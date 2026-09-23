extends "res://scripts/menu_screen.gd"
const Preview = preload("res://scripts/kit_preview.gd")
const SquadCard = preload("res://scripts/squad_card.gd")
const World = preload("res://scripts/career_world.gd")
const SelectionArt = preload("res://scripts/quick_match_art.gd")
const MINT := Color("a8e1be")
const Portraits = preload("res://scripts/squad_portraits.gd")
var portraits := Portraits.new()
const GROUPS := ["KALECİ","DEFANS","ORTA SAHA","FORVET"]
const ROLE_COLORS := [Color("ead091"),Color("a4c9eb"),Color("a8dfc0"),Color("f0b29a")]
const LINES := [
	[[0],[1,2,3,4],[5,6,7,8],[9,10]],
	[[0],[1,2,3,4],[5,6,7],[8,9,10]],
	[[0],[1,2,3],[4,5,6,7,8],[9,10]]]

func slot_group(index: int) -> int:
	return game.management.slot_role(index)

func tactical_lines() -> Array:
	var lines: Array=[]
	for row in LINES[game.management.formation]:
		var actors: Array=[]
		for slot in row: actors.append(game.management.actor_at_slot(slot))
		lines.append(actors)
	return lines

func natural_group(shirt: int,keeper: bool) -> int:
	if game.career.in_match:
		for p in game.players:
			if p.team==0 and p.shirt_number==shirt and p.natural_position>=0: return p.natural_position
	return game.management.natural_role(shirt,keeper)

var reserve_buttons: Array[Button] = []
var preview_reserve := -1
var swap_action: Button
var undo_button: Button
var history: Array = []
var swap_stage := "browse"
var swap_source: Dictionary = {}
var swap_target: Dictionary = {}
var inspected := {"kind":"slot","index":9}
var pane_focus := ["", ""]
var tab_buttons: Array[Button] = []
var tactic_buttons: Array = []
var back_button: Button
var plan_button: Button
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
var weather_button: Button
var difficulty_button: Button
var team_left: Array[Button] = []
var team_right: Array[Button] = []
var team_select: Array[Button] = []
var selection_ratings: Array[Dictionary] = []
var enter_age := 1.0
var league_buttons: Array[Button] = []
var kit_buttons: Array[Button] = []
var go_button: Button
var overlay: Control
var picked := [false, false]
var pick_step := 0
var select_wait := 0.0
var shown_ovr := [0.0, 0.0]
var ovr_punch := [0.0, 0.0]
var ovr_target := [0, 0]
var age := 0.0
var introducing := false
var intro_wait := 0.0

func _ready() -> void:
	setup_style()
	add_child(portraits)
	portraits.portrait_ready.connect(func(_key):
		queue_redraw()
		for card in slot_buttons+reserve_buttons: card.queue_redraw())
	visible=false
	controls=Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(controls)
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(draw_team_overlays)
	add_child(overlay)

func _process(delta: float) -> void:
	if visible:
		age+=delta
		enter_age+=delta
		queue_redraw()
		if overlay: overlay.queue_redraw()
		if stage=="teams":
			for side in range(2):
				var target := float(selection_ratings[side].gen) if selection_ratings.size()>side else float(team_ovr(side))
				if int(ovr_target[side])!=int(target):
					ovr_target[side]=int(target)
					ovr_punch[side]=1.0
				shown_ovr[side]=move_toward(float(shown_ovr[side]),target,delta*64.0)
				ovr_punch[side]=move_toward(float(ovr_punch[side]),0.0,delta*3.4)
	if select_wait>0:
		select_wait=maxf(0,select_wait-delta)
		if select_wait<=0: finish_pick()
	if introducing:
		intro_wait=maxf(0,intro_wait-delta)
		if intro_wait<=0:
			introducing=false
			if stage=="teams": open_tactics(true)

func open_selection() -> void:
	game.return_menu()
	game.clubs.ensure_world()
	game.clubs.apply()
	game.state="setup"
	game.ball.freeze=true
	prematch=true
	stage="teams"
	enter_age=0
	introducing=false
	intro_wait=0
	picked=[false, false]
	pick_step=0
	select_wait=0
	shown_ovr=[0.0, 0.0]
	ovr_punch=[1.0, 1.0]
	ovr_target=[0, 0]
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
	introducing=false
	intro_wait=0
	stage="tactics"
	enter_age=0
	history.clear()
	swap_stage="browse"
	swap_source={}; swap_target={}
	pane_focus=["continue" if prematch else "", ""]
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
	back_button=null
	plan_button=null
	tab_buttons.clear()
	tactic_buttons.clear()
	for child in controls.get_children(): controls.remove_child(child); child.queue_free()

func build() -> void:
	clear_controls()
	if stage=="teams":
		build_teams()
		focus_pick()
	else:
		build_tactics()
		configure_tactics_navigation()
		focus_tactics(str(pane_focus[pane]))
	queue_redraw()
	if overlay: overlay.queue_redraw()

func style_league(button: Button) -> void:
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color("2d5056") if state!="normal" else Color.TRANSPARENT
		style.set_corner_radius_all(4)
		if state=="focus":
			style.set_border_width_all(2)
			style.border_color=GOLD
			style.set_expand_margin_all(2)
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",GOLD)
	button.add_theme_color_override("font_hover_color",GOLD)
	button.add_theme_color_override("font_focus_color",GOLD)
	button.add_theme_font_size_override("font_size",15)

