extends RefCounted
## Contact quality of every foot and head strike. The governing technique, the
## striker's body and the incoming ball decide a bounded launch error at the
## real contact. The same contact always gives the same result (no dice roll),
## the preview arrow keeps showing the intended strike, and the ball is never
## steered after it leaves the boot or forehead.
const Attributes = preload("res://scripts/player_attributes.gd")
const Dimensions = preload("res://scripts/ball_dimensions.gd")
const SHOTS := ["shot","finish","volley","half_volley","header"]
const PASSES := ["kick","cross","pass","distribution","punt","header_pass","header_clearance"]
## Charge beyond this point trades accuracy for pace. Full power from range can
## clear the bar; a placed strike is the more accurate one.
const OVERHIT_START := .72
const MAX_YAW := 0.2443461 # 14 degrees.
var game
## Gameplay-setting scales per team (0 = user side, 1 = opponent).
var shot_error_scale := [1.0,1.0]
var pass_error_scale := [1.0,1.0]
var shot_speed_scale := [1.0,1.0]
## Situational pressure a restart adds (penalties), consumed by the contact.
var extra_pressure: Dictionary = {}
var last: Dictionary = {}

func reset() -> void:
	extra_pressure.clear(); last.clear()

static func overhit(effort: float,power_style: bool=false) -> float:
	return smoothstep(OVERHIT_START+(.06 if power_style else 0.0),1.0,effort)

## Risk shown on the power meter before release: how far the current charge
## lifts an average strike from this range.
static func overhit_risk(effort: float,range_to_goal: float,power_style: bool=false) -> float:
	return overhit(effort,power_style)*smoothstep(8,18,range_to_goal)

func apply(index: int,velocity: Vector3,kind: String,curve: float=0.0) -> Vector3:
	var p=game.players[index]
	var effort: float=p.strike_effort
	var timing: float=p.strike_timing
	p.strike_effort=-1.0; p.strike_timing=1.0
	if not (kind in SHOTS or kind in PASSES): return velocity
	last=assess(index,velocity,kind,effort,timing,curve)
	return last.velocity

