extends RefCounted
const World = preload("res://scripts/career_world.gd")
var game
var world: Dictionary = {}
var slot := 1
var save_root := "user://"
var in_match := false
var fixture_id := ""
var match_ids: Array = [[],[]]
var match_goals: Dictionary = {}
var match_recovery: Dictionary = {}
var match_participants: Array = [[],[]]
var deal: Dictionary = {}
var error := ""
var rng := RandomNumberGenerator.new()
var quick_state: Dictionary={}
var contracts:=preload("res://scripts/career_contracts.gd").new()
var director:=preload("res://scripts/career_director.gd").new()
var training:=preload("res://scripts/career_training.gd").new()
var terms:=preload("res://scripts/career_terms.gd").new()
var market:=preload("res://scripts/career_market.gd").new()
var match_minutes: Dictionary={}
var match_entered: Dictionary={}
var cups:=preload("res://scripts/career_cups.gd").new()

func _init() -> void:
	contracts.career=self; cups.career=self; director.career=self; terms.career=self; training.career=self; market.career=self

func remember_quick_match() -> void:
	if not quick_state.is_empty(): return
	quick_state={"plan":{},"alternate":game.clubs.alternate.duplicate(),"lineups":game.clubs.lineups.duplicate(true),"reserves":game.clubs.reserves.duplicate(true)}
	quick_state.difficulty=game.management.difficulty
	quick_state.level=game.management.level
	for key in World.plan(): quick_state.plan[key]=game.management.get(key)
	quick_state.plan.instructions=game.management.instructions.duplicate(true)

func club() -> Dictionary: return world.clubs[world.user]
func player(id: String) -> Dictionary: return world.players[id]
func exists() -> bool: return not world.is_empty()
func path_for(index: int) -> String: return save_root.path_join("sefc_career_%d.save" % index)
func has_save(index: int) -> bool: return FileAccess.file_exists(path_for(index)) or FileAccess.file_exists(path_for(index)+".bak")

func read_save(index: int) -> Dictionary:
	for candidate in [path_for(index),path_for(index)+".bak"]:
		var file:=FileAccess.open(candidate,FileAccess.READ)
		if file==null: continue
		if file.get_length()<8: file.close(); continue
		var bytes:=file.get_32()
		if bytes>file.get_length()-4 or bytes==0: file.close(); continue
		file.seek(0)
		var loaded=file.get_var(false); file.close()
		if valid(loaded):
			World.upgrade(loaded)
			cups.ensure(loaded)
			director.ensure(loaded)
			return {"world":loaded,"backup":candidate.ends_with(".bak")}
	return {}

func slot_summary(index: int) -> Dictionary:
	var saved:=read_save(index)
	if saved.is_empty(): return {}
	var w: Dictionary=saved.world; var c: Dictionary=w.clubs[w.user]
	return {"name":c.name,"league":c.league,"date":w.date,"year":w.year,"badge":c}

func new_career(id: String,index: int=1,settings: Dictionary={}) -> bool:
	world=World.create(); world.user=id; slot=index; in_match=false; fixture_id=""; deal.clear()
	world.match_settings=preload("res://scripts/match_settings.gd").normalized(settings)
	cups.start(world)
	director.ensure(world)
	news("YENİ DÖNEM",club().name+" teknik direktörünü karşıladı. Hedef: "+club().objective,"club")
	contracts.review_retirements()
	return save()

func valid(w) -> bool:
	if not w is Dictionary or not w.get("version",0) in [1,2,3,4,World.VERSION]: return false
	for key in ["clubs","players","fixtures","table","news","date","year","user","rng","offers","ledger","history","scorers","results","deals","next_player","pending_fixture","season_done"]:
		if not w.has(key): return false
	if not w.clubs.has(w.user) or not w.clubs.size() in [36,48,92,World.CLUB_COUNT]: return false
	if not training.valid(w): return false
	if w.has("league_prizes") and not w.league_prizes is Dictionary: return false
	if w.version>=3:
		for key in ["cups","cup_fixtures","cup_history","cups_pending"]:
			if not w.has(key): return false
		for f in w.cup_fixtures:
			for key in ["id","competition","stage","round","day","home","away","played","score","knockout","winner","penalties","leg"]:
				if not f.has(key): return false
			if not w.cups.has(f.competition) or not w.clubs.has(f.home) or not w.clubs.has(f.away) or f.home==f.away: return false
	if w.version>=4:
		for key in ["scouts","academy","manager","rival_bids"]:
			if not w.has(key): return false
		if not w.manager is Dictionary or not w.academy is Dictionary or not w.scouts is Array or not w.rival_bids is Dictionary: return false
		for key in ["trust","employed","target","joined","history","youth_minutes","last_review","start_cash"]:
			if not w.manager.has(key): return false
		for pid in w.rival_bids:
			var bid: Dictionary=w.rival_bids[pid]
			if not w.players.has(pid): return false
			for key in ["rival","seller","fee","deadline","closed"]:
				if not bid.has(key): return false
			if not w.clubs.has(bid.rival): return false
		for p in w.players.values():
			for key in ["development","minutes","recent_minutes","promise","concern","conversation_day","academy_owner","promoted","terms"]:
				if not p.has(key): return false
			if not p.development is Dictionary or not p.terms is Dictionary or not p.promise is Dictionary or not p.recent_minutes is Array: return false
			for key in ["plan","xp","gains","intensity"]:
				if not p.development.has(key): return false
			if p.development.plan<0 or p.development.plan>5 or p.development.intensity<0 or p.development.intensity>2: return false
			for key in ["signing","appearance","goal","title","release","sell_on","beneficiary"]:
				if not p.terms.has(key): return false
	for c in w.clubs.values():
		for key in ["roster","lineup","plan","cash","budget","league","name","id"]:
			if not c.has(key): return false
		if c.roster.size()<18: return false
		for id in c.roster:
			if not w.players.has(id) or w.players[id].get("club","")!=c.id: return false
		var seen: Dictionary={}
		for id in c.roster:
			if seen.has(id): return false
			seen[id]=true
	for p in w.players.values():
		var loan=p.get("loan",{})
		if not loan is Dictionary: return false
		if p.get("retired",false) and (p.get("club","")!="" or not loan.is_empty()): return false
		if p.get("club","")!="" and (not w.clubs.has(p.club) or not p.id in w.clubs[p.club].roster): return false
		if loan.is_empty(): continue
		for key in ["owner","start","end","share","fee","option","shirt","role"]:
			if not loan.has(key): return false
		if not w.clubs.has(loan.owner) or not w.clubs.has(p.club) or loan.owner==p.club: return false
		if p.id in w.clubs[loan.owner].roster or not p.id in w.clubs[p.club].roster: return false
		if loan.share<0 or loan.share>100 or loan.end<loan.start or loan.fee<0 or loan.option<0: return false
	return true

