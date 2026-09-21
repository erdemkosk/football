extends Node3D
const Player = preload("res://scripts/footballer.gd")
const Ball = preload("res://scripts/ball.gd")
const Stadium = preload("res://scripts/stadium.gd")
const HUD = preload("res://scripts/hud.gd")
const Audio = preload("res://scripts/audio.gd")
const Passing = preload("res://scripts/passing.gd")
const SetPieces = preload("res://scripts/set_pieces.gd")
const Rules = preload("res://scripts/football_rules.gd")
const Weather = preload("res://scripts/weather.gd")
const Ceremony = preload("res://scripts/ceremony.gd")
const ImpactFeedback = preload("res://scripts/impact_feedback.gd")
const Referees = preload("res://scripts/referees.gd")
const GoalCelebration = preload("res://scripts/goal_celebration.gd")
var celebration := GoalCelebration.new()
const SupportPlay = preload("res://scripts/support_play.gd")
const Duels = preload("res://scripts/duels.gd")
const Goalkeeping = preload("res://scripts/goalkeeping.gd")
var support := SupportPlay.new()
var duels := Duels.new()
var goalkeeping := Goalkeeping.new()
var referees := Referees.new()
const SendOff = preload("res://scripts/send_off.gd")
var send_off := SendOff.new()
var feedback := ImpactFeedback.new()
var ceremony := Ceremony.new()
var weather: Node3D
var set_pieces := SetPieces.new()
var rules := Rules.new()
const Management = preload("res://scripts/match_management.gd")
const MatchMenu = preload("res://scripts/match_menu.gd")
const Clubs = preload("res://scripts/club_catalog.gd")
const Frontend = preload("res://scripts/match_frontend.gd")
const MenuMatch = preload("res://scripts/menu_match.gd")
var menu_match := MenuMatch.new()
const ControlsHelp = preload("res://scripts/controls_help.gd")
var controls_help: Control
var clubs := Clubs.new()
var frontend: Control
const Replay = preload("res://scripts/match_replay.gd")
const MatchCamera = preload("res://scripts/match_camera.gd")
var match_camera := MatchCamera.new()
var management := Management.new()
var match_menu: Control
var replay := Replay.new()
const LENGTH := 240.0
const HalfTime = preload("res://scripts/half_time.gd")
const PerformanceHUD = preload("res://scripts/performance_hud.gd")
const Gamepad = preload("res://scripts/gamepad.gd")
var controller := Gamepad.new()
var interval := HalfTime.new()
var half := 1
var performance_hud: Control
const SHOT_AIM_RATE := 0.34906585 # 20 degrees per second.
const SHOT_AIM_LIMIT := 0.24434610 # 14 degrees either side of the starting aim.
const SHOT_MOUSE_RATE := 1.57079633 # 90 degrees per second.
const SHOT_PAD_RATE := 5.23598776 # Full deflection turns up to 300 degrees/second.
const FINESSE_CURVE := 1.65
const PASS_CHARGE_TIME := 0.65
const PASS_TURN_RATE := 3.14159265
var pass_charging := false
var pass_power := 0.0
var pass_direction := Vector3.FORWARD
var pass_preview: Dictionary = {}
var pass_risk := 0.0
var players: Array = []
var ball: RigidBody3D
var stadium: Node3D
var camera := Camera3D.new()
var hud: Control
var audio: Node
var state := "menu"
var ending_reason := ""
var before_pause := "playing"
var score := [0,0]
var shots := [0,0]
var saves := [0,0]
var passes := [0,0]
var possession := [0.0,0.0]
var controlled := 9
var carrier := -1
var dribbler := -1
var dribble_direction := Vector3.FORWARD
var last_touch := 0
var last_kicker := -1
var kick_lock := 0.0
var match_time := 0.0
var elapsed := 0.0
var charge := 0.0
var charging := false
var last_direction := Vector3.FORWARD
var shot_anchor := Vector3.FORWARD
var shot_direction := Vector3.FORWARD
var shot_offset := 0.0
var shot_mouse_aim := false
var shot_separate_aim := false
var shot_finesse := false
var shot_chip := false
var shot_curve := 0.0
var camera_focus := Vector3.ZERO
var zoom := 49.0
var tactical: bool:
	get:
		return match_camera.is_tactical()
	set(value):
		match_camera.select("tactical" if value else "sideline")
var player_lock := false
const TeamControl = preload("res://scripts/team_control.gd")
var team_control := TeamControl.new()
var pass_assistance := 1
var pass_through := false
var pass_lob := false
var request_through := false
var training := false
var restart_timer := 0.0
var restart_team := 0
var restart_type := ""
var restart_point := Vector3.ZERO
var goal_team := 0
var toast := ""
var toast_timer := 0.0
var previous_ball := Vector3.ZERO
var boundary_grace := 0.0
var camera_shake := 0.0
var rng := RandomNumberGenerator.new()
var aiming_mouse := false
var practice_goals := 0
var foul_cooldown := 0.0
var requested_receiver := -1
var request_time := 0.0
var request_age := 0.0
var request_lob := false
var request_cooldown := 0.0
var incoming_receiver := -1
var incoming_time := 0.0
var ai_receivers := [-1,-1]
var ai_pass_time := [0.0,0.0]
var possession_player := -1

func attack_sign(team: int) -> float:
	return (-1.0 if team==0 else 1.0)*(1.0 if half==1 else -1.0)

func team_name(side: int) -> String:
	return clubs.data(side).name

func _ready() -> void:
	menu_match.game=self
	team_control.game=self
	clubs.game=self
	management.game=self
	replay.game=self
	interval.game=self
	support.game=self
	duels.game=self
	goalkeeping.game=self
	celebration.game=self
	referees.game=self
	send_off.game=self
	feedback.game=self
	ceremony.game=self
	match_camera.game=self
	set_pieces.game = self
	rules.game = self
	rng.seed = 614
	stadium = Stadium.new()
	add_child(stadium)
	make_teams()
	ball = Ball.new()
	ball.goal_nets = stadium.nets
	ball.name = "PhysicalFootball"
	add_child(ball)
	ball.position = Vector3(0,0.3,-1)
	ball.active = false
	weather=Weather.new()
	weather.game=self
	add_child(weather)
	ball.surface=weather
	for p in players: p.surface=weather
	if "--rain" in OS.get_cmdline_user_args(): weather.select(2,true)
	if "--night" in OS.get_cmdline_user_args(): stadium.light_rig.select(1)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.near = 0.2
	camera.far = 800
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0,70,37)
	camera.look_at(Vector3.ZERO)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = HUD.new()
	hud.game = self
	canvas.add_child(hud)
	performance_hud=PerformanceHUD.new()
	canvas.add_child(performance_hud)
	audio = Audio.new()
	add_child(audio)
	stadium.atmosphere_event.connect(audio.react)
	referees.build()
	ceremony.officials=referees.actors
	reset_positions(0)
	controller.game=self
	add_child(controller)
	management.setup()
	clubs.apply()
	replay.setup()
	frontend=Frontend.new()
	frontend.game=self
	canvas.add_child(frontend)
	match_menu=MatchMenu.new()
	match_menu.game=self
	canvas.add_child(match_menu)
	controls_help=ControlsHelp.new()
	controls_help.game=self
	canvas.add_child(controls_help)
	start_match(false,false,true)
	set_physics_process(true)

