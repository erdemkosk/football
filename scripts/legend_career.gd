extends RefCounted
const Progress=preload("res://scripts/legend_progression.gd")
const World=preload("res://scripts/career_world.gd")
const Catalog=preload("res://scripts/training_catalog.gd")
var game
var career:=preload("res://scripts/career.gd").new()
var manager_career
var live:=preload("res://scripts/legend_match.gd").new()
var selection: Dictionary={}
var status:=""

func setup(g) -> void:
	game=g; manager_career=g.career; career.game=g
	career.save_prefix="sefc_legend_"; career.player_mode=true
	live.legend=self; live.game=g

func active() -> bool: return game!=null and game.career==career and career.exists() and career.world.has("legend")
func match_active() -> bool: return active() and career.in_match and not game.training and not game.menu_match.running
func data() -> Dictionary: return career.world.legend
func player() -> Dictionary: return career.player(data().player)
func on_pitch() -> bool: return match_active() and live.index>=0 and game.players[live.index].career_id==data().player and not game.players[live.index].dismissed and game.players[live.index].visible
func allows_selection(index: int) -> bool: return not match_active() or (on_pitch() and index==live.index)

func open() -> void:
	if game.career.in_match: return
	game.humans.release(); game.career=career
	game.legend_screen.open_hub() if active() else game.legend_screen.open_entry()

func create(club: String,slot: int,config: Dictionary,settings: Dictionary={}) -> bool:
	var position:=clampi(int(config.get("position",9)),0,Progress.POSITIONS.size()-1)
	var name:=str(config.get("name","YENİ YILDIZ")).strip_edges().left(24).replace("i","İ").to_upper()
	if name.length()<2: status="Oyuncunun adını yaz (en az 2 harf)."; return false
	if not career.new_career(club,slot,settings,false): status=career.error; return false
	var p:=World.academy_player(career.world,career.club(),Progress.ROLES[position])
	p.name=name; p.age=18; p.attributes=Progress.initial_attributes(position,int(config.get("foot",1)))
	p.height_cm=clampi(int(config.get("height",190 if position==0 else 180)),160,205)
	p.weight_kg=clampi(int(config.get("weight",78 if position==0 else 73)),52,105)
	p.appearance_id=clampi(int(config.get("appearance",17)),0,9999)
	p.potential=92; p.legend_player=true; p.squad_role=0; p.keeper=position==0
	p.talent_version=World.Talent.VERSION; p.talent_club_bonus=0; p.contract=career.world.year+3
	p.fitness=1.0; p.wage=World.wage(p)
	career.director.player_fields(p)
	career.world.players[p.id]=p; career.club().roster.append(p.id); career.assign_shirt(p.id)
	career.world.legend=Progress.create_data(p.id,position,int(career.world.date))
	career.world.news.clear()
	career.news("İLK İMZA",p.name+" · "+career.club().name+". Önce yedek kulübesi; forma için çalış.","club")
	game.career=career; coach_selection()
	status="" if career.save() else career.error
	return status==""

func coach_selection() -> Dictionary:
	var d:=data(); var p:=player()
	if p.get("retired",false):
		selection={"starter":false,"available":false,"role":"KARİYER TAMAMLANDI","slot":0,"minute":90,"ability":World.ovr(p),"competition":0,"reason":"Futbolculuk kariyerin tamamlandı. Maçların, gollerin ve gelişimin bu kayıtta saklanıyor."}
		return selection
	var lineup: Array=career.best_eleven(career.world.user)
	if p.id in lineup:
		var old:=lineup.find(p.id)
		var pool: Array=career.roster(career.world.user).filter(func(pid): return pid not in lineup and career.available(pid) and career.player(pid).keeper==p.keeper)
		pool.sort_custom(func(a,b): return World.ovr(career.player(a))-(0 if career.player(a).role==p.role else 15)>World.ovr(career.player(b))-(0 if career.player(b).role==p.role else 15))
		if not pool.is_empty(): lineup[old]=pool[0]
	var slot:=Progress.slot_for(int(d.position),int(career.club().plan.formation))
	selection=Progress.selection(d,p,career.player(lineup[slot]))
	selection.slot=slot; selection.available=career.available(p.id)
	if not selection.available:
		selection.starter=false; selection.role="KADRO DIŞI"
		selection.reason="Sakatlık veya ceza bittiğinde tekrar forma için yarışacaksın."
	elif selection.starter: lineup[slot]=p.id
	career.club().lineup=lineup
	return selection

