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
	_build_main_street_wall_ads()
	_build_nile_waterfront()
	_build_pyramids()
	_build_royal_gate_and_square()
	_build_royal_square_mosaic_mural()
	_build_royal_square_landscaping()
	_build_waterfront_landscaping()
	_build_beach_handball_court()
	_build_royal_ship()
	_build_access_roads_and_parking()
	_build_public_gardens()
	_build_pedestrian_green_pockets()
	_build_mountain_route()
	_build_mountain_animals()
	_build_city_lighting_and_wayfinding()
	_build_npc_population()

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
	var door_width := maxf(1.5, w * 0.18)
	var wall_depth := 0.35
	var half_w := w * 0.5
	var half_d := d * 0.5
	var side_width := (w - door_width) * 0.5
	# Build a hollow facade shell with a real visible doorway instead of a solid
	# cuboid that visually seals the entrance despite the collision opening.
	_box(root, "LeftFacade", Vector3(wall_depth, height, d), Vector3(-half_w + wall_depth * 0.5, height * 0.5, 0), IVORY)
	_box(root, "RightFacade", Vector3(wall_depth, height, d), Vector3(half_w - wall_depth * 0.5, height * 0.5, 0), IVORY)
	_box(root, "RearFacade", Vector3(w, height, wall_depth), Vector3(0, height * 0.5, -half_d + wall_depth * 0.5), IVORY)
	_box(root, "FrontLeftFacade", Vector3(side_width, height, wall_depth), Vector3(-(door_width + side_width) * 0.5, height * 0.5, half_d - wall_depth * 0.5), IVORY)
	_box(root, "FrontRightFacade", Vector3(side_width, height, wall_depth), Vector3((door_width + side_width) * 0.5, height * 0.5, half_d - wall_depth * 0.5), IVORY)
	_box(root, "FrontDoorLintel", Vector3(door_width, height - 2.8, wall_depth), Vector3(0, 2.8 + (height - 2.8) * 0.5, half_d - wall_depth * 0.5), IVORY)
	# Split the raised plinth too, keeping the doorway threshold visually open.
	var plinth_side_width := (w + 0.8 - door_width) * 0.5
	_box(root, "LeftGroundPlinth", Vector3(0.8, 0.7, d + 0.8), Vector3(-w * 0.5, 0.35, 0), SAND)
	_box(root, "RightGroundPlinth", Vector3(0.8, 0.7, d + 0.8), Vector3(w * 0.5, 0.35, 0), SAND)
	_box(root, "RearGroundPlinth", Vector3(w, 0.7, 0.8), Vector3(0, 0.35, -half_d), SAND)
	_box(root, "FrontLeftGroundPlinth", Vector3(plinth_side_width, 0.7, 0.8), Vector3(-(door_width + plinth_side_width) * 0.5, 0.35, half_d), SAND)
	_box(root, "FrontRightGroundPlinth", Vector3(plinth_side_width, 0.7, 0.8), Vector3((door_width + plinth_side_width) * 0.5, 0.35, half_d), SAND)
	_box(root, "RoofCornice", Vector3(w + 0.5, 0.35, d + 0.5), Vector3(0, height + 0.12, 0), accent)
	_box(root, "Entrance", Vector3(door_width, 2.8, 0.16), Vector3(0, 1.4, d * 0.5 + 0.09), DARK)
	_add_pharaonic_door_band(root, door_width, half_d + 0.205)
	_add_building_collision_shell(root, footprint, height, door_width)
	for side in [-1.0, 1.0]:
		_box(root, "FrontColumn", Vector3(0.38, minf(height - 0.8, 5.0), 0.42), Vector3(side * w * 0.34, minf(height - 0.8, 5.0) * 0.5, d * 0.5 + 0.25), accent)
	_add_building_facade_details(root, footprint, height, accent)
	_box(root, "EntranceStep", Vector3(maxf(3.0, w * 0.28), 0.22, 1.1), Vector3(0.0, 0.11, d * 0.5 + 0.68), SAND)
	_box(root, "FrontRoyalFrieze", Vector3(w * 0.82, 0.22, 0.24), Vector3(0.0, maxf(3.2, height - 0.72), d * 0.5 + 0.12), accent)
	var sign := Label3D.new()
	sign.name = "BuildingName"
	sign.text = title
	sign.position = Vector3(0, height + 1.0, d * 0.5 + 0.25)
	sign.font_size = 42
	sign.pixel_size = 0.009
	sign.modulate = Color(1.0, 0.9, 0.64)
	sign.outline_size = 8
	root.add_child(sign)
	if id == "royal_palace":
		var interaction_script := load("res://scripts/building_interaction.gd") as Script
		if interaction_script != null:
			var entrance := Node3D.new()
			entrance.name = "RoyalPalaceEntranceInteraction"
			entrance.position = Vector3(0, 0, d * 0.5 + 1.4)
			entrance.set_script(interaction_script)
			entrance.set("building_id", "royal_palace")
			entrance.set("building_title", "القصر الملكي")
			entrance.set("mission_title", "استكشف القصر الملكي")
			entrance.set("mission_description", "ادخل القصر واستكشف قاعاته وأجنحته الملكية الخمسة.")
			entrance.set("activity_list", "قاعة العرش الملكية، قاعة الاحتفالات، الكازينو الأوروبي، صالة VIP، الحديقة الملكية الداخلية")
			entrance.set("requires_interior", true)
			entrance.set("reward_money", 0)
			entrance.set("reward_chips", 0)
			entrance.set("reward_xp", 0)
			entrance.set("interaction_radius", 4.8)
			root.add_child(entrance)
	_add_building_lod_proxy(root, footprint, height, accent)



func _add_building_facade_details(root: Node3D, footprint: Vector2, height: float, accent: Color) -> void:
	# Repeated window panels are batched into two MultiMeshes per building to keep
	# the richer Egyptian facade inexpensive on Android.
	var levels: Array[float] = [3.55]
	if height >= 9.0:
		levels.append(height * 0.68)
	var frame_transforms: Array[Transform3D] = []
	var glass_transforms: Array[Transform3D] = []
	for level in levels:
		for side in [-1.0, 1.0]:
			var front_at := Vector3(side * footprint.x * 0.28, level, footprint.y * 0.5 + 0.11)
			frame_transforms.append(Transform3D(Basis.IDENTITY, front_at))
			glass_transforms.append(Transform3D(Basis.IDENTITY, front_at + Vector3(0.0, 0.0, 0.075)))
		for side in [-1.0, 1.0]:
			for z_offset in [-footprint.y * 0.22, footprint.y * 0.22]:
				var side_basis := Basis(Vector3.UP, PI * 0.5)
				var side_at := Vector3(side * (footprint.x * 0.5 + 0.035), level, z_offset)
				frame_transforms.append(Transform3D(side_basis, side_at))
				glass_transforms.append(Transform3D(side_basis, side_at + Vector3(side * 0.075, 0.0, 0.0)))
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.48, 1.72, 0.12)
	var frame_multi := MultiMesh.new()
	frame_multi.transform_format = MultiMesh.TRANSFORM_3D
	frame_multi.mesh = frame_mesh
	frame_multi.instance_count = frame_transforms.size()
	for i in range(frame_transforms.size()):
		frame_multi.set_instance_transform(i, frame_transforms[i])
	var frames := MultiMeshInstance3D.new()
	frames.name = "BatchedGoldWindowFrames"
	frames.multimesh = frame_multi
	frames.material_override = _mat(accent, 0.42)
	frames.visibility_range_end = 140.0
	frames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frames.add_to_group("city_world_geometry")
	root.add_child(frames)
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(1.22, 1.46, 0.08)
	var glass_multi := MultiMesh.new()
	glass_multi.transform_format = MultiMesh.TRANSFORM_3D
	glass_multi.mesh = glass_mesh
	glass_multi.instance_count = glass_transforms.size()
	for i in range(glass_transforms.size()):
		glass_multi.set_instance_transform(i, glass_transforms[i])
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.035, 0.12, 0.15)
	glass_material.metallic = 0.32
	glass_material.roughness = 0.2
	glass_material.emission_enabled = true
	glass_material.emission = Color(0.018, 0.055, 0.07)
	glass_material.emission_energy_multiplier = 0.28
	var glass := MultiMeshInstance3D.new()
	glass.name = "BatchedDarkTealWindows"
	glass.add_to_group("city_night_windows")
	glass.multimesh = glass_multi
	glass.material_override = glass_material
	glass.visibility_range_end = 140.0
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.add_to_group("city_world_geometry")
	root.add_child(glass)


func _add_pharaonic_door_band(root: Node3D, door_width: float, front_z: float) -> void:
	# One slim, emissive black-and-gold identity strip shared by every city entrance.
	var band := MeshInstance3D.new()
	band.name = "PharaonicDoorLightBand"
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(door_width + 0.22, 0.42, 0.075)
	band.mesh = band_mesh
	band.position = Vector3(0.0, 1.48, front_z)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.012, 0.014, 0.016)
	black.roughness = 0.34
	black.metallic = 0.42
	black.emission_enabled = true
	black.emission = Color(0.12, 0.075, 0.025)
	black.emission_energy_multiplier = 0.55
	band.material_override = black
	band.add_to_group("city_world_geometry")
	root.add_child(band)

	var trim := MeshInstance3D.new()
	trim.name = "PharaonicDoorBandGoldTrim"
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(door_width + 0.28, 0.035, 0.09)
	trim.mesh = trim_mesh
	trim.position = Vector3(0.0, 1.48, front_z + 0.008)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.92, 0.66, 0.24)
	gold.metallic = 0.72
	gold.roughness = 0.28
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.48, 0.12)
	gold.emission_energy_multiplier = 1.35
	trim.material_override = gold
	trim.add_to_group("city_world_geometry")
	root.add_child(trim)

	var glyphs := Label3D.new()
	glyphs.name = "PharaonicDoorBandGlyphs"
	glyphs.text = "𓂀  𓋹  𓆣  𓊹  𓋹  𓂀"
	glyphs.position = Vector3(0.0, 1.48, front_z + 0.058)
	glyphs.font_size = 30
	glyphs.pixel_size = 0.0065
	glyphs.modulate = Color(1.0, 0.78, 0.36)
	glyphs.outline_size = 3
	glyphs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyphs.add_to_group("city_world_geometry")
	root.add_child(glyphs)