func build_teams() -> void:
	team_left.clear(); team_right.clear(); team_select.clear(); league_buttons.clear(); kit_buttons.clear()
	selection_ratings.assign([team_ratings(0),team_ratings(1)])
	for side in range(2):
		if ovr_target[side]==0: shown_ovr[side]=float(selection_ratings[side].gen); ovr_target[side]=selection_ratings[side].gen
	go_button=null
	for side in range(2):
		var x := 48.0 if side==0 else 758.0
		var preview := Preview.new()
		preview.position=Vector2(x+196,273)
		preview.size=Vector2(432,370)
		controls.add_child(preview)
		preview.show_kit(game.clubs.kit(side),side)
		preview.player.apply_identity(game.clubs.member(side,game.clubs.lineups[side][9]))
		if picked[side]: preview.hold_selected()
		else: preview.stand_idle()
		previews.append(preview)
		var league := make_button(controls,Rect2(x+24,224,484,34),game.clubs.league_name(side)+"  ›",cycle_league.bind(side,1))
		style_league(league)
		league_buttons.append(league)
		team_left.append(make_button(controls,Rect2(x+24,662,48,48),"‹",cycle_team.bind(side,-1)))
		team_select.append(make_button(controls,Rect2(x+84,662,466,48),"TAKIMI SEÇ",pick_side.bind(side),true))
		team_right.append(make_button(controls,Rect2(x+562,662,48,48),"›",cycle_team.bind(side,1)))
		var kit_title: String="FORMA · KONTRAST" if game.clubs.contrast_override.has(side) else ("FORMA  B" if game.clubs.alternate[side] else "FORMA  A")
		kit_buttons.append(make_button(controls,Rect2(x+445,285,163,31),kit_title,toggle_kit.bind(side)))
		kit_buttons[-1].add_theme_font_size_override("font_size",12)
	back_button=make_button(controls,Rect2(48,828,180,48),"← ANA MENÜ",back)
	weather_button=make_button(controls,Rect2(252,828,220,48),"HAVA  ·  "+game.weather.label(),cycle_weather)
	difficulty_button=make_button(controls,Rect2(490,828,220,48),"ZORLUK  ·  "+["KOLAY","NORMAL","ZOR"][game.management.difficulty],cycle_difficulty)
	time_button=make_button(controls,Rect2(728,828,220,48),"SAAT  ·  "+game.stadium.light_rig.label(),cycle_time)
	for button in [back_button,weather_button,difficulty_button,time_button]: button.add_theme_font_size_override("font_size",13)
	go_button=make_button(controls,Rect2(978,815,414,64),"KADRO & TAKTİK  →",pick_current,true)
	first_focus=team_select[mini(pick_step,1)] if pick_step<2 else go_button
	refresh_picks()

func refresh_picks() -> void:
	if team_select.size()!=2 or go_button==null: return
	for side in range(2):
		var locked: bool=picked[side] or pick_step!=side or select_wait>0
		team_select[side].disabled=locked
		team_select[side].text="✓  TAKIM HAZIR" if picked[side] else ("TAKIMINI SEÇ  →" if side==0 else "RAKİBİNİ SEÇ  →")
		var disabled_style := StyleBoxFlat.new()
		disabled_style.bg_color=Color("193831") if picked[side] else Color("193038")
		disabled_style.set_corner_radius_all(6)
		team_select[side].add_theme_stylebox_override("disabled",disabled_style)
		team_select[side].add_theme_color_override("font_disabled_color",MINT if picked[side] else MUTE)
		for button in [team_left[side],team_right[side],league_buttons[side]]: button.disabled=locked
	go_button.disabled=not (picked[0] and picked[1]) or select_wait>0
	go_button.text="KADRO & TAKTİK  →" if not go_button.disabled else "İKİ TAKIMI SEÇ"
	configure_selection_navigation()

func configure_selection_navigation() -> void:
	var footer: Array=[back_button,weather_button,difficulty_button,time_button]
	if not go_button.disabled: footer.append(go_button)
	for i in range(footer.size()):
		neighbor(footer[i],SIDE_LEFT,footer[maxi(0,i-1)])
		neighbor(footer[i],SIDE_RIGHT,footer[mini(footer.size()-1,i+1)])
		neighbor(footer[i],SIDE_TOP,team_select[pick_step] if pick_step<2 and not team_select[pick_step].disabled else kit_buttons[0 if i<2 else 1])
	for side in range(2):
		neighbor(kit_buttons[side],SIDE_BOTTOM,nearest_x(kit_buttons[side],footer))
		neighbor(kit_buttons[side],SIDE_LEFT,kit_buttons[0])
		neighbor(kit_buttons[side],SIDE_RIGHT,kit_buttons[1])
		if not team_select[side].disabled:
			neighbor(team_select[side],SIDE_TOP,kit_buttons[side])
			neighbor(team_select[side],SIDE_BOTTOM,nearest_x(team_select[side],footer))
			neighbor(kit_buttons[side],SIDE_TOP,league_buttons[side])
			neighbor(league_buttons[side],SIDE_BOTTOM,kit_buttons[side])
		else: neighbor(kit_buttons[side],SIDE_TOP,go_button if not go_button.disabled else kit_buttons[1-side])

func overlay_caption(side: int) -> String:
	return str(game.clubs.data(side).name)

func rating_of(info: Dictionary) -> int:
	var stats: Dictionary=info.get("attributes",{}).duplicate()
	if stats.is_empty(): return 70
	for key in ["passing","defending","strength","stamina","reflexes","handling","positioning"]:
		if not stats.has(key): stats[key]=int(stats.get("control" if key=="passing" else "balance",72))
	var role: int=0 if info.get("keeper",false) else 2
	# Overall belongs to the player, never to a translated tactical slot label.
	var raw=info.get("natural_group",info.get("role",info.get("group",role)))
	if raw is int: role=int(raw)
	elif raw is String: role={"KL":0,"DEF":1,"DF":1,"OS":2,"FV":3}.get(raw,role)
	if role<0 or role>3: role=2
	return World.ovr({"role":role,"attributes":stats})

func team_ratings(side: int) -> Dictionary:
	var buckets := [[],[],[],[]]
	for slot in range(11):
		var member: Dictionary=game.clubs.member(side,game.clubs.lineups[side][slot])
		var formation: int=game.management.formation if side==0 else game.management.opponent_formation
		for group in range(4):
			if slot in LINES[formation][group]: buckets[group].append(rating_of(member))
	var avg := func(values: Array) -> int:
		if values.is_empty(): return 0
		var total := 0
		for value in values: total+=int(value)
		return roundi(float(total)/values.size())
	return {"gen":avg.call(buckets[0]+buckets[1]+buckets[2]+buckets[3]),"def":avg.call(buckets[1]),"mid":avg.call(buckets[2]),"att":avg.call(buckets[3])}

func team_ovr(side: int) -> int:
	return int(team_ratings(side).gen)

func active_side() -> int:
	return pick_step if pick_step<2 else focused_side()

func focus_pick() -> void:
	if pick_step>=2 and go_button:
		go_button.grab_focus()
	elif pick_step<team_select.size():
		team_select[pick_step].grab_focus()

func accept_teams() -> void:
	pick_current()

func pick_current() -> void:
	if stage!="teams" or select_wait>0: return
	if pick_step>=2:
		if picked[0] and picked[1]: open_tactics(true)
		return
	pick_side(pick_step)

