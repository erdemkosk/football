extends RefCounted
## Independent of optional disk recording. Identities survive substitutions and position swaps.
var game
var active:=false
var complete:=false
var rows: Dictionary={}
var events: Array[Dictionary]=[]
var last_clock:=0.0
var sample:=0.0
var page:=0
var roster_page:=0
var event_page:=0
var career_before: Dictionary={}
var consequences: Array[String]=[]
var last_shot: Dictionary={}

func key(p) -> String:
	return p.career_id if p.career_id!="" else "%d:%d:%s" % [p.team,p.shirt_number,p.display_name]

func player(p) -> Dictionary:
	var id:=key(p)
	if not rows.has(id):
		rows[id]={"id":id,"name":p.display_name,"shirt":p.shirt_number,"team":p.team,"keeper":p.keeper,"minutes":0.0,"goals":0,"own_goals":0,"shots":0,"saves":0,"tackles":0,"yellow":0,"red":false}
	return rows[id]

func begin(practice: bool,background: bool) -> void:
	active=not practice and not background; complete=false; rows.clear(); events.clear(); consequences.clear()
	page=0; roster_page=0; event_page=0; last_clock=0; sample=0; career_before={}
	last_shot.clear()
	if not active: return
	for p in game.players: player(p)
	if game.career.in_match:
		var c=game.career
		career_before={"cash":c.club().cash,"points":c.world.table[c.world.user].pts,"rank":c.standings(c.club().league).find(c.world.user)+1}

func update(delta: float) -> void:
	if not active or game.menu_match.running: return
	sample+=delta
	if sample<.25: return
	sample=0; sync()

func sync() -> void:
	if not active: return
	var minutes: float=maxf(0,game.match_time-last_clock)/game.LENGTH*90
	last_clock=game.match_time
	for p in game.players:
		var row:=player(p)
		if p.visible and not row.red: row.minutes+=minutes
		if p.yellow_cards>row.yellow:
			event("SARI KART",p.display_name,p.team); row.yellow=p.yellow_cards
		if p.dismissed and not row.red:
			event("KIRMIZI KART",p.display_name,p.team); row.red=true

func event(kind: String,label: String,team: int) -> void:
	if not active or game.menu_match.running or events.size()>=150: return
	events.append({"minute":roundi(game.match_time/game.LENGTH*90),"kind":kind,"label":label,"team":team})

func strike(index: int,kind: String,is_save: bool) -> void:
	if not active or game.menu_match.running or is_save: return
	var row:=player(game.players[index])
	if kind in ["shot","header","volley","half_volley","finish"]:
		row.shots+=1; last_shot={"id":row.id,"clock":game.match_time,"parried":false}
	else:
		last_shot.clear()
		if kind=="ball_tackle": row.tackles+=1

func saved(index: int) -> void:
	if not active or game.menu_match.running: return
	player(game.players[index]).saves+=1
	if not last_shot.is_empty(): last_shot.parried=true

func goal(team: int) -> void:
	if not active or game.menu_match.running: return
	var label: String=game.team_name(team)
	if game.last_kicker>=0:
		var p=game.players[game.last_kicker]; var row:=player(p)
		if p.keeper and p.team!=team and not last_shot.is_empty() and last_shot.parried and game.match_time-last_shot.clock<8 and rows[last_shot.id].team==team:
			row=rows[last_shot.id]
		var own: bool=row.team!=team
		row.own_goals+=int(own); row.goals+=int(not own)
		label=row.name+(" · kendi kalesine" if own else "")
	event("GOL · %d–%d" % game.score,label,team)
	last_shot.clear()

func substitution(p,incoming: Dictionary) -> void:
	if not active: return
	sync()
	event("DEĞİŞİKLİK",p.display_name+" → "+str(incoming.name),p.team)

func finish() -> void:
	if not active: return
	sync(); active=false; complete=true
	game.broadcast.finish()
	game.toast_queue.clear(); game.toast=""; game.toast_timer=0

func career_result() -> void:
	if career_before.is_empty() or not consequences.is_empty(): return
	var c=game.career
	var points: int=c.world.table[c.world.user].pts-career_before.points
	var rank: int=c.standings(c.club().league).find(c.world.user)+1
	consequences.append("LİG · %d. sıra  /  %d puan%s" % [rank,c.world.table[c.world.user].pts,"  (+%d)" % points if points>0 else ""])
	var cash: int=c.club().cash-career_before.cash
	consequences.append("KASA · "+("+" if cash>=0 else "−")+c.money(absi(cash)))
	var unavailable:=0
	for id in c.club().roster:
		var p: Dictionary=c.player(id)
		if p.banned>0 or p.injury>c.world.date: unavailable+=1
	consequences.append("SONRAKİ MAÇ · %d sakat / cezalı oyuncu" % unavailable if unavailable>0 else "SONRAKİ MAÇ · Sakat veya cezalı oyuncu yok")

func rating(row: Dictionary) -> float:
	return snappedf(clampf(6.0+row.goals*1.15+minf(1.2,row.shots*.08)+minf(2.2,row.saves*.32)+minf(1.3,row.tackles*.18)-row.yellow*.25-float(row.red)*1.1-row.own_goals*.8,3,10),.1)

func participants(team: int=-1) -> Array:
	var list:=rows.values().filter(func(r): return (team<0 or r.team==team) and (r.minutes>0 or r.goals+r.own_goals+r.shots+r.saves+r.tackles>0 or r.red or r.yellow>0))
	list.sort_custom(func(a,b):
		if not is_equal_approx(rating(a),rating(b)): return rating(a)>rating(b)
		if not is_equal_approx(a.minutes,b.minutes): return a.minutes>b.minutes
		return a.shirt<b.shirt)
	return list

func best() -> Dictionary:
	var list:=participants()
	return {} if list.is_empty() else list[0]
