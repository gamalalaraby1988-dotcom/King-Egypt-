# Royal Waterfront Blockout — Static Geometry Audit

**Scope:** Coordinate/footprint review of the isolated blockout only. This is not a Godot runtime test, rendered inspection, collision test, or approval of final shoreline coordinates.

## Findings from the current blockout

Coordinates below are axis-aligned footprint ranges derived from the dimensions and positions in `scripts/royal_waterfront_blockout_preview.gd`.

| Element | X range (m) | Z range (m) |
|---|---:|---:|
| Main open sea | -95 to 95 | 65 to 107 |
| Visual shallow band | -90 to 90 | 105.5 to 110.5 |
| Shoreline transition band | -90 to 90 | 104 to 107 |
| Sandy beach strip | -90 to 90 | 107 to 117 |
| Existing handball footprint | 19 to 61 | 107 to 143 |
| Bridge deck | -15.5 to -2.5 | 91 to 108 |
| Land-ramp transition | -15.5 to -2.5 | 108 to 113 |
| Arrival platform | -15.5 to -2.5 | 80.5 to 90.5 |
| Ship reference outline | -2.9 to 2.9 | 75.5 to 94.5 |
| Pier reference outline | -10 to -2 | 77 to 91 |
| Existing south-road conflict marker | -95 to 95 | 94.5 to 95.5 |

## Confirmed footprint intersections

1. **Beach and handball footprint:** overlap is 42m wide × 10m deep (X=19..61, Z=107..117). Both are dry/sandy surfaces in the schematic, but the beach currently runs through the court footprint rather than clearly terminating beside it. Keep the court dry and make the court/beach boundary explicit in the next geometry revision.
2. **Shallow band and open sea:** overlap is 1.5m in Z (105.5..107). This can serve as a visual blend, but the layers currently have different elevations and are not a single continuous walkable surface.
3. **Shallow band and beach:** overlap is 3.5m in Z (107..110.5). The beach top is above the shallow-water surface, so the beach visually covers part of the shallow band.
4. **Bridge and land ramp:** their Z ranges meet at Z=108 with no positive-area overlap. A shared edge alone does not guarantee a smooth vehicle/player transition; inspect the final mesh elevations and ramp slope in Godot.
5. **Bridge and existing south-road marker:** the marker crosses the bridge footprint at Z≈95. This records the known road conflict; no live road has been rerouted.
6. **Arrival platform and pier reference:** the footprints overlap by 7.5m in X and 10m in Z. This may be intentional as a connection, but the actual pier/ship geometry and walkable path must be checked before implementation.
7. **Arrival platform and ship outline:** the rectangular footprints overlap by only 0.4m in X (−2.9..−2.5). Do not infer that this provides a usable ship connection; use the actual approved ship scene and inspect its access geometry.

## Recommended next revision

- Resolve the court/beach edge deliberately without moving the approved court location.
- Rebuild the sea → transition → shallow → beach sequence as adjacent, non-overlapping surfaces or explicitly designed blend meshes, with a single walkable collision surface only where intended.
- Confirm bridge-to-ramp height continuity and vehicle clearance using the real scene scale.
- Replace the ship and pier reference rectangles with instances of the approved assets in a dedicated test scene, without moving the production ship.
- Re-route the southern road only after presenting the proposed route and obtaining approval.
- Add gameplay collision, water-depth boundaries, vehicle/player tests, and server-authoritative out-of-bounds protection in later implementation stages.

## Validation status

- Static footprint arithmetic: completed from source dimensions.
- Godot editor/runtime validation: not performed; Godot is not available in the current execution environment.
- Rendered screenshot from the actual scene: not captured.
- Production files, approved layout, existing roads, buildings, and ship: not changed.
- No merge or deployment performed.
