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
var shared_location_marker: Node3D = null
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
var loading_layer: CanvasLayer
var loading_panel: PanelContainer
var loading_label: Label
var navigation_label: Label
var navigation_arrow: Label
var navigation_cancel_button: Button
var animal_selector: OptionButton
var selected_animal_staff: Node3D = null
# معرف ثابت طوال نافذة التأجير الحالية؛ يمنع تكرار الخصم بسبب النقر المزدوج.
var active_rental_transaction_id: String = ""
var daily_reward_chest: Node3D = null
var daily_chest_reward_configured := false
var daily_chest_server_claimed := false
var daily_chest_reward_day := ""

var _key_was_down := false
var _profile_session_uid := ""
var _profile_session_generation := -1
var _daily_chest_request_action := ""
var _daily_chest_request_uid := ""
var _daily_chest_request_generation := -1

const MAX_CURRENCY_BALANCE := 2000000000

func _ready() -> void:
	_build_ui()
	_create_target_marker()
	if not AccountDataSession.session_ready.is_connected(_on_account_session_ready):
		AccountDataSession.session_ready.connect(_on_account_session_ready)
	if not AccountDataSession.session_invalidated.is_connected(_on_account_session_invalidated):
		AccountDataSession.session_invalidated.connect(_on_account_session_invalidated)
	if AccountDataSession.is_ready():
		_on_account_session_ready(AccountDataSession.get_user_id(), AccountDataSession.get_generation(), AccountDataSession.get_profile_path())
	CityLanguage.language_changed.connect(_refresh_navigation_language)
	if not SocialChatManager.operation_completed.is_connected(_on_daily_chest_rpc_completed):
		SocialChatManager.operation_completed.connect(_on_daily_chest_rpc_completed)
	if not SocialChatManager.operation_failed.is_connected(_on_daily_chest_rpc_failed):
		SocialChatManager.operation_failed.connect(_on_daily_chest_rpc_failed)
	if AuthManager.is_authenticated():
		_refresh_daily_chest_status()
	elif not AuthManager.authenticated.is_connected(_on_daily_chest_authenticated):
		AuthManager.authenticated.connect(_on_daily_chest_authenticated)

func _exit_tree() -> void:
	if AccountDataSession.session_ready.is_connected(_on_account_session_ready):
		AccountDataSession.session_ready.disconnect(_on_account_session_ready)
	if AccountDataSession.session_invalidated.is_connected(_on_account_session_invalidated):
		AccountDataSession.session_invalidated.disconnect(_on_account_session_invalidated)
	if CityLanguage.language_changed.is_connected(_refresh_navigation_language):
		CityLanguage.language_changed.disconnect(_refresh_navigation_language)
	if SocialChatManager.operation_completed.is_connected(_on_daily_chest_rpc_completed):
		SocialChatManager.operation_completed.disconnect(_on_daily_chest_rpc_completed)
	if SocialChatManager.operation_failed.is_connected(_on_daily_chest_rpc_failed):
		SocialChatManager.operation_failed.disconnect(_on_daily_chest_rpc_failed)
	if AuthManager.authenticated.is_connected(_on_daily_chest_authenticated):
		AuthManager.authenticated.disconnect(_on_daily_chest_authenticated)


func _on_account_session_ready(user_id: String, generation: int, _profile_path: String) -> void:
	if not AccountDataSession.is_session_current(user_id, generation):
		return
	_reset_account_bound_activity_state()
	_clear_daily_chest_request()
	_profile_session_uid = user_id
	_profile_session_generation = generation
	_load_profile()

func _on_account_session_invalidated(_previous_user_id: String, _generation: int) -> void:
	_reset_account_bound_activity_state()
	_clear_daily_chest_request()
	_profile_session_uid = ""
	_profile_session_generation = -1
	player_level = 1
	xp = 0
	money = 0
	chips = 0
	completed_missions = {}
	completed_jobs = {}
	owned_outfits = ["default"]
	reward_receipts = {}
	daily_chest_reward_configured = false
	daily_chest_server_claimed = false
	daily_chest_reward_day = ""
	achievement_totals = {"jobs": 0, "missions": 0, "daily_claims": 0}
	achievement_events = {}
	achievement_stats_initialized = false
	daily_task_progress = {}
	daily_task_events = {}

