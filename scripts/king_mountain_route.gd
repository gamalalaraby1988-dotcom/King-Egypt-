extends Node3D

const CityCollisionProfile = preload("res://scripts/city_collision_profile.gd")

const ROAD_WIDTH := 8.0
const ROAD_THICKNESS := 0.42
const ROUTE_POINTS := [
	Vector3(45.0, 0.1, 88.0),
	Vector3(72.0, 6.5, 110.0),
	Vector3(72.0, 13.0, 134.0),
	Vector3(38.0, 19.5, 156.0),
	Vector3(38.0, 26.0, 180.0),
	Vector3(64.0, 32.5, 202.0)
]

func _ready() -> void:
	_build_mountain_base()
	_build_city_approach()
	_build_approach_gate()
	_build_road()
	_build_turn_guard_connectors()
	_build_turn_aprons()
	_build_wayfinding_lights()
	_build_rock_outcrops()
	_build_rest_stops()
	_build_turn_direction_signs()
	_build_summit_terrace()


func get_gate_position() -> Vector3:
	return ROUTE_POINTS[0] + Vector3(0.0, 1.15, -2.0)


func get_summit_position() -> Vector3:
	return ROUTE_POINTS[ROUTE_POINTS.size() - 1] + Vector3(0.0, 1.2, 5.0)


func _build_mountain_base() -> void:
	# امتداد أرضي صلب خلف المخيم حتى لا ينتهي العالم عند حافة شبكة المدينة.
	_add_box("MountainFooting", Vector3(112.0, 0.8, 150.0), Vector3(56.0, -0.75, 151.0), Color(0.28, 0.25, 0.21), true)
	# كتل صخرية جانبية متدرجة تعطي الجبل كتلة بصرية دون سد طريق الصعود.
	_add_box("MountainRockMassLower", Vector3(34.0, 10.0, 44.0), Vector3(20.0, 4.5, 128.0), Color(0.39, 0.34, 0.28), false)
	_add_box("MountainRockMassMid", Vector3(30.0, 12.0, 42.0), Vector3(101.0, 10.0, 153.0), Color(0.34, 0.30, 0.25), false)
	_add_box("MountainRockMassUpper", Vector3(34.0, 14.0, 38.0), Vector3(12.0, 18.0, 184.0), Color(0.43, 0.37, 0.29), false)



func _build_city_approach() -> void:
	# وصلة مباشرة من نهاية طريق المخيم إلى بوابة الجبل، دون فجوة ترابية.
	var start := Vector3(45.0, 0.0, 76.5)
	var finish := ROUTE_POINTS[0]
	var delta := finish - start
	var basis := Basis.looking_at(delta.normalized(), Vector3.UP)
	var center := (start + finish) * 0.5
	_add_oriented_box("MountainCityApproachRoad", Vector3(ROAD_WIDTH, ROAD_THICKNESS, delta.length() + 0.4), center, basis, Color(0.23, 0.23, 0.22), true)


func _build_approach_gate() -> void:
	var gate := Node3D.new()
	gate.name = "KingsMountainEntranceGate"
	gate.position = ROUTE_POINTS[0]
	add_child(gate)
	_add_box_to(gate, "GateLeftPillar", Vector3(0.9, 4.6, 1.0), Vector3(-5.0, 2.3, 0.0), Color(0.62, 0.50, 0.34), true)
	_add_box_to(gate, "GateRightPillar", Vector3(0.9, 4.6, 1.0), Vector3(5.0, 2.3, 0.0), Color(0.62, 0.50, 0.34), true)
	_add_box_to(gate, "GateRoyalLintel", Vector3(10.8, 0.7, 1.1), Vector3(0.0, 4.65, 0.0), Color(0.82, 0.65, 0.29), true)
	_add_box_to(gate, "GateNamePlate", Vector3(6.0, 0.8, 0.22), Vector3(0.0, 3.75, -0.62), Color(0.12, 0.18, 0.19), false)
	var gate_title := Label3D.new()
	gate_title.name = "MountainGateTitle"
	gate_title.text = "قمة الملوك"
	gate_title.position = Vector3(0.0, 3.75, -0.76)
	gate_title.rotation.y = PI
	gate_title.font_size = 64
	gate_title.outline_size = 10
	gate_title.pixel_size = 0.005
	gate_title.modulate = Color(1.0, 0.84, 0.48)
	gate_title.no_depth_test = false
	gate.add_child(gate_title)
	var gate_subtitle := Label3D.new()
	gate_subtitle.name = "MountainGateSubtitle"
	gate_subtitle.text = "طريق الصعود"
	gate_subtitle.position = Vector3(0.0, 3.12, -0.76)
	gate_subtitle.rotation.y = PI
	gate_subtitle.font_size = 30
	gate_subtitle.outline_size = 7
	gate_subtitle.pixel_size = 0.005
	gate_subtitle.modulate = Color(0.92, 0.87, 0.72)
	gate.add_child(gate_subtitle)
	# إضاءة مركزة على اسم القمة لتظل البوابة مقروءة ليلًا دون وهج على الطريق.
	var gate_light := OmniLight3D.new()
	gate_light.name = "MountainGateSignGlow"
	gate_light.position = Vector3(0.0, 4.25, -1.35)
	gate_light.light_color = Color(1.0, 0.78, 0.43)
	gate_light.light_energy = 0.8
	gate_light.omni_range = 7.0
	gate_light.shadow_enabled = false
	gate.add_child(gate_light)


