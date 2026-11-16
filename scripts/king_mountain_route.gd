extends Node3D

const CityCollisionProfile = preload("res://scripts/city_collision_profile.gd")

const ROAD_WIDTH := 8.0
const ROAD_THICKNESS := 0.42
const ROUTE_POINTS := [
	Vector3(45.0, 0.1, 88.0),
	Vector3(72.0, 6.5, 110.0),
	Vector3(72.0, 13.0, 134.0),
	Vector3(38.0, 19.5, 156.0),
	Vector3(38.0, 26.0, 180.0),
	Vector3(64.0, 32.5, 202.0)
]

func _ready() -> void:
	_build_mountain_base()
	_build_city_approach()
	_build_approach_gate()
	_build_road()
	_build_turn_guard_connectors()
	_build_turn_aprons()
	_build_wayfinding_lights()
	_build_rock_outcrops()
	_build_rest_stops()
	_build_summit_terrace()


func get_gate_position() -> Vector3:
	return ROUTE_POINTS[0] + Vector3(0.0, 1.15, -2.0)


func get_summit_position() -> Vector3:
	return ROUTE_POINTS[ROUTE_POINTS.size() - 1] + Vector3(0.0, 1.2, 5.0)


func _build_mountain_base() -> void:
	# امتداد أرضي صلب خلف المخيم حتى لا ينتهي العالم عند حافة شبكة المدينة.
	_add_box("MountainFooting", Vector3(112.0, 0.8, 150.0), Vector3(56.0, -0.75, 151.0), Color(0.28, 0.25, 0.21), true)
	# كتل صخرية جانبية متدرجة تعطي الجبل كتلة بصرية دون سد طريق الصعود.
	_add_box("MountainRockMassLower", Vector3(34.0, 10.0, 44.0), Vector3(20.0, 4.5, 128.0), Color(0.39, 0.34, 0.28), false)
	_add_box("MountainRockMassMid", Vector3(30.0, 12.0, 42.0), Vector3(101.0, 10.0, 153.0), Color(0.34, 0.30, 0.25), false)
	_add_box("MountainRockMassUpper", Vector3(34.0, 14.0, 38.0), Vector3(12.0, 18.0, 184.0), Color(0.43, 0.37, 0.29), false)



func _build_city_approach() -> void:
	# وصلة مباشرة من نهاية طريق المخيم إلى بوابة الجبل، دون فجوة ترابية.
	var start := Vector3(45.0, 0.0, 76.5)
	var finish := ROUTE_POINTS[0]
	var delta := finish - start
	var basis := Basis.looking_at(delta.normalized(), Vector3.UP)
	var center := (start + finish) * 0.5
	_add_oriented_box("MountainCityApproachRoad", Vector3(ROAD_WIDTH, ROAD_THICKNESS, delta.length() + 0.4), center, basis, Color(0.23, 0.23, 0.22), true)


func _build_approach_gate() -> void:
	var gate := Node3D.new()
	gate.name = "KingsMountainEntranceGate"
	gate.position = ROUTE_POINTS[0]
	add_child(gate)
	_add_box_to(gate, "GateLeftPillar", Vector3(0.9, 4.6, 1.0), Vector3(-5.0, 2.3, 0.0), Color(0.62, 0.50, 0.34), true)
	_add_box_to(gate, "GateRightPillar", Vector3(0.9, 4.6, 1.0), Vector3(5.0, 2.3, 0.0), Color(0.62, 0.50, 0.34), true)
	_add_box_to(gate, "GateRoyalLintel", Vector3(10.8, 0.7, 1.1), Vector3(0.0, 4.65, 0.0), Color(0.82, 0.65, 0.29), true)
	_add_box_to(gate, "GateNamePlate", Vector3(6.0, 0.8, 0.22), Vector3(0.0, 3.75, -0.62), Color(0.12, 0.18, 0.19), false)