func pick_side(side: int) -> void:
	if side<0 or side>1 or side!=pick_step or picked[side]: return
	picked[side]=true
	if side<previews.size(): previews[side].play_select()
	select_wait=0.32
	refresh_picks()

func finish_pick() -> void:
	pick_step=1 if pick_step==0 else 2
	refresh_picks()
	focus_pick()

func unpick() -> bool:
	if select_wait>0:
		select_wait=0
		picked[pick_step]=false
		if pick_step<previews.size(): previews[pick_step].stand_idle()
		refresh_picks(); focus_pick()
		return true
	if pick_step>=2:
		pick_step=1
		picked[1]=false
		if previews.size()>1: previews[1].stand_idle()
		refresh_picks()
		focus_pick()
		return true
	if pick_step==1:
		pick_step=0
		picked[0]=false
		if previews.size()>0: previews[0].stand_idle()
		refresh_picks()
		focus_pick()
		return true
	return false

func focused_side() -> int:
	var owner := get_viewport().gui_get_focus_owner()
	if owner!=null and controls.is_ancestor_of(owner):
		return 0 if owner.position.x<700 else 1
	return 0

func is_team_choice(focus: Control) -> bool:
	return focus in team_select or focus in team_left or focus in team_right

func try_carousel(focus: Control,direction: int) -> bool:
	if select_wait>0 or stage!="teams" or direction==0: return false
	if pick_step>=2 or not is_team_choice(focus): return false
	cycle_team(pick_step,direction)
	return true

func cycle_league(side: int,direction: int) -> void:
	if select_wait>0: return
	if side<2 and picked[side]: return
	game.clubs.set_league(side,game.clubs.league[side]+direction)
	if is_instance_valid(game.match_menu): game.match_menu.persist_session()
	build()

func cycle_team(side: int,direction: int) -> void:
	if select_wait>0: return
	if side<2 and picked[side]: return
	game.clubs.choose(side,game.clubs.selected[side]+direction)
	if is_instance_valid(game.match_menu): game.match_menu.persist_session()
	build()

func toggle_kit(side: int) -> void:
	if introducing: return
	game.clubs.alternate[side]=not game.clubs.alternate[side]
	game.clubs.apply(side)
	build()
	if side<kit_buttons.size(): kit_buttons[side].grab_focus()

func cycle_weather() -> void:
	game.weather.select((game.weather.preset+1)%3,true)
	build()
	if weather_button: weather_button.grab_focus()

func cycle_time() -> void:
	game.stadium.light_rig.select({0:2,2:1,1:0}[game.stadium.light_rig.period])
	build()
	if time_button: time_button.grab_focus()

func cycle_difficulty() -> void:
	game.management.difficulty=(game.management.difficulty+1)%3
	if is_instance_valid(game.match_menu): game.match_menu.persist_session()
	build()
	if difficulty_button: difficulty_button.grab_focus()

func slot_position(index: int) -> Vector2:
	var group := slot_group(index)
	var line: Array=LINES[game.management.formation][group]
	var column: int=line.find(game.players[index].number-1)
	var spread := 650.0 if line.size()==5 else (570.0 if line.size()==4 else 500.0)
	if line.size()==2: spread=280.0
	var x := 483.0 if line.size()==1 else 483.0-spread/2+spread*column/(line.size()-1)
	return Vector2(x,[566.0,473.0,373.0,270.0][group])

func player_data(kind: String,index: int) -> Dictionary:
	var data: Dictionary
	if kind=="slot":
		var p=game.players[index]
		data={"name":p.display_name,"shirt":p.shirt_number,"keeper":p.keeper,"energy":1.0 if prematch else p.energy,"yellow":0 if prematch else p.yellow_cards,"dismissed":false if prematch else p.dismissed,"role":ROLES[game.management.formation][p.number-1],"status":""}
		data.merge({"height_cm":p.height_cm,"weight_kg":p.weight_kg,"attributes":p.attributes.duplicate(),"appearance_number":p.number,"group":slot_group(index),"natural_group":p.natural_position if p.natural_position>=0 else natural_group(p.shirt_number,p.keeper)})
		if game.career.in_match and p.career_id!="": data.ovr=World.ovr(game.career.player(p.career_id))
		else: data.ovr=rating_of(data)
		data.appearance_id=p.appearance_id
		if game.career.in_match and p.career_id!="": data.energy=game.career.player(p.career_id).fitness if prematch else p.energy
		if not prematch:
			if p.dismissed: data.status="İHRAÇ"
			elif game.management.transit.has(index): data.status="DEĞİŞİYOR"
			elif not pending_for(index).is_empty(): data.status="ÇIKACAK"
	else:
		data=game.management.bench[0][index].duplicate()
		var natural: int=int(data.get("role",natural_group(data.shirt,data.keeper)))
		data.merge({"energy":1.0,"yellow":0,"dismissed":false,"role":"KL" if data.keeper else "SAHA","status":""})
		data.natural_group=natural
		data.ovr=rating_of({"attributes":data.get("attributes",{}),"keeper":data.keeper,"role":natural})
		if game.career.in_match: data.energy=data.get("fitness",1.0)
		if data.used: data.status="OYUNA GİRDİ"
		for item in game.management.pending:
			if item.slot<11 and item.reserve==index: data.status="GİRECEK"
		for slot in game.management.transit:
			if slot<11 and game.management.transit[slot].reserve==index: data.status="DEĞİŞİYOR"
	if kind=="bench":
		data.group=data.natural_group
		data.natural_group=data.group
		data.role=["KL","DF","OS","FV"][data.group]
	data.position_label=GROUPS[data.group]
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
	return game.management.substitution_reason(slot,reserve)

func make_card(kind: String,index: int,rect: Rect2) -> Button:
	var card := SquadCard.new()
	card.frontend=self; card.kind=kind; card.index=index; card.data=player_data(kind,index)
	set_card_state(card)
	card.portrait_key=portraits.request(card.data)
	card.position=rect.position; card.size=rect.size
	controls.add_child(card)
	track_tactics_focus(card,kind+":"+str(index))
	if pane==1: card.focus_mode=Control.FOCUS_NONE
	return card

