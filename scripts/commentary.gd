extends RefCounted
## Turkish match commentary spoken by the operating system's own speech engine
## (DisplayServer TTS): no recordings are bundled and player names are read
## live. Lines follow real match events; a small priority queue avoids
## repeats, never talks over a goal and falls silent while the game is paused.
const LINES := {
	"kickoff":["Ve maç başlıyor!","Hakemin düdüğüyle mücadele başladı.","Santra yapıldı, top oyunda."],
	"second_half":["İkinci yarı başladı.","Takımlar yeniden sahada, ikinci yarı başlıyor."],
	"goal":["Gol! {name} ağları sarsıyor!","Ve gol! {name}!","Gooool! {name} affetmiyor!","Muhteşem bir gol! {name}!"],
	"own_goal":["Kendi kalesine! Talihsiz bir an.","Kendi kalesine gol! {name} için kötü bir an."],
	"shot_high":["Top üstten auta gitti.","Fazla sert vurdu, top üstten dışarıda.","Çok güçlü, top tribünlere gidiyor."],
	"shot_wide":["Az farkla dışarıda.","Top direğin yanından auta çıktı.","Kaleyi bulamadı."],
	"save":["Kaleci yerinde.","{name} kurtarıyor.","Güzel kurtarış."],
	"great_save":["Müthiş bir kurtarış!","{name} harika uzandı!","İnanılmaz bir refleks!"],
	"woodwork":["Direk!","Top direkten döndü!","Üst direk! Kıl payı!"],
	"corner":["Korner.","Köşe vuruşu kazanıldı.","Top kornere çıktı."],
	"free_kick":["Faul, serbest vuruş.","Hakem düdüğü çaldı, serbest vuruş."],
	"penalty":["Penaltı!","Hakem beyaz noktayı gösteriyor!"],
	"offside":["Ofsayt bayrağı kalkıyor.","Ofsayt."],
	"yellow":["Sarı kart. {name} uyarıldı.","Hakem sarı kartını çıkarıyor."],
	"red":["Kırmızı kart! {name} oyundan atılıyor!","Oyundan atılma! Takım on kişi kalıyor."],
	"handball":["Elle oynama!","Topa elle müdahale, düdük geliyor."],
	"injury":["{name} yerde kaldı, sakatlık var gibi.","{name} topallıyor, bu iyi görünmüyor."],
	"halftime":["İlk yarı sona erdi.","Hakem ilk yarıyı bitiriyor."],
	"fulltime":["Son düdük! Maç sona erdi.","Ve maç bitti!"],
	"substitution":["Oyuncu değişikliği.","Kenardan bir değişiklik geliyor."],
	"long_shot":["Uzaktan deniyor!","Şut, uzak mesafeden!"],
	"header":["Kafa vuruşu!","Kafayla vuruyor!"],
	"skill":["Ne güzel bir hareket!","{name} rakibini çalımlıyor.","Şık bir çalım!"]}
## Higher priorities interrupt and are never dropped.
const PRIORITY := {"goal":5,"own_goal":5,"red":5,"penalty":4,"fulltime":4,"halftime":4,"woodwork":3,"great_save":3,"handball":3,"kickoff":3,"second_half":3,"yellow":2,"injury":2,"shot_high":2,"shot_wide":2,"save":2,"offside":2,"corner":1,"free_kick":1,"substitution":1,"long_shot":1,"header":1,"skill":0}
const GAP := 2.6
var game
var enabled := true
var volume := .8
var subtitles := false
var voice := ""
var cooldown := 0.0
var recent: Dictionary = {}
var history: Array[String] = []
var subtitle := ""
var subtitle_time := 0.0
var last_priority := -1

func reset() -> void:
	cooldown=0; recent.clear(); history.clear(); subtitle=""; subtitle_time=0; last_priority=-1
	stop()

func available() -> bool:
	return DisplayServer.get_name()!="headless" and enabled

func pick_voice() -> String:
	if voice!="": return voice
	var voices: PackedStringArray=DisplayServer.tts_get_voices_for_language("tr")
	if voices.is_empty(): voices=DisplayServer.tts_get_voices_for_language("en")
	if not voices.is_empty(): voice=voices[0]
	return voice

func event(kind: String,data: Dictionary={}) -> void:
	if not LINES.has(kind) or game.training or game.menu_match.running: return
	var priority: int=int(PRIORITY.get(kind,0))
	# Low-priority chatter waits its turn; important calls cut in.
	if cooldown>0 and priority<=last_priority and priority<3: return
	var lines: Array=LINES[kind]
	var last: int=int(recent.get(kind,-1))
	var choice: int=(last+1+int(data.get("seed",history.size())))%lines.size()
	if choice==last and lines.size()>1: choice=(choice+1)%lines.size()
	recent[kind]=choice
	var text: String=String(lines[choice]).format({"name":str(data.get("name","")),"team":str(data.get("team_name",""))})
	say(text,priority)

func say(text: String,priority: int) -> void:
	history.append(text)
	if history.size()>40: history.pop_front()
	subtitle=text; subtitle_time=3.4
	cooldown=GAP; last_priority=priority
	if not available(): return
	var id := pick_voice()
	if id=="": return
	DisplayServer.tts_speak(text,id,clampi(roundi(volume*100),0,100),1.0,1.05,0,priority>=3)

func stop() -> void:
	if DisplayServer.get_name()!="headless": DisplayServer.tts_stop()

func update(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	subtitle_time=maxf(0,subtitle_time-delta)
	if cooldown<=0: last_priority=-1
	if game.state in ["paused","menu"] and DisplayServer.get_name()!="headless" and DisplayServer.tts_is_speaking(): DisplayServer.tts_stop()

func draw(hud) -> void:
	if not subtitles or subtitle_time<=0 or subtitle=="" or game.state in ["menu","paused"]: return
	var alpha: float=clampf(subtitle_time/.4,0,1)
	var width: float=hud.font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+36
	var at: Vector2=Vector2(720-width*.5,742)+game.ui.edge_offset(0,1)
	hud.panel(Rect2(at,Vector2(width,30)),Color(0.04,0.08,0.1,.78*alpha),6)
	hud.draw_string(hud.font,at+Vector2(18,21),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.96,0.94,0.87,alpha))
