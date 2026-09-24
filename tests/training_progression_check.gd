extends SceneTree
const Career=preload("res://scripts/career.gd")
const Catalog=preload("res://scripts/training_catalog.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func _initialize() -> void:
	var c:=Career.new()
	c.save_root="/tmp/sefc-training-progress-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(c.save_root)
	check(c.new_career("c00",1),"A career initializes a saved weekly training program")
	var t=c.training; var d: Dictionary=t.data()
	check(d.slots.size()==5 and d.automatic,"The coach selects five sessions and automatic calendar completion by default")
	var ids: Array=d.slots.map(func(row): return row.player)
	var unique: Dictionary={}
	for pid in ids: unique[pid]=true
	check(unique.size()==5 and ids.all(func(pid): return t.eligible(c.world,pid)),"Suggested players are distinct, healthy and below their potential")
	check(d.slots.all(func(row): return row.drill in Catalog.options(c.player(row.player))),"Drills match the selected player's role")
	var p: Dictionary=c.player(ids[0])
	p.age=20; p.potential=90
	for key in Career.World.Talent.STATS: p.attributes[key]=60
	p.development.xp=0; p.development.gains=0
	var skills: Dictionary=p.attributes.duplicate()
	var result: Dictionary=t.award(0,100,true)
	check(result.grade=="A" and result.xp>20 and result.xp<25 and p.attributes==skills,"An excellent session grants gradual progress, not an instant ability jump")
	var before: Dictionary=p.duplicate(true)
	check(t.award(0,100,true).is_empty() and p==before,"Replaying the same weekly slot cannot grant points twice")
	check(not t.assign(0,ids[1],"passing") and not t.assign(1,ids[0],"passing"),"Completed rows and duplicate player assignments cannot bypass the weekly limit")
	check(c.save() and c.load_slot(1),"Training results survive the actual save and reload path")
	d=t.data(); p=c.player(ids[0])
	check(d.slots[0].done and p==before and d.best[ids[0]+":"+result.drill]==100,"Reload retains completed work, development and the earned best grade")
	var initial_day: int=c.world.date
	c.advance_one(); d=t.data()
	check(d.slots.all(func(row): return row.done) and d.history.size()==5,"Advancing one day lets the coach finish only the remaining four sessions")
	var history: Array=d.history.duplicate(true)
	t.daily(); t.daily()
	check(d.history==history,"Daily processing is idempotent on the same training week")
	for i in range(6): c.advance_one()
	d=t.data()
	check(c.world.date==initial_day+7 and d.week==c.world.date and d.slots.all(func(row): return not row.done),"A new list becomes available after seven calendar days")
	var returning: int=d.slots.find(d.slots.filter(func(row): return row.player==ids[0]).front()) if d.slots.any(func(row): return row.player==ids[0]) else 0
	check(t.assign(returning,ids[0],result.drill) and t.simulated_score(returning)==100,"The same player's earned best grade powers later automatic sessions")
	d.automatic=false
	var manual_ids: Array=d.slots.map(func(row): return row.player)
	c.advance_one()
	check(d.slots.all(func(row): return not row.done),"Manual scheduling leaves the weekly list unplayed when the calendar advances")
	var hurt: Dictionary=c.player(manual_ids[0]); hurt.injury=c.world.date+10
	check(not t.ready(0) and t.award(0,100,true).is_empty(),"An injured player cannot receive session rewards")
	hurt.injury=0; hurt.club="c01"
	check(not t.ready(0),"A player who left the club cannot train with its old weekly list")
	hurt.club=c.world.user
	t.refill(); d=t.data()
	var pid: String=d.slots[0].player
	var learner: Dictionary=c.player(pid)
	learner.age=20; learner.potential=90
	for key in Career.World.Talent.STATS: learner.attributes[key]=60
	learner.development.xp=95; learner.development.gains=0
	var drill: String=d.slots[0].drill
	var old_plan: int=learner.development.plan
	t.award(0,100,true)
	check(learner.attributes[Catalog.SKILLS[drill][0]]==61 and learner.development.plan==old_plan,"Accumulated points improve the practiced skill without changing the long-term plan")
	var low: Dictionary=learner.duplicate(true); var high: Dictionary=learner.duplicate(true)
	low.development.xp=0; low.development.gains=0; high.development.xp=0; high.development.gains=0
	c.director.gain(low,3+30*.13,Catalog.SKILLS[drill]); c.director.gain(high,3+90*.13,Catalog.SKILLS[drill])
	check(high.development.xp>low.development.xp*1.8,"Higher exercise scores yield more development under identical conditions")
	learner.potential=Career.World.ovr(learner)
	var capped: Dictionary=learner.attributes.duplicate()
	c.director.gain(learner,10000,Catalog.SKILLS[drill])
	check(learner.attributes==capped,"Exercise rewards respect the saved potential ceiling")
	var legacy: Dictionary=c.world.duplicate(true); legacy.erase("training")
	var old_players: Dictionary=legacy.players.duplicate(true)
	c.director.ensure(legacy)
	check(legacy.has("training") and legacy.players==old_players,"Older careers acquire a training program without rewriting players")
	var malformed: Dictionary=c.world.duplicate(true)
	malformed.training[c.world.user].slots[0].drill="missing_exercise"
	check(not c.valid(malformed),"Malformed saved training rows are rejected before they reach the menu")
	var departed: Dictionary=c.world.duplicate(true)
	departed.training[c.world.user].slots[0].player="released_academy_player"
	check(c.valid(departed),"A released player in an old training row does not invalidate the career save")
	print("TRAINING PROGRESSION CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
