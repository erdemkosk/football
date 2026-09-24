extends SceneTree
## Contact-quality model: exact clean passes, power/accuracy trade-off,
## technique, weak foot, pressure, determinism, skill stars and play styles.
const Attributes = preload("res://scripts/player_attributes.gd")
const ShotGuide = preload("res://scripts/shot_guide.gd")
var game
var p
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func profile(rating: int,weak_foot: int=3) -> Dictionary:
	var a := {"preferred_foot":1,"weak_foot":weak_foot,"archetype":"TEST"}
	for key in ["pace","acceleration","control","balance","heading","finishing","passing","defending","strength","stamina","reflexes","handling","positioning"]: a[key]=rating
	return a

func place(distance: float,lateral: float,rating: int,weak_foot: int=3,strong: bool=true) -> Vector3:
	var forward: float=game.attack_sign(p.team)
	p.attributes=profile(rating,weak_foot)
	p.appearance_id=900+rating
	p.position=Vector3(lateral,0,forward*(50-distance)); p.velocity=Vector3.ZERO
	p.facing=Vector3(0,0,forward); p.rig.rotation=Vector3(0,atan2(-p.facing.x,-p.facing.z),0)
	p.energy=1; p.match_fatigue=0; p.contest_weight=0; p.active_sprint=false
	# Off the body's centre line, so the foot choice is unambiguous.
	var spot: Vector3=p.position+p.facing*.55+p.facing.cross(Vector3.UP)*.24+Vector3.UP*game.ball.GROUND_HEIGHT
	game.ball.place(spot); game.ball.position=spot
	game.ball.linear_velocity=Vector3.ZERO
	game.dribbler=9; game.carrier=9
	var foot: int=p.ball_actions.choose_foot(p,game.ball.position)
	p.attributes.preferred_foot=foot if strong else 1-foot
	Attributes.refresh(p)
	return ((Vector3(0,0,forward*50)-p.position)*Vector3(1,0,1)).normalized()

func shot(distance: float,lateral: float,rating: int,power: float,kind: String="shot",weak_foot: int=3,strong: bool=true) -> Dictionary:
	var aim := place(distance,lateral,rating,weak_foot,strong)
	var velocity: Vector3=game.shot_velocity(aim,power,false,false,9)
	return game.strike_quality.assess(9,velocity,kind,power)

func crossing_height(outcome: Dictionary) -> float:
	var route: Dictionary=ShotGuide.predict(game.ball.position,outcome.velocity,0,game.attack_sign(p.team)*50,game.weather)
	return float(route.target.y) if route.get("goal_plane",false) else -1.0

