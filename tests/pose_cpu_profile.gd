extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/footballer.gd")
	source+="\nvar pose_probe: Dictionary={}\nvar pose_started: int=0\nfunc pose_mark(label: String) -> void:\n\tvar now := Time.get_ticks_usec()\n\tif label!=\"start\":\n\t\tif not pose_probe.has(label): pose_probe[label]=[0,0]\n\t\tpose_probe[label][0]+=now-pose_started; pose_probe[label][1]+=1\n\tpose_started=now\n"
	var marks := {"func animate(delta: float) -> void:\n":"start","\tlocomotion.apply_pose(self,gait,stride)\n":"base-locomotion","\tcelebration_motion.apply(self,delta)\n":"actions","\tbody_language.apply_pose(self)\n":"body-language","\tlocomotion.finish_pose(self)\n":"foot-plant","\tmotion_transition.apply(self,delta)\n":"transition","\tball_actions.finish_pose(self)\n":"boot-contact","\tkeeper_motion.apply(self)\n":"carry-keeper","\tupdate_cloth()\n":"reaction-gaze-cloth"}
	for needle in marks:
		assert(source.contains(needle)); source=source.replace(needle,needle+"\tpose_mark(\""+marks[needle]+"\")\n")
	var player_script := GDScript.new(); player_script.source_code=source; assert(player_script.reload()==OK)
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd").replace('const Player = preload("res://scripts/footballer.gd")','var Player = preload("res://scripts/footballer.gd")')
	var game_script := GDScript.new(); game_script.source_code=game_source; assert(game_script.reload()==OK)
	var game=game_script.new(); game.Player=player_script; root.add_child(game); await physics_frame
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false); game.menu_match.running=true
	for tick in range(1200):
		game.simulate_match(1.0/120); game._process(1.0/120); await physics_frame
	var totals: Dictionary={}
	for p in game.players:
		for key in p.pose_probe:
			if not totals.has(key): totals[key]=[0,0]
			totals[key][0]+=p.pose_probe[key][0]; totals[key][1]+=p.pose_probe[key][1]
	for key in totals: print(key," mean_us=",float(totals[key][0])/totals[key][1]," calls=",totals[key][1])
	game.free(); quit()
