extends Node3D
const P = preload("res://scripts/pitch_dimensions.gd")
const G = preload("res://scripts/geometry.gd")
const Actor = preload("res://scripts/sideline_actor.gd")
var actors: Array[Node3D] = []
var team_labels: Array[Label3D] = []
var clock := 0.0
var event_kind := ""
var event_team := 0
var event_age := 100.0
var event_duration := 0.0
var attention := 0.0
var team_focus := 0
var game
var fetch_phase := ""
var fetch_boy: Node3D
var fetch_age := 0.0
var coach_orders: Array = [{},{}]
var entries: Dictionary = {}
var departures: Array=[]
# Off-camera staff wait to pose until they can be seen (see update()).
var cull_offscreen := true

func retain_departing(p) -> void:
	var actor=game.Player.new()
	actor.team=p.team; actor.number=p.number; actor.keeper=p.keeper
	add_child(actor)
	actor.apply_identity(p.identity()); actor.apply_kit(game.clubs.kit(p.team))
	actor.position=p.position; actor.facing=p.facing; actor.rig.transform=p.rig.transform
	for i in range(p.kick_joints.size()): actor.kick_joints[i].transform=p.kick_joints[i].transform
	actor.head_joint.transform=p.head_joint.transform
	actor.collision_layer=0; actor.collision_mask=1; actor.marker.hide()
	var target:=Vector3(P.HALF_WIDTH+5.5,0,-12 if p.team==0 else 12)
	departures.append({"player":actor,"target":target})

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.state in ["paused","replay","career"]: return
	for item in departures:
		var p=item.player
		var offset: Vector3=(item.target-p.position)*Vector3(1,0,1)
		p.desired=offset.normalized()*minf(1,offset.length())
		p.stamina_free_movement=true; p.step(delta,3.2); p.marker.hide()

func start_entry(slot: int,reserve: int,gate: Vector3) -> void:
	var team: int=game.players[slot].team
	for actor in actors:
		if actor.role=="substitute" and actor.team==team and actor.number==12+reserve:
			entries[slot]={"actor":actor,"gate":gate+Vector3(.85,0,0),"age":0.0,"greet":false}
			actor.visible=true
			break

func step_entry(slot: int,p,delta: float) -> bool:
	if not entries.has(slot): return true
	var item: Dictionary=entries[slot]
	var actor=item.actor
	actor.target_point=item.gate
	var near: bool=game.flat_distance(actor.position,item.gate)<.15 and game.flat_distance(p.position,item.gate)<1.12
	actor.animate_actor(delta+actor.pending_delta,clock,p.position,"handshake" if near else "entry",1)
	actor.pending_delta=0.0
	if near:
		p.facing=Vector3.RIGHT; p.celebration="handshake"
		if not item.greet:
			item.greet=true
			game.broadcast.offer("substitution",slot,actor)
		item.age+=delta
	return item.age>.7

func finish_entry(slot: int) -> void:
	if not entries.has(slot): return
	entries[slot].actor.visible=false
	entries.erase(slot)

func instruct(team: int,order: String) -> void:
	coach_orders[team]={"kind":order,"time":5.2}

func _ready() -> void:
	for team in range(2): build_dugout(team)
	build_touchline()
	add_child(preload("res://scripts/sideline_props.gd").new())
	reset()

func build_touchline() -> void:
	for corner in [Vector3((P.HALF_WIDTH+3.1),0,-48.6),Vector3((P.HALF_WIDTH+3.1),0,48.6),Vector3(-(P.HALF_WIDTH+3.1),0,-48.6),Vector3(-(P.HALF_WIDTH+3.1),0,48.6),Vector3((P.HALF_WIDTH+3.1),0,0),Vector3(-(P.HALF_WIDTH+3.1),0,0)]:
		add_actor(0 if corner.z<0 else 1,"ball_boy",30+actors.size(),corner)
	add_actor(0,"fourth",40,Vector3((P.HALF_WIDTH+6.35),0,0))
	add_actor(0,"photographer",41,Vector3((P.HALF_WIDTH+1.7),0,-22.4))

