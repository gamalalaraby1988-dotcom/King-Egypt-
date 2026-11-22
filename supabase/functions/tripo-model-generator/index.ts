import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const TRIPO_BASE = "https://openapi.tripo3d.ai/v3";
const MODEL_VERSION = "v3.1-20260211";
const ASSET_ID = "royal_main_tent";

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers });
}

function allowedUsers(): Set<string> {
  return new Set(
    (Deno.env.get("TRIPO_ALLOWED_USER_IDS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

async function authenticate(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY");

  if (!authorization || !supabaseUrl || !publishableKey) return null;

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      authorization,
      apikey: publishableKey,
    },
  });
  if (!response.ok) return null;

  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

async function tripoRequest(path: string, init: RequestInit) {
  const apiKey = Deno.env.get("TRIPO_API_KEY");
  if (!apiKey) throw new Error("TRIPO_API_KEY is not configured");

  const response = await fetch(`${TRIPO_BASE}${path}`, {
    ...init,
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload?.code !== 0) {
    // Never return upstream headers or credentials to the caller.
    throw new Error(
      typeof payload?.message === "string"
        ? payload.message
        : `Tripo request failed with HTTP ${response.status}`,
    );
  }
  return payload.data;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  const userId = await authenticate(req);
  if (!userId) return json(401, { error: "Authentication required" });

  const allowlist = allowedUsers();
  if (allowlist.size === 0 || !allowlist.has(userId)) {
    return json(403, { error: "This account is not authorized to generate models" });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Invalid JSON body" });
  }

  try {
    if (body.action === "create") {
      if (body.asset_id !== ASSET_ID || body.confirm_generation !== true) {
        return json(400, {
          error: "Explicit confirmation for the approved royal tent asset is required",
        });
      }

      const prompt = [
        "Create one production-quality, standalone 3D GLB model of an extravagant",
        "ancient Egyptian royal desert reception tent for a premium social game.",
        "One large central square pavilion, elegant sand-colored woven fabric,",
        "rich restrained royal-gold trim, deep lapis-blue Egyptian geometric borders,",
        "four ornate structural corner posts, open welcoming front entrance,",
        "layered peaked canopy with believable fabric folds, tasteful pharaonic motifs.",
        "Include only the tent structure and its fabric; no ground plane, no people,",
        "no animals, no text, no watermark, no surrounding camp props.",
        "Game-ready clean topology, coherent scale, centered pivot, detailed PBR materials.",
      ].join(" ");

      const task = await tripoRequest("/generation/text-to-model", {
        method: "POST",
        body: JSON.stringify({
          prompt,
          model: MODEL_VERSION,
          texture: true,
          pbr: true,
          texture_quality: "standard",
          face_limit: 30000,
        }),
      });

      if (typeof task?.task_id !== "string") {
        return json(502, { error: "Tripo did not return a task ID" });
      }
      return json(202, {
        asset_id: ASSET_ID,
        task_id: task.task_id,
        status: "queued",
        message: "Generation started. Query this task to retrieve its GLB when complete.",
      });
    }

    if (body.action === "status") {
      const taskId = body.task_id;
      if (
        typeof taskId !== "string" ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
          .test(taskId)
      ) {
        return json(400, { error: "A valid task_id is required" });
      }

      const task = await tripoRequest(
        `/tasks/${encodeURIComponent(taskId)}`,
        { method: "GET" },
      );
      const output = task?.output ?? {};
      return json(200, {
        asset_id: ASSET_ID,
        task_id: task.task_id,
        status: task.status,
        progress: task.progress,
        model_url: task.status === "success" ? output.model_url ?? null : null,
        rendered_image_url: task.status === "success"
          ? output.rendered_image_url ?? null
          : null,
        error: task.status === "failed"
          ? task.error_message ?? task.message ?? null
          : null,
      });
    }

    return json(400, { error: "Unsupported action" });
  } catch (error) {
    // Keep internal configuration and provider details out of public responses.
    console.error("tripo-model-generator failed:", error);
    return json(502, { error: "The model provider request failed; check server logs" });
  }
});
