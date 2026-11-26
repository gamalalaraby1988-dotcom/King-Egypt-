extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_city_street_access_contract")


func _run_city_street_access_contract() -> void:
	var layout_script := load("res://scripts/approved_city_layout.gd") as Script
	_expect(layout_script != null, "Approved city layout script loads")
	if layout_script == null:
		quit(1)
		return

	var layout := Node3D.new()
	layout.set_script(layout_script)
	root.add_child(layout)
	await process_frame

	var access_paths := layout.get_tree().get_nodes_in_group("city_pedestrian_access")
	_expect(access_paths.size() >= 18, "All approved public building entrances have dedicated access paths")
	for path_node in access_paths:
		var path := path_node as MeshInstance3D
		_expect(path != null, "Entrance access path is a visible mesh")
		if path == null:
			continue
		_expect(is_equal_approx(float(path.get_meta("access_width", 0.0)), 3.2), str(path.name) + " uses the standard 3.2 m access width")
		var mesh := path.mesh as BoxMesh
		_expect(mesh != null and is_equal_approx(mesh.size.x, 3.2), str(path.name) + " visible width matches the standard")
		var body := layout.get_node_or_null(str(path.name) + "WalkCollision") as StaticBody3D
		_expect(body != null, str(path.name) + " has matching walkable collision")
		if body != null:
			var collision := body.get_child(0) as CollisionShape3D
			var shape := collision.shape as BoxShape3D if collision != null else null
			_expect(shape != null and is_equal_approx(shape.size.x, 3.2), str(path.name) + " collision width matches its visible mesh")

	var main_script := load("res://scripts/main.gd") as Script
	_expect(main_script != null, "Main city script loads for curb-cut validation")
	if main_script != null:
		var city_root := Node3D.new()
		city_root.set_script(main_script)
		city_root.call("_create_city_pedestrian_network")
		var curb_segments: Array[Node] = []
		for child in city_root.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("Curb_H_"):
				curb_segments.append(child)
		_expect(not curb_segments.is_empty(), "Horizontal curb segments are generated")
		var access_centres := [
			Vector2(-30.0, -19.92), Vector2(30.0, -19.92), Vector2(60.0, -19.92),
			Vector2(-60.0, 10.08), Vector2(0.0, 10.08), Vector2(60.0, 10.08),
			Vector2(-60.0, 40.08), Vector2(-30.0, 40.08), Vector2(0.0, 40.08), Vector2(30.0, 40.08)
		]
		for entrance in access_centres:
			var blocked := false
			for curb_node in curb_segments:
				var curb := curb_node as MeshInstance3D
				var mesh := curb.mesh as BoxMesh
				if mesh == null or not is_equal_approx(curb.position.z, entrance.y):
					continue
				var left := curb.position.x - mesh.size.x * 0.5
				var right := curb.position.x + mesh.size.x * 0.5
				if left < entrance.x + 2.0 and right > entrance.x - 2.0:
					blocked = true
					break
			_expect(not blocked, "Curb opening remains clear at entrance x=%.1f, z=%.2f" % [entrance.x, entrance.y])
		city_root.free()

	layout.queue_free()
	if _failures > 0:
		push_error("City street and entrance access contract failed: %d issue(s)." % _failures)
		quit(1)
		return
	print("City street and entrance access contract passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
