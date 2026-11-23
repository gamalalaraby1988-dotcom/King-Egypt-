extends Node3D

const ProfileConfigStore = preload("res://scripts/profile_config_store.gd")
const RemotePlayerVisual = preload("res://scripts/remote_player_visual.gd")

@export var city_half_size: int = 3
@export var block_spacing: float = 24.0

var interior_root: Node3D = null
var interior_player: CharacterBody3D = null
var interior_return_transform: Transform3D
var interior_loading_layer: CanvasLayer
var interior_loading_label: Label
var interior_loading_progress: ProgressBar
var interior_loading_tween: Tween
var interior_exit_button: Button
var palace_navigation_layer: CanvasLayer
var palace_navigation_button: Button
var palace_navigation_popup: PopupMenu
var interior_transition_busy := false
var interior_loading_message_key := "interior_loading"
var interior_hidden_world_states: Dictionary = {}
var city_vehicle: CharacterBody3D = null
var vehicle_interaction_button: Button = null
var vehicle_summon_button: Button = null
var scooter_toggle_button: Button = null
var city_scooter: CharacterBody3D = null
var scooter_occupied := false
var city_jet_ski: CharacterBody3D = null
var jet_ski_occupied := false
var _jet_ski_unmount_pending := false
var _jet_ski_saved_collision_layer := 1
var _jet_ski_saved_collision_mask := 1
const JET_SKI_LAUNCH_POSITION := Vector3(0.0, 0.34, 82.0)
const JET_SKI_BOARDING_RADIUS := 8.0
var _scooter_saved_collision_layer := 1
var _scooter_saved_collision_mask := 1
var vehicle_occupied := false
var _vehicle_key_was_down := false
var _player_saved_collision_layer := 1
var _player_saved_collision_mask := 1
var _last_safe_player_position := Vector3(0.0, 1.0, -42.0)
var _initial_player_spawn_position := Vector3(0.0, 1.0, -42.0)
var _initial_player_spawn_captured := false
var _remote_player_views: Dictionary = {}
var _city_matchmaking_request: HTTPRequest
var _pending_city_reservation_id := ""
const PLAYER_RECOVERY_FALL_LIMIT := -3.0
const CITY_SAFE_X_LIMIT := 155.0
const CITY_SAFE_Z_MIN := -340.0
const CITY_SAFE_Z_MAX := 180.0
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
		_create_desert_camp()
		_create_pyramids_area()
		return
	_create_ground()
	_create_city()
	_create_approved_city_layout()
	_create_city_signage()
	_create_mobile_hud()
	var initial_player := get_node_or_null("Player") as CharacterBody3D
	if is_instance_valid(initial_player):
		_last_safe_player_position = initial_player.global_position
		_initial_player_spawn_position = initial_player.global_position
		_initial_player_spawn_captured = true
	var key_light := get_node_or_null("DirectionalLight3D")
	if key_light:
		key_light.add_to_group("quality_shadow_light")
	_create_interactive_buildings()
	_create_desert_camp()
	_create_pyramids_area()
	_create_city_npc_population()
	_create_navigation_destinations()
	_create_interior_transition_ui()
	_create_palace_navigation_ui()
	_create_player_vehicle()
	_create_mode_selection_ui()
	_create_founder_update_panel()
	GameModeManager.status_changed.connect(_on_mode_status_changed)
	GameModeManager.online_connected.connect(_on_mode_connected)
	AuthoritativeGameServer.authentication_completed.connect(_on_player_server_authenticated)
	AuthoritativeGameServer.remote_players_received.connect(_on_remote_players_received)
	AuthoritativeGameServer.jet_ski_mount_result_received.connect(_on_jet_ski_mount_result_received)
	AuthoritativeGameServer.jet_ski_unmount_result_received.connect(_on_jet_ski_unmount_result_received)
	AuthoritativeGameServer.jet_ski_authoritative_state_received.connect(_on_jet_ski_authoritative_state_received)
	GameModeManager.online_disconnected.connect(_on_mode_disconnected)


func _create_city_npc_population() -> void:
	# NPC citizens are client-side ambience; dedicated servers do not simulate them.
	var population_script := load("res://scripts/city_npc_population.gd") as Script
	if population_script == null:
		push_warning("تعذر تحميل نظام الشخصيات الافتراضية للمدينة.")
		return
	var population := Node3D.new()
	population.name = "CityNPCPopulation"
	population.set_script(population_script)
	add_child(population)


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
		var online_player := get_node_or_null("Player") as CharacterBody3D
		var near_jet_ski_gate := is_instance_valid(online_player) and online_player.global_position.distance_to(JET_SKI_LAUNCH_POSITION) <= JET_SKI_BOARDING_RADIUS
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = jet_ski_occupied or (near_jet_ski_gate and not vehicle_occupied and not scooter_occupied)
			vehicle_interaction_button.text = "🚪↗" if jet_ski_occupied else "🏄"
			vehicle_interaction_button.tooltip_text = "النزول من الجت سكي" if jet_ski_occupied and CityLanguage.get_language() == "ar" else ("Exit jet ski" if jet_ski_occupied else ("ركوب الجت سكي الملكية" if CityLanguage.get_language() == "ar" else "Ride royal jet ski"))
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		return
	_guard_player_safety()
	# المركبات تخص مساحة المدينة؛ أخفِ أدواتها طوال الانتقال أو الوجود داخل مبنى.
	if interior_transition_busy or is_instance_valid(interior_root):
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		return
	if vehicle_occupied and (not is_instance_valid(city_vehicle) or not is_instance_valid(get_node_or_null("Player"))):
		_recover_vehicle_occupancy()
	if scooter_occupied and (not is_instance_valid(city_scooter) or not is_instance_valid(city_scooter.get_node_or_null("Player"))):
		_recover_scooter_occupancy()
	if jet_ski_occupied and (not is_instance_valid(city_jet_ski) or not is_instance_valid(city_jet_ski.get_node_or_null("Player"))):
		_recover_jet_ski_occupancy()
	var player := get_node_or_null("Player") as CharacterBody3D
	var player_needs_exit: bool = is_instance_valid(player) and (player.get("sitting") == true or player.get("animal_riding") == true)
	if vehicle_occupied or scooter_occupied or jet_ski_occupied or player_needs_exit:
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = true
			vehicle_interaction_button.text = "🚪↗"
			vehicle_interaction_button.tooltip_text = ("النزول من الجت سكي" if CityLanguage.get_language() == "ar" else "Exit jet ski") if jet_ski_occupied else (("الخروج" if CityLanguage.get_language() == "ar" else "Exit"))
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		if is_instance_valid(scooter_toggle_button):
			scooter_toggle_button.visible = scooter_occupied
			if scooter_occupied:
				scooter_toggle_button.text = "👣"
				scooter_toggle_button.tooltip_text = "العودة للمشي"
		return
	# زر الباب مخصص للخروج فقط؛ ركوب المركبات يتم من زر التفاعل الموحد داخل MissionManager.
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = false
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = true
		vehicle_summon_button.text = "إحضار السيارة" if CityLanguage.get_language() == "ar" else "Call vehicle"
	if is_instance_valid(scooter_toggle_button):
		scooter_toggle_button.visible = true
		scooter_toggle_button.text = "👣" if is_instance_valid(city_scooter) else "🛴"
		scooter_toggle_button.tooltip_text = ("العودة للمشي" if CityLanguage.get_language() == "ar" else "Walk") if is_instance_valid(city_scooter) else ("استدعاء السكوتر الكهربائي" if CityLanguage.get_language() == "ar" else "Call electric scooter")


func return_player_to_start_position() -> bool:
	if interior_transition_busy or is_instance_valid(interior_root) or vehicle_occupied or scooter_occupied or jet_ski_occupied:
		return false
	if GameModeManager.is_online_ready():
		# Online recovery is requested from the authority; never teleport locally.
		return AuthoritativeGameServer.request_safe_return()
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or not _initial_player_spawn_captured:
		return false
	player.velocity = Vector3.ZERO
	player.mobile_move = Vector2.ZERO
	player.mobile_sprint = false
	player.sitting = false
	player.global_position = _initial_player_spawn_position
	player.reset_physics_interpolation()
	_last_safe_player_position = _initial_player_spawn_position
	return true


func _guard_player_safety() -> void:
	# Offline recovery only; online movement remains server-authoritative.
	if interior_transition_busy or is_instance_valid(interior_root) or vehicle_occupied or jet_ski_occupied:
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or not player.is_physics_processing():
		return
	var position := player.global_position
	var outside_city := absf(position.x) > CITY_SAFE_X_LIMIT or position.z < CITY_SAFE_Z_MIN or position.z > CITY_SAFE_Z_MAX
	if position.y < PLAYER_RECOVERY_FALL_LIMIT or outside_city:
		var recovery := _last_safe_player_position
		if not _is_safe_city_position(recovery):
			recovery = Vector3(0.0, 1.0, -42.0)
		player.global_position = recovery + Vector3.UP * 0.15
		player.velocity = Vector3.ZERO
		player.mobile_move = Vector2.ZERO
		player.mobile_sprint = false
		player.sitting = false
		return
	if player.is_on_floor() and position.y > -0.25 and _is_safe_city_position(position):
		_last_safe_player_position = position


func _is_safe_city_position(position: Vector3) -> bool:
	return position.y > PLAYER_RECOVERY_FALL_LIMIT and absf(position.x) <= CITY_SAFE_X_LIMIT and position.z >= CITY_SAFE_Z_MIN and position.z <= CITY_SAFE_Z_MAX

