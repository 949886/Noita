# Runtime Profiles: PC vs Mobile

World generation content is still configured by `WorldGenConfig`:

- `resources/world_gen/default_world_gen_config.tres`
- biome resources
- special chunk resources
- piece library resources

Runtime performance behavior is now configured separately by `WorldRuntimeProfile` resources:

- `resources/runtime_profiles/pc_runtime_profile.tres`
- `resources/runtime_profiles/mobile_runtime_profile.tres`

This separation prevents mobile optimizations from silently changing the PC/editor experience.

## Selection

`WorldManager.runtime_profile_mode` controls which profile is used:

- `Auto`: use Mobile on Android/iOS/mobile exports, otherwise use PC.
- `PC`: always use `pc_runtime_profile`.
- `Mobile`: always use `mobile_runtime_profile`.
- `Custom`: use `custom_runtime_profile`.

The main `World.tscn` is set to `Auto` and references both bundled profile resources.

## PC profile defaults

`pc_runtime_profile.tres` favors quality and editor/debug usability:

- `load_radius = 2` for a 5 x 5 normal chunk window.
- `main_thread_upload_budget_per_frame = 2`.
- `visual_texture_downscale_factor = 1`, so 512 x 512 chunk visuals upload at full resolution.
- `keep_cpu_visual_images = true`, which keeps CPU visual images available for inspection and future editing systems.
- `chunk_renderer_pool_limit = 64`.
- `special_renderer_pool_limit = 32`.
- World debug draw options remain enabled in the profile, though the debug node still starts hidden.

## Mobile profile defaults

`mobile_runtime_profile.tres` favors stable frame pacing:

- `load_radius = 1` for a 3 x 3 normal chunk window.
- `main_thread_upload_budget_per_frame = 1`, shared between normal and special chunks.
- `visual_texture_downscale_factor = 2`, so 512 x 512 generated images upload as 256 x 256 textures and render back at world scale with nearest-neighbor filtering.
- `keep_cpu_visual_images = false`, so CPU visual images are released after texture upload.
- `chunk_renderer_pool_limit = 32`.
- `special_renderer_pool_limit = 16`.
- Debug HUD and world debug start hidden, and world-debug details are disabled by default.

## What belongs in a runtime profile

Put platform/performance settings here:

- chunk loading radius
- main-thread texture upload budget
- visual texture downscale
- whether CPU visual images are retained after upload
- renderer pool limits
- debug refresh/draw intervals
- default debug visibility and detail flags

Do not put content-generation rules here. Keep those in `WorldGenConfig`, biome configs, special chunk defs, and piece resources.

## Recommended workflow

For desktop development, leave `runtime_profile_mode = Auto`; in the editor/desktop run this selects PC.

To test mobile behavior on PC, set:

```gdscript
runtime_profile_mode = Mobile
```

To tune mobile without affecting PC, edit only:

```text
resources/runtime_profiles/mobile_runtime_profile.tres
```

To tune PC/editor without affecting mobile, edit only:

```text
resources/runtime_profiles/pc_runtime_profile.tres
```

## Debug HUD

The F1 HUD now shows the selected profile on the first line:

```text
Profile PC
Profile Mobile
```

It also shows:

- `Radius`: effective profile load radius.
- `Downscale`: visual texture downscale factor.
- `Pool`: current pooled normal chunk renderer count.
- `last gen/upload`: last worker generation time and texture uploads attached on the last frame.

If mobile still stutters, first verify that the HUD says `Profile Mobile` and `last gen/upload` usually ends with `/1`.
