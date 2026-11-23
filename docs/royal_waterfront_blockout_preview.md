# Royal Waterfront Blockout Preview

**Status:** Isolated review scene only. Not merged into the production scene and not gameplay-ready.

## Files
- `scenes/royal_waterfront_blockout_preview.tscn`
- `scripts/royal_waterfront_blockout_preview.gd`

Open the scene directly in Godot 4.7+ to inspect the schematic blockout. It is deliberately separate from `scenes/main.tscn`; the production scene and approved layout scripts are not modified.

## What the blockout shows
- A continuous open-water area replacing the old promenade/enclosed-marina concept.
- A visual shallow-water transition band and a continuous sandy beach extended around the existing handball area.
- The handball court integrated into the beach as a marked play zone on the same sand surface, with no separate raised pad; its current center and reserved footprint are retained.
- A royal bridge concept with an 8.5m two-way carriageway, 2.25m protected pedestrian paths on each side, barriers, and an arrival platform.
- The current ship and pier location shown as reference outlines only; the approved ship asset is not recreated or moved.
- The existing southern road at approximately Z=95 marked as a conflict requiring a later route redesign.

## Important dimensions and unresolved checks
- Bridge deck concept width: 13m overall (8.5m roadway + 2.25m walkway per side).
- Bridge length in this blockout: 17m, provisional only.
- Shoreline and beach extents are schematic, not surveyed or approved final coordinates.
- The beach court is a schematic 42m × 36m reserved area with low-profile boundary lines; sports clearances and equipment are not finalized.
- No boat clearance is assumed below the bridge.
- The visual shallow-water band is not walkable gameplay geometry.
- No collision, vehicle handling, water-depth logic, server-side boundary protection, or Android performance validation is included.

## Not changed
- `scenes/main.tscn`
- `scripts/main.gd`
- `scripts/approved_city_layout.gd`
- Existing building positions, ship position, road geometry, and production collision.
- No merge or production deployment was performed.

## Required before production implementation
1. Review the coastline, integrated beach-court footprint and run-off, marina terminal/yacht club, and road connections against the full live scene.
2. Adjust bridge dimensions against actual player and vehicle dimensions.
3. Build real walkable shallow-water collision and clear deep-water boundaries.
4. Replace the reference ship outline with the existing approved ship asset in a dedicated test scene.
5. Capture a rendered screenshot from the same final Godot scene after Godot validation.
6. Obtain explicit approval before merging any production changes.
