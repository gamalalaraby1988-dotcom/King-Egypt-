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


## Uploaded approved reference applied — 2026-11-23

- The user re-uploaded the exact approved ship concept image. It is now the visual source of truth for the next ship-mesh pass; no substitute web image or newly invented civilization identities are used.
- Reworked the standalone Godot ship blockout to match the reference's dominant silhouette: a very wide dark royal-blue hull, gold waterline and trim, stepped side-superstructure fascia, large side winged-emblem motifs, illuminated portholes, and a monumental central Egyptian gate.
- Added a large gold pharaoh-mask/headdress silhouette above the gate, flanking guardian-statue/pylon forms, a blue illuminated doorway, and the KING OF EGYPT CITY nameplate.
- The central gate remains oriented toward the bridge approach and the interaction circle remains in front of the gate at the bridge terminal. The ship remains stationary.
- The stepped side bands are visual fascia/overhangs only; this pass does not add walkable upper decks, stairs, or gameplay floors.
- Script update committed on `feature/royal-waterfront-blockout-preview`: `a5f9d5c9a4a3ec69f7ae306fc32d2f948e34a0c8`.
- This is still a primitive-mesh visual blockout, not the final production ship asset. Collision, vehicle physics, player interaction, network-authoritative entry, and final material/lighting polish are not implemented or validated by this change.
- The new commit must pass the Godot check workflow and produce a genuine render from the same preview scene. The rendered image must be visually inspected before claiming the reference match is validated.
- No production scene was changed and nothing was merged into `main`.


## Render review and Egyptian emblem refinement — 2026-11-23

- Retrieved and inspected the rendered PNG from workflow run `45102317971`, artifact `14785967516`, generated from the exact Godot preview scene at commit `367705ea5462db6b2b0de2cd83e741a00593daf4`.
- The render confirmed the wider hull, centered gate, and bridge approach, but also showed that the pharaoh face remained too primitive and the forward winged emblems were not legible enough. The render is therefore a review checkpoint, not an approved final ship.
- Added a further detail pass on the same preview scene: shaped nemes side lappets and gold stripes, eye/brow details, nose, ceremonial beard, and larger forward-facing winged-sun emblems on the blue fascia.
- Latest script commit: `7099b8160e02543f045e4d7ecbbe796f86c31ebf`.
- A fresh Godot validation and render are required for this latest detail pass. Do not describe the new details as validated until those workflows finish and the resulting render is visually inspected.
- Still a primitive-mesh blockout. No final production ship asset, gameplay collision, vehicle physics, player interaction, or network-authoritative entry logic is claimed.
- No production scene changed and no merge to `main`.


## Render inspection: pharaoh mask occlusion found and corrected — 2026-11-23

- Retrieved artifact `14785664348` from successful render run `45102569177` (source commit `694252f5d1a516f0af08a356ae032656cf210bd8`) and inspected the actual PNG from the Godot scene.
- The render showed a large blue headdress backing occluding the pharaoh face; the intended facial features were behind the backing plane from the bridge camera view. The earlier render was therefore not acceptable as a reference-matching preview.
- Corrected the depth placement so the face, eyes, brows, nose, beard, nemes side lappets, and stripes sit in front of the backing. Removed a second overlapping winged-emblem pass to avoid duplicated geometry.
- Fix committed to the test branch as `b6222c281a97d105d8ebd495db34f86fa9b42b2f`.
- New Godot validation run: `45102664415`; new render run: `45102664444`. Both were queued/in progress at the time of this note. The new render must be downloaded and visually inspected before confirming the occlusion fix.
- Remains a primitive-mesh blockout only. No production ship asset, gameplay collision, vehicle physics, interaction trigger, or network-authoritative entry logic is claimed.
- No merge to `main`.


## Pharaoh facial-feature visibility pass — 2026-11-23

