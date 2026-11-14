extends Node
## دورة السماء الخفيفة: نهار، غروب، ليل، سحب متحركة وألعاب نارية ليلية.
## نقطة إطلاق الألعاب النارية مؤقتًا هي مركز شبكة الطرق (0, 0, 0)،
## إلى أن يُنشأ مجسم الميدان الملكي النهائي.

@export_range(60.0, 3600.0, 30.0) var cycle_duration_seconds: float = 900.0
@export_range(0.0, 1.0, 0.01) var time_of_day: float = 0.38
@export var enable_fireworks: bool = true
@export_range(5.0, 60.0, 1.0) var fireworks_interval_seconds: float = 14.0

const FIREWORK_LAUNCH_POINT := Vector3(0.0, 0.35, 0.0)
const CLOUD_ALTITUDE := 48.0
const CLOUD_DRIFT_SPEED := 0.75

var _world_environment: WorldEnvironment
var _directional_light: DirectionalLight3D
var _environment: Environment
var _player: Node3D
var _clouds: Array[Node3D] = []
var _cloud_offsets: Array[Vector3] = []
var _firework_countdown: float = 5.0


func _ready() -> void:
	var scene_root := get_parent()
	if not is_instance_valid(scene_root):
		push_warning("SkyCycle يحتاج إلى أن يكون ابنًا للعقدة الرئيسية.")
		set_process(false)
		return

	_world_environment = scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_directional_light = scene_root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_player = scene_root.get_node_or_null("Player") as Node3D

	if not is_instance_valid(_world_environment):
		push_warning("SkyCycle لم يجد WorldEnvironment؛ لن يتم تغيير خلفية السماء.")
	else:
		_environment = _world_environment.environment
		if _environment == null:
			_environment = Environment.new()
			_world_environment.environment = _environment
		_setup_sky()

	_create_clouds()
	_apply_time_state()
	_firework_countdown = 5.0


func _process(delta: float) -> void:
	if cycle_duration_seconds > 0.0:
		time_of_day = fposmod(time_of_day + delta / cycle_duration_seconds, 1.0)
		_apply_time_state()

	_update_clouds(delta)

	if not enable_fireworks:
		return
	if _is_night():
		_firework_countdown -= delta
		if _firework_countdown <= 0.0:
			_launch_firework()
			_firework_countdown = fireworks_interval_seconds
	else:
		_firework_countdown = minf(_firework_countdown, 5.0)


func _setup_sky() -> void:
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.use_debanding = true
	sky.sky_material = sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.background_energy_multiplier = 1.0
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.72, 0.78, 0.88)
	_environment.ambient_light_energy = 0.7


func _apply_time_state() -> void:
	var sun_height := sin((time_of_day - 0.25) * TAU)
	var daylight := clampf((sun_height + 0.10) / 0.34, 0.0, 1.0)
	var twilight := clampf(1.0 - absf(sun_height) / 0.42, 0.0, 1.0)

	var night_top := Color(0.018, 0.035, 0.095)
	var day_top := Color(0.20, 0.49, 0.82)
	var sunset_top := Color(0.78, 0.30, 0.22)
	var night_horizon := Color(0.075, 0.105, 0.19)
	var day_horizon := Color(0.70, 0.82, 0.91)
	var sunset_horizon := Color(1.0, 0.48, 0.25)

	if is_instance_valid(_environment) and _environment.sky != null:
		var material := _environment.sky.sky_material as ProceduralSkyMaterial
		if material != null:
			material.sky_top_color = night_top.lerp(day_top, daylight).lerp(sunset_top, twilight * 0.72)
			material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight).lerp(sunset_horizon, twilight * 0.82)
			material.ground_bottom_color = Color(0.018, 0.025, 0.04).lerp(Color(0.24, 0.27, 0.22), daylight)
			material.ground_horizon_color = night_horizon.lerp(day_horizon, daylight).lerp(sunset_horizon, twilight * 0.45)

		_environment.ambient_light_color = Color(0.28, 0.34, 0.52).lerp(Color(0.82, 0.84, 0.78), daylight)
		_environment.ambient_light_energy = lerpf(0.22, 0.78, daylight)

	if is_instance_valid(_directional_light):
		_directional_light.light_energy = lerpf(0.035, 1.15, daylight)
		_directional_light.light_color = Color(0.48, 0.58, 0.92).lerp(Color(1.0, 0.91, 0.76), daylight)
		if twilight > 0.0:
			_directional_light.light_color = _directional_light.light_color.lerp(Color(1.0, 0.48, 0.27), twilight * 0.58)
		_directional_light.rotation = Vector3(
			lerpf(deg_to_rad(12.0), deg_to_rad(-62.0), daylight),
			deg_to_rad(-35.0),
			0.0
		)


