begin;
select extensions.plan(20);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values ('00000000-0000-4000-8000-000000000085','authenticated','authenticated','slot-settlement-test@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;

insert into public.player_wallets (user_id,cash,gems,chips,xp)
values ('00000000-0000-4000-8000-000000000085',0,0,100,0)
on conflict (user_id) do update set chips=100;

select extensions.is(
    (select pg_catalog.count(*)::integer from private.arcade_slot_machine_rules),
    3,
    'three approved VIP machine rule rows exist'
);
select extensions.ok(
    (select pg_catalog.bool_and(not enabled) from private.arcade_slot_machine_rules),
    'all slot machines remain disabled until server integration is verified'
);
select extensions.is(private.calculate_slot_payout_tenths('vip_royal_classic',array[0,0,0]),50,'first triple pays 5.0x');
select extensions.is(private.calculate_slot_payout_tenths('vip_diamond_royale',array[4,4,4]),5000,'fifth triple pays 500.0x');
select extensions.is(private.calculate_slot_payout_tenths('vip_golden_crown',array[2,2,1]),1,'exactly two matching symbols pay 0.1x');
select extensions.is(private.calculate_slot_payout_tenths('vip_royal_classic',array[0,1,2]),0,'no matching symbols pay zero');
select extensions.is(private.calculate_slot_payout_tenths('vip_royal_classic',array[0,0]),0,'malformed results are rejected');

select extensions.ok(
    not pg_catalog.has_function_privilege('anon','public.settle_arcade_slot_round(uuid,uuid,uuid,text,bigint,integer[])','EXECUTE'),
    'anon cannot execute slot settlement'
);
select extensions.ok(
    not pg_catalog.has_function_privilege('authenticated','public.settle_arcade_slot_round(uuid,uuid,uuid,text,bigint,integer[])','EXECUTE'),
    'authenticated clients cannot execute slot settlement'
);
select extensions.ok(
    pg_catalog.has_function_privilege('service_role','public.settle_arcade_slot_round(uuid,uuid,uuid,text,bigint,integer[])','EXECUTE'),
    'only the backend service role can execute the settlement wrapper'
);
select extensions.ok(
    not pg_catalog.has_table_privilege('service_role','private.arcade_slot_round_ledger','SELECT'),
    'backend role cannot bypass the settlement function to read the ledger directly'
);

update private.arcade_slot_machine_rules set enabled=true;
set local role service_role;
select extensions.is(
    (public.settle_arcade_slot_round(
        '00000000-0000-4000-8000-000000000085',
        '10000000-0000-4000-8000-000000000085',
        '20000000-0000-4000-8000-000000000085',
        'vip_royal_classic',
        10,
        array[0,0,0]
    )->>'duplicate')::boolean,
    false,
    'first valid server settlement is recorded once'
);
reset role;

select extensions.is(
    (select chips from public.player_wallets where user_id='00000000-0000-4000-8000-000000000085'),
    140::bigint,
    'stake debit and gross payout credit happen atomically'
);

set local role service_role;
select extensions.is(
    (public.settle_arcade_slot_round(
        '00000000-0000-4000-8000-000000000085',
        '10000000-0000-4000-8000-000000000085',
        '20000000-0000-4000-8000-000000000085',
        'vip_royal_classic',
        10,
        array[0,0,0]
    )->>'duplicate')::boolean,
    true,
    'replaying the same signed event is idempotent'
);
select extensions.throws_ok(
    $sql$select public.settle_arcade_slot_round(
        '00000000-0000-4000-8000-000000000085',
        '10000000-0000-4000-8000-000000000085',
        '20000000-0000-4000-8000-000000000085',
        'vip_royal_classic',
        10,
        array[1,1,1]
    )$sql$,
    '23505',
    'slot_round_event_conflict',
    'a reused event id with altered result data is rejected'
);
select extensions.throws_ok(
    $sql$select public.settle_arcade_slot_round(
        '00000000-0000-4000-8000-000000000085',
        '10000000-0000-4000-8000-000000000085',
        '20000000-0000-4000-8000-000000000086',
        'vip_royal_classic',
        200,
        array[0,1,2]
    )$sql$,
    '22003',
    'insufficient_game_chips',
    'a wager above the available chip balance is rejected'
);
select extensions.is(
    (public.settle_arcade_slot_round(
        '00000000-0000-4000-8000-000000000085',
        '10000000-0000-4000-8000-000000000085',
        '20000000-0000-4000-8000-000000000087',
        'vip_diamond_royale',
        19,
        array[0,0,1]
    )->>'payout_multiplier_tenths')::integer,
    1,
    'pair result returns the approved 0.1x multiplier'
);
select extensions.is(
    (public.settle_arcade_slot_round(
        '00000000-0000-4000-8000-000000000085',
        '10000000-0000-4000-8000-000000000085',
        '20000000-0000-4000-8000-000000000088',
        'vip_diamond_royale',
        19,
        array[0,0,1]
    )->>'gross_return_chips')::bigint,
    1::bigint,
    'a 1.9-chip pair return is rounded down to one whole chip'
);
select extensions.is(
    (public.settle_arcade_slot_round(
        '00000000-0000-4000-8000-000000000085',
        '10000000-0000-4000-8000-000000000085',
        '20000000-0000-4000-8000-000000000088',
        'vip_golden_crown',
        10,
        array[0,1,2]
    )->>'payout_multiplier_tenths')::integer,
    0,
    'no-match result returns zero'
);
reset role;

select extensions.is(
    (select chips from public.player_wallets where user_id='00000000-0000-4000-8000-000000000085'),
    112::bigint,
    'pair and no-match settlements update the balance using whole-chip floor rounding'
);

reset role;
select * from extensions.finish();
rollback;
