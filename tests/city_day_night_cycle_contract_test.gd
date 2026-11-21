extends SceneTree

func _initialize() -> void:
	call_deferred("_run_day_night_contract")


func _run_day_night_contract() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var cycle_source := FileAccess.get_file_as_string("res://scripts/city_day_night_cycle.gd")
	var shader_source := FileAccess.get_file_as_string("res://shaders/royal_cinematic_sky.gdshader")
	if not scene_source.contains('path="res://scripts/city_day_night_cycle.gd"') or not scene_source.contains('[node name="DayNightCycle" type="Node" parent="."]'):
		push_error("The automatic day/night cycle must be attached to the main city scene.")
		quit(1)
		return
	if not cycle_source.contains("cycle_duration_seconds: float = 720.0") or not cycle_source.contains("func _apply_cycle()") or not cycle_source.contains('set_shader_parameter("daylight"') or not cycle_source.contains('set_shader_parameter("sun_direction"'):
		push_error("The day/night controller must advance the cycle and drive the sky shader.")
		quit(1)
		return
	if not cycle_source.contains("_environment.ambient_light_energy") or not cycle_source.contains("_environment.fog_density") or not cycle_source.contains("_directional_light.light_energy"):
		push_error("The day/night cycle must update ambient light, fog, and directional sunlight.")
		quit(1)
		return
	if not shader_source.contains("moon_disc") or not shader_source.contains("float stars =") or not shader_source.contains("uniform float daylight"):
		push_error("The cinematic sky must show the moon and stars at night and blend daylight.")
		quit(1)
		return
	print("City automatic day/night cycle contract passed.")
	quit(0)
