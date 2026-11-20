extends Node
## إنجازات دائمة محليًا مرتبطة بالتجول والوظائف والمهام والأنشطة اليومية.

const ProfileConfigStore = preload("res://scripts/profile_config_store.gd")

var player: Node3D
var mission_manager: Node
var walked_meters := 0.0
var last_saved_walk_meters := 0.0
var last_position := Vector3.ZERO
var totals: Dictionary = {"jobs": 0, "missions": 0, "daily_claims": 0}
var unlocked: Dictionary = {}
var definitions: Array[Dictionary] = [
	{"id":"first_steps", "title":"أول خطواتك", "description":"امشِ أو اجرِ لمسافة 100 متر", "kind":"walk", "target":100, "money":100, "chips":0},
	{"id":"worker", "title":"عامل مجتهد", "description":"أكمل 3 وظائف ميدانية", "kind":"jobs", "target":3, "money":250, "chips":0},
	{"id":"explorer", "title":"مستكشف المدينة", "description":"أكمل 3 مهام من مباني المدينة", "kind":"missions", "target":3, "money":250, "chips":5},
	{"id":"veteran", "title":"صاحب الخبرة", "description":"وصل إلى المستوى 5", "kind":"level", "target":5, "money":400, "chips":10},
	{"id":"daily_three", "title":"ملتزم يوميًا", "description":"استلم مكافأة الأنشطة اليومية في 3 أيام", "kind":"daily_claims", "target":3, "money":500, "chips":10}
]
var panel: PanelContainer
var list_label: Label
var summary_label: Label
var open_button: Button

func _save_path() -> String:
	return ProfileConfigStore.get_active_scoped_path("user://kings_city_achievements.cfg")

func _ready() -> void:
	_load_state()
	if is_instance_valid(mission_manager) and mission_manager.has_method("initialize_achievement_totals_if_missing"):
		mission_manager.initialize_achievement_totals_if_missing(totals)
	if is_instance_valid(mission_manager) and mission_manager.has_method("get_achievement_totals"):
		totals = mission_manager.get_achievement_totals()
	last_saved_walk_meters = walked_meters
	if is_instance_valid(player):
		last_position = player.global_position
	_build_ui()
	_check_all()

func _process(_delta: float) -> void:
	if GameModeManager.is_online_ready():
		return
	if not is_instance_valid(player):
		return
	var current := player.global_position
	var step := Vector2(current.x - last_position.x, current.z - last_position.z).length()
	if step > 0.0 and step < 2.5:
		walked_meters += step
		if int(walked_meters / 5.0) > int(last_saved_walk_meters / 5.0):
			_save_state()
		_check_all()
	last_position = current

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_state()

func record_job_completed(job_id: String) -> void:
	_record_event_once("job:%s" % job_id, "jobs")

func record_mission_completed(mission_id: String) -> void:
	_record_event_once("mission:%s" % mission_id, "missions")

func record_daily_claimed(day_id: String) -> void:
	_record_event_once("daily:%s" % day_id, "daily_claims")

func _record_event_once(event_id: String, stat_key: String) -> void:
	if GameModeManager.is_online_ready():
		return
	if not is_instance_valid(mission_manager) or not mission_manager.has_method("record_achievement_event_once"):
		return
	if mission_manager.record_achievement_event_once(event_id, stat_key):
		totals = mission_manager.get_achievement_totals()
		_save_state()
		_check_all()

func _current_value(kind: String) -> int:
	match kind:
		"walk":
			return int(walked_meters)
		"level":
			return int(mission_manager.get("player_level")) if is_instance_valid(mission_manager) else 1
		_:
			return int(totals.get(kind, 0))

