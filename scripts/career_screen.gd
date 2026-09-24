extends "res://scripts/menu_screen.gd"
const World=preload("res://scripts/career_world.gd")
const Portraits=preload("res://scripts/squad_portraits.gd")
const Office=preload("res://scripts/career_office.gd")
const TABS := ["MERKEZ","KADRO","TAKTİK","LİG & KUPALAR","TRANSFER","KULÜP"]
const PAGES := ["hub","squad","tactics","league","market","finance"]
const Card=preload("res://scripts/career_card.gd")
var art:=preload("res://scripts/career_art.gd").new()
var showcase:=preload("res://scripts/career_showcase.gd").new()
var comparison:=preload("res://scripts/career_comparison.gd").new()
var focus_memory: Dictionary={}
var page_memory: Dictionary={}
var trigger_latched:=false
var transition:=0.0
var game
var page := "entry"
var stage := "tactics"
var controls: Control
var portraits := Portraits.new()
var selected := ""
var selected_club := "c00"
var new_world: Dictionary={}
var division := 0
var list_page := 0
var list_ids: Array=[]
var list_view:=false
var player_sort:=0
const PlayerList=preload("res://scripts/career_list.gd")
var status := ""
var mode := 0
var filter := ""
var position_filter := -1
var incoming := ""
var save_slot := 1
var overwrite := false
var new_match_settings := {"half_minutes":2,"difficulty":1,"level":2}
var duration_option: OptionButton
var difficulty_option: OptionButton
var office: SubViewportContainer
var live := false
var live_state := "playing"
var live_freeze := false
var fee := 0
var wage := 0
var years := 3
var promised := 1
var swap := ""
var selected_plan := 1
var world_mask := 1048575
var built_page := ""
var summaries: Array=[]
var market_filter := 0
var offer_page := 0
var squad_filter := 0
var loan_term := 1
var loan_share := 75
var loan_option := false
var pending_action := ""
var cup_group:=0
var nation_filter:=""
var director_ui:=preload("res://scripts/career_director_screen.gd").new()
var training_ui:=preload("res://scripts/career_training_screen.gd").new()
var calendar:=preload("res://scripts/career_calendar.gd").new()
var tactics:=preload("res://scripts/career_tactics.gd").new()

func _ready() -> void:
	setup_style(); visible=false
	controls=Control.new(); controls.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(controls)
	add_child(showcase)
	apply_career_style()
	add_child(portraits); portraits.portrait_ready.connect(func(_key): queue_redraw())
	calendar.game=game; calendar.screen=self; add_child(calendar)

func _process(delta: float) -> void:
	if visible:
		transition=1.0 if game.experience.reduce_motion else move_toward(transition,1.0,delta*7)
		controls.modulate.a=lerpf(.6,1.0,transition)
		queue_redraw()
		if not calendar.visible and game.controller.using_gamepad and page in ["squad","market","tactics"]:
			var left:=Input.get_joy_axis(game.controller.device,JOY_AXIS_TRIGGER_LEFT)
			var right:=Input.get_joy_axis(game.controller.device,JOY_AXIS_TRIGGER_RIGHT)
			if maxf(left,right)<.3: trigger_latched=false
			elif not trigger_latched and maxf(left,right)>.7:
				trigger_latched=true; turn_page(1 if right>left else -1)

func turn_page(direction: int) -> void:
	if page=="tactics": tactics.turn_page(self,direction); return
	if not page in ["squad","market"]: return
	if is_instance_valid(game.controller.menus.popup_option) and game.controller.menus.popup_option.get_popup().visible: return
	var next:=clampi(list_page+direction,0,maxi(0,(list_ids.size()-1)/9))
	if next==list_page: return
	var current:=get_viewport().gui_get_focus_owner()
	var cell: int=int(current.get_meta("card_cell",0)) if is_instance_valid(current) else 0
	list_page=next
	selected=str(list_ids[mini(list_page*9+cell,list_ids.size()-1)])
	build()
	for child in controls.get_children():
		if child.get_meta("card_cell",-1)==mini(cell,list_ids.size()-list_page*9-1): child.grab_focus(); break

func apply_career_style() -> void:
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style:=StyleBoxFlat.new(); style.set_corner_radius_all(12)
			style.content_margin_left=12; style.content_margin_right=12
			style.bg_color=Color("152a35") if state=="normal" else Color("29404c")
			if state=="disabled": style.bg_color=Color("162333")
			if state=="focus":
				style.bg_color=Color.TRANSPARENT; style.set_border_width_all(3)
				style.border_color=art.LIME; style.set_expand_margin_all(2)
			theme.set_stylebox(state,type,style)
		theme.set_color("font_color",type,art.WHITE)
		theme.set_color("font_focus_color",type,art.WHITE)
		theme.set_color("font_disabled_color",type,Color("768798"))
	var popup:=StyleBoxFlat.new(); popup.bg_color=Color("122234"); popup.set_border_width_all(1); popup.border_color=art.BLUE
	popup.content_margin_top=8; popup.content_margin_bottom=8
	theme.set_stylebox("panel","PopupMenu",popup)
	theme.set_color("font_hover_color","PopupMenu",art.LIME)

func card_at(rect: Rect2,title: String,callback: Callable,kind: String,id: String) -> Button:
	var card:=Card.new(); card.screen=self; card.position=rect.position; card.size=rect.size
	card.text=title; card.kind=kind; card.identity=id; card.pressed.connect(callback)
	card.set_meta("focus_key",kind+":"+id); controls.add_child(card)
	return card

func remember_focus() -> void:
	if page==built_page and page in ["squad","market"]:
		page_memory[page]={"selected":selected,"list_page":list_page,"list_view":list_view,"player_sort":player_sort}
	var current:=get_viewport().gui_get_focus_owner()
	if is_instance_valid(current) and controls.is_ancestor_of(current):
		focus_memory[built_page]=str(current.get_meta("focus_key",str(current.position)))

func focus_key(child: Control) -> String:
	return str(child.get_meta("focus_key",str(child.position)))


func pause_world() -> void:
	game.career.remember_quick_match()
	if game.camera.cull_mask!=0: world_mask=game.camera.cull_mask
	game.camera.cull_mask=0
	game.controller.held.clear(); game.cancel_pass(); game.charging=false
	game.state="career"; game.ball.freeze=true; game.audio.set_process(false)
	game.audio.update_atmosphere(0,"paused"); game.weather.sound.stream_paused=true
	for channel in game.audio.contacts: channel.stream_paused=true

func open_entry() -> void:
	if game.career.in_match: return
	pause_world(); visible=true; page="entry"; status=""; build()

func open_hub() -> void:
	if not game.career.exists(): open_entry(); return
	if game.career.in_match and game.state=="finished": game.career.finish_match()
	if game.state=="trophy": visible=false; clear_controls(); return
	pause_world(); live=false; visible=true; page="hub"; list_page=0; selected=""; build()

func open_live_tactics() -> void:
	tactics.reset()
	live_state=game.frontend.previous_state
	live_freeze=game.frontend.previous_freeze
	game.frontend.visible=false; live=true
	pause_world(); visible=true; page="tactics"; build()

func go(next: String) -> void:
	if calendar.visible: return
	if next=="tactics" and page!="tactics": tactics.reset()
	remember_focus()
	page=next; list_page=0; status=""; incoming=""; selected=""; mode=0
	if page in ["squad","market"] and page_memory.has(page):
		selected=page_memory[page].selected; list_page=page_memory[page].list_page
		list_view=page_memory[page].get("list_view",false); player_sort=page_memory[page].get("player_sort",0)
	pending_action=""
	if next=="league": division=int(game.career.club().league)
	build()

