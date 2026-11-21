const MAX_BODY_BYTES = 2048;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type GameWalkProgressRuntime = {
  env: (name: string) => string | undefined;
  fetcher: typeof fetch;
  nowSeconds: () => number;
};

const defaultRuntime: GameWalkProgressRuntime = {
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

function validDistance(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) &&
    value > 0 && value <= 5 && Math.round(value * 1000) === value * 1000;
}

export function createGameWalkProgressHandler(runtime: GameWalkProgressRuntime = defaultRuntime) {
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
      return json({ error: "walk_progress_not_configured" }, 503);
    }

    let publishableKey = "";
    let secretKey = "";
    try {
      publishableKey = String((JSON.parse(publishableKeysRaw) as Record<string, unknown>).default ?? "");
      secretKey = String((JSON.parse(secretKeysRaw) as Record<string, unknown>).default ?? "");
    } catch {
      return json({ error: "walk_progress_not_configured" }, 503);
    }
    if (!publishableKey || !secretKey) return json({ error: "walk_progress_not_configured" }, 503);
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

    const action = String(body.action ?? "");
    const userId = String(body.user_id ?? "");
    const issuedAt = body.issued_at;
    const signatureHex = String(body.signature_hex ?? "").toLowerCase();
    if (!UUID_RE.test(userId) || typeof issuedAt !== "number" || !Number.isSafeInteger(issuedAt) ||
      !/^[0-9a-f]{64}$/.test(signatureHex) || !["record", "lookup"].includes(action)) {
      return json({ error: "invalid_walk_payload" }, 400);
    }

    const now = runtime.nowSeconds();
    if (issuedAt > now + 30 || issuedAt < now - 120) return json({ error: "walk_timestamp_invalid" }, 400);

    let rpcPath: string;
    let rpcBody: Record<string, unknown>;
    let canonical: string;
    if (action === "lookup") {
      if (Object.keys(body).some((key) => !["action", "user_id", "issued_at", "signature_hex"].includes(key))) {
        return json({ error: "invalid_walk_lookup_payload" }, 400);
      }
      canonical = `v1|walk|lookup|${userId}|${issuedAt}`;
      rpcPath = "/rest/v1/rpc/get_server_verified_walk_distance";
      rpcBody = { p_user_id: userId };
    } else {
      const eventId = String(body.server_event_id ?? "");
      const distance = body.distance_meters;
      const expiresAt = body.expires_at;
      if (!UUID_RE.test(eventId) || !validDistance(distance) || typeof expiresAt !== "number" ||
        !Number.isSafeInteger(expiresAt) || expiresAt !== issuedAt + 300 ||
        Object.keys(body).some((key) => !["action", "user_id", "server_event_id", "distance_meters", "issued_at", "expires_at", "signature_hex"].includes(key))) {
        return json({ error: "invalid_walk_record_payload" }, 400);
      }
      canonical = `v1|walk|record|${userId}|${eventId}|${distance.toFixed(3)}|${issuedAt}|${expiresAt}`;
      rpcPath = "/rest/v1/rpc/record_server_verified_walk_distance";
      const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical)));
      const digestHex = Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
      rpcBody = {
        p_user_id: userId,
        p_server_event_id: eventId,
        p_distance_meters: distance,
        p_evidence_digest_hex: digestHex,
        p_issued_at: new Date(issuedAt * 1000).toISOString(),
        p_expires_at: new Date(expiresAt * 1000).toISOString(),
      };
    }

    let hmacKey: CryptoKey;
    try {
      hmacKey = await crypto.subtle.importKey("raw", toArrayBuffer(fromBase64(hmacSecretB64)),
        { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
    } catch {
      return json({ error: "walk_progress_not_configured" }, 503);
    }
    const valid = await crypto.subtle.verify("HMAC", hmacKey, toArrayBuffer(fromHex(signatureHex)), new TextEncoder().encode(canonical));
    if (!valid) return json({ error: "invalid_server_signature" }, 401);

    let rpcResponse: Response;
    try {
      rpcResponse = await runtime.fetcher(projectUrl + rpcPath, {
        method: "POST",
        headers: { "apikey": secretKey, "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify(rpcBody),
      });
    } catch {
      return json({ error: "walk_database_unavailable" }, 503);
    }
    if (!rpcResponse.ok) {
      const errorText = await rpcResponse.text();
      if (errorText.includes("server_walk_event_conflict")) return json({ error: "walk_event_conflict" }, 409);
      if (rpcResponse.status === 401 || rpcResponse.status === 403) return json({ error: "walk_database_unauthorized" }, 502);
      return json({ error: "walk_database_rejected" }, 502);
    }

    try {
      const value: unknown = await rpcResponse.json();
      const result = Array.isArray(value) && value.length === 1 ? value[0] : value;
      if (action === "lookup") {
        const total = typeof result === "number" ? result : Number(result);
        if (!Number.isFinite(total) || total < 0 || total > 100000000) return json({ error: "walk_lookup_response_invalid" }, 502);
        return json({ verified: true, total_meters: Math.round(total * 1000) / 1000 });
      }
      if (typeof result !== "object" || result === null || Array.isArray(result)) return json({ error: "walk_record_response_invalid" }, 502);
      const data = result as Record<string, unknown>;
      const total = Number(data.total_meters);
      if (data.recorded !== true || typeof data.duplicate !== "boolean" ||
        typeof data.achievement_unlocked !== "boolean" || !Number.isFinite(total) || total < 0 || total > 100000000) {
        return json({ error: "walk_record_response_invalid" }, 502);
      }
      return json({
        verified: true,
        recorded: true,
        duplicate: data.duplicate,
        total_meters: Math.round(total * 1000) / 1000,
        achievement_unlocked: data.achievement_unlocked,
      });
    } catch {
      return json({ error: "walk_progress_response_invalid" }, 502);
    }
  };
}

if (import.meta.main) {
  Deno.serve(createGameWalkProgressHandler());
}
