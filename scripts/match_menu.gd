extends "res://scripts/menu_screen.gd"
var game
var content: VBoxContainer
var status: Label
var capture_action := -1
var capture_pad := false
var previous_freeze := false
var return_state := "menu"
var return_before_pause := "playing"
var page := 0
var navigation: Array[Button] = []
var config_path := "user://match_settings.cfg"
const ACTIONS := [KEY_S,KEY_Y,KEY_D,KEY_A,KEY_W,KEY_Q,KEY_X,KEY_G,KEY_E,KEY_Z,KEY_V]
const NAMES := ["Pas / pas iste","Ara pas / kaleci çağır","Şut / topsuz müdahale","Orta / topsuz kayma","Hızlı koş","Oyuncu seç","Kayarak müdahale","Ayakta müdahale","Top sakla / şutta falso","Kısa çalım","Topu ileri aç"]
var keys: Dictionary = {}
var scroll: ScrollContainer
var return_focus: Control
var save_button: Button
var fields: Array[Array] = []
var binding_header: Label

func _ready() -> void:
	setup_style()
	visible=false
	for i in range(4):
		var button := make_button(self,Rect2(54,251+i*80,258,62),["01   SES","02   KONTROLCÜ","03   TUŞ ATAMA","04   GÖRÜNTÜ & OYUN"][i],show_page.bind(i))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",15)
		navigation.append(button)
	scroll=ScrollContainer.new()
	scroll.position=Vector2(379,322)
	scroll.size=Vector2(969,409)
	scroll.follow_focus=true
	add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	scroll.add_child(content)
	status=Label.new()
	status.position=Vector2(55,816)
	status.size=Vector2(915,65)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color",MUTE)
	status.add_theme_font_size_override("font_size",14)
	add_child(status)
	save_button=make_button(self,Rect2(1060,817,326,62),"KAYDET & DÖN  →",close_menu,true)
	load_settings()
	game.controller.prompts_changed.connect(refresh_prompts)

func refresh_prompts() -> void:
	if page==2:
		if is_instance_valid(binding_header): binding_header.text=game.controller.family_label()
		for i in range(mini(ACTIONS.size(),fields.size())):
			if fields[i].size()==2 and is_instance_valid(fields[i][1]): binding_icon(fields[i][1],ACTIONS[i])
	queue_redraw()

func binding_icon(button: Button,action: int) -> void:
	button.icon=game.controller.icon_for(action)
	button.text="Atanmamış" if button.icon==null else ""
	button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width",30)
	button.custom_minimum_size.y=44
	button.tooltip_text=NAMES[ACTIONS.find(action)]+" · "+game.controller.family_label()

func pad_hint(items: Array) -> void:
	var hint=preload("res://scripts/controller_hint.gd").new()
	hint.controller=game.controller
	hint.items=items
	content.add_child(hint)

func _draw() -> void:
	backdrop("TAM SANA GÖRE.","Sesini, hissini ve kontrolünü kendine göre ayarla.",Brand.SHORT+"  /  AYARLAR")
	box(Rect2(341,231,1045,533),PANEL,10,Color("29464c"))
	text(["STADYUMUN SESİ","TOP SENİN KONTROLÜNDE","HER HAREKETİN BİR TUŞU VAR","SENİN MAÇ DENEYİMİN"][page],Vector2(379,280),24,PAPER,true)
	text(["Her katmanı ayrı ayarla.","Analog hareketini eline göre ayarla.","Bir hareket seç, ardından yeni tuşa bas.","Sahaya nasıl bakacağını seç."][page],Vector2(380,306),14,MUTE)
	text("SAHADA SEN VARSIN.",Vector2(55,704),16,GOLD,true)
	text("Her dokunuşu kendin belirle.",Vector2(55,730),13,MUTE)
	if status.text=="":
		if game.controller.using_gamepad:
			game.controller.Glyphs.draw_hints(self,Vector2(55,845),[["D-PAD","Gez"],["A","Seç"],["LB / RB","Bölüm"],["B","Kaydet ve dön"]],game.controller.family,font,27,13)
		else: text("YÖN TUŞLARI  Gez     ENTER  Seç     ESC  Kaydet ve dön",Vector2(55,850),14,MUTE)

func label(value: String) -> void:
	var text := Label.new()
	text.text=value
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text)

