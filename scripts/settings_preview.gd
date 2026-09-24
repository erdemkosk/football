extends Control
const UI=preload("res://scripts/ui_style.gd")
var game
var menu
var viewport: SubViewport
var camera: Camera3D
var framing:=preload("res://scripts/match_camera.gd").new()
var tick:=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	framing.game=game
	viewport=SubViewport.new(); viewport.size=Vector2i(660,440); viewport.world_3d=game.get_world_3d()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; viewport.msaa_3d=Viewport.MSAA_2X
	add_child(viewport); camera=Camera3D.new(); viewport.add_child(camera); camera.current=true; camera.far=800

func _process(delta: float) -> void:
	visible=menu.visible and menu.page in [1,2,3]
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if not visible: return
	tick-=delta
	if menu.page==3 and tick<=0:
		tick=.1
		framing.index=framing.IDS.find(game.match_camera.preferred)
		framing.distance=game.match_camera.distance; framing.height=game.match_camera.height
		var pose: Dictionary=framing.pose(game.ball.position,game.zoom)
		camera.projection=pose.projection; camera.size=pose.size; camera.fov=pose.fov
		camera.position=pose.eye; camera.look_at(pose.look)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	queue_redraw()

func label(value: String,at: Vector2,points: int=14,color: Color=UI.PAPER) -> void:
	UI.fit(self,menu.font,value,at,size.x-28,points,color)

func _draw() -> void:
	draw_style_box(UI.surface(UI.PANEL,UI.LINE),Rect2(Vector2.ZERO,size))
	if menu.page==3:
		draw_texture_rect(viewport.get_texture(),Rect2(8,8,size.x-16,218),false)
		label("CANLI KAMERA ÖNİZLEMESİ",Vector2(14,252),14,UI.ACCENT)
		label(framing.LABELS[framing.IDS.find(game.match_camera.preferred)],Vector2(14,281),22)
		label("Uzaklık  %%%d" % roundi(game.match_camera.distance*100),Vector2(14,315))
		label("Yükseklik  %%%d" % roundi(game.match_camera.height*100),Vector2(14,341))
		label("Ayarın sahadaki etkisini gör.",Vector2(14,384),13,UI.MUTE)
		return
	label(game.controller.family_label(),Vector2(14,30),16,UI.ACCENT)
	var active: String=""
	if menu.capture_action>=0: active=game.controller.label_for(menu.capture_action)
	else:
		var focus:=get_viewport().gui_get_focus_owner()
		if is_instance_valid(focus): active=str(focus.get_meta("binding_action",""))
	var center:=Vector2(size.x*.5,156)
	draw_style_box(UI.surface(Color("253d48"),UI.LINE,34),Rect2(center-Vector2(123,66),Vector2(246,141)))
	var items: Array=[["LT",Vector2(-115,-105)],["RT",Vector2(115,-105)],["LB",Vector2(-78,-78)],["RB",Vector2(78,-78)],["LS",Vector2(-72,0)],["D-PAD",Vector2(-31,47)],["RS",Vector2(41,47)],["Y",Vector2(75,-30)],["X",Vector2(47,-2)],["B",Vector2(103,-2)],["A",Vector2(75,26)]]
	for item in items:
		var at: Vector2=center+item[1]; var hot: bool=item[0] in active.split(" ") or (item[0]=="LS" and active=="L3") or (item[0]=="RS" and active=="R3")
		if hot: draw_circle(at,21,Color(UI.ACCENT,.3))
		draw_texture_rect(game.controller.Glyphs.icon(game.controller.Glyphs.TOKENS[item[0]],game.controller.family),Rect2(at-Vector2(15,15),Vector2(30,30)),false)
	label("SEÇİLİ TUŞ",Vector2(14,276),12,UI.MUTE)
	if active in game.controller.Glyphs.TOKENS:
		game.controller.Glyphs.draw_hints(self,Vector2(14,301),[[active,"Seçili hareket"]],game.controller.family,menu.font,30,14)
	else: label(active if active!="" else "Bir hareket seç",Vector2(14,308),22,UI.ACCENT)
	label("Yeni atamalar çizime yansır.",Vector2(14,351),13,UI.MUTE)
	game.controller.Glyphs.draw_hints(self,Vector2(14,381),[["A","Seç"],["B","Geri"]],game.controller.family,menu.font,24,13)
