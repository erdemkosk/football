extends "res://scripts/menu_screen.gd"
const Preview = preload("res://scripts/kit_preview.gd")
const SquadCard = preload("res://scripts/squad_card.gd")
const MINT := Color("8ee4bd")
var reserve_buttons: Array[Button] = []
var preview_reserve := -1
var swap_action: Button
var undo_button: Button
var history: Array = []
const ROLES := [
	["KL","SLB","STP","STP","SĞB","SO","MO","MO","SA","SF","SF"],
	["KL","SLB","STP","STP","SĞB","MO","MDO","MO","SLK","SF","SĞK"],
	["KL","STP","STP","STP","SKB","MO","MDO","MO","SĞKB","SF","SF"]]
var game
var stage := "teams"
var pane := 0
var selected_slot := 9
var prematch := true
var previous_state := "menu"
var previous_freeze := false
var status := ""
var controls: Control
var previews: Array = []
var slot_buttons: Array[Button] = []
var first_focus: Button
var time_button: Button
var age := 0.0

func _ready() -> void:
	setup_style()
	visible=false
	controls=Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(controls)

func _process(delta: float) -> void:
	if visible:
		age+=delta
		queue_redraw()

func open_selection() -> void:
	game.return_menu()
	game.clubs.apply()
	game.state="setup"
	game.ball.freeze=true
	prematch=true
	stage="teams"
	status=""
	visible=true
	build()

func open_tactics(is_prematch: bool=false) -> void:
	prematch=is_prematch
	if not prematch:
		previous_state=game.before_pause if game.state=="paused" else game.state
		previous_freeze=game.ball.freeze if game.state!="paused" else previous_state=="replay"
		game.before_pause=previous_state
		game.state="paused"
		game.ball.freeze=true
		game.charging=false; game.charge=0; game.cancel_pass()
		game.goalkeeping.stop_rush()
		game.set_pieces.button=0; game.set_pieces.power=0
	game.controller.held.clear()
	stage="tactics"
	history.clear()
	preview_reserve=-1
	selected_slot=mini(game.controlled,10)
	pane=0
	status=""
	visible=true
	build()

func clear_controls() -> void:
	previews.clear()
	slot_buttons.clear()
	reserve_buttons.clear()
	swap_action=null
	undo_button=null
	for child in controls.get_children(): controls.remove_child(child); child.queue_free()

func build() -> void:
	clear_controls()
	if stage=="teams": build_teams()
	else: build_tactics()
	queue_redraw()
	if first_focus!=null: first_focus.grab_focus()

func build_teams() -> void:
	for side in range(2):
		var x := 54.0 if side==0 else 760.0
		var preview := Preview.new()
		preview.position=Vector2(x+166,324)
		preview.size=Vector2(294,294)
		controls.add_child(preview)
		preview.show_kit(game.clubs.kit(side),side)
		previews.append(preview)
		make_button(controls,Rect2(x+30,688,62,48),"‹",cycle_team.bind(side,-1))
		make_button(controls,Rect2(x+534,688,62,48),"›",cycle_team.bind(side,1))
		make_button(controls,Rect2(x+176,625,274,44),"FORMA  B" if game.clubs.alternate[side] else "FORMA  A",toggle_kit.bind(side))
	make_button(controls,Rect2(54,826,190,48),"← Ana menü",back)
	make_button(controls,Rect2(280,826,244,48),"Hava: "+game.weather.label(),cycle_weather)
	make_button(controls,Rect2(550,826,244,48),"Zorluk: "+["Kolay","Normal","Zor"][game.management.difficulty],cycle_difficulty)
	first_focus=make_button(controls,Rect2(1060,817,326,62),"KADRO & TAKTİK  →",open_tactics.bind(true),true)
	time_button=make_button(controls,Rect2(820,826,216,48),"Maç: "+game.stadium.light_rig.label(),cycle_time)

func cycle_team(side: int,direction: int) -> void:
	game.clubs.choose(side,game.clubs.selected[side]+direction)
	build()
	# Keep the navigation focus on the arrow just used.
	controls.get_child(side*4+(1 if direction<0 else 2)).grab_focus()

func toggle_kit(side: int) -> void:
	game.clubs.alternate[side]=not game.clubs.alternate[side]
	game.clubs.apply()
	build()
	controls.get_child(side*4+3).grab_focus()

