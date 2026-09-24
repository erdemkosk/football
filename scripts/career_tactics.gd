extends RefCounted
const Card=preload("res://scripts/career_tactics_card.gd")
const LINES := [
	[[0],[1,2,3,4],[5,6,7,8],[9,10]],
	[[0],[1,2,3,4],[5,6,7],[8,9,10]],
	[[0],[1,2,3],[4,5,6,7,8],[9,10]],
	[[0],[1,2,3,4],[5,6,7,8,9],[10]],
	[[0],[1,2,3,4],[5,6,7,8],[9,10]],
	[[0],[1,2,3,4,5],[6,7,8],[9,10]],
	[[0],[1,2,3],[4,5,6,7],[8,9,10]],
	[[0],[1,2,3,4],[5,6,7,8,9],[10]],
	[[0],[1,2,3,4],[5,6,7,8],[9,10]]]
var settings_open := false
var selected := ""
var focused := ""
var bench_page := 0
var undo_lineup: Array=[]
var pitch_cards: Array=[]
var bench_cards: Array=[]
var slide_from: Dictionary={}
const PAGE_SIZE := 10

func reset() -> void:
	settings_open=false; selected=""; focused=""; bench_page=0; undo_lineup.clear()
	pitch_cards.clear(); bench_cards.clear(); slide_from.clear()

func lineup(s) -> Array:
	if not s.live: return s.game.career.club().lineup
	var ids: Array=[]
	for i in range(11): ids.append(s.game.players[s.game.management.actor_at_slot(i)].career_id)
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

func remember_pitch() -> void:
	slide_from.clear()
	for card in pitch_cards:
		if is_instance_valid(card): slide_from[card.identity]=card.position

func slide_card(s,card: Control,from: Vector2,dest: Vector2) -> void:
	card.position=dest
	if from.distance_to(dest)<2: return
	if DisplayServer.get_name()=="headless" or "--disable-render-loop" in OS.get_cmdline_args(): return
	if not s.is_visible_in_tree(): return
	card.position=from
	var tween: Tween=s.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card,"position",dest,0.28)

func add_card(s,id: String,rect: Rect2,pitch: bool) -> void:
	var card:=Card.new(); card.screen=s; card.identity=id; card.on_pitch=pitch
	card.size=rect.size; card.text=s.game.career.player(id).name
	if pitch and slide_from.has(id): slide_card(s,card,slide_from[id],rect.position)
	else: card.position=rect.position
	card.tooltip_text=card.text+" · "+s.World.ROLES[s.game.career.player(id).role]
	if s.live and not pitch:
		for reserve in s.game.management.bench[0]:
			if reserve.career_id==id and reserve.used: card.disabled=true
	card.set_meta("focus_key","tactic:"+id)
	card.pressed.connect(choose.bind(s,id)); s.controls.add_child(card)
	if pitch: pitch_cards.append(card)
	else: bench_cards.append(card)
	s.portraits.request(s.portrait_data(id))

func inspect(s,id: String) -> void:
	if id=="" or focused==id: return
	focused=id
	s.queue_redraw()

func default_id(s) -> String:
	var starters:=lineup(s)
	var extras:=reserves(s)
	if focused!="" and (focused in starters or focused in extras): return focused
	if selected!="" and (selected in starters or selected in extras): return selected
	if starters.is_empty(): return extras[0] if not extras.is_empty() else ""
	if s.live:
		var actor=s.game.players[mini(s.game.controlled,10)]
		if actor.career_id in starters: return actor.career_id
	return starters[mini(6,starters.size()-1)]

