-- Lock down test party creation until authoritative server-side player position validation exists.
-- Emit a sanitized server-originated event when a party row is inserted.
revoke all on function game_private.start_my_test_party(text) from public, anon, authenticated;

create or replace function game_private.broadcast_test_party_started()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, game_test, game_private, realtime
as $function$
declare
  v_host_display_name text;
begin
  select nullif(btrim(p.display_name), '')
    into v_host_display_name
    from game_test.player_profiles p
   where p.test_account_id = new.host_account_id;

  perform realtime.send(
    jsonb_build_object(
      'party_id', new.party_id,
      'station_key', new.station_key,
      'host_display_name', left(coalesce(v_host_display_name, 'لاعب'), 24),
      'started_at', new.started_at,
      'ends_at', new.ends_at
    ),
    'party_started',
    'party:city:events',
    true
  );

  return new;
end;
$function$;

revoke all on function game_private.broadcast_test_party_started() from public, anon, authenticated;

drop trigger if exists party_sessions_broadcast_started on game_test.party_sessions;
create trigger party_sessions_broadcast_started
after insert on game_test.party_sessions
for each row
execute function game_private.broadcast_test_party_started();

drop policy if exists test_party_events_read on realtime.messages;
create policy test_party_events_read
on realtime.messages
for select
to authenticated
using (realtime.topic() = 'party:city:events');
