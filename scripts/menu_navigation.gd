extends RefCounted
## Menu controls are fixed, independent of remappable football actions.
var game
var pressed: Dictionary = {}
var direction := Vector2i.ZERO
var repeat_in := 0.0
var context := ""
var wait_for_center := false
var popup_option: OptionButton
const DIRECTIONS := {JOY_BUTTON_DPAD_LEFT:Vector2i.LEFT,JOY_BUTTON_DPAD_RIGHT:Vector2i.RIGHT,JOY_BUTTON_DPAD_UP:Vector2i.UP,JOY_BUTTON_DPAD_DOWN:Vector2i.DOWN}

func screen() -> String:
	if is_instance_valid(game.career_screen) and game.career_screen.visible: return "career:"+game.career_screen.page
	if is_instance_valid(game.controls_help) and game.controls_help.visible: return "controls_help"
	if is_instance_valid(popup_option) and popup_option.get_popup().visible: return "option:"+str(popup_option.get_instance_id())
	if is_instance_valid(game.match_menu) and game.match_menu.visible:
		return "settings:%d:%d" % [game.match_menu.page,game.match_menu.capture_action]
	if is_instance_valid(game.frontend) and game.frontend.visible:
		return "frontend:"+game.frontend.stage+str(game.frontend.pane)+":"+game.frontend.swap_stage
	if is_instance_valid(game.training_menu) and game.training_menu.visible: return "training_menu"
	if game.state=="goal" or (game.state=="restart" and game.restart_type=="SANTRA" and not game.training): return game.state
	return game.state if game.state in ["menu","paused","finished","halftime","ceremony","replay"] else ""

func sync() -> void:
	var current := screen()
	if context!=current:
		if current!="":
			game.controller.combos.cancel()
			game.controller.clear_shot_aim()
		context=current
		direction=Vector2i.ZERO
		repeat_in=0
		wait_for_center=game.controller.stick.length()>0.35
	game.hud.sync_navigation()

func update(delta: float) -> void:
	sync()
	if context=="" or direction==Vector2i.ZERO: return
	if game.match_menu.visible and game.match_menu.capture_action>=0: return
	repeat_in-=delta
	if repeat_in<=0:
		repeat_in=0.18 if context.begins_with("frontend:tactics") else 0.11
		move(direction)

func handle(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return false
	var pad=game.controller
	if pad.device!=event.device: pad.claim_device(event.device,true)
	if event.device!=pad.device: return true
	pad.input_seen=true
	sync()
	if event is InputEventJoypadMotion:
		if event.axis==JOY_AXIS_LEFT_X: pad.stick.x=event.axis_value
		elif event.axis==JOY_AXIS_LEFT_Y: pad.stick.y=event.axis_value
		if context=="": return false
		if absf(event.axis_value)>0.35: pad.using_gamepad=true
		if game.match_menu.visible and game.match_menu.capture_action>=0:
			game.match_menu.handle(event)
			return true
		if event.axis not in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]: return true
		if pad.stick.length()<0.35:
			wait_for_center=false
			direction=Vector2i.ZERO
			return true
		if wait_for_center: return true
		var next := Vector2i.ZERO
		if pad.stick.length()>0.55:
			next=Vector2i(int(signf(pad.stick.x)),0) if absf(pad.stick.x)>absf(pad.stick.y) else Vector2i(0,int(signf(pad.stick.y)))
			if context.begins_with("frontend:tactics") and direction!=Vector2i.ZERO and next.x*direction.x+next.y*direction.y==0:
				# A slight diagonal wobble must not jump between rows and columns.
				var current_axis := absf(pad.stick.x) if direction.x!=0 else absf(pad.stick.y)
				var other_axis := absf(pad.stick.y) if direction.x!=0 else absf(pad.stick.x)
				if other_axis<current_axis+0.20: next=direction
		if next!=Vector2i.ZERO and next!=direction:
			direction=next; repeat_in=0.36
			move(direction)
		return true
	# A release that began in a menu must never become a pass or tackle.
	if not event.pressed and pressed.has(event.button_index):
		pressed.erase(event.button_index)
		pad.held.erase(event.button_index)
		if event.button_index in DIRECTIONS: direction=Vector2i.ZERO
		return true
	if event.pressed and pressed.has(event.button_index): return true
	if context=="": return false
	pad.using_gamepad=true
	if not event.pressed:
		pad.held.erase(event.button_index)
		return true
	pressed[event.button_index]=true
	if game.match_menu.visible and game.match_menu.capture_action>=0:
		game.match_menu.handle(event)
		return true
	if event.button_index in DIRECTIONS:
		direction=DIRECTIONS[event.button_index]; repeat_in=0.36
		move(direction)
	elif event.button_index==JOY_BUTTON_A: activate()
	elif is_instance_valid(popup_option) and popup_option.get_popup().visible:
		if event.button_index in [JOY_BUTTON_B,JOY_BUTTON_BACK,JOY_BUTTON_START]: popup_option.get_popup().hide()
	elif game.controls_help.visible:
		game.controls_help.handle(event)
	elif is_instance_valid(game.career_screen) and game.career_screen.visible:
		game.career_screen.handle(event)
	elif game.match_menu.visible:
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			game.match_menu.show_page(posmod(game.match_menu.page+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1),4))
		else: game.match_menu.handle(event)
	elif game.frontend.visible:
		game.frontend.handle(event)
	elif game.training_menu.visible:
		game.training_menu.handle(event)
	else: game.hud.handle_pad(event.button_index)
	return true

