extends Node
const AMBIENCE = preload("res://assets/audio/stadium-ambience.mp3")
const CHEERING = preload("res://assets/audio/crowd-cheering.mp3")
const GOAL_CHEER = preload("res://assets/audio/goal-cheer.mp3")
const GOAL_ROAR = preload("res://assets/audio/goal-roar.mp3")
const WALKOUT = preload("res://assets/audio/walkout-crowd.mp3")
const REPLAY_CHANT = preload("res://assets/audio/replay-chant.mp3")
const FOUL_CHEER = preload("res://assets/audio/foul-cheer.mp3")
const CARD_CHEER = preload("res://assets/audio/card-cheer.mp3")
const MENU_THEME = preload("res://assets/audio/menu-theme.mp3")
const DRUMS = preload("res://assets/audio/crowd-drums.mp3")
const CHANTS := [
	preload("res://assets/audio/crowd-chant-english.mp3"),
	preload("res://assets/audio/crowd-chant-terrace.mp3"),
	preload("res://assets/audio/crowd-chant-old.mp3")]
const SWELLS := [
	preload("res://assets/audio/crowd-swell-1.mp3"),
	preload("res://assets/audio/crowd-swell-2.mp3"),
	preload("res://assets/audio/crowd-swell-3.mp3"),
	preload("res://assets/audio/crowd-swell-4.mp3")]
const PACKED := [
	preload("res://assets/audio/stadium-packed-1.mp3"),
	preload("res://assets/audio/stadium-packed-2.mp3"),
	preload("res://assets/audio/stadium-packed-3.mp3"),
	preload("res://assets/audio/stadium-packed-4.mp3")]
const MENU_LEVEL := -8.0
var stadium_volume := 1.0
var cheer_volume := 1.0
var drum_volume := 1.0
var ambience: AudioStreamPlayer
var cheering: AudioStreamPlayer
var roar: AudioStreamPlayer
var roar_age := 0.0
var roar_duration := 0.0
var roar_level := -4.0
var walkout: AudioStreamPlayer
var walkout_age := 0.0
var walkout_duration := 0.0
var replay_chant: AudioStreamPlayer
var replay_age := 0.0
var replay_duration := 0.0
var drums: AudioStreamPlayer
var chants: Array[AudioStreamPlayer] = []
var chant_wait: Array[float] = []
var chant_age: Array[float] = []
var chant_duration: Array[float] = []
var menu_music: AudioStreamPlayer
var menu_wanted := false
var menu_gain := 0.0
var drum_rng := RandomNumberGenerator.new()
var drum_wait := 0.0
var drum_age := 0.0
var drum_duration := 0.0
var match_audio := false
var paused := false
var ambience_gain := 0.0
var cheer_age := 0.0
var cheer_duration := 0.0
var cheer_level := -15.0
var cheer_priority := 0
var cheer_kind := ""
var cheer_cooldown := 0.0
var effects: AudioStreamPlayer
var net_impact: AudioStreamPlayer
var muted := false
var background := false
var crowd_lift := 0.0
var crowd_hush := 0.0
var crowd_danger := 0.0
var crowd_attack := 0
var swell_pressure := 0.0
var swells: Array[AudioStreamPlayer] = []
var swell_gain: Array[float] = []
var packed: Array[AudioStreamPlayer] = []
var score_margin := 0
var match_progress := 0.0

func crowd_context(home: float,danger: float,hush: float,margin: int,progress: float,attack_team: int=0) -> void:
	crowd_lift=clampf(danger*.7+maxf(0,home-.35)*.6,0,1)
	crowd_danger=clampf(danger,0,1)
	crowd_hush=hush; score_margin=margin; match_progress=progress; crowd_attack=attack_team
var clips: Dictionary = {}
var contacts: Array[AudioStreamPlayer] = []
var contact_cursor := 0

