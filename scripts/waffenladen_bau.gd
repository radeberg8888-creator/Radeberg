extends RefCounted
# Waffenladen "Waffen Krause" mit begehbarem Verkaufsraum: Schaufenster mit Gittern, Leuchtschild,
# innen Fliesenboden, Theke mit Glasvitrine (Pistolen), Wandregale mit Gewehren, Munitionskisten, Deckenlicht.
# Ursprung = Mitte der Grundfläche, Front zeigt nach +z. Darüber zwei Wohnetagen aus Backstein.
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
const W="res://assets/weapons/"
var breite:=13.0
var tiefe:=14.0

func bau()->Node3D:
	var root=Node3D.new();root.name="WaffenKrause"
	var b=Batch.new()
	var x0=-breite*0.5;var x1=breite*0.5;var zf=tiefe*0.5;var zb=-tiefe*0.5;var H=4.4;var H2=H+6.2
	var ziegel=Mats.bricks(0.45);var dunkel=Mats.flat(Color(0.1,0.1,0.11),0.5,0.6);var putz=Mats.flat(Color(0.82,0.8,0.76),0.85)
	var fliesen=Mats.pbr("pavers",0.9,Color(0.75,0.72,0.68));var decke=Mats.flat(Color(0.9,0.9,0.88),0.9)
	var holz=Mats.flat(Color(0.32,0.2,0.12),0.6);var glas=Mats.glass();var licht=Mats.emissive(Color(1,0.97,0.9),2.2)
	var metall=Mats.flat(Color(0.35,0.36,0.38),0.35,0.8)
	var wand=0.3
	# Außenwände Erdgeschoss (vorn mit Schaufenstern und Tür)
	b.box(ziegel,Vector3(x0,0,zb),Vector3(x0+wand,H,zf));b.box(ziegel,Vector3(x1-wand,0,zb),Vector3(x1,H,zf))
	b.box(ziegel,Vector3(x0,0,zb),Vector3(x1,H,zb+wand))
	# Front: Pfeiler, Brüstung, Sturz
	for px in [x0,-1.1,1.1,x1-0.6]:b.box(ziegel,Vector3(px,0,zf-wand),Vector3(px+0.6,H,zf))
	b.box(ziegel,Vector3(x0,3.3,zf-wand),Vector3(x1,H,zf))
	b.box(ziegel,Vector3(x0,0,zf-wand),Vector3(-1.1,0.7,zf));b.box(ziegel,Vector3(1.7,0,zf-wand),Vector3(x1,0.7,zf))
	b.box(glas,Vector3(x0+0.6,0.7,zf-0.2),Vector3(-1.1,3.3,zf-0.15));b.box(glas,Vector3(1.7,0.7,zf-0.2),Vector3(x1-0.6,3.3,zf-0.15))
	# Gitter vor den Schaufenstern
	var gx=x0+0.8
	while gx<x1-0.6:
		if gx<-1.1 or gx>1.7:b.box(dunkel,Vector3(gx-0.025,0.7,zf+0.02),Vector3(gx+0.025,3.3,zf+0.07))
		gx+=0.35
	for gy in [0.75,2.0,3.25]:
		b.box(dunkel,Vector3(x0+0.6,gy,zf+0.02),Vector3(-1.1,gy+0.05,zf+0.07));b.box(dunkel,Vector3(1.7,gy,zf+0.02),Vector3(x1-0.6,gy+0.05,zf+0.07))
	# Tür (offen, Rahmen)
	b.box(dunkel,Vector3(-0.5,0,zf-0.25),Vector3(-0.45,2.6,zf));b.box(dunkel,Vector3(1.05,0,zf-0.25),Vector3(1.1,2.6,zf));b.box(dunkel,Vector3(-0.5,2.6,zf-0.25),Vector3(1.1,2.7,zf))
	# Leuchtschild
	b.box(Mats.flat(Color(0.06,0.06,0.07),0.4),Vector3(x0+0.4,3.45,zf),Vector3(x1-0.4,4.3,zf+0.25))
	b.box(Mats.emissive(Color(0.95,0.15,0.1),2.5),Vector3(x0+0.6,3.5,zf+0.25),Vector3(x0+1.3,4.25,zf+0.27))
	# Obergeschosse
	b.box(ziegel,Vector3(x0,H,zb),Vector3(x1,H2,zf))
	b.box(Mats.flat(Color(0.3,0.28,0.27),0.7),Vector3(x0-0.15,H2,zb-0.15),Vector3(x1+0.15,H2+0.45,zf+0.15))
	for fy in [H+1.0,H+4.0]:
		var fx=x0+1.4
		while fx<x1-1.2:
			b.box(Mats.flat(Color(0.85,0.83,0.78),0.6),Vector3(fx-0.1,fy-0.1,zf),Vector3(fx+1.3,fy+1.9,zf+0.06))
			b.box(Mats.flat(Color(0.12,0.16,0.2),0.15,0.3),Vector3(fx,fy,zf+0.05),Vector3(fx+1.2,fy+1.8,zf+0.08))
			b.box(Mats.flat(Color(0.85,0.83,0.78),0.6),Vector3(fx+0.57,fy,zf+0.07),Vector3(fx+0.63,fy+1.8,zf+0.1))
			fx+=2.6
	# Feuertreppe an der Front
	for fy in [H+0.9,H+3.9]:
		b.box(metall,Vector3(x1-4.2,fy-0.1,zf),Vector3(x1-0.8,fy,zf+1.1))
		b.box(metall,Vector3(x1-4.2,fy,zf+1.05),Vector3(x1-0.8,fy+0.9,zf+1.1))
	# Innenraum
	b.box(fliesen,Vector3(x0+wand,0.0,zb+wand),Vector3(x1-wand,0.02,zf-wand))
	b.box(putz,Vector3(x0+wand,0.02,zb+wand),Vector3(x0+wand+0.05,3.3,zf-wand))
	b.box(putz,Vector3(x1-wand-0.05,0.02,zb+wand),Vector3(x1-wand,3.3,zf-wand))
	b.box(Mats.flat(Color(0.55,0.5,0.44),0.8),Vector3(x0+wand,0.02,zb+wand),Vector3(x1-wand,3.3,zb+wand+0.05))
	b.box(decke,Vector3(x0+wand,3.3,zb+wand),Vector3(x1-wand,3.35,zf-wand))
	for lz in [-4.0,-1.0,2.0]:b.box(licht,Vector3(-3.5,3.25,lz-0.15),Vector3(3.5,3.3,lz+0.15))
	# Theke mit Vitrine (L-Form)
	b.box(holz,Vector3(-4.5,0,-2.0),Vector3(3.0,0.95,-1.2))
	b.box(glas,Vector3(-4.4,0.95,-1.95),Vector3(2.9,1.25,-1.25))
	b.box(Mats.flat(Color(0.75,0.1,0.08),0.6),Vector3(-4.45,0.92,-1.95),Vector3(2.95,0.95,-1.25))
	b.box(holz,Vector3(3.0,0,-2.0),Vector3(3.8,0.95,1.5))
	# Kasse
	b.box(dunkel,Vector3(2.9,0.95,-1.0),Vector3(3.5,1.25,-0.4))
	# Wandregale hinten (Gewehre) und links (Pistolen-Lochwand)
	b.box(holz,Vector3(-5.5,0.4,zb+wand+0.05),Vector3(5.5,3.0,zb+wand+0.25))
	for ry in [1.0,1.8,2.6]:b.box(metall,Vector3(-5.4,ry,zb+wand+0.25),Vector3(5.4,ry+0.04,zb+wand+0.5))
	b.box(Mats.flat(Color(0.7,0.68,0.62),0.8),Vector3(x0+wand+0.05,0.8,-3.5),Vector3(x0+wand+0.1,2.8,2.5))
	# Munitionskisten
	var oliv=Mats.flat(Color(0.3,0.33,0.2),0.7)
	for k in 6:b.box(oliv,Vector3(x1-wand-1.2,k*0.35,-5.0+k*0.05),Vector3(x1-wand-0.2,k*0.35+0.3,-4.2+k*0.05))
	# Zielscheibe-Poster
	b.box(Mats.flat(Color(0.95,0.95,0.9),0.8),Vector3(x1-wand-0.1,1.6,0.5),Vector3(x1-wand-0.05,2.6,1.3))
	b.box(Mats.flat(Color(0.9,0.1,0.08),0.8),Vector3(x1-wand-0.12,1.95,0.75),Vector3(x1-wand-0.09,2.25,1.05))
	b.commit(root)
	# Licht innen
	for lz in [-4.0,1.0]:
		var l=OmniLight3D.new();l.position=Vector3(0,3.0,lz);l.omni_range=7.0;l.light_energy=1.6;l.light_color=Color(1,0.96,0.88);root.add_child(l)
	# Schriftzug
	var lb=Label3D.new();lb.text="WAFFEN KRAUSE";lb.font_size=96;lb.pixel_size=0.009;lb.modulate=Color(1,0.95,0.85);lb.outline_size=8;lb.outline_modulate=Color(0.4,0.05,0.02)
	lb.position=Vector3(0.6,3.88,zf+0.28);root.add_child(lb)
	var lb2=Label3D.new();lb2.text="JAGD · SPORT · SELBSTSCHUTZ";lb2.font_size=48;lb2.pixel_size=0.006;lb2.modulate=Color(0.95,0.95,0.95)
	lb2.position=Vector3(0,0.35,zf+0.08);root.add_child(lb2)
	# Waffen ausstellen: Gewehre waagerecht an der Rückwand, Pistolen liegend in der Vitrine und an der Lochwand
	var gewehre=[W+"gewehr47/gewehr47.gltf",W+"ar15b/ar15b.gltf",W+"aug/aug.gltf",W+"mp5b/mp5b.gltf",W+"rifle.glb"]
	var k=0
	for reihe in 3:
		for spalte in 4:
			_ausstellen(root,gewehre[k%gewehre.size()],Vector3(-4.0+spalte*2.7,1.3+reihe*0.8,zb+wand+0.42),[Vector3.RIGHT,Vector3.UP,Vector3.BACK],1.15);k+=1
	var pistolen=[W+"pistol.glb",W+"m1911/m1911.gltf",W+"pistol_tac/pistol_tac.gltf"]
	for i in 9:
		_ausstellen(root,pistolen[i%3],Vector3(-4.0+i*0.8,1.03,-1.6),[Vector3.RIGHT,Vector3.BACK,Vector3.UP],0.24)
	for i in 8:
		_ausstellen(root,pistolen[(i+1)%3],Vector3(x0+wand+0.16,1.2+(i/4)*0.7,-2.6+(i%4)*1.4),[Vector3.BACK,Vector3.UP,Vector3.RIGHT],0.34)
	# Licht über der Vitrine
	var vl=SpotLight3D.new();vl.position=Vector3(-0.7,3.2,-1.6);vl.rotation_degrees=Vector3(-90,0,0);vl.spot_range=4.0;vl.light_energy=2.0;root.add_child(vl)
	# Verkäufer hinter der Theke
	var PE=load("res://scripts/people.gd");var r=RandomNumberGenerator.new();r.seed=42
	var v=PE.make("biker",r);root.add_child(v);v.position=Vector3(-0.8,0.02,-3.0);v.rotation.y=0.0
	PE.play(v,"idle",0.3)
	v.name="Verkaeufer"
	return root

# Modell so drehen, dass seine längste Achse auf ziel[0], die mittlere auf ziel[1], die kürzeste auf ziel[2] zeigt
func _ausstellen(root:Node3D,pfad:String,p:Vector3,ziel:Array,laenge:float):
	if not ResourceLoader.exists(pfad):return
	var n:Node3D=load(pfad).instantiate()
	var F=load("res://scripts/fit.gd")
	var h=Node3D.new();root.add_child(h);h.add_child(n)
	var ab=F.aabb(h);var s=[ab.size.x,ab.size.y,ab.size.z]
	var idx=[0,1,2];idx.sort_custom(func(a,b):return s[a]>s[b])
	var cols=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	for k in 3:cols[idx[k]]=ziel[k]
	var bs=Basis(cols[0],cols[1],cols[2])
	if bs.determinant()<0:cols[idx[2]]=-cols[idx[2]];bs=Basis(cols[0],cols[1],cols[2])
	var sk=laenge/max(s[idx[0]],0.001)
	n.transform=Transform3D(bs.scaled(Vector3.ONE*sk),Vector3.ZERO)*Transform3D(Basis(),-ab.get_center())
	h.position=p
