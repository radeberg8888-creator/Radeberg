extends RefCounted
# Sonderanlagen: Hauptbahnhof mit Hallendach und Zügen, Güterbahnhof, Containerhafen mit Kränen und Schiff,
# verlassener Flugplatz (Hangars, Tower, Flugzeugwrack), Läden mit Kartensymbol (Werkstatt, Waffenladen, Kleiderladen).
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
const TOR=preload("res://scripts/rolltor.gd")
var G;var S;var B
var root:Node3D
var icons:=[]      # [typ, Vector2, name]
var rng:=RandomNumberGenerator.new()
func _init(g,s,b):G=g;S=s;B=b;rng.seed=31

var _cm:={}
func cont_mat(c:Color)->StandardMaterial3D:
	if _cm.has(c):return _cm[c]
	var m=StandardMaterial3D.new();m.albedo_texture=load("res://assets/textures/container_albedo.png");m.albedo_color=c
	m.normal_enabled=true;m.normal_texture=load("res://assets/textures/container_normal.png");m.normal_scale=0.8
	m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_scale=Vector3(0.42,0.42,0.42);m.roughness=0.62;m.metallic=0.35
	_cm[c]=m;return m
func two(m:StandardMaterial3D)->StandardMaterial3D:
	var d=m.duplicate();d.cull_mode=BaseMaterial3D.CULL_DISABLED;return d
func label(parent:Node3D,text:String,pos:Vector3,size:float,col:Color,yaw:=0.0)->Label3D:
	var l=Label3D.new();l.text=text;l.font_size=160;l.pixel_size=size/160.0;l.modulate=col;l.outline_size=0
	parent.add_child(l);l.position=pos;l.rotation.y=yaw;return l

# ---------------- Reservierungen (vor der Häuserplatzierung) ----------------
var shops:=[]
func reserve():
	# Bahnhof + Güterbahnhof
	B.rect_mark(Vector2(680,90),Vector2(0,1),205.0,72.0)
	B.rect_mark(Vector2(722,615),Vector2(0,1),180.0,32.0)
	# Hafengelände
	B.rect_mark(Vector2(1545,350),Vector2(0,1),215.0,110.0)
	# Flugplatz-Vorfeld
	B.rect_mark(Vector2(-900,520),Vector2(0,1),160.0,70.0)
	# Läden an festen Straßenstellen: [Straße, s, Seite, Breite, Tiefe, Typ]
	var plan=[[S.roads_by_name("Grove"),300.0,1,26.0,21.0,"werkstatt"],[S.roads_by_name("Grove"),150.0,-1,15.0,13.0,"waffen"],
		[S.roads_by_name("Radeberger Allee"),560.0,1,18.0,14.0,"kleider"],[S.roads_by_name("Grove"),470.0,-1,13.5,11.5,"zuhause"]]
	for e in plan:
		var r=e[0];var at=S.at(r,e[1]);var p:Vector2=at[0];var t:Vector2=at[2];var side:int=e[2]
		var nn=Vector2(-t.y,t.x)*side
		var c=p+nn*(r.w+r.sw+1.3+e[4]*0.5)
		B.rect_mark(c,t,e[3]*0.5+0.5,e[4]*0.5+0.5)
		var dir=-nn
		shops.append({"typ":e[5],"c":c,"y":at[1]+0.14,"yaw":atan2(dir.x,dir.y),"w":e[3],"d":e[4]})
		G.flatten(c,at[1]+0.14,sqrt(e[3]*e[3]+e[4]*e[4])*0.5+2.0,10.0)

func build(parent:Node3D):
	root=Node3D.new();root.name="Anlagen";parent.add_child(root)
	bahnhof();gueterbahnhof();hafen();flugplatz()
	for s in shops:
		var n=Node3D.new();root.add_child(n);n.position=Vector3(s.c.x,s.y,s.c.y);n.rotation.y=s.yaw
		match s.typ:
			"werkstatt":werkstatt(n,s.w,s.d);icons.append(["werkstatt",s.c,"Radeberg Customs (Tuning)"])
			"waffen":waffenladen(n,s.w,s.d);icons.append(["waffen",s.c,"Waffen Krause"])
			"kleider":kleiderladen(n,s.w,s.d);icons.append(["kleider",s.c,"Stoffwechsel (Kleidung)"])
			"zuhause":
				var t=B.get_tpl("stash");var w=B.instance(t,0,0.6);n.add_child(w);icons.append(["zuhause",s.c,"Zuhause (Speichern)"])
	icons.append(["bahnhof",Vector2(690,90),"Hauptbahnhof"]);icons.append(["hafen",Vector2(1545,350),"Containerhafen"]);icons.append(["flugplatz",Vector2(-1080,540),"Alter Flugplatz"])

