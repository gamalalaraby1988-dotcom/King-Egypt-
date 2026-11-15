extends Node3D
## التوسعة المكانية الأولى للمدينة: الميدان، الطريق الدائري، الساحل، الجبل،
## ساحة المشاهدة، منطقة الأهرامات، والوصلة من طريق المخيم الحالي.
## إحداثيات هذه المرحلة هي توزيع أولي قابل للضبط وليست مسحًا نهائيًا للعالم.

const ROAD_COLOR := Color(0.105, 0.115, 0.13)
const ROAD_EDGE_COLOR := Color(0.72, 0.62, 0.40)
const STONE_COLOR := Color(0.72, 0.65, 0.51)
const GOLD_COLOR := Color(0.78, 0.57, 0.24)
const WATER_COLOR := Color(0.035, 0.34, 0.48)
const DESERT_COLOR := Color(0.72, 0.59, 0.38)

func _ready() -> void:
	call_deferred("_build_world")


func _build_world() -> void:
	_create_royal_plaza()
	_create_circular_boulevard()
	_create_seaside()
	_create_king_summit()
	_create_pyramid_district()
	_create_district_gateways()


var _material_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}


func _material(color: Color, roughness: float = 0.88, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s|%s" % [str(color.r), str(color.g), str(color.b), str(color.a), str(roughness), str(metallic)]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_material_cache[key] = material
	return material


func _get_box_mesh(size: Vector3) -> BoxMesh:
	var key := "%s|%s|%s" % [str(size.x), str(size.y), str(size.z)]
	if _box_mesh_cache.has(key):
		return _box_mesh_cache[key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_box_mesh_cache[key] = mesh
	return mesh


func _get_box_shape(size: Vector3) -> BoxShape3D:
	var key := "%s|%s|%s" % [str(size.x), str(size.y), str(size.z)]
	if _box_shape_cache.has(key):
		return _box_shape_cache[key] as BoxShape3D
	var shape := BoxShape3D.new()
	shape.size = size
	_box_shape_cache[key] = shape
	return shape


func _box(parent: Node3D, name: String, size: Vector3, position: Vector3, color: Color, collision: bool = false) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	mesh_node.mesh = _get_box_mesh(size)
	mesh_node.position = position
	mesh_node.material_override = _material(color)
	parent.add_child(mesh_node)
	if collision:
		var body := StaticBody3D.new()
		body.name = name + "_Collision"
		body.position = position
		var shape_node := CollisionShape3D.new()
		shape_node.shape = _get_box_shape(size)
		body.add_child(shape_node)
		parent.add_child(body)
	return mesh_node


func _create_royal_plaza() -> void:
	var plaza := Node3D.new()
	plaza.name = "RoyalCentralPlaza"
	add_child(plaza)

	var disk := MeshInstance3D.new()
	disk.name = "PlazaStoneSurface"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 27.0
	cylinder.bottom_radius = 27.0
	cylinder.height = 0.24
	cylinder.radial_segments = 64
	disk.mesh = cylinder
	disk.position.y = 0.07
	disk.material_override = _material(STONE_COLOR)
	plaza.add_child(disk)

	var ring := MeshInstance3D.new()
	ring.name = "PlazaGoldRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 25.8
	torus.outer_radius = 26.3
	torus.rings = 64
	torus.ring_segments = 12
	ring.mesh = torus
	ring.position.y = 0.22
	ring.material_override = _material(GOLD_COLOR, 0.42, 0.35)
	plaza.add_child(ring)

	_box(plaza, "CentralObeliskBase", Vector3(5.5, 0.8, 5.5), Vector3(0, 0.58, 0), GOLD_COLOR, true)
	_box(plaza, "CentralObeliskShaft", Vector3(2.0, 12.0, 2.0), Vector3(0, 6.8, 0), Color(0.78, 0.68, 0.49), true)
	var tip := MeshInstance3D.new()
	tip.name = "CentralObeliskTip"
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 1.0
	tip_mesh.height = 2.0
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 13.8, 0)
	tip.material_override = _material(GOLD_COLOR, 0.4, 0.3)
	plaza.add_child(tip)

	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var fountain := MeshInstance3D.new()
		fountain.name = "PlazaFountain_%02d" % index
		var basin := CylinderMesh.new()
		basin.top_radius = 1.5
		basin.bottom_radius = 1.5
		basin.height = 0.35
		fountain.mesh = basin
		fountain.position = Vector3(cos(angle) * 18.0, 0.30, sin(angle) * 18.0)
		fountain.material_override = _material(Color(0.25, 0.48, 0.55), 0.25, 0.2)
		plaza.add_child(fountain)


func _create_circular_boulevard() -> void:
	var road_root := Node3D.new()
	road_root.name = "RoyalCircularBoulevard"
	add_child(road_root)

	var radius_x := 205.0
	var radius_z := 190.0
	var segments := 64
	for index in range(segments):
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var p0 := Vector3(cos(a0) * radius_x, 0.035, sin(a0) * radius_z)
		var p1 := Vector3(cos(a1) * radius_x, 0.035, sin(a1) * radius_z)
		var midpoint := (p0 + p1) * 0.5
		var tangent := p1 - p0
		var length := tangent.length() * 1.08
		var segment := _box(road_root, "BoulevardSegment_%02d" % index, Vector3(10.0, 0.10, length), midpoint, ROAD_COLOR)
		segment.rotation.y = atan2(tangent.x, tangent.z)

		# حافة حجرية رفيعة على جانبي الطريق، دون إضافة تصادمات كثيرة.
		for side in [-1.0, 1.0]:
			var edge := _box(road_root, "BoulevardEdge_%02d_%d" % [index, int(side)], Vector3(0.32, 0.13, length), midpoint + Vector3(side * 5.1, 0.02, 0), ROAD_EDGE_COLOR)
			edge.rotation.y = segment.rotation.y


func _create_seaside() -> void:
	var coast := Node3D.new()
	coast.name = "RoyalCoast"
	add_child(coast)

	_box(coast, "CoastalSand", Vector3(700, 0.18, 48), Vector3(0, -0.05, 238), DESERT_COLOR)
	_box(coast, "SeasidePromenade", Vector3(700, 0.30, 12), Vector3(0, 0.06, 216), STONE_COLOR, true)

	var water := MeshInstance3D.new()
	water.name = "SeaWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 180)
	water.mesh = plane
	water.position = Vector3(0, -0.02, 330)
	var water_material := _material(WATER_COLOR, 0.24, 0.12)
	water.material_override = water_material
	coast.add_child(water)

	_box(coast, "PromenadeSeawall", Vector3(700, 1.0, 1.2), Vector3(0, 0.55, 222), Color(0.58, 0.57, 0.51), true)
	for x in range(-320, 321, 40):
		_box(coast, "PromenadeLampPost_%d" % x, Vector3(0.35, 4.2, 0.35), Vector3(float(x), 2.1, 210), GOLD_COLOR)
		var lamp := OmniLight3D.new()
		lamp.name = "PromenadeLamp_%d" % x
		lamp.position = Vector3(float(x), 4.2, 210)
		lamp.light_color = Color(1.0, 0.78, 0.48)
		lamp.light_energy = 0.45
		lamp.omni_range = 8.0
		coast.add_child(lamp)


func _create_king_summit() -> void:
	var mountain := Node3D.new()
	mountain.name = "KingsMountain"
	mountain.position = Vector3(0, 0, -285)
	add_child(mountain)

	var body := MeshInstance3D.new()
	body.name = "MountainMass"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	body.mesh = sphere
	body.scale = Vector3(105, 66, 82)
	body.position = Vector3(0, 5, 0)
	body.material_override = _material(Color(0.39, 0.35, 0.29))
	mountain.add_child(body)

	var shoulder := MeshInstance3D.new()
	shoulder.name = "MountainShoulder"
	shoulder.mesh = sphere
	shoulder.scale = Vector3(78, 48, 68)
	shoulder.position = Vector3(-44, -3, 22)
	shoulder.material_override = _material(Color(0.48, 0.41, 0.32))
	mountain.add_child(shoulder)

	# ساحة المشاهدة المفتوحة أعلى الجبل: لا قصر ولا مناظير ولا تجهيزات تصوير.
	var summit := Node3D.new()
	summit.name = "KingsSummitObservationPlaza"
	summit.position = Vector3(0, 68, -285)
	add_child(summit)
	_box(summit, "ObservationTerraceFloor", Vector3(54, 0.8, 38), Vector3(0, 0, 0), STONE_COLOR, true)
	_box(summit, "TerraceFrontBalustrade", Vector3(54, 1.4, 0.7), Vector3(0, 1.0, 18.4), Color(0.65, 0.58, 0.46), true)
	_box(summit, "TerraceBackBalustrade", Vector3(54, 1.4, 0.7), Vector3(0, 1.0, -18.4), Color(0.65, 0.58, 0.46), true)
	for side in [-1.0, 1.0]:
		_box(summit, "TerraceSideBalustrade_%d" % int(side), Vector3(0.7, 1.4, 36), Vector3(side * 26.7, 1.0, 0), Color(0.65, 0.58, 0.46), true)
	for x in [-17.0, 17.0]:
		var bench := _box(summit, "SummitBench_%d" % int(x), Vector3(5.0, 0.55, 1.4), Vector3(x, 0.65, -5), Color(0.31, 0.22, 0.15), true)
		_box(summit, "SummitBenchBack_%d" % int(x), Vector3(5.0, 1.0, 0.35), Vector3(x, 1.25, -5.6), Color(0.31, 0.22, 0.15))
	# طريق جبلي متعرج بصري يصل إلى الساحة؛ يظل بحاجة إلى اختبار الحركة والتصادم.
	var path_points := [
		Vector3(0, 0.1, -190), Vector3(-36, 9, -214), Vector3(-48, 20, -242),
		Vector3(-26, 33, -263), Vector3(8, 47, -276), Vector3(0, 67.5, -285)
	]
	for index in range(path_points.size() - 1):
		var start := path_points[index]
		var finish := path_points[index + 1]
		var midpoint := (start + finish) * 0.5
		var direction := finish - start
		var road_name := "SummitRoad_%02d" % index
		var road := _box(mountain, road_name, Vector3(7.0, 0.28, direction.length() + 1.0), midpoint - mountain.position, ROAD_COLOR, true)
		road.look_at(finish, Vector3.UP)
		var road_collision := mountain.get_node_or_null(road_name + "_Collision") as StaticBody3D
		if is_instance_valid(road_collision):
			road_collision.rotation = road.rotation


func _create_pyramid_district() -> void:
	var district := Node3D.new()
	district.name = "PyramidDesertDistrict"
	district.position = Vector3(235, 0, 92)
	add_child(district)

	_box(district, "PyramidDistrictSand", Vector3(150, 0.16, 112), Vector3(0, -0.02, 0), DESERT_COLOR)
	for index in range(3):
		var pyramid := MeshInstance3D.new()
		pyramid.name = "Pyramid_%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 18.0 - float(index) * 3.0
		mesh.height = 25.0 - float(index) * 4.0
		mesh.radial_segments = 4
		mesh.rings = 1
		pyramid.mesh = mesh
		pyramid.position = Vector3(float(index - 1) * 35.0, mesh.height * 0.5, -float(abs(index - 1)) * 8.0)
		pyramid.rotation.y = PI / 4.0
		pyramid.material_override = _material(Color(0.78, 0.66, 0.46))
		district.add_child(pyramid)

	# وصلة الطريق الجديدة تبدأ بعد نهاية طريق المخيم الحالي ولا تستبدل أي مقطع قائم.
	var link := _box(district, "CampToPyramidsRoad", Vector3(6, 0.12, 178), Vector3(-102.0, 0.04, -8.5), ROAD_COLOR)
	link.rotation.y = atan2(175.0, 17.0)


func _create_district_gateways() -> void:
	_create_gateway("ImportantBuildingsDistrictGateway", Vector3(-150, 0, 0), "LEFT_DISTRICT")
	_create_gateway("DesertDistrictGateway", Vector3(145, 0, 80), "DESERT_DISTRICT")


func _create_gateway(gateway_name: String, position: Vector3, label_text: String) -> void:
	var gateway := Node3D.new()
	gateway.name = gateway_name
	gateway.position = position
	add_child(gateway)
	for side in [-1.0, 1.0]:
		_box(gateway, "GatewayPillar_%d" % int(side), Vector3(2.2, 8.0, 2.2), Vector3(side * 9.0, 4.0, 0), Color(0.70, 0.56, 0.34), true)
		_box(gateway, "GatewayCap_%d" % int(side), Vector3(3.2, 0.8, 3.2), Vector3(side * 9.0, 8.4, 0), GOLD_COLOR)
	_box(gateway, "GatewayLintel", Vector3(20.5, 1.6, 2.5), Vector3(0, 8.0, 0), Color(0.12, 0.23, 0.24), true)
	var label := Label3D.new()
	label.name = "GatewayLabel"
	label.text = label_text
	label.position = Vector3(0, 8.1, 1.35)
	label.font_size = 32
	label.pixel_size = 0.012
	label.modulate = Color(1.0, 0.88, 0.59)
	gateway.add_child(label)
