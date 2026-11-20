-- Permit parallel player exchanges while preventing season edits from racing an exchange.
create or replace function private.exchange_monthly_puzzle_pieces(
    p_season_id uuid, p_to_user_id uuid,
    p_offered_piece_id text, p_offered_quantity integer,
    p_requested_piece_id text, p_requested_quantity integer, p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_season private.puzzle_seasons%rowtype;
    v_existing private.puzzle_piece_exchanges%rowtype;
    v_exchange_id uuid;
    v_offered_balance integer;
    v_requested_balance integer;
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode = '28000';
    end if;
    if p_season_id is null or p_to_user_id is null or p_request_id is null
       or p_offered_piece_id is null or p_requested_piece_id is null
       or p_offered_piece_id = p_requested_piece_id or p_to_user_id = v_user_id
       or p_offered_quantity is null or p_offered_quantity <= 0
       or p_requested_quantity is null or p_requested_quantity <= 0 then
        raise exception 'invalid_puzzle_exchange_request' using errcode = '22023';
    end if;

    insert into private.puzzle_piece_exchanges (
        season_id, puzzle_id, from_user_id, to_user_id,
        offered_piece_id, offered_quantity, requested_piece_id, requested_quantity, request_id
    )
    select s.season_id, s.puzzle_id, v_user_id, p_to_user_id,
        p_offered_piece_id, p_offered_quantity, p_requested_piece_id, p_requested_quantity, p_request_id
    from private.puzzle_seasons s where s.season_id = p_season_id
    on conflict (from_user_id, request_id) do nothing
    returning exchange_id into v_exchange_id;

    if v_exchange_id is null then
        select * into v_existing from private.puzzle_piece_exchanges
        where from_user_id = v_user_id and request_id = p_request_id;
        if not found or v_existing.season_id <> p_season_id
           or v_existing.to_user_id <> p_to_user_id
           or v_existing.offered_piece_id <> p_offered_piece_id
           or v_existing.offered_quantity <> p_offered_quantity
           or v_existing.requested_piece_id <> p_requested_piece_id
           or v_existing.requested_quantity <> p_requested_quantity then
            raise exception 'puzzle_exchange_request_id_conflict' using errcode = '23505';
        end if;
        return pg_catalog.jsonb_build_object(
            'success', true, 'duplicate', true, 'exchange_id', v_existing.exchange_id
        );
    end if;

    -- SHARE locks allow parallel exchanges but block concurrent season edits.
    select * into v_season from private.puzzle_seasons
    where season_id = p_season_id and status = 'active'
      and start_at <= pg_catalog.now() and end_at > pg_catalog.now()
    for share;
    if not found then
        raise exception 'puzzle_season_not_active' using errcode = '22023';
    end if;

    if not exists (select 1 from private.puzzle_piece_catalog c
        where c.puzzle_id = v_season.puzzle_id and c.piece_id = p_offered_piece_id)
       or not exists (select 1 from private.puzzle_piece_catalog c
        where c.puzzle_id = v_season.puzzle_id and c.piece_id = p_requested_piece_id) then
        raise exception 'puzzle_piece_not_in_season_catalog' using errcode = '22023';
    end if;

    perform 1 from private.player_puzzle_piece_balances b
    where b.season_id = p_season_id and (
        (b.user_id = v_user_id and b.piece_id = p_offered_piece_id)
        or (b.user_id = p_to_user_id and b.piece_id = p_requested_piece_id)
    )
    order by b.user_id, b.piece_id for update;

    select b.quantity into v_offered_balance from private.player_puzzle_piece_balances b
    where b.season_id = p_season_id and b.user_id = v_user_id and b.piece_id = p_offered_piece_id;
    select b.quantity into v_requested_balance from private.player_puzzle_piece_balances b
    where b.season_id = p_season_id and b.user_id = p_to_user_id and b.piece_id = p_requested_piece_id;

    if coalesce(v_offered_balance, 0) < p_offered_quantity
       or coalesce(v_requested_balance, 0) < p_requested_quantity then
        raise exception 'puzzle_piece_balance_insufficient' using errcode = '22023';
    end if;

    update private.player_puzzle_piece_balances
    set quantity = quantity - p_offered_quantity, updated_at = pg_catalog.now()
    where season_id = p_season_id and user_id = v_user_id and piece_id = p_offered_piece_id;
    delete from private.player_puzzle_piece_balances
    where season_id = p_season_id and user_id = v_user_id and piece_id = p_offered_piece_id and quantity = 0;

    update private.player_puzzle_piece_balances
    set quantity = quantity - p_requested_quantity, updated_at = pg_catalog.now()
    where season_id = p_season_id and user_id = p_to_user_id and piece_id = p_requested_piece_id;
    delete from private.player_puzzle_piece_balances
    where season_id = p_season_id and user_id = p_to_user_id and piece_id = p_requested_piece_id and quantity = 0;

    insert into private.player_puzzle_piece_balances (season_id, puzzle_id, user_id, piece_id, quantity)
    values (p_season_id, v_season.puzzle_id, p_to_user_id, p_offered_piece_id, p_offered_quantity)
    on conflict (season_id, user_id, piece_id) do update
    set quantity = private.player_puzzle_piece_balances.quantity + excluded.quantity,
        updated_at = pg_catalog.now();

    insert into private.player_puzzle_piece_balances (season_id, puzzle_id, user_id, piece_id, quantity)
    values (p_season_id, v_season.puzzle_id, v_user_id, p_requested_piece_id, p_requested_quantity)
    on conflict (season_id, user_id, piece_id) do update
    set quantity = private.player_puzzle_piece_balances.quantity + excluded.quantity,
        updated_at = pg_catalog.now();

    return pg_catalog.jsonb_build_object('success', true, 'duplicate', false, 'exchange_id', v_exchange_id);
end;
$function$;
