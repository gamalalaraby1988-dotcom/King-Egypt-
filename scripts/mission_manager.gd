extends Node
## مهام بأهداف حركة فعلية وتقدم خبرة محلي داخل جلسة اللعب.

var player: Node3D
var buildings: Array[Node3D] = []
var nearest_building: Node3D = null
var nearest_interactable: Node3D = null
var interact_button: Button
var active_mission: Node3D = null
var active_job: Node3D = null
var active_job_target: Vector3 = Vector3.ZERO
var active_job_reward: Dictionary = {}
var job_running := false
var landmark_navigation_active := false
var landmark_navigation_target: Vector3 = Vector3.ZERO
var landmark_navigation_name := ""
var landmark_navigation_key := ""
var landmark_route_points: PackedVector3Array = PackedVector3Array()
var landmark_route_index := 0
var navigation_arrival_remaining := 0.0
var navigation_off_route_time := 0.0
var navigation_route_notice_remaining := 0.0
var navigation_route_recalculated := false
const NAVIGATION_OFF_ROUTE_DISTANCE := 12.0
const NAVIGATION_OFF_ROUTE_CONFIRM_TIME := 1.25
var completed_jobs: Dictionary = {}
var selected_activity_kind := "mission"
var active_target: Vector3 = Vector3.ZERO
var mission_running := false
var completed_missions: Dictionary = {}
var player_level: int = 1
var xp: int = 0
var money: int = 0
var chips: int = 0
var reward_receipts: Dictionary = {}
var achievement_totals: Dictionary = {"jobs": 0, "missions": 0, "daily_claims": 0}
var achievement_events: Dictionary = {}
var achievement_stats_initialized := false
var daily_task_progress: Dictionary = {}
var daily_task_events: Dictionary = {}
var owned_outfits: Array = ["default"]

const VALID_OUTFIT_IDS := ["default", "men_formal", "women_formal", "urban_casual", "sport"]
const OUTFIT_PRICES := {"men_formal": 500, "women_formal": 500, "urban_casual": 300, "sport": 250}
const LEGACY_STORE_PATH := "user://kings_city_store.cfg"
var target_marker: MeshInstance3D
var daily_activities: Node
var achievement_manager: Node
var shop_manager: Node

var prompt_label: Label
var stats_label: Label
var panel: PanelContainer
var title_label: Label
var description_label: Label
var reward_label: Label
var status_label: Label
var accept_button: Button
var close_button: Button
var interior_return_button: Button
var interior_activities_button: Button
var interior_preview_active := false
var interior_preview_building: Node3D = null
var inside_building := false
var current_interior_root: Node3D = null
var saved_city_player_position := Vector3.ZERO
var loading_layer: CanvasLayer
var loading_panel: PanelContainer
var loading_label: Label
var interior_exit_button: Button
var navigation_label: Label
var navigation_arrow: Label
var navigation_cancel_button: Button
var animal_selector: OptionButton
var selected_animal_staff: Node3D = null
# معرف ثابت طوال نافذة التأجير الحالية؛ يمنع تكرار الخصم بسبب النقر المزدوج.
var active_rental_transaction_id: String = ""

var _key_was_down := false

const SAVE_PATH := "user://kings_city_profile.cfg"

func _ready() -> void:
	_build_ui()
	_create_target_marker()
	_load_profile()
	CityLanguage.language_changed.connect(_refresh_navigation_language)

func _exit_tree() -> void:
	if CityLanguage.language_changed.is_connected(_refresh_navigation_language):
		CityLanguage.language_changed.disconnect(_refresh_navigation_language)

func _refresh_navigation_language() -> void:
	if is_instance_valid(navigation_cancel_button):
		navigation_cancel_button.text = CityLanguage.translate("navigation_cancel")	
	if is_instance_valid(interior_activities_button):
		interior_activities_button.text = CityLanguage.translate("interior_view_activities")
	if is_instance_valid(interior_return_button):
		interior_return_button.text = CityLanguage.translate("interior_return")
	if is_instance_valid(interior_exit_button):
		interior_exit_button.text = CityLanguage.translate("interior_exit")
	if is_instance_valid(close_button):
		close_button.text = CityLanguage.translate("service_npc_close")
	if is_instance_valid(loading_label) and loading_layer.visible:
		loading_label.text = CityLanguage.translate("interior_loading")
	_update_interaction_hud()
	_update_navigation_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_profile()

func grant_reward_once(reward_id: String, money_amount: int = 0, xp_amount: int = 0, chips_amount: int = 0) -> bool:
	# يسجل الإيصال والمحفظة في ملف واحد؛ تكرار نفس المعرف لا يصرف المكافأة مجددًا.
	if reward_id.is_empty() or money_amount < 0 or xp_amount < 0 or chips_amount < 0 or reward_receipts.has(reward_id):
		return false
	var next_money := money + money_amount
	var next_xp := xp + xp_amount
	var next_chips := chips + chips_amount
	var next_level := player_level
	while next_xp >= next_level * 100:
		next_xp -= next_level * 100
		next_level += 1
	var next_receipts := reward_receipts.duplicate(true)
	next_receipts[reward_id] = Time.get_datetime_string_from_system()
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("ملف اللاعب موجود لكنه غير قابل للقراءة؛ أُوقفت إضافة المكافأة لحماية البيانات.")
		return false
	config.set_value("profile", "player_level", next_level)
	config.set_value("profile", "xp", next_xp)
	config.set_value("profile", "money", next_money)
	config.set_value("profile", "chips", next_chips)
	config.set_value("profile", "completed_missions", completed_missions)
	config.set_value("profile", "completed_jobs", completed_jobs)
	config.set_value("profile", "reward_receipts", next_receipts)
	config.set_value("profile", "owned_outfits", owned_outfits)
	config.set_value("profile", "achievement_totals", achievement_totals)
	config.set_value("profile", "achievement_events", achievement_events)
	config.set_value("profile", "achievement_stats_initialized", achievement_stats_initialized)
	config.set_value("profile", "daily_task_progress", daily_task_progress)
	config.set_value("profile", "daily_task_events", daily_task_events)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("تعذر حفظ المكافأة %s: %s" % [reward_id, error])
		return false
	money = next_money
	xp = next_xp
	chips = next_chips
	player_level = next_level
	reward_receipts = next_receipts
	return true

func record_achievement_event_once(event_id: String, stat_key: String) -> bool:
	# عدادات الإنجازات ومعرّفات أحداثها تحفظ داخل ملف اللاعب نفسه.
	# هذا يجعل تسجيل التقدم قابلًا لإعادة المحاولة دون مضاعفة العداد.
	if event_id.is_empty() or not ["jobs", "missions", "daily_claims"].has(stat_key):
		return false
	if achievement_events.has(event_id):
		return true
	var next_totals := achievement_totals.duplicate(true)
	var next_events := achievement_events.duplicate(true)
	next_totals[stat_key] = int(next_totals.get(stat_key, 0)) + 1
	next_events[event_id] = Time.get_datetime_string_from_system()
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("ملف اللاعب غير قابل للقراءة؛ لم يتم تسجيل تقدم الإنجاز.")
		return false
	config.set_value("profile", "player_level", player_level)
	config.set_value("profile", "xp", xp)
	config.set_value("profile", "money", money)
	config.set_value("profile", "chips", chips)
	config.set_value("profile", "completed_missions", completed_missions)
	config.set_value("profile", "completed_jobs", completed_jobs)
	config.set_value("profile", "reward_receipts", reward_receipts)
	config.set_value("profile", "owned_outfits", owned_outfits)
	config.set_value("profile", "achievement_totals", next_totals)
	config.set_value("profile", "achievement_events", next_events)
	config.set_value("profile", "achievement_stats_initialized", true)
	config.set_value("profile", "daily_task_progress", daily_task_progress)
	config.set_value("profile", "daily_task_events", daily_task_events)
	var save_error := config.save(SAVE_PATH)
	if save_error != OK:
		push_warning("تعذر حفظ حدث الإنجاز %s: %s" % [event_id, save_error])
		return false
	achievement_totals = next_totals
	achievement_events = next_events
	achievement_stats_initialized = true
	return true

