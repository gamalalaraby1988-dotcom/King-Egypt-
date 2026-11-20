// Legacy result-submission endpoint disabled.
// All future paid and free spins must use slot-machine-spin, where the Edge Function
// generates both the 3-reel result and the 3x3 collection grid with Web Crypto.
// This prevents clients or legacy callers from submitting their own outcomes.
Deno.serve((_req: Request) => new Response(
  JSON.stringify({ error: "legacy_slot_settlement_disabled", use: "slot-machine-spin" }),
  { status: 410, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } },
));