func _add_building_lod_proxy(root: Node3D, footprint: Vector2, height: float, accent: Color) -> void:
	# Keep the detailed facade nearby; replace its six decorative draw calls with two
	# simple meshes at distance. The proxy remains visible through the fog/camera range.
	for child in root.get_children():
		if child is GeometryInstance3D:
			child.visibility_range_end = 140.0

	var proxy := Node3D.new()
	proxy.name = "BuildingLODProxy"
	root.add_child(proxy)

	var body := MeshInstance3D.new()
	body.name = "LowDetailBuildingBody"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(footprint.x * 0.92, height * 0.82, footprint.y * 0.92)
	body.mesh = body_mesh
	body.position.y = height * 0.41
	body.material_override = _mat(IVORY)
	body.visibility_range_begin = 140.0
	body.visibility_range_end = 480.0
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_to_group("city_world_geometry")
	proxy.add_child(body)

	var roof := MeshInstance3D.new()
	roof.name = "LowDetailRoofTrim"
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(footprint.x, 0.4, footprint.y)
	roof.mesh = roof_mesh
	roof.position.y = height * 0.83
	roof.material_override = _mat(accent, 0.08 if accent == GOLD else 0.0)
	roof.visibility_range_begin = 140.0
	roof.visibility_range_end = 480.0
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roof.add_to_group("city_world_geometry")
	proxy.add_child(roof)

func _build_districts() -> void:
	# Each position is kept within the current prototype city bounds.
	var entries := [
		["royal_palace","القصر الملكي",Vector3(0,0,-78),Vector2(22,16),12.0],
		["royal_bank","البنك الملكي",Vector3(42,0,-60),Vector2(12,11),8.0],
		["supermarket","السوبر ماركت",Vector3(-30,0,-30),Vector2(10,10),6.0],
		["market","السوق التجاري",Vector3(0,0,0),Vector2(12,10),6.0],
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
	_build_open_fuel_station()

func _build_open_fuel_station() -> void:
	# Open, drive-through forecourt on the approved west service edge.
	# No enclosed building, door, interaction prompt, or entry trigger is created.
	var station := Node3D.new()
	station.name = "OpenFuelStation"
	station.position = Vector3(-74.0, 0.0, 38.0)
	station.add_to_group("city_world_geometry")
	station.add_to_group("approved_city_buildings")
	add_child(station)

	# A broad, continuous paved surface remains open on the east side for vehicles
	# and pedestrians. Its footprint stays clear of the west parking court and
	# the neighbouring adventure-centre building.
	_box(station, "FuelStationForecourt", Vector3(16.0, 0.16, 24.0), Vector3(0.0, -0.08, 0.0), Color(0.34, 0.35, 0.34))
	_add_static_box_collision(station, "FuelStationWalkableSurface", Vector3(16.0, 0.16, 24.0), Vector3(0.0, -0.08, 0.0))
	_box(station, "FuelStationDrivewayConnector", Vector3(8.0, 0.12, 5.0), Vector3(5.5, -0.02, 4.0), Color(0.34, 0.35, 0.34))
	_add_static_box_collision(station, "FuelStationDrivewayWalkable", Vector3(8.0, 0.12, 5.0), Vector3(5.5, -0.02, 4.0))

	# Canopy supported by slim columns; all sides stay completely open.
	_box(station, "FuelCanopyRoof", Vector3(12.0, 0.42, 8.0), Vector3(-0.5, 5.0, -0.5), IVORY)
	_box(station, "FuelCanopyGoldTrim", Vector3(12.2, 0.16, 8.2), Vector3(-0.5, 4.76, -0.5), GOLD)
	for x in [-5.6, 4.6]:
		for z in [-3.6, 2.6]:
			_box(station, "FuelCanopyColumn", Vector3(0.28, 4.7, 0.28), Vector3(x, 2.35, z), GOLD)

	# Three low-profile pump islands with visible dispensers and hoses.
	for pump_index in range(3):
		var pump_x := -4.0 + float(pump_index) * 3.5
		_box(station, "FuelPumpIsland", Vector3(2.2, 0.16, 1.6), Vector3(pump_x, 0.08, -0.4), SAND)
		_box(station, "FuelPumpBase", Vector3(0.9, 1.15, 0.72), Vector3(pump_x, 0.72, -0.4), DARK)
		_box(station, "FuelPumpDisplay", Vector3(0.68, 0.36, 0.06), Vector3(pump_x, 1.05, -0.03), IVORY)
		_box(station, "FuelPumpHose", Vector3(0.08, 0.72, 0.08), Vector3(pump_x + 0.52, 0.62, -0.72), DARK)

	var sign := Label3D.new()
	sign.name = "FuelStationSign"
	sign.text = "FUEL"
	sign.position = Vector3(-0.5, 6.0, -4.4)
	sign.font_size = 44
	sign.pixel_size = 0.012
	sign.modulate = Color(1.0, 0.9, 0.64)
	sign.outline_size = 8
	station.add_child(sign)


func _build_nile_waterfront() -> void:
	# A real open basin: the matching ground section is omitted in main.gd, so
	# the player cannot walk on a hidden terrain floor beneath the water.
	var water := _box(self, "NileWaterfront", Vector3(24.0, 0.18, 24.0), Vector3(0, -0.12, 90.0), Color(0.025, 0.24, 0.34))
	var water_material := _mat(Color(0.025, 0.24, 0.34), 0.12)
	water_material.roughness = 0.2
	water.material_override = water_material
	# Low sandstone quay edges define the basin without moving the promenade,
	# ship, pier, or the service roads that pass outside the basin.
	for side in [-1.0, 1.0]:
		_box(self, "MarinaQuayEdge", Vector3(0.8, 0.55, 24.0), Vector3(side * 12.4, 0.12, 90.0), SAND)
	_box(self, "MarinaSouthQuay", Vector3(24.0, 0.55, 0.8), Vector3(0, 0.12, 102.4), SAND)
	_box(self, "WaterfrontPromenade", Vector3(180, 0.28, 3.0), Vector3(0, 0.02, 76), SAND)
	for x in [-65.0,-45.0,-25.0,25.0,45.0,65.0]:
		_box(self, "PromenadeLamp", Vector3(0.18, 3.0, 0.18), Vector3(x, 1.5, 74), GOLD)
		_box(self, "PromenadeLampHead", Vector3(0.8, 0.18, 0.8), Vector3(x, 3.0, 74), GOLD)
		_add_city_night_light(self, "PromenadeNightLight", Vector3(x, 2.9, 74), 8.0)

func _build_pyramids() -> void:
	# Place the Giza landmarks beyond the northern city skyline so they read as a distant desert region.
	# The expanded ground in main.gd extends to z=-340; these landmarks remain inside the playable world.
	var pyramid_positions: Array[Vector3] = [
		Vector3(-48.0, 0.0, -252.0),
		Vector3(0.0, 0.0, -270.0),
		Vector3(48.0, 0.0, -252.0)
	]
	for i in range(pyramid_positions.size()):
		var pyramid := MeshInstance3D.new()
		pyramid.name = "DistantGizaPyramid_%d" % (i + 1)
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 18.0 - i * 2.0
		mesh.height = 34.0 - i * 3.0
		mesh.radial_segments = 4
		mesh.rings = 1
		pyramid.mesh = mesh
		pyramid.position = pyramid_positions[i] + Vector3(0.0, mesh.height * 0.5, 0.0)
		pyramid.material_override = _mat(Color(0.72, 0.58, 0.38))
		pyramid.add_to_group("city_distant_landmarks")
		pyramid.add_to_group("city_world_geometry")
		pyramid.visibility_range_begin = 0.0
		pyramid.visibility_range_end = 500.0
		pyramid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pyramid)
	var sphinx := MeshInstance3D.new()
	sphinx.name = "DistantSphinxLandmark"
	var sphinx_mesh := BoxMesh.new()
	sphinx_mesh.size = Vector3(12.0, 4.0, 5.0)
	sphinx.mesh = sphinx_mesh
	sphinx.position = Vector3(70.0, 2.0, -246.0)
	sphinx.material_override = _mat(SAND)
	sphinx.add_to_group("city_distant_landmarks")
	sphinx.add_to_group("city_world_geometry")
	sphinx.visibility_range_begin = 0.0
	sphinx.visibility_range_end = 500.0
	sphinx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sphinx)

func _build_royal_gate_and_square() -> void:
	# The approved GLB is the single source of truth for the royal gate visual.
	_box(self, "RoyalSquare", Vector3(46, 0.22, 30), Vector3(0, 0.03, -42), SAND)
	_add_static_box_collision(self, "RoyalSquareWalkable", Vector3(46, 0.22, 30), Vector3(0, 0.03, -42))

	var gate_scene := load("res://assets/models/royal_gate.glb") as PackedScene
	assert(gate_scene != null, "Approved royal gate GLB could not be loaded.")
	var gate := gate_scene.instantiate() as Node3D
	assert(gate != null, "Approved royal gate GLB root must be Node3D.")
	gate.name = "RoyalFounderGate"
	# Blender's Z-up export is converted to Godot's Y-up axes by the glTF importer.
	# Lower the continuous roadway to ground level; keep the founder crest facing the square.
	gate.position = Vector3(0.0, -0.965, -48.0)
	gate.add_to_group("city_world_geometry")
	gate.add_to_group("approved_city_landmarks")
	add_child(gate)

	# The GLB roadway is level and 8.2 m wide. Collision is limited to the two pylons;
	# nothing is placed across the central vehicle passage.
	for side: float in [-1.0, 1.0]:
		_add_static_box_collision(
			gate,
			"RoyalGatePylonCollision",
			Vector3(6.5, 13.8, 5.2),
			Vector3(side * 8.0, 6.9 - 0.965, 0.0)
		)
	_add_static_box_collision(
		gate,
		"RoyalEntranceWalkableCollision",
		Vector3(8.2, 0.22, 42.0),
		Vector3(0.0, 0.11 - 0.965, 1.5)
	)

	assert(gate.get_node_count() > 1, "Royal gate GLB must contain imported visual nodes.")
	assert(ResourceLoader.exists("res://assets/models/royal_gate.glb"))

