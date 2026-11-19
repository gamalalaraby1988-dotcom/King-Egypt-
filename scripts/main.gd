extends Node3D

@export var city_half_size: int = 3
@export var block_spacing: float = 24.0

var interior_root: Node3D = null
var interior_player: CharacterBody3D = null
var interior_return_transform: Transform3D
var interior_loading_layer: CanvasLayer
var interior_loading_label: Label
var interior_exit_button: Button
var interior_transition_busy := false
var interior_loading_message_key := "interior_loading"
var interior_hidden_world_states: Dictionary = {}
var city_vehicle: CharacterBody3D = null
var vehicle_interaction_button: Button = null
var vehicle_summon_button: Button = null
var vehicle_occupied := false
var _vehicle_key_was_down := false
var _player_saved_collision_layer := 1
var _player_saved_collision_mask := 1
const INTERIOR_WORLD_POSITION := Vector3(1000.0, 0.0, 1000.0)

func _ready() -> void:
	if AuthoritativeGameServer.is_dedicated_server_requested():
		_create_ground()
		_create_city()
		_create_approved_city_layout()
		_create_city_signage()
		var local_player := get_node_or_null("Player")
		if is_instance_valid(local_player):
			remove_child(local_player)
			local_player.queue_free()
		_create_interactive_buildings()
		_create_camp()
		_create_royal_resort()
		_create_desert_camp()
		_create_pyramids_area()
		return
	_create_ground()
	_create_city()
	_create_approved_city_layout()
	_create_city_signage()
	_create_mobile_hud()
	var key_light := get_node_or_null("DirectionalLight3D")
	if key_light:
		key_light.add_to_group("quality_shadow_light")
	_create_interactive_buildings()
	_create_camp()
	_create_royal_resort()
	_create_desert_camp()
	_create_pyramids_area()
	_create_navigation_destinations()
	_create_interior_transition_ui()
	_create_player_vehicle()
	_create_mode_selection_ui()
	_create_founder_update_panel()
	GameModeManager.status_changed.connect(_on_mode_status_changed)
	GameModeManager.online_connected.connect(_on_mode_connected)
	AuthoritativeGameServer.authentication_completed.connect(_on_player_server_authenticated)
	PlayerAccountAuthClient.session_access_token_changed.connect(_on_player_access_token_changed)
	PlayerAccountAuthClient.session_expired.connect(_on_player_account_session_expired)
	GameModeManager.online_disconnected.connect(_on_mode_disconnected)


func _create_approved_city_layout() -> void:
	var layout_script := load("res://scripts/approved_city_layout.gd") as Script
	if layout_script == null:
		push_warning("تعذر تحميل تخطيط المدينة المعتمد.")
		return
	var layout := Node3D.new()
	layout.name = "ApprovedCityLayout"
	layout.set_script(layout_script)
	add_child(layout)
	DevelopmentManager.register_city_layout(layout)


func _process(_delta: float) -> void:
	if GameModeManager.is_online_ready():
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		return
	# المركبات تخص مساحة المدينة؛ أخفِ أدواتها طوال الانتقال أو الوجود داخل مبنى.
	if interior_transition_busy or is_instance_valid(interior_root):
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		return
	if vehicle_occupied and (not is_instance_valid(city_vehicle) or not is_instance_valid(get_node_or_null("Player"))):
		_recover_vehicle_occupancy()
	if vehicle_occupied:
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = true
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		return
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = true
		vehicle_summon_button.text = "إحضار السيارة" if CityLanguage.get_language() == "ar" else "Call vehicle"
	if not is_instance_valid(city_vehicle):
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		return
	var close_enough := player.global_position.distance_to(city_vehicle.global_position) <= 5.0
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = close_enough
		vehicle_interaction_button.text = "🚪 ركوب السيارة" if CityLanguage.get_language() == "ar" else "Enter vehicle"

func _unhandled_input(event: InputEvent) -> void:
	if GameModeManager.is_online_ready():
		return
	if event is InputEventKey and event.keycode == KEY_E:
		if event.pressed and not event.echo and not _vehicle_key_was_down:
			_vehicle_key_was_down = true
			_toggle_vehicle_use()
		elif not event.pressed:
			_vehicle_key_was_down = false

func _create_player_vehicle() -> void:
	# لا يتم إنشاء السيارة عند بداية اللعبة؛ اللاعب هو من يستدعيها عند الحاجة.
	var layer := CanvasLayer.new()
	layer.name = "VehicleInteractionLayer"
	layer.layer = 20
	add_child(layer)

	# أزرار المركبة صغيرة ومثبتة أسفل اليمين؛ زر السيارة أعلى زر الركوب/الخروج.
	var viewport_size := get_viewport().get_visible_rect().size
	var control_scale := clampf(minf(viewport_size.x, viewport_size.y) / 720.0, 0.58, 1.0)
	var control_width := 142.0 * control_scale
	var control_height := 36.0 * control_scale
	var control_gap := 4.0 * control_scale
	var right_margin := 7.0 * control_scale
	var bottom_margin := 8.0 * control_scale

	vehicle_summon_button = Button.new()
	vehicle_summon_button.name = "VehicleSummonButton"
	vehicle_summon_button.text = "🚗 إحضار السيارة"
	vehicle_summon_button.custom_minimum_size = Vector2(control_width, control_height)
	vehicle_summon_button.anchor_left = 1.0
	vehicle_summon_button.anchor_right = 1.0
	vehicle_summon_button.anchor_top = 1.0
	vehicle_summon_button.anchor_bottom = 1.0
	vehicle_summon_button.offset_left = -control_width - right_margin
	vehicle_summon_button.offset_right = -right_margin
	vehicle_summon_button.offset_top = -(bottom_margin + control_height * 2.0 + control_gap)
	vehicle_summon_button.offset_bottom = -(bottom_margin + control_height + control_gap)
	vehicle_summon_button.add_theme_font_size_override("font_size", 12)
	vehicle_summon_button.pressed.connect(_summon_player_vehicle)
	layer.add_child(vehicle_summon_button)

	vehicle_interaction_button = Button.new()
	vehicle_interaction_button.name = "VehicleInteractionButton"
	vehicle_interaction_button.text = "🚪 ركوب السيارة"
	vehicle_interaction_button.custom_minimum_size = Vector2(control_width, control_height)
	vehicle_interaction_button.anchor_left = 1.0
	vehicle_interaction_button.anchor_right = 1.0
	vehicle_interaction_button.anchor_top = 1.0
	vehicle_interaction_button.anchor_bottom = 1.0
	vehicle_interaction_button.offset_left = -control_width - right_margin
	vehicle_interaction_button.offset_right = -right_margin
	vehicle_interaction_button.offset_top = -(bottom_margin + control_height)
	vehicle_interaction_button.offset_bottom = -bottom_margin
	vehicle_interaction_button.add_theme_font_size_override("font_size", 12)
	vehicle_interaction_button.visible = false
	vehicle_interaction_button.pressed.connect(_toggle_vehicle_use)
	layer.add_child(vehicle_interaction_button)

func _summon_player_vehicle() -> void:
	if interior_transition_busy or is_instance_valid(interior_root) or vehicle_occupied:
		return
	var selected_vehicle_id := VehicleStoreManager.get_selected_vehicle_id()
	if not VehicleStoreManager.has_vehicle(selected_vehicle_id):
		push_warning("لا يمكن استدعاء مركبة غير مملوكة.")
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		return
	if not is_instance_valid(city_vehicle):
		var packed := load("res://scenes/vehicle.tscn") as PackedScene
		if packed == null:
			push_warning("تعذر تحميل مشهد المركبة.")
			return
		city_vehicle = packed.instantiate() as CharacterBody3D
		if city_vehicle == null:
			return
		city_vehicle.name = "PlayerVehicle"
		city_vehicle.set_meta("vehicle_id", selected_vehicle_id)
		add_child(city_vehicle)
		city_vehicle.set_physics_process(false)
		var vehicle_hud := city_vehicle.get_node_or_null("VehicleHUDLayer/VehicleHUD") as Control
		if is_instance_valid(vehicle_hud):
			if vehicle_hud.has_method("_clear_controls"):
				vehicle_hud.call("_clear_controls")
			vehicle_hud.visible = false
		var vehicle_camera := city_vehicle.get_node_or_null("VehicleCameraPivot/SpringArm3D/VehicleCamera") as Camera3D
		if is_instance_valid(vehicle_camera):
			vehicle_camera.current = false

	# سجل معرف المركبة المختارة مع الاستدعاء؛ لا يُسمح باختيار مركبة غير مملوكة.
	city_vehicle.set_meta("vehicle_id", selected_vehicle_id)
	# تظهر المركبة بجانب اللاعب عند الاستدعاء، ويمكن إحضارها مجددًا إذا تُركت بعيدًا.
	var side := player.global_transform.basis.x.normalized()
	var summon_position := player.global_position + side * 3.5
	summon_position.y = player.global_position.y
	city_vehicle.global_position = summon_position
	city_vehicle.global_rotation.y = player.global_rotation.y
	city_vehicle.velocity = Vector3.ZERO
	city_vehicle.call("set_drive", false)
	city_vehicle.call("set_brake", true)
	city_vehicle.call("set_reverse", false)
	city_vehicle.call("set_steering", 0.0)
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = true