func build_dugout(team: int) -> void:
	var z := -12.0 if team==0 else 12.0
	var shelter := Node3D.new()
	add_child(shelter)
	shelter.position = Vector3((P.HALF_WIDTH+5.15),0,z)
	shelter.rotation.y = PI*0.5
	var frame := G.material(Color("637878"),0.42)
	var trim := G.material(Color("244d43") if team==0 else Color("804738"))
	var chair := G.material(Color("315f51") if team==0 else Color("874e43"))
	var glass := G.material(Color(0.52,0.70,0.73,0.18),0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	G.block(shelter,Vector3(10.5,0.08,2.15),Vector3(0,0.04,0),G.material(Color("424e4c")))
	for x in [-5.15,5.15]:
		for depth in [-0.95,0.95]:
			G.rod(shelter,Vector3(x,0.06,depth),Vector3(x,2.30,depth),0.045,frame)
		var panel = G.block(shelter,Vector3(0.035,2.10,1.88),Vector3(x,1.20,0),glass)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		G.rod(shelter,Vector3(x,2.3,-0.95),Vector3(x,2.3,0.95),0.045,frame)
	var back = G.block(shelter,Vector3(10.3,1.98,0.035),Vector3(0,1.21,0.96),glass)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var roof = G.block(shelter,Vector3(10.5,0.045,2.15),Vector3(0,2.32,0),glass)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for depth in [-1.03,0.99]: G.block(shelter,Vector3(10.55,0.14,0.08),Vector3(0,2.31,depth),frame)
	G.block(shelter,Vector3(10.48,0.26,0.065),Vector3(0,2.29,-1.05),trim)
	var label := Label3D.new()
	team_labels.append(label)
	label.text = "KIYI SPOR  ·  YEDEK KULÜBESİ" if team==0 else "ATLAS FC  ·  YEDEK KULÜBESİ"
	label.font_size = 48
	label.pixel_size = 0.0035
	label.outline_size = 0
	label.modulate = Color("e3e8dc")
	shelter.add_child(label)
	label.position = Vector3(0,2.29,-1.092)
	label.rotation.y = PI
	for i in range(7):
		var x := -3.75+i*1.25
		G.block(shelter,Vector3(0.66,0.15,0.67),Vector3(x,0.44,0.02),chair)
		var seatback = G.block(shelter,Vector3(0.66,0.69,0.13),Vector3(x,0.79,0.38),chair)
		seatback.rotation.x = 0.12
		for edge in [-0.33,0.33]:
			G.rod(shelter,Vector3(x+edge,0.12,0.20),Vector3(x+edge,0.73,0.20),0.024,frame)
			G.rod(shelter,Vector3(x+edge,0.73,0.20),Vector3(x+edge,0.73,-0.25),0.024,frame)
		add_actor(team,"substitute",12+i,shelter.to_global(Vector3(x,0.04,0.04)))
	add_actor(team,"coach",24+team,Vector3((P.HALF_WIDTH+1.75),0,z))
	add_actor(team,"assistant",26+team,Vector3((P.HALF_WIDTH+2.65),0,z+4.6))
	add_actor(team,"physio",28+team,Vector3((P.HALF_WIDTH+5.1),0,z-5.9))
	G.block(self,Vector3(0.62,0.48,0.63),Vector3((P.HALF_WIDTH+5.2),0.24,z-5.9),chair)
	var kit = G.block(self,Vector3(0.45,0.36,0.65),Vector3((P.HALF_WIDTH+4.6),0.22,z-5.65),G.material(Color("a05543")))
	G.block(kit,Vector3(0.012,0.21,0.055),Vector3(-0.23,0,0),G.material(Color("ede9dd")))
	G.block(kit,Vector3(0.014,0.055,0.21),Vector3(-0.23,0,0),G.material(Color("ede9dd")))
	G.block(self,Vector3(0.62,0.62,0.62),Vector3((P.HALF_WIDTH+4.9),0.34,z+5.75),G.material(Color("56768b")))
	G.block(self,Vector3(0.66,0.06,0.66),Vector3((P.HALF_WIDTH+4.9),0.68,z+5.75),G.material(Color("dedfd3")))
	for i in range(3):
		G.cylinder(self,0.055,0.23,Vector3((P.HALF_WIDTH+4.65)+i*0.17,0.835,z+5.75),G.material(Color("b0c8cb")))
		G.cylinder(self,0.035,0.045,Vector3((P.HALF_WIDTH+4.65)+i*0.17,0.97,z+5.75),trim)
	# The shelter (seats, frame, trim) never moves: merge its opaque pieces per
	# material exactly like the stadium. Glass and the label stay separate.
	preload("res://scripts/static_geometry.gd").batch(shelter,[])

func add_actor(team: int,role: String,number: int,location: Vector3) -> void:
	var actor = Actor.new()
	actor.team = team
	actor.role = role
	actor.number = number
	actor.name = "%s_%d_%d" % [role,team,number]
	actor.home = location
	actor.position = location
	add_child(actor)
	actors.append(actor)

func reset() -> void:
	for item in departures: item.player.queue_free()
	departures.clear()
	clock = 0
	event_kind = ""
	event_age = 100
	event_duration = 0
	attention = 0
	coach_orders=[{},{}]
	entries.clear()
	clear_fetch()
	for actor in actors:
		actor.visible=true
		actor.avoid_people.clear()
		actor.position = actor.home
		actor.response = 0
		actor.pending_delta=0.0
		actor.target_point=Vector3.INF
		if actor.role=="fourth": actor.substitution_board.hide()
		actor.seated = 1.0 if actor.role in ["substitute","physio"] else (0.42 if actor.role=="photographer" else 0.0)
		actor.animate_actor(1,clock,Vector3.ZERO,"watch",0)

func react(kind: String,team: int,_location: Vector3) -> void:
	if event_kind=="goal" and event_age<event_duration and kind!="goal": return
	event_kind = kind
	event_team = team
	event_age = 0
	event_duration = 12.0 if kind=="goal" else (2.5 if kind=="save" else 1.8)
	if kind=="goal" and is_instance_valid(game) and game.match_time>game.LENGTH*.85 and game.score[team]==game.score[1-team]+1: event_duration=22

func update(delta: float,ball_position: Vector3,ball_velocity: Vector3,team: int,playing: bool,stoppage: String="",restart_point: Vector3=Vector3.ZERO) -> void:
	clock += delta
	for order in coach_orders:
		if not order.is_empty(): order.time=maxf(0,order.time-delta)
	event_age += delta
	team_focus = team
	var pressure := 0.0
	if playing and absf(ball_position.z)>27 and absf(ball_position.x)<25:
		pressure = clampf((absf(ball_position.z)-27)/20,0,1)
		if ball_velocity.length()>16: pressure = maxf(pressure,0.65)
	attention = lerpf(attention,pressure,1-exp(-delta*3))
	step_fetch(delta,stoppage,restart_point,ball_position)
	var collector := fetch_boy if fetch_phase!="" else collector_for(stoppage,restart_point)
	var view: Array[Plane]=[]
	if is_instance_valid(game) and is_instance_valid(game.camera) and game.camera.is_inside_tree():
		view.assign(game.camera.get_frustum())
	for actor in actors:
		if not actor.visible: continue
		var entering := false
		for entry in entries.values():
			if entry.actor==actor: entering=true; break
		if entering: continue
		var actor_mode := "encourage" if attention>0.35 else "watch"
		var intensity := attention*0.75
		actor.target_point=Vector3.INF
		var delay := float(actor.number%7)*0.065
		var age := event_age-delay
		if actor.role=="ball_boy":
			actor.avoid_people.clear()
			if is_instance_valid(game):
				for official in game.referees.actors:
					if official.visible: actor.avoid_people.append(official.position*Vector3(1,0,1))
			if actor==fetch_boy and fetch_phase!="":
				actor_mode=fetch_mode()
				intensity=1
				actor.target_point=fetch_target(restart_point,ball_position)
			elif collector==actor:
				actor_mode="collect"
				intensity=1.0
				actor.target_point=outside(restart_point if stoppage!="" else ball_position)
			else:
				actor_mode="watch"
				intensity=0.15
		elif actor.role=="photographer":
			actor_mode="watch"
			intensity=0
		elif actor.role=="fourth":
			actor_mode="watch"
			intensity=0
		elif actor.role=="substitute" and actor.number==14 and playing and event_age>event_duration and clock>22:
			actor_mode="jog"
			intensity=0.35
			actor.target_point=Vector3((P.HALF_WIDTH+1.55),0,(-9.5 if actor.team==0 else 9.5)+sin(clock*0.32+actor.team)*6.2)
		elif age>0 and age<event_duration:
			var strength := smoothstep(0,0.30,age)*(1-smoothstep(event_duration-0.7,event_duration,age))
			if event_kind=="goal":
				actor_mode = "celebrate" if actor.team==event_team else "disappointed"
				intensity = strength
			elif event_kind=="save":
				actor_mode = "encourage" if actor.team==event_team else "disappointed"
				intensity = strength*0.85
			elif event_kind=="miss":
				actor_mode = "disappointed" if actor.team==event_team else "encourage"
				intensity = strength*0.85
			elif event_kind=="shot":
				actor_mode = "encourage"
				intensity = strength*0.9
		if actor.role=="coach" and not coach_orders[actor.team].is_empty() and coach_orders[actor.team].time>0 and not (event_kind=="goal" and age<event_duration):
			actor_mode="tactic_"+coach_orders[actor.team].kind
			intensity=minf(1,coach_orders[actor.team].time*2)
			actor.target_point=actor.home+Vector3(-.45,0,-1.0 if actor.team==0 else 1.0)
		# Ball boys move with the restart, so they always update. Everyone else is
		# only drawn: off-camera poses wait and resume with the elapsed time.
		if cull_offscreen and actor.role!="ball_boy" and not in_view(view,actor):
			actor.mode=actor_mode
			actor.pending_delta+=delta
			continue
		actor.animate_actor(delta+actor.pending_delta,clock,ball_position,actor_mode,intensity)
		actor.pending_delta=0.0

const VIEW_MARGIN := 5.0

func in_view(planes: Array[Plane],actor: Node3D) -> bool:
	# The margin covers the person and a low floodlight shadow reaching the frame.
	var center: Vector3=actor.global_position+Vector3(0,1,0)
	for plane in planes:
		if plane.distance_to(center)>VIEW_MARGIN: return false
	return true

func collector_for(stoppage: String,restart_point: Vector3) -> Node3D:
	if stoppage not in ["TAÇ","KORNER"]: return null
	var best: Node3D=null
	var nearest := INF
	for actor in actors:
		if actor.role!="ball_boy": continue
		var cost: float=actor.home.distance_to(restart_point)
		if cost<nearest: nearest=cost; best=actor
	return best

func outside(point: Vector3) -> Vector3:
	var at := Vector3(point.x,0,point.z)
	if absf(at.x)>=absf(at.z)*P.HALF_WIDTH/P.HALF_LENGTH:
		at.x=signf(at.x if absf(at.x)>0.2 else 1.0)*(P.HALF_WIDTH+2.55)
		at.z=clampf(at.z,-48.8,48.8)
	else:
		at.z=signf(at.z if absf(at.z)>0.2 else 1.0)*51.15
		at.x=clampf(at.x,-P.HALF_WIDTH+.8,P.HALF_WIDTH-.8)
	return at

func is_fetching() -> bool:
	return fetch_phase in ["run","pickup","carry","wait"]

func claim_throw_in() -> bool:
	if is_fetching() and is_instance_valid(game) and game.ball.held_by==fetch_boy: return true
	if not owns_loose_ball(): return false
	return start_fetch() or is_fetching()

func start_fetch() -> bool:
	if not owns_loose_ball(): return false
	fetch_boy=nearest_boy(game.ball.position)
	if fetch_boy==null: return false
	fetch_phase="run"
	fetch_age=0
	return true

func clear_fetch() -> void:
	if is_instance_valid(game) and is_instance_valid(game.ball) and game.ball.held_by==fetch_boy:
		game.ball.release_hold()
	fetch_phase=""
	fetch_boy=null
	fetch_age=0

func fetch_mode() -> String:
	if fetch_phase=="pickup": return "pickup"
	if fetch_phase in ["carry","wait"]: return "carry"
	return "collect"

func fetch_target(restart_point: Vector3,ball_position: Vector3) -> Vector3:
	if fetch_phase=="return" and fetch_boy!=null: return fetch_boy.home
	if fetch_phase in ["carry","wait"]: return outside(restart_point)
	var at := Vector3(ball_position.x,0,ball_position.z)
	at.x=signf(at.x if absf(at.x)>0.2 else 1.0)*maxf(P.HALF_WIDTH+.7,absf(at.x))
	at.z=clampf(at.z,-49.2,49.2)
	return at

func owns_loose_ball() -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.ball): return false
	if game.restart_type!="TAÇ" or game.state not in ["restart","set_piece"]: return false
	var ball=game.ball
	if ball.held_by!=null and ball.held_by!=fetch_boy: return false
	if absf(ball.position.x)<P.HALF_WIDTH-.4: return false
	var speed: float=Vector2(ball.linear_velocity.x,ball.linear_velocity.z).length()
	if fetch_phase=="" and (ball.position.y>0.85 or speed>2.8): return false
	var boy := nearest_boy(ball.position)
	if boy==null: return false
	var boy_gap: float=boy.position.distance_to(Vector3(ball.position.x,0,ball.position.z))
	var player_gap := INF
	for p in game.players:
		if not p.visible or p.dismissed: continue
		player_gap=minf(player_gap,game.flat_distance(p.position,ball.position))
	return boy_gap+1.5<player_gap or player_gap>9.0

