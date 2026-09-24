extends SceneTree
## Commentary lines follow real events with priorities and variety; instant
## replay plays the recent seconds and returns to the paused match intact.
const DT := 1.0/120
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func live_match() -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.state="playing"; game.menu_match.running=false; game.hud.hide()

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-presentation-depth.cfg"
	live_match()
	var c=game.commentary
	var name: String=String(game.players[9].display_name).capitalize()
	game.broadcast_event("goal",{"index":9,"team":0})
	check(not c.history.is_empty() and name in c.history.back(),"A goal is called with the scorer's name: "+str(c.history.back() if not c.history.is_empty() else ""))
	var count: int=c.history.size()
	game.broadcast_event("corner",{"team":1})
	check(c.history.size()==count,"Low-priority chatter waits while the goal call is still going")
	c.update(8.0)
	game.broadcast_event("corner",{"team":1})
	var first: String=c.history.back()
	c.update(8.0)
	game.broadcast_event("corner",{"team":1})
	check(c.history.size()==count+1,"Repeated corners leave breathing room after the first call")
	c.update(11.0)
	game.broadcast_event("corner",{"team":1})
	check(c.history.size()==count+2 and c.history.back()!=first,"Repeated events vary their phrasing")
	game.broadcast_event("red",{"index":14})
	check("kırmızı" in c.history.back().to_lower() or "atıl" in c.history.back().to_lower(),"A red card cuts in regardless of the pause between lines")
	# Real hooks: a restart and a booking produce calls.
	c.reset()
	var before: int=c.history.size()
	game.begin_restart("KORNER",0,Vector3(30,0,48))
	check(c.history.size()==before+1,"A corner restart is called by the commentator")
	live_match(); c.update(3.0)
	before=c.history.size()
	game.rules.book(14)
	check(c.history.size()==before+1 and "Sarı" in c.history.back() or "sarı" in c.history.back(),"A booking is called")
	# The menu exhibition and training stay silent.
	live_match(); c.update(3.0); game.menu_match.running=true
	before=c.history.size()
	game.broadcast_event("goal",{"index":9,"team":0})
	check(c.history.size()==before,"The menu exhibition has no commentary")
	game.menu_match.running=false
	# Instant replay from the pause menu.
	live_match()
	var ball=game.ball
	ball.freeze=false
	for n in range(360):
		ball.position=Vector3(sin(n*.02)*10,0.2,n*.05); game.players[9].position=ball.position+Vector3(0,0,.6)
		game.replay.capture(DT)
		await physics_frame
	var live_ball: Vector3=ball.position
	game.before_pause="playing"; game.state="paused"
	game.open_instant_replay()
	check(game.state=="replay" and game.replay.instant,"The pause menu opens an instant replay")
	check(game.replay.frames.size()>=int(game.replay.RATE*2),"The buffer holds several seconds of recent play")
	var frames: int=game.replay.frames.size()
	game.replay.slow=true
	check(is_equal_approx(game.replay.playback_speed(),.35),"Slow motion is available during the instant replay")
	game.replay.slow=false
	for n in range(2000):
		if game.state!="replay": break
		game.replay.update(DT)
	check(game.state=="paused" and game.before_pause=="playing","The replay returns to the paused match")
	check(ball.position.distance_to(live_ball)<.01 and game.replay.frames.size()==frames,"The live ball and the replay buffer are restored afterwards")
	# Goal replays still show only their last seconds.
	live_match()
	for n in range(int(game.replay.RATE*12)+5):
		game.replay.sample_age=1.0; game.replay.capture(DT)
	game.replay.begin()
	check(game.replay.frames.size()<=int(game.replay.RATE*game.replay.GOAL_SECONDS)+2,"A goal replay keeps its short five-second clip")
	game.replay.finish()
	print("PRESENTATION DEPTH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
