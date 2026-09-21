extends RefCounted
## Run the real match behind the menu without exposing its phase to UI/input.
var game
var phase := "playing"
var running := false

func update(delta: float) -> void:
	running=true
	game.state=phase
	game.simulate_match(delta)
	phase=game.state
	# The synchronous match tick may return early for a whistle or a goal.
	# Always restore the menu before input, rendering or camera updates run.
	game.state="menu"
	running=false
	if phase=="finished": game.start_match(false,false,true)
	for p in game.players:
		p.chosen=false
		p.marker.visible=false
	game.toast=""
	game.toast_timer=0
