extends Node
## تقدم اللاعب عبر مباني التطوير الـ28 المعتمدة فقط.
## كل مبنى يضم خمس مراحل؛ إكمال المرحلة يفتح نطاق المستوى التالي.
## ترقية المستوى تتم بالمال، ولا تمنح الوظائف أو الأنشطة XP.

signal progression_changed(player_level: int, completed_stages: int)
signal development_panel_opened(building_id: String)

const SAVE_PATH := "user://kings_city_profile.cfg"
const MAX_PLAYER_LEVEL := 5000
const STAGES_PER_BUILDING := 5
const TOTAL_BUILDINGS := 28
const TOTAL_STAGES := TOTAL_BUILDINGS * STAGES_PER_BUILDING
const BASE_STAGE_COST := 3500
const COST_GROWTH := 1.065
const INTERACTION_RADIUS := 4.5

var player_level: int = 1
var completed_stage_count: int = 0
var _active_building_id := ""
var _active_building_name := ""
var _panel_layer: CanvasLayer
var _panel: PanelContainer
var _title_label: Label
var _progress_label: Label
var _cost_label: Label
var _status_label: Label
var _upgrade_button: Button

func _ready() -> void:
	_load_progress()

func register_city_layout(layout: Node3D) -> void:
	if not is_instance_valid(layout):
		return
	var approved := get_tree().get_nodes_in_group("approved_city_buildings")
	var registered := 0
	for building in approved:
		if not is_instance_valid(building) or not layout.is_ancestor_of(building):
			continue
		var building_id := str(building.name)
		var definition := CityMasterPlan.get_building_by_id(building_id)
		if definition.is_empty() or building.get_meta("development_interaction_created", false):
			continue
		var marker := Node3D.new()
		marker.name = "DevelopmentInteraction_" + building_id
		marker.set_script(load("res://scripts/development_building_interaction.gd"))
		marker.set("building_id", building_id)
		marker.set("building_title", str(definition.get("name", building_id)))
		marker.set("interaction_radius", INTERACTION_RADIUS)
		marker.global_position = building.to_global(Vector3(0.0, 0.0, 8.0))
		layout.add_child(marker)
		_create_ground_marker(marker)
		building.set_meta("development_interaction_created", true)
		registered += 1
	if registered != TOTAL_BUILDINGS:
		push_warning("Development progression: expected %d approved buildings, registered %d." % [TOTAL_BUILDINGS, registered])

func _create_ground_marker(parent: Node3D) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "DevelopmentGroundCircle"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.78
	mesh.outer_radius = 0.98
	ring.mesh = mesh
	ring.rotation.x = PI / 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.88, 0.68, 0.22, 0.92)
	material.emission_enabled = true
	material.emission = Color(0.55, 0.32, 0.06)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	ring.position.y = 0.08
	parent.add_child(ring)

	var label := Label3D.new()
	label.name = "DevelopmentMarkerLabel"
	label.text = "التطوير"
	label.position.y = 0.35
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.86, 0.45)
	parent.add_child(label)

func open_for_building(building_id: String, building_title: String) -> void:
	if GameModeManager.is_online_ready():
		return
	if not CityMasterPlan.is_approved_building(building_id):
		return
	_active_building_id = building_id
	_active_building_name = building_title
	_ensure_panel()
	_refresh_panel()
	_panel.visible = true
	development_panel_opened.emit(building_id)

func close_panel() -> void:
	if is_instance_valid(_panel):
		_panel.visible = false
	_active_building_id = ""

