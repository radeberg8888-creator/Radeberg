extends Node3D
# Baut eine detailreiche Radeberger Altstadtstraße: Fahrbahn, Gehwege, Gründerzeithäuser, Läden, Bäume, Laternen, Autos, Passanten
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
const U=preload("res://scripts/anim_util.gd")
const FE=preload("res://scripts/fire_escape.gd")
var SHUTTER=load("res://assets/props/polyhaven/rollershutter.glb")
var rng:=RandomNumberGenerator.new()
const ROAD_W:=14.0
const WALK_W:=4.5
const LEN:=220.0
var FX:=ROAD_W*0.5+WALK_W   # Fassadenflucht

func build(seed_:=7):
	rng.seed=seed_
	_ground()
	var z=-LEN*0.5
	while z<LEN*0.5-12:
		var w=rng.randf_range(11.0,18.0)
		if z>=-14 and z<-4:z=-4;continue   # Querstraße frei lassen
		if z<-14 and z+w>-14-11.0:w=-14-z
		_building(1,z,w);z+=w
	z=-LEN*0.5+5
	while z<LEN*0.5-12:
		var w=rng.randf_range(11.0,18.0)
		if z>=-14 and z<-4:z=-4;continue
		if z<-14 and z+w>-14-11.0:w=-14-z
		_building(-1,z,w);z+=w
	_props()
	_church(Vector3(0,0,-LEN*0.5-30))

# ---------------- Boden ----------------
func _ground():
	var b=Batch.new()
	var asph=Mats.pbr("asphalt",0.18);var pav=Mats.pbr("pavers",0.45);var curb=Mats.pbr("concrete",0.6,Color(0.86,0.85,0.82));var cob=Mats.pbr("cobble",0.35)
	var oldt=Mats.pbr("cobbleasphalt",0.3)
	b.box(asph,Vector3(-ROAD_W*0.5,-0.2,-4),Vector3(ROAD_W*0.5,0,LEN*0.5))
	b.box(oldt,Vector3(-ROAD_W*0.5,-0.2,-LEN*0.5),Vector3(ROAD_W*0.5,0,-4))
	for s in [-1,1]:
		var x0=ROAD_W*0.5;var x1=FX+0.5
		b.box(pav,Vector3(min(s*x0,s*x1),-0.2,-LEN*0.5),Vector3(max(s*x0,s*x1),0.15,LEN*0.5))
		b.box(curb,Vector3(min(s*x0,s*(x0+0.25)),-0.2,-LEN*0.5),Vector3(max(s*x0,s*(x0+0.25)),0.16,LEN*0.5))
		# Rinnstein aus Pflaster
		b.box(cob,Vector3(min(s*(x0-0.5),s*x0),-0.2,-LEN*0.5),Vector3(max(s*(x0-0.5),s*x0),0.005,LEN*0.5))
	# Querstraße mit Kopfsteinpflaster
	b.box(oldt,Vector3(-60,-0.2,-14),Vector3(60,0.0,-4))
	b.box(Mats.pbr("grass",0.2),Vector3(-300,-0.25,-300),Vector3(300,-0.2,300))
	b.commit(self)
	# Fahrbahnmarkierung
	var paint=Mats.flat(Color(0.86,0.85,0.8),0.5);var mb=Batch.new()
	var zz=-LEN*0.5
	while zz<LEN*0.5:
		if zz<-16 or zz>-2:mb.box(paint,Vector3(-0.07,0.001,zz),Vector3(0.07,0.012,zz+4.5))
		zz+=9
	for s in [-1,1]:mb.box(paint,Vector3(s*ROAD_W*0.5-s*0.4-0.06,0.001,-LEN*0.5),Vector3(s*ROAD_W*0.5-s*0.4+0.06,0.012,LEN*0.5))
	for k in 8:mb.box(paint,Vector3(-6+k*1.6,0.001,-1.6),Vector3(-5.4+k*1.6,0.012,1.4))   # Zebrastreifen
	mb.commit(self,false)

