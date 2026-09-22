extends "res://tests/shot_direction_pad_check.gd"

func shot_turn(strength: float,seconds: float=.1,hz: int=120) -> float:
 setup(); button(JOY_BUTTON_X,true); stick(strength,0)
 var before: Vector3=game.shot_direction
 hold(seconds,hz)
 return rad_to_deg(before.angle_to(game.shot_direction))

func run() -> void:
 game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
 game.match_menu.config_path="/tmp/sefc-aim-precision.cfg"
 for family in ["xbox","playstation"]:
  game.controller.family=family
  var full := shot_turn(1)
  check(full>6 and full<8,"Full left-stick shot aim turns 6–8 degrees in 100 ms: "+family)
  var partial := shot_turn(.5)
  check(partial>.5 and partial<1.2,"Half-stick movement allows a sub-1.2-degree shot correction: "+family)
  var heading: Vector3=game.shot_direction
  stick(0,0); hold(.3)
  check(game.shot_direction.is_equal_approx(heading),"Centering the stick stops aiming immediately: "+family)
  stick(.10,.10); hold(.3)
  check(game.shot_direction.is_equal_approx(heading),"Stick drift inside the deadzone cannot move aim: "+family)
  stick(1,0); hold(1.3)
  check(game.shot_direction.dot(Vector3.RIGHT)>.999,"The slower aim still reaches a deliberate sideways target: "+family)
  var shown: Vector3=game.shot_direction
  button(JOY_BUTTON_X,false)
  check(not game.kick_contact.pending.is_empty() and game.kick_contact.pending.velocity.normalized().dot(shown)>.96,"Shot release queues the displayed heading for physical boot contact: "+family)
 # Moving sensitivity must not amplify small aiming corrections.
 game.controller.sensitivity=.6
 var low := shot_turn(.5)
 var slow_walk: Vector3=game.controller.movement()
 game.controller.sensitivity=1.8
 var high := shot_turn(.5)
 check(absf(high-low)<.001 and game.controller.movement().length()>slow_walk.length(),"Running sensitivity remains effective without accelerating the aiming cursor")
 game.controller.sensitivity=1
 var at_30 := shot_turn(1,.4,30)
 var at_60 := shot_turn(1,.4,60)
 var at_120 := shot_turn(1,.4,120)
 check(absf(at_30-at_120)<.001 and absf(at_60-at_120)<.001,"Aiming speed agrees at 30, 60 and 120 updates per second")
 setup(); stick(1,0); hold(.1)
 check(game.players[9].desired.x>.99,"Uncharged left-stick running keeps its full movement response")
 # Ordinary, through and lofted passes share the gentler direction control.
 for mode in [[false,false],[true,false],[false,true]]:
  setup(); game.dribbler=9; game.carrier=9; game.last_touch=0
  game.begin_pass(mode[0],mode[1]); stick(1,0)
  var before: Vector3=game.pass_direction
  hold(.1)
  var degrees := rad_to_deg(before.angle_to(game.pass_direction))
  check(game.pass_charging and degrees>5 and degrees<7,"Charged pass direction moves 5–7 degrees per 100 ms, mode "+str(mode))
  stick(0,0); hold(.2)
  check(game.pass_direction.angle_to(before)<deg_to_rad(7),"Centering the stick holds pass heading while power continues charging")
  var shown: Vector3=game.pass_preview.velocity
  game.release_pass()
  check(not game.kick_contact.pending.is_empty() and game.kick_contact.pending.velocity.is_equal_approx(shown),"A pass still commits exactly the previewed launch velocity")
 # Set-piece tests use the real restart setup and both placement/charging phases.
 for restart in ["SERBEST VURUŞ","KORNER","PENALTI","TAÇ"]:
  for charging in [false,true]:
   setup(); game.training=false
   var point := Vector3(0,0,-25)
   if restart=="KORNER": point=Vector3(31,0,-49)
   elif restart=="PENALTI": point=Vector3(0,0,-39)
   elif restart=="TAÇ": point=Vector3(31,0,-10)
   game.begin_restart(restart,0,point); game.state="set_piece"
   var sp=game.set_pieces
   sp.direction=Vector3.FORWARD; sp.button=KEY_D if charging else 0
   stick(1,0)
   for n in range(12): sp.update(1.0/120)
   var degrees := rad_to_deg(Vector3.FORWARD.angle_to(sp.direction))
   var maximum := 1.0 if charging or restart=="PENALTI" else 3.2
   check(degrees>.1 and degrees<maximum,"Precise left-stick restart aim: %s, charging=%s" % [restart,charging])
   var held: Vector3=sp.direction
   stick(0,0)
   for n in range(12): sp.update(1.0/120)
   check(sp.direction.is_equal_approx(held),"Restart aim stays fixed when the stick is released")
 # Shootout crosshair uses the same response without slowing goalkeeper dives.
 setup(); game.state="shootout"
 var final=game.finale
 final.shooter=game.players[9]; final.keeper=game.players[11]
 final.phase="ready"; final.side=0; final.paused=false; final.keys.clear()
 final.aim=Vector2(0,.45); final.axes=Vector2.RIGHT; game.controller.using_gamepad=true
 for n in range(12): final.update(1.0/120)
 check(final.aim.x<-.04 and final.aim.x>-.06,"Shootout crosshair makes a controlled full-stick correction")
 final.axes=Vector2.ZERO
 var held_aim: Vector2=final.aim
 for n in range(12): final.update(1.0/120)
 check(final.aim.is_equal_approx(held_aim),"Shootout aim also stops immediately at neutral")
 final.axes=Vector2.RIGHT
 check(final.input_direction()==Vector2.RIGHT,"Goalkeeper dive direction still receives the full analog input")
 # Keyboard and independent aiming keep their existing controls.
 setup(); game.controller.using_gamepad=false; game.begin_shot()
 var e := InputEventKey.new(); e.keycode=KEY_RIGHT; e.physical_keycode=KEY_RIGHT; e.pressed=true
 Input.parse_input_event(e); Input.flush_buffered_events(); hold(.1)
 check(absf(rad_to_deg(Vector3.FORWARD.angle_to(game.shot_direction))-2)<.02,"Keyboard shot corrections retain their established two-degree tap")
 e=e.duplicate(); e.pressed=false; Input.parse_input_event(e); Input.flush_buffered_events()
 setup(); button(JOY_BUTTON_X,true); button(JOY_BUTTON_DPAD_RIGHT,true); hold(.1)
 check(absf(rad_to_deg(Vector3.FORWARD.angle_to(game.shot_direction))-12)<.02,"Independent D-pad aiming retains its existing response")
 print("AIM PRECISION CHECK: %d checks, %d failures" % [assertions,failures])
 game.free(); quit(0 if failures==0 else 1)