func _build_main_street_wall_ads() -> void:
	# Founder identity is painted directly onto selected side facades like a permanent wall mural.
	# There is no signboard, backing slab, frame, or raised border.
	var portrait_path := "res://assets/founder/founder_portrait.jpg"
	if not ResourceLoader.exists(portrait_path):
		push_warning("تعذر تحميل صورة جدارية المؤسس: " + portrait_path)
		return
	var portrait_texture := load(portrait_path) as Texture2D
	if portrait_texture == null:
		push_warning("ملف صورة المؤسس ليس Texture2D صالحاً للجدارية.")
		return

	var targets := [
		{"id":"royal_bank", "width":12.0, "side":1.0},
		{"id":"supermarket", "width":10.0, "side":-1.0},
		{"id":"market", "width":12.0, "side":1.0},
		{"id":"employment_center", "width":11.0, "side":-1.0},
		{"id":"main_restaurant", "width":12.0, "side":1.0},
		{"id":"royal_cafe", "width":10.0, "side":-1.0},
		{"id":"cinema", "width":12.0, "side":1.0},
		{"id":"royal_theater", "width":13.0, "side":-1.0},
		{"id":"stadium", "width":16.0, "side":1.0},
		{"id":"sports_club", "width":12.0, "side":-1.0},
		{"id":"water_city", "width":14.0, "side":1.0},
		{"id":"daily_arcade", "width":13.0, "side":-1.0}
	]
	var portrait_material := StandardMaterial3D.new()
	portrait_material.albedo_texture = portrait_texture
	portrait_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	portrait_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	portrait_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	portrait_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	portrait_material.alpha_scissor_threshold = 0.05

	for index in range(targets.size()):
		var spec: Dictionary = targets[index]
		var building := get_node_or_null("Approved_" + str(spec["id"])) as Node3D
		if building == null:
			continue
		var side := float(spec["side"])
		var width := float(spec["width"])
		# Refinish the complete visible facade shell in warm Egyptian sandstone.
		# The mural can be viewed from different camera angles, so recolor every
		# structural wall section rather than only one side panel.
		var sandstone_wall := StandardMaterial3D.new()
		sandstone_wall.albedo_color = Color(0.72, 0.61, 0.46)
		sandstone_wall.roughness = 0.96
		sandstone_wall.metallic = 0.0
		# Keep the sandstone hue stable in the low-light production preview and
		# under mobile day/night ambient changes; the wall remains matte and non-metallic.
		sandstone_wall.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sandstone_wall.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		for facade_name in ["LeftFacade", "RightFacade", "RearFacade", "FrontLeftFacade", "FrontRightFacade", "FrontDoorLintel"]:
			var facade_piece := building.get_node_or_null(facade_name) as MeshInstance3D
			if facade_piece != null:
				facade_piece.material_override = sandstone_wall
		# The detailed facade disappears beyond 140m. Its LOD proxy used the
		# generic ivory body, which caused the distant mural buildings to lose
		# the sandstone finish. Match the proxy body to the real facade material.
		var lod_body := building.get_node_or_null("BuildingLODProxy/LowDetailBuildingBody") as MeshInstance3D
		if lod_body != null:
			lod_body.material_override = sandstone_wall
		var mural := Node3D.new()
		mural.name = "FounderWallMural_" + str(spec["id"])
		# The image and lettering sit almost flush to the plaster facade, with no projecting frame.
		mural.position = Vector3(side * (width * 0.5 + 0.012), 4.75, 0.0)
		mural.rotation.y = PI * 0.5 if side > 0.0 else -PI * 0.5
		mural.add_to_group("main_street_wall_advertisements")
		building.add_child(mural)

		var portrait := MeshInstance3D.new()
		portrait.name = "FounderPortraitWallPrint"
		var portrait_mesh := QuadMesh.new()
		portrait_mesh.size = Vector2(2.75, 1.42)
		portrait.mesh = portrait_mesh
		portrait.position = Vector3(0.0, 0.43, 0.19)
		portrait.material_override = portrait_material
		portrait.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mural.add_child(portrait)

		# Gold lettering is applied directly to the wall below the portrait, like painted signage.
		var name_label := Label3D.new()
		name_label.name = "FounderMuralName"
		name_label.text = "GAMAL ALARABY"
		name_label.position = Vector3(0.0, -0.57, 0.19)
		name_label.font_size = 32
		name_label.pixel_size = 0.008
		name_label.modulate = Color(0.82, 0.57, 0.23)
		name_label.outline_size = 2
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mural.add_child(name_label)

		var title_label := Label3D.new()
		title_label.name = "FounderMuralTitle"
		title_label.text = "FOUNDER OF KING OF EGYPT CITY"
		title_label.position = Vector3(0.0, -0.88, 0.19)
		title_label.font_size = 13
		title_label.pixel_size = 0.008
		title_label.modulate = Color(0.68, 0.48, 0.24)
		title_label.outline_size = 1
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mural.add_child(title_label)

		_add_founder_mural_inlay(mural)


func _add_founder_mural_inlay(parent: Node3D) -> void:
	# Integrated Egyptian architectural relief: carved stone pilasters and gold
	# inlay ornaments sit on the facade itself; no plaque or closed picture frame.
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.78, 0.57, 0.25)
	gold.metallic = 0.68
	gold.roughness = 0.28
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var sandstone := StandardMaterial3D.new()
	sandstone.albedo_color = Color(0.62, 0.48, 0.31)
	sandstone.roughness = 0.82

	# Two shallow carved pilasters visually belong to the building facade.
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		pillar.name = "FounderMuralCarvedPilaster"
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.16, 2.42, 0.11)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(side * 1.88, 0.28, 0.13)
		pillar.material_override = sandstone
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(pillar)

		# Fine gold grooves run vertically through the stone, like temple carving.
		for groove_x in [-0.045, 0.045]:
			var groove := MeshInstance3D.new()
			groove.name = "FounderMuralPilasterGoldGroove"
			var groove_mesh := BoxMesh.new()
			groove_mesh.size = Vector3(0.012, 2.18, 0.014)
			groove.mesh = groove_mesh
			groove.position = Vector3(side * 1.88 + groove_x, 0.28, 0.192)
			groove.material_override = gold
			groove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(groove)

		# Lotus-inspired capitals and bases, deliberately separated from a frame.
		for cap_y in [-0.88, 1.44]:
			var capital := MeshInstance3D.new()
			capital.name = "FounderMuralLotusCapital"
			var capital_mesh := BoxMesh.new()
			capital_mesh.size = Vector3(0.28, 0.12, 0.13)
			capital.mesh = capital_mesh
			capital.position = Vector3(side * 1.88, cap_y, 0.17)
			capital.material_override = gold
			capital.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(capital)

		# Small diamond reliefs echo Egyptian wall engraving.
		for diamond_y in [-0.48, 0.0, 0.48]:
			var diamond := MeshInstance3D.new()
			diamond.name = "FounderMuralDiamondRelief"
			var diamond_mesh := BoxMesh.new()
			diamond_mesh.size = Vector3(0.095, 0.095, 0.035)
			diamond.mesh = diamond_mesh
			diamond.position = Vector3(side * 1.88, diamond_y, 0.205)
			diamond.rotation.z = PI * 0.25
			diamond.material_override = gold
			diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(diamond)

	# Winged-sun inspired crown above the portrait, not a rectangular border.
	for side in [-1.0, 1.0]:
		for segment in range(3):
			var wing := MeshInstance3D.new()
			wing.name = "FounderMuralWingFeather"
			var wing_mesh := BoxMesh.new()
			wing_mesh.size = Vector3(0.42 - float(segment) * 0.075, 0.035, 0.025)
			wing.mesh = wing_mesh
			wing.position = Vector3(side * (0.42 + float(segment) * 0.27), 1.43 - float(segment) * 0.075, 0.205)
			wing.rotation.z = -side * (0.08 + float(segment) * 0.07)
			wing.material_override = gold
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(wing)

	var sun := MeshInstance3D.new()
	sun.name = "FounderMuralSunDisk"
	var sun_mesh := CylinderMesh.new()
	sun_mesh.top_radius = 0.13
	sun_mesh.bottom_radius = 0.13
	sun_mesh.height = 0.025
	sun_mesh.radial_segments = 32
	sun.mesh = sun_mesh
	sun.position = Vector3(0.0, 1.43, 0.215)
	sun.rotation.x = PI * 0.5
	sun.material_override = gold
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sun)

	# A restrained lower engraved rule ties the lettering into the masonry.
	var lower_rule := MeshInstance3D.new()
	lower_rule.name = "FounderMuralEngravedLowerRule"
	var rule_mesh := BoxMesh.new()
	rule_mesh.size = Vector3(2.45, 0.022, 0.018)
	lower_rule.mesh = rule_mesh
	lower_rule.position = Vector3(0.0, -1.08, 0.19)
	lower_rule.material_override = gold
	lower_rule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lower_rule)

func _tree(parent: Node3D, label: String, at: Vector3, scale_factor: float = 1.0) -> void:
	var root := Node3D.new()
	root.name = label
	root.position = at
	parent.add_child(root)
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18 * scale_factor
	trunk_mesh.bottom_radius = 0.28 * scale_factor
	trunk_mesh.height = 3.2 * scale_factor
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.6 * scale_factor
	trunk.material_override = _mat(Color(0.38, 0.24, 0.13))
	trunk.add_to_group("city_world_geometry")
	root.add_child(trunk)
	for i in range(5):
		var leaf := MeshInstance3D.new()
		leaf.name = "PalmFrond_%d" % i
		var leaf_mesh := BoxMesh.new()
		leaf_mesh.size = Vector3(0.42 * scale_factor, 0.16 * scale_factor, 2.6 * scale_factor)
		leaf.mesh = leaf_mesh
		leaf.position = Vector3(0, 3.15 * scale_factor, 0)
		leaf.rotation.y = TAU * float(i) / 5.0
		leaf.rotation.x = -0.24
		leaf.material_override = _mat(Color(0.16, 0.34, 0.20))
		leaf.add_to_group("city_world_geometry")
		root.add_child(leaf)
	_add_tree_lod_proxy(root, scale_factor)


func _add_tree_lod_proxy(root: Node3D, scale_factor: float) -> void:
	# Keep the five-frond palm close to the player; use a compact two-mesh silhouette at distance.
	for child in root.get_children():
		if child is GeometryInstance3D:
			child.visibility_range_end = 90.0

	var proxy := Node3D.new()
	proxy.name = "PalmLODProxy"
	root.add_child(proxy)

	var trunk := MeshInstance3D.new()
	trunk.name = "LowDetailTrunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13 * scale_factor
	trunk_mesh.bottom_radius = 0.22 * scale_factor
	trunk_mesh.height = 3.2 * scale_factor
	trunk_mesh.radial_segments = 5
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.6 * scale_factor
	trunk.material_override = _mat(Color(0.38, 0.24, 0.13))
	trunk.visibility_range_begin = 90.0
	trunk.visibility_range_end = 480.0
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trunk.add_to_group("city_world_geometry")
	proxy.add_child(trunk)

	var crown := MeshInstance3D.new()
	crown.name = "LowDetailPalmCrown"
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.25 * scale_factor
	crown_mesh.height = 0.75 * scale_factor
	crown_mesh.radial_segments = 5
	crown_mesh.rings = 3
	crown.mesh = crown_mesh
	crown.position.y = 3.15 * scale_factor
	crown.material_override = _mat(Color(0.16, 0.34, 0.20))
	crown.visibility_range_begin = 90.0
	crown.visibility_range_end = 480.0
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crown.add_to_group("city_world_geometry")
	proxy.add_child(crown)

