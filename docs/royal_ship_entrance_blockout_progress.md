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


## Smooth mask facial-form pass — 2026-11-23

- Reviewed the actual Godot render from artifact `14814415086` (run `45163099074`, source commit `14695dccc0a2bbaef11e6a111ef8c2c7a1ab4f08`). The larger mask is more prominent, but the box-based facial features still looked angular and schematic.
- Replaced the block-shaped cheeks, ears, eye forms, nose, lips and beard detailing with smooth ellipsoid geometry and a tapered cylindrical ceremonial beard. Added a reusable `_ellipsoid` mesh helper.
- Latest script commit: `08c4a1d5084dafe4834b115c1c6a6e9fb3219bf5`.
- Fresh Godot validation run `45163355882` completed successfully, including import/script validation and headless startup of the exact waterfront preview scene.
- Fresh render run `45163355847` was still running its environment-install step when this note was added; the revised PNG has not yet been inspected.
- This remains a stylized primitive-mesh blockout, not a final sculpted Tutankhamun mask asset. No collision, vehicle physics, player interaction or network-authoritative ship entry implementation is claimed. No merge to `main`.


## Smooth facial-form render inspection — 2026-11-23

- Render run `45163355847` completed successfully and uploaded artifact `14813530656` from source commit `08c4a1d5084dafe4834b115c1c6a6e9fb3219bf5`.
- Retrieved and inspected the exact 1280x720 PNG from the Godot waterfront preview scene.
- The new ellipsoid facial forms and tapered beard are visible, but the mask still reads as a simplified oval gold face with stylized raised features; it does not yet match the detailed sculpted Tutankhamun mask in the user's supplied image. The surrounding vessel remains a low-detail blockout.
- This confirms the geometry smoothing pass rendered, but visual acceptance is still pending. Next visual milestone should replace the generic oval/primitive face treatment with a dedicated mask-shaped asset or a substantially more sculpted custom mesh, while retaining the approved blue-and-gold nemes, cobra/vulture insignia, collar, central gate, fixed ship position and bridge approach.
- No production-ready mask or ship asset is claimed. No collision, vehicle physics, player interaction, or network-authoritative ship entry implementation is claimed. No merge to `main`.


## Custom tapered Tutankhamun mask face mesh — 2026-11-23

- The previous Godot render (`14813530656`) was inspected directly. It showed the face still reading as a smooth oval rather than a recognizable sculpted funerary mask.
- Replaced the generic SphereMesh face base with a custom ArrayMesh generated from tapered horizontal profile rings: broader brow/cheek area, narrowed jaw and rounded chin, with smooth generated normals.
- Existing facial features, nemes stripes, cobra/vulture insignia, beard and collar remain in place.
- Script commit: `40b83370857ab19614ba0cd4b0656e5fe9b8cd91`.
- Fresh validation and exact-scene rendering are required. The custom face mesh is a procedural blockout refinement, not a final sculpted or photogrammetric Tutankhamun mask.
- No merge to `main`; no gameplay collision, vehicle physics, interaction trigger or online entry logic is claimed.


## Custom tapered mask render verification — 2026-11-23

- Godot validation run `45163805999` completed successfully.
- Exact-scene render run `45163806017` completed successfully and uploaded artifact `14812692472` from commit `40b83370857ab19614ba0cd4b0656e5fe9b8cd91`.
- Retrieved and visually inspected the rendered 1280x720 PNG. The custom tapered face mesh renders and the mask is centered above the gate, but the full ship remains a low-detail blockout with visibly primitive geometry; the mask is not yet at the reference image's sculpted detail or photoreal quality.
- This render verifies scene execution and the procedural mesh change only. It does not constitute visual approval or a final asset.
- Next work should prioritize a properly sculpted mask mesh/material and richer ship silhouette/deck detail, then render again for user review.
- No merge to `main`; no production collision, vehicle physics, player interaction trigger, or server-authoritative ship-entry logic is claimed.


## Sculpted hull silhouette and refined mask eyes — 2026-11-23

- Inspected the latest actual-scene PNG. The hull read as a flat rectangular slab and the mask eyes appeared too large and schematic.
- Replaced the plain main hull box with a custom extruded front-elevation mesh: raised bow/stern ends, a deeper rounded keel profile, and a dark-blue hull material.
- Refined the mask eye sockets and eyes to narrower almond-like forms, added lower kohl lines, and tightened the brow shapes.
- Script commit: `3cbe5ab814c7a7846d8a7ae00b93e12a980f75ad`.
- Fresh Godot validation and rendered preview are required before visual verification.
- This is still procedural blockout geometry. The full ship silhouette and mask remain below the detail/finish of the user's reference image. No gameplay collision, vehicle physics, player interaction trigger, or server-authoritative ship-entry logic is claimed. No merge to `main`.


