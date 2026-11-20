-- Production-authenticated friend graph. No direct table access is granted.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.friend_requests (
    request_id uuid primary key default pg_catalog.gen_random_uuid(),
    requester_user_id uuid not null references auth.users(id) on delete cascade,
    recipient_user_id uuid not null references auth.users(id) on delete cascade,
    status text not null default 'pending'
        check (status in ('pending', 'accepted', 'declined', 'cancelled')),
    created_at timestamptz not null default pg_catalog.now(),
    responded_at timestamptz,
    constraint friend_requests_not_self check (requester_user_id <> recipient_user_id)
);

create unique index if not exists friend_requests_one_pending_per_pair
    on private.friend_requests (
        least(requester_user_id, recipient_user_id),
        greatest(requester_user_id, recipient_user_id)
    ) where status = 'pending';
create index if not exists friend_requests_incoming_pending_idx
    on private.friend_requests (recipient_user_id, created_at desc)
    where status = 'pending';
create index if not exists friend_requests_outgoing_pending_idx
    on private.friend_requests (requester_user_id, created_at desc)
    where status = 'pending';

create table if not exists private.friendships (
    user_low uuid not null references auth.users(id) on delete cascade,
    user_high uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default pg_catalog.now(),
    primary key (user_low, user_high),
    constraint friendships_canonical_pair check (user_low < user_high)
);
create index if not exists friendships_user_high_idx
    on private.friendships (user_high, created_at desc);

create table if not exists private.player_blocks (
    blocker_user_id uuid not null references auth.users(id) on delete cascade,
    blocked_user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default pg_catalog.now(),
    primary key (blocker_user_id, blocked_user_id),
    constraint player_blocks_not_self check (blocker_user_id <> blocked_user_id)
);
create index if not exists player_blocks_blocked_user_idx
    on private.player_blocks (blocked_user_id, blocker_user_id);

alter table private.friend_requests enable row level security;
alter table private.friendships enable row level security;
alter table private.player_blocks enable row level security;
revoke all on table private.friend_requests, private.friendships, private.player_blocks
    from public, anon, authenticated;

create or replace function private.send_friend_request(p_player_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_me uuid := auth.uid();
    v_target uuid;
    v_low uuid;
    v_high uuid;
begin
    if v_me is null then return 'authentication_required'; end if;
    if pg_catalog.upper(pg_catalog.coalesce(p_player_code, '')) !~ '^[A-F0-9]{10}$' then
        return 'invalid_player_code';
    end if;
    select p.user_id into v_target
    from public.player_profiles p
    where p.player_code = pg_catalog.upper(p_player_code);
    if v_target is null then return 'player_not_found'; end if;
    if v_target = v_me then return 'cannot_request_self'; end if;

    v_low := least(v_me, v_target);
    v_high := greatest(v_me, v_target);
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_low::text || ':' || v_high::text, 0)
    );

    if exists (
        select 1 from private.player_blocks b
        where (b.blocker_user_id = v_me and b.blocked_user_id = v_target)
           or (b.blocker_user_id = v_target and b.blocked_user_id = v_me)
    ) then return 'blocked'; end if;
    if exists (
        select 1 from private.friendships f
        where f.user_low = v_low and f.user_high = v_high
    ) then return 'already_friends'; end if;
    if exists (
        select 1 from private.friend_requests r
        where r.status = 'pending'
          and least(r.requester_user_id, r.recipient_user_id) = v_low
          and greatest(r.requester_user_id, r.recipient_user_id) = v_high
    ) then return 'request_already_pending'; end if;

    insert into private.friend_requests (requester_user_id, recipient_user_id)
    values (v_me, v_target);
    return 'sent';
exception when unique_violation then
    return 'request_already_pending';
end;
$function$;

create or replace function private.respond_friend_request(p_request_id uuid, p_accept boolean)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_me uuid := auth.uid();
    v_sender uuid;
    v_status text;
    v_low uuid;
    v_high uuid;
begin
    if v_me is null then return 'authentication_required'; end if;
    select r.requester_user_id, r.status
      into v_sender, v_status
    from private.friend_requests r
    where r.request_id = p_request_id
      and r.recipient_user_id = v_me
    for update;
    if not found then return 'request_not_found'; end if;
    if v_status <> 'pending' then return 'request_not_pending'; end if;

    v_low := least(v_me, v_sender);
    v_high := greatest(v_me, v_sender);
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_low::text || ':' || v_high::text, 0)
    );

    if exists (
        select 1 from private.player_blocks b
        where (b.blocker_user_id = v_me and b.blocked_user_id = v_sender)
           or (b.blocker_user_id = v_sender and b.blocked_user_id = v_me)
    ) then
        update private.friend_requests
        set status = 'cancelled', responded_at = pg_catalog.now()
        where request_id = p_request_id;
        return 'blocked';
    end if;

    update private.friend_requests
    set status = case when p_accept then 'accepted' else 'declined' end,
        responded_at = pg_catalog.now()
    where request_id = p_request_id;

    if p_accept then
        insert into private.friendships (user_low, user_high)
        values (v_low, v_high)
        on conflict (user_low, user_high) do nothing;
        return 'accepted';
    end if;
    return 'declined';