func _toggle_vehicle_use() -> void:
	if interior_transition_busy or is_instance_valid(interior_root):
		return
	if vehicle_occupied:
		_exit_player_vehicle()
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or not is_instance_valid(city_vehicle):
		return
	if player.global_position.distance_to(city_vehicle.global_position) > 5.0:
		return
	if player.get("animal_riding") == true or player.get("sitting") == true:
		return
	_set_mobile_hud_active(false)
	vehicle_occupied = true
	_player_saved_collision_layer = player.collision_layer
	_player_saved_collision_mask = player.collision_mask
	player.set_mobile_move(Vector2.ZERO)
	player.set_mobile_sprint(false)
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	var player_camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if is_instance_valid(player_camera):
		player_camera.current = false
	city_vehicle.call("set_brake", false)
	city_vehicle.call("set_drive", false)
	city_vehicle.set_physics_process(true)
	var vehicle_hud := city_vehicle.get_node_or_null("VehicleHUDLayer/VehicleHUD") as Control
	if is_instance_valid(vehicle_hud):
		vehicle_hud.visible = true
	var vehicle_camera := city_vehicle.get_node_or_null("VehicleCameraPivot/SpringArm3D/VehicleCamera") as Camera3D
	if is_instance_valid(vehicle_camera):
		vehicle_camera.current = true
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.text = "🚪 النزول من السيارة" if CityLanguage.get_language() == "ar" else "Exit vehicle"
		vehicle_interaction_button.visible = true

func _recover_vehicle_occupancy() -> void:
	# لا تترك حالة الركوب عالقة إذا حُذفت السيارة أو اللاعب أثناء القيادة.
	var player := get_node_or_null("Player") as CharacterBody3D
	if is_instance_valid(city_vehicle):
		city_vehicle.call("set_drive", false)
		city_vehicle.call("set_brake", true)
		city_vehicle.call("set_reverse", false)
		city_vehicle.call("set_steering", 0.0)
		city_vehicle.set_physics_process(false)
		var vehicle_hud := city_vehicle.get_node_or_null("VehicleHUDLayer/VehicleHUD") as Control
		if is_instance_valid(vehicle_hud):
			if vehicle_hud.has_method("_clear_controls"):
				vehicle_hud.call("_clear_controls")
			vehicle_hud.visible = false
		var vehicle_camera := city_vehicle.get_node_or_null("VehicleCameraPivot/SpringArm3D/VehicleCamera") as Camera3D
		if is_instance_valid(vehicle_camera):
			vehicle_camera.current = false
	if is_instance_valid(player):
		player.visible = true
		player.collision_layer = _player_saved_collision_layer
		player.collision_mask = _player_saved_collision_mask
		player.set_physics_process(true)
		var player_camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
		if is_instance_valid(player_camera):
			player_camera.current = true
	vehicle_occupied = false
	_set_mobile_hud_active(is_instance_valid(player))
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = false
		vehicle_interaction_button.text = "🚪 ركوب السيارة" if CityLanguage.get_language() == "ar" else "Enter vehicle"
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = is_instance_valid(player)

func _exit_player_vehicle() -> void:
	if not vehicle_occupied:
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or not is_instance_valid(city_vehicle):
		return
	var side := city_vehicle.global_transform.basis.x.normalized()
	var exit_position := city_vehicle.global_position + side * 2.1 + Vector3.UP * 0.15
	player.global_position = exit_position
	player.velocity = Vector3.ZERO
	player.visible = true
	player.collision_layer = _player_saved_collision_layer
	player.collision_mask = _player_saved_collision_mask
	player.set_physics_process(true)
	var vehicle_camera := city_vehicle.get_node_or_null("VehicleCameraPivot/SpringArm3D/VehicleCamera") as Camera3D
	if is_instance_valid(vehicle_camera):
		vehicle_camera.current = false
	var player_camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if is_instance_valid(player_camera):
		player_camera.current = true
	var vehicle_hud := city_vehicle.get_node_or_null("VehicleHUDLayer/VehicleHUD") as Control
	if is_instance_valid(vehicle_hud):
		if vehicle_hud.has_method("_clear_controls"):
			vehicle_hud.call("_clear_controls")
		vehicle_hud.visible = false
	city_vehicle.call("set_drive", false)
	city_vehicle.call("set_brake", true)
	city_vehicle.call("set_reverse", false)
	city_vehicle.call("set_steering", 0.0)
	city_vehicle.set_physics_process(false)
	vehicle_occupied = false
	_set_mobile_hud_active(true)
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.text = "🚪 ركوب السيارة" if CityLanguage.get_language() == "ar" else "Enter vehicle"
		vehicle_interaction_button.visible = player.global_position.distance_to(city_vehicle.global_position) <= 5.0

func _create_interior_transition_ui() -> void:
	interior_loading_layer = CanvasLayer.new()
	interior_loading_layer.name = "InteriorTransitionUI"
	interior_loading_layer.layer = 30
	add_child(interior_loading_layer)
	var backdrop := ColorRect.new()
	backdrop.name = "LoadingBackdrop"
	backdrop.color = Color(0.035, 0.045, 0.055, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	interior_loading_layer.add_child(backdrop)
	var content := VBoxContainer.new()
	content.name = "LoadingContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.position = Vector2(-210, -85)
	content.size = Vector2(420, 170)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	backdrop.add_child(content)
	interior_loading_label = Label.new()
	interior_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interior_loading_label.add_theme_font_size_override("font_size", 26)
	interior_loading_label.add_theme_color_override("font_color", Color(0.94, 0.79, 0.43))
	content.add_child(interior_loading_label)
	var hint := Label.new()
	hint.text = "𓂀   KING OF EGYPT CITY   𓂀"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78))
	content.add_child(hint)
	interior_exit_button = Button.new()
	interior_exit_button.text = CityLanguage.translate("interior_exit")
	interior_exit_button.visible = false
	interior_exit_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	interior_exit_button.offset_left = 24
	interior_exit_button.offset_right = -24
	interior_exit_button.offset_top = -76
	interior_exit_button.offset_bottom = -20
	interior_exit_button.pressed.connect(return_from_building_interior)
	interior_loading_layer.add_child(interior_exit_button)
	CityLanguage.language_changed.connect(_refresh_interior_ui_language)

func _refresh_interior_ui_language() -> void:
	if is_instance_valid(interior_loading_label):
		interior_loading_label.text = CityLanguage.translate(interior_loading_message_key)
	if is_instance_valid(interior_exit_button):
		interior_exit_button.text = CityLanguage.translate("interior_exit")

func _show_interior_loading(show_exit: bool = false, message_key: String = "interior_loading") -> void:
	if not is_instance_valid(interior_loading_layer):
		return
	interior_loading_message_key = message_key
	var backdrop := interior_loading_layer.get_node_or_null("LoadingBackdrop") as ColorRect
	if is_instance_valid(backdrop):
		backdrop.visible = not show_exit
	interior_exit_button.visible = show_exit
	_refresh_interior_ui_language()

func _hide_interior_loading() -> void:
	var backdrop: ColorRect = null
	if is_instance_valid(interior_loading_layer):
		backdrop = interior_loading_layer.get_node_or_null("LoadingBackdrop") as ColorRect
	if is_instance_valid(backdrop):
		backdrop.visible = false
	interior_exit_button.visible = false

