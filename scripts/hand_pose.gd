extends RefCounted
## Finger-only motion: wrist nodes remain the authoritative save/ball anchors.
var curls := Vector2(.20,.20)
var spreads := Vector2.ZERO

func apply(p,delta: float) -> void:
	var pace:=clampf(Vector2(p.velocity.x,p.velocity.z).length()/8.5,0,1)
	var target:=Vector2.ONE*lerpf(.20,.62,pace)
	var spread:=Vector2.ZERO
	if p.protecting or p.jockeying or p.body_language.contest_weight>.1 or p.discipline_pose!="":
		target=Vector2.ONE*.08; spread=Vector2.ONE*.55
	if p.kick_timer>0 or p.receive_timer>0 or p.pose in ["header","volley","stumble","fall","rise"]:
		target=Vector2.ONE*.12; spread=Vector2.ONE*.32
	if p.call_timer>0: target.y=.05; spread.y=.75
	if p.reaction.kind in ["miss","acknowledge","encourage"]: target=Vector2.ONE*.06; spread=Vector2.ONE*.45
	if p.celebration in ["fist","cheer"]: target=Vector2.ONE*.92
	elif p.celebration in ["crowd","wings","applaud","embrace","high_five"]: target=Vector2.ONE*.05; spread=Vector2.ONE*.65
	if p.keeper:
		p.left_hand.rotation=Vector3.ZERO; p.right_hand.rotation=Vector3.ZERO
		target=Vector2.ONE*.08; spread=Vector2.ONE*.40
		if p.action_timer>0: target=Vector2.ONE*.04; spread=Vector2.ONE*.82
	if p.keeper and p.keeper_motion.special(p):
		if p.keeper_motion.kind=="punch": target=Vector2.ONE*.98; spread=Vector2.ZERO
		else: target=Vector2.ONE*.02; spread=Vector2.ONE*.65
	if p.set_piece_pose in ["carry","pickup","receive","throw"] or (p.keeper and p.keeper_motion.secured):
		target=Vector2.ONE*.38; spread=Vector2.ONE*.24
	if p.keeper and p.keeper_motion.brace_weight>0:
		var side: int=0 if p.keeper_motion.brace_left else 1
		target[side]=lerpf(target[side],.03,p.keeper_motion.brace_weight)
		spread[side]=lerpf(spread[side],.75,p.keeper_motion.brace_weight)
		var hand: Node3D=p.left_hand if side==0 else p.right_hand
		var along: Vector3=-(p.facing*Vector3(1,0,1)).normalized()
		if along.length_squared()>.5:
			var flat:=Basis(along.cross(Vector3.UP),along,Vector3.UP)
			var local: Basis=hand.get_parent().global_basis.orthonormalized().inverse()*flat
			hand.quaternion=Quaternion.IDENTITY.slerp(local.get_rotation_quaternion(),p.keeper_motion.brace_weight)
	var blend:=1-exp(-maxf(delta,0)*12)
	curls=curls.lerp(target,blend); spreads=spreads.lerp(spread,blend)
	render(p)

func snapshot() -> Vector4:
	return Vector4(curls.x,curls.y,spreads.x,spreads.y)

func restore(p,value: Vector4) -> void:
	curls=Vector2(value.x,value.y); spreads=Vector2(value.z,value.w)
	render(p)

func render(p) -> void:
	for i in range(2):
		var hand: MeshInstance3D=p.left_hand if i==0 else p.right_hand
		if hand.mesh.get_blend_shape_count()<2: continue
		hand.set_blend_shape_value(0,curls[i])
		hand.set_blend_shape_value(1,minf(spreads[i],1-curls[i]))