end;
$function$;

create or replace function private.list_friend_requests()
returns table (
    request_id uuid,
    direction text,
    player_code text,
    display_name text,
    created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
    select r.request_id,
           case when r.requester_user_id = auth.uid() then 'outgoing' else 'incoming' end,
           p.player_code,
           pg_catalog.left(pg_catalog.coalesce(p.display_name, ''), 24),
           r.created_at
    from private.friend_requests r
    join public.player_profiles p
      on p.user_id = case when r.requester_user_id = auth.uid()
                          then r.recipient_user_id else r.requester_user_id end
    where r.status = 'pending'
      and auth.uid() in (r.requester_user_id, r.recipient_user_id)
    order by r.created_at desc;
$function$;

create or replace function private.list_friends()
returns table (player_code text, display_name text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $function$
    select p.player_code,
           pg_catalog.left(pg_catalog.coalesce(p.display_name, ''), 24),
           f.created_at
    from private.friendships f
    join public.player_profiles p
      on p.user_id = case when f.user_low = auth.uid() then f.user_high else f.user_low end
    where auth.uid() in (f.user_low, f.user_high)
    order by f.created_at desc;
$function$;

create or replace function private.remove_friend(p_player_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_me uuid := auth.uid();
    v_target uuid;
    v_low uuid;
    v_high uuid;
begin
    if v_me is null then return 'authentication_required'; end if;
    if pg_catalog.upper(pg_catalog.coalesce(p_player_code, '')) !~ '^[A-F0-9]{10}$' then
        return 'invalid_player_code';
    end if;
    select p.user_id into v_target from public.player_profiles p
    where p.player_code = pg_catalog.upper(p_player_code);
    if v_target is null then return 'player_not_found'; end if;
    if v_target = v_me then return 'cannot_remove_self'; end if;
    v_low := least(v_me, v_target);
    v_high := greatest(v_me, v_target);
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_low::text || ':' || v_high::text, 0)
    );
    delete from private.friendships f
    where f.user_low = v_low and f.user_high = v_high;
    if not found then return 'not_friends'; end if;
    return 'removed';
end;
$function$;

create or replace function private.block_player(p_player_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_me uuid := auth.uid();
    v_target uuid;
    v_low uuid;
    v_high uuid;
begin
    if v_me is null then return 'authentication_required'; end if;
    if pg_catalog.upper(pg_catalog.coalesce(p_player_code, '')) !~ '^[A-F0-9]{10}$' then
        return 'invalid_player_code';
    end if;
    select p.user_id into v_target from public.player_profiles p
    where p.player_code = pg_catalog.upper(p_player_code);
    if v_target is null then return 'player_not_found'; end if;
    if v_target = v_me then return 'cannot_block_self'; end if;
    v_low := least(v_me, v_target);
    v_high := greatest(v_me, v_target);
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_low::text || ':' || v_high::text, 0)
    );
    insert into private.player_blocks (blocker_user_id, blocked_user_id)
    values (v_me, v_target)
    on conflict (blocker_user_id, blocked_user_id) do nothing;
    delete from private.friendships f
    where f.user_low = v_low and f.user_high = v_high;
    update private.friend_requests r
    set status = 'cancelled', responded_at = pg_catalog.now()
    where r.status = 'pending'
      and least(r.requester_user_id, r.recipient_user_id) = v_low
      and greatest(r.requester_user_id, r.recipient_user_id) = v_high;
    return 'blocked';
end;
$function$;

create or replace function private.unblock_player(p_player_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_me uuid := auth.uid();
    v_target uuid;
begin
    if v_me is null then return 'authentication_required'; end if;
    if pg_catalog.upper(pg_catalog.coalesce(p_player_code, '')) !~ '^[A-F0-9]{10}$' then
        return 'invalid_player_code';
    end if;
    select p.user_id into v_target from public.player_profiles p
    where p.player_code = pg_catalog.upper(p_player_code);
    if v_target is null then return 'player_not_found'; end if;
    delete from private.player_blocks b
    where b.blocker_user_id = v_me and b.blocked_user_id = v_target;
    if not found then return 'not_blocked'; end if;
    return 'unblocked';
end;
$function$;

create or replace function private.list_blocked_players()
returns table (player_code text, display_name text, blocked_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $function$
    select p.player_code,
           pg_catalog.left(pg_catalog.coalesce(p.display_name, ''), 24),
           b.created_at
    from private.player_blocks b
    join public.player_profiles p on p.user_id = b.blocked_user_id
    where b.blocker_user_id = auth.uid()
    order by b.created_at desc
    limit 100;
$function$;

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

comment on table private.friend_requests is 'Private server-authoritative friend requests keyed by Auth user IDs.';
comment on table private.friendships is 'Private canonical friend pairs keyed by Auth user IDs.';
comment on table private.player_blocks is 'Private directional player blocks keyed by Auth user IDs.';
