extends "res://scripts/menu_screen.gd"
const Progress=preload("res://scripts/legend_progression.gd")
const World=preload("res://scripts/career_world.gd")
const Catalog=preload("res://scripts/training_catalog.gd")
var game
var controls: Control
var page:="entry"
var stage:="tactics"
var world_mask:=1048575
var slot:=1
var overwrite:=false
var division:=0
var club_id:="c00"
var draft: Dictionary={}
var config:={"name":"YENİ YILDIZ","position":9,"foot":1,"height":180,"weight":73,"appearance":17}
var settings:={"half_minutes":2,"difficulty":1,"level":2}
var summaries: Array=[]
var portraits:=preload("res://scripts/squad_portraits.gd").new()
var portrait: Dictionary={}
var selected_drill:="passing"
var learn_position:=5

func _ready() -> void:
	setup_style(); hide()
	controls=Control.new(); controls.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(controls)
	add_child(portraits); portraits.portrait_ready.connect(func(_key): queue_redraw())

func pause_world() -> void:
	game.career.remember_quick_match()
	if game.camera.cull_mask!=0: world_mask=game.camera.cull_mask
	game.camera.cull_mask=0; game.state="career"; game.ball.freeze=true
	game.controller.held.clear(); game.cancel_pass(); game.charging=false
	game.audio.set_process(false); game.audio.update_atmosphere(0,"paused"); game.weather.sound.stream_paused=true

func open_entry() -> void:
	pause_world(); page="entry"; show(); build()

func open_hub() -> void:
	if not game.legend.active(): open_entry(); return
	if game.career.in_match:
		if game.state!="finished": return
		game.career.finish_match()
	if game.state=="trophy": hide(); return
	pause_world(); game.legend.coach_selection(); page="hub"; show(); build()

func close() -> void:
	hide(); clear_controls(); game.camera.cull_mask=world_mask; game.audio.set_process(true)
	game.return_menu()

func go(value: String) -> void:
	page=value; overwrite=false; game.legend.status=""; build()

func handle(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B):
		if page in ["entry","hub"]: close()
		elif page=="create": go("entry")
		else: go("hub")
		get_viewport().set_input_as_handled()

func clear_controls() -> void:
	for child in controls.get_children(): controls.remove_child(child); child.queue_free()

func button(rect: Rect2,value: String,callback: Callable,primary: bool=false) -> Button:
	var b:=make_button(controls,rect,value,callback,primary)
	b.add_theme_font_size_override("font_size",15); b.clip_text=true; b.tooltip_text=value
	return b

func option(rect: Rect2,items: Array,index: int,callback: Callable) -> OptionButton:
	var b:=OptionButton.new(); b.position=rect.position; b.size=rect.size; b.fit_to_longest_item=false; b.clip_text=true
	for value in items: b.add_item(str(value))
	b.select(index); b.item_selected.connect(callback); controls.add_child(b)
	b.get_popup().window_input.connect(game.controller.menus.popup_input.bind(b))
	b.get_popup().popup_hide.connect(func(): game.controller.menus.popup_option=null; b.grab_focus())
	return b

func club_ids() -> Array: return draft.clubs.keys().filter(func(id): return int(draft.clubs[id].league)==division)

func choose(index: int) -> void:
	slot=index; draft=World.create(); division=0; club_id="c00"; overwrite=false
	settings=game.MatchSettings.normalized({"half_minutes":game.quick_half_minutes,"level":game.management.level})
	page="create"; build()

func preview() -> void:
	if page=="create":
		portrait={"name":config.name,"shirt":24,"keeper":config.position==0,"age":18,"appearance_id":config.appearance,"height_cm":config.height,"weight_kg":config.weight,"attributes":Progress.initial_attributes(config.position,config.foot),"kit":World.kit(draft.clubs[club_id])}
	elif game.legend.active():
		portrait=game.legend.player().duplicate(true); portrait.kit=World.kit(game.career.club())
	if not portrait.is_empty(): portraits.request(portrait)
	queue_redraw()

