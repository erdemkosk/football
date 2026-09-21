extends RefCounted
var game
var holding := -1
var hold_age := 0.0
var modes: Dictionary = {}

func reset() -> void:
	if holding>=0: game.players[holding].set_piece_pose=""
	holding=-1
	hold_age=0
	modes.clear()

func safe_parry(index: int) -> Vector3:
	var p=game.players[index]
	var forward := -1.0 if p.team==0 else 1.0
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
	var ball: Vector3=game.ball.position
	var bv: Vector3=game.ball.linear_velocity
	var forward := -1.0 if p.team==0 else 1.0
	var goal := Vector3(0,0,-forward*50)
	var depth := 50+ball.z*forward
	var in_box := depth>=0 and depth<16.5 and absf(ball.x)<20.16
	var direction: Vector3=(ball-goal)*Vector3(1,0,1)
	var advance := clampf(direction.length()*0.13,1.0,3.5)
	var target: Vector3=goal+direction.normalized()*advance
	target.x=clampf(target.x,-3.3,3.3)
	modes[index]="angle"
	if holding==index:
		if game.ball.held_by!=p: reset(); return target
		hold_age+=delta
		p.set_piece_pose="carry"
		p.facing=Vector3(0,0,forward)
		game.ball.hold_target=p.hand_center()
		modes[index]="hold"
		if hold_age>1.15:
			var receiver := -1
			var best_risk := 0.5
			for j in range(game.players.size()):
				var q=game.players[j]
				if not q.visible or q.team!=p.team or q.keeper: continue
				var distance: float=game.flat_distance(p.position,q.position)
				if distance<7 or distance>28: continue
				var route=game.Passing.plan(ball,q.position,q.velocity,false)
				var risk: float=game.Passing.risk(ball,route,p.team,game.players)
				if risk<best_risk: best_risk=risk; receiver=j
			p.set_piece_pose=""
			holding=-1
			if receiver>=0: game.deliver_pass(index,receiver,false)
			else: game.strike(index,Vector3(7 if ball.x>=0 else -7,7,forward*22))
			p.kick_timer=0
			p.set_piece_pose="throw"
			p.handling_blend=0.75
			p.wall_hold=0.4
		return p.position
	# Come off the line for a reachable through ball or an isolated attacker.
	if in_box and ball.y<1.05 and game.last_touch!=p.team and bv.length()<17:
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
	if in_box and ball.y>0.9 and absf(bv.x)>3.5 and p.action_timer<=0:
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
	if absf(bv.z)>5:
		var time: float=(p.position.z-ball.z)/bv.z
		if time>0 and time<0.70:
			var predicted: float=ball.x+bv.x*time
			var height: float=maxf(0.22,ball.y+bv.y*time-4.905*time*time)
			target.x=clampf(predicted,-4.3,4.3)
			var reach: float=predicted-p.position.x
			if absf(reach)>1.2 and absf(reach)<4.3 and time<0.57 and height<2.65:
				p.start_dive(reach,height,time)
	# Every save still requires actual glove/body proximity.
	if p.can_save(ball) and p.touch_cooldown<=0 and game.kick_lock<=0:
		var opponent: bool=game.last_touch!=p.team
		var glove_distance: float=minf(p.left_hand.global_position.distance_to(ball),p.right_hand.global_position.distance_to(ball))
		if opponent and in_box and bv.length()<14 and glove_distance<0.75:
			if not game.rules.before_touch(index,false): return target
			game.saves[p.team]+=1
			game.stadium.react("save",p.team,ball)
			game.dribbler=-1
			game.last_touch=p.team
			game.last_kicker=index
			game.ball.hold(p)
			holding=index
			hold_age=0
			p.set_piece_pose="carry"
			game.announce("KALECİ TOPU KONTROL ETTİ")
		elif opponent:
			game.saves[p.team]+=1
			game.stadium.react("save",p.team,ball)
			game.strike(index,safe_parry(index),0,true)
			p.touch_cooldown=0.9
			game.announce("KALECİ TOPU YANA ÇELDİ")
		elif bv.length()<9:
			game.strike(index,Vector3(7 if ball.x>=0 else -7,6.5,forward*22))
	return target
