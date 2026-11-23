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
| Main beach activity path | -48 to 40 | 144.8 to 147.2 |
| Gym path connector | -49.2 to -46.8 | 140 to 146 |
| Court path connector | 38.8 to 41.2 | 143 to 146 |
| Beach gym pergola posts/beams | within gym footprint | within gym footprint |
| Bridge deck | -6.5 to 6.5 | 91 to 108 |
| Land-ramp transition | -6.5 to 6.5 | 108 to 113 |
| Arrival platform | -6.5 to 6.5 | 80.5 to 90.5 |
| Ship reference outline | -2.9 to 2.9 | 75.5 to 94.5 |
| Pier reference outline | -10 to -2 | 77 to 91 |
| Preserved west/east road arms | -95 to -16; 16 to 95 | 92 to 98 |
| Extended west/east detours | -19 to -13; 13 to 19 | 95 to 120 |
| Relocated south basin bypass | -16 to 16 | 117 to 123 |
| Option B land access spur | -4.25 to 4.25 | 111 to 118 |

## Court integration decision

The handball court is treated as a play zone embedded in the continuous beach, not as a separate raised sand pad. Its current center and 42m × 36m reserved footprint are retained in the test blockout. The beach surface is extended behind and around it; only thin, low-profile court boundary markings identify the play area.

This is a schematic layout decision, not a final sports specification. Net/goal placement, safety run-off, player clearance, and any required regulation dimensions still need review in the actual scene.

## Open-air beach gym proposal

A 26m × 16m open-air fitness area is placed at approximately X=-48m, Z=132m, on the western side of the continuous beach. This keeps it well clear of the handball court footprint (court begins at X=19m), while remaining inside the beach surface. The blockout shows a low-profile training surface, open-sided pergola, pull-up bar, parallel bars, stretching rail, and bench. It is intentionally not enclosed and is oriented as a beach-side amenity.

The gym is schematic only. Confirm accessible circulation, safe fall zones around equipment, salt-air-resistant materials, shade coverage, and the final relationship to beach paths in the full Godot scene. No equipment interaction or collision is implemented.

A 2.4m-wide compacted-sand path links the gym and handball court along the southern side of the beach, with short connectors meeting the gym edge at Z=140 and court edge at Z=143. The main path remains within the sandy beach boundary (ends at Z=147.2, beach ends at Z=153). This is a visual path only; grade, accessibility, and collision need runtime review.

## Remaining geometric intersections and checks

1. **Shallow band and open sea:** overlap is 1.5m in Z (105.5..107). This can serve as a visual blend, but the layers currently have different elevations and are not a single continuous walkable surface.
2. **Shallow band and beach:** overlap is 3.5m in Z (107..110.5). This is a visual transition only; final waterline, surface elevations, and collision boundaries need to be designed together.
3. **Gym and handball court:** no overlap; their X ranges are separated by 54m. The new 2.4m-wide path runs along the southern beach margin. The gym connector touches the gym's southern edge, and the court connector touches the court's southern edge; the connectors meet the main path. Check actual walkable continuity and clearances in Godot.
4. **Bridge and land ramp:** their Z ranges meet at Z=108 with no positive-area overlap. A shared edge alone does not guarantee a smooth vehicle/player transition; inspect final mesh elevations and ramp slope in Godot.
5. **Option B bridge and southern routes:** the centered bridge X range (-6.5..6.5) is separated from the existing road-arm inner edges at X=±16 by 9.5m, and from the extended detour nearest edges at X=±13 by 6.5m. The blockout now includes the preserved road arms, extended detours, relocated bypass at Z=120, and the 8.5m access spur. This is a plan-view representation only; junction turning radii, grades, and live-network compatibility remain unverified.
6. **Arrival platform and pier reference:** the footprints overlap by 7.5m in X and 10m in Z. This may be intentional as a connection, but the actual pier/ship geometry and walkable path must be checked before implementation.
7. **Arrival platform and ship outline:** the rectangular footprints overlap by only 0.4m in X (−2.9..−2.5). Do not infer that this provides a usable ship connection; use the actual approved ship scene and inspect its access geometry.

## Recommended next revision

- Review the beach/court proportions, court run-off, gym access and equipment clearances, activity-path continuity, and shoreline boundary in the full scene.
- Rebuild the sea → transition → shallow → beach sequence as adjacent surfaces or explicitly designed blend meshes, with a single walkable collision surface only where intended.
- Confirm bridge-to-ramp height continuity and vehicle clearance using the real scene scale.
- Replace the ship and pier reference rectangles with instances of the approved assets in a dedicated test scene, without moving the production ship.
- Option B is approved for the isolated preview only; any production road edits still require a separate implementation review and approval.
- Add gameplay collision, water-depth boundaries, equipment interaction, vehicle/player tests, and server-authoritative out-of-bounds protection in later implementation stages.

## Validation status

- Static footprint arithmetic: updated from source dimensions.
- Godot editor/runtime validation: not performed; Godot is not available in the current execution environment.
- Rendered screenshot from the actual scene: not captured.
- Production files, approved layout, existing roads, buildings, and ship: not changed.
- No merge or deployment performed.

## Cross-check against the current production source (read-only)

The isolated blockout was compared with the existing production geometry in `proposal/compact-city-masterplan` at the time of this audit. This is coordinate arithmetic from source dimensions, not a Godot runtime or visual test.

### Confirmed intersections and access gaps

