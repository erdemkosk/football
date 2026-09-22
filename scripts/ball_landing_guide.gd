extends RefCounted
## Read-only help for the ball already in flight, independent of who kicked it.
const Motion = preload("res://scripts/ball_motion.gd")
const RADIUS := .22
const STEP := 1.0/120.0
const REFRESH := .08
var prediction: Dictionary = {}
var refresh_in := 0.0
var age := 0.0
var opacity := 0.0
var last_velocity := Vector3.ZERO

func reset() -> void:
	prediction.clear(); refresh_in=0; age=0; opacity=0; last_velocity=Vector3.ZERO

static func on_pitch(point: Vector3) -> bool:
	return absf(point.x)<32 and absf(point.z)<50

static func predict(origin: Vector3,velocity: Vector3,spin: float,surface=null) -> Dictionary:
	var result: Dictionary={}
	var point := origin
	var drag := Motion.air_drag(surface)
	for step in range(720):
		var previous := point
		# Match the rigid body's drag / Magnus / gravity order. Never predict
		# a bounce: after a real collision the next flight is sampled afresh.
		velocity=Motion.apply_spin(Motion.air_velocity(velocity,STEP,drag),spin,STEP)
		spin=Motion.decay_spin(spin,STEP,true)
		velocity.y-=Motion.GRAVITY*STEP
		point+=velocity*STEP
		if point.y<=RADIUS and previous.y>RADIUS:
			var fraction := (RADIUS-previous.y)/(point.y-previous.y)
			var landing := previous.lerp(point,fraction)
			if on_pitch(landing):
				result.landing=Vector3(landing.x,.045,landing.z)
				result.time=(step+fraction)*STEP
			break
		# Do not clamp out-of-play trajectories into a misleading pitch marker.
		if not on_pitch(point): break
	return result

func available(game) -> bool:
	return game.state=="playing" and not game.menu_match.running and not game.broadcast.active and game.ball.held_by==null and not game.ball.pending_reset and game.ball.active and not game.frontend.visible and not game.match_menu.visible and not game.controls_help.visible and not game.training_menu.visible

func update(game,delta: float) -> void:
	if not available(game): reset(); return
	var ball=game.ball
	var velocity: Vector3=ball.kick_velocity if ball.pending_kick else ball.linear_velocity
	if ball.position.y<.55 and velocity.y<2.0:
		reset(); return
	age+=delta; refresh_in-=delta
	var changed: bool=(last_velocity.length()>2 and velocity.distance_to(last_velocity)>3) or (last_velocity.y<-.5 and velocity.y-last_velocity.y>2)
	if refresh_in<=0 or changed or ball.pending_kick:
		prediction=predict(ball.position,velocity,ball.spin,game.weather)
		refresh_in=REFRESH; age=0
	last_velocity=velocity
	opacity=move_toward(opacity,1 if not prediction.is_empty() else 0,delta*10)

func ring(hud,point: Vector3,radius: float,color: Color,fill: bool=false) -> void:
	if hud.game.camera.is_position_behind(point): return
	var at: Vector2=hud.game.screen_position(point)
	if not Rect2(24,115,1392,650).has_point(at): return
	var points := PackedVector2Array()
	for i in range(33):
		var angle := TAU*i/32.0
		points.append(hud.game.screen_position(point+Vector3(cos(angle),0,sin(angle))*radius))
	if fill: hud.draw_colored_polygon(points,Color(color,color.a*.10))
	hud.draw_polyline(points,Color(.015,.035,.035,color.a*.7),4.2,true)
	hud.draw_polyline(points,color,1.8,true)

func draw(hud) -> void:
	var game=hud.game
	if opacity<=0 or not available(game): return
	if prediction.has("landing"):
		var color := Color(.83,.94,.91,opacity*.86)
		var time: float=maxf(0,prediction.time-age)
		ring(hud,prediction.landing,.78,color,true)
		ring(hud,prediction.landing,.90+minf(time,2)*.42,Color(color,opacity*.36))