func _is_local_city_interaction_allowed() -> bool:
	# Interior teleports and local vehicle control are not yet server-authoritative.
	return not GameModeManager.is_online_ready()


func _unhandled_input(event: InputEvent) -> void:
	if GameModeManager.is_online_ready():
		return
	if event is InputEventKey and event.keycode == KEY_E:
		if event.pressed and not event.echo and not _vehicle_key_was_down:
			_vehicle_key_was_down = true
			if vehicle_occupied:
				_exit_player_vehicle()
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

	scooter_toggle_button = Button.new()
	scooter_toggle_button.name = "ElectricScooterToggleButton"
	scooter_toggle_button.text = "🛴"
	scooter_toggle_button.custom_minimum_size = Vector2(control_width, control_height)
	scooter_toggle_button.anchor_left = 1.0
	scooter_toggle_button.anchor_right = 1.0
	scooter_toggle_button.anchor_top = 1.0
	scooter_toggle_button.anchor_bottom = 1.0
	scooter_toggle_button.offset_left = -control_width - right_margin
	scooter_toggle_button.offset_right = -right_margin
	scooter_toggle_button.offset_top = -(bottom_margin + control_height * 3.0 + control_gap * 2.0)
	scooter_toggle_button.offset_bottom = -(bottom_margin + control_height * 2.0 + control_gap * 2.0)
	scooter_toggle_button.add_theme_font_size_override("font_size", 18)
	scooter_toggle_button.tooltip_text = "استدعاء السكوتر الكهربائي"
	scooter_toggle_button.pressed.connect(_on_scooter_toggle_pressed)
	layer.add_child(scooter_toggle_button)

	vehicle_interaction_button = Button.new()
	vehicle_interaction_button.name = "VehicleInteractionButton"
	vehicle_interaction_button.text = "🚪↗"
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
	vehicle_interaction_button.pressed.connect(_on_vehicle_interaction_pressed)
	layer.add_child(vehicle_interaction_button)

func _summon_player_vehicle() -> void:
	if not _is_local_city_interaction_allowed():
		return
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
		vehicle_interaction_button.visible = false
	# Vehicle summon now completes the entry action: place the player inside immediately.
	_toggle_vehicle_use()

func _on_scooter_toggle_pressed() -> void:
	if scooter_occupied:
		# Foot button means return to walking and dismiss the scooter completely.
		_exit_player_scooter(true)
		return
	if is_instance_valid(city_scooter):
		city_scooter.queue_free()
		city_scooter = null
		if is_instance_valid(scooter_toggle_button):
			scooter_toggle_button.text = "🛴"
			scooter_toggle_button.tooltip_text = "استدعاء السكوتر الكهربائي"
		return
	_summon_electric_scooter()

func _summon_electric_scooter() -> void:
	if not _is_local_city_interaction_allowed() or scooter_occupied or vehicle_occupied:
		return
	if interior_transition_busy or is_instance_valid(interior_root):
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		return
	if not is_instance_valid(city_scooter):
		var packed := load("res://scenes/electric_scooter.tscn") as PackedScene
		if packed == null:
			push_warning("تعذر تحميل مشهد السكوتر الكهربائي.")
			return
		city_scooter = packed.instantiate() as CharacterBody3D
		if city_scooter == null:
			return
		city_scooter.name = "PlayerElectricScooter"
		add_child(city_scooter)
		city_scooter.set_physics_process(false)
	var side := player.global_transform.basis.x.normalized()
	city_scooter.global_position = player.global_position + side * 2.2
	city_scooter.global_position.y = player.global_position.y
	city_scooter.global_rotation.y = player.global_rotation.y
	city_scooter.velocity = Vector3.ZERO
	city_scooter.call("clear_controls")
	# Calling the scooter now places the player directly on it.
	_mount_player_scooter()
	if not scooter_occupied:
		city_scooter.queue_free()
		city_scooter = null
		if is_instance_valid(scooter_toggle_button):
			scooter_toggle_button.text = "🛴"
			scooter_toggle_button.tooltip_text = "استدعاء السكوتر الكهربائي" if CityLanguage.get_language() == "ar" else "Call electric scooter"

func try_enter_summoned_vehicle() -> bool:
	# Board the personal watercraft only from the marked start gate on the royal sea course.
	if jet_ski_occupied:
		return true
	if scooter_occupied:
		return true
	if not vehicle_occupied and not scooter_occupied and _is_local_city_interaction_allowed():
		var launch_player := get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(launch_player) and launch_player.global_position.distance_to(JET_SKI_LAUNCH_POSITION) <= JET_SKI_BOARDING_RADIUS:
			if not is_instance_valid(city_jet_ski):
				var jet_ski_scene := load("res://scenes/jet_ski.tscn") as PackedScene
				if jet_ski_scene == null:
					push_warning("تعذر تحميل الجت سكي الملكي.")
					return false
				city_jet_ski = jet_ski_scene.instantiate() as CharacterBody3D
				if city_jet_ski == null:
					return false
				city_jet_ski.name = "PlayerRoyalJetSki"
				add_child(city_jet_ski)
			city_jet_ski.global_position = JET_SKI_LAUNCH_POSITION
			city_jet_ski.global_rotation.y = launch_player.global_rotation.y
			_mount_player_jet_ski()
			return jet_ski_occupied
	if is_instance_valid(city_scooter) and not vehicle_occupied and _is_local_city_interaction_allowed():
		var scooter_player := get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(scooter_player) and scooter_player.global_position.distance_to(city_scooter.global_position) <= 5.0:
			_mount_player_scooter()
			return scooter_occupied
	if vehicle_occupied or not _is_local_city_interaction_allowed() or not is_instance_valid(city_vehicle):
		return false
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or player.global_position.distance_to(city_vehicle.global_position) > 5.0:
		return false
	_toggle_vehicle_use()
	return vehicle_occupied

func _on_vehicle_interaction_pressed() -> void:
	if jet_ski_occupied:
		if GameModeManager.is_online_ready():
			if not _jet_ski_unmount_pending:
				_jet_ski_unmount_pending = true
				if is_instance_valid(vehicle_interaction_button):
					vehicle_interaction_button.disabled = true
				AuthoritativeGameServer.request_jet_ski_unmount()
		else:
			_exit_player_jet_ski()
		return
	if GameModeManager.is_online_ready():
		AuthoritativeGameServer.request_jet_ski_mount()
		return
	_exit_contextual_state()


func _on_jet_ski_mount_result_received(success: bool, message: String) -> void:
	_on_mode_status_changed(message)
	if not success:
		return
	if not is_instance_valid(city_jet_ski):
		var jet_ski_scene := load("res://scenes/jet_ski.tscn") as PackedScene
		if jet_ski_scene == null:
			push_warning("تعذر تحميل الجت سكي بعد تأكيد الخادم.")
			AuthoritativeGameServer.request_jet_ski_unmount()
			return
		city_jet_ski = jet_ski_scene.instantiate() as CharacterBody3D
		if not is_instance_valid(city_jet_ski):
			AuthoritativeGameServer.request_jet_ski_unmount()
			return
		city_jet_ski.name = "LocalAuthoritativeRoyalJetSki"
		add_child(city_jet_ski)
	var local_player := get_node_or_null("Player") as CharacterBody3D
	if is_instance_valid(local_player):
		city_jet_ski.global_position = JET_SKI_LAUNCH_POSITION
		city_jet_ski.global_rotation.y = local_player.global_rotation.y
	_mount_player_jet_ski()


func _on_jet_ski_unmount_result_received(success: bool, server_position: Vector3) -> void:
	_jet_ski_unmount_pending = false
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.disabled = false
	if not success:
		_on_mode_status_changed("تعذر تأكيد النزول من الخادم. ما زلت على الجت سكي.")
		return
	if jet_ski_occupied:
		_exit_player_jet_ski(server_position)


func _on_jet_ski_authoritative_state_received(position: Vector3, rotation_y: float, _velocity: Vector3) -> void:
	if not jet_ski_occupied or not is_instance_valid(city_jet_ski):
		return
	if city_jet_ski.has_method("reconcile_authoritative_state"):
		city_jet_ski.call("reconcile_authoritative_state", position, rotation_y, _velocity)
	else:
		city_jet_ski.global_position = position
		city_jet_ski.global_rotation.y = rotation_y


func _exit_contextual_state() -> void:
	_jet_ski_unmount_pending = false
	if jet_ski_occupied:
		_exit_player_jet_ski()
		return
	if scooter_occupied:
		_exit_player_scooter()
		return
	if vehicle_occupied:
		_exit_player_vehicle()
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		return
	if player.get("animal_riding") == true and player.has_method("end_animal_ride"):
		player.call("end_animal_ride")
	elif player.get("sitting") == true and player.has_method("toggle_sit"):
		player.call("toggle_sit")
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = false
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = true

func _mount_player_scooter() -> void:
	if scooter_occupied or not is_instance_valid(city_scooter):
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or player.get("animal_riding") == true or player.get("sitting") == true:
		return
	_scooter_saved_collision_layer = player.collision_layer
	_scooter_saved_collision_mask = player.collision_mask
	player.set_mobile_move(Vector2.ZERO)
	player.set_mobile_sprint(false)
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.reparent(city_scooter, true)
	player.position = Vector3(0.0, 0.48, 0.0)
	player.rotation = Vector3.ZERO
	player.call("set_mounted_scooter", city_scooter)
	city_scooter.set_physics_process(true)
	scooter_occupied = true
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = false
	if is_instance_valid(scooter_toggle_button):
		scooter_toggle_button.visible = true
		scooter_toggle_button.text = "👣"
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = true
		vehicle_interaction_button.text = "🚪↗"
		vehicle_interaction_button.tooltip_text = "النزول من السكوتر" if CityLanguage.get_language() == "ar" else "Dismount scooter"

