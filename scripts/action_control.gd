extends RefCounted
## Deliberate commands. Cancellation stops intentions, never a struck ball.
var game
var down: Dictionary = {}
var consumed: Dictionary = {}

func reset() -> void:
	down.clear(); consumed.clear()

func pending(index: int) -> bool:
	return game.charging or game.pass_charging or game.controller.combos.cross_player==index or game.kick_contact.pending.get("index",-1)==index or game.kick_contact.pending.get("user_pass",false) or game.finishing.active(index) or game.aerial_shot_active(index) or game.pass_buffer.pending.get("player",-1)==index

func actor() -> int:
	return game.kick_contact.pending.index if game.kick_contact.pending.get("user_pass",false) else game.controlled

func cancel() -> bool:
	if game.state=="set_piece" and game.human_team(game.restart_team) and game.active_team()==game.restart_team:
		return game.set_pieces.cancel_input()
	if game.state!="playing": return false
	var index: int=actor()
	var p=game.players[index]
	var retained_control: bool=game.dribbler==index or p.dribble_motion.preparing
	var changed := pending(index)
	var restart: Dictionary={}
	if game.kick_contact.pending.get("index",-1)==index:
		restart=game.kick_contact.pending.get("restart",{})
		if game.kick_contact.pending.get("user_pass",false):
			game.passes[p.team]=maxi(0,game.passes[p.team]-1)
			game.ai_receivers[p.team]=-1; game.ai_pass_time[p.team]=0
			game.team_control.run_receiver=-1
			game.support.end_run(index)
		game.kick_contact.reset()
		p.kick_timer=0
		if index!=game.controlled: game.team_control.select(index)
	if game.finishing.active(index):
		game.finishing.clear_pending()
		if p.pose=="finish": p.action_timer=0; p.pose="run"
	game.heading.cancel(index); game.volleys.cancel(index); game.aerial_assist.cancel(index)
	if game.keeper_distribution.active(index) and not game.keeper_distribution.pending.released:
		game.keeper_distribution.reset(); p.set_piece_pose="carry"; changed=true
	if game.skills.active.has(index):
		var skill: Dictionary=game.skills.active[index]
		if skill.get("contacts",-1)==0 or skill.age==0:
			game.skills.cancel(index); p.skill_cooldown=.12; changed=true
	if not changed: return false
	game.cancel_pass(); game.charging=false; game.charge=0
	game.finishing.style=""; game.shot_finesse=false; game.shot_chip=false
	p.shot_preparation=0; p.wrapping=0; p.aerial_preparing=false
	p.ball_actions.contact_pending=false; p.ball_actions.support_foot=-1
	p.dribble_motion.release_collision()
	# Only retain genuinely reachable possession; no transform/velocity changes.
	if retained_control and p.action_timer<=0 and game.ball.held_by==null and not game.ball.pending_kick and game.ball.position.y<.6 and game.flat_distance(p.position,game.ball.position)<1.3 and game.last_touch==p.team and game.dribbler in [-1,index]:
		game.dribbler=index; game.carrier=index
	game.controller.combos.switch_pending=false
	if not restart.is_empty(): game.set_pieces.restore_cancelled(restart)
	return true

func fake() -> bool:
	if game.kick_contact.pending.has("restart"): return false
	var index: int=actor()
	var p=game.players[index]
	if not pending(index) or p.keeper or p.skill_cooldown>0 or game.ball.held_by!=null or game.ball.pending_kick or game.ball.position.y>.6 or game.flat_distance(p.position,game.ball.position)>1.3: return false
	var shot: bool=game.charging or game.finishing.active(index) or game.kick_contact.pending.get("kind","")=="shot"
	var side: float=game.advanced_controls.side()
	if not cancel(): return false
	return game.skills.start(index,"fake_shot" if shot else "fake_pass",side)

func handle(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		if game.controller.device!=event.device: game.controller.claim_device(event.device,true)
		if game.controller.device!=event.device: return false
		if event.pressed: down[event.button_index]=true
		else: down.erase(event.button_index)
		if consumed.has(event.button_index):
			if not event.pressed: consumed.erase(event.button_index)
			return true
	if game.state not in ["playing","set_piece"]: return false
	if event is InputEventKey:
		if not event.pressed or event.echo: return false
		if event.keycode==KEY_B: cancel(); return true
		if game.state=="set_piece": return false
		if event.keycode in [KEY_N,KEY_I]: game.support.command(event.keycode==KEY_I); return true
		if event.keycode in [KEY_S,KEY_Z] and pending(game.controlled) and fake(): return true
	elif event is InputEventJoypadButton and event.pressed:
		var b: int=event.button_index
		var pad=game.controller
		pad.using_gamepad=true
		var lb: bool=down.has(JOY_BUTTON_LEFT_SHOULDER)
		var rb: bool=down.has(JOY_BUTTON_RIGHT_SHOULDER)
		var used := false
		var arrows := [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT]
		if game.state=="set_piece" and game.human_team(game.restart_team) and game.active_team()==game.restart_team and lb and b in arrows:
			game.set_pieces.routines.select(game.set_pieces,arrows.find(b)); used=true
		elif b in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER] and lb and rb:
			cancel(); pad.combos.switch_pending=false; used=true
		elif game.state=="playing" and lb and b in [JOY_BUTTON_RIGHT_STICK,JOY_BUTTON_LEFT_STICK]:
			game.support.command(b==JOY_BUTTON_LEFT_STICK); pad.combos.switch_pending=false; used=true
		elif game.state=="playing" and pad.bindings.get(b)==KEY_S and pending(game.controlled): used=fake()
		if used:
			consumed[b]=true; pad.using_gamepad=true; game.aiming_mouse=false
			return true
	return false
