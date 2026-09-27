extends SceneTree
const Progress=preload("res://scripts/legend_progression.gd")
const World=preload("res://scripts/career_world.gd")
var game
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func development() -> void:
	for position in range(Progress.POSITIONS.size()):
		var p:={"id":"hero","name":"YILDIZ","role":Progress.ROLES[position],"attributes":Progress.initial_attributes(position,0),"potential":92,"fitness":1.0}
		var overall:=World.ovr(p)
		check(overall>=48 and overall<=58 and p.attributes.preferred_foot==0,"Low initial rating and selected foot: "+Progress.POSITIONS[position])
		var d:=Progress.create_data("hero",position,0)
		var rival: Dictionary=p.duplicate(true)
		check(not Progress.selection(d,p,rival).starter,"A new player begins on the bench even at a weak club")
		var before: Dictionary=p.attributes.duplicate(true)
		for n in range(3): Progress.training(d,p,0,85,Progress.SKILLS[position],"fixture")
		check(d.sessions==3 and Progress.training(d,p,0,100,Progress.SKILLS[position],"fixture").is_empty(),"Three sessions cannot be farmed by reopening training")
		check(not d.xp.is_empty() and d.trust<60,"A good session stores individual attribute progress without granting a starting place")
		for week in range(1,36):
			for n in range(3): Progress.training(d,p,week*7,80,Progress.SKILLS[position],"fixture")
		var growth:=World.ovr(p)-overall
		print("SEASON GROWTH ",Progress.SHORT[position]," +",growth," OVR")
		check(growth>=6 and growth<=18 and World.ovr(p)<80,"One strong training season develops a prospect without creating an instant superstar")
		d.games=5; d.trust=80; d.form=7.5
		check(Progress.selection(d,p,rival).starter,"Sustained trust, appearances and ability earn a starting place")
		for key in World.Talent.STATS: rival.attributes[key]=90
		check(not Progress.selection(d,p,rival).starter,"Elite competition still blocks an underqualified starter")
		if position>0:
			d.learning=1 if position!=1 else 5; d.positions[str(int(d.learning))]=0.0
			for n in range(8): Progress.training(d,p,280+(n/3)*7,80,Progress.SKILLS[position],"fixture")
			check(d.learning==-1 and d.positions.size()==2,"A second position requires multiple successful sessions")
		var row:={"minutes":25,"rating":8.0,"goals":1,"assists":0}
		var trust: float=d.trust
		Progress.match_result(d,p,"match-1",row,false)
		var updated: Dictionary=d.duplicate(true)
		check(d.trust>trust and d.games==6,"A strong substitute performance increases trust and experience")
		check(Progress.match_result(d,p,"match-1",row,false).is_empty() and d==updated,"The same fixture cannot award progression twice")
		Progress.match_result(d,p,"match-2",{"minutes":70,"rating":4.8,"red":true},true)
		check(d.trust<updated.trust,"Poor play and a red card reduce coach trust")

