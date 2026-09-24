extends RefCounted
## A brief blackout covers optional dead-ball skips; never advances match time.
var game
var age:=-1.0
var source:=""
var action: Callable
var applied:=false

func reset() -> void:
	age=-1; action=Callable(); source=""; applied=false

func request(next: Callable) -> void:
	if age>=0 or game.state in ["playing","paused","set_piece"]: return
	age=0; source=game.state; action=next; applied=false

func update(delta: float) -> bool:
	if age<0: return false
	if game.state=="paused": return true
	if not applied and game.state!=source: reset(); return false
	age+=delta
	if not applied and age>=.18:
		applied=true
		if action.is_valid(): action.call()
	if age>=.42: reset()
	return true

func alpha() -> float:
	if age<0: return 0
	return smoothstep(0,.18,age)*(1-smoothstep(.22,.42,age))

func restart_ready() -> void:
	game.stadium.sidelines.clear_fetch()
	game.set_pieces.snap_ready()
	# Throw-ins must still start with a real raised, held ball and legal spacing.
	if game.restart_type=="TAÇ":
		var p=game.players[game.set_pieces.taker]
		p.set_piece_pose="throw"; p.handling_blend=1; p.animate(.1)
		game.ball.hold(p); game.ball.hold_target=p.hand_center(); game.ball.position=p.hand_center()
		game.ball.reset_position=p.hand_center(); game.ball.pending_velocity=Vector3.ZERO
		game.set_pieces.ready()

func substitutions_ready() -> void:
	var m=game.management; var lines=game.stadium.sidelines
	for index in m.transit:
		var item: Dictionary=m.transit[index]
		if item.phase!="out": continue
		game.players[index].position=item.gate
		game.players[index].velocity=Vector3.ZERO
		item.erase("waypoint")
		if lines.entries.has(index):
			var entry: Dictionary=lines.entries[index]
			entry.actor.position=entry.gate; entry.actor.velocity=Vector3.ZERO
			entry.rise=.22; entry.aisle=true; entry.greet=true; entry.age=.36
	# Use the normal exchange path for identities, appearance/fitness records,
	# substitution limits, captaincy and the retained departing player.
	m.update_substitutions(.001)
	for index in m.transit:
		if m.transit[index].phase=="in":
			game.players[index].position=m.transit[index].target
			game.players[index].velocity=Vector3.ZERO; m.transit[index].erase("waypoint")
	m.update_substitutions(.001)
