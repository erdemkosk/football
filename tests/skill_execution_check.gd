extends "res://tests/advanced_play_check.gd"

func fixture(stars: int,owner: int=9) -> void:
	await reset(owner)
	p.attributes.skill_moves=stars
	p.attributes.control=76; p.attributes.balance=76
	p.facing=Vector3(0,0,game.attack_sign(p.team))
	p.rig.rotation.y=atan2(-p.facing.x,-p.facing.z)
	game.last_direction=p.facing; game.last_touch=p.team
	game.ball.place(p.position+p.facing*.6+Vector3.UP*game.ball.GROUND_HEIGHT)
	await physics_frame; await physics_frame

func execute(kind: String,stars: int) -> Dictionary:
	await fixture(stars)
	var before: Vector3=game.ball.position
	var started: bool=game.skills.start(9,kind)
	check(started and game.ball.position==before,"%d-star %s starts without teleporting the ball" % [stars,kind])
	if not started: return {}
	var move: Dictionary=game.skills.active[9]
	var first_contact := -1.0
	var age := 0.0
	var peak := 0.0
	var lean := 0.0
	var moved := 0.0
	var physical := true
	while game.skills.active.has(9) and age<2.0:
		var position: Vector3=p.position
		await tick(); age+=DT
		peak=maxf(peak,game.ball.position.y)
		lean=maxf(lean,absf(p.spine.rotation.z))
		moved=maxf(moved,game.flat_distance(before,game.ball.position))
		physical=physical and p.position.distance_to(position)<.15
		if move.get("contacts",0)>0 and first_contact<0: first_contact=age
	var grounded: bool=kind in game.skills.Ground.KINDS
	var lifted: bool=kind in ["rainbow","heel","flick"]
	check((move.age>=move.duration or (lifted and move.lifted)) and moved>.12 and physical,"%d-star %s follows through with physical movement" % [stars,kind])
	if grounded:
		check(move.contacts==(2 if kind=="stop_go" else 1) and move.get("hit_gap",INF)<=.34,"%d-star %s still requires its actual boot contacts" % [stars,kind])
	if lifted or kind=="scoop":
		# A heel touch is intentionally a small hop, not a rainbow-height lob.
		var lift_floor: float=game.ball.GROUND_HEIGHT+.035 if kind=="heel" else .3
		check(peak>lift_floor,"%d-star %s still lifts the live ball" % [stars,kind])
	return {"time":age,"contact":first_contact,"gap":game.flat_distance(p.position,game.ball.position),"lean":lean,"cooldown":p.skill_cooldown,"completed":move.age>=move.duration}

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-skill-execution.cfg"
	# All ratings and both teams use the same unrestricted execution entry point.
	for owner in [9,20]:
		for stars in range(1,6):
			await fixture(stars,owner)
			var all_open := true
			for kind in game.skills.NAMES:
				p.skill_cooldown=0; p.energy=1
				all_open=game.skills.start(owner,kind) and all_open
				game.skills.reset()
			check(all_open,"Every special move is available: team=%d stars=%d" % [p.team,stars])
	var slow_results := {}
	var fast_results := {}
	for kind in game.skills.NAMES:
		slow_results[kind]=await execute(kind,1)
		fast_results[kind]=await execute(kind,5)
		var slow: Dictionary=slow_results[kind]
		var fast: Dictionary=fast_results[kind]
		if slow.is_empty() or fast.is_empty(): continue
		print("SKILL EXECUTION ",kind," one=",slow," five=",fast)
		check(fast.time<slow.time*.78,"Five-star %s finishes visibly sooner with identical core attributes" % kind)
		check(fast.cooldown<slow.cooldown*.7,"Five-star %s recovers sooner for the next input" % kind)
		if kind in ["roll","roulette","elastico","stop_go","ball_roll_cut"]:
			check(fast.gap<slow.gap*.96 and fast.lean<slow.lean*.85,"Five-star %s exits with a closer ball and less body lean" % kind)
		if kind in game.skills.Ground.KINDS:
			check(fast.contact>0 and fast.contact<slow.contact*.8,"Five-star %s reaches the contact sooner without skipping it" % kind)
	await fixture(1)
	key(KEY_3); key(KEY_3,false)
	check(game.skills.active.get(9,{}).get("kind","")=="elastico","Keyboard can start an elastico with one star")
	await fixture(1)
	game.controller.adopt_device(0,"Xbox Controller")
	# The actual gesture path also goes through the shared unrestricted start.
	game.advanced_controls.skill_gesture(p.facing.cross(Vector3.UP))
	game.advanced_controls.skill_gesture(-p.facing.cross(Vector3.UP))
	check(game.skills.active.get(9,{}).get("kind","")=="elastico","Controller can start an elastico with one star")
	await fixture(1); p.energy=.02
	check(not game.skills.start(9,"rainbow") and "KONDİSYON" in game.skills.notice,"Low energy still prevents an attempt")
	await fixture(1); game.ball.position+=Vector3(4,0,0)
	check(not game.skills.start(9,"spin"),"Unlocking moves does not grant control of an unreachable ball")
	await fixture(5); game.skills.start(9,"elastico")
	game.last_kicker=14; game.last_touch=1; game.carrier=14; game.dribbler=14
	game.skills.update(DT)
	check(game.skills.active.is_empty(),"Even five-star execution ends when the opponent wins possession")
	print("SKILL EXECUTION CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
