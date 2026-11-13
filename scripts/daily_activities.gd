extends Node
## أنشطة يومية خفيفة تتجدد حسب تاريخ الجهاز المحلي وتحفظ تقدمها ومكافآتها.

const SAVE_PATH := "user://kings_city_daily.cfg"
const DAILY_REWARD_MONEY := 250
const DAILY_REWARD_XP := 60

var tasks: Array[Dictionary] = []
var progress: Dictionary = {}
var claimed := false
var day_key := ""
var player: Node3D
var mission_manager: Node
var achievement_manager: Node
var last_position := Vector3.ZERO
var walked_meters := 0.0
var root_panel: PanelContainer
var content_label: Label
var reward_button: Button
var open_button: Button

func _ready() -> void:
	day_key = Time.get_date_string_from_system()
	_load_state()
	_build_tasks_if_needed()
	_sync_completed_daily_tasks_from_profile()
	reconcile_reward_receipt()
	_build_ui()
	if is_instance_valid(player):
		last_position = player.global_position


func reconcile_reward_receipt() -> void:
	if not is_instance_valid(mission_manager) or not mission_manager.has_method("has_reward_receipt"):
		return
	if mission_manager.has_reward_receipt(_daily_reward_id()):
		claimed = true
		_save_state()
		if is_instance_valid(achievement_manager):
			achievement_manager.record_daily_claimed(day_key)

func _process(_delta: float) -> void:
	_check_new_day()
	if not is_instance_valid(player):
		return
	var current := player.global_position
	var step := Vector2(current.x - last_position.x, current.z - last_position.z).length()
	if step > 0.0 and step < 2.5:
		walked_meters += step
		_set_progress("walk", int(walked_meters / 25.0))
	last_position = current
	_refresh_ui()

func record_job_completed(_job_id: String = "") -> void:
	_sync_completed_daily_tasks_from_profile()
	_save_state()
	_refresh_ui()

func record_mission_completed(_mission_id: String = "") -> void:
	_sync_completed_daily_tasks_from_profile()
	_save_state()
	_refresh_ui()

func _sync_completed_daily_tasks_from_profile() -> void:
	if not is_instance_valid(mission_manager) or not mission_manager.has_method("get_daily_task_progress"):
		return
	progress["job"] = maxi(int(progress.get("job", 0)), mission_manager.get_daily_task_progress(day_key, "job"))
	progress["mission"] = maxi(int(progress.get("mission", 0)), mission_manager.get_daily_task_progress(day_key, "mission"))

func record_city_visit() -> void:
	_set_progress("visit", int(progress.get("visit", 0)) + 1)

func _set_progress(task_id: String, value: int) -> void:
	progress[task_id] = value
	_save_state()

func _build_tasks_if_needed() -> void:
	if tasks.is_empty():
		tasks = [
			{"id":"walk", "title":"استكشف شوارع المدينة", "target":4, "unit":"مسافات", "description":"امشِ أو اجرِ لمسافة إجمالية 100 متر"},
			{"id":"job", "title":"أنجز وظيفة ميدانية", "target":1, "unit":"وظيفة", "description":"أكمل وظيفة واحدة من لوحة الوظائف"},
			{"id":"mission", "title":"أكمل نشاطًا من المدينة", "target":1, "unit":"نشاط", "description":"أكمل مهمة من أحد المباني"}
		]

func _is_task_complete(task: Dictionary) -> bool:
	return int(progress.get(str(task.id), 0)) >= int(task.target)

func _all_complete() -> bool:
	for task in tasks:
		if not _is_task_complete(task):
			return false
	return true

func _daily_reward_id() -> String:
	return "daily_reward_%s" % day_key

func _claim_reward() -> void:
	if claimed or not _all_complete() or not is_instance_valid(mission_manager):
		return
	if not mission_manager.has_method("grant_reward_once"):
		return
	if not mission_manager.grant_reward_once(_daily_reward_id(), DAILY_REWARD_MONEY, DAILY_REWARD_XP, 0):
		if mission_manager.has_method("has_reward_receipt") and mission_manager.has_reward_receipt(_daily_reward_id()):
			claimed = true
			_save_state()
			if is_instance_valid(achievement_manager):
				achievement_manager.record_daily_claimed(day_key)
			_refresh_ui()
		return
	claimed = true
	if not _save_state():
		push_warning("تم تسجيل المكافأة في ملف اللاعب؛ سيُستعاد وضع الاستلام من إيصال المكافأة عند إعادة التشغيل.")
	if is_instance_valid(achievement_manager):
		achievement_manager.record_daily_claimed(day_key)
	_refresh_ui()

func _check_new_day() -> void:
	var today := Time.get_date_string_from_system()
	if today == day_key:
		return
	day_key = today
	progress.clear()
	walked_meters = 0.0
	claimed = false
	_sync_completed_daily_tasks_from_profile()
	_save_state()
	_refresh_ui()

func _load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var saved_day := str(cfg.get_value("daily", "day", day_key))
	if saved_day != day_key:
		return
	progress = cfg.get_value("daily", "progress", {})
	claimed = bool(cfg.get_value("daily", "claimed", false))
	walked_meters = float(cfg.get_value("daily", "walked_meters", 0.0))

func _save_state() -> bool:
	var cfg := ConfigFile.new()
	var load_error := cfg.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("ملف الأنشطة اليومية موجود لكنه غير قابل للقراءة؛ أُوقفت الكتابة لحماية التقدم السابق.")
		return false
	cfg.set_value("daily", "day", day_key)
	cfg.set_value("daily", "progress", progress)
	cfg.set_value("daily", "claimed", claimed)
	cfg.set_value("daily", "walked_meters", walked_meters)
	var error := cfg.save(SAVE_PATH)
	if error != OK:
		push_warning("تعذر حفظ الأنشطة اليومية: %s" % error)
	return error == OK

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DailyActivitiesHUD"
	add_child(layer)
	open_button = Button.new()
	open_button.text = "أنشطة اليوم"
	open_button.position = Vector2(165, 120)
	open_button.size = Vector2(145, 54)
	open_button.pressed.connect(func(): root_panel.visible = not root_panel.visible)
	layer.add_child(open_button)
	root_panel = PanelContainer.new()
	root_panel.position = Vector2(220, 455)
	root_panel.size = Vector2(500, 230)
	root_panel.visible = false
	layer.add_child(root_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	root_panel.add_child(box)
	var heading := Label.new()
	heading.text = "أنشطة اليوم — تتجدد يوميًا"
	heading.add_theme_font_size_override("font_size", 18)
	box.add_child(heading)
	content_label = Label.new()
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(content_label)
	reward_button = Button.new()
	reward_button.text = "استلام مكافأة اليوم"
	reward_button.pressed.connect(_claim_reward)
	box.add_child(reward_button)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): root_panel.visible = false)
	box.add_child(close)
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_instance_valid(content_label):
		return
	var lines := PackedStringArray()
	for task in tasks:
		var amount := mini(int(progress.get(str(task.id), 0)), int(task.target))
		var mark := "✓" if amount >= int(task.target) else "•"
		var display := "%s %s: %d/%d" % [mark, str(task.title), amount, int(task.target)]
		lines.append(display)
	content_label.text = "\n".join(lines)
	if claimed:
		reward_button.text = "تم استلام مكافأة اليوم"
		reward_button.disabled = true
	elif _all_complete():
		reward_button.text = "استلام 250 جنيه + 60 خبرة"
		reward_button.disabled = false
	else:
		reward_button.text = "أكمل الأنشطة لاستلام المكافأة"
		reward_button.disabled = true
