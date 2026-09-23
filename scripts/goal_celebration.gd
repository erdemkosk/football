extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## A continuous goal-to-kickoff sequence. All movement uses player physics.
var game
var age := 0.0
var scorer := -1
var gathering := Vector3.ZERO
var targets: Dictionary = {}
var group: Array[int] = []
var next_jump: Dictionary = {}
var gathered_age := 0.0
var urgent := false
var late_winner := false
var collection := "approach"
var collection_age := 0.0
const STYLES := ["fist","badge","crowd","heart","wings"]
var sequence := 0
var style := "fist"

func clear() -> void:
	age=0
	gathered_age=0
	urgent=false; late_winner=false; collection="approach"; collection_age=0
	scorer=-1
	targets.clear()
	group.clear()
	next_jump.clear()
	for p in game.players: p.celebration=""

func begin(team: int) -> void:
	clear()
	scorer=game.last_kicker
	if scorer<0 or not game.players[scorer].visible or game.players[scorer].team!=team:
		var nearest := INF
		for i in range(game.players.size()):
			var p=game.players[i]
			if p.visible and p.team==team and not p.keeper:
				var distance: float=game.flat_distance(p.position,game.ball.position)
				if distance<nearest: nearest=distance; scorer=i
	if scorer<0: return
	style=STYLES[posmod(game.players[scorer].shirt_number+sequence,STYLES.size())]
	sequence+=1
	urgent=game.match_time>game.LENGTH*.68 and game.score[team]<game.score[1-team]
	late_winner=game.match_time>game.LENGTH*.85 and game.score[team]==game.score[1-team]+1
	var side := -1.0 if game.players[scorer].position.x<0 else 1.0
	# The away end sits on the far sideline; celebrate toward those fans.
	if team==1: side=-1
	gathering=Vector3(side*21*P.WIDTH_RATIO,0,game.attack_sign(team)*38)
	var teammates: Array[int] = []
	for i in range(game.players.size()):
		var p=game.players[i]
		if not p.visible: continue
		p.celebration="applaud" if p.team==team else "dejected"
		p.sprinting=false
		p.kick_timer=0
		p.shot_preparation=0
		p.call_timer=0
		p.chosen=false
		targets[i]=p.position if p.team==team else p.home
		if p.team==team and not p.keeper and i!=scorer: teammates.append(i)
	teammates.sort_custom(func(a,b): return game.flat_distance(game.players[a].position,gathering)<game.flat_distance(game.players[b].position,gathering))
	group.append(scorer)
	targets[scorer]=gathering
	for j in range(teammates.size()):
		var index: int=teammates[j]
		group.append(index)
		var inner := j<5
		var angle := TAU*(j if inner else j-5)/(5.0 if inner else maxf(1,teammates.size()-5))+ (0.0 if inner else 0.4)
		targets[index]=gathering+Vector3(cos(angle),0,sin(angle))*(1.65 if inner else 3.05)
	for i in group: next_jump[i]=2.0+(i%5)*0.23
	if urgent:
		for i in targets:
			targets[i]=game.players[i].home
			game.players[i].celebration=""
		game.stadium.sidelines.instruct(team,"attack")
		game.hint("TOPU AL · SANTRAYA DÖN")
	game.match_camera.cinematic()

func update(delta: float) -> void:
	age+=delta
	if urgent:
		update_urgent(delta)
		return
	var arrived := 0
	for i in targets:
		var p=game.players[i]
		if not p.visible: continue
		var destination: Vector3=game.set_pieces.recovery.around_goal(p.position,targets[i])
		var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
		p.desired=offset.normalized()*minf(0.95,offset.length()*1.2)
		if i in group:
			var close: bool=game.flat_distance(p.position,targets[i])<0.8
			if i==scorer: p.celebration=style if close or age>2.5 else "wings"
			elif close:
				p.celebration=["embrace","applaud","fist","crowd"][posmod(group.find(i),4)]
			else: p.celebration="cheer" if i%3==0 else "applaud"
			if close:
				arrived+=1
				if next_jump[i]>=0 and age>float(next_jump[i]) and p.is_on_floor() and p.action_timer<=0 and ((i==scorer and style=="fist") or (late_winner and group.find(i)<3)):
					p.velocity.y=(4.8 if i==scorer else 3.8)+(0.35 if late_winner else 0.0)
					next_jump[i]=-1.0
		# Distinct gathering slots and lateral yielding keep the group moving.
		if offset.length()>0.6:
			for j in targets:
				if i==j: continue
				var gap: Vector3=(p.position-game.players[j].position)*Vector3(1,0,1)
				if gap.length()>0.01 and gap.length()<1.2:
					var tangent := Vector3(-offset.z,0,offset.x).normalized()
					if tangent.dot(gap)<0: tangent=-tangent
					p.desired+=tangent*(1.2-gap.length())
		p.step(delta)
		if offset.length()<1.0:
			var look: Vector3=(Vector3(signf(gathering.x)*(42+P.SIDE_SHIFT),0,gathering.z)-p.position) if i==scorer else gathering-p.position
			look.y=0
			if look.length()>0.1:
				p.facing=look.normalized()
				p.rig.rotation.y=lerp_angle(p.rig.rotation.y,atan2(-p.facing.x,-p.facing.z),1-exp(-delta*10))
	if arrived>=maxi(4,group.size()-2): gathered_age+=delta
	if (age>(15 if late_winner else 12) and gathered_age>(4.0 if late_winner else 3.0)) or age>(23 if late_winner else 19):
		clear()
		game.begin_restart("SANTRA",1-game.goal_team,Vector3.ZERO)

