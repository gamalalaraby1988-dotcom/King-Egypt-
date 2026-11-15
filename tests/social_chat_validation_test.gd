extends SceneTree

func _initialize() -> void:
	call_deferred("_run_social_validation_tests")

func _run_social_validation_tests() -> void:
	await process_frame
	var social := root.get_node_or_null("SocialChatManager")
	if social == null:
		push_error("SocialChatManager autoload did not initialize.")
		quit(1)
		return

	var saved_topics: Dictionary = social._realtime_topics.duplicate(true)
	var saved_join_refs: Dictionary = social._realtime_join_refs.duplicate(true)
	var saved_ready_topics: Dictionary = social._realtime_ready_topics.duplicate(true)
	social._realtime_topics = {"chat:direct:joined": true}
	social._realtime_join_refs = {"chat:direct:joined": "ci-join-ref"}
	social._realtime_ready_topics = {}
	if social.is_realtime_topic_subscribed("chat:direct:joined"):
		push_error("A pending realtime join was treated as ready before server acknowledgement.")
		quit(1)
		return
	social._realtime_ready_topics = {"chat:direct:joined": true}
	if not social.is_realtime_join_ack_current("chat:direct:joined", "ci-join-ref"):
		push_error("The current realtime join acknowledgement was not recognized.")
		quit(1)
		return
	if social.is_realtime_join_ack_current("chat:direct:joined", "stale-join-ref") or social.is_realtime_join_ack_current("chat:direct:unjoined", "ci-join-ref"):
		push_error("A stale or unrelated realtime join acknowledgement was accepted.")
		quit(1)
		return
	if not social.is_realtime_topic_subscribed("chat:direct:joined"):
		push_error("A server-acknowledged realtime topic was not recognized.")
		quit(1)
		return
	if social.is_realtime_topic_subscribed("chat:direct:unjoined") or social.is_realtime_topic_subscribed("chat:group:joined"):
		push_error("An unjoined realtime topic was treated as an active subscription.")
		quit(1)
		return
	social._realtime_topics = saved_topics
	social._realtime_join_refs = saved_join_refs
	social._realtime_ready_topics = saved_ready_topics

	if not social.is_valid_player_code("AB12CD34EF"):
		push_error("A valid ten-character player code was rejected.")
		quit(1)
		return
	if social.is_valid_player_code("AB12-CD34"):
		push_error("A player code containing punctuation was accepted.")
		quit(1)
		return
	if social.is_valid_player_code("AB12CD34E"):
		push_error("A player code shorter than ten characters was accepted.")
		quit(1)
		return

	social.set_realtime_player_code("bad-code")
	if not social._realtime_player_code.is_empty() or social._realtime_topics.has("chat:invites:BAD-CODE"):
		push_error("An invalid player identity created a realtime invitation subscription.")
		quit(1)
		return
	social.set_realtime_player_code("AB12CD34EF")
	if social._realtime_player_code != "AB12CD34EF" or not social._realtime_topics.has("chat:invites:AB12CD34EF"):
		push_error("A valid player identity did not create its invitation subscription.")
		quit(1)
		return
	social.set_realtime_player_code("")
	if not social._realtime_player_code.is_empty() or social._realtime_topics.has("chat:invites:AB12CD34EF"):
		push_error("Clearing a player identity left its realtime invitation subscription active.")
		quit(1)
		return

	social.subscribe_group_chat("group-a")
	if social._realtime_group_id != "group-a" or not social._realtime_topics.has("chat:group:group-a"):
		push_error("The initial group subscription was not registered.")
		quit(1)
		return
	social.subscribe_group_chat("group-b")
	if social._realtime_group_id != "group-b" or social._realtime_topics.has("chat:group:group-a") or not social._realtime_topics.has("chat:group:group-b"):
		push_error("Switching groups left the previous realtime group topic subscribed.")
		quit(1)
		return
	social.subscribe_group_chat("")
	if not social._realtime_group_id.is_empty() or social._realtime_topics.has("chat:group:group-b"):
		push_error("Leaving a group did not clear its realtime subscription.")
		quit(1)
		return

	social.subscribe_direct_chat("conversation-a")
	if social._realtime_direct_id != "conversation-a" or not social._realtime_topics.has("chat:direct:conversation-a"):
		push_error("The initial direct conversation subscription was not registered.")
		quit(1)
		return
	social.subscribe_direct_chat("conversation-b")
	if social._realtime_direct_id != "conversation-b" or social._realtime_topics.has("chat:direct:conversation-a") or not social._realtime_topics.has("chat:direct:conversation-b"):
		push_error("Switching direct conversations left the previous realtime topic subscribed.")
		quit(1)
		return
	social.subscribe_direct_chat("")
	if not social._realtime_direct_id.is_empty() or social._realtime_topics.has("chat:direct:conversation-b"):
		push_error("Closing a direct conversation did not clear its realtime subscription.")
		quit(1)
		return

	if social.open_direct_conversation("bad-code"):
		push_error("Invalid player code was accepted for direct conversation.")
		quit(1)
		return
	if social.invite_chat_group_member("bad-code"):
		push_error("Invalid player code was accepted for group invitation.")
		quit(1)
		return
	if social.send_chat_message("admin", "hello"):
		push_error("Unsupported chat channel was accepted.")
		quit(1)
		return
	if social.send_chat_message("public", "   "):
		push_error("Empty chat message was accepted.")
		quit(1)
		return
	if social.send_chat_message("group", "x".repeat(301)):
		push_error("Overlength chat message was accepted.")
		quit(1)
		return
	if social.read_chat_messages("private"):
		push_error("Unsupported chat read channel was accepted.")
		quit(1)
		return

	var invitation_script: Script = load("res://scripts/invitation_overlay.gd")
	var invitation_overlay: Control = invitation_script.new()
	root.add_child(invitation_overlay)
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-account-a-invite",
		"title": "CI invitation",
		"body": "Account A invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	if invitation_overlay.get_pending_invitation_count() != 1:
		push_error("Invitation overlay did not retain the active test invitation.")
		quit(1)
		return
	invitation_overlay.clear_pending_invitations()
	if invitation_overlay.get_pending_invitation_count() != 0 or not invitation_overlay._current.is_empty() or invitation_overlay._panel.visible:
		push_error("A previous account's active or queued invitation survived account cleanup.")
		quit(1)
		return
	invitation_overlay.free()

	print("Social chat input and invitation lifecycle validation tests passed.")
	quit(0)
