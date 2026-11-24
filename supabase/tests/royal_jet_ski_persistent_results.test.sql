begin;
select extensions.plan(15);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values
('00000000-0000-4000-8000-000000000051','authenticated','authenticated','jet-ski-result-one@example.invalid','',pg_catalog.now()),
('00000000-0000-4000-8000-000000000052','authenticated','authenticated','jet-ski-result-two@example.invalid','',pg_catalog.now()),
('00000000-0000-4000-8000-000000000053','authenticated','authenticated','jet-ski-result-three@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;

set local role service_role;

select extensions.is(
  (private.record_jet_ski_race_result(
    '10000000-0000-4000-8000-000000000051','20000000-0000-4000-8000-000000000051',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000051','finished',2::smallint,3200000::bigint,
    '30000000-0000-4000-8000-000000000051',pg_catalog.now(),null::text
  )->>'recorded')::boolean,
  true,
  'records a server-finalized finish result'
);

select extensions.is(
  (private.record_jet_ski_race_result(
    '10000000-0000-4000-8000-000000000051','20000000-0000-4000-8000-000000000051',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000051','finished',2::smallint,3200000::bigint,
    '30000000-0000-4000-8000-000000000052',pg_catalog.now(),null::text
  )->>'duplicate')::boolean,
  true,
  'replaying the identical server event with a fresh nonce is idempotent'
);

select extensions.throws_ok(
  $$select private.record_jet_ski_race_result(
    '10000000-0000-4000-8000-000000000051','20000000-0000-4000-8000-000000000099',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000051','finished',1::smallint,2500000::bigint,
    '30000000-0000-4000-8000-000000000053',pg_catalog.now(),null::text
  )$$,
  '23505','jet_ski_race_result_conflict',
  'a second conflicting result for the same racer and race is rejected'
);

select extensions.throws_ok(
  $$select private.record_jet_ski_race_result(
    '10000000-0000-4000-8000-000000000059','20000000-0000-4000-8000-000000000059',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000051','finished',1::smallint,1000::bigint,
    '30000000-0000-4000-8000-000000000051',pg_catalog.now(),null::text
  )$$,
  '23505','jet_ski_race_server_nonce_replayed',
  'a reused server nonce is rejected even when the race event id differs'
);

select extensions.throws_ok(
  $$select private.record_jet_ski_race_result(
    '10000000-0000-4000-8000-000000000058','20000000-0000-4000-8000-000000000058',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000051','dnf',null::smallint,null::bigint,
    '30000000-0000-4000-8000-000000000058',pg_catalog.now(),null::text
  )$$,
  '22023','jet_ski_race_dnf_payload_invalid',
  'DNF records require a recognized server reason'
);

select extensions.is(
  (private.record_jet_ski_race_result(
    '10000000-0000-4000-8000-000000000052','20000000-0000-4000-8000-000000000052',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000051','finished',1::smallint,2800000::bigint,
    '30000000-0000-4000-8000-000000000054',pg_catalog.now(),null::text
  )->>'daily_best_place')::smallint,
  1::smallint,
  'a better later podium result replaces the daily best place'
);

select extensions.is(
  (select count(*) from private.jet_ski_daily_reward_entitlements
   where user_id='00000000-0000-4000-8000-000000000051'
     and egypt_day=(pg_catalog.now() at time zone 'Africa/Cairo')::date),
  1::bigint,
  'multiple podium finishes create only one entitlement for the Egypt-local day'
);

select extensions.is(
  (select best_place from private.jet_ski_daily_reward_entitlements
   where user_id='00000000-0000-4000-8000-000000000051'
     and egypt_day=(pg_catalog.now() at time zone 'Africa/Cairo')::date),
  1::smallint,
  'the daily entitlement keeps the best rank achieved'
);

select extensions.is(
  (select reward_cash is null and status='pending_configuration'
   from private.jet_ski_daily_reward_entitlements
   where user_id='00000000-0000-4000-8000-000000000051'
     and egypt_day=(pg_catalog.now() at time zone 'Africa/Cairo')::date),
  true,
  'podium entitlement is recorded without inventing or paying a cash amount'
);

select extensions.is(
  (private.record_jet_ski_race_result(
    '10000000-0000-4000-8000-000000000053','20000000-0000-4000-8000-000000000053',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000052','dnf',null::smallint,null::bigint,
    '30000000-0000-4000-8000-000000000055',pg_catalog.now(),'disconnect'
  )->>'daily_reward_eligible')::boolean,
  false,
  'DNF results do not create a podium entitlement'
);

select extensions.is(
  (select count(*) from private.jet_ski_daily_reward_entitlements
   where user_id='00000000-0000-4000-8000-000000000052'),
  0::bigint,
  'DNF account has no daily reward entitlement'
);

select extensions.is(
  (private.record_jet_ski_race_result(
    '10000000-0000-4000-8000-000000000054','20000000-0000-4000-8000-000000000054',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000053','finished',4::smallint,5000000::bigint,
    '30000000-0000-4000-8000-000000000056',pg_catalog.now(),null::text
  )->>'daily_reward_eligible')::boolean,
  false,
  'fourth place is not eligible for the daily podium entitlement'
);

reset role;
set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000051',true);

select extensions.ok(
  not pg_catalog.has_function_privilege(
    'authenticated',
    'public.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text)',
    'EXECUTE'
  ),
  'authenticated clients cannot call the public server-only result wrapper'
);

select extensions.ok(
  not pg_catalog.has_function_privilege(
    'authenticated',
    'private.record_jet_ski_race_result(uuid,uuid,text,uuid,text,smallint,bigint,uuid,timestamptz,text)',
    'EXECUTE'
  ),
  'authenticated clients cannot call the private server-only result recorder'
);

select extensions.throws_ok(
  $$insert into private.jet_ski_race_results (
    race_id,server_event_id,server_id,user_id,egypt_day,status,place,finish_time_usec
  ) values (
    '10000000-0000-4000-8000-000000000055','20000000-0000-4000-8000-000000000055',
    'jet-ski-test-1','00000000-0000-4000-8000-000000000051',
    (pg_catalog.now() at time zone 'Africa/Cairo')::date,'finished',1,1000
  )$$,
  '42501',null,
  'authenticated clients cannot insert or forge race results'
);

reset role;
select * from extensions.finish();
rollback;
