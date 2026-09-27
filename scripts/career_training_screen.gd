extends RefCounted
const Catalog=preload("res://scripts/training_catalog.gd")
const World=preload("res://scripts/career_world.gd")
var selected:=0

func ready_count(s) -> int:
	var count:=0
	for i in range(s.game.career.training.data().slots.size()):
		if s.game.career.training.ready(i): count+=1
	return count

func reason(s,row: Dictionary) -> String:
	var c=s.game.career
	if row.done: return "Bu haftaki çalışma tamamlandı."
	if row.player=="" or not c.world.players.has(row.player): return "Uygun oyuncu yok. Antrenörden programı yenilemesini iste."
	var p: Dictionary=c.player(row.player)
	if p.get("retired",false): return "Oyuncu emekli oldu. Program için başka oyuncu seç."
	if p.club!=c.world.user and p.get("academy_owner","")!=c.world.user: return "Oyuncu artık kulübünde değil. Program için başka oyuncu seç."
	if p.injury>c.world.date: return "Oyuncu sakat. İyileştiğinde veya başka oyuncu seçince çalışabilir."
	if p.age>=30: return "Bu gelişim programı 30 yaş altındaki oyuncular içindir."
	if World.ovr(p)>=p.potential: return "Oyuncu mevcut gelişim potansiyeline ulaştı."
	if not c.world.manager.employed: return "Programı kullanmak için bir kulüpte görev almalısın."
	return "Oyuncu bu çalışma için hazır."

func build(s) -> void:
	var c=s.game.career; var coach=c.training; var d: Dictionary=coach.data()
	selected=clampi(selected,0,d.slots.size()-1)
	s.button_at(Rect2(52,826,260,44),"← KARİYER MERKEZİ",func(): s.go("hub"))
	s.button_at(Rect2(327,826,260,44),"GELİŞİM PLANLARI",func(): s.go("development"))
	var auto_button=s.button_at(Rect2(905,179,237,43),"OTOMATİK: "+("AÇIK" if d.automatic else "KAPALI"),func(): d.automatic=not d.automatic; c.save(); s.build())
	auto_button.tooltip_text="Açıksa, takvim ilerlediğinde hazır çalışmalar antrenör tarafından tamamlanır."
	s.button_at(Rect2(1154,179,242,43),"KALANLARI SİMÜLE ET",func(): coach.simulate(); s.build()).disabled=ready_count(s)==0
	s.button_at(Rect2(1102,826,294,44),"PROGRAMI ANTRENÖR SEÇSİN",func(): coach.refill(); s.build()).tooltip_text="Tamamlanan çalışmalar korunur; kalan yerler uygun oyuncularla doldurulur."
	for i in range(d.slots.size()):
		var row: Dictionary=d.slots[i]
		var label: String=c.player(row.player).name if c.world.players.has(row.player) else "Oyuncu seçilmedi"
		var card=s.card_at(Rect2(52,269+i*102,642,91),label,func(): selected=i; s.build(),"session",str(i))
		card.tooltip_text=label+" · "+Catalog.title(row.drill)+" · "+reason(s,row)
	var row: Dictionary=d.slots[selected]
	if row.player=="" or not c.world.players.has(row.player): return
	var candidates: Array=coach.candidates(c.world).filter(func(pid): return not d.slots.any(func(other): return other!=row and other.player==pid))
	if not row.player in candidates: candidates.push_front(row.player)
	var player_option=s.option_at(Rect2(746,334,622,46),candidates.map(func(pid): return c.player(pid).name+" · "+World.ROLES[c.player(pid).role]),candidates.find(row.player),func(v): coach.assign(selected,candidates[v],Catalog.suggested(c.player(candidates[v]),d.week)); s.build())
	player_option.disabled=row.done; player_option.set_meta("focus_key","training_player")
	var modes: Array=Catalog.options(c.player(row.player))
	var drill_option=s.option_at(Rect2(746,420,622,46),modes.map(func(value): return Catalog.title(value)),maxi(0,modes.find(row.drill)),func(v): coach.assign(selected,row.player,modes[v]); s.build())
	drill_option.disabled=row.done; drill_option.set_meta("focus_key","training_drill")
	var play=s.button_at(Rect2(746,645,302,50),"OYNA",func(): coach.start(selected),true)
	var sim=s.button_at(Rect2(1062,645,306,50),"SİMÜLE ET",func(): coach.simulate(selected); s.build())
	play.disabled=not coach.ready(selected); sim.disabled=play.disabled
	play.tooltip_text="Altı denemeyi seçtiğin oyuncuyla oyna. Notun gelişim puanına dönüşür." if not play.disabled else reason(s,row)
	sim.tooltip_text="Antrenör oyuncunun becerilerini ve bu çalışmada kazandığın en iyi notu kullanır." if not sim.disabled else reason(s,row)
	play.set_meta("focus_key","training_play"); sim.set_meta("focus_key","training_simulate")

