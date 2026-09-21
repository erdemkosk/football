extends RefCounted
## Deterministic restart formations, then a protected, player-controlled kick.
const Passing = preload("res://scripts/passing.gd")
const Recovery = preload("res://scripts/restart_recovery.gd")
var recovery := Recovery.new()
var game
var taker := -1
var wall: Array[int] = []
var targets: Dictionary = {}
var direction := Vector3.FORWARD
var power := 0.0
var button := 0
var ready_age := 0.0
var runup := -1.0
var pending_velocity := Vector3.ZERO
var pending_curve := 0.0
var shot_curve := 0.0
var receiver := -1
var target := Vector3.ZERO

func clear() -> void:
	recovery.reset()
	if is_instance_valid(game.ball): game.ball.release_hold()
	for p in game.players:
		p.set_piece_pose = ""
		p.shot_preparation=0
		p.handling_blend=0
		p.wall_hold = 0
		p.wall_jump_delay = -1
	wall.clear()
	targets.clear()
	button = 0
	power = 0
	pending_curve=0
	shot_curve=0
	runup = -1
	taker = -1

func prepare() -> void:
	clear()
	var team: int = game.restart_team
	var kind: String = game.restart_type
	var point: Vector3 = game.restart_point
	var forward: float = game.attack_sign(team)
	var goal := Vector3(0,0,forward*50)
	var distance := point.distance_to(goal)
	var nearest := INF
	for i in range(game.players.size()):
		var p = game.players[i]
		if not p.visible: continue
		if p.team==team and (p.keeper==(kind=="KALE VURUŞU")):
			var rating: float = p.position.distance_to(point)
			if kind=="PENALTI": rating = 0 if p.number==10 else 100+p.number
			if rating<nearest: nearest=rating; taker=i
		var pos: Vector3 = p.home+Vector3(point.x*0.16,0,point.z*0.34)
		pos.x = clampf(pos.x,-29,29)
		pos.z = clampf(pos.z,-44,44)
		if p.keeper: pos = Vector3(clampf(point.x*0.06,-2,2),0,-game.attack_sign(p.team)*46)
		targets[i] = pos
	if taker<0:
		for i in targets:
			if game.players[i].team==team: taker=i; break
	if taker<0: return
	direction = (goal-point).normalized() if distance<38 else Vector3(0,0,forward)
	if kind=="TAÇ": direction=Vector3(-signf(point.x),0,forward*0.3).normalized()
	if kind=="KORNER": direction=(Vector3(0,0,forward*43)-point).normalized()
	var attackers: Array[int] = []
	var defenders: Array[int] = []
	for i in targets:
		if i==taker or game.players[i].keeper: continue
		if game.players[i].team==team: attackers.append(i)
		else: defenders.append(i)
	if kind in ["KORNER","SERBEST VURUŞ","ENDİREKT VURUŞ"] and distance<43:
		# Two forwards attack the posts, midfielders occupy the penalty spot/edge.
		attackers.reverse()
		for j in range(mini(5,attackers.size())):
			var spaces = [Vector3(-4,0,forward*44),Vector3(4,0,forward*42),Vector3(0,0,forward*37),Vector3(-12,0,forward*34),Vector3(13,0,forward*32)]
			targets[attackers[j]] = spaces[j]
		for j in range(mini(5,defenders.size())):
			targets[defenders[j]] = targets[attackers[j]]+Vector3(0.9,0,forward*1.1)
	if kind in ["SERBEST VURUŞ","ENDİREKT VURUŞ"] and distance<36:
		var count := 4 if distance<29 else 3
		if distance<22: count=5
		defenders.sort_custom(func(a,b): return game.players[a].position.distance_to(point)<game.players[b].position.distance_to(point))
		var near_post := Vector3(-2.2 if point.x<0 else 2.2,0,forward*50)
		var axis := (near_post-point).normalized()
		var across := Vector3(-axis.z,0,axis.x)
		for j in range(mini(count,defenders.size())):
			var index: int = defenders[j]
			var pos := point+axis*9.6+across*(j-(count-1)*0.5)*0.82
			if distance<10: pos=Vector3((j-(count-1)*0.5)*0.82,0,forward*50)
			targets[index] = pos
			wall.append(index)
			game.players[index].set_piece_pose = "wall"
		# The wall covers the near post; the goalkeeper sees the other side.
		targets[11 if team==0 else 0] = Vector3(1.25 if point.x<0 else -1.25,0,forward*48.7)
	if kind=="PENALTI":
		var spaces = [Vector2(-7,29.1),Vector2(8,29.5),Vector2(-14,32),Vector2(15,31.8),Vector2(23,31),Vector2(-23,30),Vector2(-4,22),Vector2(5,22.8),Vector2(-16,20),Vector2(18,21)]
		for j in range(attackers.size()): targets[attackers[j]]=Vector3(spaces[j].x,0,forward*spaces[j].y)
		for j in range(defenders.size()): targets[defenders[j]]=Vector3(spaces[j].x+1.1,0,forward*(spaces[j].y-1.3))
		targets[11 if team==0 else 0] = Vector3(0,0,forward*50)
	if kind=="TAÇ":
		for j in range(mini(3,attackers.size())):
			targets[attackers[j]] = Vector3(point.x-signf(point.x)*(7+j*5),0,clampf(point.z+(j-1)*7,-46,46))
	if kind=="KALE VURUŞU":
		for j in range(mini(4,attackers.size())):
			targets[attackers[j]] = Vector3(-23+j*15,0,-forward*(36 if j%2 else 29))
	if kind=="SANTRA":
		for i in targets:
			var p=game.players[i]
			var pos: Vector3=p.home
			pos.z=-game.attack_sign(p.team)*maxf(2.5,pos.z*-game.attack_sign(p.team))
			targets[i]=pos
		if not attackers.is_empty():
			targets[attackers.back()]=Vector3(5,0,-forward*3)
			direction=(targets[attackers.back()]-point).normalized()
	# Project everyone into legal locations before the referee releases the kick.
	for i in targets:
		if i==taker: continue
		var p = game.players[i]
		var pos: Vector3 = targets[i]
		if kind=="KALE VURUŞU" and p.team!=team and absf(pos.x)<20.8 and pos.z*(-forward)>32.7:
			pos.z = -forward*32.7
		if p.team!=team and kind!="KALE VURUŞU":
			var minimum := 2.4 if kind=="TAÇ" else (10.2 if kind=="KORNER" else 9.3)
			var on_goal_line := absf(pos.z-forward*50)<0.1 and absf(pos.x)<3.3
			if not on_goal_line: pos=outside_circle(pos,point,minimum)
		if p.team==team and wall.size()>=3:
			for member in wall:
				pos=outside_circle(pos,targets[member],1.65)
		if p.team==team: pos=outside_circle(pos,point,2.0)
		targets[i] = pos
	targets[taker] = point-direction*0.92
	if kind=="TAÇ":
		targets[taker]=Vector3(signf(point.x)*32.32,0,point.z)
	for i in targets:
		var p = game.players[i]
		p.desired=Vector3.ZERO
		p.sprinting=false
		p.touch_cooldown=0.35
		p.call_timer=0
	game.ball.active=true
	game.ball.freeze=false
	game.carrier=-1
	game.last_touch=team
	game.last_kicker=-1
	if team==0: game.controlled=taker
	game.last_direction=direction
	ready_age=0
	recovery.begin(self)
	preview()