# ---------------- Hauptbahnhof ----------------
func bahnhof():
	var h=G.base_height(700,100)
	var b=Batch.new()
	var steel=two(Mats.flat(Color(0.28,0.33,0.36),0.45,0.75));var glass=two(Mats.flat(Color(0.55,0.68,0.75),0.08,0.3))
	var roofm=two(Mats.flat(Color(0.32,0.34,0.36),0.6,0.5));var plat=Mats.pbr("pavers",0.5,Color(0.75,0.74,0.72));var edge=Mats.flat(Color(0.92,0.92,0.9),0.6)
	var brick=Mats.bricks(0.45);var sand=Mats.pbr("plaster_cream",0.3,Color(0.92,0.86,0.72));var dglass=Mats.glass()
	var top=h+0.56
	# Bahnsteige (zwischen den Gleisen)
	for px in [[673.7,688.3],[691.7,706.3],[709.7,724.3]]:
		b.box(plat,Vector3(px[0],h,-80),Vector3(px[1],top+0.55,250))
		b.box(edge,Vector3(px[0],top+0.55,-80),Vector3(px[0]+0.5,top+0.57,250));b.box(edge,Vector3(px[1]-0.5,top+0.55,-80),Vector3(px[1],top+0.57,250))
		for z in range(-60,250,30):
			b.box(Mats.flat(Color(0.15,0.25,0.4),0.5),Vector3((px[0]+px[1])*0.5-0.05,top+2.6,z-1.2),Vector3((px[0]+px[1])*0.5+0.05,top+3.4,z+1.2))   # Zugzielanzeiger
			b.box(Mats.flat(Color(0.35,0.22,0.12),0.7),Vector3((px[0]+px[1])*0.5-0.3,top+0.55,z+6),Vector3((px[0]+px[1])*0.5+0.3,top+1.0,z+8))   # Bank
	# Hallendach: drei Tonnengewölbe aus Stahl und Glas
	var z0=-90.0;var z1=270.0;var spring=top+9.0
	for vc in [673.3,700.0,726.7]:
		var R=13.35;var nseg=14
		for k in nseg:
			var a0=PI*k/nseg;var a1=PI*(k+1)/nseg
			var p0=Vector2(vc+R*cos(a0),spring+R*sin(a0)*0.62);var p1=Vector2(vc+R*cos(a1),spring+R*sin(a1)*0.62)
			var c=(p0+p1)*0.5;var L=p0.distance_to(p1);var ang=atan2(p1.y-p0.y,p1.x-p0.x)
			var m=glass if (k>=3 and k<=10) else roofm
			b.box_rot(m,Vector3(c.x,c.y,(z0+z1)*0.5),Vector3(L+0.05,0.12,z1-z0),Basis(Vector3(0,0,1),ang))
			for z in range(int(z0),int(z1)+1,15):
				b.box_rot(steel,Vector3(c.x,c.y-0.25,z),Vector3(L+0.1,0.45,0.3),Basis(Vector3(0,0,1),ang))
		# Längsträger
		b.box(steel,Vector3(vc-0.3,spring+R*0.62-0.2,z0),Vector3(vc+0.3,spring+R*0.62+0.25,z1))
	for x in [660.0,686.65,713.35,740.0]:
		for z in range(int(z0),int(z1)+1,15):
			b.cyl(steel,Vector3(x,(h+spring)*0.5,z),0.35,spring-h)
		b.box(steel,Vector3(x-0.4,spring-0.6,z0),Vector3(x+0.4,spring+0.2,z1))
	# Empfangsgebäude (Backstein mit Sandsteingliederung) an der Westseite
	var ex0=612.0;var ex1=655.0;var ez0=10.0;var ez1=210.0;var eh=h+19.0
	b.box(brick,Vector3(ex0,h-1,ez0),Vector3(ex1,eh,ez1))
	b.box(sand,Vector3(ex0-0.6,h-1,ez0-0.6),Vector3(ex1+0.6,h+3.5,ez1+0.6))    # Sockel
	b.box(sand,Vector3(ex0-0.8,eh-1.2,ez0-0.8),Vector3(ex1+0.8,eh,ez1+0.8))    # Gesims
	b.box(Mats.flat(Color(0.25,0.33,0.3),0.6,0.4),Vector3(ex0+1,eh,ez0+1),Vector3(ex1-1,eh+3.5,ez1-1))   # Kupferdach
	for z in range(int(ez0)+8,int(ez1)-4,12):
		if abs(z-110)<14:continue
		b.box(dglass,Vector3(ex0-0.15,h+5,z-2.4),Vector3(ex0+0.2,eh-4.5,z+2.4))
		b.box(sand,Vector3(ex0-0.5,eh-4.5,z-3.0),Vector3(ex0+0.1,eh-3.6,z+3.0))
		b.box(sand,Vector3(ex0-0.5,h+4.4,z-3.0),Vector3(ex0+0.1,h+5.0,z+3.0))
	# Mittelportal + Uhrturm
	b.box(sand,Vector3(ex0-2,h-1,96),Vector3(ex1,eh+6,124))
	b.box(dglass,Vector3(ex0-2.2,h+0.5,101),Vector3(ex0-1.8,eh+1,119))
	for z in [101.0,106.0,110.0,114.0,119.0]:b.box(steel,Vector3(ex0-2.4,h+0.5,z-0.15),Vector3(ex0-2.1,eh+1,z+0.15))
	b.box(brick,Vector3(ex0+4,eh,104),Vector3(ex0+16,h+48,116))
	b.box(sand,Vector3(ex0+3.4,h+40,103.4),Vector3(ex0+16.6,h+42,116.6))
	b.prism(Mats.flat(Color(0.25,0.33,0.3),0.6,0.4),Vector3(ex0+10,h+52,110),Vector3(13,8,13))
	b.commit(root)
	var clock=MeshInstance3D.new();clock.mesh=CylinderMesh.new();clock.mesh.top_radius=3.6;clock.mesh.bottom_radius=3.6;clock.mesh.height=0.3;root.add_child(clock)
	clock.position=Vector3(ex0+3.8,h+35,110);clock.rotation.z=PI*0.5;clock.material_override=Mats.flat(Color(0.95,0.94,0.9),0.5)
	var hb=Batch.new();var blk=Mats.flat(Color(0.05,0.05,0.05),0.5)
	hb.box_rot(blk,Vector3(ex0+3.6,h+35+1.2,110),Vector3(0.1,2.6,0.3),Basis());hb.box_rot(blk,Vector3(ex0+3.6,h+35,110+1.5),Vector3(0.1,0.3,3.2),Basis(Vector3(1,0,0),0.5));hb.commit(root)
	label(root,"HAUPTBAHNHOF RADEBERG",Vector3(ex0-2.5,eh+3.2,110),2.6,Color(0.95,0.92,0.8),-PI*0.5)
	# Züge
	train(Vector2(708,-50),0,8,"ice",top);train(Vector2(672,20),0,5,"regio",top);train(Vector2(726,60),0,4,"regio",top)

