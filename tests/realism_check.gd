extends SceneTree
var game
var failures := 0
var checks := 0
const Attributes=preload("res://scripts/player_attributes.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func setup() -> void:
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.pending_touch=false; game.ball.linear_velocity=Vector3.ZERO
	game.ball.position=Vector3(0,.23,-.6)
	game.controller.adopt_device(0,"Xbox Controller")
func key(code: int) -> InputEventKey:
	var e := InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=true
	return e
func pad(code: int,down: bool=true,device: int=0) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new(); e.button_index=code; e.pressed=down; e.device=device
	return e
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup()
	var bounded := true
	for club in range(8):
		for member in range(18):
			var stats: Dictionary=Attributes.profile(club,member,member in [0,11])
			for field in Attributes.KEYS: bounded=bounded and stats[field]>=45 and stats[field]<=93
			bounded=bounded and stats.preferred_foot in [0,1] and stats.weak_foot in [2,3,4]
	check(bounded,"Every roster identity has bounded, repeatable football attributes")
	var winger: Dictionary=Attributes.profile(0,8)
	var defender: Dictionary=Attributes.profile(0,2)
	check(winger.pace>defender.pace and winger.acceleration>defender.acceleration and defender.heading>winger.heading and defender.balance>winger.balance,"Quick wingers and strong centre backs have distinct strengths")
	var p=game.players[9]
	var saved: Dictionary=p.identity()
	var stats: Dictionary=p.attributes.duplicate()
	p.apply_identity(game.management.bench[0][2]); p.apply_identity(saved)
	check(p.attributes==stats,"Identity round-trip preserves the actual player's attributes")
	p.attributes=winger; p.sprinting=true; p.energy=1; p.exhausted=false
	var quick: float=p.movement_speed()
	p.attributes=defender
	check(p.movement_speed()<quick and quick/p.movement_speed()<1.3,"Pace changes movement within balanced limits")
	p.apply_identity(saved); p.position=Vector3.ZERO; p.rig.rotation=Vector3.ZERO; p.facing=Vector3.FORWARD
	p.attributes.preferred_foot=1; p.attributes.weak_foot=2
	var right := Vector3(.5,.23,-.5)
	var left := Vector3(-.5,.23,-.5)
	check(p.ball_actions.choose_foot(p,right)==1 and p.ball_actions.choose_foot(p,left)==0,"Actual ball position chooses the foot before weak-foot ability is applied")
	check(Attributes.kick_factor(p,right)>Attributes.kick_factor(p,left),"A weak-foot shot has a bounded physical power difference")
	game.ball.position=left; game.controlled=9
	var preview: Vector3=game.shot_velocity(Vector3.FORWARD,.6,false,false)
	check(preview==game.shot_velocity(Vector3.FORWARD,.6,false,false,9),"Shot guide and explicit player shot use the same attribute-aware velocity")
	for q in game.players:
		if q!=p: q.position=Vector3(25,0,25)
	game.ball.position=Vector3(.25,.23,-.6); game.ball.linear_velocity=Vector3(0,0,18)
	p.desired=Vector3.ZERO; p.velocity=Vector3.ZERO; p.contest_weight=.7; p.attributes.control=90; p.attributes.balance=90
	game.first_touch.receive(9,false)
	var soft: float=game.ball.touch_velocity.length()
	p.attributes.control=50; p.attributes.balance=50
	game.first_touch.receive(9,false)
	check(game.ball.touch_velocity.length()>soft and game.ball.pending_touch,"Control and balance change the real cushioning impulse under pressure")
	setup()
	game.dribbler=20; game.carrier=20; game.ball.position=Vector3(0,.23,15)
	game.players[20].position=Vector3(0,0,15)
	game.players[6].position=Vector3(1,0,17)
	game.team_tactics.update(.2)
	var pressing := 0; var covering := 0
	for role in game.team_tactics.roles.values():
		pressing+=int(role=="press"); covering+=int(role=="cover")
	check(pressing==1 and covering==1 and game.team_tactics.targets.size()==10,"Defending team assigns one presser, one cover and a connected outfield block")
	var depths: Array[float]=[]
	for i in range(1,5):
		if game.team_tactics.roles.get(i,"")=="block": depths.append(game.team_tactics.targets[i].z)
	check(depths.size()>=2 and absf(depths.max()-depths.min())<.01,"Remaining defenders hold one shared depth instead of chasing independently")
	var line_player := 1
	for i in range(1,5):
		if game.team_tactics.roles.get(i,"")=="block": line_player=i; break
	game.management.line_height=0; game.team_tactics.update(.2)
	var deep: float=game.team_tactics.targets[line_player].z
	game.management.line_height=2; game.team_tactics.update(.2)
	check(game.team_tactics.targets[line_player].z<deep-5,"The user's separate defensive-line setting remains effective")
	game.management.pressing=0; game.team_tactics.update(.2)
	check(game.team_tactics.press_level(0)==0,"Independent pressing instructions remain separate from mentality")
	game.match_time=game.LENGTH*.9; game.score=[2,1]
	check(game.team_tactics.plan_for(1)==2,"A losing opponent takes more risk late in the match")
	game.score=[1,2]
	check(game.team_tactics.plan_for(1)==0,"A leading opponent protects its advantage late in the match")
	game.carrier=20
	var cautious: Vector3=game.management.adjust_target(17,Vector3.ZERO)
	game.score=[2,1]
	check(game.management.adjust_target(17,Vector3.ZERO).z>cautious.z+5,"Score context also changes attacking support positions")
	setup()
	game.carrier=-1; game.dribbler=-1
	game.ball.position=Vector3(0,.23,-35); game.ball.linear_velocity=Vector3(4,6,5)
	for i in range(22): game.players[i].position=Vector3((i%5)-2,0,-33+float(i%3)*2)
	var landing: Vector3=game.second_balls.landing()
	check(game.flat_distance(landing,game.ball.position)>2,"A rising low rebound is followed to its landing rather than its launch point")
	game.second_balls.alert("save",0); game.second_balls.update(.01)
	check(game.second_balls.targets.size()==4 and game.second_balls.roles.values().count("contest")==2 and "finish" in game.second_balls.roles.values() and "protect_goal" in game.second_balls.roles.values(),"Both teams contest a parry with separate finishing and goal-protection support")
	check(game.shots==[0,0] and game.passes==[0,0] and not game.ball.pending_kick,"Rebound assignments move players without automatically shooting or passing for the user")
	game.dribbler=9; game.second_balls.update(.01)
	check(game.second_balls.targets.is_empty() and game.second_balls.remaining==0,"Confirmed possession immediately ends the loose-ball chase")
	game.dribbler=-1; game.reactions.shooter=9; game.reactions.shot_age=.8
	game.second_balls.previous_velocity=Vector3(0,0,-18); game.ball.linear_velocity=Vector3(3,0,8); game.kick_lock=0
	game.second_balls.update(.01)
	check(game.second_balls.source=="rebound" and game.second_balls.attacking_team==0,"A real sharp shot deflection triggers second-ball reactions")
	game.begin_restart("TAÇ",0,Vector3(32,0,-35))
	check(game.second_balls.remaining==0 and game.second_balls.targets.is_empty(),"A whistle cancels obsolete rebound targets")
	setup()
	p=game.players[9]; var q=game.players[20]
	for actor in game.players: actor.position=Vector3(25,0,25)
	p.position=Vector3(-.4,0,0); q.position=Vector3(.4,0,0)
	p.velocity=Vector3(0,0,-4); q.velocity=p.velocity; p.facing=Vector3.FORWARD; q.facing=p.facing
	game.physical_contests.update(.1)
	check(game.physical_contests.pairs.size()==1 and p.contest_weight>0 and q.contest_weight>0,"Side-by-side runners share a paired shoulder-contest pose")
	check(p.velocity.x<0 and q.velocity.x>0 and game.state=="playing" and p.fouls_committed==0 and q.fouls_committed==0,"Legal shoulder contact applies opposing pressure without manufacturing a foul")
	q.position.y=2; game.physical_contests.update(.1)
	check(game.physical_contests.pairs.is_empty(),"Vertically separated players do not push each other across the pitch")
	q.position.y=0; p.velocity=Vector3.ZERO; q.velocity=Vector3.ZERO; p.pose="header"; p.action_timer=.2
	game.physical_contests.update(.1)
	check(game.physical_contests.pairs.size()==1,"Players can hold their aerial position before the jump")
	game.physical_contests.reset()
	check(p.contest_weight==0 and p.landing_age==1 and not p.header_airborne,"New phases clear contest and landing state")
	var crowd=game.stadium.crowd
	crowd.context([0,0],0,game.LENGTH); var early: float=crowd.home_support
	crowd.context([0,1],game.LENGTH*.96,game.LENGTH)
	check(crowd.home_support>early+.4 and crowd.home_support>crowd.away_support,"The home crowd rallies for a late equalizer independently of the away end")
	crowd.react("goal",1,Vector3.ZERO); crowd.update(.2,Vector3.ZERO,Vector3.ZERO,1,false,true)
	check(crowd.hush>.1 and crowd.material.get_shader_parameter("event_team")==1.0,"An away goal quiets the main stands while the away supporters celebrate")
	crowd.reset(); crowd.context([0,0],game.LENGTH*.96,game.LENGTH); crowd.react("goal",0,Vector3.ZERO)
	check(crowd.material.get_shader_parameter("event_strength")>1,"A late decisive goal increases the crowd's visible response")
	setup()
	game.broadcast.show_graphic("goal","KIYI  ·  EGE",1.0)
	game.broadcast.update(0.2)
	check(game.broadcast.graphic=="goal" and game.broadcast.graphic_weight()>0.4 and not game.broadcast.active,"A scored goal can raise a one-second lower-third without stealing the camera")
	game.broadcast.update(1.0)
	check(game.broadcast.graphic=="","The goal graphic expires after one second")
	game.broadcast.offer("miss",9); game.broadcast.update(.1)
	check(not game.broadcast.active,"Broadcast inserts cannot interrupt live football")
	game.state="restart"; game.broadcast.offer("miss",9); game.broadcast.update(.1)
	check(game.broadcast.active and game.broadcast.kind=="miss" and game.players[9].display_name in game.broadcast.caption,"A missed-chance insert identifies the player during a stoppage")
	check(not game.broadcast.handle(pad(JOY_BUTTON_A,true,1)) and game.broadcast.active,"An inactive second controller cannot skip the insert")
	check(game.broadcast.handle(pad(JOY_BUTTON_A)) and not game.broadcast.active and game.broadcast.handle(pad(JOY_BUTTON_A,false)),"Controller skip consumes both press and release without leaking a pass")
	game.broadcast.cooldown=0; game.broadcast.offer("miss",9); game.broadcast.update(.1); game.state="set_piece"; game.broadcast.update(.01)
	check(not game.broadcast.active,"A ready restart takes priority over the camera insert immediately")
	game.state="restart"; game.broadcast.cooldown=0; game.broadcast.offer("miss",9); game.broadcast.update(.1)
	check(game.broadcast.handle(key(KEY_SPACE)) and not game.broadcast.active,"Keyboard Space skips a stoppage insert")
	game.training=true; game.broadcast.reset(); game.broadcast.offer("miss",9)
	check(game.broadcast.queued.is_empty(),"Training keeps its uninterrupted camera flow")
	game.training=false; game.state="restart"; game.match_time=game.LENGTH*.9; game.score=[0,1]
	game.broadcast.restart(); game.broadcast.update(.1)
	check(game.broadcast.active and game.broadcast.kind=="coach" and game.stadium.sidelines.coach_orders[0].kind=="attack","A close late stoppage can show the trailing coach's instructions")
	game.broadcast.update(2)
	check(not game.broadcast.active,"An unwatched insert ends automatically within two seconds")
	print("REALISM CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
