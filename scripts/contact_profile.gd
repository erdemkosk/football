extends RefCounted
## Contact colours share one vocabulary across audio and controller feedback.
static func read(kind: String,strength: float) -> Dictionary:
	var s:=clampf(strength,0,1)
	var low:=.16; var high:=.32; var duration:=.13; var gain:=0.0; var pitch:=1.0
	match kind:
		"kick": low=.05; high=.20; duration=.075; gain=-2.0; pitch=1.08
		"soft_pass": low=.04; high=.15; duration=.065; gain=-3.0; pitch=1.06
		"shot": low=.70; high=.38; duration=.16; gain=1.0; pitch=.98
		"power": low=.95; high=.48; duration=.28; gain=1.0; pitch=.94
		"glove": low=.26; high=.12; duration=.105; gain=-1.0; pitch=.92
		"woodwork": low=.24; high=.82; duration=.19; gain=0.0; pitch=1.0
		"body_hit": low=.65; high=.28; duration=.22
		"ball_tackle": low=.23; high=.48; duration=.12
	return {"low":low*s,"high":high*s,"duration":duration,"gain":gain,"pitch":pitch*lerpf(1.05,.96,s)}