func cycle_weather() -> void:
	game.weather.select((game.weather.preset+1)%3,true)
	build()
	controls.get_child(9).grab_focus()

func cycle_time() -> void:
	game.stadium.light_rig.select(1-game.stadium.light_rig.period)
	build()
	time_button.grab_focus()

func cycle_difficulty() -> void:
	game.management.difficulty=(game.management.difficulty+1)%3
	build()
	controls.get_child(10).grab_focus()

func slot_position(index: int) -> Vector2:
	var pos: Vector2=game.management.SHAPES[game.management.formation][index]
	var y := maxf(252,246+(pos.y+10)*5.65)
	# Keep readable gaps between cards while preserving the formation's shape.
	if index==0: y=572
	elif index==6 and game.management.formation!=0: y-=12
	return Vector2(482+pos.x*12,y)

func player_data(kind: String,index: int) -> Dictionary:
	var data: Dictionary
	if kind=="slot":
		var p=game.players[index]
		data={"name":p.display_name,"shirt":p.shirt_number,"keeper":p.keeper,"energy":1.0 if prematch else p.energy,"yellow":0 if prematch else p.yellow_cards,"dismissed":false if prematch else p.dismissed,"role":ROLES[game.management.formation][index],"status":""}
		if not prematch:
			if p.dismissed: data.status="İHRAÇ"
			elif game.management.transit.has(index): data.status="DEĞİŞİYOR"
			elif not pending_for(index).is_empty(): data.status="ÇIKACAK"
	else:
		data=game.management.bench[0][index].duplicate()
		data.merge({"energy":1.0,"yellow":0,"dismissed":false,"role":"KL" if data.keeper else "SAHA","status":""})
		if data.used: data.status="OYUNA GİRDİ"
		for item in game.management.pending:
			if item.slot<11 and item.reserve==index: data.status="GİRECEK"
		for slot in game.management.transit:
			if slot<11 and game.management.transit[slot].reserve==index: data.status="DEĞİŞİYOR"
	data.kit=game.clubs.kit(0).duplicate()
	if data.keeper: data.kit.primary=Color("d7b83c"); data.kit.accent=Color("17272b")
	return data

func pending_for(slot: int) -> Dictionary:
	for item in game.management.pending:
		if item.slot==slot: return item
	return {}

func replacement_reason(slot: int,reserve: int) -> String:
	if slot<0 or slot>10 or reserve<0 or reserve>6: return "Bir oyuncu ve yedek seç."
	var p=game.players[slot]
	var b: Dictionary=game.management.bench[0][reserve]
	if p.keeper!=b.keeper: return "Kaleci yalnızca yedek kaleciyle değişir."
	if prematch: return ""
	if game.training: return "Antrenmanda oyuncu değişikliği yok."
	if p.dismissed: return "İhraç edilen oyuncu değiştirilemez."
	if game.management.transit.has(slot): return "Bu oyuncu şu anda değişiyor."
	if b.used: return "Bu yedek maçta zaten kullanıldı."
	var count: int=game.management.used[0]
	for other in game.management.transit:
		if other<11:
			if game.management.transit[other].reserve==reserve: return "Bu yedek şu anda sahaya giriyor."
			if game.management.transit[other].phase=="out": count+=1
	for item in game.management.pending:
		if item.slot<11:
			count+=1
			if item.slot==slot: return "Bu oyuncunun bekleyen değişikliğini önce iptal et."
			if item.reserve==reserve: return "Bu yedek başka bir oyuncu için seçildi."
	if count>=5: return "Beş oyuncu değişikliği hakkı doldu."
	return ""

func make_card(kind: String,index: int,rect: Rect2) -> Button:
	var card := SquadCard.new()
	card.frontend=self; card.kind=kind; card.index=index; card.data=player_data(kind,index)
	card.active=kind=="slot" and index==selected_slot
	card.eligible=kind=="slot" or replacement_reason(selected_slot,index)==""
	if kind=="bench" and not card.eligible:
		card.data.unavailable="MEVKİ UYUMSUZ" if game.players[selected_slot].keeper!=card.data.keeper else "SEÇİLEMİYOR"
	card.position=rect.position; card.size=rect.size
	controls.add_child(card)
	return card

