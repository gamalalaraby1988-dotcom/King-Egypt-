extends Node3D
## Standalone visual blockout for review. It is intentionally not instanced in main.tscn.
## Geometry is schematic and has no gameplay collision; do not treat it as production terrain.

const GOLD := Color(0.78, 0.55, 0.20)
const IVORY := Color(0.91, 0.86, 0.72)
const SAND := Color(0.76, 0.63, 0.42)
const DEEP_WATER := Color(0.025, 0.20, 0.29)
const SHALLOW_WATER := Color(0.16, 0.48, 0.53)
const ROAD := Color(0.16, 0.17, 0.18)
const WARNING := Color(0.75, 0.12, 0.10)
const GYM_WOOD := Color(0.39, 0.25, 0.13)
const GYM_METAL := Color(0.20, 0.22, 0.23)

func _ready() -> void:
	_build_land_and_beach()
	_build_open_beach_gym()
	_build_beach_activity_path()
	_build_open_water()
	_build_bridge_and_arrival()
	_build_bridge_details()
	_build_ship_gate_interaction()
	_build_five_civilizations_ship_blockout()
	_build_ship_detail_pass()
	_scale_royal_ship_visuals(1.28)
	_build_option_b_southern_roads()
	_mark_preserved_ship_and_conflicts()
	# Centered frontal review angle: show the ship gate symmetrically, its full wide silhouette, and the bridge approach.
	$PreviewCamera.position = Vector3(0.0, 22.0, 135.0)
	$PreviewCamera.fov = 56.0
	$PreviewCamera.look_at(Vector3(0.0, 9.0, 88.0), Vector3.UP)

