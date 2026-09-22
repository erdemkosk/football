extends RefCounted
const G=preload("res://scripts/geometry.gd")
var game
var fixture: Dictionary={}
var attempts: Array=[[],[]]
var totals: Array=[0,0]
var pools: Array=[[],[]]
var side:=0
var phase:="ready"
var age:=0.0
var aim:=Vector2(0,.45)
var power:=0.0
var charging:=false
var paused:=false
var axes:=Vector2.ZERO
var keys: Dictionary={}
var shooter
var keeper
var last_ball:=Vector3.ZERO
var keeper_aim:=0.0
var keeper_delay:=0.0
var keeper_jumped:=false
var saved:=false
var result:=""
var stage: Node3D
var trophy: Node3D
var medals: Array=[]
var confetti: MultiMeshInstance3D
var champion:=0
var title:=""
var prize_amount:=0
var random:=RandomNumberGenerator.new()
var masks: Dictionary={}
var keeper_flags: Dictionary={}

func reset() -> void:
	prize_amount=0
	if is_instance_valid(stage): stage.queue_free()
	stage=null; trophy=null; confetti=null
	for medal in medals:
		if is_instance_valid(medal): medal.queue_free()
	medals.clear()
	for p in masks:
		if is_instance_valid(p): p.collision_mask=masks[p]; p.stamina_free_movement=false; p.celebration=""
	for p in keeper_flags:
		if is_instance_valid(p): p.keeper=keeper_flags[p]
	keeper_flags.clear()
	masks.clear(); keys.clear(); charging=false; paused=false; fixture={}

func begin_shootout(f: Dictionary) -> void:
	reset(); fixture=f; attempts=[[],[]]; totals=[0,0]; side=0; pools=[[],[]]
	random.seed=int(game.career.world.date)*137+int(f.stage)
	game.charging=false; game.cancel_pass(); game.carrier=-1; game.rules.reset()
	game.state="shootout"; game.ball.freeze=false; game.ball.active=true
	game.controller.held.clear()
	for p in game.players:
		masks[p]=p.collision_mask; p.collision_mask=1; p.desired=Vector3.ZERO; p.velocity=Vector3.ZERO
		p.chosen=false; p.set_piece_pose=""; p.action_timer=0; p.celebration=""; p.stamina_free_movement=true
		if p.visible and not p.dismissed: pools[p.team].append(p)
	# Equalise eligible takers after a dismissal. Each eligible player shoots before repeating.
	for team in range(2): pools[team].sort_custom(func(a,b): return a.attributes.finishing>b.attributes.finishing)
	var count:=mini(pools[0].size(),pools[1].size())
	for team in range(2): pools[team].resize(count)
	prepare()

func prepare() -> void:
	phase="ready"; age=0; charging=false; power=0; aim=Vector2(0,.45); keeper_jumped=false; saved=false; result=""
	shooter=pools[side][attempts[side].size()%pools[side].size()]
	keeper=game.players[11 if side==0 else 0]
	if keeper.dismissed or not keeper.visible:
		keeper=pools[1-side][0]
		if not keeper_flags.has(keeper): keeper_flags[keeper]=keeper.keeper
		keeper.keeper=true
	for p in game.players:
		p.position=Vector3((p.number%11-5)*1.2,0,-4 if p.team==0 else -8)
		p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO; p.action_timer=0; p.tackle_cooldown=0; p.pose="run"; p.facing=Vector3.BACK; p.rig.rotation=Vector3(0,PI,0); p.rig.position=Vector3.ZERO
	shooter.position=Vector3(-.45,0,37.8)
	keeper.position=Vector3(0,0,49.5); keeper.facing=Vector3.FORWARD; keeper.rig.rotation=Vector3.ZERO
	game.ball.place(Vector3(0,.23,39)); game.ball.active=true
	keeper_aim=random.randf_range(-3.3,3.3); keeper_delay=random.randf_range(.14,.27)

