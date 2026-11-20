extends Node3D
## توزيع 50 شخصية افتراضية فقط في نقاط المدينة.
## يعاد استخدام AvatarVisual نفسه؛ لا توجد مجسمات أو خامات شخصية جديدة.
## للحفاظ على أداء Android لا تُنشأ إلا الشخصيات الأقرب للاعب (بحد أقصى 18).

const AVATAR_SCENE: PackedScene = preload("res://scenes/characters/avatar_visual.tscn")
const MAX_ACTIVE_VISUALS_OFFLINE := 18
const ONLINE_PLAYERS_PER_NPC_REDUCTION := 2
const ACTIVE_RADIUS := 125.0
const REFRESH_INTERVAL := 1.25

const BASE_SPAWNS: Array[Vector3] = [
	# 6 — المنطقة الملكية والميدان
	Vector3(-17, 0, -45), Vector3(17, 0, -45), Vector3(-13, 0, -31),
	Vector3(13, 0, -31), Vector3(-7, 0, -65), Vector3(7, 0, -65),
	# 10 — المنطقة التجارية
	Vector3(-30, 0, -17), Vector3(-22, 0, -27), Vector3(0, 0, -15),
	Vector3(12, 0, -12), Vector3(30, 0, -16), Vector3(42, 0, -24),
	Vector3(58, 0, -16), Vector3(-58, 0, -12), Vector3(45, 0, 8),
	Vector3(58, 0, 12),
	# 5 — المنطقة السكنية
	Vector3(-60, 0, 43), Vector3(-30, 0, 43), Vector3(0, 0, 44),
	Vector3(30, 0, 44), Vector3(45, 0, 43),
	# 10 — المنطقة الترفيهية
	Vector3(-60, 0, 48), Vector3(-50, 0, 67), Vector3(-30, 0, 49),
	Vector3(-18, 0, 69), Vector3(0, 0, 73), Vector3(15, 0, 68),
	Vector3(30, 0, 49), Vector3(43, 0, 68), Vector3(60, 0, 48),
	Vector3(65, 0, 68),
	# 7 — منطقة الخدمات
	Vector3(-84, 0, -14), Vector3(-84, 0, 7), Vector3(-84, 0, 30),
	Vector3(84, 0, -14), Vector3(84, 0, 7), Vector3(84, 0, 28),
	Vector3(85, 0, 48),
	# 6 — الميناء والنيل
	Vector3(-52, 0, 72), Vector3(-32, 0, 72), Vector3(-16, 0, 72),
	Vector3(16, 0, 72), Vector3(36, 0, 72), Vector3(56, 0, 72),
	# 6 — المغامرات والجبل
	Vector3(88, 0, 65), Vector3(101, 0, 62), Vector3(108, 0, 47),
	Vector3(91, 0, 39), Vector3(105, 0, 31), Vector3(91, 0, 18)
]


var _spawn_records: Array[Dictionary] = []
var _active_visuals: Dictionary = {}
var _player: Node3D
var _refresh_clock := 0.0
var _motion_clock := 0.0

func _ready() -> void:
	name = "CityNPCPopulation"
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(_player):
		_player = get_parent().get_node_or_null("Player") as Node3D
	_build_spawn_records()
	_refresh_population()

func _build_spawn_records() -> void:
	for i in range(BASE_SPAWNS.size()):
		_spawn_records.append({
			"id": "citizen_%02d" % (i + 1),
			"position": BASE_SPAWNS[i],
			"source": i,
			"is_copy": false,
			"wander": 0.0 if i % 3 == 0 else 1.35,
			"phase": float(i) * 1.71
		})

func _process(delta: float) -> void:
	_motion_clock += delta
	_refresh_clock += delta
	if _refresh_clock >= REFRESH_INTERVAL:
		_refresh_clock = 0.0
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not is_instance_valid(_player):
			_player = get_parent().get_node_or_null("Player") as Node3D
		_refresh_population()
	_update_active_motion()

func _refresh_population() -> void:
	var candidates: Array[Dictionary] = []
	var player_position := _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	for record in _spawn_records:
		var distance := player_position.distance_to(record["position"])
		if distance <= ACTIVE_RADIUS:
			var candidate := record.duplicate()
			candidate["distance"] = distance
			candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var wanted: Dictionary = {}
	var online_players := 0
	if GameModeManager.is_online_ready():
		online_players = multiplayer.get_peers().size() + 1
	var visual_budget := MAX_ACTIVE_VISUALS_OFFLINE
	if online_players > 1:
		visual_budget = maxi(0, MAX_ACTIVE_VISUALS_OFFLINE - int(ceil(float(online_players - 1) / float(ONLINE_PLAYERS_PER_NPC_REDUCTION))))
	var limit := mini(visual_budget, candidates.size())
	for i in range(limit):
		var record: Dictionary = candidates[i]
		var actor_id := str(record["id"])
		wanted[actor_id] = true
		if not _active_visuals.has(actor_id):
			_create_active_visual(record)
	var old_ids: Array = _active_visuals.keys()
	for actor_id in old_ids:
		if not wanted.has(actor_id):
			var actor: Node3D = _active_visuals[actor_id]["root"]
			if is_instance_valid(actor):
				actor.queue_free()
			_active_visuals.erase(actor_id)

func _create_active_visual(record: Dictionary) -> void:
	var source_index := int(record["source"])
	var is_female := source_index % 2 == 0
	var outfit_id := "women_formal" if is_female and source_index % 4 == 0 else (
		"men_formal" if not is_female and source_index % 4 == 1 else (
		"sport" if source_index % 4 == 3 else "urban_casual"))
	var hairstyle_id := ("long" if source_index % 4 == 0 else "curly") if is_female else (
		"short" if source_index % 4 == 1 else ("curly" if source_index % 4 == 3 else "short"))
	var actor := Node3D.new()
	actor.name = str(record["id"])
	actor.position = record["position"]
	actor.set_meta("npc_gender", "female" if is_female else "male")
	actor.set_meta("source_character", source_index + 1)
	actor.set_meta("is_visual_copy", bool(record["is_copy"]))
	add_child(actor)
	var avatar := AVATAR_SCENE.instantiate() as Node3D
	avatar.name = "AvatarVisual"
	actor.add_child(avatar)
	avatar.call("apply_outfit", outfit_id)
	avatar.call("apply_hairstyle", hairstyle_id)
	_active_visuals[str(record["id"])] = {
		"root": actor,
		"avatar": avatar,
		"anchor": record["position"],
		"wander": float(record["wander"]),
		"phase": float(record["phase"]),
		"speed": 0.32 + float(source_index % 5) * 0.055
	}

func _update_active_motion() -> void:
	for actor_id in _active_visuals:
		var data: Dictionary = _active_visuals[actor_id]
		var actor: Node3D = data["root"]
		var avatar: Node3D = data["avatar"]
		if not is_instance_valid(actor) or not is_instance_valid(avatar):
			continue
		var radius := float(data["wander"])
		if radius <= 0.01:
			avatar.call("set_motion_state", "idle", 0.0)
			continue
		var phase := _motion_clock * float(data["speed"]) + float(data["phase"])
		var offset := Vector3(sin(phase) * radius, 0.0, cos(phase) * radius)
		var next_position: Vector3 = data["anchor"] + offset
		var direction := next_position - actor.position
		actor.position = next_position
		if direction.length_squared() > 0.0001:
			actor.rotation.y = atan2(direction.x, direction.z)
		avatar.call("set_motion_state", "walk", float(data["speed"]) * radius)
