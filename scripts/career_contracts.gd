extends RefCounted
## Legal ownership stays in loan.owner; player.club is the club fielding the player.
const World=preload("res://scripts/career_world.gd")
var career_ref: WeakRef
var career:
	get: return career_ref.get_ref() if career_ref!=null else null
	set(value): career_ref=weakref(value)

func transfer_lock(pid: String,allow_loan: bool=false) -> String:
	if not career.world.players.has(pid): return "Oyuncu bulunamadı."
	var p: Dictionary=career.player(pid)
	if p.get("retired",false): return "Oyuncu futbolu bıraktı; transfer edilemez."
	if int(p.get("retirement_year",0))>0: return "Oyuncu sezon sonunda emekli olacak; transfer ve sözleşme görüşmesi yapmıyor."
	if not allow_loan and not p.get("loan",{}).is_empty(): return "Oyuncu kiralık; bonservisi başka kulüpte."
	return ""

func outgoing(id: String) -> Array:
	var ids: Array=[]
	for p in career.world.players.values():
		if p.get("loan",{}).get("owner","")==id: ids.append(p.id)
	return ids

func incoming(id: String) -> Array:
	return career.world.clubs[id].roster.filter(func(pid): return not career.player(pid).get("loan",{}).is_empty())

func owned_count(id: String) -> int:
	return career.world.clubs[id].roster.size()-incoming(id).size()+outgoing(id).size()

func wage_cost(pid: String,id: String) -> int:
	var p: Dictionary=career.player(pid); var loan: Dictionary=p.get("loan",{})
	if p.get("retired",false): return 0
	if loan.is_empty(): return int(p.wage) if p.club==id else 0
	var share:=roundi(p.wage*loan.share/100.0)
	if p.club==id: return share
	return int(p.wage)-share if loan.owner==id else 0

func review_retirements() -> void:
	for p in career.world.players.values():
		if p.get("retired",false) or p.get("retirement_year",0)>0: continue
		if p.age+1<int(p.retirement_age): continue
		p.retirement_year=career.world.year+1; p.listed=false; p.loan_listed=false
		close_offers(p.id)
		if p.club==career.world.user or p.get("loan",{}).get("owner","")==career.world.user:
			career.news("SEZON SONUNDA VEDA",p.name+", haziran "+str(p.retirement_year)+" sonunda emekli olacağını açıkladı. Bu sezon oynamaya devam edecek; satılamaz veya kiralanamaz.","club")

func close_offers(pid: String) -> void:
	for o in career.world.offers:
		if o.player==pid: o.closed=true

func update_calendar() -> void:
	for p in career.world.players.values():
		if not p.get("loan",{}).is_empty() and p.loan.end<career.world.date: return_player(p.id)
		if p.get("retired",false) or int(p.get("retirement_year",0))==0: continue
		if career.world.date<=World.day(p.retirement_year,6,30): continue
		if not p.get("loan",{}).is_empty(): return_player(p.id)
		var old_club: String=p.club
		if old_club!="":
			career.world.clubs[old_club].roster.erase(p.id); career.world.clubs[old_club].lineup.erase(p.id)
			if old_club==career.world.user: career.news("FUTBOLA VEDA",p.name+" kariyerini noktaladı. Maaş yükü sona erdi; oyuncu arşivde korunuyor.","club")
		p.club=""; p.age+=1; p.retired=true; p.listed=false; p.loan_listed=false
		close_offers(p.id)

func end_day(term: int) -> int:
	var w: Dictionary=career.world
	if term==0 and World.calendar(w.date).month>=7: return World.day(w.year+1,1,31)
	return World.day(w.year+(2 if term==2 else 1),6,30)

func minimum_fee(pid: String,term: int) -> int:
	return maxi(1000,roundi(World.value(career.player(pid))*[.035,.06,.11][clampi(term,0,2)]/1000.0)*1000)

func loan_reason(pid: String,borrower: String,term: int=1) -> String:
	var blocked:=transfer_lock(pid)
	if blocked!="": return blocked
	var p: Dictionary=career.player(pid)
	if p.club=="": return "Serbest oyuncu kiralanamaz; sözleşme teklif et."
	if not career.window_open(): return "Kiralık oyuncu kaydı transfer döneminde yapılır."
	if career.in_match: return "Önce devam eden maçı tamamla."
	if not career.world.clubs.has(borrower) or borrower==p.club: return "Kiralayan kulüp uygun değil."
	if term<0 or term>2: return "Kiralık süresi uygun değil."
	if World.day(p.contract,6,30)<end_day(term): return "Oyuncunun kulübüyle sözleşmesi bu kiralık süresini karşılamıyor."
	if incoming(borrower).size()>=6 or outgoing(p.club).size()>=6: return "Bir kulüp aynı anda en fazla altı oyuncu kiralar veya kiraya verir."
	if career.world.clubs[borrower].roster.size()+outgoing(borrower).size()>=30: return "Kadro dolu; kiradan döneceklerle birlikte sınır 30 oyuncu."
	var roster: Array=career.world.clubs[p.club].roster
	if roster.size()<=18: return "Kulüp en az 18 kişilik kadrosunu korumalı."
	var count:=0
	for id in roster:
		if career.player(id).role==p.role: count+=1
	if count<=(1 if p.keeper else 3): return "Kulüp bu mevkide oyuncu kaybedemiyor."
	return ""

