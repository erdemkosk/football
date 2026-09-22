extends RefCounted
const NATIONS:={"TR":"TÜRKİYE","ES":"İSPANYA","PT":"PORTEKİZ","IT":"İTALYA","DE":"ALMANYA","FR":"FRANSA","GB":"İNGİLTERE","NL":"HOLLANDA","BR":"BREZİLYA","AR":"ARJANTİN","HR":"HIRVATİSTAN","NG":"NİJERYA","JP":"JAPONYA"}
const LEAGUE_NATIONS:=["TR","TR","ES","PT","IT","DE","FR","GB","NL","TR"]
const CITIES:={"ES":["VALENCIA","SEVILLA","BILBAO","MÁLAGA","ZARAGOZA","VIGO"],"PT":["BRAGA","COIMBRA","FARO","AVEIRO","VISEU","SETÚBAL"],"IT":["TORINO","NAPOLI","FIRENZE","GENOVA","BOLOGNA","VERONA"],"DE":["HAMBURG","KÖLN","BREMEN","DRESDEN","MAINZ","HANNOVER"],"FR":["LILLE","NANTES","NICE","BORDEAUX","TOULOUSE","RENNES"],"GB":["YORK","BRISTOL","OXFORD","LEEDS","DERBY","EXETER","BATH"],"NL":["UTRECHT","DELFT","BREDA","LEIDEN","ZWOLLE","ARNHEM","GOUDA"]}
const POOLS:={
	"ES":[["DIEGO","ÁLVARO","MATEO","PABLO"],["MORENO","ROMERO","SERRANO","VEGA"]],
	"PT":[["RAFAEL","TIAGO","DUARTE","JOÃO"],["COSTA","FERREIRA","NUNES","PINTO"]],
	"IT":[["LUCA","MARCO","ANDREA","LORENZO"],["ROSSI","CONTI","MORETTI","RINALDI"]],
	"DE":[["LUKAS","LEON","FELIX","JONAS"],["WEBER","FISCHER","KELLER","BRAUN"]],
	"FR":[["HUGO","LOUIS","JULES","THÉO"],["MARTIN","MOREAU","GARNIER","DUBOIS"]],
	"GB":[["OLIVER","JACK","HARRY","THEO"],["WALKER","CLARKE","BROWN","HARRIS"]],
	"NL":[["DAAN","LUUK","FINN","SEM"],["DE VRIES","VAN DIJK","BAKKER","VISSER"]],
	"BR":[["CAIO","PEDRO","GABRIEL","MATHEUS"],["SILVA","SANTOS","ALMEIDA","ROCHA"]],
	"AR":[["ENZO","JULIÁN","TOMÁS","NICOLÁS"],["MOLINA","FERNÁNDEZ","ACOSTA","MEDINA"]],
	"HR":[["LUKA","IVAN","MARKO","ANTE"],["KOVAČ","BABIĆ","HORVAT","JURIĆ"]],
	"NG":[["CHIDI","EMEKA","FEMI","TUNDE"],["OKORO","ADEYEMI","NWOSU","BALOGUN"]],
	"JP":[["REN","HARUTO","YUTO","SOTA"],["TANAKA","SATO","NAKAMURA","ITO"]]}
const CLUBS:=[
	["MADRID AURORA","MAD","MADRID","ES","f1ece0","233557"],
	["BARCELONA MARINA","BCM","BARCELONA","ES","184d83","dbb44a"],
	["LISBOA ATLÂNTICO","LIS","LİZBON","PT","bd283b","efe6d4"],
	["PORTO ESTRELA","PES","PORTO","PT","267d9e","eeeeec"],
	["MILANO STELLA","MIL","MİLANO","IT","28394d","d9b570"],
	["ROMA AURELIA","ROM","ROMA","IT","922f39","e7bd66"],
	["BERLIN ADLER","BER","BERLİN","DE","f0ebe1","253329"],
	["MÜNCHEN WALD","MUN","MÜNİH","DE","245c49","daceaa"],
	["PARIS LUMIÈRE","PAR","PARİS","FR","253b6d","e2ba84"],
	["LYON RIVIÈRE","LYO","LYON","FR","c5d7df","23475d"],
	["LONDON BOROUGH","LON","LONDRA","GB","833d51","efe2ce"],
	["AMSTERDAM HAVEN","AMS","AMSTERDAM","NL","d56835","efe6d0"]]

static func nationality(p: Dictionary,home: String="TR",rename: bool=false) -> void:
	if p.has("nationality"): return
	var serial: int=p.appearance_id
	var codes: Array=POOLS.keys()
	p.nationality=home if serial%5<3 else codes[posmod(serial*17+serial/7,codes.size())]
	if rename and p.nationality!="TR":
		var pool: Array=POOLS[p.nationality]
		p.name=pool[0][serial%4]+" "+pool[1][(serial/4)%4]

