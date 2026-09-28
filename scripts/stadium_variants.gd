extends RefCounted
## Alternate bowls reuse the physical pitch, tunnel route and four-light budget.
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/pitch_dimensions.gd")

static func terrace(kind: String,side: int= -1,ends: bool=false) -> Dictionary:
	match kind:
		"town": return {"rows":4 if ends else 7,"rise":.44,"depth":.95}
		"compact": return {"rows":15 if ends else 18,"rise":.68,"depth":.74}
		"historic": return {"rows":8 if ends else (10 if side<0 else 14),"rise":.56,"depth":.95}
	return {"rows":9 if ends else 12,"rise":.56,"depth":.95}

static func lower(parent: Node3D,crowd,kind: String,concrete: Material,front: Material) -> void:
	var rail:=G.material(Color("83928a"))
	for ends in [false,true]:
		for side in [-1,1]:
			var spec:=terrace(kind,side,ends)
			var stand:=Node3D.new(); parent.add_child(stand)
			stand.name=("End" if ends else "Side")+str(side)
			stand.rotation.y=(0.0 if side>0 else PI) if ends else side*PI*.5
			var start:=58.5 if ends else 39.5+P.SIDE_SHIFT
			var width:=99.0+P.EXTRA_WIDTH if ends else 112.0
			var columns:=int(width/.86)-2
			for row in range(spec.rows):
				var y: float=.25+row*spec.rise
				var z: float=start+row*spec.depth
				if not ends and side>0:
					for end in [-1,1]: G.block(stand,Vector3(52.4,.5,spec.depth+.04),Vector3(end*29.8,y,z),concrete)
				else: G.block(stand,Vector3(width,.5,spec.depth+.04),Vector3(0,y,z),concrete)
				for col in range(columns):
					var x: float=-width*.5+1.0+col*.86
					if not ends and side>0 and absf(x)<3.6: continue
					if col%22==0:
						G.block(stand,Vector3(.84,.025,.06),Vector3(x,y+.27,z-.3),rail)
						continue
					crowd.seat(stand.transform*Vector3(x,y+.275,z),stand.rotation.y,row,col/22)
				for aisle in range(22,columns,22):
					var x: float=-width*.5+1+aisle*.86
					G.rod(stand,Vector3(x,y+.3,z),Vector3(x,y+1.15,z),.026,rail)
			for end in [-1,1]:
				var span:=width*.5-3.6 if not ends and side>0 else width*.5
				var center: float=end*(width*.25+1.8 if not ends and side>0 else width*.25)
				G.block(stand,Vector3(span,.65,.18),Vector3(center,.35,start-.7),front)
				G.rod(stand,Vector3(center-span*.5,.95,start-.7),Vector3(center+span*.5,.95,start-.7),.04,rail)
			# Back wall closes each terrace, leaving real open corners between stands.
			var height: float=.6+(spec.rows-1)*spec.rise
			G.block(stand,Vector3(width,height,.3),Vector3(0,height*.5,start+spec.rows*spec.depth),concrete)

static func shell(a,crowd,kind: String) -> void:
	for side in [-1,1]:
		var side_roof: bool=kind!="town" or side<0
		if side_roof:
			var stand:=Node3D.new(); a.add_child(stand); stand.rotation.y=side*PI*.5
			var height:=8.2 if kind=="town" else 15.5 if kind=="compact" else 11.0 if side<0 else 23.0
			var back:=53.5+P.SIDE_SHIFT if kind=="town" else 57.5+P.SIDE_SHIFT if kind=="compact" else 54.5+P.SIDE_SHIFT if side<0 else 68.0+P.SIDE_SHIFT
			canopy(a,stand,114,42+P.SIDE_SHIFT,back,height,kind=="historic")
			if kind=="historic" and side>0:
				upper_gallery(a,crowd,stand)
				G.block(stand,Vector3(116,9,.6),Vector3(0,4.5,back),a.stone)
				for x in range(-49,50,14):
					G.block(stand,Vector3(8,2.2,.15),Vector3(x,7,back+.4),a.glass)
	for side in [-1,1]:
		var stand:=Node3D.new(); a.add_child(stand); stand.rotation.y=0 if side>0 else PI
		if kind=="compact" or kind=="historic" and side<0:
			canopy(a,stand,108+P.EXTRA_WIDTH,57.6,74,13.5 if kind=="compact" else 10.5,kind=="historic")
		var display:=Node3D.new(); stand.add_child(display)
		display.position=Vector3(0,6.3 if kind=="town" else 10.0,65 if kind=="town" else 69)
		display.scale=Vector3.ONE*(.65 if kind=="town" else .85)
		a.scoreboard(display,Vector3.ZERO)
		for x in [-4,4]: G.rod(stand,Vector3(x,0,display.position.z),Vector3(x,display.position.y,display.position.z),.10,a.frame)
	for side in [-1,1]:
		for end in [-1,1]:
			pylon(a,Vector3(side*(55+P.SIDE_SHIFT),32,end*43),kind=="historic")
	if kind=="historic": clock_tower(a)
	if kind=="town":
		for side in [-1,1]:
			for z in [-49,-28,24,47]:
				var at:=Vector3(side*(66+P.SIDE_SHIFT),0,z)
				G.cylinder(a,.22,3.8,at+Vector3.UP*1.5,a.frame)
				var foliage:=G.sphere(a,2.5,at+Vector3.UP*4.6,a.hedge)
				foliage.scale=Vector3(1,1.35,.9)