func build() -> void:
	var previous: Control=get_viewport().gui_get_focus_owner()
	var at: Vector2=previous.position if previous!=null and previous.get_parent()==controls else Vector2(-1,-1)
	clear_controls()
	if page=="entry":
		summaries=[]
		for i in range(3):
			summaries.append(game.legend.career.slot_summary(i+1))
			button(Rect2(75+i*458,515,370,50),"DEVAM ET",load_slot.bind(i+1),true).disabled=not game.legend.career.has_save(i+1)
			button(Rect2(75+i*458,580,370,48),"YENİ EFSANE",choose.bind(i+1))
	elif page=="create": build_create()
	else:
		var labels:=["FUTBOLCUM","ANTRENMAN","MEVKİLER","LİG & FİKSTÜR"]
		var pages:=["hub","training","positions","league"]
		for i in range(pages.size()): button(Rect2(52+i*338,216,322,43),labels[i],go.bind(pages[i]),page==pages[i])
		match page:
			"hub": build_hub()
			"training": build_training()
			"positions": build_positions()
	button(Rect2(52,823,260,46),"← ANA MENÜ" if page in ["entry","hub"] else "← GERİ",close if page in ["entry","hub"] else go.bind("entry" if page=="create" else "hub"))
	if game.legend.active() and page!="create": button(Rect2(1130,823,266,46),"KAYDET",save_game)
	var items: Array=controls.get_children().filter(func(child): return child is LineEdit or (child is BaseButton and not child.disabled))
	items.sort_custom(func(a,b): return a.position.y<b.position.y if a.position.y!=b.position.y else a.position.x<b.position.x)
	for i in range(items.size()):
		var child: Control=items[i]
		child.focus_neighbor_top=child.get_path_to(items[posmod(i-1,items.size())])
		child.focus_neighbor_bottom=child.get_path_to(items[(i+1)%items.size()])
		child.focus_previous=child.focus_neighbor_top; child.focus_next=child.focus_neighbor_bottom
	if not items.is_empty():
		items[0].grab_focus()
		for child in items:
			if child.position==at: child.grab_focus(); break
	preview(); queue_redraw()

func load_slot(index: int) -> void:
	if game.legend.career.load_slot(index): open_hub()
	else: game.legend.status=game.legend.career.error; queue_redraw()

func save_game() -> void:
	game.legend.status="Efsane kariyerin kaydedildi." if game.career.save() else game.career.error; queue_redraw()

func build_create() -> void:
	var name:=LineEdit.new(); name.position=Vector2(52,302); name.size=Vector2(405,48)
	name.text=config.name; name.max_length=24; name.placeholder_text="Ad soyad"; name.select_all_on_focus=true
	name.text_changed.connect(func(value): config.name=value; overwrite=false; preview()); controls.add_child(name)
	option(Rect2(483,302,405,48),Progress.POSITIONS,config.position,func(v):
		config.position=v
		if v==0: config.height=190; config.weight=80
		build())
	option(Rect2(52,397,195,48),["SOL AYAK","SAĞ AYAK"],config.foot,func(v): config.foot=v; preview())
	option(Rect2(272,397,185,48),range(160,206).map(func(n): return str(n)+" cm"),config.height-160,func(v): config.height=v+160; preview())
	option(Rect2(483,397,185,48),range(52,106).map(func(n): return str(n)+" kg"),config.weight-52,func(v): config.weight=v+52; preview())
	option(Rect2(694,397,194,48),range(60).map(func(n): return "GÖRÜNÜŞ "+str(n+1)),clampi(config.appearance,0,59),func(v): config.appearance=v; preview())
	option(Rect2(52,497,405,48),World.LEAGUES,division,func(v): division=v; club_id=club_ids()[0]; overwrite=false; build())
	var ids:=club_ids()
	option(Rect2(483,497,405,48),ids.map(func(id): return draft.clubs[id].name),ids.find(club_id),func(v): club_id=ids[v]; overwrite=false; preview())
	option(Rect2(52,601,405,48),game.MatchSettings.HALF_MINUTES.map(func(n): return "DEVRE BAŞINA %d DAKİKA" % n),game.MatchSettings.HALF_MINUTES.find(settings.half_minutes),func(v): settings.half_minutes=game.MatchSettings.HALF_MINUTES[v])
	option(Rect2(483,601,405,48),game.MatchSettings.LEVELS,settings.level,func(v): settings=game.MatchSettings.normalized({"half_minutes":settings.half_minutes,"level":v}))
	button(Rect2(52,700,836,58),"BU EFSANE KAYDININ ÜZERİNE YAZ & BAŞLA" if overwrite else "İLK SÖZLEŞMENİ İMZALA",begin,true)