func _exit_player_scooter(remove_scooter: bool = false) -> void:
	if not scooter_occupied or not is_instance_valid(city_scooter):
		return
	var player := city_scooter.get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		return
	var exit_position := city_scooter.global_position + city_scooter.global_transform.basis.x.normalized() * 1.35 + Vector3.UP * 0.1
	player.call("set_mounted_scooter", null)
	player.reparent(self, true)
	player.global_position = exit_position
	player.velocity = Vector3.ZERO
	player.collision_layer = _scooter_saved_collision_layer
	player.collision_mask = _scooter_saved_collision_mask
	player.set_physics_process(true)
	city_scooter.call("clear_controls")
	city_scooter.set_physics_process(false)
	scooter_occupied = false
	if remove_scooter:
		city_scooter.queue_free()
		city_scooter = null
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = false
	if is_instance_valid(scooter_toggle_button):
		scooter_toggle_button.visible = true
		scooter_toggle_button.text = "👣" if is_instance_valid(city_scooter) else "🛴"
		scooter_toggle_button.tooltip_text = ("العودة للمشي" if CityLanguage.get_language() == "ar" else "Walk") if is_instance_valid(city_scooter) else ("استدعاء السكوتر الكهربائي" if CityLanguage.get_language() == "ar" else "Call electric scooter")
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = true

func _recover_scooter_occupancy() -> void:
	var player := city_scooter.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(city_scooter) else null
	if is_instance_valid(player):
		player.call("set_mounted_scooter", null)
		player.reparent(self, true)
		player.collision_layer = _scooter_saved_collision_layer
		player.collision_mask = _scooter_saved_collision_mask
		player.set_physics_process(true)
	if is_instance_valid(city_scooter):
		city_scooter.call("clear_controls")
		city_scooter.set_physics_process(false)
	scooter_occupied = false

func _toggle_vehicle_use() -> void:
	if not _is_local_city_interaction_allowed():
		return
	if interior_transition_busy or is_instance_valid(interior_root):
		return
	if vehicle_occupied:
		_exit_player_vehicle()
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if is_instance_valid(player) and player.get("animal_riding") == true:
		if player.has_method("end_animal_ride"):
			player.call("end_animal_ride")
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = true
		return
	if is_instance_valid(player) and player.get("sitting") == true:
		if player.has_method("toggle_sit"):
			player.call("toggle_sit")
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = true
		return
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
		vehicle_interaction_button.text = "🚪↗"
		vehicle_interaction_button.tooltip_text = "النزول من السيارة" if CityLanguage.get_language() == "ar" else "Exit vehicle"
		vehicle_interaction_button.visible = true

func _mount_player_jet_ski() -> void:
	if jet_ski_occupied or not is_instance_valid(city_jet_ski):
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or player.get("animal_riding") == true or player.get("sitting") == true:
		return
	_jet_ski_saved_collision_layer = player.collision_layer
	_jet_ski_saved_collision_mask = player.collision_mask
	_set_mobile_hud_active(false)
	player.set_mobile_move(Vector2.ZERO)
	player.set_mobile_sprint(false)
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.reparent(city_jet_ski, true)
	player.position = Vector3(0.0, 0.88, 0.28)
	player.rotation = Vector3.ZERO
	player.visible = true
	player.sitting = true
	var player_camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if is_instance_valid(player_camera):
		player_camera.current = false
	var jet_camera := city_jet_ski.get_node_or_null("CameraPivot/SpringArm3D/JetSkiCamera") as Camera3D
	if is_instance_valid(jet_camera):
		jet_camera.current = true
	var jet_hud := city_jet_ski.get_node_or_null("JetSkiHUDLayer") as CanvasLayer
	if is_instance_valid(jet_hud):
		jet_hud.visible = true
	# Online mode predicts locally from the same water controls, then reconciles against server snapshots.
	city_jet_ski.set_physics_process(true)
	jet_ski_occupied = true
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.text = "🚪↗"
		vehicle_interaction_button.tooltip_text = "النزول من الجت سكي" if CityLanguage.get_language() == "ar" else "Exit jet ski"
		vehicle_interaction_button.visible = true
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = false
	if is_instance_valid(scooter_toggle_button):
		scooter_toggle_button.visible = false


func _exit_player_jet_ski(server_position: Variant = null) -> void:
	if not jet_ski_occupied or not is_instance_valid(city_jet_ski):
		return
	var player := city_jet_ski.get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		_recover_jet_ski_occupancy()
		return
	var exit_position := city_jet_ski.global_position + city_jet_ski.global_transform.basis.x.normalized() * 2.0 + Vector3.UP * 0.15
	if server_position is Vector3 and is_finite(server_position.x) and is_finite(server_position.y) and is_finite(server_position.z):
		exit_position = server_position
	player.reparent(self, true)
	player.global_position = exit_position
	_jet_ski_unmount_pending = false
	player.velocity = Vector3.ZERO
	player.sitting = false
	player.collision_layer = _jet_ski_saved_collision_layer
	player.collision_mask = _jet_ski_saved_collision_mask
	player.set_physics_process(true)
	var jet_camera := city_jet_ski.get_node_or_null("CameraPivot/SpringArm3D/JetSkiCamera") as Camera3D
	if is_instance_valid(jet_camera):
		jet_camera.current = false
	var player_camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if is_instance_valid(player_camera):
		player_camera.current = true
	var jet_hud := city_jet_ski.get_node_or_null("JetSkiHUDLayer") as CanvasLayer
	if is_instance_valid(jet_hud):
		var controls := jet_hud.get_node_or_null("JetSkiHUD") as Control
		if is_instance_valid(controls) and controls.has_method("_clear_controls"):
			controls.call("_clear_controls")
		jet_hud.visible = false
	city_jet_ski.call("clear_controls")
	city_jet_ski.set_physics_process(false)
	jet_ski_occupied = false
	_set_mobile_hud_active(true)
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = false
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = true
	if is_instance_valid(scooter_toggle_button):
		scooter_toggle_button.visible = true


func _recover_jet_ski_occupancy() -> void:
	var player := city_jet_ski.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(city_jet_ski) else null
	if is_instance_valid(player):
		player.reparent(self, true)
		player.sitting = false
		player.collision_layer = _jet_ski_saved_collision_layer
		player.collision_mask = _jet_ski_saved_collision_mask
		player.set_physics_process(true)
		var player_camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
		if is_instance_valid(player_camera):
			player_camera.current = true
	if is_instance_valid(city_jet_ski):
		city_jet_ski.call("clear_controls")
		city_jet_ski.set_physics_process(false)
		var jet_camera := city_jet_ski.get_node_or_null("CameraPivot/SpringArm3D/JetSkiCamera") as Camera3D
		if is_instance_valid(jet_camera):
			jet_camera.current = false
		var jet_hud := city_jet_ski.get_node_or_null("JetSkiHUDLayer") as CanvasLayer
		if is_instance_valid(jet_hud):
			jet_hud.visible = false
	jet_ski_occupied = false
	_set_mobile_hud_active(is_instance_valid(player))


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
		vehicle_interaction_button.tooltip_text = "ركوب السيارة" if CityLanguage.get_language() == "ar" else "Enter vehicle"
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
		vehicle_interaction_button.visible = false

func _create_interior_transition_ui() -> void:
	interior_loading_layer = CanvasLayer.new()
	interior_loading_layer.name = "InteriorTransitionUI"
	interior_loading_layer.layer = 30
	add_child(interior_loading_layer)
	var backdrop := ColorRect.new()
	backdrop.name = "LoadingBackdrop"
	backdrop.color = Color(0.035, 0.025, 0.018, 0.98)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	interior_loading_layer.add_child(backdrop)
	# إطار فرعوني ذهبي وزخارف هندسية خفيفة بدل خلفية فارغة.
	var frame := Panel.new()
	frame.name = "PharaonicFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 22
	frame.offset_top = 22
	frame.offset_right = -22
	frame.offset_bottom = -22
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.07, 0.045, 0.025, 0.0)
	frame_style.border_color = Color(0.78, 0.57, 0.23, 0.95)
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(12)
	frame.add_theme_stylebox_override("panel", frame_style)
	backdrop.add_child(frame)
	for side in [-1, 1]:
		var hieroglyphs := Label.new()
		hieroglyphs.name = "HieroglyphColumn_%d" % side
		hieroglyphs.text = "𓂀\n𓆣\n𓋹\n𓊖\n𓇳"
		hieroglyphs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hieroglyphs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hieroglyphs.size = Vector2(86, 390)
		hieroglyphs.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if side < 0 else Control.PRESET_CENTER_RIGHT)
		hieroglyphs.position = Vector2(34 if side < 0 else -120, -195)
		hieroglyphs.add_theme_font_size_override("font_size", 38)
		hieroglyphs.add_theme_color_override("font_color", Color(0.78, 0.58, 0.27, 0.22))
		backdrop.add_child(hieroglyphs)
	var ornament := Label.new()
	ornament.name = "PharaonicOrnament"
	ornament.text = "𓂀     𓆣     𓋹     𓂀"
	ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ornament.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	ornament.position = Vector2(-190, 95)
	ornament.size = Vector2(380, 60)
	ornament.add_theme_font_size_override("font_size", 38)
	ornament.add_theme_color_override("font_color", Color(0.88, 0.68, 0.31))
	backdrop.add_child(ornament)
	var content := VBoxContainer.new()
	content.name = "LoadingContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.position = Vector2(-230, -55)
	content.size = Vector2(460, 190)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	backdrop.add_child(content)
	interior_loading_label = Label.new()
	interior_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interior_loading_label.add_theme_font_size_override("font_size", 27)
	interior_loading_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.48))
	content.add_child(interior_loading_label)
	var hint := Label.new()
	hint.text = "𓂀   KING OF EGYPT CITY   𓂀"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.91, 0.84, 0.68))
	content.add_child(hint)
	interior_loading_progress = ProgressBar.new()
	interior_loading_progress.name = "LoadingProgress"
	interior_loading_progress.custom_minimum_size = Vector2(420, 20)
	interior_loading_progress.min_value = 0.0
	interior_loading_progress.max_value = 100.0
	interior_loading_progress.value = 0.0
	interior_loading_progress.show_percentage = true
	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color = Color(0.12, 0.09, 0.06)
	progress_style.border_color = Color(0.78, 0.57, 0.23)
	progress_style.set_border_width_all(2)
	progress_style.set_corner_radius_all(8)
	interior_loading_progress.add_theme_stylebox_override("background", progress_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.86, 0.65, 0.27)
	fill_style.set_corner_radius_all(6)
	interior_loading_progress.add_theme_stylebox_override("fill", fill_style)
	content.add_child(interior_loading_progress)
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
	if is_instance_valid(palace_navigation_layer):
		palace_navigation_layer.visible = false
		if is_instance_valid(palace_navigation_popup):
			palace_navigation_popup.hide()
	var backdrop := interior_loading_layer.get_node_or_null("LoadingBackdrop") as ColorRect
	if is_instance_valid(backdrop):
		backdrop.visible = not show_exit
	interior_exit_button.visible = show_exit
	if not show_exit and is_instance_valid(interior_loading_progress):
		if is_instance_valid(interior_loading_tween):
			interior_loading_tween.kill()
		interior_loading_progress.value = 0.0
		interior_loading_tween = create_tween()
		interior_loading_tween.tween_property(interior_loading_progress, "value", 100.0, 0.65)
	_refresh_interior_ui_language()