func _ensure_panel() -> void:
	if is_instance_valid(_panel_layer):
		return
	_panel_layer = CanvasLayer.new()
	_panel_layer.name = "DevelopmentProgressionLayer"
	_panel_layer.layer = 35
	get_tree().root.add_child(_panel_layer)

	_panel = PanelContainer.new()
	_panel.name = "DevelopmentProgressionPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -190
	_panel.offset_right = 190
	_panel.offset_top = -150
	_panel.offset_bottom = 150
	_panel.visible = false
	_panel_layer.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_title_label)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_progress_label)

	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_color_override("font_color", Color(0.92, 0.76, 0.30))
	box.add_child(_cost_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)

	_upgrade_button = Button.new()
	_upgrade_button.text = "تطوير المرحلة التالية"
	_upgrade_button.custom_minimum_size = Vector2(0, 44)
	_upgrade_button.pressed.connect(_purchase_current_stage)
	box.add_child(_upgrade_button)

	var close_button := Button.new()
	close_button.text = "إغلاق"
	close_button.pressed.connect(close_panel)
	box.add_child(close_button)

func _refresh_panel(message: String = "") -> void:
	if not is_instance_valid(_panel):
		return
	var building_index := int(completed_stage_count / STAGES_PER_BUILDING)
	if completed_stage_count >= TOTAL_STAGES:
		_title_label.text = "اكتمل التطوير الملكي"
		_progress_label.text = "وصلت إلى المستوى %d من %d. أكملت المباني الـ%d جميعها." % [MAX_PLAYER_LEVEL, MAX_PLAYER_LEVEL, TOTAL_BUILDINGS]
		_cost_label.text = "لا توجد مراحل تطوير متبقية"
		_status_label.text = message if not message.is_empty() else "لقد بلغت أعلى مستوى في المدينة."
		_upgrade_button.disabled = true
		_upgrade_button.text = "اكتمل التطوير"
		return

	var definition: Dictionary = CityMasterPlan.BUILDINGS[building_index]
	var stage_in_building := (completed_stage_count % STAGES_PER_BUILDING) + 1
	var next_level := _level_for_stage(completed_stage_count + 1)
	var previous_level := player_level
	var cost := _cost_for_stage(completed_stage_count)
	var expected_building_id := str(definition.get("id", ""))
	var is_correct_building := _active_building_id == expected_building_id

	_title_label.text = "مبنى التطوير %d من %d — %s" % [building_index + 1, TOTAL_BUILDINGS, str(definition.get("name", _active_building_name))]
	_progress_label.text = "المرحلة %d من %d\nمستواك الحالي: %d  ←  المستوى بعد التطوير: %d\nإجمالي المراحل المكتملة: %d من %d" % [stage_in_building, STAGES_PER_BUILDING, previous_level, next_level, completed_stage_count, TOTAL_STAGES]
	_cost_label.text = "تكلفة التطوير: %s جنيه" % _format_money(cost)
	if not message.is_empty():
		_status_label.text = message
	elif not is_correct_building:
		_status_label.text = "هذا المبنى غير مفتوح بعد. المبنى المطلوب حاليًا: %s." % str(definition.get("name", ""))
	elif stage_in_building == STAGES_PER_BUILDING:
		_status_label.text = "هذه آخر مرحلة في المبنى. بعد إكمالها يُفتح مبنى التطوير التالي."
	else:
		_status_label.text = "ادفع تكلفة التطوير لفتح المرحلة التالية."
	_upgrade_button.disabled = not is_correct_building or WalletManager.get_balance("money") < cost
	_upgrade_button.text = "تطوير المرحلة %d" % stage_in_building