func make_teams() -> void:
	var formation = [Vector2(0,46),Vector2(-23,28),Vector2(-8,31),Vector2(8,31),Vector2(23,28),Vector2(-20,7),Vector2(-6,13),Vector2(9,10),Vector2(22,5),Vector2(-5,-1),Vector2(9,-7)]
	var names = ["DENİZ","KAAN","DEMİR","CAN","EMİR","ARAS","MERT","ALP","KEREM","EGE","BORA"]
	for team in range(2):
		for i in range(11):
			var p = Player.new()
			p.team = team
			p.number = i+1
			p.keeper = i==0
			p.display_name = names[i] if team==0 else ["MARC","LUCA","IVAN","ALEX","THEO","RAFA","OMAR","LEO","NICO","ENZO","SAM"][i]
			p.home = Vector3(formation[i].x,0,formation[i].y)*(1 if team==0 else -1)
			p.position = p.home
			p.facing = Vector3.FORWARD if team==0 else Vector3.BACK
			players.append(p)
			add_child(p)

func start_match(practice: bool = false,show_ceremony: bool = true,background: bool = false) -> void:
	send_off.reset()
	controller.clear_shot_aim()
	menu_match.phase="playing"
	audio.background=background
	replay.reset()
	interval.reset()
	management.reset()
	rules.advantage.clear()
	rules.deferred_cards.clear()
	celebration.clear()
	feedback.reset()
	ceremony.clear()
	set_pieces.clear()
	rules.reset()
	rules.card_time=0
	training = practice
	audio.start_match(not practice and not background)
	weather.reset_match()
	ending_reason=""
	stadium.crowd.reset()
	stadium.sidelines.reset()
	score = [0,0]
	shots = [0,0]
	saves = [0,0]
	passes = [0,0]
	possession = [0.0,0.0]
	match_time = 0
	practice_goals = 0
	charging = false
	charge = 0
	shot_finesse = false
	shot_chip = false
	charge = 0
	player_lock = false
	team_control.reset()
	state = "playing"
	reset_positions(0)
	for p in players:
		p.reset_stamina()
		p.tackle_cooldown=0
		p.yellow_cards=0
		p.fouls_committed=0
		p.dismissed=false
		p.visible = not practice or (p.team==0 and p.number==10) or (p.team==1 and p.keeper)
		p.collision_layer = 2 if p.visible else 0
	referees.reset(not practice)
	if practice: reset_practice()
	ball.active = true
	ball.freeze=false
	if background:
		state="menu"
		toast=""
		toast_timer=0
		for p in players: p.chosen=false; p.marker.visible=false
		return
	match_camera.reset()
	camera.size = zoom
	camera_focus = Vector3(0,0,-30 if practice else 0)
	update_camera(0)
	if not practice and show_ceremony:
		ceremony.begin()
		ceremony.update_camera(0)
	else:
		referees.whistle()
		announce("ANTRENMAN  ·  KALE SENİN" if practice else "İLK DÜDÜK  ·  HÜCUM YÖNÜ ↑")

func reset_positions(team: int) -> void:
	controller.combos.cancel()
	support.reset()
	duels.reset()
	goalkeeping.reset()
	dribbler=-1
	celebration.clear()
	referees.clear_decision()
	set_pieces.clear()
	rules.reset()
	possession_player = -1
	clear_pass_request()
	ai_receivers = [-1,-1]
	ai_pass_time = [0.0,0.0]
	for p in players:
		p.position = p.home
		p.velocity = Vector3.ZERO
		p.desired = Vector3.ZERO
		p.facing = Vector3.FORWARD if p.team==0 else Vector3.BACK
		p.rig.rotation = Vector3(0,0 if p.team==0 else PI,0)
		p.action_timer = 0
		p.touch_cooldown = 0
		p.kick_timer = 0
		p.shot_preparation=0
		p.wrapping=0
		p.pose = "run"
		p.last_horizontal = Vector3.ZERO
		p.acceleration_lean = Vector3.ZERO
		p.locomotion.reset()
		p.body_language.reset(p)
		p.animate(1.0)
		p.ai_think = 0
		# Every player begins in their own half except the kickoff taker.
		p.position.z = maxf(p.position.z,2.5) if p.team==0 else minf(p.position.z,-2.5)
	controlled = 9
	players[9 if team==0 else 20].position = Vector3(0,0,0.8 if team==0 else -0.8)
	players[10 if team==0 else 21].position = Vector3(5,0,2 if team==0 else -2)
	last_touch = team
	last_kicker = -1
	last_direction = Vector3.FORWARD
	for p in players:
		if p.team!=team and flat_distance(p.position,Vector3.ZERO)<9.15:
			p.position=p.position.normalized()*9.3
	ball.place(Vector3(0,0.23,0))
	carrier = -1
	kick_lock = 0.3
	boundary_grace = 0.5
	previous_ball = Vector3(0,0.23,0)
	camera_focus = Vector3.ZERO

func reset_practice() -> void:
	controller.combos.cancel()
	support.reset()
	duels.reset()
	goalkeeping.reset()
	dribbler=-1
	possession_player = -1
	clear_pass_request()
	ai_receivers = [-1,-1]
	ai_pass_time = [0.0,0.0]
	players[9].position = Vector3(0,0,-25)
	players[9].velocity = Vector3.ZERO
	players[9].facing = Vector3.FORWARD
	players[11].position = Vector3(0,0,-47.5)
	for index in [9,11]:
		var p = players[index]
		p.reset_stamina()
		p.velocity = Vector3.ZERO
		p.desired = Vector3.ZERO
		p.action_timer = 0
		p.tackle_cooldown = 0
		p.touch_cooldown = 0
		p.kick_timer = 0
		p.shot_preparation=0
		p.pose = "run"
		p.last_horizontal = Vector3.ZERO
		p.acceleration_lean = Vector3.ZERO
		p.locomotion.reset()
		p.body_language.reset(p)
		p.animate(1.0)
	ball.place(Vector3(0,0.23,-26))
	previous_ball = Vector3(0,0.23,-26)
	boundary_grace = 0.5
	last_touch = 0
	last_kicker = -1
	controlled = 9
	camera_focus = Vector3(0,0,-29)

