extends RefCounted
## Fictional Turkish clubs, separate from the two original SEFC divisions.
const Attributes=preload("res://scripts/player_attributes.gd")
const Physique=preload("res://scripts/player_physique.gd")
const International=preload("res://scripts/career_international.gd")
const LEAGUE:=9
const CLUBS:=[
	["BOĞAZİÇİ YILDIZ","BOY","İSTANBUL",1912,"192f65","eed258",84],
	["İSTANBUL HİLAL","İHL","İSTANBUL",1909,"a3293d","edb950",83],
	["KARAKÖY KARTALLARI","KKA","İSTANBUL",1918,"e5e8e5","242b37",81],
	["TRABZON FIRTINA","TRF","TRABZON",1969,"76354b","66bbd7",79],
	["BURSA İPEK","BİP","BURSA",1964,"247957","f0ecd9",76],
	["ANKARA KALESİ","ANK","ANKARA",1924,"a13934","172b47",75],
	["İZMİR KÖRFEZ","İZK","İZMİR",1931,"283b62","e6e1d1",74],
	["ANTALYA AKDENİZ","AAD","ANTALYA",1968,"c44443","f1eee5",73],
	["SAMSUN MARTI","SMA","SAMSUN",1966,"cf4c4d","242c3d",73],
	["KONYA SELÇUK","KSE","KONYA",1932,"3d7869","e5e6ca",72],
	["ADANA TOROS","ATO","ADANA",1956,"367fab","192f57",72],
	["KAYSERİ ERCİYES YILDIZI","KEY","KAYSERİ",1971,"d8a73e","7c2940",71],
	["ESKİŞEHİR LOKOMOTİF","ELK","ESKİŞEHİR",1967,"1f2835","c64c46",70],
	["GAZİANTEP BAKIR","GBA","GAZİANTEP",1972,"963943","d49b66",70],
	["RİZE ÇAYLIKKENT","RÇK","RİZE",1954,"267957","71bace",69],
	["SİVAS KALE","SVK","SİVAS",1968,"dcdedb","a33b48",68],
	["KOCAELİ KÖRFEZ GÜCÜ","KKG","KOCAELİ",1967,"266f57","202c35",67],
	["DİYARBAKIR SURLARI","DSR","DİYARBAKIR",1969,"467b63","b24442",66]
]
const NAMES:=["ARDA","KEREM","YUSUF","FERDİ","SALİH","İRFAN","MERT","OĞUZ","EMİRHAN","ERTUĞRUL","CENK","BERAT","KAAN","ALPER","EMRE","ORHAN","TAYLAN","SERHAT","BATUHAN","BURAK","HALİL","OKAN","BARIŞ","ENES","UMUT","FURKAN","YUNUS","ABDÜLKADİR","DOĞUKAN","EREN","BERKAY","GÖKHAN"]
const SURNAMES:=["KARACA","YILDIZ","KORKMAZ","TEKİN","DOĞAN","YÜCEL","ŞAHİN","TUNÇ","ÖZDEMİR","KAPLAN","BULUT","KESKİN","TAŞ","KURT","YAVUZ","ÖZKAN","AKIN","ERDOĞAN","KOCAMAN","SARI","GÜLER","YÜKSEL","ÇAKIR","ALBAYRAK","ÇETİN","AYDIN","KILIÇ","DEMİRCİ","KIRAN","GÜNEŞ","ERDEM","ULUSOY"]

static func expand(w: Dictionary,base_plan: Dictionary) -> Array:
	var added: Array=[]
	for i in range(CLUBS.size()):
		var id:="tr%02d" % i
		if w.clubs.has(id): continue
		var info: Array=CLUBS[i]; var strength: int=info[6]
		var p: Dictionary=base_plan.duplicate(true)
		p.formation=i%3; p.mentality=[2,1,2,1,0][i%5]; p.pressing=2 if i<5 else 1
		p.line_height=2 if i<3 else 1; p.width=2 if i%3==0 else 1
		var plans: Array=[base_plan.duplicate(true),p.duplicate(true),base_plan.duplicate(true)]
		plans[0].mentality=0; plans[0].pressing=0; plans[0].line_height=0
		plans[2].mentality=2; plans[2].pressing=2; plans[2].line_height=2
		var c:={"id":id,"name":info[0],"short":info[1],"city":info[2],"year":str(info[3]),"nation":"TR","league":LEAGUE,"badge_id":92+i,"primary":info[4],"accent":info[5],"shorts":info[4],"alt":info[5],"alt_trim":info[4],"pattern":i%3,"style":["ÖN ALAN BASKISI","SABIRLI PAS OYUNU","KANATLARDAN OYUN","HIZLI GEÇİŞ OYUNU"][i%4],"roster":[],"lineup":[],"plan":p,"plans":plans,"objective":"Şampiyonluk" if i<4 else ("İlk yarı" if i<11 else "Takımı geliştir"),"reputation":strength,"cash":int(1600000+pow(strength-40,2)*13500),"budget":int(850000+pow(strength-40,2)*8000)}
		var rng:=RandomNumberGenerator.new(); rng.seed=73097+i*199
		for j in range(24):
			# New identities never reuse an academy or transferred player's saved ID.
			while w.players.has("p%04d" % int(w.next_player)): w.next_player+=1
			var serial: int=w.next_player; w.next_player+=1
			var pid:="p%04d" % serial
			var role: int=0 if j in [0,11] else (1 if j in [1,2,3,4,12,13,18,19] else (3 if j in [9,10,16,17,23] else 2))
			var stats:=Attributes.profile(92+i,j,role==0)
			var offset: int=strength-74+rng.randi_range(-4,4)-(5 if j>17 else 0)
			for key in Attributes.KEYS: stats[key]=clampi(stats[key]+offset,35,95)
			for key in ["passing","defending","strength","stamina","reflexes","handling","positioning"]:
				var bonus: int=6 if (key=="passing" and role==2) or (key=="defending" and role==1) or (key in ["reflexes","handling","positioning"] and role==0) else 0
				stats[key]=clampi(strength+rng.randi_range(-8,5)+bonus-(8 if key=="defending" and role==3 else 0),35,95)
			# Distribute imports across the starting eleven AND bench, rather than a block.
			# This is an initial squad mix, not a nationality-based registration restriction.
			var foreign: bool=(j*7+i)%24<10+i%5
			var country: String=International.POOLS.keys()[(j+i*5)%International.POOLS.size()] if foreign else "TR"
			var name: String=NAMES[(i*5+j)%NAMES.size()]+" "+SURNAMES[(i*7+j*3)%SURNAMES.size()]
			if foreign:
				var names: Array=International.POOLS[country]
				name=names[0][(i+j)%4]+" "+names[1][(i+j/4)%4]
			var member:={"id":pid,"career_id":pid,"club":id,"name":name,"nationality":country,"shirt":j+1,"role":role,"keeper":role==0,"attributes":stats,"appearance_id":serial,"age":rng.randi_range(18,33),"potential":mini(96,strength+rng.randi_range(3,12)),"contract":w.year+rng.randi_range(1,4),"wage":0,"squad_role":1,"fitness":1.0,"form":0.0,"morale":.7,"banned":0,"yellow":0,"injury":0,"listed":false,"loan_listed":false,"goals":0,"appearances":0,"used":false}
			member.merge(Physique.profile(92+i,j,role==0)); member.loan_listed=j>=18 and member.age<=25
			w.players[pid]=member; c.roster.append(pid); added.append(pid)
			if j<11: c.lineup.append(pid)
		w.clubs[id]=c
	return added
