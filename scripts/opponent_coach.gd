extends RefCounted
## Reads completed actions and visible positions, never the user's buttons or aim.
var game
var elapsed := 0.0
var review_in := 0.0
var samples := 0.0
var wing_time := [0.0,0.0]
var central_time := 0.0
var direct_play := 0.0
var build_pressure := 0.0
var possession_team := -1
var transition := 0.0
var press_load := 0.0
var press_rest := 0.0
var mentality := 1
var pressing := 1
var line_height := 1
var wing_bias := 0.0
var protect_depth := false
var escape_press := false
var reason := "balance"
var next_sub := 0.0

func level() -> int:
	return clampi(game.management.difficulty,0,2)

func reset() -> void:
	elapsed=0; review_in=0; samples=0; wing_time=[0.0,0.0]; central_time=0
	direct_play=0; build_pressure=0; possession_team=-1; transition=0
	press_load=0; press_rest=0; mentality=1; pressing=1; line_height=1
	wing_bias=0; protect_depth=false; escape_press=false; reason="balance"; next_sub=0
	var plan: Dictionary=game.clubs.tactical_plan(1)
	mentality=int(plan.mentality); pressing=int(plan.pressing); line_height=int(plan.line_height)

func observe_kick(index: int,velocity: Vector3,kind: String) -> void:
	if game.training or game.players[index].team!=0 or kind in ["shot","header","volley","half_volley","finish","ball_tackle"]: return
	# A fast pass upfield is evidence only after it has actually been struck.
	if velocity.z*game.attack_sign(0)>13 and absf(velocity.z)>absf(velocity.x)*1.25:
		direct_play=minf(8,direct_play+1)

func energy() -> float:
	var total := 0.0
	var count := 0
	for i in range(12,22):
		var p=game.players[i]
		if p.visible and not p.dismissed: total+=p.energy; count+=1
	return total/maxi(1,count)

func update(delta: float) -> void:
	if game.training or game.state!="playing": return
	elapsed+=delta; review_in-=delta; transition=maxf(0,transition-delta)
	press_rest=maxf(0,press_rest-delta)
	var owner: int=game.dribbler if game.dribbler>=0 else game.carrier
	var team: int=game.players[owner].team if owner>=0 else -1
	if team>=0 and team!=possession_team:
		if possession_team==1 and team==0: transition=[0.0,2.0,3.4][level()]
		possession_team=team
	var decay := exp(-delta/35.0)
	wing_time[0]*=decay; wing_time[1]*=decay; central_time*=decay
	direct_play*=exp(-delta/48.0); build_pressure*=decay; samples*=decay
	if team==0:
		samples+=delta
		if absf(game.ball.position.x)>12: wing_time[0 if game.ball.position.x<0 else 1]+=delta
		else: central_time+=delta
	if team==1 and game.ball.position.z*game.attack_sign(1)<5:
		var nearby := 0
		for p in game.players:
			if p.visible and p.team==0 and game.flat_distance(p.position,game.ball.position)<7: nearby+=1
		if nearby>=2: build_pressure+=delta
	if team==0 and pressing==2 and press_rest<=0:
		press_load+=delta
		if press_load>[4.5,6.0,7.5][level()]: press_rest=4.0; press_load=0
	else: press_load=maxf(0,press_load-delta*.6)
	if review_in<=0:
		review_in=[14.0,9.0,5.5][level()]*lerpf(1.22,.78,game.management.identity.team_quality(1))
		review()

func review() -> void:
	var old := reason
	var plan: Dictionary=game.clubs.tactical_plan(1)
	mentality=int(plan.mentality); pressing=int(plan.pressing); line_height=int(plan.line_height)
	var ready: bool=samples>[12.0,7.0,4.0][level()]
	wing_bias=0; protect_depth=false; escape_press=false; reason="balance"
	if ready:
		var difference: float=(wing_time[1]-wing_time[0])/maxf(1,samples)
		if absf(difference)>.34:
			wing_bias=signf(difference)*[.28,.62,.9][level()]; reason="wing"
		protect_depth=direct_play>[4.8,2.8,1.8][level()]
		if protect_depth: line_height=0; reason="depth"
	escape_press=build_pressure>[7.0,4.0,2.5][level()]
	if escape_press: reason="outlet"
	var margin: int=game.score[1]-game.score[0]
	var late: bool=game.match_time>game.LENGTH*.68
	var available := 0
	for i in range(12,22):
		if game.players[i].visible and not game.players[i].dismissed: available+=1
	if available<10:
		mentality=0 if margin>=0 else 1; pressing=0; line_height=0; reason="ten_men"
	elif late and margin<0:
		mentality=2; pressing=2; line_height=1 if protect_depth else 2; reason="chase"
	elif late and margin>0:
		mentality=0; pressing=0; line_height=0; reason="protect"
	elif protect_depth:
		pressing=mini(pressing,1)
	# Team identity sets sustained pressure. A few seconds of human possession
	# must not turn every balanced or deep-block club into an all-out press.
	if energy()<.32: pressing=0
	var shape: int=int(plan.formation)
	if reason=="chase" and level()>0: shape=1
	elif reason=="protect": shape=0
	elif escape_press and level()==2 and not protect_depth and available==10: shape=2
	if game.management.opponent_formation!=shape:
		game.management.opponent_formation=shape
		game.management.apply_formation()
	if reason!=old: game.stadium.sidelines.instruct(1,"attack" if mentality==2 else ("defend" if mentality==0 or protect_depth else "balance"))

func press_level() -> int:
	if press_rest>0 or energy()<.28: return mini(1,pressing)
	if transition>0 and level()>0 and game.ball.position.z*game.attack_sign(1)>-25: return 2
	return pressing

func substitution() -> Dictionary:
	if game.training or game.match_time<60 or game.match_time<next_sub or game.management.committed(1)>=3: return {}
	var late: bool=game.match_time>game.LENGTH*.60
	var best := 0.0
	var choice: Dictionary={}
	for i in range(12,22):
		var p=game.players[i]
		if not p.visible or p.dismissed: continue
		var role: int=game.management.slot_role(i)
		var threshold: float=[.36,.44,.52][level()]
		var need: float=maxf(0,threshold-p.energy)*8
		if late and level()>0 and p.yellow_cards>0 and role==1: need+=.85
		if late and mentality==2 and role==3 and p.energy<.78: need+=.8
		if late and mentality==0 and role==1 and p.energy<.7: need+=.65
		if need<=0: continue
		for reserve in range(1,7):
			var b: Dictionary=game.management.bench[1][reserve]
			if int(b.get("role",game.management.natural_role(b.shirt,b.keeper)))!=role or game.management.substitution_reason(i,reserve)!="": continue
			var stats: Dictionary=b.get("attributes",{})
			var fit: float=float(stats.get("finishing" if role==3 else ("balance" if role==1 else "control"),72))/100.0
			if need+fit*.2>best:
				best=need+fit*.2; choice={"slot":i,"reserve":reserve}
	return choice

func substituted() -> void:
	next_sub=game.match_time+[30.0,22.0,16.0][level()]
