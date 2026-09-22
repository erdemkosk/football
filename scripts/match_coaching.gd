extends RefCounted
## Live touchline commands consume their own presses/releases; the match keeps moving.
const TITLES := ["SAVUNMACI","DENGELİ","HÜCUMCU"]
const OFFER := Rect2(32,568,332,160)
const ACCEPT := Rect2(46,683,190,31)
const DISMISS := Rect2(247,683,101,31)
var game
var trigger_down := false
var opened := false
var consumed: Dictionary = {}
var proposal: Dictionary = {}
var dismissed: Dictionary = {}
var age := 0.0
var scan_in := 0.0
var offer_time := 0.0
var notice := ""
var notice_time := 0.0

func reset_input() -> void:
	opened=false
	trigger_down=false
	consumed.clear()

func reset() -> void:
	reset_input()
	proposal.clear(); dismissed.clear()
	age=0; scan_in=0; offer_time=0; notice_time=0; notice=""

func available() -> bool:
	return not game.training and not game.menu_match.running and game.state in ["playing","restart","set_piece"] and not game.frontend.visible and not game.match_menu.visible and not game.controls_help.visible

func proposal_valid() -> bool:
	if proposal.is_empty(): return false
	var p=game.players[proposal.slot]
	var b: Dictionary=game.management.bench[0][proposal.reserve]
	return p.shirt_number==proposal.shirt and b.shirt==proposal.incoming and p.energy<.48 and game.management.substitution_reason(proposal.slot,proposal.reserve)==""

func refresh() -> void:
	if proposal_valid(): return
	proposal.clear()
	var excluded: Array=[]
	for shirt in dismissed:
		if dismissed[shirt]>age: excluded.append(shirt)
	proposal=game.management.suggestion(0,.40,excluded)
	offer_time=11 if not proposal.is_empty() else 0

func update(delta: float) -> void:
	if not available(): opened=false; return
	age+=delta
	notice_time=maxf(0,notice_time-delta)
	if not proposal.is_empty() and not proposal_valid(): proposal.clear()
	if not proposal.is_empty() and not opened:
		offer_time-=delta
		if offer_time<=0: dismiss(false)
	scan_in-=delta
	if scan_in<=0:
		scan_in=1.0
		refresh()

func select_plan(value: int) -> void:
	game.management.live_plan(value)
	notice=TITLES[value]+" · TEKNİK DİREKTÖRDEN TALİMAT"
	notice_time=3.4
	game.controller.rumble(.20)

func accept() -> void:
	if not available() or not proposal_valid(): refresh(); return
	var before: int=game.management.pending.size()
	var result: String=game.management.queue_sub(proposal.slot,proposal.reserve)
	if game.management.pending.size()>before:
		notice=result; notice_time=5
		proposal.clear(); scan_in=5
		# Live acceptance queues only. A currently stopped ball can begin the change now.
		if game.state in ["restart","set_piece"]:
			game.management.prepare_substitutions()
			if game.state=="set_piece" and not game.management.transit.is_empty():
				game.state="restart"
				game.set_pieces.prepare()
		game.controller.rumble(.35)
	else:
		notice=result; notice_time=3
		proposal.clear()

func dismiss(show_notice: bool=true) -> void:
	if proposal.is_empty(): return
	dismissed[proposal.shirt]=age+24
	proposal.clear(); scan_in=6
	if show_notice: notice="ÖNERİ GEÇİLDİ"; notice_time=2

func power_shot_held() -> bool:
	var pad=game.controller
	if pad.bindings.get(JOY_BUTTON_LEFT_SHOULDER)!=KEY_Q: return false
	return pad.action_held(KEY_Q) or game.advanced_controls.shoulder_held() or pad.combos.consumed.has(JOY_BUTTON_LEFT_SHOULDER)