func _build_royal_square_landscaping() -> void:
	# Keep the center of the plaza open for large player gatherings.
	for x in [-25.0, 25.0]:
		for z in [-58.0, -23.0]:
			_tree(self, "RoyalSquarePalm", Vector3(x, 0, z), 1.15)
	for x in [-19.0, 19.0]:
		_box(self, "RoyalSquarePlanter", Vector3(2.2, 0.45, 2.2), Vector3(x, 0.23, -42), SAND)
	# Low golden edge markers frame the gathering space without blocking entrances.
	for x in [-20.0, -10.0, 10.0, 20.0]:
		_box(self, "RoyalSquareEdgeMarker", Vector3(0.35, 0.65, 0.35), Vector3(x, 0.34, -27.5), GOLD)

func _build_waterfront_landscaping() -> void:
	for x in range(-60, 61, 20):
		# Keep the ship approach and pier centerline free of palms.
		if x != 0:
			_tree(self, "WaterfrontPalm", Vector3(float(x), 0, 72.0), 0.9)


func _build_beach_handball_court() -> void:
	# Open sandy beach-handball area beside the marina's south-east shoreline.
	# It is a walkable outdoor court, not an enclosed building or interaction point.
	var beach := Node3D.new()
	beach.name = "BeachHandballCourt"
	beach.position = Vector3(40.0, 0.0, 125.0)
	beach.add_to_group("city_world_geometry")
	add_child(beach)

	# Broad sand apron gives players room to enter, move around and leave the court.
	_box(beach, "BeachSandApron", Vector3(42.0, 0.16, 36.0), Vector3(0.0, -0.08, 0.0), Color(0.78, 0.67, 0.48))
	_add_static_box_collision(beach, "BeachSandWalkable", Vector3(42.0, 0.16, 36.0), Vector3(0.0, -0.08, 0.0))

	# Official-style beach handball playing rectangle: 27 x 12 metres.
	var court_half_length := 13.5
	var court_half_width := 6.0
	var line_y := 0.025
	var line_color := IVORY
	_box(beach, "HandballSideline_North", Vector3(27.0, 0.045, 0.12), Vector3(0.0, line_y, -court_half_width), line_color)
	_box(beach, "HandballSideline_South", Vector3(27.0, 0.045, 0.12), Vector3(0.0, line_y, court_half_width), line_color)
	_box(beach, "HandballGoalLine_West", Vector3(0.12, 0.045, 12.0), Vector3(-court_half_length, line_y, 0.0), line_color)
	_box(beach, "HandballGoalLine_East", Vector3(0.12, 0.045, 12.0), Vector3(court_half_length, line_y, 0.0), line_color)
	_box(beach, "HandballCenterLine", Vector3(0.10, 0.045, 12.0), Vector3(0.0, line_y, 0.0), line_color)

	# Two open goals with visible posts, crossbars and lightweight net mesh lines.
	for side in [-1.0, 1.0]:
		var goal := Node3D.new()
		goal.name = "BeachHandballGoal_West" if side < 0.0 else "BeachHandballGoal_East"
		goal.position = Vector3(side * court_half_length, 0.0, 0.0)
		beach.add_child(goal)
		for post_side in [-1.0, 1.0]:
			_box(goal, "GoalPost", Vector3(0.18, 2.0, 0.18), Vector3(0.0, 1.0, post_side * 1.5), IVORY)
		_box(goal, "GoalCrossbar", Vector3(0.18, 0.18, 3.18), Vector3(0.0, 2.0, 0.0), GOLD)
		var net_color := Color(0.92, 0.94, 0.88, 0.28)
		var net_backing := _box(goal, "GoalNetBacking", Vector3(0.05, 1.78, 3.0), Vector3(side * 0.55, 0.95, 0.0), net_color)
		var net_material := _mat(net_color)
		net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		net_backing.material_override = net_material
		for net_index in range(1, 5):
			var net_z := -1.5 + float(net_index) * 0.6
			_box(goal, "GoalNetVerticalCord", Vector3(0.07, 1.75, 0.035), Vector3(side * 0.58, 0.95, net_z), IVORY)
		for net_index in range(1, 4):
			var net_y := 0.45 + float(net_index) * 0.42
			_box(goal, "GoalNetHorizontalCord", Vector3(0.07, 0.035, 3.0), Vector3(side * 0.58, net_y, 0.0), IVORY)

	var sign := Label3D.new()
	sign.name = "BeachHandballSign"
	sign.text = "BEACH HANDBALL"
	sign.position = Vector3(0.0, 2.4, -16.0)
	sign.font_size = 34
	sign.pixel_size = 0.012
	sign.modulate = Color(1.0, 0.92, 0.72)
	sign.outline_size = 6
	beach.add_child(sign)


func _build_royal_ship() -> void:
	# A single stationary royal ship carries five civilization-themed deck banners.
	var ship := Node3D.new()
	ship.name = "RoyalCivilizationsShip"
	ship.position = Vector3(0, 0, 85)
	add_child(ship)
	_box(ship, "RoyalShipHull", Vector3(4.8, 1.8, 17.0), Vector3(0, 1.0, 0), Color(0.16, 0.20, 0.23))
	_box(ship, "RoyalShipGoldTrim", Vector3(5.0, 0.22, 16.0), Vector3(0, 1.92, 0), GOLD)
	_box(ship, "RoyalShipMainDeck", Vector3(4.1, 0.28, 13.5), Vector3(0, 2.12, -0.4), IVORY)
	_box(ship, "RoyalShipCabin", Vector3(2.8, 1.7, 4.0), Vector3(0, 3.0, -3.0), SAND)
	_box(ship, "RoyalShipUpperDeck", Vector3(2.5, 0.22, 3.2), Vector3(0, 3.92, -3.0), GOLD)
	_box(ship, "RoyalShipBow", Vector3(3.0, 0.55, 2.6), Vector3(0, 1.4, 8.0), Color(0.24, 0.27, 0.28))
	var mast := MeshInstance3D.new()
	mast.name = "RoyalShipMast"
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.10
	mast_mesh.bottom_radius = 0.16
	mast_mesh.height = 6.5
	mast.mesh = mast_mesh
	mast.position = Vector3(0, 5.3, 1.0)
	mast.material_override = _mat(GOLD, 0.25)
	ship.add_child(mast)
	var flag_colors := [
		Color(0.20, 0.42, 0.72), Color(0.68, 0.20, 0.16),
		Color(0.78, 0.20, 0.22), Color(0.82, 0.72, 0.38),
		Color(0.20, 0.34, 0.68)
	]
	var civilizations := ["GREECE", "ROME", "JAPAN", "CHINA", "FRANCE"]
	for i in range(civilizations.size()):
		var flag := MeshInstance3D.new()
		flag.name = "CivilizationFlag_" + civilizations[i]
		var flag_mesh := BoxMesh.new()
		flag_mesh.size = Vector3(1.0, 0.55, 0.08)
		flag.mesh = flag_mesh
		flag.position = Vector3(0.62, 7.65, -5.0 + float(i) * 2.5)
		flag.material_override = _mat(flag_colors[i])
		ship.add_child(flag)
	# A side pier connects the waterfront promenade to the ship without blocking the quay.
	_box(self, "RoyalShipPier", Vector3(8.0, 0.28, 14.0), Vector3(-6.0, 0.02, 84.0), SAND)
	_add_static_box_collision(ship, "RoyalShipPierWalkable", Vector3(8.0, 0.28, 14.0), Vector3(-6.0, 0.02, -1.0))
	for x in [-10.0, -2.0]:
		for z in [79.0, 84.0, 89.0]:
			_box(self, "RoyalShipPierPost", Vector3(0.35, 1.1, 0.35), Vector3(x, 0.5, z), GOLD)


func _add_building_collision_shell(root: Node3D, footprint: Vector2, height: float, door_width: float) -> void:
	# Physical walls mirror the visible facade while leaving a real doorway opening.
	var body := StaticBody3D.new()
	body.name = "BuildingCollisionShell"
	body.add_to_group("city_world_geometry")
	root.add_child(body)

	var wall_height := maxf(height, 3.0)
	var wall_depth := 0.35
	var half_width := footprint.x * 0.5
	var half_depth := footprint.y * 0.5
	var opening_width := clampf(door_width, 1.5, maxf(1.5, footprint.x - 0.8))
	var side_width := maxf(0.25, (footprint.x - opening_width) * 0.5)

	_add_collision_box(body, "BackWall", Vector3(footprint.x, wall_height, wall_depth), Vector3(0.0, wall_height * 0.5, -half_depth))
	_add_collision_box(body, "LeftWall", Vector3(wall_depth, wall_height, footprint.y), Vector3(-half_width, wall_height * 0.5, 0.0))
	_add_collision_box(body, "RightWall", Vector3(wall_depth, wall_height, footprint.y), Vector3(half_width, wall_height * 0.5, 0.0))
	_add_collision_box(body, "FrontLeftWall", Vector3(side_width, wall_height, wall_depth), Vector3(-(opening_width + side_width) * 0.5, wall_height * 0.5, half_depth))
	_add_collision_box(body, "FrontRightWall", Vector3(side_width, wall_height, wall_depth), Vector3((opening_width + side_width) * 0.5, wall_height * 0.5, half_depth))
	var lintel_height := maxf(0.2, wall_height - 2.8)
	_add_collision_box(body, "DoorLintel", Vector3(opening_width, lintel_height, wall_depth), Vector3(0.0, 2.8 + lintel_height * 0.5, half_depth))


