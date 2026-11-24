-- Persist server-finalized royal jet ski race results and one daily podium entitlement per account.
-- Payout values intentionally remain unset until the city economy approves the amounts.
create schema if not exists private;

create table if not exists private.jet_ski_race_results (
    race_id uuid not null,
    server_event_id uuid not null unique,
    server_id text not null check (server_id ~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{2,63}$'),
    user_id uuid not null references auth.users(id) on delete cascade,
    egypt_day date not null,
    status text not null check (status in ('finished', 'dnf')),
    place smallint,
    finish_time_usec bigint,
    reason text,
    finalized_at timestamptz not null default pg_catalog.now(),
    primary key (race_id, user_id)
);

alter table private.jet_ski_race_results
    drop constraint if exists jet_ski_race_results_check;
alter table private.jet_ski_race_results
    drop constraint if exists jet_ski_race_results_status_shape_check;
alter table private.jet_ski_race_results
    add constraint jet_ski_race_results_status_shape_check check (
        (status = 'finished' and place between 1 and 4 and finish_time_usec >= 0 and reason is null)
        or
        (status = 'dnf' and place is null and finish_time_usec is null
            and reason is not null and reason in ('disconnect', 'time_limit'))
    );

create index if not exists jet_ski_race_results_user_day_idx
    on private.jet_ski_race_results(user_id, egypt_day desc, finalized_at desc);

create table if not exists private.jet_ski_race_server_nonces (
    server_id text not null check (server_id ~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{2,63}create table if not exists private.jet_ski_daily_reward_entitlements (
    user_id uuid not null references auth.users(id) on delete cascade,
    egypt_day date not null,
    race_id uuid not null,
    best_place smallint not null check (best_place between 1 and 3),
    finish_time_usec bigint not null check (finish_time_usec >= 0),
    reward_cash bigint check (reward_cash is null or reward_cash between 0 and 2000000000),
    status text not null default 'pending_configuration'
        check (status in ('pending_configuration', 'pending_settlement', 'paid')),
    created_at timestamptz not null default pg_catalog.now(),
    updated_at timestamptz not null default pg_catalog.now(),
    paid_at timestamptz,
    primary key (user_id, egypt_day),
    foreign key (race_id, user_id)
        references private.jet_ski_race_results(race_id, user_id) on delete cascade,
    check (
        (status = 'paid' and reward_cash is not null and paid_at is not null)
        or
        (status <> 'paid' and paid_at is null)
    )
);

alter table private.jet_ski_race_results enable row level security;
alter table private.jet_ski_race_results force row level security;
alter table private.jet_ski_daily_reward_entitlements enable row level security;
alter table private.jet_ski_daily_reward_entitlements force row level security;
alter table private.jet_ski_race_server_nonces enable row level security;
alter table private.jet_ski_race_server_nonces force row level security;

revoke all on table private.jet_ski_race_results, private.jet_ski_daily_reward_entitlements,
    private.jet_ski_race_server_nonces from public, anon, authenticated, service_role;
grant usage on schema private to service_role;
grant select, insert on table private.jet_ski_race_results to service_role;
grant select, insert, update on table private.jet_ski_daily_reward_entitlements to service_role;
grant select, insert, delete on table private.jet_ski_race_server_nonces to service_role;

drop policy if exists jet_ski_race_results_service_select on private.jet_ski_race_results;
create policy jet_ski_race_results_service_select
    on private.jet_ski_race_results for select to service_role using (true);
drop policy if exists jet_ski_race_results_service_insert on private.jet_ski_race_results;
create policy jet_ski_race_results_service_insert
    on private.jet_ski_race_results for insert to service_role with check (true);
drop policy if exists jet_ski_daily_entitlements_service_select on private.jet_ski_daily_reward_entitlements;
create policy jet_ski_daily_entitlements_service_select
    on private.jet_ski_daily_reward_entitlements for select to service_role using (true);
drop policy if exists jet_ski_daily_entitlements_service_insert on private.jet_ski_daily_reward_entitlements;
create policy jet_ski_daily_entitlements_service_insert
    on private.jet_ski_daily_reward_entitlements for insert to service_role with check (true);
drop policy if exists jet_ski_daily_entitlements_service_update on private.jet_ski_daily_reward_entitlements;
create policy jet_ski_daily_entitlements_service_update
    on private.jet_ski_daily_reward_entitlements for update to service_role
    using (true) with check (true);

drop policy if exists jet_ski_race_nonces_service_select on private.jet_ski_race_server_nonces;
create policy jet_ski_race_nonces_service_select
    on private.jet_ski_race_server_nonces for select to service_role using (true);
drop policy if exists jet_ski_race_nonces_service_insert on private.jet_ski_race_server_nonces;
create policy jet_ski_race_nonces_service_insert
    on private.jet_ski_race_server_nonces for insert to service_role with check (true);
drop policy if exists jet_ski_race_nonces_service_delete on private.jet_ski_race_server_nonces;
create policy jet_ski_race_nonces_service_delete
    on private.jet_ski_race_server_nonces for delete to service_role using (true);

drop function if exists private.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text);

create or replace function private.record_jet_ski_race_result(
    p_race_id uuid,
    p_server_event_id uuid,
    p_server_id text,
    p_user_id uuid,
    p_status text,
    p_place smallint,
    p_finish_time_usec bigint,
    p_nonce uuid,
    p_issued_at timestamptz,
    p_reason text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_egypt_day date := (pg_catalog.now() at time zone 'Africa/Cairo')::date;
    v_by_event private.jet_ski_race_results%rowtype;
    v_by_racer private.jet_ski_race_results%rowtype;
    v_result private.jet_ski_race_results%rowtype;
    v_entitlement private.jet_ski_daily_reward_entitlements%rowtype;
    v_event_found boolean := false;
    v_racer_found boolean := false;
    v_inserted boolean := false;
begin
    if p_race_id is null or p_server_event_id is null or p_user_id is null
       or p_nonce is null or p_issued_at is null
       or p_issued_at > pg_catalog.now() + interval '60 seconds'
       or p_issued_at < pg_catalog.now() - interval '60 seconds'
       or p_status is null or p_server_id is null or p_server_id !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{2,63}$'
       or p_status not in ('finished', 'dnf') then
        raise exception 'jet_ski_race_result_invalid' using errcode = '22023';
    end if;

    if p_status = 'finished' then
        if p_place is null or p_place < 1 or p_place > 4
           or p_finish_time_usec is null or p_finish_time_usec < 0
           or p_reason is not null then
            raise exception 'jet_ski_race_finish_payload_invalid' using errcode = '22023';
        end if;
    elsif p_place is not null or p_finish_time_usec is not null
       or p_reason is null or p_reason not in ('disconnect', 'time_limit') then
        raise exception 'jet_ski_race_dnf_payload_invalid' using errcode = '22023';
    end if;

    delete from private.jet_ski_race_server_nonces
    where expires_at <= pg_catalog.now();
    insert into private.jet_ski_race_server_nonces(server_id, nonce, expires_at)
    values (p_server_id, p_nonce, pg_catalog.now() + interval '10 minutes')
    on conflict (server_id, nonce) do nothing;
    if not found then
        raise exception 'jet_ski_race_server_nonce_replayed' using errcode = '23505';
    end if;

    -- Serialize both idempotency dimensions before checking/inserting.
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_race_id::text || ':' || p_user_id::text, 0)
    );
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_server_event_id::text, 0)
    );

    select * into v_by_event
    from private.jet_ski_race_results
    where server_event_id = p_server_event_id;
    v_event_found := found;

    select * into v_by_racer
    from private.jet_ski_race_results
    where race_id = p_race_id and user_id = p_user_id;
    v_racer_found := found;

    if v_event_found and v_racer_found
       and v_by_event.server_event_id <> v_by_racer.server_event_id then
        raise exception 'jet_ski_race_result_conflict' using errcode = '23505';
    end if;

    if v_event_found or v_racer_found then
        v_result := case when v_event_found then v_by_event else v_by_racer end;
        if v_result.race_id <> p_race_id
           or v_result.server_event_id <> p_server_event_id
           or v_result.server_id <> p_server_id
           or v_result.user_id <> p_user_id
           or v_result.egypt_day <> v_egypt_day
           or v_result.status <> p_status
           or v_result.place is distinct from p_place
           or v_result.finish_time_usec is distinct from p_finish_time_usec
           or v_result.reason is distinct from p_reason then
            raise exception 'jet_ski_race_result_conflict' using errcode = '23505';
        end if;
    else
        insert into private.jet_ski_race_results (
            race_id, server_event_id, server_id, user_id, egypt_day,
            status, place, finish_time_usec, reason
        ) values (
            p_race_id, p_server_event_id, p_server_id, p_user_id, v_egypt_day,
            p_status, p_place, p_finish_time_usec, p_reason
        )
        returning * into v_result;
        v_inserted := true;
    end if;

    if p_status = 'finished' and p_place <= 3 then
        insert into private.jet_ski_daily_reward_entitlements (
            user_id, egypt_day, race_id, best_place, finish_time_usec
        ) values (
            p_user_id, v_egypt_day, p_race_id, p_place, p_finish_time_usec
        )
        on conflict (user_id, egypt_day) do update
        set race_id = excluded.race_id,
            best_place = excluded.best_place,
            finish_time_usec = excluded.finish_time_usec,
            updated_at = pg_catalog.now()
        where private.jet_ski_daily_reward_entitlements.status = 'pending_configuration'
          and (
              excluded.best_place < private.jet_ski_daily_reward_entitlements.best_place
              or (
                  excluded.best_place = private.jet_ski_daily_reward_entitlements.best_place
                  and excluded.finish_time_usec < private.jet_ski_daily_reward_entitlements.finish_time_usec
              )
          )
        returning * into v_entitlement;

        if not found then
            select * into v_entitlement
            from private.jet_ski_daily_reward_entitlements
            where user_id = p_user_id and egypt_day = v_egypt_day;
        end if;
    end if;

    return pg_catalog.jsonb_build_object(
        'recorded', true,
        'duplicate', not v_inserted,
        'egypt_day', v_egypt_day,
        'daily_reward_eligible', p_status = 'finished' and p_place between 1 and 3,
        'daily_best_place', case when v_entitlement.user_id is null then null else v_entitlement.best_place end,
        'entitlement_status', case when v_entitlement.user_id is null then null else v_entitlement.status end
    );
