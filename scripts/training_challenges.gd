extends RefCounted
const Catalog=preload("res://scripts/training_catalog.gd")
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/pitch_dimensions.gd")
var game
var mode:=""
var completed:=0
var points:=0
var age:=0.0
var wait:=-1.0
var live:=false
var finished:=false
var career_context:=false
var props: Node3D
var target:=Vector3.ZERO
var last_ball:=Vector3.ZERO
var peak:=0.0
var kicked:=false
var fed:=false
var secured:=0.0
var message:=""
var receive_target:=Vector3.ZERO
var control_exit:=Vector3.ZERO
var control_received:=false
var control_delivery_at:=0.0

func active() -> bool: return game.training and mode in Catalog.SCORED

func clear() -> void:
	if is_instance_valid(props): props.queue_free()
	props=null; live=false; mode=""; finished=false

func begin(value: String) -> void:
	clear(); mode=value; completed=0; points=0; wait=-1; age=0; message=""
	career_context=not game.career.training.active.is_empty()

func gate(index: int) -> Vector3:
	return Vector3(-3 if index%2==0 else 3,0,-12-index*5)

func marker(at: Vector3,width: float=1.4,forward: Vector3=Vector3.FORWARD) -> void:
	var orange:=G.material(Color("efad61")); var green:=G.material(Color("bbed9e"))
	var across:=forward.normalized().cross(Vector3.UP)
	for x in [-width,width]:
		G.cylinder(props,.24,.55,at+across*x+Vector3.UP*.27,orange,.04)
		G.block(props,Vector3(.57,.05,.57),at+across*x+Vector3.UP*.025,orange)
	var line:=G.block(props,Vector3(width*2,.025,.13),at+Vector3(0,.035,0),green)
	line.rotation.y=atan2(-forward.x,-forward.z)

func ring(at: Vector3,radius: float) -> void:
	var material:=G.material(Color("c8e995"))
	for i in range(40):
		var a:=Vector3(cos(i*TAU/40),.02,sin(i*TAU/40))*radius
		var b:=Vector3(cos((i+1)*TAU/40),.02,sin((i+1)*TAU/40))*radius
		G.rod(props,at+a,at+b,.035,material)

func setup() -> void:
	# R / retry consumes the unfinished attempt; it cannot reset career rewards.
	if live and wait<0: completed+=1
	if completed>=6: finish(); return
	if is_instance_valid(props): props.queue_free()
	props=Node3D.new(); props.name="TrainingTargets"; game.add_child(props)
	age=0; wait=-1; live=true; peak=0; kicked=false; fed=false; secured=0; control_received=false
	for i in range(game.players.size()):
		var p=game.players[i]
		p.visible=i==9 or (i==11 and mode in ["shooting","penalty"]) or (i==8 and mode=="control") or (i==20 and mode=="defending")
		p.collision_layer=2 if p.visible else 0
		p.desired=Vector3.ZERO; p.velocity=Vector3.ZERO
	var user=game.players[9]
	user.position=Vector3(0,0,-8); user.facing=Vector3.FORWARD; user.rig.rotation.y=0
	game.controlled=9; game.player_lock=true; game.kick_lock=.15
	match mode:
		"slalom":
			user.position=Vector3(0,0,-7) if completed==0 else gate(completed-1)+Vector3.BACK
			target=gate(completed)
			for i in range(6): marker(gate(i))
		"passing","distribution":
			user.position=Vector3(0,0,8 if mode=="distribution" else -8)
			target=Vector3([-8,6,0,10,-5,3][completed],0,-23)
			marker(target,2.8 if mode=="distribution" else 1.8)
		"shooting","penalty":
			user.position=Vector3([-8,0,8,-5,5,0][completed],0,[-24,-28,-24,-20,-20,-30][completed])
			target=Vector3(-2.2 if completed%2==0 else 2.2,.8,-P.HALF_LENGTH)
			var mat:=G.material(Color("c8e995"))
			for x in [-.9,.9]: G.rod(props,target+Vector3(x,-.7,0),target+Vector3(x,.7,0),.045,mat)
			for y in [-.7,.7]: G.rod(props,target+Vector3(-.9,y,0),target+Vector3(.9,y,0),.045,mat)
		"crossing":
			user.position=Vector3(-24 if completed%2==0 else 24,0,-34)
			target=Vector3([-4,3,0,4,-3,1][completed],0,-42)
			ring(target,3)
			user.facing=(target-user.position).normalized()
		"control":
			user.position=Vector3(0,0,-16)
			receive_target=Vector3([-6,6,-7,7,-4,4][completed],0,[-23,-23,-19,-19,-27,-27][completed])
			control_exit=receive_target+Vector3(signf(receive_target.x)*4.5,0,1.5)
			target=receive_target
			game.players[8].position=Vector3(receive_target.x*.25,0,-38)
			game.players[8].facing=(receive_target-game.players[8].position).normalized()
			ring(receive_target,2.6); marker(control_exit,1.8,control_exit-receive_target)
		"defending":
			user.position=Vector3(0,0,-16); user.facing=Vector3.FORWARD
			game.players[20].position=Vector3(-1.5 if completed%2==0 else 1.5,0,-23)
			game.players[20].facing=Vector3.BACK; target=Vector3(0,0,-8)
			marker(target,7)
	user.rig.rotation.y=atan2(-user.facing.x,-user.facing.z)
	var owner: int=8 if mode=="control" else 20 if mode=="defending" else 9
	var p=game.players[owner]
	game.ball.place(p.position+p.facing*.65+Vector3.UP*game.ball.GROUND_HEIGHT)
	if mode=="control": control_delivery_at=maxf(.9,3.2-game.Passing.flight_time(game.ball.reset_position,receive_target,12+completed*.5,game.weather))
	game.previous_ball=game.ball.position; last_ball=game.ball.position
	game.dribbler=owner; game.carrier=owner; game.last_kicker=-1; game.last_touch=p.team
	game.camera_focus=user.position; game.match_camera.snap=true
	if mode=="penalty":
		game.restart_type="PENALTI"; game.restart_team=0
		game.restart_point=Vector3(0,0,-P.HALF_LENGTH+11)
		game.state="restart"; game.set_pieces.prepare(); game.set_pieces.snap_ready()
	game.hint(Catalog.detail(mode))

