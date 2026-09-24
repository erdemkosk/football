extends RefCounted
## Open play uses a short direction ribbon. Set pieces show the full estimated
## flight and its target so the taker can place the delivery. Rendering is read-only.
const INK := Color("10272b")
const PAPER := Color("fff5dc")

func screen_path(hud,points: PackedVector3Array,power: float) -> PackedVector2Array:
	var path := PackedVector2Array()
	if points.size()<2: return path
	var origin := Vector3(points[0].x,.06,points[0].z)
	if hud.game.camera.is_position_behind(origin): return path
	var start: Vector2=hud.game.screen_position(origin)
	if not hud.game.ui.bounds().grow(-18).has_point(start): return path
	path.append(start)
	var remaining := lerpf(4.2,7.0,clampf(power,0,1))
	var previous := origin
	for sample in range(1,points.size()):
		var next := Vector3(points[sample].x,.06,points[sample].z)
		var distance := previous.distance_to(next)
		if distance<.001: continue
		next=previous.lerp(next,minf(1,remaining/distance))
		if hud.game.camera.is_position_behind(next): break
		path.append(hud.game.screen_position(next))
		remaining-=distance
		previous=next
		if remaining<=0: break
	if path.size()<2: return PackedVector2Array()
	var length := path_length(path)
	if length<2: return PackedVector2Array()
	# Readable in both broadcast cameras without growing across the pitch.
	var scale := clampf(length,66,126)/length
	for i in range(1,path.size()): path[i]=start+(path[i]-start)*scale
	return path

func path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1,path.size()): length+=path[i-1].distance_to(path[i])
	return length

func point_at(path: PackedVector2Array,distance: float) -> Vector2:
	for i in range(1,path.size()):
		var span := path[i-1].distance_to(path[i])
		if distance<=span: return path[i-1].lerp(path[i],distance/maxf(.001,span))
		distance-=span
	return path[-1]

