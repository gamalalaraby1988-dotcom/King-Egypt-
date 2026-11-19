-- Isolated synthetic-only wallet transaction prototype.
-- Not a production economy schema or client-facing RPC.
create schema if not exists game_test;

create table if not exists game_test.wallets (
  test_account_id uuid primary key,
  balance bigint not null default 0 check (balance >= 0),
  created_at timestamptz not null default now()
);

create table if not exists game_test.ledger (
  ledger_id bigint generated always as identity primary key,
  test_account_id uuid not null references game_test.wallets(test_account_id),
  delta bigint not null check (delta <> 0),
  balance_after bigint not null check (balance_after >= 0),
  request_key text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists game_test.idempotency_requests (
  request_key text primary key,
  operation text not null,
  test_account_id uuid not null references game_test.wallets(test_account_id),
  created_at timestamptz not null default now()
);

alter table game_test.idempotency_requests
  add column if not exists delta bigint,
  add column if not exists balance_after bigint;

alter table game_test.wallets enable row level security;
alter table game_test.ledger enable row level security;
alter table game_test.idempotency_requests enable row level security;

revoke all on schema game_test from public, anon, authenticated, service_role;
revoke all on all tables in schema game_test from public, anon, authenticated, service_role;
revoke all on all sequences in schema game_test from public, anon, authenticated, service_role;

create or replace function game_test.apply_test_delta(
  p_test_account_id uuid,
  p_request_key text,
  p_operation text,
  p_delta bigint
)
returns table (applied boolean, resulting_balance bigint, replayed boolean)
language plpgsql
security definer
set search_path = pg_catalog, game_test
as $$
declare
  v_existing game_test.idempotency_requests%rowtype;
  v_balance bigint;
  v_new_balance numeric;
  v_inserted_key text;
begin
  if p_test_account_id is null or p_request_key is null
     or length(p_request_key) < 8 or length(p_request_key) > 128
     or p_operation is null or length(p_operation) < 1 or length(p_operation) > 64
     or p_delta is null or p_delta = 0 then
    raise exception 'invalid test operation';
  end if;

  insert into game_test.idempotency_requests(request_key, operation, test_account_id, delta)
  values (p_request_key, p_operation, p_test_account_id, p_delta)
  on conflict (request_key) do nothing
  returning request_key into v_inserted_key;

  if v_inserted_key is null then
    select * into v_existing from game_test.idempotency_requests
    where request_key = p_request_key for update;
    if v_existing.test_account_id <> p_test_account_id
       or v_existing.operation <> p_operation or v_existing.delta <> p_delta then
      raise exception 'idempotency key conflict';
    end if;
    if v_existing.balance_after is null then raise exception 'request is not finalized'; end if;
    return query select false, v_existing.balance_after, true;
    return;
  end if;

  select balance into v_balance from game_test.wallets
  where test_account_id = p_test_account_id for update;
  if not found then raise exception 'test account not found'; end if;

  v_new_balance := v_balance::numeric + p_delta::numeric;
  if v_new_balance < 0 then raise exception 'insufficient test balance'; end if;
  if v_new_balance > 9223372036854775807::numeric then raise exception 'balance overflow'; end if;

  update game_test.wallets set balance = v_new_balance::bigint
  where test_account_id = p_test_account_id;
  insert into game_test.ledger(test_account_id, delta, balance_after, request_key)
  values (p_test_account_id, p_delta, v_new_balance::bigint, p_request_key);
  update game_test.idempotency_requests set balance_after = v_new_balance::bigint
  where request_key = p_request_key;

  return query select true, v_new_balance::bigint, false;
end;
$$;

revoke all on function game_test.apply_test_delta(uuid, text, text, bigint)
  from public, anon, authenticated, service_role;
