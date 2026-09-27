extends RefCounted
## Authored, reciprocal rivalries use immutable club IDs, never league position.
## Promotion, relegation, renaming and transfers cannot redraw the derby map.
const PAIRS:=[
	["c00","c06","KIYI DERBİSİ",.95], ["c01","c03","ZİRVE REKABETİ",1.0],
	["c02","c11","DEMİR DERBİSİ",.90], ["c04","c14","YEŞİL VADİ REKABETİ",.85],
	["c05","c15","KUZEY–BATI REKABETİ",.85], ["c07","c12","GÜNEŞ DERBİSİ",.80],
	["c08","c09","GÖLLER REKABETİ",.85], ["c10","c13","İKİ KIYI REKABETİ",.80],
	["c16","c17","YILDIZLAR REKABETİ",.85],
	["c18","c27","LİMAN DERBİSİ",.85], ["c19","c24","ALTIN KIYI REKABETİ",.80],
	["c20","c30","SONBAHAR DERBİSİ",.80], ["c21","c29","GÖL–TEPE REKABETİ",.85],
	["c22","c28","DOĞU RÜZGÂRI REKABETİ",.80], ["c23","c25","TEPE DERBİSİ",.85],
	["c26","c33","MAVİ KIYI REKABETİ",.80], ["c31","c35","GÜNEŞ–ALTIN REKABETİ",.85],
	["c32","c34","AKŞAM DERBİSİ",.80],
	["c36","c37","İSPANYA KLASİĞİ",1.0], ["c38","c39","PORTEKİZ KLASİĞİ",1.0],
	["c40","c41","İTALYA KLASİĞİ",.95], ["c42","c43","ALMANYA KLASİĞİ",.95],
	["c44","c45","FRANSA KLASİĞİ",.95],
	["c48","c49","İBERYA REKABETİ",.80], ["c50","c52","KUZEY İSPANYA DERBİSİ",.85],
	["c51","c53","İKİ KIYI DERBİSİ",.80],
	["c54","c58","KUZEY PORTEKİZ REKABETİ",.80], ["c55","c57","MERKEZ PORTEKİZ DERBİSİ",.85],
	["c56","c59","GÜNEY PORTEKİZ REKABETİ",.85],
	["c60","c61","KUZEY–GÜNEY KLASİĞİ",.90], ["c62","c64","APENİN DERBİSİ",.85],
	["c63","c65","İTALYA REKABETİ",.80],
	["c66","c68","KUZEY ALMANYA DERBİSİ",.90], ["c67","c70","REN REKABETİ",.85],
	["c69","c71","ALMANYA REKABETİ",.80],
	["c72","c76","KUZEY–GÜNEY REKABETİ",.85], ["c73","c77","BATI FRANSA DERBİSİ",.90],
	["c74","c75","GÜNEY FRANSA REKABETİ",.85],
	["c46","c80","İNGİLTERE REKABETİ",.95], ["c78","c81","YORKSHIRE DERBİSİ",.90],
	["c79","c84","BATI İNGİLTERE DERBİSİ",.90], ["c82","c83","İNGİLTERE KUPA REKABETİ",.80],
	["c47","c85","KANALLAR DERBİSİ",.95], ["c86","c88","GÜNEY HOLLANDA DERBİSİ",.85],
	["c87","c91","HOLLANDA REKABETİ",.80], ["c89","c90","DOĞU HOLLANDA DERBİSİ",.90],
	# The city triangle precedes secondary rivalries so each Istanbul club has a local primary rival.
	["tr00","tr01","BOĞAZ DERBİSİ",1.0],
	["tr00","tr02","İSTANBUL DERBİSİ",1.0], ["tr01","tr02","İSTANBUL DERBİSİ",1.0],
	["tr02","tr05","BAŞKENT–BOĞAZ REKABETİ",.90],
	["tr03","tr14","DOĞU KARADENİZ DERBİSİ",.95], ["tr04","tr16","MARMARA DERBİSİ",.90],
	["tr06","tr07","KIYI REKABETİ",.85], ["tr08","tr17","ANADOLU REKABETİ",.85],
	["tr09","tr12","DEMİRYOLU DERBİSİ",.90], ["tr10","tr13","GÜNEY DERBİSİ",.90],
	["tr11","tr15","İÇ ANADOLU DERBİSİ",.90]
]
const GROUPS:=["KALE ARKASI","ARMA BİRLİĞİ","RENKDAŞLAR","SON DÜDÜK","TRİBÜN BİRLİĞİ","ŞEHİR TAYFASI","VEFALI TRİBÜN","ON İKİNCİ ADAM"]
const MOTTOS:=["HER YERDE SENİNLEYİZ","BU ARMA İÇİN","SON DÜDÜĞE KADAR","RENKLERİMİZLE BİRLİKTE","İNANÇLA OMUZ OMUZA","ŞEHRİN SESİ BİZİZ","HEP AYNI SEVDA","BİR TAKIM BİR YÜREK"]

static func rivals(id: String) -> Array:
	var result: Array=[]
	for pair in PAIRS:
		if pair[0]==id: result.append(pair[1])
		elif pair[1]==id: result.append(pair[0])
	return result

static func match_info(home: String,away: String) -> Dictionary:
	if home==away: return {}
	for pair in PAIRS:
		if (pair[0]==home and pair[1]==away) or (pair[1]==home and pair[0]==away):
			return {"title":pair[2],"heat":pair[3],"home":home,"away":away}
	return {}

static func supporters(id: String,club: Dictionary) -> Dictionary:
	var index:=absi(id.hash())
	return {"name":str(club.get("short","FC"))+" · "+GROUPS[index%GROUPS.size()],"motto":MOTTOS[(index/7)%MOTTOS.size()],"chant":index%3,"tempo":.97+(index%7)*.01,"pattern":index%4}

static func ensure(w: Dictionary) -> void:
	for id in w.clubs:
		w.clubs[id].rivals=rivals(id).filter(func(other): return w.clubs.has(other))
		w.clubs[id].supporters=supporters(id,w.clubs[id])

static func fixture(f: Dictionary) -> Dictionary:
	return match_info(str(f.get("home","")),str(f.get("away","")))

static func label(club: Dictionary,clubs: Dictionary) -> String:
	var names: Array=[]
	for id in rivals(str(club.get("id",""))):
		if clubs.has(id): names.append(clubs[id].name)
	return " · ".join(names)
