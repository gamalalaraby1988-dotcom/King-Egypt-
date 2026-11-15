-- Index foreign-key columns used to scope synthetic test-account ledger and idempotency lookups.
-- These indexes are part of the isolated game_test prototype only.
create index if not exists idx_ledger_test_account_id
  on game_test.ledger (test_account_id);

create index if not exists idx_idempotency_requests_test_account_id
  on game_test.idempotency_requests (test_account_id);
