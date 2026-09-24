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

func rating(p: Dictionary,overall: int) -> void:
	for key in p.attributes: p.attributes[key]=overall
	p.potential=overall

func run() -> void:
	c=Career.new(); c.save_root="/tmp/sefc-transfer-balance"
	DirAccess.make_dir_recursive_absolute(c.save_root); c.new_career("c35")
	var p: Dictionary=c.player(c.world.clubs.c36.roster[9])
	p.age=24; p.contract=2030; p.retirement_year=0
	var fees: Array=[]
	for quality in [50,60,70,80,90]:
		rating(p,quality); fees.append(c.market.value(p))
	print("TRANSFER SAMPLE 50/60/70/80/90 OVR: ",fees)
	check(fees[1]>fees[0]*3 and fees[2]>fees[1]*3 and fees[3]>fees[2]*3 and fees[4]>fees[3]*3,"Each ten-point quality tier has a materially higher fee")
	check(fees[4]>c.club().budget*20,"A small club cannot buy an elite player with its starting budget")
	var prime: int=c.market.value(p)
	p.age=34
	check(c.market.value(p)<prime*.4,"A veteran's shorter remaining career lowers resale value")
	p.age=20; rating(p,65); p.potential=65
	var ordinary: int=c.market.value(p); var salary: int=World.wage(p)
	p.potential=90
	check(c.market.value(p)>ordinary*1.6,"A young high-potential prospect commands a premium")
	check(World.wage(p)==salary,"Potential resale value does not multiply the current salary")
	var prestige: int=c.world.clubs.c36.reputation
	c.world.clubs.c36.reputation=45; var small: int=c.market.value(p)
	c.world.clubs.c36.reputation=90
	check(c.market.value(p)>small*1.5,"The selling club's stature affects price for the same player")
	c.world.clubs.c36.reputation=prestige
	p.contract=2027; var expiring: int=c.market.value(p)
	p.contract=2030
	check(c.market.value(p)>expiring*1.4,"A long contract costs more than its final year")
	p.listed=false; var protected: int=c.market.asking_price(p)
	p.listed=true
	check(c.market.asking_price(p)<protected,"Transfer-listed players have a lower club asking price")
	p.listed=false; p.terms.release=500000
	check(c.market.asking_price(p)==500000,"An existing release clause still limits the seller's demand")
	p.terms.release=0; p.age=24; rating(p,90)
	check(c.market.interest(p,"c35").rare,"An elite player sees a small club as a major step down")
	check(not c.market.interest(p,"c36").rare,"The same player can join an appropriate top-level club normally")
	var unattached: Dictionary=p.duplicate(true); unattached.club=""
	check(c.market.asking_price(unattached)==0 and c.market.interest(unattached,"c35").rare,"Free agents have no fee but elite players retain their sporting ambitions")
	var random_state: int=c.world.rng
	var willing:=0; var low_salary_accepted:=0
	var rejected_id:=""; var accepting_id:=""
	for index in range(1000):
		var prospect: Dictionary=p.duplicate(true); prospect.id="ambition-%d" % index
		var intent: Dictionary=c.market.interest(prospect,"c35")
		if intent.willing:
			willing+=1; accepting_id=prospect.id
		else: rejected_id=prospect.id
		if c.market.refusal(prospect,"c35",c.market.base_salary(prospect),2,3)=="": low_salary_accepted+=1
	check(willing>=15 and willing<=100,"Only a rare minority consider an exceptional downwards move (%d / 1000)" % willing)
	check(low_salary_accepted==0,"Normal wages cannot attract any elite player to the small club")
	check(c.world.rng==random_state,"Market previews do not consume career simulation randomness")
	var probe: Dictionary=p.duplicate(true); probe.id=accepting_id
	var required: int=c.market.salary(probe,"c35")
	check(required>=c.market.base_salary(probe)*3,"A willing exception demands at least triple guaranteed income")
	check(c.market.refusal(probe,"c35",required,2,3)=="","Exceptional guaranteed pay can convince a rare willing player")
	check(c.market.refusal(probe,"c35",required,1,3)!="" and c.market.refusal(probe,"c35",required,2,5)!="","An exceptional move also requires first-team status and a shorter commitment")
	check(c.market.refusal(probe,"c35",roundi(required*.8),2,3,required*12)=="","A funded signing bonus can contribute to guaranteed compensation")
	probe.id=rejected_id
	check(c.market.refusal(probe,"c35",required*100,2,3)!="","Even unlimited money cannot change most players' decision")
	var stable: Dictionary=c.market.interest(probe,"c35")
	for i in range(50):
		c.world.date=World.day(2026,7,1)+i
		if c.market.interest(probe,"c35")!=stable: stable={}; break
	check(not stable.is_empty(),"Reopening talks and advancing within the same window cannot reroll consent")
	c.world.date=World.day(2026,7,1)
	check(c.market.loan_refusal(p,"c35")!="" and not c.contracts.sign_loan(p.id,"c35",100000,100,1,1),"A cheap loan and purchase option cannot bypass elite ambition")
	var current_owner: String=p.club; var cash: int=c.club().cash
	check(not c.transfer(p.id,"c35",1,World.wage(p),3,2,"") and p.club==current_owner and c.club().cash==cash,"Direct AI transfer finalization also requires player consent and preserves failed transaction state")
	# Use real persistent identities for complete negotiation and save/load paths.
	var refusing:=""; var accepting:=""
	for pid in c.world.clubs.c36.roster:
		var candidate: Dictionary=c.player(pid)
		if candidate.keeper: continue
		rating(candidate,90); candidate.age=24; candidate.contract=2030; candidate.retirement_year=0
		if c.market.interest(candidate,"c35").willing: accepting=pid
		else: refusing=pid
	# The sample may contain no willing player: search other real clubs without
	# changing identity or the deterministic willingness rule.
	if accepting=="":
		for pid in c.world.players:
			var candidate: Dictionary=c.player(pid)
			if candidate.club in ["c35","c36"] or candidate.keeper: continue
			rating(candidate,90); candidate.age=24; candidate.contract=2030; candidate.retirement_year=0
			if c.market.interest(candidate,"c35").willing and c.sale_allowed(pid): accepting=pid; break
	check(refusing!="" and accepting!="","Real squads include both unwilling stars and a rare negotiable exception")
	c.club().cash=1000000000; c.club().budget=900000000
	c.begin_deal(refusing)
	c.offer_deal(c.market.asking_price(c.player(refusing))*2,10000000,3,2)
	c.offer_deal(c.deal.fee,10000000,3,2)
	check(c.deal.stage=="rejected" and c.deal.response.contains("üst seviyede"),"A funded club agreement still fails when the star refuses the destination")
	var refusal: String=c.deal.response
	c.begin_deal(refusing)
	c.offer_deal(c.market.asking_price(c.player(refusing))*2,10000000,3,2)
	c.offer_deal(c.deal.fee,10000000,3,2)
	check(c.deal.stage=="rejected" and c.deal.response==refusal,"Repeated negotiations cannot buy a fresh random chance")
	var signed_wage: int=c.player(refusing).wage
	var quoted: int=c.market.value(c.player(refusing))
	check(c.save() and c.load_slot(1) and c.market.value(c.player(refusing))==quoted and c.player(refusing).wage==signed_wage,"Reload preserves pricing, identity and existing signed salaries")
	check(not c.market.interest(c.player(refusing),"c35").willing,"An unwilling star stays unwilling after save/load")
	p=c.player(accepting); current_owner=p.club
	c.begin_deal(accepting)
	c.offer_deal(c.market.asking_price(p)*2,World.wage(p),3,2)
	c.offer_deal(c.deal.fee,World.wage(p),3,2)
	check(c.deal.stage=="contract" and c.deal.wage>=c.market.base_salary(p)*3,"A rare interested star counters with a substantial salary premium")
	var premium: int=c.deal.wage
	c.deal.terms.appearance=10000000; c.deal.terms.goal=10000000
	c.offer_deal(c.deal.fee,roundi(premium*.8),3,2)
	check(c.deal.stage=="contract","Huge conditional bonuses cannot replace a star's required guaranteed income")
	c.deal.terms.appearance=0; c.deal.terms.goal=0
	c.offer_deal(c.deal.fee,c.deal.wage,3,2)
	check(c.deal.stage=="sign" and p.club==current_owner,"Even the exceptional agreement needs a final signature")
	cash=c.club().cash; var fee: int=c.deal.fee
	check(c.sign_deal() and p.club=="c35" and c.club().cash==cash-fee,"The fully funded rare transfer completes and charges its real price once")
	check(not c.sign_deal() and c.club().cash==cash-fee,"The rare signing cannot be duplicated")
	check(c.save() and c.load_slot(1) and c.player(accepting).club=="c35","The rare transfer and wage survive career reload")
	if "--visual" in OS.get_cmdline_user_args(): await visual_check()
	print("TRANSFER BALANCE CHECK: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func visual_check() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.ball.freeze=true
	game.career=c; c.game=game; c.new_career("c35")
	var screen=game.career_screen; screen.open_hub(); screen.go("market")
	var best: String=screen.list_ids[0]
	for pid in screen.list_ids:
		if c.market.value(c.player(pid))>c.market.value(c.player(best)): best=pid
	screen.selected=best; screen.list_page=screen.list_ids.find(best)/9; screen.build()
	await capture("market")
	screen.negotiate(false)
	await capture("talks")
	game.free()

func capture(label: String) -> void:
	for i in range(25): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-transfer-"+label+".png")
