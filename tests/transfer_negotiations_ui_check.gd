extends "res://tests/career_flow_check.gd"
const World=preload("res://scripts/career_world.gd")

func capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.career_screen.queue_redraw(); game.legend_screen.queue_redraw()
	for n in range(25): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-transfer-"+label+("-compact" if "--compact" in OS.get_cmdline_user_args() else "")+".png")

func find_button(ui,title: String) -> Control:
	for child in ui.controls.get_children():
		if child is Button and child.text==title: return child
	return null

func reachable(ui) -> bool:
	var ok:=true
	for child in ui.controls.get_children():
		if child is BaseButton and not child.disabled:
			ok=Rect2(0,0,1440,900).encloses(Rect2(child.position,child.size)) and go(child) and ok
	return ok

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-transfer-ui-settings.cfg"
	if "--visual" in OS.get_cmdline_user_args():
		game.match_menu.display.fullscreen=false
		game.match_menu.display.resolution=Vector2i(1120,760) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1440,900)
		game.match_menu.display.apply(); await create_timer(1.5).timeout
		game.match_menu.display.apply(); await create_timer(.5).timeout
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.ball.freeze=true
	var c=game.career; var ui=game.career_screen
	c.save_root="/tmp/sefc-transfer-ui-"+str(OS.get_process_id()); DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("c18"); ui.open_hub()
	var pid: String=c.club().roster.filter(func(id): return c.sale_allowed(id) and c.player(id).role==2)[0]
	var p: Dictionary=c.player(pid)
	var o: Dictionary=c.offers.add(pid,"c00",c.market.value(p),c.market.salary(p,"c00"),2)
	ui.go("finance"); game.controller.menus.sync()
	check(go(find_button(ui,"PAZARLIK YAP")),"The manager inbox exposes a controller-accessible negotiation action")
	tap(JOY_BUTTON_A)
	check(ui.page=="offer" and reachable(ui),"Every manager offer control fits and is controller-accessible")
	await capture("manager-offer")
	ui.transfer_ui.fee=int(o.ceiling)+1000000
	check(go(find_button(ui,"KARŞI TEKLİF SUN")),"The counteroffer action is reachable")
	tap(JOY_BUTTON_A)
	check(o.rounds==1 and o.response.contains("Karşı teklif"),"Submitting with the gamepad updates the real persisted negotiation")
	await capture("manager-counter")
	check(go(find_button(ui,"SATIŞI TAMAMLA")),"The final sale action is reachable")
	tap(JOY_BUTTON_A)
	check(p.club==o.buyer and o.closed and find_button(ui,"SATIŞI TAMAMLA")==null,"A completed sale removes the stale acceptance button")
	await capture("manager-signed")
	ui.hide(); ui.clear_controls()
	var l=game.legend; l.career.save_root=c.save_root
	l.create("c18",1,{"name":"Deniz Yıldız","position":7})
	c=l.career; var screen=game.legend_screen
	screen.open_hub(); screen.go("transfers"); game.controller.menus.sync()
	check(reachable(screen),"The empty personal offer page remains fully navigable")
	await capture("personal-empty")
	p=l.player()
	for key in World.Talent.STATS: p.attributes[key]=67
	l.data().games=12; l.data().minutes=650; l.data().form=7.6
	for n in range(6):
		c.world.date+=7; c.offers.week()
		if not c.offers.active(true).is_empty(): break
	var entries: Array=c.offers.active(true)
	check(not entries.is_empty(),"A developed player's offers appear in the personal inbox")
	if entries.is_empty(): game.free(); quit(1); return
	screen.go("transfers"); game.controller.menus.sync()
	check(reachable(screen),"All personal offer, salary, bonus, duration and role controls are reachable")
	await capture("personal-offer")
	o=screen.transfer_ui.selected
	screen.transfer_ui.wage=int(o.max_wage)*3; screen.transfer_ui.role=2
	check(go(find_button(screen,"KARŞI TEKLİF SUN")),"The personal counteroffer button is reachable")
	tap(JOY_BUTTON_A)
	check(o.rounds==1 and not o.closed,"Personal gamepad negotiation produces a real counteroffer")
	await capture("personal-counter")
	check(go(find_button(screen,"KULÜBÜN TEKLİFİNİ İMZALA")),"The offered contract can be signed with the controller")
	tap(JOY_BUTTON_A)
	check(l.player().club==o.buyer and l.career.world.user==o.buyer and o.closed,"Signing updates both the player and displayed career club")
	await capture("personal-signed")
	screen.go("hub")
	check(l.selection.has("competition") and l.career.valid(l.career.world),"The new club immediately has valid coach selection and a saveable season")
	await capture("personal-new-club")
	print("TRANSFER NEGOTIATIONS UI CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
