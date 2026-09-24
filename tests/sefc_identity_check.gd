extends "res://tests/ai_attack_check.gd"
const World=preload("res://scripts/career_world.gd")
const SEFC=preload("res://scripts/sefc_identity.gd")

func country_options() -> Array:
	for control in game.career_screen.controls.get_children():
		if control is OptionButton and control.position==Vector2(694,173):
			var labels: Array=[]
			for i in range(control.item_count): labels.append(control.get_item_text(i))
			return labels
	return []

func capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	for frame in range(90): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-identity-"+label+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false); game.ball.freeze=true
	game.match_menu.config_path="/tmp/sefc-identity-settings.cfg"
	var c=game.career
	c.save_root="/tmp/sefc-identity-career"; DirAccess.make_dir_recursive_absolute(c.save_root)
	check(c.new_career("c00",1) and c.valid(c.world),"The independent SEFC world starts and saves correctly")
	var names: Dictionary={}; var shorts: Dictionary={}; var countries: Dictionary={}
	var rosters_ok:=true; var identities_ok:=true
	for i in range(36):
		var club: Dictionary=c.world.clubs["c%02d" % i]
		names[club.name]=true; shorts[club.short]=true
		identities_ok=identities_ok and club.nation==SEFC.NATION and club.name==SEFC.CLUBS[i][0] and club.city==SEFC.CLUBS[i][2]
		var squad_countries: Dictionary={}; var squad_names: Dictionary={}
		for pid in club.roster:
			var p: Dictionary=c.player(pid)
			squad_countries[p.nationality]=true; squad_names[p.name]=true
			countries[p.nationality]=int(countries.get(p.nationality,0))+1
			identities_ok=identities_ok and p.name==SEFC.player(p.appearance_id).name and World.International.NATIONS.has(p.nationality)
		rosters_ok=rosters_ok and club.roster.size()==24 and squad_countries.size()>=10 and squad_names.size()==24
	check(identities_ok and names.size()==36 and shorts.size()==36,"All 36 SEFC clubs have unique independent identities and country-consistent player names")
	check(rosters_ok and countries.size()==13 and countries.TR<100,"Every SEFC squad mixes countries without treating Turkey as the home nation")
	print("SEFC NATIONALITIES: ",countries)
	check(c.world.clubs.values().filter(func(club): return club.league==0).size()==18 and c.world.clubs.values().filter(func(club): return club.league==1).size()==18,"The independent association retains two eighteen-club divisions")
	check(c.world.clubs.tr00.name=="BOĞAZİÇİ YILDIZ" and c.world.clubs.tr00.nation=="TR" and c.world.clubs.tr00.league==9,"The separate Turkish league retains its own club identity")
	check(c.world.cups.domestic.title=="SEFC LİG KUPASI" and c.world.cups.domestic.entries.size()==36,"The shared SEFC cup identifies the independent league system")
	var quick_ok:=true
	for club in range(8):
		game.clubs.selected[0]=club
		for member in range(18):
			var quick: Dictionary=game.clubs.member(0,member)
			var career: Dictionary=c.player("p%04d" % (club*24+member))
			quick_ok=quick_ok and quick.name==career.name and quick.nationality==career.nationality
	check(quick_ok,"Quick-match players have the same names and nationalities as their career identities")
	game.clubs.ensure_world()
	check(game.clubs.league_ids(0).size()==18 and game.clubs.league_ids(1).size()==18 and game.clubs.league_ids(9).size()==18,"Quick-match league browsing keeps SEFC and Turkey separate")
	var youth_countries: Dictionary={}
	for i in range(39):
		var p:=World.academy_player(c.world,c.world.clubs.c00,i%4)
		youth_countries[p.nationality]=true
	check(youth_countries.size()==13 and not youth_countries.has(SEFC.NATION),"New SEFC academy players have genuine diverse nationalities")
	# Existing foreign signings remain foreign people; native SEFC people keep
	# their IDs even when they already transferred out of the association.
	var imported: String=c.world.clubs.tr00.roster[5]
	c.club().cash=50000000; c.club().budget=50000000
	check(c.transfer(imported,"c00",100000,9000,3,1,"") and c.transfer("p0009","tr00",100000,9000,3,1,""),"Prepares transfers in both directions before legacy migration")
	var import_before: Dictionary=c.player(imported).duplicate(true)
	var sefc_before: Dictionary=c.player("p0009").duplicate(true)
	c.world.clubs.c00.league=1; c.world.clubs.c18.league=0
	for i in range(36):
		var club: Dictionary=c.world.clubs["c%02d" % i]
		club.erase("sefc_identity_version"); club.nation="TR"
		club.name="ESKİ SEFC %d" % i; club.city="İSTANBUL"; club.short="ESK"
	for p in c.world.players.values():
		if p.appearance_id<864:
			p.erase("sefc_identity_version"); p.name="MERT YILMAZ"; p.nationality="TR"
	c.world.cups.domestic.title="SEFC ÜLKE KUPASI"
	c.world.fixtures[0].played=true; c.world.fixtures[0].score=[3,1]
	var legacy: Dictionary=c.world.duplicate(true)
	check(c.save() and c.load_slot(1),"A legacy career migrates through the real save/load path")
	var restored: Dictionary=c.world
	check(restored.clubs.c00.league==1 and restored.clubs.c18.league==0,"Migration preserves promotions and relegations rather than merging SEFC divisions")
	check(c.player(imported)==import_before and c.player("p0009")==sefc_before,"Imports stay unchanged and transferred SEFC players receive their stable identity wherever they play")
	var preserved:=true
	for id in restored.clubs:
		for key in ["roster","lineup","cash","budget","plan","primary","badge_id"]:
			preserved=preserved and restored.clubs[id][key]==legacy.clubs[id][key]
	for pid in restored.players:
		for key in ["attributes","potential","talent_version","appearance_id","club","wage","contract","loan","fitness","development"]:
			preserved=preserved and restored.players[pid][key]==legacy.players[pid][key]
	check(preserved,"Renaming preserves all player abilities, contracts, transfers, club kits, tactics and finances")
	check(restored.fixtures==legacy.fixtures and restored.table==legacy.table and restored.cup_fixtures==legacy.cup_fixtures,"Migration preserves every season result, table and cup fixture")
	var snapshot: Dictionary=restored.duplicate(true)
	check(c.save() and c.load_slot(1) and c.world==snapshot,"Repeated loading cannot rename again, duplicate clubs or reassign divisions")
	var ui=game.career_screen
	ui.open_hub(); ui.go("market")
	check(not country_options().has("YABANCI") and country_options().has("TÜRKİYE"),"SEFC's market offers countries without a Turkish domestic/foreign split")
	ui.nation_filter="*"; ui.build()
	check(ui.nation_filter=="" and not ui.list_ids.is_empty(),"A saved foreign filter clears when entering the independent association")
	c.world.user="tr00"; ui.go("market")
	check(country_options().has("YABANCI"),"Turkey still has a meaningful foreign-player filter")
	ui.nation_filter="*"; ui.build()
	check(not ui.list_ids.is_empty() and ui.list_ids.all(func(pid): return c.player(pid).nationality!="TR"),"The Turkish foreign filter excludes Turkish nationals")
	c.world.user="c46"; ui.nation_filter="*"; ui.build()
	check(c.club().nation=="GB" and not ui.list_ids.is_empty() and ui.list_ids.all(func(pid): return c.player(pid).nationality!="GB"),"Other national leagues use their own country for the foreign filter")
	ui.choose(1); await capture("career")
	ui.hide(); c.detach(); game.clubs.league=[0,0]; game.clubs.selected=[0,1]; game.clubs.apply()
	game.frontend.open_selection(); await capture("quick")
	game.frontend.hide(); c.world.user="c00"; ui.open_hub(); ui.go("squad"); await capture("squad")
	print("SEFC IDENTITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