func ensure_bench(chosen: Array,reserves: Array,pool: Array) -> void:
	if not active() or not career.available(player().id) or player().id in chosen or player().id in reserves: return
	if player().id not in pool: return
	var replace:=reserves.size()-1
	for i in range(reserves.size()-1,-1,-1):
		if career.player(reserves[i]).keeper==player().keeper: replace=i; break
	reserves[replace]=player().id

func play() -> bool:
	if not active() or career.in_match: return false
	coach_selection()
	if not selection.available: status=selection.reason; return false
	if not career.prepare_match(): status=career.error; return false
	game.legend_screen.hide(); game.legend_screen.clear_controls()
	game.frontend.hide(); game.camera.cull_mask=game.legend_screen.world_mask; game.audio.set_process(true)
	game.humans.release(); game.start_match(false,bool(selection.starter))
	live.enforce_control()
	return true

func advance() -> void:
	if not active() or player().get("retired",false): return
	status=career.advance_to_event()
	Progress.refresh_week(data(),int(career.world.date))
	coach_selection(); career.save()

func train(mode: String) -> bool:
	if not active() or career.in_match or player().get("retired",false) or not career.training.active.is_empty(): return false
	Progress.refresh_week(data(),int(career.world.date))
	if data().sessions>=Progress.TRAINING_LIMIT: status="Bu haftanın üç çalışması tamamlandı. Takvimi ilerlet."; return false
	if player().injury>career.world.date: status="Sakatlık bitmeden saha çalışması yapamazsın."; return false
	if mode not in Catalog.options(player()): return false
	career.training.active={"legend":true,"player":player().id,"drill":mode,"week":data().week,"save":career.slot}
	game.legend_screen.hide(); game.legend_screen.clear_controls(); game.camera.cull_mask=game.legend_screen.world_mask
	game.audio.set_process(true); game.start_match(true,false,false,mode)
	game.players[9].apply_identity(player().duplicate(true)); game.players[9].apply_kit(World.kit(career.club()))
	return true

func training_skills(mode: String) -> Array:
	if player().keeper: return ["reflexes","handling","positioning","passing"]
	if mode=="slalom": return ["pace","acceleration","control","balance"]
	return Catalog.SKILLS[mode]

func finish_training(score: int) -> Dictionary:
	var context: Dictionary=career.training.active.duplicate(true)
	career.training.active={}
	if not active() or context.get("player","")!=player().id or context.get("save",-1)!=career.slot or context.get("week",-1)!=data().week: return {}
	var skills: Array=training_skills(context.drill)
	var result:=Progress.training(data(),player(),int(career.world.date),score,skills,context.drill)
	if not result.is_empty(): result.saved=career.save()
	return result

func leave_training() -> void:
	career.training.active={}; game.clubs.apply(); game.training=false; game.player_lock=false
	game.training_drills.challenges.clear(); game.training_menu.hide()
	game.legend_screen.open_hub(); game.legend_screen.go("training")

func learn(position: int) -> bool:
	if not active() or career.in_match or position<=0 or position>=Progress.POSITIONS.size() or player().keeper: return false
	var d:=data()
	if d.learning>=0 or d.positions.has(str(position)) or d.positions.size()>=3: return false
	d.learning=position; d.positions[str(position)]=0.0; career.save(); return true

func prefer(position: int) -> bool:
	if not active() or career.in_match or float(data().positions.get(str(position),0))<100: return false
	data().position=position; coach_selection(); career.save(); return true

func finish_match() -> void:
	if not active(): return
	var row:=live.result()
	Progress.match_result(data(),player(),career.fixture_id,row,bool(selection.get("starter",false)))
	coach_selection()

func draw(h) -> void:
	if not match_active() or game.state not in ["playing","restart","set_piece","halftime"]: return
	live.draw(h)
