extends Node3D
## Cosmetic event cues. Never writes ball/player positions, velocities or clocks.
const Style=preload("res://scripts/match_identity_style.gd")
const LED=preload("res://scripts/led_boards.gd")
const CAPACITY:=28
var game
var cues: Array[Dictionary]=[]
var particles: Array[GPUParticles3D]=[]
var particle_cursor:=0
var motion: Dictionary={}
var goal_age:=10.0
var clock:=0.0
var charge: MeshInstance3D
var event_counts: Dictionary={}
var post_rest: Array[Transform3D]=[]
var post_age:=1.0
var post_index:=-1
var post_strength:=0.0
var post_axis:=Vector3.ZERO

func setup(owner) -> void:
	game=owner; name="MatchVisualIdentity"; owner.add_child(self)
	for i in range(CAPACITY):
		var node:=make_card()
		cues.append({"node":node,"age":1.0,"life":0.0,"origin":Vector3.ZERO,"drift":Vector3.ZERO,"ground":false})
	charge=make_card(); charge.name="PowerWindup"
	charge.material_override.set_shader_parameter("kind",3)
	charge.material_override.set_shader_parameter("tint",Style.POWER)
	for i in range(6):
		var emitter:=GPUParticles3D.new(); emitter.name="ContactFragments"
		emitter.emitting=false; emitter.one_shot=true; emitter.explosiveness=1
		emitter.amount=10; emitter.lifetime=.42; emitter.local_coords=false; emitter.fixed_fps=30
		emitter.visibility_aabb=AABB(Vector3(-3,-2,-3),Vector3(6,5,6))
		emitter.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var process:=ParticleProcessMaterial.new()
		process.gravity=Vector3(0,-8,0); process.spread=48
		process.initial_velocity_min=.7; process.initial_velocity_max=2.2
		process.scale_min=.6; process.scale_max=1.35
		var gradient:=Gradient.new(); gradient.set_color(0,Color.WHITE); gradient.set_color(1,Color(1,1,1,0))
		var ramp:=GradientTexture1D.new(); ramp.gradient=gradient; process.color_ramp=ramp
		emitter.process_material=process
		var shape:=BoxMesh.new(); shape.size=Vector3(.022,.065,.012)
		var mat:=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		shape.material=mat; emitter.draw_pass_1=shape
		add_child(emitter); particles.append(emitter)
	game.stadium.atmosphere_event.connect(on_stadium_event)
	for post in game.stadium.goal_posts: post_rest.append(post.transform)
	reset()

func make_card() -> MeshInstance3D:
	var node:=MeshInstance3D.new(); var quad:=QuadMesh.new(); quad.size=Vector2.ONE*2
	node.mesh=quad; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=ShaderMaterial.new(); mat.shader=preload("res://shaders/match_cue.gdshader")
	node.material_override=mat; add_child(node); node.hide()
	return node

func reset() -> void:
	for cue in cues: cue.age=1.0; cue.life=0.0; cue.node.hide()
	for emitter in particles: emitter.emitting=false; emitter.hide()
	if charge!=null: charge.hide()
	motion.clear(); event_counts.clear(); goal_age=10; clock=0
	for i in range(post_rest.size()): game.stadium.goal_posts[i].transform=post_rest[i]
	post_age=1; post_index=-1
	LED.goal_state(0,Style.FINESSE,Style.PAPER,0)

func allowed() -> bool:
	return game.state in ["playing","goal","restart","set_piece"] and not game.menu_match.running

func spawn(at: Vector3,tint: Color,radius: float,life: float,kind: int=0,ground: bool=false,drift: Vector3=Vector3.ZERO) -> MeshInstance3D:
	if not allowed(): return null
	var chosen: Dictionary=cues[0]
	for cue in cues:
		if cue.age>=cue.life: chosen=cue; break
		if cue.age/maxf(.01,cue.life)>chosen.age/maxf(.01,chosen.life): chosen=cue
	chosen.age=0.0; chosen.life=life; chosen.origin=at; chosen.drift=drift; chosen.ground=ground
	var node: MeshInstance3D=chosen.node
	node.position=at; node.scale=Vector3.ONE*radius; node.rotation=Vector3(-PI/2,0,0) if ground else Vector3.ZERO
	node.material_override.set_shader_parameter("kind",kind)
	node.material_override.set_shader_parameter("tint",tint)
	node.material_override.set_shader_parameter("progress",0.0)
	node.material_override.set_shader_parameter("reduced_motion",game.experience.reduce_motion)
	node.show()
	return node

