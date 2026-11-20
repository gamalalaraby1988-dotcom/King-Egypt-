-- Keep private implementation functions inaccessible to API roles.
-- Public RPC wrappers are narrow SECURITY DEFINER entrypoints with an empty
-- search_path; they only delegate to fixed, schema-qualified private functions.
revoke all on function private.send_friend_request(text) from public, anon, authenticated;
revoke all on function private.respond_friend_request(uuid, boolean) from public, anon, authenticated;
revoke all on function private.list_friend_requests() from public, anon, authenticated;
revoke all on function private.list_friends() from public, anon, authenticated;
revoke all on function private.remove_friend(text) from public, anon, authenticated;
revoke all on function private.block_player(text) from public, anon, authenticated;
revoke all on function private.unblock_player(text) from public, anon, authenticated;
revoke all on function private.list_blocked_players() from public, anon, authenticated;

create or replace function public.send_friend_request(p_player_code text)
returns text language sql security definer set search_path = ''
as $function$ select private.send_friend_request(p_player_code) $function$;
create or replace function public.respond_friend_request(p_request_id uuid, p_accept boolean)
returns text language sql security definer set search_path = ''
as $function$ select private.respond_friend_request(p_request_id, p_accept) $function$;
create or replace function public.list_friend_requests()
returns table (request_id uuid, direction text, player_code text, display_name text, created_at timestamptz)
language sql stable security definer set search_path = ''
as $function$ select * from private.list_friend_requests() $function$;
create or replace function public.list_friends()
returns table (player_code text, display_name text, created_at timestamptz)
language sql stable security definer set search_path = ''
as $function$ select * from private.list_friends() $function$;
create or replace function public.remove_friend(p_player_code text)
returns text language sql security definer set search_path = ''
as $function$ select private.remove_friend(p_player_code) $function$;
create or replace function public.block_player(p_player_code text)
returns text language sql security definer set search_path = ''
as $function$ select private.block_player(p_player_code) $function$;
create or replace function public.unblock_player(p_player_code text)
returns text language sql security definer set search_path = ''
as $function$ select private.unblock_player(p_player_code) $function$;
create or replace function public.list_blocked_players()
returns table (player_code text, display_name text, blocked_at timestamptz)
language sql stable security definer set search_path = ''
as $function$ select * from private.list_blocked_players() $function$;

revoke all on function public.send_friend_request(text) from public, anon;
revoke all on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke all on function public.list_friend_requests() from public, anon;
revoke all on function public.list_friends() from public, anon;
revoke all on function public.remove_friend(text) from public, anon;
revoke all on function public.block_player(text) from public, anon;
revoke all on function public.unblock_player(text) from public, anon;
revoke all on function public.list_blocked_players() from public, anon;
grant execute on function public.send_friend_request(text) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.list_friend_requests() to authenticated;
grant execute on function public.list_friends() to authenticated;
grant execute on function public.remove_friend(text) to authenticated;
grant execute on function public.block_player(text) to authenticated;
grant execute on function public.unblock_player(text) to authenticated;
grant execute on function public.list_blocked_players() to authenticated;
