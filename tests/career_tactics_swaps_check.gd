extends "res://tests/career_flow_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.ball.freeze=true
	var career=game.career; var ui=game.career_screen
	career.save_root="res://tests/tactics-career-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(career.save_root)
	check(career.new_career("c00",1),"A separate test career is created")
	ui.open_hub(); ui.go("tactics")
	game.controller.menus.sync()
	var start: Control=focus()
	check(start!=null and start.get_script()==ui.tactics.Card and start.on_pitch,"Tactics opens with a starter card focused")
	check(ui.tactics.focused==start.identity,"The detail strip follows the focused starter")
	var start_id: String=start.identity
	tap(JOY_BUTTON_DPAD_RIGHT)
	var moved: Control=focus()
	check(moved!=null and moved.get_script()==ui.tactics.Card and moved.identity!=start_id,"Direction changes the focused player instead of staying on the default card")
	check(ui.tactics.focused==moved.identity,"Player details follow the pad direction")
	tap(JOY_BUTTON_A)
	check(ui.tactics.selected==moved.identity and focus()!=null and focus().get("identity")==moved.identity,"A arms the focused player without jumping to the first card")
	tap(JOY_BUTTON_DPAD_LEFT)
	var other: Control=focus()
	check(other!=null and other.get("identity")!=moved.identity,"Direction still moves after the first selection")
	tap(JOY_BUTTON_B)
	check(ui.visible and ui.page=="tactics" and ui.tactics.selected=="","B cancels the first selection without leaving tactics")
	var initial: Array=career.club().lineup.duplicate()
	var reserve: String=ui.tactics.reserves(ui).filter(func(id): return not career.player(id).keeper)[0]
	ui.tactics.choose(ui,reserve); ui.tactics.choose(ui,initial[9])
	check(career.club().lineup[9]==reserve,"Career accepts a bench-first substitution")
	ui.tactics.undo(ui)
	ui.tactics.choose(ui,initial[1]); ui.tactics.choose(ui,initial[9])
	check(career.club().lineup[1]==initial[9] and career.club().lineup[9]==initial[1],"Career swaps two starters before a match")
	ui.tactics.undo(ui)
	check(career.club().lineup==initial,"Career undo restores the original starting eleven")
	ui.go("hub"); career.world.date=career.next_fixture().day
	ui.play(); game.frontend.confirm(); game.ceremony.finish(true)
	game.state="playing"; game.ball.freeze=false
	game.frontend.open_tactics(); ui.open_live_tactics()
	var first=game.players[1]; var second=game.players[9]
	first.energy=.35; first.yellow_cards=1
	var first_home: Vector3=first.home; var second_home: Vector3=second.home
	var before: Array=ui.tactics.lineup(ui).duplicate()
	game.management.used[0]=3
	ui.tactics.choose(ui,first.career_id); ui.tactics.choose(ui,second.career_id)
	check(first.number==10 and second.number==2 and first.home==second_home and second.home==first_home,"Detailed live career tactics swaps tactical assignments")
	check(first.energy==.35 and first.yellow_cards==1 and game.management.used[0]==3,"Live career position swap preserves condition, cards and substitution allowance")
	check(ui.tactics.lineup(ui)[9]==first.career_id and ui.tactics.lineup(ui)[1]==second.career_id,"Career cards appear at the new tactical positions")
	game.management.used[0]=0
	var bench_id: String=ui.tactics.reserves(ui).filter(func(id): return not career.player(id).keeper)[0]
	ui.tactics.choose(ui,bench_id); ui.tactics.choose(ui,first.career_id)
	check(game.management.pending.size()==1 and game.management.pending[0].slot==1,"Bench-first live substitution targets the correct actor after a position swap")
	ui.tactics.choose(ui,first.career_id); ui.tactics.undo(ui)
	check(game.management.pending.is_empty(),"Career cancellation still finds the repositioned player")
	ui.tactics.choose(ui,first.career_id); ui.tactics.choose(ui,second.career_id)
	check(ui.tactics.lineup(ui)==before,"Detailed tactics can swap both players back")
	ui.close()
	check(game.state=="playing" and not game.ball.freeze,"Closing detailed tactics resumes live play")
	var save_path: String=career.path_for(1)
	var save_root: String=career.save_root
	game.free()
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(save_path+suffix)
	DirAccess.remove_absolute(save_root)
	print("CAREER TACTICS SWAPS CHECK: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
