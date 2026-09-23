extends SceneTree
var game
var front
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)

func tap(code: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device=0; event.button_index=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()

func ratings() -> Dictionary:
	var values := {}
	for kind in ["slot","bench"]:
		for i in range(11 if kind=="slot" else 7):
			var data: Dictionary=front.player_data(kind,i)
			values[data.shirt]=data.ovr
	return values

func choose(kind: String,index: int) -> void:
	front.focus_tactics(kind+":"+str(index)); tap(JOY_BUTTON_A)

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	for i in range(180):
		await process_frame
		if front.portraits.pending.is_empty() and front.portraits.studio==null and i>8: break
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/tactics-swap-"+label+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0
	front=game.frontend; front.open_selection(); front.open_tactics(true)
	var original: Array=game.clubs.lineups[0].duplicate()
	var original_bench: Array=game.clubs.reserves[0].duplicate()
	var original_ratings := ratings()
	# A defender whose correct overall is 83 must not use midfielder weights on the pitch.
	var attributes := {"defending":97,"strength":80,"pace":70,"passing":60,"heading":87,"control":60,"stamina":65,"finishing":55}
	for label in ["STP","SLB","SĞB","MO","SF"]:
		check(front.rating_of({"attributes":attributes,"natural_group":1,"role":label})==83,"Defender 83 keeps the same overall with tactical label "+label)
	for formation in range(3):
		front.set_tactic("formation",formation)
		check(ratings()==original_ratings,"Changing formation preserves all individual ratings")
		choose("slot",1)
		tap(JOY_BUTTON_DPAD_RIGHT)
		check(root.gui_get_focus_owner()==front.slot_buttons[2] and front.swap_source.index==1,"Selected starter can navigate to another starter")
		tap(JOY_BUTTON_A)
		check(front.swap_stage=="confirm" and game.clubs.lineups[0]==original,"Pitch swap waits for explicit confirmation")
		if formation==0: await capture("positions")
		tap(JOY_BUTTON_A)
		check(game.clubs.lineups[0][1]==original[2] and game.clubs.lineups[0][2]==original[1],"Confirm exchanges the two on-pitch positions")
		check(ratings()==original_ratings and game.management.used[0]==0,"Pitch swap preserves ratings and substitution allowance")
		tap(JOY_BUTTON_X)
		check(game.clubs.lineups[0]==original,"Undo restores both on-pitch positions")
		choose("bench",2)
		check(front.swap_stage=="choose" and front.reserve_buttons[2].active and front.swap_source.kind=="bench","A reserve can be the first selection")
		tap(JOY_BUTTON_DPAD_UP)
		check(root.gui_get_focus_owner()==front.slot_buttons[0],"Bench-first selection can navigate onto the pitch")
		tap(JOY_BUTTON_A)
		check(front.swap_stage=="choose" and front.status.contains("Kaleci") and game.clubs.lineups[0]==original,"Incompatible goalkeeper target leaves the source selected")
		choose("slot",4)
		if formation==0: await capture("bench-first")
		var intended: Dictionary=front.swap_target.duplicate()
		front.slot_buttons[8].grab_focus()
		check(front.swap_target==intended and front.swap_source.index==2,"Browsing after confirmation does not silently change either chosen player")
		front.swap_action.grab_focus(); tap(JOY_BUTTON_A)
		check(game.clubs.lineups[0][4]==original_bench[2] and game.clubs.reserves[0][2]==original[4],"Bench-first confirmation swaps exactly the two selected players")
		check(ratings()==original_ratings,"Moving from bench to pitch preserves the player's natural-role overall")
		if formation==0: await capture("bench-first-applied")
		tap(JOY_BUTTON_X)
		choose("bench",1); tap(JOY_BUTTON_B)
		check(front.swap_stage=="browse" and root.gui_get_focus_owner()==front.reserve_buttons[1],"Cancel clears a bench-first selection and returns to that reserve")
		choose("slot",2); tap(JOY_BUTTON_A)
		check(front.swap_stage=="browse" and game.clubs.lineups[0]==original,"Selecting the same player twice deselects without changing the squad")
	front.set_tactic("formation",0)
	front.confirm(); game.ceremony.finish(true)
	game.state="playing"; game.ball.freeze=false; game.controlled=1; game.carrier=1; game.dribbler=1
	var first=game.players[1]; var second=game.players[9]
	first.energy=.32; first.yellow_cards=1
	second.energy=.84
	var first_home: Vector3=first.home; var second_home: Vector3=second.home
	var first_position: Vector3=first.position; var second_position: Vector3=second.position
	var first_identity: Dictionary=first.identity()
	game.management.used[0]=3
	front.open_tactics(false)
	choose("slot",1); choose("slot",9); tap(JOY_BUTTON_A)
	check(game.players[1]==first and game.players[9]==second and first.identity()==first_identity,"Live position swap retains actor identity and attributes")
	check(first.number==10 and second.number==2 and first.home==second_home and second.home==first_home,"Live position swap changes tactical assignments and AI home positions")
	check(first.position==first_position and second.position==second_position,"Players are not teleported during a live position swap")
	check(first.energy==.32 and first.yellow_cards==1 and second.energy==.84,"Live swap preserves condition and discipline")
	check(game.carrier==1 and game.dribbler==1 and game.controlled==1,"Ball possession and controlled player keep their actor references")
	check(game.management.used[0]==3 and game.management.pending.is_empty(),"Position swaps remain available after all three substitutions")
	check(game.management.slot_role(1)==3 and game.management.slot_role(9)==1,"AI role queries follow the new tactical assignments")
	check(front.slot_buttons[1].position.y<front.slot_buttons[9].position.y,"Tactics cards follow the swapped live positions")
	front.slot_buttons[1].grab_focus(); tap(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner()==front.slot_buttons[10],"Live navigation follows visual pitch order after a position swap")
	tap(JOY_BUTTON_X)
	check(first.number==2 and first.home==first_home and game.management.used[0]==3,"Undo restores live positions without restoring or spending substitutions")
	game.management.used[0]=0
	game.management.queue_sub(1,3)
	front.build()
	choose("slot",9); choose("slot",1); tap(JOY_BUTTON_A)
	check(game.management.pending.size()==1 and game.management.pending[0].slot==1 and game.players[1]==first,"A queued substitution remains attached to the same player after a position swap")
	tap(JOY_BUTTON_X)
	check(game.management.pending.size()==1 and first.number==2,"Undoing a position swap does not cancel an independent pending substitution")
	game.management.pending.clear(); front.history.clear()
	first.dismissed=true
	check(not game.management.swap_positions(1,9),"Dismissed players cannot be repositioned")
	first.dismissed=false; game.management.transit[1]={"reserve":2,"phase":"out"}
	check(not game.management.swap_positions(1,9),"A player in a substitution animation cannot be repositioned")
	game.management.transit.clear()
	check(not game.management.swap_positions(0,9),"Goalkeeper cannot be moved into an outfield position")
	game.management.swap_positions(1,9); game.management.reset()
	check(game.players[1].number==2 and game.players[9].number==10,"New match reset restores initial tactical assignments")
	print("TACTICS SWAPS CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
