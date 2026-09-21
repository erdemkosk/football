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
var feedback := ImpactFeedback.new()
var ceremony := Ceremony.new()
var weather: Node3D
var set_pieces := SetPieces.new()
var rules := Rules.new()
const LENGTH := 240.0
const SHOT_AIM_RATE := 0.34906585 # 20 degrees per second.
const SHOT_AIM_LIMIT := 0.24434610 # 14 degrees either side of the starting aim.
const SHOT_MOUSE_RATE := 1.57079633 # 90 degrees per second.
const SHOT_CURVE := 0.22
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
var camera_focus := Vector3.ZERO
var zoom := 49.0
var tactical := false
var player_lock := false
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

func _ready() -> void:
	support.game=self
	duels.game=self
	goalkeeping.game=self
	celebration.game=self
	referees.game=self
	feedback.game=self
	ceremony.game=self
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
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.near = 0.2
	camera.far = 600
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0,70,37)
	camera.look_at(Vector3.ZERO)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = HUD.new()
	hud.game = self
	canvas.add_child(hud)
	audio = Audio.new()
	add_child(audio)
	referees.build()
	ceremony.officials=referees.actors
	reset_positions(0)
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

func start_match(practice: bool = false,show_ceremony: bool = true) -> void:
	celebration.clear()
	feedback.reset()
	ceremony.clear()
	set_pieces.clear()
	rules.reset()
	rules.card_time=0
	training = practice
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
	player_lock = false
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
	camera.size = 114 if tactical else zoom
	camera_focus = Vector3(0,0,-30 if practice else 0)
	update_camera(0)
	ball.active = true
	ball.freeze=false
	if not practice and show_ceremony:
		ceremony.begin()
		ceremony.update_camera(0)
	else:
		referees.whistle()
		announce("ANTRENMAN  ·  KALE SENİN" if practice else "İLK DÜDÜK  ·  HÜCUM YÖNÜ ↑")

func reset_positions(team: int) -> void:
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
		p.pose = "run"
		p.last_horizontal = Vector3.ZERO
		p.acceleration_lean = Vector3.ZERO
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
	if state=="ceremony" and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
		ceremony.finish(true)
		return
	if state=="set_piece": set_pieces.input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER:
				if state in ["menu","finished"]: start_match()
				elif state=="paused": resume()
			KEY_ESCAPE:
				if state=="paused": resume()
				elif state not in ["menu","finished"]:
					before_pause = state
					state = "paused"
					ball.freeze = true
					charging = false
					charge = 0
					cancel_pass()
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
					start_match(training)
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_C: tactical = not tactical
			KEY_M: audio.toggle()
			KEY_H:
				weather.select((weather.preset+1)%3,state=="menu")
				announce("HAVA · "+weather.label())
			KEY_TAB:
				player_lock = not player_lock
				announce("YILDIZ MODU · TEK OYUNCU" if player_lock else "TAKIM KONTROLÜ")
			KEY_Q:
				if state=="playing": switch_player()
			KEY_S:
				if state=="playing": begin_pass()
			KEY_A:
				if state=="playing": pass_ball(true)
			KEY_Z:
				if state=="playing": duels.feint(controlled)
			KEY_V:
				if state=="playing": duels.push_ahead(controlled)
			KEY_F:
				if state=="playing":
					cancel_pass()
					duels.standing_tackle(controlled)
			KEY_X:
				if state=="playing": tackle()
			KEY_D:
				if state=="playing":
					if can_touch(controlled,1.8): begin_shot()
	if event is InputEventKey and not event.pressed and event.keycode==KEY_D and charging:
		shoot()
	if event is InputEventKey and not event.pressed and event.keycode==KEY_S and pass_charging:
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
	ball.freeze = false

func return_menu() -> void:
	ceremony.clear()
	referees.reset(false)
	state = "menu"
	ball.freeze = false
	ball.active = false
	charging = false
	charge = 0
	training = false
	for p in players: p.visible = true; p.collision_layer = 2
	reset_positions(0)

func _process(delta: float) -> void:
	elapsed += delta
	toast_timer = maxf(0,toast_timer-delta)
	update_camera(delta)
	hud.queue_redraw()
	stadium.architecture.update_score(score,match_time,LENGTH)
	if state!="paused":
		rules.card_time=maxf(0,rules.card_time-delta)
		stadium.crowd.update(delta,ball.position,ball.linear_velocity,last_touch,state=="playing",not training and match_time>LENGTH*0.7 and abs(score[0]-score[1])<=1)
		stadium.sidelines.update(delta,ball.position,ball.linear_velocity,last_touch,state=="playing")
		if not audio.muted: audio.crowd.volume_db = -22+stadium.crowd.excitement*(9 if stadium.crowd.event_kind=="goal" else 5)

