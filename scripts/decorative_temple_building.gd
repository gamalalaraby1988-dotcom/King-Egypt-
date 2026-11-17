extends Node3D
## Decorative, non-interactive Egyptian royal temple.
## Kept as a standalone scene; do not place over roads or functional entrances.

const SAND := Color(0.72, 0.59, 0.40)
const LIGHT_STONE := Color(0.86, 0.75, 0.56)
const GOLD := Color(0.78, 0.59, 0.25)
const DARK := Color(0.12, 0.14, 0.15)
const BLUE := Color(0.12, 0.30, 0.34)
const GREEN := Color(0.18, 0.34, 0.27)

func _ready() -> void:
	_build_temple()

func _build_temple() -> void:
	_add_box("Foundation", Vector3(18.0, 0.8, 10.0), Vector3(0, 0.4, 0), SAND)
	_add_box("LowerStep", Vector3(15.5, 0.35, 8.8), Vector3(0, 0.95, 0.15), LIGHT_STONE)
	_add_box("UpperStep", Vector3(13.0, 0.3, 7.4), Vector3(0, 1.27, 0.25), SAND)
	_add_box("TempleCore", Vector3(11.0, 6.0, 6.2), Vector3(0, 4.35, 0.55), SAND)
	_add_box("LowerCornice", Vector3(11.8, 0.35, 6.8), Vector3(0, 1.65, 0.55), GOLD)
	_add_box("UpperCornice", Vector3(12.0, 0.42, 7.0), Vector3(0, 7.45, 0.55), LIGHT_STONE)
	_add_box("RoofCap", Vector3(11.2, 0.5, 6.4), Vector3(0, 7.9, 0.55), GOLD)

	# Twin entrance pylons and their gold caps frame the dark doorway.
	for side in [-1.0, 1.0]:
		var x := side * 6.4
		_add_box("Pylon_%s" % str(side), Vector3(3.2, 7.2, 1.8), Vector3(x, 4.4, -2.2), LIGHT_STONE)
		_add_box("PylonCap_%s" % str(side), Vector3(3.55, 0.45, 2.0), Vector3(x, 8.15, -2.2), GOLD)
		_add_box("PylonFoot_%s" % str(side), Vector3(3.45, 0.5, 2.0), Vector3(x, 0.65, -2.2), SAND)

	_add_box("EntranceShadow", Vector3(3.1, 4.8, 0.18), Vector3(0, 3.9, -2.76), DARK)
	_add_box("EntranceLintel", Vector3(10.2, 0.65, 1.5), Vector3(0, 8.25, -2.2), GOLD)
	_add_box("DoorThreshold", Vector3(4.0, 0.22, 1.2), Vector3(0, 1.55, -3.0), LIGHT_STONE)

	# Eight simple stone columns along the front portico.
	for row in range(2):
		for column in range(4):
			var x := -4.5 + float(column) * 3.0
			var z := -3.65 + float(row) * 1.35
			_add_column("PorticoColumn_%d_%d" % [row, column], 0.34, 4.3, Vector3(x, 3.9, z), LIGHT_STONE)
			_add_box("ColumnCapital_%d_%d" % [row, column], Vector3(0.95, 0.3, 0.95), Vector3(x, 6.12, z), GOLD)
			_add_box("ColumnBase_%d_%d" % [row, column], Vector3(0.9, 0.28, 0.9), Vector3(x, 1.78, z), SAND)

	# Restrained colored inlays and two entrance obelisks.
	for side in [-1.0, 1.0]:
		var x := side * 8.0
		_add_box("ObeliskBase_%s" % str(side), Vector3(1.5, 0.45, 1.5), Vector3(x, 0.62, -4.8), GOLD)
		_add_box("ObeliskShaft_%s" % str(side), Vector3(0.72, 4.0, 0.72), Vector3(x, 2.85, -4.8), LIGHT_STONE)
		_add_box("ObeliskTip_%s" % str(side), Vector3(0.72, 0.65, 0.72), Vector3(x, 5.18, -4.8), GOLD)
	_add_box("BlueInlay", Vector3(1.0, 0.12, 0.18), Vector3(0, 7.0, -3.16), BLUE)
	_add_box("GreenInlay", Vector3(0.55, 0.12, 0.18), Vector3(-1.0, 7.0, -3.16), GREEN)
	_add_box("GoldFrieze", Vector3(9.4, 0.22, 0.12), Vector3(0, 6.75, -2.72), GOLD)

func _add_box(node_name: String, dimensions: Vector3, at: Vector3, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _make_material(tint)
	add_child(instance)

func _add_column(node_name: String, radius: float, height: float, at: Vector3, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.12
	mesh.height = height
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _make_material(tint)
	add_child(instance)

func _make_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	return material
