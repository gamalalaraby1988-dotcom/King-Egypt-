begin;
select extensions.plan(45);
insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values
    ('00000000-0000-4000-8000-000000000038','authenticated','authenticated','player-sync-inbox-test-a@example.invalid','',pg_catalog.now()),
    ('00000000-0000-4000-8000-000000000039','authenticated','authenticated','player-sync-inbox-test-b@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;
set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000038',true);

select extensions.is((public.get_player_preference_snapshot()->>'revision')::bigint,0::bigint,'new account starts with empty preference snapshot revision');
select extensions.is((public.save_player_preference_snapshot(0,'{"locale":"ar","volume":65,"quality":2}'::jsonb)->>'saved')::boolean,true,'saves allowlisted preference snapshot');
select extensions.is((public.get_player_preference_snapshot()->>'revision')::bigint,1::bigint,'snapshot read returns committed revision');
select extensions.is((public.save_player_preference_snapshot(0,'{"locale":"en"}'::jsonb)->>'conflict')::boolean,true,'stale snapshot revision returns conflict without overwrite');
select extensions.throws_ok($$select public.save_player_preference_snapshot(1,'{"wallet_balance":999999}'::jsonb)$$,'22023','setting_key_not_allowed','snapshot rejects financial or unknown fields');
select pg_catalog.set_config('request.jwt.claim.sub','',true);
select extensions.throws_ok($$select public.get_player_preference_snapshot()$$,'28000','authentication_required','snapshot read rejects unauthenticated access');
select extensions.throws_ok($$select public.save_player_preference_snapshot(0,'{}'::jsonb)$$,'28000','authentication_required','snapshot write rejects unauthenticated access');
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000038',true);

select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000001","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb)->>'accepted')::integer,1,'accepts valid settings with invoker privileges');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000001","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb)->>'duplicates')::integer,1,'deduplicates replayed event IDs');
select extensions.is(public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000002","event_type":"setting_changed","payload":{"key":"music_enabled","value":true}}]'::jsonb)->>'authoritative','false','client observations are never authoritative');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000009","event_type":"setting_changed","payload":{"key":"volume","value":65}}]'::jsonb)->>'accepted')::integer,1,'accepts bounded volume preference');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000010","event_type":"setting_changed","payload":{"key":"quality","value":2}}]'::jsonb)->>'accepted')::integer,1,'accepts supported graphics quality preference');
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000011","event_type":"setting_changed","payload":{"key":"quality","value":3}}]'::jsonb)$$,'22023','invalid_setting_value','rejects graphics quality outside supported choices');
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000003","event_type":"setting_changed","payload":{"key":"wallet_balance","value":999999}}]'::jsonb)$$,'22023','setting_key_not_allowed','rejects unapproved setting keys');
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000004","event_type":"mission_progress_observed","payload":{"progress_key":"mission.test","progress_value":1000001}}]'::jsonb)$$,'22023','invalid_progress_value','rejects progress values above the cap');
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000008","event_type":"achievement_progress_observed","payload":{"progress_key":"mission.fake","progress_value":1}}]'::jsonb)$$,'22023','progress_key_not_allowed','enforces event-specific progress namespaces');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000012","event_type":"mission_progress_observed","payload":{"progress_key":"mission.completed","progress_value":12}}]'::jsonb)->>'accepted')::integer,1,'stores mission progress observation for account recovery');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000013","event_type":"mission_progress_observed","payload":{"progress_key":"mission.completed","progress_value":4}}]'::jsonb)->>'accepted')::integer,1,'accepts a later lower observation without lowering recovered progress');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000012","event_type":"mission_progress_observed","payload":{"progress_key":"mission.completed","progress_value":999}}]'::jsonb)->>'duplicates')::integer,1,'replaying an accepted progress event is idempotent even with a changed payload');
select extensions.is(((select value from pg_catalog.jsonb_array_elements(public.get_player_progress_observations()->'observations') where value->>'progress_key'='mission.completed')->>'progress_value')::integer,12,'a replayed stale event cannot replace the newest stored progress');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000014","event_type":"achievement_progress_observed","payload":{"progress_key":"achievement.jobs","progress_value":9}}]'::jsonb)->>'accepted')::integer,1,'stores achievement observation separately');
select extensions.is(public.get_player_progress_observations()->>'authoritative','false','progress recovery response is explicitly non-authoritative');
select extensions.is(public.get_player_progress_observations()->>'trust','unverified_client_observations','progress recovery response carries unverified trust label');
select extensions.is(pg_catalog.jsonb_array_length(public.get_player_progress_observations()->'observations'),2,'returns the two aggregated progress keys');
select extensions.is(((select value from pg_catalog.jsonb_array_elements(public.get_player_progress_observations()->'observations') where value->>'progress_key'='mission.completed')->>'progress_value')::integer,12,'progress aggregation never decreases an observed value');