func _ready() -> void:
	drum_rng.randomize()
	drums=AudioStreamPlayer.new()
	drums.name="SupporterDrums"
	add_child(drums)
	var rhythm: AudioStreamMP3=DRUMS.duplicate()
	rhythm.loop=false
	drums.stream=rhythm
	drums.volume_db=-80
	for i in range(CHANTS.size()):
		var voice := AudioStreamPlayer.new()
		voice.name=["EnglishChant","TerraceChant","OldChant"][i]
		var phrase: AudioStreamMP3=CHANTS[i].duplicate()
		phrase.loop=false
		voice.stream=phrase
		voice.volume_db=-80
		add_child(voice)
		chants.append(voice)
		chant_wait.append(0.0)
		chant_age.append(0.0)
		chant_duration.append(0.0)
	for i in range(SWELLS.size()):
		var rise := AudioStreamPlayer.new()
		rise.name="CrowdSwell%d" % (i+1)
		var bed: AudioStreamMP3=SWELLS[i].duplicate()
		bed.loop=true
		rise.stream=bed
		rise.volume_db=-80
		add_child(rise)
		swells.append(rise)
		swell_gain.append(0.0)
	for i in range(PACKED.size()):
		var stand := AudioStreamPlayer.new()
		stand.name="PackedStadium%d" % (i+1)
		var packed_bed: AudioStreamMP3=PACKED[i].duplicate()
		packed_bed.loop=true
		stand.stream=packed_bed
		stand.volume_db=-80
		add_child(stand)
		packed.append(stand)
	ambience=AudioStreamPlayer.new()
	ambience.name="StadiumAmbience"
	add_child(ambience)
	var loop: AudioStreamMP3=AMBIENCE.duplicate()
	loop.loop=true
	ambience.stream=loop
	ambience.volume_db=-80
	menu_music=AudioStreamPlayer.new()
	menu_music.name="MenuTheme"
	add_child(menu_music)
	var theme: AudioStreamMP3=MENU_THEME.duplicate()
	theme.loop=true
	menu_music.stream=theme
	menu_music.volume_db=-80
	cheering=AudioStreamPlayer.new()
	cheering.name="CrowdCheering"
	add_child(cheering)
	var reaction: AudioStreamMP3=CHEERING.duplicate()
	reaction.loop=false
	cheering.stream=reaction
	cheering.volume_db=-80
	roar=AudioStreamPlayer.new()
	roar.name="GoalRoar"
	add_child(roar)
	var burst: AudioStreamMP3=GOAL_ROAR.duplicate()
	burst.loop=false
	roar.stream=burst
	roar.volume_db=-80
	walkout=AudioStreamPlayer.new()
	walkout.name="WalkoutCrowd"
	add_child(walkout)
	var tunnel: AudioStreamMP3=WALKOUT.duplicate()
	tunnel.loop=true
	walkout.stream=tunnel
	walkout.volume_db=-80
	replay_chant=AudioStreamPlayer.new()
	replay_chant.name="ReplayChant"
	add_child(replay_chant)
	var echo: AudioStreamMP3=REPLAY_CHANT.duplicate()
	echo.loop=false
	replay_chant.stream=echo
	replay_chant.volume_db=-80
	effects = AudioStreamPlayer.new()
	add_child(effects)
	clips.kick = synth("kick",0.13)
	clips.whistle=synth("whistle",0.65)
	clips.shot=synth("shot",0.24)
	clips.power=synth("power",0.38)
	clips.body_hit=synth("body_hit",0.30)
	clips.ball_tackle=synth("ball_tackle",0.18)
	clips.slide=synth("slide",0.40)
	clips.net=synth("net",0.72)
	net_impact=AudioStreamPlayer.new()
	net_impact.name="NetImpact"
	net_impact.stream=clips.net
	add_child(net_impact)
	for i in range(4):
		var channel := AudioStreamPlayer.new()
		add_child(channel)
		contacts.append(channel)
	effects.volume_db = -11

