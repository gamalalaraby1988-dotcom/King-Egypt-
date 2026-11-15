extends SceneTree

func _initialize() -> void:
	call_deferred("_run_social_validation_tests")

func _run_social_validation_tests() -> void:
	await process_frame
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Social chat validation test watchdog expired.")
		quit(1)
	)
	print("SOCIAL_TEST_STAGE: autoload_ready")
	var social := root.get_node_or_null("SocialChatManager")
	if social == null:
		push_error("SocialChatManager autoload did not initialize.")
		quit(1)
		return

	var invitation_overlay_script: Script = load("res://scripts/invitation_overlay.gd")
	if invitation_overlay_script == null:
		push_error("Unified invitation overlay script could not be loaded.")
		quit(1)
		return
	var expiry_probe: Control = invitation_overlay_script.new()
	if not is_equal_approx(expiry_probe.get_panel_width_for_viewport(360.0), 314.0):
		push_error("The invitation panel width changed unexpectedly on a standard 360px phone screen.")
		quit(1)
		return
	if not is_equal_approx(expiry_probe.get_panel_width_for_viewport(320.0), 296.0):
		push_error("The invitation panel did not shrink to preserve margins on a 320px phone screen.")
		quit(1)
		return
	if not is_equal_approx(expiry_probe.get_panel_width_for_viewport(240.0), 216.0):
		push_error("The invitation panel did not adapt to a narrow 240px viewport.")
		quit(1)
		return
	for viewport_width in [20.0, 180.0, 200.0, 240.0, 320.0, 360.0, 800.0, 1280.0]:
		var panel_layout: Vector2 = expiry_probe.get_panel_layout_for_viewport(viewport_width)
		if panel_layout.x < 0.0 or panel_layout.y < 0.0 or panel_layout.x * 2.0 + panel_layout.y > viewport_width:
			push_error("The invitation panel or its horizontal margins escaped the viewport after a portrait/landscape size change.")
			quit(1)
			return
	for viewport_height in [20.0, 180.0, 240.0, 320.0, 360.0, 800.0, 1280.0]:
		var vertical_layout: Vector2 = expiry_probe.get_panel_vertical_layout(viewport_height)
		if vertical_layout.x < 0.0 or vertical_layout.y < 0.0 or vertical_layout.x + vertical_layout.y > viewport_height:
			push_error("The invitation panel escaped the viewport height after switching to landscape orientation.")
			quit(1)
			return
	var known_created_at := "2026-11-16T10:00:00"
	var known_created_timestamp := float(Time.get_unix_time_from_datetime_string(known_created_at))
	var anchored_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": known_created_at}, known_created_timestamp + 10.0)
	if not is_equal_approx(anchored_deadline, known_created_timestamp + 30.0):
		push_error("A server creation timestamp did not anchor the invitation to its original 30-second lifetime.")
		quit(1)
		return
	var extended_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": known_created_at, "expires_at": known_created_timestamp + 90.0}, known_created_timestamp + 10.0)
	if not is_equal_approx(extended_deadline, known_created_timestamp + 30.0):
		push_error("A supplied invitation deadline extended the approved 30-second lifetime.")
		quit(1)
		return
	var anchored_shortened_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": known_created_at, "expires_at": known_created_timestamp + 20.0}, known_created_timestamp + 10.0)
	if not is_equal_approx(anchored_shortened_deadline, known_created_timestamp + 20.0):
		push_error("A shorter supplied invitation deadline was not respected.")
		quit(1)
		return
	var receipt_deadline: float = expiry_probe.resolve_invitation_expiry({"expires_at": 2000.0}, 1000.0)
	if not is_equal_approx(receipt_deadline, 1030.0):
		push_error("An invitation without a trustworthy creation timestamp did not receive a 30-second receipt cap.")
		quit(1)
		return
	var malformed_created_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": "not-a-date"}, 1000.0)
	if not is_equal_approx(malformed_created_deadline, 1030.0):
		push_error("An invitation with a malformed creation timestamp was granted a fresh lifetime.")
		quit(1)
		return
	var future_created_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": "2026-11-17T10:00:00"}, 1000.0)
	if not is_equal_approx(future_created_deadline, 1030.0):
		push_error("An invitation with a future creation timestamp was granted a fresh lifetime.")
		quit(1)
		return
	expiry_probe.free()
	var compact_overlay: Control = invitation_overlay_script.new()
	root.add_child(compact_overlay)
	await process_frame
	var content_scroll := compact_overlay.get_node_or_null("UnifiedInvitationPanel/InvitationContentScroll")
	if not content_scroll is ScrollContainer:
		push_error("The invitation panel did not create its compact-height scroll container.")
		quit(1)
		return
	if content_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or content_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		push_error("The invitation panel scroll container does not preserve vertical-only compact content scrolling.")
		quit(1)
		return
	var accept_button := compact_overlay.find_child("AcceptInvitationButton", true, false)
	var decline_button := compact_overlay.find_child("DeclineInvitationButton", true, false)
	if not accept_button is Button or not decline_button is Button:
		push_error("The invitation panel action buttons could not be found for touch-target validation.")
		quit(1)
		return
	if accept_button.custom_minimum_size.y < 44.0 or decline_button.custom_minimum_size.y < 44.0:
		push_error("Invitation accept/decline touch targets are smaller than the 44px mobile target.")
		quit(1)
		return
	compact_overlay.queue_free()
	await process_frame
	var dedupe_overlay: Control = invitation_overlay_script.new()
	var expired_invitation_ids: Array[String] = []
	dedupe_overlay.invitation_expired.connect(func(invitation: Dictionary) -> void:
		expired_invitation_ids.append(str(invitation.get("invite_id", "")))
	)
	var duplicate_expired_invitation := {
		"invite_id": "550e8400-e29b-41d4-a716-446655440099",
		"expires_at": 1.0
	}
	dedupe_overlay.enqueue_invitation(duplicate_expired_invitation)
	dedupe_overlay.enqueue_invitation(duplicate_expired_invitation)
	if expired_invitation_ids.size() != 1:
		push_error("A repeated realtime delivery re-emitted the same expired invitation.")
		quit(1)
		return
	dedupe_overlay.clear_pending_invitations()
	dedupe_overlay.enqueue_invitation(duplicate_expired_invitation)
	if expired_invitation_ids.size() != 2:
		push_error("Invitation deduplication state was not cleared for a new account session.")
		quit(1)
		return
	dedupe_overlay.free()

	print("SOCIAL_TEST_STAGE: invitation_dedupe_complete")
	var city_hud_script: Script = load("res://scripts/city_hud.gd")
	if city_hud_script == null:
		push_error("City HUD script could not be loaded for group-gather guard tests.")
		quit(1)
		return
	var city_hud: CanvasLayer = city_hud_script.new()
	if not city_hud.can_show_group_gather_button(true, 2, false):
		push_error("A group leader with another member outside an apartment should see the gather button.")
		quit(1)
		return
	if city_hud.can_show_group_gather_button(false, 2, false):
		push_error("A non-leader was allowed to see the group gather button.")
		quit(1)
		return
	if city_hud.can_show_group_gather_button(true, 1, false):
		push_error("A solo leader was allowed to see the group gather button.")
		quit(1)
		return
	if city_hud.can_show_group_gather_button(true, 2, true):
		push_error("The group gather button remained available inside a private apartment.")
		quit(1)
		return

	var male_portrait_scene: String = city_hud.get_friend_character_scene_path({"selected_character_id":"eg_m_adam"})
	var female_portrait_scene: String = city_hud.get_friend_character_scene_path({"selected_character_id":"eg_f_layan"})
	if male_portrait_scene != "res://scenes/characters/avatar_visual.tscn" or female_portrait_scene != "res://scenes/characters/avatar_visual.tscn":
		push_error("A supported male/female roster ID did not resolve to the in-game character preview scene.")
		quit(1)
		return
	var avatar_scene: PackedScene = load("res://scenes/characters/avatar_visual.tscn") as PackedScene
	if avatar_scene == null:
		push_error("The in-game character preview scene could not be loaded.")
		quit(1)
		return
	var male_avatar := avatar_scene.instantiate()
	root.add_child(male_avatar)
	male_avatar.call("apply_character_identity", "eg_m_adam")
	if str(male_avatar.get("current_outfit")) != "men_formal" or str(male_avatar.get("current_hairstyle")) != "short":
		push_error("A male roster identity did not apply its approved in-game character preset.")
		quit(1)
		return
	male_avatar.queue_free()
	var female_avatar := avatar_scene.instantiate()
	root.add_child(female_avatar)
	female_avatar.call("apply_character_identity", "eg_f_layan")
	if str(female_avatar.get("current_outfit")) != "women_formal" or str(female_avatar.get("current_hairstyle")) != "long":
		push_error("A female roster identity did not apply its approved in-game character preset.")
		quit(1)
		return
	female_avatar.queue_free()
	var male_portrait: Control = city_hud.call("_build_friend_character_portrait", {"selected_character_id":"eg_m_adam"}) as Control
	root.add_child(male_portrait)
	await process_frame
	await process_frame
	if not male_portrait is SubViewportContainer:
		push_error("A valid in-game male character did not produce a rendered viewport portrait.")
		quit(1)
		return
	var portrait_viewport := male_portrait.get_child(0) as SubViewport
	var portrait_world := portrait_viewport.get_child(0) as Node3D
	var portrait_character := portrait_world.get_child(2) as Node3D
	if portrait_viewport.size.x <= 0 or portrait_viewport.size.y <= 0 or portrait_character == null or str(portrait_character.get("current_outfit")) != "men_formal":
		push_error("The male friend portrait viewport did not render the selected in-game character preset.")
		quit(1)
		return
	male_portrait.free()
	var female_portrait: Control = city_hud.call("_build_friend_character_portrait", {"character_id":"eg_f_layan"}) as Control
	root.add_child(female_portrait)
	await process_frame
	await process_frame
	if not female_portrait is SubViewportContainer:
		push_error("A valid in-game female character did not produce a rendered viewport portrait.")
		quit(1)
		return
	var female_viewport := female_portrait.get_child(0) as SubViewport
	var female_world := female_viewport.get_child(0) as Node3D
	var female_character := female_world.get_child(2) as Node3D
	if female_viewport.size.x <= 0 or female_viewport.size.y <= 0 or female_character == null or str(female_character.get("current_outfit")) != "women_formal":
		push_error("The female friend portrait viewport did not render the selected in-game character preset.")
		quit(1)
		return
	female_portrait.free()
	var unknown_portrait: Control = city_hud.call("_build_friend_character_portrait", {"selected_character_id":"xx_m_unknown"}) as Control
	root.add_child(unknown_portrait)
	if unknown_portrait is SubViewportContainer or unknown_portrait.name != "FriendCharacterPortraitFallback":
		push_error("An unknown character did not receive the neutral in-game portrait fallback.")
		quit(1)
		return
	unknown_portrait.free()
	if city_hud.get_friend_character_scene_path({"selected_character_id":"xx_m_unknown"}) != "":
		push_error("An unknown character ID was allowed to resolve to a portrait scene.")
		quit(1)
		return
	if city_hud.get_friend_character_scene_path({"selected_character_id":"https://example.com/avatar.png"}) != "":
		push_error("The friend portrait resolver accepted an external image URL.")
		quit(1)
		return
	if city_hud.get_friend_character_scene_path({"selected_character_id":"../../outside"}) != "":
		push_error("The friend portrait resolver accepted a path traversal value.")
		quit(1)
		return
	if city_hud.get_friend_character_scene_path({"avatar_texture":null}) != "":
		push_error("The friend portrait resolver accepted a texture without an in-game character ID.")
		quit(1)
		return

	var online_invite_friends: Array = city_hud.get_online_group_invite_friends([
		{"player_code":"AB12CD34EF", "display_name":"متصل", "is_online":true},
		{"player_code":"CD34EF56GH", "display_name":"غير متصل", "is_online":false},
		{"player_code":"EF56GH78JK", "display_name":"حالة متصلة", "status":"online"},
		{"player_code":"GH78JK90LM", "display_name":"غير معروف"}
	])
	if online_invite_friends.size() != 2:
		push_error("The group invite picker did not restrict its results to explicitly online friends.")
		quit(1)
		return

	if city_hud.has_group_invite_presence_metadata([
		{"player_code":"AB12CD34EF", "display_name":"صديق"}
	]):
		push_error("The group invite picker treated a friend list without presence fields as having online status.")
		quit(1)
		return
	if not city_hud.has_group_invite_presence_metadata([
		{"player_code":"AB12CD34EF", "display_name":"صديق", "is_online":false}
	]):
		push_error("The group invite picker failed to recognize explicit offline presence metadata.")
		quit(1)
		return

	if str(online_invite_friends[0].get("player_code", "")) != "AB12CD34EF" or str(online_invite_friends[1].get("player_code", "")) != "EF56GH78JK":
		push_error("The group invite picker returned an offline or unknown-presence friend.")
		quit(1)
		return

	var deferred_invite := {"expires_at": 200.0}
	if not city_hud.resolve_deferred_invitation_acceptance(deferred_invite, true, 199.0):
		push_error("A still-valid queued invitation acceptance was changed.")
		quit(1)
		return
	if city_hud.resolve_deferred_invitation_acceptance(deferred_invite, true, 200.0):
		push_error("An expired queued invitation acceptance was not downgraded to decline.")
		quit(1)
		return
	if city_hud.resolve_deferred_invitation_acceptance({}, true, 100.0):
		push_error("A queued acceptance without a verified expiry deadline was allowed.")
		quit(1)
		return
	if city_hud.resolve_deferred_invitation_acceptance(deferred_invite, false, 199.0):
		push_error("A queued decline was incorrectly converted into acceptance.")
		quit(1)
		return
	var first_invite_id := "550e8400-e29b-41d4-a716-446655440000"
	var second_invite_id := "550e8400-e29b-41d4-a716-446655440001"
	if not city_hud.can_submit_group_invitation_response("", first_invite_id):
		push_error("A valid first group invitation response was blocked.")
		quit(1)
		return
	if city_hud.can_submit_group_invitation_response(first_invite_id, second_invite_id) or city_hud.can_submit_group_invitation_response("", ""):
		push_error("Overlapping or empty group invitation responses were allowed.")
		quit(1)
		return
	if city_hud.can_submit_group_invitation_response("", "invite-1"):
		push_error("A malformed group invitation UUID passed the HUD response guard.")
		quit(1)
		return
	if not city_hud.can_accept_social_invitation_payload("chat:invites:AB12CD34EF", "AB12CD34EF", first_invite_id):
		push_error("A valid private invitation topic and UUID were rejected.")
		quit(1)
		return
	if city_hud.can_accept_social_invitation_payload("chat:invites:OTHER12345", "AB12CD34EF", first_invite_id):
		push_error("An invitation from another player's private topic was accepted.")
		quit(1)
		return
	if city_hud.can_accept_social_invitation_payload("chat:invites:AB12CD34EF", "bad-code", first_invite_id):
		push_error("An invitation with an invalid local player code was accepted.")
		quit(1)
		return
	if city_hud.can_accept_social_invitation_payload("chat:invites:AB12CD34EF", "AB12CD34EF", "not-a-uuid"):
		push_error("An invitation with a malformed id was accepted into the HUD.")
		quit(1)
		return
	city_hud.free()

	print("SOCIAL_TEST_STAGE: hud_guards_complete")
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

	# Channel-level close/error must retry only the current join, never a stale ref.
	var saved_topic_retries: Dictionary = social._realtime_topic_retry_seconds.duplicate(true)
	var saved_topic_retry_attempts: Dictionary = social._realtime_topic_retry_attempts.duplicate(true)
	social._realtime_topics = {"chat:direct:retry": true}
	social._realtime_join_refs = {"chat:direct:retry": "active-ref"}
	social._realtime_ready_topics = {"chat:direct:retry": true}
	social._realtime_topic_retry_seconds = {}
	social._schedule_realtime_topic_retry("chat:direct:retry", "stale-ref")
	if not social._realtime_join_refs.has("chat:direct:retry") or not social._realtime_ready_topics.has("chat:direct:retry"):
		push_error("A stale channel failure cleared the current realtime join.")
		quit(1)
		return
	social._schedule_realtime_topic_retry("chat:direct:retry", "active-ref")
	if social._realtime_join_refs.has("chat:direct:retry") or social._realtime_ready_topics.has("chat:direct:retry"):
		push_error("A current channel failure did not clear its failed join state.")
		quit(1)
		return
	if social._take_due_realtime_topic_retries(1.0).size() != 0:
		push_error("A realtime channel retry fired before its backoff elapsed.")
		quit(1)
		return
	var due_retries: Array[String] = social._take_due_realtime_topic_retries(1.1)
	if due_retries.size() != 1 or due_retries[0] != "chat:direct:retry":
		push_error("A failed active realtime channel was not scheduled for retry.")
		quit(1)
		return
	social._realtime_topics = {"chat:direct:retry": true}
	social._realtime_join_refs = {"chat:direct:retry": "new-ref"}
	social._realtime_ready_topics = {}
	social._schedule_realtime_topic_retry("chat:direct:retry", "new-ref")
	social._leave_realtime_topic("chat:direct:retry")
	if social._realtime_topic_retry_seconds.has("chat:direct:retry"):
		push_error("Leaving a realtime topic did not cancel its pending retry.")
		quit(1)
		return
	social._realtime_topics = {"chat:direct:joined": true}
	social._realtime_join_refs = {"chat:direct:joined": "ci-join-ref"}
	social._realtime_ready_topics = {"chat:direct:joined": true}
	# Stop retrying after the configured limit instead of looping forever.
	social._realtime_topics = {"chat:direct:retry-limit": true}
	social._realtime_join_refs = {"chat:direct:retry-limit": "retry-ref-1"}
	social._realtime_ready_topics = {}
	social._realtime_topic_retry_seconds = {}
	social._realtime_topic_retry_attempts = {}
	for attempt in range(3):
		social._schedule_realtime_topic_retry("chat:direct:retry-limit", "retry-ref-%d" % (attempt + 1))
		if not social._realtime_topic_retry_seconds.has("chat:direct:retry-limit"):
			push_error("A realtime channel retry stopped before reaching its configured limit.")
			quit(1)
			return
		social._take_due_realtime_topic_retries(2.0)
		social._realtime_join_refs["chat:direct:retry-limit"] = "retry-ref-%d" % (attempt + 2)
	social._schedule_realtime_topic_retry("chat:direct:retry-limit", "retry-ref-%d" % 4)
	if social._realtime_topic_retry_seconds.has("chat:direct:retry-limit") or social._realtime_topic_retry_attempts.has("chat:direct:retry-limit"):
		push_error("A realtime channel continued retrying after the configured limit.")
		quit(1)
		return
	# Drop retry entries when the topic is no longer wanted or already has a live join.
	social._realtime_topics = {"chat:direct:active": true}
	social._realtime_join_refs = {"chat:direct:active": "live-ref"}
	social._realtime_topic_retry_seconds = {
		"chat:direct:removed": 0.0,
		"chat:direct:active": 0.0
	}
	var ignored_retries: Array[String] = social._take_due_realtime_topic_retries(0.0)
	if not ignored_retries.is_empty() or not social._realtime_topic_retry_seconds.is_empty():
		push_error("Obsolete or already-joined realtime topics were retried.")
		quit(1)
		return
	social._realtime_topic_retry_seconds = saved_topic_retries
	social._realtime_topic_retry_attempts = saved_topic_retry_attempts
	if social.is_realtime_topic_subscribed("chat:direct:unjoined") or social.is_realtime_topic_subscribed("chat:group:joined"):
		push_error("An unjoined realtime topic was treated as an active subscription.")
		quit(1)
		return
	social._realtime_topics = saved_topics
	social._realtime_join_refs = saved_join_refs
	social._realtime_ready_topics = saved_ready_topics

	print("SOCIAL_TEST_STAGE: realtime_retry_checks_complete")
	if not social.is_valid_player_code("AB12CD34EF"): 
		push_error("A valid ten-character player code was rejected.")
		quit(1)
		return
	if not social.is_valid_invite_id("550e8400-e29b-41d4-a716-446655440000"):
		push_error("A valid UUID invitation id was rejected.")
		quit(1)
		return
	if not social.is_valid_invite_id("550E8400-E29B-41D4-A716-446655440000"):
		push_error("A valid uppercase UUID invitation id was rejected.")
		quit(1)
		return
	if social.is_valid_invite_id("invite-1") or social.is_valid_invite_id("550e8400-e29b-41d4-a716-44665544000"):
		push_error("A malformed invitation id was accepted.")
		quit(1)
		return
	if social.respond_chat_group_invite("invite-1", true):
		push_error("A malformed invitation id was sent to the RPC layer.")
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

	print("SOCIAL_TEST_STAGE: id_validation_complete")
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

	print("SOCIAL_TEST_STAGE: player_code_checks_complete")
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

	print("SOCIAL_TEST_STAGE: group_subscription_checks_complete")
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

	print("SOCIAL_TEST_STAGE: direct_subscription_checks_complete")
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

	print("SOCIAL_TEST_STAGE: chat_input_checks_complete")
	var invitation_script: Script = load("res://scripts/invitation_overlay.gd")
	var invitation_overlay: Control = invitation_script.new()
	root.add_child(invitation_overlay)
	var invitation_now := float(Time.get_unix_time_from_system())
	var capped_deadline := float(invitation_overlay.call("resolve_invitation_expiry", {
		"expires_at": invitation_now + 90.0
	}, invitation_now))
	if capped_deadline > invitation_now + 30.0:
		push_error("A supplied invitation deadline extended the approved 30-second lifetime.")
		quit(1)
		return
	var stale_created_at := Time.get_datetime_string_from_unix_time(int(invitation_now) - 40)
	var stale_deadline := float(invitation_overlay.call("resolve_invitation_expiry", {
		"created_at": stale_created_at
	}, invitation_now))
	if stale_deadline > invitation_now - 9.0:
		push_error("An invitation created more than 30 seconds ago received a fresh lifetime.")
		quit(1)
		return
	var shortened_deadline := invitation_now + 8.0
	var server_shortened := float(invitation_overlay.call("resolve_invitation_expiry", {
		"expires_at": shortened_deadline
	}, invitation_now))
	if not is_equal_approx(server_shortened, shortened_deadline):
		push_error("A shorter server-provided invitation deadline was not preserved.")
		quit(1)
		return
	var already_expired_deadline := invitation_now - 3.0
	var server_expired := float(invitation_overlay.call("resolve_invitation_expiry", {
		"expires_at": already_expired_deadline
	}, invitation_now))
	if not is_equal_approx(server_expired, already_expired_deadline):
		push_error("An already-expired server invitation was extended locally.")
		quit(1)
		return
	var future_created_at := Time.get_datetime_string_from_unix_time(int(invitation_now) + 300)
	var future_timestamp_deadline := float(invitation_overlay.call("resolve_invitation_expiry", {
		"created_at": future_created_at
	}, invitation_now))
	if future_timestamp_deadline > invitation_now + 30.0 or future_timestamp_deadline < invitation_now + 29.0:
		push_error("A future creation timestamp bypassed the local invitation lifetime cap.")
		quit(1)
		return
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
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-account-a-invite",
		"title": "Duplicate invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	if invitation_overlay.get_pending_invitation_count() != 1:
		push_error("A duplicate active invitation was added to the queue.")
		quit(1)
		return
	var expired_count := [0]
	invitation_overlay.invitation_expired.connect(func(_item: Dictionary) -> void:
		expired_count[0] += 1
	)
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-already-expired",
		"title": "Expired invitation",
		"expires_at": float(Time.get_unix_time_from_system()) - 1.0
	})
	if expired_count[0] != 1 or invitation_overlay.get_pending_invitation_count() != 1:
		push_error("An already-expired invitation was queued instead of being rejected.")
		quit(1)
		return
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-account-b-invite",
		"title": "Queued invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-queued-expired",
		"title": "Queued invitation that expires during response",
		"expires_at": float(Time.get_unix_time_from_system()) + 1.0
	})
	# Simulate the accept/decline handler starting its RPC before the active
	# invitation is removed; queued items must stay hidden and keep expiring.
	invitation_overlay.call("set_response_pending", true)
	invitation_overlay.call("_finish_current", true)
	if invitation_overlay.get_pending_invitation_count() != 2 or not invitation_overlay._current.is_empty():
		push_error("Queued invitations became actionable while the previous response was pending.")
		quit(1)
		return
	# Simulate real elapsed wall-clock time, including time spent backgrounded.
	for queued_item in invitation_overlay._queue:
		if str(queued_item.get("invite_id", "")) == "ci-queued-expired":
			queued_item["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	invitation_overlay.call("_tick", 0.0)
	if expired_count[0] != 2 or invitation_overlay.get_pending_invitation_count() != 1 or not invitation_overlay._current.is_empty():
		push_error("A queued invitation did not expire while the previous response was pending.")
		quit(1)
		return
	invitation_overlay.call("set_response_pending", false)
	if invitation_overlay.get_pending_invitation_count() != 1 or str(invitation_overlay.get_current_invitation().get("invite_id", "")) != "ci-account-b-invite":
		push_error("The next unexpired invitation was not shown after the pending response completed.")
		quit(1)
		return
	# The currently displayed invitation must also expire from its absolute
	# deadline, independently of frame delta or app pause duration.
	invitation_overlay._current["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	invitation_overlay.call("_tick", 0.0)
	if expired_count[0] != 3 or invitation_overlay.get_pending_invitation_count() != 0 or invitation_overlay._panel.visible:
		push_error("The active invitation did not expire and close at its absolute deadline.")
		quit(1)
		return
	var accepted_count := [0]
	invitation_overlay.invitation_accepted.connect(func(_item: Dictionary) -> void:
		accepted_count[0] += 1
	)
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-late-tap-invite",
		"title": "Late tap invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	invitation_overlay._current["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	invitation_overlay.call("_finish_current", true)
	if accepted_count[0] != 0 or expired_count[0] != 4 or invitation_overlay.get_pending_invitation_count() != 0 or invitation_overlay._panel.visible:
		push_error("A late accept tap was emitted after the invitation deadline.")
		quit(1)
		return
	var declined_count := [0]
	invitation_overlay.invitation_declined.connect(func(_item: Dictionary) -> void:
		declined_count[0] += 1
	)
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-late-tap-decline-invite",
		"title": "Late tap decline invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	invitation_overlay._current["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	invitation_overlay.call("_finish_current", false)
	if declined_count[0] != 0 or expired_count[0] != 5 or invitation_overlay.get_pending_invitation_count() != 0 or invitation_overlay._panel.visible:
		push_error("A late decline tap was emitted after the invitation deadline.")
		quit(1)
		return
	invitation_overlay.clear_pending_invitations()
	if invitation_overlay.get_pending_invitation_count() != 0 or not invitation_overlay._current.is_empty() or invitation_overlay._panel.visible:
		push_error("A previous account's active or queued invitation survived account cleanup.")
		quit(1)
		return
	print("SOCIAL_TEST_STAGE: invitation_lifecycle_complete")
	print("Social chat input and invitation lifecycle validation tests passed.")
	quit(0)