func handle(event: InputEvent) -> bool:
	if not game.state in ["shootout","trophy"]: return false
	if event is InputEventKey:
		if event.echo: return true
		game.controller.using_gamepad=false
		if event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]: keys[event.keycode]=event.pressed
		if event.pressed and event.keycode in [KEY_ESCAPE,KEY_P]: toggle_pause()
		if game.state=="trophy" and event.pressed and event.keycode in [KEY_SPACE,KEY_ENTER]: finish_ceremony()
		if event.keycode==KEY_D: shot_button(event.pressed)
	elif event is InputEventJoypadMotion:
		game.controller.using_gamepad=true
		if event.axis==JOY_AXIS_LEFT_X: axes.x=event.axis_value
		if event.axis==JOY_AXIS_LEFT_Y: axes.y=event.axis_value
	elif event is InputEventJoypadButton:
		game.controller.adopt_device(event.device)
		if event.button_index==JOY_BUTTON_START and event.pressed: toggle_pause()
		if game.state=="trophy" and event.button_index==JOY_BUTTON_A and event.pressed: finish_ceremony()
		if event.button_index==JOY_BUTTON_X: shot_button(event.pressed)
		var map:={JOY_BUTTON_DPAD_LEFT:KEY_LEFT,JOY_BUTTON_DPAD_RIGHT:KEY_RIGHT,JOY_BUTTON_DPAD_UP:KEY_UP,JOY_BUTTON_DPAD_DOWN:KEY_DOWN}
		if map.has(event.button_index): keys[map[event.button_index]]=event.pressed
	return true

func toggle_pause() -> void:
	paused=not paused; game.ball.freeze=paused; charging=false

func input_direction() -> Vector2:
	var value:=axes if game.controller.using_gamepad else Vector2.ZERO
	if value.length()<.18: value=Vector2.ZERO
	return (value+Vector2(int(keys.get(KEY_RIGHT,false))-int(keys.get(KEY_LEFT,false)),int(keys.get(KEY_DOWN,false))-int(keys.get(KEY_UP,false)))).limit_length(1)

func shot_button(pressed: bool) -> void:
	if paused or game.state!="shootout": return
	if side==0 and phase=="ready":
		if pressed: charging=true; power=0
		elif charging: charging=false; launch(aim,clampf(power,.16,1))
	elif side==1 and pressed and phase in ["ready","flight"] and not keeper_jumped:
		keeper_jumped=true
		var dir:=input_direction()
		keeper.start_dive((-1 if dir.x>=0 else 1)*(1.5+absf(dir.x)*2.2),1.5-dir.y,.45)

func launch(target: Vector2,strength: float) -> void:
	phase="flight"; age=0; charging=false
	var accuracy: float=shooter.attributes.finishing/100.0
	var error_size: float=(1-accuracy)*.5+maxf(0,strength-.82)*2.8
	var goal:=Vector3(target.x*3.42+random.randf_range(-error_size,error_size),.3+target.y*2.45,50.3)
	var origin:=Vector3(0,.23,39)
	var duration:=lerpf(.78,.38,strength)
	var velocity: Vector3=(goal-origin)/duration+Vector3.UP*(4.905*duration)
	game.ball.strike(velocity)
	shooter.begin_kick(strength,.55,"laces",origin,velocity.normalized())
	last_ball=origin
	game.audio.contact("kick",strength)
	game.stadium.crowd.react("shot",side,origin)
	# Keeper commits with imperfect anticipation, never tracks every change exactly.
	if side==0: keeper_aim=goal.x+random.randf_range(-1.8,1.8)

func update(delta: float) -> void:
	if paused: return
	age+=delta
	if game.state=="trophy": celebrate(delta); return
	if game.state!="shootout": return
	shooter.step(delta); keeper.step(delta)
	if phase=="ready":
		if side==0:
			var direction:=input_direction()
			if game.controller.using_gamepad and not keys.values().has(true):
				direction=game.controller.precision_stick(axes)
				direction=direction.normalized()*game.controller.aim_response(direction.length())
			aim.x=clampf(aim.x-direction.x*delta*.8,-1,1); aim.y=clampf(aim.y-direction.y*delta*.6,0,1)
			if charging: power=minf(1,power+delta*.75)
		elif age>2.5: launch(Vector2(random.randf_range(-.98,.98),random.randf_range(.02,.70)),random.randf_range(.45,.82))
	elif phase=="flight":
		var point: Vector3=game.ball.position
		if side==0 and not keeper_jumped and age>=keeper_delay:
			keeper_jumped=true; keeper.start_dive(keeper_aim,clampf(aim.y*2.5,.4,2.3),.43)
		# Sweep the ball between frames against the keeper's animated hands/body.
		if not saved:
			for n in range(5):
				if keeper.can_save(last_ball.lerp(point,n/4.0)):
					saved=true; game.ball.strike(Vector3(signf(point.x)*8,2.2,-9)); break
		if last_ball.z<50.22 and point.z>=50.22:
			var cross:=last_ball.lerp(point,(50.22-last_ball.z)/maxf(.001,point.z-last_ball.z))
			resolve(absf(cross.x)<3.44 and cross.y<2.22)
		elif age>3 or (point.z<45 and age>1) or absf(point.x)>6: resolve(false)
		last_ball=point
	elif phase=="result" and age>2:
		if shootout_winner()>=0:
			fixture.penalties=totals.duplicate() if fixture.home==game.career.world.user else [totals[1],totals[0]]
			fixture.live_penalties=true; game.state="finished"; game.ball.active=false
		else: side=1-side; prepare()