func manages(index: int) -> bool:
	return (mode=="control" and index==8) or (mode=="defending" and index==20)

func actor(index: int) -> void:
	var p=game.players[index]
	p.desired=Vector3.ZERO; p.sprinting=false
	if mode=="defending" and live and wait<0: p.desired=Vector3(sin(age*.8)*.45,0,1)*2.8
	elif mode=="control": p.facing=(receive_target-p.position).normalized()

func crossing_point(current: Vector3) -> Vector3:
	if last_ball.z>target.z and current.z<=target.z and absf(current.z-last_ball.z)>.001:
		return last_ball.lerp(current,(target.z-last_ball.z)/(current.z-last_ball.z))
	return Vector3.INF

func update(delta: float) -> void:
	if not active() or finished or game.state in ["paused","training_setup"] or game.match_menu.visible or game.controls_help.visible: return
	if wait>=0:
		wait-=delta
		if wait<=0:
			live=false; game.reset_practice()
		return
	if game.state not in ["playing","set_piece","restart"] or game.ball.pending_reset: return
	age+=delta
	var ball: Vector3=game.ball.position
	peak=maxf(peak,ball.y)
	if game.last_kicker==9 and game.ball.linear_velocity.length()>3: kicked=true
	var user=game.players[9]
	match mode:
		"slalom":
			var hit:=crossing_point(ball)
			if hit!=Vector3.INF and absf(hit.x-target.x)<1.4 and ball.y<.7 and game.flat_distance(user.position,ball)<1.8 and game.has_ball_control(9):
				record(clampi(roundi(108-age*2),45,100),"KAPI GEÇİLDİ")
		"passing","distribution":
			var hit:=crossing_point(ball)
			var width:=2.8 if mode=="distribution" else 1.8
			if kicked and hit!=Vector3.INF:
				record(clampi(roundi(100-absf(hit.x-target.x)/width*30),60,100) if absf(hit.x-target.x)<width and hit.y<1.2 else 0,"PAS HEDEFİ")
		"crossing":
			if kicked and peak>1.8 and ball.y<.6 and game.ball.linear_velocity.y<0:
				var distance:=Vector2(ball.x-target.x,ball.z-target.z).length()
				record(clampi(roundi(100-distance*10),50,100) if distance<3 else 0,"ORTA İSABETİ")
		"control":
			# Deliver into a fixed space, not at the waiting user's feet. The
			# player must meet the real pass and keep it while moving out.
			var speed:=12+completed*.5
			if not fed and age>control_delivery_at and not game.ball.pending_kick:
				var direction: Vector3=(receive_target-game.ball.position)*Vector3(1,0,1)
				fed=game.strike(8,direction.normalized()*speed+Vector3.UP*.32,0,false,"pass")
				if fed: game.dribbler=-1; game.carrier=-1
			var held: bool=fed and game.last_kicker==9 and game.has_ball_control(9) and game.flat_distance(user.position,ball)<1.7
			if not control_received and held and game.flat_distance(ball,receive_target)<2.6:
				control_received=true; target=control_exit
			var exit_direction: Vector3=(control_exit-receive_target).normalized()
			var beyond_gate: float=(ball-control_exit).dot(exit_direction)
			var lateral: float=absf((ball-control_exit).dot(exit_direction.cross(Vector3.UP)))
			if control_received and held and beyond_gate>=0 and beyond_gate<1.8 and lateral<1.8:
				record(clampi(roundi(113-age*3-game.flat_distance(ball,control_exit)*5),45,100),"KARŞILA VE ÇIK")
			elif fed and not control_received and game.last_kicker==8:
				var incoming: Vector3=(receive_target-game.players[8].position).normalized()
				if (ball-receive_target).dot(incoming)>3.4: record(0,"TOP KAÇTI")
		"defending":
			secured=secured+delta if game.has_ball_control(9) and game.last_touch==0 else 0
			if secured>=3: record(clampi(roundi(112-age*2),50,100),"TOP KAZANILDI")
			elif game.players[20].position.z>-8: record(0,"RAKİP GEÇTİ")
		"shooting","penalty":
			if kicked and (game.ball.held_by!=null or (game.last_kicker>=0 and game.players[game.last_kicker].keeper)): record(0,"KALECİ KURTARDI")
	if live and wait<0 and age>(25 if mode=="defending" else 18): record(0,"SÜRE DOLDU")
	last_ball=ball

