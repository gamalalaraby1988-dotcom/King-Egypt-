-- Reject NULL asset types explicitly; SQL three-valued logic must not route NULL to XP.
create or replace function game_test.apply_test_asset_delta(
  p_test_account_id uuid,
  p_request_key text,
  p_operation text,
  p_asset_type text,
  p_delta bigint
)
returns table (applied boolean, resulting_balance bigint, replayed boolean)
language plpgsql
security definer
set search_path = pg_catalog, game_test
as $$
declare
  v_existing game_test.idempotency_requests%rowtype;
  v_cash bigint;
  v_chips bigint;
  v_gems bigint;
  v_balance bigint;
  v_new_balance numeric;
  v_inserted_key text;
begin
  if p_test_account_id is null
     or p_request_key is null
     or length(p_request_key) < 8
     or length(p_request_key) > 128
     or p_operation is null
     or length(p_operation) < 1
     or length(p_operation) > 64
     or p_asset_type is null
     or p_asset_type not in ('cash', 'chips', 'gems', 'xp')
     or p_delta is null
     or p_delta = 0 then
    raise exception 'invalid test operation';
  end if;

  insert into game_test.idempotency_requests(
    request_key, operation, test_account_id, delta, asset_type
  )
  values (
    p_request_key, p_operation, p_test_account_id, p_delta, p_asset_type
  )
  on conflict (request_key) do nothing
  returning request_key into v_inserted_key;

  if v_inserted_key is null then
    select * into v_existing
    from game_test.idempotency_requests
    where request_key = p_request_key
    for update;

    if v_existing.test_account_id <> p_test_account_id
       or v_existing.operation <> p_operation
       or v_existing.delta <> p_delta
       or v_existing.asset_type <> p_asset_type then
      raise exception 'idempotency key conflict';
    end if;

    if v_existing.balance_after is null then
      raise exception 'request is not finalized';
    end if;

    return query select false, v_existing.balance_after, true;
    return;
  end if;

  select cash_balance, chips_balance, gems_balance
  into v_cash, v_chips, v_gems
  from game_test.wallets
  where test_account_id = p_test_account_id
  for update;

  if not found then
    raise exception 'test account not found';
  end if;

  if p_asset_type = 'cash' then
    v_balance := v_cash;
  elsif p_asset_type = 'chips' then
    v_balance := v_chips;
  elsif p_asset_type = 'gems' then
    v_balance := v_gems;
  else
    insert into game_test.account_progress(test_account_id)
    values (p_test_account_id)
    on conflict (test_account_id) do nothing;

    select xp_total into v_balance
    from game_test.account_progress
    where test_account_id = p_test_account_id
    for update;
  end if;

  v_new_balance := v_balance::numeric + p_delta::numeric;
  if v_new_balance < 0 then
    raise exception 'insufficient test asset balance';
  end if;
  if v_new_balance > 9223372036854775807::numeric then
    raise exception 'test asset overflow';
  end if;

  if p_asset_type = 'cash' then
    update game_test.wallets
    set cash_balance = v_new_balance::bigint,
        account_version = account_version + 1,
        updated_at = now()
    where test_account_id = p_test_account_id;
  elsif p_asset_type = 'chips' then
    update game_test.wallets
    set chips_balance = v_new_balance::bigint,
        account_version = account_version + 1,
        updated_at = now()
    where test_account_id = p_test_account_id;
  elsif p_asset_type = 'gems' then
    update game_test.wallets
    set gems_balance = v_new_balance::bigint,
        account_version = account_version + 1,
        updated_at = now()
    where test_account_id = p_test_account_id;
  else
    update game_test.account_progress
    set xp_total = v_new_balance::bigint,
        updated_at = now()
    where test_account_id = p_test_account_id;

    update game_test.wallets
    set account_version = account_version + 1,
        updated_at = now()
    where test_account_id = p_test_account_id;
  end if;

  insert into game_test.ledger(
    test_account_id, delta, balance_after, request_key, asset_type
  )
  values (
    p_test_account_id, p_delta, v_new_balance::bigint, p_request_key, p_asset_type
  );

  update game_test.idempotency_requests
  set balance_after = v_new_balance::bigint
  where request_key = p_request_key;

  return query select true, v_new_balance::bigint, false;
end;
$$;

revoke all on function game_test.apply_test_asset_delta(uuid, text, text, text, bigint)
  from public, anon, authenticated, service_role;
