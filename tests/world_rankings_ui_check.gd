extends "res://tests/career_flow_check.gd"
const World=preload("res://scripts/career_world.gd")
func find_button(ui,title: String) -> Control:
	for child in ui.controls.get_children():
		if child is Button and child.text==title: return child
	return null
func reachable(ui) -> bool:
	var ok:=true
	for child in ui.controls.get_children():
		if child is BaseButton and not child.disabled:
			ok=Rect2(0,0,1440,900).encloses(Rect2(child.position,child.size)) and go(child) and ok
			if ui==game.legend_screen and ui.page=="world": ok=not Rect2(52,760,400,39).intersects(Rect2(child.position,child.size)) and ok
	return ok
func press(ui,title: String) -> bool:
	var b:=find_button(ui,title)
	if b==null or not go(b): return false
	tap(JOY_BUTTON_A); return true
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	game.career_screen.queue_redraw(); game.legend_screen.queue_redraw()
	for i in range(25): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/sefc-rankings-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-ranking-ui-settings.cfg"
	if "--visual" in OS.get_cmdline_user_args():
		game.match_menu.display.fullscreen=false; game.match_menu.display.resolution=Vector2i(1440,900)
		game.match_menu.display.apply(); await create_timer(1.5).timeout
		game.match_menu.display.apply(); await create_timer(.5).timeout
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.controller.using_gamepad=true; game.ball.freeze=true
	var c=game.career; var ui=game.career_screen
	c.save_root="/tmp/sefc-ranking-ui-"+str(OS.get_process_id()); DirAccess.make_dir_recursive_absolute(c.save_root)
	game.legend.career.save_root=c.save_root
	c.new_career("c35")
	# Show actual sporting movement and a top-ten-sized league list.
	for i in range(8): World.Rankings.record(c.world,{"id":"ui-win-%d" % i,"home":"c35","away":"c00","score":[2,0],"played":true})
	ui.open_hub(); await capture("hub")
	ui.go("league"); game.controller.menus.sync(); await capture("league-entry")
	check(press(ui,"DÜNYA SIRALAMASI  ·  KULÜPLER & LİGLER") and ui.page=="world","The complete manager league table leads to world rankings through controller input")
	check(ui.rankings_ui.ids.size()==110 and reachable(ui),"All global club controls fit the screen and are reachable")
	await capture("clubs")
	check(press(ui,"KULÜBÜMÜ BUL") and ui.rankings_ui.page==ui.rankings_ui.ids.find(c.world.user)/10,"Find my club jumps to its actual global page")
	await capture("my-club")
	check(ui.rankings_ui.movement(c.world.rankings.clubs.c35).begins_with("↑"),"The displayed season movement reflects earned results")
	ui.rankings_ui.page=10; ui.build()
	check(find_button(ui,"SONRAKİ →").disabled and not find_button(ui,"← ÖNCEKİ").disabled,"Pagination respects the last global club page")
	check(press(ui,"LİGLER") and ui.rankings_ui.mode==1 and ui.rankings_ui.ids.size()==10 and ui.rankings_ui.page==0,"Switching to leagues resets pagination and displays every league")
	check(find_button(ui,"SONRAKİ →").disabled and find_button(ui,"← ÖNCEKİ").disabled and press(ui,"LİGİMİ BUL"),"The league list has no empty pages and its own-league shortcut works")
	await capture("leagues")
	tap(JOY_BUTTON_B); check(ui.page=="league","Controller Back returns to league and cups")
	ui.go("market"); await capture("market")
	ui.selected=ui.list_ids[-1]; ui.negotiate(false); await capture("talks")
	ui.go("hub"); var pid: String=c.club().roster.filter(func(id): return c.sale_allowed(id) and c.player(id).role==2)[0]
	var p: Dictionary=c.player(pid); var offer: Dictionary=c.offers.add(pid,"c00",c.market.value(p),c.market.salary(p,"c00"),2)
	ui.transfer_ui.selected=offer; ui.transfer_ui.sync(); ui.go("offer"); await capture("offer")
	ui.hide(); ui.clear_controls()
	game.legend.create("tr00",2,{"name":"Deniz Yıldız","position":7}); c=game.legend.career
	var screen=game.legend_screen; screen.open_hub(); screen.go("league"); game.controller.menus.sync()
	check(press(screen,"DÜNYA SIRALAMASI  ·  KULÜPLER & LİGLER") and screen.page=="world" and reachable(screen),"Personal careers expose the same ranking system with reachable controls")
	check(press(screen,"KULÜBÜMÜ BUL") and screen.rankings_ui.page==screen.rankings_ui.ids.find("tr00")/10,"Personal rankings use the active personal club rather than the manager save")
	await capture("legend-clubs")
	check(press(screen,"LİGLER") and reachable(screen),"Personal career league rankings also fit and support the controller")
	await capture("legend-leagues")
	tap(JOY_BUTTON_B); check(screen.page=="league","Personal Back returns to the league page")
	check(c.save() and c.load_slot(2) and c.valid(c.world),"Personal ranking progress is valid and saveable")
	print("WORLD RANKINGS UI CHECK: %d checks, %d failures" % [checks,failures]); game.free(); quit(1 if failures else 0)