func _has_active_profile_session() -> bool:
	return AccountDataSession.is_session_current(_profile_session_uid, _profile_session_generation) and WalletManager.initialized

func _reset_account_bound_activity_state() -> void:
	# لا تسمح باستمرار مهمة أو عملية تأجير من حساب سابق داخل جلسة الحساب التالي.
	active_mission = null
	active_job = null
	active_job_target = Vector3.ZERO
	active_job_reward = {}
	job_running = false
	mission_running = false
	active_target = Vector3.ZERO
	selected_activity_kind = "mission"
	active_rental_transaction_id = ""
	selected_animal_staff = null

func _profile_save_path() -> String:
	return AccountDataSession.get_profile_path() if _has_active_profile_session() else ""

func _on_daily_chest_authenticated(_user_id: String, _email: String) -> void:
	_refresh_daily_chest_status()

func _refresh_daily_chest_status() -> void:
	if not _has_active_profile_session():
		return
	if not AuthManager.is_session_current(_profile_session_uid, _profile_session_generation):
		return
	_track_daily_chest_request("daily_chest_status")
	if not SocialChatManager.get_daily_chest_status() and _daily_chest_request_action == "daily_chest_status":
		_clear_daily_chest_request()

func _track_daily_chest_request(action: String) -> void:
	_daily_chest_request_action = action
	_daily_chest_request_uid = _profile_session_uid
	_daily_chest_request_generation = _profile_session_generation

func _clear_daily_chest_request() -> void:
	_daily_chest_request_action = ""
	_daily_chest_request_uid = ""
	_daily_chest_request_generation = -1

func _daily_chest_request_is_current(action: String) -> bool:
	return action == _daily_chest_request_action and _has_active_profile_session() and AccountDataSession.is_session_current(_daily_chest_request_uid, _daily_chest_request_generation) and _profile_session_uid == _daily_chest_request_uid and _profile_session_generation == _daily_chest_request_generation

