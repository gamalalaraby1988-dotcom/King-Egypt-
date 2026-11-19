import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const MAX_BODY_BYTES = 512 * 1024;

function json(data: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, ...extraHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

async function readBoundedBody(req: Request): Promise<string | null> {
  const contentLength = req.headers.get("Content-Length");
  if (contentLength && Number.isFinite(Number(contentLength)) && Number(contentLength) > MAX_BODY_BYTES) return null;
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const contentType = (req.headers.get("Content-Type") ?? "").split(";")[0].trim().toLowerCase();
  if (contentType !== "application/json") return json({ error: "content_type_must_be_json" }, 415);

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ") || authorization.slice(7).trim().length === 0) {
    return json({ error: "unauthorized" }, 401);
  }

  const projectUrlRaw = Deno.env.get("SUPABASE_URL");
  const projectUrl = projectUrlRaw?.endsWith("/") ? projectUrlRaw.slice(0, -1) : projectUrlRaw;
  const publishableKeysRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (!projectUrl || !publishableKeysRaw) return json({ error: "sync_service_not_configured" }, 503);

  let publishableKey = "";
  try {
    const keys = JSON.parse(publishableKeysRaw) as Record<string, unknown>;
    publishableKey = typeof keys.default === "string" ? keys.default : "";
  } catch {
    return json({ error: "sync_service_not_configured" }, 503);
  }
  if (!publishableKey) return json({ error: "sync_service_not_configured" }, 503);

  // verify_jwt is disabled for the new publishable-key model. Validate the
  // user's actual Supabase Auth access token explicitly before touching data.
  let authResponse: Response;
  try {
    authResponse = await fetch(projectUrl + "/auth/v1/user", {
      method: "GET",
      headers: { "apikey": publishableKey, "Authorization": authorization },
    });
  } catch {
    return json({ error: "auth_service_unavailable" }, 503);
  }
  if (!authResponse.ok) return json({ error: "unauthorized" }, 401);

  const rawBody = await readBoundedBody(req);
  if (rawBody === null) return json({ error: "request_too_large" }, 413);

  let body: unknown;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (
    typeof body !== "object" || body === null || Array.isArray(body) ||
    !("events" in body) || !Array.isArray((body as { events: unknown }).events) ||
    (body as { events: unknown[] }).events.length < 1 ||
    (body as { events: unknown[] }).events.length > 50
  ) return json({ error: "invalid_event_batch" }, 400);

  // The invoker RPC applies RLS and per-account rate limits; user_id comes from auth.uid().
  let rpcResponse: Response;
  try {
    rpcResponse = await fetch(projectUrl + "/rest/v1/rpc/submit_player_sync_events", {
      method: "POST",
      headers: {
        "apikey": publishableKey,
        "Authorization": authorization,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify({ p_events: (body as { events: unknown[] }).events }),
    });
  } catch {
    return json({ error: "sync_database_unavailable" }, 503);
  }

  if (!rpcResponse.ok) {
    const errorText = await rpcResponse.text();
    if (rpcResponse.status === 401 || rpcResponse.status === 403) return json({ error: "unauthorized" }, rpcResponse.status);
    if (errorText.includes("sync_rate_limited")) return json({ error: "rate_limited" }, 429, { "Retry-After": "60" });
    if (rpcResponse.status === 400 || rpcResponse.status === 422) return json({ error: "invalid_or_rejected_events" }, 400);
    return json({ error: "sync_database_error" }, 502);
  }

  try {
    return json({ ok: true, result: await rpcResponse.json() });
  } catch {
    return json({ error: "sync_response_invalid" }, 502);
  }
});