func _add_collision_box(parent: Node3D, label: String, size: Vector3, at: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	parent.add_child(collision)

func _add_static_box_collision(parent: Node3D, label: String, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.add_to_group("city_world_geometry")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _build_access_roads_and_parking() -> void:
	# A short connector links the royal square to the internal street grid.
	_box(self, "RoyalSquareSouthConnector", Vector3(5.0, 0.08, 12.0), Vector3(0, 0.01, -21.0), DARK)
	# Small parking courts sit beside the service edge, outside building footprints and the main carriageways.
	for side in [-1.0, 1.0]:
		# Keep each court in the narrow clear strip between the outer service buildings and perimeter road.
		# The 10 m width ends at the road edge and starts beyond the 81.5 m building footprint.
		var parking_z := -35.0 if side < 0.0 else 34.0
		var parking := _box(self, "ServiceParkingCourt", Vector3(10.0, 0.06, 18.0), Vector3(side * 87.0, 0.015, parking_z), Color(0.20, 0.22, 0.23))
		for slot in range(3):
			_box(parking, "ParkingBayLine", Vector3(0.12, 0.025, 4.8), Vector3(-3.6 + float(slot) * 3.6, 0.06, 0), IVORY)
	# Dedicated access spurs connect the perimeter roads to service destinations.
	# Fuel station: the west spur opens directly into the outdoor forecourt.
	_path_segment(self, "FuelStationAccessSpur", Vector3(-95.0, 0.12, 38.0), Vector3(-85.5, 0.12, 38.0), 4.2, DARK)
	# Move the west parking court away from the fuel forecourt; preserve the east parking court.
	# Desert lodge and adventure district pedestrian access.
	_path_segment(self, "WestAdventureAccess_01", Vector3(-95.0, 0.12, 58.0), Vector3(-84.0, 0.12, 58.0), 3.6, SAND)
	_path_segment(self, "WestAdventureAccess_02", Vector3(-84.0, 0.12, 58.0), Vector3(-84.0, 0.12, 75.0), 3.6, SAND)
	_path_segment(self, "AdventureCenterEntranceWalk", Vector3(-84.0, 0.12, 62.5), Vector3(-75.0, 0.12, 62.6), 3.0, SAND)
	_path_segment(self, "DesertLodgeEntranceWalk", Vector3(-84.0, 0.12, 75.0), Vector3(-75.0, 0.12, 80.7), 3.0, SAND)
	# Marina terminal and yacht club: a clear pedestrian spine runs beside the building fronts.
	_path_segment(self, "MarinaTerminalAccess_01", Vector3(95.0, 0.12, 38.0), Vector3(84.0, 0.12, 38.0), 3.6, SAND)
	_path_segment(self, "MarinaPromenadeSpine", Vector3(84.0, 0.12, 38.0), Vector3(84.0, 0.12, 62.0), 3.6, SAND)
	_path_segment(self, "MarinaTerminalEntranceWalk", Vector3(84.0, 0.12, 42.5), Vector3(75.0, 0.12, 42.6), 3.0, SAND)
	_path_segment(self, "YachtClubEntranceWalk", Vector3(84.0, 0.12, 62.0), Vector3(75.0, 0.12, 62.6), 3.0, SAND)
	# Beach handball court access joins the waterfront promenade to the open sand apron.
	_path_segment(self, "BeachHandballPromenadeConnector", Vector3(32.0, 0.12, 76.0), Vector3(32.0, 0.12, 106.0), 3.6, SAND)
	_path_segment(self, "BeachHandballApronEntry", Vector3(32.0, 0.12, 106.0), Vector3(40.0, 0.12, 107.0), 3.6, SAND)
	# Temple approach branches from the mountain trail without moving the temple or summit.
	_path_segment(self, "MountainTempleEntranceWalk", Vector3(83.0, 0.12, 68.0), Vector3(75.0, 0.12, 80.7), 3.2, SAND)
	# Short, collision-backed approaches connect visible entrances to the nearest public walk.
	var entrance_walks := [
		["RoyalPalaceEntranceWalk", Vector3(0.0, 0.12, -69.8), Vector3(0.0, 0.12, -58.5)],
		["RoyalBankEntranceWalk", Vector3(42.0, 0.12, -54.1), Vector3(42.0, 0.12, -50.0)],
		["SupermarketEntranceWalk", Vector3(-30.0, 0.12, -23.6), Vector3(-30.0, 0.12, -20.0)],
		["MarketEntranceWalk", Vector3(0.0, 0.12, 6.4), Vector3(0.0, 0.12, 10.0)],
		["EmploymentEntranceWalk", Vector3(30.0, 0.12, -23.6), Vector3(30.0, 0.12, -20.0)],
		["RestaurantEntranceWalk", Vector3(60.0, 0.12, -23.6), Vector3(60.0, 0.12, -20.0)],
		["CafeEntranceWalk", Vector3(-60.0, 0.12, 6.4), Vector3(-60.0, 0.12, 10.0)],
		["CommercialServicesEntranceWalk", Vector3(60.0, 0.12, 6.4), Vector3(60.0, 0.12, 10.0)],
		["ApartmentOneEntranceWalk", Vector3(-60.0, 0.12, 37.4), Vector3(-60.0, 0.12, 40.0)],
		["ApartmentTwoEntranceWalk", Vector3(-30.0, 0.12, 37.4), Vector3(-30.0, 0.12, 40.0)],
		["ApartmentThreeEntranceWalk", Vector3(0.0, 0.12, 37.4), Vector3(0.0, 0.12, 40.0)],
		["ApartmentFourEntranceWalk", Vector3(30.0, 0.12, 37.4), Vector3(30.0, 0.12, 40.0)],
		["CinemaEntranceWalk", Vector3(60.0, 0.12, 36.4), Vector3(60.0, 0.12, 40.0)],
		["TheaterEntranceWalk", Vector3(-60.0, 0.12, 66.9), Vector3(-60.0, 0.12, 74.0)],
		["StadiumEntranceWalk", Vector3(-30.0, 0.12, 66.9), Vector3(-30.0, 0.12, 74.0)],
		["SportsClubEntranceWalk", Vector3(0.0, 0.12, 66.9), Vector3(0.0, 0.12, 74.0)],
		["WaterCityEntranceWalk", Vector3(30.0, 0.12, 66.9), Vector3(30.0, 0.12, 74.0)],
		["DailyArcadeEntranceWalk", Vector3(60.0, 0.12, 66.9), Vector3(60.0, 0.12, 74.0)]
	]
	for walk in entrance_walks:
		_path_segment(self, str(walk[0]), walk[1], walk[2], 2.6, SAND)
	_path_segment(self, "PoliceServiceAccess", Vector3(-95.0, 0.12, -5.0), Vector3(-84.0, 0.12, -5.0), 3.2, SAND)
	_path_segment(self, "PoliceEntranceTurn", Vector3(-84.0, 0.12, -5.0), Vector3(-84.0, 0.12, 0.9), 3.2, SAND)
	_path_segment(self, "PoliceFrontWalk", Vector3(-84.0, 0.12, 0.9), Vector3(-75.0, 0.12, 0.9), 3.2, SAND)
	_path_segment(self, "CourthouseServiceAccess", Vector3(95.0, 0.12, -5.0), Vector3(84.0, 0.12, -5.0), 3.2, SAND)
	_path_segment(self, "CourthouseEntranceTurn", Vector3(84.0, 0.12, -5.0), Vector3(84.0, 0.12, 0.9), 3.2, SAND)
	_path_segment(self, "CourthouseFrontWalk", Vector3(84.0, 0.12, 0.9), Vector3(75.0, 0.12, 0.9), 3.2, SAND)
	_path_segment(self, "FireServiceAccess", Vector3(-95.0, 0.12, 15.0), Vector3(-84.0, 0.12, 15.0), 3.2, SAND)
	_path_segment(self, "FireEntranceTurn", Vector3(-84.0, 0.12, 15.0), Vector3(-84.0, 0.12, 20.9), 3.2, SAND)
	_path_segment(self, "FireFrontWalk", Vector3(-84.0, 0.12, 20.9), Vector3(-75.0, 0.12, 20.9), 3.2, SAND)
	_path_segment(self, "TrainServiceAccess", Vector3(95.0, 0.12, 15.0), Vector3(84.0, 0.12, 15.0), 3.2, SAND)
	_path_segment(self, "TrainEntranceTurn", Vector3(84.0, 0.12, 15.0), Vector3(84.0, 0.12, 20.9), 3.2, SAND)
	_path_segment(self, "TrainFrontWalk", Vector3(84.0, 0.12, 20.9), Vector3(75.0, 0.12, 20.9), 3.2, SAND)
	# Green buffers line the outer edges while keeping sidewalks, parking courts, and entrances clear.
	for side in [-1.0, 1.0]:
		for z in [-65.0, -35.0, -5.0, 55.0]:
			if side < 0.0 and z == -35.0:
				continue
			_tree(self, "OuterBoulevardPalm", Vector3(side * 87.0, 0, z), 0.85)


func _build_public_gardens() -> void:
	# Small landscaped pockets occupy the gaps between approved building footprints.
	for side in [-1.0, 1.0]:
		var garden := Node3D.new()
		garden.name = "PublicGarden_WestEast_%s" % str(side)
		garden.position = Vector3(side * 45.0, 0, 0)
		add_child(garden)
		_box(garden, "GardenLawn", Vector3(13.0, 0.12, 12.0), Vector3(0, 0.06, 0), Color(0.20, 0.38, 0.22))
		_box(garden, "GardenPath", Vector3(2.0, 0.08, 11.0), Vector3(0, 0.14, 0), SAND)
		for z in [-4.0, 4.0]:
			_tree(garden, "GardenPalm", Vector3(-4.5, 0, z), 0.72)
			_tree(garden, "GardenPalm", Vector3(4.5, 0, z), 0.72)
		_box(garden, "GardenBenchSeat", Vector3(3.0, 0.22, 0.65), Vector3(0, 0.72, -4.0), SAND)
		_box(garden, "GardenBenchBack", Vector3(3.0, 0.9, 0.18), Vector3(0, 1.12, -4.25), GOLD)
	# A modest fountain is a landmark inside the central pedestrian garden pocket.
	var fountain := Node3D.new()
	fountain.name = "CentralGardenFountain"
	fountain.position = Vector3(45, 0, 30)
	add_child(fountain)
	_box(fountain, "FountainBase", Vector3(5.0, 0.5, 5.0), Vector3(0, 0.25, 0), SAND)
	_box(fountain, "FountainBasin", Vector3(3.8, 0.45, 3.8), Vector3(0, 0.72, 0), TEAL)
	_box(fountain, "FountainColumn", Vector3(0.65, 1.8, 0.65), Vector3(0, 1.65, 0), IVORY)
	_box(fountain, "FountainCrown", Vector3(1.8, 0.25, 1.8), Vector3(0, 2.65, 0), GOLD)
	for x in [-2.0, 2.0]:
		_tree(fountain, "FountainGardenPalm", Vector3(x, 0, 3.8), 0.65)


func _build_pedestrian_green_pockets() -> void:
	# Three additional landscaped pockets fill the clear block gaps without moving
	# approved buildings, changing street alignments, or narrowing vehicle lanes.
	var pocket_centres: Array[Vector2] = [
		Vector2(-45.0, -30.0),
		Vector2(45.0, -30.0),
		Vector2(-45.0, 30.0)
	]
	for index in range(pocket_centres.size()):
		var centre := pocket_centres[index]
		var pocket := Node3D.new()
		pocket.name = "PedestrianGreenPocket_%02d" % (index + 1)
		pocket.position = Vector3(centre.x, 0.0, centre.y)
		add_child(pocket)
		_box(pocket, "PocketLawn", Vector3(10.0, 0.12, 10.0), Vector3(0.0, 0.06, 0.0), Color(0.20, 0.38, 0.22))
		# A central stone walk remains clear between the seating and palm planters.
		_box(pocket, "PocketWalkway", Vector3(2.0, 0.08, 9.8), Vector3(0.0, 0.15, 0.0), SAND)
		_add_static_box_collision(pocket, "PocketWalkwayCollision", Vector3(2.0, 0.22, 9.8), Vector3(0.0, 0.10, 0.0))
		for x in [-4.0, 4.0]:
			for z in [-4.0, 4.0]:
				_tree(pocket, "PocketPalm", Vector3(x, 0.0, z), 0.62)
		for side in [-1.0, 1.0]:
			var bench_x: float = side * 2.9
			_box(pocket, "PocketBenchSeat", Vector3(2.2, 0.22, 0.62), Vector3(bench_x, 0.72, 0.0), SAND)
			_box(pocket, "PocketBenchBack", Vector3(2.2, 0.82, 0.16), Vector3(bench_x, 1.12, -0.22), GOLD)
			_add_static_box_collision(pocket, "PocketBenchCollision", Vector3(2.2, 1.0, 0.62), Vector3(bench_x, 0.62, 0.0))
		# Join each pocket to the existing cross streets with collision-backed
		# pedestrian links; these links stay inside the open block gap.
		var upper_road_z := centre.y - 12.0
		var lower_road_z := centre.y + 12.0
		_path_segment(self, "PocketNorthWalk_%02d" % (index + 1), Vector3(centre.x, 0.12, upper_road_z), Vector3(centre.x, 0.12, centre.y - 5.0), 2.4, SAND)
		_path_segment(self, "PocketSouthWalk_%02d" % (index + 1), Vector3(centre.x, 0.12, centre.y + 5.0), Vector3(centre.x, 0.12, lower_road_z), 2.4, SAND)

func _path_segment(parent: Node3D, label: String, start: Vector3, finish: Vector3, width: float, color: Color) -> void:
	var delta := finish - start
	var segment_size := Vector3(width, 0.12, delta.length())
	var segment_position := (start + finish) * 0.5
	var segment := _box(parent, label, segment_size, segment_position, color)
	var segment_rotation := atan2(delta.x, delta.z)
	segment.rotation.y = segment_rotation
	# Every access path is physically walkable, not only a visible strip.
	var body := StaticBody3D.new()
	body.name = label + "WalkCollision"
	body.position = segment_position
	body.rotation.y = segment_rotation
	body.add_to_group("city_world_geometry")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.22, delta.length())
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _build_mountain_route() -> void:
	# The mountain zone is placed at the far eastern edge, beyond the service-building row.
	var mountain := Node3D.new()
	mountain.name = "KingsMountainRoute"
	mountain.position = Vector3(98, 0, 40)
	add_child(mountain)
	var lower := MeshInstance3D.new()
	lower.name = "MountainLowerSlope"
	var lower_mesh := CylinderMesh.new()
	lower_mesh.top_radius = 1.8
	lower_mesh.bottom_radius = 10.5
	lower_mesh.height = 15.0
	lower_mesh.radial_segments = 7
	lower_mesh.rings = 3
	lower.mesh = lower_mesh
	lower.position = Vector3(0, 7.5, 0)
	lower.material_override = _mat(Color(0.48, 0.39, 0.28))
	mountain.add_child(lower)
	var upper := MeshInstance3D.new()
	upper.name = "MountainUpperPeak"
	var upper_mesh := CylinderMesh.new()
	upper_mesh.top_radius = 0.0
	upper_mesh.bottom_radius = 6.0
	upper_mesh.height = 12.0
	upper_mesh.radial_segments = 7
	upper_mesh.rings = 2
	upper.mesh = upper_mesh
	upper.position = Vector3(0, 17.0, 0)
	upper.material_override = _mat(Color(0.61, 0.49, 0.34))
	mountain.add_child(upper)
	# Switchback walking route, with two rest stops and two observation decks.
	_path_segment(mountain, "MountainTrailEntrance", Vector3(-3.0, 0.18, 28.0), Vector3(-15.0, 0.18, 28.0), 3.2, SAND)
	var p0 := Vector3(-15.0, 0.18, 28.0)
	var p1 := Vector3(-9.0, 0.18, 20.0)
	var p2 := Vector3(-14.0, 0.18, 12.0)
	var p3 := Vector3(-7.0, 0.18, 5.0)
	var p4 := Vector3(-2.0, 0.18, -3.0)
	_path_segment(mountain, "MountainTrail_01", p0, p1, 3.2, SAND)
	_path_segment(mountain, "MountainTrail_02", p1, p2, 3.2, SAND)
	_path_segment(mountain, "MountainTrail_03", p2, p3, 3.2, SAND)
	_path_segment(mountain, "MountainTrail_04", p3, p4, 3.2, SAND)
	for i in range(4):
		var point: Vector3 = [p0, p1, p2, p3][i]
		var rail := _box(mountain, "TrailEdgeRail", Vector3(0.18, 0.75, 4.0), point + Vector3(-1.8, 0.55, 0), GOLD)
		rail.rotation.y = 0.55
	# Rest stop one.
	for stop_index in range(2):
		var stop := Node3D.new()
		stop.name = "MountainRestStop_%d" % (stop_index + 1)
		stop.position = Vector3(-12.0 + float(stop_index) * 7.0, 0.2, 18.0 - float(stop_index) * 13.0)
		mountain.add_child(stop)
		_box(stop, "RestStopFloor", Vector3(7.0, 0.2, 5.0), Vector3(0, 0.1, 0), IVORY)
		for x in [-3.0, 3.0]:
			for z in [-2.0, 2.0]:
				_box(stop, "RestStopColumn", Vector3(0.28, 2.6, 0.28), Vector3(x, 1.4, z), GOLD)
		_box(stop, "RestStopCanopy", Vector3(7.5, 0.35, 5.5), Vector3(0, 2.85, 0), SAND)
		_box(stop, "RestStopBench", Vector3(2.6, 0.25, 0.65), Vector3(0, 0.75, -1.2), DARK)
	# Observation platforms and the summit landmark.
	for i in range(2):
		var deck := Node3D.new()
		deck.name = "MountainViewPlatform_%d" % (i + 1)
		deck.position = Vector3(-2.0 + float(i) * 1.5, 7.0 + float(i) * 4.0, 4.0 - float(i) * 3.0)
		mountain.add_child(deck)
		_box(deck, "ViewDeck", Vector3(8.0, 0.35, 6.0), Vector3(0, 0, 0), SAND)
		for x in [-3.7, 3.7]:
			_box(deck, "ViewRail", Vector3(0.18, 1.0, 6.0), Vector3(x, 0.65, 0), GOLD)
		_box(deck, "ViewRailFront", Vector3(8.0, 1.0, 0.18), Vector3(0, 0.65, 2.8), GOLD)
	var summit := Node3D.new()
	summit.name = "KingsSummit"
	summit.position = Vector3(0, 21.0, -1.0)
	mountain.add_child(summit)

	# A generous 30 x 30 m royal panorama terrace, organized around the
	# existing obelisk and crown. The original trail, rest stops and view decks
	# remain in place; a new collision-backed switchback ramp reaches the plaza.
	_box(summit, "SummitPlatform", Vector3(30.0, 0.5, 30.0), Vector3(0.0, 0.0, 0.0), IVORY)
	var plaza_collision := StaticBody3D.new()
	plaza_collision.name = "SummitPlazaWalkableCollision"
	plaza_collision.position = Vector3(0.0, -0.02, 0.0)
	plaza_collision.add_to_group("city_world_geometry")
	var plaza_shape := CollisionShape3D.new()
	var plaza_box := BoxShape3D.new()
	plaza_box.size = Vector3(30.0, 0.5, 30.0)
	plaza_shape.shape = plaza_box
	plaza_collision.add_child(plaza_shape)
	summit.add_child(plaza_collision)

	# Low perimeter balustrades leave a broad entrance opening toward the ramp.
	for side in [-1.0, 1.0]:
		for offset in [-10.5, -5.5, 5.5, 10.5]:
			_box(summit, "SummitBalustradePost", Vector3(0.32, 1.15, 0.32), Vector3(side * 14.35, 0.82, offset), GOLD)
			_box(summit, "SummitBalustradePost", Vector3(0.32, 1.15, 0.32), Vector3(offset, 0.82, side * 14.35), GOLD)
		# Keep a wide vehicle-road opening on both side edges of the plaza.
		for rail_side in [-1.0, 1.0]:
			_box(summit, "SummitBalustradeSide", Vector3(0.22, 0.18, 10.0), Vector3(side * 14.35, 1.22, rail_side * 10.0), GOLD)
		_box(summit, "SummitBalustradeBack", Vector3(30.0, 0.18, 0.22), Vector3(0.0, 1.22, side * 14.35), GOLD)
	# Four restrained stone seating bays sit inside the corners, keeping the
	# central panorama and circulation route open.
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			var seat_at := Vector3(side * 10.5, 0.0, depth * 10.5)
			_box(summit, "SummitBenchSeat", Vector3(3.2, 0.24, 0.72), seat_at + Vector3(0.0, 0.62, 0.0), SAND)
			_box(summit, "SummitBenchBack", Vector3(3.2, 0.82, 0.18), seat_at + Vector3(0.0, 1.08, -0.28), GOLD)
	# Four low-glare royal lanterns mark the corners without obstructing views.
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			var lantern := Node3D.new()
			lantern.name = "SummitLantern"
			lantern.position = Vector3(side * 12.2, 0.0, depth * 12.2)
			summit.add_child(lantern)
			_box(lantern, "LanternBase", Vector3(0.55, 0.35, 0.55), Vector3(0.0, 0.18, 0.0), GOLD)
			_box(lantern, "LanternBody", Vector3(0.32, 0.72, 0.32), Vector3(0.0, 0.72, 0.0), IVORY)
			_box(lantern, "LanternCap", Vector3(0.62, 0.16, 0.62), Vector3(0.0, 1.18, 0.0), GOLD)

	# New four-flight switchback ramp joins the existing trail end to the plaza.
	# Each flight has a walkable sloped mesh and a matching StaticBody collider.
	var ramp_points: Array[Vector3] = [
		Vector3(-2.0, 0.18, -3.0),
		Vector3(-11.0, 5.4, -3.0),
		Vector3(-11.0, 10.6, -12.0),
		Vector3(10.0, 15.8, -12.0),
		Vector3(10.0, 21.0, -3.0)
	]
	for ramp_index in range(ramp_points.size() - 1):
		var ramp_start: Vector3 = ramp_points[ramp_index]
		var ramp_end: Vector3 = ramp_points[ramp_index + 1]
		var ramp_delta := ramp_end - ramp_start
		var ramp_length := ramp_delta.length()
		var ramp_midpoint := (ramp_start + ramp_end) * 0.5
		var ramp := _box(mountain, "SummitAccessRamp_%02d" % (ramp_index + 1), Vector3(3.8, 0.28, ramp_length), ramp_midpoint, SAND)
		ramp.look_at_from_position(mountain.to_global(ramp_midpoint), mountain.to_global(ramp_end), Vector3.UP)
		var ramp_body := StaticBody3D.new()
		ramp_body.name = "SummitAccessRampCollision_%02d" % (ramp_index + 1)
		ramp_body.position = ramp_midpoint
		ramp_body.look_at_from_position(mountain.to_global(ramp_midpoint), mountain.to_global(ramp_end), Vector3.UP)
		ramp_body.add_to_group("city_world_geometry")
		var ramp_collision := CollisionShape3D.new()
		var ramp_shape := BoxShape3D.new()
		ramp_shape.size = Vector3(3.8, 0.32, ramp_length)
		ramp_collision.shape = ramp_shape
		ramp_body.add_child(ramp_collision)
		mountain.add_child(ramp_body)
		# Narrow gold edge markers make each ramp flight legible at a glance.
		var ramp_side := Vector3(-ramp_delta.z, 0.0, ramp_delta.x).normalized()
		for edge in [-1.0, 1.0]:
			var edge_marker := _box(mountain, "SummitRampEdge", Vector3(0.12, 0.22, ramp_length), ramp_midpoint + ramp_side * edge * 1.92 + Vector3(0.0, 0.18, 0.0), GOLD)
			edge_marker.rotation = ramp.rotation

	# Separate low-gradient access for cars and electric scooters. The original
	# narrow walking trail and the four-flight pedestrian summit ramp stay intact.
	_build_mountain_vehicle_access(mountain)

	_box(summit, "SummitObelisk", Vector3(1.2, 4.5, 1.2), Vector3(0, 2.4, 0), GOLD)
	_box(summit, "SummitCrown", Vector3(2.4, 0.35, 2.4), Vector3(0, 4.8, 0), GOLD)


# نسخ إضافية من حيوانات المخيم موزعة على جوانب الجبل بعيداً عن مسار الصعود.
var mountain_wildlife_nodes: Array[Node3D] = []
var mountain_wildlife_base_positions: Array[Vector3] = []
var mountain_wildlife_clock := 0.0

func _process(delta: float) -> void:
	mountain_wildlife_clock += delta
	for i in range(mountain_wildlife_nodes.size()):
		var animal := mountain_wildlife_nodes[i]
		if is_instance_valid(animal):
			var phase := float(i) * 0.91
			animal.rotation.y = sin(mountain_wildlife_clock * 0.34 + phase) * 0.055
			if animal.name == "MountainFalcon":
				animal.position.y = mountain_wildlife_base_positions[i].y + sin(mountain_wildlife_clock * 1.8 + phase) * 0.045


func _build_mountain_vehicle_access(mountain: Node3D) -> void:
	var road := Node3D.new()
	road.name = "MountainVehicleAccessRoad"
	mountain.add_child(road)

	# Join the eastern perimeter road at the existing mountain approach.
	_add_sloped_vehicle_road_segment(road, "MountainVehicleRoadEntry",
		Vector3(-3.0, 0.18, 28.0), Vector3(14.0, 0.18, 34.0), 6.5, false)

	# Eight broad switchback legs climb around the outside of the mountain.
	# Each 2.62 m rise is spread over roughly 41 m of travel (about 6.5% grade).
	var route_points: Array[Vector3] = [
		Vector3(14.0, 0.18, 34.0),
		Vector3(54.0, 2.8, 26.0),
		Vector3(14.0, 5.4, 18.0),
		Vector3(54.0, 8.0, 10.0),
		Vector3(14.0, 10.6, 2.0),
		Vector3(54.0, 13.2, -6.0),
		Vector3(14.0, 15.8, -14.0),
		Vector3(54.0, 18.4, -22.0),
		Vector3(14.0, 21.0, -30.0),
		Vector3(14.0, 21.0, -1.0)
	]
	for i in range(route_points.size() - 1):
		_add_sloped_vehicle_road_segment(road, "MountainVehicleRoad_%02d" % (i + 1),
			route_points[i], route_points[i + 1], 6.5, true)

	# Wide, collision-backed turning aprons keep the alternating bends usable.
	for i in range(1, route_points.size() - 1):
		var point: Vector3 = route_points[i]
		var landing_center := Vector3(maxf(point.x, 17.5), point.y, point.z)
		_box(road, "MountainVehicleTurnout_%02d" % i,
			Vector3(12.0, 0.22, 12.0), landing_center, SAND)
		var landing_body := StaticBody3D.new()
		landing_body.name = "MountainVehicleTurnoutCollision_%02d" % i
		landing_body.position = landing_center
		landing_body.add_to_group("city_world_geometry")
		var landing_shape := CollisionShape3D.new()
		var landing_box := BoxShape3D.new()
		landing_box.size = Vector3(12.0, 0.3, 12.0)
		landing_shape.shape = landing_box
		landing_body.add_child(landing_shape)
		road.add_child(landing_body)

	# A small upper pull-off lets drivers stop before walking onto the summit plaza.
	var pull_off := _box(road, "MountainSummitVehiclePullOff",
		Vector3(12.0, 0.22, 10.0), Vector3(14.0, 21.0, -1.0), IVORY)
	var pull_off_body := StaticBody3D.new()
	pull_off_body.name = "MountainSummitVehiclePullOffCollision"
	pull_off_body.position = Vector3(14.0, 21.0, -1.0)
	pull_off_body.add_to_group("city_world_geometry")
	var pull_off_shape := CollisionShape3D.new()
	var pull_off_box := BoxShape3D.new()
	pull_off_box.size = Vector3(12.0, 0.3, 10.0)
	pull_off_shape.shape = pull_off_box
	pull_off_body.add_child(pull_off_shape)
	road.add_child(pull_off_body)


func _add_sloped_vehicle_road_segment(parent: Node3D, label: String,
		start: Vector3, finish: Vector3, width: float, add_guardrails: bool) -> void:
	var delta := finish - start
	var length := delta.length()
	var midpoint := (start + finish) * 0.5
	var segment := _box(parent, label, Vector3(width, 0.28, length), midpoint, SAND)
	segment.look_at_from_position(parent.to_global(midpoint), parent.to_global(start), Vector3.UP)

	var body := StaticBody3D.new()
	body.name = label + "Collision"
	body.position = midpoint
	body.look_at_from_position(parent.to_global(midpoint), parent.to_global(start), Vector3.UP)
	body.add_to_group("city_world_geometry")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.36, length + 0.25)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

	if add_guardrails:
		var rails := Node3D.new()
		rails.name = label + "Guardrails"
		rails.position = midpoint
		rails.look_at_from_position(parent.to_global(midpoint), parent.to_global(start), Vector3.UP)
		parent.add_child(rails)
		for side in [-1.0, 1.0]:
			var rail_at := Vector3(side * (width * 0.5 - 0.18), 0.55, 0.0)
			_box(rails, "VehicleRoadGuardrail", Vector3(0.18, 0.9, length), rail_at, GOLD)
			var rail_body := StaticBody3D.new()
			rail_body.name = "VehicleRoadGuardrailCollision"
			rail_body.position = rail_at
			rail_body.add_to_group("city_world_geometry")
			var rail_collision := CollisionShape3D.new()
			var rail_shape := BoxShape3D.new()
			rail_shape.size = Vector3(0.28, 1.0, length)
			rail_collision.shape = rail_shape
			rail_body.add_child(rail_collision)
			rails.add_child(rail_body)


