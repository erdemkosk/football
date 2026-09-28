extends RefCounted
## Personal earnings and owned equipment; never changes the club's transfer budget.
const ITEMS:={
	"club_boots":{"name":"KULÜP KRAMPONU","slot":"boots","price":0,"stats":{},"style":0,"note":"İlk gününden beri senin. Dengeli, ek etkisi yok."},
	"touch":{"name":"İLK DOKUNUŞ","slot":"boots","price":1200,"stats":{"control":1,"passing":1},"style":1,"note":"Topla rahat etmek için hafif bir başlangıç."},
	"pace":{"name":"SÜRAT","slot":"boots","price":3200,"stats":{"pace":3,"acceleration":2,"control":-1},"style":5,"note":"Koşu ve ilk adım avantajı; top kontrolünde küçük bir ödün."},
	"control":{"name":"OYUN KURUCU","slot":"boots","price":3200,"stats":{"control":3,"passing":2,"pace":-1},"style":4,"note":"Yakın kontrol ve pas için; az miktarda hızdan vazgeçersin."},
	"strike":{"name":"BİTİRİCİ","slot":"boots","price":3200,"stats":{"finishing":3,"balance":1,"stamina":-1},"style":2,"note":"Vuruş ve denge desteği; uzun koşularda biraz daha yorucu."},
	"insoles":{"name":"DESTEK TABANLIĞI","slot":"support","price":1800,"stats":{"stamina":2,"balance":1},"style":3,"note":"Uzun maçlarda dayanıklılık ve denge desteği."},
	"gloves":{"name":"KALECİ ELDİVENİ","slot":"support","price":2600,"stats":{"handling":3,"reflexes":2},"style":3,"keeper":true,"note":"Top tutuşu ve reaksiyon desteği. Yalnızca kaleciler için."},
	"recovery":{"name":"TOPARLANMA SETİ","slot":"support","price":2400,"stats":{},"style":9,"recovery":0.008,"note":"Maç aralarında her gün fazladan %0,8 kondisyon yeniler."}}
const NAMES:={"pace":"Hız","acceleration":"İvmelenme","control":"Kontrol","passing":"Pas","finishing":"Şut","balance":"Denge","stamina":"Dayanıklılık","handling":"Top tutuşu","reflexes":"Refleks"}

static func ensure(w: Dictionary) -> void:
	if not w.has("legend") or w.legend.has("equipment"): return
	w.legend.equipment={"version":1,"balance":0,"earned":0,"spent":0,"owned":["club_boots"],"equipped":{"boots":"club_boots","support":""},"payments":{},"journal":[]}

static func valid(w: Dictionary) -> bool:
	if not w.has("legend"): return true
	if not w.legend is Dictionary: return false
	if not w.legend.has("equipment"): return true
	if not w.players.has(w.legend.get("player","")): return false
	var d=w.legend.equipment
	if not d is Dictionary or d.get("version",0)!=1: return false
	for key in ["balance","earned","spent"]:
		if not (d.get(key) is int) or d[key]<0: return false
	if d.balance!=d.earned-d.spent or not d.get("owned") is Array or not d.get("equipped") is Dictionary or not d.get("payments") is Dictionary or not d.get("journal") is Array: return false
	if "club_boots" not in d.owned or d.owned.size()>ITEMS.size() or d.journal.size()>30: return false
	for id in d.owned:
		if not id is String or not ITEMS.has(id) or d.owned.count(id)!=1: return false
	for slot in ["boots","support"]:
		var id=d.equipped.get(slot)
		if not id is String: return false
		if slot=="support" and id=="": continue
		if id not in d.owned or ITEMS[id].slot!=slot or (ITEMS[id].get("keeper",false) and not w.players[w.legend.player].keeper): return false
	for row in d.journal:
		if not row is Dictionary or not row.get("day") is int or not row.get("amount") is int or not row.get("label") is String: return false
	return true

static func credit(w: Dictionary,pid: String,key: String,amount: int,label: String) -> bool:
	if not w.has("legend") or w.legend.player!=pid or amount<=0 or key=="": return false
	ensure(w)
	var d: Dictionary=w.legend.equipment
	if d.payments.has(key): return false
	d.payments[key]=true; d.balance+=amount; d.earned+=amount
	entry(w,amount,label)
	return true