1. **Bridge vs. southwest road detour:** the proposed bridge deck occupies X=-15.5..-2.5, Z=91..108. The existing `MainRoad_Southwest_Detour` occupies X=-19..-13, Z=95..108. Their intersection is approximately 2.5m × 13m. The bridge cannot be placed as drawn without a road decision.
2. **Bridge/ramp vs. south basin bypass:** the existing `MainRoad_South_Basin_Bypass` occupies X=-16..16, Z=105..111. It overlaps the bridge deck over approximately X=-15.5..-2.5, Z=105..108, and overlaps the land-ramp footprint over approximately X=-15.5..-2.5, Z=108..111. This is a second independent route conflict.
3. **Water vs. center-south ground collision:** `Ground_Center_South` spans X=-12..12, Z=102..180. The proposed open sea spans X=-95..95, Z=65..107. Their plan overlap is 24m × 5m (120m²), including the Z=102..107 portion. The production ground has collision; if the water footprint is implemented unchanged, this strip risks retaining a hidden ground collision under water.
4. **Ship approach connection:** the existing ship hull is 4.8m wide and 17m long at (0,0,85), giving an approximate plan footprint X=-2.4..2.4, Z=76.5..93.5. The proposed arrival platform ends at X=-2.5, leaving a nominal 0.1m horizontal gap to the hull footprint. The existing pier spans X=-10..-2 and Z=77..91, so it overlaps the platform footprint but only reaches the ship hull by a 0.4m plan overlap. A continuous, safe boarding connection is not established by these rectangles; inspect the actual ship scene and access mesh before implementation.
5. **Existing yacht facilities:** the marina terminal remains centered at (75,0,38) and the royal yacht club at (75,0,58), each with a 13m × 9m footprint. The blockout's sea spans X=-95..95, Z=65..107, so these facilities do not intersect the sea rectangle in Z; preserve their current positions pending a full-scene shoreline review.
6. **Beach court dimensions:** the production beach court is a 42m × 36m sand apron centered at (40,0,125), with a 27m × 12m marked playing rectangle. The blockout retains the same reserved apron and its 27m × 12m line rectangle. Its schematic court integration is dimensionally consistent with the production source.

### Decisions required before changing production geometry

- Present a revised bridge centerline/landing and southern road route together; do not independently move the bridge or roads.
- Decide how the center-south ground collision is cut back or replaced at the new shoreline, without creating a hole in the walkable beach.
- Use the actual approved ship and pier scene to design a continuous boarding connection; do not move the ship.
- Keep the marina terminal, yacht club, and beach court at their existing positions unless the user explicitly approves a change.

### Validation boundary

This cross-check does not modify production files. It does not establish walkable collision, vehicle clearance, water depth, player access, or a rendered result. Godot validation and a screenshot from the actual scene remain outstanding.

## Coordinated route option B (user-approved for isolated preview; not production)

A coordinated alternative is documented in [royal_waterfront_route_option_b.md](royal_waterfront_route_option_b.md), with a coordinate sketch in [royal_waterfront_route_option_b.svg](royal_waterfront_route_option_b.svg).

- Center the 13m bridge at X=0, retaining the existing ship at (0,0,85).
- Keep the existing west/east southern road arms at Z=95.
- Extend both side detours at X=±16 from Z=95 to Z=120.
- Move the 32m-wide southern bypass from Z=108 to Z=120.
- Add an 8.5m-wide short land access spur from the ramp toward the relocated bypass, subject to turning-radius and grade review.

Static plan-view check: the centered bridge footprint X=-6.5..6.5 is 9.5m clear of the existing road-arm inner edges at X=±16 and 6.5m clear of the side-detour nearest edges at X=±13. The ramp ends at Z=113; the relocated bypass begins at Z=117, leaving a 4m gap that the proposed spur bridges. The spur overlaps the bypass by 1m in Z to form a T-junction. The extended side detours overlap the bypass by 3m in Z to form the two perimeter-road junctions.

The user approved Option B for the isolated review blockout, and the preview script now represents the centered bridge/platform, ramp, preserved road arms, extended detours, relocated bypass, and access spur. This does not resolve the shoreline/ground-collision overlap, prove a continuous boarding surface to the real ship, or establish vertical clearance, road grades, turning radii, or Godot runtime behavior. No production geometry was changed.


## Follow-up shoreline collision and ship access audit

A read-only follow-up is recorded in [royal_waterfront_shoreline_collision_audit.md](royal_waterfront_shoreline_collision_audit.md).

Key findings from the production source:
- The 190 × 42m preview sea overlaps all four existing collision-backed ground sections by a combined **7,404m²** in plan view, not only the center-south strip.
- The 180 × 5m shallow band overlaps existing ground by **900m²**; the 180 × 46m beach visual overlaps existing ground by **8,280m²**.
- Existing ground collision top is about Y=-0.05; preview beach top is Y=0.17, so a dedicated beach collision surface is needed to avoid a player settling below the visible sand.
- Existing ship main-deck top is Y=2.26 while the pier top is Y=0.16, a vertical difference of about **2.10m**. The Option B arrival platform top is Y=0.825 and does not itself solve boarding.
- The schematic bridge road top is Y=0.84 while the flat land-ramp top is Y=0.45; the current boxes do not form a smooth sloped transition. The platform and bridge also have a 0.5m plan gap at Z=90.5..91.

These are source-based geometry calculations only. No Godot physics/runtime test or rendered screenshot was performed. No production geometry was changed.
