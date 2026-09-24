extends RefCounted
const World=preload("res://scripts/career_world.gd")
var game
var presentation:=preload("res://scripts/trophy_presentation.gd").new()
var return_to_hub:=false
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
	presentation.clear(); return_to_hub=false

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
	game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,39)); game.ball.active=true
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
	paused=not paused; game.ball.freeze=paused or game.state=="trophy"; charging=false

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
	var accuracy: float=(float(shooter.attributes.finishing)*.6+shooter.Attributes.value(shooter,"composure")*.4)/100.0
	var error_size: float=(1-accuracy)*.5+maxf(0,strength-.82)*2.8
	var goal:=Vector3(target.x*3.42+random.randf_range(-error_size,error_size),.3+target.y*2.45,50.3)
	var origin:=Vector3(0,game.ball.GROUND_HEIGHT,39)
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
					saved=true
					game.feedback.contact("glove",game.players.find(keeper),point,game.ball.linear_velocity.normalized(),clampf(game.ball.linear_velocity.length()/25,.18,1))
					game.ball.strike(Vector3(signf(point.x)*8,2.2,-9)); break
		if last_ball.z<(50+game.ball.RADIUS) and point.z>=(50+game.ball.RADIUS):
			var cross:=last_ball.lerp(point,((50+game.ball.RADIUS)-last_ball.z)/maxf(.001,point.z-last_ball.z))
			resolve(absf(cross.x)<3.66-game.ball.RADIUS and cross.y<2.44-game.ball.RADIUS)
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

func award_for(f: Dictionary) -> Dictionary:
	var c=game.career
	if not f.get("played",false): return {}
	if f.has("competition"):
		var key: String=f.competition
		var cup: Dictionary=c.world.cups.get(key,{})
		var winner: String=cup.get("champion","")
		if winner!="" and winner in [f.home,f.away]:
			return {"club":winner,"opponent":f.away if winner==f.home else f.home,"title":cup.title,"prize":c.cups.championship_prize(key)}
	elif c.world.league_prizes.get("%d:%d" % [c.world.year,f.league],{}).get("champion","")==c.world.user:
		return {"club":c.world.user,"opponent":f.away if c.world.user==f.home else f.home,"title":World.LEAGUES[f.league],"prize":World.LEAGUE_CHAMPION_PRIZES[f.league]}
	return {}

func award_for_division(division: int) -> Dictionary:
	var c=game.career
	var matches: Array=c.world.fixtures if division<World.LEAGUES.size() else c.world.cup_fixtures
	var key: String=["domestic","champions","super"][division-World.LEAGUES.size()] if division>=World.LEAGUES.size() else ""
	for i in range(matches.size()-1,-1,-1):
		var f: Dictionary=matches[i]
		if not f.played or c.world.user not in [f.home,f.away]: continue
		if (key!="" and f.get("competition","")!=key) or (key=="" and f.league!=division): continue
		var award:=award_for(f)
		if award.get("club","")==c.world.user: return award
	return {}

func after_result(f: Dictionary) -> void:
	var award:=award_for(f)
	if award.is_empty(): reset(); return
	begin_ceremony(0 if award.club==game.career.world.user else 1,award.title)
	prize_amount=award.prize

func show_award(award: Dictionary) -> bool:
	if award.is_empty() or game.career.in_match: return false
	var c=game.career
	c.remember_quick_match()
	game.clubs.career_clubs=[]; game.clubs.career_rosters=[[],[]]
	for side_index in range(2):
		var id: String=award.club if side_index==0 else award.opponent
		var club: Dictionary=c.world.clubs[id]
		game.clubs.career_clubs.append(club.duplicate(true))
		var chosen: Array=club.lineup.filter(func(pid): return pid in club.roster)
		for pid in club.roster:
			if not pid in chosen: chosen.append(pid)
		if chosen.size()<18: game.clubs.clear_career(); return false
		for pid in chosen.slice(0,18): game.clubs.career_rosters[side_index].append(c.player(pid).duplicate(true))
	game.clubs.lineups=[range(11),range(11)]; game.clubs.reserves=[range(11,18),range(11,18)]
	game.clubs.apply()
	# A menu replay/simulated match uses fresh scene actors, not discipline or
	# hidden rigs left over from the last physically played match.
	for p in game.players:
		p.dismissed=false; p.visible=true; p.rig.show(); p.pose="run"
	var screen=game.career_screen
	screen.hide(); screen.clear_controls(); game.frontend.hide()
	game.camera.cull_mask=screen.world_mask; game.audio.set_process(true)
	game.weather.sound.stream_paused=false
	begin_ceremony(0,award.title)
	prize_amount=award.prize; return_to_hub=true
	return true

