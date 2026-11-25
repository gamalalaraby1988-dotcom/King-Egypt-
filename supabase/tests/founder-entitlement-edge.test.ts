import { createFounderEntitlementHandler, type FounderEntitlementRuntime } from "../functions/founder-entitlement/index.ts";

const PROJECT_URL = "https://founder-test.supabase.co";
const PUBLISHABLE_KEY = "sb_publishable_test_only";
const ACCESS_TOKEN = "test-founder-access-token";
const FOUNDER_USER_ID = "123e4567-e89b-12d3-a456-426614174000";
const FOUNDER_EMAIL = "founder@example.test";
const NOW_MS = 1_800_000_000_000;

function pem(label: string, bytes: ArrayBuffer): string {
  const binary = String.fromCharCode(...new Uint8Array(bytes));
  const base64 = btoa(binary).match(/.{1,64}/g)?.join("\n") ?? "";
  return `-----BEGIN ${label}-----\n${base64}\n-----END ${label}-----`;
}

async function createSigningKeys() {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  ) as CryptoKeyPair;
  const privateDer = await crypto.subtle.exportKey("pkcs8", pair.privateKey);
  const publicDer = await crypto.subtle.exportKey("spki", pair.publicKey);
  return {
    privateKeyPem: pem("PRIVATE KEY", privateDer),
    publicKey: await crypto.subtle.importKey(
      "spki",
      publicDer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    ),
  };
}

function env(overrides: Record<string, string | undefined> = {}) {
  const values: Record<string, string | undefined> = {
    SUPABASE_URL: PROJECT_URL + "/",
    SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({ default: PUBLISHABLE_KEY }),
    FOUNDER_AUTH_USER_ID: FOUNDER_USER_ID,
    FOUNDER_AUTH_EMAIL: FOUNDER_EMAIL,
    FOUNDER_SIGNING_PRIVATE_KEY: "configured-by-test",
    ...overrides,
  };
  return (name: string) => values[name];
}

function postRequest(body = "{}", authorization = "Bearer " + ACCESS_TOKEN): Request {
  return new Request("https://edge-test.example/founder-entitlement", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(authorization ? { Authorization: authorization } : {}),
    },
    body,
  });
}

function runtime(
  fetcher: FounderEntitlementRuntime["fetcher"],
  overrides: Record<string, string | undefined> = {},
  privateKeyPem = "configured-by-test",
): FounderEntitlementRuntime {
  return {
    env: env({ FOUNDER_SIGNING_PRIVATE_KEY: privateKeyPem, ...overrides }),
    fetcher,
    now: () => NOW_MS,
  };
}

Deno.test("preflight and non-POST methods do not call Supabase", async () => {
  let calls = 0;
  const handler = createFounderEntitlementHandler(runtime(async () => {
    calls++;
    return new Response(null, { status: 500 });
  }));

  const options = await handler(new Request("https://edge-test.example/founder-entitlement", { method: "OPTIONS" }));
  const get = await handler(new Request("https://edge-test.example/founder-entitlement", { method: "GET" }));

  if (options.status !== 200) throw new Error("OPTIONS must return 200");
  if (options.headers.get("Access-Control-Allow-Methods") !== "POST, OPTIONS") throw new Error("CORS methods missing");
  if (get.status !== 405) throw new Error("Non-POST methods must return 405");
  if (calls !== 0) throw new Error("Preflight/method checks must not call Supabase");
});

Deno.test("missing or malformed bearer token is rejected before Auth lookup", async () => {
  let calls = 0;
  const handler = createFounderEntitlementHandler(runtime(async () => {
    calls++;
    return new Response("{}", { status: 200 });
  }));

  const missing = await handler(postRequest("{}", ""));
  const malformed = await handler(postRequest("{}", "Bearer "));
  if (missing.status !== 401 || malformed.status !== 401) throw new Error("Invalid bearer token must return 401");
  if (calls !== 0) throw new Error("Unauthenticated request reached Supabase Auth");
});

Deno.test("only a small empty JSON object is accepted as the request body", async () => {
  let calls = 0;
  const handler = createFounderEntitlementHandler(runtime(async () => {
    calls++;
    return new Response("{}", { status: 200 });
  }));

  const claims = await handler(postRequest(JSON.stringify({ subject_id: FOUNDER_USER_ID })));
  const malformed = await handler(postRequest("{"));
  const oversized = await handler(postRequest(JSON.stringify({ padding: "x".repeat(2048) })));
  if (claims.status !== 400 || malformed.status !== 400 || oversized.status !== 413) {
    throw new Error("Client-supplied claims and malformed JSON must return 400; oversized bodies must return 413");
  }
  if (calls !== 0) throw new Error("Invalid request body reached Supabase Auth");
});

Deno.test("missing server configuration fails closed", async () => {
  const handler = createFounderEntitlementHandler(runtime(
    async () => new Response("{}", { status: 200 }),
    { FOUNDER_AUTH_USER_ID: undefined },
  ));
  const response = await handler(postRequest());
  if (response.status !== 503) throw new Error("Missing founder identity configuration must return 503");
});

