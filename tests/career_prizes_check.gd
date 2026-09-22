extends "res://tests/career_cups_check.gd"

func gate(f: Dictionary,id: String) -> int:
	return 45000+int(c.world.clubs[id].reputation)*1200 if f.home==id else 0

func run() -> void:
	fresh("tr17")
	check(World.league_prize(9,1,18)==6000000 and World.league_prize(7,1,8)==18000000,"Turkish and English titles have distinct league-value rewards")
	check(World.league_prize(0,1,18)==8000000 and World.league_prize(1,1,18)==2000000,"Promotion from the second division opens a more valuable title")
	var fair:=true
	for league in range(World.LEAGUES.size()):
		var count: int=c.standings(league).size()
		var previous:=World.league_prize(league,1,count)
		for position in range(2,count+1):
			var amount:=World.league_prize(league,position,count)
			fair=fair and amount>0 and amount<previous
			previous=amount
	check(fair,"Every league pays decreasing finish-position awards and a distinct champion bonus")
	check(not c.settle_league_prizes(9) and c.world.league_prizes.is_empty(),"An unfinished league cannot grant a championship payment")
	var fixtures: Array=c.world.fixtures.filter(func(f): return f.league==9)
	var last: Dictionary=fixtures.back()
	for f in fixtures:
		if f==last: break
		c.world.date=f.day
		c.apply_result(f,[3,0] if f.home=="tr17" else ([0,3] if f.away=="tr17" else [0,0]))
	check(c.world.league_prizes.is_empty(),"A mathematically secured title waits for the league's final fixture")
	var cash: int=c.club().cash; var budget: int=c.club().budget
	c.world.date=last.day; c.apply_result(last,[3,0] if last.home=="tr17" else ([0,3] if last.away=="tr17" else [0,0]))
	check(c.standings(9)[0]=="tr17" and c.club().cash==cash+gate(last,"tr17")+6000000,"The final league whistle immediately credits the actual champion's cash")
	check(c.club().budget==budget+4800000,"Eighty percent of the league prize becomes additional transfer authority")
	check(c.world.league_prizes["2026:9"].awards.size()==18 and not c.world.season_done,"All Turkish clubs receive one award without waiting for other leagues or cups")
	check(c.world.news[0].title=="ŞAMPİYONLUK ÖDÜLÜ" and c.world.news[0].body.contains("€6,00 M") and c.world.news[0].body.contains("€4,80 M"),"The career news names both actual cash and usable transfer rewards")
	cash=c.club().cash; budget=c.club().budget
	var ledger: int=c.world.ledger.size()
	check(not c.settle_league_prizes(9) and not c.apply_result(last,[9,0]) and c.club().cash==cash and c.club().budget==budget and c.world.ledger.size()==ledger,"Reprocessing the result or settlement cannot pay again")
	check(c.save() and c.load_slot(1) and c.club().cash==cash and c.club().budget==budget,"Saving and reloading a champion preserves the payment without duplicating it")
	# A pre-update completed league had not yet received its rollover payment.
	var old: Dictionary=c.world.duplicate(true)
	for id in old.league_prizes["2026:9"].awards:
		var amount: int=old.league_prizes["2026:9"].awards[id]
		old.clubs[id].cash-=amount; old.clubs[id].budget-=roundi(amount*.8)
	old.erase("league_prizes")
	old.ledger=old.ledger.filter(func(item): return not item.label.contains("ödülü"))
	var file:=FileAccess.open(c.path_for(2),FileAccess.WRITE); file.store_var(old); file.close()
	check(c.load_slot(2) and c.club().cash==cash and c.club().budget==budget,"A completed legacy league receives its previously unpaid title award on load")
	check(c.save() and c.load_slot(2) and c.club().cash==cash,"The migrated payment is persistent and idempotent")
	# Real knockout results: regulation, extra-time and shootout winners can be away.
	for outcome in range(3):
		fresh()
		c.world.cup_fixtures=c.world.cup_fixtures.filter(func(f): return f.competition!="champions")
		c.world.cups.champions.stage=3
		var final: Dictionary=c.cups.fixture(c.world,"champions","c00","c01",3,World.day(2027,5,5))
		c.world.date=final.day
		var winner: String="c00" if outcome==0 else "c01"
		if outcome==1: final.extra_time=true
		if outcome==2: final.live_penalties=true; final.penalties=[3,5]
		cash=c.world.clubs[winner].cash; budget=c.world.clubs[winner].budget
		var loser: String="c01" if winner=="c00" else "c00"
		var loser_budget: int=c.world.clubs[loser].budget
		check(c.apply_result(final,[[2,1],[1,2],[1,1]][outcome]) and c.world.cups.champions.champion==winner,"Final result %d awards the correct champion, including away and shootout winners" % outcome)
		check(c.world.clubs[winner].cash==cash+gate(final,winner)+25000000 and c.world.clubs[winner].budget==budget+25000000,"Final result %d credits €25M to cash and transfer budget immediately" % outcome)
		check(c.world.clubs[loser].budget==loser_budget,"Final result %d does not give the winner's bonus to the losing finalist" % outcome)
		check(c.world.cup_history[0].prize==25000000 and c.cups.championship_prize("champions")==25000000,"The trophy archive and UI expose the actually awarded €25M")
		cash=c.world.clubs[winner].cash
		ledger=c.world.ledger.size()
		c.cups.record(final)
		check(not c.apply_result(final,[5,0]) and c.world.clubs[winner].cash==cash and c.world.ledger.size()==ledger and c.world.cup_history.size()==1,"A final and its reward cannot be recorded twice")
		check(c.save() and c.load_slot(1) and c.world.clubs[winner].cash==cash and c.cups.championship_prize("champions")==25000000,"Final payment and trophy value survive reload")
	# Updating the game does not rewrite a historic prize or pay an old final again.
	c.world.cup_history[0].prize=6500000
	check(c.cups.championship_prize("champions")==6500000,"Already-awarded legacy trophies still show the original amount")
	fresh(); complete_season()
	check(c.world.league_prizes.size()==10,"A full season settles each of the ten leagues independently")
	var paid: Dictionary=c.world.league_prizes.duplicate(true)
	var previous_year: int=c.world.year
	check(c.next_season() and c.world.league_prizes==paid,"Rollover retains the payment archive and does not issue another award")
	check(not c.settle_league_prizes(0) and not c.world.league_prizes.has("%d:0" % (previous_year+1)),"New-season fixtures must finish before another title payment")
	check(c.valid(c.world),"The prize-aware multi-season career remains valid")
	print("CAREER PRIZES CHECK: %d checks, %d failures" % [checks,failures])
	c=null; quit(1 if failures else 0)