func build_tactics() -> void:
	for i in range(11):
		slot_buttons.append(make_card("slot",i,Rect2(slot_position(i)-Vector2(59,44),Vector2(118,88))))
	tab_buttons.append(make_button(controls,Rect2(925,45,219,48),"KADROM",set_pane.bind(0),pane==0))
	tab_buttons.append(make_button(controls,Rect2(1158,45,242,48),"OYUN PLANI",set_pane.bind(1),pane==1))
	for i in range(2): track_tactics_focus(tab_buttons[i],"tab:"+str(i))
	if pane==0:
		for j in range(7):
			reserve_buttons.append(make_card("bench",j,Rect2(52+j*192,694,184,92)))
		swap_action=make_button(controls,Rect2(976,564,400,44),"YEDEK SEÇ",apply_preview,true)
		track_tactics_focus(swap_action,"swap")
		update_swap_action()
	else:
		var m=game.management
		var rows := [["Diziliş",m.FORMATIONS,m.formation,"formation"],["Oyun anlayışı",["Savunmacı","Dengeli","Hücumcu"],m.mentality,"mentality"],["Pres yoğunluğu",["Geri çekil","Dengeli","Yoğun"],m.pressing,"pressing"],["Savunma çizgisi",["Derin","Normal","Önde"],m.line_height,"line_height"]]
		for i in range(rows.size()):
			var row: Array=rows[i]
			var buttons: Array[Button]=[]
			for j in range(3):
				var button := make_button(controls,Rect2(976+j*136,234+i*99,128,42),row[1][j],set_tactic.bind(row[3],j),j==row[2])
				button.add_theme_font_size_override("font_size",14)
				buttons.append(button)
				track_tactics_focus(button,"plan:%d:%d" % [i,j])
			tactic_buttons.append(buttons)
	back_button=make_button(controls,Rect2(40,834,222,49),("← Kariyere dön" if game.career.in_match else "← Takım seçimi") if prematch else "← Maça dön",back)
	track_tactics_focus(back_button,"back")
	undo_button=make_button(controls,Rect2(848,834,240,49),"SON DEĞİŞİKLİĞİ GERİ AL",undo_last)
	undo_button.add_theme_font_size_override("font_size",12)
	undo_button.disabled=history.is_empty()
	track_tactics_focus(undo_button,"undo")
	first_focus=make_button(controls,Rect2(1112,830,288,53),"MAÇA BAŞLA  →" if prematch else "MAÇA DÖN  →",confirm,true)
	track_tactics_focus(first_focus,"continue")
	if game.career.in_match and not prematch:
		plan_button=make_button(controls,Rect2(976,624,400,43),"DETAYLI OYUN PLANI",game.career_screen.open_live_tactics)
		track_tactics_focus(plan_button,"detail")

func track_tactics_focus(button: Button,key: String) -> void:
	button.set_meta("tactics_focus",key)
	button.focus_entered.connect(func():
		if not key.begins_with("tab:"): pane_focus[pane]=key
		if swap_action!=null: swap_action.visible=not (prematch and key=="continue" and swap_stage=="browse")
		queue_redraw()
		if overlay: overlay.queue_redraw())
	button.focus_exited.connect(func():
		button.queue_redraw()
		if overlay: overlay.queue_redraw())

func focus_tactics(key: String) -> void:
	for child in controls.get_children():
		if child is Button and child.get_meta("tactics_focus","")==key and not child.disabled and child.focus_mode!=Control.FOCUS_NONE:
			child.grab_focus()
			return
	if pane==0: slot_buttons[selected_slot].grab_focus()
	else: tactic_buttons[0][game.management.formation].grab_focus()

func refresh_card_states() -> void:
	for card in slot_buttons+reserve_buttons:
		set_card_state(card)
		card.queue_redraw()

func set_card_state(card) -> void:
	var ref := {"kind":card.kind,"index":card.index}
	card.active=swap_stage!="browse" and (ref==swap_source or ref==swap_target)
	var reason := selectable_reason(ref)
	if swap_stage!="browse" and ref!=swap_source and not (ref.kind=="bench" and swap_source.kind=="bench"):
		reason=pair_reason(swap_source,ref)
	card.eligible=reason==""
	card.data.unavailable="MEVKİ UYUMSUZ" if reason.contains("Kaleci") else "SEÇİLEMİYOR"

func neighbor(button: Control,side: int,target: Control) -> void:
	button.set(["focus_neighbor_left","focus_neighbor_top","focus_neighbor_right","focus_neighbor_bottom"][side],button.get_path_to(target))

func nearest_x(button: Control,candidates: Array) -> Control:
	var best: Control=candidates[0]
	var x := button.get_rect().get_center().x
	for candidate in candidates:
		if absf(candidate.get_rect().get_center().x-x)<absf(best.get_rect().get_center().x-x): best=candidate
	return best

