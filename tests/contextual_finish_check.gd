extends "res://tests/volley_check.gd"
const Context = preload("res://scripts/contextual_finish.gd")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	p=game.players[9]
	await reset(Vector3(0,1.9,1.8),Vector3(0,-.2,-8))
	p.facing=Vector3.BACK; p.rig.rotation.y=PI; p.attributes.finishing=90
	var point: Vector3=p.position+Vector3(0,1.6,.4)
	check(Context.technique(game,p,point,Vector3.FORWARD*8,Vector3.FORWARD,.2,false)=="bicycle","Back-to-goal high ball with space selects bicycle")
	p.energy=.2
	check(Context.technique(game,p,point,Vector3.FORWARD*8,Vector3.FORWARD,.2,false)!="bicycle","Exhausted players do not attempt acrobatics")
	p.energy=1
	var defender=game.players[2]
	defender.visible=true; defender.position=p.position+Vector3.RIGHT
	check(Context.technique(game,p,point,Vector3.FORWARD*8,Vector3.FORWARD,.2,false)!="bicycle","Nearby opponent prevents a dangerous overhead attempt")
	defender.visible=false
	check(Context.technique(game,p,p.position+Vector3(.4,.9,-.3),Vector3.RIGHT*9,Vector3.FORWARD,.2,false)=="side_volley","Lateral cross selects side volley")
	check(Context.technique(game,p,p.position+Vector3(0,.5,-.3),Vector3.UP*3,Vector3.FORWARD,.2,true)=="half_volley","Real bounce selects half volley")
	print("BICYCLE PLAN: ",game.volleys.window(9,Vector3.FORWARD))
	check(game.volleys.arm(9,Vector3.FORWARD,.65,false),"Overhead intent can be armed against actual ball flight")
	await tick(140)
	print("BICYCLE CONTACT: ",contacts," gap=",contact_gap," kind=",contact_kind)
	check(contacts==1 and contact_kind=="bicycle" and contact_gap<.4,"Overhead shot requires actual animated boot contact")
	check(p.action_timer==0 and p.pose=="run","Overhead recovery returns to locomotion")
	check(absf(p.rig.rotation.x)<.1 and absf(p.rig.rotation.z)<.1,"Recovery clears acrobatic body rotation")
	print("CONTEXTUAL FINISH: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
