extends Node3D
## مخيم صحراوي مفتوح يضم الجمل والحصان وستة أنواع إضافية.
## المجسمات خفيفة ومولدة برمجياً لتناسب تشغيل Android دون أصول خارجية.

const SAND := Color(0.62, 0.48, 0.30)
const DARK_WOOD := Color(0.30, 0.20, 0.12)
const GOLD := Color(0.78, 0.60, 0.32)
const ANIMAL_TYPES := [
	{"id":"ArabianCamel","name":"جمل عربي","kind":"camel","color":Color(0.62,0.43,0.25)},
	{"id":"ArabianHorse","name":"حصان عربي","kind":"horse","color":Color(0.28,0.16,0.11)},
	{"id":"ArabianOryx","name":"مها عربي","kind":"oryx","color":Color(0.88,0.82,0.68)},
	{"id":"DesertGazelle","name":"غزال","kind":"gazelle","color":Color(0.70,0.48,0.29)},
	{"id":"FennecFox","name":"ثعلب صحراوي","kind":"fox","color":Color(0.86,0.62,0.34)},
	{"id":"DesertSheep","name":"أغنام","kind":"sheep","color":Color(0.82,0.78,0.67)},
	{"id":"ArabianGoat","name":"ماعز","kind":"goat","color":Color(0.48,0.34,0.22)},
	{"id":"DesertFalcon","name":"صقر","kind":"falcon","color":Color(0.48,0.34,0.22)}
]

var animal_nodes: Array[Node3D] = []
var animal_base_positions: Array[Vector3] = []
var idle_clock := 0.0

func _ready() -> void:
	_build_camp()

func _process(delta: float) -> void:
	idle_clock += delta
	for i in range(animal_nodes.size()):
		var animal := animal_nodes[i]
		if not is_instance_valid(animal):
			continue
		var phase := float(i) * 0.83
		var base := animal_base_positions[i]
		animal.position.y = base.y + sin(idle_clock * 1.35 + phase) * 0.035
		animal.rotation.y = sin(idle_clock * 0.42 + phase) * 0.045

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material

func _box(parent: Node3D, label: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, label: String, radius: float, pos: Vector3, color: Color, scale_factor: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	node.mesh = mesh
	node.position = pos
	node.scale = scale_factor
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, label: String, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color, tilt: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 7
	node.mesh = mesh
	node.position = pos
	node.rotation = tilt
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _build_camp() -> void:
	_box(self, "CampGround", Vector3(34, 0.18, 28), Vector3(0, -0.09, 0), SAND)
	_box(self, "CampSign", Vector3(7, 2.2, 0.25), Vector3(0, 2.2, -13.7), DARK_WOOD)
	var sign_text := Label3D.new()
	sign_text.name = "CampTitle"
	sign_text.text = "المخيم الصحراوي الملكي"
	sign_text.position = Vector3(0, 2.25, -13.52)
	sign_text.font_size = 40
	sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign_text)

	# مظلة ظل مركزية مفتوحة من جميع الجهات.
	_box(self, "CampCanopy", Vector3(9, 0.35, 6), Vector3(0, 3.2, 0), Color(0.76, 0.62, 0.38))
	for x in [-4.0, 4.0]:
		for z in [-2.5, 2.5]:
			_box(self, "CanopyPost", Vector3(0.22, 3.2, 0.22), Vector3(x, 1.6, z), DARK_WOOD)

	# مورد ماء وعلف قريبان من الحظائر، دون سد الممرات.
	_box(self, "WaterTrough", Vector3(5.0, 0.48, 0.85), Vector3(-11.8, 0.24, 1.0), Color(0.35,0.43,0.42))
	_box(self, "WaterSurface", Vector3(4.65, 0.035, 0.62), Vector3(-11.8, 0.49, 1.0), Color(0.12,0.38,0.52))
	_box(self, "HayFeeder", Vector3(4.6, 0.65, 0.8), Vector3(11.7, 0.33, 1.0), Color(0.53,0.39,0.20))
	for i in range(8):
		var spec: Dictionary = ANIMAL_TYPES[i]
		var animal := Node3D.new()
		animal.name = str(spec["id"])
		var x := -11.0 + float(i % 4) * 7.3
		var z := 6.0 if i < 4 else 10.5
		animal.position = Vector3(x, 0.0, z)
		add_child(animal)
		_build_animal(animal, str(spec["kind"]), spec["color"])
		var label := Label3D.new()
		label.name = "AnimalName"
		label.text = str(spec["name"])
		label.position = Vector3(0, 2.55, 0)
		label.font_size = 27
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		animal.add_child(label)
		_box(self, "AnimalPenRail", Vector3(4.2, 0.18, 0.18), Vector3(x, 0.65, z + 1.4), DARK_WOOD)
		animal_nodes.append(animal)
		animal_base_positions.append(animal.position)

	# الموظف عند مدخل المخيم.
	var staff := Node3D.new()
	staff.name = "CampAnimalStaff"
	staff.set_script(load("res://scripts/camp_animal_staff.gd"))
	staff.position = Vector3(0, 0, -7.0)
	add_child(staff)