func _material(color: Color, roughness: float = 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _box(label: String, size: Vector3, position: Vector3, color: Color, parent: Node = null) -> MeshInstance3D:
	var target: Node = self if parent == null else parent
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	if label.begins_with("FiveCivilizationsShip_") or label.begins_with("ShipSuperstructure_") or label.begins_with("ShipRoyalGate_") or label.begins_with("ShipGate_") or label.begins_with("ShipPharaoh_") or label.begins_with("Tutankhamun_") or label.begins_with("ShipHull_") or label.begins_with("ShipTier_"):
		node.add_to_group("royal_ship_visuals")
	target.add_child(node)
	return node

func _ellipsoid(label: String, radii: Vector3, position: Vector3, color: Color, parent: Node = null) -> MeshInstance3D:
	var target: Node = self if parent == null else parent
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	node.mesh = mesh
	node.position = position
	node.scale = radii
	node.material_override = _material(color, 0.28)
	if label.begins_with("ShipPharaoh_") or label.begins_with("Tutankhamun_"):
		node.add_to_group("royal_ship_visuals")
	target.add_child(node)
	return node

func _label(text: String, position: Vector3, color: Color = IVORY, font_size: int = 34) -> void:
	var node := Label3D.new()
	node.name = "Label_" + text.replace(" ", "_")
	node.text = text
	node.position = position
	node.font_size = font_size
	node.pixel_size = 0.012
	node.modulate = color
	node.outline_size = 8
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if text == "KING OF EGYPT CITY":
		node.add_to_group("royal_ship_visuals")
	add_child(node)

func _build_land_and_beach() -> void:
	# The shoreline is a review boundary, not a final surveyed coastline.
	_box("LandMass_Blockout", Vector3(220.0, 0.5, 104.0), Vector3(0.0, -0.35, 158.0), Color(0.34, 0.42, 0.31))
	_box("RoyalCoastalCorniche", Vector3(190.0, 0.24, 7.0), Vector3(0.0, 0.12, 119.0), SAND)
	_box("ContinuousSandyBeach", Vector3(180.0, 0.18, 46.0), Vector3(0.0, 0.08, 130.0), Color(0.83, 0.72, 0.53))
	# The handball court is integrated into the same continuous beach surface: no raised pad or separate material.
	# Its existing footprint and center are retained; only low-profile court markings identify the play area.
	_box("BeachCourtLine_N", Vector3(27.0, 0.035, 0.12), Vector3(40.0, 0.20, 119.0), IVORY)
	_box("BeachCourtLine_S", Vector3(27.0, 0.035, 0.12), Vector3(40.0, 0.20, 131.0), IVORY)
	_box("BeachCourtLine_W", Vector3(0.12, 0.035, 12.0), Vector3(26.5, 0.20, 125.0), IVORY)
	_box("BeachCourtLine_E", Vector3(0.12, 0.035, 12.0), Vector3(53.5, 0.20, 125.0), IVORY)
	_label("ROYAL BEACH HANDBALL COURT - INTEGRATED IN THE SAND", Vector3(40.0, 2.0, 139.0), IVORY, 22)
	_label("ROYAL CORNICHE", Vector3(-58.0, 2.0, 119.0), GOLD, 28)

func _build_open_beach_gym() -> void:
	# Open-air fitness zone on the western side of the beach, separated from the handball play area.
	# The low, flush exercise surface is a visual placeholder; gameplay collision and equipment interaction are not implemented.
	var gym_center := Vector3(-48.0, 0.18, 132.0)
	_box("BeachGym_SoftTrainingSurface", Vector3(26.0, 0.12, 16.0), gym_center, Color(0.65, 0.54, 0.39))
	# Open-sided shade pergola: four posts and slim beams only, with no enclosed walls.
	for x_offset in [-11.0, 11.0]:
		for z_offset in [-6.5, 6.5]:
			_box("BeachGym_PergolaPost", Vector3(0.35, 3.0, 0.35), gym_center + Vector3(x_offset, 1.55, z_offset), GYM_WOOD)
	_box("BeachGym_PergolaBeam_Long_A", Vector3(23.0, 0.28, 0.32), gym_center + Vector3(0.0, 3.05, -6.5), GYM_WOOD)
	_box("BeachGym_PergolaBeam_Long_B", Vector3(23.0, 0.28, 0.32), gym_center + Vector3(0.0, 3.05, 6.5), GYM_WOOD)
	_box("BeachGym_PergolaBeam_Side_A", Vector3(0.32, 0.28, 13.0), gym_center + Vector3(-11.0, 3.05, 0.0), GYM_WOOD)
	_box("BeachGym_PergolaBeam_Side_B", Vector3(0.32, 0.28, 13.0), gym_center + Vector3(11.0, 3.05, 0.0), GYM_WOOD)
	# Simple recognizable equipment silhouettes, all kept within the gym footprint.
	_box("BeachGym_PullUpBar", Vector3(5.0, 0.16, 0.16), gym_center + Vector3(-7.0, 2.35, -2.5), GYM_METAL)
	_box("BeachGym_PullUpPost_L", Vector3(0.16, 2.4, 0.16), gym_center + Vector3(-9.5, 1.25, -2.5), GYM_METAL)
	_box("BeachGym_PullUpPost_R", Vector3(0.16, 2.4, 0.16), gym_center + Vector3(-4.5, 1.25, -2.5), GYM_METAL)
	_box("BeachGym_ParallelBars", Vector3(4.0, 0.14, 0.14), gym_center + Vector3(6.0, 1.15, 2.5), GYM_METAL)
	_box("BeachGym_Bench", Vector3(2.6, 0.18, 0.8), gym_center + Vector3(5.5, 0.62, -3.5), GYM_WOOD)
	_box("BeachGym_StretchingRail", Vector3(4.0, 0.12, 0.12), gym_center + Vector3(-6.0, 1.0, 4.0), GYM_METAL)
	_label("OPEN-AIR BEACH FITNESS", Vector3(-48.0, 4.0, 132.0), GOLD, 25)
	_label("OPEN SIDES • SEA VIEW • NO ENCLOSURE", Vector3(-48.0, 3.6, 141.5), IVORY, 16)


func _build_beach_activity_path() -> void:
	# A compacted-sand pedestrian path links the gym and handball court without crossing either play area.
	var path_material := Color(0.72, 0.62, 0.47)
	_box("BeachActivityPath_Main", Vector3(88.0, 0.045, 2.4), Vector3(-4.0, 0.205, 146.0), path_material)
	_box("BeachActivityPath_GymConnector", Vector3(2.4, 0.045, 6.0), Vector3(-48.0, 0.205, 143.0), path_material)
	_box("BeachActivityPath_CourtConnector", Vector3(2.4, 0.045, 3.0), Vector3(40.0, 0.205, 144.5), path_material)
	_label("BEACH ACTIVITY WALKWAY", Vector3(-4.0, 1.8, 148.0), GOLD, 18)

func _build_open_water() -> void:
	# Water covers the former promenade and enclosed marina basin as one open body.
	_box("OpenSea_Main", Vector3(190.0, 0.22, 42.0), Vector3(0.0, -0.08, 86.0), DEEP_WATER)
	_box("WalkableShallows_VisualBand", Vector3(180.0, 0.12, 5.0), Vector3(0.0, 0.02, 108.0), SHALLOW_WATER)
	_box("ShorelineTransitionBand", Vector3(180.0, 0.10, 3.0), Vector3(0.0, 0.04, 104.0), Color(0.25, 0.56, 0.56))
	_label("OPEN SEA - FORMER PROMENADE + MARINA FOOTPRINT", Vector3(47.0, 2.0, 72.0), IVORY, 26)
	_label("SHALLOW WALKING ZONE (VISUAL ONLY)", Vector3(62.0, 1.6, 106.0), IVORY, 20)

func _build_bridge_and_arrival() -> void:
	# Overall 13m concept width: 8.5m two-way carriageway + 2.25m protected walkways each side.
	var center_x := 0.0
	_box("RoyalBridgeDeck", Vector3(13.0, 0.45, 17.0), Vector3(center_x, 0.52, 99.5), IVORY)
	_box("BridgeTwoWayRoad", Vector3(8.5, 0.08, 17.0), Vector3(center_x, 0.80, 99.5), ROAD)
	for side: float in [-1.0, 1.0]:
		var walkway_x: float = center_x + side * 5.375
		_box("ProtectedPedestrianWalkway", Vector3(2.25, 0.12, 17.0), Vector3(walkway_x, 0.86, 99.5), SAND)
		_box("BridgeSafetyBarrier", Vector3(0.18, 1.0, 17.0), Vector3(center_x + side * 6.42, 1.05, 99.5), GOLD)
		_box("BridgePedestrianSeparator", Vector3(0.14, 0.72, 17.0), Vector3(center_x + side * 4.22, 1.02, 99.5), GOLD)
	_box("ArrivalPlatform", Vector3(13.0, 0.55, 10.0), Vector3(center_x, 0.55, 85.5), SAND)
	_box("LandRampTransition", Vector3(13.0, 0.30, 5.0), Vector3(center_x, 0.30, 110.5), IVORY)
	_label("ROYAL BRIDGE - 2 WAY ROAD", Vector3(center_x, 3.0, 101.0), GOLD, 25)
	_label("PROTECTED WALKWAYS", Vector3(center_x - 8.0, 2.0, 98.0), IVORY, 19)
	_label("ARRIVAL PLATFORM", Vector3(center_x, 2.0, 87.0), GOLD, 22)


func _emissive_material(color: Color, energy: float = 2.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.28
	return material

func _cylinder(label: String, radius: float, height: float, position: Vector3, material: Material, parent: Node = null) -> MeshInstance3D:
	var target: Node = self if parent == null else parent
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = position
	node.material_override = material
	if label.begins_with("ShipHull_") or label.begins_with("ShipPharaoh_"):
		node.add_to_group("royal_ship_visuals")
	target.add_child(node)
	return node

func _build_bridge_details() -> void:
	# Decorative/readability pass on the same 13m two-way bridge blockout.
	for side: float in [-1.0, 1.0]:
		var x: float = side * 2.1
		_box("BridgeCenterDoubleGoldLine", Vector3(0.10, 0.025, 17.0), Vector3(x, 0.855, 99.5), GOLD)
		for z: float in [94.0, 99.0, 104.0]:
			var lamp_x: float = side * 5.7
			_box("BridgeLampPedestal", Vector3(0.55, 0.45, 0.55), Vector3(lamp_x, 1.12, z), GOLD)
			_box("BridgeLampPost", Vector3(0.12, 2.0, 0.12), Vector3(lamp_x, 2.25, z), GOLD)
			_box("BridgeLampHead", Vector3(0.48, 0.22, 0.48), Vector3(lamp_x, 3.35, z), IVORY)

func _build_ship_gate_interaction() -> void:
	# The ship-facing end widens into a terminal apron. Cars bypass the central
	# pedestrian interaction pad on two flanking lanes; the ring is not in a live lane.
	var apron_z := 91.5
	_box("ShipApproachFlaredApron", Vector3(22.0, 0.42, 11.0), Vector3(0.0, 0.78, apron_z), IVORY)
	_box("ShipApproachVehicleLane_Left", Vector3(6.0, 0.09, 11.0), Vector3(-8.0, 1.035, apron_z), ROAD)
	_box("ShipApproachVehicleLane_Right", Vector3(6.0, 0.09, 11.0), Vector3(8.0, 1.035, apron_z), ROAD)
	_box("ShipApproachPedestrianIsland", Vector3(8.0, 0.16, 9.0), Vector3(0.0, 1.07, 91.5), SAND)
	var glow := _emissive_material(Color(1.0, 0.62, 0.12), 3.5)
	var inner_glow := _emissive_material(Color(1.0, 0.88, 0.42), 4.0)
	_cylinder("ShipInteractionPad_Base", 3.2, 0.12, Vector3(0.0, 1.20, 91.5), _material(Color(0.12, 0.10, 0.07), 0.3))
	var outer_ring := MeshInstance3D.new()
	outer_ring.name = "ShipInteractionPad_OuterGlowingRing"
	var outer_mesh := TorusMesh.new()
	outer_mesh.inner_radius = 3.05
	outer_mesh.outer_radius = 3.22
	outer_ring.mesh = outer_mesh
	outer_ring.position = Vector3(0.0, 1.30, 91.5)
	outer_ring.material_override = glow
	add_child(outer_ring)
	var inner_ring := MeshInstance3D.new()
	inner_ring.name = "ShipInteractionPad_InnerGlowingRing"
	var inner_mesh := TorusMesh.new()
	inner_mesh.inner_radius = 2.55
	inner_mesh.outer_radius = 2.64
	inner_ring.mesh = inner_mesh
	inner_ring.position = Vector3(0.0, 1.31, 91.5)
	inner_ring.material_override = inner_glow
	add_child(inner_ring)
	for side: float in [-1.0, 1.0]:
		_box("InteractionIslandGoldEdge", Vector3(0.16, 0.22, 9.0), Vector3(side * 4.05, 1.20, 91.5), GOLD)
	_label("GLOWING INTERACTION CIRCLE - DIRECTLY BEFORE SHIP GATE", Vector3(0.0, 3.3, 86.5), GOLD, 19)
	_label("PLAYER ENTERS CIRCLE  >  INTERACT  >  CONFIRM SHIP ENTRY", Vector3(0.0, 2.8, 96.5), IVORY, 15)
	_label("VEHICLE BYPASS LANES - KEEP PAD CLEAR", Vector3(0.0, 3.0, 99.0), GOLD, 15)

func _build_option_b_southern_roads() -> void:
	# Option B review geometry only: side arms remain in place; detours extend to the relocated bypass.
	for side: float in [-1.0, 1.0]:
		var x: float = side * 55.5
		_box("PreservedSouthRoadArm", Vector3(79.0, 0.08, 6.0), Vector3(x, 0.22, 95.0), ROAD)
		var detour_x: float = side * 16.0
		_box("ExtendedSouthSideDetour", Vector3(6.0, 0.08, 25.0), Vector3(detour_x, 0.24, 107.5), ROAD)
	_box("RelocatedSouthBasinBypass", Vector3(32.0, 0.08, 6.0), Vector3(0.0, 0.26, 120.0), ROAD)
	_box("OptionB_LandAccessSpur", Vector3(8.5, 0.08, 7.0), Vector3(0.0, 0.28, 114.5), ROAD)
	_label("OPTION B - PRESERVED SOUTH ROAD ARMS", Vector3(-58.0, 2.0, 91.0), GOLD, 16)
	_label("RELOCATED SOUTH BYPASS - Z=120", Vector3(0.0, 2.0, 125.0), GOLD, 18)


func _tutankhamun_mask_mesh() -> ArrayMesh:
	# Custom tapered face silhouette: broad brow/cheeks, narrowing jaw and rounded chin.
	# Local +Z faces the bridge camera.
	var rings := [
		Vector3(0.00, -2.20, 0.12),
		Vector3(0.78, -1.88, 0.72),
		Vector3(1.42, -1.28, 0.92),
		Vector3(1.82, -0.42, 1.02),
		Vector3(1.92, 0.48, 1.00),
		Vector3(1.78, 1.28, 0.88),
		Vector3(1.48, 1.92, 0.62),
		Vector3(0.82, 2.20, 0.22)
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 40
	for ring_index in range(rings.size() - 1):
		var lower: Vector3 = rings[ring_index]
		var upper: Vector3 = rings[ring_index + 1]
		for segment in range(segments):
			var a0 := TAU * float(segment) / float(segments)
			var a1 := TAU * float(segment + 1) / float(segments)
			var p00 := Vector3(cos(a0) * lower.x, lower.y, sin(a0) * lower.z)
			var p01 := Vector3(cos(a1) * lower.x, lower.y, sin(a1) * lower.z)
			var p10 := Vector3(cos(a0) * upper.x, upper.y, sin(a0) * upper.z)
			var p11 := Vector3(cos(a1) * upper.x, upper.y, sin(a1) * upper.z)
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)
	st.generate_normals()
	return st.commit()

func _royal_ship_hull_mesh() -> ArrayMesh:
	# Front elevation silhouette: a gently raised bow/stern and a deeper rounded keel.
	# The mesh is extruded across the ship depth, avoiding the plain rectangular hull block.
	var outline := PackedVector2Array([
		Vector2(-33.0, -0.55), Vector2(-31.0, -1.55), Vector2(-27.0, -2.18),
		Vector2(-19.0, -2.55), Vector2(0.0, -2.72), Vector2(19.0, -2.55),
		Vector2(27.0, -2.18), Vector2(31.0, -1.55), Vector2(33.0, -0.55),
		Vector2(33.0, 1.45), Vector2(29.0, 2.05), Vector2(20.0, 2.35),
		Vector2(-20.0, 2.35), Vector2(-29.0, 2.05), Vector2(-33.0, 1.45)
	])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, 0.0, 15.0)
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		st.add_vertex(center)
		st.add_vertex(Vector3(a.x, a.y, 15.0))
		st.add_vertex(Vector3(b.x, b.y, 15.0))
		st.add_vertex(Vector3(0.0, 0.0, -15.0))
		st.add_vertex(Vector3(b.x, b.y, -15.0))
		st.add_vertex(Vector3(a.x, a.y, -15.0))
		var front_a := Vector3(a.x, a.y, 15.0)
		var front_b := Vector3(b.x, b.y, 15.0)
		var back_a := Vector3(a.x, a.y, -15.0)
		var back_b := Vector3(b.x, b.y, -15.0)
		st.add_vertex(front_a)
		st.add_vertex(back_a)
		st.add_vertex(back_b)
		st.add_vertex(front_a)
		st.add_vertex(back_b)
		st.add_vertex(front_b)
	st.generate_normals()
	return st.commit()

func _ship_deck_ribbon_mesh(width: float, depth: float, thickness: float) -> ArrayMesh:
	# Curved cruise-ship deck fascia: the middle stays high and the bow/stern wings sweep down.
	var top := PackedVector3Array()
	var bottom := PackedVector3Array()
	var segments := 32
	for i in range(segments + 1):
		var t := -1.0 + 2.0 * float(i) / float(segments)
		var x := t * width * 0.5
		var sweep := pow(abs(t), 2.15)
		var y := 0.28 - 1.65 * sweep
		top.append(Vector3(x, y, depth * 0.5 * (1.0 - 0.10 * sweep)))
		bottom.append(Vector3(x, y - thickness, depth * 0.5 * (1.0 - 0.10 * sweep)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a := top[i]
		var b := top[i + 1]
		var c := bottom[i + 1]
		var d := bottom[i]
		# Top surface and front fascia.
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(Vector3(b.x, b.y, -b.z))
		st.add_vertex(a)
		st.add_vertex(Vector3(b.x, b.y, -b.z))
		st.add_vertex(Vector3(a.x, a.y, -a.z))
		st.add_vertex(a)
		st.add_vertex(d)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
		# Bottom surface and rear fascia.
		st.add_vertex(Vector3(a.x, d.y, -d.z))
		st.add_vertex(Vector3(b.x, c.y, -c.z))
		st.add_vertex(Vector3(b.x, c.y, c.z))
		st.add_vertex(Vector3(a.x, d.y, -d.z))
		st.add_vertex(Vector3(b.x, c.y, c.z))
		st.add_vertex(Vector3(a.x, d.y, d.z))
		st.add_vertex(d)
		st.add_vertex(Vector3(a.x, d.y, -d.z))
		st.add_vertex(Vector3(b.x, c.y, -c.z))
		st.add_vertex(d)
		st.add_vertex(Vector3(b.x, c.y, -c.z))
		st.add_vertex(c)
	st.generate_normals()
	return st.commit()

func _ship_deck_ribbon(label: String, width: float, depth: float, thickness: float, position: Vector3, color: Color) -> Node3D:
	# Build a smooth-looking curved fascia from narrow overlapping segments.
	# This avoids the oversized planar faces and inconsistent normals of the first ribbon mesh.
	var root := Node3D.new()
	root.name = label
	root.position = position
	root.add_to_group("royal_ship_visuals")
	add_child(root)
	var segments := 40
	var segment_width := width / float(segments)
	for i in range(segments):
		var t := -1.0 + 2.0 * (float(i) + 0.5) / float(segments)
		var sweep := pow(abs(t), 2.0)
		var x := t * width * 0.5
		var y := 0.42 - 3.55 * pow(abs(t), 1.65)
		var segment_depth := depth * (1.0 - 0.42 * sweep)
		var segment := _box(label + "_Segment_%02d" % i, Vector3(segment_width + 0.07, thickness, segment_depth), Vector3(x, y, 0.0), color, root)
		segment.rotation_degrees.z = -sign(t) * 16.0 * pow(abs(t), 1.2)
		segment.material_override = _material(color, 0.78)
		# Deep-blue fascia below each deck gives the tier real visual mass.
		var fascia := _box(label + "_LowerFascia_%02d" % i, Vector3(segment_width + 0.08, thickness * 0.92, segment_depth * 0.98), Vector3(x, y - thickness * 0.88, 0.0), Color(0.012, 0.045, 0.09), root)
		fascia.material_override = _material(Color(0.012, 0.045, 0.09), 0.72)
	return root

func _build_five_civilizations_ship_blockout() -> void:
	# Reference-matched stationary royal vessel. The uploaded image is the visual authority:
	# very wide dark-blue cruise-ship silhouette, gold Egyptian ornament, stepped side
	# superstructure, and a monumental central pharaonic entrance facing the bridge.
	var hull := Color(0.025, 0.075, 0.14)
	var blue := Color(0.025, 0.12, 0.23)
	var blue_light := Color(0.055, 0.22, 0.34)
	var gold := GOLD
	var ivory := Color(0.91, 0.86, 0.72)
	var dark := Color(0.035, 0.045, 0.065)

	# Broad ship body: long axis across the image, with the entrance facing +Z.
	var sculpted_hull := MeshInstance3D.new()
	sculpted_hull.name = "FiveCivilizationsShip_MainHull_SculptedSilhouette"
	sculpted_hull.mesh = _royal_ship_hull_mesh()
	sculpted_hull.position = Vector3(0.0, -0.15, 82.5)
	sculpted_hull.material_override = _material(hull, 0.48)
	sculpted_hull.add_to_group("royal_ship_visuals")
	add_child(sculpted_hull)
	_box("FiveCivilizationsShip_Hull_GoldWaterline", Vector3(66.4, 0.22, 29.0), Vector3(0.0, -2.25, 82.5), gold)
	_box("FiveCivilizationsShip_Hull_BlueUpperBand", Vector3(65.5, 1.25, 28.5), Vector3(0.0, 2.25, 82.5), blue)

	# Stepped outer superstructure ribbons reproduce the layered cruise-ship profile.
	# These are visual fascia/overhangs, not extra walkable floors or stair access.
	for tier in range(4):
		var width := 62.0 - float(tier) * 4.6
		var depth := 26.0 - float(tier) * 1.8
		var y := 3.05 + float(tier) * 1.55
		var z := 82.5 - float(tier) * 0.25
		_ship_deck_ribbon("ShipSuperstructure_Tier_%02d_CurvedDarkBlue" % tier, width, depth, 1.12, Vector3(0.0, y, z), blue if tier % 2 == 0 else blue_light)
		_ship_deck_ribbon("ShipSuperstructure_Tier_%02d_CurvedGoldEdge" % tier, width + 0.20, depth + 0.12, 0.085, Vector3(0.0, y + 0.58, z), gold)
		for side: float in [-1.0, 1.0]:
			_box("ShipSuperstructure_Tier_%02d_SideBalcony" % tier, Vector3(0.22, 0.22, depth - 1.6), Vector3(side * (width * 0.5 - 0.12), y + 0.46, z), blue_light)

	# Monumental central Egyptian gate, intentionally dominant over the side decks.
	_box("ShipRoyalGate_Backdrop", Vector3(13.5, 10.5, 2.2), Vector3(0.0, 7.4, 94.0), dark)
	_box("ShipRoyalGate_GoldFrame_Left", Vector3(1.15, 10.0, 1.0), Vector3(-6.2, 7.2, 95.0), gold)
	_box("ShipRoyalGate_GoldFrame_Right", Vector3(1.15, 10.0, 1.0), Vector3(6.2, 7.2, 95.0), gold)
	_box("ShipRoyalGate_TopBeam", Vector3(13.5, 1.0, 1.2), Vector3(0.0, 12.0, 95.0), gold)
	_box("ShipRoyalGate_InnerBluePortal", Vector3(8.8, 7.4, 0.28), Vector3(0.0, 6.3, 96.0), blue_light)
	var gate_door := _box("ShipRoyalGate_IlluminatedDoorway", Vector3(5.8, 5.8, 0.18), Vector3(0.0, 5.4, 96.2), Color(0.035, 0.18, 0.29))
	gate_door.material_override = _emissive_material(Color(0.08, 0.32, 0.46), 0.85)
	_box("ShipRoyalGate_NamePlate", Vector3(9.6, 1.2, 0.35), Vector3(0.0, 10.0, 96.1), dark)
	_label("KING OF EGYPT CITY", Vector3(0.0, 10.05, 96.35), gold, 28)

	# Tall flanking pylons and guardian-statue silhouettes.
	for side: float in [-1.0, 1.0]:
		var x := side * 8.0
		_box("ShipGate_GuardPylon_%s" % str(side), Vector3(2.2, 9.2, 1.8), Vector3(x, 6.8, 94.6), blue)
		_box("ShipGate_GuardPylon_GoldTrim", Vector3(2.35, 0.28, 1.95), Vector3(x, 11.45, 94.6), gold)
		_box("ShipGate_GuardStatue_Body", Vector3(0.95, 3.7, 0.72), Vector3(x, 5.9, 95.8), gold)
		_box("ShipGate_GuardStatue_Head", Vector3(1.05, 1.15, 0.82), Vector3(x, 8.35, 95.8), ivory)
		_box("ShipGate_GuardStatue_Headdress", Vector3(1.45, 1.2, 0.92), Vector3(x, 9.15, 95.8), gold)

	# Monumental pharaoh mask: sculptural face, nemes side lobes, brows, eyes and ceremonial beard.
	var head := MeshInstance3D.new()
	head.name = "ShipPharaoh_MaskFace_CustomTaperedMesh"
	head.mesh = _tutankhamun_mask_mesh()
	head.position = Vector3(0.0, 15.0, 97.15)
	head.material_override = _material(gold, 0.24)
	add_child(head)
	_box("ShipPharaoh_Headdress_Back", Vector3(9.6, 7.5, 0.58), Vector3(0.0, 15.1, 96.0), blue)
	for side: float in [-1.0, 1.0]:
		var lappet := _box("ShipPharaoh_Nemes_SideLappet", Vector3(2.0, 6.6, 0.72), Vector3(side * 3.35, 13.9, 97.05), blue)
		lappet.rotation_degrees.z = side * -7.0
		for stripe in range(5):
			var stripe_y := 11.8 + float(stripe) * 0.95
			var stripe_node := _box("ShipPharaoh_Nemes_GoldStripe", Vector3(2.12, 0.16, 0.78), Vector3(side * 3.35, stripe_y, 97.18), gold)
			stripe_node.rotation_degrees.z = side * -7.0
	for stripe in range(6):
		var y := 12.6 + float(stripe) * 0.86
		_box("ShipPharaoh_Headdress_GoldStripe_%02d" % stripe, Vector3(9.0 - float(stripe) * 0.56, 0.17, 0.18), Vector3(0.0, y, 97.08), gold)
	_box("ShipPharaoh_Crown", Vector3(1.65, 1.85, 0.72), Vector3(0.0, 18.25, 97.0), gold)
	# Smooth sculpted facial forms sit just in front of the gold mask surface, facing the bridge.
	for side: float in [-1.0, 1.0]:
		_ellipsoid("ShipPharaoh_Ear", Vector3(0.28, 0.52, 0.16), Vector3(side * 2.02, 14.82, 98.28), gold)
		_ellipsoid("ShipPharaoh_Cheek", Vector3(0.62, 0.42, 0.16), Vector3(side * 1.02, 14.62, 98.34), Color(0.91, 0.72, 0.37))
		_ellipsoid("ShipPharaoh_EyeSocket", Vector3(0.47, 0.15, 0.12), Vector3(side * 0.88, 15.54, 98.37), Color(0.18, 0.10, 0.055))
		var eye := _ellipsoid("ShipPharaoh_Eye", Vector3(0.30, 0.075, 0.075), Vector3(side * 0.88, 15.55, 98.46), IVORY)
		eye.rotation_degrees.z = side * -4.0
		_ellipsoid("ShipPharaoh_EyePupil", Vector3(0.068, 0.082, 0.06), Vector3(side * 0.88, 15.55, 98.53), Color(0.045, 0.035, 0.025))
		var lower_liner := _ellipsoid("ShipPharaoh_KohlLowerLiner", Vector3(0.34, 0.035, 0.045), Vector3(side * 0.88, 15.43, 98.49), dark)
		lower_liner.rotation_degrees.z = side * -4.0
		var brow := _ellipsoid("ShipPharaoh_GoldBrow", Vector3(0.55, 0.075, 0.095), Vector3(side * 0.90, 15.88, 98.40), gold)
		brow.rotation_degrees.z = side * -5.0
	# Tapered smooth nose, defined lips and a narrower ceremonial false beard.
	_ellipsoid("ShipPharaoh_NoseBridge", Vector3(0.22, 0.62, 0.18), Vector3(0.0, 15.03, 98.43), Color(0.91, 0.72, 0.37))
	_ellipsoid("ShipPharaoh_NoseTip", Vector3(0.30, 0.20, 0.20), Vector3(0.0, 14.62, 98.51), gold)
	_ellipsoid("ShipPharaoh_MouthLine", Vector3(0.34, 0.055, 0.07), Vector3(0.0, 14.12, 98.47), Color(0.20, 0.10, 0.05))
	_ellipsoid("ShipPharaoh_LowerLip", Vector3(0.30, 0.075, 0.07), Vector3(0.0, 13.98, 98.46), Color(0.91, 0.72, 0.37))
	var beard := _cylinder("ShipPharaoh_CeremonialBeard", 0.46, 1.55, Vector3(0.0, 12.86, 98.34), _material(gold, 0.28))
	var beard_mesh := beard.mesh as CylinderMesh
	beard_mesh.top_radius = 0.22
	beard_mesh.bottom_radius = 0.40
	for rib_x in [-0.16, 0.0, 0.16]:
		_ellipsoid("ShipPharaoh_BeardRib", Vector3(0.035, 0.60, 0.035), Vector3(rib_x, 12.86, 98.61), IVORY)
	_ellipsoid("ShipPharaoh_BeardTip", Vector3(0.22, 0.24, 0.20), Vector3(0.0, 11.98, 98.36), gold)
	# Small uraeus crest above the brow completes the royal nemes silhouette.
	_box("ShipPharaoh_UraeusStem", Vector3(0.20, 0.88, 0.20), Vector3(0.0, 17.20, 97.62), gold)
	_box("ShipPharaoh_UraeusHead", Vector3(0.58, 0.52, 0.28), Vector3(0.0, 17.60, 97.78), ivory)

	# Tutankhamun's broad ceremonial collar, rendered as layered gold-and-blue arcs beneath the mask.
	for collar_layer in range(4):
		var collar_width := 5.8 - float(collar_layer) * 0.58
		var collar_y := 11.25 - float(collar_layer) * 0.34
		var collar_band := _box("Tutankhamun_Collar_GoldBand", Vector3(collar_width, 0.28, 0.30), Vector3(0.0, collar_y, 98.05 + float(collar_layer) * 0.035), gold)
		collar_band.rotation_degrees.z = 0.0
		_box("Tutankhamun_Collar_BlueInlay", Vector3(collar_width - 0.22, 0.12, 0.12), Vector3(0.0, collar_y - 0.08, 98.23 + float(collar_layer) * 0.035), blue)
	for side: float in [-1.0, 1.0]:
		# Stylized vulture wings framing the cobra on the brow, matching the royal mask insignia.
		var wing := _box("Tutankhamun_Uraeus_VultureWing", Vector3(0.78, 0.22, 0.18), Vector3(side * 0.52, 17.42, 98.06), gold)
		wing.rotation_degrees.z = side * -18.0
		for feather_index in range(3):
			var feather := _box("Tutankhamun_Uraeus_WingFeather", Vector3(0.42, 0.10, 0.12), Vector3(side * (0.70 + float(feather_index) * 0.12), 17.18 - float(feather_index) * 0.12, 98.10), ivory)
			feather.rotation_degrees.z = side * -22.0
	_box("Tutankhamun_Uraeus_CobraBody", Vector3(0.24, 0.82, 0.22), Vector3(0.0, 17.48, 98.18), gold)
	_box("Tutankhamun_Uraeus_CobraHood", Vector3(0.56, 0.42, 0.24), Vector3(0.0, 17.92, 98.18), gold)
	_box("Tutankhamun_Uraeus_CobraHead", Vector3(0.32, 0.32, 0.24), Vector3(0.0, 18.20, 98.20), ivory)

	# Oversized winged-sun emblems on the forward blue fascia, readable from the bridge.
	for side: float in [-1.0, 1.0]:
		var emblem_x := side * 21.0
		var sun := _cylinder("ShipFront_WingedSun_Disc", 0.88, 0.20, Vector3(emblem_x, 0.95, 95.78), _material(gold, 0.28))
		sun.rotation_degrees.x = 90.0
		_box("ShipFront_WingedSun_CentralBody", Vector3(1.15, 1.45, 0.22), Vector3(emblem_x, 0.9, 95.82), gold)
		for feather_index in range(9):
			var feather_x := emblem_x + side * (1.15 + float(feather_index) * 0.88)
			var feather_y := 0.38 + float(feather_index) * 0.17
			var feather := _box("ShipFront_WingedSun_Feather", Vector3(1.18, 0.20, 0.18), Vector3(feather_x, feather_y, 95.84), gold)
			feather.rotation_degrees.z = side * -float(feather_index + 1) * 3.2
		var lower_wing := _box("ShipFront_WingedSun_LowerFeather", Vector3(8.5, 0.18, 0.16), Vector3(emblem_x + side * 4.0, 0.08, 95.82), gold)
		lower_wing.rotation_degrees.z = side * 7.0
		_box("ShipHull_GoldSheerLine", Vector3(0.12, 0.16, 22.0), Vector3(side * 33.0, -1.0, 82.5), gold)

	# Broad front-facing promenade fascia: visible from the bridge approach like the reference image.
	_box("ShipFront_PromenadeFascia", Vector3(58.0, 2.1, 0.72), Vector3(0.0, 1.55, 95.15), blue)
	_box("ShipFront_PromenadeGoldRail", Vector3(58.5, 0.14, 0.88), Vector3(0.0, 2.72, 95.15), gold)
	_box("ShipFront_PromenadeLowerGoldLine", Vector3(58.2, 0.12, 0.82), Vector3(0.0, 0.45, 95.15), gold)
	for window_index in range(18):
		var window_x := -27.0 + float(window_index) * 3.18
		if absf(window_x) > 8.0:
			var window_node := _box("ShipFront_IlluminatedCabinWindow_%02d" % window_index, Vector3(1.25, 0.78, 0.12), Vector3(window_x, 1.65, 95.58), Color(0.22, 0.62, 0.82))
			window_node.material_override = _emissive_material(Color(0.22, 0.62, 0.82), 0.55)
	for side: float in [-1.0, 1.0]:
		for post_index in range(12):
			var post_x := side * (10.0 + float(post_index) * 1.85)
			_box("ShipFront_PromenadeRailPost", Vector3(0.12, 0.72, 0.12), Vector3(post_x, 2.35, 95.72), gold)
	# Illuminated cabin rows and fine balcony rails make the stepped cruise-ship decks readable from the bridge.
	for tier in range(4):
		var deck_y := 3.65 + float(tier) * 1.55
		var deck_width := 58.0 - float(tier) * 4.6
		for side: float in [-1.0, 1.0]:
			var rail := _box("ShipDeck_FrontGoldBalconyRail", Vector3(deck_width * 0.5 - 7.0, 0.12, 0.16), Vector3(side * (deck_width * 0.25 + 3.5), deck_y + 0.72, 95.68 - float(tier) * 0.35), gold)
			for window_index in range(7):
				var window_x := side * (9.0 + float(window_index) * 2.75)
				var window := _box("ShipDeck_IlluminatedCabinWindow", Vector3(1.35, 0.76, 0.14), Vector3(window_x, deck_y + 0.12, 95.48 - float(tier) * 0.35), Color(0.24, 0.62, 0.82))
				window.material_override = _emissive_material(Color(0.24, 0.62, 0.82), 0.42)
				_box("ShipDeck_WindowGoldFrame_Top", Vector3(1.48, 0.10, 0.18), Vector3(window_x, deck_y + 0.56, 95.58 - float(tier) * 0.35), gold)
				_box("ShipDeck_WindowGoldFrame_Bottom", Vector3(1.48, 0.10, 0.18), Vector3(window_x, deck_y - 0.32, 95.58 - float(tier) * 0.35), gold)
			for post_index in range(9):
				var post_x := side * (9.0 + float(post_index) * 3.25)
				_box("ShipDeck_BalconyPost", Vector3(0.10, 0.55, 0.10), Vector3(post_x, deck_y + 0.43, 95.82 - float(tier) * 0.35), gold)

	# Broad bow/stern caps keep the vessel silhouette expansive and symmetrical.
	_box("ShipBow_RoyalBlueCap", Vector3(52.0, 0.65, 2.0), Vector3(0.0, 3.0, 69.8), blue_light)
	_box("ShipStern_RoyalBlueCap", Vector3(34.0, 0.65, 2.0), Vector3(0.0, 3.0, 95.0), blue_light)
	_label("FIVE CIVILIZATIONS SHIP - REFERENCE SILHOUETTE BLOCKOUT", Vector3(0.0, 20.5, 82.0), GOLD, 22)


func _scale_royal_ship_visuals(factor: float) -> void:
	# Enlarge the complete vessel while keeping the gate aligned with the bridge approach.
	# Pivot is near the gate face so the glowing interaction circle and bridge remain untouched.
	var pivot := Vector3(0.0, 7.4, 95.5)
	for node in get_tree().get_nodes_in_group("royal_ship_visuals"):
		if node is Node3D:
			var visual := node as Node3D
			visual.position = pivot + (visual.position - pivot) * factor
			visual.scale *= factor

func _build_ship_detail_pass() -> void:
	# Gold trim, portholes and lighting reinforce the uploaded royal blue/gold reference.
	var gold := GOLD
	var blue := Color(0.035, 0.13, 0.23)
	for side: float in [-1.0, 1.0]:
		for z: float in [72.0, 76.0, 80.0, 84.0, 88.0, 92.0]:
			var porthole := _cylinder("ShipHull_IlluminatedPorthole", 0.28, 0.12, Vector3(side * 33.15, 0.1, z), _emissive_material(Color(0.28, 0.72, 0.96), 1.1))
			porthole.rotation_degrees.z = 90.0
		for tier in range(4):
			var y := 3.55 + float(tier) * 1.55
			_box("ShipTier_RoyalGoldFrontTrim", Vector3(24.0, 0.12, 0.18), Vector3(side * 16.0, y, 95.0), gold)
	# Five small insignia plates identify the five-civilization theme without inventing their names.
	for i in range(5):
		var x := -4.0 + float(i) * 2.0
		_box("FiveCivilizations_EmblemPlate_%02d" % i, Vector3(1.1, 1.35, 0.22), Vector3(x, 2.9, 95.5), gold)
		_box("FiveCivilizations_EmblemInset_%02d" % i, Vector3(0.72, 0.88, 0.08), Vector3(x, 2.95, 95.34), blue)
	# Glowing gold portal arch and a soft blue central doorway.
	var portal_glow := _emissive_material(Color(1.0, 0.62, 0.12), 2.8)
	for side: float in [-1.0, 1.0]:
		var portal_side := _box("ShipGate_IlluminatedVertical", Vector3(0.20, 6.4, 0.16), Vector3(side * 3.25, 5.5, 96.55), Color(1.0, 0.62, 0.12))
		portal_side.material_override = portal_glow
	var portal_header := _box("ShipGate_IlluminatedHeader", Vector3(6.6, 0.20, 0.16), Vector3(0.0, 8.7, 96.55), Color(1.0, 0.62, 0.12))
	portal_header.material_override = portal_glow
	# The ship remains moored and static; no walkable upper decks, extra floors or stairs are introduced.
func _mark_preserved_ship_and_conflicts() -> void:
	# The vessel above is a review blockout only; it does not replace a final approved ship asset.
	_label("SHIP BLOCKOUT - FINAL ASSET STILL REQUIRED", Vector3(12.0, 3.0, 82.0), GOLD, 18)
	_label("OPTION B ROUTE - REVIEW BLOCKOUT ONLY", Vector3(45.0, 3.0, 94.0), Color(1.0, 0.72, 0.66), 18)
	_label("SCHEMATIC BLOCKOUT - NOT GAMEPLAY COLLISION", Vector3(0.0, 5.0, 151.0), GOLD, 32)
