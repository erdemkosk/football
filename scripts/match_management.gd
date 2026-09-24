extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Roster slots remain stable for physics and AI; shirt identity is independent.
var game
var identity := preload("res://scripts/team_identity.gd").new()
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
## Six visible opponent levels over the three tuned AI tables. `difficulty`
## stays the 0..2 tier that the tables index; `pick` interpolates between them
## (and a little beyond Hard for Efsane) so every level is distinct.
const Settings = preload("res://scripts/match_settings.gd")
const LEVEL_SCALE := [0.0,.5,1.0,1.5,2.0,2.35]
var level := 2:
	set(value): level=clampi(value,0,Settings.LEVELS.size()-1)
var difficulty: int:
	get: return Settings.LEVEL_TIER[level]
	set(value): level=Settings.TIER_LEVEL[clampi(value,0,2)]
var manual_plan := false
## Individual instructions for the user's side, keyed by roster slot number:
## attack 0 hold / 1 balanced / 2 join the attack; width 0 inside / 1 / 2 wide.
var instructions: Dictionary = {}
const ATTACK_ORDERS := ["GERİDE KAL","DENGELİ","HÜCUMA KATIL"]
const WIDTH_ORDERS := ["İÇE KAT ET","DENGELİ","GENİŞ KAL"]
var bench: Array = [[],[]]
var used := [0,0]
var pending: Array = []
var originals: Array = []
var reserve_originals: Array = [[],[]]
var transit: Dictionary = {}
var lost_time := [0.0,0.0]
var added := [-1.0,-1.0]
const FORMATIONS := ["4-4-2","4-3-3","3-5-2","4-2-3-1","4-1-2-1-2","5-3-2","3-4-3","4-1-4-1","4-4-1-1"]
const SHAPES := [
	[Vector2(0,46),Vector2(-23,28),Vector2(-8,31),Vector2(8,31),Vector2(23,28),Vector2(-20,7),Vector2(-6,13),Vector2(9,10),Vector2(22,5),Vector2(-5,-1),Vector2(9,-7)],
	[Vector2(0,46),Vector2(-23,28),Vector2(-8,31),Vector2(8,31),Vector2(23,28),Vector2(-13,12),Vector2(0,18),Vector2(13,12),Vector2(-23,-5),Vector2(0,-10),Vector2(23,-5)],
	[Vector2(0,46),Vector2(-16,31),Vector2(0,33),Vector2(16,31),Vector2(-26,9),Vector2(-12,13),Vector2(0,20),Vector2(12,13),Vector2(26,9),Vector2(-7,-7),Vector2(7,-7)],
	[Vector2(0,46),Vector2(-23,28),Vector2(-8,31),Vector2(8,31),Vector2(23,28),Vector2(-7,18),Vector2(7,18),Vector2(-20,3),Vector2(0,4),Vector2(20,3),Vector2(0,-9)],
	[Vector2(0,46),Vector2(-22,28),Vector2(-8,31),Vector2(8,31),Vector2(22,28),Vector2(0,19),Vector2(-11,11),Vector2(11,11),Vector2(0,3),Vector2(-6,-8),Vector2(6,-8)],
	[Vector2(0,46),Vector2(-26,24),Vector2(-12,32),Vector2(0,34),Vector2(12,32),Vector2(26,24),Vector2(-11,13),Vector2(0,17),Vector2(11,13),Vector2(-7,-7),Vector2(7,-7)],
	[Vector2(0,46),Vector2(-15,31),Vector2(0,33),Vector2(15,31),Vector2(-25,10),Vector2(-8,15),Vector2(8,15),Vector2(25,10),Vector2(-20,-5),Vector2(0,-10),Vector2(20,-5)],
	[Vector2(0,46),Vector2(-23,28),Vector2(-8,31),Vector2(8,31),Vector2(23,28),Vector2(0,19),Vector2(-22,6),Vector2(-8,10),Vector2(8,10),Vector2(22,6),Vector2(0,-9)],
	[Vector2(0,46),Vector2(-23,28),Vector2(-8,31),Vector2(8,31),Vector2(23,28),Vector2(-21,7),Vector2(-7,13),Vector2(7,13),Vector2(21,7),Vector2(0,1),Vector2(0,-8)]]
## Defenders, midfielders and forwards per formation, in slot order.
const LINE_COUNTS := [[4,4,2],[4,3,3],[3,5,2],[4,5,1],[4,4,2],[5,3,2],[3,4,3],[4,5,1],[4,4,2]]
## Shirt numbers of the wide players who overlap as full backs or wing backs.
const WIDE_BACKS := [[2,5],[2,5],[5,9],[2,5],[2,5],[2,6],[5,8],[2,5],[2,5]]

static func lines(shape: int) -> Array:
	var counts: Array=LINE_COUNTS[clampi(shape,0,LINE_COUNTS.size()-1)]
	var result: Array=[[0],[],[],[]]
	var slot := 1
	for group in range(3):
		for n in range(int(counts[group])):
			result[group+1].append(slot); slot+=1
	return result

