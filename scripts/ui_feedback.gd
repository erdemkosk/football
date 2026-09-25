extends Control
const Style=preload("res://scripts/ui_style.gd")
var game
var target: Control
var rect:=Rect2()
var origin:=Rect2()
var goal:=Rect2()
var age:=1.0
var context:=""
var sound: AudioStreamPlayer
var clips: Dictionary={}
var cooldown:=0.0
var pulse:=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; focus_mode=Control.FOCUS_NONE
	sound=AudioStreamPlayer.new(); add_child(sound)
	for kind in ["move","confirm","error"]: clips[kind]=tone(kind)
	get_tree().node_added.connect(watch)
	bind_tree(game)

func bind_tree(node: Node) -> void:
	watch(node)
	for child in node.get_children(): bind_tree(child)

func watch(node: Node) -> void:
	if not node is Control or node.has_meta("ui_feedback"): return
	if node is BaseButton:
		node.set_meta("ui_feedback",true)
		node.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		if node is OptionButton: node.item_selected.connect(func(_v): cue("confirm"))
		node.focus_entered.connect(func(): cue("move"))
		node.pressed.connect(func(): pulse=.12; cue("confirm"))
	elif node is Range:
		node.set_meta("ui_feedback",true)
		node.value_changed.connect(func(_v): if node.is_visible_in_tree() and node.has_focus(): cue("move"))

func cue(kind: String) -> void:
	if not is_instance_valid(game.audio) or game.audio.muted or not game.experience.ui_sounds: return
	if kind=="move" and cooldown>0: return
	cooldown=.055
	sound.stream=clips[kind]; sound.volume_db=-22 if kind=="move" else -18; sound.play()

func tone(kind: String) -> AudioStreamWAV:
	var length:=.045 if kind=="move" else .10
	var bytes:=PackedByteArray(); var samples:=int(22050*length); bytes.resize(samples*2)
	for i in range(samples):
		var t:=float(i)/22050
		var hz:=660.0 if kind=="move" else (880.0 if kind=="confirm" else 180.0)
		var v:=sin(TAU*hz*t)*sin(PI*i/samples)*.35
		if kind=="confirm": v+=sin(TAU*1320*t)*sin(PI*i/samples)*.12
		bytes.encode_s16(i*2,int(v*32767))
	var stream:=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=22050; stream.data=bytes
	return stream

func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta); pulse=maxf(0,pulse-delta)
	if (game.audio.muted or not game.experience.ui_sounds) and sound.playing: sound.stop()
	var focused:=get_viewport().gui_get_focus_owner()
	visible=is_instance_valid(focused) and focused.is_visible_in_tree() and game.controller.menus.screen()!=""
	if not visible: target=null; return
	var next: Rect2=Rect2(get_global_transform_with_canvas().affine_inverse()*focused.get_global_transform_with_canvas().origin,focused.size*focused.get_global_transform_with_canvas().get_scale()/get_global_transform_with_canvas().get_scale()).grow(3)
	var screen: String=game.controller.menus.screen()
	if focused!=target or not goal.is_equal_approx(next):
		# Animate navigation between controls; follow the same control immediately
		# when resizing or scrolling moves its actual screen position.
		origin=rect if focused!=target and is_instance_valid(target) and context==screen else next
		goal=next; age=0; target=focused; context=screen
	age=minf(.14,age+delta)
	rect=goal if game.experience.reduce_motion else Rect2(origin.position.lerp(goal.position,smoothstep(0,.14,age)),origin.size.lerp(goal.size,smoothstep(0,.14,age)))
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(target): return
	var style:=Style.surface(Color(Style.ACCENT,.05 if pulse>0 else 0),Color(Style.ACCENT,.9))
	style.set_border_width_all(2)
	draw_style_box(style,rect)
