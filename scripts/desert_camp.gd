extends Node3D
## المخيم الملكي المطوّر: أربع خيام مفتوحة، مجلس مركزي، وإسطبلات جانبية.
## كل المجسمات تُنشأ هنا داخل مشهد الإنتاج نفسه لتكون المعاينة مطابقة للتنفيذ.

const SAND := Color(0.58, 0.42, 0.27)
const SAND_LIGHT := Color(0.70, 0.55, 0.37)
const GOLD := Color(0.82, 0.63, 0.29)
const DARK := Color(0.12, 0.085, 0.065)
const CLOTH := Color(0.73, 0.60, 0.43)
const ROYAL_CLOTH := Color(0.39, 0.19, 0.12)
const RED := Color(0.48, 0.12, 0.10)

func _ready() -> void:
	_build_camp()

func _mat(color: Color, roughness: float = 0.88, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.25
	return m

func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.rotation = rot
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _collision_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color) -> void:
	_box(parent, node_name, size, pos, color)
	var body := StaticBody3D.new()
	body.name = node_name + "Collision"
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _seat(parent: Node3D, seat_name: String, pos: Vector3, royal: bool) -> void:
	var seat := Node3D.new()
	seat.name = seat_name
	seat.position = pos
	seat.add_to_group("city_interactables")
	seat.set_script(load("res://scripts/tent_seat_interaction.gd"))
	seat.set("seat_title", "مقعد الخيمة الملكية" if royal else "مقعد خيمة الضيافة")
	parent.add_child(seat)
	var cushion := RED if royal else Color(0.56, 0.28, 0.20)
	_box(seat, "SeatCushion", Vector3(1.05, 0.28, 0.82), Vector3.ZERO, cushion)
	_box(seat, "SeatBack", Vector3(1.05, 0.62, 0.16), Vector3(0, 0.38, -0.34), GOLD.darkened(0.18) if royal else CLOTH.darkened(0.16))
	_box(seat, "SeatGoldPiping", Vector3(1.08, 0.055, 0.84), Vector3(0, 0.17, 0), GOLD)

func _build_tent(parent: Node3D, node_name: String, pos: Vector3, royal: bool) -> void:
	var tent := Node3D.new()
	tent.name = node_name
	tent.position = pos
	parent.add_child(tent)
	var cloth := ROYAL_CLOTH if royal else CLOTH
	# سقف مرتفع ومظلة أمامية؛ الواجهة الأمامية (+Z) مفتوحة بالكامل نحو الأهرامات.
	_box(tent, "MainCanopy", Vector3(8.2, 0.24, 6.2), Vector3(0, 3.15, -0.1), cloth)
	_box(tent, "FrontCanopy", Vector3(8.8, 0.18, 2.6), Vector3(0, 3.05, 3.15), cloth.lightened(0.08), Vector3(-0.08, 0, 0))
	_box(tent, "RearPrivacyPanel", Vector3(7.6, 1.8, 0.18), Vector3(0, 1.05, -3.0), cloth.darkened(0.08))
	# ستائر جانبية قصيرة لا تحجب خط النظر من المقاعد إلى الأهرامات.
	for side in [-1.0, 1.0]:
		_box(tent, "LowSideScreen", Vector3(0.16, 1.15, 4.7), Vector3(side * 4.0, 0.72, -0.45), cloth)
		_cylinder(tent, "FrontSupport", 0.10, 3.25, Vector3(side * 4.15, 1.62, 3.25), DARK)
		_cylinder(tent, "RearSupport", 0.10, 3.25, Vector3(side * 4.0, 1.62, -3.0), DARK)
		_cylinder(tent, "GoldPoleCap", 0.16, 0.18, Vector3(side * 4.15, 3.30, 3.25), GOLD)
	_box(tent, "FrontGoldValance", Vector3(8.85, 0.12, 0.18), Vector3(0, 2.88, 4.42), GOLD)
	_box(tent, "RearGoldTrim", Vector3(7.8, 0.10, 0.18), Vector3(0, 2.08, -2.88), GOLD)
	if royal:
		_box(tent, "RoyalCrest", Vector3(1.45, 0.72, 0.12), Vector3(0, 2.58, 4.36), GOLD)
		var crest_label := Label3D.new()
		crest_label.text = "ROYAL MAJLIS"
		crest_label.position = Vector3(0, 2.70, 4.46)
		crest_label.font_size = 28
		crest_label.modulate = Color(0.15, 0.09, 0.04)
		crest_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tent.add_child(crest_label)
	# أربعة مقاعد مستقلة قابلة للتفاعل في كل خيمة.
	for i in range(4):
		var x := -2.25 if i % 2 == 0 else 2.25
		var z := 0.15 if i < 2 else 1.85
		var seat := Node3D.new()
		seat.name = "SeatAnchor_%02d" % (i + 1)
		seat.position = Vector3(x, 0.18, z)
		seat.rotation.y = PI if i < 2 else 0.0
		tent.add_child(seat)
		_seat(tent, "InteractiveSeat_%02d" % (i + 1), seat.position, royal)

