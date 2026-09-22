extends SceneTree
const Career=preload("res://scripts/career.gd")
const World=preload("res://scripts/career_world.gd")
var c
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func fresh(id: String="c00") -> void:
	c=Career.new(); c.save_root="/tmp/sefc-career-cups"; DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career(id,1)
func complete_season(winner: String="c00") -> void:
	var safety:=0
	while not c.cups.done() and safety<1500:
		var fixtures: Array=c.cups.all_fixtures().filter(func(f): return not f.played)
		if fixtures.is_empty(): break
		var f: Dictionary=fixtures[0]; c.world.date=f.day
		var score: Array=[2,0] if f.home==winner else ([0,2] if f.away==winner else [safety%3,safety%2])
		c.apply_result(f,score); safety+=1
	check(safety<1500 and c.cups.done(),"All competitions finish without an empty-fixture deadlock")

func run() -> void:
	fresh()
	check(c.world.clubs.size()==110 and c.world.players.size()==2640,"The career contains 36 SEFC, 18 Turkish and 56 overseas clubs")
	var foreign: Array=c.world.clubs.values().filter(func(club): return club.nation!="TR")
	check(foreign.size()==56 and foreign.all(func(club): return club.nation!="TR" and club.roster.size()==24),"International clubs have their own country and full playable squads")
	var nations: Dictionary={}
	for p in c.world.players.values(): nations[p.nationality]=true
	check(nations.size()>=10 and c.world.players.values().all(func(p): return World.International.NATIONS.has(p.nationality)),"Persistent players have valid and diverse nationalities")
	check(c.world.clubs.c36.name!="" and c.player(c.world.clubs.c36.roster[0]).name!="","International club and player identities are populated")
	check(c.world.fixtures.size()==1310 and c.world.table.size()==110,"Ten league tables and complete fixtures coexist with the independent cups")
	check(c.world.cups.domestic.entries.size()==36 and c.world.cups.champions.entries.size()==16 and c.world.cups.super.entries.size()==2,"The three cups have the correct participant counts")
	check(c.world.cups.champions.entries.filter(func(id): return c.world.clubs[id].league==0).size()==4,"Four domestic qualifiers face twelve international clubs")
	var groups: Array=c.world.cup_fixtures.filter(func(f): return f.competition=="champions" and not f.knockout)
	check(groups.size()==48,"The champions group stage contains 48 home-and-away games")
	var balanced:=true
	for id in c.world.cups.champions.entries:
		var matches: Array=groups.filter(func(f): return id in [f.home,f.away])
		var opponents: Dictionary={}; var home:=0
		for f in matches:
			var opponent: String=f.away if f.home==id else f.home
			opponents[opponent]=int(opponents.get(opponent,0))+1; home+=int(f.home==id)
		balanced=balanced and matches.size()==6 and home==3 and opponents.size()==3 and opponents.values().all(func(count): return count==2)
	check(balanced,"Each group team meets three opponents twice, with three home games")
	var table: Dictionary=c.world.table.duplicate(true); var scorers: Dictionary=c.world.scorers.duplicate(true)
	var preliminary: Dictionary=c.world.cup_fixtures[0]; c.world.date=preliminary.day
	check(c.apply_result(preliminary,[3,2]),"A domestic preliminary match can be recorded")
	check(c.world.table==table and c.world.scorers==scorers,"Cup goals and wins never leak into league points or the league scoring chart")
	check(c.world.cups.domestic.scorers.size()>0,"Cup scorers have their own competition chart")
	for f in c.world.cup_fixtures.duplicate():
		if f.competition=="domestic" and not f.played: c.apply_result(f,[1,0])
	check(c.world.cups.domestic.stage==1 and c.world.cup_fixtures.filter(func(f): return f.competition=="domestic" and f.stage==1).size()==16,"Four preliminary winners and 28 byes form a complete round of 32")
	var entrants: Array=[]
	for f in c.world.cup_fixtures:
		if f.competition=="domestic" and f.stage==1: entrants.append(f.home); entrants.append(f.away)
	var unique: Dictionary={}
	for id in entrants: unique[id]=true
	check(unique.size()==32,"The knockout draw has no duplicate participants")
	# A shootout winner is separate from regulation goals and cannot pay twice.
	var final: Dictionary=c.world.cup_fixtures.filter(func(f): return f.competition=="super")[0]
	c.world.date=final.day; c.apply_result(final,[0,0])
	check(final.score==[0,0] and final.penalties.size()==2 and final.penalties[0]!=final.penalties[1] and final.winner!="","A drawn final produces a decisive shootout without inventing match goals")
	check(c.world.cups.super.scorers.is_empty(),"Penalty-shootout goals do not credit any goal scorer")
	check(c.world.cups.super.champion==final.winner and c.world.cup_history.size()==1,"The trophy is recorded for the actual shootout winner")
	var cash: int=c.world.clubs[final.winner].cash; var ledger: int=c.world.ledger.size()
	check(not c.apply_result(final,[9,0]) and c.world.clubs[final.winner].cash==cash and c.world.ledger.size()==ledger,"A cup result and trophy prize cannot be awarded twice")
	check(c.world.ledger.any(func(item): return item.club==final.winner and item.amount==650000),"The Super Cup reward is a real club transaction")
	for f in groups: c.world.date=f.day; c.apply_result(f,[1,1])
	check(c.world.cups.champions.stage==1 and c.world.cups.champions.table.values().all(func(row): return row.p==6 and row.pts==6),"Drawn groups complete with deterministic tied standings")
	var quarter: Array=c.world.cup_fixtures.filter(func(f): return f.competition=="champions" and f.stage==1)
	check(quarter.size()==8 and quarter.filter(func(f): return f.leg==2).size()==4,"The quarter-finals contain four two-leg ties")
	var first: Dictionary=quarter[0]; var second: Dictionary=quarter[1]
	check(first.home==second.away and first.away==second.home and first.id==second.tie,"The return fixture reverses venue and references the same tie")
	c.world.date=first.day; c.apply_result(first,[2,0])
	check(first.winner=="" and first.penalties.is_empty(),"The first leg does not decide advancement or trigger penalties")
	c.world.date=second.day; c.apply_result(second,[1,0])
	check(second.winner==first.home and second.aggregate==[1,2],"Aggregate score advances the right club even when it loses the return leg")
	first=quarter[2]; second=quarter[3]
	c.world.date=first.day; c.apply_result(first,[1,0]); c.world.date=second.day; c.apply_result(second,[1,0])
	check(second.aggregate==[1,1] and not second.penalties.is_empty(),"A tied aggregate uses penalties independently of the return-leg score")
	check(c.valid(c.world) and c.save() and c.load_slot(1),"Groups, ties, trophies and foreign identities save and load")
	check(c.world.cup_fixtures.any(func(f): return not f.penalties.is_empty()),"Shootout outcomes survive reload")
	# A real season includes all finals; qualification uses the completed table.
	fresh(); complete_season()
	check(c.world.cup_fixtures.size()==97,"A full season has 35 domestic, 61 champions and one Super Cup fixture")
	check(c.world.cups.values().all(func(cup): return cup.champion!="") and c.world.cup_history.size()==3,"All three competitions award exactly one trophy")
	check(c.world.cups.champions.champion=="c00" and c.world.cups.domestic.champion=="c00","The winning user club can complete a domestic and international cup double")
	check(c.world.table.keys().all(func(id): return c.world.table[id].p==(34 if World.full_calendar(c.world.clubs[id].league) else 14)),"Every domestic club still plays exactly 34 league games")
	var occupied: Dictionary={}; var clash:=false; var tight:=false
	for f in c.cups.all_fixtures():
		for id in [f.home,f.away]:
			if not occupied.has(id): occupied[id]=[]
			if f.day in occupied[id]: clash=true
			for date in occupied[id]:
				if absi(date-f.day)<3: tight=true
			occupied[id].append(f.day)
	check(not clash and not tight,"League and cup fixtures have no double bookings and allow at least three days between games")
	var qualified: Array=c.standings(0).slice(0,4); var promoted: Array=c.standings(1).slice(0,3); var relegated: Array=c.standings(0).slice(15)
	var runner_up: String=c.standings(0)[1]
	check(c.next_season(),"A season with completed cups can roll over")
	check(c.world.cups.champions.entries.slice(0,4)==qualified,"Next season's Champions Cup uses actual top-four league finishers")
	check(c.world.cups.super.entries==["c00",runner_up],"A league-and-cup double sends the league runner-up to the Super Cup")
	check(promoted.all(func(id): return c.world.clubs[id].league==0) and relegated.all(func(id): return c.world.clubs[id].league==1),"Three promotions and three relegations persist into the new fixtures")
	check(c.world.cup_history.size()==3 and c.world.cup_fixtures.all(func(f): return not f.played),"The trophy archive persists while next-season cup fixtures reset")
	check(c.valid(c.world),"The multi-season international world is internally consistent")
	# Elimination must not strand the calendar before remaining AI finals finish.
	fresh("c35")
	for f in c.world.fixtures: f.played=true
	for f in c.world.cup_fixtures.duplicate():
		if c.world.user in [f.home,f.away]: c.apply_result(f,[0,2] if f.home==c.world.user else [2,0])
	c.world.date=World.day(2027,5,1)
	check(c.next_fixture().is_empty() and not c.world.season_done,"An eliminated club can have no remaining matches before the cup finals")
	for n in range(6): c.advance_to_event()
	check(c.world.season_done and c.cups.done(),"Advancing the calendar finishes other clubs' remaining cup rounds")
	# Migration preserves old domestic identities/results and never inserts missed cup games.
	fresh()
	var old: Dictionary=c.world.duplicate(true); old.version=2; old.date=World.day(2027,1,1)
	for key in ["cups","cup_history","cup_fixtures","cups_pending"]: old.erase(key)
	for id in old.clubs.keys():
		if old.clubs[id].league<2: continue
		for pid in old.clubs[id].roster: old.players.erase(pid)
		old.clubs.erase(id)
	old.next_player=864
	old.fixtures[0].played=true; old.fixtures[0].score=[4,2]
	var previous_name: String=old.players.p0000.name
	var file:=FileAccess.open(c.path_for(2),FileAccess.WRITE); file.store_var(old); file.close()
	check(c.load_slot(2) and c.world.version==World.VERSION and c.world.clubs.size()==110,"A 36-club version-2 save migrates to international competition support")
	check(c.world.cups_pending and c.world.cup_fixtures.is_empty() and c.world.fixtures[0].score==[4,2] and c.player("p0000").name==previous_name,"Mid-season migration preserves names/results and schedules new cups from the next season")
	check(c.valid(c.world),"The migrated mid-season save remains valid")
	print("CAREER CUPS CHECK: %d checks, %d failures" % [checks,failures])
	c=null; quit(0 if failures==0 else 1)