func enter_building_interior(building: Node3D, actor: Node3D) -> void:
	var body := actor as CharacterBody3D
	if interior_transition_busy or is_instance_valid(interior_root) or vehicle_occupied:
		return
	if not is_instance_valid(building) or building.is_queued_for_deletion() or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	var building_data: Dictionary = building.get_mission_data() if building.has_method("get_mission_data") else {}
	if not bool(building_data.get("requires_interior", false)):
		return
	# نظام المدينة الرئيسي هو المصدر الوحيد لحالة الانتقال؛ امنع الانتقال من وضعية غير آمنة.
	if bool(body.get("sitting")) or bool(body.get("animal_riding")):
		return
	var manager := get_node_or_null("MissionManager")
	if is_instance_valid(manager) and (bool(manager.get("mission_running")) or bool(manager.get("job_running"))):
		return
	var radius_value: Variant = building.get("interaction_radius")
	var allowed_distance := float(radius_value) if radius_value != null else 4.5
	if body.global_position.distance_to(building.global_position) > clampf(allowed_distance, 0.5, 4.8) + 0.65:
		return
	interior_transition_busy = true
	interior_player = body
	interior_return_transform = body.global_transform
	body.set_physics_process(false)
	_show_interior_loading(false)
	await get_tree().create_timer(0.65).timeout
	# أعد التحقق بعد التحميل؛ لا تنقل لاعبًا أو مبنى حُذف أثناء الانتظار.
	if not is_inside_tree() or not is_instance_valid(building) or building.is_queued_for_deletion() or not is_instance_valid(body) or body.is_queued_for_deletion():
		if is_instance_valid(body):
			body.set_physics_process(true)
		interior_transition_busy = false
		interior_player = null
		_hide_interior_loading()
		return
	_set_city_world_hidden(true)
	_create_building_interior(str(building.get("building_title")))
	body.global_position = INTERIOR_WORLD_POSITION + Vector3(0, 1.05, 2.8)
	body.velocity = Vector3.ZERO
	body.rotation.y = PI
	body.set_physics_process(true)
	interior_transition_busy = false
	_show_interior_loading(true)

func _set_city_world_hidden(hidden: bool) -> void:
	if hidden:
		interior_hidden_world_states.clear()
		for item in get_tree().get_nodes_in_group("city_world_geometry"):
			if not is_instance_valid(item):
				continue
			var state: Dictionary = {"visible": item.visible if item is Node3D else true}
			if item is CollisionObject3D:
				state["collision_layer"] = item.collision_layer
				state["collision_mask"] = item.collision_mask
				item.collision_layer = 0
				item.collision_mask = 0
			if item is Node3D:
				item.visible = false
			interior_hidden_world_states[item] = state
	else:
		for item in interior_hidden_world_states.keys():
			if not is_instance_valid(item):
				continue
			var state: Dictionary = interior_hidden_world_states[item]
			if item is CollisionObject3D:
				item.collision_layer = int(state.get("collision_layer", 1))
				item.collision_mask = int(state.get("collision_mask", 1))
			if item is Node3D:
				item.visible = bool(state.get("visible", true))
		interior_hidden_world_states.clear()

func _create_building_interior(building_title: String) -> void:
	if is_instance_valid(interior_root):
		interior_root.queue_free()
	interior_root = Node3D.new()
	interior_root.name = "GeneratedBuildingInterior"
	interior_root.position = INTERIOR_WORLD_POSITION
	add_child(interior_root)
	# غرفة أولية خفيفة مبنية من المجسمات البدائية الموجودة بالفعل في المشروع.
	_create_box(interior_root, "InteriorFloor", Vector3(14, 0.35, 14), Vector3(0, 0, 0), Color(0.48, 0.39, 0.27), true)
	_create_box(interior_root, "BackWall", Vector3(14, 5, 0.35), Vector3(0, 2.5, -7), Color(0.69, 0.59, 0.43), true)
	_create_box(interior_root, "LeftWall", Vector3(0.35, 5, 14), Vector3(-7, 2.5, 0), Color(0.63, 0.53, 0.39), true)
	_create_box(interior_root, "RightWall", Vector3(0.35, 5, 14), Vector3(7, 2.5, 0), Color(0.63, 0.53, 0.39), true)
	_create_box(interior_root, "FrontWallLeft", Vector3(4.6, 5, 0.35), Vector3(-4.7, 2.5, 7), Color(0.69, 0.59, 0.43), true)
	_create_box(interior_root, "FrontWallRight", Vector3(4.6, 5, 0.35), Vector3(4.7, 2.5, 7), Color(0.69, 0.59, 0.43), true)
	_create_box(interior_root, "DoorLintel", Vector3(4.0, 1.1, 0.35), Vector3(0, 4.45, 7), Color(0.76, 0.58, 0.25), true)
	_create_box(interior_root, "ReceptionDesk", Vector3(4.2, 1.15, 1.1), Vector3(0, 0.75, -2.4), Color(0.30, 0.20, 0.12), true)
	_create_box(interior_root, "GoldWallBand", Vector3(13.8, 0.18, 0.22), Vector3(0, 3.9, -6.78), Color(0.86, 0.67, 0.30))
	var title := Label3D.new()
	title.text = building_title
	title.position = Vector3(0, 3.25, -6.78)
	title.font_size = 44
	title.pixel_size = 0.012
	title.modulate = Color(1.0, 0.88, 0.58)
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# Interior wall title remains aligned with the wall-mounted plaque.
	interior_root.add_child(title)
	_create_interior_furnishings(interior_root, building_title)
	_create_interior_staff(interior_root, building_title)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.2, 0)
	light.light_color = Color(1.0, 0.82, 0.57)
	light.light_energy = 1.2
	light.omni_range = 18.0
	interior_root.add_child(light)

func _create_interior_furnishings(root: Node3D, building_title: String) -> void:
	# أثاث هندسي خفيف ومختلف لكل مبنى، دون صور أو خامات أو مكتبات إضافية.
	if building_title == "المتجر":
		for index in range(3):
			var x := -4.2 + float(index) * 4.2
			_create_box(root, "ShopShelf_%d" % index, Vector3(1.0, 2.5, 3.4), Vector3(x, 1.25, -0.4), Color(0.34, 0.23, 0.13), true)
			for level in range(3):
				_create_box(root, "ShopShelfBand_%d_%d" % [index, level], Vector3(1.08, 0.12, 3.5), Vector3(x, 0.55 + float(level) * 0.78, -0.4), Color(0.82, 0.63, 0.30))
		_create_box(root, "ShopCheckout", Vector3(2.8, 1.0, 1.0), Vector3(0, 0.5, 3.7), Color(0.28, 0.19, 0.12), true)
	elif building_title == "المطعم":
		for index in range(4):
			var x := -3.6 if index % 2 == 0 else 3.6
			var z := -3.8 if index < 2 else 1.0
			_create_box(root, "RestaurantTable_%d" % index, Vector3(2.0, 0.18, 1.6), Vector3(x, 1.0, z), Color(0.40, 0.24, 0.13), true)
			_create_box(root, "RestaurantTableLeg_%d" % index, Vector3(0.22, 0.9, 0.22), Vector3(x, 0.48, z), Color(0.25, 0.18, 0.12), true)
			for side in [-1.0, 1.0]:
				_create_box(root, "RestaurantSeat_%d_%d" % [index, int(side)], Vector3(0.8, 0.85, 0.8), Vector3(x + side * 1.35, 0.42, z), Color(0.18, 0.31, 0.29), true)
		_create_box(root, "RestaurantServingCounter", Vector3(4.0, 1.0, 0.9), Vector3(0, 0.5, -5.1), Color(0.32, 0.19, 0.12), true)
	elif building_title == "مركز التوظيف":
		for index in range(3):
			var x := -4.0 + float(index) * 4.0
			_create_box(root, "EmploymentDesk_%d" % index, Vector3(2.6, 0.95, 1.1), Vector3(x, 0.48, -2.5), Color(0.31, 0.22, 0.14), true)
			_create_box(root, "EmploymentScreen_%d" % index, Vector3(1.0, 0.8, 0.12), Vector3(x, 1.35, -2.9), Color(0.12, 0.29, 0.31))
			_create_box(root, "EmploymentChair_%d" % index, Vector3(0.9, 0.85, 0.9), Vector3(x, 0.42, -0.7), Color(0.20, 0.29, 0.38), true)
		_create_box(root, "EmploymentNoticeBoard", Vector3(4.5, 2.0, 0.18), Vector3(0, 2.4, -6.65), Color(0.16, 0.27, 0.27))
	else:
		_create_box(root, "GenericWaitingBench", Vector3(3.2, 0.55, 0.8), Vector3(0, 0.28, 2.5), Color(0.34, 0.25, 0.16), true)


