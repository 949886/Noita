# Noita-style Wang Tile World Demo — SpecialChunk iteration

This Godot 4.7 demo explores a Noita-inspired large-world generator built from chunked Wang tiles. This version focuses on authored **SpecialChunks**: chunk-sized or multi-chunk `PackedScene` structures that coexist with procedurally generated Wang chunks.

## What changed in this iteration

- Renamed SpecialRoom terminology to **SpecialChunk** across scripts, resources, paths, and config fields.
- Added direction-aware transition rows to the `special_chunk_atlas` to soften the seam between authored chunks and natural Wang chunks.
- Updated demo SpecialChunks to use transition border tiles around their edges.
- Added a snow-biome SpecialChunk: `SnowShrineChunk`.
- Added comments to the core generation, atlas, streaming, AirPocket, and SpecialChunk scripts.

## Main systems

- `WorldManager` streams normal chunks and skips chunks occupied by SpecialChunks.
- `WorldGenerator` keeps using Wang Tile generation for ordinary chunks.
- `EdgeProfile` makes deterministic seam profiles and lets SpecialChunk edge profiles override neighboring edges.
- `SpecialChunkPlanner` deterministically places authored chunks from the world seed.
- `SpecialChunkManager` loads/unloads each SpecialChunk placement once, even for multi-chunk structures.
- `SpecialChunkNode` is the base scene node for editable SpecialChunk scenes.

## Included SpecialChunks

- `MineTreasureChunk.tscn` — 1x1 mine treasure structure.
- `AncientHall2x1Chunk.tscn` — 2x1 multi-chunk hall.
- `SnowShrineChunk.tscn` — 1x1 snow shrine structure.

Resources live here:

```text
res://resources/special_chunks/
├─ mine_treasure_chunk.tres
├─ ancient_hall_2x1_chunk.tres
└─ snow_shrine_chunk.tres
```

Scenes live here:

```text
res://scenes/special_chunks/
├─ MineTreasureChunk.tscn
├─ AncientHall2x1Chunk.tscn
└─ SnowShrineChunk.tscn
```

## SpecialChunk atlas

`special_chunk_atlas.png` is source ID `10` in `generated_tileset.tres`.

```text
row 0  = wall
row 1  = floor
row 2  = platform
row 3  = door
row 4  = pillar
row 5  = background
row 6  = decoration
row 7  = transition_top
row 8  = transition_right
row 9  = transition_bottom
row 10 = transition_left
row 11 = debug
```

The transition rows are the current solution for the seam problem. SpecialChunk scenes paint a one-tile transition border around their outer edge so the jump from cave rock/snow/deep material into authored architecture is less abrupt. The EdgeProfile system still controls where openings align; direction-aware transition tiles solve the visual-material mismatch.

## Editing SpecialChunks

Open one of the scenes under `res://scenes/special_chunks/`, select the `Ground` `TileMapLayer`, and paint using `generated_tileset.tres`, source ID `10`.

`SpecialChunkNode` only synchronizes the TileSet at runtime and updates labels/markers. It will not overwrite authored cells. The demo bootstrap fills the layer only when it is empty, so the examples remain visible after resource regeneration.

To make a chunk fully hand-authored, paint the `Ground` layer and optionally disable `populate_demo_layout_if_empty`.

## Editor tool

Use:

```text
Project > Tools > Generate Noita World Resources
```

The tool regenerates:

- biome atlases
- `special_chunk_atlas.png`
- `TileAtlasDef` resources
- `generated_tileset.tres`
- `WorldGenConfig.tres`
- default SpecialChunk resource definitions

## Controls

```text
WASD / Arrow keys: move
+ / -: zoom
```

## Notes

- The seam fix in this version is intentionally content-driven: SpecialChunks own their transition border. A later version can add procedural transition chunks around authored structures if needed.
- SpecialChunks are planned before chunk generation, so streaming order does not change placement.
- The project has not been run in this environment with the Godot editor; report any parse or resource-load errors and they can be fixed in the next iteration.

## 2026-07 Transition direction update

SpecialChunk transition tiles are now direction-aware. The `special_chunk_atlas` uses these rows:

