# Noita Piece World Prototype

This project is a parallel rewrite/prototype for a Noita-like world generator that does **not** use TileMap as the primary world representation.

The new pipeline is:

```text
PieceDef / generated prefab pieces
→ PieceChunkGenerator
→ 512x512 chunk Image
→ ImageTexture
→ PieceChunkRenderer streaming
```

## Main scene

Open:

```text
res://scenes/PieceWorld.tscn
```

Controls:

```text
WASD / Arrow keys = move
F1 = toggle chunk/piece debug outlines
F3 = regenerate current seed
F4 = seed +1 and regenerate
```

## Important constants

```text
UNIT_SIZE = 128
CHUNK_UNITS = 4
CHUNK_SIZE = 512
```

Supported piece sizes in this first prototype:

```text
128x128 = 1x1 unit
256x128 = 2x1 units
128x256 = 1x2 units
256x256 = 2x2 units
```

## Generated test piece library

The project already includes generated placeholder pieces under:

```text
res://resources/generated_pieces/textures/
res://resources/generated_pieces/defs/
```

It also includes the three uploaded sample pieces as PieceDefs:

```text
laboratory.png
symbolroom_alt.png
oiltank_1.png
```

There is an editor plugin:

```text
Project > Tools > Generate Test Piece Library
```

Enable `addons/piece_world_tools` in Project Settings > Plugins to use it. It regenerates placeholder PNGs and PieceDef resources for testing.

## Architecture notes

This prototype keeps the earlier TileMap/Wang-tile work conceptually useful, but the new world renderer is chunk-image based. Glue pieces are generated procedurally when no authored piece fills a 128x128 unit. This is the intended path toward a future pixel/material simulation layer.

## 2026-07-16 piece generator fix: slot-correct openings

This build fixes the first feedback pass for the piece-world prototype.

### Editor tools

The plugin is now enabled in `project.godot` by default:

```text
res://addons/piece_world_tools/plugin.cfg
```

After opening the project, the following menu items should appear under **Project > Tools**:

```text
Generate Test Piece Library
Validate Piece Library
```

`Generate Test Piece Library` deletes and regenerates `res://resources/generated_pieces/textures` and `res://resources/generated_pieces/defs`.

### Slot-correct piece generation

Piece openings are now carved per 128 px edge slot. For example, a `128x256` piece with:

```text
right_slots = [open_medium, open_small]
```

now gets two separate right-edge openings:

```text
slot 0 center: y = 64   -> medium opening
slot 1 center: y = 192  -> small opening
```

The generator no longer treats an entire multi-slot edge as one centered opening.

### Validation

`Validate Piece Library` checks:

```text
texture exists
size_px == size_units * 128
top/bottom slot count == size_units.x
left/right slot count == size_units.y
```

This catches the most common PieceDef/image metadata mismatches before testing streaming.

## 2026-07-16 socket upgrade: double_open_small

This build adds a new socket:

```text
double_open_small
```

Meaning:

```text
one 128 px edge slot contains two small openings
opening centers are approximately at 1/4 and 3/4 of the slot
```

For a vertical edge slot this means local y positions:

```text
32 px and 96 px
```

For a horizontal edge slot this means local x positions:

```text
32 px and 96 px
```

The generator and glue generator now use socket opening patterns instead of assuming one socket equals one opening. Examples:

```text
open_small        -> one small opening at 0.50
double_open_small -> two small openings at 0.25 and 0.75
open_medium       -> one medium opening at 0.50
open_large        -> one large opening at 0.50
```

`Validate Piece Library` now also checks generated pieces for edge opening counts, including `double_open_small` expecting two separate edge openings.

## Patch: blit image format fix

`PieceChunkGenerator._paste_piece_texture()` now duplicates, decompresses when needed, and converts source piece images to the target chunk image format before `Image.blit_rect()`. This prevents Godot's `format != p_src->format` blit error when imported PNGs use a different internal image format.


## Piece fill pipeline update

Chunk generation now uses a three-phase fill pipeline:

1. Anchor pieces are placed first for the chunk type.
2. Regular non-glue pieces are repeatedly placed using a global best-first search until no legal regular piece can fit.
3. Programmatic glue pieces are generated only for the remaining empty 128x128 units.

The size bonus treats all multi-unit pieces equally: `2x1`, `1x2`, and `2x2` receive the same bonus. Glue is now a final fallback instead of the main filler.

## Piece generation sequence demo

Open:

```text
res://scenes/PieceGenerationSequenceDemo.tscn
```

This scene visualizes one chunk being assembled over time. It uses the same `PieceChunkGenerator` placement order, but starts from an empty 512x512 image and pastes placements one by one:

```text
Anchor pieces -> Regular pieces -> Glue fallback pieces
```

Controls:

```text
Space = pause / play
Right Arrow = step one placement
R or F3 = restart same seed
F4 = seed +1 and restart
```

Debug colors:

```text
red = anchor piece
green = regular piece
orange = glue piece
white = next placement
```

## Debug overlay and piece boundary colors

Runtime chunk debug lines represent placement boundaries, not collision or material boundaries.

Color legend:

```text
cyan       chunk boundary
red        anchor piece (first structural placements)
green      regular piece (best-first fill stage)
orange     glue fallback piece (final gap filling stage)
```

The outlines are intended for understanding generation order and piece coverage. They are not the final rendered world boundary.

Debug hotkeys are edge-triggered:

```text
F1 toggle debug outlines
F3 regenerate current seed
F4 next seed and regenerate
```

Holding a key no longer repeatedly toggles/regenerates every frame.

## Biome vertical order

Current prototype layer order:

```text
lower layer: mine
above layer: snow
higher layer: deep
```

The first generated underground layer now starts as mine before transitioning upward into snow.
