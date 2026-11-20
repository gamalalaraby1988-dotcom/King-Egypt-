-- Retire the 30-day monthly puzzle backend only.
-- The approved three-day royal puzzle is a separate system and is not touched.

drop function if exists public.exchange_monthly_puzzle_pieces(uuid, uuid, text, integer, text, integer, uuid);
drop function if exists private.exchange_monthly_puzzle_pieces(uuid, uuid, text, integer, text, integer, uuid);

drop function if exists public.claim_verified_puzzle_piece(uuid);
drop function if exists private.claim_verified_puzzle_piece(uuid);

drop function if exists public.issue_server_puzzle_piece_proof(
    uuid, uuid, text, text, text, uuid, text, timestamptz, timestamptz
);

drop table if exists private.player_puzzle_piece_claims;
drop table if exists private.player_puzzle_piece_proofs;
drop table if exists private.puzzle_piece_exchanges;
drop table if exists private.player_puzzle_piece_balances;
drop table if exists private.puzzle_piece_catalog;
drop table if exists private.puzzle_seasons;
