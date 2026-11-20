begin;
select extensions.plan(17);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values
('00000000-0000-4000-8000-000000000061','authenticated','authenticated','puzzle-inventory-a@example.invalid','',pg_catalog.now()),
('00000000-0000-4000-8000-000000000062','authenticated','authenticated','puzzle-inventory-b@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;

insert into private.puzzle_seasons (
    season_id,puzzle_id,status,start_at,end_at
) values (
    '60000000-0000-4000-8000-000000000001',
    'puzzle_test_30day','active',
    pg_catalog.now() - interval '1 hour',
    pg_catalog.now() + interval '719 hours'
);

insert into private.puzzle_piece_catalog (puzzle_id,piece_id,piece_index,rarity)
values
('puzzle_test_30day','piece_a',0,'standard'),
('puzzle_test_30day','piece_b',1,'rare');

insert into private.player_puzzle_piece_balances (
    season_id,puzzle_id,user_id,piece_id,quantity
) values
('60000000-0000-4000-8000-000000000001','puzzle_test_30day','00000000-0000-4000-8000-000000000061','piece_a',3),
('60000000-0000-4000-8000-000000000001','puzzle_test_30day','00000000-0000-4000-8000-000000000062','piece_b',4);

select extensions.throws_ok(
    $sql$insert into private.puzzle_seasons (puzzle_id,status,start_at,end_at)
    values ('invalid_duration_test','draft',now(),now()+interval '719 hours')$sql$,
    '23514',null,'season duration must be exactly 720 hours'
);

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000061',true);

select extensions.throws_ok(
    $sql$insert into private.player_puzzle_piece_balances
    (season_id,puzzle_id,user_id,piece_id,quantity)
    values ('60000000-0000-4000-8000-000000000001','puzzle_test_30day',
    '00000000-0000-4000-8000-000000000061','piece_b',1)$sql$,
    '42501',null,'authenticated clients cannot mint inventory rows'
);

select extensions.ok(
    not (select prosecdef from pg_catalog.pg_proc
         where oid='public.exchange_monthly_puzzle_pieces(uuid,uuid,text,integer,text,integer,uuid)'::pg_catalog.regprocedure),
    'public exchange wrapper is SECURITY INVOKER'
);
select extensions.ok(
    (select prosecdef from pg_catalog.pg_proc
     where oid='private.exchange_monthly_puzzle_pieces(uuid,uuid,text,integer,text,integer,uuid)'::pg_catalog.regprocedure),
    'atomic exchange implementation is isolated in the private schema'
);
select extensions.throws_ok(
    $sql$update private.player_puzzle_piece_balances set quantity=999
    where season_id='60000000-0000-4000-8000-000000000001' and piece_id='piece_a'$sql$,
    '42501',null,'authenticated clients cannot directly change inventory'
);
select extensions.is(
    (select pg_catalog.count(*)::integer from private.player_puzzle_piece_balances
     where season_id='60000000-0000-4000-8000-000000000001'),
    1,'a player can read only their own inventory rows'
);

select extensions.is(
    (public.exchange_monthly_puzzle_pieces(
        '60000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000062',
        'piece_a',2,'piece_b',1,
        '70000000-0000-4000-8000-000000000001'
    )->>'success')::boolean,
    true,'a valid two-way piece exchange succeeds'
);
select extensions.is(
    (select quantity from private.player_puzzle_piece_balances
     where season_id='60000000-0000-4000-8000-000000000001'
       and user_id='00000000-0000-4000-8000-000000000061' and piece_id='piece_a'),
    1,'the offered quantity is debited from the sender'
);
select extensions.is(
    (select quantity from private.player_puzzle_piece_balances
     where season_id='60000000-0000-4000-8000-000000000001'
       and user_id='00000000-0000-4000-8000-000000000061' and piece_id='piece_b'),
    1,'the requested quantity is credited to the sender'
);
select extensions.is(
    (public.exchange_monthly_puzzle_pieces(
        '60000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000062',
        'piece_a',2,'piece_b',1,
        '70000000-0000-4000-8000-000000000001'
    )->>'duplicate')::boolean,
    true,'replaying the same request is idempotent'
);
select extensions.is(
    (select quantity from private.player_puzzle_piece_balances
     where season_id='60000000-0000-4000-8000-000000000001'
       and user_id='00000000-0000-4000-8000-000000000061' and piece_id='piece_a'),
    1,'replay does not debit inventory a second time'
);
select extensions.throws_ok(
    $sql$select public.exchange_monthly_puzzle_pieces(
        '60000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000062',
        'piece_a',1,'piece_b',1,
        '70000000-0000-4000-8000-000000000001'
    )$sql$,
    '23505','puzzle_exchange_request_id_conflict',
    'reusing a request id with different terms is rejected'
);
select extensions.throws_ok(
    $sql$select public.exchange_monthly_puzzle_pieces(
        '60000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000062',
        'piece_a',99,'piece_b',1,
        '70000000-0000-4000-8000-000000000002'
    )$sql$,
    '22023','puzzle_piece_balance_insufficient',
    'an exchange cannot spend pieces the sender does not own'
);
select extensions.is(
    (select pg_catalog.count(*)::integer from private.puzzle_piece_exchanges
     where from_user_id='00000000-0000-4000-8000-000000000061'),
    1,'a failed exchange leaves no ledger entry or partial transfer'
);

select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
select extensions.is(
    (select quantity from private.player_puzzle_piece_balances
     where season_id='60000000-0000-4000-8000-000000000001'
       and user_id='00000000-0000-4000-8000-000000000062' and piece_id='piece_a'),
    2,'the recipient receives the offered pieces'
);
select extensions.is(
    (select quantity from private.player_puzzle_piece_balances
     where season_id='60000000-0000-4000-8000-000000000001'
       and user_id='00000000-0000-4000-8000-000000000062' and piece_id='piece_b'),
    3,'the recipient gives the requested pieces atomically'
);
select pg_catalog.set_config('request.jwt.claim.sub','',true);
select extensions.throws_ok(
    $sql$select public.exchange_monthly_puzzle_pieces(
        '60000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000062',
        'piece_a',1,'piece_b',1,
        '70000000-0000-4000-8000-000000000003'
    )$sql$,
    '28000','authentication_required','unauthenticated exchanges are rejected'
);

reset role;
select * from extensions.finish();
rollback;
