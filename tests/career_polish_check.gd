extends "res://tests/career_flow_check.gd"
const Hair=preload("res://scripts/hair_styles.gd")

func tactic_card(id: String) -> Control:
 for child in game.career_screen.controls.get_children():
  if child.get_meta("focus_key","")=="tactic:"+id: return child
 return null

func picture(label: String) -> void:
 if not "--visual" in OS.get_cmdline_user_args(): return
 for frame in range(110): await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("/tmp/sefc-polish-"+label+".png")

func hair_gallery() -> void:
 if not "--visual" in OS.get_cmdline_user_args(): return
 var ui=game.career_screen
 var gallery:=Control.new(); gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(gallery)
 var background:=ColorRect.new(); background.color=Color("101f2d"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); gallery.add_child(background)
 var data_set: Array=[]
 for id in range(18):
  var data: Dictionary=ui.portrait_data(game.career.club().lineup[0])
  data.appearance_id=id; data.name="MODEL "+str(id); data.shirt=id+1; data.height_cm=180; data.weight_kg=76; data.keeper=false
  data_set.append(data); ui.portraits.request(data)
 for frame in range(180): await process_frame
 for id in range(18):
  var data: Dictionary=data_set[id]
  var texture:=TextureRect.new(); texture.texture=ui.portraits.photo(data); texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  texture.position=Vector2(60+(id%6)*224,15+(id/6)*283); texture.size=Vector2(192,225); texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; gallery.add_child(texture)
  var label:=Label.new(); label.text=Hair.NAMES[Hair.style_for(id)]; label.position=texture.position+Vector2(0,227); label.size=Vector2(192,30); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  gallery.add_child(label)
 await picture("hair-gallery")
 gallery.queue_free(); await process_frame

