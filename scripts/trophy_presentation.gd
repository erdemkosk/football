extends RefCounted
const G=preload("res://scripts/geometry.gd")
const Arm=preload("res://scripts/arm_pose.gd")
const LIFT_START:=3.2
const LIFT_END:=5.4
const DURATION:=23.0
const TROPHY_SCALE:=.72
const HANDLE_HEIGHT:=.13
const HANDLE_WIDTH:=.32
var game
var captain
var winners: Array=[]
var original: Dictionary={}
var officials: Dictionary={}
var ball_visible:=true
var burst:=false
var pedestal: Node3D
var receiver
var guests: Array=[]
var coach

func timeline(f) -> float:
	return f.age*(2.0 if f.game.experience.short_presentation else 1.0)

func clear() -> void:
	for guest in guests:
		if is_instance_valid(guest): guest.queue_free()
	guests.clear(); coach=null; receiver=null
	for p in original:
		if not is_instance_valid(p): continue
		var saved: Dictionary=original[p]
		p.transform=saved.transform; p.collision_mask=saved.mask; p.collision_layer=saved.layer
		p.stamina_free_movement=saved.free; p.celebration=""; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
		p.animate(0)
	for actor in officials:
		if is_instance_valid(actor): actor.visible=officials[actor]
	if not original.is_empty() and is_instance_valid(game): game.ball.visible=ball_visible
	original.clear(); officials.clear(); winners.clear(); captain=null; pedestal=null; burst=false