func nearest_boy(point: Vector3) -> Node3D:
	var best: Node3D=null
	var nearest := INF
	for actor in actors:
		if actor.role!="ball_boy": continue
		var cost: float=actor.position.distance_to(Vector3(point.x,0,point.z))
		if cost<nearest: nearest=cost; best=actor
	return best

func step_fetch(delta: float,stoppage: String,restart_point: Vector3,ball_position: Vector3) -> void:
	var player_has: bool=is_instance_valid(game) and is_instance_valid(game.ball) and game.ball.held_by!=null and game.ball.held_by!=fetch_boy
	var back_in: bool=is_instance_valid(game) and is_instance_valid(game.ball) and absf(game.ball.position.x)<P.HALF_WIDTH-.4 and game.ball.held_by!=fetch_boy
	if stoppage!="TAÇ" or player_has or back_in or (fetch_phase=="" and not owns_loose_ball()):
		if fetch_phase!="" and fetch_phase!="return":
			if is_instance_valid(game) and game.ball.held_by==fetch_boy: game.ball.release_hold()
			fetch_phase="return" if fetch_boy!=null else ""
			fetch_age=0
		if fetch_phase=="return" and fetch_boy!=null and fetch_boy.position.distance_to(fetch_boy.home)<0.25:
			clear_fetch()
		return
	if fetch_phase=="" or fetch_phase=="return": start_fetch()
	if fetch_boy==null: return
	fetch_age+=delta
	var ball=game.ball
	var settled: bool=ball.position.y<0.85 and Vector2(ball.linear_velocity.x,ball.linear_velocity.z).length()<2.8
	if fetch_phase=="run":
		var gap: float=fetch_boy.position.distance_to(Vector3(ball.position.x,0,ball.position.z))
		if settled and gap<1.15:
			fetch_phase="pickup"
			fetch_age=0
	elif fetch_phase=="pickup":
		if fetch_age>0.32 and settled:
			ball.hold(fetch_boy)
			fetch_phase="carry"
			fetch_age=0
	elif fetch_phase=="carry":
		if ball.held_by==fetch_boy: ball.hold_target=fetch_boy.hand_center()
		if fetch_boy.position.distance_to(outside(restart_point))<0.55:
			fetch_phase="wait"
			fetch_age=0
	elif fetch_phase=="wait":
		if ball.held_by==fetch_boy: ball.hold_target=fetch_boy.hand_center()