func strip(path: PackedVector2Array,start: float,end: float,width: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(13):
		var along := lerpf(start,end,i/12.0)
		var at := point_at(path,along)
		var tangent := (point_at(path,along+.5)-point_at(path,maxf(0,along-.5))).normalized()
		left.append(at+tangent.orthogonal()*width)
		right.append(at-tangent.orthogonal()*width)
	right.reverse(); left.append_array(right)
	return left

func draw_arrow(hud,points: PackedVector3Array,power: float,color: Color) -> void:
	var path := screen_path(hud,points,power)
	if path.size()<2: return
	var length := path_length(path)
	var start := path[0]
	var neck := length-18.0
	var tip := path[-1]
	var base := point_at(path,neck)
	var forward := (tip-base).normalized()
	var side := forward.orthogonal()
	var charge := clampf(power,0,1)
	# A translucent tapered blade, with a lit leading edge. The center remains
	# readable over striped grass without an opaque black arrow across the pitch.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var colors_left := PackedColorArray()
	var colors_right := PackedColorArray()
	for i in range(17):
		var t := i/16.0
		var along := lerpf(20,neck,t)
		var at := point_at(path,along)
		var normal := (point_at(path,along+.5)-point_at(path,along-.5)).normalized().orthogonal()
		var width := lerpf(2.0,5.0,t)
		left.append(at+normal*width); right.append(at-normal*width)
		colors_left.append(Color(color.lerp(PAPER,.24),color.a*lerpf(.03,.70,t)))
		colors_right.append(Color(color,color.a*lerpf(.02,.25,t)))
	var blade := left.duplicate(); var reverse := right.duplicate(); reverse.reverse(); blade.append_array(reverse)
	colors_right.reverse(); colors_left.append_array(colors_right)
	hud.draw_polygon(blade,colors_left)
	hud.draw_polyline(left,Color(PAPER,color.a*.72),1.0,true)
	hud.draw_polyline(right,Color(color,color.a*.46),1.0,true)
	var edge := PackedVector2Array([base+side*10,tip,base-side*10])
	hud.draw_polyline(edge,Color(INK,color.a*.6),4,true)
	hud.draw_polyline(edge,Color(PAPER,color.a*.98),2,true)
	var inset := PackedVector2Array([base+side*6,tip-forward*6,base-side*6])
	hud.draw_polyline(inset,Color(color,color.a*.9),1.4,true)
	# Charge lives at the player's feet; it is independent of predicted travel.
	var angle := (point_at(path,22)-start).angle()
	hud.draw_arc(start,14,angle+.55,angle+TAU-.55,42,Color(INK,color.a*.6),4,true)
	hud.draw_arc(start,14,angle+.55,angle+TAU-.55,42,Color(PAPER,color.a*.28),1.4,true)
	if charge>.005:
		hud.draw_arc(start,14,angle+.55,angle+.55+(TAU-1.10)*charge,42,Color(color,color.a*.95),2.7,true)
	var tick := start+Vector2.from_angle(angle+PI)*19
	hud.draw_line(tick-Vector2.from_angle(angle)*2,tick+Vector2.from_angle(angle)*2,Color(PAPER,color.a*.8),1.4,true)

func draw_set_piece(hud,route: Dictionary,color: Color,lob: bool) -> void:
	var arc := PackedVector2Array()
	var ground := PackedVector2Array()
	for point in route.points:
		if hud.game.camera.is_position_behind(point): break
		arc.append(hud.game.screen_position(point))
		ground.append(hud.game.screen_position(Vector3(point.x,.03,point.z)))
	if arc.size()<2: return
	# Restore the long flight arrow, including lift and curl, for dead balls only.
	for i in range(1,ground.size(),2):
		hud.draw_line(ground[i-1],ground[i],Color(color,color.a*.32),1.2,true)
	hud.draw_polyline(arc,Color(INK,color.a*.85),5,true)
	hud.draw_polyline(arc,color,2.3,true)
	for i in range(6,arc.size(),10):
		var tangent := (arc[i]-arc[i-1]).normalized()
		var side := tangent.orthogonal()*3.5
		hud.draw_colored_polygon(PackedVector2Array([arc[i]+tangent*5,arc[i]-tangent*4+side,arc[i]-tangent*4-side]),color)
	var point: Vector3=route.target
	if hud.game.camera.is_position_behind(point): return
	var ring := PackedVector2Array()
	var radius := .85 if lob else .58
	for i in range(33):
		var angle := TAU*i/32.0
		ring.append(hud.game.screen_position(Vector3(point.x,.04,point.z)+Vector3(cos(angle),0,sin(angle))*radius))
	hud.draw_colored_polygon(ring,Color(color,color.a*.16))
	hud.draw_polyline(ring,Color(color,color.a*.55),1.5,true)
	var target: Vector2=hud.game.screen_position(point)
	if not hud.game.ui.bounds().grow(-26).has_point(target): return
	# The crosshair sits at the predicted height in goal; the disc marks the turf.
	hud.draw_circle(target,8,Color(INK,color.a*.8))
	hud.draw_arc(target,9,0,TAU,32,color,2,true)
	hud.draw_line(target-Vector2(4,0),target+Vector2(4,0),color,1.5,true)
	hud.draw_line(target-Vector2(0,4),target+Vector2(0,4),color,1.5,true)

func draw_meter(hud,power: float,label: String,color: Color,warning: String="",lob: bool=false,risk_from: float=-1.0) -> void:
	hud.draw_set_transform(hud.game.ui.edge_offset(0,1))
	var rect := Rect2(598,803,244,60)
	hud.panel(Rect2(rect.position+Vector2(0,2),rect.size),Color(0,0,0,.15),8)
	hud.panel(rect,Color("0b2026",.92),8,Color(color,.28))
	hud.draw_line(rect.position+Vector2(14,1),rect.position+Vector2(230,1),Color(color,.66),1,true)
	var center := rect.position+Vector2(24,22)
	if lob:
		var arc := PackedVector2Array()
		for i in range(17):
			var t := i/16.0
			arc.append(center+Vector2(-8+16*t,4-10*sin(t*PI)))
		hud.draw_polyline(arc,color,1.7,true)
	else:
		hud.draw_polyline(PackedVector2Array([center+Vector2(-6,4),center+Vector2(2,-4),center+Vector2(7,1)]),color,1.7,true)
	hud.text(label,rect.position+Vector2(43,25),12,hud.PAPER,true)
	var value := "%d" % roundi(clampf(power,0,1)*100)
	var text_width: float=hud.bold.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	hud.text(value,Vector2(rect.end.x-16-text_width,rect.position.y+25),12,color,true)
	var track := Rect2(rect.position+Vector2(16,39),Vector2(212,4))
	hud.panel(track,Color(color,.18),2)
	if power>.001: hud.panel(Rect2(track.position,Vector2(track.size.x*clampf(power,0,1),4)),color,2)
	for t in [.25,.5,.75]:
		var x: float=track.position.x+track.size.x*t
		hud.draw_line(Vector2(x,track.end.y+3),Vector2(x,track.end.y+5),Color(color,.3),1)
	if risk_from>0:
		# Beyond this charge the strike trades accuracy for pace.
		var risk_x: float=track.position.x+track.size.x*risk_from
		hud.draw_line(Vector2(risk_x,track.position.y-3),Vector2(risk_x,track.end.y+3),Color("efc09b",.9),1.5)
	if warning!="":
		hud.panel(Rect2(600,775,240,21),Color("10272b",.92),5)
		hud.center(warning,Vector2(720,790),10,Color("efc09b"))
	hud.draw_set_transform(Vector2.ZERO)