func train(start:Vector2,_dir:int,cars:int,kind:String,top:float):
	var b=Batch.new()
	var body=Mats.flat(Color(0.93,0.93,0.92),0.35,0.2) if kind=="ice" else Mats.flat(Color(0.72,0.08,0.06),0.4,0.2)
	var stripe=Mats.flat(Color(0.75,0.05,0.05),0.4) if kind=="ice" else Mats.flat(Color(0.92,0.92,0.9),0.4)
	var win=Mats.glass();var dark=Mats.flat(Color(0.1,0.1,0.11),0.7,0.4);var roof=Mats.flat(Color(0.55,0.56,0.58),0.5,0.4)
	var L=25.0;var z=start.y;var x=start.x
	for k in cars:
		var za=z+k*(L+1.0);var zb=za+L
		var H=4.0 if kind=="ice" else 4.6
		b.box(body,Vector3(x-1.45,top+1.0,za),Vector3(x+1.45,top+H,zb))
		b.box(roof,Vector3(x-1.3,top+H,za+0.5),Vector3(x+1.3,top+H+0.25,zb-0.5))
		b.box(stripe,Vector3(x-1.47,top+1.25,za),Vector3(x+1.47,top+1.55,zb))
		if kind=="ice":b.box(win,Vector3(x-1.47,top+2.2,za+1.5),Vector3(x+1.47,top+3.1,zb-1.5))
		else:
			b.box(win,Vector3(x-1.47,top+1.8,za+1.5),Vector3(x+1.47,top+2.5,zb-1.5));b.box(win,Vector3(x-1.47,top+3.2,za+1.5),Vector3(x+1.47,top+3.9,zb-1.5))
		for dz in [3.5,L-3.5]:
			b.box(dark,Vector3(x-1.2,top,za+dz-1.6),Vector3(x+1.2,top+1.0,za+dz+1.6))
			for wz in [-1.2,1.2]:
				for sx in [-0.72,0.72]:b.cyl(dark,Vector3(x+sx,top+0.45,za+dz+wz),0.45,0.15,Transform3D.IDENTITY,Basis(Vector3(0,0,1),PI*0.5))
		b.box(dark,Vector3(x-1.0,top+1.4,zb),Vector3(x+1.0,top+H-0.2,zb+1.0))   # Übergang
	# Triebköpfe (abgeschrägte Nasen)
	for e in [[z-0.1,-1.0],[z+cars*(L+1.0)-1.0+0.1,1.0]]:
		var z0=e[0];var sgn=e[1]
		for st in 6:
			var t=st/6.0;var hh=lerp(4.0,1.6,t);var ww=lerp(1.45,0.9,t)
			b.box(body,Vector3(x-ww,top+1.0,z0+sgn*st*0.9),Vector3(x+ww,top+hh,z0+sgn*(st+1)*0.9))
		b.box(win,Vector3(x-1.0,top+2.6,z0+sgn*1.0),Vector3(x+1.0,top+3.4,z0+sgn*2.2))
	b.commit(root)