func move(value: Vector2i) -> void:
	if is_instance_valid(popup_option) and popup_option.get_popup().visible:
		var popup := popup_option.get_popup()
		popup.set_focused_item(posmod(popup.get_focused_item()+(value.y if value.y!=0 else value.x),popup.item_count))
		return
	var focus: Control=game.get_viewport().gui_get_focus_owner()
	if not is_instance_valid(focus): return
	if value.x!=0 and focus is HSlider:
		focus.value+=value.x*focus.step
		return
	if value.x!=0 and is_instance_valid(game.frontend) and game.frontend.visible and game.frontend.stage=="teams":
		if game.frontend.try_carousel(focus,value.x):
			return
	if value.x!=0 and focus is OptionButton:
		choose(focus,value.x)
		return
	var side: int=SIDE_LEFT if value.x<0 else (SIDE_RIGHT if value.x>0 else (SIDE_TOP if value.y<0 else SIDE_BOTTOM))
	var next := focus.find_valid_focus_neighbor(side)
	if next!=null: next.grab_focus()

func activate() -> void:
	if is_instance_valid(popup_option) and popup_option.get_popup().visible:
		var option := popup_option
		var index := option.get_popup().get_focused_item()
		option.get_popup().hide()
		if index>=0 and not option.is_item_disabled(index):
			option.select(index)
			option.item_selected.emit(index)
		return
	var focus: Control=game.get_viewport().gui_get_focus_owner()
	if is_instance_valid(game.frontend) and game.frontend.visible and game.frontend.stage=="teams" and game.frontend.pick_step<2 and game.frontend.is_team_choice(focus):
		game.frontend.pick_current()
		return
	if focus is OptionButton:
		popup_option=focus
		focus.show_popup()
		focus.get_popup().set_focused_item(focus.selected)
	elif focus is BaseButton and not focus.disabled:
		if game.training_menu.visible and focus in game.training_menu.cards: game.training_menu.start()
		else: focus.pressed.emit()
	else:
		game.skip_sequence()

func popup_input(event: InputEvent,option: OptionButton) -> void:
	popup_option=option
	if handle(event): option.get_popup().set_input_as_handled()

func choose(option: OptionButton,step: int) -> void:
	var index := option.selected
	for attempt in range(option.item_count):
		index=posmod(index+step,option.item_count)
		if not option.is_item_disabled(index):
			option.select(index)
			option.item_selected.emit(index)
			return

func reset() -> void:
	if is_instance_valid(popup_option): popup_option.get_popup().hide()
	popup_option=null
	pressed.clear()
	direction=Vector2i.ZERO
	wait_for_center=false
	context=""