func close() -> void:
	calendar.hide()
	game.camera.cull_mask=world_mask
	visible=false; clear_controls(); game.audio.set_process(true)
	if live:
		game.career.apply_plan(game.career.club().plan); game.management.apply_formation()
		game.state=live_state; game.ball.freeze=live_freeze; live=false
		if game.state in ["restart","set_piece","halftime"]:
			game.management.prepare_substitutions()
			if game.state=="set_piece" and not game.management.transit.is_empty():
				game.state="restart"; game.set_pieces.prepare()
	else: game.return_menu()

func handle(event: InputEvent) -> void:
	if calendar.visible:
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_ENTER,KEY_SPACE]: calendar.finish()
		elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_START]: calendar.finish()
		get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo:
		game.controller.using_gamepad=false
		if event.keycode==KEY_ESCAPE: back(); get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]: turn_page(1 if event.keycode==KEY_PAGEDOWN else -1)
		elif page=="tactics" and event.keycode==KEY_T: tactics.toggle(self)
		elif page=="tactics" and event.keycode==KEY_Z: tactics.undo(self)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_B: back()
		elif page=="tactics" and event.button_index==JOY_BUTTON_Y: tactics.toggle(self)
		elif page=="tactics" and event.button_index==JOY_BUTTON_X: tactics.undo(self)
		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER] and page in PAGES and not live:
			go(PAGES[posmod(PAGES.find(page)+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1),6)])

		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER] and page in director_ui.PAGES:
			page=director_ui.PAGES[posmod(director_ui.PAGES.find(page)+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1),director_ui.PAGES.size())]; build()

func back() -> void:
	if page=="tactics" and tactics.settings_open: tactics.toggle(self)
	elif page=="tactics" and tactics.selected!="": tactics.selected=""; status=""; build()
	elif live: close()
	elif page=="terms": page="talks"; build()
	elif page=="comparison": page=comparison.origin; build()
	elif page=="talks": go("market")
	elif page=="choose": page="entry"; build()
	elif page=="entry" or page=="hub": close()
	else: go("hub")

func clear_controls() -> void:
	office=null
	for child in controls.get_children(): controls.remove_child(child); child.queue_free()

func button_at(rect: Rect2,title: String,callback: Callable,primary: bool=false) -> Button:
	var b:=make_button(controls,rect,title,callback,primary)
	b.add_theme_font_size_override("font_size",14)
	b.clip_text=true
	if primary:
		for state in ["normal","hover","pressed"]:
			var style:=StyleBoxFlat.new(); style.bg_color=art.LIME.lightened(.1) if state=="hover" else art.LIME
			style.set_corner_radius_all(7); b.add_theme_stylebox_override(state,style)
	return b

func option_at(rect: Rect2,items: Array,index: int,callback: Callable) -> OptionButton:
	var b:=OptionButton.new(); b.position=rect.position; b.size=rect.size
	b.fit_to_longest_item=false; b.clip_text=true
	b.add_theme_font_size_override("font_size",14)
	for item in items: b.add_item(str(item))
	b.select(index); b.item_selected.connect(callback); controls.add_child(b)
	b.get_popup().window_input.connect(game.controller.menus.popup_input.bind(b))
	b.get_popup().popup_hide.connect(func(): game.controller.menus.popup_option=null; b.grab_focus())
	return b

func build() -> void:
	remember_focus()
	if page!=built_page:
		transition=0.0
		trigger_latched=maxf(Input.get_joy_axis(game.controller.device,JOY_AXIS_TRIGGER_LEFT),Input.get_joy_axis(game.controller.device,JOY_AXIS_TRIGGER_RIGHT))>.3 if game.controller.device>=0 else false
	clear_controls()
	if page in PAGES:
		for i in range(6):
			if live and PAGES[i]!="tactics": continue
			button_at(Rect2(44+i*226,108,216,43),TABS[i],go.bind(PAGES[i]),page==PAGES[i])
		button_at(Rect2(44,827,220,43),"← MAÇA DÖN" if live else "← ANA MENÜ",close)
		button_at(Rect2(1110,827,286,43),"KARİYERİ KAYDET",save_game)
	if page in director_ui.PAGES or page=="terms": director_ui.build(self)
	match page:
		"entry": build_entry()
		"choose": build_choose()
		"hub": build_hub()
		"squad","market": build_players()
		"league": build_league()
		"tactics": build_tactics()
		"finance": build_finance()
		"talks": build_talks()
		"comparison": comparison.build(self)
		"training": training_ui.build(self)
	if page=="hub" and not game.career.club().lineup.is_empty():
		var hero: String=showcase.hero(self)
		showcase.configure(portrait_data(hero))
	if page=="tactics":
		for id in game.career.club().lineup: portraits.request(portrait_data(id))
	var focus: Control=null
	var remembered: String=focus_memory.get(page,"")
	if remembered=="" and page=="hub": remembered=str(Vector2(77,532))
	if remembered=="" and page=="tactics":
		var id := tactics.default_id(self)
		if id!="": remembered="tactic:"+id
	for child in controls.get_children():
		if not child is BaseButton or child.disabled: continue
		if focus==null or (remembered=="" and child.position.y>160 and child.position.y<800 and (focus.position.y<160 or focus.position.y>=800)): focus=child
		if focus_key(child)==remembered: focus=child; break
	if remembered=="" and page in ["squad","market"]:
		for child in controls.get_children():
			if child.get_meta("focus_key","")==("player_row:" if list_view else "player:")+selected: focus=child; break
	if focus!=null:
		focus.grab_focus()
		if page=="tactics" and focus.get_meta("focus_key","").begins_with("tactic:"):
			tactics.inspect(self,str(focus.get_meta("focus_key")).substr(7))
	built_page=page
	queue_redraw()

func save_game() -> void:
	status="Kariyer kaydedildi." if game.career.save() else game.career.error

func build_entry() -> void:
	summaries=[]
	for i in range(3):
		summaries.append(game.career.slot_summary(i+1))
		var x:=50+i*458
		button_at(Rect2(x+24,500,370,51),"KAYITTAN DEVAM ET",load_career.bind(i+1),true).disabled=not game.career.has_save(i+1)
		button_at(Rect2(x+24,568,370,49),"YENİ KARİYER",choose.bind(i+1))
	button_at(Rect2(50,823,260,45),"← ANA MENÜ",close)

func load_career(index: int) -> void:
	if game.career.load_slot(index): status=game.career.error; open_hub()
	else: status=game.career.error

func choose(index: int) -> void:
	save_slot=index; new_world=World.create(); page="choose"; overwrite=false; selected_club="c00"; division=0
	new_match_settings=game.MatchSettings.normalized({"half_minutes":game.quick_half_minutes,"level":game.career.quick_state.get("level",game.management.level)})
	if DisplayServer.get_name()!="headless" and is_instance_valid(game.match_menu):
		division=clampi(game.match_menu.last_career_division,0,World.LEAGUES.size()-1)
		selected_club=game.match_menu.last_career_club
		var ids: Array=choose_ids()
		if selected_club not in ids: selected_club=ids[0] if not ids.is_empty() else "c00"
	build()

func remember_club() -> void:
	if DisplayServer.get_name()=="headless" or not is_instance_valid(game.match_menu): return
	game.match_menu.last_career_club=selected_club
	game.match_menu.last_career_division=division
	game.match_menu.persist_session()

func choose_ids() -> Array:
	return new_world.clubs.keys().filter(func(id): return int(new_world.clubs[id].league)==division)

