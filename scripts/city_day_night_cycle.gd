extends Node

@export_range(60.0, 1800.0, 30.0) var cycle_duration_seconds: float = 720.0
@export_range(10.0, 120.0, 5.0) var night_duration_seconds: float = 15.0
@export_range(0.0, 1.0, 0.01) var initial_cycle_progress: float = 0.34

var _elapsed_seconds: float = 0.0
var _world_environment: WorldEnvironment
var _directional_light: DirectionalLight3D
var _environment: Environment
var _sky_material: ShaderMaterial
var _city_night_lights: Array[OmniLight3D] = []
var _city_window_materials: Array[StandardMaterial3D] = []
var _last_night_amount: float = -1.0


func _ready() -> void:
	if AuthoritativeGameServer.is_dedicated_server_requested():
		set_process(false)
		return
	_world_environment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	_directional_light = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if _world_environment == null or _directional_light == null:
		push_warning("تعذر تشغيل دورة الليل والنهار: عناصر الإضاءة الأساسية غير موجودة.")
		set_process(false)
		return
	_environment = _world_environment.environment
	if _environment == null or _environment.sky == null:
		push_warning("تعذر تشغيل دورة الليل والنهار: بيئة السماء غير متاحة.")
		set_process(false)
		return
	_sky_material = _environment.sky.sky_material as ShaderMaterial
	if _sky_material == null:
		push_warning("تعذر تشغيل دورة الليل والنهار: خامة السماء السينمائية غير متاحة.")
		set_process(false)
		return
	_elapsed_seconds = initial_cycle_progress * cycle_duration_seconds
	_apply_cycle()
	call_deferred("_cache_city_lighting_nodes")


func _process(delta: float) -> void:
	_elapsed_seconds = fposmod(_elapsed_seconds + delta, cycle_duration_seconds)
	_apply_cycle()


func _apply_cycle() -> void:
	var progress := fposmod(_elapsed_seconds / maxf(cycle_duration_seconds, 1.0), 1.0)
	var night_duration := clampf(night_duration_seconds, 10.0, cycle_duration_seconds - 10.0)
	var day_duration := cycle_duration_seconds - night_duration
	var sun_height := 0.0
	if _elapsed_seconds < day_duration:
		var day_progress := _elapsed_seconds / maxf(day_duration, 1.0)
		sun_height = sin(day_progress * PI)
	else:
		var night_progress := (_elapsed_seconds - day_duration) / maxf(night_duration, 1.0)
		sun_height = -sin(night_progress * PI)
	var sun_angle := progress * TAU
	var sun_direction := Vector3(cos(sun_angle), sun_height, sin(sun_angle) * 0.35).normalized()
	var daylight := smoothstep(-0.12, 0.20, sun_height)
	var twilight := 1.0 - smoothstep(0.015, 0.30, absf(sun_height))

	_sky_material.set_shader_parameter("daylight", daylight)
	_sky_material.set_shader_parameter("sun_height", sun_height)
	_sky_material.set_shader_parameter("sun_direction", sun_direction)

	var night_ambient := Color(0.22, 0.27, 0.40, 1.0)
	var day_ambient := Color(0.82, 0.86, 0.92, 1.0)
	var twilight_ambient := Color(0.95, 0.55, 0.36, 1.0)
	_environment.ambient_light_color = night_ambient.lerp(day_ambient, daylight).lerp(twilight_ambient, twilight * 0.32)
	_environment.ambient_light_energy = lerpf(0.34, 0.78, daylight)
	_environment.fog_light_color = Color(0.10, 0.16, 0.28, 1.0).lerp(Color(0.86, 0.62, 0.43, 1.0), maxf(daylight, twilight * 0.72))
	_environment.fog_density = lerpf(0.00165, 0.0012, daylight)

	var light_up := Vector3.FORWARD if absf(sun_direction.dot(Vector3.UP)) > 0.96 else Vector3.UP
	_directional_light.look_at(-sun_direction, light_up)
	_directional_light.light_color = Color(1.0, 0.48, 0.30, 1.0).lerp(Color(1.0, 0.84, 0.68, 1.0), daylight)
	_directional_light.light_energy = lerpf(0.075, 1.15, daylight) + twilight * 0.12
	_apply_city_night_lighting(daylight)

func _cache_city_lighting_nodes() -> void:
	_city_night_lights.clear()
	_city_window_materials.clear()
	for node in get_tree().get_nodes_in_group("city_night_lights"):
		if node is OmniLight3D:
			_city_night_lights.append(node as OmniLight3D)
	for node in get_tree().get_nodes_in_group("city_night_windows"):
		if node is GeometryInstance3D:
			var material := (node as GeometryInstance3D).material_override as StandardMaterial3D
			if material != null:
				_city_window_materials.append(material)
	_last_night_amount = -1.0
	_apply_cycle()


func _apply_city_night_lighting(daylight: float) -> void:
	var night_amount := 1.0 - smoothstep(0.08, 0.58, daylight)
	if absf(night_amount - _last_night_amount) < 0.025:
		return
	_last_night_amount = night_amount
	for light in _city_night_lights:
		if is_instance_valid(light):
			light.light_energy = 0.72 * night_amount
	for material in _city_window_materials:
		if is_instance_valid(material):
			material.emission = Color(0.018, 0.055, 0.07).lerp(Color(1.0, 0.46, 0.14), night_amount)
			material.emission_energy_multiplier = lerpf(0.025, 1.25, night_amount)
