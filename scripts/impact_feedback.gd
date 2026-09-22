extends RefCounted
## Short contact cues run on match time; they never stop or accelerate the ball.
var game
var age := 1.0
var duration := 0.28
var amplitude := 0.0
var axis := Vector3.RIGHT
var hurt := 0.0
var last_kind := ""
var event_count := 0

func reset() -> void:
	age=1
	amplitude=0
	hurt=0
	last_kind=""
	event_count=0

func update(delta: float) -> void:
	age+=delta
	hurt=move_toward(hurt,0,delta*3.5)

func offset() -> Vector3:
	if age>=duration: return Vector3.ZERO
	var envelope := pow(1-age/duration,2)
	return (axis*sin(age*53)+Vector3(0,0,1)*sin(age*37)*0.28)*amplitude*envelope

func contact(kind: String,index: int,point: Vector3,direction: Vector3,strength: float,victim: int=-1) -> void:
	last_kind=kind
	event_count+=1
	strength=clampf(strength,0,1)
	var nearby: bool=game.flat_distance(point,game.players[game.controlled].position)<16
	var personal: bool=game.is_user_player(index) or game.is_user_player(victim)
	game.audio.contact("shot" if kind=="header" else kind,strength,1.0 if personal else (0.65 if nearby else 0.32))
	if personal: game.controller.rumble(strength,kind in ["shot","header"])
	if personal or nearby:
		age=0
		duration=0.23 if kind in ["shot","header"] else 0.30
		amplitude=lerpf(0.055,0.19,strength)*(1.0 if personal else 0.35)
		if kind=="body_hit": amplitude*=1.25
		axis=Vector3(direction.x,0,direction.z).normalized()
		if axis.length()<0.1: axis=Vector3.RIGHT
	if victim==game.controlled and kind=="body_hit": hurt=0.3+strength*0.5
	if kind in ["shot","ball_tackle","body_hit"]:
		var wet: float=game.weather.wetness
		var mud: float=game.weather.mud_at(point)
		game.weather.splash(point,direction*5,4+int(strength*6),mud if wet>0.25 else 1.0)