func _create_interior_staff(root: Node3D, building_title: String) -> void:
	# موظف محلي داخل كل مبنى؛ يستخدم نظام التفاعل الحالي دون إنشاء نظام مكافآت جديد.
	var staff := Node3D.new()
	staff.name = "InteriorServiceStaff"
	staff.set_script(load("res://scripts/service_npc.gd"))
	staff.set("character_name", "صاحب المتجر" if building_title == "المتجر" else "موظف المطعم" if building_title == "المطعم" else "موظف مركز التوظيف")
	staff.set("role_title", "صاحب محل" if building_title == "المتجر" else "موظف مطعم" if building_title == "المطعم" else "مسؤول التوظيف")
	staff.set("name_key", "interior_shop_staff" if building_title == "المتجر" else "interior_restaurant_staff" if building_title == "المطعم" else "interior_employment_staff")
	staff.set("role_key", "interior_shop_role" if building_title == "المتجر" else "interior_restaurant_role" if building_title == "المطعم" else "interior_employment_role")
	staff.set("interaction_key", "interior_shop_dialogue" if building_title == "المتجر" else "interior_restaurant_dialogue" if building_title == "المطعم" else "interior_employment_dialogue")
	staff.set("interaction_radius", 4.8)
	staff.position = Vector3(0, 0, -0.7)
	root.add_child(staff)

func return_from_building_interior() -> void:
	if interior_transition_busy or not is_instance_valid(interior_root):
		return
	interior_transition_busy = true
	var body := interior_player
	if is_instance_valid(body) and not body.is_queued_for_deletion():
		body.set_physics_process(false)
	_show_interior_loading(false, "interior_return_loading")
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	# استعد المدينة حتى لو تعذر استعادة اللاعب؛ لا تترك العالم مخفيًا أو الانتقال مقفولًا.
	_set_city_world_hidden(false)
	if is_instance_valid(body) and not body.is_queued_for_deletion():
		body.global_transform = interior_return_transform
		body.velocity = Vector3.ZERO
		body.set_physics_process(true)
	if is_instance_valid(interior_root):
		interior_root.queue_free()
	interior_root = null
	interior_player = null
	interior_transition_busy = false
	_hide_interior_loading()
	var manager := get_node_or_null("MissionManager")
	if is_instance_valid(manager) and manager.has_method("_update_interaction_target"):
		manager._update_interaction_target()
		manager._update_interaction_hud()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _create_box(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color, collision: bool = false) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.add_to_group("city_world_geometry")
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = name + "Collision"
		body.add_to_group("city_world_geometry")
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.position = pos
		body.add_child(shape_node)
		parent.add_child(body)

func _create_ground() -> void:
	# Split the terrain around a dedicated marina basin. The outer land strips retain
	# the original world bounds; only the protected ship-water footprint is removed.
	var ground_color := Color(0.34, 0.42, 0.31)
	_create_box(self, "Ground_West", Vector3(148, 1, 520), Vector3(-86, -0.55, -80), ground_color, true)
	_create_box(self, "Ground_East", Vector3(148, 1, 520), Vector3(86, -0.55, -80), ground_color, true)
	_create_box(self, "Ground_Center_North", Vector3(24, 1, 418), Vector3(0, -0.55, -131), ground_color, true)
	_create_box(self, "Ground_Center_South", Vector3(24, 1, 78), Vector3(0, -0.55, 141), ground_color, true)

func _create_city() -> void:
	# المباني المرئية تُنشأ من قائمة المدينة المعتمدة في ApprovedCityLayout.
	# شبكة الطرق تمر في الممرات الخالية وبين صفوف المباني، لا عبر بصماتها.

	var road_color := Color(0.12, 0.13, 0.15)
	var side_road_color := Color(0.15, 0.16, 0.17)
	# طريق محيطي مستطيل يحيط بالمدينة مع خلوّ مسافة عن مباني الأطراف.
	_create_box(self, "MainRoad_North", Vector3(190, 0.08, 6), Vector3(0, 0.0, -95), road_color)
	# Route the southern perimeter road around the outside of the marina basin.
	# Keep a clear buffer from the basin's side and south quay edges.
	_create_box(self, "MainRoad_South_West", Vector3(79, 0.08, 6), Vector3(-55.5, 0.0, 95), road_color)
	_create_box(self, "MainRoad_South_East", Vector3(79, 0.08, 6), Vector3(55.5, 0.0, 95), road_color)
	_create_box(self, "MainRoad_Southwest_Detour", Vector3(6, 0.08, 13), Vector3(-16, 0.0, 101.5), road_color)
	_create_box(self, "MainRoad_Southeast_Detour", Vector3(6, 0.08, 13), Vector3(16, 0.0, 101.5), road_color)
	_create_box(self, "MainRoad_South_Basin_Bypass", Vector3(32, 0.08, 6), Vector3(0, 0.0, 108), road_color)
	_create_box(self, "MainRoad_West", Vector3(6, 0.08, 190), Vector3(-95, 0.0, 0), road_color)
	_create_box(self, "MainRoad_East", Vector3(6, 0.08, 190), Vector3(95, 0.0, 0), road_color)
	# الشارع العرضي الشمالي يلتف حول الميدان الملكي ويترك ساحته مفتوحة للتجمع.
	for side in [-1.0, 1.0]:
		_create_box(self, "MainRoad_X_%s" % str(side), Vector3(72, 0.08, 6), Vector3(side * 59, 0.0, -45), road_color)
	# شوارع طولية في الممرات الآمنة بين صفوف المباني، وتتصل بالشوارع العرضية.
	for road_x in [-15.0, 15.0]:
		_create_box(self, "SideRoad_V_%d" % int(road_x), Vector3(5, 0.075, 118), Vector3(road_x, 0.006, 36), side_road_color)
	# شوارع عرضية قصيرة داخل الفواصل الآمنة بين صفوف المباني.
	for road_z in [-15.0, 15.0, 45.0]:
		_create_box(self, "SideRoad_Z_%d" % int(road_z), Vector3(132, 0.075, 5), Vector3(0, 0.006, road_z), side_road_color)
	# خطوط إرشادية على جزأي الطريق المحيط بالميدان.
	for side in [-1.0, 1.0]:
		for i in range(4):
			var mark_x := side * (28.0 + float(i) * 18.0)
			_create_box(self, "RoadMark_X_%s_%d" % [str(side), i], Vector3(3, 0.025, 0.16), Vector3(mark_x, 0.06, -45), Color(0.92, 0.86, 0.62))

func _create_mobile_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MobileHUD"
	add_child(layer)

	var hud_script = load("res://scripts/mobile_hud.gd")
	var touch_hud := Control.new()
	touch_hud.name = "TouchControls"
	touch_hud.set_script(hud_script)
	layer.add_child(touch_hud)
	touch_hud.set("player", get_node_or_null("Player"))

	# إنشاء واجهة المدينة مرة واحدة عند بدء اللعب، لا عند ركوب المركبة.
	if get_node_or_null("CityActionHUD") == null:
		var hud_layer := CanvasLayer.new()
		hud_layer.name = "CityActionHUD"
		hud_layer.set_script(load("res://scripts/city_hud.gd"))
		add_child(hud_layer)

func _set_mobile_hud_active(active: bool) -> void:
	var touch_hud := get_node_or_null("MobileHUD/TouchControls") as Control
	if not is_instance_valid(touch_hud):
		return
	if touch_hud.has_method("_clear_touch_state"):
		touch_hud.call("_clear_touch_state")
	touch_hud.visible = active


