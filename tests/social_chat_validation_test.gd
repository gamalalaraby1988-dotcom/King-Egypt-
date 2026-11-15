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

	print("Social chat input validation tests passed.")
	quit(0)
