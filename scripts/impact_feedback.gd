extends RefCounted
## Short contact cues run on match time; they never stop or accelerate the ball.
const P = preload("res://scripts/pitch_dimensions.gd")
const BallSize = preload("res://scripts/ball_dimensions.gd")
const POST_X := 3.66
const BAR_Y := 2.44
const WOODWORK_REACH := 0.36
var game
var age := 1.0
var duration := 0.28
var amplitude := 0.0
var axis := Vector3.RIGHT
var hurt := 0.0
var last_kind := ""
var event_count := 0
var woodwork_in := 0.0
var previous_velocity := Vector3.ZERO

func reset() -> void:
	age=1
	amplitude=0
	hurt=0
	last_kind=""
	event_count=0
	woodwork_in=0
	previous_velocity=Vector3.ZERO

func update(delta: float) -> void:
	age+=delta
	hurt=move_toward(hurt,0,delta*3.5)
	woodwork_in=maxf(0,woodwork_in-delta)

func offset() -> Vector3:
	if age>=duration: return Vector3.ZERO
	var envelope := pow(1-age/duration,2)
	return (axis*sin(age*53)+Vector3(0,0,1)*sin(age*37)*0.28)*amplitude*envelope

func net_contact(point: Vector3,direction: Vector3,strength: float) -> void:
	if game.menu_match.running or game.state not in ["playing","goal","restart","set_piece"]: return
	var scored: bool=game.state=="goal"
	game.audio.net_contact(strength,scored)
	last_kind="net"
	event_count+=1
	var nearby: bool=game.flat_distance(point,game.players[game.controlled].position)<18
	if not scored and not nearby: return
	age=0
	duration=lerpf(0.26,0.46,strength)
	amplitude=lerpf(0.035,0.22,strength)*(1.0 if scored else 0.4)
	axis=direction.normalized()
	if scored: game.controller.net_rumble(strength,game.goal_team==0)

func contact(kind: String,index: int,point: Vector3,direction: Vector3,strength: float,victim: int=-1,heavy: bool=false) -> void:
	last_kind=kind
	event_count+=1
	strength=clampf(strength,0,1)
	var nearby: bool=game.flat_distance(point,game.players[game.controlled].position)<16
	var personal: bool=game.is_user_player(index) or game.is_user_player(victim)
	var cue := "power" if heavy and kind in ["shot","header"] else ("shot" if kind=="header" else kind)
	game.audio.contact(cue,strength,1.0 if personal else (0.65 if nearby else 0.32))
	if personal: game.controller.rumble(strength*(1.15 if heavy else 1.0),kind in ["shot","header"],0.38 if heavy else -1.0)
	if personal or nearby:
		age=0
		duration=(lerpf(0.34,0.48,strength) if heavy else (0.23 if kind in ["shot","header"] else 0.30))
		amplitude=lerpf(0.18 if heavy else 0.055,0.32 if heavy else 0.19,strength)*(1.0 if personal else 0.35)
		if kind=="body_hit": amplitude*=1.25
		axis=Vector3(direction.x,0,direction.z).normalized()
		if axis.length()<0.1: axis=Vector3.RIGHT
	if victim==game.controlled and kind=="body_hit": hurt=0.3+strength*0.5
	if kind in ["shot","ball_tackle","body_hit"]:
		var wet: float=game.weather.wetness
		var mud: float=game.weather.mud_at(point)
		game.weather.splash(point,direction*5,4+int(strength*6),mud if wet>0.25 else 1.0)

func nearest_woodwork(point: Vector3) -> Dictionary:
	var best := INF
	var at := Vector3.ZERO
	var normal := Vector3.RIGHT
	for side in [-1.0,1.0]:
		var z: float=side*P.HALF_LENGTH
		for x in [-POST_X,POST_X]:
			var post := Vector3(x,clampf(point.y,0.0,BAR_Y),z)
			var gap: float=point.distance_to(post)
			if gap<best:
				best=gap; at=post
				var away: Vector3=point-post
				normal=away.normalized() if away.length()>0.001 else Vector3(-signf(x),0,0)
		var bar := Vector3(clampf(point.x,-POST_X,POST_X),BAR_Y,z)
		var bar_gap: float=point.distance_to(bar)
		if bar_gap<best:
			best=bar_gap; at=bar
			var away: Vector3=point-bar
			normal=away.normalized() if away.length()>0.001 else Vector3.UP
	return {"point":at,"gap":best,"normal":normal}

func woodwork(point: Vector3,direction: Vector3,strength: float) -> void:
	if game.menu_match.running or game.state!="playing": return
	strength=clampf(strength,0,1)
	last_kind="woodwork"
	event_count+=1
	age=0
	duration=lerpf(0.14,0.20,strength)
	amplitude=lerpf(0.16,0.28,strength)
	axis=Vector3(direction.x,direction.y*.35,direction.z)
	if axis.length()<0.1: axis=Vector3.RIGHT
	else: axis=axis.normalized()
	woodwork_in=0.38
	if is_instance_valid(game.controller):
		game.controller.rumble(0.22+strength*0.28,false,0.16)

func watch_woodwork() -> void:
	var ball=game.ball
	var velocity: Vector3=ball.linear_velocity
	var previous: Vector3=previous_velocity
	previous_velocity=velocity
	if woodwork_in>0 or game.menu_match.running or game.state!="playing": return
	if ball.held_by!=null or ball.pending_kick or ball.pending_reset: return
	var read := nearest_woodwork(ball.position)
	if read.gap>WOODWORK_REACH+BallSize.RADIUS: return
	var incoming := -previous.dot(read.normal)
	if incoming<4.2: return
	if velocity.distance_to(previous)<5.0 and velocity.dot(read.normal)>-1.0: return
	woodwork(read.point,read.normal,clampf((incoming-4.0)/20.0,0.28,1.0))
