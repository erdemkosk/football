extends RefCounted
## HUD and physical stadium displays share the same half / extra-time rules.
static func text(seconds: float,duration: float,half: int=2,extended: bool=false) -> String:
	var played := maxf(0.0,seconds)/maxf(duration,0.001)*5400.0
	var boundary := 45*clampi(half,1,2)
	if not extended and played>boundary*60:
		return "%d+%d" % [boundary,ceili((played-boundary*60)/60.0)]
	var total := mini(7200 if extended else 5400,int(played))
	return "%02d:%02d" % [total/60,total%60]