func build_tactics() -> void:
	for i in range(11):
		slot_buttons.append(make_card("slot",i,Rect2(slot_position(i)-Vector2(56,38),Vector2(112,76))))
	make_button(controls,Rect2(925,45,219,48),"İLK 11 & YEDEKLER",set_pane.bind(0),pane==0)
	make_button(controls,Rect2(1158,45,242,48),"TAKTİK PLANI",set_pane.bind(1),pane==1)
	if pane==0:
		for j in range(7):
			reserve_buttons.append(make_card("bench",j,Rect2(52+j*192,694,184,92)))
		swap_action=make_button(controls,Rect2(976,564,400,44),"YEDEK SEÇ",apply_preview,true)
		update_swap_action()
	else:
		var m=game.management
		var rows := [["Diziliş",m.FORMATIONS,m.formation,"formation"],["Oyun anlayışı",["Savunmacı","Dengeli","Hücumcu"],m.mentality,"mentality"],["Pres yoğunluğu",["Geri çekil","Dengeli","Yoğun"],m.pressing,"pressing"],["Savunma çizgisi",["Derin","Normal","Önde"],m.line_height,"line_height"]]
		for i in range(rows.size()):
			var row: Array=rows[i]
			for j in range(3):
				var button := make_button(controls,Rect2(976+j*136,234+i*99,128,42),row[1][j],set_tactic.bind(row[3],j),j==row[2])
				button.add_theme_font_size_override("font_size",14)
	make_button(controls,Rect2(40,834,222,49),"← Takım seçimi" if prematch else "← Maça dön",back)
	undo_button=make_button(controls,Rect2(848,834,240,49),"X  SON İŞLEMİ GERİ AL",undo_last)
	undo_button.add_theme_font_size_override("font_size",12)
	undo_button.disabled=history.is_empty()
	first_focus=make_button(controls,Rect2(1112,834,288,49),"MAÇA ÇIK  →" if prematch else "MAÇA DÖN  →",confirm,true)

func preview_player(kind: String,index: int) -> void:
	preview_reserve=index if kind=="bench" else -1
	update_swap_action()
	queue_redraw()

func update_swap_action() -> void:
	if not is_instance_valid(swap_action): return
	var pending := pending_for(selected_slot)
	if not pending.is_empty():
		swap_action.text="BU DEĞİŞİKLİĞİ İPTAL ET"
		swap_action.disabled=false
	else:
		swap_action.text="DEĞİŞTİR  →" if preview_reserve>=0 else "YEDEK SEÇ"
		swap_action.disabled=preview_reserve<0 or replacement_reason(selected_slot,preview_reserve)!=""

func apply_preview() -> void:
	if not pending_for(selected_slot).is_empty(): cancel_selected()
	elif preview_reserve>=0: select_reserve(preview_reserve)

func select_slot(index: int) -> void:
	selected_slot=index
	pane=0
	preview_reserve=-1
	status=""
	build()
	# Selecting the outgoing player takes the pad straight to an eligible reserve.
	for j in range(7):
		if replacement_reason(index,j)=="": reserve_buttons[j].grab_focus(); return
	slot_buttons[index].grab_focus()

func set_pane(value: int) -> void:
	pane=value
	build()
	controls.get_child(11+pane).grab_focus()

func set_tactic(property: String,value: int) -> void:
	game.management.set(property,value)
	game.management.apply_formation()
	build()
	controls.get_child(13+["formation","mentality","pressing","line_height"].find(property)*3+value).grab_focus()

func select_reserve(index: int) -> void:
	var pending := pending_for(selected_slot)
	if not pending.is_empty() and pending.reserve==index:
		cancel_selected()
		return
	var reason := replacement_reason(selected_slot,index)
	if reason!="":
		status=reason; preview_reserve=index; update_swap_action(); queue_redraw(); return
	var old_name: String=game.players[selected_slot].display_name
	var new_name: String=game.management.bench[0][index].name
	if prematch:
		history.append({"lineup":game.clubs.lineups[0].duplicate(),"bench":game.clubs.reserves[0].duplicate(),"slot":selected_slot})
		game.clubs.swap_starter(selected_slot,index)
		status=old_name+" → "+new_name+" · İlk 11 güncellendi."
	else:
		var before: int=game.management.pending.size()
		status=game.management.queue_sub(selected_slot,index)
		if game.management.pending.size()>before: history.append({"slot":selected_slot,"reserve":index})
	preview_reserve=-1
	build()
	slot_buttons[selected_slot].grab_focus()

