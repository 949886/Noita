# Piece World Migration Notes

This project is the migrated version of `noita-tilemap` using the piece-based generation stack from `noita`.

## What changed

- Removed the runtime TileMap/TileSet/TileDef generation path.
- Migrated the piece model, generated piece definitions, piece textures, material palette, glue generator, and image chunk renderer.
- Replaced the old 64px-by-8 edge profile concept with four 128px `PieceSocket` slots per chunk side.
- Retained and adapted the second project's debug HUD and world debug drawer:
  - socket letters per edge: `S`, `s`, `d`, `m`, `L`, `?`
  - piece bounds, glue placements, chamber/special metadata, and special chunk outlines
- Reworked special chunks to be image-based `SpecialPieceRenderer` nodes instead of TileMap scenes.
- Updated `World.tscn` to run through `WorldManager -> PieceChunkGenerator -> PieceChunkRenderer`.


## Socket enum cleanup

- Removed unused semantic socket variants `ROOM` and `SHAFT` from `PieceSocket.Socket`.
- Existing piece/socket resources only used numeric socket values `0..4` (`SOLID` through `OPEN_LARGE`), so serialized piece edge data is preserved.
- `ROOM` still exists as `PieceDef.PieceKind.ROOM`, and `room` remains a normal piece tag. The cleanup only removes room/shaft as boundary socket shapes.
- Chamber-internal seams now use `OPEN_LARGE` for broad passage intent instead of a separate `ROOM` socket.

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

## 2026-07-30 Seam hardening pass

This pass fixes the open-vs-solid chunk-border problem at the root instead of relying on soft compatibility scoring.

### Added

- `scripts/world/WorldSeamRegistry.gd`
  - Stores one authoritative profile per world seam.
  - `chunk(x-1,y).right` and `chunk(x,y).left` now read the same cached vertical seam.
  - `chunk(x,y-1).bottom` and `chunk(x,y).top` now read the same cached horizontal seam.
  - Canonicalizes `ANY` sockets into concrete `OPEN_MEDIUM` sockets so world seams are never ambiguous.

- `scripts/piece_world/ChunkSeamValidator.gd`
  - Checks expected-vs-actual chunk profiles.
  - Checks loaded neighbor actual-vs-actual profiles.
  - Reports exact, compatible, and broken counts for debug HUD/world debug.

### Changed

- `PieceChunkGenerator.gd`
  - Uses `WorldSeamRegistry` as the only source of external chunk profiles.
  - Treats chunk boundary sockets as exact hard constraints during regular piece placement.
  - Computes `actual_*_profile` after placement.
  - Runs a deterministic seam-repair pass: any boundary unit whose actual socket does not equal the canonical seam is replaced by a 128px `seam_repair_glue` unit.
  - Recomputes actual profiles and seam status after repair.
  - Fixed glue normalization so boundary sockets are treated as fixed and are never normalized from open to solid.

- `PieceChunkData.gd`
  - Added `actual_top/right/bottom/left_profile`.
  - Added seam repair/status counters.
  - `placement_at_unit()` now searches newest placement first, so seam repair overlays take precedence over earlier multi-unit pieces.

- `DebugOverlay.gd`
  - Shows expected and actual socket profiles separately.
  - Shows seam repair count and expected/neighbor broken seam counts.

- `WorldDebugDrawer.gd`
  - Draws expected and actual socket markers separately.
  - Highlights any expected-vs-actual mismatch in red.
  - Shows seam repairs in red in the piece-boundary overlay.

### Result

Normal streamed chunks now satisfy this invariant:

```text
for each loaded non-special neighbor seam:
    left_chunk.actual_right_profile == right_chunk.actual_left_profile
    upper_chunk.actual_bottom_profile == lower_chunk.actual_top_profile
```

Special chunks still render through `SpecialPieceRenderer`; their external profiles feed the same `WorldSeamRegistry` override path, and neighboring normal chunks are repaired against that canonical profile.

Additional visual/material hardening:

- `PieceChunkGenerator` now enforces boundary pixels after seam repair:
  - open sockets are carved through `visual_image` and `material_image` at the canonical slot position;
  - solid sockets seal an 8px border strip with biome rock color.