func begin(pid: String) -> Dictionary:
	var p: Dictionary=career.player(pid)
	var blocked:=loan_reason(pid,career.world.user)
	career.deal={"kind":"loan","player":pid,"seller":p.club,"renewal":false,"stage":"loan" if blocked=="" else "rejected","fee":minimum_fee(pid,1),"wage":p.wage,"years":1,"term":1,"share":75,"option":0,"role":1,"swap":"","attempts":0,"response":blocked if blocked!="" else "Süre, kiralama bedeli ve maaş paylaşımını görüşelim.","signed":false}
	return career.deal

func offer(fee: int,share: int,term: int,with_option: bool) -> String:
	var d: Dictionary=career.deal
	if d.get("kind","")!="loan" or d.stage!="loan": return "Kiralık görüşmesi kapalı."
	var p: Dictionary=career.player(d.player)
	var blocked:=loan_reason(p.id,career.world.user,term)
	if blocked!="": d.response=blocked; return blocked
	if p.club!=d.seller: d.stage="rejected"; d.response="Oyuncunun kulübü değişti."; return d.response
	var required_share:=50 if p.get("loan_listed",false) else 75
	var required_fee:=minimum_fee(p.id,term)
	d.attempts+=1; d.term=term
	if fee<required_fee or share<required_share or share>100:
		d.fee=maxi(fee,required_fee); d.share=required_share
		d.response="Karşı teklif: "+career.money(d.fee)+" kiralama bedeli ve maaşın %"+str(required_share)+" kısmı."
		if d.attempts>=4: d.stage="rejected"; d.response="Kulüp kiralık görüşmesinden çekildi."
		return d.response
	if World.ovr(p)>career.club().reputation+20: d.response="Oyuncu daha yüksek seviyede bir kulüpte oynamak istiyor."; return d.response
	var future_wages: int=career.payroll(career.world.user)+roundi(p.wage*share/100.0)
	if fee>career.club().budget or career.club().cash-fee<future_wages*2:
		d.response="Kiralama bedeli ve iki aylık maaş rezervi için bütçe yetersiz."; return d.response
	d.fee=fee; d.share=share; d.option=roundi(World.value(p)*1.2) if with_option else 0
	d.stage="sign"; d.response="Oyuncu ve kulüp şartları kabul etti. İmzadan önce kiralık koşullarını incele."
	return d.response

func sign_loan(pid: String,borrower: String,fee: int,share: int,term: int,option: int=0) -> bool:
	career.error=loan_reason(pid,borrower,term)
	if career.error!="": return false
	if fee<0 or share<0 or share>100 or option<0: career.error="Kiralık koşulları geçersiz."; return false
	var p: Dictionary=career.player(pid); var owner: String=p.club
	var taking: Dictionary=career.world.clubs[borrower]
	if fee>taking.budget or taking.cash-fee<(career.payroll(borrower)+roundi(p.wage*share/100.0))*2:
		career.error="Kiralama ve maaş rezervi için bütçe yetersiz."; return false
	p.loan={"owner":owner,"start":career.world.date,"end":end_day(term),"share":share,"fee":fee,"option":option,"shirt":p.shirt,"role":p.squad_role}
	career.world.clubs[owner].roster.erase(pid); career.world.clubs[owner].lineup.erase(pid)
	taking.roster.append(pid); p.club=borrower; p.listed=false; p.loan_listed=false
	p.arrival={"club":borrower,"day":career.world.date,"debut":false}
	career.assign_shirt(pid); close_offers(pid)
	career.transaction(borrower,-fee,"Kiralama bedeli: "+p.name); taking.budget-=fee
	career.transaction(owner,fee,"Kiralama geliri: "+p.name); career.world.clubs[owner].budget+=fee
	career.world.clubs[owner].lineup=career.selection(owner); taking.lineup=career.selection(borrower)
	career.world.deals.push_front({"player":pid,"from":owner,"to":borrower,"fee":fee,"day":career.world.date,"kind":"loan"})
	if career.world.deals.size()>80: career.world.deals.resize(80)
	career.news("KİRALIK İMZA",p.name+", "+taking.name+" kadrosuna kiralık katıldı. Dönüş: "+World.date_label(p.loan.end+1)+". Maaş payı: %"+str(share)+".","transfer")
	return true

