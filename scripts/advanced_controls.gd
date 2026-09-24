extends RefCounted
## Contextual gestures run after menus and before ordinary gameplay bindings.
var game
var pad_down: Dictionary = {}
var consumed: Dictionary = {}
var stick := Vector2.ZERO
var stick_ready := true
var roll_side := 0.0
var roll_age := 0.0
var dummy: Dictionary = {}
var sprint_tap_age := 1.0
var sprint_tap_player := -1

func reset() -> void:
	for i in dummy:
		game.players[i].dummy_time=0
		game.ball.remove_collision_exception_with(game.players[i])
	dummy.clear(); pad_down.clear(); consumed.clear()
	sprint_tap_age=1.0; sprint_tap_player=-1
	stick=Vector2.ZERO; stick_ready=true; roll_side=0; roll_age=0
	game.defending.pressing=false

func side() -> float:
	var p=game.players[game.controlled]
	var direction: Vector3=game.movement_input()
	return -1.0 if direction.dot(p.facing.cross(Vector3.UP))<-.15 else 1.0

func start_dummy(index: int) -> bool:
	var p=game.players[index]
	if p.keeper or p.action_timer>0 or p.skill_cooldown>0 or game.ball.held_by!=null or game.dribbler==index or game.last_touch!=p.team: return false
	var incoming: Vector3=game.ball.linear_velocity-p.velocity
	if incoming.length()<2 or game.flat_distance(p.position,game.ball.position)>9 or game.ball.position.y>.95: return false
	dummy[index]=.68; p.skill_cooldown=.9; p.dummy_time=.68
	game.ball.add_collision_exception_with(p)
	game.hint("BIRAK GEÇ")
	return true

func skill_gesture(direction: Vector3) -> void:
	var p=game.players[game.controlled]
	var fancy: bool=game.controller.action_held(KEY_E) or Input.is_key_pressed(KEY_E)
	var forward: float=direction.dot(p.facing)
	var lateral: float=direction.dot(p.facing.cross(Vector3.UP))
	if game.controller.action_held(KEY_W):
		roll_side=0
		game.skills.start(game.controlled,"stop_go" if forward<-.35 else "knock_around",-1 if lateral<0 else 1)
		return
	if fancy:
		roll_side=0
		if forward<-.35: game.skills.start(game.controlled,"rainbow",side())
		elif forward>.35: game.skills.start(game.controlled,"heel",side())
		else: game.skills.start(game.controlled,"flick",side())
		return
	if absf(lateral)>absf(forward):
		var sign_side := signf(lateral)
		if roll_side!=0 and sign_side!=roll_side:
			game.skills.start(game.controlled,"elastico",roll_side); roll_side=0
		else: roll_side=sign_side; roll_age=0
	else:
		roll_side=0
		game.skills.start(game.controlled,"scoop" if forward>0 else "roulette",side())

func update(delta: float) -> void:
	if game.state!="playing": reset(); return
	sprint_tap_age+=delta
	if roll_side!=0:
		roll_age+=delta
		if roll_age>.18:
			game.skills.start(game.controlled,"roll",roll_side); roll_side=0
	for i in dummy.keys():
		dummy[i]-=delta; game.players[i].dummy_time=dummy[i]
		if dummy[i]<=0 or not game.players[i].visible or game.ball.position.y>1.0:
			game.players[i].dummy_time=0
			game.ball.remove_collision_exception_with(game.players[i]); dummy.erase(i)

func sprint_pressed() -> void:
	var index: int=game.controlled
	var p=game.players[index]
	if sprint_tap_player==index and sprint_tap_age<.30 and game.dribbler==index and p.desired.length()>.2 and not game.charging and not game.pass_charging:
		game.duels.push_ahead(index)
		sprint_tap_age=1.0; sprint_tap_player=-1
	else:
		sprint_tap_age=0; sprint_tap_player=index

func shoulder_held() -> bool:
	var pad=game.controller
	return pad_down.has(JOY_BUTTON_LEFT_SHOULDER) and pad.bindings.get(JOY_BUTTON_LEFT_SHOULDER)==KEY_Q

