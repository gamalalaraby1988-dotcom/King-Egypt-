import { createPlayerSyncHandler } from "../functions/player-sync/index.ts";

const PROJECT_URL = "https://sync-test.example";
const PUBLISHABLE_KEY = "sb_publishable_test_only";
const ACCESS_TOKEN = "test-user-access-token";
const EVENT = {
  event_id: "10000000-0000-4000-8000-000000000001",
  event_type: "setting_changed",
  payload: { key: "locale", value: "ar" },
};

function runtime(fetcher: (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>) {
  return {
    env: (name: string) => {
      if (name === "SUPABASE_URL") return PROJECT_URL + "/";
      if (name === "SUPABASE_PUBLISHABLE_KEYS") return JSON.stringify({ default: PUBLISHABLE_KEY });
      return undefined;
    },
    fetcher,
  };
}

function postRequest(body: string, authorization = "Bearer " + ACCESS_TOKEN): Request {
  return new Request("https://edge-test.example/player-sync", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(authorization ? { Authorization: authorization } : {}),
    },
    body,
  });
}

Deno.test("preflight and method checks do not call upstream services", async () => {
  let calls = 0;
  const handler = createPlayerSyncHandler(runtime(async () => {
    calls++;
    return new Response(null, { status: 500 });
  }));

  const options = await handler(new Request("https://edge-test.example/player-sync", { method: "OPTIONS" }));
  const get = await handler(new Request("https://edge-test.example/player-sync", { method: "GET" }));

  if (options.status !== 200) throw new Error("OPTIONS must return 200");
  if (options.headers.get("Access-Control-Allow-Methods") !== "POST, OPTIONS") throw new Error("CORS methods missing");
  if (get.status !== 405) throw new Error("Non-POST methods must be rejected");
  if (calls !== 0) throw new Error("Preflight/method checks must not call auth or database");
});

Deno.test("unsupported content type is rejected before auth", async () => {
  let calls = 0;
  const handler = createPlayerSyncHandler(runtime(async () => {
    calls++;
    return new Response(null, { status: 500 });
  }));
  const response = await handler(new Request("https://edge-test.example/player-sync", {
    method: "POST",
    headers: { "Content-Type": "text/plain", Authorization: "Bearer " + ACCESS_TOKEN },
    body: "{}",
  }));
  if (response.status !== 415) throw new Error("Unsupported content type must return 415");
  if (calls !== 0) throw new Error("Unsupported content type must not call upstream services");
});

Deno.test("missing bearer token is rejected without contacting Supabase", async () => {
  let calls = 0;
  const handler = createPlayerSyncHandler(runtime(async () => {
    calls++;
    return new Response(null, { status: 200 });
  }));
  const response = await handler(postRequest(JSON.stringify({ events: [EVENT] }), ""));
  if (response.status !== 401) throw new Error("Missing bearer token must return 401");
  if (calls !== 0) throw new Error("Unauthenticated request reached Supabase");
});

Deno.test("invalid access token is rejected and never reaches the sync RPC", async () => {
  const calls: string[] = [];
  const handler = createPlayerSyncHandler(runtime(async (input) => {
    calls.push(String(input));
    return new Response(JSON.stringify({ message: "invalid token" }), { status: 401 });
  }));
  const response = await handler(postRequest(JSON.stringify({ events: [EVENT] })));
  if (response.status !== 401) throw new Error("Invalid access token must return 401");
  if (calls.length !== 1 || !calls[0].endsWith("/auth/v1/user")) {
    throw new Error("Invalid token must stop before the database RPC");
  }
});

Deno.test("valid access token forwards the exact user token and bounded events to the invoker RPC", async () => {
  const calls: Array<{ url: string; init?: RequestInit }> = [];
  const handler = createPlayerSyncHandler(runtime(async (input, init) => {
    const url = String(input);
    calls.push({ url, init });
    if (url.endsWith("/auth/v1/user")) return new Response(JSON.stringify({ id: "user-1" }), { status: 200 });
    if (url.endsWith("/rest/v1/rpc/submit_player_sync_events")) {
      return new Response(JSON.stringify({ accepted: 1, duplicates: 0, authoritative: false }), { status: 200 });
    }
    return new Response(null, { status: 404 });
  }));

  const response = await handler(postRequest(JSON.stringify({ events: [EVENT] })));
  const result = await response.json() as { ok?: boolean; result?: { accepted?: number; authoritative?: boolean } };
  if (response.status !== 200 || result.ok !== true) throw new Error("Valid authenticated batch must succeed");
  if (calls.length !== 2) throw new Error("Expected auth validation followed by exactly one RPC");
  if (!calls[0].url.endsWith("/auth/v1/user")) throw new Error("Auth validation must happen first");
  if (calls[1].url !== PROJECT_URL + "/rest/v1/rpc/submit_player_sync_events") throw new Error("Unexpected RPC destination");
  for (const call of calls) {
    const headers = new Headers(call.init?.headers);
    if (headers.get("Authorization") !== "Bearer " + ACCESS_TOKEN) throw new Error("User token was not forwarded unchanged");
    if (headers.get("apikey") !== PUBLISHABLE_KEY) throw new Error("Publishable key must use the apikey header");
  }
  const rpcBody = JSON.parse(String(calls[1].init?.body)) as { p_events?: unknown[] };
  if (rpcBody.p_events?.length !== 1) throw new Error("RPC must receive the validated event batch");
  if (result.result?.authoritative !== false) throw new Error("Client observations must remain non-authoritative");
});

Deno.test("invalid event batch is rejected after auth and before the RPC", async () => {
  let rpcCalls = 0;
  const handler = createPlayerSyncHandler(runtime(async (input) => {
    if (String(input).endsWith("/auth/v1/user")) return new Response("{}", { status: 200 });
    rpcCalls++;
    return new Response("{}", { status: 200 });
  }));
  const response = await handler(postRequest(JSON.stringify({ events: [] })));
  if (response.status !== 400) throw new Error("Empty event batch must return 400");
  if (rpcCalls !== 0) throw new Error("Invalid batch must not reach the database RPC");
});

Deno.test("oversized body is rejected after authentication without database writes", async () => {
  let rpcCalls = 0;
  const handler = createPlayerSyncHandler(runtime(async (input) => {
    if (String(input).endsWith("/auth/v1/user")) return new Response("{}", { status: 200 });
    rpcCalls++;
    return new Response("{}", { status: 200 });
  }));
  const oversized = "x".repeat(512 * 1024 + 1);
  const response = await handler(postRequest(oversized));
  if (response.status !== 413) throw new Error("Oversized body must return 413");
  if (rpcCalls !== 0) throw new Error("Oversized body must not reach the database RPC");
});

Deno.test("per-account database rate limit is returned as HTTP 429", async () => {
  const handler = createPlayerSyncHandler(runtime(async (input) => {
    if (String(input).endsWith("/auth/v1/user")) return new Response("{}", { status: 200 });
    return new Response(JSON.stringify({ message: "sync_rate_limited" }), { status: 400 });
  }));
  const response = await handler(postRequest(JSON.stringify({ events: [EVENT] })));
  const body = await response.json() as { error?: string };
  if (response.status !== 429 || body.error !== "rate_limited") throw new Error("Database rate limit must map to HTTP 429");
  if (response.headers.get("Retry-After") !== "60") throw new Error("Rate limit retry hint missing");
});
