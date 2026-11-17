extends Control
## أيقونات HUD متجهية أصلية بلمسة ذهبية مصرية.

var mode: String = "scooter"

func set_mode(value: String) -> void:
	mode = value
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	if mode != "scooter" and mode != "feet":
		_draw_hud_symbol(center)
		return
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


func _draw_hud_symbol(c: Vector2) -> void:
	var g := Color("#e8c477")
	var glow := Color("#e8c477", 0.22)
	var s := minf(size.x, size.y) / 54.0
	var w := 2.4 * s
	match mode:
		"phone":
			draw_rounded_rect(Rect2(c + Vector2(-10, -17) * s, Vector2(20, 34) * s), 3.0 * s, g, false, w)
			draw_line(c + Vector2(-5, -11) * s, c + Vector2(5, -11) * s, g, w, true)
			draw_circle(c + Vector2(0, 12) * s, 1.4 * s, g)
		"notifications":
			draw_arc(c + Vector2(0, -1) * s, 11 * s, PI, TAU, 32, g, w, true)
			draw_line(c + Vector2(-11, -1) * s, c + Vector2(-11, 7) * s, g, w, true)
			draw_line(c + Vector2(11, -1) * s, c + Vector2(11, 7) * s, g, w, true)
			draw_line(c + Vector2(-14, 7) * s, c + Vector2(14, 7) * s, g, w, true)
			draw_arc(c + Vector2(0, 7) * s, 4 * s, 0, PI, 12, g, w, true)
			draw_circle(c + Vector2(0, -16) * s, 2.0 * s, g)
		"car":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-19, 4)*s,c + Vector2(-14,-7)*s,c + Vector2(10,-7)*s,c + Vector2(18,3)*s,c + Vector2(18,10)*s,c + Vector2(-19,10)*s]), glow)
			draw_line(c + Vector2(-19, 4)*s,c + Vector2(18,4)*s,g,w,true)
			draw_line(c + Vector2(-14,-7)*s,c + Vector2(10,-7)*s,g,w,true)
			draw_line(c + Vector2(-19,4)*s,c + Vector2(-19,10)*s,g,w,true)
			draw_line(c + Vector2(18,4)*s,c + Vector2(18,10)*s,g,w,true)
			draw_circle(c + Vector2(-11,11)*s,3.2*s,g)
			draw_circle(c + Vector2(11,11)*s,3.2*s,g)
		"location":
			draw_arc(c + Vector2(0,-5)*s, 11*s, PI*0.12, PI*0.88, 28, g, w, true)
			draw_line(c + Vector2(-10,-1)*s,c + Vector2(0,18)*s,g,w,true)
			draw_line(c + Vector2(10,-1)*s,c + Vector2(0,18)*s,g,w,true)
			draw_circle(c + Vector2(0,-5)*s,3.2*s,g)
		"chat":
			draw_rounded_rect(Rect2(c + Vector2(-17,-12)*s,Vector2(34,24)*s),5*s,g,false,w)
			draw_line(c + Vector2(-8,12)*s,c + Vector2(-14,18)*s,g,w,true)
			draw_line(c + Vector2(-14,18)*s,c + Vector2(-4,12)*s,g,w,true)
			for i in range(3):
				draw_circle(c + Vector2((-7 + i*7),0)*s,1.6*s,g)
		"friends":
			draw_circle(c + Vector2(-6,-7)*s,5*s,g,false,w)
			draw_circle(c + Vector2(8,-5)*s,4*s,g,false,w)
			draw_arc(c + Vector2(-6,9)*s,10*s,PI,TAU,24,g,w,true)
			draw_arc(c + Vector2(8,10)*s,8*s,PI,TAU,20,g,w,true)
		"emotes":
			draw_circle(c,15*s,g,false,w)
			draw_arc(c + Vector2(0,1)*s,8*s,0.18,PI-0.18,20,g,w,true)
			draw_circle(c + Vector2(-6,-5)*s,1.7*s,g)
			draw_circle(c + Vector2(6,-5)*s,1.7*s,g)
		"hand":
			draw_line(c + Vector2(-9,17)*s,c + Vector2(-9,-4)*s,g,w,true)
			draw_line(c + Vector2(-9,-4)*s,c + Vector2(-9,-15)*s,g,w,true)
			draw_line(c + Vector2(-9,-15)*s,c + Vector2(-5,-17)*s,g,w,true)
			draw_line(c + Vector2(-5,-17)*s,c + Vector2(-2,-4)*s,g,w,true)
			draw_line(c + Vector2(-2,-4)*s,c + Vector2(-2,-18)*s,g,w,true)
			draw_line(c + Vector2(-2,-18)*s,c + Vector2(2,-18)*s,g,w,true)
			draw_line(c + Vector2(2,-18)*s,c + Vector2(4,-4)*s,g,w,true)
			draw_line(c + Vector2(4,-4)*s,c + Vector2(6,-15)*s,g,w,true)
			draw_line(c + Vector2(6,-15)*s,c + Vector2(10,-13)*s,g,w,true)
			draw_line(c + Vector2(10,-13)*s,c + Vector2(11,7)*s,g,w,true)
			draw_line(c + Vector2(11,7)*s,c + Vector2(4,17)*s,g,w,true)
			draw_line(c + Vector2(4,17)*s,c + Vector2(-9,17)*s,g,w,true)
		_:
			draw_circle(c,12*s,g,false,w)
