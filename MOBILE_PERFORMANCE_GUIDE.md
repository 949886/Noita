# Mobile Performance Guide

Mobile settings now live in a separate runtime profile resource:

```text
resources/runtime_profiles/mobile_runtime_profile.tres
```

The PC/editor settings live in:

```text
resources/runtime_profiles/pc_runtime_profile.tres
```

`WorldManager.runtime_profile_mode = Auto` selects Mobile on Android/iOS/mobile exports and PC elsewhere. You can force either profile from the World scene for testing.

## Mobile defaults

The bundled Mobile profile applies these runtime choices:

- `load_radius = 1`, so normal chunks are usually kept in a 3 x 3 window.
- `main_thread_upload_budget_per_frame = 1`, shared by normal and special chunks.
- `visual_texture_downscale_factor = 2`, so generated 512 x 512 visuals upload as 256 x 256 textures and are displayed at full world size with nearest-neighbor scaling.
- `keep_cpu_visual_images = false`, so CPU visual images are released after upload.
- `chunk_renderer_pool_limit = 32` and `special_renderer_pool_limit = 16`.
- Debug HUD and world debug start hidden.
- World debug draw details are disabled by default in the Mobile profile.

These choices target stable frame pacing. They do not change the material image resolution or the logical chunk size.

## PC defaults

The bundled PC profile keeps full visual quality:

- `load_radius = 2`.
- `main_thread_upload_budget_per_frame = 2`.
- `visual_texture_downscale_factor = 1`.
- `keep_cpu_visual_images = true`.
- Larger renderer pools.
- Debug detail flags remain enabled, though the debug nodes still start hidden.

## Most important mobile knobs

### 1. Upload budget

Texture upload is still a main-thread/GPU operation. For mobile, keep:

```text
main_thread_upload_budget_per_frame = 1
```

If you raise it, chunk pop-in may reduce, but frame spikes may return.

### 2. Visual downscale

For best performance:

```text
visual_texture_downscale_factor = 2
```

For sharper visuals but heavier uploads:

```text
visual_texture_downscale_factor = 1
```

A factor of `2` cuts visual texture upload size to roughly one quarter.

### 3. Load radius

For mobile, start with:

```text
load_radius = 1
```

If the world appears too late at the screen edge, raise it to `2`, but expect higher memory and upload pressure.

### 4. CPU visual images

For mobile, keep:

```text
keep_cpu_visual_images = false
```

`material_image` remains available for future material/collision systems. Only the CPU copy of the rendered visual image is released after texture upload.

## Debug tips

Use F1 only while profiling. The first line now includes:

```text
Profile Mobile
```

Check:

- `Downscale`: should usually be `2x` on mobile.
- `Radius`: should usually be `1` on mobile.
- `last gen/upload`: upload count should usually be `0` or `1`.

If F2 world debug is enabled on a mobile device, expect additional draw cost. Keep it off during gameplay tests.
