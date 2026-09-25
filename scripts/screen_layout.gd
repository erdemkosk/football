extends CanvasLayer
## Fill the output with 3D; center modal menus and anchor screen furniture to bounds().
const DESIGN_SIZE := Vector2(1440,900)

func _ready() -> void:
	get_viewport().size_changed.connect(refresh)
	refresh()

func refresh() -> void:
	offset=(get_viewport().get_visible_rect().size-DESIGN_SIZE)*.5
	for item in get_children():
		if item is CanvasItem: item.queue_redraw()

func bounds() -> Rect2:
	return Rect2(-offset,get_viewport().get_visible_rect().size)

func edge_offset(horizontal: int=0,vertical: int=0) -> Vector2:
	# Full-screen menus and broadcast furniture use actual output edges.
	var full := bounds()
	return Vector2(full.position.x if horizontal<0 else (full.end.x-DESIGN_SIZE.x if horizontal>0 else 0.0),full.position.y if vertical<0 else (full.end.y-DESIGN_SIZE.y if vertical>0 else 0.0))

func from_viewport(point: Vector2) -> Vector2:
	return transform.affine_inverse()*point