# ---------------- Güterbahnhof ----------------
func gueterbahnhof():
	var b=Batch.new();var cols=[Color(0.65,0.12,0.08),Color(0.1,0.3,0.55),Color(0.15,0.45,0.25),Color(0.85,0.55,0.1),Color(0.6,0.6,0.62),Color(0.35,0.2,0.12),Color(0.8,0.8,0.78)]
	var dark=Mats.flat(Color(0.12,0.12,0.12),0.7,0.5);var rust=Mats.flat(Color(0.42,0.22,0.12),0.85,0.3)
	for k in 6:
		var x=704+k*5.5;var r=null
		for rr in S.roads:
			if rr.typ=="schiene" and rr.P.size()>2 and abs(rr.P[0].x-x)<0.6 and rr.P[0].y>460:r=rr
		var top=(r.h[10] if r!=null else G.base_height(x,600))+0.56
		var z=480.0+rng.randf()*20
		while z<740:
			var kind=rng.randi()%4;var L=[16.0,19.0,14.0,17.0][kind]
			if rng.randf()<0.18:z+=L+5;continue
			b.box(dark,Vector3(x-1.4,top+0.8,z),Vector3(x+1.4,top+1.2,z+L))
			for dz in [2.0,L-2.0]:b.box(dark,Vector3(x-1.1,top,z+dz-1.3),Vector3(x+1.1,top+0.8,z+dz+1.3))
			var c=cont_mat(cols[rng.randi()%cols.size()])
			match kind:
				0:   # Containertragwagen
					b.box(c,Vector3(x-1.22,top+1.2,z+0.6),Vector3(x+1.22,top+3.8,z+6.7))
					b.box(cont_mat(cols[rng.randi()%cols.size()]),Vector3(x-1.22,top+1.2,z+7.2),Vector3(x+1.22,top+3.8,z+15.4))
				1:   # Kesselwagen
					b.cyl(Mats.flat(Color(0.2,0.2,0.22) if rng.randf()<0.5 else Color(0.85,0.85,0.83),0.4,0.5),Vector3(x,top+2.6,z+L*0.5),1.4,L-1.0,Transform3D.IDENTITY,Basis(Vector3(1,0,0),PI*0.5))
				2:   # Schüttgutwagen
					b.box(rust,Vector3(x-1.45,top+1.2,z+0.3),Vector3(x+1.45,top+3.6,z+L-0.3))
				3:   # gedeckter Güterwagen
					b.box(c,Vector3(x-1.45,top+1.2,z+0.2),Vector3(x+1.45,top+4.2,z+L-0.2))
					b.box(Mats.flat(Color(0.5,0.5,0.5),0.6,0.4),Vector3(x-1.35,top+4.2,z+0.4),Vector3(x+1.35,top+4.45,z+L-0.4))
			z+=L+1.2
	# Portalkran über den Gleisen
	var yel=Mats.flat(Color(0.9,0.68,0.08),0.5,0.4);var y0=G.base_height(718,620)
	for x in [697.0,739.0]:
		for z in [590.0,640.0]:b.box(yel,Vector3(x-0.6,y0,z-0.6),Vector3(x+0.6,y0+16,z+0.6))
		b.box(yel,Vector3(x-0.7,y0+15,588),Vector3(x+0.7,y0+16.5,642))
	for z in [605.0,625.0]:b.box(yel,Vector3(696,y0+16.5,z-1),Vector3(740,y0+18.5,z+1))
	b.box(Mats.flat(Color(0.3,0.3,0.32),0.5,0.6),Vector3(712,y0+14,603),Vector3(718,y0+16.5,627))
	b.commit(root)

# ---------------- Containerhafen ----------------
func hafen():
	var b=Batch.new();var conc=Mats.pbr("concrete",0.2,Color(0.62,0.62,0.6));var top=3.0
	b.box(conc,Vector3(1440,-9,140),Vector3(1652,top,560))
	b.box(Mats.flat(Color(0.95,0.85,0.1),0.6),Vector3(1648,top,140),Vector3(1652,top+0.02,560))
	var bol=Mats.flat(Color(0.1,0.1,0.1),0.5,0.6)
	for z in range(150,560,20):b.cyl(bol,Vector3(1649,top+0.35,z),0.3,0.7)
	# Reifenfender an der Kaimauer
	for z in range(160,560,25):b.cyl(Mats.flat(Color(0.05,0.05,0.05),0.9),Vector3(1652.6,1.4,z),0.8,2.4)
	# Containerstapel
	var cols=[Color(0.7,0.12,0.08),Color(0.1,0.3,0.6),Color(0.12,0.45,0.25),Color(0.88,0.55,0.1),Color(0.55,0.56,0.58),Color(0.45,0.25,0.15),Color(0.85,0.85,0.82),Color(0.15,0.55,0.6)]
	var cm=[];for c in cols:cm.append(cont_mat(c))
	for bx in range(1470,1600,32):
		for bz in range(170,540,36):
			if bx<1520 and bz>440:continue   # Platz für die Lagerhalle
			var base=1+rng.randi()%4
			for i in 2:
				for j in 10:
					var hgt=clampi(base+rng.randi_range(-1,1),0,5)
					if rng.randf()<0.06:hgt=0
					for k in hgt:
						var x0=bx+i*13.0;var z0=bz+j*2.6
						b.box(cm[rng.randi()%cm.size()],Vector3(x0,top+k*2.6,z0),Vector3(x0+12.1,top+k*2.6+2.55,z0+2.42))
	# Containerbrücken (STS-Kräne)
	for zc in [230.0,360.0,490.0]:sts_crane(b,1632.0,zc,top)
	# Schiff am Kai
	var hull=Mats.flat(Color(0.12,0.16,0.28),0.6,0.3);var red=Mats.flat(Color(0.55,0.08,0.06),0.7,0.2);var white=Mats.flat(Color(0.92,0.92,0.9),0.5)
	b.box(red,Vector3(1656,-8,230),Vector3(1690,0.5,470));b.box(hull,Vector3(1656,0.5,230),Vector3(1690,9,470))
	for k in 10:
		var t=(k+1)/10.0
		b.box(hull,Vector3(1656+t*14,-6,470+k*4),Vector3(1690-t*14,9,474+k*4))
		b.box(hull,Vector3(1656+t*10,-6,230-(k+1)*3),Vector3(1690-t*10,9,230-k*3))
	b.box(white,Vector3(1658,9,250),Vector3(1688,26,268));b.box(Mats.glass(),Vector3(1657.8,22,249.8),Vector3(1688.2,24.5,268.2))
	b.box(red,Vector3(1668,26,256),Vector3(1676,31,262))
	for bz in range(275,465,13):
		for i in 5:
			var hgt=2+rng.randi()%4
			for k in hgt:b.box(cm[rng.randi()%cm.size()],Vector3(1658+i*6.0,9+k*2.6,bz),Vector3(1663.8+i*6.0,9+k*2.6+2.55,bz+12.1))
	# Lagerhalle
	var hall=Mats.flat(Color(0.7,0.72,0.74),0.6,0.5)
	b.box(hall,Vector3(1450,top,450),Vector3(1520,top+11,550));b.prism(hall,Vector3(1485,top+13,500),Vector3(70,4,100))
	b.commit(root)
	label(root,"RADEBERG CONTAINER TERMINAL",Vector3(1484.9,top+8,500),3.0,Color(0.15,0.25,0.45),-PI*0.5)

