extends RefCounted
const Catalog=preload("res://scripts/training_catalog.gd")
const World=preload("res://scripts/career_world.gd")

func build(s) -> void:
	var c=s.game.career; var coach=c.training; var d: Dictionary=coach.data()
	s.button_at(Rect2(52,826,260,44),"← KARİYER MERKEZİ",func(): s.go("hub"))
	s.button_at(Rect2(327,826,260,44),"GELİŞİM PLANLARI",func(): s.go("development"))
	s.button_at(Rect2(891,179,238,43),"OTOMATİK: "+("AÇIK" if d.automatic else "KAPALI"),func(): d.automatic=not d.automatic; c.save(); s.build())
	s.button_at(Rect2(1144,179,252,43),"KALANLARI SİMÜLE ET",func(): coach.simulate(); s.build(),true)
	s.button_at(Rect2(1114,826,282,44),"ANTRENÖR LİSTEYİ SEÇSİN",func(): coach.refill(); s.build())
	var candidates: Array=coach.candidates(c.world)
	for i in range(d.slots.size()):
		var row: Dictionary=d.slots[i]; var y:=280+i*96
		var ids: Array=candidates.filter(func(pid): return not d.slots.any(func(other): return other!=row and other.player==pid))
		if row.player!="" and not row.player in ids and c.world.players.has(row.player): ids.push_front(row.player)
		if ids.is_empty(): continue
		var current: String=row.player if row.player in ids else ids[0]
		var player_option=s.option_at(Rect2(90,y,394,42),ids.map(func(pid): return c.player(pid).name+" · GEN "+str(World.ovr(c.player(pid)))),ids.find(current),func(v):
			coach.assign(i,ids[v],Catalog.suggested(c.player(ids[v]),d.week)); s.build())
		player_option.disabled=row.done
		var modes: Array=Catalog.options(c.player(current))
		var drill_option=s.option_at(Rect2(499,y,294,42),modes.map(func(value): return Catalog.title(value)),maxi(0,modes.find(row.drill)),func(v): coach.assign(i,current,modes[v]); s.build())
		drill_option.disabled=row.done
		var play=s.button_at(Rect2(808,y,126,42),"OYNA",func(): coach.start(i),true)
		var sim=s.button_at(Rect2(946,y,126,42),"SİMÜLE ET",func(): coach.simulate(i); s.build())
		play.disabled=not coach.ready(i); sim.disabled=not coach.ready(i)

func draw(s) -> void:
	var c=s.game.career; var d: Dictionary=c.training.data()
	s.text("HAFTALIK ANTRENMAN",Vector2(52,148),34,s.PAPER,true)
	s.text("5 ÇALIŞMA  ·  "+World.date_label(d.week)+"  /  Sonraki program: "+World.date_label(d.week+7),Vector2(54,191),14,s.GOLD)
	s.text("Oyuncunu ve çalışmasını seç. Oyna veya antrenöre bırak.",Vector2(54,217),15,s.MUTE)
	s.text("OYUNCU",Vector2(91,255),11,s.GOLD,true)
	s.text("ÇALIŞMA",Vector2(501,255),11,s.GOLD,true)
	s.text("SONUÇ / GELİŞİM",Vector2(1107,255),11,s.GOLD,true)
	for i in range(d.slots.size()):
		var row: Dictionary=d.slots[i]; var y:=271+i*96
		s.art.surface(s,Rect2(52,y,1344,85))
		s.text(str(i+1),Vector2(65,y+34),18,s.GOLD,true)
		if row.player=="" or not c.world.players.has(row.player):
			s.text("Uygun oyuncu yok · Sakatlık, yaş ve potansiyel kontrol edilir.",Vector2(92,y+35),16,s.MUTE)
			continue
		var p: Dictionary=c.player(row.player)
		s.text("%d YAŞ  ·  POT %d  ·  %s" % [p.age,p.potential,"AKADEMİ" if p.get("academy_owner","")!="" else "A TAKIM"],Vector2(92,y+72),11,s.MUTE)
		s.text(Catalog.detail(row.drill),Vector2(501,y+72),11,s.MUTE)
		if row.done:
			s.text("%s  ·  %d / 100" % [Catalog.grade(row.score),row.score],Vector2(1105,y+33),21,s.GOLD,true)
			s.text("+%.1f GELİŞİM PUANI · %s" % [row.xp,"OYNANDI" if row.manual else "OTOMATİK"],Vector2(1106,y+60),10,s.MUTE)
		else:
			s.text("HAZIR" if c.training.ready(i) else "UYGUN DEĞİL",Vector2(1106,y+34),17,s.PAPER,true)
			if c.training.ready(i): s.text("Otomatik not: "+Catalog.grade(c.training.simulated_score(i)),Vector2(1106,y+60),12,s.MUTE)
	s.text("Yüksek not daha çok puan kazandırır. 100 gelişim puanında bir özellik artar; potansiyel aşılmaz.",Vector2(54,777),14,s.PAPER)
	s.text("Otomatik açıkken takvim ilerlediğinde tamamlanır. Oynayarak kazandığın en iyi not sonraki simülasyonlarda kullanılır.",Vector2(54,800),12,s.MUTE)
