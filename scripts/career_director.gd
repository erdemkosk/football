extends RefCounted
const World=preload("res://scripts/career_world.gd")
const PLANS:=["DENGELİ","HIZ & DAYANIKLILIK","BİTİRİCİLİK","OYUN KURUCU","SAVUNMA","KALECİ"]
const FOCUS:=[["control","passing","stamina"],["pace","acceleration","stamina"],["finishing","heading","balance"],["passing","control","balance"],["defending","strength","positioning"],["reflexes","handling","positioning"]]
var ref: WeakRef
var career:
	get: return ref.get_ref()
	set(value): ref=weakref(value)

static func player_fields(p: Dictionary) -> void:
	var defaults:={"development":{"plan":5 if p.keeper else 0,"xp":0.0,"gains":0,"intensity":1},"minutes":0,"recent_minutes":[],"promise":{},"concern":"","conversation_day":-99999,"academy_owner":"","promoted":false,"terms":{"signing":0,"appearance":0,"goal":0,"title":0,"release":0,"sell_on":0,"beneficiary":""}}
	for key in defaults:
		if not p.has(key): p[key]=defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]

func ensure(w: Dictionary) -> void:
	for p in w.players.values(): player_fields(p)
	if not w.has("scouts"): w.scouts=[]
	if not w.has("academy"): w.academy={}
	if not w.has("rival_bids"): w.rival_bids={}
	if not w.has("manager"): w.manager={"trust":70.0,"employed":true,"joined":w.date,"history":[],"target":0,"youth_minutes":0,"start_cash":w.clubs[w.user].cash,"last_review":0}
	if w.manager.target==0: targets(w)
	# Add missing league calendars without resetting any saved results or cup progress.
	for league in range(2,World.LEAGUES.size()):
		if not w.fixtures.any(func(f): return int(f.league)==league):
			World.append_league(w,league)
			w.season_done=false
	for id in w.clubs:
		if not w.table.has(id): w.table[id]={"p":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"pts":0}
	w.fixtures.sort_custom(func(a,b): return a.day<b.day if a.day!=b.day else a.id<b.id)
	career.training.ensure(w)

func targets(w: Dictionary) -> void:
	var c: Dictionary=w.clubs[w.user]
	var rivals: Array=w.clubs.values().filter(func(q): return q.league==c.league)
	rivals.sort_custom(func(a,b): return a.reputation>b.reputation)
	var rank:=rivals.find(c)+1
	w.manager.target=mini(rivals.size(),maxi(2,rank+2))
	w.manager.youth_minutes=0; w.manager.start_cash=c.cash; w.manager.joined=w.date; w.manager.last_review=0

func gain(p: Dictionary,xp: float,exercise_skills: Array=[]) -> void:
	if p.get("retired",false) or p.age>=30 or World.ovr(p)>=int(p.potential): return
	var d: Dictionary=p.development
	d.xp+=xp*(1.35 if p.age<=21 else .7)
	while d.xp>=100 and World.ovr(p)<int(p.potential):
		d.xp-=100
		var keys: Array=FOCUS[int(d.plan)] if exercise_skills.is_empty() else exercise_skills
		var key: String=keys[int(d.gains)%keys.size()]
		p.attributes[key]=mini(95,int(p.attributes.get(key,60))+1); d.gains+=1

func match_progress(id: String,eleven: Array,won: bool,minutes: Dictionary={}) -> void:
	var c=career
	for pid in c.world.clubs[id].roster:
		var p: Dictionary=c.player(pid); player_fields(p)
		var played: int=int(minutes.get(pid,90 if pid in eleven else 0))
		p.minutes+=played; p.recent_minutes.append(played)
		if p.recent_minutes.size()>6: p.recent_minutes.pop_front()
		gain(p,played/90.0*(8+maxf(0,p.form)*5+(3 if won else 0)))
		if id==c.world.user and p.promoted: c.world.manager.youth_minutes+=played
		if played>0:
			var bonus: int=int(p.terms.appearance)
			if bonus>0: c.transaction(id,-bonus,"Maç primi: "+p.name)
		if p.recent_minutes.size()>=4 and p.injury<=c.world.date and p.banned==0:
			var total:=0
			for value in p.recent_minutes: total+=int(value)
			var expected: int=[30,140,300][int(p.squad_role)]
			if total<expected:
				p.morale=maxf(.1,p.morale-.045); p.concern="Daha fazla süre istiyorum."
				if p.morale<.28 and not p.listed:
					p.listed=true; p.concern="Ayrılmak istiyorum."
					if id==c.world.user: c.news("TRANSFER TALEBİ",p.name+": Verilen rol ile oynadığım süre uyuşmuyor.","club")
			else: p.concern=""; p.morale=minf(1,p.morale+.02)

