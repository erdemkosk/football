extends RefCounted
## Crosses share the pass/shot contract: hold to aim, release to commit once.
const CROSS_CHARGE_TIME := .95
var game
var consumed: Dictionary = {}
var switch_pending := false
var switch_player := -1
var cross_player := -1
var cross_age := 0.0
var cross_direction := Vector3.FORWARD
var cross_guard := 0.0
var cross_power := 0.0
var cross_driven := false
var loft_started := false

func cancel_cross() -> void:
	if cross_player>=0: game.players[cross_player].shot_preparation=0
	cross_player=-1
	cross_age=0
	cross_power=0

func cancel() -> void:
	cancel_cross()
	switch_pending=false
	switch_player=-1
	cross_guard=0
	loft_started=false
	consumed.clear()

func handle(event: InputEventJoypadButton) -> bool:
	var button := event.button_index
	if consumed.has(button):
		if not event.pressed:
			consumed.erase(button)
			if game.controller.bindings.get(button)==KEY_A and cross_player>=0: commit_cross(cross_driven)
			if button==JOY_BUTTON_Y and loft_started:
				loft_started=false
				if game.pass_lob: game.release_pass()
			if button==JOY_BUTTON_LEFT_SHOULDER:
				if switch_pending and game.state=="playing" and game.controlled==switch_player and not game.charging: game.switch_player()
				switch_pending=false
		return true
	if not event.pressed or game.state!="playing": return false
	if button==JOY_BUTTON_LEFT_SHOULDER and game.has_ball_control(game.controlled):
		# In possession, release LB to switch; holding it leaves the passer selected.
		if game.controller.bindings.get(button)==KEY_Q:
			switch_pending=true
			switch_player=game.controlled
			consumed[button]=true
			if game.controller.held.get(JOY_BUTTON_A)==KEY_S and (game.pass_charging or game.has_ball_control(game.controlled)):
				consumed[JOY_BUTTON_A]=true
				game.controller.held.erase(JOY_BUTTON_A)
				one_two()
			elif game.controller.held.get(JOY_BUTTON_Y)==KEY_Y and game.pass_charging:
				consumed[JOY_BUTTON_Y]=true
				game.controller.held.erase(JOY_BUTTON_Y)
				start_loft()
			return true
	if button==JOY_BUTTON_A and consumed.has(JOY_BUTTON_LEFT_SHOULDER) and game.controller.bindings.get(button)==KEY_S:
		consumed[button]=true
		one_two()
		return true
	if button==JOY_BUTTON_Y and consumed.has(JOY_BUTTON_LEFT_SHOULDER):
		consumed[button]=true
		start_loft()
		return true
	if game.controller.bindings.get(button)!=KEY_A: return false
	if cross_guard>0:
		consumed[button]=true
		return true
	if cross_player>=0:
		consumed[button]=true
		return true
	if not game.has_ball_control(game.controlled): return false
	consumed[button]=true
	if game.kick_lock>0 and game.last_kicker>=0: return true
	begin_cross()
	return true

func begin_cross() -> void:
	if not game.has_ball_control(game.controlled) or cross_player>=0 or cross_guard>0: return
	game.cancel_pass()
	game.charging=false; game.charge=0
	cross_player=game.controlled; cross_age=0; cross_power=0
	var movement: Vector3=game.aiming_input()
	cross_direction=movement.normalized() if movement.length()>.1 else game.last_direction
	cross_driven=game.controller.action_held(KEY_W) or Input.is_physical_key_pressed(game.match_menu.key_for(KEY_W))

func release_cross() -> void:
	if cross_player>=0: commit_cross(cross_driven)

func one_two() -> void:
	switch_pending=false
	game.charging=false; game.charge=0
	game.shot_chip=false
	game.players[game.controlled].shot_preparation=0
	cancel_cross()
	game.cancel_pass()
	if game.controlled!=switch_player or not game.has_ball_control(game.controlled): return
	var movement: Vector3=game.movement_input()
	if movement.length()>0.1: game.last_direction=movement.normalized()
	game.one_two_pass()

func start_loft() -> void:
	switch_pending=false
	if not game.has_ball_control(game.controlled): return
	var power: float=game.pass_power if game.pass_charging else 0.0
	var movement: Vector3=game.movement_input()
	if movement.length()>0.1: game.last_direction=movement.normalized()
	game.begin_pass(false,true)
	if game.pass_charging and game.pass_lob:
		game.pass_power=power
		game.update_pass_preview()
		loft_started=true

func valid_cross() -> bool:
	return cross_player>=0 and game.state=="playing" and game.controlled==cross_player and game.has_ball_control(cross_player) and not game.charging and not game.pass_charging

func update(delta: float) -> void:
	if game.state!="playing":
		cancel()
		return
	cross_guard=maxf(0,cross_guard-delta)
	if cross_player<0: return
	if not valid_cross():
		cross_guard=.18
		cancel_cross()
		return
	cross_age+=delta
	cross_power=minf(1,cross_age/CROSS_CHARGE_TIME)
	var movement: Vector3=game.aiming_input()
	if movement.length()>.01:
		var turn := cross_direction.signed_angle_to(movement.normalized(),Vector3.UP)
		var response: float=game.controller.aim_response(movement.length()) if game.controller.using_gamepad else 1.0
		cross_direction=cross_direction.rotated(Vector3.UP,clampf(turn,-game.PASS_TURN_RATE*response*delta,game.PASS_TURN_RATE*response*delta)).normalized()

func commit_cross(driven: bool) -> void:
	var valid := valid_cross()
	var heading := cross_direction
	var power := cross_power
	cancel_cross()
	if not valid: return
	game.last_direction=heading
	game.execute_player_pass(game.cross_plan(heading,driven,power))
	cross_guard=0.18
