extends RefCounted
const LABELS := ["SABİT RAKİP","MÜDAHALEYİ BEKLE","SERBEST SAVUNMACI"]
var game
var stage := 0
var wins := 0
var used := false
var age := 0.0
var wait := -1.0
var result := ""
var result_time := 0.0
var advance := false
var line := -16.8

func reset() -> void:
	stage=0; wins=0; result=""; result_time=0; advance=false

func next_stage() -> void:
	stage=(stage+1)%3; wins=0; advance=false
	game.reset_practice()

func setup() -> void:
	if advance: stage=mini(2,stage+1); wins=0; advance=false
	used=false; age=0; wait=-1
	for i in range(game.players.size()):
		var p=game.players[i]
		p.visible=i in [9,14]; p.collision_layer=2 if p.visible else 0
		p.desired=Vector3.ZERO; p.velocity=Vector3.ZERO
	var user=game.players[9]
	user.position=Vector3(0,0,-12); user.facing=Vector3.FORWARD; user.rig.rotation.y=0
	var opponent=game.players[14]
	opponent.position=Vector3(0,0,-14.8); opponent.facing=Vector3.BACK; opponent.rig.rotation.y=PI
	game.ball.place(user.position+Vector3(0,game.ball.GROUND_HEIGHT,-.55))
	game.previous_ball=game.ball.position; game.camera_focus=user.position+Vector3.FORWARD*2
	game.controlled=9; game.dribbler=9; game.carrier=9; game.last_kicker=9
	game.kick_lock=0; game.player_lock=true
	game.players[9].touch_cooldown=0
	game.match_camera.snap=true

func actor(index: int) -> void:
	var p=game.players[index]
	p.desired=Vector3.ZERO; p.sprinting=false; p.jockeying=true
	p.facing=((game.players[9].position-p.position)*Vector3(1,0,1)).normalized()
	if stage==1 and wait<0 and age>.8 and game.flat_distance(p.position,game.ball.position)<1.45 and p.action_timer<=0 and p.tackle_cooldown<=0:
		game.duels.standing_tackle(index)

func finish(message: String,success: bool=false) -> void:
	if wait>=0: return
	result=message; result_time=4; wait=2.0
	if success:
		wins+=1
		if wins>=2 and stage<2: advance=true

func update(delta: float) -> void:
	age+=delta; result_time=maxf(0,result_time-delta)
	if wait>=0:
		wait-=delta
		if wait<=0: game.reset_practice()
		return
	if game.ball.pending_reset: return
	var p=game.players[9]
	if game.last_touch==1 or game.dribbler==14:
		finish("TOP RAKİBE AÇILDI · TEMASI BEKLEYİP BOŞ YANA ÇIK")
	elif used and p.position.z<line and absf(p.position.x)<4 and game.flat_distance(p.position,game.ball.position)<1.7 and game.has_ball_control(9):
		finish("GEÇTİN VE TOPU KORUDUN"+(" · SONRAKİ AŞAMA" if wins>=1 and stage<2 else ""),true)
	elif absf(p.position.x)>8 or game.flat_distance(p.position,game.ball.position)>7:
		finish("TOPU FAZLA AÇTIN · ÇIKIŞTA TOPA YAKIN KAL")
	elif age>16:
		finish("RAKİP HÂLÂ ÖNÜNDE · HIZINI VE ÇIKIŞ YÖNÜNÜ DEĞİŞTİR" if used else "ÖNCE BİR HAREKET DENE · 2 / 9 / 0")

func draw(hud) -> void:
	var left := Vector3(-4,.04,line)
	var right := Vector3(4,.04,line)
	if not game.camera.is_position_behind(left) and not game.camera.is_position_behind(right):
		var a: Vector2=game.screen_position(left)
		var b: Vector2=game.screen_position(right)
		hud.draw_line(a,b,Color(.5,.9,.75,.65),3,true)
		hud.center("TOPLA GEÇ",(a+b)*.5+Vector2(0,-10),11,hud.GOLD)
	hud.draw_set_transform(game.ui.edge_offset(-1,-1))
	hud.panel(Rect2(32,142,530,93),Color("101c22"),4)
	hud.text("%d/3 · %s  ·  %d/2" % [stage+1,LABELS[stage],mini(wins,2)],Vector2(46,164),13,hud.GOLD,true)
	var instruction: String=["Çalım yap ve çizgiyi top yanında geç.","Rakibin uzanan ayağından yana çekerek kaç.","Beklerse hız değiştir; hamle yaparsa tersine çık."][stage]
	hud.text(instruction,Vector2(46,187),12,hud.PAPER)
	hud.text("LT + R3: aşama  ·  R3: yeniden" if game.controller.using_gamepad else "F3: aşama  ·  R: yeniden",Vector2(46,217),11,hud.MUTE)
	hud.draw_set_transform(Vector2.ZERO)
	hud.panel(Rect2(420,804,600,63),Color("101c22"),4)
	hud.center("RS yana: çek  ·  RB + RS geri: dur–kalk  ·  RB + RS yana: aç" if game.controller.using_gamepad else "2 + YÖN: yana çek  ·  9: dur–kalk  ·  0 + YÖN: aç ve dolaş",Vector2(720,829),12,hud.GOLD)
	hud.center(result if result_time>0 else "Hazırlıkta pasla vazgeçebilirsin. İki başarılı geçişte aşama ilerler.",Vector2(720,852),11,hud.PAPER)
