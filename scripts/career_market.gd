extends RefCounted
## Shared pricing and player consent for human, AI, swaps and loans.
const World=preload("res://scripts/career_world.gd")
var ref: WeakRef
var career:
	get: return ref.get_ref()
	set(value): ref=weakref(value)

func value(p: Dictionary) -> int:
	var owner: String=p.get("loan",{}).get("owner",p.club)
	return World.value(p,career.world.clubs.get(owner,{}),World.calendar(career.world.date).year)

func asking_price(p: Dictionary) -> int:
	if p.club=="": return 0
	var markup := 1.02 if p.listed else 1.15+maxf(0,World.ovr(p)-75)*.015
	var fee := roundi(value(p)*markup/10000.0)*10000
	var release: int=int(p.get("terms",{}).get("release",0))
	return mini(fee,release) if release>0 else fee

func level(id: String) -> float:
	var club: Dictionary=career.world.clubs[id]
	var ratings: Array=[]
	for pid in club.roster: ratings.append(World.ovr(career.player(pid)))
	ratings.sort(); ratings.reverse()
	var total := 0.0
	for rating in ratings.slice(0,11): total+=rating
	return float(club.reputation)*.55+(total/maxi(1,mini(11,ratings.size())))*.45

func interest(p: Dictionary,buyer: String) -> Dictionary:
	var ambition := float(World.ovr(p))-6.0
	var owner: String=p.get("loan",{}).get("owner",p.club)
	if owner!="": ambition=maxf(ambition,minf(level(owner)-4.0,World.ovr(p)+3.0))
	if p.age>=31: ambition-=minf(4,(p.age-30)*1.0)
	if p.get("listed",false): ambition-=3
	var gap := maxf(0,ambition-level(buyer))
	var rare := gap>12
	var premium := 1.0+clampf(gap-4,0,8)*.10
	if rare: premium=clampf(3.0+(gap-12)*.08,3.0,5.0)
	# A player's decision is stable for this club and transfer window. Reopening
	# talks, reloading or adding one euro cannot reroll an unwilling star.
	var date := World.calendar(career.world.date)
	var random := RandomNumberGenerator.new()
	random.seed=("%s|%s|%s|%d|%s" % [p.id,buyer,owner,date.year,"winter" if date.month<7 else "summer"]).hash()
	var chance := clampf(.08-(gap-12)*.0015,.025,.08)
	var willing := not rare or random.randf()<chance
	var label := "GÖRÜŞMEYE AÇIK"
	if gap>4: label="DAHA YÜKSEK MAAŞ VE ROL BEKLİYOR"
	if rare: label="GELMESİ ÇOK ZOR · ÜST DÜZEY KULÜP İSTİYOR"
	return {"gap":gap,"rare":rare,"premium":premium,"willing":willing,"label":label}

func base_salary(p: Dictionary) -> int:
	return maxi(World.wage(p),roundi(p.wage*1.1))

func salary(p: Dictionary,buyer: String) -> int:
	return ceili(base_salary(p)*float(interest(p,buyer).premium)/500.0)*500

func wanted_role(p: Dictionary,buyer: String) -> int:
	return 2 if float(interest(p,buyer).gap)>4 or World.ovr(p)>career.strength(buyer)+3 else 1

func refusal(p: Dictionary,buyer: String,wage: int,role: int,years: int,signing: int=0) -> String:
	var intent := interest(p,buyer)
	if intent.rare and not intent.willing:
		return "Oyuncu bu dönemde daha üst seviyede bir kulüp istiyor; yüksek ücret için de kararını değiştirmiyor."
	if intent.rare:
		# Only guaranteed money counts toward the exceptional move, never
		# hypothetical goal/title bonuses or a fee paid to the selling club.
		var required := salary(p,buyer)
		if years<1 or years>3 or role!=2 or wage<required*.8 or wage+float(signing)/maxi(12,years*12)<required:
			return "Ancak olağanüstü ücretle düşünebilir: %s / ay garantili gelir, İlk 11 ve en fazla 3 yıl." % career.money(required)
	return ""

func loan_refusal(p: Dictionary,borrower: String) -> String:
	# Young reserves may step down for minutes; an elite player cannot bypass
	# permanent-transfer ambitions through a cheap loan/purchase option.
	if World.ovr(p)-8>level(borrower)+8:
		return "Oyuncu kiralık olarak da daha yüksek seviyede bir kulüpte oynamak istiyor."
	return ""