func _build_road() -> void:
	for i in range(ROUTE_POINTS.size() - 1):
		var start: Vector3 = ROUTE_POINTS[i]
		var finish: Vector3 = ROUTE_POINTS[i + 1]
		var delta := finish - start
		var length := delta.length() + 0.35
		var direction := delta.normalized()
		var basis := Basis.looking_at(direction, Vector3.UP)
		var center := (start + finish) * 0.5
		_add_oriented_box("MountainRoadSegment_%02d" % i, Vector3(ROAD_WIDTH, ROAD_THICKNESS, length), center, basis, Color(0.23, 0.23, 0.22), true)
		# خط إرشادي ذهبي رفيع في منتصف المسار.
		_add_oriented_box("MountainRoadCenterGuide_%02d" % i, Vector3(0.10, 0.025, maxf(1.0, length - 1.2)), center + basis.y * (ROAD_THICKNESS * 0.5 + 0.018), basis, Color(0.70, 0.56, 0.30), false)
		# حواجز صلبة على حافتي الطريق، مع فتح عرض الطريق بالكامل.
		for side in [-1.0, 1.0]:
			var rail_center: Vector3 = center + basis.x * side * (ROAD_WIDTH * 0.5 + 0.28) + basis.y * 0.88
			_add_oriented_box("MountainGuardWall_%02d_%s" % [i, "L" if side < 0.0 else "R"], Vector3(0.56, 1.35, length), rail_center, basis, Color(0.48, 0.40, 0.31), true)
			var gold_center: Vector3 = rail_center + basis.y * 0.72
			_add_oriented_box("MountainGuardGoldRail_%02d_%s" % [i, "L" if side < 0.0 else "R"], Vector3(0.18, 0.16, length), gold_center, basis, Color(0.82, 0.65, 0.29), true)



func _build_turn_guard_connectors() -> void:
	# تصل حواجز المنعطفات ببعضها حتى لا تبقى فتحات عند التقاء مقاطع الطريق.
	for i in range(1, ROUTE_POINTS.size() - 1):
		var point: Vector3 = ROUTE_POINTS[i]
		var incoming: Vector3 = (point - ROUTE_POINTS[i - 1]).normalized()
		var outgoing: Vector3 = (ROUTE_POINTS[i + 1] - point).normalized()
		var incoming_side := Vector3.UP.cross(incoming).normalized()
		var outgoing_side := Vector3.UP.cross(outgoing).normalized()
		for side_sign in [-1.0, 1.0]:
			var incoming_edge: Vector3 = point + incoming_side * side_sign * (ROAD_WIDTH * 0.5 + 0.28)
			var outgoing_edge: Vector3 = point + outgoing_side * side_sign * (ROAD_WIDTH * 0.5 + 0.28)
			var connector := outgoing_edge - incoming_edge
			if connector.length() < 0.5:
				continue
			var basis := Basis.looking_at(connector.normalized(), Vector3.UP)
			var center := (incoming_edge + outgoing_edge) * 0.5 + Vector3.UP * 0.88
			var guard_name := "MountainTurnGuardConnector_%02d_%s" % [i, "L" if side_sign < 0.0 else "R"]
			if get_node_or_null(guard_name + "Collision") != null:
				continue
			var guard_size := Vector3(0.56, 1.35, connector.length() + 0.35)
			var guard_color := Color(0.48, 0.40, 0.31)
			# Build the visual and its collider explicitly here. This avoids relying on
			# the generic box helper to create a separately named collision child.
			_add_oriented_box(guard_name, guard_size, center, basis, guard_color, false)
			# Continue the gold safety rail across the bend so the barrier reads as one line.
			_add_oriented_box(
				guard_name + "GoldRail",
				Vector3(0.18, 0.16, connector.length() + 0.35),
				center + basis.y * 0.72,
				basis,
				Color(0.82, 0.65, 0.29),
				false
			)
			var guard_body := StaticBody3D.new()
			guard_body.name = guard_name + "Collision"
			CityCollisionProfile.apply_world_collision(guard_body)
			var guard_shape_node := CollisionShape3D.new()
			guard_shape_node.name = "CollisionShape3D"
			var guard_shape := BoxShape3D.new()
			guard_shape.size = guard_size
			guard_shape_node.shape = guard_shape
			guard_body.transform = Transform3D(basis, center)
			guard_body.add_child(guard_shape_node)
			add_child(guard_body)


