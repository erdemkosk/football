extends "res://tests/ai_attack_check.gd"
const World=preload("res://scripts/career_world.gd")

func attributes(index: int,value: int) -> void:
	for key in preload("res://scripts/player_talent.gd").STATS: game.players[index].attributes[key]=value
	game.players[index].energy=1
	game.players[index].appearance_id=9

func pass_trial(index: int,ability: int,pressured: bool) -> float:
	setup(); game.weather.select(0,true)
	for p in game.players: p.visible=false
	player(index,Vector3.ZERO); attributes(index,ability)
	game.controlled=index; game.players[index].career_id=""
	if pressured: player(20 if index==9 else 9,Vector3(.9,0,0))
	game.ball.freeze=false; game.ball.place(Vector3(0,.23,-.65),Vector3.ZERO)
	await physics_frame; await physics_frame
	game.commit_strike(index,Vector3(0,.1,-23),0,false,"kick")
	for tick in range(240):
		await physics_frame
		if game.ball.position.z<=-15: break
	check(game.ball.position.z<-14,"Pass travels over fourteen metres as a real rigid body")
	return absf(game.ball.position.x)

func first_touch_trial(ability: int) -> Dictionary:
	setup(); player(9,Vector3.ZERO); player(20,Vector3(.9,0,0))
	game.controlled=9; attributes(9,ability)
	var p=game.players[9]
	p.facing=Vector3.FORWARD; p.rig.rotation.y=0; p.desired=Vector3.FORWARD
	game.ball.position=Vector3(0,.23,-.6); game.ball.linear_velocity=Vector3.BACK*16
	game.ball.pending_kick=false; game.last_kicker=8
	var received: bool=game.first_touch.receive(9,false)
	return {"received":received,"opening":p.ball_actions.receive_distance,"error":p.ball_actions.receive_error}

func miss_trial(ability: int) -> float:
	setup(); player(14,Vector3.ZERO); player(9,Vector3(3,0,-2)); possession(9)
	attributes(14,ability)
	game.duels.standing_tackle(14); game.players[14].step(.13); game.duels.resolve(.13)
	check(game.last_kicker!=14,"Even the best defender cannot reach a ball outside his physical challenge")
	return game.players[14].tackle_recovery

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-player-ability.cfg"
	for index in [9,20]:
		var ordinary: float=await pass_trial(index,50,false)
		var weak: float=await pass_trial(index,50,true)
		var elite: float=await pass_trial(index,90,true)
		print("PASS ABILITY team=",game.players[index].team," ordinary=",ordinary," weak=",weak," elite=",elite)
		check(ordinary<.02,"An unpressured ordinary pass respects the requested direction, team %d" % game.players[index].team)
		check(weak>.15 and elite<weak*.2,"A talented passer is substantially more accurate under identical pressure, team %d" % game.players[index].team)
	var weak_touch:=first_touch_trial(50)
	var elite_touch:=first_touch_trial(90)
	check(weak_touch.received and elite_touch.received,"Both players can control an ordinary reachable pass")
	check(weak_touch.opening>elite_touch.opening*1.5 and weak_touch.error>elite_touch.error,"The technician exposes less ball with a visibly shorter first touch")
	var weak_miss:=miss_trial(50)
	var elite_miss:=miss_trial(90)
	check(weak_miss>elite_miss*1.35 and elite_miss>=.42,"Defensive quality improves recovery but a mistimed elite tackle is still punishable")
	setup(Vector3(0,0,30)); player(9,Vector3(.9,0,30))
	var shot_errors: Array=[]; var shot_speeds: Array=[]
	for ability in [50,90]:
		attributes(20,ability)
		var aim:=Vector3.BACK
		var shot: Vector3=game.shot_velocity(aim,.85,false,false,20)
		game.players[20].strike_effort=.85
		game.commit_strike(20,shot,0,false,"shot")
		var outcome: Dictionary=game.strike_quality.last
		shot_errors.append(float(outcome.limit)); shot_speeds.append(shot.length())
		check(outcome.intended.is_equal_approx(shot) and game.ball.kick_velocity.is_equal_approx(outcome.velocity),"The released shot is its preview plus the recorded contact error at ability %d" % ability)
		var advanced: Vector3=game.finishing.velocity(20,aim,.85,"power")
		check(is_equal_approx(advanced.x/advanced.z,shot.x/shot.z),"Power shots use the same finishing precision at ability %d" % ability)
	check(shot_errors[0]>shot_errors[1]*3 and shot_speeds[1]>shot_speeds[0]*1.2,"A skilled finisher delivers a faster, more accurate shot under pressure")
	# Complete a real transfer, reload the career, and start its next fixture.
	var c=game.career; c.save_root="/tmp/sefc-talent-transfer"
	DirAccess.make_dir_recursive_absolute(c.save_root)
	check(c.new_career("c18",1),"Creates a separate lower-league career for the transfer trial")
	var candidates: Array=c.world.players.values().filter(func(p): return p.role==2 and p.club!="c18" and World.ovr(p)>=85)
	candidates.sort_custom(func(a,b): return a.attributes.passing>b.attributes.passing)
	var signing: Dictionary=candidates[0]
	var original: Dictionary=signing.duplicate(true)
	var replaced: Dictionary=c.player(c.club().lineup[5]).duplicate(true)
	c.club().cash=40000000; c.club().budget=40000000
	check(c.transfer(signing.id,c.world.user,World.value(signing)*2,signing.wage*2,3,2,""),"A rare elite midfielder can be signed through the real transfer operation")
	c.club().lineup[5]=signing.id
	check(c.save() and c.load_slot(1),"The completed transfer survives a real career save and reload")
	check(c.player(signing.id).attributes==original.attributes and c.player(signing.id).talent_version==original.talent_version,"Changing clubs and reloading never rerolls the signing's ability")
	c.world.date=c.next_fixture().day
	check(c.prepare_match(),"The transferred player enters the career's actual match roster")
	var live=game.players[5]
	check(live.career_id==signing.id and live.attributes==original.attributes,"The on-pitch player has the signing's exact attributes")
	check(live.attributes.passing>replaced.attributes.passing+20 and World.ovr(original)>World.ovr(replaced)+20,"A quality transfer produces a substantial upgrade over the replaced midfielder")
	live.active_sprint=true
	var new_speed: float=live.movement_speed()
	live.attributes=replaced.attributes.duplicate(true)
	var old_speed: float=live.movement_speed()
	print("TRANSFER PACE old=",replaced.attributes.pace," new=",original.attributes.pace," speed=",old_speed," -> ",new_speed)
	check(new_speed>old_speed*1.04,"The faster signing increases actual sprint speed by more than four percent in the same match slot")
	live.attributes=original.attributes.duplicate(true)
	print("PLAYER ABILITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
