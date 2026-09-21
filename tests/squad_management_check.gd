extends SceneTree
var game
var screen
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func settle() -> void:
	game.controller.menus.sync()
	for i in range(4): await process_frame
func tap(code: int) -> void:
	for down in [true,false]:
		var e := InputEventJoypadButton.new(); e.device=0; e.button_index=code; e.pressed=down
		Input.parse_input_event(e); Input.flush_buffered_events()
func mouse_button(at: Vector2,down: bool) -> void:
	at=root.get_final_transform()*at
	var e := InputEventMouseButton.new(); e.position=at; e.global_position=at
	e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down; e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e); Input.flush_buffered_events()
func motion(at: Vector2,from: Vector2,down: bool=false) -> void:
	var transform := root.get_final_transform()
	var e := InputEventMouseMotion.new(); e.position=transform*at; e.global_position=e.position
	e.relative=transform*at-transform*from; e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e); Input.flush_buffered_events()
func click(card: Control) -> void:
	var at := card.get_global_rect().get_center()
	motion(at,at); mouse_button(at,true); mouse_button(at,false)
	await settle()
func drag(source: Control,target: Control) -> void:
	var from := source.get_global_rect().get_center()
	var to := target.get_global_rect().get_center()
	motion(from,from); mouse_button(from,true)
	await process_frame
	motion(from+Vector2(20,-20),from,true)
	await process_frame
	motion(to,from+Vector2(20,-20),true)
	await process_frame
	check(root.gui_is_dragging(),"Mouse movement starts a native squad drag")
	mouse_button(to,false)
	await settle()
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	await settle(); RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/squad-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_physics_process(false); game.controller.device=0
	screen=game.frontend; screen.open_selection(); screen.open_tactics(true); await settle()
	var original: String=game.players[9].display_name
	var incoming: String=game.management.bench[0][2].name
	await click(screen.slot_buttons[9])
	check(screen.selected_slot==9 and root.gui_get_focus_owner()==screen.reserve_buttons[1],"Selecting a starter focuses the first eligible substitute")
	await click(screen.reserve_buttons[2])
	check(game.players[9].display_name==incoming and game.management.bench[0][2].name==original and game.management.used[0]==0,"Two real mouse clicks exchange starter and reserve without spending a match substitution")
	tap(JOY_BUTTON_X); await settle()
	check(game.players[9].display_name==original and screen.history.is_empty(),"Xbox X undoes a mouse substitution and restores both squad identities")
	screen.slot_buttons[8].grab_focus(); tap(JOY_BUTTON_A); await settle()
	check(root.gui_get_focus_owner()==screen.reserve_buttons[1],"Controller A selects the outgoing player and goes directly to an eligible reserve")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner()==screen.reserve_buttons[2] and screen.preview_reserve==2,"D-pad previews the next reserve in the comparison panel")
	tap(JOY_BUTTON_A); await settle()
	check(game.players[8].display_name==incoming and screen.history.size()==1,"Controller A completes the selected lineup change")
	tap(JOY_BUTTON_X); await settle()
	await drag(screen.reserve_buttons[2],screen.slot_buttons[9])
	check(game.players[9].display_name==incoming and screen.history.size()==1,"Dragging a reserve onto a starter completes exactly one swap")
	tap(JOY_BUTTON_X); await settle()
	await drag(screen.slot_buttons[9],screen.reserve_buttons[2])
	check(game.players[9].display_name==incoming and screen.history.size()==1,"Dragging a starter onto a reserve also completes exactly one swap")
	tap(JOY_BUTTON_X); await settle()
	var goalkeeper: String=game.players[0].display_name
	await drag(screen.reserve_buttons[2],screen.slot_buttons[0])
	check(game.players[0].display_name==goalkeeper and screen.history.is_empty(),"Invalid goalkeeper drag leaves the lineup unchanged")
	check(not screen.can_drop_player({"squad":screen.get_instance_id(),"kind":"bench"},"slot",9) and not screen.can_drop_player({"squad":-1,"kind":"bench","index":2},"slot",9),"Unrelated or incomplete drag payloads are ignored")
	for formation in range(3):
		screen.set_tactic("formation",formation)
		var clear := true
		for i in range(11):
			var rect: Rect2=screen.slot_buttons[i].get_global_rect()
			clear=clear and Rect2(78,208,810,404).encloses(rect)
			for j in range(i): clear=clear and not rect.intersects(screen.slot_buttons[j].get_global_rect())
		check(clear,"All eleven shirt cards remain inside the pitch without overlap, formation="+str(formation))
	await capture("352")
	screen.confirm(); game.ceremony.finish(true); game.set_physics_process(false)
	game.players[9].energy=0.22; game.players[9].yellow_cards=1
	game.players[6].energy=0.48; game.players[8].energy=0.63
	game.match_time=170; game.score=[1,1]; game.controlled=9
	screen.open_tactics(false); await settle()
	check(game.state=="paused" and game.ball.freeze and screen.slot_buttons[9].data.energy==0.22 and screen.slot_buttons[9].data.yellow==1,"In-match management freezes play and displays real energy and cards")
	await click(screen.slot_buttons[9]); screen.reserve_buttons[2].grab_focus()
	await capture("comparison")
	await click(screen.reserve_buttons[2])
	check(game.management.pending.size()==1 and game.players[9].display_name==original and game.management.used[0]==0,"Live substitution waits for a stoppage and does not teleport the player")
	check(screen.slot_buttons[9].data.status=="ÇIKACAK" and screen.reserve_buttons[2].data.status=="GİRECEK" and not screen.swap_action.disabled,"Outgoing and incoming players are marked and individual cancellation is available")
	await capture("pending")
	await click(screen.slot_buttons[8]); await click(screen.reserve_buttons[2])
	check(game.management.pending.size()==1 and screen.status.contains("başka"),"A reserved substitute cannot be assigned to another player")
	await click(screen.reserve_buttons[3])
	check(game.management.pending.size()==2,"Another eligible replacement can be queued independently")
	tap(JOY_BUTTON_X); await settle()
	check(game.management.pending.size()==1 and game.management.pending[0].slot==9,"Undo removes only the last queued replacement")
	await click(screen.slot_buttons[9]); await click(screen.swap_action)
	check(game.management.pending.is_empty() and screen.history.is_empty(),"Clicking cancel removes the selected pending replacement")
	game.players[9].dismissed=true; screen.build(); await click(screen.reserve_buttons[2])
	check(game.management.pending.is_empty() and screen.status.contains("İhraç"),"A dismissed player cannot be replaced")
	game.players[9].dismissed=false; game.management.bench[0][2].used=true; screen.build(); await click(screen.reserve_buttons[2])
	check(game.management.pending.is_empty() and screen.status.contains("kullanıldı"),"A previously used substitute cannot re-enter")
	game.management.bench[0][2].used=false; game.management.used[0]=5; screen.build(); await click(screen.reserve_buttons[2])
	check(game.management.pending.is_empty() and screen.status.contains("hakkı doldu"),"The five-substitution limit is enforced through the new UI")
	game.management.used[0]=0; screen.build(); await click(screen.reserve_buttons[2])
	tap(JOY_BUTTON_B); await settle()
	check(not screen.visible and game.state=="playing" and not game.ball.freeze and game.management.pending.size()==1,"Controller B resumes play with the requested substitution still queued")
	check(not game.pass_charging and game.ball.pending_kick==false,"Menu selections never trigger a gameplay kick")
	print("SQUAD MANAGEMENT CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