func announce(text: String) -> void:
	toast = text
	toast_timer = 2.8

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F1 and (not match_menu.visible or match_menu.capture_action<0):
		controller.using_gamepad=false
		controls_help.open_panel()
		get_viewport().set_input_as_handled()
		return
	if controller.menus.handle(event):
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventKey and event.pressed) or event is InputEventMouseButton:
		controller.using_gamepad=false
	if controls_help.visible:
		controls_help.handle(event)
		return
	if is_instance_valid(match_menu) and match_menu.visible:
		match_menu.handle(event)
		return
	if is_instance_valid(frontend) and frontend.visible:
		frontend.handle(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ENTER and state in ["menu","paused","finished","halftime","ceremony","replay"]:
		hud.sync_navigation()
		controller.menus.activate()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and is_instance_valid(match_menu):
		var original: int=event.physical_keycode if event.physical_keycode else event.keycode
		if original in match_menu.keys:
			event=event.duplicate()
			event.keycode=match_menu.keys[original]
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		event=controller.translate(event)
		if event==null: return
	elif event is InputEventKey and event.pressed:
		controller.using_gamepad=false
	elif event is InputEventMouseButton:
		controller.using_gamepad=false
	if state=="replay" and event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER,KEY_SPACE]:
		replay.finish()
		return
	if state=="ceremony" and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
		ceremony.finish(true)
		return
	if state=="goal" and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
		celebration.skip()
		return
	if state=="restart" and restart_type=="SANTRA" and not training and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
		set_pieces.snap_ready()
		return
	if state=="set_piece": set_pieces.input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P: match_menu.open_menu()
			KEY_K:
				if state not in ["menu","finished","ceremony","replay"]: frontend.open_tactics()
			KEY_ENTER:
				if state in ["menu","finished"]:
					frontend.open_selection()
					get_viewport().set_input_as_handled()
				elif state=="paused": resume()
				elif state=="halftime": interval.finish()
			KEY_ESCAPE:
				if state=="paused": resume()
				elif state not in ["menu","finished"]:
					before_pause = state
					state = "paused"
					ball.freeze = true
					charging = false
					charge = 0
					cancel_pass()
					goalkeeping.stop_rush()
					set_pieces.button=0
					set_pieces.power=0
			KEY_T:
				if state in ["menu","finished"]: start_match(true)
			KEY_F2:
				if state in ["menu","finished"]:
					start_match(false,false)
					begin_restart("SERBEST VURUŞ",0,Vector3(-8,0,-25))
			KEY_R:
				if training and state=="playing": reset_practice()
				elif state in ["paused","finished"]:
					ball.freeze = false
					frontend.open_selection()
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_C: match_camera.cycle()
			KEY_M: audio.toggle()
			KEY_H:
				weather.select((weather.preset+1)%3,state=="menu")
				announce("HAVA · "+weather.label())
			KEY_TAB:
				player_lock = not player_lock
				announce("YILDIZ MODU · TEK OYUNCU" if player_lock else "TAKIM KONTROLÜ")
			KEY_Q:
				if state=="playing" and not charging: switch_player()
			KEY_S:
				if state=="playing": begin_pass()
			KEY_A:
				if state=="playing": pass_ball(true)
			KEY_Y:
				if state=="playing":
					if goalkeeping.can_call(): goalkeeping.start_rush()
					else: begin_pass(true)
			KEY_Z:
				if state=="playing": duels.feint(controlled)
			KEY_V:
				if state=="playing": duels.push_ahead(controlled)
			KEY_F: performance_hud.visible=not performance_hud.visible
			KEY_G:
				if state=="playing":
					cancel_pass()
					charging=false; charge=0
					players[controlled].shot_preparation=0
					duels.standing_tackle(controlled)
			KEY_X:
				if state=="playing": tackle()
			KEY_D:
				if state=="playing":
					if can_touch(controlled,1.8): begin_shot()
	if event is InputEventKey and not event.pressed and event.keycode==KEY_D and charging:
		shoot()
	if event is InputEventKey and not event.pressed and event.keycode==KEY_Y:
		goalkeeping.stop_rush()
	if event is InputEventKey and not event.pressed and event.keycode==(KEY_Y if pass_through else KEY_S) and pass_charging and not pass_lob:
		release_pass()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom = clampf(zoom-3,34,76)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom = clampf(zoom+3,34,76)
		if event.button_index==MOUSE_BUTTON_RIGHT: aiming_mouse = event.pressed
		if event.button_index==MOUSE_BUTTON_LEFT and state=="playing":
			if event.pressed and can_touch(controlled,1.8): aiming_mouse = true; begin_shot(true)
			elif not event.pressed and charging: shoot(); aiming_mouse = false

func resume() -> void:
	state = before_pause
	ball.freeze = state=="replay"

func return_menu() -> void:
	start_match(false,false,true)

func _process(delta: float) -> void:
	elapsed += delta
	toast_timer = maxf(0,toast_timer-delta)
	update_camera(delta)
	hud.queue_redraw()
	stadium.architecture.update_score(score,match_time,LENGTH)
	stadium.architecture.district.update_traffic(0.0 if state=="paused" else delta,state in ["menu","setup"] or (state=="paused" and before_pause in ["menu","setup"]))
	if state!="paused":
		rules.card_time=maxf(0,rules.card_time-delta)
		stadium.crowd.home_attack=attack_sign(0)
		var playing: bool=state=="playing" or (state=="menu" and menu_match.phase=="playing")
		stadium.crowd.update(delta,ball.position,ball.linear_velocity,last_touch,playing,not training and match_time>LENGTH*0.7 and abs(score[0]-score[1])<=1)
		stadium.sidelines.update(delta,ball.position,ball.linear_velocity,last_touch,playing)

func update_camera(delta: float) -> void:
	if state=="replay" or (state=="paused" and before_pause=="replay"): return
	if not training and not tactical and celebration.age>=1.15 and (state=="goal" or (state=="paused" and before_pause=="goal")):
		celebration.update_camera(0 if state=="paused" else delta)
		return
	if state=="ceremony" or (state=="paused" and before_pause=="ceremony"):
		ceremony.update_camera(0 if state=="paused" else delta)
		return
	if state=="menu" or state=="setup" or (state=="paused" and before_pause in ["menu","setup"]):
		var center = Vector3(-26,0,22)
		var angle = 0.86+sin(elapsed*0.035)*0.055
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 230
		camera.position = center+Vector3(cos(angle)*190,144,sin(angle)*190)
		camera.look_at(center)
		return
	if send_off.update_camera(delta): return
	var focus: Vector3 = ball.position
	if state=="playing": focus = ball.position.lerp(players[controlled].position,0.26)
	if state in ["restart","set_piece"] and set_pieces.recovery.phase in ["arrange","ready"] and restart_type in ["SERBEST VURUŞ","ENDİREKT VURUŞ","PENALTI","KORNER"]:
		var goal = Vector3(0,0,attack_sign(restart_team)*50)
		if restart_point.distance_to(goal)<45: focus=restart_point.lerp(goal,0.42)
	focus.y = 0
	if tactical: focus = Vector3.ZERO
	else:
		focus.x = clampf(focus.x*0.42,-8,8)
		var extent := 45.0 if state=="restart" and set_pieces.recovery.phase not in ["arrange","ready"] else 35.0
		focus.z = clampf(focus.z,-extent,extent)
	if match_camera.snap or delta<=0.0: camera_focus=focus
	else: camera_focus=camera_focus.lerp(focus,1-exp(-delta*3.7))
	var view_zoom := zoom
	if not tactical:
		if state in ["restart","set_piece"]: view_zoom=maxf(zoom,57)
		if state=="goal": view_zoom=maxf(zoom,61.0)
	var pose: Dictionary=match_camera.apply(camera_focus,view_zoom,delta)
	camera.position = pose.eye
	if camera_shake>0:
		camera.position.x += sin(elapsed*63)*camera_shake
		camera_shake = maxf(0,camera_shake-delta*1.8)
	var contact_offset := feedback.offset()
	camera.position+=contact_offset
	camera.look_at(pose.look+contact_offset)

func _physics_process(delta: float) -> void:
	controller.combos.update(delta)
	if state!="playing" and goalkeeping.rush_requested: goalkeeping.stop_rush()
	audio.update_atmosphere(delta,state)
	weather.sound.stream_paused=state=="paused"
	for channel in audio.contacts: channel.stream_paused=state=="paused"
	if state=="menu": menu_match.update(delta)
	else: simulate_match(delta)