func save() -> bool:
	if not exists(): return false
	world.pending_fixture=fixture_id if in_match else ""
	var path := path_for(slot)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: error="Kariyer kaydedilemedi. Kayıt klasörüne erişilemiyor."; return false
	file.store_var(world); file.flush()
	var result := file.get_error(); file.close()
	if result!=OK: error="Kariyer kaydı yazılamadı."; return false
	# Keep a complete prior version. A failed write never replaces the current save.
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path,path+".bak")!=OK: error="Kayıt yedeği oluşturulamadı."; return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK: error="Kariyer kaydı tamamlanamadı."; return false
	error=""; return true

func load_slot(index: int) -> bool:
	var saved:=read_save(index)
	if not saved.is_empty():
		world=saved.world; slot=index; in_match=false; fixture_id=""; deal.clear(); world.pending_fixture=""
		contracts.review_retirements(); contracts.update_calendar()
		for league in range(World.LEAGUES.size()): settle_league_prizes(league)
		error="Yedek kayıt geri yüklendi." if saved.backup else ""
		return true
	error="Geçerli bir kariyer kaydı bulunamadı."; return false

func news(title: String,body: String,kind: String="league") -> void:
	world.news.push_front({"day":world.date,"title":title,"body":body,"kind":kind})
	if world.news.size()>80: world.news.resize(80)

func money(amount: int) -> String:
	if abs(amount)>=1000000: return ("€%.2f M" % (amount/1000000.0)).replace(".",",")
	var digits:=str(absi(amount)); var grouped:=""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0: grouped+="."
		grouped+=digits[i]
	return ("−" if amount<0 else "")+"€"+grouped

func transaction(id: String,amount: int,label: String) -> void:
	world.clubs[id].cash+=amount
	world.ledger.push_front({"day":world.date,"club":id,"amount":amount,"label":label})
	if world.ledger.size()>6000: world.ledger.resize(6000)

func payroll(id: String) -> int:
	var total := 0
	for pid in world.clubs[id].roster: total+=contracts.wage_cost(pid,id)
	for pid in contracts.outgoing(id): total+=contracts.wage_cost(pid,id)
	return total

func window_open() -> bool:
	var month: int=World.calendar(world.date).month
	return month in [7,8,1]

func available(pid: String) -> bool:
	var p := player(pid)
	return not p.get("retired",false) and p.banned==0 and p.injury<=world.date

func roster(id: String) -> Array:
	var ids: Array=world.clubs[id].roster.duplicate()
	ids.sort_custom(func(a,b): return player(a).role<player(b).role if player(a).role!=player(b).role else World.ovr(player(a))>World.ovr(player(b)))
	return ids

func best_eleven(id: String) -> Array:
	var c: Dictionary=world.clubs[id]
	var shape: int=c.plan.formation
	var roles: Array=[0]
	var counts: Array=preload("res://scripts/match_management.gd").LINE_COUNTS[clampi(shape,0,8)]
	for group in range(3):
		for n in range(int(counts[group])): roles.append(group+1)
	var chosen: Array=[]
	for role in roles:
		var best := -INF; var pick := ""
		for pid in c.roster:
			var p:=player(pid)
			if pid in chosen or not available(pid) or (role==0)!=(p.role==0): continue
			var score: float=World.ovr(p)+(p.fitness-1)*20+p.form*2-(12 if p.role!=role else 0)
			if score>best: best=score; pick=pid
		if pick!="": chosen.append(pick)
	return chosen

func selection(id: String) -> Array:
	var c: Dictionary=world.clubs[id]
	var base: Array=c.lineup.duplicate() if id==world.user else best_eleven(id)
	var result: Array=[]
	for pid in base:
		if pid in c.roster and available(pid) and not pid in result: result.append(pid)
	for pid in best_eleven(id):
		if result.size()>=11: break
		if not pid in result: result.append(pid)
	# A designated goalkeeper always occupies match slot zero.
	for n in range(result.size()):
		if player(result[n]).keeper:
			var old=result[0]; result[0]=result[n]; result[n]=old; break
	return result

func strength(id: String,group: int=-1) -> float:
	var total := 0.0; var count := 0
	for pid in selection(id):
		var p:=player(pid)
		if group>=0 and p.role!=group: continue
		total+=World.ovr(p)*(0.80+p.fitness*.20)+p.form*1.5+(p.morale-.7)*3; count+=1
	return total/maxi(1,count)

func standings(league: int) -> Array:
	var ids: Array=[]
	for id in world.clubs:
		if int(world.clubs[id].league)==league: ids.append(id)
	ids.sort_custom(func(a,b):
		var x: Dictionary=world.table[a]; var y: Dictionary=world.table[b]
		if x.pts!=y.pts: return x.pts>y.pts
		if x.gf-x.ga!=y.gf-y.ga: return x.gf-x.ga>y.gf-y.ga
		return x.gf>y.gf if x.gf!=y.gf else a<b)
	return ids

