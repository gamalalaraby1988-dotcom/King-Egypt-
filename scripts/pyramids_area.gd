extends Node3D
## Pyramids and royal desert camp form one continuous Egyptian landmark district.

const SANDSTONE := Color(0.76, 0.64, 0.46)
const LIGHT_STONE := Color(0.88, 0.77, 0.58)
const DARK_STONE := Color(0.31, 0.25, 0.19)

func _ready() -> void:
	_build_pyramid("SmallPyramid", Vector3(38.0, 0.0, 36.0), 8.0, 8.0, SANDSTONE)
	_build_pyramid("MiddlePyramid", Vector3(49.0, 0.0, 36.0), 10.0, 11.0, LIGHT_STONE)
	_build_pyramid("GreatPyramid", Vector3(62.0, 0.0, 36.0), 13.0, 15.0, SANDSTONE)
	_build_sphinx()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	return material

func _build_pyramid(node_name: String, at: Vector3, base_width: float, height: float, tint: Color) -> void:
	var pyramid := Node3D.new()
	pyramid.name = node_name
	pyramid.position = at
	add_child(pyramid)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "StonePyramidMesh"
	mesh_instance.add_to_group("city_world_geometry")
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	# Rotate the inscribed square so its axis-aligned footprint matches the box collider.
	mesh.bottom_radius = base_width * 0.70710678
	mesh.height = height
	mesh.radial_segments = 4
	mesh_instance.mesh = mesh
	mesh_instance.position.y = height * 0.5
	mesh_instance.rotation.y = PI * 0.25
	mesh_instance.material_override = _material(tint)
	pyramid.add_child(mesh_instance)

	var collision := StaticBody3D.new()
	collision.name = "PyramidCollision"
	collision.add_to_group("city_world_geometry")
	collision.collision_layer = 1
	collision.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(base_width, height, base_width)
	shape_node.shape = shape
	shape_node.position.y = height * 0.5
	collision.add_child(shape_node)
	pyramid.add_child(collision)

	# Low sandstone apron marks the footprint without blocking nearby paths.
	var apron := MeshInstance3D.new()
	apron.name = "PyramidStoneApron"
	apron.add_to_group("city_world_geometry")
	var apron_mesh := BoxMesh.new()
	apron_mesh.size = Vector3(base_width + 1.2, 0.16, base_width + 1.2)
	apron.mesh = apron_mesh
	apron.position.y = 0.02
	apron.material_override = _material(DARK_STONE)
	pyramid.add_child(apron)

func _build_sphinx() -> void:
	var sphinx := Node3D.new()
	sphinx.name = "DecorativeSphinx"
	sphinx.position = Vector3(20.0, 0.0, 43.0)
	add_child(sphinx)
	_add_box(sphinx, "SphinxBase", Vector3(4.8, 0.45, 2.5), Vector3(0.0, 0.24, 0.0), DARK_STONE)
	_add_box(sphinx, "SphinxBody", Vector3(3.8, 1.05, 1.65), Vector3(0.0, 0.95, 0.0), SANDSTONE)
	_add_box(sphinx, "SphinxChest", Vector3(1.0, 1.5, 1.25), Vector3(1.1, 1.65, -0.05), LIGHT_STONE)
	var head := MeshInstance3D.new()
	head.name = "SphinxHead"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.62
	head_mesh.height = 1.24
	head.mesh = head_mesh
	head.position = Vector3(1.15, 2.45, -0.05)
	head.material_override = _material(LIGHT_STONE)
	head.add_to_group("city_world_geometry")
	sphinx.add_child(head)

	# A single conservative collider covers the decorative statue silhouette.
	var collision := StaticBody3D.new()
	collision.name = "SphinxCollision"
	collision.add_to_group("city_world_geometry")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.8, 3.1, 2.5)
	shape_node.shape = shape
	shape_node.position = Vector3(-0.3, 1.55, -0.05)
	collision.add_child(shape_node)
	sphinx.add_child(collision)

func _add_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.add_to_group("city_world_geometry")
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(tint)
	parent.add_child(instance)
