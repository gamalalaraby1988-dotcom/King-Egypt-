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

	var mission_manager_script: Script = load("res://scripts/mission_manager.gd")
	var mission_manager: Node = mission_manager_script.new()
	mission_manager.owned_outfits = ["default", "ci_previous_account_outfit"]
	mission_manager.daily_chest_reward_configured = true
	mission_manager.daily_chest_server_claimed = true
	mission_manager.daily_chest_reward_day = "2099-01-01"

	auth.clear_session()
	mission_manager._on_account_session_invalidated("00000000-0000-4000-8000-000000000001", auth.get_session_generation())
	if mission_manager.owned_outfits != ["default"] or mission_manager.daily_chest_reward_configured or mission_manager.daily_chest_server_claimed or not mission_manager.daily_chest_reward_day.is_empty():
		push_error("Mission state from the previous account remained after session invalidation.")
		quit(1)
		return
	if auth.is_authenticated():
		push_error("clear_session did not clear authentication.")
		quit(1)
		return
	if auth.is_session_current("00000000-0000-4000-8000-000000000001", auth.get_session_generation()):
		push_error("A cleared session was still considered current.")
		quit(1)
		return
	if changed_events.size() != 3:
		push_error("Session invalidation signal was not emitted exactly once.")
		quit(1)
		return
	if changed_events[2].get("previous_uid", "") != "00000000-0000-4000-8000-000000000001" or changed_events[2].get("current_uid", "") != "":
		push_error("Session invalidation signal contained incorrect account identities.")
		quit(1)
		return

	mission_manager.free()
	mission_manager = null
	mission_manager_script = null
	await process_frame
	print("Auth session generation and invalidation tests passed.")
	quit(0)
