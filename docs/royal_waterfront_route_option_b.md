# Royal Waterfront — Combined Bridge and Southern Road Option B

**Status:** Geometry proposal for review only. Not approved for production and not applied to the live scene.

## Purpose

Resolve the bridge conflict as one coordinated road-and-bridge arrangement. The option preserves the approved ship at (0, 0, 85), keeps the existing west/east southern road arms, and avoids the existing two short detour strips by centering the bridge in the 26m gap between them.

## Proposed coordinates

All dimensions are metres in the existing world X/Z plane.

| Element | Proposed footprint / center | Notes |
|---|---|---|
| Royal bridge deck | center (0, 99.5), size 13 × 17; X=-6.5..6.5, Z=91..108 | 8.5m two-way carriageway plus 2.25m protected walkway each side |
| Arrival platform | center (0, 85.5), size 13 × 10; X=-6.5..6.5, Z=80.5..90.5 | Better centered on existing ship/pier access than the prior X=-9 proposal; exact connection still requires the real ship scene |
| Land ramp | center (0, 110.5), size 13 × 5; X=-6.5..6.5, Z=108..113 | Connects bridge to beach-side land approach |
| Existing west/east south road arms | unchanged: centers X=-55.5/+55.5, Z=95; size 79 × 6 | Their inner edges are at X=-16 and +16 |
| West/east detours | centers X=-16/+16, Z=107.5; size 6 × 25; Z=95..120 | Extends existing 13m detours from Z=95..108 to Z=95..120 |
| South basin bypass | center (0, 120), size 32 × 6; X=-16..16, Z=117..123 | Relocated from Z=108; joins both extended side detours |
| Short land access spur | center (0, 114.5), size 8.5 × 7; Z=111..118 | Optional connection from ramp to bypass; T-junction at bypass. Confirm turning radius and grades |

## Why this resolves the known plan-view conflicts

1. Bridge X range (-6.5..6.5) stays clear of existing west/east road arms, whose nearest edges are X=-16 and +16 at Z≈95. Nominal horizontal clearance is 9.5m on each side.
2. Bridge X range also stays clear of both side detours, which occupy X=-19..-13 and X=13..19. The gap between detours is 26m, leaving 6.5m between each bridge edge and the nearest detour edge.
3. The bridge ramp ends at Z=113. Moving the bypass to Z=120 gives a 4m plan gap between ramp end and bypass near edge at Z=117. The optional 7m access spur fills this gap and meets the bypass at a T-junction.
4. The extended detours meet the relocated bypass at Z=120, preserving a continuous perimeter-road loop around the bridge approach.
5. The bridge/arrival platform now centers on X=0, so its footprint overlaps the existing pier and ship access envelope more generously than the former X=-9 option. This is only a plan-view improvement, not proof of a safe boarding surface.

## Shoreline and collision dependency

This road proposal does not by itself resolve the water/terrain issue. Current production center-south ground begins at Z=102 and extends through the beach. The sea, transition, shallow band, beach, and their collision layers must be redrawn together. Do not simply place deep-water visuals over existing land collision. Preserve a walkable shallow zone and ensure deep water has the intended movement boundary.

The ship remains fixed. The marina terminal, yacht club, beach handball area, beach gym, and all approved buildings remain in place.

## Required validation before implementation

- Inspect the actual Godot scene and actual ship/pier meshes, including deck heights and boarding width.
- Check bridge and ramp vertical profiles, vehicle turning radii, pedestrian barriers, and approach grades.
- Check proposed Z=120 bypass and both extended detours against the full live road network and all building footprints.
- Resolve shoreline collision boundary, shallow-water walking behavior, and deep-water boundary.
- Capture the review image from the actual Godot scene after validation.

## Change boundary

Only the proposal document and coordinate diagram are added to the isolated review branch. No production scene, production road, approved building, ship, or gameplay collision is edited. No merge or deployment is performed.
