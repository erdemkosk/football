extends SceneTree
const World=preload("res://scripts/career_world.gd")
var game
var failures:=0
var checks:=0
var visual:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.ball.freeze=true
	game.match_menu.config_path="/tmp/sefc-career-test-settings.cfg"
	var c=game.career; c.save_root="/tmp/sefc-career-check"
	DirAccess.make_dir_recursive_absolute(c.save_root)
	check(c.new_career("c18",1),"A lower-league career creates an atomic save")
	check(c.world.clubs.size()==110 and c.world.players.size()==2640,"Ten divisions have 110 clubs and 2640 persistent players")
	check(c.world.fixtures.size()==1310,"Both 18-team leagues have complete home-and-away schedules")
	var valid:=true
	for id in c.world.clubs:
		if c.world.clubs[id].league>=2: continue
		var games:=0; var home:=0; var opponents: Dictionary={}; var days: Dictionary={}
		for f in c.world.fixtures:
			if not id in [f.home,f.away]: continue
			games+=1; home+=int(f.home==id)
			var opp: String=f.away if f.home==id else f.home
			opponents[opp]=int(opponents.get(opp,0))+1
			valid=valid and not days.has(f.day); days[f.day]=true
		valid=valid and games==34 and home==17 and opponents.size()==17 and opponents.values().all(func(n): return n==2)
	check(valid,"Every club plays each opponent twice, 17 at home, with no double bookings")
	check(c.window_open(),"July opens the summer transfer window")
	c.world.date=World.day(2026,9,1); check(not c.window_open(),"September closes player registration")
	c.world.date=World.day(2027,1,1); check(c.window_open(),"January opens the winter transfer window")
	c.world.date=World.day(2027,2,1); check(not c.window_open(),"February closes the winter window")
	c.world.date=World.day(2026,7,31)
	var cash: int=c.club().cash; var wages: int=c.payroll(c.world.user)
	c.advance_one()
	check(c.club().cash==cash+int(c.club().reputation*1900)-wages,"Crossing a month posts sponsor income and wages exactly once")
	var pid: String="p0809"; var p: Dictionary=c.player(pid)
	var old_owner: String=p.club; var identity: Dictionary=p.duplicate(true)
	c.club().cash=40000000; c.club().budget=30000000
	c.begin_deal(pid)
	c.offer_deal(1,1,3,1)
	check(c.deal.stage=="club" and c.deal.fee>1,"A low bid generates a club counteroffer")
	c.offer_deal(c.deal.fee,1,3,1)
	check(c.deal.stage=="contract" and p.club==old_owner,"A club agreement does not yet transfer the player")
	c.offer_deal(c.deal.fee,1,3,0)
	check(c.deal.stage=="contract" and c.deal.wage>1,"Player salary and squad role are negotiated independently")
	c.offer_deal(c.deal.fee,c.deal.wage,3,c.deal.role)
	check(c.deal.stage=="sign" and p.club==old_owner,"Agreed terms present a final signature step")
	cash=c.club().cash; var fee: int=c.deal.fee
	check(c.sign_deal() and p.club==c.world.user,"Signing adds the same player to the actual club roster")
	check(c.club().cash==cash-fee and not pid in c.world.clubs[old_owner].roster,"Cash and both rosters update together")
	check(p.attributes==identity.attributes and p.appearance_id==identity.appearance_id and p.role==identity.role,"A transfer preserves attributes, appearance and natural position")
	check(not c.sign_deal() and c.club().cash==cash-fee,"Repeated confirmation cannot buy or charge twice")
	var jerseys: Array=[]
	for id in c.club().roster: jerseys.append(c.player(id).shirt)
	var unique: Dictionary={}
	for jersey in jerseys: unique[jersey]=true
	check(jerseys.size()==unique.size(),"The new signing is assigned a unique shirt number")
	var swap: String=c.club().roster[18]
	var target: String="p0050"
	var swap_seller: String=c.player(target).club
	check(c.transfer(target,c.world.user,100000,9000,3,1,swap),"A player-plus-cash swap can complete")
	check(c.player(swap).club==swap_seller and swap in c.world.clubs[swap_seller].roster and not swap in c.club().roster,"The exchange player moves in the opposite direction")
	c.world.date=World.day(2026,9,4); var before: int=c.club().cash
	check(not c.transfer("p0027",c.world.user,1000,5000,2,1,"") and c.club().cash==before,"Closed windows reject transfers without charging money")
	c.begin_deal(pid,true); c.offer_deal(0,p.wage*2,4,2)
	check(c.sign_deal() and p.contract==2030,"Own players can renew contracts outside transfer windows")
	check(c.save(),"The career can be saved after market activity")
	var saved_date: int=c.world.date
	c.world.date+=100
	check(c.load_slot(1) and c.world.date==saved_date and c.player(pid).club==c.world.user,"Loading restores dates, transfers and player identity")
	# Readable backup recovery, no object deserialization or replacement of good state.
	c.save(); var file:=FileAccess.open(c.path_for(1),FileAccess.WRITE); file.store_string("broken"); file.close()
	check(c.load_slot(1) and c.exists(),"A damaged primary file falls back to the previous complete save")
	c.new_career("c18",2)
	var f: Dictionary=c.next_fixture(); c.world.date=f.day
	check(c.prepare_match() and c.in_match and game.frontend.visible,"A scheduled career fixture opens the existing pre-match tactics screen")
	check(game.players[0].career_id!="" and game.players[9].natural_position>=0,"Persistent identities are loaded into actual 3D players")
	game.frontend.confirm(); game.ceremony.finish(true)
	check(game.career.in_match and game.team_name(0)==c.club().name,"Starting the physical match retains the chosen career club")
	var live_pid: String=game.players[9].career_id
	game.score=[2,1]; game.players[9].energy=.45; game.players[9].yellow_cards=1
	c.match_goals={live_pid:2}; game.state="finished"
	check(c.finish_match() and f.played,"Full-time records the real match into its scheduled fixture")
	check(c.world.table[c.world.user].pts==3 and c.world.table[c.world.user].p==1,"Actual match result updates the league table")
	check(c.player(live_pid).goals==2 and c.player(live_pid).fitness<.7 and c.player(live_pid).yellow==1,"Goals, fatigue and discipline persist after the match")
	check(not c.finish_match() and c.world.table[c.world.user].p==1,"Returning to the result screen cannot award points twice")
	c.detach()
	check(game.clubs.career_clubs.is_empty(),"Leaving career restores the independent quick-match catalogue")
	var runner=game.players[9]; runner.career_id="test"; runner.active_sprint=true; runner.energy=1
	runner.attributes.pace=50; var slow: float=runner.movement_speed(); runner.attributes.pace=90
	check(runner.movement_speed()>slow*1.2,"Career pace differences materially affect actual sprint speed")
	runner.desired=Vector3.FORWARD; runner.sprinting=true; runner.action_timer=0; runner.exhausted=false; runner.attributes.stamina=40
	runner.update_stamina(2); var tired: float=runner.energy
	runner.energy=1; runner.attributes.stamina=90; runner.update_stamina(2)
	check(runner.energy>tired,"Endurance affects real stamina consumption")
	# Complete two seasons, exercising date events, every AI fixture and promotion.
	c.new_career("c18",3)
	var expiring: String=c.club().roster[4]
	c.player(expiring).contract=2027
	var veteran: String=c.club().roster[5]
	c.player(veteran).age=37
	var suspended: String=c.club().lineup[9]
	c.player(suspended).banned=1
	var first: Dictionary=c.next_fixture(); c.world.date=first.day; c.simulate_next()
	check(c.player(suspended).appearances==0 and c.player(suspended).banned==0,"A suspension is served without crediting the player with an appearance")
	var seasons:=0
	while seasons<2:
		var safety:=0
		while not c.world.season_done and safety<400:
			var next: Dictionary=c.next_fixture()
			if next.is_empty(): c.advance_to_event(); safety+=1; continue
			while c.world.date<next.day: c.advance_one()
			c.simulate_next(); safety+=1
		check(c.world.fixtures.all(func(item): return item.played) and c.world.table.keys().all(func(id): return c.world.table[id].p==(34 if World.full_calendar(c.world.clubs[id].league) else 14)),"Every team completes its domestic schedule in season %d" % (seasons+1))
		var wins:=0; var losses:=0; var scored:=0; var conceded:=0
		for row in c.world.table.values(): wins+=row.w; losses+=row.l; scored+=row.gf; conceded+=row.ga
		check(wins==losses and scored==conceded,"Season tables conserve wins/losses and goals")
		var promoted: Array=c.standings(1).slice(0,3); var relegated: Array=c.standings(0).slice(15,18)
		check(c.next_season(),"The completed season rolls into the next year")
		if seasons==0:
			check(c.player(expiring).club=="" and not expiring in c.club().roster,"An unrenewed contract expires instead of being silently extended")
			check(c.player(veteran).get("retired",false) and not veteran in c.club().roster,"Retiring players leave the active squad and transfer market")
			check(c.world.next_player>864 and c.club().roster.size()>=22,"Academy players replenish depleted squads with new persistent identities")
			var june: int=World.day(2027,6,1)
			check(c.world.ledger.any(func(item): return item.club==c.world.user and item.day==june and item.amount<0),"The off-season still pays June salaries")
		check(promoted.all(func(id): return c.world.clubs[id].league==0) and relegated.all(func(id): return c.world.clubs[id].league==1),"Promotion and relegation change the actual next-season leagues")
		check(c.world.fixtures.size()==1310 and c.world.table.values().all(func(row): return row.p==0),"New-season fixtures and standings start cleanly")
		seasons+=1
	check(c.valid(c.world),"The multi-season world remains internally consistent and reloadable")
	if visual:
		c.new_career("c00",1)
		for page in ["entry","choose","hub","squad","tactics","league","market","finance"]:
			if page=="entry": game.career_screen.open_entry()
			elif page=="choose": game.career_screen.choose(1)
			else: game.career_screen.open_hub(); game.career_screen.go(page)
			await capture(page)
		game.career_screen.selected="p0249"; game.career_screen.negotiate(false)
		await capture("talks")
		c.offer_deal(World.value(c.player("p0249"))*2,15000,3,2)
		c.offer_deal(c.deal.fee,30000,3,2)
		game.career_screen.build(); await capture("agreement")
		c.sign_deal(); game.career_screen.build(); await capture("signed")
	print("CAREER CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)

func capture(label: String) -> void:
	for i in range(70): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/career-"+label+".png")
