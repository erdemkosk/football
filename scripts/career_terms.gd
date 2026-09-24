extends RefCounted
const World=preload("res://scripts/career_world.gd")
var ref: WeakRef
var career:
	get: return ref.get_ref()
	set(value): ref=weakref(value)

func begin(d: Dictionary,p: Dictionary) -> void:
	d.terms={"signing":0,"appearance":0,"goal":0,"title":0,"release":0,"sell_on":0,"beneficiary":p.club}
	d.rival=""; d.rival_fee=0; d.deadline=career.world.date+7
	if d.renewal: return
	var previous: Dictionary=career.world.rival_bids.get(p.id,{})
	if not previous.is_empty() and not previous.closed and previous.seller==p.club:
		d.rival=previous.rival; d.rival_fee=previous.fee; d.deadline=previous.deadline
		d.response="Rakip teklif: "+career.world.clubs[d.rival].name+" · "+career.money(d.rival_fee)+". Son karar: "+World.date_label(d.deadline)
		return
	# Attractive players can have a competing, funded bid. Its expiry is persistent.
	if p.age<=26 and World.ovr(p)>=70:
		for id in career.world.clubs:
			var c: Dictionary=career.world.clubs[id]
			var fee:=roundi(career.market.asking_price(p)*1.03)
			if id in [p.club,career.world.user] or c.roster.size()>=28 or c.budget<fee or c.cash-fee<career.payroll(id)*2: continue
			var salary: int=career.market.salary(p,id); var role: int=career.market.wanted_role(p,id)
			if career.market.refusal(p,id,salary,role,3)!="" or c.cash-fee<(career.payroll(id)+salary)*2: continue
			d.rival=id; d.rival_fee=fee
			career.world.rival_bids[p.id]={"seller":p.club,"rival":id,"fee":fee,"wage":salary,"role":role,"deadline":d.deadline,"closed":false}
			d.response="Rakip teklif: "+c.name+" · "+career.money(fee)+". Son karar: "+World.date_label(d.deadline)
			break

func validate(d: Dictionary) -> bool:
	var c=career; var t: Dictionary=d.get("terms",{})
	for key in ["signing","appearance","goal","title","release","sell_on"]:
		if int(t.get(key,0))<0: c.error="Sözleşme tutarları negatif olamaz."; return false
	if int(t.get("sell_on",0))>30: c.error="Sonraki satış payı en fazla %30."; return false
	if int(t.get("release",0))>0 and int(t.release)<c.market.value(c.player(d.player)):
		c.error="Serbest kalma bedeli oyuncu değerinin altında olamaz."; return false
	var cost: int=int(t.get("signing",0))+(0 if d.renewal else int(d.fee))
	if cost>c.club().budget: c.error="Bonservis ve imza parası bütçeyi aşıyor."; return false
	if d.get("rival","")!="" and c.world.date>d.deadline: c.error="Rakip teklifin karar tarihi geçti."; return false
	return true

func salary_floor(p: Dictionary,d: Dictionary,years: int) -> int:
	var base:=maxi(World.wage(p),roundi(p.wage*(1.05 if d.renewal else 1.1)))
	if not d.renewal: base=career.market.salary(p,career.world.user)
	var t: Dictionary=d.get("terms",{})
	var monthly: float=float(t.get("signing",0))/maxi(12,years*12)+float(t.get("appearance",0))*2+float(t.get("goal",0))*(.7 if p.role==3 else .2)
	return maxi(roundi(base*(.8 if not d.renewal and career.market.interest(p,career.world.user).rare else .75)),roundi(base-monthly*.7))

func sign(d: Dictionary,p: Dictionary) -> void:
	var c=career
	p.terms=d.terms.duplicate(true)
	p.paid_goals=p.goals
	if d.renewal: p.terms.beneficiary=""; p.terms.sell_on=0
	var bonus: int=p.terms.signing
	if bonus>0: c.transaction(c.world.user,-bonus,"İmza parası: "+p.name); c.club().budget-=bonus
	p.promise={}; p.concern=""; p.morale=minf(1,p.morale+.08)
	if c.world.rival_bids.has(p.id): c.world.rival_bids[p.id].closed=true

func sell_on(p: Dictionary,seller: String,fee: int) -> int:
	var c=career; var t: Dictionary=p.get("terms",{})
	var owner: String=t.get("beneficiary","")
	if owner==seller or not c.world.clubs.has(owner): return fee
	var cut:=roundi(fee*clampf(float(t.get("sell_on",0)),0,30)/100)
	if cut>0: c.transaction(owner,cut,"Sonraki satış payı: "+p.name); c.world.clubs[owner].budget+=cut
	return fee-cut

func result_bonuses(f: Dictionary) -> void:
	var c=career
	for id in [f.home,f.away]:
		var title: bool=f.has("competition") and c.world.cups[f.competition].champion==id
		for pid in c.world.clubs[id].roster:
			var p: Dictionary=c.player(pid)
			var amount: int=int(p.terms.title) if title else 0
			# A scorer's per-match delta is captured before the result is applied.
			var previous: int=p.get("paid_goals",0)
			amount+=maxi(0,int(p.goals)-previous)*int(p.terms.goal)
			p.paid_goals=p.goals
			if amount>0: c.transaction(id,-amount,"Performans primi: "+p.name)

func daily() -> void:
	var c=career; var d: Dictionary=c.deal
	for pid in c.world.rival_bids:
		var bid: Dictionary=c.world.rival_bids[pid]
		if bid.closed or c.world.date<=bid.deadline: continue
		bid.closed=true
		var p: Dictionary=c.player(pid)
		var signed: bool=p.club==bid.seller and c.transfer(pid,bid.rival,bid.fee,int(bid.get("wage",c.market.salary(p,bid.rival))),3,int(bid.get("role",c.market.wanted_role(p,bid.rival))),"")
		if not d.is_empty() and d.player==pid and not d.signed:
			d.response="Oyuncu rakip kulübün teklifini kabul etti." if signed else "Görüşmenin süresi doldu. Yeni görüşme başlatabilirsin."
			d.stage="rejected"
