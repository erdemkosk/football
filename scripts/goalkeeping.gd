extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
var game
var holding := -1
var hold_age := 0.0
var modes: Dictionary = {}
var rush_requested := false
var returning := false
var reads: Dictionary = {}
var variation := RandomNumberGenerator.new()

func _init() -> void:
	variation.seed=742

func reset() -> void:
	if holding>=0: game.players[holding].set_piece_pose=""
	holding=-1
	hold_age=0
	modes.clear()
	rush_requested=false
	returning=false
	reads.clear()
	for p in game.players:
		if p.keeper: p.keeper_motion.reset()

func shot_read(index: int,delta: float) -> Dictionary:
	var p=game.players[index]
	var ball: Vector3=game.ball.position
	var velocity: Vector3=game.ball.linear_velocity
	var forward: float=game.attack_sign(p.team)
	var time: float=(-forward*50-ball.z)/velocity.z if absf(velocity.z)>7 else -1.0
	var threat: bool=game.last_touch!=p.team and velocity.z*forward< -7 and time>0 and time<2.2 and absf(ball.x+velocity.x*time)<5.5
	if not threat:
		reads.erase(index)
		return {}
	if reads.has(index) and reads[index].kicker!=game.last_kicker: reads.erase(index)
	if not reads.has(index):
		var difficulty: int=game.management.difficulty if p.team==1 else 1
		var screened := false
		var line: Vector3=(ball-p.position)*Vector3(1,0,1)
		for other in game.players:
			if other==p or not other.visible: continue
			var offset: Vector3=(other.position-p.position)*Vector3(1,0,1)
			var fraction := offset.dot(line)/maxf(line.length_squared(),0.01)
			if fraction>0.15 and fraction<0.85 and (offset-line*fraction).length()<0.65: screened=true; break
		var fatigue: float=1.0-p.energy
		var delay: float=[0.28,0.23,0.18][difficulty]+variation.randf_range(-0.025,0.025)+fatigue*0.055
		delay/=p.Attributes.multiplier(p.attributes.get("reflexes",72),.25)
		# Faster balls leave less time to judge the interception point. Keep this
		# as one small, persistent read error rather than a forced save/goal roll.
		var pace_error: float=clampf((velocity.length()-20)/16,0,1)*0.13
		var error: float=[0.42,0.33,0.21][difficulty]+pace_error+fatigue*0.12+game.weather.rain*0.08
		error/=p.Attributes.multiplier(p.attributes.get("positioning",72),.28)
		if screened: delay+=0.06; error+=0.16
		# One imperfect read per incoming ball, never a random roll every frame.
		if variation.randf()<0.10: delay+=0.055; error+=0.30
		reads[index]={"kicker":game.last_kicker,"age":0.0,"delay":delay,"next_read":delay,"set":p.position,"x":p.position.x,"height":1.0,"error":variation.randf_range(-error,error),"height_error":variation.randf_range(-0.10,0.10),"handling":variation.randf(),"screened":screened}
	var read: Dictionary=reads[index]
	read.age+=delta
	if read.age>=read.next_read:
		var arrival: float=maxf(0,(p.position.z-ball.z)/velocity.z)
		read.x=ball.x+velocity.x*arrival+read.error
		read.height=maxf(0.22,ball.y+velocity.y*arrival-4.905*arrival*arrival+read.height_error)
		read.next_read=read.age+0.12
	return read

func handling_error(index: int,read: Dictionary) -> bool:
	if read.is_empty(): return false
	var p=game.players[index]
	var pace: float=clampf((game.ball.linear_velocity.length()-16)/18,0,1)
	var difficult: float=pace*0.21+game.weather.rain*0.13+(1-p.energy)*0.08+(0.06 if read.screened else 0.0)
	if p.pose=="dive": difficult+=0.06
	difficult/=p.Attributes.multiplier(p.attributes.get("handling",72),.3)
	return read.handling<difficult

func loose_parry(index: int) -> Vector3:
	var p=game.players[index]
	var forward: float=game.attack_sign(p.team)
	var side: float=clampf((game.ball.position.x-p.position.x)*0.7,-0.55,0.55)
	# A weak palm leaves a playable rebound in front; the rigid ball stays live.
	return Vector3(side,0,forward).normalized()*clampf(game.ball.linear_velocity.length()*0.26,4,8)+Vector3.UP*1.25