func simulate_match(delta: float) -> void:
	if state not in ["playing","paused","replay"]:
		for p in players: p.body_language.clear_intent()
	if state not in ["paused","replay"]:
		weather.update(delta)
		feedback.update(delta)
		referees.update(delta)
	management.update_clock(delta)
	if send_off.update(delta): return
	if state in ["restart","halftime"] and management.update_substitutions(delta): return
	if state=="replay":
		replay.update(delta)
	elif state=="ceremony":
		ceremony.update(delta)
	elif state=="halftime":
		interval.update(delta)
	elif state=="playing":
		match_time += delta
		if not training and half==1 and match_time>=management.half_end():
			interval.begin()
			return
		if not training and half==2 and match_time>=management.half_end():
			match_time=LENGTH
			state = "finished"
			ball.active = false
			referees.finish_match()
			return
		kick_lock = maxf(0,kick_lock-delta)
		boundary_grace = maxf(0,boundary_grace-delta)
		foul_cooldown = maxf(0,foul_cooldown-delta)
		rules.update(delta)
		if state!="playing": return
		if not menu_match.running:
			team_control.update(delta)
			update_control(delta)
		else:
			for p in players:
				p.shot_preparation=0
				p.wrapping=0
				p.protecting=false
				p.jockeying=false
		update_pass_request(delta)
		update_ai(delta)
		if state!="playing": return
		for i in range(players.size()): players[i].body_language.observe(self,i)
		for i in range(players.size()):
			var p = players[i]
			p.chosen = is_user_player(i)
			if p.visible:
				p.step(delta)
				p.position.x = clampf(p.position.x,-34,34)
				p.position.z = clampf(p.position.z,-51,51)
		duels.resolve(delta)
		if state!="playing": return
		rules.resolve_tackles()
		if state!="playing": return
		update_contacts(delta)
		if state!="playing": return
		if not menu_match.running: replay.capture(delta)
		check_boundaries()
		previous_ball = ball.position
	elif state=="restart":
		if not training:
			set_pieces.recovery.step(delta)
		else:
			restart_timer-=delta
			if restart_timer<=0:
				reset_practice()
				state="playing"
				ball.active=true
	elif state=="set_piece":
		set_pieces.update(delta)
	elif state=="goal":
		if training:
			restart_timer -= delta
			for p in players:
				p.desired=Vector3.ZERO
				if p.visible: p.step(delta)
			if restart_timer<=0:
				reset_practice()
				state="playing"
				ball.active=true
		else:
			celebration.update(delta)
			if state=="goal" and not menu_match.running: replay.capture_goal(delta)

func is_user_player(index: int) -> bool:
	return index==controlled and not menu_match.running

func autonomous_kicks(team: int) -> bool:
	# Teammates still defend and make runs; possession decisions belong to the user.
	return team!=0 or menu_match.running

func raw_move() -> Vector3:
	var keyboard := Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
	return keyboard.normalized() if keyboard.length_squared()>0 else controller.movement()

func movement_input() -> Vector3:
	return match_camera.orient(raw_move())

func steering_input() -> float:
	var move: Vector3=movement_input()
	if move.length_squared()<0.0001: return 0.0
	return clampf(move.dot(match_camera.ground_right()),-1,1)

func update_control(delta: float) -> void:
	for p in players: p.shot_preparation=0; p.wrapping=0
	var movement = movement_input()
	players[controlled].desired = movement*(0.62 if charging else (0.72 if pass_charging else 1.0))
	if movement.length()<0.01 and not charging and not pass_charging:
		players[controlled].desired=team_control.reception_direction()
	players[controlled].sprinting = Input.is_physical_key_pressed(match_menu.key_for(KEY_W)) or controller.action_held(KEY_W)
	for p in players: p.protecting=false; p.jockeying=false
	var user=players[controlled]
	if (Input.is_physical_key_pressed(match_menu.key_for(KEY_E)) or controller.action_held(KEY_E)) and not charging and not pass_charging and user.action_timer<=0:
		user.protecting=dribbler==controlled
		user.jockeying=not user.protecting
		user.sprinting=false
		user.desired*=0.45 if user.protecting else 0.58
		var facing: Vector3=duels.shield_direction(controlled) if user.protecting else (ball.position-user.position)*Vector3(1,0,1)
		if facing.length()>0.1: user.facing=facing.normalized()
	if movement.length()>0 and not charging and not pass_charging: last_direction = movement.normalized()
	if pass_charging:
		if not has_ball_control(controlled): cancel_pass()
		else:
			pass_power = minf(1,pass_power+delta/PASS_CHARGE_TIME)
			if movement.length()>0.1:
				var turn := pass_direction.signed_angle_to(movement,Vector3.UP)
				pass_direction = pass_direction.rotated(Vector3.UP,clampf(turn,-PASS_TURN_RATE*delta,PASS_TURN_RATE*delta))
			update_pass_preview()
	if charging:
		charge = minf(1,charge+delta*0.86)
		update_shot_aim(delta)
		shot_chip=chip_held()
		shot_finesse=finesse_held() and not shot_chip
		players[controlled].shot_preparation=0.15+charge*0.85
		players[controlled].wrapping=1.0 if shot_finesse else (0.35 if shot_chip else 0.0)
		players[controlled].facing=shot_direction
	if controller.combos.cross_player==controlled:
		players[controlled].shot_preparation=0.2+0.25*controller.combos.cross_age/controller.combos.DOUBLE_TAP_TIME
		players[controlled].facing=controller.combos.cross_direction
	if controlled==0 and (goalkeeping.is_rushing() or ball.held_by==players[0]):
		var keeper_target: Vector3=goalkeeping.update(0,delta)
		if ball.held_by!=players[0]:
			var offset: Vector3=(keeper_target-players[0].position)*Vector3(1,0,1)
			players[0].desired=offset.normalized()*clampf(offset.length()/1.4,0,1)

func pointer_direction(fallback: Vector3) -> Vector3:
	var mouse = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mouse)
	var ray = camera.project_ray_normal(mouse)
	var point: Variant = Plane(Vector3.UP,0).intersects_ray(origin,ray)
	if point != null:
		var direction: Vector3 = point-ball.position
		direction.y = 0
		# The direction is undefined over the ball; keep the previous aim there.
		if direction.length()>1.0: return direction.normalized()
	return fallback

func aim_direction() -> Vector3:
	if charging: return shot_direction
	return pointer_direction(last_direction) if aiming_mouse else last_direction

func assisted_shot_direction(direction: Vector3) -> Vector3:
	var toward_goal := Vector3(clampf(ball.position.x+direction.x*10,-3.0,3.0),0,attack_sign(0)*50)-ball.position
	toward_goal.y = 0
	if toward_goal.length()<0.1: return direction
	var assistance := smoothstep(0.35,0.95,direction.z*attack_sign(0))*0.36
	return direction.lerp(toward_goal.normalized(),assistance).normalized()

func begin_shot(use_mouse: bool = false) -> void:
	cancel_pass()
	if charging: return
	shot_mouse_aim = use_mouse or aiming_mouse
	shot_separate_aim = not shot_mouse_aim and controller.using_gamepad and controller.has_separate_aim()
	shot_anchor = pointer_direction(last_direction) if shot_mouse_aim else assisted_shot_direction(last_direction)
	if shot_separate_aim and controller.separate_aim().length()>0.01:
		shot_anchor=match_camera.orient(controller.separate_aim()).normalized()
	shot_direction = shot_anchor
	shot_offset = 0
	shot_finesse = false
	shot_chip = false
	shot_curve = choose_finesse_curve(shot_anchor)
	charge = 0
	charging = true

func update_shot_aim(delta: float) -> void:
	if shot_mouse_aim:
		var target := pointer_direction(shot_direction)
		var turn := shot_direction.signed_angle_to(target,Vector3.UP)
		shot_direction = shot_direction.rotated(Vector3.UP,clampf(turn,-SHOT_MOUSE_RATE*delta,SHOT_MOUSE_RATE*delta)).normalized()
	elif controller.using_gamepad:
		# A separate aim gesture stays in charge until this shot ends. Releasing
		# it holds the aim instead of snapping back to the running direction.
		if controller.has_separate_aim(): shot_separate_aim=true
		var target: Vector3=match_camera.orient(controller.separate_aim() if shot_separate_aim else controller.movement())
		if target.length()>0.01:
			var turn := shot_direction.signed_angle_to(target.normalized(),Vector3.UP)
			if shot_direction.dot(target.normalized())< -0.9999:
				var toward_goal := shot_direction.cross(Vector3(0,0,attack_sign(0))).y
				if absf(toward_goal)>0.01: turn=signf(toward_goal)*PI
			# Small stick deflections are precise; a deliberate full deflection
			# can turn away from the original heading without an instant snap.
			var rate := lerpf(deg_to_rad(6),SHOT_PAD_RATE,pow(clampf(target.length(),0,1),3))
			shot_direction=shot_direction.rotated(Vector3.UP,clampf(turn,-rate*delta,rate*delta)).normalized()
			shot_offset=shot_anchor.signed_angle_to(shot_direction,Vector3.UP)
	else:
		var steering := steering_input()
		# Small taps make small corrections; releasing an arrow retains that aim.
		shot_offset = clampf(shot_offset-steering*SHOT_AIM_RATE*delta,-SHOT_AIM_LIMIT,SHOT_AIM_LIMIT)
		shot_direction = shot_anchor.rotated(Vector3.UP,shot_offset).normalized()

