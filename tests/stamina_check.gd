extends SceneTree
var game
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func advance(p,seconds:float,rate:float=120) -> void:
	for i in range(int(seconds*rate)): p.update_stamina(1.0/rate)
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	game.ball.freeze=true
	var p=game.players[9]
	var ai=game.players[18]
	# Durations below use the base drain constants; isolate endurance from
	# the club-specific attributes that the live squad now starts with.
	p.attributes.stamina=72; ai.attributes.stamina=72
	p.desired=Vector3.FORWARD
	p.sprinting=true
	advance(p,0.5)
	check(p.active_sprint and p.energy<1.0-p.SPRINT_DRAIN*0.25 and p.movement_speed()>8.5*p.MOVEMENT_PACE,"Sprinting consumes stamina while enabling higher speed")
	advance(p,(p.energy-p.EXHAUSTION_LIMIT)/p.SPRINT_DRAIN+0.15)
	check(p.exhausted and not p.active_sprint and is_equal_approx(p.movement_speed(),3.4*p.MOVEMENT_PACE),"A sustained sprint ends in exhaustion and walking speed")
	var never_restarted:=true
	for i in range(1200):
		p.update_stamina(1.0/120.0)
		if p.active_sprint: never_restarted=false
	check(never_restarted and p.energy>p.RECOVERY_LIMIT,"Holding W cannot repeatedly reactivate sprint while recovering")
	p.sprinting=false
	p.update_stamina(1.0/120.0)
	check(not p.exhausted,"Releasing W after sufficient recovery re-arms sprint")
	p.sprinting=true
	p.update_stamina(1.0/120.0)
	check(p.active_sprint,"A fresh W press can sprint after recovery")
	p.energy=0.05; p.exhausted=true; p.sprinting=false
	p.update_stamina(1.0/120.0)
	check(p.exhausted and not p.active_sprint,"Releasing W alone does not bypass the minimum stamina threshold")
	p.reset_stamina()
	p.desired=Vector3.FORWARD
	advance(p,(1.0-0.41)/p.RUN_DRAIN+0.5)
	check(p.energy<0.41 and not p.exhausted,"Normal running also gradually consumes stamina")
	advance(p,(p.energy-p.EXHAUSTION_LIMIT)/p.RUN_DRAIN+0.2)
	check(p.exhausted and p.movement_speed()<4,"Continuous normal running eventually forces a slower pace")
	p.reset_stamina(); p.energy=0.2; p.exhausted=true; p.desired=Vector3.ZERO
	advance(p,2)
	var resting_energy:float=p.energy
	p.reset_stamina(); p.energy=0.2; p.exhausted=true; p.desired=Vector3.FORWARD
	advance(p,2)
	check(resting_energy>p.energy+0.1,"Standing still recovers faster than walking")
	p.reset_stamina(); p.desired=Vector3.ZERO; p.sprinting=true
	advance(p,3)
	check(p.energy==1 and not p.active_sprint,"Holding W without movement does not drain stamina")
	p.reset_stamina(); p.desired=Vector3.FORWARD; p.sprinting=true
	advance(p,2,30)
	var energy30:float=p.energy
	p.reset_stamina(); p.desired=Vector3.FORWARD; p.sprinting=true
	advance(p,2,120)
	check(absf(energy30-p.energy)<0.001,"Stamina consumption is consistent across update rates")
	ai.reset_stamina(); ai.desired=Vector3.FORWARD; ai.sprinting=true
	advance(ai,(1.0-ai.EXHAUSTION_LIMIT)/ai.SPRINT_DRAIN+0.15)
	check(ai.exhausted and is_equal_approx(ai.movement_speed(),3.4*ai.MOVEMENT_PACE),"AI players use the same exhaustion rules")
	p.energy=0.16; p.exhausted=true
	game.reset_positions(0)
	check(p.energy==0.16 and p.exhausted,"Goal kickoffs do not refill stamina")
	game.start_match(false,false)
	check(p.energy==1 and not p.exhausted,"A new match restores stamina and clears exhaustion")
	game.start_match(true)
	p.energy=0.1; p.exhausted=true
	game.reset_practice()
	check(p.energy==1 and not p.exhausted,"A new practice attempt restores training stamina")
	# Exercise actual movement, acceleration and animation on the physical field.
	p.position=Vector3(0,0,0)
	p.velocity=Vector3.ZERO
	p.energy=0.04; p.exhausted=true; p.desired=Vector3.FORWARD; p.sprinting=true
	for i in range(90):
		await physics_frame
		p.step(1.0/120.0)
	check(Vector2(p.velocity.x,p.velocity.z).length()<3.5,"Exhaustion actually limits physical player velocity")
	if visual:
		game.toast_timer=0
		game.camera.position=Vector3(6,7,5)
		game.camera.look_at(p.position+Vector3.UP)
		game.camera.size=8
		game.hud.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/stamina-exhausted.png")
	var before_pause:float=p.energy
	game.state="paused"
	for i in range(10): game._physics_process(0.1)
	check(p.energy==before_pause,"Paused matches do not drain or recover stamina")
	print("STAMINA CHECK: %d failures" % failures)
	game.free()
	await process_frame
	quit(0 if failures==0 else 1)
