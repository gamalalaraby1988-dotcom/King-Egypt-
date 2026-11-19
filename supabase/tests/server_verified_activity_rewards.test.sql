begin;
select extensions.plan(13);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values
('00000000-0000-4000-8000-000000000039','authenticated','authenticated','verified-activity-test@example.invalid','',pg_catalog.now()),
('00000000-0000-4000-8000-000000000040','authenticated','authenticated','verified-activity-other@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;

insert into private.player_activity_reward_catalog (
    activity_kind, activity_id, reward_cash, reward_chips, reward_xp, enabled
) values
('mission','mission.proof_test',100,5,25,true),
('mission','mission.expired_test',50,0,10,true)
on conflict (activity_kind,activity_id) do update
set reward_cash=excluded.reward_cash,
    reward_chips=excluded.reward_chips,
    reward_xp=excluded.reward_xp,
    enabled=excluded.enabled;

insert into private.player_activity_proofs (
    proof_id,user_id,activity_kind,activity_id,server_event_id,evidence_digest,issued_at,expires_at
) values
('30000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000039','mission','mission.proof_test','40000000-0000-4000-8000-000000000001',pg_catalog.decode(pg_catalog.repeat('ab',32),'hex'),pg_catalog.now(),pg_catalog.now()+interval '1 hour'),
('30000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000039','mission','mission.proof_test','40000000-0000-4000-8000-000000000002',pg_catalog.decode(pg_catalog.repeat('cd',32),'hex'),pg_catalog.now(),pg_catalog.now()+interval '1 hour'),
('30000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000039','mission','mission.expired_test','40000000-0000-4000-8000-000000000003',pg_catalog.decode(pg_catalog.repeat('ef',32),'hex'),pg_catalog.now()-interval '2 days',pg_catalog.now()-interval '1 day')
on conflict (proof_id) do nothing;

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000039',true);

select extensions.throws_ok($sql$select * from private.player_activity_reward_catalog$sql$,'42501',null,'clients cannot read or alter the server reward catalog');
select extensions.ok(
    not (select prosecdef from pg_catalog.pg_proc where oid='public.claim_verified_activity_reward(uuid)'::pg_catalog.regprocedure),
    'public reward RPC is SECURITY INVOKER'
);
select extensions.ok(
    (select prosecdef from pg_catalog.pg_proc where oid='private.claim_verified_activity_reward(uuid)'::pg_catalog.regprocedure),
    'privileged settlement remains inside the non-exposed private schema'
);
select extensions.throws_ok($sql$insert into private.player_activity_proofs (user_id,activity_kind,activity_id,server_event_id,evidence_digest,expires_at) values ('00000000-0000-4000-8000-000000000039','mission','mission.proof_test','40000000-0000-4000-8000-000000000099',decode(repeat('11',32),'hex'),now()+interval '1 hour')$sql$,'42501',null,'clients cannot mint their own validation proofs');
select extensions.throws_ok($sql$update private.player_activity_reward_catalog set reward_cash=999999 where activity_id='mission.proof_test'$sql$,'42501',null,'clients cannot change reward amounts');

select extensions.is((public.claim_verified_activity_reward('30000000-0000-4000-8000-000000000001')->>'claimed')::boolean,true,'redeems a valid server proof');
select extensions.is((select cash from public.player_wallets where user_id='00000000-0000-4000-8000-000000000039'),100::bigint,'credits only the catalog cash reward');
select extensions.is((public.claim_verified_activity_reward('30000000-0000-4000-8000-000000000001')->>'duplicate')::boolean,true,'replaying the same proof is idempotent');
select extensions.is((select cash from public.player_wallets where user_id='00000000-0000-4000-8000-000000000039'),100::bigint,'replay does not credit cash twice');
select extensions.is((public.claim_verified_activity_reward('30000000-0000-4000-8000-000000000002')->>'duplicate')::boolean,true,'a second proof for the same one-time activity cannot pay twice');

select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000040',true);
select extensions.throws_ok($sql$select public.claim_verified_activity_reward('30000000-0000-4000-8000-000000000001')$sql$,'P0002','verified_proof_not_found','another player cannot redeem this proof');

select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000039',true);
select extensions.throws_ok($sql$select public.claim_verified_activity_reward('30000000-0000-4000-8000-000000000003')$sql$,'22023','verified_proof_expired','expired server proofs are rejected');

select pg_catalog.set_config('request.jwt.claim.sub','',true);
select extensions.throws_ok($sql$select public.claim_verified_activity_reward('30000000-0000-4000-8000-000000000001')$sql$,'28000','authentication_required','unauthenticated reward claims are rejected');

reset role;
select * from extensions.finish();
rollback;
