extends "res://tests/power_shot_trail_check.gd"
func live_cues() -> int:
	var count:=0
	for cue in game.visual_identity.cues:
		if cue.age<cue.life: count+=1
	return count

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.controller.set_process(false)
	game.visual_identity.set_process(false)
	game.match_menu.config_path="/tmp/sefc-match-identity/settings.cfg"
	game.experience.reduce_motion=false
	await trail_fixture()
	var vfx=game.visual_identity
	game.finishing.style="power"; game.charging=true; game.charge=.8
	vfx._process(0)
	check(vfx.charge.visible and game.ball.power_trail.remaining==0,"Power windup lights the boot without a premature ball trail")
	game.charging=false; vfx._process(0)
	check(not vfx.charge.visible,"Releasing or cancelling the charge removes the boot ring")
	check(game.finishing.release_charged(9,p.facing,.7),"Power effect is reached through the real successful strike")
	check(vfx.event_counts.get("shot",0)==1 and live_cues()==2,"One power contact emits its short flash and ring exactly once")
	var ball_pose: Transform3D=game.ball.transform; var velocity: Vector3=game.ball.linear_velocity
	vfx._process(.05)
	check(game.ball.transform==ball_pose and game.ball.linear_velocity==velocity,"Effects never change ball transforms or velocity")
	await flight(18)
	check(game.ball.power_trail.node.visible and game.ball.power_trail.style=="power","Power ribbon follows the physical flight")
	await trail_fixture("")
	check(game.commit_strike(9,p.facing*27+Vector3.UP*3,2.5,false,"shot"),"A curved shot commits through the normal strike path")
	await flight(18)
	check(game.ball.power_trail.style=="finesse" and game.ball.power_trail.node.visible and game.ball.power_trail.node.material_override.get_shader_parameter("finesse"),"Curved shots select the two turquoise ribbons")
	await trail_fixture("timed")
	game.finishing.queue(9,p.facing,.6,"timed")
	game.finishing.pending.age=game.finishing.pending.contact-.035
	game.finishing.timing_press()
	check(vfx.event_counts.get("perfect",0)==0,"A timing-button press alone cannot emit a successful-contact halo")
	await flight(45)
	check(vfx.event_counts.get("perfect",0)==1,"Perfect timing emits its gold halo only at the actual successful contact")
	await trail_fixture("")
	p.strike_timing=.76
	game.commit_strike(9,p.facing*25+Vector3.UP*2,0,false,"shot")
	check(vfx.event_counts.get("perfect",0)==0 and game.ball.power_trail.remaining==0,"Early timing and ordinary shots do not gain special cues")
	vfx.reset(); game.weather.wetness=.8
	game.feedback.contact("glove",0,game.ball.position,Vector3.UP,.8)
	check(vfx.event_counts.get("glove",0)==1 and live_cues()==2 and vfx.particle_cursor>0,"A wet glove contact emits white impact and droplets")
	vfx.reset(); p.velocity=Vector3.ZERO; vfx.acceleration(9,.016)
	p.velocity=Vector3.FORWARD*7; vfx.acceleration(9,.016)
	check(vfx.event_counts.get("acceleration",0)==1 and live_cues()==2,"The first acceleration produces two short boot streaks")
	for i in range(10): vfx.acceleration(9,.016)
	check(vfx.event_counts.get("acceleration",0)==1,"Sustained running does not continuously spam acceleration effects")
	vfx.reset(); game.experience.reduce_motion=true; vfx.acceleration(9,.016)
	p.velocity=Vector3.RIGHT*8; vfx.acceleration(9,.016)
	check(live_cues()==0,"Reduced-motion mode suppresses speed streaks")
	game.experience.reduce_motion=false
	for i in range(200): vfx.perfect(Vector3.ZERO)
	check(vfx.cues.size()==vfx.CAPACITY and live_cues()==vfx.CAPACITY and vfx.particles.size()==6,"Burst allocation remains bounded during overlapping events")
	vfx._process(1)
	check(live_cues()==0,"Contact halos expire and return to the pool")
	game.goal(0); vfx._process(.3)
	check(vfx.goal_age<.4 and preload("res://scripts/led_boards.gd").materials[0].get_shader_parameter("goal_amount")>0,"A real goal starts team-coloured LED celebrations")
	var age: float=vfx.goal_age; game.state="paused"; vfx._process(.5)
	check(vfx.goal_age==age,"Pause freezes visual event time and LEDs")
	game.state="replay"; vfx._process(.016)
	check(live_cues()==0 and not vfx.charge.visible and preload("res://scripts/led_boards.gd").materials[0].get_shader_parameter("goal_amount")==0,"Replay entry clears live cues and restores normal LED programming")
	print("MATCH IDENTITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
