extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
const LABELS := ["ÖN DİREK","ARKA DİREK","CEZA YAYI","KISA PAS"]
var selected := -1
var runs: Dictionary = {}
var base: Dictionary = {}

func reset() -> void:
	selected=-1; runs.clear(); base.clear()

func available(setup) -> bool:
	return setup.game.restart_type in ["KORNER","SERBEST VURUŞ","ENDİREKT VURUŞ"] and setup.taker>=0

func select(setup,value: int) -> bool:
	if not available(setup) or setup.runup>=0 or value<0 or value>=LABELS.size(): return false
	var game=setup.game
	if base.is_empty(): base=setup.targets.duplicate()
	for i in base: setup.targets[i]=base[i]
	selected=value; runs.clear()
	var point: Vector3=game.restart_point
	var forward: float=game.attack_sign(game.restart_team)
	var side: float=-1 if point.x<0 else 1
	var attack: Array[int]=[]
	for i in setup.targets:
		var p=game.players[i]
		if i!=setup.taker and p.team==game.restart_team and not p.keeper and p.visible and not p.dismissed: attack.append(i)
	attack.sort_custom(func(a,b): return game.management.slot_role(a)>game.management.slot_role(b) if game.management.slot_role(a)!=game.management.slot_role(b) else a>b)
	var near := Vector3(side*3.8,0,forward*44)
	var far := Vector3(-side*4.5,0,forward*43)
	var edge := Vector3(side*1.5,0,forward*31)
	var short := point+Vector3(-side*6,0,-forward*4)
	var destinations: Array[Vector3]=[near,far,edge,short]
	if value==2:
		destinations[0].x=side*6; destinations[1].x=-side*6
	elif value==3:
		destinations[0]=short+Vector3(-side*5,0,-forward*6)
		destinations[2]=Vector3(-side*11,0,forward*33)
	# For a distant free kick, the same requests become playable local lanes.
	if point.z*forward<15:
		for j in range(3): destinations[j].z=point.z+forward*(16 if j<2 else 9)
	var order: Array=[value]
	for j in range(4):
		if j!=value: order.append(j)
	for j in range(mini(4,attack.size())):
		var i: int=attack[j]
		var destination: Vector3=destinations[order[j]]
		destination.x=clampf(destination.x,-P.HALF_WIDTH+2,P.HALF_WIDTH-2)
		destination.z=clampf(destination.z,-46,46)
		# Stage a few steps away; the run begins with the taker's approach.
		var staging: Vector3=destination-Vector3(0,0,forward*(3 if order[j]<2 else 1.5))
		if j==0 and value==0: staging=destination+Vector3(side*3,0,-forward*4)
		elif j==0 and value==1: staging=destination+Vector3(side*5,0,-forward*4)
		elif j==0 and value==2: staging=destination+Vector3(0,0,forward*5)
		if order[j]==3: staging=destination
		setup.targets[i]=legal(setup,staging)
		runs[i]=legal(setup,destination)
	return true

func legal(setup,point: Vector3) -> Vector3:
	point=setup.outside_circle(point,setup.game.restart_point,2.2)
	for member in setup.wall: point=setup.outside_circle(point,setup.targets[member],1.7)
	if setup.game.restart_type!="KORNER":
		var forward: float=setup.game.attack_sign(setup.game.restart_team)
		point.z=forward*minf(point.z*forward,maxf(0,setup.game.rules.offside_line(setup.game.restart_team)-.9))
	return point

func start(setup) -> void:
	for i in runs: setup.targets[i]=legal(setup,runs[i])

func launch(setup) -> void:
	for i in runs:
		if setup.game.players[i].visible and not setup.game.players[i].dismissed:
			setup.game.support.assign_run(i,runs[i],"set_piece_run",2.4)

func draw(hud,setup) -> void:
	if not available(setup): return
	var at: Vector2=Vector2(922,728)+setup.game.ui.edge_offset(1,1)
	hud.panel(Rect2(at,Vector2(310,104)),Color("10282e",.94),5)
	hud.text("ORGANİZASYON",at+Vector2(14,20),12,hud.GOLD,true)
	for i in range(4):
		var x: int=i%2
		var y: int=i/2
		var label: String=(["LB + ↑","LB + →","LB + ↓","LB + ←"][i] if setup.game.controller.using_gamepad else str(i+1))+"  "+LABELS[i]
		if setup.game.controller.family=="playstation": label=label.replace("LB","L1")
		hud.text(label,at+Vector2(14+x*148,43+y*23),11,hud.GOLD if i==selected else hud.PAPER,i==selected)
	var cancel_label := "İPTAL: L1 + R1" if setup.game.controller.family=="playstation" else "İPTAL: LB + RB"
	hud.text(cancel_label if setup.game.controller.using_gamepad else "İPTAL: B",at+Vector2(14,92),10,hud.MUTE)