func initialize_achievement_totals_if_missing(legacy_totals: Dictionary) -> bool:
	if achievement_stats_initialized:
		return true
	var migrated := {"jobs": maxi(0, int(legacy_totals.get("jobs", 0))), "missions": maxi(0, int(legacy_totals.get("missions", 0))), "daily_claims": maxi(0, int(legacy_totals.get("daily_claims", 0)))}
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("تعذر ترحيل عدادات الإنجازات لأن ملف اللاعب غير قابل للقراءة.")
		return false
	config.set_value("profile", "player_level", player_level)
	config.set_value("profile", "xp", xp)
	config.set_value("profile", "money", money)
	config.set_value("profile", "chips", chips)
	config.set_value("profile", "completed_missions", completed_missions)
	config.set_value("profile", "completed_jobs", completed_jobs)
	config.set_value("profile", "reward_receipts", reward_receipts)
	config.set_value("profile", "owned_outfits", owned_outfits)
	config.set_value("profile", "achievement_totals", migrated)
	config.set_value("profile", "achievement_events", achievement_events)
	config.set_value("profile", "achievement_stats_initialized", true)
	config.set_value("profile", "daily_task_progress", daily_task_progress)
	config.set_value("profile", "daily_task_events", daily_task_events)
	if config.save(SAVE_PATH) != OK:
		push_warning("تعذر حفظ ترحيل عدادات الإنجازات.")
		return false
	achievement_totals = migrated
	achievement_stats_initialized = true
	return true

func get_achievement_totals() -> Dictionary:
	return achievement_totals.duplicate(true)

func has_reward_receipt(reward_id: String) -> bool:
	return reward_receipts.has(reward_id)

func complete_activity_once(activity_id: String, activity_kind: String, money_amount: int = 0, xp_amount: int = 0, chips_amount: int = 0) -> bool:
	# حفظ إكمال النشاط وإيصال المكافأة والمحفظة في ملف واحد يمنع إعادة الصرف بعد إعادة التشغيل.
	if activity_id.is_empty() or money_amount < 0 or xp_amount < 0 or chips_amount < 0:
		return false
	var completion_key := activity_id
	var receipt_id := "activity_%s_%s" % [activity_kind, activity_id]
	var next_completed_missions := completed_missions.duplicate(true)
	var next_completed_jobs := completed_jobs.duplicate(true)
	if activity_kind == "mission":
		if next_completed_missions.has(completion_key):
			return false
		next_completed_missions[completion_key] = true
	elif activity_kind == "job":
		if next_completed_jobs.has(completion_key):
			return false
		next_completed_jobs[completion_key] = true
	else:
		return false
	if reward_receipts.has(receipt_id):
		return false
	var next_money := money + money_amount
	var next_xp := xp + xp_amount
	var next_chips := chips + chips_amount
	var next_level := player_level
	while next_xp >= next_level * 100:
		next_xp -= next_level * 100
		next_level += 1
	var next_receipts := reward_receipts.duplicate(true)
	next_receipts[receipt_id] = Time.get_datetime_string_from_system()
	var next_achievement_totals := achievement_totals.duplicate(true)
	var next_achievement_events := achievement_events.duplicate(true)
	var achievement_event_id := "%s:%s" % [activity_kind, activity_id]
	if not next_achievement_events.has(achievement_event_id):
		var stat_key := "jobs" if activity_kind == "job" else "missions"
		next_achievement_totals[stat_key] = int(next_achievement_totals.get(stat_key, 0)) + 1
		next_achievement_events[achievement_event_id] = Time.get_datetime_string_from_system()
	var next_daily_progress := daily_task_progress.duplicate(true)
	var next_daily_events := daily_task_events.duplicate(true)
	var today_key := Time.get_date_string_from_system()
	var daily_event_id := "%s:%s:%s" % [today_key, activity_kind, activity_id]
	if not next_daily_events.has(daily_event_id):
		var today_progress: Dictionary = next_daily_progress.get(today_key, {}).duplicate(true)
		var daily_stat_key := "job" if activity_kind == "job" else "mission"
		today_progress[daily_stat_key] = int(today_progress.get(daily_stat_key, 0)) + 1
		next_daily_progress[today_key] = today_progress
		next_daily_events[daily_event_id] = Time.get_datetime_string_from_system()
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("ملف اللاعب غير قابل للقراءة؛ لم يُعتمد إكمال النشاط أو مكافأته.")
		return false
	config.set_value("profile", "player_level", next_level)
	config.set_value("profile", "xp", next_xp)
	config.set_value("profile", "money", next_money)
	config.set_value("profile", "chips", next_chips)
	config.set_value("profile", "completed_missions", next_completed_missions)
	config.set_value("profile", "completed_jobs", next_completed_jobs)
	config.set_value("profile", "reward_receipts", next_receipts)
	config.set_value("profile", "owned_outfits", owned_outfits)
	config.set_value("profile", "achievement_totals", next_achievement_totals)
	config.set_value("profile", "achievement_events", next_achievement_events)
	config.set_value("profile", "achievement_stats_initialized", true)
	config.set_value("profile", "daily_task_progress", next_daily_progress)
	config.set_value("profile", "daily_task_events", next_daily_events)
	var save_error := config.save(SAVE_PATH)
	if save_error != OK:
		push_warning("تعذر حفظ إكمال النشاط %s: %s" % [activity_id, save_error])
		return false
	money = next_money
	xp = next_xp
	chips = next_chips
	player_level = next_level
	completed_missions = next_completed_missions
	completed_jobs = next_completed_jobs
	reward_receipts = next_receipts
	achievement_totals = next_achievement_totals
	achievement_events = next_achievement_events
	achievement_stats_initialized = true
	daily_task_progress = next_daily_progress
	daily_task_events = next_daily_events
	return true

func spend_money_once(transaction_id: String, amount: int) -> bool:
	# للمدفوعات التي لا يجوز تنفيذها مرتين بسبب النقر المتكرر أو إعادة المحاولة.
	if transaction_id.is_empty() or amount < 0 or money < amount:
		return false
	var receipt_id := "spend_%s" % transaction_id
	if reward_receipts.has(receipt_id):
		return false
	var next_receipts := reward_receipts.duplicate(true)
	next_receipts[receipt_id] = Time.get_datetime_string_from_system()
	var next_money := money - amount
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("ملف اللاعب غير قابل للقراءة؛ أُوقفت عملية الدفع.")
		return false
	config.set_value("profile", "player_level", player_level)
	config.set_value("profile", "xp", xp)
	config.set_value("profile", "money", next_money)
	config.set_value("profile", "chips", chips)
	config.set_value("profile", "completed_missions", completed_missions)
	config.set_value("profile", "completed_jobs", completed_jobs)
	config.set_value("profile", "reward_receipts", next_receipts)
	config.set_value("profile", "owned_outfits", owned_outfits)
	config.set_value("profile", "achievement_totals", achievement_totals)
	config.set_value("profile", "achievement_events", achievement_events)
	config.set_value("profile", "achievement_stats_initialized", achievement_stats_initialized)
	config.set_value("profile", "daily_task_progress", daily_task_progress)
	config.set_value("profile", "daily_task_events", daily_task_events)
	var save_error := config.save(SAVE_PATH)
	if save_error != OK:
		push_warning("تعذر حفظ عملية الدفع %s: %s" % [transaction_id, save_error])
		return false
	money = next_money
	reward_receipts = next_receipts
	return true