func can_touch(index: int,reach: float=1.3) -> bool:
	return players[index].visible and players[index].action_timer<=0 and flat_distance(players[index].position,ball.position)<reach and ball.position.y<1.05

func flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func switch_player() -> void:
	if training: return
	clear_pass_request()
	var best: int=duels.switch_choice()
	if best>=0: team_control.select(best,true)

func finesse_held() -> bool:
	if menu_match.running: return false
	return Input.is_physical_key_pressed(match_menu.key_for(KEY_E)) or controller.action_held(KEY_E)

func chip_held() -> bool:
	if menu_match.running: return false
	return Input.is_physical_key_pressed(match_menu.key_for(KEY_Q)) or controller.action_held(KEY_Q) or controller.combos.consumed.has(JOY_BUTTON_LEFT_SHOULDER)

func finesse_curve(aim: Vector3) -> float:
	return shot_curve if charging else choose_finesse_curve(aim)

func choose_finesse_curve(aim: Vector3) -> float:
	var heading := Vector3(aim.x,0,aim.z)
	if heading.length()<0.08: heading=Vector3(0,0,attack_sign(players[controlled].team))
	heading=heading.normalized()
	var side := ball.position.x
	if absf(side)<0.85: side=players[controlled].position.x-ball.position.x
	if absf(side)<0.08: side=heading.x
	if absf(side)<0.04: side=1.0
	var far_post := Vector3(-signf(side)*3.32,0,attack_sign(players[controlled].team)*50)
	var toward := (far_post-ball.position)*Vector3(1,0,1)
	if toward.length()<1.0: toward=Vector3(-signf(side),0,0)
	var turn := heading.signed_angle_to(toward.normalized(),Vector3.UP)
	if absf(turn)<0.012: turn=heading.signed_angle_to((heading+Vector3(-signf(side),0,0)).normalized(),Vector3.UP)
	if absf(turn)<0.012: return 0.0
	return -signf(turn)*FINESSE_CURVE

func shot_velocity(aim: Vector3,power: float,curl: bool,chip: bool=false) -> Vector3:
	if chip:
		return aim*lerpf(10.5,18.5,power)+Vector3.UP*lerpf(6.8,10.4,power)
	var speed := lerpf(19,32,power)*(0.92 if curl else 1.0)
	var lift := lerpf(1.6,5.1,power)*(1.08 if curl else 1.0)
	return aim*speed+Vector3.UP*lift

func shoot() -> void:
	if state=="playing" and (can_touch(controlled,2.0) or ball.held_by==players[controlled]):
		# Release uses exactly the previewed heading, with no last-frame aim correction.
		var aim := shot_direction if charging else (pointer_direction(last_direction) if aiming_mouse else assisted_shot_direction(last_direction))
		var chip := charging and (shot_chip or chip_held())
		var curl := charging and not chip and (shot_finesse or finesse_held())
		var curve := finesse_curve(aim) if curl else 0.0
		if strike(controlled,shot_velocity(aim,charge,curl,chip),curve,false,"shot"): shots[0] += 1
	players[controlled].shot_preparation=0
	players[controlled].wrapping=0
	charging = false
	charge = 0
	shot_finesse = false
	shot_chip = false

func strike(index: int,velocity: Vector3,curve: float=0,is_save: bool=false,kind: String="kick") -> bool:
	if not rules.before_touch(index,not is_save): return false
	if not is_save: rules.kicked(index)
	possession_player = -1
	dribbler=-1
	var from_hands: bool=ball.held_by==players[index]
	ball.strike(velocity,curve)
	if from_hands:
		goalkeeping.holding=-1
		goalkeeping.hold_age=0
		players[index].set_piece_pose=""
	last_touch = players[index].team
	last_kicker = index
	players[index].touch_cooldown = 0.38
	players[index].kick_power=clampf((velocity.length()-12)/20,0.15,1)
	if kind!="ball_tackle" and not is_save:
		players[index].begin_kick(players[index].kick_power,0.46 if kind=="shot" else 0.32)
	else: players[index].kick_timer=0
	players[index].shot_preparation=0
	if kind=="shot": players[index].facing=(velocity*Vector3(1,0,1)).normalized()
	players[index].ai_think = 0
	kick_lock = 0.16
	if kind in ["shot","ball_tackle"]:
		feedback.contact(kind,index,ball.position,velocity.normalized(),players[index].kick_power)
	else: audio.play("kick")
	var forward := attack_sign(last_touch)
	if kind=="shot":
		stadium.react("shot",last_touch,ball.position)
	elif velocity.z*forward>16 and ball.position.z*forward>18:
		var travel := (forward*50-ball.position.z)/velocity.z
		if absf(ball.position.x+velocity.x*travel)<7:
			stadium.react("shot",last_touch,ball.position)
	return true

func tackle_impact(index: int,victim: int,clean: bool=false) -> void:
	var attacker=players[index]
	var target=players[victim]
	var relative: float=(attacker.velocity-target.velocity).length()
	var strength := clampf(relative/17.0,0.35,1.0)*(0.48 if clean else 1.0)
	if dribbler==victim or dribbler==index: dribbler=-1
	target.receive_impact(attacker.facing,strength)
	attacker.velocity*=0.65 if clean else 0.42
	attacker.action_timer=minf(attacker.action_timer,0.3)
	feedback.contact("body_hit",index,target.position,attacker.facing,strength,victim)
	if victim==controlled:
		charging=false
		charge=0
		cancel_pass()
	stadium.react("tackle",attacker.team,target.position)

func best_pass(index: int,heading: Vector3=Vector3.ZERO) -> int:
	var p = players[index]
	var aim: Vector3 = aim_direction() if is_user_player(index) else Vector3(0,0,attack_sign(p.team))
	if heading.length_squared()>0.01: aim=heading
	var best = -1
	var highest = -INF
	for j in range(players.size()):
		var q = players[j]
		if j==index or q.team!=p.team or q.keeper or not q.visible: continue
		var offset: Vector3 = q.position-p.position
		var distance: float = offset.length()
		if distance<4 or distance>42: continue
		var pressure = 0.0
		for opponent in players:
			if opponent.team!=p.team:
				pressure += maxf(0,5-flat_distance(opponent.position,q.position))*1.7
		var route = Passing.plan(ball.position,q.position,q.velocity,false,weather)
		var interception = Passing.risk(ball.position,route,p.team,players)
		var value: float = aim.dot(offset.normalized())*18-distance*0.15-pressure-interception*19
		if value>highest: highest = value; best = j
	return best

func pass_ball(lob: bool) -> void:
	if not lob:
		begin_pass()
		release_pass()
		return
	cancel_pass()
	if state!="playing": return
	if not has_ball_control(controlled):
		call_for_pass(lob)
		return
	if kick_lock>0 and last_kicker>=0: return
	clear_pass_request()
	execute_player_pass(cross_plan(aim_direction()))
	charging = false
	charge = 0

func cancel_pass() -> void:
	controller.combos.cancel_cross()
	controller.combos.switch_pending=false
	pass_charging = false
	pass_through = false
	pass_lob = false
	pass_power = 0
	pass_preview = {}
	pass_risk = 0

