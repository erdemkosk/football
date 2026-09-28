extends "res://tests/career_flow_check.gd"
const World=preload("res://scripts/career_world.gd")
const Equipment=World.Equipment
func named(title: String) -> Control:
	for child in game.legend_screen.controls.get_children():
		if child is Button and child.text==title: return child
	return null
func press(title: String) -> bool:
	var b:=named(title)
	if b==null or b.disabled or not go(b): return false
	tap(JOY_BUTTON_A); return true
func usable() -> bool:
	var result:=true
	for child in game.legend_screen.controls.get_children():
		if child is BaseButton:
			result=Rect2(0,0,1440,900).encloses(Rect2(child.position,child.size)) and not Rect2(52,760,400,39).intersects(Rect2(child.position,child.size)) and result
			if not child.disabled: result=go(child) and result
	return result
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	game.legend_screen.queue_redraw()
	for i in range(25): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/sefc-personal-"+label+("-compact" if "--compact" in OS.get_cmdline_user_args() else "")+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-equipment-ui-settings.cfg"
	if "--visual" in OS.get_cmdline_user_args():
		game.match_menu.display.fullscreen=false; game.match_menu.display.resolution=Vector2i(1120,760) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1440,900)
		game.match_menu.display.apply(); await create_timer(1.5).timeout
		game.match_menu.display.apply(); await create_timer(.5).timeout
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.controller.using_gamepad=true; game.ball.freeze=true
	var l=game.legend; var ui=game.legend_screen; var c=l.career
	c.save_root="/tmp/sefc-personal-ui-"+str(OS.get_process_id()); DirAccess.make_dir_recursive_absolute(c.save_root); game.career.save_root=c.save_root
	l.create("c18",1,{"name":"Deniz Yıldız","position":7}); ui.open_hub()
	check(press("EKİPMAN & CÜZDAN") and ui.page=="equipment" and usable(),"The personal equipment shop is directly reachable with controller navigation")
	check(press("SÜRAT") and named("SATIN AL & KUŞAN").disabled,"The shop clearly disables an unaffordable purchase")
	await capture("empty-wallet")
	check(press("CÜZDAN") and usable(),"An empty earnings history remains usable and explains payment timing")
	await capture("first-income")
	c.world.date=World.day(2026,7,31); c.advance_one()
	Equipment.credit(c.world,l.player().id,"ui-contract",5000,"İmza parası"); c.save()
	press("KRAMPON"); press("SÜRAT"); var balance: int=l.data().equipment.balance
	check(press("SATIN AL & KUŞAN") and l.data().equipment.balance==balance-3200 and l.data().equipment.equipped.boots=="pace","Controller confirmation charges the wallet once and equips the purchased boot")
	check(named("KUŞANILDI").disabled and usable(),"A completed purchase replaces the stale buy action with its equipped state")
	await capture("boots")
	press("DESTEK"); press("KALECİ ELDİVENİ")
	check(named("KALECİLER İÇİN").disabled,"Outfield players see the goalkeeper-only restriction before purchasing")
	press("DESTEK TABANLIĞI"); press("SATIN AL & KUŞAN")
	check(l.data().equipment.equipped.support=="insoles" and usable(),"A single compatible support item can be purchased from the controller")
	await capture("support")
	press("CÜZDAN"); await capture("wallet")
	check(l.data().equipment.journal.size()==4 and usable(),"The history shows actual income and both purchases without affecting navigation")
	tap(JOY_BUTTON_B); check(ui.page=="hub","Back returns to the footballer hub with the current personal balance")
	await capture("hub")
	var base: Dictionary=l.player().attributes.duplicate(true); var price: int=c.market.value(l.player())
	check(l.train("passing") and game.players[9].attributes.pace==base.pace+3 and game.players[9].attributes.stamina==base.stamina+2,"Real training uses the equipped player's effective attributes")
	check(game.players[9].boot_meshes.all(func(boot): return boot.mesh==preload("res://scripts/player_appearance.gd").boot_mesh(5)),"The purchased boot colour is visible on the real player model")
	var actor=game.players[9]; var equipped_stats: Dictionary=actor.attributes.duplicate(true)
	actor.reset_stamina(); actor.desired=Vector3.FORWARD; actor.sprinting=true; actor.active_sprint=true; actor.action_timer=0
	var equipped_speed: float=actor.base_movement_speed(); actor.update_stamina(2)
	var equipped_energy: float=actor.energy
	actor.attributes=base.duplicate(true)
	actor.reset_stamina(); actor.sprinting=true; actor.active_sprint=true
	var bare_speed: float=actor.base_movement_speed(); actor.update_stamina(2)
	var bare_energy: float=actor.energy
	actor.attributes=equipped_stats; actor.reset_stamina()
	check(equipped_speed>bare_speed and equipped_speed<bare_speed*1.08 and equipped_energy>bare_energy,"Purchased gear measurably changes real movement speed and stamina with a modest bounded advantage")
	c.training.finish(80); c.training.leave()
	check(l.player().attributes==base and c.market.value(l.player())==price,"Equipment does not become permanent training growth or inflate transfer value")
	var f: Dictionary=c.next_fixture(); c.world.date=f.day; ui.open_hub(); l.play(); game.state="playing"
	var bench: Array=game.management.bench[0].filter(func(row): return row.get("career_id","")==l.player().id)
	check(bench.size()==1 and bench[0].attributes.pace==base.pace+3,"The substitute's persistent match identity includes equipment bonuses")
	l.live.skip_bench(); game.pace.substitutions_ready()
	for i in range(240):
		game.management.update_substitutions(1.0/60)
		if l.on_pitch(): break
	check(l.on_pitch() and game.players[game.controlled].attributes.pace==base.pace+3 and game.players[game.controlled].attributes.stamina==base.stamina+2,"A real substitution delivers the purchased effects to the controlled player on the pitch")
	if l.on_pitch():
		check(game.players[game.controlled].boot_meshes.all(func(boot): return boot.mesh==preload("res://scripts/player_appearance.gd").boot_mesh(5)),"Boot appearance survives substitute identity and kit application")
	c.detach(); game.return_menu(); game.career=c; ui.open_hub()
	for stat in World.Talent.STATS: l.player().attributes[stat]=67
	l.data().games=12; l.data().minutes=650; l.data().form=7.6; l.data().last={}
	c.world.date=World.day(2026,8,10); c.offers.week(); ui.go("transfers")
	check(not c.offers.active(true).is_empty() and usable(),"A believable personal offer appears with affordable terms and accessible negotiation controls")
	await capture("offer")
	l.create("tr00",3,{"name":"Deniz Kaleci","position":0}); ui.open_hub(); ui.go("equipment"); ui.shop_ui.tab=1; ui.shop_ui.selected="gloves"
	Equipment.credit(c.world,l.player().id,"keeper-contract",5000,"İmza parası"); ui.build()
	check(press("SATIN AL & KUŞAN") and l.data().equipment.equipped.support=="gloves" and usable(),"Goalkeepers can buy and equip the gloves through the same shop")
	await capture("keeper")
	print("LEGEND EQUIPMENT UI CHECK: %d checks, %d failures" % [checks,failures]); game.free(); quit(1 if failures else 0)
