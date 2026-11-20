begin;
select extensions.plan(10);

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at)
values
('00000000-0000-4000-8000-000000000081','authenticated','authenticated','puzzle-proof-a@example.invalid','',pg_catalog.now()),
('00000000-0000-4000-8000-000000000082','authenticated','authenticated','puzzle-proof-b@example.invalid','',pg_catalog.now())
on conflict (id) do nothing;

insert into private.puzzle_seasons(season_id,puzzle_id,status,start_at,end_at)
values ('60000000-0000-4000-8000-000000000081','puzzle_proof_test','active',
        pg_catalog.now()-interval '1 hour',pg_catalog.now()+interval '719 hours');
insert into private.puzzle_piece_catalog(puzzle_id,piece_id,piece_index,rarity)
values ('puzzle_proof_test','proof_piece_a',0,'standard'),
       ('puzzle_proof_test','proof_piece_b',1,'gold');

create temporary table issued_puzzle_proofs(label text primary key,proof_id uuid not null);
grant select,insert on issued_puzzle_proofs to authenticated,service_role;

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000081',true);
select extensions.throws_ok(
    $sql$select public.issue_server_puzzle_piece_proof(
      '00000000-0000-4000-8000-000000000081',
      '60000000-0000-4000-8000-000000000081',
      'proof_piece_a','mission','mission_01',
      '70000000-0000-4000-8000-000000000081',
      repeat('a',64),now(),now()+interval '5 minutes'
    )$sql$,
    '42501',null,'players cannot issue puzzle piece proofs'
);
reset role;

set local role service_role;
insert into issued_puzzle_proofs
select 'first',public.issue_server_puzzle_piece_proof(
    '00000000-0000-4000-8000-000000000081',
    '60000000-0000-4000-8000-000000000081',
    'proof_piece_a','mission','mission_01',
    '70000000-0000-4000-8000-000000000081',
    repeat('a',64),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
);
insert into issued_puzzle_proofs
select 'replay',public.issue_server_puzzle_piece_proof(
    '00000000-0000-4000-8000-000000000081',
    '60000000-0000-4000-8000-000000000081',
    'proof_piece_a','mission','mission_01',
    '70000000-0000-4000-8000-000000000081',
    repeat('a',64),pg_catalog.now(),pg_catalog.now()+interval '5 minutes'
);
select extensions.is(
    (select proof_id from issued_puzzle_proofs where label='first'),
    (select proof_id from issued_puzzle_proofs where label='replay'),
    'replaying a server event returns the same proof'
);
select extensions.throws_ok(
    $sql$select public.issue_server_puzzle_piece_proof(
      '00000000-0000-4000-8000-000000000081',
      '60000000-0000-4000-8000-000000000081',
      'proof_piece_b','mission','mission_02',
      '70000000-0000-4000-8000-000000000081',
      repeat('b',64),now(),now()+interval '5 minutes'
    )$sql$,
    '23505','puzzle_piece_server_event_conflict',
    'a server event cannot be reused for a different piece'
);
reset role;

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000081',true);
select extensions.is(
    (public.claim_verified_puzzle_piece((select proof_id from issued_puzzle_proofs where label='first'))->>'claimed')::boolean,
    true,'the proof owner can claim the server-selected piece'
);
select extensions.is(
    (select quantity from private.player_puzzle_piece_balances
     where season_id='60000000-0000-4000-8000-000000000081'
       and user_id='00000000-0000-4000-8000-000000000081'
       and piece_id='proof_piece_a'),
    1,'a successful claim adds exactly one piece'
);
select extensions.is(
    (public.claim_verified_puzzle_piece((select proof_id from issued_puzzle_proofs where label='first'))->>'duplicate')::boolean,
    true,'replaying a claim returns duplicate without granting again'
);
select extensions.is(
    (select quantity from private.player_puzzle_piece_balances
     where season_id='60000000-0000-4000-8000-000000000081'
       and user_id='00000000-0000-4000-8000-000000000081'
       and piece_id='proof_piece_a'),
    1,'claim replay does not increase inventory'
);
select extensions.is(
    (select pg_catalog.count(*)::integer from private.player_puzzle_piece_proofs),
    1,'a player can read only their own proof rows'
);
reset role;

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000082',true);
select extensions.throws_ok(
    $sql$select public.claim_verified_puzzle_piece(
      (select proof_id from issued_puzzle_proofs where label='first')
    )$sql$,
    'P0002','verified_puzzle_piece_proof_not_found',
    'another player cannot claim someone else proof'
);
reset role;

select * from extensions.finish();
rollback;
