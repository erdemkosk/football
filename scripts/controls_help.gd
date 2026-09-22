extends "res://scripts/menu_screen.gd"
## A contextual reference; the live match is paused while the guide is open.
var game
var page := 0
var use_pad := false
var return_state := "menu"
var return_before_pause := "playing"
var previous_freeze := false
var return_focus: Control
var paused_match := false
var tabs: Array[Button] = []
var device_buttons: Array[Button] = []
var close_button: Button
const TITLES := ["PAS & ŞUT","SAVUNMA","TOP KONTROLÜ","MAÇ & MENÜ","ÇALIMLAR","BİTİRİCİLİK","ÖZEL PAS","KALECİ"]
const CARD := Rect2(390,84,1010,744)

func _ready() -> void:
	setup_style()
	visible=false
	mouse_filter=Control.MOUSE_FILTER_STOP
	for i in range(TITLES.size()):
		var tab := make_button(self,Rect2(422+i*118,192,112,40),TITLES[i],select_page.bind(i))
		tab.add_theme_font_size_override("font_size",11)
		tabs.append(tab)
	device_buttons.append(make_button(self,Rect2(1040,146,156,34),game.controller.family_label(),select_device.bind(true)))
	device_buttons[0].add_theme_font_size_override("font_size",13)
	device_buttons.append(make_button(self,Rect2(1208,146,160,34),"KLAVYE",select_device.bind(false)))
	close_button=make_button(self,Rect2(1168,766,200,40),"KAPAT  ×",close_panel,true)
	var close_icon := make_button(self,Rect2(1324,110,44,38),"×",close_panel)
	close_icon.focus_mode=Control.FOCUS_NONE
	var buttons: Array[Button]=[]
	buttons.append_array(tabs); buttons.append_array(device_buttons); buttons.append(close_button)
	for i in range(buttons.size()):
		var previous: NodePath=buttons[i].get_path_to(buttons[posmod(i-1,buttons.size())])
		var next: NodePath=buttons[i].get_path_to(buttons[(i+1)%buttons.size()])
		buttons[i].focus_neighbor_left=previous; buttons[i].focus_neighbor_top=previous
		buttons[i].focus_neighbor_right=next; buttons[i].focus_neighbor_bottom=next
		buttons[i].focus_previous=previous; buttons[i].focus_next=next
	select_page(0)
	select_device(false)
	game.controller.prompts_changed.connect(refresh_prompts)

func refresh_prompts() -> void:
	device_buttons[0].text=game.controller.family_label()
	queue_redraw()

func open_panel() -> void:
	if visible: close_panel(); return
	return_focus=get_viewport().gui_get_focus_owner()
	return_state=game.state
	return_before_pause=game.before_pause
	previous_freeze=game.ball.freeze
	paused_match=game.state!="menu"
	if paused_match:
		if game.state!="paused": game.before_pause=game.state
		game.state="paused"
		game.ball.freeze=true
	game.charging=false; game.charge=0; game.cancel_pass()
	game.reset_advanced_play()
	game.aiming_mouse=false
	game.goalkeeping.stop_rush()
	game.set_pieces.button=0; game.set_pieces.power=0
	for p in game.players: p.shot_preparation=0; p.wrapping=0
	game.controller.held.clear()
	select_device(game.controller.using_gamepad)
	visible=true
	game.hud.sync_navigation()
	tabs[page].grab_focus()
	queue_redraw()

func close_panel() -> void:
	if not visible: return
	visible=false
	if paused_match:
		game.state=return_state
		game.before_pause=return_before_pause
		game.ball.freeze=previous_freeze
	game.controller.held.clear()
	game.hud.sync_navigation()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree(): return_focus.grab_focus()
	game.hud.queue_redraw()

func select_page(value: int) -> void:
	page=posmod(value,TITLES.size())
	for i in range(tabs.size()):
		tabs[i].add_theme_color_override("font_color",GOLD if i==page else MUTE)
	queue_redraw()

func select_device(pad: bool) -> void:
	use_pad=pad
	for i in range(device_buttons.size()):
		device_buttons[i].add_theme_color_override("font_color",GOLD if (i==0)==use_pad else MUTE)
	queue_redraw()

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F1,KEY_ESCAPE]:
			close_panel(); get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START,JOY_BUTTON_Y]: close_panel()
		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			select_page(page+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1))
			tabs[page].grab_focus()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not CARD.has_point(event.position):
		close_panel(); accept_event()

func binding(action: int) -> String:
	return game.controller.label_for(action) if use_pad else OS.get_keycode_string(game.match_menu.key_for(action))

func entry(title: String,detail: String,keys: String) -> Dictionary:
	return {"title":title,"detail":detail,"keys":keys,"pad_keys":use_pad}