func _build_turn_aprons() -> void:
	# توسعات صغيرة عند المنعطفات تمنع الفواصل الحادة بين مقاطع الطريق.
	for i in range(1, ROUTE_POINTS.size() - 1):
		var incoming: Vector3 = (ROUTE_POINTS[i] - ROUTE_POINTS[i - 1]).normalized()
		var outgoing: Vector3 = (ROUTE_POINTS[i + 1] - ROUTE_POINTS[i]).normalized()
		var tangent := (incoming + outgoing).normalized()
		if tangent.length() < 0.1:
			tangent = outgoing
		var basis := Basis.looking_at(tangent, Vector3.UP)
		_add_oriented_box("MountainTurnApron_%02d" % i, Vector3(9.2, ROAD_THICKNESS, 9.2), ROUTE_POINTS[i], basis, Color(0.25, 0.24, 0.22), true)
		# وصلة إرشاد ذهبية فوق توسعة المنعطف حتى لا ينقطع خط الطريق بصريًا.
		_add_oriented_box("MountainTurnGuide_%02d" % i, Vector3(0.10, 0.025, 7.6), ROUTE_POINTS[i] + Vector3.UP * (ROAD_THICKNESS * 0.5 + 0.025), basis, Color(0.70, 0.56, 0.30), false)

func _build_wayfinding_lights() -> void:
	# أعمدة إنارة وإرشاد خارج حافة الحواجز؛ لا تقترب من حيز قيادة المركبات.
	for i in range(ROUTE_POINTS.size()):
		var previous: Vector3 = ROUTE_POINTS[maxi(0, i - 1)]
		var following: Vector3 = ROUTE_POINTS[mini(ROUTE_POINTS.size() - 1, i + 1)]
		var forward := (following - previous).normalized()
		var side := Vector3.UP.cross(forward).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var side_sign := -1.0 if i % 2 == 0 else 1.0
		var lamp_position: Vector3 = ROUTE_POINTS[i] + side * side_sign * 6.4
		_add_box("MountainWayfindingLampPost_%02d" % i, Vector3(0.32, 3.0, 0.32), lamp_position + Vector3.UP * 1.5, Color(0.49, 0.39, 0.25), true)
		_add_box("MountainWayfindingLampCap_%02d" % i, Vector3(0.72, 0.32, 0.72), lamp_position + Vector3.UP * 3.12, Color(0.82, 0.65, 0.30), false)
		var glow := OmniLight3D.new()
		glow.name = "MountainWayfindingGlow_%02d" % i
		glow.position = lamp_position + Vector3.UP * 3.0
		glow.light_color = Color(1.0, 0.78, 0.43)
		glow.light_energy = 0.65
		glow.omni_range = 8.0
		glow.shadow_enabled = false
		add_child(glow)
	# أضواء منخفضة إضافية في منتصف كل مقطع لتقليل المناطق المظلمة بين الأعمدة.
	for segment_index in range(ROUTE_POINTS.size() - 1):
		var start: Vector3 = ROUTE_POINTS[segment_index]
		var finish: Vector3 = ROUTE_POINTS[segment_index + 1]
		var forward := (finish - start).normalized()
		var side := Vector3.UP.cross(forward).normalized()
		var side_sign := 1.0 if segment_index % 2 == 0 else -1.0
		var marker_position: Vector3 = (start + finish) * 0.5 + side * side_sign * 5.6 + Vector3.UP * 1.1
		_add_warm_light("MountainSegmentGuideGlow_%02d" % segment_index, marker_position, 0.42, 6.5)

