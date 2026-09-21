extends Control
var controller
var items: Array = []
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(0,34)
	controller.prompts_changed.connect(queue_redraw)
func _draw() -> void:
	controller.Glyphs.draw_hints(self,Vector2(0,17),items,controller.family,get_theme_default_font(),28,14)
