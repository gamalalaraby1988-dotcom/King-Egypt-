import { createGameProgressLookupHandler, type GameProgressLookupRuntime } from "../functions/game-progress-lookup/index.ts";

const USER_ID = "00000000-0000-4000-8000-000000000061";
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

function runtime(fetcher: typeof fetch, overrides: Record<string, string | undefined> = {}): GameProgressLookupRuntime {
  const values: Record<string, string | undefined> = {
    SUPABASE_URL: "https://project.example",
    SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({ default: PUBLISHABLE_KEY }),
    SUPABASE_SECRET_KEYS: JSON.stringify({ default: SECRET_KEY }),
    KING_CITY_PROOF_HMAC_SECRET_B64: SECRET_B64,
    ...overrides,
  };
  return { env: (name) => values[name], fetcher, nowSeconds: () => NOW };
}

async function signedBody(activityId = "mission_shop") {
  const issuedAt = NOW;
  const canonical = `v1|lookup|${USER_ID}|mission|${activityId}|${issuedAt}`;
  const message = new TextEncoder().encode(canonical);
  const key = await crypto.subtle.importKey("raw", toArrayBuffer(SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, message));
  const hex = (bytes: Uint8Array) => Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return { user_id: USER_ID, activity_kind: "mission", activity_id: activityId, issued_at: issuedAt, signature_hex: hex(signature) };
}

function post(body: unknown, apikey = PUBLISHABLE_KEY) {
  return new Request("https://edge.example/game-progress-lookup", {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey },
    body: JSON.stringify(body),
  });
}

Deno.test("rejects wrong method before database access", async () => {
  let calls = 0;
  const handler = createGameProgressLookupHandler(runtime(async () => { calls++; return Response.json(false); }));
  const response = await handler(new Request("https://edge.example", { method: "GET" }));
  if (response.status !== 405 || calls !== 0) throw new Error("method guard failed");
});

Deno.test("rejects missing configuration", async () => {
  const handler = createGameProgressLookupHandler(runtime(fetch, { KING_CITY_PROOF_HMAC_SECRET_B64: undefined }));
  const response = await handler(post(await signedBody()));
  if (response.status !== 503) throw new Error("missing HMAC secret must fail closed");
});

Deno.test("rejects wrong publishable key", async () => {
  let calls = 0;
  const handler = createGameProgressLookupHandler(runtime(async () => { calls++; return Response.json(false); }));
  const response = await handler(post(await signedBody(), "wrong"));
  if (response.status !== 401 || calls !== 0) throw new Error("API key guard failed");
});

Deno.test("allows only known one-time building missions", async () => {
  let calls = 0;
  const handler = createGameProgressLookupHandler(runtime(async () => { calls++; return Response.json(false); }));
  const response = await handler(post(await signedBody("city_adventure_treasure")));
  if (response.status !== 400 || calls !== 0) throw new Error("mission id allowlist failed");
});

Deno.test("rejects invalid HMAC before querying the database", async () => {
  let calls = 0;
  const handler = createGameProgressLookupHandler(runtime(async () => { calls++; return Response.json(false); }));
  const body = await signedBody();
  body.signature_hex = "00".repeat(32);
  const response = await handler(post(body));
  if (response.status !== 401 || calls !== 0) throw new Error("HMAC verification failed");
});

Deno.test("returns completed true for a server-verified mission", async () => {
  const handler = createGameProgressLookupHandler(runtime(async (input, init) => {
    if (!String(input).endsWith("/rpc/has_player_verified_activity")) throw new Error("wrong RPC");
    if (new Headers(init?.headers).get("apikey") !== SECRET_KEY) throw new Error("trusted service key not used");
    return Response.json(true);
  }));
  const response = await handler(post(await signedBody()));
  const data = await response.json();
  if (response.status !== 200 || data.verified !== true || data.completed !== true) throw new Error("verified completion was not returned");
});

Deno.test("returns completed false when no server record exists", async () => {
  const handler = createGameProgressLookupHandler(runtime(async () => Response.json(false)));
  const response = await handler(post(await signedBody()));
  const data = await response.json();
  if (response.status !== 200 || data.verified !== true || data.completed !== false) throw new Error("missing completion was not reported");
});

Deno.test("fails closed when the progress database is unavailable", async () => {
  const handler = createGameProgressLookupHandler(runtime(async () => { throw new Error("offline"); }));
  const response = await handler(post(await signedBody()));
  if (response.status !== 503) throw new Error("database outage must not look like an incomplete mission");
});
