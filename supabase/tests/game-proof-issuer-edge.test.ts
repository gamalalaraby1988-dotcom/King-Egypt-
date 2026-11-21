import { createGameProofIssuerHandler, type GameProofIssuerRuntime } from "../functions/game-proof-issuer/index.ts";

const USER_ID = "00000000-0000-4000-8000-000000000061";
const EVENT_ID = "60000000-0000-4000-8000-000000000011";
const PROOF_ID = "70000000-0000-4000-8000-000000000011";
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

function runtime(fetcher: typeof fetch, overrides: Record<string, string | undefined> = {}): GameProofIssuerRuntime {
  const values: Record<string, string | undefined> = {
    SUPABASE_URL: "https://project.example",
    SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({ default: PUBLISHABLE_KEY }),
    SUPABASE_SECRET_KEYS: JSON.stringify({ default: SECRET_KEY }),
    KING_CITY_PROOF_HMAC_SECRET_B64: SECRET_B64,
    ...overrides,
  };
  return { env: (name) => values[name], fetcher, nowSeconds: () => NOW };
}

async function signedBody(activityId = "mission.progress_only_test") {
  const issuedAt = NOW;
  const expiresAt = issuedAt + 300;
  const canonical = `v1|${USER_ID}|mission|${activityId}|${EVENT_ID}|${issuedAt}|${expiresAt}`;
  const message = new TextEncoder().encode(canonical);
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", message));
  const key = await crypto.subtle.importKey("raw", toArrayBuffer(SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, message));
  const hex = (bytes: Uint8Array) => Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return {
    user_id: USER_ID,
    activity_kind: "mission",
    activity_id: activityId,
    server_event_id: EVENT_ID,
    issued_at: issuedAt,
    expires_at: expiresAt,
    evidence_digest_hex: hex(digest),
    signature_hex: hex(signature),
  };
}

function post(body: unknown, apikey = PUBLISHABLE_KEY) {
  return new Request("https://edge.example/game-proof-issuer", {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey },
    body: JSON.stringify(body),
  });
}

Deno.test("rejects wrong method before any database request", async () => {
  let calls = 0;
  const handler = createGameProofIssuerHandler(runtime(async () => { calls++; return new Response("{}"); }));
  const response = await handler(new Request("https://edge.example", { method: "GET" }));
  if (response.status !== 405 || calls !== 0) throw new Error("method gate failed");
});

Deno.test("rejects missing server configuration", async () => {
  const handler = createGameProofIssuerHandler(runtime(fetch, { KING_CITY_PROOF_HMAC_SECRET_B64: undefined }));
  const response = await handler(post(await signedBody()));
  if (response.status !== 503) throw new Error("missing HMAC secret must fail closed");
});

Deno.test("rejects a caller without the publishable API key", async () => {
  let calls = 0;
  const handler = createGameProofIssuerHandler(runtime(async () => { calls++; return new Response("{}"); }));
  const response = await handler(post(await signedBody(), "wrong"));
  if (response.status !== 401 || calls !== 0) throw new Error("API key gate failed");
});

Deno.test("rejects malformed activity payloads", async () => {
  let calls = 0;
  const handler = createGameProofIssuerHandler(runtime(async () => { calls++; return new Response("{}"); }));
  const body = await signedBody();
  body.activity_id = "../wallet";
  const response = await handler(post(body));
  if (response.status !== 400 || calls !== 0) throw new Error("activity allowlist failed");
});

Deno.test("rejects digest mismatch before database writes", async () => {
  let calls = 0;
  const handler = createGameProofIssuerHandler(runtime(async () => { calls++; return new Response("{}"); }));
  const body = await signedBody();
  body.evidence_digest_hex = "00".repeat(32);
  const response = await handler(post(body));
  if (response.status !== 401 || calls !== 0) throw new Error("digest validation failed");
});

Deno.test("rejects invalid HMAC signatures before database writes", async () => {
  let calls = 0;
  const handler = createGameProofIssuerHandler(runtime(async () => { calls++; return new Response("{}"); }));
  const body = await signedBody();
  body.signature_hex = "00".repeat(32);
  const response = await handler(post(body));
  if (response.status !== 401 || calls !== 0) throw new Error("HMAC verification failed");
});

Deno.test("persists server progress when reward catalog is disabled without creating a proof", async () => {
  let calls = 0;
  const handler = createGameProofIssuerHandler(runtime(async (input, init) => {
    calls++;
    if (!String(input).endsWith("/rpc/record_server_verified_activity_progress")) throw new Error("wrong RPC");
    const headers = new Headers(init?.headers);
    if (headers.get("apikey") !== SECRET_KEY) throw new Error("trusted secret key not forwarded");
    return Response.json({
      progress_recorded: true,
      duplicate: false,
      reward_eligible: false,
      proof_id: null,
    });
  }));
  const response = await handler(post(await signedBody()));
  const data = await response.json();
  if (response.status !== 200 || calls !== 1 || data.progress_recorded !== true || data.reward_eligible !== false || data.proof_id !== null) {
    throw new Error("progress-only completion was not acknowledged safely");
  }
});

Deno.test("returns a proof only when the server catalog allowed rewards at completion", async () => {
  const handler = createGameProofIssuerHandler(runtime(async () => Response.json({
    progress_recorded: true,
    duplicate: false,
    reward_eligible: true,
    proof_id: PROOF_ID,
  })));
  const response = await handler(post(await signedBody("mission.progress_reward_test")));
  const data = await response.json();
  if (response.status !== 200 || data.proof_id !== PROOF_ID || data.reward_eligible !== true) {
    throw new Error("reward-eligible proof response was not preserved");
  }
});

Deno.test("maps server event replay conflicts to HTTP 409", async () => {
  const handler = createGameProofIssuerHandler(runtime(async () => new Response(
    JSON.stringify({ message: "server_progress_event_conflict" }),
    { status: 409 },
  )));
  const response = await handler(post(await signedBody()));
  if (response.status !== 409) throw new Error("event conflict must be rejected");
});

Deno.test("fails closed when the progress database is unavailable", async () => {
  const handler = createGameProofIssuerHandler(runtime(async () => { throw new Error("offline"); }));
  const response = await handler(post(await signedBody()));
  if (response.status !== 503) throw new Error("database outage must not be acknowledged as saved");
});
