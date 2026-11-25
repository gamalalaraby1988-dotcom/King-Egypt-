import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const FOUNDER_ID = "king_of_egypt_city:founder:primary";
const ENTITLEMENT_TTL_SECONDS = 30 * 24 * 60 * 60;
const MAX_REQUEST_BODY_BYTES = 1024;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export type FounderEntitlementRuntime = {
  env: (name: string) => string | undefined;
  fetcher: (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;
  now: () => number;
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

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalized = pem.trim();
  if (
    !normalized.startsWith("-----BEGIN PRIVATE KEY-----") ||
    !normalized.endsWith("-----END PRIVATE KEY-----")
  ) {
    throw new Error("Expected an unencrypted PKCS#8 PRIVATE KEY PEM.");
  }
  const base64 = normalized
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  if (!base64) throw new Error("Private key PEM is empty.");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function readBoundedBody(req: Request): Promise<string | null> {
  const contentLength = req.headers.get("Content-Length");
  if (
    contentLength &&
    Number.isFinite(Number(contentLength)) &&
    Number(contentLength) > MAX_REQUEST_BODY_BYTES
  ) return null;
  if (!req.body) return "";
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_REQUEST_BODY_BYTES) {
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

function isEmptyJsonObject(body: string): boolean {
  try {
    const parsed: unknown = JSON.parse(body);
    return typeof parsed === "object" && parsed !== null &&
      !Array.isArray(parsed) && Object.keys(parsed).length === 0;
  } catch {
    return false;
  }
}

export function createFounderEntitlementHandler(
  runtime: FounderEntitlementRuntime = {
    env: (name: string) => Deno.env.get(name),
    fetcher: (input: RequestInfo | URL, init?: RequestInit) => fetch(input, init),
    now: () => Date.now(),
  },
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!/^Bearer\s+\S+$/i.test(authHeader)) {
      return json({ error: "unauthorized" }, 401);
    }
    const requestBody = await readBoundedBody(req);
    if (requestBody === null) {
      return json({ error: "request_too_large" }, 413);
    }
    if (
      (req.headers.get("Content-Type") ?? "").split(";")[0].trim().toLowerCase() !== "application/json" ||
      !isEmptyJsonObject(requestBody)
    ) {
      return json({ error: "invalid_request_body" }, 400);
    }

    const projectUrl = runtime.env("SUPABASE_URL")?.trim().replace(/\/$/, "");
    const publishableKeysRaw = runtime.env("SUPABASE_PUBLISHABLE_KEYS");
    const expectedUserId = runtime.env("FOUNDER_AUTH_USER_ID")?.trim().toLowerCase();
    const expectedEmail = runtime.env("FOUNDER_AUTH_EMAIL")?.trim().toLowerCase();
    const privateKeyPem = runtime.env("FOUNDER_SIGNING_PRIVATE_KEY");

    if (!projectUrl || !publishableKeysRaw || !expectedUserId || !expectedEmail || !privateKeyPem) {
      return json({ error: "founder_entitlement_not_configured" }, 503);
    }
    if (!/^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(projectUrl)) {
      return json({ error: "server_configuration_error" }, 503);
    }
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(expectedUserId)) {
      return json({ error: "server_configuration_error" }, 503);
    }
    if (!expectedEmail.includes("@") || expectedEmail.length > 254) {
      return json({ error: "server_configuration_error" }, 503);
    }

    let publishableKey = "";
    try {
      const keys: unknown = JSON.parse(publishableKeysRaw);
      if (typeof keys !== "object" || keys === null || Array.isArray(keys)) {
        return json({ error: "server_configuration_error" }, 503);
      }
      const defaultKey = (keys as Record<string, unknown>).default;
      publishableKey = typeof defaultKey === "string" ? defaultKey.trim() : "";
    } catch {
      return json({ error: "server_configuration_error" }, 503);
    }
    if (!publishableKey.startsWith("sb_publishable_")) {
      return json({ error: "server_configuration_error" }, 503);
    }

    // Resolve the caller through Auth itself; never trust identity claims from the request body.
    let userResponse: Response;
    try {
      userResponse = await runtime.fetcher(projectUrl + "/auth/v1/user", {
        method: "GET",
        headers: {
          "apikey": publishableKey,
          "Authorization": authHeader,
          "Accept": "application/json",
        },
      });
    } catch {
      return json({ error: "auth_service_unavailable" }, 503);
    }
    if (!userResponse.ok) {
      return json({ error: "unauthorized" }, 401);
    }

    let user: Record<string, unknown>;
    try {
      const parsed: unknown = await userResponse.json();
      if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
        return json({ error: "auth_response_invalid" }, 502);
      }
      user = parsed as Record<string, unknown>;
    } catch {
      return json({ error: "auth_response_invalid" }, 502);
    }

    const verifiedEmail = String(user.email ?? "").trim().toLowerCase();
    if (
      String(user.id ?? "").toLowerCase() !== expectedUserId ||
      verifiedEmail !== expectedEmail ||
      typeof user.email_confirmed_at !== "string" ||
      user.email_confirmed_at.trim().length === 0
    ) {
      return json({ error: "founder_identity_not_authorized" }, 403);
    }

    try {
      const now = Math.floor(runtime.now() / 1000);
      const claims = {
        founder_id: FOUNDER_ID,
        subject_id: String(user.id),
        offline_allowed: true,
        issued_at: now,
        expires_at: now + ENTITLEMENT_TTL_SECONDS,
      };
      const payload = JSON.stringify(claims);
      const key = await crypto.subtle.importKey(
        "pkcs8",
        pemToArrayBuffer(privateKeyPem),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
      );
      const signature = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        new TextEncoder().encode(payload),
      );
      return json({ payload, signature: toBase64(new Uint8Array(signature)) });
    } catch {
      // Never include key material or cryptographic exception details in client responses.
      return json({ error: "entitlement_signing_failed" }, 500);
    }
  };
}

if (import.meta.main) {
  Deno.serve(createFounderEntitlementHandler());
}
