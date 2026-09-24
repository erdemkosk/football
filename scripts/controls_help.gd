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
var row_scroll: ScrollContainer
var row_content: VBoxContainer
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
	row_scroll=ScrollContainer.new()
	row_scroll.position=Vector2(422,282); row_scroll.size=Vector2(946,458)
	row_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	row_scroll.follow_focus=true
	add_child(row_scroll)
	row_content=VBoxContainer.new(); row_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row_content.add_theme_constant_override("separation",6); row_scroll.add_child(row_content)
	select_page(0)
	select_device(false)
	game.controller.prompts_changed.connect(refresh_prompts)

func refresh_prompts() -> void:
	device_buttons[0].text=game.controller.family_label()
	rebuild_rows()
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

func rebuild_rows() -> void:
	if not is_instance_valid(row_content): return
	for child in row_content.get_children(): row_content.remove_child(child); child.queue_free()
	row_scroll.scroll_vertical=0
	var factor: float=game.experience.scale_factor()
	var cards: Array[Control]=[]
	for item in rows():
		var card := PanelContainer.new()
		card.focus_mode=Control.FOCUS_ALL
		var style := StyleBoxFlat.new(); style.bg_color=Color("18333a")
		style.content_margin_left=14; style.content_margin_right=14; style.content_margin_top=10; style.content_margin_bottom=10
		style.set_corner_radius_all(5); card.add_theme_stylebox_override("panel",style)
		var focus_style := style.duplicate(); focus_style.border_color=GOLD; focus_style.set_border_width_all(2)
		card.focus_entered.connect(func(): card.add_theme_stylebox_override("panel",focus_style); row_scroll.ensure_control_visible(card))
		card.focus_exited.connect(func(): card.add_theme_stylebox_override("panel",style))
		row_content.add_child(card); cards.append(card)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",18); card.add_child(row)
		var body := VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(body)
		for value in [item.title,item.detail]:
			var caption := Label.new(); caption.text=value; caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			caption.add_theme_font_size_override("font_size",roundi((17 if value==item.title else 14)*factor))
			caption.add_theme_color_override("font_color",PAPER if value==item.title else MUTE)
			body.add_child(caption)
		var keys := VBoxContainer.new(); keys.custom_minimum_size.x=260; keys.size_flags_vertical=Control.SIZE_SHRINK_CENTER; row.add_child(keys)
		if item.pad_keys and item.keys!="ATAMA GEREKLİ":
			var hint=preload("res://scripts/controller_hint.gd").new(); hint.controller=game.controller; hint.items=[[item.keys,""]]; keys.add_child(hint)
		else:
			var caption := Label.new(); caption.text=item.keys; caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; caption.add_theme_color_override("font_color",GOLD)
			caption.add_theme_font_size_override("font_size",roundi(16*factor)); keys.add_child(caption)
	for i in range(cards.size()):
		cards[i].focus_neighbor_top=cards[i].get_path_to(cards[i-1] if i>0 else tabs[page])
		cards[i].focus_neighbor_bottom=cards[i].get_path_to(cards[i+1] if i+1<cards.size() else close_button)
		cards[i].focus_neighbor_left=cards[i].get_path_to(tabs[page])
		cards[i].focus_neighbor_right=cards[i].get_path_to(close_button)
	if not cards.is_empty():
		for tab in tabs: tab.focus_neighbor_bottom=tab.get_path_to(cards[0])
		close_button.focus_neighbor_top=close_button.get_path_to(cards.back())

func select_page(value: int) -> void:
	page=posmod(value,TITLES.size())
	for i in range(tabs.size()):
		tabs[i].add_theme_color_override("font_color",GOLD if i==page else MUTE)
	rebuild_rows()
	queue_redraw()

func select_device(pad: bool) -> void:
	use_pad=pad
	for i in range(device_buttons.size()):
		device_buttons[i].add_theme_color_override("font_color",GOLD if (i==0)==use_pad else MUTE)
	rebuild_rows()
	queue_redraw()