func configure_tactics_navigation() -> void:
	# Explicit neighbors keep direction presses spatial and never activate an action.
	var enabled: Array[Control]=[]
	for child in controls.get_children():
		if child is Button and child.focus_mode!=Control.FOCUS_NONE and not child.disabled:
			enabled.append(child)
			for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: neighbor(child,side,child)
	for i in range(enabled.size()):
		enabled[i].focus_next=enabled[i].get_path_to(enabled[(i+1)%enabled.size()])
		enabled[i].focus_previous=enabled[i].get_path_to(enabled[posmod(i-1,enabled.size())])
	var footer: Array=[back_button]
	if not undo_button.disabled: footer.append(undo_button)
	footer.append(first_focus)
	for i in range(footer.size()):
		neighbor(footer[i],SIDE_LEFT,footer[maxi(0,i-1)])
		neighbor(footer[i],SIDE_RIGHT,footer[mini(footer.size()-1,i+1)])
	neighbor(tab_buttons[0],SIDE_RIGHT,tab_buttons[1])
	neighbor(tab_buttons[1],SIDE_LEFT,tab_buttons[0])
	if pane==0:
		var lines := tactical_lines()
		for group in range(4):
			var line: Array=lines[group]
			for column in range(line.size()):
				var card: Control=slot_buttons[line[column]]
				neighbor(card,SIDE_LEFT,slot_buttons[line[maxi(0,column-1)]])
				neighbor(card,SIDE_RIGHT,slot_buttons[line[column+1]] if column+1<line.size() else (swap_action if not swap_action.disabled else card))
				for vertical in [-1,1]:
					var adjacent: int=group+vertical
					var side := SIDE_TOP if vertical==1 else SIDE_BOTTOM
					if adjacent>3: neighbor(card,side,tab_buttons[0])
					elif adjacent<0: neighbor(card,side,nearest_x(card,reserve_buttons))
					else:
						var candidates: Array=[]
						for index in lines[adjacent]: candidates.append(slot_buttons[index])
						neighbor(card,side,nearest_x(card,candidates))
		for i in range(7):
			var card: Control=reserve_buttons[i]
			neighbor(card,SIDE_LEFT,reserve_buttons[maxi(0,i-1)])
			neighbor(card,SIDE_RIGHT,reserve_buttons[mini(6,i+1)])
			neighbor(card,SIDE_TOP,slot_buttons[0])
			neighbor(card,SIDE_BOTTOM,nearest_x(card,footer))
		for tab in tab_buttons: neighbor(tab,SIDE_BOTTOM,slot_buttons[selected_slot])
		for button in footer: neighbor(button,SIDE_TOP,nearest_x(button,reserve_buttons))
		neighbor(swap_action,SIDE_LEFT,slot_buttons[selected_slot])
		neighbor(swap_action,SIDE_TOP,tab_buttons[1])
		neighbor(swap_action,SIDE_BOTTOM,reserve_buttons[maxi(0,preview_reserve)] if plan_button==null else plan_button)
	else:
		for row in range(4):
			for column in range(3):
				var button: Control=tactic_buttons[row][column]
				neighbor(button,SIDE_LEFT,tactic_buttons[row][maxi(0,column-1)])
				neighbor(button,SIDE_RIGHT,tactic_buttons[row][mini(2,column+1)])
				neighbor(button,SIDE_TOP,tactic_buttons[row-1][column] if row>0 else tab_buttons[1])
				neighbor(button,SIDE_BOTTOM,tactic_buttons[row+1][column] if row<3 else (nearest_x(button,footer) if plan_button==null else plan_button))
		for tab in tab_buttons: neighbor(tab,SIDE_BOTTOM,tactic_buttons[0][game.management.formation])
		for button in footer: neighbor(button,SIDE_TOP,nearest_x(button,tactic_buttons[3]))
	if plan_button!=null:
		neighbor(plan_button,SIDE_TOP,swap_action if pane==0 else tactic_buttons[3][1])
		neighbor(plan_button,SIDE_BOTTOM,first_focus)

func cancel_swap_preview() -> void:
	var restore := swap_source.duplicate()
	if swap_stage=="confirm":
		restore=swap_target.duplicate()
		swap_target.clear()
		swap_stage="choose"
	else:
		swap_stage="browse"
		swap_source.clear()
		swap_target.clear()
		preview_reserve=-1
	status=""
	update_swap_action()
	configure_tactics_navigation()
	if not restore.is_empty(): focus_tactics(restore.kind+":"+str(restore.index))
	refresh_card_states()
	queue_redraw()

func preview_player(kind: String,index: int) -> void:
	if pane!=0: return
	inspected={"kind":kind,"index":index}
	if swap_stage=="browse" and kind=="slot": selected_slot=index
	preview_reserve=index if kind=="bench" else -1
	refresh_card_states()
	update_swap_action()
	if first_focus!=null and is_instance_valid(first_focus): configure_tactics_navigation()
	queue_redraw()

func update_swap_action() -> void:
	if not is_instance_valid(swap_action): return
	if swap_stage=="browse" and inspected.kind=="slot" and not pending_for(inspected.index).is_empty():
		swap_action.text="BU DEĞİŞİKLİĞİ İPTAL ET"
		swap_action.disabled=false
	elif swap_stage=="confirm":
		swap_action.text="YERLERİNİ DEĞİŞTİR  →" if swap_source.kind==swap_target.kind else "DEĞİŞİKLİĞİ ONAYLA  →"
		swap_action.disabled=pair_reason(swap_source,swap_target)!=""
	else:
		swap_action.text="İKİNCİ OYUNCUYU SEÇ" if swap_stage=="choose" else "OYUNCUYU SEÇ  →"
		swap_action.disabled=(inspected==swap_source or pair_reason(swap_source,inspected)!="") if swap_stage=="choose" else selectable_reason(inspected)!=""

func apply_preview() -> void:
	if swap_stage=="confirm": commit_pair(swap_source,swap_target)
	elif swap_stage=="browse" and inspected.kind=="slot" and not pending_for(inspected.index).is_empty():
		selected_slot=inspected.index
		cancel_selected()
	else: activate_card(inspected.kind,inspected.index)

func selectable_reason(ref: Dictionary) -> String:
	if ref.is_empty() or ref.get("kind","") not in ["slot","bench"]: return "Bir oyuncu seç."
	var index: int=ref.get("index",-1)
	if index<0 or index>=(11 if ref.kind=="slot" else 7): return "Geçersiz seçim."
	if prematch: return ""
	if ref.kind=="slot":
		if game.players[index].dismissed: return "İhraç edilen oyuncu değiştirilemez."
		if game.management.transit.has(index): return "Bu oyuncunun değişikliği devam ediyor."
	else:
		if game.management.bench[0][index].used: return "Bu yedek maçta zaten kullanıldı."
		for item in game.management.pending:
			if item.slot<11 and item.reserve==index: return "Bu yedek başka bir oyuncu için seçildi."
		for slot in game.management.transit:
			if slot<11 and game.management.transit[slot].reserve==index: return "Bu yedek şu anda sahaya giriyor."
		if game.management.committed(0)>=game.management.MAX_SUBS: return "Üç oyuncu değişikliği hakkı doldu."
	return ""

func pair_reason(a: Dictionary,b: Dictionary) -> String:
	for ref in [a,b]:
		var reason := selectable_reason(ref)
		if reason!="": return reason
	if a==b: return "İki farklı oyuncu seç."
	if a.kind=="bench" and b.kind=="bench": return "Şimdi sahadan bir oyuncu seç."
	if a.kind=="slot" and b.kind=="slot": return game.management.position_swap_reason(a.index,b.index)
	return replacement_reason(a.index if a.kind=="slot" else b.index,b.index if b.kind=="bench" else a.index)

