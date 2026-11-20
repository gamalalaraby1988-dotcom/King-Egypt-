-- Server-verified puzzle piece issuance and one-time player claims.
-- This does not define drop odds, rewards, prices, or activity distribution.

create table if not exists private.player_puzzle_piece_proofs (
    proof_id uuid primary key default gen_random_uuid(),
    season_id uuid not null,
    puzzle_id text not null,
    user_id uuid not null references auth.users(id) on delete cascade,
    piece_id text not null,
    source_kind text not null check (source_kind ~ '^[a-z0-9][a-z0-9_.-]{0,79}$'),
    source_id text not null check (source_id ~ '^[a-z0-9][a-z0-9_.-]{0,79}$'),
    server_event_id uuid not null,
    evidence_digest bytea not null check (octet_length(evidence_digest)=32),
    issued_at timestamptz not null,
    expires_at timestamptz not null,
    consumed_at timestamptz,
    created_at timestamptz not null default pg_catalog.now(),
    unique (user_id, server_event_id),
    foreign key (season_id,puzzle_id)
      references private.puzzle_seasons(season_id,puzzle_id) on delete cascade,
    foreign key (puzzle_id,piece_id)
      references private.puzzle_piece_catalog(puzzle_id,piece_id),
    check (expires_at = issued_at + interval '5 minutes')
);
create index if not exists player_puzzle_piece_proofs_user_idx
    on private.player_puzzle_piece_proofs(user_id,issued_at desc);
create index if not exists player_puzzle_piece_proofs_season_piece_idx
    on private.player_puzzle_piece_proofs(season_id,piece_id);
create index if not exists player_puzzle_piece_proofs_season_fk_idx
    on private.player_puzzle_piece_proofs(season_id,puzzle_id);
create index if not exists player_puzzle_piece_proofs_catalog_fk_idx
    on private.player_puzzle_piece_proofs(puzzle_id,piece_id);

create table if not exists private.player_puzzle_piece_claims (
    claim_id uuid primary key default gen_random_uuid(),
    proof_id uuid not null unique
      references private.player_puzzle_piece_proofs(proof_id),
    season_id uuid not null,
    puzzle_id text not null,
    user_id uuid not null references auth.users(id) on delete cascade,
    piece_id text not null,
    server_event_id uuid not null,
    claimed_at timestamptz not null default pg_catalog.now(),
    unique (user_id,server_event_id),
    foreign key (season_id,puzzle_id)
      references private.puzzle_seasons(season_id,puzzle_id),
    foreign key (puzzle_id,piece_id)
      references private.puzzle_piece_catalog(puzzle_id,piece_id)
);
create index if not exists player_puzzle_piece_claims_user_idx
    on private.player_puzzle_piece_claims(user_id,claimed_at desc);
create index if not exists player_puzzle_piece_claims_season_fk_idx
    on private.player_puzzle_piece_claims(season_id,puzzle_id);
create index if not exists player_puzzle_piece_claims_catalog_fk_idx
    on private.player_puzzle_piece_claims(puzzle_id,piece_id);

alter table private.player_puzzle_piece_proofs enable row level security;
alter table private.player_puzzle_piece_proofs force row level security;
alter table private.player_puzzle_piece_claims enable row level security;
alter table private.player_puzzle_piece_claims force row level security;

drop policy if exists puzzle_piece_proofs_read_own on private.player_puzzle_piece_proofs;
create policy puzzle_piece_proofs_read_own on private.player_puzzle_piece_proofs
 for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists puzzle_piece_proofs_service_all on private.player_puzzle_piece_proofs;
create policy puzzle_piece_proofs_service_all on private.player_puzzle_piece_proofs
 for all to service_role using (true) with check (true);

drop policy if exists puzzle_piece_claims_read_own on private.player_puzzle_piece_claims;
create policy puzzle_piece_claims_read_own on private.player_puzzle_piece_claims
 for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists puzzle_piece_claims_service_all on private.player_puzzle_piece_claims;
create policy puzzle_piece_claims_service_all on private.player_puzzle_piece_claims
 for all to service_role using (true) with check (true);

