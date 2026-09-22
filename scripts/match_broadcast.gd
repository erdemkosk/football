extends RefCounted
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

func reset() -> void:
	finish(); queued.clear(); consumed.clear(); cooldown=0

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
	hud.panel(Rect2(412,780,616,54),Color(.035,.085,.075,.92),8)
	hud.text({"miss":"KAÇAN FIRSAT","coach":"KENARDAN TALİMAT","substitution":"OYUNCU DEĞİŞİKLİĞİ"}.get(kind,"SAHADAN"),Vector2(430,802),10,hud.GOLD,true)
	hud.text(caption,Vector2(430,823),15,hud.PAPER,true)
	if game.controller.using_gamepad: hud.pad_hints(Vector2(898,808),[["A","Geç"]],23,11)
	else: hud.text("SPACE · GEÇ",Vector2(910,813),11,hud.MUTE)
