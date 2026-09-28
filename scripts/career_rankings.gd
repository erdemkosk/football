extends RefCounted
## Persistent sporting prestige. Never changes player attributes or simulated odds.
const LEAGUE_SEEDS:=[68.0,48.0,84.0,72.0,82.0,83.0,78.0,86.0,70.0,69.0]
const CUP_BONUS:={"champions":[65.0,25.0],"domestic":[30.0,10.0],"super":[12.0,4.0]}

static func members(w: Dictionary,league: int) -> Array:
	return w.clubs.keys().filter(func(id): return int(w.clubs[id].league)==league)

static func ensure(w: Dictionary) -> void:
	var fresh:=not w.has("rankings")
	if fresh: w.rankings={"version":1,"year":w.year,"clubs":{},"leagues":{},"awards":{},"recorded":{}}
	var r: Dictionary=w.rankings
	for id in w.clubs:
		if r.clubs.has(id): continue
		var c: Dictionary=w.clubs[id]
		var points: float=700+float(c.reputation)*12+(LEAGUE_SEEDS[int(c.league)]-70)*3
		r.clubs[id]={"points":points,"seed_points":points,"seed_reputation":float(c.reputation),"start_points":points,"start_rank":0,"rank":0,"matches":0,"last_change":0.0}
	for league in range(LEAGUE_SEEDS.size()):
		var key:=str(league)
		if r.leagues.has(key): continue
		var total:=0.0; var ids:=members(w,league)
		for id in ids: total+=float(r.clubs[id].points)
		r.leagues[key]={"points":LEAGUE_SEEDS[league],"seed_points":LEAGUE_SEEDS[league],"seed_strength":total/maxi(1,ids.size()),"coefficient":0.0,"start_coefficient":0.0,"start_points":LEAGUE_SEEDS[league],"start_rank":0,"rank":0,"matches":0,"last_change":0.0}
	refresh(w)
	if fresh:
		# Rebuild only recorded sporting results, without replaying income, training or prizes.
		var played: Array=w.get("fixtures",[]).duplicate(); played.append_array(w.get("cup_fixtures",[]))
		played=played.filter(func(f): return f.get("played",false))
		played.sort_custom(func(a,b): return a.day<b.day if a.day!=b.day else str(a.id)<str(b.id))
		for f in played: record(w,f,false)
		for prize in w.get("league_prizes",{}).values():
			if int(prize.year)==int(w.year): league_awards(w,int(prize.league),table_order(w,int(prize.league)))
		sync_cups(w)
	refresh(w)

static func ordered(rows: Dictionary) -> Array:
	var ids: Array=rows.keys()
	ids.sort_custom(func(a,b): return float(rows[a].points)>float(rows[b].points) if float(rows[a].points)!=float(rows[b].points) else str(a)<str(b))
	return ids

static func refresh(w: Dictionary) -> void:
	var r: Dictionary=w.rankings
	var ids:=ordered(r.clubs)
	for i in range(ids.size()):
		var row: Dictionary=r.clubs[ids[i]]; row.rank=i+1
		if row.start_rank==0: row.start_rank=row.rank
		w.clubs[ids[i]].sporting_reputation=prestige(w,ids[i])
	for key in r.leagues:
		var row: Dictionary=r.leagues[key]; var total:=0.0; var clubs:=members(w,int(key))
		for id in clubs: total+=float(r.clubs[id].points)
		# Average, not sum: a larger league cannot rise just by scheduling more games.
		row.points=clampf(float(row.seed_points)+(total/maxi(1,clubs.size())-float(row.seed_strength))*.025+float(row.coefficient),30,96)
	var leagues:=ordered(r.leagues)
	for i in range(leagues.size()):
		var row: Dictionary=r.leagues[leagues[i]]; row.rank=i+1
		if row.start_rank==0: row.start_rank=row.rank

static func prestige(w: Dictionary,id: String) -> float:
	if not w.get("rankings",{}).get("clubs",{}).has(id): return float(w.clubs[id].reputation)
	var row: Dictionary=w.rankings.clubs[id]
	return clampf(float(row.seed_reputation)+(float(row.points)-float(row.seed_points))/12.0,35,96)

static func league_effect(w: Dictionary,league: int) -> float:
	var points: float=w.get("rankings",{}).get("leagues",{}).get(str(league),{}).get("points",70.0)
	return (points-70.0)*.18

