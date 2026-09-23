extends SceneTree
var game
var failures:=0
var checks:=0
const NAV:=[JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]
const SIDES:=[SIDE_TOP,SIDE_BOTTOM,SIDE_LEFT,SIDE_RIGHT]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func tap(code: int) -> void:
	for down in [true,false]:
		var e:=InputEventJoypadButton.new(); e.device=0; e.button_index=code; e.pressed=down
		Input.parse_input_event(e); Input.flush_buffered_events()
func focus() -> Control: return root.gui_get_focus_owner()
func go(target: Control) -> bool:
	var pending: Array=[[focus(),[]]]; var seen: Array=[]
	while not pending.is_empty():
		var entry: Array=pending.pop_front(); var current: Control=entry[0]
		if current==target:
			for code in entry[1]: tap(code)
			return focus()==target
		if current==null or current in seen: continue
		seen.append(current)
		for i in range(4):
			if i>=2 and current is OptionButton: continue
			var next:=current.find_valid_focus_neighbor(SIDES[i])
			if next!=null and not next in seen: pending.append([next,entry[1]+[NAV[i]]])
	print("UNREACHABLE: ",target.get_class()," ",target.position," ",target.get("text"))
	return false
func named(title: String) -> Control:
	for child in game.career_screen.controls.get_children():
		if child is Button and child.text==title: return child
	return null
func capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw()
	if game.state=="playing": game.update_camera(0)
	for i in range(80): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/career-flow-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.ball.freeze=true
	game.match_menu.config_path="/tmp/sefc-career-flow-settings.cfg"
	var c=game.career; var ui=game.career_screen
	c.save_root="res://tests/career-flow.tmp"; DirAccess.make_dir_recursive_absolute(c.save_root)
	game.hud.sync_navigation()
	check(go(game.hud.nav_buttons[4]),"Career is reachable from the main menu by controller")
	tap(JOY_BUTTON_A)
	check(ui.visible and ui.page=="entry" and game.state=="career","Controller opens the save-slot screen and pauses the stadium")
	check(go(named("YENİ KARİYER")),"A new career slot is reachable")
	tap(JOY_BUTTON_A)
	var league: OptionButton=ui.controls.get_child(0)
	check(go(league),"The league selector is reachable")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.division==1 and focus().position==Vector2(52,170),"Changing division retains focus on its selector")
	var club_name: String=ui.new_world.clubs.c23.name
	check(go(named(club_name)),"A lower-league club card is reachable")
	tap(JOY_BUTTON_A)
	check(ui.selected_club=="c23" and focus().text==club_name,"Choosing a club preserves the controller focus")
	check(go(named("BU KULÜPLE BAŞLA")),"The start-career action is reachable")
	tap(JOY_BUTTON_A)
	if ui.overwrite: tap(JOY_BUTTON_A)
	check(ui.page=="hub" and c.world.user=="c23","The chosen lower-league career starts from controller input")
	for page in ui.PAGES:
		ui.go(page); game.controller.menus.sync()
		var all_reachable:=true
		for control in ui.controls.get_children():
			if control is BaseButton and not control.disabled: all_reachable=go(control) and all_reachable
		check(all_reachable,"Every enabled action is reachable on career page: "+page)
	ui.go("squad"); game.controller.menus.sync()
	var row: Control
	for control in ui.controls.get_children():
		if control is Button and str(control.get_meta("focus_key",""))=="player:"+str(ui.list_ids[1]): row=control
	check(go(row),"A squad row can be selected with the pad")
	tap(JOY_BUTTON_A)
	check(str(focus().get_meta("focus_key",""))=="player:"+str(ui.list_ids[1]),"Selecting a player does not jump focus to the top tabs")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui.page=="tactics","RB moves to the next career tab")
	tap(JOY_BUTTON_Y)
	var formation: OptionButton
	for control in ui.controls.get_children():
		if control is OptionButton and control.position==Vector2(1100,228): formation=control
	check(go(formation),"Formation is reachable from the tactics page")
	tap(JOY_BUTTON_A)
	check(is_instance_valid(game.controller.menus.popup_option),"Controller A opens the formation popup")
	tap(JOY_BUTTON_DPAD_DOWN); tap(JOY_BUTTON_A)
	check(not formation.get_popup().visible and formation.selected==int(c.club().plan.formation),"Controller confirms and applies a tactical option")
	ui.go("market"); ui.market_filter=3; ui.build()
	check(ui.list_ids.is_empty() and ui.selected=="","An empty free-agent search remains usable")
	ui.market_filter=0; ui.build()
	var target: String=ui.list_ids[-1]
	ui.selected=target; ui.negotiate(false); game.controller.menus.sync()
	check(go(named("TEKLİFİ SUN")),"The offer action is reachable in the 3D negotiation room")
	var owner: String=c.player(target).club; c.club().cash=40000000; c.club().budget=30000000
	ui.fee=c.World.value(c.player(target))*2
	tap(JOY_BUTTON_A)
	check(c.deal.stage=="contract" and c.player(target).club==owner,"The club negotiation proceeds without prematurely transferring ownership")
	ui.wage=25000; ui.promised=2
	check(go(named("TEKLİFİ SUN")),"The player contract offer is reachable")
	tap(JOY_BUTTON_A)
	check(c.deal.stage=="sign","Player agreement opens the signature summary")
	check(go(named("ANLAŞMAYI İMZALA")),"Final signature is reachable by controller")
	tap(JOY_BUTTON_A)
	check(c.deal.signed and c.player(target).club==c.world.user,"Controller confirmation completes the transfer exactly once")
	await capture("signed")
	ui.open_hub(); var f: Dictionary=c.next_fixture(); c.world.date=f.day
	# Start with fatigue on a real bench member so substitution cannot silently refill it.
	ui.play()
	check(game.frontend.visible and game.state=="setup" and not ui.visible,"Career match preparation enters the normal pre-match flow")
	var bench_roles: Array=[]
	for player in game.management.bench[0]: bench_roles.append(player.role)
	check(bench_roles.has(0) and bench_roles.has(1) and bench_roles.has(2) and bench_roles.has(3),"The match bench covers keeper, defence, midfield and forward roles")
	await capture("prematch")
	game.frontend.confirm(); game.ceremony.finish(true)
	game.ball.freeze=false
	for frame in range(30):
		game._physics_process(1.0/120.0)
		await physics_frame
	tap(JOY_BUTTON_A)
	for frame in range(600):
		game._physics_process(1.0/120.0)
		await physics_frame
	check(game.match_time>0 and c.in_match and game.players[9].career_id!="","The actual 3D career match simulates and advances its match clock")
	await capture("playing")
	game.frontend.open_tactics(); ui.open_live_tactics()
	var before: float=game.match_time
	for frame in range(20): game._physics_process(1.0/120.0)
	check(game.match_time==before and game.ball.freeze,"Detailed live tactics freeze both match time and ball physics")
	c.club().plan.width=2; c.club().plan.anchor=false; ui.close()
	check(game.state=="playing" and game.management.width==2 and not game.management.anchor,"Closing detailed tactics resumes the match with the new plan")
	game.ball.freeze=true; game.state="restart"; game.restart_type="TAÇ"
	var p=game.players[9]; var outgoing: String=p.career_id
	p.energy=.4; p.yellow_cards=1
	var incoming: String=game.management.bench[0][1].career_id; c.player(incoming).fitness=.61
	game.management.queue_sub(9,1); game.management.prepare_substitutions()
	# Put both actors at the exchange gate, then let the normal greeting and identity exchange run.
	p.position=Vector3(game.P.HALF_WIDTH+.8,0,7.8)
	if game.stadium.sidelines.entries.has(9):
		var entry: Dictionary=game.stadium.sidelines.entries[9]; entry.actor.position=entry.gate
	for frame in range(130):
		game.management.update_substitutions(1.0/120.0)
		await physics_frame
	check(p.career_id==incoming and is_equal_approx(p.energy,.61),"A real substitution applies the incoming player's saved fitness")
	check(c.match_recovery.has(outgoing) and outgoing in c.match_participants[0] and incoming in c.match_participants[0],"Both departing and entering identities remain in the match record")
	game.score=[1,0]; c.match_goals={incoming:1}; game.state="finished"
	check(c.finish_match(),"A career match completes after substitutions")
	check(c.player(outgoing).appearances==1 and c.player(outgoing).fitness<.6 and c.player(outgoing).yellow==1,"The outgoing player's appearance, fatigue and card persist")
	check(c.player(incoming).appearances==1 and c.player(incoming).goals==1,"The substitute is credited with the appearance and goal")
	ui.open_hub(); await capture("result-hub")
	check(ui.visible and f.played and not c.in_match,"Full time returns to the same career hub with its fixture recorded")
	ui.close()
	check(game.state=="menu" and game.camera.cull_mask!=0 and game.clubs.career_clubs.is_empty(),"Leaving career restores the normal stadium and quick-match catalogue")
	print("CAREER FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
