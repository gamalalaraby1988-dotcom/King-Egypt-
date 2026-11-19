begin;
select extensions.plan(5);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values ('00000000-0000-4000-8000-000000000051','authenticated','authenticated','game-proof-issuer-test@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;

insert into private.player_activity_reward_catalog (
    activity_kind, activity_id, reward_cash, reward_chips, reward_xp, enabled
) values
('mission','mission.server_issuer_test',25,1,5,true),
('mission','mission.disabled_issuer_test',25,0,5,false)
on conflict (activity_kind,activity_id) do update
set reward_cash=excluded.reward_cash,
    reward_chips=excluded.reward_chips,
    reward_xp=excluded.reward_xp,
    enabled=excluded.enabled;

select extensions.ok(
    not pg_catalog.has_function_privilege(
        'authenticated',
        'public.issue_server_activity_proof(uuid,text,text,uuid,text,timestamp with time zone,timestamp with time zone)',
        'EXECUTE'
    ),
    'authenticated players cannot call the proof insertion RPC'
);
select extensions.ok(
    pg_catalog.has_function_privilege(
        'service_role',
        'public.issue_server_activity_proof(uuid,text,text,uuid,text,timestamp with time zone,timestamp with time zone)',
        'EXECUTE'
    ),
    'only the trusted backend role can call the proof insertion RPC'
);

set local role service_role;
create temporary table issued_game_proof on commit drop as
select public.issue_server_activity_proof(
    '00000000-0000-4000-8000-000000000051',
    'mission',
    'mission.server_issuer_test',
    '50000000-0000-4000-8000-000000000051',
    pg_catalog.repeat('ab',32),
    pg_catalog.now(),
    pg_catalog.now() + interval '5 minutes'
) as proof_id;

select extensions.ok((select proof_id is not null from issued_game_proof), 'trusted backend can issue a proof for an enabled catalog activity');
select extensions.is(
    public.issue_server_activity_proof(
        '00000000-0000-4000-8000-000000000051',
        'mission',
        'mission.server_issuer_test',
        '50000000-0000-4000-8000-000000000051',
        pg_catalog.repeat('ab',32),
        pg_catalog.now(),
        pg_catalog.now() + interval '5 minutes'
    ),
    (select proof_id from issued_game_proof),
    'replaying the same server event returns the same proof id'
);
select extensions.throws_ok(
    $$select public.issue_server_activity_proof(
        '00000000-0000-4000-8000-000000000051',
        'mission',
        'mission.disabled_issuer_test',
        '50000000-0000-4000-8000-000000000052',
        repeat('cd',32),
        now(),
        now() + interval '5 minutes'
    )$$,
    '22023',
    'activity_reward_not_enabled',
    'the backend cannot issue proofs while the reward catalog entry is disabled'
);

reset role;
select * from extensions.finish();
rollback;