func build_choose() -> void:
	option_at(Rect2(52,170,470,44),World.LEAGUES,division,func(v): division=v; selected_club=choose_ids()[0]; remember_club(); build())
	var choices:=choose_ids()
	for n in range(choices.size()):
		var id: String=choices[n]
		var c: Dictionary=new_world.clubs[id]
		var b:=card_at(Rect2(54+(n%3)*280,248+(n/3)*76,264,63),c.name,func(): selected_club=id; overwrite=false; remember_club(); build(),"club",id)
		b.add_theme_font_size_override("font_size",12)
	duration_option=option_at(Rect2(954,685,198,44),game.MatchSettings.HALF_MINUTES.map(func(minutes): return "%d dakika" % minutes),game.MatchSettings.HALF_MINUTES.find(new_match_settings.half_minutes),func(v): new_match_settings.half_minutes=game.MatchSettings.HALF_MINUTES[v]; queue_redraw())
	duration_option.set_meta("focus_key","career_duration")
	difficulty_option=option_at(Rect2(1168,685,198,44),game.MatchSettings.LEVELS,new_match_settings.level,func(v): new_match_settings=game.MatchSettings.normalized({"half_minutes":new_match_settings.half_minutes,"level":v}); queue_redraw())
	difficulty_option.set_meta("focus_key","career_difficulty")
	var start_button:=button_at(Rect2(954,766,412,52),"KAYDIN ÜZERİNE YAZ & BAŞLA" if overwrite else "BU KULÜPLE BAŞLA",begin,true)
	# Left/right changes an option's value; up/down visits both settings.
	duration_option.focus_neighbor_bottom=duration_option.get_path_to(difficulty_option)
	difficulty_option.focus_neighbor_top=difficulty_option.get_path_to(duration_option)
	difficulty_option.focus_neighbor_bottom=difficulty_option.get_path_to(start_button)
	start_button.focus_neighbor_top=start_button.get_path_to(difficulty_option)
	button_at(Rect2(52,823,220,43),"← KAYITLAR",func(): page="entry"; build())

func begin() -> void:
	if game.career.has_save(save_slot) and not overwrite: overwrite=true; status="Bu yuvadaki kariyer değiştirilecek. Devam etmek için tekrar seç."; build(); return
	if game.career.new_career(selected_club,save_slot,new_match_settings): open_hub()
	else: status=game.career.error

func pending_offers() -> int:
	var c=game.career
	return c.world.offers.filter(func(o): return not o.get("closed",false) and o.expires>=c.world.date).size()

func build_hub() -> void:
	var c=game.career
	var training_done: int=c.training.data().slots.filter(func(row): return row.done).size()
	button_at(Rect2(77,592,490,28),"HAFTALIK ANTRENMAN  ·  %d / 5" % training_done,go.bind("training"))
	var f: Dictionary=c.next_fixture()
	if c.world.season_done:
		button_at(Rect2(77,532,490,52),"YENİ SEZONA GEÇ",func(): c.next_season(); build(),true)
	elif not f.is_empty() and f.day<=c.world.date:
		button_at(Rect2(77,532,490,52),"KADROYU HAZIRLA & MAÇA ÇIK",play,true)
		button_at(Rect2(586,532,252,52),"MAÇI SİMÜLE ET",simulate_match)
	else:
		button_at(Rect2(77,532,490,52),"TAKVİMİ İLERLET  →",advance_calendar,true)
	button_at(Rect2(908,440,465,29),"PUAN DURUMU & FİKSTÜR",go.bind("league"))
	if pending_offers()>0: button_at(Rect2(909,567,464,30),"%d TEKLİFİ İNCELE →" % pending_offers(),go.bind("finance"))
	var a=card_at(Rect2(52,629,436,163),"TRANSFER MERKEZİ",go.bind("market"),"action","market")
	a.caption="KADRONU GÜÇLENDİR"; a.detail="Oyuncu keşfet · Teklif yap · İmza at"; a.accent=art.BLUE
	var b=card_at(Rect2(504,629,438,163),"TEKNİK DİREKTÖR MERKEZİ",go.bind("board"),"action","board")
	b.caption="KULÜBÜN GELECEĞİ"; b.detail="Gelişim · Akademi · Yönetim"
	var d=card_at(Rect2(958,629,438,163),"GELEN TEKLİFLER & BÜTÇE",go.bind("finance"),"action","finance")
	d.caption="KULÜBÜ YÖNET"; d.detail="Kasa "+c.money(c.club().cash)+"  /  Yeni teklifler"; d.accent=Color("e9c99a")

func play() -> void:
	if game.career.prepare_match(): visible=false; clear_controls(); game.camera.cull_mask=world_mask; game.audio.set_process(true)
	else: status=game.career.error

func simulate_match() -> void:
	var c=game.career
	var fixture: Dictionary=c.next_fixture()
	if c.simulate_next():
		var award: Dictionary=game.finale.award_for(fixture)
		if award.get("club","")==c.world.user and game.finale.show_award(award): return
	build()

func advance_calendar() -> void:
	if calendar.visible or page!="hub": return
	var c=game.career
	var before: int=c.world.date
	var old_offers: int=c.world.offers.size()
	status=c.advance_to_event()
	if c.world.date==before: build(); return
	var f: Dictionary=c.next_fixture()
	var notice: String="Takımın kondisyonu ve kulüp gündemi güncellendi."
	if c.world.offers.size()>old_offers: notice="Yeni transfer teklifi geldi · Gelen teklifler bölümünde."
	elif not f.is_empty() and f.day<=c.world.date: notice="Maç günü geldi · Kadronu hazırla."
	status="%d gün ilerledi · %s → %s" % [c.world.date-before,World.date_label(before),World.date_label(c.world.date)]
	build(); calendar.begin(before,c.world.date,notice)

func calendar_finished() -> void:
	for child in controls.get_children():
		if child is Button and child.position==Vector2(77,532): child.grab_focus(); return

