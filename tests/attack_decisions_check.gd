extends "res://tests/ai_attack_check.gd"

func route_to(receiver: int) -> Dictionary:
 var q=game.players[receiver]
 return game.ai_attack.pass_choice("pass",game.Passing.plan(game.ball.position,q.position,q.velocity,false,game.weather),receiver)

func team_shape(half: int=1) -> void:
 setup(); game.half=half
 var f: float=game.attack_sign(1)
 player(0,Vector3(0,0,f*49)); player(2,Vector3(-27,0,f*48))
 player(16,Vector3(-7,0,-f*6)); player(17,Vector3(9,0,f*4))
 player(18,Vector3(-23,0,f*2)); player(21,Vector3(6,0,f*11))
 player(13,Vector3(-8,0,-f*20)); player(14,Vector3(8,0,-f*20))
 possession(20); game.support.update(.1)

func run() -> void:
 game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
 game.match_menu.config_path="/tmp/sefc-attack-decisions.cfg"
 setup(Vector3(0,0,33)); player(18,Vector3(-9,0,27)); game.support.passed(18,20,true)
 check(game.support.return_option(20)==18 and kind()=="shot","An available wall return cannot override a clear scoring chance")
 var options: Array[Dictionary]=game.ai_attack.options(20)
 options.reverse()
 check(game.ai_attack.decisions.select(20,options).kind=="shot","Reordering feasible candidates does not change the best decision")
 setup(Vector3(0,0,36)); player(18,Vector3(6,0,8)); player(0,Vector3(1,0,43))
 check(game.ai_attack.through_on_goal(20) and kind() in ["shot","low","chip"],"A one-on-one with the keeper is not recycled to a teammate behind")
 setup(Vector3(2,0,28)); player(18,Vector3(-5,0,10)); player(0,Vector3(0,0,42))
 check(kind() not in ["pass","return_pass","one_two","driven_pass"],"An isolated run at goal does not pass backwards")
 setup(); player(18,Vector3(-9,0,8)); player(4,Vector3(1.8,0,0))
 var kinds: Array=[]
 for option in game.ai_attack.options(20): kinds.append(option.kind)
 check("feint" in kinds and kind()=="pass","A safe forward escape beats an available pressure dribble")
 setup(); player(18,Vector3(10,0,-10)); game.ai_attack.skill_in[20]=2
 check(game.ai_attack.decide(20).is_empty(),"An unpressured carrier uses open grass instead of automatically passing backwards")
 player(4,Vector3(-1.8,0,0))
 check(kind()=="pass","The same backward outlet becomes useful when the carrier is pressed")
 setup(Vector3(20,0,4)); player(18,Vector3(-24,0,6)); player(4,Vector3(24,0,4))
 check(kind()=="switch","A free far wing remains a reachable switch option beyond ordinary pass range")
 setup(); player(18,Vector3(-10,0,12)); player(19,Vector3(0,0,15)); player(4,Vector3(0,0,7))
 var chosen: Dictionary=game.ai_attack.decide(20)
 check(chosen.get("receiver",-1)==18,"An unobstructed receiver beats the teammate behind a blocked passing lane")
 # Evaluate a real second passing lane rather than giving every back pass a bonus.
 setup(); player(18,Vector3(-10,0,-4)); player(19,Vector3(-10,0,12))
 game.ai_attack.decisions.game=game
 var origin: Vector3=game.players[18].position
 var open_value: float=game.ai_attack.decisions.continuation(20,18,origin,.8)
 player(4,Vector3(-10,0,4))
 var closed_value: float=game.ai_attack.decisions.continuation(20,18,origin,.8)
 check(open_value>4 and closed_value<open_value-3,"A layoff earns value only when its next forward lane is open")
 game.players[4].visible=false
 var route: Dictionary=route_to(18)
 game.management.difficulty=0
 var easy_value: float=game.ai_attack.decisions.value(20,route)
 game.management.difficulty=2
 check(game.ai_attack.decisions.value(20,route)>easy_value+4,"Hard difficulty considers the next pass without changing player physics")
 var unreachable: Dictionary=route.duplicate(true)
 unreachable.route.target=Vector3(-25,.23,18); unreachable.route.flight=.2
 check(game.ai_attack.decisions.value(20,unreachable)<game.ai_attack.decisions.value(20,route)-30,"An attractive destination is penalized when its receiver cannot get there")
 for half in [1,2]:
  team_shape(half)
  var shape=game.support.shape
  var f: float=game.attack_sign(1)
  check(shape.jobs.size()==3 and shape.jobs.values()[0]!=shape.jobs.values()[1] and shape.jobs.values()[1]!=shape.jobs.values()[2],"Short, deep and wide duties go to different players in half %d" % half)
  check(shape.points.short_outlet.z*f<0 and shape.points.channel_run.z*f>6 and absf(shape.points.wide_outlet.x)>20,"Off-ball jobs supply complementary receiving spaces in half %d" % half)
  var separated := true
  for a in shape.points:
   for b in shape.points:
    if a!=b and game.flat_distance(shape.points[a],shape.points[b])<4: separated=false
  check(separated,"Coordinated destinations keep separate passing lanes")
  check(game.support.roles[13]=="cover_attack" and game.support.roles[14]=="cover_attack","The cover pair stays behind the coordinated attack")
  var jobs: Dictionary=shape.jobs.duplicate()
  for tick in range(12): game.support.update(.1)
  check(shape.jobs==jobs,"Small planning ticks do not repeatedly swap runners' jobs")
  # Moving the defensive line is honoured immediately, inside the refresh interval.
  game.players[2].position.z=f*7
  game.support.update(.01)
  var onside := true
  for i in shape.jobs.values(): onside=onside and game.support.targets[i].z*f<=game.rules.offside_line(1)-.8
  check(onside,"A moving back line immediately caps held off-ball runs")
  var receiver: int=shape.jobs.short_outlet
  game.ai_receivers[1]=receiver; game.ai_pass_time[1]=2
  game.support.update(.01)
  check(receiver not in shape.jobs.values(),"A committed pass receiver is released from off-ball coordination")
  var runner: int=shape.jobs.get("channel_run",21)
  game.support.passed(runner,20,true); game.support.update(.01)
  check(game.support.roles[runner]=="one_two" and runner not in shape.jobs.values(),"Explicit one-two movement keeps priority over a shared role")
  player(4,Vector3.ZERO); possession(4); game.support.update(.01)
  check(shape.team==0 and shape.jobs.is_empty(),"Possession loss clears the previous team's attacking assignments")
 team_shape()
 var expelled: int=game.support.shape.jobs.channel_run
 game.players[expelled].dismissed=true; game.support.update(.01)
 check(expelled not in game.support.shape.jobs.values() and not game.support.targets.has(expelled),"A sent-off player cannot retain an attacking assignment")
 game.state="restart"; game.support.update(.1)
 check(game.support.shape.jobs.is_empty() and game.support.targets.is_empty(),"Stoppages discard attacking plans before the real restart sequence")
 # Support on the human team never grants permission to kick autonomously.
 setup(); player(9,Vector3(0,0,-12)); possession(9); game.support.update(.1)
 check(not game.ai_attack.act(9) and game.shots[0]==0 and game.passes[0]==0,"Coordinated human teammates still leave every pass and shot to the user")
 print("ATTACK DECISIONS CHECK: %d checks, %d failures" % [checks,failures])
 game.free(); quit(0 if failures==0 else 1)
