extends "res://tests/squad_management_check.gd"
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_physics_process(false); game.controller.device=0
	screen=game.frontend; screen.open_selection(); screen.open_tactics(true)
	print("PRE ",screen.stage," slots=",screen.slot_buttons.size()," size=",root.size," canvas=",game.ui.transform)
	await settle()
	print("SETTLE ",screen.stage," slots=",screen.slot_buttons.size()," state=",game.state)
	if screen.slot_buttons.size()>9:
		print("CLICK ",screen.slot_buttons[9].get_global_rect()," final=",root.get_final_transform())
		await click(screen.slot_buttons[9])
	print("POST ",screen.stage," slots=",screen.slot_buttons.size()," state=",game.state," selected=",screen.selected_slot," focus=",root.gui_get_focus_owner())
	quit()
