extends "res://scripts/menu_screen.gd"
const Catalog=preload("res://scripts/training_catalog.gd")
var game
var demo:=preload("res://scripts/training_demo.gd").new()
var demo_button: Button
var selected:=0
var cards: Array[Button]=[]
var start_button: Button
var back_button: Button
var return_state:="menu"
var return_freeze:=false
var return_focus: Control
var result: Dictionary={}

func _ready() -> void:
	setup_style(); hide()
	for i in range(Catalog.MODES.size()):
		var card:=make_button(self,card_rect(i),"",choose.bind(i))
		for state in ["normal","hover","pressed"]: card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		card.focus_entered.connect(choose.bind(i)); cards.append(card)
	back_button=make_button(self,Rect2(54,818,260,60),"← GERİ",close_menu)
	start_button=make_button(self,Rect2(1010,818,376,60),"ANTRENMANA BAŞLA →",start,true)
	demo_button=make_button(self,Rect2(1060,705,299,31),"Ⅱ GÖSTERİMİ DURAKLAT",func(): demo.toggle(self))
	for i in range(cards.size()):
		cards[i].focus_neighbor_left=cards[i].get_path_to(cards[(i/2)*2+posmod(i%2-1,2)])
		cards[i].focus_neighbor_right=cards[i].get_path_to(demo_button if i%2==1 else cards[i+1])
		cards[i].focus_neighbor_top=cards[i].get_path_to(cards[i-2] if i>=2 else back_button)
		cards[i].focus_neighbor_bottom=cards[i].get_path_to(cards[i+2] if i+2<cards.size() else start_button)
	start_button.focus_neighbor_left=start_button.get_path_to(back_button)
	back_button.focus_neighbor_right=back_button.get_path_to(start_button)
	demo_button.focus_neighbor_bottom=demo_button.get_path_to(start_button)
	demo_button.focus_neighbor_top=demo_button.get_path_to(cards[1])
	demo_button.focus_neighbor_left=demo_button.get_path_to(cards[1])
	game.controller.prompts_changed.connect(queue_redraw)

func card_rect(index: int) -> Rect2: return Rect2(54+(index%2)*369,204+(index/2)*90,351,84)

func _process(delta: float) -> void:
	if visible:
		demo_button.visible=result.is_empty()
		if result.is_empty(): demo.update(self,delta)

func choose(index: int) -> void:
	selected=clampi(index,0,Catalog.MODES.size()-1)
	if demo_button!=null: demo_button.focus_neighbor_left=demo_button.get_path_to(cards[selected])
	if start_button!=null: start_button.focus_neighbor_top=start_button.get_path_to(cards[selected])
	if back_button!=null: back_button.focus_neighbor_top=back_button.get_path_to(cards[selected])
	queue_redraw()

func open_menu() -> void:
	if visible: return
	if not game.career.training.active.is_empty(): game.career.training.leave(); return
	result={}; return_state=game.state; return_freeze=game.ball.freeze
	return_focus=get_viewport().gui_get_focus_owner()
	game.heading.reset(); game.charging=false; game.charge=0; game.cancel_pass()
	game.controller.combos.cancel(); game.controller.held.clear(); game.controller.clear_shot_aim()
	game.set_pieces.button=0; game.set_pieces.power=0
	game.state="training_setup"; game.ball.freeze=true
	selected=maxi(0,Catalog.MODES.find(game.training_drills.mode)) if game.training else 0
	for card in cards: card.show()
	back_button.text="← GERİ"; start_button.text="ANTRENMANA BAŞLA →"
	show(); game.hud.sync_navigation(); cards[selected].grab_focus(); queue_redraw()

func close_menu() -> void:
	if not visible: return
	if not result.is_empty():
		if result.career:
			hide(); result={}; game.career.training.leave(); return
		result={}; return_state="menu"; hide(); game.return_menu(); open_menu(); return
	hide(); game.state=return_state; game.ball.freeze=return_freeze
	game.hud.sync_navigation()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree(): return_focus.grab_focus()

func start() -> void:
	if not result.is_empty() and result.career:
		var next:=next_session()
		hide(); result={}
		if next>=0: game.career.training.start(next)
		else: game.career.training.leave()
		return
	result={}; hide()
	game.start_match(true,false,false,Catalog.MODES[selected]); game.hud.sync_navigation()