static func expand(w: Dictionary) -> void:
	for c in w.clubs.values():
		if not c.has("nation"): c.nation="TR"
	for p in w.players.values(): nationality(p)
	for i in range(CLUBS.size()):
		var id:="c%02d" % (36+i)
		if w.clubs.has(id): continue
		var info: Array=CLUBS[i]
		var c: Dictionary=w.clubs.c00.duplicate(true)
		c.merge({"id":id,"name":info[0],"short":info[1],"city":info[2],"nation":info[3],"primary":info[4],"accent":info[5],"shorts":info[4],"alt":info[5],"alt_trim":info[4],"pattern":i%3,"badge_id":36+i,"league":2,"year":str(1902+i*3),"reputation":86-i%6,"roster":[],"lineup":[],"cash":24000000-i*500000,"budget":16000000-i*300000,"objective":"Avrupa şampiyonluğu"},true)
		var source: Array=w.clubs.c00.roster
		for n in range(24):
			var p: Dictionary=w.players[source[n%source.size()]].duplicate(true)
			var serial: int=w.next_player; w.next_player+=1
			p.merge({"id":"p%04d" % serial,"career_id":"p%04d" % serial,"appearance_id":serial,"club":id,"shirt":n+1,"age":19+(n*7+i*3)%15,"contract":w.year+2+n%3,"fitness":1.0,"form":0.0,"morale":.7,"banned":0,"yellow":0,"injury":0,"listed":false,"loan_listed":n>=18,"goals":0,"appearances":0,"used":false,"loan":{},"retired":false,"retirement_year":0},true)
			p.erase("nationality"); nationality(p,info[3],true)
			p.retirement_age=(36 if p.keeper else 34)+posmod(serial*13+p.role*7,5)
			for key in p.attributes:
				if key in ["preferred_foot","weak_foot","archetype"]: continue
				p.attributes[key]=clampi(int(p.attributes[key])+int(c.reputation)-83+(n%3)-1,35,95)
			p.wage=maxi(1500,roundi(p.wage*(1.1+i*.01)/500)*500)
			w.players[p.id]=p; c.roster.append(p.id)
			if n<11: c.lineup.append(p.id)
		w.clubs[id]=c
	complete_leagues(w)

static func complete_leagues(w: Dictionary) -> void:
	for c in w.clubs.values():
		if c.nation!="TR": c.league=LEAGUE_NATIONS.find(c.nation)
	var serial:=48
	for league in range(2,9):
		var country: String=LEAGUE_NATIONS[league]
		var count: int=w.clubs.values().filter(func(c): return c.nation==country).size()
		for n in range(8-count):
			while w.clubs.has("c%02d" % serial): serial+=1
			var id:="c%02d" % serial; var c: Dictionary=w.clubs["c36"].duplicate(true)
			var city: String=CITIES[country][n]
			c.merge({"id":id,"nation":country,"league":league,"city":city,"name":city+" "+["UNITED","SPORT","FC","ATHLETIC"][n%4],"short":city.left(3),"badge_id":serial,"reputation":74+n%5,"roster":[],"lineup":[],"cash":13000000,"budget":7000000,"objective":"İlk yarı","primary":Color.from_hsv(fmod(serial*.137,1),.65,.65).to_html(false),"accent":"eee5ce"},true)
			for j in range(24):
				var p: Dictionary=w.players[w.clubs.c36.roster[j%w.clubs.c36.roster.size()]].duplicate(true)
				var number: int=w.next_player; w.next_player+=1
				p.merge({"id":"p%04d" % number,"career_id":"p%04d" % number,"appearance_id":number,"club":id,"age":18+(number*7)%16,"contract":w.year+2+j%3,"loan":{},"retired":false,"retirement_year":0},true)
				p.merge({"fitness":1.0,"form":0.0,"morale":.7,"banned":0,"yellow":0,"injury":0,"listed":false,"loan_listed":j>=18,"goals":0,"appearances":0,"minutes":0,"recent_minutes":[],"promise":{},"concern":"","used":false,"shirt":j+1},true)
				p.erase("development"); p.erase("terms"); p.erase("nationality"); nationality(p,country,true)
				p.retirement_age=(36 if p.keeper else 34)+posmod(number*13+p.role*7,5)
				for key in p.attributes:
					if not key in ["preferred_foot","weak_foot","archetype"]: p.attributes[key]=clampi(p.attributes[key]-8+n%4,35,92)
				p.wage=maxi(1500,roundi(p.wage*.7/500)*500)
				w.players[p.id]=p; c.roster.append(p.id)
				if j<11: c.lineup.append(p.id)
			w.clubs[id]=c; serial+=1