func _on_daily_chest_rpc_completed(action: String, data: Variant) -> void:
	if action != "daily_chest_status" and action != "daily_chest_claim":
		return
	if not _daily_chest_request_is_current(action):
		return
	_clear_daily_chest_request()
	if not data is Dictionary:
		_on_daily_chest_rpc_failed(action, "استجابة صندوق المكافأة غير صالحة.")
		return
	var result: Dictionary = data
	var result_status := str(result.get("status", ""))
	if action == "daily_chest_status":
		daily_chest_reward_configured = bool(result.get("reward_configured", false))
		daily_chest_server_claimed = result_status == "claimed"
		daily_chest_reward_day = str(result.get("reward_day", ""))
		if not is_instance_valid(daily_reward_chest):
			daily_reward_chest = get_tree().get_first_node_in_group("daily_reward_chests") as Node3D
		var local_receipt_id := "daily_chest_" + daily_chest_reward_day
		var local_receipt_saved := not daily_chest_reward_day.is_empty() and has_reward_receipt(local_receipt_id)
		if is_instance_valid(daily_reward_chest):
			daily_reward_chest.visible = not (daily_chest_server_claimed and local_receipt_saved)
		if selected_activity_kind == "daily_chest" and panel.visible:
			accept_button.visible = true
			if daily_chest_server_claimed and local_receipt_saved:
				status_label.text = "استلمت مكافأة الصندوق اليوم."
				accept_button.text = "تم استلام مكافأة اليوم"
				accept_button.disabled = true
			elif daily_chest_server_claimed:
				status_label.text = "الاستلام محفوظ على الخادم؛ اضغط لاستعادة المكافأة على هذا الجهاز."
				accept_button.text = "استعادة المكافأة"
				accept_button.disabled = false
			elif daily_chest_reward_configured:
				status_label.text = "الصندوق متاح لك اليوم."
				accept_button.text = "استلام المكافأة"
				accept_button.disabled = false
			else:
				status_label.text = "الصندوق جاهز، لكن قيمة المكافأة لم تُعتمد بعد."
				accept_button.text = "المكافأة قيد التجهيز"
				accept_button.disabled = true
		return

	if result_status == "claimed" or result_status == "already_claimed":
		var reward_day := str(result.get("reward_day", ""))
		if reward_day.is_empty():
			_on_daily_chest_rpc_failed(action, "لم يحدد الخادم يوم المكافأة.")
			return
		var reward_id := "daily_chest_" + reward_day
		var cash_reward := maxi(0, int(result.get("reward_cash", 0)))
		var chips_reward := maxi(0, int(result.get("reward_chips", 0)))
		var xp_reward := maxi(0, int(result.get("reward_xp", 0)))
		var saved := grant_reward_once(reward_id, cash_reward, xp_reward, chips_reward)
		if not saved and not has_reward_receipt(reward_id):
			status_label.text = "حُفظ الاستلام على الخادم، لكن تعذر حفظه محليًا. حاول الاستعادة مرة أخرى."
			accept_button.disabled = false
			return
		daily_chest_server_claimed = true
		daily_chest_reward_day = reward_day
		if not is_instance_valid(daily_reward_chest):
			daily_reward_chest = get_tree().get_first_node_in_group("daily_reward_chests") as Node3D
		if is_instance_valid(daily_reward_chest):
			daily_reward_chest.visible = false
		reward_label.text = "المكافأة: %d نقدًا | %d رقائق | %d خبرة" % [cash_reward, chips_reward, xp_reward]
		status_label.text = "تم استلام مكافأة الصندوق وحفظها."
		accept_button.text = "تم استلام مكافأة اليوم"
		accept_button.disabled = true
		return
	if result_status == "reward_not_configured":
		daily_chest_reward_configured = false
		status_label.text = "لم تُحدد قيمة المكافأة بعد؛ لم يتم صرف شيء."
		accept_button.disabled = true
	else:
		status_label.text = "تعذر استلام المكافأة: " + result_status
		accept_button.disabled = false

func _on_daily_chest_rpc_failed(action: String, message: String) -> void:
	if action != "daily_chest_status" and action != "daily_chest_claim":
		return
	if not _daily_chest_request_is_current(action):
		return
	_clear_daily_chest_request()
	if selected_activity_kind == "daily_chest" and is_instance_valid(status_label):
		status_label.text = message
		if is_instance_valid(accept_button):
			accept_button.disabled = false

func _claim_daily_chest_reward() -> void:
	if not _has_active_profile_session() or not AuthManager.is_session_current(_profile_session_uid, _profile_session_generation):
		status_label.text = "سجّل الدخول أولًا لاستلام مكافأتك اليومية."
		accept_button.disabled = true
		return
	accept_button.disabled = true
	status_label.text = "جارٍ التحقق من استحقاقك للمكافأة..."
	_track_daily_chest_request("daily_chest_claim")
	if not SocialChatManager.claim_daily_chest_reward() and _daily_chest_request_action == "daily_chest_claim":
		_clear_daily_chest_request()

func _refresh_navigation_language() -> void:
	if is_instance_valid(navigation_cancel_button):
		navigation_cancel_button.text = CityLanguage.translate("navigation_cancel")	
	if is_instance_valid(interior_activities_button):
		interior_activities_button.text = CityLanguage.translate("interior_view_activities")
	if is_instance_valid(interior_return_button):
		interior_return_button.text = CityLanguage.translate("interior_return")
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
	if not _has_active_profile_session():
		return false
	# يسجل الإيصال والمحفظة في ملف واحد؛ تكرار نفس المعرف لا يصرف المكافأة مجددًا.
	if reward_id.is_empty() or money_amount < 0 or xp_amount < 0 or chips_amount < 0 or money + money_amount > MAX_CURRENCY_BALANCE or chips + chips_amount > MAX_CURRENCY_BALANCE or reward_receipts.has(reward_id):
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
	var load_error := config.load(_profile_save_path())
	if load_error != OK and FileAccess.file_exists(_profile_save_path()):
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
	var save_success := WalletManager.save_profile_update(config, next_money, next_chips)
	if not save_success:
		push_warning("تعذر حفظ المكافأة %s مع سجل المحفظة." % reward_id)
		return false
	money = next_money
	xp = next_xp
	chips = next_chips
	player_level = next_level
	reward_receipts = next_receipts
	return true