func _build_animal(animal: Node3D, kind: String, coat: Color) -> void:
	if kind == "falcon":
		_sphere(animal, "FalconBody", 0.48, Vector3(0,0.88,0), coat, Vector3(0.78,1.0,1.28))
		_sphere(animal, "FalconHead", 0.25, Vector3(0,1.42,-0.24), coat.lightened(0.12))
		_cylinder(animal, "FalconBeak", 0.02, 0.12, 0.24, Vector3(0,1.38,-0.52), GOLD, Vector3(-0.55,0,0))
		for side in [-1.0,1.0]:
			_box(animal, "FalconWing", Vector3(0.16,0.12,1.05), Vector3(side*0.38,0.98,0.05), coat.darkened(0.12)).rotation.x = -0.18
			_cylinder(animal, "FalconLeg", 0.045, 0.05, 0.48, Vector3(side*0.13,0.28,0), GOLD)
		return

	var body_scale := Vector3(1.0,1.0,1.0)
	var leg_height := 0.78
	if kind == "camel":
		body_scale = Vector3(1.35,1.0,1.25)
		leg_height = 0.95
	elif kind == "horse":
		body_scale = Vector3(1.1,0.95,1.0)
		leg_height = 0.9
	elif kind == "gazelle" or kind == "oryx":
		body_scale = Vector3(0.88,0.82,0.92)
		leg_height = 0.95
	elif kind == "fox":
		body_scale = Vector3(0.88,0.75,1.0)
		leg_height = 0.58
	elif kind == "sheep":
		body_scale = Vector3(1.0,1.0,1.0)
		leg_height = 0.55
	elif kind == "goat":
		body_scale = Vector3(0.92,0.9,0.9)
		leg_height = 0.68

	_sphere(animal, "AnimalBody", 0.58, Vector3(0,1.02,0), coat, body_scale)
	_sphere(animal, "AnimalNeck", 0.34, Vector3(0,1.30,-0.48), coat, Vector3(0.78,1.45,0.82))
	_sphere(animal, "AnimalHead", 0.32, Vector3(0,1.72,-0.72), coat.lightened(0.08))
	_sphere(animal, "AnimalMuzzle", 0.19, Vector3(0,1.60,-0.98), coat.lightened(0.18), Vector3(1.0,0.75,0.8))

	for side in [-1.0,1.0]:
		for front_back in [-1.0,1.0]:
			var leg := _cylinder(animal, "AnimalLeg", 0.095, 0.12, leg_height, Vector3(side*0.27,leg_height*0.5,front_back*0.34), coat.darkened(0.16))
			leg.rotation.x = -0.04
			_box(animal, "AnimalHoof", Vector3(0.22,0.13,0.25), Vector3(side*0.27,0.09,front_back*0.34), DARK_WOOD)

	_sphere(animal, "AnimalTail", 0.12, Vector3(0,1.03,0.68), coat.darkened(0.18), Vector3(0.8,0.8,2.5))

	if kind == "camel":
		_sphere(animal, "CamelHump", 0.42, Vector3(0,1.68,0.02), coat.darkened(0.06), Vector3(1.0,1.25,0.95))
		_sphere(animal, "CamelSecondHump", 0.31, Vector3(0,1.55,0.35), coat.darkened(0.02), Vector3(1.0,1.1,0.9))
	elif kind == "horse":
		_sphere(animal, "HorseMane", 0.22, Vector3(0,1.92,-0.48), DARK_WOOD, Vector3(0.7,1.5,1.2))
		_sphere(animal, "HorseForelock", 0.18, Vector3(0,2.0,-0.78), DARK_WOOD)
	elif kind == "oryx" or kind == "gazelle" or kind == "goat":
		var horn_length := 0.9 if kind == "oryx" else (0.58 if kind == "gazelle" else 0.42)
		for side in [-1.0,1.0]:
			var horn := _cylinder(animal, "AnimalHorn", 0.035, 0.10, horn_length, Vector3(side*0.18,2.20,-0.68), Color(0.20,0.16,0.12), Vector3(0,0,side*0.12))
			horn.rotation.x = -0.18
	elif kind == "fox":
		for side in [-1.0,1.0]:
			var ear := _cylinder(animal, "FoxEar", 0.015, 0.17, 0.55, Vector3(side*0.19,2.08,-0.72), coat.darkened(0.08), Vector3(0,0,side*0.18))
		_sphere(animal, "FoxTailTip", 0.19, Vector3(0,1.0,1.0), Color(0.92,0.84,0.68))
	elif kind == "sheep":
		for j in range(5):
			_sphere(animal, "WoolCurl", 0.27, Vector3(float(j-2)*0.22,1.30,0.05), coat.lightened(0.08))
