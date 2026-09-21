extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	game._input(event)
func framed(at: Vector3) -> bool:
	if game.camera.is_position_behind(at): return false
	var view: Vector2=game.get_viewport().get_visible_rect().size
	var screen: Vector2=game.camera.unproject_position(at)
	return screen.x>48 and screen.x<view.x-48 and screen.y>48 and screen.y<view.y-48
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	check(game.match_camera.id()=="pitch" and game.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"The game boots on the original pitch camera")
	game.start_match(false,false)
	game.set_physics_process(false)
	game.update_camera(0)
	check(game.match_camera.is_sideline() and game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and absf(game.camera.position.x-40)<0.05,"A match starts on the east sideline")
	var seen: PackedStringArray=[]
	for _i in range(5):
		key(KEY_C)
		game.update_camera(0)
		seen.append(game.match_camera.id())
	check(seen==PackedStringArray(["end","tactical","pitch","broadcast","sideline"]),"C walks end, tactical, pitch and broadcast, then returns to the sideline")
	check(game.match_camera.is_sideline() and game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"The fifth press restores the default sideline")
	game.ball.place(Vector3(32,0.23,8),Vector3.ZERO)
	game.state="set_piece"
	game.restart_type="TAÇ"
	game.restart_point=Vector3(32,0,8)
	game.update_camera(0)
	check(game.camera.position.x>43 and game.camera.position.y>22,"Sideline leans back and up when the ball reaches the near touchline")
	check(framed(game.restart_point+Vector3.UP*0.9),"A near-side throw-in stays inside the frame")
	game.ball.place(Vector3.ZERO,Vector3.ZERO)
	game.state="playing"
	game.restart_type=""
	game.update_camera(0)
	key(KEY_C)
	game.update_camera(0)
	check(game.match_camera.id()=="end" and signf(game.camera.position.z)==signf(game.attack_sign(0)),"End camera stands behind the attack goal")
	game.tactical=true
	game.update_camera(0)
	check(game.tactical and game.camera.size>100 and game.camera_focus.length()<0.2,"The tactical setter still opens the full-pitch view")
	game.tactical=false
	game.update_camera(0)
	check(game.match_camera.is_sideline(),"Leaving tactical returns to the default sideline")
	game.controller.device=0
	game.controller.stick=Vector2(0,-1)
	game.match_camera.select("pitch")
	game.update_camera(0)
	var pitch_up: Vector3=game.movement_input()
	check(pitch_up.dot(Vector3(0,0,-1))>0.95,"Pitch camera keeps stick-up as the original north run")
	game.match_camera.select("sideline")
	game.update_camera(0)
	var side_up: Vector3=game.movement_input()
	check(side_up.x<-0.85 and absf(side_up.z)<0.35,"Sideline stick-up runs onto the pitch, not along the touchline")
	game.match_camera.select("end")
	game.update_camera(0)
	var end_up: Vector3=game.movement_input()
	check(end_up.dot(game.match_camera.ground_forward())>0.95,"End-camera stick-up runs toward what the lens sees")
	game.controller.stick=Vector2.ZERO
	game.begin_restart("SERBEST VURUŞ",0,Vector3(0,0,-25))
	game.state="set_piece"
	game.set_pieces.direction=Vector3.RIGHT
	game.match_camera.select("sideline")
	game.update_camera(0)
	var kick_before: Vector3=game.set_pieces.direction
	game.controller.device=0
	game.controller.stick=Vector2(1,0)
	game.set_pieces.update(0.25)
	check(game.set_pieces.direction.dot(game.match_camera.ground_right())>kick_before.dot(game.match_camera.ground_right())+0.05 and game.set_pieces.direction.x<kick_before.x,"Sideline free-kick aim follows screen-right, not world X")
	game.controller.stick=Vector2.ZERO
	game.start_match(false,false)
	game.update_camera(0)
	check(game.match_camera.is_sideline() and game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"A new match forgets the last angle and starts on the sideline")
	print("CAMERA RIG CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
