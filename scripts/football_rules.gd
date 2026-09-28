extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Active-play offside and the first/second-touch restrictions on restarts.
var advantage: Dictionary = {}
var deferred_cards: Array = []
var game
var candidates: Array[int] = []
var phase_team := -1
var restart_kind := ""
var restart_team := -1
var restart_taker := -1
var first_kick := false
var touch_age := 0.0
var last_contact := -1
var tackles: Dictionary = {}
var card_text := ""
var card_red := false
var card_time := 0.0

func reset() -> void:
	candidates.clear()
	phase_team=-1
	restart_kind=""
	restart_team=-1
	restart_taker=-1
	first_kick=false
	touch_age=0
	last_contact=-1
	tackles.clear()

func restart_taken(kind: String,team: int,taker: int) -> void:
	game.referee_flow.taking(kind,team,taker)
	if kind=="SANTRA" and game.match_time<.5: game.broadcast_event("kickoff")
	elif kind=="SANTRA" and absf(game.match_time-game.LENGTH*.5)<.5: game.broadcast_event("second_half")
	reset()
	restart_kind=kind
	restart_team=team
	restart_taker=taker
	first_kick=true

func before_touch(index: int,deliberate: bool=true) -> bool:
	if game.training: return true
	if not game.referee_flow.before_touch(index): return false
	if first_kick and index==restart_taker: return true
	if index in candidates:
		game.begin_restart("ENDİREKT VURUŞ",1-game.players[index].team,game.players[index].position)
		game.referees.offside(game.players[index].team,game.players[index].position)
		game.reactions.appeal(index,game.players[index].position)
		return false
	if restart_taker==index and touch_age>0.45:
		game.begin_restart("ENDİREKT VURUŞ",1-game.players[index].team,game.ball.position)
		return false
	if restart_taker>=0 and index!=restart_taker:
		restart_taker=-1
		restart_kind=""
	if deliberate and game.players[index].team!=phase_team:
		candidates.clear()
		phase_team=-1
	last_contact=index
	game.referees.touch(index)
	return true

func kicked(index: int) -> void:
	var exempt := first_kick and restart_kind in ["TAÇ","KORNER","KALE VURUŞU"]
	first_kick=false
	touch_age=0
	last_contact=index
	candidates.clear()
	phase_team=game.players[index].team
	if game.training or exempt: return
	var forward: float = game.attack_sign(phase_team)
	var line := offside_line(phase_team)
	for i in range(game.players.size()):
		var p=game.players[i]
		if p.visible and i!=index and p.team==phase_team and p.position.z*forward>line+0.18:
			candidates.append(i)

func offside_line(attacking_team: int) -> float:
	var forward: float = game.attack_sign(attacking_team)
	var line := 0.0
	# The second-deepest defender, tracked in one pass instead of sorting a
	# freshly allocated list on every AI, support and assistant-referee query.
	var deepest := -INF
	var second := -INF
	var defenders := 0
	for p in game.players:
		if p.visible and p.team!=attacking_team:
			var depth: float=p.position.z*forward
			defenders+=1
			if depth>deepest:
				second=deepest; deepest=depth
			elif depth>second: second=depth
	if defenders>=2: line=second
	line=maxf(line,game.ball.position.z*forward)
	line=maxf(line,0)
	return line

func update(delta: float) -> void:
	update_advantage(delta)
	if game.state!="playing": return
	touch_age+=delta
	# Contact events include headers, deflections and rebounds, not just possession.
	for body in game.ball.get_colliding_bodies():
		var index: int=game.players.find(body)
		if index<0 or (index==last_contact and touch_age<0.45): continue
		if not before_touch(index,false): return

func allows_goal(team: int) -> bool:
	if not advantage.is_empty() and team!=int(advantage.team):
		recall_advantage(); return false
	if restart_taker<0: return true
	if team!=restart_team:
		game.begin_restart("KORNER",team,Vector3(signf(game.ball.position.x+0.001)*(P.HALF_WIDTH-.4),0,signf(game.ball.position.z)*49.6))
		return false
	if restart_kind in ["TAÇ","ENDİREKT VURUŞ"]:
		game.begin_restart("KALE VURUŞU",1-team,Vector3(0,0,game.attack_sign(team)*45))
		return false
	return true

