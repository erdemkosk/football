extends RefCounted
var game
var selected := [0,1]
var alternate := [false,false]
var lineups: Array = [range(11),range(11)]
var reserves: Array = [range(11,18),range(11,18)]
const CLUBS := [
	{"name":"KIYI SPOR","short":"KIY","city":"İSTANBUL","year":"1967","primary":"e5ece5","accent":"193d39","shorts":"133933","alt":"193d39","alt_trim":"e5ece5","pattern":0,"style":"KANATLARDAN OYUN","squad":"DENİZ,KAAN,DEMİR,CAN,EMİR,ARAS,MERT,ALP,KEREM,EGE,BORA,EFE,UMUT,TUNA,OZAN,BARAN,YİĞİT,ATA"},
	{"name":"ATLAS FC","short":"ATL","city":"İZMİR","year":"1924","primary":"d34532","accent":"f1d7bd","shorts":"eee3d2","alt":"202f48","alt_trim":"e4ae79","pattern":1,"style":"ÖN ALAN BASKISI","squad":"MARC,LUCA,IVAN,ALEX,THEO,RAFA,OMAR,LEO,NICO,ENZO,SAM,JOEL,MIRO,NOAH,LARS,LUIS,ADAM,FINN"},
	{"name":"DEMİRSPOR","short":"DEM","city":"ANKARA","year":"1938","primary":"2463a3","accent":"b8e6f2","shorts":"102d50","alt":"e7edf2","alt_trim":"235282","pattern":2,"style":"DİSİPLİNLİ SAVUNMA","squad":"VOLKAN,EREN,BERK,ONUR,SERHAT,CEM,SELİM,ERDEM,HAKAN,TOLGA,BATU,SİNAN,AYAZ,DORUK,UFUK,TAYLAN,KORAY,ERAY"},
	{"name":"GÜNEŞ FK","short":"GÜN","city":"ANTALYA","year":"1972","primary":"f2be49","accent":"54253b","shorts":"54253b","alt":"58223d","alt_trim":"f3cc66","pattern":1,"style":"HIZLI GEÇİŞLER","squad":"ARDA,ALPER,İLKER,FIRAT,ENGİN,OKAN,BURAK,DOĞAN,SARP,YAMAN,RÜZGAR,UTKU,ÖMER,İSMAİL,HAMZA,TARIK,ERSEL,CEYHUN"},
	{"name":"ORMAN BİRLİĞİ","short":"ORM","city":"BURSA","year":"1963","primary":"24715b","accent":"eee5ce","shorts":"173c34","alt":"f0e7cf","alt_trim":"24694f","pattern":2,"style":"SABIRLI PAS OYUNU","squad":"YUSUF,ÖZGÜR,MURAT,EMRE,MESUT,SEZER,ORÇUN,CİHAN,İLHAN,HALİL,FATİH,MEHMET,KAHRAMAN,SONER,ŞAHİN,GÖKHAN,ŞENER,İSA"},
	{"name":"KUZEY YILDIZI","short":"KUZ","city":"TRABZON","year":"1955","primary":"7d324c","accent":"77bed6","shorts":"20334a","alt":"79bed3","alt_trim":"733047","pattern":1,"style":"CESUR HÜCUM","squad":"KIVANÇ,ADİL,AYKUT,MUZAFFER,YAVUZ,LEVENT,ENGİNCAN,TAMER,ORHAN,TUNCAY,HAKAN,ERGİN,AZİZ,İRFAN,KEMAL,BİLAL,ZAFER,MELİH"},
	{"name":"LİMAN ATHLETIC","short":"LİM","city":"MERSİN","year":"1981","primary":"243346","accent":"f1f0df","shorts":"1a2636","alt":"f0eee3","alt_trim":"29384f","pattern":0,"style":"KOMPAKT BLOK","squad":"DIEGO,BRUNO,HUGO,TIAGO,ANDRE,MATEO,OSCAR,PABLO,ELIAS,MARCO,FELIX,RENE,LOREN,JORGE,DARIO,INES,TONI,VICTOR"},
	{"name":"KAPADOKYA SK","short":"KAP","city":"NEVŞEHİR","year":"1969","primary":"8d629d","accent":"f0ded1","shorts":"422d58","alt":"eee0cf","alt_trim":"705180","pattern":2,"style":"YARATICI ORTA SAHA","squad":"CANER,BARIŞ,BERAT,BULUT,İHSAN,ENES,İBRAHİM,FERHAT,SEFA,FURKAN,BATUHAN,RECEP,SALİH,AHMET,MAHMUT,NECATİ,KAĞAN,SERDAR"}]

func data(side: int) -> Dictionary:
	return CLUBS[selected[side]]

func kit(side: int) -> Dictionary:
	var club := data(side)
	return {"primary":Color(club.alt if alternate[side] else club.primary),"accent":Color(club.alt_trim if alternate[side] else club.accent),"shorts":Color(club.alt if alternate[side] else club.shorts),"pattern":int(club.pattern)}

func choose(side: int,id: int) -> void:
	var direction := -1 if id<selected[side] else 1
	selected[side]=posmod(id,CLUBS.size())
	if selected[side]==selected[1-side]: selected[side]=posmod(selected[side]+direction,CLUBS.size())
	lineups[side]=range(11)
	reserves[side]=range(11,18)
	alternate[side]=false
	# Start visually similar pairs in contrasting strips; both can still be chosen.
	var a := Color(data(0).primary)
	var b := Color(data(1).primary)
	if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<0.4: alternate[1]=true
	apply()

func member(side: int,id: int) -> Dictionary:
	var names: PackedStringArray=data(side).squad.split(",")
	return {"name":names[id],"shirt":id+1,"keeper":id in [0,11],"used":false}

func swap_starter(slot: int,reserve: int) -> bool:
	var a: int=lineups[0][slot]
	var b: int=reserves[0][reserve]
	if member(0,a).keeper!=member(0,b).keeper: return false
	lineups[0][slot]=b
	reserves[0][reserve]=a
	apply()
	return true

func apply() -> void:
	game.management.originals.clear()
	game.management.reserve_originals=[[],[]]
	for side in range(2):
		for slot in range(11):
			var identity := member(side,lineups[side][slot])
			game.management.originals.append(identity)
			var p=game.players[side*11+slot]
			p.apply_kit(kit(side))
		for id in reserves[side]: game.management.reserve_originals[side].append(member(side,id))
	game.management.reset()
	if game.stadium.sidelines.team_labels.size()==2:
		for side in range(2): game.stadium.sidelines.team_labels[side].text=data(side).name+" · YEDEK KULÜBESİ"
	for actor in game.stadium.sidelines.actors:
		if actor.role=="substitute":
			actor.kit_material.albedo_color=kit(actor.team).primary
			actor.bib_material.albedo_color=kit(actor.team).accent.lerp(Color("9eae97"),0.5)
	for caption in game.stadium.architecture.team_captions: caption.text=data(0).short+"       "+data(1).short