func get_daily_task_progress(day_id: String, task_id: String) -> int:
	var day_progress: Dictionary = daily_task_progress.get(day_id, {})
	return int(day_progress.get(task_id, 0))

func get_outfit_price(outfit_id: String) -> int:
	return int(OUTFIT_PRICES.get(outfit_id, -1))

func get_owned_outfits() -> Array:
	return owned_outfits.duplicate()

func purchase_outfit(outfit_id: String) -> bool:
	# السعر المرجعي داخل مدير اللاعب؛ لا يقبل سعرًا يمرره واجهة العميل.
	# هذا يمنع اختلاف سعر الواجهة عن قائمة الأسعار المعتمدة داخل المصدر.
	if not OUTFIT_PRICES.has(outfit_id):
		return false
	var price: int = int(OUTFIT_PRICES[outfit_id])
	if owned_outfits.has(outfit_id) or money < price:
		return false
	var next_owned := owned_outfits.duplicate()
	next_owned.append(outfit_id)
	var next_money := money - price
	var receipt_id := "purchase_outfit_%s" % outfit_id
	var next_receipts := reward_receipts.duplicate(true)
	if next_receipts.has(receipt_id):
		return false
	next_receipts[receipt_id] = Time.get_datetime_string_from_system()
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("ملف اللاعب موجود لكنه غير قابل للقراءة؛ أُوقف الشراء لحماية البيانات.")
		return false
	config.set_value("profile", "player_level", player_level)
	config.set_value("profile", "xp", xp)
	config.set_value("profile", "money", next_money)
	config.set_value("profile", "chips", chips)
	config.set_value("profile", "completed_missions", completed_missions)
	config.set_value("profile", "completed_jobs", completed_jobs)
	config.set_value("profile", "reward_receipts", next_receipts)
	config.set_value("profile", "owned_outfits", next_owned)
	config.set_value("profile", "achievement_totals", achievement_totals)
	config.set_value("profile", "achievement_events", achievement_events)
	config.set_value("profile", "achievement_stats_initialized", achievement_stats_initialized)
	config.set_value("profile", "daily_task_progress", daily_task_progress)
	config.set_value("profile", "daily_task_events", daily_task_events)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("تعذر حفظ شراء الإطلالة %s: %s" % [outfit_id, error])
		return false
	money = next_money
	owned_outfits = next_owned
	reward_receipts = next_receipts
	return true

func _save_profile() -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("ملف اللاعب غير قابل للقراءة؛ لم تتم الكتابة فوقه.")
		return false
	config.set_value("profile", "player_level", player_level)
	config.set_value("profile", "xp", xp)
	config.set_value("profile", "money", money)
	config.set_value("profile", "chips", chips)
	config.set_value("profile", "completed_missions", completed_missions)
	config.set_value("profile", "completed_jobs", completed_jobs)
	config.set_value("profile", "reward_receipts", reward_receipts)
	config.set_value("profile", "owned_outfits", owned_outfits)
	config.set_value("profile", "achievement_totals", achievement_totals)
	config.set_value("profile", "achievement_events", achievement_events)
	config.set_value("profile", "achievement_stats_initialized", achievement_stats_initialized)
	config.set_value("profile", "daily_task_progress", daily_task_progress)
	config.set_value("profile", "daily_task_events", daily_task_events)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("تعذر حفظ ملف اللاعب: %s" % error)
	return error == OK

func _load_profile() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("تعذر قراءة ملف اللاعب؛ تم إيقاف الترحيل لتجنب فقدان البيانات.")
		return
	if error == OK:
		player_level = _safe_profile_int(config.get_value("profile", "player_level", 1), 1, 1)
		xp = _safe_profile_int(config.get_value("profile", "xp", 0), 0)
		money = _safe_profile_int(config.get_value("profile", "money", 0), 0)
		chips = _safe_profile_int(config.get_value("profile", "chips", 0), 0)
		var saved_missions: Variant = config.get_value("profile", "completed_missions", {})
		var saved_jobs: Variant = config.get_value("profile", "completed_jobs", {})
		var saved_receipts: Variant = config.get_value("profile", "reward_receipts", {})
		var saved_totals: Variant = config.get_value("profile", "achievement_totals", achievement_totals)
		var saved_achievement_events: Variant = config.get_value("profile", "achievement_events", {})
		var saved_daily_progress: Variant = config.get_value("profile", "daily_task_progress", {})
		var saved_daily_events: Variant = config.get_value("profile", "daily_task_events", {})
		completed_missions = saved_missions if saved_missions is Dictionary else {}
		completed_jobs = saved_jobs if saved_jobs is Dictionary else {}
		reward_receipts = saved_receipts if saved_receipts is Dictionary else {}
		achievement_totals = {"jobs": 0, "missions": 0, "daily_claims": 0}
		if saved_totals is Dictionary:
			for stat_key in ["jobs", "missions", "daily_claims"]:
				achievement_totals[stat_key] = _safe_profile_int(saved_totals.get(stat_key, 0), 0)
		achievement_events = saved_achievement_events if saved_achievement_events is Dictionary else {}
		daily_task_progress = {}
		if saved_daily_progress is Dictionary:
			for day_key in saved_daily_progress:
				var day_value: Variant = saved_daily_progress[day_key]
				if day_value is Dictionary:
					var clean_day: Dictionary = {}
					for task_key in day_value:
						var task_value: Variant = day_value[task_key]
						if (task_value is int or task_value is float) and is_finite(float(task_value)):
							clean_day[str(task_key)] = clampi(int(task_value), 0, 1000000)
					daily_task_progress[str(day_key)] = clean_day
		daily_task_events = saved_daily_events if saved_daily_events is Dictionary else {}
		achievement_stats_initialized = bool(config.get_value("profile", "achievement_stats_initialized", false))
	var saved_owned = config.get_value("profile", "owned_outfits", null) if error == OK else null
	if saved_owned is Array:
		owned_outfits = _sanitize_owned_outfits(saved_owned)
	else:
		# ترحيل ملكيات النسخ السابقة من ملف المتجر القديم دون فقدانها.
		var legacy := ConfigFile.new()
		if legacy.load(LEGACY_STORE_PATH) == OK:
			var legacy_owned = legacy.get_value("store", "owned_outfits", ["default"])
			owned_outfits = _sanitize_owned_outfits(legacy_owned if legacy_owned is Array else ["default"])
		else:
			owned_outfits = ["default"]
		# اكتب البنية الموحدة حتى للحساب الجديد، أو بعد ترحيل ملف قديم.
		_save_profile()

func _safe_profile_int(value: Variant, fallback: int, minimum: int = 0) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampi(int(value), minimum, 2000000000)

func _sanitize_owned_outfits(items: Array) -> Array:
	var result: Array = ["default"]
	for item in items:
		var item_id := str(item)
		if VALID_OUTFIT_IDS.has(item_id) and not result.has(item_id):
			result.append(item_id)
	return result

func register_building(building: Node3D) -> void:
	buildings.append(building)

func _process(_delta: float) -> void:
	if navigation_arrival_remaining > 0.0:
		navigation_arrival_remaining = maxf(navigation_arrival_remaining - _delta, 0.0)
	if navigation_route_notice_remaining > 0.0:
		navigation_route_notice_remaining = maxf(navigation_route_notice_remaining - _delta, 0.0)
	if not is_instance_valid(player):
		return
	_update_interaction_target()
	_update_interaction_hud()
	if Input.is_key_pressed(KEY_E) and not _key_was_down and not mission_running and not job_running:
		interact()
	_key_was_down = Input.is_key_pressed(KEY_E)

	stats_label.text = "المستوى %d  |  الخبرة %d  |  المال %d  |  الرقائق %d" % [player_level, xp, money, chips]
	if job_running:
		var job_distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
		status_label.text = "الوظيفة: توجّه إلى نقطة العمل. المتبقي: %.1f متر" % job_distance
		if job_distance <= 2.2:
			_complete_active_job()
	if mission_running:
		var distance_to_target := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(active_target.x, active_target.z))
		status_label.text = "الهدف: اذهب إلى علامة المهمة. المسافة المتبقية: %.1f متر" % distance_to_target
		if distance_to_target <= 2.2:
			_complete_active_mission()
	_update_navigation_hud()