func resolve(goal: bool) -> void:
	if phase!="flight": return
	attempts[side].append(goal)
	if goal: totals[side]+=1
	phase="result"; age=0; result="GOL" if goal else ("KURTARIŞ" if saved else "KAÇTI")
	var reaction: String="goal" if goal else ("save" if saved else "miss")
	game.audio.react(reaction,side,game.ball.position); game.stadium.crowd.react(reaction,side,game.ball.position)

func shootout_winner() -> int:
	var a: int=attempts[0].size(); var b: int=attempts[1].size()
	if a<=5 and b<=5:
		if totals[0]>totals[1]+maxi(0,5-b): return 0
		if totals[1]>totals[0]+maxi(0,5-a): return 1
	if a>=5 and a==b and totals[0]!=totals[1]: return 0 if totals[0]>totals[1] else 1
	return -1

func after_result(f: Dictionary) -> void:
	var c=game.career
	if f.has("competition") and c.world.cups[f.competition].champion!="":
		var winner: String=c.world.cups[f.competition].champion
		begin_ceremony(0 if winner==c.world.user else 1,c.world.cups[f.competition].title)
		prize_amount=c.cups.championship_prize(f.competition)
	elif not f.has("competition"):
		var remaining: bool=c.world.fixtures.any(func(q): return not q.played and q.league==f.league)
		if not remaining and c.standings(f.league)[0]==c.world.user:
			begin_ceremony(0,preload("res://scripts/career_world.gd").LEAGUES[f.league])
			prize_amount=preload("res://scripts/career_world.gd").LEAGUE_CHAMPION_PRIZES[f.league]

	if game.state!="trophy": reset()

func begin_ceremony(winner: int,label: String) -> void:
	reset(); champion=winner; title=label; age=0; game.state="trophy"; game.ball.freeze=true
	stage=Node3D.new(); game.add_child(stage)
	var dark:=G.material(Color("173c3a")); var gold:=G.material(Color("e6c570"),.22); gold.metallic=.75
	G.block(stage,Vector3(15,.22,5),Vector3(0,.03,0),dark)
	G.block(stage,Vector3(15,.07,.12),Vector3(0,.18,-2.5),gold)
	trophy=Node3D.new(); stage.add_child(trophy)
	G.cylinder(trophy,.21,.12,Vector3.ZERO,dark); G.cylinder(trophy,.07,.36,Vector3(0,.23,0),gold)
	G.cylinder(trophy,.15,.43,Vector3(0,.60,0),gold,.34)
	for side_x in [-1,1]:
		for n in range(12):
			var a: float=-PI*.7+n*PI*1.4/12; var b: float=-PI*.7+(n+1)*PI*1.4/12
			G.rod(trophy,Vector3(side_x*(.23+cos(a)*.23),.60+sin(a)*.24,0),Vector3(side_x*(.23+cos(b)*.23),.60+sin(b)*.24,0),.025,gold)
	var count:=0
	for p in game.players:
		masks[p]=p.collision_mask; p.collision_mask=1; p.action_timer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO; p.stamina_free_movement=true
		p.chosen=false; p.shot_preparation=0; p.set_piece_pose=""
		if p.team==winner and p.visible and not p.dismissed:
			p.position=Vector3((count%6-2.5)*1.75,.16,-.5+floori(count/6.0)*1.9); p.facing=Vector3.FORWARD; p.rig.rotation.y=0
			p.celebration="cheer"; count+=1
			var medal:=Node3D.new(); p.spine.add_child(medal); medals.append(medal)
			var ribbon:=G.material(Color("22487c")); G.rod(medal,Vector3(-.16,.52,-.17),Vector3(0,.19,-.29),.016,ribbon); G.rod(medal,Vector3(.16,.52,-.17),Vector3(0,.19,-.29),.016,ribbon)
			G.sphere(medal,.062,Vector3(0,.18,-.30),gold)
		else: p.position=Vector3(10+p.number*.6,0,8); p.celebration="dejected"
	shooter=game.players.filter(func(p): return p.team==winner and p.visible and not p.dismissed and not p.keeper)[0]; shooter.position=Vector3(0,.16,-1.7)
	confetti=MultiMeshInstance3D.new(); confetti.multimesh=MultiMesh.new(); confetti.multimesh.transform_format=MultiMesh.TRANSFORM_3D; confetti.multimesh.use_colors=true
	var mesh:=BoxMesh.new(); mesh.size=Vector3(.10,.025,.18); mesh.material=G.material(Color.WHITE)
	mesh.material.vertex_color_use_as_albedo=true; confetti.multimesh.mesh=mesh; confetti.multimesh.instance_count=260; stage.add_child(confetti)
	game.audio.react("goal",winner,Vector3.ZERO); game.stadium.crowd.react("goal",winner,Vector3.ZERO)