# ---------------- Gebäude ----------------
func _building(side:int,z0:float,width:float):
	var floors=rng.randi_range(3,5);var gh=4.4;var fh=3.25;var H=gh+floors*fh;var D=12.0
	var cols=["plaster_cream","plaster_ochre","plaster_grey","plaster_blue","plaster_rose","plaster_white"]
	var brick=rng.randf()<0.18
	var wall=Mats.bricks(0.45) if brick else Mats.pbr(cols[rng.randi()%cols.size()],0.35)
	var stone=Mats.pbr("concrete",0.5,Color(0.93,0.88,0.78));var frame=Mats.flat(Color(0.93,0.92,0.88),0.45);var dark=Mats.flat(Color(0.05,0.05,0.06),0.9)
	var glass=Mats.glass();var roofm=Mats.pbr("roof",0.5)
	# lokaler Rahmen: u entlang Straße (z), v hoch, w in das Haus hinein
	var xf:Transform3D
	if side>0:xf=Transform3D(Basis(Vector3(0,0,-1),Vector3(0,1,0),Vector3(1,0,0)),Vector3(FX,0,z0+width))
	else:xf=Transform3D(Basis(Vector3(0,0,1),Vector3(0,1,0),Vector3(-1,0,0)),Vector3(-FX,0,z0))
	var b=Batch.new()
	var P=func(u,v,w):return Vector3(u,v,w)
	# Hauptkörper hinter der Fassadenebene
	var shop=rng.randf()<0.85
	b.box(wall,Vector3(0,gh,0.32),Vector3(width,H,D),xf)
	b.box(wall,Vector3(0,0.15,3.4 if shop else 0.32),Vector3(width,gh,D),xf)
	# Sockel
	b.box(stone,Vector3(0,0.15,-0.05),Vector3(width,0.75,0.35),xf)
	# ---- Erdgeschoss: Laden
	var doorU=width-2.2
	if shop:
		var sx0=0.7;var sx1=width-3.0
		# Pfeiler und Sturz aus Naturstein
		b.box(stone,Vector3(0,0.75,0),Vector3(sx0,gh,0.32),xf);b.box(stone,Vector3(sx1,0.75,0),Vector3(width,gh,0.32),xf)
		b.box(stone,Vector3(sx0,3.6,0),Vector3(sx1,gh,0.32),xf)
		b.box(stone,Vector3(0,0.15,0.32),Vector3(sx0,gh,3.4),xf);b.box(stone,Vector3(sx1,0.15,0.32),Vector3(width,gh,3.4),xf)
		# Schaufenster mit Rahmen und Sprossen
		var fr=Mats.flat(Color(0.12,0.12,0.13),0.4,0.6)
		b.box(fr,Vector3(sx0,0.75,0.12),Vector3(sx1,0.88,0.28),xf);b.box(fr,Vector3(sx0,3.48,0.12),Vector3(sx1,3.6,0.28),xf);b.box(fr,Vector3(sx0,0.75,0.12),Vector3(sx0+0.1,3.6,0.28),xf);b.box(fr,Vector3(sx1-0.1,0.75,0.12),Vector3(sx1,3.6,0.28),xf)
		b.box(Mats.shop_glass(),Vector3(sx0+0.08,0.85,0.16),Vector3(sx1-0.08,3.5,0.2),xf)
		if rng.randf()<0.12:   # geschlossener Laden: ein durchgehender Rollladen über die ganze Schaufensterbreite
			var rs=Node3D.new();rs.set_script(load("res://scripts/rolltor.gd"));add_child(rs);rs.setup(sx1-sx0-0.04,3.6-0.75,Color(0.5,0.52,0.54))
			rs.transform=xf*Transform3D(Basis(Vector3.UP,PI*0.5),Vector3((sx0+sx1)*0.5,0.75,0.06))
		var u=sx0+2.2
		while u<sx1-0.6:
			b.box(Mats.flat(Color(0.12,0.12,0.13),0.4,0.6),Vector3(u-0.04,0.85,0.12),Vector3(u+0.04,3.5,0.2),xf);u+=2.2
		# Ladeninneres: Rückwand, Decke mit Lichtpaneelen, Boden, Wandregal mit Waren, Mittelregal, Theke
		var back=Mats.flat(Color(0.82,0.78,0.7),0.8);var shelf=Mats.flat(Color(0.32,0.24,0.17),0.7);var metal_s=Mats.flat(Color(0.7,0.7,0.72),0.4,0.6)
		b.box(back,Vector3(sx0,0.8,3.2),Vector3(sx1,3.5,3.3),xf);b.box(Mats.flat(Color(0.9,0.89,0.86),0.8),Vector3(sx0,3.45,0.32),Vector3(sx1,3.55,3.2),xf);b.box(Mats.pbr('pavers',0.6,Color(0.8,0.75,0.7)),Vector3(sx0,0.7,0.32),Vector3(sx1,0.8,3.2),xf)
		var lu=sx0+0.6
		while lu<sx1-1.0:b.box(Mats.emissive(Color(1.0,0.96,0.88),1.2),Vector3(lu,3.43,1.2),Vector3(lu+0.9,3.45,1.8),xf);lu+=1.8
		var prod=[Color(0.75,0.2,0.15),Color(0.95,0.82,0.35),Color(0.25,0.45,0.7),Color(0.9,0.9,0.85),Color(0.3,0.6,0.3),Color(0.55,0.35,0.6)]
		for k in 3:
			var y=1.2+k*0.65
			b.box(shelf,Vector3(sx0+0.2,y-0.03,2.8),Vector3(sx1-0.2,y,3.2),xf)
			var p=sx0+0.25
			while p<sx1-0.45:
				var w_=rng.randf_range(0.12,0.3);var h_=rng.randf_range(0.15,0.42)
				b.box(Mats.flat(prod[rng.randi()%prod.size()],0.7),Vector3(p,y,2.85),Vector3(p+w_,y+h_,3.15),xf);p+=w_+0.03
		var mid=(sx0+sx1)*0.5
		b.box(metal_s,Vector3(mid-1.2,0.8,1.6),Vector3(mid+1.2,1.6,2.0),xf)
		for k in 2:
			var p2=mid-1.15
			while p2<mid+1.0:
				var w2=rng.randf_range(0.12,0.25);b.box(Mats.flat(prod[rng.randi()%prod.size()],0.7),Vector3(p2,1.6+0.0*k,1.62+k*0.2),Vector3(p2+w2,1.6+rng.randf_range(0.12,0.3),1.78+k*0.2),xf);p2+=w2+0.04
		b.box(shelf,Vector3(sx1-1.6,0.8,0.9),Vector3(sx1-0.3,1.85,1.4),xf)
		# Markise
		if rng.randf()<0.6:
			var awc=[Color(0.62,0.12,0.1),Color(0.1,0.32,0.2),Color(0.12,0.2,0.42),Color(0.75,0.55,0.12)][rng.randi()%4]
			b.box_rot(Mats.flat(awc,0.85),Vector3((sx0+sx1)*0.5,3.45,-0.75),Vector3(sx1-sx0+0.3,0.05,1.7),Basis(Vector3(1,0,0),-0.35),xf)
		# Ladenschild
		var names=["BÄCKEREI MÜLLER","FLEISCHEREI","APOTHEKE AM MARKT","DÖNER KEBAB","SPÄTI","BLUMEN RÖDER","FRISEUR","KIOSK","BUCHHANDLUNG","HANDY-SHOP","EISCAFÉ VENEZIA","SPARKASSE","RADEBERGER STUBE","OPTIKER","SCHUHHAUS"]
		var lb=Label3D.new();lb.text=names[rng.randi()%names.size()];lb.font_size=96;lb.pixel_size=0.0045;lb.outline_size=0
		lb.modulate=Color(0.96,0.94,0.88) if rng.randf()<0.6 else Color(0.95,0.78,0.3);lb.shaded=true
		add_child(lb);lb.transform=xf*Transform3D(Basis(Vector3(0,1,0),PI),Vector3((sx0+sx1)*0.5,4.0,-0.02))
	else:
		# Wohnhaus-Erdgeschoss: Sockel, Fenster mit Laibung, Gitter (statt fensterloser Wand)
		var ng=int(max(1,floor((width-3.5)/2.6)));var gp=(width-3.5)/ng;var wy0=1.35;var wy1=3.35;var ul2=0.0
		b.box(stone,Vector3(0,0.75,0),Vector3(width,wy0,0.32),xf);b.box(stone,Vector3(0,wy1,0),Vector3(width,gh,0.32),xf)
		for i in ng:
			var cu=0.4+gp*(i+0.5);var a=cu-0.62;var c=cu+0.62
			b.box(stone,Vector3(ul2,wy0,0),Vector3(a,wy1,0.32),xf);ul2=c
			b.box(frame,Vector3(a,wy0,0.22),Vector3(a+0.08,wy1,0.3),xf);b.box(frame,Vector3(c-0.08,wy0,0.22),Vector3(c,wy1,0.3),xf)
			b.box(frame,Vector3(a,wy1-0.08,0.22),Vector3(c,wy1,0.3),xf);b.box(frame,Vector3(a,wy0,0.22),Vector3(c,wy0+0.08,0.3),xf)
			b.box(frame,Vector3(cu-0.035,wy0,0.23),Vector3(cu+0.035,wy1,0.29),xf)
			b.box(glass,Vector3(a+0.05,wy0+0.05,0.25),Vector3(c-0.05,wy1-0.05,0.27),xf)
			b.box(Mats.flat([Color(0.92,0.9,0.84),Color(0.75,0.68,0.55)][rng.randi()%2],1.0),Vector3(a+0.1,wy0+0.1,0.28),Vector3(c-0.1,wy0+0.9,0.31),xf)
			b.box(stone,Vector3(a-0.1,wy0-0.1,-0.1),Vector3(c+0.1,wy0,0.3),xf)
		b.box(stone,Vector3(ul2,wy0,0),Vector3(width,wy1,0.32),xf)
	# Haustür mit Oberlicht
	b.box(stone,Vector3(doorU-0.85,0.15,-0.08),Vector3(doorU+0.85,3.4,0.05),xf)
	b.box(Mats.flat(Color(0.28,0.16,0.09),0.55),Vector3(doorU-0.6,0.15,0.12),Vector3(doorU+0.6,2.6,0.2),xf)
	b.box(glass,Vector3(doorU-0.6,2.7,0.12),Vector3(doorU+0.6,3.2,0.16),xf)
	b.box(Mats.flat(Color(0.8,0.7,0.3),0.3,1.0),Vector3(doorU+0.38,1.2,0.06),Vector3(doorU+0.44,1.3,0.12),xf)
	if abs(z0+4.0)<0.01 or abs(z0+width+14.0)<0.01:
		var lv=[];for k in floors:lv.append(gh+k*fh)
		var fe=FE.build(lv);add_child(fe)
		var atu=0.0 if (side<0)==(abs(z0+4.0)<0.01) else width
		var bz=Basis(Vector3(0,0,-1),Vector3(0,1,0),Vector3(1,0,0)) if atu==0.0 else Basis(Vector3(0,0,1),Vector3(0,1,0),Vector3(-1,0,0))
		fe.transform=xf*Transform3D(bz,Vector3(atu,0,D*0.5))
	# Gesims über dem Erdgeschoss
	b.box(stone,Vector3(-0.05,gh-0.05,-0.28),Vector3(width+0.05,gh+0.25,0.32),xf)
	# ---- Obergeschosse
	var n=int(max(2,floor((width-1.0)/2.6)));var pitch=(width-1.0)/n;var ww=1.25;var wh=1.85
	for f in floors:
		var y0=gh+f*fh;var wy0=y0+0.85;var wy1=wy0+wh
		# Fassadenscheibe: Brüstung, Sturz, Pfeiler (echte Fensterlaibungen)
		b.box(wall,Vector3(0,y0+0.25,0),Vector3(width,wy0,0.32),xf)
		b.box(wall,Vector3(0,wy1,0),Vector3(width,y0+fh,0.32),xf)
		var ul=0.5
		for i in n:
			var cu=0.5+pitch*(i+0.5);var a=cu-ww*0.5;var c=cu+ww*0.5
			b.box(wall,Vector3(ul,wy0,0),Vector3(a,wy1,0.32),xf);ul=c
			# Fenster: Rahmen, Kreuz, Glas, Gardine
			b.box(frame,Vector3(a,wy0,0.22),Vector3(a+0.08,wy1,0.3),xf);b.box(frame,Vector3(c-0.08,wy0,0.22),Vector3(c,wy1,0.3),xf)
			b.box(frame,Vector3(a,wy1-0.08,0.22),Vector3(c,wy1,0.3),xf);b.box(frame,Vector3(a,wy0,0.22),Vector3(c,wy0+0.08,0.3),xf)
			b.box(frame,Vector3(cu-0.035,wy0,0.23),Vector3(cu+0.035,wy1,0.29),xf);b.box(frame,Vector3(a,wy1-0.6,0.23),Vector3(c,wy1-0.53,0.29),xf)
			b.box(glass,Vector3(a+0.05,wy0+0.05,0.25),Vector3(c-0.05,wy1-0.05,0.27),xf)
			if rng.randf()<0.5:b.box(Mats.flat([Color(0.92,0.9,0.84),Color(0.75,0.68,0.55),Color(0.55,0.6,0.62)][rng.randi()%3],1.0),Vector3(a+0.1,wy0+0.1,0.28),Vector3(a+0.1+rng.randf_range(0.2,0.45),wy1-0.1,0.31),xf)
			# Fensterbank und Verdachung (Gründerzeit)
			b.box(stone,Vector3(a-0.12,wy0-0.12,-0.12),Vector3(c+0.12,wy0,0.3),xf)
			if f<floors-1 or rng.randf()<0.5:
				b.box(stone,Vector3(a-0.18,wy1+0.05,-0.14),Vector3(c+0.18,wy1+0.2,0.3),xf)
				if f==0 and rng.randf()<0.6:b.prism(stone,Vector3(cu,wy1+0.42,0.08),Vector3(ww+0.5,0.45,0.44),xf)
			# Blumenkasten
			if rng.randf()<0.12:
				b.box(Mats.flat(Color(0.5,0.25,0.15),0.8),Vector3(a,wy0+0.02,-0.3),Vector3(c,wy0+0.22,-0.1),xf)
				for k in 5:b.add_mesh(SphereMesh.new() if false else Batch.BOX,Mats.flat(Color(0.75,0.15,0.2) if k%2 else Color(0.25,0.45,0.15),0.9),xf*Transform3D(Basis().scaled(Vector3(0.22,0.18,0.18)),Vector3(a+0.15+k*0.24,wy0+0.3,-0.2)))
			# Satellitenschüssel
			if rng.randf()<0.05:b.cyl(Mats.flat(Color(0.85,0.85,0.85),0.4),Vector3(c+0.35,wy1-0.3,-0.2),0.3,0.06,xf,Basis(Vector3(1,0,0),PI*0.5))
		b.box(wall,Vector3(ul,wy0,0),Vector3(width,wy1,0.32),xf)
		# Gurtgesims
		b.box(stone,Vector3(-0.02,y0+fh-0.12,-0.12),Vector3(width+0.02,y0+fh+0.05,0.32),xf)
		# Balkon
		if f<floors and rng.randf()<0.25:
			var bu=0.5+pitch*(rng.randi()%n+0.5)
			b.box(stone,Vector3(bu-1.3,y0+0.05,-1.25),Vector3(bu+1.3,y0+0.25,0.32),xf)
			var rail=Mats.flat(Color(0.12,0.13,0.13),0.45,0.7)
			b.box(rail,Vector3(bu-1.3,y0+1.18,-1.25),Vector3(bu+1.3,y0+1.24,-1.19),xf)
			var k=bu-1.25
			while k<=bu+1.26:b.box(rail,Vector3(k-0.012,y0+0.25,-1.24),Vector3(k+0.012,y0+1.18,-1.21),xf);k+=0.12
			for s2 in [-1,1]:b.box(rail,Vector3(bu+s2*1.3-0.025,y0+0.25,-1.25),Vector3(bu+s2*1.3+0.025,y0+1.24,0.0),xf)
	# Hauptgesims und Dach
	b.box(stone,Vector3(-0.1,H-0.2,-0.45),Vector3(width+0.1,H+0.25,0.32),xf)
	b.box(stone,Vector3(-0.05,H-0.55,-0.2),Vector3(width+0.05,H-0.2,0.32),xf)
	var rh=rng.randf_range(3.8,5.2)
	b.prism(roofm,Vector3(width*0.5,H+0.25+rh*0.5,D*0.5+0.16),Vector3(D+0.6,rh,width+0.3),xf,Basis(Vector3(0,1,0),PI*0.5))
	# Gauben
	for i in rng.randi_range(0,2):
		var du=rng.randf_range(2.0,width-2.0)
		b.box(wall,Vector3(du-0.8,H+0.25,1.4),Vector3(du+0.8,H+2.0,3.0),xf)
		b.box(glass,Vector3(du-0.5,H+0.6,1.36),Vector3(du+0.5,H+1.7,1.4),xf)
		b.prism(roofm,Vector3(du,H+2.35,2.2),Vector3(2.0,0.75,1.8),xf)
	# Schornsteine
	for i in rng.randi_range(1,2):
		var cu2=rng.randf_range(1.5,width-1.5);b.box(Mats.bricks(0.8),Vector3(cu2-0.4,H,4.5),Vector3(cu2+0.4,H+rh+0.9,5.3),xf)
	# Fallrohr
	b.cyl(Mats.flat(Color(0.45,0.45,0.43),0.4,0.8),Vector3(0.18,H*0.5,-0.08),0.055,H,xf)
	b.commit(self)
	# Hausnummer
	var hn=Label3D.new();hn.text=str(rng.randi_range(1,98));hn.font_size=48;hn.pixel_size=0.004;hn.modulate=Color(0.95,0.95,0.95);add_child(hn)
	hn.transform=xf*Transform3D(Basis(Vector3(0,1,0),PI),Vector3(doorU+1.05,2.9,-0.11))

