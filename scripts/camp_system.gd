extends Node3D
## مخيم بسيط يضم ثمانية أماكن للحيوانات وموظف التأجير.

func _ready() -> void:
	_build_camp()

var _camp_material_cache: Dictionary = {}
var _camp_box_mesh_cache: Dictionary = {}

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _camp_material_cache.has(key):
		return _camp_material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	_camp_material_cache[key] = material
	return material

func _get_box_mesh(size: Vector3) -> BoxMesh:
	var key := "%s|%s|%s" % [str(size.x), str(size.y), str(size.z)]
	if _camp_box_mesh_cache.has(key):
		return _camp_box_mesh_cache[key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_camp_box_mesh_cache[key] = mesh
	return mesh

func _box(parent: Node3D, label: String, size: Vector3, pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = _get_box_mesh(size)
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)

func _build_camp() -> void:
	# أرضية المخيم وعلامة المدخل
	_box(self, "CampGround", Vector3(34, 0.18, 28), Vector3(0, 0.0, 0), Color(0.62, 0.48, 0.30))
	_box(self, "CampSign", Vector3(7, 2.2, 0.25), Vector3(0, 2.2, -13.7), Color(0.35, 0.20, 0.10))
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
			_box(self, "CanopyPost", Vector3(0.22, 3.2, 0.22), Vector3(x, 1.6, z), Color(0.30, 0.20, 0.12))
	# مشاركة موارد مجسمات الحيوانات المتكررة بدل إنشاء نسخة هندسية لكل حيوان.
	var shared_body_mesh := CapsuleMesh.new()
	shared_body_mesh.radius = 0.48
	shared_body_mesh.height = 1.8
	var shared_head_mesh := SphereMesh.new()
	shared_head_mesh.radius = 0.34
	shared_head_mesh.height = 0.68
	# ثمانية أماكن واضحة للحيوانات، مع مجسمات أولية خفيفة.
	for i in range(8):
		var animal := Node3D.new()
		animal.name = "CampAnimal_%02d" % (i + 1)
		var col := Color(0.48 + float(i % 3) * 0.12, 0.30 + float(i % 2) * 0.12, 0.18 + float(i % 4) * 0.06)
		var body := MeshInstance3D.new()
		body.mesh = shared_body_mesh
		body.rotation.z = PI / 2.0
		body.position.y = 0.95
		body.material_override = _mat(col)
		animal.add_child(body)
		var head := MeshInstance3D.new()
		head.mesh = shared_head_mesh
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
		_box(self, "AnimalPenRail", Vector3(4.2, 0.18, 0.18), Vector3(x, 0.65, z + 1.4), Color(0.32, 0.20, 0.12))
	# الموظف عند مدخل المخيم
	var staff := Node3D.new()
	staff.name = "CampAnimalStaff"
	staff.set_script(load("res://scripts/camp_animal_staff.gd"))
	staff.position = Vector3(0, 0, -7.0)
	add_child(staff)
