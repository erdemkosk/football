extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
var game

func expected(index: int) -> bool:
	var team: int=game.players[index].team
	return game.ai_receivers[team]==index and game.ai_pass_time[team]>0 and game.last_touch==team and game.last_kicker!=index

func assigned(index: int) -> bool:
	return expected(index) or game.incoming_receiver==index

## First touch into space: V / R3 just before the ball arrives turns the
## receiving touch into a push along the chosen direction. It is still one
## physical contact; the ball runs free and must be chased.
var knocks: Dictionary = {}

func request_knock(index: int) -> bool:
	var p=game.players[index]
	var gap: float=game.flat_distance(p.position,game.ball.position)
	var incoming: Vector3=game.ball.linear_velocity*Vector3(1,0,1)
	if game.ball.held_by!=null or game.dribbler==index or gap<.9 or gap>16 or incoming.length()<3: return false
	if incoming.normalized().dot(((p.position-game.ball.position)*Vector3(1,0,1)).normalized())<.6: return false
	knocks[index]=.55
	game.skills.explain(index,"İLK DOKUNUŞTA AÇ · YÖN VER")
	return true

func prepare(delta: float=1.0/120.0) -> void:
	for i in knocks.keys():
		knocks[i]-=delta
		if knocks[i]<=0: knocks.erase(i)
	# Assigned receivers open toward the ball like a broadcast receive, not a
	# wait-and-hope stance. Manual steering still owns facing.
	for i in range(game.players.size()):
		var p=game.players[i]
		prepare_intent(i,delta)
		p.receiving_facing=Vector3.ZERO
		if game.ball.held_by!=null or game.ball.pending_reset: continue
		if not p.visible or p.keeper or p.action_timer>0 or p.kick_timer>0 or game.aerial_shot_active(i) or game.dribbler>=0: continue
		if game.is_user_player(i) and game.movement_input().length()>.2: continue
		if game.is_user_player(i) and not assigned(i) and game.team_control.predicted_receiver!=i: continue
		var offset: Vector3=(game.ball.position-p.position)*Vector3(1,0,1)
		var waiting: bool=assigned(i)
		if offset.length()<.2 or offset.length()>(22.0 if waiting else 5.0): continue
		var relative: Vector3=(game.ball.linear_velocity-p.velocity)*Vector3(1,0,1)
		var time := clampf(-offset.dot(relative)/maxf(.01,relative.length_squared()),0,.65)
		if waiting or (time>0 and (offset+relative*time).length()<.8):
			p.receiving_facing=offset.normalized()
			if waiting and pressure(i)>0.52 and offset.length()<12.0 and not game.is_user_player(i):
				p.protecting=true
				var cover: Vector3=game.duels.shield_direction(i)
				if cover.length()>0.1: p.receiving_facing=cover.lerp(p.receiving_facing,0.55).normalized()

func prepare_intent(index: int,delta: float) -> void:
	var p=game.players[index]
	var action=p.ball_actions
	var offset: Vector3=(game.ball.position-p.position)*Vector3(1,0,1)
	var relative: Vector3=(game.ball.linear_velocity-p.velocity)*Vector3(1,0,1)
	if not p.visible or p.dismissed or p.action_timer>0 or game.ball.held_by!=null or game.last_kicker==index or game.dribbler>=0 or offset.length()>12 or offset.dot(relative)>=0:
		action.intent_age=0; action.intent_direction=Vector3.ZERO
		return
	var direction := control_intent(index)
	if direction.length()<.1:
		action.intent_age=0; action.intent_direction=Vector3.ZERO
		return
	action.intent_age=minf(.3,action.intent_age+delta) if direction.dot(action.intent_direction)>.92 else 0.0
	action.intent_direction=direction

func pressure(index: int) -> float:
	var p=game.players[index]
	var nearest := 3.0
	for q in game.players:
		if q.visible and q.team!=p.team: nearest=minf(nearest,game.flat_distance(p.position,q.position))
	return 1-smoothstep(0.6,2.7,nearest)

