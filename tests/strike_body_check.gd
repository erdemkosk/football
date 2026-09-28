extends "res://tests/motion_contact_check.gd"
## Exercise the complete rendered pose around real strikes, including recovery
## and the independent shoulder roots used by the continuous shirt skin.

func strike_body(rate: int,side: float,kind: String) -> void:
	setup()
	game.ball.position=p.position+Vector3(side*.18,.23,-.78)
	var velocity:=Vector3(0,7 if kind=="cross" else 1,-29 if kind=="shot" else -14)
	game.strike(9,velocity,0,false,kind)
	var delta:=1.0/rate
	var chest_peak:=-INF; var chest_time:=0.0
	var arm_peak:=-INF; var arm_time:=0.0
	var hip_peak:=-INF; var hip_time:=0.0
	var low_chest:=INF; var shoulder_travel:=0.0
	var finite:=true; var lowest:=INF
	var hip: Node3D=p.right_leg if side>0 else p.left_leg
	var arm: Node3D=p.right_arm if side>0 else p.left_arm
	var contact_time:=-1.0
	for frame in range(rate):
		tick(delta)
		var age: float=(frame+1)*delta
		if game.ball.pending_kick and contact_time<0: contact_time=age
		for joint: Node3D in p.kick_joints: finite=finite and joint.transform.is_finite()
		lowest=minf(lowest,minf(p.left_knee.to_global(p.ball_actions.BOOT).y,p.right_knee.to_global(p.ball_actions.BOOT).y)-p.position.y-p.boot_ground_height())
		shoulder_travel=maxf(shoulder_travel,absf(arm.position.z))
		if p.kick_timer>0:
			low_chest=minf(low_chest,p.spine.rotation.y*side)
			if p.spine.rotation.y*side>chest_peak:
				chest_peak=p.spine.rotation.y*side; chest_time=age
			if arm.rotation.x>arm_peak: arm_peak=arm.rotation.x; arm_time=age
			if hip.rotation.x>hip_peak: hip_peak=hip.rotation.x; hip_time=age
	var label:="%s / %s foot / %d Hz" % [kind,"right" if side>0 else "left",rate]
	check(contact_time>0 and contact_time<=.1 and game.feedback.event_count==1,"One timely boot contact: "+label)
	check(finite and lowest>-.035 and shoulder_travel<.036,"Finite pose, grounded support and bounded shoulder travel: "+label)
	check(absf(arm.position.z)<.001 and absf(arm.position.y-.535)<.001 and p.kick_timer==0,"Shoulders and kick settle back into the live stance: "+label)
	if kind=="shot":
		print("STRIKE PHASES ",label," hip=",hip_time," chest=",chest_time," arm=",arm_time," yaw=",low_chest,"..",chest_peak)
		check(low_chest<-.025 and chest_peak>.10,"Chest coils and then turns through the shot on either foot: "+label)
		check(chest_time>=hip_time and arm_time>hip_time,"Chest and kicking-side arm follow the boot instead of peaking together: "+label)

func interrupted_shoulders() -> void:
	setup(); p.velocity=Vector3.FORWARD*9; p.desired=Vector3.FORWARD
	for i in range(24): tick()
	var moved: float=absf(p.left_arm.position.z)+absf(p.right_arm.position.z)
	p.keeper=true; p.pose="claim"; p.action_timer=.5; p.animate(1)
	check(moved>.004 and absf(p.left_arm.position.z)<.0001 and absf(p.right_arm.position.z)<.0001,"Goalkeeper hand poses restore neutral shoulder roots after a running pose")
	p.keeper=false

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-strike-body-settings.cfg"
	p=game.players[9]
	for rate in [30,60,120]:
		for side in [-1.0,1.0]:
			for kind in ["kick","shot","cross"]: strike_body(rate,side,kind)
	interrupted_shoulders()
	print("STRIKE BODY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