```text
row 0  = wall
row 1  = floor
row 2  = platform
row 3  = door
row 4  = pillar
row 5  = background
row 6  = decoration
row 7  = transition_top
row 8  = transition_right
row 9  = transition_bottom
row 10 = transition_left
row 11 = debug
```

Transition columns are shared by all four direction rows:

```text
col 0 = rock wall
col 1 = snow wall
col 2 = deep wall
col 3 = ruins wall
col 4 = rock door
col 5 = snow door
col 6 = deep door
col 7 = ruins door
```

`SpecialChunkDef.transition_style` chooses the style family. `SpecialChunkNode` can auto-fill empty border cells from the chunk edge profiles; it skips corners and never overwrites hand-authored cells.

## 2026-07 Edge v2 + AirPocketPass update

Normal biome Wang tiles now use **Edge v2**:

```text
S = SOLID  wall/material edge
O = OPEN   normal cave opening
A = AIR    full empty-space tile
```

`NARROW` was removed for now to keep the resource set small and predictable. AIR is deliberately limited to a single signature:

```text
AAAA
```

Biome atlas layout is now:

```text
row 0-15 = original S/O Wang signatures
row 16   = AAAA air tile
row 17   = fallback/debug
```

AIR does **not** participate in ordinary chunk outer edge profiles. `EdgeProfile` still generates only SOLID/OPEN for chunk-to-chunk seams, which keeps streaming seams stable. Instead, `WorldGenerator` runs an `AirPocketPass` after the normal S/O tile grid is generated. The pass finds internal `OOOO` areas and upgrades clustered cells to `AAAA`, producing larger cave pockets without introducing partial AIR signatures such as `SAAS` or `AOOA`.

Matching now uses:

```text
1. exact edge match
2. compatible edge match
3. fallback tile
```

Compatibility is intentionally simple:

```text
SOLID only connects to SOLID
OPEN connects to OPEN or AIR
AIR connects to AIR or OPEN
```

The debug overlay now shows loaded `Air tiles` and `Compatible matches` to help tune pocket frequency. Snow chunks currently have the highest AirPocket chance, so snow caves should feel more open than mine/deep areas.

## 2026-07-14 iteration: tile polish, stronger air pockets, and connectivity

This version addresses the feedback pass after Edge v2:

- Biome atlas tiles no longer have semi-transparent outer borders. The dark edge shading is now fully opaque, so TileMap cells should not show a transparent fringe between neighboring tiles.
- `SSSS` is now a truly solid tile. The generator no longer carves the default center cave hole for fully solid signatures.
- `AirPocketPass` is stronger and supports a wider shape library: `1x1`, `1x2`, `2x1`, `2x2`, `1x3`, `3x1`, `2x3`, `3x2`, plus `2x4`, `4x2`, and `3x3` in more open contexts such as snow and main path chunks.
- AIR still only uses the single `AAAA` signature and still avoids the outer chunk border. This keeps chunk-to-chunk seams deterministic while allowing bigger interior empty spaces.
- Edge profiles now use wider opening segments and an edge-level connectivity pass. Higher-openness edges are guaranteed to receive readable openings, which should reduce dead ends and make main/cave routes more connected.
- Default biome openness values were increased. Snow is intentionally the most open biome, followed by mine, then deep.

If the map becomes too open while testing, tune the values in `BiomeConfig` resources or in `WorldGenResourceExporter._apply_default_biome_depths_and_chances()`.

### Tile atlas seam note

The generated biome atlas no longer applies a universal outline, border shade, or transparent padding around each 64x64 tile. Terrain pixels and carved air regions extend directly to the tile boundary so adjacent TileMap cells can stitch together without visible per-tile seams.

## Debug & Stability pass

This version adds the first debugging/stability layer for the chunked world generator.

### Runtime debug controls

- `F1` toggles the modern debug HUD.
- `F2` toggles world-space debug drawing.
- `F3` regenerates the current world with the same seed.
- `F4` advances the seed by one and regenerates the world.

### Debug HUD

The HUD now shows grouped information:

- world seed, loaded chunk count, load radius, current chunk
- current biome and chunk type
- top/right/bottom/left edge profiles
- exact/compatible/fallback tile match counts
- AIR tile and air pocket counts
- SpecialChunk info when the current chunk is occupied by an authored SpecialChunk

