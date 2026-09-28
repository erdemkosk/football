extends RefCounted
## Two recorded Turkish voices share one channel. Only a relevant reply may
## follow a call; new play cancels it. System speech remains an optional fallback.
const LINES = preload("res://scripts/commentary_lines.gd").LINES
const VOICE_BANK = preload("res://scripts/commentary_voice_bank.gd").CUES
const PRIORITY := {"goal":5,"own_goal":5,"red":5,"penalty":4,"fulltime":6,"halftime":6,"woodwork":3,"great_save":3,"kickoff":3,"second_half":3,"yellow":2,"injury":2,"shot_high":2,"shot_wide":2,"save":2,"offside":2,"corner":1,"free_kick":1,"substitution":1,"long_shot":1,"header":1,"volley":1,"cross":1,"shot":1,"skill":0}
# Real seconds, independent of match length and gameplay speed.
const GAP := 6.5
const REPEAT := {"goal":1.0,"own_goal":1.0,"red":1.0,"penalty":5.0,"woodwork":5.0,"great_save":8.0,"save":12.0,"shot_high":12.0,"shot_wide":12.0,"shot":12.0,"long_shot":14.0,"header":14.0,"volley":14.0,"cross":16.0,"corner":18.0,"free_kick":18.0,"offside":16.0,"skill":28.0,"counter":32.0,"wing_attack":50.0,"pressure":55.0,"build_up":60.0,"late_chase":65.0,"late_protect":65.0,"late_level":65.0,"fatigue":100.0,"rain":160.0}
var game
var enabled := true
var volume := 1.0
var subtitles := false
var recorded := true
var analyst_enabled := true
var voice := ""
var playback: AudioStreamPlayer
var stream_cache: Dictionary = {}
var current_role := ""
var current_kind := ""
var current_context: Dictionary = {}
var pending_reply: Dictionary = {}
var reply_wait := -1.0
var next_dialogue := 0.0
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
	elapsed=0; spoken_at.clear(); bags.clear(); context_in=14; sample_age=0; next_dialogue=0
	clear_observation()
	stop()

func available() -> bool:
	return DisplayServer.get_name()!="headless" and enabled

func pick_voice() -> String:
	if voice!="": return voice
	var voices: PackedStringArray=DisplayServer.tts_get_voices_for_language("tr")
	if not voices.is_empty(): voice=voices[0]
	return voice

func eligible() -> bool:
	return enabled and not game.training and not game.menu_match.running and game.state in ["playing","restart","set_piece","goal","halftime","finished","ceremony"]

func speaking() -> bool:
	return (is_instance_valid(playback) and playback.playing) or (DisplayServer.get_name()!="headless" and DisplayServer.tts_is_speaking())

func ensure_playback() -> void:
	if is_instance_valid(playback): return
	playback=AudioStreamPlayer.new()
	playback.name="MatchCommentary"
	playback.max_polyphony=1
	game.audio.add_child(playback)
	playback.finished.connect(on_voice_finished)
	game.audio.silence_commentary.connect(stop)

func recorded_stream(path: String) -> AudioStream:
	if path=="": return null
	if stream_cache.has(path): return stream_cache[path]
	if not ResourceLoader.exists(path): return null
	var stream := load(path) as AudioStream
	if stream==null or stream.get_length()<=0: return null
	# A bounded cache keeps long matches from retaining the entire voice library.
	if stream_cache.size()>=32: stream_cache.erase(stream_cache.keys()[0])
	stream_cache[path]=stream
	return stream

func cancel_reply() -> void:
	pending_reply.clear(); reply_wait=-1

func on_voice_finished() -> void:
	# finished is emitted only for natural completion, never for an interruption.
	if not pending_reply.is_empty(): reply_wait=variation.randf_range(.35,.65)
	if is_instance_valid(game): game.audio.commentary_active=false

func reply_context(kind: String,data: Dictionary) -> Dictionary:
	var expected_score: Array=game.score.duplicate()
	var team := int(data.get("team",-1))
	if kind in ["goal","own_goal"] and team in [0,1]: expected_score[team]+=1
	return {"kind":kind,"team":team,"score":expected_score,"half":game.half,"expires":elapsed+9.0}

func reply_relevant(context: Dictionary,check_age: bool=true) -> bool:
	if not eligible() or not analyst_enabled or not recorded or game.audio.muted or volume<=0: return false
	if context.is_empty() or game.score!=context.score or game.half!=context.half: return false
	if check_age and elapsed>float(context.expires): return false
	var kind: String=context.kind
	if kind in ["goal","own_goal"]: return game.state=="goal"
	if kind=="halftime": return game.state=="halftime"
	if kind=="fulltime": return game.state=="finished"
	if game.state not in ["playing","restart","set_piece"]: return false
	if kind=="rain": return game.weather.rain>.4
	if not PRIORITY.has(kind):
		var team: int=context.team
		var owner: int=game.dribbler if game.dribbler>=0 else game.carrier
		if team not in [0,1] or owner<0 or owner>=game.players.size(): return false
		var p=game.players[owner]
		if p.team!=team or not p.visible or p.dismissed or p.keeper or game.ball.held_by!=null or game.flat_distance(p.position,game.ball.position)>2: return false
		var depth: float=game.ball.position.z*game.attack_sign(team)
		if kind=="counter": return game.team_tactics.counter_time[team]>0 and p.velocity.z*game.attack_sign(team)>3
		if kind=="wing_attack": return absf(game.ball.position.x)>20 and depth>5
		if kind=="build_up": return depth<15
		if kind=="pressure": return depth>25
	return true

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
	return lines[choose_index(key,lines.size())]