## Sculpted hull / refined mask render inspection — 2026-11-23

- Validation run `45164181033` completed successfully.
- Render run `45164181130` completed successfully and produced artifact `14814396455` from commit `3cbe5ab814c7a7846d8a7ae00b93e12a980f75ad`.
- Downloaded and inspected the exact 1280x720 PNG rendered from `royal_waterfront_blockout_preview.tscn`.
- The custom hull silhouette is present, but the current camera angle and blockout construction still make the hull/deck stack read as broad flat stepped slabs rather than the elegant curved multi-deck vessel in the user's supplied reference. The face has recognizable mask cues and blue/gold nemes, but remains stylized low-poly geometry with visibly simplified eyes/nose/beard.
- The render is a genuine Godot scene capture, not a production-quality asset or final visual match. It verifies scene launch/render only.
- Next pass should prioritize reshaping the side decks into continuous curved profiles and refining the mask's facial proportions and gold surface detailing, while preserving the central gate, fixed vessel position, bridge, and interaction-ring placement.
- No final ship/mask production asset, collision, vehicle physics, player interaction trigger, or server-authoritative ship-entry logic is claimed. No merge to `main`.


## Vessel scale increase — 2026-11-23

- User noted that the vessel looked too small compared with the approved reference image.
- Added a dedicated `royal_ship_visuals` group for the hull, superstructure tiers, gate, pharaoh mask, collar, hull trim and ship insignia.
- Applied a uniform 1.28 scale (28% increase) around a pivot near the gate face, so the vessel grows substantially while the bridge, arrival apron and glowing interaction circle remain unchanged.
- Gate-centered pivot: `Vector3(0.0, 7.4, 95.5)`.
- Script commit: `2a40428f3eded0e63af98ef7e8e9ee3ccf5b835b`.
- Fresh Godot validation and exact-scene render are required to confirm the larger vessel fits the composition and does not overlap the bridge approach.
- This remains a review blockout, not a final ship asset. No gameplay collision, vehicle physics, player interaction trigger or server-authoritative ship-entry logic is claimed. No merge to `main`.


## 28% enlarged vessel render review — 2026-11-23

- Godot validation run `45165064202` completed successfully.
- Exact-scene render run `45165064196` completed successfully; artifact `14813063449` was retrieved and the PNG inspected at 1280x720.
- The 1.28 visual scale pass clearly makes the ship occupy much more of the frame. The gate, pharaoh mask and side decks are substantially larger relative to the bridge.
- Visual review also reveals the current blockout still has broad flat bright deck slabs and a simplified low-poly face; the new size alone does not reproduce the reference image's elegant curved multi-deck ship. The camera framing also makes the foreground bridge prominent and the ship read as a wide, flat facade.
- The scale change is therefore an intermediate review result, not final approval. Next pass should refine the curved side-deck silhouettes and hull volume and rebalance the camera composition so the enlarged vessel reads as a majestic ship rather than a flat facade.
- No final ship asset, collision, vehicle physics, interaction trigger or server-authoritative ship-entry logic is claimed. No merge to `main`.


## Curved stepped deck and camera-composition pass — 2026-11-23

- Replaced the four rectangular side-deck tier slabs with custom extruded ribbon meshes. Each tier now sweeps downward toward both bow/stern ends, with matching curved gold edge bands; the side-balcony trim remains.
- Added helper functions `_ship_deck_ribbon_mesh` and `_ship_deck_ribbon`; all deck ribbons join the same `royal_ship_visuals` scale group.
- Rebalanced the review camera to position `(0, 22, 135)`, FOV `56`, looking toward `(0, 9, 88)`, reducing some foreground bridge dominance while retaining the bridge-to-gate relationship.
- Script commit: `888f636599a44a569aaddb4ca92a275a53b20936`.
- Fresh Godot validation and rendered capture are required; mesh winding, appearance and framing have not yet been visually verified.
- This remains procedural review geometry, not a final ship asset. No merge to `main`; no production collision, vehicle physics, interaction trigger or online entry logic is claimed.


## Curved deck render review — 2026-11-23