func _build_mountain_animals() -> void:
	var mountain := get_node_or_null("KingsMountainRoute") as Node3D
	if mountain == null:
		return
	var wildlife := [
		{"id":"MountainArabianCamel","label":"جمل عربي","kind":"camel","at":Vector3(8.2,0.25,22.0),"color":Color(0.62,0.43,0.25)},
		{"id":"MountainArabianHorse","label":"حصان عربي","kind":"horse","at":Vector3(15.0,0.2,15.0),"color":Color(0.28,0.16,0.11)},
		{"id":"MountainArabianOryx","label":"مها عربي","kind":"oryx","at":Vector3(-7.0,2.7,5.0),"color":Color(0.88,0.82,0.68)},
		{"id":"MountainGazelle","label":"غزال","kind":"gazelle","at":Vector3(7.8,2.5,4.5),"color":Color(0.70,0.48,0.29)},
		{"id":"MountainFennecFox","label":"ثعلب صحراوي","kind":"fox","at":Vector3(4.5,2.8,-7.2),"color":Color(0.86,0.62,0.34)},
		{"id":"MountainSheep","label":"أغنام","kind":"sheep","at":Vector3(-8.2,2.3,-2.0),"color":Color(0.82,0.78,0.67)},
		{"id":"MountainGoat","label":"ماعز","kind":"goat","at":Vector3(6.5,3.0,7.5),"color":Color(0.48,0.34,0.22)},
		{"id":"MountainFalcon","label":"صقر","kind":"falcon","at":Vector3(2.5,13.5,-1.5),"color":Color(0.48,0.34,0.22)}
	]
	for spec in wildlife:
		var animal := Node3D.new()
		animal.name = str(spec["id"])
		animal.position = spec["at"]
		animal.add_to_group("mountain_wildlife")
		mountain.add_child(animal)
		_build_mountain_animal_mesh(animal, str(spec["kind"]), spec["color"])
		var label := Label3D.new()
		label.name = "WildlifeName"
		label.text = str(spec["label"])
		label.position = Vector3(0, 2.5, 0)
		label.font_size = 25
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		animal.add_child(label)
		mountain_wildlife_nodes.append(animal)
		mountain_wildlife_base_positions.append(animal.position)

