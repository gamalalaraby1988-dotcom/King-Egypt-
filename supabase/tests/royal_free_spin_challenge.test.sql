begin;
select extensions.plan(17);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values ('00000000-0000-4000-8000-000000000087','authenticated','authenticated','royal-free-spin-test@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;
insert into public.player_wallets (user_id,cash,gems,chips,xp)
values ('00000000-0000-4000-8000-000000000087',0,0,100,0)
on conflict (user_id) do update set chips=100;
update private.arcade_slot_machine_rules set enabled=true;

select extensions.is(
    (select pg_catalog.count(*)::integer from private.arcade_slot_challenge_rules),
    3,
    'each approved machine has independent challenge symbol rules'
);

set local role service_role;
select extensions.is(
    (public.settle_arcade_slot_spin(
        '00000000-0000-4000-8000-000000000087',
        '10000000-0000-4000-8000-000000000087',
        '20000000-0000-4000-8000-000000000087',
        'vip_royal_classic','paid',10,
        array[0,0,0],
        array[0,1,2,3,4,0,1,2,3]
    )->>'duplicate')::boolean,
    false,
    'a paid spin is settled once by the trusted role'
);
select extensions.is(
    (select collection_match_count from private.arcade_slot_round_ledger
     where server_event_id='20000000-0000-4000-8000-000000000087'),
    2::smallint,
    'paid spin counts its machine collectible symbols in the 3x3 result'
);
select extensions.is(
    (select challenge_progress from private.arcade_slot_challenge_state
     where user_id='00000000-0000-4000-8000-000000000087' and machine_id='vip_royal_classic'),
    2::smallint,
    'paid spins advance the per-machine challenge'
);
select extensions.is(
    (select chips from public.player_wallets where user_id='00000000-0000-4000-8000-000000000087'),
    140::bigint,
    'paid spin debits stake and credits the approved gross return atomically'
);

select extensions.throws_ok(
    $sql$select public.settle_arcade_slot_spin(
        '00000000-0000-4000-8000-000000000087',
        '10000000-0000-4000-8000-000000000087',
        '20000000-0000-4000-8000-000000000088',
        'vip_royal_classic','free',10,
        array[1,1,1],array[0,0,0,0,0,0,0,0,0]
    )$sql$,
    '22003','free_spin_balance_insufficient',
    'a free spin cannot run without a server-owned free-spin balance'
);

update private.arcade_slot_challenge_state
set challenge_progress=14, free_spins=1
where user_id='00000000-0000-4000-8000-000000000087'
  and machine_id='vip_royal_classic';

select extensions.is(
    (public.settle_arcade_slot_spin(
        '00000000-0000-4000-8000-000000000087',
        '10000000-0000-4000-8000-000000000087',
        '20000000-0000-4000-8000-000000000089',
        'vip_royal_classic','free',10,
        array[1,1,1],array[0,0,0,0,0,0,0,0,0]
    )->>'free_spins_awarded')::integer,
    5,
    'a free spin can complete the challenge and award five more free spins'
);
select extensions.is(
    (select challenge_progress from private.arcade_slot_challenge_state
     where user_id='00000000-0000-4000-8000-000000000087' and machine_id='vip_royal_classic'),
    8::smallint,
    'challenge overflow is carried into the next cycle without losing appearances'
);
select extensions.is(
    (select free_spins from private.arcade_slot_challenge_state
     where user_id='00000000-0000-4000-8000-000000000087' and machine_id='vip_royal_classic'),
    5::bigint,
    'one free spin is consumed and five are awarded in the same transaction'
);
select extensions.is(
    (select collection_activity_multiplier from private.arcade_slot_round_ledger
     where server_event_id='20000000-0000-4000-8000-000000000089'),
    100::smallint,
    'nine matching collection symbols record the approved activity multiplier'
);
select extensions.is(
    (select chips from public.player_wallets where user_id='00000000-0000-4000-8000-000000000087'),
    240::bigint,
    'free spin uses a 10-chip reference wager without debiting the wallet'
);

select extensions.is(
    (public.settle_arcade_slot_spin(
        '00000000-0000-4000-8000-000000000087',
        '10000000-0000-4000-8000-000000000087',
        '20000000-0000-4000-8000-000000000089',
        'vip_royal_classic','free',10,
        array[1,1,1],array[0,0,0,0,0,0,0,0,0]
    )->>'duplicate')::boolean,
    true,
    'replaying the same free-spin event does not grant or consume twice'
);
select extensions.is(
    (select chips from public.player_wallets where user_id='00000000-0000-4000-8000-000000000087'),
    240::bigint,
    'replaying a free-spin event does not change the wallet again'
);

reset role;
select extensions.ok(
    not pg_catalog.has_function_privilege('anon','public.settle_arcade_slot_spin(uuid,uuid,uuid,text,text,bigint,integer[],integer[])','EXECUTE'),
    'anon cannot execute spin settlement'
);
select extensions.ok(
    not pg_catalog.has_function_privilege('authenticated','public.settle_arcade_slot_spin(uuid,uuid,uuid,text,text,bigint,integer[],integer[])','EXECUTE'),
    'authenticated clients cannot execute spin settlement'
);
select extensions.ok(
    pg_catalog.has_function_privilege('service_role','public.settle_arcade_slot_spin(uuid,uuid,uuid,text,text,bigint,integer[],integer[])','EXECUTE'),
    'only service_role can execute spin settlement'
);

select * from extensions.finish();
rollback;
