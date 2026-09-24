extends RefCounted
const World=preload("res://scripts/career_world.gd")
const TITLES:={"domestic":"SEFC LİG KUPASI","champions":"SEFC ŞAMPİYONLAR KUPASI","super":"SEFC SÜPER KUPA"}
const CHAMPION_PRIZES:={"domestic":1800000,"champions":25000000,"super":650000}
const ROUNDS:=["ÖN ELEME","SON 32","SON 16","ÇEYREK FİNAL","YARI FİNAL","FİNAL"]
var career_ref: WeakRef
var career:
	get: return career_ref.get_ref() if career_ref!=null else null
	set(value): career_ref=weakref(value)
var extra_phase:=0

static func ensure(w: Dictionary) -> void:
	if w.has("cups"): return
	w.cup_history=[]; w.cup_fixtures=[]; w.cups={}
	# Old saves retain every league result. Cups join at the next full season.
	if w.date>World.day(w.year,8,1):
		w.cups_pending=true
		return
	start(w)

static func start(w: Dictionary,qualified: Array=[],super_pair: Array=[],overseas: Array=[]) -> void:
	w.cups_pending=false; w.cup_fixtures=[]; w.cups={}
	if not w.has("cup_history"): w.cup_history=[]
	var domestic: Array=[]; var foreign: Array=[]
	for id in w.clubs:
		if w.clubs[id].league<2: domestic.append(id)
		else: foreign.append(id)
	domestic.sort_custom(func(a,b): return w.clubs[a].reputation>w.clubs[b].reputation if w.clubs[a].reputation!=w.clubs[b].reputation else a<b)
	if qualified.is_empty(): qualified=domestic.filter(func(id): return w.clubs[id].league==0).slice(0,4)
	if overseas.is_empty():
		foreign.sort_custom(func(a,b): return w.clubs[a].reputation>w.clubs[b].reputation if w.clubs[a].reputation!=w.clubs[b].reputation else a<b)
		for league in range(2,World.LEAGUES.size()): overseas.append_array(foreign.filter(func(id): return w.clubs[id].league==league).slice(0,World.CHAMPIONS_PLACES[league]))
	var entries: Array=qualified.duplicate(); entries.append_array(overseas)
	w.cups.domestic={"title":TITLES.domestic,"entries":domestic,"stage":0,"champion":"","byes":domestic.slice(0,28),"groups":[],"table":{},"scorers":{}}
	w.cups.champions={"title":TITLES.champions,"entries":entries,"stage":0,"champion":"","groups":[],"table":{},"scorers":{}}
	if super_pair.size()!=2 or super_pair[0]==super_pair[1]: super_pair=qualified.slice(0,2)
	w.cups.super={"title":TITLES.super,"entries":super_pair,"stage":0,"champion":"","groups":[],"table":{},"scorers":{}}
	add_round(w,"domestic",domestic.slice(28),0,domestic_day(w,0))
	add_round(w,"super",super_pair,0,World.day(w.year,8,8)-7)
	# Four groups: one domestic qualifier and three international clubs each.
	for g in range(4):
		var group: Array=[entries[g],entries[4+g],entries[8+g],entries[12+g]]
		w.cups.champions.groups.append(group)
		for id in group: w.cups.champions.table[id]={"p":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"pts":0}
		var pairings: Array=[[[0,3],[1,2]],[[0,2],[3,1]],[[0,1],[2,3]]]
		for round_index in range(6):
			for pair in pairings[round_index%3]:
				var home: String=group[pair[0] if round_index<3 else pair[1]]
				var away: String=group[pair[1] if round_index<3 else pair[0]]
				var f:=fixture(w,"champions",home,away,0,World.day(w.year,8,8)+[32,46,67,81,102,116][round_index])
				f.group=g; f.round=round_index; f.knockout=false

static func domestic_day(w: Dictionary,stage: int) -> int:
	if stage<3: return World.day(w.year,8,8)+[25,60,88][stage]
	return World.day(w.year+1,1,9)+[11,67,123][stage-3]

