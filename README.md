# Noita-style Wang Tile World Demo — SpecialChunk iteration

This Godot 4.7 demo explores a Noita-inspired large-world generator built from chunked Wang tiles. This version focuses on authored **SpecialChunks**: chunk-sized or multi-chunk `PackedScene` structures that coexist with procedurally generated Wang chunks.

## What changed in this iteration

- Renamed SpecialRoom terminology to **SpecialChunk** across scripts, resources, paths, and config fields.
- Added a `transition` row to the `special_chunk_atlas` to soften the seam between authored chunks and natural Wang chunks.
- Updated demo SpecialChunks to use transition border tiles around their edges.
- Added a snow-biome SpecialChunk: `SnowShrineChunk`.
- Added comments to the core generation, atlas, streaming, and SpecialChunk scripts.

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