func activate_card(kind: String,index: int) -> void:
	if pane!=0: return
	var ref := {"kind":kind,"index":index}
	var reason := selectable_reason(ref)
	if reason!="":
		status=reason; update_swap_action(); queue_redraw(); return
	if swap_stage!="browse" and ref==swap_source:
		swap_stage="choose"
		cancel_swap_preview()
		return
	if swap_stage=="browse" and kind=="slot" and not pending_for(index).is_empty():
		selected_slot=index
		inspected=ref
		update_swap_action(); swap_action.grab_focus(); return
	if swap_stage=="browse" or (swap_source.kind=="bench" and kind=="bench"):
		swap_source=ref
		swap_target={}
		swap_stage="choose"
	else:
		reason=pair_reason(swap_source,ref)
		if reason!="": status=reason; queue_redraw(); return
		swap_target=ref
		swap_stage="confirm"
	if kind=="slot": selected_slot=index
	status=""
	refresh_card_states()
	update_swap_action()
	configure_tactics_navigation()
	if swap_stage=="confirm": swap_action.grab_focus()
	queue_redraw()

func select_slot(index: int) -> void:
	activate_card("slot",index)

func commit_pair(a: Dictionary,b: Dictionary) -> void:
	var reason := pair_reason(a,b)
	if reason!="": status=reason; queue_redraw(); return
	if a.kind!=b.kind:
		selected_slot=a.index if a.kind=="slot" else b.index
		select_reserve(b.index if b.kind=="bench" else a.index)
		return
	selected_slot=a.index
	var names: String=game.players[a.index].display_name+" ↔ "+game.players[b.index].display_name
	if prematch:
		history.append({"lineup":game.clubs.lineups[0].duplicate(),"bench":game.clubs.reserves[0].duplicate(),"slot":selected_slot})
		game.clubs.swap_positions(a.index,b.index)
	else:
		game.management.swap_positions(a.index,b.index)
		history.append({"slot":a.index,"position_swap":b.index})
	status=names+" · Sahadaki yerleri değişti."
	swap_stage="browse"
	swap_source={}; swap_target={}
	preview_reserve=-1
	pane_focus[0]="slot:"+str(selected_slot)
	build()

func set_pane(value: int) -> void:
	if pane==value: return
	swap_stage="browse"
	preview_reserve=-1
	status=""
	if str(pane_focus[0]).begins_with("bench:") or pane_focus[0]=="swap": pane_focus[0]="slot:"+str(selected_slot)
	pane=value
	build()

func set_tactic(property: String,value: int) -> void:
	var from: Dictionary={}
	if property=="formation":
		for i in range(slot_buttons.size()): from[i]=slot_buttons[i].position
	game.management.set(property,value)
	game.management.apply_formation()
	build()
	if property=="formation": slide_slots(from)
	if pane==1: focus_tactics("plan:%d:%d" % [["formation","mentality","pressing","line_height"].find(property),value])

func slide_slots(from: Dictionary) -> void:
	if DisplayServer.get_name()=="headless" or "--disable-render-loop" in OS.get_cmdline_args(): return
	if not is_visible_in_tree(): return
	for i in range(slot_buttons.size()):
		if not from.has(i): continue
		var dest: Vector2=slot_buttons[i].position
		if from[i].distance_to(dest)<2: continue
		slot_buttons[i].position=from[i]
		var tween: Tween=create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot_buttons[i],"position",dest,0.28)

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
	swap_stage="browse"
	pane_focus[0]="slot:"+str(selected_slot)
	build()
	slot_buttons[selected_slot].grab_focus()

func cancel_selected() -> void:
	var slot := selected_slot
	game.management.pending=game.management.pending.filter(func(item): return item.slot!=slot)
	history=history.filter(func(item): return item.has("position_swap") or item.slot!=slot)
	status="Bekleyen değişiklik iptal edildi."
	preview_reserve=-1
	swap_stage="browse"
	pane_focus[0]="slot:"+str(slot)
	build()
	slot_buttons[slot].grab_focus()

func cancel_pending() -> void:
	game.management.pending=game.management.pending.filter(func(item): return game.players[item.slot].team!=0)
	history.clear()
	swap_stage="browse"
	preview_reserve=-1
	pane_focus[0]="slot:"+str(selected_slot)
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
	elif item.has("position_swap"):
		game.management.swap_positions(item.slot,item.position_swap)
	else:
		game.management.pending=game.management.pending.filter(func(entry): return entry.slot!=item.slot or entry.reserve!=item.reserve)
	status="Son değişiklik geri alındı."
	preview_reserve=-1
	swap_stage="browse"
	pane_focus[0]="slot:"+str(selected_slot)
	build()
	slot_buttons[selected_slot].grab_focus()

func can_drop_player(value: Variant,kind: String,index: int) -> bool:
	if not value is Dictionary or value.get("squad",-1)!=get_instance_id(): return false
	if value.get("kind","") not in ["slot","bench"]: return false
	if kind not in ["slot","bench"] or not value.get("index") is int: return false
	return pair_reason({"kind":value.kind,"index":value.index},{"kind":kind,"index":index})==""

func drop_player(value: Variant,kind: String,index: int) -> void:
	if not can_drop_player(value,kind,index): return
	commit_pair({"kind":value.kind,"index":value.index},{"kind":kind,"index":index})

func confirm() -> void:
	if stage=="tactics" and swap_stage!="browse":
		status="Değişikliği onayla veya geri tuşuyla vazgeç."
		if swap_action!=null and not swap_action.disabled: swap_action.grab_focus()
		return
	visible=false
	clear_controls()
	game.controller.held.clear()
	if game.career.in_match:
		for key in game.career.club().plan: game.career.club().plan[key]=game.management.get(key)
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
	if stage=="tactics" and swap_stage!="browse":
		cancel_swap_preview()
		return
	if introducing:
		introducing=false
		intro_wait=0
		for preview in previews: preview.stand_idle()
		return
	if stage=="teams" and unpick(): return
	if prematch and game.career.in_match:
		visible=false; clear_controls(); game.career.in_match=false
		game.career_screen.open_hub(); return
	if stage=="tactics" and prematch:
		stage="teams"; enter_age=0; status=""; build()
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
		elif event.keycode==KEY_ENTER and stage=="teams" and is_team_choice(get_viewport().gui_get_focus_owner()):
			pick_current(); get_viewport().set_input_as_handled()
		elif stage=="teams" and event.keycode in [KEY_LEFT,KEY_RIGHT]:
			if try_carousel(get_viewport().gui_get_focus_owner(),-1 if event.keycode==KEY_LEFT else 1):
				get_viewport().set_input_as_handled()
		elif stage=="teams" and event.keycode in [KEY_Q,KEY_BRACKETLEFT]:
			cycle_league(active_side(),-1); get_viewport().set_input_as_handled()
		elif stage=="teams" and event.keycode in [KEY_E,KEY_BRACKETRIGHT]:
			cycle_league(active_side(),1); get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		game.controller.using_gamepad=true
		if event.button_index==JOY_BUTTON_B: back(); get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_X and stage=="tactics": undo_last(); get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_START: confirm() if stage=="tactics" else pick_current(); get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_BACK: game.match_menu.open_menu(); get_viewport().set_input_as_handled()
		elif stage=="teams" and event.button_index==JOY_BUTTON_LEFT_SHOULDER:
			cycle_league(active_side(),-1); get_viewport().set_input_as_handled()
		elif stage=="teams" and event.button_index==JOY_BUTTON_RIGHT_SHOULDER:
			cycle_league(active_side(),1); get_viewport().set_input_as_handled()
		elif stage=="teams" and event.button_index==JOY_BUTTON_X:
			toggle_kit(active_side()); get_viewport().set_input_as_handled()
		elif stage=="tactics" and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			set_pane(0 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1)
			get_viewport().set_input_as_handled()