func _update_interaction_target() -> void:
	if inside_building:
		nearest_interactable = null
		nearest_building = null
		return
	var previous_target := nearest_interactable
	var best: Node3D = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("city_interactables"):
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate is Node3D:
			continue
		var radius_value: Variant = candidate.get("interaction_radius")
		var allowed_distance := float(radius_value) if radius_value != null else 4.5
		allowed_distance = clampf(allowed_distance, 0.5, 4.8)
		# هامش خروج صغير للهدف الحالي يمنع وميض زر التفاعل عند حافة النطاق.
		if candidate == previous_target:
			allowed_distance += 0.65
		var distance := player.global_position.distance_to(candidate.global_position)
		if distance <= allowed_distance and distance < best_distance:
			best_distance = distance
			best = candidate
	nearest_interactable = best
	nearest_building = best if is_instance_valid(best) and best.has_method("get_mission_data") else null

func _interaction_action_key(target: Node3D) -> String:
	if target.has_method("get_job_data"):
		return "interaction_job"
	if target.has_method("get_mission_data"):
		return "interaction_enter"
	if target.has_method("get_animal_rental_data"):
		return "interaction_rent"
	if target.has_method("is_shop_owner") and target.is_shop_owner():
		return "interaction_shop"
	return "interaction_talk"

func _update_interaction_hud() -> void:
	if not is_instance_valid(interact_button) or not is_instance_valid(prompt_label):
		return
	if is_instance_valid(player) and player.has_method("is_riding_animal") and player.is_riding_animal():
		prompt_label.text = CityLanguage.translate("interaction_riding_prompt")
		interact_button.text = CityLanguage.translate("interaction_dismount")
		interact_button.visible = true
	elif is_instance_valid(nearest_interactable):
		var display_name := CityLanguage.translate("interaction_place")
		if nearest_interactable.has_method("get_job_data"):
			display_name = str(nearest_interactable.get_job_data().get("title", CityLanguage.translate("interaction_job_name")))
		elif nearest_building:
			display_name = str(nearest_interactable.get("building_title"))
		elif nearest_interactable.has_method("get_animal_rental_data"):
			display_name = CityLanguage.translate("interaction_animal_staff")
		elif nearest_interactable.has_method("get_interaction_data"):
			var interaction_data: Dictionary = nearest_interactable.get_interaction_data()
			display_name = str(interaction_data.get("title", nearest_interactable.get("character_name")))
		else:
			display_name = str(nearest_interactable.get("character_name"))
		interact_button.text = CityLanguage.translate(_interaction_action_key(nearest_interactable))
		prompt_label.text = "%s %s — %s" % [CityLanguage.translate("interaction_near"), display_name, CityLanguage.translate("interaction_press_hint")]
		interact_button.visible = true
	else:
		prompt_label.text = CityLanguage.translate("interaction_approach")
		interact_button.text = CityLanguage.translate("interaction_button")
		interact_button.visible = false

func interact() -> void:
	_update_interaction_target()
	if is_instance_valid(player) and player.has_method("is_riding_animal") and player.is_riding_animal():
		player.end_animal_ride()
		prompt_label.text = CityLanguage.translate("interaction_dismounted")
		_update_interaction_hud()
		return
	if mission_running or job_running:
		panel.visible = true
	elif is_instance_valid(nearest_interactable):
		open_interactable(nearest_interactable)

func open_interactable(target: Node3D) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not is_instance_valid(player):
		return
	var radius_value: Variant = target.get("interaction_radius")
	var allowed_distance := float(radius_value) if radius_value != null else 4.5
	if player.global_position.distance_to(target.global_position) > clampf(allowed_distance, 0.5, 4.8) + 0.65:
		_update_interaction_target()
		return
	if target.has_method("is_shop_owner") and target.is_shop_owner() and is_instance_valid(shop_manager):
		shop_manager.open_shop()
		return
	if target.has_method("get_animal_rental_data"):
		open_animal_rental(target)
		return
	if target.has_method("get_job_data"):
		open_job(target)
		return
	if target.has_method("get_mission_data"):
		open_building(target)
		return
	if target.has_method("get_interaction_data"):
		animal_selector.visible = false
		var info: Dictionary = target.get_interaction_data()
		active_mission = null
		title_label.text = str(info.get("title", "شخصية"))
		description_label.text = str(info.get("description", ""))
		reward_label.text = CityLanguage.translate("service_npc_no_rewards")
		status_label.text = CityLanguage.translate("service_npc_dialogue_status")
		accept_button.visible = false
		panel.visible = true

func open_animal_rental(staff: Node3D) -> void:
	selected_animal_staff = staff
	selected_activity_kind = "animal_rental"
	# يُنشأ المعرف عند فتح نافذة جديدة، لا عند الضغط على زر الدفع؛
	# تكرار إشارة الزر داخل النافذة نفسها سيصطدم بالإيصال نفسه.
	active_rental_transaction_id = "animal_rental_%s" % str(Time.get_ticks_usec())
	var data: Dictionary = staff.get_animal_rental_data()
	title_label.text = str(data.get("title", "موظف حيوانات المخيم"))
	description_label.text = str(data.get("description", "اختر حيوانًا للركوب."))	
	animal_selector.clear()
	for animal_name in data.get("animals", []):
		animal_selector.add_item(str(animal_name))
	if animal_selector.item_count > 0:
		animal_selector.select(0)
	animal_selector.visible = true
	var price := int(data.get("price", 25))
	reward_label.text = "أجرة الركوب: %d جنيه من مال اللعبة" % price
	if is_instance_valid(player) and player.has_method("is_riding_animal") and player.is_riding_animal():
		status_label.text = "أنت تركب حيوانًا بالفعل. انزل أولًا قبل استئجار حيوان آخر."
		accept_button.disabled = true
	elif money < price:
		status_label.text = "رصيدك لا يكفي. رصيدك الحالي: %d جنيه." % money
		accept_button.disabled = true
	else:
		status_label.text = "اختر الحيوان ثم اضغط دفع وركوب. الركوب متاح لجميع اللاعبين."
		accept_button.disabled = false
	accept_button.text = "دفع وركوب"
	panel.visible = true

func _rent_selected_animal() -> void:
	if not is_instance_valid(selected_animal_staff) or not is_instance_valid(player):
		return
	if player.has_method("is_riding_animal") and player.is_riding_animal():
		status_label.text = "انزل من الحيوان الحالي قبل استئجار حيوان آخر."
		accept_button.disabled = true
		return
	if active_rental_transaction_id.is_empty():
		status_label.text = "انتهت جلسة التأجير. أغلق النافذة وافتحها مرة أخرى."
		accept_button.disabled = true
		return
	var data: Dictionary = selected_animal_staff.get_animal_rental_data()
	var price := int(data.get("price", 25))
	if money < price:
		status_label.text = "لا يوجد مال كافٍ لدفع أجرة الركوب."
		accept_button.disabled = true
		return
	var animals: Array = data.get("animals", [])
	if animals.is_empty():
		status_label.text = "لا توجد حيوانات متاحة حاليًا."
		return
	var index := clampi(animal_selector.selected, 0, animals.size() - 1)
	var animal_name := str(animals[index])
	if not player.start_animal_ride(animal_name):
		status_label.text = "تعذر بدء الركوب؛ لم يتم خصم المال. حاول مرة أخرى."
		return
	if not spend_money_once(active_rental_transaction_id, price):
		player.end_animal_ride()
		status_label.text = "تعذر حفظ أجرة الركوب؛ لم يتم خصم المال. حاول مرة أخرى."
		return
	stats_label.text = "المستوى %d  |  الخبرة %d  |  المال %d  |  الرقائق %d" % [player_level, xp, money, chips]
	status_label.text = "دفعت %d جنيه وبدأت ركوب %s. اضغط زر تفاعل للنزول." % [price, animal_name]
	description_label.text = "يمكنك التجول بالحيوان في المخيم والمدينة."
	reward_label.text = "تم خصم أجرة الركوب من رصيدك."
	accept_button.disabled = true
	panel.visible = true

