extends Control
var game
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; focus_mode=Control.FOCUS_NONE
func _process(_delta: float) -> void:
	visible=game.pace.alpha()>0 and game.state!="paused"
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color(0.025,.05,.055,game.pace.alpha()))
