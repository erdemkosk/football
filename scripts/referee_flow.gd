extends RefCounted
## End a period after its last live incident, never before its contact/goal.
## Finishing a promising attack is a bounded game-flow choice. The mandatory
## exception is an end-of-period penalty, which must be completed.
const ATTACK_WINDOW := 8.0
const SHOT_WINDOW := 3.0
var game
var period := -1
var attacking_team := -1
var late_age := 0.0
var protected_restart := -1
var penalty_team := -1
var penalty_taker := -1
var penalty_kicked := false
var penalty_done := false
var period_complete := false

func reset() -> void:
	period=-1; attacking_team=-1; late_age=0; protected_restart=-1
	penalty_team=-1; penalty_taker=-1; penalty_kicked=false; penalty_done=false
	period_complete=false

func sync_period() -> void:
	var current: int=game.management.period_index()
	if period==current: return
	reset(); period=current

func due() -> bool:
	return not game.training and game.match_time>=game.management.half_end()

func allow_recalled_foul(team: int) -> void:
	sync_period()
	if game.match_time>=game.management.half_end()-3.0: protected_restart=team

func restarting(kind: String,team: int) -> void:
	sync_period()
	if penalty_team>=0 and penalty_kicked and due() and kind!="PENALTI": period_complete=true
	if kind=="PENALTI":
		penalty_team=team; penalty_taker=-1; penalty_kicked=false; penalty_done=false
	else:
		penalty_team=-1; penalty_taker=-1; penalty_kicked=false; penalty_done=false
	if kind not in ["SERBEST VURUŞ","PENALTI"] or team!=protected_restart: protected_restart=-1

func taking(kind: String,team: int,taker: int) -> void:
	sync_period()
	if kind=="PENALTI":
		penalty_team=team; penalty_taker=taker; penalty_kicked=false; penalty_done=false

func kicked(index: int) -> void:
	if game.players[index].team==protected_restart:
		attacking_team=protected_restart; protected_restart=-1
	if index==penalty_taker: penalty_kicked=true

func scored() -> void:
	# Count the goal and show its celebration, then finish without requiring
	# a ceremonial kickoff or adding the celebration to an expired period.
	sync_period()
	if due(): period_complete=true

func before_touch(index: int) -> bool:
	if penalty_team<0 or not penalty_kicked or penalty_done: return true
	var p=game.players[index]
	if p.keeper and p.team!=penalty_team: return true
	penalty_done=true
	# In an extended penalty, no rebound kick by an outfielder is allowed.
	if due(): finish(); return false
	return true

func velocity() -> Vector3:
	return game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity

func shot_in_flight(team: int) -> bool:
	var shooter: int=game.reactions.shooter
	if shooter<0 or game.players[shooter].team!=team or game.reactions.shot_age>3.0: return false
	if game.ball.held_by!=null: return false
	var motion := velocity()
	var f: float=game.attack_sign(team)
	if motion.z*f<=2: return false
	var time: float=(game.P.HALF_LENGTH+game.Ball.RADIUS-game.ball.position.z*f)/(motion.z*f)
	return time>=0 and time<3.0 and absf(game.ball.position.x+motion.x*time)<9.0

func promising(team: int) -> bool:
	if team<0 or game.ball.held_by!=null: return false
	if shot_in_flight(team): return true
	var pending: Dictionary=game.kick_contact.pending
	if not pending.is_empty() and game.players[pending.index].team==team and pending.get("kind","") in ["shot","finish","volley","header","half_volley"]:
		return game.flat_distance(game.ball.position,Vector3(0,0,game.attack_sign(team)*50))<34
	var ball: Vector3=game.ball.position
	var f: float=game.attack_sign(team)
	if ball.z*f<26 or absf(ball.x)>27: return false
	var owner: int=game.dribbler
	if owner>=0:
		var p=game.players[owner]
		if p.team!=team or not p.visible or p.dismissed: return false
		return p.velocity.z*f>.7 or (ball.z*f>35 and absf(ball.x)<20 and p.facing.z*f>.1)
	# Crosses, forward deliveries and rebounds inside the box stay live.
	return velocity().z*f>.8 or (ball.z*f>35 and absf(ball.x)<20 and velocity().length()>1)

func update(delta: float) -> void:
	if game.training or game.state not in ["playing","restart","set_piece"]: return
	sync_period()
	if period_complete: finish(); return
	if not due(): return
	if not game.rules.advantage.is_empty(): return
	if protected_restart>=0: return
	if penalty_team>=0 and not penalty_done:
		if not penalty_kicked: return
		if game.ball.pending_kick: return
		if game.ball.held_by==null and velocity().length()>.45: return
		penalty_done=true
		finish(); return
	if game.state!="playing": finish(); return
	if game.ball.held_by!=null: finish(); return
	if attacking_team<0:
		var owner: int=game.dribbler
		var team: int=game.players[owner].team if owner>=0 else game.last_touch
		# A keeper/defender's loose deflection is not won possession and must
		# not erase an on-target shot just as the clock runs out.
		var shooter: int=game.reactions.shooter
		if owner<0 and shooter>=0 and shot_in_flight(game.players[shooter].team): team=game.players[shooter].team
		if not promising(team): finish(); return
		attacking_team=team
	late_age+=delta
	var owner: int=game.dribbler
	if owner>=0 and game.players[owner].team!=attacking_team: finish(); return
	if not promising(attacking_team): finish(); return
	# Possession in the box must not keep the match alive indefinitely.
	if late_age>=ATTACK_WINDOW and not (late_age<ATTACK_WINDOW+SHOT_WINDOW and shot_in_flight(attacking_team)):
		finish()

func finish() -> void:
	if game.state not in ["playing","restart","set_piece","goal"]: return
	game.rules.advantage.clear()
	game.rules.show_deferred_cards()
	if not game.career.cups.extra_active() and game.half==1:
		game.interval.begin(); return
	if game.career.cups.period_end():
		sync_period(); return
	# Preserve visible added time, but absorb the final sub-tick at 90/120.
	var base: float=game.management.period_end_base()
	if game.match_time-base<.05: game.match_time=base
	game.state="finished"; game.ball.active=false
	game.charging=false; game.cancel_pass(); game.kick_contact.reset()
	game.referees.finish_match()
	game.broadcast_event("fulltime")