func sts_crane(b:Batch,x:float,zc:float,top:float):
	var c1=Mats.flat(Color(0.12,0.35,0.62),0.5,0.4);var c2=Mats.flat(Color(0.9,0.9,0.88),0.5,0.4)
	for lx in [x-14,x+4]:
		for lz in [zc-9,zc+9]:b.box(c1,Vector3(lx-0.8,top,lz-0.8),Vector3(lx+0.8,top+38,lz+0.8))
		b.box(c1,Vector3(lx-0.8,top+20,zc-9),Vector3(lx+0.8,top+21.5,zc+9))
	for lz in [zc-9,zc+9]:b.box(c1,Vector3(x-15,top+36,lz-0.8),Vector3(x+5,top+38,lz+0.8))
	# Ausleger über das Wasser + Gegengewicht
	for lz in [zc-2.0,zc+2.0]:b.box(c2,Vector3(x-38,top+38,lz-0.6),Vector3(x+62,top+40,lz+0.6))
	b.box(c1,Vector3(x-12,top+40,zc-3),Vector3(x-2,top+46,zc+3))
	for lz in [zc-2,zc+2]:
		b.box_rot(c2,Vector3(x+25,top+46,lz),Vector3(76,0.6,0.6),Basis(Vector3(0,0,1),-0.2))
		b.box_rot(c2,Vector3(x-15,top+46,lz),Vector3(40,0.6,0.6),Basis(Vector3(0,0,1),0.3))
	b.box(c1,Vector3(x-1,top+38,zc-2.5),Vector3(x+1,top+56,zc+2.5))
	b.box(c2,Vector3(x+20,top+33,zc-2.5),Vector3(x+24,top+38,zc+2.5))   # Katze

