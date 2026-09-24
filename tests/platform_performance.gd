extends "res://tests/performance_benchmark.gd"
## Run the same file on Windows and macOS, from the same project revision.
## The inherited benchmark sets 1440x900, VSync off and uncapped real rendering.
func run() -> void:
	print("PLATFORM ",JSON.stringify({
		"os":OS.get_name(),
		"cpu":OS.get_processor_name(),
		"logical_processors":OS.get_processor_count(),
		"engine":Engine.get_version_info().string,
		"debug_build":OS.is_debug_build(),
		"gpu":RenderingServer.get_video_adapter_name(),
		"renderer":RenderingServer.get_current_rendering_method(),
		"display":DisplayServer.get_name(),
		"initial_vsync":DisplayServer.window_get_vsync_mode(),
		"initial_fps_limit":Engine.max_fps,
		"physics_hz":Engine.physics_ticks_per_second
	}))
	await super.run()