func outside_circle(pos: Vector3,center: Vector3,radius: float) -> Vector3:
	if game.flat_distance(pos,center)>=radius: return pos
	var delta := (pos-center)*Vector3(1,0,1)
	if delta.length()<0.01: delta=Vector3(-signf(center.x+0.01),0,-signf(center.z+0.01))
	var best := Vector3.ZERO
	var cost := INF
	for step in range(36):
		var candidate := center+delta.normalized().rotated(Vector3.UP,step*TAU/36)*radius
		if absf(candidate.x)>31 or absf(candidate.z)>49: continue
		var d := candidate.distance_to(pos)
		if d<cost: cost=d; best=candidate
	return best if cost<INF else pos

func move_player(index: int,destination: Vector3,delta: float,rate: float=0.9) -> void:
	var p=game.players[index]
	if wall.size()>=3 and index not in wall:
		destination=around_wall(p.position,destination)
	if index in wall and index!=recovery.worker:
		var slot: Vector3=targets[index]
		var across: Vector3=(targets[wall.back()]-targets[wall.front()]).normalized()
		if p.position.distance_to(slot)<4 and absf((slot-p.position).dot(across))>0.3:
			destination=slot+(game.restart_point-slot).normalized()*1.45
	if index!=taker and (index!=recovery.worker or recovery.phase=="handoff") and recovery.phase in ["stand","handoff","arrange","ready"]:
		destination=recovery.clear_delivered_ball(p.position,destination)
	if game.restart_type=="SANTRA":
		# Returning players cross the whole pitch. Route past already-settled
		# bodies instead of alternating the avoidance side in a head-on contact.
		var route: Vector3=(destination-p.position)*Vector3(1,0,1)
		if route.length()>1.5:
			var ahead := route.normalized()
			for j in targets:
				if j==index: continue
				var obstacle: Vector3=(game.players[j].position-p.position)*Vector3(1,0,1)
				var along := obstacle.dot(ahead)
				if along>0 and along<1.7 and (obstacle-ahead*along).length()<0.9:
					destination=game.players[j].position+Vector3(-ahead.z,0,ahead.x)*1.2
					break
	var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
	p.desired=offset.normalized()*minf(rate,offset.length()*1.2)
	# Yield around nearby bodies while travelling; do not spread a settled wall.
	if offset.length()>0.6:
		for j in targets:
			if j==index: continue
			var gap: Vector3=(p.position-game.players[j].position)*Vector3(1,0,1)
			if gap.length()<1.15 and gap.length()>0.01:
				var side := Vector3(-offset.z,0,offset.x).normalized()
				if side.dot(gap)<0: side=-side
				p.desired+=side*(1.15-gap.length())*0.8
	p.sprinting=false
	p.chosen=game.is_user_player(index)
	p.stamina_free_movement=recovery.is_retriever(index)
	p.step(delta)
	p.stamina_free_movement=false

