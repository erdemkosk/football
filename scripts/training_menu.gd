extends "res://scripts/menu_screen.gd"
var game
var selected := 0
var cards: Array[Button] = []
var start_button: Button
var back_button: Button
var return_state := "menu"
var return_freeze := false
var return_focus: Control
const DESCRIPTIONS := [
	["ON BİR OYUNCU.","Kendi takımın sahada; oto seçim maçtaki gibi.","Pas ver, kontrol değişir, kaleciye karşı oyna."],
	["ORTAYA HAREKETLEN.","Takım arkadaşın sırayla iki kanattan orta açar.","Yerini al, şut tuşuyla kafa vur veya kontrol et."],
	["BARAJI AŞ.","Yön tuşlarıyla noktayı seç, A ile oradan vur.","Yön, güç ve falsoyu birlikte dene."]]

func _ready() -> void:
	setup_style(); hide()
	for i in range(3):
		var card := make_button(self,Rect2(54+i*450,246,432,444),"",choose.bind(i))
		for state in ["normal","hover","pressed"]: card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		card.focus_entered.connect(choose.bind(i))
		cards.append(card)
	back_button=make_button(self,Rect2(54,818,220,60),"← Geri",close_menu)
	start_button=make_button(self,Rect2(1050,818,336,60),"ANTRENMANA BAŞLA  →",start,true)
	for i in range(3):
		cards[i].focus_neighbor_left=cards[i].get_path_to(cards[posmod(i-1,3)])
		cards[i].focus_neighbor_right=cards[i].get_path_to(cards[(i+1)%3])
		cards[i].focus_neighbor_bottom=cards[i].get_path_to(start_button)
		cards[i].focus_neighbor_top=cards[i].get_path_to(back_button)
	start_button.focus_neighbor_left=start_button.get_path_to(back_button)
	back_button.focus_neighbor_right=back_button.get_path_to(start_button)
	game.controller.prompts_changed.connect(queue_redraw)

func choose(index: int) -> void:
	selected=index
	if start_button!=null: start_button.focus_neighbor_top=start_button.get_path_to(cards[index])
	if back_button!=null: back_button.focus_neighbor_top=back_button.get_path_to(cards[index])
	queue_redraw()

func open_menu() -> void:
	if visible: return
	return_state=game.state; return_freeze=game.ball.freeze
	return_focus=get_viewport().gui_get_focus_owner()
	game.heading.reset(); game.charging=false; game.charge=0; game.cancel_pass()
	game.controller.combos.cancel(); game.controller.held.clear(); game.controller.clear_shot_aim()
	game.set_pieces.button=0; game.set_pieces.power=0
	game.state="training_setup"; game.ball.freeze=true
	selected=game.training_drills.MODES.find(game.training_drills.mode) if game.training else 0
	show(); game.hud.sync_navigation(); cards[selected].grab_focus(); queue_redraw()

func close_menu() -> void:
	if not visible: return
	hide(); game.state=return_state; game.ball.freeze=return_freeze
	game.hud.sync_navigation()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree(): return_focus.grab_focus()

func start() -> void:
	hide()
	game.start_match(true,true,false,game.training_drills.MODES[selected])
	game.hud.sync_navigation()

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: close_menu(); get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ENTER:
			game.controller.menus.activate(); get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B,JOY_BUTTON_BACK]: close_menu()
		elif event.button_index==JOY_BUTTON_START: start()

func _draw() -> void:
	backdrop("ANTRENMANINI SEÇ.","Serbest oyna ya da tek bir pozisyonu tekrar tekrar çalış.","SEFC  /  ANTRENMAN SAHASI")
	for i in range(3):
		var at := Vector2(54+i*450,246)
		var chosen := selected==i
		box(Rect2(at,Vector2(432,444)),Color("173b3d") if chosen else PANEL,8,GOLD if chosen else Color("29454a"))
		text("0%d  /  %s" % [i+1,"SEÇİLİ" if chosen else "ÇALIŞMA"],at+Vector2(25,35),11,GOLD if chosen else MUTE,true)
		pitch_diagram(at+Vector2(28,64),i)
		text(game.training_drills.TITLES[i],at+Vector2(25,288),24,PAPER,true)
		text(DESCRIPTIONS[i][0],at+Vector2(25,323),11,GOLD,true)
		text(DESCRIPTIONS[i][1],at+Vector2(25,355),13,MUTE)
		text(DESCRIPTIONS[i][2],at+Vector2(25,380),13,MUTE)
		text("OTOMATİK YENİ DENEME" if i>0 else "ÖZGÜRCE OYNA",at+Vector2(25,418),10,GOLD,true)
	if game.controller.using_gamepad:
		game.controller.Glyphs.draw_hints(self,Vector2(56,743),[["START","Mola / yeni deneme"],["VIEW","Antrenman seçimi"]],game.controller.family,font,28,13)
	else: text("R · Yeni deneme     T · Antrenman seçimi",Vector2(56,743),14,PAPER)

func pitch_diagram(at: Vector2,mode: int) -> void:
	var rect := Rect2(at,Vector2(376,196))
	box(rect,Color("163f39"),5)
	var line := Color("658b78")
	draw_rect(Rect2(at+Vector2(10,10),Vector2(356,176)),line,false,1)
	draw_rect(Rect2(at+Vector2(102,10),Vector2(172,76)),line,false,1)
	draw_rect(Rect2(at+Vector2(154,3),Vector2(68,12)),PAPER,false,2)
	var player := at+Vector2(188,151 if mode!=1 else 104)
	draw_circle(player,8,GOLD); draw_arc(player,14,0,TAU,32,Color(GOLD,.25),2,true)
	draw_circle(at+Vector2(188,30),7,Color("df9867"))
	if mode==1:
		var partner := at+Vector2(334,115)
		draw_circle(partner,7,PAPER)
		var curve := PackedVector2Array()
		for step in range(25):
			var t := step/24.0
			curve.append(partner.lerp(player,t)+Vector2(0,-sin(t*PI)*52))
		draw_polyline(curve,Color(GOLD,.8),2,true)
		draw_circle(curve[12],4,PAPER)
	else:
		for step in range(10): draw_line(player+Vector2(2,-12-step*11),player+Vector2(3,-16-step*11),GOLD,2,true)
		draw_circle(player+Vector2(0,-17),4,PAPER)
		if mode==2:
			for j in range(4): draw_circle(at+Vector2(170+j*13,89),5,Color("d88373"))
