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
	c=Career.new(); c.save_root="/tmp/sefc-director-check"; DirAccess.make_dir_recursive_absolute(c.save_root); c.new_career(id)
func run() -> void:
	fresh("c36")
	check(c.valid(c.world) and c.world.clubs.size()==110,"An overseas career creates a valid 110-club world")
	var schedules:=true
	for id in c.world.clubs:
		var fixtures: Array=c.world.fixtures.filter(func(f): return id in [f.home,f.away])
		var opponents: Dictionary={}
		for f in fixtures:
			var other: String=f.away if f.home==id else f.home
			opponents[other]=int(opponents.get(other,0))+1
		var total:=34 if World.full_calendar(c.world.clubs[id].league) else 14
		schedules=schedules and fixtures.size()==total and opponents.size()==total/2 and opponents.values().all(func(n): return n==2)
	check(schedules,"All nine leagues have complete home-and-away schedules")
	check(c.standings(2).size()==8 and not c.next_fixture().is_empty(),"Foreign clubs participate in their domestic season")
	var p: Dictionary=c.player(c.club().roster[9]); p.age=19; p.potential=96; p.development.plan=2; p.attributes.finishing=70
	var before: int=p.attributes.finishing
	c.director.gain(p,80)
	check(p.attributes.finishing==before+1 and p.development.gains==1,"Plan-specific experience raises the chosen on-field attribute")
	var xp: float=p.development.xp; p.age=33; c.director.gain(p,1000)
	check(p.development.xp==xp,"Veterans do not gain unlimited youth development")
	p.age=19; p.squad_role=2
	for n in range(6): c.director.match_progress(c.world.user,[],false)
	check(p.concern!="" and p.morale<.7,"A promised starter reacts to repeated bench time")
	c.director.talk(p.id,1)
	check(p.promise.required==180,"A conversation creates a measurable playing-time promise")
	var morale: float=p.morale
	c.director.talk(p.id,0)
	check(p.morale==morale,"Conversation cooldown prevents unlimited morale farming")
	c.world.date=p.promise.due; c.director.daily()
	check(p.promise.is_empty() and p.morale<morale,"A broken playing-time promise reduces morale")
	p.conversation_day=-99999; c.director.talk(p.id,1); p.minutes+=180
	c.world.date=p.promise.due; morale=p.morale; c.director.daily()
	check(p.promise.is_empty() and p.morale>morale,"A kept promise restores trust")
	p.morale=.2; p.recent_minutes=[0,0,0,0]; c.director.match_progress(c.world.user,[],false)
	check(p.listed and p.concern.contains("Ayrılmak"),"Severe dissatisfaction creates a transfer request")
	fresh(); c.club().cash=40000000; c.club().budget=30000000
	var cash: int=c.club().cash
	c.director.scout("BR",3,60)
	check(c.club().cash==cash-90000 and c.world.scouts.size()==1,"Scouting reserves an affordable, paid country assignment")
	c.world.date+=59; c.director.daily()
	check(c.world.academy.get(c.world.user,[]).is_empty(),"Scouting reports cannot arrive before their due date")
	c.world.date+=1; c.director.daily()
	check(c.world.academy[c.world.user].size()==3,"A completed scout mission returns three academy prospects")
	var youth: String=c.world.academy[c.world.user][0]; var q: Dictionary=c.player(youth)
	check(q.nationality=="BR" and q.role==3 and q.age<=18,"Reports respect the requested country and position")
	check(not c.sale_allowed(youth) and not youth in c.club().roster,"Academy prospects are not transferable free agents or first-team players")
	c.director.daily()
	check(c.world.academy[c.world.user].size()==3,"A delivered scout report cannot create duplicates")
	check(c.director.promote(youth).contains("katıldı") and q.club==c.world.user and q.promoted,"Promotion signs the prospect to the real first-team roster")
	c.director.match_progress(c.world.user,[youth],true,{youth:27})
	check(q.minutes==27 and c.world.manager.youth_minutes==27,"Actual substitution minutes count toward the academy objective")
	check(c.save() and c.load_slot(1) and c.player(youth).promoted,"Scouting, academy and development state survive reload")
	var old: Dictionary=c.world.duplicate(true); old.version=3
	for key in ["scouts","academy","manager"]: old.erase(key)
	for v in old.players.values():
		for key in ["development","minutes","recent_minutes","promise","concern","conversation_day","terms"]: v.erase(key)
	var file:=FileAccess.open(c.path_for(2),FileAccess.WRITE); file.store_var(old); file.close()
	check(c.load_slot(2) and c.world.version==World.VERSION and c.player(youth).has("development"),"Older saves migrate with player IDs and roster membership intact")
	fresh(); c.club().cash=60000000; c.club().budget=50000000
	var target: String=c.world.clubs.c01.roster[9]
	c.begin_deal(target)
	c.deal.terms={"signing":50000,"appearance":500,"goal":1000,"title":20000,"release":10000000,"sell_on":10,"beneficiary":"c01"}
	c.offer_deal(5000000,50000,3,2); c.offer_deal(5000000,50000,3,2)
	cash=c.club().cash
	check(c.sign_deal() and c.club().cash==cash-5050000,"Signing deducts both the agreed fee and signing bonus exactly once")
	check(not c.sign_deal() and c.club().cash==cash-5050000,"Repeated signatures cannot charge terms twice")
	q=c.player(target)
	var base_salary: int=c.terms.salary_floor(q,{"renewal":true,"terms":{}},3)
	check(c.terms.salary_floor(q,{"renewal":true,"terms":{"signing":100000,"appearance":500}},3)<base_salary,"Guaranteed and appearance bonuses reduce the negotiated salary demand")
	check(q.terms.goal==1000 and q.terms.sell_on==10,"Performance bonuses and sell-on clauses are stored on the contract")
	cash=c.club().cash; c.director.match_progress(c.world.user,[target],true)
	check(c.club().cash==cash-500,"An appearance bonus is paid only for a player who participated")
	q.goals=2; cash=c.club().cash
	c.terms.result_bonuses({"home":"c00","away":"c02"})
	check(c.club().cash==cash-2000,"Goal bonuses pay the new goal delta")
	c.terms.result_bonuses({"home":"c00","away":"c02"})
	check(c.club().cash==cash-2000,"Previously paid goals are not paid again")
	var seller_cash: int=c.club().cash; var former_cash: int=c.world.clubs.c01.cash
	check(c.transfer(target,"c02",1000000,50000,3,2,""),"A player with a resale clause can be transferred normally")
	check(c.club().cash==seller_cash+900000 and c.world.clubs.c01.cash==former_cash+100000,"The previous club receives its share while the seller receives the net fee")
	q.terms.release=World.value(q); c.begin_deal(target); c.deal.rival_fee=0
	c.offer_deal(q.terms.release,50000,3,2)
	check(c.deal.stage=="contract","A release-price offer is accepted without the seller's normal markup")
	fresh(); target=c.world.clubs.c01.roster[9]; c.player(target).age=22
	c.begin_deal(target)
	check(c.deal.rival!="" and c.deal.rival_fee>0,"A desirable player attracts a funded rival offer with a deadline")
	var rival: String=c.deal.rival; var deadline: int=c.deal.deadline
	c.save(); c.load_slot(1); c.begin_deal(target)
	check(c.deal.deadline==deadline and c.deal.rival==rival,"Rival offers retain the same deadline across save/load and reopened talks")
	c.world.date=c.deal.deadline+1; c.terms.daily()
	check(c.player(target).club==rival and c.deal.stage=="rejected","Ignoring a competing bid allows the player to join the rival club")
	fresh(); c.world.manager.trust=30; c.world.manager.target=1; c.world.date+=95
	for id in c.standings(0): c.world.table[id].p=5; c.world.table[id].pts=15
	c.world.table.c00.pts=0; c.director.review()
	check(not c.world.manager.employed and c.next_fixture().is_empty(),"Persistent poor results can end the managerial job and disable coaching fixtures")
	var job: String=c.director.job_clubs().filter(func(id): return c.world.clubs[id].league>=2)[0]
	var date: int=c.world.date; var fixture_count: int=c.world.fixtures.size()
	c.director.accept_job(job)
	check(c.world.user==job and c.world.manager.employed and c.world.date==date and c.world.fixtures.size()==fixture_count,"An overseas job changes the controlled club without restarting the world")
	check(c.save() and c.load_slot(1) and c.world.user==job and c.valid(c.world),"The new managerial job and board objectives persist in a valid save")
	var broken: Dictionary=c.world.duplicate(true); broken.players[broken.clubs[broken.user].roster[0]].development.plan=99
	check(not c.valid(broken),"Malformed development plans are rejected before loading a save")
	print("CAREER DIRECTOR CHECK: %d checks, %d failures" % [checks,failures]); c=null; quit(0 if failures==0 else 1)