func choose_index(key: String,count: int) -> int:
	var bag: Array=bags.get(key,[])
	if bag.is_empty():
		for i in range(count): bag.append(i)
		for i in range(bag.size()-1,0,-1):
			var j := variation.randi_range(0,i)
			var swap: int=bag[i]; bag[i]=bag[j]; bag[j]=swap
		if bag.size()>1 and bag.back()==recent.get(key,-1):
			var swap: int=bag[0]; bag[0]=bag.back(); bag[bag.size()-1]=swap
		bags[key]=bag
	var index: int=bag.pop_back()
	recent[key]=index
	return index

func event(kind: String,data: Dictionary={}) -> bool:
	if not LINES.has(kind) or not eligible(): return false
	var priority: int=int(PRIORITY.get(kind,0))
	# Even a call dropped during a goal invalidates analysis of the old position.
	if kind!=current_kind and priority>=1: cancel_reply()
	# A duplicate call can stay silent, but must still release the microphone.
	if current_role=="yorumcu" and priority>=1: stop()
	if elapsed-float(spoken_at.get(kind,-1000.0))<float(REPEAT.get(kind,6.5)): return false
	# A result may interrupt its build-up. Routine remarks never overlap,
	# and the speech engine must not queue a call for a position already over.
	if priority<4:
		if (cooldown>0 or speaking()) and (priority<=last_priority or priority<2): return false
	var key := line_key(kind,data)
	if recorded and VOICE_BANK.has(key):
		var cues: Array=VOICE_BANK[key]
		var cue: Dictionary=cues[choose_index("recorded:"+key,cues.size())]
		var stream := recorded_stream(cue.clip)
		if stream!=null:
			spoken_at[kind]=elapsed
			say(cue.text,priority,stream)
			current_kind=kind
			current_context=reply_context(kind,data)
			if analyst_enabled and elapsed>=next_dialogue and cue.reply!="" and not game.audio.muted and volume>0:
				pending_reply={"text":cue.reply,"clip":cue.reply_clip,"context":current_context.duplicate(true)}
			return true
	var values := data.duplicate()
	values["name"]=str(data.get("name","Oyuncu"))
	values["team"]=game.team_name(int(data.team)) if data.get("team",-1) in [0,1] else str(data.get("team_name","Takım"))
	var text: String=choose(key).format(values)
	spoken_at[kind]=elapsed
	say(text,priority)
	current_kind=kind
	return true

func say(text: String,priority: int,stream: AudioStream=null,role: String="spiker") -> void:
	stop()
	ensure_playback()
	history.append(text)
	if history.size()>40: history.pop_front()
	var duration := stream.get_length() if stream!=null else clampf(text.length()/15.0,1.8,6.5)
	current_role=role
	subtitle=text; subtitle_time=duration+.8
	cooldown=maxf(GAP,duration+2.4); last_priority=priority
	context_in=variation.randf_range(12,18)
	if game.audio.muted or volume<=0: return
	if stream!=null:
		playback.stream=stream
		playback.volume_db=linear_to_db(maxf(.0001,volume))
		playback.play()
		game.audio.commentary_active=true
		return
	if not available(): return
	var id := pick_voice()
	if id=="": return
	DisplayServer.tts_speak(text,id,clampi(roundi(volume*100),0,100),1.0,1.05,0,true)
	game.audio.commentary_active=true

func stop() -> void:
	if is_instance_valid(playback): playback.stop()
	if DisplayServer.get_name()!="headless": DisplayServer.tts_stop()
	if is_instance_valid(game): game.audio.commentary_active=false
	cancel_reply()
	current_role=""; current_kind=""; current_context.clear()
	subtitle=""; subtitle_time=0; cooldown=0; last_priority=-1

func update_dialogue(delta: float) -> void:
	if game.audio.muted or volume<=0:
		if speaking(): stop()
		cancel_reply()
		game.audio.commentary_active=false
		return
	if current_role=="yorumcu" and not reply_relevant(current_context,false): stop(); return
	if is_instance_valid(playback): playback.volume_db=linear_to_db(maxf(.0001,volume))
	game.audio.commentary_active=speaking()
	if pending_reply.is_empty(): return
	if not reply_relevant(pending_reply.context): cancel_reply(); return
	if speaking() or reply_wait<0: return
	reply_wait-=delta
	if reply_wait>0: return
	var reply: Dictionary=pending_reply.duplicate(true)
	cancel_reply()
	var stream := recorded_stream(reply.clip)
	if stream==null: return
	say(reply.text,0,stream,"yorumcu")
	current_context=reply.context
	next_dialogue=elapsed+20.0

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
		if speaking() or subtitle_time>0 or not pending_reply.is_empty(): stop()
		clear_observation(); sample_age=0
		return
	elapsed+=delta
	cooldown=maxf(0,cooldown-delta)
	subtitle_time=maxf(0,subtitle_time-delta)
	update_dialogue(delta)
	if speaking(): subtitle_time=maxf(subtitle_time,.8)
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
	var caption := ("YORUMCU  ·  " if current_role=="yorumcu" else "SPİKER  ·  ")+subtitle
	var width: float=hud.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+36
	var at: Vector2=Vector2(720-width*.5,742)+game.ui.edge_offset(0,1)
	hud.panel(Rect2(at,Vector2(width,30)),Color(0.04,0.08,0.1,.78*alpha),6)
	hud.draw_string(hud.font,at+Vector2(18,21),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.96,0.94,0.87,alpha))
