extends Node
const ProfileConfigStore = preload("res://scripts/profile_config_store.gd")

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
var target_marker: Node3D
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
var job_selector: OptionButton
var job_delivery_button: Button
var selected_job_id := ""
var active_job_stops: Array[Vector3] = []
var active_job_stop_index := 0
var returning_to_fuel := false
var job_package_visual: Node3D = null
var job_delivery_ring: MeshInstance3D = null
var selected_animal_staff: Node3D = null
# معرف ثابت طوال نافذة التأجير الحالية؛ يمنع تكرار الخصم بسبب النقر المزدوج.
var active_rental_transaction_id: String = ""

var _key_was_down := false
var _pending_verified_proofs: Array[Dictionary] = []
var _reward_claim_inflight := false
var selected_adventure_id := ""
var adventure_stage_index := 0
var survival_prep_remaining := 0.0
var survival_time_remaining := 0.0
var adventure_treasure_visual: Node3D
var rescue_interaction_button: Button
var rescue_citizen_actor: Node3D
var message_puzzle_input: LineEdit
var message_puzzle_submit_button: Button
var message_puzzle_ready := false
var survival_progress_label: Label
var survival_progress_bar: ProgressBar
var rescue_population: Node
const SURVIVAL_PREPARATION_SECONDS := 10.0
const SURVIVAL_DURATION_SECONDS := 60.0
const CITY_ADVENTURES := {
	"city_adventure_rescue": {"title": "مهمة الإنقاذ", "description": "اتجه إلى مركز الإنقاذ ثم إلى مركز الشرطة لإتمام المهمة."},
	"city_adventure_treasure": {"title": "الكنز المفقود", "description": "اتبع الأدلة بين مواقع المدينة الموجودة حتى تصل إلى الهدف."},
	"city_adventure_message": {"title": "الرسالة الغامضة", "description": "اجمع الأدلة الثلاثة من مواقع المدينة، ثم حل الشفرة عند نقطة النهاية."},
	"city_adventure_survival": {"title": "سباق النجاة", "description": "اعبر نقاط المسار المحددة في شوارع المدينة بالترتيب."}
}
const CITY_ADVENTURE_STAGES := {
	"city_adventure_rescue": [Vector3(-75.0, 0.15, 20.9), Vector3(-75.0, 0.15, 0.9)],
	"city_adventure_treasure": [Vector3(-30.0, 0.15, -23.6), Vector3(0.0, 0.15, 6.4), Vector3(60.0, 0.15, 36.4)],
	"city_adventure_message": [Vector3(75.0, 0.15, 0.9), Vector3(75.0, 0.15, 20.9), Vector3(60.0, 0.15, -23.6)],
	"city_adventure_survival": [Vector3(-60.0, 0.15, 45.0), Vector3(-30.0, 0.15, 45.0), Vector3(0.0, 0.15, 45.0), Vector3(30.0, 0.15, 45.0), Vector3(60.0, 0.15, 45.0)]
}

const MAX_CURRENCY_BALANCE := 2000000000

# الوظائف السبع المعتمدة متاحة من مكتب التوظيف الموحد.

func _save_path() -> String:
	return ProfileConfigStore.get_active_profile_path()

func _egypt_datetime() -> Dictionary:
	return GameCalendar.get_egypt_datetime()

func _egypt_day_key() -> String:
	return GameCalendar.get_egypt_day_key()

func _daily_job_key(job_id: String) -> String:
	return "%s:%s" % [_egypt_day_key(), job_id]

func is_job_available_today(job_id: String) -> bool:
	return CityJobsCatalog.is_approved_job(job_id)

func _ready() -> void:
	_build_ui()
	_create_target_marker()
	_load_profile()
	CityLanguage.language_changed.connect(_refresh_navigation_language)
	AuthoritativeGameServer.job_start_result.connect(_on_server_job_start_result)
	AuthoritativeGameServer.job_completed.connect(_on_server_job_completed)
	AuthoritativeGameServer.mission_start_result.connect(_on_server_mission_start_result)
	AuthoritativeGameServer.mission_stage_updated.connect(_on_server_mission_stage_updated)
	rescue_population = get_tree().current_scene.get_node_or_null("CityNPCPopulation") if is_instance_valid(get_tree().current_scene) else null
	AuthoritativeGameServer.mission_failed.connect(_on_server_mission_failed)
	AuthoritativeGameServer.mission_completed.connect(_on_server_mission_completed)
	AuthoritativeGameServer.activity_progress_recorded.connect(_on_server_activity_progress_recorded)
	AuthoritativeGameServer.activity_proof_received.connect(_on_server_activity_proof_received)
	AuthoritativeGameServer.activity_proof_failed.connect(_on_server_activity_proof_failed)
	PlayerSyncClient.verified_reward_claim_finished.connect(_on_verified_reward_claim_finished)

func _exit_tree() -> void:
	if CityLanguage.language_changed.is_connected(_refresh_navigation_language):
		CityLanguage.language_changed.disconnect(_refresh_navigation_language)
	if AuthoritativeGameServer.job_start_result.is_connected(_on_server_job_start_result):
		AuthoritativeGameServer.job_start_result.disconnect(_on_server_job_start_result)
	if AuthoritativeGameServer.job_completed.is_connected(_on_server_job_completed):
		AuthoritativeGameServer.job_completed.disconnect(_on_server_job_completed)
	if AuthoritativeGameServer.mission_start_result.is_connected(_on_server_mission_start_result):
		AuthoritativeGameServer.mission_start_result.disconnect(_on_server_mission_start_result)
	_clear_rescue_citizen()
	if AuthoritativeGameServer.mission_stage_updated.is_connected(_on_server_mission_stage_updated):
		AuthoritativeGameServer.mission_stage_updated.disconnect(_on_server_mission_stage_updated)
	if AuthoritativeGameServer.mission_failed.is_connected(_on_server_mission_failed):
		AuthoritativeGameServer.mission_failed.disconnect(_on_server_mission_failed)
	if AuthoritativeGameServer.mission_completed.is_connected(_on_server_mission_completed):
		AuthoritativeGameServer.mission_completed.disconnect(_on_server_mission_completed)
	if AuthoritativeGameServer.activity_progress_recorded.is_connected(_on_server_activity_progress_recorded):
		AuthoritativeGameServer.activity_progress_recorded.disconnect(_on_server_activity_progress_recorded)
	if AuthoritativeGameServer.activity_proof_received.is_connected(_on_server_activity_proof_received):
		AuthoritativeGameServer.activity_proof_received.disconnect(_on_server_activity_proof_received)
	if AuthoritativeGameServer.activity_proof_failed.is_connected(_on_server_activity_proof_failed):
		AuthoritativeGameServer.activity_proof_failed.disconnect(_on_server_activity_proof_failed)
	if PlayerSyncClient.verified_reward_claim_finished.is_connected(_on_verified_reward_claim_finished):
		PlayerSyncClient.verified_reward_claim_finished.disconnect(_on_verified_reward_claim_finished)

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
	if GameModeManager.is_online_ready():
		return false
	if not _refresh_wallet_cache():
		return false
	# يسجل الإيصال والمحفظة في ملف واحد؛ تكرار نفس المعرف لا يصرف المكافأة مجددًا.
	xp_amount = 0
	if reward_id.is_empty() or money_amount < 0 or xp_amount < 0 or chips_amount < 0 or money + money_amount > MAX_CURRENCY_BALANCE or chips + chips_amount > MAX_CURRENCY_BALANCE or reward_receipts.has(reward_id):
		return false
	var next_money := money + money_amount
	var next_xp := 0
	var next_chips := chips + chips_amount
	var next_level := DevelopmentManager.player_level
	var next_receipts := reward_receipts.duplicate(true)
	next_receipts[reward_id] = Time.get_datetime_string_from_system()
	var config := ConfigFile.new()
	var load_error := config.load(_save_path())
	if load_error != OK and FileAccess.file_exists(_save_path()):
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
	if GameModeManager.is_online_ready():
		return false
	if not _refresh_wallet_cache():
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
	var load_error := config.load(_save_path())
	if load_error != OK and FileAccess.file_exists(_save_path()):
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
	if is_instance_valid(PlayerSyncClient):
		var progress_key := "achievement." + stat_key
		PlayerSyncClient.enqueue_progress_observation("achievement_progress_observed", progress_key, int(next_totals.get(stat_key, 0)))
	return true

func initialize_achievement_totals_if_missing(legacy_totals: Dictionary) -> bool:
	if achievement_stats_initialized:
		return true
	if not _refresh_wallet_cache():
		return false
	var migrated := {"jobs": maxi(0, int(legacy_totals.get("jobs", 0))), "missions": maxi(0, int(legacy_totals.get("missions", 0))), "daily_claims": maxi(0, int(legacy_totals.get("daily_claims", 0)))}
	var config := ConfigFile.new()
	var load_error := config.load(_save_path())
	if load_error != OK and FileAccess.file_exists(_save_path()):
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
	return achievement_totals.duplicate(true)