func _hide_interior_loading() -> void:
	var backdrop: ColorRect = null
	if is_instance_valid(interior_loading_layer):
		backdrop = interior_loading_layer.get_node_or_null("LoadingBackdrop") as ColorRect
	if is_instance_valid(backdrop):
		backdrop.visible = false
	interior_exit_button.visible = false
	if is_instance_valid(interior_loading_tween):
		interior_loading_tween.kill()
	if is_instance_valid(interior_root) and bool(interior_root.get_meta("royal_palace", false)):
		_set_palace_navigation_visible(true)

func enter_building_interior(building: Node3D, actor: Node3D) -> void:
	if not _is_local_city_interaction_allowed():
		return
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
	_set_palace_navigation_visible(str(building.get("building_title")) == "القصر الملكي")
	await get_tree().create_timer(0.15).timeout
	_hide_interior_loading()

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
	interior_root.set_meta("royal_palace", building_title == "القصر الملكي")
	add_child(interior_root)
	if building_title == "القصر الملكي":
		_create_royal_palace_interior(interior_root)
		return
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
	_create_palace_portal(interior_root, "BuildingCityExitGate", "الخروج إلى المدينة", Vector3(0,0,6.8), "city_exit")

func _create_royal_palace_interior(root: Node3D) -> void:
	# ردهة مركزية وخمسة أجنحة مغلقة بجدران وتصادمات مستقلة.
	_create_box(root, "PalaceMarbleFloor", Vector3(34, 0.35, 30), Vector3(0, 0, 0), Color(0.72, 0.66, 0.54), true)
	_create_box(root, "PalaceBackWall", Vector3(34, 6.5, 0.4), Vector3(0, 3.25, -15), Color(0.78, 0.70, 0.56), true)
	_create_box(root, "PalaceLeftWall", Vector3(0.4, 6.5, 30), Vector3(-17, 3.25, 0), Color(0.70, 0.61, 0.47), true)
	_create_box(root, "PalaceRightWall", Vector3(0.4, 6.5, 30), Vector3(17, 3.25, 0), Color(0.70, 0.61, 0.47), true)
	_create_box(root, "PalaceFrontLeft", Vector3(12, 6.5, 0.4), Vector3(-11, 3.25, 15), Color(0.78, 0.70, 0.56), true)
	_create_box(root, "PalaceFrontRight", Vector3(12, 6.5, 0.4), Vector3(11, 3.25, 15), Color(0.78, 0.70, 0.56), true)
	_create_box(root, "PalaceEntranceLintel", Vector3(10, 1.0, 0.45), Vector3(0, 5.9, 15), Color(0.86, 0.67, 0.30), true)
	_create_box(root, "PalaceLobbyFloor", Vector3(13, 0.18, 9), Vector3(0, 0.22, 0), Color(0.83, 0.75, 0.61), true)
	_create_box(root, "PalaceLobbyGoldInlay", Vector3(9, 0.07, 6), Vector3(0, 0.35, 0), Color(0.86, 0.67, 0.30))
	var lobby_title := Label3D.new()
	lobby_title.name = "PalaceLobbyTitle"
	lobby_title.text = "الردهة الملكية"
	lobby_title.position = Vector3(0, 3.7, -3.9)
	lobby_title.font_size = 42
	lobby_title.pixel_size = 0.012
	lobby_title.modulate = Color(1.0, 0.88, 0.58)
	lobby_title.outline_size = 7
	root.add_child(lobby_title)

	var rooms := [
		{"id":"ThroneHall","label":"قاعة العرش الملكية","center":Vector3(-10,0,-9),"door":"south","color":Color(0.52,0.34,0.22),"target":"throne"},
		{"id":"CelebrationHall","label":"قاعة الاحتفالات","center":Vector3(0,0,-9),"door":"south","color":Color(0.48,0.25,0.22),"target":"celebration"},
		{"id":"EuropeanCasino","label":"الكازينو الأوروبي","center":Vector3(10,0,-9),"door":"south","color":Color(0.12,0.30,0.29),"target":"casino"},
		{"id":"VIPLounge","label":"صالة VIP","center":Vector3(-7,0,9),"door":"north","color":Color(0.16,0.22,0.30),"target":"vip"},
		{"id":"IndoorGarden","label":"الحديقة الملكية الداخلية","center":Vector3(7,0,9),"door":"north","color":Color(0.19,0.34,0.23),"target":"garden"}
	]
	for room in rooms:
		var center: Vector3 = room["center"]
		var room_id := str(room["id"])
		var label := str(room["label"])
		var door_side := str(room["door"])
		var room_color: Color = room["color"]
		_create_palace_room_shell(root, room_id, center, door_side, room_color)
		var portal_z := center.z + (4.35 if door_side == "south" else -4.35)
		_create_palace_portal(root, room_id + "Door", "دخول " + label, Vector3(center.x,0,portal_z), str(room["target"]))
		var plaque := Label3D.new()
		plaque.name = room_id + "Plaque"
		plaque.text = label
		plaque.position = center + Vector3(0,3.2,-3.55)
		plaque.font_size = 25
		plaque.pixel_size = 0.012
		plaque.modulate = Color(1.0,0.88,0.58)
		plaque.outline_size = 7
		root.add_child(plaque)
		if room_id == "EuropeanCasino":
			_create_european_vip_slot_machines(root, center)
		else:
			_create_box(root, room_id + "Feature", Vector3(2.2,0.9,0.9), center + Vector3(0,0.75,0.7), room_color, true)

	# أثاث القصر غير المتعارض مع نظام الماكينات الجديد.
	_create_box(root, "ThroneDais", Vector3(3.8,0.45,2.6), Vector3(-10,0.48,-10.5), Color(0.58,0.43,0.24), true)
	_create_box(root, "ThroneSeat", Vector3(1.8,1.8,1.0), Vector3(-10,1.6,-10.5), Color(0.42,0.12,0.12), true)
	for i in range(3):
		var x := -2.0 + float(i) * 2.0
		_create_box(root, "CelebrationTable_%d" % i, Vector3(1.3,0.18,1.3), Vector3(x,0.85,-9.2), Color(0.48,0.27,0.14), true)
	for i in range(2):
		_create_box(root, "VIPSofa_%d" % i, Vector3(2.5,0.7,0.9), Vector3(-8.5 + float(i)*3.0,0.42,10.0), Color(0.12,0.20,0.28), true)
	for i in range(3):
		_create_box(root, "GardenPlanter_%d" % i, Vector3(1.3,0.6,1.3), Vector3(5.0 + float(i)*1.8,0.42,10.0), Color(0.20,0.36,0.22), true)
		_create_box(root, "GardenPlant_%d" % i, Vector3(0.55,1.6,0.55), Vector3(5.0 + float(i)*1.8,1.45,10.0), Color(0.15,0.42,0.20))
	_create_palace_portal(root, "PalaceCityExitGate", "الخروج إلى المدينة", Vector3(0,0,13.0), "city_exit")
	var title := Label3D.new()
	title.name = "RoyalPalaceInteriorTitle"
	title.text = "القصر الملكي"
	title.position = Vector3(0,5.1,-14.6)
	title.font_size = 54
	title.pixel_size = 0.012
	title.modulate = Color(1.0,0.88,0.58)
	root.add_child(title)
	var light := OmniLight3D.new()
	light.position = Vector3(0,5.2,0)
	light.light_color = Color(1.0,0.82,0.57)
	light.light_energy = 1.6
	light.omni_range = 42.0
	root.add_child(light)