func daily() -> void:
	var c=career; var w: Dictionary=c.world
	for job in w.scouts:
		if job.done or job.due>w.date: continue
		job.done=true
		var owner: Dictionary=w.clubs[job.club]
		if not w.academy.has(job.club): w.academy[job.club]=[]
		for n in range(3):
			if w.academy[job.club].size()>=12: break
			var p:=World.academy_player(w,owner,job.role if job.role>=0 else (n+int(job.due))%4)
			p.club=""; p.age=16+n%3; p.academy_owner=job.club
			p.potential=mini(96,p.potential+(int(job.get("duration",30))-30)/10)
			p.erase("nationality"); World.International.nationality(p,job.nation,true)
			# A country assignment searches that nationality, not a random import.
			p.nationality=job.nation
			var serial: int=p.appearance_id
			if job.nation=="TR": p.name=World.NAMES[serial%24]+" "+World.SURNAMES[(serial/7)%12]
			else:
				var pool: Array=World.International.POOLS[job.nation]
				p.name=pool[0][serial%4]+" "+pool[1][(serial/4)%4]
			player_fields(p); w.players[p.id]=p; w.academy[job.club].append(p.id)
		if job.club==w.user: c.news("GÖZLEMCİ RAPORU",World.International.NATIONS[job.nation]+" raporu geldi. Adayları akademide inceleyebilirsin.","club")
	for p in w.players.values():
		if p.get("retired",false): continue
		player_fields(p)
		if w.date%7==0 and p.injury<=w.date:
			gain(p,[2,5,8][int(p.development.intensity)]*(1.5 if p.academy_owner!="" else 1.0))
			if p.development.intensity==2 and p.club!="": p.fitness=maxf(.4,p.fitness-.04)
		if not p.promise.is_empty() and w.date>=p.promise.due:
			var kept: bool=p.minutes-int(p.promise.start)>=int(p.promise.required)
			p.morale=clampf(p.morale+(.13 if kept else -.22),.1,1)
			p.concern="" if kept else "Verdiğiniz süre sözünü tutmadınız."
			if p.club==w.user: c.news("OYUNCU GÖRÜŞMESİ",p.name+(": Sözünüzü tuttunuz." if kept else ": Süre sözünüz tutulmadı."),"club")
			p.promise={}
	var date:=World.calendar(w.date)
	if date.day==1: review()

func scout(nation: String,role: int,duration: int) -> String:
	var c=career
	if not c.world.manager.employed: return "Önce bir kulüple anlaş."
	if not World.International.NATIONS.has(nation) or not duration in [30,60,90] or role< -1 or role>3: return "Geçersiz görev."
	if c.world.scouts.filter(func(j): return not j.done and j.club==c.world.user).size()>=3: return "Üç gözlemci de görevde."
	if c.world.academy.get(c.world.user,[]).size()>=12: return "Akademi kapasitesi 12 oyuncu."
	var cost:=duration*1500
	if c.club().cash-c.payroll(c.world.user)*2<cost or c.club().budget<cost: return "Gözlemcilik bütçesi yetersiz."
	c.transaction(c.world.user,-cost,"Gözlemci: "+nation); c.club().budget-=cost
	c.world.scouts.append({"nation":nation,"role":role,"club":c.world.user,"due":c.world.date+duration,"duration":duration,"done":false})
	c.save(); return "Gözlemci yola çıktı. Rapor: "+World.date_label(c.world.date+duration)

func promote(pid: String) -> String:
	var c=career; var p: Dictionary=c.player(pid)
	if p.academy_owner!=c.world.user or not c.world.manager.employed: return "Bu oyuncu akademinde değil."
	if c.club().roster.size()+c.contracts.outgoing(c.world.user).size()>=30: return "A takım kapasitesi 30 oyuncu."
	if c.club().cash<(c.payroll(c.world.user)+World.wage(p))*2: return "İki aylık maaş rezervi gerekli."
	c.world.academy[c.world.user].erase(pid); p.academy_owner=""; p.club=c.world.user; p.promoted=true
	p.wage=World.wage(p); p.contract=World.calendar(c.world.date).year+3; c.club().roster.append(pid); c.assign_shirt(pid)
	c.news("AKADEMİDEN A TAKIMA",p.name+" profesyonel sözleşmesini imzaladı.","club"); c.save(); return "Oyuncu A takıma katıldı."