func has_reward_receipt(reward_id: String) -> bool:
	return reward_receipts.has(reward_id)

func complete_activity_once(activity_id: String, activity_kind: String, money_amount: int = 0, xp_amount: int = 0, chips_amount: int = 0) -> bool:
	if GameModeManager.is_online_ready():
		return false
	if not _refresh_wallet_cache():
		return false
	# حفظ إكمال النشاط وإيصال المكافأة والمحفظة في ملف واحد يمنع إعادة الصرف بعد إعادة التشغيل.
	xp_amount = 0
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
	var next_xp := 0
	var next_chips := chips + chips_amount
	var next_level := DevelopmentManager.player_level
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
	var today_key := GameCalendar.get_egypt_day_key()
	var daily_event_id := "%s:%s:%s" % [today_key, activity_kind, activity_id]
	if not next_daily_events.has(daily_event_id):
		var today_progress: Dictionary = next_daily_progress.get(today_key, {}).duplicate(true)
		var daily_stat_key := "job" if activity_kind == "job" else "mission"
		today_progress[daily_stat_key] = int(today_progress.get(daily_stat_key, 0)) + 1
		next_daily_progress[today_key] = today_progress
		next_daily_events[daily_event_id] = Time.get_datetime_string_from_system()
	var config := ConfigFile.new()
	var load_error := config.load(_save_path())
	if load_error != OK and FileAccess.file_exists(_save_path()):
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

	# Queue daily counters only after the profile and wallet receipt are saved.
	# These observations never carry or authorize rewards, balances, or ownership.
	if is_instance_valid(PlayerSyncClient):
		var daily_key := "job" if activity_kind == "job" else "mission"
		PlayerSyncClient.enqueue_progress_observation(
			"activity_progress_observed",
			"activity.daily_" + daily_key,
			int(next_daily_progress.get(today_key, {}).get(daily_key, 0))
		)

	# Queue non-authoritative progress observations only after the local completion
	# and wallet receipt have been saved successfully. These events never grant rewards.
	if is_instance_valid(PlayerSyncClient):
		if activity_kind == "mission":
			PlayerSyncClient.enqueue_progress_observation(
				"mission_progress_observed",
				"mission.completed",
				int(next_achievement_totals.get("missions", 0))
			)
		else:
			PlayerSyncClient.enqueue_progress_observation(
				"activity_progress_observed",
				"activity.jobs_completed",
				int(next_achievement_totals.get("jobs", 0))
			)
		var achievement_key := "missions" if activity_kind == "mission" else "jobs"
		PlayerSyncClient.enqueue_progress_observation(
			"achievement_progress_observed",
			"achievement." + achievement_key,
			int(next_achievement_totals.get(achievement_key, 0))
		)
	return true


func spend_money_once(transaction_id: String, amount: int) -> bool:
	# تأجير الخدمات المدفوعة يستخدم إيصال المحفظة نفسه لمنع الخصم المكرر.
	if not _refresh_wallet_cache():
		return false
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
	var day_progress: Dictionary = daily_task_progress.get(day_id, {})
	return int(day_progress.get(task_id, 0))

func get_outfit_price(outfit_id: String) -> int:
	return int(OUTFIT_PRICES.get(outfit_id, -1))

func get_owned_outfits() -> Array:
	return owned_outfits.duplicate()

func purchase_outfit(outfit_id: String) -> bool:
	# مسار تاريخي غير مستخدم؛ حدّث رصيد المحفظة قبل أي عملية قديمة حتى لا تُخصم من لقطة متقادمة.
	if not _refresh_wallet_cache():
		return false
	if not OUTFIT_PRICES.has(outfit_id) or owned_outfits.has(outfit_id):
		return false
	var price: int = int(OUTFIT_PRICES[outfit_id])
	var next_owned := owned_outfits.duplicate()
	next_owned.append(outfit_id)
	var receipt_id := "purchase_outfit_%s" % outfit_id
	if reward_receipts.has(receipt_id) or WalletManager.has_transaction(receipt_id):
		return false
	var next_receipts := reward_receipts.duplicate(true)
	next_receipts[receipt_id] = Time.get_datetime_string_from_system(true)
	var updates := {
		"owned_outfits": next_owned,
		"reward_receipts": next_receipts
	}
	if not WalletManager.purchase_once(receipt_id, "money", price, "Purchase outfit: " + outfit_id, updates):
		return false
	money = WalletManager.get_balance("money")
	owned_outfits = next_owned
	reward_receipts = next_receipts
	return true


func _refresh_wallet_cache() -> bool:
	# المحفظة هي مصدر الرصيد؛ لا تستخدم نسخ المال/الرقائق القديمة قبل أي مكافأة أو حفظ.
	if not WalletManager.initialized or WalletManager.integrity_warning:
		return false
	var snapshot: Dictionary = WalletManager.get_balances()
	if snapshot.is_empty():
		return false
	var next_money := int(snapshot.get("money", -1))
	var next_chips := int(snapshot.get("chips", -1))
	if next_money < 0 or next_chips < 0:
		return false
	money = next_money
	chips = next_chips
	return true

