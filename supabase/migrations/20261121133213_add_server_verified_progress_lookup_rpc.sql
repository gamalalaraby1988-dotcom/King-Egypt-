create or replace function public.has_player_verified_activity(
    p_user_id uuid,
    p_activity_kind text,
    p_activity_id text
)
returns boolean
language sql
security invoker
set search_path = ''
as $function$
    select exists (
        select 1
        from private.player_verified_activity_progress
        where user_id = p_user_id
          and activity_kind = p_activity_kind
          and activity_id = p_activity_id
    );
$function$;

revoke all on function public.has_player_verified_activity(uuid,text,text) from public, anon, authenticated;
grant execute on function public.has_player_verified_activity(uuid,text,text) to service_role;

comment on function public.has_player_verified_activity(uuid,text,text) is
'Backend-only lookup for the dedicated game server. The HMAC-protected progress lookup Edge Function uses this to prevent replaying one-time missions across devices.';