func begin_ceremony(winner: int,label: String) -> void:
	reset(); champion=winner; title=label; age=0; game.state="trophy"; game.ball.freeze=true
	presentation.begin(self)
	if not is_instance_valid(trophy): game.state="finished"

func celebrate(delta: float) -> void:
	presentation.update(self,delta)

func finish_ceremony() -> void:
	if game.state!="trophy" or age<1 or paused: return
	var hub:=return_to_hub
	reset(); game.state="finished"; game.ball.freeze=false; game.ball.active=false
	if hub:
		game.career.detach(); game.clubs.apply(); game.career_screen.open_hub()

func camera() -> bool:
	if not game.state in ["shootout","trophy"]: return false
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	if game.state=="shootout":
		game.camera.fov=48; game.camera.position=Vector3(0,5.1,30.5); game.camera.look_at(Vector3(0,1.0,47))
	else:
		presentation.camera(self)
	return true

func draw(h) -> void:
	if game.state=="trophy":
		var compact:=1.0 if game.experience.reduce_motion else smoothstep(1.8,3.2,presentation.timeline(self))
		var card:=Rect2(Vector2(310,42).lerp(Vector2(32,30),compact),Vector2(820,142).lerp(Vector2(560,76),compact))
		h.panel(card,Color("122c30"),10)
		h.center(title.to_upper(),card.position+Vector2(card.size.x*.5,lerpf(45,26,compact)),roundi(lerpf(21,12,compact)),preload("res://scripts/ui_style.gd").GOLD)
		h.center("ŞAMPİYON  ·  "+game.clubs.career_clubs[champion].name,card.position+Vector2(card.size.x*.5,lerpf(97,56,compact)),roundi(lerpf(32,21,compact)))
		if prize_amount>0:
			h.panel(Rect2(1100,30,308,76),Color("183b34"),10)
			h.center("ŞAMPİYONLUK ÖDÜLÜ",Vector2(1254,57),11,preload("res://scripts/ui_style.gd").GOLD)
			h.center("+ "+game.career.money(prize_amount),Vector2(1254,87),23,preload("res://scripts/ui_style.gd").GOLD)
		var phase_text: String={"presentation":"ŞAMPİYONLUK TÖRENİ","receive":"KAPTAN KUPAYI TESLİM ALIYOR","lift":"KUPA HAVAYA!","celebrate":"TAKIMINLA KUTLA","share":"BU KUPA HEPİMİZİN","photo":"ŞAMPİYON KADRO · TAKIM FOTOĞRAFI"}.get(phase,"")
		h.panel(Rect2(490,750,460,44),Color("122c30"),10)
		h.center("DURAKLATILDI · ESC / START" if paused else phase_text,Vector2(720,778),15,preload("res://scripts/ui_style.gd").GOLD)
		if game.controller.using_gamepad:
			game.controller.Glyphs.draw_hints(h,Vector2(551,817),[["A","Devam et"],["START","Mola"]],game.controller.family,h.font,24,13)
		else: h.center("DEVAM ET · ENTER / SPACE    |    ESC · MOLA",Vector2(720,837),17,preload("res://scripts/ui_style.gd").GOLD)
		return
	h.panel(Rect2(310,42,820,142),Color("122c30"),12)
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
		var point: Vector2=game.screen_position(Vector3(aim.x*3.42,.3+aim.y*2.45,50))
		h.draw_arc(point,12,0,TAU,32,h.GOLD,2,true); h.draw_circle(point,3,h.PAPER)