static func canopy(a,parent: Node3D,width: float,lip: float,back: float,height: float,old: bool) -> void:
	var front:=height-.9
	a.roof.cull_mode=BaseMaterial3D.CULL_DISABLED
	a.roof_panel(parent,Vector3(-width*.5,front,lip),Vector3(width*.5,front,lip),Vector3(-width*.5,height,back),Vector3(width*.5,height,back),a.roof)
	G.block(parent,Vector3(width,.6,.28),Vector3(0,front,lip),a.trim)
	G.block(parent,Vector3(width,.4,.35),Vector3(0,height,back),a.trim)
	for x in range(-int(width*.5)+2,int(width*.5),12):
		G.rod(parent,Vector3(x,0,back),Vector3(x,height,back),.13,a.frame)
		G.rod(parent,Vector3(x,front,lip),Vector3(x,height,back),.07,a.frame)
		G.rod(parent,Vector3(x,front,lip),Vector3(x,height-2,back),.065,a.frame)
		if old:
			G.rod(parent,Vector3(x,0,lip+2),Vector3(x,front,lip+2),.09,a.frame)
			for t in [.25,.5,.75]:
				G.rod(parent,Vector3(x,lerpf(front,height-2,t),lerpf(lip,back,t)),Vector3(x,lerpf(front,height,t+.12),lerpf(lip,back,t+.12)),.035,a.frame)

static func upper_gallery(a,crowd,stand: Node3D) -> void:
	for row in range(7):
		var y:=11.3+row*.7; var z:=59.5+P.SIDE_SHIFT+row*.95
		G.block(stand,Vector3(110,.6,1),Vector3(0,y,z),a.stone)
		for col in range(125):
			if col%22==0: continue
			crowd.seat(stand.transform*Vector3(-53+col*.86,y+.3,z),stand.rotation.y,row,col/22)
	G.block(stand,Vector3(110,1.1,.22),Vector3(0,11.6,59+P.SIDE_SHIFT),a.trim)

static func pylon(a,head: Vector3,lattice: bool) -> void:
	var foot:=Vector3(head.x,0,head.z)
	if lattice:
		for x in [-.9,.9]:
			for z in [-.9,.9]: G.rod(a,foot+Vector3(x,0,z),head+Vector3(x*.4,0,z*.4),.09,a.frame)
		for y in range(0,30,4):
			for z in [-.8,.8]:
				G.rod(a,foot+Vector3(-.8,y,z),foot+Vector3(.8,y+4,z),.045,a.frame)
				G.rod(a,foot+Vector3(.8,y,z),foot+Vector3(-.8,y+4,z),.045,a.frame)
	else: G.rod(a,foot,head,.20,a.frame)
	var bank:=Node3D.new(); a.add_child(bank); bank.position=head
	bank.look_at(Vector3(-signf(head.x)*5,0,head.z*.28))
	G.block(bank,Vector3(4.5,1.65,.26),Vector3.ZERO,a.charcoal)
	for row in range(2):
		for col in range(6): G.block(bank,Vector3(.58,.56,.05),Vector3(-1.75+col*.7,-.37+row*.74,-.17),a.lamp_glass)
	a.floodlight_mounts.append(bank.global_position-bank.global_basis.z*.24)

static func clock_tower(a) -> void:
	var root:=Node3D.new(); a.add_child(root); root.name="ClockTower"; root.position=Vector3(-61-P.SIDE_SHIFT,0,-68)
	G.block(root,Vector3(5.5,16,5.5),Vector3(0,8,0),a.stone)
	G.block(root,Vector3(6.5,.6,6.5),Vector3(0,16,0),a.trim)
	var face:=G.material(Color("e4d7b7"))
	for angle in [0.0,PI*.5,PI,PI*1.5]:
		var dial:=Node3D.new(); root.add_child(dial); dial.rotation.y=angle
		G.block(dial,Vector3(3.6,3.6,.06),Vector3(0,12.6,2.8),face)
		G.block(dial,Vector3(.12,1.3,.05),Vector3(0,13.15,2.85),a.charcoal)
		G.block(dial,Vector3(1.1,.12,.05),Vector3(.5,12.6,2.85),a.charcoal)
