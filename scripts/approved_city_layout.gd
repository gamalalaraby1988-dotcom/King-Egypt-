extends Node3D
## Visible first-pass implementation of the approved city master plan.
## All structures are lightweight primitive meshes for Android; detailed interiors remain separate work.

const CityMasterPlan = preload("res://scripts/city_master_plan.gd")

const GOLD := Color(0.78, 0.57, 0.24)
const IVORY := Color(0.82, 0.77, 0.65)
const SAND := Color(0.62, 0.48, 0.31)
const TEAL := Color(0.10, 0.42, 0.43)
const DARK := Color(0.12, 0.16, 0.17)

func _ready() -> void:
	name = "ApprovedCityLayout"
	_build_districts()
	_build_nile_waterfront()
	_build_pyramids()
	_build_royal_gate_and_square()

func _mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.78
	m.metallic = metallic
	return m

func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _mat(color, 0.12 if color == GOLD else 0.0)
	node.add_to_group("city_world_geometry")
	parent.add_child(node)
	return node

func _building(parent: Node3D, id: String, title: String, at: Vector3, footprint: Vector2, height: float, accent: Color = GOLD) -> void:
	var root := Node3D.new()
	root.name = "Approved_" + id
	root.position = at
	root.add_to_group("approved_city_buildings")
	parent.add_child(root)
	var w := footprint.x
	var d := footprint.y
	_box(root, "MainFacade", Vector3(w, height, d), Vector3(0, height * 0.5, 0), IVORY)
	_box(root, "GroundPlinth", Vector3(w + 0.8, 0.7, d + 0.8), Vector3(0, 0.35, 0), SAND)
	_box(root, "RoofCornice", Vector3(w + 0.5, 0.35, d + 0.5), Vector3(0, height + 0.12, 0), accent)
	_box(root, "Entrance", Vector3(maxf(1.5, w * 0.18), 2.8, 0.16), Vector3(0, 1.4, d * 0.5 + 0.09), DARK)
	for side in [-1.0, 1.0]:
		_box(root, "FrontColumn", Vector3(0.38, minf(height - 0.8, 5.0), 0.42), Vector3(side * w * 0.34, minf(height - 0.8, 5.0) * 0.5, d * 0.5 + 0.25), accent)
	var sign := Label3D.new()
	sign.name = "BuildingName"
	sign.text = title
	sign.position = Vector3(0, height + 1.0, d * 0.5 + 0.25)
	sign.font_size = 42
	sign.pixel_size = 0.009
	sign.modulate = Color(1.0, 0.9, 0.64)
	sign.outline_size = 8
	root.add_child(sign)