func record_achievement_event_once(event_id: String, stat_key: String) -> bool:
	if not _has_active_profile_session():
		return false
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
	var load_error := config.load(_profile_save_path())
	if load_error != OK and FileAccess.file_exists(_profile_save_path()):
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
	var save_success := WalletManager.save_profile_update(config, money, chips)
	if not save_success:
		push_warning("تعذر حفظ حدث الإنجاز %s مع سجل المحفظة." % event_id)
		return false
	achievement_totals = next_totals
	achievement_events = next_events
	achievement_stats_initialized = true
	return true

func initialize_achievement_totals_if_missing(legacy_totals: Dictionary) -> bool:
	if not _has_active_profile_session():
		return false
	if achievement_stats_initialized:
		return true
	var migrated := {"jobs": maxi(0, int(legacy_totals.get("jobs", 0))), "missions": maxi(0, int(legacy_totals.get("missions", 0))), "daily_claims": maxi(0, int(legacy_totals.get("daily_claims", 0)))}
	var config := ConfigFile.new()
	var load_error := config.load(_profile_save_path())
	if load_error != OK and FileAccess.file_exists(_profile_save_path()):
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
	if not WalletManager.save_profile_update(config, money, chips):
		push_warning("تعذر حفظ ترحيل عدادات الإنجازات مع سجل المحفظة.")
		return false
	achievement_totals = migrated
	achievement_stats_initialized = true
	return true

func get_achievement_totals() -> Dictionary:
	if not _has_active_profile_session():
		return {"jobs": 0, "missions": 0, "daily_claims": 0}
	return achievement_totals.duplicate(true)

func has_reward_receipt(reward_id: String) -> bool:
	return _has_active_profile_session() and reward_receipts.has(reward_id)

func complete_activity_once(activity_id: String, activity_kind: String, money_amount: int = 0, xp_amount: int = 0, chips_amount: int = 0) -> bool:
	if not _has_active_profile_session():
		return false
	# حفظ إكمال النشاط وإيصال المكافأة والمحفظة في ملف واحد يمنع إعادة الصرف بعد إعادة التشغيل.
	if activity_id.is_empty() or money_amount < 0 or xp_amount < 0 or chips_amount < 0 or money + money_amount > MAX_CURRENCY_BALANCE or chips + chips_amount > MAX_CURRENCY_BALANCE:
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
	var load_error := config.load(_profile_save_path())
	if load_error != OK and FileAccess.file_exists(_profile_save_path()):
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
	var save_success := WalletManager.save_profile_update(config, next_money, next_chips)
	if not save_success:
		push_warning("تعذر حفظ إكمال النشاط %s مع سجل المحفظة." % activity_id)
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
	if not _has_active_profile_session():
		return false
	# تأجير الخدمات المدفوعة يستخدم إيصال المحفظة نفسه لمنع الخصم المكرر.
	if transaction_id.strip_edges().is_empty() or amount <= 0 or amount > MAX_CURRENCY_BALANCE:
		return false
	var receipt_id := "spend_%s" % transaction_id
	if reward_receipts.has(receipt_id) or WalletManager.has_transaction(receipt_id):
		return false
	var next_receipts := reward_receipts.duplicate(true)
	next_receipts[receipt_id] = Time.get_datetime_string_from_system(true)
	var updates := {"reward_receipts": next_receipts}
	if not WalletManager.purchase_once(receipt_id, "money", amount, "Paid in-game service: " + transaction_id, updates):
		return false
	money = WalletManager.get_balance("money")
	reward_receipts = next_receipts
	return true