- This catches the case where a `PieceDef` declares a matching socket but the source image edge was authored incorrectly.

## 2026-07-30 Seam visual preservation hotfix

The previous seam-fixed build enforced canonical sockets by carving/sealing final
chunk edge pixels. That protected seams but was too destructive for authored
prefab pieces: a predefined piece placed on an open seam could receive a large
forced edge tunnel.

This hotfix keeps the long-term seam architecture but changes the enforcement
rules:

- `WorldSeamRegistry` remains the single canonical source for chunk-edge sockets.
- Chunk boundary placement remains an exact logical socket constraint.
- `_enforce_boundary_pixels()` was removed from the generation path.
- Authored prefab images are no longer carved, sealed, or overwritten to satisfy
  a seam.
- Seam repair is non-destructive: only empty/generated-glue boundary units may be
  replaced by `seam_repair_glue`.
- If an authored piece somehow violates the logical seam contract, the issue is
  reported in `seam_repairs` with `repair_mode = authored_piece_not_modified`
  instead of mutating the art.

This separates the generator contract from art correction: socket mismatch is
handled by selection/registry/repair logic, while piece art remains under author
control.

## 2026-07-30 Debug marker clarity pass

The world-space socket overlay has been updated to make expected-vs-actual seam debugging easier to read:

- Each socket slot now uses one combined marker instead of two separated dots.
- Hollow outer ring = expected/canonical socket from `WorldSeamRegistry`.
- Filled inner dot = actual socket produced by the placed piece/glue.
- A red translucent strip still marks `expected != actual`.
- The F1 HUD help text now includes the marker legend.
- Added `DEBUG_OVERLAY_GUIDE.md` with detailed explanations for the HUD, socket characters, marker shapes, color meanings, chunk colors, piece phase colors, and recommended debugging workflow.

This is a visual/debug-only change. It does not modify seam planning, piece selection, or generated chunk data.


## 2026-07-30 Debug marker uniform-size pass

The world-space socket marker style has been refined again for readability:

- Expected/canonical socket is drawn as a hollow outer ring.
- Actual/generated socket is drawn as a filled inner dot.
- Marker sizes are now fixed across all socket types. Size no longer encodes socket class.
- Socket type is encoded only by color and by the F1 HUD socket characters.
- `DEBUG_OVERLAY_GUIDE.md` now explicitly documents marker shape, size rules, socket colors, chunk colors, piece phase colors, and the recommended seam debugging workflow.

This is a debug-visual-only change. It does not alter generation, seam registry data, piece selection, or repair behavior.

## PieceGenerationSequenceDemo migrated and adapted

This version restores project 1's `PieceGenerationSequenceDemo.tscn` as a standalone diagnostic scene, but it no longer depends on project 1's old debug stack.

New files:

- `scenes/PieceGenerationSequenceDemo.tscn`
- `scripts/piece_world/PieceGenerationSequenceDemo.gd`
- `PIECE_GENERATION_SEQUENCE_DEMO_GUIDE.md`

Adaptation details:

- Uses the current migrated `PieceChunkGenerator` instead of the original project 1 generator interface.
- Uses `WorldGenConfig`, `WorldStructureBuilder`, `SpecialChunkPlanner`, and the current `WorldSeamRegistry` path when `build_world_structure` is enabled.
- Uses `PieceWorldConstants.UNIT_SIZE = 128` and `PieceWorldConstants.CHUNK_UNITS = 4`.
- Shows current canonical/expected socket profiles and generated/actual socket profiles using the same marker language as `WorldDebugDrawer`:
  - Expected = hollow outer ring.
  - Actual = filled inner dot.
  - Red edge strip = expected/actual mismatch.
- Shows phase colors consistent with the world debug overlay:
  - red = anchor
  - green = regular
  - orange = glue
  - bright red = seam_repair
- Supports stepping backward by rebuilding the visible image up to the requested step. This keeps the demo deterministic without mutating the generator output.
- Does not restore `PieceDebugOverlay`, `PiecePlayer`, or project 1's old runtime debug/demo stack.

Controls:

- `SPACE`: pause/play
- `Right`: step forward
- `Left`: step backward
- `Home`: show all placements
- `Backspace`: clear back to step 0
- `R` or `F3`: restart current seed
- `F4`: increment seed and restart
- `F5`: decrement seed and restart
- `F2`: toggle socket markers

