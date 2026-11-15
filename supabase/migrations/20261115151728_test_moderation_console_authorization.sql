create table game_private.test_moderators (
  test_account_id uuid primary key
    references game_test.player_identities(test_account_id) on delete cascade,
  granted_at timestamptz not null default now()
);
alter table game_private.test_moderators enable row level security;
revoke all on game_private.test_moderators from public, anon, authenticated;

create or replace function game_private.is_my_test_moderator()
returns boolean
language sql stable security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1 from game_private.test_moderators m
    where m.test_account_id = game_private.my_test_account_id()
  )
$$;

create or replace function game_private.list_test_player_reports_for_moderation()
returns table (
  report_id uuid,
  reporter_player_code text,
  reporter_display_name text,
  reported_player_code text,
  reported_display_name text,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  reviewed_at timestamptz
)
language plpgsql stable security definer
set search_path = pg_catalog
as $$
begin
  if not game_private.is_my_test_moderator() then
    raise exception 'moderator_access_required' using errcode = '42501';
  end if;

  return query
  select r.report_id,
         ri.player_code,
         left(coalesce(rp.display_name, ''), 24),
         ti.player_code,
         left(coalesce(tp.display_name, ''), 24),
         r.reason,
         r.details,
         r.status,
         r.created_at,
         r.reviewed_at
  from game_test.player_reports r
  join game_test.player_identities ri on ri.test_account_id = r.reporter_account_id
  left join game_test.player_profiles rp on rp.test_account_id = r.reporter_account_id
  join game_test.player_identities ti on ti.test_account_id = r.reported_account_id
  left join game_test.player_profiles tp on tp.test_account_id = r.reported_account_id
  where r.status in ('pending', 'reviewing')
  order by r.created_at asc
  limit 200;
end
$$;

create or replace function game_private.set_test_player_report_status(
  p_report_id uuid,
  p_status text
)
returns text
language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  if not game_private.is_my_test_moderator() then
    return 'moderator_access_required';
  end if;
  if p_report_id is null or coalesce(p_status, '') not in ('reviewing', 'resolved', 'dismissed') then
    return 'invalid_request';
  end if;

  update game_test.player_reports
     set status = p_status,
         reviewed_at = case when p_status = 'reviewing' then null else now() end
   where report_id = p_report_id
     and status in ('pending', 'reviewing');

  if not found then
    return 'report_not_found_or_closed';
  end if;
  return 'status_updated';
end
$$;

create or replace function public.is_my_test_moderator()
returns boolean language sql stable
set search_path = pg_catalog
as $$ select game_private.is_my_test_moderator() $$;

create or replace function public.list_test_player_reports_for_moderation()
returns table (
  report_id uuid,
  reporter_player_code text,
  reporter_display_name text,
  reported_player_code text,
  reported_display_name text,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  reviewed_at timestamptz
)
language sql stable
set search_path = pg_catalog
as $$ select * from game_private.list_test_player_reports_for_moderation() $$;

create or replace function public.set_test_player_report_status(p_report_id uuid, p_status text)
returns text language sql
set search_path = pg_catalog
as $$ select game_private.set_test_player_report_status(p_report_id, p_status) $$;

revoke all on function game_private.is_my_test_moderator() from public, anon, authenticated;
revoke all on function game_private.list_test_player_reports_for_moderation() from public, anon, authenticated;
revoke all on function game_private.set_test_player_report_status(uuid,text) from public, anon, authenticated;
grant execute on function game_private.is_my_test_moderator() to authenticated;
grant execute on function game_private.list_test_player_reports_for_moderation() to authenticated;
grant execute on function game_private.set_test_player_report_status(uuid,text) to authenticated;

revoke all on function public.is_my_test_moderator() from public, anon;
revoke all on function public.list_test_player_reports_for_moderation() from public, anon;
revoke all on function public.set_test_player_report_status(uuid,text) from public, anon;
grant execute on function public.is_my_test_moderator() to authenticated;
grant execute on function public.list_test_player_reports_for_moderation() to authenticated;
grant execute on function public.set_test_player_report_status(uuid,text) to authenticated;