func fragments(at: Vector3,direction: Vector3,water: bool) -> void:
	if not allowed() or game.experience.reduce_motion: return
	var emitter:=particles[particle_cursor]; particle_cursor=(particle_cursor+1)%particles.size()
	var mat: ParticleProcessMaterial=emitter.process_material
	mat.direction=(direction+Vector3.UP*2).normalized()
	mat.color=Color("bfedf2",.75) if water else Color("81a74b")
	emitter.position=at+Vector3.UP*.025; emitter.show(); emitter.restart(); emitter.emitting=true

func contact(kind: String,point: Vector3,direction: Vector3,heavy: bool=false) -> void:
	if not allowed(): return
	if kind=="glove":
		spawn(point,Style.PAPER,.42,.22,1)
		spawn(point,Color(Style.PAPER,.60),.48,.30)
		if game.weather.wetness>.2: fragments(point,direction,true)
	elif kind=="shot" and heavy:
		spawn(point,Style.POWER,.72,.20,1)
		contact_ring(point,Color(Style.POWER,.65),.78,.27)
	else: return
	event_counts[kind]=int(event_counts.get(kind,0))+1

func perfect(point: Vector3) -> void:
	if not allowed(): return
	contact_ring(point,Style.PERFECT,.90,.44)
	event_counts.perfect=int(event_counts.get("perfect",0))+1

func skill_contact(index: int,state: Dictionary) -> void:
	if not allowed() or game.experience.reduce_motion or state.get("fx_done",false): return
	state.fx_done=true
	var p=game.players[index]
	var kind: String=state.kind
	var form:=4
	if kind in ["elastico","ball_roll_cut"]: form=5
	elif kind in ["nutmeg","knock_around","stop_go","heel_to_heel"]: form=6
	elif kind in ["rainbow","flick","heel","scoop"]: form=7
	var knee=p.left_knee if state.side<0 else p.right_knee
	var foot: Vector3=knee.to_global(p.ball_actions.BOOT)
	var ground:=form!=7
	var at:=Vector3(foot.x,.05,foot.z) if ground else foot+Vector3.UP*.22
	var tint:=Style.FINESSE.lerp(Style.PAPER,.25 if form==4 else .05)
	var arc:=spawn(at,tint,.82,.38,form,ground)
	if arc!=null and ground: arc.rotate_y(atan2(-p.facing.x,-p.facing.z))
	event_counts.skill=int(event_counts.get("skill",0))+1

func woodwork(point: Vector3,direction: Vector3,strength: float) -> void:
	if not allowed(): return
	spawn(point,Color(Style.PAPER,.75),.38,.18,1)
	if game.experience.reduce_motion: return
	if post_index>=0: game.stadium.goal_posts[post_index].transform=post_rest[post_index]
	var nearest:=INF
	for i in range(game.stadium.goal_posts.size()):
		var node: MeshInstance3D=game.stadium.goal_posts[i]
		var gap: float=node.position.distance_to(point)
		# Compare to the whole bar/post segment, not only its centre.
		var half: float=(node.mesh as CylinderMesh).height*.5
		var axis: Vector3=node.basis.y.normalized()*half
		gap=Geometry3D.get_closest_point_to_segment(point,node.position-axis,node.position+axis).distance_to(point)
		if gap<nearest: nearest=gap; post_index=i
	post_age=0; post_strength=clampf(strength,0,1); post_axis=direction.normalized()
	event_counts.woodwork=int(event_counts.get("woodwork",0))+1

func contact_ring(point: Vector3,tint: Color,radius: float,life: float) -> void:
	# Low contacts expand across the turf instead of clipping a vertical halo into it.
	var ground: bool=point.y<.6
	var at:=Vector3(point.x,.045,point.z) if ground else point
	spawn(at,tint,radius,life,0,ground)

