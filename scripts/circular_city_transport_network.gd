extends Node3D
## Lightweight circular road network and elevated royal semicircle overlook.
## The royal route joins the first ring at its north and east sides, on the pyramid-facing side.

const ROAD := Color(0.105, 0.12, 0.14)
const ROAD_EDGE := Color(0.82, 0.62, 0.28)
const GOLD := Color(0.88, 0.66, 0.27)
const CITY_CENTER := Vector3(0.0, 0.0, -55.0)
const RING_RADII := [175.0, 215.0, 255.0]
const RING_SEGMENTS := 32
const RING_WIDTH := 9.0
const ROYAL_ROUTE_WIDTH := 34.0
const ROYAL_ROUTE_HEIGHT := 8.0
const ROYAL_ROUTE_SEGMENTS := 36

func _ready() -> void:
	name = "CircularCityTransportNetwork"
	_build_circular_rings()
	_build_radial_shortcuts()
	_build_royal_panorama_link()

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.78) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add_road_box(label: String, size: Vector3, at: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = at
	mesh_node.rotation = rotation
	mesh_node.material_override = _material(ROAD)
	mesh_node.add_to_group("city_world_geometry")
	add_child(mesh_node)

	var body := StaticBody3D.new()
	body.name = label + "Collision"
	body.position = at
	body.rotation = rotation
	body.add_to_group("city_world_geometry")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _build_circular_rings() -> void:
	for ring_index in range(RING_RADII.size()):
		var radius: float = RING_RADII[ring_index]
		var arc_length := TAU * radius / float(RING_SEGMENTS)
		for segment_index in range(RING_SEGMENTS):
			var angle := TAU * float(segment_index) / float(RING_SEGMENTS)
			var next_angle := TAU * float(segment_index + 1) / float(RING_SEGMENTS)
			var midpoint := (angle + next_angle) * 0.5
			var at := CITY_CENTER + Vector3(cos(midpoint) * radius, 0.055, sin(midpoint) * radius)
			_add_road_box(
				"RoyalCircularRoad_R%d_S%d" % [ring_index + 1, segment_index + 1],
				Vector3(RING_WIDTH, 0.12, arc_length * 1.08),
				at,
				Vector3(0.0, -midpoint, 0.0)
			)

func _build_radial_shortcuts() -> void:
	for spoke_index in range(6):
		var angle := TAU * float(spoke_index) / 6.0
		var inner_radius := RING_RADII[0] - 3.0
		var outer_radius := RING_RADII[2] + 3.0
		var midpoint_radius := (inner_radius + outer_radius) * 0.5
		var length := outer_radius - inner_radius
		var at := CITY_CENTER + Vector3(cos(angle) * midpoint_radius, 0.065, sin(angle) * midpoint_radius)
		_add_road_box(
			"RoyalRadialShortcut_%d" % (spoke_index + 1),
			Vector3(8.0, 0.12, length),
			at,
			Vector3(0.0, PI * 0.5 - angle, 0.0)
		)

func _add_route_segment(label: String, start: Vector3, finish: Vector3, width: float) -> void:
	var delta := finish - start
	var length := delta.length()
	if length <= 0.1:
		return
	var midpoint := (start + finish) * 0.5
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.62, length + 0.8)
	mesh_node.mesh = mesh
	mesh_node.position = midpoint
	mesh_node.material_override = _material(ROAD)
	mesh_node.add_to_group("city_world_geometry")
	add_child(mesh_node)
	mesh_node.look_at(finish, Vector3.UP)

	var body := StaticBody3D.new()
	body.name = label + "Collision"
	body.position = midpoint
	body.add_to_group("city_world_geometry")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.look_at(finish, Vector3.UP)

	# Steel highway guardrail on both edges, with closely spaced support posts.
	var horizontal := Vector3(delta.x, 0.0, delta.z).normalized()
	var side := horizontal.cross(Vector3.UP).normalized()
	for edge in [-1.0, 1.0]:
		var rail_start: Vector3 = start + side * edge * (width * 0.5 - 0.7) + Vector3(0.0, 1.05, 0.0)
		var rail_finish: Vector3 = finish + side * edge * (width * 0.5 - 0.7) + Vector3(0.0, 1.05, 0.0)
		var rail_mid: Vector3 = (rail_start + rail_finish) * 0.5
		var rail := MeshInstance3D.new()
		rail.name = label + ("_SteelGuardrail_Outer" if edge > 0.0 else "_SteelGuardrail_Inner")
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.22, 0.42, length + 0.7)
		rail.mesh = rail_mesh
		rail.position = rail_mid
		rail.material_override = _material(Color(0.48, 0.51, 0.53), 0.78, 0.34)
		rail.add_to_group("city_world_geometry")
		add_child(rail)
		rail.look_at(rail_finish, Vector3.UP)
		var post_count := maxi(2, int(ceil(length / 7.0)))
		for post_index in range(post_count + 1):
			var t := float(post_index) / float(post_count)
			var post := MeshInstance3D.new()
			post.name = label + "_GuardrailPost"
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.18, 1.05, 0.18)
			post.mesh = post_mesh
			post.position = rail_start.lerp(rail_finish, t) - Vector3(0.0, 0.55, 0.0)
			post.material_override = _material(Color(0.34, 0.37, 0.39), 0.72, 0.4)
			post.add_to_group("city_world_geometry")
			add_child(post)