func goal(team: int) -> void:
	if mode in ["shooting","penalty"] and team==0 and kicked:
		game.practice_goals+=1
		var offset: float=Vector2(game.ball.position.x-target.x,game.ball.position.y-target.y).length()
		record(clampi(roundi(100-offset*12),55,100),"GOL · HEDEF KÖŞE" if offset<1.2 else "GOL")
	else: record(0,"HEDEF DIŞI")

func record(value: int,label: String) -> void:
	if not live or wait>=0 or finished: return
	points+=clampi(value,0,100); completed+=1; message=label+"  ·  +"+str(value)
	if completed>=6: finish(); return
	if mode=="slalom" and value>0:
		target=gate(completed); age=0; game.hint(message); return
	wait=1.1; game.state="training_wait"; game.ball.freeze=true
	game.hint(message)

func finish() -> void:
	if finished: return
	finished=true; live=false; game.state="training_result"; game.ball.freeze=true
	var score:=roundi(points/6.0)
	var reward: Dictionary=game.career.training.finish(score) if career_context else {}
	game.training_menu.show_result({"mode":mode,"score":score,"points":points,"grade":Catalog.grade(score),"career":career_context,"reward":reward})

func draw(h) -> void:
	if not active() or finished: return
	var shown_attempt:=clampi(completed if wait>=0 else completed+1,1,6)
	if not game.camera.is_position_behind(target):
		var at: Vector2=game.screen_position(target+Vector3.UP*.7)
		if mode=="control": at+=Vector2(-105,-15)
		h.panel(Rect2(at-Vector2(51,25),Vector2(102,25)),Color("173d35"),5)
		h.center(("ÇIKIŞ" if control_received else "KARŞILA") if mode=="control" else "HEDEF "+str(shown_attempt),at-Vector2(0,8),11,h.GOLD,true)
	h.draw_set_transform(game.ui.edge_offset(-1,-1))
	h.panel(Rect2(32,145,545,83),Color("102126"),7,Color(h.GOLD,.3))
	h.text("%d / 6  ·  %d PUAN  ·  %ds" % [shown_attempt,points,maxi(0,ceili((25 if mode=="defending" else 18)-age))],Vector2(48,172),18,h.GOLD,true)
	var instruction:=Catalog.detail(mode)
	if mode=="control" and control_received: instruction="Topu ayağında tutarak çıkış kapısından geç."
	h.text(instruction,Vector2(48,198),12,h.PAPER)
	var context:="KARİYER ÇALIŞMASI" if career_context else "SERBEST PRATİK · KALICI GELİŞİM YOK"
	h.text(message if wait>=0 else context,Vector2(48,218),10,h.GOLD if wait>=0 else h.MUTE)
	h.draw_set_transform(Vector2.ZERO)