func team_has_ball() -> bool:
	if game.ball.held_by!=null: return game.ball.held_by.team==0
	if game.dribbler>=0: return game.players[game.dribbler].team==0
	if game.has_ball_control(game.controlled): return true
	var nearest: int=game.nearest_to_ball(1.4) if game.ball.linear_velocity.length()<16 else -1
	return (nearest>=0 and game.players[nearest].team==0) or (game.last_touch==0 and game.ai_pass_time[0]>0)

func can_call() -> bool:
	return game.state=="playing" and not game.training and game.players[0].visible and not game.players[0].dismissed and not team_has_ball()

func start_rush() -> void:
	if not can_call(): return
	rush_requested=true
	returning=false
	game.clear_pass_request()
	game.charging=false; game.charge=0
	game.announce("KALECİ ÇIKIYOR · TUŞU BASILI TUT")

func stop_rush() -> void:
	if rush_requested: returning=true
	rush_requested=false
	game.players[0].sprinting=false

func is_rushing(index: int=0) -> bool:
	return index==0 and rush_requested and can_call()

func safe_parry(index: int) -> Vector3:
	var p=game.players[index]
	var forward: float = game.attack_sign(p.team)
	var best := Vector3.RIGHT
	var best_space := -INF
	for side in [-1.0,1.0]:
		var direction := Vector3(side,0,forward*0.42).normalized()
		var landing: Vector3=game.ball.position+direction*11
		var space := 15.0
		for q in game.players:
			if q.visible and q.team!=p.team: space=minf(space,game.flat_distance(q.position,landing))
		space+=absf(landing.x)*0.18
		if space>best_space: best_space=space; best=direction
	return best*clampf(game.ball.linear_velocity.length()*0.65,12,19)+Vector3.UP*2.6

