import { createGameWalkProgressHandler, type GameWalkProgressRuntime } from "../functions/game-walk-progress/index.ts";

const USER_ID = "00000000-0000-4000-8000-000000000061";
const EVENT_ID = "60000000-0000-4000-8000-000000000061";
const NOW = 1_800_000_000;
const SECRET = new Uint8Array(32).fill(0x5a);
const SECRET_B64 = btoa(String.fromCharCode(...SECRET));
const PUBLISHABLE_KEY = "sb_publishable_test";
const SECRET_KEY = "sb_secret_test";

function toArrayBuffer(value: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(value.byteLength);
  copy.set(value);
  return copy.buffer;
}

function runtime(fetcher: typeof fetch, overrides: Record<string, string | undefined> = {}): GameWalkProgressRuntime {
  const values: Record<string, string | undefined> = {
    SUPABASE_URL: "https://project.example",
    SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({ default: PUBLISHABLE_KEY }),
    SUPABASE_SECRET_KEYS: JSON.stringify({ default: SECRET_KEY }),
    KING_CITY_PROOF_HMAC_SECRET_B64: SECRET_B64,
    ...overrides,
  };
  return { env: (name) => values[name], fetcher, nowSeconds: () => NOW };
}

async function sign(canonical: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", toArrayBuffer(SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(canonical)));
  return Array.from(signature, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function recordBody(distance = 4.25) {
  const issuedAt = NOW;
  const expiresAt = issuedAt + 300;
  const canonical = `v1|walk|record|${USER_ID}|${EVENT_ID}|${distance.toFixed(3)}|${issuedAt}|${expiresAt}`;
  return {
    action: "record",
    user_id: USER_ID,
    server_event_id: EVENT_ID,
    distance_meters: distance,
    issued_at: issuedAt,
    expires_at: expiresAt,
    signature_hex: await sign(canonical),
  };
}

async function lookupBody() {
  const issuedAt = NOW;
  return {
    action: "lookup",
    user_id: USER_ID,
    issued_at: issuedAt,
    signature_hex: await sign(`v1|walk|lookup|${USER_ID}|${issuedAt}`),
  };
}

function post(body: unknown, apikey = PUBLISHABLE_KEY) {
  return new Request("https://edge.example/game-walk-progress", {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey },
    body: JSON.stringify(body),
  });
}

Deno.test("rejects wrong method before database access", async () => {
  let calls = 0;
  const handler = createGameWalkProgressHandler(runtime(async () => { calls++; return Response.json(0); }));
  const response = await handler(new Request("https://edge.example", { method: "GET" }));
  if (response.status !== 405 || calls !== 0) throw new Error("method guard failed");
});

Deno.test("fails closed when the HMAC secret is missing", async () => {
  const handler = createGameWalkProgressHandler(runtime(fetch, { KING_CITY_PROOF_HMAC_SECRET_B64: undefined }));
  const response = await handler(post(await recordBody()));
  if (response.status !== 503) throw new Error("missing secret must fail closed");
});

Deno.test("rejects wrong publishable key before database access", async () => {
  let calls = 0;
  const handler = createGameWalkProgressHandler(runtime(async () => { calls++; return Response.json({}); }));
  const response = await handler(post(await recordBody(), "wrong"));
  if (response.status !== 401 || calls !== 0) throw new Error("API key guard failed");
});

Deno.test("rejects increments above five meters before database access", async () => {
  let calls = 0;
  const handler = createGameWalkProgressHandler(runtime(async () => { calls++; return Response.json({}); }));
  const response = await handler(post(await recordBody(5.001)));
  if (response.status !== 400 || calls !== 0) throw new Error("distance upper bound failed");
});

Deno.test("rejects invalid HMAC before database access", async () => {
  let calls = 0;
  const body = await recordBody();
  body.signature_hex = "00".repeat(32);
  const handler = createGameWalkProgressHandler(runtime(async () => { calls++; return Response.json({}); }));
  const response = await handler(post(body));
  if (response.status !== 401 || calls !== 0) throw new Error("HMAC verification failed");
});

Deno.test("records bounded server distance using service role", async () => {
  const handler = createGameWalkProgressHandler(runtime(async (input, init) => {
    if (!String(input).endsWith("/rpc/record_server_verified_walk_distance")) throw new Error("wrong RPC");
    if (new Headers(init?.headers).get("apikey") !== SECRET_KEY) throw new Error("trusted service key not used");
    const body = JSON.parse(String(init?.body));
    if (body.p_user_id !== USER_ID || body.p_server_event_id !== EVENT_ID || body.p_distance_meters !== 4.25) throw new Error("record payload mismatch");
    return Response.json({ recorded: true, duplicate: false, total_meters: 94.25, achievement_unlocked: false });
  }));
  const response = await handler(post(await recordBody()));
  const data = await response.json();
  if (response.status !== 200 || data.verified !== true || data.total_meters !== 94.25 || data.achievement_unlocked !== false) {
    throw new Error("valid distance increment was not recorded");
  }
});

Deno.test("returns the durable account distance for a signed lookup", async () => {
  const handler = createGameWalkProgressHandler(runtime(async (input, init) => {
    if (!String(input).endsWith("/rpc/get_server_verified_walk_distance")) throw new Error("wrong lookup RPC");
    if (new Headers(init?.headers).get("apikey") !== SECRET_KEY) throw new Error("lookup must use service role");
    return Response.json(100.125);
  }));
  const response = await handler(post(await lookupBody()));
  const data = await response.json();
  if (response.status !== 200 || data.verified !== true || data.total_meters !== 100.125) throw new Error("durable distance lookup failed");
});

Deno.test("maps event replay conflicts to HTTP 409", async () => {
  const handler = createGameWalkProgressHandler(runtime(async () => new Response("server_walk_event_conflict", { status: 409 })));
  const response = await handler(post(await recordBody()));
  if (response.status !== 409) throw new Error("event conflict must not be accepted");
});

Deno.test("fails closed when the database is unavailable", async () => {
  const handler = createGameWalkProgressHandler(runtime(async () => { throw new Error("offline"); }));
  const response = await handler(post(await recordBody()));
  if (response.status !== 503) throw new Error("database outage must not be reported as success");
});
