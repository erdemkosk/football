extends RefCounted
## Visual playback never runs football logic; all live transforms are restored.
const P = preload("res://scripts/pitch_dimensions.gd")
var game
var frames: Array = []
var nodes: Array[Node3D] = []
var saved: Dictionary = {}
var age := 0.0
var sample_age := 0.0
var enabled := true
var restart_clip := false
var goal_tail := 0.0
var cut := 0
var goal_end := -1.0
var display_seconds := 0.0
var display_score: Array = [0,0]
const RATE := 20.0
const SECONDS := 5.0
const CUTS: PackedStringArray = ["sideline","end","net"]
const CUT_HOLD := 1.15
const FADE_OUT := .09
const FADE_HOLD := .02
const FADE_IN := .13
var cut_age := 0.0
var pending_cut := -1
var cut_transition := -1.0
var entry_left := 0.0
var exit_left := 0.0
var camera_ready := false
var camera_side := 1.0
var camera_eye := Vector3.ZERO
var camera_look := Vector3.ZERO
var previous_point := Vector3.ZERO
var goal_at := -1.0

func setup() -> void:
	for p in game.players:
		nodes.append(p)
		collect(p.rig)
	nodes.append(game.ball)

func collect(node: Node3D) -> void:
	nodes.append(node)
	for child in node.get_children():
		if child is Node3D and not child is MeshInstance3D and not child is Label3D: collect(child)

func snapshot() -> Dictionary:
	game.flush_running_poses()
	var transforms: Array[Transform3D] = []
	for node in nodes: transforms.append(node.transform)
	var visibility: Array[bool] = []
	for p in game.players: visibility.append(p.visible)
	var net_poses: Array=[]
	for net in game.stadium.nets: net_poses.append(net.capture_pose())
	return {"transforms":transforms,"visible":visibility,"ball":game.ball.position,"nets":net_poses,"seconds":game.match_time,"score":game.score.duplicate()}

func capture(delta: float) -> void:
	if not enabled or game.training: return
	sample_age+=delta
	if sample_age<1.0/RATE: return
	sample_age=fmod(sample_age,1.0/RATE)
	frames.append(snapshot())
	if frames.size()>int(RATE*SECONDS): frames.pop_front()

func origin() -> void:
	# A restart that can score immediately must not replay the previous open play.
	if not enabled or game.training or game.menu_match.running: return
	frames.clear()
	sample_age=0
	restart_clip=true
	frames.append(snapshot())

func queue_goal() -> void:
	# Keep the ball live until it has reached and stretched the net.
	if enabled and frames.size()>=(8 if restart_clip else 20): goal_tail=1.15

func capture_goal(delta: float) -> void:
	if goal_tail<=0: return
	capture(delta)
	goal_tail=maxf(0,goal_tail-delta)
	if goal_tail<=0: begin()

func begin() -> bool:
	goal_tail=0
	if not enabled or frames.size()<(8 if restart_clip else 20): return false
	frames.append(snapshot())
	saved=snapshot()
	saved.velocity=game.ball.linear_velocity
	saved.spin=game.ball.angular_velocity
	saved.freeze=game.ball.freeze
	saved.active=game.ball.active
	saved.net_physics=[]
	for net in game.stadium.nets:
		saved.net_physics.append(net.capture_physics())
		net.playback=true
	game.ball.freeze=true
	game.ball.active=false
	game.state="replay"
	game.audio.start_replay_chant(game.goal_team)
	age=0
	cut=0
	cut_age=0; pending_cut=-1; cut_transition=-1
	entry_left=.36; exit_left=0; camera_ready=false
	goal_end=game.attack_sign(game.goal_team)
	if goal_end==0.0: goal_end=signf(game.ball.position.z)
	if goal_end==0.0: goal_end=-1.0
	goal_at=-1
	for index in range(frames.size()):
		var point: Vector3=frames[index].ball
		if point.z*goal_end>=P.HALF_LENGTH and absf(point.x)<4.2 and point.y<3:
			goal_at=index/RATE; break
	var first: Dictionary=frames[0]
	camera_side=-1.0 if first.ball.x< -14 else 1.0
	previous_point=first.ball
	display_seconds=first.seconds; display_score=first.score
	for i in range(nodes.size()): nodes[i].transform=first.transforms[i]
	for p in game.players: p.reset_physics_interpolation()
	game.ball.reset_physics_interpolation()
	for i in range(game.players.size()): game.players[i].visible=first.visible[i]
	game.broadcast.show_graphic("goal",game.broadcast.goal_caption())
	place_camera(0)
	return true