func handle(event: InputEvent) -> bool:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var pad=game.controller
		if pad.device<0: pad.adopt_device(event.device)
		if event.device!=pad.device: return false
		if event is InputEventJoypadMotion and event.axis==JOY_AXIS_TRIGGER_RIGHT:
			var was_down := trigger_down
			trigger_down=event.axis_value>(.35 if trigger_down else .55)
			if not trigger_down: opened=false
			elif not was_down and available() and not power_shot_held():
				opened=true; pad.using_gamepad=true
				pad.clear_shot_aim(); pad.combos.cancel()
				game.cancel_pass(); game.charging=false; game.charge=0
				game.heading.cancel(game.controlled)
				game.players[game.controlled].shot_preparation=0
				refresh()
			return available() and not power_shot_held()
		if event is InputEventJoypadButton:
			var button: int=event.button_index
			if button==JOY_BUTTON_LEFT_SHOULDER and event.pressed and pad.bindings.get(button)==KEY_Q:
				opened=false
			if consumed.has(button):
				if not event.pressed: consumed.erase(button)
				return true
			if available() and opened and not power_shot_held() and button in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y]:
				if event.pressed:
					consumed[button]=true
					pad.using_gamepad=true
					match button:
						JOY_BUTTON_DPAD_LEFT: select_plan(0)
						JOY_BUTTON_DPAD_UP: select_plan(1)
						JOY_BUTTON_DPAD_RIGHT: select_plan(2)
						JOY_BUTTON_DPAD_DOWN: refresh()
						JOY_BUTTON_A: accept()
						JOY_BUTTON_B: dismiss()
				return true
	if not available(): return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F5,KEY_F6,KEY_F7]:
			game.controller.using_gamepad=false
			select_plan(event.keycode-KEY_F5); return true
		if event.keycode==KEY_F8: game.controller.using_gamepad=false; accept(); return true
		if event.keycode==KEY_F9: game.controller.using_gamepad=false; dismiss(); return true
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and proposal_valid():
		if ACCEPT.has_point(event.position): accept(); return true
		if DISMISS.has_point(event.position): dismiss(); return true
	return false

func draw(hud) -> void:
	if not available(): return
	var pad=game.controller
	var plan: int=game.management.mentality
	if opened:
		hud.panel(Rect2(395,679,810,151),Color("142f2b"),10,Color("9ebc9e"))
		hud.text("KENARDAN TALİMAT",Vector2(415,707),13,hud.GOLD,true)
		hud.text("OYUN DEVAM EDİYOR",Vector2(1036,707),10,hud.MUTE)
		for i in range(3):
			var x := 415+i*258
			hud.panel(Rect2(x,722,244,43),hud.GOLD if i==plan else Color("27463b"),6)
			hud.center(["←  ","↑  ","→  "][i]+TITLES[i],Vector2(x+122,749),14,hud.INK if i==plan else hud.PAPER)
		hud.pad_hints(Vector2(420,797),[["RT","Basılı tut"],["A","Öneriyi kabul et"],["B","Öneriyi geç"]],24,11)
	else:
		hud.panel(Rect2(32,139,230,27),Color(.04,.10,.10,.86),4)
		hud.text(TITLES[plan],Vector2(43,157),10,hud.GOLD,true)
		if pad.using_gamepad: hud.pad_hints(Vector2(158,152),[["RT","Taktik"]],19,9)
		else: hud.text("F5 / F6 / F7",Vector2(173,157),9,hud.MUTE)
	if notice_time>0:
		hud.panel(Rect2(395,635,810,34),Color(.06,.15,.13,.94),5)
		hud.center(notice.left(85),Vector2(800,657),12,hud.GOLD)
	if proposal_valid():
		var p=game.players[proposal.slot]
		var incoming: Dictionary=game.management.bench[0][proposal.reserve]
		hud.panel(OFFER,Color("142f2b"),10,Color("587b61"))
		hud.text("TAZE BİR HAMLE",Vector2(47,592),12,hud.GOLD,true)
		hud.text("%d / 3" % game.management.committed(0),Vector2(306,592),11,hud.MUTE)
		hud.text(p.display_name+"  →  "+incoming.name,Vector2(47,619),18,hud.PAPER,true)
		hud.text(["KALECİ","DEFANS","ORTA SAHA","FORVET"][game.management.slot_role(proposal.slot)],Vector2(47,641),10,Color("a8e1be"),true)
		hud.text("ENERJİ  %d%% → 100%%" % roundi(p.energy*100),Vector2(175,641),11,hud.MUTE)
		hud.text("Onayla; ilk duraklamada değişsin.",Vector2(47,664),11,hud.MUTE)
		hud.panel(ACCEPT,Color("305743"),5)
		hud.panel(DISMISS,Color("29463a"),5)
		if pad.using_gamepad:
			hud.pad_hints(Vector2(53,699),[["RT + A","Kabul"]],22,10)
			hud.pad_hints(Vector2(252,699),[["RT + B","Geç"]],20,9)
		else:
			hud.text("F8  ·  KABUL ET",Vector2(68,703),11,hud.PAPER,true)
			hud.text("F9  ·  GEÇ",Vector2(266,703),10,hud.PAPER,true)