func begin() -> void:
	if game.legend.career.has_save(slot) and not overwrite:
		overwrite=true; game.legend.status="Bu yuvadaki Efsane kaydı değiştirilecek. Başlamak için tekrar onayla."; build(); return
	if game.legend.create(club_id,slot,config,settings): open_hub()
	else: queue_redraw()

func build_hub() -> void:
	var c=game.career; var f: Dictionary=c.next_fixture()
	if game.legend.player().get("retired",false):
		button(Rect2(490,421,530,52),"YENİ BİR EFSANE YARAT",go.bind("entry"),true)
	elif c.world.season_done:
		button(Rect2(490,421,530,52),"YENİ SEZONA GEÇ",func(): c.next_season(); game.legend.coach_selection(); build(),true)
	elif not f.is_empty() and f.day<=c.world.date:
		if game.legend.selection.available: button(Rect2(490,421,530,52),"MAÇA ÇIK · "+game.legend.selection.role,func(): game.legend.play(); queue_redraw(),true)
		else: button(Rect2(490,421,530,52),"BU MAÇI TRİBÜNDEN TAKİP ET",func(): c.simulate_next(); build(),true)
	else: button(Rect2(490,421,530,52),"TAKVİMİ İLERLET",func(): game.legend.advance(); build(),true)

func build_training() -> void:
	Progress.refresh_week(game.legend.data(),int(game.career.world.date))
	var modes: Array=Catalog.options(game.legend.player())
	if selected_drill not in modes: selected_drill=modes[0]
	for i in range(modes.size()):
		var mode: String=modes[i]
		button(Rect2(52,286+i*57,420,47),Catalog.title(mode),func(): selected_drill=mode; build(),selected_drill==mode)
	var ready: bool=not game.legend.player().get("retired",false) and game.legend.data().sessions<Progress.TRAINING_LIMIT and game.legend.player().injury<=game.career.world.date
	button(Rect2(521,680,840,58),"SAHAYA ÇIK · 6 DENEME" if ready else "KARİYER TAMAMLANDI" if game.legend.player().get("retired",false) else "SAKATLIK NEDENİYLE DİNLEN" if game.legend.player().injury>game.career.world.date else "BU HAFTA TAMAMLANDI",func(): game.legend.train(selected_drill); queue_redraw(),true).disabled=not ready

func build_positions() -> void:
	var d: Dictionary=game.legend.data()
	for i in range(Progress.POSITIONS.size()):
		var value: float=d.positions.get(str(i),0)
		var label: String=Progress.POSITIONS[i]+(" · SEÇİLİ" if i==d.position else " · HAZIR" if value>=100 else " · %%%d" % value if d.learning==i else "")
		button(Rect2(52+(i%2)*435,285+(i/2)*83,414,64),label,func():
			if value>=100: game.legend.prefer(i)
			else: game.legend.learn(i)
			build(),i==d.position).disabled=value<100 and (d.learning>=0 or d.positions.size()>=3 or i==0 or game.legend.player().keeper)

func fit(value: String,at: Vector2,width: float,size: int=16,color: Color=PAPER,strong: bool=false) -> void:
	var f: Font=bold if strong else font
	while size>12 and f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width: size-=1
	draw_string(f,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)