func get_daily_task_progress(day_id: String, task_id: String) -> int:
	if not _has_active_profile_session():
		return 0
	var day_progress: Dictionary = daily_task_progress.get(day_id, {})
	return int(day_progress.get(task_id, 0))

func get_outfit_price(_outfit_id: String) -> int:
	# الملابس ليست نظامًا معتمدًا في اللعبة؛ أبقِ بيانات النسخ القديمة محفوظة فقط.
	return -1

func get_owned_outfits() -> Array:
	# لا تعرض خزانة أو ملكيات أزياء؛ لا نحذف بيانات الأرشيف القديمة من الملف.
	return []

func purchase_outfit(_outfit_id: String) -> bool:
	# شراء الأزياء معطل نهائيًا وفق قرار اعتماد الشخصيات الجاهزة ذات الزي الثابت.
	return false

func _save_profile() -> bool:
	if not _has_active_profile_session():
		return false
	var config := ConfigFile.new()
	var load_error := config.load(_profile_save_path())
	if load_error != OK and FileAccess.file_exists(_profile_save_path()):
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
	if not WalletManager.save_profile_update(config, money, chips):
		push_warning("تعذر حفظ ملف اللاعب مع سجل المحفظة.")
		return false
	return true

func _load_profile() -> void:
	if not _has_active_profile_session():
		return
	var config := ConfigFile.new()
	var error := config.load(_profile_save_path())
	if error != OK and FileAccess.file_exists(_profile_save_path()):
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
	var saved_owned: Variant = config.get_value("profile", "owned_outfits") if error == OK and config.has_section_key("profile", "owned_outfits") else null
	# Never import the unscoped legacy store file into a newly authenticated UID.
	# Legacy outfit data remains untouched for a separately approved reconciliation.
	owned_outfits = _sanitize_owned_outfits(saved_owned) if saved_owned is Array else ["default"]

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
		_update_navigation_hud()
		return
	_update_interaction_target()
	_update_interaction_hud()
	var interaction_key_down := Input.is_key_pressed(KEY_E)
	var city_root := get_tree().current_scene
	var vehicle_has_priority := false
	if interaction_key_down and is_instance_valid(city_root):
		if bool(city_root.get("vehicle_occupied")):
			vehicle_has_priority = true
		else:
			var city_vehicle := city_root.get("city_vehicle") as Node3D
			if is_instance_valid(city_vehicle) and player.global_position.distance_to(city_vehicle.global_position) <= 5.0:
				vehicle_has_priority = true
	if interaction_key_down and not _key_was_down and not mission_running and not job_running and not vehicle_has_priority:
		interact()
	_key_was_down = interaction_key_down

	stats_label.text = "المستوى %d  |  الخبرة %d  |  المال %d  |  الرقائق %d  |  الجواهر %d" % [player_level, xp, money, chips, WalletManager.get_balance("gems")]
	if job_running:
		var job_distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
		status_label.text = "الوظيفة: توجّه إلى نقطة العمل. المتبقي: %.1f متر" % job_distance
		if job_distance <= 2.2:
			_complete_active_job()
	if mission_running and (not is_instance_valid(active_mission) or active_mission.is_queued_for_deletion()):
		# لا تترك اللاعب عالقًا في مهمة إذا أزيل المبنى أثناء تنفيذها.
		mission_running = false
		active_mission = null
		target_marker.visible = false
		status_label.text = "تعذر إكمال المهمة لأن موقعها لم يعد متاحًا. لم تُصرف مكافأة."
		description_label.text = "افتح مبنى متاحًا لبدء مهمة أخرى."
		reward_label.text = "لم تُحتسب المهمة ولم تُصرف مكافأة."
		accept_button.disabled = false
		panel.visible = true
	if mission_running:
		var distance_to_target := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(active_target.x, active_target.z))
		status_label.text = "الهدف: اذهب إلى علامة المهمة. المسافة المتبقية: %.1f متر" % distance_to_target
		if distance_to_target <= 2.2:
			_complete_active_mission()
	_update_navigation_hud()
	_update_shared_location_auto_walk()