func run() -> void:
	development()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	var l=game.legend; var manager=game.career
	var folder:="/tmp/sefc-legend-check-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	manager.save_root=folder; l.career.save_root=folder; game.match_menu.config_path=folder.path_join("settings.cfg")
	check(manager.new_career("c00",1),"Create an independent manager save")
	var file:=FileAccess.open(manager.path_for(1),FileAccess.READ); var original:=file.get_buffer(file.get_length()); file.close()
	l.open(); game.legend_screen.choose(1)
	check(game.legend_screen.visible and game.legend_screen.page=="create" and not l.career.has_save(1),"Legend creation is reachable without overwriting manager saves")
	check(l.create("c18",1,{"name":"Deniz Efsane","position":7,"foot":0,"height":176,"weight":67,"appearance":35},{"half_minutes":1,"level":1}),"Create a named left-footed winger at the chosen club")
	check(l.active() and l.career.valid(l.career.world) and l.player().name=="DENİZ EFSANE" and l.player().height_cm==176,"Created identity, physique and save schema agree")
	check(l.career.path_for(1)!=manager.path_for(1) and l.career.has_save(1),"Player career uses separate save slots")
	file=FileAccess.open(manager.path_for(1),FileAccess.READ); check(file.get_buffer(file.get_length())==original,"Manager save is unchanged"); file.close()
	check(not l.selection.starter and l.player().id not in l.career.club().lineup,"The created player is not silently placed in the starting eleven")
	var xp: Dictionary=l.data().xp.duplicate(true)
	l.career.director.gain(l.player(),9999)
	check(l.data().xp==xp and l.player().development.gains==0,"Manager passive growth cannot duplicate personal training rewards")
	check(l.train("passing"),"Start a real scored training drill with the created player")
	check(game.training and game.players[9].career_id==l.player().id and game.player_lock,"Training controls the created footballer with his actual abilities")
	var reward: Dictionary=l.career.training.finish(85)
	check(reward.get("score",0)==85 and l.data().sessions==1 and not l.data().xp.is_empty(),"Finishing a real training session persists personal XP")
	check(l.career.training.finish(100).is_empty() and l.data().sessions==1,"A duplicate training completion grants no reward")
	l.career.training.leave()
	check(game.legend_screen.visible and game.legend_screen.page=="training" and not game.training,"Training returns to the personal career rather than a manager screen")
	check(l.learn(5) and not l.learn(9) and not l.prefer(5),"Only one new position can be learned at a time; unfinished positions cannot be selected")
	var saved: Dictionary=l.data().duplicate(true); var stats: Dictionary=l.player().attributes.duplicate(true)
	l.career.save(); l.career.world={}
	check(l.career.load_slot(1) and l.data()==saved and l.player().attributes==stats,"Save/load preserves XP, trust, foot and partially learned positions")
	for malformed in [{"position":99},{"trust":"invalid"},{"sessions":1.5},{"form":INF},{"xp":{"passing":100}}]:
		var broken: Dictionary=l.career.world.duplicate(true); broken.legend.merge(malformed,true)
		check(not l.career.valid(broken),"Malformed progression data is rejected: "+str(malformed.keys()))
	check(not l.career.sale_allowed(l.player().id),"The AI transfer market cannot sell the controlled footballer away")
	var fixture: Dictionary=l.career.next_fixture(); l.career.world.date=fixture.day
	game.legend_screen.open_hub()
	check(l.play(),"Begin the fixture from the personal career")
	check(l.match_active() and not l.on_pitch() and game.player_lock and not game.is_user_player(9),"A benched player cannot secretly control a teammate")
	check(game.management.bench[0].any(func(p): return p.get("career_id","")==l.player().id),"Low-rated created player is explicitly included among the match substitutes")
	check(game.autonomous_kicks(0),"Teammates play and shoot autonomously while the user is on the bench")
	l.live.skip_bench()
	check(game.match_time>game.LENGTH*.6 and game.half==2 and not game.management.transit.is_empty(),"Skipping the bench simulates only the prefix and starts a real substitution")
	var state_before: Array=[game.match_time,game.score.duplicate(),game.management.transit.duplicate(true)]
	l.live.skip_bench()
	check([game.match_time,game.score,game.management.transit]==state_before,"Repeated bench skip cannot replay goals or restart the incoming substitution")
	var pad:=InputEventJoypadButton.new(); pad.device=0; pad.button_index=JOY_BUTTON_X; pad.pressed=true
	game.state="playing"; game.handle_input(pad)
	check(not game.charging,"Gamepad cannot shoot as a teammate while waiting for a substitution")
	game.state="restart"; game.pace.substitutions_ready()
	for n in range(240):
		game.management.update_substitutions(1.0/60)
		if l.on_pitch(): break
	check(l.on_pitch() and game.players[game.controlled].career_id==l.player().id,"Control follows the incoming identity when the substitution completes")
	if not l.on_pitch():
		print("ENTRY DEBUG ",game.management.transit," ",game.management.bench[0]); game.free(); quit(1); return
	var controlled: int=game.controlled
	game.team_control.select((controlled+1)%11,true); game.switch_player()
	check(game.controlled==controlled,"Manual and automatic selection cannot leave the created player")
	game.reset_positions(1)
	check(game.controlled==controlled,"Goal and halftime resets retain the created player's control immediately")
	check(l.live.result().rating==6,"A substitute enters with a neutral rating before a position sample exists")
	game.state="playing"; game.kick_lock=0; game.dribbler=6 if controlled!=6 else 7
	game.ball.place(game.players[game.dribbler].position+Vector3(0,.23,-.3)); game.clear_pass_request()
	game.begin_pass()
	check(game.requested_receiver==controlled,"The normal pass button requests the ball off the ball")
	var passer: int=game.dribbler
	for i in range(22): game.players[i].position=Vector3(30,0,35+i*.3)
	game.players[controlled].position=Vector3(0,0,-8); game.players[passer].position=Vector3.ZERO
	game.players[passer].touch_cooldown=0; game.players[passer].action_timer=0
	game.ball.place(Vector3(0,.23,-.4)); game.kick_lock=0; game.request_age=.4
	check(game.try_requested_pass(passer) and game.incoming_receiver==controlled,"A teammate actually answers an open pass request")
	game.kick_contact.reset()

	game.begin_restart("SERBEST VURUŞ",0,Vector3(-8,0,-25))
	check(game.controlled==controlled and game.set_pieces.human_restart()==(game.set_pieces.taker==controlled),"A teammate's free kick remains AI-controlled without stealing the user's player")
	game.state="playing"; game.players[controlled].visible=true
	var finale=game.finale
	finale.begin_shootout({"stage":1})
	finale.shooter=game.players[passer]; finale.keeper=game.players[11]; finale.phase="ready"; finale.age=3
	check(not finale.user_shooter() and not finale.user_keeper(),"Another player's shootout turn is fully AI-controlled")
	finale.update(.01)
	check(finale.phase=="flight","A teammate takes his penalty without waiting for human input")
	finale.shooter=game.players[controlled]; finale.phase="ready"; finale.age=3
	finale.update(.01)
	check(finale.user_shooter() and finale.phase=="ready","The created player's own penalty waits for his input")
	finale.reset(); game.state="playing"
	l.live.position_time=20; l.live.good_position=18; l.live.completed=9; l.live.passes=10
	var row: Dictionary=game.match_report.player(game.players[controlled]); row.goals=1
	game.match_time=game.LENGTH; game.score=[1,0]; l.career.match_goals[l.player().id]=1
	game.match_report.finish(); game.state="finished"
	check(l.career.finish_match() and l.data().games==1 and l.data().last.minutes<40,"Finishing counts the substitute's actual minutes and awards a personal report")
	check(l.data().last.rating>7 and l.data().trust>22,"Successful passing, positioning and a goal improve the player's career")
	game.career_screen.open_hub()
	check(game.legend_screen.visible and game.legend_screen.page=="hub","The match report returns to the player career hub")
	game.legend_screen.close()
	check(game.career==manager and not l.match_active() and not game.player_lock,"Returning to the main menu restores normal team control and manager context")
	print("LEGEND CAREER CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
