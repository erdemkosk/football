extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Roster slots remain stable for physics and AI; shirt identity is independent.
var game
const MAX_SUBS := 3
var formation := 0
var opponent_formation := 0
var mentality := 1
var pressing := 1
var line_height := 1
var width := 1
var tempo := 1
var runs := 1
var fullbacks := 1
var anchor := true
var difficulty := 1
var bench: Array = [[],[]]
var used := [0,0]
var pending: Array = []
var originals: Array = []
var reserve_originals: Array = [[],[]]
var transit: Dictionary = {}
var lost_time := [0.0,0.0]
var added := [-1.0,-1.0]
const FORMATIONS := ["4-4-2","4-3-3","3-5-2"]
const SHAPES := [
	[Vector2(0,46),Vector2(-23,28),Vector2(-8,31),Vector2(8,31),Vector2(23,28),Vector2(-20,7),Vector2(-6,13),Vector2(9,10),Vector2(22,5),Vector2(-5,-1),Vector2(9,-7)],
	[Vector2(0,46),Vector2(-23,28),Vector2(-8,31),Vector2(8,31),Vector2(23,28),Vector2(-13,12),Vector2(0,18),Vector2(13,12),Vector2(-23,-5),Vector2(0,-10),Vector2(23,-5)],
	[Vector2(0,46),Vector2(-16,31),Vector2(0,33),Vector2(16,31),Vector2(-26,9),Vector2(-12,13),Vector2(0,20),Vector2(12,13),Vector2(26,9),Vector2(-7,-7),Vector2(7,-7)]]

func setup() -> void:
	for p in game.players: originals.append(p.identity())
	reset()

func reset() -> void:
	opponent_formation=int(game.clubs.career_clubs[1].plan.formation) if not game.clubs.career_clubs.is_empty() else 0
	bench=[[],[]]
	used=[0,0]
	pending.clear()
	transit.clear()
	lost_time=[0.0,0.0]
	added=[-1.0,-1.0]
	for team in range(2):
		for j in range(7):
			bench[team].append({"name":(["EFE","UMUT","TUNA","OZAN","BARAN","YİĞİT","ATA"] if team==0 else ["JOEL","MIRO","NOAH","LARS","LUIS","ADAM","FINN"])[j],"shirt":12+j,"keeper":j==0,"used":false})
			bench[team][-1].merge(preload("res://scripts/player_physique.gd").profile(team,11+j,j==0))
	for side in range(2):
		if not reserve_originals[side].is_empty(): bench[side]=reserve_originals[side].duplicate(true)
	for i in range(originals.size()):
		var p=game.players[i]
		p.apply_identity(originals[i])
	apply_formation()

func apply_formation() -> void:
	for p in game.players:
		var shape: Array=SHAPES[formation if p.team==0 else opponent_formation]
		var pos: Vector2=shape[p.number-1]
		p.home=Vector3(pos.x*P.WIDTH_RATIO,0,pos.y)*(-game.attack_sign(p.team))
		p.home.x*=([.78,1.0,1.14][width] if p.team==0 else 1.0)

func committed(team: int) -> int:
	var count: int=used[team]
	for index in transit:
		if game.players[index].team==team and transit[index].phase=="out": count+=1
	for item in pending:
		if game.players[item.slot].team==team: count+=1
	return count

func substitution_reason(slot: int,reserve: int) -> String:
	if game.training or game.state in ["menu","finished"]: return "Oyuncu değişikliği maç sırasında yapılır."
	if slot<0 or slot>=game.players.size() or reserve<0 or reserve>=7: return "Geçersiz seçim."
	var p=game.players[slot]
	var b: Dictionary=bench[p.team][reserve]
	if p.dismissed: return "İhraç edilen oyuncu değiştirilemez."
	if transit.has(slot): return "Bu oyuncunun değişikliği devam ediyor."
	if b.used: return "Bu yedek maçta zaten kullanıldı."
	if p.keeper!=b.keeper: return "Kaleci yalnızca yedek kaleciyle değişir."
	for index in transit:
		if game.players[index].team==p.team and transit[index].reserve==reserve: return "Bu yedek şu anda sahaya giriyor."
	for item in pending:
		if item.slot==slot: return "Bu oyuncunun bekleyen değişikliğini önce iptal et."
		if game.players[item.slot].team==p.team and item.reserve==reserve: return "Bu yedek başka bir oyuncu için seçildi."
	if committed(p.team)>=MAX_SUBS: return "Üç oyuncu değişikliği hakkı doldu."
	return ""