func begin_pass(through: bool=false,lob: bool=false) -> void:
	if state!="playing" or (pass_charging and pass_through==through and pass_lob==lob): return
	if pass_charging: cancel_pass()
	if not has_ball_control(controlled):
		call_for_pass(false,through)
		return
	if kick_lock>0 and last_kicker>=0: return
	charging = false
	charge = 0
	pass_charging = true
	pass_through = through
	pass_lob = lob
	pass_power = 0
	pass_direction = last_direction
	update_pass_preview()

func update_pass_preview() -> void:
	if pass_lob:
		pass_preview=Passing.switch_plan(ball.position,pass_direction,pass_power,players[controlled].team,controlled,players,[0.0,0.65,1.0][pass_assistance],attack_sign(0),rules.offside_line(0),weather)
	else:
		pass_preview = Passing.assisted_plan(ball.position,pass_direction,pass_power,players[controlled].team,controlled,players,[0.0,0.65,1.0][pass_assistance],pass_through,attack_sign(0),rules.offside_line(0),weather)
	pass_risk = Passing.risk(ball.position,pass_preview,players[controlled].team,players)

func release_pass() -> void:
	if not pass_charging: return
	if state!="playing" or not has_ball_control(controlled):
		cancel_pass()
		return
	var route := pass_preview.duplicate()
	last_direction = pass_direction
	execute_player_pass(route)

func execute_player_pass(route: Dictionary,one_two: bool=false) -> bool:
	var passer := controlled
	clear_pass_request()
	if not strike(passer,route.velocity): return false
	hud.remember_pass(route,passer)
	passes[players[passer].team] += 1
	var hint: int=int(route.get("receiver",-1))
	if hint<0:
		var heading: Vector3=(route.velocity*Vector3(1,0,1)).normalized()
		var reach: float=Vector2(route.target.x-ball.position.x,route.target.z-ball.position.z).length()
		hint=Passing.hint_along(ball.position,heading,reach,players[passer].team,passer,players,16,10,route.get("through",false),attack_sign(players[passer].team),rules.offside_line(players[passer].team))
	if hint>=0:
		support.passed(passer,hint,one_two)
		ai_receivers[players[passer].team]=hint
		ai_pass_time[players[passer].team]=float(route.flight)+2.0
		team_control.follow_pass(hint,route)
		if one_two and not player_lock and not training: team_control.select(hint)
	return true

func one_two_pass() -> void:
	if state!="playing" or not has_ball_control(controlled) or (kick_lock>0 and last_kicker>=0): return
	var route := Passing.one_two_plan(ball.position,last_direction,players[controlled].team,controlled,players,attack_sign(0),rules.offside_line(0),weather)
	if route.is_empty():
		announce("VERKAÇ İÇİN YAKIN TAKIM ARKADAŞI YOK")
		return
	if execute_player_pass(route,true): announce("VERKAÇ · PASI VEREN İÇERİ KATIYOR")

func cross_plan(heading: Vector3,driven: bool=false) -> Dictionary:
	var aim := (heading*Vector3(1,0,1)).normalized()
	if aim.length()<0.1: aim=last_direction
	var reach := 30.0
	aim=Passing.nudge_heading(ball.position,aim,reach,players[controlled].team,controlled,players,[0.0,0.65,1.0][pass_assistance])
	var target: Vector3=ball.position+aim*reach
	target.y=0.23
	var route := Passing.driven_cross(ball.position,target,Vector3.ZERO,weather) if driven else Passing.plan(ball.position,target,Vector3.ZERO,true,weather)
	if not driven and route.velocity.length()<0.1:
		route.velocity=aim*16+Vector3.UP*7.5
		route.flight=1.5
	route.receiver=-1
	route.cross=true
	return route

func driven_cross() -> void:
	if state!="playing" or not has_ball_control(controlled) or (kick_lock>0 and last_kicker>=0): return
	var route := cross_plan(last_direction,true)
	charging=false; charge=0
	if execute_player_pass(route):
		controller.rumble(0.6)
		announce("YERDEN SERT ORTA")

func clear_pass_request() -> void:
	cancel_pass()
	requested_receiver = -1
	request_through = false
	request_time = 0
	request_age = 0
	incoming_receiver = -1
	incoming_time = 0
	request_cooldown = 0
	for p in players:
		p.call_timer = 0
		p.call_label.visible = false

func call_for_pass(lob: bool = false,through: bool=false) -> void:
	if request_cooldown>0: return
	if training:
		announce("ANTRENMANDA TAKIM ARKADAŞI YOK")
		return
	if incoming_receiver==controlled and incoming_time>0:
		announce("TOP SANA GELİYOR")
		return
	requested_receiver = controlled
	request_time = 3.2
	request_age = 0
	request_lob = lob
	request_through = through
	request_cooldown = 0.6
	players[controlled].call_timer = 3.2
	players[controlled].call_label.text = "ARA PAS!" if through else ("ORTA!" if lob else "PAS!")
	announce("KOŞU YOLUNA PAS İSTEDİN" if through else ("ORTA İSTEDİN · BOŞLUĞA KOŞ" if lob else "PAS İSTEDİN · BOŞLUĞA KOŞ"))

func nearest_to_ball(reach: float = 1.5) -> int:
	var nearest := -1
	var distance := reach
	if ball.position.y>1.05: return nearest
	for i in range(players.size()):
		if not players[i].visible: continue
		var gap := flat_distance(players[i].position,ball.position)
		if gap<distance: nearest=i; distance=gap
	return nearest

func has_ball_control(index: int) -> bool:
	if ball.held_by!=null: return ball.held_by==players[index]
	if not can_touch(index,1.8): return false
	if dribbler>=0 and dribbler!=index and can_touch(dribbler,1.65): return false
	var nearest := nearest_to_ball(1.8)
	return nearest==index or flat_distance(players[index].position,ball.position)<1.05

func update_pass_request(delta: float) -> void:
	for team in range(2):
		ai_pass_time[team] = maxf(0,ai_pass_time[team]-delta)
		if ai_pass_time[team]<=0 or last_touch!=team: ai_receivers[team]=-1
	var owner := nearest_to_ball()
	if owner>=0 and owner!=possession_player and ball.linear_velocity.length()<16:
		possession_player = owner
		players[owner].ai_think = 0
	if incoming_receiver>=0 and owner>=0 and players[owner].team!=players[incoming_receiver].team and ball.linear_velocity.length()<12:
		clear_pass_request()
		announce("PAS KESİLDİ · TOPU KAZAN")
	request_cooldown = maxf(0,request_cooldown-delta)
	incoming_time = maxf(0,incoming_time-delta)
	if incoming_time<=0: incoming_receiver=-1
	if requested_receiver<0: return
	request_time -= delta
	request_age += delta
	if owner>=0 and players[owner].team!=players[requested_receiver].team and ball.linear_velocity.length()<12:
		clear_pass_request()
		announce("TOP RAKİPTE · TOPU KAZAN")
		return
	if can_touch(requested_receiver,1.05):
		clear_pass_request()
		return
	if requested_receiver!=controlled or request_time<=0:
		clear_pass_request()
		announce("PAS YOLU AÇILMADI · YENİDEN BOŞA ÇIK")

