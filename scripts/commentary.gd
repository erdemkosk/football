extends RefCounted
## Turkish match commentary spoken by the operating system's own speech engine
## (DisplayServer TTS): no recordings are bundled and player names are read
## live. Calls follow real events; stale remarks are dropped, never queued.
const LINES = preload("res://scripts/commentary_lines.gd").LINES
const PRIORITY := {"goal":5,"own_goal":5,"red":5,"penalty":4,"fulltime":6,"halftime":6,"woodwork":3,"great_save":3,"handball":3,"kickoff":3,"second_half":3,"yellow":2,"injury":2,"shot_high":2,"shot_wide":2,"save":2,"offside":2,"corner":1,"free_kick":1,"substitution":1,"long_shot":1,"header":1,"volley":1,"cross":1,"shot":1,"skill":0}
# Real seconds, independent of match length and gameplay speed.
const GAP := 6.5
const REPEAT := {"goal":1.0,"own_goal":1.0,"red":1.0,"penalty":5.0,"woodwork":5.0,"great_save":8.0,"save":12.0,"shot_high":12.0,"shot_wide":12.0,"shot":12.0,"long_shot":14.0,"header":14.0,"volley":14.0,"cross":16.0,"corner":18.0,"free_kick":18.0,"offside":16.0,"skill":28.0,"counter":32.0,"wing_attack":50.0,"pressure":55.0,"build_up":60.0,"late_chase":65.0,"late_protect":65.0,"late_level":65.0,"fatigue":100.0,"rain":160.0}
var game
var enabled := true
var volume := .8
var subtitles := false
var voice := ""
var cooldown := 0.0
var recent: Dictionary = {}
var history: Array[String] = []
var subtitle := ""
var subtitle_time := 0.0
var last_priority := -1
var elapsed := 0.0
var spoken_at: Dictionary = {}
var bags: Dictionary = {}
var variation := RandomNumberGenerator.new()
var context_in := 14.0
var sample_age := 0.0
var observed_team := -1
var possession_age := 0.0
var wide_age := 0.0
var pressure_age := 0.0

func _init() -> void:
	# Commentary variety must not consume the match simulation's random stream.
	variation.randomize()

func reset() -> void:
	cooldown=0; recent.clear(); history.clear(); subtitle=""; subtitle_time=0; last_priority=-1
	elapsed=0; spoken_at.clear(); bags.clear(); context_in=14; sample_age=0
	clear_observation()
	stop()

func available() -> bool:
	return DisplayServer.get_name()!="headless" and enabled

func pick_voice() -> String:
	if voice!="": return voice
	var voices: PackedStringArray=DisplayServer.tts_get_voices_for_language("tr")
	if voices.is_empty(): voices=DisplayServer.tts_get_voices_for_language("en")
	if not voices.is_empty(): voice=voices[0]
	return voice

func eligible() -> bool:
	return enabled and not game.training and not game.menu_match.running and game.state not in ["paused","menu","replay"]

func speaking() -> bool:
	return DisplayServer.get_name()!="headless" and DisplayServer.tts_is_speaking()

func line_key(kind: String,data: Dictionary) -> String:
	if kind=="substitution" and data.has("out") and data.has("incoming"): return "substitution_named"
	if kind!="goal" or not data.has("team"): return kind
	var team := int(data.team)
	if team not in [0,1]: return kind
	# Goal events are emitted before the scoreboard increments.
	var margin: int=game.score[team]+1-game.score[1-team]
	var late: bool=game.match_time>=game.LENGTH*.82
	if margin==0: return "goal_late_level" if late else "goal_level"
	if margin==1: return "goal_late_lead" if late else "goal_lead"
	return "goal_extend" if margin>1 else "goal_reply"

func choose(key: String) -> String:
	var lines: Array=LINES[key]
	var bag: Array=bags.get(key,[])
	if bag.is_empty():
		for i in range(lines.size()): bag.append(i)
		for i in range(bag.size()-1,0,-1):
			var j := variation.randi_range(0,i)
			var swap: int=bag[i]; bag[i]=bag[j]; bag[j]=swap
		if bag.size()>1 and bag.back()==recent.get(key,-1):
			var swap: int=bag[0]; bag[0]=bag.back(); bag[bag.size()-1]=swap
		bags[key]=bag
	var index: int=bag.pop_back()
	recent[key]=index
	return lines[index]