func _update_shared_location_auto_walk() -> void:
	if not landmark_navigation_active or landmark_navigation_key != "shared_location" or not is_instance_valid(player):
		return
	if player.has_method("is_auto_navigation_cancelled") and bool(player.call("is_auto_navigation_cancelled")):
		_cancel_active_navigation()
		return
	_advance_landmark_route()
	var waypoint := landmark_navigation_target
	if landmark_route_index < landmark_route_points.size():
		waypoint = landmark_route_points[landmark_route_index]
	var direction := waypoint - player.global_position
	direction.y = 0.0
	if direction.length() > 0.1 and player.has_method("set_auto_navigation_direction"):
		player.call("set_auto_navigation_direction", direction.normalized())


func _update_interaction_target() -> void:
	# لا تفحص تفاعلات المدينة أثناء الانتقال أو أثناء وجود اللاعب داخل مبنى.
	var city_root := get_tree().current_scene
	if is_instance_valid(city_root) and bool(city_root.get("interior_transition_busy")):
		nearest_interactable = null
		nearest_building = null
		return
	if is_instance_valid(city_root) and is_instance_valid(city_root.get("interior_root")):
		nearest_interactable = _find_nearest_interior_exit(city_root)
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

func _find_nearest_interior_exit(city_root: Node) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("interior_exit_interactables"):
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate is Node3D:
			continue
		var distance := player.global_position.distance_to(candidate.global_position)
		if distance <= 4.5 and distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func _interaction_action_key(target: Node3D) -> String:
	if target.is_in_group("interior_exit_interactables"):
		return "interaction_enter"
	if target.has_method("get_daily_reward_chest_data"):
		return "interaction_talk"
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
	var city_root := get_tree().current_scene
	if is_instance_valid(city_root) and is_instance_valid(city_root.get("interior_root")):
		if is_instance_valid(nearest_interactable):
			interact_button.text = CityLanguage.translate("interaction_enter")
			prompt_label.text = "عند الباب — اضغط زر التفاعل لفتح التنقل السريع"
			interact_button.visible = true
		else:
			interact_button.visible = false
			prompt_label.text = ""
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
		elif nearest_interactable.has_method("get_daily_reward_chest_data"):
			display_name = str(nearest_interactable.get_daily_reward_chest_data().get("title", "صندوق المكافأة"))
		elif nearest_interactable.has_method("get_animal_rental_data"):
			display_name = CityLanguage.translate("interaction_animal_staff")
		elif nearest_interactable.has_method("get_interaction_data"):
			var interaction_data: Dictionary = nearest_interactable.get_interaction_data()
			display_name = str(interaction_data.get("title", nearest_interactable.get("character_name")))
		else:
			display_name = str(nearest_interactable.get("character_name"))
		interact_button.text = "فتح الصندوق" if nearest_interactable.has_method("get_daily_reward_chest_data") else CityLanguage.translate(_interaction_action_key(nearest_interactable))
		prompt_label.text = "%s %s — %s" % [CityLanguage.translate("interaction_near"), display_name, CityLanguage.translate("interaction_press_hint")]
		interact_button.visible = true
	else:
		prompt_label.text = CityLanguage.translate("interaction_approach")
		interact_button.text = CityLanguage.translate("interaction_button")
		interact_button.visible = false

func interact() -> void:
	_update_interaction_target()
	var city_root := get_tree().current_scene
	if is_instance_valid(city_root) and is_instance_valid(city_root.get("interior_root")):
		if is_instance_valid(nearest_interactable):
			open_interactable(nearest_interactable)
		return
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
	if target.is_in_group("interior_exit_interactables"):
		var city_root := get_tree().current_scene
		if is_instance_valid(city_root) and city_root.has_method("show_interior_quick_travel_menu"):
			city_root.show_interior_quick_travel_menu()
		return
	if target.has_method("is_shop_owner") and target.is_shop_owner() and is_instance_valid(shop_manager):
		shop_manager.open_shop()
		return
	if target.has_method("get_daily_reward_chest_data"):
		open_daily_reward_chest(target)
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


