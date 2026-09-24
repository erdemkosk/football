extends RefCounted
const World=preload("res://scripts/career_world.gd")
const Graphics=preload("res://scripts/kit_graphics.gd")
const RECTS := [
	Rect2(64,392,520,88), Rect2(64,628,520,72),
	Rect2(64,716,254,54), Rect2(64,786,520,46),
	Rect2(64,496,520,116), Rect2(330,716,254,54)]
const ACTIONS := ["quick","training","settings","guide","career","saves"]
var game
var was_visible:=false
var resume_slot:=0
var summary: Dictionary={}
var badge: Texture2D
var first_empty:=1

func refresh() -> void:
	# Read save summaries only on menu entry, never from drawing or every frame.
	resume_slot=0; first_empty=0; summary={}; badge=null
	var latest: int=-1
	for slot in range(1,4):
		if not game.career.has_save(slot):
			if first_empty==0: first_empty=slot
			continue
		var saved: Dictionary=game.career.read_save(slot)
		if saved.is_empty(): continue
		var path: String=game.career.path_for(slot)+(".bak" if saved.backup else "")
		var modified: int=FileAccess.get_modified_time(path)
		if modified<=latest: continue
		latest=modified; resume_slot=slot
		var w: Dictionary=saved.world
		var club: Dictionary=w.clubs[w.user]
		summary={"name":club.name,"league":w.clubs[w.user].league,"date":w.date,"badge":club}
	# Returning from a career resumes the same session, including pending edits.
	if game.career.exists():
		var w: Dictionary=game.career.world
		var club: Dictionary=game.career.club()
		resume_slot=game.career.slot
		summary={"name":club.name,"league":club.league,"date":w.date,"badge":club}
	if not summary.is_empty():
		var club: Dictionary=summary.badge
		badge=Graphics.badge(int(club.badge_id),Color(club.primary),Color(club.accent))

func career_action() -> void:
	if resume_slot>0:
		if game.career.exists() and game.career.slot==resume_slot:
			game.career_screen.open_hub()
		else:
			game.career_screen.open_entry()
			game.career_screen.load_career(resume_slot)
	else:
		game.career_screen.open_entry()
		# A damaged or occupied slot still goes through the existing save picker
		# and its overwrite confirmation; this shortcut only uses an empty slot.
		if first_empty>0: game.career_screen.choose(first_empty)

func title(index: int) -> String:
	return ["HIZLI MAÇ","ANTRENMAN","AYARLAR","KONTROL REHBERİ","KARİYERE DEVAM ET" if resume_slot>0 else "YENİ KARİYER","YENİ / KAYITLAR"][index]

func navigation(h) -> void:
	var callbacks: Array[Callable]=[game.frontend.open_selection,game.training_menu.open_menu,game.match_menu.open_menu,game.controls_help.open_panel,career_action,game.career_screen.open_entry]
	for i in range(RECTS.size()):
		h.nav_button(RECTS[i],callbacks[i])
		h.nav_buttons[i].set_meta("home_action",ACTIONS[i])
		h.nav_buttons[i].tooltip_text=title(i)
	# Geometry and controller navigation follow the same visual order.
	# The horizontal pair is Settings / Saves; every other item spans the column.
	var neighbors := [[3,4,0,0],[4,2,1,1],[1,3,5,5],[2,0,3,3],[0,1,4,4],[1,3,2,2]]
	var order := [0,4,1,2,5,3]
	var sides := [SIDE_TOP,SIDE_BOTTOM,SIDE_LEFT,SIDE_RIGHT]
	for i in range(RECTS.size()):
		var item: Button=h.nav_buttons[i]
		for side in range(4): item.set_focus_neighbor(sides[side],item.get_path_to(h.nav_buttons[neighbors[i][side]]))
		var step: int=order.find(i)
		item.focus_previous=item.get_path_to(h.nav_buttons[order[posmod(step-1,order.size())]])
		item.focus_next=item.get_path_to(h.nav_buttons[order[(step+1)%order.size()]])

