-- Durable server-verified walking distance for the Online "First Steps" achievement.
-- Every increment is HMAC-authenticated by the dedicated game server and stored append-only.
create table if not exists private.player_verified_walk_distance_events (
    user_id uuid not null references auth.users(id) on delete cascade,
    server_event_id uuid not null,
    distance_meters numeric(8,3) not null check (distance_meters > 0 and distance_meters <= 5.000),
    evidence_digest bytea not null check (pg_catalog.octet_length(evidence_digest) = 32),
    verified_at timestamptz not null,
    primary key (user_id, server_event_id)
);

create index if not exists player_verified_walk_distance_user_idx
    on private.player_verified_walk_distance_events (user_id, verified_at);

alter table private.player_verified_walk_distance_events enable row level security;
alter table private.player_verified_walk_distance_events force row level security;
revoke all on table private.player_verified_walk_distance_events from public, anon, authenticated, service_role;
grant select, insert on table private.player_verified_walk_distance_events to authenticated, service_role;
drop policy if exists player_verified_walk_distance_service_select on private.player_verified_walk_distance_events;
create policy player_verified_walk_distance_service_select
    on private.player_verified_walk_distance_events for select to service_role using (true);
drop policy if exists player_verified_walk_distance_service_insert on private.player_verified_walk_distance_events;
create policy player_verified_walk_distance_service_insert
    on private.player_verified_walk_distance_events for insert to service_role with check (true);
drop policy if exists player_verified_walk_distance_own_select on private.player_verified_walk_distance_events;
create policy player_verified_walk_distance_own_select
    on private.player_verified_walk_distance_events for select to authenticated
    using ((select auth.uid()) = user_id);

create or replace function public.record_server_verified_walk_distance(
    p_user_id uuid,
    p_server_event_id uuid,
    p_distance_meters numeric,
    p_evidence_digest_hex text,
    p_issued_at timestamptz,
    p_expires_at timestamptz
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_digest bytea;
    v_event private.player_verified_walk_distance_events%rowtype;
    v_inserted boolean := false;
    v_total numeric(12,3);
    v_achievement private.player_verified_activity_progress%rowtype;
    v_achievement_event_id uuid;
    v_achievement_digest bytea;
    v_achievement_unlocked boolean := false;
begin
    if p_user_id is null or p_server_event_id is null
       or p_distance_meters is null or p_distance_meters <= 0 or p_distance_meters > 5.000
       or p_distance_meters <> pg_catalog.round(p_distance_meters, 3)
       or p_evidence_digest_hex is null or p_evidence_digest_hex !~ '^[0-9a-f]{64}$'
       or p_issued_at is null or p_expires_at is null then
        raise exception 'invalid_server_walk_progress_payload' using errcode = '22023';
    end if;

    if p_issued_at > pg_catalog.now() + interval '30 seconds'
       or p_issued_at < pg_catalog.now() - interval '2 minutes'
       or p_expires_at <> p_issued_at + interval '5 minutes' then
        raise exception 'server_walk_progress_timestamp_invalid' using errcode = '22023';
    end if;

    v_digest := pg_catalog.decode(p_evidence_digest_hex, 'hex');
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_user_id::text || ':walk-distance', 0)
    );
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_user_id::text || ':' || p_server_event_id::text, 0)
    );

    insert into private.player_verified_walk_distance_events (
        user_id, server_event_id, distance_meters, evidence_digest, verified_at
    ) values (
        p_user_id, p_server_event_id, p_distance_meters, v_digest, p_issued_at
    )
    on conflict (user_id, server_event_id) do nothing
    returning * into v_event;

    if found then
        v_inserted := true;
    else
        select * into v_event
        from private.player_verified_walk_distance_events
        where user_id = p_user_id and server_event_id = p_server_event_id;
        if not found
           or v_event.distance_meters <> p_distance_meters
           or v_event.evidence_digest <> v_digest
           or v_event.verified_at <> p_issued_at then
            raise exception 'server_walk_event_conflict' using errcode = '23505';
        end if;
    end if;

    select coalesce(pg_catalog.sum(distance_meters), 0)::numeric(12,3)
    into v_total
    from private.player_verified_walk_distance_events
    where user_id = p_user_id;

    if v_total >= 100.000 then
        perform pg_catalog.pg_advisory_xact_lock(
            pg_catalog.hashtextextended(p_user_id::text || ':achievement:first_steps', 0)
        );
        select * into v_achievement
        from private.player_verified_activity_progress
        where user_id = p_user_id
          and activity_kind = 'achievement'
          and activity_id = 'first_steps';

        if not found then
            v_achievement_event_id := pg_catalog.gen_random_uuid();
            v_achievement_digest := extensions.digest(
                pg_catalog.convert_to(
                    'v1|' || p_user_id::text || '|achievement|first_steps|' ||
                    v_achievement_event_id::text || '|' || p_issued_at::text,
                    'UTF8'
                ),
                'sha256'
            );
            insert into private.player_verified_activity_progress (
                user_id, activity_kind, activity_id, server_event_id,
                evidence_digest, reward_eligible_at_completion, verified_at
            ) values (
                p_user_id, 'achievement', 'first_steps', v_achievement_event_id,
                v_achievement_digest, false, p_issued_at
            )
            on conflict do nothing
            returning * into v_achievement;

            if not found then
                select * into v_achievement
                from private.player_verified_activity_progress
                where user_id = p_user_id
                  and activity_kind = 'achievement'
                  and activity_id = 'first_steps';
            end if;
        end if;
        v_achievement_unlocked := v_achievement.user_id is not null;
    end if;

    return pg_catalog.jsonb_build_object(
        'recorded', true,
        'duplicate', not v_inserted,
        'total_meters', v_total,
        'achievement_unlocked', v_achievement_unlocked
    );