func open_daily_reward_chest(chest: Node3D) -> void:
	if not is_instance_valid(chest) or not chest.has_method("get_daily_reward_chest_data"):
		return
	daily_reward_chest = chest
	selected_activity_kind = "daily_chest"
	active_mission = null
	animal_selector.visible = false
	title_label.text = "صندوق المكافأة الفرعوني اليومي"
	description_label.text = "افتح الصندوق لاستلام مكافأتك اليومية. يختفي بعد الاستلام من عالمك وحدك."
	reward_label.text = "تُصرف المكافأة بعد التحقق من الخادم."
	accept_button.visible = true
	accept_button.text = "استلام المكافأة"
	accept_button.disabled = true
	if AuthManager.is_authenticated():
		status_label.text = "جارٍ التحقق من حالة مكافأتك..." 
		SocialChatManager.get_daily_chest_status()
	else:
		status_label.text = "سجّل الدخول أولًا لاستلام مكافأتك اليومية."
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
	if not is_instance_valid(building) or building.is_queued_for_deletion() or mission_running or job_running:
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
	if mission_running or job_running or not is_instance_valid(building) or building.is_queued_for_deletion():
		return
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

func _close_interior_preview() -> void:
	interior_preview_active = false
	interior_preview_building = null
	interior_activities_button.visible = false
	interior_return_button.visible = false
	accept_button.visible = true
	panel.visible = false

func _accept_selected_activity() -> void:
	if selected_activity_kind == "daily_chest":
		_claim_daily_chest_reward()
	elif selected_activity_kind == "animal_rental":
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
	if not is_instance_valid(active_mission) or active_mission.is_queued_for_deletion() or mission_running or job_running:
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
	if not is_instance_valid(player):
		navigation_label.visible = false
		navigation_arrow.visible = false
		navigation_cancel_button.visible = false
		return
	if not navigating:
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
		if landmark_navigation_key == "shared_location":
			if is_instance_valid(player) and player.has_method("end_auto_navigation"):
				player.call("end_auto_navigation")
			hide_shared_location_marker()
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
	var player_point := Vector2(position_3d.x, position_3d.z)
	# بعد تجاوز آخر waypoint، نقيس المسافة إلى الوجهة النهائية بدل إرجاع INF.
	if landmark_route_index >= landmark_route_points.size():
		return player_point.distance_to(Vector2(landmark_navigation_target.x, landmark_navigation_target.z))
	# قد تبقى نقطة واحدة فقط؛ تعامل معها كنقطة وصول لا كمقطع فارغ.
	if landmark_route_points.size() - landmark_route_index == 1:
		var final_point: Vector3 = landmark_route_points[landmark_route_index]
		return player_point.distance_to(Vector2(final_point.x, final_point.z))
	var closest_distance := INF
	for index in range(maxi(landmark_route_index, 0), landmark_route_points.size() - 1):
		var a: Vector2 = Vector2(landmark_route_points[index].x, landmark_route_points[index].z)
		var b: Vector2 = Vector2(landmark_route_points[index + 1].x, landmark_route_points[index + 1].z)
		var segment := b - a
		var denominator := segment.length_squared()
		var weight := 0.0 if denominator <= 0.0001 else clampf((player_point - a).dot(segment) / denominator, 0.0, 1.0)
		closest_distance = minf(closest_distance, player_point.distance_to(a + segment * weight))
	return closest_distance

const CITY_ROAD_COORDS := [-72.0, -24.0, 0.0, 24.0, 72.0]

