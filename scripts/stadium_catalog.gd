extends RefCounted
## Club-owned venue identity, independent of form, promotion and the match RNG.
const KINDS := ["town","compact","modern","historic"]
const LABELS := {"town":"ŞEHİR STADI","compact":"KOMPAKT STAT","modern":"MODERN ARENA","historic":"TARİHİ STAT"}
const LOCAL := ["modern","modern","historic","compact","town","historic","town","compact"]
const NAMES := {
	"town":["ÇINAR PARK","YELKEN PARK","SÖĞÜT PARK","GÜNEŞ PARK"],
	"compact":["ÇEMBER STADI","YANKI STADI","KUZEY KAPISI","BİRLİK STADI"],
	"modern":["UFUK ARENA","IŞIK ARENA","MERİDYEN ARENA","YENİ ŞEHİR ARENA"],
	"historic":["DEMİRYOLU STADI","ESKİ ÇINAR STADI","TAŞKAPI STADI","SAAT KULESİ STADI"]}

static func assignment(club: Dictionary,id: String) -> Dictionary:
	var seed_value := int(id.hash())
	var kind := str(club.get("stadium_kind",""))
	# Expansion code can clone a club template. Never inherit its stadium.
	var owned: bool=str(club.get("stadium_owner",id))==id
	if kind not in KINDS or not owned:
		var local_index := int(id.substr(1)) if id.begins_with("c") else -1
		if local_index>=0 and local_index<LOCAL.size(): kind=LOCAL[local_index]
		else:
			var reputation := int(club.get("reputation",65))
			var old := int(club.get("year",1950))<1935
			var traditional: bool=str(club.get("nation","")) in ["GB","IT","DE"]
			if reputation>=80: kind="historic" if old and traditional and posmod(seed_value,3)==0 else "modern"
			elif reputation<61: kind="town"
			elif old and (traditional or posmod(seed_value,3)==0): kind="historic"
			else: kind="compact" if reputation>=68 or posmod(seed_value,3)!=0 else "town"
	var title := str(club.get("stadium_name","")) if owned else ""
	if title.is_empty(): title=str(club.get("city",club.get("short","SEFC")))+" · "+str(NAMES[kind][posmod(seed_value,4)])
	return {"kind":kind,"name":title,"owner":id,"label":LABELS[kind]}

static func ensure(world: Dictionary) -> void:
	for id in world.clubs:
		var club: Dictionary=world.clubs[id]
		var venue := assignment(club,str(id))
		club.stadium_kind=venue.kind; club.stadium_name=venue.name; club.stadium_owner=id
