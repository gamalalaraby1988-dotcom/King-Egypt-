extends Node3D
## 50 شخصية أساسية يمكن إنشاء نسخ بصرية إضافية منها في نقاط مستقلة.
## كل نسخة تعيد استخدام AvatarVisual نفسه ولا تنشئ خامات أو مجسمات جديدة.
## يظل حد المجسمات النشطة قريبًا من اللاعب محدودًا لحماية أداء Android.

const AVATAR_SCENE: PackedScene = preload("res://scenes/characters/avatar_visual.tscn")
const MAX_ACTIVE_VISUALS_OFFLINE := 18
const ONLINE_PLAYERS_PER_NPC_REDUCTION := 2
const ACTIVE_RADIUS := 125.0
const REFRESH_INTERVAL := 1.25
const SOCIAL_POLL_INTERVAL := 1.0
const SOCIAL_RANGE := 2.8
const SOCIAL_DURATION := 3.0
const SOCIAL_COOLDOWN := 7.0

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

## نقاط نسخ إضافية. أضف Vector3 جديدًا هنا لتوزيع نسخة في مكان آخر.
## source هو رقم الشخصية الأساسية من 1 إلى 50 التي ستُنسخ.
const COPY_SPAWNS: Array[Dictionary] = [
	{"position": Vector3(-72, 0, -48), "source": 1},
	{"position": Vector3(-48, 0, -48), "source": 2},
	{"position": Vector3(48, 0, -48), "source": 3},
	{"position": Vector3(72, 0, -48), "source": 4},
	{"position": Vector3(-72, 0, -22), "source": 5},
	{"position": Vector3(72, 0, -22), "source": 6},
	{"position": Vector3(-72, 0, 25), "source": 7},
	{"position": Vector3(72, 0, 25), "source": 8},
	{"position": Vector3(-52, 0, 18), "source": 9},
	{"position": Vector3(52, 0, 18), "source": 10},
	{"position": Vector3(-24, 0, 82), "source": 11},
	{"position": Vector3(24, 0, 82), "source": 12},
	{"position": Vector3(-42, 0, 95), "source": 13},
	{"position": Vector3(42, 0, 95), "source": 14},
	{"position": Vector3(-90, 0, 60), "source": 15},
	{"position": Vector3(90, 0, 82), "source": 16},
	{"position": Vector3(96, 0, 8), "source": 17},
	{"position": Vector3(112, 0, 60), "source": 18},
	{"position": Vector3(0, 0, -5), "source": 19},
	{"position": Vector3(0, 0, 58), "source": 20}
]

