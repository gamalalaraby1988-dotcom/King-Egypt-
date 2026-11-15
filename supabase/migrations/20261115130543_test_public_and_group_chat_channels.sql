-- Test-only public and group chat backend. All tables stay private to the game API.
create table if not exists game_test.chat_groups (
 group_id uuid primary key default gen_random_uuid(), leader_account_id uuid not null,
 created_at timestamptz not null default now(), closed_at timestamptz
);
create table if not exists game_test.chat_group_members (
 group_id uuid not null references game_test.chat_groups(group_id) on delete cascade,
 account_id uuid not null, joined_at timestamptz not null default now(), left_at timestamptz,
 primary key(group_id,account_id)
);
create unique index if not exists chat_group_one_active_per_account on game_test.chat_group_members(account_id) where left_at is null;
create table if not exists game_test.chat_group_invites (
 invite_id uuid primary key default gen_random_uuid(), group_id uuid not null references game_test.chat_groups(group_id) on delete cascade,
 inviter_account_id uuid not null, invitee_account_id uuid not null,
 status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled')),
 created_at timestamptz not null default now(), responded_at timestamptz
);
create unique index if not exists chat_group_one_pending_invite on game_test.chat_group_invites(group_id,invitee_account_id) where status='pending';
create table if not exists game_test.chat_messages (
 message_id bigint generated always as identity primary key,
 channel_type text not null check(channel_type in ('public','group')),
 group_id uuid references game_test.chat_groups(group_id) on delete cascade,
 sender_account_id uuid not null, body text not null check(char_length(body) between 1 and 300),
 created_at timestamptz not null default now(),
 check((channel_type='public' and group_id is null) or (channel_type='group' and group_id is not null))
);
create index if not exists chat_messages_public_recent on game_test.chat_messages(message_id desc) where channel_type='public';
create index if not exists chat_messages_group_recent on game_test.chat_messages(group_id,message_id desc) where channel_type='group';
alter table game_test.chat_groups enable row level security;
alter table game_test.chat_group_members enable row level security;
alter table game_test.chat_group_invites enable row level security;
alter table game_test.chat_messages enable row level security;
revoke all on game_test.chat_groups,game_test.chat_group_members,game_test.chat_group_invites,game_test.chat_messages from public,anon,authenticated;

create or replace function game_private.create_my_test_chat_group()
returns table(success boolean,group_id uuid,error_code text) language plpgsql security definer set search_path=pg_catalog as $$
declare v_me uuid; v_group uuid;
begin
 v_me:=game_private.my_test_account_id();
 if v_me is null then return query select false,null::uuid,'authentication_required'; return; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_me::text,0));
 select m.group_id into v_group from game_test.chat_group_members m join game_test.chat_groups g using(group_id)
 where m.account_id=v_me and m.left_at is null and g.closed_at is null limit 1;
 if v_group is not null then return query select true,v_group,'already_in_group'; return; end if;
 insert into game_test.chat_groups(leader_account_id) values(v_me) returning chat_groups.group_id into v_group;
 insert into game_test.chat_group_members(group_id,account_id) values(v_group,v_me);
 return query select true,v_group,null::text;
end $$;

