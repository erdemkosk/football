extends "res://tests/career_flow_check.gd"
const World=preload("res://scripts/career_world.gd")

func option_at_point(point: Vector2) -> OptionButton:
	for control in game.career_screen.controls.get_children():
		if control is OptionButton and control.position==point: return control
	return null

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.ball.freeze=true
	game.match_menu.config_path="/tmp/sefc-career-loans-flow-settings.cfg"
	var c=game.career; var ui=game.career_screen
	c.save_root="/tmp/sefc-career-loans-flow"; DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("c00",1); c.club().cash=90000000; c.club().budget=60000000
	ui.open_hub(); ui.go("market"); game.controller.menus.sync()
	check(go(option_at_point(Vector2(487,173))),"The loan market filter is reachable by controller")
	for n in range(4): tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.market_filter==4 and not ui.list_ids.is_empty(),"Controller navigation opens the loan-listed player market")
	var target: String=ui.list_ids[0]
	for pid in ui.list_ids:
		if c.contracts.loan_reason(pid,"c00")=="": target=pid; break
	ui.select_player(target); var p: Dictionary=c.player(target); p.contract=2031
	var owner: String=p.club
	await capture("loan-market")
	check(go(named("KİRALIK TEKLİF")),"A loan negotiation is reachable from the player card")
	tap(JOY_BUTTON_A)
	check(c.deal.kind=="loan" and c.deal.stage=="loan" and ui.office!=null,"The loan proposal opens the animated 3D office")
	check(go(option_at_point(Vector2(934,368))),"The loan term selector is reachable")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.loan_term==2,"The controller can request a two-season loan")
	check(go(option_at_point(Vector2(934,447))),"The wage-share selector is reachable")
	tap(JOY_BUTTON_DPAD_LEFT)
	check(ui.loan_share==50,"The controller can choose a 50 percent wage contribution")
	check(go(named("SATIN ALMA OPSİYONU: KAPALI")),"The purchase-option toggle is reachable")
	tap(JOY_BUTTON_A)
	check(ui.loan_option and focus().position==Vector2(934,504),"Toggling the option preserves controller focus")
	ui.fee=1
	check(go(named("TEKLİFİ SUN")),"Submitting loan terms is reachable")
	tap(JOY_BUTTON_A)
	check(c.deal.stage=="loan" and ui.fee>1 and option_at_point(Vector2(934,447)).selected==0,"A counteroffer updates the fee and wage controls")
	await capture("loan-talks")
	tap(JOY_BUTTON_A)
	check(c.deal.stage=="sign" and p.club==owner,"Agreement displays a summary without moving the player")
	await capture("loan-agreement")
	check(go(named("ANLAŞMAYI İMZALA")),"The final loan signature is reachable")
	tap(JOY_BUTTON_A)
	check(c.deal.signed and p.club=="c00" and p.loan.owner==owner,"Controller signature completes the loan with separate legal ownership")
	ui.go("squad"); game.controller.menus.sync()
	check(go(option_at_point(Vector2(487,173))),"The squad loan filter is reachable")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.squad_filter==1 and ui.list_ids==[target],"Incoming loans appear in their own squad view")
	check(named("SÖZLEŞME YENİLE")==null and named("SATIŞA KOY")==null and named("OPSİYONU KULLAN")!=null,"A borrowed player's card exposes the option and hides invalid sale/renew actions")
	await capture("loan-squad")
	# The same loan identity must be loaded into a real 3D career fixture.
	var outgoing_slot:=1
	for n in range(1,11):
		if c.player(c.club().lineup[n]).role==p.role: outgoing_slot=n; break
	c.club().lineup[outgoing_slot]=target
	var fixture: Dictionary=c.next_fixture(); c.world.date=fixture.day
	ui.play()
	check(game.players.any(func(actor): return actor.career_id==target),"The actual physical match uses the borrowed player's persistent identity")
	c.in_match=false; c.fixture_id=""; game.frontend.visible=false; game.state="career"
	ui.open_hub(); ui.squad_filter=1; ui.go("squad")
	check(go(named("OPSİYONU KULLAN")),"The loan purchase option is reachable by controller")
	var cash: int=c.club().cash; var price: int=p.loan.option
	tap(JOY_BUTTON_A)
	check(not p.loan.is_empty() and c.club().cash==cash and ui.pending_action=="option","The option action first shows the exact payment for review")
	tap(JOY_BUTTON_A)
	check(p.loan.is_empty() and c.club().cash==cash-price and ui.squad_filter==0,"A second confirmation buys the player and refreshes the full squad")
	# User loans out a player through the same squad action and incoming-offer UI.
	var lent: String=""
	for pid in c.club().roster:
		if c.player(pid).role==1 and c.contracts.transfer_lock(pid)=="": lent=pid; break
	c.player(lent).contract=2031
	ui.select_player(lent)
	check(go(named("KİRALIK LİSTESİNE KOY")),"The loan-list action is reachable on an owned player")
	tap(JOY_BUTTON_A)
	check(c.player(lent).loan_listed and not c.player(lent).listed,"Loan-listing does not silently list a player for permanent sale")
	c.contracts.market_week(); ui.go("finance")
	var offers: Array=c.world.offers.filter(func(o): return o.get("kind","")=="loan" and not o.closed and o.player==lent)
	check(not offers.is_empty(),"An AI loan offer appears in the club inbox")
	await capture("loan-offers")
	if not offers.is_empty():
		var all_offers: Array=c.world.offers.filter(func(o): return not o.closed and o.expires>=c.world.date)
		var offer_index: int=all_offers.find(offers[0]); ui.offer_page=offer_index/4; ui.build()
		var accept: Control=null
		for control in ui.controls.get_children():
			if control is Button and control.position==Vector2(1223,405+(offer_index%4)*80): accept=control
		check(go(accept),"Accepting the outgoing loan offer is reachable by controller")
		tap(JOY_BUTTON_A)
		check(c.player(lent).loan.get("owner","")=="c00","Controller acceptance sends the actual player to the borrowing club")
	ui.squad_filter=2; ui.go("squad"); ui.select_player(lent)
	check(ui.list_ids.has(lent) and named("İLK 11'İ DEĞİŞTİR").disabled,"Loaned-out players are tracked but cannot be selected in the parent club's eleven")
	await capture("loan-outgoing")
	check(go(named("GERİ ÇAĞIR")),"The parent club can reach early recall by controller")
	tap(JOY_BUTTON_A); tap(JOY_BUTTON_A)
	check(c.player(lent).loan.is_empty() and c.player(lent).club=="c00","Recall confirmation restores the original player to the user squad")
	# Retirement is visible and enforced in both the squad and player market.
	var veteran: Dictionary=c.player(lent); veteran.age=35; veteran.retirement_age=36
	c.contracts.review_retirements(); ui.squad_filter=3; ui.go("squad"); ui.select_player(lent)
	check(ui.list_ids.has(lent) and named("SÖZLEŞME YENİLE").disabled and named("SATIŞA KOY").disabled and named("KİRALIK LİSTESİNE KOY").disabled,"Retirement decisions are visible and disable all invalid squad contract actions")
	await capture("retirement-squad")
	var remote: String=c.world.clubs.c02.roster[4]; c.player(remote).age=35; c.player(remote).retirement_age=36; c.contracts.review_retirements()
	ui.market_filter=5; ui.go("market"); ui.select_player(remote)
	check(ui.list_ids.has(remote) and named("GÖRÜŞMEYE BAŞLA").disabled and named("KİRALIK TEKLİF").disabled,"The market explains retirement and blocks both buying and borrowing")
	await capture("retirement-market")
	check(c.save() and c.load_slot(1),"The career still saves and loads after the complete controller workflow")
	print("CAREER LOANS FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
