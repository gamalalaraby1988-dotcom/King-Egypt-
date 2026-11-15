extends SceneTree

func _initialize() -> void:
	call_deferred("_run_invitation_overlay_tests")

func _run_invitation_overlay_tests() -> void:
	var overlay_script := load("res://scripts/invitation_overlay.gd") as Script
	if overlay_script == null:
		push_error("Unified invitation overlay script did not load.")
		quit(1)
		return
	var overlay := Control.new()
	overlay.set_script(overlay_script)
	root.add_child(overlay)
	await process_frame

	var expiry_reference := 2000000000.0
	var capped_expiry := float(overlay.call("resolve_invitation_expiry", {
		"expires_at": expiry_reference + 90.0
	}, expiry_reference))
	if not is_equal_approx(capped_expiry, expiry_reference + 30.0):
		push_error("A supplied deadline extended an invitation beyond the approved 30-second lifetime.")
		quit(1)
		return
	var shortened_expiry := float(overlay.call("resolve_invitation_expiry", {
		"expires_at": expiry_reference + 12.0
	}, expiry_reference))
	if not is_equal_approx(shortened_expiry, expiry_reference + 12.0):
		push_error("A shorter supplied invitation deadline was not preserved.")
		quit(1)
		return
	var future_created_at := Time.get_datetime_string_from_unix_time(int(expiry_reference + 60.0))
	var future_timestamp_expiry := float(overlay.call("resolve_invitation_expiry", {
		"created_at": future_created_at
	}, expiry_reference))
	if not is_equal_approx(future_timestamp_expiry, expiry_reference + 30.0):
		push_error("A future creation timestamp incorrectly extended the invitation lifetime.")
		quit(1)
		return

	var expired_ids: Array[String] = []
	var accepted_ids: Array[String] = []
	var declined_ids: Array[String] = []
	overlay.connect("invitation_expired", func(item: Dictionary) -> void:
		expired_ids.append(str(item.get("invite_id", "")))
	)
	overlay.connect("invitation_accepted", func(item: Dictionary) -> void:
		accepted_ids.append(str(item.get("invite_id", "")))
	)
	overlay.connect("invitation_declined", func(item: Dictionary) -> void:
		declined_ids.append(str(item.get("invite_id", "")))
		overlay.call("set_response_pending", true)
	)

	var now := float(Time.get_unix_time_from_system())
	overlay.call("enqueue_invitation", {
		"invite_id": "group-1",
		"type": "group_invite",
		"title": "دعوة مجموعة",
		"body": "اختبار",
		"expires_at": now + 30.0
})
	overlay.call("enqueue_invitation", {
		"invite_id": "apartment-1",
		"type": "apartment_invite",
		"title": "دعوة شقة",
		"body": "اختبار",
		"expires_at": now + 60.0
})
	var current_invitation: Dictionary = overlay.call("get_current_invitation")
	if str(current_invitation.get("invite_id", "")) != "group-1":
		push_error("The first invitation was not displayed first.")
		quit(1)
		return
	if int(overlay.call("get_pending_invitation_count")) != 2:
		push_error("The unified invitation queue did not retain both invitations.")
		quit(1)
		return

	# Simulate the app being suspended beyond the invitation deadline.
	var suspended_now := float(Time.get_unix_time_from_system())
	var active_after_suspend: Dictionary = overlay.get("_current")
	active_after_suspend["expires_at"] = suspended_now - 1.0
	overlay.set("_current", active_after_suspend)
	overlay.call("_tick", 0.0)
	if expired_ids != ["group-1"]:
		push_error("The first invitation did not expire after its 30-second window.")
		quit(1)
		return
	current_invitation = overlay.call("get_current_invitation")
	if str(current_invitation.get("invite_id", "")) != "apartment-1":
		push_error("The next invitation did not appear after the first expired.")
		quit(1)
		return

	overlay.call("_finish_current", true)
	if accepted_ids != ["apartment-1"]:
		push_error("The unified invitation accept action was not emitted.")
		quit(1)
		return
	if int(overlay.call("get_pending_invitation_count")) != 0:
		push_error("The invitation queue was not cleared after completion.")
		quit(1)
		return

	var decline_now := float(Time.get_unix_time_from_system())
	overlay.call("enqueue_invitation", {
		"invite_id": "group-decline",
		"type": "group_invite",
		"title": "دعوة مجموعة",
		"body": "اختبار الرفض",
		"expires_at": decline_now + 30.0
	})
	overlay.call("enqueue_invitation", {
		"invite_id": "apartment-after-decline",
		"type": "apartment_invite",
		"title": "دعوة شقة",
		"body": "اختبار انتهاء المهلة أثناء انتظار الرد",
		"expires_at": decline_now + 10.0
	})
	overlay.call("enqueue_invitation", {
		"invite_id": "group-after-wait",
		"type": "group_invite",
		"title": "دعوة مجموعة",
		"body": "اختبار متابعة الطابور بعد حذف الدعوة المنتهية",
		"expires_at": decline_now + 60.0
	})
	overlay.call("_finish_current", false)
	if declined_ids != ["group-decline"]:
		push_error("The unified invitation decline action was not emitted exactly once.")
		quit(1)
		return
	current_invitation = overlay.call("get_current_invitation")
	if not current_invitation.is_empty():
		push_error("The next invitation appeared before the server response completed.")
		quit(1)
		return
	if int(overlay.call("get_pending_invitation_count")) != 2:
		push_error("Both queued invitations were not retained while the decline response was pending.")
		quit(1)
		return
	# Expire the first queued invitation by its wall-clock deadline while
	# the server response is pending; frame delta is deliberately zero.
	var queued_items: Array = overlay.get("_queue")
	var queued_expired: Dictionary = queued_items[0]
	queued_expired["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	queued_items[0] = queued_expired
	overlay.set("_queue", queued_items)
	overlay.call("_tick", 0.0)
	overlay.call("set_response_pending", false)
	if expired_ids != ["group-1", "apartment-after-decline"]:
		push_error("An invitation that expired while waiting for the server response was not discarded.")
		quit(1)
		return
	current_invitation = overlay.call("get_current_invitation")
	if str(current_invitation.get("invite_id", "")) != "group-after-wait":
		push_error("The queue did not advance past an expired invitation after the server response completed.")
		quit(1)
		return

	print("Unified invitation queue, accept, decline, response serialization, and expiry tests passed.")
	quit(0)