static func fixture(w: Dictionary,key: String,home: String,away: String,stage: int,date: int) -> Dictionary:
	var f:={"id":"%d-%s-%d" % [w.year,key,w.cup_fixtures.size()],"competition":key,"league":-1,"round":stage,"stage":stage,"day":date,"home":home,"away":away,"played":false,"score":[],"knockout":true,"winner":"","penalties":[],"extra_time":false,"group":-1,"leg":1,"tie":""}
	w.cup_fixtures.append(f)
	return f

static func add_round(w: Dictionary,key: String,entries: Array,stage: int,date: int,return_date: int=0) -> void:
	for n in range(0,entries.size(),2):
		var f:=fixture(w,key,entries[n],entries[n+1],stage,date)
		if return_date>0:
			f.tie=f.id; f.leg=1; f.deciding=false
			var second:=fixture(w,key,entries[n+1],entries[n],stage,return_date)
			second.tie=f.id; second.leg=2; second.deciding=true

func all_fixtures() -> Array:
	var fixtures: Array=career.world.fixtures.duplicate()
	fixtures.append_array(career.world.cup_fixtures)
	fixtures.sort_custom(func(a,b): return a.day<b.day if a.day!=b.day else a.id<b.id)
	return fixtures

func done() -> bool:
	return career.world.fixtures.all(func(f): return f.played) and career.world.cups.values().all(func(c): return c.champion!="")

func group_order(ids: Array) -> Array:
	var order: Array=ids.duplicate(); var table: Dictionary=career.world.cups.champions.table
	order.sort_custom(func(a,b):
		var x: Dictionary=table[a]; var y: Dictionary=table[b]
		if x.pts!=y.pts: return x.pts>y.pts
		if x.gf-x.ga!=y.gf-y.ga: return x.gf-x.ga>y.gf-y.ga
		return x.gf>y.gf if x.gf!=y.gf else a<b)
	return order

func total_score(f: Dictionary,result: Array) -> Array:
	var aggregate: Array=result.duplicate()
	if f.get("leg",1)==2:
		for first in career.world.cup_fixtures:
			if first.id==f.tie and first.played:
				aggregate[0]+=first.score[1]; aggregate[1]+=first.score[0]; break
	return aggregate

func needs_winner(f: Dictionary) -> bool:
	return f.get("knockout",false) and f.get("deciding",true)

func penalties(f: Dictionary) -> Array:
	# Stored shootout is separate from match goals, aggregate and the scorer charts.
	var rng:=RandomNumberGenerator.new(); rng.seed=hash(f.id+str(f.score))
	var goals: Array=[0,0]; var attempts: Array=[0,0]
	var chance: Array=[]
	for id in [f.home,f.away]:
		var eleven: Array=career.selection(id); var total:=0.0
		for pid in eleven: total+=career.player(pid).attributes.finishing
		chance.append(clampf(.68+(total/maxi(1,eleven.size())-65)*.003,.58,.87))
	for n in range(40):
		for side in range(2):
			attempts[side]+=1
			if rng.randf()<chance[side]: goals[side]+=1
			if n<5 and (goals[0]>goals[1]+maxi(0,5-attempts[1]) or goals[1]>goals[0]+maxi(0,5-attempts[0])): return goals
		if n>=4 and goals[0]!=goals[1]: return goals
	goals[rng.randi_range(0,1)]+=1
	return goals

