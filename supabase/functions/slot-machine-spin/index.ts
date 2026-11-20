const MAX_BODY_BYTES = 2048;
const MACHINE_WEIGHTS: Record<string, number[]> = {
  vip_royal_classic: [4000, 3000, 1800, 900, 300],
  vip_diamond_royale: [4000, 3000, 1800, 900, 300],
  vip_golden_crown: [4000, 3000, 1800, 900, 300],
};
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

// Deterministic HMAC-based pseudorandom stream makes a retried event reproduce
// exactly the same server outcome, while remaining unpredictable without the server secret.
async function createServerOutcome(
  machineId: string,
  hmacKey: CryptoKey,
  canonicalIntent: string,
): Promise<{ reelSymbols: number[]; collectionSymbols: number[] }> {
  const weights = MACHINE_WEIGHTS[machineId];
  if (!weights || weights.reduce((sum, value) => sum + value, 0) !== 10000) {
    throw new Error("machine_rules_invalid");
  }
  let counter = 0;
  let block = new Uint8Array(0);
  let offset = 0;
  const encoder = new TextEncoder();

  async function integerBelow(maxExclusive: number): Promise<number> {
    const range = 0x1_0000_0000;
    const limit = Math.floor(range / maxExclusive) * maxExclusive;
    while (true) {
      if (offset + 4 > block.length) {
        const input = encoder.encode(`${canonicalIntent}|slot-outcome-v1|${counter++}`);
        block = new Uint8Array(await crypto.subtle.sign("HMAC", hmacKey, input));
        offset = 0;
      }
      const value = new DataView(block.buffer, block.byteOffset + offset, 4).getUint32(0, false);
      offset += 4;
      if (value < limit) return value % maxExclusive;
    }
  }

  async function weightedSymbol(): Promise<number> {
    const draw = await integerBelow(10000);
    let cumulative = 0;
    for (let index = 0; index < weights.length; index++) {
      cumulative += weights[index];
      if (draw < cumulative) return index;
    }
    throw new Error("invalid_symbol_weights");
  }

  const reelSymbols = [await weightedSymbol(), await weightedSymbol(), await weightedSymbol()];
  const collectionSymbols: number[] = [];
  for (let index = 0; index < 9; index++) collectionSymbols.push(await integerBelow(5));
  return { reelSymbols, collectionSymbols };
}
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const contentType = (req.headers.get("Content-Type") ?? "").split(";")[0].trim().toLowerCase();
  if (contentType !== "application/json") return json({ error: "content_type_must_be_json" }, 415);

  const projectUrlRaw = Deno.env.get("SUPABASE_URL");
  const projectUrl = projectUrlRaw?.endsWith("/") ? projectUrlRaw.slice(0, -1) : projectUrlRaw;
  const publishableKeysRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  const secretKeysRaw = Deno.env.get("SUPABASE_SECRET_KEYS");
  const hmacSecretB64 = Deno.env.get("KING_CITY_PROOF_HMAC_SECRET_B64");
  if (!projectUrl || !publishableKeysRaw || !secretKeysRaw || !hmacSecretB64) {
    return json({ error: "slot_spin_not_configured" }, 503);
  }

  let publishableKey = "";
  let secretKey = "";
  try {
    publishableKey = String((JSON.parse(publishableKeysRaw) as Record<string, unknown>).default ?? "");
    secretKey = String((JSON.parse(secretKeysRaw) as Record<string, unknown>).default ?? "");
  } catch {
    return json({ error: "slot_spin_not_configured" }, 503);
  }
  if (!publishableKey || !secretKey) return json({ error: "slot_spin_not_configured" }, 503);
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
  const sessionId = String(body.session_id ?? "");
  const eventId = String(body.server_event_id ?? "");
  const machineId = String(body.machine_id ?? "");
  const spinType = String(body.spin_type ?? "");
  const wager = spinType === "free" ? 10 : body.wager_chips;
  const issuedAt = body.issued_at;
  const signatureHex = String(body.signature_hex ?? "").toLowerCase();

  if (
    !UUID_RE.test(userId) || !UUID_RE.test(sessionId) || !UUID_RE.test(eventId) ||
    !Object.hasOwn(MACHINE_WEIGHTS, machineId) || !["paid", "free"].includes(spinType) ||
    typeof wager !== "number" || !Number.isSafeInteger(wager) ||
    (spinType === "paid" && (wager < 10 || wager > 2_000_000_000)) ||
    (spinType === "free" && wager !== 10) ||
    typeof issuedAt !== "number" || !Number.isSafeInteger(issuedAt) ||
    !/^[0-9a-f]{64}$/.test(signatureHex)
  ) return json({ error: "invalid_slot_spin_intent" }, 400);

  const now = Math.floor(Date.now() / 1000);
  if (issuedAt > now + 30 || issuedAt < now - 120) return json({ error: "slot_spin_timestamp_invalid" }, 400);

  const canonical = `v2|${userId}|${sessionId}|${machineId}|${eventId}|${spinType}|${wager}|${issuedAt}`;
  let hmacKey: CryptoKey;
  try {
    const secretBytes = fromBase64(hmacSecretB64);
    if (secretBytes.length < 32) return json({ error: "slot_spin_not_configured" }, 503);
    hmacKey = await crypto.subtle.importKey("raw", secretBytes, { name: "HMAC", hash: "SHA-256" }, false, ["verify", "sign"]);
  } catch {
    return json({ error: "slot_spin_not_configured" }, 503);
  }
  const valid = await crypto.subtle.verify("HMAC", hmacKey, fromHex(signatureHex), new TextEncoder().encode(canonical));
  if (!valid) return json({ error: "invalid_server_signature" }, 401);

  let outcome: { reelSymbols: number[]; collectionSymbols: number[] };
  try {
    outcome = await createServerOutcome(machineId, hmacKey, canonical);
  } catch {
    return json({ error: "slot_machine_rules_invalid" }, 503);
  }

  let rpcResponse: Response;
  try {
    rpcResponse = await fetch(projectUrl + "/rest/v1/rpc/settle_arcade_slot_spin", {
      method: "POST",
      headers: { "apikey": secretKey, "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify({
        p_user_id: userId,
        p_session_id: sessionId,
        p_server_event_id: eventId,
        p_machine_id: machineId,
        p_spin_type: spinType,
        p_wager_chips: wager,
        p_reel_symbols: outcome.reelSymbols,
        p_collection_symbols: outcome.collectionSymbols,
      }),
    });
  } catch {
    return json({ error: "slot_spin_database_unavailable" }, 503);
  }

  if (!rpcResponse.ok) {
    const errorText = await rpcResponse.text();
    for (const code of [
      "insufficient_game_chips", "free_spin_balance_insufficient", "slot_machine_not_enabled",
      "slot_round_event_conflict", "player_wallet_not_found", "player_wallet_limit_exceeded",
      "free_spin_wallet_limit_exceeded",
    ]) {
      if (errorText.includes(code)) return json({ error: code }, 409);
    }
    return json({ error: "slot_spin_settlement_rejected" }, 502);
  }

  try {
    const result: unknown = await rpcResponse.json();
    if (typeof result !== "object" || result === null || Array.isArray(result)) return json({ error: "slot_spin_response_invalid" }, 502);
    const value = result as Record<string, unknown>;
    if (value.settled !== true || typeof value.balance_after !== "number" ||
        typeof value.challenge_progress !== "number" || typeof value.free_spins_balance !== "number") {
      return json({ error: "slot_spin_response_invalid" }, 502);
    }
    return json(value);
  } catch {
    return json({ error: "slot_spin_response_invalid" }, 502);
  }
});