func setup() -> void:
	identity.game=game
	var plan: Dictionary=game.clubs.tactical_plan(0)
	for key in identity.SETTINGS: set(key,bool(plan[key]) if key=="anchor" else int(plan[key]))
	for p in game.players: originals.append(p.identity())
	reset()

func reset() -> void:
	manual_plan=false
	opponent_formation=int(game.clubs.tactical_plan(1).formation)
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
		p.number=i%11+1
		p.apply_identity(originals[i])
		p.apply_kit(game.clubs.kit(p.team))
	apply_formation()
	refresh_captains(true)

func apply_formation() -> void:
	for p in game.players:
		var shape: Array=SHAPES[formation if p.team==0 else opponent_formation]
		var pos: Vector2=shape[p.number-1]
		p.home=Vector3(pos.x*P.WIDTH_RATIO,0,pos.y)*(-game.attack_sign(p.team))
		p.home.x*=[.78,1.0,1.14][detail(p.team,"width")]

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
	var slot: int=p.number-1
	var shape: int=formation if p.team==0 else opponent_formation
	var counts: Array=LINE_COUNTS[clampi(shape,0,LINE_COUNTS.size()-1)]
	if slot<=int(counts[0]): return 1
	if slot>=11-int(counts[2]): return 3
	return 2

func actor_at_slot(slot: int,team: int=0) -> int:
	for i in range(team*11,team*11+11):
		if game.players[i].number==slot+1: return i
	return -1

func wide_defender(index: int) -> bool:
	var p=game.players[index]
	var shape: int=formation if p.team==0 else opponent_formation
	return p.number in WIDE_BACKS[clampi(shape,0,WIDE_BACKS.size()-1)]

func position_swap_reason(a: int,b: int) -> String:
	if a<0 or b<0 or a>=game.players.size() or b>=game.players.size() or a==b: return "İki farklı oyuncu seç."
	var first=game.players[a]
	var second=game.players[b]
	if first.team!=second.team: return "Aynı takımdan iki oyuncu seç."
	if first.keeper!=second.keeper: return "Kaleci yalnızca kaleciyle değiştirilebilir."
	if first.dismissed or second.dismissed: return "İhraç edilen oyuncunun yeri değiştirilemez."
	if transit.has(a) or transit.has(b): return "Devam eden oyuncu değişikliğini bekle."
	return ""

func swap_positions(a: int,b: int) -> bool:
	if position_swap_reason(a,b)!="": return false
	# Change tactical assignments, keeping actors and all ball/event references intact.
	var number: int=game.players[a].number
	game.players[a].number=game.players[b].number
	game.players[b].number=number
	apply_formation()
	refresh_captains()
	return true

func refresh_captains(new_match: bool=false) -> void:
	for team in range(2):
		var selected=-1
		for i in range(team*11,team*11+11):
			var p=game.players[i]
			if p.dismissed and not new_match: continue
			if selected<0 or p.captain: selected=i
			if p.captain: break
		for i in range(team*11,team*11+11): game.players[i].set_captain(i==selected)

func suggestion(team: int,threshold: float=0.40,excluded: Array=[]) -> Dictionary:
	if committed(team)>=MAX_SUBS or game.training: return {}
	var best: Dictionary={}
	var lowest := threshold
	for slot in range(team*11+1,team*11+11):
		var p=game.players[slot]
		if not p.visible or p.dismissed or p.readiness()>=lowest or p.shirt_number in excluded: continue
		for reserve in range(1,7):
			var b: Dictionary=bench[team][reserve]
			if int(b.get("role",natural_role(b.shirt,b.keeper)))!=slot_role(slot) or substitution_reason(slot,reserve)!="": continue
			if float(b.get("fitness",1.0))<=p.readiness()+.08: continue
			lowest=p.readiness()
			best={"slot":slot,"reserve":reserve,"shirt":p.shirt_number,"incoming":b.shirt}
			break
	return best

func live_plan(value: int) -> void:
	manual_plan=true
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
		var gate:=Vector3(P.HALF_WIDTH+.8,0,(-1 if p.team==0 else 1)*(1.6+reserved*1.4))
		transit[item.slot]={"reserve":item.reserve,"phase":"out","target":p.position,"old":p.display_name,"gate":gate}
		game.broadcast.substitution(p.identity(),bench[p.team][item.reserve],p.team)
		game.stadium.sidelines.start_entry(item.slot,item.reserve,gate)
	pending.clear()

