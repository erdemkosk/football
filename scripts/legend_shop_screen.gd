extends RefCounted
const Equipment=preload("res://scripts/legend_equipment.gd")
const World=preload("res://scripts/career_world.gd")
const Style=preload("res://scripts/ui_style.gd")
const Appearance=preload("res://scripts/player_appearance.gd")
var tab:=0
var selected:="club_boots"
var ids: Array=[]

func build(s) -> void:
	var c=s.game.career; Equipment.ensure(c.world)
	ids=Equipment.ITEMS.keys().filter(func(id): return Equipment.ITEMS[id].slot==("boots" if tab==0 else "support"))
	if selected not in ids: selected=ids[0]
	for i in range(3): s.button(Rect2(52+i*135,427,125,40),["KRAMPON","DESTEK","CÜZDAN"][i],func(): tab=i; s.build(),tab==i)
	if tab==2: return
	for i in range(ids.size()):
		var id: String=ids[i]
		s.button(Rect2(52,483+i*53,390,43),Equipment.ITEMS[id].name,func(): selected=id; s.build(),id==selected)
	var d: Dictionary=c.world.legend.equipment; var item: Dictionary=Equipment.ITEMS[selected]
	var owned: bool=selected in d.owned; var equipped: bool=d.equipped[item.slot]==selected
	var allowed: bool=not item.get("keeper",false) or s.game.legend.player().keeper
	var label:="KUŞANILDI" if equipped else "KALECİLER İÇİN" if not allowed else "KUŞAN" if owned else "SATIN AL & KUŞAN"
	s.button(Rect2(947,678,424,48),label,func(): s.game.legend.status=Equipment.use(c,selected); s.build(),true).disabled=equipped or not allowed or not Equipment.available(c) or (not owned and d.balance<item.price)
	if tab==1 and d.equipped.support!="":
		s.button(Rect2(491,678,424,48),"DESTEĞİ ÇIKAR",func(): s.game.legend.status=Equipment.remove_support(c); s.build()).disabled=not Equipment.available(c)

func icon(s,at: Vector2,item: Dictionary) -> void:
	var color: Color=Appearance.BOOT_COLORS[int(item.style)][0]
	var accent: Color=Appearance.BOOT_COLORS[int(item.style)][1]
	var points:=PackedVector2Array()
	if item.slot=="boots":
		for p in [Vector2(8,86),Vector2(24,65),Vector2(56,53),Vector2(65,25),Vector2(93,32),Vector2(114,65),Vector2(169,74),Vector2(184,90),Vector2(176,109),Vector2(9,109)]: points.append(at+p)
		s.draw_colored_polygon(points,color)
		s.draw_line(at+Vector2(13,108),at+Vector2(177,108),accent,7,true)
		for i in range(3): s.draw_line(at+Vector2(93+i*8,61+i*5),at+Vector2(78+i*8,67+i*5),accent,3,true)
		for x in [23,58,123,159]: s.box(Rect2(at+Vector2(x,112),Vector2(8,7)),Style.MUTE,2)
	elif item.get("keeper",false):
		s.box(Rect2(at+Vector2(57,57),Vector2(77,61)),color,18)
		for i in range(4): s.box(Rect2(at+Vector2(57+i*20,16+absi(i-1)*6),Vector2(17,60)),color,8)
		s.draw_line(at+Vector2(63,102),at+Vector2(126,102),accent,6,true)
		s.draw_line(at+Vector2(55,85),at+Vector2(34,57),color,19,true)
	elif item.has("recovery"):
		s.box(Rect2(at+Vector2(25,38),Vector2(146,83)),color,15)
		s.draw_line(at+Vector2(98,60),at+Vector2(98,99),accent,9,true)
		s.draw_line(at+Vector2(79,79),at+Vector2(117,79),accent,9,true)
	else:
		for x in [54,115]:
			s.draw_line(at+Vector2(x,46),at+Vector2(x-12,111),color,29,true)
			s.draw_circle(at+Vector2(x+4,39),23,color)
			s.draw_line(at+Vector2(x,52),at+Vector2(x-8,97),accent,5,true)

func draw(s) -> void:
	var c=s.game.career; var p: Dictionary=s.game.legend.player(); var d: Dictionary=c.world.legend.equipment
	s.box(Rect2(52,280,390,126),Style.PANEL,12)
	s.text("KİŞİSEL BAKİYEN",Vector2(76,311),13,Style.MUTE,true)
	s.text(c.money(d.balance),Vector2(76,352),33,Style.ACCENT,true)
	s.fit("MAAŞ "+c.money(p.wage)+" / ay · Her ayın 1'i",Vector2(76,382),340,14,Style.MUTE)
	s.box(Rect2(466,280,930,126),Style.PANEL,12)
	for i in range(2):
		var slot: String=["boots","support"][i]; var id: String=d.equipped[slot]; var x:=490+i*455
		s.text(["KUŞANILAN KRAMPON","KUŞANILAN DESTEK"][i],Vector2(x,311),12,Style.MUTE,true)
		s.fit("YOK" if id=="" else Equipment.ITEMS[id].name,Vector2(x,341),416,19,Style.PAPER,true)
		s.fit("Bir destek ekipmanı seçebilirsin." if id=="" else Equipment.effects(Equipment.ITEMS[id]),Vector2(x,377),416,13,Style.ACCENT)
	if tab==2:
		s.box(Rect2(52,483,1344,269),Style.PANEL,12)
		if d.journal.is_empty():
			s.text("İLK KAZANCINA DOĞRU",Vector2(79,523),22,Style.PAPER,true)
			s.paragraph("Maaşın ayın ilk günü, sözleşme primlerin hak ettiğinde yatırılır. Transferde imza parası da senindir. Bonservis kulüpler arasında ödenir.",Vector2(79,564),790,18)
		else:
			for i in range(mini(5,d.journal.size())):
				var row: Dictionary=d.journal[i]; var y:=518+i*43
				s.text(World.date_label(int(row.day)),Vector2(79,y),14,Style.MUTE)
				s.fit(row.label,Vector2(272,y),701,15)
				s.fit(("+" if row.amount>0 else "")+c.money(row.amount),Vector2(1090,y),273,19,Style.ACCENT if row.amount>0 else Style.RED,true)
		s.fit("KAZANILAN "+c.money(d.earned)+" · HARCANAN "+c.money(d.spent),Vector2(80,739),1280,12,Style.MUTE)
		return
	var item: Dictionary=Equipment.ITEMS[selected]
	s.box(Rect2(466,427,930,325),Style.PANEL,12)
	s.box(Rect2(490,452,198,168),Style.INK,10)
	icon(s,Vector2(491,461),item)
	s.fit(item.name,Vector2(714,472),650,25,Style.PAPER,true)
	s.paragraph(item.note,Vector2(714,511),631,17)
	s.fit(Equipment.effects(item),Vector2(714,581),631,17,Style.ACCENT,true)
	s.fit("SAHİP OLDUĞUN EKİPMAN" if selected in d.owned else c.money(item.price)+" · TEK SEFERLİK",Vector2(714,616),631,18,Style.PAPER,true)
	s.fit("Etki kuşanıldığında geçerli. Temel yeteneğin ve transfer değerin değişmez.",Vector2(490,653),874,13,Style.MUTE)
	if tab==0: s.fit("Bir krampon + bir destek seçebilirsin.",Vector2(491,708),424,14,Style.MUTE)
	elif d.equipped.support=="": s.fit("Tek destek yuvası · İstediğinde değiştir.",Vector2(491,708),424,14,Style.MUTE)
