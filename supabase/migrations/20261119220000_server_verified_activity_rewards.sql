-- Server-validated activity reward claims.
-- Clients can read their own proofs and redeem them, but cannot create proofs,
-- change the catalog, choose reward amounts, or write wallet balances.
create schema if not exists private;

create table if not exists private.player_activity_reward_catalog (
    activity_kind text not null check (activity_kind in ('mission', 'job', 'achievement', 'daily_claim')),
    activity_id text not null check (activity_id ~ '^[a-z0-9][a-z0-9_.-]{0,79}$'),
    reward_cash bigint not null default 0 check (reward_cash between 0 and 2000000000),
    reward_chips bigint not null default 0 check (reward_chips between 0 and 2000000000),
    reward_xp bigint not null default 0 check (reward_xp between 0 and 2000000000),
    enabled boolean not null default false,
    created_at timestamptz not null default pg_catalog.now(),
    primary key (activity_kind, activity_id)
);

create table if not exists private.player_activity_proofs (
    proof_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    activity_kind text not null,
    activity_id text not null,
    server_event_id uuid not null,
    evidence_digest bytea not null check (pg_catalog.octet_length(evidence_digest) = 32),
    issued_at timestamptz not null default pg_catalog.now(),
    expires_at timestamptz not null,
    consumed_at timestamptz,
    foreign key (activity_kind, activity_id)
        references private.player_activity_reward_catalog(activity_kind, activity_id),
    unique (user_id, server_event_id),
    check (expires_at > issued_at)
);

create index if not exists player_activity_proofs_user_expiry_idx
    on private.player_activity_proofs(user_id, expires_at desc);

create table if not exists private.player_reward_claims (
    claim_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    activity_kind text not null,
    activity_id text not null,
    proof_id uuid not null unique references private.player_activity_proofs(proof_id),
    reward_cash bigint not null check (reward_cash between 0 and 2000000000),
    reward_chips bigint not null check (reward_chips between 0 and 2000000000),
    reward_xp bigint not null check (reward_xp between 0 and 2000000000),
    claimed_at timestamptz not null default pg_catalog.now(),
    unique (user_id, activity_kind, activity_id)
);

alter table private.player_activity_reward_catalog enable row level security;
alter table private.player_activity_reward_catalog force row level security;
alter table private.player_activity_proofs enable row level security;
alter table private.player_activity_proofs force row level security;
alter table private.player_reward_claims enable row level security;
alter table private.player_reward_claims force row level security;

revoke all on table private.player_activity_reward_catalog from public, anon, authenticated;
revoke all on table private.player_activity_proofs from public, anon, authenticated;
revoke all on table private.player_reward_claims from public, anon, authenticated;

grant usage on schema private to authenticated, service_role;
grant select on table private.player_activity_proofs, private.player_reward_claims to authenticated;
grant select, insert, update, delete on table private.player_activity_reward_catalog to service_role;
grant select, insert, update, delete on table private.player_activity_proofs to service_role;
grant select, insert, update, delete on table private.player_reward_claims to service_role;

drop policy if exists player_activity_proofs_select_own on private.player_activity_proofs;
create policy player_activity_proofs_select_own
    on private.player_activity_proofs for select to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists player_reward_claims_select_own on private.player_reward_claims;
create policy player_reward_claims_select_own
    on private.player_reward_claims for select to authenticated
    using ((select auth.uid()) = user_id);