func right_trigger() -> bool:
	if game.coaching.trigger_down: return true
	var pad=game.controller
	return pad.device>=0 and Input.get_joy_axis(pad.device,JOY_AXIS_TRIGGER_RIGHT)>0.28

func set_shot_style(low: bool,power: bool,outside: bool) -> void:
	var next := "outside" if outside else ("power" if power else ("low" if low else ("timed" if game.finishing.timed_armed else "")))
	if game.finishing.style==next: return
	if next=="" and game.finishing.style=="power": return
	game.finishing.style=next
	if game.finishing.style!="": game.hint(game.finishing.LABELS[game.finishing.style])

func refresh_shot_style() -> void:
	var pad=game.controller
	var lb: bool=shoulder_held() or pad.combos.consumed.has(JOY_BUTTON_LEFT_SHOULDER)
	var rb: bool=pad_down.has(JOY_BUTTON_RIGHT_SHOULDER) and pad.bindings.get(JOY_BUTTON_RIGHT_SHOULDER)==KEY_W
	var lt: bool=pad.action_held(KEY_E)
	var rt: bool=right_trigger()
	if lb and rt:
		set_shot_style(false,true,false)
		pad.combos.switch_pending=false
	elif lb and lt:
		set_shot_style(false,false,true)
		pad.combos.switch_pending=false
	elif rb and not lb:
		set_shot_style(true,false,false)
		pad.combos.switch_pending=false
	elif game.finishing.style=="power":
		return
	else:
		set_shot_style(false,false,false)

func handle(event: InputEvent) -> bool:
	if game.state!="playing": return false
	var index: int=game.controlled
	var in_hand: bool=game.ball.held_by==game.players[index]
	if event is InputEventKey:
		if event.keycode==KEY_SPACE:
			game.defending.pressing=event.pressed; return true
		if not event.pressed or event.echo: return false
		if event.keycode==KEY_9: game.skills.start(index,"stop_go",side()); return true
		if event.keycode==KEY_0: game.skills.start(index,"knock_around",side()); return true
		if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:
			game.skills.start(index,["roulette","roll","elastico","scoop"][event.keycode-KEY_1],side()); return true
		if event.keycode in [KEY_6,KEY_7,KEY_8]:
			game.skills.start(index,["rainbow","heel","flick"][event.keycode-KEY_6],side()); return true
		if event.keycode==KEY_5:
			game.finishing.timed_armed=not game.finishing.timed_armed; return true
		if event.keycode==KEY_J: game.defending.shoulder(index); return true
		if event.keycode==KEY_L: game.defending.intercept(index); return true
		if event.keycode==KEY_U: start_dummy(index); return true
		if event.keycode==KEY_V and in_hand: game.keeper_distribution.drop(index); return true
		if event.keycode==KEY_D:
			if game.finishing.active(index): game.finishing.timing_press(); return true
			roll_side=0
			set_shot_style(event.ctrl_pressed,event.shift_pressed,event.alt_pressed)
		if event.keycode in [KEY_S,KEY_Y] and event.ctrl_pressed and game.has_ball_control(index) and not in_hand:
			game.begin_pass(event.keycode==KEY_Y,false,true); return true
		return false
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return false
	var pad=game.controller
	if pad.device!=event.device: pad.claim_device(event.device,true)
	if event.device!=pad.device: return false
	if event is InputEventJoypadMotion:
		if event.axis not in [JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]: return false
		if game.charging or game.pass_charging or game.controller.combos.cross_player>=0 or game.aerial_shot_active(index) or game.finishing.active(index): return false
		if event.axis==JOY_AXIS_RIGHT_X: stick.x=event.axis_value
		else: stick.y=event.axis_value
		if stick.length()<.3: stick_ready=true
		elif stick.length()>.75 and stick_ready:
			stick_ready=false; pad.using_gamepad=true; pad.clear_shot_aim()
			var direction: Vector3=game.match_camera.orient(Vector3(stick.x,0,stick.y)).normalized()
			if game.has_ball_control(index): skill_gesture(direction)
			else: game.defending.switch_direction(direction)
		return true
	var button: int=event.button_index
	if event.pressed: pad_down[button]=true
	else: pad_down.erase(button)
	if consumed.has(button):
		if not event.pressed:
			if consumed[button]=="press": game.defending.pressing=false
			elif consumed[button]=="pass": game.release_pass()
			consumed.erase(button)
		return true
	if not event.pressed: return false
	var action: int=pad.bindings.get(button,0)
	var lb: bool=shoulder_held()
	var rb: bool=pad_down.has(JOY_BUTTON_RIGHT_SHOULDER) and pad.bindings.get(JOY_BUTTON_RIGHT_SHOULDER)==KEY_W
	var lt: bool=pad.action_held(KEY_E)
	if button==JOY_BUTTON_RIGHT_STICK and lt and game.training and game.training_drills.mode=="duel":
		game.training_drills.duel.next_stage(); consumed[button]="stage"; return true
	if button==JOY_BUTTON_RIGHT_STICK and game.training and game.training_drills.mode=="duel":
		game.reset_practice(); consumed[button]="stage"; return true
	if action==KEY_D:
		if game.finishing.active(index): consumed[button]="timing"; game.finishing.timing_press(); return true
		if lt and game.dribbler!=index and game.last_touch!=game.players[index].team and not game.can_request_aerial(index):
			consumed[button]="intercept"; game.defending.intercept(index); return true
		roll_side=0
		if stick.length()>.3: pad.aim_stick=stick
		refresh_shot_style()
		if rb or (lb and lt) or (lb and right_trigger()): pad.combos.switch_pending=false
	if action in [KEY_S,KEY_Y] and rb and not lb and game.has_ball_control(index) and not in_hand:
		consumed[button]="pass"; pad.using_gamepad=true
		game.begin_pass(action==KEY_Y,false,true); return true
	if action==KEY_S and not game.has_ball_control(index) and game.last_touch!=0:
		consumed[button]="press"; game.defending.pressing=true; pad.using_gamepad=true; return true
	if button==JOY_BUTTON_LEFT_STICK:
		consumed[button]="stick"; pad.using_gamepad=true
		if game.has_ball_control(index): game.finishing.timed_armed=not game.finishing.timed_armed
		elif game.last_touch==0: start_dummy(index)
		else: game.defending.shoulder(index)
		return true
	if action==KEY_V and in_hand:
		consumed[button]="drop"; game.keeper_distribution.drop(index); return true
	return false

