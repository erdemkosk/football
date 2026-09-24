extends SceneTree
const Settings=preload("res://scripts/match_settings.gd")
const Clock=preload("res://scripts/match_clock.gd")
const DT := 1.0/120.0
var game
var checks := 0
var failures := 0
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func tap(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventJoypadButton.new()
		event.device=0; event.button_index=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()

func capture(label: String) -> void:
	if not visual: return
	for frame in range(35): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/football-duration-"+label+".png")

func reach(target: Control) -> bool:
	var codes: Array=[JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]
	var sides: Array=[SIDE_TOP,SIDE_BOTTOM,SIDE_LEFT,SIDE_RIGHT]
	var pending: Array=[[root.gui_get_focus_owner(),[]]]
	var seen: Array=[]
	while not pending.is_empty():
		var item: Array=pending.pop_front(); var current: Control=item[0]
		if current==target:
			for code in item[1]: tap(code)
			return root.gui_get_focus_owner()==target
		if current==null or current in seen: continue
		seen.append(current)
		for i in range(4):
			if current is OptionButton and i>=2: continue
			var next: Control=current.find_valid_focus_neighbor(sides[i])
			if next!=null and not next in seen: pending.append([next,item[1]+[codes[i]]])
	return false

func tick() -> void:
	game._physics_process(DT)
	await physics_frame

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.playtest.enabled=false; game.controller.device=0
	var folder: String="/tmp/football-duration-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	game.match_menu.config_path=folder.path_join("settings.cfg")
	game.career.save_root=folder
	game.quick_half_minutes=2; game.management.difficulty=0
	game.frontend.open_selection()
	game.frontend.duration_button.grab_focus(); tap(JOY_BUTTON_A)
	check(game.quick_half_minutes==4 and root.gui_get_focus_owner()==game.frontend.duration_button,"Controller selects quick-match duration and retains focus")
	await capture("quick-match")
	game.match_menu.save_settings()
	game.quick_half_minutes=20; game.match_menu.load_settings()
	check(game.quick_half_minutes==4,"Quick-match duration survives settings save and reload")
	game.frontend.hide(); game.frontend.clear_controls()
	for minutes in Settings.HALF_MINUTES:
		game.quick_half_minutes=minutes; game.start_match(false,false)
		game.opponent_coach.next_sub=INF
		check(game.LENGTH==minutes*120 and Clock.text(game.LENGTH*.5,game.LENGTH,1)=="45:00" and Clock.text(game.LENGTH,game.LENGTH)=="90:00","%d-minute halves map to a full 90-minute match" % minutes)
		game.match_time=game.LENGTH*.5-DT*.5
		await tick()
		check(game.state=="halftime" and game.match_time==minutes*60,"The first-half whistle follows the chosen %d-minute duration" % minutes)
		game.interval.finish()
		game.state="playing"; game.match_time=game.LENGTH-DT*.5
		await tick()
		check(game.state=="finished" and game.match_time==minutes*120,"Full time follows the chosen %d-minute duration" % minutes)
	game.quick_half_minutes=10; game.start_match(false,false)
	var p=game.players[9]
	p.desired=Vector3.FORWARD; p.sprinting=true; p.action_timer=0
	p.update_stamina(1)
	var long_energy: float=p.energy; var long_fatigue: float=p.match_fatigue
	game.quick_half_minutes=2
	check(game.LENGTH==1200,"Changing a preference cannot change the current match clock")
	game.start_match(false,false)
	p.desired=Vector3.FORWARD; p.sprinting=true; p.action_timer=0; p.update_stamina(1)
	check(is_equal_approx(p.energy,long_energy) and is_equal_approx(p.match_fatigue,long_fatigue*5),"Sprint energy stays responsive while cumulative fatigue follows match length")
	p.reset_stamina(); p.sprinting=false; p.update_stamina(120)
	var short_running_energy: float=p.energy; var short_running_fatigue: float=p.match_fatigue
	game.quick_half_minutes=10; game.start_match(false,false)
	p.desired=Vector3.FORWARD; p.sprinting=false; p.action_timer=0; p.update_stamina(600)
	check(is_equal_approx(p.energy,short_running_energy) and is_equal_approx(p.match_fatigue,short_running_fatigue),"Normal running has the same gradual fitness cost over either length of half")
	game.match_time=game.LENGTH*.5-1; game.management.lost_time[0]=30
	game.management.update_clock(DT)
	check(is_equal_approx(game.management.added[0],game.LENGTH/90*3) and Clock.text(game.LENGTH*.5+game.management.added[0],game.LENGTH,1)=="45+3","Added time uses whole displayed minutes at the selected duration")
	check(Clock.text(game.LENGTH*7/6,game.LENGTH,1,true)=="105:00" and Clock.text(game.LENGTH*4/3,game.LENGTH,2,true)=="120:00","Extra-time clocks scale with the match duration")
	game.return_menu(); game.quick_half_minutes=4; game.management.difficulty=0
	var ui=game.career_screen; var c=game.career
	ui.open_entry(); ui.choose(1)
	check(reach(ui.duration_option),"Career duration is reachable through directional navigation")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(reach(ui.difficulty_option),"Career difficulty is reachable through directional navigation")
	# Six levels: four steps right of Başlangıç reach Dünya Klası (the old Hard tier).
	for step in range(4): tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.new_match_settings=={"half_minutes":6,"difficulty":2,"level":4},"Career creation offers independent duration and difficulty through the controller")
	ui.selected_club="c18"; ui.build()
	check(ui.duration_option.selected==2 and ui.difficulty_option.selected==4,"Changing the selected club preserves both career choices")
	await capture("career-start")
	ui.begin()
	check(c.world.match_settings=={"half_minutes":6,"difficulty":2,"level":4} and ui.page=="hub","Starting a career saves its selected duration and difficulty")
	ui.close()
	check(game.quick_half_minutes==4 and game.management.difficulty==0,"Leaving the career preserves independent quick-match preferences")
	check(c.load_slot(1) and c.world.match_settings=={"half_minutes":6,"difficulty":2,"level":4},"Career settings survive loading from disk")
	c.world.date=c.next_fixture().day
	check(c.prepare_match() and game.management.difficulty==2,"Career match preparation uses the career's difficulty")
	game.frontend.confirm()
	check(game.LENGTH==720 and game.management.difficulty==2,"The actual career match uses six-minute halves and Hard difficulty")
	game.match_menu.change_difficulty(2); game.match_menu.save_settings()
	var cfg:=ConfigFile.new(); cfg.load(game.match_menu.config_path)
	check(cfg.get_value("tactics","difficulty")==0 and cfg.get_value("match","half_minutes")==4,"Saving settings during a career cannot overwrite quick-match choices")
	game.return_menu()
	check(c.load_slot(1) and c.world.match_settings=={"half_minutes":6,"difficulty":1,"level":2},"An in-match career difficulty change stays with that career")
	c.new_career("c00",2,{"half_minutes":20,"difficulty":0})
	check(c.load_slot(1) and c.world.match_settings.half_minutes==6 and c.load_slot(2) and c.world.match_settings.half_minutes==20,"Separate career slots retain their own match lengths")
	c.world.erase("match_settings"); c.save()
	check(c.load_slot(2) and c.world.match_settings=={"half_minutes":2,"difficulty":1,"level":2},"Older careers without these fields load safely with the original match length")
	c.world.match_settings={"half_minutes":-900,"difficulty":"invalid"}; c.save()
	check(c.load_slot(2) and c.world.match_settings=={"half_minutes":2,"difficulty":1,"level":2},"Invalid stored choices fall back to playable defaults")
	game.quick_half_minutes=20; game.start_match(true)
	check(game.training and game.state=="playing","Practice still starts immediately")
	game.return_menu()
	check(game.LENGTH==240 and game.quick_half_minutes==20,"The menu exhibition keeps its short cycle without erasing the quick-match preference")
	print("MATCH DURATION: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