func paragraph(value: String,at: Vector2,width: float,size: int=16,color: Color=MUTE) -> void:
	var line:=""; var y:=at.y
	for word in value.split(" "):
		if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			text(line,Vector2(at.x,y),size,color); line=""; y+=25
		line+=word+" "
	text(line,Vector2(at.x,y),size,color)

func _draw() -> void:
	if not visible: return
	var titles:={"entry":"BİR EFSANE DOĞUYOR","create":"SAHADAKİ HİKÂYENİ YARAT","hub":"FUTBOLCUM","training":"HER ÇALIŞMA BİR ADIM","positions":"OYUNUNU GENİŞLET","league":"SEZONUN HİKÂYESİ"}
	var subtitle:="Tek oyuncu. İlk sözleşmeden ilk 11'e. Kendi emeğinle yüksel."
	if game.legend.active() and page!="create": subtitle=game.career.club().name+" · "+World.date_label(int(game.career.world.date))
	backdrop(titles.get(page,"EFSANE"),subtitle,"E F S A N E   M O D U")
	match page:
		"entry": draw_entry()
		"create": draw_create()
		"hub": draw_hub()
		"training": draw_training()
		"positions": draw_positions()
		"league": draw_league()
	if not game.legend.status.is_empty(): fit(game.legend.status,Vector2(330,850),765,14,GOLD)

func draw_entry() -> void:
	for i in range(summaries.size()):
		var x:=52+i*458; var d: Dictionary=summaries[i]
		box(Rect2(x,271,430,439),PANEL,12)
		text("EFSANE  %02d" % (i+1),Vector2(x+26,310),14,GOLD,true)
		if d.is_empty():
			text("İLK İMZA",Vector2(x+26,377),29,PAPER,true)
			paragraph("18 yaşında başla. Forma şansını çalışarak kazan.",Vector2(x+26,422),370,18)
		else:
			badge(Vector2(x+60,377),d.badge,.95)
			fit(d.get("player",d.name),Vector2(x+111,366),285,21,PAPER,true)
			fit(d.name,Vector2(x+111,393),285,15)
			text("GEN %d · %s" % [d.get("overall",0),d.get("position","")],Vector2(x+26,448),19,GOLD,true)
			text(World.date_label(int(d.date)),Vector2(x+26,480),15,MUTE)
	text("Efsane kayıtları, teknik direktör kariyerinin üç kaydından ayrıdır.",Vector2(56,752),15,MUTE)

func draw_create() -> void:
	for label in [["AD SOYAD",52,281],["ANA MEVKİ",483,281],["BASKIN AYAK",52,376],["BOY",272,376],["KİLO",483,376],["GÖRÜNÜŞ",694,376],["LİG",52,476],["İLK KULÜBÜN",483,476],["MAÇ SÜRESİ",52,580],["ZORLUK",483,580]]: text(label[0],Vector2(label[1],label[2]),13,GOLD,true)
	box(Rect2(922,270,474,490),PANEL,12)
	var photo: Texture2D=portraits.photo(portrait) if not portrait.is_empty() else null
	if photo!=null: draw_texture_rect(photo,Rect2(999,285,320,280),false)
	fit(str(config.name).replace("i","İ").to_upper(),Vector2(948,589),416,27,PAPER,true)
	text("18 YAŞ · GEN %d · YEDEK" % World.ovr({"role":Progress.ROLES[config.position],"attributes":Progress.initial_attributes(config.position,config.foot)}),Vector2(948,625),18,GOLD,true)
	paragraph("Düşük güçle başlayacaksın. İlk 11'e çıkmak için antrenman, iyi maç notu ve teknik direktörün güveni gerekiyor.",Vector2(948,663),405,16)