create or replace function game_private.invite_my_test_chat_group_member(p_player_code text)
returns text language plpgsql security definer set search_path=pg_catalog as $$
declare v_me uuid; v_group uuid; v_target uuid; v_count integer;
begin
 v_me:=game_private.my_test_account_id(); if v_me is null then return 'authentication_required'; end if;
 select g.group_id into v_group from game_test.chat_groups g join game_test.chat_group_members m using(group_id)
 where m.account_id=v_me and m.left_at is null and g.closed_at is null and g.leader_account_id=v_me limit 1;
 if v_group is null then return 'leader_group_not_found'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_group::text,1));
 if coalesce(p_player_code,'') !~ '^[A-Z0-9]{10}$' then return 'invalid_player_code'; end if;
 select test_account_id into v_target from game_test.player_identities where player_code=upper(p_player_code);
 if v_target is null then return 'player_not_found'; end if;
 if v_target=v_me then return 'cannot_invite_self'; end if;
 if not exists(select 1 from game_test.friendships f where f.account_low=least(v_me,v_target) and f.account_high=greatest(v_me,v_target)) then return 'not_friends'; end if;
 if exists(select 1 from game_test.player_blocks b where (b.blocker_account_id=v_me and b.blocked_account_id=v_target) or (b.blocker_account_id=v_target and b.blocked_account_id=v_me)) then return 'blocked'; end if;
 if exists(select 1 from game_test.chat_group_members m where m.account_id=v_target and m.left_at is null) then return 'target_already_in_group'; end if;
 select count(*) into v_count from game_test.chat_group_members m where m.group_id=v_group and m.left_at is null;
 if v_count>=4 then return 'group_full'; end if;
 insert into game_test.chat_group_invites(group_id,inviter_account_id,invitee_account_id) values(v_group,v_me,v_target) on conflict do nothing;
 if not found then return 'invite_already_pending'; end if; return 'sent';
end $$;

create or replace function game_private.respond_my_test_chat_group_invite(p_invite_id uuid,p_accept boolean)
returns text language plpgsql security definer set search_path=pg_catalog as $$
declare v_me uuid; v_group uuid; v_leader uuid; v_count integer;
begin
 v_me:=game_private.my_test_account_id(); if v_me is null then return 'authentication_required'; end if;
 select i.group_id,g.leader_account_id into v_group,v_leader from game_test.chat_group_invites i join game_test.chat_groups g using(group_id)
 where i.invite_id=p_invite_id and i.invitee_account_id=v_me and i.status='pending' for update of i,g;
 if v_group is null then return 'invite_not_found'; end if;
 if not p_accept then update game_test.chat_group_invites set status='declined',responded_at=now() where invite_id=p_invite_id; return 'declined'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_group::text,1));
 perform pg_advisory_xact_lock(hashtextextended(v_me::text,0));
 if exists(select 1 from game_test.chat_group_members m where m.account_id=v_me and m.left_at is null) then return 'already_in_group'; end if;
 select count(*) into v_count from game_test.chat_group_members m where m.group_id=v_group and m.left_at is null;
 if v_count>=4 then return 'group_full'; end if;
 if exists(select 1 from game_test.player_blocks b where (b.blocker_account_id=v_me and b.blocked_account_id=v_leader) or (b.blocker_account_id=v_leader and b.blocked_account_id=v_me)) then return 'blocked'; end if;
 insert into game_test.chat_group_members(group_id,account_id) values(v_group,v_me);
 update game_test.chat_group_invites set status='accepted',responded_at=now() where invite_id=p_invite_id; return 'accepted';
end $$;

create or replace function game_private.get_my_test_chat_group()
returns table(group_id uuid,player_code text,display_name text,is_leader boolean,joined_at timestamptz)
language sql stable security definer set search_path=pg_catalog as $$
 select g.group_id,i.player_code,left(coalesce(p.display_name,''),24),g.leader_account_id=m.account_id,m.joined_at
 from game_test.chat_group_members mine join game_test.chat_groups g using(group_id)
 join game_test.chat_group_members m using(group_id) join game_test.player_identities i on i.test_account_id=m.account_id
 left join game_test.player_profiles p on p.test_account_id=m.account_id
 where mine.account_id=game_private.my_test_account_id() and mine.left_at is null and m.left_at is null and g.closed_at is null
 order by m.joined_at limit 4
$$;

