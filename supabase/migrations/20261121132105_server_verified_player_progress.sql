-- Persist activity completions proven by the dedicated game server.
-- This ledger is separate from client observations and from reward settlement.
create schema if not exists private;

create table if not exists private.player_verified_activity_progress (
    user_id uuid not null references auth.users(id) on delete cascade,
    activity_kind text not null check (activity_kind in ('mission', 'job', 'achievement', 'daily_claim')),
    activity_id text not null check (activity_id ~ '^[a-z0-9][a-z0-9_.-]{0,79}$'),
    server_event_id uuid not null,
    evidence_digest bytea not null check (pg_catalog.octet_length(evidence_digest) = 32),
    reward_eligible_at_completion boolean not null default false,
    verified_at timestamptz not null,
    primary key (user_id, server_event_id)
);

create index if not exists player_verified_activity_progress_lookup_idx
    on private.player_verified_activity_progress (user_id, activity_kind, activity_id, verified_at desc);

alter table private.player_verified_activity_progress enable row level security;
alter table private.player_verified_activity_progress force row level security;

revoke all on table private.player_verified_activity_progress from public, anon, authenticated;
grant select on table private.player_verified_activity_progress to authenticated;
grant select, insert, update, delete on table private.player_verified_activity_progress to service_role;

drop policy if exists player_verified_activity_progress_service_role_all on private.player_verified_activity_progress;
create policy player_verified_activity_progress_service_role_all
    on private.player_verified_activity_progress for all to service_role
    using (true) with check (true);

drop policy if exists player_verified_activity_progress_select_own on private.player_verified_activity_progress;
create policy player_verified_activity_progress_select_own
    on private.player_verified_activity_progress for select to authenticated
    using ((select auth.uid()) = user_id);

create or replace function public.record_server_verified_activity_progress(
    p_user_id uuid,
    p_activity_kind text,
    p_activity_id text,
    p_server_event_id uuid,
    p_evidence_digest_hex text,
    p_issued_at timestamptz,
    p_expires_at timestamptz
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_digest bytea;
    v_progress private.player_verified_activity_progress%rowtype;
    v_proof_id uuid;
    v_inserted boolean := false;
begin
    if p_user_id is null or p_server_event_id is null
       or p_activity_kind is null or p_activity_id is null or p_evidence_digest_hex is null
       or p_activity_kind not in ('mission', 'job', 'achievement', 'daily_claim')
       or p_activity_id !~ '^[a-z0-9][a-z0-9_.-]{0,79}$'
       or p_evidence_digest_hex !~ '^[0-9a-f]{64}$'
       or p_issued_at is null or p_expires_at is null then
        raise exception 'invalid_server_progress_payload' using errcode = '22023';
    end if;

    if p_issued_at > pg_catalog.now() + interval '30 seconds'
       or p_issued_at < pg_catalog.now() - interval '2 minutes'
       or p_expires_at <> p_issued_at + interval '5 minutes' then
        raise exception 'server_progress_timestamp_invalid' using errcode = '22023';
    end if;

    v_digest := pg_catalog.decode(p_evidence_digest_hex, 'hex');

    insert into private.player_verified_activity_progress (
        user_id, activity_kind, activity_id, server_event_id,
        evidence_digest, reward_eligible_at_completion, verified_at
    )
    values (
        p_user_id, p_activity_kind, p_activity_id, p_server_event_id,
        v_digest,
        exists (
            select 1 from private.player_activity_reward_catalog c
            where c.activity_kind = p_activity_kind
              and c.activity_id = p_activity_id
              and c.enabled = true
        ),
        p_issued_at
    )
    on conflict (user_id, server_event_id) do nothing
    returning * into v_progress;

    if found then
        v_inserted := true;
    else
        select * into v_progress
        from private.player_verified_activity_progress
        where user_id = p_user_id and server_event_id = p_server_event_id
        for update;

        if not found
           or v_progress.activity_kind <> p_activity_kind
           or v_progress.activity_id <> p_activity_id
           or v_progress.evidence_digest <> v_digest
           or v_progress.verified_at <> p_issued_at then
            raise exception 'server_progress_event_conflict' using errcode = '23505';
        end if;
    end if;

    if v_progress.reward_eligible_at_completion then
        select proof_id into v_proof_id
        from private.player_activity_proofs
        where user_id = p_user_id and server_event_id = p_server_event_id;

        if v_proof_id is null then
            insert into private.player_activity_proofs (
                user_id, activity_kind, activity_id, server_event_id,
                evidence_digest, issued_at, expires_at
            )
            values (
                p_user_id, p_activity_kind, p_activity_id, p_server_event_id,
                v_digest, p_issued_at, p_expires_at
            )
            on conflict (user_id, server_event_id) do nothing
            returning proof_id into v_proof_id;

            if v_proof_id is null then
                select proof_id into v_proof_id
                from private.player_activity_proofs
                where user_id = p_user_id and server_event_id = p_server_event_id;
            end if;
        end if;
    end if;

    return pg_catalog.jsonb_build_object(
        'progress_recorded', true,
        'duplicate', not v_inserted,
        'activity_kind', p_activity_kind,
        'activity_id', p_activity_id,
        'verified_at', v_progress.verified_at,
        'reward_eligible', v_progress.reward_eligible_at_completion,
        'proof_id', v_proof_id
    );
end;
$function$;

revoke all on function public.record_server_verified_activity_progress(uuid,text,text,uuid,text,timestamptz,timestamptz)
    from public, anon, authenticated;
grant execute on function public.record_server_verified_activity_progress(uuid,text,text,uuid,text,timestamptz,timestamptz)
    to service_role;

create or replace function public.get_player_verified_activity_progress()
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_progress jsonb;
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode = '28000';
    end if;

    select coalesce(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'activity_kind', activity_kind,
                'activity_id', activity_id,
                'server_event_id', server_event_id,
                'verified_at', verified_at
            )
            order by verified_at, server_event_id
        ),
        '[]'::jsonb
    )
    into v_progress
    from private.player_verified_activity_progress
    where user_id = v_user_id;

    return pg_catalog.jsonb_build_object(
        'authoritative', true,
        'trust', 'server_verified',
        'activities', v_progress
    );
end;
$function$;

revoke all on function public.get_player_verified_activity_progress() from public, anon;
grant execute on function public.get_player_verified_activity_progress() to authenticated;

comment on table private.player_verified_activity_progress is
'Append-only server-verified activity completion ledger. Rows are written only through the trusted server HMAC proof issuer. Client sync observations never write here and never grant rewards.';

comment on function public.record_server_verified_activity_progress(uuid,text,text,uuid,text,timestamptz,timestamptz) is
'Backend-only atomic recorder for HMAC-verified dedicated-server activity completions. Records progress even when rewards are disabled; a reward proof is created only if the reward catalog was enabled at completion time.';

comment on function public.get_player_verified_activity_progress() is
'Returns only the authenticated player server-verified activity ledger. It does not merge or overwrite local state and does not grant rewards.';
