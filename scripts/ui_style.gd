extends RefCounted
## Shared palette and component geometry for every football screen.
const INK=Color("09151c")
const PANEL=Color("142a35")
const PAPER=Color("f3f5ed")
const MUTE=Color("a8bac5")
const ACCENT=Color("d6f77a")
const GOLD=Color("e9ce87")
const LINE=Color("304852")
const BLUE=Color("7acde3")
const RED=Color("efa18f")
const RADIUS=10

static func surface(color: Color=PANEL,border: Color=Color.TRANSPARENT,radius: int=RADIUS) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new(); s.bg_color=color; s.set_corner_radius_all(radius)
	if border.a>0: s.border_color=border; s.set_border_width_all(1)
	return s

static func club_tint(data: Dictionary) -> Color:
	var primary:=Color(data.get("primary","334a53"))
	return primary.lerp(BLUE,.45) if primary.get_luminance()<.15 else primary

static func fit(canvas,font: Font,value: String,at: Vector2,width: float,size: int,color: Color) -> void:
	while size>12 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width: size-=1
	canvas.draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)
