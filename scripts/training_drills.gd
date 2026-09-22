extends RefCounted
## Script only the exercise partner; every delivery, shot and save uses live physics.
const MODES := ["free","cross","free_kick"]
const TITLES := ["SERBEST ANTRENMAN","ORTA & KAFA","SERBEST VURUŞ"]
var game
var mode := "free"
var attempt := 0
var phase := ""
var age := 0.0
var held_age := 0.0
var feeder := 8
var station := Vector3.ZERO
var target := Vector3.ZERO
var wall: Array[int] = []

func begin(value: String) -> void:
	mode=value if value in MODES else "free"
	attempt=0; phase=""; age=0; held_age=0; wall.clear()

func title() -> String:
	return TITLES[MODES.find(mode)]

func setup() -> void:
	attempt+=1; age=0; held_age=0; wall.clear()
	phase="free" if mode=="free" else "waiting"
	for i in range(game.players.size()):
		var p=game.players[i]
		p.visible=i in [9,11] or (mode=="cross" and i==feeder) or (mode=="free_kick" and i in [12,13,14,15])
		p.collision_layer=2 if p.visible else 0
	if mode=="free": return
	if mode=="cross":
		station=Vector3(23 if attempt%2==1 else -23,0,-39)
		game.players[9].position=Vector3(0,0,-40)
		var partner=game.players[feeder]
		partner.position=station
		partner.facing=(game.players[9].position-station).normalized()
		partner.rig.rotation.y=atan2(-partner.facing.x,-partner.facing.z)
		game.ball.place(station+partner.facing*.74+Vector3.UP*.23)
		game.previous_ball=station+partner.facing*.74+Vector3.UP*.23
		game.announce("ORTA ÇALIŞMASI · CEZA SAHASINDA YERİNİ AL")
	else:
		var points := [Vector3(-7,0,-26),Vector3(6,0,-28),Vector3(0,0,-24)]
		game.restart_point=points[(attempt-1)%points.size()]
		game.restart_type="SERBEST VURUŞ"; game.restart_team=0
		game.players[9].position=game.restart_point+Vector3.BACK
		game.state="restart"
		game.set_pieces.prepare()
		game.set_pieces.snap_ready()
		wall.assign(game.set_pieces.wall)
		for i in wall: game.players[i].set_piece_pose="wall"
		phase="setup"
	game.match_camera.snap=true

func manages(index: int) -> bool:
	return game.training and ((mode=="cross" and index==feeder) or (mode=="free_kick" and index in wall))

func actor(index: int) -> void:
	var p=game.players[index]
	p.desired=Vector3.ZERO; p.sprinting=false
	if index==feeder and mode=="cross":
		p.facing=((game.players[9].position-p.position)*Vector3(1,0,1)).normalized()
		if phase=="waiting":
			p.desired=(station-p.position)*Vector3(1,0,1)
	else:
		p.facing=((game.ball.position-p.position)*Vector3(1,0,1)).normalized()

func request_cross() -> bool:
	if mode!="cross": return false
	if phase=="waiting":
		age=maxf(age,1.5)
		game.players[9].call_timer=.7
	else: game.announce("ORTA YOLDA · ŞUT TUŞUYLA KAFA VURUŞU")
	return true

func deliver_cross() -> bool:
	if game.ball.pending_reset or not game.can_touch(feeder,1.3) or game.kick_lock>0: return false
	var p=game.players[9]
	var lead: Vector3=(p.velocity*Vector3(1,0,1)*.45).limit_length(2.5)
	target=Vector3(clampf(p.position.x+lead.x,-12,12),game.heading.head_point(p).y+.28,clampf(p.position.z+lead.z,-45,-33))
	var flight := 1.45
	var velocity: Vector3=game.Passing.Motion.lob_velocity(game.ball.position,target,flight,game.weather)
	if not game.strike(feeder,velocity,0,false,"cross"): return false
	game.passes[0]+=1
	game.incoming_receiver=9; game.incoming_time=flight+1
	# Do not invoke the ground-pass assist: it would run the finisher towards
	# the rising ball and away from the cross's actual meeting point.
	game.ai_receivers[0]=-1; game.ai_pass_time[0]=0
	phase="live"; age=0
	game.announce("ORTA GELİYOR · ŞUT TUŞUYLA KAFA VURUŞU")
	return true

func update(delta: float) -> void:
	if not game.training or mode=="free" or game.state not in ["playing","restart","set_piece"]: return
	if mode=="free_kick" and phase=="setup":
		if game.ball.pending_reset: return
		if game.state=="restart": game.set_pieces.recovery.step(delta)
		if game.state=="set_piece": phase="ready"
		return
	if game.state!="playing": return
	if mode=="free_kick" and phase=="ready": phase="live"; age=0
	age+=delta
	if mode=="cross" and phase=="waiting":
		if age>=1.8: deliver_cross()
		# A disrupted setup must not strand the exercise partner without a ball.
		if age>7: game.reset_practice()
		return
	if phase!="live": return
	held_age=held_age+delta if game.ball.held_by!=null else 0.0
	if held_age>.8 or age>11:
		game.reset_practice()

func instruction() -> String:
	if mode=="cross":
		return "Kanattaki arkadaşın hazırlanıyor. Yerini al; pas tuşuyla ortayı iste." if phase=="waiting" else "Topa yaklaş; havadayken şut tuşuyla kafa vur."
	if mode=="free_kick":
		return "Yönünü seç; şuta basılı tutup bırak. Falso da kullanabilirsin." if phase in ["setup","ready"] else "Seken topu tamamlayabilirsin. Sonra yeni deneme kurulacak."
	return "Mevcut serbest çalışma: topu sür, yönünü seç, şutunu çek."
