extends SceneTree
var game
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func shot(p: Vector3,v: Vector3,count: int=150) -> Dictionary:
	for net in game.stadium.nets: net.reset(); net.impact_count=0
	game.ball.place(p,v)
	var peak := 0.0
	var farthest := 0.0
	var peak_speed := 0.0
	for i in range(count):
		await physics_frame
		peak=maxf(peak,game.stadium.nets[0 if p.z<0 else 1].max_deformation())
		farthest=maxf(farthest,absf(game.ball.position.z))
		if i>10: peak_speed=maxf(peak_speed,game.ball.linear_velocity.length())
		if visual and i==25 and v.z< -25:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/net-impact.png")
	var result={"deformation":peak,"farthest":farthest,"speed":game.ball.linear_velocity.length(),"position":game.ball.position,"contacts":game.stadium.nets[0 if p.z<0 else 1].impact_count,"peak_speed":peak_speed}
	print(result)
	return result
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.start_match(true)
	game.set_physics_process(false)
	game.set_process(false)
	game.hud.visible=false
	for p in game.players: p.collision_layer=0; p.visible=false
	game.camera.position=Vector3(8,5,-43)
	game.camera.look_at(Vector3(0,1,-52))
	game.camera.size=11
	var weak=await shot(Vector3(0,1,-51),Vector3(0,1,-8))
	var strong=await shot(Vector3(0.8,1.1,-50.8),Vector3(0,2,-32))
	check(strong.contacts>0 and strong.deformation>0.10,"Ball contact physically deforms the rear net")
	check(strong.deformation>weak.deformation*1.15,"A hard shot stretches the net more than a soft shot")
	check(strong.farthest<53.5 and strong.position.z< -50,"Hard shot remains in the goal without tunnelling through the net")
	check(strong.speed<8 and strong.peak_speed<33,"Net dissipates shot energy without an explosive rebound")
	check(game.stadium.nets[1].max_deformation()==0,"The untouched opposite goal remains still")
	var pinned_ok := true
	for panel in game.stadium.nets[0].panels:
		for i in range(panel.offset.size()):
			if panel.pinned[i] and panel.offset[i]!=0: pinned_ok=false
	check(pinned_ok,"Net attachment points remain fixed to the frame")
	game.ball.place(Vector3(0,0.23,0))
	await frames(600)
	check(game.stadium.nets[0].max_deformation()<0.002,"Net oscillations settle after the ball leaves")
	var side=await shot(Vector3(2.5,1.0,-51.2),Vector3(17,0,0))
	check(side.contacts>0 and side.deformation>0.05 and absf(side.position.x)<4.65,"Side net stretches and contains an angled shot")
	var roof=await shot(Vector3(0,1.4,-51.1),Vector3(0,12,0))
	check(roof.contacts>0 and roof.deformation>0.05 and roof.position.y<2.7,"Roof net reacts to an upward ball")
	var south=await shot(Vector3(-0.8,1.1,50.8),Vector3(0,2,32))
	check(south.contacts>0 and south.deformation>0.1 and south.position.z>50 and south.farthest<53.5,"Both goals have mirrored physical net contact")
	var outside=await shot(Vector3(4.6,1,-51.2),Vector3(-12,0,0))
	check(outside.contacts>0 and outside.deformation>0.05 and outside.position.x>3.5,"A shot hitting the outside of the side net cannot enter the goal")
	var low=await shot(Vector3(-2.9,0.24,-50.9),Vector3(-2,0,-32))
	check(low.contacts>0 and low.farthest<53.5 and absf(low.position.x)<4.65,"A low angled shot stays inside the joined net surfaces")
	var fast=await shot(Vector3(-1.6,1,-50.8),Vector3(0,0,-48),100)
	check(fast.contacts>0 and fast.farthest<53.5 and fast.peak_speed<48,"Swept contact contains shots faster than the maximum player shot")
	await shot(Vector3(0,1,-48),Vector3(0,0,-2),30)
	check(game.stadium.nets[0].impact_count==0,"Net does not react before the ball touches it")
	game.free()
	await process_frame
	print("NET CHECK: %d failures" % failures)
	quit(0 if failures==0 else 1)