- Godot validation run `45167850399` completed successfully.
- Render workflow `45167850600` completed its render and artifact upload successfully; artifact `14816140916` was downloaded and inspected as the exact 1280x720 PNG from the waterfront preview scene.
- The new tier ribbons are visible, but the render exposes a geometry/material issue: broad bright upper surfaces dominate the ship and the decks still read as flat horizontal wings rather than a convincing curved multi-deck cruise vessel. Some trim appears thin and disconnected at the outer ends.
- The frontal composition shows the gate and enlarged mask clearly, but the overall ship remains a stylized low-detail blockout, not a visual match for the user's reference image.
- Next pass must correct the deck ribbon surface construction and tone down the large bright surfaces, strengthen the blue hull/deck volumes, and create continuous rounded balcony profiles before another render is reviewed.
- This is a scene-render verification only. No final ship asset, gameplay collision, vehicle physics, player interaction trigger, or server-authoritative entry system is claimed. No merge to `main`.


## Deck fascia geometry correction — 2026-11-23

- The first curved-ribbon render was inspected; it showed oversized planar surfaces and visually disconnected bright trim.
- Replaced the ribbon's single custom triangle surface with 40 narrow overlapping box segments per tier. Segment height and depth follow a smooth downward sweep toward both ends, creating a continuous stepped balcony silhouette without broad planar faces.
- Segment meshes are parented under a single scaled tier node and inherit the existing ship visual scale group.
- Script commit: `d4c5754e97e046d408b83ae95635087007a04816`.
- New Godot validation and exact-scene render are required before accepting the geometry.
- The vessel remains a procedural blockout; no production asset, collision, vehicle physics, player interaction, or network-authoritative entry implementation is claimed. No merge to `main`.


## Curved deck helper return-type fix — 2026-11-23

- The validation run `45168289287` exposed a GDScript runtime type mismatch: the segmented deck helper returned a `Node3D` while its signature declared `MeshInstance3D`.
- Corrected the helper return annotation to `Node3D` in commit `2438306cc6b99fca9c790b0bb0d4640b37bbbf82`.
- The earlier render run `45168289013` was still running at the time of this note and is not treated as valid verification of the corrected script.
- Push of the fix triggers fresh Godot validation and render workflows. No visual approval is claimed until the new render is inspected.
- No merge to `main`; no production collision, vehicle physics, interaction trigger or server-authoritative entry logic is claimed.


## Segmented deck render inspection and follow-up tuning — 2026-11-23

- Corrected helper return type was validated by Godot 4.7.2; validation run `45168500103` succeeded.
- Exact scene render run `45168499368` succeeded and artifact `14815357593` was retrieved and inspected as a 1280x720 PNG.
- Inspection shows the side decks are still too horizontal/flat and the portal glow is overly cyan compared with the user's navy-blue and gold reference.
- Follow-up commit `470505ec162b2edf93ae0ca44269d5399eb2f56f` strengthens the deck-end drop, tapers depth toward the ends, adds a slight segment slope, and tones the portal to a restrained deep blue.
- This follow-up still requires a fresh Godot validation and rendered preview. It is not yet visually verified.
- The current image is a genuine scene capture but still only a low-detail blockout. No final ship asset, collision, vehicle physics, interaction trigger or server-authoritative entry logic is claimed. No merge to `main`.


## Review of curved-deck render and blue-volume refinement — 2026-11-23

- Validation run `45168794145` and render run `45168793980` both completed successfully on commit `470505ec162b2edf93ae0ca44269d5399eb2f56f`.
- Retrieved artifact `14815557624` and inspected the exact 1280x720 PNG rendered from the Godot preview scene.
- The render shows the side tiers, but they still read as thin horizontal gold/blue rails with a broad bright upper surface; the ship does not yet resemble the reference's deep navy multi-deck hull.
- Follow-up commit `39539a4f6c11adcb476d554b7d4a5adecc61b35a` adds dark navy lower fascia under each tier, increases the downward slope at the deck ends, narrows gold edge bands and changes balcony strips from ivory to blue.
- Fresh validation and rendering are required to assess this correction. The vessel remains procedural blockout geometry, not the final reference-matched ship. No production collision, vehicle physics, player interaction trigger, or server-authoritative entry system is claimed. No merge to `main`.


## Navy deck-volume render review and next geometry pass — 2026-11-23

