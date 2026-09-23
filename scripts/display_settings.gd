extends Node
## Keep the menu's logical coordinates independent of the output resolution.
signal changed
const WINDOW_PRESETS := [Vector2i(960,600),Vector2i(1280,720),Vector2i(1280,800),Vector2i(1366,768),Vector2i(1440,900),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(1920,1200),Vector2i(2560,1440),Vector2i(2560,1600),Vector2i(3440,1440),Vector2i(3840,2160)]
var fullscreen := true
var resolution := Vector2i.ZERO # Zero means automatic; never save a detected size as a preference.
var native_size := Vector2i(1920,1080)
var work_area := Rect2i(0,0,1920,1080)
var screen := -1
var window: Window
var applying := false
var poll_age := 0.0

func _ready() -> void:
	window=get_tree().root
	fullscreen=window.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]
	refresh_screen()
	window.size_changed.connect(on_window_resized)

static func fit_size(value: Vector2i,limit: Vector2i) -> Vector2i:
	var ratio := minf(1.0,minf(float(limit.x)/maxi(1,value.x),float(limit.y)/maxi(1,value.y)))
	return Vector2i(maxi(1,floori(value.x*ratio)),maxi(1,floori(value.y*ratio)))

func refresh_screen() -> bool:
	if DisplayServer.get_name()=="headless": return false
	var next_screen := DisplayServer.window_get_current_screen()
	var next_size := DisplayServer.screen_get_size(next_screen)
	var next_area := DisplayServer.screen_get_usable_rect(next_screen)
	if next_size.x<=0 or next_size.y<=0: return false
	if next_area.size.x<=0 or next_area.size.y<=0: next_area=Rect2i(DisplayServer.screen_get_position(next_screen),next_size)
	var different := screen!=next_screen or native_size!=next_size or work_area!=next_area
	screen=next_screen; native_size=next_size; work_area=next_area
	return different

func _process(delta: float) -> void:
	poll_age+=delta
	if poll_age<.5: return
	poll_age=0
	if refresh_screen(): apply()

func window_limit() -> Vector2i:
	# Leave room for the title bar, borders and the taskbar on this monitor.
	return Vector2i(maxi(1,work_area.size.x-32),maxi(1,work_area.size.y-64))

func automatic_size() -> Vector2i:
	return native_size if fullscreen else fit_size(native_size,Vector2i(Vector2(window_limit())*.9))

func normalized(value: Vector2i) -> Vector2i:
	if value==Vector2i.ZERO: return value
	var limit := native_size if fullscreen else window_limit()
	if value.x<640 or value.y<360 or value.x>limit.x or value.y>limit.y: return Vector2i.ZERO
	# Fullscreen preserves the monitor's aspect ratio. Offer actual 3D buffer sizes.
	if not fullscreen: return value
	var height := mini(value.y,roundi(float(value.x)*native_size.y/native_size.x))
	return Vector2i(roundi(float(native_size.x)*height/native_size.y),height)

func available_resolutions() -> Array[Vector2i]:
	var values: Array[Vector2i]=[Vector2i.ZERO]
	if fullscreen:
		for height in [600,720,800,900,1080,1200,1440,1600,1800,2160]:
			if height>=native_size.y: continue
			var value := Vector2i(roundi(float(native_size.x)*height/native_size.y),height)
			if value.x>=640 and value not in values: values.append(value)
		values.append(native_size)
	else:
		for value in WINDOW_PRESETS:
			if normalized(value)==value: values.append(value)
	if resolution!=Vector2i.ZERO and resolution not in values: values.append(resolution)
	values.sort_custom(func(a,b): return a.x*a.y<b.x*b.y)
	return values

static func size_label(value: Vector2i) -> String:
	return "%d × %d" % [value.x,value.y]

func resolution_labels() -> Array:
	var labels: Array=[]
	for value in available_resolutions():
		labels.append("Otomatik · "+size_label(automatic_size()) if value==Vector2i.ZERO else size_label(value))
	return labels

func select_resolution(value: Vector2i) -> void:
	resolution=normalized(value)
	apply()

func set_fullscreen(value: bool) -> void:
	fullscreen=value
	apply()

func apply() -> void:
	if window==null: return
	applying=true
	refresh_screen()
	resolution=normalized(resolution)
	if DisplayServer.get_name()!="headless":
		window.mode=Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if not fullscreen:
			window.size=automatic_size() if resolution==Vector2i.ZERO else resolution
			window.position=work_area.position+(work_area.size-window.size)/2
	applying=false
	apply_render_size()
	# Fullscreen/window transitions can finish after the OS resize notification.
	apply_render_size.call_deferred()
	changed.emit()

func render_size() -> Vector2i:
	var output := window.size if window!=null else native_size
	return output if not fullscreen or resolution==Vector2i.ZERO else fit_size(output,resolution)

func apply_render_size() -> void:
	if window==null: return
	var output := window.size
	var target := render_size()
	window.scaling_3d_scale=clampf(minf(float(target.x)/maxi(1,output.x),float(target.y)/maxi(1,output.y)),.1,1.0)

func on_window_resized() -> void:
	if applying: return
	# A user resize is a new window preference; automatic stays automatic.
	if not fullscreen and resolution!=Vector2i.ZERO: resolution=normalized(window.size)
	apply_render_size()
	changed.emit()

func load_config(cfg: ConfigFile) -> void:
	fullscreen=bool(cfg.get_value("display","fullscreen",fullscreen))
	var stored: Variant=cfg.get_value("display","resolution",Vector2i.ZERO)
	resolution=stored if stored is Vector2i else Vector2i.ZERO
	apply()

func save_config(cfg: ConfigFile) -> void:
	cfg.set_value("display","fullscreen",fullscreen)
	cfg.set_value("display","resolution",resolution)