func build_players() -> void:
	var c=game.career
	if page=="squad":
		list_ids=c.roster(c.world.user)
		if squad_filter==1: list_ids=c.contracts.incoming(c.world.user)
		elif squad_filter==2: list_ids=c.contracts.outgoing(c.world.user)
		elif squad_filter==3: list_ids=list_ids.filter(func(pid): return c.player(pid).get("retirement_year",0)>0)
		option_at(Rect2(487,173,369,41),["TÜM KADRO","KİRALIK GELENLER","KİRALIK GİDENLER","EMEKLİLİK KARARI"],squad_filter,func(v): squad_filter=v; list_page=0; selected=""; incoming=""; pending_action=""; build())
	else:
		list_ids=[]
		var home_country: String=c.club().get("nation","")
		var national_league: bool=World.International.NATIONS.has(home_country)
		if nation_filter=="*" and not national_league: nation_filter=""
		for pid in c.world.players:
			var p: Dictionary=c.player(pid)
			if p.club==c.world.user or p.get("retired",false) or p.get("academy_owner","")!="": continue
			if p.get("loan",{}).get("owner","")==c.world.user: continue
			if market_filter==1 and (c.market.asking_price(p)>minf(c.club().budget,c.club().cash-c.payroll(c.world.user)*2) and p.club!=""): continue
			if market_filter==2 and not p.listed: continue
			if market_filter==3 and p.club!="": continue
			if market_filter==4 and (not p.get("loan_listed",false) or c.contracts.transfer_lock(pid)!=""): continue
			if market_filter==5 and p.get("retirement_year",0)==0: continue
			if position_filter>=0 and int(p.role)!=position_filter: continue
			if nation_filter=="*" and p.get("nationality","")==home_country: continue
			if not nation_filter in ["","*"] and p.get("nationality","TR")!=nation_filter: continue
			if filter!="" and not p.name.to_lower().contains(filter.to_lower()): continue
			list_ids.append(pid)
		list_ids.sort_custom(func(a,b): return World.ovr(c.player(a))>World.ovr(c.player(b)))
		var search:=LineEdit.new(); search.position=Vector2(52,173); search.size=Vector2(190,41); search.placeholder_text="Oyuncu ara…"; search.text=filter
		controls.add_child(search)
		search.text_submitted.connect(func(v): filter=v; list_page=0; selected=""; build())
		button_at(Rect2(254,173,65,41),"ARA",func(): filter=search.text; list_page=0; selected=""; build())
		option_at(Rect2(331,173,144,41),["MEVKİ: TÜMÜ","KALECİ","DEFANS","ORTA SAHA","FORVET"],position_filter+1,func(v): position_filter=v-1; list_page=0; selected=""; build())
		option_at(Rect2(487,173,195,41),["TÜM OYUNCULAR","BÜTÇEME UYGUN","SATIŞ LİSTESİ","SERBEST","KİRALIK LİSTESİ","EMEKLİ OLACAK"],market_filter,func(v): market_filter=v; list_page=0; selected=""; build())
		var countries: Array=["ÜLKE: TÜMÜ"]+(["YABANCI"] if national_league else [])+World.International.NATIONS.values()
		var codes: Array=[""]+(["*"] if national_league else [])+World.International.NATIONS.keys()
		option_at(Rect2(694,173,166,41),countries,codes.find(nation_filter),func(v): nation_filter=codes[v]; list_page=0; selected=""; build())
	PlayerList.sort_players(self)
	PlayerList.toolbar(self)
	if selected=="" or not selected in list_ids: selected=str(list_ids[0]) if not list_ids.is_empty() else ""
	list_page=clampi(list_page,0,maxi(0,(list_ids.size()-1)/9))
	if not list_ids.is_empty() and not selected in list_ids.slice(list_page*9,list_page*9+9): selected=str(list_ids[list_page*9])
	for n in range(9):
		var index:=list_page*9+n
		if index>=list_ids.size(): break
		var pid: String=list_ids[index]; var p: Dictionary=c.player(pid)
		var rect:=Rect2(52,258+n*53,804,49) if list_view else Rect2(52+(n%3)*274,228+(n/3)*175,257,163)
		var card:=card_at(rect,p.name,select_player.bind(pid),"player_row" if list_view else "player",pid)
		card.set_meta("card_cell",n)
		if not list_view: portraits.request(portrait_data(pid))
	button_at(Rect2(52,751,110,42),"← GERİ",func(): list_page=maxi(0,list_page-1); build()).disabled=list_page==0
	button_at(Rect2(746,751,110,42),"İLERİ →",func(): list_page+=1; build()).disabled=(list_page+1)*9>=list_ids.size()
	if selected=="": return
	portraits.request(portrait_data(selected))
	var member: Dictionary=c.player(selected)
	var loan: Dictionary=member.get("loan",{})
	var blocked: String=c.contracts.transfer_lock(selected)
	if page=="market":
		button_at(Rect2(910,730,218,52),"GÖRÜŞMEYE BAŞLA",negotiate.bind(false),true).disabled=not c.window_open() or blocked!=""
		button_at(Rect2(1140,730,226,52),"KİRALIK TEKLİF",negotiate_loan).disabled=c.contracts.loan_reason(selected,c.world.user)!=""
		button_at(Rect2(910,798,456,42),"KADRONLA KARŞILAŞTIR",func(): comparison.open(self,selected,"market"))
	else:
		button_at(Rect2(910,639,218,45),"İLK 11'İ DEĞİŞTİR",promote,true).disabled=member.club!=c.world.user
		if loan.is_empty():
			button_at(Rect2(1140,639,226,45),"SÖZLEŞME YENİLE",negotiate.bind(true)).disabled=blocked!=""
			button_at(Rect2(910,697,218,42),"SATIŞTAN ÇIKAR" if member.listed else "SATIŞA KOY",toggle_listing.bind(false)).disabled=blocked!=""
			button_at(Rect2(1140,697,226,42),"KİRALIKTAN ÇIKAR" if member.get("loan_listed",false) else "KİRALIK LİSTESİNE KOY",toggle_listing.bind(true)).disabled=blocked!=""
		else:
			var is_owner: bool=loan.owner==c.world.user
			var cost: int=c.contracts.recall_cost(selected) if is_owner else int(loan.option)
			var action: String="recall" if is_owner else "option"
			var label: String="ONAYLA · "+c.money(cost) if pending_action==action else ("GERİ ÇAĞIR" if is_owner else "OPSİYONU KULLAN")
			button_at(Rect2(1140,639,226,45),label,loan_action.bind(action),true).disabled=not c.window_open() or (not is_owner and (cost==0 or member.get("retirement_year",0)>0))
		button_at(Rect2(910,750,218,42),"EN HAZIR İLK 11",func(): c.club().lineup=c.best_eleven(c.world.user); c.save(); build())

		button_at(Rect2(1140,750,226,42),"GELİŞİM & GÖRÜŞME",func(): page="development"; build())

func toggle_listing(is_loan: bool) -> void:
	var c=game.career; var p: Dictionary=c.player(selected)
	if p.club!=c.world.user or c.contracts.transfer_lock(selected)!="": return
	if is_loan: p.loan_listed=not p.get("loan_listed",false); p.listed=false
	else: p.listed=not p.listed; p.loan_listed=false
	c.save(); build()

func loan_action(action: String) -> void:
	var c=game.career
	if pending_action!=action:
		pending_action=action
		status="Geri çağırma tazminatını ve tam maaşı kabul etmek için tekrar seç." if action=="recall" else "Opsiyon bedeli ödenir; aynı maaşla 3 yıllık kalıcı sözleşme yapılır. Onaylamak için tekrar seç."
		build(); return
	var ok: bool=c.contracts.recall(selected) if action=="recall" else c.contracts.buy_option(selected)
	status=("Oyuncu kadrona geri döndü." if action=="recall" else "Oyuncu bonservisiyle kadrona katıldı.") if ok else c.error
	pending_action=""
	if ok: squad_filter=0
	build()

func select_player(pid: String) -> void:
	pending_action=""
	if incoming!="":
		var c=game.career
		var index: int=c.club().lineup.find(pid)
		if index<0: status="Çıkacak oyuncuyu ilk 11 içinden seç."
		elif c.player(pid).keeper!=c.player(incoming).keeper: status="Kaleci yalnızca kaleciyle değiştirilebilir."
		else:
			c.club().lineup[index]=incoming; c.save(); incoming=""; status="İlk 11 güncellendi."
	selected=pid; build()

func promote() -> void:
	var c=game.career
	if not selected in c.club().roster: status="Kiralık giden oyuncu bu takımın maç kadrosunda kullanılamaz."; return
	if not c.available(selected): status="Oyuncu sakat veya cezalı."; return
	if selected in c.club().lineup: status="Bu oyuncu zaten ilk 11'de. Yedek oyuncuyu seçerek başla."; return
	incoming=selected; status="Şimdi ilk 11'den çıkaracağın oyuncuyu seç."

