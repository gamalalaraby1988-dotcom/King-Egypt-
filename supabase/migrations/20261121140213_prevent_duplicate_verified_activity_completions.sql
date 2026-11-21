-- Prevent multiple sessions/devices from completing a one-time activity for the same account.
-- City adventures remain replayable; their activity IDs use the city_adventure_ prefix.

do $preflight$
begin
  if exists (
    select 1
    from private.player_verified_activity_progress
    where not (activity_kind = 'mission' and activity_id ~ '^city_adventure_')
    group by user_id, activity_kind, activity_id
    having count(*) > 1
  ) then
    raise exception 'duplicate_one_time_verified_activity_exists';
  end if;
end
$preflight$;

create unique index if not exists player_verified_activity_progress_one_time_idx
  on private.player_verified_activity_progress (user_id, activity_kind, activity_id)
  where not (activity_kind = 'mission' and activity_id ~ '^city_adventure_');

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

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_user_id::text || ':' || p_activity_kind || ':' || p_activity_id, 0)
    );
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_user_id::text || ':' || p_server_event_id::text, 0)
    );

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
    on conflict do nothing
    returning * into v_progress;

    if found then
        v_inserted := true;
    else
        select * into v_progress
        from private.player_verified_activity_progress
        where user_id = p_user_id and server_event_id = p_server_event_id;

        if found then
            if v_progress.activity_kind <> p_activity_kind
               or v_progress.activity_id <> p_activity_id
               or v_progress.evidence_digest <> v_digest
               or v_progress.verified_at <> p_issued_at then
                raise exception 'server_progress_event_conflict' using errcode = '23505';
            end if;
        else
            select * into v_progress
            from private.player_verified_activity_progress
            where user_id = p_user_id
              and activity_kind = p_activity_kind
              and activity_id = p_activity_id;

            if not found then
                raise exception 'server_progress_conflict' using errcode = '23505';
            end if;

            return pg_catalog.jsonb_build_object(
                'progress_recorded', true,
                'duplicate', true,
                'activity_kind', p_activity_kind,
                'activity_id', p_activity_id,
                'verified_at', v_progress.verified_at,
                'reward_eligible', v_progress.reward_eligible_at_completion,
                'proof_id', null
            );
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