end;
$function$;

revoke all on function private.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text)
    from public, anon, authenticated;
grant execute on function private.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text)
    to service_role;

create or replace function public.record_jet_ski_race_result(
    p_race_id uuid,
    p_server_event_id uuid,
    p_server_id text,
    p_user_id uuid,
    p_status text,
    p_place smallint,
    p_finish_time_usec bigint,
    p_nonce uuid,
    p_issued_at timestamptz,
    p_reason text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
    select private.record_jet_ski_race_result(
        p_race_id, p_server_event_id, p_server_id, p_user_id,
        p_status, p_place, p_finish_time_usec, p_nonce, p_issued_at, p_reason
    );
$function$;

revoke all on function public.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text)
    from public, anon, authenticated;
grant execute on function public.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text)
    to service_role;

comment on table private.jet_ski_race_results is
'Append-only server-finalized royal jet ski race results. Client roles have no access; a trusted HMAC-verifying Edge Function records results through the service-only RPC.';
comment on table private.jet_ski_daily_reward_entitlements is
'One best podium entitlement per account and Egypt-local day. Reward amounts remain null until the economy team approves the daily cash schedule; this table does not pay currency.';
comment on function private.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text) is
'Service-only idempotent race-result recorder. Consumes a short-lived server nonce, derives the Egypt-local day in Postgres, rejects conflicting event replays, and atomically maintains one best top-three entitlement per account/day without issuing a payout.';
),
    nonce uuid not null,
    expires_at timestamptz not null,
    created_at timestamptz not null default pg_catalog.now(),
    primary key (server_id, nonce)
);

