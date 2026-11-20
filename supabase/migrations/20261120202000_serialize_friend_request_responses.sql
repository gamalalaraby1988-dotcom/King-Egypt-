-- Acquire the pair lock before locking the request row. This matches the
-- lock order used by block_player and avoids a request-row/advisory-lock deadlock.
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

    select r.requester_user_id
      into v_sender
    from private.friend_requests r
    where r.request_id = p_request_id
      and r.recipient_user_id = v_me;
    if not found then return 'request_not_found'; end if;

    v_low := least(v_me, v_sender);
    v_high := greatest(v_me, v_sender);
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_low::text || ':' || v_high::text, 0)
    );

    select r.status
      into v_status
    from private.friend_requests r
    where r.request_id = p_request_id
      and r.requester_user_id = v_sender
      and r.recipient_user_id = v_me
    for update;
    if not found then return 'request_not_found'; end if;
    if v_status <> 'pending' then return 'request_not_pending'; end if;

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