func synth(kind: String, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var count = int(sample_rate*duration)
	var data = PackedByteArray()
	data.resize(count*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 73
	var low = 0.0
	var fabric = 0.0
	for i in range(count):
		var t = float(i)/sample_rate
		var n = rng.randf_range(-1,1)
		low = lerpf(low,n,0.08)
		fabric=lerpf(fabric,n,0.24)
		var value = 0.0
		match kind:
			"kick": value = (sin(TAU*(100*t-80*t*t))*0.6+low*0.8+n*0.11)*exp(-t*35)
			"whistle": value = (sin(TAU*2300*t+sin(t*42)*2)+sin(TAU*2850*t)*0.22)*0.22*minf(t*50,1)*minf((duration-t)*20,1)
			"shot": value = sin(TAU*(108*t-105*t*t))*0.68*exp(-t*24)+low*1.2*exp(-t*36)+n*0.23*exp(-t*130)
			"power": value = sin(TAU*(48*t-22*t*t))*0.9*exp(-t*12)+low*1.7*exp(-t*9)+n*0.10*exp(-t*28)
			"body_hit": value = sin(TAU*(65*t-35*t*t))*0.55*exp(-t*19)+low*1.4*exp(-t*15)+n*0.16*exp(-t*55)
			"ball_tackle": value = sin(TAU*145*t)*0.46*exp(-t*34)+n*0.20*exp(-t*45)+low*0.8*exp(-t*20)
			"slide": value = (low*0.7+n*0.06)*sin(PI*t/duration)*exp(-t*3)
			"rain": value = n*0.13+low*0.7
			"net":
				# A padded ball thump, taut cord snap and a soft fabric tail.
				# Band-limited noise and smooth ends avoid a click or hiss loop.
				var snap: float=(fabric-low)*0.65*exp(-t*48)
				var thump := sin(TAU*(88*t-38*t*t))*0.48*exp(-t*24)
				var rustle: float=(fabric-low)*0.30*(0.65+0.35*cos(t*39))*exp(-t*6.5)
				value=(snap+thump+rustle)*smoothstep(0,0.003,t)*smoothstep(0,0.12,duration-t)
		data.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	if kind=="rain":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav

func play(kind: String) -> void:
	if muted or background: return
	effects.stream = clips[kind]
	effects.play()

func contact(kind: String,strength: float=0.5,proximity: float=1.0) -> void:
	if muted or background: return
	var channel := contacts[contact_cursor]
	contact_cursor=(contact_cursor+1)%contacts.size()
	channel.stream=clips[kind]
	channel.pitch_scale=lerpf(1.09,0.94,strength)
	channel.volume_db=lerpf(-19,-8,strength)+linear_to_db(maxf(0.05,proximity))
	channel.play()

func net_contact(strength: float,scored: bool) -> void:
	if muted or background or paused: return
	# Keep the shot, crowd recording and net on independent channels.
	net_impact.pitch_scale=lerpf(1.14,0.88,strength)
	net_impact.volume_db=lerpf(-16,-6.5,strength)-(0.0 if scored else 3.0)
	net_impact.play()

func toggle() -> void:
	muted = not muted
	if muted:
		ambience.volume_db=-80
		drums.stop()
		drum_duration=0
		drum_wait=drum_rng.randf_range(24,42)
		stop_chants(true)
		cheering.stop()
		cheer_duration=0
		cheer_priority=0
		stop_roar()
		stop_walkout()
		stop_replay_chant()
		stop_swells()
		hush_packed()
		stop_menu_playback()
	else:
		ambience_gain=0
		if menu_wanted: start_menu()
		if match_audio:
			start_swells()
			start_packed()
	if muted: effects.stop()
	if muted: net_impact.stop()
	if muted:
		for channel in contacts: channel.stop()

func start_match(enabled: bool) -> void:
	stop_atmosphere()
	if background:
		effects.stop()
		for channel in contacts: channel.stop()
	match_audio=enabled
	drum_wait=drum_rng.randf_range(12,22)
	schedule_chants()
	if enabled:
		stop_menu()
		ambience.play()
		start_swells()
		start_packed()
	elif background:
		start_menu()
	else:
		stop_menu()

func stop_atmosphere() -> void:
	net_impact.stop()
	net_impact.stream_paused=false
	match_audio=false
	paused=false
	drums.stop()
	drums.stream_paused=false
	drums.volume_db=-80
	drum_age=0
	drum_duration=0
	drum_wait=0
	stop_chants(false)
	ambience.stop()
	ambience.stream_paused=false
	cheering.stop()
	cheering.stream_paused=false
	stop_roar()
	stop_walkout()
	stop_replay_chant()
	stop_swells()
	stop_packed()
	effects.stream_paused=false
	ambience_gain=0
	cheer_duration=0
	cheer_age=0
	cheer_priority=0
	cheer_kind=""
	cheer_cooldown=0
	ambience.volume_db=-80
	cheering.volume_db=-80

func start_menu() -> void:
	menu_wanted=true
	if muted or menu_music==null: return
	if not menu_music.playing:
		menu_music.volume_db=-80
		menu_gain=0
		menu_music.play()

func stop_menu() -> void:
	menu_wanted=false
	stop_menu_playback()

func stop_menu_playback() -> void:
	if menu_music==null: return
	menu_music.stop()
	menu_music.stream_paused=false
	menu_music.volume_db=-80
	menu_gain=0

func update_menu(delta: float) -> void:
	if menu_music==null: return
	if muted:
		stop_menu_playback()
		return
	var target: float=db_to_linear(MENU_LEVEL) if menu_wanted else 0.0
	var rise: float=maxf(0.08,db_to_linear(MENU_LEVEL)/2.0)
	menu_gain=move_toward(menu_gain,target,delta*(rise if target>menu_gain else 0.2))
	if menu_wanted and not menu_music.playing:
		menu_music.volume_db=-80
		menu_music.play()
	if menu_gain<=0.0001:
		menu_music.volume_db=-80
		if not menu_wanted: menu_music.stop()
		return
	var position := menu_music.get_playback_position()
	var edge := minf(smoothstep(0,0.45,position),smoothstep(0,0.45,menu_music.stream.get_length()-position))
	menu_music.volume_db=linear_to_db(maxf(0.0001,menu_gain*edge))

func reaction_source(kind: String) -> AudioStreamMP3:
	if kind=="goal": return GOAL_CHEER
	if kind=="foul": return FOUL_CHEER
	if kind=="card": return CARD_CHEER
	return CHEERING

func dedicated_reaction(kind: String) -> bool:
	return kind=="goal" or kind=="foul" or kind=="card"

func stop_roar() -> void:
	if roar==null: return
	roar.stop()
	roar.stream_paused=false
	roar.volume_db=-80
	roar_age=0
	roar_duration=0

func start_roar(team: int) -> void:
	var clip: AudioStreamMP3=GOAL_ROAR.duplicate()
	clip.loop=false
	roar.stream=clip
	roar.volume_db=-80
	roar_age=0
	roar_duration=maxf(2.0,clip.get_length())
	roar_level=-4.0 if team==0 else -7.0
	if match_progress>.8 and abs(score_margin)<=1: roar_level+=1.5
	roar.play()

func update_roar(delta: float) -> void:
	if roar==null or roar_duration<=0: return
	roar_age+=delta
	var envelope: float=minf(smoothstep(0,0.1,roar_age),smoothstep(0,0.65,roar_duration-roar_age))
	var volume: float=db_to_linear(roar_level)*envelope*cheer_volume
	roar.volume_db=linear_to_db(maxf(0.0001,volume)) if not muted else -80
	if roar_age>=roar_duration or not roar.playing:
		stop_roar()

func stop_walkout() -> void:
	if walkout==null: return
	walkout.stop()
	walkout.stream_paused=false
	walkout.volume_db=-80
	walkout_age=0
	walkout_duration=0

func start_walkout() -> void:
	if walkout==null or muted or not match_audio: return
	if walkout_duration>0 and walkout.playing: return
	var clip: AudioStreamMP3=WALKOUT.duplicate()
	clip.loop=true
	walkout.stream=clip
	walkout.volume_db=-80
	walkout_age=0
	walkout_duration=90.0
	walkout.play()

func release_walkout() -> void:
	if walkout_duration>0: walkout_duration=minf(walkout_duration,walkout_age+1.4)

func update_walkout(delta: float) -> void:
	if walkout==null or walkout_duration<=0: return
	walkout_age+=delta
	var envelope: float=minf(smoothstep(0,0.7,walkout_age),smoothstep(0,1.4,walkout_duration-walkout_age))
	var volume: float=db_to_linear(-8.5)*envelope*stadium_volume
	walkout.volume_db=linear_to_db(maxf(0.0001,volume)) if not muted else -80
	if walkout_age>=walkout_duration or not walkout.playing:
		stop_walkout()

func stop_replay_chant() -> void:
	if replay_chant==null: return
	replay_chant.stop()
	replay_chant.stream_paused=false
	replay_chant.volume_db=-80
	replay_age=0
	replay_duration=0

func start_replay_chant(team: int) -> void:
	if replay_chant==null or muted or not match_audio or team!=0: return
	var clip: AudioStreamMP3=REPLAY_CHANT.duplicate()
	clip.loop=false
	var span: float=maxf(0.0,clip.get_length()-8.0)
	var start: float=drum_rng.randf_range(0.0,span)
	replay_chant.stream=clip
	replay_chant.volume_db=-80
	replay_age=0
	replay_duration=minf(drum_rng.randf_range(6.0,9.0),maxf(3.5,clip.get_length()-start))
	replay_chant.play(start)

func release_replay_chant() -> void:
	if replay_duration>0: replay_duration=minf(replay_duration,replay_age+0.8)

func update_replay_chant(delta: float) -> void:
	if replay_chant==null or replay_duration<=0: return
	replay_age+=delta
	var envelope: float=minf(smoothstep(0,0.45,replay_age),smoothstep(0,0.8,replay_duration-replay_age))
	var volume: float=db_to_linear(-18.0)*envelope*cheer_volume
	replay_chant.volume_db=linear_to_db(maxf(0.0001,volume)) if not muted else -80
	if replay_age>=replay_duration or not replay_chant.playing:
		stop_replay_chant()

func start_swells() -> void:
	for rise in swells:
		if rise==null: continue
		if not rise.playing:
			rise.volume_db=-80
			rise.play()

func stop_swells() -> void:
	swell_pressure=0
	for i in range(swells.size()):
		swells[i].stop()
		swells[i].stream_paused=false
		swells[i].volume_db=-80
		swell_gain[i]=0.0

func start_packed() -> void:
	for i in range(packed.size()):
		var bed := packed[i]
		if bed==null: continue
		if not bed.playing:
			bed.volume_db=-80
			bed.play()
			var length: float=bed.stream.get_length()
			if length>1.0: bed.seek(length*[0.0,0.22,0.47,0.73][i])

func stop_packed() -> void:
	for bed in packed:
		if bed==null: continue
		bed.stop()
		bed.stream_paused=false
		bed.volume_db=-80

func hush_packed() -> void:
	for bed in packed:
		if bed!=null: bed.volume_db=-80

func update_packed() -> void:
	if packed.is_empty(): return
	if muted:
		hush_packed()
		return
	# Four different stands, always under the main bed and event layers.
	var mix := [0.40,0.33,0.37,0.30]
	for i in range(packed.size()):
		var volume: float=ambience_gain*mix[i]*stadium_volume
		packed[i].volume_db=linear_to_db(maxf(0.0001,volume))
		if match_audio and not packed[i].playing: start_packed()

func update_swell(delta: float,state: String) -> void:
	if swells.is_empty() or muted: return
	var wanted: float=crowd_danger if state=="playing" else 0.0
	if crowd_hush>0.35: wanted*=lerpf(1.0,0.72,clampf((crowd_hush-0.35)/0.65,0,1))
	if cheer_duration>0 and cheer_kind in ["goal","save","shot","card"]: wanted*=0.22
	swell_pressure=move_toward(swell_pressure,wanted,delta*(0.42 if wanted>swell_pressure else 1.55))
	var side: float=0.72 if crowd_attack==1 else 1.0
	var peaks: Array[float]=[-20.5,-18.5,-16.5,-14.8]
	var opens: Array[float]=[0.10,0.28,0.46,0.64]
	var fulls: Array[float]=[0.38,0.54,0.70,0.86]
	for i in range(swells.size()):
		var layer: float=smoothstep(opens[i],fulls[i],swell_pressure)
		var target: float=db_to_linear(peaks[i])*layer*side*cheer_volume
		swell_gain[i]=move_toward(swell_gain[i],target,delta*(0.38 if target>swell_gain[i] else 1.35))
		if swell_gain[i]<=0.00012:
			swells[i].volume_db=-80
			continue
		if not swells[i].playing: swells[i].play()
		swells[i].volume_db=linear_to_db(maxf(0.0001,swell_gain[i]))

func start_reaction(kind: String) -> void:
	var clip: AudioStreamMP3=reaction_source(kind).duplicate()
	clip.loop=false
	cheering.stream=clip
	cheering.volume_db=-80
	var start: float=0.0 if dedicated_reaction(kind) else 0.8
	cheering.play(start)
	if dedicated_reaction(kind):
		cheer_age=0.0
		cheer_duration=maxf(2.0,clip.get_length()-start)

func react(kind: String,_team: int,_location: Vector3) -> void:
	if not match_audio or muted or paused: return
	if kind=="entrance":
		start_walkout()
		return
	var priority: int={"goal":4,"card":4,"foul":3,"save":3,"shot":2,"miss":1,"tackle":1}.get(kind,0)
	if priority==0: return
	# A save can build on a shot and a goal always wins. One reaction player
	# prevents overlapping copies or repeated events restarting the recording.
	if cheer_duration>0 and priority<=cheer_priority: return
	if cheer_cooldown>0 and priority<3: return
	# Give the important play room: fade the rhythm out under the reaction.
	if drum_duration>0: drum_duration=minf(drum_duration,drum_age+0.3)
	for i in range(chants.size()):
		if chant_duration[i]>0: chant_duration[i]=minf(chant_duration[i],chant_age[i]+0.35)
	var was_playing := cheering.playing
	var was_dedicated := dedicated_reaction(cheer_kind)
	cheer_kind=kind
	cheer_priority=priority
	cheer_age=0.25 if was_playing and not dedicated_reaction(kind) else 0.0
	cheer_duration={"goal":6.0,"foul":6.4,"card":2.0,"save":5.0,"shot":3.5,"miss":2.8,"tackle":2.6}[kind]
	cheer_level={"goal":-10.0,"card":-11.0,"foul":-12.0,"save":-12.0,"shot":-15.0,"miss":-18.0,"tackle":-17.0}[kind]
	# Goal, foul and booking use their own supplied recordings.
	if _team==1: cheer_level-=5.0
	if kind=="goal" and match_progress>.8 and abs(score_margin)<=1: cheer_level+=2
	if kind=="miss": cheer_duration=1.35; cheer_level-=2
	if dedicated_reaction(kind) or not was_playing or was_dedicated:
		start_reaction(kind)
	else:
		# Keep the applause continuous when a shot becomes a save.
		cheer_duration=minf(cheer_duration,maxf(0.1,cheering.stream.get_length()-cheering.get_playback_position()))
	if kind=="goal": start_roar(_team)
	cheer_cooldown=cheer_duration+1.5

func update_atmosphere(delta: float,state: String) -> void:
	paused=state=="paused"
	ambience.stream_paused=paused
	cheering.stream_paused=paused
	if roar!=null: roar.stream_paused=paused
	if walkout!=null: walkout.stream_paused=paused
	if replay_chant!=null: replay_chant.stream_paused=paused
	drums.stream_paused=paused
	for voice in chants: voice.stream_paused=paused
	for rise in swells: rise.stream_paused=paused
	for bed in packed: bed.stream_paused=paused
	effects.stream_paused=paused
	net_impact.stream_paused=paused
	update_menu(delta)
	if not match_audio or paused: return
	if state=="menu": stop_atmosphere(); return
	cheer_cooldown=maxf(0,cheer_cooldown-delta)
	update_drums(delta,state)
	update_chants(delta,state)
	var target := 0.0 if muted else db_to_linear(-18 if state=="halftime" else (-12+crowd_lift*4-crowd_hush*7))
	ambience_gain=move_toward(ambience_gain,target,delta*0.25)
	# Fade at the recording's loop boundary to avoid a hard audio click.
	var position := ambience.get_playback_position()
	var edge := minf(smoothstep(0,0.6,position),smoothstep(0,0.6,ambience.stream.get_length()-position))
	ambience.volume_db=linear_to_db(maxf(0.0001,ambience_gain*edge*stadium_volume)) if not muted else -80
	update_packed()
	update_roar(delta)
	update_walkout(delta)
	update_replay_chant(delta)
	update_swell(delta,state)
	if cheer_duration<=0: return
	cheer_age+=delta
	var envelope := minf(smoothstep(0,0.25,cheer_age),smoothstep(0,0.9,cheer_duration-cheer_age))
	var volume := db_to_linear(cheer_level)*envelope*cheer_volume
	cheering.volume_db=linear_to_db(maxf(0.0001,volume)) if not muted else -80
	if cheer_age>=cheer_duration or not cheering.playing:
		cheering.stop()
		cheer_duration=0
		cheer_priority=0

func update_drums(delta: float,state: String) -> void:
	if muted: return
	if drum_duration>0:
		if state!="playing": drum_duration=minf(drum_duration,drum_age+0.3)
		drum_age+=delta
		var envelope := minf(smoothstep(0,0.3,drum_age),smoothstep(0,0.5,drum_duration-drum_age))
		drums.volume_db=linear_to_db(maxf(0.0001,db_to_linear(-15)*envelope*drum_volume))
		if drum_age>=drum_duration or not drums.playing:
			drums.stop()
			drum_duration=0
			drum_wait=drum_rng.randf_range(24,42)
		return
	if state!="playing" or cheer_duration>0 or cheer_cooldown>0: return
	drum_wait=maxf(0,drum_wait-delta)
	if drum_wait>0: return
	drum_age=0
	# The supplied recording's last 2.3 seconds are silent; keep its audible phrase.
	drum_duration=minf(5.5,drums.stream.get_length())
	drums.volume_db=-80
	drums.play()

func schedule_chants() -> void:
	for i in range(chants.size()):
		chant_age[i]=0
		chant_duration[i]=0
		chant_wait[i]=drum_rng.randf_range(16.0+i*8.0,28.0+i*12.0)

func stop_chants(reschedule: bool) -> void:
	for i in range(chants.size()):
		if i>=chants.size(): break
		chants[i].stop()
		chants[i].stream_paused=false
		chants[i].volume_db=-80
		chant_age[i]=0
		chant_duration[i]=0
		chant_wait[i]=drum_rng.randf_range(20,36) if reschedule else 0.0

func chanting() -> int:
	var count: int=0
	for length in chant_duration:
		if length>0: count+=1
	return count

func start_chant(index: int) -> void:
	if index<0 or index>=chants.size() or muted or not match_audio: return
	var clip: AudioStreamMP3=CHANTS[index].duplicate()
	clip.loop=false
	var span: float=maxf(0.0,clip.get_length()-7.0)
	var start: float=drum_rng.randf_range(0.0,span)
	chant_age[index]=0
	chant_duration[index]=minf(drum_rng.randf_range(6.5,10.5),maxf(3.0,clip.get_length()-start))
	chants[index].stream=clip
	chants[index].volume_db=-80
	chants[index].play(start)

func update_chants(delta: float,state: String) -> void:
	if muted: return
	for i in range(chants.size()):
		if chant_duration[i]>0:
			if state!="playing": chant_duration[i]=minf(chant_duration[i],chant_age[i]+0.35)
			chant_age[i]+=delta
			var envelope: float=minf(smoothstep(0,0.55,chant_age[i]),smoothstep(0,0.8,chant_duration[i]-chant_age[i]))
			chants[i].volume_db=linear_to_db(maxf(0.0001,db_to_linear(-16.5)*envelope*drum_volume))
			if chant_age[i]>=chant_duration[i] or not chants[i].playing:
				chants[i].stop()
				chant_duration[i]=0
				chant_wait[i]=drum_rng.randf_range(22,40)
			continue
		if state!="playing" or cheer_duration>0 or cheer_cooldown>0: continue
		chant_wait[i]=maxf(0,chant_wait[i]-delta)
		if chant_wait[i]>0: continue
		if chanting()>0 and drum_rng.randf()>0.42:
			chant_wait[i]=drum_rng.randf_range(6,14)
			continue
		start_chant(i)
