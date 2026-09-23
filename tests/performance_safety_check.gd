extends "res://tests/ai_attack_check.gd"
const Motion=preload("res://scripts/ball_motion.gd")
const Identity=preload("res://scripts/team_identity.gd")

func original_travel_time(speed: float,distance: float,resistance: Vector2) -> float:
	var low := 0.0
	var high := Motion.stop_time(speed,resistance)
	for i in range(13):
		var middle := (low+high)*.5
		if Motion.distance_at(speed,middle,resistance)<distance: low=middle
		else: high=middle
	return (low+high)*.5

func run() -> void:
	var geometry=preload("res://scripts/geometry.gd")
	var parent:=Node3D.new(); root.add_child(parent)
	var material:=geometry.material(Color("cea47a"))
	var first=geometry.sphere(parent,.205,Vector3(0,.16,0),material); first.scale=Vector3(.86,1.1,.91)
	var second=geometry.sphere(parent,.045,Vector3(0,.15,-.181),material)
	var vertices: Array[Vector3]=[]
	var uv_count:=0
	for part in [first,second]:
		var arrays: Array=part.mesh.surface_get_arrays(0)
		for vertex in arrays[Mesh.ARRAY_VERTEX]: vertices.append(part.transform*vertex)
		uv_count+=arrays[Mesh.ARRAY_TEX_UV].size()
	var merged=geometry.combine_rigid(parent,[first,second],"test_head")
	var data: Array=merged.mesh.surface_get_arrays(0)
	var same: bool=data[Mesh.ARRAY_VERTEX].size()==vertices.size()
	if same:
		for i in range(vertices.size()): same=same and vertices[i].is_equal_approx(data[Mesh.ARRAY_VERTEX][i])
	check(same,"Merged rigid parts retain every transformed source vertex")
	check(data[Mesh.ARRAY_TEX_UV].size()==uv_count and merged.material_override==material and parent.get_child_count()==1,"Mesh batching preserves UVs and the material while removing duplicate draw instances")
	parent.free()
	var solver_matches := true
	for resistance in [Vector2(2,.12),Vector2(1.62,.12),Vector2(5.22,.34)]:
		for speed in [0.0,.1,1.0,4.0,12.0,24.0,40.0]:
			for distance in [0.0,.01,.5,2.0,12.0,35.0,80.0]:
				solver_matches=solver_matches and absf(Motion.travel_time(speed,distance,resistance)-original_travel_time(speed,distance,resistance))<1e-10
	check(solver_matches,"147 dry/wet/mud travel-time cases preserve the original physical solver")
	var plans_match := true
	for style in Identity.STYLES.keys()+["unknown"]:
		for saved in [{},{"width":0,"tempo":2,"formation":2}]:
			var club := {"style":style,"plan":saved}
			for key in Identity.SETTINGS: plans_match=plans_match and Identity.setting(club,key)==Identity.plan(club)[key]
	check(plans_match,"Direct tactical reads preserve every club style and saved career override")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup(); player(18,Vector3(10,0,14)); player(17,Vector3(-9,0,10))
	var route: Dictionary=game.Passing.plan(game.ball.position,game.players[18].position,Vector3.ZERO,false,game.weather)
	var read: Dictionary=game.ai_attack.delivery.assess(20,route,18)
	check(read.lane_risk==game.Passing.risk(game.ball.position,route,1,game.players),"Reused lane scoring stays separate from time-based interception safety")
	game.weather.select(0,true)
	var surface_matches := true
	for wet in [0.0,.2,.25,.4,.7,1.0]:
		game.weather.wetness=wet
		for point in [Vector3.ZERO,Vector3(0,0,47),Vector3(22,0,12),Vector3(45,0,4)]:
			surface_matches=surface_matches and Motion.profile(game.weather,point).is_equal_approx(Vector2(game.weather.ball_drag(point),game.weather.ball_rolling_damping(point)))
	check(surface_matches,"Combined resistance reads preserve actual weather and goalmouth mud")
	game.support.update(DT)
	check(game.support.targets.has(18),"Support plan includes an available teammate")
	var age: float=game.support.plan_age
	game.support.update(DT)
	check(game.support.plan_age<age,"Unchanged spatial planning is reused between physics ticks")
	game.players[2].position.z=4
	game.support.update(DT)
	var onside := true
	for target in game.support.targets.values(): onside=onside and target.z<=game.rules.offside_line(1)-.8+.001
	check(onside,"A defender stepping up clamps cached support to the current offside line immediately")
	possession(18); game.support.update(DT)
	check(game.support.plan_owner==18 and not game.support.targets.has(18) and game.support.targets.has(20),"A change of ball carrier rebuilds support on the same physics tick")
	game.players[17].visible=false; game.support.update(DT)
	check(not game.support.targets.has(17),"A departing player leaves the support plan immediately")
	game.players[17].visible=true; game.support.update(DT)
	check(game.support.targets.has(17),"A returning player joins the support plan immediately")
	game.players[17].dismissed=true; game.support.update(DT)
	check(not game.support.targets.has(17),"A sent-off player cannot retain a cached role")
	game.support.passed(20,18,true); game.support.update(DT)
	check(game.support.roles.get(20,"")=="one_two","An explicit one-two updates support immediately")
	game.support.runs[20].time=DT*.5; game.support.update(DT)
	check(not game.support.runs.has(20) and game.support.roles.get(20,"")!="one_two","An explicit run expires at physics rate between planning samples")
	game.clubs.career_clubs=[game.clubs.data(0).duplicate(true),game.clubs.data(1).duplicate(true)]
	game.clubs.career_clubs[1].plan={"width":0}
	game.support.update(DT)
	game.clubs.career_clubs[1].plan.width=2; game.support.update(DT)
	check(is_equal_approx(game.support.plan_age,game.support.PLAN_INTERVAL),"A changed tactical instruction invalidates support immediately")
	game.state="paused"; game.support.update(3)
	check(game.support.targets.is_empty() and game.support.plan_elapsed==0,"Pausing clears support without accumulating a stale planning time")
	game.state="playing"; game.weather.select(2,true)
	var p=game.players[20]
	p.kit_soil=0; p.update_soil(1); p.velocity=Vector3(3,0,0); p.action_timer=0
	for tick in range(120): p.stain(DT)
	check(p.kit_soil>0 and absf(p.kit_soil-p.shown_soil)<.0005,"Dirt continues accumulating at physics rate while uploaded colour stays within 0.05 percent")
	p.kit_soil=0; p.update_soil(0)
	check(p.shown_soil==0 and p.shown_wetness==0 and p.kit_materials.socks.get_shader_parameter("soil")==0,"An explicit kit reset updates materials immediately")
	print("PERFORMANCE SAFETY: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