func foul(offender: int,victim: int,reckless: bool=false,severe: bool=false) -> void:
	var p=game.players[victim]
	var offender_player=game.players[offender]
	var point: Vector3=p.position*Vector3(1,0,1)
	var goal_side: float=-game.attack_sign(offender_player.team)
	var penalty := absf(point.x)<=20.16 and point.z*goal_side>=33.5 and point.z*goal_side<=50
	game.foul_cooldown=4
	offender_player.fouls_committed+=1
	var booking: bool=reckless or severe or offender_player.fouls_committed%3==0
	# Staying on one's feet can preserve the advantage too. Proximity to a
	# fast pass alone does not establish possession or a useful continuation.
	var owner := advantage_owner()
	var clear_attack: bool=owner>=0 and game.state=="playing" and game.players[owner].team==p.team and advantage_open(owner,point)
	if not penalty and not severe and clear_attack and (not booking or offender_player.yellow_cards==0):
		if booking and offender not in deferred_cards: deferred_cards.append(offender)
		# A second foul cannot erase the earlier, better free-kick position.
		if not advantage.is_empty() and int(advantage.team)==p.team and advantage.point.z*game.attack_sign(p.team)>point.z*game.attack_sign(p.team): point=advantage.point
		advantage={"team":p.team,"point":point,"age":0.0,"controlled":0.0}
		game.referees.decision="AVANTAJ"
		game.referees.decision_age=0
		game.referees.signal_time=2.0
		game.referees.actors[0].signal_pose("advantage")
		return
	if booking: book(offender,severe,victim)
	# During the last attack, fouling in shooting range must not buy an
	# immediate final whistle. Give the attacking side its awarded kick.
	if not penalty and point.z*game.attack_sign(p.team)>=26: game.referee_flow.allow_recalled_foul(p.team)
	game.begin_restart("PENALTI" if penalty else "SERBEST VURUŞ",p.team,Vector3(0,0,goal_side*39) if penalty else point)
	if booking: game.referees.show_card(offender_player.position,card_red,severe)
	game.stadium.react("foul",offender_player.team,point)
	game.reactions.dispute(victim,offender)
	var remaining := 0
	for teammate in game.players:
		if teammate.team==offender_player.team and not teammate.dismissed: remaining+=1
	if remaining<7:
		game.ending_reason="YEDİ OYUNCUDAN AZ · MAÇ TATİL EDİLDİ"
		game.state="finished"
		game.ball.active=false

func book(offender: int,direct: bool=false,victim: int=-1) -> void:
	var p=game.players[offender]
	if p.dismissed: return
	if not direct: p.yellow_cards+=1
	card_red=direct or p.yellow_cards>=2
	card_time=5
	card_text=p.display_name+" · "+("DOĞRUDAN KIRMIZI" if direct else ("İKİNCİ SARI / KIRMIZI" if card_red else "SARI KART"))
	game.broadcast_event("red" if card_red else "yellow",{"index":offender})
	if card_red:
		game.send_off.begin(offender,victim)
		p.dismissed=true
		game.management.refresh_captains()
		game.career.remember_player(p)
		p.visible=false
		p.collision_layer=0
		p.desired=Vector3.ZERO
		p.chosen=false
		p.marker.visible=false
		if game.controlled==offender: game.switch_player()

func advantage_owner() -> int:
	if game.ball.held_by!=null: return game.players.find(game.ball.held_by)
	var owner: int=game.dribbler
	if owner>=0:
		var p=game.players[owner]
		if p.visible and not p.dismissed and p.action_timer<=0 and game.flat_distance(p.position,game.ball.position)<1.65: return owner
	if game.ball.pending_kick or game.ball.position.y>.8: return -1
	owner=game.nearest_to_ball(1.1)
	if owner<0: return -1
	var p=game.players[owner]
	if not p.visible or p.dismissed or p.action_timer>0 or (game.ball.linear_velocity-p.velocity).length()>8: return -1
	return owner

func advantage_open(owner: int,point: Vector3) -> bool:
	var p=game.players[owner]
	var f: float=game.attack_sign(p.team)
	if p.keeper or p.position.z*f< -28: return false
	var heading := Vector3(0,0,f)
	var progress: float=(p.position.z-point.z)*f
	if progress<2 and p.velocity.z*f<.8 and p.position.z*f<30: return false
	for q in game.players:
		if not q.visible or q.dismissed or q.team==p.team or q.action_timer>0: continue
		var gap: Vector3=(q.position-p.position)*Vector3(1,0,1)
		if gap.dot(heading)>.1 and gap.length()<2.0: return false
	return true