create table if not exists private.jet_ski_daily_reward_entitlements (
    user_id uuid not null references auth.users(id) on delete cascade,
    egypt_day date not null,
    race_id uuid not null,
    best_place smallint not null check (best_place between 1 and 3),
    finish_time_usec bigint not null check (finish_time_usec >= 0),
    reward_cash bigint check (reward_cash is null or reward_cash between 0 and 2000000000),
    status text not null default 'pending_configuration'
        check (status in ('pending_configuration', 'pending_settlement', 'paid')),
    created_at timestamptz not null default pg_catalog.now(),
    updated_at timestamptz not null default pg_catalog.now(),
    paid_at timestamptz,
    primary key (user_id, egypt_day),
    foreign key (race_id, user_id)
        references private.jet_ski_race_results(race_id, user_id) on delete cascade,
    check (
        (status = 'paid' and reward_cash is not null and paid_at is not null)
        or
        (status <> 'paid' and paid_at is null)
    )
);

alter table private.jet_ski_race_results enable row level security;
alter table private.jet_ski_race_results force row level security;
alter table private.jet_ski_daily_reward_entitlements enable row level security;
alter table private.jet_ski_daily_reward_entitlements force row level security;

revoke all on table private.jet_ski_race_results, private.jet_ski_daily_reward_entitlements
    from public, anon, authenticated, service_role;