func record(f: Dictionary) -> void:
	if not f.has("competition"): return
	var key: String=f.competition; var cup: Dictionary=career.world.cups[key]
	if cup.champion!="": return
	if f.knockout:
		var aggregate:=total_score(f,f.score)
		if needs_winner(f):
			if aggregate[0]==aggregate[1]:
				if not f.get("live_penalties",false): f.penalties=penalties(f)
				f.winner=f.home if f.penalties[0]>f.penalties[1] else f.away
			else: f.winner=f.home if aggregate[0]>aggregate[1] else f.away
			f.aggregate=aggregate
	else:
		for side in range(2):
			var row: Dictionary=cup.table[f.home if side==0 else f.away]
			var gf: int=f.score[side]; var ga: int=f.score[1-side]
			row.p+=1; row.gf+=gf; row.ga+=ga
			if gf>ga: row.w+=1; row.pts+=3
			elif gf==ga: row.d+=1; row.pts+=1
			else: row.l+=1
	var round_games: Array=career.world.cup_fixtures.filter(func(item): return item.competition==key and item.stage==cup.stage)
	if not round_games.all(func(item): return item.played): return
	var winners: Array=[]
	for item in round_games:
		if item.winner!="": winners.append(item.winner)
	if key=="champions" and cup.stage==0:
		var orders: Array=[]
		for group in cup.groups: orders.append(group_order(group))
		winners=[orders[0][0],orders[1][1],orders[1][0],orders[0][1],orders[2][0],orders[3][1],orders[3][0],orders[2][1]]
	if key=="domestic" and cup.stage==0:
		winners.append_array(cup.byes)
		# A repeatable open draw; no dependency on unrelated gameplay randomness.
		var random:=RandomNumberGenerator.new(); random.seed=career.world.year*31+7
		for i in range(winners.size()-1,0,-1):
			var j:=random.randi_range(0,i); var saved=winners[i]; winners[i]=winners[j]; winners[j]=saved
	if winners.size()==1:
		cup.champion=winners[0]
		var prize: int=CHAMPION_PRIZES[key]
		career.transaction(cup.champion,prize,cup.title+" şampiyonluk ödülü")
		career.world.clubs[cup.champion].budget+=prize
		career.world.cup_history.append({"year":career.world.year,"competition":key,"champion":cup.champion,"runner_up":f.away if cup.champion==f.home else f.home,"prize":prize})
		career.news("KUPA ŞAMPİYONU",career.world.clubs[cup.champion].name+", "+cup.title+" kupasını kaldırdı. Kasaya ve transfer bütçesine "+career.money(prize)+" eklendi.","cup")
		return
	cup.stage+=1
	if key=="domestic": add_round(career.world,key,winners,cup.stage,domestic_day(career.world,cup.stage))
	elif key=="champions":
		var base:=World.day(career.world.year+1,1,9)
		if cup.stage==1: add_round(career.world,key,winners,1,base+39,base+53)
		elif cup.stage==2: add_round(career.world,key,winners,2,base+81,base+95)
		else: add_round(career.world,key,winners,3,base+116)
	career.news("KUPADA YENİ TUR",cup.title+": yeni eşleşmeler belli oldu. Kupa ekranından takip edebilirsin.","cup")

func championship_prize(key: String) -> int:
	# Old trophy archives keep the amount that was actually paid at the time.
	for entry in career.world.cup_history:
		if entry.year==career.world.year and entry.competition==key: return int(entry.prize)
	return CHAMPION_PRIZES.get(key,0)

func fixture_label(f: Dictionary) -> String:
	if not f.has("competition"): return World.LEAGUES[int(f.league)]+" · %d. HAFTA" % (f.round+1)
	var stage: String="FİNAL"
	if f.competition=="domestic": stage=ROUNDS[int(f.stage)]
	elif f.competition=="champions": stage=["GRUP "+str(char(65+int(f.group))),"ÇEYREK FİNAL","YARI FİNAL","FİNAL"][int(f.stage)]
	if f.get("tie","")!="": stage+=" · %d. MAÇ" % f.leg
	return TITLES[f.competition]+" · "+stage

func live_fixture() -> Dictionary:
	if not career.in_match: return {}
	for f in career.world.cup_fixtures:
		if f.id==career.fixture_id: return f
	return {}

func extra_active() -> bool: return career.in_match and extra_phase>0

func period_end() -> bool:
	var f:=live_fixture()
	if f.is_empty() or not needs_winner(f): return false
	var result: Array=career.game.score.duplicate() if f.home==career.world.user else [career.game.score[1],career.game.score[0]]
	var total:=total_score(f,result)
	if extra_phase==0 and total[0]!=total[1]: return false
	if extra_phase>=2:
		if total[0]==total[1]: career.game.finale.begin_shootout(f); return true
		return false
	extra_phase+=1; f.extra_time=true
	var game=career.game
	game.match_time=game.LENGTH*(1.0 if extra_phase==1 else 7.0/6.0)
	game.half=extra_phase; game.management.apply_formation()
	game.stadium.crowd.home_attack=game.attack_sign(0)
	game.charging=false; game.cancel_pass(); game.replay.frames.clear(); game.rules.reset()
	game.begin_restart("SANTRA",extra_phase-1,Vector3.ZERO)
	game.referees.whistle()
	return true