end;
$function$;

create or replace function public.get_server_verified_walk_distance(p_user_id uuid)
returns numeric
language sql
security invoker
set search_path = ''
as $function$
    select coalesce(pg_catalog.sum(distance_meters), 0)::numeric(12,3)
    from private.player_verified_walk_distance_events
    where user_id = p_user_id;
$function$;

revoke all on function public.record_server_verified_walk_distance(uuid,uuid,numeric,text,timestamptz,timestamptz)
    from public, anon, authenticated;
grant execute on function public.record_server_verified_walk_distance(uuid,uuid,numeric,text,timestamptz,timestamptz)
    to service_role;
revoke all on function public.get_server_verified_walk_distance(uuid) from public, anon, authenticated;
grant execute on function public.get_server_verified_walk_distance(uuid) to service_role;

create or replace function public.get_player_verified_activity_progress()
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_progress jsonb;
    v_walk_distance numeric(12,3);
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode = '28000';
    end if;

    select coalesce(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'activity_kind', activity_kind,
                'activity_id', activity_id,
                'server_event_id', server_event_id,
                'verified_at', verified_at
            )
            order by verified_at, server_event_id
        ),
        '[]'::jsonb
    )
    into v_progress
    from private.player_verified_activity_progress
    where user_id = v_user_id;

    select coalesce(pg_catalog.sum(distance_meters), 0)::numeric(12,3)
    into v_walk_distance
    from private.player_verified_walk_distance_events
    where user_id = v_user_id;

    if v_walk_distance > 0 then
        v_progress := v_progress || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
                'activity_kind', 'walk_distance',
                'activity_id', 'first_steps',
                'distance_meters', v_walk_distance
            )
        );
    end if;

    return pg_catalog.jsonb_build_object(
        'authoritative', true,
        'trust', 'server_verified',
        'activities', v_progress
    );
end;
$function$;

revoke all on function public.get_player_verified_activity_progress() from public, anon;
grant execute on function public.get_player_verified_activity_progress() to authenticated;

comment on table private.player_verified_walk_distance_events is
'Append-only per-account walking distance increments measured by the dedicated server. Only HMAC-verified backend events can be inserted; clients cannot alter or delete distance evidence.';
comment on function public.record_server_verified_walk_distance(uuid,uuid,numeric,text,timestamptz,timestamptz) is
'Backend-only recorder for bounded HMAC-verified walking increments. Accumulates durable account distance and unlocks First Steps at 100 meters without issuing a reward proof.';
