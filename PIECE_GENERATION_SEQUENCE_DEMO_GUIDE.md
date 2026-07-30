# Piece Generation Sequence Demo Guide

`scenes/PieceGenerationSequenceDemo.tscn` is a standalone scene for watching one chunk being assembled placement by placement.

It was migrated from project 1's `PieceGenerationSequenceDemo.tscn`, but it has been adapted to the current project-2 piece world architecture. It uses the same 128px piece unit, 4 socket slots per chunk edge, global seam registry, and non-destructive seam repair rules as the main world.

## What the scene shows

The demo first generates a complete `PieceChunkData` with the current runtime generator, then reveals its `placements` array step by step.

Each step draws the next piece or generated glue into a temporary display image. The original generated chunk data is not mutated while stepping.

## Placement colors

Piece outlines use the same phase colors as the world debug overlay:

| Color | Phase | Meaning |
| --- | --- | --- |
| Red | `anchor` | Early high-value piece selected to establish the chunk layout. |
| Green | `regular` | Normal authored piece chosen by the generator. |
| Orange | `glue` | Generated glue piece used to fill remaining unit cells. |
| Bright red | `seam_repair` | Generated glue piece used to repair an edge slot without carving authored pieces. |
| White outline | Upcoming | The next placement that will be revealed. |

## Socket marker style

Socket markers match `WorldDebugDrawer`:

- Hollow outer ring = `Expected` / canonical socket from `WorldSeamRegistry`.
- Filled inner dot = `Actual` socket computed after piece placement and seam repair.
- Red edge strip = expected and actual socket differ at that edge slot.

The demo intentionally shows both profiles because socket bugs can happen at different layers:

- Expected wrong means the world/seam plan is wrong.
- Actual wrong means the selected piece or generated glue did not satisfy the canonical seam.
- Expected and actual match but the image looks wrong means a `PieceDef` socket declaration likely does not match its authored texture.

## Socket colors

| Character | Socket | Color | Meaning |
| --- | --- | --- | --- |
| `S` | `SOLID` | translucent gray/white | Closed edge. |
| `s` | `OPEN_SMALL` | green | Small passable opening. |
| `d` | `DOUBLE_OPEN_SMALL` | light blue | Two small openings or a split small opening. |
| `m` | `OPEN_MEDIUM` | teal | Medium connection. |
| `L` | `OPEN_LARGE` | yellow | Large opening. |
| `?` | `ANY` | white | Wildcard/debug socket. |

## HUD fields

The top label shows:

- `seed`: the seed used to generate the current chunk.
- `chunk`: chunk coordinate currently being demonstrated.
- `biome`: biome returned by the current `BiomeMap` / `WorldStructure` path.
- `type`: chunk type such as `main_path`, `cave`, `branch`, `chamber`, `special`, or `solid`.
- `structure`: structure tags attached to this chunk, or `fallback` if no `WorldStructure` node exists.
- `step`: current visible placement count over total placements.
- `next`: phase, id, unit position, and unit size of the next placement.
- `visible`: counts of phases already revealed.
- `planned`: counts of all phases in the completed generated chunk.
- `Expected T/R/B/L`: canonical socket profiles for top, right, bottom, and left.
- `Actual T/R/B/L`: actual generated socket profiles after placement and repair.
- `Seam`: repair and validation counters.

## Controls

| Input | Action |
| --- | --- |
| `SPACE` | Pause or resume autoplay. |
| `Right` | Reveal one placement. |
| `Left` | Step back one placement. |
| `Home` | Reveal all placements. |
| `Backspace` | Clear back to step 0. |
| `R` or `F3` | Regenerate with the current seed. |
| `F4` | Increment seed and regenerate. |
| `F5` | Decrement seed and regenerate. |
| `F2` | Toggle socket markers. |

## Important limitation

This scene is a sequence visualizer, not the main streamed world. It shows one generated chunk at a time and does not spawn neighboring chunks. To inspect cross-chunk seam validation, use the main `World.tscn` with `F1` and `F2` debug overlays.