func _build_rock_outcrops() -> void:
	# كتل صخرية زخرفية على مسافة آمنة خارج الحواجز.
	_add_box("MountainRockOutcrop_00", Vector3(5.0, 3.8, 6.0), Vector3(27.0, 2.0, 145.0), Color(0.37, 0.32, 0.27), true)
	_add_box("MountainRockOutcrop_01", Vector3(6.0, 5.0, 5.0), Vector3(88.0, 4.0, 176.0), Color(0.33, 0.29, 0.25), true)
	_add_box("MountainRockOutcrop_02", Vector3(5.5, 4.5, 6.5), Vector3(22.0, 8.0, 193.0), Color(0.42, 0.36, 0.29), true)
	_add_box("MountainRockOutcrop_03", Vector3(4.5, 3.2, 5.0), Vector3(84.0, 0.5, 119.0), Color(0.39, 0.34, 0.29), true)

func _build_rest_stops() -> void:
	# فسحات جانبية خارج مسار المركبات؛ لا توضع المقاعد على الطريق.
	var stop_indices := [1, 3]
	for stop_number in range(stop_indices.size()):
		var route_index: int = stop_indices[stop_number]
		var point: Vector3 = ROUTE_POINTS[route_index]
		var incoming: Vector3 = (point - ROUTE_POINTS[route_index - 1]).normalized()
		var outgoing: Vector3 = (ROUTE_POINTS[route_index + 1] - point).normalized()
		# استخدم مماس منتصف المنعطف حتى تصطف الفسحة مع الطريق من الجهتين.
		var forward: Vector3 = (incoming + outgoing).normalized()
		if forward.length_squared() < 0.001:
			forward = outgoing
		var side := Vector3.UP.cross(forward).normalized()
		var view_basis := Basis(-side, Vector3.UP, -forward)
		var pad_center := point + side * 8.5 + Vector3.UP * 0.12
		_add_oriented_box("MountainRestBay_%d" % stop_number, Vector3(7.0, 0.32, 7.0), pad_center, view_basis, Color(0.56, 0.47, 0.36), true)
		_add_oriented_box("MountainRestBench_%d" % stop_number, Vector3(2.8, 0.55, 0.75), pad_center + side * 0.9 + Vector3.UP * 0.42, view_basis, Color(0.30, 0.27, 0.23), true)
		_add_box("MountainRestLantern_%d" % stop_number, Vector3(0.28, 2.4, 0.28), pad_center - side * 2.4 + Vector3.UP * 1.2, Color(0.78, 0.59, 0.27), true)
		_add_warm_light("MountainRestGlow_%d" % stop_number, pad_center - side * 2.4 + Vector3.UP * 2.7, 0.85, 9.0)
		# لوحة تعريف صغيرة داخل فسحة الاستراحة، بعيدة عن مسار الطريق.
		var rest_sign_position: Vector3 = pad_center + side * 2.0 + Vector3.UP * 1.55
		_add_oriented_box("MountainRestSignBoard_%d" % stop_number, Vector3(2.2, 0.9, 0.16), rest_sign_position, view_basis, Color(0.12, 0.18, 0.19), true)
		var rest_sign_label := Label3D.new()
		rest_sign_label.name = "MountainRestSignLabel_%d" % stop_number
		rest_sign_label.text = "استراحة %d\nتابع الصعود للقمة" % (stop_number + 1)
		rest_sign_label.position = rest_sign_position + Vector3.UP * 0.02
		rest_sign_label.rotation.y = atan2(forward.x, forward.z)
		rest_sign_label.font_size = 34
		rest_sign_label.outline_size = 8
		rest_sign_label.pixel_size = 0.006
		rest_sign_label.modulate = Color(1.0, 0.86, 0.58)
		add_child(rest_sign_label)
		_add_warm_light("MountainRestSignGlow_%d" % stop_number, rest_sign_position + Vector3.UP * 0.85, 0.55, 5.5)
		# منصة المشاهدة وحواجزها تتبع اتجاه المسار بدل محاور العالم، وتبقى جهة الاستراحة مفتوحة.
		var view_center := pad_center + side * 5.2
		_add_oriented_box("MountainViewDeck_%d" % stop_number, Vector3(8.0, 0.32, 7.0), view_center, view_basis, Color(0.61, 0.52, 0.39), true)
		_add_oriented_box("MountainViewDeckOuterRail_%d" % stop_number, Vector3(0.38, 1.15, 7.0), view_center + side * 3.8 + Vector3.UP * 0.72, view_basis, Color(0.48, 0.40, 0.31), true)
		_add_oriented_box("MountainViewDeckLeftRail_%d" % stop_number, Vector3(8.0, 1.15, 0.38), view_center - forward * 3.3 + Vector3.UP * 0.72, view_basis, Color(0.48, 0.40, 0.31), true)
		_add_oriented_box("MountainViewDeckRightRail_%d" % stop_number, Vector3(8.0, 1.15, 0.38), view_center + forward * 3.3 + Vector3.UP * 0.72, view_basis, Color(0.48, 0.40, 0.31), true)
		# درابزين ذهبي علوي متصل مع الحواجز الحجرية دون إضافة عوائق عند فتحة الدخول.
		_add_oriented_box("MountainViewDeckOuterGoldRail_%d" % stop_number, Vector3(0.20, 0.14, 7.0), view_center + side * 3.8 + Vector3.UP * 1.37, view_basis, Color(0.82, 0.65, 0.29), false)
		_add_oriented_box("MountainViewDeckLeftGoldRail_%d" % stop_number, Vector3(8.0, 0.14, 0.20), view_center - forward * 3.3 + Vector3.UP * 1.37, view_basis, Color(0.82, 0.65, 0.29), false)
		_add_oriented_box("MountainViewDeckRightGoldRail_%d" % stop_number, Vector3(8.0, 0.14, 0.20), view_center + forward * 3.3 + Vector3.UP * 1.37, view_basis, Color(0.82, 0.65, 0.29), false)


