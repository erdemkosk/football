extends SceneTree
const Career=preload("res://scripts/career.gd")
const World=preload("res://scripts/career_world.gd")
const Rankings=World.Rankings
var c
var checks:=0
var failures:=0
var serial:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func match_result(home: String,away: String,score: Array,competition: String="",stage: int=0) -> Dictionary:
	serial+=1
	return {"id":"ranking-test-%d" % serial,"day":c.world.date,"home":home,"away":away,"score":score,"played":true,"competition":competition,"stage":stage}
func fresh() -> void: c.new_career("c35",1,{},false)
func run() -> void:
	c=Career.new(); c.save_root="/tmp/sefc-ranking-check-"+str(OS.get_process_id()); DirAccess.make_dir_recursive_absolute(c.save_root)
	fresh()
	check(c.world.rankings.clubs.size()==110 and c.world.rankings.leagues.size()==10 and c.valid(c.world),"Every club and league starts with valid persistent world standings")
	var order:=Rankings.ordered(c.world.rankings.clubs)
	check(order.size()==110 and order.all(func(id): return c.world.rankings.clubs[id].rank==order.find(id)+1),"Ranks form one deterministic complete global order")
	var f: Dictionary=c.world.fixtures.filter(func(fixture): return fixture.home=="c35")[0]
	var before: float=c.world.rankings.clubs.c35.points; var loser: float=c.world.rankings.clubs[f.away].points
	var league: float=c.world.rankings.leagues["1"].points
	check(c.apply_result(f,[2,0],{},true) and c.world.rankings.clubs.c35.points>before and c.world.rankings.clubs[f.away].points<loser,"The played-match completion path awards the winner and penalizes the loser")
	check(is_equal_approx(c.world.rankings.leagues["1"].points,league),"Domestic point exchanges do not inflate an entire league")
	var once: Dictionary=c.world.rankings.duplicate(true)
	check(not c.apply_result(f,[9,0]) and not Rankings.record(c.world,f.duplicate(true)) and c.world.rankings==once,"Repeated completion and copied fixtures cannot award points twice")
	var fixture2: Dictionary=c.world.fixtures.filter(func(fixture): return not fixture.played and fixture.home=="c35")[0]
	before=c.world.rankings.clubs.c35.points; c.simulate(fixture2)
	check(c.world.rankings.clubs.c35.matches==2 and c.world.rankings.clubs.c35.points!=before,"The simulated-match path uses the same ranking rules")
	fresh(); Rankings.record(c.world,match_result("c35","c36",[1,0]))
	var upset: float=c.world.rankings.clubs.c35.last_change
	fresh(); Rankings.record(c.world,match_result("c36","c35",[1,0]))
	check(upset>c.world.rankings.clubs.c36.last_change*3,"An underdog victory is worth substantially more than beating a weaker opponent")
	fresh(); Rankings.record(c.world,match_result("c35","c36",[4,0])); var capped: float=c.world.rankings.clubs.c35.last_change
	fresh(); Rankings.record(c.world,match_result("c35","c36",[20,0]))
	check(is_equal_approx(capped,c.world.rankings.clubs.c35.last_change),"Extra goals beyond a four-goal margin cannot farm additional rating")
	fresh(); var drawn:=match_result("c00","c36",[1,1],"champions",3); drawn.penalties=[5,3]
	Rankings.record(c.world,drawn); var draw_points: float=c.world.rankings.clubs.c00.points
	fresh(); drawn=match_result("c00","c36",[1,1],"champions",3); drawn.penalties=[3,5]; Rankings.record(c.world,drawn)
	check(is_equal_approx(draw_points,c.world.rankings.clubs.c00.points),"Shootout goals do not turn a drawn match into a rating victory")
	fresh(); var host_league:=str(c.world.clubs.c00.league); var guest_league:=str(c.world.clubs.c36.league)
	Rankings.record(c.world,match_result("c00","c36",[2,0],"champions"))
	var gain: float=c.world.rankings.leagues[host_league].coefficient; var loss: float=c.world.rankings.leagues[guest_league].coefficient
	var host_count: int=c.world.cups.champions.entries.filter(func(id): return c.world.clubs[id].league==c.world.clubs.c00.league).size()
	var guest_count: int=c.world.cups.champions.entries.filter(func(id): return c.world.clubs[id].league==c.world.clubs.c36.league).size()
	check(gain>0 and loss<0 and is_equal_approx(gain*host_count,-loss*guest_count),"International results change both leagues with normalization by actual representatives")
	check(c.world.rankings.leagues[host_league].points>Rankings.LEAGUE_SEEDS[int(host_league)] and c.world.rankings.leagues[guest_league].points<Rankings.LEAGUE_SEEDS[int(guest_league)],"League reputation rises and falls with international success")
	for i in range(120): Rankings.record(c.world,match_result("c00","c36",[2,0],"champions"))
	check(c.world.rankings.leagues[host_league].coefficient<=6 and c.world.rankings.leagues[guest_league].coefficient>=-6,"A season cannot change the international coefficient beyond the bounded swing")
	check(c.world.rankings.leagues[host_league].rank<c.world.rankings.leagues[host_league].start_rank and c.world.rankings.leagues[guest_league].rank>c.world.rankings.leagues[guest_league].start_rank,"Repeated international success and failure change the actual global league order")
	fresh(); before=c.world.rankings.clubs.c35.points
	c.world.cups.champions.champion="c35"; c.world.cup_history.append({"year":c.world.year,"competition":"champions","champion":"c35","runner_up":"c36"})
	Rankings.sync_cups(c.world); Rankings.refresh(c.world)
	check(is_equal_approx(c.world.rankings.clubs.c35.points,before+65),"An international title grants a meaningful separate honours bonus")
	once=c.world.rankings.duplicate(true); Rankings.sync_cups(c.world); Rankings.refresh(c.world)
	check(c.world.rankings==once,"Champion and runner-up bonuses are idempotent")
	var standings: Array=c.standings(1); standings.erase("c35"); standings.push_front("c35")
	before=c.world.rankings.clubs.c35.points; Rankings.league_awards(c.world,1,standings)
	check(is_equal_approx(c.world.rankings.clubs.c35.points,before+24.5),"Winning the second division earns its balanced honours bonus")
	once=c.world.rankings.duplicate(true); Rankings.league_awards(c.world,1,standings)
	check(c.world.rankings==once,"League prizes cannot be added twice")
	# Isolate sporting success from squad quality, cash, player identity and ability.
	fresh(); var p: Dictionary=c.player(c.world.clubs.c36.roster[9])
	for key in p.attributes: p.attributes[key]=75
	p.age=24; p.potential=75
	var intent: Dictionary=c.market.interest(p,"c35"); var salary: int=c.market.salary(p,"c35"); var level: float=c.market.level("c35")
	var club_row: Dictionary=c.world.rankings.clubs.c35
	club_row.points+=480; Rankings.refresh(c.world)
	var improved: Dictionary=c.market.interest(p,"c35")
	check(c.market.level("c35")>level+15 and improved.gap<intent.gap and c.market.salary(p,"c35")<salary,"Earned success materially improves attraction and salary demands for the exact same squad and target")
	check(intent.rare and not improved.rare,"Sustained success can make a previously exceptional transfer a normal negotiation")
	check(c.market.asking_price(p)>c.club().budget,"Rising sporting prestige does not remove a small club's financial constraint")
	level=c.market.level("c35"); c.world.rankings.leagues["1"].coefficient+=6; Rankings.refresh(c.world)
	check(c.market.level("c35")>level+1,"League reputation independently influences a club's transfer attraction")
	var price: int=c.market.value(p); c.world.rankings.clubs.c36.points+=100; Rankings.refresh(c.world)
	check(c.market.value(p)>price,"The selling club's earned reputation affects the same player's market price")
	p.terms.release=100000
	check(c.market.asking_price(p)==100000,"Earned reputation respects signed release clauses")
	var rng: int=c.world.rng
	for i in range(30): c.market.interest(p,"c35")
	check(c.world.rng==rng,"World ranking and transfer previews never consume simulation randomness")
	once=c.world.rankings.duplicate(true)
	check(c.save() and c.load_slot(1) and c.world.rankings==once,"Save and load retain exact club points, league coefficients and award guards")
	var corrupt: Dictionary=c.world.duplicate(true); corrupt.rankings.clubs.c35.points=NAN
	check(not c.valid(corrupt),"Non-finite ranking data is rejected before loading")
	corrupt=c.world.duplicate(true); corrupt.rankings.recorded=[]
	check(not c.valid(corrupt),"Malformed ranking history is rejected before loading")
	# Legacy migration must replay results only, without repaying money or changing athletes.
	fresh(); f=c.world.fixtures.filter(func(fixture): return fixture.home=="c35")[0]; c.apply_result(f,[3,0])
	var expected: Dictionary=c.world.rankings.duplicate(true); var old: Dictionary=c.world.duplicate(true)
	old.erase("rankings")
	for club in old.clubs.values(): club.erase("sporting_reputation")
	var players: Dictionary=old.players.duplicate(true); var ledger: Array=old.ledger.duplicate(true); var fixtures: Array=old.fixtures.duplicate(true)
	var cash: int=old.clubs.c35.cash
	Rankings.ensure(old)
	check(old.rankings==expected,"A pre-ranking save rebuilds the same sporting rating from its played results")
	check(old.players==players and old.ledger==ledger and old.fixtures==fixtures and old.clubs.c35.cash==cash,"Legacy replay changes no player attributes, results, payroll or finances")
	once=old.duplicate(true); Rankings.ensure(old)
	check(old==once,"Repeated migration cannot duplicate results or bonuses")
	# Promotion and a new season retain club identity and most earned success.
	before=c.world.rankings.clubs.c35.points; var seed: float=c.world.rankings.clubs.c35.seed_points
	c.world.rankings.leagues["1"].coefficient=3; c.world.clubs.c35.league=0; c.world.year+=1; Rankings.rollover(c.world)
	check(is_equal_approx(c.world.rankings.clubs.c35.points,seed+(before-seed)*.96) and is_equal_approx(c.world.rankings.leagues["1"].coefficient,2.82),"New seasons preserve 96 percent of earned club success and 94 percent of league coefficient")
	check(c.world.rankings.clubs.c35.start_rank==c.world.rankings.clubs.c35.rank and c.world.rankings.clubs.c35.matches==0 and c.world.rankings.recorded.is_empty(),"Promotion keeps global club identity and starts a fresh seasonal comparison")
	once=c.world.rankings.duplicate(true); Rankings.rollover(c.world)
	check(c.world.rankings==once,"Rollover itself is idempotent")
	print("WORLD RANKINGS CHECK: %d checks, %d failures" % [checks,failures]); c=null; quit(1 if failures else 0)
