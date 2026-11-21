const MAX_BODY_BYTES = 2048;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ACTIVITY_ID_RE = /^(mission_shop|mission_restaurant|mission_employment)$/;

export type GameProgressLookupRuntime = {
  env: (name: string) => string | undefined;
  fetcher: typeof fetch;
  nowSeconds: () => number;
};

const defaultRuntime: GameProgressLookupRuntime = {
  env: (name) => Deno.env.get(name),
  fetcher: fetch,
  nowSeconds: () => Math.floor(Date.now() / 1000),
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

async function readBoundedBody(req: Request): Promise<string | null> {
  const length = req.headers.get("Content-Length");
  if (length && Number.isFinite(Number(length)) && Number(length) > MAX_BODY_BYTES) return null;
  if (!req.body) return "";
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_BODY_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

function fromHex(value: string): Uint8Array {
  const bytes = new Uint8Array(value.length / 2);
  for (let i = 0; i < bytes.length; i++) bytes[i] = Number.parseInt(value.slice(i * 2, i * 2 + 2), 16);
  return bytes;
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function toArrayBuffer(value: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(value.byteLength);
  copy.set(value);
  return copy.buffer;
}

export function createGameProgressLookupHandler(runtime: GameProgressLookupRuntime = defaultRuntime) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    const contentType = (req.headers.get("Content-Type") ?? "").split(";")[0].trim().toLowerCase();
    if (contentType !== "application/json") return json({ error: "content_type_must_be_json" }, 415);

    const projectUrlRaw = runtime.env("SUPABASE_URL");
    const projectUrl = projectUrlRaw?.endsWith("/") ? projectUrlRaw.slice(0, -1) : projectUrlRaw;
    const publishableKeysRaw = runtime.env("SUPABASE_PUBLISHABLE_KEYS");
    const secretKeysRaw = runtime.env("SUPABASE_SECRET_KEYS");
    const hmacSecretB64 = runtime.env("KING_CITY_PROOF_HMAC_SECRET_B64");
    if (!projectUrl || !publishableKeysRaw || !secretKeysRaw || !hmacSecretB64) {
      return json({ error: "progress_lookup_not_configured" }, 503);
    }

    let publishableKey = "";
    let secretKey = "";
    try {
      publishableKey = String((JSON.parse(publishableKeysRaw) as Record<string, unknown>).default ?? "");
      secretKey = String((JSON.parse(secretKeysRaw) as Record<string, unknown>).default ?? "");
    } catch {
      return json({ error: "progress_lookup_not_configured" }, 503);
    }
    if (!publishableKey || !secretKey) return json({ error: "progress_lookup_not_configured" }, 503);
    if (req.headers.get("apikey") !== publishableKey) return json({ error: "unauthorized" }, 401);

    const rawBody = await readBoundedBody(req);
    if (rawBody === null) return json({ error: "request_too_large" }, 413);
    let body: Record<string, unknown>;
    try {
      const parsed: unknown = JSON.parse(rawBody);
      if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) return json({ error: "invalid_payload" }, 400);
      body = parsed as Record<string, unknown>;
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    const userId = String(body.user_id ?? "");
    const activityKind = String(body.activity_kind ?? "");
    const activityId = String(body.activity_id ?? "");
    const issuedAt = body.issued_at;
    const signatureHex = String(body.signature_hex ?? "").toLowerCase();
    if (
      !UUID_RE.test(userId) || activityKind !== "mission" || !ACTIVITY_ID_RE.test(activityId) ||
      typeof issuedAt !== "number" || !Number.isSafeInteger(issuedAt) ||
      !/^[0-9a-f]{64}$/.test(signatureHex)
    ) return json({ error: "invalid_lookup_payload" }, 400);

    const now = runtime.nowSeconds();
    if (issuedAt > now + 30 || issuedAt < now - 120) return json({ error: "lookup_timestamp_invalid" }, 400);

    const canonical = \`v1|lookup|\${userId}|\${activityKind}|\${activityId}|\${issuedAt}\`;
    const message = new TextEncoder().encode(canonical);
    let hmacKey: CryptoKey;
    try {
      hmacKey = await crypto.subtle.importKey(
        "raw",
        toArrayBuffer(fromBase64(hmacSecretB64)),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["verify"],
      );
    } catch {
      return json({ error: "progress_lookup_not_configured" }, 503);
    }
    const valid = await crypto.subtle.verify("HMAC", hmacKey, toArrayBuffer(fromHex(signatureHex)), message);
    if (!valid) return json({ error: "invalid_server_signature" }, 401);

    let rpcResponse: Response;
    try {
      rpcResponse = await runtime.fetcher(projectUrl + "/rest/v1/rpc/has_player_verified_activity", {
        method: "POST",
        headers: {
          "apikey": secretKey,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: JSON.stringify({
          p_user_id: userId,
          p_activity_kind: activityKind,
          p_activity_id: activityId,
        }),
      });
    } catch {
      return json({ error: "progress_database_unavailable" }, 503);
    }
    if (!rpcResponse.ok) return json({ error: "progress_database_rejected" }, 502);

    try {
      const value: unknown = await rpcResponse.json();
      const completed = value === true || (Array.isArray(value) && value.length === 1 && value[0] === true);
      if (!(value === true || value === false || (Array.isArray(value) && value.length === 1 && typeof value[0] === "boolean"))) {
        return json({ error: "progress_lookup_response_invalid" }, 502);
      }
      return json({ verified: true, completed });
    } catch {
      return json({ error: "progress_lookup_response_invalid" }, 502);
    }
  };
}

if (import.meta.main) {
  Deno.serve(createGameProgressLookupHandler());
}