- Inspected the actual PNG from artifact `14785664538` (render run `45102664444`, source SHA `b6222c281a97d105d8ebd495db34f86fa9b42b2f`). The face still read as a blank gold oval because the eyes, nose and beard were embedded behind the front surface of the scaled sphere mesh.
- Moved the facial features to the camera-facing side of the mask and added visible eye sockets/eyes/pupils, brows, cheeks, ears, stepped nose, mouth, ribbed ceremonial beard and uraeus crest.
- Script commit: `38311928acef3c667d4bdaee9ab5c385df6444ae`.
- Fresh validation run: `45161961858`; fresh render run: `45161961847`. Both were queued/in progress when this note was added. Do not claim the latest face is validated until the workflows finish and the new PNG is inspected.
- Still a primitive-mesh review blockout. No production asset, collision, vehicle physics, interaction trigger, or network-authoritative entry implementation is claimed. No merge to `main`.


## Latest face render reviewed and deck-detail pass — 2026-11-23

- The validation workflow for face-detail commit `38311928acef3c667d4bdaee9ab5c385df6444ae` completed successfully: run `45161961858`.
- The exact-scene render workflow completed its render step and uploaded artifact `14810374942` in run `45161961847`. The PNG was extracted and visually inspected at 1280x720.
- Inspection confirms the frontal ship silhouette, central gate, bridge approach and pharaoh mask details are present. However, the face still reads as stylized blockout geometry rather than the detailed sculpted pharaoh in the user's reference image; the side decks also need more convincing cabin/window detail.
- Added a deck-detail pass: illuminated cabin-window rows, gold window frames, balcony rails and posts across the four stepped tiers, keeping the central gate clear and the vessel stationary.
- Latest script commit: `e7b33846521666e416cb90dae8ed9618179cb96e`.
- This newest deck-detail pass still requires a fresh Godot validation, render, artifact retrieval and visual inspection before it can be called verified.
- This remains a primitive-mesh blockout, not the final ship asset. No collision, vehicle physics, player interaction trigger, or network-authoritative ship-entry logic is claimed. No merge to `main`.


## Render review and Tutankhamun mask refinement — 2026-11-23

- Reviewed the exact-scene render artifact `14811935992` from run `45162241626` at commit `e7b33846521666e416cb90dae8ed9618179cb96e`. Both the Godot check (`45162241636`) and render workflow (`45162241626`) completed successfully.
- The render shows the ship silhouette, central gate, stepped deck rows and bridge. The mask is recognizable as a gold-and-blue royal headdress concept, but the current face still reads as simple blockout geometry and does not yet match the fine sculpted Tutankhamun funerary mask in the supplied reference.
- Following the user's explicit confirmation that the centerpiece is Tutankhamun's mask, added another refinement pass: layered broad gold/blue ceremonial collar and a clearer cobra-and-vulture brow insignia with feather details.
- Latest script commit: `f14e15fe69b19a2569748af2cbc53286361f6dd3`.
- This latest addition requires fresh Godot validation, rendering, artifact retrieval and visual inspection before it can be called verified.
- All work remains on `feature/royal-waterfront-blockout-preview`. The ship is still primitive-mesh blockout geometry; no final production asset, gameplay collision, vehicle physics, player interaction, or server-authoritative entry logic is claimed. No merge to `main`.


## Mask render inspection and scale/readability refinement — 2026-11-23

- Render workflow `45162722370` completed successfully and produced artifact `14810953439` from the exact Godot preview scene at commit `f14e15fe69b19a2569748af2cbc53286361f6dd3`.
- Inspected the extracted 1280x720 PNG. The ship, central gate, bridge, mask, nemes stripes, collar and brow insignia are present. The mask remains highly stylized blockout geometry and reads too small relative to the ship facade compared with the user's reference.
- Increased the face/head scale and widened/tallened the headdress backing, side lappets and crown to make the Tutankhamun centerpiece more prominent from the bridge approach.
- Latest script commit: `14695dccc0a2bbaef11e6a111ef8c2c7a1ab4f08`.
- Fresh validation/render are required before this scale pass is verified.
- Remains a primitive-mesh blockout; no final sculpted production mask asset or gameplay collision/interaction/network entry implementation is claimed. No merge to `main`.