func on_stadium_event(kind: String,team: int,_at: Vector3) -> void:
	if kind!="goal" or game.menu_match.running: return
	goal_age=0
	var club: Dictionary=game.clubs.data(team)
	LED.goal_state(1,Color(club.primary),Color(club.accent),0)

func acceleration(index: int,delta: float) -> void:
	var p=game.players[index]
	var velocity: Vector3=p.velocity*Vector3(1,0,1)
	var before: Dictionary=motion.get(index,{"velocity":velocity,"cooldown":0.0,"skill":false})
	var speed:=velocity.length(); var previous: Vector3=before.velocity
	var skill: bool=game.skills.active.has(index)
	var cooldown:=maxf(0,before.cooldown-delta)
	var turn: bool=previous.length()>4 and speed>4 and previous.normalized().dot(velocity.normalized())<.80
	var surge: bool=speed>4.5 and (speed-previous.length())/maxf(.001,delta)>9
	if cooldown<=0 and (surge or turn or skill and not before.skill) and not game.experience.reduce_motion:
		var direction: Vector3=velocity.normalized() if speed>.1 else p.facing
		for knee in [p.left_knee,p.right_knee]:
			var at: Vector3=knee.to_global(p.ball_actions.BOOT); at.y=maxf(.045,at.y-.02)
			var streak:=spawn(at-direction*.45,Color(Style.FINESSE,.55),.70,.28,2,true,-direction*.6)
			# Streaks lie along the turf and the actual travel direction.
			if streak!=null: streak.basis=Basis(direction,Vector3(-direction.z,0,direction.x),Vector3.DOWN)*Basis.from_scale(Vector3(.70,.045,1))
		fragments(Vector3(p.position.x,.06,p.position.z),-direction,game.weather.wetness>.2)
		cooldown=.65; event_counts.acceleration=int(event_counts.get("acceleration",0))+1
	motion[index]={"velocity":velocity,"cooldown":cooldown,"skill":skill}

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.match_menu): return
	var paused: bool=game.state=="paused"
	for emitter in particles: emitter.speed_scale=0 if paused else 1
	game.ball.power_trail.reduced_motion=game.experience.reduce_motion
	if paused: return
	if not allowed():
		if visible: reset(); hide()
		return
	show(); clock+=delta; goal_age+=delta
	if post_index>=0:
		post_age+=delta
		var post: MeshInstance3D=game.stadium.goal_posts[post_index]
		post.transform=post_rest[post_index]
		if post_age<.45:
			post.position+=post_axis*sin(post_age*88)*pow(1-post_age/.45,2)*.014*post_strength
		else: post_index=-1
	for cue in cues:
		if cue.age>=cue.life: continue
		cue.age+=delta
		var node: MeshInstance3D=cue.node
		if cue.age>=cue.life: node.hide(); continue
		node.position=cue.origin+cue.drift*cue.age
		if not cue.ground:
			var radius: float=node.scale.x
			node.basis=game.camera.global_basis*Basis.from_scale(Vector3.ONE*radius)
		node.material_override.set_shader_parameter("progress",cue.age/cue.life)
	var windup: float=game.power_windup()
	charge.visible=windup>.02
	if charge.visible:
		var index: int=game.finishing.pending.index if not game.finishing.pending.is_empty() else game.controlled
		var p=game.players[index]
		var knee=p.left_knee if p.ball_actions.foot==0 else p.right_knee
		charge.position=knee.to_global(p.ball_actions.BOOT); charge.position.y=.045
		charge.rotation=Vector3(-PI/2,0,0); charge.scale=Vector3.ONE*.62
		charge.material_override.set_shader_parameter("progress",windup)
	if goal_age<5:
		var club: Dictionary=game.clubs.data(game.goal_team)
		LED.goal_state(1-smoothstep(3.8,5,goal_age),Color(club.primary),Color(club.accent),0 if game.experience.reduce_motion else goal_age)
	else: LED.goal_state(0,Style.FINESSE,Style.PAPER,0)
	if game.state=="playing":
		for i in range(game.players.size()):
			if game.players[i].visible and game.players[i].position.distance_squared_to(game.players[game.controlled].position)<225: acceleration(i,delta)