func update(index: int,delta: float) -> Vector3:
	var p=game.players[index]
	if index==0 and rush_requested and not can_call(): stop_rush()
	var called := is_rushing(index)
	var ball: Vector3=game.ball.position
	var bv: Vector3=game.ball.linear_velocity
	var forward: float = game.attack_sign(p.team)
	var goal := Vector3(0,0,-forward*50)
	var depth := 50+ball.z*forward
	var in_box := depth>=0 and depth<16.5 and absf(ball.x)<20.16
	var direction: Vector3=(ball-goal)*Vector3(1,0,1)
	var advance := clampf(direction.length()*0.13,1.0,3.5)
	var target: Vector3=goal+direction.normalized()*advance
	target.x=clampf(target.x,-3.3,3.3)
	modes[index]="angle"
	if index==0 and returning and game.flat_distance(p.position,target)<1.2: returning=false
	if holding==index:
		if game.ball.held_by!=p: reset(); return target
		hold_age+=delta
		if game.keeper_distribution.active(index): return p.position
		p.set_piece_pose="" if p.pose.begins_with("keeper_") and p.action_timer>0 else "carry"
		if not game.is_user_player(index) or (not game.charging and not game.pass_charging and p.desired.length()<0.05):
			p.facing=Vector3(0,0,forward)
		game.ball.hold_target=p.hand_center()
		modes[index]="hold"
		if hold_age>1.15+game.management.reaction(p.team)*.35 and game.autonomous_kicks(p.team):
			game.ai_attack.distribute(index)
		return p.position
	var read := shot_read(index,delta)
	var reacting: bool=not read.is_empty() and read.age<read.delay
	# Come off the line for a reachable through ball or an isolated attacker.
	if in_box and ball.y<1.05 and game.last_touch!=p.team and bv.length()<17 and not (index==0 and returning):
		var defender_distance := INF
		for q in game.players:
			if q.visible and q.team==p.team and not q.keeper: defender_distance=minf(defender_distance,game.flat_distance(q.position,ball))
		var distance: float=game.flat_distance(p.position,ball)
		if distance<8 or distance<defender_distance+1:
			target=ball+bv*0.18
			target.z=-forward*clampf(absf(target.z),38,49)
			target.x=clampf(target.x,-14,14)
			modes[index]="rush"
	# Read a cross's descending arc; jump only when the body can reach it.
	if read.is_empty() and in_box and ball.y>0.9 and absf(bv.x)>3.5 and p.action_timer<=0:
		for step in range(2,11):
			var time := step*0.1
			var predicted: Vector3=ball+bv*time-Vector3.UP*4.905*time*time
			if predicted.y<1.4 or predicted.y>3.1 or absf(predicted.x)>17 or absf(predicted.z)<35 or absf(predicted.z)>49.5: continue
			var travel: float=game.flat_distance(p.position,predicted)
			if travel>time*6.0+0.7: continue
			target=predicted*Vector3(1,0,1)
			modes[index]="cross"
			if time<=0.5 and travel<1.35 and p.is_on_floor() and p.tackle_cooldown<=0:
				p.start_claim(predicted.y,time)
			break
	var look: Vector3=(ball-p.position)*Vector3(1,0,1)
	if look.length()>0.1 and p.action_timer<=0: p.facing=look.normalized()
	if reacting:
		target=read.set
		modes[index]="react"
	elif not read.is_empty() and in_box and absf(bv.z)>5:
		var time: float=(p.position.z-ball.z)/bv.z
		if time>0 and time<0.70:
			var predicted: float=read.x
			var height: float=read.height
			target.x=clampf(predicted,-4.3,4.3)
			var reach: float=predicted-p.position.x
			if absf(reach)<1.15 and time<.30 and time>.04 and height<1.65:
				var style := "foot" if height<.55 else "spread"
				p.keeper_motion.start(p,style,Vector3(predicted,height,p.position.z))
			if absf(reach)>1.05 and absf(reach)<3.9 and time<0.52 and height<2.65:
				p.start_dive(reach,height,time)
	if called and p.action_timer<=0:
		var anticipation: float=clampf(game.flat_distance(p.position,ball)/12,0.12,0.65)
		target=ball+bv.limit_length(25)*anticipation
		target=Vector3(clampf(target.x,-(P.HALF_WIDTH-2),(P.HALF_WIDTH-2)),0,clampf(target.z,-48,48))
		p.sprinting=game.flat_distance(p.position,target)>1.4
		modes[index]="manual_rush"
	# Outside the penalty area a rushing keeper must use his feet.
	if not in_box and (called or (index==0 and returning)) and game.can_touch(index,1.15) and p.touch_cooldown<=0 and game.kick_lock<=0:
		if game.strike(index,Vector3(6 if ball.x>=0 else -6,2.5,forward*20)):
			stop_rush()
		return target
	# Every hand save requires proximity and the ball inside the penalty area.
	var rebound: bool=game.last_kicker==index and p.motion_clock-p.keeper_motion.saved_at<2.2
	if rebound and in_box and game.flat_distance(p.position,ball)<4:
		# Recover where the first save landed, then attack the loose ball. An
		# automatic retreat to the goal line would abandon every second attempt.
		target=ball+bv*.12 if p.keeper_motion.rebound_ready(p) else p.position
		modes[index]="rebound"
	if in_box and (game.last_touch!=p.team or rebound) and ball.y<.7 and bv.length()<12 and game.flat_distance(p.position,ball)<1.45 and not reacting:
		if rebound and p.keeper_motion.rebound_ready(p) and p.pose!="keeper_rebound":
			p.keeper_motion.start(p,"rebound",ball,true)
		elif not rebound: p.keeper_motion.start(p,"smother",ball)
	if in_box and p.can_save(ball) and p.touch_cooldown<=0 and game.kick_lock<=0 and (not reacting or bv.length()<8):
		var opponent: bool=game.last_touch!=p.team or rebound
		var glove_distance: float=minf(p.left_hand.global_position.distance_to(ball),p.right_hand.global_position.distance_to(ball))
		var spill := handling_error(index,read)
		if opponent and in_box and bv.length()<11.5 and glove_distance<0.65 and not spill:
			if not game.rules.before_touch(index,false): return target
			game.saves[p.team]+=1
			game.stadium.react("save",p.team,ball)
			game.reactions.saved(index)
			game.dribbler=-1
			game.last_touch=p.team
			game.last_kicker=index
			game.ball.hold(p)
			game.team_control.touched(index)
			p.keeper_motion.saved(p)
			p.keeper_motion.secured=true
			holding=index
			hold_age=0
			if index==0: stop_rush()
			p.set_piece_pose="" if p.pose.begins_with("keeper_") and p.action_timer>0 else "carry"
			game.announce("KALECİ TOPU KONTROL ETTİ")
		elif opponent:
			if not game.strike(index,loose_parry(index) if spill else safe_parry(index),0,true): return target
			game.saves[p.team]+=1
			game.stadium.react("save",p.team,ball)
			game.reactions.saved(index)
			p.keeper_motion.saved(p)
			game.announce("KALECİDEN SEKTİ · TOP OYUNDA" if spill else "KALECİ TOPU YANA ÇELDİ")
		elif bv.length()<9:
			if game.autonomous_kicks(p.team): game.strike(index,Vector3(7 if ball.x>=0 else -7,6.5,forward*22))
			elif not game.player_lock and not game.training:
				game.team_control.select(index)
	return target
