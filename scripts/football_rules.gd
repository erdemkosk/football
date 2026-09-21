extends RefCounted
## Active-play offside and the first/second-touch restrictions on restarts.
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
	reset()
	restart_kind=kind
	restart_team=team
	restart_taker=taker
	first_kick=true

func before_touch(index: int,deliberate: bool=true) -> bool:
	if game.training: return true
	if first_kick and index==restart_taker: return true
	if index in candidates:
		game.begin_restart("ENDİREKT VURUŞ",1-game.players[index].team,game.players[index].position)
		game.referees.offside(game.players[index].team,game.players[index].position)
		game.announce("OFSAYT · "+game.players[index].display_name)
		return false
	if restart_taker==index and touch_age>0.45:
		game.begin_restart("ENDİREKT VURUŞ",1-game.players[index].team,game.ball.position)
		game.announce("ÇİFT DOKUNUŞ · ENDİREKT VURUŞ")
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
	var forward := -1.0 if phase_team==0 else 1.0
	var line := offside_line(phase_team)
	for i in range(game.players.size()):
		var p=game.players[i]
		if p.visible and i!=index and p.team==phase_team and p.position.z*forward>line+0.18:
			candidates.append(i)

func offside_line(attacking_team: int) -> float:
	var forward := -1.0 if attacking_team==0 else 1.0
	var line := 0.0
	var defensive_line: Array[float]=[]
	for p in game.players:
		if p.visible and p.team!=attacking_team: defensive_line.append(p.position.z*forward)
	defensive_line.sort()
	if defensive_line.size()>=2: line=defensive_line[-2]
	line=maxf(line,game.ball.position.z*forward)
	line=maxf(line,0)
	return line

func update(delta: float) -> void:
	touch_age+=delta
	# Contact events include headers, deflections and rebounds, not just possession.
	for body in game.ball.get_colliding_bodies():
		var index: int=game.players.find(body)
		if index<0 or (index==last_contact and touch_age<0.45): continue
		if not before_touch(index,false): return

func allows_goal(team: int) -> bool:
	if restart_taker<0: return true
	if team!=restart_team:
		game.begin_restart("KORNER",team,Vector3(signf(game.ball.position.x+0.001)*31.6,0,signf(game.ball.position.z)*49.6))
		game.announce("DURAN TOPTAN DOĞRUDAN KENDİ KALESİNE · KORNER")
		return false
	if restart_kind in ["TAÇ","ENDİREKT VURUŞ"]:
		game.begin_restart("KALE VURUŞU",1-team,Vector3(0,0,-45 if team==0 else 45))
		game.announce("DOĞRUDAN GOL GEÇERSİZ · KALE VURUŞU")
		return false
	return true

func foul(offender: int,victim: int,reckless: bool=false) -> void:
	var p=game.players[victim]
	var offender_player=game.players[offender]
	var point: Vector3=p.position*Vector3(1,0,1)
	var goal_side := 1.0 if game.players[offender].team==0 else -1.0
	var penalty := absf(point.x)<=20.16 and point.z*goal_side>=33.5 and point.z*goal_side<=50
	game.foul_cooldown=4
	offender_player.fouls_committed+=1
	var booking: bool=reckless or offender_player.fouls_committed%3==0
	if booking:
		offender_player.yellow_cards+=1
		card_red=offender_player.yellow_cards>=2
		card_time=5
		card_text=offender_player.display_name+" · "+("İKİNCİ SARI / KIRMIZI" if card_red else "SARI KART")
		if card_red:
			offender_player.dismissed=true
			offender_player.visible=false
			offender_player.collision_layer=0
			if game.controlled==offender: game.switch_player()
	game.begin_restart("PENALTI" if penalty else "SERBEST VURUŞ",p.team,Vector3(0,0,goal_side*39) if penalty else point)
	if booking: game.referees.show_card(offender_player.position,card_red)
	var remaining := 0
	for teammate in game.players:
		if teammate.team==offender_player.team and not teammate.dismissed: remaining+=1
	if remaining<7:
		game.ending_reason="YEDİ OYUNCUDAN AZ · MAÇ TATİL EDİLDİ"
		game.state="finished"
		game.ball.active=false
		game.announce("YEDİ OYUNCUDAN AZ · MAÇ TATİL EDİLDİ")

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
			var q_point: Vector3=q.position*Vector3(1,0,1)
			var near=Geometry3D.get_closest_point_to_segment(q_point,start,end)
			if near.distance_to(q_point)<0.68 and near.distance_to(start)<first:
				first=near.distance_to(start)
				victim=j
		if victim>=0 and (not ball_hit or first+0.12<near_ball.distance_to(start)) and not game.training:
			var reckless: bool=p.facing.dot(game.players[victim].facing)>0.5 and p.velocity.length()>8
			game.tackle_impact(index,victim)
			foul(index,victim,reckless)
			return
		if ball_hit:
			game.strike(index,p.facing*9+Vector3.UP*0.6,0,false,"ball_tackle")
			if victim>=0: game.tackle_impact(index,victim,true)
			tackles.erase(index)
			if game.state!="playing": return
			# A successful ball-first challenge is resolved once.
		else: tackles[index]=p.position
