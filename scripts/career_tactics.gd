extends RefCounted
const Card=preload("res://scripts/career_tactics_card.gd")
var settings_open := false
var selected := ""
var bench_page := 0
var undo_lineup: Array=[]
const PAGE_SIZE := 10

func reset() -> void:
	settings_open=false; selected=""; bench_page=0; undo_lineup.clear()

func lineup(s) -> Array:
	if not s.live: return s.game.career.club().lineup
	var ids: Array=[]
	for i in range(11): ids.append(s.game.players[i].career_id)
	return ids

func reserves(s) -> Array:
	var ids: Array=[]
	if s.live:
		for p in s.game.management.bench[0]: ids.append(p.career_id)
	else:
		for id in s.game.career.roster(s.game.career.world.user):
			if id not in lineup(s): ids.append(id)
	return ids

func player_info(s,id: String) -> Dictionary:
	var c=s.game.career
	var p: Dictionary=c.player(id).duplicate()
	p.tactic_status="HAZIR" if c.available(id) else ("CEZALI" if p.banned>0 else "SAKAT")
	if s.live:
		var on_pitch: bool=id in lineup(s)
		for actor in s.game.players:
			if actor.career_id==id:
				p.fitness=actor.energy
				if actor.dismissed: p.tactic_status="İHRAÇ"
				else:
					for change in s.game.management.pending:
						if s.game.players[change.slot]==actor: p.tactic_status="ÇIKACAK"
		for i in range(s.game.management.bench[0].size()):
			if s.game.management.bench[0][i].career_id!=id: continue
			if s.game.management.bench[0][i].used and not on_pitch: p.tactic_status="OYUNA GİRDİ"
			for change in s.game.management.pending:
				if change.slot<11 and change.reserve==i: p.tactic_status="GİRECEK"
	return p

func point(s,index: int) -> Vector2:
	var plan: Dictionary=s.game.career.club().plan
	var at: Vector2=s.game.management.SHAPES[plan.formation][index]
	return Vector2(456+at.x*10*[.78,1.0,1.14][plan.width],323+at.y*6.2-((plan.line_height-1)*14 if index>0 else 0))

func add_card(s,id: String,rect: Rect2,pitch: bool) -> void:
	var card:=Card.new(); card.screen=s; card.identity=id; card.on_pitch=pitch
	card.position=rect.position; card.size=rect.size; card.text=s.game.career.player(id).name
	card.tooltip_text=card.text+" · "+s.World.ROLES[s.game.career.player(id).role]
	if s.live and not pitch:
		for reserve in s.game.management.bench[0]:
			if reserve.career_id==id and reserve.used: card.disabled=true
	card.set_meta("focus_key","tactic:"+id)
	card.pressed.connect(choose.bind(s,id)); s.controls.add_child(card)
	s.portraits.request(s.portrait_data(id))

func toggle(s) -> void:
	settings_open=not settings_open; s.build()
	for child in s.controls.get_children():
		if child.get_meta("focus_key","")=="tactic:settings": child.grab_focus(); break

func turn_page(s,step: int) -> void:
	if settings_open: return
	var last: int=maxi(0,(reserves(s).size()-1)/PAGE_SIZE)
	var next: int=clampi(bench_page+step,0,last)
	if next==bench_page: return
	var focused: Control=s.get_viewport().gui_get_focus_owner()
	var cell:=0
	if focused!=null and focused.get_script()==Card and not focused.on_pitch:
		cell=reserves(s).find(focused.identity)%PAGE_SIZE
	bench_page=next; s.build()
	var ids:=reserves(s)
	var id: String=ids[mini(bench_page*PAGE_SIZE+cell,ids.size()-1)]
	for child in s.controls.get_children():
		if child.get_meta("focus_key","")=="tactic:"+id: child.grab_focus(); break

