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

	auth._authenticated_user_id = "ci-session-user-a"
	auth._authenticated_email = "ci-session-a@example.invalid"
	auth._access_token = "ci-access-token"
	auth._refresh_token = "ci-refresh-token"
	var first_generation: int = auth.get_session_generation()
	if not auth.is_session_current("ci-session-user-a", first_generation):
		push_error("Current authenticated session was not recognized.")
		quit(1)
		return

	auth._advance_session_generation()
	if auth.is_session_current("ci-session-user-a", first_generation):
		push_error("A stale session generation was accepted.")
		quit(1)
		return
	if not auth.is_session_current("ci-session-user-a", auth.get_session_generation()):
		push_error("The current session was rejected after generation advance.")
		quit(1)
		return

	auth.clear_session()
	if auth.is_authenticated():
		push_error("clear_session did not clear authentication.")
		quit(1)
		return
	if auth.is_session_current("ci-session-user-a", auth.get_session_generation()):
		push_error("A cleared session was still considered current.")
		quit(1)
		return
	if changed_events.size() != 1:
		push_error("Session invalidation signal was not emitted exactly once.")
		quit(1)
		return
	if changed_events[0].get("previous_uid", "") != "ci-session-user-a" or changed_events[0].get("current_uid", "") != "":
		push_error("Session invalidation signal contained incorrect account identities.")
		quit(1)
		return

	print("Auth session generation and invalidation tests passed.")
	quit(0)
