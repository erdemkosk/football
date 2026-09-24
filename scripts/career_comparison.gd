extends RefCounted
var target:=""
var peer:=""
var origin:="market"
var candidates: Array=[]

func open(s,pid: String,from: String) -> void:
	target=pid; origin=from; peer=""; s.page="comparison"; s.build()

func build(s) -> void:
	var c=s.game.career; var p: Dictionary=c.player(target)
	candidates=c.club().roster.filter(func(id): return id!=target and c.player(id).keeper==p.keeper)
	candidates.sort_custom(func(a,b):
		var x: Dictionary=c.player(a); var y: Dictionary=c.player(b)
		if (x.role==p.role)!=(y.role==p.role): return x.role==p.role
		if (a in c.club().lineup)!=(b in c.club().lineup): return a in c.club().lineup
		return s.World.ovr(x)>s.World.ovr(y))
	if peer not in candidates: peer=str(candidates[0]) if not candidates.is_empty() else ""
	if peer!="":
		s.option_at(Rect2(74,184,562,44),candidates.map(func(id): return c.player(id).name),candidates.find(peer),func(v): peer=candidates[v]; s.queue_redraw())
		s.portraits.request(s.portrait_data(peer))
	s.button_at(Rect2(52,826,340,44),"← GERİ DÖN",func(): s.page=origin; s.build())
	if p.club!=c.world.user:
		s.button_at(Rect2(1014,826,382,44),"GÖRÜŞMEYE BAŞLA",func(): s.selected=target; s.negotiate(false),true).disabled=not c.window_open() or c.contracts.transfer_lock(target)!=""

func rows(c) -> Array:
	if peer=="": return []
	var a: Dictionary=c.player(peer); var b: Dictionary=c.player(target)
	var keys: Array=["pace","acceleration","control","passing","finishing","stamina"] if not b.keeper else ["reflexes","handling","positioning","passing","pace","stamina"]
	var names: Array=["HIZ","İVME","TEKNİK","PAS","ŞUT","DAYANIKLILIK"] if not b.keeper else ["REFLEKS","TOP TUTUŞU","POZİSYON","PAS","HIZ","DAYANIKLILIK"]
	var result: Array=[]
	for i in range(keys.size()): result.append({"label":names[i],"a":int(a.attributes.get(keys[i],72)),"b":int(b.attributes.get(keys[i],72))})
	result.append({"label":"KONDİSYON %","a":roundi(a.fitness*100),"b":roundi(b.fitness*100)})
	return result

func insight(c) -> String:
	var values:=rows(c)
	if values.is_empty(): return ""
	var strongest: Dictionary=values[0]; var weakest: Dictionary=values[0]
	for row in values.slice(0,6):
		if row.b-row.a>strongest.b-strongest.a: strongest=row
		if row.b-row.a<weakest.b-weakest.a: weakest=row
	var parts: Array[String]=[]
	if strongest.b>strongest.a: parts.append("%s %+d" % [strongest.label,strongest.b-strongest.a])
	if weakest.b<weakest.a: parts.append("%s %+d" % [weakest.label,weakest.b-weakest.a])
	return "ÖNE ÇIKAN FARK: "+"  /  ".join(parts) if not parts.is_empty() else "İKİ OYUNCUNUN TEMEL ÖZELLİKLERİ EŞİT"

func draw(s) -> void:
	var c=s.game.career
	s.text("KADRONLA KARŞILAŞTIR",Vector2(52,149),30,s.PAPER,true)
	s.text("KADRONDAKİ OYUNCU",Vector2(74,177),11,s.MUTE)
	s.text("İNCELEDİĞİN OYUNCU",Vector2(800,211),12,s.GOLD,true)
	s.box(Rect2(52,250,1344,547),Color("152b38"),12)
	if peer=="": s.text("Karşılaştırılacak uygun oyuncu bulunamadı.",Vector2(90,310),20,s.PAPER); return
	for side in range(2):
		var p: Dictionary=c.player(peer if side==0 else target)
		var x: float=90 if side==0 else 800
		s.draw_string(s.bold,Vector2(x,294),p.name,HORIZONTAL_ALIGNMENT_LEFT,505,24,s.PAPER)
		s.text("GENEL %d · %s · %d YAŞ" % [s.World.ovr(p),s.World.ROLES[p.role],p.age],Vector2(x,321),13,s.GOLD)
		s.text("MAAŞ "+c.money(p.wage)+" / AY",Vector2(x,345),12,s.MUTE)
	var values:=rows(c)
	for i in range(values.size()):
		var row: Dictionary=values[i]; var y: float=391+i*47
		var difference: int=row.b-row.a
		var color: Color=Color("96d7ac") if difference>0 else (Color("e9a08d") if difference<0 else s.MUTE)
		s.center(row.label,Vector2(714,y+5),11,s.MUTE)
		s.box(Rect2(102,y-9,390,7),Color("294452"),3)
		s.box(Rect2(102,y-9,390*row.a/100.0,7),s.art.BLUE,3)
		s.text(str(row.a),Vector2(531,y+3),20,s.PAPER,true)
		s.text(str(row.b),Vector2(828,y+3),20,s.PAPER,true)
		s.box(Rect2(887,y-9,333,7),Color("294452"),3)
		s.box(Rect2(887,y-9,333*row.b/100.0,7),s.GOLD,3)
		s.text("%+d" % difference if difference!=0 else "=",Vector2(1260,y+3),17,color,true)
	s.text(insight(c),Vector2(90,728),14,s.GOLD,true)
	s.text("+/− farkı: incelenen oyuncu − kadrondaki oyuncu. Kondisyon maç öncesindeki mevcut enerjidir.",Vector2(90,756),13,s.MUTE)
