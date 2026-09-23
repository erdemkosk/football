extends SceneTree
const Footballer = preload("res://scripts/footballer.gd")
const P = preload("res://scripts/pitch_dimensions.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.sync_navigation(); game.hud.queue_redraw()
	for i in range(12): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/player-scale-"+label+".png")

func run() -> void:
	var actor := Footballer.new()
	root.add_child(actor)
	actor.body_language.enabled=false
	actor.idle_habit=0
	actor.number=10
	for height in [166,180,199]:
		actor.height_cm=height; actor.weight_kg=roundi(23*pow(height/100.0,2))
		actor.apply_build()
		actor.animate(1)
		var crown := actor.head_joint.to_global(Vector3(0,.3855,0)).y
		var boot: float=actor.left_knee.to_global(actor.ball_actions.BOOT).y
		var sole: float=boot-.115*.61*actor.body_scale.y
		print("HEIGHT %d cm -> %.3f m; sole %.3f m" % [height,crown,sole])
		check(absf(crown-height/100.0)<.035,"Standing model matches roster height: %d cm" % height)
		check(sole>=.005 and sole<.035,"Boot rests on the turf without floating: %d cm" % height)
		check(absf(actor.body_collision.shape.height-(height/100.0-.08))<.012 and actor.body_collision.shape.radius<.30,"Human-sized collision fits the visible body")
	actor.height_cm=180; actor.weight_kg=76; actor.apply_build(); actor.animate(1)
	check(absf(2.44-actor.head_joint.to_global(Vector3(0,.3855,0)).y-.64)<.02,"A 180 cm player has 64 cm of standing clearance under the crossbar")
	check(actor.call_label.position.y>1.8 and actor.call_label.position.y<2.15,"Pass-call label stays just above the player's head")
	actor.keeper=true; actor.height_cm=195; actor.apply_build()
	actor.start_dive(2.5,1.4,.45); actor.action_timer=actor.dive_duration-.38; actor.animate_dive()
	check(actor.rig.basis.get_scale().is_equal_approx(actor.body_scale),"Diving keeps the new body proportions")
	actor.action_timer=0; actor.tackle_cooldown=0; actor.start_claim(2.8,.35)
	var reach: float=actor.body_scale.y*1.94+actor.velocity.y*.35-10*.35*.35
	check(absf(reach-2.8)<.06,"Cross-claim jump accounts for the actual raised glove height")
	actor.free()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.start_match(false,false)
	game.state="playing"; game.match_camera.defaults()
	game.ball.place(Vector3(0,.23,-8),Vector3.ZERO); game.ball.freeze=true
	game.camera_focus=Vector3(0,0,-8); game.update_camera(0)
	check(game.match_camera.id()=="sideline" and game.camera.position.y>=22 and game.camera.fov>=42,"Default camera gives the smaller players a higher, wider sideline view")
	check(P.WIDTH==72 and P.LENGTH==100,"Pitch geometry retains its existing metre dimensions")
	await capture("match")
	game.hud.hide()
	for p in game.players: p.visible=false
	var player=game.players[9]
	player.visible=true; player.position=Vector3(1.8,0,-49)
	player.height_cm=180; player.weight_kg=76; player.apply_build()
	player.body_language.enabled=false; player.rig.rotation=Vector3.ZERO; player.facing=Vector3.BACK
	player.animate(1)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=42
	game.camera.position=Vector3(9,4,-36); game.camera.look_at(Vector3(0,1,-49.5))
	await capture("goal")
	game.hud.show(); game.frontend.open_selection()
	await capture("selection")
	check(game.frontend.previews[0].player.body_scale.y<1.1,"Team selection uses the same corrected player scale")
	print("PLAYER SCALE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