func around_wall(from: Vector3,to: Vector3) -> Vector3:
	# A compact wall is a continuous obstacle; route around its end instead of
	# relying on body avoidance to squeeze an attacker between defenders.
	var left: Vector3=targets[wall.front()]
	var right: Vector3=targets[wall.back()]
	var center := (left+right)*0.5
	var across := (right-left).normalized()
	var normal := Vector3(-across.z,0,across.x)
	var start_u := (from-center).dot(across)
	var start_v := (from-center).dot(normal)
	var end_u := (to-center).dot(across)
	var end_v := (to-center).dot(normal)
	if start_v*end_v>0 and absf(start_v)>1.35: return to
	if absf(end_v)<0.01: return to
	var extent := left.distance_to(right)*0.5+1.35
	var target_side := signf(end_v)
	if start_v*target_side>=1.35: return to
	var crossing_u := lerpf(start_u,end_u,clampf(-start_v/(end_v-start_v),0,1))
	if absf(crossing_u)>extent: return to
	var end_sign := 1.0 if start_u+end_u>=0 else -1.0
	if start_u*end_sign<extent-0.12:
		return center+across*extent*end_sign-normal*target_side*1.55
	return center+across*extent*end_sign+normal*target_side*1.55

func settle(delta: float,skip: int=-1) -> void:
	for i in targets:
		if i==skip: continue
		var p = game.players[i]
		var destination: Vector3=targets[i]
		if i==taker and recovery.worker!=taker and recovery.worker>=0 and recovery.phase not in ["relay_prepare","relay_throw"]:
			# Leave the delivery point clear for a teammate or opponent fetching it.
			destination+=Vector3(0,0,-game.attack_sign(game.restart_team)*2.4) if game.restart_type=="TAÇ" else -direction*2.4
		move_player(i,destination,delta)
		if i==taker and recovery.phase in ["relay_prepare","relay_throw"]:
			p.set_piece_pose="receive"
			p.facing=((game.ball.position-p.position)*Vector3(1,0,1)).normalized()
			continue
		var look: Vector3 = game.restart_point-p.position
		if i==taker: look=direction
		look.y=0
		if look.length()>0.1: p.facing=look.normalized()
	if game.ball.held_by!=null: game.ball.hold_target=game.ball.held_by.hand_center()