func _build_turn_direction_signs() -> void:
	# لوحات تحذير على الكتف الخارجي للمنعطفات؛ تبقى خارج عرض الطريق والحواجز.
	for route_index in range(1, ROUTE_POINTS.size() - 1):
		var point: Vector3 = ROUTE_POINTS[route_index]
		var incoming: Vector3 = (point - ROUTE_POINTS[route_index - 1]).normalized()
		var outgoing: Vector3 = (ROUTE_POINTS[route_index + 1] - point).normalized()
		var forward: Vector3 = (incoming + outgoing).normalized()
		if forward.length_squared() < 0.001:
			forward = outgoing
		var side: Vector3 = Vector3.UP.cross(forward).normalized()
		var turn_strength: float = incoming.cross(outgoing).y
		var outer_sign: float = -1.0 if turn_strength > 0.0 else 1.0
		var sign_position: Vector3 = point + side * outer_sign * 7.2 + Vector3.UP * 1.55
		var sign_basis: Basis = Basis.looking_at(-forward, Vector3.UP)
		var sign_root := Node3D.new()
		sign_root.name = "MountainTurnWarning_%02d" % route_index
		sign_root.position = sign_position
		add_child(sign_root)
		_add_box_to(sign_root, "WarningPost", Vector3(0.22, 2.8, 0.22), Vector3(0.0, -0.15, 0.0), Color(0.49, 0.39, 0.25), true)
		_add_oriented_box_to(sign_root, "WarningBoard", Vector3(1.9, 1.05, 0.16), Vector3.ZERO, sign_basis, Color(0.12, 0.18, 0.19), true)
		var warning_label := Label3D.new()
		warning_label.name = "WarningLabel"
		warning_label.text = "⚠  خفّف السرعة"
		warning_label.position = Vector3(0.0, 0.0, -0.105)
		warning_label.rotation.y = PI
		warning_label.font_size = 30
		warning_label.outline_size = 7
		warning_label.pixel_size = 0.005
		warning_label.modulate = Color(1.0, 0.84, 0.48)
		sign_root.add_child(warning_label)
		_add_warm_light("MountainTurnWarningGlow_%02d" % route_index, sign_position + Vector3.UP * 0.75, 0.42, 5.0)


