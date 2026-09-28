extends RefCounted
## Authored right-foot poses; contact IK and the live stride remain authoritative.
## The chest turns after the leg, then the arms settle after the chest.
static func pose(power: float,style: String,progress: float) -> Array[Vector3]:
	if style in ["compact","outside_pass","backheel"]: return pass_pose(style,progress)
	var inside:=1.0 if style=="inside" else 0.0
	var chip:=1.0 if style=="chip" else 0.0
	var sweep:=smoothstep(0,.24,progress)
	var recoil:=smoothstep(.28,.68,progress)
	var chest:=smoothstep(.06,.43,progress)
	var arms:=smoothstep(.12,.54,progress)
	var settle:=smoothstep(.46,.88,progress)
	var effort: float=lerpf(.38,1.0,power)*(1-inside*.42)
	var hip:=lerpf(lerpf(lerpf(.42,.20,inside),lerpf(lerpf(.85,.44,inside),lerpf(1.24,.92,inside),power),sweep),.12,recoil)
	if chip>0: hip=lerpf(lerpf(.50,lerpf(.95,1.18,power),sweep),.18,recoil)
	var knee:=lerpf(lerpf(-.12,-.28,sweep),-.86,recoil)
	# An inside pass opens the instep with a compact shoulder action. A driven
	# strike carries the chest forward and the kicking-side arm across the body.
	var chest_yaw:=lerpf(-.12-effort*.22,.12+effort*.34,chest)
	chest_yaw+=inside*.12*sweep
	var chest_pitch: float=-.12-effort*.18*chest-chip*.13*sweep
	return [
		Vector3(.24,0,-.045-inside*.08),Vector3(hip,inside*.46*sweep,.045+inside*.16),
		Vector3(-.42,0,0),Vector3(knee,0,inside*.22),
		Vector3(lerpf(chest_pitch,-.12,settle),lerpf(chest_yaw,-effort*.08,settle),lerpf(.025,-.07,chest)*effort),
		Vector3(lerpf(.26+effort*.22,-.12,arms),lerpf(-.16,.18,arms)*effort,-.35-effort*.40*(1-arms*.55)),
		Vector3(lerpf(-.24-effort*.27,.26+effort*.57,arms),effort*.22*arms,.22+effort*.17*(1-arms)-effort*.10*arms),
		Vector3(lerpf(.90,.58,arms)+settle*.20,0,-effort*.08*chest),
		Vector3(lerpf(.64,1.12,arms)-settle*.24,0,effort*.10*chest)
	]

static func pass_pose(style: String,progress: float) -> Array[Vector3]:
	var stroke := smoothstep(0,.25,progress)
	var settle := smoothstep(.30,.85,progress)
	var weight := stroke*(1-settle)
	var leg := Vector3(.30+.25*weight,.35*weight,.06)
	var knee := Vector3(-.24-.25*settle,0,.09*weight)
	var chest := Vector3(-.13,.13*weight,-.025*weight)
	if style=="outside_pass":
		leg=Vector3(.35+.32*weight,-.38*weight,.16*weight)
		knee=Vector3(-.22-.30*settle,-.32*weight,-.12*weight)
		chest=Vector3(-.18,-.28*weight,.08*weight)
	elif style=="backheel":
		leg=Vector3(lerpf(.28,-.40,stroke)*(1-settle),.08,.08)
		knee=Vector3(-.38-.50*weight,0,0)
		chest=Vector3(-.23,-.12*weight,.06*weight)
	return [Vector3(.18,0,-.05),leg,Vector3(-.33,0,0),knee,chest,
		Vector3(.12,0,-.42),Vector3(-.12,0,.38),Vector3(.8,0,0),Vector3(.75,0,0)]

static func shoulders(p,delta: float,amount: float) -> void:
	# Small clavicle travel keeps the arm roots from looking bolted to the shirt.
	# The connected shirt skin follows these same nodes. Restore neutral roots
	# before hand IK/keeper poses; never move a collision or foot-contact node.
	var left:=Vector2.ZERO
	var right:=Vector2.ZERO
	var free: bool=not p.keeper and p.action_timer<=0 and p.set_piece_pose=="" and p.celebration=="" and p.discipline_pose=="" and p.skill_move.is_empty() and not p.protecting and not p.jockeying
	if free:
		var roll: float=sin(p.run_phase-.30)*amount
		left=Vector2(-roll*.012,roll*.022)
		right=-left
		if p.kick_timer>0:
			var progress: float=1-p.kick_timer/maxf(.01,p.kick_duration)
			var weight:=smoothstep(0,.12,progress)*(1-smoothstep(.55,1,progress))
			var turn:=lerpf(-1,1,smoothstep(.08,.48,progress))
			var effort: float=lerpf(.35,1,p.kick_power)*(.6 if p.kick_style=="inside" else 1.0)
			var support:=Vector2(.012,-turn*.035)*effort
			var striking:=Vector2(-.008,turn*.035)*effort
			left=left.lerp(support if p.ball_actions.foot==1 else striking,weight)
			right=right.lerp(striking if p.ball_actions.foot==1 else support,weight)
	var blend:=1-exp(-delta*22)
	p.left_arm.position.y=lerpf(p.left_arm.position.y,.535+left.x,blend)
	p.left_arm.position.z=lerpf(p.left_arm.position.z,left.y,blend)
	p.right_arm.position.y=lerpf(p.right_arm.position.y,.535+right.x,blend)
	p.right_arm.position.z=lerpf(p.right_arm.position.z,right.y,blend)