func next_fixture() -> Dictionary:
	if not world.get("manager",{}).get("employed",true): return {}
	for f in cups.all_fixtures():
		if not f.played and world.user in [f.home,f.away]: return f
	return {}

func advance_one() -> String:
	if not exists() or in_match or not training.active.is_empty(): return ""
	var next:=next_fixture()
	if not next.is_empty() and next.day<=world.date: return "Maç günü. Maça çık veya sonucu simüle et."
	world.date+=1
	contracts.update_calendar()
	director.daily()
	training.daily()
	terms.daily()
	for p in world.players.values(): p.fitness=minf(1,p.fitness+.055)
	var date:=World.calendar(world.date)
	if date.day==1:
		contracts.review_retirements()
		for id in world.clubs:
			var wages:=payroll(id)
			transaction(id,int(world.clubs[id].reputation*1900),"Aylık sponsor geliri")
			transaction(id,-wages,"Aylık oyuncu maaşları")
			if world.clubs[id].cash<0:
				for pid in world.clubs[id].roster: player(pid).morale=maxf(.15,player(pid).morale-.08)
		news("AYLIK HESAP",money(payroll(world.user))+" maaş ödendi. Kasa: "+money(club().cash),"finance")
		if date.month in [7,1]: news("TRANSFER DÖNEMİ AÇILDI","Kulüpler yeni oyuncularını kaydedebilir. Son gün: bu ayın sonu." if date.month==1 else "Yaz transfer dönemi ağustos sonuna kadar açık.","transfer")
		if date.month in [9,2]: news("TRANSFER DÖNEMİ KAPANDI","Kulüpler mevcut kadrolarıyla sezona devam ediyor.","transfer")
		if date.month in [1,6]:
			var expiring: Array=[]
			for pid in club().roster:
				if player(pid).contract<=date.year and contracts.transfer_lock(pid)=="": expiring.append(player(pid).name)
			if not expiring.is_empty(): news("SÖZLEŞME HATIRLATMASI",", ".join(expiring)+": sözleşmeleri haziranda bitiyor. Kadro ekranında yenileyebilirsin.","club")
	if window_open() and world.date%7==0: market_week()
	for f in cups.all_fixtures():
		if not f.played and f.day<=world.date and (not world.user in [f.home,f.away] or not world.manager.employed): simulate(f)
	for offer in world.offers: offer.expired=offer.expires<world.date
	world.season_done=cups.done()
	return ""

func advance_to_event() -> String:
	if not training.active.is_empty(): return "Önce antrenmanı bitir veya programa dön."
	var next:=next_fixture()
	if world.season_done: return "Sezon tamamlandı. Yeni sezona geçebilirsin."
	var limit: int=mini(next.day,world.date+7) if not next.is_empty() else world.date+7
	while world.date<limit:
		var previous: int=world.offers.size()
		var result:=advance_one()
		if result!="": break
		if world.offers.size()>previous: break
	save(); return "Takvim ilerledi."

func randomize_state() -> void: rng.state=world.rng
func remember_random() -> void: world.rng=rng.state

func simulate(f: Dictionary) -> void:
	if f.played: return
	randomize_state()
	var goals: Array=[0,0]
	for side in range(2):
		var id: String=f.home if side==0 else f.away
		var opponent: String=f.away if side==0 else f.home
		var own: Dictionary=world.clubs[id].plan; var other: Dictionary=world.clubs[opponent].plan
		var edge: float=(strength(id)-strength(opponent))*.009
		var tactical: float=(int(own.mentality)-1)*.025+(int(other.line_height)-1)*.022
		if int(own.tempo)==2 and int(other.line_height)==2: tactical+=.035
		var chance:=clampf(.16+edge+tactical+(.025 if side==0 else 0),.035,.43)
		for attack in range(8):
			if rng.randf()<chance: goals[side]+=1
	if cups.needs_winner(f):
		var aggregate:=cups.total_score(f,goals)
		if aggregate[0]==aggregate[1]:
			f.extra_time=true
			for side in range(2):
				for attack in range(3):
					if rng.randf()<.16: goals[side]+=1
	remember_random()
	apply_result(f,goals,{},false)

