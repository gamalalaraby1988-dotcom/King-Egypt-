# Tripo model generator (review draft)

This Edge Function is intentionally isolated on the `feat/tripo-model-generator`
branch. It has **not** been deployed to Supabase.

## Scope

- Generates only the approved `royal_main_tent` asset.
- Uses Tripo API v3 text-to-model and asynchronous task polling.
- Returns the GLB URL and rendered preview URL after successful generation.
- Does not download, store, import, or merge the GLB into Godot.
- The expiring Tripo model URL must be downloaded promptly after success.
- Generation consumes Tripo credits. The caller must explicitly set
  `confirm_generation: true`.

## Required Edge Function secrets

Set these only in the target Supabase project's Edge Function secrets; never
commit their values:

- `TRIPO_API_KEY`: the Tripo API key.
- `TRIPO_ALLOWED_USER_IDS`: comma-separated Supabase Auth user UUIDs permitted
  to generate or inspect tasks. Keep this allowlist empty until the founder's
  exact Auth UUID is verified.

Supabase provides `SUPABASE_URL` and a publishable/anon key to Edge Functions.
The handler validates the Bearer token against Supabase Auth and then checks
the user ID against the explicit allowlist. The gateway JWT check also remains
enabled in `supabase/config.toml`.

## Request

POST JSON to the function:

```json
{
  "action": "create",
  "asset_id": "royal_main_tent",
  "confirm_generation": true
}
```

The response is HTTP 202 with a `task_id`.

Poll with:

```json
{
  "action": "status",
  "task_id": "<task_id returned by create>"
}
```

When status is `success`, the response includes `model_url` (GLB) and
`rendered_image_url`. Tripo says model URLs expire after five minutes.

## Before any deployment

1. Verify the founder's Auth UUID and set the allowlist secret.
2. Verify the Tripo key exists in this exact Supabase project without revealing it.
3. Review the PR and confirm the Tripo account has credits; a create request
   incurs provider usage.
4. Deploy to a non-production Supabase test project first.
5. Generate the tent, download the exact GLB, render that same file in Godot,
   and obtain the user's approval before any scene integration.
6. Do not merge to `main` or deploy to production without separate approval.
