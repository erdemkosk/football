extends Node
## Godot's normalized face buttons support Xbox and PlayStation alike.
signal prompts_changed
const Glyphs = preload("res://scripts/controller_glyphs.gd")
const DEADZONE := 0.18
var sensitivity := 1.0
var deadzone := DEADZONE
var vibration := true
var bindings: Dictionary = {JOY_BUTTON_A:KEY_S,JOY_BUTTON_B:KEY_A,JOY_BUTTON_X:KEY_D,JOY_BUTTON_Y:KEY_Y,JOY_BUTTON_RIGHT_SHOULDER:KEY_W,JOY_BUTTON_LEFT_SHOULDER:KEY_Q,JOY_BUTTON_LEFT_STICK:KEY_X,JOY_BUTTON_RIGHT_STICK:KEY_V,100+JOY_AXIS_TRIGGER_LEFT:KEY_E,100+JOY_AXIS_TRIGGER_RIGHT:KEY_G}
var game
var device := -1
var family := "xbox"
var device_name := ""
var stick := Vector2.ZERO
var aim_stick := Vector2.ZERO
var aim_buttons: Dictionary = {}
const AIM_DIRECTIONS := {JOY_BUTTON_DPAD_LEFT:Vector2.LEFT,JOY_BUTTON_DPAD_RIGHT:Vector2.RIGHT,JOY_BUTTON_DPAD_UP:Vector2.UP,JOY_BUTTON_DPAD_DOWN:Vector2.DOWN}
var using_gamepad := false:
	set(value):
		if using_gamepad==value: return
		using_gamepad=value
		prompts_changed.emit()
var held: Dictionary = {}
var menus = preload("res://scripts/menu_navigation.gd").new()
var combos = preload("res://scripts/attacking_combos.gd").new()

func _ready() -> void:
	menus.game=game
	combos.game=game
	# MenuNavigation owns pad focus, repeats and popups. Keep keyboard UI bindings,
	# but remove built-in pad actions so PopupMenu cannot process the same press twice.
	for action in ["ui_accept","ui_cancel","ui_up","ui_down","ui_left","ui_right","ui_focus_next","ui_focus_prev"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action,event)
	Input.joy_connection_changed.connect(connection_changed)
	var connected := Input.get_connected_joypads()
	if not connected.is_empty():
		adopt_device(connected[0])
		stick=Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))

static func detect_family(controller_name: String,info: Dictionary={},guid: String="") -> String:
	var name := (controller_name+" "+str(info.get("raw_name",""))).to_lower()
	if int(info.get("vendor_id",0))==0x054c or (guid.length()>=12 and guid.substr(8,4).to_lower()=="4c05"): return "playstation"
	for identifier in ["dualsense","dual sense","dualshock","dual shock","playstation","play station","ps3","ps4","ps5","sony"]:
		if identifier in name: return "playstation"
	return "xbox"

func adopt_device(id: int,controller_name: String="",info: Dictionary={},guid: String="") -> void:
	device=id
	if controller_name=="" and id in Input.get_connected_joypads():
		controller_name=Input.get_joy_name(id)
		info=Input.get_joy_info(id)
		guid=Input.get_joy_guid(id)
	device_name=controller_name
	family=detect_family(controller_name,info,guid)
	using_gamepad=true
	prompts_changed.emit()

func family_label() -> String:
	return "PLAYSTATION" if family=="playstation" else "XBOX"

func button_for(action: int) -> int:
	for button in bindings:
		if bindings[button]==action: return button
	return -1

func icon_for(action: int) -> Texture2D:
	var button := button_for(action)
	return Glyphs.icon(button,family) if button>=0 else null

func _process(delta: float) -> void:
	menus.update(delta)

func movement() -> Vector3:
	var magnitude := stick.length()
	if device<0 or magnitude<=deadzone: return Vector3.ZERO
	var strength := clampf((magnitude-deadzone)/(1-deadzone),0,1)
	var direction := stick.normalized()*pow(strength,1.0/sensitivity)
	return Vector3(direction.x,0,direction.y)

func clear_shot_aim() -> void:
	aim_stick=Vector2.ZERO
	aim_buttons.clear()

func has_separate_aim() -> bool:
	return not aim_buttons.is_empty() or aim_stick.length()>deadzone

func separate_aim() -> Vector3:
	if device<0: return Vector3.ZERO
	var direction := Vector2.ZERO
	if not aim_buttons.is_empty():
		for button in aim_buttons: direction+=AIM_DIRECTIONS[button]
		direction=direction.normalized()
	elif aim_stick.length()>deadzone:
		var strength := clampf((aim_stick.length()-deadzone)/(1-deadzone),0,1)
		direction=aim_stick.normalized()*strength
	return Vector3(direction.x,0,direction.y)