func _create_interactive_buildings() -> void:
	if AuthoritativeGameServer.is_dedicated_server_requested():
		_add_functional_building(null, "المتجر", "مهمة شراء احتياجات", "تعرّف على المتجر واستلم قائمة احتياجات تجريبية من البوابة.", Vector3(16, 0, 16), Color(0.20, 0.48, 0.30), 150, 0, 1)
		_add_functional_building(null, "المطعم", "مهمة توصيل وجبة", "استلم طلب توصيل تجريبي من المطعم.", Vector3(-16, 0, 16), Color(0.65, 0.30, 0.18), 220, 2, 1)
		_add_functional_building(null, "مركز التوظيف", "مهمة التسجيل في وظيفة", "تعرّف على الوظائف المتاحة وشروط الالتحاق بها.", Vector3(16, 0, -16), Color(0.22, 0.34, 0.62), 300, 5, 1)
		_create_job_board("وظيفة التوصيل", "توصيل طلب إلى نقطة الاستلام المحددة في المدينة.", Vector3(24, 0, 4.5), Vector3(0, 0, 9.5), 1200, 2, 0, "courier_delivery")
		_create_job_board("مرشد المدينة", "اذهب إلى نقطة المعلم السياحي وساعد الزائرين على اكتشاف المدينة.", Vector3(-24, 0, 4.5), Vector3(0, 0, -18.5), 1400, 3, 0, "city_guide")
		_create_job_board("عامل صيانة", "توجّه إلى موقع الصيانة المحدد وأكمل جولة الفحص الميدانية.", Vector3(4.5, 0, 24), Vector3(9.5, 0, 0), 1600, 3, 0, "city_maintenance", PI / 2.0)
		return
	var manager := Node.new()
	manager.name = "MissionManager"
	manager.set_script(load("res://scripts/mission_manager.gd"))
	add_child(manager)
	manager.set("player", get_node_or_null("Player"))
	var daily := Node.new()
	daily.name = "DailyActivities"
	daily.set_script(load("res://scripts/daily_activities.gd"))
	daily.player = get_node_or_null("Player")
	daily.mission_manager = manager
	manager.daily_activities = daily
	var achievements := Node.new()
	achievements.name = "AchievementManager"
	achievements.set_script(load("res://scripts/achievement_manager.gd"))
	achievements.set("player", get_node_or_null("Player"))
	achievements.mission_manager = manager
	manager.achievement_manager = achievements
	daily.achievement_manager = achievements
	add_child(achievements)
	add_child(daily)
	var profile_ui := Node.new()
	profile_ui.name = "ProfileSettings"
	profile_ui.set_script(load("res://scripts/profile_settings.gd"))
	profile_ui.set("mission_manager", manager)
	profile_ui.player = get_node_or_null("Player")
	add_child(profile_ui)

	_add_functional_building(manager, "المتجر", "مهمة شراء احتياجات", "تعرّف على المتجر واستلم قائمة احتياجات تجريبية من البوابة.", Vector3(16, 0, 16), Color(0.20, 0.48, 0.30), 150, 0, 1)
	_add_functional_building(manager, "المطعم", "مهمة توصيل وجبة", "استلم طلب توصيل تجريبي من المطعم. ستصبح أهداف التوصيل الفعلية جزءًا من مرحلة لاحقة.", Vector3(-16, 0, 16), Color(0.65, 0.30, 0.18), 220, 2, 1)
	_add_functional_building(manager, "مركز التوظيف", "مهمة التسجيل في وظيفة", "تعرّف على الوظائف المتاحة وشروط الالتحاق بها.", Vector3(16, 0, -16), Color(0.22, 0.34, 0.62), 300, 5, 1)
	_create_job_board("وظيفة التوصيل", "توصيل طلب إلى نقطة الاستلام المحددة في المدينة.", Vector3(24, 0, 4.5), Vector3(0, 0, 9.5), 1200, 2, 0, "courier_delivery")
	_create_job_board("مرشد المدينة", "اذهب إلى نقطة المعلم السياحي وساعد الزائرين على اكتشاف المدينة.", Vector3(-24, 0, 4.5), Vector3(0, 0, -18.5), 1400, 3, 0, "city_guide")
	_create_job_board("عامل صيانة", "توجّه إلى موقع الصيانة المحدد وأكمل جولة الفحص الميدانية.", Vector3(4.5, 0, 24), Vector3(9.5, 0, 0), 1600, 3, 0, "city_maintenance", PI / 2.0)
	_create_service_staff("صاحب المتجر", "صاحب محل", "أهلًا بك! يمكنني مساعدتك في احتياجاتك ومشترياتك من المتجر.", Vector3(19.5, 0, 20.2))
	_create_service_staff("موظف المطعم", "موظف", "مرحبًا! أستقبل طلبات المطعم وأساعدك في أنشطة التوصيل.", Vector3(-12.5, 0, 20.2))
	_create_service_staff("موظف مركز التوظيف", "موظف", "أهلًا بك! يمكنك مراجعة الوظائف المتاحة وشروطها هنا.", Vector3(19.5, 0, -11))

func _add_functional_building(manager: Node, title: String, mission: String, description: String, pos: Vector3, color: Color, reward: int, chips_reward: int, level: int) -> void:
	var building := Node3D.new()
	building.name = "Functional_" + title
	building.set_script(load("res://scripts/building_interaction.gd"))
	building.building_id = "mission_" + str(title.hash())
	building.server_activity_id = "mission_shop" if title == "المتجر" else ("mission_restaurant" if title == "المطعم" else "mission_employment")
	building.position = pos
	building.building_title = title
	building.mission_title = mission
	building.mission_description = description
	building.reward_money = reward
	building.reward_chips = chips_reward
	building.reward_xp = max(20, int(reward / 5))
	building.required_level = level
	building.requires_interior = false
	add_child(building)
	_create_box(building, "BuildingBody", Vector3(8, 5, 7), Vector3(0, 2.5, 0), color, true)
	_create_box(building, "Entrance", Vector3(1.5, 2.4, 0.12), Vector3(0, 1.2, 3.56), Color(0.12, 0.14, 0.18), false)
	_create_box(building, "Sign", Vector3(5.0, 0.8, 0.16), Vector3(0, 4.25, 3.58), Color(0.10, 0.22, 0.25), false)
	var sign_key := "shop"
	if title == "المطعم":
		sign_key = "restaurant"
	elif title == "مركز التوظيف":
		sign_key = "employment"
	_add_sign_label(building, sign_key, Vector3(0, 4.25, 3.70), PI)
	if is_instance_valid(manager) and manager.has_method("register_building"):
		manager.register_building(building)


func _create_job_board(title: String, description: String, pos: Vector3, target_offset: Vector3, reward: int, chips_reward: int, xp_reward: int, job_id: String, yaw: float = 0.0) -> void:
	var board := Node3D.new()
	board.name = "JobBoard_" + job_id
	board.set_script(load("res://scripts/job_interaction.gd"))
	board.position = pos
	board.rotation.y = yaw
	board.job_id = job_id
	board.job_title = title
	board.job_description = description
	board.reward_money = reward
	board.reward_chips = chips_reward
	board.reward_xp = xp_reward
	board.target_offset = target_offset
	add_child(board)
	_create_box(board, "JobBoardBase", Vector3(2.4, 1.5, 0.45), Vector3(0, 0.75, 0), Color(0.16, 0.22, 0.28), false)
	_create_box(board, "JobBoardSign", Vector3(2.8, 1.1, 0.16), Vector3(0, 2.05, 0), Color(0.10, 0.22, 0.25), false)
	var board_key := "city_guide"
	if job_id == "courier_delivery":
		board_key = "delivery"
	elif job_id == "city_maintenance":
		board_key = "maintenance"
	_add_sign_label(board, board_key, Vector3(0, 2.05, -0.12))



func _create_city_signage() -> void:
	# Signposts reuse primitive meshes and point to known prototype destinations.
	_create_direction_signpost("Signpost_Central", Vector3(9, 0, 8), "restaurant", "shop", PI / 2.0)
	# Move roadside signs off the road centerline and turn their faces toward the road.
	_create_direction_signpost("Signpost_Employment", Vector3(29, 0, -8), "employment", "city_center", PI / 2.0)
	_create_direction_signpost("Signpost_Camp", Vector3(34, 0, 38), "city_center", "animal_camp", PI / 2.0)