func handle(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not CARD.has_point(game.ui.from_viewport(event.position)):
		close_panel(); get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F1,KEY_ESCAPE]:
			close_panel(); get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START,JOY_BUTTON_Y]: close_panel()
		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			select_page(page+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1))
			tabs[page].grab_focus()

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
			entry("Şut / pas aldatması","Şut, orta veya ara pası hazırla; top çıkmadan kısa pasa basıp yön seç. Bekleyen savunmacı yolu kapatabilir.",binding(KEY_D)+" / "+binding(KEY_A)+" → "+binding(KEY_S)),
			advanced_entry("Roulette","Topu saklayarak tam dönüş. Analog yönleri oyuncunun baktığı yöne göredir.","RS ↓","1"),
			advanced_entry("Yana çek","Sprint basılıyken de yana çekersin. Boş tarafa çık; rakip yolu kapatabilir.","RS ← / →","2 + YÖN"),
			advanced_entry("Dur–kalk","Topu durdur, rakip akarken hızlan. Hazırlıkta pasla vazgeçebilirsin.","RB + RS ↓","9"),
			advanced_entry("Aç ve dolaş","Topu seçtiğin yana aç, rakibin diğer yanından koş. Top serbesttir.","RB + RS ↑","0 + YÖN"),
			advanced_entry("Elastico","Dışa göster, içe çek. Sağ analogu hızla bir yandan diğerine çevir.","RS → ←","3 + YÖN"),
			advanced_entry("Scoop turn","Topu hafif kaldırarak çapraz dön. Düşük hızda daha kontrollüdür.","RS ↑","4 + YÖN"),
			advanced_entry("Rainbow","Topuğuyla topu arkadan üzerinden atar.","LT + RS ↓","6"),
			advanced_entry("Heel flick","Topukla topu arkaya bırakır; savunmayı keser.","LT + RS ↑","7"),
			advanced_entry("Flick up","Topu önünde havaya kaldırır; vole veya kafa için.","LT + RS ← / →","8"),
			advanced_entry("Topuktan topuğa","Topu duran bacağın arkasından diğer topuğa alıp çaprazdan çık.","LB + LT + RS","SHIFT + 1"),
			advanced_entry("Çek ve kes","Tabanla topu çek, gövdenin arkasından keserek yön değiştir.","LB + RS ↓","SHIFT + 2"),
			advanced_entry("Bacak arası","Önündeki rakibin açık bacaklarından topu geçir; topu önce kapan alır.","LB + RS ↑","SHIFT + 3"),
			advanced_entry("McGeady dönüşü","Dönerek topu çapraz öne al; boş çıkış alanı gerekir.","LB + RS ← / →","SHIFT + 4"),
			entry("Çalım yıldızı","Tüm hareketler açık. Yıldız yükseldikçe hareket, top kontrolü ve toparlanma daha seri olur.","★"),
			entry("Kısa vücut çalımı","Yakın kontrolde kısa aldatma; koşuya devam edebilirsin.",binding(KEY_Z)),
			entry("Topu ileri aç","Topu öne it; boş alanda arkasından hızlan. Rakip topu alabilir.",binding(KEY_V))]
	if page==5:
		return [
			advanced_entry("Alçak sert şut","Hazırla ve bırak; güçlü, düşük yükselişli vuruş.","RB + "+binding(KEY_D),"CTRL + "+binding(KEY_D)),
			advanced_entry("Power shot","Basılı tutarak gücü ayarla; bırakınca hemen sert vurur.","LB + RT + "+binding(KEY_D),"SHIFT + "+binding(KEY_D)),
			advanced_entry("Dış ayak","Ayağın dışıyla ters yönde kavis. Yön ve güç sende kalır.","LB + LT + "+binding(KEY_D),"ALT + "+binding(KEY_D)),
			advanced_entry("Zamanlamalı şutu seç","Sonraki normal şut için zamanlamayı aç / kapat.","L3","5"),
			entry("Timed finishing","Özel şutu bırak; çubuk yeşile gelince şuta tekrar bas. Erken basmak zayıflatır.",binding(KEY_D)+" → "+binding(KEY_D)),
			entry("İkinci basış isteğe bağlı","Tek basışla normal kalitede vurur. Zamanlama golü garanti etmez.",binding(KEY_D)),
			entry("Vole / kafa","Top gelmeden şutu hazırla. Kısa adım, uzanma ve gerekirse küçük sıçramayla uygun vuruş seçilir.",binding(KEY_D))]
	if page==6:
		return [
			advanced_entry("Koşuya gönder","Yönündeki arkadaşına ileri koşu yaptır. Pasın yönü ve zamanlaması sende.","LB + R3","N"),
			advanced_entry("Ayağına çağır","Yönündeki arkadaşın kısa pas mesafesine yaklaşır.","LB + L3","I"),
			advanced_entry("Sert düz pas","Yön ver ve bir kez bas. Mesafeye göre sert pas; kontrolü daha zordur.","RB + "+binding(KEY_S),"CTRL + "+binding(KEY_S)),
			advanced_entry("Yerden sert ara pas","Savunma arasına hızlı yerden pas. Mesafeyi basılı tutarak ayarla.","RB + "+binding(KEY_Y),"CTRL + "+binding(KEY_Y)),
			advanced_entry("Dummy / bırak geç","Takım arkadaşının alçak pasını kontrol etmeden arkandaki oyuncuya bırak.","L3","U"),
			entry("Ara pas","Yönü serbestçe seç; gücü basılı tutup bırak. Ok oyuncuya kilitlenmez.",binding(KEY_Y)),
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
				entry("Pas","Yön ver, bir kez bas. Mesafe otomatik; top gelmeden hemen önce de basabilirsin.",binding(KEY_S)),
				entry("Ara pas","Yönü serbestçe seç; gücü tutup bırak. Daha fazla güç topu aynı yönde ileri gönderir.",binding(KEY_Y)),
				combo("Aşırtma şut","Şutu kalecinin üzerinden yumuşak bir kavisle gönder.","LB + X",lb),
				combo("Havadan uzun pas","Sol omuz tuşunu tut; pas tuşuyla gücü ayarla, bırakarak gönder.","LB + Y",lb),
				entry("Orta","Basılı tut: yön ve güç ayarla. Bırak: ortayı gönder.",binding(KEY_A)),
				entry("Yerden sert orta","Hızlı koş tuşunu tutarken ortayı hazırla; orta tuşunu bırakarak gönder.",binding(KEY_W)+" + "+binding(KEY_A)),
				entry("Şut","Sol analogla nişan; koşudan bağımsız yön: D-pad / sağ analog." if use_pad else "Basılı tut → bırak. Yönle küçük nişan düzeltmeleri yap.",binding(KEY_D)),
				entry("Vole / kafa","Top gelirken şuta bas, vuruş yönünü seç. Tuşu erken bıraksan da temasa kadar yönü değiştirebilirsin; yönü bırakınca son seçim korunur.",binding(KEY_D)),
				entry("Falsolu şut","Şutu hazırlarken top koruma tuşunu da basılı tut.",binding(KEY_E)+" + "+binding(KEY_D)),
				combo("Verkaç","Pası ver; pası atan oyuncu kısa bir ileri koşu yapsın.","LB + A",lb),
				advanced_entry("Vuruştan vazgeç","Şut, pas, orta veya gelişine vuruş hazırlığını topa temas etmeden iptal et. Çıkan top geri alınmaz.","LB + RB","B"),
				advanced_entry("Duran top organizasyonu","Korner / frikikte ön direk, arka direk, ceza yayı veya kısa pas seç. Nişan ve güç değişmez.","LB + D-PAD ↑ → ↓ ←","1 / 2 / 3 / 4")]
		1:
			return [
				entry("Ayakta müdahale","Topsuzken ayağını uzatıp topu almaya çalış.",binding(KEY_D) if use_pad else binding(KEY_G)),
				entry("Kayarak müdahale","Topsuzken kay. Önce rakibe temas edersen faul olabilir.",binding(KEY_A) if use_pad else binding(KEY_X)),
				entry("Kaleciyi çıkar","Savunmada basılı tut; bırakınca kaleci yerine döner.",binding(KEY_Y)),
				entry("Oyuncu değiştir","Topa yakın uygun oyuncuya geç. Sonraki hedef içi boş okla gösterilir; koşu yönün seçimi değiştirmez.",binding(KEY_Q)),
				entry("Rakibi karşıla","Basılı tut; topa dönük kısa, kontrollü adımlarla savun.",binding(KEY_E)),
				entry("Kapat (contain)","Hızlı koşla birlikte tut: oyuncun kale tarafındaki boşluğa koşar ve mesafeyi korur. Müdahale ayrı tuştur.",binding(KEY_E)+" + "+binding(KEY_W)),
				advanced_entry("İkinci adam baskısı","Rakipteyken tut: yeşil PRES oyuncusu basar. En fazla 4 sn; kondisyon harcar.",binding(KEY_S)+" TUT","SPACE TUT"),
				advanced_entry("Omuz mücadelesi","Rakibin yanında omuz koy. Arkadan veya topsuz itiş faul olabilir.","L3","J"),
				advanced_entry("Pas arası","Ayağını pas yoluna uzat. Doğru zamanlamayla topu keser; ıskalayabilir.","LT + "+binding(KEY_D),"L"),
				advanced_entry("Yönlü oyuncu seçimi","Savunmada sağ analogu seçmek istediğin oyuncuya doğru it. Manuel seçimin kısa süre korunur.","RS","KONTROLCÜ: RS") ]
		2:
			return [
				entry("Hareket","Oyuncuyu yönlendir; son hareket yönün pas ve şuta temel olur.","SOL ANALOG" if use_pad else "↑  ↓  ←  →"),
				entry("Hızlı koş","Basılı tut: sprint. Hızlıca iki bas: topu ileri açıp peşinden koş. Kondisyon harcar.",binding(KEY_W)),
				entry("Topu sakla","Basılı tut; vücudunu rakiple topun arasına koy.",binding(KEY_E)),
				entry("Yan adımla sür","Top sendeyken hızlı koşla birlikte tut: gövde aynı yöne bakar, kısa yan adımlarla topu taşırsın.",binding(KEY_E)+" + "+binding(KEY_W)),
				advanced_entry("Kontrollü sprint","Sprintte kısa dokunuşlar; biraz daha yavaş ama top ayağa yakın.","RB + RT",binding(KEY_W)+" + SHIFT"),
				entry("İlk dokunuşta aç","Top gelmeden hemen önce bas ve yön ver: ilk dokunuş topu boşluğa iter.",binding(KEY_V)+" + YÖN"),
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
	draw_rect(game.ui.bounds(),Color(0.015,0.035,0.045,0.55))
	box(Rect2(398,96,1010,744),Color(0,0,0,0.25),14)
	box(CARD,Color("10282f"),12,Color("365359"))
	box(Rect2(422,110,4,32),GOLD,2)
	text("KONTROL REHBERİ",Vector2(442,138),29,PAPER,true)
	text("Hareketi bul. Tuşunu öğren. Sahaya dön.",Vector2(423,165),14,MUTE)
	draw_line(Vector2(422,247),Vector2(1368,247),Color("365359"),1)
	text(TITLES[page],Vector2(438,272),11,GOLD,true)
	text(game.controller.family_label()+" KONTROLCÜSÜ" if use_pad else "KLAVYE & FARE",Vector2(1090,272),11,MUTE,true)
	draw_line(Vector2(422,750),Vector2(1368,750),Color("365359"),1)
	if game.controller.using_gamepad:
		game.controller.Glyphs.draw_hints(self,Vector2(423,779),[["LB / RB","Bölüm değiştir"],["A","Seç"],["B / Y","Kapat"]],game.controller.family,font,25,12)
	else: text("F1 / ESC  Kapat     TAB / YÖN TUŞLARI  Gez     ENTER  Seç",Vector2(423,783),12,MUTE)
	text("Tuşlar geçerli atamalarını gösterir."+("  Maç duraklatıldı." if paused_match and return_state!="setup" else ""),Vector2(423,806),11,GOLD)
