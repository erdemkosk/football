extends RefCounted
var game
var passer := -1
var pass_age := 10.0
var shooter := -1
var shot_age := 10.0

func reset() -> void:
	passer=-1; shooter=-1; pass_age=10; shot_age=10
	for p in game.players: p.reaction.reset()

func update(delta: float) -> void:
	pass_age+=delta; shot_age+=delta
	for p in game.players:
		p.reaction.live=game.state=="playing"
		p.reaction.ball_position=game.ball.position

func kicked(index: int,kind: String) -> void:
	if kind=="shot": shooter=index; shot_age=0; passer=-1
	elif kind=="kick": passer=index; pass_age=0; shooter=-1

func received(index: int) -> void:
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

func saved(index: int) -> void:
	var keeper=game.players[index]
	var candidates: Array[int]=[]
	for i in range(game.players.size()):
		var p=game.players[i]
		if p.visible and not p.keeper and p.team==keeper.team and game.flat_distance(p.position,keeper.position)<22: candidates.append(i)
	candidates.sort_custom(func(a,b): return game.flat_distance(game.players[a].position,keeper.position)<game.flat_distance(game.players[b].position,keeper.position))
	for i in candidates.slice(0,2): game.players[i].reaction.begin("applaud",keeper.position)
	shooter=-1
