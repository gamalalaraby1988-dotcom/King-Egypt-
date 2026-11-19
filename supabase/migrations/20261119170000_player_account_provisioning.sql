-- Provision one stable player profile and an empty wallet for each new Auth identity.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.generate_player_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
    v_code text;
begin
    loop
        v_code := pg_catalog.upper(pg_catalog.substr(
            pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''),
            1, 10
        ));
        exit when not exists (
            select 1 from public.player_profiles p where p.player_code = v_code
        );
    end loop;
    return v_code;
end;
$function$;

revoke all on function private.generate_player_code() from public, anon, authenticated;

create or replace function private.provision_player_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
    insert into public.player_profiles (user_id, player_code, display_name)
    values (new.id, private.generate_player_code(), 'لاعب')
    on conflict (user_id) do nothing;

    insert into public.player_wallets (user_id, cash, gems, chips, xp)
    values (new.id, 0, 0, 0, 0)
    on conflict (user_id) do nothing;

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
        insert into public.player_profiles (user_id, player_code, display_name)
        values (v_user.id, private.generate_player_code(), 'لاعب')
        on conflict (user_id) do nothing;

        insert into public.player_wallets (user_id, cash, gems, chips, xp)
        values (v_user.id, 0, 0, 0, 0)
        on conflict (user_id) do nothing;
    end loop;
end;
$backfill$;

comment on function private.provision_player_account() is
'Creates a stable public player profile and zero-balance wallet for a newly created Supabase Auth user. Does not grant privileges or rewards.';