func apply_result(f: Dictionary,result: Array,scorers: Dictionary={},played: bool=false) -> bool:
	if f.played or result.size()!=2: return false
	f.played=true; f.score=result.duplicate()
	randomize_state()
	for side in range(2):
		var id: String=f.home if side==0 else f.away
		var gf: int=result[side]; var ga: int=result[1-side]
		if not f.has("competition"):
			var table: Dictionary=world.table[id]
			table.p+=1; table.gf+=gf; table.ga+=ga
			if gf>ga: table.w+=1; table.pts+=3
			elif gf==ga: table.d+=1; table.pts+=1
			else: table.l+=1
		# Choose before serving suspensions, so a banned player cannot play this fixture.
		var eleven: Array=selection(id)
		if played: eleven=match_participants[0] if id==world.user else match_participants[1]
		for pid in world.clubs[id].roster:
			var p:=player(pid)
			if p.banned>0: p.banned-=1
		for pid in eleven:
			var p:=player(pid)
			p.appearances+=1; p.form=clampf(p.form*.8+(gf-ga)*.12,-1,1)
			if p.get("arrival",{}).get("club","")==id and not p.arrival.get("debut",false): p.arrival.debut=true
			if not played: p.fitness=maxf(.35,p.fitness-(.17 if world.clubs[id].plan.pressing==2 else .11))
			p.morale=clampf(p.morale+(0.035 if gf>=ga else -.045),.1,1)
			if rng.randf()<.008: p.injury=world.date+rng.randi_range(5,15)
		if not played and not eleven.is_empty():
			var attackers: Array=eleven.filter(func(pid): return player(pid).role>=2)
			for goal in range(gf):
				if attackers.is_empty(): break
				var pid: String=attackers[rng.randi_range(0,attackers.size()-1)]
				player(pid).goals+=1; add_scorer(f,pid,1)
		director.match_progress(id,eleven,gf>ga,match_minutes if played else {})
		if side==0: transaction(id,int(45000+world.clubs[id].reputation*1200),"Maç günü hasılatı")
	for pid in scorers:
		if world.players.has(pid): player(pid).goals+=int(scorers[pid]); add_scorer(f,pid,int(scorers[pid]))
	remember_random()
	cups.record(f)
	terms.result_bonuses(f)
	world.results.push_front(f.duplicate(true))
	if world.results.size()>80: world.results.resize(80)
	if world.user in [f.home,f.away]:
		var detail: String=" · PENALTILAR %d–%d" % f.penalties if not f.get("penalties",[]).is_empty() else ""
		news("SON DÜDÜK",world.clubs[f.home].name+" %d – %d " % result+world.clubs[f.away].name+detail+" · "+cups.fixture_label(f),"match")
		if not f.has("competition"): world.round=f.round+1
	world.season_done=cups.done()
	if not f.has("competition"): settle_league_prizes(int(f.league))
	return true

func add_scorer(f: Dictionary,pid: String,count: int) -> void:
	var chart: Dictionary=world.cups[f.competition].scorers if f.has("competition") else world.scorers
	chart[pid]=int(chart.get(pid,0))+count

func simulate_next() -> bool:
	var f:=next_fixture()
	if f.is_empty() or f.day>world.date: return false
	simulate(f)
	for other in cups.all_fixtures():
		if not other.played and other.day<=world.date: simulate(other)
	return save()

func sale_allowed(pid: String) -> bool:
	if contracts.transfer_lock(pid)!="" or player(pid).get("academy_owner","")!="": return false
	var p:=player(pid)
	if p.club=="": return true
	var ids: Array=world.clubs[p.club].roster
	if ids.size()<=18: return false
	var count:=0
	for id in ids:
		if player(id).role==p.role: count+=1
	return count>(2 if p.keeper else 3)

func market_week() -> void:
	randomize_state()
	for iteration in range(3):
		var buyer: String=world.clubs.keys()[rng.randi_range(0,world.clubs.size()-1)]
		if buyer==world.user: continue
		var c: Dictionary=world.clubs[buyer]
		var team: Array=best_eleven(buyer)
		if team.is_empty(): continue
		var weakest: String=team[0]
		for pid in team:
			if World.ovr(player(pid))<World.ovr(player(weakest)): weakest=pid
		var options: Array=[]
		for pid in world.players:
			var p:=player(pid)
			if p.club==buyer or p.role!=player(weakest).role or not sale_allowed(pid): continue
			if p.get("retired",false) or p.get("loan_listed",false): continue
			if World.ovr(p)<=World.ovr(player(weakest)) or World.ovr(p)>World.ovr(player(weakest))+10: continue
			var salary: int=market.salary(p,buyer)
			if market.refusal(p,buyer,salary,market.wanted_role(p,buyer),3)!="": continue
			if market.asking_price(p)<minf(c.budget,c.cash-(payroll(buyer)+salary)*2): options.append(pid)
		if options.is_empty(): continue
		var target: String=options[rng.randi_range(0,options.size()-1)]
		var p:=player(target); var fee: int=market.asking_price(p)
		var salary: int=market.salary(p,buyer); var role: int=market.wanted_role(p,buyer)
		if p.club==world.user:
			if world.offers.any(func(o): return o.player==target and not o.get("closed",false) and o.expires>=world.date): continue
			world.offers.push_front({"player":target,"buyer":buyer,"fee":fee,"wage":salary,"role":role,"expires":world.date+7,"closed":false,"expired":false})
			news("TRANSFER TEKLİFİ",c.name+", "+p.name+" için "+money(fee)+" önerdi.","transfer")
		else: transfer(target,buyer,fee,salary,3,role,"")
	# Listed players attract bids at their level, including from smaller clubs.
	for pid in club().roster:
		var p:=player(pid)
		if not p.listed or not sale_allowed(pid): continue
		if world.offers.any(func(o): return o.player==pid and not o.closed and o.expires>=world.date): continue
		for id in world.clubs:
			if id==world.user: continue
			var buyer: Dictionary=world.clubs[id]; var bid:=roundi(market.value(p)*rng.randf_range(.88,1.07))
			if buyer.roster.size()>=28 or World.ovr(p)<buyer.reputation-4 or World.ovr(p)>buyer.reputation+12: continue
			var salary: int=market.salary(p,id); var role: int=market.wanted_role(p,id)
			if market.refusal(p,id,salary,role,3)!="": continue
			if bid>minf(buyer.budget,buyer.cash-(payroll(id)+salary)*2): continue
			world.offers.push_front({"player":pid,"buyer":id,"fee":bid,"wage":salary,"role":role,"expires":world.date+7,"closed":false,"expired":false})
			news("TRANSFER TEKLİFİ",buyer.name+", "+p.name+" için "+money(bid)+" önerdi.","transfer")
			break
	remember_random()
	contracts.market_week()

