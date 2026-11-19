-- pgTAP tests for the untrusted player sync inbox.
-- Run locally with: supabase test db
begin;

select extensions.plan(10);

-- A disposable Auth user is required because accepted inbox rows reference auth.users.
insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at
) values (
    '00000000-0000-4000-8000-000000000038',
    'authenticated',
    'authenticated',
    'player-sync-inbox-test@example.invalid',
    '',
    pg_catalog.now()
)
on conflict (id) do nothing;

set local role authenticated;
select pg_catalog.set_config(
    'request.jwt.claim.sub',
    '00000000-0000-4000-8000-000000000038',
    true
);

-- 1. A valid allowlisted setting observation is accepted.
select extensions.is(
    (public.submit_player_sync_events(
        '[{"event_id":"10000000-0000-4000-8000-000000000001","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb
    ) ->> 'accepted')::integer,
    1,
    'accepts a valid setting observation'
);

-- 2. Replaying the same event ID is idempotent.
select extensions.is(
    (public.submit_player_sync_events(
        '[{"event_id":"10000000-0000-4000-8000-000000000001","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb
    ) ->> 'duplicates')::integer,
    1,
    'counts a replayed event as a duplicate'
);

-- 3. The RPC explicitly says that observations are not authoritative.
select extensions.is(
    public.submit_player_sync_events(
        '[{"event_id":"10000000-0000-4000-8000-000000000002","event_type":"setting_changed","payload":{"key":"music_enabled","value":true}}]'::jsonb
    ) ->> 'authoritative',
    'false',
    'never marks client observations as authoritative'
);

-- 4. Arbitrary setting keys are rejected.
select extensions.throws_ok(
    $$ select public.submit_player_sync_events(
        '[{"event_id":"10000000-0000-4000-8000-000000000003","event_type":"setting_changed","payload":{"key":"wallet_balance","value":999999}}]'::jsonb
    ) $$,
    '22023',
    'setting_key_not_allowed',
    'rejects setting keys outside the allowlist'
);

-- 5. Progress observations above the hard cap are rejected.
select extensions.throws_ok(
    $$ select public.submit_player_sync_events(
        '[{"event_id":"10000000-0000-4000-8000-000000000004","event_type":"mission_progress_observed","payload":{"progress_key":"mission.test","progress_value":1000001}}]'::jsonb
    ) $$,
    '22023',
    'invalid_progress_value',
    'rejects progress values above the configured cap'
);

-- 6. Event-specific progress namespaces prevent cross-domain key spoofing.
select extensions.throws_ok(
    $ select public.submit_player_sync_events(
        '[{"event_id":"10000000-0000-4000-8000-000000000008","event_type":"achievement_progress_observed","payload":{"progress_key":"mission.fake","progress_value":1}}]'::jsonb
    ) $,
    '22023',
    'progress_key_not_allowed',
    'enforces event-specific progress key namespaces'
);

select extensions.is(
    (select not prosecdef from pg_catalog.pg_proc
     where oid = 'public.submit_player_sync_events(jsonb)'::regprocedure),
    true,
    'RPC executes as invoker and relies on RLS'
);

-- 6. Extra event fields are rejected rather than silently accepted.
select extensions.throws_ok(
    $$ select public.submit_player_sync_events(
        '[{"event_id":"10000000-0000-4000-8000-000000000005","event_type":"setting_changed","payload":{"key":"locale","value":"ar"},"user_id":"00000000-0000-4000-8000-000000000001"}]'::jsonb
    ) $$,
    '22023',
    'invalid_event_shape',
    'rejects client-supplied identity fields'
);

-- 7. An absent JWT subject cannot submit events.
select pg_catalog.set_config('request.jwt.claim.sub', '', true);
select extensions.throws_ok(
    $$ select public.submit_player_sync_events(
        '[{"event_id":"10000000-0000-4000-8000-000000000006","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb
    ) $$,
    '28000',
    'authentication_required',
    'rejects unauthenticated submissions'
);

-- 8. Oversized batches are rejected before processing individual events.
select pg_catalog.set_config(
    'request.jwt.claim.sub',
    '00000000-0000-4000-8000-000000000038',
    true
);
select extensions.throws_ok(
    $$ select public.submit_player_sync_events(
        (select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'event_id', '10000000-0000-4000-8000-000000000007',
                'event_type', 'setting_changed',
                'payload', pg_catalog.jsonb_build_object('key', 'locale', 'value', 'ar')
            )
        ) from pg_catalog.generate_series(1, 51))
    ) $$,
    '22023',
    'invalid_event_batch',
    'rejects batches larger than 50 events'
);

reset role;
delete from auth.users
where id = '00000000-0000-4000-8000-000000000038';

select * from extensions.finish();
rollback;
