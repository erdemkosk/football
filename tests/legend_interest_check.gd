extends "res://tests/legend_equipment_check.gd"
func prove_player() -> void:
	var p:=hero()
	for stat in World.Talent.STATS: p.attributes[stat]=67
	c.world.legend.games=12; c.world.legend.minutes=650; c.world.legend.form=7.6
	c.world.legend.last={"rating":7.6,"minutes":60,"trust_change":3.0,"xp":38.0,"day":c.world.date}
func run() -> void:
	fresh(); c.offers.week()
	check(c.offers.active(true).is_empty(),"High potential alone does not create personal transfer offers")
	prove_player(); c.world.legend.minutes=89; c.world.date+=7; c.offers.week()
	check(c.offers.active(true).is_empty() and c.offers.personal_status().contains("90 dakika"),"Scouting requires meaningful playing time and explains the missing requirement")
	c.world.legend.minutes=650; c.world.legend.form=5.4; c.world.date+=7; c.offers.week()
	check(c.offers.active(true).is_empty() and c.offers.personal_status().contains("düşük"),"Poor current form suppresses new interest")
	c.world.legend.form=7.6; c.world.date+=7; var rng: int=c.world.rng; c.offers.week()
	var entries: Array=c.offers.active(true)
	check(entries.size()==1 and c.world.rng==rng,"Proven form attracts one suitable offer without consuming simulation randomness")
	if entries.is_empty(): quit(1); return
	var o: Dictionary=entries[0]; var day: int=c.world.date
	check(o.expires==day+10 and o.reason.contains("12 maç") and c.offers.capacity(o.buyer,o.wage)>=o.fee+o.signing,"Offers explain sporting interest and carry affordable terms with ten days to decide")
	var unchanged: Dictionary=c.world.duplicate(true); c.offers.week()
	check(c.world==unchanged,"Reopening scouting in the same week cannot reroll offers")
	c.world.date+=7; c.offers.week()
	check(c.offers.active(true).size()==1 and c.offers.active(true)[0]==o,"Existing negotiations do not trigger a flood of new offers")
	c.offers.reject(o); c.world.date=day+14; c.offers.week()
	check(c.offers.active(true).is_empty(),"Rejection preserves the three-week global contact interval")
	c.world.legend.erase("last_offer_day")
	var count: int=c.world.offers.size(); c.save(); c.load_slot(1); c.offers.personal_week()
	check(c.world.offers.size()==count,"Reloading a legacy contact history cannot reset the contact cooldown")
	c.world.date=day+21; c.offers.week(); entries=c.offers.active(true)
	check(entries.size()==1,"A performing player can receive another offer after the cooldown")
	if entries.is_empty(): quit(1); return
	o=entries[0]; var owned: Array=wallet().owned.duplicate(); var balance: int=wallet().balance
	var buyer_cash: int=c.world.clubs[o.buyer].cash; var seller_cash: int=c.club().cash
	o.erase("created") # Older valid offers may not have the optional creation timestamp.
	check(c.offers.accept_personal(o) and wallet().balance==balance+o.signing,"Signing credits only the agreed signing bonus to the personal wallet")
	check(c.club().cash==buyer_cash-o.fee-o.signing and c.world.clubs[o.seller].cash==seller_cash+o.fee and wallet().owned==owned,"Transfer fee stays between clubs and personal possessions travel with the player")
	balance=wallet().balance
	check(not c.offers.accept_personal(o) and wallet().balance==balance and c.save() and c.load_slot(1) and wallet().balance==balance,"A contract cannot replay its bonus through repeat acceptance or reload")
	c.world.date+=7; c.offers.week()
	check(c.offers.active(true).is_empty() and c.offers.personal_status().contains("alışma"),"New signings have a meaningful settling-in period")
	fresh(); prove_player(); c.world.date=World.day(2027,1,1); c.offers.week()
	check(c.offers.active(true).is_empty() and c.offers.personal_status().contains("güncel"),"Old good form without recent football does not attract perpetual offers")
	c.world.legend.last.day=c.world.date; c.world.date=World.day(2027,2,1); c.offers.week()
	check(c.offers.active(true).is_empty() and c.offers.personal_status().contains("kapalı"),"Offers respect closed transfer windows")
	for position in [0,1,5,9]:
		fresh(position); prove_player(); c.world.date=World.day(2026,8,28); c.world.legend.last.day=c.world.date
		c.offers.week(); entries=c.offers.active(true)
		check(not entries.is_empty(),"Recent performance creates realistic interest for position "+Progress.POSITIONS[position])
		check(entries.all(func(row): return row.expires<=World.day(2026,8,31) and c.offers.competition(hero().id,row.buyer)<=World.ovr(hero())+7 and c.market.level(row.buyer)<=World.ovr(hero())+10),"Scouting fits the destination squad and cannot extend registration deadlines")
	print("LEGEND INTEREST CHECK: %d checks, %d failures" % [checks,failures]); c=null; quit(1 if failures else 0)
