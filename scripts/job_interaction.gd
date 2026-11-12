extends Node3D
## لوحة توظيف تعرض وظيفة ميدانية واحدة قابلة للإنجاز بالمشي أو الجري.

@export var job_id: String = "city_job"
@export var job_title: String = "وظيفة في المدينة"
@export_multiline var job_description: String = "نفّذ المهمة الميدانية ثم عد إلى حياتك في المدينة."
@export var reward_money: int = 180
@export var reward_chips: int = 0
@export var reward_xp: int = 30
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
		"target_offset": target_offset
	}