-- Switch to a second synthetic Auth identity and prove snapshots and recovery are account-scoped.
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000039',true);
select extensions.is((public.get_player_preference_snapshot()->>'revision')::bigint,0::bigint,'second account starts with its own empty preference snapshot');
select extensions.is(public.get_player_preference_snapshot()->'settings','{}'::jsonb,'second account cannot inherit first account preferences');
select extensions.is(pg_catalog.jsonb_array_length(public.get_player_progress_observations()->'observations'),0,'second account cannot read first account progress observations');
select extensions.is((public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000012","event_type":"mission_progress_observed","payload":{"progress_key":"mission.completed","progress_value":3}}]'::jsonb)->>'accepted')::integer,1,'same event ID is independent across different player accounts');
select extensions.is(((select value from pg_catalog.jsonb_array_elements(public.get_player_progress_observations()->'observations') where value->>'progress_key'='mission.completed')->>'progress_value')::integer,3,'second account recovers only its own mission observation');
select extensions.is((public.save_player_preference_snapshot(0,'{"locale":"en","volume":25}'::jsonb)->>'saved')::boolean,true,'second account saves an independent preference snapshot');
select extensions.is((select pg_catalog.count(*)::integer from private.player_sync_events where user_id='00000000-0000-4000-8000-000000000038'),0,'RLS hides first account inbox rows from second account');
select extensions.is((select pg_catalog.count(*)::integer from private.player_progress_observations where user_id='00000000-0000-4000-8000-000000000038'),0,'RLS hides first account progress rows from second account');

select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000038',true);
select extensions.is(((select value from pg_catalog.jsonb_array_elements(public.get_player_progress_observations()->'observations') where value->>'progress_key'='mission.completed')->>'progress_value')::integer,12,'switching back restores first account progress without second account contamination');
select extensions.is(public.get_player_preference_snapshot()->'settings'->>'locale','ar','first account retains its original preference snapshot');
select extensions.is((select pg_catalog.count(*)::integer from private.player_sync_events where user_id='00000000-0000-4000-8000-000000000039'),0,'RLS hides second account inbox rows from first account');

select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000039',true);
select extensions.is(((select value from pg_catalog.jsonb_array_elements(public.get_player_progress_observations()->'observations') where value->>'progress_key'='mission.completed')->>'progress_value')::integer,3,'second account progress remains unchanged after switching back and forth');
select extensions.is(public.get_player_preference_snapshot()->'settings'->>'locale','en','second account retains its independent preference snapshot');
select extensions.is((select pg_catalog.count(*)::integer from private.player_sync_snapshots where user_id='00000000-0000-4000-8000-000000000038'),0,'RLS hides first account preference snapshot from second account');

select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000038',true);
select extensions.is((select not prosecdef from pg_catalog.pg_proc where oid='public.submit_player_sync_events(jsonb)'::regprocedure),true,'RPC is SECURITY INVOKER');
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000005","event_type":"setting_changed","payload":{"key":"locale","value":"ar"},"user_id":"00000000-0000-4000-8000-000000000001"}]'::jsonb)$$,'22023','invalid_event_shape','rejects client-supplied identity');
select pg_catalog.set_config('request.jwt.claim.sub','',true);
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"10000000-0000-4000-8000-000000000006","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb)$$,'28000','authentication_required','rejects unauthenticated submissions');
select extensions.throws_ok($$select public.get_player_progress_observations()$$,'28000','authentication_required','progress recovery rejects unauthenticated access');
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000038',true);
select extensions.throws_ok($$select public.submit_player_sync_events((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('event_id','10000000-0000-4000-8000-000000000007','event_type','setting_changed','payload',pg_catalog.jsonb_build_object('key','locale','value','ar'))) from pg_catalog.generate_series(1,51)))$$,'22023','invalid_event_batch','rejects batches over 50 events');

do $rate_test$
declare
    batch_no integer;
    batch_events jsonb;
begin
    for batch_no in 0..3 loop
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'event_id',('20000000-0000-4000-8000-' || pg_catalog.lpad(gs::text,12,'0'))::text,
            'event_type','setting_changed',
            'payload',pg_catalog.jsonb_build_object('key','locale','value','ar')
        ))
        into batch_events
        from pg_catalog.generate_series(batch_no * 50 + 1, least(batch_no * 50 + 50, 193)) gs;
        perform public.submit_player_sync_events(batch_events);
    end loop;
end;
$rate_test$;
select extensions.throws_ok($$select public.submit_player_sync_events('[{"event_id":"30000000-0000-4000-8000-000000000001","event_type":"setting_changed","payload":{"key":"locale","value":"ar"}}]'::jsonb)$$,'P0001','sync_rate_limited','enforces the per-player rolling event limit');

reset role;
delete from auth.users where id in ('00000000-0000-4000-8000-000000000038','00000000-0000-4000-8000-000000000039');
select * from extensions.finish();
rollback;
