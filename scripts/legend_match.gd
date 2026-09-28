extends RefCounted
const Progress=preload("res://scripts/legend_progression.gd")
var game
var ref: WeakRef
var legend:
	get: return ref.get_ref()
	set(value): ref=weakref(value)
var index:=-1
var entered:=0.0
var queued:=false
var passes:=0
var completed:=0
var losses:=0
var assists:=0
var pending:=false
var pass_age:=0.0
var pass_origin:=Vector3.ZERO
var assist_player:=-1
var assist_age:=99.0
var position_time:=0.0
var good_position:=0.0
var previous_owner:=-1
var sample:=0.0
const SKIP_RECT:=Rect2(1075,245,325,42)

func begin() -> void:
	index=-1; entered=0; queued=false; passes=0; completed=0; losses=0; assists=0
	pending=false; pass_age=0; assist_player=-1; assist_age=99
	position_time=0; good_position=0; previous_owner=-1; sample=0
	for i in range(11):
		if game.players[i].career_id==legend.data().player: index=i; break
	for p in game.players: Progress.World.Equipment.present(legend.career.world,p)
	enforce_control()

func enforce_control() -> void:
	if not legend.match_active(): return
	game.player_lock=true
	if legend.on_pitch(): game.controlled=index
	for i in range(game.players.size()): game.players[i].chosen=legend.on_pitch() and i==index

func entered_player(p) -> void:
	if not legend.match_active() or p.career_id!=legend.data().player: return
	Progress.World.Equipment.present(legend.career.world,p)
	index=game.players.find(p); entered=game.match_time
	enforce_control()
	game.announce("OYUNDASIN · "+Progress.POSITIONS[int(legend.data().position)]+" · S ile pas iste")

func queue_entry() -> void:
	if queued or index>=0 or not legend.match_active(): return
	var reserve:=-1
	for i in range(game.management.bench[0].size()):
		if game.management.bench[0][i].get("career_id","")==legend.data().player and not game.management.bench[0][i].used: reserve=i; break
	if reserve<0: return
	var slot: int=legend.selection.slot
	if game.players[slot].dismissed:
		for i in range(1,11):
			if not game.players[i].dismissed: slot=i; break
	var reason: String=game.management.substitution_reason(slot,reserve)
	if reason!="": return
	game.management.queue_sub(slot,reserve); queued=true
	if game.state in ["restart","halftime"]: game.management.prepare_substitutions()

func skip_bench() -> void:
	if not legend.match_active() or index>=0 or queued or game.state not in ["playing","restart","set_piece"]: return
	var target:=maxf(game.match_time,float(legend.selection.minute)/90.0*game.LENGTH)
	var minutes: float=(target-game.match_time)/game.LENGTH*90
	var c=legend.career
	c.randomize_state()
	# Simulate only the unplayed bench interval; the fixture is settled once,
	# after the user has actually played the remaining minutes.
	for side in range(2):
		var ids: Array=c.match_ids[side].slice(0,11)
		var strength:=0.0; var rival:=0.0
		for pid in ids: strength+=Progress.World.ovr(c.player(pid))/11.0
		for pid in c.match_ids[1-side].slice(0,11): rival+=Progress.World.ovr(c.player(pid))/11.0
		var chance:=clampf(.16+(strength-rival)*.009,.035,.43)
		var attacks: float=8*minutes/90.0
		for n in range(ceili(attacks)):
			if c.rng.randf()>=chance*minf(1,attacks-n): continue
			var scorer: String=ids[c.rng.randi_range(5,10)]
			game.score[side]+=1; c.match_goals[scorer]=int(c.match_goals.get(scorer,0))+1
			var actor=game.players[side*11+ids.find(scorer)]
			game.match_report.player(actor).goals+=1
			game.shots[side]+=1; game.shots_on_target[side]+=1
	c.remember_random()
	game.match_time=target; game.match_report.sync()
	game.half=2 if target>=game.LENGTH*.5 else 1
	game.management.apply_formation(); game.reset_positions(0)
	for p in game.players:
		p.energy=maxf(.55,p.energy-minutes/90*.28)
	queue_entry()
	game.begin_restart("TAÇ",0,Vector3(game.P.HALF_WIDTH,0,0))
	enforce_control()

