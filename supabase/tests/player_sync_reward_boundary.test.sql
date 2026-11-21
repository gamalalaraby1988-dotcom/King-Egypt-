begin;
select extensions.plan(10);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values ('00000000-0000-4000-8000-000000000041','authenticated','authenticated','player-sync-reward-boundary@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000041',true);

select extensions.is(
  (select cash + chips + gems + xp from public.player_wallets where user_id=auth.uid()),
  0::bigint,
  'new test player starts with no currency or XP'
);

select extensions.is(
  public.submit_player_sync_events(
    '[{"event_id":"50000000-0000-4000-8000-000000000001","event_type":"mission_progress_observed","payload":{"progress_key":"mission.test","progress_value":1000000}}]'::jsonb
  )->>'authoritative',
  'false',
  'client mission progress remains an untrusted observation'
);

select extensions.is(
  (select cash + chips + gems + xp from public.player_wallets where user_id=auth.uid()),
  0::bigint,
  'submitting maximum progress observation grants no currency or XP'
);

select extensions.throws_ok(
  $$update public.player_wallets set cash=999999, chips=999999, gems=999999, xp=999999 where user_id=auth.uid()$$,
  '42501', null,
  'authenticated client cannot write wallet balances'
);

select extensions.throws_ok(
  $$insert into private.player_activity_proofs (user_id,activity_kind,activity_id,server_event_id,evidence_digest,expires_at)
    values (auth.uid(),'mission','mission.test','50000000-0000-4000-8000-000000000002',pg_catalog.decode(pg_catalog.repeat('11',32),'hex'),pg_catalog.now()+interval '1 hour')$$,
  '42501', null,
  'authenticated client cannot mint a server activity proof'
);

select extensions.throws_ok(
  $$update private.player_activity_reward_catalog set reward_cash=999999, reward_chips=999999, reward_xp=999999 where activity_id='mission.test'$$,
  '42501', null,
  'authenticated client cannot change server reward amounts'
);

select extensions.throws_ok(
  $$insert into private.player_reward_claims (user_id,activity_kind,activity_id,proof_id,reward_cash,reward_chips,reward_xp)
    values (auth.uid(),'mission','mission.test','50000000-0000-4000-8000-000000000003',999999,999999,999999)$$,
  '42501', null,
  'authenticated client cannot create a reward claim ledger entry'
);

select extensions.throws_ok(
  $$select public.issue_server_activity_proof(
    auth.uid(),'mission','mission.test','50000000-0000-4000-8000-000000000004',
    pg_catalog.repeat('ab',32),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
  )$$,
  '42501', null,
  'authenticated client cannot call the server-only proof issuer RPC'
);

select extensions.throws_ok(
  $$select public.submit_player_sync_events(
    '[{"event_id":"50000000-0000-4000-8000-000000000005","event_type":"mission_completed","payload":{"mission_id":"mission.test","reward_cash":999999}}]'::jsonb
  )$$,
  '22023','event_type_not_allowed',
  'sync inbox rejects client-asserted authoritative mission completion and reward fields'
);

select extensions.throws_ok(
  $$select public.claim_verified_activity_reward('50000000-0000-4000-8000-000000000006')$$,
  'P0002','verified_proof_not_found',
  'a client cannot claim a reward without a matching server-issued proof'
);

select * from extensions.finish();
rollback;
