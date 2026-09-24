extends RefCounted
## Local multiplayer. Each person owns a control slot: a device (the keyboard
## or one controller), a team and the per-person match state — selected player,
## shot/pass charge and aim, and the input modules. The single-player code runs
## once per slot with that state swapped in, so every mechanic behaves the same
## for both people, and a one-person match is exactly the previous code path.
const MODES := ["TEK KİŞİ","2 KİŞİ · KARŞILIKLI","2 KİŞİ · AYNI TAKIM"]
const MODE_SHORT := ["TEK","1v1","CO-OP"]
const KEYBOARD := -2
const COLORS := [Color("f2c14e"),Color("5ec8ff")]
## Game properties that belong to one person.
const STATE := ["controlled","charging","charge","shot_anchor","shot_direction","shot_offset","shot_mouse_aim","shot_separate_aim","shot_direct_aim","shot_finesse","shot_chip","shot_curve","pass_charging","pass_power","pass_direction","pass_preview","pass_risk","pass_through","pass_lob","pass_driven","request_through","last_direction","aiming_mouse","player_lock","requested_receiver","request_time","request_age","request_lob","request_cooldown","controller","advanced_controls","action_control","pass_buffer","team_control","defending","finishing","keys_enabled"]
var game
var mode := 0
## Chosen mode for the next quick match; a career always plays alone.
var preferred := 0
var slots: Array[Dictionary] = []
var active := 0

func multiple() -> bool:
	return slots.size()>1

func setup() -> void:
	slots=[{"team":0,"device":KEYBOARD,"state":{}}]
	active=0

## Devices for two people: the keyboard plus one pad, or two pads.
static func devices(pads: Array) -> Array:
	if pads.size()>=2: return [int(pads[0]),int(pads[1])]
	if pads.size()==1: return [KEYBOARD,int(pads[0])]
	return []

func configure(new_mode: int,pads_override: Array=[]) -> bool:
	release()
	var pads: Array=pads_override if not pads_override.is_empty() else Input.get_connected_joypads()
	var pair: Array=devices(pads)
	if new_mode==0 or pair.is_empty():
		mode=0
		return new_mode==0
	mode=new_mode
	var second_team: int=1 if mode==1 else 0
	slots[0].device=pair[0]
	game.keys_enabled=pair[0]==KEYBOARD
	if pair[0]!=KEYBOARD:
		game.controller.adopt_device(pair[0]); game.controller.locked=true
	else:
		game.controller.device=-1; game.controller.locked=true
	var pad=preload("res://scripts/gamepad.gd").new()
	pad.game=game
	game.add_child(pad)
	pad.set_process(false)
	pad.bindings=game.controller.bindings.duplicate()
	pad.sensitivity=game.controller.sensitivity; pad.deadzone=game.controller.deadzone; pad.vibration=game.controller.vibration
	pad.adopt_device(pair[1]); pad.locked=true
	var second := {"controller":pad,"keys_enabled":false,"controlled":second_team*11+9 if second_team==1 else 7}
	for module in ["advanced_controls","action_control","pass_buffer","team_control","defending","finishing"]:
		var instance=game.get(module).get_script().new()
		instance.game=game
		second[module]=instance
	second.team_control.team=second_team
	for key in STATE:
		if not second.has(key): second[key]=game.get(key)
	second.last_direction=Vector3(0,0,game.attack_sign(second_team))
	second.pass_preview={}
	slots.append({"team":second_team,"device":pair[1],"state":second})
	return true

func release() -> void:
	# Back to one person: slot 0's state is live in the game; drop the rest.
	if slots.is_empty(): setup()
	if active!=0: activate(0)
	for i in range(1,slots.size()):
		var pad=slots[i].state.get("controller")
		if is_instance_valid(pad): pad.queue_free()
	slots=[slots[0]]
	slots[0].device=KEYBOARD
	mode=0
	game.keys_enabled=true
	if is_instance_valid(game.controller): game.controller.locked=false

func activate(index: int) -> void:
	if index==active or index<0 or index>=slots.size(): return
	store()
	active=index
	var state: Dictionary=slots[index].state
	for key in STATE:
		if state.has(key): game.set(key,state[key])

func store() -> void:
	var state: Dictionary=slots[active].state
	for key in STATE: state[key]=game.get(key)

## Run a per-person step once for every slot, then return to slot 0.
func each(step: Callable) -> void:
	if not multiple():
		step.call(); return
	for i in range(slots.size()):
		activate(i)
		step.call()
	activate(0)

func slot_for_team(team: int) -> int:
	for i in range(slots.size()):
		if int(slots[i].team)==team: return i
	return -1

func team_of(index: int) -> int:
	return int(slots[index].team) if index>=0 and index<slots.size() else 0

func human_team(team: int) -> bool:
	return slot_for_team(team)>=0

func controlled_of(slot: int) -> int:
	return game.controlled if slot==active else int(slots[slot].state.get("controlled",-1))

func owner_of(player: int) -> int:
	for i in range(slots.size()):
		if controlled_of(i)==player: return i
	return -1

func claimed_by_other(player: int) -> bool:
	# In co-op one person cannot take the teammate's current player.
	if not multiple(): return false
	var owner := owner_of(player)
	return owner>=0 and owner!=active

func slot_for_event(event: InputEvent) -> int:
	if not multiple(): return 0
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		for i in range(slots.size()):
			if int(slots[i].device)==event.device: return i
		return -1
	for i in range(slots.size()):
		if int(slots[i].device)==KEYBOARD: return i
	return -1

func set_controlled_for_team(team: int,player: int) -> void:
	var slot := slot_for_team(team)
	if slot<0: return
	if slot==active: game.controlled=player
	else: slots[slot].state.controlled=player

func label() -> String:
	if not multiple(): return MODES[0]
	var names: Array[String]=[]
	for i in range(slots.size()):
		var device: int=int(slots[i].device)
		names.append("P%d %s" % [i+1,"KLAVYE" if device==KEYBOARD else "KOL %d" % (device+1)])
	return MODES[mode]+" · "+" / ".join(names)