func begin_deal(pid: String,renewal: bool=false) -> Dictionary:
	var p:=player(pid)
	deal={"player":pid,"renewal":renewal,"stage":"contract" if renewal or p.club=="" else "club","fee":0 if renewal or p.club=="" else market.value(p),"wage":maxi(p.wage,World.wage(p)),"years":3,"role":1,"swap":"","attempts":0,"response":"Sizi dinliyoruz. Teklifinizi sunabilirsiniz.","signed":false}
	deal.seller=p.club
	terms.begin(deal,p)
	if not renewal and market.interest(p,world.user).gap>4:
		deal.response="Oyuncunun tercihi: "+str(market.interest(p,world.user).label).to_lower()+". Bonservis anlaşması tek başına yeterli değil."
	var blocked: String=contracts.transfer_lock(pid)
	if blocked!="": deal.stage="rejected"; deal.response=blocked
	save()
	return deal

func offer_deal(fee: int,wage: int,years: int,role: int,swap: String="") -> String:
	if deal.is_empty() or deal.signed or deal.stage=="rejected": return "Görüşme kapalı."
	if fee<0 or wage<0 or years<1 or years>5 or role<0 or role>2: return "Teklif koşulları geçersiz."
	var p:=player(deal.player)
	var blocked: String=contracts.transfer_lock(p.id)
	if blocked!="": deal.stage="rejected"; deal.response=blocked; return blocked
	if p.club!=deal.get("seller",p.club): deal.stage="rejected"; return "Oyuncunun kulübü değişti."
	if not deal.renewal and not window_open(): return "Transfer dönemi kapalı."
	deal.attempts+=1
	if deal.stage=="club":
		if not sale_allowed(p.id) and swap=="": return "Kulüp bu mevkide oyuncu kaybedemiyor. Takas öner."
		var credit:=0
		if swap!="":
			if not world.players.has(swap) or player(swap).club!=world.user or player(swap).keeper!=p.keeper: return "Takas oyuncusu uygun değil."
			if contracts.transfer_lock(swap)!="": return contracts.transfer_lock(swap)
			if market.refusal(player(swap),p.club,player(swap).wage,1,3)!="":
				deal.response="Takas oyuncusu karşı kulübe gitmeyi kabul etmiyor."; return deal.response
			credit=roundi(market.value(player(swap))*.85)
		var minimum: int=market.asking_price(p)
		minimum=roundi(minimum*(1.0-clampf(float(deal.get("terms",{}).get("sell_on",0)),0,30)*.0025))
		if int(p.get("terms",{}).get("release",0))>0: minimum=mini(minimum,int(p.terms.release))
		minimum=maxi(minimum,int(deal.get("rival_fee",0)))
		if fee+credit<minimum:
			deal.fee=maxi(0,minimum-credit); deal.response="Karşı teklif: "+money(deal.fee)+(" + oyuncu takası." if swap!="" else ".")
			if deal.attempts>=4: deal.stage="rejected"; deal.response="Kulüp görüşmeden çekildi."
			return deal.response
		if fee>minf(club().cash,club().budget): return "Bu bonservis için yeterli bütçe yok."
		deal.fee=fee; deal.swap=swap; deal.stage="contract"; deal.attempts=0
		deal.response="Kulüple anlaşıldı. Oyuncuyla maaş ve sözleşmeyi görüşelim."
		return deal.response
	if not deal.renewal and not market.interest(p,world.user).willing:
		deal.stage="rejected"; deal.response=market.refusal(p,world.user,wage,role,years)
		return deal.response
	var minimum: int=terms.salary_floor(p,deal,years)
	var wanted: int=market.wanted_role(p,world.user) if not deal.renewal else (2 if World.ovr(p)>strength(world.user)+3 else 1)
	if wage<minimum or role<wanted or years<1 or years>5:
		deal.wage=minimum; deal.role=wanted
		deal.response="Talebimiz: "+money(minimum)+" / ay, "+["Gelişim","Rotasyon","İlk 11"][wanted]+" rolü."
		if deal.attempts>=4: deal.stage="rejected"; deal.response="Oyuncu görüşmeden çekildi."
		return deal.response
	if not deal.renewal:
		var refusal: String=market.refusal(p,world.user,wage,role,years,int(deal.get("terms",{}).get("signing",0)))
		if refusal!="": deal.response=refusal; return refusal
	var cost: int=(0 if deal.renewal else int(deal.fee))+int(deal.get("terms",{}).get("signing",0))
	var future_payroll:=payroll(world.user)- (int(p.wage) if deal.renewal else 0)+wage
	if deal.swap!="": future_payroll-=int(player(deal.swap).wage)
	if club().cash-cost<future_payroll*2: return "İmza sonrası en az iki aylık maaş karşılığı kasada kalmalı."
	deal.wage=wage; deal.years=years; deal.role=role; deal.stage="sign"
	deal.response="Şartlarda anlaştık. İmzayla transfer tamamlanacak."
	return deal.response

func sign_deal() -> bool:
	if deal.is_empty() or deal.stage!="sign" or deal.signed or not world.manager.employed: return false
	var p:=player(deal.player)
	error=contracts.transfer_lock(p.id)
	if error!="": return false
	if p.club!=deal.get("seller",p.club): error="Oyuncunun kulübü değişti."; return false
	if deal.get("kind","")=="loan":
		if not contracts.sign_loan(p.id,world.user,deal.fee,deal.share,deal.term,deal.option): return false
		deal.signed=true; deal.stage="signed"; deal.response="Kiralık sözleşme imzalandı. Oyuncu artık maç kadrona alınabilir."
		return save()
	var cost: int=(0 if deal.renewal else int(deal.fee))+int(deal.get("terms",{}).get("signing",0))
	var future_wages:=payroll(world.user)+int(deal.wage)-(int(p.wage) if deal.renewal else 0)
	if deal.swap!="": future_wages-=int(player(deal.swap).wage)
	if club().cash-cost<future_wages*2: error="İmza için iki aylık maaş rezervi gerekli."; return false
	if not terms.validate(deal): return false
	if int(deal.wage)<terms.salary_floor(p,deal,int(deal.years)):
		error="Şartlar değişti; oyuncunun maaş talebini yeniden görüşmelisin."; return false
	if deal.renewal:
		if p.club!=world.user: return false
		p.wage=deal.wage; p.contract=World.calendar(world.date).year+int(deal.years); p.squad_role=deal.role
		news("SÖZLEŞME YENİLENDİ",p.name+" ile "+str(deal.years)+" yıllık anlaşma.","transfer")
	else:
		if not transfer(p.id,world.user,deal.fee,deal.wage,deal.years,deal.role,deal.swap,int(deal.get("terms",{}).get("signing",0))): return false
	terms.sign(deal,p)
	deal.signed=true; deal.stage="signed"; deal.response="İmzalar atıldı. Birlikte yeni bir sayfa."
	return save()

