extends SceneTree
## Deterministic framing/garment regressions and optional rendered review shots.
const Shirt=preload("res://scripts/shirt_skin.gd")
var game
var failures:=0
var checks:=0
var output:="/tmp/sefc-visual-quality"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func framed(point: Vector3,margin: float=.04) -> bool:
	if game.camera.is_position_behind(point): return false
	var uv: Vector2=game.camera.unproject_position(point)/game.get_viewport().get_visible_rect().size
	return uv.x>margin and uv.x<1-margin and uv.y>margin and uv.y<1-margin
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func layout(x: float,z: float=0) -> void:
	game.state="playing"; game.restart_type=""; game.controlled=9; game.dribbler=9; game.carrier=9
	game.ball.position=Vector3(x,.23,z-.65); game.ball.linear_velocity=Vector3.ZERO
	var p=game.players[9]
	for actor in game.players:
		actor.position=actor.home; actor.velocity=Vector3.ZERO; actor.desired=Vector3.ZERO
		actor.set_piece_pose=""; actor.prematch=false; actor.action_timer=0; actor.kick_timer=0
		actor.pose=""; actor.body_language.clear_intent(); actor.idle_rest=0
	p.position=Vector3(x,0,z); p.facing=Vector3.FORWARD
	game.players[6].position=Vector3(x-5 if x>0 else x+5,0,z-9)
	game.players[10].position=Vector3(x-8 if x>0 else x+8,0,z+11)
	game.players[20].position=Vector3(x-2 if x>0 else x+2,0,z-3)
	for actor in game.players: actor.animate(1)
	game.match_camera.select("sideline"); game.match_camera.attack_lead=Vector3.ZERO
	game.camera_focus=Vector3.ZERO; game.update_camera(0)
	game.weather.presence.update_visuals()
func garment() -> void:
	var arrays:=Shirt.SURFACE.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var triangles: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var valid:=true; var blended:=0
	var welded: Dictionary={}; var ids: Array[int]=[]; var edges: Dictionary={}
	for i in range(points.size()):
		var key:=Vector3i((points[i]*100000).round())
		if not welded.has(key): welded[key]=welded.size()
		ids.append(welded[key])
		var sum:=0.0
		for k in range(4):
			sum+=weights[i*4+k]
			valid=valid and weights[i*4+k]>=0 and bones[i*4+k]>=0 and bones[i*4+k]<preload("res://scripts/shirt_skin.gd").REST.size()
		valid=valid and absf(sum-1)<.0001 and points[i].is_finite() and normals[i].length()>.99
		if weights[i*4]>.05 and weights[i*4]<.95: blended+=1
	for i in range(0,triangles.size(),3):
		for j in range(3):
			var a:=ids[triangles[i+j]]; var b:=ids[triangles[i+(j+1)%3]]
			if not edges.has(a): edges[a]=[]
			edges[a].append(b)
	var seen: Dictionary={}; var pending: Array[int]=[0]
	while not pending.is_empty():
		var at: int=pending.pop_back()
		if seen.has(at): continue
		seen[at]=true
		for next: int in edges.get(at,[]):
			if not seen.has(next): pending.append(next)
	print("GARMENT CONNECTIVITY reached=",seen.size()," referenced=",edges.size()," welded=",welded.size())
	check(seen.size()==edges.size(),"Torso and both sleeves form a single connected surface, including UV seams")
	check(valid and blended>100 and points.size()<8500,"Shoulders have normalized blended skin weights within the shared mesh budget")
	var p=game.players[9]
	for rotation in [Vector3.ZERO,Vector3(-1.7,0,-.5),Vector3(.6,.2,.4)]:
		p.left_arm.rotation=rotation; p.right_arm.rotation=rotation*Vector3(1,-1,-1)
		p.shirt_skin.sync_pose()
		for pose: Transform3D in p.shirt_skin.poses: valid=valid and pose.is_finite()
		var hand: Transform3D=p.left_hand.global_transform
		p.shirt_skin.sync_pose(); valid=valid and hand==p.left_hand.global_transform
	check(valid,"Animated shirt remains finite and does not move the hand/contact rig")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if "--visual" in OS.get_cmdline_user_args(): DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-visual-quality/settings.tmp"
	game.match_menu.display.set_fullscreen(false)
	if DisplayServer.get_name()!="headless": await create_timer(.7).timeout
	game.match_menu.display.select_resolution(Vector2i(1440,900))
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.controller.set_process(false); game.ball.freeze=true; game.ball.pending_reset=false
	game.frontend.hide(); game.hud.hide(); game.match_menu.hide(); game.toast_timer=0
	game.weather.select(0,true); game.stadium.light_rig.select(0)
	game.match_camera.defaults()
	garment()
	for x in [-32.0,0.0,32.0]:
		layout(x)
		var visible:=true
		for i in [9,6,10]:
			visible=visible and framed(game.players[i].position) and framed(game.players[i].position+Vector3.UP*1.7)
		check(visible and framed(game.ball.position),"Ball, active player's feet/head and two nearby passing options fit at x=%s" % x)
		var at: Vector3=game.players[9].position
		var pixels: float=game.camera.unproject_position(at).distance_to(game.camera.unproject_position(at+Vector3.UP*1.8))
		print("PLAYER HEIGHT x=",x," pixels=",pixels," viewport=",root.size)
		check(pixels>24,"Active player is large enough to read foot/ball contact at x=%s" % x)
		await capture("match-"+str(int(x)))
	var before: Transform3D=game.camera.global_transform; var fov: float=game.camera.fov
	game.state="paused"; game.ball.position=Vector3(-32,4,-40); game.update_camera(.2)
	check(before.is_equal_approx(game.camera.global_transform) and is_equal_approx(fov,game.camera.fov),"Pausing freezes the closer camera, including its lens")
	layout(0); game.stadium.light_rig.select(1); await capture("match-night")
	game.weather.select(2,true); game.weather.update(8); await capture("match-rain")
	game.weather.select(0,true); game.stadium.light_rig.select(0)
	game.camera.position=Vector3(4,3.3,5); game.camera.look_at(Vector3(0,.8,0)); game.camera.fov=42
	await capture("pitch-close")
	game.camera.position=Vector3(-29,11,18); game.camera.look_at(Vector3(-44,6,18)); game.camera.fov=45
	await capture("crowd-close")
	print("VISUAL QUALITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