func _build_royal_panorama_link() -> void:
	# The royal road is the northern outer boundary, joining the west and east shoulders of ring one.
	var west_join := CITY_CENTER + Vector3(-RING_RADII[0], 0.0, 0.0)
	var east_join := CITY_CENTER + Vector3(RING_RADII[0], 0.0, 0.0)
	var desert_control := Vector3(0.0, 0.0, -550.0)
	var route_points: Array[Vector3] = []
	for i in range(ROYAL_ROUTE_SEGMENTS + 1):
		var t := float(i) / float(ROYAL_ROUTE_SEGMENTS)
		var one_minus_t := 1.0 - t
		var horizontal_point := west_join * (one_minus_t * one_minus_t)
		horizontal_point += desert_control * (2.0 * one_minus_t * t)
		horizontal_point += east_join * (t * t)
		var ramp_factor := sin(t * PI)
		route_points.append(horizontal_point + Vector3(0.0, 0.25 + ramp_factor * ROYAL_ROUTE_HEIGHT, 0.0))

	for i in range(route_points.size() - 1):
		_add_route_segment("RoyalSemicircleRoad_%02d" % (i + 1), route_points[i], route_points[i + 1], ROYAL_ROUTE_WIDTH)

	# Four short descending exits are distributed across the royal road and reconnect to ring one.
	var branch_angles := [PI * 0.82, PI * 0.62, PI * 0.38, PI * 0.18]
	var branch_names := ["RoyalWestDesertBranch", "RoyalWestCenterBranch", "RoyalEastCenterBranch", "RoyalEastDesertBranch"]
	var branch_samples := [7, 14, 22, 29]
	for branch_index in range(branch_samples.size()):
		var sample_index: int = branch_samples[branch_index]
		var branch_start: Vector3 = route_points[sample_index]
		var angle: float = branch_angles[branch_index]
		var branch_finish := CITY_CENTER + Vector3(cos(angle) * RING_RADII[0], 0.25, sin(angle) * RING_RADII[0])
		var midpoint := branch_start.lerp(branch_finish, 0.5)
		var control_a := branch_start.lerp(midpoint, 0.42) + Vector3(0.0, -1.0, 0.0)
		var control_b := branch_finish.lerp(midpoint, 0.42) + Vector3(0.0, -0.4, 0.0)
		_build_short_branch(str(branch_names[branch_index]), branch_start, control_a, control_b, branch_finish, 13.0, 12)

	var panorama_center := route_points[ROYAL_ROUTE_SEGMENTS / 2]
	_build_royal_panorama_plaza(panorama_center)

func _build_short_branch(label: String, start: Vector3, control_a: Vector3, control_b: Vector3, finish: Vector3, width: float, segments: int) -> void:
	# Cubic Bezier sampling keeps the exits smooth; segment elevation gradually
	# falls from the elevated route to the existing ground road level.
	var points: Array[Vector3] = []
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var one_minus_t := 1.0 - t
		var point := start * (one_minus_t * one_minus_t * one_minus_t)
		point += control_a * (3.0 * one_minus_t * one_minus_t * t)
		point += control_b * (3.0 * one_minus_t * t * t)
		point += finish * (t * t * t)
		points.append(point)
	for i in range(points.size() - 1):
		_add_route_segment(label + "_%02d" % (i + 1), points[i], points[i + 1], width)