func run() -> void:
 game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
 game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
 game.controller.device=0; game.controller.using_gamepad=true; game.ball.freeze=true
 game.match_menu.config_path="/tmp/sefc-polish-settings.cfg"
 var c=game.career; var ui=game.career_screen
 c.save_root="/tmp/sefc-career-polish"; DirAccess.make_dir_recursive_absolute(c.save_root)
 c.new_career("c00",1); ui.open_hub(); ui.go("tactics"); game.controller.menus.sync()
 var unique: Dictionary={}
 for id in range(18):
  var p=game.players[9]; p.apply_identity({"appearance_id":id,"shirt":10,"height_cm":180,"weight_kg":76})
  unique[p.hair_style]=true
  check(p.haircut.mesh.get_surface_count()==1,"Hair silhouette uses a single mesh surface: "+Hair.NAMES[p.hair_style])
 check(unique.size()==18,"Eighteen distinct cuts are distributed across player identities")
 var p=game.players[9]; p.apply_identity({"appearance_id":11,"shirt":4})
 var style: int=p.hair_style; var mesh: Mesh=p.haircut.mesh; var color: Color=p.kit_materials.hair.albedo_color
 p.apply_identity({"appearance_id":11,"shirt":30})
 check(p.hair_style==style and p.haircut.mesh==mesh and p.kit_materials.hair.albedo_color==color,"Changing shirt or lineup slot preserves the player's hairstyle")
 var defaults: Dictionary={}
 for id in range(18): defaults[game.clubs.member(0,id).appearance_id]=true
 check(defaults.size()==18,"Quick-match starters and reserves have stable distinct appearance identities")
 check(not ui.tactics.settings_open and ui.controls.get_children().any(func(node): return node.get_meta("focus_key","")=="tactic:settings"),"Career tactics opens with the bench and a separate settings button")
 var before: Array=c.club().lineup.duplicate()
 var outgoing: String=before[9]
 var incoming: String=ui.tactics.reserves(ui).filter(func(id): return not c.player(id).keeper)[0]
 check(go(tactic_card(outgoing)),"The controller reaches an on-pitch player")
 tap(JOY_BUTTON_A)
 check(ui.tactics.selected==outgoing,"A selects the outgoing player on the pitch")
 check(go(tactic_card(incoming)),"The controller reaches a reserve from the pitch")
 tap(JOY_BUTTON_A)
 check(c.club().lineup[9]==incoming and outgoing in ui.tactics.reserves(ui),"Two selections exchange the starter and reserve immediately")
 check(c.club().lineup.size()==11 and c.club().lineup.count(incoming)==1,"A quick swap keeps eleven unique starters")
 check(c.read_save(1).get("world",{}).clubs.c00.lineup[9]==incoming,"The new lineup is persisted in the career save")
 ui.tactics.undo(ui)
 check(c.club().lineup==before,"Undo restores the previous starting eleven")
 ui.tactics.choose(ui,before[0]); ui.tactics.choose(ui,incoming)
 check(c.club().lineup==before and "Kaleci" in ui.status,"An outfielder cannot replace the goalkeeper")
 ui.tactics.selected=""; c.player(incoming).injury=c.world.date+5
 ui.tactics.choose(ui,outgoing); ui.tactics.choose(ui,incoming)
 check(c.club().lineup==before,"Injured reserves cannot enter the starting lineup")
 c.player(incoming).injury=0; ui.tactics.selected=""; ui.status=""; ui.build()
 await picture("tactics-bench")
 tap(JOY_BUTTON_Y)
 check(ui.tactics.settings_open and ui.controls.get_children().any(func(node): return node is OptionButton),"Y opens tactical settings in the same sidebar")
 var reachable:=true
 for child in ui.controls.get_children():
  if child is BaseButton and not child.disabled: reachable=go(child) and reachable
 check(reachable,"Every tactical setting and saved-plan action is reachable by controller")
 var formation: OptionButton
 for child in ui.controls.get_children():
  if child.get_meta("focus_key","")=="plan:formation": formation=child
 check(go(formation),"The formation control remains reachable with the controller")
 tap(JOY_BUTTON_DPAD_RIGHT)
 check(c.club().plan.formation==1 and game.management.formation==1,"Formation changes immediately update the pitch and match plan")
 await picture("tactics-settings")
 tap(JOY_BUTTON_B)
 check(not ui.tactics.settings_open and ui.page=="tactics","B closes settings and returns to the reserve list")
 ui.tactics.turn_page(ui,1)
 check(ui.tactics.bench_page==1 and tactic_card(ui.tactics.reserves(ui)[10])!=null,"The remaining reserves are accessible on the next page")
 ui.tactics.turn_page(ui,-1)
 var receiver=tactic_card(incoming)
 check(receiver._can_drop_data(Vector2.ZERO,{"career_player":outgoing}),"A reserve accepts a drag from the starting eleven")
 receiver._drop_data(Vector2.ZERO,{"career_player":outgoing})
 check(incoming in c.club().lineup,"Drag-and-drop uses the same validated lineup swap")
 ui.tactics.undo(ui)
 # Advancing and skipping the presentation must never advance the save twice.
 ui.go("hub"); game.controller.menus.sync()
 var day_before: int=c.world.date
 ui.advance_calendar()
 var day_after: int=c.world.date
 check(day_after>day_before and ui.calendar.visible,"Advancing the career starts a visible calendar transition")
 ui.advance_calendar()
 check(c.world.date==day_after,"Repeated advance input cannot skip another week during the animation")
 check(focus()==ui.calendar.finish_button and focus().find_valid_focus_neighbor(SIDE_LEFT)==focus(),"Calendar focus is captured so background actions cannot activate")
 ui.calendar.set_process(false); ui.calendar.age=ui.calendar.travel*.55; ui.calendar.queue_redraw()
 await picture("calendar-moving")
 ui.calendar.age=ui.calendar.travel+.2; ui.calendar.finish_button.text="DEVAM ET"; ui.calendar.queue_redraw()
 await picture("calendar-arrived")
 tap(JOY_BUTTON_A)
 check(not ui.calendar.visible and c.world.date==day_after and focus().position==Vector2(77,532),"A skips the effect and restores the next career action without advancing again")
 check(ui.status.contains(str(day_after-day_before)+" gün ilerledi"),"The hub keeps a clear elapsed-days and old/new date confirmation")
 var saved: Dictionary=c.read_save(1)
 check(saved.world.date==day_after,"The calendar result is saved independently of animation completion")
 ui.calendar.begin(day_before,day_after,"Takım hazır.")
 ui.calendar._process(ui.calendar.travel+1.0)
 check(not ui.calendar.visible and c.world.date==day_after,"The transition also completes automatically without touching the saved date")
 ui.go("tactics"); await hair_gallery()
 # Live tactics must queue a legal substitution instead of editing the saved XI.
 ui.go("hub"); var f: Dictionary=c.next_fixture(); c.world.date=f.day
 ui.play(); game.frontend.confirm(); game.ceremony.finish(true)
 game.frontend.open_tactics(); ui.open_live_tactics(); game.controller.menus.sync()
 var live_before: String=game.players[9].career_id
 var bench_id: String=ui.tactics.reserves(ui).filter(func(id): return not c.player(id).keeper)[0]
 ui.tactics.choose(ui,live_before); ui.tactics.choose(ui,bench_id)
 check(game.management.pending.size()==1 and game.players[9].career_id==live_before,"Live quick changes wait for the next stoppage rather than swapping players instantly")
 check(ui.tactics.player_info(ui,live_before).tactic_status=="ÇIKACAK" and ui.tactics.player_info(ui,bench_id).tactic_status=="GİRECEK","Both sides of a queued substitution are clearly identified")
 ui.tactics.choose(ui,live_before); tap(JOY_BUTTON_X)
 check(game.management.pending.is_empty() and game.players[9].career_id==live_before,"X cancels the selected pending change without changing the on-pitch player")
 game.management.used[0]=3
 ui.tactics.choose(ui,live_before); ui.tactics.choose(ui,bench_id)
 check(game.management.pending.is_empty() and "Üç" in ui.status,"Live tactics respects the three-substitution limit")
 var bench_index: int=ui.tactics.reserves(ui).find(bench_id)
 game.management.bench[0][bench_index].used=true; game.players[9].career_id=bench_id; ui.build()
 var used_card
 for child in ui.controls.get_children():
  if child.get_script()==ui.tactics.Card and child.identity==bench_id and not child.on_pitch: used_card=child
 check(used_card!=null and used_card.disabled and not used_card._can_drop_data(Vector2.ZERO,{"career_player":live_before}),"Used reserves cannot be selected or targeted by drag-and-drop")
 check(ui.tactics.player_info(ui,bench_id).tactic_status=="HAZIR","A substitute now playing is shown as ready on the pitch")
 game.management.bench[0][bench_index].used=false; game.players[9].career_id=live_before; ui.build()
 await picture("live-tactics")
 ui.close()
 check(game.state=="playing" and not game.ball.freeze,"Closing live tactics resumes the original match state")
 print("CAREER POLISH CHECK: %d checks, %d failures" % [checks,failures])
 game.free(); quit(0 if failures==0 else 1)
