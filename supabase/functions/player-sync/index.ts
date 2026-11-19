import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) {
    return json({ error: "unauthorized" }, 401);
  }

  const projectUrl = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "");
  const publishableKeysRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (!projectUrl || !publishableKeysRaw) {
    return json({ error: "sync_service_not_configured" }, 503);
  }

  let publishableKey = "";
  try {
    const keys = JSON.parse(publishableKeysRaw);
    publishableKey = String(keys.default ?? "");
  } catch {
    return json({ error: "sync_service_not_configured" }, 503);
  }
  if (!publishableKey) {
    return json({ error: "sync_service_not_configured" }, 503);
  }

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > 512 * 1024) {
    return json({ error: "request_too_large" }, 413);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (
    typeof body !== "object" ||
    body === null ||
    Array.isArray(body) ||
    !("events" in body) ||
    !Array.isArray((body as { events: unknown }).events) ||
    (body as { events: unknown[] }).events.length < 1 ||
    (body as { events: unknown[] }).events.length > 50
  ) {
    return json({ error: "invalid_event_batch" }, 400);
  }

  // The database RPC validates the exact event shape, event types and payload allowlist.
  // It derives user_id from auth.uid(); the client cannot choose another account.
  let rpcResponse: Response;
  try {
    rpcResponse = await fetch(
      `${projectUrl}/rest/v1/rpc/submit_player_sync_events`,
      {
        method: "POST",
        headers: {
          "apikey": publishableKey,
          "Authorization": authorization,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: JSON.stringify({
          p_events: (body as { events: unknown[] }).events,
        }),
      },
    );
  } catch {
    return json({ error: "sync_database_unavailable" }, 503);
  }

  if (!rpcResponse.ok) {
    if (rpcResponse.status === 401 || rpcResponse.status === 403) {
      return json({ error: "unauthorized" }, rpcResponse.status);
    }
    if (rpcResponse.status === 400 || rpcResponse.status === 422) {
      return json({ error: "invalid_or_rejected_events" }, 400);
    }
    return json({ error: "sync_database_error" }, 502);
  }

  let result: unknown;
  try {
    result = await rpcResponse.json();
  } catch {
    return json({ error: "sync_response_invalid" }, 502);
  }
  return json({ ok: true, result });
});
