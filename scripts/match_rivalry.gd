extends RefCounted
const Rivals=preload("res://scripts/rivalries.gd")
var info: Dictionary={}
var home_team:=0
var profiles: Array=[]
var active:=false

func preview(clubs) -> Dictionary:
	return Rivals.match_info(clubs.match_id(0),clubs.match_id(1))

func begin(game,practice: bool,background: bool) -> void:
	info=preview(game.clubs); active=not info.is_empty() and not practice and not background
	home_team=0 if practice or background else host_side(game)
	var home: Dictionary=game.clubs.data(home_team); var away: Dictionary=game.clubs.data(1-home_team)
	game.stadium.select_home(home,game.clubs.match_id(home_team),practice)
	profiles=[Rivals.supporters(game.clubs.match_id(home_team),home),Rivals.supporters(game.clubs.match_id(1-home_team),away)]
	var heat: float=float(info.get("heat",0)) if active else 0.0
	game.audio.derby_heat=heat; game.audio.home_team=home_team
	game.audio.chant_order=[profiles[0].chant,profiles[1].chant,(int(profiles[0].chant)+1)%3]
	game.audio.chant_tempos=[profiles[0].tempo,profiles[1].tempo,profiles[0].tempo]
	game.stadium.crowd.derby_heat=heat; game.stadium.crowd.home_team=home_team
	game.stadium.crowd.set_clubs(game.clubs.kit(home_team),game.clubs.kit(1-home_team))
	game.stadium.supporters.configure(game,home,away,profiles,heat)
	for banner in game.stadium.supporter_banners:
		var identity: Dictionary=profiles[1 if banner.away else 0]
		banner.label.text=identity.name if banner.section==0 else identity.motto if banner.section==1 else ("DERBİ GÜNÜ" if active else "SON DÜDÜĞE KADAR")

func caption() -> String:
	return str(info.get("title","")) if active else ""

func host_side(game) -> int:
	if game.career.in_match:
		for fixture in game.career.cups.all_fixtures():
			if fixture.id==game.career.fixture_id:
				return 0 if fixture.home==game.clubs.match_id(0) else 1
	return 0
