extends Node
var crowd: AudioStreamPlayer
var effects: AudioStreamPlayer
var muted := false
var clips: Dictionary = {}
var contacts: Array[AudioStreamPlayer] = []
var contact_cursor := 0

func _ready() -> void:
	crowd = AudioStreamPlayer.new()
	effects = AudioStreamPlayer.new()
	add_child(crowd)
	add_child(effects)
	clips.kick = synth("kick",0.13)
	clips.whistle = synth("whistle",0.65)
	clips.goal = synth("goal",6.5)
	clips.shot=synth("shot",0.24)
	clips.body_hit=synth("body_hit",0.30)
	clips.ball_tackle=synth("ball_tackle",0.18)
	clips.slide=synth("slide",0.40)
	for i in range(4):
		var channel := AudioStreamPlayer.new()
		add_child(channel)
		contacts.append(channel)
	crowd.stream = synth("crowd",6.0)
	crowd.volume_db = -22
	crowd.play()
	effects.volume_db = -11

func synth(kind: String, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var count = int(sample_rate*duration)
	var data = PackedByteArray()
	data.resize(count*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 73
	var low = 0.0
	for i in range(count):
		var t = float(i)/sample_rate
		var n = rng.randf_range(-1,1)
		low = lerpf(low,n,0.08)
		var value = 0.0
		match kind:
			"kick": value = (sin(TAU*(100*t-80*t*t))*0.6+low*0.8+n*0.11)*exp(-t*35)
			"shot": value = sin(TAU*(108*t-105*t*t))*0.68*exp(-t*24)+low*1.2*exp(-t*36)+n*0.23*exp(-t*130)
			"body_hit": value = sin(TAU*(65*t-35*t*t))*0.55*exp(-t*19)+low*1.4*exp(-t*15)+n*0.16*exp(-t*55)
			"ball_tackle": value = sin(TAU*145*t)*0.46*exp(-t*34)+n*0.20*exp(-t*45)+low*0.8*exp(-t*20)
			"slide": value = (low*0.7+n*0.06)*sin(PI*t/duration)*exp(-t*3)
			"whistle": value = (sin(TAU*2300*t+sin(t*42)*2)+sin(TAU*2850*t)*0.22)*0.22*minf(t*50,1)*minf((duration-t)*20,1)
			"crowd": value = low*(0.62+sin(TAU*t/6)*0.14)+sin(TAU*145*t)*0.018+sin(TAU*217*t)*0.01
			"rain": value = n*0.13+low*0.7
			"goal": value = (low*2+n*0.03)*(sin(PI*t/duration)*0.7+0.12)
		data.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	if kind in ["crowd","rain"]:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav

func play(kind: String) -> void:
	if muted: return
	effects.stream = clips[kind]
	effects.play()

func contact(kind: String,strength: float=0.5,proximity: float=1.0) -> void:
	if muted: return
	var channel := contacts[contact_cursor]
	contact_cursor=(contact_cursor+1)%contacts.size()
	channel.stream=clips[kind]
	channel.pitch_scale=lerpf(1.09,0.94,strength)
	channel.volume_db=lerpf(-19,-8,strength)+linear_to_db(maxf(0.05,proximity))
	channel.play()

func toggle() -> void:
	muted = not muted
	crowd.volume_db = -80 if muted else -22
	if muted: effects.stop()
	if muted:
		for channel in contacts: channel.stop()