func _build_summit_terrace() -> void:
	var summit: Vector3 = ROUTE_POINTS[ROUTE_POINTS.size() - 1]
	var summit_forward: Vector3 = (summit - ROUTE_POINTS[ROUTE_POINTS.size() - 2]).normalized()
	var summit_side: Vector3 = Vector3.UP.cross(summit_forward).normalized()
	var summit_basis: Basis = Basis(-summit_side, Vector3.UP, -summit_forward)
	var platform_center: Vector3 = summit + Vector3.UP * -0.5 + summit_forward * 5.0
	_add_oriented_box("MountainSummitPlatform", Vector3(34.0, 1.0, 34.0), platform_center, summit_basis, Color(0.52, 0.45, 0.35), true)
	# الحواجز تتبع اتجاه الوصول الفعلي وتترك فتحة واسعة على امتداد طريق الصعود.
	for side_sign in [-1.0, 1.0]:
		var side_center: Vector3 = summit + summit_side * side_sign * 15.0 + Vector3.UP * 0.8 + summit_forward * 5.0
		_add_oriented_box("MountainSummitSideBarrier_%d" % int(side_sign), Vector3(0.65, 1.6, 30.0), side_center, summit_basis, Color(0.36, 0.31, 0.25), true)
		_add_oriented_box("MountainSummitSideGoldRail_%d" % int(side_sign), Vector3(0.20, 0.14, 30.0), side_center + Vector3.UP * 0.87, summit_basis, Color(0.82, 0.65, 0.29), false)
	var rear_center: Vector3 = summit + summit_forward * 21.0 + Vector3.UP * 0.8
	_add_oriented_box("MountainSummitRearBarrier", Vector3(30.0, 1.6, 0.65), rear_center, summit_basis, Color(0.36, 0.31, 0.25), true)
	_add_oriented_box("MountainSummitRearGoldRail", Vector3(30.0, 0.14, 0.20), rear_center + Vector3.UP * 0.87, summit_basis, Color(0.82, 0.65, 0.29), false)
	var obelisk_position: Vector3 = summit - summit_side * 9.0 + summit_forward * 7.0
	_add_oriented_box("MountainSummitObeliskBase", Vector3(4.0, 0.6, 4.0), obelisk_position + Vector3.UP * 0.8, summit_basis, Color(0.36, 0.31, 0.25), true)
	_add_oriented_box("MountainSummitObelisk", Vector3(0.65, 5.0, 0.65), obelisk_position + Vector3.UP * 3.6, summit_basis, Color(0.86, 0.68, 0.29), true)
	_add_warm_light("MountainSummitObeliskGlow", obelisk_position + Vector3.UP * 6.0, 1.1, 14.0)
	for side_sign in [-1.0, 1.0]:
		var bench_position: Vector3 = summit + summit_side * side_sign * 10.0 + summit_forward * 9.0
		_add_oriented_box("MountainSummitBench_%d" % int(side_sign), Vector3(3.0, 0.5, 0.8), bench_position + Vector3.UP * 0.45, summit_basis, Color(0.32, 0.28, 0.23), true)


func _add_warm_light(light_name: String, light_position: Vector3, energy: float, light_range: float) -> void:
	var glow := OmniLight3D.new()
	glow.name = light_name
	glow.position = light_position
	glow.light_color = Color(1.0, 0.76, 0.43)
	glow.light_energy = energy
	glow.omni_range = light_range
	glow.shadow_enabled = false
	add_child(glow)


func _add_box(name: String, size: Vector3, position: Vector3, color: Color, collision: bool) -> void:
	_add_box_to(self, name, size, position, color, collision)


func _add_box_to(parent: Node3D, name: String, size: Vector3, position: Vector3, color: Color, collision: bool) -> void:
	_add_oriented_box_to(parent, name, size, position, Basis.IDENTITY, color, collision)


func _add_oriented_box(name: String, size: Vector3, position: Vector3, basis: Basis, color: Color, collision: bool) -> void:
	_add_oriented_box_to(self, name, size, position, basis, color, collision)


func _add_oriented_box_to(parent: Node3D, name: String, size: Vector3, position: Vector3, basis: Basis, color: Color, collision: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.transform = Transform3D(basis, position)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	if not collision:
		return
	var body := StaticBody3D.new()
	body.name = name + "Collision"
	CityCollisionProfile.apply_world_collision(body)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.transform = Transform3D(basis, position)
	body.add_child(shape_node)
	parent.add_child(body)
