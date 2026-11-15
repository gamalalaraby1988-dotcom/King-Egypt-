extends Node3D
## مدير عام لتحميل منطقة مستقلة عند اقتراب اللاعب وتحريرها عند الابتعاد.
## يوضع هذا العقد عند مركز المنطقة، ويُمرر له اللاعب ومشهد المنطقة قبل إضافته إلى شجرة المشهد.

@export_range(1.0, 1000.0, 1.0) var load_distance: float = 180.0
@export_range(1.0, 1200.0, 1.0) var unload_distance: float = 220.0

var player: Node3D
var region_scene: PackedScene
var _region_instance: Node3D
var _check_elapsed := 0.0

func configure(target_player: Node3D, scene: PackedScene) -> void:
	# عند تبديل اللاعب أو مشهد المنطقة، حرّر المحتوى القديم قبل اعتماد الإعداد الجديد.
	if player != target_player or region_scene != scene:
		_unload_region()
		_check_elapsed = 0.0
	player = target_player
	region_scene = scene

func _ready() -> void:
	if unload_distance < load_distance:
		unload_distance = load_distance
	set_process(true)

func _process(delta: float) -> void:
	_check_elapsed += delta
	if _check_elapsed < 0.5:
		return
	_check_elapsed = 0.0

	# لا نحتفظ بتفاصيل المنطقة إذا اختفى اللاعب أو أُلغي مشهدها المصدر.
	if not is_instance_valid(player) or region_scene == null:
		_unload_region()
		return

	var distance_squared := global_position.distance_squared_to(player.global_position)
	if not is_instance_valid(_region_instance):
		if distance_squared <= load_distance * load_distance:
			_load_region()
	elif distance_squared >= unload_distance * unload_distance:
		_unload_region()

func _load_region() -> void:
	if region_scene == null or is_instance_valid(_region_instance):
		return

	var instance := region_scene.instantiate()
	if not instance is Node3D:
		push_error("مشهد المنطقة يجب أن يكون جذره من نوع Node3D.")
		instance.free()
		return

	_region_instance = instance as Node3D
	_region_instance.name = "LoadedRegionContent"
	add_child(_region_instance)

func _unload_region() -> void:
	if not is_instance_valid(_region_instance):
		_region_instance = null
		return

	_region_instance.queue_free()
	_region_instance = null
