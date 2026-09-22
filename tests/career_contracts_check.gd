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
func fresh() -> void:
	c=Career.new(); c.save_root="/tmp/sefc-career-contracts"
	DirAccess.make_dir_recursive_absolute(c.save_root); c.new_career("c00",1)
	for club in c.world.clubs.values(): club.cash=90000000; club.budget=60000000
func candidate(owner: String="c01",role: int=1) -> String:
	for pid in c.world.clubs[owner].roster:
		var p: Dictionary=c.player(pid)
		if p.role==role and c.contracts.transfer_lock(pid)=="":
			p.contract=2031
			return pid
	return ""
func total_payroll() -> int:
	var amount:=0
	for id in c.world.clubs: amount+=c.payroll(id)
	return amount

func run() -> void:
	fresh()
	var x=c.contracts
	var outfield: Array=[]; var keepers: Array=[]
	for p in c.world.players.values():
		if p.keeper: keepers.append(p.retirement_age)
		else: outfield.append(p.retirement_age)
	check(outfield.min()==34 and outfield.max()==38 and keepers.min()==36 and keepers.max()==40,"Retirement ages vary by identity, and goalkeepers play longer")
	var veteran: String=candidate("c00")
	var v: Dictionary=c.player(veteran); v.age=35; v.retirement_age=36
	v.listed=true; v.loan_listed=true
	c.world.offers.append({"player":veteran,"buyer":"c01","fee":1000000,"expires":c.world.date+7,"closed":false})
	c.begin_deal(veteran,true); c.deal.stage="sign"
	x.review_retirements()
	check(v.retirement_year==2027 and not v.listed and not v.loan_listed,"Retirement is announced in advance and clears sale/loan listings")
	check(c.available(veteran) and veteran in c.club().roster,"A retiring player can still play out the final season")
	check(c.world.offers[-1].closed and not c.accept_sale(c.world.offers.size()-1),"The announcement closes old offers and prevents accepting them")
	var cash: int=c.club().cash
	check(not c.sign_deal() and c.club().cash==cash,"Retirement invalidates an already negotiated renewal without charging")
	check(not c.transfer(veteran,"c01",100000,10000,2,1,"") and v.club=="c00","A direct transfer cannot sell a retiring player")
	var target: String=candidate()
	check(not c.transfer(target,"c00",100000,10000,2,1,veteran),"Retiring players cannot bypass the rule through a swap")
	check(not x.sign_loan(veteran,"c01",10000,75,1),"Retiring players cannot leave on new loans")
	c.begin_deal(veteran,true)
	check(c.deal.stage=="rejected","The negotiation room explains why retirement blocks renewal")
	var wages: int=c.payroll("c00")
	c.world.date=World.day(2027,6,30); x.update_calendar()
	check(not v.retired and veteran in c.club().roster,"Retirement leaves the player available through June 30")
	c.world.date+=1; x.update_calendar()
	check(v.retired and v.age==36 and v.club=="" and not veteran in c.club().roster and not veteran in c.club().lineup,"July retirement removes the player from squad and lineup at the right age")
	check(c.payroll("c00")==wages-v.wage and not c.available(veteran),"Retirement stops wages and match selection")
	check(not c.transfer(veteran,"c00",0,10000,2,1,"") and not x.transfer_lock(veteran).is_empty(),"A retired free player cannot re-enter through the transfer market")
	check(c.save() and c.load_slot(1) and c.player(veteran).retired,"Retirement and archived player identity survive save/load")
	# The existing version-1 binary format is upgraded without losing player IDs.
	fresh()
	var old: Dictionary=c.world.duplicate(true); old.version=1
	for p in old.players.values():
		for key in ["retirement_age","retirement_year","loan","loan_listed"]: p.erase(key)
	var file:=FileAccess.open(c.path_for(2),FileAccess.WRITE); file.store_var(old); file.close()
	check(c.load_slot(2) and c.world.version==World.VERSION and c.world.players.size()==2640,"Older career saves migrate automatically to the new contract model")
	check(c.player("p0000").has("retirement_age") and c.player("p0000").has("loan"),"Migration adds deterministic defaults to existing identities")
	# Agreement, fee, ownership, sporting registration and payroll are one transaction.
	fresh(); x=c.contracts; target=candidate()
	var p: Dictionary=c.player(target); var identity: Dictionary=p.duplicate(true)
	var total:=total_payroll(); var owner_wages: int=c.payroll("c01"); var user_wages: int=c.payroll("c00")
	p.loan_listed=true; x.begin(target)
	x.offer(1,0,0,true)
	check(c.deal.stage=="loan" and c.deal.fee>1 and c.deal.share==50,"Loan negotiations counter an insufficient fee and wage contribution")
	var fee: int=c.deal.fee
	x.offer(fee,50,0,true)
	check(c.deal.stage=="sign" and p.club=="c01" and c.deal.option>0,"Loan terms and purchase option require a separate final signature")
	cash=c.club().cash; var owner_cash: int=c.world.clubs.c01.cash
	check(c.sign_deal() and p.club=="c00" and p.loan.owner=="c01","Signing registers the player while preserving the legal owner")
	check(c.club().cash==cash-fee and c.world.clubs.c01.cash==owner_cash+fee,"The agreed loan fee is paid once to the parent club")
	check(target in c.club().roster and not target in c.world.clubs.c01.roster and not target in c.world.clubs.c01.lineup,"Only the borrowing club can field the loaned player")
	check(p.attributes==identity.attributes and p.appearance_id==identity.appearance_id,"A loan keeps the player's attributes and visual identity")
	check(p.loan.end==World.day(2027,1,31) and x.incoming("c00").has(target) and x.outgoing("c01").has(target),"Half-season loans expose both sides and the exact end date")
	check(c.payroll("c00")==user_wages+roundi(p.wage*.5) and c.payroll("c01")==owner_wages-roundi(p.wage*.5) and total_payroll()==total,"Shared wages conserve the exact total across both clubs")
	check(not c.sign_deal() and c.club().cash==cash-fee,"Double confirmation cannot charge the loan fee twice")
	check(not c.transfer(target,"c02",10000,10000,2,1,"") and not x.sign_loan(target,"c02",10000,75,1),"Borrowed players cannot be sold or loaned onwards")
	c.begin_deal(target,true); check(c.deal.stage=="rejected","The borrowing club cannot renew the parent club's contract")
	check(c.valid(c.world) and c.save() and c.load_slot(1),"The loan world is valid and reloads atomically")
	x=c.contracts; p=c.player(target)
	check(p.loan.owner=="c01" and p.loan.share==50 and p.loan.option>0 and x.outgoing("c01").has(target),"Loan dates, ownership, option and wage contribution persist")
	var bad: Dictionary=c.world.duplicate(true); bad.players[target].loan.share=101
	check(not c.valid(bad),"Save validation rejects a corrupted loan wage share")
	bad=c.world.duplicate(true); bad.clubs.c01.roster.append(target)
	check(not c.valid(bad),"Save validation rejects duplicate registration with the legal owner")
	# The ordinary daily calendar, not a test-only return, restores ownership and full wages.
	p.fitness=.71; p.goals=3; p.yellow=2
	c.world.date=World.day(2027,1,31)
	for f in c.cups.all_fixtures():
		if f.day<=c.world.date: f.played=true
	cash=c.club().cash; user_wages=c.payroll("c00")-x.wage_cost(target,"c00")
	c.advance_one()
	check(p.loan.is_empty() and p.club=="c01" and target in c.world.clubs.c01.roster and not target in c.club().roster,"The daily calendar automatically returns an expired half-season loan")
	check(c.payroll("c01")==owner_wages and c.payroll("c00")==user_wages,"Full parent-club wages resume after the loan ends")
	check(c.club().cash==cash+int(c.club().reputation*1900)-user_wages,"The first post-loan monthly payment excludes the returned player")
	check(p.goals==3 and p.yellow==2 and p.fitness<.9,"A return preserves sporting history and does not refill fitness")
	var shirts: Dictionary={}; var unique:=true
	for pid in c.world.clubs.c01.roster:
		var shirt: int=c.player(pid).shirt
		if shirts.has(shirt): unique=false
		shirts[shirt]=true
	check(unique,"Loan returns resolve shirt collisions without duplicate numbers")
	# Purchase-option exercise is permanent and cannot be repeated.
	fresh(); x=c.contracts; target=candidate(); p=c.player(target)
	check(x.sign_loan(target,"c00",100000,75,1,1000000),"A loan with a purchase option can start")
	c.world.date=World.day(2026,9,1); cash=c.club().cash
	check(not x.buy_option(target) and c.club().cash==cash,"Purchase options respect the transfer window")
	c.world.date=World.day(2027,1,1); var owner: String=p.loan.owner
	owner_cash=c.world.clubs[owner].cash; cash=c.club().cash
	check(x.buy_option(target) and p.loan.is_empty() and p.club=="c00" and p.contract==2030,"Exercising the option creates a permanent three-year contract")
	check(c.club().cash==cash-1000000 and c.world.clubs[owner].cash==owner_cash+1000000,"The option fee goes to the actual owner exactly once")
	check(not x.buy_option(target) and c.club().cash==cash-1000000,"A completed option cannot be paid a second time")
	c.world.date=World.day(2027,7,1); x.update_calendar()
	check(p.club=="c00" and p.loan.is_empty(),"An exercised option cancels the scheduled loan return")
	# Outgoing loans, AI offers and early recall.
	fresh(); x=c.contracts; veteran=candidate("c00"); v=c.player(veteran); v.loan_listed=true
	x.market_week()
	var offers: Array=c.world.offers.filter(func(o): return o.player==veteran and o.get("kind","")=="loan")
	check(not offers.is_empty(),"An AI club makes a loan offer for a listed user player")
	if not offers.is_empty():
		var offer: Dictionary=offers[0]; var borrower: String=offer.buyer
		check(c.accept_sale(c.world.offers.find(offer)) and v.club==borrower and v.loan.owner=="c00","Accepting an AI loan offer lends the actual player on the advertised terms")
		check(not c.accept_sale(c.world.offers.find(offer)),"An outgoing loan offer cannot be accepted twice")
		c.world.date=World.day(2026,9,1)
		check(not x.recall(veteran),"Early recall is unavailable outside transfer windows")
		c.world.date=World.day(2027,1,1); cash=c.club().cash; owner_cash=c.world.clubs[borrower].cash
		var cost: int=x.recall_cost(veteran)
		check(x.recall(veteran) and v.club=="c00" and v.loan.is_empty(),"The legal owner can recall a loan during the winter window")
		check(c.club().cash==cash-cost and c.world.clubs[borrower].cash==owner_cash+cost,"Early recall pays the agreed compensation to the borrowing club")
		check(not x.recall(veteran) and c.club().cash==cash-cost,"An already recalled player cannot incur another charge")
	check(c.world.deals.any(func(d): return d.get("kind","")=="loan" and d.from!="c00" and d.to!="c00"),"AI clubs also loan players between themselves")
	# Long loans persist through season rollover, but never extend the parent's contract.
	fresh(); x=c.contracts; target=candidate(); p=c.player(target); p.age=24; p.retirement_year=0
	check(x.sign_loan(target,"c00",100000,100,2),"A two-season loan can be agreed within the parent contract")
	for f in c.world.fixtures: f.played=true
	while not c.cups.done():
		for f in c.world.cup_fixtures.duplicate():
			if not f.played: c.simulate(f)
	c.world.season_done=true; c.world.date=World.day(2027,6,30)
	check(c.next_season() and not p.loan.is_empty() and p.loan.end==World.day(2028,6,30),"A two-season loan survives its first season rollover")
	for f in c.world.fixtures: f.played=true
	while not c.cups.done():
		for f in c.world.cup_fixtures.duplicate():
			if not f.played: c.simulate(f)
	c.world.season_done=true; c.world.date=World.day(2028,6,30)
	check(c.next_season() and p.loan.is_empty() and p.club=="c01","The second season rollover returns a two-season loan")
	check(c.valid(c.world),"A multi-season world with loans remains internally consistent")
	fresh(); x=c.contracts; target=candidate(); p=c.player(target); p.contract=2027
	cash=c.club().cash
	check(not x.sign_loan(target,"c00",100000,75,2) and p.loan.is_empty() and c.club().cash==cash,"A loan cannot outlast its parent's player contract")
	p.contract=2031; c.club().cash=1
	check(not x.sign_loan(target,"c00",100000,75,1) and p.club=="c01","Insolvent clubs cannot sign a loan")
	c.club().cash=90000000; c.world.date=World.day(2026,9,1)
	check(not x.sign_loan(target,"c00",100000,75,1),"Loan registration respects closed transfer windows")
	c.world.date=World.day(2026,7,1)
	var signed_count:=0
	for n in range(1,8):
		if x.sign_loan(candidate("c%02d" % n),"c00",10000,75,1): signed_count+=1
	check(signed_count==6 and x.incoming("c00").size()==6 and c.club().roster.size()==30,"A club cannot exceed six incoming loans or 30 registered players")
	check(c.valid(c.world),"The maximum-size loan squad remains saveable")
	print("CAREER CONTRACTS CHECK: %d checks, %d failures" % [checks,failures])
	c=null; quit(0 if failures==0 else 1)
