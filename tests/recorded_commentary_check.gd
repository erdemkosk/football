extends "res://tests/presentation_depth_check.gd"
## Recorded playback, completion-driven turn-taking and stale-dialogue cancellation.

class MissingRecordings:
	extends "res://scripts/commentary.gd"
	func recorded_stream(_path: String) -> AudioStream: return null
	func available() -> bool: return false

var c

func fixture() -> void:
	live_match()
	c=game.commentary
	c.enabled=true; c.recorded=true; c.analyst_enabled=true; c.volume=1; c.reset()
	c.variation.seed=43
	game.audio.muted=false; game.score=[0,0]; game.half=1; game.match_time=20
	game.carrier=-1; game.dribbler=-1
	game.ball.freeze=true; game.ball.release_hold()

func finish_voice() -> void:
	# Simulate the audio driver's completion, without tying scheduling tests to
	# wall-clock playback. A real completion is also exercised below.
	c.playback.stop()
	c.playback.finished.emit()

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-recorded-commentary.cfg"
	fixture()
	var clips := 0
	var valid := true
	for kind in c.LINES:
		valid=valid and c.VOICE_BANK.has(kind)
		for cue in c.VOICE_BANK.get(kind,[]):
			for field in ["clip","reply_clip"]:
				if cue[field]=="": continue
				var stream: AudioStream=c.recorded_stream(cue[field])
				valid=valid and stream is AudioStreamWAV and stream.get_length()>.3 and stream.get_length()<8 and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED
				clips+=1
	check(valid and clips==171,"All 171 recordings load, are finite and cover every commentary event")
	check(c.stream_cache.size()<=32,"Loading the library keeps a bounded runtime cache")
	for row in [[0,1,.3,"goal_level"],[0,0,.3,"goal_lead"],[2,0,.3,"goal_extend"],[0,3,.3,"goal_reply"],[0,0,.9,"goal_late_lead"],[0,1,.9,"goal_late_level"]]:
		fixture(); game.score=[row[0],row[1]]; game.match_time=game.LENGTH*row[2]
		c.event("goal",{"team":0})
		check(c.VOICE_BANK[row[3]].any(func(cue): return cue.text==c.subtitle),"The recording agrees with the actual score: "+row[3])
	fixture()
	var seen: Array[String]=[]
	for n in range(c.VOICE_BANK.corner.size()):
		c.event("corner"); seen.append(c.subtitle); c.stop(); c.elapsed+=20
	c.event("corner")
	check(seen.size()==3 and seen[0]!=seen[1] and seen[0]!=seen[2] and seen[1]!=seen[2] and c.subtitle!=seen.back(),"Recorded variants cycle without immediate repetition")
	fixture()
	var random_state: int=game.rng.state
	check(c.event("free_kick") and c.playback.playing and c.current_role=="spiker","A real recorded clip plays through the game's audio graph")
	# Choose an event where both variants have an answer.
	fixture(); c.event("penalty")
	var reply: Dictionary=c.pending_reply.duplicate(true)
	var expected_reply: String=reply.text
	var primary: String=c.subtitle
	c.update(.1)
	check(c.history.size()==1 and c.subtitle==primary,"The analyst cannot overlap an unfinished call")
	finish_voice(); c.update(.2)
	check(c.history.size()==1,"The two voices leave a short natural gap")
	c.update(.5)
	check(c.current_role=="yorumcu" and c.subtitle==expected_reply and c.playback.playing,"The paired answer starts after actual completion, with matching subtitles")
	check(c.playback.stream==c.recorded_stream(reply.clip),"The analyst uses its own recorded voice")
	check(c.event("shot") and c.current_role=="spiker" and c.pending_reply.is_empty(),"A new shot immediately takes the microphone back from analysis")
	check(game.rng.state==random_state,"Audio selection does not consume gameplay randomness")
	fixture(); c.event("penalty"); finish_voice(); c.update(.7)
	c.spoken_at.shot=c.elapsed
	check(not c.event("shot") and not c.playback.playing,"A repeat-suppressed shot still interrupts outdated analysis")
	fixture(); c.event("penalty"); c.elapsed=8; finish_voice(); c.update(.7); c.update(1)
	check(c.current_role=="yorumcu" and c.playback.playing,"An answer that started in time can finish beyond its scheduling deadline")
	fixture(); c.event("penalty"); finish_voice(); c.update(.7)
	finish_voice(); c.update(7)
	c.event("penalty")
	check(c.pending_reply.is_empty(),"Analysis leaves twenty seconds of breathing room between exchanges")
	fixture(); c.event("penalty")
	c.update(12)
	check(c.pending_reply.is_empty() and c.history.size()==1,"An unfinished or slow call never delivers an expired answer later")
	fixture(); c.event("penalty"); finish_voice()
	game.score=[1,0]; c.update(.7)
	check(c.pending_reply.is_empty() and c.history.size()==1,"A changed score invalidates a pending answer")
	fixture(); c.event("penalty"); finish_voice()
	game.half=2; c.update(.7)
	check(c.pending_reply.is_empty() and c.history.size()==1,"A changed half invalidates a pending answer")
	fixture(); c.event("penalty"); finish_voice()
	c.event("shot") # Suppressed by penalty priority, but invalidates the old analysis.
	c.update(.7)
	check(c.pending_reply.is_empty() and c.history.size()==1,"Even a suppressed new shot cancels analysis of the previous position")
	fixture(); game.last_kicker=9; game.goal(0)
	check(c.current_context.score==game.score and c.playback.playing,"The actual goal hook snapshots the post-goal score for its answer")
	finish_voice(); c.update(.7)
	check(c.current_role=="yorumcu","A goal answer is allowed during the celebration")
	for mode in ["paused","replay","menu","setup","career","training","disabled"]:
		fixture(); c.event("penalty"); finish_voice()
		if mode=="training": game.training=true
		elif mode=="disabled": c.enabled=false
		else: game.state=mode
		c.update(.7)
		check(c.pending_reply.is_empty() and not c.playback.playing and c.subtitle=="","No voice, answer or subtitle survives into "+mode)
	fixture(); c.event("penalty"); game.audio.toggle()
	check(not c.playback.playing and c.pending_reply.is_empty() and c.subtitle=="","Master mute stops speech immediately, including pending dialogue")
	game.audio.toggle(); c.update(1)
	check(not c.playback.playing and c.history.size()==1,"Unmute never resumes an old position")
	fixture(); c.event("penalty"); c.volume=0; c.update(.1)
	check(not c.playback.playing and c.pending_reply.is_empty() and not game.audio.commentary_active,"Zero commentary volume cancels playback and releases the crowd mix")
	fixture(); c.analyst_enabled=false; c.event("penalty"); finish_voice(); c.update(.7)
	check(c.current_role=="spiker" and c.history.size()==1,"Solo-spiker mode never starts the analyst")
	fixture(); c.event("penalty"); finish_voice(); c.update(.7); c.analyst_enabled=false; c.update(.1)
	check(not c.playback.playing and c.pending_reply.is_empty(),"Disabling the analyst also stops an answer already playing")
	fixture(); c.event("wing_attack",{"team":0})
	game.carrier=20; game.dribbler=20; finish_voice(); c.update(.7)
	check(c.pending_reply.is_empty() and c.history.size()==1,"A turnover cancels commentary about the previous team's attack")
	fixture(); c.event("penalty"); game.audio.update_atmosphere(.2,"playing")
	check(game.audio.commentary_duck<.7 and AudioServer.get_bus_volume_db(game.audio.stadium_bus)<-3,"Crowd layers fade down under commentary")
	c.stop(); game.audio.update_atmosphere(1,"playing")
	check(is_equal_approx(game.audio.commentary_duck,1) and is_zero_approx(AudioServer.get_bus_volume_db(game.audio.stadium_bus)),"The crowd mix recovers after speech without changing saved volume settings")
	fixture(); c.event("penalty"); c.volume=.25; c.update(.1)
	check(is_equal_approx(c.playback.volume_db,linear_to_db(.25)),"The volume slider controls recorded speech immediately")
	fixture()
	var fallback := MissingRecordings.new(); fallback.game=game
	check(fallback.event("goal",{"team":0,"name":"Deniz"}) and "Deniz" in fallback.subtitle and fallback.pending_reply.is_empty(),"Missing recordings safely fall back to dynamic text/system speech")
	fallback.stop()
	check(c.recorded_stream("res://assets/audio/commentary/not-present.wav")==null,"An absent optional recording is handled without a resource-loading error")
	fixture(); c.recorded=false; c.analyst_enabled=false; c.volume=.37; c.subtitles=true
	game.match_menu.save_settings()
	c.recorded=true; c.analyst_enabled=true; c.volume=1; c.subtitles=false
	game.match_menu.load_settings()
	check(not c.recorded and not c.analyst_enabled and is_equal_approx(c.volume,.37) and c.subtitles,"Voice mode, dialogue preference, volume and subtitles survive saving")
	fixture(); c.event("penalty")
	var deadline := Time.get_ticks_msec()+7000
	while c.current_role!="yorumcu" and Time.get_ticks_msec()<deadline:
		await create_timer(.05).timeout
		c.update(.05)
	check(c.current_role=="yorumcu" and c.playback.playing,"The real audio finished signal hands off to the analyst")
	c.stop()
	print("RECORDED COMMENTARY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
