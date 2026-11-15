-- Serialize invitation and acceptance against the four-member group cap.
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