create or replace function game_private.send_my_test_chat_message(p_channel text,p_body text)
returns table(success boolean,message_id bigint,error_code text) language plpgsql security definer set search_path=pg_catalog as $$
declare v_me uuid; v_group uuid; v_id bigint; v_body text; v_count integer;
begin
 v_me:=game_private.my_test_account_id(); if v_me is null then return query select false,null::bigint,'authentication_required'; return; end if;
 v_body:=btrim(coalesce(p_body,'')); if char_length(v_body)<1 or char_length(v_body)>300 then return query select false,null::bigint,'invalid_message_length'; return; end if;
 if p_channel not in ('public','group') then return query select false,null::bigint,'invalid_channel'; return; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_me::text,0));
 select count(*) into v_count from game_test.chat_messages m where m.sender_account_id=v_me and m.created_at>now()-interval '10 seconds';
 if v_count>=5 then return query select false,null::bigint,'rate_limited'; return; end if;
 if p_channel='group' then
  select m.group_id into v_group from game_test.chat_group_members m join game_test.chat_groups g using(group_id)
  where m.account_id=v_me and m.left_at is null and g.closed_at is null limit 1;
  if v_group is null then return query select false,null::bigint,'not_in_group'; return; end if;
  if exists(select 1 from game_test.chat_group_members m join game_test.player_blocks b on
   (b.blocker_account_id=v_me and b.blocked_account_id=m.account_id) or (b.blocker_account_id=m.account_id and b.blocked_account_id=v_me)
   where m.group_id=v_group and m.left_at is null and m.account_id<>v_me) then return query select false,null::bigint,'blocked_group_member'; return; end if;
 else v_group:=null; end if;
 insert into game_test.chat_messages(channel_type,group_id,sender_account_id,body) values(p_channel,v_group,v_me,v_body) returning chat_messages.message_id into v_id;
 return query select true,v_id,null::text;
end $$;

create or replace function game_private.read_my_test_chat_messages(p_channel text,p_before_message_id bigint,p_limit integer)
returns table(message_id bigint,sender_is_me boolean,sender_code text,sender_name text,body text,created_at timestamptz)
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_me uuid; v_group uuid; v_limit integer;
begin
 v_me:=game_private.my_test_account_id(); if v_me is null then return; end if;
 if p_channel not in ('public','group') then return; end if;
 v_limit:=least(greatest(coalesce(p_limit,50),1),50);
 if p_channel='group' then
  select m.group_id into v_group from game_test.chat_group_members m join game_test.chat_groups g using(group_id)
  where m.account_id=v_me and m.left_at is null and g.closed_at is null limit 1;
  if v_group is null then return; end if;
 end if;
 return query select m.message_id,m.sender_account_id=v_me,i.player_code,left(coalesce(p.display_name,''),24),m.body,m.created_at
 from game_test.chat_messages m join game_test.player_identities i on i.test_account_id=m.sender_account_id
 left join game_test.player_profiles p on p.test_account_id=m.sender_account_id
 where m.channel_type=p_channel and ((p_channel='public' and m.group_id is null) or (p_channel='group' and m.group_id=v_group))
 and (p_before_message_id is null or m.message_id<p_before_message_id)
 and not exists(select 1 from game_test.player_blocks b where (b.blocker_account_id=v_me and b.blocked_account_id=m.sender_account_id) or (b.blocker_account_id=m.sender_account_id and b.blocked_account_id=v_me))
 order by m.message_id desc limit v_limit;
end $$;

create or replace function public.create_my_test_chat_group() returns table(success boolean,group_id uuid,error_code text) language sql set search_path=pg_catalog as $$ select * from game_private.create_my_test_chat_group() $$;
create or replace function public.invite_my_test_chat_group_member(p_player_code text) returns text language sql set search_path=pg_catalog as $$ select game_private.invite_my_test_chat_group_member(p_player_code) $$;
create or replace function public.respond_my_test_chat_group_invite(p_invite_id uuid,p_accept boolean) returns text language sql set search_path=pg_catalog as $$ select game_private.respond_my_test_chat_group_invite(p_invite_id,p_accept) $$;
create or replace function public.get_my_test_chat_group() returns table(group_id uuid,player_code text,display_name text,is_leader boolean,joined_at timestamptz) language sql stable set search_path=pg_catalog as $$ select * from game_private.get_my_test_chat_group() $$;
create or replace function public.send_my_test_chat_message(p_channel text,p_body text) returns table(success boolean,message_id bigint,error_code text) language sql set search_path=pg_catalog as $$ select * from game_private.send_my_test_chat_message(p_channel,p_body) $$;
create or replace function public.read_my_test_chat_messages(p_channel text,p_before_message_id bigint,p_limit integer) returns table(message_id bigint,sender_is_me boolean,sender_code text,sender_name text,body text,created_at timestamptz) language sql stable set search_path=pg_catalog as $$ select * from game_private.read_my_test_chat_messages(p_channel,p_before_message_id,p_limit) $$;