func queue_sub(slot: int,reserve: int) -> String:
	var reason := substitution_reason(slot,reserve)
	if reason!="": return reason
	pending.append({"slot":slot,"reserve":reserve})
	game.stadium.sidelines.instruct(game.players[slot].team,"substitute")
	return "%s → %s · Bir sonraki duraklamada" % [game.players[slot].display_name,bench[game.players[slot].team][reserve].name]

static func natural_role(shirt: int,keeper: bool) -> int:
	if keeper: return 0
	if shirt in [2,3,4,5,13,14]: return 1
	if shirt in [6,7,8,9,15,16]: return 2
	return 3

func slot_role(index: int) -> int:
	var p=game.players[index]
	if p.keeper: return 0
	var slot := index%11
	var shape: int=formation if p.team==0 else opponent_formation
	if slot<=(3 if shape==2 else 4): return 1
	if slot>=(8 if shape==1 else 9): return 3
	return 2

func suggestion(team: int,threshold: float=0.40,excluded: Array=[]) -> Dictionary:
	if committed(team)>=MAX_SUBS or game.training: return {}
	var best: Dictionary={}
	var lowest := threshold
	for slot in range(team*11+1,team*11+11):
		var p=game.players[slot]
		if not p.visible or p.dismissed or p.energy>=lowest or p.shirt_number in excluded: continue
		for reserve in range(1,7):
			var b: Dictionary=bench[team][reserve]
			if int(b.get("role",natural_role(b.shirt,b.keeper)))!=slot_role(slot) or substitution_reason(slot,reserve)!="": continue
			lowest=p.energy
			best={"slot":slot,"reserve":reserve,"shirt":p.shirt_number,"incoming":b.shirt}
			break
	return best

func live_plan(value: int) -> void:
	value=clampi(value,0,2)
	if game.career.in_match:
		game.career.club().plan=game.career.club().plans[value].duplicate(true)
		game.career.apply_plan(game.career.club().plan)
		apply_formation()
		game.stadium.sidelines.instruct(0,["defend","balance","attack"][value])
		return
	mentality=value; pressing=value; line_height=value
	game.stadium.sidelines.instruct(0,["defend","balance","attack"][value])

func prepare_substitutions() -> void:
	if game.training: return
	# Each team's allowance includes accepted and still-running changes.
	# The opponent's decision never depends on whether our team queued a change.
	var next: Dictionary=game.opponent_coach.substitution()
	if not next.is_empty():
		queue_sub(next.slot,next.reserve)
		game.opponent_coach.substituted()
	for item in pending:
		var p=game.players[item.slot]
		if p.dismissed or bench[p.team][item.reserve].used or transit.has(item.slot): continue
		var reserved: int=used[p.team]
		for index in transit:
			if game.players[index].team==p.team and transit[index].phase=="out": reserved+=1
		if reserved>=MAX_SUBS: continue
		transit[item.slot]={"reserve":item.reserve,"phase":"out","target":p.position,"old":p.display_name}
		game.stadium.sidelines.start_entry(item.slot,item.reserve,Vector3(P.HALF_WIDTH+.8,0,(-3 if p.team==0 else 3)+(item.slot%11)*1.2))
	pending.clear()

