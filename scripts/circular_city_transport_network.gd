extends Node3D
## Lightweight road layer for the circular-city transition and the elevated royal overlook.
## Existing beach, sea, desert, pyramids, and approved buildings are not moved.

const ROAD := Color(0.105, 0.12, 0.14)
const ROAD_EDGE := Color(0.72, 0.59, 0.34)
const CITY_CENTER := Vector3(0.0, 0.0, -55.0)
const RING_RADII := [175.0, 215.0, 255.0]
const RING_SEGMENTS := 32
const RING_WIDTH := 9.0

func _ready() -> void:
	name = "CircularCityTransportNetwork"
	_build_circular_rings()
	_build_radial_shortcuts()
	_build_royal_panorama_link()

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

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material

func _build_circular_rings() -> void:
	# Three polygonal rings keep draw calls low while giving the city a clear circular structure.
	for ring_index in range(RING_RADII.size()):
		var radius: float = RING_RADII[ring_index]
		var arc_length := TAU * radius / float(RING_SEGMENTS)
		for segment_index in range(RING_SEGMENTS):
			var angle := TAU * float(segment_index) / float(RING_SEGMENTS)
			var next_angle := TAU * float(segment_index + 1) / float(RING_SEGMENTS)
			var midpoint := (angle + next_angle) * 0.5
			var at := CITY_CENTER + Vector3(cos(midpoint) * radius, 0.055, sin(midpoint) * radius)
			var tangent_rotation := -midpoint
			_add_road_box(
				"RoyalCircularRoad_R%d_S%d" % [ring_index + 1, segment_index + 1],
				Vector3(RING_WIDTH, 0.12, arc_length * 1.08),
				at,
				Vector3(0.0, tangent_rotation, 0.0)
			)

func _build_radial_shortcuts() -> void:
	# Six short radial links connect the three rings; existing inner streets remain the
	# access routes between buildings, avoiding relocation of approved building footprints.
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
			Vector3(0.0, -angle, 0.0)
		)

func _add_oriented_road(label: String, from_point: Vector3, to_point: Vector3, width: float, height: float = 0.55) -> void:
	var direction := to_point - from_point
	var length := direction.length()
	if length <= 0.1:
		return
	var midpoint := (from_point + to_point) * 0.5
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, length)
	node.mesh = mesh
	node.position = midpoint
	node.look_at(to_point, Vector3.UP)
	node.material_override = _material(ROAD)
	node.add_to_group("city_world_geometry")
	add_child(node)

	var body := StaticBody3D.new()
	body.name = label + "Collision"
	body.position = node.position
	body.rotation = node.rotation
	body.add_to_group("city_world_geometry")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_royal_panorama_link() -> void:
	# A broad, continuous elevated route passes behind the three pyramids.
	# Both ramps descend to the north perimeter road; the overlook is part of the route,
	# not a dead end. The sea-side beach remains north of the existing ground boundary.
	var z := -320.0
	var left_ground := Vector3(-205.0, 0.28, z)
	var left_high := Vector3(-140.0, 7.5, z)
	var right_high := Vector3(140.0, 7.5, z)
	var right_ground := Vector3(205.0, 0.28, z)

	_add_oriented_road("RoyalPanoramaRamp_West", left_ground, left_high, 18.0)
	_add_oriented_road("RoyalPanoramaDeck_West", left_high, Vector3(-34.0, 7.5, z), 18.0)
	_add_oriented_road("RoyalPanoramaDeck_East", Vector3(34.0, 7.5, z), right_high, 18.0)
	_add_oriented_road("RoyalPanoramaRamp_East", right_high, right_ground, 18.0)

	_add_road_box("RoyalPanoramaPlazaDeck", Vector3(68.0, 0.6, 48.0), Vector3(0.0, 7.5, z))
	_add_road_box("RoyalPanoramaPlazaGoldBorder_N", Vector3(68.0, 0.22, 0.45), Vector3(0.0, 7.95, z - 23.8))
	_add_road_box("RoyalPanoramaPlazaGoldBorder_S", Vector3(68.0, 0.22, 0.45), Vector3(0.0, 7.95, z + 23.8))
	_add_road_box("RoyalPanoramaPlazaGoldBorder_W", Vector3(0.45, 0.22, 48.0), Vector3(-33.8, 7.95, z))
	_add_road_box("RoyalPanoramaPlazaGoldBorder_E", Vector3(0.45, 0.22, 48.0), Vector3(33.8, 7.95, z))

	# Short ground-level tie-ins make both ends join the existing north loop road.
	_add_road_box("RoyalPanoramaGroundTie_West", Vector3(18.0, 0.14, 6.0), Vector3(-205.0, 0.12, -317.0))
	_add_road_box("RoyalPanoramaGroundTie_East", Vector3(18.0, 0.14, 6.0), Vector3(205.0, 0.12, -317.0))

	var title := Label3D.new()
	title.name = "RoyalPanoramaPlazaSign"
	title.text = "ROYAL PANORAMIC PLAZA"
	title.position = Vector3(0.0, 11.0, z - 16.0)
	title.font_size = 34
	title.pixel_size = 0.012
	title.modulate = Color(1.0, 0.84, 0.48)
	title.outline_size = 6
	title.add_to_group("city_world_geometry")
	add_child(title)
