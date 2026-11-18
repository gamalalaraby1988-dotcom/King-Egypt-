extends Node3D

const CityCollisionProfile = preload("res://scripts/city_collision_profile.gd")

@export var city_half_size: int = 3
@export var block_spacing: float = 24.0

var interior_root: Node3D = null
var interior_player: CharacterBody3D = null
var interior_return_transform: Transform3D
var interior_loading_layer: CanvasLayer
var interior_loading_label: Label
var interior_exit_button: Button
var interior_quick_travel_layer: CanvasLayer
var interior_quick_travel_panel: PanelContainer
var interior_quick_travel_buttons: Array[Button] = []
var apartment_customization_layer: CanvasLayer = null
var apartment_design_index := 0
var apartment_furniture_layer: CanvasLayer = null
var apartment_furniture_index := 0
var apartment_furniture_defaults: Dictionary = {}
var interior_transition_busy := false
var interior_loading_message_key := "interior_loading"
var interior_hidden_world_states: Dictionary = {}
var city_vehicle: CharacterBody3D = null
var vehicle_interaction_button: Button = null
var interaction_marker_target: Node3D = null
var interaction_target_marker: Node3D = null
var interaction_marker_elapsed := 0.0
var vehicle_summon_button: Button = null
var _vehicle_summon_check_elapsed := 0.0
var _vehicle_summon_position := Vector3.ZERO
var _vehicle_summon_available := false
var showroom_layer: CanvasLayer = null
var vehicle_occupied := false
var _shared_location_vehicle_following := false
var _shared_location_vehicle_target := Vector3.ZERO
var _shared_location_vehicle_route := PackedVector3Array()
var _shared_location_vehicle_route_index := 0
var _vehicle_key_was_down := false
var _player_saved_collision_layer := 1
var _player_saved_collision_mask := 1
const INTERIOR_WORLD_POSITION := Vector3(1000.0, 0.0, 1000.0)
const APARTMENT_SAVE_PATH := "user://kings_city_apartment.cfg"
const APARTMENT_DESIGN_NAMES := ["الملكي الذهبي", "النيل الفيروزي", "الأسواني الدافئ"]

const APARTMENT_FURNITURE_GROUPS := [
	{"label": "السجادة", "nodes": ["ApartmentLivingRug"]},
	{"label": "الأريكة", "nodes": ["ApartmentSofaBase", "ApartmentSofaBack"]},
	{"label": "طاولة الوسط", "nodes": ["ApartmentCoffeeTable"]},
	{"label": "التلفاز", "nodes": ["ApartmentTVConsole", "ApartmentTVScreen"]},
	{"label": "السفرة", "nodes": ["ApartmentDiningTable"]},
	{"label": "السرير", "nodes": ["ApartmentBedBase", "ApartmentBedMattress", "ApartmentBedHeadboard"]}
]

func _ready() -> void:
	_create_ground()
	_create_city()
	_create_desert_camp()
	_create_pyramids_area()
	_create_party_station()
	_create_city_signage()
	_create_mobile_hud()
	var key_light := get_node_or_null("DirectionalLight3D")
	if key_light:
		key_light.add_to_group("quality_shadow_light")
	_create_interactive_buildings()
	_create_desert_camp_access_road()
	_create_king_mountain_route()
	_create_decorative_mountain_temple()
	_create_interior_transition_ui()
	_create_player_vehicle()
	# دخول مباشر للمدينة في نسخة الاختبار؛ شاشة OTP المؤقتة معطلة حتى تجهيز نظام الدخول النهائي.
	_create_character_selection_ui()



func _create_king_mountain_route() -> void:
	var route := Node3D.new()
	route.name = "KingsMountainRoute"
	route.set_script(load("res://scripts/king_mountain_route.gd"))
	add_child(route)


func _create_decorative_mountain_temple() -> void:
	var packed := load("res://scenes/buildings/decorative_temple_building.tscn") as PackedScene
	if packed == null:
		push_warning("تعذر تحميل المعبد الفرعوني الزخرفي.")
		return
	var temple := packed.instantiate() as Node3D
	if temple == null:
		push_warning("تعذر إنشاء مشهد المعبد الفرعوني الزخرفي.")
		return
	temple.name = "DecorativeMountainTemple"
	# موضع جانبي آمن: شرق ساحة الانتقال وخارج مسار الصعود والكتل الصخرية.
	# الواجهة تدور غربًا نحو منطقة البوابة، دون سد الطريق أو الساحة.
	temple.position = Vector3(103.0, -0.16, 119.0)
	temple.rotation.y = PI * 0.5
	add_child(temple)


func _create_character_selection_ui() -> void:
	# شاشة معاينة الشخصيات الجاهزة؛ الاختيار النهائي ينتظر الأصول وخدمة الملف الشخصي.
	var selection_script := load("res://scripts/character_selection_ui.gd") as Script
	if selection_script == null:
		push_warning("تعذر تحميل واجهة اختيار الشخصيات.")
		return
	var selection_ui := CanvasLayer.new()
	selection_ui.name = "CharacterSelectionUI"
	selection_ui.set_script(selection_script)
	selection_ui.set("player", get_node_or_null("Player"))
	add_child(selection_ui)


func _create_auth_login_panel() -> void:
	# واجهة مصادقة تجريبية مستقلة؛ لا تغيّر بيانات اللاعب أو تفتح صلاحيات المؤسس.
	var panel_script := load("res://scripts/auth_login_panel.gd") as Script
	if panel_script == null:
		push_warning("تعذر تحميل واجهة تسجيل الدخول التجريبية.")
		return
	var auth_panel := CanvasLayer.new()
	auth_panel.name = "TestEmailAuthPanel"
	auth_panel.set_script(panel_script)
	add_child(auth_panel)


static func is_position_inside_city_bounds(position: Vector3, half_extent: float = 90.0) -> bool:
	return absf(position.x) <= half_extent and absf(position.z) <= half_extent

static func is_vehicle_summon_position_road_safe(position: Vector3) -> bool:
	# اترك مسافة أمان حول الشارعين الرئيسيين.
	if absf(position.x) <= 8.0 or absf(position.z) <= 8.0:
		return false
	# تجنب أيضًا الشوارع الفرعية عند x/z = ±24 و±72.
	for road_center in [-72.0, -24.0, 24.0, 72.0]:
		if absf(position.x - road_center) <= 5.5 or absf(position.z - road_center) <= 5.5:
			return false
	return true

func _make_vehicle_summon_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _find_suitable_vehicle_summon_position(player: CharacterBody3D) -> Variant:
	if not is_instance_valid(player):
		return null
	# استدعِ السيارة بمحاذاة اللاعب وعلى أقرب جانب خالٍ، مع احترام اتجاه جسمه.
	# الطرق صالحة لوقوف السيارة؛ مانع التصادم هو الذي يستبعد المباني والعوائق.
	var basis := player.global_transform.basis
	var right := basis.x
	var forward := -basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	var candidates: Array[Vector3] = []
	# ابدأ بالجانبين الأقرب جدًا للاعب، ثم وسّع البحث فقط عند وجود عائق.
	for distance in [2.2, 2.6, 3.0, 3.4, 3.8]:
		var offsets := [
			right * distance,
			-right * distance,
			forward * distance,
			-forward * distance,
			(right + forward).normalized() * distance,
			(-right + forward).normalized() * distance,
			(right - forward).normalized() * distance,
			(-right - forward).normalized() * distance
		]
		for offset in offsets:
			candidates.append(player.global_position + offset)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 1.9, 5.2)
	var space_state := get_world_3d().direct_space_state
	for candidate in candidates:
		if not is_position_inside_city_bounds(candidate, 85.0):
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(Vector3.UP, player.global_rotation.y), candidate + Vector3.UP * 1.0)
		query.collision_mask = 1 | 8 # عناصر المدينة الصلبة والموظفون فقط.
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var excluded: Array[RID] = [player.get_rid()]
		if is_instance_valid(city_vehicle):
			excluded.append(city_vehicle.get_rid())
		query.exclude = excluded
		if space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return null

func _refresh_vehicle_summon_availability(player: CharacterBody3D) -> void:
	var candidate: Variant = _find_suitable_vehicle_summon_position(player)
	_vehicle_summon_available = candidate is Vector3
	if _vehicle_summon_available:
		_vehicle_summon_position = candidate
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.disabled = not _vehicle_summon_available

func _process(_delta: float) -> void:
	# المركبات تخص مساحة المدينة؛ أخفِ أدواتها طوال الانتقال أو الوجود داخل مبنى.
	if interior_transition_busy or is_instance_valid(interior_root):
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		_update_interaction_target_marker(null)
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		if is_instance_valid(showroom_layer):
			showroom_layer.visible = false
		return
	if is_instance_valid(showroom_layer):
		showroom_layer.visible = true
	if vehicle_occupied and (not is_instance_valid(city_vehicle) or not is_instance_valid(get_node_or_null("Player"))):
		_recover_vehicle_occupancy()
	_update_shared_location_vehicle_follow()
	if vehicle_occupied:
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		_update_interaction_target_marker(null)
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.visible = false
		if is_instance_valid(vehicle_interaction_button):
			vehicle_interaction_button.visible = false
		_update_interaction_target_marker(null)
		return
	var player_inside_city := is_position_inside_city_bounds(player.global_position)
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = player_inside_city
		vehicle_summon_button.text = "إحضار السيارة" if CityLanguage.get_language() == "ar" else "Call vehicle"
		_vehicle_summon_check_elapsed += _delta
		if _vehicle_summon_check_elapsed >= 0.25:
			_vehicle_summon_check_elapsed = 0.0
			_refresh_vehicle_summon_availability(player)
	# أولوية العلامة: محطة الحفلة، ثم أقرب عنصر مدينة يملك مسار تفاعل قائمًا، ثم السيارة.
	var nearby_party_station := _get_nearby_party_station(player)
	var mission_manager := get_node_or_null("MissionManager")
	var nearby_city_interactable: Node3D = null
	if is_instance_valid(mission_manager):
		var manager_target: Variant = mission_manager.get("nearest_interactable")
		if manager_target is Node3D and is_instance_valid(manager_target):
			nearby_city_interactable = manager_target
	var close_enough := is_instance_valid(city_vehicle) and player.global_position.distance_to(city_vehicle.global_position) <= 5.0
	var interaction_target: Node3D = nearby_party_station if is_instance_valid(nearby_party_station) else (nearby_city_interactable if is_instance_valid(nearby_city_interactable) else (city_vehicle if close_enough else null))
	_update_interaction_target_marker(interaction_target)
	# زر المركبة الإضافي مخصص للمحطة والسيارة فقط؛ بقية عناصر المدينة تستخدم زر MissionManager القائم.
	if is_instance_valid(vehicle_interaction_button):
		# كل تفاعلات اللاعب تمر عبر زر MissionManager الموحد.
		vehicle_interaction_button.visible = false