func draw_row(card) -> void:
	var s=card.screen; var c=s.game.career; var i:=int(card.identity); var row: Dictionary=c.training.data().slots[i]
	var exists: bool=c.world.players.has(row.player)
	card.label("%02d" % (i+1),Vector2(20,39),19,s.art.MUTED)
	card.label(c.player(row.player).name if exists else "Oyuncu seçilmedi",Vector2(67,34),19,s.PAPER,null,382)
	card.label(Catalog.title(row.drill) if exists else "Antrenör programı hazırlayabilir",Vector2(67,60),13,s.MUTE,s.font,382)
	var label: String="%s · %d/100" % [Catalog.grade(row.score),row.score] if row.done else "HAZIR" if c.training.ready(i) else "BEKLİYOR"
	card.label(label,Vector2(474,36),14,s.GOLD if row.done else s.MUTE)
	card.label("+%.1f puan" % row.xp if row.done else "6 deneme",Vector2(474,60),13,s.MUTE,s.font)
	if row.done: card.draw_circle(Vector2(620,18),3,s.GOLD)

func draw(s) -> void:
	var c=s.game.career; var coach=c.training; var d: Dictionary=coach.data()
	var completed: int=d.slots.filter(func(row): return row.done).size()
	s.text("Haftalık antrenman",Vector2(52,145),32,s.PAPER,true)
	s.text("Oyuncunu seç. Çalışmasını oyna veya antrenöre bırak.",Vector2(54,190),16,s.MUTE)
	s.text("Yeni program: "+World.date_label(d.week+7),Vector2(54,218),13,s.GOLD)
	s.text("Takvim ilerleyince hazır çalışmalar tamamlanır." if d.automatic else "Çalışmalar sen oynayana veya simüle edene kadar bekler.",Vector2(905,239),11,s.MUTE)
	s.text("PROGRAMIN",Vector2(54,252),12,s.MUTE,true)
	s.text("%d / 5 tamamlandı" % completed,Vector2(473,252),15,s.GOLD,true)
	s.art.surface(s,Rect2(718,244,678,548))
	var row: Dictionary=d.slots[selected]
	s.text("ÇALIŞMA %d" % (selected+1),Vector2(746,282),12,s.GOLD,true)
	if row.player=="" or not c.world.players.has(row.player):
		s.wrapped(reason(s,row),Vector2(746,350),608,24,s.PAPER,3)
		s.wrapped("Sağlıklı, potansiyeline ulaşmamış 30 yaş altı oyuncular ve akademi adayları bu programa katılabilir.",Vector2(746,481),608,17,s.MUTE,4)
		return
	var p: Dictionary=c.player(row.player)
	s.text("OYUNCU",Vector2(746,320),12,s.MUTE,true)
	s.text("ÇALIŞMA",Vector2(746,406),12,s.MUTE,true)
	s.text("GELİŞTİRDİĞİ ÖZELLİKLER",Vector2(746,500),12,s.MUTE,true)
	s.text(Catalog.skill_labels(row.drill),Vector2(746,528),19,s.PAPER,true)
	s.wrapped(Catalog.detail(row.drill),Vector2(746,559),608,15,s.MUTE,2)
	if row.done:
		s.text("%s notu · %d / 100 · +%.1f gelişim puanı" % [Catalog.grade(row.score),row.score,row.xp],Vector2(746,614),18,s.GOLD,true)
	elif coach.ready(selected):
		var score: int=coach.simulated_score(selected)
		s.text("Antrenörün notu: %s · %d / 100" % [Catalog.grade(score),score],Vector2(746,614),17,s.GOLD,true)
	else: s.wrapped(reason(s,row),Vector2(746,598),608,14,s.art.Style.RED,2)
	s.wrapped("Her 100 gelişim puanı bir özelliği artırır. Potansiyel sınırı korunur.",Vector2(746,730),608,14,s.MUTE,2)
	s.text("%d yaş · Güç %d · Potansiyel %d" % [p.age,World.ovr(p),p.potential],Vector2(746,772),13,s.MUTE)
