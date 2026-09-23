extends Control
## A single transparent overlay below the HUD; never captures controller or mouse input.
var game
var treatment := ShaderMaterial.new()

func _ready() -> void:
	name="ReplayFrame"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	focus_mode=Control.FOCUS_NONE
	treatment.shader=load("res://shaders/replay_frame.gdshader")
	material=treatment
	sync()

func _process(delta: float) -> void:
	game.replay.update_outro(delta)
	sync()

func sync() -> void:
	visible=(game.state=="replay" or game.replay.exit_left>0 and game.state in ["goal","restart","playing"]) and not game.match_menu.visible and not game.frontend.visible and not game.controls_help.visible and not game.training_menu.visible
	if not visible: return
	var full: Rect2=game.ui.bounds()
	position=full.position; size=full.size
	treatment.set_shader_parameter("frame_size",size)
	treatment.set_shader_parameter("bar_height",bar_height(size.y))
	treatment.set_shader_parameter("grain_frame",floorf(game.replay.age*24.0))
	treatment.set_shader_parameter("transition",game.replay.transition_alpha())
	treatment.set_shader_parameter("replay_amount",1.0 if game.state=="replay" else 0.0)
	queue_redraw()

static func bar_height(height: float) -> float: return clampf(height*.05,38,58)

func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color.WHITE)