func _update_interaction_target_marker(target: Node3D) -> void:
	if not is_instance_valid(target):
		if is_instance_valid(interaction_target_marker):
			interaction_target_marker.visible = false
		interaction_marker_target = null
		return
	if not is_instance_valid(interaction_target_marker):
		interaction_target_marker = Node3D.new()
		interaction_target_marker.name = "GlowingInteractionPoint"
		var dot := MeshInstance3D.new()
		dot.name = "GlowDot"
		var dot_mesh := SphereMesh.new()
		dot_mesh.radius = 0.16
		dot_mesh.height = 0.32
		dot.mesh = dot_mesh
		var dot_material := StandardMaterial3D.new()
		dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot_material.albedo_color = Color(1.0, 0.78, 0.25, 1.0)
		dot_material.emission_enabled = true
		dot_material.emission = Color(1.0, 0.62, 0.12)
		dot_material.emission_energy_multiplier = 2.4
		dot.material_override = dot_material
		interaction_target_marker.add_child(dot)
		var halo := MeshInstance3D.new()
		halo.name = "GlowHalo"
		var halo_mesh := TorusMesh.new()
		halo_mesh.inner_radius = 0.22
		halo_mesh.outer_radius = 0.29
		halo_mesh.rings = 24
		halo_mesh.ring_segments = 8
		halo.mesh = halo_mesh
		halo.rotation.x = PI * 0.5
		halo.position.y = -0.12
		var halo_material := StandardMaterial3D.new()
		halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_material.albedo_color = Color(1.0, 0.72, 0.24, 0.38)
		halo_material.emission_enabled = true
		halo_material.emission = Color(1.0, 0.58, 0.12)
		halo_material.emission_energy_multiplier = 1.2
		halo.material_override = halo_material
		interaction_target_marker.add_child(halo)
		var glow := OmniLight3D.new()
		glow.name = "GlowLight"
		glow.light_color = Color(1.0, 0.72, 0.24)
		glow.light_energy = 0.65
		glow.omni_range = 1.8
		interaction_target_marker.add_child(glow)
	if is_instance_valid(interaction_marker_target) and interaction_marker_target != target:
		if interaction_target_marker.get_parent() == interaction_marker_target:
			interaction_marker_target.remove_child(interaction_target_marker)
	if interaction_target_marker.get_parent() != target:
		if is_instance_valid(interaction_target_marker.get_parent()):
			interaction_target_marker.get_parent().remove_child(interaction_target_marker)
		target.add_child(interaction_target_marker)
	interaction_marker_target = target
	interaction_marker_elapsed += get_process_delta_time()
	var pulse := (sin(interaction_marker_elapsed * 3.2) + 1.0) * 0.5
	interaction_target_marker.position = Vector3(0.0, (2.0 if target.is_in_group("party_stations") else 1.65) + pulse * 0.07, 0.0)
	var dot := interaction_target_marker.get_node_or_null("GlowDot") as MeshInstance3D
	if is_instance_valid(dot):
		var dot_scale := 0.94 + pulse * 0.12
		dot.scale = Vector3.ONE * dot_scale
	var halo_node := interaction_target_marker.get_node_or_null("GlowHalo") as MeshInstance3D
	if is_instance_valid(halo_node):
		var halo_scale := 0.94 + pulse * 0.14
		halo_node.scale = Vector3(halo_scale, halo_scale, halo_scale)
	var glow_node := interaction_target_marker.get_node_or_null("GlowLight") as OmniLight3D
	if is_instance_valid(glow_node):
		glow_node.light_energy = 0.45 + pulse * 0.28
	interaction_target_marker.visible = true


func _unhandled_input(event: InputEvent) -> void:
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

	# معرض المركبات منفصل عن الاستدعاء والملكية؛ لا ينفذ شراء أو يغيّر المركبة المختارة.
	showroom_layer = CanvasLayer.new()
	showroom_layer.name = "VehicleShowroomUI"
	showroom_layer.set_script(load("res://scripts/vehicle_showroom_ui.gd"))
	add_child(showroom_layer)

	vehicle_summon_button = Button.new()
	vehicle_summon_button.name = "VehicleSummonButton"
	vehicle_summon_button.text = "إحضار السيارة"
	vehicle_summon_button.disabled = true
	vehicle_summon_button.custom_minimum_size = Vector2(190, 58)
	vehicle_summon_button.anchor_left = 0.0
	vehicle_summon_button.anchor_right = 0.0
	vehicle_summon_button.anchor_top = 0.0
	vehicle_summon_button.anchor_bottom = 0.0
	vehicle_summon_button.offset_left = 24
	vehicle_summon_button.offset_right = 214
	vehicle_summon_button.offset_top = 24
	vehicle_summon_button.offset_bottom = 82
	vehicle_summon_button.add_theme_stylebox_override("normal", _make_vehicle_summon_style(Color(0.04, 0.34, 0.78)))
	vehicle_summon_button.add_theme_stylebox_override("hover", _make_vehicle_summon_style(Color(0.08, 0.46, 0.94)))
	vehicle_summon_button.add_theme_stylebox_override("pressed", _make_vehicle_summon_style(Color(0.02, 0.23, 0.58)))
	vehicle_summon_button.add_theme_stylebox_override("disabled", _make_vehicle_summon_style(Color(0.24, 0.27, 0.31)))
	vehicle_summon_button.pressed.connect(_summon_player_vehicle)
	layer.add_child(vehicle_summon_button)

	vehicle_interaction_button = Button.new()
	vehicle_interaction_button.name = "VehicleInteractionButton"
	vehicle_interaction_button.text = "ركوب السيارة"
	vehicle_interaction_button.custom_minimum_size = Vector2(190, 58)
	vehicle_interaction_button.anchor_left = 0.5
	vehicle_interaction_button.anchor_right = 0.5
	vehicle_interaction_button.anchor_top = 1.0
	vehicle_interaction_button.anchor_bottom = 1.0
	vehicle_interaction_button.offset_left = -95
	vehicle_interaction_button.offset_right = 95
	vehicle_interaction_button.offset_top = -150
	vehicle_interaction_button.offset_bottom = -92
	vehicle_interaction_button.visible = false
	vehicle_interaction_button.pressed.connect(_toggle_vehicle_use)
	vehicle_interaction_button.visible = false
	layer.add_child(vehicle_interaction_button)

func _summon_player_vehicle() -> void:
	if interior_transition_busy or is_instance_valid(interior_root) or vehicle_occupied:
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or not is_position_inside_city_bounds(player.global_position):
		return
	var safe_position: Variant = _find_suitable_vehicle_summon_position(player)
	if not safe_position is Vector3:
		_vehicle_summon_available = false
		if is_instance_valid(vehicle_summon_button):
			vehicle_summon_button.disabled = true
		return
	_vehicle_summon_position = safe_position
	_vehicle_summon_available = true
	var selected_vehicle_id := VehicleStoreManager.get_selected_vehicle_id()
	if not VehicleStoreManager.has_vehicle(selected_vehicle_id):
		push_warning("لا يمكن استدعاء مركبة غير مملوكة.")
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
		CityCollisionProfile.apply_owned_vehicle_parked_collision(city_vehicle, get_node_or_null("Player") as CharacterBody3D)
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
	# Use the freshly validated clear parking position represented by the blue button.
	var summon_position: Vector3 = _vehicle_summon_position
	summon_position.y = player.global_position.y
	city_vehicle.global_position = summon_position
	city_vehicle.global_rotation.y = player.global_rotation.y
	city_vehicle.velocity = Vector3.ZERO
	CityCollisionProfile.apply_owned_vehicle_parked_collision(city_vehicle, player)
	city_vehicle.call("set_drive", false)
	city_vehicle.call("set_brake", true)
	city_vehicle.call("set_reverse", false)
	city_vehicle.call("set_steering", 0.0)
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = true

func get_shared_location_navigation_actor() -> Node3D:
	if vehicle_occupied and is_instance_valid(city_vehicle):
		return city_vehicle
	return get_node_or_null("Player") as Node3D


func is_shared_location_navigation_active() -> bool:
	if _shared_location_vehicle_following:
		return true
	var mission_manager := get_node_or_null("MissionManager")
	return is_instance_valid(mission_manager) and mission_manager.has_method("is_shared_location_navigation_active") and bool(mission_manager.call("is_shared_location_navigation_active"))


func begin_shared_location_navigation(destination: Vector3) -> bool:
	if interior_transition_busy or is_instance_valid(interior_root):
		return false
	if absf(destination.x) > 250.0 or absf(destination.z) > 250.0 or destination.y < -10.0 or destination.y > 100.0:
		return false
	var mission_manager := get_node_or_null("MissionManager")
	if not is_instance_valid(mission_manager) or not mission_manager.has_method("can_start_shared_location_navigation"):
		return false
	if not bool(mission_manager.call("can_start_shared_location_navigation")):
		return false
	if vehicle_occupied:
		if not is_instance_valid(city_vehicle) or not city_vehicle.has_method("set_auto_navigation_controls"):
			return false
		if not mission_manager.has_method("build_shared_location_route_from"):
			return false
		# ابنِ المسار في متغير مؤقت حتى لا تمحو محاولة فاشلة متابعةً جارية.
		var requested_vehicle_route: PackedVector3Array = mission_manager.call("build_shared_location_route_from", city_vehicle.global_position, destination)
		if requested_vehicle_route.size() < 2:
			return false
		# ألغِ أي متابعة مشي قديمة فقط بعد نجاح بناء مسار المركبة الجديد.
		mission_manager.call("cancel_shared_location_navigation")
		_shared_location_vehicle_route = requested_vehicle_route
		_shared_location_vehicle_target = destination
		_shared_location_vehicle_route_index = 0
		_shared_location_vehicle_following = true
		mission_manager.call("show_shared_location_marker", destination)
		city_vehicle.call("set_auto_navigation_controls", 0.0, 0.0)
		return true
	if not mission_manager.has_method("navigate_to_landmark"):
		return false
	return bool(mission_manager.call("navigate_to_landmark", "shared_location", destination))