func _create_direction_signpost(sign_name: String, pos: Vector3, left_key: String, right_key: String, yaw: float = 0.0) -> void:
	var sign_root := Node3D.new()
	sign_root.name = sign_name
	sign_root.position = pos
	sign_root.rotation.y = yaw
	add_child(sign_root)
	_create_box(sign_root, "StonePost", Vector3(0.35, 2.7, 0.35), Vector3(0, 1.35, 0), Color(0.66, 0.52, 0.32), false)
	_create_box(sign_root, "DarkBoard", Vector3(6.2, 1.15, 0.22), Vector3(0, 2.65, 0), Color(0.08, 0.22, 0.23), false)
	_create_box(sign_root, "GoldTopTrim", Vector3(6.3, 0.09, 0.27), Vector3(0, 3.25, 0), Color(0.88, 0.68, 0.30), false)
	_add_sign_label(sign_root, left_key, Vector3(-1.45, 2.65, -0.13), 0.0, "← ")
	_add_sign_label(sign_root, right_key, Vector3(1.45, 2.65, -0.13), 0.0, "→ ")

func _add_sign_label(parent: Node3D, key: String, pos: Vector3, y_rotation: float = 0.0, prefix: String = "") -> void:
	var label := Label3D.new()
	label.name = "SignText_" + key
	label.add_to_group("city_world_geometry")
	label.set_script(load("res://scripts/city_sign_label.gd"))
	label.set("translation_key", key)
	label.set("prefix", prefix)
	label.position = pos
	label.rotation.y = y_rotation
	label.font_size = 48
	label.pixel_size = 0.006
	label.outline_size = 10
	label.modulate = Color(1.0, 0.91, 0.68)
	# Keep text aligned with its physical sign face and directional arrows.
	# Billboard mode made labels rotate independently of the board.
	parent.add_child(label)


func _create_navigation_destinations() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NavigationDestinationsHUD"
	add_child(layer)
	var map_control := Control.new()
	map_control.name = "NavigationDestinations"
	map_control.set_script(load("res://scripts/city_map.gd"))
	map_control.player = get_node_or_null("Player")
	map_control.mission_manager = get_node_or_null("MissionManager")
	layer.add_child(map_control)


func _create_service_staff(display_name: String, role: String, dialogue: String, pos: Vector3) -> void:
	var staff := Node3D.new()
	staff.name = "Staff_" + str(display_name.hash())
	staff.set_script(load("res://scripts/service_npc.gd"))
	staff.set("character_name", display_name)
	staff.set("role_title", role)
	staff.interaction_text = dialogue
	staff.position = pos
	add_child(staff)

func _create_camp() -> void:
	# مسار المخيم يلتف حول أطراف المدينة بدل المرور عبر قصور الشقق والمدينة المائية.
	var camp_road_color := Color(0.12, 0.13, 0.15)
	_create_box(self, "CampRoad_Entry", Vector3(5, 0.07, 45), Vector3(16, 0.025, -22.5), camp_road_color)
	_create_box(self, "CampRoad_North", Vector3(35, 0.07, 5), Vector3(77.5, 0.025, 90), camp_road_color)
	_create_box(self, "CampRoad_Camp", Vector3(5, 0.07, 15), Vector3(60, 0.025, 82.5), camp_road_color)
	var camp := Node3D.new()
	camp.name = "AnimalCamp"
	camp.position = Vector3(60, 0, 75)
	camp.set_script(load("res://scripts/camp_system.gd"))
	add_child(camp)


func _create_royal_resort() -> void:
	# المنتجع الملكي في القطاع الشرقي، منفصل عن مخيم الحيوانات والمناطق الصحراوية.
	_create_box(self, "RoyalResortAccessRoad", Vector3(30, 0.08, 5), Vector3(110, 0.01, 50), Color(0.12, 0.13, 0.15), true)
	_create_box(self, "RoyalResortApproachRoad", Vector3(5, 0.08, 15), Vector3(120, 0.01, 42.5), Color(0.12, 0.13, 0.15), true)
	var resort := Node3D.new()
	resort.name = "RoyalResort"
	resort.position = Vector3(120, 0, 50)
	resort.set_script(load("res://scripts/royal_resort.gd"))
	add_child(resort)

func _create_desert_camp() -> void:
	# مخيم صحراوي ملكي مستقل غرب المدينة؛ لا يستبدل مخيم الحيوانات الحالي.
	_create_box(self, "DesertCampAccessRoad", Vector3(35, 0.08, 5), Vector3(-112.5, 0.01, 70), Color(0.12, 0.13, 0.15), true)
	_create_box(self, "DesertCampApproachRoad", Vector3(5, 0.08, 15), Vector3(-130, 0.01, 62.5), Color(0.12, 0.13, 0.15), true)
	var camp := Node3D.new()
	camp.name = "RoyalDesertCamp"
	camp.position = Vector3(-130, 0, 70)
	camp.set_script(load("res://scripts/desert_camp.gd"))
	add_child(camp)

func _create_pyramids_area() -> void:
	# منطقة الأهرامات وأبو الهول متصلة بطريق المخيم الصحراوي.
	_create_box(self, "PyramidsAccessRoad_West", Vector3(40, 0.08, 5), Vector3(-110, 0.01, 70), Color(0.12, 0.13, 0.15), true)
	_create_box(self, "PyramidsAccessRoad_North", Vector3(5, 0.08, 40), Vector3(-90, 0.01, 90), Color(0.12, 0.13, 0.15), true)
	var pyramids := Node3D.new()
	pyramids.name = "GizaPyramidsArea"
	pyramids.position = Vector3(-130, 0, 70)
	pyramids.set_script(load("res://scripts/pyramids_area.gd"))
	add_child(pyramids)


# اختيار وضع اللعب وبوابة PIN محلية لحساب المؤسس الموثق.
var mode_selection_layer: CanvasLayer
var mode_selection_panel: PanelContainer
var mode_status_label: Label
var online_address_input: LineEdit
var founder_pin_input: LineEdit
var founder_pin_confirm_input: LineEdit
var founder_pin_button: Button
var founder_pin_gate: VBoxContainer
var game_mode_controls: VBoxContainer
var founder_email_gate: VBoxContainer
var founder_email_input: LineEdit
var founder_email_code_input: LineEdit
var founder_email_verified := false
var player_account_window: Window
var player_account_email_input: LineEdit
var player_account_code_input: LineEdit
var player_account_status_label: Label
var player_account_button: Button
var player_account_profile_label: Label


