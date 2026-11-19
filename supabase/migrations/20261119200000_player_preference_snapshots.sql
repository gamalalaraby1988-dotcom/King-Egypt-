-- Versioned cross-device snapshot for non-sensitive player preferences only.
-- Progress observations remain append-only events and are not authoritative state.
create table if not exists private.player_sync_snapshots (
    user_id uuid primary key references auth.users(id) on delete cascade,
    revision bigint not null default 0 check (revision >= 0),
    settings jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now(),
    constraint player_sync_snapshots_settings_object check (jsonb_typeof(settings) = 'object')
);

alter table private.player_sync_snapshots enable row level security;
alter table private.player_sync_snapshots force row level security;

drop policy if exists player_sync_snapshots_select_own on private.player_sync_snapshots;
create policy player_sync_snapshots_select_own
    on private.player_sync_snapshots
    for select to authenticated
    using (user_id = (select auth.uid()));

drop policy if exists player_sync_snapshots_insert_own on private.player_sync_snapshots;
create policy player_sync_snapshots_insert_own
    on private.player_sync_snapshots
    for insert to authenticated
    with check (user_id = (select auth.uid()));

drop policy if exists player_sync_snapshots_update_own on private.player_sync_snapshots;
create policy player_sync_snapshots_update_own
    on private.player_sync_snapshots
    for update to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

revoke all on table private.player_sync_snapshots from public, anon, authenticated;
grant usage on schema private to authenticated;
grant select, insert, update on table private.player_sync_snapshots to authenticated;

create or replace function public.get_player_preference_snapshot()
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_row private.player_sync_snapshots%rowtype;
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode = '28000';
    end if;

    select * into v_row
    from private.player_sync_snapshots
    where user_id = v_user_id;

    if not found then
        return jsonb_build_object('revision', 0, 'settings', '{}'::jsonb, 'updated_at', null);
    end if;

    return jsonb_build_object(
        'revision', v_row.revision,
        'settings', v_row.settings,
        'updated_at', v_row.updated_at
    );
end;
$function$;

create or replace function public.save_player_preference_snapshot(
    p_expected_revision bigint,
    p_settings jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_current_revision bigint;
    v_next_revision bigint;
    v_key text;
    v_value jsonb;
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode = '28000';
    end if;
    if p_expected_revision is null or p_expected_revision < 0 then
        raise exception 'invalid_snapshot_revision' using errcode = '22023';
    end if;
    if p_settings is null or jsonb_typeof(p_settings) <> 'object'
       or octet_length(p_settings::text) > 8192 then
        raise exception 'invalid_snapshot_payload' using errcode = '22023';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_user_id::text, 0)
    );

    select revision into v_current_revision
    from private.player_sync_snapshots
    where user_id = v_user_id
    for update;

    v_current_revision := coalesce(v_current_revision, 0);
    if p_expected_revision <> v_current_revision then
        return jsonb_build_object(
            'saved', false,
            'conflict', true,
            'revision', v_current_revision
        );
    end if;

    for v_key, v_value in select key, value from jsonb_each(p_settings)
    loop
        if v_key = 'locale' then
            if jsonb_typeof(v_value) <> 'string'
               or length(v_value #>> '{}') > 16 then
                raise exception 'invalid_setting_value' using errcode = '22023';
            end if;
        elsif v_key = 'volume' then
            if jsonb_typeof(v_value) <> 'number'
               or (v_value #>> '{}')::numeric < 0
               or (v_value #>> '{}')::numeric > 100
               or (v_value #>> '{}')::numeric <> trunc((v_value #>> '{}')::numeric) then
                raise exception 'invalid_setting_value' using errcode = '22023';
            end if;
        elsif v_key = 'quality' then
            if jsonb_typeof(v_value) <> 'number'
               or (v_value #>> '{}')::numeric not in (0, 1, 2)
               or (v_value #>> '{}')::numeric <> trunc((v_value #>> '{}')::numeric) then
                raise exception 'invalid_setting_value' using errcode = '22023';
            end if;
        else
            raise exception 'setting_key_not_allowed' using errcode = '22023';
        end if;
    end loop;

    v_next_revision := v_current_revision + 1;
    insert into private.player_sync_snapshots (user_id, revision, settings, updated_at)
    values (v_user_id, v_next_revision, p_settings, now())
    on conflict (user_id) do update
    set revision = excluded.revision,
        settings = excluded.settings,
        updated_at = excluded.updated_at;

    return jsonb_build_object(
        'saved', true,
        'conflict', false,
        'revision', v_next_revision
    );
end;
$function$;

revoke all on function public.get_player_preference_snapshot() from public, anon;
revoke all on function public.save_player_preference_snapshot(bigint, jsonb) from public, anon;
grant execute on function public.get_player_preference_snapshot() to authenticated;
grant execute on function public.save_player_preference_snapshot(bigint, jsonb) to authenticated;
