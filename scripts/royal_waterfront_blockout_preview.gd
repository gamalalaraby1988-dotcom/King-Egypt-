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
	_build_open_water()
	_build_bridge_and_arrival()
	_mark_preserved_ship_and_conflicts()
	$PreviewCamera.look_at(Vector3(-3.0, 0.0, 99.0), Vector3.UP)

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

func _build_open_water() -> void:
	# Water covers the former promenade and enclosed marina basin as one open body.
	_box("OpenSea_Main", Vector3(190.0, 0.22, 42.0), Vector3(0.0, -0.08, 86.0), DEEP_WATER)
	_box("WalkableShallows_VisualBand", Vector3(180.0, 0.12, 5.0), Vector3(0.0, 0.02, 108.0), SHALLOW_WATER)
	_box("ShorelineTransitionBand", Vector3(180.0, 0.10, 3.0), Vector3(0.0, 0.04, 104.0), Color(0.25, 0.56, 0.56))
	_label("OPEN SEA - FORMER PROMENADE + MARINA FOOTPRINT", Vector3(47.0, 2.0, 72.0), IVORY, 26)
	_label("SHALLOW WALKING ZONE (VISUAL ONLY)", Vector3(62.0, 1.6, 106.0), IVORY, 20)

func _build_bridge_and_arrival() -> void:
	# Overall 13m concept width: 8.5m two-way carriageway + 2.25m protected walkways each side.
	var center_x := -9.0
	_box("RoyalBridgeDeck", Vector3(13.0, 0.45, 17.0), Vector3(center_x, 0.52, 99.5), IVORY)
	_box("BridgeTwoWayRoad", Vector3(8.5, 0.08, 17.0), Vector3(center_x, 0.80, 99.5), ROAD)
	for side in [-1.0, 1.0]:
		var walkway_x := center_x + side * 5.375
		_box("ProtectedPedestrianWalkway", Vector3(2.25, 0.12, 17.0), Vector3(walkway_x, 0.86, 99.5), SAND)
		_box("BridgeSafetyBarrier", Vector3(0.18, 1.0, 17.0), Vector3(center_x + side * 6.42, 1.05, 99.5), GOLD)
		_box("BridgePedestrianSeparator", Vector3(0.14, 0.72, 17.0), Vector3(center_x + side * 4.22, 1.02, 99.5), GOLD)
	_box("ArrivalPlatform", Vector3(13.0, 0.55, 10.0), Vector3(center_x, 0.55, 85.5), SAND)
	_box("LandRampTransition", Vector3(13.0, 0.30, 5.0), Vector3(center_x, 0.30, 110.5), IVORY)
	_label("ROYAL BRIDGE - 2 WAY ROAD", Vector3(center_x, 3.0, 101.0), GOLD, 25)
	_label("PROTECTED WALKWAYS", Vector3(center_x - 8.0, 2.0, 98.0), IVORY, 19)
	_label("ARRIVAL PLATFORM", Vector3(center_x, 2.0, 87.0), GOLD, 22)

func _mark_preserved_ship_and_conflicts() -> void:
	# Outline only: the approved Five Civilizations Ship asset remains untouched.
	_box("ExistingShipFootprint_ReferenceOnly", Vector3(5.8, 0.16, 19.0), Vector3(0.0, 0.18, 85.0), GOLD)
	_box("ExistingPierReferenceOnly", Vector3(8.0, 0.18, 14.0), Vector3(-6.0, 0.30, 84.0), IVORY)
	_label("PRESERVE APPROVED SHIP POSITION", Vector3(12.0, 3.0, 82.0), GOLD, 24)
	# Red marker records the known southern road conflict; no existing road is edited here.
	_box("ExistingSouthRoadConflictMarker", Vector3(190.0, 0.12, 1.0), Vector3(0.0, 0.28, 95.0), WARNING)
	_label("EXISTING ROAD AT Z≈95 - RE-ROUTE REQUIRED BEFORE IMPLEMENTATION", Vector3(45.0, 3.0, 94.0), Color(1.0, 0.72, 0.66), 18)
	_label("SCHEMATIC BLOCKOUT - NOT GAMEPLAY COLLISION", Vector3(0.0, 5.0, 151.0), GOLD, 32)