func _build_mountain_animal_mesh(animal: Node3D, kind: String, coat: Color) -> void:
	var body := MeshInstance3D.new()
	body.name = "WildlifeBody"
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.48 if kind != "camel" else 0.62
	body_mesh.height = body_mesh.radius * 2.0
	body_mesh.radial_segments = 7
	body_mesh.rings = 4
	body.mesh = body_mesh
	body.scale = Vector3(1.25, 0.9, 1.55)
	body.position = Vector3(0, 0.95, 0)
	body.material_override = _mat(coat)
	animal.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "WildlifeHead"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head_mesh.radial_segments = 7
	head_mesh.rings = 4
	head.mesh = head_mesh
	head.position = Vector3(0, 1.48, -0.58)
	head.material_override = _mat(coat.lightened(0.08))
	animal.add_child(head)

	if kind == "falcon":
		body.position.y = 1.0
		head.position = Vector3(0, 1.42, -0.35)
		for side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			wing.name = "FalconWing"
			var wing_mesh := BoxMesh.new()
			wing_mesh.size = Vector3(0.16, 0.12, 1.2)
			wing.mesh = wing_mesh
			wing.position = Vector3(side * 0.48, 1.05, 0.0)
			wing.rotation.z = side * -0.12
			wing.material_override = _mat(coat.darkened(0.12))
			animal.add_child(wing)
		return

	if kind == "camel":
		var hump := MeshInstance3D.new()
		hump.name = "CamelHump"
		var hump_mesh := SphereMesh.new()
		hump_mesh.radius = 0.38
		hump_mesh.height = 0.76
		hump.mesh = hump_mesh
		hump.position = Vector3(0, 1.55, 0.05)
		hump.material_override = _mat(coat.darkened(0.06))
		animal.add_child(hump)

	for side in [-1.0, 1.0]:
		for front_back in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			leg.name = "WildlifeLeg"
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.07
			leg_mesh.bottom_radius = 0.10
			leg_mesh.height = 0.78
			leg_mesh.radial_segments = 6
			leg.mesh = leg_mesh
			leg.position = Vector3(side * 0.25, 0.42, front_back * 0.34)
			leg.material_override = _mat(coat.darkened(0.16))
			animal.add_child(leg)

	if kind == "oryx" or kind == "gazelle" or kind == "goat":
		for side in [-1.0, 1.0]:
			var horn := MeshInstance3D.new()
			horn.name = "WildlifeHorn"
			var horn_mesh := CylinderMesh.new()
			horn_mesh.top_radius = 0.015
			horn_mesh.bottom_radius = 0.075
			horn_mesh.height = 0.62 if kind != "oryx" else 0.9
			horn_mesh.radial_segments = 5
			horn.mesh = horn_mesh
			horn.position = Vector3(side * 0.16, 1.95, -0.58)
			horn.rotation.z = side * -0.16
			horn.material_override = _mat(Color(0.22, 0.17, 0.12))
			animal.add_child(horn)

	if kind == "fox":
		var tail := MeshInstance3D.new()
		tail.name = "FennecTail"
		var tail_mesh := SphereMesh.new()
		tail_mesh.radius = 0.22
		tail_mesh.height = 0.44
		tail.mesh = tail_mesh
		tail.position = Vector3(0, 0.95, 0.72)
		tail.scale = Vector3(0.85, 0.85, 1.8)
		tail.material_override = _mat(Color(0.94, 0.84, 0.68))
		animal.add_child(tail)

	if kind == "sheep":
		for i in range(4):
			var wool := MeshInstance3D.new()
			wool.name = "SheepWool"
			var wool_mesh := SphereMesh.new()
			wool_mesh.radius = 0.24
			wool_mesh.height = 0.48
			wool.mesh = wool_mesh
			wool.position = Vector3(float(i - 2) * 0.2, 1.2, 0.12)
			wool.material_override = _mat(coat.lightened(0.08))
			animal.add_child(wool)

