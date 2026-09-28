extends SceneTree
var game
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func context() -> void:
	var h=game.hud
	game.state="menu"; h.update_context(0)
	game.state="playing"; h.update_context(0)
	check(h.environment_time>0 and h.direction_time>0,"Match entry briefly exposes camera/weather and attack direction")
	h.update_context(6)
	check(h.environment_time==0 and h.direction_time==0,"Unchanged secondary information disappears during play")
	game.match_camera.select("end"); h.update_context(.01)
	check(h.environment_time>0 and h.direction_time==0,"A camera change reopens its information without repeating attack direction")
	var time: float=h.environment_time
	game.state="paused"; h.update_context(10)
	check(h.environment_time==time,"Pausing preserves time to read a changed setting")
	game.state="playing"; h.update_context(6)
	game.weather.select(2,true); h.update_context(.01)
	check(h.environment_time>0,"A changed weather preset becomes visible again")
	h.update_context(6); game.half=2; h.update_context(.01)
	check(h.direction_time>0 and h.environment_time==0 and game.attack_sign(0)>0,"The second half announces the reversed attack direction")
	var p=game.players[game.controlled]
	p.energy=1; p.exhausted=false; game.training=false; game.coaching.opened=false
	check(not h.detailed_energy(),"A healthy player's identity and energy bar use the compact card")
	p.energy=.3
	check(h.detailed_energy(),"Low energy retains an explicit readable warning and percentage")
	p.energy=1; game.coaching.opened=true
	check(h.detailed_energy(),"Opening live tactics exposes the energy detail on demand")
	game.coaching.opened=false; game.state="menu"; h.update_context(0)
	check(h.environment_time==0 and h.direction_time==0 and h.context_half==0,"Leaving a match resets contextual information for the next session")

func paint() -> void:
	var count:=0; var valid:=true
	for mesh: MeshInstance3D in game.stadium.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or mesh.get_active_material(0)!=game.stadium.chalk: continue
		var arrays:=mesh.mesh.surface_get_arrays(0)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		valid=valid and mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in range(points.size()):
			valid=valid and absf((mesh.global_transform*points[i]).y-.002)<.0001 and normals[i].is_finite() and normals[i].y>.99
		count+=points.size()
	check(count>500 and valid,"Every line and spot is a finite, flat upward surface without a raised edge or shadow")

func gaze() -> void:
	var p=game.players[9]
	p.body_language.reset(p); p.body_language.enabled=true; p.body_language.urgent=true
	p.celebration=""; p.action_timer=0; p.kick_timer=0; p.receive_timer=0; p.set_piece_pose=""; p.prematch=false
	p.rig.rotation=Vector3.ZERO; p.spine.rotation=Vector3(-.2,0,.08)
	p.body_language.ball_target=p.position+Vector3(0,.23,-.75)
	for i in range(120): p.body_language.apply_gaze(p,1.0/120)
	check(p.head_joint.rotation.x>=-.271 and p.head_joint.rotation.x<0,"A nearby dribble does not pin the neck at the deep downward stop")
	check(p.head_joint.rotation.z<0 and absf(p.head_joint.rotation.z)<.1,"The head gently counterbalances body roll instead of tilting rigidly with the chest")
	p.rig.rotation=Vector3.ZERO; p.spine.rotation=Vector3.ZERO
	p.head_joint.rotation=Vector3.ZERO
	p.body_language.ball_target=p.position+Vector3(-5,2,-10)
	var speeds: Array[float]=[]
	for i in range(60):
		var previous: float=p.head_joint.rotation.y
		p.body_language.apply_gaze(p,1.0/120)
		speeds.append(absf(p.head_joint.rotation.y-previous)*120)
	check(speeds.max()<=5.401 and speeds[45]<speeds[5]*.1,"A head turn eases into its target with a bounded angular speed")
	p.body_language.enabled=false
	for i in range(120): p.body_language.apply_gaze(p,1.0/120)
	check(p.head_joint.rotation.length()<.001,"A finished gaze restores the neutral neck, including any old side tilt")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-presentation-polish.cfg"
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.controller.set_process(false); game.hud.set_process(false); game.ball.freeze=true
	context(); paint(); gaze()
	print("PRESENTATION POLISH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