- Godot validation run `45170833802` and exact-scene render run `45170833806` both completed successfully on script commit `39539a4f6c11adcb476d554b7d4a5adecc61b35a`.
- Retrieved artifact `14816094367` and inspected its 1280x720 PNG directly. The ship now fills most of the horizontal frame and the navy lower fascia is visible, but the four side decks still read as thin horizontal slats rather than substantial curved balcony tiers; the current mask is still a simplified blockout.
- Follow-up commit `80444032acf62c161a793ca6f08526de6ac73fa1` increases deck thickness from 0.72m to 1.12m, deepens the navy lower fascia, strengthens the downward sweep at the outer ends, tapers deck depth more strongly, and raises the gold edge trim to sit above the thicker deck.
- This follow-up requires fresh validation and an exact-scene render before its visual effect can be accepted.
- No final production ship asset, collision, vehicle physics, player interaction trigger, or server-authoritative ship-entry system is claimed. No merge to `main`.


## External ready-made ship asset candidate — 2026-11-23

- User authorized sourcing a ready-made ship model if a suitable asset can match the approved Five Civilizations Ship requirements.
- Candidate identified: Innerscene “Cruise ship” GLB, 9.5 MB, CC0 public-domain dedication. Source page: https://www.innerscene.com/tools/library/3d-parts/cruise-ship-d142a65c
- Published model dimensions: 289.4 m overall length, 33.4 m overall width, 62.4 m overall height; described with a hull, porthole decks, balcony cabins, promenade glazing, recessed lifeboats, pool/sun deck and rounded bridge front.
- This is a generic modern cruise ship, not the Egyptian royal ship shown in the user's reference. It does not include the pharaoh/Tutankhamun mask gate, navy-and-gold Egyptian styling, royal insignia, or the approved entrance interaction.
- It is a candidate base only. Do not replace the current ship blockout or merge it until the exact GLB is acquired, imported into Godot, inspected from multiple angles, and checked against the approved reference. If its superstructure conflicts with the user's no-extra-interior-floors/stairs requirement, modify or reject it rather than accepting that mismatch.
- Planned custom work if accepted: navy/ivory hull palette with gold trim, Egyptian royal gate and Tutankhamun mask, Five Civilizations emblems, entrance alignment to the bridge, and preservation of the fixed ship and gate interaction area.
- No purchase authorized or made. No asset download/import or visual match is claimed yet; the source page is identified but the binary download URL could not be verified in this pass. No merge to `main`.


## Ready-made ship sourcing review — 2026-11-23

- Rechecked the Innerscene Cruise Ship GLB candidate. Its source listing confirms a 9.5 MB GLB under CC0, overall dimensions 289.4 x 33.4 x 62.4 m, white hull, portholes, twelve superstructure decks (eight balcony-cabin decks and three promenade-glazing decks), recessed lifeboats, pool/sun deck, rounded bridge and aft funnel. Source: https://www.innerscene.com/tools/library/3d-parts/cruise-ship-d142a65c
- Suitability: potentially useful as a large hull and cruise-ship silhouette base, but not suitable for direct drop-in. The twelve-deck generic superstructure, white modern livery and generic bridge/funnel conflict with the approved Egyptian royal visual. The model would require selective removal/replacement of superstructure and complete material/ornament redesign.
- Additional modular candidate: 3DAssets.dev “Cruise Ship Deck and Lounge” pack, CC0 1.0, 62 parts, 3.7 MB total, including a walkable starter scene, teak/steel deck modules, promenade bulwarks, balcony runs, lifeboats, pool/hot tub, lounge and deck furnishings. Source: https://3dassets.dev/packs/cruise-ship-deck-and-lounge
- Suitability: useful for interior/deck props and walkable deck dressing, but not a replacement for the large exterior hull and royal gate.
- Current recommendation: evaluate the Innerscene cruise ship as a hull/silhouette donor only, and the 3DAssets.dev kit as optional interior/deck prop source. Preserve the current approved ship blockout until the exact binary files are acquired, imported and inspected in Godot. Do not accept the 12-deck generic superstructure as-is; remove/reshape it to the approved Five Civilizations Ship form and keep the fixed mooring, bridge connection, royal gate, Tutankhamun mask, and interaction circle.
- The web catalogue pages were verified, but direct binary download URLs were not exposed in the retrieved page content. No GLB binary was downloaded or imported in this pass. No final asset or visual match is claimed. No merge to `main`.


## Latest render review and ready-made asset acquisition status — 2026-11-23