func _draw() -> void:
	if stage=="teams": SelectionArt.draw(self)
	else: draw_tactics()
func overlay_panel(rect: Rect2, tint: Color, selected: bool=false) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color=Color("0b2028").lerp(tint,0.07)
	style.set_corner_radius_all(14)
	style.set_border_width_all(1)
	style.border_color=Color(tint,0.55 if selected else 0.24)
	style.shadow_color=Color(0,0,0,0.18)
	style.shadow_size=8
	style.shadow_offset=Vector2(0,4)
	overlay.draw_style_box(style,rect)

func overlay_text(value: String, at: Vector2, px: int, tint: Color, strong: bool=false, centered: bool=false) -> void:
	var face: Font=bold if strong else font
	if centered: at.x-=face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x/2.0
	overlay.draw_string(face,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,tint)

func draw_team_overlays() -> void:
	if stage=="tactics": draw_tactics_focus()
	elif stage=="teams": SelectionArt.overlay(self)
	if enter_age<.24:
		overlay.draw_rect(game.ui.bounds(),Color(.025,.055,.07,1-smoothstep(0,.24,enter_age)))
func draw_tactics_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused==null or not controls.is_ancestor_of(focused) or game.match_menu.visible: return
	var rect := Rect2(focused.position,focused.size).grow(4)
	var ring := StyleBoxFlat.new()
	ring.bg_color=Color.TRANSPARENT
	ring.border_color=Color("061d22")
	ring.set_corner_radius_all(10)
	ring.set_border_width_all(6)
	overlay.draw_style_box(ring,rect.grow(2))
	ring.border_color=Color("66efff")
	ring.set_border_width_all(3)
	overlay.draw_style_box(ring,rect)
	# The pointer remains visible even against a selected gold button or pale card.
	var tip := Vector2(rect.end.x-18,rect.position.y)
	overlay.draw_colored_polygon(PackedVector2Array([tip+Vector2(-5,-7),tip+Vector2(5,-7),tip]),Color("66efff"))

func tactics_action_label() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	if focused==first_focus: return "Maça başla" if prematch else "Maça dön"
	if focused!=null and focused==swap_action: return "Onayla" if swap_stage=="confirm" else ("İptal et" if not pending_for(selected_slot).is_empty() else "Seç")
	if focused in reserve_buttons or focused in slot_buttons:
		if focused.active: return "Seçimi kaldır"
		return "İlk oyuncuyu seç" if swap_stage=="browse" else "İkinci oyuncuyu seç"
	return "Uygula" if pane==1 else "Seç"

func draw_tactics() -> void:
	preload("res://scripts/tactics_art.gd").draw(self)

func draw_player_detail(data: Dictionary,at: Vector2,title: String,color: Color) -> void:
	text(title,at,10,color,true)
	var group_color: Color=ROLE_COLORS[data.group]
	box(Rect2(at+Vector2(0,12),Vector2(90,90)),Color("2f5142"),12)
	draw_circle(at+Vector2(45,60),37,Color(group_color,.14))
	var photo: Texture2D=portraits.photo(data)
	if photo!=null: draw_texture_rect(photo,Rect2(at+Vector2(-3,6),Vector2(96,96)),false)
	else: SquadCard.shirt(self,at+Vector2(45,56),63,data.kit,data.shirt,bold)
	text(data.name,at+Vector2(106,34),25 if str(data.name).length()<11 else 21,PAPER,true)
	text("#%02d · %s · GÜÇ %d" % [data.shirt,GROUPS[data.natural_group],data.ovr],at+Vector2(107,55),11,group_color,true)
	var stats: Dictionary=data.get("attributes",preload("res://scripts/player_attributes.gd").profile(0,int(data.shirt)-1,data.keeper))
	text("%d cm · %d kg · %s · ZAYIF %d/5" % [data.height_cm,data.weight_kg,"SOL" if stats.preferred_foot==0 else "SAĞ",stats.weak_foot],at+Vector2(108,76),10,MUTE)
	var energy: float=data.energy
	var tint := SquadCard.energy_color(energy)
	text("ENERJİ",at+Vector2(108,93),9,MUTE,true)
	text("%d%%" % roundi(energy*100),at+Vector2(349,93),11,tint,true)
	box(Rect2(at+Vector2(108,99),Vector2(279,4)),Color("38584a"),2)
	box(Rect2(at+Vector2(108,99),Vector2(maxf(2,279*energy),4)),tint,2)

	for i in range(6):
		var x: float=at.x+i*66
		text(preload("res://scripts/player_attributes.gd").LABELS[i],Vector2(x,at.y+115),8,MUTE,true)
		text(str(stats[preload("res://scripts/player_attributes.gd").KEYS[i]]),Vector2(x+42,at.y+115),11,PAPER,true)
		box(Rect2(x,at.y+121,57,3),Color("38584a"),1)
		box(Rect2(x,at.y+121,57*float(stats[preload("res://scripts/player_attributes.gd").KEYS[i]])/100,3),color,1)