func grab_card(s,id: String) -> void:
	if id=="": id=default_id(s)
	for child in s.controls.get_children():
		if child.get_meta("focus_key","")=="tactic:"+id and not child.disabled:
			child.grab_focus()
			inspect(s,id)
			return
	var fallback:=default_id(s)
	if fallback!="" and fallback!=id: grab_card(s,fallback)

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
	if selected==id: selected=""; s.status=""; s.build(); grab_card(s,id); return
	if selected=="":
		selected=id; focused=id; s.status="Şimdi değiştireceğin oyuncuyu seç."; s.build(); grab_card(s,id); return
	var starters:=lineup(s)
	var a: int=starters.find(selected); var b: int=starters.find(id)
	if a<0 and b<0: selected=id; focused=id; s.build(); grab_card(s,id); return
	if c.player(selected).keeper!=c.player(id).keeper:
		s.status="Kaleci yalnızca kaleciyle değiştirilebilir."; s.queue_redraw(); return
	if s.live:
		if a>=0 and b>=0:
			var first: int=s.game.management.actor_at_slot(a)
			var second: int=s.game.management.actor_at_slot(b)
			var reason: String=s.game.management.position_swap_reason(first,second)
			if reason!="": s.status=reason; s.queue_redraw(); return
			s.game.management.swap_positions(first,second)
			s.status="Oyuncuların sahadaki yerleri değişti."
			selected=""; s.build(); grab_card(s,id); return
		var slot: int=s.game.management.actor_at_slot(a if a>=0 else b)
		var reserve: int=reserves(s).find(id if a>=0 else selected)
		s.status=s.game.management.queue_sub(slot,reserve)
		selected=""; s.build(); grab_card(s,id); return
	var incoming: String=id if a>=0 else selected
	if not c.available(incoming): s.status="Sakat veya cezalı oyuncu ilk 11'e alınamaz."; s.queue_redraw(); return
	undo_lineup=c.club().lineup.duplicate()
	if a>=0 and b>=0:
		c.club().lineup[a]=id; c.club().lineup[b]=selected
	else: c.club().lineup[a if a>=0 else b]=incoming
	s.status=c.player(selected).name+" ↔ "+c.player(id).name+" · Kadro güncellendi."
	selected=""; c.save(); s.build(); grab_card(s,id)

func undo(s) -> void:
	if s.live:
		var pending:=pending_index(s)
		if pending>=0:
			s.game.management.pending.remove_at(pending)
			selected=""; s.status="Bekleyen oyuncu değişikliği iptal edildi."; s.build(); grab_card(s,focused)
		return
	if undo_lineup.is_empty() or s.live: return
	s.game.career.club().lineup=undo_lineup.duplicate(); undo_lineup.clear()
	selected=""; s.status="Son kadro değişikliği geri alındı."; s.game.career.save(); s.build(); grab_card(s,focused)

func pending_index(s) -> int:
	if not s.live or selected=="": return -1
	for i in range(s.game.management.pending.size()):
		var item: Dictionary=s.game.management.pending[i]
		if item.slot>=11: continue
		if s.game.players[item.slot].career_id==selected or s.game.management.bench[0][item.reserve].career_id==selected: return i
	return -1

func build(s) -> void:
	remember_pitch()
	pitch_cards.clear(); bench_cards.clear()
	var starters:=lineup(s)
	for n in range(starters.size()):
		add_card(s,starters[n],Rect2(point(s,n)-Vector2(46,33),Vector2(92,72)),true)
	var toggle_button: Button=s.button_at(Rect2(1176,188,200,33),"← KADROYA DÖN" if settings_open else "TAKTİK AYARLARI",toggle.bind(s))
	toggle_button.set_meta("focus_key","tactic:settings")
	if settings_open:
		build_settings(s)
		wire_navigation(s)
		return
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
	wire_navigation(s)

func build_settings(s) -> void:
	var plan: Dictionary=s.game.career.club().plan
	var rows := [["Diziliş",Array(s.game.management.FORMATIONS),"formation"],["Oyun anlayışı",["Savunmacı","Dengeli","Hücumcu"],"mentality"],["Savunma çizgisi",["Derin","Normal","Önde"],"line_height"],["Pres",["Geri çekil","Dengeli","Yoğun"],"pressing"],["Genişlik",["Dar","Dengeli","Geniş"],"width"],["Tempo",["Sabırlı","Dengeli","Hızlı"],"tempo"],["Koşular",["Ayağa gel","Dengeli","Arkaya koş"],"runs"],["Bekler",["Geride kal","Dengeli","Bindir"],"fullbacks"]]
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
	if s.live: s.game.management.manual_plan=true
	s.game.career.apply_plan(s.game.career.club().plan); s.game.management.apply_formation(); s.game.career.save()

