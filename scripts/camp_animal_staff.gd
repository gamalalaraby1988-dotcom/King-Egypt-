extends Node3D
## موظف استقبال المخيم؛ لا توجد أسعار أو أجور أو نظام تأجير.

@export var interaction_radius: float = 4.5

func _ready() -> void:
	add_to_group("city_interactables")
	add_to_group("camp_staff")
	_build_visual()

func _build_visual() -> void:
	var uniform := StandardMaterial3D.new()
	uniform.albedo_color = Color(0.18, 0.38, 0.30)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.31
	capsule.height = 1.6
	body.mesh = capsule
	body.position.y = 0.8
	body.material_override = uniform
	add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.23
	sphere.height = 0.46
	head.mesh = sphere
	head.position.y = 1.75
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.52, 0.38)
	head.material_override = skin
	add_child(head)

	var reception_sign := Label3D.new()
	reception_sign.name = "CampReceptionLabel"
	reception_sign.text = "استقبال وترحيب"
	reception_sign.position = Vector3(0, 2.45, -0.15)
	reception_sign.font_size = 30
	reception_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reception_sign.modulate = Color(1.0, 0.88, 0.58)
	add_child(reception_sign)

func get_reception_data() -> Dictionary:
	return {
		"title": "استقبال المخيم الصحراوي الملكي",
		"description": "أهلاً بك في المخيم الملكي. يمكنني إرشادك إلى الحيوانات ومناطق المشاهدة داخل المخيم.",
		"animals": [
			"الجمل العربي",
			"الحصان العربي",
			"المها العربي",
			"الغزال",
			"الثعلب الصحراوي",
			"الأغنام",
			"الماعز",
			"الصقر"
		]
	}
