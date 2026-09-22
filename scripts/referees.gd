extends RefCounted
const Official = preload("res://scripts/referee.gd")
var game
var actors: Array = []
var targets: Array[Vector3] = [Vector3(-8,0,3),Vector3(-33.2,0,-12),Vector3(33.2,0,12)]
var decision := ""
var decision_age := 0.0
var decision_team := 0
var decision_point := Vector3.ZERO
var signal_time := 0.0
var assistant_index := -1
var assistant_stop_z := 0.0
var card_queue: Array[String] = []
var card_stage := ""
var card_age := 0.0
var card_point := Vector3.ZERO
var indirect_pending := false
var indirect_kicker := -1
var clock := 0.0

func build() -> void:
	for i in range(3):
		var actor=Official.new()
		actor.assistant=i>0
		actor.number=30+i
		actor.name="Referee" if i==0 else "AssistantReferee%d" % i
		game.add_child(actor)
		actor.surface=game.weather
		actors.append(actor)
	reset(false)

func reset(show: bool) -> void:
	clear_decision()
	clock=0
	for i in range(3):
		var actor=actors[i]
		actor.visible=show
		actor.position=kickoff_target(i)
		actor.velocity=Vector3.ZERO
		actor.desired=Vector3.ZERO
		actor.prematch=false
		actor.collision_layer=16 if show else 0
		actor.collision_mask=1
		actor.animate(0)

func clear_decision() -> void:
	decision=""
	signal_time=0
	assistant_index=-1
	card_queue.clear()
	card_stage=""
	indirect_pending=false
	indirect_kicker=-1
	for actor in actors:
		actor.signal_pose("")

func kickoff_target(index: int) -> Vector3:
	return [Vector3(-8,0,3),Vector3(-33.2,0,-12),Vector3(33.2,0,12)][index]

func activate(reposition: bool) -> void:
	for i in range(3):
		var actor=actors[i]
		actor.visible=not game.training
		actor.collision_layer=16 if actor.visible else 0
		actor.collision_mask=1
		actor.prematch=false
		actor.signal_pose("")
		if reposition: actor.position=kickoff_target(i); actor.velocity=Vector3.ZERO

func whistle() -> void:
	game.audio.play("whistle")
	if game.training: return
	signal_time=0.75
	actors[0].signal_pose("whistle")

func restart(kind: String,team: int,point: Vector3) -> void:
	if game.training: return
	decision=kind
	decision_team=team
	decision_point=point
	decision_age=0
	assistant_index=-1
	indirect_pending=kind=="ENDİREKT VURUŞ"
	indirect_kicker=-1
	for actor in actors: actor.signal_pose("")
	if kind=="TAÇ": assistant_index=1 if point.x<0 else 2
	elif kind in ["KORNER","KALE VURUŞU"]: assistant_index=1 if point.z<0 else 2

func offside(attacking_team: int,point: Vector3) -> void:
	assistant_index=1 if game.attack_sign(attacking_team)<0 else 2
	assistant_stop_z=actors[assistant_index].position.z
	decision="OFSAYT"
	decision_point=point
	decision_age=0
	var width: float=point.x+32 if assistant_index==1 else 32-point.x
	actors[assistant_index].zone=0 if width<21.3 else (1 if width<42.7 else 2)
	actors[assistant_index].signal_pose("flag_up")

func show_card(point: Vector3,second_yellow: bool,direct: bool=false) -> void:
	card_point=point
	card_queue.assign(["red"] if direct else (["yellow","red"] if second_yellow else ["yellow"]))
	card_stage="approach"
	card_age=0
	game.stadium.react("card",0,point)

func ready_for_restart() -> bool:
	return card_stage=="" and not game.send_off.blocks_restart()

func ball_in_play(kind: String,taker: int) -> void:
	decision=""
	assistant_index=-1
	indirect_pending=kind=="ENDİREKT VURUŞ"
	indirect_kicker=taker if indirect_pending else -1
	for actor in actors: actor.signal_pose("")

func touch(index: int) -> void:
	if indirect_kicker>=0 and index!=indirect_kicker:
		indirect_pending=false
		indirect_kicker=-1

func goal() -> void:
	decision="GOL"
	decision_point=Vector3.ZERO
	decision_age=0
	assistant_index=-1
	indirect_pending=false
	actors[0].signal_pose("goal")

func finish_match() -> void:
	decision="BİTİŞ"
	decision_age=0
	whistle()