func talk(pid: String,choice: int) -> String:
	var c=career; var p: Dictionary=c.player(pid)
	if p.club!=c.world.user or not c.world.manager.employed: return "Oyuncu kulübünde değil."
	if c.world.date-p.conversation_day<14: return "Oyuncu sözlerini sahada görmek istiyor. 14 gün sonra tekrar görüş."
	p.conversation_day=c.world.date
	var reply: String
	if choice==0:
		p.morale=clampf(p.morale+(.07 if p.form>=0 else -.02),.1,1)
		reply="Desteğiniz için teşekkür ederim." if p.form>=0 else "Önce performansımı düzeltmeliyim."
	elif choice==1:
		p.promise={"due":c.world.date+60,"start":p.minutes,"required":180}; p.morale=minf(1,p.morale+.08)
		reply="60 gün içinde en az 180 dakika bekliyorum."
	elif choice==2:
		p.squad_role=1; p.morale=maxf(.1,p.morale-.06); reply="Rotasyon rolünü kabul ediyorum; süre bulmak istiyorum."
	else:
		if c.contracts.transfer_lock(pid)!="": return c.contracts.transfer_lock(pid)
		p.listed=true; reply="Yeni kulüp arayışını değerlendireceğim."
	c.news("BİREBİR GÖRÜŞME",p.name+": "+reply,"club"); c.save(); return reply

func review() -> void:
	var c=career; var w: Dictionary=c.world; var m: Dictionary=w.manager
	if not m.employed or w.date-m.joined<60 or w.date-m.last_review<28: return
	m.last_review=w.date
	var position: int=c.standings(c.club().league).find(w.user)+1
	var played: int=w.table[w.user].p
	if played<3: return
	var delta:=clampf((int(m.target)-position)*1.6,-12,5)
	if c.club().cash<0: delta-=8
	if m.youth_minutes>=450: delta+=2
	m.trust=clampf(m.trust+delta,0,100)
	if m.trust<25:
		m.employed=false; m.history.append({"club":w.user,"day":w.date,"reason":"Görevden alındı"})
		c.news("YÖNETİM KARARI","Görevin sona erdi. Teknik direktör merkezinden yeni kulübe başvurabilirsin.","club")
	else: c.news("YÖNETİM RAPORU","Güven %d / 100 · Hedef ilk %d · Sıra %d. Akademi süresi %d / 450 dk." % [m.trust,m.target,position,m.youth_minutes],"club")

func season_review() -> void:
	var c=career; var m: Dictionary=c.world.manager
	if not m.employed: return
	var position: int=c.standings(c.club().league).find(c.world.user)+1
	var success: bool=position<=m.target
	m.trust=clampf(m.trust+(10 if success else -20),0,100)
	var amount:=int(maxi(0,c.club().cash)*(.12 if success else .04))
	c.club().budget=maxi(0,c.club().budget+(amount if success else -amount))
	c.news("SEZON DEĞERLENDİRMESİ",("Hedef gerçekleşti. Ek transfer yetkisi: " if success else "Hedef kaçırıldı. Transfer yetkisi azaltıldı: ")+c.money(amount),"finance")

func job_clubs() -> Array:
	var c=career; var ids: Array=[]
	var ceiling: int=int(c.club().reputation)+ (8 if c.world.manager.trust>=75 else 0)
	for id in c.world.clubs:
		if id!=c.world.user and c.world.clubs[id].reputation<=ceiling: ids.append(id)
	return ids

func accept_job(id: String) -> String:
	var c=career
	if c.in_match or not id in job_clubs(): return "Bu görev şu an uygun değil."
	if c.world.manager.employed and c.world.date-c.world.manager.joined<30: return "İlk 30 gün içinde kulüp değiştirilemez."
	c.world.manager.history.append({"club":c.world.user,"day":c.world.date,"reason":"Kulüp değişimi"})
	c.world.user=id; c.world.manager.employed=true; c.world.manager.trust=65.0; c.deal.clear()
	targets(c.world); c.club().lineup=c.best_eleven(id)
	c.news("YENİ İMZA",c.club().name+" ile teknik direktör sözleşmesi imzalandı.","club"); c.save(); return "Yeni kulübüne hoş geldin."
