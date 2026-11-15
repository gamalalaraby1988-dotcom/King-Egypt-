extends Node3D
## يُنشئ تفاصيل المخيم عند اقتراب اللاعب ويحررها عند الابتعاد.

@export var load_distance: float = 82.0
@export var unload_distance: float = 112.0
var player: Node3D
var _camp_content: Node3D
var _distance_check_elapsed := 0.0
var _camp_material_cache: Dictionary = {}
var _camp_box_mesh_cache: Dictionary = {}

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_distance_check_elapsed += delta
	if _distance_check_elapsed < 0.5:
		return
	_distance_check_elapsed = 0.0
	if not is_instance_valid(player):
		return
	# مقارنة المسافة المربعة كافية لحدود التحميل/التفريغ، دون حساب جذر تربيعي دوري.
	var distance_squared := global_position.distance_squared_to(player.global_position)
	if not is_instance_valid(_camp_content):
		if distance_squared <= load_distance * load_distance:
			_build_camp()
	elif distance_squared >= unload_distance * unload_distance:
		_camp_content.queue_free()
		_camp_content = null

func _mat(color: Color) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [str(color.r), str(color.g), str(color.b), str(color.a)]
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
	if is_instance_valid(_camp_content):
		return
	_camp_content = Node3D.new()
	_camp_content.name = "CampLoadedContent"
	add_child(_camp_content)
	var content := _camp_content
	# أرضية المخيم وعلامة المدخل
	_box(content, "CampGround", Vector3(34, 0.18, 28), Vector3(0, 0.0, 0), Color(0.62, 0.48, 0.30))
	_box(content, "CampSign", Vector3(7, 2.2, 0.25), Vector3(0, 2.2, -13.7), Color(0.35, 0.20, 0.10))
	var sign_text := Label3D.new()
	sign_text.text = "مخيم الحيوانات"
	sign_text.position = Vector3(0, 2.25, -13.52)
	sign_text.font_size = 48
	sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	content.add_child(sign_text)
	# مظلة مركزية خفيفة
	_box(content, "CampCanopy", Vector3(9, 0.35, 6), Vector3(0, 3.2, 0), Color(0.76, 0.62, 0.38))
	for x in [-4.0, 4.0]:
		for z in [-2.5, 2.5]:
			_box(content, "CanopyPost", Vector3(0.22, 3.2, 0.22), Vector3(x, 1.6, z), Color(0.30, 0.20, 0.12))
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
		content.add_child(animal)
		var animal_label := Label3D.new()
		animal_label.text = "الحيوان %d" % (i + 1)
		animal_label.position = Vector3(0, 2.2, 0)
		animal_label.font_size = 30
		animal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		animal.add_child(animal_label)
		_box(content, "AnimalPenRail", Vector3(4.2, 0.18, 0.18), Vector3(x, 0.65, z + 1.4), Color(0.32, 0.20, 0.12))
	# الموظف عند مدخل المخيم
	var staff := Node3D.new()
	staff.name = "CampAnimalStaff"
	staff.set_script(load("res://scripts/camp_animal_staff.gd"))
	staff.position = Vector3(0, 0, -7.0)
	content.add_child(staff)
