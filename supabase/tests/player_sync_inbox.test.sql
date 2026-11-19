begin;
select extensions.plan(11);
insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values ('00000000-0000-4000-8000-000000000038','authenticated','authenticated','player-sync-inbox-test@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;
set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000038',true);

select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000001","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb)->>'accepted')::integer,1,'accepts valid settings with invoker privileges');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000001","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb)->>'duplicates')::integer,1,'deduplicates replayed event IDs');
select extensions.is(public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000002","event_type":"setting_changed","payload":{"key":"music_enabled","value":true}}]'::jsonb)->>'authoritative','false','client observations are never authoritative');

select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000003","event_type":"setting_changed","payload":{"key":"wallet_balance","value":999999}}]'::jsonb)$$,'22023','setting_key_not_allowed','rejects unapproved setting keys');
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000004","event_type":"mission_progress_observed","payload":{"progress_key":"mission.test","progress_value":1000001}}]'::jsonb)$$,'22023','invalid_progress_value','rejects progress values above the cap');
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000008","event_type":"achievement_progress_observed","payload":{"progress_key":"mission.fake","progress_value":1}}]'::jsonb)$$,'22023','progress_key_not_allowed','enforces event-specific progress namespaces');
select extensions.is((select not prosecdef from pg_catalog.pg_proc where oid='public.submit_player_sync_events(jsonb)'::regprocedure),true,'RPC is SECURITY INVOKER');

select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000005","event_type":"setting_changed","payload":{"key":"locale","value":"ar"},"user_id":"00000000-0000-4000-8000-000000000001"}]'::jsonb)$$,'22023','invalid_event_shape','rejects client-supplied identity');
select pg_catalog.set_config('request.jwt.claim.sub','',true);
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000006","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb)$$,'28000','authentication_required','rejects unauthenticated submissions');
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000038',true);
select extensions.throws_ok($$select public.submit_player_sync_events((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('event_id','10000000-0000-4000-8000-000000000007','event_type','setting_changed','payload',pg_catalog.jsonb_build_object('key','locale','value','ar'))) from pg_catalog.generate_series(1,51)))$$,'22023','invalid_event_batch','rejects batches over 50 events');

select extensions.throws_ok(
    $select public.submit_player_sync_events(
        (select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'event_id', ('20000000-0000-4000-8000-' || pg_catalog.lpad(gs::text,12,'0'))::text,
            'event_type','setting_changed',
            'payload',pg_catalog.jsonb_build_object('key','locale','value','ar')
        )) from pg_catalog.generate_series(1,198) gs)
    )$,
    'P0001',
    'sync_rate_limited',
    'enforces the per-player rolling event limit'
);

reset role;
delete from auth.users where id='00000000-0000-4000-8000-000000000038';
select * from extensions.finish();
rollback;