revoke all on function game_private.create_my_test_chat_group() from public,anon,authenticated;
revoke all on function game_private.invite_my_test_chat_group_member(text) from public,anon,authenticated;
revoke all on function game_private.respond_my_test_chat_group_invite(uuid,boolean) from public,anon,authenticated;
revoke all on function game_private.get_my_test_chat_group() from public,anon,authenticated;
revoke all on function game_private.send_my_test_chat_message(text,text) from public,anon,authenticated;
revoke all on function game_private.read_my_test_chat_messages(text,bigint,integer) from public,anon,authenticated;
grant execute on function game_private.create_my_test_chat_group() to authenticated;
grant execute on function game_private.invite_my_test_chat_group_member(text) to authenticated;
grant execute on function game_private.respond_my_test_chat_group_invite(uuid,boolean) to authenticated;
grant execute on function game_private.get_my_test_chat_group() to authenticated;
grant execute on function game_private.send_my_test_chat_message(text,text) to authenticated;
grant execute on function game_private.read_my_test_chat_messages(text,bigint,integer) to authenticated;
revoke all on function public.create_my_test_chat_group() from public,anon;
revoke all on function public.invite_my_test_chat_group_member(text) from public,anon;
revoke all on function public.respond_my_test_chat_group_invite(uuid,boolean) from public,anon;
revoke all on function public.get_my_test_chat_group() from public,anon;
revoke all on function public.send_my_test_chat_message(text,text) from public,anon;
revoke all on function public.read_my_test_chat_messages(text,bigint,integer) from public,anon;
grant execute on function public.create_my_test_chat_group() to authenticated;
grant execute on function public.invite_my_test_chat_group_member(text) to authenticated;
grant execute on function public.respond_my_test_chat_group_invite(uuid,boolean) to authenticated;
grant execute on function public.get_my_test_chat_group() to authenticated;
grant execute on function public.send_my_test_chat_message(text,text) to authenticated;
grant execute on function public.read_my_test_chat_messages(text,bigint,integer) to authenticated;

create or replace function game_private.broadcast_test_chat_message()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
declare v_topic text;
begin
 if new.channel_type='public' then v_topic:='chat:public:messages'; else v_topic:='chat:group:'||new.group_id::text; end if;
 perform realtime.broadcast_changes(v_topic,'INSERT','INSERT','chat_messages','game_test',new,null);
 return new;
end $$;
revoke all on function game_private.broadcast_test_chat_message() from public,anon,authenticated;
drop trigger if exists broadcast_test_chat_message on game_test.chat_messages;
create trigger broadcast_test_chat_message after insert on game_test.chat_messages for each row execute function game_private.broadcast_test_chat_message();

drop policy if exists test_chat_private_channel_read on realtime.messages;
create policy test_chat_private_channel_read on realtime.messages for select to authenticated using (
 realtime.topic()='chat:public:messages'
 or (realtime.topic() like 'chat:group:%' and exists (
  select 1 from game_test.chat_group_members m join game_test.chat_groups g using(group_id)
  where m.account_id=game_private.my_test_account_id() and m.left_at is null and g.closed_at is null
   and ('chat:group:'||m.group_id::text)=realtime.topic()
 ))
);