# ---------------- Straßenmöbel, Bäume, Autos ----------------
var lantern_scene:PackedScene
func _props():
	var b=Batch.new();var metal=Mats.flat(Color(0.12,0.14,0.13),0.45,0.6)
	# Laternen (historisch) – Modell "Lantern" von Khronos, sonst Mast
	lantern_scene=load("res://assets/props/lantern.glb")
	var zz=-LEN*0.5+8
	while zz<LEN*0.5:
		for s in [-1,1]:
			if abs(zz+9)<6:continue
			var L=lantern_scene.instantiate();add_child(L);L.scale=Vector3.ONE*0.2;L.position=Vector3(s*(ROAD_W*0.5+0.7),0.15,zz+(0 if s>0 else 12));L.rotation.y=PI*0.5 if s>0 else -PI*0.5
		zz+=24
	# Bäume mit echtem Laub
	zz=-LEN*0.5+20
	while zz<LEN*0.5-10:
		for s in [-1,1]:
			if abs(zz+9)<8:continue
			_tree(Vector3(s*(ROAD_W*0.5+1.9),0.15,zz+(s*5)))
		zz+=24
	# Poller, Mülleimer, Bänke, Schilder
	for s in [-1,1]:
		var k=-LEN*0.5
		while k<LEN*0.5:
			if abs(k+9)>8:b.cyl(metal,Vector3(s*(ROAD_W*0.5+0.45),0.6,k),0.07,0.9)
			k+=3.5
	for p in [Vector3(8.4,0.15,6),Vector3(-8.4,0.15,30),Vector3(8.4,0.15,-40)]:
		b.cyl(Mats.flat(Color(0.18,0.32,0.2),0.5,0.3),p+Vector3(0,0.45,0),0.28,0.9);b.cyl(metal,p+Vector3(0,0.93,0),0.3,0.05)
	for p in [Vector3(10.4,0.15,12),Vector3(-10.4,0.15,-28)]:
		var wood=Mats.flat(Color(0.42,0.27,0.15),0.7)
		for k in 3:b.box(wood,p+Vector3(-0.25+k*0.17,0.45,-0.9),p+Vector3(-0.12+k*0.17,0.5,0.9))
		for k in 2:b.box(wood,p+Vector3(0.28,0.62+k*0.17,-0.9),p+Vector3(0.32,0.74+k*0.17,0.9))
		for d in [-0.75,0.75]:b.box(metal,p+Vector3(-0.3,0,d-0.03),p+Vector3(0.32,0.85,d+0.03))
	# Verkehrsschilder
	for sg in [[Vector3(7.6,0.15,-17),Color(0.8,0.1,0.1)],[Vector3(-7.6,0.15,2),Color(0.1,0.25,0.65)]]:
		b.cyl(Mats.flat(Color(0.6,0.6,0.6),0.4,0.8),sg[0]+Vector3(0,1.4,0),0.04,2.8)
		b.cyl(Mats.flat(sg[1],0.5),sg[0]+Vector3(0,2.7,0),0.32,0.03,Transform3D.IDENTITY,Basis(Vector3(0,0,1),PI*0.5))
	# Bushaltestelle
	var bp=Vector3(9.2,0.15,24);var gl=Mats.glass()
	b.box(metal,bp+Vector3(-0.05,0,-2),bp+Vector3(0.05,2.6,2));b.box(metal,bp+Vector3(-0.8,2.5,-2.1),bp+Vector3(1.0,2.62,2.1))
	b.box(gl,bp+Vector3(0.0,0.3,-1.9),bp+Vector3(0.03,2.4,1.9))
	b.commit(self)
	var st=Label3D.new();st.text="Hauptstraße";st.font_size=64;st.pixel_size=0.004;st.modulate=Color(1,1,1);add_child(st);st.position=Vector3(-7.6,2.35,2);st.rotation.y=PI*0.5
	# Absperrung mit Pylonen und Fass
	var cone=load("res://assets/props/trafficcone.glb")
	for k in 4:
		var c=cone.instantiate();add_child(c);c.position=Vector3(-5.5+k*0.9,0.0,-30);c.scale=Vector3.ONE*1.0
	# Litfaßsäulen
	for p in [Vector3(-9.8,0.15,-2),Vector3(9.9,0.15,-60)]:
		var lb=Batch.new();var pm=StandardMaterial3D.new();pm.albedo_texture=load("res://assets/textures/poster_albedo.jpg");pm.roughness=0.8
		var cy=CylinderMesh.new();cy.top_radius=0.6;cy.bottom_radius=0.6;cy.height=2.8;cy.radial_segments=32
		var mi=MeshInstance3D.new();mi.mesh=cy;mi.material_override=pm;add_child(mi);mi.position=p+Vector3(0,1.55,0)
		lb.cyl(Mats.flat(Color(0.15,0.25,0.18),0.5,0.4),p+Vector3(0,3.05,0),0.68,0.25);lb.cyl(Mats.flat(Color(0.15,0.25,0.18),0.5,0.4),p+Vector3(0,0.12,0),0.66,0.25)
		lb.add_mesh(Batch.PRISM,Mats.flat(Color(0.15,0.25,0.18),0.5,0.4),Transform3D(Basis().scaled(Vector3(1.3,0.5,1.3)),p+Vector3(0,3.4,0)));lb.commit(self)
	# Fahrradständer mit Rädern (einfach)
	var rack=Batch.new();var steel=Mats.flat(Color(0.7,0.7,0.72),0.3,0.9)
	for k in 5:rack.cyl(steel,Vector3(10.6,0.6,-18+k*0.9),0.03,0.9,Transform3D.IDENTITY)
	rack.commit(self)
	# Litfaßsäulen
	for p in [Vector3(-9.8,0.15,-2),Vector3(9.9,0.15,-60)]:
		var lb=Batch.new();var pm=StandardMaterial3D.new();pm.albedo_texture=load("res://assets/textures/poster_albedo.jpg");pm.roughness=0.8
		var cy=CylinderMesh.new();cy.top_radius=0.6;cy.bottom_radius=0.6;cy.height=2.8;cy.radial_segments=32
		var mi=MeshInstance3D.new();mi.mesh=cy;mi.material_override=pm;add_child(mi);mi.position=p+Vector3(0,1.55,0)
		var gr=Mats.flat(Color(0.15,0.25,0.18),0.5,0.4)
		lb.cyl(gr,p+Vector3(0,3.05,0),0.68,0.25);lb.cyl(gr,p+Vector3(0,0.12,0),0.66,0.25)
		lb.add_mesh(Batch.PRISM,gr,Transform3D(Basis().scaled(Vector3(1.3,0.5,1.3)),p+Vector3(0,3.4,0)));lb.commit(self)
	var br=load("res://assets/props/barrel.glb").instantiate();add_child(br);br.position=Vector3(-9.6,0.15,-33);br.scale=Vector3.ONE*0.012