func try_requested_pass(passer: int) -> bool:
	if requested_receiver<0 or request_age<0.23 or request_time<=0: return false
	var receiver := requested_receiver
	var p = players[passer]
	if passer==receiver or p.team!=players[receiver].team or p.action_timer>0: return false
	var keeper_holding: bool=ball.held_by==p
	if (not keeper_holding and (nearest_to_ball(1.4)!=passer or ball.linear_velocity.length()>13)) or kick_lock>0 or p.touch_cooldown>0: return false
	var distance := flat_distance(p.position,players[receiver].position)
	if distance<3 or distance>42: return false
	var lob := request_lob
	var route = Passing.through_to(ball.position,players[receiver],0.4,attack_sign(p.team),weather) if request_through else Passing.plan(ball.position,players[receiver].position,players[receiver].velocity,lob,weather)
	var danger = Passing.risk(ball.position,route,p.team,players)
	if not lob and not request_through and danger>0.48 and distance>9:
		var high_route = Passing.plan(ball.position,players[receiver].position,players[receiver].velocity,true,weather)
		if Passing.risk(ball.position,high_route,p.team,players)<danger:
			route=high_route
			lob=true
	if Passing.risk(ball.position,route,p.team,players)>0.48:
		if request_age>0.8 and request_age<0.8+1.0/60.0: announce("PAS YOLU KAPALI · BOŞA ÇIK")
		return false
	if not deliver_pass(passer,receiver,lob,request_through): return false
	requested_receiver = -1
	request_time = 0
	players[receiver].call_timer = 0.7
	incoming_receiver = receiver
	incoming_time = float(route.flight)+1.5
	p.desired = Vector3.ZERO
	announce("%s SANA %s" % [p.display_name,"ORTA AÇIYOR" if lob else "PAS ATIYOR"])
	return true

func deliver_pass(passer: int,receiver: int,lob: bool,through: bool=false) -> bool:
	var route = Passing.through_to(ball.position,players[receiver],0.4,attack_sign(players[passer].team),weather) if through else Passing.plan(ball.position,players[receiver].position,players[receiver].velocity,lob,weather)
	var error: float=management.pass_error(players[passer].team)
	var velocity: Vector3=route.velocity.rotated(Vector3.UP,rng.randf_range(-error,error))
	if not strike(passer,velocity): return false
	if players[passer].team==0 and not menu_match.running:
		var shown := route.duplicate()
		shown.velocity=velocity; shown.receiver=receiver
		hud.remember_pass(shown,passer)
	support.passed(passer,receiver)
	passes[players[passer].team] += 1
	ai_receivers[players[passer].team] = receiver
	ai_pass_time[players[passer].team] = float(route.flight)+2.0
	if players[passer].team==0:
		team_control.follow_pass(receiver,route)
		if not player_lock and not training: team_control.select(receiver)
	return true

func tackle() -> void:
	cancel_pass()
	charging=false
	charge=0
	players[controlled].shot_preparation=0
	rules.start_tackle(controlled,last_direction)

func update_ai(_delta: float) -> void:
	support.update(_delta)
	var nearest = [-1,-1]
	var distances = [INF,INF]
	for i in range(players.size()):
		var p = players[i]
		if not p.visible or p.keeper or is_user_player(i): continue
		var d = flat_distance(p.position,ball.position)
		if d<distances[p.team]: distances[p.team] = d; nearest[p.team] = i
	for i in range(players.size()):
		var p = players[i]
		if is_user_player(i) or not p.visible: continue
		if state!="playing": return
		if p.action_timer>0 and p.pose in ["stumble","fall","poke"]:
			p.desired=Vector3.ZERO
			continue
		if i==nearest[p.team] and carrier>=0 and players[carrier].team!=p.team and foul_cooldown<=0:
			var gap: Vector3=ball.position-p.position
			gap.y=0
			var poke_at: float=1.58 if duels.ball_opened(carrier) else 1.35
			if gap.length()<poke_at and ball.position.y<0.75 and p.tackle_cooldown<=0 and p.ai_think>management.reaction(p.team):
				duels.standing_tackle(i)
				if p.pose=="poke": continue
			elif gap.length()<2.2 and gap.length()>1 and p.tackle_cooldown<=0 and p.ai_think>1.5 and rng.randf()<0.8*_delta:
				rules.start_tackle(i,gap.normalized())
		if p.set_piece_pose=="wall" and p.wall_hold>0:
			p.desired=Vector3.ZERO
			p.sprinting=false
			continue
		if try_requested_pass(i): continue
		var forward = attack_sign(p.team)
		var target: Vector3 = p.home
		p.sprinting = false
		if p.keeper:
			target=goalkeeping.update(i,_delta)
		else:
			var distance = flat_distance(p.position,ball.position)
			var has_ball = distance<1.05 and ball.position.y<1.05 and ball.linear_velocity.length()<16
			if has_ball:
				target = Vector3(clampf(p.position.x*0.45,-12,12),0,forward*48)
				if dribbler==i:
					for q in players:
						if q.visible and q.team!=p.team and flat_distance(p.position,q.position)<1.6:
							p.protecting=true
							p.facing=duels.shield_direction(i)
							break
				if autonomous_kicks(p.team) and p.ai_think>management.reaction(p.team) and kick_lock<=0 and p.touch_cooldown<=0:
					var return_to: int=support.return_option(i)
					if return_to>=0:
						deliver_pass(i,return_to,false)
						support.runs.erase(i)
						support.runs.erase(return_to)
						continue
					var goal_distance = flat_distance(p.position,Vector3(0,0,forward*50))
					if goal_distance<26 and absf(p.position.x)<20:
						var aim = (Vector3(rng.randf_range(-2.7,2.7),0,forward*50)-ball.position)
						aim.y = 0
						strike(i,aim.normalized()*rng.randf_range(22,29)+Vector3.UP*rng.randf_range(2.2,4.2),0,false,"shot")
						shots[p.team] += 1
					elif p.ai_think>management.reaction(p.team)*2.55:
						var receiver = best_pass(i)
						if receiver>=0:
							deliver_pass(i,receiver,false)
			elif ai_receivers[p.team]==i and last_touch==p.team:
				target = ball.position+ball.linear_velocity*clampf(distance/14,0.08,0.65)
				target.x = clampf(target.x,-30,30)
				target.z = clampf(target.z,-48,48)
				p.sprinting = distance>5 and p.energy>0.4 and not p.exhausted
			elif i==nearest[p.team] and (carrier<0 or carrier==i or players[carrier].team!=p.team):
				target = ball.position+ball.linear_velocity*0.18
				p.sprinting = distance>9 and p.energy>0.4 and not p.exhausted
			else:
				target.x += clampf(ball.position.x*0.25,-7,7)
				target.z += clampf(ball.position.z*0.38,-18,18)
				if carrier>=0 and players[carrier].team==p.team:
					target.z += forward*9
					if p.number>8: target.z += forward*8
				else:
					# Defenders mark opponents in their channel without all chasing the ball.
					if p.number in [2,3,4,5]:
						var mark = players[(11 if p.team==0 else 0)+8+(p.number%3)]
						target = target.lerp(mark.position-Vector3(0,0,forward*3),0.30)
				target.x = clampf(target.x,-29,29)
				target.z = clampf(target.z,-43,43)
		if not p.keeper and i in support.targets and not can_touch(i,1.05) and ai_receivers[p.team]!=i:
			target=support.targets[i]
			p.sprinting=support.roles[i] in ["give_go","one_two","overlap"] and p.energy>0.35 and not p.exhausted
		if i!=nearest[p.team] and not can_touch(i,1.05) and support.roles.get(i,"")!="one_two": target=management.adjust_target(i,target)
		var offset: Vector3 = target-p.position
		offset.y = 0
		p.desired = offset.normalized()*clampf(offset.length()/1.4,0,1)
		if p.protecting: p.desired*=0.45
		# Local separation keeps formations open and avoids stacks of bodies.
		for other in players:
			if other==p or not other.visible: continue
			var gap: Vector3 = p.position-other.position
			gap.y = 0
			if gap.length()<1.2 and gap.length()>0.01: p.desired += gap.normalized()*(1.2-gap.length())*0.55
		p.desired = p.desired.limit_length(1)

