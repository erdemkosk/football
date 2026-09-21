extends RefCounted
## The interval keeps score, discipline and player identity across the end change.
var game
var age := 0.0
const DURATION := 20.0

func reset() -> void:
	if game.half==2:
		for p in game.players: p.home*=Vector3(-1,1,-1)
	game.half=1
	age=0

func begin() -> void:
	age=0
	game.match_time=game.LENGTH*0.5
	game.state="halftime"
	game.management.prepare_substitutions()
	game.charging=false
	game.charge=0
	game.cancel_pass()
	game.clear_pass_request()
	game.support.reset()
	game.duels.reset()
	game.goalkeeping.reset()
	game.set_pieces.clear()
	game.rules.reset()
	game.dribbler=-1
	game.carrier=-1
	game.ball.active=false
	game.referees.clear_decision()
	game.referees.decision="DEVRE"
	game.referees.decision_age=0
	game.referees.whistle()
	game.rules.show_deferred_cards()
	for p in game.players:
		p.desired=Vector3.ZERO
		p.sprinting=false
		p.shot_preparation=0
		p.chosen=false
	game.announce("DEVRE ARASI · TAKIMLAR DİNLENİYOR")

func update(delta: float) -> void:
	age+=delta
	for p in game.players:
		if not p.visible: continue
		var slot := Vector3(33.5+(p.number%2)*1.0,0,(-12 if p.team==0 else 12)+(p.number-6)*1.1)
		var destination: Vector3=game.set_pieces.recovery.around_goal(p.position,slot)
		var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
		p.desired=offset.normalized()*minf(0.55,offset.length())
		p.stamina_free_movement=true
		p.step(delta)
		p.stamina_free_movement=false
	if age>=DURATION: finish()

func finish() -> void:
	if game.state!="halftime": return
	game.half=2
	game.replay.frames.clear()
	game.stadium.crowd.home_attack=game.attack_sign(0)
	for p in game.players:
		p.home*=Vector3(-1,1,-1)
		# Fixed recovery also applies when the user skips the interval.
		p.energy=minf(1,p.energy+0.20)
		p.recovery_delay=0
		if p.energy>=p.RECOVERY_LIMIT: p.exhausted=false
		p.ai_think=0
	game.last_direction=Vector3(0,0,game.attack_sign(0))
	game.begin_restart("SANTRA",1,Vector3.ZERO)
	game.announce("İKİNCİ YARI · HÜCUM YÖNÜ ↓ · RAKİP SANTRASI")