func portrait_data(pid: String) -> Dictionary:
	var p: Dictionary=game.career.player(pid).duplicate(true)
	var club: Dictionary=game.career.world.clubs[p.club] if p.club!="" else game.career.club()
	p.kit=World.kit(club); p.appearance_number=p.appearance_id%99+1
	return p

func build_league() -> void:
	option_at(Rect2(54,177,423,41),World.LEAGUES+game.career.cups.TITLES.values(),division,func(v): division=v; list_page=0; cup_group=0; build())
	var award: Dictionary=game.finale.award_for_division(division)
	if division==World.LEAGUES.size()+1 and not game.career.world.cups.is_empty():
		option_at(Rect2(536,177,308 if award.is_empty() else 172,41),["GRUP A","GRUP B","GRUP C","GRUP D"],cup_group,func(v): cup_group=v; list_page=0; queue_redraw())
	if not award.is_empty():
		button_at(Rect2(720 if division==World.LEAGUES.size()+1 else 536,177,124 if division==World.LEAGUES.size()+1 else 308,41),"TÖRENİ İZLE",func(): game.finale.show_award(award),true)
	for i in range(3): button_at(Rect2(907+i*158,177,149,41),["FİKSTÜR","SONUÇLAR","GOL KRALI"][i],func(): mode=i; list_page=0; build(),mode==i)
	button_at(Rect2(908,751,204,42),"← ÖNCEKİ",func(): list_page=maxi(0,list_page-1); build())
	button_at(Rect2(1162,751,204,42),"SONRAKİ →",func(): list_page+=1; build())

func build_tactics() -> void:
	tactics.build(self)

func build_finance() -> void:
	for i in range(3): button_at(Rect2(73+i*254,366,242,34),["HABERLER","GELİR / GİDER","SEZON ARŞİVİ"][i],func(): mode=i; list_page=0; build(),mode==i)
	var entries: Array=finance_entries()
	list_page=clampi(list_page,0,maxi(0,(entries.size()-1)/5))
	button_at(Rect2(76,754,180,34),"← ÖNCEKİ",func(): list_page-=1; build()).disabled=list_page==0
	button_at(Rect2(654,754,180,34),"SONRAKİ →",func(): list_page+=1; build()).disabled=(list_page+1)*5>=entries.size()
	var offers: Array=game.career.world.offers.filter(func(o): return not o.closed and o.expires>=game.career.world.date)
	offer_page=clampi(offer_page,0,maxi(0,(offers.size()-1)/4))
	for n in range(4):
		if offer_page*4+n>=offers.size(): break
		var o: Dictionary=offers[offer_page*4+n]; var index: int=game.career.world.offers.find(o)
		button_at(Rect2(1223,405+n*80,146,32),"KABUL ET",func(): status="Anlaşma tamamlandı." if game.career.accept_sale(index) else "Anlaşma yapılamadı: kadro, dönem veya bütçe uygun değil."; build(),true)
		button_at(Rect2(1223,443+n*80,146,30),"REDDET",func(): o.closed=true; game.career.save(); build())
	if offers.size()>4:
		button_at(Rect2(910,754,175,34),"← TEKLİFLER",func(): offer_page-=1; build()).disabled=offer_page==0
		button_at(Rect2(1190,754,175,34),"TEKLİFLER →",func(): offer_page+=1; build()).disabled=(offer_page+1)*4>=offers.size()

func finance_entries() -> Array:
	var c=game.career
	if mode==1: return c.world.ledger.filter(func(item): return item.club==c.world.user)
	if mode==2:
		var entries: Array=c.world.history.duplicate(); entries.reverse(); return entries
	return c.world.news

func negotiate(renewal: bool) -> void:
	game.career.begin_deal(selected,renewal)
	fee=game.career.deal.fee; wage=game.career.deal.wage; years=3; promised=1; swap=""
	page="talks"; build()

func negotiate_loan() -> void:
	game.career.contracts.begin(selected)
	fee=game.career.deal.fee; loan_term=1; loan_share=75; loan_option=false
	page="talks"; build()

func number_control(at: Vector2,kind: String,step: int) -> void:
	button_at(Rect2(at,Vector2(52,40)),"−",func(): adjust(kind,-step))
	button_at(Rect2(at+Vector2(352,0),Vector2(52,40)),"+",func(): adjust(kind,step))

func adjust(kind: String,amount: int) -> void:
	match kind:
		"fee": fee=maxi(0,fee+amount)
		"wage": wage=maxi(500,wage+amount)
		"years": years=clampi(years+amount,1,5)
	queue_redraw()

func build_talks() -> void:
	var c=game.career; var d: Dictionary=c.deal
	office=Office.new(); office.position=Vector2(52,181); office.size=Vector2(822,463)
	office.club_data=c.club(); office.guest_data=c.player(d.player); controls.add_child(office)
	if d.stage=="signed": office.react("signed")
	if not d.renewal: button_at(Rect2(934,761,404,38),"KADRONLA KARŞILAŞTIR",func(): comparison.open(self,d.player,"talks"))
	if d.stage=="loan":
		number_control(Vector2(934,295),"fee",maxi(1000,roundi(c.contracts.minimum_fee(d.player,loan_term)*.1/1000.0)*1000))
		option_at(Rect2(934,368,404,42),["YARIM SEZON","SEZON SONUNA KADAR","İKİ SEZON"],loan_term,func(v): loan_term=v; queue_redraw())
		option_at(Rect2(934,447,404,42),["MAAŞIN %50'Sİ","MAAŞIN %75'İ","MAAŞIN %100'Ü"],[50,75,100].find(loan_share),func(v): loan_share=[50,75,100][v]; queue_redraw())
		button_at(Rect2(934,504,404,40),"SATIN ALMA OPSİYONU: AÇIK" if loan_option else "SATIN ALMA OPSİYONU: KAPALI",func(): loan_option=not loan_option; build())
	elif d.stage=="club":
		number_control(Vector2(934,327),"fee",maxi(10000,roundi(c.market.value(c.player(d.player))*.05/10000.0)*10000))
		var items: Array=["Takas yok"]; var ids: Array=[""]
		for pid in c.club().roster:
			if c.player(pid).keeper==c.player(d.player).keeper and c.contracts.transfer_lock(pid)=="": items.append(c.player(pid).name); ids.append(pid)
		option_at(Rect2(934,426,404,43),items,maxi(0,ids.find(swap)),func(v): swap=ids[v])
	elif d.stage=="contract":
		number_control(Vector2(934,295),"wage",maxi(500,roundi(c.terms.salary_floor(c.player(d.player),d,years)*.1/500.0)*500))
		number_control(Vector2(934,383),"years",1)
		option_at(Rect2(934,474,404,43),["Gelişim oyuncusu","Rotasyon","İlk 11"],promised,func(v): promised=v)
	if d.stage in ["club","contract","loan"]:
		button_at(Rect2(934,565,404,55),"TEKLİFİ SUN",submit_offer,true)
	elif d.stage=="sign":
		button_at(Rect2(934,565,404,55),"ANLAŞMAYI İMZALA",func():
			if c.sign_deal(): status=""; build(); office.react("signed")
			else: status=c.error if c.error!="" else "Anlaşma artık geçerli değil. Bütçe ve dönemi kontrol et.",true)
	if d.get("kind","")!="loan" and not d.stage in ["signed","rejected"]:
		button_at(Rect2(52,663,468,37),"PRİMLER & SÖZLEŞME DETAYLARI",func(): page="terms"; build())
	button_at(Rect2(52,824,340,44),"← KARİYERE DÖN" if d.signed else "GÖRÜŞMEDEN AYRIL",func(): go("hub" if d.signed else "market"))
	button_at(Rect2(552,663,298,37),"ANİMASYONU GEÇ",func(): office.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; office.set_process(false))