func move_actor(actor,destination: Vector3,look: Vector3,delta: float) -> void:
	var offset: Vector3=(destination-actor.position)*Vector3(1,0,1)
	actor.desired=offset.normalized()*minf(1.0,offset.length()*0.8)
	# Officials yield visually as well as being excluded from ball collisions.
	if not actor.assistant:
		for player in game.players:
			if not player.visible: continue
			var gap: Vector3=(actor.position-player.position)*Vector3(1,0,1)
			if gap.length()>0.01 and gap.length()<2.0: actor.desired+=gap.normalized()*(2-gap.length())*0.6
	actor.step(delta)
	if actor.assistant:
		var obstacles: Array[Vector3]=[]
		for person in game.stadium.sidelines.actors:
			if person.role=="ball_boy": obstacles.append(person.position*Vector3(1,0,1))
		actor.position=preload("res://scripts/sideline_spacing.gd").separate(actor.position,obstacles)
	actor.reset_stamina()
	look.y=0
	if look.length()>0.1:
		actor.facing=look.normalized()
		actor.rig.rotation.y=lerp_angle(actor.rig.rotation.y,atan2(-actor.facing.x,-actor.facing.z),1-exp(-delta*14))

func update(delta: float) -> void:
	if game.training or game.state in ["menu","ceremony","paused"]: return
	clock+=delta
	decision_age+=delta
	signal_time=maxf(0,signal_time-delta)
	var ball: Vector3=game.ball.position
	var forward: float = game.attack_sign(game.last_touch)
	var follow := Vector3(clampf(ball.x*0.4-7,-24,24),0,clampf(ball.z-forward*9,-42,42))
	if game.state in ["restart","set_piece"]:
		follow=game.restart_point+Vector3(-6 if game.restart_point.x>0 else 6,0,-forward*5)
		follow.x=clampf(follow.x,-27,27)
		follow.z=clampf(follow.z,-45,45)
	if decision=="GOL": follow=Vector3(-8,0,0)
	if game.state=="finished": follow=actors[0].position
	if game.state=="halftime": follow=Vector3(29,0,0)
	var look: Vector3=ball-actors[0].position
	var pose := "indirect" if indirect_pending else ""
	if decision=="AVANTAJ" and decision_age<3: pose="advantage"
	elif signal_time>0: pose="whistle"
	elif decision=="GOL": pose="goal"; look=Vector3.ZERO-actors[0].position
	elif decision in ["BİTİŞ","DEVRE"] and decision_age<2.5: pose="full_time"
	elif game.state in ["restart","set_piece"] and not indirect_pending:
		pose="penalty" if decision=="PENALTI" else "point"
		look=game.restart_point-actors[0].position if decision=="PENALTI" else Vector3(0,0,game.attack_sign(decision_team))
	if card_stage!="":
		follow=card_point+Vector3(2.2,0,1.2)
		look=card_point-actors[0].position
		if card_stage=="approach":
			pose="whistle" if signal_time>0 else ""
			card_age+=delta
			# A gathering player can occupy the ideal spot. A referee already
			# within speaking distance can show the card without squeezing through.
			var nearby: bool=card_age>1.0 and game.flat_distance(actors[0].position,card_point)<4.0
			if game.flat_distance(actors[0].position,follow)<0.6 or nearby:
				card_stage="show"
				card_age=0
		else:
			card_age+=delta
			pose=card_queue[0]
			if card_age>1.65:
				card_queue.pop_front()
				card_age=0
				if card_queue.is_empty(): card_stage=""
	if card_stage=="" and game.send_off.calming():
		var incident: Dictionary=game.send_off.confrontation()
		pose="separate"
		follow=incident.center+Vector3(2.2,0,1.2)
		look=incident.center-actors[0].position
	actors[0].signal_pose(pose)
	targets[0]=follow
	move_actor(actors[0],follow,look,delta)
	for i in [1,2]:
		var attack_team := (0 if i==1 else 1) if game.half==1 else (1 if i==1 else 0)
		var end := -1.0 if i==1 else 1.0
		var line: float=game.rules.offside_line(attack_team)
		targets[i]=Vector3(-33.2 if i==1 else 33.2,0,end*clampf(line,0,50))
		var flag_pose := ""
		var flag_look := Vector3(1 if i==1 else -1,0,0)
		if i==assistant_index and game.state in ["restart","set_piece"]:
			targets[i].z=clampf(decision_point.z,-50,0) if i==1 else clampf(decision_point.z,0,50)
			if decision=="OFSAYT":
				targets[i].z=assistant_stop_z
				flag_pose="flag_up" if decision_age<1.0 else "offside_zone"
			elif decision=="TAÇ":
				flag_pose="flag_direction"
				flag_look=Vector3(0,0,game.attack_sign(decision_team))
			elif decision=="KORNER": flag_pose="flag_corner"
			elif decision=="KALE VURUŞU": flag_pose="flag_goal_kick"
		actors[i].signal_pose(flag_pose)
		var sideline=game.stadium.sidelines
		if sideline.fetch_boy!=null and sideline.fetch_phase in ["run","pickup"]:
			var point: Vector3=game.ball.position
			if absf(point.z-targets[i].z)<2.2 and absf(point.x-targets[i].x)<1.0 and sideline.fetch_boy.position.distance_to(point)<4.5:
				# Step out briefly for a pickup while retaining the correct offside z-line.
				targets[i].x=(-1 if i==1 else 1)*35.0
		move_actor(actors[i],targets[i],flag_look,delta)