func begin(f) -> void:
	game=f.game
	for p in game.players:
		if p.team==f.champion and p.visible and not p.dismissed: winners.append(p)
	if winners.is_empty(): return
	captain=winners[0]
	for p in winners:
		if p.captain: captain=p; break
	# Build presentation-only bench actors from real identities. Live match
	# slots, substitute eligibility and career appearance counts stay untouched.
	var ids: Array=winners.map(func(p): return p.career_id if p.career_id!="" else str(p.shirt_number))
	var invited: Array=game.management.bench[f.champion].duplicate(true)
	for item in game.stadium.sidelines.departures:
		if item.player.team==f.champion: invited.append(item.player.identity())
	for data in invited:
		var id: String=data.get("career_id",str(data.shirt))
		if id in ids: continue
		ids.append(id)
		var guest=game.Player.new(); guest.team=f.champion; guest.number=int(data.shirt); guest.keeper=bool(data.keeper)
		game.add_child(guest); guest.apply_identity(data); guest.apply_kit(game.clubs.kit(f.champion))
		guest.collision_layer=0; guest.collision_mask=0; guest.stamina_free_movement=true; guest.prematch=true
		guest.marker.hide(); guest.call_label.hide(); guest.body_language.enabled=false
		guests.append(guest); winners.append(guest)
	receiver=winners[0]
	for p in winners:
		if p!=captain and not p.keeper: receiver=p; break
	f.shooter=captain
	f.phase="presentation"
	ball_visible=game.ball.visible; game.ball.hide(); game.ball.active=false
	game.charging=false; game.cancel_pass(); game.controller.held.clear()
	game.dribbler=-1; game.carrier=-1
	for actor in game.referees.actors: officials[actor]=actor.visible; actor.hide()
	for p in game.players:
		original[p]={"transform":p.transform,"mask":p.collision_mask,"layer":p.collision_layer,"free":p.stamina_free_movement}
		p.flush_running_pose(); p.dribble_motion.release_collision()
		p.collision_mask=0; p.collision_layer=0; p.stamina_free_movement=true
		p.action_timer=0; p.kick_timer=0; p.receive_timer=0; p.shot_preparation=0
		p.pose="run"; p.feint_time=0; p.protecting=false; p.jockeying=false
		p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO; p.sprinting=false; p.chosen=false
		p.set_piece_pose=""; p.skill_move.clear(); p.celebration="applaud" if p in winners else "dejected"
		p.rig.position=Vector3.ZERO; p.rig.rotation=Vector3.ZERO; p.facing=Vector3.FORWARD
		if p not in winners: p.position=Vector3(13+p.number*.65,0,8)
	var count:=0
	for p in winners:
		if p==captain: p.position=Vector3(0,.16,-1.7)
		elif p==receiver: p.position=Vector3(1.05,.16,-1.7)
		else:
			var row:=floori(count/6.0)
			p.position=Vector3((floori((count%6)/2.0)-1)*2.3+(count%2-.5)*.8+(0.65 if row==1 else 0.0),.16,.1+row*1.45); count+=1
		p.celebration="applaud"; p.rig.rotation=Vector3.ZERO; p.facing=Vector3.FORWARD
		p.animate(0)
	coach=preload("res://scripts/sideline_actor.gd").new(); coach.role="coach"; coach.team=f.champion
	game.add_child(coach); guests.append(coach); coach.position=Vector3(-4,.16,1.2); coach.home=coach.position; coach.target_point=coach.position
	coach.seated=0; coach.rotation.y=0
	f.stage=Node3D.new(); game.add_child(f.stage)
	var dark:=G.material(Color("173c3a")); var gold:=G.material(Color("e6c570"),.22); gold.metallic=.75
	G.block(f.stage,Vector3(13,.22,8),Vector3(0,.03,1.2),dark)
	G.block(f.stage,Vector3(13,.07,.12),Vector3(0,.18,-2.8),gold)
	f.trophy=Node3D.new(); f.stage.add_child(f.trophy); f.trophy.scale=Vector3.ONE*TROPHY_SCALE
	G.cylinder(f.trophy,.21,.12,Vector3.ZERO,dark)
	G.cylinder(f.trophy,.07,.36,Vector3(0,.23,0),gold)
	G.cylinder(f.trophy,.15,.43,Vector3(0,.60,0),gold,.34)
	for side in [-1,1]:
		for n in range(16):
			var a: float=-PI*.7+n*PI*1.4/16; var b: float=-PI*.7+(n+1)*PI*1.4/16
			G.rod(f.trophy,Vector3(side*(.23+cos(a)*.23),.46+sin(a)*.37,0),Vector3(side*(.23+cos(b)*.23),.46+sin(b)*.37,0),.025,gold)
	var kit: Dictionary=game.clubs.kit(f.champion)
	for side in [-1,1]:
		G.block(f.trophy,Vector3(.06,.35,.012),Vector3(side*.43,.29,0),G.material(kit.primary))
		G.block(f.trophy,Vector3(.025,.35,.014),Vector3(side*.45,.29,-.01),G.material(kit.accent))
	pose_captain(f)
	var top: float=f.trophy.position.y-.06*TROPHY_SCALE
	pedestal=Node3D.new(); f.stage.add_child(pedestal)
	G.cylinder(pedestal,.22,top-.16,Vector3(0,(top+.16)*.5,0),dark)
	G.cylinder(pedestal,.24,.035,Vector3(0,top-.0175,0),gold)
	pedestal.position.z=f.trophy.position.z
	var ribbon:=G.material(Color("22487c"))
	for p in winners:
		var medal:=Node3D.new(); p.spine.add_child(medal); f.medals.append(medal)
		G.rod(medal,Vector3(-.16,.52,-.17),Vector3(0,.19,-.29),.016,ribbon)
		G.rod(medal,Vector3(.16,.52,-.17),Vector3(0,.19,-.29),.016,ribbon)
		G.sphere(medal,.062,Vector3(0,.18,-.30),gold)
	f.confetti=MultiMeshInstance3D.new(); f.confetti.multimesh=MultiMesh.new()
	f.confetti.multimesh.transform_format=MultiMesh.TRANSFORM_3D; f.confetti.multimesh.use_colors=true
	var mesh:=BoxMesh.new(); mesh.size=Vector3(.055,.012,.10); mesh.material=G.material(Color.WHITE)
	mesh.material.vertex_color_use_as_albedo=true; f.confetti.multimesh.mesh=mesh
	f.confetti.multimesh.instance_count=260; f.confetti.hide(); f.stage.add_child(f.confetti)
	game.audio.react("save",f.champion,Vector3.ZERO)

func pose_captain(f) -> void:
	if not is_instance_valid(captain): return
	var t:=timeline(f)
	var receive:=smoothstep(1.6,LIFT_START,t)
	var lift:=smoothstep(LIFT_START,LIFT_END,t)
	captain.spine.rotation=Vector3.ZERO
	# Grip the low returns of the handles so the cup clears the captain's face
	# at full extension without stretching the existing arm bones.
	var grip:=Vector3(0,lerpf(.12,.30,receive)+lift*.70,lerpf(-.30,-.02,lift))
	f.trophy.global_position=captain.spine.to_global(grip)-Vector3.UP*(HANDLE_HEIGHT*TROPHY_SCALE)
	f.trophy.rotation.z=sin(t*3)*.025*lift
	var weight:=smoothstep(.55,1.6,t)
	if t>=9 and receiver!=captain:
		pose_shared_cup(f,t)
		return
	for side in [-1,1]:
		reach_handle(captain,side,side,f,weight)

func reach_handle(p,arm_side: int,handle_side: int,f,weight: float=1.0) -> void:
	var point: Vector3=p.spine.to_local(f.trophy.to_global(Vector3(handle_side*HANDLE_WIDTH,HANDLE_HEIGHT,0)))
	Arm.reach(p.left_arm if arm_side<0 else p.right_arm,p.left_elbow if arm_side<0 else p.right_elbow,point,Vector3(arm_side,-.2,-1),weight)

