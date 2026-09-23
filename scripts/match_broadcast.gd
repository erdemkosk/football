extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Camera-only inserts: football/recovery keep running and a ready restart wins.
var game
var active := false
var kind := ""
var subject := -1
var partner: Node3D
var age := 0.0
var duration := 1.8
var cooldown := 0.0
var queued: Dictionary = {}
var consumed: Dictionary = {}
var caption := ""
var graphic := ""
var graphic_caption := ""
var graphic_age := 0.0
var graphic_duration := 1.0
var substitution_queue: Array[Dictionary] = []
var substitution_card: Dictionary = {}
var substitution_age := 0.0

func reset() -> void:
	finish(); queued.clear(); consumed.clear(); cooldown=0
	graphic=""; graphic_caption=""; graphic_age=0
	substitution_queue.clear(); substitution_card.clear(); substitution_age=0
	for actor in game.stadium.sidelines.actors:
		if actor.role=="fourth": actor.substitution_board.hide(); actor.target_point=Vector3.INF

func substitution(outgoing: Dictionary,incoming: Dictionary,team: int) -> void:
	if game.training or game.menu_match.running: return
	substitution_queue.append({"out":outgoing.duplicate(),"in":incoming.duplicate(),"team":team})

func update_substitution(delta: float) -> void:
	substitution_age+=delta
	if not substitution_card.is_empty() and substitution_age>=5.5:
		substitution_card.clear()
		for actor in game.stadium.sidelines.actors:
			if actor.role=="fourth": actor.substitution_board.hide(); actor.target_point=Vector3.INF
	if substitution_card.is_empty() and not substitution_queue.is_empty():
		substitution_card=substitution_queue.pop_front(); substitution_age=0
		for actor in game.stadium.sidelines.actors:
			if actor.role=="fourth":
				actor.substitution_board.show_numbers(substitution_card.out.shirt,substitution_card["in"].shirt)
				actor.target_point=Vector3(P.HALF_WIDTH+1.65,0,0)

func goal_caption() -> String:
	var title: String=game.team_name(game.goal_team)
	if game.last_kicker>=0 and game.players[game.last_kicker].team==game.goal_team:
		title+="  ·  "+game.players[game.last_kicker].display_name
	return title

func show_graphic(kind: String,label: String,length: float=1.0) -> void:
	graphic=kind; graphic_caption=label; graphic_age=0; graphic_duration=length

func graphic_weight() -> float:
	if graphic=="": return 0.0
	return smoothstep(0.0,0.14,graphic_age)*(1.0-smoothstep(graphic_duration-0.16,graphic_duration,graphic_age))

func offer(value: String,index: int,other: Node3D=null) -> void:
	if game.training or game.menu_match.running or game.state in ["menu","setup","finished"] or index<0: return
	if cooldown>0 and value!="substitution": return
	queued={"kind":value,"index":index,"other":other,"life":2.5}

func restart() -> void:
	if not queued.is_empty() or game.match_time<game.LENGTH*.7 or abs(game.score[0]-game.score[1])>1: return
	var side: int=0 if game.score[0]<=game.score[1] else 1
	for actor in game.stadium.sidelines.actors:
		if actor.role=="coach" and actor.team==side:
			game.stadium.sidelines.instruct(side,"attack" if game.score[side]<game.score[1-side] else "balance")
			offer("coach",side*11+9,actor)
			return

func finish() -> void:
	if active:
		game.match_camera.apply_projection(); game.match_camera.snap=true
	active=false; kind=""; subject=-1; partner=null

func update(delta: float) -> void:
	if game.state=="paused": return
	update_substitution(delta)
	if graphic!="":
		graphic_age+=delta
		if graphic_age>=graphic_duration: graphic=""
	cooldown=maxf(0,cooldown-delta)
	if active:
		age+=delta
		if age>=duration or game.state not in ["restart","halftime"] or game.frontend.visible or game.match_menu.visible or not game.players[subject].visible:
			finish()
	if queued.is_empty(): return
	queued.life-=delta
	if queued.life<=0 or game.state in ["playing","goal","replay","set_piece"]:
		queued.clear(); return
	if active or game.state not in ["restart","halftime"] or game.frontend.visible or not game.send_off.confrontation().is_empty(): return
	if game.coaching.opened: return
	active=true; kind=queued.kind; subject=queued.index; partner=queued.other
	caption=game.players[subject].display_name
	if kind=="coach": caption=game.team_name(game.players[subject].team)
	elif kind=="substitution" and game.management.transit.has(subject):
		caption+=" → "+str(game.management.bench[game.players[subject].team][game.management.transit[subject].reserve].name)
	age=0; duration=1.9 if kind=="substitution" else 1.6; cooldown=13
	queued.clear()