func _clear_shared_location_vehicle_follow() -> void:
	if is_instance_valid(city_vehicle) and city_vehicle.has_method("clear_auto_navigation_controls"):
		city_vehicle.call("clear_auto_navigation_controls")
	_shared_location_vehicle_following = false
	_shared_location_vehicle_target = Vector3.ZERO
	_shared_location_vehicle_route = PackedVector3Array()
	_shared_location_vehicle_route_index = 0
	var mission_manager := get_node_or_null("MissionManager")
	if is_instance_valid(mission_manager) and mission_manager.has_method("hide_shared_location_marker"):
		mission_manager.call("hide_shared_location_marker")


func _update_shared_location_vehicle_follow() -> void:
	if not _shared_location_vehicle_following:
		return
	if not vehicle_occupied or not is_instance_valid(city_vehicle):
		_clear_shared_location_vehicle_follow()
		return
	var mission_manager := get_node_or_null("MissionManager")
	if is_instance_valid(mission_manager) and (bool(mission_manager.get("mission_running")) or bool(mission_manager.get("job_running"))):
		_clear_shared_location_vehicle_follow()
		return
	if bool(city_vehicle.get("auto_navigation_interrupted")):
		_clear_shared_location_vehicle_follow()
		return
	if is_instance_valid(mission_manager) and mission_manager.has_method("is_position_near_shared_location_route"):
		var remains_on_route := bool(mission_manager.call(
			"is_position_near_shared_location_route",
			city_vehicle.global_position,
			_shared_location_vehicle_route,
			_shared_location_vehicle_route_index,
			8.0
		))
		if not remains_on_route:
			var recalculated_route: PackedVector3Array = mission_manager.call(
				"build_shared_location_route_from",
				city_vehicle.global_position,
				_shared_location_vehicle_target
			)
			if recalculated_route.size() < 2:
				_clear_shared_location_vehicle_follow()
				return
			_shared_location_vehicle_route = recalculated_route
			_shared_location_vehicle_route_index = 0
	while _shared_location_vehicle_route_index < _shared_location_vehicle_route.size():
		var waypoint: Vector3 = _shared_location_vehicle_route[_shared_location_vehicle_route_index]
		var waypoint_delta := waypoint - city_vehicle.global_position
		waypoint_delta.y = 0.0
		# نقاط الانعطاف تُجتاز بهامش 3 أمتار، لكن الوجهة النهائية تحتاج دقة 2 متر مثل المشي.
		var final_waypoint := _shared_location_vehicle_route_index == _shared_location_vehicle_route.size() - 1
		var waypoint_reach_distance := 2.0 if final_waypoint else 3.0
		if waypoint_delta.length() > waypoint_reach_distance:
			break
		_shared_location_vehicle_route_index += 1
	if _shared_location_vehicle_route_index >= _shared_location_vehicle_route.size():
		_clear_shared_location_vehicle_follow()
		return
	var direction: Vector3 = _shared_location_vehicle_route[_shared_location_vehicle_route_index] - city_vehicle.global_position
	direction.y = 0.0
	var desired_angle := atan2(direction.x, -direction.z)
	var heading_error := wrapf(desired_angle - city_vehicle.global_rotation.y, -PI, PI)
	var steering := clampf(heading_error * 1.15, -1.0, 1.0)
	var speed := 2.8 if absf(heading_error) < 0.85 else 1.6
	city_vehicle.call("set_auto_navigation_controls", speed, steering)

func _toggle_vehicle_use() -> void:
	if interior_transition_busy or is_instance_valid(interior_root):
		return
	if vehicle_occupied:
		_exit_player_vehicle()
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		return
	var nearby_party_station := _get_nearby_party_station(player)
	if is_instance_valid(nearby_party_station):
		_show_party_station_notice(nearby_party_station)
		return
	if not is_instance_valid(city_vehicle) or player.global_position.distance_to(city_vehicle.global_position) > 5.0:
		return
	if player.get("animal_riding") == true or player.get("sitting") == true:
		return
	# لا نحتفظ بمسار المشي القديم عند الانتقال إلى الاسكوتر.
	var mission_manager := get_node_or_null("MissionManager")
	if is_instance_valid(mission_manager) and mission_manager.has_method("cancel_shared_location_navigation"):
		mission_manager.call("cancel_shared_location_navigation")
	_set_mobile_hud_active(false)
	var touch_hud := get_node_or_null("MobileHUD/TouchControls") as Control
	if is_instance_valid(touch_hud):
		touch_hud.set("vehicle_control_target", city_vehicle)
		touch_hud.visible = true
	vehicle_occupied = true
	CityCollisionProfile.apply_driven_vehicle_collision(city_vehicle)
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
	# أزرار STEER/DRIVE/BRAKE غير معتمدة؛ القيادة تتم بعصا الحركة المعتادة.
	var vehicle_hud := city_vehicle.get_node_or_null("VehicleHUDLayer/VehicleHUD") as Control
	if is_instance_valid(vehicle_hud):
		if vehicle_hud.has_method("_clear_controls"):
			vehicle_hud.call("_clear_controls")
		vehicle_hud.visible = false
	var vehicle_camera := city_vehicle.get_node_or_null("VehicleCameraPivot/SpringArm3D/VehicleCamera") as Camera3D
	if is_instance_valid(vehicle_camera):
		vehicle_camera.current = true
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.visible = false

func _recover_vehicle_occupancy() -> void:
	# لا تترك حالة الركوب أو متابعة الموقع عالقة إذا حُذفت السيارة أو اللاعب.
	_clear_shared_location_vehicle_follow()
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
		if is_instance_valid(city_vehicle):
			CityCollisionProfile.apply_owned_vehicle_parked_collision(city_vehicle, player)
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
		vehicle_interaction_button.text = "ركوب السيارة" if CityLanguage.get_language() == "ar" else "Enter vehicle"
	if is_instance_valid(vehicle_summon_button):
		vehicle_summon_button.visible = is_instance_valid(player)

func _exit_player_vehicle() -> void:
	if not vehicle_occupied:
		return
	# النزول من المركبة ينهي متابعة الموقع بالكامل قبل تبديل وسيلة الحركة.
	_clear_shared_location_vehicle_follow()
	var player := get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player) or not is_instance_valid(city_vehicle):
		return
	var side := city_vehicle.global_transform.basis.x.normalized()
	var exit_position := city_vehicle.global_position + side * 2.1 + Vector3.UP * 0.15
	CityCollisionProfile.apply_owned_vehicle_parked_collision(city_vehicle, player)
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
	var touch_hud := get_node_or_null("MobileHUD/TouchControls") as Control
	if is_instance_valid(touch_hud):
		touch_hud.set("vehicle_control_target", null)
	_set_mobile_hud_active(true)
	if is_instance_valid(vehicle_interaction_button):
		vehicle_interaction_button.text = "ركوب السيارة" if CityLanguage.get_language() == "ar" else "Enter vehicle"
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
	_create_interior_quick_travel_ui()
	CityLanguage.language_changed.connect(_refresh_interior_ui_language)

func _create_interior_quick_travel_ui() -> void:
	interior_quick_travel_layer = CanvasLayer.new()
	interior_quick_travel_layer.name = "InteriorQuickTravel"
	interior_quick_travel_layer.layer = 31
	add_child(interior_quick_travel_layer)
	interior_quick_travel_panel = PanelContainer.new()
	interior_quick_travel_panel.name = "QuickTravelPanel"
	interior_quick_travel_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	interior_quick_travel_panel.position = Vector2(-330, -220)
	interior_quick_travel_panel.custom_minimum_size = Vector2(300, 440)
	interior_quick_travel_panel.visible = false
	interior_quick_travel_layer.add_child(interior_quick_travel_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	interior_quick_travel_panel.add_child(content)
	var heading := Label.new()
	heading.text = "𓂀  التنقل السريع 𓂀"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(0.88, 0.68, 0.30))
	content.add_child(heading)
	var entries := [
		["𓉴  الأهرامات والمخيم الملكي", true],
		["🏠  الشقة", true],
		["𓉐  بوابة صعود الجبل", true],
		["⚜  الميدان", true],
		["⛵  السفينة", true],
		["🚪  الخروج خارج المبنى", true],
 	]
	for index in range(entries.size()):
		var entry: Array = entries[index]
		var travel_button := Button.new()
		travel_button.text = str(entry[0])
		travel_button.custom_minimum_size = Vector2(270, 48)
		travel_button.disabled = not bool(entry[1])
		travel_button.pressed.connect(_on_interior_quick_travel_selected.bind(index))
		content.add_child(travel_button)
		interior_quick_travel_buttons.append(travel_button)
	var note := Label.new()
	note.text = "الشقة نموذج خاص محفوظ محليًا على هذا الجهاز. زيارة الأصدقاء تحتاج خادم حسابات واتصالًا شبكيًا."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	content.add_child(note)
	var close_menu_button := Button.new()
	close_menu_button.text = "إغلاق"
	close_menu_button.custom_minimum_size = Vector2(270, 42)
	close_menu_button.pressed.connect(_hide_interior_quick_travel_menu)
	content.add_child(close_menu_button)

func show_interior_quick_travel_menu() -> void:
	if interior_transition_busy or not is_instance_valid(interior_quick_travel_panel):
		return
	if not is_instance_valid(interior_root):
		return
	interior_quick_travel_panel.visible = true

func _hide_interior_quick_travel_menu() -> void:
	if is_instance_valid(interior_quick_travel_panel):
		interior_quick_travel_panel.visible = false

