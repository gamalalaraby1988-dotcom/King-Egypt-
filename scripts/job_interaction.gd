extends Node3D
## نقطة التوظيف الموحدة التي تعرض الوظائف السبع المعتمدة.

@export var job_id: String = "city_jobs_hub"
@export var job_title: String = "مكتب الوظائف"
@export_multiline var job_description: String = "اختر إحدى وظائف التوصيل السبع، استلم الطرد، سلّمه بنفسك، ثم عُد بالمركبة إلى محطة الوقود."
@export var reward_money: int = 0
@export var reward_chips: int = 0
@export var reward_xp: int = 0
@export var required_level: int = 1
@export var interaction_radius: float = 4.8
@export var target_offset: Vector3 = Vector3(0, 0, -12)

func _ready() -> void:
	add_to_group("city_interactables")

func get_job_data() -> Dictionary:
	return {
		"job_id": job_id,
		"title": job_title,
		"description": job_description + "\nالمستوى المطلوب: %d" % required_level,
		"money": reward_money,
		"chips": reward_chips,
		"xp": reward_xp,
		"level": required_level,
		"target_offset": target_offset,
		"is_jobs_hub": job_id == "city_jobs_hub"
	}
