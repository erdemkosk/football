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
var group:=0
var group_buttons: Array[Button]=[]

func _ready() -> void:
	setup_style(); hide()
	for i in range(Catalog.MODES.size()):
		var card:=make_button(self,card_rect(i),"",choose.bind(i))
		card.tooltip_text=Catalog.title(Catalog.MODES[i])+" · "+Catalog.detail(Catalog.MODES[i])
		card.set_meta("training_mode",Catalog.MODES[i])
		for state in ["normal","hover","pressed"]: card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		card.focus_entered.connect(choose.bind(i)); cards.append(card)
	for i in range(2):
		group_buttons.append(make_button(self,Rect2(54+i*330,174,314,43),["SERBEST ATÖLYELER · 4","PUANLI ÇALIŞMALAR · 8"][i],select_group.bind(i)))
	back_button=make_button(self,Rect2(54,818,260,60),"← GERİ",close_menu)
	start_button=make_button(self,Rect2(1010,818,376,60),"ANTRENMANA BAŞLA →",start,true)
	demo_button=make_button(self,Rect2(1090,748,276,32),"Ⅱ GÖSTERİMİ DURAKLAT",func(): demo.toggle(self))
	demo_button.add_theme_font_size_override("font_size",12)
	start_button.focus_neighbor_left=start_button.get_path_to(back_button)
	back_button.focus_neighbor_right=back_button.get_path_to(start_button)
	demo_button.focus_neighbor_bottom=demo_button.get_path_to(start_button)
	demo_button.focus_neighbor_top=demo_button.get_path_to(cards[1])
	demo_button.focus_neighbor_left=demo_button.get_path_to(cards[1])
	game.controller.prompts_changed.connect(queue_redraw)
	layout_choices()

func card_rect(index: int) -> Rect2:
	var modes: Array=Catalog.WORKSHOPS if index<4 else Catalog.SCORED
	var cell: int=modes.find(Catalog.MODES[index])
	return Rect2(54+(cell%2)*330,238+(cell/2)*118,314,104)

func visible_indices() -> Array:
	return (Catalog.WORKSHOPS if group==0 else Catalog.SCORED).map(func(mode): return Catalog.MODES.find(mode))

func layout_choices() -> void:
	var ids:=visible_indices()
	for i in range(cards.size()): cards[i].visible=i in ids and result.is_empty()
	for i in range(ids.size()):
		var card: Button=cards[ids[i]]
		card.position=card_rect(ids[i]).position; card.size=card_rect(ids[i]).size
		card.focus_neighbor_left=card.get_path_to(cards[ids[i-1]] if i%2==1 else group_buttons[group])
		card.focus_neighbor_right=card.get_path_to(cards[ids[i+1]] if i%2==0 else demo_button)
		card.focus_neighbor_top=card.get_path_to(cards[ids[i-2]] if i>=2 else group_buttons[group])
		card.focus_neighbor_bottom=card.get_path_to(cards[ids[i+2]] if i+2<ids.size() else start_button)
	for i in range(group_buttons.size()):
		group_buttons[i].visible=result.is_empty()
		group_buttons[i].focus_neighbor_bottom=group_buttons[i].get_path_to(cards[ids[0]])
		group_buttons[i].focus_neighbor_top=group_buttons[i].get_path_to(back_button)
		group_buttons[i].add_theme_color_override("font_color",GOLD if group==i else MUTE)
	group_buttons[0].focus_neighbor_right=group_buttons[0].get_path_to(group_buttons[1])
	group_buttons[1].focus_neighbor_left=group_buttons[1].get_path_to(group_buttons[0])
	demo_button.focus_neighbor_left=demo_button.get_path_to(cards[selected])
	demo_button.focus_neighbor_top=demo_button.get_path_to(cards[selected])
	queue_redraw()

func select_group(value: int) -> void:
	group=value
	selected=visible_indices()[0]
	layout_choices(); choose(selected); cards[selected].grab_focus()

func _process(delta: float) -> void:
	if visible:
		demo_button.visible=result.is_empty()
		if result.is_empty(): demo.update(self,delta)

func choose(index: int) -> void:
	selected=clampi(index,0,Catalog.MODES.size()-1)
	var next_group:=0 if Catalog.MODES[selected] in Catalog.WORKSHOPS else 1
	if group!=next_group: group=next_group; layout_choices()
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
	group=0 if Catalog.MODES[selected] in Catalog.WORKSHOPS else 1
	layout_choices()
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
	for tab in group_buttons: tab.hide()
	demo_button.hide()
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
		elif result.is_empty() and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]: select_group(1-group)

