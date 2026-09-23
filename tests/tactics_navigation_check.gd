extends SceneTree
var game
var front
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)

func focus() -> Control: return root.gui_get_focus_owner()

func tap(code: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device=0; event.button_index=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()

func axis(code: int,value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device=0; event.axis=code; event.axis_value=value
	Input.parse_input_event(event); Input.flush_buffered_events()

func key(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	for i in range(160):
		await process_frame
		if front.portraits.pending.is_empty() and front.portraits.studio==null and i>8: break
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/tactics-nav-"+label+".png")

func reachable() -> Array:
	var pending: Array=[focus()]
	var seen: Array=[]
	while not pending.is_empty():
		var current: Control=pending.pop_front()
		if current==null or current in seen: continue
		seen.append(current)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: pending.append(current.find_valid_focus_neighbor(side))
	return seen

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0
	game.match_menu.config_path="res://tests/tactics-nav-settings.cfg"
	game.controlled=9
	front=game.frontend
	front.open_selection(); front.open_tactics(true)
	check(focus()==front.first_focus and front.swap_stage=="browse","Prematch tactics opens on match start, with no substitution armed")
	var initial: Array=game.clubs.lineups[0].duplicate()
	for formation in range(3):
		front.set_tactic("formation",formation)
		front.slot_buttons[9].grab_focus()
		var available := reachable()
		check((front.slot_buttons+front.reserve_buttons+front.tab_buttons+[front.swap_action,front.back_button,front.first_focus]).all(func(button): return button in available),"Every lineup control is reachable in formation "+str(formation))
		for group in range(4):
			var line: Array=front.LINES[formation][group]
			front.slot_buttons[line[0]].grab_focus()
			for i in range(1,line.size()):
				tap(JOY_BUTTON_DPAD_RIGHT)
				check(focus()==front.slot_buttons[line[i]] and front.selected_slot==line[i],"Right follows the same pitch row and updates player details")
		check(game.clubs.lineups[0]==initial and front.history.is_empty() and game.management.pending.is_empty(),"Directional browsing never changes the lineup")
	front.set_tactic("formation",0)
	front.slot_buttons[9].grab_focus()
	await capture("focus")
	axis(JOY_AXIS_LEFT_X,0.22)
	check(focus()==front.slot_buttons[9],"Analog drift cannot move focus")
	axis(JOY_AXIS_LEFT_X,0.9)
	check(focus()==front.slot_buttons[10],"One analog deflection moves one player")
	axis(JOY_AXIS_LEFT_Y,0.94)
	check(focus()==front.slot_buttons[10],"Small diagonal wobble does not switch navigation axes")
	axis(JOY_AXIS_LEFT_Y,0)
	game.controller.menus.update(0.20)
	check(focus()==front.slot_buttons[10],"Held analog waits before repeating")
	axis(JOY_AXIS_LEFT_X,0)
	front.slot_buttons[9].grab_focus(); tap(JOY_BUTTON_A)
	check(front.swap_stage=="choose" and focus()==front.slot_buttons[9] and front.slot_buttons[9].active,"A selects a starter without forcing the bench")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(focus()==front.slot_buttons[10] and front.swap_source.index==9,"Direction presses reach another starter while preserving the first selection")
	check(front.reserve_buttons.all(func(button): return button in reachable()),"The full bench remains reachable after selecting a starter")
	front.reserve_buttons[2].grab_focus()
	await capture("reserve")
	var incoming: String=game.management.bench[0][2].name
	tap(JOY_BUTTON_A)
	check(front.swap_stage=="confirm" and focus()==front.swap_action and game.clubs.lineups[0]==initial and front.history.is_empty(),"A on a reserve opens confirmation without making a change")
	await capture("confirm")
	tap(JOY_BUTTON_START)
	check(front.visible and front.swap_stage=="confirm" and game.clubs.lineups[0]==initial,"Start cannot skip an unconfirmed change")
	tap(JOY_BUTTON_B)
	check(front.visible and front.swap_stage=="choose" and focus()==front.reserve_buttons[2],"B leaves confirmation and returns to the same reserve")
	tap(JOY_BUTTON_B)
	check(front.swap_stage=="browse" and focus()==front.slot_buttons[9] and front.preview_reserve==-1,"B cancels the outgoing selection before closing the screen")
	tap(JOY_BUTTON_A); front.reserve_buttons[2].grab_focus(); tap(JOY_BUTTON_A); tap(JOY_BUTTON_A)
	check(game.players[9].display_name==incoming and front.history.size()==1 and front.swap_stage=="browse" and focus()==front.slot_buttons[9],"Explicit confirmation applies exactly one swap and restores starter focus")
	tap(JOY_BUTTON_X)
	check(game.clubs.lineups[0]==initial and front.history.is_empty(),"Undo restores the original lineup")
	front.slot_buttons[6].grab_focus()
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(front.pane==1 and focus()==front.tactic_buttons[0][0],"RB enters the active formation option")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(focus()==front.tactic_buttons[0][1] and game.management.formation==0,"Right previews another formation without applying it")
	tap(JOY_BUTTON_A)
	check(game.management.formation==1 and focus()==front.tactic_buttons[0][1],"A applies a formation and preserves the exact focus")
	tap(JOY_BUTTON_DPAD_DOWN); tap(JOY_BUTTON_DPAD_RIGHT)
	check(focus()==front.tactic_buttons[1][2] and game.management.mentality==1,"Plan navigation keeps rows and columns without changing tactics")
	await capture("plan")
	tap(JOY_BUTTON_LEFT_SHOULDER)
	check(front.pane==0 and focus()==front.slot_buttons[6],"LB restores the last starter focus")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(focus()==front.tactic_buttons[1][2],"RB restores the last plan option")
	front.tab_buttons[0].grab_focus(); tap(JOY_BUTTON_A)
	check(focus()==front.slot_buttons[6],"Activating the lineup tab also restores content focus")
	front.tab_buttons[1].grab_focus(); tap(JOY_BUTTON_A)
	check(focus()==front.tactic_buttons[1][2],"Activating the plan tab retains the last option rather than the tab itself")
	var saved_focus: Control=focus()
	tap(JOY_BUTTON_BACK); tap(JOY_BUTTON_B)
	check(front.visible and focus()==saved_focus and game.state=="setup","Settings restore the tactical focus and preparation state")
	tap(JOY_BUTTON_LEFT_SHOULDER)
	front.slot_buttons[9].grab_focus()
	axis(JOY_AXIS_LEFT_X,0.9); tap(JOY_BUTTON_A)
	var reserve_focus: Control=focus()
	game.controller.menus.update(1.0)
	check(front.swap_stage=="choose" and focus()==reserve_focus,"A held stick cannot run across the squad after selecting a starter")
	axis(JOY_AXIS_LEFT_X,0); tap(JOY_BUTTON_B)
	front.slot_buttons[9].grab_focus()
	key(KEY_RIGHT)
	check(focus()==front.slot_buttons[10] and game.clubs.lineups[0]==initial,"Keyboard arrows use the same safe focus graph")
	key(KEY_ENTER)
	check(front.swap_stage=="choose","Keyboard Enter selects the first player")
	key(KEY_ESCAPE)
	check(front.swap_stage=="browse" and front.visible,"Keyboard Escape cancels the selection first")
	front.confirm(); game.ceremony.finish(true)
	game.controlled=9; game.players[9].energy=0.25
	front.open_tactics(false)
	tap(JOY_BUTTON_A); front.reserve_buttons[2].grab_focus(); tap(JOY_BUTTON_A)
	check(game.management.pending.is_empty() and game.management.used[0]==0,"In-match confirmation does not queue a substitution early")
	tap(JOY_BUTTON_A)
	check(game.management.pending.size()==1 and game.management.used[0]==0,"Confirm queues one substitution for the next stoppage")
	tap(JOY_BUTTON_A)
	check(focus()==front.swap_action and not front.swap_action.disabled,"A pending replacement exposes its cancel action")
	tap(JOY_BUTTON_A)
	check(game.management.pending.is_empty() and front.swap_stage=="browse","The pending replacement can be cancelled explicitly")
	game.players[9].dismissed=true
	tap(JOY_BUTTON_A)
	check(front.swap_stage=="browse" and front.status.contains("İhraç") and focus()==front.slot_buttons[9],"No eligible replacement leaves focus on the starter with a reason")
	check(not game.pass_charging and not game.ball.pending_kick,"Tactics inputs never leak into football actions")
	print("TACTICS NAVIGATION CHECK: %d checks, %d failures" % [checks,failures])
	DirAccess.remove_absolute(game.match_menu.config_path)
	game.free(); quit(0 if failures==0 else 1)
