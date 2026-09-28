extends SceneTree
const Career=preload("res://scripts/career.gd")
const World=preload("res://scripts/career_world.gd")
const Progress=preload("res://scripts/legend_progression.gd")
const Equipment=World.Equipment
var c
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func fresh(position: int=7) -> void:
	c=Career.new(); c.save_root="/tmp/sefc-equipment-unit-"+str(OS.get_process_id()); DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("c18",1,{},false); c.player_mode=true
	var p:=World.academy_player(c.world,c.club(),Progress.ROLES[position])
	p.legend_player=true; p.keeper=position==0; p.attributes=Progress.initial_attributes(position,1)
	p.wage=World.wage(p); p.potential=92; p.contract=2030; c.director.player_fields(p)
	c.world.players[p.id]=p; c.club().roster.append(p.id); c.assign_shirt(p.id)
	c.world.legend=Progress.create_data(p.id,position,c.world.date); Equipment.ensure(c.world)
func hero() -> Dictionary: return c.player(c.world.legend.player)
func wallet() -> Dictionary: return c.world.legend.equipment
func funded() -> void: Equipment.credit(c.world,hero().id,"test-contract",20000,"İmza parası")
func run() -> void:
	fresh(); var p:=hero()
	check(wallet().balance==0 and wallet().owned==["club_boots"] and Equipment.bonuses(c.world).is_empty() and c.valid(c.world),"New personal careers begin with a valid empty wallet and free neutral boots")
	var before: Dictionary=wallet().duplicate(true); var budget: int=c.club().budget
	Equipment.use(c,"pace")
	check(wallet()==before and c.club().budget==budget,"Club transfer funds cannot pay for personal equipment")
	c.world.date=World.day(2026,7,31); var cash: int=c.club().cash; var wages: int=c.payroll(c.world.user)
	c.advance_one()
	check(wallet().balance==p.wage and c.club().cash==cash+int(c.club().reputation*1900)-wages,"The real monthly payroll credits personal salary without charging the club twice")
	before=wallet().duplicate(true); Equipment.salary(c.world,"2026-8")
	check(wallet()==before and c.save() and c.load_slot(1) and wallet()==before,"Repeated salary settlement and reloading cannot mint another month's salary")
	p=hero(); var permanent: Dictionary=p.attributes.duplicate(true); var ovr: int=World.ovr(p); var value: int=c.market.value(p)
	cash=c.club().cash; budget=c.club().budget; var balance: int=wallet().balance
	check(Equipment.use(c,"touch").contains("satın alındı") and wallet().balance==balance-1200 and wallet().spent==1200,"Buying equipment charges its advertised one-time price and equips it")
	check(c.club().cash==cash and c.club().budget==budget and p.attributes==permanent and World.ovr(p)==ovr and c.market.value(p)==value,"Purchases leave club finances, permanent ability and transfer valuation unchanged")
	before=wallet().duplicate(true); Equipment.use(c,"touch")
	check(wallet()==before,"Repeated purchase clicks cannot buy or charge the equipped item twice")
	Equipment.use(c,"club_boots"); Equipment.use(c,"touch")
	check(wallet().balance==before.balance and wallet().owned.count("touch")==1,"Owned equipment can be switched freely without stacking ownership or price")
	funded(); Equipment.use(c,"pace"); Equipment.use(c,"insoles")
	var identity: Dictionary=p.duplicate(true); Equipment.apply(c.world,identity)
	check(identity.attributes.pace==permanent.pace+3 and identity.attributes.acceleration==permanent.acceleration+2 and identity.attributes.control==permanent.control-1 and identity.attributes.stamina==permanent.stamina+2,"Boot and support tradeoffs combine on the actual match identity")
	var applied: Dictionary=identity.duplicate(true); Equipment.apply(c.world,identity)
	check(identity==applied and p.attributes==permanent,"Applying match equipment twice cannot stack bonuses or overwrite trained stats")
	var other: Dictionary=c.player(c.club().roster[0]).duplicate(true); var untouched: Dictionary=other.duplicate(true); Equipment.apply(c.world,other)
	check(other==untouched,"Equipment affects only the controlled footballer")
	Equipment.use(c,"recovery")
	check(wallet().equipped.support=="recovery" and not Equipment.bonuses(c.world).has("stamina"),"Only one support item can be active; switching removes the old bonus")
	p.fitness=.5; var injury: int=p.injury; c.world.date=World.day(2026,8,2); c.advance_one()
	check(is_equal_approx(p.fitness,.563) and p.injury==injury,"Recovery equipment modestly improves daily fitness without curing injuries")
	p.fitness=.999; Equipment.recover(c.world)
	check(p.fitness==1,"Recovery cannot exceed full fitness")
	before=wallet().duplicate(true); Equipment.use(c,"gloves"); Equipment.use(c,"unknown")
	check(wallet()==before,"Outfield players cannot buy goalkeeper-only equipment or unknown products")
	c.in_match=true; Equipment.use(c,"control"); Equipment.remove_support(c)
	check(wallet()==before,"Shopping and loadout changes are blocked during a match")
	c.in_match=false; c.training.active={"legend":true}; Equipment.use(c,"control"); Equipment.remove_support(c)
	check(wallet()==before,"A running training session cannot switch equipment for free advantages")
	c.training.active={}; var root_path: String=c.save_root; c.save_root=root_path.path_join("missing/directory")
	Equipment.use(c,"control")
	check(wallet()==before,"A failed purchase save restores money, ownership and equipped items")
	c.save_root=root_path; Equipment.remove_support(c)
	check(wallet().equipped.support=="" and "recovery" in wallet().owned,"Removing equipment preserves ownership while removing its effect")
	for key in ["pace","acceleration"]: p.attributes[key]=95
	identity=p.duplicate(true); Equipment.apply(c.world,identity)
	check(identity.attributes.pace==95 and identity.attributes.acceleration==95,"Gear cannot exceed the established attribute ceiling")
	before=wallet().duplicate(true); c.save(); c.load_slot(1)
	check(wallet()==before,"Money, spending history, owned items and loadout survive save/load exactly")
	for change in [{"balance":-1},{"balance":1.5},{"owned":["club_boots","missing"]},{"equipped":{"boots":"gloves","support":""}}]:
		var corrupt: Dictionary=c.world.duplicate(true); corrupt.legend.equipment.merge(change,true)
		check(not c.valid(corrupt),"Malformed personal economy data is rejected: "+str(change.keys()))
	# Old saves gain a wallet, without inventing backdated salaries or purchases.
	var old: Dictionary=c.world.duplicate(true); old.legend.erase("equipment")
	var attributes: Dictionary=old.players[old.legend.player].attributes.duplicate(true)
	var file:=FileAccess.open(c.path_for(2),FileAccess.WRITE); file.store_var(old); file.close()
	check(c.load_slot(2) and wallet().balance==0 and wallet().owned==["club_boots"] and hero().attributes==attributes,"Legacy saves migrate to neutral equipment without retroactive earnings or lost ability")
	fresh(0); funded(); Equipment.use(c,"gloves"); identity=hero().duplicate(true); Equipment.apply(c.world,identity)
	check(identity.attributes.handling==hero().attributes.handling+3 and identity.attributes.reflexes==hero().attributes.reflexes+2 and c.valid(c.world),"Goalkeepers can equip role-appropriate gloves with bounded real effects")
	# Pay the same contract bonuses the club actually debits when the user plays.
	fresh(); p=hero(); p.terms.appearance=150; p.terms.goal=100
	var f: Dictionary=c.world.fixtures.filter(func(row): return row.home==c.world.user)[0]
	c.world.date=f.day; c.match_participants=[[p.id],[]]; c.match_minutes={p.id:30}
	check(c.apply_result(f,[1,0],{p.id:1},true) and wallet().balance==250,"A played substitute appearance and goal credit their real contractual bonuses")
	balance=wallet().balance; c.apply_result(f,[1,0],{p.id:1},true)
	check(wallet().balance==balance,"Replaying match completion cannot duplicate personal bonuses")
	# A new season keeps personal possessions while posting the distinct July salary.
	funded(); Equipment.use(c,"pace"); balance=wallet().balance; var owned: Array=wallet().owned.duplicate()
	for fixture in c.cups.all_fixtures(): fixture.played=true; fixture.score=[0,0]
	for cup in c.world.cups.values(): cup.champion="c00"
	c.world.season_done=true; c.world.date=World.day(2027,6,30)
	check(c.next_season() and wallet().balance==balance+hero().wage and wallet().owned==owned and wallet().equipped.boots=="pace","Season rollover preserves equipment and posts the new July salary once")
	print("LEGEND EQUIPMENT CHECK: %d checks, %d failures" % [checks,failures]); c=null; quit(1 if failures else 0)
