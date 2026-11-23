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


## Follow-up work
- Corrected the interaction-pad position back to the **ship-facing end of the bridge** (Z≈91.5 in the current blockout), rather than leaving it in the middle of the bridge.
- Added `.github/workflows/royal-waterfront-preview-check.yml` to import the project and attempt a headless startup of the exact preview scene on future pushes to this branch.
- The workflow has been committed, but no GitHub Actions run is visible yet; therefore this is not a passed validation.
- The interaction circle and vehicle bypass remain visual-only placeholders pending a real Godot render, collision setup, and vehicle/player testing.


## Ship geometry blockout follow-up

- Repository asset inspection found no existing Five Civilizations Ship mesh, scene, or vessel model in this branch; only the waterfront preview and design/progress documents were present.
- Added a native Godot primitive-mesh **ship geometry blockout** to the standalone preview scene at the approved moored reference position. It includes a hull, one main deck, a simplified main hall, a bridge-facing gate, gold perimeter rails, and five small civilization markers.
- The preview calls this a **blockout**, not the final ship asset. It does not add a second floor, stairs, movement, collision, or gameplay entry logic.
- The ship gate is placed on the bridge-facing (+Z) end for visual alignment with the existing interaction pad. Exact alignment remains provisional until the final ship model and gate dimensions are supplied/created and inspected together.
- Only `scripts/royal_waterfront_blockout_preview.gd` was changed, on `feature/royal-waterfront-blockout-preview`. No production scene or `main` branch was changed.
- Next validation: Godot headless check and a genuine render from the updated preview scene; inspect the resulting image before claiming visual alignment.


## Royal ship detail pass — 2026-11-23

- Added a second visual-detail pass to the same stationary, single-main-deck ship blockout: continuous gold hull sheer-lines, illuminated porthole details, deck-edge rail posts, a shaped bow cap and crest, a stern cap, five inset civilization emblem plaques, and a slim crown band above the main hall.
- The ship remains fixed at the approved location. No extra floor, stairs, ship movement, production scene changes, collision, vehicle physics, interaction trigger, or network entry logic were added.
- Change committed on `feature/royal-waterfront-blockout-preview`: `1c98ed04331cb140e700906f1c3b76d63d7a69f1`.
- Godot 4.7.2 import/script validation and headless startup both passed on this commit (workflow run `45101305293`).
- A genuine render from the same updated scene is running in workflow `45101305010`; its image must be inspected before visual alignment or appearance is reported as confirmed.
- No merge to `main`.


## Rendered ship-detail review — 2026-11-23

- The updated scene was rendered by GitHub Actions from the exact Godot preview scene on commit `1c98ed04331cb140e700906f1c3b76d63d7a69f1`.
- Render workflow `45101305010` completed successfully and uploaded artifact `14785398210` (`royal-waterfront-rendered-preview`, PNG extracted from the scene render).
- Visual inspection confirms the added hull bands, portholes, bow/stern caps, deck rail posts, five emblem plaques, and crowned main-hall roof are present in the rendered image, together with the bridge and arrival apron.
- The current camera/render is a broad blockout view; labels and the approach apron make the interaction circle less distinct than desired. The next visual pass should improve camera framing and pad readability before asking for approval of final ship detailing.
- This is still primitive-mesh review geometry, not a production-ready detailed vessel. Collision, turning physics, player interaction, and online entry logic remain unimplemented and untested.
- No production scene was modified and nothing was merged into `main`.