func neighbor(button: Control,side: int,target: Control) -> void:
	if button==null or target==null: return
	button.set(["focus_neighbor_left","focus_neighbor_top","focus_neighbor_right","focus_neighbor_bottom"][side],button.get_path_to(target))

func nearest_x(button: Control,candidates: Array) -> Control:
	if candidates.is_empty(): return button
	var best: Control=candidates[0]
	var x := button.get_rect().get_center().x
	for candidate in candidates:
		if not is_instance_valid(candidate): continue
		if absf(candidate.get_rect().get_center().x-x)<absf(best.get_rect().get_center().x-x): best=candidate
	return best

func wire_navigation(s) -> void:
	var enabled: Array=[]
	for child in s.controls.get_children():
		if child is BaseButton and child.focus_mode!=Control.FOCUS_NONE and not child.disabled:
			enabled.append(child)
			for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: neighbor(child,side,child)
	if enabled.is_empty(): return
	var tabs: Array=[]
	var footer: Array=[]
	var settings: Control=null
	var options: Array=[]
	var pages: Array=[]
	for child in enabled:
		var key: String=str(child.get_meta("focus_key",""))
		if child.position.y==108: tabs.append(child)
		elif child.position.y>=820: footer.append(child)
		elif key=="tactic:settings": settings=child
		elif key.begins_with("plan:"): options.append(child)
		elif child.position.y>=745 and child.position.x>=900: pages.append(child)
	var formation := clampi(int(s.game.career.club().plan.formation),0,LINES.size()-1)
	if not pitch_cards.is_empty():
		var lines: Array=LINES[formation]
		for group in range(lines.size()):
			var line: Array=lines[group]
			for column in range(line.size()):
				if line[column]>=pitch_cards.size(): continue
				var card: Control=pitch_cards[line[column]]
				neighbor(card,SIDE_LEFT,pitch_cards[line[maxi(0,column-1)]])
				if column+1<line.size() and line[column+1]<pitch_cards.size():
					neighbor(card,SIDE_RIGHT,pitch_cards[line[column+1]])
				elif not bench_cards.is_empty():
					neighbor(card,SIDE_RIGHT,nearest_x(card,bench_cards))
				elif settings!=null:
					neighbor(card,SIDE_RIGHT,settings)
				for vertical in [-1,1]:
					var adjacent: int=group+vertical
					var side := SIDE_TOP if vertical==1 else SIDE_BOTTOM
					if adjacent>=lines.size():
						if not tabs.is_empty(): neighbor(card,side,tabs[mini(2,tabs.size()-1)])
					elif adjacent<0:
						if not footer.is_empty(): neighbor(card,side,nearest_x(card,footer))
					else:
						var candidates: Array=[]
						for index in lines[adjacent]:
							if index<pitch_cards.size(): candidates.append(pitch_cards[index])
						if not candidates.is_empty(): neighbor(card,side,nearest_x(card,candidates))
	for n in range(bench_cards.size()):
		var card: Control=bench_cards[n]
		var col := n%2
		var row := n/2
		if col==1: neighbor(card,SIDE_LEFT,bench_cards[n-1])
		elif not pitch_cards.is_empty(): neighbor(card,SIDE_LEFT,nearest_x(card,pitch_cards))
		if col==0 and n+1<bench_cards.size(): neighbor(card,SIDE_RIGHT,bench_cards[n+1])
		elif settings!=null: neighbor(card,SIDE_RIGHT,settings)
		if row>0: neighbor(card,SIDE_TOP,bench_cards[n-2])
		elif settings!=null: neighbor(card,SIDE_TOP,settings)
		if n+2<bench_cards.size(): neighbor(card,SIDE_BOTTOM,bench_cards[n+2])
		elif not pages.is_empty(): neighbor(card,SIDE_BOTTOM,nearest_x(card,pages))
		elif not footer.is_empty(): neighbor(card,SIDE_BOTTOM,nearest_x(card,footer))
	if settings!=null:
		if not tabs.is_empty(): neighbor(settings,SIDE_TOP,tabs[mini(tabs.size()-1,2)])
		if not bench_cards.is_empty(): neighbor(settings,SIDE_BOTTOM,bench_cards[0])
		elif not options.is_empty(): neighbor(settings,SIDE_BOTTOM,options[0])
		elif not pitch_cards.is_empty(): neighbor(settings,SIDE_LEFT,pitch_cards[mini(6,pitch_cards.size()-1)])
	for i in range(options.size()):
		var option: Control=options[i]
		if i>0: neighbor(option,SIDE_TOP,options[i-1])
		if i+1<options.size(): neighbor(option,SIDE_BOTTOM,options[i+1])
		if settings!=null and i==0: neighbor(option,SIDE_TOP,settings)
		if not pitch_cards.is_empty(): neighbor(option,SIDE_LEFT,nearest_x(option,pitch_cards))
	for i in range(tabs.size()):
		if i>0: neighbor(tabs[i],SIDE_LEFT,tabs[i-1])
		if i+1<tabs.size(): neighbor(tabs[i],SIDE_RIGHT,tabs[i+1])
		if not pitch_cards.is_empty(): neighbor(tabs[i],SIDE_BOTTOM,pitch_cards[mini(6,pitch_cards.size()-1)])
	for i in range(footer.size()):
		if i>0: neighbor(footer[i],SIDE_LEFT,footer[i-1])
		if i+1<footer.size(): neighbor(footer[i],SIDE_RIGHT,footer[i+1])
		if not pitch_cards.is_empty(): neighbor(footer[i],SIDE_TOP,nearest_x(footer[i],pitch_cards))
	for i in range(pages.size()):
		if i>0: neighbor(pages[i],SIDE_LEFT,pages[i-1])
		if i+1<pages.size(): neighbor(pages[i],SIDE_RIGHT,pages[i+1])
		if not bench_cards.is_empty(): neighbor(pages[i],SIDE_TOP,bench_cards[maxi(0,bench_cards.size()-2)])
		if not footer.is_empty(): neighbor(pages[i],SIDE_BOTTOM,nearest_x(pages[i],footer))

