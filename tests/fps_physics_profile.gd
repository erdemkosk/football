extends SceneTree
## Instrument an in-memory copy; shipping match code has no profiling branches.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	source=source.replace('const Player = preload("res://scripts/footballer.gd")','var Player = preload("res://scripts/footballer.gd")')
	var player_source := FileAccess.get_file_as_string("res://scripts/footballer.gd")
	player_source+="\nvar probe: Dictionary={}\nvar probe_last: int=0\nfunc probe_mark(label: String) -> void:\n\tvar now := Time.get_ticks_usec()\n\tif label!=\"start\":\n\t\tif not probe.has(label): probe[label]=[0,0]\n\t\tprobe[label][0]+=now-probe_last; probe[label][1]+=1\n\tprobe_last=now\n"
	var player_marks := {"func step(delta: float,stoppage_speed: float=0.0) -> void:\n":"start","\t\tstain(delta)\n":"timers-weather","\tvar travel_velocity := velocity\n":"steering","\tmove_and_slide()\n":"body-physics","\tlocomotion.update(self,delta,last_horizontal)\n":"facing-locomotion","\tbody_language.update(self,delta)\n":"body-language","\treaction.update(self,delta)\n":"ball-actions","\tanimate(delta)\n":"animation","\tif is_instance_valid(surface): surface.player_step(self,delta)\n":"footprints"}
	for needle in player_marks:
		assert(player_source.contains(needle))
		player_source=player_source.replace(needle,needle+"\tprobe_mark(\""+player_marks[needle]+"\")\n")
	var player_script := GDScript.new(); player_script.source_code=player_source; assert(player_script.reload()==OK)
	source+="\nvar probe_times: Dictionary={}\nvar probe_last: int=0\nfunc probe_mark(label: String) -> void:\n\tvar now := Time.get_ticks_usec()\n\tif label!=\"start\":\n\t\tif not probe_times.has(label): probe_times[label]=[0,0]\n\t\tprobe_times[label][0]+=now-probe_last; probe_times[label][1]+=1\n\tprobe_last=now\n"
	var marks := {
		"func _physics_process(delta: float) -> void:\n":"start",
        "\tfor channel in audio.contacts: channel.stream_paused=state==\"paused\"\n":"audio",
		"\t\tsecond_balls.update(delta)\n":"preparation",
		"\t\tupdate_ai(delta)\n":"ai",
		"\t\tkick_contact.prepare(delta)\n":"contact-preparation",
		"\t\tfor i in range(players.size()): players[i].body_language.observe(self,i)\n":"body-language",
		"\t\tduels.resolve(delta)\n":"players-step",
		"\t\tkick_contact.resolve()\n":"resolve",
		"\t\tupdate_contacts(delta)\n":"contacts",
		"\t\tcheck_boundaries()\n":"replay-boundaries"
	}
	for needle in marks:
		assert(source.contains(needle))
		var indent := "\t" if marks[needle] in ["start","audio"] else "\t\t"
		source=source.replace(needle,needle+indent+"probe_mark(\""+marks[needle]+"\")\n")
	var script := GDScript.new(); script.source_code=source
	assert(script.reload()==OK)
	var game=script.new(); game.Player=player_script; root.add_child(game); await physics_frame
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.menu_match.running=true; game.management.difficulty=2; game.weather.select(0,true)
	for tick in range(1200):
		game._physics_process(1.0/120); game._process(1.0/120); await physics_frame
	for key in game.probe_times:
		var row: Array=game.probe_times[key]
		print(key,": ",float(row[0])/row[1]," us (",row[1]," samples)")
	var players: Dictionary={}
	for p in game.players:
		for key in p.probe:
			if not players.has(key): players[key]=[0,0]
			players[key][0]+=p.probe[key][0]; players[key][1]+=p.probe[key][1]
	for key in players: print("player ",key,": ",float(players[key][0])/players[key][1]," us")
	game.free(); quit()