func update_substitutions(delta: float) -> bool:
	if transit.is_empty(): return false
	for item in transit.values(): item.presentation_age=float(item.get("presentation_age",0))+delta
	if game.experience.short_presentation and transit.values().any(func(item): return item.presentation_age>2.5):
		game.pace.request(game.pace.substitutions_ready)
	for p in game.players:
		p.desired=Vector3.ZERO
		p.sprinting=false
	for index in transit.keys():
		var item: Dictionary=transit[index]
		var p=game.players[index]
		var gate: Vector3=item.gate
		var destination: Vector3=gate if item.phase=="out" else item.target
		destination=game.set_pieces.recovery.around_goal(p.position,destination)
		var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
		var distance_to_destination := offset.length()
		var greeted: bool=game.stadium.sidelines.step_entry(index,p,delta) if item.phase=="out" else true
		if item.has("waypoint") and game.flat_distance(p.position,item.waypoint)<0.4: item.erase("waypoint")
		if not item.has("waypoint") and offset.length()>0.8:
			var ahead := offset.normalized()
			for other in game.players:
				if other==p or not other.visible or not other.rig.visible: continue
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
				game.stadium.sidelines.retain_departing(p,index)
				game.match_report.substitution(p,b)
				game.broadcast_event("substitution",{"out":p.display_name.capitalize(),"incoming":String(b.name).capitalize(),"team":p.team})
				p.apply_identity(b)
				p.apply_kit(game.clubs.kit(p.team))
				refresh_captains()
				p.reset_stamina()
				game.career.enter_player(p)
				p.yellow_cards=0
				p.fouls_committed=0
				p.action_timer=0
				p.pose="run"
				p.celebration=""
				p.kick_timer=0; p.receive_timer=0; p.shot_preparation=0; p.shot_ready_blend=0
				p.set_piece_pose=""; p.discipline_pose=""; p.saluting=false
				p.skill_move.clear(); p.feint_time=0; p.dummy_time=0
				p.tackle_cooldown=0; p.tackle_recovery=0
				p.dribble_motion.reset(); p.locomotion.reset(); p.reaction.reset()
				# Keep the last greeting pose as the visual blend's origin while the
				# replacement's own running cycle begins on the next physics tick.
				p.body_language.reset(p)
				game.stadium.sidelines.finish_entry(index,p)
				item.phase="in"
			else: transit.erase(index)
	for index in range(game.players.size()):
		var p=game.players[index]
		if not p.visible: continue
		p.stamina_free_movement=true
		var changing: bool=transit.has(index)
		var was_prematch: bool=p.prematch
		if changing: p.prematch=true
		p.step(delta,9.2 if changing else 0.0)
		p.prematch=was_prematch
		p.stamina_free_movement=false
	return true

func pick(values: Array,low: float=-INF,high: float=INF) -> float:
	# values = [easy, normal, hard] at scale 0, 1 and 2.
	var s: float=LEVEL_SCALE[level]
	var result: float=lerpf(float(values[0]),float(values[1]),s) if s<=1.0 else float(values[1])+(float(values[2])-float(values[1]))*(s-1.0)
	return clampf(result,low,high)

func reaction(team: int,index: int=-1,defense: bool=false) -> float:
	var ability: float=identity.quality(index,defense) if index>=0 else identity.team_quality(team,defense)
	return (pick([1.7,1.05,0.58],.34) if team==1 else 1.05)*lerpf(1.30,.72,ability)

func pass_error(team: int,index: int=-1,_shot: bool=false) -> float:
	# Difficulty handicap only: technique, body and pressure errors come from
	# the shared contact model that both teams use (strike_quality.gd).
	var base: float=pick([0.045,0.012,0.0],0.0) if team==1 else 0.004
	if index<0: return base
	return base*(1+(1-game.players[index].energy)*.3)

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
		if gap<pick([4.0,6.5,10.0],3.0,12.0): target=target.lerp(game.ball.position,pick([0.12,0.28,0.48],.08,.56))
	elif p.team==1 and game.carrier>=0 and game.players[game.carrier].team==1:
		# Late chasing teams commit runners; a leading team keeps more cover.
		target.z+=forward*(game.team_tactics.plan_for(1)-1)*(4 if slot_role(index)==1 else 6)
	target.x=clampf(target.x,-(P.HALF_WIDTH-3),(P.HALF_WIDTH-3))
	target.z=clampf(target.z,-45,45)
	return target

func instruction(index: int) -> Dictionary:
	var p=game.players[index]
	if p.team!=0 or p.keeper or game.menu_match.running: return {}
	return instructions.get(p.number,{})

func cycle_instruction(slot_number: int,key: String) -> Dictionary:
	var order: Dictionary=instructions.get(slot_number,{"attack":1,"width":1}).duplicate()
	order[key]=(int(order.get(key,1))+1)%3
	if int(order.attack)==1 and int(order.width)==1: instructions.erase(slot_number)
	else: instructions[slot_number]=order
	# A career keeps its instructions in the club's plan.
	if game.career.in_match:
		game.career.club().plan.instructions=instructions.duplicate(true)
		game.career.save()
	return order

func detail(team: int,key: String) -> int:
	var value: int=int(get(key)) if team==0 else identity.setting(game.clubs.data(team),key)
	# The run-frequency slider moves the attacking-run instruction one step at
	# its extremes; the underlying support logic stays the same.
	if key=="runs": value=clampi(value+roundi(game.sliders.offset(team,"runs",1.0)),0,2)
	return value

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
		var minute: float=game.LENGTH/90.0
		added[half_index]=clampf(ceilf(lost_time[half_index]/minute)*minute,0,minute*6)

func half_end() -> float:
	return game.LENGTH*game.half*0.5+maxf(0,added[game.half-1])
