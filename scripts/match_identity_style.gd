extends RefCounted
## Shared match signature: tapered ribbons, three slashes and restrained ink.
const INK:=Color("10272d")
const PAPER:=Color("fff5dc")
const POWER:=Color("ffac50")
const PERFECT:=Color("ffdc83")
const FINESSE:=Color("64ecd8")

static func ribbon(canvas: CanvasItem,rect: Rect2,color: Color) -> void:
	var cut:=minf(14,rect.size.y*.28)
	canvas.draw_colored_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end-Vector2(cut,0),Vector2(rect.position.x,rect.end.y)]),color)

static func slashes(canvas: CanvasItem,at: Vector2,color: Color,height: float=20) -> void:
	for i in range(3):
		var p:=at+Vector2(i*height*.42,0)
		canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(height*.32,0),p+Vector2(height*.55,0),p+Vector2(height*.23,height),p+Vector2(0,height)]),color)

static func goal(hud) -> void:
	var game=hud.game
	var age: float=game.visual_identity.goal_age
	var team:=Color(game.clubs.data(game.goal_team).primary)
	var accent:=Color(game.clubs.data(game.goal_team).accent).lerp(PAPER,.30)
	var lift:=0.0 if game.experience.reduce_motion else (1-smoothstep(0,.32,age))*140
	hud.draw_set_transform(game.ui.edge_offset(0,1)+Vector2(0,lift))
	var rect:=Rect2(420,739,600,125)
	ribbon(hud,rect,Color(INK,.96))
	ribbon(hud,Rect2(420,739,160,125),team.lerp(INK,.22))
	slashes(hud,Vector2(439,749),accent,12)
	hud.text("GOL",Vector2(443,821),52,PAPER,true)
	hud.text("STARTING ELEVEN FC",Vector2(599,764),10,accent,true)
	var scorer: String=game.players[game.last_kicker].display_name if game.last_kicker>=0 and game.players[game.last_kicker].team==game.goal_team else game.team_name(game.goal_team)
	hud.UI.fit(hud,hud.bold,scorer,Vector2(598,799),280,23,PAPER)
	hud.UI.fit(hud,hud.font,game.team_name(game.goal_team),Vector2(599,831),280,13,accent)
	hud.draw_line(Vector2(902,768),Vector2(888,836),Color(accent,.45),1.5,true)
	hud.center("%d – %d" % game.score,Vector2(947,812),28,PAPER)
	hud.draw_line(Vector2(439,852),Vector2(989,852),Color(accent,.45),1.5,true)
	hud.draw_set_transform(Vector2.ZERO)

static func finish_card(hud) -> void:
	var game=hud.game; var record: Dictionary=game.replay.goal_record
	var club: Dictionary=game.clubs.data(game.goal_team)
	var main:=Color(club.primary); var accent:=Color(club.accent).lerp(PAPER,.45)
	hud.draw_set_transform(game.ui.edge_offset(1,1))
	var rect:=Rect2(842,635,552,193)
	ribbon(hud,rect,Color(INK,.97))
	hud.draw_rect(Rect2(rect.position,Vector2(5,rect.size.y)),main.lightened(.12))
	slashes(hud,Vector2(867,654),accent,17)
	hud.text("ÇİZGİ ANI",Vector2(904,669),13,accent,true)
	hud.UI.fit(hud,hud.bold,str(record.get("name","GOL")),Vector2(866,710),488,29,PAPER)
	hud.text(game.team_name(game.goal_team),Vector2(868,735),13,accent)
	hud.draw_line(Vector2(868,751),Vector2(1358,751),Color(accent,.3),1,true)
	var speed: String="%d km/sa" % roundi(record.speed) if record.has("speed") else "—"
	var distance: String="%.1f m" % record.distance if record.has("distance") else "—"
	hud.text("ŞUT HIZI",Vector2(868,773),10,accent,true)
	hud.text(speed,Vector2(868,804),24,PAPER,true)
	hud.text("MESAFE",Vector2(1070,773),10,accent,true)
	hud.text(distance,Vector2(1070,804),24,PAPER,true)
	hud.draw_set_transform(Vector2.ZERO)

static func entrance_player(hud,index: int) -> void:
	if index<0: return
	var game=hud.game; var p=game.players[index]
	var club: Dictionary=game.clubs.data(p.team)
	hud.draw_set_transform(game.ui.edge_offset(-1,1))
	ribbon(hud,Rect2(42,628,436,137),Color(INK,.96))
	hud.draw_rect(Rect2(42,628,6,137),Color(club.primary).lightened(.15))
	slashes(hud,Vector2(65,641),Color(club.accent),13)
	hud.text(game.team_name(p.team),Vector2(101,653),12,PAPER)
	hud.text("%02d" % p.shirt_number,Vector2(65,709),38,Color(club.accent))
	hud.UI.fit(hud,hud.bold,p.display_name,Vector2(140,705),304,23,PAPER)
	hud.text("KALECİ" if p.keeper else preload("res://scripts/signature_motion.gd").LABELS[p.idle_habit]+" · OYUNCU PROFİLİ",Vector2(140,738),11,Color(club.accent))
	hud.draw_set_transform(Vector2.ZERO)
