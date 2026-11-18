extends Node3D
## Spawns the 50 ambient residents for offline play and suppresses them
## once the authenticated realtime connection is available.

const CITIZEN_SCRIPT := preload("res://scripts/virtual_citizen.gd")
const TOTAL_CITIZENS := 50
const FEMALE_COUNT := 25
const ONLINE_POLL_INTERVAL := 1.0

var _citizens: Array[CharacterBody3D] = []
var _poll_elapsed := 0.0
var _online_mode := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_spawn_citizens()
	_refresh_mode()

func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed < ONLINE_POLL_INTERVAL:
		return
	_poll_elapsed = 0.0
	_refresh_mode()

func _spawn_citizens() -> void:
	var female_created := 0
	var male_created := 0
	for index in range(TOTAL_CITIZENS):
		var is_female := female_created < FEMALE_COUNT and (male_created >= TOTAL_CITIZENS - FEMALE_COUNT or index % 2 == 0)
		var gender := "female" if is_female else "male"
		if is_female:
			female_created += 1
		else:
			male_created += 1
		var citizen := CharacterBody3D.new()
		citizen.name = "OfflineCitizen_%02d" % (index + 1)
		citizen.set_script(CITIZEN_SCRIPT)
		citizen.set("citizen_id", "offline_npc_%02d_%s" % [index + 1, "f" if is_female else "m"])
		citizen.set("gender", gender)
		citizen.set("roam_radius", _rng.randf_range(8.0, 15.0))
		citizen.position = _choose_spawn_position(index)
		add_child(citizen)
		_citizens.append(citizen)

func _choose_spawn_position(index: int) -> Vector3:
	# Distribute residents over five public-city sectors, away from the main road axes.
	var sectors := [
		Vector3(-48.0, 0.0, -48.0),
		Vector3(48.0, 0.0, -48.0),
		Vector3(-48.0, 0.0, 48.0),
		Vector3(48.0, 0.0, 48.0),
		Vector3(0.0, 0.0, 54.0)
	]
	var center: Vector3 = sectors[index % sectors.size()]
	for attempt in range(12):
		var candidate := center + Vector3(_rng.randf_range(-8.0, 8.0), 0.0, _rng.randf_range(-8.0, 8.0))
		if absf(candidate.x) > 9.0 and absf(candidate.z) > 9.0:
			return candidate
	return center

func _refresh_mode() -> void:
	var online_ready := false
	var chat_manager := get_node_or_null("/root/SocialChatManager")
	if is_instance_valid(chat_manager):
		var connected_value: Variant = chat_manager.get("_realtime_connected")
		online_ready = bool(connected_value)
	if online_ready == _online_mode:
		return
	_online_mode = online_ready
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		citizen.visible = not _online_mode
		citizen.set_physics_process(not _online_mode)
		if _online_mode:
			citizen.velocity = Vector3.ZERO
		else:
			citizen.set_physics_process(true)

func get_citizen_count() -> int:
	return _citizens.size()

func is_online_mode() -> bool:
	return _online_mode