func _tree(p:Vector3):
	var b=Batch.new();var bark=Mats.pbr("bark",0.8)
	b.cyl(bark,p+Vector3(0,1.9,0),0.17,3.8)
	for i in 6:
		var a=rng.randf()*TAU;var tilt=rng.randf_range(0.5,0.9)
		var basis=Basis(Vector3(cos(a),0,sin(a)).cross(Vector3.UP).normalized(),tilt)
		b.cyl(bark,p+Vector3(cos(a)*0.5,3.9,sin(a)*0.5),0.07,2.0,Transform3D.IDENTITY,basis)
	b.box(Mats.pbr("cobble",0.6,Color(0.7,0.65,0.6)),p+Vector3(-0.8,-0.14,-0.8),p+Vector3(0.8,0.02,0.8))
	b.commit(self)
	# Laub als Blattkarten (MultiMesh)
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	var q=QuadMesh.new();q.size=Vector2(1.3,1.3);mm.mesh=q;mm.instance_count=650
	for i in mm.instance_count:
		var u=rng.randf()*TAU;var v=acos(2*rng.randf()-1);var r=pow(rng.randf(),0.33)*2.6
		var pos=p+Vector3(sin(v)*cos(u)*r*1.05,5.4+cos(v)*r*0.8,sin(v)*sin(u)*r*1.05)
		var bs=Basis.from_euler(Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)).scaled(Vector3.ONE*rng.randf_range(0.7,1.25))
		mm.set_instance_transform(i,Transform3D(bs,pos))
		var shade=0.65+0.45*(r/2.6)+rng.randf_range(-0.08,0.08)
		mm.set_instance_color(i,Color(shade*rng.randf_range(0.92,1.05),shade,shade*rng.randf_range(0.85,1.0)))
	var mi=MultiMeshInstance3D.new();mi.multimesh=mm
	var lm=StandardMaterial3D.new();lm.albedo_texture=load("res://assets/textures/leaves_albedo.png");lm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;lm.alpha_scissor_threshold=0.5
	lm.cull_mode=BaseMaterial3D.CULL_DISABLED;lm.vertex_color_use_as_albedo=true;lm.roughness=0.75;lm.backlight_enabled=true;lm.backlight=Color(0.25,0.35,0.1)
	mi.material_override=lm;add_child(mi)