func assess(index: int,velocity: Vector3,kind: String,effort: float=-1.0,timing: float=1.0,curve: float=0.0) -> Dictionary:
	var p=game.players[index]
	var ball: Vector3=game.ball.position
	var flat := Vector3(velocity.x,0,velocity.z)
	var speed := flat.length()
	var pressure_bonus: float=float(extra_pressure.get(index,0.0))
	extra_pressure.erase(index)
	if speed<2.5: return {"velocity":velocity,"intended":velocity,"yaw":0.0,"lift":0.0,"challenge":0.0,"skill":1.0,"over":0.0,"limit":0.0,"kind":kind,"index":index}
	var aim := flat/speed
	var header: bool=kind.begins_with("header")
	var shot: bool=kind in SHOTS
	var volley: bool=kind in ["volley","half_volley"]
	var goal := Vector3(0,0,game.attack_sign(p.team)*50)
	var range_to_goal: float=game.flat_distance(ball,goal)
	if effort<0: effort=clampf((speed-17.0)/15.0,0,1) if shot and not header else clampf((speed-8.0)/24.0,0,1)
	var lofted: bool=velocity.y>3.5
	# The technique that governs this contact.
	var skill: float
	if header: skill=Attributes.skill(p,"heading")*.8+Attributes.skill(p,"jumping")*.2
	elif volley: skill=lerpf(Attributes.skill(p,"finishing"),Attributes.skill(p,"volleys"),.6)
	elif shot: skill=lerpf(Attributes.skill(p,"finishing"),Attributes.skill(p,"long_shots"),smoothstep(16,27,range_to_goal))
	elif kind=="cross": skill=Attributes.skill(p,"crossing")
	elif kind in ["distribution","punt"]: skill=Attributes.skill(p,"kicking")
	else: skill=lerpf(Attributes.skill(p,"passing"),Attributes.skill(p,"vision"),clampf(smoothstep(16,28,speed)+(.25 if lofted else 0.0),0,1))
	# Every term below is visible on the pitch.
	var pressure: float=maxf(game.first_touch.pressure(index),pressure_bonus)
	var composure: float=Attributes.skill(p,"composure")
	if Attributes.has_style(p,"press_proven"): composure=lerpf(composure,1.0,.4)
	var run: Vector3=p.velocity*Vector3(1,0,1)
	var pace := run.length()
	var across := 0.0
	if pace>1.2: across=clampf((1.0-run.normalized().dot(aim))*.5,0,1)*smoothstep(1.2,6.5,pace)
	var sprint: float=1.0 if p.active_sprint else smoothstep(4.8,7.8,pace)*.6
	var first_time := 0.0
	if game.dribbler!=index and not header: first_time=smoothstep(5.0,18.0,((game.ball.linear_velocity-p.velocity)*Vector3(1,0,1)).length())
	var height: float=0.0 if header or volley else smoothstep(.30,1.0,ball.y-Dimensions.GROUND_HEIGHT)
	var weak := 0.0
	if not header: weak=1.0-Attributes.foot_quality(p,p.ball_actions.choose_foot(p,ball))
	var duel: float=clampf(p.contest_weight,0,1)
	var tired: float=clampf((1.0-p.energy)*.6+p.match_fatigue,0,1)
	var over: float=overhit(effort,Attributes.has_style(p,"power_shot")) if shot and not header else 0.0
	var challenge: float=pressure*(1.25*(1.0-composure)+.25)+across*1.1+sprint*.45+first_time*.7+height*.8+weak*2.2+duel*.6+tired*.35+over*.45
	if timing>1.0: challenge*=.6
	# Spread of the launch direction in degrees: shots always carry some,
	# ordinary short passes only when something makes the contact difficult.
	var clean: float
	var spread: float
	if header: clean=lerpf(9.0,2.4,skill); spread=clean
	elif volley: clean=lerpf(7.5,1.8,skill); spread=clean
	elif shot: clean=lerpf(6.0,1.2,skill)*lerpf(.8,1.0,smoothstep(.3,OVERHIT_START,effort)); spread=clean
	elif kind=="cross": clean=lerpf(2.6,.45,skill); spread=lerpf(4.0,.8,skill)
	else: clean=lerpf(1.4,.12,skill)*smoothstep(18,32,speed)*(1.0 if lofted else 0.0); spread=lerpf(3.2,.45,skill)
	var tier := 1.0
	if shot and not header and absf(curve)>.1 and Attributes.has_style(p,"finesse"): tier=.75
	elif shot and not header and velocity.y>6.5 and Attributes.has_style(p,"chip"): tier=.65
	elif header and Attributes.has_style(p,"aerial"): tier=.75
	elif kind=="cross" and Attributes.has_style(p,"whipped"): tier=.7
	elif kind in ["distribution","punt"] and Attributes.has_style(p,"footwork"): tier=.7
	elif not shot and not header and (lofted or speed>18) and Attributes.has_style(p,"incisive"): tier=.7
	var scale: float=float((shot_error_scale if shot else pass_error_scale)[clampi(p.team,0,1)])
	var yaw_limit: float=minf(deg_to_rad((clean*(1.0+challenge) if shot else clean+spread*challenge)*tier*scale),MAX_YAW)
	var lift_limit := 0.0
	var bias := 0.0
	if shot:
		lift_limit=lerpf(1.3,.3,skill)*(1.0+challenge*.8)*tier*scale
		if not header: bias=pow(over,1.6)*lerpf(4.0,1.6,skill)*smoothstep(8,18,range_to_goal)*scale
	elif lofted: lift_limit=lerpf(.9,.12,skill)*challenge*tier*scale
	# Weight of pass: only lofted or long balls can be over- or under-hit.
	var speed_limit: float=0.0 if shot or not (lofted or speed>20) else lerpf(.05,.01,skill)*minf(challenge,1.5)*tier*scale
	# Deterministic contact noise: the same body, ball and strike reproduce the
	# same launch, including in tests and replays.
	var noise := RandomNumberGenerator.new()
	noise.seed=hash([int(p.appearance_id),index,kind,Vector3i((ball*24).round()),Vector3i((p.position*24).round()),Vector3i((velocity*6).round())])
	var yaw: float=(noise.randf()+noise.randf()-1.0)*yaw_limit
	var lift: float=bias+(noise.randf()+noise.randf()-1.0)*lift_limit
	var pace_scale: float=1.0+(noise.randf()+noise.randf()-1.0)*speed_limit
	if shot: pace_scale*=float(shot_speed_scale[clampi(p.team,0,1)])
	var result: Vector3=flat.rotated(Vector3.UP,yaw)*pace_scale+Vector3.UP*(velocity.y+lift)
	return {"velocity":result,"intended":velocity,"yaw":yaw,"lift":lift,"challenge":challenge,"skill":skill,"over":over,"limit":yaw_limit,"kind":kind,"index":index}
