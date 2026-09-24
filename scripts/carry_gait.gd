extends RefCounted
## A carrying stride has its own stance/swing cycle. The planted boot is kept
## in world space; the other boot follows a low arc into its next footfall.
const BOOT:=Vector3(0,-.42,-.05)
var phase:=0.0
var weight:=0.0
var anchors: Array[Vector3]=[]
var lift_off: Array[Vector3]=[]
var stance: Array[bool]=[false,false]
var heading:=Vector3.FORWARD
var previous:=Vector3.INF

func reset() -> void:
	anchors.clear(); lift_off.clear(); stance.assign([false,false]); weight=0; previous=Vector3.INF

func apply(p,delta: float) -> void:
	if not p.dribble_motion.available(p) or p.receive_timer>0 or p.shot_preparation>0:
		reset(); return
	var velocity: Vector3=p.velocity*Vector3(1,0,1)
	var pace:=velocity.length()
	var active: bool=p.dribble_motion.freshness>0 and pace>.45 and not p.protecting and not p.jockeying and p.feint_time<=0 and p.dribble_motion.available(p) and not p.dribble_motion.preparing
	if previous!=Vector3.INF and p.position.distance_to(previous)>2: reset()
	previous=p.position
	weight=move_toward(weight,1.0 if active else 0.0,delta*9)
	if weight<=0:
		anchors.clear(); return
	var current: Array[Vector3]=[p.left_knee.to_global(BOOT),p.right_knee.to_global(BOOT)]
	if anchors.size()!=2:
		anchors=current.duplicate(); lift_off=current.duplicate(); phase=fposmod(p.run_phase/TAU,1)
		heading=velocity.normalized() if pace>.1 else p.facing
	if pace>.1: heading=heading.slerp(velocity.normalized(),1-exp(-delta*12)).normalized()
	var sprint:=smoothstep(4.5,8.0,pace)
	var cadence:=lerpf(1.6,2.65,smoothstep(1.0,8.0,pace))
	var contact_share:=lerpf(.60,.40,smoothstep(1.0,8.0,pace))
	phase=fposmod(phase+delta*cadence,1)
	var reach:=minf(.38,pace/cadence*contact_share*.5)
	var right:=heading.cross(Vector3.UP)
	var floor_y: float=p.position.y+p.boot_ground_height()
	p.rig.position.y=lerpf(p.rig.position.y,-.105-.025*sprint+.012*sin(phase*TAU*2),weight)
	# Both leg solves change children only; the pelvis frame stays fixed here.
	var rig_inverse: Transform3D=p.rig.global_transform.affine_inverse()
	for i in range(2):
		var cycle:=fposmod(phase+i*.5,1)
		var planted:=cycle<contact_share
		var lateral: float=(-1 if i==0 else 1)*p.body_scale.x*.14
		var forward: Vector3=p.position+heading*reach+right*lateral
		forward.y=floor_y
		if planted and not stance[i]: anchors[i]=forward
		elif not planted and stance[i]: lift_off[i]=anchors[i]
		stance[i]=planted
		var point: Vector3=anchors[i]
		if not planted:
			var swing:=inverse_lerp(contact_share,1.0,cycle)
			point=lift_off[i].lerp(forward,smoothstep(0,1,swing))
			point.y=floor_y+sin(PI*swing)*lerpf(.10,.13,sprint)
		point=current[i].lerp(point,weight)
		point.y=maxf(floor_y,point.y)
		var leg: Node3D=p.left_leg if i==0 else p.right_leg
		var knee: Node3D=p.left_knee if i==0 else p.right_knee
		p.locomotion.solve_leg(leg,knee,rig_inverse*point-leg.position,1)
