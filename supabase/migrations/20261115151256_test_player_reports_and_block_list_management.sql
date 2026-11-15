-- Test-only moderation reporting and self-service blocked-player management.
create table if not exists game_test.player_reports (
 report_id uuid primary key default gen_random_uuid(),
 reporter_account_id uuid not null references game_test.player_identities(test_account_id) on delete cascade,
 reported_account_id uuid not null references game_test.player_identities(test_account_id) on delete cascade,
 reason text not null check (reason in ('harassment','spam','inappropriate_name','cheating','other')),
 details text not null default '' check (char_length(details) <= 300),
 status text not null default 'pending' check (status in ('pending','reviewing','resolved','dismissed')),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 check (reporter_account_id <> reported_account_id)
);
create index if not exists player_reports_pending_recent on game_test.player_reports(created_at desc) where status='pending';
create index if not exists player_reports_reporter_recent on game_test.player_reports(reporter_account_id,created_at desc);
alter table game_test.player_reports enable row level security;
revoke all on game_test.player_reports from public,anon,authenticated;

create or replace function game_private.report_my_test_player(p_player_code text,p_reason text,p_details text default '')
returns text language plpgsql security definer set search_path=pg_catalog as $$
declare v_me uuid; v_target uuid; v_details text;
begin
 v_me:=game_private.my_test_account_id();
 if v_me is null then return 'authentication_required'; end if;
 if coalesce(p_player_code,'') !~ '^[A-Z0-9]{10}$' then return 'invalid_player_code'; end if;
 if coalesce(p_reason,'') not in ('harassment','spam','inappropriate_name','cheating','other') then return 'invalid_reason'; end if;
 v_details:=btrim(coalesce(p_details,''));
 if char_length(v_details)>300 then return 'details_too_long'; end if;
 select test_account_id into v_target from game_test.player_identities where player_code=upper(p_player_code);
 if v_target is null then return 'player_not_found'; end if;
 if v_target=v_me then return 'cannot_report_self'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_me::text,7));
 if (select count(*) from game_test.player_reports r where r.reporter_account_id=v_me and r.created_at>now()-interval '24 hours')>=5 then
  return 'report_rate_limited';
 end if;
 if exists(select 1 from game_test.player_reports r where r.reporter_account_id=v_me and r.reported_account_id=v_target and r.created_at>now()-interval '24 hours') then
  return 'already_reported_recently';
 end if;
 insert into game_test.player_reports(reporter_account_id,reported_account_id,reason,details)
 values(v_me,v_target,p_reason,v_details);
 return 'report_submitted';
end $$;

create or replace function game_private.list_my_test_blocked_players()
returns table(player_code text,display_name text,blocked_at timestamptz)
language sql stable security definer set search_path=pg_catalog as $$
 select i.player_code,left(coalesce(p.display_name,''),24),b.created_at
 from game_test.player_blocks b
 join game_test.player_identities i on i.test_account_id=b.blocked_account_id
 left join game_test.player_profiles p on p.test_account_id=b.blocked_account_id
 where b.blocker_account_id=game_private.my_test_account_id()
 order by b.created_at desc limit 100
$$;

create or replace function game_private.unblock_my_test_player(p_player_code text)
returns text language plpgsql security definer set search_path=pg_catalog as $$
declare v_me uuid; v_target uuid;
begin
 v_me:=game_private.my_test_account_id();
 if v_me is null then return 'authentication_required'; end if;
 if coalesce(p_player_code,'') !~ '^[A-Z0-9]{10}$' then return 'invalid_player_code'; end if;
 select test_account_id into v_target from game_test.player_identities where player_code=upper(p_player_code);
 if v_target is null then return 'player_not_found'; end if;
 delete from game_test.player_blocks where blocker_account_id=v_me and blocked_account_id=v_target;
 if not found then return 'not_blocked'; end if;
 return 'unblocked';
end $$;

create or replace function public.report_my_test_player(p_player_code text,p_reason text,p_details text default '')
returns text language sql set search_path=pg_catalog as $$
 select game_private.report_my_test_player(p_player_code,p_reason,p_details)
$$;
create or replace function public.list_my_test_blocked_players()
returns table(player_code text,display_name text,blocked_at timestamptz)
language sql stable set search_path=pg_catalog as $$
 select * from game_private.list_my_test_blocked_players()
$$;
create or replace function public.unblock_my_test_player(p_player_code text)
returns text language sql set search_path=pg_catalog as $$
 select game_private.unblock_my_test_player(p_player_code)
$$;

revoke all on function game_private.report_my_test_player(text,text,text) from public,anon,authenticated;
revoke all on function game_private.list_my_test_blocked_players() from public,anon,authenticated;
revoke all on function game_private.unblock_my_test_player(text) from public,anon,authenticated;
grant execute on function game_private.report_my_test_player(text,text,text) to authenticated;
grant execute on function game_private.list_my_test_blocked_players() to authenticated;
grant execute on function game_private.unblock_my_test_player(text) to authenticated;

revoke all on function public.report_my_test_player(text,text,text) from public,anon;
revoke all on function public.list_my_test_blocked_players() from public,anon;
revoke all on function public.unblock_my_test_player(text) from public,anon;
grant execute on function public.report_my_test_player(text,text,text) to authenticated;
grant execute on function public.list_my_test_blocked_players() to authenticated;
grant execute on function public.unblock_my_test_player(text) to authenticated;