func _is_night() -> bool:
	return sin((time_of_day - 0.25) * TAU) < -0.08


func _create_clouds() -> void:
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color(0.94, 0.97, 1.0, 0.78)
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var offsets := [
		Vector3(-78, 0, -62), Vector3(-42, 0, 24), Vector3(-8, 0, -78),
		Vector3(35, 0, -42), Vector3(76, 0, 12), Vector3(48, 0, 72),
		Vector3(-58, 0, 78), Vector3(8, 0, 48)
	]

	for index in range(offsets.size()):
		var cloud_root := Node3D.new()
		cloud_root.name = "SkyCloud_%02d" % index
		add_child(cloud_root)
		_add_cloud_puff(cloud_root, cloud_material, Vector3.ZERO, Vector3(1.8, 0.52, 1.0))
		_add_cloud_puff(cloud_root, cloud_material, Vector3(-3.2, 0.25, 0.4), Vector3(1.25, 0.42, 0.82))
		_add_cloud_puff(cloud_root, cloud_material, Vector3(3.0, 0.15, -0.2), Vector3(1.35, 0.44, 0.88))
		_add_cloud_puff(cloud_root, cloud_material, Vector3(0.3, 0.65, 1.8), Vector3(1.0, 0.38, 0.72))
		_clouds.append(cloud_root)
		_cloud_offsets.append(offsets[index])


func _add_cloud_puff(parent: Node3D, material: StandardMaterial3D, local_position: Vector3, puff_scale: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.0
	sphere.height = 2.2
	puff.mesh = sphere
	puff.material_override = material
	puff.position = local_position
	puff.scale = puff_scale
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(puff)


func _update_clouds(delta: float) -> void:
	var anchor := Vector3.ZERO
	if is_instance_valid(_player):
		anchor = _player.global_position

	for index in range(_clouds.size()):
		var offset := _cloud_offsets[index]
		offset.x += CLOUD_DRIFT_SPEED * delta
		if offset.x > 110.0:
			offset.x = -110.0
		_cloud_offsets[index] = offset
		var cloud := _clouds[index]
		if is_instance_valid(cloud):
			cloud.global_position = anchor + Vector3(offset.x, CLOUD_ALTITUDE, offset.z)


func _launch_firework() -> void:
	var rocket := Node3D.new()
	rocket.name = "FireworkRocket"
	add_child(rocket)
	rocket.global_position = FIREWORK_LAUNCH_POINT

	var trail := GPUParticles3D.new()
	trail.name = "FireworkTrail"
	trail.amount = 22
	trail.lifetime = 0.65
	trail.emitting = true
	trail.local_coords = false
	trail.draw_pass_1 = _make_particle_mesh(0.075)
	var trail_process := ParticleProcessMaterial.new()
	trail_process.direction = Vector3(0.0, 1.0, 0.0)
	trail_process.spread = 9.0
	trail_process.initial_velocity_min = 0.5
	trail_process.initial_velocity_max = 1.4
	trail_process.gravity = Vector3(0.0, -0.8, 0.0)
	trail_process.scale_min = 0.45
	trail_process.scale_max = 0.8
	trail_process.color = Color(1.0, 0.72, 0.28, 1.0)
	trail.process_material = trail_process
	rocket.add_child(trail)

	var burst_height := randf_range(22.0, 34.0)
	var burst_offset := Vector3(randf_range(-5.0, 5.0), burst_height, randf_range(-5.0, 5.0))
	var tween := create_tween()
	tween.tween_property(rocket, "global_position", FIREWORK_LAUNCH_POINT + burst_offset, 1.35)
	tween.finished.connect(_finish_firework.bind(rocket))


func _finish_firework(rocket: Node3D) -> void:
	if not is_instance_valid(rocket):
		return
	var burst_position := rocket.global_position
	rocket.queue_free()

	var burst := GPUParticles3D.new()
	burst.name = "FireworkBurst"
	burst.amount = 76
	burst.lifetime = 1.8
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	burst.local_coords = false
	burst.draw_pass_1 = _make_particle_mesh(0.11)

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.25
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.initial_velocity_min = 7.0
	process_material.initial_velocity_max = 14.0
	process_material.gravity = Vector3(0.0, -3.6, 0.0)
	process_material.damping_min = 0.25
	process_material.damping_max = 0.8
	process_material.scale_min = 0.55
	process_material.scale_max = 1.0
	process_material.color = Color.from_hsv(randf(), 0.88, 1.0, 1.0)
	burst.process_material = process_material
	add_child(burst)
	burst.global_position = burst_position
	burst.finished.connect(burst.queue_free)


func _make_particle_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh
