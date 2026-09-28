extends RefCounted
const OPEN_GAP := 1.05
const POKE_REACH := 1.35
const OPEN_POKE_REACH := 1.72
const POKE_BALL := 0.32
const OPEN_POKE_BALL := 0.46
const POKE_BODY_SLACK := 0.10
const OPEN_POKE_BODY_SLACK := 0.38
const STEAL_REACH := 0.72
const OPEN_STEAL_REACH := 1.02
const STEAL_MARGIN := 0.18
const OPEN_STEAL_MARGIN := 0.06
var game
var attempts: Dictionary = {}
var feint_side := 1.0

func reset() -> void:
	attempts.clear()
	for p in game.players:
		p.protecting=false
		p.jockeying=false
		p.feint_time=0
		p.skill_cooldown=0
		p.defensive_turn_load=0
		p.tackle_recovery=0

func shield_direction(index: int) -> Vector3:
	var p=game.players[index]
	var direction: Vector3=p.facing
	var nearest := 4.0
	for q in game.players:
		if not q.visible or q.team==p.team: continue
		var distance: float=game.flat_distance(p.position,q.position)
		if distance<nearest:
			nearest=distance
			direction=((p.position-q.position)*Vector3(1,0,1)).normalized()
	return direction

func ball_opened(owner: int) -> bool:
	if owner<0: return true
	var p=game.players[owner]
	if p.active_sprint: return true
	return game.flat_distance(p.position,game.ball.position)>OPEN_GAP

func steal_reach(owner: int) -> float:
	return OPEN_STEAL_REACH if ball_opened(owner) else STEAL_REACH

func steal_margin(owner: int) -> float:
	return OPEN_STEAL_MARGIN if ball_opened(owner) else STEAL_MARGIN

func poke_reach(owner: int) -> float:
	# The tackle reach follows the resized body, just like the visible leg.
	# Sprinting exposes the ball; it must not grant a two-metre invisible boot.
	return (OPEN_POKE_REACH if ball_opened(owner) else POKE_REACH)*preload("res://scripts/footballer.gd").WORLD_SCALE

func poke_ball_radius(owner: int) -> float:
	return OPEN_POKE_BALL if ball_opened(owner) else POKE_BALL

func poke_body_slack(owner: int) -> float:
	return OPEN_POKE_BODY_SLACK if ball_opened(owner) else POKE_BODY_SLACK

func ball_exposed(challenger: int,owner: int) -> bool:
	if owner<0 or ball_opened(owner) or not game.players[owner].protecting: return true
	var a: Vector3=game.players[challenger].position*Vector3(1,0,1)
	var b: Vector3=game.ball.position*Vector3(1,0,1)
	var body: Vector3=game.players[owner].position*Vector3(1,0,1)
	var near := Geometry3D.get_closest_point_to_segment(body,a,b)
	return near.distance_to(body)>0.48 or a.distance_to(b)<a.distance_to(body)

func pressure_target(index: int,owner: int) -> Vector3:
	# Go around a shielding body, or stay alongside a runner. The ordinary
	# goal-side target still handles frontal pressure and distant recovery.
	if owner<0 or owner==index: return Vector3.INF
	var p=game.players[index]
	var q=game.players[owner]
	var offset: Vector3=(p.position-q.position)*Vector3(1,0,1)
	if p.team==q.team or offset.length()>3.2 or q.keeper: return Vector3.INF
	var motion: Vector3=q.velocity*Vector3(1,0,1)
	# Short walking turns are handled by the close-ball target. Orbiting a
	# slowly circling carrier would keep chasing his hip instead of the ball.
	if not q.protecting and motion.length()>.6 and motion.length()<2.2: return Vector3.INF
	var forward: Vector3=motion.normalized() if motion.length()>1.2 and not q.protecting else q.facing
	var right := forward.cross(Vector3.UP).normalized()
	var lateral := offset.dot(right)
	var body: Vector3=q.position*Vector3(1,0,1)
	var start: Vector3=p.position*Vector3(1,0,1)
	var ball: Vector3=game.ball.position*Vector3(1,0,1)
	var blocked := Geometry3D.get_closest_point_to_segment(body,start,ball).distance_to(body)<.48 and offset.length()+.12<start.distance_to(ball)
	var alongside := motion.length()>1.2 and absf(offset.dot(forward))<1.1 and absf(lateral)>.45
	if not blocked and not alongside: return Vector3.INF
	var side := signf(lateral) if absf(lateral)>.12 else (-1.0 if index%2==0 else 1.0)
	# Get the tackling foot level with the next touch after closing the side
	# gap. Merely matching the hip leaves a 120 ms poke behind a moving ball.
	var style := pressure_profile(p)
	var lead: float=lerpf(.58,.36,style.body) if motion.length()>1.2 and not q.protecting else .18
	return q.position+right*side*lerpf(.96,.82,style.body)+forward*lead

func pressure_profile(p) -> Dictionary:
	var strength: float=p.Attributes.value(p,"strength")
	var agility: float=p.Attributes.value(p,"agility")
	var reading: float=p.Attributes.technique(p.Attributes.value(p,"tackling")*.65+p.Attributes.value(p,"reactions")*.35)
	return {"body":clampf((strength-agility+14)/42.0,0,1),"reading":reading}

func reaction_time(index: int) -> float:
	var p=game.players[index]
	return game.management.reaction(p.team,index,true)*lerpf(1.10,.82,pressure_profile(p).reading)

func prefers_shoulder(index: int,owner: int) -> bool:
	if not ai_can_shoulder(index,owner): return false
	# Nimble markers wait for the foot opening; stronger markers can lean on
	# a protected runner. Both still obey the same safe angle and speed gates.
	return pressure_profile(game.players[index]).body>=.35 or ball_opened(owner)

func spacing_radius(a: int,b: int) -> float:
	var owner: int=game.dribbler
	if owner<0 or (a!=owner and b!=owner): return 1.2
	var challenger: int=b if a==owner else a
	var p=game.players[challenger]
	if p.team==game.players[owner].team or p.keeper or p.dismissed: return 1.2
	if game.ball.held_by!=null or game.flat_distance(game.players[owner].position,game.ball.position)>1.65: return 1.2
	var pressing: bool=game.team_tactics.pressers[p.team]==challenger or game.defending.presser==challenger or game.is_user_player(challenger)
	# Let the actual opponents meet, while keeping teammate spacing and a
	# minimum body gap. Character collisions and paired pressure remain active.
	return .82 if pressing else 1.2

func ai_can_shoulder(index: int,owner: int) -> bool:
	if owner<0 or owner==index: return false
	var p=game.players[index]
	var q=game.players[owner]
	if p.team==q.team or q.keeper or not q.visible or q.dismissed: return false
	var offset: Vector3=(p.position-q.position)*Vector3(1,0,1)
	if offset.length()<.1 or offset.length()>1.10 or game.flat_distance(q.position,game.ball.position)>1.4: return false
	var side := offset.normalized()
	var angle := side.dot(q.facing)
	var closing: float=maxf(0,(p.velocity-q.velocity).dot(-side))
	var cautious: bool=p.yellow_cards>0 or q.position.z*game.attack_sign(p.team)<-30
	# A legal, controlled side challenge remains available near our own goal.
	# Never turn rear pressure or a head-on charge into an automatic shove.
	if absf(angle)>(.30 if cautious else .48) or closing>(1.5 if cautious else 2.8): return false
	var motion: Vector3=q.velocity*Vector3(1,0,1)
	var following: Vector3=p.velocity*Vector3(1,0,1)
	return motion.length()>1 and following.length()>1 and motion.normalized().dot(following.normalized())>.65 and ball_exposed(index,owner)

func feint(index: int,chosen_side: float=0) -> void:
	var p=game.players[index]
	if game.dribbler!=index or p.action_timer>0 or p.skill_cooldown>0 or p.energy<0.06: return
	if game.is_user_player(index):
		game.cancel_pass()
		game.charging=false
	feint_side=signf(chosen_side) if absf(chosen_side)>.1 else -feint_side
	p.feint_side=feint_side
	p.feint_time=0.48
	p.skill_cooldown=0.85
	p.energy=maxf(0,p.energy-0.035)

func push_ahead(index: int) -> void:
	var p=game.players[index]
	if game.dribbler!=index or p.action_timer>0 or p.skill_cooldown>0 or p.energy<0.05: return
	if game.is_user_player(index):
		game.clear_pass_request()
		game.charging=false
	if game.strike(index,p.facing*clampf(Vector2(p.velocity.x,p.velocity.z).length()+4.5,7,13)+Vector3.UP*0.12):
		p.skill_cooldown=0.8
		p.energy=maxf(0,p.energy-0.025)

