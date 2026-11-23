# Royal Waterfront Blockout — Static Geometry Audit

**Scope:** Coordinate/footprint review of the isolated blockout only. This is not a Godot runtime test, rendered inspection, collision test, or approval of final shoreline coordinates.

## Current reviewed footprints

Coordinates are axis-aligned ranges derived from the dimensions and positions in the blockout script.

| Element | X range (m) | Z range (m) |
|---|---:|---:|
| Main open sea | -95 to 95 | 65 to 107 |
| Visual shallow band | -90 to 90 | 105.5 to 110.5 |
| Shoreline transition band | -90 to 90 | 104 to 107 |
| Continuous sandy beach (including court and gym) | -90 to 90 | 107 to 153 |
| Integrated beach handball court area | 19 to 61 | 107 to 143 |
| Open-air beach gym surface | -61 to -35 | 124 to 140 |
| Beach gym pergola posts/beams | within gym footprint | within gym footprint |
| Bridge deck | -15.5 to -2.5 | 91 to 108 |
| Land-ramp transition | -15.5 to -2.5 | 108 to 113 |
| Arrival platform | -15.5 to -2.5 | 80.5 to 90.5 |
| Ship reference outline | -2.9 to 2.9 | 75.5 to 94.5 |
| Pier reference outline | -10 to -2 | 77 to 91 |
| Existing south-road conflict marker | -95 to 95 | 94.5 to 95.5 |

## Court integration decision

The handball court is treated as a play zone embedded in the continuous beach, not as a separate raised sand pad. Its current center and 42m × 36m reserved footprint are retained in the test blockout. The beach surface is extended behind and around it; only thin, low-profile court boundary markings identify the play area.

This is a schematic layout decision, not a final sports specification. Net/goal placement, safety run-off, player clearance, and any required regulation dimensions still need review in the actual scene.

## Open-air beach gym proposal

A 26m × 16m open-air fitness area is placed at approximately X=-48m, Z=132m, on the western side of the continuous beach. This keeps it well clear of the handball court footprint (court begins at X=19m), while remaining inside the beach surface. The blockout shows a low-profile training surface, open-sided pergola, pull-up bar, parallel bars, stretching rail, and bench. It is intentionally not enclosed and is oriented as a beach-side amenity.

The gym is schematic only. Confirm accessible circulation, safe fall zones around equipment, salt-air-resistant materials, shade coverage, and the final relationship to beach paths in the full Godot scene. No equipment interaction or collision is implemented.

## Remaining geometric intersections and checks

1. **Shallow band and open sea:** overlap is 1.5m in Z (105.5..107). This can serve as a visual blend, but the layers currently have different elevations and are not a single continuous walkable surface.
2. **Shallow band and beach:** overlap is 3.5m in Z (107..110.5). This is a visual transition only; final waterline, surface elevations, and collision boundaries need to be designed together.
3. **Gym and handball court:** no overlap; their X ranges are separated by 54m, leaving ample room for a shared beach promenade/activity path if designed later.
4. **Bridge and land ramp:** their Z ranges meet at Z=108 with no positive-area overlap. A shared edge alone does not guarantee a smooth vehicle/player transition; inspect final mesh elevations and ramp slope in Godot.
5. **Bridge and existing south-road marker:** the marker crosses the bridge footprint at Z≈95. This records the known road conflict; no live road has been rerouted.
6. **Arrival platform and pier reference:** the footprints overlap by 7.5m in X and 10m in Z. This may be intentional as a connection, but the actual pier/ship geometry and walkable path must be checked before implementation.
7. **Arrival platform and ship outline:** the rectangular footprints overlap by only 0.4m in X (−2.9..−2.5). Do not infer that this provides a usable ship connection; use the actual approved ship scene and inspect its access geometry.

## Recommended next revision

- Review the beach/court proportions, court run-off, gym access and equipment clearances, and shoreline boundary in the full scene.
- Rebuild the sea → transition → shallow → beach sequence as adjacent surfaces or explicitly designed blend meshes, with a single walkable collision surface only where intended.
- Confirm bridge-to-ramp height continuity and vehicle clearance using the real scene scale.
- Replace the ship and pier reference rectangles with instances of the approved assets in a dedicated test scene, without moving the production ship.
- Re-route the southern road only after presenting the proposed route and obtaining approval.
- Add gameplay collision, water-depth boundaries, equipment interaction, vehicle/player tests, and server-authoritative out-of-bounds protection in later implementation stages.

## Validation status

- Static footprint arithmetic: updated from source dimensions.
- Godot editor/runtime validation: not performed; Godot is not available in the current execution environment.
- Rendered screenshot from the actual scene: not captured.
- Production files, approved layout, existing roads, buildings, and ship: not changed.
- No merge or deployment performed.