func update_camera(delta: float) -> void:
	if not training and not tactical and (state=="goal" or (state=="paused" and before_pause=="goal")):
		celebration.update_camera(0 if state=="paused" else delta)
		return
	if state=="ceremony" or (state=="paused" and before_pause=="ceremony"):
		ceremony.update_camera(0 if state=="paused" else delta)
		return
	if state=="menu":
		var center = Vector3(-26,0,22)
		var angle = 0.86+sin(elapsed*0.035)*0.055
		camera.size = 180
		camera.position = center+Vector3(cos(angle)*190,144,sin(angle)*190)
		camera.look_at(center)
		return
	var focus: Vector3 = ball.position
	if state=="playing": focus = ball.position.lerp(players[controlled].position,0.26)
	if state in ["restart","set_piece"] and set_pieces.recovery.phase in ["arrange","ready"] and restart_type in ["SERBEST VURUŞ","ENDİREKT VURUŞ","PENALTI","KORNER"]:
		var goal = Vector3(0,0,-50 if restart_team==0 else 50)
		if restart_point.distance_to(goal)<45: focus=restart_point.lerp(goal,0.42)
	focus.y = 0
	if tactical: focus = Vector3.ZERO
	else:
		focus.x = clampf(focus.x*0.42,-8,8)
		var extent := 45.0 if state=="restart" and set_pieces.recovery.phase not in ["arrange","ready"] else 35.0
		focus.z = clampf(focus.z,-extent,extent)
	camera_focus = camera_focus.lerp(focus,1-exp(-delta*3.7))
	var target_zoom = 114.0 if tactical else zoom
	if state in ["restart","set_piece"] and not tactical: target_zoom=maxf(zoom,57)
	if state=="goal" and not tactical: target_zoom = maxf(zoom,61.0)
	camera.size = lerpf(camera.size,target_zoom,1-exp(-delta*3))
	camera.position = camera_focus + Vector3(0,70,37)
	if camera_shake>0:
		camera.position.x += sin(elapsed*63)*camera_shake
		camera_shake = maxf(0,camera_shake-delta*1.8)
	var contact_offset := feedback.offset()
	camera.position+=contact_offset
	camera.look_at(camera_focus+contact_offset)

func _physics_process(delta: float) -> void:
	weather.sound.stream_paused=state=="paused"
	for channel in audio.contacts: channel.stream_paused=state=="paused"
	if state!="paused":
		weather.update(delta)
		feedback.update(delta)
		referees.update(delta)
	if state=="ceremony":
		ceremony.update(delta)
	elif state=="playing":
		match_time += delta
		if not training and match_time>=LENGTH:
			state = "finished"
			ball.active = false
			referees.finish_match()
			return
		kick_lock = maxf(0,kick_lock-delta)
		boundary_grace = maxf(0,boundary_grace-delta)
		foul_cooldown = maxf(0,foul_cooldown-delta)
		rules.update(delta)
		if state!="playing": return
		update_control(delta)
		update_pass_request(delta)
		update_ai(delta)
		if state!="playing": return
		for i in range(players.size()):
			var p = players[i]
			p.chosen = i==controlled
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
		else: celebration.update(delta)
	elif state=="menu":
		for i in range(players.size()):
			players[i].chosen = i==controlled
			players[i].marker.visible = i==controlled

func update_control(delta: float) -> void:
	for p in players: p.shot_preparation=0
	var movement = Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP))).normalized()
	players[controlled].desired = movement*(0.62 if charging else (0.72 if pass_charging else 1.0))
	players[controlled].sprinting = Input.is_physical_key_pressed(KEY_W)
	for p in players: p.protecting=false; p.jockeying=false
	var user=players[controlled]
	if Input.is_physical_key_pressed(KEY_E) and not charging and not pass_charging and user.action_timer<=0:
		user.protecting=dribbler==controlled
		user.jockeying=not user.protecting
		user.sprinting=false
		user.desired*=0.45 if user.protecting else 0.58
		var facing: Vector3=duels.shield_direction(controlled) if user.protecting else (ball.position-user.position)*Vector3(1,0,1)
		if facing.length()>0.1: user.facing=facing.normalized()
	if movement.length()>0 and not charging and not pass_charging: last_direction = movement
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
		players[controlled].shot_preparation=0.15+charge*0.85
		players[controlled].facing=shot_direction

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
	var toward_goal := Vector3(clampf(ball.position.x+direction.x*10,-3.0,3.0),0,-50)-ball.position
	toward_goal.y = 0
	if toward_goal.length()<0.1: return direction
	var assistance := smoothstep(0.35,0.95,-direction.z)*0.36
	return direction.lerp(toward_goal.normalized(),assistance).normalized()