func formation_ready() -> bool:
	var point: Vector3=game.restart_point
	var kind: String=game.restart_type
	var forward: float = game.attack_sign(game.restart_team)
	for i in targets:
		if i==taker: continue
		var p=game.players[i]
		var distance: float=game.flat_distance(p.position,point)
		if kind=="SANTRA":
			if p.position.z*-game.attack_sign(p.team)<0: return false
			if game.flat_distance(p.position,targets[i])>1.2: return false
		if i in wall and game.flat_distance(p.position,targets[i])>0.2: return false
		if kind=="PENALTI":
			if p.keeper and p.team!=game.restart_team:
				if absf(p.position.z-forward*50)>0.08: return false
			else:
				if distance<9.15 or p.position.z*forward>39: return false
				if absf(p.position.x)<20.16 and p.position.z*forward>33.5: return false
		elif p.team!=game.restart_team:
			if kind=="KALE VURUŞU":
				if absf(p.position.x)<20.16 and p.position.z*forward< -33.5: return false
			else:
				var goal_line := absf(p.position.z-forward*50)<0.1 and absf(p.position.x)<3.3
				if not goal_line and distance<(2.0 if kind=="TAÇ" else 9.15): return false
		if p.team==game.restart_team and wall.size()>=3:
			for member in wall:
				if game.flat_distance(p.position,game.players[member].position)<1.0: return false
	return true

func snap_ready() -> void:
	if taker<0 or targets.is_empty(): return
	for i in targets:
		var p=game.players[i]
		p.position=targets[i]
		p.velocity=Vector3.ZERO
		p.desired=Vector3.ZERO
		p.celebration=""
		p.set_piece_pose=""
		p.handling_blend=0
		var look: Vector3=direction if i==taker else game.restart_point-p.position
		look.y=0
		if look.length()>0.1:
			p.facing=look.normalized()
			p.rig.rotation.y=atan2(-p.facing.x,-p.facing.z)
		p.animate(1)
	game.ball.release_hold()
	game.ball.place(game.restart_point+Vector3(0,0.23,0))
	recovery.phase="arrange"
	recovery.age=1
	recovery.rest_age=1
	recovery.worker=taker
	ready()
	game.camera_focus=Vector3.ZERO
	game.match_camera.apply_projection()
	game.camera.size=game.match_camera.play_size(game.zoom)
	game.update_camera(0)

func ready() -> void:
	if recovery.phase!="arrange" or not recovery.can_ready(): return
	if not game.referees.ready_for_restart(): return
	recovery.phase="ready"
	game.state="set_piece"
	game.ball.active=true
	game.referees.whistle()
	if game.restart_type=="SANTRA":
		game.announce("SANTRA · "+((("A" if game.controller.using_gamepad else "S")+" İLE PAS VEREREK BAŞLA") if game.restart_team==0 else "RAKİP OYUNU BAŞLATIYOR"))
	else:
		game.announce("DÜDÜK · "+("YÖNÜ SEÇ, VURUŞU YAP" if game.restart_team==0 else "RAKİP DURAN TOPU KULLANIYOR"))

func update(delta: float) -> void:
	ready_age+=delta
	settle(delta)
	if runup>=0:
		runup-=delta
		game.players[taker].desired=direction*0.6
		if runup<=0: launch()
		return
	if game.restart_team==1 or game.menu_match.running:
		if ready_age>1.15:
			button=KEY_D if game.restart_type=="PENALTI" or (game.restart_type=="SERBEST VURUŞ" and absf(game.restart_point.z)>22) else (KEY_A if game.restart_type=="KORNER" else KEY_S)
			power=0.60 if button==KEY_D else 0.45
			if button==KEY_D and game.restart_type=="SERBEST VURUŞ": power=0.18
			if button==KEY_D:
				var goal := Vector3(game.rng.randf_range(-2.6,2.6),0,game.attack_sign(game.restart_team)*50)
				direction=(goal-game.restart_point).normalized()
			preview()
			commit()
		return
	var aim: Vector3=aim_input()
	var rate := 0.35 if button==KEY_D or game.restart_type=="PENALTI" else 1.0
	if aim.length()>0.01:
		var turn := direction.signed_angle_to(aim.normalized(),Vector3.UP)
		direction=direction.rotated(Vector3.UP,clampf(turn,-rate*aim.length()*delta,rate*aim.length()*delta))
	if game.restart_type=="PENALTI":
		var anchor := Vector3(0,0,game.attack_sign(game.restart_team))
		var angle := anchor.signed_angle_to(direction,Vector3.UP)
		direction=anchor.rotated(Vector3.UP,clampf(angle,-0.28,0.28))
	if button!=0: power=minf(1,power+delta/(1.15 if button==KEY_D else 0.65))
	game.players[taker].shot_preparation=0.15+power*0.85 if button==KEY_D else 0.0
	game.players[taker].wrapping=1.0 if button==KEY_D and game.finesse_held() else 0.0
	game.last_direction=direction
	preview()