func _draw() -> void:
	preload("res://scripts/quick_match_art.gd").backdrop(self)
	draw_texture_rect(Brand.CREST,Rect2(48,28,42,51),false)
	text("ANTRENMAN",Vector2(108,65),29,PAPER,true)
	if not result.is_empty(): draw_result(); return
	text("Bugün neyi çalışacağız?",Vector2(54,134),32,PAPER,true)
	for i in visible_indices():
		var rect:=card_rect(i); var at:=rect.position; var chosen: bool=selected==i
		box(rect,Color("20362f") if chosen else PANEL,10,GOLD if chosen else UI.LINE)
		UI.fit(self,bold,Catalog.TITLES[i],at+Vector2(20,33),274,18,PAPER)
		UI.fit(self,font,Catalog.focus(Catalog.MODES[i]),at+Vector2(20,60),274,13,MUTE)
		text("6 deneme" if group==1 else "Serbest pratik",at+Vector2(20,86),12,GOLD if chosen else MUTE)
		if chosen: draw_circle(at+Vector2(287,82),4,GOLD)
	if group==0:
		text("Kendi temponda öğren",Vector2(56,540),23,PAPER,true)
		wrapped("Önce hareketleri dene. Hazır olduğunda puanlı çalışmalara geçerek isabetini ölç.",Vector2(56,578),614,17,MUTE,3)
		text("Süre sınırı yok · İstediğin kadar tekrar",Vector2(56,660),14,GOLD)
	else:
		text("Altı deneme · Tek sonuç",Vector2(56,741),18,PAPER,true)
		text("A: 85+   B: 70+   C: 55+   D: 35+   E: 1+   F: 0",Vector2(56,773),13,MUTE)
	demo.draw(self)
	text("Oyuncu geliştirmek için: Kariyer → Haftalık antrenman",Vector2(640,55),14,MUTE)
	if game.controller.using_gamepad:
		game.controller.Glyphs.draw_hints(self,Vector2(341,854),[["D-PAD","Seç"],["A","Başla"],["LB / RB","Bölüm"],["B","Geri"]],game.controller.family,font,24,11)
	else: text("YÖN TUŞLARI · Seç    ENTER · Başla    ESC · Geri",Vector2(351,854),12,MUTE)

func draw_result() -> void:
	box(Rect2(220,174,1000,610),PANEL,16,UI.LINE)
	text("ÇALIŞMA TAMAMLANDI",Vector2(256,211),12,GOLD,true)
	UI.fit(self,bold,Catalog.title(result.mode),Vector2(256,254),916,32,PAPER)
	text("Notun",Vector2(260,312),14,MUTE)
	text(result.grade,Vector2(252,408),100,GOLD,true)
	text("%d / 100" % result.score,Vector2(425,351),48,PAPER,true)
	text("Altı denemenin ortalaması",Vector2(428,383),16,MUTE)
	var attempts: Array=result.get("attempts",[])
	for i in range(attempts.size()):
		var x:=256+i*152
		box(Rect2(x,439,140,74),Color("1b323c"),8)
		text("DENEME %d" % (i+1),Vector2(x+14,461),11,MUTE)
		text(str(attempts[i])+" puan",Vector2(x+14,492),20,GOLD if attempts[i]>0 else UI.RED,true)
	draw_line(Vector2(256,538),Vector2(1184,538),UI.LINE,1)
	if result.career and not result.reward.is_empty():
		text(result.reward.name,Vector2(256,579),24,PAPER,true)
		text("+%.1f gelişim puanı" % result.reward.xp,Vector2(256,617),28,GOLD,true)
		text(Catalog.skill_labels(result.mode),Vector2(256,648),16,MUTE)
		wrapped("Kariyerine kaydedildi. En iyi notun sonraki otomatik çalışmalarda da kullanılır." if result.reward.get("saved",false) else "Puan uygulandı. Kayıt başarısız; kariyer merkezinden tekrar kaydet.",Vector2(256,715),910,16,MUTE,2)
	else:
		text("BİR SONRAKİ DENEMEDE",Vector2(256,579),12,GOLD,true)
		wrapped(Catalog.tip(result.mode),Vector2(256,613),910,21,PAPER,2)
		text("Bu çalışma pratik içindir. Kalıcı oyuncu gelişimi kariyer programında kazanılır.",Vector2(256,732),15,MUTE)

func wrapped(value: String,at: Vector2,width: float,size: int,color: Color,lines: int) -> void:
	var row:=""; var line:=0
	for word in value.split(" "):
		var next: String=word if row=="" else row+" "+word
		if font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and row!="":
			text(row,at+Vector2(0,line*(size+5)),size,color); line+=1; row=word
			if line>=lines: return
		else: row=next
	if row!="": text(row,at+Vector2(0,line*(size+5)),size,color)