# ---------------- Verlassener Flugplatz ----------------
func flugplatz():
	var b=Batch.new();var rust=two(Mats.flat(Color(0.48,0.33,0.24),0.85,0.45));var metal=two(Mats.flat(Color(0.55,0.56,0.55),0.6,0.6))
	var conc=Mats.pbr("concrete",0.25,Color(0.75,0.72,0.66));var y=G.base_height(-930,520)
	# Vorfeld (rissiger Beton)
	b.box(Mats.pbr("concrete",0.12,Color(0.78,0.74,0.66)),Vector3(-950,y-0.4,445),Vector3(-845,y+0.05,600))
	# drei Hangars mit Tonnendach, eines mit Dachschaden
	var idx=0
	for hz in [470.0,530.0,590.0]:
		var x0=-900.0;var x1=-860.0;var R=13.0;var nseg=12
		for k in nseg:
			if idx==1 and (k==5 or k==6):continue   # Loch im Dach
			var a0=PI*k/nseg;var a1=PI*(k+1)/nseg
			var p0=Vector2(hz+R*cos(a0),y+5+R*sin(a0)*0.8);var p1=Vector2(hz+R*cos(a1),y+5+R*sin(a1)*0.8)
			var c=(p0+p1)*0.5;var L=p0.distance_to(p1);var ang=atan2(p1.y-p0.y,p1.x-p0.x)
			b.box_rot(rust if (k+idx)%3==0 else metal,Vector3((x0+x1)*0.5,c.y,c.x),Vector3(x1-x0,0.15,L+0.05),Basis(Vector3(1,0,0),-ang))
		for s in [-1,1]:b.box(metal,Vector3(x0,y,hz+s*R-0.1),Vector3(x1,y+5,hz+s*R+0.1))
		# Rückwand (Giebel, Osten)
		for k in 10:
			var t0=-1.0+k*0.2;var hh=5+R*0.8*sqrt(max(0.0,1.0-(t0+0.1)*(t0+0.1)))
			b.box(metal,Vector3(x1-0.1,y,hz+t0*R),Vector3(x1+0.1,y+hh,hz+(t0+0.2)*R))
		# Schiebetore an der Westseite, eines halb offen
		var open=6.0 if idx!=2 else 0.0
		b.box(rust,Vector3(x0-0.3,y,hz-R+0.5),Vector3(x0-0.1,y+7.5,hz-1-open*0.5))
		b.box(rust,Vector3(x0-0.6,y,hz+1+open*0.5),Vector3(x0-0.4,y+7.5,hz+R-0.5))
		for k in 6:
			var t0=-1.0+k*0.333;var hh=5+R*0.8*sqrt(max(0.0,1.0-(t0+0.16)*(t0+0.16)))
			b.box(metal,Vector3(x0-0.1,y+7.5,hz+t0*R),Vector3(x0+0.1,y+hh,hz+(t0+0.333)*R))
		idx+=1
	label(root,"HANGAR 2",Vector3(-900.7,y+9.5,530),2.0,Color(0.9,0.88,0.8),-PI*0.5)
	# Tower
	var tx=-905.0;var tz=395.0
	b.box(conc,Vector3(tx-3,y,tz-3),Vector3(tx+3,y+18,tz+3))
	b.box(conc,Vector3(tx-5,y+18,tz-5),Vector3(tx+5,y+18.6,tz+5))
	b.box(Mats.glass(),Vector3(tx-4.6,y+18.6,tz-4.6),Vector3(tx+4.6,y+22,tz+4.6))
	b.box(conc,Vector3(tx-5,y+22,tz-5),Vector3(tx+5,y+22.6,tz+5))
	b.box(metal,Vector3(tx-0.1,y+22.6,tz-0.1),Vector3(tx+0.1,y+27,tz+0.1))
	b.box(Mats.pbr("plaster_white",0.3,Color(0.8,0.78,0.7)),Vector3(tx+3,y,tz-12),Vector3(tx+25,y+5,tz+6))   # Abfertigung
	b.box(Mats.flat(Color(0.2,0.2,0.2),0.8),Vector3(tx+3,y+5,tz-12),Vector3(tx+25,y+5.3,tz+6))
	# Flugzeugwrack (Propellermaschine, Flügel abgeknickt)
	var px=-955.0;var pz=575.0;var pl=Mats.flat(Color(0.82,0.82,0.78),0.6,0.3);var pr=Mats.flat(Color(0.6,0.12,0.08),0.6,0.3)
	var bas=Basis(Vector3.UP,0.6)*Basis(Vector3(0,0,1),0.06)
	var xf=Transform3D(bas,Vector3(px,y+1.2,pz))
	b.cyl(pl,Vector3(0,0,0),1.2,14,xf,Basis(Vector3(1,0,0),PI*0.5))
	b.box(pr,Vector3(-1.22,-0.2,-7),Vector3(1.22,0.2,7),xf)
	b.box(pl,Vector3(-8,0.6,-1.8),Vector3(8,0.9,0.6),xf)
	b.box_rot(pl,Vector3(-9.5,-0.2,-0.6),Vector3(4,0.3,2.3),Basis(Vector3(0,0,1),0.45),xf)
	b.box(pl,Vector3(-3,0.2,6),Vector3(3,0.4,7.5),xf);b.box(pr,Vector3(-0.1,0.2,6),Vector3(0.1,3,7.8),xf)
	for sx in [-4.0,4.0]:b.cyl(Mats.flat(Color(0.2,0.2,0.2),0.6,0.6),Vector3(sx,0.5,-1.6),0.7,2.2,xf,Basis(Vector3(1,0,0),PI*0.5))
	# Ölfässer, Betonblöcke, Zaun
	for k in 40:
		var p=Vector2(rng.randf_range(-940,-850),rng.randf_range(450,600))
		if abs(p.y-470)<14 and p.x>-905 or abs(p.y-530)<14 and p.x>-905 or abs(p.y-590)<14 and p.x>-905:continue
		b.cyl(rust if k%2 else Mats.flat(Color(0.2,0.3,0.45),0.7,0.4),Vector3(p.x,y+0.45,p.y),0.3,0.9)
	var fence=two(Mats.flat(Color(0.5,0.52,0.5),0.5,0.7))
	for z in range(440,610,3):b.box(fence,Vector3(-842.05,y,z),Vector3(-841.95,y+2.4,z+0.06))
	var chain=StandardMaterial3D.new();chain.albedo_color=Color(0.6,0.62,0.63,0.35);chain.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;chain.metallic=0.7;chain.cull_mode=BaseMaterial3D.CULL_DISABLED
	b.box(chain,Vector3(-842.02,y+0.2,440),Vector3(-841.98,y+2.3,610))
	b.commit(root)

# ---------------- Läden ----------------
func window(b:Batch,x0:float,y0:float,x1:float,y1:float,zf:float,frame:Material):
	b.box(frame,Vector3(x0-0.12,y0-0.12,zf-0.05),Vector3(x1+0.12,y1+0.12,zf+0.04))
	b.box(Mats.glass(),Vector3(x0,y0,zf+0.04),Vector3(x1,y1,zf+0.06))
	b.box(frame,Vector3((x0+x1)*0.5-0.04,y0,zf+0.04),Vector3((x0+x1)*0.5+0.04,y1,zf+0.08))
	b.box(frame,Vector3(x0,y0+(y1-y0)*0.68-0.04,zf+0.04),Vector3(x1,y0+(y1-y0)*0.68+0.04,zf+0.08))
	b.box(frame,Vector3(x0-0.2,y0-0.2,zf),Vector3(x1+0.2,y0-0.08,zf+0.22))
