extends Node3D
## موظف المخيم المسؤول عن تأجير أنواع الحيوانات الموجودة في المخيم.

@export var ride_price: int = 25
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

func get_animal_rental_data() -> Dictionary:
	return {
		"title": "موظف حيوانات المخيم",
		"description": "اختر الحيوان الذي ترغب في ركوبه من حيوانات المخيم الثمانية، ثم ادفع أجرة الركوب.",
		"animals": [
			"الجمل العربي",
			"الحصان العربي",
			"المها العربي",
			"الغزال",
			"الثعلب الصحراوي",
			"الأغنام",
			"الماعز",
			"الصقر"
		],
		"price": ride_price
	}
