# Royal Ship Entrance Blockout — Progress Record

**Branch:** `feature/royal-waterfront-blockout-preview`  
**Status:** Geometry added to the standalone Godot preview script; not yet rendered or runtime-validated.

## Geometry added
- The 13 m bridge remains the preliminary two-way bridge width: 8.5 m roadway plus 2.25 m protected pedestrian walkways on both sides.
- Added a visual detail pass with a double center marking and repeated royal lamp-post silhouettes.
- Added a flared terminal apron at the ship-facing end of the bridge.
- Added two vehicle bypass lanes on either side of a central pedestrian island, so the interaction pad is not placed in the live vehicle lanes.
- Added a circular interaction pad with two emissive concentric torus rings, positioned at the ship-facing bridge terminal in front of the ship footprint marker.
- Added labels explaining the player flow: enter the circle, interact, confirm ship entry.

## Important limits
- This remains a schematic blockout using primitive meshes and placeholder ship footprint markers.
- The exact main-gate location on the final Five Civilizations Ship mesh is not yet available in this preview, so the pad's placement is a provisional alignment to the current ship footprint reference.
- The two vehicle bypass lanes and terminal apron are visual geometry only; no turning-radius, vehicle physics, pedestrian collision, interaction trigger, or network-authoritative entry logic has been implemented or tested.
- The preview scene has not been launched in Godot and no genuine rendered screenshot has been captured.
- No production scenes or approved ship assets were changed. Nothing was merged into `main`.

## Required next validation
1. Open the standalone preview in Godot 4.7.2 and resolve any script/import errors.
2. Capture a render from this exact scene for review.
3. Compare the terminal pad and apron against the actual ship entrance mesh and adjust only after that inspection.
4. Add real collision and vehicle turning geometry, then test player and vehicle movement.
5. Implement the interaction prompt and confirmation using the previously approved ship-entry flow only after the geometry is approved.
