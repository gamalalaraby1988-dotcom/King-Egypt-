-- Offline progress sync inbox. Client events are observations, never grants.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.player_sync_events (
    user_id uuid not null references auth.users(id) on delete cascade,
    event_id uuid not null,
    event_type text not null check (
        event_type in (
            'setting_changed',
            'mission_progress_observed',
            'achievement_progress_observed',
            'activity_progress_observed'
        )
    ),
    payload jsonb not null check (jsonb_typeof(payload) = 'object'),
    created_at timestamptz not null default pg_catalog.now(),
    primary key (user_id, event_id),
    check (pg_catalog.pg_column_size(payload) <= 8192)
);

alter table private.player_sync_events enable row level security;
revoke all on table private.player_sync_events from public, anon, authenticated;

create or replace function public.submit_player_sync_events(p_events jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_event jsonb;
    v_event_id uuid;
    v_event_type text;
    v_payload jsonb;
    v_key text;
    v_value jsonb;
    v_rows integer;
    v_inserted integer := 0;
    v_duplicates integer := 0;
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode = '28000';
    end if;

    if pg_catalog.jsonb_typeof(p_events) <> 'array'
       or pg_catalog.jsonb_array_length(p_events) < 1
       or pg_catalog.jsonb_array_length(p_events) > 50 then
        raise exception 'invalid_event_batch' using errcode = '22023';
    end if;

    for v_event in select value from pg_catalog.jsonb_array_elements(p_events)
    loop
        if pg_catalog.jsonb_typeof(v_event) <> 'object'
           or not (v_event ? 'event_id')
           or not (v_event ? 'event_type')
           or not (v_event ? 'payload')
           or pg_catalog.jsonb_object_length(v_event) <> 3 then
            raise exception 'invalid_event_shape' using errcode = '22023';
        end if;

        begin
            v_event_id := (v_event ->> 'event_id')::uuid;
        exception when others then
            raise exception 'invalid_event_id' using errcode = '22023';
        end;

        v_event_type := v_event ->> 'event_type';
        v_payload := v_event -> 'payload';

        if pg_catalog.jsonb_typeof(v_payload) <> 'object'
           or pg_catalog.pg_column_size(v_payload) > 8192 then
            raise exception 'invalid_event_payload' using errcode = '22023';
        end if;

        if v_event_type = 'setting_changed' then
            if pg_catalog.jsonb_object_length(v_payload) <> 2
               or not (v_payload ? 'key')
               or not (v_payload ? 'value') then
                raise exception 'invalid_setting_event' using errcode = '22023';
            end if;

            v_key := v_payload ->> 'key';
            v_value := v_payload -> 'value';

            if v_key = 'locale' then
                if pg_catalog.jsonb_typeof(v_value) <> 'string'
                   or pg_catalog.length(v_value #>> '{}') > 16 then
                    raise exception 'invalid_setting_value' using errcode = '22023';
                end if;
            elsif v_key = 'camera_sensitivity' then
                if pg_catalog.jsonb_typeof(v_value) <> 'number'
                   or (v_value #>> '{}')::numeric < 0.1
                   or (v_value #>> '{}')::numeric > 3.0 then
                    raise exception 'invalid_setting_value' using errcode = '22023';
                end if;
            elsif v_key in ('music_enabled', 'sfx_enabled') then
                if pg_catalog.jsonb_typeof(v_value) <> 'boolean' then
                    raise exception 'invalid_setting_value' using errcode = '22023';
                end if;
            elsif v_key = 'control_layout' then
                if pg_catalog.jsonb_typeof(v_value) <> 'string'
                   or v_value #>> '{}' not in ('classic', 'left_handed') then
                    raise exception 'invalid_setting_value' using errcode = '22023';
                end if;
            else
                raise exception 'setting_key_not_allowed' using errcode = '22023';
            end if;

        elsif v_event_type in (
            'mission_progress_observed',
            'achievement_progress_observed',
            'activity_progress_observed'
        ) then
            if pg_catalog.jsonb_object_length(v_payload) <> 2
               or not (v_payload ? 'progress_key')
               or not (v_payload ? 'progress_value') then
                raise exception 'invalid_progress_event' using errcode = '22023';
            end if;

            if pg_catalog.jsonb_typeof(v_payload -> 'progress_key') <> 'string'
               or pg_catalog.length(v_payload ->> 'progress_key') < 1
               or pg_catalog.length(v_payload ->> 'progress_key') > 80
               or pg_catalog.jsonb_typeof(v_payload -> 'progress_value') <> 'number'
               or (v_payload ->> 'progress_value') !~ '^[0-9]{1,7}$'
               or (v_payload ->> 'progress_value')::integer > 1000000 then
                raise exception 'invalid_progress_value' using errcode = '22023';
            end if;
        else
            raise exception 'event_type_not_allowed' using errcode = '22023';
        end if;

        insert into private.player_sync_events (
            user_id, event_id, event_type, payload
        ) values (
            v_user_id, v_event_id, v_event_type, v_payload
        )
        on conflict (user_id, event_id) do nothing;

        get diagnostics v_rows = row_count;
        if v_rows = 1 then
            v_inserted := v_inserted + 1;
        else
            v_duplicates := v_duplicates + 1;
        end if;
    end loop;

    return pg_catalog.jsonb_build_object(
        'accepted', v_inserted,
        'duplicates', v_duplicates,
        'authoritative', false
    );
end;
$function$;

revoke all on function public.submit_player_sync_events(jsonb) from public, anon;
grant execute on function public.submit_player_sync_events(jsonb) to authenticated;

comment on table private.player_sync_events is
'Untrusted player-originated sync observations. Never use these rows to grant currency, items, ownership, rewards, or founder privileges.';
comment on function public.submit_player_sync_events(jsonb) is
'Idempotently records bounded, allowlisted player observations for the authenticated user. Does not grant rewards or alter authoritative game state.';