func transfer(pid: String,buyer: String,fee: int,wage: int,years: int,role: int,swap: String,signing: int=0) -> bool:
	if not window_open() or not world.players.has(pid) or fee<0 or wage<0: return false
	if years<1 or years>5 or role<0 or role>2 or signing<0: return false
	if contracts.transfer_lock(pid)!="": return false
	var p:=player(pid); var seller: String=p.club
	if seller==buyer or not world.clubs.has(buyer): return false
	error=market.refusal(p,buyer,wage,role,years,signing)
	if error!="": return false
	var buying: Dictionary=world.clubs[buyer]
	if fee>minf(buying.cash,buying.budget) or (buying.roster.size()+contracts.outgoing(buyer).size()>=30 and swap==""): return false
	if not sale_allowed(pid) and swap=="": return false
	if swap!="" and (seller=="" or not world.players.has(swap) or player(swap).club!=buyer or player(swap).keeper!=p.keeper): return false
	if swap!="" and contracts.transfer_lock(swap)!="": return false
	if swap!="" and market.refusal(player(swap),seller,player(swap).wage,1,3)!="":
		error="Takas oyuncusu karşı kulübe gitmeyi kabul etmiyor."; return false
	var future_wages := payroll(buyer)+wage-(int(player(swap).wage) if swap!="" else 0)
	if fee+signing>buying.budget or buying.cash-fee-signing<future_wages*2:
		error="Transfer ve iki aylık maaş rezervi için bütçe yetersiz."; return false
	if seller!="":
		world.clubs[seller].roster.erase(pid); world.clubs[seller].lineup.erase(pid)
		var net: int=terms.sell_on(p,seller,fee)
		transaction(seller,net,"Oyuncu satışı: "+p.name); world.clubs[seller].budget+=net
	if swap!="":
		var q:=player(swap); buying.roster.erase(swap); buying.lineup.erase(swap)
		world.clubs[seller].roster.append(swap); q.club=seller
	buying.roster.append(pid); p.club=buyer; p.wage=wage; p.contract=World.calendar(world.date).year+years; p.squad_role=role; p.listed=false; p.loan_listed=false
	p.arrival={"club":buyer,"day":world.date,"debut":false}
	if swap!="": player(swap).arrival={"club":seller,"day":world.date,"debut":false}
	p.terms={"signing":0,"appearance":0,"goal":0,"title":0,"release":0,"sell_on":0,"beneficiary":""}
	p.promise={}; p.concern=""; p.recent_minutes=[]
	assign_shirt(pid)
	if swap!="": assign_shirt(swap)
	transaction(buyer,-fee,"Transfer: "+p.name); buying.budget-=fee
	buying.lineup=selection(buyer)
	if seller!="": world.clubs[seller].lineup=selection(seller)
	world.deals.push_front({"player":pid,"from":seller,"to":buyer,"fee":fee,"day":world.date})
	if world.deals.size()>80: world.deals.resize(80)
	news("İMZALAR ATILDI",p.name+", "+buying.name+" kadrosuna katıldı. Bonservis: "+money(fee),"transfer")
	return true

func assign_shirt(pid: String) -> void:
	var p:=player(pid); var taken: Array=[]
	for id in world.clubs[p.club].roster:
		if id!=pid: taken.append(player(id).shirt)
	if p.shirt in taken:
		for n in range(1,100):
			if not n in taken: p.shirt=n; break

func accept_sale(index: int) -> bool:
	if index<0 or index>=world.offers.size(): return false
	var o: Dictionary=world.offers[index]
	if o.closed or o.expires<world.date or player(o.player).club!=world.user: return false
	if o.get("kind","")=="loan":
		if not contracts.sign_loan(o.player,o.buyer,o.fee,o.share,o.term,o.get("option",0)): return false
		o.closed=true; return save()
	if not transfer(o.player,o.buyer,o.fee,int(o.get("wage",market.salary(player(o.player),o.buyer))),3,int(o.get("role",market.wanted_role(player(o.player),o.buyer))),""): return false
	o.closed=true; return save()

func settle_league_prizes(league: int) -> bool:
	var key:="%d:%d" % [world.year,league]
	if not world.has("league_prizes"): world.league_prizes={}
	if world.league_prizes.has(key): return false
	var fixtures: Array=world.fixtures.filter(func(f): return int(f.league)==league)
	if fixtures.is_empty() or fixtures.any(func(f): return not f.played): return false
	var order:=standings(league)
	if order.is_empty(): return false
	var awards: Dictionary={}
	for rank in range(order.size()):
		var id: String=order[rank]
		var amount:=World.league_prize(league,rank+1,order.size())
		var label: String=World.LEAGUES[league]+(" şampiyonluk ödülü" if rank==0 else " · %d. sıra ödülü" % (rank+1))
		transaction(id,amount,label)
		world.clubs[id].budget+=roundi(amount*.8)
		awards[id]=amount
	world.league_prizes[key]={"year":world.year,"league":league,"champion":order[0],"awards":awards}
	if world.user in order:
		var position: int=order.find(world.user)+1
		var amount: int=awards[world.user]
		news("ŞAMPİYONLUK ÖDÜLÜ" if position==1 else "LİG ÖDÜLÜ",World.LEAGUES[league]+" · %d. sıra. Kasaya %s, transfer bütçesine %s eklendi." % [position,money(amount),money(roundi(amount*.8))],"finance")
	return true

