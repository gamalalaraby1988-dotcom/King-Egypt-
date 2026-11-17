extends Control
## أيقونة متجهية تتبدل بين الاسكوتر وآثار القدمين.

var mode: String = "scooter"

func set_mode(value: String) -> void:
	mode = value
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var gold := Color(0.91, 0.73, 0.39, 0.98)
	var dark := Color(0.16, 0.20, 0.24, 0.95)
	var scale_factor := minf(size.x, size.y) / 54.0
	if mode == "feet":
		_draw_footprint(center + Vector2(-7.0, 1.0) * scale_factor, -0.22, gold, scale_factor)
		_draw_footprint(center + Vector2(8.0, -1.0) * scale_factor, 0.22, gold, scale_factor)
	else:
		var rear := center + Vector2(-12.0, 8.0) * scale_factor
		var front := center + Vector2(12.0, 8.0) * scale_factor
		draw_arc(rear, 5.5 * scale_factor, 0.0, TAU, 28, gold, 2.2 * scale_factor, true)
		draw_arc(front, 5.5 * scale_factor, 0.0, TAU, 28, gold, 2.2 * scale_factor, true)
		draw_line(rear + Vector2(0, -1) * scale_factor, center + Vector2(5, 1) * scale_factor, gold, 2.5 * scale_factor, true)
		draw_line(center + Vector2(5, 1) * scale_factor, front + Vector2(0, -1) * scale_factor, gold, 2.5 * scale_factor, true)
		draw_line(center + Vector2(5, 1) * scale_factor, center + Vector2(0, -14) * scale_factor, gold, 2.3 * scale_factor, true)
		draw_line(center + Vector2(-7, -14) * scale_factor, center + Vector2(7, -14) * scale_factor, gold, 2.5 * scale_factor, true)
		draw_circle(center + Vector2(0, -14) * scale_factor, 2.0 * scale_factor, dark)

func _draw_footprint(point: Vector2, angle: float, color: Color, scale_factor: float) -> void:
	var transform := Transform2D(angle, point)
	var sole := PackedVector2Array([
		Vector2(-3.5, -7.0), Vector2(3.5, -7.0), Vector2(4.8, -1.0),
		Vector2(3.6, 6.0), Vector2(0.0, 8.0), Vector2(-3.6, 6.0),
		Vector2(-4.8, -1.0)
	])
	var points := PackedVector2Array()
	for point_local in sole:
		points.append(transform * (point_local * scale_factor))
	draw_colored_polygon(points, color)
	for toe_index in range(3):
		var toe := transform * (Vector2(-2.6 + toe_index * 2.6, -9.0) * scale_factor)
		draw_circle(toe, 1.15 * scale_factor, color)