func show_result(value: Dictionary) -> void:
	result=value; selected=Catalog.MODES.find(value.mode)
	for card in cards: card.hide()
	back_button.text="PROGRAMA DÖN" if result.career else "ÇALIŞMALAR"
	start_button.text=("SONRAKİ ÇALIŞMA →" if next_session()>=0 else "PROGRAMA DÖN →") if result.career else "YENİDEN DENE →"
	start_button.focus_neighbor_top=start_button.get_path_to(back_button)
	back_button.focus_neighbor_top=back_button.get_path_to(start_button)
	show(); game.hud.sync_navigation(); start_button.grab_focus(); queue_redraw()

func next_session() -> int:
	if not game.career.exists(): return -1
	for i in range(game.career.training.data().slots.size()):
		if game.career.training.ready(i): return i
	return -1

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: close_menu(); get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ENTER: game.controller.menus.activate(); get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B,JOY_BUTTON_BACK]: close_menu()
		elif event.button_index==JOY_BUTTON_START: start()

func _draw() -> void:
	preload("res://scripts/quick_match_art.gd").backdrop(self)
	draw_texture_rect(Brand.CREST,Rect2(48,28,42,51),false)
	text("ANTRENMAN",Vector2(108,65),29,PAPER,true)
	if not result.is_empty(): draw_result(); return
	text("HER DOKUNUŞTA DAHA İYİ.",Vector2(54,132),36,PAPER,true)
	text("8 puanlı çalışma + 4 serbest atölye  ·  Burada kariyer özellikleri değişmez.",Vector2(56,170),15,GOLD)
	for i in range(cards.size()):
		var rect:=card_rect(i); var at:=rect.position; var chosen:=selected==i
		box(rect,Color("1a373b") if chosen else PANEL,12,GOLD if chosen else Color("29404c"))
		text("%02d" % (i+1),at+Vector2(14,30),16,GOLD,true)
		UI.fit(self,bold,Catalog.TITLES[i],at+Vector2(50,30),286,16,PAPER)
		text("6 DENEME · A–F NOTU" if Catalog.MODES[i] in Catalog.SCORED else "SERBEST ATÖLYE",at+Vector2(50,62),12,MUTE,true)
	demo.draw(self)
	text("Kariyerde gelişim: Kariyer merkezi → Haftalık antrenman",Vector2(56,791),14,MUTE)
	if game.controller.using_gamepad:
		game.controller.Glyphs.draw_hints(self,Vector2(341,854),[["D-PAD","Çalışma"],["A","Başla"],["B","Geri"]],game.controller.family,font,24,11)
	else: text("YÖN TUŞLARI · Seç    ENTER · Başla    ESC · Geri",Vector2(351,854),12,MUTE)

func draw_result() -> void:
	box(Rect2(220,181,1000,553),Color("122b34"),20,Color(GOLD,.35))
	center(Catalog.title(result.mode),Vector2(720,241),32,PAPER,true)
	center("ÇALIŞMA TAMAMLANDI",Vector2(720,277),12,MUTE,true)
	center(result.grade,Vector2(500,446),134,GOLD,true)
	text("%d / 100" % result.score,Vector2(669,398),48,PAPER,true)
	text("%d / 600 PUAN · 6 DENEME" % result.points,Vector2(672,439),17,MUTE)
	draw_line(Vector2(295,487),Vector2(1145,487),Color(GOLD,.25),1)
	if result.career and not result.reward.is_empty():
		center(result.reward.name,Vector2(720,541),24,PAPER,true)
		center("+%.1f GELİŞİM PUANI" % result.reward.xp,Vector2(720,590),32,GOLD,true)
		center("Bu haftaki çalışma tamamlandı ve kariyere kaydedildi." if result.reward.get("saved",false) else "Puan uygulandı. Kayıt başarısız; kariyer merkezinden tekrar kaydet.",Vector2(720,631),16,MUTE)
		center("En iyi oynama notun sonraki otomatik çalışmalarda kullanılır.",Vector2(720,660),14,MUTE)
	else:
		center("SERBEST PRATİK",Vector2(720,558),27,GOLD,true)
		center("Bu puan kariyer oyuncularının özelliklerini değiştirmez.",Vector2(720,607),18,PAPER)
		center("Oyuncu geliştirmek için kariyerdeki haftalık programı kullan.",Vector2(720,642),15,MUTE)

func wrapped(value: String,at: Vector2,width: float,size: int,color: Color,lines: int) -> void:
	var row:=""; var line:=0
	for word in value.split(" "):
		var next: String=word if row=="" else row+" "+word
		if font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and row!="":
			text(row,at+Vector2(0,line*(size+5)),size,color); line+=1; row=word
			if line>=lines: return
		else: row=next
	if row!="": text(row,at+Vector2(0,line*(size+5)),size,color)