func next_season() -> bool:
	if not world.season_done or not cups.done(): return false
	contracts.review_retirements()
	# Account for the off-season too; June salaries are not skipped by rollover.
	while world.date<World.day(world.year+1,6,30): advance_one()
	var top:=standings(0); var lower:=standings(1)
	var previous_league: int=club().league
	var league_champion: String=standings(previous_league)[0]
	var local_qualifiers: Array=standings(previous_league).slice(0,World.CHAMPIONS_PLACES[previous_league])
	var qualified: Array=top.slice(0,4)
	var cup_winner: String=world.cups.get("domestic",{}).get("champion",top[1])
	var super_pair: Array=[top[0],cup_winner if cup_winner!=top[0] else top[1]]
	var movement: String="ÜST LİGE YÜKSELDİN!" if world.user in lower.slice(0,3) else ("ALT LİGE DÜŞTÜN" if world.user in top.slice(15,18) else "YENİ SEZON")
	world.history.append({"year":world.year,"champion":standings(int(club().league))[0],"position":standings(int(club().league)).find(world.user)+1,"league":club().league})
	director.season_review()
	var overseas: Array=[]
	for league in range(2,World.LEAGUES.size()): overseas.append_array(standings(league).slice(0,World.CHAMPIONS_PLACES[league]))
	# Covers completed legacy seasons too, without paying a live-season award twice.
	for league in range(World.LEAGUES.size()): settle_league_prizes(league)
	for n in range(3): world.clubs[top[17-n]].league=1; world.clubs[lower[n]].league=0
	world.year+=1; world.date=World.day(world.year,7,1)
	contracts.update_calendar()
	randomize_state()
	for p in world.players.values():
		if p.get("retired",false): continue
		p.age+=1; p.goals=0; p.appearances=0; p.fitness=1; p.banned=0; p.yellow=0
		var growth: int=-1 if p.age>=32 else 0
		p.minutes=0; p.recent_minutes=[]; p.paid_goals=0
		for key in p.attributes:
			if key in ["preferred_foot","weak_foot","archetype"]: continue
			p.attributes[key]=clampi(int(p.attributes[key])+growth,35,95)
		if p.club!="" and p.contract<=world.year:
			if p.club==world.user:
				club().roster.erase(p.id); club().lineup.erase(p.id); p.club=""
				news("SÖZLEŞME SONA ERDİ",p.name+" serbest oyuncu oldu.","transfer")
			else: p.contract=world.year+2; p.wage=World.wage(p)
	remember_random()
	contracts.review_retirements()
	for c in world.clubs.values():
		replenish(c.id)
		c.lineup=selection(c.id); c.reputation=roundi(strength(c.id)); c.budget=maxi(c.budget,int(maxi(0,c.cash-payroll(c.id)*3)*.65))
		transaction(c.id,int(c.reputation*1900),"Aylık sponsor geliri")
		transaction(c.id,-payroll(c.id),"Aylık oyuncu maaşları")
	World.fixtures(world)
	cups.start(world,qualified,super_pair,overseas)
	director.targets(world)
	var qualification: String=(", ".join(local_qualifiers.map(func(id): return world.clubs[id].short)))+" Şampiyonlar Kupası'na katılıyor. " if not local_qualifiers.is_empty() else ""
	news(movement,World.LEAGUES[previous_league]+" şampiyonu: "+world.clubs[league_champion].name+". "+qualification+"Yeni fikstür açıklandı.")
	return save()

func replenish(id: String,emergency: bool=false) -> void:
	var c: Dictionary=world.clubs[id]
	var added: Array=[]
	for role in range(4):
		var count:=0
		for pid in c.roster:
			if player(pid).role==role and (not emergency or available(pid)): count+=1
		var needed: int=([2,6,6,4] if emergency else [2,7,7,6])[role]
		while count<needed:
			var p:=World.academy_player(world,c,role)
			director.player_fields(p)
			world.players[p.id]=p; c.roster.append(p.id); assign_shirt(p.id)
			added.append(p.name); count+=1
	if id==world.user and not added.is_empty():
		news("ALTYAPIDAN A TAKIMA",str(added.size())+" genç oyuncu kadroya katıldı. "+("Eksikler nedeniyle maç kadrosuna alındılar." if emergency else "Kadro ekranından gelişimlerini ve sözleşmelerini görebilirsin."),"club")

func capture_goal(team: int,kicker: int) -> void:
	if not in_match or kicker<0: return
	var p=game.players[kicker]
	if p.team==team and p.career_id!="": match_goals[p.career_id]=int(match_goals.get(p.career_id,0))+1