func _on_interior_quick_travel_selected(index: int) -> void:
	if index == 0:
		_hide_interior_quick_travel_menu()
		await return_from_building_interior(Vector3(60.0, 0.15, 60.0))
	elif index == 1:
		_hide_interior_quick_travel_menu()
		await _open_private_apartment()
	elif index == 2:
		_hide_interior_quick_travel_menu()
		await _open_quick_travel_destination("قمة الملوك", "summit")
	elif index == 3:
		_hide_interior_quick_travel_menu()
		await _open_quick_travel_destination("الميدان الملكي", "plaza")
	elif index == 4:
		_hide_interior_quick_travel_menu()
		await _open_quick_travel_destination("السفينة الملكية", "ship")
	elif index == 5:
		_hide_interior_quick_travel_menu()
		await return_from_building_interior()
	else:
		return

func _open_quick_travel_destination(destination_name: String, destination_kind: String) -> void:
	var body := interior_player
	if not is_instance_valid(body) or not is_instance_valid(interior_root) or interior_transition_busy:
		return
	await return_from_building_interior()
	if not is_inside_tree() or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if destination_kind == "summit":
		# الوصول إلى الجهة الغربية من البوابة بعد تدويرها لتواجه وصلة الطريق القادمة من الغرب.
		body.global_position = Vector3(86.5, 1.2, 99.0)
		body.velocity = Vector3.ZERO
		body.rotation.y = -PI * 0.5
		body.set_physics_process(true)
		return
	interior_transition_busy = true
	interior_player = body
	interior_return_transform = body.global_transform
	body.set_physics_process(false)
	_show_interior_loading(false)
	_set_city_world_hidden(true)
	_create_destination_scene(destination_name, destination_kind)
	body.global_position = INTERIOR_WORLD_POSITION + Vector3(0, 1.05, 6.0)
	body.velocity = Vector3.ZERO
	body.rotation.y = PI
	body.set_physics_process(true)
	interior_transition_busy = false
	_show_interior_loading(true)


func _create_summit_edge_barriers(root: Node3D, wall_color: Color, rail_color: Color) -> void:
	# الحاجز الحجري المرتفع يتحمل اصطدام اللاعب والمركبة، والسياج الذهبي العلوي يكمل الحماية.
	var wall_height := 1.55
	var wall_thickness := 0.7
	var wall_center_y := wall_height * 0.5
	var rail_height := 0.22
	var rail_center_y := wall_height + rail_height * 0.5 - 0.05
	var edge_offset := 14.65
	var edge_length := 29.3
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		var side_name := "Left" if side < 0.0 else "Right"
		_create_box(root, "SummitSideSafetyWall_" + side_name, Vector3(wall_thickness, wall_height, edge_length), Vector3(side * edge_offset, wall_center_y, 0.0), wall_color, true)
		_create_box(root, "SummitSideGoldRail_" + side_name, Vector3(0.22, rail_height, edge_length), Vector3(side * edge_offset, rail_center_y, 0.0), rail_color, true)
		# اترك فتحة مركزية واسعة متصلة بطريق الصعود، مع حماية جانبي المدخل.
		var entrance_segment_length := edge_length * 0.36
		var entrance_segment_center := edge_length * 0.5 - entrance_segment_length * 0.5
		_create_box(root, "SummitFrontSafetyWall_" + side_name, Vector3(entrance_segment_length, wall_height, wall_thickness), Vector3(side * entrance_segment_center, wall_center_y, -edge_offset), wall_color, true)
		_create_box(root, "SummitFrontGoldRail_" + side_name, Vector3(entrance_segment_length, rail_height, 0.22), Vector3(side * entrance_segment_center, rail_center_y, -edge_offset), rail_color, true)
		_create_box(root, "SummitRearSafetyWall_" + side_name, Vector3(edge_length * 0.5, wall_height, wall_thickness), Vector3(side * edge_length * 0.25, wall_center_y, edge_offset), wall_color, true)
		_create_box(root, "SummitRearGoldRail_" + side_name, Vector3(edge_length * 0.5, rail_height, 0.22), Vector3(side * edge_length * 0.25, rail_center_y, edge_offset), rail_color, true)