func _create_palace_room_shell(root: Node3D, room_id: String, center: Vector3, door_side: String, room_color: Color) -> void:
	var width := 9.5
	var depth := 8.0
	var height := 5.2
	var wall_color := Color(0.76,0.68,0.54)
	_create_box(root, room_id + "Floor", Vector3(width,0.3,depth), center, room_color.lightened(0.32), true)
	_create_box(root, room_id + "LeftWall", Vector3(0.3,height,depth), center + Vector3(-width*0.5,height*0.5,0), wall_color, true)
	_create_box(root, room_id + "RightWall", Vector3(0.3,height,depth), center + Vector3(width*0.5,height*0.5,0), wall_color, true)
	var door_width := 2.8
	if door_side == "south":
		_create_box(root, room_id + "BackWall", Vector3(width,height,0.3), center + Vector3(0,height*0.5,-depth*0.5), wall_color, true)
		_create_box(root, room_id + "FrontWallLeft", Vector3((width-door_width)*0.5,height,0.3), center + Vector3(-(width+door_width)*0.25,height*0.5,depth*0.5), wall_color, true)
		_create_box(root, room_id + "FrontWallRight", Vector3((width-door_width)*0.5,height,0.3), center + Vector3((width+door_width)*0.25,height*0.5,depth*0.5), wall_color, true)
		_create_box(root, room_id + "DoorLintel", Vector3(door_width,0.7,0.34), center + Vector3(0,height-0.35,depth*0.5), Color(0.86,0.67,0.30), true)
	else:
		_create_box(root, room_id + "FrontWall", Vector3(width,height,0.3), center + Vector3(0,height*0.5,depth*0.5), wall_color, true)
		_create_box(root, room_id + "BackWallLeft", Vector3((width-door_width)*0.5,height,0.3), center + Vector3(-(width+door_width)*0.25,height*0.5,-depth*0.5), wall_color, true)
		_create_box(root, room_id + "BackWallRight", Vector3((width-door_width)*0.5,height,0.3), center + Vector3((width+door_width)*0.25,height*0.5,-depth*0.5), wall_color, true)
		_create_box(root, room_id + "DoorLintel", Vector3(door_width,0.7,0.34), center + Vector3(0,height-0.35,-depth*0.5), Color(0.86,0.67,0.30), true)


func _create_palace_portal(root: Node3D, portal_name: String, label: String, position: Vector3, destination: String) -> void:
	var portal := Node3D.new()
	portal.name = portal_name
	portal.set_script(load("res://scripts/palace_portal_interaction.gd"))
	portal.position = position
	portal.set_meta("palace_portal_target", destination)
	portal.set_meta("palace_portal_label", label)
	if destination != "city_exit":
		var room_centers := {"throne":Vector3(-10,0,-9),"celebration":Vector3(0,0,-9),"casino":Vector3(10,0,-9),"vip":Vector3(-7,0,9),"garden":Vector3(7,0,9)}
		portal.set_meta("palace_room_center", room_centers.get(destination, Vector3.ZERO))
		portal.set_meta("palace_door_side", "south" if destination in ["throne","celebration","casino"] else "north")
	root.add_child(portal)
	_create_box(portal, "PortalMarker", Vector3(1.7,2.5,0.14), Vector3(0,1.25,0), Color(0.86,0.67,0.30))
	var sign := Label3D.new()
	sign.text = label
	sign.position = Vector3(0,3.0,0)
	sign.font_size = 21
	sign.pixel_size = 0.012
	sign.modulate = Color(1.0,0.9,0.66)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	portal.add_child(sign)


func _create_palace_navigation_ui() -> void:
	palace_navigation_layer = CanvasLayer.new()
	palace_navigation_layer.name = "PalaceQuickNavigation"
	palace_navigation_layer.layer = 32
	palace_navigation_layer.visible = false
	add_child(palace_navigation_layer)
	palace_navigation_button = Button.new()
	palace_navigation_button.name = "PalaceNavigationButton"
	palace_navigation_button.text = "𓉐 الأماكن"
	palace_navigation_button.position = Vector2(18,110)
	palace_navigation_button.size = Vector2(148,42)
	palace_navigation_button.pressed.connect(_toggle_palace_navigation)
	palace_navigation_layer.add_child(palace_navigation_button)
	palace_navigation_popup = PopupMenu.new()
	palace_navigation_popup.name = "PalaceNavigationPopup"
	palace_navigation_popup.add_item("الردهة المركزية",0)
	palace_navigation_popup.add_item("قاعة العرش الملكية",1)
	palace_navigation_popup.add_item("قاعة الاحتفالات",2)
	palace_navigation_popup.add_item("الكازينو الأوروبي",3)
	palace_navigation_popup.add_item("صالة VIP",4)
	palace_navigation_popup.add_item("الحديقة الملكية الداخلية",5)
	palace_navigation_popup.add_item("الاقتراب من بوابة الخروج",6)
	palace_navigation_popup.id_pressed.connect(_on_palace_navigation_selected)
	palace_navigation_layer.add_child(palace_navigation_popup)


func _set_palace_navigation_visible(show: bool) -> void:
	if is_instance_valid(palace_navigation_layer):
		palace_navigation_layer.visible = show
		if not show and is_instance_valid(palace_navigation_popup):
			palace_navigation_popup.hide()


func _toggle_palace_navigation() -> void:
	if not is_instance_valid(palace_navigation_popup) or not is_instance_valid(palace_navigation_button):
		return
	palace_navigation_popup.position = Vector2i(int(palace_navigation_button.global_position.x), int(palace_navigation_button.global_position.y + palace_navigation_button.size.y))
	palace_navigation_popup.popup()


func _on_palace_navigation_selected(id: int) -> void:
	var destinations := ["lobby","throne","celebration","casino","vip","garden","exit_gate"]
	if id >= 0 and id < destinations.size():
		_navigate_palace_quick(destinations[id])


func _navigate_palace_quick(destination: String) -> void:
	if interior_transition_busy or not is_instance_valid(interior_root) or not is_instance_valid(interior_player):
		return
	var positions := {
		"lobby":Vector3(0,1.05,0),
		"throne":Vector3(-10,1.05,-9),
		"celebration":Vector3(0,1.05,-9),
		"casino":Vector3(10,1.05,-9),
		"vip":Vector3(-7,1.05,9),
		"garden":Vector3(7,1.05,9),
		"exit_gate":Vector3(0,1.05,11.2)
	}
	if not positions.has(destination):
		return
	interior_transition_busy = true
	interior_player.set_physics_process(false)
	_show_interior_loading(false, "interior_loading")
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree() or not is_instance_valid(interior_root) or not is_instance_valid(interior_player):
		if is_instance_valid(interior_player):
			interior_player.set_physics_process(true)
		interior_transition_busy = false
		_hide_interior_loading()
		return
	interior_player.global_position = INTERIOR_WORLD_POSITION + positions[destination]
	interior_player.velocity = Vector3.ZERO
	interior_player.set_physics_process(true)
	interior_transition_busy = false
	if is_instance_valid(palace_navigation_popup):
		palace_navigation_popup.hide()
	_hide_interior_loading()
	var manager := get_node_or_null("MissionManager")
	if is_instance_valid(manager):
		manager.call_deferred("_update_interaction_target")
		manager.call_deferred("_update_interaction_hud")


func use_palace_portal(portal: Node3D, actor: Node3D) -> void:
	if interior_transition_busy or not is_instance_valid(interior_root) or not is_instance_valid(portal) or not is_instance_valid(actor):
		return
	var destination := str(portal.get_meta("palace_portal_target",""))
	if destination == "city_exit":
		return_from_building_interior()
		return
	if not portal.has_meta("palace_room_center"):
		return
	var center: Vector3 = portal.get_meta("palace_room_center")
	var door_side := str(portal.get_meta("palace_door_side","south"))
	var portal_local := portal.global_position - INTERIOR_WORLD_POSITION
	var actor_local := actor.global_position - INTERIOR_WORLD_POSITION
	var is_inside_room := actor_local.z < portal_local.z if door_side == "south" else actor_local.z > portal_local.z
	var destination_position := Vector3(0,1.05,0)
	if is_inside_room:
		destination_position = Vector3(center.x,1.05,portal_local.z + (1.8 if door_side == "south" else -1.8))
	else:
		destination_position = Vector3(center.x,1.05,center.z)
	interior_transition_busy = true
	actor.set_physics_process(false)
	_show_interior_loading(false, "interior_loading")
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree() or not is_instance_valid(interior_root) or not is_instance_valid(actor):
		if is_instance_valid(actor):
			actor.set_physics_process(true)
		interior_transition_busy = false
		_hide_interior_loading()
		return
	actor.global_position = INTERIOR_WORLD_POSITION + destination_position
	actor.velocity = Vector3.ZERO
	actor.set_physics_process(true)
	interior_transition_busy = false
	_hide_interior_loading()
	var manager := get_node_or_null("MissionManager")
	if is_instance_valid(manager):
		manager.call_deferred("_update_interaction_target")
		manager.call_deferred("_update_interaction_hud")


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
			for side_index in range(2):
				var side: float = -1.0 if side_index == 0 else 1.0
				_create_box(root, "RestaurantSeat_%d_%d" % [index, side_index], Vector3(0.8, 0.85, 0.8), Vector3(x + side * 1.35, 0.42, z), Color(0.18, 0.31, 0.29), true)
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
	await get_tree().create_timer(0.65).timeout
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
	_set_palace_navigation_visible(false)
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
	# Keep the full northern city ground while opening a broad, collision-free
	# sea footprint from the promenade southward. East/west land strips remain
	# continuous and provide dry beach-club and sports access.
	var ground_color := Color(0.34, 0.42, 0.31)
	_create_box(self, "Ground_West", Vector3(100, 1, 520), Vector3(-110, -0.55, -80), ground_color, true)
	_create_box(self, "Ground_East", Vector3(100, 1, 520), Vector3(110, -0.55, -80), ground_color, true)
	_create_box(self, "Ground_Center_North", Vector3(120, 1, 418), Vector3(0, -0.55, -131), ground_color, true)