func update_contacts(delta: float) -> void:
	# Keep possession through a turn; a nearby opponent can still win the ball.
	if dribbler>=0:
		var owner=players[dribbler]
		if not owner.visible or owner.action_timer>0 or (owner.keeper and not is_user_player(dribbler)) or flat_distance(owner.position,ball.position)>(2.05 if owner.active_sprint else 1.65) or ball.position.y>1.05 or ball.linear_velocity.length()>18 or kick_lock>0 or ball.pending_kick:
			dribbler=-1
	carrier=dribbler
	var nearest_distance: float=flat_distance(players[carrier].position,ball.position) if carrier>=0 else 1.35
	for i in range(players.size()):
		var p=players[i]
		if not p.visible or p.action_timer>0: continue
		var distance: float=flat_distance(p.position,ball.position)
		var closer: bool=distance<nearest_distance if dribbler<0 else (p.team!=players[dribbler].team and distance<duels.steal_reach(dribbler) and distance+duels.steal_margin(dribbler)<nearest_distance)
		if closer and ball.position.y<1.05 and duels.ball_exposed(i,dribbler):
			nearest_distance=distance
			carrier=i
	if carrier<0: return
	var p=players[carrier]
	possession[p.team]+=delta
	if carrier!=dribbler:
		if kick_lock>0 or p.touch_cooldown>0 or (p.keeper and not is_user_player(carrier)) or nearest_distance>1.12: return
		var speed: float=ball.linear_velocity.length()
		if speed>16 and not (ai_receivers[p.team]==carrier and last_touch==p.team and speed<27):
			if nearest_distance<0.65:
				if not rules.before_touch(carrier,false): return
				last_touch=p.team
			return
		if not rules.before_touch(carrier): return
		dribbler=carrier
		dribble_direction=(ball.position-p.position)*Vector3(1,0,1)
		dribble_direction=dribble_direction.normalized() if dribble_direction.length()>0.1 else p.facing
		if ai_receivers[p.team]==carrier: ai_receivers[p.team]=-1
		if carrier==incoming_receiver:
			incoming_receiver=-1
			incoming_time=0
			announce("İLK DOKUNUŞ · TOP SENDE")
	elif not rules.before_touch(carrier): return
	# Close control is a continuous, bounded foot impulse, never a transform
	# snap. Sprint only opens the ball a step ahead; it does not kick it away.
	var desired_direction: Vector3=duels.shield_direction(carrier) if p.protecting else p.facing
	if p.feint_time>0: desired_direction=desired_direction.rotated(Vector3.UP,sin((1-p.feint_time/0.48)*TAU)*0.85*p.feint_side)
	var turn := dribble_direction.signed_angle_to(desired_direction,Vector3.UP)
	var turn_rate := 5.0 if p.active_sprint else 9.0
	dribble_direction=dribble_direction.rotated(Vector3.UP,clampf(turn,-turn_rate*delta,turn_rate*delta))
	var pace: float=pace_of(p)
	var carry := 1.28 if p.active_sprint else 0.82
	if not p.active_sprint and pace<1.4: carry=0.80
	var foot: Vector3=p.position+dribble_direction*carry
	var correction: Vector3=(foot-ball.position)*Vector3(1,0,1)
	var catch := 11.0 if pace<1.4 else (8.0 if p.active_sprint else 7.0)
	var velocity: Vector3=p.velocity*Vector3(1,0,1)+(correction*20).limit_length(catch)
	ball.touch(Vector3(velocity.x,ball.linear_velocity.y,velocity.z),ball.mass*(120.0 if p.active_sprint else 110.0)*delta)
	last_touch=p.team
	last_kicker=carrier
	if p.team==0 and not player_lock and not training and carrier!=controlled and requested_receiver<0 and team_control.manual_hold<=0:
		team_control.select(carrier)

func pace_of(player: Node3D) -> float:
	return Vector2(player.velocity.x,player.velocity.z).length()

func check_boundaries() -> void:
	if boundary_grace>0 or ball.pending_reset: return
	var current: Vector3 = ball.position
	for side in [-1,1]:
		var goal_line = side*50.22
		if (previous_ball.z-goal_line)*side<=0 and (current.z-goal_line)*side>0:
			var difference = current.z-previous_ball.z
			if absf(difference)>0.0001:
				var fraction = (goal_line-previous_ball.z)/difference
				var cross_x = lerpf(previous_ball.x,current.x,fraction)
				var cross_y = lerpf(previous_ball.y,current.y,fraction)
				if absf(cross_x)<3.44 and cross_y<2.22:
					var scoring_team := 0 if side==int(attack_sign(0)) else 1
					if rules.allows_goal(scoring_team): goal(scoring_team)
					return
	if absf(current.x)>32.22:
		begin_restart("TAÇ",1-last_touch,Vector3(signf(current.x)*32,0,clampf(current.z,-49,49)))
	elif absf(current.z)>50.22:
		var defending_team = 1 if current.z*attack_sign(0)>0 else 0
		if last_touch==defending_team:
			begin_restart("KORNER",1-defending_team,Vector3(signf(current.x+0.001)*31.6,0,signf(current.z)*49.6))
		else:
			if absf(current.x)<9 and ball.linear_velocity.length()>8:
				stadium.react("miss",last_touch,current)
			begin_restart("KALE VURUŞU",defending_team,Vector3(0,0,signf(current.z)*45))
	elif training and current.length()>200: reset_practice()

func goal(team: int) -> void:
	support.reset()
	duels.reset()
	goalkeeping.reset()
	dribbler=-1
	set_pieces.clear()
	referees.goal()
	clear_pass_request()
	cancel_pass()
	score[team] += 1
	if training: practice_goals += 1
	goal_team = team
	state = "goal"
	restart_timer = 3.7
	charging = false
	charge = 0
	camera_shake = 0.28
	stadium.react("goal",team,ball.position)
	rules.advantage.clear()
	if not training:
		celebration.begin(team)
		if not menu_match.running: replay.queue_goal()

func skip_to_kickoff() -> void:
	if state=="goal": celebration.skip()
	elif state=="restart" and restart_type=="SANTRA" and not training: set_pieces.snap_ready()
	elif state=="ceremony": ceremony.finish(true)

func begin_restart(kind: String,team: int,point: Vector3) -> void:
	replay.goal_tail=0
	if not rules.advantage.is_empty():
		var pending: Dictionary=rules.advantage.duplicate()
		rules.advantage.clear()
		if team!=int(pending.team):
			kind="SERBEST VURUŞ"
			team=pending.team
			point=pending.point
	management.prepare_substitutions()
	support.reset()
	duels.reset()
	goalkeeping.reset()
	dribbler=-1
	clear_pass_request()
	rules.reset()
	state = "restart"
	restart_timer = 2.6
	restart_team = team
	restart_type = kind
	restart_point = Vector3(clampf(point.x,-32,32),0,clampf(point.z,-49.6,49.6))
	if kind=="KALE VURUŞU": restart_point=Vector3(0,0,-attack_sign(team)*45)
	if kind=="PENALTI": restart_point=Vector3(0,0,attack_sign(team)*39)
	# Indirect kicks inside the goal area are moved to its parallel boundary.
	if kind=="ENDİREKT VURUŞ" and absf(restart_point.x)<9.16 and absf(restart_point.z)>44.5:
		restart_point.z=signf(restart_point.z)*44.5
	charging = false
	charge = 0
	if not training: set_pieces.prepare()
	else: ball.active=true
	referees.restart(kind,team,restart_point)
	referees.whistle()
	rules.show_deferred_cards()
	announce(kind+"  ·  "+team_name(team))

func execute_restart() -> void:
	set_pieces.ready()

func screen_position(p: Vector3) -> Vector2:
	return camera.unproject_position(p)