func draw(s) -> void:
	var art=s.art
	art.surface(s,Rect2(52,177,815,527))
	for i in range(8): s.draw_rect(Rect2(82,217+i*55,755,55),Color("1b3b40") if i%2 else Color("18353b"))
	art.pitch(s,Rect2(100,223,720,429),.5)
	s.text("İLK 11  /  "+s.game.management.FORMATIONS[int(s.game.career.club().plan.formation)],Vector2(80,205),13,art.LIME,true)
	s.text("İKİ OYUNCU SEÇ · SAHADA YER DEĞİŞTİR VEYA YEDEĞİ OYUNA AL",Vector2(77,689),11,art.MUTED)
	art.surface(s,Rect2(890,177,506,622),art.BLUE)
	s.text("OYUN PLANI" if settings_open else "YEDEK KADRO",Vector2(910,211),16,art.WHITE,true)
	if settings_open:
		for n in range(8): s.text(["DİZİLİŞ","YAKLAŞIM","SAVUNMA ÇİZGİSİ","PRES","GENİŞLİK","TEMPO","KOŞULAR","BEKLER"][n],Vector2(912,255+n*57),11,art.MUTED,true)
	else:
		s.text("%d OYUNCU  ·  " % reserves(s).size()+("DEĞİŞİKLİK %d / 3" % s.game.management.committed(0) if s.live else "HIZLI KADRO DEĞİŞİMİ"),Vector2(910,248),11,art.MUTED)
		s.center("%d / %d" % [bench_page+1,maxi(1,ceili(reserves(s).size()/float(PAGE_SIZE)))],Vector2(1140,769),13,art.MUTED)
	art.surface(s,Rect2(52,718,815,81))
	var shown: String=focused if focused!="" else selected
	if shown!="":
		var p: Dictionary=player_info(s,shown)
		var heading: String=p.name
		if selected!="" and focused!="" and focused!=selected:
			heading=s.game.career.player(selected).name+"  →  "+p.name
		s.text(heading,Vector2(77,748),19,art.WHITE,true)
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