func _create_city() -> void:
	# المباني المرئية تُنشأ من قائمة المدينة المعتمدة في ApprovedCityLayout.
	# شبكة الطرق تمر في الممرات الخالية وبين صفوف المباني، لا عبر بصماتها.

	var road_color := Color(0.12, 0.13, 0.15)
	var side_road_color := Color(0.15, 0.16, 0.17)
	# طريق محيطي مستطيل يحيط بالمدينة مع خلوّ مسافة عن مباني الأطراف.
	_create_box(self, "MainRoad_North", Vector3(190, 0.08, 6), Vector3(0, 0.0, -95), road_color)
	# Perimeter roads continue along the dry east/west shoreline strips;
	# no road or collision surface crosses the open-water race area.
	_create_box(self, "MainRoad_West", Vector3(6, 0.08, 260), Vector3(-95, 0.0, 35), road_color)
	_create_box(self, "MainRoad_East", Vector3(6, 0.08, 260), Vector3(95, 0.0, 35), road_color)
	_create_box(self, "BeachAccessRoad_West", Vector3(6, 0.08, 70), Vector3(-65, 0.0, 115), road_color)
	_create_box(self, "BeachAccessRoad_East", Vector3(6, 0.08, 70), Vector3(65, 0.0, 115), road_color)
	_create_box(self, "BeachAccessConnector_West", Vector3(30, 0.08, 6), Vector3(-80, 0.0, 115), road_color)
	_create_box(self, "BeachAccessConnector_East", Vector3(30, 0.08, 6), Vector3(80, 0.0, 115), road_color)
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
			var mark_x: float = side * (28.0 + float(i) * 18.0)
			_create_box(self, "RoadMark_X_%s_%d" % [str(side), i], Vector3(3, 0.025, 0.16), Vector3(mark_x, 0.06, -45), Color(0.92, 0.86, 0.62))
	_create_city_pedestrian_network()

func _create_city_pedestrian_network() -> void:
	var sidewalk_color := Color(0.58, 0.51, 0.40)
	var curb_color := Color(0.78, 0.69, 0.53)
	for road_z in [-15.0, 15.0, 45.0]:
		for side in [-1.0, 1.0]:
			var walk_z: float = road_z + side * 4.0
			_create_box(self, "Sidewalk_H_%d_%d" % [int(road_z), int(side)], Vector3(132.0, 0.14, 1.7), Vector3(0.0, 0.07, walk_z), sidewalk_color)
			_create_box(self, "Curb_H_%d_%d" % [int(road_z), int(side)], Vector3(132.0, 0.22, 0.16), Vector3(0.0, 0.11, road_z + side * 4.92), curb_color)
	for road_x in [-15.0, 15.0]:
		for side in [-1.0, 1.0]:
			var walk_x: float = road_x + side * 3.65
			_create_box(self, "Sidewalk_V_%d_%d" % [int(road_x), int(side)], Vector3(1.65, 0.14, 118.0), Vector3(walk_x, 0.07, 36.0), sidewalk_color)
			_create_box(self, "Curb_V_%d_%d" % [int(road_x), int(side)], Vector3(0.16, 0.22, 118.0), Vector3(road_x + side * 4.55, 0.11, 36.0), curb_color)
	for road_z in [-15.0, 15.0, 45.0]:
		for mark_index in range(12):
			var mark_x := -62.0 + float(mark_index) * 11.0
			_create_box(self, "LaneDash_H_%d_%d" % [int(road_z), mark_index], Vector3(2.4, 0.025, 0.12), Vector3(mark_x, 0.065, road_z), Color(0.91, 0.85, 0.68))
	for road_x in [-15.0, 15.0]:
		for mark_index in range(10):
			var mark_z := -18.0 + float(mark_index) * 11.0
			_create_box(self, "LaneDash_V_%d_%d" % [int(road_x), mark_index], Vector3(0.12, 0.025, 2.4), Vector3(road_x, 0.065, mark_z), Color(0.91, 0.85, 0.68))
	for road_x in [-15.0, 15.0]:
		for road_z in [-15.0, 15.0, 45.0]:
			for stripe in range(5):
				var stripe_z: float = road_z - 2.1 + float(stripe) * 1.05
				_create_box(self, "Crosswalk_H_%d_%d_%d" % [int(road_x), int(road_z), stripe], Vector3(3.4, 0.035, 0.42), Vector3(road_x, 0.075, stripe_z), Color(0.88, 0.85, 0.76))
				var stripe_x: float = road_x - 1.8 + float(stripe) * 0.9
				_create_box(self, "Crosswalk_V_%d_%d_%d" % [int(road_x), int(road_z), stripe], Vector3(0.42, 0.035, 3.4), Vector3(stripe_x, 0.075, road_z), Color(0.88, 0.85, 0.76))


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
	_create_adventure_hub_interaction()
	if AuthoritativeGameServer.is_dedicated_server_requested():
		_add_functional_building(null, "المتجر", "مهمة شراء احتياجات", "تعرّف على المتجر واستلم قائمة احتياجات تجريبية من البوابة.", Vector3(0, 0, 6.4), Color(0.20, 0.48, 0.30), 150, 0, 1)
		_add_functional_building(null, "المطعم", "مهمة توصيل وجبة", "استلم طلب توصيل تجريبي من المطعم.", Vector3(60, 0, -23.6), Color(0.65, 0.30, 0.18), 220, 2, 1)
		_add_functional_building(null, "مركز التوظيف", "مهمة التسجيل في وظيفة", "تعرّف على الوظائف المتاحة وشروط الالتحاق بها.", Vector3(30, 0, -23.6), Color(0.22, 0.34, 0.62), 300, 5, 1)
		_create_job_board("مكتب الوظائف", "اختر من الوظائف السبع المعتمدة: الشحنات، البريد، البيتزا، الصيدلية، الزهور والهدايا، طلبات المنازل، والأمتعة.", Vector3(30, 0, -22.0), Vector3.ZERO, 0, 0, 0, "city_jobs_hub")
		return
	var manager := Node.new()
	manager.name = "MissionManager"
	manager.set_script(load("res://scripts/mission_manager.gd"))
	add_child(manager)
	manager.set("player", get_node_or_null("Player"))
	var daily := Node.new()
	daily.name = "DailyActivities"
	daily.set_script(load("res://scripts/daily_activities.gd"))
	daily.set("player", get_node_or_null("Player"))
	daily.set("mission_manager", manager)
	manager.set("daily_activities", daily)
	var achievements := Node.new()
	achievements.name = "AchievementManager"
	achievements.set_script(load("res://scripts/achievement_manager.gd"))
	achievements.set("player", get_node_or_null("Player"))
	achievements.set("mission_manager", manager)
	manager.set("achievement_manager", achievements)
	daily.set("achievement_manager", achievements)
	add_child(achievements)
	add_child(daily)
	var profile_ui := Node.new()
	profile_ui.name = "ProfileSettings"
	profile_ui.set_script(load("res://scripts/profile_settings.gd"))
	profile_ui.set("mission_manager", manager)
	profile_ui.player = get_node_or_null("Player")
	add_child(profile_ui)

	_add_functional_building(manager, "المتجر", "مهمة شراء احتياجات", "تعرّف على المتجر واستلم قائمة احتياجات تجريبية من البوابة.", Vector3(0, 0, 6.4), Color(0.20, 0.48, 0.30), 150, 0, 1)
	_add_functional_building(manager, "المطعم", "مهمة توصيل وجبة", "استلم طلب توصيل تجريبي من المطعم. ستصبح أهداف التوصيل الفعلية جزءًا من مرحلة لاحقة.", Vector3(60, 0, -23.6), Color(0.65, 0.30, 0.18), 220, 2, 1)
	_add_functional_building(manager, "مركز التوظيف", "مهمة التسجيل في وظيفة", "تعرّف على الوظائف المتاحة وشروط الالتحاق بها.", Vector3(30, 0, -23.6), Color(0.22, 0.34, 0.62), 300, 5, 1)
	_create_job_board("مكتب الوظائف", "اختر من الوظائف السبع المعتمدة: الشحنات، البريد، البيتزا، الصيدلية، الزهور والهدايا، طلبات المنازل، والأمتعة.", Vector3(30, 0, -22.0), Vector3.ZERO, 0, 0, 0, "city_jobs_hub")
	_create_service_staff("صاحب المتجر", "صاحب محل", "أهلًا بك! يمكنني مساعدتك في احتياجاتك ومشترياتك من المتجر.", Vector3(3.5, 0, 7.0))
	_create_service_staff("موظف المطعم", "موظف", "مرحبًا! أستقبل طلبات المطعم وأساعدك في أنشطة التوصيل.", Vector3(63.5, 0, -23.0))
	_create_service_staff("موظف مركز التوظيف", "موظف", "أهلًا بك! يمكنك مراجعة الوظائف المتاحة وشروطها هنا.", Vector3(33.5, 0, -23.0))