func return_player(pid: String,recalled: bool=false) -> void:
	var p: Dictionary=career.player(pid); var loan: Dictionary=p.get("loan",{})
	if loan.is_empty(): return
	var borrower: String=p.club; var owner: String=loan.owner
	career.world.clubs[borrower].roster.erase(pid); career.world.clubs[borrower].lineup.erase(pid)
	p.club=owner; p.shirt=loan.shirt; p.squad_role=loan.role; p.loan={}
	if not pid in career.world.clubs[owner].roster: career.world.clubs[owner].roster.append(pid)
	career.assign_shirt(pid); close_offers(pid)
	if career.world.clubs[borrower].roster.size()<18: career.replenish(borrower,true)
	career.world.clubs[borrower].lineup=career.selection(borrower)
	career.world.clubs[owner].lineup=career.selection(owner)
	if career.world.user in [owner,borrower]:
		career.news("KİRALIK GERİ ÇAĞRILDI" if recalled else "KİRALIK SÜRESİ BİTTİ",p.name+", "+career.world.clubs[owner].name+" kulübüne döndü. Maaşın tamamı artık bonservis sahibi kulüpte.","transfer")

func recall_cost(pid: String) -> int:
	return maxi(5000,roundi(career.player(pid).get("loan",{}).get("fee",0)*.25))

func recall(pid: String) -> bool:
	var loan: Dictionary=career.player(pid).get("loan",{})
	if career.in_match or loan.get("owner","")!=career.world.user or not career.window_open():
		career.error="Kendi oyuncunu yalnızca transfer döneminde geri çağırabilirsin."; return false
	var cost:=recall_cost(pid); var borrower: String=career.player(pid).club
	if career.club().cash-cost< (career.payroll(career.world.user)+wage_cost(pid,borrower))*2:
		career.error="Geri çağırma bedeli ve maaşı için bütçe yetersiz."; return false
	career.transaction(career.world.user,-cost,"Kiralık geri çağırma: "+career.player(pid).name)
	career.transaction(borrower,cost,"Erken dönüş tazminatı: "+career.player(pid).name)
	return_player(pid,true)
	return career.save()

func buy_option(pid: String) -> bool:
	var p: Dictionary=career.player(pid); var loan: Dictionary=p.get("loan",{})
	career.error=transfer_lock(pid,true)
	if career.error!="": return false
	if career.in_match or loan.is_empty() or p.club!=career.world.user or loan.option<=0 or not career.window_open():
		career.error="Satın alma opsiyonu transfer döneminde kullanılabilir."; return false
	var cost: int=loan.option; var owner: String=loan.owner
	if owned_count(p.club)>=30 or cost>career.club().budget or career.club().cash-cost<(career.payroll(p.club)+wage_cost(pid,owner))*2:
		career.error="Opsiyon bedeli, kadro veya maaş bütçesi uygun değil."; return false
	career.transaction(p.club,-cost,"Satın alma opsiyonu: "+p.name); career.club().budget-=cost
	career.transaction(owner,cost,"Opsiyonla oyuncu satışı: "+p.name); career.world.clubs[owner].budget+=cost
	p.loan={}; p.contract=World.calendar(career.world.date).year+3; p.squad_role=1
	close_offers(pid)
	career.world.deals.push_front({"player":pid,"from":owner,"to":p.club,"fee":cost,"day":career.world.date,"kind":"option"})
	if career.world.deals.size()>80: career.world.deals.resize(80)
	career.news("OPSİYON KULLANILDI",p.name+" artık bonservisiyle "+career.club().name+" oyuncusu. Aynı maaşla üç yıllık sözleşme imzaladı.","transfer")
	return career.save()

func market_week() -> void:
	if not career.window_open(): return
	var random:=RandomNumberGenerator.new(); random.seed=career.world.date*173+91
	var candidates: Array=career.world.players.values().filter(func(p): return p.get("loan_listed",false) and transfer_lock(p.id)=="")
	var completed:=0
	for p in candidates:
		if p.club=="" or (p.club!=career.world.user and completed>=2): continue
		if career.world.offers.any(func(o): return o.player==p.id and not o.closed and o.expires>=career.world.date): continue
		var clubs: Array=career.world.clubs.keys()
		var first:=random.randi_range(0,clubs.size()-1)
		for offset in range(clubs.size()):
			var id: String=clubs[(first+offset)%clubs.size()]
			if id==career.world.user or loan_reason(p.id,id)!="": continue
			var buyer: Dictionary=career.world.clubs[id]
			if World.ovr(p)<career.strength(id,p.role)-3 or World.ovr(p)>buyer.reputation+16: continue
			var fee:=minimum_fee(p.id,1); var share:=75
			if fee>buyer.budget or buyer.cash-fee<(career.payroll(id)+roundi(p.wage*share/100.0))*2: continue
			if p.club==career.world.user:
				career.world.offers.push_front({"kind":"loan","player":p.id,"buyer":id,"fee":fee,"share":share,"term":1,"option":0,"expires":career.world.date+7,"closed":false,"expired":false})
				career.news("KİRALAMA TEKLİFİ",buyer.name+", "+p.name+" için sezon sonuna kadar kiralama önerdi. Maaşın %75'ini karşılayacak.","transfer")
			else:
				if sign_loan(p.id,id,fee,share,1): completed+=1
			break