func draw_hub() -> void:
	var l=game.legend; var d: Dictionary=l.data(); var p: Dictionary=l.player(); var c=game.career
	box(Rect2(52,279,390,472),PANEL,12)
	var photo: Texture2D=portraits.photo(portrait)
	if photo!=null: draw_texture_rect(photo,Rect2(103,292,288,255),false)
	fit(p.name,Vector2(76,576),340,24,PAPER,true)
	text("GEN %d" % World.ovr(p),Vector2(76,625),36,GOLD,true)
	text(Progress.POSITIONS[d.position],Vector2(76,659),17,PAPER,true)
	text("%d cm · %d kg · %s ayak" % [p.height_cm,p.weight_kg,"Sol" if p.attributes.preferred_foot==0 else "Sağ"],Vector2(76,690),15,MUTE)
	text("%d maç · %d gol · %d asist" % [d.games,d.goals,d.assists],Vector2(76,724),16)
	box(Rect2(466,279,580,218),PANEL,12)
	text("SIRADAKİ GÖREV",Vector2(490,313),13,GOLD,true)
	var f: Dictionary=c.next_fixture()
	if not f.is_empty():
		var rival: Dictionary=c.world.clubs[f.away if f.home==c.world.user else f.home]
		fit(rival.name,Vector2(490,355),530,28,PAPER,true)
		text(World.date_label(int(f.day))+" · "+l.selection.role,Vector2(490,389),16,MUTE)
	else: text("Sezon tamamlandı",Vector2(490,368),26,PAPER,true)
	box(Rect2(1070,279,326,218),PANEL,12)
	text("TEKNİK DİREKTÖR GÜVENİ",Vector2(1092,314),13,GOLD,true)
	text("%d / 100" % roundi(d.trust),Vector2(1092,361),32,PAPER,true)
	box(Rect2(1092,384,280,7),Color("30474b"),3)
	box(Rect2(1092,384,280*d.trust/100,7),GOLD,3)
	text("İlk 11 eşiği: 60",Vector2(1092,424),15,MUTE)
	text("Son form: %.1f / 10" % d.form,Vector2(1092,460),17)
	box(Rect2(466,517,930,234),PANEL,12)
	text("FORMA REKABETİ",Vector2(490,550),13,GOLD,true)
	text("Sen %d  /  Rakibin %d" % [l.selection.ability,l.selection.competition],Vector2(490,585),23,PAPER,true)
	paragraph(l.selection.reason,Vector2(490,619),430,15)
	text("SON MAÇ" if not d.last.is_empty() else "İLK ADIM",Vector2(980,550),13,GOLD,true)
	if d.last.is_empty(): paragraph("Haftada 3 antrenman. Yedekten gelen dakikalarda pas yap, görevini koru ve fırsatları değerlendir.",Vector2(980,585),388,17)
	else:
		text("%.1f NOT · %d DAKİKA" % [d.last.rating,d.last.minutes],Vector2(980,588),23,PAPER,true)
		text("Güven %+.1f · +%d gelişim puanı" % [d.last.trust_change,roundi(d.last.xp)],Vector2(980,624),16,GOLD)
		text("Pas %d/%d · Top kaybı %d" % [d.last.get("completed",0),d.last.get("passes",0),d.last.get("losses",0)],Vector2(980,657),15)
	text("Antrenmanla yeteneğini artır; maç katkınla süre kazan.",Vector2(490,720),15,MUTE)

func draw_training() -> void:
	var d: Dictionary=game.legend.data()
	box(Rect2(495,282,901,474),PANEL,12)
	text("BU HAFTA %d / 3 TAMAMLANDI" % d.sessions,Vector2(521,322),15,GOLD,true)
	text(Catalog.title(selected_drill),Vector2(521,375),32,PAPER,true)
	paragraph(Catalog.SUCCESS[selected_drill],Vector2(521,420),823,19,PAPER)
	text("ÖZELLİKLER · 100 GELİŞİM PUANI = +1 GÜÇ",Vector2(521,497),13,GOLD,true)
	var skills: Array=game.legend.training_skills(selected_drill)
	var names:={"pace":"Hız","acceleration":"İvme","control":"Teknik","balance":"Denge","passing":"Pas","finishing":"Şut","stamina":"Dayanıklılık","defending":"Savunma","strength":"Güç","positioning":"Pozisyon","handling":"Tutuş","reflexes":"Refleks"}
	for i in range(skills.size()):
		var key: String=skills[i]; var x:=521+(i%2)*423; var y:=531+(i/2)*59
		var xp: float=d.xp.get(key,0)
		text(names.get(key,key)+"  "+str(game.legend.player().attributes[key]),Vector2(x,y),18,PAPER,true)
		text("%d / 100" % roundi(xp),Vector2(x+303,y),13,MUTE)
		box(Rect2(x,y+11,382,5),Color("30474b"),2)
		if xp>0: box(Rect2(x,y+11,382*xp/100,5),GOLD,2)
	text("İyi not daha çok gelişim getirir. Yarım kalan çalışmadan ödül gelmez.",Vector2(521,651),15,MUTE)
	text("Yeni hafta: "+World.date_label(int(d.week)+7),Vector2(56,752),14,MUTE)

