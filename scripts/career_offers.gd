extends RefCounted
## Quotes and negotiation rounds live in the save, never in a UI-only counter.
const PERSONAL_INTERVAL:=21
const World=preload("res://scripts/career_world.gd")
var ref: WeakRef
var career:
	get: return ref.get_ref()
	set(value): ref=weakref(value)

func live(o: Dictionary) -> bool:
	var c=career
	return not o.get("closed",false) and o.expires>=c.world.date and c.window_open() and c.world.players.has(o.player) and c.player(o.player).club==o.get("seller",c.world.user)

func valid(w: Dictionary) -> bool:
	if not w.offers is Array or not w.get("negotiations",{}) is Dictionary: return false
	for o in w.offers:
		if not o is Dictionary: return false
		for key in ["player","buyer","fee","expires","closed"]:
			if not o.has(key): return false
		if not w.players.has(o.player) or not w.clubs.has(o.buyer): return false
		for key in ["fee","expires","rounds","wage","years","role","signing","ceiling","max_wage","max_role","max_bonus","created","last_demand"]:
			if o.has(key) and (not (o[key] is int or o[key] is float) or not is_finite(float(o[key])) or float(o[key])<0 or float(o[key])!=floor(float(o[key]))): return false
		if o.has("history") and not o.history is Array: return false
		for row in o.get("history",[]):
			if not row is Dictionary or not row.get("text",0) is String: return false
		if o.get("kind","")=="personal":
			for key in ["seller","wage","years","role","signing","max_wage","max_role","max_bonus","rounds"]:
				if not o.has(key): return false
			if not w.get("legend",0) is Dictionary or o.player!=w.legend.get("player","") or not w.clubs.has(o.seller): return false
			if o.years<1 or o.years>5 or o.role>2 or o.max_role>2 or o.rounds>3: return false
	for d in w.get("negotiations",{}).values():
		if not d is Dictionary: return false
		for key in ["player","seller","until","renewal","stage","signed","fee","wage","years","role","swap","attempts","response","terms"]:
			if not d.has(key): return false
		if not w.players.has(d.player) or not d.terms is Dictionary or not (d.until is int or d.until is float) or not is_finite(float(d.until)): return false
		for key in ["fee","wage","years","role","attempts"]:
			if not (d[key] is int or d[key] is float) or not is_finite(float(d[key])) or float(d[key])!=floor(float(d[key])) or d[key]<0: return false
		if d.years<1 or d.years>5 or d.role>2 or d.stage not in ["club","contract","sign","signed","rejected"]: return false
	return true

func active(personal: bool=false) -> Array:
	return career.world.offers.filter(func(o): return live(o) and (o.get("kind","")=="personal")==personal)

func capacity(buyer: String,wage: int) -> int:
	var c=career; var b: Dictionary=c.world.clubs[buyer]
	return maxi(0,mini(int(b.budget),int(b.cash)-(c.payroll(buyer)+wage)*2))

func competition(pid: String,buyer: String) -> int:
	var c=career; var p: Dictionary=c.player(pid); var ratings: Array=[]
	for id in c.best_eleven(buyer):
		if c.player(id).role==p.role: ratings.append(World.ovr(c.player(id)))
	return int(ratings.min()) if not ratings.is_empty() else roundi(c.strength(buyer))

