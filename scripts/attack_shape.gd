extends RefCounted
## Complementary off-ball jobs, refreshed at a bounded rate. Jobs persist long
## enough to finish a movement; the normal locomotion/stamina systems execute it.
var game
var team := -1
var refresh := 0.0
var hold := 0.0
var jobs: Dictionary = {}
var points: Dictionary = {}
const ROLES := ["short_outlet","channel_run","wide_outlet"]

func reset() -> void:
	team=-1; refresh=0; hold=0; jobs.clear(); points.clear()

func eligible(index: int,owner: int,support) -> bool:
	var p=game.players[index]
	if not p.visible or p.dismissed or p.keeper or p.team!=team or index==owner: return false
	if game.ai_receivers[team]==index and game.ai_pass_time[team]>0: return false
	if index==game.controlled and not game.menu_match.running: return false
	# Preserve explicit runs, overlapping fullbacks, box runs and the cover pair.
	if support.roles.get(index,"")!="support": return false
	return game.management.slot_role(index)>=2

func update(delta: float,owner: int,possession: int,support) -> void:
	if game.state!="playing" or owner<0 and game.ai_pass_time[possession]<=0:
		reset(); return
	if team!=possession:
		reset(); team=possession
	refresh-=delta; hold-=delta
	for role in jobs.keys():
		if not eligible(jobs[role],owner,support):
			jobs.erase(role); points.erase(role); refresh=0
	if refresh<=0:
		refresh=.24
		if hold<=0:
			jobs.clear(); hold=2.4
		plan(owner,support)
	var forward: float=game.attack_sign(team)
	var line: float=maxf(0,game.rules.offside_line(team)-.9)
	for role in jobs:
		var target: Vector3=points[role]
		# Recheck the live line between planning ticks so a moving back line
		# cannot make a held job keep running offside.
		target.z=forward*minf(target.z*forward,line)
		support.targets[jobs[role]]=target
		support.roles[jobs[role]]=role

func plan(owner: int,support) -> void:
	var ball: Vector3=game.players[owner].position if owner>=0 else game.ball.position
	ball.y=0
	var forward: float=game.attack_sign(team)
	var width: float=[.84,1.0,1.12][game.management.detail(team,"width")]
	var depth: float=11+(game.management.detail(team,"runs")-1)*3
	var open_side := 1.0
	if game.ai_attack.clearance(ball+Vector3(-9,0,forward*depth),team)>game.ai_attack.clearance(ball+Vector3(9,0,forward*depth),team): open_side=-1
	# Keep a run in its chosen channel while the job is held.
	if points.has("channel_run") and jobs.has("channel_run"):
		open_side=signf(points.channel_run.x-ball.x)
		if open_side==0: open_side=1
	var anchors := {
		"short_outlet":ball+Vector3(-open_side*7,0,-forward*5),
		"channel_run":ball+Vector3(open_side*8*width,0,forward*depth),
		"wide_outlet":Vector3(-open_side*25*width,0,ball.z+forward*3)
	}
	var reserved: Array[Vector3]=[]
	for index in support.targets:
		if support.roles[index] in ["one_two","give_go","overlap","box"]: reserved.append(support.targets[index])
	for role in ROLES:
		var best := -INF
		var chosen := -1
		var destination := Vector3.ZERO
		for i in range(game.players.size()):
			if not eligible(i,owner,support): continue
			if jobs.has(role) and jobs[role]!=i: continue
			if i in jobs.values() and jobs.get(role,-1)!=i: continue
			var p=game.players[i]
			for offset in [Vector3.ZERO,Vector3(-3,0,0),Vector3(3,0,0),Vector3(0,0,-forward*3)]:
				var at: Vector3=anchors[role]+offset
				at.x=clampf(at.x,-29,29)
				at.z=forward*minf(clampf(at.z*forward,-42,44),maxf(0,game.rules.offside_line(team)-.9))
				var overlaps := false
				for occupied in reserved:
					if game.flat_distance(at,occupied)<4: overlaps=true; break
				if overlaps: continue
				var travel: float=game.flat_distance(p.position,at)
				if travel>24: continue
				var lane := 5.0
				for opponent in game.players:
					if not opponent.visible or opponent.dismissed or opponent.team==team: continue
					var near := Geometry3D.get_closest_point_to_segment(opponent.position*Vector3(1,0,1),ball,at)
					lane=minf(lane,game.flat_distance(near,opponent.position))
				var score: float=minf(8,game.ai_attack.clearance(at,team))*1.1+lane*1.5-travel*.42-offset.length()*.25
				var group: int=game.management.slot_role(i)
				if role=="short_outlet": score+=3 if group==2 else 0
				elif role=="channel_run": score+=(3 if group==3 else 0)-(1-p.energy)*7
				else: score+=minf(3,absf(p.home.x)*.14)
				if score>best: best=score; chosen=i; destination=at
		if chosen>=0:
			jobs[role]=chosen; points[role]=destination; reserved.append(destination)
		else:
			jobs.erase(role); points.erase(role)
