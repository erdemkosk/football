extends RefCounted
const Catalog=preload("res://scripts/training_catalog.gd")
const World=preload("res://scripts/career_world.gd")
const INTERVAL:=7
const SLOTS:=5
var ref: WeakRef
var career:
	get: return ref.get_ref()
	set(value): ref=weakref(value)
var active: Dictionary={}

static func valid(w: Dictionary) -> bool:
	if not w.has("training"): return true
	if not w.training is Dictionary: return false
	for club_id in w.training:
		var d=w.training[club_id]
		if not w.clubs.has(club_id) or not d is Dictionary: return false
		for key in ["week","automatic","slots","history","best","last"]:
			if not d.has(key): return false
		if not d.week is int or not d.automatic is bool or not d.slots is Array or not d.history is Array or not d.best is Dictionary or not d.last is Dictionary: return false
		if d.slots.size()!=SLOTS: return false
		var seen: Dictionary={}
		for row in d.slots:
			if not row is Dictionary: return false
			for key in ["player","drill","done","score","xp","manual"]:
				if not row.has(key): return false
			if not row.player is String or not row.drill in Catalog.SCORED or not row.done is bool or not row.manual is bool or not row.score is int: return false
			if row.score<0 or row.score>100 or not (row.xp is float or row.xp is int): return false
			if row.player!="":
				# Released academy players can disappear; their old row simply
				# becomes unavailable until it is replaced or the week rolls over.
				if seen.has(row.player): return false
				seen[row.player]=true
	return true

func ensure(w: Dictionary) -> void:
	if not w.get("training",{}) is Dictionary: w.training={}
	if not w.has("training"): w.training={}
	if not w.training.has(w.user):
		w.training[w.user]={"week":int(w.date),"automatic":true,"slots":[],"history":[],"best":{},"last":{}}
		fill(w)

func data() -> Dictionary:
	ensure(career.world)
	return career.world.training[career.world.user]

func eligible(w: Dictionary,pid: String) -> bool:
	if not w.players.has(pid): return false
	var p: Dictionary=w.players[pid]
	return not p.get("retired",false) and (p.club==w.user or p.get("academy_owner","")==w.user) and int(p.injury)<=int(w.date) and p.age<30 and World.ovr(p)<int(p.potential)

func candidates(w: Dictionary) -> Array:
	var ids: Array=w.clubs[w.user].roster.duplicate()
	ids.append_array(w.get("academy",{}).get(w.user,[]))
	ids=ids.filter(func(pid): return eligible(w,pid))
	var last: Dictionary=w.training[w.user].last
	ids.sort_custom(func(a,b):
		if int(last.get(a,-1))!=int(last.get(b,-1)): return int(last.get(a,-1))<int(last.get(b,-1))
		var pa: Dictionary=w.players[a]; var pb: Dictionary=w.players[b]
		var ga: int=pa.potential-World.ovr(pa); var gb: int=pb.potential-World.ovr(pb)
		return ga>gb if ga!=gb else (pa.age<pb.age if pa.age!=pb.age else a<b))
	return ids

func fill(w: Dictionary) -> void:
	var d: Dictionary=w.training[w.user]
	var occupied: Array=[]
	for row in d.slots:
		if row.done: occupied.append(row.player)
	var ids:=candidates(w).filter(func(pid): return not pid in occupied)
	for i in range(SLOTS):
		if i<d.slots.size() and d.slots[i].done: continue
		var pid: String=ids.pop_front() if not ids.is_empty() else ""
		var row:={"player":pid,"drill":Catalog.suggested(w.players[pid],d.week) if pid!="" else "passing","done":false,"score":0,"xp":0.0,"manual":false}
		if i<d.slots.size(): d.slots[i]=row
		else: d.slots.append(row)

func ready(index: int) -> bool:
	if not career.exists() or career.in_match or not career.world.manager.employed: return false
	var d:=data()
	return index>=0 and index<d.slots.size() and not d.slots[index].done and eligible(career.world,d.slots[index].player)

