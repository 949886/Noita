# Noita Piece World Demo

This project is the migrated version of the original TileMapLayer world prototype.
The runtime terrain generation path now uses 128px **Piece** units instead of
64px TileMap cells.

## What changed

- Removed the TileMapLayer runtime generation pipeline.
- Migrated the Piece/PieceSocket/PieceLibrary/PieceChunk generation stack.
- Kept project 2's macro world structure, biome planning, special-chunk planning,
  player controller, HUD, and world debug drawer.
- Replaced legacy 8-point edge profiles with 4 PieceSocket slots per chunk edge.
- Special chunks are planned by `SpecialChunkPlanner` but rendered by
  `SpecialPieceRenderer` instead of TileMap scenes.
- Project 1 debug/demo scripts were intentionally not copied; debugging is handled
  by `scripts/debug/DebugOverlay.gd` and `scripts/debug/WorldDebugDrawer.gd`.

## Runtime controls

- `WASD` / arrow keys: move player camera anchor
- `+` / `-`: zoom
- `F1`: toggle HUD
- `F2`: toggle world debug overlay
- `F3`: regenerate same seed
- `F4`: advance seed and regenerate

## Socket model

`PieceSocket.Socket` now only contains boundary-connection shapes:

```text
SOLID, OPEN_SMALL, DOUBLE_OPEN_SMALL, OPEN_MEDIUM, OPEN_LARGE, ANY
```

The old `ROOM` and `SHAFT` socket variants were removed because no piece or special-chunk resource used them as edge socket values. Room/lab/cave identity still exists through `PieceDef.kind` and piece tags such as `room`, `lab`, and `cave_room`.

## Main files

- `scenes/World.tscn` — main scene
- `scripts/world/WorldManager.gd` — streaming coordinator
- `scripts/piece_world/PieceChunkGenerator.gd` — piece-based chunk generation
- `scripts/world/SocketProfilePlanner.gd` — socket seam planner, 4 slots per edge
- `scripts/special/SpecialPieceRenderer.gd` — image-based special chunks
- `resources/pieces/piece_library.tres` — migrated piece library

## Debug guide

See [`DEBUG_OVERLAY_GUIDE.md`](DEBUG_OVERLAY_GUIDE.md) for a detailed explanation of the F1 HUD, F2 world debug drawer, socket marker shapes, and color meanings.

## Piece generation sequence demo

A standalone adapted sequence visualizer is available at:

```text
scenes/PieceGenerationSequenceDemo.tscn
```

It was migrated from project 1 but now uses the current piece-world generator, 128px units, 4 socket slots per edge, `WorldSeamRegistry`, and non-destructive seam repair. See `PIECE_GENERATION_SEQUENCE_DEMO_GUIDE.md` for controls and how to read the expected/actual socket markers.
