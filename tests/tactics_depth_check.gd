extends SceneTree
## Nine formations, formation paging in the tactics screen and individual
## player instructions that change real support and defensive targets.
const DT := 1.0/120
var game
var front
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func focus() -> Control: return root.gui_get_focus_owner()
func tap(code: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device=0; event.button_index=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()
func key(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()

func possession_scene() -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.state="playing"; game.menu_match.running=false
	for p in game.players:
		p.position=p.home; p.velocity=Vector3.ZERO
	var owner=game.players[6]
	# Build-up from our own half: the striker is ahead of the ball.
	owner.position=Vector3(0,0,game.attack_sign(0)*-18)
	game.ball.position=owner.position+Vector3(0,.23,game.attack_sign(0)*.65); game.ball.linear_velocity=Vector3.ZERO
	game.dribbler=6; game.carrier=6; game.last_touch=0; game.controlled=6

func support_target(index: int) -> Vector3:
	game.support.plan_age=0
	game.support.update(DT)
	return game.support.targets.get(index,Vector3.INF)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0
	game.match_menu.config_path="/tmp/sefc-tactics-depth.cfg"
	front=game.frontend
	var m=game.management
	check(m.FORMATIONS.size()==9 and m.SHAPES.size()==9 and m.LINE_COUNTS.size()==9 and m.WIDE_BACKS.size()==9,"Nine formations share one table")
	for shape in range(m.FORMATIONS.size()):
		m.formation=shape; m.apply_formation()
		var counts := [0,0,0,0]
		for i in range(11): counts[m.slot_role(i)]+=1
		var expected: Array=m.LINE_COUNTS[shape]
		check(counts==[1,expected[0],expected[1],expected[2]],"%s assigns its real lines" % m.FORMATIONS[shape])
		var sane := true
		for i in range(11):
			var p=game.players[i]
			if absf(p.home.x)>36 or absf(p.home.z)>47: sane=false
		check(sane,"%s keeps every home spot on the pitch" % m.FORMATIONS[shape])
		check(front.LINES[shape][1].size()==int(expected[0]) and front.ROLES[shape].size()==11 and m.lines(shape)[3].size()==int(expected[2]),"%s has card lines, role labels and slot groups" % m.FORMATIONS[shape])
	m.formation=0; m.apply_formation()
	# The tactics screen pages through the other shapes without applying them.
	front.open_selection(); front.open_tactics(true)
	front.set_pane(1)
	front.tactic_buttons[0][2].grab_focus()
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(focus()==front.formation_arrows[1],"Right from the last shape reaches the next-page arrow")
	tap(JOY_BUTTON_A)
	check(front.tactic_buttons[0][0].text=="4-2-3-1" and m.formation==0,"The arrow pages to more formations without applying one")
	front.tactic_buttons[0][0].grab_focus(); tap(JOY_BUTTON_A)
	check(m.formation==3 and front.tactic_buttons[0][0].text=="4-2-3-1","A applies 4-2-3-1 from the second page")
	front.set_tactic("formation",0)
	check(front.tactic_buttons[0][0].text=="4-4-2","Applying a first-page shape returns the row to that page")
	# Individual instructions cycle from the inspected pitch card.
	front.set_pane(0)
	front.slot_buttons[9].grab_focus()
	var number: int=game.players[9].number
	key(KEY_T)
	check(m.instructions.get(number,{}).get("attack",-1)==2,"T sets the striker to join the attack")
	key(KEY_Y); key(KEY_Y)
	check(m.instructions.get(number,{}).get("width",-1)==0,"Y cycles the width instruction")
	tap(JOY_BUTTON_Y)
	check(m.instructions.get(number,{}).get("attack",-1)==0,"Controller Y cycles the attacking instruction too")
	front.slot_buttons[0].grab_focus(); key(KEY_T)
	check(not m.instructions.has(game.players[0].number),"The goalkeeper takes no outfield instruction")
	front.hide()
	# Instructions move the real support target.
	m.instructions={}
	possession_scene()
	var forward: float=game.attack_sign(0)
	var balanced: Vector3=support_target(9)
	m.instructions[game.players[9].number]={"attack":0,"width":1}
	var holding: Vector3=support_target(9)
	m.instructions[game.players[9].number]={"attack":2,"width":1}
	var joining: Vector3=support_target(9)
	check(holding.z*forward<balanced.z*forward and joining.z*forward>=balanced.z*forward,"Hold and join-the-attack move the striker's support run: %.1f / %.1f / %.1f" % [holding.z*forward,balanced.z*forward,joining.z*forward])
	var wide_index: int=5
	m.instructions={}
	var normal_wide: Vector3=support_target(wide_index)
	m.instructions[game.players[wide_index].number]={"attack":1,"width":0}
	var inside: Vector3=support_target(wide_index)
	check(absf(inside.x)<absf(normal_wide.x)-1.0,"Cut inside pulls a wide player towards the middle")
	# Persistence.
	m.instructions={10:{"attack":2,"width":2}}
	game.match_menu.save_settings(); m.instructions={}; game.match_menu.load_settings()
	check(m.instructions.get(10,{}).get("attack",-1)==2 and m.instructions.get(10,{}).get("width",-1)==2,"Instructions survive a settings round trip")
	game.career.apply_plan({"formation":3,"instructions":{7:{"attack":0,"width":1}}})
	check(m.formation==3 and m.instructions.has(7) and not m.instructions.has(10),"A career plan carries its own formation and instructions")
	m.instructions={}; m.formation=0; game.match_menu.save_settings()
	print("TACTICS DEPTH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