func event(kind: String,data: Dictionary={}) -> bool:
	if not LINES.has(kind) or not eligible(): return false
	var priority: int=int(PRIORITY.get(kind,0))
	if elapsed-float(spoken_at.get(kind,-1000.0))<float(REPEAT.get(kind,6.5)): return false
	# A result may interrupt its build-up. Routine remarks never overlap,
	# and the speech engine must not queue a call for a position already over.
	if priority<4:
		if (cooldown>0 or speaking()) and (priority<=last_priority or priority<2): return false
	var values := data.duplicate()
	values["name"]=str(data.get("name","Oyuncu"))
	values["team"]=game.team_name(int(data.team)) if data.get("team",-1) in [0,1] else str(data.get("team_name","Takım"))
	var text: String=choose(line_key(kind,data)).format(values)
	spoken_at[kind]=elapsed
	say(text,priority)
	return true

func say(text: String,priority: int) -> void:
	history.append(text)
	if history.size()>40: history.pop_front()
	var duration := clampf(text.length()/15.0,1.8,6.5)
	subtitle=text; subtitle_time=duration+.8
	cooldown=maxf(GAP,duration+2.4); last_priority=priority
	context_in=variation.randf_range(12,18)
	if not available(): return
	var id := pick_voice()
	if id=="": return
	DisplayServer.tts_speak(text,id,clampi(roundi(volume*100),0,100),1.0,1.05,0,true)

func stop() -> void:
	if DisplayServer.get_name()!="headless": DisplayServer.tts_stop()
	subtitle=""; subtitle_time=0

func clear_observation() -> void:
	observed_team=-1; possession_age=0; wide_age=0; pressure_age=0

func observe(delta: float) -> void:
	var owner: int=game.dribbler if game.dribbler>=0 else game.carrier
	if owner<0 or owner>=game.players.size() or game.ball.held_by!=null:
		clear_observation(); return
	var p=game.players[owner]
	if not p.visible or p.dismissed or p.keeper or game.flat_distance(p.position,game.ball.position)>2 or game.ball.position.y>1.05 or game.ball.linear_velocity.length()>18:
		clear_observation(); return
	var team: int=p.team
	if team!=observed_team: clear_observation(); observed_team=team
	possession_age+=delta
	var depth: float=game.ball.position.z*game.attack_sign(team)
	wide_age=wide_age+delta if absf(game.ball.position.x)>20 and depth>5 else 0.0
	var attackers := 0
	for q in game.players:
		if q.visible and not q.dismissed and not q.keeper and q.team==team and q.position.z*game.attack_sign(team)>18 and absf(q.position.x)<28: attackers+=1
	pressure_age=pressure_age+delta if depth>25 and attackers>=3 else 0.0
	if context_in>0 or cooldown>0 or speaking(): return
	var kind := ""
	var margin: int=game.score[team]-game.score[1-team]
	if game.team_tactics.counter_time[team]>0 and p.velocity.z*game.attack_sign(team)>3 and depth<30: kind="counter"
	elif pressure_age>=3: kind="pressure"
	elif wide_age>=2.5: kind="wing_attack"
	elif game.match_time>=game.LENGTH*.82 and possession_age>=2:
		kind="late_level" if margin==0 else ("late_chase" if margin== -1 else ("late_protect" if margin>0 else ""))
	elif possession_age>=8 and depth<15: kind="build_up"
	if kind!="" and event(kind,{"team":team}): return
	# Secondary context is sparse and based on live conditions, not filler.
	var energy := 0.0
	var count := 0
	for q in game.players:
		if q.visible and not q.dismissed and not q.keeper and q.team==team:
			energy+=q.energy; count+=1
	if count>=7 and energy/count<.3 and event("fatigue",{"team":team}): return
	if game.weather.rain>.4 and possession_age>=3: event("rain")

func update(delta: float) -> void:
	if not eligible():
		if speaking() or subtitle_time>0: stop()
		clear_observation(); sample_age=0
		return
	elapsed+=delta
	cooldown=maxf(0,cooldown-delta)
	subtitle_time=maxf(0,subtitle_time-delta)
	if cooldown<=0 and not speaking(): last_priority=-1
	if game.state!="playing": clear_observation(); sample_age=0; return
	context_in=maxf(0,context_in-delta)
	sample_age+=delta
	if sample_age>=.5:
		observe(minf(sample_age,.5))
		sample_age=0

func draw(hud) -> void:
	if not enabled or not subtitles or subtitle_time<=0 or subtitle=="" or not eligible(): return
	var alpha: float=clampf(subtitle_time/.4,0,1)
	var width: float=hud.font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+36
	var at: Vector2=Vector2(720-width*.5,742)+game.ui.edge_offset(0,1)
	hud.panel(Rect2(at,Vector2(width,30)),Color(0.04,0.08,0.1,.78*alpha),6)
	hud.draw_string(hud.font,at+Vector2(18,21),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.96,0.94,0.87,alpha))