func update(delta: float) -> void:
	entry_left=maxf(0,entry_left-delta)
	cut_age+=delta
	age+=delta*playback_speed()
	var frame_index := age*RATE
	if frame_index>=frames.size()-1: finish(); return
	var a: Dictionary=frames[int(frame_index)]
	var b: Dictionary=frames[mini(int(frame_index)+1,frames.size()-1)]
	display_seconds=lerpf(a.seconds,b.seconds,fmod(frame_index,1.0))
	display_score=a.score
	for i in range(nodes.size()): nodes[i].transform=a.transforms[i].interpolate_with(b.transforms[i],fmod(frame_index,1.0))
	for i in range(game.players.size()): game.players[i].visible=a.visible[i]
	for i in range(game.stadium.nets.size()): game.stadium.nets[i].show_replay(a.nets[i],b.nets[i],fmod(frame_index,1.0))
	if cut_transition>=0:
		cut_transition+=delta
		if pending_cut>=0 and cut_transition>=FADE_OUT+FADE_HOLD*.5:
			cut=pending_cut; pending_cut=-1; cut_age=0; camera_ready=false
		if cut_transition>=FADE_OUT+FADE_HOLD+FADE_IN: cut_transition=-1
	else: choose_cut()
	place_camera(delta)

func choose_cut() -> void:
	if cut_transition>=0 or cut_age<CUT_HOLD: return
	# Keep the ball crossing the goal line visible. A presentation transition
	# must never cover the decisive moment of the replay.
	if goal_at>=0 and age>goal_at-.8 and age<goal_at+.30: return
	var point: Vector3=game.ball.position
	var mouth := Vector3(0,0,goal_end*50)
	var approach := Vector3(point.x,0,point.z).distance_to(mouth)
	var next := cut
	# A shot progresses through its angles once. Crossing a distance boundary
	# no longer switches cameras back and forth every simulation tick.
	if cut==0 and approach<18 and absf(point.x)<20: next=1
	elif cut==1 and approach<7.2 and absf(point.x)<7 and (goal_at<0 or age>=goal_at+.30) and (frames.size()-1)/RATE-age>.6: next=2
	elif cut>0 and approach>27: next=0
	if next!=cut:
		pending_cut=next; cut_transition=0

func playback_speed() -> float:
	if goal_at<0: return .8
	# Ease only the recorded timeline, never live physics or input timing.
	var entry:=smoothstep(goal_at-.50,goal_at-.18,age)
	var leave:=smoothstep(goal_at+.12,goal_at+.43,age)
	return lerpf(.8,.38,entry*(1-leave))

func place_camera(delta: float=0.0) -> void:
	var point: Vector3=game.ball.position
	var end := goal_end
	var goal := Vector3(0,0.95,end*50)
	var look := point+Vector3(0,0.7,0)
	var eye := Vector3(camera_side*24,11.5,clampf(point.z-end*8,-43,43))
	var fov := 46.0
	if cut==1:
		eye=Vector3(camera_side*15,8.2,end*57)
		look=point.lerp(goal,0.16)+Vector3(0,0.5,0)
		fov=48.0
	elif cut==2:
		eye=Vector3(camera_side*10,5.2,end*55)
		look=point.lerp(goal,0.12)+Vector3(0,0.45,0)
		fov=50.0
	# Recorded discontinuities (e.g. a restart) are also covered, never swept
	# across the stadium. Normal pursuit has a level horizon and bounded speed.
	if camera_ready and point.distance_to(previous_point)>12:
		entry_left=.36; camera_ready=false
	previous_point=point
	if not camera_ready or delta<=0:
		camera_eye=eye; camera_look=look; camera_ready=true
	else:
		camera_eye=camera_eye.move_toward(camera_eye.lerp(eye,1-exp(-delta*2.5)),delta*8)
		camera_look=camera_look.move_toward(camera_look.lerp(look,1-exp(-delta*7)),delta*30)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=fov
	game.camera.position=camera_eye
	game.camera.look_at(camera_look,Vector3.UP)

func transition_alpha() -> float:
	var alpha := smoothstep(0,.36,entry_left)
	if exit_left>0: alpha=maxf(alpha,smoothstep(0,.28,exit_left))
	if cut_transition>=0:
		var fade := smoothstep(0,FADE_OUT,cut_transition)*(1-smoothstep(FADE_OUT+FADE_HOLD,FADE_OUT+FADE_HOLD+FADE_IN,cut_transition))
		alpha=maxf(alpha,fade)
	return alpha

func update_outro(delta: float) -> void:
	if game.state!="paused": exit_left=maxf(0,exit_left-delta)

func finish() -> void:
	game.audio.release_replay_chant()
	if saved.is_empty(): return
	exit_left=.28; entry_left=0; cut_transition=-1; pending_cut=-1
	for i in range(nodes.size()): nodes[i].transform=saved.transforms[i]
	for p in game.players: p.reset_physics_interpolation()
	game.ball.reset_physics_interpolation()
	for i in range(game.players.size()): game.players[i].visible=saved.visible[i]
	game.ball.freeze=saved.freeze
	game.ball.active=saved.active
	game.ball.linear_velocity=saved.velocity
	game.ball.angular_velocity=saved.spin
	for i in range(game.stadium.nets.size()): game.stadium.nets[i].restore_physics(saved.net_physics[i])
	game.state="goal"
	game.update_stadium_score()
	game.previous_ball=game.ball.position
	saved.clear()
	frames.clear()
	restart_clip=false
	cut=0
	game.match_camera.cinematic()

func reset() -> void:
	goal_tail=0
	finish()
	frames.clear()
	sample_age=0
	cut=0
	entry_left=0; exit_left=0; cut_transition=-1; pending_cut=-1; camera_ready=false
