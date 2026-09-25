extends "res://tests/menu_controller_check.gd"

func return_home() -> void:
	if game.career_screen.visible: game.career_screen.close()
	game.return_menu(); game.set_process(false); game.set_physics_process(false)
	game.hud.home_menu.was_visible=false
	await settle()

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0
	var c=game.career
	var temp_root := OS.get_environment("TEMP") if OS.has_feature("windows") else "/tmp"
	c.save_root=temp_root.path_join("sefc-home-menu-check-"+str(OS.get_process_id()))
	var created := DirAccess.make_dir_recursive_absolute(c.save_root)
	if created!=OK: check(false,"Create the isolated save fixture"); game.free(); quit(1); return
	game.match_menu.config_path=c.save_root.path_join("settings.cfg")
	c.world={}
	await return_home()
	var menu=game.hud.home_menu
	check(menu.resume_slot==0 and menu.title(4)=="YENİ KARİYER","An empty career library offers a new career instead of a dead Continue button")
	var fits:=true
	var separate:=true
	for i in range(game.hud.nav_buttons.size()):
		var rect: Rect2=game.hud.nav_buttons[i].get_rect()
		fits=fits and game.ui.bounds().encloses(rect)
		for j in range(i): separate=separate and not rect.intersects(game.hud.nav_buttons[j].get_rect())
	check(fits and separate,"Every menu action fits one aligned column with no overlapping click targets")
	go(game.hud.nav_buttons[4]); tap(JOY_BUTTON_A); await settle()
	check(game.career_screen.page=="choose" and game.career_screen.save_slot==1 and not c.has_save(1),"New Career opens an empty slot without writing or overwriting a save")
	await return_home()
	check(c.new_career("c36",2),"Create a separate real save for the resume path")
	# Cold start: the card must come from disk, not the currently loaded world.
	c.world={}; c.slot=1
	await return_home()
	check(menu.resume_slot==2 and menu.summary.name=="MADRID AURORA" and menu.title(4)=="KARİYERE DEVAM ET","The saved club, date and resume action appear after returning home")
	var file:=FileAccess.open(c.path_for(2),FileAccess.READ)
	var original:=file.get_buffer(file.get_length()); file.close()
	click(game.hud.nav_buttons[4].get_global_transform_with_canvas()*(game.hud.nav_buttons[4].size*.5))
	await settle()
	check(game.career_screen.visible and game.career_screen.page=="hub" and c.world.user=="c36" and c.slot==2,"Mouse activation resumes the saved career directly into its hub")
	file=FileAccess.open(c.path_for(2),FileAccess.READ)
	var after:=file.get_buffer(file.get_length()); file.close()
	check(original==after,"Resuming does not rewrite the saved career")
	c.world.date+=3
	await return_home()
	check(menu.summary.date==c.world.date,"The current session card includes progress since its last save")
	go(game.hud.nav_buttons[4]); tap(JOY_BUTTON_A); await settle()
	check(c.world.date==menu.summary.date and game.career_screen.page=="hub","Controller Continue preserves the current session instead of loading an older copy")
	await return_home()
	go(game.hud.nav_buttons[5]); tap(JOY_BUTTON_A); await settle()
	check(game.career_screen.page=="entry" and c.has_save(2),"New / Saves keeps all three career slots accessible")
	await return_home()
	check(c.save(),"A second save creates a valid recovery copy")
	# A corrupt primary must use the same backup recovery as the career picker.
	file=FileAccess.open(c.path_for(2),FileAccess.WRITE); file.store_string("broken"); file.close()
	c.world={}
	await return_home()
	check(menu.resume_slot==2,"The main menu recognizes a valid backup when the primary file is damaged")
	go(game.hud.nav_buttons[4]); key(KEY_ENTER); await settle()
	check(game.career_screen.page=="hub" and c.error.contains("Yedek"),"Keyboard Continue restores the backup and shows the existing recovery message")
	await return_home()
	go(game.hud.nav_buttons[2]); tap(JOY_BUTTON_A); await settle(); tap(JOY_BUTTON_B); await settle()
	check(focus()==game.hud.nav_buttons[2],"Returning from Settings keeps focus on the same main-menu action")
	print("HOME MENU CHECK: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(1 if failures else 0)
