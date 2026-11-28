# Approved KING OF EGYPT CITY World Layout Change

Status: approved design direction; implementation must be staged and previewed before acceptance.

## Preserve without relocation
- Keep the sea and open water in their current locations.
- Keep the beach and waterfront in their current locations.
- Keep the desert district, royal resort, and pyramids in their current locations.
- Preserve the existing royal civilizations ship and its access.
- Do not remove approved buildings or gameplay systems as part of the layout change.

## Circular central city
- Reshape the central urban district only into a circular/radial composition.
- Place the royal palace and a generous circular royal plaza at the center.
- Arrange the existing approved city districts around the center in concentric bands.
- Use a small number of legible ring roads connected by radial streets; avoid excessive concentric road clutter.
- Connect the circular city to the existing beach and desert approaches without moving either destination.
- Retain walkable access, vehicle access, and mobile-friendly navigation.

## Elevated royal panoramic route behind the pyramids
- Remove the requirement for players to climb the existing steep/awkward mountain route.
- Replace the difficult ascent with a broad, gently graded elevated road passing behind the pyramids.
- Keep the pyramids visible and unobstructed; the road must pass behind them, not across their fronts.
- Connect the elevated route to the city and desert-side circulation.
- Add a large, level royal observation plaza on the elevated section, with safe perimeter railings and a clear panoramic view over the city, sea, beach, and pyramids.
- Walking and vehicle approaches must be practical; avoid steep slopes, narrow ledges, and forced climbing.

## Implementation safeguards
1. Treat this document as the approved design brief, not proof that the 3D geometry has already changed.
2. Inspect existing coordinates, collisions, navigation, safe-zone bounds, and district connections before editing geometry.
3. Implement the central circular city and elevated route in separate, reviewable changes.
4. Preserve existing terrain and water placement. Any required local terrain blending must not relocate the sea or desert.
5. Capture production-scene aerial and ground-level previews after each phase.
6. Run the Godot import, headless scene startup, and relevant gameplay/safety tests.
7. Do not merge this branch into the default branch without the user's explicit approval.