func add(pid: String,buyer: String,fee: int,wage: int,role: int,personal: bool=false) -> Dictionary:
	var c=career
	if not c.window_open() or not c.world.players.has(pid) or not c.world.clubs.has(buyer) or fee<0 or wage<0 or role<0 or role>2: return {}
	if c.player(pid).club==buyer or not c.sale_allowed(pid,personal): return {}
	if personal and (not c.world.has("legend") or c.world.legend.player!=pid): return {}
	if not personal and c.market.refusal(c.player(pid),buyer,wage,role,3)!="": return {}
	if active(personal).size()>=(3 if personal else 6): return {}
	# Rejection, withdrawal and expiry all retain a two-week contact cooldown.
	for previous in c.world.offers:
		if previous.player==pid and previous.buyer==buyer and int(previous.get("created",previous.expires-7))+14>c.world.date: return {}
	if capacity(buyer,wage)<fee or c.world.clubs[buyer].roster.size()+c.contracts.outgoing(buyer).size()>=30: return {}
	var p: Dictionary=c.player(pid)
	var o:={"player":pid,"seller":p.club,"buyer":buyer,"fee":fee,"wage":wage,"role":role,"years":3,"signing":0,"created":c.world.date,"expires":c.world.date+7,"closed":false,"expired":false,"rounds":0,"history":[],"response":"Teklifimizi değerlendirebilirsiniz.","kind":"personal" if personal else "sale"}
	o.ceiling=mini(capacity(buyer,wage),maxi(fee,roundi(c.market.asking_price(p)*(1.06+clampf((World.ovr(p)-competition(pid,buyer))*.01,0,.08))/10000)*10000))
	if personal:
		var date:=World.calendar(c.world.date)
		o.expires=mini(int(c.world.date)+10,World.day(date.year,1 if date.month==1 else 8,31))
		o.reason="%d maç · %.1f form · %s için izleniyorsun." % [c.world.legend.games,c.world.legend.form,"İlk 11" if role==2 else "Rotasyon"]
		o.max_wage=ceili(minf(wage*1.3,World.wage(p)*1.9)/500.0)*500
		o.max_role=2 if World.ovr(p)>=competition(pid,buyer)-3 else 1 if World.ovr(p)>=competition(pid,buyer)-7 else 0
		o.signing=wage; o.max_bonus=wage*3
		o.response="Kulüpler bonserviste anlaştı. Maaş, süre ve beklenen rolü görüşebiliriz."
		if capacity(buyer,wage)<fee+int(o.signing): return {}
	o.history.append({"day":c.world.date,"text":"İlk teklif · "+c.money(wage)+" / ay" if personal else "İlk teklif · "+c.money(fee)})
	if personal: c.world.legend.last_offer_day=c.world.date
	c.world.offers.push_front(o)
	c.news("SANA TRANSFER TEKLİFİ" if personal else "TRANSFER TEKLİFİ",c.world.clubs[buyer].name+", "+p.name+" için "+c.money(fee)+" önerdi.","transfer")
	return o

func reply(o: Dictionary,message: String) -> String:
	o.response=message
	if not o.has("history"): o.history=[]
	o.history.append({"day":career.world.date,"text":message})
	if o.history.size()>5: o.history.pop_front()
	career.save()
	return message

func reject(o: Dictionary) -> void:
	if not live(o): return
	o.closed=true; reply(o,"Teklif reddedildi.")

func counter_sale(o: Dictionary,fee: int) -> String:
	var c=career
	if c.in_match or not live(o) or o.get("kind","") in ["loan","personal"] or c.player(o.player).club!=c.world.user: return "Bu teklif artık görüşülemiyor."
	if fee<=0: return "Bonservis pozitif olmalı."
	var ceiling:=mini(int(o.get("ceiling",roundi(c.market.asking_price(c.player(o.player))*1.12))),capacity(o.buyer,int(o.get("wage",0))))
	if ceiling<int(o.fee): o.closed=true; return reply(o,"Kulübün bütçesi değişti; teklif geri çekildi.")
	if fee<=ceiling:
		o.fee=fee; return reply(o,"Bonservis talebiniz kabul edildi: "+c.money(fee)+". Son karar sizin.")
	o.rounds=int(o.get("rounds",0))+1
	if o.rounds>=3: o.closed=true; return reply(o,"Üç turda anlaşamadık. Kulüp görüşmeden çekildi.")
	# A repeated or even higher demand cannot force a new automatic concession.
	if fee<int(o.get("last_demand",9223372036854775807)):
		o.fee=mini(ceiling,int(o.fee)+maxi(10000,roundi((ceiling-int(o.fee))*.5/10000)*10000))
	o.last_demand=fee
	return reply(o,"Talebiniz bütçemizi aşıyor. Karşı teklifimiz "+c.money(o.fee)+". Kalan tur: "+str(3-int(o.rounds))+".")

func week() -> void:
	var c=career
	if not c.window_open() or int(c.world.get("offers_week",-100))==int(c.world.date)/7: return
	c.world.offers_week=int(c.world.date)/7
	# Keep recent replies for cooldowns without growing the save indefinitely.
	c.world.offers=c.world.offers.filter(func(o): return not o.get("closed",false) and o.expires>=c.world.date or o.expires>=c.world.date-30)
	if c.world.has("legend"): personal_week(); return
	if active().size()>=6: return
	# Also scout unlisted first-team players. A bid still needs a real squad need.
	var candidates: Array=c.club().roster.filter(func(pid): return c.sale_allowed(pid) and not c.player(pid).get("loan_listed",false))
	var random:=RandomNumberGenerator.new(); random.seed=(str(c.world.year)+"|"+str(c.world.offers_week)+"|"+str(c.world.user)).hash()
	var buyers: Array=c.world.clubs.keys()
	for n in range(mini(10,candidates.size())):
		var pid: String=candidates[random.randi_range(0,candidates.size()-1)]; var p: Dictionary=c.player(pid)
		if active().any(func(o): return o.player==pid): continue
		for attempt in range(20):
			var buyer: String=buyers[random.randi_range(0,buyers.size()-1)]
			if buyer==p.club: continue
			var gap:=World.ovr(p)-competition(pid,buyer)
			if gap<1 or gap>9: continue
			var wage: int=c.market.salary(p,buyer); var role: int=c.market.wanted_role(p,buyer)
			if c.market.refusal(p,buyer,wage,role,3)!="": continue
			var fee:=roundi(c.market.value(p)*random.randf_range(.95,1.08)/10000)*10000
			if not add(pid,buyer,fee,wage,role).is_empty(): return