func _build_road() -> void:
	for i in range(ROUTE_POINTS.size() - 1):
		var start: Vector3 = ROUTE_POINTS[i]
		var finish: Vector3 = ROUTE_POINTS[i + 1]
		var delta := finish - start
		var length := delta.length() + 0.35
		var direction := delta.normalized()
		var basis := Basis.looking_at(direction, Vector3.UP)
		var center := (start + finish) * 0.5
		_add_oriented_box("MountainRoadSegment_%02d" % i, Vector3(ROAD_WIDTH, ROAD_THICKNESS, length), center, basis, Color(0.23, 0.23, 0.22), true)
		# خط إرشادي ذهبي رفيع في منتصف المسار.
		_add_oriented_box("MountainRoadCenterGuide_%02d" % i, Vector3(0.10, 0.025, maxf(1.0, length - 1.2)), center + basis.y * (ROAD_THICKNESS * 0.5 + 0.018), basis, Color(0.70, 0.56, 0.30), false)
		# حواجز صلبة على حافتي الطريق، مع فتح عرض الطريق بالكامل.
		for side in [-1.0, 1.0]:
			var rail_center: Vector3 = center + basis.x * side * (ROAD_WIDTH * 0.5 + 0.28) + basis.y * 0.88
			_add_oriented_box("MountainGuardWall_%02d_%s" % [i, "L" if side < 0.0 else "R"], Vector3(0.56, 1.35, length), rail_center, basis, Color(0.48, 0.40, 0.31), true)
			var gold_center: Vector3 = rail_center + basis.y * 0.72
			_add_oriented_box("MountainGuardGoldRail_%02d_%s" % [i, "L" if side < 0.0 else "R"], Vector3(0.18, 0.16, length), gold_center, basis, Color(0.82, 0.65, 0.29), true)



func _build_turn_guard_connectors() -> void:
	# تصل حواجز المنعطفات ببعضها حتى لا تبقى فتحات عند التقاء مقاطع الطريق.
	for i in range(1, ROUTE_POINTS.size() - 1):
		var point: Vector3 = ROUTE_POINTS[i]
		var incoming: Vector3 = (point - ROUTE_POINTS[i - 1]).normalized()
		var outgoing: Vector3 = (ROUTE_POINTS[i + 1] - point).normalized()
		var incoming_side := Vector3.UP.cross(incoming).normalized()
		var outgoing_side := Vector3.UP.cross(outgoing).normalized()
		for side_sign in [-1.0, 1.0]:
			var incoming_edge: Vector3 = point + incoming_side * side_sign * (ROAD_WIDTH * 0.5 + 0.28)
			var outgoing_edge: Vector3 = point + outgoing_side * side_sign * (ROAD_WIDTH * 0.5 + 0.28)
			var connector := outgoing_edge - incoming_edge
			if connector.length() < 0.5:
				continue
			var basis := Basis.looking_at(connector.normalized(), Vector3.UP)
			var center := (incoming_edge + outgoing_edge) * 0.5 + Vector3.UP * 0.88
			var guard_name := "MountainTurnGuardConnector_%02d_%s" % [i, "L" if side_sign < 0.0 else "R"]
			if get_node_or_null(guard_name + "Collision") != null:
				continue
			var guard_size := Vector3(0.56, 1.35, connector.length() + 0.35)
			var guard_color := Color(0.48, 0.40, 0.31)
			# Build the visual and its collider explicitly here. This avoids relying on
			# the generic box helper to create a separately named collision child.
			_add_oriented_box(guard_name, guard_size, center, basis, guard_color, false)
			# Continue the gold safety rail across the bend so the barrier reads as one line.
			_add_oriented_box(
				guard_name + "GoldRail",
				Vector3(0.18, 0.16, connector.length() + 0.35),
				center + basis.y * 0.72,
				basis,
				Color(0.82, 0.65, 0.29),
				false
			)
			var guard_body := StaticBody3D.new()
			guard_body.name = guard_name + "Collision"
			CityCollisionProfile.apply_world_collision(guard_body)
			var guard_shape_node := CollisionShape3D.new()
			guard_shape_node.name = "CollisionShape3D"
			var guard_shape := BoxShape3D.new()
			guard_shape.size = guard_size
			guard_shape_node.shape = guard_shape
			guard_body.transform = Transform3D(basis, center)
			guard_body.add_child(guard_shape_node)
			add_child(guard_body)