func advantage_strike(index: int,velocity: Vector3,shot: bool) -> void:
	if advantage.is_empty() or game.players[index].team!=int(advantage.team) or not shot: return
	var team: int=advantage.team
	var goal := Vector3(0,0,game.attack_sign(team)*50)
	var toward: Vector3=(goal-game.ball.position)*Vector3(1,0,1)
	# A real shooting opportunity consumes the advantage even if it is missed
	# or saved. The foul is not a free second attempt after taking that shot.
	if toward.length()<34 and (velocity*Vector3(1,0,1)).normalized().dot(toward.normalized())>.55: advantage.clear()

func advantage_restart(kind: String,team: int,point: Vector3) -> Dictionary:
	var pending: Dictionary=advantage.duplicate()
	advantage.clear()
	var awarded: int=pending.team
	var better: bool=team==awarded and (kind=="PENALTI" or kind=="SERBEST VURUŞ" and point.z*game.attack_sign(team)>pending.point.z*game.attack_sign(team))
	game.referee_flow.allow_recalled_foul(awarded)
	return {"kind":kind if better else "SERBEST VURUŞ","team":awarded,"point":point if better else pending.point}

func recall_advantage() -> void:
	if advantage.is_empty(): return
	var decision: Dictionary=advantage.duplicate()
	advantage.clear()
	game.referee_flow.allow_recalled_foul(decision.team)
	game.begin_restart("SERBEST VURUŞ",decision.team,decision.point)
	game.stadium.react("foul",1-int(decision.team),decision.point)

func update_advantage(delta: float) -> void:
	if advantage.is_empty() or game.state!="playing": return
	advantage.age+=delta
	var owner := advantage_owner()
	if owner>=0 and game.players[owner].team!=int(advantage.team): recall_advantage(); return
	var progressed := false
	if owner>=0:
		advantage.controlled=float(advantage.get("controlled",0.0))+delta
		var f: float=game.attack_sign(advantage.team)
		progressed=(game.players[owner].position.z-advantage.point.z)*f>4.0 and advantage.controlled>=.25 and advantage_open(owner,advantage.point)
	if progressed: advantage.clear()
	elif advantage.age>=3.0: recall_advantage()

func show_deferred_cards() -> void:
	for offender in deferred_cards:
		book(offender)
		game.referees.show_card(game.players[offender].position,card_red)
	deferred_cards.clear()

func start_tackle(index: int,direction: Vector3) -> void:
	var p=game.players[index]
	if p.tackle_cooldown>0 or p.dismissed or p.action_timer>0: return
	p.start_slide(direction)
	game.audio.contact("slide",0.3,1.0 if index==game.controlled else 0.4)
	tackles[index]=p.position

func resolve_tackles() -> void:
	for index in tackles.keys():
		var p=game.players[index]
		if p.action_timer<=0 or p.pose!="slide":
			tackles.erase(index)
			continue
		var start: Vector3=tackles[index]
		var end: Vector3=p.position+p.facing*0.85
		start.y=0
		end.y=0
		var ball_point: Vector3=game.ball.position*Vector3(1,0,1)
		var near_ball=Geometry3D.get_closest_point_to_segment(ball_point,start,end)
		var ball_hit: bool=near_ball.distance_to(ball_point)<0.65 and game.ball.position.y<0.85
		var victim := -1
		var first := INF
		for j in range(game.players.size()):
			var q=game.players[j]
			if q.team==p.team or not q.visible: continue
			# Only actual raised boots clear the sliding leg; late hops still trip.
			if q.pose=="hurdle" and q.action_timer>0:
				var boots: float=minf(q.left_knee.to_global(q.ball_actions.BOOT).y,q.right_knee.to_global(q.ball_actions.BOOT).y)
				if boots>.34 and q.position.y>.08: continue
			var q_point: Vector3=q.position*Vector3(1,0,1)
			var near=Geometry3D.get_closest_point_to_segment(q_point,start,end)
			if near.distance_to(q_point)<0.48 and near.distance_to(start)<first:
				first=near.distance_to(start)
				victim=j
		if victim>=0 and (not ball_hit or first+0.28<near_ball.distance_to(start)) and not game.training:
			var reckless: bool=p.facing.dot(game.players[victim].facing)>0.5 and p.velocity.length()>8
			var severe: bool=reckless and not ball_hit and first>0.45 and p.velocity.length()>16.5
			game.tackle_impact(index,victim)
			foul(index,victim,reckless,severe)
			return
		if ball_hit:
			game.strike(index,p.facing*9+Vector3.UP*0.6,0,false,"ball_tackle")
			if victim>=0: game.tackle_impact(index,victim,true)
			tackles.erase(index)
			if game.state!="playing": return
			# A successful ball-first challenge is resolved once.
		else: tackles[index]=p.position
