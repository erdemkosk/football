extends RefCounted
## Named match cameras. Play starts on the sideline; C cycles the rest.
const IDS: PackedStringArray = ["pitch","broadcast","sideline","end","tactical"]
const LABELS: PackedStringArray = ["SAHA","YAYIN","KENAR","KALE","TAKTİK"]
const DEFAULT := "sideline"
const KICK_RESTARTS: PackedStringArray = ["KORNER","PENALTI","SERBEST VURUŞ","ENDİREKT VURUŞ"]
var game
var index := 0
var snap := true
var current_eye := Vector3.ZERO
var current_look := Vector3.ZERO
var has_pose := false
var preferred := DEFAULT
var distance := 1.0
var height := 1.0

func reset() -> void:
	has_pose=false
	select(preferred)

func preference(value: String,activate: bool=true) -> void:
	preferred=value if value in IDS else DEFAULT
	if activate: select(preferred)

func set_distance(value: float) -> void:
	distance=clampf(value,.70,1.50)

func set_height(value: float) -> void:
	height=clampf(value,.65,1.60)

func defaults() -> void:
	distance=1.0; height=1.0
	preference(DEFAULT)

func cycle() -> void:
	index=posmod(index+1,IDS.size())
	snap=true
	apply_projection()
	game.announce("KAMERA  ·  "+label())

func select(id: String) -> void:
	var found: int=IDS.find(id)
	index=found if found>=0 else 0
	snap=true
	apply_projection()

func id() -> String:
	return IDS[index]

func label() -> String:
	return LABELS[index]

func is_tactical() -> bool:
	return id()=="tactical"

func is_pitch() -> bool:
	return id()=="pitch"

func is_sideline() -> bool:
	return id()=="sideline"

func kick_restart() -> bool:
	return game!=null and not (game.training and game.training_drills.placing()) and game.state in ["restart","set_piece"] and game.restart_type in KICK_RESTARTS

func set_piece_inset() -> float:
	if not kick_restart(): return 0.0
	if game.state=="set_piece": return 1.0
	var phase: String=game.set_pieces.recovery.phase
	if phase=="ready": return 1.0
	if phase=="arrange": return smoothstep(0.0,1.55,game.set_pieces.recovery.age)
	return 0.0

func kick_toward() -> Vector3:
	var point: Vector3=game.restart_point
	var goal := Vector3(0,0,game.attack_sign(game.restart_team)*50)
	var toward: Vector3=(goal-point)*Vector3(1,0,1)
	if game.restart_type=="KORNER":
		toward=Vector3(0,0,game.attack_sign(game.restart_team)*42)-point
	if toward.length_squared()<0.0004:
		toward=Vector3(0,0,game.attack_sign(game.restart_team))
	return toward.normalized()

func behind_kick_pose() -> Dictionary:
	var point: Vector3=game.restart_point
	var toward: Vector3=kick_toward()
	var side := Vector3(-toward.z,0,toward.x)
	if side.dot(Vector3.RIGHT)<0.05: side=-side
	var kind: String=game.restart_type
	var back := 10.4
	var height := 3.9
	var side_off := 2.7
	var look_ahead := 16.5
	var fov := 40.0
	if kind=="KORNER":
		var attack: float=game.attack_sign(game.restart_team)
		var side_sign := 1.0 if point.x>=0.0 else -1.0
		return {eye=Vector3(clampf(point.x*0.55+side_sign*6.4,-28,28),14.0,clampf(attack*12.0,-36,36)),look=Vector3(point.x*0.5,1.2,attack*46),fov=50.0}
	if kind=="PENALTI":
		back=11.2; height=3.15; side_off=1.55; look_ahead=13.5; fov=38.0
	elif point.distance_to(Vector3(0,0,game.attack_sign(game.restart_team)*50))<22.0:
		back=9.6; height=3.55; side_off=2.35; look_ahead=18.0; fov=41.0
	var eye: Vector3=point-toward*back+side*side_off+Vector3.UP*height
	eye.x=clampf(eye.x,-39,40)
	eye.z=clampf(eye.z,-54,54)
	var look: Vector3=point+toward*look_ahead+Vector3.UP*1.08
	if kind=="PENALTI":
		look=Vector3(0,1.35,game.attack_sign(game.restart_team)*50).lerp(point+Vector3.UP*1.1,0.18)
	return {eye=eye,look=look,fov=fov}

func tracked_point(focus: Vector3) -> Vector3:
	if game==null: return focus
	if game.state in ["restart","set_piece"] and game.restart_type=="TAÇ":
		return Vector3(game.restart_point.x,0,game.restart_point.z)
	if is_instance_valid(game.ball):
		return Vector3(game.ball.position.x,0,game.ball.position.z)
	return focus

func apply_projection() -> void:
	if game==null or not is_instance_valid(game.camera): return
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if id() in ["pitch","tactical"] else Camera3D.PROJECTION_PERSPECTIVE
	game.camera.near=0.2
	game.camera.far=800