# ---------------- Autos ----------------
func car(path:String,pos:Vector3,yaw:float,color:Color,scale:=1.0)->Node3D:
	var c=load(path).instantiate();add_child(c);c.position=pos;c.rotation.y=yaw;c.scale=Vector3.ONE*scale
	for m in c.find_children("*","MeshInstance3D",true,false):
		for s in m.mesh.get_surface_count():
			var mt=m.get_active_material(s)
			if mt is StandardMaterial3D:
				var nm:String=(mt.resource_name+" "+m.name).to_lower()
				if nm.contains("body") or nm.contains("paint") or nm.contains("carpaint"):
					var pm=mt.duplicate();pm.albedo_color=color;pm.metallic=0.75;pm.roughness=0.28;pm.clearcoat_enabled=true;pm.clearcoat=1.0;pm.clearcoat_roughness=0.05
					m.set_surface_override_material(s,pm)
	return c

# ---------------- Passanten ----------------
var walk_anim:Animation;var walk_skel:Skeleton3D
func walker(path:String,pos:Vector3,yaw:float,phase:float,tint:=Color(1,1,1))->Node3D:
	if walk_anim==null:
		var src=load("res://assets/animations/walking.glb").instantiate();add_child(src);src.visible=false
		var ap:AnimationPlayer=src.find_child("AnimationPlayer",true,false);walk_anim=ap.get_animation(ap.get_animation_list()[0]);walk_skel=U.find_skel(src)
	var s=load(path).instantiate();add_child(s);s.position=pos;s.rotation.y=yaw
	var old=s.find_child("AnimationPlayer",true,false);if old:old.stop()
	var sk=U.find_skel(s);U.play(s,U.retarget(walk_anim,walk_skel,sk,s),"walk",phase)
	if tint!=Color(1,1,1):
		for m in s.find_children("*","MeshInstance3D",true,false):
			for i in m.mesh.get_surface_count():
				var mt=m.get_active_material(i)
				if mt is StandardMaterial3D and not (mt.resource_name.to_lower().contains("skin") or mt.resource_name.to_lower().contains("head") or mt.resource_name.to_lower().contains("eye") or mt.resource_name.to_lower().contains("teeth") or mt.resource_name.to_lower().contains("hair")):
					var d=mt.duplicate();d.albedo_color=mt.albedo_color*tint;m.set_surface_override_material(i,d)
	return s

