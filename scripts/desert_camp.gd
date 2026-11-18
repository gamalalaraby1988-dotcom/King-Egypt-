extends Node3D
## مخيم صحراوي ملكي خفيف. الجمال والخيول ديكور متحرك بتصادم، بلا تفاعل أو ركوب.

const SAND := Color(0.56, 0.39, 0.23)
const GOLD := Color(0.78, 0.57, 0.25)
const DARK := Color(0.13, 0.09, 0.07)
const FABRIC := Color(0.72, 0.57, 0.38)

const CollisionProfile = preload("res://scripts/city_collision_profile.gd")
var _animal_motion: Array[Dictionary] = []

func _ready() -> void:
	_build_camp()

func _process(delta: float) -> void:
	for motion in _animal_motion:
		var animal: Node3D = motion["animal"]
		var phase: float = motion["phase"]
		var clock: float = motion["clock"] + delta
		motion["clock"] = clock
		var walk_cycle := fposmod(clock + phase * 0.7, 8.0)
		var walk_blend := minf(clampf(walk_cycle / 0.45, 0.0, 1.0), clampf((2.8 - walk_cycle) / 0.45, 0.0, 1.0))
		var stride := sin(clock * 1.7 + phase) * walk_blend
		var drift := sin(clock * 0.75 + phase) * 0.32 * walk_blend
		animal.position = motion["base_position"] + Vector3(drift, absf(stride) * 0.025, cos(clock * 0.75 + phase) * 0.12 * walk_blend)
		animal.rotation.y = motion["base_rotation"] + sin(clock * 0.75 + phase) * 0.12 * walk_blend
		var head: Node3D = motion["head"]
		var neck: Node3D = motion["neck"]
		var tail: Node3D = motion["tail"]
		head.rotation.z = sin(clock * 1.1 + phase) * 0.09
		neck.rotation.z = sin(clock * 0.9 + phase + 0.4) * 0.045
		tail.rotation.x = sin(clock * 2.2 + phase) * 0.22
		for i in range(motion["legs"].size()):
			var leg: Node3D = motion["legs"][i]
			var direction := 1.0 if i % 2 == 0 else -1.0
			leg.rotation.x = sin(clock * 1.7 + phase + (0.0 if i < 2 else PI)) * 0.12 * direction * walk_blend