func _save_profile() -> bool:
	if ProfileConfigStore.is_account_switch_in_progress():
		return false
	if not _refresh_wallet_cache():
		push_warning("تخطي حفظ ملف اللاعب لأن المحفظة غير مهيأة أو موقوفة للمراجعة.")
		return false
	var config := ConfigFile.new()
	var load_error := config.load(_save_path())
	if load_error != OK and FileAccess.file_exists(_save_path()):
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
	var config := ConfigFile.new()
	var error := config.load(_save_path())
	if error != OK and FileAccess.file_exists(_save_path()):
		push_warning("تعذر قراءة ملف اللاعب؛ تم إيقاف الترحيل لتجنب فقدان البيانات.")
		return
	if error == OK:
		player_level = DevelopmentManager.player_level
		xp = 0
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
	var needs_profile_save := false
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
		needs_profile_save = true

	if needs_profile_save:
		if not _save_profile():
			push_warning("تعذر حفظ بيانات اللاعب بعد ترحيل الملكيات القديمة.")

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
	_update_survival_timers(_delta)
	if GameModeManager.is_online_ready():
		if not is_instance_valid(player):
			return
		_update_interaction_target()
		_update_interaction_hud()
		_update_rescue_interaction_prompt()
		var online_interaction_down := Input.is_key_pressed(KEY_E)
		if online_interaction_down and not _key_was_down and not job_running:
			interact()
		_key_was_down = online_interaction_down
		if job_running:
			var server_job_distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
			status_label.text = "الوظيفة Online: اقترب من الهدف. المتبقي %.1f متر" % server_job_distance
		elif mission_running:
			var server_mission_distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(active_target.x, active_target.z))
			if selected_adventure_id == "city_adventure_survival":
				status_label.text = "سباق النجاة: %d ثانية متبقية | %.1f متر للهدف" % [ceili(survival_time_remaining), server_mission_distance]
			else:
				status_label.text = "المهمة Online: اقترب من الهدف. المتبقي %.1f متر" % server_mission_distance
		_update_navigation_hud()
		return
	if navigation_arrival_remaining > 0.0:
		navigation_arrival_remaining = maxf(navigation_arrival_remaining - _delta, 0.0)
	if navigation_route_notice_remaining > 0.0:
		navigation_route_notice_remaining = maxf(navigation_route_notice_remaining - _delta, 0.0)
	if not is_instance_valid(player):
		_update_navigation_hud()
		return
	_update_interaction_target()
	_update_interaction_hud()
	_update_rescue_interaction_prompt()
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

	stats_label.text = "المستوى %d/5000  |  مراحل التطوير %d/140  |  المال %d  |  الرقائق %d  |  الجواهر %d" % [DevelopmentManager.player_level, DevelopmentManager.get_completed_stage_count(), money, chips, WalletManager.get_balance("gems")]
	if job_running:
		var job_city_root := get_tree().current_scene
		var vehicle := job_city_root.get("city_vehicle") as Node3D if is_instance_valid(job_city_root) else null
		var vehicle_occupied_now := bool(job_city_root.get("vehicle_occupied")) if is_instance_valid(job_city_root) else false
		if returning_to_fuel:
			job_delivery_button.visible = false
			if vehicle_occupied_now and is_instance_valid(vehicle):
				var fuel_distance := Vector2(vehicle.global_position.x, vehicle.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
				status_label.text = "عُد بالسيارة إلى محطة الوقود. المتبقي: %.1f متر" % fuel_distance
				if fuel_distance <= 6.0:
					_complete_active_job()
			else:
				status_label.text = "استخدم سيارتك للعودة إلى محطة الوقود وإنهاء الوظيفة."
		elif vehicle_occupied_now and is_instance_valid(vehicle):
			job_delivery_button.visible = false
			var vehicle_distance := Vector2(vehicle.global_position.x, vehicle.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
			status_label.text = "وصل بالسيارة قرب نقطة التسليم ثم انزل واحمل الطرد. المتبقي: %.1f متر" % vehicle_distance
		else:
			var job_distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
			var parked_vehicle_distance := INF
			if is_instance_valid(vehicle):
				parked_vehicle_distance = Vector2(vehicle.global_position.x, vehicle.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
			job_delivery_button.visible = job_distance <= 2.6 and parked_vehicle_distance <= 8.0
			if parked_vehicle_distance > 8.0:
				status_label.text = "قرّب السيارة من نقطة التسليم أولًا، ثم انزل واحمل الطرد."
			else:
				status_label.text = "احمل الطرد إلى دائرة التسليم. المتبقي: %.1f متر" % job_distance
				if job_delivery_button.visible:
					status_label.text = "وصلت إلى نقطة التسليم. ضع الطرد داخل الدائرة."
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
		if selected_activity_kind == "adventure" and selected_adventure_id == "city_adventure_survival":
			status_label.text = "سباق النجاة: %d ثانية متبقية | %.1f متر للهدف" % [ceili(survival_time_remaining), distance_to_target]
		else:
			status_label.text = "الهدف: اذهب إلى علامة المهمة. المسافة المتبقية: %.1f متر" % distance_to_target
		var rescue_requires_interaction := selected_activity_kind == "adventure" and selected_adventure_id == "city_adventure_rescue" and adventure_stage_index == 0
		if distance_to_target <= 2.2 and not rescue_requires_interaction:
			if selected_activity_kind == "adventure":
				_advance_local_adventure_stage()
			else:
				_complete_active_mission()
	_update_navigation_hud()


func _update_interaction_target() -> void:
	var city_root := get_tree().current_scene
	if is_instance_valid(city_root) and bool(city_root.get("interior_transition_busy")):
		nearest_interactable = null
		nearest_building = null
		return
	# داخل القصر نفحص بواباته فقط؛ لا نعيد تفاعلات المدينة المخفية.
	if is_instance_valid(city_root) and is_instance_valid(city_root.get("interior_root")):
		var palace_best: Node3D = null
		var palace_distance := INF
		for candidate in get_tree().get_nodes_in_group("city_interactables"):
			if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate is Node3D or not candidate.has_meta("palace_portal_target"):
				continue
			var radius_value: Variant = candidate.get("interaction_radius")
			var allowed_distance := float(radius_value) if radius_value != null else 3.6
			var distance := player.global_position.distance_to(candidate.global_position)
			if distance <= allowed_distance and distance < palace_distance:
				palace_distance = distance
				palace_best = candidate
		nearest_interactable = palace_best
		nearest_building = null
		return
	var previous_target := nearest_interactable
	var best: Node3D = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("city_interactables"):
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate is Node3D:
			continue
		if GameModeManager.is_online_ready() and not candidate.has_method("get_job_data") and not candidate.has_method("get_mission_data") and not candidate.has_method("get_development_data"):
			continue
		var radius_value: Variant = candidate.get("interaction_radius")
		var allowed_distance := float(radius_value) if radius_value != null else 4.5
		allowed_distance = clampf(allowed_distance, 0.5, 4.8)
		if candidate == previous_target:
			allowed_distance += 0.65
		var distance := player.global_position.distance_to(candidate.global_position)
		if distance <= allowed_distance and distance < best_distance:
			best_distance = distance
			best = candidate
	nearest_interactable = best
	nearest_building = best if is_instance_valid(best) and best.has_method("get_mission_data") else null

func _interaction_action_key(target: Node3D) -> String:
	if target.has_meta("palace_portal_target"):
		return "interaction_enter"
	if target.has_method("sit_player"):
		return "interaction_talk"
	if target.has_method("get_development_data"):
		return "interaction_enter"
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
	var player_is_busy: bool = is_instance_valid(player) and (bool(player.get("sitting")) or bool(player.get("animal_riding")))
	var has_interaction: bool = is_instance_valid(nearest_interactable) and not player_is_busy
	interact_button.visible = true
	interact_button.text = "✋"
	interact_button.add_theme_font_size_override("font_size", 28)
	var hand_color := Color(0.20, 0.62, 1.0, 1.0) if has_interaction else Color.WHITE
	interact_button.add_theme_color_override("font_color", hand_color)
	interact_button.add_theme_color_override("font_hover_color", hand_color)
	interact_button.add_theme_color_override("font_pressed_color", hand_color)
	interact_button.tooltip_text = CityLanguage.translate(_interaction_action_key(nearest_interactable)) if has_interaction else CityLanguage.translate("interaction_approach")
	if has_interaction:
		var display_name := CityLanguage.translate("interaction_place")
		if nearest_interactable.has_meta("palace_portal_label"):
			display_name = str(nearest_interactable.get_meta("palace_portal_label"))
			if nearest_interactable.has_meta("palace_room_center"):
				var portal_position := nearest_interactable.global_position
				var actor_position := player.global_position
				var door_side := str(nearest_interactable.get_meta("palace_door_side", "south"))
				var inside_room := actor_position.z < portal_position.z if door_side == "south" else actor_position.z > portal_position.z
				if inside_room:
					display_name = "الخروج إلى الردهة"
		elif nearest_interactable.has_method("get_development_data"):
			display_name = str(nearest_interactable.get_development_data().get("title", "مبنى التطوير"))
		elif nearest_interactable.has_method("get_job_data"):
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
		interact_button.text = "جلوس" if nearest_interactable.has_method("sit_player") else CityLanguage.translate(_interaction_action_key(nearest_interactable))
		prompt_label.text = "%s %s — %s" % [CityLanguage.translate("interaction_near"), display_name, CityLanguage.translate("interaction_press_hint")]
	else:
		if is_instance_valid(player) and player.get("animal_riding") == true:
			prompt_label.text = CityLanguage.translate("interaction_riding_prompt") + " — استخدم زر الباب للنزول."
		elif is_instance_valid(player) and player.get("sitting") == true:
			prompt_label.text = "استخدم زر الباب للوقوف."
		else:
			prompt_label.text = CityLanguage.translate("interaction_approach")

func interact() -> void:
	_update_interaction_target()
	if is_instance_valid(player) and (player.get("animal_riding") == true or player.get("sitting") == true):
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
	if target.has_meta("palace_portal_target"):
		var city_root := get_tree().current_scene
		if is_instance_valid(city_root) and city_root.has_method("use_palace_portal"):
			city_root.use_palace_portal(target, player)
		return
	if target.has_method("sit_player"):
		var seated := bool(target.call("sit_player", player))
		if seated:
			panel.visible = false
			prompt_label.text = "استمتع بالجلوس ومشاهدة الأهرامات"
		return
	if target.has_method("is_shop_owner") and target.is_shop_owner() and is_instance_valid(shop_manager):
		shop_manager.open_shop()
		return
	if target.has_method("get_development_data"):
		var development_data: Dictionary = target.get_development_data()
		DevelopmentManager.open_for_building(str(development_data.get("building_id", "")), str(development_data.get("title", "مبنى التطوير")))
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
	job_selector.visible = false
	selected_animal_staff = staff
	var wallet_ready := _refresh_wallet_cache()
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
	elif not wallet_ready:
		status_label.text = "المحفظة غير مهيأة أو موقوفة للمراجعة؛ لا يمكن التأجير الآن."
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
	if not _refresh_wallet_cache():
		status_label.text = "المحفظة غير مهيأة أو موقوفة للمراجعة؛ لم يبدأ الركوب ولم يُخصم شيء."
		accept_button.disabled = true
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
	stats_label.text = "المستوى %d/5000  |  مراحل التطوير %d/140  |  المال %d  |  الرقائق %d" % [DevelopmentManager.player_level, DevelopmentManager.get_completed_stage_count(), money, chips]
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
	selected_activity_kind = "job"
	job_selector.clear()
	for job_id in CityJobsCatalog.get_job_ids():
		var job_data := CityJobsCatalog.get_job(job_id)
		job_selector.add_item(str(job_data.get("title", job_id)))
		job_selector.set_item_metadata(job_selector.item_count - 1, job_id)
	job_selector.visible = true
	job_delivery_button.visible = false
	if job_selector.item_count > 0:
		job_selector.select(0)
		_on_job_selected(0)
	accept_button.text = "قبول الوظيفة"
	panel.visible = true

func _on_job_selected(index: int) -> void:
	if not is_instance_valid(job_selector) or index < 0 or index >= job_selector.item_count:
		return
	selected_job_id = str(job_selector.get_item_metadata(index))
	var data := CityJobsCatalog.get_job(selected_job_id)
	title_label.text = "وظيفة | " + str(data.get("title", ""))
	description_label.text = str(data.get("description", ""))
	reward_label.text = "الأجر: يحدد لاحقًا وفق اقتصاد المدينة."
	var daily_key := _daily_job_key(selected_job_id)
	if GameModeManager.is_online_ready():
		status_label.text = "وظائف التوصيل Online ستُفعّل بعد مزامنة قيادة المركبات والتسليم الخادمي."
		accept_button.disabled = true
	elif completed_jobs.has(daily_key):
		status_label.text = "أنجزت هذه الوظيفة اليوم. يمكنك اختيار وظيفة أخرى."
		accept_button.disabled = true
	else:
		status_label.text = "تحتاج إلى استدعاء سيارتك أولًا. سلّم كل طرد بنفسك ثم عُد بالسيارة إلى محطة الوقود."
		accept_button.disabled = false

func open_building(building: Node3D) -> void:
	job_selector.visible = false
	if not is_instance_valid(building) or building.is_queued_for_deletion() or mission_running or job_running:
		return
	if str(building.get("building_id")) == "city_adventure_hub":
		_open_city_adventure_hub(building)
		return
	animal_selector.visible = false
	selected_activity_kind = "mission"
	active_mission = building
	var data: Dictionary = building.get_mission_data()
	if bool(data.get("requires_interior", false)) and not GameModeManager.is_online_ready():
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
	reward_label.text = "المكافأة: %d جنيه | %d رقائق" % [data["money"], data["chips"]]
	var key: String = str(building.get("building_id"))
	if completed_missions.has(key) and not GameModeManager.is_online_ready():
		status_label.text = "أنجزت هذه المهمة بالفعل في هذه الجلسة."
		accept_button.disabled = true
	elif player_level < int(data["level"]) and not GameModeManager.is_online_ready():
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
	reward_label.text = "المكافأة: %d جنيه | %d رقائق" % [data["money"], data["chips"]]
	status_label.text = CityLanguage.translate("interior_activity_status")
	accept_button.disabled = completed_missions.has(str(building.building_id)) or player_level < int(data.get("level", 1))
	accept_button.text = "بدء المهمة"
	panel.visible = true

func _close_interaction_panel() -> void:
	job_selector.visible = false
	job_delivery_button.visible = false
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

func _open_city_adventure_hub(building: Node3D) -> void:
	if not is_instance_valid(building) or mission_running or job_running:
		return
	active_mission = building
	selected_activity_kind = "adventure"
	animal_selector.visible = false
	job_selector.clear()
	for adventure_id in CITY_ADVENTURES.keys():
		var adventure: Dictionary = CITY_ADVENTURES[adventure_id]
		job_selector.add_item(str(adventure.get("title", adventure_id)))
		job_selector.set_item_metadata(job_selector.item_count - 1, adventure_id)
	job_selector.select(0)
	selected_adventure_id = str(job_selector.get_item_metadata(0))
	adventure_stage_index = 0
	interior_activities_button.visible = false
	interior_return_button.visible = false
	accept_button.visible = true
	accept_button.disabled = false
	accept_button.text = "ابدأ المغامرة"
	title_label.text = "مغامرات المدينة"
	description_label.text = "اختر مغامرتك. جميع المراحل تستخدم مواقع موجودة بالفعل داخل المدينة."
	reward_label.text = "المكافآت غير مفعلة لهذه النسخة؛ لا يوجد صرف محلي."
	status_label.text = "اختر واحدة من المغامرات الأربع."
	job_selector.visible = true
	panel.visible = true


func _accept_selected_activity() -> void:
	if selected_activity_kind == "animal_rental":
		_rent_selected_animal()
	elif selected_activity_kind == "job":
		_accept_job()
	elif selected_activity_kind == "adventure":
		_accept_adventure()
	else:
		_accept_mission()

func _update_survival_race_hud() -> void:
	var active := selected_adventure_id == "city_adventure_survival" and (mission_running or survival_prep_remaining > 0.0)
	if is_instance_valid(survival_progress_label):
		survival_progress_label.visible = active
		survival_progress_label.text = "نقاط السباق: %d / 5" % clampi(adventure_stage_index, 0, 5)
	if is_instance_valid(survival_progress_bar):
		survival_progress_bar.visible = active
		survival_progress_bar.value = clampf(float(adventure_stage_index), 0.0, 5.0)


func _accept_adventure() -> void:
	if not is_instance_valid(active_mission) or mission_running or job_running or job_selector.selected < 0:
		return
	var adventure_id := str(job_selector.get_item_metadata(job_selector.selected))
	if not CITY_ADVENTURES.has(adventure_id) or not CITY_ADVENTURE_STAGES.has(adventure_id):
		status_label.text = "المغامرة المختارة غير متاحة."
		return
	selected_adventure_id = adventure_id
	_set_message_puzzle_visible(false)
	_hide_adventure_treasure()
	active_mission.set("server_activity_id", adventure_id)
	adventure_stage_index = 0
	landmark_navigation_active = false
	navigation_arrival_remaining = 0.0
	job_selector.visible = false
	accept_button.disabled = true
	if adventure_id == "city_adventure_survival":
		adventure_stage_index = 0
		survival_prep_remaining = SURVIVAL_PREPARATION_SECONDS
		survival_time_remaining = 0.0
		status_label.text = "استعد للسباق! يبدأ بعد 10 ثوانٍ."
		description_label.text = "لديك 10 ثوانٍ للاستعداد، ثم 60 ثانية لاجتياز خمس نقاط على مسار الشارع. اتبع العلامة حتى خط النهاية."
		_update_survival_race_hud()
		return
	_begin_selected_adventure()


func _begin_selected_adventure() -> void:
	if not CITY_ADVENTURE_STAGES.has(selected_adventure_id):
		return
	var stages: Array = CITY_ADVENTURE_STAGES[selected_adventure_id]
	if stages.is_empty():
		status_label.text = "مسار المغامرة غير مكتمل."
		accept_button.disabled = false
		return
	if GameModeManager.is_online_ready():
		status_label.text = "يراجع الخادم موقعك ويبدأ المغامرة..."
		AuthoritativeGameServer.request_start_mission.rpc_id(1, selected_adventure_id)
		return
	active_target = stages[0]
	mission_running = true
	if selected_adventure_id == "city_adventure_survival":
		survival_time_remaining = SURVIVAL_DURATION_SECONDS
		_update_survival_race_hud()
	target_marker.global_position = active_target
	target_marker.visible = true
	accept_button.disabled = true
	var adventure: Dictionary = CITY_ADVENTURES[selected_adventure_id]
	title_label.text = str(adventure.get("title", "مغامرة"))
	description_label.text = str(adventure.get("description", ""))
	status_label.text = "بدأت المغامرة. اتبع علامة الهدف الأولى."
	reward_label.text = "لا توجد مكافأة محلية؛ إكمال المراحل يسجل كتقدم تجريبي فقط."


func _update_survival_timers(delta: float) -> void:
	if survival_prep_remaining > 0.0:
		survival_prep_remaining = maxf(survival_prep_remaining - delta, 0.0)
		status_label.text = "استعد للسباق! البداية خلال %d ثانية." % ceili(survival_prep_remaining)
		_update_survival_race_hud()
		if survival_prep_remaining <= 0.0:
			_begin_selected_adventure()
		return
	if selected_adventure_id != "city_adventure_survival" or not mission_running or survival_time_remaining <= 0.0:
		return
	survival_time_remaining = maxf(survival_time_remaining - delta, 0.0)
	status_label.text = "سباق النجاة: %d ثانية متبقية | النقطة %d من 5." % [ceili(survival_time_remaining), clampi(adventure_stage_index + 1, 1, 5)]
	_update_survival_race_hud()
	if survival_time_remaining <= 0.0 and not GameModeManager.is_online_ready():
		_fail_local_survival_race()


func _fail_local_survival_race() -> void:
	mission_running = false
	if is_instance_valid(survival_progress_label):
		survival_progress_label.visible = false
	if is_instance_valid(survival_progress_bar):
		survival_progress_bar.visible = false
	survival_time_remaining = 0.0
	target_marker.visible = false
	status_label.text = "انتهى الوقت! لم تصل إلى نقطة النجاة."
	description_label.text = "انتهى سباق النجاة بالوقت المحدد. يمكنك المحاولة مرة أخرى."
	reward_label.text = "لم تُسجل نتيجة فوز ولم تُصرف أي مكافأة."
	accept_button.disabled = false
	if is_instance_valid(navigation_cancel_button):
		navigation_cancel_button.disabled = false
	panel.visible = true


func _advance_local_adventure_stage() -> void:
	var stages: Array = CITY_ADVENTURE_STAGES.get(selected_adventure_id, [])
	if stages.is_empty():
		return
	adventure_stage_index += 1
	if selected_adventure_id == "city_adventure_survival":
		_update_survival_race_hud()
	if adventure_stage_index >= stages.size():
		if selected_adventure_id == "city_adventure_message":
			adventure_stage_index = stages.size() - 1
			_set_message_puzzle_visible(true)
			description_label.text = "الأدلة التي جمعتها: مجرى الحياة في مصر، يبدأ اسمه بحرف النون، وينتهي باللام. ما الكلمة المقصودة؟"
			status_label.text = "وصلت إلى نقطة فك الشفرة. اكتب الإجابة لإكمال المغامرة."
			return
		_clear_rescue_citizen()
		_hide_adventure_treasure()
		_complete_active_mission()
		return
	active_target = stages[adventure_stage_index]
	target_marker.global_position = active_target
	if selected_adventure_id == "city_adventure_treasure" and adventure_stage_index == stages.size() - 1:
		_show_adventure_treasure()
	var adventure: Dictionary = CITY_ADVENTURES.get(selected_adventure_id, {})
	if selected_adventure_id == "city_adventure_message":
		var clues := [
			"الدليل الأول: ابحث عن مجرى الحياة الذي يمر في مصر.",
			"الدليل الثاني: يبدأ اسم هذا المجرى بحرف النون.",
			"الدليل الثالث: ينتهي الاسم بحرف اللام."
		]
		description_label.text = "%s\n%s" % [str(adventure.get("description", "")), clues[mini(adventure_stage_index - 1, clues.size() - 1)]]
	else:
		description_label.text = "%s\nالمرحلة %d من %d" % [str(adventure.get("description", "")), adventure_stage_index + 1, stages.size()]
	status_label.text = "أحسنت! انتقل إلى نقطة المغامرة التالية."


func _on_server_mission_stage_updated(mission_id: String, server_target: Vector3, stage_number: int, stage_count: int, message: String) -> void:
	if not GameModeManager.is_online_ready() or not mission_running or selected_activity_kind != "adventure" or mission_id != selected_adventure_id:
		return
	active_target = server_target
	if mission_id == "city_adventure_message" and stage_number > stage_count:
		adventure_stage_index = stage_count - 1
		target_marker.global_position = active_target
		_set_message_puzzle_visible(true)
		description_label.text = "الأدلة التي جمعتها: مجرى الحياة في مصر، يبدأ اسمه بحرف النون، وينتهي باللام. ما الكلمة المقصودة؟"
		status_label.text = message
		return
	adventure_stage_index = stage_number - 1
	if mission_id == "city_adventure_survival":
		_update_survival_race_hud()
		status_label.text = "اجتزت النقطة %d من 5! تابع السباق." % maxi(stage_number - 1, 1)
	if mission_id == "city_adventure_rescue" and stage_number > 1:
		_clear_rescue_citizen()
	target_marker.global_position = active_target
	if mission_id == "city_adventure_treasure" and stage_number == stage_count:
		_show_adventure_treasure()
	if mission_id == "city_adventure_message":
		var clues := [
			"الدليل الأول: ابحث عن مجرى الحياة الذي يمر في مصر.",
			"الدليل الثاني: يبدأ اسم هذا المجرى بحرف النون.",
			"الدليل الثالث: ينتهي الاسم بحرف اللام."
		]
		description_label.text = "%s\\n%s" % [str(CITY_ADVENTURES.get(mission_id, {}).get("description", "")), clues[mini(stage_number - 2, clues.size() - 1)]]
	else:
		description_label.text = "%s\\nالمرحلة %d من %d" % [str(CITY_ADVENTURES.get(mission_id, {}).get("description", "")), stage_number, stage_count]
	status_label.text = message

func _accept_job() -> void:
	if not is_instance_valid(active_job) or mission_running or job_running:
		return
	if GameModeManager.is_online_ready():
		status_label.text = "وظائف التوصيل Online غير مفعلة بعد؛ لن نستخدم نظام الوظائف القديم."
		accept_button.disabled = true
		return
	var key := selected_job_id
	var data := CityJobsCatalog.get_job(key)
	if data.is_empty() or completed_jobs.has(_daily_job_key(key)):
		status_label.text = "اختر وظيفة متاحة لم تنجزها اليوم."
		return
	var city_root := get_tree().current_scene
	var vehicle := city_root.get("city_vehicle") as Node3D if is_instance_valid(city_root) else null
	if not is_instance_valid(vehicle):
		status_label.text = "استدعِ سيارتك من زر المركبة قبل بدء وظيفة التوصيل."
		return
	active_job_stops.clear()
	for stop in data.get("stops", []):
		active_job_stops.append(stop)
	if active_job_stops.size() < 3:
		status_label.text = "مسار الوظيفة غير مكتمل؛ لم تبدأ المهمة."
		return
	landmark_navigation_active = false
	navigation_arrival_remaining = 0.0
	active_job_stop_index = 0
	returning_to_fuel = false
	active_job_target = active_job_stops[0]
	active_job_reward = data.duplicate(true)
	active_job_reward["job_id"] = key
	active_job_reward["money"] = 0
	active_job_reward["chips"] = 0
	job_running = true
	job_delivery_ring.visible = true
	_attach_job_package()
	target_marker.global_position = active_job_target
	target_marker.visible = true
	job_delivery_button.visible = false
	job_selector.visible = false
	accept_button.disabled = true
	description_label.text = "بدأت الوظيفة. قُد إلى نقطة التسليم، انزل من السيارة، واحمل الطرد إلى دائرة التسليم."
	reward_label.text = "سيتم تحديد الأجر لاحقًا بعد اعتماد اقتصاد المدينة."
	status_label.text = "اتجه بالسيارة إلى نقطة التسليم الأولى."

func _on_server_mission_start_result(success: bool, mission_id: String, server_target: Vector3, message: String) -> void:
	if not GameModeManager.is_online_ready():
		return
	status_label.text = message
	if not success:
		if mission_id == "city_adventure_survival":
			survival_prep_remaining = 0.0
			survival_time_remaining = 0.0
			if is_instance_valid(survival_progress_label):
				survival_progress_label.visible = false
			if is_instance_valid(survival_progress_bar):
				survival_progress_bar.visible = false
		accept_button.disabled = false
		return
	if not is_instance_valid(active_mission) or str(active_mission.get("server_activity_id")) != mission_id:
		accept_button.disabled = false
		return
	active_target = server_target
	mission_running = true
	if mission_id == "city_adventure_survival":
		survival_time_remaining = SURVIVAL_DURATION_SECONDS
		adventure_stage_index = 0
		_update_survival_race_hud()
	target_marker.global_position = active_target
	target_marker.visible = true
	accept_button.disabled = true
	description_label.text = "بدأت المهمة على الخادم. اتبع علامة الهدف."
	reward_label.text = "سيتم اعتماد الإكمال والمكافأة من الخادم بعد التحقق."


func _on_server_mission_failed(mission_id: String, message: String) -> void:
	if not GameModeManager.is_online_ready() or not mission_running or selected_activity_kind != "adventure" or mission_id != selected_adventure_id:
		return
	mission_running = false
	survival_time_remaining = 0.0
	survival_prep_remaining = 0.0
	if is_instance_valid(survival_progress_label):
		survival_progress_label.visible = false
	if is_instance_valid(survival_progress_bar):
		survival_progress_bar.visible = false
	_set_message_puzzle_visible(false)
	_clear_rescue_citizen()
	_hide_adventure_treasure()
	target_marker.visible = false
	status_label.text = message
	description_label.text = "انتهت مغامرة سباق النجاة. يمكنك المحاولة مرة أخرى."
	reward_label.text = "لم تُسجل نتيجة فوز ولم تُصرف أي مكافأة."
	accept_button.disabled = false
	panel.visible = true


func _on_server_mission_completed(mission_id: String) -> void:
	if not GameModeManager.is_online_ready() or not mission_running or not is_instance_valid(active_mission):
		return
	var expected_mission_id := selected_adventure_id if selected_activity_kind == "adventure" else str(active_mission.get("building_id"))
	if expected_mission_id != mission_id:
		return
	mission_running = false
	survival_time_remaining = 0.0
	survival_prep_remaining = 0.0
	if is_instance_valid(survival_progress_label):
		survival_progress_label.visible = false
	if is_instance_valid(survival_progress_bar):
		survival_progress_bar.visible = false
	_set_message_puzzle_visible(false)
	_clear_rescue_citizen()
	_hide_adventure_treasure()
	target_marker.visible = false
	status_label.text = "عثرت على الكنز وأكد الخادم إكمال المغامرة." if mission_id == "city_adventure_treasure" else ("اكتملت المغامرة بعد تحقق الخادم من جميع المراحل." if selected_activity_kind == "adventure" else "تحقق الخادم من وصولك إلى هدف المهمة.")
	description_label.text = "تم تسجيل اكتمال المسار خادميًا. لا يوجد صرف مكافآت في هذه النسخة."
	reward_label.text = "لم تُضف أي مكافأة محليًا."
	accept_button.disabled = false
	panel.visible = true


func _on_server_activity_progress_recorded(activity_kind: String, activity_id: String, reward_eligible: bool) -> void:
	if not GameModeManager.is_online_ready():
		return
	if not ["mission", "job", "achievement"].has(activity_kind):
		return
	if (activity_kind == "mission" and ["mission_shop", "mission_restaurant", "mission_employment"].has(activity_id)) or (activity_kind == "achievement" and activity_id == "first_steps"):
		# Read the account's authoritative ledger after the server confirms the write.
		PlayerSyncClient.fetch_verified_activity_progress()
	status_label.text = "تم حفظ إنجاز %s في سجل حسابك الخادمي." % activity_id
	description_label.text = "هذا الإنجاز موثّق من خادم اللعبة، ويمكن استعادته عند تسجيل الدخول من جهاز آخر."
	if activity_kind == "achievement" and activity_id == "explorer":
		description_label.text = "أكملت مهام المتجر والمطعم والتوظيف الثلاث، واعتمد الخادم إنجاز مستكشف المدينة."
	reward_label.text = "إثبات المكافأة متاح للتحقق." if reward_eligible else "تم حفظ الإنجاز دون مكافأة؛ المكافآت ما زالت مغلقة."


func _on_server_activity_proof_received(activity_kind: String, activity_id: String, proof_id: String) -> void:
	if not GameModeManager.is_online_ready() or not ["mission", "job", "achievement"].has(activity_kind):
		return
	var allowed_ids: Array = ["mission_shop", "mission_restaurant", "mission_employment"] if activity_kind == "mission" else (CityJobsCatalog.get_job_ids() if activity_kind == "job" else ["explorer"])
	if not allowed_ids.has(activity_id):
		return
	_pending_verified_proofs.append({"activity_kind": activity_kind, "activity_id": activity_id, "proof_id": proof_id})
	_process_next_server_reward_proof()


func _process_next_server_reward_proof() -> void:
	if _reward_claim_inflight or _pending_verified_proofs.is_empty() or not GameModeManager.is_online_ready():
		return
	var proof: Dictionary = _pending_verified_proofs.pop_front()
	_reward_claim_inflight = true
	status_label.text = "وصل إثبات إتمام %s. جارٍ اعتماد المكافأة." % str(proof.get("activity_id", ""))
	PlayerSyncClient.claim_verified_activity_reward(str(proof.get("proof_id", "")))


func _on_server_activity_proof_failed(activity_kind: String, activity_id: String, message: String) -> void:
	if not GameModeManager.is_online_ready():
		return
	var allowed_ids: Array = ["mission_shop", "mission_restaurant", "mission_employment"] if activity_kind == "mission" else (CityJobsCatalog.get_job_ids() if activity_kind == "job" else (["explorer"] if activity_kind == "achievement" else []))
	if not allowed_ids.has(activity_id):
		return
	status_label.text = message
	description_label.text = "اكتمل التحقق من الوصول، لكن خدمة إصدار الإثبات غير جاهزة."
	reward_label.text = "لم تُصرف مكافأة ولم يُضف أي رصيد."


func _on_verified_reward_claim_finished(success: bool, result: Dictionary, message: String) -> void:
	_reward_claim_inflight = false
	if not GameModeManager.is_online_ready():
		return
	status_label.text = message
	if success:
		description_label.text = "اعتمد الخادم المكافأة وسجلها في محفظتك المركزية."
		reward_label.text = "أرصدتك الخادمية: %d جنيه | %d رقائق" % [int(result.get("cash", 0)), int(result.get("chips", 0))]
		stats_label.text = "الرصيد الخادمي: %d جنيه | %d رقائق" % [int(result.get("cash", 0)), int(result.get("chips", 0))]
	else:
		description_label.text = "لم يتم إضافة أي رصيد محلي. سيظل الاعتماد متوقفًا حتى اكتمال إعداد الخدمة."
		reward_label.text = "لا توجد مكافأة محلية بديلة في وضع Online."
	call_deferred("_process_next_server_reward_proof")


func _on_server_job_start_result(success: bool, job_id: String, server_target: Vector3, message: String) -> void:
	if not GameModeManager.is_online_ready():
		return
	status_label.text = message
	if not success:
		accept_button.disabled = false
		return
	if not is_instance_valid(active_job):
		accept_button.disabled = false
		return
	var data: Dictionary = active_job.get_job_data()
	if str(data.get("job_id", "")) != job_id:
		accept_button.disabled = false
		return
	active_job_target = server_target
	active_job_reward = data.duplicate(true)
	job_running = true
	target_marker.global_position = active_job_target
	target_marker.visible = true
	accept_button.disabled = true
	description_label.text = "بدأت الوظيفة على الخادم. لا تعتمد المكافأة إلا بعد التحقق الخادمي."
	reward_label.text = "سيتم اعتماد الإكمال من الخادم؛ لا توجد مكافأة Online مفعلة حاليًا."


func _on_server_job_completed(job_id: String) -> void:
	if not GameModeManager.is_online_ready() or not job_running:
		return
	if str(active_job_reward.get("job_id", "")) != job_id:
		return
	job_running = false
	target_marker.visible = false
	status_label.text = "تحقق الخادم من وصولك إلى هدف الوظيفة."
	description_label.text = "تم تسجيل الوصول خادميًا. جارٍ إصدار إثبات المكافأة الآمن."
	reward_label.text = "مكافآت Online ما زالت مقفلة."
	accept_button.disabled = true
	panel.visible = true



func _attach_job_package() -> void:
	_remove_job_package()
	if not is_instance_valid(player):
		return
	job_package_visual = Node3D.new()
	job_package_visual.name = "JobPackageCarry"
	job_package_visual.position = Vector3(0.42, 1.05, -0.28)
	player.add_child(job_package_visual)
	var parcel := MeshInstance3D.new()
	var box := BoxMesh.new()
	var cargo_type := str(active_job_reward.get("cargo", "طرد"))
	box.size = Vector3(0.42, 0.34, 0.34)
	if cargo_type == "علبة بيتزا":
		box.size = Vector3(0.56, 0.14, 0.56)
	elif cargo_type == "حقيبة سفر":
		box.size = Vector3(0.42, 0.52, 0.30)
	elif cargo_type == "باقة أو هدية":
		box.size = Vector3(0.34, 0.42, 0.34)
	parcel.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.58, 0.34, 0.16)
	material.roughness = 0.82
	parcel.material_override = material
	job_package_visual.add_child(parcel)

func _remove_job_package() -> void:
	if is_instance_valid(job_package_visual):
		job_package_visual.queue_free()
	job_package_visual = null

func _deliver_current_job_package() -> void:
	if not job_running or returning_to_fuel or not is_instance_valid(player):
		return
	var city_root := get_tree().current_scene
	if not is_instance_valid(city_root) or bool(city_root.get("vehicle_occupied")):
		return
	var vehicle := city_root.get("city_vehicle") as Node3D
	if not is_instance_valid(vehicle):
		return
	var vehicle_distance := Vector2(vehicle.global_position.x, vehicle.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
	if vehicle_distance > 8.0:
		status_label.text = "قرّب السيارة من دائرة التسليم قبل تسليم الطرد."
		return
	var distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(active_job_target.x, active_job_target.z))
	if distance > 2.6:
		job_delivery_button.visible = false
		return
	_remove_job_package()
	job_delivery_button.visible = false
	active_job_stop_index += 1
	if active_job_stop_index < active_job_stops.size():
		active_job_target = active_job_stops[active_job_stop_index]
		_attach_job_package()
		status_label.text = "تم تسليم الطرد. احمل الطرد التالي واتجه إلى الوجهة %d من %d." % [active_job_stop_index + 1, active_job_stops.size()]
	else:
		returning_to_fuel = true
		active_job_target = CityJobsCatalog.FUEL_STATION
		status_label.text = "اكتملت جميع التوصيلات. اركب سيارتك وعُد إلى محطة الوقود."
	target_marker.global_position = active_job_target
	target_marker.visible = true
	description_label.text = "التقدم: %d من %d توصيلات." % [active_job_stop_index, active_job_stops.size()]

func _complete_active_job() -> void:
	if not job_running or not returning_to_fuel:
		return
	var job_id := str(active_job_reward.get("job_id", "job"))
	var key := _daily_job_key(job_id)
	_remove_job_package()
	job_delivery_button.visible = false
	var saved := complete_activity_once(key, "job", 0, 0, 0)
	if not saved:
		job_running = false
		returning_to_fuel = false
		active_job_stops.clear()
		target_marker.visible = false
		job_delivery_button.visible = false
		job_delivery_ring.visible = false
		status_label.text = "لم يتم حفظ إكمال الوظيفة؛ لم تُصرف مكافأة. يمكنك إعادة المحاولة لاحقًا."
		accept_button.disabled = false
		panel.visible = true
		return
	if is_instance_valid(daily_activities):
		daily_activities.record_job_completed(key)
	if is_instance_valid(achievement_manager):
		achievement_manager.record_job_completed(key)
	job_running = false
	returning_to_fuel = false
	active_job_stops.clear()
	target_marker.visible = false
	job_delivery_button.visible = false
	job_delivery_ring.visible = false
	status_label.text = "أنهيت جميع التوصيلات وعدت بالسيارة إلى محطة الوقود. تم تسجيل إنجاز الوظيفة."
	description_label.text = "رصيدك الحالي: %d جنيه، %d رقائق، المستوى %d." % [money, chips, player_level]
	reward_label.text = "تم حفظ إنجاز الوظيفة. الأجر لم يُحدد بعد."
	accept_button.disabled = true
	panel.visible = true

func _accept_mission() -> void:
	if not is_instance_valid(active_mission) or active_mission.is_queued_for_deletion() or mission_running or job_running:
		return
	landmark_navigation_active = false
	navigation_arrival_remaining = 0.0
	var data: Dictionary = active_mission.get_mission_data()
	var key: String = str(active_mission.get("building_id"))
	if not GameModeManager.is_online_ready() and (completed_missions.has(key) or player_level < int(data["level"])):
		return
	if GameModeManager.is_online_ready():
		accept_button.disabled = true
		status_label.text = "يراجع الخادم موقعك ويبدأ المهمة..."
		var server_mission_id := str(active_mission.get("server_activity_id"))
		if server_mission_id.is_empty():
			accept_button.disabled = false
			status_label.text = "تعذر تحديد معرف المهمة الخادمي."
			return
		if selected_activity_kind != "adventure" and PlayerSyncClient.is_server_activity_verified("mission", server_mission_id):
			accept_button.disabled = false
			status_label.text = "أنجزت هذه المهمة سابقًا على حسابك؛ تم استرجاع إنجازها الموثق."
			description_label.text = "لن نكرر المهمة أو نعتمد إكمالًا محليًا بدل السجل الخادمي."
			return
		AuthoritativeGameServer.request_start_mission.rpc_id(1, server_mission_id)
		return
	active_target = active_mission.global_position + data["target_offset"]
	active_target.y = 0.15
	mission_running = true
	target_marker.global_position = active_target
	target_marker.visible = true
	accept_button.disabled = true
	status_label.text = "بدأت المهمة! اتبع علامة الهدف الصفراء."
	description_label.text = "تحرك إلى نقطة الهدف المحددة في المدينة لإكمال المهمة."
	reward_label.text = "المكافأة عند الوصول: %d جنيه | %d رقائق" % [data["money"], data["chips"]]

func _complete_active_mission() -> void:
	if not mission_running or not is_instance_valid(active_mission):
		return
	if selected_activity_kind == "adventure":
		mission_running = false
		survival_time_remaining = 0.0
		survival_prep_remaining = 0.0
		if is_instance_valid(survival_progress_label):
			survival_progress_label.visible = false
		if is_instance_valid(survival_progress_bar):
			survival_progress_bar.visible = false
		_set_message_puzzle_visible(false)
		_clear_rescue_citizen()
		_hide_adventure_treasure()
		target_marker.visible = false
		status_label.text = "اكتملت المغامرة! لا توجد مكافأة أو نقاط يومية مفعلة."
		description_label.text = "تم إنهاء المغامرة في هذه الجلسة دون تسجيل تقدم دائم."
		reward_label.text = "لا توجد مكافأة، ولم تُضف نقاط مهام يومية أو إنجازات."
		accept_button.disabled = false
		panel.visible = true
		return
	var data: Dictionary = active_mission.get_mission_data()
	var key := str(active_mission.get("building_id"))
	var reward_money := int(data["money"])
	var reward_xp := int(data["xp"])
	var reward_chips := int(data["chips"])
	var saved := complete_activity_once(key, "mission", reward_money, reward_xp, reward_chips)
	if not saved:
		mission_running = false
		survival_time_remaining = 0.0
		if is_instance_valid(survival_progress_label):
			survival_progress_label.visible = false
		if is_instance_valid(survival_progress_bar):
			survival_progress_bar.visible = false
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
	survival_time_remaining = 0.0
	if is_instance_valid(survival_progress_label):
		survival_progress_label.visible = false
	if is_instance_valid(survival_progress_bar):
		survival_progress_bar.visible = false
	_set_message_puzzle_visible(false)
	_hide_adventure_treasure()
	target_marker.visible = false
	status_label.text = "عثرت على الكنز وأكملت المغامرة! لا توجد مكافأة مفعلة." if selected_adventure_id == "city_adventure_treasure" else ("اكتملت المغامرة! تم تسجيلها محليًا دون مكافأة." if selected_activity_kind == "adventure" else "اكتملت المهمة! تم حفظ المكافأة.")
	description_label.text = "تم تسجيل إكمال المغامرة في هذا الجهاز فقط." if selected_activity_kind == "adventure" else "رصيدك الحالي: %d جنيه، %d رقائق، المستوى %d." % [money, chips, player_level]
	reward_label.text = "لا توجد مكافأة لهذه النسخة." if selected_activity_kind == "adventure" else "تم حفظ إكمال المهمة ومكافآتها."
	accept_button.disabled = selected_activity_kind != "adventure"
	panel.visible = true

func _update_navigation_hud() -> void:
	var navigating := mission_running or job_running or landmark_navigation_active or navigation_arrival_remaining > 0.0
	if is_instance_valid(target_marker):
		var beacon_target := active_job_target if job_running else active_target if mission_running else landmark_navigation_target
		if navigating and navigation_arrival_remaining <= 0.0:
			target_marker.global_position = beacon_target
		target_marker.visible = navigating and navigation_arrival_remaining <= 0.0
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
	if GameModeManager.is_online_ready() and selected_activity_kind == "adventure" and mission_running:
		status_label.text = "جارٍ إلغاء المغامرة من الخادم..."
		if is_instance_valid(navigation_cancel_button):
			navigation_cancel_button.disabled = true
		AuthoritativeGameServer.request_cancel_mission.rpc_id(1)
		return
	landmark_navigation_active = false
	landmark_route_points.clear()
	landmark_route_index = 0
	navigation_arrival_remaining = 0.0
	navigation_off_route_time = 0.0
	navigation_route_notice_remaining = 0.0
	mission_running = false
	job_running = false
	if selected_activity_kind == "adventure":
		survival_prep_remaining = 0.0
		survival_time_remaining = 0.0
		if is_instance_valid(survival_progress_label):
			survival_progress_label.visible = false
		if is_instance_valid(survival_progress_bar):
			survival_progress_bar.visible = false
		_set_message_puzzle_visible(false)
		_clear_rescue_citizen()
		_hide_adventure_treasure()
	returning_to_fuel = false
	active_job_stops.clear()
	_remove_job_package()
	if is_instance_valid(job_delivery_button):
		job_delivery_button.visible = false
	if is_instance_valid(job_delivery_ring):
		job_delivery_ring.visible = false
	target_marker.visible = false
	status_label.text = "تم إلغاء التوجيه. لم تُحتسب المهمة أو الوظيفة ولم تُصرف مكافأة."
	description_label.text = "يمكنك فتح المبنى أو لوحة الوظيفة مرة أخرى للبدء من جديد."
	reward_label.text = "لا توجد مكافأة مستحقة حاليًا."
	accept_button.disabled = false
	accept_button.text = "بدء من جديد"
	panel.visible = true
	_update_navigation_hud()

func _set_message_puzzle_visible(visible: bool) -> void:
	message_puzzle_ready = visible
	if is_instance_valid(message_puzzle_input):
		message_puzzle_input.visible = visible
		if not visible:
			message_puzzle_input.text = ""
	if is_instance_valid(message_puzzle_submit_button):
		message_puzzle_submit_button.visible = visible


func _submit_message_puzzle_answer() -> void:
	if not mission_running or selected_adventure_id != "city_adventure_message" or not message_puzzle_ready or not is_instance_valid(message_puzzle_input):
		return
	var answer := message_puzzle_input.text.strip_edges()
	if answer.is_empty():
		status_label.text = "اكتب إجابتك أولًا."
		return
	message_puzzle_submit_button.disabled = true
	if GameModeManager.is_online_ready():
		AuthoritativeGameServer.request_submit_message_puzzle_answer.rpc_id(1, answer)
	else:
		var normalized_answer := answer.replace(" ", "").replace("ـ", "")
		if normalized_answer == "النيل":
			_set_message_puzzle_visible(false)
			_complete_active_mission()
		else:
			status_label.text = "الإجابة غير صحيحة. راجع الأدلة وحاول مرة أخرى."
	message_puzzle_submit_button.disabled = false


func _clear_rescue_citizen() -> void:
	if is_instance_valid(rescue_population) and is_instance_valid(rescue_citizen_actor) and rescue_population.has_method("set_rescue_citizen"):
		rescue_population.call("set_rescue_citizen", rescue_citizen_actor, false)
	rescue_citizen_actor = null
	if is_instance_valid(rescue_interaction_button):
		rescue_interaction_button.visible = false


func _update_rescue_interaction_prompt() -> void:
	if not is_instance_valid(rescue_interaction_button):
		return
	var rescue_stage_active := mission_running and selected_activity_kind == "adventure" and selected_adventure_id == "city_adventure_rescue" and adventure_stage_index == 0
	if not rescue_stage_active or not is_instance_valid(player):
		rescue_interaction_button.visible = false
		return
	if not is_instance_valid(rescue_population):
		var city_root := get_tree().current_scene
		rescue_population = city_root.get_node_or_null("CityNPCPopulation") if is_instance_valid(city_root) else null
	if not is_instance_valid(rescue_population) or not rescue_population.has_method("get_nearest_active_citizen"):
		rescue_interaction_button.visible = false
		return
	var citizen := rescue_population.call("get_nearest_active_citizen", active_target, 12.0) as Node3D
	if not is_instance_valid(citizen):
		rescue_interaction_button.visible = false
		return
	if rescue_citizen_actor != citizen:
		_clear_rescue_citizen()
		rescue_citizen_actor = citizen
		rescue_population.call("set_rescue_citizen", rescue_citizen_actor, true)
	var distance := Vector2(player.global_position.x - active_target.x, player.global_position.z - active_target.z).length()
	rescue_interaction_button.visible = distance <= 3.0
	status_label.text = "اقترب من المواطن لمساعدته." if distance > 3.0 else "المواطن يحتاج مساعدتك. اضغط «مساعدة المواطن»."


func _interact_with_rescue_citizen() -> void:
	if not mission_running or selected_adventure_id != "city_adventure_rescue" or adventure_stage_index != 0 or not is_instance_valid(player):
		return
	var distance := Vector2(player.global_position.x - active_target.x, player.global_position.z - active_target.z).length()
	if distance > 3.0:
		status_label.text = "اقترب من المواطن أولًا."
		return
	rescue_interaction_button.disabled = true
	if GameModeManager.is_online_ready():
		AuthoritativeGameServer.request_rescue_citizen_interaction.rpc_id(1)
	else:
		_clear_rescue_citizen()
		_advance_local_adventure_stage()
	rescue_interaction_button.disabled = false


func _hide_adventure_treasure() -> void:
	if is_instance_valid(adventure_treasure_visual):
		adventure_treasure_visual.queue_free()
	adventure_treasure_visual = null


func _add_treasure_box_part(parent: Node3D, part_name: String, size: Vector3, offset: Vector3, material: StandardMaterial3D) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.material_override = material
	part.position = offset
	parent.add_child(part)


func _show_adventure_treasure() -> void:
	_hide_adventure_treasure()
	var city_root := get_tree().current_scene
	if not is_instance_valid(city_root):
		return
	var chest := Node3D.new()
	chest.name = "AdventureTreasureVisual"
	city_root.add_child(chest)
	chest.global_position = active_target + Vector3(0.0, 0.34, 0.0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.20, 0.075, 0.025)
	wood.roughness = 0.78
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.92, 0.62, 0.12)
	gold.metallic = 0.72
	gold.roughness = 0.28
	_add_treasure_box_part(chest, "ChestBody", Vector3(1.05, 0.62, 0.72), Vector3(0.0, -0.18, 0.0), wood)
	_add_treasure_box_part(chest, "GoldenLid", Vector3(1.12, 0.22, 0.78), Vector3(0.0, 0.24, 0.0), gold)
	_add_treasure_box_part(chest, "FrontBand", Vector3(1.08, 0.09, 0.035), Vector3(0.0, -0.16, 0.37), gold)
	_add_treasure_box_part(chest, "SideBandLeft", Vector3(0.035, 0.52, 0.76), Vector3(-0.39, -0.16, 0.0), gold)
	_add_treasure_box_part(chest, "SideBandRight", Vector3(0.035, 0.52, 0.76), Vector3(0.39, -0.16, 0.0), gold)
	_add_treasure_box_part(chest, "LockPlate", Vector3(0.18, 0.22, 0.06), Vector3(0.0, -0.05, 0.405), gold)
	adventure_treasure_visual = chest


func _create_target_marker() -> void:
	# هذا المجسم محلي داخل نسخة اللاعب فقط؛ لا يُرسل كعنصر شبكة إلى بقية اللاعبين.
	target_marker = Node3D.new()
	target_marker.name = "PrivateMissionSkyBeacon"
	var delivery_ring := MeshInstance3D.new()
	delivery_ring.name = "GoldenDeliveryCircle"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.35
	ring_mesh.outer_radius = 1.65
	delivery_ring.mesh = ring_mesh
	delivery_ring.position.y = 0.08
	delivery_ring.visible = false
	job_delivery_ring = delivery_ring
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(1.0, 0.72, 0.20, 0.9)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.62, 0.12)
	ring_material.emission_energy_multiplier = 2.0
	delivery_ring.material_override = ring_material
	target_marker.add_child(delivery_ring)

	var outer_beam := MeshInstance3D.new()
	outer_beam.name = "GoldenBeamGlow"
	var outer_mesh := CylinderMesh.new()
	outer_mesh.top_radius = 0.22
	outer_mesh.bottom_radius = 0.72
	outer_mesh.height = 120.0
	outer_beam.mesh = outer_mesh
	outer_beam.position.y = 60.0
	outer_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color = Color(1.0, 0.72, 0.22, 0.18)
	glow_material.emission_enabled = true
	glow_material.emission = Color(1.0, 0.62, 0.12)
	glow_material.emission_energy_multiplier = 2.2
	outer_beam.material_override = glow_material
	target_marker.add_child(outer_beam)

	var core_beam := MeshInstance3D.new()
	core_beam.name = "GoldenBeamCore"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.075
	core_mesh.bottom_radius = 0.20
	core_mesh.height = 120.0
	core_beam.mesh = core_mesh
	core_beam.position.y = 60.0
	core_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_material := StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.albedo_color = Color(1.0, 0.91, 0.58, 0.48)
	core_material.emission_enabled = true
	core_material.emission = Color(1.0, 0.78, 0.30)
	core_material.emission_energy_multiplier = 3.0
	core_beam.material_override = core_material
	target_marker.add_child(core_beam)
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
	navigation_arrow.offset_left = -14
	navigation_arrow.offset_right = 14
	navigation_arrow.offset_top = 50
	navigation_arrow.offset_bottom = 78
	navigation_arrow.pivot_offset = Vector2(14, 14)
	navigation_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation_arrow.add_theme_font_size_override("font_size", 21)
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
	panel.size = Vector2(500, 360)
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
	survival_progress_label = Label.new()
	survival_progress_label.name = "SurvivalRaceProgress"
	survival_progress_label.text = "نقاط السباق: 0 / 5"
	survival_progress_label.visible = false
	content.add_child(survival_progress_label)
	survival_progress_bar = ProgressBar.new()
	survival_progress_bar.name = "SurvivalRaceProgressBar"
	survival_progress_bar.min_value = 0.0
	survival_progress_bar.max_value = 5.0
	survival_progress_bar.value = 0.0
	survival_progress_bar.show_percentage = false
	survival_progress_bar.custom_minimum_size = Vector2(0, 14)
	survival_progress_bar.visible = false
	content.add_child(survival_progress_bar)

	job_selector = OptionButton.new()
	job_selector.visible = false
	job_selector.item_selected.connect(_on_job_selected)
	content.add_child(job_selector)
	animal_selector = OptionButton.new()
	animal_selector.visible = false
	content.add_child(animal_selector)
	job_delivery_button = Button.new()
	job_delivery_button.text = "تسليم الطرد"
	job_delivery_button.visible = false
	job_delivery_button.pressed.connect(_deliver_current_job_package)
	content.add_child(job_delivery_button)
	rescue_interaction_button = Button.new()
	rescue_interaction_button.name = "RescueCitizenInteractionButton"
	rescue_interaction_button.text = "مساعدة المواطن"
	rescue_interaction_button.visible = false
	rescue_interaction_button.pressed.connect(_interact_with_rescue_citizen)
	content.add_child(rescue_interaction_button)
	message_puzzle_input = LineEdit.new()
	message_puzzle_input.name = "MysteryMessageAnswer"
	message_puzzle_input.placeholder_text = "اكتب حل الشفرة هنا"
	message_puzzle_input.visible = false
	content.add_child(message_puzzle_input)
	message_puzzle_submit_button = Button.new()
	message_puzzle_submit_button.name = "SubmitMysteryMessageAnswer"
	message_puzzle_submit_button.text = "إرسال الحل"
	message_puzzle_submit_button.visible = false
	message_puzzle_submit_button.pressed.connect(_submit_message_puzzle_answer)
	content.add_child(message_puzzle_submit_button)
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
