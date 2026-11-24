import { assertEquals } from "jsr:@std/assert@1";
import { createJetSkiRaceResultsHandler, type JetSkiRaceResultsRuntime } from "../functions/jet-ski-race-results/index.ts";

const SERVER_ID = "city-test-01";
const USER_ID = "10000000-0000-4000-8000-000000000001";
const RACE_ID = "20000000-0000-4000-8000-000000000001";
const EVENT_ID = "30000000-0000-4000-8000-000000000001";
const NONCE = "40000000-0000-4000-8000-000000000001";
const NOW = 1_800_000_000;
const SECRET = new Uint8Array(32).fill(7);
const SECRET_B64 = btoa(String.fromCharCode(...SECRET));
const PUBLISHABLE = "sb_publishable_test";
const SERVICE = "sb_secret_test";
const VALUES: Record<string, string | undefined> = {
  SUPABASE_URL: "https://project.invalid",
  SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({ default: PUBLISHABLE }),
  SUPABASE_SECRET_KEYS: JSON.stringify({ default: SERVICE }),
  JET_SKI_RACE_SERVER_KEYS_JSON: JSON.stringify({ [SERVER_ID]: SECRET_B64 }),
};

function runtime(fetcher: typeof fetch, overrides: Record<string, string | undefined> = {}): JetSkiRaceResultsRuntime {
  const values = { ...VALUES, ...overrides };
  return { env: (name) => values[name], fetcher, nowSeconds: () => NOW };
}

