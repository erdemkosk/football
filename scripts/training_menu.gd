extends "res://scripts/menu_screen.gd"
var game
var selected := 0
var cards: Array[Button] = []
var start_button: Button
var back_button: Button
var return_state := "menu"
var return_freeze := false
var return_focus: Control
var studios: Array=[]
const DESCRIPTIONS := [
	["ON BİR OYUNCU.","Kendi takımın sahada; oto seçim maçtaki gibi.","Pas ver, kontrol değişir, kaleciye karşı oyna."],
	["ORTAYA HAREKETLEN.","Takım arkadaşın sırayla iki kanattan orta açar.","Yerini al, şut tuşuyla kafa vur veya kontrol et."],
	["BARAJI AŞ.","Yön tuşlarıyla noktayı seç, A ile oradan vur.","Yön, güç ve falsoyu birlikte dene."],
	["RAKİBİNİ OKU.","Yana çek, dur–kalk, topu açıp diğer yandan geç.","Sabit rakip → müdahale → serbest savunmacı."]]

func _ready() -> void:
	setup_style(); hide()
	for i in range(3):
		var card := make_button(self,Rect2(54+i*450,246,432,444),"",choose.bind(i))
		for state in ["normal","hover","pressed"]: card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		card.focus_entered.connect(choose.bind(i))
		cards.append(card)
		var studio=preload("res://scripts/training_preview.gd").new()
		studio.mode=i; studio.game=game
		studio.position=Vector2(67+i*450,305); studio.size=Vector2(405,270)
		add_child(studio)
		studio.viewport.gui_disable_input=true
		move_child(card,-1)
		studio.player.number=9+i
		studios.append(studio)
	var duel_card := make_button(self,Rect2(54,706,1332,65),"",choose.bind(3))
	for state in ["normal","hover","pressed"]: duel_card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	duel_card.focus_entered.connect(choose.bind(3)); cards.append(duel_card)
	back_button=make_button(self,Rect2(54,818,220,60),"← Geri",close_menu)
	start_button=make_button(self,Rect2(1050,818,336,60),"ANTRENMANA BAŞLA  →",start,true)
	for i in range(3):
		cards[i].focus_neighbor_left=cards[i].get_path_to(cards[posmod(i-1,3)])
		cards[i].focus_neighbor_right=cards[i].get_path_to(cards[(i+1)%3])
		cards[i].focus_neighbor_bottom=cards[i].get_path_to(duel_card)
		cards[i].focus_neighbor_top=cards[i].get_path_to(back_button)
	duel_card.focus_neighbor_top=duel_card.get_path_to(cards[0])
	duel_card.focus_neighbor_bottom=duel_card.get_path_to(start_button)
	duel_card.focus_neighbor_left=duel_card.get_path_to(cards[2])
	duel_card.focus_neighbor_right=duel_card.get_path_to(cards[0])
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
	preload("res://scripts/quick_match_art.gd").backdrop(self)
	draw_texture_rect(Brand.CREST,Rect2(48,28,42,51),false)
	text("ANTRENMAN",Vector2(108,65),29,PAPER,true)
	text("BİR SONRAKİ GOLÜ HAZIRLA.",Vector2(54,166),40,PAPER,true)
	text(DESCRIPTIONS[selected][1],Vector2(56,200),14,GOLD,true)
	for i in range(3):
		var at := Vector2(54+i*450,246)
		var chosen := selected==i
		box(Rect2(at,Vector2(432,444)),Color("152d36") if chosen else PANEL,18,GOLD if chosen else Color("29404c"))
		text("0%d" % (i+1),at+Vector2(20,104),88,Color(GOLD,.16),true)
		text(["SAHA SENİN","HAVADAN BİTİR","DURAN TOP USTASI"][i],at+Vector2(24,36),12,GOLD,true)
		text(game.training_drills.TITLES[i],at+Vector2(25,351),27,PAPER,true)
		text(["11 oyuncu · Serbest oyun","Kafa · Vole · Röveşata","Yön · Güç · Falso"][i],at+Vector2(25,382),15,MUTE)
		text("SEÇİLİ  ●" if chosen else "ÇALIŞMAYI SEÇ  →",at+Vector2(25,420),11,GOLD if chosen else MUTE,true)
	box(Rect2(54,706,1332,65),Color("152d36") if selected==3 else PANEL,12,GOLD if selected==3 else Color("29404c"))
	text("04  BİRE BİR ATÖLYESİ",Vector2(77,745),22,GOLD,true)
	text("Yana çek · Dur–kalk · Aç ve dolaş  /  3 aşama",Vector2(490,745),16,PAPER)
	text("SEÇİLİ ●" if selected==3 else "SEÇ →",Vector2(1240,745),13,GOLD,true)
	if game.controller.using_gamepad:
		game.controller.Glyphs.draw_hints(self,Vector2(56,798),[["LS / D-PAD","Çalışma"],["A","Seç"],["START","Başla"],["B","Geri"]],game.controller.family,font,26,12)
	else: text("YÖN TUŞLARI · Çalışma     ENTER · Seç     ESC · Geri",Vector2(56,802),13,MUTE)

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