func _create_mode_selection_ui() -> void:
	var player := get_node_or_null("Player")
	if is_instance_valid(player):
		player.set_physics_process(false)
		player.set_process(false)

	mode_selection_layer = CanvasLayer.new()
	mode_selection_layer.name = "GameModeSelection"
	mode_selection_layer.layer = 100
	add_child(mode_selection_layer)
	# Connect auth lifecycle even when the founder identity is already cached locally.
	FounderAuthClient.request_finished.connect(_on_founder_auth_request_finished)
	FounderAuthClient.email_verified.connect(_on_founder_email_verified)
	FounderAuthClient.auth_session_received.connect(_on_founder_auth_session_received)
	FounderAuthClient.auth_session_refreshed.connect(_on_founder_auth_session_refreshed)
	FounderAuthClient.auth_session_restored.connect(_on_founder_auth_session_restored)
	FounderAuthClient.auth_session_expired.connect(_on_founder_auth_session_expired)
	FounderAuthClient.founder_entitlement_received.connect(_on_founder_entitlement_received)
	FounderAuthClient.founder_entitlement_failed.connect(_on_founder_entitlement_failed)
	PlayerAccountAuthClient.request_finished.connect(_on_player_account_request_finished)
	PlayerAccountAuthClient.account_authenticated.connect(_on_player_account_authenticated)
	PlayerAccountAuthClient.session_access_token_changed.connect(_on_player_account_access_token_changed)
	PlayerAccountAuthClient.session_expired.connect(_on_player_account_session_expired)
	PlayerAccountAuthClient.player_profile_ready.connect(_on_player_profile_ready)
	PlayerAccountAuthClient.player_profile_failed.connect(_on_player_profile_failed)
	if PlayerAccountAuthClient.has_active_session():
		PlayerSyncClient.set_session_access_token(PlayerAccountAuthClient.get_access_token())
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.035, 0.05, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_selection_layer.add_child(backdrop)

	mode_selection_panel = PanelContainer.new()
	mode_selection_panel.custom_minimum_size = Vector2(360, 590)
	mode_selection_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mode_selection_panel.position = Vector2(-180, -295)
	mode_selection_panel.add_theme_stylebox_override("panel", _make_mode_panel_style())
	backdrop.add_child(mode_selection_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	mode_selection_panel.add_child(content)

	var heading := Label.new()
	heading.text = "KING OF EGYPT CITY"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(0.94, 0.79, 0.43))
	content.add_child(heading)

	player_account_button = Button.new()
	player_account_button.text = "حساب اللاعب - تسجيل الدخول وحفظ التقدم"
	player_account_button.custom_minimum_size.y = 40
	player_account_button.pressed.connect(_open_player_account_window)
	content.add_child(player_account_button)
	_create_player_account_window()

	founder_pin_gate = VBoxContainer.new()
	founder_pin_gate.add_theme_constant_override("separation", 8)
	content.add_child(founder_pin_gate)
	var founder_heading := Label.new()
	founder_heading.text = "حماية حساب المؤسس"
	founder_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founder_pin_gate.add_child(founder_heading)
	founder_pin_input = LineEdit.new()
	founder_pin_input.placeholder_text = "رمز PIN من 6 أرقام"
	founder_pin_input.secret = true
	founder_pin_input.max_length = 6
	founder_pin_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	founder_pin_gate.add_child(founder_pin_input)
	founder_pin_confirm_input = LineEdit.new()
	founder_pin_confirm_input.placeholder_text = "تأكيد رمز PIN"
	founder_pin_confirm_input.secret = true
	founder_pin_confirm_input.max_length = 6
	founder_pin_confirm_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	founder_pin_gate.add_child(founder_pin_confirm_input)
	founder_pin_button = Button.new()
	founder_pin_button.custom_minimum_size.y = 44
	founder_pin_button.pressed.connect(_on_founder_pin_submit)
	founder_pin_gate.add_child(founder_pin_button)
	var is_verified_founder := FounderIdentityManager.is_founder
	founder_pin_gate.visible = is_verified_founder
	if is_verified_founder:
		if FounderPinManager.is_pin_configured():
			founder_pin_confirm_input.visible = false
			founder_pin_button.text = "فتح حساب المؤسس"
			mode_status_label = Label.new()
			mode_status_label.text = "أدخل رمزك المحلي لفتح الحساب."
		else:
			founder_pin_button.text = "حفظ رمز المؤسس"
			mode_status_label = Label.new()
			mode_status_label.text = "أنشئ رمزًا خاصًا من 6 أرقام لهذا الجهاز."
	else:
		mode_status_label = Label.new()
		mode_status_label.text = "اختر طريقة اللعب."
	mode_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(mode_status_label)

	if not is_verified_founder:
		founder_email_gate = VBoxContainer.new()
		founder_email_gate.add_theme_constant_override("separation", 7)
		content.add_child(founder_email_gate)
		var email_heading := Label.new()
		email_heading.text = "التحقق من بريد حساب المؤسس"
		email_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		founder_email_gate.add_child(email_heading)
		founder_email_input = LineEdit.new()
		founder_email_input.placeholder_text = "البريد الإلكتروني"
		founder_email_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		founder_email_gate.add_child(founder_email_input)
		var send_code_button := Button.new()
		send_code_button.text = "إرسال رمز التحقق"
		send_code_button.custom_minimum_size.y = 40
		send_code_button.pressed.connect(_on_founder_send_code)
		founder_email_gate.add_child(send_code_button)
		founder_email_code_input = LineEdit.new()
		founder_email_code_input.placeholder_text = "رمز البريد المكوّن من 6 أرقام"
		founder_email_code_input.max_length = 6
		founder_email_code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		founder_email_gate.add_child(founder_email_code_input)
		var verify_code_button := Button.new()
		verify_code_button.text = "تأكيد البريد"
		verify_code_button.custom_minimum_size.y = 40
		verify_code_button.pressed.connect(_on_founder_verify_code)
		founder_email_gate.add_child(verify_code_button)

	game_mode_controls = VBoxContainer.new()
	game_mode_controls.add_theme_constant_override("separation", 8)
	content.add_child(game_mode_controls)
	var offline_button := Button.new()
	offline_button.text = "اللعب دون إنترنت"
	offline_button.custom_minimum_size.y = 44
	offline_button.pressed.connect(_select_offline_mode)
	game_mode_controls.add_child(offline_button)
	online_address_input = LineEdit.new()
	online_address_input.placeholder_text = "اسم نطاق خادم WSS الآمن"
	online_address_input.text = str(ProjectSettings.get_setting("network/online/server_address", ""))
	game_mode_controls.add_child(online_address_input)
	var online_button := Button.new()
	online_button.text = "اللعب عبر الإنترنت"
	online_button.custom_minimum_size.y = 44
	online_button.pressed.connect(_select_online_mode)
	game_mode_controls.add_child(online_button)
	game_mode_controls.visible = not is_verified_founder

 
func _create_player_account_window() -> void:
	player_account_window = Window.new()
	player_account_window.title = "حساب اللاعب"
	player_account_window.size = Vector2i(380, 360)
	player_account_window.min_size = Vector2i(340, 320)
	player_account_window.unresizable = false
	player_account_window.exclusive = true
	add_child(player_account_window)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_account_window.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)

	var heading := Label.new()
	heading.text = "حساب اللاعب"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)

	player_account_status_label = Label.new()
	player_account_status_label.text = "سجّل ببريدك لحفظ هوية اللاعب والتقدم بين الأجهزة."
	player_account_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_account_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(player_account_status_label)

	player_account_email_input = LineEdit.new()
	player_account_email_input.placeholder_text = "البريد الإلكتروني"
	player_account_email_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	content.add_child(player_account_email_input)

	var send_button := Button.new()
	send_button.text = "إنشاء حساب / إرسال رمز الدخول"
	send_button.custom_minimum_size.y = 42
	send_button.pressed.connect(_on_player_account_send_code)
	content.add_child(send_button)

	player_account_code_input = LineEdit.new()
	player_account_code_input.placeholder_text = "رمز التحقق المكوّن من 6 أرقام"
	player_account_code_input.max_length = 6
	player_account_code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	content.add_child(player_account_code_input)

	var verify_button := Button.new()
	verify_button.text = "تأكيد الرمز وتسجيل الدخول"
	verify_button.custom_minimum_size.y = 42
	verify_button.pressed.connect(_on_player_account_verify_code)
	content.add_child(verify_button)

	player_account_profile_label = Label.new()
	player_account_profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_account_profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(player_account_profile_label)

	if PlayerAccountAuthClient.has_active_session():
		player_account_email_input.text = PlayerAccountAuthClient.get_email()
		player_account_status_label.text = "الحساب متصل. رمز اللاعب مرتبط بهوية الحساب الثابتة."
		player_account_button.text = "حساب اللاعب - متصل"
		if not PlayerAccountAuthClient.get_user_id().is_empty():
			player_account_profile_label.text = "معرّف الحساب: " + PlayerAccountAuthClient.get_user_id()

func _open_player_account_window() -> void:
	if not is_instance_valid(player_account_window):
		return
	if PlayerAccountAuthClient.has_active_session():
		player_account_email_input.text = PlayerAccountAuthClient.get_email()
		player_account_status_label.text = "الحساب متصل. يمكنك استخدامه على أجهزتك الأخرى."
	player_account_window.popup_centered()

func _on_player_account_send_code() -> void:
	if not is_instance_valid(player_account_email_input):
		return
	player_account_status_label.text = "جارٍ إرسال رمز الدخول..."
	if not PlayerAccountAuthClient.request_email_code(player_account_email_input.text):
		player_account_status_label.text = "تعذر بدء طلب الرمز. راجع البريد والإعدادات."

func _on_player_account_verify_code() -> void:
	if not is_instance_valid(player_account_email_input) or not is_instance_valid(player_account_code_input):
		return
	player_account_status_label.text = "جارٍ التحقق من الرمز..."
	if not PlayerAccountAuthClient.verify_email_code(player_account_email_input.text, player_account_code_input.text):
		player_account_status_label.text = "تعذر بدء التحقق. راجع البريد والرمز."

func _on_player_account_request_finished(success: bool, message: String) -> void:
	if is_instance_valid(player_account_status_label):
		player_account_status_label.text = message

func _on_player_account_authenticated(user_id: String, email: String) -> void:
	if is_instance_valid(player_account_button):
		player_account_button.text = "حساب اللاعب - متصل"
	if is_instance_valid(player_account_status_label):
		player_account_status_label.text = "تم ربط الحساب %s بهوية لاعب ثابتة." % email
	if is_instance_valid(player_account_profile_label):
		player_account_profile_label.text = "معرّف الحساب: " + user_id

