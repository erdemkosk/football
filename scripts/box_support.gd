extends RefCounted
## Three complementary destinations follow the delivery, not shirt numbers.
var jobs: Dictionary = {}
var points: Dictionary = {}
var team := -1
var side := 0.0

func reset() -> void:
	jobs.clear(); points.clear(); team=-1; side=0

func available(game,index: int,owner: int,support) -> bool:
	var p=game.players[index]
	if not p.visible or p.dismissed or p.keeper or p.team!=team or index==owner: return false
	if game.is_user_player(index) or p.action_timer>0: return false
	if game.ai_receivers[team]==index and game.ai_pass_time[team]>0: return false
	return game.management.slot_role(index)>=2 and support.roles.get(index,"") in ["box","support","commit","counter_run"]

func update(game,owner: int,possession: int,support) -> void:
	var ball: Vector3=game.ball.position
	var forward: float=game.attack_sign(possession)
	if owner<0 and team==possession and game.ai_pass_time[team]>0:
		# Once the cross leaves the wing, the other runners finish their jobs.
		# The chosen receiver and manually controlled player keep their own
		# interception/input path; the support planner cannot pull them away.
		for role in jobs:
			var index: int=jobs[role]
			if available(game,index,owner,support):
				support.targets[index]=points[role]
				support.roles[index]="box_"+role
		return
	if owner<0 or absf(ball.x)<16 or ball.z*forward<27:
		reset(); return
	var wing := signf(ball.x)
	if team!=possession or side!=wing:
		reset(); team=possession; side=wing
	var carrier=game.players[owner]
	# A forward-moving carrier invites runs beyond the defence. When the
	# carrier brakes or reaches the byline, keep a distinct backward outlet.
	var depth := clampf(ball.z*forward+6+carrier.velocity.z*forward*.35,36,46)
	var anchors := {
		"cutback":Vector3(clampf(ball.x*.24,-8,8),0,forward*clampf(ball.z*forward-6,27,38)),
		"near":Vector3(side*3.5,0,forward*depth),
		"far":Vector3(-side*5.5,0,forward*(depth-1.8))
	}
	var assigned: Array[int]=[]
	var occupied: Array[Vector3]=[]
	var spaces: Dictionary={}
	var line: float=maxf(0,game.rules.offside_line(team)-.8)
	for role in ["cutback","near","far"]:
		var best := -INF
		var chosen := -1
		var destination: Vector3=anchors[role]
		for i in range(game.players.size()):
			if i in assigned or not available(game,i,owner,support): continue
			var p=game.players[i]
			for shift in [-1.8,0.0,1.8]:
				var point: Vector3=anchors[role]+Vector3(shift,0,0)
				point.z=forward*minf(point.z*forward,line)
				var crowded := false
				for other in occupied:
					if game.flat_distance(point,other)<4: crowded=true
				if crowded: continue
				var travel: float=game.flat_distance(p.position,point)
				if travel>28: continue
				if not spaces.has(point): spaces[point]=minf(5,game.ai_attack.clearance(point,team))
				var space: float=spaces[point]
				var score := space*.8-travel*.22-absf(shift)*.18
				var midfield: bool=game.management.slot_role(i)==2
				score+=3.0 if midfield==(role=="cutback") else 0.0
				# Hysteresis keeps two runners from swapping jobs every frame.
				if jobs.get(role,-1)==i: score+=2.5
				if score>best: best=score; chosen=i; destination=point
		if chosen>=0:
			jobs[role]=chosen; assigned.append(chosen); occupied.append(destination)
			points[role]=destination
			support.targets[chosen]=destination
			support.roles[chosen]="box_"+role
		else: jobs.erase(role); points.erase(role)