func update(delta: float) -> void:
	if not legend.match_active(): return
	enforce_control()
	if not legend.on_pitch():
		if game.match_time/game.LENGTH*90>=float(legend.selection.get("minute",90)) and game.state in ["playing","restart","halftime"]: queue_entry()
		return
	if game.state!="playing": return
	assist_age+=delta
	if pending:
		pass_age+=delta
		if pass_age>5: pending=false; losses+=1
	sample+=delta
	if sample<.25: return
	var elapsed:=sample; sample=0
	var p=game.players[index]
	var target: Vector3=p.home
	if not p.keeper:
		target.z=clampf(target.z+game.ball.position.z*.24,-44,44)
		if game.ball.position.distance_to(p.position)<12: target=p.position
	position_time+=elapsed
	if game.flat_distance(p.position,target)<(18 if not p.keeper else 10): good_position+=elapsed
	var owner: int=game.dribbler
	if previous_owner==index and owner>=11 and not pending: losses+=1
	previous_owner=owner

func strike(actor: int,kind: String,is_save: bool) -> void:
	if not legend.match_active() or is_save: return
	if actor>=11: assist_player=-1
	if actor!=index or not legend.on_pitch(): return
	if kind in ["kick","cross","distribution","header_pass"]:
		passes+=1; pending=true; pass_age=0; pass_origin=game.players[index].position

func touched(actor: int) -> void:
	if not legend.match_active() or actor<0: return
	if actor>=11: assist_player=-1
	if not pending or actor==index or pass_age<.08: return
	pending=false
	if actor<11:
		if game.flat_distance(pass_origin,game.players[actor].position)>=3:
			completed+=1; assist_player=actor; assist_age=0
	else: losses+=1

func goal(team: int,kicker: int) -> void:
	if legend.match_active() and team==0 and kicker==assist_player and assist_age<8: assists+=1
	assist_player=-1

func result() -> Dictionary:
	var row: Dictionary=game.match_report.rows.get(legend.data().player,{}).duplicate(true)
	var minutes: float=float(legend.career.match_minutes.get(legend.data().player,row.get("minutes",0)))
	row.minutes=minutes; row.passes=passes; row.completed=completed; row.losses=losses; row.assists=assists
	row.position_share=good_position/position_time if position_time>=5 else .6
	var value:=6.0+float(row.get("goals",0))*.95+assists*.7+minf(.75,completed*.045)+minf(1.4,float(row.get("tackles",0))*.23)+minf(2,float(row.get("saves",0))*.3)
	value+=clampf((row.position_share-.6)*1.5,-.9,.6)
	value-=minf(1.4,losses*.12)+float(row.get("yellow",0))*.25+float(row.get("own_goals",0))*.8+(1.5 if row.get("red",false) else 0.0)
	if completed+int(row.get("goals",0))+int(row.get("tackles",0))+int(row.get("saves",0))+assists==0: value=minf(6,value)
	row.rating=snappedf(clampf(value,3,10),.1)
	return row

func draw(h) -> void:
	h.draw_set_transform(game.ui.edge_offset(1,-1))
	h.panel(Rect2(1059,135,357,165),Color("10252e"),10,Color(h.GOLD,.24))
	if legend.on_pitch():
		var row:=result()
		h.text("EFSANE · "+Progress.SHORT[int(legend.data().position)],Vector2(1077,162),13,h.GOLD,true)
		h.UI.fit(h,h.bold,legend.player().name,Vector2(1077,191),320,18,h.PAPER)
		h.text("MAÇ NOTU  %.1f" % row.rating,Vector2(1077,222),20,h.GOLD,true)
		h.text("Pas %d / %d · Asist %d" % [completed,passes,assists],Vector2(1077,248),13,h.PAPER)
		h.text(h.action_label(KEY_S)+" · Top sendeyken pas / topsuzken pas iste",Vector2(1077,278),12,h.MUTE)
	else:
		h.text("EFSANE · MAÇ DIŞI" if index>=0 else "EFSANE · YEDEK KULÜBESİ",Vector2(1077,163),13,h.GOLD,true)
		h.UI.fit(h,h.bold,legend.player().name,Vector2(1077,192),320,18,h.PAPER)
		if index>=0:
			h.text("Artık sahada değilsin. Takımın maça devam ediyor.",Vector2(1077,225),12,h.MUTE)
		elif queued:
			h.text("Değişiklik bekleniyor · Birazdan oyundasın",Vector2(1077,225),13,h.GOLD)
		else:
			h.text("Hazırlan · Hedef giriş %d. dakika" % int(legend.selection.get("minute",75)),Vector2(1077,221),13,h.MUTE)
			h.button(SKIP_RECT,"ZAMANI İLERLET","ENTER",true,game.ui.edge_offset(1,-1))
	h.draw_set_transform(Vector2.ZERO)