async function signed(body: Record<string, unknown>, nonce = NONCE, timestamp = NOW) {
  const raw = JSON.stringify(body);
  const key = await crypto.subtle.importKey("raw", SECRET, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}\n${nonce}\n${raw}`),
  ));
  const hex = Array.from(signature, (byte) => byte.toString(16).padStart(2, "0")).join("");
  return new Request("https://edge.invalid/jet-ski-race-results", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: PUBLISHABLE,
      "x-king-city-timestamp": String(timestamp),
      "x-king-city-nonce": nonce,
      "x-king-city-signature": hex,
    },
    body: raw,
  });
}

function resultBody(overrides: Record<string, unknown> = {}) {
  return {
    server_id: SERVER_ID,
    race_id: RACE_ID,
    server_event_id: EVENT_ID,
    user_id: USER_ID,
    status: "finished",
    place: 1,
    finish_time_usec: 2_450_000,
    race_finished_at: new Date(NOW * 1000).toISOString(),
    reason: null,
    ...overrides,
  };
}

Deno.test("method, configuration, and API-key guards fail closed", async () => {
  let calls = 0;
  const handler = createJetSkiRaceResultsHandler(runtime(async () => { calls++; return Response.json({}); }));
  assertEquals((await handler(new Request("https://edge.invalid", { method: "GET" }))).status, 405);
  const missing = createJetSkiRaceResultsHandler(runtime(fetch, { JET_SKI_RACE_SERVER_KEYS_JSON: undefined }));
  assertEquals((await missing(await signed(resultBody()))).status, 401);
  const noConfig = createJetSkiRaceResultsHandler(runtime(fetch, { SUPABASE_SECRET_KEYS: undefined }));
  assertEquals((await noConfig(await signed(resultBody()))).status, 503);
  const badKeyReq = await signed(resultBody());
  const headers = new Headers(badKeyReq.headers);
  headers.set("apikey", "wrong");
  assertEquals((await handler(new Request(badKeyReq.url, { method: "POST", headers, body: await badKeyReq.text() }))).status, 401);
  assertEquals(calls, 0);
});

Deno.test("valid signed finish forwards only server-verified fields to service-role RPC", async () => {
  let url = "";
  let payload: Record<string, unknown> = {};
  let headers = new Headers();
  const handler = createJetSkiRaceResultsHandler(runtime(async (input, init) => {
    url = String(input);
    payload = JSON.parse(String(init?.body));
    headers = new Headers(init?.headers);
    return Response.json({
      recorded: true, duplicate: false, egypt_day: "2026-11-24",
      daily_reward_eligible: true, daily_best_place: 1, entitlement_status: "pending_configuration",
    });
  }));
  const request = await signed(resultBody());
  const nonce = request.headers.get("x-king-city-nonce");
  const response = await handler(request);
  const data = await response.json();
  assertEquals(response.status, 200);
  assertEquals(url.endsWith("/rpc/record_jet_ski_race_result"), true);
  assertEquals(headers.get("apikey"), SERVICE);
  assertEquals(payload.p_race_id, RACE_ID);
  assertEquals(payload.p_server_event_id, EVENT_ID);
  assertEquals(payload.p_user_id, USER_ID);
  assertEquals(payload.p_nonce, nonce);
  assertEquals(payload.p_issued_at, new Date(NOW * 1000).toISOString());
  assertEquals(payload.p_race_finished_at, new Date(NOW * 1000).toISOString());
  assertEquals(data.recorded, true);
});

Deno.test("rejects invalid HMAC without contacting the database", async () => {
  let calls = 0;
  const handler = createJetSkiRaceResultsHandler(runtime(async () => { calls++; return Response.json({}); }));
  const request = await signed(resultBody());
  const headers = new Headers(request.headers);
  headers.set("x-king-city-signature", "0".repeat(64));
  const response = await handler(new Request(request.url, { method: "POST", headers, body: await request.text() }));
  assertEquals(response.status, 401);
  assertEquals(calls, 0);
});

Deno.test("valid DNF uses reason and no finish fields", async () => {
  let payload: Record<string, unknown> = {};
  const handler = createJetSkiRaceResultsHandler(runtime(async (_input, init) => {
    payload = JSON.parse(String(init?.body));
    return Response.json({ recorded: true, duplicate: false, daily_reward_eligible: false });
  }));
  const request = await signed(resultBody({
    status: "dnf", place: null, finish_time_usec: null, reason: "disconnect",
  }), "40000000-0000-4000-8000-000000000002");
  assertEquals((await handler(request)).status, 200);
  assertEquals(payload.p_status, "dnf");
  assertEquals(payload.p_reason, "disconnect");
  assertEquals(payload.p_place, null);
});

Deno.test("malformed DNF and unknown fields are rejected before database writes", async () => {
  let calls = 0;
  const handler = createJetSkiRaceResultsHandler(runtime(async () => { calls++; return Response.json({}); }));
  assertEquals((await handler(await signed(resultBody({
    status: "dnf", place: null, finish_time_usec: null, reason: null,
  }), "40000000-0000-4000-8000-000000000003"))).status, 400);
  assertEquals((await handler(await signed(resultBody({ client_rank: 1 }), "40000000-0000-4000-8000-000000000004"))).status, 400);
  assertEquals(calls, 0);
});

Deno.test("nonce replay and conflicting results map to HTTP 409", async () => {
  const replay = createJetSkiRaceResultsHandler(runtime(async () => new Response("jet_ski_race_server_nonce_replayed", { status: 409 })));
  const conflict = createJetSkiRaceResultsHandler(runtime(async () => new Response("jet_ski_race_result_conflict", { status: 409 })));
  assertEquals((await replay(await signed(resultBody(), "40000000-0000-4000-8000-000000000005"))).status, 409);
  assertEquals((await conflict(await signed(resultBody(), "40000000-0000-4000-8000-000000000006"))).status, 409);
});

Deno.test("database outage is not acknowledged as a saved result", async () => {
  const handler = createJetSkiRaceResultsHandler(runtime(async () => { throw new Error("offline"); }));
  assertEquals((await handler(await signed(resultBody(), "40000000-0000-4000-8000-000000000007"))).status, 503);
});

Deno.test("oversized body is rejected", async () => {
  const handler = createJetSkiRaceResultsHandler(runtime(fetch));
  const body = "x".repeat(5000);
  const response = await handler(new Request("https://edge.invalid", {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: PUBLISHABLE, "Content-Length": String(body.length) },
    body,
  }));
  assertEquals(response.status, 413);
});