func celebrate(delta: float) -> void:
	for p in game.players:
		if p.team!=champion or not p.visible or p.dismissed: continue
		p.step(delta)
		p.position.y=.16+absf(sin(age*3.8+p.number))*.18
	var lift:=smoothstep(1.8,4.2,age)
	shooter.spine.rotation=Vector3.ZERO
	shooter.left_arm.rotation=Vector3(1.1+lift*1.85,0,-.08); shooter.right_arm.rotation=Vector3(1.1+lift*1.85,0,.08)
	shooter.left_elbow.rotation.x=.08; shooter.right_elbow.rotation.x=.08
	trophy.global_position=(shooter.left_hand.global_position+shooter.right_hand.global_position)*.5-Vector3(0,.5,0)
	trophy.rotation.z=sin(age*4)*.035*lift
	for i in range(260):
		var pos:=Vector3(sin(i*9.71)*8+sin(age+i)*.7,8-fmod(age*(.75+i%5*.08)+i*.037,8),cos(i*3.13)*5)
		var t:=Transform3D(Basis.from_euler(Vector3(age+i,age*.7,i)),pos)
		confetti.multimesh.set_instance_transform(i,t); confetti.multimesh.set_instance_color(i,Color("e6c570") if i%2==0 else Color("f2f0df"))
	if age>22: finish_ceremony()

func finish_ceremony() -> void:
	if game.state!="trophy" or age<1: return
	reset(); game.state="finished"; game.ball.freeze=false; game.ball.active=false

func camera() -> bool:
	if not game.state in ["shootout","trophy"]: return false
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	if game.state=="shootout":
		game.camera.fov=48; game.camera.position=Vector3(0,5.1,30.5); game.camera.look_at(Vector3(0,1.0,47))
	else:
		game.camera.fov=42; game.camera.position=Vector3(sin(age*.06)*2,3.8,-13.5); game.camera.look_at(Vector3(0,1.45,0))
	return true

func draw(h) -> void:
	h.panel(Rect2(310,42,820,142),Color("122c30"),12)
	if game.state=="trophy":
		h.center(title.to_upper(),Vector2(720,87),21,h.GOLD)
		h.center("ŞAMPİYON  ·  "+game.clubs.career_clubs[champion].name,Vector2(720,139),32)
		if prize_amount>0:
			h.panel(Rect2(450,199,540,79),Color("183b34"),10)
			h.center("ŞAMPİYONLUK ÖDÜLÜ",Vector2(720,226),12,h.GOLD)
			h.center("+ "+game.career.money(prize_amount),Vector2(720,260),28,h.GOLD)
		h.center("DEVAM ET  ·  A / SPACE",Vector2(720,837),17,h.GOLD)
		return
	h.center("PENALTI ATIŞLARI    %d — %d" % totals,Vector2(720,80),29,h.GOLD)
	for team in range(2):
		for n in range(maxi(5,attempts[team].size())):
			var color: Color=h.MUTE if n>=attempts[team].size() else (Color("78d8a5") if attempts[team][n] else Color("eb8e7c"))
			h.draw_circle(Vector2(412+(n%11)*30+team*340,119+floori(n/11.0)*20),8,color)
	h.panel(Rect2(285,737,870,124),Color("122c30"),10)
	h.center("DURAKLATILDI · ESC / START" if paused else (result if phase=="result" else ("YÖNÜ AYARLA · ŞUTU BASILI TUT, BIRAK" if side==0 else "KALECİ SENSİN · YÖN + ŞUT İLE ATLA")),Vector2(720,772),20,h.GOLD)
	if game.controller.using_gamepad: game.controller.Glyphs.draw_hints(h,Vector2(483,802),[["LS / D-PAD","Yön"],["X","Şut / Atla"],["START","Mola"]],game.controller.family,h.font,24,13)
	else: h.center("YÖN TUŞLARI · D ŞUT / ATLA · ESC MOLA",Vector2(720,807),15)
	if side==0 and phase=="ready":
		h.draw_rect(Rect2(446,825,548,9),Color("38504b")); h.draw_rect(Rect2(446,825,548*power,9),h.GOLD if power<.83 else Color("e48e73"))
		var point: Vector2=game.camera.unproject_position(Vector3(aim.x*3.42,.3+aim.y*2.45,50))
		h.draw_arc(point,12,0,TAU,32,h.GOLD,2,true); h.draw_circle(point,3,h.PAPER)