- Godot validation run `45183973129` and exact-scene render run `45183973132` both completed successfully on commit `80444032acf62c161a793ca6f08526de6ac73fa1`.
- Retrieved and inspected the exact rendered preview artifact `14822957011` (1280x720 PNG) from the same Godot scene. The ship reads as a broad, symmetric navy hull with gold rails and the central mask/gate blockout, but the decks remain visibly skeletal horizontal rails; this is not a match for the richly detailed layered reference image and is not a final ship asset.
- Verified a direct ready-made modular asset pack page: https://3dassets.dev/packs/cruise-ship-deck-and-lounge. Its manifest URL is https://3dassets.dev/api/v1/packs/cruise-ship-deck-and-lounge and its starter-scene GLB URL is https://cdn.3dassets.dev/assets/38462/v1/model.glb. Pack contains 62 CC0 1.0 GLB parts, 3.7 MB total, 59,524 triangles, metres/+Y up; modular teak/steel deck plates, promenade bulwarks, superstructure wall and balcony runs, lifeboats, pool, lounge furniture, etc. Godot 4 imports its GLBs directly. The pack is modular deck/interior dressing, not a complete large exterior hull and has no Egyptian royal gate or mask. Source page explicitly states colliders, navigation and gameplay scripts must be supplied by the game.
- Direct starter-scene CDN URL was identified in the source page, but the binary could not be fetched into the current project workspace in this pass; no asset file has been imported into the repository. The Innerscene Cruise Ship GLB remains a possible hull donor, but its twelve-deck modern cruise superstructure is not acceptable as-is.
- Recommendation: preserve the current approved reference and use the modular CC0 pack only for selected deck/interior components after binary acquisition; evaluate the Innerscene hull donor separately and remove/rebuild its generic superstructure as required. Do not replace the ship with the starter deck scene.
- No final asset, visual match, production collision, vehicle physics, player interaction trigger, or server-authoritative ship-entry system is claimed. No merge to `main`.


## Candidate selection after latest user confirmation — 2026-11-23

- Re-inspected the exact preview image currently attached at `/mnt/data/royal-waterfront-latest/royal-waterfront-preview.png`. It is a direct Godot scene capture, 1280x720. It confirms the current ship remains a low-detail procedural blockout: broad navy hull, thin horizontal gold/blue deck rails, central gate/mask blockout, and bridge. It is not close enough to the user's richly detailed reference and must not be presented as final.
- Compared additional CC0 candidates:
  - Innerscene Cruise Ship GLB (9.5 MB, 289.4 x 33.4 x 62.4 m) remains the strongest candidate for the large exterior hull and multi-deck cruise silhouette. It is white and has 12 modern superstructure decks, so it must be treated as a donor mesh for hull/volume only; the royal gate, mask, gold/navy styling and Egyptian ornament need replacement/custom work. Source: https://www.innerscene.com/tools/library/3d-parts/cruise-ship-d142a65c
  - 3DAssets.dev Cruise Ship Deck and Lounge is a 62-part CC0 modular deck/prop kit (3.7 MB total); the assembled starter scene is 80 x 17.86 x 56 m and has only one walkable deck level with a small three-tier superstructure. It is useful for selected deck/interior dressing, not the full outer hull. Source: https://3dassets.dev/packs/cruise-ship-deck-and-lounge
  - Innerscene Ro-Ro Ferry is 189.4 x 29.1 x 36.7 m with passenger superstructure and vehicle decks, but its ferry ramp/vehicle-carrier arrangement is not the approved fixed royal ship entrance. Secondary candidate only. Source: https://www.innerscene.com/tools/library/3d-parts/ro-ro-ferry-90b664df
  - Container ship and aircraft carrier candidates rejected as silhouette mismatches.
- Acquisition limitation: current available GitHub connector can read/write UTF-8 repository files and download GitHub Actions artifacts, but cannot fetch arbitrary binary files from external CDNs directly. The web reader can verify asset metadata/pages but cannot retrieve the GLB binary. Therefore none of these external binary assets has yet been downloaded or imported. Do not claim otherwise.
- Next practical step requires a binary-capable download path (for example, the user providing the GLB file, or a repository workflow with permitted outbound download and artifact upload). Until then preserve the existing blockout and do not swap it for a guessed or incomplete asset.
- No final ship asset, import, visual match, collision, vehicle physics, player interaction trigger, or server-authoritative entry system is claimed. No merge to `main`.
