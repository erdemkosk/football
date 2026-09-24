extends RefCounted
## Local, bounded match reports. No network, account ID or automatic upload.
var game
var enabled := true
var active := false
var report: Dictionary = {}
var output_dir := "user://playtests"
var last_file := ""
var pending_shot := -1
var sample_in := 0.0
var recorded_time := 0.0
const MAX_EVENTS := 3000

func begin(practice: bool,background: bool,automated: bool=false) -> void:
	if active: finish("abandoned")
	if not practice and not background:
		report.clear(); last_file=""
	active=enabled and not practice and not background and (automated or DisplayServer.get_name()!="headless")
	pending_shot=-1; sample_in=0; recorded_time=0
	if not active: return
	last_file=""
	# Keep reports from different match lengths comparable.
	report={"schema":1,"balance_version":"rain-fatigue-1","engine":Engine.get_version_info().string,"source":"automated" if automated else "human","started_utc":Time.get_datetime_string_from_system(true),"id":"%d-%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()],"difficulty":game.management.difficulty,"match_length":game.LENGTH,"pass_assistance":game.pass_assistance,"shots":[],"events":[],"samples":[],"feedback":{},"truncated":false}

func update(delta: float) -> void:
	if not active: return
	if not enabled: finish("recording_disabled"); return
	if game.state in ["finished","trophy"]: finish("completed"); return
	if game.state=="menu": finish("abandoned"); return
	if game.state in ["restart","set_piece","halftime"]: resolve_shot("no_goal")
	if game.state!="playing" or game.menu_match.running: return
	recorded_time+=delta
	if pending_shot>=0 and recorded_time-float(report.shots[pending_shot].elapsed)>12: resolve_shot("no_goal")
	sample_in-=delta
	if sample_in>0: return
	sample_in=5
	if report.samples.size()>=600: report.truncated=true; return
	var teams := []
	for side in [0,1]:
		var energy := 0.0; var fatigue := 0.0; var count := 0
		for p in game.players:
			if p.visible and not p.dismissed and p.team==side:
				energy+=p.energy; fatigue+=p.match_fatigue; count+=1
		teams.append({"energy":energy/maxi(1,count),"fatigue":fatigue/maxi(1,count)})
	report.samples.append({"clock":game.match_time,"wetness":game.weather.wetness,"teams":teams,"score":game.score.duplicate()})

func event(kind: String,index: int,data: Dictionary={}) -> void:
	if not active or not enabled or game.menu_match.running: return
	if report.events.size()>=MAX_EVENTS: report.truncated=true; return
	var row := data.duplicate(true)
	row.merge({"event":kind,"player":index,"clock":game.match_time},true)
	report.events.append(row)

func strike(index: int,velocity: Vector3,kind: String,is_save: bool) -> void:
	if not active or not enabled: return
	var p=game.players[index]
	if is_save:
		resolve_shot("saved"); event("save",index); return
	if pending_shot>=0: resolve_shot("blocked" if p.team!=report.shots[pending_shot].team else "continued")
	if kind not in ["shot","header","volley","half_volley","finish"]:
		event("contact",index,{"kind":kind}); return
	if report.shots.size()>=500: report.truncated=true; return
	var point: Vector3=game.ball.position
	var depth: float=50-point.z*game.attack_sign(p.team)
	var angle := rad_to_deg(atan2(absf(point.x),maxf(.01,depth)))
	report.shots.append({"player":index,"team":p.team,"kind":kind,"style":game.finishing.style if index==game.controlled else "","clock":game.match_time,"elapsed":recorded_time,"x":point.x,"depth":depth,"angle":angle,"distance":Vector2(point.x,depth).length(),"speed":velocity.length(),"velocity":[velocity.x,velocity.y,velocity.z],"wetness":game.weather.wetness,"mud":game.weather.mud_at(point),"energy":p.energy,"fatigue":p.match_fatigue,"pressure":game.first_touch.pressure(index),"outcome":"pending"})
	pending_shot=report.shots.size()-1

func resolve_shot(outcome: String) -> void:
	if pending_shot<0: return
	report.shots[pending_shot].outcome=outcome
	pending_shot=-1

func goal(team: int) -> void:
	if not active: return
	if pending_shot>=0: resolve_shot("goal" if report.shots[pending_shot].team==team else "own_goal")
	event("goal",game.last_kicker,{"team":team})

func finish(reason: String) -> bool:
	if not active: return false
	resolve_shot("unresolved")
	report.status=reason
	report.score=game.score.duplicate()
	report.duration=game.match_time
	report.statistics={"shots":game.shots.duplicate(),"on_target":game.shots_on_target.duplicate(),"saves":game.saves.duplicate(),"passes":game.passes.duplicate(),"possession":game.possession.duplicate()}
	active=false
	return write_report()

func write_report() -> bool:
	if report.is_empty(): return false
	var directory := ProjectSettings.globalize_path(output_dir)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK: return save_failed()
	var path := directory.path_join("match-"+report.id+".json")
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return save_failed()
	file.store_string(JSON.stringify(report,"\t"))
	file.flush()
	error=file.get_error(); file.close()
	if error!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK: return save_failed()
	last_file=path
	return true

func save_failed() -> bool:
	game.announce("Maç raporu diske yazılamadı. Ayarlardan yeniden kaydedebilirsin.")
	return false

func feedback(controls: int,balance: int,animation: int,note: String) -> bool:
	if report.is_empty() or active: return false
	report.feedback={"controls":clampi(controls,1,5),"balance":clampi(balance,1,5),"animation":clampi(animation,1,5),"note":note.left(500)}
	return write_report()