func cancel_selected() -> void:
	var slot := selected_slot
	game.management.pending=game.management.pending.filter(func(item): return item.slot!=slot)
	history=history.filter(func(item): return item.slot!=slot)
	status="Bekleyen değişiklik iptal edildi."
	preview_reserve=-1
	build()
	slot_buttons[slot].grab_focus()

func cancel_pending() -> void:
	game.management.pending=game.management.pending.filter(func(item): return game.players[item.slot].team!=0)
	history.clear()
	status="Bekleyen değişiklikler iptal edildi."
	build()
	slot_buttons[selected_slot].grab_focus()

func undo_last() -> void:
	if history.is_empty(): return
	var item: Dictionary=history.pop_back()
	selected_slot=item.slot
	if prematch:
		game.clubs.lineups[0]=item.lineup
		game.clubs.reserves[0]=item.bench
		game.clubs.apply()
	else:
		game.management.pending=game.management.pending.filter(func(entry): return entry.slot!=item.slot or entry.reserve!=item.reserve)
	status="Son değişiklik geri alındı."
	preview_reserve=-1
	build()
	slot_buttons[selected_slot].grab_focus()

func can_drop_player(value: Variant,kind: String,index: int) -> bool:
	if not value is Dictionary or value.get("squad",-1)!=get_instance_id(): return false
	if value.get("kind","")==kind or value.get("kind","") not in ["slot","bench"]: return false
	if kind not in ["slot","bench"] or not value.get("index") is int: return false
	var slot: int=index if kind=="slot" else int(value.index)
	var reserve: int=index if kind=="bench" else int(value.index)
	return replacement_reason(slot,reserve)==""

func drop_player(value: Variant,kind: String,index: int) -> void:
	if not can_drop_player(value,kind,index): return
	selected_slot=index if kind=="slot" else int(value.index)
	select_reserve(index if kind=="bench" else int(value.index))

func confirm() -> void:
	visible=false
	clear_controls()
	game.controller.held.clear()
	if prematch:
		game.start_match(false,true)
	else:
		game.state=previous_state
		game.ball.freeze=previous_freeze
		if game.state in ["restart","set_piece","halftime"]:
			game.management.prepare_substitutions()
			if game.state=="set_piece" and not game.management.transit.is_empty():
				game.state="restart"
				game.set_pieces.prepare()

func back() -> void:
	if stage=="tactics" and prematch:
		stage="teams"; status=""; build()
	elif not prematch: confirm()
	else:
		visible=false
		clear_controls()
		game.return_menu()

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: back(); get_viewport().set_input_as_handled()
		elif event.keycode==KEY_Z and stage=="tactics": undo_last(); get_viewport().set_input_as_handled()
		elif event.keycode==KEY_P: game.match_menu.open_menu(); get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		game.controller.using_gamepad=true
		if event.button_index==JOY_BUTTON_B: back(); get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_X and stage=="tactics": undo_last(); get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_START: confirm() if stage=="tactics" else open_tactics(true); get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_BACK: game.match_menu.open_menu(); get_viewport().set_input_as_handled()
		elif stage=="tactics" and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			set_pane(0 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1)
			get_viewport().set_input_as_handled()

func _draw() -> void:
	if stage=="teams": draw_teams()
	else: draw_tactics()
	if stage=="teams":
		if game.controller.using_gamepad: game.controller.Glyphs.draw_hints(self,Vector2(1290,779),[["VIEW","Ayarlar"]],game.controller.family,font,24,10)
		else: text("P  AYARLAR",Vector2(1300,786),10,MUTE)