revoke all on table private.player_puzzle_piece_proofs from public,anon,authenticated;
revoke all on table private.player_puzzle_piece_claims from public,anon,authenticated;
grant select on table private.player_puzzle_piece_proofs,private.player_puzzle_piece_claims to authenticated;
grant select,insert,update,delete on table private.player_puzzle_piece_proofs,private.player_puzzle_piece_claims to service_role;

create or replace function public.issue_server_puzzle_piece_proof(
    p_user_id uuid,
    p_season_id uuid,
    p_piece_id text,
    p_source_kind text,
    p_source_id text,
    p_server_event_id uuid,
    p_evidence_digest_hex text,
    p_issued_at timestamptz,
    p_expires_at timestamptz
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_season private.puzzle_seasons%rowtype;
    v_proof_id uuid;
    v_existing private.player_puzzle_piece_proofs%rowtype;
    v_digest bytea;
begin
    if p_user_id is null or p_season_id is null or p_piece_id is null
       or p_source_kind is null or p_source_id is null or p_server_event_id is null
       or p_evidence_digest_hex is null or p_issued_at is null or p_expires_at is null
       or p_source_kind !~ '^[a-z0-9][a-z0-9_.-]{0,79}$'
       or p_source_id !~ '^[a-z0-9][a-z0-9_.-]{0,79}$'
       or p_evidence_digest_hex !~ '^[0-9a-f]{64}$' then
        raise exception 'invalid_puzzle_piece_proof_payload' using errcode='22023';
    end if;

    if p_issued_at > pg_catalog.now() + interval '30 seconds'
       or p_issued_at < pg_catalog.now() - interval '2 minutes'
       or p_expires_at <> p_issued_at + interval '5 minutes' then
        raise exception 'puzzle_piece_proof_timestamp_invalid' using errcode='22023';
    end if;

    select * into v_season from private.puzzle_seasons
    where season_id=p_season_id and status='active'
      and start_at <= pg_catalog.now() and end_at > pg_catalog.now()
    for share;
    if not found then
        raise exception 'puzzle_season_not_active' using errcode='22023';
    end if;

    if not exists (
        select 1 from private.puzzle_piece_catalog c
        where c.puzzle_id=v_season.puzzle_id and c.piece_id=p_piece_id
    ) then
        raise exception 'puzzle_piece_not_in_season_catalog' using errcode='22023';
    end if;

    v_digest := pg_catalog.decode(p_evidence_digest_hex,'hex');
    insert into private.player_puzzle_piece_proofs(
        season_id,puzzle_id,user_id,piece_id,source_kind,source_id,
        server_event_id,evidence_digest,issued_at,expires_at
    ) values (
        p_season_id,v_season.puzzle_id,p_user_id,p_piece_id,p_source_kind,p_source_id,
        p_server_event_id,v_digest,p_issued_at,p_expires_at
    )
    on conflict(user_id,server_event_id) do nothing
    returning proof_id into v_proof_id;

    if v_proof_id is not null then return v_proof_id; end if;

    select * into v_existing from private.player_puzzle_piece_proofs
    where user_id=p_user_id and server_event_id=p_server_event_id;
    if not found or v_existing.season_id<>p_season_id
       or v_existing.piece_id<>p_piece_id
       or v_existing.source_kind<>p_source_kind
       or v_existing.source_id<>p_source_id
       or v_existing.evidence_digest<>v_digest then
        raise exception 'puzzle_piece_server_event_conflict' using errcode='23505';
    end if;
    return v_existing.proof_id;
end;
$function$;

revoke all on function public.issue_server_puzzle_piece_proof(uuid,uuid,text,text,text,uuid,text,timestamptz,timestamptz)
 from public,anon,authenticated;
grant execute on function public.issue_server_puzzle_piece_proof(uuid,uuid,text,text,text,uuid,text,timestamptz,timestamptz)
 to service_role;

create or replace function private.claim_verified_puzzle_piece(p_proof_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_proof private.player_puzzle_piece_proofs%rowtype;
    v_season private.puzzle_seasons%rowtype;
    v_existing private.player_puzzle_piece_claims%rowtype;
    v_quantity integer;
    v_claim_id uuid;
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode='28000';
    end if;
    if p_proof_id is null then
        raise exception 'puzzle_piece_proof_required' using errcode='22023';
    end if;

    select * into v_proof from private.player_puzzle_piece_proofs
    where proof_id=p_proof_id and user_id=v_user_id
    for update;
    if not found then
        raise exception 'verified_puzzle_piece_proof_not_found' using errcode='P0002';
    end if;

    select * into v_existing from private.player_puzzle_piece_claims
    where proof_id=v_proof.proof_id;
    if found then
        select quantity into v_quantity from private.player_puzzle_piece_balances
        where season_id=v_proof.season_id and user_id=v_user_id and piece_id=v_proof.piece_id;
        return pg_catalog.jsonb_build_object(
            'claimed',false,'duplicate',true,'claim_id',v_existing.claim_id,
            'piece_id',v_proof.piece_id,'quantity',coalesce(v_quantity,0)
        );
    end if;
    if v_proof.consumed_at is not null then
        return pg_catalog.jsonb_build_object('claimed',false,'duplicate',true);
    end if;
    if v_proof.expires_at <= pg_catalog.now() then
        raise exception 'verified_puzzle_piece_proof_expired' using errcode='22023';
    end if;

    select * into v_season from private.puzzle_seasons
    where season_id=v_proof.season_id and status='active'
      and start_at <= pg_catalog.now() and end_at > pg_catalog.now()
    for share;
    if not found then
        raise exception 'puzzle_season_not_active' using errcode='22023';
    end if;

    insert into private.player_puzzle_piece_claims(
        proof_id,season_id,puzzle_id,user_id,piece_id,server_event_id
    ) values (
        v_proof.proof_id,v_proof.season_id,v_proof.puzzle_id,v_user_id,
        v_proof.piece_id,v_proof.server_event_id
    ) returning claim_id into v_claim_id;

    insert into private.player_puzzle_piece_balances(
        season_id,puzzle_id,user_id,piece_id,quantity
    ) values (
        v_proof.season_id,v_proof.puzzle_id,v_user_id,v_proof.piece_id,1
    )
    on conflict(season_id,user_id,piece_id) do update
    set quantity=private.player_puzzle_piece_balances.quantity+1,
        updated_at=pg_catalog.now()
    returning quantity into v_quantity;

    update private.player_puzzle_piece_proofs
    set consumed_at=pg_catalog.now()
    where proof_id=v_proof.proof_id;

    return pg_catalog.jsonb_build_object(
        'claimed',true,'duplicate',false,'claim_id',v_claim_id,
        'piece_id',v_proof.piece_id,'quantity',v_quantity
    );
end;
$function$;

revoke all on function private.claim_verified_puzzle_piece(uuid) from public,anon;
grant execute on function private.claim_verified_puzzle_piece(uuid) to authenticated;

create or replace function public.claim_verified_puzzle_piece(p_proof_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $wrapper$
    select private.claim_verified_puzzle_piece(p_proof_id);
$wrapper$;

revoke all on function public.claim_verified_puzzle_piece(uuid) from public,anon;
grant execute on function public.claim_verified_puzzle_piece(uuid) to authenticated;

comment on table private.player_puzzle_piece_proofs is
'Short-lived, service-issued proofs tying a server event to one puzzle piece. Players cannot issue or modify proofs.';
comment on table private.player_puzzle_piece_claims is
'Idempotent claim ledger for server-issued puzzle piece proofs. One claim per proof and server event.';
comment on function public.issue_server_puzzle_piece_proof(uuid,uuid,text,text,text,uuid,text,timestamptz,timestamptz) is
'Service-role-only issuance of a short-lived proof for a piece already in the active season catalog. Does not select a drop probability.';
comment on function public.claim_verified_puzzle_piece(uuid) is
'Authenticated owner claims exactly one server-selected puzzle piece once; no wallet currency, XP, or other reward is granted.';