func cinematic() -> void:
	if not is_instance_valid(game.camera): return
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.near=0.2
	game.camera.far=800

func play_size(zoom: float) -> float:
	return (114.0 if is_tactical() else zoom)*distance

func pose(focus: Vector3,zoom: float) -> Dictionary:
	var eye := focus+Vector3(0,70,37)
	var look := focus
	var projection := Camera3D.PROJECTION_ORTHOGONAL
	var size := zoom
	var fov := 38.0
	if game!=null and game.training and game.training_drills.placing():
		var point: Vector3=game.training_drills.place_point
		var above := Vector3(clampf(point.x,-16,16),0,point.z)
		return {eye=above+Vector3(0,82,9),look=above,projection=Camera3D.PROJECTION_ORTHOGONAL,size=58.0,fov=fov}
	match id():
		"broadcast":
			projection=Camera3D.PROJECTION_PERSPECTIVE
			eye=focus+Vector3(0,46,54)
			look=focus+Vector3(0,0.6,0)
			fov=36.0
		"sideline":
			projection=Camera3D.PROJECTION_PERSPECTIVE
			var track: Vector3=tracked_point(focus)
			# Camera lives on +x. Near throw-ins lean back so the ball stays framed.
			# Corners and free kicks ease behind the taker and look into the play.
			var near := 0.0 if kick_restart() else smoothstep(16.0,31.5,track.x)
			eye=Vector3(40.0+near*5.5,18.6+near*7.4,clampf(lerpf(focus.z,track.z,near*0.55),-42,42))
			look=Vector3(lerpf(clampf(focus.x,-10,10),track.x,near*0.94),lerpf(1.05,0.22,near),lerpf(focus.z,clampf(track.z,-48,48),near))
			fov=lerpf(40.0,37.0,near)
			var inset := set_piece_inset()
			if inset>0.0:
				var piece: Dictionary=behind_kick_pose()
				eye=eye.lerp(piece.eye,inset)
				look=look.lerp(piece.look,inset)
				fov=lerpf(fov,piece.fov,inset)
		"end":
			projection=Camera3D.PROJECTION_PERSPECTIVE
			var end: float=game.attack_sign(0)*56.0
			eye=Vector3(clampf(focus.x*0.4,-10,10),15,end)
			look=Vector3(focus.x*0.5,0.8,clampf(focus.z,-36,36))
			fov=42.0
		"tactical":
			eye=Vector3(0,90,8)
			look=Vector3.ZERO
			size=114.0
	# Keep the authored free-kick/corner framing and training spot selection.
	# Ordinary views share zoom/height controls, including perspective cameras.
	var custom := 1.0-set_piece_inset() if is_sideline() else 1.0
	var zoom_scale := lerpf(1.0,distance,custom)
	var elevation := lerpf(1.0,height,custom)
	var offset := eye-look
	if projection==Camera3D.PROJECTION_ORTHOGONAL:
		size*=zoom_scale
		offset.y*=elevation
	else:
		offset*=zoom_scale
		offset.y*=elevation
		# A distant low sideline must remain above the stadium seating.
		if is_sideline() and look.x+offset.x>45: offset.y=maxf(offset.y,22.0-look.y)
	eye=look+offset
	return {eye=eye,look=look,projection=projection,size=size,fov=fov}

func ground_forward() -> Vector3:
	if not is_instance_valid(game.camera): return Vector3(0,0,-1)
	var look: Vector3=-game.camera.global_transform.basis.z
	look.y=0
	if look.length_squared()<0.0004:
		look=-game.camera.global_transform.basis.y
		look.y=0
	return look.normalized() if look.length_squared()>0.0004 else Vector3(0,0,-1)

func ground_right() -> Vector3:
	var right: Vector3=ground_forward().cross(Vector3.UP)
	return right.normalized() if right.length_squared()>0.0004 else Vector3.RIGHT

func orient(raw: Vector3) -> Vector3:
	var planar := Vector3(raw.x,0,raw.z)
	if planar.length_squared()<0.0001: return Vector3.ZERO
	return (ground_right()*planar.x-ground_forward()*planar.z).normalized()*planar.length()

func apply(focus: Vector3,zoom: float,delta: float) -> Dictionary:
	var next: Dictionary=pose(focus,zoom)
	var cam: Camera3D=game.camera
	cam.projection=next.projection
	var rate := 1.15 if set_piece_inset()>0.02 else 3.0
	var blend := 1.0 if snap or delta<=0.0 or not has_pose else 1.0-exp(-delta*rate)
	if snap or not has_pose:
		current_eye=next.eye
		current_look=next.look
		has_pose=true
	else:
		current_eye=current_eye.lerp(next.eye,blend)
		current_look=current_look.lerp(next.look,blend)
	if next.projection==Camera3D.PROJECTION_ORTHOGONAL:
		cam.size=lerpf(cam.size,next.size,blend)
	else:
		cam.fov=lerpf(cam.fov,next.fov,blend)
	snap=false
	next.eye=current_eye
	next.look=current_look
	return next
