extends Node3D
## مخيم بسيط يضم ثمانية أماكن للحيوانات وموظف التأجير.

func _ready() -> void:
	_build_camp()

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m

func _box(parent: Node3D, label: String, size: Vector3, pos: Vector3, color: Color, collision: bool = false) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)
	if collision:
		var body := StaticBody3D.new()
		body.name = label + "Collision"
		body.add_to_group("city_world_geometry")
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.position = pos
		body.add_child(shape_node)
		parent.add_child(body)

func _build_camp() -> void:
	# أرضية المخيم وعلامة المدخل
	_box(self, "CampGround", Vector3(34, 0.18, 28), Vector3(0, 0.0, 0), Color(0.62, 0.48, 0.30))
	_box(self, "CampSign", Vector3(7, 2.2, 0.25), Vector3(0, 2.2, -13.7), Color(0.35, 0.20, 0.10), true)
	var sign_text := Label3D.new()
	sign_text.text = "مخيم الحيوانات"
	sign_text.position = Vector3(0, 2.25, -13.52)
	sign_text.font_size = 48
	sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign_text)
	# مظلة مركزية خفيفة
	_box(self, "CampCanopy", Vector3(9, 0.35, 6), Vector3(0, 3.2, 0), Color(0.76, 0.62, 0.38))
	for x in [-4.0, 4.0]:
		for z in [-2.5, 2.5]:
			_box(self, "CanopyPost", Vector3(0.22, 3.2, 0.22), Vector3(x, 1.6, z), Color(0.30, 0.20, 0.12), true)
	# ثمانية أماكن واضحة للحيوانات، مع مجسمات أولية خفيفة.
	for i in range(8):
		var animal := Node3D.new()
		animal.name = "CampAnimal_%02d" % (i + 1)
		var col := Color(0.48 + float(i % 3) * 0.12, 0.30 + float(i % 2) * 0.12, 0.18 + float(i % 4) * 0.06)
		var body := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.48
		body_mesh.height = 1.8
		body.mesh = body_mesh
		body.rotation.z = PI / 2.0
		body.position.y = 0.95
		body.material_override = _mat(col)
		animal.add_child(body)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.34
		head_mesh.height = 0.68
		head.mesh = head_mesh
		head.position = Vector3(0, 1.55, -0.65)
		head.material_override = _mat(col.lightened(0.12))
		animal.add_child(head)
		var x := -11.0 + float(i % 4) * 7.3
		var z := 6.0 if i < 4 else 10.5
		animal.position = Vector3(x, 0.0, z)
		add_child(animal)
		var animal_label := Label3D.new()
		animal_label.text = "الحيوان %d" % (i + 1)
		animal_label.position = Vector3(0, 2.2, 0)
		animal_label.font_size = 30
		animal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		animal.add_child(animal_label)
		_box(self, "AnimalPenRail", Vector3(4.2, 0.18, 0.18), Vector3(x, 0.65, z + 1.4), Color(0.32, 0.20, 0.12), true)
	# محطة حفلات جانبية في الجهة الشرقية؛ تبقى خارج المدخل والمظلة وحظائر الحيوانات.
	_create_party_station(Vector3(12.0, 0.0, -3.0))

	# الموظف عند مدخل المخيم
	var staff := Node3D.new()
	staff.name = "CampAnimalStaff"
	staff.set_script(load("res://scripts/camp_animal_staff.gd"))
	staff.position = Vector3(0, 0, -7.0)
	add_child(staff)

func _create_party_station(pos: Vector3) -> void:
	var station := Node3D.new()
	station.name = "CampPartyStation"
	station.position = pos
	station.add_to_group("party_stations")
	add_child(station)
	# قاعدة صغيرة لا تتجاوز مساحة الوقوف ولا تمتد إلى الممر.
	_box(station, "PartyStationBase", Vector3(2.2, 0.28, 1.25), Vector3(0, 0.16, 0), Color(0.22, 0.15, 0.12), true)
	_box(station, "PartyStationBody", Vector3(1.9, 1.25, 0.85), Vector3(0, 0.9, 0), Color(0.18, 0.12, 0.28), true)
	_box(station, "PartyStationGoldTrim", Vector3(2.0, 0.09, 0.92), Vector3(0, 1.48, 0), Color(0.88, 0.68, 0.27))
	var speaker := MeshInstance3D.new()
	speaker.name = "PartySpeaker"
	var speaker_mesh := CylinderMesh.new()
	speaker_mesh.top_radius = 0.36
	speaker_mesh.bottom_radius = 0.36
	speaker_mesh.height = 0.12
	speaker.mesh = speaker_mesh
	speaker.rotation.x = PI / 2.0
	speaker.position = Vector3(0, 0.92, -0.46)
	speaker.material_override = _mat(Color(0.72, 0.48, 0.20))
	station.add_child(speaker)
	var marker := Label3D.new()
	marker.name = "PartyMusicMarker"
	marker.text = "♫"
	marker.position = Vector3(0, 2.55, 0)
	marker.font_size = 64
	marker.modulate = Color(1.0, 0.78, 0.28)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station.add_child(marker)
