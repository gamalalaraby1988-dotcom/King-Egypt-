import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const FOUNDER_ID = "king_of_egypt_city:founder:primary";
const FOUNDER_EMAIL = "gamalalaraby1988@gmail.com";
const ENTITLEMENT_TTL_SECONDS = 30 * 24 * 60 * 60;

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

Deno.serve(async (req: Request) => {
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

  const projectUrl = Deno.env.get("SUPABASE_URL");
  const publishableKeysRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  const expectedUserId = Deno.env.get("FOUNDER_AUTH_USER_ID")?.trim().toLowerCase();
  const privateKeyPem = Deno.env.get("FOUNDER_SIGNING_PRIVATE_KEY");

  if (!projectUrl || !publishableKeysRaw || !expectedUserId || !privateKeyPem) {
    return json({ error: "founder_entitlement_not_configured" }, 503);
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(expectedUserId)) {
    return json({ error: "server_configuration_error" }, 503);
  }

  let publishableKey = "";
  try {
    const keys = JSON.parse(publishableKeysRaw);
    publishableKey = String(keys.default ?? "");
  } catch {
    return json({ error: "server_configuration_error" }, 503);
  }
  if (!publishableKey) {
    return json({ error: "server_configuration_error" }, 503);
  }

  // Resolve the caller through Auth itself; never trust email/user metadata supplied by the client.
  let userResponse: Response;
  try {
    userResponse = await fetch(`${projectUrl.replace(/\/$/, "")}/auth/v1/user`, {
      headers: {
        "apikey": publishableKey,
        "Authorization": authHeader,
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
      return json({ error: "unauthorized" }, 401);
    }
    user = parsed as Record<string, unknown>;
  } catch {
    return json({ error: "auth_response_invalid" }, 502);
  }

  const verifiedEmail = String(user.email ?? "").trim().toLowerCase();
  if (
    String(user.id ?? "").toLowerCase() !== expectedUserId ||
    verifiedEmail !== FOUNDER_EMAIL ||
    !user.email_confirmed_at
  ) {
    return json({ error: "founder_identity_not_authorized" }, 403);
  }

  try {
    const now = Math.floor(Date.now() / 1000);
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
});