func draw_positions() -> void:
	box(Rect2(947,283,449,437),PANEL,12)
	text("BİRDEN FAZLA MEVKİ",Vector2(972,322),22,PAPER,true)
	paragraph("Ana mevkin her zaman hazır. İki ek saha mevkisini sırayla öğrenebilirsin. Başarılı antrenmanlar, çalıştığın mevkinin uyumunu artırır.",Vector2(972,366),395,18)
	paragraph("Uyum %100 olunca mevkiyi seç. Teknik direktör seni o görev için değerlendirsin. Yeni rol için gereken özellikleri de geliştirmelisin.",Vector2(972,493),395,17)
	var d: Dictionary=game.legend.data()
	if d.learning>=0: fit("ÇALIŞILIYOR · "+Progress.POSITIONS[d.learning],Vector2(972,656),395,16,GOLD,true)
	elif game.legend.player().keeper: paragraph("Kaleci kariyeri kaleci olarak devam eder; saha mevkilerine geçiş yapılmaz.",Vector2(972,627),395,16,GOLD)
	else: text("Yaklaşık 6–8 başarılı çalışma",Vector2(972,656),17,GOLD)

func draw_league() -> void:
	var c=game.career; var ids: Array=c.standings(int(c.club().league))
	box(Rect2(52,280,720,469),PANEL,12); box(Rect2(796,280,600,469),PANEL,12)
	text("PUAN DURUMU",Vector2(76,316),17,GOLD,true)
	var start:=maxi(0,mini(ids.find(c.world.user)-4,ids.size()-10))
	for n in range(start,mini(start+10,ids.size())):
		var id: String=ids[n]; var row: Dictionary=c.world.table[id]; var y:=352+(n-start)*38
		if id==c.world.user: box(Rect2(66,y-24,691,34),Color("29433c"),5)
		text(str(n+1),Vector2(78,y),16); fit(c.world.clubs[id].name,Vector2(119,y),469,16)
		text("%d M   %d P" % [row.p,row.pts],Vector2(621,y),16,GOLD,true)
	text("SIRADAKİ MAÇLAR",Vector2(822,316),17,GOLD,true)
	var upcoming: Array=c.cups.all_fixtures().filter(func(f): return not f.played and c.world.user in [f.home,f.away])
	upcoming.sort_custom(func(a,b): return a.day<b.day)
	for i in range(mini(3,upcoming.size())):
		var f: Dictionary=upcoming[i]; var y:=354+i*58
		fit(c.world.clubs[f.home].name+" – "+c.world.clubs[f.away].name,Vector2(822,y),543,16)
		text(World.date_label(int(f.day)),Vector2(822,y+24),13,MUTE)
	if upcoming.is_empty(): text("Sezon tamamlandı.",Vector2(822,360),18,MUTE)
	text("SON MAÇLAR",Vector2(822,553),17,GOLD,true)
	var n:=0
	for f in c.world.results:
		if c.world.user not in [f.home,f.away]: continue
		var y:=590+n*47
		fit(c.world.clubs[f.home].short+"  %d – %d  " % f.score+c.world.clubs[f.away].short,Vector2(822,y),543,17)
		n+=1
		if n>=3: break
	if n==0: text("İlk düdük henüz çalmadı.",Vector2(822,599),18,MUTE)