func _material(color: Color, roughness: float = 0.9, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.4
	return material

func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation = rotation
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _build_tent(parent: Node3D, node_name: String, pos: Vector3, scale_factor: float, royal: bool = false) -> void:
	var tent := Node3D.new()
	tent.name = node_name
	tent.position = pos
	tent.scale = Vector3.ONE * scale_factor
	parent.add_child(tent)
	var cloth := Color(0.56, 0.30, 0.17) if royal else FABRIC
	_box(tent, "TentBody", Vector3(6.0, 2.5, 4.6), Vector3(0, 1.35, 0), cloth)
	_box(tent, "FrontCanopy", Vector3(6.5, 0.22, 2.0), Vector3(0, 2.7, 2.4), cloth.lightened(0.08), Vector3(-0.12, 0, 0))
	_box(tent, "GoldValance", Vector3(6.55, 0.12, 0.18), Vector3(0, 2.56, 3.34), GOLD)
	for x in [-2.75, 2.75]:
		_cylinder(tent, "TentPole", 0.09, 3.0, Vector3(x, 1.5, 2.8), DARK)
	if royal:
		_box(tent, "RoyalEmblem", Vector3(1.0, 0.62, 0.12), Vector3(0, 2.55, 2.38), GOLD)

func _build_fire_circle(parent: Node3D, pos: Vector3) -> void:
	var fire := Node3D.new()
	fire.name = "Campfire"
	fire.position = pos
	parent.add_child(fire)
	_cylinder(fire, "StoneRing", 1.25, 0.22, Vector3(0, 0.12, 0), Color(0.30, 0.25, 0.20))
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		_box(fire, "Firewood", Vector3(1.1, 0.12, 0.14), Vector3(cos(angle) * 0.28, 0.36, sin(angle) * 0.28), Color(0.20, 0.11, 0.06), Vector3(0, angle, 0))
	_sphere(fire, "WarmFlame", 0.38, Vector3(0, 0.68, 0), Color(1.0, 0.36, 0.06))
	var glow := OmniLight3D.new()
	glow.name = "FireGlow"
	glow.position.y = 1.0
	glow.light_color = Color(1.0, 0.48, 0.16)
	glow.light_energy = 1.1
	glow.omni_range = 8.0
	fire.add_child(glow)

func _build_lantern(parent: Node3D, pos: Vector3) -> void:
	var lantern := Node3D.new()
	lantern.position = pos
	parent.add_child(lantern)
	_cylinder(lantern, "LanternBase", 0.18, 0.12, Vector3.ZERO, DARK)
	var glass := _sphere(lantern, "LanternGlow", 0.16, Vector3(0, 0.28, 0), Color(1.0, 0.72, 0.30))
	glass.material_override = _material(Color(1.0, 0.72, 0.30), 0.25, Color(1.0, 0.52, 0.12))
	var light := OmniLight3D.new()
	light.position.y = 0.35
	light.light_color = Color(1.0, 0.68, 0.32)
	light.light_energy = 0.45
	light.omni_range = 3.0
	lantern.add_child(light)

func _build_palm(parent: Node3D, pos: Vector3) -> void:
	var palm := Node3D.new()
	palm.position = pos
	parent.add_child(palm)
	_cylinder(palm, "PalmTrunk", 0.22, 4.0, Vector3(0, 2.0, 0), Color(0.34, 0.21, 0.12))
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		_box(palm, "PalmFrond", Vector3(0.22, 0.12, 2.4), Vector3(cos(angle) * 0.9, 3.8, sin(angle) * 0.9), Color(0.16, 0.34, 0.18), Vector3(0.25, angle, 0.18))

func _build_static_animal(parent: Node3D, node_name: String, pos: Vector3, coat: Color, camel: bool) -> void:
	# حيوان زينة يتحرك بهدوء داخل نطاقه، مع تصادم صلب؛ بلا تفاعل أو ركوب أو تأجير.
	var animal := Node3D.new()
	animal.name = node_name
	animal.position = pos
	parent.add_child(animal)
	var body := _sphere(animal, "DecorativeBody", 0.62 if camel else 0.48, Vector3(0, 0.9, 0), coat)
	body.scale = Vector3(1.45, 0.85, 0.72)
	var head := _sphere(animal, "DecorativeHead", 0.28, Vector3(0.58, 1.35, -0.12), coat.lightened(0.08))
	var neck := _cylinder(animal, "DecorativeNeck", 0.19, 0.95, Vector3(0.42, 1.25, 0), coat)
	var legs: Array[MeshInstance3D] = []
	for x in [-0.38, 0.38]:
		for z in [-0.22, 0.22]:
			legs.append(_cylinder(animal, "DecorativeLeg", 0.075, 0.72, Vector3(x, 0.36, z), coat.darkened(0.12)))
	if camel:
		_sphere(animal, "DecorativeHump", 0.34, Vector3(-0.12, 1.48, 0), coat.darkened(0.05))
	var tail := _cylinder(animal, "DecorativeTail", 0.045, 0.52, Vector3(-0.72, 0.95, 0), coat.darkened(0.18))
	tail.rotation.z = PI * 0.35
	CollisionProfile.add_staff_collider(animal, 0.55 if camel else 0.46, 1.65 if camel else 1.55)
	_animal_motion.append({
		"animal": animal,
		"base_position": pos,
		"base_rotation": animal.rotation.y,
		"phase": float(_animal_motion.size()) * 1.37,
		"clock": 0.0,
		"head": head,
		"neck": neck,
		"tail": tail,
		"legs": legs
	})

func _build_photo_oasis() -> void:
	var oasis := Node3D.new()
	oasis.name = "PhotoOasis"
	oasis.position = Vector3(10.5, 0.08, 7.0)
	add_child(oasis)
	var water := _cylinder(oasis, "OasisWater", 2.8, 0.08, Vector3.ZERO, Color(0.08, 0.38, 0.43))
	water.scale = Vector3(1.5, 1.0, 0.85)
	_box(oasis, "PhotoFrameLeft", Vector3(0.22, 3.0, 0.22), Vector3(-3.0, 1.5, 0), GOLD)
	_box(oasis, "PhotoFrameRight", Vector3(0.22, 3.0, 0.22), Vector3(3.0, 1.5, 0), GOLD)
	_box(oasis, "PhotoFrameTop", Vector3(6.2, 0.22, 0.22), Vector3(0, 3.0, 0), GOLD)
	var label := Label3D.new()
	label.text = "واحة الذكريات"
	label.position = Vector3(0, 3.45, 0)
	label.font_size = 34
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	oasis.add_child(label)
	_build_palm(oasis, Vector3(-4.0, 0, 1.0))
	_build_palm(oasis, Vector3(4.0, 0, -1.0))

func _build_camp() -> void:
	_box(self, "DesertGround", Vector3(38, 0.22, 32), Vector3(0, -0.12, 0), SAND)
	var sign := Label3D.new()
	sign.name = "DesertCampSign"
	sign.text = "المخيم الصحراوي الملكي"
	sign.position = Vector3(0, 3.4, -14.2)
	sign.font_size = 48
	sign.modulate = GOLD.lightened(0.25)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)
	_build_tent(self, "GuestTentWest", Vector3(-10.0, 0, -4.0), 0.9)
	_build_tent(self, "GuestTentEast", Vector3(10.0, 0, -4.0), 0.9)
	_build_tent(self, "FoundersRoyalTent", Vector3(0, 0, 9.0), 1.15, true)
	_build_fire_circle(self, Vector3(0, 0, 1.0))
	for pos in [Vector3(-4.0, 0, 1.0), Vector3(4.0, 0, 1.0), Vector3(-4.0, 0, 4.0), Vector3(4.0, 0, 4.0)]:
		_box(self, "MajlisCushion", Vector3(1.5, 0.42, 0.85), pos + Vector3(0, 0.3, 0), Color(0.52, 0.17, 0.12))
		_box(self, "MajlisBackrest", Vector3(1.5, 0.72, 0.2), pos + Vector3(0, 0.72, 0.38), GOLD.darkened(0.15))
	_box(self, "HospitalityTable", Vector3(4.2, 0.22, 1.5), Vector3(0, 0.72, -8.0), DARK)
	for x in [-1.5, -0.5, 0.5, 1.5]:
		_sphere(self, "HospitalityDish", 0.22, Vector3(x, 0.98, -8.0), GOLD)
	for pos in [Vector3(-15, 0, -11), Vector3(15, 0, -11), Vector3(-15, 0, 11), Vector3(15, 0, 11)]:
		_build_lantern(self, pos + Vector3(0, 1.0, 0))
	_build_palm(self, Vector3(-16, 0, 5))
	_build_palm(self, Vector3(16, 0, 5))
	_build_photo_oasis()
	# حيوانات زينة غير تفاعلية؛ تتحرك بخطوات قصيرة داخل نطاقها ولا تُنشأ لها نقاط ركوب أو نظام تأجير.
	_build_static_animal(self, "DecorativeCamel_01", Vector3(-13, 0, 2), Color(0.55, 0.34, 0.19), true)
	_build_static_animal(self, "DecorativeCamel_02", Vector3(13, 0, 2), Color(0.68, 0.48, 0.29), true)
	_build_static_animal(self, "DecorativeHorse_White", Vector3(-13, 0, 9), Color(0.88, 0.84, 0.74), false)
	_build_static_animal(self, "DecorativeHorse_Black", Vector3(-9, 0, 11), Color(0.10, 0.09, 0.08), false)
	_build_static_animal(self, "DecorativeHorse_Brown", Vector3(9, 0, 11), Color(0.38, 0.20, 0.11), false)
	_build_static_animal(self, "DecorativeHorse_Gray", Vector3(13, 0, 9), Color(0.46, 0.48, 0.50), false)
	# محطة الحفلات جزء من منظومة الحفلات الحالية، وليست نظامًا منفصلًا.
	var party := Node3D.new()
	party.name = "DesertCampPartyStation"
	party.position = Vector3(15.0, 0, -2.0)
	party.add_to_group("party_stations")
	add_child(party)
	_box(party, "PartyStationBase", Vector3(2.2, 0.25, 1.3), Vector3(0, 0.14, 0), DARK)
	_box(party, "PartyStationGoldTrim", Vector3(2.0, 0.1, 1.0), Vector3(0, 0.85, 0), GOLD)
	var marker := Label3D.new()
	marker.text = "♫"
	marker.position.y = 2.0
	marker.font_size = 64
	marker.modulate = GOLD
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	party.add_child(marker)