func _build_fire_circle() -> void:
	var fire := Node3D.new()
	fire.name = "CentralCampfire"
	fire.position = Vector3(0, 0, 7.0)
	add_child(fire)
	_cylinder(fire, "StoneRing", 1.35, 0.24, Vector3(0, 0.12, 0), Color(0.29, 0.24, 0.19))
	for i in range(6):
		var a := TAU * float(i) / 6.0
		_box(fire, "Firewood", Vector3(1.0, 0.13, 0.15), Vector3(cos(a) * 0.28, 0.34, sin(a) * 0.28), DARK, Vector3(0, a, 0))
	_sphere(fire, "Flame", 0.38, Vector3(0, 0.68, 0), Color(1.0, 0.34, 0.055))
	var glow := OmniLight3D.new()
	glow.position.y = 1.0
	glow.light_color = Color(1.0, 0.48, 0.16)
	glow.light_energy = 1.25
	glow.omni_range = 9.0
	fire.add_child(glow)

func _build_majlis() -> void:
	var majlis := Node3D.new()
	majlis.name = "OpenRoyalMajlis"
	majlis.position = Vector3(0, 0.02, 13.0)
	add_child(majlis)
	_box(majlis, "WovenMajlisRug", Vector3(15.0, 0.08, 6.0), Vector3(0, 0.04, 0), Color(0.38, 0.13, 0.10))
	for x in [-5.4, -2.7, 0.0, 2.7, 5.4]:
		for z in [-1.7, 1.7]:
			_box(majlis, "MajlisCushion", Vector3(1.55, 0.38, 1.0), Vector3(x, 0.28, z), RED)
			_box(majlis, "MajlisBackrest", Vector3(1.55, 0.65, 0.20), Vector3(x, 0.66, z - 0.42), GOLD.darkened(0.18))
	_box(majlis, "HospitalityTable", Vector3(5.8, 0.28, 1.2), Vector3(0, 0.48, 0), DARK)
	for x in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		_sphere(majlis, "ServingDish", 0.20, Vector3(x, 0.73, 0), GOLD)