var _spawn_records: Array[Dictionary] = []
var _active_visuals: Dictionary = {}
var _player: Node3D
var _refresh_clock := 0.0
var _motion_clock := 0.0
var _social_poll_elapsed := 0.0
var _social_pair_cooldowns: Dictionary = {}
var _social_actor_states: Dictionary = {}
var _rescue_actor_ids: Dictionary = {}

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
	for i in range(COPY_SPAWNS.size()):
		var copy: Dictionary = COPY_SPAWNS[i]
		var source_index := clampi(int(copy.get("source", 1)) - 1, 0, BASE_SPAWNS.size() - 1)
		_spawn_records.append({
			"id": "citizen_copy_%03d" % (i + 1),
			"position": copy["position"],
			"source": source_index,
			"is_copy": true,
			"wander": 0.0 if i % 4 == 0 else 1.1,
			"phase": float(i + BASE_SPAWNS.size()) * 1.37
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
	_update_social_interactions(delta)
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
			_clear_social_actor(str(actor_id))

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
	# NPCs are visual-only actors: disable any physics objects inherited from
	# future avatar/outfit assets so they never block or push real players.
	_disable_npc_collisions(actor)
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

func _disable_npc_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		if collision_object is Area3D:
			(collision_object as Area3D).monitoring = false
			(collision_object as Area3D).monitorable = false
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", true)
	elif node is CollisionPolygon3D:
		(node as CollisionPolygon3D).set_deferred("disabled", true)
	for child in node.get_children():
		_disable_npc_collisions(child)

func _update_social_interactions(delta: float) -> void:
	for actor_id in _social_actor_states.keys():
		var state: Dictionary = _social_actor_states[actor_id]
		state["remaining"] = maxf(0.0, float(state.get("remaining", 0.0)) - delta)
		if float(state["remaining"]) <= 0.0:
			_social_actor_states.erase(actor_id)
	for pair_key in _social_pair_cooldowns.keys():
		var cooldown_remaining := maxf(0.0, float(_social_pair_cooldowns[pair_key]) - delta)
		if cooldown_remaining <= 0.0:
			_social_pair_cooldowns.erase(pair_key)
		else:
			_social_pair_cooldowns[pair_key] = cooldown_remaining
	_social_poll_elapsed += delta
	if _social_poll_elapsed < SOCIAL_POLL_INTERVAL:
		return
	_social_poll_elapsed = 0.0
	var actor_ids: Array[String] = []
	for actor_id in _active_visuals.keys():
		actor_ids.append(str(actor_id))
	for i in range(actor_ids.size()):
		var first_id := actor_ids[i]
		if _social_actor_states.has(first_id):
			continue
		var first_data: Dictionary = _active_visuals.get(first_id, {})
		var first_actor := first_data.get("root") as Node3D
		if not is_instance_valid(first_actor):
			continue
		for j in range(i + 1, actor_ids.size()):
			var second_id := actor_ids[j]
			if _social_actor_states.has(second_id):
				continue
			var pair_key := _make_social_pair_key(first_id, second_id)
			if float(_social_pair_cooldowns.get(pair_key, 0.0)) > 0.0:
				continue
			var second_data: Dictionary = _active_visuals.get(second_id, {})
			var second_actor := second_data.get("root") as Node3D
			if not is_instance_valid(second_actor):
				continue
			if first_actor.global_position.distance_to(second_actor.global_position) > SOCIAL_RANGE:
				continue
			# Both residents receive the same social timer and pair cooldown.
			_social_actor_states[first_id] = {"partner_id": second_id, "remaining": SOCIAL_DURATION}
			_social_actor_states[second_id] = {"partner_id": first_id, "remaining": SOCIAL_DURATION}
			_social_pair_cooldowns[pair_key] = SOCIAL_COOLDOWN
			break

func _make_social_pair_key(first_id: String, second_id: String) -> String:
	return first_id + "|" + second_id if first_id < second_id else second_id + "|" + first_id

func _clear_social_actor(actor_id: String) -> void:
	_social_actor_states.erase(actor_id)
	for partner_id in _social_actor_states.keys():
		var state: Dictionary = _social_actor_states[partner_id]
		if str(state.get("partner_id", "")) == actor_id:
			_social_actor_states.erase(partner_id)

func get_nearest_active_citizen(world_position: Vector3, max_distance: float = 12.0) -> Node3D:
	var best_actor: Node3D = null
	var best_distance := max_distance
	for actor_id in _active_visuals:
		var data: Dictionary = _active_visuals[actor_id]
		var actor := data.get("root") as Node3D
		if not is_instance_valid(actor):
			continue
		var distance := Vector2(actor.global_position.x - world_position.x, actor.global_position.z - world_position.z).length()
		if distance <= best_distance:
			best_distance = distance
			best_actor = actor
	return best_actor


func set_rescue_citizen(actor: Node3D, active: bool) -> void:
	if not is_instance_valid(actor):
		return
	var actor_id := str(actor.name)
	if active:
		_rescue_actor_ids[actor_id] = true
		var data: Dictionary = _active_visuals.get(actor_id, {})
		var avatar := data.get("avatar") as Node3D
		if is_instance_valid(avatar):
			avatar.call("set_motion_state", "wave", 0.0)
	else:
		_rescue_actor_ids.erase(actor_id)
		var data: Dictionary = _active_visuals.get(actor_id, {})
		var avatar := data.get("avatar") as Node3D
		if is_instance_valid(avatar):
			avatar.call("set_motion_state", "idle", 0.0)


func _update_active_motion() -> void:
	for actor_id in _active_visuals:
		var data: Dictionary = _active_visuals[actor_id]
		var actor: Node3D = data["root"]
		var avatar: Node3D = data["avatar"]
		if not is_instance_valid(actor) or not is_instance_valid(avatar):
			continue
		if _rescue_actor_ids.has(actor_id):
			avatar.call("set_motion_state", "wave", 0.0)
			continue
		if _social_actor_states.has(actor_id):
			var social_state: Dictionary = _social_actor_states[actor_id]
			var partner_id := str(social_state.get("partner_id", ""))
			var partner_data: Dictionary = _active_visuals.get(partner_id, {})
			var partner := partner_data.get("root") as Node3D
			if is_instance_valid(partner):
				var facing := partner.global_position - actor.global_position
				facing.y = 0.0
				if facing.length_squared() > 0.0001:
					actor.rotation.y = atan2(facing.x, facing.z)
				avatar.call("set_motion_state", "talk", 0.0)
				continue
			_social_actor_states.erase(actor_id)
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
