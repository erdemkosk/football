extends "res://tests/advanced_play_check.gd"

func run() -> void:
 game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
 game.match_menu.config_path="/tmp/sefc-aim-contact.cfg"
 for action in [JOY_BUTTON_X,JOY_BUTTON_A,JOY_BUTTON_Y]:
  await reset()
  game.controller.device=0
  button(action); axis(JOY_AXIS_LEFT_X,.5)
  await tick(30)
  axis(JOY_AXIS_LEFT_X,0)
  await tick(6)
  var shown: Vector3=game.shot_direction if action==JOY_BUTTON_X else (game.pass_preview.velocity*Vector3(1,0,1)).normalized()
  var contacts: int=game.kick_contact.contacts
  button(action,false)
  check(not game.kick_contact.pending.is_empty(),"Aimed action waits for physical contact, button %d" % action)
  for frame in range(80):
   await tick()
   if game.kick_contact.contacts>contacts: break
  check(game.kick_contact.contacts==contacts+1,"Aimed action reaches the boot exactly once, button %d" % action)
  var actual: Vector3=(game.ball.kick_velocity*Vector3(1,0,1)).normalized()
  check(actual.dot(shown)>.9999,"Physical launch follows the slower aimed preview, button %d" % action)
 print("AIM CONTACT CHECK: %d checks, %d failures" % [checks,failures])
 game.free(); quit(0 if failures==0 else 1)