func assign(index: int,pid: String,mode: String) -> bool:
	if not active.is_empty() or not eligible(career.world,pid): return false
	var d:=data()
	if index<0 or index>=d.slots.size() or d.slots[index].done or not mode in Catalog.options(career.player(pid)): return false
	for i in range(d.slots.size()):
		if i!=index and d.slots[i].player==pid: return false
	d.slots[index].player=pid; d.slots[index].drill=mode
	career.save(); return true

func refill() -> void:
	if not active.is_empty(): return
	data(); fill(career.world); career.save()

func simulated_score(index: int) -> int:
	var d:=data(); var row: Dictionary=d.slots[index]
	var p: Dictionary=career.player(row.player)
	var skill:=0.0
	for key in Catalog.SKILLS[row.drill]: skill+=float(p.attributes.get(key,60))
	var baseline:=clampi(roundi(38+skill/3*.30),45,65)
	return maxi(baseline,int(d.best.get(row.player+":"+row.drill,0)))

func award(index: int,score: int,manual: bool) -> Dictionary:
	if not ready(index): return {}
	var d:=data(); var row: Dictionary=d.slots[index]
	var p: Dictionary=career.player(row.player)
	score=clampi(score,0,100)
	var requested: float=(3+score*.13)*[.65,1.0,1.15][int(p.development.intensity)] if score>0 else 0.0
	var before: float=float(p.development.xp)+int(p.development.gains)*100
	career.director.gain(p,requested,Catalog.SKILLS[row.drill])
	var gained: float=maxf(0,float(p.development.xp)+int(p.development.gains)*100-before)
	row.merge({"done":true,"score":score,"xp":gained,"manual":manual},true)
	d.last[row.player]=int(career.world.date)
	if manual:
		var key: String=row.player+":"+row.drill
		d.best[key]=maxi(int(d.best.get(key,0)),score)
	var result: Dictionary=row.duplicate(true)
	result.name=p.name; result.day=int(career.world.date); result.grade=Catalog.grade(score)
	d.history.push_front(result)
	if d.history.size()>30: d.history.resize(30)
	return result

func simulate(index: int=-1) -> void:
	if not active.is_empty(): return
	var d:=data()
	for i in range(d.slots.size()):
		if (index<0 or index==i) and ready(i): award(i,simulated_score(i),false)
	career.save()

func daily() -> void:
	var c=career; var d:=data()
	if not c.world.manager.employed: return
	# The coach completes a week's pending list on the next calendar day.
	# Opening or closing a menu never awards points or advances the schedule.
	if d.automatic and c.world.date>d.week:
		for i in range(d.slots.size()):
			if ready(i): award(i,simulated_score(i),false)
	if c.world.date>=d.week+INTERVAL:
		d.week=int(c.world.date); d.slots=[]; fill(c.world)

func start(index: int) -> bool:
	if not active.is_empty() or not ready(index): return false
	var c=career; var d:=data(); var row: Dictionary=d.slots[index]
	active={"slot":index,"player":row.player,"drill":row.drill,"club":c.world.user,"week":d.week,"save":c.slot}
	var g=c.game; var screen=g.career_screen
	screen.visible=false; screen.clear_controls(); g.camera.cull_mask=screen.world_mask
	g.audio.set_process(true)
	g.start_match(true,false,false,row.drill)
	g.players[9].apply_identity(c.player(row.player).duplicate(true))
	g.players[9].apply_kit(World.kit(c.club()))
	return true

func finish(score: int) -> Dictionary:
	if active.is_empty(): return {}
	var result: Dictionary={}
	var c=career
	if c.slot==active.save and c.world.user==active.club and data().week==active.week and data().slots[active.slot].player==active.player and data().slots[active.slot].drill==active.drill:
		result=award(active.slot,score,true)
		if not result.is_empty(): result.saved=c.save()
	active={}
	return result

func leave() -> void:
	active={}
	var g=career.game
	g.clubs.apply(); g.training=false; g.player_lock=false
	g.training_drills.challenges.clear()
	g.career_screen.open_hub(); g.career_screen.go("training")