func airborne() -> bool:
	var ball=game.ball
	if ball.position.y<0.7 or ball.position.y>2.15 or ball.pending_kick or ball.held_by!=null: return false
	var best := -1
	var gap := 1.02
	for i in range(game.players.size()):
		var p=game.players[i]
		if game.dribbler==i and settling(i): continue
		if game.kick_lock>0 and i==game.last_kicker: continue
		if game.aerial_shot_active(i) or p.dummy_time>0 or p.nutmeg_time>0: continue
		if not p.visible or p.keeper or p.action_timer>0 or p.kick_timer>0 or p.touch_cooldown>0 or p.ball_actions.contact_cooldown>0: continue
		var offset: Vector3=(ball.position-p.position)*Vector3(1,0,1)
		if offset.length()>gap or ball.position.y>p.body_scale.y*1.75: continue
		if offset.length()>0.2 and offset.normalized().dot(p.facing)<-0.35: continue
		var relative: Vector3=ball.linear_velocity-p.velocity
		# Rising shots, departing passes and balls flying overhead are not traps.
		if relative.y>2.5 or relative.length()>22 or offset.dot(relative)>0.25: continue
		gap=offset.length(); best=i
	if best<0: return false
	if not game.rules.before_touch(best): return true
	game.dribbler=best if receive(best,false) else -1
	game.carrier=game.dribbler
	return true

func settling(index: int) -> bool:
	var p=game.players[index]
	return p.ball_actions.settle_time>0 and p.receive_timer>0 and p.touch_cooldown<=0 and p.dribble_motion.available(p)

func settle(index: int) -> bool:
	var p=game.players[index]
	var ball=game.ball
	if not settling(index): return false
	if absf(ball.position.x)>P.HALF_WIDTH+.2 or absf(ball.position.z)>50.2: return false
	if ball.position.y<=.6 and p.ball_actions.control_grace<=0: return false
	# Keep cushioning a thigh/chest trap until gravity brings it to the foot.
	# Re-enabling the solid torso between these two contacts caused ricochets.
	p.dribble_motion.control_collision(p,ball)
	p.dribble_motion.freshness=.07
	var offset: Vector3=(ball.position-p.position)*Vector3(1,0,1)
	var direction := control_intent(index)
	if direction.length_squared()<.1: direction=p.facing
	var right := direction.cross(Vector3.UP)
	var goal: Vector3=direction*.55+right*clampf(offset.dot(right),-.18,.18)
	var relative: Vector3=(ball.linear_velocity-p.velocity)*Vector3(1,0,1)
	ball.guide(((goal-offset)*100-relative*20).limit_length(85))
	return true