static func entry(w: Dictionary,amount: int,label: String) -> void:
	var rows: Array=w.legend.equipment.journal
	rows.push_front({"day":w.date,"amount":amount,"label":label})
	if rows.size()>30: rows.resize(30)

static func salary(w: Dictionary,month: String) -> void:
	if not w.has("legend"): return
	var p: Dictionary=w.players[w.legend.player]
	if p.get("retired",false) or p.club=="": return
	credit(w,p.id,"salary:"+month,int(p.wage),"Aylık maaş")

static func available(c) -> bool:
	return c.world.has("legend") and not c.in_match and c.training.active.is_empty() and not c.player(c.world.legend.player).get("retired",false)

static func use(c,id: String) -> String:
	if not available(c): return "Ekipmanını kariyer menüsünde değiştirebilirsin."
	if not ITEMS.has(id): return "Ekipman bulunamadı."
	ensure(c.world)
	var item: Dictionary=ITEMS[id]; var d: Dictionary=c.world.legend.equipment
	if item.get("keeper",false) and not c.player(c.world.legend.player).keeper: return "Bu ekipman yalnızca kaleciler için."
	if d.equipped[item.slot]==id: return "Bu ekipman zaten kuşanılmış."
	var owned: bool=id in d.owned
	if not owned and d.balance<int(item.price): return "Kişisel bakiyen yetersiz. Maaş ve primlerin cüzdanına yatırılır."
	var previous: Dictionary=d.duplicate(true)
	if not owned:
		d.balance-=int(item.price); d.spent+=int(item.price); d.owned.append(id)
		entry(c.world,-int(item.price),item.name)
	d.equipped[item.slot]=id
	if not c.save(): c.world.legend.equipment=previous; return c.error
	return item.name+(" kuşanıldı." if owned else " satın alındı ve kuşanıldı.")

static func remove_support(c) -> String:
	if not available(c): return "Ekipmanını kariyer menüsünde değiştirebilirsin."
	ensure(c.world)
	var d: Dictionary=c.world.legend.equipment; var previous: String=d.equipped.support
	d.equipped.support=""
	if not c.save(): d.equipped.support=previous; return c.error
	return "Destek ekipmanı çıkarıldı; sahip olduklarında duruyor."

static func bonuses(w: Dictionary) -> Dictionary:
	var result: Dictionary={}
	if not w.has("legend"): return result
	ensure(w)
	for id in w.legend.equipment.equipped.values():
		if id=="": continue
		for stat in ITEMS[id].stats: result[stat]=clampi(int(result.get(stat,0))+int(ITEMS[id].stats[stat]),-3,4)
	return result

static func apply(w: Dictionary,identity: Dictionary) -> void:
	if not w.has("legend") or identity.get("id",identity.get("career_id",""))!=w.legend.player or identity.get("equipment_applied",false): return
	var boosts:=bonuses(w)
	for stat in boosts: identity.attributes[stat]=clampi(int(identity.attributes[stat])+int(boosts[stat]),35,95)
	identity.equipment_applied=true

static func recover(w: Dictionary) -> void:
	if not w.has("legend"): return
	ensure(w)
	var p: Dictionary=w.players[w.legend.player]
	if p.get("retired",false): return
	for id in w.legend.equipment.equipped.values():
		if id!="": p.fitness=minf(1,float(p.fitness)+float(ITEMS[id].get("recovery",0)))

static func present(w: Dictionary,p) -> void:
	if not w.has("legend") or p.career_id!=w.legend.player: return
	ensure(w)
	var id: String=w.legend.equipment.equipped.boots
	for boot in p.boot_meshes: boot.mesh=preload("res://scripts/player_appearance.gd").boot_mesh(int(ITEMS[id].style))

static func effects(item: Dictionary) -> String:
	var parts: Array=[]
	for stat in item.stats: parts.append("%s %s%d" % [NAMES[stat],"+" if item.stats[stat]>0 else "",item.stats[stat]])
	if item.get("recovery",0)>0: parts.append("Günlük kondisyon +%0,8")
	return " · ".join(parts) if not parts.is_empty() else "Ek özellik yok"