func _on_player_account_access_token_changed(access_token: String) -> void:
	PlayerSyncClient.set_session_access_token(access_token)

func _on_player_account_session_expired() -> void:
	PlayerSyncClient.clear_session_access_token()
	if is_instance_valid(player_account_button):
		player_account_button.text = "حساب اللاعب - تسجيل الدخول وحفظ التقدم"
	if is_instance_valid(player_account_status_label):
		player_account_status_label.text = "انتهت جلسة الحساب. سجّل الدخول مجددًا لاستعادة المزامنة."

func _on_player_profile_ready(_user_id: String, player_code: String, display_name: String) -> void:
	if is_instance_valid(player_account_profile_label):
		player_account_profile_label.text = "اسم اللاعب: %s\nرمز اللاعب: %s" % [display_name, player_code]

func _on_player_profile_failed(message: String) -> void:
	if is_instance_valid(player_account_profile_label):
		player_account_profile_label.text = message

func _on_founder_send_code() -> void:
	if not is_instance_valid(founder_email_input):
		return
	mode_status_label.text = "جارٍ طلب رمز التحقق..."
	if not FounderAuthClient.request_email_code(founder_email_input.text):
		mode_status_label.text = "تعذر بدء طلب الرمز. راجع البريد والإعدادات."

func _on_founder_verify_code() -> void:
	if not is_instance_valid(founder_email_input) or not is_instance_valid(founder_email_code_input):
		return
	mode_status_label.text = "جارٍ التحقق من الرمز..."
	if not FounderAuthClient.verify_email_code(founder_email_input.text, founder_email_code_input.text):
		mode_status_label.text = "تعذر بدء التحقق. راجع البريد والرمز."

func _on_founder_auth_request_finished(success: bool, message: String) -> void:
	if is_instance_valid(mode_status_label):
		mode_status_label.text = message

func _on_founder_email_verified(_user_id: String, verified_email: String) -> void:
	founder_email_verified = true
	if is_instance_valid(mode_status_label):
		mode_status_label.text = "تم تأكيد ملكية البريد %s. تفعيل حساب المؤسس ينتظر اعتماد التذكرة الخادمية." % verified_email

func _on_founder_auth_session_expired() -> void:
	# انتهاء جلسة المؤسس لا يمس جلسة حساب اللاعب المستقلة أو رمز مزامنته.
	if FounderIdentityManager.is_founder and is_instance_valid(mode_status_label):
		mode_status_label.text = "انتهت جلسة الاتصال الآمنة. أعد التحقق من بريد المؤسس للعمليات Online؛ تذكرة Offline الصالحة لا تتأثر."


func _on_founder_auth_session_received(access_token: String, _refresh_token: String) -> void:
	# Founder session remains isolated; player sync uses PlayerAccountAuthClient only.
	pass


func _on_founder_auth_session_refreshed(_access_token: String) -> void:
	pass


func _on_founder_auth_session_restored(_access_token: String) -> void:
	# Revalidate the founder entitlement after a persisted Auth session is recovered.
	FounderAuthClient.request_founder_entitlement_for_active_session()

func _on_founder_entitlement_received(payload: String, signature_base64: String) -> void:
	if not FounderIdentityManager.accept_signed_entitlement(payload, signature_base64):
		_on_founder_entitlement_failed("رفض الجهاز التذكرة الموقعة أو تعذر حفظها بأمان.")
		return
	if is_instance_valid(founder_email_gate):
		founder_email_gate.visible = false
	if is_instance_valid(founder_pin_gate):
		founder_pin_gate.visible = true
	if is_instance_valid(game_mode_controls):
		game_mode_controls.visible = false
	if FounderPinManager.is_pin_configured():
		founder_pin_confirm_input.visible = false
		founder_pin_button.text = "فتح حساب المؤسس"
	else:
		founder_pin_confirm_input.visible = true
		founder_pin_button.text = "حفظ رمز المؤسس"
	if is_instance_valid(mode_status_label):
		mode_status_label.text = "تم اعتماد هوية المؤسس وحفظ التذكرة لهذا الجهاز. أنشئ رمز PIN المحلي للمتابعة."

func _on_founder_entitlement_failed(message: String) -> void:
	if is_instance_valid(mode_status_label):
		mode_status_label.text = message + " لم تُمنح صلاحيات المؤسس."

func _on_founder_pin_submit() -> void:
	if not FounderIdentityManager.is_founder:
		mode_status_label.text = "لا توجد تذكرة مؤسس موثقة على هذا الجهاز."
		return
	var pin := founder_pin_input.text.strip_edges()
	if FounderPinManager.is_pin_configured():
		if FounderPinManager.is_locked():
			mode_status_label.text = "محاولات كثيرة. انتظر %d ثانية." % FounderPinManager.lock_seconds_remaining()
			return
		if not FounderPinManager.verify_pin(pin):
			mode_status_label.text = "الرمز غير صحيح أو غير صالح. المحاولات محدودة."
			return
	else:
		if not FounderPinManager.setup_pin(pin, founder_pin_confirm_input.text.strip_edges()):
			mode_status_label.text = "تعذر حفظ الرمز. أدخل 6 أرقام متطابقة."
			return
	founder_pin_gate.visible = false
	game_mode_controls.visible = true
	mode_status_label.text = "تم فتح حساب المؤسس على هذا الجهاز. اختر طريقة اللعب."
	founder_pin_input.clear()
	founder_pin_confirm_input.clear()

func _make_mode_panel_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.085, 0.11, 0.98)
	style.border_color = Color(0.72, 0.55, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	return style

func _select_offline_mode() -> void:
	GameModeManager.select_offline()
	_enter_selected_game_mode()

func _select_online_mode() -> void:
	var address := online_address_input.text.strip_edges()
	if address.is_empty():
		mode_status_label.text = "أدخل اسم نطاق خادم WSS الآمن بعد تجهيز شهادة TLS."
		return
	mode_status_label.text = "جارٍ إنشاء اتصال آمن والتحقق من حساب اللاعب..."
	GameModeManager.connect_online(address, 2456)

func _enter_selected_game_mode() -> void:
	if is_instance_valid(mode_selection_layer):
		mode_selection_layer.visible = false
	var player := get_node_or_null("Player")
	if is_instance_valid(player):
		player.set_process(true)
		player.set_physics_process(true)

func _on_mode_status_changed(message: String) -> void:
	if is_instance_valid(mode_status_label):
		mode_status_label.text = message

func _on_mode_connected() -> void:
	var access_token := PlayerAccountAuthClient.get_access_token()
	if access_token.is_empty():
		_on_mode_status_changed("سجّل الدخول إلى حساب اللاعب قبل دخول Online.")
		GameModeManager.disconnect_online()
		return
	AuthoritativeGameServer.authenticate_player.rpc_id(1, access_token)


func _on_player_account_session_expired() -> void:
	if GameModeManager.is_online_ready():
		_on_mode_status_changed("انتهت جلسة حساب اللاعب؛ تم إنهاء اتصال Online لحماية الحساب.")
		GameModeManager.disconnect_online()


func _on_player_access_token_changed(access_token: String) -> void:
	if GameModeManager.is_online_ready() and not access_token.is_empty():
		AuthoritativeGameServer.authenticate_player.rpc_id(1, access_token)


func _on_player_server_authenticated(success: bool, message: String) -> void:
	_on_mode_status_changed(message)
	if success:
		_enter_selected_game_mode()
	else:
		GameModeManager.disconnect_online()

func _on_mode_disconnected() -> void:
	# أعد نافذة اختيار الوضع بعد فقد الخادم، ولا تحوّل الجلسة تلقائيًا إلى Offline.
	var player := get_node_or_null("Player")
	if is_instance_valid(player):
		player.set_process(false)
		player.set_physics_process(false)
	if is_instance_valid(mode_selection_layer):
		mode_selection_layer.visible = true


func _create_founder_update_panel() -> void:
	# لوحة المؤسس مستقلة عن واجهة اللاعب العادية، ولا تظهر إلا بعد التحقق من تذكرة المؤسس.
	var panel_script := load("res://scripts/founder_update_panel.gd") as Script
	if panel_script == null:
		push_warning("تعذر تحميل لوحة إدارة تحديثات المؤسس.")
		return
	var panel := CanvasLayer.new()
	panel.name = "FounderUpdateManagement"
	panel.set_script(panel_script)
	add_child(panel)