func _church(p:Vector3):
	var b=Batch.new();var st=Mats.pbr("plaster_white",0.3);var stone=Mats.pbr("concrete",0.5,Color(0.9,0.86,0.76));var roof=Mats.pbr("roof",0.4,Color(0.75,0.75,0.8))
	var cu=Mats.flat(Color(0.32,0.5,0.42),0.55,0.6)
	b.box(st,p+Vector3(-9,0,-34),p+Vector3(9,16,0))
	b.prism(roof,p+Vector3(0,16+5,-17),Vector3(19,10,35))
	b.box(st,p+Vector3(-4.5,0,-2),p+Vector3(4.5,34,7))
	b.box(stone,p+Vector3(-4.8,33,-2.3),p+Vector3(4.8,34.4,7.3))
	b.box(st,p+Vector3(-3.4,34.4,-0.9),p+Vector3(3.4,42,5.9))
	b.cyl(cu,p+Vector3(0,44.5,2.5),2.6,5.0)
	b.add_mesh(Batch.PRISM,cu,Transform3D(Basis().scaled(Vector3(4.5,9,4.5)),p+Vector3(0,51.5,2.5)))
	b.cyl(Mats.flat(Color(0.85,0.7,0.3),0.3,1.0),p+Vector3(0,57,2.5),0.06,2.5)
	for k in 3:
		b.box(Mats.glass(),p+Vector3(-1,8+k*9,7.0),p+Vector3(1,12+k*9,7.05))
	b.box(Mats.flat(Color(0.95,0.95,0.9),0.4),p+Vector3(-1.4,37,5.95),p+Vector3(1.4,39.8,6.0))
	b.box(Mats.flat(Color(0.3,0.2,0.12),0.6),p+Vector3(-1.4,0,7.0),p+Vector3(1.4,4.2,7.1))
	b.commit(self)
