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
	_build_approach_gate()
	_build_road()
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
		# حواجز صلبة على حافتي الطريق، مع فتح عرض الطريق بالكامل.
		for side in [-1.0, 1.0]:
			var rail_center := center + basis.x * side * (ROAD_WIDTH * 0.5 + 0.28) + basis.y * 0.88
			_add_oriented_box("MountainGuardWall_%02d_%s" % [i, "L" if side < 0.0 else "R"], Vector3(0.56, 1.35, length), rail_center, basis, Color(0.48, 0.40, 0.31), true)
			var gold_center := rail_center + basis.y * 0.72
			_add_oriented_box("MountainGuardGoldRail_%02d_%s" % [i, "L" if side < 0.0 else "R"], Vector3(0.18, 0.16, length), gold_center, basis, Color(0.82, 0.65, 0.29), true)


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


func _build_summit_terrace() -> void:
	var summit := ROUTE_POINTS[ROUTE_POINTS.size() - 1]
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
