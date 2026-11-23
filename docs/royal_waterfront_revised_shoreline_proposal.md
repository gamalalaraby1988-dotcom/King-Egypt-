# Royal Waterfront — Revised Shoreline and Ship-Access Engineering Proposal

**Status:** New coordinate proposal for user review only. It is not an implementation, final survey, Godot scene, collision mesh, or rendered preview. It applies to the isolated review branch only.

## Design intent

Resolve the previously measured hidden-ground overlaps by replacing the single broad water/beach overlays with mutually exclusive surface zones and matching terrain/collision ownership. Preserve the fixed ship, the approved Option B bridge alignment, the handball court, beach gym, marina terminal, yacht club, and existing approved buildings.

All dimensions are metres in the existing world X/Z plan. Heights are world Y. These are proposed design coordinates, not surveyed shoreline coordinates.

## 1. Proposed shore cross-section

Use one continuous north-to-south sequence:

| Zone | X range | Z range | Plan size | Surface / movement |
|---|---:|---:|---:|---|
| Deep open sea | -95..95 | 65..102 | 190 × 37 | Water visual; no walkable ground collider beneath; deep-water boundary/recovery |
| Shallow-water shelf | -90..90 | 102..107 | 180 × 5 | Dedicated underwater floor/collider; walking allowed only within this band |
| Sandy beach | -90..90 | 107..153 | 180 × 46 | Separate sand mesh and matching walkable collision |
| Existing inland city | outside beach footprint / south of Z=153 | as existing | — | Preserve existing approved ground and structures, except where a reviewed seam requires a dedicated join |

The zone boundaries meet edge-to-edge at Z=102 and Z=107. There is no positive-area overlap between deep sea, shallow shelf, and beach. Use a narrow visual waterline blend mesh only as a non-colliding material transition; do not let blend geometry create a second walkable surface.

The shallow shelf must have a deliberate depth profile and a clearly authored boundary at Z=102. The player may walk only on its dedicated floor. At the deep-water edge, block further walking and invoke the approved safe recovery/return behavior. Do not rely on hidden city ground as the shallow seabed.

## 2. Ground/collision ownership — required cutback

The previous audit found 7,404m² of deep-sea overlap, 900m² of shallow-band overlap, and 8,280m² of beach overlap with existing ground collision. The revised plan must eliminate those intersections structurally, not hide them visually.

### Proposed ownership rules

1. **Deep sea (Z=65..102):** remove/cut back all land-ground collision inside the deep-sea footprint X=-95..95. No player-walkable terrain collision may remain below deep water.
2. **Shallow shelf (Z=102..107):** replace the existing ground collision in X=-90..90 with a purpose-built shallow-floor collider whose top follows the designed underwater shelf. This is the only walkable collision in this band.
3. **Beach (Z=107..153):** replace/clip existing ground collision inside X=-90..90 with a dedicated beach collision surface matching the visible sand top. Keep the beach court apron and gym fully supported by the same beach collision surface.
4. **Outside these footprints:** preserve existing ground and approved structures. Use polygonal cutouts/mesh boundaries rather than merely shortening a box if that would create holes or affect unrelated land.
5. Rebuild the four production ground sections only after the cut polygons and all adjacent seams have been inspected. The current ground extents are reference inputs, not permission to delete or reshape them.

### Existing ground sections requiring a cut plan

| Existing node | Existing extent | Required review |
|---|---|---|
| Ground_West | X=-160..-12, Z=-340..180 | Clip collision against deep sea/shallow/beach only within the proposed shoreline footprint |
| Ground_East | X=12..160, Z=-340..180 | Same as west; preserve outer city ground |
| Ground_Center_North | X=-12..12, Z=-340..78 | Deep sea intersects only Z=65..78; remove hidden ground collision in that overlap |
| Ground_Center_South | X=-12..12, Z=102..180 | Replace Z=102..153 with shallow/beach-owned surfaces; preserve inland ground south of Z=153 |

The center north/south ground gap and existing basin are not a substitute for a continuous sea floor. The proposed sea floor, shallow shelf, and beach must be separate authored geometry with explicit ownership.

## 3. Preserve the approved beach facilities

- Keep the handball sand apron at X=19..61, Z=107..143. Its full northern edge begins at the proposed beach line Z=107, so it remains entirely on beach land.
- Keep the open-air gym at X=-61..-35, Z=124..140.
- Keep the 2.4m beach path and its connectors within the sandy beach.
- Keep the marina terminal near (75, 38) and yacht club near (75, 58); they remain outside the proposed sea's Z extent and are not moved.
- Preserve all approved buildings and the fixed Five Civilizations Ship. This proposal does not relocate any of them.

## 4. Bridge and landing — retain Option B in plan