func standing_tackle(index: int) -> void:
	var p=game.players[index]
	if not p.visible or p.dismissed or game.dribbler==index: return
	if p.action_timer>0 or p.tackle_cooldown>0:
		game.skills.explain(index,"TOPARLANIYOR · YENİ HAMLE İÇİN %.1f sn" % maxf(p.action_timer,p.tackle_cooldown))
		game.playtest.event("tackle_rejected",index,{"recovery":maxf(p.action_timer,p.tackle_cooldown)})
		return
	var facing: Vector3=(game.ball.position-p.position)*Vector3(1,0,1)
	if facing.length()>0.1: p.facing=facing.normalized()
	p.pose="poke"
	p.tackle_foot=p.ball_actions.choose_foot(p,game.ball.position)
	p.tackle_target=game.ball.position
	p.action_timer=0.38
	p.poke_recovery_duration=0
	p.tackle_cooldown=0.85
	p.sprinting=false
	attempts[index]=0.0
	game.playtest.event("tackle_attempt",index)

func resolve(delta: float) -> void:
	for i in attempts.keys():
		var p=game.players[i]
		if p.pose!="poke" or p.action_timer<=0: attempts.erase(i); continue
		attempts[i]+=delta
		if attempts[i]<0.12: continue
		attempts.erase(i)
		var a: Vector3=p.position*Vector3(1,0,1)
		var owner: int=game.dribbler
		var end: Vector3=a+p.facing*poke_reach(owner)*tackle_reach(p)
		var ball: Vector3=game.ball.position*Vector3(1,0,1)
		var victim := -1
		var body_distance := INF
		var body_offset := INF
		for j in range(game.players.size()):
			var q=game.players[j]
			if not q.visible or q.team==p.team: continue
			var body: Vector3=q.position*Vector3(1,0,1)
			var offset := Geometry3D.get_closest_point_to_segment(body,a,end).distance_to(body)
			if offset<0.43 and a.distance_to(body)<body_distance:
				victim=j
				body_distance=a.distance_to(body)
				body_offset=offset
		var boot: Vector3=(p.left_knee if p.tackle_foot==0 else p.right_knee).to_global(p.ball_actions.BOOT)
		var reaches_ball: bool=Geometry3D.get_closest_point_to_segment(ball,a,end).distance_to(ball)<poke_ball_radius(owner) and boot.distance_to(game.ball.position)<.53 and game.ball.position.y<0.75
		if reaches_ball and (victim<0 or a.distance_to(ball)<body_distance+poke_body_slack(owner)) and ball_exposed(i,owner):
			var direction: Vector3=p.facing
			if owner>=0 and owner!=i:
				# The side of the real boot contact determines the loose ball.
				# Avoid poking straight back through the carrier's feet.
				var away: Vector3=(ball-game.players[owner].position*Vector3(1,0,1)).normalized()
				if away.length()>.1: direction=(direction*.35+away*.65).normalized()
			var control: float=p.Attributes.skill(p,"tackling")
			var incoming: Vector3=game.ball.linear_velocity*Vector3(1,0,1)
			var output: Vector3=direction*lerpf(4.8,3.5,control)+incoming.limit_length(8)*.12
			if game.strike(i,output+Vector3.UP*.15,0,false,"ball_tackle"):
				# A clean plant can follow the ball sooner than a missed lunge.
				# Possession still requires the next actual control opportunity.
				p.action_timer=minf(p.action_timer,lerpf(.16,.10,control))
				p.poke_recovery_duration=p.action_timer
				p.touch_cooldown=minf(p.touch_cooldown,.16)
				game.playtest.event("tackle_clean",i,{"speed":output.length()})
			continue
		# Missing commits the same recovery for humans and AI, even if no body
		# was hit. A late sidestep earns space without granting ball immunity.
		game.playtest.event("tackle_miss",i,{"gap":a.distance_to(ball),"fatigue":p.match_fatigue})
		p.tackle_recovery=lerpf(.78,.42,p.Attributes.technique(float(p.attributes.get("defending",72))*.75+p.Attributes.value(p,"tackling")*.25))+p.match_fatigue*.3
		p.tackle_cooldown=maxf(p.tackle_cooldown,.95)
		p.recovery_delay=maxf(p.recovery_delay,.75)
		p.energy=maxf(0,p.energy-.012)
		if victim>=0 and body_distance<1.05:
			var q=game.players[victim]
			var from_victim: Vector3=(a-q.position*Vector3(1,0,1)).normalized()
			var behind: bool=from_victim.dot(q.facing)<-0.48
			var closing: float=maxf(0,(p.velocity-q.velocity).dot(-from_victim))
			var late: bool=a.distance_to(ball)>poke_reach(owner)+0.25 or game.ball.position.y>1.1
			# A missed poke beside the carrier is a duel, not an automatic trip.
			# Penalize a foot through the legs from behind, a late lunge or a forceful charge.
			var trip: bool=body_offset<0.27 and (behind or late or closing>7.5)
			if trip:
				game.tackle_impact(i,victim)
				if not game.training: game.rules.foul(i,victim,closing>10.0 and (behind or late))
			else:
				q.body_language.contact(q,-from_victim,0.25)
				p.velocity*=0.88

