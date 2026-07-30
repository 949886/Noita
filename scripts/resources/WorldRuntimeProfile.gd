class_name WorldRuntimeProfile
extends Resource

# Runtime/streaming profile selected by WorldManager.
# Keep generation content in WorldGenConfig; keep platform/performance behavior here.
@export var id: StringName = &"pc"
@export var display_name: String = "PC"

@export var use_threaded_chunk_generation: bool = true
@export var use_threaded_special_generation: bool = true
@export_range(1, 4, 1) var load_radius: int = 2
@export_range(1, 8, 1) var main_thread_upload_budget_per_frame: int = 2

@export var keep_cpu_visual_images: bool = true
@export_range(1, 4, 1) var visual_texture_downscale_factor: int = 1
@export_range(0, 128, 1) var chunk_renderer_pool_limit: int = 64
@export_range(0, 128, 1) var special_renderer_pool_limit: int = 32

@export var debug_overlay_visible_on_start: bool = false
@export var world_debug_visible_on_start: bool = false
@export_range(0.05, 1.0, 0.05) var debug_update_interval: float = 0.20
@export_range(0.05, 1.0, 0.05) var world_debug_redraw_interval: float = 0.15

@export var show_world_debug_chunk_bounds: bool = true
@export var show_world_debug_socket_profiles: bool = true
@export var show_world_debug_chunk_labels: bool = true
@export var show_world_debug_piece_bounds: bool = true