func begin_shot(use_mouse: bool = false) -> void:
	cancel_pass()
	if charging: return
	shot_mouse_aim = use_mouse or aiming_mouse
	shot_anchor = pointer_direction(last_direction) if shot_mouse_aim else assisted_shot_direction(last_direction)
	shot_direction = shot_anchor
	shot_offset = 0
	charge = 0
	charging = true

func update_shot_aim(delta: float) -> void:
	if shot_mouse_aim:
		var target := pointer_direction(shot_direction)
		var turn := shot_direction.signed_angle_to(target,Vector3.UP)
		shot_direction = shot_direction.rotated(Vector3.UP,clampf(turn,-SHOT_MOUSE_RATE*delta,SHOT_MOUSE_RATE*delta)).normalized()
	else:
		var steering := float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
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
	if best>=0:
		controlled = best
		last_direction = players[controlled].facing
		charging = false
		charge = 0

func shoot() -> void:
	if state=="playing" and can_touch(controlled,2.0):
		# Release uses exactly the previewed heading, with no last-frame aim correction.
		var aim := shot_direction if charging else (pointer_direction(last_direction) if aiming_mouse else assisted_shot_direction(last_direction))
		var speed := lerpf(19,32,charge)
		var lift := lerpf(1.6,5.1,charge)
		var curve := -shot_offset/SHOT_AIM_LIMIT*SHOT_CURVE if charging and not shot_mouse_aim else 0.0
		if strike(controlled,aim*speed+Vector3.UP*lift,curve,false,"shot"): shots[0] += 1
	players[controlled].shot_preparation=0
	charging = false
	charge = 0

func strike(index: int,velocity: Vector3,curve: float=0,is_save: bool=false,kind: String="kick") -> bool:
	if not rules.before_touch(index,not is_save): return false
	if not is_save: rules.kicked(index)
	possession_player = -1
	dribbler=-1
	ball.strike(velocity,curve)
	last_touch = players[index].team
	last_kicker = index
	players[index].touch_cooldown = 0.38
	players[index].kick_power=clampf((velocity.length()-12)/20,0.15,1)
	players[index].kick_duration=0.46 if kind=="shot" else 0.32
	players[index].kick_timer=players[index].kick_duration if kind!="ball_tackle" and not is_save else 0.0
	players[index].shot_preparation=0
	if kind=="shot": players[index].facing=(velocity*Vector3(1,0,1)).normalized()
	players[index].ai_think = 0
	kick_lock = 0.16
	if kind in ["shot","ball_tackle"]:
		feedback.contact(kind,index,ball.position,velocity.normalized(),players[index].kick_power)
	else: audio.play("kick")
	var forward := -1.0 if last_touch==0 else 1.0
	if velocity.z*forward>16 and ball.position.z*forward>18:
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

func best_pass(index: int) -> int:
	var p = players[index]
	var aim: Vector3 = aim_direction() if index==controlled else (Vector3.FORWARD if p.team==0 else Vector3.BACK)
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
		var route = Passing.plan(ball.position,q.position,q.velocity,false)
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
	var receiver = best_pass(controlled)
	if receiver>=0:
		deliver_pass(controlled,receiver,lob)
		if not player_lock and not training: controlled = receiver
	else:
		strike(controlled,aim_direction()*16+Vector3.UP*(7.5 if lob else 0.32))
		passes[0] += 1
	charging = false
	charge = 0

func cancel_pass() -> void:
	pass_charging = false
	pass_power = 0
	pass_preview = {}
	pass_risk = 0

func begin_pass() -> void:
	if state!="playing" or pass_charging: return
	if not has_ball_control(controlled):
		call_for_pass()
		return
	if kick_lock>0 and last_kicker>=0: return
	charging = false
	charge = 0
	pass_charging = true
	pass_power = 0
	pass_direction = last_direction
	update_pass_preview()

func update_pass_preview() -> void:
	pass_preview = Passing.manual_plan(ball.position,pass_direction,pass_power,players[controlled].team,controlled,players)
	pass_risk = Passing.risk(ball.position,pass_preview,players[controlled].team,players)