func ai_poke_window(index: int,owner: int) -> bool:
	var p=game.players[index]
	# A poke commits for 120 ms. If a runner will have already left its path,
	# keep moving and get alongside instead of repeatedly stabbing behind him.
	var slow_ball: bool=game.ball.linear_velocity.length()<5
	var start: Vector3=p.position*Vector3(1,0,1)+p.velocity*Vector3(1,0,1)*(.02 if slow_ball else .065)
	var now: Vector3=game.ball.position*Vector3(1,0,1)
	# Less composed readers stab at where the ball is now. Better readers
	# allow for the boot's 120 ms approach, so a cut can punish an early poke.
	var reading: float=pressure_profile(p).reading
	var future: Vector3=now+game.ball.linear_velocity*Vector3(1,0,1)*lerpf(.045,.12,reading)
	var aim: Vector3=(now-p.position*Vector3(1,0,1)).normalized()
	var reach: float=poke_reach(owner)*tackle_reach(p)
	var end: Vector3=start+aim*reach
	# Against a slow ball, step into the boot's reach before committing. The
	# wider sweep tolerance is for a moving ball, not extra stationary leg length.
	if slow_ball and future.distance_to(start)>reach: return false
	var confidence: float=lerpf(.88,.96,reading)
	return Geometry3D.get_closest_point_to_segment(future,start,end).distance_to(future)<poke_ball_radius(owner)*confidence

static func tackle_reach(p) -> float:
	var reach: float=p.Attributes.multiplier(float(p.attributes.get("defending",72))*.4+p.Attributes.value(p,"tackling")*.6,.075)
	return reach*(1.08 if p.Attributes.has_style(p,"anticipate") else 1.0)

func ai_can_challenge(index: int,owner: int,sliding: bool=false) -> bool:
	if owner<0: return false
	var p=game.players[index]
	var q=game.players[owner]
	var start: Vector3=p.position*Vector3(1,0,1)
	var ball: Vector3=game.ball.position*Vector3(1,0,1)
	var body: Vector3=q.position*Vector3(1,0,1)
	var near := Geometry3D.get_closest_point_to_segment(body,start,ball)
	var blocked := near.distance_to(body)<(0.64 if sliding else 0.36) and start.distance_to(body)+0.15<start.distance_to(ball)
	if blocked or not ball_exposed(index,owner): return false
	if p.team==1:
		var box: bool=absf(body.x)<20.16 and body.z*game.attack_sign(p.team)<-33.5
		var cautious: bool=box or p.yellow_cards>0
		var facing: Vector3=(start-body).normalized()
		var behind: bool=facing.dot(q.facing)<-.35
		var closing: float=maxf(0,(p.velocity-q.velocity).dot(-facing))
		# Penalize the attempted path through a leg, not the result of a dice roll.
		var clearance: float=near.distance_to(body)
		var first_to_ball: bool=start.distance_to(ball)+.18<start.distance_to(body)
		if cautious and (behind or closing>7.0 or (clearance<.62 and not first_to_ball)): return false
		if sliding and (p.yellow_cards>0 or (box and (clearance<.95 or not first_to_ball))): return false
	# AI slides only into a loose, reachable ball; jockeying handles protected possession.
	return not sliding or (ball_opened(owner) and game.ball.position.y<0.65 and start.distance_to(ball)<2.2)

func switch_choice() -> int:
	# LB/Q means the next nearby challenger. Directional selection belongs to
	# the right stick, so running with the left stick cannot redirect this button.
	return game.team_control.switch_choice()