func _build_royal_panorama_plaza(center: Vector3) -> void:
	var deck := MeshInstance3D.new()
	deck.name = "RoyalPanoramaPlazaDeck"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 31.0
	cylinder.bottom_radius = 31.0
	cylinder.height = 0.9
	cylinder.radial_segments = 48
	deck.mesh = cylinder
	deck.position = center + Vector3(0.0, -0.18, 0.0)
	deck.material_override = _material(Color(0.22, 0.20, 0.18), 0.28, 0.48)
	deck.add_to_group("city_world_geometry")
	add_child(deck)

	var body := StaticBody3D.new()
	body.name = "RoyalPanoramaPlazaCollision"
	body.position = deck.position
	body.add_to_group("city_world_geometry")
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 31.0
	shape.height = 1.0
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

	# Two concentric gold inlays frame the royal observation terrace.
	for ring_index in range(2):
		var torus_node := MeshInstance3D.new()
		torus_node.name = "RoyalPlazaGoldInlay_%d" % ring_index
		var torus := TorusMesh.new()
		torus.inner_radius = 29.0 - float(ring_index) * 2.0
		torus.outer_radius = torus.inner_radius + 0.28
		torus_node.mesh = torus
		torus_node.position = center + Vector3(0.0, 0.36, 0.0)
		torus_node.material_override = _material(GOLD, 0.82, 0.28)
		torus_node.add_to_group("city_world_geometry")
		add_child(torus_node)

	# Central royal fountain and illuminated founder/city emblem.
	var fountain_base := MeshInstance3D.new()
	fountain_base.name = "RoyalPanoramaFountainBase"
	var fountain_mesh := CylinderMesh.new()
	fountain_mesh.top_radius = 5.0
	fountain_mesh.bottom_radius = 6.0
	fountain_mesh.height = 0.75
	fountain_base.mesh = fountain_mesh
	fountain_base.position = center + Vector3(0.0, 0.72, 0.0)
	fountain_base.material_override = _material(GOLD, 0.7, 0.26)
	fountain_base.add_to_group("city_world_geometry")
	add_child(fountain_base)

	var water := MeshInstance3D.new()
	water.name = "RoyalPanoramaFountainWater"
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 4.45
	water_mesh.bottom_radius = 4.45
	water_mesh.height = 0.16
	water.mesh = water_mesh
	water.position = center + Vector3(0.0, 1.16, 0.0)
	water.material_override = _material(Color(0.08, 0.42, 0.55), 0.5, 0.18)
	water.add_to_group("city_world_geometry")
	add_child(water)

	var emblem := Label3D.new()
	emblem.name = "RoyalPanoramaCityEmblem"
	emblem.text = "KING OF EGYPT CITY"
	emblem.position = center + Vector3(0.0, 2.4, -12.0)
	emblem.font_size = 52
	emblem.pixel_size = 0.014
	emblem.modulate = Color(1.0, 0.82, 0.43)
	emblem.outline_size = 8
	emblem.add_to_group("city_world_geometry")
	add_child(emblem)

	var sign := Label3D.new()
	sign.name = "RoyalPanoramaPlazaSign"
	sign.text = "ROYAL PANORAMIC PLAZA"
	sign.position = center + Vector3(0.0, 4.0, 14.0)
	sign.font_size = 38
	sign.pixel_size = 0.012
	sign.modulate = Color(1.0, 0.86, 0.58)
	sign.outline_size = 7
	sign.add_to_group("city_world_geometry")
	add_child(sign)

	# Low-cost royal light pillars define the plaza perimeter without heavy dynamic effects.
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var pillar := MeshInstance3D.new()
		pillar.name = "RoyalPlazaLightPillar_%02d" % i
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.65, 3.2, 0.65)
		pillar.mesh = pillar_mesh
		pillar.position = center + Vector3(cos(angle) * 26.5, 1.55, sin(angle) * 26.5)
		pillar.material_override = _material(GOLD, 0.76, 0.3)
		pillar.add_to_group("city_world_geometry")
		add_child(pillar)