func _create_destination_scene(destination_name: String, destination_kind: String) -> void:
	if is_instance_valid(interior_root):
		interior_root.queue_free()
	interior_root = Node3D.new()
	interior_root.name = "Generated_" + destination_kind.capitalize()
	interior_root.position = INTERIOR_WORLD_POSITION
	add_child(interior_root)
	var root := interior_root
	var stone := Color(0.66, 0.56, 0.40)
	var dark_stone := Color(0.34, 0.29, 0.23)
	var gold := Color(0.88, 0.68, 0.27)
	if destination_kind == "summit":
		# قمة الملوك ساحة مشاهدة مفتوحة فوق الجبل، وليست قصرًا أو مبنى مغلقًا.
		var summit_stone := Color(0.43, 0.38, 0.30)
		var rail_gold := Color(0.76, 0.58, 0.27)
		_create_box(root, "SummitRockPlatform", Vector3(38, 1.4, 38), Vector3(0, -0.7, 0), summit_stone, true)
		_create_box(root, "SummitOpenViewingTerrace", Vector3(30, 0.35, 30), Vector3(0, 0.15, 0), stone, true)
		# حواجز حماية صلبة ومتصلة على الجهات الأربع؛ الواجهة تبقى مفتوحة بصريًا فوق الحاجز.
		_create_summit_edge_barriers(root, dark_stone, rail_gold)
		# أعمدة ذهبية زخرفية عند أطراف الشرفة، لا تسد خط النظر.
		for x in [-12.0, 12.0]:
			for z in [-11.0, 10.0]:
				_create_box(root, "SummitTerracePillar_%d_%d" % [int(x), int(z)], Vector3(0.85, 4.0, 0.85), Vector3(x, 2.15, z), gold, true)
		# قاعدة معبد ومسلة جانبية كعلامة ملكية، مع إبقاء منتصف الشرفة للمشاهدة.
		_create_box(root, "SummitTempleBase", Vector3(7.0, 0.65, 4.0), Vector3(-9.0, 0.65, -7.0), dark_stone, true)
		_create_box(root, "SummitTempleUpper", Vector3(5.5, 0.65, 3.2), Vector3(-9.0, 1.3, -7.0), stone, true)
		_create_box(root, "SummitObelisk", Vector3(0.65, 4.5, 0.65), Vector3(-9.0, 3.85, -7.0), gold, true)
		# مقاعد على الجانبين بعيدًا عن مسار الحركة وخط المشاهدة المركزي.
		for x in [-10.0, 10.0]:
			for z in [-1.0, 6.0]:
				_create_box(root, "SummitViewingBench_%d_%d" % [int(x), int(z)], Vector3(3.2, 0.5, 0.8), Vector3(x, 0.48, z), dark_stone, true)
		# أفق بصري بعيد يوضح المدينة والبحر والأهرامات من الشرفة المفتوحة.
		_create_box(root, "SummitDistantSea", Vector3(180, 0.25, 34), Vector3(0, -1.4, -86), Color(0.07, 0.25, 0.38))
		for i in range(9):
			var skyline_x: float = -48.0 + float(i) * 12.0
			var skyline_h: float = 7.0 + float((i * 7) % 5) * 2.0
			_create_box(root, "SummitDistantCity_%d" % i, Vector3(7.0, skyline_h, 5.0), Vector3(skyline_x, skyline_h * 0.5 - 1.2, -59.0), Color(0.43, 0.39, 0.32))
		for i in range(3):
			var pyramid_x: float = -25.0 + float(i) * 25.0
			_create_box(root, "SummitDistantPyramidBase_%d" % i, Vector3(11.0, 0.25, 8.0), Vector3(pyramid_x, -1.0, -69.0), gold)
			_create_box(root, "SummitDistantPyramidBody_%d" % i, Vector3(7.0, 9.0, 5.5), Vector3(pyramid_x, 3.5, -69.0), Color(0.69, 0.57, 0.39))
		_create_box(root, "SummitViewMarker", Vector3(9, 0.12, 0.22), Vector3(0, 0.42, -5.0), gold)
	elif destination_kind == "plaza":
		# الميدان الملكي ساحة مركزية مفتوحة للاجتماع والاحتفالات.
		_create_box(root, "RoyalPlazaGround", Vector3(36, 0.8, 36), Vector3(0, -0.4, 0), stone, true)
		var tile_colors := [Color(0.72, 0.63, 0.48), Color(0.61, 0.53, 0.41)]
		for x in range(-15, 16, 3):
			for z in range(-15, 16, 3):
				var tile_color: Color = tile_colors[(int(x / 3) + int(z / 3) + 20) % 2]
				_create_box(root, "PlazaTile_%d_%d" % [x, z], Vector3(2.92, 0.045, 2.92), Vector3(float(x), 0.025, float(z)), tile_color)
		# نافورة مركزية منخفضة؛ لا تتجاوز الممرات المحيطة بها.
		_create_box(root, "PlazaFountainOuterBasin", Vector3(5.4, 0.55, 5.4), Vector3(0, 0.35, -2.0), dark_stone, true)
		_create_box(root, "PlazaFountainWater", Vector3(4.65, 0.12, 4.65), Vector3(0, 0.68, -2.0), Color(0.12, 0.48, 0.62))
		_create_box(root, "PlazaFountainCentralPedestal", Vector3(0.85, 1.8, 0.85), Vector3(0, 1.5, -2.0), gold, true)
		_create_box(root, "PlazaFountainTopBowl", Vector3(2.1, 0.22, 2.1), Vector3(0, 2.48, -2.0), gold, true)
		# أربعة نصب عند الزوايا الداخلية، بعيدًا عن مدخل الساحة.
		for x in [-12.0, 12.0]:
			for z in [-11.0, 10.0]:
				_create_box(root, "PlazaMonumentBase_%d_%d" % [int(x), int(z)], Vector3(2.0, 0.55, 2.0), Vector3(x, 0.28, z), dark_stone, true)
				_create_box(root, "PlazaMonument_%d_%d" % [int(x), int(z)], Vector3(0.85, 4.6, 0.85), Vector3(x, 2.85, z), gold, true)
		# مقاعد جانبية تحافظ على ممرات واضحة حول النافورة.
		for x in [-11.0, 11.0]:
			for z in [-3.0, 5.0]:
				_create_box(root, "PlazaBench_%d_%d" % [int(x), int(z)], Vector3(4.0, 0.55, 0.9), Vector3(x, 0.48, z), dark_stone, true)
		# بوابة ملكية خلفية بأعمدة جانبية وعتبة ذهبية.
		_create_box(root, "PlazaRoyalGateTop", Vector3(13.0, 0.65, 0.75), Vector3(0, 5.0, -15.5), gold, true)
		for x in [-6.0, 6.0]:
			_create_box(root, "PlazaRoyalGatePillar_%d" % int(x), Vector3(0.9, 5.2, 0.9), Vector3(x, 2.6, -15.5), gold, true)
		_create_box(root, "PlazaFireworksLaunchMarker", Vector3(2.0, 0.15, 2.0), Vector3(0, 0.12, 14.0), Color(0.52, 0.18, 0.14))
		# منطقة الإطلاق موضع بصري فقط؛ تشغيل الألعاب النارية يحتاج خدمة/نظام مؤثرات مستقلًا.
	elif destination_kind == "ship":
		# القاعة الرئيسية لسفينة الحضارات الخمس؛ مساحة واحدة بلا طوابق أو سلالم.
		var ivory := Color(0.91, 0.87, 0.76)
		var royal_gold := Color(0.88, 0.67, 0.25)
		var red := Color(0.58, 0.12, 0.10)
		var jade := Color(0.18, 0.43, 0.34)
		var blue := Color(0.18, 0.34, 0.52)
		_create_box(root, "FiveCivilizationsHallFloor", Vector3(34, 0.7, 28), Vector3(0, -0.35, 0), ivory, true)
		_create_box(root, "FiveCivilizationsHallCeiling", Vector3(34, 0.65, 28), Vector3(0, 8.2, 0), ivory, true)
		for x in [-16.0, 16.0]:
			_create_box(root, "ShipHallSideWall_%d" % int(x), Vector3(0.7, 8.5, 28), Vector3(x, 4.0, 0), ivory, true)
			_create_box(root, "ShipHallGoldBand_%d" % int(x), Vector3(0.18, 0.28, 27.5), Vector3(x * 0.97, 7.35, 0), royal_gold)
		for z in [-13.5, 13.5]:
			_create_box(root, "ShipHallEndWall_%d" % int(z), Vector3(32, 8.5, 0.7), Vector3(0, 4.0, z), ivory, true)
			_create_box(root, "ShipHallEndGoldBand_%d" % int(z), Vector3(31.5, 0.28, 0.18), Vector3(0, 7.35, z * 0.97), royal_gold)
		for x in [-13.0, -7.0, 7.0, 13.0]:
			_create_box(root, "ShipHallColumn_%d" % int(x), Vector3(0.75, 7.0, 0.75), Vector3(x, 3.5, -1.0), royal_gold, true)
			_create_box(root, "ShipHallCapital_%d" % int(x), Vector3(1.35, 0.45, 1.35), Vector3(x, 7.1, -1.0), ivory, true)
		# خمسة مداخل مستقلة على الجدار الخلفي، لكل حضارة لون وهوية واضحة.
		var gate_x := [-12.0, -6.0, 0.0, 6.0, 12.0]
		var gate_colors := [Color(0.78, 0.62, 0.34), blue, jade, red, Color(0.52, 0.35, 0.62)]
		var gate_names := ["Greek", "Roman", "Japanese", "Chinese", "French"]
		for i in range(5):
			var gx: float = gate_x[i]
			var gc: Color = gate_colors[i]
			var gn: String = gate_names[i]
			_create_box(root, gn + "GateTop", Vector3(4.4, 0.45, 0.55), Vector3(gx, 5.2, -10.8), royal_gold, true)
			_create_box(root, gn + "GateLeft", Vector3(0.45, 5.2, 0.55), Vector3(gx - 2.0, 2.6, -10.8), gc, true)
			_create_box(root, gn + "GateRight", Vector3(0.45, 5.2, 0.55), Vector3(gx + 2.0, 2.6, -10.8), gc, true)
			_create_box(root, gn + "GateGlow", Vector3(3.35, 3.8, 0.12), Vector3(gx, 2.65, -11.1), gc)
			_create_box(root, gn + "GameMachine", Vector3(1.5, 1.65, 0.85), Vector3(gx, 0.95, -6.2), royal_gold, true)
			_create_box(root, gn + "MachineScreen", Vector3(1.18, 0.72, 0.12), Vector3(gx, 1.22, -5.72), gc)
			_create_box(root, gn + "Seat", Vector3(1.25, 0.55, 0.8), Vector3(gx, 0.42, -3.8), dark_stone, true)
			_create_box(root, gn + "AchievementWing", Vector3(3.4, 2.1, 0.22), Vector3(gx, 3.0, -8.9), ivory, true)
			_create_box(root, gn + "AchievementTrim", Vector3(3.5, 0.14, 0.3), Vector3(gx, 4.12, -8.82), royal_gold)
		# ملامح الحضارات على القاعة دون تحويلها إلى خمس غرف منفصلة.
		# اليونانية: تيجان أعمدة؛ الرومانية: أقواس مستطيلة؛ اليابانية: سقف مائل متدرج.
		_create_box(root, "GreekMarblePediment", Vector3(4.8, 0.65, 0.8), Vector3(-12.0, 5.75, -10.7), ivory, true)
		_create_box(root, "RomanArchUpper", Vector3(4.8, 0.5, 0.7), Vector3(-6.0, 5.65, -10.65), royal_gold, true)
		_create_box(root, "JapaneseRoofLower", Vector3(5.0, 0.28, 1.1), Vector3(6.0, 5.55, -10.6), jade, true)
		_create_box(root, "JapaneseRoofUpper", Vector3(4.1, 0.28, 0.9), Vector3(6.0, 5.92, -10.6), royal_gold, true)
		_create_box(root, "ChineseRedLintel", Vector3(5.0, 0.35, 0.85), Vector3(0.0, 5.55, -10.55), red, true)
		_create_box(root, "FrenchRoyalCrest", Vector3(2.0, 1.0, 0.3), Vector3(12.0, 5.8, -10.6), royal_gold, true)
		# مجسم ذهبي مركزي يجمع رموز الحضارات الخمس، في قلب القاعة.
		_create_box(root, "FiveCivilizationsEmblemBase", Vector3(4.0, 0.45, 4.0), Vector3(0, 0.25, 1.0), dark_stone, true)
		_create_box(root, "FiveCivilizationsGoldenStatueCore", Vector3(1.0, 3.4, 1.0), Vector3(0, 2.1, 1.0), royal_gold, true)
		_create_box(root, "FiveCivilizationsEmblemCrossA", Vector3(4.0, 0.28, 0.28), Vector3(0, 3.45, 1.0), royal_gold, true)
		_create_box(root, "FiveCivilizationsEmblemCrossB", Vector3(0.28, 4.0, 0.28), Vector3(0, 3.45, 1.0), royal_gold, true)
		_create_box(root, "FiveCivilizationsEmblemRing", Vector3(2.6, 0.22, 2.6), Vector3(0, 4.0, 1.0), ivory, true)
		# أجنحة عرض الإنجازات الخمسة موزعة على جانبي القاعة.
		for i in range(5):
			var wing_x: float = -12.0 + float(i) * 6.0
			_create_box(root, "AchievementDisplayWing_%d" % i, Vector3(3.6, 2.6, 0.25), Vector3(wing_x, 2.4, 8.8), ivory, true)
			_create_box(root, "AchievementDisplayGold_%d" % i, Vector3(3.7, 0.16, 0.32), Vector3(wing_x, 3.78, 8.7), royal_gold)
		# ممر مركزي واسع يبقى خاليًا للحركة من نقطة الدخول إلى البوابات.
		_create_box(root, "ShipHallCentralAisleTrim", Vector3(1.0, 0.06, 17.0), Vector3(0, 0.04, 0), royal_gold)
		_create_box(root, "ShipHallBowWindow", Vector3(12.0, 4.0, 0.25), Vector3(0, 5.0, 13.05), blue)
		_create_box(root, "ShipHallBowWindowFrame", Vector3(13.0, 0.35, 0.55), Vector3(0, 7.15, 12.8), royal_gold)
		_create_box(root, "ShipHallPortSideAccent", Vector3(0.3, 3.0, 20.0), Vector3(-15.45, 4.0, 0), royal_gold)
		_create_box(root, "ShipHallStarboardSideAccent", Vector3(0.3, 3.0, 20.0), Vector3(15.45, 4.0, 0), royal_gold)
	var title := Label3D.new()
	title.name = "DestinationTitle"
	title.text = "𓂀  " + destination_name + "  𓂀"
	title.position = Vector3(0, 5.0, -12.0)
	title.font_size = 48
	title.pixel_size = 0.012
	title.modulate = Color(1.0, 0.86, 0.52)
	root.add_child(title)
	_create_interior_exit_marker(root)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 8.0, 0)
	light.light_color = Color(1.0, 0.82, 0.58)
	light.light_energy = 1.5
	light.omni_range = 38.0
	root.add_child(light)

func _open_private_apartment() -> void:
	# نسخة محلية أولية للشقة؛ لا تمثل زيارة أصدقاء أو ملكية مرتبطة بحساب خادمي.
	var body := interior_player
	if not is_instance_valid(body) or not is_instance_valid(interior_root) or interior_transition_busy:
		return
	await return_from_building_interior()
	if not is_inside_tree() or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	interior_transition_busy = true
	interior_player = body
	interior_return_transform = body.global_transform
	body.set_physics_process(false)
	_show_interior_loading(false)
	_set_city_world_hidden(true)
	_create_building_interior("شقتي")
	_create_apartment_customization_ui()
	_create_apartment_furniture_ui()
	body.global_position = INTERIOR_WORLD_POSITION + Vector3(0, 1.05, 2.8)
	body.velocity = Vector3.ZERO
	body.rotation.y = PI
	body.set_physics_process(true)
	interior_transition_busy = false
	_show_interior_loading(true)

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
	interior_exit_button.visible = false
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
	if bool(body.get("sitting")) or bool(body.get("animal_riding")) or bool(body.get("scooter_riding")):
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
	if building_title != "شقتي":
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
	_create_interior_exit_marker(interior_root)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.2, 0)
	light.light_color = Color(1.0, 0.82, 0.57)
	light.light_energy = 1.2
	light.omni_range = 18.0
	interior_root.add_child(light)

