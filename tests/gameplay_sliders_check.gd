extends SceneTree
## Six difficulty levels over the tuned tables and FIFA-style gameplay sliders
## for the user's side and the CPU side, including persistence.
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-gameplay-sliders.cfg"
	var m=game.management
	# Levels keep the three legacy tiers exactly and interpolate between them.
	check(game.MatchSettings.LEVELS.size()==6,"Six named opponent levels are offered")
	m.difficulty=0; check(m.level==0 and is_equal_approx(m.pick([1.7,1.05,.58]),1.7),"Legacy Easy is Başlangıç with the Easy table")
	m.difficulty=1; check(m.level==2 and is_equal_approx(m.pick([1.7,1.05,.58]),1.05),"Legacy Normal is Yarı Profesyonel with the Normal table")
	m.difficulty=2; check(m.level==4 and is_equal_approx(m.pick([1.7,1.05,.58]),.58),"Legacy Hard is Dünya Klası with the Hard table")
	m.level=3
	var professional: float=m.pick([1.7,1.05,.58])
	check(m.difficulty==1 and professional<1.05 and professional>.58,"Profesyonel sits between Normal and Hard")
	m.level=5
	check(m.difficulty==2 and m.pick([1.7,1.05,.58],.34)<.58 and m.pick([1.7,1.05,.58],.34)>=.34,"Efsane reacts faster than Dünya Klası within a bounded floor")
	check(m.pick([0.045,0.012,0.0],0.0)==0.0,"No level adds negative aim noise")
	var settings: Dictionary=game.MatchSettings.normalized({"half_minutes":4,"difficulty":2})
	check(settings.level==4 and settings.difficulty==2,"Older careers map their stored tier onto the new levels")
	check(game.MatchSettings.normalized({"level":1}).difficulty==0,"A stored level derives its legacy tier")
	m.level=2
	# Sliders: the defaults change nothing.
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false); game.hud.hide()
	game.sliders.reset(); game.sliders.apply()
	var p=game.players[9]
	var cpu=game.players[20]
	check(p.sprint_scale==1.0 and cpu.sprint_scale==1.0 and game.strike_quality.shot_error_scale==[1.0,1.0],"Default sliders leave the tuned game unchanged")
	p.active_sprint=true; cpu.active_sprint=true; p.energy=1; cpu.energy=1
	cpu.attributes=p.attributes.duplicate(); cpu.match_fatigue=0; p.match_fatigue=0
	var base_speed: float=p.movement_speed()
	game.sliders.set_value(0,"sprint_speed",1.0)
	check(p.movement_speed()>base_speed*1.1 and is_equal_approx(cpu.movement_speed(),base_speed),"The user's sprint slider changes only the user's side")
	game.sliders.set_value(1,"shot_error",0.0)
	check(game.strike_quality.shot_error_scale[1]<.5 and game.strike_quality.shot_error_scale[0]==1.0,"The CPU shot-error slider scales only the CPU contact cone")
	var plan_before: int=m.detail(0,"runs")
	game.sliders.set_value(0,"runs",1.0)
	check(m.detail(0,"runs")==mini(2,plan_before+1),"A high run-frequency slider sends more runners in behind")
	game.sliders.set_value(0,"line_height",1.0)
	check(is_equal_approx(game.sliders.offset(0,"line_height",6),6.0),"The line-height slider moves the defensive line by up to six metres")
	# Persistence.
	game.match_menu.save_settings()
	game.sliders.reset()
	game.match_menu.load_settings()
	check(is_equal_approx(game.sliders.values[0].sprint_speed,1.0) and is_equal_approx(game.sliders.values[1].shot_error,0.0) and game.sliders.values[0].runs==1.0,"Sliders survive a settings round trip")
	m.level=5; game.match_menu.save_settings(); m.level=0; game.match_menu.load_settings()
	check(m.level==5,"The chosen level survives a settings round trip")
	# The settings screen offers the section.
	game.match_menu.open_menu(); game.match_menu.show_page(5)
	check(game.match_menu.navigation.size()==6 and game.match_menu.fields.size()>=23,"The OYNANIŞ section lists the level and both slider sets")
	game.match_menu.close_menu()
	game.sliders.reset(); game.sliders.apply(); m.level=2; game.match_menu.save_settings()
	print("GAMEPLAY SLIDERS CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
