extends SceneTree
var game
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func button(code: int) -> void:
	for pressed in [true,false]:
		var e:=InputEventJoypadButton.new(); e.device=0; e.button_index=code; e.pressed=pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/refresh-"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.match_menu.config_path="res://tests/presentation-settings.tmp"
	if DisplayServer.get_name()!="headless":
		game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	game.controller.adopt_device(0,"Xbox Controller")
	game.training_menu.open_menu(); await capture("training")
	button(JOY_BUTTON_DPAD_RIGHT)
	check(game.training_menu.selected==1,"Controller selects the second visual training card")
	game.training_menu.close_menu()
	game.start_match(false,false); game.ball.freeze=true
	game.before_pause="playing"; game.state="paused"; game.hud.sync_navigation(); game.hud.queue_redraw()
	await capture("pause")
	check(game.hud.nav_buttons[0].has_focus(),"Pause defaults to resume")
	button(JOY_BUTTON_A)
	check(game.state=="playing","Pause confirmation resumes without a gameplay pass")
	game.ball.freeze=true; game.players[9].energy=.18; game.match_time=150
	game.coaching.update(.1)
	check(game.coaching.proposal_valid(),"Tired player receives a live substitution offer")
	button(JOY_BUTTON_BACK)
	check(game.coaching.offer_latched and game.coaching.opened,"View opens the offer without holding a trigger")
	game.hud.queue_redraw(); await capture("substitution")
	button(JOY_BUTTON_DPAD_RIGHT)
	check(game.coaching.offer_choice==1,"D-pad selects dismiss without changing team tactics")
	button(JOY_BUTTON_DPAD_LEFT); button(JOY_BUTTON_A)
	check(game.management.pending.size()==1 and not game.pass_charging and not game.ball.pending_kick,"Confirm queues exactly one substitution without passing")
	check(not game.coaching.offer_latched and game.coaching.consumed.is_empty(),"Confirmation restores control with no stuck buttons")
	game.state="restart"; game.management.prepare_substitutions()
	var identity: String=game.players[9].display_name
	var changed:=false
	for tick in range(3600):
		game.management.update_substitutions(1.0/120)
		if game.players[9].display_name!=identity: changed=true; break
		await physics_frame
	check(changed and not game.stadium.sidelines.departures.is_empty(),"Outgoing player remains visible at the touchline after replacement enters")
	if changed:
		check(game.stadium.sidelines.departures[0].player.display_name==identity,"The departing actor retains the outgoing identity")
	print("PRESENTATION REFRESH: failures=",failures)
	game.free(); quit(1 if failures else 0)
