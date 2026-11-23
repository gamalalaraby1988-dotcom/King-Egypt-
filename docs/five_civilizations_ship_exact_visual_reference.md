# Five Civilizations Ship — Exact Visual Reference

Status: user-supplied visual reference received on 2026-11-23. This image is the primary visual target for the ship model and entrance composition. It supersedes the earlier generic primitive-ship silhouette. It does not authorize merging to main or replacing unrelated approved city assets.

## Reference features to reproduce

- A very large, wide, stationary royal vessel, viewed from the bridge-facing bow/entrance.
- Deep royal-blue hull with extensive gold trim, Egyptian winged emblems, gold ornamental bands and illuminated portholes.
- Broad, stepped multi-level side decks and long symmetrical side wings, matching the visible silhouette in the reference. These are side-deck tiers, not a request for a generic modern cruise ship redesign.
- A monumental central Egyptian entrance structure integrated into the vessel: large central pharaonic face/crown motif above the gate, tall decorated side pylons, flanking statues, a bright ceremonial portal and the visible KING OF EGYPT CITY sign.
- Symmetrical composition around the central gate, with the vessel wings extending far to both sides.
- Royal bridge aligned with the center of the gate. It is broad enough for two-way vehicle access and has protected pedestrian edges, gold railings, lighting and Egyptian ornament.
- A luminous circular player interaction pad directly in front of the ship gate at the bridge terminus. The player stands in the circle, presses Interact, then confirms entry to transfer to the ship's main hall, following the previously approved entry flow.
- Keep vehicle approach/bypass lanes clear of the central interaction circle.

## Separate game UI from world geometry

The uploaded reference is a gameplay-style composite. Do not model the player portrait/profile, level display, minimap, mission/reward buttons, joystick, sprint/action buttons, or the on-screen interaction prompt as permanent ship architecture. The central portal sign, ship ornament, bridge, vehicles as scale/context, and glowing interaction circle are useful visual references. Vehicles and player are not required as static geometry in the ship asset.

## Modeling direction

Build the ship as a coherent large-scale Godot scene/GLB asset with a symmetrical centerline and separately understandable components: hull, stepped side-deck tiers, side wings, gold hull ornament, central gate pylons, pharaonic crown/face feature, flanking statues, ceremonial portal, and bridge-facing entry apron. Preserve the blue-and-gold palette and the reference's monumental proportions. The vessel remains moored and stationary.

The preview must be rendered from the exact same Godot scene/model intended for integration, with matching geometry, materials, colors and details. Do not substitute a separately generated concept image or unrelated internet ship image.

## Existing blockout discrepancy to correct

The current `_build_five_civilizations_ship_blockout()` in `scripts/royal_waterfront_blockout_preview.gd` is only a small primitive placeholder (approximately 8m wide) and does not match the supplied reference's broad hull, stepped side decks or monumental central gate. Its current interaction-pad placement also needs a coordinate pass so the circle is physically outside the gate on the bridge-facing approach, not overlapping the ship footprint. Treat the current blockout as review scaffolding only, not the approved final ship.

## Implementation and approval gates

1. Rework the actual Godot ship geometry to match this reference, retaining the approved stationary vessel and bridge connection.
2. Recalculate the entrance, bridge terminus, vehicle bypasses and interaction-pad positions together so they align in-world.
3. Render the exact revised Godot scene and inspect the image for silhouette, scale, symmetry, gate alignment and interaction-circle visibility.
4. Present that render for user review before any production integration.
5. Do not merge to `main` or production without explicit user approval.

This document records the reference and modeling requirements; it does not claim that the final ship mesh, gameplay collision, vehicle physics, interaction trigger, or online entry logic are complete.