# lokaler Rahmen: Front bei z=+d/2 zeigt nach +z (zur Straße), Boden y=0 (Gehweghöhe)
func werkstatt(n:Node3D,w:float,d:float):
	var b=Batch.new();var brick=Mats.bricks(0.45);var conc=Mats.pbr("concrete",0.4,Color(0.66,0.66,0.68));var trim=Mats.flat(Color(0.18,0.18,0.2),0.6,0.3)
	var H=8.0;var x0=-w*0.5;var x1=w*0.5;var zf=d*0.5;var zb=-d*0.5
	b.box(conc,Vector3(x0,-0.6,zb),Vector3(x1,0.02,zf))
	b.box(brick,Vector3(x0,0,zb),Vector3(x1,H,zb+0.5))
	b.box(brick,Vector3(x0,0,zb),Vector3(x0+0.5,H,zf));b.box(brick,Vector3(x1-0.5,0,zb),Vector3(x1,H,zf))
	b.box(trim,Vector3(x0-0.15,H,zb-0.15),Vector3(x1+0.15,H+0.45,zf+0.15))
	b.box(Mats.flat(Color(0.3,0.3,0.32),0.8),Vector3(x0,H-0.2,zb),Vector3(x1,H,zf))
	var dw=5.4;var dh=4.6;var gap=(w-3*dw)/4.0;var xx=x0;var doors=[]
	var yel=Mats.flat(Color(0.95,0.7,0.1),0.45,0.3)
	for k in 4:
		b.box(brick,Vector3(xx,0,zf-0.5),Vector3(xx+gap,H,zf));xx+=gap
		if k<3:
			doors.append(xx+dw*0.5)
			b.box(brick,Vector3(xx,dh,zf-0.5),Vector3(xx+dw,H,zf))
			b.box(yel,Vector3(xx-0.12,dh,zf-0.02),Vector3(xx+dw+0.12,dh+0.18,zf+0.04))
			for s in [xx-0.12,xx+dw]:b.box(yel,Vector3(s,0,zf-0.02),Vector3(s+0.12,dh,zf+0.04))
			xx+=dw
	var red=Mats.flat(Color(0.62,0.05,0.04),0.45,0.3);var steel=Mats.flat(Color(0.55,0.55,0.57),0.35,0.8)
	for i in 6:
		var xb=x0+1.2+i*4.0
		b.box(red,Vector3(xb,0,zb+0.5),Vector3(xb+2.6,0.9,zb+1.3));b.box(steel,Vector3(xb,0.9,zb+0.5),Vector3(xb+2.6,0.95,zb+1.35))
	for xc in doors:
		for sx in [-1,1]:
			b.box(yel,Vector3(xc+sx*1.85-0.14,0,zf-10.6),Vector3(xc+sx*1.85+0.14,3.3,zf-10.3))
		b.box(yel,Vector3(xc-2.0,3.3,zf-10.6),Vector3(xc+2.0,3.45,zf-10.3))
	var tire=Mats.flat(Color(0.03,0.03,0.03),0.85)
	for s in 2:
		for k in 5:b.cyl(tire,Vector3(x0+0.95,0.15+k*0.27,zb+2.0+s*0.9),0.36,0.25)
	b.commit(n)
	for k in 3:
		var t=Node3D.new();t.set_script(TOR);n.add_child(t);t.setup(dw,dh)
		t.position=Vector3(doors[k],0,zf-0.3);t.rotation.y=PI*0.5
		if k==1:t.open=0.85
		var l=OmniLight3D.new();n.add_child(l);l.position=Vector3(doors[k],H-1.0,zf-9);l.omni_range=12;l.light_energy=2.2
	label(n,"RADEBERG CUSTOMS",Vector3(0,H-1.5,zf+0.05),1.7,Color(1,0.72,0.15))
	label(n,"TUNING · LACK · FELGEN · NOS",Vector3(0,H-2.6,zf+0.05),0.8,Color(0.95,0.95,0.92))