func translate(event: InputEvent) -> InputEventKey:
	if device<0: adopt_device(event.device)
	if event.device!=device: return null
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			var trigger := InputEventJoypadButton.new()
			trigger.device=event.device
			trigger.button_index=100+event.axis
			trigger.pressed=event.axis_value>0.55 if not held.has(trigger.button_index) else event.axis_value>0.35
			return translate(trigger)
		if event.axis==JOY_AXIS_LEFT_X: stick.x=event.axis_value
		elif event.axis==JOY_AXIS_LEFT_Y: stick.y=event.axis_value
		elif event.axis==JOY_AXIS_RIGHT_X: aim_stick.x=event.axis_value
		elif event.axis==JOY_AXIS_RIGHT_Y: aim_stick.y=event.axis_value
		else: return null
		if movement().length()>0.01 or separate_aim().length()>0.01:
			using_gamepad=true
			game.aiming_mouse=false
		return null
	if not event is InputEventJoypadButton: return null
	if event.button_index in AIM_DIRECTIONS:
		if event.pressed: aim_buttons[event.button_index]=true
		else: aim_buttons.erase(event.button_index)
		using_gamepad=true
		game.aiming_mouse=false
		return null
	if event.pressed and held.has(event.button_index): return null
	if combos.handle(event):
		using_gamepad=true
		game.aiming_mouse=false
		return null
	var code: int=0
	if event.pressed:
		code=bindings.get(event.button_index,0)
		if event.button_index==JOY_BUTTON_START: code=KEY_ESCAPE
		elif event.button_index==JOY_BUTTON_BACK: code=KEY_P if game.state in ["menu","finished"] else KEY_K
		elif event.button_index==JOY_BUTTON_A and game.state in ["menu","finished","paused","ceremony","halftime","replay","goal"]: code=KEY_ENTER
		elif event.button_index==JOY_BUTTON_A and game.state=="restart" and game.restart_type=="SANTRA": code=KEY_ENTER
		elif code==KEY_A and game.state=="playing" and not game.has_ball_control(game.controlled): code=KEY_X
		elif code==KEY_D and game.state=="playing" and not game.has_ball_control(game.controlled): code=KEY_G
		if code==0: return null
		held[event.button_index]=code
	else:
		# Release the action that began on press, even across menu/ceremony changes.
		code=held.get(event.button_index,0)
		held.erase(event.button_index)
		if code==0: return null
	using_gamepad=true
	game.aiming_mouse=false
	var direction := movement()
	if direction.length()>0.01 and (code==KEY_X or (not game.charging and not game.pass_charging)):
		game.last_direction=game.match_camera.orient(direction).normalized()
	var mapped := InputEventKey.new()
	mapped.keycode=code
	mapped.physical_keycode=code
	mapped.pressed=event.pressed
	return mapped

func connection_changed(id: int,connected: bool) -> void:
	if connected:
		if device<0:
			adopt_device(id)
			stick=Vector2.ZERO
			game.announce(family_label()+" KONTROLCÜ BAĞLANDI")
		return
	if id!=device: return
	device=-1
	stick=Vector2.ZERO
	clear_shot_aim()
	held.clear()
	menus.reset()
	combos.cancel()
	using_gamepad=false
	game.charging=false
	game.charge=0
	game.cancel_pass()
	game.goalkeeping.stop_rush()
	game.set_pieces.button=0
	game.set_pieces.power=0
	for p in game.players: p.shot_preparation=0
	if game.state not in ["menu","finished","paused"] and not game.frontend.visible and not game.match_menu.visible:
		var pause := InputEventKey.new()
		pause.keycode=KEY_ESCAPE
		pause.pressed=true
		game._input(pause)
	game.announce("KONTROLCÜ BAĞLANTISI KESİLDİ · OYUN DURAKLATILDI")

func action_held(action: int) -> bool:
	return action in held.values()

func rumble(strength: float,shot: bool=false) -> void:
	if not vibration or device not in Input.get_connected_joypads(): return
	Input.start_joy_vibration(device,clampf(strength*0.55,0,1),clampf(strength*(0.85 if shot else 1.0),0,1),0.16 if shot else 0.25)

func rebind(action: int,button: int) -> void:
	var old := -1
	for key in bindings:
		if bindings[key]==action: old=key; break
	var displaced: int=bindings.get(button,0)
	if old>=0:
		bindings.erase(old)
		if displaced>0: bindings[old]=displaced
	bindings[button]=action
	held.clear()
	prompts_changed.emit()

func reset_bindings() -> void:
	bindings={JOY_BUTTON_A:KEY_S,JOY_BUTTON_B:KEY_A,JOY_BUTTON_X:KEY_D,JOY_BUTTON_Y:KEY_Y,JOY_BUTTON_RIGHT_SHOULDER:KEY_W,JOY_BUTTON_LEFT_SHOULDER:KEY_Q,JOY_BUTTON_LEFT_STICK:KEY_X,JOY_BUTTON_RIGHT_STICK:KEY_V,100+JOY_AXIS_TRIGGER_LEFT:KEY_E,100+JOY_AXIS_TRIGGER_RIGHT:KEY_G}
	held.clear()
	prompts_changed.emit()

func label_for(action: int) -> String:
	for button in bindings:
		if bindings[button]==action: return {0:"A",1:"B",2:"X",3:"Y",7:"L3",8:"R3",9:"LB",10:"RB",104:"LT",105:"RT"}.get(button,"Tuş %d" % button)
	return "Atanmamış"