func _build_lantern(pos: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.position = pos
	add_child(lamp)
	_cylinder(lamp, "LanternBase", 0.17, 0.12, Vector3.ZERO, DARK)
	var glass := _sphere(lamp, "LanternGlass", 0.15, Vector3(0, 0.28, 0), Color(1.0, 0.72, 0.30))
	glass.material_override = _mat(Color(1.0, 0.72, 0.30), 0.25, Color(1.0, 0.50, 0.10))
	var light := OmniLight3D.new()
	light.position.y = 0.34
	light.light_color = Color(1.0, 0.66, 0.30)
	light.light_energy = 0.5
	light.omni_range = 3.8
	lamp.add_child(light)

func _build_palm(pos: Vector3) -> void:
	var palm := Node3D.new()
	palm.position = pos
	add_child(palm)
	_cylinder(palm, "PalmTrunk", 0.22, 4.0, Vector3(0, 2.0, 0), Color(0.34, 0.21, 0.12))
	for i in range(7):
		var a := TAU * float(i) / 7.0
		_box(palm, "PalmFrond", Vector3(0.22, 0.12, 2.5), Vector3(cos(a) * 0.9, 3.8, sin(a) * 0.9), Color(0.16, 0.34, 0.18), Vector3(0.25, a, 0.18))

func _build_fence_pen(pen_name: String, center: Vector3, width: float, depth: float, species: String, coat: Color) -> void:
	var pen := Node3D.new()
	pen.name = pen_name
	pen.position = center
	add_child(pen)
	var rail_color := Color(0.28, 0.20, 0.13)
	for x in [-width * 0.5, width * 0.5]:
		for z in [-depth * 0.5, depth * 0.5]:
			_cylinder(pen, "PenPost", 0.13, 1.65, Vector3(x, 0.82, z), DARK)
	for y in [0.48, 1.12]:
		_box(pen, "FenceNorth", Vector3(width, 0.13, 0.13), Vector3(0, y, -depth * 0.5), rail_color)
		_box(pen, "FenceSouthLeft", Vector3(width * 0.35, 0.13, 0.13), Vector3(-width * 0.325, y, depth * 0.5), rail_color)
		_box(pen, "FenceSouthRight", Vector3(width * 0.35, 0.13, 0.13), Vector3(width * 0.325, y, depth * 0.5), rail_color)
		_box(pen, "FenceWest", Vector3(0.13, 0.13, depth), Vector3(-width * 0.5, y, 0), rail_color)
		_box(pen, "FenceEast", Vector3(0.13, 0.13, depth), Vector3(width * 0.5, y, 0), rail_color)
	for i in range(2):
		var animal := Node3D.new()
		animal.name = species + "_Display_%02d" % (i + 1)
		animal.position = Vector3(-width * 0.20 + float(i) * width * 0.40, 0, (0.2 if i == 0 else -0.35))
		pen.add_child(animal)
		var body := _sphere(animal, "Body", 0.48, Vector3(0, 0.82, 0), coat)
		body.scale = Vector3(1.35, 0.78, 0.72)
		_sphere(animal, "Head", 0.25, Vector3(0.48, 1.20, 0.02), coat.lightened(0.08))
		for lx in [-0.30, 0.30]:
			for lz in [-0.18, 0.18]:
				_cylinder(animal, "Leg", 0.065, 0.62, Vector3(lx, 0.31, lz), coat.darkened(0.15))
		if species == "Camels":
			_sphere(animal, "Hump", 0.32, Vector3(-0.10, 1.35, 0), coat.darkened(0.05))
	var sign := Label3D.new()
	sign.text = "منطقة " + species
	sign.position = Vector3(0, 2.0, -depth * 0.5 - 0.6)
	sign.font_size = 24
	sign.modulate = GOLD
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pen.add_child(sign)

func _build_viewing_deck() -> void:
	var deck := Node3D.new()
	deck.name = "PyramidViewingDeck"
	deck.position = Vector3(0, 0.05, 22.0)
	add_child(deck)
	_box(deck, "StoneViewingPlatform", Vector3(18.0, 0.22, 4.5), Vector3.ZERO, SAND_LIGHT)
	_box(deck, "GoldViewMarker", Vector3(10.0, 0.10, 0.14), Vector3(0, 0.18, 1.9), GOLD)
	var label := Label3D.new()
	label.text = "إطلالة الأهرامات"
	label.position = Vector3(0, 1.4, 1.5)
	label.font_size = 32
	label.modulate = GOLD
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	deck.add_child(label)

func _build_camp() -> void:
	# منصة رملية متدرجة مع ممر مركزي واضح نحو الأهرامات (+Z).
	_box(self, "DesertGround", Vector3(58.0, 0.28, 52.0), Vector3(0, -0.16, 0), SAND)
	_box(self, "RaisedMajlisTerrace", Vector3(19.0, 0.34, 9.0), Vector3(0, 0.02, 13.0), SAND_LIGHT)
	_box(self, "CentralSandWalkway", Vector3(5.0, 0.10, 23.0), Vector3(0, 0.06, 12.0), Color(0.73, 0.59, 0.41))
	var sign := Label3D.new()
	sign.name = "DesertCampSign"
	sign.text = "المخيم الملكي"
	sign.position = Vector3(0, 4.0, -23.0)
	sign.font_size = 50
	sign.modulate = GOLD.lightened(0.2)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)
	# خيمة المؤسس وثلاث خيام ضيافة؛ لكل خيمة أربعة مقاعد تفاعلية.
	_build_tent(self, "FoundersRoyalTent", Vector3(0, 0, -7.0), true)
	_build_tent(self, "GuestTentWest", Vector3(-15.0, 0, -5.0), false)
	_build_tent(self, "GuestTentEast", Vector3(15.0, 0, -5.0), false)
	_build_tent(self, "GuestTentNorth", Vector3(0, 0, 1.0), false)
	_build_fire_circle()
	_build_majlis()
	_build_viewing_deck()
	# الحظائر على الجانبين الخارجيين حتى لا تقطع الممر أو الإطلالة الأمامية.
	_build_fence_pen("CamelPen", Vector3(-23.0, 0, -7.0), 9.0, 10.0, "Camels", Color(0.62, 0.40, 0.23))
	_build_fence_pen("HorsePen", Vector3(23.0, 0, -7.0), 9.0, 10.0, "Horses", Color(0.42, 0.24, 0.14))
	_build_fence_pen("SheepGoatPen", Vector3(-23.0, 0, 10.0), 8.0, 8.0, "Sheep and Goats", Color(0.78, 0.73, 0.63))
	for p in [Vector3(-27, 0, 20), Vector3(27, 0, 20), Vector3(-27, 0, -20), Vector3(27, 0, -20)]:
		_build_lantern(p + Vector3(0, 1.0, 0))
	_build_palm(Vector3(-27.0, 0, 5.0))
	_build_palm(Vector3(27.0, 0, 5.0))
	# محطة الحفلات تبقى مرتبطة بالنظام الموحد الموجود.
	var party := Node3D.new()
	party.name = "DesertCampPartyStation"
	party.position = Vector3(25.0, 0, 1.0)
	party.add_to_group("party_stations")
	add_child(party)
	_box(party, "PartyStationBase", Vector3(2.2, 0.25, 1.3), Vector3(0, 0.14, 0), DARK)
	_box(party, "PartyStationGoldTrim", Vector3(2.0, 0.10, 1.0), Vector3(0, 0.85, 0), GOLD)
	var marker := Label3D.new()
	marker.text = "♫"
	marker.position.y = 2.0
	marker.font_size = 64
	marker.modulate = GOLD
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	party.add_child(marker)