func _build_city_lighting_and_wayfinding() -> void:
	# Low-cost decorative lamp posts mark the main pedestrian routes and plaza edges.
	var lamp_points := [
		Vector3(-24, 0, -42), Vector3(24, 0, -42),
		Vector3(-45, 0, -18), Vector3(45, 0, -18),
		Vector3(-45, 0, 18), Vector3(45, 0, 18),
		Vector3(-45, 0, 48), Vector3(45, 0, 48),
		Vector3(-80, 0, 34), Vector3(80, 0, 34)
	]
	for i in range(lamp_points.size()):
		var lamp := Node3D.new()
		lamp.name = "CityLamp_%02d" % i
		lamp.position = lamp_points[i]
		add_child(lamp)
		_box(lamp, "LampPost", Vector3(0.22, 4.2, 0.22), Vector3(0, 2.1, 0), GOLD)
		_box(lamp, "LampArm", Vector3(1.1, 0.16, 0.16), Vector3(0.48, 4.0, 0), GOLD)
		_box(lamp, "LampHead", Vector3(0.7, 0.32, 0.55), Vector3(0.95, 3.85, 0), IVORY)
		_add_city_night_light(lamp, "CityLampNightLight", Vector3(0.95, 3.7, 0.0), 8.5)
	# Direction markers use bilingual labels without adding standalone buildings.
	var sign_specs := [
		["Sign_RoyalSquare", Vector3(8, 0, -24), "الميدان الملكي"],
		["Sign_CommercialDistrict", Vector3(44, 0, -8), "المنطقة التجارية"],
		["Sign_EntertainmentDistrict", Vector3(-44, 0, 48), "المنطقة الترفيهية"],
		["Sign_Harbor", Vector3(20, 0, 70), "الميناء الملكي"],
		["Sign_KingsMountain", Vector3(88, 0, 62), "طريق قمة الملوك"]
	]
	for spec in sign_specs:
		var sign := Node3D.new()
		sign.name = str(spec[0])
		sign.position = spec[1]
		add_child(sign)
		_box(sign, "SignBoard", Vector3(4.6, 1.0, 0.18), Vector3(0, 2.8, 0), DARK)
		_box(sign, "SignTopTrim", Vector3(4.8, 0.12, 0.22), Vector3(0, 3.35, 0), GOLD)
		var label := Label3D.new()
		label.name = "DistrictLabel"
		label.text = str(spec[2])
		label.position = Vector3(0, 2.8, -0.13)
		label.font_size = 32
		label.pixel_size = 0.012
		label.modulate = Color(1.0, 0.9, 0.64)
		label.outline_size = 6
		sign.add_child(label)


func _add_city_night_light(parent: Node3D, label: String, at: Vector3, radius: float) -> void:
	# Warm point lights stay disabled by day and never cast real-time shadows on Android.
	var light := OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = Color(1.0, 0.66, 0.34)
	light.light_energy = 0.0
	light.omni_range = radius
	light.shadow_enabled = false
	light.add_to_group("city_night_lights")
	parent.add_child(light)



func _build_npc_population() -> void:
	var population_script := load("res://scripts/city_npc_population.gd") as Script
	if population_script == null:
		push_warning("تعذر تحميل نظام توزيع الشخصيات الافتراضية.")
		return
	var population := Node3D.new()
	population.name = "CityNPCPopulation"
	population.set_script(population_script)
	add_child(population)


func _build_royal_square_mosaic_mural() -> void:
	# Temporary first-pass in-world mosaic mural on the palace facade facing the royal square.
	# It is built from the same scene geometry (one colored MultiMesh), not a separate concept image.
	var palace := get_node_or_null("Approved_royal_palace") as Node3D
	if palace == null:
		push_warning("تعذر العثور على واجهة القصر لوضع جدارية الفسيفساء.")
		return

	var mural := Node3D.new()
	mural.name = "RoyalSquareHistoricalMosaicPreview"
	mural.position = Vector3(-4.80, 5.65, 8.03)
	# Keep the full panel between the palace column and doorway so no facade element hides it.
	mural.scale = Vector3(0.86, 0.86, 1.0)
	mural.add_to_group("royal_square_mosaic_preview")
	palace.add_child(mural)

	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(0.086, 0.086, 0.045)
	var tile_material := StandardMaterial3D.new()
	tile_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	tile_material.vertex_color_use_as_albedo = true
	tile_material.roughness = 0.82
	tile_material.metallic = 0.08
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = tile_mesh

	var columns := 60
	var rows := 34
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var blue := Color(0.035, 0.23, 0.34)
	var turquoise := Color(0.08, 0.48, 0.49)
	var gold := Color(0.88, 0.62, 0.22)
	var dark_gold := Color(0.47, 0.29, 0.10)
	var sandstone := Color(0.78, 0.62, 0.40)
	var skin := Color(0.86, 0.66, 0.45)
	var dark := Color(0.12, 0.10, 0.08)
	var red := Color(0.58, 0.16, 0.12)
	var ivory := Color(0.91, 0.82, 0.64)

	for row in range(rows):
		for column in range(columns):
			var u := float(column) / float(columns - 1)
			var v := float(row) / float(rows - 1)
			var color := blue if (column + row) % 3 != 0 else turquoise
			var border := column == 0 or column == columns - 1 or row == 0 or row == rows - 1
			if border:
				color = gold if (column + row) % 2 == 0 else dark_gold
			else:
				# A stylized pharaonic profile in the left half of the mosaic.
				var face_dx := (u - 0.34) / 0.19
				var face_dy := (v - 0.48) / 0.34
				if face_dx * face_dx + face_dy * face_dy < 1.0:
					color = skin
				if u > 0.24 and u < 0.47 and v > 0.18 and v < 0.31:
					color = gold if column % 3 == 0 else dark_gold
				if absf(u - 0.41) < 0.025 and absf(v - 0.47) < 0.025:
					color = dark
				if absf(u - 0.49) < 0.018 and v > 0.35 and v < 0.72:
					color = gold
				# Gold-and-red royal headdress stripes.
				if u > 0.18 and u < 0.52 and v > 0.16 and v < 0.28 and row % 2 == 0:
					color = red if column % 3 == 0 else gold
				# A horse and chariot procession occupies the lower-right area.
				var horse_body := u > 0.59 and u < 0.84 and v > 0.57 and v < 0.75
				var horse_neck := u > 0.77 and u < 0.86 and v > 0.42 and v < 0.64
				var horse_head := u > 0.82 and u < 0.91 and v > 0.38 and v < 0.49
				if horse_body or horse_neck or horse_head:
					color = sandstone
				if u > 0.62 and u < 0.68 and v > 0.72 and v < 0.91:
					color = dark_gold
				if u > 0.77 and u < 0.82 and v > 0.72 and v < 0.91:
					color = dark_gold
				# Chariot wheel and long reins.
				var wheel_dx := (u - 0.91) / 0.065
				var wheel_dy := (v - 0.75) / 0.12
				if wheel_dx * wheel_dx + wheel_dy * wheel_dy < 1.0:
					color = gold if absf(wheel_dx * wheel_dx + wheel_dy * wheel_dy - 0.55) < 0.32 else red
				if u > 0.50 and u < 0.83 and absf(v - (0.34 + (u - 0.50) * 0.55)) < 0.018:
					color = ivory
				# Small hieroglyphic-inspired gold marks along the upper field.
				if v < 0.18 and int(u * 100.0) % 7 < 2:
					color = gold

			var tile_x := -2.70 + float(column) * 0.093
			var tile_y := -1.49 + float(row) * 0.093
			transforms.append(Transform3D(Basis.IDENTITY, Vector3(tile_x, tile_y, 0.0)))
			colors.append(color)

	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
		multi.set_instance_color(index, colors[index])

	var tiles := MultiMeshInstance3D.new()
	tiles.name = "RoyalHistoricalMosaicTiles"
	tiles.multimesh = multi
	tiles.material_override = tile_material
	tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mural.add_child(tiles)

	# Slim inlaid edges sit flush with the wall and visually finish the mosaic.
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		edge.name = "MosaicGoldSideInlay"
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.055, 3.22, 0.045)
		edge.mesh = edge_mesh
		edge.position = Vector3(side * 2.84, 0.0, 0.0)
		edge.material_override = _mat(gold, 0.58)
		mural.add_child(edge)
