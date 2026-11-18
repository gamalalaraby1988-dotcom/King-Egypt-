extends Node3D
## Keeps ambient residents active offline and online, scaling them down as real players populate the city.

const CITIZEN_SCRIPT := preload("res://scripts/virtual_citizen.gd")
const TOTAL_CITIZENS := 50
const FEMALE_COUNT := 25
const ONLINE_POLL_INTERVAL := 1.0
const DENSITY_STEP_INTERVAL := 0.12

var _citizens: Array[CharacterBody3D] = []
var _poll_elapsed := 0.0
var _density_step_elapsed := 0.0
var _online_mode := false
var _nearby_real_player_count := 0
var _visible_target_count := TOTAL_CITIZENS
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_spawn_citizens()
	_refresh_mode()
	_update_density_target()

func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed >= ONLINE_POLL_INTERVAL:
		_poll_elapsed = 0.0
		_refresh_mode()
		_update_density_target()
	_advance_density_transition(delta)

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
		online_ready = bool(chat_manager.get("_realtime_connected"))
	if online_ready != _online_mode:
		_online_mode = online_ready
		# Connecting to the internet alone must never make the city empty.
		# Real-player density is handled separately by set_nearby_real_player_count().

func set_nearby_real_player_count(player_count: int) -> void:
	## Multiplayer presence should call this with the real-player count near this city sector.
	_nearby_real_player_count = maxi(0, player_count)
	_update_density_target()

func _update_density_target() -> void:
	if not _online_mode:
		_visible_target_count = TOTAL_CITIZENS
		return
	var count := _nearby_real_player_count
	if count <= 0:
		_visible_target_count = TOTAL_CITIZENS
	elif count <= 2:
		_visible_target_count = 42
	elif count <= 5:
		_visible_target_count = 32
	elif count <= 9:
		_visible_target_count = 22
	elif count <= 14:
		_visible_target_count = 12
	elif count <= 20:
		_visible_target_count = 5
	else:
		_visible_target_count = 0

func _advance_density_transition(delta: float) -> void:
	_density_step_elapsed += delta
	if _density_step_elapsed < DENSITY_STEP_INTERVAL:
		return
	_density_step_elapsed = 0.0
	var current_visible := 0
	for citizen in _citizens:
		if is_instance_valid(citizen) and citizen.visible:
			current_visible += 1
	if current_visible == _visible_target_count:
		return
	var should_show := current_visible < _visible_target_count
	for citizen in _citizens:
		if not is_instance_valid(citizen) or citizen.visible == should_show:
			continue
		citizen.visible = should_show
		citizen.set_physics_process(should_show)
		if not should_show:
			citizen.velocity = Vector3.ZERO
		break

func get_citizen_count() -> int:
	return _citizens.size()

func get_visible_citizen_count() -> int:
	var count := 0
	for citizen in _citizens:
		if is_instance_valid(citizen) and citizen.visible:
			count += 1
	return count

func is_online_mode() -> bool:
	return _online_mode
