-- Progress observations are recoverable across devices but remain explicitly unverified.
-- They never update missions, achievements, XP, currency, rewards, or ownership.
create table if not exists private.player_progress_observations (
    user_id uuid not null references auth.users(id) on delete cascade,
    progress_key text not null check (
        progress_key ~ '^(mission|achievement|activity)[.][a-z0-9][a-z0-9_.-]{0,70}$'
    ),
    observed_value integer not null check (observed_value between 0 and 1000000),
    updated_at timestamptz not null default pg_catalog.now(),
    primary key (user_id, progress_key)
);

alter table private.player_progress_observations enable row level security;
alter table private.player_progress_observations force row level security;
revoke all on table private.player_progress_observations from public, anon, authenticated;
grant usage on schema private to authenticated;
grant select, insert, update on table private.player_progress_observations to authenticated;

drop policy if exists player_progress_observations_select_own on private.player_progress_observations;
create policy player_progress_observations_select_own
    on private.player_progress_observations
    for select to authenticated
    using (user_id = (select auth.uid()));

drop policy if exists player_progress_observations_insert_own on private.player_progress_observations;
create policy player_progress_observations_insert_own
    on private.player_progress_observations
    for insert to authenticated
    with check (user_id = (select auth.uid()));

drop policy if exists player_progress_observations_update_own on private.player_progress_observations;
create policy player_progress_observations_update_own
    on private.player_progress_observations
    for update to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

create or replace function private.capture_player_progress_observation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_key text;
    v_value integer;
begin
    if new.event_type not in (
        'mission_progress_observed',
        'achievement_progress_observed',
        'activity_progress_observed'
    ) then
        return new;
    end if;

    v_key := new.payload ->> 'progress_key';
    v_value := (new.payload ->> 'progress_value')::integer;

    insert into private.player_progress_observations (
        user_id, progress_key, observed_value, updated_at
    ) values (
        new.user_id, v_key, v_value, pg_catalog.now()
    )
    on conflict (user_id, progress_key) do update
    set observed_value = greatest(
            private.player_progress_observations.observed_value,
            excluded.observed_value
        ),
        updated_at = pg_catalog.now();

    return new;
end;
$function$;

drop trigger if exists capture_player_progress_observation on private.player_sync_events;
create trigger capture_player_progress_observation
after insert on private.player_sync_events
for each row execute function private.capture_player_progress_observation();

create or replace function public.get_player_progress_observations()
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
    select pg_catalog.jsonb_build_object(
        'authoritative', false,
        'trust', 'unverified_client_observations',
        'observations',
        coalesce(
            (
                select pg_catalog.jsonb_agg(
                    pg_catalog.jsonb_build_object(
                        'progress_key', progress_key,
                        'progress_value', observed_value,
                        'updated_at', updated_at
                    )
                    order by progress_key
                )
                from private.player_progress_observations
                where user_id = (select auth.uid())
            ),
            '[]'::jsonb
        )
    );
$function$;

revoke all on function private.capture_player_progress_observation() from public, anon;
revoke all on function public.get_player_progress_observations() from public, anon;
grant execute on function public.get_player_progress_observations() to authenticated;

comment on table private.player_progress_observations is
'Aggregated client-originated progress observations for cross-device review only. Never authoritative and never a source for rewards, XP, currency, achievements, mission completion, or ownership.';
comment on function public.get_player_progress_observations() is
'Returns only the authenticated user progress observations and labels them unverified. Does not restore authoritative game progression.';
