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
var _sector_player_counts: Dictionary = {}
var _sector_visible_targets: Dictionary = {}
var _sector_ids := ["north_west", "north_east", "south_west", "south_east", "south_center"]
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_spawn_citizens()
	var chat_manager := get_node_or_null("/root/SocialChatManager")
	if is_instance_valid(chat_manager):
		if chat_manager.has_signal("city_presence_counts_changed") and not chat_manager.city_presence_counts_changed.is_connected(_on_city_presence_counts_changed):
			chat_manager.city_presence_counts_changed.connect(_on_city_presence_counts_changed)
		if chat_manager.has_method("get_city_presence_counts"):
			_on_city_presence_counts_changed(chat_manager.get_city_presence_counts())
	_refresh_mode()
	_update_density_targets()

func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed >= ONLINE_POLL_INTERVAL:
		_poll_elapsed = 0.0
		_refresh_mode()
		_update_density_targets()
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
		citizen.set("roam_radius", _rng.randf_range(4.5, 6.0))
		citizen.set("city_sector", _sector_ids[index % _sector_ids.size()])
		citizen.position = _choose_spawn_position(index)
		add_child(citizen)
		_citizens.append(citizen)

func _choose_spawn_position(index: int) -> Vector3:
	# These five gathering areas sit in open pedestrian pockets between the
	# prototype's road grid and 10x10 building footprints (not inside buildings).
	var sectors := [
		Vector3(-34.0, 0.0, -34.0),
		Vector3(34.0, 0.0, -34.0),
		Vector3(-34.0, 0.0, 34.0),
		Vector3(34.0, 0.0, 34.0),
		Vector3(0.0, 0.0, 34.0)
	]
	var sector_index := index % sectors.size()
	var slot := int(index / sectors.size())
	var x_offset := (float(slot % 5) - 2.0) * 1.45
	var z_offset := -1.15 if slot < 5 else 1.15
	var center: Vector3 = sectors[sector_index]
	return center + Vector3(x_offset + _rng.randf_range(-0.2, 0.2), 0.0, z_offset + _rng.randf_range(-0.2, 0.2))

func _refresh_mode() -> void:
	var online_ready := false
	var chat_manager := get_node_or_null("/root/SocialChatManager")
	if is_instance_valid(chat_manager):
		online_ready = bool(chat_manager.get("_realtime_connected"))
	if online_ready != _online_mode:
		_online_mode = online_ready
		# Connecting to the internet alone must never make the city empty.
		# Real-player density is driven by authenticated Realtime Presence counts for each coarse city sector.

func _on_city_presence_counts_changed(counts: Dictionary) -> void:
	_sector_player_counts = counts.duplicate(true)
	_update_density_targets()

func _update_density_targets() -> void:
	for sector in _sector_ids:
		var target := 10
		if _online_mode:
			var count := maxi(0, int(_sector_player_counts.get(sector, 0)))
			if count <= 0:
				target = 10
			elif count <= 2:
				target = 8
			elif count <= 5:
				target = 6
			elif count <= 9:
				target = 4
			elif count <= 14:
				target = 2
			elif count <= 20:
				target = 1
			else:
				target = 0
		_sector_visible_targets[sector] = target

func _advance_density_transition(delta: float) -> void:
	_density_step_elapsed += delta
	if _density_step_elapsed < DENSITY_STEP_INTERVAL:
		return
	_density_step_elapsed = 0.0
	for sector in _sector_ids:
		var sector_citizens: Array[CharacterBody3D] = []
		var visible_count := 0
		for citizen in _citizens:
			if not is_instance_valid(citizen) or str(citizen.get("city_sector")) != sector:
				continue
			sector_citizens.append(citizen)
			if citizen.visible:
				visible_count += 1
		var target := int(_sector_visible_targets.get(sector, 10))
		if visible_count == target:
			continue
		var should_show := visible_count < target
		for citizen in sector_citizens:
			if citizen.visible == should_show:
				continue
			citizen.visible = should_show
			# Disable inherited processing too, so the avatar's child animation
			# does not keep consuming frame time while this citizen is hidden.
			citizen.process_mode = Node.PROCESS_MODE_INHERIT if should_show else Node.PROCESS_MODE_DISABLED
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

func get_sector_visible_citizen_count(sector: String) -> int:
	var count := 0
	for citizen in _citizens:
		if is_instance_valid(citizen) and citizen.visible and str(citizen.get("city_sector")) == sector:
			count += 1
	return count

func is_online_mode() -> bool:
	return _online_mode
