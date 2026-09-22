extends Node
const AMBIENCE = preload("res://assets/audio/stadium-ambience.mp3")
const CHEERING = preload("res://assets/audio/crowd-cheering.mp3")
const GOAL_CHEER = preload("res://assets/audio/goal-cheer.mp3")
const FOUL_CHEER = preload("res://assets/audio/foul-cheer.mp3")
const CARD_CHEER = preload("res://assets/audio/card-cheer.mp3")
const MENU_THEME = preload("res://assets/audio/menu-theme.mp3")
const DRUMS = preload("res://assets/audio/crowd-drums.mp3")
const MENU_LEVEL := -8.0
var stadium_volume := 1.0
var cheer_volume := 1.0
var drum_volume := 1.0
var ambience: AudioStreamPlayer
var cheering: AudioStreamPlayer
var drums: AudioStreamPlayer
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
var score_margin := 0
var match_progress := 0.0

func crowd_context(home: float,danger: float,hush: float,margin: int,progress: float) -> void:
	crowd_lift=clampf(danger*.7+maxf(0,home-.35)*.6,0,1)
	crowd_hush=hush; score_margin=margin; match_progress=progress
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
	effects = AudioStreamPlayer.new()
	add_child(effects)
	clips.kick = synth("kick",0.13)
	clips.whistle=synth("whistle",0.65)
	clips.shot=synth("shot",0.24)
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
		cheering.stop()
		cheer_duration=0
		cheer_priority=0
		stop_menu_playback()
	else:
		ambience_gain=0
		if menu_wanted: start_menu()
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
	if enabled:
		stop_menu()
		ambience.play()
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
	ambience.stop()
	ambience.stream_paused=false
	cheering.stop()
	cheering.stream_paused=false
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
	var priority: int={"goal":4,"card":4,"foul":3,"save":3,"shot":2,"miss":1,"tackle":1}.get(kind,0)
	if priority==0: return
	# A save can build on a shot and a goal always wins. One reaction player
	# prevents overlapping copies or repeated events restarting the recording.
	if cheer_duration>0 and priority<=cheer_priority: return
	if cheer_cooldown>0 and priority<3: return
	# Give the important play room: fade the rhythm out under the reaction.
	if drum_duration>0: drum_duration=minf(drum_duration,drum_age+0.3)
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
	cheer_cooldown=cheer_duration+1.5

func update_atmosphere(delta: float,state: String) -> void:
	paused=state=="paused"
	ambience.stream_paused=paused
	cheering.stream_paused=paused
	drums.stream_paused=paused
	effects.stream_paused=paused
	net_impact.stream_paused=paused
	update_menu(delta)
	if not match_audio or paused: return
	if state=="menu": stop_atmosphere(); return
	cheer_cooldown=maxf(0,cheer_cooldown-delta)
	update_drums(delta,state)
	var target := 0.0 if muted else db_to_linear(-18 if state=="halftime" else (-12+crowd_lift*4-crowd_hush*7))
	ambience_gain=move_toward(ambience_gain,target,delta*0.25)
	# Fade at the recording's loop boundary to avoid a hard audio click.
	var position := ambience.get_playback_position()
	var edge := minf(smoothstep(0,0.6,position),smoothstep(0,0.6,ambience.stream.get_length()-position))
	ambience.volume_db=linear_to_db(maxf(0.0001,ambience_gain*edge*stadium_volume)) if not muted else -80
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