func handle(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		if event.device!=game.controller.device: return false
		if consumed.has(event.button_index):
			if not event.pressed: consumed.erase(event.button_index)
			return true
	if not active or game.state=="paused": return false
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B]:
			consumed[event.button_index]=true; finish(); return true
		finish()
	elif event is InputEventKey and event.pressed:
		var skip: bool=event.keycode in [KEY_SPACE,KEY_ENTER]
		finish(); return skip
	elif event is InputEventMouseButton and event.pressed: finish()
	return false

func camera() -> bool:
	if not active or game.state not in ["restart","halftime","paused"]: return false
	var p=game.players[subject]
	var focus: Vector3=p.position+Vector3.UP*1.4
	if is_instance_valid(partner): focus=focus.lerp(partner.position+Vector3.UP*1.2,.45)
	var front: Vector3=p.facing.normalized()
	if kind=="coach" and is_instance_valid(partner):
		focus=partner.position+Vector3.UP*1.35
		front=-partner.global_basis.z.normalized()
	if front.length()<.5: front=Vector3.FORWARD
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
	game.camera.position=focus+front*6+Vector3(-front.z,.9,front.x)*1.8
	# Shoot touchline scenes from the pitch, never through the dugout glazing.
	if kind=="substitution":
		game.camera.position=focus+Vector3(-2.8,1.1,5.8 if game.players[subject].team==0 else -5.8)
	elif kind=="coach":
		game.camera.position=focus+Vector3(-5.6,1.1,3.0 if game.players[subject].team==0 else -3.0)
	elif absf(focus.x)>26:
		game.camera.position=focus+Vector3(-signf(focus.x)*5.5,1.2,3.2)
	elif absf(focus.z)>42:
		game.camera.position=focus+Vector3(3.2,1.2,-signf(focus.z)*5.5)
	game.camera.look_at(focus)
	return true

func draw(hud) -> void:
	if not active: return
	if kind=="substitution" and not substitution_card.is_empty(): return
	hud.draw_set_transform(game.ui.edge_offset(0,1))
	hud.panel(Rect2(412,780,616,54),Color(.035,.085,.075,.92),8)
	hud.text({"miss":"KAÇAN FIRSAT","coach":"KENARDAN TALİMAT","substitution":"OYUNCU DEĞİŞİKLİĞİ"}.get(kind,"SAHADAN"),Vector2(430,802),10,hud.GOLD,true)
	hud.text(caption,Vector2(430,823),15,hud.PAPER,true)
	if game.controller.using_gamepad: hud.pad_hints(Vector2(898,808),[["A","Geç"]],23,11)
	else: hud.text("SPACE · GEÇ",Vector2(910,813),11,hud.MUTE)
	hud.draw_set_transform(Vector2.ZERO)

func draw_graphic(hud) -> void:
	draw_substitution(hud)
	var weight := graphic_weight()
	if weight<=0: return
	hud.draw_set_transform(game.ui.edge_offset(0,1))
	var y := lerpf(918,758,weight)
	hud.panel(Rect2(412,y,616,54),Color(.035,.085,.075,.92),8)
	hud.draw_rect(Rect2(412,y,5,54),hud.GOLD)
	hud.text("GOL" if graphic=="goal" else "SAHADAN",Vector2(430,y+22),10,hud.GOLD,true)
	hud.text(graphic_caption,Vector2(430,y+43),15,hud.PAPER,true)
	hud.center("%d  –  %d" % game.score,Vector2(948,y+36),22,hud.PAPER)
	hud.draw_set_transform(Vector2.ZERO)

func draw_substitution(hud) -> void:
	if substitution_card.is_empty(): return
	hud.draw_set_transform(game.ui.edge_offset(0,1))
	var entry := smoothstep(0,.22,substitution_age)*(1-smoothstep(5.15,5.5,substitution_age))
	var y := lerpf(920,725,entry)
	var red := Color("ef8074"); var green := Color("93d6ac")
	hud.panel(Rect2(402,y,636,94),Color(.025,.055,.062,.96),7)
	hud.draw_rect(Rect2(402,y,4,94),hud.GOLD)
	hud.text("OYUNCU DEĞİŞİKLİĞİ  ·  "+game.team_name(substitution_card.team),Vector2(422,y+24),11,hud.GOLD,true)
	hud.draw_line(Vector2(422,y+36),Vector2(1016,y+36),Color(.3,.4,.39,.6),1)
	var outgoing: Dictionary=substitution_card.out
	var incoming: Dictionary=substitution_card["in"]
	hud.text("↓ %02d" % outgoing.shirt,Vector2(422,y+69),23,red,true)
	hud.text(str(outgoing.name).substr(0,16),Vector2(487,y+65),16,hud.PAPER,true)
	hud.text("ÇIKAN",Vector2(487,y+82),9,red)
	hud.text("↑ %02d" % incoming.shirt,Vector2(734,y+69),23,green,true)
	hud.text(str(incoming.name).substr(0,16),Vector2(799,y+65),16,hud.PAPER,true)
	hud.text("GİREN",Vector2(799,y+82),9,green)
	hud.draw_set_transform(Vector2.ZERO)
