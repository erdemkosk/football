extends RefCounted
const UI=preload("res://scripts/ui_style.gd")
const Catalog=preload("res://scripts/training_catalog.gd")
const STEPS={
	"free":["Pas açısı oluştur","Arkadaşına pas ver","Şut açısına koş"],
	"cross":["Kanattan topu kaldır","Ceza sahasına koş","Kafa veya voleyle bitir"],
	"free_kick":["Köşeyi hedefle","Barajı aşacak falsoyu ayarla","Gücünü kontrollü bırak"],
	"duel":["Savunmacıyı üstüne çek","Yaklaşırken yön değiştir","Boşluğa hızlan"],
	"slalom":["İlk kapıya yönel","Topu yakınında tut","Kapıları sırayla geç"],
	"passing":["Hedef kapıyı bul","Ayağını ve yönünü ayarla","Pası kapının içinden geçir"],
	"shooting":["Köşeye nişan al","Dengeni koru","Şut gücünü ayarla"],
	"crossing":["Kanatta alan bul","Hedef bölgeye yönel","Havadan orta aç"],
	"control":["Karşılama alanına koş","Pası kontrol et","Topla çıkış kapısından geç"],
	"penalty":["Köşeyi seç","Gücü ayarla","Düdükten sonra vur"],
	"defending":["Rakibe kontrollü yaklaş","Top açılınca müdahale et","Topu üç saniye koru"],
	"distribution":["Hedef kapıya bak","Uzun pas yönünü ayarla","Topu kapıya gönder"]}
var elapsed:=0.0
var paused:=false
var selected:=-1

func update(s,delta: float) -> void:
	if selected!=s.selected: selected=s.selected; elapsed=0; paused=false
	if not paused and not s.game.experience.reduce_motion: elapsed=fmod(elapsed+delta,6.0)
	s.demo_button.text="SONRAKİ ADIM →" if s.game.experience.reduce_motion else ("▶ GÖSTERİMİ OYNAT" if paused else "Ⅱ GÖSTERİMİ DURAKLAT")
	s.queue_redraw()

func toggle(s) -> void:
	if s.game.experience.reduce_motion: elapsed=fmod(elapsed+2,6)
	else: paused=not paused

func route(mode: String) -> PackedVector2Array:
	match mode:
		"slalom": return PackedVector2Array([Vector2(.5,.89),Vector2(.31,.71),Vector2(.66,.54),Vector2(.32,.37),Vector2(.66,.20),Vector2(.5,.09)])
		"duel": return PackedVector2Array([Vector2(.48,.87),Vector2(.48,.60),Vector2(.69,.48),Vector2(.66,.18)])
		"defending": return PackedVector2Array([Vector2(.36,.74),Vector2(.49,.51),Vector2(.59,.64),Vector2(.68,.77)])
		"control": return PackedVector2Array([Vector2(.22,.78),Vector2(.44,.48),Vector2(.44,.48),Vector2(.77,.25)])
		"cross","crossing": return PackedVector2Array([Vector2(.87,.80),Vector2(.86,.54),Vector2(.68,.29),Vector2(.46,.22),Vector2(.5,.05) if mode=="cross" else Vector2(.46,.22)])
		"free_kick": return PackedVector2Array([Vector2(.5,.82),Vector2(.61,.56),Vector2(.68,.32),Vector2(.6,.06)])
		"free": return PackedVector2Array([Vector2(.5,.83),Vector2(.26,.58),Vector2(.72,.38),Vector2(.55,.07)])
		"distribution": return PackedVector2Array([Vector2(.5,.93),Vector2(.60,.67),Vector2(.70,.39),Vector2(.77,.17)])
		"passing": return PackedVector2Array([Vector2(.28,.81),Vector2(.39,.64),Vector2(.56,.43),Vector2(.75,.20)])
	return PackedVector2Array([Vector2(.5,.8),Vector2(.5,.8),Vector2(.6,.45),Vector2(.63,.06)])

func draw(s) -> void:
	var mode: String=Catalog.MODES[s.selected]; var step:=mini(2,int(elapsed/2))
	s.box(Rect2(800,204,586,540),UI.PANEL,12,UI.LINE)
	s.text("HAREKETİ GÖR · SAHADA DENE",Vector2(827,236),12,UI.ACCENT,true)
	UI.fit(s,s.bold,Catalog.TITLES[s.selected],Vector2(827,271),531,27,UI.PAPER)
	s.wrapped(Catalog.DETAILS[s.selected],Vector2(827,300),526,15,UI.MUTE,2)
	var field:=Rect2(827,340,532,272)
	s.box(field,Color("183d38"),9)
	for i in range(8):
		if i%2==0: s.draw_rect(Rect2(field.position+Vector2(0,i*34),Vector2(532,34)),Color(1,1,1,.024))
	s.draw_rect(field.grow(-12),Color("61867a"),false,1)
	s.draw_rect(Rect2(1013,352,160,62),Color("61867a"),false,1)
	s.draw_rect(Rect2(1056,338,74,15),UI.PAPER,false,2)
	s.draw_arc(Vector2(1093,413),39,0,PI,28,Color("61867a"),1,true)
	var points:=route(mode)
	for i in range(points.size()): points[i]=field.position+points[i]*field.size
	for i in range(1,points.size()): s.draw_dashed_line(points[i-1],points[i],Color(UI.PAPER,.5),2,6,true)
	if mode in ["slalom","passing","control","distribution"]:
		for i in range(1,points.size()):
			for offset in [-15,15]:
				var at: Vector2=points[i]+Vector2(offset,0)
				s.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-7),at+Vector2(-6,5),at+Vector2(6,5)]),UI.GOLD)
	if mode in ["duel","defending","free_kick"]:
		for i in range(3 if mode=="free_kick" else 1): s.draw_circle(field.position+Vector2(.46+i*.05,.49)*field.size,8,UI.RED)
	var t: float=clampf(elapsed/5.3,0,1)*(points.size()-1)
	var segment:=mini(int(t),points.size()-2)
	var ball: Vector2=points[segment].lerp(points[segment+1],t-segment)
	var carrier: Vector2=ball+Vector2(0,14) if mode in ["duel","slalom","defending"] or (mode=="control" and step==2) else points[0]+Vector2(0,14)
	s.draw_circle(carrier,9,UI.ACCENT)
	if mode in ["control","cross","crossing","free"]: s.draw_circle(points[-2]+Vector2(0,14),9,UI.ACCENT)
	s.draw_circle(ball+Vector2(2,4),5,Color(0,0,0,.4)); s.draw_circle(ball,5,UI.PAPER)
	for i in range(3):
		var at:=Vector2(843+i*179,642)
		s.draw_circle(at,12,UI.ACCENT if i==step else UI.LINE)
		s.center(str(i+1),at+Vector2(0,5),13,UI.INK if i==step else UI.MUTE,true)
		if i<2: s.draw_line(at+Vector2(20,0),at+Vector2(153,0),UI.LINE,2)
	s.text(STEPS[mode][step],Vector2(827,684),18,UI.PAPER,true)
	s.text("Temsili gösterim",Vector2(827,725),12,UI.MUTE)