func pose_shared_cup(f,t: float) -> void:
	receiver.spine.rotation=Vector3.ZERO
	var lower:=smoothstep(9,10.1,t)
	var across:=smoothstep(10.1,10.9,t)*.5+smoothstep(11.7,12.5,t)*.5
	var photo:=smoothstep(17,18.2,t)
	var second_lift:=smoothstep(12.5,14.5,t)*(1-photo)
	var center: Vector3=captain.spine.to_global(Vector3(0,1,-.02)).lerp(captain.spine.to_global(Vector3(0,.42,-.28)),lower)
	center.x=lerpf(captain.spine.global_position.x,receiver.spine.global_position.x,across*(1-photo)+.5*photo)
	center.y=lerpf(center.y,receiver.spine.to_global(Vector3(0,1,-.02)).y,second_lift)
	center.z=lerpf(center.z,receiver.spine.to_global(Vector3(0,1,-.02)).z,second_lift)
	f.trophy.global_position=center-Vector3.UP*HANDLE_HEIGHT*TROPHY_SCALE
	f.trophy.rotation.z=sin(t*3)*.018*(1-photo)
	if t<10.1:
		reach_handle(captain,-1,-1,f); reach_handle(captain,1,1,f)
	elif t<11.7:
		reach_handle(captain,1,-1,f); reach_handle(receiver,-1,1,f,smoothstep(10.1,10.5,t))
	elif t<17:
		reach_handle(receiver,-1,-1,f); reach_handle(receiver,1,1,f)
	else:
		reach_handle(captain,1,-1,f,photo); reach_handle(receiver,-1,1,f)

func group_photo(t: float) -> void:
	var line: Array=winners.filter(func(p): return p!=captain and p!=receiver)
	for i in range(0,line.size()-1,2):
		for side in [0,1]:
			var p=line[i+side]; var other=line[i+1-side]
			var arm_side: int=1 if side==0 else -1
			var point: Vector3=p.spine.to_local(other.spine.to_global(Vector3(-arm_side*.17,.38,.10)))
			Arm.reach(p.right_arm if side==0 else p.left_arm,p.right_elbow if side==0 else p.left_elbow,point,Vector3(arm_side,-.3,1),smoothstep(16.5,18,t))

func update(f,delta: float) -> void:
	if not is_instance_valid(captain): return
	var t:=timeline(f)
	f.phase="presentation" if t<1.6 else ("receive" if t<LIFT_START else ("lift" if t<LIFT_END else ("celebrate" if t<9 else ("share" if t<17 else "photo"))))
	if t>=LIFT_END and not burst:
		burst=true; f.confetti.show()
		game.audio.react("goal",f.champion,captain.position); game.stadium.crowd.react("goal",f.champion,captain.position)
	for p in winners:
		p.celebration=("applaud" if t>=17 else ["cheer","fist","badge","crowd"][p.number%4]) if burst else "applaud"
		p.step(delta)
		p.position.y=.16+(absf(sin(t*4+p.number))*(.015 if p in [captain,receiver] else .12)*(1-smoothstep(15,17,t)) if burst else 0.0)
	coach.animate_actor(delta,t,Vector3(0,1,-8),"celebrate" if burst and t<17 else "encourage",1)
	coach.rotation.y=0
	pose_captain(f)
	if t>=16.5: group_photo(t)
	if burst:
		var elapsed: float=t-LIFT_END
		var kit: Dictionary=game.clubs.kit(f.champion)
		for i in range(260):
			var pos:=Vector3(sin(i*9.71)*6+sin(elapsed+i)*.5,6.5-fmod(elapsed*(1.1+i%5*.12)+i*.023,6.5),cos(i*3.13)*3)
			f.confetti.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(elapsed+i,elapsed*.7,i)),pos))
			f.confetti.multimesh.set_instance_color(i,Color("e6c570") if i%3==0 else (kit.primary if i%3==1 else kit.accent))
	if t>DURATION: f.finish_ceremony()

func camera(f) -> void:
	var t:=timeline(f)
	var close:=smoothstep(1.4,3.2,t)*(1-smoothstep(7,10,t))
	var photo:=smoothstep(15.5,18.5,t)
	game.camera.fov=lerpf(43,37,close)
	game.camera.position=Vector3(sin(t*.09)*1.1,lerpf(3.8,2.8,close),lerpf(-14,-10,close))
	game.camera.position=game.camera.position.lerp(Vector3(.3,5.4,-10.8),photo)
	game.camera.look_at(Vector3(0,lerpf(1.3,1.65,close),-.1).lerp(Vector3(0,1.0,.9),photo))