func _check_all() -> void:
	if GameModeManager.is_online_ready():
		return
	if is_instance_valid(mission_manager) and mission_manager.has_method("get_achievement_totals"):
		totals = mission_manager.get_achievement_totals()
	var changed := false
	for item in definitions:
		var achievement_id := str(item["id"])
		if unlocked.has(achievement_id):
			continue
		if _current_value(str(item["kind"])) >= int(item["target"]):
			if not is_instance_valid(mission_manager) or not mission_manager.has_method("grant_reward_once"):
				continue
			var reward_id := "achievement_%s" % achievement_id
			# حتى لو فشل حفظ ملف الإنجازات، يمنع إيصال المحفظة صرف الجائزة مرة أخرى.
			var reward_saved: bool = bool(mission_manager.has_reward_receipt(reward_id))
			if not reward_saved:
				reward_saved = bool(mission_manager.grant_reward_once(reward_id, int(item["money"]), 0, int(item["chips"])))
			if not reward_saved:
				continue
			unlocked[achievement_id] = Time.get_datetime_string_from_system()
			changed = true
	if changed:
		_save_state()
	_refresh_ui()

func _save_state() -> void:
	var cfg := ConfigFile.new()
	var load_error := cfg.load(_save_path())
	if load_error != OK and FileAccess.file_exists(_save_path()):
		push_warning("ملف الإنجازات موجود لكنه غير قابل للقراءة؛ أُوقفت الكتابة لحماية التقدم السابق.")
		return
	cfg.set_value("achievements", "walked_meters", walked_meters)
	cfg.set_value("achievements", "totals", totals)
	cfg.set_value("achievements", "unlocked", unlocked)
	var error := cfg.save(_save_path())
	if error != OK:
		push_warning("تعذر حفظ الإنجازات: %s" % error)
	else:
		last_saved_walk_meters = walked_meters
		if is_instance_valid(PlayerSyncClient):
			PlayerSyncClient.enqueue_progress_observation(
				"achievement_progress_observed",
				"achievement.walked_meters",
				int(walked_meters)
			)

func _load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_save_path()) != OK:
		return
	var saved_walked: float = float(cfg.get_value("achievements", "walked_meters", 0.0))
	walked_meters = maxf(0.0, saved_walked) if is_finite(saved_walked) else 0.0
	var saved_totals: Variant = cfg.get_value("achievements", "totals", totals)
	var saved_unlocked: Variant = cfg.get_value("achievements", "unlocked", {})
	if saved_totals is Dictionary:
		totals = {
			"jobs": maxi(0, int(saved_totals.get("jobs", 0))),
			"missions": maxi(0, int(saved_totals.get("missions", 0))),
			"daily_claims": maxi(0, int(saved_totals.get("daily_claims", 0)))
		}
	if saved_unlocked is Dictionary:
		unlocked = saved_unlocked

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AchievementsHUD"
	add_child(layer)
	open_button = Button.new()
	open_button.text = "الإنجازات 🏆"
	open_button.position = Vector2(165, 180)
	open_button.size = Vector2(145, 52)
	open_button.pressed.connect(func(): panel.visible = not panel.visible)
	layer.add_child(open_button)
	panel = PanelContainer.new()
	panel.position = Vector2(220, 170)
	panel.size = Vector2(500, 360)
	panel.visible = false
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = "إنجازات King of Egypt City"
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	summary_label = Label.new()
	box.add_child(summary_label)
	list_label = Label.new()
	list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(list_label)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): panel.visible = false)
	box.add_child(close)

func _refresh_ui() -> void:
	if not is_instance_valid(list_label):
		return
	var lines := PackedStringArray()
	var count := unlocked.size()
	for item in definitions:
		var done := unlocked.has(str(item["id"]))
		var amount := mini(_current_value(str(item["kind"])), int(item["target"]))
		var mark := "🏆" if done else "🔒"
		lines.append("%s %s — %s (%d/%d) | مكافأة: %d جنيه + %d رقائق" % [mark, str(item["title"]), str(item["description"]), amount, int(item["target"]), int(item["money"]), int(item["chips"])])
	list_label.text = "\n\n".join(lines)
	summary_label.text = "الإنجازات المفتوحة: %d من %d" % [count, definitions.size()]