func draw(h) -> void:
	var full: Rect2=game.ui.bounds()
	if full.position.x<0: h.draw_rect(Rect2(full.position,Vector2(-full.position.x,full.size.y)),Color("081416"))
	for i in range(90):
		h.draw_rect(Rect2(i*10,full.position.y,10,full.size.y),Color(.025,.055,.06,.97*pow(1.0-i/90.0,.55)))
	if not summary.is_empty(): h.draw_rect(Rect2(0,full.position.y,5,full.size.y),preload("res://scripts/ui_style.gd").club_tint(summary.badge))
	h.draw_texture_rect(h.Brand.CREST,Rect2(62,32,108,108),false)
	h.text("STARTING",Vector2(188,74),24,h.PAPER,true)
	h.headline("ELEVEN FC",Vector2(185,120),46)
	h.text("S E F C   /   1 1 ' E  1 1  F U T B O L",Vector2(190,143),9,h.GOLD,true)
	h.draw_line(Vector2(64,181),Vector2(105,181),h.GOLD,2)
	h.text("M A Ç   G Ü N Ü",Vector2(117,185),10,h.GOLD,true)
	h.headline("MAÇA HAZIR MISIN?",Vector2(61,259),51)
	h.headline("HİKÂYENE DEVAM ET." if resume_slot>0 else "İLK DÜDÜK SENİN.",Vector2(61,325),43,h.GOLD)
	h.text("İlk dokunuştan son düdüğe.",Vector2(66,363),17,h.MUTE)
	card(h,0,"Takımını seç. Sahaya çık.","quick",resume_slot==0)
	card(h,1,"İlk dokunuş, çalım ve bitiricilik.","training",false)
	card(h,2,"","settings",false)
	card(h,3,"","guide",false)
	card(h,4,str(summary.get("name","Bir kulüp seç. Kendi hikâyeni yaz.")),"career",resume_slot>0)
	card(h,5,"","saves",false)
	h.draw_line(Vector2(64,851),Vector2(584,851),Color(h.GOLD,.16),1)
	if game.controller.using_gamepad:
		h.pad_hints(Vector2(65,877),[["D-PAD","Gez"],["A","Seç"]],22,11)
	else: h.text("↑ ↓  GEZ     ENTER  SEÇ     F1  KONTROLLER",Vector2(66,877),10,h.MUTE)
	h.draw_set_transform(game.ui.edge_offset(1,-1))
	h.panel(Rect2(1186,36,218,36),Color(.03,.08,.09,.82),7,Color(h.GOLD,.15))
	h.draw_circle(Vector2(1203,54),3,h.GOLD)
	h.text("SEFC ARENA  ·  CANLI",Vector2(1217,58),10,h.PAPER,true)
	h.draw_set_transform(Vector2.ZERO)

func fitted(h,value: String,at: Vector2,size: int,width: float,color: Color,strong: bool=false) -> void:
	var font: Font=h.bold if strong else h.font
	while size>11 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width: size-=1
	h.draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)

func card(h,index: int,subtitle: String,kind: String,primary: bool) -> void:
	var rect: Rect2=RECTS[index]
	var focused: bool=index<h.nav_buttons.size() and h.nav_buttons[index].has_focus()
	var hover: bool=rect.has_point(h.get_local_mouse_position())
	var hot: bool=focused or hover
	var color: Color=h.GOLD.lightened(.06 if hot else 0) if primary else Color("1e3738") if hot else Color(.065,.135,.145,.96)
	var ink: Color=h.INK if primary else h.PAPER
	var mute: Color=Color("43534a") if primary else h.MUTE
	h.panel(Rect2(rect.position+Vector2(0,4),rect.size),Color(0,0,0,.16),10)
	h.panel(rect,color,10,Color(h.GOLD,.8 if hot else .24) if not primary else Color.TRANSPARENT)
	if hot and not primary: h.panel(Rect2(rect.position+Vector2(0,12),Vector2(3,rect.size.y-24)),h.GOLD,1)
	var small: bool=rect.size.y<60
	var icon_at: Vector2=rect.position+Vector2(28 if small else 38,rect.size.y*.5)
	if kind=="career" and badge!=null:
		h.draw_texture_rect(badge,Rect2(icon_at-Vector2(25,28),Vector2(50,56)),false)
	else: icon(h,icon_at,kind,ink,small)
	var x: float=rect.position.x+(53 if small else 78)
	var size: int=12 if index==5 else 14 if small else 20
	var baseline: float=rect.position.y+rect.size.y*.5+5 if small else rect.position.y+35
	fitted(h,title(index),Vector2(x,baseline),size,rect.end.x-x-45,ink,true)
	if not subtitle.is_empty():
		fitted(h,subtitle,Vector2(x,baseline+24),14,rect.end.x-x-35,mute,kind=="career" and resume_slot>0)
	if kind=="career" and resume_slot>0:
		var detail: String=World.LEAGUES[int(summary.league)]+"  ·  "+World.date_label(int(summary.date))
		fitted(h,detail,Vector2(x,baseline+47),11,rect.end.x-x-26,mute)
	elif kind=="career":
		h.text("KADRONU KUR  /  SEZONA BAŞLA",Vector2(x,baseline+47),10,mute)
	if focused and game.controller.using_gamepad:
		h.draw_texture_rect(game.controller.Glyphs.icon(JOY_BUTTON_A,game.controller.family),Rect2(rect.end.x-40,rect.position.y+16,25,25),false)
	else:
		var at:=Vector2(rect.end.x-28,rect.position.y+rect.size.y*.5)
		h.draw_line(at-Vector2(5,5),at,h.INK if primary else Color(h.PAPER,.65),1.6,true)
		h.draw_line(at,at+Vector2(-5,5),h.INK if primary else Color(h.PAPER,.65),1.6,true)