func release_pass() -> void:
	if not pass_charging: return
	if state!="playing" or not has_ball_control(controlled):
		cancel_pass()
		return
	var route := pass_preview.duplicate()
	var passer := controlled
	var receiver: int = route.receiver
	last_direction = pass_direction
	clear_pass_request()
	strike(passer,route.velocity)
	passes[players[passer].team] += 1
	if receiver>=0:
		support.passed(passer,receiver)
		ai_receivers[players[passer].team]=receiver
		ai_pass_time[players[passer].team]=float(route.flight)+2.0
		if not player_lock and not training: controlled=receiver

func clear_pass_request() -> void:
	cancel_pass()
	requested_receiver = -1
	request_time = 0
	request_age = 0
	incoming_receiver = -1
	incoming_time = 0
	request_cooldown = 0
	for p in players:
		p.call_timer = 0
		p.call_label.visible = false

func call_for_pass(lob: bool = false) -> void:
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
	request_cooldown = 0.6
	players[controlled].call_timer = 3.2
	players[controlled].call_label.text = "ORTA!" if lob else "PAS!"
	announce("ORTA İSTEDİN · BOŞLUĞA KOŞ" if lob else "PAS İSTEDİN · BOŞLUĞA KOŞ")

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
	if not can_touch(index,1.8): return false
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
	if nearest_to_ball(1.4)!=passer or kick_lock>0 or p.touch_cooldown>0 or ball.linear_velocity.length()>13: return false
	var distance := flat_distance(p.position,players[receiver].position)
	if distance<3 or distance>42: return false
	var lob := request_lob
	var route = Passing.plan(ball.position,players[receiver].position,players[receiver].velocity,lob)
	var danger = Passing.risk(ball.position,route,p.team,players)
	if not lob and danger>0.48 and distance>9:
		var high_route = Passing.plan(ball.position,players[receiver].position,players[receiver].velocity,true)
		if Passing.risk(ball.position,high_route,p.team,players)<danger:
			route=high_route
			lob=true
	if Passing.risk(ball.position,route,p.team,players)>0.48:
		if request_age>0.8 and request_age<0.8+1.0/60.0: announce("PAS YOLU KAPALI · BOŞA ÇIK")
		return false
	deliver_pass(passer,receiver,lob)
	requested_receiver = -1
	request_time = 0
	players[receiver].call_timer = 0.7
	incoming_receiver = receiver
	incoming_time = float(route.flight)+1.5
	p.desired = Vector3.ZERO
	announce("%s SANA %s" % [p.display_name,"ORTA AÇIYOR" if lob else "PAS ATIYOR"])
	return true

func deliver_pass(passer: int,receiver: int,lob: bool) -> void:
	var route = Passing.plan(ball.position,players[receiver].position,players[receiver].velocity,lob)
	if not strike(passer,route.velocity): return
	support.passed(passer,receiver)
	passes[players[passer].team] += 1
	ai_receivers[players[passer].team] = receiver
	ai_pass_time[players[passer].team] = float(route.flight)+2.0

func tackle() -> void:
	cancel_pass()
	rules.start_tackle(controlled,last_direction)