func waffenladen(n:Node3D,w:float,d:float):
	var b=Batch.new();var brick=Mats.bricks(0.45);var dark=Mats.flat(Color(0.12,0.12,0.13),0.5,0.6);var conc=Mats.pbr("concrete",0.4,Color(0.6,0.6,0.6))
	var x0=-w*0.5;var x1=w*0.5;var zf=d*0.5;var zb=-d*0.5;var H=8.5
	b.box(conc,Vector3(x0,-0.6,zb),Vector3(x1,0.02,zf))
	b.box(brick,Vector3(x0,0,zb),Vector3(x1,H,zf-0.4))
	b.box(Mats.flat(Color(0.25,0.25,0.27),0.7),Vector3(x0-0.2,H,zb-0.2),Vector3(x1+0.2,H+0.5,zf+0.2))
	# Schaufenster mit Gittern, Tür
	b.box(Mats.glass(),Vector3(x0+1,0.6,zf-0.45),Vector3(-1.5,3.4,zf-0.3));b.box(Mats.glass(),Vector3(2.5,0.6,zf-0.45),Vector3(x1-1,3.4,zf-0.3))
	for x in range(int(x0)+1,int(x1),1):
		if x>-1.5 and x<2.5:continue
		b.box(dark,Vector3(x-0.03,0.6,zf-0.25),Vector3(x+0.03,3.4,zf-0.19))
	b.box(Mats.flat(Color(0.2,0.12,0.08),0.6),Vector3(-1.2,0,zf-0.45),Vector3(2.2,2.6,zf-0.35))
	# Schild mit Pistolen-Silhouette
	b.box(Mats.flat(Color(0.08,0.08,0.09),0.4),Vector3(x0+0.5,3.8,zf-0.4),Vector3(x1-0.5,5.6,zf-0.2))
	b.box(Mats.flat(Color(0.85,0.1,0.08),0.4),Vector3(x1-3.6,4.3,zf-0.19),Vector3(x1-1.2,4.8,zf-0.15))
	b.box(Mats.flat(Color(0.85,0.1,0.08),0.4),Vector3(x1-1.9,3.95,zf-0.19),Vector3(x1-1.4,4.5,zf-0.15))
	for wx in [x0+2.2,0.0,x1-2.2]:window(b,wx-0.7,6.0,wx+0.7,7.8,zf-0.4,Mats.flat(Color(0.85,0.83,0.78),0.6))
	b.commit(n)
	label(n,"WAFFEN KRAUSE",Vector3(-1.2,4.75,zf-0.12),1.25,Color(0.95,0.95,0.9))

func kleiderladen(n:Node3D,w:float,d:float):
	var b=Batch.new();var plaster=Mats.pbr("plaster_cream",0.35);var conc=Mats.pbr("concrete",0.4,Color(0.6,0.6,0.6))
	var x0=-w*0.5;var x1=w*0.5;var zf=d*0.5;var zb=-d*0.5;var H=12.0
	b.box(conc,Vector3(x0,-0.6,zb),Vector3(x1,0.02,zf))
	b.box(plaster,Vector3(x0,4.2,zb),Vector3(x1,H,zf-0.3))
	b.box(plaster,Vector3(x0,0,zb),Vector3(x1,4.2,zb+0.4));b.box(plaster,Vector3(x0,0,zb),Vector3(x0+0.6,4.2,zf-0.3));b.box(plaster,Vector3(x1-0.6,0,zb),Vector3(x1,4.2,zf-0.3))
	b.box(Mats.shop_glass(),Vector3(x0+0.6,0.1,zf-0.42),Vector3(x1-0.6,4.0,zf-0.36))
	b.box(Mats.flat(Color(0.86,0.83,0.78),0.5),Vector3(x0+0.6,0,zb+0.4),Vector3(x1-0.6,0.02,zf-0.4))
	# Kleiderstangen und Puppen im Schaufenster
	var cols=[Color(0.7,0.1,0.15),Color(0.1,0.2,0.45),Color(0.85,0.85,0.8),Color(0.15,0.15,0.15),Color(0.3,0.5,0.25),Color(0.9,0.7,0.2)]
	for k in 3:
		var z=zb+2.5+k*3.0
		b.box(Mats.flat(Color(0.7,0.7,0.72),0.3,0.8),Vector3(x0+2,1.6,z),Vector3(x1-2,1.65,z+0.05))
		for j in 14:b.box(Mats.flat(cols[(j+k)%cols.size()],0.85),Vector3(x0+2.2+j*(w-4.4)/14.0,0.7,z-0.25),Vector3(x0+2.5+j*(w-4.4)/14.0,1.6,z+0.3))
	# Markise und Fenster oben
	b.box_rot(Mats.flat(Color(0.1,0.28,0.2),0.8),Vector3(0,4.35,zf+0.6),Vector3(w-0.4,0.06,1.8),Basis(Vector3(1,0,0),0.3))
	for k in 2:
		for wx in range(int(x0)+2,int(x1)-1,3):window(b,wx,6.2+k*3,wx+1.4,8.0+k*3,zf-0.3,Mats.flat(Color(0.95,0.95,0.93),0.5))
	b.box(Mats.flat(Color(0.1,0.28,0.2),0.5),Vector3(x0+1,4.75,zf-0.3),Vector3(x1-1,5.9,zf-0.15))   # Schildband
	b.commit(n)
	label(n,"STOFFWECHSEL",Vector3(0,5.45,zf-0.13),1.2,Color(0.98,0.98,0.95))
	label(n,"MODE · SCHUHE · CAPS",Vector3(0,4.97,zf-0.13),0.42,Color(0.95,0.8,0.35))
	# Schaufensterpuppen (echte Figuren, weiß lackiert, stehend)
	var PE=load("res://scripts/people.gd");var r2=RandomNumberGenerator.new();r2.seed=3
	for k in 3:
		var base=["joe","female","daya"][k]
		var p=PE.make(base,r2,{"skin":Color(0.93,0.92,0.9),"hair":Color(0.93,0.92,0.9),"tint":[Color(0.6,0.07,0.07),Color(0.12,0.2,0.45),Color(0.9,0.9,0.88)][k],"mix":0.9,"height":1.8})
		n.add_child(p);p.position=Vector3(-w*0.3+k*w*0.3,0.05,zf-1.6);p.rotation.y=0.3-k*0.3
		PE.play(p,"idle",0.0,0.0)