func submit_offer() -> void:
	var before: String=game.career.deal.stage
	if game.career.deal.get("kind","")=="loan":
		status=game.career.contracts.offer(fee,loan_share,loan_term,loan_option)
		loan_share=game.career.deal.share
	else: status=game.career.offer_deal(fee,wage,years,promised,swap)
	var d: Dictionary=game.career.deal
	fee=d.fee; wage=d.wage; promised=d.role
	if before!=d.stage or d.get("kind","")=="loan": build()
	office.react("reject" if d.stage=="rejected" else ("sign" if d.stage=="sign" else "offer"))

func _draw() -> void:
	art.background(self)
	if page in director_ui.PAGES or page=="terms": director_ui.draw(self)
	match page:
		"entry": art.entry(self)
		"choose": draw_choose()
		"hub": art.hub(self)
		"squad","market": art.players(self)
		"league": draw_league()
		"tactics": art.tactics(self)
		"finance": draw_finance()
		"talks": draw_talks()
		"comparison": comparison.draw(self)
		"training": training_ui.draw(self)

func draw_choose() -> void:
	var c: Dictionary=new_world.clubs[selected_club]
	text("KULÜBÜNÜ SEÇ",Vector2(52,145),24,PAPER,true)
	var club_count: int=choose_ids().size()
	text("%d KULÜP  /  %d HAFTA  ·  " % [club_count,(club_count-1)*2]+("TÜRK VE YABANCI OYUNCULAR" if division==World.Turkey.LEAGUE else ("BAĞIMSIZ KARMA LİG" if division in [0,1] else "ÖZGÜN KULÜPLER")),Vector2(54,237),12,art.MUTED)
	box(Rect2(923,171,474,660),Color("1d3345"),12,Color("3d6250"))
	art.pitch(self,Rect2(952,200,414,300),.16)
	badge(Vector2(1160,273),c,2.1)
	center(c.name,Vector2(1160,401),25,PAPER,true)
	center(c.city+"  /  "+c.year,Vector2(1160,431),13,MUTE)
	var total:=0
	for pid in c.lineup: total+=World.ovr(new_world.players[pid])
	center(str(roundi(total/11.0)),Vector2(1160,504),54,GOLD,true)
	center("TAKIM GÜCÜ",Vector2(1160,530),12,MUTE)
	text("TRANSFER BÜTÇESİ",Vector2(954,574),11,MUTE)
	text(game.career.money(c.budget),Vector2(954,602),24,PAPER,true)
	text("SEZON HEDEFİ  ·  "+c.objective,Vector2(954,643),15,GOLD)
	text("DEVRE SÜRESİ",Vector2(954,674),11,MUTE,true)
	text("RAKİP ZORLUĞU",Vector2(1168,674),11,MUTE,true)
	text("2 × %d dk · Toplam %d dk · Kariyere kaydedilir" % [new_match_settings.half_minutes,new_match_settings.half_minutes*2],Vector2(954,750),12,MUTE)
	box(Rect2(54,724,824,64),Color("23433f"),10)
	text("LİG ŞAMPİYONLUĞU",Vector2(77,750),11,MUTE,true)
	text(game.career.money(World.LEAGUE_CHAMPION_PRIZES[division]),Vector2(77,778),23,GOLD,true)
	text("Ligin değerine göre sezon sonu ödülü",Vector2(375,764),15,PAPER)

func draw_league() -> void:
	if division>=World.LEAGUES.size(): draw_cups(); return
	var c=game.career; var table: Array=c.standings(division)
	box(Rect2(52,232,817,571),Color("122334"),10)
	text("ŞAMPİYONLUK ÖDÜLÜ",Vector2(77,256),11,MUTE,true)
	text(c.money(World.LEAGUE_CHAMPION_PRIZES[division]),Vector2(77,291),29,GOLD,true)
	art.card_icon(self,Vector2(806,273),"trophy",GOLD)
	if c.world.user in table:
		var award: Dictionary=c.world.league_prizes.get("%d:%d" % [c.world.year,division],{})
		var position: int=table.find(c.world.user)+1
		var amount: int=award.get("awards",{}).get(c.world.user,World.league_prize(division,position,table.size()))
		text("ÖDENEN LİG ÖDÜLÜ" if not award.is_empty() else "MEVCUT SIRAYLA TAHMİNİ ÖDÜL",Vector2(351,259),10,MUTE)
		text(c.money(amount),Vector2(351,286),22,art.LIME,true)
	text("KULÜP",Vector2(111,319),11,MUTE)
	for j in range(6): text(["O","G","B","M","AV","P"][j],Vector2(529+j*54,319),12,MUTE)
	for n in range(table.size()):
		var id: String=table[n]; var r: Dictionary=c.world.table[id]; var y:=342+n*25
		if id==c.world.user: box(Rect2(61,y-19,799,24),Color("365542"),3)
		if n<(3 if division==1 else World.CHAMPIONS_PLACES[division]): draw_rect(Rect2(61,y-19,3,24),GOLD)
		elif n>=15 and division==0: draw_rect(Rect2(61,y-19,3,24),Color("e9a08d"))
		text(str(n+1),Vector2(72,y),12,GOLD if n<(3 if division==1 else World.CHAMPIONS_PLACES[division]) else (Color("e9a08d") if n>=15 and division==0 else MUTE))
		badge(Vector2(116,y-5),c.world.clubs[id],.30)
		text(c.world.clubs[id].name,Vector2(135,y),13,PAPER,true)
		for j in range(6): text(str([r.p,r.w,r.d,r.l,r.gf-r.ga,r.pts][j]),Vector2(529+j*54,y),13,GOLD if j==5 else PAPER)
	text(("İLK %d: ŞAMPİYONLAR KUPASI · %d HAFTALIK ÇİFT DEVRE" % [World.CHAMPIONS_PLACES[division],(table.size()-1)*2]) if division>=2 else ("İLK 3: ÜST LİGE YÜKSELİR" if division==1 else "İLK 4: ŞAMPİYONLAR KUPASI  ·  SON 3: ALT LİGE DÜŞER"),Vector2(77,789),10,MUTE)
	box(Rect2(894,232,502,500),Color("17293e"),10)
	if mode==2:
		var ids: Array=c.world.scorers.keys()
		ids=ids.filter(func(pid): return c.player(pid).club!="" and int(c.world.clubs[c.player(pid).club].league)==division)
		ids.sort_custom(func(a,b): return c.world.scorers[a]>c.world.scorers[b])
		list_page=mini(list_page,maxi(0,(ids.size()-1)/8))
		for n in range(8):
			var i:=list_page*8+n
			if i>=ids.size(): break
			text(c.player(ids[i]).name,Vector2(919,283+n*49),15,PAPER,true); text(str(c.world.scorers[ids[i]]),Vector2(1330,283+n*49),22,GOLD,true)
	else:
		var fixtures: Array=c.world.fixtures.filter(func(f): return (f.played if mode==1 else not f.played) and int(f.league)==division)
		if mode==1: fixtures.reverse()
		list_page=mini(list_page,maxi(0,(fixtures.size()-1)/8))
		for n in range(8):
			var i:=list_page*8+n
			if i>=fixtures.size(): break
			var f: Dictionary=fixtures[i]; var y:=278+n*55
			text(World.date_label(f.day),Vector2(919,y),10,MUTE)
			text(c.world.clubs[f.home].short+"   "+("%d – %d" % f.score if f.played else "vs")+"   "+c.world.clubs[f.away].short,Vector2(919,y+24),18,GOLD if c.world.user in [f.home,f.away] else PAPER,true)