func choose(s,id: String) -> void:
	var c=s.game.career
	if id not in c.club().roster: return
	if selected==id: selected=""; s.status=""; s.build(); return
	if selected=="":
		selected=id; s.status="Şimdi değiştireceğin oyuncuyu seç."; s.build(); return
	var starters:=lineup(s)
	var a: int=starters.find(selected); var b: int=starters.find(id)
	if a<0 and b<0: selected=id; s.build(); return
	if c.player(selected).keeper!=c.player(id).keeper:
		s.status="Kaleci yalnızca kaleciyle değiştirilebilir."; s.queue_redraw(); return
	if s.live:
		if a>=0 and b>=0: selected=id; s.build(); return
		var slot: int=a if a>=0 else b
		var reserve: int=reserves(s).find(id if a>=0 else selected)
		s.status=s.game.management.queue_sub(slot,reserve)
		selected=""; s.build(); return
	var incoming: String=id if a>=0 else selected
	if not c.available(incoming): s.status="Sakat veya cezalı oyuncu ilk 11'e alınamaz."; s.queue_redraw(); return
	undo_lineup=c.club().lineup.duplicate()
	if a>=0 and b>=0:
		c.club().lineup[a]=id; c.club().lineup[b]=selected
	else: c.club().lineup[a if a>=0 else b]=incoming
	s.status=c.player(selected).name+" ↔ "+c.player(id).name+" · Kadro güncellendi."
	selected=""; c.save(); s.build()

func undo(s) -> void:
	if s.live:
		var pending:=pending_index(s)
		if pending>=0:
			s.game.management.pending.remove_at(pending)
			selected=""; s.status="Bekleyen oyuncu değişikliği iptal edildi."; s.build()
		return
	if undo_lineup.is_empty() or s.live: return
	s.game.career.club().lineup=undo_lineup.duplicate(); undo_lineup.clear()
	selected=""; s.status="Son kadro değişikliği geri alındı."; s.game.career.save(); s.build()

func pending_index(s) -> int:
	if not s.live or selected=="": return -1
	for i in range(s.game.management.pending.size()):
		var item: Dictionary=s.game.management.pending[i]
		if item.slot>=11: continue
		if s.game.players[item.slot].career_id==selected or s.game.management.bench[0][item.reserve].career_id==selected: return i
	return -1

func build(s) -> void:
	var starters:=lineup(s)
	for n in range(starters.size()):
		add_card(s,starters[n],Rect2(point(s,n)-Vector2(46,33),Vector2(92,72)),true)
	var toggle_button: Button=s.button_at(Rect2(1176,188,200,33),"← KADROYA DÖN" if settings_open else "TAKTİK AYARLARI",toggle.bind(s))
	toggle_button.set_meta("focus_key","tactic:settings")
	if settings_open: build_settings(s); return
	var ids:=reserves(s)
	bench_page=clampi(bench_page,0,maxi(0,(ids.size()-1)/PAGE_SIZE))
	for n in range(mini(PAGE_SIZE,ids.size()-bench_page*PAGE_SIZE)):
		add_card(s,ids[bench_page*PAGE_SIZE+n],Rect2(907+(n%2)*235,270+(n/2)*87,224,78),false)
	s.button_at(Rect2(908,745,138,36),"← ÖNCEKİ",turn_page.bind(s,-1)).disabled=bench_page==0
	s.button_at(Rect2(1237,745,138,36),"SONRAKİ →",turn_page.bind(s,1)).disabled=(bench_page+1)*PAGE_SIZE>=ids.size()
	if not undo_lineup.is_empty() and not s.live:
		s.button_at(Rect2(692,743,148,36),"GERİ AL",undo.bind(s))
	elif pending_index(s)>=0:
		s.button_at(Rect2(641,743,199,36),"DEĞİŞİKLİĞİ İPTAL ET",undo.bind(s))