func mean_yaw(distance: float,rating: int,power: float,weak_foot: int=3,strong: bool=true) -> float:
	var total := 0.0
	for i in range(24): total+=absf(float(shot(distance+(i%3)*.4,-5.5+i*.47,rating,power,"shot",weak_foot,strong).yaw))
	return total/24.0

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-strike-quality.cfg"
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false); game.hud.hide()
	p=game.players[9]
	for i in range(game.players.size()):
		var q=game.players[i]
		q.visible=i==9
		if i!=9: q.position=Vector3(30,0,0)
	# Clean, unpressured ordinary passes stay exact.
	var aim := place(20,0,72)
	var pass_velocity: Vector3=aim*14+Vector3.UP*.14
	var clean: Dictionary=game.strike_quality.assess(9,pass_velocity,"kick")
	check(clean.velocity.is_equal_approx(pass_velocity) and clean.yaw==0.0,"An unpressured short pass leaves exactly as intended")
	# A pass made under pressure while sprinting across the body can drift.
	var marker=game.players[12]; marker.visible=true; marker.position=p.position+Vector3(.9,0,0)
	p.velocity=Vector3(6.5,0,0); p.active_sprint=true
	var hurried: Dictionary=game.strike_quality.assess(9,aim*14+Vector3.UP*.14,"kick")
	check(hurried.limit>deg_to_rad(1.5),"A hurried pass across a sprint under pressure has a real error cone")
	marker.visible=false; marker.position=Vector3(30,0,0); p.velocity=Vector3.ZERO; p.active_sprint=false
	# The preview arrow is the intended strike; the contact adds the error.
	aim=place(18,2,72)
	var intended: Vector3=game.shot_velocity(aim,.6,false,false,9)
	check(((intended*Vector3(1,0,1)).normalized()).dot(aim)>.99999,"The shot preview follows the chosen aim exactly")
	var first: Dictionary=game.strike_quality.assess(9,intended,"shot",.6)
	var second: Dictionary=game.strike_quality.assess(9,intended,"shot",.6)
	check(first.velocity==second.velocity and first.yaw!=0.0,"The same contact reproduces the same launch error")
	# Power trades accuracy: full power from 25 m clears the bar, 80% does not.
	var over := 0
	var under := 0
	for i in range(12):
		if crossing_height(shot(25+(i%3)*.5,-4+i*.7,72,1.0))>2.44: over+=1
		var controlled_height: float=crossing_height(shot(25+(i%3)*.5,-4+i*.7,72,.8))
		if controlled_height>0 and controlled_height<2.3: under+=1
	check(over>=9,"An average finisher's full-power strike from 25 m usually clears the bar: %d/12" % over)
	check(under>=11,"An 80%% strike from 25 m stays under the bar: %d/12" % under)
	check(game.strike_quality.overhit_risk(1.0,25)>.9 and game.strike_quality.overhit_risk(.6,25)==0.0 and game.strike_quality.overhit_risk(1.0,6)==0.0,"The meter warns about over-hitting only from range")
	# Technique, weak foot and pressure all widen the cone.
	var elite := mean_yaw(18,92,.6)
	var poor := mean_yaw(18,50,.6)
	check(poor>elite*2.0,"A poor finisher sprays the ball more than an elite one: %.2f vs %.2f deg" % [rad_to_deg(poor),rad_to_deg(elite)])
	var weak := mean_yaw(18,72,.6,1,false)
	var strong := mean_yaw(18,72,.6,1,true)
	check(weak>strong*1.4,"A one-star weak foot is clearly less accurate: %.2f vs %.2f deg" % [rad_to_deg(weak),rad_to_deg(strong)])
	aim=place(16,1,72)
	var free: Dictionary=game.strike_quality.assess(9,game.shot_velocity(aim,.6,false,false,9),"shot",.6)
	marker.visible=true; marker.position=p.position+Vector3(.8,0,0)
	var pressed: Dictionary=game.strike_quality.assess(9,game.shot_velocity(aim,.6,false,false,9),"shot",.6)
	check(pressed.limit>free.limit*1.3,"Close pressure widens the shooting cone")
	p.attributes.composure=95; Attributes.refresh(p)
	var composed: Dictionary=game.strike_quality.assess(9,game.shot_velocity(aim,.6,false,false,9),"shot",.6)
	check(composed.limit<pressed.limit,"Composure resists the same pressure")
	marker.visible=false; marker.position=Vector3(30,0,0)
	# A header is harder to place than a ground shot of equal technique.
	aim=place(10,0,72)
	var ground: Dictionary=game.strike_quality.assess(9,aim*18+Vector3.UP*1.5,"shot",.6)
	game.dribbler=-1
	var header: Dictionary=game.strike_quality.assess(9,aim*14+Vector3.UP*1.0,"header",.6)
	check(header.limit>ground.limit,"Headers carry a wider cone than ground shots")
	# The AI no longer adds hidden technique noise on the hardest level.
	game.management.difficulty=2
	check(game.management.pass_error(1)==0.0 and game.management.pass_error(1,9)==0.0,"Hard AI aim adds no extra handicap; the shared contact model decides")
	game.management.difficulty=1
	# Skill stars gate the moves for both teams.
	p.attributes=profile(72); p.attributes.skill_moves=3; Attributes.refresh(p)
	check(Attributes.can_perform(p,"roulette") and not Attributes.can_perform(p,"elastico") and Attributes.can_perform(p,"roll"),"Three skill stars allow the roulette but not the elastico")
	p.attributes.skill_moves=5
	check(Attributes.can_perform(p,"rainbow"),"Five skill stars unlock every move")
	# Derived techniques, styles and separate strength.
	var elite_profile := profile(92)
	var details := Attributes.details_for(elite_profile,77)
	check(details.vision>=85 and details.long_shots>=85 and details.tackling>=85,"Derived techniques follow the core ratings")
	check(Attributes.styles_for(elite_profile,77).size()>0 and Attributes.styles_for(profile(60),77).is_empty(),"Play styles belong to genuine specialists only")
	check(Attributes.styles_for(elite_profile,77).size()<=Attributes.MAX_STYLES,"A player carries at most four play styles")
	var striker := Attributes.club_profile(0,9)
	var winger := Attributes.club_profile(0,5)
	check(striker.strength>winger.strength and striker.strength!=striker.balance,"Exhibition squads separate strength from balance")
	check(Attributes.stars_for(Attributes.club_profile(0,6),6)>=Attributes.stars_for(Attributes.club_profile(0,2),2),"A playmaker has at least the skill stars of a centre back")
	print("STRIKE QUALITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
