extends RefCounted
## Named match cameras. Play starts on the sideline; C cycles the rest.
const IDS: PackedStringArray = ["pitch","broadcast","sideline","end","tactical"]
const LABELS: PackedStringArray = ["SAHA","YAYIN","KENAR","KALE","TAKTİK"]
const DEFAULT := "sideline"
var game
var index := 0
var snap := true

func reset() -> void:
	select(DEFAULT)

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
	return 114.0 if is_tactical() else zoom

func pose(focus: Vector3,zoom: float) -> Dictionary:
	var eye := focus+Vector3(0,70,37)
	var look := focus
	var projection := Camera3D.PROJECTION_ORTHOGONAL
	var size := zoom
	var fov := 38.0
	match id():
		"broadcast":
			projection=Camera3D.PROJECTION_PERSPECTIVE
			eye=focus+Vector3(0,46,54)
			look=focus+Vector3(0,0.6,0)
			fov=36.0
		"sideline":
			projection=Camera3D.PROJECTION_PERSPECTIVE
			var track: Vector3=tracked_point(focus)
			# Camera lives on +x. When the ball reaches the near touchline the
			# throw-in sits under the lens; lean back and look down so it stays framed.
			var near := smoothstep(16.0,31.5,track.x)
			eye=Vector3(40.0+near*5.5,18.6+near*7.4,clampf(lerpf(focus.z,track.z,near*0.55),-42,42))
			look=Vector3(lerpf(clampf(focus.x,-10,10),track.x,near*0.94),lerpf(1.05,0.22,near),lerpf(focus.z,clampf(track.z,-48,48),near))
			fov=lerpf(40.0,37.0,near)
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
	var blend := 1.0 if snap or delta<=0.0 else 1.0-exp(-delta*3.0)
	if next.projection==Camera3D.PROJECTION_ORTHOGONAL:
		cam.size=lerpf(cam.size,next.size,blend)
	else:
		cam.fov=lerpf(cam.fov,next.fov,blend)
	snap=false
	return next
