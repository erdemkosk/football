extends RefCounted
## A marked channel runner checks toward the ball, then attacks the space.
## These are movement targets only: defenders decide whether to follow them.
var game
var active: Dictionary={}
var cooldown := [0.0,0.0]

func reset() -> void:
	active.clear(); cooldown=[0.0,0.0]

func available(index: int,owner: int,support) -> bool:
	if index<0 or index==owner: return false
	var p=game.players[index]
	if not p.visible or p.dismissed or p.keeper or p.action_timer>0 or p.energy<.3 or game.is_user_player(index): return false
	if support.runs.has(index) or (game.ai_receivers[p.team]==index and game.ai_pass_time[p.team]>0): return false
	var order: Dictionary=game.management.instruction(index)
	if not order.is_empty() and int(order.get("attack",1))==0: return false
	return support.roles.get(index,"") in ["channel_run","short_outlet","link_outlet","wide_outlet"]

func marker(index: int) -> int:
	var p=game.players[index]
	var forward: float=game.attack_sign(p.team)
	var best := 4.2
	var found := -1
	for j in range(game.players.size()):
		var q=game.players[j]
		if not q.visible or q.dismissed or q.keeper or q.team==p.team or q.action_timer>0: continue
		if (q.position.z-p.position.z)*forward<-.4: continue
		var distance: float=game.flat_distance(q.position,p.position)
		if distance<best: best=distance; found=j
	return found

func begin(owner: int,team: int,support) -> void:
	if cooldown[team]>0 or game.dribbler!=owner or game.team_tactics.countering(team): return
	var forward: float=game.attack_sign(team)
	var carrier=game.players[owner]
	if carrier.receive_timer>0 or carrier.position.z*forward< -8 or carrier.position.z*forward>34: return
	var runner: int=support.shape.jobs.get("channel_run",-1)
	if not available(runner,owner,support): return
	var p=game.players[runner]
	var target: Vector3=support.targets[runner]
	if (target.z-p.position.z)*forward<3 or game.flat_distance(p.position,carrier.position)<6: return
	var defender := marker(runner)
	if defender<0: return
	var toward: Vector3=((carrier.position-p.position)*Vector3(1,0,1)).normalized()
	var feet: Vector3=p.position+toward*1.8
	var awareness: float=p.Attributes.skill(p,"positioning")
	active={"owner":owner,"team":team,"runner":runner,"marker":defender,"origin":p.position,"feet":feet,"target":target,"age":0.0,"phase":"check","check_time":lerpf(.58,.38,awareness),"decoy":-1}
	cooldown[team]=5.0
	# A second marked outlet can take its marker outward while the runner
	# attacks the channel. No defender is moved or assigned a forced response.
	for role in ["short_outlet","wide_outlet","link_outlet"]:
		var other: int=support.shape.jobs.get(role,-1)
		if not available(other,owner,support) or other==runner or marker(other)<0: continue
		var q=game.players[other]
		if game.flat_distance(q.position,p.position)>15: continue
		var side: float=signf(target.x-carrier.position.x)
		if side==0: side=1
		active.decoy=other
		active.decoy_target=q.position+Vector3(-side*3.5,0,-forward)
		break

func update(delta: float,owner: int,team: int,support) -> void:
	for i in range(2): cooldown[i]=maxf(0,cooldown[i]-delta)
	if game.training or game.state!="playing" or owner<0 or game.dribbler!=owner or game.ball.held_by!=null:
		active.clear(); return
	if not active.is_empty():
		if active.owner!=owner or active.team!=team or not available(active.runner,owner,support): active.clear()
	if active.is_empty(): begin(owner,team,support)
	if active.is_empty(): return
	active.age+=delta
	var runner=game.players[active.runner]
	if active.age>2.4 or game.flat_distance(runner.position,active.target)<.9:
		active.clear(); return
	if active.phase=="check" and (active.age>=active.check_time or game.flat_distance(runner.position,active.feet)<.4):
		active.phase="burst"
	var target: Vector3=active.feet if active.phase=="check" else active.target
	assign(support,active.runner,target,"check_run" if active.phase=="check" else "burst_run",team)
	if active.decoy>=0 and active.age<1.35 and available(active.decoy,owner,support):
		assign(support,active.decoy,active.decoy_target,"decoy_run",team)

func assign(support,index: int,target: Vector3,role: String,team: int) -> void:
	var forward: float=game.attack_sign(team)
	var line: float=maxf(0,game.rules.offside_line(team)-.9)
	target.x=clampf(target.x,-game.P.HALF_WIDTH+3,game.P.HALF_WIDTH-3)
	target.z=forward*minf(clampf(target.z*forward,-43,46),line)
	support.targets[index]=target; support.roles[index]=role