func combo(title: String,detail: String,keys: String,enabled: bool) -> Dictionary:
	if not enabled: return entry(title,"Tuş atamalarında "+("Orta sağ yüz tuşunda" if keys=="B × 2" else "Oyuncu seç sol omuz tuşunda")+" olmalı.","ATAMA GEREKLİ")
	var item := entry(title,("Kontrolcü kombosu · " if not use_pad else "")+detail,keys)
	item.pad_keys=true
	return item

func advanced_entry(title: String,detail: String,pad_keys: String,keyboard_keys: String) -> Dictionary:
	return entry(title,detail,pad_keys if use_pad else keyboard_keys)

func rows() -> Array:
	if page==4:
		return [
			advanced_entry("Roulette","Topu saklayarak tam dönüş. Analog yönleri oyuncunun baktığı yöne göredir.","RS ↓","1"),
			advanced_entry("Ball roll","Tabanla yana taşı. Sağ / sol yön hangi ayağın kullanılacağını seçer.","RS ← / →","2 + YÖN"),
			advanced_entry("Elastico","Dışa göster, içe çek. Sağ analogu hızla bir yandan diğerine çevir.","RS → ←","3 + YÖN"),
			advanced_entry("Scoop turn","Topu hafif kaldırarak çapraz dön. Düşük hızda daha kontrollüdür.","RS ↑","4 + YÖN"),
			entry("Kısa vücut çalımı","Yakın kontrolde kısa aldatma; koşuya devam edebilirsin.",binding(KEY_Z)),
			entry("Topu ileri aç","Topu öne it; boş alanda arkasından hızlan.",binding(KEY_V)),
			advanced_entry("Bağlama göre sağ analog","Top ayağında: çalım. Savunmada: oyuncu seç. Şut hazırlarken: nişan.","RS","YÖN TUŞLARI"),
			advanced_entry("Hareket sınırı","Çalımlar kondisyon harcar; kısa toparlanma ister. Rakip topu alabilir.","LS","↑ ↓ ← →")]
	if page==5:
		return [
			advanced_entry("Alçak sert şut","Hazırla ve bırak; güçlü, düşük yükselişli vuruş.","RB + "+binding(KEY_D),"CTRL + "+binding(KEY_D)),
			advanced_entry("Power shot","Daha uzun hazırlık, daha sert vuruş. Hazırlıkta top kapılabilir.","LB + RT + "+binding(KEY_D),"SHIFT + "+binding(KEY_D)),
			advanced_entry("Dış ayak","Ayağın dışıyla ters yönde kavis. Yön ve güç sende kalır.","LB + LT + "+binding(KEY_D),"ALT + "+binding(KEY_D)),
			advanced_entry("Zamanlamalı şutu seç","Sonraki normal şut için zamanlamayı aç / kapat.","L3","5"),
			entry("Timed finishing","Özel şutu bırak; çubuk yeşile gelince şuta tekrar bas. Erken basmak zayıflatır.",binding(KEY_D)+" → "+binding(KEY_D)),
			entry("İkinci basış isteğe bağlı","Tek basışla normal kalitede vurur. Zamanlama golü garanti etmez.",binding(KEY_D)),
			entry("Vole / kafa","Top gelmeden şutu hazırla. Kısa adım, uzanma ve gerekirse küçük sıçramayla uygun vuruş seçilir.",binding(KEY_D))]
	if page==6:
		return [
			advanced_entry("Sert düz pas","Yön ver, gücü ayarla ve bırak. Daha hızlı gider; kontrolü daha zordur.","RB + "+binding(KEY_S),"CTRL + "+binding(KEY_S)),
			advanced_entry("Yerden sert ara pas","Savunma arasına hızlı yerden pas. Mesafeyi basılı tutarak ayarla.","RB + "+binding(KEY_Y),"CTRL + "+binding(KEY_Y)),
			advanced_entry("Dummy / bırak geç","Takım arkadaşının alçak pasını kontrol etmeden arkandaki oyuncuya bırak.","L3","U"),
			entry("Ara pas","Yönündeki koşu alanına yarı yardımlı pas; boşluğa da oynayabilirsin.",binding(KEY_Y)),
			advanced_entry("Verkaç","Pas veren oyuncu sınırlı bir koşu yapar; dönüş pasını sen verirsin.","LB + "+binding(KEY_S),"KONTROLCÜ: LB + A")]
	if page==7:
		return [
			entry("Elle yerden dağıtım","Top eldeyken yönünü seç; kısa dokun veya mesafe için basılı tutup bırak.",binding(KEY_S)),
			entry("Uzun el atışı","Topu seçtiğin yöne omuz üzerinden fırlat. Basılı tutarak gücü ayarla.",binding(KEY_Y)),
			entry("Ayaktan açış","Şutu hazırla ve bırak: top elden düşer, ayağa temasla havadan açılır.",binding(KEY_D)),
			entry("Yere bırak","Topu elden sahaya bırak; ardından normal pas veya şutla devam et.",binding(KEY_V)),
			advanced_entry("Serbest yön ve güç","Kullanıcı kalecisi kendiliğinden güvenli oyuncuya pas vermez.","LS","↑ ↓ ← →"),
			entry("Kaleciyi çıkar","Rakip hücumdayken basılı tut; bıraktığında kaleye döner.",binding(KEY_Y))]
	var lb: bool=game.controller.bindings.get(JOY_BUTTON_LEFT_SHOULDER)==KEY_Q
	match page:
		0:
			return [
				entry("Pas","Kısa dokun: yakın pas. Basılı tut → bırak: daha uzak hedef.",binding(KEY_S)),
				entry("Ara pas","Yönünü seç; basılı tutup bırak. Top koşu yoluna gider.",binding(KEY_Y)),
				combo("Aşırtma şut","Şutu kalecinin üzerinden yumuşak bir kavisle gönder.","LB + X",lb),
				combo("Havadan uzun pas","Sol omuz tuşunu tut; pas tuşuyla gücü ayarla, bırakarak gönder.","LB + Y",lb),
				entry("Orta","Kanattan ceza sahasına havadan gönder.",binding(KEY_A)),
				combo("Yerden sert orta","Orta tuşuna hızlıca iki kez bas. Top yerden sert gider.","B × 2",game.controller.bindings.get(JOY_BUTTON_B)==KEY_A),
				entry("Şut","Sol analogla nişan; koşudan bağımsız yön: D-pad / sağ analog." if use_pad else "Basılı tut → bırak. Yönle küçük nişan düzeltmeleri yap.",binding(KEY_D)),
				entry("Vole / kafa","Top gelirken şuta erken basabilirsin. Oyuncu yerleşir; uygun ayak/kafa vuruşunu seçer. Yön ver → bırak.",binding(KEY_D)),
				entry("Falsolu şut","Şutu hazırlarken top koruma tuşunu da basılı tut.",binding(KEY_E)+" + "+binding(KEY_D)),
				combo("Verkaç","Pası ver; pası atan oyuncu kısa bir ileri koşu yapsın.","LB + A",lb)]
		1:
			return [
				entry("Ayakta müdahale","Topsuzken ayağını uzatıp topu almaya çalış.",binding(KEY_D) if use_pad else binding(KEY_G)),
				entry("Kayarak müdahale","Topsuzken kay. Önce rakibe temas edersen faul olabilir.",binding(KEY_A) if use_pad else binding(KEY_X)),
				entry("Kaleciyi çıkar","Savunmada basılı tut; bırakınca kaleci yerine döner.",binding(KEY_Y)),
				entry("Oyuncu değiştir","Tehlikeye yakın oyuncuyu seç; yön vererek seçimi etkile.",binding(KEY_Q)),
				entry("Rakibi karşıla","Basılı tut; topa dönük kısa, kontrollü adımlarla savun.",binding(KEY_E)),
				advanced_entry("İkinci adam baskısı","Rakipteyken tut: yeşil PRES oyuncusu basar. En fazla 4 sn; kondisyon harcar.",binding(KEY_S)+" TUT","SPACE TUT"),
				advanced_entry("Omuz mücadelesi","Rakibin yanında omuz koy. Arkadan veya topsuz itiş faul olabilir.","L3","J"),
				advanced_entry("Pas arası","Ayağını pas yoluna uzat. Doğru zamanlamayla topu keser; ıskalayabilir.","LT + "+binding(KEY_D),"L"),
				advanced_entry("Yönlü oyuncu seçimi","Savunmada sağ analogu hedefe it. LB/Q'nun sonraki hedefi sahada işaretlidir.","RS / LB + LS","Q + YÖN") ]
		2:
			return [
				entry("Hareket","Oyuncuyu yönlendir; son hareket yönün pas ve şuta temel olur.","SOL ANALOG" if use_pad else "↑  ↓  ←  →"),
				entry("Hızlı koş","Basılı tut: sprint. Hızlıca iki bas: topu ileri açıp peşinden koş. Kondisyon harcar.",binding(KEY_W)),
				entry("Topu sakla","Basılı tut; vücudunu rakiple topun arasına koy.",binding(KEY_E)),
				entry("Kısa çalım","Vücut çalımıyla topu yana al." if not use_pad or binding(KEY_Z)!="Atanmamış" else "Ayarlar → Tuş atama bölümünden bir tuş seç.",binding(KEY_Z)),
				entry("Topu ileri aç","Topu önüne bırak, ardından hızlanarak yetiş.",binding(KEY_V)),
				entry("Pas iste","Top takım arkadaşındayken bas; boşluğa koş.",binding(KEY_S)),
				entry("Havadan pas iste","Top takım arkadaşındayken havadan servis iste.",binding(KEY_A)),
				entry("Takım / tek oyuncu","Takım kontrolü ile tek oyuncuda kalma arasında geç.","KLAVYE: TAB" if use_pad else "TAB")]
	return [
		entry("Anlık oyun planı","RT/R2 basılı: sol savunmacı, yukarı dengeli, sağ hücumcu. Oyun durmaz.","RT + D-PAD" if use_pad else "F5 / F6 / F7"),
		entry("Hızlı değişiklik","Yorgun oyuncuya mevki uyumlu yedek. Kabul et; ilk duraklamada girsin. Takım başına 3 hak.","RT + A / B" if use_pad else "F8 / F9"),
		entry("Mola / devam","Maçı duraklat veya duraklatma menüsünden devam et.","START" if use_pad else "ESC"),
		entry("Kadro & taktik","Maç sırasında oyuncu değiştir, dizilişini düzenle.","VIEW" if use_pad else "K"),
		entry("Ayarlar","Ses, kontrolcü, tuş atama ve oyun tercihleri.","MENÜDEN" if use_pad else "P"),
		entry("Seremoni / golü geç","Töreni, gol kutlamasını, tekrarı veya devre arasını geç; santradan başla.","A" if use_pad else "SPACE"),
		entry("Hava durumu","Açık, yağmurlu ve sağanak arasında geç.","MENÜDEN" if use_pad else "H"),
		entry("Kamera","Ayarlar → Görüntü & Oyun: kamera, uzaklık ve yükseklik. C açı değiştirir; fare tekeri yakınlaştırır.","AYARLARDAN" if use_pad else "C / TEKER"),
		entry("FPS paneli","Kare hızı ve performans grafiğini aç / kapat.","KLAVYE: F" if use_pad else "F"),
		entry("Ses aç / kapat","Tüm oyun seslerini aç veya sessize al.","AYARLARDAN" if use_pad else "M")]