grant usage on schema private to service_role;
grant select, insert on table private.jet_ski_race_results to service_role;
grant select, insert, update on table private.jet_ski_daily_reward_entitlements to service_role;

drop policy if exists jet_ski_race_results_service_select on private.jet_ski_race_results;
create policy jet_ski_race_results_service_select
    on private.jet_ski_race_results for select to service_role using (true);
drop policy if exists jet_ski_race_results_service_insert on private.jet_ski_race_results;
create policy jet_ski_race_results_service_insert
    on private.jet_ski_race_results for insert to service_role with check (true);
drop policy if exists jet_ski_daily_entitlements_service_select on private.jet_ski_daily_reward_entitlements;
create policy jet_ski_daily_entitlements_service_select
    on private.jet_ski_daily_reward_entitlements for select to service_role using (true);
drop policy if exists jet_ski_daily_entitlements_service_insert on private.jet_ski_daily_reward_entitlements;
create policy jet_ski_daily_entitlements_service_insert
    on private.jet_ski_daily_reward_entitlements for insert to service_role with check (true);
drop policy if exists jet_ski_daily_entitlements_service_update on private.jet_ski_daily_reward_entitlements;
create policy jet_ski_daily_entitlements_service_update
    on private.jet_ski_daily_reward_entitlements for update to service_role
    using (true) with check (true);

