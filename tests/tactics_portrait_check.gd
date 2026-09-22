extends SceneTree
var game
var screen
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func loaded() -> void:
	for i in range(240):
		await process_frame
		if screen.portraits.pending.is_empty() and screen.portraits.studio==null: return
func capture(label: String) -> void:
	screen.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/tactics-"+label+".png")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Portrait rendering requires a graphical Godot run."); quit(1); return
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_physics_process(false); game.set_process(false)
	screen=game.frontend; screen.open_selection(); screen.open_tactics(true)
	await loaded()
	var all_ready := true
	var keys: Array[String]=[]
	for card in screen.slot_buttons+screen.reserve_buttons:
		var photo: Texture2D=screen.portraits.photo(card.data)
		all_ready=all_ready and photo!=null and photo.get_size()==Vector2(256,256)
		keys.append(card.portrait_key)
	check(all_ready and screen.portraits.cache.size()==18,"All eleven starters and seven substitutes have rendered 256px model portraits")
	var unique: Dictionary={}
	for key in keys: unique[key]=true
	check(unique.size()==18,"Portraits use player and kit identity rather than one shared placeholder")
	check(screen.portraits.studio==null and screen.portraits.get_child_count()==0,"Finished portraits release their 3D studio and leave only cached images")
	var groups: Array[int]=[]
	for card in screen.reserve_buttons: groups.append(card.data.group)
	check(groups==[0,1,1,2,2,3,3],"The bench clearly identifies goalkeeper, defenders, midfielders and forwards")
	for formation in range(3):
		screen.set_tactic("formation",formation); screen.set_pane(0)
		await loaded()
		var ready := true
		for card in screen.slot_buttons:
			ready=ready and card.data.position_label in screen.GROUPS and screen.portraits.photo(card.data)!=null
		check(ready and screen.portraits.cache.size()==18,"Formation changes retain portraits and update positions, formation="+str(formation))
		screen.preview_reserve=-1; screen.slot_buttons[9].grab_focus()
		await capture(["442","433","352"][formation])
	screen.set_pane(1); await capture("plan")
	screen.set_pane(0)
	screen.select_slot(9); screen.select_reserve(2)
	await loaded()
	check(screen.slot_buttons[9].data.name==game.players[9].display_name and screen.portraits.photo(screen.slot_buttons[9].data)!=null,"A swap updates portrait identity as well as shirt, name and body measurements")
	screen.undo_last(); await loaded()
	check(screen.slot_buttons[9].portrait_key==keys[9],"Undo restores the original cached player photo")
	screen.visible=false
	for i in range(4): await process_frame
	check(screen.portraits.studio==null,"No portrait camera keeps rendering after returning to the match")
	print("TACTICS PORTRAIT CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