func draw_cups() -> void:
	var c=game.career; var key: String=["domestic","champions","super"][division-World.LEAGUES.size()]
	box(Rect2(52,232,817,571),Color("122d2c"),12,Color("355547"))
	box(Rect2(894,232,502,500),Color("17293e"),12)
	text(c.cups.TITLES[key],Vector2(80,278),24,PAPER,true)
	if c.world.cups_pending:
		wrapped("Bu kariyer sezon devam ederken güncellendi. Mevcut lig sonuçların korunuyor; kupalar yeni sezonla birlikte başlayacak.",Vector2(80,364),620,20,MUTE,5)
		return
	var cup: Dictionary=c.world.cups[key]
	var champion: String=cup.champion
	# A small native trophy illustration follows the same gold-and-green menu style.
	var at:=Vector2(775,344)
	draw_arc(at+Vector2(-29,-9),19,PI*.35,PI*1.55,24,GOLD,4,true)
	draw_arc(at+Vector2(29,-9),19,-PI*.55,PI*.65,24,GOLD,4,true)
	draw_colored_polygon(PackedVector2Array([at+Vector2(-31,-32),at+Vector2(31,-32),at+Vector2(22,13),at+Vector2(0,29),at+Vector2(-22,13)]),GOLD)
	draw_line(at+Vector2(0,27),at+Vector2(0,51),GOLD,8,true)
	box(Rect2(at+Vector2(-29,49),Vector2(58,10)),GOLD,3)
	var status_text: String="ŞAMPİYON  /  "+c.world.clubs[champion].name if champion!="" else ("KUPA YOLCULUĞUN DEVAM EDİYOR" if c.world.user in cup.entries else "BU SEZON KATILMIYORSUN")
	if champion=="" and c.world.user in cup.entries:
		var live: Array=c.world.cup_fixtures.filter(func(f): return f.competition==key and not f.played and c.world.user in [f.home,f.away])
		if live.is_empty() and cup.stage>0: status_text="BU KUPADAKİ YOLCULUĞUN TAMAMLANDI"
	wrapped(status_text,Vector2(81,320),601,17,GOLD,2)
	var format_text: String={"domestic":"İki ligden 36 takım. Tek maçlı eleme; ön turdan finale.","champions":"16 takım, 4 grup. İlk ikiler çıkar; çeyrek ve yarı final rövanşlı.","super":"Lig şampiyonu ile ülke kupası şampiyonu karşılaşır."}[key]
	wrapped(format_text,Vector2(81,369),605,14,MUTE,2)
	text(("ŞAMPİYONLUK ÖDÜLÜ ÖDENDİ  ·  " if champion!="" else "FİNALİ KAZANAN  ·  ")+c.money(c.cups.championship_prize(key)),Vector2(81,417),16,GOLD,true)
	if key=="champions":
		var order: Array=c.cups.group_order(cup.groups[cup_group])
		text("GRUP "+String.chr(65+cup_group),Vector2(80,447),13,GOLD,true)
		text("O      AV      PUAN",Vector2(645,447),11,MUTE)
		for n in range(4):
			var id: String=order[n]; var row: Dictionary=cup.table[id]; var y:=483+n*40
			box(Rect2(75,y-25,769,35),Color("345242") if id==c.world.user else Color("173a34"),4)
			text(str(n+1),Vector2(88,y),14,GOLD if n<2 else MUTE)
			text(c.world.clubs[id].name,Vector2(122,y),16,PAPER,true)
			text(c.world.clubs[id].nation,Vector2(568,y),11,MUTE)
			text("%d      %+d      %d" % [row.p,row.gf-row.ga,row.pts],Vector2(651,y),15,GOLD,true)
	else:
		text("BU SEZON",Vector2(81,450),12,MUTE,true)
		text(c.cups.ROUNDS[int(cup.stage)] if key=="domestic" else "SÜPER KUPA FİNALİ",Vector2(81,488),30,GOLD,true)
		text("%d KULÜP  ·  UZATMA + SERİ PENALTILAR" % cup.entries.size(),Vector2(81,527),13,PAPER)
		wrapped("Beraberlikte 2 × 15 dakika oynanır. Eşitlik sürerse seri penaltıları oyuncu özellikleriyle simüle edilir; maç gollerine eklenmez.",Vector2(81,567),715,14,MUTE,3)
	text("KUPA ARŞİVİ",Vector2(81,667),12,GOLD,true)
	var history: Array=c.world.cup_history.filter(func(item): return item.competition==key)
	history.reverse()
	if history.is_empty(): text("İlk kupanın sahibi henüz belli değil.",Vector2(81,708),15,MUTE)
	for n in range(mini(3,history.size())):
		var item: Dictionary=history[n]
		text("%d / %d    %s" % [item.year,item.year+1,c.world.clubs[item.champion].name],Vector2(81,707+n*30),15,PAPER,true)
	if mode==2:
		var ids: Array=cup.scorers.keys(); ids.sort_custom(func(a,b): return cup.scorers[a]>cup.scorers[b])
		list_page=mini(list_page,maxi(0,(ids.size()-1)/7))
		for n in range(7):
			var i:=list_page*7+n
			if i>=ids.size(): break
			text(c.player(ids[i]).name,Vector2(919,282+n*60),15,PAPER,true)
			text(str(cup.scorers[ids[i]]),Vector2(1330,282+n*60),22,GOLD,true)
		if ids.is_empty(): text("İlk gol henüz gelmedi.",Vector2(919,283),16,MUTE)
	else:
		var fixtures: Array=c.world.cup_fixtures.filter(func(f): return f.competition==key and (f.played if mode==1 else not f.played))
		if key=="champions": fixtures=fixtures.filter(func(f): return f.stage>0 or f.group==cup_group)
		fixtures.sort_custom(func(a,b): return a.id<b.id if a.day==b.day else (a.day>b.day if mode==1 else a.day<b.day))
		list_page=mini(list_page,maxi(0,(fixtures.size()-1)/7))
		for n in range(7):
			var i:=list_page*7+n
			if i>=fixtures.size(): break
			var f: Dictionary=fixtures[i]; var y:=273+n*64
			var label: String=c.cups.fixture_label(f).replace(c.cups.TITLES[key]+" · ","")
			text(World.date_label(f.day)+" · "+label,Vector2(919,y),9,MUTE)
			text(c.world.clubs[f.home].short+"   "+("%d – %d" % f.score if f.played else "vs")+"   "+c.world.clubs[f.away].short,Vector2(919,y+25),19,GOLD if c.world.user in [f.home,f.away] else PAPER,true)
			if f.played and not f.penalties.is_empty(): text("PEN. %d–%d  ·  %s" % [f.penalties[0],f.penalties[1],c.world.clubs[f.winner].short],Vector2(919,y+43),10,GOLD)
			elif f.played and f.get("leg",1)==2: text("TOPLAM %d–%d" % f.get("aggregate",f.score),Vector2(919,y+43),10,GOLD)
		if fixtures.is_empty(): wrapped("Bu görünümde maç yok. Tur tamamlandığında yeni eşleşmeler otomatik çekilir.",Vector2(919,284),440,16,MUTE,4)
		center("%d / %d" % [list_page+1,maxi(1,ceili(fixtures.size()/7.0))],Vector2(1144,724),11,MUTE)

