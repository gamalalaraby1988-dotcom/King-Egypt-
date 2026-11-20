-- Choose free spins before paid spins atomically under the per-player/machine challenge lock.
-- The client and game server request "auto"; the database decides the effective spin type.
create or replace function private.settle_arcade_slot_spin_auto(
    p_user_id uuid,
    p_session_id uuid,
    p_server_event_id uuid,
    p_machine_id text,
    p_wager_chips bigint,
    p_reel_symbols integer[],
    p_collection_symbols integer[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_existing private.arcade_slot_round_ledger%rowtype;
    v_free_spins bigint;
    v_spin_type text;
    v_wager_chips bigint;
begin
    if p_user_id is null or p_session_id is null or p_server_event_id is null
       or p_machine_id is null or p_wager_chips is null
       or p_wager_chips not between 10 and 2000000000
       or p_reel_symbols is null or p_collection_symbols is null then
        raise exception 'slot_spin_values_invalid' using errcode = '22023';
    end if;

    -- Idempotent retries reuse the already committed effective spin type and wager.
    select * into v_existing
    from private.arcade_slot_round_ledger
    where server_event_id = p_server_event_id;
    if found then
        return private.settle_arcade_slot_spin(
            p_user_id, p_session_id, p_server_event_id, p_machine_id,
            v_existing.spin_type, v_existing.wager_chips,
            p_reel_symbols, p_collection_symbols
        );
    end if;

    insert into private.arcade_slot_challenge_state (user_id, machine_id)
    values (p_user_id, p_machine_id)
    on conflict (user_id, machine_id) do nothing;

    select free_spins into v_free_spins
    from private.arcade_slot_challenge_state
    where user_id = p_user_id and machine_id = p_machine_id
    for update;

    -- A concurrent retry may have committed while this request waited for the row lock.
    select * into v_existing
    from private.arcade_slot_round_ledger
    where server_event_id = p_server_event_id;
    if found then
        return private.settle_arcade_slot_spin(
            p_user_id, p_session_id, p_server_event_id, p_machine_id,
            v_existing.spin_type, v_existing.wager_chips,
            p_reel_symbols, p_collection_symbols
        );
    end if;

    v_spin_type := case when v_free_spins > 0 then 'free' else 'paid' end;
    v_wager_chips := case when v_spin_type = 'free' then 10 else p_wager_chips end;

    return private.settle_arcade_slot_spin(
        p_user_id, p_session_id, p_server_event_id, p_machine_id,
        v_spin_type, v_wager_chips, p_reel_symbols, p_collection_symbols
    );
end;
$function$;

revoke all on function private.settle_arcade_slot_spin_auto(uuid,uuid,uuid,text,bigint,integer[],integer[])
    from public, anon, authenticated;
grant execute on function private.settle_arcade_slot_spin_auto(uuid,uuid,uuid,text,bigint,integer[],integer[])
    to service_role;

create or replace function public.settle_arcade_slot_spin_auto(
    p_user_id uuid,
    p_session_id uuid,
    p_server_event_id uuid,
    p_machine_id text,
    p_wager_chips bigint,
    p_reel_symbols integer[],
    p_collection_symbols integer[]
)
returns jsonb
language sql
security invoker
set search_path = ''
as $wrapper$
    select private.settle_arcade_slot_spin_auto(
        p_user_id, p_session_id, p_server_event_id, p_machine_id,
        p_wager_chips, p_reel_symbols, p_collection_symbols
    );
$wrapper$;

revoke all on function public.settle_arcade_slot_spin_auto(uuid,uuid,uuid,text,bigint,integer[],integer[])
    from public, anon, authenticated;
grant execute on function public.settle_arcade_slot_spin_auto(uuid,uuid,uuid,text,bigint,integer[],integer[])
    to service_role;
