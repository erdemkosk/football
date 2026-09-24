extends RefCounted
const UI=preload("res://scripts/ui_style.gd")
const SORTS=["GÜÇ · yüksekten","HIZ · yüksekten","KONDİSYON · yüksekten","FORM · yüksekten","BEDEL · düşükten"]

static func sort_players(s) -> void:
	var c=s.game.career
	s.list_ids.sort_custom(func(a,b):
		var x: Dictionary=c.player(a); var y: Dictionary=c.player(b)
		var vx: float=value(s,x); var vy: float=value(s,y)
		if is_equal_approx(vx,vy): return x.name.naturalnocasecmp_to(y.name)<0
		return vx<vy if s.player_sort==4 else vx>vy)

static func value(s,p: Dictionary) -> float:
	match s.player_sort:
		1: return p.attributes.pace
		2: return p.fitness
		3: return p.form
		4: return 0 if p.club=="" else s.game.career.market.value(p)
	return s.World.ovr(p)

static func toolbar(s) -> void:
	s.option_at(Rect2(174,751,190,42),["KART GÖRÜNÜMÜ","LİSTE GÖRÜNÜMÜ"],int(s.list_view),func(v): s.list_view=v==1; s.build()).set_meta("focus_key","player_view")
	s.option_at(Rect2(376,751,245,42),SORTS,s.player_sort,func(v): s.player_sort=v; sort_players(s); s.list_page=maxi(0,s.list_ids.find(s.selected)/9); s.build()).set_meta("focus_key","player_sort")

static func header(s) -> void:
	if not s.list_view: return
	for item in [["OYUNCU",70],["GEN",366],["HIZ",426],["KND",486],["FORM",554],["DURUM",626],["BEDEL",757]]:
		s.text(item[0],Vector2(item[1],245),12,UI.MUTE,true)

static func row(card,p: Dictionary) -> void:
	var s=card.screen; var c=s.game.career
	card.label(p.name,Vector2(24,22),15,UI.PAPER,null,269)
	card.label("%s · %d YAŞ · %s" % [s.World.ROLES[p.role],p.age,p.get("nationality","TR")],Vector2(24,42),12,UI.MUTE,s.font,269)
	card.label(str(s.World.ovr(p)),Vector2(314,32),19,UI.ACCENT)
	card.label(str(p.attributes.pace),Vector2(374,32),16,UI.PAPER)
	card.label("%d%%" % roundi(p.fitness*100),Vector2(434,32),14,UI.RED if p.fitness<.6 else UI.PAPER)
	card.label("%+.0f" % (p.form*100),Vector2(502,32),14,UI.BLUE if p.form>=0 else UI.RED)
	var status: String="+ SAKAT" if p.injury>c.world.date else ("! CEZALI" if p.banned>0 else ("↓ YORGUN" if p.fitness<.6 else ("11 · HAZIR" if p.id in c.club().lineup else "✓ HAZIR")))
	card.label(status,Vector2(574,32),12,UI.RED if p.injury>c.world.date or p.banned>0 else UI.MUTE,null,122)
	card.label(c.money(0 if p.club=="" else s.game.career.market.value(p)),Vector2(705,32),13,UI.PAPER,null,91)
