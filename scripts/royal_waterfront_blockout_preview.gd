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
	_build_option_b_southern_roads()
	_mark_preserved_ship_and_conflicts()
	# Close 3/4 review angle: keep the bridge, glowing interaction pad, and ship reference footprint in one readable frame.
	$PreviewCamera.position = Vector3(27.0, 22.0, 119.0)
	$PreviewCamera.fov = 56.0
	$PreviewCamera.look_at(Vector3(0.0, 0.5, 91.0), Vector3.UP)

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


func _build_five_civilizations_ship_blockout() -> void:
	# Real Godot mesh blockout for review only; deliberately not presented as the final ship asset.
	# Keep the approved moored position and one accessible main deck (no extra floors or stairs).
	var hull_mat := _material(Color(0.72, 0.73, 0.70), 0.42)
	var ivory_mat := _material(IVORY, 0.38)
	var gold_mat := _material(GOLD, 0.32)
	var blue_mat := _material(Color(0.035, 0.12, 0.20), 0.34)
	_box("FiveCivilizationsShip_Hull_Blockout", Vector3(8.0, 2.2, 18.0), Vector3(0.0, 0.35, 85.0), hull_mat)
	_box("FiveCivilizationsShip_MainDeck_OneLevel", Vector3(9.0, 0.28, 17.0), Vector3(0.0, 1.60, 85.0), ivory_mat)
	_box("FiveCivilizationsShip_RoyalBlueDeckInset", Vector3(6.8, 0.035, 12.0), Vector3(0.0, 1.76, 83.0), blue_mat)
	# Main entrance faces the bridge-side (+Z) approach; the interaction circle remains outside it.
	for x: float in [-2.2, 2.2]:
		_box("FiveCivilizationsShip_GatePillar", Vector3(0.48, 3.2, 0.55), Vector3(x, 3.35, 93.8), gold_mat)
	_box("FiveCivilizationsShip_GateLintel", Vector3(5.0, 0.48, 0.65), Vector3(0.0, 4.85, 93.8), gold_mat)
	_box("FiveCivilizationsShip_MainHallFacade", Vector3(6.0, 3.2, 3.0), Vector3(0.0, 3.35, 88.0), ivory_mat)
	_box("FiveCivilizationsShip_MainHallRoof", Vector3(6.8, 0.42, 3.8), Vector3(0.0, 5.15, 88.0), gold_mat)
	# Five restrained civilization markers along the single deck edge.
	for i in range(5):
		var x := -3.2 + float(i) * 1.6
		_box("FiveCivilizationsShip_CivilizationPanel_%02d" % i, Vector3(0.85, 1.15, 0.18), Vector3(x, 2.45, 79.8), gold_mat)
	# Low perimeter rails clarify the vessel edge without creating another deck or floor.
	for side: float in [-1.0, 1.0]:
		_box("FiveCivilizationsShip_SideRail", Vector3(0.14, 0.7, 15.0), Vector3(side * 4.35, 2.05, 85.0), gold_mat)
	_label("FIVE CIVILIZATIONS SHIP - GEOMETRY BLOCKOUT", Vector3(0.0, 7.0, 82.0), GOLD, 24)
	_label("ONE MAIN DECK • STATIONARY • MAIN GATE TO ROYAL BRIDGE", Vector3(0.0, 6.0, 96.0), IVORY, 16)


func _mark_preserved_ship_and_conflicts() -> void:
	# The vessel above is a review blockout only; it does not replace a final approved ship asset.
	_label("SHIP BLOCKOUT - FINAL ASSET STILL REQUIRED", Vector3(12.0, 3.0, 82.0), GOLD, 18)
	_label("OPTION B ROUTE - REVIEW BLOCKOUT ONLY", Vector3(45.0, 3.0, 94.0), Color(1.0, 0.72, 0.66), 18)
	_label("SCHEMATIC BLOCKOUT - NOT GAMEPLAY COLLISION", Vector3(0.0, 5.0, 151.0), GOLD, 32)