func draw(hud) -> void:
	if game.state!="playing" or game.menu_match.running: return
	var next: int=game.team_control.next_switch()
	if next>=0:
		var p=game.players[next]
		var point: Vector3=p.position+Vector3.UP*2.75
		var at: Vector2=game.screen_position(point)
		if not game.camera.is_position_behind(point) and game.ui.bounds().grow(-36).has_point(at):
			var selected=game.players[game.controlled]
			var selected_at: Vector2=game.screen_position(selected.position+Vector3.UP*(selected.height_cm/100.0+.30))
			if absf(at.x-selected_at.x)<80 and absf(at.y-selected_at.y)<40:
				at.x=selected_at.x+(-90 if at.x<selected_at.x else 90)
			# A hollow arrow previews the same candidate used by LB/L1/Q.
			hud.draw_polyline(PackedVector2Array([at+Vector2(-5,-4),at+Vector2(5,-4),at+Vector2(0,3),at+Vector2(-5,-4)]),Color("101c22"),4.5,true)
			hud.draw_polyline(PackedVector2Array([at+Vector2(-5,-4),at+Vector2(5,-4),at+Vector2(0,3),at+Vector2(-5,-4)]),Color("9fcbe2",.8),1.5,true)
			if game.controller.using_gamepad:
				game.controller.Glyphs.draw_sequence(hud,at+Vector2(-9,-19),game.controller.label_for(KEY_Q),game.controller.family,hud.font,18,9)
			else: hud.center(OS.get_keycode_string(game.match_menu.key_for(KEY_Q)),at+Vector2(0,-12),10,Color("9fcbe2"))
	if game.defending.presser>=0:
		var at: Vector2=game.screen_position(game.players[game.defending.presser].position+Vector3.UP*2.85)
		hud.center("PRES",at,11,Color("9fdfb6"))
	game.finishing.draw(hud)
