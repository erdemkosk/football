extends RefCounted
## Roster slots remain stable for physics and AI; shirt identity is independent.
var game
var formation := 0
var mentality := 1
var pressing := 1
var line_height := 1
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
	for p in game.players: originals.append({"name":p.display_name,"shirt":p.number})
	reset()

func reset() -> void:
	bench=[[],[]]
	used=[0,0]
	pending.clear()
	transit.clear()
	lost_time=[0.0,0.0]
	added=[-1.0,-1.0]
	for team in range(2):
		for j in range(7):
			bench[team].append({"name":(["EFE","UMUT","TUNA","OZAN","BARAN","YİĞİT","ATA"] if team==0 else ["JOEL","MIRO","NOAH","LARS","LUIS","ADAM","FINN"])[j],"shirt":12+j,"keeper":j==0,"used":false})
	for side in range(2):
		if not reserve_originals[side].is_empty(): bench[side]=reserve_originals[side].duplicate(true)
	for i in range(originals.size()):
		var p=game.players[i]
		p.display_name=originals[i].name
		p.shirt_number=originals[i].shirt
		p.shirt_label.text=str(p.shirt_number)
	apply_formation()

func apply_formation() -> void:
	for p in game.players:
		var shape: Array=SHAPES[formation if p.team==0 else 0]
		var pos: Vector2=shape[p.number-1]
		p.home=Vector3(pos.x,0,pos.y)*(-game.attack_sign(p.team))

func queue_sub(slot: int,reserve: int) -> String:
	if game.training or game.state in ["menu","finished"]: return "Oyuncu değişikliği maç sırasında yapılır."
	if slot<0 or slot>=game.players.size() or reserve<0 or reserve>=7: return "Geçersiz seçim."
	var p=game.players[slot]
	var b: Dictionary=bench[p.team][reserve]
	if transit.has(slot): return "Bu oyuncunun değişikliği devam ediyor."
	if p.dismissed or b.used or p.keeper!=b.keeper: return "Uygun yedek seç: kaleci kaleciyle değişir; ihraç edilen değiştirilemez."
	var count: int=used[p.team]
	for index in transit:
		if game.players[index].team==p.team:
			if transit[index].reserve==reserve: return "Bu yedek sahaya giriyor."
			if transit[index].phase=="out": count+=1
	for item in pending:
		if game.players[item.slot].team==p.team: count+=1
		if item.slot==slot or (item.reserve==reserve and game.players[item.slot].team==p.team): return "Bu oyuncu için değişiklik zaten bekliyor."
	if count>=5: return "Beş oyuncu değişikliği hakkı doldu."
	pending.append({"slot":slot,"reserve":reserve})
	return "%s → %s · Bir sonraki duraklamada" % [p.display_name,b.name]

func prepare_substitutions() -> void:
	if game.training: return
	# The opponent also refreshes tired players at a stoppage.
	if game.match_time>75 and used[1]<5 and pending.is_empty():
		var tired := -1
		var lowest := 0.32
		for i in range(12,22):
			if not game.players[i].dismissed and game.players[i].energy<lowest:
				lowest=game.players[i].energy; tired=i
		if tired>=0:
			for j in range(1,7):
				if not bench[1][j].used: queue_sub(tired,j); break
	for item in pending:
		var p=game.players[item.slot]
		if p.dismissed: continue
		transit[item.slot]={"reserve":item.reserve,"phase":"out","target":p.position,"old":p.display_name}
	pending.clear()

func update_substitutions(delta: float) -> bool:
	if transit.is_empty(): return false
	for p in game.players:
		p.desired=Vector3.ZERO
		p.sprinting=false
	for index in transit.keys():
		var item: Dictionary=transit[index]
		var p=game.players[index]
		var gate := Vector3(32.8,0,(-3 if p.team==0 else 3)+(index%11)*1.2)
		var destination: Vector3=gate if item.phase=="out" else item.target
		destination=game.set_pieces.recovery.around_goal(p.position,destination)
		var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
		var distance_to_destination := offset.length()
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
		if distance_to_destination<0.7:
			item.erase("waypoint")
			if item.phase=="out":
				var b: Dictionary=bench[p.team][item.reserve]
				b.used=true
				used[p.team]+=1
				p.display_name=b.name
				p.shirt_number=b.shirt
				p.shirt_label.text=str(p.shirt_number)
				p.reset_stamina()
				p.yellow_cards=0
				p.fouls_committed=0
				p.action_timer=0
				p.pose="run"
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
	target.x=clampf(target.x,-29,29)
	target.z=clampf(target.z,-45,45)
	return target

func update_clock(delta: float) -> void:
	if game.training: return
	var half_index: int=game.half-1
	# Active-play time is retained; stoppages earn a bounded extra period.
	if game.state in ["restart","set_piece","goal"] and added[half_index]<0:
		lost_time[half_index]+=delta*0.08
	if game.state=="playing" and game.match_time>=game.LENGTH*game.half*0.5-10 and added[half_index]<0:
		added[half_index]=clampf(ceilf(lost_time[half_index]/2.6667)*2.6667,0,16)
		if added[half_index]>0: game.announce("HAKEM · EN AZ +%d DAKİKA" % roundi(added[half_index]*90/game.LENGTH))

func half_end() -> float:
	return game.LENGTH*game.half*0.5+maxf(0,added[game.half-1])
