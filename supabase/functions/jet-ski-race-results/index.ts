import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const MAX_BODY_BYTES = 4096;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SERVER_ID_RE = /^[a-zA-Z0-9][a-zA-Z0-9_-]{2,63}$/;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, content-type, x-king-city-timestamp, x-king-city-nonce, x-king-city-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export type JetSkiRaceResultsRuntime = {
  env: (name: string) => string | undefined;
  fetcher: typeof fetch;
  nowSeconds: () => number;
};

const defaults: JetSkiRaceResultsRuntime = {
  env: (name) => Deno.env.get(name),
  fetcher: fetch,
  nowSeconds: () => Math.floor(Date.now() / 1000),
};

const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), {
    status,
    headers: { ...CORS, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

function toArrayBuffer(value: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(value.byteLength);
  copy.set(value);
  return copy.buffer;
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

function getKeys(runtime: JetSkiRaceResultsRuntime) {
  try {
    const url = runtime.env("SUPABASE_URL")?.replace(/\/$/, "") ?? "";
    const publishable = JSON.parse(runtime.env("SUPABASE_PUBLISHABLE_KEYS") ?? "{}").default;
    const secret = JSON.parse(runtime.env("SUPABASE_SECRET_KEYS") ?? "{}").default;
    if (!url.startsWith("https://") || typeof publishable !== "string" || typeof secret !== "string") return null;
    return { url, publishable, secret };
  } catch {
    return null;
  }
}

async function verifyServer(
  body: Record<string, unknown>,
  rawBody: string,
  req: Request,
  runtime: JetSkiRaceResultsRuntime,
) {
  const serverId = String(body.server_id ?? "");
  const timestamp = Number(req.headers.get("x-king-city-timestamp"));
  const nonce = req.headers.get("x-king-city-nonce") ?? "";
  const signature = (req.headers.get("x-king-city-signature") ?? "").toLowerCase();
  if (
    !SERVER_ID_RE.test(serverId) ||
    !Number.isSafeInteger(timestamp) ||
    Math.abs(runtime.nowSeconds() - timestamp) > 60 ||
    !UUID_RE.test(nonce) ||
    !/^[0-9a-f]{64}$/.test(signature)
  ) return null;

  let serverKeys: Record<string, unknown>;
  try {
    serverKeys = JSON.parse(runtime.env("CITY_SESSION_SERVER_KEYS_JSON") ?? "{}");
  } catch {
    return null;
  }
  const secretB64 = serverKeys[serverId];
  if (typeof secretB64 !== "string") return null;
  try {
    const secret = Uint8Array.from(atob(secretB64), (char) => char.charCodeAt(0));
    if (secret.byteLength < 32) return null;
    const key = await crypto.subtle.importKey("raw", toArrayBuffer(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
    const signatureBytes = Uint8Array.from(signature.match(/../g) ?? [], (part) => Number.parseInt(part, 16));
    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      toArrayBuffer(signatureBytes),
      new TextEncoder().encode(`${timestamp}\n${nonce}\n${rawBody}`),
    );
    return valid ? { serverId, nonce, timestamp } : null;
  } catch {
    return null;
  }
}

function rpcError(status: number, value: unknown) {
  const message = typeof value === "string" ? value : JSON.stringify(value);
  if (message.includes("jet_ski_race_server_nonce_replayed")) return json({ error: "server_request_replayed" }, 409);
  if (message.includes("jet_ski_race_result_conflict")) return json({ error: "race_result_conflict" }, 409);
  if (message.includes("jet_ski_race_result_invalid") || message.includes("jet_ski_race_finish_payload_invalid") ||
      message.includes("jet_ski_race_dnf_payload_invalid")) return json({ error: "invalid_race_result" }, 400);
  if (status === 401 || status === 403) return json({ error: "result_database_unauthorized" }, 502);
  return json({ error: "result_database_rejected" }, 502);
}

export function createJetSkiRaceResultsHandler(runtime: JetSkiRaceResultsRuntime = defaults) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    if ((req.headers.get("Content-Type") ?? "").split(";")[0].trim().toLowerCase() !== "application/json") {
      return json({ error: "content_type_must_be_json" }, 415);
    }

    const keys = getKeys(runtime);
    if (!keys) return json({ error: "race_results_not_configured" }, 503);
    if (req.headers.get("apikey") !== keys.publishable) return json({ error: "unauthorized" }, 401);

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

    const allowed = ["server_id", "race_id", "server_event_id", "user_id", "status", "place", "finish_time_usec", "race_finished_at", "reason"];
    if (Object.keys(body).some((key) => !allowed.includes(key))) return json({ error: "unexpected_payload_field" }, 400);

    const raceId = String(body.race_id ?? "");
    const eventId = String(body.server_event_id ?? "");
    const userId = String(body.user_id ?? "");
    const status = String(body.status ?? "");
    const raceFinishedAt = typeof body.race_finished_at === "string" ? Date.parse(body.race_finished_at) : Number.NaN;
    if (!UUID_RE.test(raceId) || !UUID_RE.test(eventId) || !UUID_RE.test(userId) ||
        !["finished", "dnf"].includes(status) || !Number.isFinite(raceFinishedAt)) {
      return json({ error: "invalid_race_result" }, 400);
    }

    let place: number | null = null;
    let finishTimeUsec: number | null = null;
    let reason: string | null = null;
    if (status === "finished") {
      if (typeof body.place !== "number" || !Number.isSafeInteger(body.place) || body.place < 1 || body.place > 4 ||
          typeof body.finish_time_usec !== "number" || !Number.isSafeInteger(body.finish_time_usec) || body.finish_time_usec < 0 ||
          (body.reason !== undefined && body.reason !== null)) {
        return json({ error: "invalid_finish_result" }, 400);
      }
      place = Number(body.place);
      finishTimeUsec = Number(body.finish_time_usec);
    } else {
      if ((body.place !== undefined && body.place !== null) ||
          (body.finish_time_usec !== undefined && body.finish_time_usec !== null) ||
          !["disconnect", "time_limit"].includes(String(body.reason ?? ""))) {
        return json({ error: "invalid_dnf_result" }, 400);
      }
      reason = String(body.reason);
    }

    const verified = await verifyServer(body, rawBody, req, runtime);
    if (!verified) return json({ error: "invalid_server_signature" }, 401);
    const finishSeconds = Math.floor(raceFinishedAt / 1000);
    if (finishSeconds > runtime.nowSeconds() + 60 || finishSeconds < runtime.nowSeconds() - 7 * 86400) {
      return json({ error: "race_finish_timestamp_invalid" }, 400);
    }

    let response: Response;
    try {
      response = await runtime.fetcher(keys.url + "/rest/v1/rpc/record_jet_ski_race_result", {
        method: "POST",
        headers: { apikey: keys.secret, "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          p_race_id: raceId,
          p_server_event_id: eventId,
          p_server_id: verified.serverId,
          p_user_id: userId,
          p_status: status,
          p_place: place,
          p_finish_time_usec: finishTimeUsec,
          p_race_finished_at: new Date(raceFinishedAt).toISOString(),
          p_nonce: verified.nonce,
          p_issued_at: new Date(verified.timestamp * 1000).toISOString(),
          p_reason: reason,
        }),
      });
    } catch {
      return json({ error: "result_database_unavailable" }, 503);
    }
    if (!response.ok) {
      const value = await response.text();
      return rpcError(response.status, value);
    }

    try {
      const value: unknown = await response.json();
      const result = Array.isArray(value) && value.length === 1 ? value[0] : value;
      if (typeof result !== "object" || result === null || Array.isArray(result) ||
          (result as Record<string, unknown>).recorded !== true ||
          typeof (result as Record<string, unknown>).duplicate !== "boolean") {
        return json({ error: "result_database_response_invalid" }, 502);
      }
      return json(result);
    } catch {
      return json({ error: "result_database_response_invalid" }, 502);
    }
  };
}

if (import.meta.main) Deno.serve(createJetSkiRaceResultsHandler());
