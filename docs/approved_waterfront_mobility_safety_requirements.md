# Waterfront, Ship Access, Mobility, and Safety Requirements

Status: approved design requirements; implementation and gameplay validation are pending.

## Waterfront and beach
- Expand the current small waterfront basin into a large sea using available open land, while preserving approved city landmarks, roads, and circulation.
- Provide a wide sandy beach, not a narrow strip.
- Arrange a coherent coastal section with a generous pedestrian promenade, landscaped sidewalk buffers/curbs, and a suitable coastal road.
- Keep the water visually deep-sea beyond the designated shallow-access shelf.

## Shallow-water movement
- The shoreline shall include a clearly bounded shallow-water shelf.
- The player may walk through this shallow water; do not switch the character to a swimming mode.
- Cars may enter and drive through the shallow-water shelf.
- Both player and vehicles must be stopped or safely redirected at the configured safe-depth boundary before deep water.
- The shallow shelf must have suitable collision/ground support and must not rely on an invisible full-depth floor.

## Royal ship and access
- Preserve the previously approved stationary Five Civilizations Ship identity and its approved interior/portal system; do not replace it with a generic multi-deck yacht or make it sail away.
- Locate the ship offshore in a suitable position with adequate clearance from the beach and navigation area.
- Provide a wide, elegant, two-way vehicle bridge/causeway from shore to the ship.
- Include protected pedestrian edges/sidewalks, barriers, lighting, and a vehicle arrival/turnaround area at the ship.
- Keep safe clearance for watercraft under the bridge wherever bridge height and water depth permit.

## Sidewalks and mobility
- Sidewalks are traversable surfaces, not forbidden zones.
- The player, cars, and scooters may mount and leave sidewalks at designed curb ramps or smooth transitions.
- Provide collision geometry and ramp slopes suitable for each supported controller; do not make every curb universally climbable if it creates unstable vehicle behavior.

## City-wide safety envelope
- Apply consistent safe boundaries to the playable city, sea depth, bridges, rooftops, cliffs, mountain edges, waterfront platforms, and other fall hazards.
- Prefer invisible collision/safety boundaries that do not visually obstruct the environment.
- Prevent falling through geometry, leaving the playable world, or driving beyond the allowed water depth.
- If an unexpected fall or out-of-bounds event occurs, recover the player or vehicle to a valid nearby safe location and reset velocity/input safely.
- Apply equivalent safeguards to online play through server-authoritative validation; local-only checks are not sufficient for multiplayer.
- Keep legitimate movement and access open on the beach, shallow water, sidewalks, ramps, and bridge.

## Implementation and acceptance checks
1. Expand and render the sea/beach/road/bridge/ship layout in the production city scene.
2. Verify player walking in shallow water and stopping at the safe-depth boundary.
3. Verify cars can enter shallow water and cannot cross into deep water.
4. Verify player, cars, and scooters can use sidewalks through designed ramps.
5. Verify city perimeter, rooftops, cliffs, bridges, ship platforms, and mountain edges prevent falls or recover safely.
6. Verify online/server-side enforcement, not only offline client behavior.
7. Capture previews from the same production scene and run Godot checks before proposing any merge to `main`.

No production scene or gameplay behavior is considered implemented merely because this requirements document exists.