func _create_interior_furnishings(root: Node3D, building_title: String) -> void:
	# أثاث هندسي خفيف ومختلف لكل مبنى، دون صور أو خامات أو مكتبات إضافية.
	if building_title == "شقتي":
		# توزيع أولي لشقة خاصة: صالة معيشة، تلفاز، سفرة، وغرفة نوم.
		_create_box(root, "ApartmentLivingRug", Vector3(6.2, 0.06, 4.2), Vector3(0, 0.22, 1.0), Color(0.42, 0.24, 0.16))
		_create_box(root, "ApartmentSofaBase", Vector3(3.8, 0.65, 1.0), Vector3(-2.0, 0.48, 1.6), Color(0.12, 0.29, 0.28), true)
		_create_box(root, "ApartmentSofaBack", Vector3(3.8, 1.0, 0.28), Vector3(-2.0, 1.0, 2.0), Color(0.16, 0.36, 0.34), true)
		_create_box(root, "ApartmentCoffeeTable", Vector3(1.8, 0.22, 0.9), Vector3(-2.0, 0.48, -0.1), Color(0.34, 0.20, 0.11), true)
		_create_box(root, "ApartmentTVConsole", Vector3(3.2, 0.65, 0.55), Vector3(2.2, 0.38, -3.8), Color(0.24, 0.17, 0.12), true)
		_create_box(root, "ApartmentTVScreen", Vector3(2.4, 1.35, 0.12), Vector3(2.2, 1.45, -4.0), Color(0.035, 0.07, 0.09))
		_create_box(root, "ApartmentDiningTable", Vector3(2.2, 0.16, 1.3), Vector3(3.7, 0.95, 1.2), Color(0.40, 0.25, 0.13), true)
		_create_box(root, "ApartmentBedBase", Vector3(2.8, 0.48, 3.2), Vector3(3.8, 0.42, -2.0), Color(0.34, 0.24, 0.19), true)
		_create_box(root, "ApartmentBedMattress", Vector3(2.7, 0.22, 3.0), Vector3(3.8, 0.75, -2.0), Color(0.78, 0.72, 0.61))
		_create_box(root, "ApartmentBedHeadboard", Vector3(2.9, 1.2, 0.18), Vector3(3.8, 1.0, -3.65), Color(0.43, 0.29, 0.17), true)
		_create_box(root, "ApartmentGoldFeature", Vector3(4.8, 0.12, 0.18), Vector3(0, 3.35, -6.76), Color(0.86, 0.67, 0.30))
		for item_name in ["ApartmentLivingRug", "ApartmentSofaBase", "ApartmentSofaBack"]:
			var fabric_item := root.get_node_or_null(item_name) as MeshInstance3D
			if is_instance_valid(fabric_item):
				fabric_item.add_to_group("apartment_fabric")
		for item_name in ["ApartmentCoffeeTable", "ApartmentTVConsole", "ApartmentDiningTable", "ApartmentBedBase", "ApartmentBedHeadboard"]:
			var wood_item := root.get_node_or_null(item_name) as MeshInstance3D
			if is_instance_valid(wood_item):
				wood_item.add_to_group("apartment_wood")
		var gold_item := root.get_node_or_null("ApartmentGoldFeature") as MeshInstance3D
		if is_instance_valid(gold_item):
			gold_item.add_to_group("apartment_gold")
		_load_apartment_design()
		_apply_apartment_design(root)
		_capture_apartment_furniture_defaults(root)
		_load_apartment_furniture(root)
	elif building_title == "المتجر":
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


func _load_apartment_design() -> void:
	var config := ConfigFile.new()
	if config.load(APARTMENT_SAVE_PATH) != OK:
		apartment_design_index = 0
		return
	var saved_value: Variant = config.get_value("apartment", "design_index", 0)
	if saved_value is int and int(saved_value) >= 0 and int(saved_value) < APARTMENT_DESIGN_NAMES.size():
		apartment_design_index = int(saved_value)
	else:
		apartment_design_index = 0