func personal_week() -> void:
	var c=career; var d: Dictionary=c.world.legend; var p: Dictionary=c.player(d.player)
	if d.games<3 or d.minutes<90 or d.form<5.8 or p.get("retired",false) or c.contracts.transfer_lock(p.id)!="" or not c.sale_allowed(p.id,true): return
	if c.world.date-int(d.get("transfer_day",-100))<45 or not active(true).is_empty(): return
	var last_contact: int=int(d.get("last_offer_day",-100))
	for old in c.world.offers:
		if old.get("kind","")=="personal" and old.player==p.id: last_contact=maxi(last_contact,int(old.get("created",old.expires-7)))
	if c.world.date-last_contact<PERSONAL_INTERVAL: return
	if not d.last.is_empty() and c.world.date-int(d.last.get("day",c.world.date))>60: return
	var random:=RandomNumberGenerator.new(); random.seed=(p.id+"|"+str(int(c.world.date)/7)+"|offers").hash()
	var candidates: Array=[]
	for buyer in c.world.clubs:
		if buyer==p.club: continue
		var gap:=competition(p.id,buyer)-World.ovr(p)
		# Potential alone never attracts an elite team. Minutes and form permit
		# a small step upward, including for defenders and goalkeepers.
		if gap> (7 if d.games>=10 and d.form>=7 else 4) or gap< -10: continue
		if c.market.level(buyer)>World.ovr(p)+10: continue
		candidates.append(buyer)
	for attempt in range(candidates.size()):
		var at:=random.randi_range(0,candidates.size()-1); var buyer: String=candidates.pop_at(at)
		# Changing clubs repeatedly cannot compound wages without improving ability.
		var wage:=ceili(minf(World.wage(p)*1.5,maxi(World.wage(p),int(p.wage))*clampf(1.05+(float(d.form)-6)*.06,1.0,1.22))/500)*500
		var role:=2 if World.ovr(p)>=competition(p.id,buyer) else 1
		if not add(p.id,buyer,c.market.asking_price(p),wage,role,true).is_empty(): return

func personal_status() -> String:
	var c=career; var d: Dictionary=c.world.legend
	if not c.window_open(): return "Transfer dönemi kapalı. Sonraki döneme kadar maçlarda kendini göster."
	if c.player(d.player).get("retired",false): return "Futbolculuk kariyerin tamamlandı."
	if c.world.date-int(d.get("transfer_day",-100))<45: return "Yeni takımına alışma dönemi. Önce burada kendini göster."
	if d.games<3 or d.minutes<90: return "İlgi için en az 3 maç ve toplam 90 dakika oyna."
	if d.form<5.8: return "Son formun düşük. İstikrarlı maçlarla ilgiyi yeniden artır."
	if not d.last.is_empty() and c.world.date-int(d.last.get("day",c.world.date))>60: return "Kulüpler güncel performans görmek istiyor. Yeniden süre al."
	return "Kulüpler seni izliyor. Uygun kadro, lig seviyesi ve bütçe eşleşirse teklif gelir."

