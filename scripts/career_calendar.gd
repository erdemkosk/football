extends "res://scripts/menu_screen.gd"
## Presentation only: the saved calendar advances once before this animation.
var game
var screen
var from_day := 0
var to_day := 0
var age := 0.0
var travel := 1.0
var next_match: Dictionary={}
var summary := ""
var finish_button: Button

func _ready() -> void:
	setup_style(); hide(); mouse_filter=Control.MOUSE_FILTER_STOP
	finish_button=make_button(self,Rect2(590,690,260,45),"ANİMASYONU GEÇ",finish)
	for property in ["focus_neighbor_left","focus_neighbor_right","focus_neighbor_top","focus_neighbor_bottom","focus_next","focus_previous"]:
		finish_button.set(property,NodePath("."))

func begin(first: int,last: int,notice: String) -> void:
	from_day=first; to_day=last; summary=notice; age=0
	travel=.30+maxi(1,last-first)*.22
	next_match=game.career.next_fixture().duplicate()
	show(); move_to_front(); finish_button.text="ANİMASYONU GEÇ"; finish_button.grab_focus()
	queue_redraw()

func _process(delta: float) -> void:
	if not visible: return
	age+=delta
	if age>=travel: finish_button.text="DEVAM ET"
	if age>=travel+.85: finish(); return
	queue_redraw()

func finish() -> void:
	if not visible: return
	hide(); screen.calendar_finished()

func _draw() -> void:
	if not visible: return
	var art=screen.art
	draw_rect(game.ui.bounds(),Color(.025,.05,.08,.94))
	art.fade(self,Rect2(185,165,1070,590),Color("183a44"),Color("10202f"))
	box(Rect2(190,170,1060,580),Color(.035,.08,.12,.65),18,Color("4a6970"))
	var progress:=clampf(age/travel,0,1)
	var shown:=lerpf(from_day,to_day,smoothstep(0,1,progress))
	var settled:=age>=travel
	badge(Vector2(720,226),game.career.club(),.65)
	center("TAKVİM GÜNCELLENDİ" if settled else "KULÜP TAKVİMİ İLERLİYOR",Vector2(720,287),16,art.LIME,true)
	center(screen.World.date_label(to_day if settled else roundi(shown)),Vector2(720,338),40,art.WHITE,true)
	# Sliding calendar tiles expose each crossed day; a fixed centre marks today.
	for day in range(from_day-3,to_day+4):
		var x: float=720+(day-shown)*130
		if x<265 or x>1175: continue
		var distance:=absf(day-shown)
		var emphasis:=clampf(1-distance,0,1)
		var date: Dictionary=screen.World.calendar(day)
		var opacity:=clampf(1-absf(x-720)/520,.15,1)
		var rect:=Rect2(x-54,381-emphasis*8,108,122+emphasis*8)
		box(rect,Color(Color("37584e").lerp(Color("142b3b"),1-emphasis),opacity),10,Color(art.LIME,emphasis*.8))
		center(["PAZ","PZT","SAL","ÇAR","PER","CUM","CMT"][date.weekday],Vector2(x,410-emphasis*8),11,Color(art.MUTED,opacity),true)
		center("%02d" % date.day,Vector2(x,463-emphasis*8),38,Color(art.WHITE,opacity),true)
		if not next_match.is_empty() and next_match.day==day:
			center("MAÇ",Vector2(x,488),10,art.LIME,true)
		elif day<=floori(shown): draw_circle(Vector2(x,483),3,Color(art.LIME,opacity))
	draw_line(Vector2(720,515),Vector2(720,528),art.LIME,3,true)
	box(Rect2(336,555,768,4),Color("29414b"),2)
	box(Rect2(336,555,768*progress,4),art.LIME,2)
	center("%d GÜN İLERLEDİ" % (to_day-from_day) if settled else "GÜNLER GEÇİYOR · TAKIM HAZIRLANIYOR",Vector2(720,598),19,art.WHITE,true)
	center(summary,Vector2(720,633),14,art.MUTED)
	if game.controller.using_gamepad:
		game.controller.Glyphs.draw_hints(self,Vector2(603,779),[["A","Devam"],["B","Geç"]],game.controller.family,font,24,12)