Retain the user-approved Option B plan alignment for this isolated review:

| Element | Center / extent | Size |
|---|---|---|
| Royal bridge | center (0, 99.5), X=-6.5..6.5, Z=91..108 | 13 × 17 |
| Two-way vehicle carriageway | centered on X=0 | 8.5m wide |
| Protected pedestrian paths | both sides | 2.25m each |
| Arrival platform | center (0, 85.5), X=-6.5..6.5, Z=80.5..90.5 | 13 × 10 |
| Land-side transition | Z=108..113 | 13 × 5, to be replaced by a real sloped mesh |
| South access spur | center (0,114.5), Z=111..118 | 8.5 × 7 |
| South bypass | center (0,120), Z=117..123 | 32 × 6 |
| West/east detours | X=-19..-13 and 13..19, Z=95..120 | 6 × 25 each |

### Vertical continuity corrections

Do not retain the current flat-box transitions as final geometry. The current audit recorded:
- Bridge road top about Y=0.84 versus land-ramp top about Y=0.45.
- A 0.5m plan gap between arrival platform end Z=90.5 and bridge start Z=91.
- No verified vehicle grade or turning-radius continuity.

The revised mesh must make the bridge, platform, ramp, and approach continuous with shared edge vertices, explicit slopes, pedestrian barriers, and vehicle clearance. Close the 0.5m plan gap by extending/reshaping the transition mesh, not by leaving a visual seam. Check the Option B spur and bypass junction with vehicle swept paths before approval.

## 5. Fixed ship boarding connection

The production ship remains fixed at (0,0,85). Do not move, resize, or replace it as part of this proposal.

Known source heights:
- Pier top: approximately Y=0.16.
- Arrival platform top: approximately Y=0.825.
- Ship main deck top: approximately Y=2.26.
- Platform-to-deck rise: approximately 1.435m.
- Pier-to-deck rise: approximately 2.10m.

### Proposed boarding concept for review

Create a dedicated, non-vehicle pedestrian gangway from the arrival platform/pier to a verified side-deck landing on the existing ship:
- Clear walking width: target 2.4m.
- Handrails on both sides, toe-kick/edge protection, non-slip deck.
- Use a sloped ramp where the verified available run permits; for a 1.435m rise, a 14.35m horizontal run corresponds to a 10% grade. If that run cannot fit beside the fixed hull and pier, use a compact switchback with a level intermediate landing rather than an excessively steep short ramp.
- Provide a continuous collider and flush transitions at platform, landing, and ship deck.
- Add a small level landing at the ship entry; do not connect to an arbitrary point on the hull.
- Keep the ship fixed and place the gangway geometry around it only after inspecting the actual ship mesh and confirming its deck edge/entry point.

This is deliberately a **concept**, not a committed footprint: the existing source uses primitive ship meshes and does not yet identify a verified door/boarding edge. Therefore no exact gangway centerline or final ramp length is approved by this document. A side elevation and plan placement must be derived from the actual ship scene before construction.

## 6. Required geometry and collision checks before implementation

- Generate non-overlapping shoreline polygons and verify their areas/intersections numerically.
- Confirm every point inside the deep-sea polygon is free of land-ground collision.
- Confirm shallow-floor collision exists only within the approved shallow zone and ends at the depth boundary.
- Confirm beach collision top matches the rendered sand surface and supports the complete court, gym, and paths.
- Inspect all seams at X=-12 and X=12 where existing center and side ground sections meet.
- Check beach court run-off and gym access remain intact.
- Verify bridge/platform/ramp seams, slope, vehicle clearance, protected pedestrian paths, and Option B road junctions.
- Inspect the actual ship and pier meshes; verify the gangway landing point and deck elevation.
- Test player walking, shallow-water entry/exit, deep-water boundary/recovery, vehicle approach, and server-authoritative out-of-bounds protection in Godot.

## 7. Review decisions requested

Please review these four items before any production edits:
1. Shoreline line at Z=107, with a 5m shallow shelf from Z=102 to 107.
2. Ground ownership/cutback strategy: deep sea has no land collider; shallow shelf and beach receive their own matching collision surfaces.
3. Retain Option B bridge/road coordinates while rebuilding the vertical transitions as real sloped meshes.
4. Use a pedestrian gangway to the fixed ship, with final placement deferred until the actual ship deck edge is inspected.

## Validation and change boundary

- This is a coordinate proposal and engineering review document only.
- No production ground, collision, road, ship, pier, or building files are changed.
- No final GLB/GLTF assets are created or merged.
- Godot has not been run; no physics or player/vehicle tests are claimed.
- No rendered screenshot from the actual Godot scene is available.
- No PR, merge, or deployment is performed.