func counter_personal(o: Dictionary,wage: int,years: int,role: int,bonus: int) -> String:
	var c=career
	if c.in_match or not c.training.active.is_empty() or not live(o) or o.get("kind","")!="personal": return "Görüşme kapalı."
	if wage<500 or years<1 or years>5 or role<0 or role>2 or bonus<0: return "Sözleşme koşulları geçersiz."
	if int(o.get("rounds",0))>=3: return "Pazarlık hakkın doldu; son teklifi kabul edebilir veya reddedebilirsin."
	var cap: int=o.max_wage
	var affordable: bool=capacity(o.buyer,wage)>=int(o.fee)+bonus
	var acceptable: bool=affordable and wage<=cap and role<=o.max_role and bonus<=o.max_bonus and wage+float(bonus)/(years*12)<=cap
	o.rounds+=1
	if acceptable:
		o.wage=wage; o.years=years; o.role=role; o.signing=bonus
		return reply(o,"Talebin kabul edildi. "+c.money(wage)+" / ay · "+str(years)+" yıl. İmza için son karar sende.")
	if o.rounds>=3: o.closed=true; return reply(o,"Üç turda anlaşamadık; kulüp teklifini geri çekti.")
	# Quote one affordable compromise; guaranteed money and salary share a cap.
	var next_wage:=mini(cap,maxi(int(o.wage),roundi((int(o.wage)+mini(wage,cap))*.5/500)*500))
	var next_bonus:=mini(int(o.max_bonus),mini(bonus,maxi(0,(cap-next_wage)*years*12)))
	if capacity(o.buyer,next_wage)>=int(o.fee)+next_bonus:
		o.wage=next_wage; o.signing=next_bonus
	o.years=years; o.role=mini(role,int(o.max_role))
	return reply(o,"Bu maaş ve rol paketine çıkamıyoruz. Güncel karşı teklifimizi incele. Kalan tur: "+str(3-int(o.rounds))+".")

func authorized(o: Dictionary,pid: String,buyer: String,fee: int,wage: int,years: int,role: int,bonus: int) -> bool:
	var c=career
	return c.player_mode and c.world.has("legend") and not c.in_match and c.training.active.is_empty() and c.world.legend.player==pid and o in c.world.offers and live(o) and o.get("kind","")=="personal" and o.player==pid and o.buyer==buyer and o.fee==fee and o.wage==wage and o.years==years and o.role==role and o.signing==bonus

func accept_personal(o: Dictionary) -> bool:
	var c=career
	if o.is_empty() or not authorized(o,o.player,o.buyer,o.fee,o.wage,o.years,o.role,o.signing): return false
	if not c.transfer(o.player,o.buyer,o.fee,o.wage,o.years,o.role,"",o.signing,o): return false
	c.world.user=o.buyer
	c.transaction(o.buyer,-int(o.signing),"İmza parası: "+c.player(o.player).name); c.club().budget-=int(o.signing)
	c.player(o.player).terms.signing=o.signing
	World.Equipment.credit(c.world,o.player,"signing:%s:%d" % [o.buyer,int(o.get("created",o.expires-7))],int(o.signing),"İmza parası")
	c.contracts.close_offers(o.player)
	o.response="İmzalar atıldı. Yeni kulübüne hoş geldin."
	if c.world.rival_bids.has(o.player): c.world.rival_bids[o.player].closed=true
	c.world.legend.transfer_day=c.world.date
	c.world.legend.trust=[28.0,45.0,60.0][int(o.role)]
	c.world.manager.joined=c.world.date; c.world.manager.employed=true
	c.director.targets(c.world)
	c.deal.clear(); c.fixture_id=""; c.world.pending_fixture=""
	if c.game!=null and c.game.legend.active(): c.game.legend.coach_selection()
	return c.save()

func resume(pid: String,renewal: bool) -> Dictionary:
	var c=career
	var key:=str(c.world.user)+"|"+pid+"|"+str(renewal)
	var previous: Dictionary=c.world.get("negotiations",{}).get(key,{})
	if not previous.is_empty() and previous.until>=c.world.date and previous.seller==c.player(pid).club and not previous.signed: return previous.duplicate(true)
	return {}

func remember() -> void:
	var c=career
	if c.deal.is_empty() or c.deal.get("kind","")=="loan": return
	if not c.world.has("negotiations"): c.world.negotiations={}
	for key in c.world.negotiations.keys():
		if c.world.negotiations[key].until<c.world.date: c.world.negotiations.erase(key)
	if not c.deal.has("until"): c.deal.until=c.world.date+7
	c.world.negotiations[str(c.world.user)+"|"+str(c.deal.player)+"|"+str(c.deal.renewal)]=c.deal.duplicate(true)
	c.save()

func club_quote(p: Dictionary,minimum: int,offered: int) -> int:
	var d: Dictionary=career.deal
	var discount:=.06 if p.listed else .005 if World.ovr(p)>=80 else .02
	var floor_fee:=maxi(int(d.get("rival_fee",0)),mini(minimum,ceili(minimum*(1-discount)/10000.0)*10000))
	if offered>=floor_fee: return floor_fee
	var previous: int=d.get("quote",minimum)
	if offered>=floor_fee*.8 and offered>int(d.get("last_bid",0)):
		previous=maxi(floor_fee,ceili((previous*.65+offered*.35)/10000.0)*10000)
	d.quote=previous; d.last_bid=maxi(offered,int(d.get("last_bid",0)))
	return previous