func option(title: String,values: Array,current: int,changed: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	content.add_child(row)
	var text := Label.new()
	text.text=title
	text.custom_minimum_size.x=300
	row.add_child(text)
	var field := OptionButton.new()
	field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for value in values: field.add_item(str(value))
	field.select(current)
	field.item_selected.connect(changed)
	field.get_popup().window_input.connect(game.controller.menus.popup_input.bind(field))
	field.get_popup().popup_hide.connect(func():
		game.controller.menus.popup_option=null
		if field.is_visible_in_tree(): field.grab_focus())
	row.add_child(field)
	fields.append([field])
	return field

func slider(title: String,value: float,low: float,high: float,changed: Callable) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var text := Label.new()
	text.text=title
	text.custom_minimum_size.x=300
	row.add_child(text)
	row.custom_minimum_size.y=57
	var field := HSlider.new()
	field.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	field.custom_minimum_size.y=26
	field.min_value=low; field.max_value=high; field.step=0.01; field.value=value
	field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(field)
	fields.append([field])
	var number := Label.new()
	number.custom_minimum_size.x=65
	number.text="%d%%" % roundi(value*100)
	row.add_child(number)
	field.value_changed.connect(func(v): number.text="%d%%" % roundi(v*100); changed.call(v))

func show_page(index: int) -> void:
	page=clampi(index,0,3)
	capture_action=-1
	fields.clear()
	for i in range(navigation.size()): navigation[i].modulate=GOLD if i==page else Color.WHITE
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	scroll.scroll_vertical=0
	match page:
		0:
			slider("Stadyum ambiyansı",game.audio.stadium_volume,0,1,func(v): game.audio.stadium_volume=v)
			slider("Alkış & tezahürat",game.audio.cheer_volume,0,1,func(v): game.audio.cheer_volume=v)
			slider("Tribün davulları",game.audio.drum_volume,0,1,func(v): game.audio.drum_volume=v)
			option("Tüm sesler",["Kapalı","Açık"],int(not game.audio.muted),func(v):
				if game.audio.muted==(v==1): game.audio.toggle())
			label("Stadyum, alkış ve davul birbirinden bağımsız çalar. Maça döndüğünde yeni ses dengesi uygulanır.")
		1:
			slider("Analog hassasiyeti",game.controller.sensitivity,0.6,1.8,func(v): game.controller.sensitivity=v)
			slider("Analog ölü bölge",game.controller.deadzone,0.08,0.35,func(v): game.controller.deadzone=v)
			option("Kontrolcü titreşimi",["Kapalı","Açık"],int(game.controller.vibration),func(v): game.controller.vibration=v==1)
			pad_hint([[game.controller.label_for(KEY_D),"Şut / ayakta müdahale"],[game.controller.label_for(KEY_A),"Orta / kayma"]])
			pad_hint([[game.controller.label_for(KEY_S),"Pas"],[game.controller.label_for(KEY_Y),"Ara pas / kaleciyi çıkar"]])
			pad_hint([[game.controller.label_for(KEY_W),"Hızlı koş"],[game.controller.label_for(KEY_Q),"Oyuncu seç"],["LB + X","Aşırtma"]])
			pad_hint([["B × 2","Yerden sert orta"],["LB + Y","Havadan uzun pas"]])
			pad_hint([["LB + A","Verkaç"],[game.controller.label_for(KEY_E),"Top koruma / falso"]])
			pad_hint([[game.controller.label_for(KEY_G),"Ayakta müdahale"],[game.controller.label_for(KEY_V),"Topu aç"]])
			pad_hint([["START","Mola"],["VIEW","Kadro & taktik"]])
		2:
			var header := HBoxContainer.new()
			content.add_child(header)
			for title in ["HAREKET","KLAVYE",game.controller.family_label()]:
				var heading := Label.new()
				heading.text=title
				if title=="HAREKET": heading.custom_minimum_size.x=300
				else:
					heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
					heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				header.add_child(heading)
				binding_header=heading
			for i in range(ACTIONS.size()):
				var buttons: Array = []
				var row := HBoxContainer.new(); content.add_child(row)
				var caption := Label.new(); caption.text=NAMES[i]; caption.custom_minimum_size.x=300; row.add_child(caption)
				for pad in [false,true]:
					var button := Button.new(); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
					if pad: binding_icon(button,ACTIONS[i])
					else: button.text=OS.get_keycode_string(key_for(ACTIONS[i]))
					button.pressed.connect(func(): capture_action=ACTIONS[i]; capture_pad=pad; status.text="Yeni kontrolcü tuşuna bas…  ·  Menü / geri tuşu veya Esc: iptal" if pad else "Yeni klavye tuşuna bas…  ·  Geri tuşu veya Esc: iptal"; queue_redraw())
					row.add_child(button)
					buttons.append(button)
				fields.append(buttons)
			var reset := Button.new(); reset.text="Varsayılan tuşlara dön"; content.add_child(reset)
			fields.append([reset])
			reset.pressed.connect(func(): keys.clear(); game.controller.reset_bindings(); show_page(2); fields.back()[0].grab_focus())
		3:
			option("Ekran modu",["Pencere","Tam ekran"],int(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN),func(v): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v==1 else DisplayServer.WINDOW_MODE_WINDOWED))
			option("FPS göstergesi",["Kapalı","Açık"],int(game.performance_hud.visible),func(v): game.performance_hud.visible=v==1)
			option("Gol tekrarları",["Kapalı","Açık"],int(game.replay.enabled),func(v): game.replay.enabled=v==1)
			option("Rakip zorluğu",["Kolay","Normal","Zor"],game.management.difficulty,func(v): game.management.difficulty=v)
			option("Pas yardımı",["Manuel","Yarı yardımlı","Yardımlı"],game.pass_assistance,func(v): game.pass_assistance=v)
			label("Pas yardımı, seçtiğin yöne göre hedefi ve gücü dengeler. Koşu yoluna pasla arkadaşını boşluğa kaçır; topa rakipler de müdahale edebilir.")
			pad_hint([["A","Gol tekrarını geç (klavye: Space / Enter)"]])
	wire_navigation()
	navigation[page].grab_focus()
	queue_redraw()

