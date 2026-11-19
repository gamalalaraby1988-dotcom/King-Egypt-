-- Provision one stable player profile and an empty wallet for each Auth identity.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.ensure_player_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_code text;
begin
    if not exists (
        select 1 from public.player_profiles p where p.user_id = p_user_id
    ) then
        loop
            v_code := pg_catalog.upper(pg_catalog.substr(
                pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''),
                1, 10
            ));
            begin
                insert into public.player_profiles (user_id, player_code, display_name)
                values (p_user_id, v_code, 'لاعب');
                exit;
            exception when unique_violation then
                if exists (
                    select 1 from public.player_profiles p where p.user_id = p_user_id
                ) then
                    exit;
                end if;
                -- A concurrent player_code collision: generate another code and retry.
            end;
        end loop;
    end if;

    insert into public.player_wallets (user_id, cash, gems, chips, xp)
    values (p_user_id, 0, 0, 0, 0)
    on conflict (user_id) do nothing;
end;
$function$;

revoke all on function private.ensure_player_account(uuid) from public, anon, authenticated;

create or replace function private.provision_player_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
    perform private.ensure_player_account(new.id);
    return new;
end;
$function$;

revoke all on function private.provision_player_account() from public, anon, authenticated;

drop trigger if exists provision_player_account_after_auth_insert on auth.users;
create trigger provision_player_account_after_auth_insert
after insert on auth.users
for each row execute function private.provision_player_account();

-- Idempotently backfill any existing Auth identities missing their profile or empty wallet.
do $backfill$
declare
    v_user record;
begin
    for v_user in
        select u.id
        from auth.users u
        left join public.player_profiles p on p.user_id = u.id
        left join public.player_wallets w on w.user_id = u.id
        where p.user_id is null or w.user_id is null
    loop
        perform private.ensure_player_account(v_user.id);
    end loop;
end;
$backfill$;

comment on function private.ensure_player_account(uuid) is
'Creates a stable player profile and zero-balance wallet if missing. It never changes existing profile or wallet data and grants no privileges or rewards.';
comment on function private.provision_player_account() is
'Auth trigger wrapper that provisions a new player identity without granting rewards or privileges.';