### World debug drawing

`WorldDebugDrawer` renders chunk bounds, chunk labels, and edge-profile markers directly in the world.
This helps diagnose disconnected caves, dead ends, SpecialChunk overrides, and fallback-heavy areas.

### Resource validation

The editor plugin now includes:

`Project > Tools > Validate Noita World Resources`

It checks the main `WorldGenConfig`, biome atlas row counts, the `AAAA` AIR row, TileSet source IDs, and basic SpecialChunk scene/profile data.

## WorldStructureBuilder v1

This build adds a chunk-level structure layer before Wang tile generation:

- A deterministic vertical `main_path` is generated from the seed.
- Side `branch` chunks extend from the main path and may loop back.
- Procedural `chamber` chunks create larger cave regions while still using biome Wang tiles.
- Each structure node stores intended top/right/bottom/left connections.
- `EdgeProfile` now respects those intended connections before applying random openness, so macro paths are easier to follow and dead ends are reduced.
- `AirPocketPass` gives chamber chunks higher AIR pocket probability and larger pocket shapes.

Debug HUD / world debug labels now show structure tags such as `main_path`, `branch`, `loop_branch`, `branch_end`, `chamber`, and `chamber_connector`.

The current structure range is intentionally finite for debugging:

```text
x = -16..16
y = 0..96
```

Outside that range, the older fallback biome/chunk-type logic is still used.


## ChamberCarvePass v1

Chambers are no longer just tagged cave chunks. Each chamber placement now stores `chamber_id`, `chamber_origin`, and `chamber_size`, so 2x1 / 1x2 / 2x2 chambers can be carved as one continuous macro-room.

Generation now applies a dedicated ChamberCarvePass before AirPocketPass:

- chamber outer border stays controlled by EdgeProfile, so outside seams remain stable;
- chamber inner ring is pushed toward `OOOO` to form a readable cave wall;
- chamber core is mostly `AAAA`, with some `OOOO` left as natural mass;
- internal seams between chunks in the same chamber use a wide `SOOOOOOS` profile.

Debug labels now show chamber id, size, origin, and carve counts (`A` for air tiles and `O` for open tiles), making it easier to verify whether a region is actually being carved as a chamber.

## ChunkConnectivityCarvePass v1

This build adds a local connectivity carve pass for normal generated chunks.

EdgeProfile already guarantees that two neighboring chunks agree on border `OPEN` cells, but a chunk could still have unreachable entrances inside its own tile grid. `ChunkConnectivityCarvePass` fixes that at the signature-grid level:

- it groups border openings by side (`top`, `right`, `bottom`, `left`);
- if two or more different sides have openings, it chooses one representative entrance per side;
- it carves each representative entrance to a small internal hub using `OOOO` tiles;
- main-path and chamber chunks carve a wider 2x2 stamped route, while cave/solid/branch chunks carve a narrow route;
- existing `AAAA` air tiles are preserved because they are already walkable.

This means a chunk with openings on different sides should now contain at least one internal route between those sides. A single-side open chunk can still remain a dead end by design.

Debug HUD / world labels now include connectivity path statistics, so you can see whether a loaded chunk range is being repaired by the pass.

## ChunkConnectivityCarvePass v2: MST route carving

This build replaces the v1 center-hub connectivity repair with a lightweight MST-style route graph.

The old pass connected every side entrance to one internal hub and stamped `OOOO` along the path. That guaranteed reachability, but it often produced artificial plus-shaped / cross-shaped tunnel patterns.

The v2 pass now:

- chooses one representative entrance per open side, same as before;
- builds a small nearest-neighbor spanning tree between those representatives instead of using a fixed center hub;
- carves biased wandering paths between tree edges, so routes can bend and drift instead of always forming strict L-shapes;
- writes direction-aware signatures such as horizontal corridors, vertical corridors, and corners instead of converting every carved tile to `OOOO`;
- keeps existing `AAAA` air tiles intact;
- merges required path openings with the tile's existing openings, so the pass opens only what is needed and avoids closing previously valid cave connections.

The goal is unchanged: if a chunk has openings on two or more different sides, those sides should be locally reachable. The visual result should be less grid-like than v1 and should produce fewer obvious cross structures inside ordinary cave/solid chunks.
