extends RefCounted
## A continuous goal-to-kickoff sequence. All movement uses player physics.
var game
var age := 0.0
var scorer := -1
var gathering := Vector3.ZERO
var targets: Dictionary = {}
var group: Array[int] = []
var next_jump: Dictionary = {}

func clear() -> void:
	age=0
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
	var side := -1.0 if game.players[scorer].position.x<0 else 1.0
	# The away end is in the south-east corner; celebrate toward those fans.
	if team==1: side=1
	gathering=Vector3(side*24,0,-41 if team==0 else 41)
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
	for j in range(mini(5,teammates.size())):
		var index: int=teammates[j]
		group.append(index)
		var angle := TAU*j/5.0
		targets[index]=gathering+Vector3(cos(angle),0,sin(angle))*1.7
	for i in group: next_jump[i]=2.0+(i%5)*0.23

func update(delta: float) -> void:
	age+=delta
	var arrived := 0
	for i in targets:
		var p=game.players[i]
		if not p.visible: continue
		var destination: Vector3=game.set_pieces.recovery.around_goal(p.position,targets[i])
		var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
		p.desired=offset.normalized()*minf(0.95,offset.length()*1.2)
		if i in group:
			var close: bool=game.flat_distance(p.position,targets[i])<0.8
			p.celebration="embrace" if close and i!=scorer else "cheer"
			if close:
				arrived+=1
				if age>float(next_jump[i]) and p.is_on_floor() and p.action_timer<=0:
					p.velocity.y=4.8 if i==scorer else 3.8
					next_jump[i]=age+1.2+(i%3)*0.15
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
			var look: Vector3=(Vector3(signf(gathering.x)*42,0,gathering.z)-p.position) if i==scorer else gathering-p.position
			look.y=0
			if look.length()>0.1:
				p.facing=look.normalized()
				p.rig.rotation.y=lerp_angle(p.rig.rotation.y,atan2(-p.facing.x,-p.facing.z),1-exp(-delta*10))
	if (age>8.5 and arrived>=4) or age>12:
		clear()
		game.begin_restart("SANTRA",1-game.goal_team,Vector3.ZERO)

func update_camera(delta: float) -> void:
	var player_focus: Vector3=game.players[scorer].position if scorer>=0 else gathering
	var focus := player_focus.lerp(Vector3(signf(gathering.x)*38,0,gathering.z),0.24)
	focus.y=0
	game.camera_focus=game.camera_focus.lerp(focus,1-exp(-delta*2.2))
	var close := smoothstep(1.5,4.0,age)
	game.camera.size=lerpf(game.camera.size,lerpf(36,24,close),1-exp(-delta*1.8))
	var offset := Vector3(0,52,38).lerp(Vector3(-signf(gathering.x)*20,24,-signf(gathering.z)*24),close)
	game.camera.position=game.camera.position.lerp(game.camera_focus+offset,1-exp(-delta*2.8))
	game.camera.look_at(game.camera_focus)