# نقاط الوقوف عند أبواب المباني ولوحات الوظائف، لا عند مركز كتلة المبنى.
# المواقع متوافقة مع إحداثيات الإنشاء الحالية في main.gd.
const CITY_LANDMARK_ENTRANCES := {
	"shop": Vector3(16.0, 0.0, 19.56),
	"restaurant": Vector3(-16.0, 0.0, 19.56),
	"employment": Vector3(16.0, 0.0, -12.44),
	"delivery": Vector3(24.0, 0.0, 4.5),
	"city_guide": Vector3(-24.0, 0.0, 4.5),
	"maintenance": Vector3(4.5, 0.0, 24.0),
	"animal_camp": Vector3(60.0, 0.0, 68.0)
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
		landmark_route_points.append(Vector3(60.0, 0.0, 75.0))
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
	for node in _find_grid_route(start_node, target_node):
		landmark_route_points.append(Vector3(node.x, 0.0, node.y))


func _find_grid_route(start_node: Vector2, target_node: Vector2) -> Array[Vector2]:
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
	while cursor != start_node:
		if not previous.has(cursor):
			return []
		cursor = previous[cursor]
		reversed_path.append(cursor)
	reversed_path.reverse()
	return reversed_path


func build_shared_location_route_from(start_position: Vector3, destination: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	var start_node := _nearest_city_road_node(start_position)
	var target_node := _nearest_city_road_node(destination)
	points.append(Vector3(start_position.x, 0.0, start_position.z))
	points.append(Vector3(start_node.x, 0.0, start_node.y))
	for node in _find_grid_route(start_node, target_node):
		points.append(Vector3(node.x, 0.0, node.y))
	points.append(Vector3(destination.x, 0.0, destination.z))
	var compact := PackedVector3Array()
	for point in points:
		if compact.is_empty() or compact[compact.size() - 1].distance_to(point) > 0.5:
			compact.append(point)
	return compact

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
	landmark_navigation_name = "الموقع المشترك" if landmark_key == "shared_location" else CityLanguage.translate(landmark_key)
	navigation_arrival_remaining = 0.0
	navigation_off_route_time = 0.0
	navigation_route_notice_remaining = 0.0
	_build_landmark_route(landmark_navigation_target, landmark_key)
	landmark_navigation_active = true
	if landmark_key == "shared_location":
		if not player.has_method("begin_auto_navigation") or not bool(player.call("begin_auto_navigation")):
			landmark_navigation_active = false
			return false
		show_shared_location_marker(landmark_navigation_target)
	_update_navigation_hud()
	return true


func show_shared_location_marker(destination: Vector3) -> void:
	if not is_instance_valid(shared_location_marker):
		shared_location_marker = Node3D.new()
		shared_location_marker.name = "SharedLocationWorldMarker"
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.42
		ring_mesh.outer_radius = 0.58
		ring_mesh.rings = 24
		ring_mesh.ring_segments = 8
		ring.mesh = ring_mesh
		ring.rotation.x = PI * 0.5
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.albedo_color = Color(1.0, 0.72, 0.2, 1.0)
		ring_material.emission_enabled = true
		ring_material.emission = Color(1.0, 0.58, 0.08)
		ring_material.emission_energy_multiplier = 1.8
		ring.material_override = ring_material
		shared_location_marker.add_child(ring)
		var pin := Label3D.new()
		pin.text = "📍"
		pin.position.y = 1.35
		pin.font_size = 36
		pin.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		shared_location_marker.add_child(pin)
		add_child(shared_location_marker)
	shared_location_marker.global_position = Vector3(destination.x, destination.y + 0.08, destination.z)
	shared_location_marker.visible = true


func hide_shared_location_marker() -> void:
	if is_instance_valid(shared_location_marker):
		shared_location_marker.visible = false


func is_shared_location_navigation_active() -> bool:
	return landmark_navigation_active and landmark_navigation_key == "shared_location"


func get_shared_location_navigation_target() -> Vector3:
	return landmark_navigation_target if is_shared_location_navigation_active() else Vector3.ZERO

func _cancel_active_navigation() -> void:
	if not mission_running and not job_running and not landmark_navigation_active:
		return
	landmark_navigation_active = false
	if landmark_navigation_key == "shared_location":
		if is_instance_valid(player) and player.has_method("end_auto_navigation"):
			player.call("end_auto_navigation")
		hide_shared_location_marker()
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
	_create_loading_ui()
	close_button = Button.new()
	close_button.text = CityLanguage.translate("service_npc_close")
	close_button.pressed.connect(_close_interaction_panel)
	content.add_child(close_button)
