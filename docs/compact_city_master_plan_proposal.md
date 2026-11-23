# KING OF EGYPT CITY — Compact Luxury Master Plan (Proposal v1)

Status: **proposal for founder review only**. This document does not move buildings, alter runtime coordinates, change collision, or merge anything into production.

Base: north-district approved-placement branch at `c0821d4f34a222828e615b99c9ab001110867ab9`.

## Design rules

- Compact luxury urban fabric: target clear gaps of 3–6 m between ordinary building footprints where site geometry permits.
- Keep main streets 16–20 m, local streets 8–12 m, pedestrian walks 2–3 m.
- Keep royal square, pyramids/Giza view corridor, mountain route, beach, waterfront promenade, marina and ship as open landmarks.
- Keep every building entrance accessible; no building-to-building contact, blocked fire access, or collision overlap.
- Preserve Android performance with existing facade LOD and instancing.
- Coordinates below are **proposed centers in Godot X/Z metres**, not applied runtime values. Y=0 unless noted.
- The north entertainment block retains the founder-approved northward relocation concept, but its proposed compact coordinates below are a new proposal and require explicit approval.

## Proposed district arrangement

### A. Royal core
| Building | Proposed center (X, Y, Z) | Footprint (m) |
|---|---:|---:|
| Royal Palace | (0, 0, -78) | 22 × 16 |
| Royal Bank | (22, 0, -78) | 12 × 11 |

Keep the royal square and founder gate open in front of the palace. Do not squeeze the palace into the commercial blocks.

### B. Commercial quarter
| Building | Proposed center (X, Y, Z) | Footprint (m) |
|---|---:|---:|
| Supermarket | (-28, 0, -35) | 10 × 10 |
| Market | (-10, 0, -35) | 12 × 10 |
| Employment Center | (12, 0, -35) | 11 × 10 |
| Main Restaurant | (32, 0, -35) | 12 × 10 |
| Royal Cafe | (-28, 0, -17) | 10 × 10 |
| Commercial Services | (32, 0, -17) | 12 × 10 |

Arrange storefronts around a walkable commercial lane, with rear/service access kept clear.

### C. Residential quarter
| Building | Proposed center (X, Y, Z) | Footprint (m) |
|---|---:|---:|
| Apartment Palace 1 | (-27, 0, 15) | 12 × 12 |
| Apartment Palace 2 | (-9, 0, 15) | 12 × 12 |
| Apartment Palace 3 | (9, 0, 15) | 12 × 12 |
| Apartment Palace 4 | (27, 0, 15) | 12 × 12 |

Use a shared residential garden/courtyard and keep a clear pedestrian loop around all four buildings.

### D. Entertainment quarter — compact two-row cluster
| Building | Proposed center (X, Y, Z) | Footprint (m) |
|---|---:|---:|
| Royal Theater | (-18, 0, -120) | 13 × 11 |
| Stadium | (0, 0, -120) | 16 × 12 |
| Sports Club | (19, 0, -120) | 12 × 10 |
| Water City | (-15, 0, -145) | 14 × 12 |
| Cinema | (4, 0, -145) | 12 × 10 |
| DAILY ARCADE | (23, 0, -145) | 13 × 10 |

Keep a clear public arrival street on the south side of the cluster and separate pedestrian entrances from vehicle drop-off. Preserve a visual corridor toward the pyramids to the north.

### E. Civic and mobility services
| Building | Proposed center (X, Y, Z) | Footprint (m) |
|---|---:|---:|
| Police Station | (-62, 0, -25) | 10 × 9 |
| Fire & Rescue | (-62, 0, -5) | 11 × 9 |
| Fuel Station (open forecourt) | (-62, 0, 18) | 16 × 24 |
| Courthouse | (62, 0, -25) | 11 × 9 |
| Train Station | (62, 0, -5) | 13 × 9 |

The fuel forecourt must remain open and drive-through. Emergency services need direct access to the main street.

### F. Marina and adventure edge
| Building | Proposed center (X, Y, Z) | Footprint (m) |
|---|---:|---:|
| Marina Terminal | (75, 0, 38) | 13 × 9 |
| Royal Yacht Club | (75, 0, 58) | 13 × 9 |
| Adventure Center | (-75, 0, 58) | 11 × 9 |
| Desert Lodge | (-75, 0, 75) | 12 × 10 |
| Mountain Temple | (75, 0, 75) | 13 × 11 |

Treat this as a transition zone, not a dense building wall: retain access to the mountain route and the waterfront promenade. The final marina/ship geometry remains subject to its separate approved design.

## Schematic (not to scale)

```text
                         NORTH / GIZA VIEW
                   [PYRAMIDS + OPEN VIEW CORRIDOR]

                 [THEATER] [STADIUM] [SPORTS CLUB]
                 [WATER CITY] [CINEMA] [DAILY ARCADE]

 [POLICE / FIRE]       [ROYAL PALACE + BANK]       [COURT / TRAIN]
                       [ROYAL SQUARE + GATE]

 [SUPERMARKET] [MARKET] [EMPLOYMENT] [RESTAURANT]
 [ROYAL CAFE]                         [SERVICES]

       [APARTMENTS 1] [2] [3] [4] + SHARED COURTYARD

 [ADVENTURE / DESERT EDGE]     [MARINA / YACHT CLUB]
             [BEACH + PROMENADE + ROYAL SHIP]
                         SOUTH
```

## Required checks before any implementation

1. Reconcile proposed footprints against the actual terrain polygons and all existing roads.
2. Compute pairwise footprint distances; reject any overlap and any blocked entrance.
3. Check road widths, turning radii, parking, emergency access, pedestrian paths and vehicle collision.
4. Verify the Giza sightline and mountain/waterfront access in the production scene.
5. Generate rendered previews from the same production scene and inspect them with the founder.
6. Only after explicit approval of the coordinate map, create a separate implementation change and run Godot headless/runtime checks.

## Explicit non-actions

- No building coordinates have been changed by this proposal.
- No approved building or landmark has been deleted.
- PR #147 remains a separate open change and is not merged by this proposal.
- No production or main-branch merge is authorized.