func receive(index: int,extended: bool) -> bool:
	var p=game.players[index]
	game.team_control.touched(index)
	var ball=game.ball
	var relative: Vector3=ball.linear_velocity-p.velocity
	var speed := relative.length()
	var height: float=(ball.position.y-p.position.y)/p.body_scale.y
	var style := "chest" if height>1.05 else ("thigh" if height>0.70 else "foot")
	var distance: float=game.flat_distance(p.position,ball.position)
	var reach := smoothstep(0.91,1.34,distance) if style=="foot" else 0.0
	var difficulty := clampf(reach*0.55+pressure(index)*0.22+(1-p.energy)*0.20+maxf(0,speed-12)*0.023,0,1)
	var stability: float=p.Attributes.multiplier(p.attributes.balance,.2)
	difficulty=clampf(difficulty+(72-float(p.attributes.control))*.0045+p.contest_weight*.16/stability,0,1)
	var technique := clampf((float(p.attributes.control)-45)/50,0,1)
	var foot: int=p.ball_actions.choose_foot(p,ball.position)
	var weaker: float=1.0-p.Attributes.foot_quality(p,foot)
	var preparation: float=smoothstep(.03,.16,p.ball_actions.intent_age)*technique
	# A prepared opening uses the instep with less recovery. A weak-foot,
	# sprinting reception remains playable but gives the defender more ball.
	difficulty=clampf(difficulty+weaker*.45-preparation*.14,0,1)
	# Reactions read the late bounce; composure keeps the touch under pressure.
	difficulty=clampf(difficulty+(72-p.Attributes.value(p,"reactions"))*.0018+pressure(index)*(.5-p.Attributes.skill(p,"composure"))*.12,0,1)
	if p.Attributes.has_style(p,"first_touch"): difficulty*=.75
	difficulty=clampf(difficulty*game.sliders.scale(p.team,"first_touch",.5,1.6),0,1)
	var offset: Vector3=(ball.position-p.position)*Vector3(1,0,1)
	var facing: Vector3=-p.rig.global_basis.z.normalized()
	var behind: bool=distance>.55 and offset.normalized().dot(facing)<-.55
	# Fatigue, technique and nearby pressure vary touch length, not whether a
	# routine pass is controllable. A spill needs difficult speed or geometry.
	var prepared := expected(index)
	var spill := speed>(32+technique*3 if prepared else 27+technique*3) or (behind and speed>(18+technique*4 if prepared else 7+technique*4))
	spill=spill or (extended and speed>20+technique*4) or (reach>.90 and speed>13+technique*6)
	spill=spill or (p.contest_weight>.65 and difficulty>.72 and speed>13)
	p.begin_receive(style,ball.position,relative,reach)
	p.ball_actions.receive_error=difficulty if not spill else maxf(.65,difficulty)
	p.ball_actions.receive_reason="ARKADA KALAN TOP" if behind else ("UZANARAK KONTROL" if reach>.6 else ("SERT GELEN TOP" if speed>20 else ("BASKI ALTINDA" if pressure(index)>.55 else "")))
	if spill:
		p.ball_actions.receive_feedback_time=1.2
		if p.ball_actions.receive_reason=="": p.ball_actions.receive_reason="DENGE KAYBI"
	p.ball_actions.control_grace=0.04 if style=="foot" else 0.22
	p.ball_actions.contact_cooldown=0.32 if spill else 0.25
	p.ball_actions.settle_time=0 if spill else (.5 if style=="foot" else .8)
	# One bounded impulse cushions the real rigid body. Hard, stretched touches
	# retain more incoming momentum; no transform snap or guaranteed possession.
	var retain := lerpf(0.025,0.14,difficulty)
	if spill: retain=maxf(retain,0.40)
	var output: Vector3=p.velocity*Vector3(1,0,1)+relative*retain
	var intent := control_intent(index)
	var knock: bool=knocks.has(index) and not spill and style=="foot" and intent.length_squared()>.1
	knocks.erase(index)
	if intent.length_squared()>.1:
		var opening: float=(lerpf(2.25,.95,technique)+(.50 if p.active_sprint else 0.0)+difficulty*.40+weaker*.9)*(1-preparation*.22)
		if knock: opening=maxf(opening*2.6,6.2)
		# Turn the incoming momentum with one limited impulse. A good technician
		# takes a compact touch; sprinting and poor control expose more ball.
		var directed: Vector3=p.velocity*Vector3(1,0,1)+intent*opening
		output=output.lerp(directed,1.0 if knock else lerpf(.55,.90,technique)*(0.45 if spill else 1.0))
		p.ball_actions.receive_direction=intent
		p.ball_actions.receive_distance=clampf(opening*.42,.45,3.0 if knock else 1.65)
		p.receive_duration*=1-preparation*.18
		p.receive_timer=p.receive_duration
	if spill:
		var side := -1.0 if p.ball_actions.receive_foot==0 else 1.0
		output+=p.rig.global_basis.x.normalized()*side*(0.8+difficulty*1.2)
	if style!="foot": output.y=clampf(relative.y*.2,-2,-.8)
	else: output.y=clampf(ball.linear_velocity.y*.15,-.6,.15)
	if not spill and not knock:
		# During the receive-to-dribble handover, the coarse torso capsule must
		# not strike a ball already cushioned by the foot. Other players still collide.
		p.dribble_motion.control_collision(p,ball)
		p.dribble_motion.freshness=p.ball_actions.control_grace+.02
	var cushion := lerpf(28,34,technique) if not spill else 17.0
	ball.touch(output,ball.mass*minf(cushion,maxf(2.5,speed*(1.08 if not spill else 0.60))))
	game.playtest.event("receive",index,{"spill":spill,"pressure":pressure(index),"speed":speed,"reason":p.ball_actions.receive_reason})
	game.reactions.received(index)
	game.last_touch=p.team
	game.last_kicker=index
	# The release lock belongs to the passer. A receiver's real contact ends
	# it; otherwise the next tick drops possession and restores torso collision.
	game.kick_lock=0
	if spill: p.touch_cooldown=maxf(p.touch_cooldown,0.25)
	# A knock into space leaves the ball free until the runner reaches it.
	if knock:
		p.touch_cooldown=maxf(p.touch_cooldown,0.45)
		return false
	return not spill

func control_intent(index: int) -> Vector3:
	var p=game.players[index]
	var input: Vector3=p.desired*Vector3(1,0,1)
	if p.protecting: return game.duels.shield_direction(index)
	if game.is_user_player(index):
		# The automatic meeting run is not a request for a directional touch.
		if game.team_control.awaiting_delivery(): input=game.movement_input()
		return input.normalized() if input.length()>.2 else Vector3.ZERO
	if game.ai_attack.pressure_read(index).urgency>.2:
		return ((game.ai_attack.carry_target(index)-p.position)*Vector3(1,0,1)).normalized()
	# AI receivers use the same touch, opening away from the closest pressure.
	var forward := Vector3(0,0,game.attack_sign(p.team))
	var space := forward
	for q in game.players:
		if not q.visible or q.team==p.team: continue
		var gap: Vector3=(p.position-q.position)*Vector3(1,0,1)
		if gap.length()>.1 and gap.length()<3: space+=gap.normalized()*(1-gap.length()/3)*1.4
	return space.normalized()
