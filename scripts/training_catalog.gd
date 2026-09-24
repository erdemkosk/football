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