func update_ai(_delta: float) -> void:
	support.update(_delta)
	var nearest = [-1,-1]
	var distances = [INF,INF]
	for i in range(players.size()):
		var p = players[i]
		if not p.visible or p.keeper or i==controlled: continue
		var d = flat_distance(p.position,ball.position)
		if d<distances[p.team]: distances[p.team] = d; nearest[p.team] = i
	for i in range(players.size()):
		var p = players[i]
		if i==controlled or not p.visible: continue
		if state!="playing": return
		if p.action_timer>0 and p.pose in ["stumble","fall","poke"]:
			p.desired=Vector3.ZERO
			continue
		if i==nearest[p.team] and carrier>=0 and players[carrier].team!=p.team and foul_cooldown<=0:
			var gap: Vector3=ball.position-p.position
			gap.y=0
			if gap.length()<1.35 and ball.position.y<0.75 and p.tackle_cooldown<=0 and p.ai_think>0.6:
				duels.standing_tackle(i)
				if p.pose=="poke": continue
			elif gap.length()<2.2 and gap.length()>1 and p.tackle_cooldown<=0 and p.ai_think>1.5 and rng.randf()<0.8*_delta:
				rules.start_tackle(i,gap.normalized())
		if p.set_piece_pose=="wall" and p.wall_hold>0:
			p.desired=Vector3.ZERO
			p.sprinting=false
			continue
		if try_requested_pass(i): continue
		var forward = -1 if p.team==0 else 1
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
				if p.ai_think>0.55 and kick_lock<=0 and p.touch_cooldown<=0:
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
					elif p.ai_think>1.4:
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
			p.sprinting=support.roles[i] in ["give_go","overlap"] and p.energy>0.35 and not p.exhausted
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
		if not owner.visible or owner.action_timer>0 or owner.keeper or flat_distance(owner.position,ball.position)>1.65 or ball.position.y>1.05 or ball.linear_velocity.length()>18 or kick_lock>0 or ball.pending_kick:
			dribbler=-1
	carrier=dribbler
	var nearest_distance: float=flat_distance(players[carrier].position,ball.position) if carrier>=0 else 1.35
	for i in range(players.size()):
		var p=players[i]
		if not p.visible or p.action_timer>0: continue
		var distance: float=flat_distance(p.position,ball.position)
		var closer: bool=distance<nearest_distance if dribbler<0 else (p.team!=players[dribbler].team and distance<0.72 and distance+0.18<nearest_distance)
		if closer and ball.position.y<1.05 and duels.ball_exposed(i,dribbler):
			nearest_distance=distance
			carrier=i
	if carrier<0: return
	var p=players[carrier]
	possession[p.team]+=delta
	if carrier!=dribbler:
		if kick_lock>0 or p.touch_cooldown>0 or p.keeper or nearest_distance>1.12: return
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
	# snap. Rotate around the body on sharp turns instead of pulling through it.
	var desired_direction: Vector3=duels.shield_direction(carrier) if p.protecting else p.facing
	if p.feint_time>0: desired_direction=desired_direction.rotated(Vector3.UP,sin((1-p.feint_time/0.48)*TAU)*0.85*p.feint_side)
	var turn := dribble_direction.signed_angle_to(desired_direction,Vector3.UP)
	dribble_direction=dribble_direction.rotated(Vector3.UP,clampf(turn,-9*delta,9*delta))
	var foot: Vector3=p.position+dribble_direction*0.82
	var correction: Vector3=(foot-ball.position)*Vector3(1,0,1)
	var velocity: Vector3=p.velocity*Vector3(1,0,1)+(correction*18).limit_length(7)
	ball.touch(Vector3(velocity.x,ball.linear_velocity.y,velocity.z),ball.mass*110*delta)
	last_touch=p.team
	last_kicker=carrier
	if p.team==0 and not player_lock and not training and carrier!=controlled and p.desired.length()<=0.12 and requested_receiver<0 and incoming_receiver<0:
		controlled=carrier

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
					var scoring_team := 0 if side<0 else 1
					if rules.allows_goal(scoring_team): goal(scoring_team)
					return
	if absf(current.x)>32.22:
		begin_restart("TAÇ",1-last_touch,Vector3(signf(current.x)*32,0,clampf(current.z,-49,49)))
	elif absf(current.z)>50.22:
		var defending_team = 1 if current.z<0 else 0
		if last_touch==defending_team:
			begin_restart("KORNER",1-defending_team,Vector3(signf(current.x+0.001)*31.6,0,signf(current.z)*49.6))
		else:
			if absf(current.x)<9 and ball.linear_velocity.length()>8:
				stadium.sidelines.react("miss",last_touch,current)
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
	audio.play("goal")
	stadium.react("goal",team,ball.position)
	if not training: celebration.begin(team)

func begin_restart(kind: String,team: int,point: Vector3) -> void:
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
	if kind=="KALE VURUŞU": restart_point=Vector3(0,0,45 if team==0 else -45)
	if kind=="PENALTI": restart_point=Vector3(0,0,-39 if team==0 else 39)
	# Indirect kicks inside the goal area are moved to its parallel boundary.
	if kind=="ENDİREKT VURUŞ" and absf(restart_point.x)<9.16 and absf(restart_point.z)>44.5:
		restart_point.z=signf(restart_point.z)*44.5
	charging = false
	charge = 0
	if not training: set_pieces.prepare()
	else: ball.active=true
	referees.restart(kind,team,restart_point)
	referees.whistle()
	announce(kind+"  ·  "+("KIYI SPOR" if team==0 else "ATLAS FC"))

func execute_restart() -> void:
	set_pieces.ready()

func screen_position(p: Vector3) -> Vector2:
	return camera.unproject_position(p)