create or replace function public.claim_verified_activity_reward(p_proof_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_proof private.player_activity_proofs%rowtype;
    v_catalog private.player_activity_reward_catalog%rowtype;
    v_claim private.player_reward_claims%rowtype;
    v_wallet public.player_wallets%rowtype;
    v_cash bigint;
    v_chips bigint;
    v_xp bigint;
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode = '28000';
    end if;
    if p_proof_id is null then
        raise exception 'proof_required' using errcode = '22023';
    end if;

    select * into v_proof
    from private.player_activity_proofs
    where proof_id = p_proof_id and user_id = v_user_id
    for update;

    if not found then
        raise exception 'verified_proof_not_found' using errcode = 'P0002';
    end if;

    select * into v_claim
    from private.player_reward_claims
    where proof_id = v_proof.proof_id;

    if found then
        return pg_catalog.jsonb_build_object(
            'claimed', false,
            'duplicate', true,
            'claim_id', v_claim.claim_id
        );
    end if;

    if v_proof.consumed_at is not null then
        return pg_catalog.jsonb_build_object('claimed', false, 'duplicate', true);
    end if;
    if v_proof.expires_at <= pg_catalog.now() then
        raise exception 'verified_proof_expired' using errcode = '22023';
    end if;

    select * into v_catalog
    from private.player_activity_reward_catalog
    where activity_kind = v_proof.activity_kind
      and activity_id = v_proof.activity_id
      and enabled = true;

    if not found then
        raise exception 'activity_reward_not_enabled' using errcode = '22023';
    end if;

    perform 1
    from private.player_reward_claims
    where user_id = v_user_id
      and activity_kind = v_proof.activity_kind
      and activity_id = v_proof.activity_id;

    if found then
        update private.player_activity_proofs
        set consumed_at = pg_catalog.now()
        where proof_id = v_proof.proof_id;
        return pg_catalog.jsonb_build_object('claimed', false, 'duplicate', true);
    end if;

    select * into v_wallet
    from public.player_wallets
    where user_id = v_user_id
    for update;

    if not found then
        raise exception 'player_wallet_not_found' using errcode = 'P0002';
    end if;

    v_cash := v_wallet.cash + v_catalog.reward_cash;
    v_chips := v_wallet.chips + v_catalog.reward_chips;
    v_xp := v_wallet.xp + v_catalog.reward_xp;

    if v_cash > 2000000000 or v_chips > 2000000000 or v_xp > 2000000000 then
        raise exception 'player_wallet_limit_exceeded' using errcode = '22003';
    end if;

    update public.player_wallets
    set cash = v_cash,
        chips = v_chips,
        xp = v_xp
    where user_id = v_user_id;

    insert into private.player_reward_claims (
        user_id, activity_kind, activity_id, proof_id,
        reward_cash, reward_chips, reward_xp
    ) values (
        v_user_id, v_proof.activity_kind, v_proof.activity_id, v_proof.proof_id,
        v_catalog.reward_cash, v_catalog.reward_chips, v_catalog.reward_xp
    )
    returning * into v_claim;

    update private.player_activity_proofs
    set consumed_at = pg_catalog.now()
    where proof_id = v_proof.proof_id;

    return pg_catalog.jsonb_build_object(
        'claimed', true,
        'duplicate', false,
        'claim_id', v_claim.claim_id,
        'activity_kind', v_claim.activity_kind,
        'activity_id', v_claim.activity_id,
        'cash', v_cash,
        'chips', v_chips,
        'xp', v_xp
    );
end;
$function$;

revoke all on function public.claim_verified_activity_reward(uuid) from public, anon;
grant execute on function public.claim_verified_activity_reward(uuid) to authenticated;

comment on table private.player_activity_reward_catalog is
'Server-managed allowlist of activity identifiers and reward amounts. No client write access.';
comment on table private.player_activity_proofs is
'Proofs inserted only by trusted game-server infrastructure after validating gameplay. Client observations and Offline progress are not proofs.';
comment on table private.player_reward_claims is
'Immutable idempotency ledger for rewards atomically credited from a valid server-issued proof.';
comment on function public.claim_verified_activity_reward(uuid) is
'Atomically redeems a server-issued proof once. Reward amounts come only from the private catalog; the client cannot choose amounts or create proofs. SECURITY DEFINER is narrowly required to update wallet and private ledger atomically, and explicitly binds the proof to auth.uid().';
