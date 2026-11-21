-- Trusted city session directory; only the authenticated Edge Function can call these service-role RPCs.
create schema if not exists private;
create table if not exists private.city_session_servers(server_id text primary key check(server_id ~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{2,63}$'),region text not null check(region ~ '^[a-z0-9][a-z0-9-]{1,31}$'),endpoint text not null check(endpoint like 'wss://%' and pg_catalog.length(endpoint)<=512),capacity smallint not null check(capacity between 1 and 64),connected_players smallint not null default 0 check(connected_players>=0 and connected_players<=capacity),status text not null default 'ready' check(status in ('ready','draining','maintenance')),heartbeat_at timestamptz not null default pg_catalog.now(),lease_expires_at timestamptz not null,created_at timestamptz not null default pg_catalog.now(),updated_at timestamptz not null default pg_catalog.now());
create index if not exists city_session_servers_region_ready_idx on private.city_session_servers(region,status,lease_expires_at);
create table if not exists private.city_session_server_nonces(server_id text not null references private.city_session_servers(server_id) on delete cascade,nonce uuid not null,expires_at timestamptz not null,created_at timestamptz not null default pg_catalog.now(),primary key(server_id,nonce));
create index if not exists city_session_server_nonces_expiry_idx on private.city_session_server_nonces(expires_at);
create table if not exists private.city_session_reservations(reservation_id uuid primary key default pg_catalog.gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,server_id text not null references private.city_session_servers(server_id) on delete cascade,status text not null default 'reserved' check(status in ('reserved','connected','released','expired')),created_at timestamptz not null default pg_catalog.now(),expires_at timestamptz not null,connected_at timestamptz,updated_at timestamptz not null default pg_catalog.now());
create unique index if not exists city_session_one_active_reservation_per_user on private.city_session_reservations(user_id) where status in ('reserved','connected');
create index if not exists city_session_reservations_server_reserved_idx on private.city_session_reservations(server_id,expires_at) where status='reserved';
create index if not exists city_session_reservations_user_status_idx on private.city_session_reservations(user_id,status,expires_at);
alter table private.city_session_servers enable row level security; alter table private.city_session_servers force row level security;
alter table private.city_session_server_nonces enable row level security; alter table private.city_session_server_nonces force row level security;
alter table private.city_session_reservations enable row level security; alter table private.city_session_reservations force row level security;
revoke all on table private.city_session_servers,private.city_session_server_nonces,private.city_session_reservations from public,anon,authenticated,service_role;
grant select,insert,update,delete on table private.city_session_servers,private.city_session_server_nonces,private.city_session_reservations to service_role;
grant usage on schema private to service_role;
drop policy if exists city_session_servers_service_all on private.city_session_servers; create policy city_session_servers_service_all on private.city_session_servers for all to service_role using(true) with check(true);
drop policy if exists city_session_nonces_service_all on private.city_session_server_nonces; create policy city_session_nonces_service_all on private.city_session_server_nonces for all to service_role using(true) with check(true);
drop policy if exists city_session_reservations_service_all on private.city_session_reservations; create policy city_session_reservations_service_all on private.city_session_reservations for all to service_role using(true) with check(true);
CREATE OR REPLACE FUNCTION public.city_confirm_session_connection(p_server_id text, p_user_id uuid, p_reservation_id uuid, p_nonce uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_reservation private.city_session_reservations%rowtype;
begin
    if p_server_id is null or p_user_id is null or p_reservation_id is null or p_nonce is null then
        raise exception 'city_session_confirmation_invalid' using errcode = '22023';
    end if;

    delete from private.city_session_server_nonces
    where expires_at <= pg_catalog.now();
    insert into private.city_session_server_nonces(server_id, nonce, expires_at)
    values (p_server_id, p_nonce, pg_catalog.now() + interval '10 minutes')
    on conflict (server_id, nonce) do nothing;
    if not found then
        raise exception 'city_server_nonce_replayed' using errcode = '23505';
    end if;

    update private.city_session_reservations
    set status = 'connected',
        connected_at = coalesce(connected_at, pg_catalog.now()),
        expires_at = pg_catalog.now() + interval '2 hours',
        updated_at = pg_catalog.now()
    where reservation_id = p_reservation_id
      and user_id = p_user_id
      and server_id = p_server_id
      and status = 'reserved'
      and expires_at > pg_catalog.now()
    returning * into v_reservation;

    if not found then
        raise exception 'city_session_reservation_not_found' using errcode = 'P0002';
    end if;

    return pg_catalog.jsonb_build_object(
        'status', 'connected',
        'reservation_id', v_reservation.reservation_id,
        'server_id', v_reservation.server_id
    );
end;
$function$


CREATE OR REPLACE FUNCTION public.city_heartbeat_server(p_server_id text, p_connected_players integer, p_status text, p_nonce uuid, p_lease_seconds integer DEFAULT 45)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_server private.city_session_servers%rowtype;
begin
    if p_server_id is null or p_server_id !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{2,63}$'
       or p_connected_players is null or p_connected_players < 0
       or p_status not in ('ready', 'draining', 'maintenance')
       or p_nonce is null or p_lease_seconds is null or p_lease_seconds < 15 or p_lease_seconds > 90 then
        raise exception 'city_server_heartbeat_invalid' using errcode = '22023';
    end if;

    delete from private.city_session_server_nonces
    where expires_at <= pg_catalog.now();

    insert into private.city_session_server_nonces(server_id, nonce, expires_at)
    values (p_server_id, p_nonce, pg_catalog.now() + interval '10 minutes')
    on conflict (server_id, nonce) do nothing;
    if not found then
        raise exception 'city_server_nonce_replayed' using errcode = '23505';
    end if;

    update private.city_session_servers
    set connected_players = p_connected_players,
        status = p_status,
        heartbeat_at = pg_catalog.now(),
        lease_expires_at = pg_catalog.now() + pg_catalog.make_interval(secs => p_lease_seconds),
        updated_at = pg_catalog.now()
    where server_id = p_server_id
      and p_connected_players <= capacity
    returning * into v_server;

    if not found then
        raise exception 'city_server_not_registered_or_capacity_invalid' using errcode = 'P0002';
    end if;

    update private.city_session_reservations
    set expires_at = pg_catalog.now() + interval '2 hours',
        updated_at = pg_catalog.now()
    where server_id = p_server_id and status = 'connected';

    return pg_catalog.jsonb_build_object(
        'status', 'heartbeat_accepted',
        'server_id', v_server.server_id,
        'lease_expires_at', v_server.lease_expires_at
    );
end;
$function$


CREATE OR REPLACE FUNCTION public.city_register_server(p_server_id text, p_region text, p_endpoint text, p_capacity integer, p_connected_players integer, p_nonce uuid, p_lease_seconds integer DEFAULT 45)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_server private.city_session_servers%rowtype;
begin
    if p_server_id is null or p_server_id !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{2,63}$'
       or p_region is null or p_region !~ '^[a-z0-9][a-z0-9-]{1,31}$'
       or p_endpoint is null or p_endpoint not like 'wss://%' or pg_catalog.length(p_endpoint) > 512
       or p_capacity is null or p_capacity < 1 or p_capacity > 64
       or p_connected_players is null or p_connected_players < 0 or p_connected_players > p_capacity
       or p_nonce is null or p_lease_seconds is null or p_lease_seconds < 15 or p_lease_seconds > 90 then
        raise exception 'city_server_registration_invalid' using errcode = '22023';
    end if;

    update private.city_session_reservations
    set status = 'expired', updated_at = pg_catalog.now()
    where server_id = p_server_id and status in ('reserved', 'connected');

    insert into private.city_session_servers(
        server_id, region, endpoint, capacity, connected_players, status,
        heartbeat_at, lease_expires_at, updated_at
    ) values (
        p_server_id, p_region, p_endpoint, p_capacity, p_connected_players, 'ready',
        pg_catalog.now(), pg_catalog.now() + pg_catalog.make_interval(secs => p_lease_seconds),
        pg_catalog.now()
    )
    on conflict (server_id) do update set
        region = excluded.region, endpoint = excluded.endpoint, capacity = excluded.capacity,
        connected_players = excluded.connected_players, status = 'ready',
        heartbeat_at = pg_catalog.now(), lease_expires_at = excluded.lease_expires_at,
        updated_at = pg_catalog.now()
    returning * into v_server;

    delete from private.city_session_server_nonces where expires_at <= pg_catalog.now();
    insert into private.city_session_server_nonces(server_id, nonce, expires_at)
    values (p_server_id, p_nonce, pg_catalog.now() + interval '10 minutes')
    on conflict (server_id, nonce) do nothing;
    if not found then raise exception 'city_server_nonce_replayed' using errcode = '23505'; end if;

    return pg_catalog.jsonb_build_object('status','registered','server_id',v_server.server_id,'lease_expires_at',v_server.lease_expires_at);
end;
$function$


CREATE OR REPLACE FUNCTION public.city_release_player_reservation(p_user_id uuid, p_reservation_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_updated integer;
begin
 if p_user_id is null or p_reservation_id is null then raise exception 'city_player_release_invalid' using errcode='22023'; end if;
 update private.city_session_reservations set status='released',updated_at=pg_catalog.now()
 where reservation_id=p_reservation_id and user_id=p_user_id and status='reserved';
 get diagnostics v_updated=row_count;
 return pg_catalog.jsonb_build_object('status',case when v_updated=1 then 'released' else 'not_found' end);
end;
$function$

CREATE OR REPLACE FUNCTION public.city_release_server_session(p_server_id text, p_user_id uuid, p_reservation_id uuid, p_nonce uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_updated integer;
begin
    if p_server_id is null or p_user_id is null or p_reservation_id is null or p_nonce is null then
        raise exception 'city_session_release_invalid' using errcode = '22023';
    end if;

    delete from private.city_session_server_nonces
    where expires_at <= pg_catalog.now();
    insert into private.city_session_server_nonces(server_id, nonce, expires_at)
    values (p_server_id, p_nonce, pg_catalog.now() + interval '10 minutes')
    on conflict (server_id, nonce) do nothing;
    if not found then
        raise exception 'city_server_nonce_replayed' using errcode = '23505';
    end if;

    update private.city_session_reservations
    set status = 'released', updated_at = pg_catalog.now()
    where reservation_id = p_reservation_id
      and user_id = p_user_id
      and server_id = p_server_id
      and status in ('reserved', 'connected');
    get diagnostics v_updated = row_count;

    return pg_catalog.jsonb_build_object('status', case when v_updated = 1 then 'released' else 'not_found' end);
end;
$function$


CREATE OR REPLACE FUNCTION public.city_reserve_session(p_user_id uuid, p_preferred_region text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_existing private.city_session_reservations%rowtype;
    v_server_id text;
    v_endpoint text;
    v_reservation private.city_session_reservations%rowtype;
begin
    if p_user_id is null or p_preferred_region is null
       or p_preferred_region !~ '^[a-z0-9][a-z0-9-]{1,31}$' then
        raise exception 'city_matchmaking_request_invalid' using errcode = '22023';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('city-session-user:' || p_user_id::text, 0)
    );
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('city-session-region:' || p_preferred_region, 0)
    );

    update private.city_session_reservations r
    set status = 'expired', updated_at = pg_catalog.now()
    where r.status in ('reserved', 'connected')
      and (
        r.expires_at <= pg_catalog.now()
        or exists (
            select 1 from private.city_session_servers s
            where s.server_id = r.server_id
              and s.lease_expires_at <= pg_catalog.now()
        )
      );

    select r.* into v_existing
    from private.city_session_reservations r
    join private.city_session_servers s on s.server_id = r.server_id
    where r.user_id = p_user_id
      and r.status in ('reserved', 'connected')
      and r.expires_at > pg_catalog.now()
      and s.lease_expires_at > pg_catalog.now()
    order by r.created_at desc
    limit 1
    for update of r;

    if found then
        select endpoint into v_endpoint
        from private.city_session_servers
        where server_id = v_existing.server_id;
        return pg_catalog.jsonb_build_object(
            'status', 'assigned',
            'server_id', v_existing.server_id,
            'instance_id', v_existing.server_id,
            'endpoint', v_endpoint,
            'reservation_id', v_existing.reservation_id,
            'expires_at', v_existing.expires_at,
            'reused', true
        );
    end if;

    with server_load as (
        select s.server_id, s.capacity,
               s.connected_players + pg_catalog.count(r.reservation_id)::integer as load_count
        from private.city_session_servers s
        left join private.city_session_reservations r
          on r.server_id = s.server_id
         and r.status = 'reserved'
         and r.expires_at > pg_catalog.now()
        where s.region = p_preferred_region
          and s.status = 'ready'
          and s.lease_expires_at > pg_catalog.now()
        group by s.server_id, s.capacity, s.connected_players
        having s.connected_players + pg_catalog.count(r.reservation_id)::integer < s.capacity
    )
    select s.server_id, s.endpoint
    into v_server_id, v_endpoint
    from private.city_session_servers s
    join server_load l on l.server_id = s.server_id
    order by l.load_count::numeric / l.capacity, l.server_id
    for update of s skip locked
    limit 1;

    if v_server_id is null then
        return pg_catalog.jsonb_build_object('status', 'no_capacity');
    end if;

    insert into private.city_session_reservations(
        user_id, server_id, status, expires_at, updated_at
    ) values (
        p_user_id, v_server_id, 'reserved',
        pg_catalog.now() + interval '5 minutes',
        pg_catalog.now()
    )
    returning * into v_reservation;

    return pg_catalog.jsonb_build_object(
        'status', 'assigned',
        'server_id', v_server_id,
        'instance_id', v_server_id,
        'endpoint', v_endpoint,
        'reservation_id', v_reservation.reservation_id,
        'expires_at', v_reservation.expires_at,
        'reused', false
    );
end;
$function$

revoke all on function public.city_register_server(text,text,text,integer,integer,uuid,integer) from public,anon,authenticated;
revoke all on function public.city_heartbeat_server(text,integer,text,uuid,integer) from public,anon,authenticated;
revoke all on function public.city_reserve_session(uuid,text) from public,anon,authenticated;
revoke all on function public.city_confirm_session_connection(text,uuid,uuid,uuid) from public,anon,authenticated;
revoke all on function public.city_release_server_session(text,uuid,uuid,uuid) from public,anon,authenticated;
revoke all on function public.city_release_player_reservation(uuid,uuid) from public,anon,authenticated;
grant execute on function public.city_register_server(text,text,text,integer,integer,uuid,integer) to service_role;
grant execute on function public.city_heartbeat_server(text,integer,text,uuid,integer) to service_role;
grant execute on function public.city_reserve_session(uuid,text) to service_role;
grant execute on function public.city_confirm_session_connection(text,uuid,uuid,uuid) to service_role;
grant execute on function public.city_release_server_session(text,uuid,uuid,uuid) to service_role;
grant execute on function public.city_release_player_reservation(uuid,uuid) to service_role;
comment on table private.city_session_servers is 'Trusted dedicated server registry; signed heartbeats maintain leases.';
comment on table private.city_session_server_nonces is 'Replay protection for HMAC-authenticated server requests.';
comment on table private.city_session_reservations is 'Private player session reservations; no direct client access.';
