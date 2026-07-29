# Piece World Migration Notes

This project is the migrated version of `noita-tilemap` using the piece-based generation stack from `noita`.

## What changed

- Removed the runtime TileMap/TileSet/TileDef generation path.
- Migrated the piece model, generated piece definitions, piece textures, material palette, glue generator, and image chunk renderer.
- Replaced the old 64px-by-8 edge profile concept with four 128px `PieceSocket` slots per chunk side.
- Retained and adapted the second project's debug HUD and world debug drawer:
  - socket letters per edge: `S`, `s`, `d`, `m`, `L`, `R`, `H`, `?`
  - piece bounds, glue placements, chamber/special metadata, and special chunk outlines
- Reworked special chunks to be image-based `SpecialPieceRenderer` nodes instead of TileMap scenes.
- Updated `World.tscn` to run through `WorldManager -> PieceChunkGenerator -> PieceChunkRenderer`.

## Important controls

- WASD / Arrow keys: move the player camera anchor
- `F1`: toggle debug HUD
- `F2`: toggle world debug drawing
- `F3`: regenerate with the same seed
- `F4`: advance seed and regenerate

## Validation performed in this environment

- Checked that all non-cache `res://` references in `.gd`, `.tres`, `.tscn`, `.cfg`, and `.godot` files resolve.
- Checked for duplicate `class_name` declarations.
- Checked that deleted project-1 debug/demo classes are not referenced.
- Checked that legacy runtime TileMap class references are removed from scripts/scenes/resources, with only comments/documentation mentioning the old approach.
- Checked special chunk socket profiles have the expected 4-slot-per-chunk-edge lengths.

Godot CLI was not available in this container, so the editor/runtime launch itself could not be executed here. On first open, Godot may regenerate `.import` cache files for PNG/SVG resources.