func draw_finance() -> void:
	var c=game.career
	for n in range(3):
		var x:=52+n*453
		box(Rect2(x,182,438,144),Color("23433f") if n==0 else Color("152538"),10)
		art.card_icon(self,Vector2(x+376,252),"finance" if n!=1 else "market",art.BLUE if n==2 else art.LIME)
		text(["KULÜP KASASI","TRANSFER BÜTÇESİ","AYLIK MAAŞ YÜKÜ"][n],Vector2(x+24,217),12,MUTE,true)
		text(c.money([c.club().cash,c.club().budget,c.payroll(c.world.user)][n]),Vector2(x+24,279),31,art.LIME,true)
		var amount: float=[c.club().cash,c.club().budget,c.payroll(c.world.user)][n]
		box(Rect2(x+24,303,280,4),Color("33495a"),2)
		box(Rect2(x+24,303,280*clampf(amount/maxf(1,c.club().cash),0,1),4),art.BLUE if n==2 else art.LIME,2)
	box(Rect2(52,351,811,454),Color("152538"),10)
	var entries: Array=finance_entries()
	for n in range(5):
		var index:=list_page*5+n
		if index>=entries.size(): break
		var item: Dictionary=entries[index]; var y:=434+n*61
		if mode==0:
			text(World.date_label(item.day)+"  /  "+item.title,Vector2(77,y),12,PAPER,true)
			text(item.body.left(89),Vector2(77,y+22),13,MUTE)
		elif mode==1:
			text(World.date_label(item.day)+"  /  "+item.label.left(45),Vector2(77,y),13,PAPER,true)
			text(("+" if item.amount>0 else "")+c.money(item.amount),Vector2(77,y+23),16,GOLD if item.amount>=0 else Color("e9a08d"),true)
		else:
			text("%d / %d  ·  %s  ·  %d. SIRA" % [item.year,item.year+1,World.LEAGUES[item.league],item.position],Vector2(77,y),14,PAPER,true)
			text("ŞAMPİYON  "+c.world.clubs[item.champion].name,Vector2(77,y+24),14,GOLD)
	if entries.is_empty(): text("Henüz kayıt yok. Takvimi ilerlettikçe burada görünecek.",Vector2(77,455),16,MUTE)
	center("%d / %d" % [list_page+1,maxi(1,ceili(entries.size()/5.0))],Vector2(453,778),12,MUTE)
	box(Rect2(884,351,512,454),Color("142a3b"),10)
	text("GELEN TRANSFER TEKLİFLERİ",Vector2(908,389),15,GOLD,true)
	var offers: Array=c.world.offers.filter(func(o): return not o.closed and o.expires>=c.world.date)
	for n in range(4):
		if offer_page*4+n>=offers.size(): break
		var o: Dictionary=offers[offer_page*4+n]
		text(c.player(o.player).name.left(25),Vector2(911,427+n*80),13,PAPER,true)
		text(("KİRALIK · " if o.get("kind","")=="loan" else "")+c.world.clubs[o.buyer].short+"  ·  "+c.money(o.fee),Vector2(911,450+n*80),11,GOLD)
		text("MAAŞ %"+str(o.share)+" · SEZON SONUNA KADAR" if o.get("kind","")=="loan" else "SON GÜN  "+World.date_label(o.expires),Vector2(911,469+n*80),9,MUTE)
	if offers.is_empty():
		art.card_icon(self,Vector2(1139,491),"market",art.BLUE)
		center("TRANSFER MASASI HAZIR",Vector2(1140,589),21,PAPER,true)
		wrapped("Oyuncularını satış veya kiralık listesine koy. Gelen teklifleri burada değerlendirebilirsin.",Vector2(920,638),433,17,MUTE,4)

func draw_talks() -> void:
	var c=game.career; var d: Dictionary=c.deal; var p: Dictionary=c.player(d.player)
	text("GÖRÜŞME ODASI",Vector2(53,145),25,PAPER,true)
	box(Rect2(899,181,497,602),Color("172a3d"),12,Color("41634d"))
	text(p.name,Vector2(931,230),25,PAPER,true)
	text({"loan":"KİRALIK SÖZLEŞMESİ","club":"KULÜPLER ARASI GÖRÜŞME","contract":"OYUNCU SÖZLEŞMESİ","sign":"İMZA ÖNCESİ ÖZET","signed":"KULÜBE HOŞ GELDİN","rejected":"GÖRÜŞME SONA ERDİ"}.get(d.stage,""),Vector2(934,258),11,GOLD,true)
	if d.stage=="loan":
		text("KİRALAMA BEDELİ",Vector2(934,282),10,MUTE)
		center(c.money(fee),Vector2(1136,323),24,PAPER,true)
		text("SÜRE · BİTİŞ "+World.date_label(c.contracts.end_day(loan_term)),Vector2(934,358),10,MUTE)
		text("AYLIK PAYIN  "+c.money(roundi(p.wage*loan_share/100.0)),Vector2(934,436),11,GOLD)
		text("OPSİYON BEDELİ  "+c.money(roundi(c.market.value(p)*1.2)) if loan_option else "Bonservis oyuncunun kulübünde kalır.",Vector2(934,553),11,MUTE)
	elif d.stage=="club":
		text("BONSERVİS TEKLİFİ",Vector2(934,311),11,MUTE)
		center(c.money(fee),Vector2(1136,356),24,PAPER,true)
		text("OYUNCU TAKASI",Vector2(934,410),11,MUTE)
	elif d.stage=="contract":
		center(c.money(wage)+" / AY",Vector2(1136,323),21,PAPER,true)
		text("SÖZLEŞME SÜRESİ",Vector2(934,370),11,MUTE); center(str(years)+" YIL",Vector2(1136,412),24,PAPER,true)
		text("TAKIMDAKİ ROLÜ",Vector2(934,460),11,MUTE)
	else:
		var lines: Array=["BONSERVİS  "+c.money(d.fee),"MAAŞ / AY  "+c.money(d.wage),"SÜRE  "+str(d.years)+" YIL","ROL  "+["GELİŞİM","ROTASYON","İLK 11"][d.role],"KALAN KASA  "+c.money(c.club().cash-(0 if d.signed else int(d.fee)))]
		if d.get("kind","")=="loan":
			lines=["KİRALAMA BEDELİ  "+c.money(d.fee),"MAAŞ PAYIN  %"+str(d.share)+" · "+c.money(roundi(p.wage*d.share/100.0)),"BİTİŞ  "+World.date_label(c.contracts.end_day(d.term)),"OPSİYON  "+c.money(d.option) if d.option>0 else "SATIN ALMA OPSİYONU YOK",lines[4]]
		for n in range(lines.size()): text(lines[n],Vector2(934,325+n*41),17,PAPER,true)
	wrapped(d.response,Vector2(934,662),400,16,GOLD,4)
	box(Rect2(52,714,822,69),Color("1a3343"),8)
	text("OVR %d  ·  %s  ·  %d YAŞ" % [World.ovr(p),World.ROLES[p.role],p.age],Vector2(77,744),17,PAPER,true)
	text("Bedel: güç, yaş, potansiyel, kulüp ve kalan sözleşme süresi.",Vector2(77,769),13,MUTE)

func wrapped(value: String,at: Vector2,width: float,size_value: int,color: Color,limit: int) -> void:
	var line := ""; var row:=0
	for word in value.split(" "):
		var next:=line+(" " if line!="" else "")+word
		if font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x>width and line!="":
			text(line,at+Vector2(0,row*(size_value+7)),size_value,color); row+=1; line=word
			if row>=limit: return
		else: line=next
	if row<limit: text(line,at+Vector2(0,row*(size_value+7)),size_value,color)
