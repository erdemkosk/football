extends RefCounted
var game
var passer := -1
var pass_age := 10.0
var shooter := -1
var shot_age := 10.0
var shot_counted := false

func reset() -> void:
	passer=-1; shooter=-1; pass_age=10; shot_age=10
	shot_counted=false
	for p in game.players: p.reaction.reset()

func update(delta: float) -> void:
	pass_age+=delta; shot_age+=delta
	for p in game.players:
		p.reaction.live=game.state=="playing"
		p.reaction.ball_position=game.ball.position

func kicked(index: int,kind: String) -> void:
	if kind=="shot": shooter=index; shot_age=0; passer=-1; shot_counted=false
	elif kind in ["kick","cross"]: passer=index; pass_age=0; shooter=-1

func received(index: int) -> void:
	if shooter>=0 and index!=shooter: shooter=-1
	if passer<0 or pass_age>5 or passer==index: return
	if game.players[passer].team!=game.players[index].team:
		game.players[passer].reaction.begin("sorry",game.ball.position)
	passer=-1

func out(team: int) -> void:
	if shooter>=0 and shot_age<6:
		game.players[shooter].reaction.begin("miss",game.ball.position)
		game.broadcast.offer("miss",shooter)
	elif passer>=0 and pass_age<5 and game.players[passer].team!=team:
		game.players[passer].reaction.begin("sorry",game.ball.position)
	shooter=-1; passer=-1

func captain_index(team: int) -> int:
	var fallback := -1
	for i in range(game.players.size()):
		var p=game.players[i]
		if p.team!=team or not p.visible or p.keeper or p.official or p.dismissed: continue
		if p.shirt_number==10: return i
		if fallback<0: fallback=i
	return fallback

func appeal(index: int,point: Vector3=Vector3.ZERO) -> void:
	if index<0 or game.training: return
	var origin: Vector3=point if point!=Vector3.ZERO else game.players[index].position
	_signal_around(index,origin,"appeal",2)

func dispute(victim: int,offender: int) -> void:
	if game.training: return
	appeal(victim,game.players[offender].position)
	var cap := captain_index(game.players[offender].team)
	if cap>=0 and cap!=offender: game.players[cap].reaction.begin("captain",game.players[victim].position)

func _signal_around(index: int,point: Vector3,kind: String,extra: int) -> void:
	game.players[index].reaction.begin(kind,point)
	var added := 0
	var order: Array[int]=[]
	for i in range(game.players.size()):
		if i==index: continue
		var q=game.players[i]
		if q.visible and q.team==game.players[index].team and not q.keeper and q.reaction.available(q):
			order.append(i)
	order.sort_custom(func(a,b): return game.flat_distance(game.players[a].position,point)<game.flat_distance(game.players[b].position,point))
	for i in order:
		if added>=extra: break
		if game.flat_distance(game.players[i].position,point)>16: break
		game.players[i].reaction.begin(kind,point)
		added+=1

func on_target(team: int) -> void:
	# A parry and the subsequent goal belong to the same shot.
	if shooter<0 or shot_counted or shot_age>8 or game.players[shooter].team!=team: return
	game.shots_on_target[team]+=1
	shot_counted=true

func save_on_target(index: int,incoming: Vector3) -> bool:
	if shooter<0 or shot_counted or shot_age>8 or game.players[shooter].team==game.players[index].team: return false
	var goal_z: float=game.attack_sign(game.players[shooter].team)*50
	if incoming.z*goal_z<=0: return false
	var route: Dictionary=preload("res://scripts/shot_guide.gd").predict(game.ball.position,incoming,game.ball.spin,goal_z,game.weather)
	return route.on_target

func saved(index: int,was_on_target: bool=false) -> void:
	game.match_report.saved(index)
	var keeper=game.players[index]
	if was_on_target: on_target(1-keeper.team)
	var candidates: Array[int]=[]
	for i in range(game.players.size()):
		var p=game.players[i]
		if p.visible and not p.keeper and p.team==keeper.team and game.flat_distance(p.position,keeper.position)<22: candidates.append(i)
	candidates.sort_custom(func(a,b): return game.flat_distance(game.players[a].position,keeper.position)<game.flat_distance(game.players[b].position,keeper.position))
	for i in candidates.slice(0,2): game.players[i].reaction.begin("applaud",keeper.position)
	shooter=-1