func _build_turn_aprons() -> void:
	# توسعات صغيرة عند المنعطفات تمنع الفواصل الحادة بين مقاطع الطريق.
	for i in range(1, ROUTE_POINTS.size() - 1):
		var incoming: Vector3 = (ROUTE_POINTS[i] - ROUTE_POINTS[i - 1]).normalized()
		var outgoing: Vector3 = (ROUTE_POINTS[i + 1] - ROUTE_POINTS[i]).normalized()
		var tangent := (incoming + outgoing).normalized()
		if tangent.length() < 0.1:
			tangent = outgoing
		var basis := Basis.looking_at(tangent, Vector3.UP)
		_add_oriented_box("MountainTurnApron_%02d" % i, Vector3(9.2, ROAD_THICKNESS, 9.2), ROUTE_POINTS[i], basis, Color(0.25, 0.24, 0.22), true)

func _build_wayfinding_lights() -> void:
	# أعمدة إنارة وإرشاد خارج حافة الحواجز؛ لا تقترب من حيز قيادة المركبات.
	for i in range(ROUTE_POINTS.size()):
		var previous: Vector3 = ROUTE_POINTS[maxi(0, i - 1)]
		var following: Vector3 = ROUTE_POINTS[mini(ROUTE_POINTS.size() - 1, i + 1)]
		var forward := (following - previous).normalized()
		var side := Vector3.UP.cross(forward).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var side_sign := -1.0 if i % 2 == 0 else 1.0
		var lamp_position: Vector3 = ROUTE_POINTS[i] + side * side_sign * 6.4
		_add_box("MountainWayfindingLampPost_%02d" % i, Vector3(0.32, 3.0, 0.32), lamp_position + Vector3.UP * 1.5, Color(0.49, 0.39, 0.25), true)
		_add_box("MountainWayfindingLampCap_%02d" % i, Vector3(0.72, 0.32, 0.72), lamp_position + Vector3.UP * 3.12, Color(0.82, 0.65, 0.30), false)
		var glow := OmniLight3D.new()
		glow.name = "MountainWayfindingGlow_%02d" % i
		glow.position = lamp_position + Vector3.UP * 3.0
		glow.light_color = Color(1.0, 0.78, 0.43)
		glow.light_energy = 0.65
		glow.omni_range = 8.0
		glow.shadow_enabled = false
		add_child(glow)

func _build_rock_outcrops() -> void:
	# كتل صخرية زخرفية على مسافة آمنة خارج الحواجز.
	_add_box("MountainRockOutcrop_00", Vector3(5.0, 3.8, 6.0), Vector3(27.0, 2.0, 145.0), Color(0.37, 0.32, 0.27), true)
	_add_box("MountainRockOutcrop_01", Vector3(6.0, 5.0, 5.0), Vector3(88.0, 4.0, 176.0), Color(0.33, 0.29, 0.25), true)
	_add_box("MountainRockOutcrop_02", Vector3(5.5, 4.5, 6.5), Vector3(22.0, 8.0, 193.0), Color(0.42, 0.36, 0.29), true)
	_add_box("MountainRockOutcrop_03", Vector3(4.5, 3.2, 5.0), Vector3(84.0, 0.5, 119.0), Color(0.39, 0.34, 0.29), true)

