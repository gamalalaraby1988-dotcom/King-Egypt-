const MAX_BODY_BYTES = 4096;
const ACTIVITY_KINDS = new Set(["mission", "job", "achievement", "daily_claim"]);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ACTIVITY_ID_RE = /^[a-z0-9][a-z0-9_.-]{0,79}$/;

export type GameProofIssuerRuntime = {
  env: (name: string) => string | undefined;
  fetcher: typeof fetch;
  nowSeconds: () => number;
};

const defaultRuntime: GameProofIssuerRuntime = {
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

function toHex(value: ArrayBuffer): string {
  return Array.from(new Uint8Array(value), (byte) => byte.toString(16).padStart(2, "0")).join("");
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

export function createGameProofIssuerHandler(runtime: GameProofIssuerRuntime = defaultRuntime) {
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
      return json({ error: "proof_issuer_not_configured" }, 503);
    }

    let publishableKey = "";
    let secretKey = "";
    try {
      publishableKey = String((JSON.parse(publishableKeysRaw) as Record<string, unknown>).default ?? "");
      secretKey = String((JSON.parse(secretKeysRaw) as Record<string, unknown>).default ?? "");
    } catch {
      return json({ error: "proof_issuer_not_configured" }, 503);
    }
    if (!publishableKey || !secretKey) return json({ error: "proof_issuer_not_configured" }, 503);
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
    const eventId = String(body.server_event_id ?? "");
    const issuedAt = body.issued_at;
    const expiresAt = body.expires_at;
    const suppliedDigest = String(body.evidence_digest_hex ?? "").toLowerCase();
    const signatureHex = String(body.signature_hex ?? "").toLowerCase();

    if (
      !UUID_RE.test(userId) || !UUID_RE.test(eventId) ||
      !ACTIVITY_KINDS.has(activityKind) || !ACTIVITY_ID_RE.test(activityId) ||
      typeof issuedAt !== "number" || typeof expiresAt !== "number" ||
      !Number.isSafeInteger(issuedAt) || !Number.isSafeInteger(expiresAt) ||
      !/^[0-9a-f]{64}$/.test(suppliedDigest) || !/^[0-9a-f]{64}$/.test(signatureHex)
    ) return json({ error: "invalid_proof_payload" }, 400);

    const now = runtime.nowSeconds();
    if (issuedAt > now + 30 || issuedAt < now - 120 || expiresAt !== issuedAt + 300) {
      return json({ error: "proof_timestamp_invalid" }, 400);
    }

    const canonical = `v1|${userId}|${activityKind}|${activityId}|${eventId}|${issuedAt}|${expiresAt}`;
    const message = new TextEncoder().encode(canonical);
    const digest = toHex(await crypto.subtle.digest("SHA-256", message));
    if (digest !== suppliedDigest) return json({ error: "evidence_digest_mismatch" }, 401);

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
      return json({ error: "proof_issuer_not_configured" }, 503);
    }
    const signatureValid = await crypto.subtle.verify(
      "HMAC",
      hmacKey,
      toArrayBuffer(fromHex(signatureHex)),
      message,
    );
    if (!signatureValid) return json({ error: "invalid_server_signature" }, 401);

    let rpcResponse: Response;
    try {
      rpcResponse = await runtime.fetcher(projectUrl + "/rest/v1/rpc/record_server_verified_activity_progress", {
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
          p_server_event_id: eventId,
          p_evidence_digest_hex: digest,
          p_issued_at: new Date(issuedAt * 1000).toISOString(),
          p_expires_at: new Date(expiresAt * 1000).toISOString(),
        }),
      });
    } catch {
      return json({ error: "progress_database_unavailable" }, 503);
    }
    if (!rpcResponse.ok) {
      const errorText = await rpcResponse.text();
      if (errorText.includes("server_progress_event_conflict")) return json({ error: "progress_event_conflict" }, 409);
      if (rpcResponse.status === 401 || rpcResponse.status === 403) return json({ error: "progress_database_unauthorized" }, 502);
      return json({ error: "progress_database_rejected" }, 502);
    }

    try {
      const value: unknown = await rpcResponse.json();
      const result = Array.isArray(value) && value.length === 1 ? value[0] : value;
      if (typeof result !== "object" || result === null || Array.isArray(result)) {
        return json({ error: "progress_response_invalid" }, 502);
      }
      const data = result as Record<string, unknown>;
      if (data.progress_recorded !== true || typeof data.reward_eligible !== "boolean") {
        return json({ error: "progress_response_invalid" }, 502);
      }
      const proofId = data.proof_id == null ? null : String(data.proof_id);
      if (proofId !== null && !UUID_RE.test(proofId)) return json({ error: "progress_response_invalid" }, 502);
      const achievementUnlocked = data.achievement_unlocked;
      const achievementRewardEligible = data.achievement_reward_eligible;
      const achievementProofId = data.achievement_proof_id == null ? null : String(data.achievement_proof_id);
      if (
        typeof achievementUnlocked !== "boolean" ||
        typeof achievementRewardEligible !== "boolean" ||
        (achievementRewardEligible && (!achievementUnlocked || achievementProofId === null)) ||
        (!achievementUnlocked && (achievementRewardEligible || achievementProofId !== null)) ||
        (achievementProofId !== null && (!achievementUnlocked || !achievementRewardEligible || !UUID_RE.test(achievementProofId)))
      ) return json({ error: "progress_response_invalid" }, 502);
      return json({
        progress_recorded: true,
        duplicate: data.duplicate === true,
        reward_eligible: data.reward_eligible,
        proof_id: proofId,
        achievement_unlocked: achievementUnlocked,
        achievement_reward_eligible: achievementRewardEligible,
        achievement_proof_id: achievementProofId,
      });
    } catch {
      return json({ error: "progress_response_invalid" }, 502);
    }
  };
}

if (import.meta.main) {
  Deno.serve(createGameProofIssuerHandler());
}
