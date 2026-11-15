extends SceneTree

func _initialize() -> void:
	call_deferred("_run_auth_session_tests")

func _run_auth_session_tests() -> void:
	await process_frame
	var auth := root.get_node_or_null("AuthManager")
	if auth == null:
		push_error("AuthManager autoload did not initialize.")
		quit(1)
		return

	var changed_events: Array[Dictionary] = []
	auth.session_changed.connect(func(previous_uid: String, current_uid: String, generation: int) -> void:
		changed_events.append({
			"previous_uid": previous_uid,
			"current_uid": current_uid,
			"generation": generation
		})
	)

	auth._authenticated_user_id = "00000000-0000-4000-8000-000000000001"
	auth._authenticated_email = "ci-session-a@example.invalid"
	auth._access_token = "ci-access-token"
	auth._refresh_token = "ci-refresh-token"
	var first_generation: int = auth.get_session_generation()
	auth.session_changed.emit("", "00000000-0000-4000-8000-000000000001", first_generation)
	var data_session := root.get_node_or_null("AccountDataSession")
	var wallet := root.get_node_or_null("WalletManager")
	var social := root.get_node_or_null("SocialChatManager")
	if social == null or not social._request_session_is_current("00000000-0000-4000-8000-000000000001", first_generation):
		push_error("Social RPC did not recognize the active account session.")
		quit(1)
		return
	if data_session == null or wallet == null or not data_session.is_ready() or not wallet.initialized:
		push_error("Account data session did not activate the authenticated profile.")
		quit(1)
		return
	var account_profile_path := "user://accounts/00000000-0000-4000-8000-000000000001/profile.cfg"
	if wallet.profile_path != account_profile_path:
		push_error("Wallet did not switch to the UID-scoped profile path.")
		quit(1)
		return
	if not wallet.credit("ci_session_credit", "gems", 1, "session test"):
		push_error("Wallet rejected a write in the current authenticated session.")
		quit(1)
		return

	if not auth.is_session_current("00000000-0000-4000-8000-000000000001", first_generation):
		push_error("Current authenticated session was not recognized.")
		quit(1)
		return

	auth._advance_session_generation()
	if auth.is_session_current("00000000-0000-4000-8000-000000000001", first_generation):
		push_error("A stale session generation was accepted.")
		quit(1)
		return
	if social._request_session_is_current("00000000-0000-4000-8000-000000000001", first_generation):
		push_error("Social RPC accepted a response from a stale account generation.")
		quit(1)
		return
	if wallet.get_balances() != {"money": 0, "chips": 0, "gems": 0} or not wallet.get_recent_transactions().is_empty() or wallet.has_transaction("ci_session_credit"):
		push_error("Wallet reads exposed cached balances or receipts from a stale session.")
		quit(1)
		return
	if not auth.is_session_current("00000000-0000-4000-8000-000000000001", auth.get_session_generation()):
		push_error("The current session was rejected after generation advance.")
		quit(1)
		return

	if data_session.is_ready() or wallet.credit("ci_stale_session_credit", "gems", 1, "stale session test"):
		push_error("A stale account generation was allowed to access wallet storage.")
		quit(1)
		return
	auth.session_changed.emit("00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000001", auth.get_session_generation())
	if not social._request_session_is_current("00000000-0000-4000-8000-000000000001", auth.get_session_generation()):
		push_error("Social RPC rejected the rebound current account session.")
		quit(1)
		return
	if not data_session.is_ready() or not wallet.initialized:
		push_error("Account data session did not rebind after a valid generation change.")
		quit(1)
		return

	var achievement_script: Script = load("res://scripts/achievement_manager.gd")
	var achievement_manager: Node = achievement_script.new()
	root.add_child(achievement_manager)
	await process_frame
	var expected_achievement_path := "user://accounts/00000000-0000-4000-8000-000000000001/achievements.cfg"
	if achievement_manager._save_path != expected_achievement_path:
		push_error("Achievement progress did not use the active account's private save path.")
		quit(1)
		return
	achievement_manager.walked_meters = 12.5
	achievement_manager._save_state()
	if not FileAccess.file_exists(expected_achievement_path):
		push_error("Account-scoped achievement progress was not saved.")
		quit(1)
		return
	var achievement_file_before_signout := FileAccess.get_file_as_bytes(expected_achievement_path)

	# Profile names belong to the authenticated account; device preferences stay separate.
	var legacy_profile_path := "user://kings_city_profile.cfg"
	var legacy_profile_existed := FileAccess.file_exists(legacy_profile_path)
	var legacy_profile_snapshot := FileAccess.get_file_as_bytes(legacy_profile_path) if legacy_profile_existed else PackedByteArray()
	var profile_settings_script: Script = load("res://scripts/profile_settings.gd")
	var profile_settings: Node = profile_settings_script.new()
	root.add_child(profile_settings)
	await process_frame
	if profile_settings.name_input.text != "لاعب جديد":
		push_error("A fresh account unexpectedly inherited a profile name.")
		quit(1)
		return
	profile_settings.name_input.text = "CI Account A"
	profile_settings._save_settings()
	var first_profile_config := ConfigFile.new()
	if first_profile_config.load(data_session.get_profile_path()) != OK or str(first_profile_config.get_value("profile", "player_name", "")) != "CI Account A":
		push_error("Profile settings did not save the name to the active account profile.")
		quit(1)
		return

	# A realtime socket remains bound to the exact identity and generation that opened it.
	social._realtime_session_user_id = "00000000-0000-4000-8000-000000000001"
	social._realtime_session_generation = auth.get_session_generation()
	if not social._realtime_session_is_current():
		push_error("Realtime socket did not recognize its owning authenticated session.")
		quit(1)
		return

	# Switch to a second authenticated UID and verify its achievement file is isolated.
	auth._advance_session_generation()
	auth._authenticated_user_id = "00000000-0000-4000-8000-000000000002"
	auth._authenticated_email = "ci-session-b@example.invalid"
	auth.session_changed.emit("00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000002", auth.get_session_generation())
	if social._realtime_session_is_current() or not social._realtime_session_user_id.is_empty() or social._realtime_session_generation != -1:
		push_error("Realtime socket retained account A ownership after switching to account B.")
		quit(1)
		return
	# If a stale socket is detected outside the auth-change signal, it must not replay A's topics for B.
	social._realtime_topics = {
		"chat:public:messages": true,
		"chat:group:account-a-group": true,
		"chat:direct:account-a-direct": true,
		"chat:invites:ABCDEFGHIJ": true
	}
	social._realtime_join_refs = {"chat:group:account-a-group": "old-ref"}
	social._realtime_player_code = "ABCDEFGHIJ"
	social._realtime_group_id = "account-a-group"
	social._realtime_direct_id = "account-a-direct"
	social._realtime_session_user_id = "00000000-0000-4000-8000-000000000001"
	social._realtime_session_generation = first_generation
	social._realtime_socket = WebSocketPeer.new()
	social._process(0.0)
	if social._realtime_socket != null or not social._realtime_topics.is_empty() or not social._realtime_join_refs.is_empty() or not social._realtime_player_code.is_empty() or not social._realtime_group_id.is_empty() or not social._realtime_direct_id.is_empty():
		push_error("A stale realtime socket replayed account A subscriptions or identity after account B became active.")
		quit(1)
		return

	# A delayed callback from A must not consume or overwrite B's active RPC slot.
	var stale_rpc_request := HTTPRequest.new()
	var current_rpc_request := HTTPRequest.new()
	root.add_child(stale_rpc_request)
	root.add_child(current_rpc_request)
	social._http = current_rpc_request
	social._pending_action = "friends_list"
	social._pending_user_id = "00000000-0000-4000-8000-000000000002"
	social._pending_session_generation = auth.get_session_generation()
	social._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer(), "daily_chest_claim", "00000000-0000-4000-8000-000000000001", first_generation, stale_rpc_request)
	if social._http != current_rpc_request or social._pending_action != "friends_list" or social._pending_user_id != "00000000-0000-4000-8000-000000000002":
		push_error("A delayed RPC callback from account A consumed account B's active request.")
		quit(1)
		return
	social._http = null
	social._pending_action = ""
	social._pending_user_id = ""
	social._pending_session_generation = -1
	current_rpc_request.queue_free()
	var second_achievement_path := "user://accounts/00000000-0000-4000-8000-000000000002/achievements.cfg"
	if achievement_manager._save_path != second_achievement_path or achievement_manager.walked_meters != 0.0:
		push_error("A second account inherited achievement progress from the first account.")
		quit(1)
		return
	if profile_settings.name_input.text != "لاعب جديد":
		push_error("A second account inherited the first account's profile name.")
		quit(1)
		return
	profile_settings.name_input.text = "CI Account B"
	profile_settings._save_settings()
	var second_profile_config := ConfigFile.new()
	if second_profile_config.load(data_session.get_profile_path()) != OK or str(second_profile_config.get_value("profile", "player_name", "")) != "CI Account B":
		push_error("Profile settings did not save the second account's name independently.")
		quit(1)
		return
	achievement_manager.walked_meters = 3.5
	achievement_manager._save_state()
	if not FileAccess.file_exists(second_achievement_path):
		push_error("Second account achievement progress was not saved separately.")
		quit(1)
		return

	# Return to the first UID and verify its own progress is restored, not account B's.
	auth._advance_session_generation()
	auth._authenticated_user_id = "00000000-0000-4000-8000-000000000001"
	auth._authenticated_email = "ci-session-a@example.invalid"
	auth.session_changed.emit("00000000-0000-4000-8000-000000000002", "00000000-0000-4000-8000-000000000001", auth.get_session_generation())
	if achievement_manager._save_path != expected_achievement_path or achievement_manager.walked_meters != 12.5:
		push_error("Returning to the first account did not restore its own achievement progress.")
		quit(1)
		return
	if profile_settings.name_input.text != "CI Account A":
		push_error("Returning to the first account did not restore its own profile name.")
		quit(1)
		return
	var legacy_achievement_path := "user://kings_city_achievements.cfg"
	var legacy_achievement_existed := FileAccess.file_exists(legacy_achievement_path)
	var legacy_achievement_snapshot := FileAccess.get_file_as_bytes(legacy_achievement_path) if legacy_achievement_existed else PackedByteArray()

	var mission_manager_script: Script = load("res://scripts/mission_manager.gd")
	var mission_manager: Node = mission_manager_script.new()
	mission_manager.owned_outfits = ["default", "ci_previous_account_outfit"]
	mission_manager.daily_chest_reward_configured = true
	mission_manager.daily_chest_server_claimed = true
	mission_manager.daily_chest_reward_day = "2099-01-01"
	mission_manager._daily_chest_request_action = "daily_chest_claim"
	mission_manager._daily_chest_request_uid = "00000000-0000-4000-8000-000000000001"
	mission_manager._daily_chest_request_generation = auth.get_session_generation()
	mission_manager.achievement_totals = {"jobs": 7, "missions": 4, "daily_claims": 2}
	mission_manager.reward_receipts = {"ci_private_reward": "claimed"}
	mission_manager.daily_task_progress = {"2099-01-01": {"ci_task": 9}}
	var active_mission_fixture := Node3D.new()
	var active_job_fixture := Node3D.new()
	mission_manager.active_mission = active_mission_fixture
	mission_manager.active_job = active_job_fixture
	mission_manager.active_job_target = Vector3(1, 2, 3)
	mission_manager.active_job_reward = {"money": 500}
	mission_manager.job_running = true
	mission_manager.mission_running = true
	mission_manager.active_rental_transaction_id = "ci_previous_account_rental"

	# Seed account-bound realtime state and prove sign-out clears every subscription.
	social._realtime_topics = {
		"chat:public:messages": true,
		"chat:group:ci-group": true,
		"chat:direct:ci-direct": true,
		"chat:invites:ABCDEFGHIJ": true
	}
	social._realtime_join_refs = {"chat:group:ci-group": "ci-ref"}
	social._realtime_player_code = "ABCDEFGHIJ"
	social._realtime_group_id = "ci-group"
	social._realtime_direct_id = "ci-direct"
	social._pending_action = "direct_read"
	social._pending_user_id = "00000000-0000-4000-8000-000000000001"
	social._pending_session_generation = auth.get_session_generation()
	auth.clear_session()
	if not achievement_manager._save_path.is_empty() or achievement_manager.walked_meters != 0.0:
		push_error("Achievement progress retained the previous account after sign-out.")
		quit(1)
		return
	achievement_manager._check_all()
	achievement_manager.record_job_completed("ci_after_signout")
	if not achievement_manager.unlocked.is_empty() or achievement_manager.totals != {"jobs": 0, "missions": 0, "daily_claims": 0}:
		push_error("Achievement manager exposed or updated account progress after sign-out.")
		quit(1)
		return
	achievement_manager.walked_meters = 999.0
	achievement_manager._save_state()
	if FileAccess.get_file_as_bytes(expected_achievement_path) != achievement_file_before_signout:
		push_error("Achievement manager wrote previous-account data after sign-out.")
		quit(1)
		return
	if FileAccess.file_exists(legacy_achievement_path) != legacy_achievement_existed:
		push_error("Achievement manager created or removed the legacy shared progress file.")
		quit(1)
		return
	if legacy_achievement_existed and FileAccess.get_file_as_bytes(legacy_achievement_path) != legacy_achievement_snapshot:
		push_error("Achievement manager modified the legacy shared progress file.")
		quit(1)
		return
	if profile_settings.name_input.text != "لاعب جديد" or profile_settings.name_input.editable:
		push_error("Profile settings retained the previous account name after sign-out.")
		quit(1)
		return
	if FileAccess.file_exists(legacy_profile_path) != legacy_profile_existed:
		push_error("Profile settings created or removed the legacy shared profile file.")
		quit(1)
		return
	if legacy_profile_existed and FileAccess.get_file_as_bytes(legacy_profile_path) != legacy_profile_snapshot:
		push_error("Profile settings modified the legacy shared profile file.")
		quit(1)
		return
	if not social._pending_action.is_empty() or not social._pending_user_id.is_empty() or social._pending_session_generation != -1:
		push_error("Pending social RPC retained the signed-out account session.")
		quit(1)
		return
	if wallet.get_balances() != {"money": 0, "chips": 0, "gems": 0} or not wallet.get_recent_transactions().is_empty() or wallet.has_transaction("ci_session_credit"):
		push_error("Wallet reads exposed the previous account after sign-out.")
		quit(1)
		return
	if not social._realtime_topics.is_empty() or not social._realtime_join_refs.is_empty() or not social._realtime_player_code.is_empty() or not social._realtime_group_id.is_empty() or not social._realtime_direct_id.is_empty():
		push_error("Realtime subscriptions or account identity survived sign-out.")
		quit(1)
		return
	mission_manager._on_account_session_invalidated("00000000-0000-4000-8000-000000000001", auth.get_session_generation())
	mission_manager._on_daily_chest_rpc_completed("daily_chest_claim", {
		"status": "claimed",
		"reward_day": "2099-01-01",
		"reward_cash": 999,
		"reward_chips": 50,
		"reward_xp": 100
	})
	if mission_manager.money != 0 or mission_manager.daily_chest_server_claimed or mission_manager.has_reward_receipt("daily_chest_2099-01-01"):
		push_error("A late daily chest response changed state after the account session ended.")
		quit(1)
		return
	if mission_manager.active_mission != null or mission_manager.active_job != null or mission_manager.job_running or mission_manager.mission_running or mission_manager.active_job_target != Vector3.ZERO or not mission_manager.active_job_reward.is_empty() or not mission_manager.active_rental_transaction_id.is_empty():
		push_error("An active mission, job, or rental from the previous account survived session invalidation.")
		quit(1)
		return
	active_mission_fixture.free()
	active_job_fixture.free()
	if mission_manager.owned_outfits != ["default"] or mission_manager.daily_chest_reward_configured or mission_manager.daily_chest_server_claimed or not mission_manager.daily_chest_reward_day.is_empty():
		push_error("Mission state from the previous account remained after session invalidation.")
		quit(1)
		return
	if mission_manager.get_achievement_totals() != {"jobs": 0, "missions": 0, "daily_claims": 0}:
		push_error("Achievement totals from the previous account were exposed after sign-out.")
		quit(1)
		return
	if mission_manager.has_reward_receipt("ci_private_reward"):
		push_error("A previous-account reward receipt remained readable after sign-out.")
		quit(1)
		return
	if mission_manager.get_daily_task_progress("2099-01-01", "ci_task") != 0:
		push_error("Daily task progress from the previous account remained readable after sign-out.")
		quit(1)
		return
	if auth.is_authenticated():
		push_error("clear_session did not clear authentication.")
		quit(1)
		return
	var signed_out_profile_settings: Node = profile_settings_script.new()
	root.add_child(signed_out_profile_settings)
	await process_frame
	if signed_out_profile_settings.name_input.editable:
		push_error("Profile name editing was enabled without an authenticated account.")
		quit(1)
		return
	signed_out_profile_settings.free()
	signed_out_profile_settings = null
	if auth.is_session_current("00000000-0000-4000-8000-000000000001", auth.get_session_generation()):
		push_error("A cleared session was still considered current.")
		quit(1)
		return
	if changed_events.size() != 5:
		push_error("Session change and invalidation signals did not match the expected sign-in, account-switch, and sign-out sequence.")
		quit(1)
		return
	if changed_events[4].get("previous_uid", "") != "00000000-0000-4000-8000-000000000001" or changed_events[4].get("current_uid", "") != "":
		push_error("Session invalidation signal contained incorrect account identities.")
		quit(1)
		return

	profile_settings.free()
	profile_settings = null
	profile_settings_script = null
	achievement_manager.free()
	achievement_manager = null
	achievement_script = null
	mission_manager.free()
	mission_manager = null
	mission_manager_script = null
	await process_frame
	print("Auth session generation and invalidation tests passed.")
	quit(0)