func _build_rest_stops() -> void:
	# فسحات جانبية خارج مسار المركبات؛ لا توضع المقاعد على الطريق.
	var stop_indices := [1, 3]
	for stop_number in range(stop_indices.size()):
		var point: Vector3 = ROUTE_POINTS[stop_indices[stop_number]]
		var next_point: Vector3 = ROUTE_POINTS[stop_indices[stop_number] + 1]
		var forward := (next_point - point).normalized()
		var side := Vector3.UP.cross(forward).normalized()
		var pad_center := point + side * 8.5 + Vector3.UP * 0.12
		_add_box("MountainRestBay_%d" % stop_number, Vector3(7.0, 0.32, 7.0), pad_center, Color(0.56, 0.47, 0.36), true)
		_add_box("MountainRestBench_%d" % stop_number, Vector3(2.8, 0.55, 0.75), pad_center + side * 0.9 + Vector3.UP * 0.42, Color(0.30, 0.27, 0.23), true)
		_add_box("MountainRestLantern_%d" % stop_number, Vector3(0.28, 2.4, 0.28), pad_center - side * 2.4 + Vector3.UP * 1.2, Color(0.78, 0.59, 0.27), true)
		# منصة مشاهدة جانبية متصلة بفسحة الاستراحة، مع حواجز على الجهات المكشوفة.
		var view_center := pad_center + side * 5.2
		_add_box("MountainViewDeck_%d" % stop_number, Vector3(8.0, 0.32, 7.0), view_center, Color(0.61, 0.52, 0.39), true)
		_add_box("MountainViewDeckOuterRail_%d" % stop_number, Vector3(0.38, 1.15, 7.0), view_center + side * 3.8 + Vector3.UP * 0.72, Color(0.48, 0.40, 0.31), true)
		_add_box("MountainViewDeckLeftRail_%d" % stop_number, Vector3(8.0, 1.15, 0.38), view_center + Vector3(0.0, 0.72, -3.3), Color(0.48, 0.40, 0.31), true)
		_add_box("MountainViewDeckRightRail_%d" % stop_number, Vector3(8.0, 1.15, 0.38), view_center + Vector3(0.0, 0.72, 3.3), Color(0.48, 0.40, 0.31), true)


func _build_summit_terrace() -> void:
	var summit: Vector3 = ROUTE_POINTS[ROUTE_POINTS.size() - 1]
	_add_box("MountainSummitPlatform", Vector3(34.0, 1.0, 34.0), summit + Vector3(0.0, -0.5, 5.0), Color(0.52, 0.45, 0.35), true)
	# الحواجز تحيط بالحواف وتترك مدخل الطريق مفتوحًا من الجهة الجنوبية.
	for x in [-15.0, 15.0]:
		_add_box("MountainSummitSideBarrier_%d" % int(x), Vector3(0.65, 1.6, 30.0), summit + Vector3(x, 0.8, 5.0), Color(0.36, 0.31, 0.25), true)
	_add_box("MountainSummitRearBarrier", Vector3(30.0, 1.6, 0.65), summit + Vector3(0.0, 0.8, 21.0), Color(0.36, 0.31, 0.25), true)
	_add_box("MountainSummitObeliskBase", Vector3(4.0, 0.6, 4.0), summit + Vector3(-9.0, 0.8, 7.0), Color(0.36, 0.31, 0.25), true)
	_add_box("MountainSummitObelisk", Vector3(0.65, 5.0, 0.65), summit + Vector3(-9.0, 3.6, 7.0), Color(0.86, 0.68, 0.29), true)
	for x in [-10.0, 10.0]:
		_add_box("MountainSummitBench_%d" % int(x), Vector3(3.0, 0.5, 0.8), summit + Vector3(x, 0.45, 9.0), Color(0.32, 0.28, 0.23), true)


func _add_box(name: String, size: Vector3, position: Vector3, color: Color, collision: bool) -> void:
	_add_box_to(self, name, size, position, color, collision)


func _add_box_to(parent: Node3D, name: String, size: Vector3, position: Vector3, color: Color, collision: bool) -> void:
	_add_oriented_box_to(parent, name, size, position, Basis.IDENTITY, color, collision)


func _add_oriented_box(name: String, size: Vector3, position: Vector3, basis: Basis, color: Color, collision: bool) -> void:
	_add_oriented_box_to(self, name, size, position, basis, color, collision)


func _add_oriented_box_to(parent: Node3D, name: String, size: Vector3, position: Vector3, basis: Basis, color: Color, collision: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.transform = Transform3D(basis, position)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	if not collision:
		return
	var body := StaticBody3D.new()
	body.name = name + "Collision"
	CityCollisionProfile.apply_world_collision(body)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.transform = Transform3D(basis, position)
	body.add_child(shape_node)
	parent.add_child(body)