## 2026-07-31 threaded streaming refactor

Added a two-stage threaded streaming architecture to reduce movement stutter when crossing chunk boundaries.

### Added

- `scripts/piece_world/ChunkGenerationWorker.gd`
- `scripts/special/SpecialChunkImageWorker.gd`
- `scripts/special/SpecialPieceImageBuilder.gd`
- `THREADING_STREAMING_GUIDE.md`

### Changed

- `WorldManager.gd` now queues missing chunks instead of synchronously generating every chunk in the current load radius.
- `PieceChunkGenerator.generate_chunk(coord, create_texture)` can now generate chunk data/images without creating an `ImageTexture`.
- `PieceChunkRenderer.gd` creates the `ImageTexture` on the main thread when attaching a completed chunk.
- `PieceLibrary.prepare()` now pre-caches piece `Image` data through `PieceDef.prepare_image_cache()`.
- `SpecialChunkManager.gd` can queue special chunk image generation through a background worker.
- `SpecialPieceRenderer.gd` only performs Node/Texture setup; image construction moved to `SpecialPieceImageBuilder`.
- `DebugOverlay.gd` now displays pending/worker queue stats.
- `WorldDebugDrawer.gd` redraws at a throttled interval instead of every frame.

### Threading boundary

Background threads now perform CPU-heavy `Image` generation and composition. Main thread remains responsible for:

- scene-tree mutation
- renderer node creation
- `ImageTexture.create_from_image()`
- `Sprite2D` texture assignment
- debug UI update

This avoids unsafe scene-tree access from worker threads while moving the expensive chunk calculation off the movement frame.


## 2026-07-31 mobile performance pass

Added a mobile-oriented streaming optimization pass on top of threaded chunk generation.

### Changed

- Mobile performance behavior is now provided by `resources/runtime_profiles/mobile_runtime_profile.tres`.
- PC/editor behavior is provided by `resources/runtime_profiles/pc_runtime_profile.tres`.
- Normal chunk and special chunk uploads share one main-thread upload budget.
- The Mobile profile sets `main_thread_upload_budget_per_frame = 1`; the PC profile sets it to `2`.
- F1/F2 debug UI starts hidden in `World.tscn`; profile resources control startup visibility and draw detail defaults.
- `DebugOverlay` no longer builds snapshots while hidden.
- `PieceChunkRenderer` supports CPU `visual_image` release after `ImageTexture` upload.
- `PieceChunkRenderer` and `SpecialPieceRenderer` now support visual texture downscaling before upload.
- The Mobile profile sets `visual_texture_downscale_factor = 2`, uploading 256 x 256 chunk textures while preserving 512 x 512 world size via nearest-neighbor sprite scale. The PC profile keeps full-resolution visuals with downscale factor `1`.
- Normal chunk renderers are pooled instead of being freed/recreated on every unload/load cycle.
- Special chunk renderers are also pooled.
- Added `MOBILE_PERFORMANCE_GUIDE.md` and `RUNTIME_PROFILES_GUIDE.md`.

### Important limitation

`ImageTexture.create_from_image()` still runs on the main thread because texture upload and scene-tree attachment are rendering/main-thread operations. This pass reduces upload size and caps uploads per frame, but it does not remove the upload cost entirely.

## Platform runtime profiles

This version separates PC and Mobile performance behavior into two `WorldRuntimeProfile` resources:

- `resources/runtime_profiles/pc_runtime_profile.tres`
- `resources/runtime_profiles/mobile_runtime_profile.tres`

`WorldManager.runtime_profile_mode` now controls profile selection:

- `Auto`: Mobile on Android/iOS/mobile exports, PC elsewhere.
- `PC`: force PC profile.
- `Mobile`: force Mobile profile.
- `Custom`: use `custom_runtime_profile`.

The older direct mobile overrides (`mobile_performance_mode`, `mobile_load_radius`, and `mobile_visual_texture_downscale_factor`) were removed from `WorldManager`. Runtime/platform choices are now data-driven through the two profile resources, while generation content remains in `WorldGenConfig`.
