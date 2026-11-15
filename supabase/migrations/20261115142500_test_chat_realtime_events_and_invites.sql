-- Secure, sanitized realtime events for public, group, direct chat and group invitations.
create or replace function game_private.get_my_test_chat_realtime_identity()
returns table(player_code text,display_name text)
language sql stable security definer set search_path=pg_catalog
as $$
 select i.player_code,left(coalesce(p.display_name,''),24)
 from game_test.player_identities i
 left join game_test.player_profiles p on p.test_account_id=i.test_account_id
 where i.test_account_id=game_private.my_test_account_id() limit 1
$$;

create or replace function game_private.list_my_test_chat_group_invites()
returns table(invite_id uuid,group_id uuid,inviter_code text,inviter_name text,created_at timestamptz)
language sql stable security definer set search_path=pg_catalog
as $$
 select i.invite_id,i.group_id,pi.player_code,left(coalesce(pp.display_name,''),24),i.created_at
 from game_test.chat_group_invites i
 join game_test.player_identities pi on pi.test_account_id=i.inviter_account_id
 left join game_test.player_profiles pp on pp.test_account_id=i.inviter_account_id
 where i.invitee_account_id=game_private.my_test_account_id() and i.status='pending'
 and not exists(select 1 from game_test.player_blocks b where
  (b.blocker_account_id=i.invitee_account_id and b.blocked_account_id=i.inviter_account_id)
  or (b.blocker_account_id=i.inviter_account_id and b.blocked_account_id=i.invitee_account_id))
 order by i.created_at desc limit 20
$$;

create or replace function public.get_my_test_chat_realtime_identity()
returns table(player_code text,display_name text)
language sql stable set search_path=pg_catalog
as $$ select * from game_private.get_my_test_chat_realtime_identity() $$;

create or replace function public.list_my_test_chat_group_invites()
returns table(invite_id uuid,group_id uuid,inviter_code text,inviter_name text,created_at timestamptz)
language sql stable set search_path=pg_catalog
as $$ select * from game_private.list_my_test_chat_group_invites() $$;

revoke all on function game_private.get_my_test_chat_realtime_identity() from public,anon,authenticated;
revoke all on function game_private.list_my_test_chat_group_invites() from public,anon,authenticated;
grant execute on function game_private.get_my_test_chat_realtime_identity() to authenticated;
grant execute on function game_private.list_my_test_chat_group_invites() to authenticated;
revoke all on function public.get_my_test_chat_realtime_identity() from public,anon;
revoke all on function public.list_my_test_chat_group_invites() from public,anon;
grant execute on function public.get_my_test_chat_realtime_identity() to authenticated;
grant execute on function public.list_my_test_chat_group_invites() to authenticated;

create or replace function game_private.broadcast_test_chat_message()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
declare v_topic text; v_code text; v_name text;
begin
 if new.channel_type='public' then v_topic:='chat:public:messages';
 else v_topic:='chat:group:'||new.group_id::text; end if;
 select i.player_code,left(coalesce(p.display_name,''),24) into v_code,v_name
 from game_test.player_identities i left join game_test.player_profiles p on p.test_account_id=i.test_account_id
 where i.test_account_id=new.sender_account_id;
 perform realtime.send(jsonb_build_object('message_id',new.message_id,'sender_code',v_code,
 'sender_name',coalesce(v_name,'لاعب'),'body',new.body,'created_at',new.created_at),
 'chat_message',v_topic,true);
 return new;
end $$;

create or replace function game_private.broadcast_test_chat_group_invite()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
declare v_target_code text; v_inviter_code text; v_inviter_name text;
begin
 select player_code into v_target_code from game_test.player_identities where test_account_id=new.invitee_account_id;
 select i.player_code,left(coalesce(p.display_name,''),24) into v_inviter_code,v_inviter_name
 from game_test.player_identities i left join game_test.player_profiles p on p.test_account_id=i.test_account_id
 where i.test_account_id=new.inviter_account_id;
 if v_target_code is not null then
  perform realtime.send(jsonb_build_object('invite_id',new.invite_id,'group_id',new.group_id,
  'inviter_code',v_inviter_code,'inviter_name',coalesce(v_inviter_name,'لاعب'),'created_at',new.created_at),
  'group_invite','chat:invites:'||v_target_code,true);
 end if;
 return new;
end $$;

create or replace function game_private.broadcast_test_direct_message()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
declare v_code text; v_name text;
begin
 if new.deleted_at is not null then return new; end if;
 select i.player_code,left(coalesce(p.display_name,''),24) into v_code,v_name
 from game_test.player_identities i left join game_test.player_profiles p on p.test_account_id=i.test_account_id
 where i.test_account_id=new.sender_account_id;
 perform realtime.send(jsonb_build_object('message_id',new.message_id,'sender_code',v_code,
 'sender_name',coalesce(v_name,'لاعب'),'body',new.body,'created_at',new.created_at),
 'direct_message','chat:direct:'||new.conversation_id::text,true);
 return new;
end $$;

revoke all on function game_private.broadcast_test_chat_message() from public,anon,authenticated;
revoke all on function game_private.broadcast_test_chat_group_invite() from public,anon,authenticated;
revoke all on function game_private.broadcast_test_direct_message() from public,anon,authenticated;

drop trigger if exists broadcast_test_chat_message on game_test.chat_messages;
create trigger broadcast_test_chat_message after insert on game_test.chat_messages
for each row execute function game_private.broadcast_test_chat_message();

drop trigger if exists broadcast_test_chat_group_invite on game_test.chat_group_invites;
create trigger broadcast_test_chat_group_invite after insert on game_test.chat_group_invites
for each row when (new.status='pending') execute function game_private.broadcast_test_chat_group_invite();

drop trigger if exists broadcast_test_direct_message on game_test.direct_messages;
create trigger broadcast_test_direct_message after insert on game_test.direct_messages
for each row execute function game_private.broadcast_test_direct_message();

drop policy if exists test_chat_private_channel_read on realtime.messages;
create policy test_chat_private_channel_read on realtime.messages
for select to authenticated using (
 realtime.topic()='chat:public:messages'
 or (realtime.topic() like 'chat:group:%' and exists(
  select 1 from game_test.chat_group_members m join game_test.chat_groups g using(group_id)
  where m.account_id=game_private.my_test_account_id() and m.left_at is null and g.closed_at is null
  and ('chat:group:'||m.group_id::text)=realtime.topic()))
 or (realtime.topic() like 'chat:invites:%' and exists(
  select 1 from game_test.player_identities i where i.test_account_id=game_private.my_test_account_id()
  and ('chat:invites:'||i.player_code)=realtime.topic()))
 or (realtime.topic() like 'chat:direct:%' and exists(
  select 1 from game_test.direct_conversations c where c.conversation_id::text=substring(realtime.topic() from 13)
  and game_private.my_test_account_id() in (c.account_low,c.account_high)
  and not exists(select 1 from game_test.player_blocks b where
   (b.blocker_account_id=c.account_low and b.blocked_account_id=c.account_high)
   or (b.blocker_account_id=c.account_high and b.blocked_account_id=c.account_low))))
);
