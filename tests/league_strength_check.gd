extends SceneTree
const World=preload("res://scripts/career_world.gd")
const Talent=preload("res://scripts/player_talent.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func average(w: Dictionary,ids: Array) -> float:
	var total:=0.0
	for pid in ids: total+=World.ovr(w.players[pid])
	return total/maxi(1,ids.size())
func team(w: Dictionary,id: String) -> float: return average(w,w.clubs[id].lineup)
func legacy_player(w: Dictionary) -> Dictionary:
	var p: Dictionary=w.players.p0865.duplicate(true)
	for key in Talent.STATS: p.attributes[key]=64
	p.attributes.defending=73; p.attributes.passing=67
	p.talent_version=1; p.potential=79
	for key in ["talent_club","talent_slot","talent_club_bonus"]: p.erase(key)
	return p
func run() -> void:
	var w:=World.create()
	var madrid:=team(w,"c36"); var barcelona:=team(w,"c37")
	check(madrid>=83 and madrid<=88 and barcelona>=81 and barcelona<=87,"Spain has two genuinely strong starting elevens")
	check(team(w,"c50")>=74 and team(w,"c48")>=71 and madrid>team(w,"c50")+7,"Spain also has a competitive chasing group below its two giants")
	check(team(w,"c53")<71 and madrid>team(w,"c53")+13,"Spain retains ordinary teams and a visible top-to-bottom gap")
	for id in ["c36","c37","c43","c44","c46"]:
		var c: Dictionary=w.clubs[id]
		print("SQUAD DEPTH ",c.name," first=",team(w,id)," bench=",average(w,c.roster.slice(11,18))," reserves=",average(w,c.roster.slice(18)))
		# A rare established star may be on the bench; do not erase that player
		# merely to force every reserve below every starter.
		check(team(w,id)>average(w,c.roster.slice(11,18))+2 and average(w,c.roster.slice(18))<team(w,id)-5,"The strong first eleven has distinct bench and reserve quality: "+c.name)
	check(team(w,"c44")>team(w,"c45")+7 and team(w,"c43")>team(w,"c42")+3 and team(w,"c42")>=79 and team(w,"c66")>=79,"France has a dominant leader and Germany has a favorite with two strong challengers")
	var english: Array=w.clubs.values().filter(func(c): return c.league==7)
	check(english.filter(func(c): return team(w,c.id)>=82).size()==3 and english.filter(func(c): return team(w,c.id)>=80).size()==4,"England has three close favorites and a fourth strong contender")
	check(team(w,"c81")>=77 and team(w,"c82")>=73 and team(w,"c84")<71,"England retains a competitive middle and a weaker lower tier")
	check(team(w,"c38")>=80 and team(w,"c39")>=80 and team(w,"c54")>=78 and team(w,"c55")<71,"Portugal has a closer leading trio above its ordinary clubs")
	check(team(w,"c47")>=79 and team(w,"c85")>=79 and team(w,"c86")>=79,"The Netherlands has three comparable title contenders")
	check(team(w,"c40")>=82 and team(w,"c60")>=80 and team(w,"c41")>=80 and team(w,"c61")>=80 and team(w,"c40")-team(w,"c41")<4,"Italy has four strong contenders rather than one isolated favorite")
	check(team(w,"c62")>=74 and team(w,"c64")>=72 and team(w,"c65")<70,"Italy's middle tier connects the title contenders and weaker squads")
	check(team(w,"c72")>=75 and team(w,"c73")>=72 and team(w,"c67")>=74 and team(w,"c68")>=72,"French and German mid-table clubs offer meaningful opposition")
	check(team(w,"tr00")>=79 and team(w,"tr01")>=77 and team(w,"tr02")>=75 and team(w,"tr17")<62,"Turkey retains strong title contenders and weaker squads")
	# Only a handful of clubs in a league should turn into an all-star squad.
	for league in range(World.LEAGUES.size()):
		var ratings: Array=[]
		for c in w.clubs.values():
			if c.league==league: ratings.append(team(w,c.id))
		print("LEAGUE ",World.LEAGUES[league]," STARTING XI ",ratings)
		var strong_limit:=4 if league in [4,7] else 3
		check(ratings.max()-ratings.min()>10 and ratings.filter(func(v): return v>=80).size()<=strong_limit,"The league contains distinct strength tiers: "+World.LEAGUES[league])
	# V2 careers already contain the old club adjustment. A player keeps his
	# transfer, training and contracts; only the newly authored difference applies.
	var regional: Dictionary=w.players[w.clubs.c79.lineup[1]].duplicate(true)
	for key in Talent.STATS: regional.attributes[key]=76
	regional.attributes.control=82; regional.attributes.passing=79
	regional.talent_version=2; regional.talent_club_bonus=14; regional.potential=92
	regional.club="c18"; regional.shirt=99; regional.wage=23000
	regional.development={"plan":3,"xp":78.0,"gains":5}
	var regional_before:=regional.duplicate(true)
	Talent.rebalance(regional)
	check(Talent.STATS.all(func(key): return regional.attributes[key]==regional_before.attributes[key]+4),"V2 migration adds only the regional difference to the transferred player's trained skills")
	var expected:=regional_before.duplicate(true)
	expected.attributes=regional.attributes.duplicate(); expected.potential=95
	expected.talent_version=Talent.VERSION; expected.talent_club_bonus=18
	check(regional==expected,"Regional migration leaves every identity, transfer, contract and development field intact")
	var regional_stable:=regional.duplicate(true); Talent.rebalance(regional)
	check(regional==regional_stable,"A second load cannot stack the regional adjustment")
	var unchanged:=legacy_player(w)
	for key in Talent.STATS: unchanged.attributes[key]=81
	unchanged.talent_version=2; unchanged.talent_club="c36"; unchanged.talent_slot=1
	unchanged.talent_club_bonus=7; unchanged.potential=90
	var unchanged_before:=unchanged.duplicate(true); unchanged_before.talent_version=Talent.VERSION
	Talent.rebalance(unchanged)
	check(unchanged==unchanged_before,"An unchanged league cannot gain an old bonus that was previously lost to a stat cap")
	var trained_star:=regional_before.duplicate(true)
	for key in Talent.STATS: trained_star.attributes[key]=92
	trained_star.potential=94
	Talent.rebalance(trained_star)
	check(World.ovr(trained_star)==92 and trained_star.potential==94,"A player trained above the initial squad ceiling is never downgraded")
	var natural_star:=regional_before.duplicate(true)
	for key in Talent.STATS: natural_star.attributes[key]=91
	natural_star.talent_club_bonus=0; natural_star.potential=93
	Talent.rebalance(natural_star)
	check(World.ovr(natural_star)==91 and natural_star.potential==93,"An existing rare star does not gain a second club boost")
	# A V1 save must receive the same adjustment after a transfer, while its
	# training gains and saved career state survive the migration.
	var trained:=legacy_player(w)
	trained.attributes.control+=3; trained.attributes.passing+=2
	trained.development={"plan":3,"xp":78.0,"gains":5}
	trained.club="c18"; trained.shirt=99; trained.wage=18500
	trained.contract=2031; trained.fitness=.61; trained.form=1.2
	var preserved:=trained.duplicate(true)
	var untrained:=legacy_player(w)
	Talent.rebalance(untrained); Talent.rebalance(trained)
	check(trained.attributes.control==untrained.attributes.control+3 and trained.attributes.passing==untrained.attributes.passing+2,"Migration preserves the actual training gains instead of resetting player skills")
	check(trained.talent_club=="c36" and trained.talent_slot==1 and World.ovr(trained)>=79,"A transferred player uses his original identity, not the current club or shirt")
	for key in ["id","name","club","shirt","wage","contract","fitness","form","development"]:
		check(trained[key]==preserved[key],"Migration preserves "+key)
	var stable:=trained.duplicate(true)
	trained.club="c44"; trained.shirt=8; Talent.rebalance(trained)
	check(trained.attributes==stable.attributes and trained.potential==stable.potential,"Transfers and repeat loads never stack club adjustments")
	var prospect:=legacy_player(w)
	prospect.appearance_id=900; prospect.academy_owner="c00"; prospect.promoted=true
	var youth_before: Dictionary=prospect.attributes.duplicate()
	Talent.rebalance(prospect)
	check(prospect.attributes==youth_before,"An old academy identity inside the original ID range is not upgraded as a senior star")
	var star:=legacy_player(w)
	for key in Talent.STATS: star.attributes[key]=91
	star.potential=93
	Talent.rebalance(star)
	check(World.ovr(star)==91 and star.potential==93,"An existing world-class player retains his rare rating")
	# Verify world-level migration and serialization, with a genuine old marker.
	w.players.p0865=legacy_player(w)
	var clubs: Dictionary=w.clubs.duplicate(true)
	var fixtures: Array=w.fixtures.duplicate(true)
	World.upgrade(w)
	check(w.clubs==clubs and w.fixtures==fixtures,"Rebalancing preserves budgets, rosters, results and the calendar")
	var players: Dictionary=w.players.duplicate(true)
	var file:=FileAccess.open("/tmp/sefc-league-strength.save",FileAccess.WRITE)
	file.store_var(w); file.close()
	file=FileAccess.open("/tmp/sefc-league-strength.save",FileAccess.READ)
	var loaded: Dictionary=file.get_var(false); file.close(); World.upgrade(loaded)
	check(loaded.players==players,"Reloading a migrated world preserves every player exactly")
	# Very old careers may acquire international leagues only after an academy
	# has consumed the original ID range. New clones need their own origin and
	# must replace the template's adjustment, even if it is already balanced.
	var expanded: Dictionary=w.duplicate(true)
	for id in expanded.clubs.keys():
		if expanded.clubs[id].league<2: continue
		for pid in expanded.clubs[id].roster: expanded.players.erase(pid)
		expanded.clubs.erase(id)
	expanded.next_player=5000
	var retained: Dictionary=expanded.players.duplicate(true)
	World.upgrade(expanded)
	check(retained.keys().all(func(pid): return expanded.players[pid]==retained[pid]),"Adding missing leagues leaves already-balanced players untouched")
	var new_madrid: Dictionary=expanded.players[expanded.clubs.c36.lineup[0]]
	check(new_madrid.appearance_id>=5000 and new_madrid.talent_club=="c36" and team(expanded,"c36")>=82,"New expansion squads use their own club origin even outside the old ID range")
	var expanded_players: Dictionary=expanded.players.duplicate(true)
	World.upgrade(expanded)
	check(expanded.players==expanded_players,"Expansion and reloading cannot stack the template club's rating adjustment")
	print("LEAGUE STRENGTH CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