func _save_apartment_design() -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(APARTMENT_SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(APARTMENT_SAVE_PATH):
		return false
	config.set_value("apartment", "schema_version", 2)
	config.set_value("apartment", "design_index", apartment_design_index)
	return config.save(APARTMENT_SAVE_PATH) == OK

func _apply_apartment_design(root: Node3D) -> void:
	var fabric_colors := [
		Color(0.12, 0.29, 0.28),
		Color(0.08, 0.43, 0.43),
		Color(0.48, 0.29, 0.17)
	]
	var wood_colors := [
		Color(0.34, 0.20, 0.11),
		Color(0.22, 0.17, 0.12),
		Color(0.39, 0.24, 0.13)
	]
	var gold_colors := [
		Color(0.86, 0.67, 0.30),
		Color(0.66, 0.78, 0.68),
		Color(0.83, 0.57, 0.30)
	]
	var fabric: Color = fabric_colors[apartment_design_index]
	var wood: Color = wood_colors[apartment_design_index]
	var gold: Color = gold_colors[apartment_design_index]
	for item in root.find_children("*", "MeshInstance3D", true, false):
		if item.is_in_group("apartment_fabric"):
			item.material_override = _material(fabric)
		elif item.is_in_group("apartment_wood"):
			item.material_override = _material(wood)
		elif item.is_in_group("apartment_gold"):
			item.material_override = _material(gold)

func is_player_inside_private_apartment() -> bool:
	if not is_instance_valid(interior_root):
		return false
	var interior_title := interior_root.get_node_or_null("Label3D") as Label3D
	return is_instance_valid(interior_title) and interior_title.text == "شقتي"


func _create_apartment_customization_ui() -> void:
	if is_instance_valid(apartment_customization_layer):
		apartment_customization_layer.queue_free()
	apartment_customization_layer = CanvasLayer.new()
	apartment_customization_layer.name = "ApartmentCustomizationLayer"
	apartment_customization_layer.layer = 25
	add_child(apartment_customization_layer)
	var design_button := Button.new()
	design_button.name = "ApartmentDesignButton"
	design_button.custom_minimum_size = Vector2(250, 54)
	design_button.position = Vector2(24, 96)
	design_button.text = "تصميم الشقة: " + APARTMENT_DESIGN_NAMES[apartment_design_index]
	design_button.add_theme_font_size_override("font_size", 18)
	design_button.pressed.connect(_cycle_apartment_design)
	apartment_customization_layer.add_child(design_button)
	var invite_button := Button.new()
	invite_button.name = "ApartmentInviteFriendsButton"
	invite_button.custom_minimum_size = Vector2(250, 48)
	invite_button.position = Vector2(24, 158)
	invite_button.text = "👥 دعوة الأصدقاء"
	invite_button.add_theme_font_size_override("font_size", 17)
	invite_button.pressed.connect(_open_apartment_invite_picker)
	apartment_customization_layer.add_child(invite_button)

func _open_apartment_invite_picker() -> void:
	if not is_player_inside_private_apartment():
		return
	var hud := get_node_or_null("CityActionHUD")
	if is_instance_valid(hud) and hud.has_method("open_apartment_invite_picker"):
		hud.call("open_apartment_invite_picker")


func _cycle_apartment_design() -> void:
	if not is_instance_valid(interior_root) or interior_transition_busy:
		return
	var next_index := (apartment_design_index + 1) % APARTMENT_DESIGN_NAMES.size()
	var previous_index := apartment_design_index
	apartment_design_index = next_index
	if not _save_apartment_design():
		apartment_design_index = previous_index
		push_warning("تعذر حفظ تصميم الشقة على هذا الجهاز.")
		return
	_apply_apartment_design(interior_root)
	var design_button := get_node_or_null("ApartmentCustomizationLayer/ApartmentDesignButton") as Button
	if is_instance_valid(design_button):
		design_button.text = "تصميم الشقة: " + APARTMENT_DESIGN_NAMES[apartment_design_index]


func _capture_apartment_furniture_defaults(root: Node3D) -> void:
	apartment_furniture_defaults.clear()
	for group_data in APARTMENT_FURNITURE_GROUPS:
		for node_name in group_data["nodes"]:
			for suffix in ["", "Collision"]:
				var node := root.get_node_or_null(node_name + suffix) as Node3D
				if is_instance_valid(node):
					apartment_furniture_defaults[node.name] = {"position": node.position, "rotation": node.rotation}

func _get_apartment_group_nodes(root: Node3D, group_index: int) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if group_index < 0 or group_index >= APARTMENT_FURNITURE_GROUPS.size():
		return result
	for node_name in APARTMENT_FURNITURE_GROUPS[group_index]["nodes"]:
		for suffix in ["", "Collision"]:
			var node := root.get_node_or_null(node_name + suffix) as Node3D
			if is_instance_valid(node):
				result.append(node)
	return result

func _load_apartment_furniture(root: Node3D) -> void:
	var config := ConfigFile.new()
	if config.load(APARTMENT_SAVE_PATH) != OK:
		return
	for node_name in apartment_furniture_defaults.keys():
		var node := root.get_node_or_null(node_name) as Node3D
		if not is_instance_valid(node):
			continue
		var saved_position: Variant = config.get_value("furniture", node_name + "_position", null)
		var saved_rotation: Variant = config.get_value("furniture", node_name + "_rotation", null)
		if saved_position is Vector3 and saved_rotation is Vector3:
			node.position = saved_position
			node.rotation = saved_rotation

func _save_apartment_furniture() -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(APARTMENT_SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(APARTMENT_SAVE_PATH):
		return false
	config.set_value("apartment", "schema_version", 2)
	config.set_value("apartment", "design_index", apartment_design_index)
	if is_instance_valid(interior_root):
		for node_name in apartment_furniture_defaults.keys():
			var node := interior_root.get_node_or_null(node_name) as Node3D
			if is_instance_valid(node):
				config.set_value("furniture", node_name + "_position", node.position)
				config.set_value("furniture", node_name + "_rotation", node.rotation)
	return config.save(APARTMENT_SAVE_PATH) == OK

func _create_apartment_furniture_ui() -> void:
	if is_instance_valid(apartment_furniture_layer):
		apartment_furniture_layer.queue_free()
	apartment_furniture_layer = CanvasLayer.new()
	apartment_furniture_layer.name = "ApartmentFurnitureLayer"
	apartment_furniture_layer.layer = 26
	add_child(apartment_furniture_layer)
	var panel := PanelContainer.new()
	panel.name = "ApartmentFurniturePanel"
	panel.position = Vector2(18, 164)
	panel.custom_minimum_size = Vector2(300, 0)
	apartment_furniture_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "ترتيب أثاث الشقة"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 17)
	column.add_child(heading)
	var selected_label := Label.new()
	selected_label.name = "SelectedFurnitureLabel"
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(selected_label)
	var select_row := HBoxContainer.new()
	column.add_child(select_row)
	_add_apartment_furniture_button(select_row, "السابق", func(): _select_apartment_furniture(-1))
	_add_apartment_furniture_button(select_row, "التالي", func(): _select_apartment_furniture(1))
	var move_grid := GridContainer.new()
	move_grid.columns = 3
	column.add_child(move_grid)
	_add_apartment_furniture_button(move_grid, "↖", func(): _move_selected_apartment_furniture(Vector3(-0.35, 0, -0.35)))
	_add_apartment_furniture_button(move_grid, "↑", func(): _move_selected_apartment_furniture(Vector3(0, 0, -0.35)))
	_add_apartment_furniture_button(move_grid, "↗", func(): _move_selected_apartment_furniture(Vector3(0.35, 0, -0.35)))
	_add_apartment_furniture_button(move_grid, "←", func(): _move_selected_apartment_furniture(Vector3(-0.35, 0, 0)))
	_add_apartment_furniture_button(move_grid, "إرجاع", _reset_selected_apartment_furniture)
	_add_apartment_furniture_button(move_grid, "→", func(): _move_selected_apartment_furniture(Vector3(0.35, 0, 0)))
	_add_apartment_furniture_button(move_grid, "↙", func(): _move_selected_apartment_furniture(Vector3(-0.35, 0, 0.35)))
	_add_apartment_furniture_button(move_grid, "↓", func(): _move_selected_apartment_furniture(Vector3(0, 0, 0.35)))
	_add_apartment_furniture_button(move_grid, "↘", func(): _move_selected_apartment_furniture(Vector3(0.35, 0, 0.35)))
	var rotate_row := HBoxContainer.new()
	column.add_child(rotate_row)
	_add_apartment_furniture_button(rotate_row, "↶ تدوير", func(): _rotate_selected_apartment_furniture(-15.0))
	_add_apartment_furniture_button(rotate_row, "تدوير ↷", func(): _rotate_selected_apartment_furniture(15.0))
	_update_apartment_furniture_label()

func _add_apartment_furniture_button(parent: Control, button_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(88, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	parent.add_child(button)

func _update_apartment_furniture_label() -> void:
	if not is_instance_valid(apartment_furniture_layer):
		return
	var label := apartment_furniture_layer.get_node_or_null("ApartmentFurniturePanel/VBoxContainer/SelectedFurnitureLabel") as Label
	if is_instance_valid(label):
		label.text = "العنصر: " + str(APARTMENT_FURNITURE_GROUPS[apartment_furniture_index]["label"])

func _select_apartment_furniture(direction: int) -> void:
	apartment_furniture_index = posmod(apartment_furniture_index + direction, APARTMENT_FURNITURE_GROUPS.size())
	_update_apartment_furniture_label()

func _move_selected_apartment_furniture(offset: Vector3) -> void:
	if not is_instance_valid(interior_root) or interior_transition_busy:
		return
	var nodes := _get_apartment_group_nodes(interior_root, apartment_furniture_index)
	if nodes.is_empty():
		return
	for node in nodes:
		node.position.x = clampf(node.position.x + offset.x, -5.8, 5.8)
		node.position.z = clampf(node.position.z + offset.z, -5.8, 5.8)
	_save_apartment_furniture()

func _rotate_selected_apartment_furniture(degrees: float) -> void:
	if not is_instance_valid(interior_root) or interior_transition_busy:
		return
	var nodes := _get_apartment_group_nodes(interior_root, apartment_furniture_index)
	if nodes.is_empty():
		return
	var pivot := Vector3.ZERO
	for node in nodes:
		pivot += node.position
	pivot /= float(nodes.size())
	var angle := deg_to_rad(degrees)
	for node in nodes:
		var relative := node.position - pivot
		node.position = pivot + Vector3(relative.x * cos(angle) - relative.z * sin(angle), relative.y, relative.x * sin(angle) + relative.z * cos(angle))
		node.rotation.y += angle
	_save_apartment_furniture()

func _reset_selected_apartment_furniture() -> void:
	if not is_instance_valid(interior_root) or interior_transition_busy:
		return
	for node in _get_apartment_group_nodes(interior_root, apartment_furniture_index):
		if apartment_furniture_defaults.has(node.name):
			var defaults: Dictionary = apartment_furniture_defaults[node.name]
			node.position = defaults["position"]
			node.rotation = defaults["rotation"]
	_save_apartment_furniture()

func _create_interior_exit_marker(root: Node3D) -> void:
	var exit_marker := Node3D.new()
	exit_marker.name = "ApartmentExitInteraction"
	exit_marker.position = Vector3(0, 0, 5.7)
	exit_marker.add_to_group("interior_exit_interactables")
	root.add_child(exit_marker)
	# بوابة خروج مرئية تساعد اللاعب على اكتشاف نقطة فتح التنقل السريع.
	# العناصر زخرفية بلا تصادم حتى لا تسد مسار اللاعب.
	var portal_gold := Color(0.91, 0.69, 0.28)
	_create_box(exit_marker, "ExitGateLeftPillar", Vector3(0.22, 2.9, 0.24), Vector3(-1.05, 1.45, 0.0), portal_gold)
	_create_box(exit_marker, "ExitGateRightPillar", Vector3(0.22, 2.9, 0.24), Vector3(1.05, 1.45, 0.0), portal_gold)
	_create_box(exit_marker, "ExitGateLintel", Vector3(2.32, 0.24, 0.24), Vector3(0.0, 2.92, 0.0), portal_gold)
	_create_box(exit_marker, "ExitGateThreshold", Vector3(2.1, 0.08, 0.85), Vector3(0.0, 0.05, 0.12), portal_gold)
	var portal := MeshInstance3D.new()
	portal.name = "ExitGateGlow"
	var portal_mesh := BoxMesh.new()
	portal_mesh.size = Vector3(1.82, 2.62, 0.035)
	portal.mesh = portal_mesh
	portal.position = Vector3(0.0, 1.43, 0.02)
	var portal_material := StandardMaterial3D.new()
	portal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_material.albedo_color = Color(0.42, 0.66, 0.92, 0.16)
	portal_material.emission_enabled = true
	portal_material.emission = Color(0.22, 0.48, 0.82)
	portal_material.emission_energy_multiplier = 0.65
	portal.material_override = portal_material
	exit_marker.add_child(portal)
	var exit_label := Label3D.new()
	exit_label.name = "ExitGateLabel"
	exit_label.text = "🚪  التنقل والخروج"
	exit_label.position = Vector3(0.0, 3.45, 0.0)
	exit_label.font_size = 32
	exit_label.pixel_size = 0.012
	exit_label.modulate = Color(1.0, 0.88, 0.60)
	exit_marker.add_child(exit_label)

func _create_interior_staff(root: Node3D, building_title: String) -> void:
	# الشقة ملكية خاصة؛ لا يظهر فيها موظف خدمة افتراضي.
	if building_title == "شقتي":
		return
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

func return_from_building_interior(destination: Vector3 = Vector3(0.0, -9999.0, 0.0)) -> void:
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
		if destination.y > -9000.0:
			body.global_position = destination
		body.velocity = Vector3.ZERO
		body.set_physics_process(true)
	if is_instance_valid(interior_root):
		interior_root.queue_free()
	interior_root = null
	interior_player = null
	interior_transition_busy = false
	_hide_interior_loading()
	_hide_interior_quick_travel_menu()
	if is_instance_valid(apartment_customization_layer):
		apartment_customization_layer.queue_free()
	apartment_customization_layer = null
	if is_instance_valid(apartment_furniture_layer):
		apartment_furniture_layer.queue_free()
	apartment_furniture_layer = null
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
		CityCollisionProfile.apply_world_collision(body)
		body.add_to_group("city_world_geometry")
		var shape_node := CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.position = pos
		body.add_child(shape_node)
		parent.add_child(body)


func _create_ground() -> void:
	_create_box(self, "Ground", Vector3(180, 1, 180), Vector3(0, -0.55, 0), Color(0.34, 0.42, 0.31), true)

func _create_city() -> void:
	for x in range(-city_half_size, city_half_size + 1):
		for z in range(-city_half_size, city_half_size + 1):
			var center := Vector3(x * block_spacing, 0, z * block_spacing)
			# مساحات مبانٍ على جانبي شبكة الطرق
			if abs(x) % 2 == 0 and abs(z) % 2 == 0 and (x != 0 or z != 0):
				var height := 7.0 + float((abs(x * 7 + z * 11) % 5)) * 2.0
				var building_color := Color(0.72, 0.66, 0.55) if (x + z) % 2 == 0 else Color(0.58, 0.62, 0.66)
				_create_box(self, "Building_%d_%d" % [x, z], Vector3(10, height, 10), center + Vector3(0, height / 2.0, 0), building_color, true)
				_create_box(self, "ShopFront_%d_%d" % [x, z], Vector3(4.0, 1.1, 0.18), center + Vector3(0, 1.8, 5.08), Color(0.12, 0.28, 0.42), true)

	# شارعان رئيسيان واضحان
	_create_box(self, "MainRoad_X", Vector3(180, 0.08, 10), Vector3(0, 0.0, 0), Color(0.12, 0.13, 0.15))
	_create_box(self, "MainRoad_Z", Vector3(10, 0.09, 180), Vector3(0, 0.01, 0), Color(0.12, 0.13, 0.15))
	# شوارع فرعية متصلة بالمحورين الرئيسيين، تمر في الممرات بين كتل المباني.
	# إحداثيات شبكة الطرق المستخدمة في حساب مسارات الحركة داخل المدينة.
	for road_x in [-72.0, -24.0, 24.0, 72.0]:
		_create_box(self, "SideRoad_X_%d" % int(road_x), Vector3(180, 0.075, 6), Vector3(road_x, 0.005, 0), Color(0.15, 0.16, 0.17))
	for road_z in [-72.0, -24.0, 24.0, 72.0]:
		_create_box(self, "SideRoad_Z_%d" % int(road_z), Vector3(6, 0.075, 180), Vector3(0, 0.006, road_z), Color(0.15, 0.16, 0.17))
	# خطوط إرشادية بسيطة على المحورين الرئيسيين فقط لتقليل العناصر المرئية.
	for i in range(-8, 9):
		_create_box(self, "RoadMark_X_%d" % i, Vector3(3, 0.025, 0.16), Vector3(i * 10, 0.06, 0), Color(0.92, 0.86, 0.62))
		_create_box(self, "RoadMark_Z_%d" % i, Vector3(0.16, 0.025, 3), Vector3(0, 0.065, i * 10), Color(0.92, 0.86, 0.62))

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

	# واجهة أزرار المدينة تُنشأ عند بدء اللعبة، لا عند ركوب/مغادرة السيارة.
	# كان وضعها داخل _set_mobile_hud_active يمنع ظهورها في بداية اللعب.
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
	_create_job_board("وظيفة التوصيل", "توصيل طلب إلى نقطة الاستلام المحددة في المدينة.", Vector3(24, 0, 4.5), Vector3(0, 0, 9.5), 180, 0, 30, "courier_delivery")
	_create_job_board("مرشد المدينة", "اذهب إلى نقطة المعلم السياحي وساعد الزائرين على اكتشاف المدينة.", Vector3(-24, 0, 4.5), Vector3(0, 0, -18.5), 220, 1, 40, "city_guide")
	_create_job_board("عامل صيانة", "توجّه إلى موقع الصيانة المحدد وأكمل جولة الفحص الميدانية.", Vector3(4.5, 0, 24), Vector3(9.5, 0, 0), 250, 0, 45, "city_maintenance", PI / 2.0)
	_create_service_staff("صاحب المتجر", "صاحب محل", "أهلًا بك! يمكنني مساعدتك في احتياجاتك ومشترياتك من المتجر.", Vector3(19.5, 0, 20.2))
	_create_service_staff("موظف المطعم", "موظف", "مرحبًا! أستقبل طلبات المطعم وأساعدك في أنشطة التوصيل.", Vector3(-12.5, 0, 20.2))
	_create_service_staff("موظف مركز التوظيف", "موظف", "أهلًا بك! يمكنك مراجعة الوظائف المتاحة وشروطها هنا.", Vector3(19.5, 0, -11))
	_create_daily_reward_chest()

func _create_daily_reward_chest() -> void:
	# نقطة صغيرة بجوار ساحة المحور الرئيسي، بعيدًا عن مداخل المباني.
	var chest := Node3D.new()
	chest.name = "DailyPharaonicRewardChest"
	chest.set_script(load("res://scripts/daily_reward_chest.gd"))
	chest.position = Vector3(7.5, 0.0, 7.5)
	add_child(chest)


func _add_functional_building(manager: Node, title: String, mission: String, description: String, pos: Vector3, color: Color, reward: int, chips_reward: int, level: int) -> void:
	var building := Node3D.new()
	building.name = "Functional_" + title
	building.set_script(load("res://scripts/building_interaction.gd"))
	building.building_id = "mission_" + str(title.hash())
	building.position = pos
	building.building_title = title
	building.mission_title = mission
	building.mission_description = description
	building.reward_money = reward
	building.reward_chips = chips_reward
	building.reward_xp = max(20, int(reward / 5))
	building.required_level = level
	building.requires_interior = true
	add_child(building)
	_create_box(building, "BuildingBody", Vector3(8, 5, 7), Vector3(0, 2.5, 0), color, true)
	_create_box(building, "Entrance", Vector3(1.5, 2.4, 0.12), Vector3(0, 1.2, 3.56), Color(0.12, 0.14, 0.18), false)
	_create_box(building, "Sign", Vector3(5.0, 0.8, 0.16), Vector3(0, 4.25, 3.58), Color(0.10, 0.22, 0.25), true)
	var sign_key := "shop"
	if title == "المطعم":
		sign_key = "restaurant"
	elif title == "مركز التوظيف":
		sign_key = "employment"
	_add_sign_label(building, sign_key, Vector3(0, 4.25, 3.70), PI)
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
	_create_box(board, "JobBoardBase", Vector3(2.4, 1.5, 0.45), Vector3(0, 0.75, 0), Color(0.16, 0.22, 0.28), true)
	_create_box(board, "JobBoardSign", Vector3(2.8, 1.1, 0.16), Vector3(0, 2.05, 0), Color(0.10, 0.22, 0.25), true)
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
	_create_direction_signpost("Signpost_PyramidsCamp", Vector3(34, 0, 38), "city_center", "pyramids_camp", PI / 2.0)

func _create_direction_signpost(sign_name: String, pos: Vector3, left_key: String, right_key: String, yaw: float = 0.0) -> void:
	var sign_root := Node3D.new()
	sign_root.name = sign_name
	sign_root.position = pos
	sign_root.rotation.y = yaw
	add_child(sign_root)
	_create_box(sign_root, "StonePost", Vector3(0.35, 2.7, 0.35), Vector3(0, 1.35, 0), Color(0.66, 0.52, 0.32), true)
	_create_box(sign_root, "DarkBoard", Vector3(6.2, 1.15, 0.22), Vector3(0, 2.65, 0), Color(0.08, 0.22, 0.23), true)
	_create_box(sign_root, "GoldTopTrim", Vector3(6.3, 0.09, 0.27), Vector3(0, 3.25, 0), Color(0.88, 0.68, 0.30), true)
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


func _create_service_staff(display_name: String, role: String, dialogue: String, pos: Vector3) -> void:
	var staff := Node3D.new()
	staff.name = "Staff_" + str(display_name.hash())
	staff.set_script(load("res://scripts/service_npc.gd"))
	staff.set("character_name", display_name)
	staff.set("role_title", role)
	staff.interaction_text = dialogue
	staff.position = pos
	add_child(staff)

# طريق وصول مشترك للمخيم الصحراوي واتصال طريق قمة الملوك؛ لا ينشئ منتجعًا أو بوابات.
func _create_desert_camp_access_road() -> void:
	_create_box(self, "DesertCampRoad_Entry", Vector3(32, 0.08, 5), Vector3(16, 0.01, 0), Color(0.12, 0.13, 0.15), true)
	_create_box(self, "DesertCampRoad_North", Vector3(5, 0.08, 75), Vector3(30, 0.01, 37.5), Color(0.12, 0.13, 0.15), true)
	_create_box(self, "DesertCampRoad_Approach", Vector3(11, 0.08, 5), Vector3(35.5, 0.01, 60), Color(0.12, 0.13, 0.15), true)

func _create_party_station() -> void:
	# محطة الحفلات التجريبية في الساحة المركزية، خارج مسارات الطرق ومداخل المباني.
	var station := Node3D.new()
	station.name = "RoyalPartyStation"
	station.position = Vector3(7.5, 0.0, -7.5)
	station.add_to_group("party_stations")
	add_child(station)
	_create_box(station, "PartyStationBase", Vector3(2.8, 0.32, 2.8), Vector3(0, 0.16, 0), Color(0.22, 0.17, 0.11), true)
	_create_box(station, "PartyStationGoldTrim", Vector3(2.35, 0.10, 2.35), Vector3(0, 0.37, 0), Color(0.88, 0.67, 0.28), false)
	_create_box(station, "PartyStationPillar", Vector3(0.85, 1.65, 0.85), Vector3(0, 1.22, 0), Color(0.76, 0.66, 0.48), true)
	_create_box(station, "PartyStationCrown", Vector3(1.45, 0.22, 1.45), Vector3(0, 2.12, 0), Color(0.94, 0.75, 0.34), false)
	_create_box(station, "PartyStationBeacon", Vector3(0.42, 0.65, 0.42), Vector3(0, 2.55, 0), Color(0.10, 0.66, 0.66), false)

func _get_nearby_party_station(actor: Node3D) -> Node3D:
	if not is_instance_valid(actor):
		return null
	var nearest: Node3D = null
	var nearest_distance := 4.5
	for candidate in get_tree().get_nodes_in_group("party_stations"):
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		var distance := actor.global_position.distance_to((candidate as Node3D).global_position)
		if distance <= nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	return nearest

func _show_party_station_notice(station: Node3D) -> void:
	var city_hud := get_node_or_null("CityActionHUD")
	if is_instance_valid(city_hud) and city_hud.has_method("open_party_station_window") and is_instance_valid(station):
		city_hud.call("open_party_station_window", str(station.name).to_snake_case())


func _create_desert_camp() -> void:
	# المخيم الصحراوي الملكي؛ الحيوانات داخله مجسمات زينة ثابتة فقط.
	var camp := Node3D.new()
	camp.name = "RoyalDesertCamp"
	camp.set_script(load("res://scripts/desert_camp.gd"))
	camp.position = Vector3(60.0, 0.0, 68.0)
	add_child(camp)

func _create_pyramids_area() -> void:
	# الأهرامات وأبو الهول جزء من منطقة واحدة متصلة بالمخيم الملكي.
	var pyramids := Node3D.new()
	pyramids.name = "GizaPyramidsArea"
	pyramids.set_script(load("res://scripts/pyramids_area.gd"))
	add_child(pyramids)
