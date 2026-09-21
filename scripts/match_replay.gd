extends RefCounted
## Visual playback never runs football logic; all live transforms are restored.
var game
var frames: Array = []
var nodes: Array[Node3D] = []
var saved: Dictionary = {}
var age := 0.0
var sample_age := 0.0
var enabled := true
var restart_clip := false
var goal_tail := 0.0
const RATE := 20.0
const SECONDS := 5.0

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
	var transforms: Array[Transform3D] = []
	for node in nodes: transforms.append(node.transform)
	var visibility: Array[bool] = []
	for p in game.players: visibility.append(p.visible)
	var net_poses: Array=[]
	for net in game.stadium.nets: net_poses.append(net.capture_pose())
	return {"transforms":transforms,"visible":visibility,"ball":game.ball.position,"nets":net_poses}

func capture(delta: float) -> void:
	if not enabled or game.training: return
	sample_age+=delta
	if sample_age<1.0/RATE: return
	sample_age=fmod(sample_age,1.0/RATE)
	frames.append(snapshot())
	if frames.size()>int(RATE*SECONDS): frames.pop_front()

func origin() -> void:
	# A restart that can score immediately must not replay the previous open play.
	if not enabled or game.training: return
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
	age=0
	game.match_camera.cinematic()
	return true

func update(delta: float) -> void:
	age+=delta*0.8
	var frame_index := age*RATE
	if frame_index>=frames.size()-1: finish(); return
	var a: Dictionary=frames[int(frame_index)]
	var b: Dictionary=frames[mini(int(frame_index)+1,frames.size()-1)]
	for i in range(nodes.size()): nodes[i].transform=a.transforms[i].interpolate_with(b.transforms[i],fmod(frame_index,1.0))
	for i in range(game.players.size()): game.players[i].visible=a.visible[i]
	for i in range(game.stadium.nets.size()): game.stadium.nets[i].show_replay(a.nets[i],b.nets[i],fmod(frame_index,1.0))
	var point: Vector3=game.ball.position
	game.camera.size=36
	game.camera.position=point+Vector3(24,32,28)
	game.camera.look_at(point)

func finish() -> void:
	if saved.is_empty(): return
	for i in range(nodes.size()): nodes[i].transform=saved.transforms[i]
	for i in range(game.players.size()): game.players[i].visible=saved.visible[i]
	game.ball.freeze=saved.freeze
	game.ball.active=saved.active
	game.ball.linear_velocity=saved.velocity
	game.ball.angular_velocity=saved.spin
	for i in range(game.stadium.nets.size()): game.stadium.nets[i].restore_physics(saved.net_physics[i])
	game.state="goal"
	game.previous_ball=game.ball.position
	saved.clear()
	frames.clear()
	restart_clip=false

func reset() -> void:
	goal_tail=0
	finish()
	frames.clear()
	sample_age=0