func update_substitutions(delta: float) -> bool:
	if transit.is_empty(): return false
	for p in game.players:
		p.desired=Vector3.ZERO
		p.sprinting=false
	for index in transit.keys():
		var item: Dictionary=transit[index]
		var p=game.players[index]
		var gate := Vector3(P.HALF_WIDTH+.8,0,(-3 if p.team==0 else 3)+(index%11)*1.2)
		var destination: Vector3=gate if item.phase=="out" else item.target
		destination=game.set_pieces.recovery.around_goal(p.position,destination)
		var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
		var distance_to_destination := offset.length()
		var greeted: bool=game.stadium.sidelines.step_entry(index,p,delta) if item.phase=="out" else true
		if item.has("waypoint") and game.flat_distance(p.position,item.waypoint)<0.4: item.erase("waypoint")
		if not item.has("waypoint") and offset.length()>0.8:
			var ahead := offset.normalized()
			for other in game.players:
				if other==p or not other.visible: continue
				var obstacle: Vector3=(other.position-p.position)*Vector3(1,0,1)
				var along := obstacle.dot(ahead)
				if along> -0.15 and along<2.0 and (obstacle-ahead*along).length()<0.95:
					item.waypoint=other.position+Vector3(-ahead.z,0,ahead.x)*1.6
					break
		if item.has("waypoint"): offset=(item.waypoint-p.position)*Vector3(1,0,1)
		p.desired=offset.normalized()*minf(1,offset.length())
		if distance_to_destination<(0.22 if item.phase=="out" else 0.7):
			item.erase("waypoint")
			if item.phase=="out":
				if not greeted:
					p.desired=Vector3.ZERO
					continue
				var b: Dictionary=bench[p.team][item.reserve]
				b.used=true
				used[p.team]+=1
				game.career.remember_player(p)
				p.apply_identity(b)
				p.apply_kit(game.clubs.kit(p.team))
				p.reset_stamina()
				game.career.enter_player(p)
				p.yellow_cards=0
				p.fouls_committed=0
				p.action_timer=0
				p.pose="run"
				p.celebration=""
				game.stadium.sidelines.finish_entry(index)
				item.phase="in"
				game.announce("DEĞİŞİKLİK · "+item.old+" → "+p.display_name)
			else: transit.erase(index)
	for index in range(game.players.size()):
		var p=game.players[index]
		if not p.visible: continue
		p.stamina_free_movement=true
		var exiting: bool=transit.has(index) and transit[index].phase=="out"
		p.step(delta,10.4 if exiting else 0.0)
		p.stamina_free_movement=false
	return true

func reaction(team: int) -> float:
	return [0.9,0.55,0.30][difficulty] if team==1 else 0.55

func pass_error(team: int) -> float:
	return [0.065,0.025,0.008][difficulty] if team==1 else 0.015

func adjust_target(index: int,target: Vector3) -> Vector3:
	var p=game.players[index]
	if p.keeper: return target
	var forward: float=game.attack_sign(p.team)
	if p.team==0:
		target.z+=forward*(mentality-1)*5
		if p.number<=5: target.z+=forward*(line_height-1)*7
		if game.carrier>=0 and game.players[game.carrier].team!=p.team:
			var distance: float=game.flat_distance(p.position,game.ball.position)
			if distance<([5.0,9.0,15.0][pressing]):
				target=target.lerp(game.ball.position,[0.2,0.5,0.85][pressing])
				p.sprinting=pressing==2 and p.energy>0.35
	elif game.carrier>=0 and game.players[game.carrier].team==0:
		var gap: float=game.flat_distance(p.position,game.ball.position)
		if gap<[5.0,9.0,13.0][difficulty]: target=target.lerp(game.ball.position,[0.2,0.5,0.75][difficulty])
	elif p.team==1 and game.carrier>=0 and game.players[game.carrier].team==1:
		# Late chasing teams commit runners; a leading team keeps more cover.
		target.z+=forward*(game.team_tactics.plan_for(1)-1)*(4 if slot_role(index)==1 else 6)
	target.x=clampf(target.x,-(P.HALF_WIDTH-3),(P.HALF_WIDTH-3))
	target.z=clampf(target.z,-45,45)
	return target

func detail(team: int,key: String) -> int:
	if team==0: return int(get(key))
	if not game.clubs.career_clubs.is_empty(): return int(game.clubs.career_clubs[1].plan.get(key,1))
	return 1

func update_clock(delta: float) -> void:
	if game.career.cups.extra_active(): return
	if game.training: return
	# Waiting for the opening kickoff is before play, not injury time.
	if game.match_time<=0: return
	var half_index: int=game.half-1
	# Active-play time is retained; stoppages earn a bounded extra period.
	if game.state in ["restart","set_piece","goal"] and added[half_index]<0:
		lost_time[half_index]+=delta*0.08
	if game.state=="playing" and game.match_time>=game.LENGTH*game.half*0.5-10 and added[half_index]<0:
		added[half_index]=clampf(ceilf(lost_time[half_index]/2.6667)*2.6667,0,16)
		if added[half_index]>0: game.announce("HAKEM · EN AZ +%d DAKİKA" % roundi(added[half_index]*90/game.LENGTH))

func half_end() -> float:
	return game.LENGTH*game.half*0.5+maxf(0,added[game.half-1])