func _create_adventure_hub_interaction() -> void:
	# Invisible interaction anchor at the entrance of the existing adventure_center building.
	# No mesh, collision shell, building, map, or world area is added.
	var hub := Node3D.new()
	hub.name = "AdventureHubInteraction"
	hub.set_script(load("res://scripts/building_interaction.gd"))
	hub.building_id = "city_adventure_hub"
	hub.server_activity_id = "city_adventure_rescue"
	hub.building_title = "مركز المغامرات"
	hub.mission_title = "مغامرات المدينة"
	hub.mission_description = "اختر مغامرة من مغامرات المدينة. جميع الأهداف داخل المواقع الموجودة بالفعل."
	hub.activity_list = "مهمة الإنقاذ، الكنز المفقود، الرسالة الغامضة، سباق النجاة"
	hub.reward_money = 0
	hub.reward_chips = 0
	hub.reward_xp = 0
	hub.required_level = 1
	hub.requires_interior = false
	hub.interaction_radius = 4.5
	hub.position = Vector3(-75.0, 0.0, 63.9)
	add_child(hub)


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
	# Invisible mission anchor for the corresponding approved city building.
	# Visible geometry is supplied by ApprovedCityLayout to avoid duplicate structures.
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
	var board_key := "employment"
	_add_sign_label(board, board_key, Vector3(0, 2.05, -0.12))



func _create_city_signage() -> void:
	# Signposts reuse primitive meshes and point to known prototype destinations.
	_create_direction_signpost("Signpost_Central", Vector3(9, 0, 8), "restaurant", "shop", PI / 2.0)
	# Move roadside signs off the road centerline and turn their faces toward the road.
	_create_direction_signpost("Signpost_Employment", Vector3(29, 0, -8), "employment", "city_center", PI / 2.0)

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

func _create_desert_camp() -> void:
	# المخيم الملكي هو منطقة الضيافة الصحراوية الوحيدة؛ الجمال والخيول جزء من تصميمه.
	_create_box(self, "DesertCampAccessRoad", Vector3(35, 0.08, 5), Vector3(-112.5, 0.01, 70), Color(0.12, 0.13, 0.15), true)
	_create_box(self, "DesertCampApproachRoad", Vector3(5, 0.08, 15), Vector3(-130, 0.01, 62.5), Color(0.12, 0.13, 0.15), true)
	var camp := Node3D.new()
	camp.name = "RoyalDesertCamp"
	camp.position = Vector3(-130, 0, 70)
	camp.set_script(load("res://scripts/desert_camp.gd"))
	add_child(camp)

func _create_pyramids_area() -> void:
	# منطقة الأهرامات وأبو الهول متصلة بطريق المخيم الصحراوي.
	_create_box(self, "PyramidsAccessRoad_SouthConnector", Vector3(19.5, 0.08, 5), Vector3(-120.25, 0.01, 55), Color(0.12, 0.13, 0.15), true)
	_create_box(self, "PyramidsAccessRoad_West", Vector3(5, 0.08, 50), Vector3(-108, 0.01, 75), Color(0.12, 0.13, 0.15), true)
	_create_box(self, "PyramidsAccessRoad_Approach", Vector3(18, 0.08, 5), Vector3(-99, 0.01, 100), Color(0.12, 0.13, 0.15), true)
	var pyramids := Node3D.new()
	pyramids.name = "GizaPyramidsArea"
	pyramids.position = Vector3(-130, 0, 70)
	pyramids.set_script(load("res://scripts/pyramids_area.gd"))
	add_child(pyramids)


# اختيار وضع اللعب مع تسجيل دخول Google والتحقق الخادمي من هوية المؤسس.
var mode_selection_layer: CanvasLayer
var mode_selection_panel: PanelContainer
var mode_status_label: Label
var online_address_input: LineEdit
var game_mode_controls: VBoxContainer
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
	FounderAuthClient.founder_entitlement_received.connect(_on_founder_entitlement_received)
	FounderAuthClient.founder_entitlement_failed.connect(_on_founder_entitlement_failed)
	PlayerAccountAuthClient.request_finished.connect(_on_player_account_request_finished)
	PlayerAccountAuthClient.account_authenticated.connect(_on_player_account_authenticated)
	PlayerAccountAuthClient.session_access_token_changed.connect(_on_player_account_access_token_changed)
	PlayerAccountAuthClient.session_expired.connect(_on_player_account_session_expired)
	PlayerAccountAuthClient.player_profile_ready.connect(_on_player_profile_ready)
	PlayerAccountAuthClient.player_profile_failed.connect(_on_player_profile_failed)
	if PlayerAccountAuthClient.has_active_session():
		_on_player_account_access_token_changed(PlayerAccountAuthClient.get_access_token())
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
	player_account_button.text = "المتابعة باستخدام Google"
	player_account_button.custom_minimum_size.y = 40
	player_account_button.pressed.connect(_on_google_sign_in_pressed)
	content.add_child(player_account_button)
	if PlayerAccountAuthClient.has_active_session():
		player_account_button.text = "Google - الحساب متصل"

	var is_verified_founder := FounderIdentityManager.is_founder
	mode_status_label = Label.new()
	mode_status_label.text = "جارٍ التحقق من هوية المؤسس بالحساب الحالي..." if is_verified_founder else "اختر طريقة اللعب."
	mode_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(mode_status_label)


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

 
func _on_google_sign_in_pressed() -> void:
	if not PlayerAccountAuthClient.request_google_sign_in():
		if is_instance_valid(mode_status_label):
			mode_status_label.text = "تعذر بدء تسجيل الدخول باستخدام Google."
		return
	if is_instance_valid(mode_status_label):
		mode_status_label.text = "أكمل اختيار حساب Google المرتبط بشخصيتك الأصلية، ثم ستعود إلى اللعبة تلقائيًا."

func _on_player_account_request_finished(success: bool, message: String) -> void:
	if is_instance_valid(mode_status_label):
		mode_status_label.text = message

func _on_player_account_authenticated(user_id: String, email: String) -> void:
	if is_instance_valid(player_account_button):
		player_account_button.text = "Google - الحساب متصل"
	if is_instance_valid(mode_status_label):
		mode_status_label.text = "تم تسجيل الدخول بالحساب %s." % email
	if is_instance_valid(player_account_profile_label):
		player_account_profile_label.text = "معرّف الحساب: " + user_id

func _on_player_account_access_token_changed(access_token: String) -> void:
	var account_id := PlayerAccountAuthClient.get_user_id()
	var account_changed := ProfileConfigStore.get_active_account_id() != account_id
	if account_changed:
		if not ProfileConfigStore.begin_account_switch(account_id):
			push_error("Could not activate the isolated local profile for the authenticated account.")
			return
	else:
		if not ProfileConfigStore.set_active_account(account_id):
			push_error("Could not activate the isolated local profile for the authenticated account.")
			return
	WalletManager.initialize_wallet()
	PlayerSyncClient.set_session_access_token(access_token, account_id)
	if account_changed:
		call_deferred("_reload_scene_for_account_profile")
	else:
		ProfileConfigStore.complete_account_switch()
		if FounderIdentityManager.is_founder and FounderIdentityManager.founder_subject_id != account_id:
			FounderIdentityManager.clear_entitlement()
		# Founder status is checked automatically with the same Google-authenticated player session.
		FounderAuthClient.request_founder_entitlement_with_access_token(access_token)

func _reload_scene_for_account_profile() -> void:
	# Recreate scene managers so mission, achievement, daily, vehicle, and settings state
	# is loaded from the newly selected account file instead of stale in-memory data.
	get_tree().reload_current_scene()

func _on_player_account_session_expired() -> void:
	# A session may expire while the scene is being reloaded for an account switch.
	# Always release the save guard so the selected account profile remains usable offline.
	ProfileConfigStore.complete_account_switch()
	PlayerSyncClient.clear_session_access_token()
	if is_instance_valid(player_account_button):
		player_account_button.text = "المتابعة باستخدام Google"
	if is_instance_valid(mode_status_label):
		mode_status_label.text = "انتهت جلسة الحساب. سجّل الدخول مجددًا باستخدام Google."
	if GameModeManager.is_online_ready():
		_on_mode_status_changed("انتهت جلسة حساب اللاعب؛ تم إنهاء اتصال Online لحماية الحساب.")
		GameModeManager.disconnect_online()

func _on_player_profile_ready(_user_id: String, player_code: String, display_name: String) -> void:
	if is_instance_valid(player_account_profile_label):
		player_account_profile_label.text = "اسم اللاعب: %s\nرمز اللاعب: %s" % [display_name, player_code]

func _on_player_profile_failed(message: String) -> void:
	if is_instance_valid(player_account_profile_label):
		player_account_profile_label.text = message

func _on_founder_entitlement_received(payload: String, signature_base64: String) -> void:
	var parsed_claims: Variant = JSON.parse_string(payload)
	if not (parsed_claims is Dictionary) or str(parsed_claims.get("subject_id", "")) != PlayerAccountAuthClient.get_user_id():
		_on_founder_entitlement_failed("التذكرة لا تخص حساب اللاعب الحالي.")
		return
	if not FounderIdentityManager.accept_signed_entitlement(payload, signature_base64):
		_on_founder_entitlement_failed("رفض الجهاز التذكرة الموقعة أو تعذر حفظها بأمان.")
		return
	if is_instance_valid(game_mode_controls):
		game_mode_controls.visible = true
	if is_instance_valid(mode_status_label):
		mode_status_label.text = "تم التعرف على حساب المؤسس تلقائيًا من Google. يمكنك المتابعة."

func _on_founder_entitlement_failed(message: String) -> void:
	if is_instance_valid(game_mode_controls):
		game_mode_controls.visible = true
	if is_instance_valid(mode_status_label):
		mode_status_label.text = message + " سيتم الدخول كلاعب عادي دون صلاحيات مؤسس."