func wire_navigation() -> void:
	for i in range(navigation.size()):
		var button := navigation[i]
		button.focus_neighbor_top=button.get_path_to(navigation[i-1] if i>0 else save_button)
		button.focus_neighbor_bottom=button.get_path_to(navigation[i+1] if i<3 else save_button)
		button.focus_neighbor_right=button.get_path_to(fields[0][0])
	for i in range(fields.size()):
		for j in range(fields[i].size()):
			var field: Control=fields[i][j]
			field.focus_entered.connect(func(): reveal_field.call_deferred(field))
			field.focus_neighbor_top=field.get_path_to(fields[i-1][mini(j,fields[i-1].size()-1)] if i>0 else navigation[page])
			field.focus_neighbor_bottom=field.get_path_to(fields[i+1][mini(j,fields[i+1].size()-1)] if i<fields.size()-1 else save_button)
			field.focus_neighbor_left=field.get_path_to(fields[i][j-1] if j>0 else navigation[page])
			field.focus_neighbor_right=field.get_path_to(fields[i][j+1] if j<fields[i].size()-1 else navigation[page])
	save_button.focus_neighbor_top=save_button.get_path_to(fields.back()[0])
	save_button.focus_neighbor_left=save_button.get_path_to(navigation[page])
	save_button.focus_neighbor_bottom=save_button.get_path_to(navigation[0])

func reveal_field(field: Control) -> void:
	# Rebuilding a page can invalidate an earlier deferred focus notification.
	if is_instance_valid(field) and scroll.is_ancestor_of(field) and field.has_focus():
		scroll.ensure_control_visible(field)

func open_menu() -> void:
	if visible: close_menu(); return
	return_state=game.state
	return_before_pause=game.before_pause
	previous_freeze=game.ball.freeze
	return_focus=get_viewport().gui_get_focus_owner()
	if game.state!="paused": game.before_pause=game.state
	game.state="paused"
	game.ball.freeze=true
	game.charging=false; game.charge=0; game.cancel_pass()
	game.goalkeeping.stop_rush()
	game.set_pieces.button=0; game.set_pieces.power=0
	game.controller.held.clear()
	visible=true
	status.text=""
	show_page(page)

func close_menu() -> void:
	if not visible: return
	if is_instance_valid(game.controller.menus.popup_option): game.controller.menus.popup_option.get_popup().hide()
	capture_action=-1
	visible=false
	save_settings()
	game.state=return_state
	game.before_pause=return_before_pause
	game.ball.freeze=previous_freeze
	game.controller.held.clear()
	game.hud.sync_navigation()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree(): return_focus.grab_focus()
	elif game.frontend.visible: game.frontend.first_focus.grab_focus()

func key_for(action: int) -> int:
	for code in keys:
		if keys[code]==action: return int(code)
	return action