func _draw() -> void:
	draw_rect(Rect2(0,0,1440,900),Color(0.015,0.035,0.045,0.55))
	box(Rect2(398,96,1010,744),Color(0,0,0,0.25),14)
	box(CARD,Color("10282f"),12,Color("365359"))
	box(Rect2(422,110,4,32),GOLD,2)
	text("KONTROL REHBERİ",Vector2(442,138),29,PAPER,true)
	text("Hareketi bul. Tuşunu öğren. Sahaya dön.",Vector2(423,165),14,MUTE)
	draw_line(Vector2(422,247),Vector2(1368,247),Color("365359"),1)
	text(TITLES[page],Vector2(438,272),11,GOLD,true)
	text(game.controller.family_label()+" KONTROLCÜSÜ" if use_pad else "KLAVYE & FARE",Vector2(1090,272),11,MUTE,true)
	var items := rows()
	var row_height := minf(56,448.0/items.size())
	var compact := row_height<48
	for i in range(items.size()):
		var item: Dictionary=items[i]
		var y := 286.0+i*row_height
		box(Rect2(422,y,946,row_height-4),Color("18333a") if i%2==0 else Color("132c33"),5)
		text(item.title,Vector2(438,y+(18 if compact else 22)),15 if compact else 17,PAPER,true)
		text(item.detail,Vector2(438,y+(35 if compact else 42)),11 if compact else 12,MUTE)
		box(Rect2(1080,y+(5 if compact else 9),270,34),Color("203d44"),6,Color(GOLD,0.3))
		if item.pad_keys:
			var width: float=game.controller.Glyphs.width(item.keys,bold,30,12)
			game.controller.Glyphs.draw_sequence(self,Vector2(1215-width*0.5,y+(22 if compact else 26)),item.keys,game.controller.family,bold,30,12)
		else:
			var key_size := 17
			while key_size>11 and bold.get_string_size(item.keys,HORIZONTAL_ALIGNMENT_LEFT,-1,key_size).x>246: key_size-=1
			center(item.keys,Vector2(1215,y+(28 if compact else 32)),key_size,GOLD,true)
	draw_line(Vector2(422,750),Vector2(1368,750),Color("365359"),1)
	if game.controller.using_gamepad:
		game.controller.Glyphs.draw_hints(self,Vector2(423,779),[["LB / RB","Bölüm değiştir"],["A","Seç"],["B / Y","Kapat"]],game.controller.family,font,25,12)
	else: text("F1 / ESC  Kapat     TAB / YÖN TUŞLARI  Gez     ENTER  Seç",Vector2(423,783),12,MUTE)
	text("Tuşlar geçerli atamalarını gösterir."+("  Maç duraklatıldı." if paused_match and return_state!="setup" else ""),Vector2(423,806),11,GOLD)
