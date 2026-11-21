extends Node

@export_range(60.0, 1800.0, 30.0) var cycle_duration_seconds: float = 720.0
@export_range(0.0, 1.0, 0.01) var initial_cycle_progress: float = 0.34

var _elapsed_seconds: float = 0.0
var _world_environment: WorldEnvironment
var _directional_light: DirectionalLight3D
var _environment: Environment
var _sky_material: ShaderMaterial


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


func _process(delta: float) -> void:
	_elapsed_seconds = fposmod(_elapsed_seconds + delta, cycle_duration_seconds)
	_apply_cycle()


func _apply_cycle() -> void:
	var progress := fposmod(_elapsed_seconds / maxf(cycle_duration_seconds, 1.0), 1.0)
	var sun_angle := (progress - 0.25) * TAU
	var sun_height := sin(sun_angle)
	var sun_direction := Vector3(cos(progress * TAU), sun_height, sin(progress * TAU) * 0.35).normalized()
	var daylight := smoothstep(-0.16, 0.18, sun_height)
	var twilight := 1.0 - smoothstep(0.02, 0.42, absf(sun_height))

	_sky_material.set_shader_parameter("daylight", daylight)
	_sky_material.set_shader_parameter("sun_height", sun_height)
	_sky_material.set_shader_parameter("sun_direction", sun_direction)

	var night_ambient := Color(0.12, 0.17, 0.30, 1.0)
	var day_ambient := Color(0.82, 0.86, 0.92, 1.0)
	var twilight_ambient := Color(0.95, 0.55, 0.36, 1.0)
	_environment.ambient_light_color = night_ambient.lerp(day_ambient, daylight).lerp(twilight_ambient, twilight * 0.32)
	_environment.ambient_light_energy = lerpf(0.22, 0.78, daylight)
	_environment.fog_light_color = Color(0.10, 0.16, 0.28, 1.0).lerp(Color(0.86, 0.62, 0.43, 1.0), maxf(daylight, twilight * 0.72))
	_environment.fog_density = lerpf(0.00165, 0.0012, daylight)

	var light_up := Vector3.FORWARD if absf(sun_direction.dot(Vector3.UP)) > 0.96 else Vector3.UP
	_directional_light.look_at(-sun_direction, light_up)
	_directional_light.light_color = Color(1.0, 0.48, 0.30, 1.0).lerp(Color(1.0, 0.84, 0.68, 1.0), daylight)
	_directional_light.light_energy = lerpf(0.035, 1.15, daylight) + twilight * 0.12
