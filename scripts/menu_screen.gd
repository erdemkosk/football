extends Control
const UI=preload("res://scripts/ui_style.gd")
const Brand = preload("res://scripts/branding.gd")
## Shared typography and restrained stadium-broadcast styling.
const INK := UI.INK
const PANEL := UI.PANEL
const PAPER := UI.PAPER
const GOLD := UI.ACCENT
const MUTE := UI.MUTE
var font := SystemFont.new()
var bold := SystemFont.new()
var prompt_controller

func setup_style() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	prompt_controller=get("game").controller
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font.font_names=PackedStringArray(["Avenir Next","DejaVu Sans"])
	bold.font_names=font.font_names
	bold.font_weight=700
	var skin := Theme.new()
	skin.default_font=font
	skin.default_font_size=17
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color=Color("152a35") if state=="normal" else Color("29404c")
			style.set_corner_radius_all(10)
			style.content_margin_left=16; style.content_margin_right=16
			style.content_margin_top=9; style.content_margin_bottom=9
			if state=="focus":
				style.bg_color=Color.TRANSPARENT
				style.set_border_width_all(2); style.border_color=GOLD
				style.set_expand_margin_all(3)
			skin.set_stylebox(state,type,style)
		skin.set_color("font_color",type,PAPER)
		skin.set_color("font_focus_color",type,GOLD)
		skin.set_color("font_disabled_color",type,Color("637a7e"))
	var bar := StyleBoxFlat.new()
	bar.bg_color=Color("2c484e"); bar.set_corner_radius_all(3)
	bar.content_margin_top=3; bar.content_margin_bottom=3
	skin.set_stylebox("slider","HSlider",bar)
	var fill := bar.duplicate(); fill.bg_color=GOLD
	skin.set_stylebox("grabber_area","HSlider",fill)
	skin.set_stylebox("grabber_area_highlight","HSlider",fill)
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([GOLD,Color(GOLD,0)])
	gradient.offsets=PackedFloat32Array([0.82,1.0])
	var knob := GradientTexture2D.new()
	knob.width=18; knob.height=18; knob.gradient=gradient
	knob.fill=GradientTexture2D.FILL_RADIAL
	knob.fill_from=Vector2(0.5,0.5); knob.fill_to=Vector2(1,0.5)
	skin.set_icon("grabber","HSlider",knob)
	skin.set_icon("grabber_highlight","HSlider",knob)
	var focus_bar := StyleBoxFlat.new()
	focus_bar.bg_color=Color.TRANSPARENT
	focus_bar.border_color=GOLD
	focus_bar.set_border_width_all(2)
	focus_bar.set_corner_radius_all(5)
	focus_bar.set_expand_margin_all(5)
	skin.set_stylebox("focus","HSlider",focus_bar)
	var popup_panel := StyleBoxFlat.new()
	popup_panel.bg_color=PANEL
	popup_panel.border_color=Color("476367")
	popup_panel.set_border_width_all(1)
	popup_panel.set_corner_radius_all(6)
	popup_panel.content_margin_top=8; popup_panel.content_margin_bottom=8
	skin.set_stylebox("panel","PopupMenu",popup_panel)
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color=Color("36514c")
	popup_hover.set_corner_radius_all(4)
	skin.set_stylebox("hover","PopupMenu",popup_hover)
	skin.set_color("font_color","PopupMenu",PAPER)
	skin.set_color("font_hover_color","PopupMenu",GOLD)
	theme=skin

func box(rect: Rect2,color: Color=PANEL,radius: int=8,border: Color=Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	if border.a>0: style.set_border_width_all(1); style.border_color=border
	draw_style_box(style,rect)

func text(value: String,at: Vector2,size: int=16,color: Color=PAPER,strong: bool=false) -> void:
	size=maxi(12,size)
	draw_string(bold if strong else font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center(value: String,at: Vector2,size: int=16,color: Color=PAPER,strong: bool=false) -> void:
	var f: Font=bold if strong else font
	var width := f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	draw_string(f,at-Vector2(width/2,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func backdrop(title: String,subtitle: String,step: String) -> void:
	draw_rect(get("game").ui.bounds(),Color(0.025,0.065,0.08,1.0))
	for i in range(24):
		draw_line(Vector2(770+i*38,0),Vector2(340+i*38,900),Color(0.16,0.3,0.32,0.08),1)
	draw_texture_rect(Brand.CREST,Rect2(48,25,60,60),false)
	text(Brand.TITLE,Vector2(123,53),19,PAPER,true)
	text("S E F C   /   1 1 ' E  1 1  F U T B O L",Vector2(125,76),9,GOLD)
	text(step,Vector2(1050,59),12,GOLD,true)
	draw_line(Vector2(54,102),Vector2(1386,102),Color("284249"),1)
	text(title,Vector2(54,165),42,PAPER,true)
	text(subtitle,Vector2(56,198),15,MUTE)
	draw_line(Vector2(54,797),Vector2(1386,797),Color("284249"),1)
	if prompt_controller.using_gamepad:
		prompt_controller.Glyphs.draw_hints(self,Vector2(56,779),[["LS / D-PAD","Gez"],["A","Seç"],["B","Geri"]],prompt_controller.family,font,24,10)
	else: text("YÖN TUŞLARI  GEZ     ENTER  SEÇ     ESC  GERİ",Vector2(56,786),10,MUTE)

func make_button(parent: Node,rect: Rect2,value: String,callback: Callable,primary: bool=false) -> Button:
	var button := Button.new()
	button.position=rect.position; button.size=rect.size
	button.text=value
	button.pressed.connect(callback)
	parent.add_child(button)
	if primary:
		for state in ["normal","hover","pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color=GOLD.lightened(0.12) if state=="hover" else GOLD
			style.set_corner_radius_all(UI.RADIUS)
			button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_color",INK)
		button.add_theme_color_override("font_hover_color",INK)
		button.add_theme_color_override("font_focus_color",INK)
		button.add_theme_color_override("font_pressed_color",INK)
	return button

func badge(at: Vector2,data: Dictionary,scale_value: float=1.0) -> void:
	var graphics=preload("res://scripts/kit_graphics.gd")
	var id: int=int(data.get("badge_id",graphics.SHORTS.find(data.short)))
	var texture: Texture2D=graphics.badge(id,Color(data.primary),Color(data.accent))
	draw_texture_rect(texture,Rect2(at-Vector2(34,34)*scale_value,Vector2(68,68)*scale_value),false)