func _purchase_current_stage() -> void:
	if GameModeManager.is_online_ready():
		_refresh_panel("التطوير عبر الإنترنت ينتظر ربط تحقق التطوير بالخادم.")
		return
	if completed_stage_count >= TOTAL_STAGES:
		_refresh_panel()
		return
	var building_index := int(completed_stage_count / STAGES_PER_BUILDING)
	var definition: Dictionary = CityMasterPlan.BUILDINGS[building_index]
	if _active_building_id != str(definition.get("id", "")):
		_refresh_panel("اذهب إلى مبنى التطوير المفتوح حاليًا.")
		return
	var cost := _cost_for_stage(completed_stage_count)
	var next_count := completed_stage_count + 1
	var next_level := _level_for_stage(next_count)
	var transaction_id := "development_stage_%03d" % next_count
	var updates := {
		"development_stage_count": next_count,
		"development_level": next_level,
		"player_level": next_level,
		"xp": 0
	}
	if not WalletManager.purchase_once(transaction_id, "money", cost, "تطوير %s المرحلة %d" % [str(definition.get("name", "")), ((completed_stage_count % STAGES_PER_BUILDING) + 1)], updates):
		_refresh_panel("الرصيد غير كافٍ أو تعذر حفظ عملية التطوير. لم يتم خصم أي مبلغ.")
		return
	completed_stage_count = next_count
	player_level = next_level
	_sync_mission_manager()
	progression_changed.emit(player_level, completed_stage_count)
	if completed_stage_count >= TOTAL_STAGES:
		_refresh_panel("مبروك! وصلت إلى المستوى 5000.")
	else:
		var new_building_index := int(completed_stage_count / STAGES_PER_BUILDING)
		if new_building_index != building_index:
			_active_building_id = str(CityMasterPlan.BUILDINGS[new_building_index].get("id", ""))
			_active_building_name = str(CityMasterPlan.BUILDINGS[new_building_index].get("name", ""))
			_refresh_panel("اكتملت مراحل هذا المبنى. تم فتح المبنى التالي في تسلسل التطوير.")
		else:
			_refresh_panel("تم التطوير بنجاح. أصبح مستواك %d." % player_level)

func _sync_mission_manager() -> void:
	var manager := get_tree().current_scene.get_node_or_null("MissionManager") if is_instance_valid(get_tree().current_scene) else null
	if is_instance_valid(manager):
		manager.set("player_level", player_level)
		manager.set("xp", 0)

func _load_progress() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("Development progression: profile unreadable; progression was not overwritten.")
		return
	var saved_level := 1
	if err == OK:
		saved_level = clampi(int(config.get_value("profile", "development_level", config.get_value("profile", "player_level", 1))), 1, MAX_PLAYER_LEVEL)
		var saved_count: Variant = config.get_value("profile", "development_stage_count", null)
		if saved_count == null:
			completed_stage_count = clampi(int(floor(float(saved_level - 1) * float(TOTAL_STAGES) / float(MAX_PLAYER_LEVEL))), 0, TOTAL_STAGES)
		else:
			completed_stage_count = clampi(int(saved_count), 0, TOTAL_STAGES)
	player_level = max(saved_level, _level_for_stage(completed_stage_count))
	if completed_stage_count >= TOTAL_STAGES:
		player_level = MAX_PLAYER_LEVEL

func _level_for_stage(completed_stages: int) -> int:
	if completed_stages <= 0:
		return 1
	return mini(MAX_PLAYER_LEVEL, int(ceil(float(completed_stages * MAX_PLAYER_LEVEL) / float(TOTAL_STAGES))))

func _cost_for_stage(stage_index_zero_based: int) -> int:
	var raw_cost := float(BASE_STAGE_COST) * pow(COST_GROWTH, float(maxi(0, stage_index_zero_based)))
	return clampi(int(round(raw_cost)), BASE_STAGE_COST, WalletManager.MAX_BALANCE)

func _format_money(amount: int) -> String:
	if amount >= 1000000000:
		return "%.2f مليار" % (float(amount) / 1000000000.0)
	if amount >= 1000000:
		return "%.2f مليون" % (float(amount) / 1000000.0)
	if amount >= 1000:
		return "%.1f ألف" % (float(amount) / 1000.0)
	return str(amount)

func get_completed_stage_count() -> int:
	return completed_stage_count

func get_progress_snapshot() -> Dictionary:
	return {
		"player_level": player_level,
		"max_level": MAX_PLAYER_LEVEL,
		"completed_stages": completed_stage_count,
		"total_stages": TOTAL_STAGES,
		"current_building_index": mini(int(completed_stage_count / STAGES_PER_BUILDING), TOTAL_BUILDINGS - 1),
		"stage_in_building": (completed_stage_count % STAGES_PER_BUILDING) + 1,
		"cost_next": _cost_for_stage(completed_stage_count) if completed_stage_count < TOTAL_STAGES else 0
	}
