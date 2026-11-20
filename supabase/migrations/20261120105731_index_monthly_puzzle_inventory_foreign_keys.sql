create index if not exists player_puzzle_piece_balances_season_puzzle_fk_idx
    on private.player_puzzle_piece_balances (season_id, puzzle_id);
create index if not exists player_puzzle_piece_balances_catalog_fk_idx
    on private.player_puzzle_piece_balances (puzzle_id, piece_id);
create index if not exists puzzle_piece_exchanges_season_fk_idx
    on private.puzzle_piece_exchanges (season_id, puzzle_id);
create index if not exists puzzle_piece_exchanges_offered_piece_fk_idx
    on private.puzzle_piece_exchanges (puzzle_id, offered_piece_id);
create index if not exists puzzle_piece_exchanges_requested_piece_fk_idx
    on private.puzzle_piece_exchanges (puzzle_id, requested_piece_id);