func prepare_match() -> bool:
	var f:=next_fixture()
	if f.is_empty() or f.day>world.date: return false
	remember_quick_match()
	var opponent: String=f.away if f.home==world.user else f.home
	match_ids=[[],[]]; match_goals.clear(); match_recovery.clear()
	game.clubs.career_clubs=[club().duplicate(true),world.clubs[opponent].duplicate(true)]
	game.clubs.career_rosters=[[],[]]
	for side in range(2):
		var id: String=world.user if side==0 else opponent
		var eligible: Array=world.clubs[id].roster.filter(func(pid): return available(pid))
		if eligible.size()<18 or not eligible.any(func(pid): return player(pid).keeper): replenish(id,true)
		var chosen:=selection(id)
		if chosen.size()!=11: error="Maç için uygun 11 oyuncu bulunamadı."; game.clubs.clear_career(); return false
		var reserves: Array=[]
		var pool: Array=roster(id).filter(func(pid): return not pid in chosen and available(pid))
		pool.sort_custom(func(a,b): return World.ovr(player(a))*player(a).fitness>World.ovr(player(b))*player(b).fitness)
		for role in [0,1,1,2,2,3,3]:
			for pid in pool:
				if player(pid).role==role and not pid in reserves: reserves.append(pid); break
		for pid in pool:
			if reserves.size()>=7: break
			if not pid in reserves: reserves.append(pid)
		chosen.append_array(reserves)
		if chosen.size()<18: error="Maç kadrosu için 18 uygun oyuncu gerekli."; game.clubs.clear_career(); return false
		match_ids[side]=chosen
		for pid in chosen:
			var identity: Dictionary=player(pid).duplicate(true)
			for stat in ["control","passing","finishing","positioning"]: identity.attributes[stat]=clampi(roundi(identity.attributes[stat]+(identity.morale-.7)*4),35,95)
			game.clubs.career_rosters[side].append(identity)
		game.clubs.lineups[side]=range(11); game.clubs.reserves[side]=range(11,18)
		game.clubs.alternate[side]=false
	var first:=Color(club().primary); var second:=Color(world.clubs[opponent].primary)
	if Vector3(first.r-second.r,first.g-second.g,first.b-second.b).length()<.4: game.clubs.alternate[1]=true
	apply_plan(club().plan)
	game.management.level=world.match_settings.get("level",preload("res://scripts/match_settings.gd").TIER_LEVEL[world.match_settings.difficulty])
	game.clubs.apply()
	in_match=true; fixture_id=f.id
	cups.extra_phase=0
	game.state="setup"; game.ball.freeze=true
	game.frontend.open_tactics(true)
	save(); return true

func apply_plan(p: Dictionary) -> void:
	for key in ["formation","mentality","pressing","line_height","width","tempo","runs","fullbacks","anchor"]: game.management.set(key,p.get(key,1))
	var orders: Variant=p.get("instructions",{})
	game.management.instructions=orders.duplicate(true) if orders is Dictionary else {}

func match_started() -> void:
	if not in_match: return
	match_participants=[[],[]]; match_recovery.clear(); match_minutes.clear(); match_entered.clear()
	for side in range(2):
		for i in range(11):
			var p=game.players[side*11+i]
			if p.career_id!="":
				p.energy=player(p.career_id).fitness; match_participants[side].append(p.career_id); match_entered[p.career_id]=0.0
				game.broadcast.debut(p)
		match_ids[side]=[]
		for n in game.clubs.lineups[side]+game.clubs.reserves[side]: match_ids[side].append(game.clubs.career_rosters[side][n].id)
	club().lineup=match_ids[0].slice(0,11)
	save()

func remember_player(p) -> void:
	if not in_match or p.career_id=="": return
	if match_entered.has(p.career_id):
		match_minutes[p.career_id]=int(match_minutes.get(p.career_id,0))+maxi(0,roundi(game.match_time/game.LENGTH*90-float(match_entered[p.career_id])))
		match_entered.erase(p.career_id)
	match_recovery[p.career_id]={"fitness":maxf(.35,p.energy+.14),"red":p.dismissed,"yellow":p.yellow_cards}

func enter_player(p) -> void:
	if not in_match or p.career_id=="": return
	p.energy=player(p.career_id).fitness
	game.broadcast.debut(p)
	match_entered[p.career_id]=game.match_time/game.LENGTH*90
	if not p.career_id in match_participants[p.team]: match_participants[p.team].append(p.career_id)

func finish_match() -> bool:
	if not in_match: return false
	var f: Dictionary={}
	for item in cups.all_fixtures():
		if item.id==fixture_id: f=item; break
	if f.is_empty(): return false
	var result: Array=game.score.duplicate() if f.home==world.user else [game.score[1],game.score[0]]
	for p in game.players: remember_player(p)
	if not apply_result(f,result,match_goals,true): return false
	if f.has("competition"):
		game.ending_reason=("PENALTILAR %d–%d · " % (f.penalties if f.home==world.user else [f.penalties[1],f.penalties[0]])) if not f.penalties.is_empty() else ""
		if f.winner!="": game.ending_reason+=world.clubs[f.winner].short+(" KUPAYI KAZANDI" if world.cups[f.competition].champion!="" else " TUR ATLADI")
		elif f.get("leg",1)==1 and f.get("tie","")!="": game.ending_reason="İLK MAÇ · TUR RÖVANŞTA BELİRLENECEK"
	for p in game.players: remember_player(p)
	for pid in match_recovery:
		var identity:=player(pid); var record: Dictionary=match_recovery[pid]
		identity.fitness=minf(identity.fitness,record.fitness)
		if record.red: identity.banned=1
		elif record.yellow>0:
			identity.yellow+=1
			if identity.yellow>=4: identity.banned=1; identity.yellow=0
	for other in cups.all_fixtures():
		if not other.played and other.day<=world.date: simulate(other)
	in_match=false; fixture_id=""; save()
	game.finale.after_result(f)
	return true

func detach() -> void:
	game.finale.reset()
	in_match=false; fixture_id=""; match_ids=[[],[]]
	game.clubs.clear_career()
	if not quick_state.is_empty():
		apply_plan(quick_state.plan)
		game.management.level=quick_state.get("level",preload("res://scripts/match_settings.gd").TIER_LEVEL[clampi(int(quick_state.get("difficulty",1)),0,2)])
		game.clubs.alternate=quick_state.alternate; game.clubs.lineups=quick_state.lineups; game.clubs.reserves=quick_state.reserves
		quick_state.clear()