func skip() -> void:
	if game.state!="goal": return
	clear()
	if game.training:
		game.reset_practice()
		return
	game.begin_restart("SANTRA",1-game.goal_team,Vector3.ZERO)
	game.set_pieces.snap_ready()

func update_camera(delta: float) -> void:
	var player_focus: Vector3=game.players[scorer].position if scorer>=0 else gathering
	if urgent:
		game.match_camera.apply_projection()
		var shot: Dictionary=game.match_camera.apply(player_focus,game.zoom,delta)
		game.camera.position=shot.eye; game.camera.look_at(shot.look)
		return
	var focus := player_focus.lerp(Vector3(signf(gathering.x)*(38+P.SIDE_SHIFT),0,gathering.z),0.24)
	focus.y=0
	game.camera_focus=game.camera_focus.lerp(focus,1-exp(-delta*2.2))
	var close := smoothstep(1.5,4.0,age)
	game.camera.size=lerpf(game.camera.size,lerpf(38,29,close),1-exp(-delta*1.8))
	var offset := Vector3(0,52,38).lerp(Vector3(-signf(gathering.x)*20,24,-signf(gathering.z)*24),close)
	game.camera.position=game.camera.position.lerp(game.camera_focus+offset,1-exp(-delta*2.8))
	game.camera.look_at(game.camera_focus)

func update_urgent(delta: float) -> void:
	collection_age+=delta
	var p=game.players[scorer]
	var ball=game.ball
	var destination: Vector3=ball.position*Vector3(1,0,1)
	if collection=="approach":
		p.set_piece_pose=""
		if ball.position.y>.9 or ball.linear_velocity.length()>5: destination=p.position
		elif game.flat_distance(p.position,ball.position)<1.2:
			collection="pickup"; collection_age=0
			p.facing=((ball.position-p.position)*Vector3(1,0,1)).normalized()
	elif collection=="pickup":
		p.set_piece_pose="pickup"; p.handling_blend=smoothstep(0,.4,collection_age)
		destination=p.position
		if game.flat_distance(p.position,ball.position)>1.3:
			collection="approach"
		elif collection_age>.42 and (p.hand_center().distance_to(ball.position)<.9 or game.flat_distance(p.position,ball.position)<1.05):
			ball.hold(p); collection="lift"; collection_age=0
	elif collection=="lift":
		p.set_piece_pose="pickup"; p.handling_blend=1-smoothstep(0,.5,collection_age)
		destination=p.position
		if collection_age>.58: collection="carry"; collection_age=0
	elif collection=="carry":
		p.set_piece_pose="carry"; p.handling_blend=0
		destination=Vector3.ZERO
		if game.flat_distance(p.position,Vector3.ZERO)<.5:
			collection="place"; collection_age=0
	elif collection=="place":
		destination=p.position
		p.set_piece_pose="pickup"; p.handling_blend=smoothstep(0,.45,collection_age)
		ball.hold_target=Vector3(0,ball.GROUND_HEIGHT,0)
		if collection_age>.6:
			ball.place(Vector3(0,ball.GROUND_HEIGHT,0))
			clear(); game.begin_restart("SANTRA",1-game.goal_team,Vector3.ZERO)
			return
	if ball.held_by==p and collection!="place": ball.hold_target=p.hand_center()
	destination=game.set_pieces.recovery.around_goal(p.position,destination)
	# Reach a ball inside the net from inside its mouth.
	if collection=="approach" and absf(ball.position.x)<3.66 and absf(ball.position.z)>50 and absf(ball.position.z)<52.5 and absf(p.position.x)<3.1:
		destination=Vector3(clampf(ball.position.x,-3.1,3.1),0,signf(ball.position.z)*minf(absf(ball.position.z),51.9))
	for i in targets:
		var q=game.players[i]
		if not q.visible: continue
		var to: Vector3=destination if i==scorer else game.set_pieces.recovery.around_goal(q.position,targets[i])
		var offset: Vector3=(to-q.position)*Vector3(1,0,1)
		# Brake before reaching the ball so the runner does not kick it away
		# with their capsule while bending down to pick it up.
		var approach_rate := .35 if i==scorer and collection in ["approach","carry"] else 1.6
		q.desired=offset.normalized()*minf(1,offset.length()*approach_rate)
		q.stamina_free_movement=true
		var pace := 9.5 if i==scorer and collection in ["approach","carry"] else 0.0
		if i==scorer and collection=="carry": pace=minf(pace,sqrt(12*maxf(0,offset.length()-.1)))
		q.step(delta,pace)
		q.stamina_free_movement=false
	if age>23:
		clear(); game.begin_restart("SANTRA",1-game.goal_team,Vector3.ZERO)