func _make_mode_panel_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.085, 0.11, 0.98)
	style.border_color = Color(0.72, 0.55, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	return style

func _select_offline_mode() -> void:
	_release_pending_city_reservation()
	GameModeManager.select_offline()
	_enter_selected_game_mode()

func _select_online_mode() -> void:
	if bool(ProjectSettings.get_setting("network/online/session_directory_enabled", false)):
		_request_city_session_matchmaking()
		return
	var address := online_address_input.text.strip_edges()
	if address.is_empty():
		mode_status_label.text = "أدخل اسم نطاق خادم WSS الآمن بعد تجهيز شهادة TLS."
		return
	mode_status_label.text = "جارٍ إنشاء اتصال آمن والتحقق من حساب اللاعب..."
	GameModeManager.connect_online(address, 2456)


func _request_city_session_matchmaking() -> void:
	if is_instance_valid(_city_matchmaking_request):
		mode_status_label.text = "جارٍ البحث عن جلسة مدينة مناسبة بالفعل."
		return
	var access_token := PlayerAccountAuthClient.get_access_token()
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if access_token.is_empty() or not base_url.begins_with("https://") or publishable_key.is_empty():
		mode_status_label.text = "سجّل الدخول أولًا، ثم أعد محاولة العثور على جلسة المدينة."
		return
	var preferred_region := str(ProjectSettings.get_setting("network/online/preferred_region", "egypt")).strip_edges().to_lower()
	var payload := {"action": "matchmake", "preferred_region": preferred_region}
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	_city_matchmaking_request = request
	request.request_completed.connect(_on_city_matchmaking_completed.bind(request))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + publishable_key,
		"Authorization: Bearer " + access_token
	])
	var error := request.request(base_url + "/functions/v1/city-session-directory", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_city_matchmaking_request = null
		request.queue_free()
		mode_status_label.text = "تعذر بدء البحث عن جلسة المدينة. حاول مرة أخرى."


func _on_city_matchmaking_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	if _city_matchmaking_request == request:
		_city_matchmaking_request = null
	if is_instance_valid(request):
		request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		mode_status_label.text = "تعذر العثور على جلسة مدينة متاحة أو أن خدمة الجلسات غير مفعلة."
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or str(parsed.get("status", "")) != "assigned":
		mode_status_label.text = "لا توجد جلسة مدينة متاحة حاليًا. حاول بعد قليل."
		return
	var endpoint := str(parsed.get("endpoint", "")).strip_edges()
	var reservation_id := str(parsed.get("reservation_id", "")).strip_edges()
	var reservation_regex := RegEx.new()
	reservation_regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	if reservation_regex.search(reservation_id) == null:
		mode_status_label.text = "استجابة دليل الجلسات غير صالحة؛ تم إيقاف الاتصال للحماية."
		return
	_pending_city_reservation_id = reservation_id
	if not endpoint.begins_with("wss://"):
		mode_status_label.text = "عنوان جلسة المدينة غير آمن؛ تم إيقاف الاتصال."
		_release_pending_city_reservation()
		return
	mode_status_label.text = "تم العثور على جلسة مناسبة. جارٍ الاتصال الآمن بالمدينة..."
	GameModeManager.connect_online(endpoint, 2456)


func _release_pending_city_reservation() -> void:
	if _pending_city_reservation_id.is_empty():
		return
	var reservation_id := _pending_city_reservation_id
	_pending_city_reservation_id = ""
	var access_token := PlayerAccountAuthClient.get_access_token()
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if access_token.is_empty() or not base_url.begins_with("https://") or publishable_key.is_empty():
		push_warning("تعذر تحرير حجز جلسة المدينة من العميل؛ سينتهي تلقائيًا عند انتهاء مهلته.")
		return
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(_on_city_reservation_release_completed.bind(request))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + publishable_key,
		"Authorization: Bearer " + access_token
	])
	var payload := {"action": "release", "reservation_id": reservation_id}
	var error := request.request(base_url + "/functions/v1/city-session-directory", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		push_warning("تعذر إرسال طلب تحرير حجز جلسة المدينة؛ سينتهي تلقائيًا عند انتهاء مهلته.")


func _on_city_reservation_release_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	if is_instance_valid(request):
		request.queue_free()
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not (parsed is Dictionary) or str(parsed.get("status", "")) not in ["released", "not_found"]:
		push_warning("لم يؤكد دليل الجلسات تحرير الحجز؛ ستنهيه مهلة الحجز تلقائيًا.")

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
	AuthoritativeGameServer.authenticate_player.rpc_id(1, access_token, _pending_city_reservation_id)


func _on_player_access_token_changed(access_token: String) -> void:
	if GameModeManager.is_online_ready() and not access_token.is_empty():
		AuthoritativeGameServer.authenticate_player.rpc_id(1, access_token, _pending_city_reservation_id)


func _on_remote_players_received(players: Array) -> void:
	if not GameModeManager.is_online_ready():
		return
	var active_peer_ids: Dictionary = {}
	for player_variant in players:
		if not (player_variant is Dictionary):
			continue
		var player_data: Dictionary = player_variant
		var peer_id := int(player_data.get("peer_id", 0))
		var player_position: Variant = player_data.get("position", null)
		var player_rotation: Variant = player_data.get("rotation_y", 0.0)
		var player_velocity: Variant = player_data.get("velocity", null)
		var active_emote := str(player_data.get("active_emote", ""))
		var emote_remaining := float(player_data.get("emote_remaining", 0.0))
		var is_sitting := bool(player_data.get("is_sitting", false))
		if peer_id <= 0 or peer_id == multiplayer.get_unique_id():
			continue
		if not (player_position is Vector3) or not (player_velocity is Vector3):
			continue
		if not (player_rotation is float or player_rotation is int):
			continue
		active_peer_ids[peer_id] = true
		var remote_view: Node3D = _remote_player_views.get(peer_id) as Node3D
		if not is_instance_valid(remote_view):
			remote_view = RemotePlayerVisual.new() as Node3D
			remote_view.name = "RemotePlayer_%d" % peer_id
			add_child(remote_view)
			_remote_player_views[peer_id] = remote_view
		var is_jet_ski_riding := bool(player_data.get("is_jet_ski_riding", false))
		var jet_ski_position: Variant = player_data.get("jet_ski_position", Vector3.ZERO)
		var jet_ski_rotation: Variant = player_data.get("jet_ski_rotation_y", 0.0)
		if not (jet_ski_position is Vector3) or not (jet_ski_rotation is float or jet_ski_rotation is int):
			is_jet_ski_riding = false
		remote_view.call("apply_snapshot", player_position, float(player_rotation), player_velocity, active_emote, emote_remaining, is_sitting, is_jet_ski_riding, jet_ski_position if jet_ski_position is Vector3 else Vector3.ZERO, float(jet_ski_rotation) if jet_ski_rotation is float or jet_ski_rotation is int else 0.0)
	for peer_id_variant in _remote_player_views.keys():
		var peer_id := int(peer_id_variant)
		if not active_peer_ids.has(peer_id):
			var stale_view := _remote_player_views[peer_id] as Node3D
			if is_instance_valid(stale_view):
				stale_view.queue_free()
			_remote_player_views.erase(peer_id)


func _clear_remote_player_views() -> void:
	for remote_view_variant in _remote_player_views.values():
		var remote_view := remote_view_variant as Node3D
		if is_instance_valid(remote_view):
			remote_view.queue_free()
	_remote_player_views.clear()


func _on_player_server_authenticated(success: bool, message: String) -> void:
	_on_mode_status_changed(message)
	if success and GameModeManager.confirm_online_authentication():
		_enter_selected_game_mode()
	else:
		GameModeManager.disconnect_online()

func _on_mode_disconnected() -> void:
	_clear_remote_player_views()
	if jet_ski_occupied:
		_exit_player_jet_ski()
	_release_pending_city_reservation()
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


func _create_european_vip_slot_machines(root: Node3D, room_center: Vector3) -> void:
	# استبدال مجسمات الـplaceholder الثلاثة بماكينات سلوت ذات مقاعد وتفاعل جلوس.
	var slot_script := load("res://scripts/arcade_slot_machine.gd") as Script
	if slot_script == null:
		push_warning("تعذر تحميل مشهد ماكينة السلوت الملكية.")
		return
	var machines := [
		{"id":"vip_royal_classic", "title":"Royal Classic", "subtitle":"ROYAL SLOT", "accent":Color(0.82,0.62,0.25), "body":Color(0.055,0.075,0.09), "offset":Vector3(-3.2,0,-1.35)},
		{"id":"vip_diamond_royale", "title":"Diamond Royale", "subtitle":"DIAMOND VIP", "accent":Color(0.55,0.82,0.92), "body":Color(0.035,0.07,0.12), "offset":Vector3(0,0,-1.35)},
		{"id":"vip_golden_crown", "title":"Golden Crown", "subtitle":"ROYAL JACKPOT", "accent":Color(0.92,0.72,0.28), "body":Color(0.12,0.055,0.035), "offset":Vector3(3.2,0,-1.35)}
	]
	for definition in machines:
		var machine := Node3D.new()
		machine.name = str(definition["id"])
		machine.set_script(slot_script)
		machine.set("machine_id", str(definition["id"]))
		machine.set("zone_id", "european_vip_casino")
		machine.set("machine_title", str(definition["title"]))
		machine.set("machine_subtitle", str(definition["subtitle"]))
		machine.set("accent_color", definition["accent"])
		machine.set("body_color", definition["body"])
		machine.position = room_center + definition["offset"]
		root.add_child(machine)
