extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Walkout, presentation and a continuous run to the kickoff formation.
const ORDER := [9,0,1,2,3,4,5,6,7,8,10]
var game
var phase := ""
var age := 0.0
var elapsed := 0.0
var stages: Array[int] = []
var officials: Array = []
var lineup: Array[Vector3] = []
var kickoff: Array[Vector3] = []
var camera_at := Vector3.ZERO
var camera_eye := Vector3.ZERO
var camera_size := 25.0

func clear() -> void:
	phase=""
	for p in game.players:
		p.prematch=false
		p.saluting=false
		p.collision_layer=0 if p.dismissed else 2
		p.collision_mask=3
	for ref in officials:
		ref.visible=false
		ref.collision_layer=0
	game.ball.visible=true

func begin() -> void:
	clear()
	phase="walkout"
	age=0
	elapsed=0
	stages.assign([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
	kickoff.clear()
	lineup.resize(22)
	for p in game.players: kickoff.append(p.position)
	for team in range(2):
		var side := -1.0 if team==0 else 1.0
		for slot in range(11):
			var index: int=team*11+ORDER[slot]
			var p=game.players[index]
			p.position=Vector3(41.5+P.SIDE_SHIFT+slot*1.42,0,side*1.05)
			p.velocity=Vector3.ZERO
			p.desired=Vector3.ZERO
			p.facing=Vector3.LEFT
			p.rig.rotation.y=PI*0.5
			p.prematch=true
			p.chosen=false
			p.collision_layer=2
			p.collision_mask=3
			p.animate(1)
			lineup[index]=Vector3(25+P.SIDE_SHIFT,0,side*(3+(10-slot)*1.22))
	for i in range(3):
		var ref=officials[i]
		ref.visible=true
		ref.prematch=true
		ref.position=Vector3((38.2 if i==0 else 38.8)+P.SIDE_SHIFT,0,[0,-1.05,1.05][i])
		ref.velocity=Vector3.ZERO
		ref.facing=Vector3.LEFT
		ref.rig.rotation.y=PI*0.5
		ref.collision_layer=16
		ref.collision_mask=1
	game.state="ceremony"
	game.ball.active=false
	game.ball.visible=false
	game.toast_timer=0
	game.match_camera.cinematic()
	camera_at=Vector3(36+P.SIDE_SHIFT,1.2,0)
	camera_eye=Vector3(20+P.SIDE_SHIFT,8,14)
	camera_size=24
	game.stadium.react("entrance",0,Vector3(32+P.SIDE_SHIFT,0,0))

func move_actor(p,destination: Vector3,delta: float,speed: float) -> bool:
	var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
	p.desired=offset.normalized()*minf(speed,offset.length()*1.5)
	if phase=="formation" and offset.length()>0.8:
		for other in game.players:
			if other==p: continue
			var gap: Vector3=(p.position-other.position)*Vector3(1,0,1)
			if gap.length()>0.01 and gap.length()<1.2:
				var side := Vector3(-offset.z,0,offset.x).normalized()
				if side.dot(gap)<0: side=-side
				p.desired+=side*(1.2-gap.length())*0.85
	p.sprinting=false
	p.step(delta)
	p.reset_stamina()
	return offset.length()<0.18

func update(delta: float) -> void:
	age+=delta
	elapsed+=delta
	if game.experience.short_presentation and elapsed>2.4:
		game.pace.request(func(): finish(true))
	if phase=="walkout":
		var ready := true
		for i in range(22):
			var p=game.players[i]
			var lane := -1.05 if p.team==0 else 1.05
			var destination: Vector3=Vector3(27+P.SIDE_SHIFT,0,lane) if stages[i]==0 else lineup[i]
			if move_actor(p,destination,delta,0.86):
				if stages[i]==0: stages[i]=1
				else: p.facing=Vector3.RIGHT
			if stages[i]==0 or game.flat_distance(p.position,lineup[i])>0.18: ready=false
		for i in range(3):
			if move_actor(officials[i],Vector3(25+P.SIDE_SHIFT,0,[0,-1.05,1.05][i]),delta,0.86): officials[i].facing=Vector3.RIGHT
		if ready:
			phase="presentation"
			age=0
			game.stadium.react("entrance",0,Vector3(25+P.SIDE_SHIFT,0,0))
	elif phase=="presentation":
		for p in game.players:
			p.desired=Vector3.ZERO
			p.facing=Vector3.RIGHT
			p.saluting=age>0.3+p.number*0.03 and age<2.4
			p.step(delta)
		for ref in officials:
			ref.desired=Vector3.ZERO
			ref.facing=Vector3.RIGHT
			ref.step(delta)
		if age>=3:
			phase="formation"
			age=0
			game.ball.visible=true
			for p in game.players: p.saluting=false
	elif phase=="formation":
		var ready := true
		for i in range(22):
			if not move_actor(game.players[i],kickoff[i],delta,1.0): ready=false
		for i in range(3): move_actor(officials[i],game.referees.kickoff_target(i),delta,1.0)
		if ready: finish(false)

func finish(skipped: bool) -> void:
	if phase=="": return
	game.audio.release_walkout()
	clear()
	if skipped: game.reset_positions(0)
	for p in game.players:
		p.velocity=Vector3.ZERO
		p.desired=Vector3.ZERO
		p.reset_stamina()
		p.facing=Vector3.FORWARD if p.team==0 else Vector3.BACK
	game.state="restart"
	game.referees.activate(skipped)
	game.ball.active=true
	game.ball.freeze=false
	game.previous_ball=game.ball.position
	game.boundary_grace=0.5
	game.kick_lock=0.3
	game.camera_focus=Vector3.ZERO
	# The ceremony ends at a protected kickoff, not a live ball that can be
	# dribbled away immediately. The ball is already on the centre spot, so
	# nobody needs to collect it as they would after a goal or a throw-in.
	game.restart_type="SANTRA"
	game.restart_team=0
	game.restart_point=Vector3.ZERO
	game.set_pieces.prepare()
	game.set_pieces.recovery.worker=game.set_pieces.taker
	game.set_pieces.recovery.enter("arrange")
	game.referees.restart("SANTRA",0,Vector3.ZERO)
	if skipped: game.set_pieces.snap_ready()
	game.match_camera.apply_projection()
	game.camera.size=game.match_camera.play_size(game.zoom)
	game.update_camera(0)

func update_camera(delta: float) -> void:
	var target := Vector3(32+P.SIDE_SHIFT,1,0)
	var eye := Vector3(17+P.SIDE_SHIFT,8,15)
	var size := 29.0
	if phase=="walkout":
		var t := smoothstep(1,7,age)
		target=Vector3(36+P.SIDE_SHIFT,1.2,0).lerp(Vector3(28+P.SIDE_SHIFT,1,0),t)
		eye=Vector3(20+P.SIDE_SHIFT,8,14).lerp(Vector3(38+P.SIDE_SHIFT,13,23),t)
		size=lerpf(24,43,t)
	elif phase=="presentation":
		target=Vector3(25+P.SIDE_SHIFT,1,0)
		# Stay in front of the stand and tunnel roof for an unobstructed lineup.
		eye=Vector3(32+P.SIDE_SHIFT,10,2-age*0.6)
		size=22
	elif phase=="formation":
		target=Vector3.ZERO
		eye=Vector3(0,70,37)
		size=65
	var blend := 1-exp(-delta*3.6)
	camera_at=camera_at.lerp(target,blend)
	camera_eye=camera_eye.lerp(eye,blend)
	camera_size=lerpf(camera_size,size,blend)
	game.camera.position=camera_eye
	game.camera.size=camera_size
	game.camera.look_at(camera_at)

func caption() -> String:
	return "TAKIMLAR SAHAYA ÇIKIYOR" if phase=="walkout" else ("SEFC ARENA'YA HOŞ GELDİNİZ" if phase=="presentation" else "İLK DÜDÜĞE HAZIR")
