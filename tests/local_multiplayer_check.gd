extends SceneTree
## Two people on one machine: keyboard + controller in head-to-head and
## co-op, with separate movement, sprint, shooting and player selection.
const DT := 1.0/120
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func key(code: int,pressed: bool=true) -> void:
	var e := InputEventKey.new()
	e.keycode=code; e.physical_keycode=code; e.pressed=pressed
	Input.parse_input_event(e); Input.flush_buffered_events()

func pad_button(code: int,pressed: bool=true,device: int=0) -> void:
	var e := InputEventJoypadButton.new()
	e.device=device; e.button_index=code; e.pressed=pressed
	Input.parse_input_event(e); Input.flush_buffered_events()

func pad_axis(axis: int,value: float,device: int=0) -> void:
	var e := InputEventJoypadMotion.new()
	e.device=device; e.axis=axis; e.axis_value=value
	Input.parse_input_event(e); Input.flush_buffered_events()

func scene(mode: int) -> bool:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false); game.hud.hide()
	var ready: bool=game.humans.configure(mode,[0])
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.sliders.apply()
	game.state="playing"; game.menu_match.running=false
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	return ready

func show(index: int,at: Vector3) -> void:
	var p=game.players[index]
	p.visible=true; p.collision_layer=2; p.position=at; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	p.energy=1; p.match_fatigue=0

func tick(count: int=1) -> void:
	for n in range(count):
		game.humans.each(func(): game.human_step(DT))
		for p in game.players:
			if p.visible: p.step(DT)
		await physics_frame

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-local-multiplayer.cfg"
	check(not game.humans.configure(1,[99]) or game.humans.multiple(),"Configuration accepts an injected controller list")
	game.humans.release()
	# Head to head: P1 keyboard (team 0), P2 controller 0 (team 1).
	check(await scene(1),"A controller lets a second person join head to head")
	var hs=game.humans
	check(hs.multiple() and hs.team_of(1)==1 and int(hs.slots[1].device)==0,"P2 plays the other team with controller 0")
	var p1: int=hs.controlled_of(0)
	var p2: int=hs.controlled_of(1)
	check(game.players[p1].team==0 and game.players[p2].team==1,"Each person starts on a player of their own team")
	check(game.is_user_player(p1) and game.is_user_player(p2) and not game.autonomous_kicks(1),"Both selected players are human, the second team no longer decides on its own")
	show(p1,Vector3(-6,0,0)); show(p2,Vector3(6,0,0))
	game.dribbler=-1; game.carrier=-1; game.last_touch=0
	# Movement stays with its own device.
	pad_axis(JOY_AXIS_LEFT_X,1.0)
	await tick(40)
	# Camera-relative input: measure how far each body travelled.
	check(game.players[p2].position.distance_to(Vector3(6,0,0))>.5 and game.players[p1].position.distance_to(Vector3(-6,0,0))<.05,"The controller moves only P2's player")
	pad_axis(JOY_AXIS_LEFT_X,0.0)
	await tick(90)
	var before2: Vector3=game.players[p2].position
	key(KEY_UP)
	await tick(40)
	key(KEY_UP,false)
	check(game.players[p1].position.distance_to(Vector3(-6,0,0))>.5 and game.players[p2].position.distance_to(before2)<.05,"The keyboard moves only P1's player")
	# Sprinting on the keyboard never makes P2 sprint.
	key(KEY_W); key(KEY_UP); pad_axis(JOY_AXIS_LEFT_X,1.0)
	await tick(30)
	check(game.players[p1].sprinting and not game.players[p2].sprinting,"P1's sprint key belongs to P1 only")
	key(KEY_W,false); key(KEY_UP,false); pad_axis(JOY_AXIS_LEFT_X,0.0)
	await tick(20)
	# P2 shoots with the controller while P1 stays neutral.
	var shooter=game.players[p2]
	shooter.velocity=Vector3.ZERO
	game.ball.place(shooter.position+Vector3(0,game.ball.GROUND_HEIGHT,game.attack_sign(1)*.6)); await physics_frame; await physics_frame
	game.ball.position=shooter.position+Vector3(0,game.ball.GROUND_HEIGHT,game.attack_sign(1)*.6)
	game.dribbler=p2; game.carrier=p2; game.last_touch=1; game.last_kicker=p2; game.kick_lock=0
	pad_button(JOY_BUTTON_X,true)
	await tick(20)
	check(bool(hs.slots[1].state.charging) and not game.charging,"P2's shot charge lives in P2's slot")
	pad_button(JOY_BUTTON_X,false)
	await tick(2)
	check(game.last_kicker==p2 and game.shots[1]>=1,"P2's controller releases a real shot")
	# Co-op: both people on team 0, never on the same player.
	check(await scene(2),"Two people can play on the same side")
	p1=hs.controlled_of(0); p2=hs.controlled_of(1)
	check(game.players[p1].team==0 and game.players[p2].team==0 and p1!=p2,"Co-op starts on two different players")
	hs.activate(1)
	check(not game.team_control.eligible(p1),"A teammate's current player cannot be selected by the other person")
	hs.activate(0)
	# Back to one person.
	hs.release()
	check(not hs.multiple() and game.keys_enabled and not game.controller.locked,"Leaving restores the single-person controls")
	hs.preferred=1; game.match_menu.save_settings(); hs.preferred=0; game.match_menu.load_settings()
	check(hs.preferred==1,"The chosen player mode is remembered")
	hs.preferred=0; game.match_menu.save_settings()
	print("LOCAL MULTIPLAYER CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