func icon(h,at: Vector2,kind: String,color: Color,small: bool) -> void:
	var scale:=.70 if small else 1.0
	h.draw_set_transform(at,0,Vector2.ONE*scale)
	match kind:
		"quick":
			h.draw_style_box(icon_box(color),Rect2(-21,-16,42,32))
			h.draw_line(Vector2(0,-16),Vector2(0,16),color,1.5,true)
			h.draw_arc(Vector2.ZERO,7,0,TAU,24,color,1.5,true)
			h.draw_rect(Rect2(-21,-7,7,14),color,false,1.5)
			h.draw_rect(Rect2(14,-7,7,14),color,false,1.5)
		"career":
			h.draw_polyline(PackedVector2Array([Vector2(-13,-17),Vector2(13,-17),Vector2(11,1),Vector2(0,10),Vector2(-11,1),Vector2(-13,-17)]),color,2,true)
			h.draw_line(Vector2(0,10),Vector2(0,19),color,2,true)
			h.draw_line(Vector2(-10,19),Vector2(10,19),color,2,true)
			h.draw_polyline(PackedVector2Array([Vector2(-13,-12),Vector2(-21,-12),Vector2(-20,-2),Vector2(-10,4)]),color,2,true)
			h.draw_polyline(PackedVector2Array([Vector2(13,-12),Vector2(21,-12),Vector2(20,-2),Vector2(10,4)]),color,2,true)
		"training":
			h.draw_polyline(PackedVector2Array([Vector2(-15,14),Vector2(-5,-17),Vector2(5,14)]),color,2,true)
			h.draw_line(Vector2(-10,-1),Vector2(0,-1),color,2,true)
			h.draw_line(Vector2(-20,15),Vector2(11,15),color,2,true)
			h.draw_arc(Vector2(16,7),7,0,TAU,24,color,1.5,true)
		"settings":
			for y in [-12,0,12]: h.draw_line(Vector2(-19,y),Vector2(19,y),color,2,true)
			for point in [Vector2(-8,-12),Vector2(9,0),Vector2(-3,12)]: h.draw_circle(point,4,color)
		"saves":
			h.draw_polyline(PackedVector2Array([Vector2(-19,-14),Vector2(-4,-14),Vector2(1,-8),Vector2(20,-8),Vector2(20,16),Vector2(-19,16),Vector2(-19,-14)]),color,2,true)
			h.draw_line(Vector2(-10,3),Vector2(10,3),color,2,true)
		"guide":
			h.draw_style_box(icon_box(color),Rect2(-17,-20,34,40))
			for y in [-9,0,9]: h.draw_line(Vector2(-8,y),Vector2(8,y),color,2,true)
	h.draw_set_transform(Vector2.ZERO)

func icon_box(color: Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color.TRANSPARENT; style.border_color=color
	style.set_border_width_all(2); style.set_corner_radius_all(3)
	return style