func aim_input() -> Vector3:
	if game.controller.has_separate_aim():
		return game.match_camera.orient(game.controller.separate_aim())
	return game.movement_input()

func input(event: InputEvent) -> void:
	if game.state!="set_piece" or game.restart_team!=0 or runup>=0: return
	if event is InputEventKey and event.keycode in [KEY_S,KEY_A,KEY_D] and not event.echo:
		if event.pressed:
			if game.restart_type=="PENALTI" and event.keycode!=KEY_D: return
			button=event.keycode
			power=0
			shot_curve=game.choose_finesse_curve(direction)
			preview()
		elif button==event.keycode: commit()

func preview() -> void:
	var point: Vector3 = game.restart_point
	pending_curve=shot_curve if button==KEY_D and game.restart_type!="TAÇ" and game.finesse_held() else 0.0
	if button==KEY_D and game.restart_type!="TAÇ":
		var lift := lerpf(1.5,3.5,power) if game.restart_type=="PENALTI" else lerpf(3.1,8.0,power)
		var speed := lerpf(19,32,power)
		var goal := Vector3(0,0,game.attack_sign(game.restart_team)*50)
		var distance := point.distance_to(goal)
		if game.restart_type in ["SERBEST VURUŞ","ENDİREKT VURUŞ"] and distance>15 and distance<36:
			# A softer, longer flight can arc over the wall; a driven kick stays lower.
			speed=lerpf(17,29,power)
			var flight := distance/speed
			lift=clampf((1.25-0.23+4.905*flight*flight)/flight,2,12)
		pending_velocity=direction*speed+Vector3.UP*lift
		target=point+direction*25
		receiver=-1
	else:
		var route = Passing.manual_plan(point+Vector3.UP*0.23,direction,power,game.restart_team,taker,game.players,game.weather)
		receiver=-1
		target=route.target
		pending_velocity=route.velocity
		if button==KEY_A or game.restart_type=="TAÇ":
			target=point+direction*lerpf(10,32,power)
			var flight := lerpf(1.0,2.0,power)
			var start_y: float = game.ball.position.y if game.restart_type=="TAÇ" else 0.23
			pending_velocity=Passing.Motion.lob_velocity(Vector3(point.x,start_y,point.z),Vector3(target.x,0.23,target.z),flight,game.weather)
		if game.restart_type=="TAÇ":
			# A legal throw must enter the field; forward/backward aiming is bounded.
			pending_velocity.x=-signf(point.x)*maxf(3,absf(pending_velocity.x))

func commit() -> void:
	preview()
	runup=0.25
	if game.restart_type!="TAÇ":
		targets[taker]=game.restart_point-direction*0.48
		game.players[taker].shot_preparation=0.5+power*0.5

func launch() -> void:
	var kind: String=game.restart_type
	var team: int=game.restart_team
	game.state="playing"
	game.ball.release_hold()
	game.ball.active=true
	game.boundary_grace=0.04
	game.previous_ball=game.restart_point+Vector3.UP*0.23
	game.rules.restart_taken(kind,team,taker)
	game.referees.ball_in_play(kind,taker)
	game.replay.origin()
	game.strike(taker,pending_velocity,pending_curve,false,"shot" if button==KEY_D and kind!="TAÇ" else "kick")
	if button==KEY_D and kind!="TAÇ": game.shots[team]+=1
	else: game.passes[team]+=1
	var heading: Vector3=(pending_velocity*Vector3(1,0,1)).normalized()
	var reach: float=Vector2(target.x-game.restart_point.x,target.z-game.restart_point.z).length()
	var hint: int=Passing.hint_along(game.restart_point,heading,reach,team,taker,game.players,14,8)
	if hint>=0:
		game.ai_receivers[team]=hint
		game.ai_pass_time[team]=2.5
	for i in wall:
		game.players[i].wall_hold=0.85
		game.players[i].wall_jump_delay=0.12+(i%3)*0.025 if button==KEY_D else -1.0
	game.players[taker].touch_cooldown=0.65
	game.players[taker].set_piece_pose="throw" if kind=="TAÇ" else ""
	if kind=="TAÇ": game.players[taker].wall_hold=0.45
	game.kick_lock=0.2
	runup=-1
	button=0
	power=0
