extends SceneTree
const Career=preload("res://scripts/career.gd")
const World=preload("res://scripts/career_world.gd")
const Progress=preload("res://scripts/legend_progression.gd")
var c
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func fresh(personal: bool=false) -> void:
	c=Career.new(); c.save_root="/tmp/sefc-negotiations-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(c.save_root); c.new_career("c18")
	if not personal: return
	c.player_mode=true
	var p:=World.academy_player(c.world,c.club(),3)
	p.attributes=Progress.initial_attributes(9,1); p.legend_player=true; p.potential=92
	p.wage=World.wage(p); p.contract=c.world.year+3; c.director.player_fields(p)
	c.world.players[p.id]=p; c.club().roster.append(p.id); c.assign_shirt(p.id)
	c.world.legend=Progress.create_data(p.id,9,int(c.world.date))
func rated(p: Dictionary,rating: int) -> void:
	for key in World.Talent.STATS: p.attributes[key]=rating
	p.potential=maxi(p.potential,rating)

func run() -> void:
	fresh()
	var pid: String=c.club().roster.filter(func(id): return c.sale_allowed(id) and c.player(id).role==2)[0]
	var p: Dictionary=c.player(pid)
	var o: Dictionary=c.offers.add(pid,"c00",c.market.value(p),c.market.salary(p,"c00"),2)
	check(not o.is_empty(),"A funded buyer submits a real offer")
	var original: int=o.fee; var cash: int=c.club().cash
	c.offers.counter_sale(o,int(o.ceiling)+10000000)
	check(o.fee>original and not o.closed and o.rounds==1,"An excessive fee produces a bounded counteroffer")
	var first: int=o.fee
	c.offers.counter_sale(o,int(o.ceiling)+10000000)
	check(o.fee==first and o.rounds==2,"Repeating the same demand cannot farm automatic concessions")
	check(c.club().cash==cash and p.club==c.world.user,"Negotiation alone never charges money or moves a player")
	check(c.save() and c.load_slot(1),"Offers and negotiation rounds reload in a valid career")
	o=c.world.offers[0]; p=c.player(pid)
	check(o.rounds==2 and o.fee==first and o.history.size()==3,"Counteroffer, reply history and remaining rounds persist")
	c.offers.counter_sale(o,int(o.ceiling))
	check(o.fee==o.ceiling and not o.closed,"A reasonable revised demand is accepted")
	var buyer_cash: int=c.world.clubs[o.buyer].cash; var seller_cash: int=c.club().cash
	check(c.accept_sale(0) and p.club==o.buyer,"The manager completes the negotiated sale")
	check(c.club().cash==seller_cash+o.fee and c.world.clubs[o.buyer].cash==buyer_cash-o.fee,"Buyer and seller book the negotiated fee exactly once")
	check(o.net_income==c.club().cash-seller_cash,"The signed offer records actual proceeds for its sale summary")
	check(not c.accept_sale(0) and c.world.clubs[o.buyer].cash==buyer_cash-o.fee,"A second acceptance cannot duplicate the payment")
	fresh(); pid=c.club().roster.filter(func(id): return c.sale_allowed(id) and c.player(id).role==2)[0]; p=c.player(pid)
	o=c.offers.add(pid,"c00",c.market.value(p),c.market.salary(p,"c00"),2)
	for n in range(3): c.offers.counter_sale(o,int(o.ceiling)*10)
	check(o.closed and not c.accept_sale(0),"Three failed rounds cause withdrawal")
	check(c.offers.add(pid,"c00",o.fee,o.wage,o.role).is_empty(),"Rejecting or reopening cannot instantly regenerate the same club's offer")
	fresh(); pid=c.club().roster.filter(func(id): return c.sale_allowed(id) and c.player(id).role==2)[0]; p=c.player(pid)
	o=c.offers.add(pid,"c00",c.market.value(p),c.market.salary(p,"c00"),2)
	c.world.clubs.c00.cash=1; var before: Dictionary=c.world.duplicate(true)
	check(not c.accept_sale(0) and c.world==before,"A buyer losing its funds cannot partially move ownership or money")
	c.world.date=o.expires+1
	check(not c.offers.live(o) and not c.accept_sale(0),"Expired offers cannot be signed")
	# Buying talks can concede a small, credible amount and cannot reset rounds.
	fresh(); c.club().cash=200000000; c.club().budget=100000000
	pid=c.world.clubs.c00.roster.filter(func(id): return c.sale_allowed(id) and World.ovr(c.player(id))<75)[0]; p=c.player(pid); p.listed=true; p.age=28
	c.begin_deal(pid); var asking: int=c.market.asking_price(p)
	c.offer_deal(roundi(asking*.85),50000,3,2)
	check(c.deal.stage=="club" and c.deal.fee<asking and c.deal.fee>=asking*.94,"A listed player's club makes a modest concession on a credible opening bid")
	var quote: int=c.deal.fee
	c.save(); c.load_slot(1); c.begin_deal(pid)
	check(c.deal.attempts==1 and c.deal.fee==quote,"Reopening purchase talks retains the last price and attempt count")
	for n in range(3): c.offer_deal(1,50000,3,2)
	c.begin_deal(pid)
	check(c.deal.stage=="rejected","A withdrawn purchase negotiation stays closed when reopened")
	c.world.date+=8; c.begin_deal(pid)
	check(c.deal.stage=="club" and c.deal.attempts==0,"After a cooling-off period new talks can begin")
	# Weekly scouting works for unlisted players without an unlimited inbox.
	fresh(); var count:=0
	for week in range(8):
		c.world.date=World.day(c.world.year,7,1)+week*7; c.offers.week(); var size: int=c.world.offers.size(); c.offers.week()
		check(c.world.offers.size()==size,"Weekly scouting cannot be rerolled: "+str(week))
		count=maxi(count,c.world.offers.size())
	check(count>0 and c.offers.active().size()<=6,"Normal squads attract bounded incoming interest without sale-listing everyone")
	# Personal offers depend on played football, not the hero's high potential.
	fresh(true); pid=c.world.legend.player; p=c.player(pid)
	c.offers.week()
	check(c.offers.active(true).is_empty(),"An unproven 18-year-old gets no offer merely for having 92 potential")
	c.world.legend.games=12; c.world.legend.minutes=650; c.world.legend.form=7.6; rated(p,67)
	for week in range(1,6): c.world.date=World.day(c.world.year,7,1)+week*7; c.offers.week()
	var entries: Array=c.offers.active(true)
	check(not entries.is_empty(),"Good form, minutes and suitable current ability attract personal offers")
	if entries.is_empty(): print("NEGOTIATIONS CHECK: %d checks, %d failures" % [checks,failures]); quit(1); return
	o=entries[0]
	check(c.offers.competition(pid,o.buyer)<=World.ovr(p)+7 and c.market.level(o.buyer)<=World.ovr(p)+10,"The destination is a believable step rather than an instant elite move")
	var old_club: String=c.world.user
	check(not c.transfer(pid,o.buyer,o.fee,o.wage,3,o.role,"") and not c.accept_sale(c.world.offers.find(o)),"AI and the manager sale path cannot transfer the controlled player without personal acceptance")
	var old_offer: Dictionary=o.duplicate(true)
	c.offers.counter_personal(o,int(o.max_wage)*20,5,2,int(o.max_bonus)*20)
	check(not o.closed and o.rounds==1 and o.wage<=o.max_wage and o.role<=o.max_role,"An unrealistic personal package gets a bounded salary and role counteroffer")
	check(c.offers.capacity(o.buyer,o.wage)>=o.fee+o.signing,"The counteroffer preserves the buyer's two-month payroll reserve")
	c.offers.counter_personal(o,o.wage,2,o.role,500)
	check(o.years==2 and o.signing==500 and o.response.contains("kabul"),"The player can negotiate duration, salary, role and guaranteed bonus")
	var signature: Dictionary=o.duplicate(true)
	check(c.save() and c.load_slot(1),"Personal negotiation survives save/load")
	o=c.world.offers.filter(func(row): return row==signature)[0]; p=c.player(pid)
	check(o.rounds==2 and o.wage==signature.wage and o.years==2,"Reload does not restore negotiation patience or change the agreed terms")
	var progress: Dictionary=c.world.legend.duplicate(true); var attributes: Dictionary=p.attributes.duplicate(true)
	buyer_cash=c.world.clubs[o.buyer].cash; seller_cash=c.club().cash
	var budget: int=c.world.clubs[o.buyer].budget; var fixtures: Array=c.world.fixtures.duplicate(true)
	c.in_match=true
	check(not c.offers.accept_personal(o),"A personal transfer cannot happen during a live match")
	c.in_match=false
	var funded_cash: int=c.world.clubs[o.buyer].cash
	c.world.clubs[o.buyer].cash=1
	var unchanged: Dictionary=c.world.duplicate(true)
	check(not c.offers.accept_personal(o) and c.world==unchanged,"A personal offer also revalidates funds without partial mutation")
	c.world.clubs[o.buyer].cash=funded_cash
	check(c.offers.accept_personal(o) and c.world.user==o.buyer and p.club==o.buyer,"Signing changes the personal career's club and persistent ownership together")
	check(c.world.clubs[o.buyer].cash==buyer_cash-o.fee-o.signing and c.club().budget==budget-o.fee-o.signing and c.world.clubs[old_club].cash==seller_cash+o.fee,"Personal fees and signing money are charged exactly once")
	check(c.world.legend.games==progress.games and c.world.legend.xp==progress.xp and p.attributes==attributes and c.world.fixtures==fixtures,"Transfer preserves earned development, identity and the existing season")
	check(not c.world.clubs[old_club].roster.has(pid) and c.club().roster.count(pid)==1 and not c.offers.accept_personal(o),"The controlled player belongs to one club and the contract cannot be signed twice")
	check(c.valid(c.world) and c.load_slot(1) and c.world.user==signature.buyer,"The transferred career is valid and reloads at the new club")
	c.world.date+=7; c.offers.week()
	check(c.offers.active(true).is_empty(),"A recent signing is not immediately offered another move")
	var broken: Dictionary=c.world.duplicate(true); broken.offers[0].years=99
	check(not c.valid(broken),"Malformed personal offer terms are rejected by save validation")
	fresh(true); pid=c.world.legend.player; p=c.player(pid); rated(p,67)
	c.world.legend.games=12; c.world.legend.minutes=650; c.world.legend.form=7.6
	c.offers.week(); o=c.offers.active(true)[0]
	for n in range(3): c.offers.counter_personal(o,10000000,5,2,100000000)
	check(o.closed and not c.offers.accept_personal(o),"Three unreasonable personal requests make the club withdraw")
	c.save(); c.load_slot(1); o=c.world.offers[0]
	check(o.closed and o.rounds==3 and not c.offers.accept_personal(o),"Reload cannot revive a withdrawn personal contract")
	c.world.date+=21; p=c.player(pid); p.wage=World.wage(p)*20; c.offers.week()
	var balanced: Array=c.offers.active(true)
	check(not balanced.is_empty() and balanced.all(func(row): return row.max_wage<=World.wage(p)*1.9+500),"Repeated moves cannot compound wages beyond the player's actual ability")
	fresh(); pid=c.club().roster.filter(func(id): return c.contracts.transfer_lock(id)=="")[0]
	c.club().cash=200000000; c.club().budget=100000000
	c.begin_deal(pid,true); c.deal.terms.signing=10000
	c.offer_deal(0,500000,3,2)
	check(c.sign_deal(),"A negotiated renewal can be signed normally")
	c.load_slot(1); c.begin_deal(pid,true)
	check(c.deal.stage=="contract" and not c.sign_deal(),"Reopening a signed renewal cannot replay its signature or signing bonus")
	print("NEGOTIATIONS CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
