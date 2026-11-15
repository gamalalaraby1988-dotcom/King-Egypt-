-- Report whether the daily chest reward has been configured before enabling claims.
create or replace function game_private.get_my_test_daily_chest_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog
as $function$
declare
  v_account_id uuid;
  v_reward_day date;
  v_claim game_test.daily_chest_claims%rowtype;
  v_reward_configured boolean := false;
  v_is_claimed boolean := false;
begin
  v_account_id := game_private.my_test_account_id();
  if v_account_id is null then
    return jsonb_build_object('status', 'authentication_required');
  end if;
  v_reward_day := (now() at time zone 'Africa/Cairo')::date;
  select * into v_claim from game_test.daily_chest_claims c
  where c.test_account_id = v_account_id and c.reward_day = v_reward_day;
  v_is_claimed := found;
  select (
    coalesce(c.reward_cash, 0) > 0 or coalesce(c.reward_chips, 0) > 0 or coalesce(c.reward_xp, 0) > 0
  ) into v_reward_configured
  from game_test.daily_chest_reward_config c where c.singleton = true;
  return jsonb_build_object(
    'status', case when v_is_claimed then 'claimed' else 'available' end,
    'reward_configured', coalesce(v_reward_configured, false),
    'reward_day', v_reward_day,
    'next_reset_at', ((v_reward_day + 1)::timestamp at time zone 'Africa/Cairo'),
    'claimed_at', case when v_is_claimed then v_claim.claimed_at else null end
  );
end;
$function$;
revoke all on function game_private.get_my_test_daily_chest_status() from public, anon, authenticated;
grant execute on function game_private.get_my_test_daily_chest_status() to authenticated;