func draw_teams() -> void:
	backdrop("MAÇI SEN KUR.","Takımını seç. Rakibini belirle. Kendi oyununu sahaya taşı.","01  TAKIMLAR     /     02  TAKTİK")
	for side in range(2):
		var x := 54.0 if side==0 else 760.0
		var data: Dictionary=game.clubs.data(side)
		var colors: Dictionary=game.clubs.kit(side)
		box(Rect2(x,231,626,533),PANEL,10,Color("2a464c"))
		draw_rect(Rect2(x+1,232,624,4),colors.primary)
		text("SENİN TAKIMIN" if side==0 else "RAKİP TAKIM",Vector2(x+28,261),11,GOLD,true)
		badge(Vector2(x+65,315),data,1.15)
		text(data.name,Vector2(x+124,308),29,PAPER,true)
		text(data.city+"  /  "+data.year,Vector2(x+126,334),12,MUTE)
		draw_arc(Vector2(x+313,484),121,0,TAU,80,Color(colors.primary,0.14),2,true)
		draw_circle(Vector2(x+313,484),115,Color(colors.primary,0.035))
		text(data.short,Vector2(x+30,572),65,Color(colors.primary,0.13),true)
		center(data.style,Vector2(x+313,603),11,MUTE,true)
		center("%02d  /  %02d" % [game.clubs.selected[side]+1,game.clubs.CLUBS.size()],Vector2(x+313,719),17,PAPER,true)
	center("VS",Vector2(720,503),25,GOLD,true)

func draw_tactics() -> void:
	draw_rect(Rect2(0,0,1440,900),Color("07171e"))
	for i in range(20): draw_line(Vector2(800+i*45,0),Vector2(390+i*45,900),Color(0.15,0.34,0.32,0.06),1)
	badge(Vector2(68,67),game.clubs.data(0),0.94)
	text("TAKIM YÖNETİMİ",Vector2(113,65),31,PAPER,true)
	text(game.team_name(0)+"  /  "+("MAÇ ÖNCESİ" if prematch else "%02d'  ·  %d – %d" % [int(game.match_time/game.LENGTH*90),game.score[0],game.score[1]]),Vector2(115,88),12,MUTE)
	draw_line(Vector2(40,113),Vector2(1400,113),Color("284447"),1)
	text("İLK 11",Vector2(42,140),11,MINT,true)
	text("Oyuncuyu seç → yedeği seç. İstersen sürükleyip bırak.",Vector2(115,140),12,MUTE)
	text("SINIRSIZ KADRO DÜZENLEME" if prematch else "DEĞİŞİKLİK  %d / 5   ·   BEKLEYEN  %d" % [game.management.used[0],game.management.pending.filter(func(item): return item.slot<11).size()],Vector2(980,140),11,MINT,true)
	box(Rect2(40,155,886,476),Color("102d32"),12,Color("345455"))
	text(game.management.FORMATIONS[game.management.formation],Vector2(65,187),22,PAPER,true)
	text("HÜCUM ↑",Vector2(824,186),10,MUTE,true)
	var pitch := Rect2(78,209,810,402)
	for i in range(8): draw_rect(Rect2(pitch.position+Vector2(0,i*pitch.size.y/8),Vector2(pitch.size.x,pitch.size.y/8)),Color(0.27,0.49,0.41,0.10 if i%2 else 0.025))
	var line := Color(0.49,0.66,0.59,0.28)
	draw_rect(pitch,line,false,1)
	draw_line(Vector2(78,410),Vector2(888,410),line,1)
	draw_arc(Vector2(483,410),58,0,TAU,72,line,1,true)
	draw_circle(Vector2(483,410),2,line)
	for y in [209,536]: draw_rect(Rect2(326,y,314,75),line,false,1)
	for y in [209,585]: draw_rect(Rect2(414,y,138,26),line,false,1)
	box(Rect2(952,155,448,476),Color("10272f"),12,Color("2a454c"))
	if pane==0: draw_comparison()
	else:
		text("OYUN PLANI",Vector2(976,186),12,MINT,true)
		for i in range(4): text(["DİZİLİŞ","OYUN ANLAYIŞI","PRES YOĞUNLUĞU","SAVUNMA ÇİZGİSİ"][i],Vector2(978,222+i*99),10,MUTE,true)
		text("Yoğun pres daha fazla enerji tüketir.",Vector2(978,592),12,MUTE)
	box(Rect2(40,649,1360,153),Color("0c2028"),10,Color("294248"))
	if pane==0:
		text("YEDEK KULÜBESİ",Vector2(56,676),12,PAPER,true)
		text("7 OYUNCU  ·  SEÇEREK DEĞİŞTİR  ·  SÜRÜKLEYEREK SAHAYA TAŞI",Vector2(905,676),10,MUTE)
	else:
		text("TAKTİK ÖZETİ",Vector2(65,680),12,MINT,true)
		var items := [["DİZİLİŞ",game.management.FORMATIONS[game.management.formation]],["YAKLAŞIM",["Savunmacı","Dengeli","Hücumcu"][game.management.mentality]],["PRES",["Geri çekil","Dengeli","Yoğun"][game.management.pressing]],["SAVUNMA",["Derin","Normal","Önde"][game.management.line_height]]]
		for i in range(4):
			text(items[i][0],Vector2(66+i*335,716),10,MUTE,true)
			text(items[i][1],Vector2(66+i*335,748),24,PAPER,true)
			if i<3: draw_line(Vector2(365+i*335,701),Vector2(365+i*335,772),Color("2b4349"),1)
	if game.controller.using_gamepad:
		game.controller.Glyphs.draw_hints(self,Vector2(42,818),[["LS / D-PAD","Gez"],["A","Seç"],["B","Geri"],["LB / RB","Sekme"],["X","Geri al"],["VIEW","Ayarlar"]],game.controller.family,font,23,10,20)
	else: text("YÖN TUŞLARI  GEZ    ENTER  SEÇ    ESC  GERİ    Z  GERİ AL    P  AYARLAR",Vector2(42,819),10,MUTE)
	text(status.left(74) if status!="" else "Formayı seç. Değişikliği sahaya yansıt.",Vector2(284,863),12,MINT)