func open_job(job_board: Node3D) -> void:
	animal_selector.visible = false
	if mission_running or job_running:
		return
	active_job = job_board
	active_mission = null
	var data: Dictionary = job_board.get_job_data()
	selected_activity_kind = "job"
	title_label.text = "وظيفة | " + str(data.get("title", "عمل متاح"))
	description_label.text = str(data.get("description", "نفّذ العمل المحدد في المدينة."))
	reward_label.text = "أجر الوظيفة: %d جنيه | %d رقائق | %d خبرة" % [int(data.get("money", 0)), int(data.get("chips", 0)), int(data.get("xp", 0))]
	var key := str(data.get("job_id", job_board.name))
	if completed_jobs.has(key):
		status_label.text = "أنجزت هذه الوظيفة بالفعل."
		accept_button.disabled = true
	elif player_level < int(data.get("level", 1)):
		status_label.text = "المستوى المطلوب لهذه الوظيفة: %d" % int(data.get("level", 1))
		accept_button.disabled = true
	else:
		status_label.text = "اقبل الوظيفة ثم توجّه إلى نقطة العمل الظاهرة في المدينة."
		accept_button.disabled = false
	accept_button.text = "قبول الوظيفة"
	panel.visible = true

func open_building(building: Node3D) -> void:
	if not is_instance_valid(building) or building.is_queued_for_deletion() or mission_running:
		return
	animal_selector.visible = false
	selected_activity_kind = "mission"
	active_mission = building
	var data: Dictionary = building.get_mission_data()
	if bool(data.get("requires_interior", false)):
		interior_preview_active = false
		interior_preview_building = building
		var city_root := get_tree().current_scene
		if is_instance_valid(city_root) and city_root.has_method("enter_building_interior"):
			interact_button.visible = false
			city_root.enter_building_interior(building, player)
		else:
			status_label.text = CityLanguage.translate("interior_transition_unavailable")
			panel.visible = true
		return
	interior_preview_active = false
	interior_preview_building = null
	interior_activities_button.visible = false
	interior_return_button.visible = false
	accept_button.visible = true
	title_label.text = "%s | %s" % [building.building_title, data["title"]]
	description_label.text = data["description"]
	if str(data.get("activities", "")).strip_edges() != "":
		description_label.text += "\nالأنشطة: " + str(data["activities"])
	reward_label.text = "المكافأة: %d جنيه | %d رقائق | %d خبرة" % [data["money"], data["chips"], data["xp"]]
	var key: String = str(building.get("building_id"))
	if completed_missions.has(key):
		status_label.text = "أنجزت هذه المهمة بالفعل في هذه الجلسة."
		accept_button.disabled = true
	elif player_level < int(data["level"]):
		status_label.text = "المستوى المطلوب: %d" % int(data["level"])
		accept_button.disabled = true
	else:
		status_label.text = "اقبل المهمة ثم اتبع علامة الهدف لإكمالها."
		accept_button.disabled = false
	accept_button.text = "بدء المهمة"
	panel.visible = true

func _show_building_activities() -> void:
	if not is_instance_valid(interior_preview_building) or interior_preview_building.is_queued_for_deletion():
		_close_interior_preview()
		return
	var building := interior_preview_building
	interior_preview_active = false
	interior_preview_building = null
	open_building_activities(building)

func open_building_activities(building: Node3D) -> void:
	var data: Dictionary = building.get_mission_data()
	interior_activities_button.visible = false
	interior_return_button.visible = false
	accept_button.visible = true
	title_label.text = "%s | %s" % [building.building_title, data["title"]]
	description_label.text = str(data.get("description", "")) + "\n" + str(data.get("activities", ""))
	reward_label.text = "المكافأة: %d جنيه | %d رقائق | %d خبرة" % [data["money"], data["chips"], data["xp"]]
	status_label.text = CityLanguage.translate("interior_activity_status")
	accept_button.disabled = completed_missions.has(str(building.building_id)) or player_level < int(data.get("level", 1))
	accept_button.text = "بدء المهمة"
	panel.visible = true

func _close_interaction_panel() -> void:
	accept_button.visible = true
	interior_preview_active = false
	interior_preview_building = null
	interior_activities_button.visible = false
	interior_return_button.visible = false
	accept_button.visible = true
	panel.visible = false