func handle(event: InputEvent) -> void:
	if capture_action>=0:
		if event is InputEventJoypadButton and event.pressed and (event.button_index in [JOY_BUTTON_BACK,JOY_BUTTON_START] or (not capture_pad and event.button_index==JOY_BUTTON_B)):
			capture_action=-1; status.text="Atama iptal edildi."; get_viewport().set_input_as_handled(); return
		var code := -1
		if event is InputEventKey and event.pressed:
			if event.keycode==KEY_ESCAPE: capture_action=-1; status.text="Atama iptal edildi."; get_viewport().set_input_as_handled(); return
			if not capture_pad: code=event.physical_keycode if event.physical_keycode else event.keycode
		elif capture_pad and event is InputEventJoypadButton and event.pressed: code=event.button_index
		elif capture_pad and event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT] and event.axis_value>0.65: code=100+event.axis
		if code<0: return
		if (not capture_pad and (code not in range(KEY_A,KEY_Z+1) or code in [KEY_P,KEY_K,KEY_C,KEY_M,KEY_H,KEY_F,KEY_T,KEY_R])) or (capture_pad and code in [JOY_BUTTON_START,JOY_BUTTON_BACK,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]):
			status.text="Klavye için A–Z seç; menü, geri ve yön tuşları menüye ayrılmıştır."; get_viewport().set_input_as_handled(); return
		if capture_pad: game.controller.rebind(capture_action,code)
		else:
			var previous := key_for(capture_action)
			var displaced: int=keys.get(code,code)
			keys[previous]=displaced; keys[code]=capture_action
		var row := ACTIONS.find(capture_action)
		var column := int(capture_pad)
		capture_action=-1
		status.text="Tuş atandı."
		show_page(2)
		fields[row][column].grab_focus()
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_P]) or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_BACK,JOY_BUTTON_START,JOY_BUTTON_B]):
		close_menu(); get_viewport().set_input_as_handled()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for name in ["formation","mentality","pressing","line_height","difficulty"]: cfg.set_value("tactics",name,game.management.get(name))
	for name in ["stadium_volume","cheer_volume","drum_volume"]: cfg.set_value("audio",name,game.audio.get(name))
	for name in ["sensitivity","deadzone","vibration","bindings"]: cfg.set_value("pad",name,game.controller.get(name))
	cfg.set_value("pad","bindings_version",2)
	cfg.set_value("input","keys",keys)
	cfg.set_value("match","replay",game.replay.enabled)
	cfg.set_value("match","pass_assistance",game.pass_assistance)
	cfg.set_value("display","fullscreen",DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN)
	cfg.set_value("display","fps",game.performance_hud.visible)
	cfg.set_value("audio","muted",game.audio.muted)
	var error := cfg.save(config_path)
	if error!=OK: game.announce("Ayarlar bu oturumda uygulandı; diske kaydedilemedi.")

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path)!=OK:
		# Keep the player's controls/audio preferences when the game is renamed.
		if config_path!="user://match_settings.cfg" or FileAccess.file_exists(config_path): return
		var previous := OS.get_data_dir().path_join("Godot/app_userdata/TOUCHLINE/match_settings.cfg")
		if cfg.load(previous)!=OK: return
	for name in ["formation","mentality","pressing","line_height","difficulty"]: game.management.set(name,clampi(int(cfg.get_value("tactics",name,game.management.get(name))),0,2))
	for name in ["stadium_volume","cheer_volume","drum_volume"]: game.audio.set(name,clampf(float(cfg.get_value("audio",name,1.0)),0,1))
	game.controller.sensitivity=clampf(float(cfg.get_value("pad","sensitivity",1.0)),0.6,1.8)
	game.controller.deadzone=clampf(float(cfg.get_value("pad","deadzone",0.18)),0.08,0.35)
	game.controller.vibration=bool(cfg.get_value("pad","vibration",true))
	var bindings: Variant=cfg.get_value("pad","bindings",{})
	if bindings is Dictionary:
		var valid: Dictionary={}
		for button in bindings:
			if bindings[button] in ACTIONS and int(button) in [0,1,2,3,7,8,9,10,104,105]: valid[int(button)]=int(bindings[button])
		var complete := valid.size()==10
		var seen: Array=[]
		for action in valid.values():
			if action in seen: complete=false
			seen.append(action)
		if complete: game.controller.bindings=valid
	# Older saves used Y for feint; migrate once to the new requested layout.
	if int(cfg.get_value("pad","bindings_version",1))<2: game.controller.rebind(KEY_Y,JOY_BUTTON_Y)
	var stored: Variant=cfg.get_value("input","keys",{})
	if stored is Dictionary:
		for code in stored:
			if int(code)>=KEY_A and int(code)<=KEY_Z and int(code)!=KEY_K and stored[code]!=KEY_K and stored[code] in range(KEY_A,KEY_Z+1): keys[int(code)]=int(stored[code])
	game.replay.enabled=bool(cfg.get_value("match","replay",true))
	game.pass_assistance=clampi(int(cfg.get_value("match","pass_assistance",1)),0,2)
	game.performance_hud.visible=bool(cfg.get_value("display","fps",false))
	if bool(cfg.get_value("audio","muted",false))!=game.audio.muted: game.audio.toggle()
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(cfg.get_value("display","fullscreen",false)) else DisplayServer.WINDOW_MODE_WINDOWED)
	game.management.apply_formation()