func draw_comparison() -> void:
	if prematch and swap_stage=="browse" and get_viewport().gui_get_focus_owner()==first_focus:
		draw_match_brief()
		return
	if swap_stage=="browse":
		draw_player_spotlight(player_data(inspected.kind,inspected.index))
		return
	text({"browse":"1 / 3  ·  İLK OYUNCUYU SEÇ","choose":"2 / 3  ·  İKİNCİ OYUNCUYU SEÇ","confirm":"3 / 3  ·  DEĞİŞİKLİĞİ ONAYLA"}[swap_stage],Vector2(976,186),12,Color("66efff") if swap_stage=="browse" else GOLD,true)
	var first: Dictionary=inspected if swap_stage=="browse" else swap_source
	var outgoing := player_data(first.kind,first.index)
	draw_player_detail(outgoing,Vector2(977,213),"İNCELENEN OYUNCU" if swap_stage=="browse" else "İLK OYUNCU · SEÇİLİ",GOLD)
	var pending := pending_for(first.index) if first.kind=="slot" else {}
	var second: Dictionary={}
	if not pending.is_empty(): second={"kind":"bench","index":pending.reserve}
	elif swap_stage=="confirm": second=swap_target
	elif swap_stage=="choose" and inspected!=swap_source: second=inspected
	draw_line(Vector2(978,342),Vector2(1375,342),Color("39594a"),1)
	if not second.is_empty():
		draw_player_detail(player_data(second.kind,second.index),Vector2(977,365),"GİRECEK · BEKLEMEDE" if not pending.is_empty() else "İKİNCİ OYUNCU",MINT)
		var reason := pair_reason(first,second) if pending.is_empty() else "İlk duraklamada kenardan oyuna girecek."
		var positions: bool=first.kind=="slot" and second.kind=="slot"
		var hint := "İki oyuncu sahada yer değiştirecek." if positions else ("Onayladığında ilk 11 güncellenecek." if prematch else "İlk duraklamada oyuncu değişikliği yapılacak.")
		text(reason if reason!="" else hint,Vector2(977,509),11,MUTE)
		text("Güç puanı oyuncuya aittir; yer değişince azalmaz.",Vector2(977,536),10,MINT)
	else:
		text("HERKESİN BİR YERİ VAR.",Vector2(977,379),19,PAPER,true)
		for group in range(1,4):
			var x := 978+(group-1)*134
			box(Rect2(x,398,123,66),Color("244638"),8)
			center(str(LINES[game.management.formation][group].size()),Vector2(x+61,429),24,ROLE_COLORS[group],true)
			center(GROUPS[group],Vector2(x+61,450),9,Color("bad0c0"),true)
		text("Sahadan ya da yedekten iki oyuncu seç.",Vector2(978,498),12,MUTE)
		text("Yön tuşları yalnızca odağı taşır.",Vector2(978,522),12,Color("66efff"))
		if outgoing.dismissed: text("İHRAÇ · DEĞİŞTİRİLEMEZ",Vector2(978,547),10,Color("f28172"),true)
		elif outgoing.yellow>0: text("SARI KART · İKİNCİ KARTA DİKKAT",Vector2(978,547),10,GOLD,true)

func draw_match_brief() -> void:
	var club: Dictionary=game.clubs.data(0)
	SelectionArt.fitted(self,club.name.to_upper(),Vector2(978,207),27,398)
	text("MAÇ GÜNÜ  /  KIYI ARENA",Vector2(980,234),11,SelectionArt.MUTE)
	for i in range(5): draw_arc(Vector2(1176,344),94+i*9,-PI*.9,PI*.6,56,Color(SelectionArt.MINT,.10-i*.014),1,true)
	badge(Vector2(1176,338),club,2.3)
	badge(Vector2(1002,455),game.clubs.data(1),.63)
	text("VS",Vector2(1043,459),12,SelectionArt.GOLD,true)
	SelectionArt.fitted(self,game.team_name(1),Vector2(1075,459),20,290)
	var ratings: Dictionary=team_ratings(0)
	for i in range(3): SelectionArt.gauge(self,Vector2(1042+i*133,544),[ratings.att,ratings.mid,ratings.def][i],["HÜCUM","ORTA SAHA","DEFANS"][i],SelectionArt.MINT,26)

func draw_player_spotlight(data: Dictionary) -> void:
	text(data.role,Vector2(978,192),12,SelectionArt.MINT,true)
	SelectionArt.fitted(self,str(data.name),Vector2(978,227),29,393)
	text("%d cm  /  %d kg" % [data.height_cm,data.weight_kg],Vector2(980,252),12,SelectionArt.MUTE)
	var portrait: Texture2D=portraits.photo(data)
	draw_circle(Vector2(1122,360),81,Color(SelectionArt.MINT,.08))
	draw_arc(Vector2(1122,360),89,-PI*.8,PI*.65,64,Color(SelectionArt.MINT,.25),1.4,true)
	if portrait!=null: draw_texture_rect(portrait,Rect2(1020,258,204,204),false)
	else: SquadCard.shirt(self,Vector2(1122,357),143,data.kit,data.shirt,bold)
	text(str(data.ovr),Vector2(1243,371),55,SelectionArt.GOLD,true)
	text("GÜÇ",Vector2(1252,394),10,SelectionArt.MUTE,true)
	var stats: Dictionary=data.attributes
	for i in range(3): SelectionArt.gauge(self,Vector2(1038+i*133,511),[stats.pace,stats.passing,stats.finishing][i],["HIZ","PAS","BİTİRİŞ"][i],SelectionArt.MINT,24)
	box(Rect2(981,572,390,5),SelectionArt.LINE,2)
	box(Rect2(981,572,390*data.energy,5),SquadCard.energy_color(data.energy),2)
	text("ENERJİ",Vector2(981,600),10,SelectionArt.MUTE,true)
	text("%d%%" % roundi(data.energy*100),Vector2(1337,600),12,SelectionArt.PAPER,true)

func make_button(parent: Node,rect: Rect2,value: String,callback: Callable,primary: bool=false) -> Button:
	var button: Button=super.make_button(parent,rect,value,callback,primary)
	for visual in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color=(SelectionArt.GOLD if primary else Color("152a35")).lightened(.10 if visual=="hover" else 0)
		style.set_corner_radius_all(10)
		if visual=="focus":
			style.bg_color=Color.TRANSPARENT; style.border_color=SelectionArt.GOLD
			style.set_border_width_all(2); style.set_expand_margin_all(3)
		button.add_theme_stylebox_override(visual,style)
	for visual in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]: button.add_theme_color_override(visual,SelectionArt.INK if primary else SelectionArt.PAPER)
	return button
