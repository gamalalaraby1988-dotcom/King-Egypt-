extends SceneTree

const Policy = preload("res://scripts/city_session_policy.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var candidates := [
		{"instance_id": "cairo-a", "region": "eg-cairo", "player_count": 48, "capacity": 64},
		{"instance_id": "cairo-b", "region": "eg-cairo", "player_count": 12, "capacity": 32},
		{"instance_id": "alex-a", "region": "eg-alex", "player_count": 1, "capacity": 64}
	]

	var balanced := Policy.select_instance(candidates, "eg-cairo")
	_expect(balanced.get("status") == Policy.STATUS_ASSIGNED, "an eligible region should receive an assignment")
	_expect(balanced.get("instance_id") == "cairo-b", "the least occupied eligible session should be selected")

	var party := Policy.select_instance(candidates, "eg-cairo", "cairo-a", 4)
	_expect(party.get("status") == Policy.STATUS_ASSIGNED, "a party should remain in its existing session when capacity allows")
	_expect(party.get("instance_id") == "cairo-a", "party affinity should take priority over load balancing")

	var full_party := Policy.select_instance(candidates, "eg-cairo", "cairo-a", 20)
	_expect(full_party.get("status") == Policy.STATUS_PARTY_SESSION_UNAVAILABLE, "a party must not be silently split when its session is full")

	var no_region := Policy.select_instance(candidates, "eg-giza")
	_expect(no_region.get("status") == Policy.STATUS_NO_CAPACITY, "a region without available sessions should return no_capacity")

	var no_room := Policy.select_instance([
		{"instance_id": "full", "region": "eg-cairo", "player_count": 32, "capacity": 32}
	], "eg-cairo", "", 1)
	_expect(no_room.get("status") == Policy.STATUS_NO_CAPACITY, "a full session must not accept another player")

	var tie := Policy.select_instance([
		{"instance_id": "z-session", "region": "eg-cairo", "player_count": 10, "capacity": 20},
		{"instance_id": "a-session", "region": "eg-cairo", "player_count": 5, "capacity": 10}
	], "eg-cairo")
	_expect(tie.get("instance_id") == "a-session", "equal occupancy ratios must use a stable lexical tie-break")

	var invalid := Policy.select_instance([
		{"instance_id": "bad", "region": "eg-cairo", "player_count": -1, "capacity": 64},
		{"instance_id": "bad-capacity", "region": "eg-cairo", "player_count": 0, "capacity": 100}
	], "eg-cairo")
	_expect(invalid.get("status") == Policy.STATUS_NO_CAPACITY, "invalid directory records must be ignored")

	var invalid_party := Policy.select_instance(candidates, "eg-cairo", "", 0)
	_expect(invalid_party.get("status") == Policy.STATUS_NO_CAPACITY, "invalid party sizes must be rejected")

	if _failed:
		push_error("Smart city session policy tests failed: %d assertion(s)." % _failed)
		quit(1)
		return
	print("Smart city session policy tests passed.")
	quit(0)


var _failed := 0


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed += 1
	push_error(message)