Deno.test("invalid access token is rejected before signing", async () => {
  const calls: string[] = [];
  const handler = createFounderEntitlementHandler(runtime(async (input) => {
    calls.push(String(input));
    return new Response(JSON.stringify({ message: "invalid token" }), { status: 401 });
  }));
  const response = await handler(postRequest());
  if (response.status !== 401) throw new Error("Invalid Auth token must return 401");
  if (calls.length !== 1 || calls[0] !== PROJECT_URL + "/auth/v1/user") {
    throw new Error("Invalid token must stop after the Auth user lookup");
  }
});

Deno.test("wrong user, wrong email, and unconfirmed email cannot receive founder entitlement", async () => {
  const cases = [
    { id: "223e4567-e89b-12d3-a456-426614174000", email: FOUNDER_EMAIL, email_confirmed_at: "2026-01-01T00:00:00Z" },
    { id: FOUNDER_USER_ID, email: "attacker@example.test", email_confirmed_at: "2026-01-01T00:00:00Z" },
    { id: FOUNDER_USER_ID, email: FOUNDER_EMAIL, email_confirmed_at: null },
  ];
  for (const user of cases) {
    const handler = createFounderEntitlementHandler(runtime(async () =>
      new Response(JSON.stringify(user), { status: 200 })
    ));
    const response = await handler(postRequest());
    if (response.status !== 403) throw new Error("Non-founder or unconfirmed account was not rejected");
  }
});

Deno.test("valid founder receives a signed 30-day entitlement bound to Auth user", async () => {
  const keys = await createSigningKeys();
  const calls: Array<{ url: string; init?: RequestInit }> = [];
  const handler = createFounderEntitlementHandler(runtime(async (input, init) => {
    calls.push({ url: String(input), init });
    return new Response(JSON.stringify({
      id: FOUNDER_USER_ID,
      email: FOUNDER_EMAIL,
      email_confirmed_at: "2026-01-01T00:00:00Z",
    }), { status: 200 });
  }, {}, keys.privateKeyPem));

  const response = await handler(postRequest());
  const result = await response.json() as { payload?: string; signature?: string };
  if (response.status !== 200 || !result.payload || !result.signature) {
    throw new Error("Authorized founder must receive a signed entitlement");
  }
  if (calls.length !== 1 || calls[0].url !== PROJECT_URL + "/auth/v1/user") {
    throw new Error("Handler must resolve identity through Supabase Auth exactly once");
  }
  const headers = new Headers(calls[0].init?.headers);
  if (headers.get("Authorization") !== "Bearer " + ACCESS_TOKEN) throw new Error("User access token was not forwarded unchanged");
  if (headers.get("apikey") !== PUBLISHABLE_KEY) throw new Error("Publishable key must be sent only as apikey");

  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    keys.publicKey,
    Uint8Array.from(atob(result.signature), (character) => character.charCodeAt(0)),
    new TextEncoder().encode(result.payload),
  );
  if (!valid) throw new Error("Entitlement signature did not verify with the paired public key");

  const claims = JSON.parse(result.payload) as Record<string, unknown>;
  if (claims.founder_id !== "king_of_egypt_city:founder:primary") throw new Error("Founder identity claim mismatch");
  if (claims.subject_id !== FOUNDER_USER_ID) throw new Error("Entitlement subject must be the verified Auth user");
  if (claims.offline_allowed !== true) throw new Error("Offline entitlement claim missing");
  if (claims.issued_at !== Math.floor(NOW_MS / 1000)) throw new Error("Issued-at timestamp mismatch");
  if (claims.expires_at !== Math.floor(NOW_MS / 1000) + 30 * 24 * 60 * 60) throw new Error("Entitlement must expire after 30 days");
  if (response.headers.get("Cache-Control") !== "no-store") throw new Error("Entitlement response must not be cached");
});

Deno.test("Auth service network errors and signing errors fail without leaking details", async () => {
  const unavailable = createFounderEntitlementHandler(runtime(async () => {
    throw new Error("private network detail");
  }));
  const unavailableResponse = await unavailable(postRequest());
  if (unavailableResponse.status !== 503) throw new Error("Auth network failure must return 503");
  if ((await unavailableResponse.text()).includes("private network detail")) throw new Error("Internal network details leaked");

  const badSigningKey = createFounderEntitlementHandler(runtime(async () =>
    new Response(JSON.stringify({
      id: FOUNDER_USER_ID,
      email: FOUNDER_EMAIL,
      email_confirmed_at: "2026-01-01T00:00:00Z",
    }), { status: 200 })
  ));
  const signingResponse = await badSigningKey(postRequest());
  if (signingResponse.status !== 500) throw new Error("Signing failure must return 500");
  if ((await signingResponse.text()).includes("PRIVATE KEY")) throw new Error("Signing key material leaked");
});
