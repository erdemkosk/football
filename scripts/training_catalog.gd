extends RefCounted
## One exercise catalogue shared by free practice and scheduled career sessions.
const MODES := ["free","cross","free_kick","duel","slalom","passing","shooting","crossing","control","penalty","defending","distribution"]
const TITLES := ["SERBEST ANTRENMAN","ORTA & KAFA","SERBEST VURUŞ","BİRE BİR ATÖLYESİ","KONİ PARKURU","HEDEF PASI","ŞUT İSABETİ","ORTA AÇMA","İLK KONTROL","PENALTI SERİSİ","TOP KAZANMA","KALECİ DAĞITIMI"]
const DETAILS := [
	"11 oyuncuyla pas, şut ve serbest oyun.","Kanattan gelen topu kafa veya voleyle bitir.","Noktayı seç; baraja karşı yön ve falso dene.","Üç aşamada rakibini çalımla geç.",
	"Altı kapıyı sırayla, top ayağındayken geç.","Altı pası işaretli kapılardan geçir.","Altı farklı noktadan kalenin hedef köşesine vur.","İki kanattan hedef bölgeye havadan orta aç.",
	"Alana koş, pası karşıla ve topu sürerek çık.","Kaleciye karşı altı penaltı kullan.","Rakibin topunu kazan ve üç saniye koru.","Uzun paslarını işaretli kapılara ulaştır."]
const SKILLS := {
	"slalom":["control","balance","acceleration"],"passing":["passing","control","balance"],
	"shooting":["finishing","balance","control"],"crossing":["passing","control","stamina"],
	"control":["control","balance","passing"],"penalty":["finishing","balance","control"],
	"defending":["defending","strength","positioning"],"distribution":["passing","handling","positioning"]}
const SCORED := ["slalom","passing","shooting","crossing","control","penalty","defending","distribution"]
const WORKSHOPS := ["free","cross","free_kick","duel"]
const FOCUS := {"free":"Pas · hareket · şut","cross":"Kafa · vole · zamanlama","free_kick":"Yön · güç · falso","duel":"Zamanlama · alan yaratma","slalom":"Kontrol · denge · çeviklik","passing":"Pas · yön · isabet","shooting":"Şut · denge · isabet","crossing":"Orta · mesafe · isabet","control":"İlk dokunuş · yön değiştirme","penalty":"Yön · güç · soğukkanlılık","defending":"Müdahale · topu koruma","distribution":"Uzun pas · oyun kurma"}
const SUCCESS := {
	"free":"Süre veya not baskısı yok. Pas açıları bul, topu taşı ve şut dene.",
	"cross":"Ortayı takım arkadaşın açar. Topa yetişip kafa veya voleyle bitirmeyi dene.",
	"free_kick":"Önce vuruş noktasını seç. Barajı aşarak kaleyi bulmayı dene.",
	"duel":"İki başarılı geçişte yeni aşama açılır. Son aşamada rakip serbestçe savunur.",
	"slalom":"Topla birlikte kapıdan geç. Topu yakın tutmak ve hızlı tamamlamak daha çok puan getirir.",
	"passing":"Yerden pası kapının ortasına yaklaştır. Yüksek veya kapı dışına giden top puan getirmez.",
	"shooting":"Gol at; işaretli köşeye yaklaşınca daha yüksek puan kazanırsın.",
	"crossing":"Havadan gelen topu çemberin içine indir. Merkeze yakın iniş daha çok puan getirir.",
	"control":"Pası işaretli alanda karşıla, sonra topu ayağında tutarak çıkış kapısından geç.",
	"penalty":"Altı penaltıda kaleciyi geç. İşaretli köşeye yakın goller daha çok puan getirir.",
	"defending":"Faulsüz top kazanıp üç saniye koru. Rakip çıkışa ulaşmadan müdahale et.",
	"distribution":"Uzun pası uzak kapıya ulaştır. Kapıdan geçerken top yere yakın olmalı."}
const TIPS := {
	"free":"Pas verdikten sonra yeni bir açıya koş.","cross":"Top gelmeden yerini al ve şutunu hazırla.","free_kick":"Önce az güçle dene; mesafeye göre artır.","duel":"Rakip uzanırken yön değiştir, boşluğa hızlan.",
	"slalom":"Kapıya yaklaşırken sprinti bırak; küçük yön değişimleri yap.","passing":"Vurmadan önce kapıyla aynı doğrultuya gel.","shooting":"Dengeni topla ve gücü sonuna kadar doldurmak yerine köşeyi hedefle.","crossing":"Gücü basılı tutup bırak; topun ilk inişini çemberin ortasına yaklaştır.",
	"control":"Topu beklemek yerine karşılama alanına koş. İlk dokunuşunu çıkışa çevir.","penalty":"Köşeyi erken seç ve aşırı güçten kaçın.","defending":"Top rakibin ayağından açılınca müdahale et. Kazandıktan sonra koru.","distribution":"Hedefi ortala; pas gücünü uzaklığa göre ayarla."}

static func focus(mode: String) -> String: return FOCUS.get(mode,"")
static func success(mode: String) -> String: return SUCCESS.get(mode,"")
static func tip(mode: String) -> String: return TIPS.get(mode,"")
static func skill_labels(mode: String) -> String:
	var names:={"control":"Teknik","balance":"Denge","acceleration":"İvme","passing":"Pas","finishing":"Şut","stamina":"Dayanıklılık","defending":"Savunma","strength":"Güç","positioning":"Pozisyon","handling":"Tutuş"}
	var result: Array[String]=[]
	for key in SKILLS.get(mode,[]): result.append(names[key])
	return " · ".join(result)

static func controls(mode: String,game) -> Array:
	var pad: bool=game.controller.using_gamepad
	var move: String="LS" if pad else "YÖN TUŞLARI"
	var action: int=KEY_D
	var verb: String="Şut: tut / bırak"
	match mode:
		"free","passing","distribution": action=KEY_S; verb="Pas: tut / bırak"
		"slalom","control": action=KEY_W; verb="Sprint: tut"
		"cross": action=KEY_D; verb="Kafa / vole"
		"crossing": action=KEY_A; verb="Orta: tut / bırak"
		"defending": action=KEY_G; verb="Müdahale"
		"duel": action=KEY_W; verb="Boşluğa sprint"
	var key: String=game.controller.label_for(action) if pad else OS.get_keycode_string(game.match_menu.key_for(action))
	return [[move,"Yön"],[key,verb]]

static func title(mode: String) -> String: return TITLES[maxi(0,MODES.find(mode))]
static func detail(mode: String) -> String: return DETAILS[maxi(0,MODES.find(mode))]
static func grade(score: int) -> String:
	if score>=85: return "A"
	if score>=70: return "B"
	if score>=55: return "C"
	if score>=35: return "D"
	return "E" if score>0 else "F"
static func options(p: Dictionary) -> Array:
	return ["distribution"] if p.keeper else SCORED.slice(0,7)
static func suggested(p: Dictionary,week: int) -> String:
	if p.keeper: return "distribution"
	var modes: Array=["slalom","control","passing"]
	match int(p.development.plan):
		1: modes=["slalom","control"]
		2: modes=["shooting","penalty","crossing"]
		3: modes=["passing","control","crossing"]
		4: modes=["defending","passing"]
		_:
			if p.role==1: modes=["defending","passing","control"]
			elif p.role==3: modes=["shooting","penalty","slalom"]
	return modes[posmod(week/7+int(p.appearance_id),modes.size())]