func _build_districts() -> void:
	# Each position is kept within the current prototype city bounds.
	var entries := [
		["royal_palace","القصر الملكي",Vector3(0,0,-60),Vector2(22,16),12.0],
		["royal_bank","البنك الملكي",Vector3(42,0,-60),Vector2(12,11),8.0],
		["supermarket","السوبر ماركت",Vector3(-30,0,-30),Vector2(10,10),6.0],
		["market","السوق التجاري",Vector3(0,0,-30),Vector2(12,10),6.0],
		["employment_center","مركز التوظيف",Vector3(30,0,-30),Vector2(11,10),7.0],
		["main_restaurant","المطعم الرئيسي",Vector3(60,0,-30),Vector2(12,10),7.0],
		["royal_cafe","المقهى الملكي",Vector3(-60,0,0),Vector2(10,10),6.0],
		["commercial_services","مركز الخدمات التجارية",Vector3(60,0,0),Vector2(12,10),7.0],
		["apartment_palace_1","قصر الشقق الأول",Vector3(-60,0,30),Vector2(12,12),12.0],
		["apartment_palace_2","قصر الشقق الثاني",Vector3(-30,0,30),Vector2(12,12),12.0],
		["apartment_palace_3","قصر الشقق الثالث",Vector3(0,0,30),Vector2(12,12),12.0],
		["apartment_palace_4","قصر الشقق الرابع",Vector3(30,0,30),Vector2(12,12),12.0],
		["cinema","السينما",Vector3(60,0,30),Vector2(12,10),7.0],
		["royal_theater","المسرح الملكي",Vector3(-60,0,60),Vector2(13,11),9.0],
		["stadium","الملعب الرياضي",Vector3(-30,0,60),Vector2(16,12),8.0],
		["sports_club","النادي الرياضي",Vector3(0,0,60),Vector2(12,10),7.0],
		["water_city","المدينة المائية",Vector3(30,0,60),Vector2(14,12),6.0],
		["daily_arcade","مركز DAILY ARCADE",Vector3(60,0,60),Vector2(13,10),8.0],
		["police_station","مركز الشرطة",Vector3(-75,0,-5),Vector2(10,9),7.0],
		["courthouse","المحكمة",Vector3(75,0,-5),Vector2(11,9),8.0],
		["fire_rescue","مركز الإطفاء والإنقاذ",Vector3(-75,0,15),Vector2(11,9),7.0],
		["train_station","محطة القطار",Vector3(75,0,15),Vector2(13,9),7.0],
		["fuel_station","محطة الوقود",Vector3(-75,0,38),Vector2(10,8),5.0],
		["marina_terminal","محطة المارينا البحرية",Vector3(75,0,38),Vector2(13,9),7.0],
		["royal_yacht_club","نادي اليخوت الملكي",Vector3(75,0,58),Vector2(13,9),7.0],
		["adventure_center","مركز المغامرات",Vector3(-75,0,58),Vector2(11,9),7.0],
		["desert_lodge","نزل المخيم الصحراوي الملكي",Vector3(-75,0,75),Vector2(12,10),6.0],
		["mountain_temple","المعبد الملكي أعلى الجبل",Vector3(75,0,75),Vector2(13,11),10.0]
	]
	for i in range(entries.size()):
		var e: Array = entries[i]
		var accent := GOLD if i < 3 or i == 0 else (TEAL if i % 3 == 0 else SAND)
		_building(self, str(e[0]), str(e[1]), e[2], e[3], float(e[4]), accent)

func _build_nile_waterfront() -> void:
	var water := _box(self, "NileWaterfront", Vector3(180, 0.22, 12), Vector3(0, -0.22, 84), Color(0.04, 0.30, 0.39))
	water.material_override = _mat(Color(0.04, 0.30, 0.39), 0.25)
	_box(self, "WaterfrontPromenade", Vector3(180, 0.28, 3.0), Vector3(0, 0.02, 76), SAND)
	for x in [-65.0,-45.0,-25.0,25.0,45.0,65.0]:
		_box(self, "PromenadeLamp", Vector3(0.18, 3.0, 0.18), Vector3(x, 1.5, 74), GOLD)
		_box(self, "PromenadeLampHead", Vector3(0.8, 0.18, 0.8), Vector3(x, 3.0, 74), GOLD)

func _build_pyramids() -> void:
	for i in range(3):
		var pyramid := MeshInstance3D.new()
		pyramid.name = "ApprovedPyramid_%d" % (i + 1)
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 9.0 - i * 1.5
		mesh.height = 15.0 - i * 2.0
		mesh.radial_segments = 4
		mesh.rings = 1
		pyramid.mesh = mesh
		pyramid.position = Vector3(-65.0 + i * 24.0, 7.5, 90.0)
		pyramid.material_override = _mat(Color(0.72, 0.58, 0.38))
		add_child(pyramid)
	var sphinx := MeshInstance3D.new()
	sphinx.name = "ApprovedSphinxLandmark"
	var sphinx_mesh := BoxMesh.new()
	sphinx_mesh.size = Vector3(7, 3, 3)
	sphinx.mesh = sphinx_mesh
	sphinx.position = Vector3(35, 1.5, 91)
	sphinx.material_override = _mat(SAND)
	add_child(sphinx)

func _build_royal_gate_and_square() -> void:
	_box(self, "RoyalSquare", Vector3(24, 0.18, 18), Vector3(0, 0.03, -42), SAND)
	for x in [-10.0,10.0]:
		_box(self, "RoyalGatePillar", Vector3(2.0, 8.0, 2.0), Vector3(x, 4.0, -42), IVORY)
		_box(self, "RoyalGateCap", Vector3(3.0, 0.55, 3.0), Vector3(x, 8.1, -42), GOLD)
	_box(self, "RoyalGateBeam", Vector3(22, 1.2, 2.0), Vector3(0, 8.0, -42), GOLD)
