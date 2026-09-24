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
func run() -> void:
	var world:=World.create()
	var ratings: Array=[]
	var potential_stars:=0
	var valid:=true
	for p in world.players.values():
		ratings.append(World.ovr(p)); potential_stars+=int(p.potential>=85)
		valid=valid and p.potential>=World.ovr(p) and p.potential<=95 and p.talent_version==Talent.VERSION
		for key in Talent.STATS: valid=valid and int(p.attributes[key])>=35 and int(p.attributes[key])<=95
	var good: int=ratings.filter(func(v): return v>=80).size()
	var stars: int=ratings.filter(func(v): return v>=85).size()
	var elite: int=ratings.filter(func(v): return v>=90).size()
	var mean: float=float(ratings.reduce(func(a,b): return a+b))/ratings.size()
	print("TALENT DISTRIBUTION: total=%d average=%.2f 80+=%d 85+=%d 90+=%d potential85+=%d" % [ratings.size(),mean,good,stars,elite,potential_stars])
	check(ratings.size()==2640 and mean>58 and mean<69,"The full world contains mostly ordinary players")
	check(good>150 and good<ratings.size()*.12 and stars>50 and stars<ratings.size()*.05 and elite>0 and elite<ratings.size()*.005,"Good squads coexist with a mostly ordinary world; 90+ players remain exceptional")
	check(valid and potential_stars<ratings.size()*.09,"All attributes and potential are bounded; fewer than one in ten players can reach 85")
	var second:=World.create()
	check(second.players==world.players,"New worlds reproduce the same individual talent and identities")
	var legacy: Dictionary=world.players.p0009.duplicate(true)
	legacy.erase("talent_version")
	for key in Talent.STATS: legacy.attributes[key]=80
	legacy.attributes.finishing=94; legacy.attributes.defending=49
	legacy.contract=2031; legacy.wage=18500; legacy.club="c18"; legacy.fitness=.63
	legacy.development={"plan":0,"xp":78.0,"gains":6}
	var identity: Dictionary=legacy.duplicate(true)
	world.players.p0009=legacy
	var clubs: Dictionary=world.clubs.duplicate(true)
	var fixtures: Array=world.fixtures.duplicate(true)
	World.upgrade(world)
	check(legacy.attributes.finishing>legacy.attributes.defending+30,"Migration preserves a striker's strengths and weaknesses")
	for key in ["id","career_id","appearance_id","name","club","contract","wage","fitness","development"]:
		check(legacy[key]==identity[key],"Migration preserves existing "+key)
	check(world.clubs==clubs and world.fixtures==fixtures,"Migration preserves club rosters, budgets and the season calendar")
	var balanced: Dictionary=world.players.duplicate(true)
	World.upgrade(world); World.upgrade(world)
	check(world.players==balanced,"Reloading a balanced career cannot repeatedly lower or reroll its ratings")
	# Round-trip through the same variant format as a career save.
	var file:=FileAccess.open("/tmp/sefc-talent-migration.save",FileAccess.WRITE)
	file.store_var(world); file.close()
	file=FileAccess.open("/tmp/sefc-talent-migration.save",FileAccess.READ)
	var loaded: Dictionary=file.get_var(false); file.close()
	var restored: Dictionary=loaded.players.duplicate(true)
	World.upgrade(loaded)
	check(loaded.players==restored,"The migration marker survives the career save format")
	var youth_stars:=0
	var youth_valid:=true
	for i in range(400):
		var p:=World.academy_player(world,world.clubs["c%02d" % (i%36)],i%4)
		youth_stars+=int(p.potential>=85)
		youth_valid=youth_valid and p.talent_version==Talent.VERSION and p.potential>=World.ovr(p)
		var before:=p.duplicate(true); Talent.rebalance(p)
		youth_valid=youth_valid and p==before
	check(youth_valid and youth_stars>0 and youth_stars<24,"Academies generate rare prospects without recreating broad rating inflation")
	var quick: Array=[]
	for club in range(8):
		for member in range(18):
			var keeper:=member in [0,11]
			var role:=0 if keeper else (1 if member in [1,2,3,4,12,13] else (3 if member in [9,10,16,17] else 2))
			var attrs:=World.Attributes.club_profile(club,member,keeper)
			quick.append(Talent.overall({"role":role,"attributes":attrs}))
	check(quick.filter(func(v): return v>=80).size()<quick.size()*.20 and quick.min()<55,"Quick-match squads contain a strong core without removing weaker players")
	var director=preload("res://scripts/career_director.gd").new()
	var prospect: Dictionary=legacy.duplicate(true)
	prospect.age=18; prospect.potential=World.ovr(prospect)+1
	prospect.development={"plan":0,"xp":0.0,"gains":0}
	director.gain(prospect,100000)
	check(World.ovr(prospect)==prospect.potential,"A large training reward stops exactly at potential instead of creating a superstar")
	print("PLAYER TALENT CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