func draw_player_detail(data: Dictionary,at: Vector2,title: String,color: Color) -> void:
	text(title,at,10,color,true)
	SquadCard.shirt(self,at+Vector2(38,51),68,data.kit,data.shirt,bold)
	text(data.name,at+Vector2(90,32),26,PAPER,true)
	text("%02d  ·  %s" % [data.shirt,"KALECİ" if data.keeper else data.role],at+Vector2(91,55),12,MUTE)
	var energy: float=data.energy
	var tint := SquadCard.energy_color(energy)
	text("ENERJİ",at+Vector2(91,78),10,MUTE,true)
	text("%d%%" % roundi(energy*100),at+Vector2(349,78),12,tint,true)
	box(Rect2(at+Vector2(91,88),Vector2(295,5)),Color("2c4549"),2)
	box(Rect2(at+Vector2(91,88),Vector2(maxf(2,295*energy),5)),tint,2)

func draw_comparison() -> void:
	text("OYUNCU DEĞİŞİKLİĞİ",Vector2(976,186),12,MINT,true)
	var outgoing := player_data("slot",selected_slot)
	draw_player_detail(outgoing,Vector2(977,215),"SEÇİLİ OYUNCU",Color("eca18b"))
	var pending := pending_for(selected_slot)
	var incoming: int=pending.reserve if not pending.is_empty() else preview_reserve
	draw_line(Vector2(978,328),Vector2(1375,328),Color("2a444b"),1)
	if incoming>=0:
		draw_player_detail(player_data("bench",incoming),Vector2(977,357),"GİRECEK · BEKLEMEDE" if not pending.is_empty() else "GİRECEK OYUNCU",MINT)
		var reason := replacement_reason(selected_slot,incoming) if pending.is_empty() else "İlk duraklamada kenardan oyuna girecek."
		text(reason if reason!="" else ("İlk 11 anında güncellenir." if prematch else "İlk duraklamada sahaya girecek."),Vector2(977,495),12,MUTE)
		var difference: int=roundi((1.0-float(outgoing.energy))*100)
		if reason=="" and difference>0: text("+%d PUAN ENERJİ · TAZE OYUNCU" % difference,Vector2(977,526),11,MINT,true)
	else:
		text("TAZE BİR HAMLE.",Vector2(977,383),24,PAPER,true)
		text("Alttaki yedeklerden birini seç.",Vector2(978,416),14,MUTE)
		text("Oyuncuları sürükleyerek de",Vector2(978,442),14,MUTE)
		text("doğrudan değiştirebilirsin.",Vector2(978,466),14,MUTE)
		if outgoing.dismissed: text("İHRAÇ · BU OYUNCU DEĞİŞTİRİLEMEZ",Vector2(978,526),11,Color("f28172"),true)
		elif outgoing.yellow>0: text("SARI KART · İKİNCİ KARTA DİKKAT",Vector2(978,526),11,GOLD,true)
