const MAX_BODY_BYTES = 4096;
const MACHINE_IDS = new Set(["vip_royal_classic", "vip_diamond_royale", "vip_golden_crown"]);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = Number.parseInt(value.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
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
    return json({ error: "slot_settlement_not_configured" }, 503);
  }

  let publishableKey = "";
  let secretKey = "";
  try {
    publishableKey = String((JSON.parse(publishableKeysRaw) as Record<string, unknown>).default ?? "");
    secretKey = String((JSON.parse(secretKeysRaw) as Record<string, unknown>).default ?? "");
  } catch {
    return json({ error: "slot_settlement_not_configured" }, 503);
  }
  if (!publishableKey || !secretKey) return json({ error: "slot_settlement_not_configured" }, 503);
  if (req.headers.get("apikey") !== publishableKey) return json({ error: "unauthorized" }, 401);

  const rawBody = await readBoundedBody(req);
  if (rawBody === null) return json({ error: "request_too_large" }, 413);

  let body: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(rawBody);
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return json({ error: "invalid_payload" }, 400);
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const userId = String(body.user_id ?? "");
  const sessionId = String(body.session_id ?? "");
  const eventId = String(body.server_event_id ?? "");
  const machineId = String(body.machine_id ?? "");
  const wager = body.wager_chips;
  const symbols = body.symbols;
  const issuedAt = body.issued_at;
  const signatureHex = String(body.signature_hex ?? "").toLowerCase();

  if (
    !UUID_RE.test(userId) || !UUID_RE.test(sessionId) || !UUID_RE.test(eventId) ||
    !MACHINE_IDS.has(machineId) ||
    typeof wager !== "number" || !Number.isSafeInteger(wager) || wager < 10 || wager > 2_000_000_000 ||
    !Array.isArray(symbols) || symbols.length !== 3 ||
    !symbols.every((symbol) => typeof symbol === "number" && Number.isInteger(symbol) && symbol >= 0 && symbol <= 4) ||
    typeof issuedAt !== "number" || !Number.isSafeInteger(issuedAt) ||
    !/^[0-9a-f]{64}$/.test(signatureHex)
  ) return json({ error: "invalid_slot_settlement_payload" }, 400);

  const now = Math.floor(Date.now() / 1000);
  if (issuedAt > now + 30 || issuedAt < now - 120) {
    return json({ error: "slot_settlement_timestamp_invalid" }, 400);
  }

  const canonical = `v1|${userId}|${sessionId}|${machineId}|${eventId}|${wager}|${symbols.join(",")}|${issuedAt}`;
  const message = new TextEncoder().encode(canonical);

  let hmacKey: CryptoKey;
  try {
    hmacKey = await crypto.subtle.importKey(
      "raw",
      fromBase64(hmacSecretB64),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"],
    );
  } catch {
    return json({ error: "slot_settlement_not_configured" }, 503);
  }

  const valid = await crypto.subtle.verify("HMAC", hmacKey, fromHex(signatureHex), message);
  if (!valid) return json({ error: "invalid_server_signature" }, 401);

  let rpcResponse: Response;
  try {
    rpcResponse = await fetch(projectUrl + "/rest/v1/rpc/settle_arcade_slot_round", {
      method: "POST",
      headers: {
        "apikey": secretKey,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify({
        p_user_id: userId,
        p_session_id: sessionId,
        p_server_event_id: eventId,
        p_machine_id: machineId,
        p_wager_chips: wager,
        p_symbols: symbols,
      }),
    });
  } catch {
    return json({ error: "slot_settlement_database_unavailable" }, 503);
  }

  if (!rpcResponse.ok) {
    const errorText = await rpcResponse.text();
    if (errorText.includes("insufficient_game_chips")) return json({ error: "insufficient_game_chips" }, 409);
    if (errorText.includes("slot_machine_not_enabled")) return json({ error: "slot_machine_not_enabled" }, 409);
    if (errorText.includes("slot_round_event_conflict")) return json({ error: "slot_round_event_conflict" }, 409);
    if (errorText.includes("player_wallet_not_found")) return json({ error: "player_wallet_not_found" }, 409);
    if (errorText.includes("player_wallet_limit_exceeded")) return json({ error: "player_wallet_limit_exceeded" }, 409);
    return json({ error: "slot_settlement_rejected" }, 502);
  }

  try {
    const result: unknown = await rpcResponse.json();
    if (typeof result !== "object" || result === null || Array.isArray(result)) {
      return json({ error: "slot_settlement_response_invalid" }, 502);
    }
    const value = result as Record<string, unknown>;
    if (value.settled !== true || typeof value.balance_after !== "number") {
      return json({ error: "slot_settlement_response_invalid" }, 502);
    }
    return json(value);
  } catch {
    return json({ error: "slot_settlement_response_invalid" }, 502);
  }
});