create or replace function private.record_jet_ski_race_result(
    p_race_id uuid,
    p_server_event_id uuid,
    p_server_id text,
    p_user_id uuid,
    p_status text,
    p_place smallint,
    p_finish_time_usec bigint,
    p_reason text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_egypt_day date := (pg_catalog.now() at time zone 'Africa/Cairo')::date;
    v_by_event private.jet_ski_race_results%rowtype;
    v_by_racer private.jet_ski_race_results%rowtype;
    v_result private.jet_ski_race_results%rowtype;
    v_entitlement private.jet_ski_daily_reward_entitlements%rowtype;
    v_event_found boolean := false;
    v_racer_found boolean := false;
    v_inserted boolean := false;
begin
    if p_race_id is null or p_server_event_id is null or p_user_id is null
       or p_status is null or p_server_id is null or p_server_id !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{2,63}$'
       or p_status not in ('finished', 'dnf') then
        raise exception 'jet_ski_race_result_invalid' using errcode = '22023';
    end if;

    if p_status = 'finished' then
        if p_place is null or p_place < 1 or p_place > 4
           or p_finish_time_usec is null or p_finish_time_usec < 0
           or p_reason is not null then
            raise exception 'jet_ski_race_finish_payload_invalid' using errcode = '22023';
        end if;
    elsif p_place is not null or p_finish_time_usec is not null
       or p_reason is null or p_reason not in ('disconnect', 'time_limit') then
        raise exception 'jet_ski_race_dnf_payload_invalid' using errcode = '22023';
    end if;

    -- Serialize both idempotency dimensions before checking/inserting.
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_race_id::text || ':' || p_user_id::text, 0)
    );
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_server_event_id::text, 0)
    );

    select * into v_by_event
    from private.jet_ski_race_results
    where server_event_id = p_server_event_id;
    v_event_found := found;

    select * into v_by_racer
    from private.jet_ski_race_results
    where race_id = p_race_id and user_id = p_user_id;
    v_racer_found := found;

    if v_event_found and v_racer_found
       and v_by_event.server_event_id <> v_by_racer.server_event_id then
        raise exception 'jet_ski_race_result_conflict' using errcode = '23505';
    end if;

    if v_event_found or v_racer_found then
        v_result := case when v_event_found then v_by_event else v_by_racer end;
        if v_result.race_id <> p_race_id
           or v_result.server_event_id <> p_server_event_id
           or v_result.server_id <> p_server_id
           or v_result.user_id <> p_user_id
           or v_result.egypt_day <> v_egypt_day
           or v_result.status <> p_status
           or v_result.place is distinct from p_place
           or v_result.finish_time_usec is distinct from p_finish_time_usec
           or v_result.reason is distinct from p_reason then
            raise exception 'jet_ski_race_result_conflict' using errcode = '23505';
        end if;
    else
        insert into private.jet_ski_race_results (
            race_id, server_event_id, server_id, user_id, egypt_day,
            status, place, finish_time_usec, reason
        ) values (
            p_race_id, p_server_event_id, p_server_id, p_user_id, v_egypt_day,
            p_status, p_place, p_finish_time_usec, p_reason
        )
        returning * into v_result;
        v_inserted := true;
    end if;

    if p_status = 'finished' and p_place <= 3 then
        insert into private.jet_ski_daily_reward_entitlements (
            user_id, egypt_day, race_id, best_place, finish_time_usec
        ) values (
            p_user_id, v_egypt_day, p_race_id, p_place, p_finish_time_usec
        )
        on conflict (user_id, egypt_day) do update
        set race_id = excluded.race_id,
            best_place = excluded.best_place,
            finish_time_usec = excluded.finish_time_usec,
            updated_at = pg_catalog.now()
        where private.jet_ski_daily_reward_entitlements.status = 'pending_configuration'
          and (
              excluded.best_place < private.jet_ski_daily_reward_entitlements.best_place
              or (
                  excluded.best_place = private.jet_ski_daily_reward_entitlements.best_place
                  and excluded.finish_time_usec < private.jet_ski_daily_reward_entitlements.finish_time_usec
              )
          )
        returning * into v_entitlement;

        if not found then
            select * into v_entitlement
            from private.jet_ski_daily_reward_entitlements
            where user_id = p_user_id and egypt_day = v_egypt_day;
        end if;
    end if;

    return pg_catalog.jsonb_build_object(
        'recorded', true,
        'duplicate', not v_inserted,
        'egypt_day', v_egypt_day,
        'daily_reward_eligible', p_status = 'finished' and p_place between 1 and 3,
        'daily_best_place', case when v_entitlement.user_id is null then null else v_entitlement.best_place end,
        'entitlement_status', case when v_entitlement.user_id is null then null else v_entitlement.status end
    );
end;
$function$;

revoke all on function private.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text)
    from public, anon, authenticated;
grant execute on function private.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text)
    to service_role;

comment on table private.jet_ski_race_results is
'Append-only server-finalized royal jet ski race results. Client roles have no access; a trusted HMAC-verifying Edge Function records results through the service-only RPC.';
comment on table private.jet_ski_daily_reward_entitlements is
'One best podium entitlement per account and Egypt-local day. Reward amounts remain null until the economy team approves the daily cash schedule; this table does not pay currency.';
comment on function private.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text) is
'Service-only idempotent race-result recorder. Derives the Egypt-local day in Postgres, rejects conflicting event replays, and atomically maintains one best top-three entitlement per account/day without issuing a payout.';