func _create_loading_ui() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.name = "BuildingLoadingScreen"
	loading_layer.layer = 30
	add_child(loading_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.055, 0.075, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(shade)
	loading_panel = PanelContainer.new()
	loading_panel.set_anchors_preset(Control.PRESET_CENTER)
	loading_panel.offset_left = -190
	loading_panel.offset_top = -75
	loading_panel.offset_right = 190
	loading_panel.offset_bottom = 75
	shade.add_child(loading_panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	loading_panel.add_child(content)
	loading_label = Label.new()
	loading_label.text = CityLanguage.translate("interior_loading")
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 22)
	content.add_child(loading_label)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(300, 16)
	progress.show_percentage = false
	progress.value = 100
	content.add_child(progress)
	loading_layer.visible = false

func _set_city_world_visible(is_visible: bool) -> void:
	for node in get_tree().get_nodes_in_group("city_world_geometry"):
		if not is_instance_valid(node):
			continue
		if node is VisualInstance3D:
			node.visible = is_visible
		if node is StaticBody3D:
			node.collision_layer = 1 if is_visible else 0
			node.collision_mask = 1 if is_visible else 0

func _enter_building(building: Node3D) -> void:
	if inside_building or not is_instance_valid(building) or building.is_queued_for_deletion():
		return
	var radius_value: Variant = building.get("interaction_radius")
	var allowed_distance := float(radius_value) if radius_value != null else 4.5
	if not is_instance_valid(player) or player.global_position.distance_to(building.global_position) > clampf(allowed_distance, 0.5, 4.8) + 0.65:
		_update_interaction_target()
		return
	var city_root := get_tree().current_scene
	if not is_instance_valid(city_root):
		return
	saved_city_player_position = player.global_position
	panel.visible = false
	interact_button.visible = false
	loading_layer.visible = true
	loading_label.text = CityLanguage.translate("interior_loading")
	await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(building) or building.is_queued_for_deletion():
		loading_layer.visible = false
		return
	_set_city_world_visible(false)
	current_interior_root = Node3D.new()
	current_interior_root.name = "GeneratedBuildingInterior"
	city_root.add_child(current_interior_root)
	var localized_building_name := str(building.get("building_title"))
	if localized_building_name == "المتجر":
		localized_building_name = CityLanguage.translate("shop")
	elif localized_building_name == "المطعم":
		localized_building_name = CityLanguage.translate("restaurant")
	elif localized_building_name == "مركز التوظيف":
		localized_building_name = CityLanguage.translate("employment")
	_create_basic_interior(current_interior_root, localized_building_name)
	player.global_position = Vector3(0, 1.0, 2.0)
	player.velocity = Vector3.ZERO
	inside_building = true
	interior_exit_button.visible = true
	loading_layer.visible = false
	_update_interaction_hud()

func _create_basic_interior(root: Node3D, building_name: String) -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(14, 0.3, 14)
	_add_interior_box(root, "InteriorFloor", floor_mesh, Vector3(0, -0.2, 0), Color(0.63, 0.53, 0.38), true)
	_add_interior_box(root, "BackWall", _box_mesh(Vector3(14, 5, 0.35)), Vector3(0, 2.3, -7), Color(0.73, 0.65, 0.49), true)
	_add_interior_box(root, "LeftWall", _box_mesh(Vector3(0.35, 5, 14)), Vector3(-7, 2.3, 0), Color(0.69, 0.59, 0.43), true)
	_add_interior_box(root, "RightWall", _box_mesh(Vector3(0.35, 5, 14)), Vector3(7, 2.3, 0), Color(0.69, 0.59, 0.43), true)
	_add_interior_box(root, "FrontLeftWall", _box_mesh(Vector3(5.2, 5, 0.35)), Vector3(-4.4, 2.3, 7), Color(0.73, 0.65, 0.49), true)
	_add_interior_box(root, "FrontRightWall", _box_mesh(Vector3(5.2, 5, 0.35)), Vector3(4.4, 2.3, 7), Color(0.73, 0.65, 0.49), true)
	_add_interior_box(root, "CeilingTrim", _box_mesh(Vector3(14, 0.25, 14)), Vector3(0, 4.85, 0), Color(0.17, 0.23, 0.24), false)
	_add_interior_box(root, "WelcomeCounter", _box_mesh(Vector3(3.2, 1.1, 0.8)), Vector3(0, 0.55, -3.5), Color(0.28, 0.22, 0.16), false)
	var title := Label3D.new()
	title.text = building_name
	title.position = Vector3(0, 3.2, -6.75)
	title.font_size = 42
	title.modulate = Color(0.95, 0.79, 0.42)
	root.add_child(title)

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _add_interior_box(root: Node3D, node_name: String, mesh: BoxMesh, pos: Vector3, color: Color, collision: bool) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	visual.material_override = material
	root.add_child(visual)
	if collision:
		var body := StaticBody3D.new()
		body.position = pos
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		shape_node.shape = shape
		body.add_child(shape_node)
		root.add_child(body)

func _exit_building() -> void:
	if not inside_building or not is_instance_valid(player):
		return
	loading_layer.visible = true
	loading_label.text = CityLanguage.translate("interior_city_loading")
	interior_exit_button.visible = false
	await get_tree().create_timer(0.75).timeout
	if is_instance_valid(current_interior_root):
		current_interior_root.queue_free()
	current_interior_root = null
	_set_city_world_visible(true)
	player.global_position = saved_city_player_position
	player.velocity = Vector3.ZERO
	inside_building = false
	loading_layer.visible = false
	_update_interaction_target()
	_update_interaction_hud()

func _close_interior_preview() -> void:
	interior_preview_active = false
	interior_preview_building = null
	interior_activities_button.visible = false
	interior_return_button.visible = false
	accept_button.visible = true
	panel.visible = false

func _accept_selected_activity() -> void:
	if selected_activity_kind == "animal_rental":
		_rent_selected_animal()
	elif selected_activity_kind == "job":
		_accept_job()
	else:
		_accept_mission()

func _accept_job() -> void:
	if not is_instance_valid(active_job) or mission_running or job_running:
		return
	landmark_navigation_active = false
	navigation_arrival_remaining = 0.0
	var data: Dictionary = active_job.get_job_data()
	var key := str(data.get("job_id", active_job.name))
	if completed_jobs.has(key) or player_level < int(data.get("level", 1)):
		return
	active_job_target = active_job.global_position + data.get("target_offset", Vector3(0, 0, -10))
	active_job_target.y = 0.15
	active_job_reward = data.duplicate(true)
	job_running = true
	target_marker.global_position = active_job_target
	target_marker.visible = true
	accept_button.disabled = true
	description_label.text = "بدأت الوظيفة! اتبع علامة العمل حتى تصل إلى الموقع المطلوب."
	reward_label.text = "الأجر عند إتمام العمل: %d جنيه | %d رقائق | %d خبرة" % [int(data.get("money", 0)), int(data.get("chips", 0)), int(data.get("xp", 0))]
	status_label.text = "توجّه إلى نقطة العمل."

func _complete_active_job() -> void:
	if not job_running:
		return
	var key := str(active_job_reward.get("job_id", active_job.name if is_instance_valid(active_job) else "job"))
	var saved := complete_activity_once(key, "job", int(active_job_reward.get("money", 0)), int(active_job_reward.get("xp", 0)), int(active_job_reward.get("chips", 0)))
	if not saved:
		job_running = false
		target_marker.visible = false
		status_label.text = "لم يتم حفظ إكمال الوظيفة؛ لم تُصرف المكافأة. افتح الوظيفة وحاول مرة أخرى."
		accept_button.disabled = false
		panel.visible = true
		return
	if is_instance_valid(daily_activities):
		daily_activities.record_job_completed(key)
	if is_instance_valid(achievement_manager):
		achievement_manager.record_job_completed(key)
	job_running = false
	target_marker.visible = false
	status_label.text = "أتممت الوظيفة واستلمت أجرك!"
	description_label.text = "رصيدك الحالي: %d جنيه، %d رقائق، المستوى %d." % [money, chips, player_level]
	reward_label.text = "تم حفظ إكمال الوظيفة ومكافأتها."
	accept_button.disabled = true
	panel.visible = true

func _accept_mission() -> void:
	if not is_instance_valid(active_mission) or mission_running:
		return
	landmark_navigation_active = false
	navigation_arrival_remaining = 0.0
	var data: Dictionary = active_mission.get_mission_data()
	var key: String = str(active_mission.get("building_id"))
	if completed_missions.has(key) or player_level < int(data["level"]):
		return
	active_target = active_mission.global_position + data["target_offset"]
	active_target.y = 0.15
	mission_running = true
	target_marker.global_position = active_target
	target_marker.visible = true
	accept_button.disabled = true
	status_label.text = "بدأت المهمة! اتبع علامة الهدف الصفراء."
	description_label.text = "تحرك إلى نقطة الهدف المحددة في المدينة لإكمال المهمة."
	reward_label.text = "المكافأة عند الوصول: %d جنيه | %d رقائق | %d خبرة" % [data["money"], data["chips"], data["xp"]]

func _complete_active_mission() -> void:
	if not mission_running or not is_instance_valid(active_mission):
		return
	var data: Dictionary = active_mission.get_mission_data()
	var key: String = str(active_mission.get("building_id"))
	var saved := complete_activity_once(key, "mission", int(data["money"]), int(data["xp"]), int(data["chips"]))
	if not saved:
		mission_running = false
		target_marker.visible = false
		status_label.text = "لم يتم حفظ إكمال المهمة؛ لم تُصرف المكافأة. ابدأ المهمة مجددًا للمحاولة."
		accept_button.disabled = false
		panel.visible = true
		return
	if is_instance_valid(daily_activities):
		daily_activities.record_mission_completed(key)
	if is_instance_valid(achievement_manager):
		achievement_manager.record_mission_completed(key)
	mission_running = false
	target_marker.visible = false
	status_label.text = "اكتملت المهمة! تم حفظ المكافأة."
	description_label.text = "رصيدك الحالي: %d جنيه، %d رقائق، المستوى %d." % [money, chips, player_level]
	reward_label.text = "تم حفظ إكمال المهمة ومكافآتها."
	accept_button.disabled = true
	panel.visible = true

func _update_navigation_hud() -> void:
	var navigating := mission_running or job_running or landmark_navigation_active or navigation_arrival_remaining > 0.0
	if not is_instance_valid(navigation_label) or not is_instance_valid(navigation_arrow) or not is_instance_valid(navigation_cancel_button):
		return
	navigation_label.visible = navigating
	navigation_arrow.visible = navigating
	navigation_cancel_button.visible = navigating
	if not navigating or not is_instance_valid(player):
		return
	if navigation_arrival_remaining > 0.0 and not mission_running and not job_running and not landmark_navigation_active:
		navigation_label.text = "%s %s" % [CityLanguage.translate("navigation_arrived"), CityLanguage.translate(landmark_navigation_key)]
		navigation_arrow.visible = false
		navigation_cancel_button.visible = false
		return
	var destination := active_job_target if job_running else active_target if mission_running else landmark_navigation_target
	var destination_name := str(active_job_reward.get("title", "نقطة العمل")) if job_running else str(active_mission.get("building_title")) if mission_running and is_instance_valid(active_mission) else CityLanguage.translate(landmark_navigation_key) if landmark_navigation_active else "هدف المهمة"
	var guidance_target := destination
	var distance := Vector2(destination.x - player.global_position.x, destination.z - player.global_position.z).length()
	if landmark_navigation_active and not mission_running and not job_running:
		_advance_landmark_route()
		if landmark_route_index < landmark_route_points.size():
			guidance_target = landmark_route_points[landmark_route_index]
		distance = _remaining_landmark_route_distance()
		_update_landmark_route_deviation()
		if navigation_route_notice_remaining > 0.0:
			navigation_label.text = CityLanguage.translate("navigation_recalculating")
			navigation_arrow.visible = true
			return
	var delta := guidance_target - player.global_position
	var target_angle := atan2(delta.x, -delta.z)
	var player_heading := player.global_rotation.y
	var relative_angle := wrapf(target_angle - player_heading, -PI, PI)
	navigation_arrow.rotation = relative_angle
	navigation_label.text = "%s %s   |   %s: %.0f م" % [CityLanguage.translate("navigation_destination"), destination_name, CityLanguage.translate("navigation_distance"), distance] if landmark_navigation_active and not mission_running and not job_running else "الوجهة: %s   |   المسافة: %.0f م" % [destination_name, distance]
	if landmark_navigation_active and not mission_running and not job_running and Vector2(destination.x - player.global_position.x, destination.z - player.global_position.z).length() <= 2.0:
		landmark_navigation_active = false
		landmark_route_points.clear()
		landmark_route_index = 0
		navigation_arrival_remaining = 2.5
		navigation_label.text = "%s %s" % [CityLanguage.translate("navigation_arrived"), CityLanguage.translate(landmark_navigation_key)]
		navigation_arrow.visible = false
		navigation_cancel_button.visible = false

func _update_landmark_route_deviation() -> void:
	if not landmark_navigation_active or landmark_route_points.size() < 2 or not is_instance_valid(player):
		navigation_off_route_time = 0.0
		return
	var distance_from_route := _distance_to_remaining_route(player.global_position)
	if distance_from_route > NAVIGATION_OFF_ROUTE_DISTANCE:
		navigation_off_route_time += get_process_delta_time()
	else:
		navigation_off_route_time = maxf(navigation_off_route_time - get_process_delta_time() * 2.0, 0.0)
	if navigation_off_route_time < NAVIGATION_OFF_ROUTE_CONFIRM_TIME:
		return
	_build_landmark_route(landmark_navigation_target, landmark_navigation_key)
	navigation_off_route_time = 0.0
	navigation_route_notice_remaining = 2.0
	navigation_route_recalculated = true

func _distance_to_remaining_route(position_3d: Vector3) -> float:
	if landmark_route_points.size() < 2:
		return 0.0
	var closest_distance := INF
	for index in range(maxi(landmark_route_index, 0), landmark_route_points.size() - 1):
		var a: Vector2 = Vector2(landmark_route_points[index].x, landmark_route_points[index].z)
		var b: Vector2 = Vector2(landmark_route_points[index + 1].x, landmark_route_points[index + 1].z)
		var p := Vector2(position_3d.x, position_3d.z)
		var segment := b - a
		var denominator := segment.length_squared()
		var weight := 0.0 if denominator <= 0.0001 else clampf((p - a).dot(segment) / denominator, 0.0, 1.0)
		closest_distance = minf(closest_distance, p.distance_to(a + segment * weight))
	return closest_distance

const CITY_ROAD_COORDS := [-72.0, -24.0, 0.0, 24.0, 72.0]

# نقاط الوقوف عند أبواب المباني ولوحات الوظائف، لا عند مركز كتلة المبنى.
# المواقع متوافقة مع إحداثيات الإنشاء الحالية في main.gd.
const CITY_LANDMARK_ENTRANCES := {
	"shop": Vector3(16.0, 0.0, 21.0),
	"restaurant": Vector3(-16.0, 0.0, 21.0),
	"employment": Vector3(16.0, 0.0, -11.0),
	"delivery": Vector3(24.0, 0.0, 2.5),
	"city_guide": Vector3(-24.0, 0.0, 2.5),
	"maintenance": Vector3(0.0, 0.0, 26.5),
	"animal_camp": Vector3(60.0, 0.0, 75.0)
}

func get_landmark_entrance(landmark_key: String, fallback: Vector3) -> Vector3:
	return CITY_LANDMARK_ENTRANCES.get(landmark_key, fallback)

func _build_landmark_route(destination: Vector3, landmark_key: String) -> void:
	landmark_route_points.clear()
	landmark_route_index = 0
	if not is_instance_valid(player):
		landmark_route_points.append(destination)
		return
	var start := player.global_position
	var start_node := _nearest_city_road_node(start)
	landmark_route_points.append(Vector3(start.x, 0.0, start.z))
	landmark_route_points.append(Vector3(start_node.x, 0.0, start_node.y))
	if landmark_key == "animal_camp":
		# نصل أولًا إلى مدخل طريق المخيم، ثم نتبع مقاطعه المنشأة في المشهد.
		var camp_entry := Vector2(24.0, 0.0)
		_append_grid_route(start_node, camp_entry)
		landmark_route_points.append(Vector3(30.0, 0.0, 0.0))
		landmark_route_points.append(Vector3(30.0, 0.0, 75.0))
		landmark_route_points.append(Vector3(45.0, 0.0, 75.0))
		landmark_route_points.append(destination)
	else:
		var target_node := _nearest_city_road_node(destination)
		_append_grid_route(start_node, target_node)
		landmark_route_points.append(destination)
	# إزالة النقاط المتطابقة وتوحيد ارتفاع نقاط الملاحة.
	var compact := PackedVector3Array()
	for point in landmark_route_points:
		var flat_point := Vector3(point.x, 0.0, point.z)
		if compact.is_empty() or compact[compact.size() - 1].distance_to(flat_point) > 0.5:
			compact.append(flat_point)
	landmark_route_points = compact
	landmark_route_index = 0

func _nearest_city_road_node(position_3d: Vector3) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for road_x in CITY_ROAD_COORDS:
		for road_z in CITY_ROAD_COORDS:
			var candidate := Vector2(float(road_x), float(road_z))
			var distance := Vector2(position_3d.x, position_3d.z).distance_to(candidate)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best

func _append_grid_route(start_node: Vector2, target_node: Vector2) -> void:
	var nodes: Array[Vector2] = []
	for road_x in CITY_ROAD_COORDS:
		for road_z in CITY_ROAD_COORDS:
			nodes.append(Vector2(float(road_x), float(road_z)))
	var distances: Dictionary = {}
	var previous: Dictionary = {}
	var unvisited: Array[Vector2] = nodes.duplicate()
	for node in nodes:
		distances[node] = INF
	distances[start_node] = 0.0
	while not unvisited.is_empty():
		var current := unvisited[0]
		for candidate in unvisited:
			if float(distances[candidate]) < float(distances[current]):
				current = candidate
		if float(distances[current]) == INF:
			break
		unvisited.erase(current)
		if current == target_node:
			break
		for neighbor in nodes:
			if not unvisited.has(neighbor):
				continue
			var delta := neighbor - current
			var connected := (absf(delta.x) < 0.1 and absf(delta.y) <= 48.1) or (absf(delta.y) < 0.1 and absf(delta.x) <= 48.1)
			if not connected:
				continue
			var alternative := float(distances[current]) + delta.length()
			if alternative < float(distances[neighbor]):
				distances[neighbor] = alternative
				previous[neighbor] = current
	var reversed_path: Array[Vector2] = [target_node]
	var cursor := target_node
	while cursor != start_node and previous.has(cursor):
		cursor = previous[cursor]
		reversed_path.append(cursor)
	reversed_path.reverse()
	for node in reversed_path:
		landmark_route_points.append(Vector3(node.x, 0.0, node.y))

func _route_points_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		var previous: Vector3 = points[index - 1]
		var current: Vector3 = points[index]
		total += Vector2(current.x - previous.x, current.z - previous.z).length()
	return total

func _advance_landmark_route() -> void:
	while landmark_route_index < landmark_route_points.size():
		var waypoint := landmark_route_points[landmark_route_index]
		if Vector2(waypoint.x - player.global_position.x, waypoint.z - player.global_position.z).length() > 3.0:
			break
		landmark_route_index += 1

func _remaining_landmark_route_distance() -> float:
	if not is_instance_valid(player):
		return 0.0
	var total := 0.0
	var previous := player.global_position
	for index in range(landmark_route_index, landmark_route_points.size()):
		var point: Vector3 = landmark_route_points[index]
		total += Vector2(point.x - previous.x, point.z - previous.z).length()
		previous = point
	return total

func get_landmark_route_points() -> PackedVector3Array:
	var result := PackedVector3Array()
	if not landmark_navigation_active or not is_instance_valid(player):
		return result
	result.append(player.global_position)
	for index in range(landmark_route_index, landmark_route_points.size()):
		result.append(landmark_route_points[index])
	return result

func navigate_to_landmark(landmark_key: String, destination: Vector3) -> bool:
	if mission_running or job_running:
		return false
	# الملاحة تنتهي عند المدخل أو لوحة الوظيفة بدل مركز المبنى.
	landmark_navigation_target = get_landmark_entrance(landmark_key, destination)
	landmark_navigation_key = landmark_key
	landmark_navigation_name = CityLanguage.translate(landmark_key)
	navigation_arrival_remaining = 0.0
	navigation_off_route_time = 0.0
	navigation_route_notice_remaining = 0.0
	_build_landmark_route(landmark_navigation_target, landmark_key)
	landmark_navigation_active = true
	_update_navigation_hud()
	return true

func _cancel_active_navigation() -> void:
	if not mission_running and not job_running and not landmark_navigation_active:
		return
	landmark_navigation_active = false
	landmark_route_points.clear()
	landmark_route_index = 0
	navigation_arrival_remaining = 0.0
	navigation_off_route_time = 0.0
	navigation_route_notice_remaining = 0.0
	mission_running = false
	job_running = false
	target_marker.visible = false
	status_label.text = "تم إلغاء التوجيه. لم تُحتسب المهمة أو الوظيفة ولم تُصرف مكافأة."
	description_label.text = "يمكنك فتح المبنى أو لوحة الوظيفة مرة أخرى للبدء من جديد."
	reward_label.text = "لا توجد مكافأة مستحقة حاليًا."
	accept_button.disabled = false
	accept_button.text = "بدء من جديد"
	panel.visible = true
	_update_navigation_hud()

func _create_target_marker() -> void:
	target_marker = MeshInstance3D.new()
	target_marker.name = "MissionTargetMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.65
	mesh.bottom_radius = 0.65
	mesh.height = 0.22
	target_marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.78, 0.08)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.62, 0.02)
	target_marker.material_override = material
	target_marker.visible = false
	add_child(target_marker)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MissionHUD"
	add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)

	prompt_label = Label.new()
	prompt_label.position = Vector2(18, 52)
	prompt_label.size = Vector2(760, 36)
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	root_control.add_child(prompt_label)

	stats_label = Label.new()
	stats_label.position = Vector2(18, 82)
	stats_label.size = Vector2(850, 30)
	stats_label.add_theme_color_override("font_color", Color.WHITE)
	root_control.add_child(stats_label)

	navigation_label = Label.new()
	navigation_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	navigation_label.anchor_left = 0.5
	navigation_label.anchor_right = 0.5
	navigation_label.offset_left = -190
	navigation_label.offset_right = 190
	navigation_label.offset_top = 18
	navigation_label.offset_bottom = 48
	navigation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation_label.add_theme_font_size_override("font_size", 17)
	navigation_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.68))
	navigation_label.visible = false
	root_control.add_child(navigation_label)

	navigation_arrow = Label.new()
	navigation_arrow.text = "▲"
	navigation_arrow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	navigation_arrow.anchor_left = 0.5
	navigation_arrow.anchor_right = 0.5
	navigation_arrow.offset_left = -20
	navigation_arrow.offset_right = 20
	navigation_arrow.offset_top = 48
	navigation_arrow.offset_bottom = 82
	navigation_arrow.pivot_offset = Vector2(20, 17)
	navigation_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation_arrow.add_theme_font_size_override("font_size", 28)
	navigation_arrow.add_theme_color_override("font_color", Color(1.0, 0.72, 0.18))
	navigation_arrow.visible = false
	root_control.add_child(navigation_arrow)

	navigation_cancel_button = Button.new()
	navigation_cancel_button.text = CityLanguage.translate("navigation_cancel")
	navigation_cancel_button.set_anchors_preset(Control.PRESET_TOP_WIDE)
	navigation_cancel_button.anchor_left = 0.5
	navigation_cancel_button.anchor_right = 0.5
	navigation_cancel_button.offset_left = -72
	navigation_cancel_button.offset_right = 72
	navigation_cancel_button.offset_top = 84
	navigation_cancel_button.offset_bottom = 120
	navigation_cancel_button.visible = false
	navigation_cancel_button.pressed.connect(_cancel_active_navigation)
	root_control.add_child(navigation_cancel_button)

	interact_button = Button.new()
	interact_button.text = "تفاعل"
	interact_button.visible = false
	interact_button.position = Vector2(18, 120)
	interact_button.size = Vector2(130, 54)
	interact_button.pressed.connect(interact)
	root_control.add_child(interact_button)

	panel = PanelContainer.new()
	panel.position = Vector2(220, 120)
	panel.size = Vector2(500, 320)
	panel.visible = false
	root_control.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 21)
	content.add_child(title_label)
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description_label)
	reward_label = Label.new()
	content.add_child(reward_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)

	animal_selector = OptionButton.new()
	animal_selector.visible = false
	content.add_child(animal_selector)
	accept_button = Button.new()
	accept_button.text = "بدء المهمة"
	accept_button.pressed.connect(_accept_selected_activity)
	content.add_child(accept_button)
	interior_activities_button = Button.new()
	interior_activities_button.text = CityLanguage.translate("interior_view_activities")
	interior_activities_button.visible = false
	interior_activities_button.pressed.connect(_show_building_activities)
	content.add_child(interior_activities_button)
	interior_return_button = Button.new()
	interior_return_button.text = CityLanguage.translate("interior_return")
	interior_return_button.visible = false
	interior_return_button.pressed.connect(_close_interior_preview)
	content.add_child(interior_return_button)
	interior_exit_button = Button.new()
	interior_exit_button.text = CityLanguage.translate("interior_exit")
	interior_exit_button.position = Vector2(18, 180)
	interior_exit_button.size = Vector2(150, 52)
	interior_exit_button.visible = false
	interior_exit_button.pressed.connect(_exit_building)
	root_control.add_child(interior_exit_button)
	_create_loading_ui()
	close_button = Button.new()
	close_button.text = CityLanguage.translate("service_npc_close")
	close_button.pressed.connect(_close_interaction_panel)
	content.add_child(close_button)