func build_settings(s) -> void:
	var plan: Dictionary=s.game.career.club().plan
	var rows := [["Diziliş",["4-4-2","4-3-3","3-5-2"],"formation"],["Oyun anlayışı",["Savunmacı","Dengeli","Hücumcu"],"mentality"],["Savunma çizgisi",["Derin","Normal","Önde"],"line_height"],["Pres",["Geri çekil","Dengeli","Yoğun"],"pressing"],["Genişlik",["Dar","Dengeli","Geniş"],"width"],["Tempo",["Sabırlı","Dengeli","Hızlı"],"tempo"],["Koşular",["Ayağa gel","Dengeli","Arkaya koş"],"runs"],["Bekler",["Geride kal","Dengeli","Bindir"],"fullbacks"]]
	for n in range(rows.size()):
		var row: Array=rows[n]
		var option: OptionButton=s.option_at(Rect2(1100,228+n*57,266,39),row[1],int(plan.get(row[2],1)),func(v): plan[row[2]]=v; apply_plan(s); s.build())
		option.set_meta("focus_key","plan:"+row[2])
	s.button_at(Rect2(918,675,448,33),"ÖN LİBERO: GERİDE KAL" if plan.get("anchor",true) else "ÖN LİBERO: SERBEST",func(): plan.anchor=not plan.get("anchor",true); apply_plan(s); s.build())
	s.option_at(Rect2(918,720,218,42),["SAVUNMA PLANI","DENGELİ PLAN","HÜCUM PLANI"],s.selected_plan,func(v): s.selected_plan=v)
	var save_plan: Button=s.button_at(Rect2(1149,720,102,42),"KAYDET",func(): s.game.career.club().plans[s.selected_plan]=plan.duplicate(true); s.game.career.save(); s.status="Oyun planı kaydedildi.")
	var use_plan: Button=s.button_at(Rect2(1263,720,103,42),"UYGULA",func(): s.game.career.club().plan=s.game.career.club().plans[s.selected_plan].duplicate(true); apply_plan(s); s.build())
	save_plan.focus_neighbor_right=save_plan.get_path_to(use_plan)
	use_plan.focus_neighbor_left=use_plan.get_path_to(save_plan)

func apply_plan(s) -> void:
	s.game.career.apply_plan(s.game.career.club().plan); s.game.management.apply_formation(); s.game.career.save()

func draw(s) -> void:
	var art=s.art
	art.surface(s,Rect2(52,177,815,527))
	for i in range(8): s.draw_rect(Rect2(82,217+i*55,755,55),Color("1b3b40") if i%2 else Color("18353b"))
	art.pitch(s,Rect2(100,223,720,429),.5)
	s.text("İLK 11  /  "+s.game.management.FORMATIONS[int(s.game.career.club().plan.formation)],Vector2(80,205),13,art.LIME,true)
	s.text("OYUNCUYU SEÇ → YEDEĞİ SEÇ  ·  SÜRÜKLEYEREK DE DEĞİŞTİREBİLİRSİN",Vector2(77,689),11,art.MUTED)
	art.surface(s,Rect2(890,177,506,622),art.BLUE)
	s.text("OYUN PLANI" if settings_open else "YEDEK KADRO",Vector2(910,211),16,art.WHITE,true)
	if settings_open:
		for n in range(8): s.text(["DİZİLİŞ","YAKLAŞIM","SAVUNMA ÇİZGİSİ","PRES","GENİŞLİK","TEMPO","KOŞULAR","BEKLER"][n],Vector2(912,255+n*57),11,art.MUTED,true)
	else:
		s.text("%d OYUNCU  ·  " % reserves(s).size()+("DEĞİŞİKLİK %d / 3" % s.game.management.committed(0) if s.live else "HIZLI KADRO DEĞİŞİMİ"),Vector2(910,248),11,art.MUTED)
		s.center("%d / %d" % [bench_page+1,maxi(1,ceili(reserves(s).size()/float(PAGE_SIZE)))],Vector2(1140,769),13,art.MUTED)
	art.surface(s,Rect2(52,718,815,81))
	if selected!="":
		var p: Dictionary=player_info(s,selected)
		s.text(p.name,Vector2(77,748),19,art.WHITE,true)
		s.text("%s  ·  GÜÇ %d  ·  KONDİSYON %d%%" % [s.World.ROLES[p.role],s.World.ovr(p),p.fitness*100],Vector2(78,776),12,art.LIME)
	else:
		var c=s.game.career; var fixture: Dictionary=c.next_fixture()
		if not fixture.is_empty():
			var opponent: String=fixture.away if fixture.home==c.world.user else fixture.home
			s.badge(Vector2(86,756),c.world.clubs[opponent],.7)
			s.text("RAKİP RAPORU  /  "+c.world.clubs[opponent].short,Vector2(127,745),13,art.LIME,true)
			s.draw_string(s.bold,Vector2(127,775),c.world.clubs[opponent].style+"  ·  GÜÇ "+str(roundi(c.strength(opponent))),HORIZONTAL_ALIGNMENT_LEFT,550,16,art.WHITE)
		else:
			s.text("KADRONU SAHADA KUR",Vector2(78,749),18,art.WHITE,true)
			s.text("Portreler, mevkiler ve kondisyon bilgisiyle hızlı seçim.",Vector2(78,776),12,art.MUTED)
