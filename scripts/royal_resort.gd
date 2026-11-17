extends Node3D
## المنتجع الملكي: مدخل بمستوى 500 وست بوابات مناطق بمستويات فتح مستقلة.

const GATE_SCRIPT := preload("res://scripts/royal_resort_gate.gd")
const RESORT_LEVEL := 500
const ZONES := [
	{"id":"royal_square","title":"الساحة الملكية","level":500,"position":Vector3(0,0,0),"spawn":Vector3(0,1,4),"color":Color(0.72,0.60,0.39)},
	{"id":"royal_gardens","title":"الحدائق الملكية","level":1000,"position":Vector3(-20,0,22),"spawn":Vector3(-20,1,26),"color":Color(0.27,0.48,0.29)},
	{"id":"pools","title":"منطقة المسابح","level":1800,"position":Vector3(20,0,22),"spawn":Vector3(20,1,26),"color":Color(0.18,0.55,0.68)},
	{"id":"waterfalls","title":"منطقة الشلالات","level":2600,"position":Vector3(-20,0,48),"spawn":Vector3(-20,1,52),"color":Color(0.30,0.62,0.72)},
	{"id":"royal_suites","title":"الأجنحة الملكية","level":3500,"position":Vector3(20,0,48),"spawn":Vector3(20,1,52),"color":Color(0.66,0.49,0.30)},
	{"id":"party_zone","title":"منطقة الحفلات","level":4500,"position":Vector3(0,0,72),"spawn":Vector3(0,1,76),"color":Color(0.49,0.31,0.55)}
]
var _outside_transform: Transform3D
var _has_outside_transform := false
var _inside := false

func _ready() -> void:
	_build_resort()

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic = metallic
	return material

func _box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = _material(color, 0.18)
	parent.add_child(mesh_instance)

func _label(parent: Node3D, value: String, local_position: Vector3, font_size: int = 42) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = local_position
	label.font_size = font_size
	label.pixel_size = 0.006
	label.outline_size = 9
	label.modulate = Color(1.0, 0.91, 0.68)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _build_resort() -> void:
	# المدخل الرئيسي
	_create_gate("resort_entrance", "بوابة المنتجع الملكي", RESORT_LEVEL, Vector3(0,0,-15), Vector3(0,1,-7), "entrance")
	_box(self, "RoyalResortEntryPlaza", Vector3(20,0.3,12), Vector3(0,0.05,-7), Color(0.55,0.43,0.29))
	_label(self, "𓂀 المنتجع الملكي 𓂀", Vector3(0,4.2,-17), 54)
	# الساحة والمناطق الست، لكل منطقة منصة ومعلم بصري وبوابة مستقلة.
	for zone in ZONES:
		var zone_position: Vector3 = zone["position"]
		var zone_title: String = zone["title"]
		var zone_id: String = zone["id"]
		var zone_color: Color = zone["color"]
		_box(self, "Floor_" + zone_id, Vector3(17,0.28,15), zone_position, zone_color.darkened(0.22))
		_box(self, "Trim_" + zone_id, Vector3(17.4,0.12,0.28), zone_position + Vector3(0,0.2,-7.5), Color(0.84,0.66,0.31))
		_label(self, zone_title, zone_position + Vector3(0,3.1,-5.0), 34)
		_create_gate(zone_id, "بوابة " + zone_title, int(zone["level"]), zone_position + Vector3(0,0,-8.5), zone["spawn"], "zone")
		# أعمدة زخرفية خفيفة تمنح كل منطقة هوية من دون حجب مسارات الحركة.
		for side in [-1.0,1.0]:
			_box(self, "Pillar_" + zone_id, Vector3(0.8,3.0,0.8), zone_position + Vector3(side * 7.0,1.5,-6.5), Color(0.76,0.65,0.45))

	# نقطة تفتح قائمة التنقل السريع داخل المنتجع، ومنها خيار الخروج إلى المدينة.
	_create_gate("resort_quick_travel", "قائمة التنقل السريع", 1, Vector3(8,0,0), Vector3.ZERO, "quick_menu")
	_label(self, "التنقل السريع", Vector3(8,3.2,-2), 26)
	# بوابة خروج ظاهرة من داخل المنتجع.
	_create_gate("resort_exit", "الخروج من المنتجع الملكي", 1, Vector3(0,0,88), Vector3.ZERO, "exit")
	_label(self, "الخروج إلى المدينة", Vector3(0,3.2,91), 32)

func _create_gate(id: String, title: String, level: int, local_position: Vector3, destination: Vector3, kind: String) -> void:
	var gate := Node3D.new()
	gate.name = "Gate_" + id
	gate.set_script(GATE_SCRIPT)
	gate.set("gate_id", id)
	gate.set("gate_title", title)
	gate.set("required_level", level)
	gate.set("destination_offset", destination)
	gate.set("gate_kind", kind)
	gate.position = local_position
	add_child(gate)
	var gold := Color(0.88,0.68,0.30)
	_box(gate, "LeftPillar", Vector3(0.8,4.2,0.9), Vector3(-2.0,2.1,0), gold)
	_box(gate, "RightPillar", Vector3(0.8,4.2,0.9), Vector3(2.0,2.1,0), gold)
	_box(gate, "TopBeam", Vector3(4.8,0.65,0.9), Vector3(0,4.2,0), gold)
	_box(gate, "GatePanel", Vector3(2.8,2.8,0.18), Vector3(0,1.65,0), Color(0.12,0.22,0.23))
	_label(gate, title, Vector3(0,5.0,-0.1), 28)
	_label(gate, "المستوى " + str(level), Vector3(0,0.25,-0.55), 23)

func is_inside_resort() -> bool:
	return _inside

func exit_resort(actor: Node3D) -> void:
	if not _inside or not is_instance_valid(actor):
		return
	if _has_outside_transform:
		actor.global_transform = _outside_transform
	else:
		actor.global_position = to_global(Vector3(0,1,-18))
	_inside = false

func activate_gate(gate: Node3D, actor: Node3D, current_level: int) -> Dictionary:
	if not is_instance_valid(gate) or not is_instance_valid(actor):
		return {"success":false,"message":"تعذر التحقق من البوابة."}
	var data: Dictionary = gate.get_royal_resort_gate_data()
	var required := int(data.get("required_level", 1))
	var kind := str(data.get("gate_kind", "zone"))
	if kind == "entrance":
		if current_level < RESORT_LEVEL:
			return {"success":false,"message":"تحتاج إلى المستوى %d للدخول. مستواك الحالي %d." % [RESORT_LEVEL,current_level]}
		_outside_transform = actor.global_transform
		_has_outside_transform = true
		_inside = true
		actor.global_position = to_global(Vector3(0,1,-7))
		return {"success":true,"message":"مرحبًا بك في المنتجع الملكي."}
	if not _inside:
		return {"success":false,"message":"يجب دخول المنتجع أولًا."}
	if kind == "exit":
		exit_resort(actor)
		return {"success":true,"message":"تم الخروج إلى المدينة."}
	if current_level < required:
		return {"success":false,"message":"هذه المنطقة تفتح عند المستوى %d. مستواك الحالي %d." % [required,current_level]}
	var destination: Vector3 = data.get("destination_offset", Vector3.ZERO)
	actor.global_position = to_global(destination)
	return {"success":true,"message":"تم فتح %s." % str(data.get("title","المنطقة"))}
