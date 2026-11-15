create or replace function game_private.change_my_test_display_name(p_new_display_name text)
returns table(success boolean, current_display_name text, next_change_at timestamptz, error_code text)
language plpgsql
security definer
set search_path to 'pg_catalog'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_account_id uuid;
  v_new_name text := btrim(coalesce(p_new_display_name, ''));
  v_old_name text;
  v_last_change timestamptz;
  v_now timestamptz := now();
  v_next_change timestamptz;
begin
  if v_user_id is null then
    return query select false, null::text, null::timestamptz, 'authentication_required'; return;
  end if;
  if char_length(v_new_name) < 1 or char_length(v_new_name) > 24 then
    return query select false, null::text, null::timestamptz, 'invalid_display_name'; return;
  end if;
  select l.test_account_id into v_account_id
  from game_test.auth_account_links l where l.auth_user_id = v_user_id;
  if v_account_id is null then
    return query select false, null::text, null::timestamptz, 'test_account_not_linked'; return;
  end if;
  insert into game_test.player_profiles (test_account_id) values (v_account_id)
  on conflict (test_account_id) do nothing;
  select p.display_name, p.last_name_change_at into v_old_name, v_last_change
  from game_test.player_profiles p where p.test_account_id = v_account_id for update;
  if v_old_name is not null and lower(v_old_name) = lower(v_new_name) then
    return query select false, v_old_name, null::timestamptz, 'name_unchanged'; return;
  end if;
  if v_last_change is not null
     and (v_last_change at time zone 'Africa/Cairo')::date = (v_now at time zone 'Africa/Cairo')::date then
    v_next_change := (date_trunc('day', v_now at time zone 'Africa/Cairo') + interval '1 day') at time zone 'Africa/Cairo';
    return query select false, v_old_name, v_next_change, 'daily_limit_reached'; return;
  end if;
  update game_test.player_profiles p
  set display_name = v_new_name, last_name_change_at = v_now, updated_at = v_now
  where p.test_account_id = v_account_id;
  return query select true, v_new_name,
    (date_trunc('day', v_now at time zone 'Africa/Cairo') + interval '1 day') at time zone 'Africa/Cairo',
    null::text;
exception when unique_violation then
  return query select false, v_old_name, null::timestamptz, 'display_name_taken';
end;
$function$;

create or replace function public.get_my_test_display_name()
returns table(display_name text, last_name_change_at timestamptz, next_change_at timestamptz)
language sql
stable
set search_path to 'pg_catalog', 'game_test'
as $function$
  select
    p.display_name,
    p.last_name_change_at,
    case
      when p.last_name_change_at is null then null::timestamptz
      else (
        date_trunc('day', p.last_name_change_at at time zone 'Africa/Cairo')
        + interval '1 day'
      ) at time zone 'Africa/Cairo'
    end as next_change_at
  from game_test.auth_account_links l
  join game_test.player_profiles p
    on p.test_account_id = l.test_account_id
  where l.auth_user_id = (select auth.uid())
  limit 1;
$function$;