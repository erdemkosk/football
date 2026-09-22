extends SceneTree
const Career=preload("res://scripts/career.gd")
const World=preload("res://scripts/career_world.gd")
var c
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func run() -> void:
	c=Career.new(); c.save_root="/tmp/sefc-turkey-check"; DirAccess.make_dir_recursive_absolute(c.save_root)
	check(c.new_career("tr00",1) and c.valid(c.world),"A Turkish-league club starts a valid, saveable career")
	check(c.world.clubs.size()==110 and c.world.players.size()==2640,"The Turkish league adds 18 full squads without replacing an existing club")
	var ids: Array=c.world.clubs.keys().filter(func(id): return c.world.clubs[id].league==World.Turkey.LEAGUE)
	check(ids.size()==18 and World.LEAGUES[9]=="Türkiye Süper Ligi","Turkey is a distinct eighteen-club league")
	var names: Array=[]; var shorts: Array=[]; var kits: Array=[]
	var sefc_names: Array=c.world.clubs.values().filter(func(club): return club.league<2).map(func(club): return club.name)
	var squad_ok:=true; var identity_ok:=true; var starter_ok:=true; var schedule_ok:=true
	for id in ids:
		var club: Dictionary=c.world.clubs[id]
		names.append(club.name); shorts.append(club.short); kits.append(club.primary+club.accent)
		var foreign:=0; var countries: Dictionary={}; var lineup_foreign:=0
		for pid in club.roster:
			var p: Dictionary=c.player(pid)
			foreign+=int(p.nationality!="TR"); countries[p.nationality]=true
			identity_ok=identity_ok and p.club==id and p.career_id==pid and p.wage>0 and World.International.NATIONS.has(p.nationality)
			if pid in club.lineup: lineup_foreign+=int(p.nationality!="TR")
		squad_ok=squad_ok and club.roster.size()==24 and foreign>=10 and foreign<=14 and countries.size()>=5
		starter_ok=starter_ok and lineup_foreign>=3 and lineup_foreign<=8 and c.player(club.lineup[0]).keeper
		var fixtures: Array=c.world.fixtures.filter(func(f): return id in [f.home,f.away])
		var home:=0; var opponents: Dictionary={}; var days: Dictionary={}
		for f in fixtures:
			home+=int(f.home==id)
			var other: String=f.away if f.home==id else f.home
			opponents[other]=int(opponents.get(other,0))+1
			schedule_ok=schedule_ok and f.league==9 and not days.has(f.day) and c.world.clubs[other].league==9
			days[f.day]=true
		schedule_ok=schedule_ok and fixtures.size()==34 and home==17 and opponents.size()==17 and opponents.values().all(func(n): return n==2)
	check(squad_ok,"Every Turkish club has Turkish players and 10–14 imports from multiple countries")
	check(starter_ok,"Starting elevens mix local and foreign players, including a real goalkeeper")
	check(identity_ok,"Players have persistent IDs, salaries and supported nationalities")
	check(names.size()==18 and names.all(func(n): return names.count(n)==1 and not n in sefc_names),"Turkish club names are unique and different from the SEFC clubs")
	check(shorts.all(func(n): return shorts.count(n)==1) and kits.all(func(n): return kits.count(n)==1),"New clubs have distinct score abbreviations and kit colours")
	check(schedule_ok,"Each Turkish club plays 34 matches, 17 at home, without duplicate dates or SEFC opponents")
	var january: Array=c.world.fixtures.filter(func(f): return f.league==9 and f.round==17)
	check(january.size()==9 and january.all(func(f): return f.day==World.day(2027,1,9)),"Turkey resumes its second half in January rather than using the shorter overseas calendar")
	check(c.world.fixtures.size()==1310,"Every league retains a complete independent calendar")
	var cup: Dictionary=c.world.cups.champions
	var qualified:=true
	for league in range(World.LEAGUES.size()):
		qualified=qualified and cup.entries.filter(func(id): return c.world.clubs[id].league==league).size()==World.CHAMPIONS_PLACES[league]
	check(qualified and cup.entries.size()==16 and cup.entries.has("tr00"),"The sixteen-team Champions Cup includes a Turkish qualifier and all other top divisions")
	check(c.world.cups.domestic.entries.size()==36 and c.world.cups.domestic.entries.all(func(id): return c.world.clubs[id].league<2),"The original SEFC domestic cup keeps its own two divisions")
	var p: String=c.club().roster.filter(func(pid): return c.player(pid).nationality!="TR" and c.sale_allowed(pid))[0]
	var nationality: String=c.player(p).nationality; var appearance: int=c.player(p).appearance_id
	check(c.transfer(p,"c00",100000,10000,3,1,"") and c.player(p).nationality==nationality and c.player(p).appearance_id==appearance,"Cross-league transfers preserve the foreign player's nationality and appearance")
	check(c.save() and c.load_slot(1) and c.world.user=="tr00" and c.player(p).club=="c00","Turkish careers and cross-league moves survive save and reload")
	# Reconstruct an actual version-4 world, including its original French cup slot.
	c.new_career("c00",1)
	c.transfer(c.world.clubs.c01.roster[4],"c00",250000,7000,3,1,"")
	var old: Dictionary=c.world.duplicate(true); old.version=4
	for id in ids:
		for pid in old.clubs[id].roster: old.players.erase(pid)
		old.clubs.erase(id); old.table.erase(id)
	old.fixtures=old.fixtures.filter(func(f): return f.league!=9)
	old.cups.champions.entries[old.cups.champions.entries.find("tr00")]="c45"
	for group in old.cups.champions.groups:
		if "tr00" in group: group[group.find("tr00")]="c45"
	old.cups.champions.table.c45=old.cups.champions.table.tr00
	old.cups.champions.table.erase("tr00")
	for f in old.cup_fixtures:
		if f.home=="tr00": f.home="c45"
		if f.away=="tr00": f.away="c45"
	old.next_player=2640
	var academy: Dictionary=World.academy_player(old,old.clubs.c00,2)
	c.director.player_fields(academy); old.players[academy.id]=academy; old.clubs.c00.roster.append(academy.id)
	old.date=World.day(2027,1,1); old.fixtures[0].played=true; old.fixtures[0].score=[3,1]
	var retained_club: Dictionary=old.clubs.c00.duplicate(true)
	var retained_players: Dictionary=old.players.duplicate(true)
	var retained_cups: Dictionary=old.cups.duplicate(true)
	var retained_fixtures: Array=old.fixtures.duplicate(true)
	var file:=FileAccess.open(c.path_for(2),FileAccess.WRITE); file.store_var(old); file.close()
	check(c.valid(old) and c.load_slot(2) and c.world.version==World.VERSION,"A real 92-club version-4 save migrates to the new league")
	check(c.world.clubs.c00==retained_club and retained_players.keys().all(func(pid): return c.player(pid)==retained_players[pid]),"Migration preserves existing rosters, player identities, academy prospects, contracts and finances")
	check(c.world.cups==retained_cups and c.world.fixtures.filter(func(f): return f.league!=9)==retained_fixtures,"Migration keeps played results, original fixture IDs and the current cup draw")
	check(c.world.clubs.size()==110 and c.world.fixtures.size()==1310 and c.valid(c.world),"Migrated clubs receive a table, calendar and all career fields")
	var migrated: Dictionary=c.world.duplicate(true)
	check(c.save() and c.load_slot(2) and c.world==migrated,"Repeated save/load never duplicates Turkish clubs, fixtures or players")
	# A completed old season must not leave the new calendar blocked behind the next-season button.
	old.season_done=true; old.date=World.day(2027,5,30)
	file=FileAccess.open(c.path_for(3),FileAccess.WRITE); file.store_var(old); file.close()
	check(c.load_slot(3) and not c.world.season_done,"Adding the new calendar releases the season-complete gate so its games can be simulated")
	# The next cup must use actual Turkish league results, not the initial reputation seed.
	c.new_career("tr04",1)
	var safety:=0
	while not c.cups.done() and safety<1600:
		var remaining: Array=c.cups.all_fixtures().filter(func(f): return not f.played)
		if remaining.is_empty(): break
		var match_data: Dictionary=remaining[0]; c.world.date=match_data.day
		c.apply_result(match_data,[2,0] if match_data.home=="tr17" else ([0,2] if match_data.away=="tr17" else [0,0]))
		safety+=1
	check(c.cups.done() and c.standings(9)[0]=="tr17","A lower-rated Turkish club can win the complete independent season")
	check(c.next_season() and c.world.cups.champions.entries.has("tr17") and not c.world.cups.champions.entries.has("tr00"),"Next season qualifies the actual Turkish champion rather than its strongest initial club")
	check(c.world.cups.champions.entries.size()==16 and c.world.fixtures.filter(func(f): return f.league==9).size()==306,"Rollover retains the balanced Champions Cup and all Turkish league fixtures")
	check(c.world.news[0].body.contains("Türkiye Süper Ligi") and c.world.news[0].body.contains(c.world.clubs.tr17.name),"Season news reports the user's Turkish league champion, separately from SEFC")
	print("TURKISH LEAGUE CHECK: %d checks, %d failures" % [checks,failures])
	c=null; quit(1 if failures else 0)