static func record(w: Dictionary,f: Dictionary,honours: bool=true) -> bool:
	if not f.get("played",false) or w.rankings.recorded.has(str(f.get("id",""))) or f.get("score",[]).size()!=2: return false
	if str(f.get("id",""))=="" or not w.rankings.clubs.has(f.home) or not w.rankings.clubs.has(f.away) or f.home==f.away: return false
	w.rankings.recorded[str(f.id)]=true
	var home: Dictionary=w.rankings.clubs[f.home]; var away: Dictionary=w.rankings.clubs[f.away]
	var competition: String=f.get("competition","")
	var neutral: bool=competition=="super" or (competition=="champions" and int(f.get("stage",0))==3) or (competition=="domestic" and int(f.get("stage",0))==5)
	var expected:=1.0/(1.0+pow(10.0,(float(away.points)-float(home.points)-(0 if neutral else 45))/400.0))
	# A shootout decides the trophy; the drawn match remains a draw for rating purposes.
	var result:=1.0 if f.score[0]>f.score[1] else 0.0 if f.score[0]<f.score[1] else .5
	var k:=40.0+int(f.get("stage",0))*4 if competition=="champions" else 26.0 if competition=="domestic" else 18.0 if competition=="super" else 28.0
	if competition=="": k*=sqrt(34.0/maxi(14,(members(w,int(w.clubs[f.home].league)).size()-1)*2))
	var margin:=1.0+.10*clampi(absi(int(f.score[0])-int(f.score[1]))-1,0,3)
	var change:=k*(result-expected)*margin
	for side in range(2):
		var row: Dictionary=home if side==0 else away; var before: float=row.points
		row.points=clampf(before+change*(1 if side==0 else -1),900,2300)
		row.last_change=row.points-before; row.matches+=1
	var leagues: Array=[int(w.clubs[f.home].league),int(w.clubs[f.away].league)]
	if competition=="champions" and leagues[0]!=leagues[1]:
		var entrants: Array=w.get("cups",{}).get("champions",{}).get("entries",[])
		for side in range(2):
			var league: int=leagues[side]; var row: Dictionary=w.rankings.leagues[str(league)]
			var representatives:=maxi(1,entrants.filter(func(id): return int(w.clubs[id].league)==league).size())
			var before: float=row.coefficient
			row.coefficient=clampf(before+2.4*(result-expected)*(1 if side==0 else -1)/representatives,float(row.start_coefficient)-6,float(row.start_coefficient)+6)
			row.last_change=float(row.coefficient)-before; row.matches+=1
	if honours: sync_cups(w)
	refresh(w)
	return true

static func award(w: Dictionary,key: String,id: String,points: float) -> void:
	if w.rankings.awards.has(key) or not w.rankings.clubs.has(id): return
	w.rankings.awards[key]=true
	var row: Dictionary=w.rankings.clubs[id]
	row.points=clampf(float(row.points)+points,900,2300)

static func sync_cups(w: Dictionary) -> void:
	for key in w.get("cups",{}):
		var cup: Dictionary=w.cups[key]; var champion: String=cup.get("champion","")
		if champion=="" or not CUP_BONUS.has(key): continue
		award(w,"%d:cup:%s:winner" % [w.year,key],champion,CUP_BONUS[key][0])
		for history in w.get("cup_history",[]):
			if history.year==w.year and history.competition==key:
				award(w,"%d:cup:%s:runner" % [w.year,key],history.runner_up,CUP_BONUS[key][1]); break

static func table_order(w: Dictionary,league: int) -> Array:
	var ids:=members(w,league)
	ids.sort_custom(func(a,b):
		var x: Dictionary=w.table[a]; var y: Dictionary=w.table[b]
		if x.pts!=y.pts: return x.pts>y.pts
		if x.gf-x.ga!=y.gf-y.ga: return x.gf-x.ga>y.gf-y.ga
		return x.gf>y.gf if x.gf!=y.gf else str(a)<str(b))
	return ids

static func league_awards(w: Dictionary,league: int,order: Array) -> void:
	for i in range(order.size()):
		var bonus: float=([35.0,18.0,10.0][i] if i<3 else -8.0 if i>=order.size()-3 else 0.0)*(.7 if league==1 else 1.0)
		award(w,"%d:league:%d:%s" % [w.year,league,order[i]],order[i],bonus)
	refresh(w)

static func rollover(w: Dictionary) -> void:
	var r: Dictionary=w.rankings
	if int(r.year)>=int(w.year): return
	# Most earned reputation survives; old success slowly loses weight.
	for row in r.clubs.values(): row.points=lerpf(float(row.points),float(row.seed_points),.04)
	for row in r.leagues.values(): row.coefficient*=.94; row.start_coefficient=row.coefficient
	r.year=w.year; r.awards.clear(); r.recorded.clear()
	refresh(w)
	for rows in [r.clubs,r.leagues]:
		for row in rows.values(): row.start_points=row.points; row.start_rank=row.rank; row.matches=0; row.last_change=0.0

static func valid(w: Dictionary) -> bool:
	if not w.has("rankings"): return true
	var r=w.rankings
	if not r is Dictionary or r.get("version",0)!=1: return false
	if not r.get("year",0) is int or not r.get("clubs",0) is Dictionary or not r.get("leagues",0) is Dictionary or not r.get("awards",0) is Dictionary or not r.get("recorded",0) is Dictionary: return false
	for section in ["clubs","leagues"]:
		for id in r[section]:
			if section=="clubs" and not w.clubs.has(id): return false
			if section=="leagues" and (not str(id).is_valid_int() or int(id)<0 or int(id)>=LEAGUE_SEEDS.size()): return false
			var row=r[section][id]
			if not row is Dictionary: return false
			var keys: Array=["points","seed_points","start_points","start_rank","rank","matches","last_change"]
			keys.append_array(["seed_reputation"] if section=="clubs" else ["seed_strength","coefficient","start_coefficient"])
			for key in keys:
				if not (row.get(key) is float or row.get(key) is int) or not is_finite(float(row[key])): return false
			if row.matches<0 or row.rank<0 or row.start_rank<0 or row.points<0 or row.points>2500: return false
	return true
