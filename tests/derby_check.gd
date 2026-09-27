extends SceneTree
const World=preload("res://scripts/career_world.gd")
const Rivals=preload("res://scripts/rivalries.gd")
const Pitch=preload("res://scripts/pitch_dimensions.gd")
var game
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func run() -> void:
	var world:=World.create()
	check(world.clubs.size()==110 and world.clubs.values().all(func(c): return not c.rivals.is_empty()),"Every one of the 110 clubs has a rival")
	var reciprocal:=true; var distinct:=true; var domestic:=true
	for id in world.clubs:
		for other in world.clubs[id].rivals:
			reciprocal=reciprocal and world.clubs.has(other) and id in world.clubs[other].rivals
			distinct=distinct and other!=id
			domestic=domestic and world.clubs[id].nation==world.clubs[other].nation
	check(reciprocal and distinct and domestic,"Every rivalry is reciprocal, distinct and within its association")
	check(Rivals.match_info("tr00","tr01").title=="BOĞAZ DERBİSİ" and Rivals.rivals("tr02").has("tr00") and Rivals.rivals("tr02").has("tr01"),"The fictional Istanbul clubs share their city rivalries")
	check(Rivals.match_info("c00","c01").is_empty() and Rivals.match_info("c82","c84").is_empty(),"An ordinary match, including a club named Derby, is not a rivalry by accident")
	check(Rivals.match_info("c00","c06").heat==Rivals.match_info("c06","c00").heat,"Reversing the fixture keeps the same rivalry intensity")
	var original: Dictionary=world.duplicate(true)
	world.clubs.c00.league=1; world.clubs.c00.name="RENAMED ROVERS"; Rivals.ensure(world)
	check(world.clubs.c00.rivals==original.clubs.c00.rivals,"Renaming and relegation preserve the club's historic rival")
	check(world.players==original.players and world.fixtures==original.fixtures and world.clubs.c00.cash==original.clubs.c00.cash,"Assigning supporter identities cannot change players, the calendar or finances")
	var names: Dictionary={}
	for c in world.clubs.values(): names[c.supporters.name]=true
	check(names.size()==110,"All clubs have distinct supporter-section names")
	for c in world.clubs.values(): c.erase("rivals"); c.erase("supporters")
	World.upgrade(world)
	check(world.clubs.values().all(func(c): return c.has("supporters") and not c.rivals.is_empty()),"Legacy worlds receive rivalries without requiring a new save")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.match_menu.config_path="/tmp/sefc-derby-settings.cfg"
	game.clubs.league=[0,0]; game.clubs.selected=[0,1]; game.clubs.apply()
	var c=game.career; c.save_root="/tmp/sefc-derby-check-"+str(OS.get_process_id()); DirAccess.make_dir_recursive_absolute(c.save_root)
	game.start_match(false,false)
	var crowd=game.stadium.crowd; var audio=game.audio
	crowd.context([0,0],0,game.LENGTH)
	var regular: float=crowd.home_support
	audio.drum_rng.seed=17; audio.schedule_chants(); var ordinary_wait: float=audio.chant_wait[0]
	check(not game.clubs.rivalry.active and audio.derby_heat==0 and not game.stadium.supporters.visible,"An ordinary match has no derby overlay or cloth display")
	check(game.clubs.choose_rival() and game.clubs.match_id(1)=="c06","One action selects the current club's primary rival")
	game.start_match(false,true)
	check(game.clubs.rivalry.active and game.ceremony.caption().contains("KIYI DERBİSİ"),"The actual opening ceremony announces the rivalry")
	crowd.context([0,0],0,game.LENGTH)
	check(crowd.home_support>regular+.15 and crowd.away_support>regular+.12,"Both supporter sections are livelier before the score or late-match pressure changes")
	audio.drum_rng.seed=17; audio.schedule_chants()
	check(audio.chant_wait[0]<ordinary_wait*.7,"Derby chants return sooner with the same random seed")
	game.stadium.supporters._process(1.5)
	check(game.stadium.supporters.visible and game.stadium.supporters.deployment>.95,"Opening cloth displays unfold in the real stadium")
	check(game.stadium.supporters.displays.all(func(d): return absf(d.root.position.x)>Pitch.HALF_WIDTH+3.6),"The cloth displays stay outside the playing field")
	var above_terrace:=true
	for d in game.stadium.supporters.displays:
		for y in [-6.0,6.0]:
			var edge: Vector3=d.root.transform*Vector3(0,y,0)
			var raised_hands: float=(absf(edge.x)-(39.5+Pitch.SIDE_SHIFT))*.56/.95+.525+2.0
			above_terrace=above_terrace and edge.y>raised_hands+.1
	check(above_terrace,"Deployed cloth sits above supporters and concrete, not buried inside the terrace")
	check(game.stadium.supporters.covered,"Opening the fabric enables the covered supporter-prop state")
	var attributes: Dictionary=game.players[9].attributes.duplicate(true)
	game.ceremony.finish(true); game.state="playing"
	check(game.players[9].attributes==attributes,"The rivalry does not secretly multiply player attributes")
	audio.cheer_duration=0; audio.cheer_cooldown=0; audio.chant_wait.assign([0.0,0.0,0.0])
	audio.update_chants(.1,"playing")
	check(audio.chanting()==1,"Derby sections answer each other without stacking three chants")
	var age: float=game.stadium.supporters.age; var chant_age: float=audio.chant_age[0]
	game.state="paused"; game.stadium.supporters._process(2); audio.update_atmosphere(2,"paused")
	check(game.stadium.supporters.age==age and audio.chant_age[0]==chant_age,"Pause freezes both the cloth choreography and supporter audio")
	game.state="playing"; audio.update_atmosphere(.1,"playing"); game.stadium.react("goal",1,Vector3.ZERO)
	crowd.update(.4,Vector3.ZERO,Vector3.ZERO,1,false,false)
	check(crowd.hush_team==0 and crowd.event_side==1,"An away goal celebrates in the away block and hushes the home end")
	audio.toggle()
	check(audio.chants.all(func(voice): return not voice.playing) and audio.ambience.volume_db<=-79,"Mute still silences the heightened derby atmosphere")
	audio.toggle()
	game.stadium.supporters.age=40; game.stadium.supporters._process(5)
	check(not game.stadium.supporters.visible,"The opening display folds away instead of staying up for the entire match")
	check(not game.stadium.supporters.covered and game.stadium.supporters.covered_props.all(func(prop): return prop.mesh.get_instance_transform(prop.index).is_equal_approx(prop.transform)),"The original supporter props return intact after the fabric folds")
	game.half=2; game.stadium.supporters.age=0; game.stadium.supporters._process(1)
	check(not game.stadium.supporters.visible,"The second half cannot trigger another opening choreography")
	game.start_match(true,false)
	check(not game.clubs.rivalry.active and audio.derby_heat==0 and crowd.derby_heat==0 and not game.stadium.supporters.visible,"Training clears every derby-specific effect")
	game.experience.reduce_motion=true; game.start_match(false,true); game.stadium.supporters._process(.01)
	check(game.stadium.supporters.deployment==1 and game.stadium.supporters.displays[0].material.get_shader_parameter("cloth_time")==0.0 and game.ceremony.camera_at.x>0,"Reduced motion holds the fabric still and keeps the standard entrance camera")
	game.experience.reduce_motion=false; game.start_match(false,false,true)
	check(not game.clubs.rivalry.active and audio.derby_heat==0 and not game.stadium.supporters.visible,"The background menu match suppresses rivalry presentation")
	# Career uses user-first actor indices even when the user plays away.
	c.new_career("tr00")
	var fixture: Dictionary=c.world.fixtures.filter(func(f): return f.home=="tr01" and f.away=="tr00")[0]
	c.world.fixtures.filter(func(f): return f.day<fixture.day and c.world.user in [f.home,f.away]).map(func(f): f.played=true; f.score=[0,0])
	c.world.date=fixture.day
	check(c.cups.fixture_label(fixture).begins_with("DERBİ"),"Career fixtures expose a derby marker")
	# Register the fixture and actor-side clubs directly, avoiding a full season simulation.
	c.in_match=true; c.fixture_id=fixture.id
	game.clubs.career_clubs=[c.club().duplicate(true),c.world.clubs.tr01.duplicate(true)]
	game.clubs.rivalry.begin(game,false,false)
	check(game.clubs.rivalry.home_team==1 and crowd.home_team==1 and audio.home_team==1,"An away career fixture identifies the actual home club despite user-first actor indices")
	check(crowd.home_kit.badge_primary==Color(c.world.clubs.tr01.primary) and game.stadium.supporters.profiles[0].name.begins_with("İHL"),"The stadium's dominant colours and home display belong to the actual host")
	crowd.reset(); crowd.context([1,0],game.LENGTH*.8,game.LENGTH); crowd.react("goal",0,Vector3.ZERO)
	check(crowd.event_side==1 and crowd.hush_team==0 and crowd.margin==-1,"A user goal on the road excites visitors rather than the home crowd")
	audio.start_match(true); audio.react("goal",0,Vector3.ZERO)
	check(audio.roar_level< -5 and audio.cheer_level< -12,"The audio also treats a user goal on the road as an away goal")
	check(c.save() and c.load_slot(1) and c.club().rivals.has("tr01"),"Derby identity survives career save and reload")
	game.clubs.clear_career(); game.clubs.league=[0,0]; game.clubs.selected=[0,1]; game.clubs.apply(); game.start_match(false,false)
	check(not game.clubs.rivalry.active and crowd.home_team==0 and audio.home_team==0 and audio.derby_heat==0,"A subsequent ordinary match cannot inherit the derby or old home-side mapping")
	print("DERBY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
