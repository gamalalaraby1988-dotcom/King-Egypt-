begin;
select extensions.plan(37);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values
('00000000-0000-4000-8000-000000000061','authenticated','authenticated','verified-progress-test@example.invalid','',pg_catalog.now()),
('00000000-0000-4000-8000-000000000062','authenticated','authenticated','verified-progress-other@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;

insert into private.player_activity_reward_catalog (
    activity_kind, activity_id, reward_cash, reward_chips, reward_xp, enabled
) values
('mission','mission.progress_only_test',0,0,0,false),
('mission','mission.progress_reward_test',25,1,5,true),
('achievement','explorer',250,5,0,false)
on conflict (activity_kind,activity_id) do update
set reward_cash=excluded.reward_cash,
    reward_chips=excluded.reward_chips,
    reward_xp=excluded.reward_xp,
    enabled=excluded.enabled;

select extensions.ok(
    not pg_catalog.has_function_privilege(
        'authenticated',
        'public.record_server_verified_activity_progress(uuid,text,text,uuid,text,timestamp with time zone,timestamp with time zone)',
        'EXECUTE'
    ),
    'authenticated clients cannot call the server progress writer'
);
select extensions.ok(
    not (select prosecdef from pg_catalog.pg_proc where oid='public.record_server_verified_activity_progress(uuid,text,text,uuid,text,timestamp with time zone,timestamp with time zone)'::pg_catalog.regprocedure),
    'server progress writer is SECURITY INVOKER'
);
select extensions.ok(
    not pg_catalog.has_table_privilege('service_role','private.player_verified_activity_progress','UPDATE'),
    'even the backend API role cannot rewrite verified progress'
);
select extensions.ok(
    not pg_catalog.has_table_privilege('service_role','private.player_verified_activity_progress','DELETE'),
    'even the backend API role cannot delete verified progress'
);

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000061',true);

select extensions.throws_ok(
    $$insert into private.player_verified_activity_progress(user_id,activity_kind,activity_id,server_event_id,evidence_digest,verified_at)
      values(auth.uid(),'mission','mission.fake','60000000-0000-4000-8000-000000000001',pg_catalog.decode(pg_catalog.repeat('11',32),'hex'),pg_catalog.now())$$,
    '42501',null,'clients cannot insert server-verified progress rows'
);

select extensions.is(
    (public.get_player_verified_activity_progress()->>'trust'),
    'server_verified',
    'verified progress endpoint identifies its trust level'
);
select extensions.is(
    pg_catalog.jsonb_array_length(public.get_player_verified_activity_progress()->'activities'),
    0,
    'unverified client observations are not promoted into the verified ledger'
);

reset role;
set local role service_role;

create temporary table progress_only_result on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','mission.progress_only_test',
    '60000000-0000-4000-8000-000000000011',
    pg_catalog.repeat('ab',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

select extensions.is((select result->>'progress_recorded' from progress_only_result),'true','server can persist verified progress while rewards are disabled');
select extensions.is((select result->>'reward_eligible' from progress_only_result),'false','reward eligibility is frozen as false at completion time');
select extensions.is((select result->>'proof_id' from progress_only_result),null::text,'no reward proof is created while the catalog entry is disabled');
select extensions.is(
    (select count(*)::integer from private.player_verified_activity_progress where user_id='00000000-0000-4000-8000-000000000061'),
    1,'server completion is written to the durable ledger'
);
select extensions.is(
    (select count(*)::integer from private.player_activity_proofs where user_id='00000000-0000-4000-8000-000000000061'),
    0,'progress-only completion does not create a reward proof'
);

select extensions.is(
    (public.record_server_verified_activity_progress(
        '00000000-0000-4000-8000-000000000061',
        'mission','mission.progress_only_test',
        '60000000-0000-4000-8000-000000000011',
        pg_catalog.repeat('ab',32),(select verified_at from private.player_verified_activity_progress where server_event_id='60000000-0000-4000-8000-000000000011'),
        (select verified_at from private.player_verified_activity_progress where server_event_id='60000000-0000-4000-8000-000000000011')+interval '5 minutes'
    )->>'duplicate'),
    'true','replaying the exact server event is idempotent'
);

select extensions.throws_ok(
    $$select public.record_server_verified_activity_progress(
        '00000000-0000-4000-8000-000000000061',
        'mission','mission.progress_only_test',
        '60000000-0000-4000-8000-000000000011',
        repeat('cd',32),now(),now()+interval '5 minutes'
    )$$,
    '23505','server_progress_event_conflict','reusing an event id with different evidence is rejected'
);

create temporary table reward_progress_result on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','mission.progress_reward_test',
    '60000000-0000-4000-8000-000000000012',
    pg_catalog.repeat('ef',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

select extensions.is((select result->>'reward_eligible' from reward_progress_result),'true','enabled reward catalog is captured at completion time');
select extensions.ok(
    pg_catalog.jsonb_typeof((select result->'proof_id' from reward_progress_result))='string',
    'reward-eligible server completion receives a proof'
);
select extensions.is(
    (select count(*)::integer from private.player_activity_proofs where user_id='00000000-0000-4000-8000-000000000061'),
    1,'only reward-eligible completion creates a reward proof'
);
select extensions.ok(
    not pg_catalog.has_function_privilege('authenticated','public.has_player_verified_activity(uuid,text,text)','EXECUTE'),
    'clients cannot query the backend-only mission completion lookup'
);
select extensions.is(
    public.has_player_verified_activity('00000000-0000-4000-8000-000000000061','mission','mission.progress_only_test'),
    true,'trusted game server can find a previously verified mission completion'
);
select extensions.is(
    public.has_player_verified_activity('00000000-0000-4000-8000-000000000062','mission','mission.progress_only_test'),
    false,'trusted game server lookup is scoped to the requested player identity'
);


create temporary table one_time_duplicate_result on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','mission.progress_reward_test',
    '60000000-0000-4000-8000-000000000013',
    pg_catalog.repeat('12',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

select extensions.is((select result->>'duplicate' from one_time_duplicate_result),'true','a second event cannot complete a one-time activity again');
select extensions.is((select result->>'proof_id' from one_time_duplicate_result),null::text,'a second one-time completion receives no new reward proof');
select extensions.is(
    (select count(*)::integer from private.player_verified_activity_progress where user_id='00000000-0000-4000-8000-000000000061' and activity_kind='mission' and activity_id='mission.progress_reward_test'),
    1,'one-time activity ledger keeps exactly one completion per account'
);
select extensions.is(
    (select count(*)::integer from private.player_activity_proofs where user_id='00000000-0000-4000-8000-000000000061' and activity_kind='mission' and activity_id='mission.progress_reward_test'),
    1,'one-time activity cannot mint a second reward proof from another session'
);

create temporary table adventure_replay_first on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','city_adventure_message',
    '60000000-0000-4000-8000-000000000014',
    pg_catalog.repeat('34',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

create temporary table adventure_replay_second on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','city_adventure_message',
    '60000000-0000-4000-8000-000000000015',
    pg_catalog.repeat('56',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

select extensions.is((select result->>'duplicate' from adventure_replay_first),'false','first city adventure completion is recorded');
select extensions.is((select result->>'duplicate' from adventure_replay_second),'false','city adventures remain replayable across sessions');
select extensions.is(
    (select count(*)::integer from private.player_verified_activity_progress where user_id='00000000-0000-4000-8000-000000000061' and activity_kind='mission' and activity_id='city_adventure_message'),
    2,'replayable city adventures may keep multiple verified completions'
);


create temporary table unapproved_mission_result on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','mission_unapproved_test',
    '60000000-0000-4000-8000-000000000016',
    pg_catalog.repeat('01',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

select extensions.is((select result->>'achievement_unlocked' from unapproved_mission_result),'false','unapproved missions do not count toward Explorer');

create temporary table explorer_shop_result on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','mission_shop',
    '60000000-0000-4000-8000-000000000021',
    pg_catalog.repeat('02',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

select extensions.is((select result->>'achievement_unlocked' from explorer_shop_result),'false','one approved building mission is not enough for Explorer');

create temporary table explorer_restaurant_result on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','mission_restaurant',
    '60000000-0000-4000-8000-000000000022',
    pg_catalog.repeat('03',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

select extensions.is((select result->>'achievement_unlocked' from explorer_restaurant_result),'false','two approved building missions are not enough for Explorer');

create temporary table explorer_employment_result on commit drop as
select public.record_server_verified_activity_progress(
    '00000000-0000-4000-8000-000000000061',
    'mission','mission_employment',
    '60000000-0000-4000-8000-000000000023',
    pg_catalog.repeat('04',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
) as result;

select extensions.is((select result->>'achievement_unlocked' from explorer_employment_result),'true','the third approved building mission unlocks Explorer');
select extensions.is((select result->>'achievement_reward_eligible' from explorer_employment_result),'false','Explorer reward eligibility remains disabled until its catalog is enabled');
select extensions.is((select result->>'achievement_proof_id' from explorer_employment_result),null::text,'no Explorer reward proof is issued while rewards are disabled');
select extensions.is(
    (select count(*)::integer from private.player_verified_activity_progress where user_id='00000000-0000-4000-8000-000000000061' and activity_kind='achievement' and activity_id='explorer'),
    1,'Explorer is recorded exactly once in the server verified ledger'
);
select extensions.is(
    (select count(*)::integer from private.player_activity_proofs where user_id='00000000-0000-4000-8000-000000000061' and activity_kind='achievement' and activity_id='explorer'),
    0,'disabled Explorer rewards do not create a proof'
);


reset role;
set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000061',true);

select extensions.is(
    pg_catalog.jsonb_array_length(public.get_player_verified_activity_progress()->'activities'),
    4,'player can retrieve their own verified progress including replayable adventures'
);
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
select extensions.is(
    pg_catalog.jsonb_array_length(public.get_player_verified_activity_progress()->'activities'),
    0,'another player cannot see the first player verified progress'
);

reset role;
select * from extensions.finish();
rollback;
