extends RefCounted
# Natur für alles außerhalb der Städte: Bausätze (Bäume, Büsche, Gräser, Blumen, Farn, Felsen, Totholz, Schilf,
# Jagdhütte, Cannabisfeld) und ein Landschaftsmuster (Wald / Waldrand / Wiese / Felshang / Ufer / Wüste)
# aus Höhe, Steigung, Küstenabstand und Rauschen. Platzierungen sind [Bausatz, Transform3D (Welt, y absolut)].
var L;var K;var G0
var rng:=RandomNumberGenerator.new()
var nwald:=FastNoiseLite.new();var ndetail:=FastNoiseLite.new();var nfarbe:=FastNoiseLite.new()
const KB:=0.15

func _init(lib,kitlib,gelaende):
	L=lib;K=kitlib;G0=gelaende;rng.seed=4711
	nwald.seed=11;nwald.frequency=1.0/420.0;nwald.fractal_octaves=3
	ndetail.seed=23;ndetail.frequency=1.0/70.0
	nfarbe.seed=5;nfarbe.frequency=1.0/35.0

var _mc:={}
func T(c:Color)->Material:
	var k=str(c)
	if not _mc.has(k):
		var m=StandardMaterial3D.new();m.albedo_color=c;m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.specular_mode=BaseMaterial3D.SPECULAR_TOON;m.roughness=0.9;_mc[k]=m
	return _mc[k]

# ================= Bausätze =================
func kits_bauen():
	var alt=[L.leicht,L.hoehen_an];L.leicht=false;L.hoehen_an=false
	var SPH0=L.SPH;var s=SphereMesh.new();s.radial_segments=10;s.rings=5;L.SPH=s
	var laub=[Color(0.3,0.56,0.22),Color(0.38,0.64,0.24),Color(0.24,0.48,0.2),Color(0.78,0.5,0.16)]
	for i in 4:K.kit("nt_eiche_%d"%i,7.0,7.0,func():_eiche(i,laub[i]))
	for i in 2:K.kit("nt_birke_%d"%i,4.0,4.0,func():_birke(i))
	for i in 3:K.kit("nt_tanne_%d"%i,5.0,5.0,func():_tanne(i))
	K.kit("nt_kiefer",5.0,5.0,func():_kiefer())
	for i in 5:K.kit("nt_busch_%d"%i,3.0,3.0,func():_busch(i))
	for i in 3:K.kit("nt_gras_%d"%i,2.0,2.0,func():_gras(i,false))
	for i in 2:K.kit("nt_hohgras_%d"%i,2.0,2.0,func():_gras(i,true))
	for i in 3:K.kit("nt_blumen_%d"%i,2.0,2.0,func():_blumen(i))
	K.kit("nt_farn",2.0,2.0,func():_farn())
	for i in 3:K.kit("nt_fels_%d"%i,6.0,6.0,func():_fels(i))
	for i in 2:K.kit("nt_kiesel_%d"%i,2.0,2.0,func():_kiesel(i))
	K.kit("nt_totholz",7.0,3.0,func():_totholz())
	K.kit("nt_schilf",3.0,3.0,func():_schilf())
	K.kit("nt_jagdhuette",12.0,12.0,func():_jagdhuette())
	K.kit("nt_hanf_reihe",24.0,2.0,func():_hanf_reihe())
	K.kit("nt_gewaechshaus",10.0,24.0,func():_gewaechshaus())
	K.kit("nt_wachhuette",10.0,8.0,func():_wachhuette())
	K.kit("nt_zaun",10.0,1.0,func():_zaun())
	K.kit("nt_hochsitz",4.0,4.0,func():_hochsitz())
	K.kit("nt_strandvilla",30.0,26.0,func():_strandvilla())
	K.kit("nt_steg",4.0,34.0,func():_steg())
	# Fernbäume (ohne Kontur, wenige Dreiecke)
	K.kit("nt_fern_laub",6.0,6.0,func():_fern(false))
	K.kit("nt_fern_nadel",5.0,5.0,func():_fern(true))
	L.SPH=SPH0;L.leicht=alt[0];L.hoehen_an=alt[1]

func _eiche(i:int,c:Color):
	var h=[6.5,8.0,5.5,6.8][i];var p=Vector3(0,KB,0);var rinde=T(Color(0.38,0.26,0.17))
	L.zyl(rinde,p,p+Vector3(0.1,h*0.55,0),0.28,1.2)
	L.zyl(rinde,p+Vector3(0,h*0.4,0),p+Vector3(1.2,h*0.72,0.3),0.12,1.25)
	L.zyl(rinde,p+Vector3(0,h*0.45,0),p+Vector3(-1.0,h*0.75,-0.5),0.12,1.25)
	var c2=c.lightened(0.12);var c3=c.darkened(0.15)
	var m=p+Vector3(0,h*0.78,0);var r=h*0.36
	L.kugel(T(c),m,Vector3(r,r*0.8,r),1.05)
	for k in 5:
		var a=TAU*k/5.0+i
		L.kugel(T([c2,c3,c][k%3]),m+Vector3(cos(a)*r*0.75,rng.randf_range(-0.2,0.35)*r,sin(a)*r*0.75),Vector3(r,r*0.8,r)*0.62,1.05)
	L.kugel(T(c2),m+Vector3(0,r*0.6,0),Vector3(r,r*0.7,r)*0.65,1.05)
	L.PFOSTEN.append([p,0.35,3.0])
func _birke(i:int):
	var h=7.5+i*1.5;var p=Vector3(0,KB,0)
	var weiss=T(Color(0.92,0.9,0.86));var schwarz=T(Color(0.15,0.14,0.14))
	L.zyl(weiss,p,p+Vector3(0.15,h*0.75,0),0.16,1.2)
	for k in 5:L.box(schwarz,p+Vector3(0.0,0.6+k*h*0.13,0.16),Vector3(0.18,0.06,0.04),Basis(),0.0)
	var g=T(Color(0.55,0.75,0.3));var g2=T(Color(0.45,0.68,0.26))
	var m=p+Vector3(0.15,h*0.78,0)
	L.kugel(g,m,Vector3(1.6,2.3,1.6),1.05);L.kugel(g2,m+Vector3(0.7,-0.5,0.4),Vector3(1.1,1.4,1.1),1.05);L.kugel(g2,m+Vector3(-0.6,-0.8,-0.3),Vector3(1.0,1.3,1.0),1.05)
	L.PFOSTEN.append([p,0.2,3.0])
func _tanne(i:int):
	var h=[9.0,12.0,7.0][i];var p=Vector3(0,KB,0)
	var g=T([Color(0.14,0.36,0.22),Color(0.18,0.4,0.24),Color(0.12,0.32,0.2)][i]);var g2=T(Color(0.2,0.44,0.27))
	L.zyl(T(Color(0.35,0.24,0.15)),p,p+Vector3(0,h*0.3,0),0.22,1.2)
	for k in 4:
		var y=h*(0.16+k*0.19);var r=h*(0.3-k*0.06)
		var cm=CylinderMesh.new();cm.top_radius=0.02;cm.bottom_radius=r;cm.height=h*0.36;cm.radial_segments=9;cm.rings=1
		L.mesh(g if k%2==0 else g2,cm,Transform3D(Basis(Vector3.UP,k*0.6),p+Vector3(0,y+h*0.18,0)),1.06)
	L.PFOSTEN.append([p,0.3,3.0])
func _kiefer():
	var h=13.0;var p=Vector3(0,KB,0);var rinde=T(Color(0.55,0.33,0.2))
	L.zyl(rinde,p,p+Vector3(0.3,h*0.8,0.1),0.24,1.2)
	var g=T(Color(0.2,0.42,0.24));var m=p+Vector3(0.3,h*0.85,0.1)
	L.kugel(g,m,Vector3(2.4,1.2,2.4),1.06);L.kugel(g,m+Vector3(1.4,-0.8,0.5),Vector3(1.6,0.9,1.6),1.06);L.kugel(g,m+Vector3(-1.2,-0.5,-0.6),Vector3(1.5,0.8,1.5),1.06)
	L.PFOSTEN.append([p,0.3,3.0])
func _busch(i:int):
	var c=[Color(0.3,0.55,0.22),Color(0.36,0.6,0.25),Color(0.26,0.48,0.2),Color(0.4,0.58,0.22),Color(0.32,0.52,0.28)][i]
	var n=3+i%3
	for k in n:
		var a=TAU*k/n+i;var r=0.5+0.2*(k%2)
		L.kugel(T(c.lightened(0.08*(k%2))),Vector3(cos(a)*r,KB+0.45+0.1*k,sin(a)*r),Vector3(0.75,0.6,0.75)*rng.randf_range(0.8,1.15),1.06)
	if i==3:
		for k in 5:L.kugel(T(Color(0.85,0.1,0.15)),Vector3(rng.randf_range(-0.7,0.7),KB+0.7+rng.randf()*0.4,rng.randf_range(-0.7,0.7)),Vector3(0.07,0.07,0.07),1.0)
	if i==4:
		for k in 6:L.kugel(T(Color(0.98,0.95,0.9)),Vector3(rng.randf_range(-0.7,0.7),KB+0.8+rng.randf()*0.4,rng.randf_range(-0.7,0.7)),Vector3(0.09,0.09,0.09),1.0)
func _gras(i:int,hoch:bool):
	# dünne, spitz zulaufende Halme (Kreuz aus 2 Dreiecken, beidseitig), zwei Farbtöne nah am Boden
	var c=[Color(0.27,0.46,0.18),Color(0.32,0.5,0.2),Color(0.42,0.48,0.22)][i] if not hoch else [Color(0.56,0.52,0.3),Color(0.36,0.5,0.22)][i]
	var n=26 if hoch else 18
	var sts=[SurfaceTool.new(),SurfaceTool.new()]
	for t in sts:t.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n:
		var a=rng.randf()*TAU;var r=sqrt(rng.randf())*(0.7 if hoch else 0.55)
		var h=(0.75 if hoch else 0.32)+rng.randf()*(0.55 if hoch else 0.3)
		var p=Vector3(cos(a)*r,KB-0.05,sin(a)*r);var w=0.045 if hoch else 0.04
		var neig=Vector3(rng.randf_range(-0.25,0.25),0,rng.randf_range(-0.25,0.25))*h
		var t:SurfaceTool=sts[k%2]
		for q in 2:
			var d=Vector3(cos(a+q*1.57),0,sin(a+q*1.57))*w
			for v in [p-d,p+d,p+Vector3(0,h,0)+neig,p+d,p-d,p+Vector3(0,h,0)+neig]:t.set_normal(Vector3.UP);t.add_vertex(v)
	L.mesh(T(c),sts[0].commit(),Transform3D(),0.0);L.mesh(T(c.lightened(0.12)),sts[1].commit(),Transform3D(),0.0)
func _blumen(i:int):
	_gras(0,false)
	var bc=[Color(0.98,0.85,0.2),Color(0.9,0.3,0.45),Color(0.6,0.45,0.95)][i]
	for k in 7:
		var p=Vector3(rng.randf_range(-0.6,0.6),KB+0.45+rng.randf()*0.2,rng.randf_range(-0.6,0.6))
		L.box(T(Color(0.35,0.6,0.25)),p-Vector3(0,0.2,0),Vector3(0.03,0.4,0.03),Basis(),0.0)
		L.kugel(T(bc if k%3!=0 else Color(0.98,0.97,0.95)),p,Vector3(0.09,0.06,0.09),1.0)
func _farn():
	var g=T(Color(0.3,0.58,0.25))
	for k in 7:
		var a=TAU*k/7.0
		L.box(g,Vector3(cos(a)*0.45,KB+0.35,sin(a)*0.45),Vector3(0.22,0.03,0.95),Basis(Vector3.UP,-a+PI*0.5)*Basis(Vector3.RIGHT,-0.55),0.0)
func _fels(i:int):
	var f=[Color(0.56,0.55,0.53),Color(0.5,0.48,0.45),Color(0.62,0.6,0.56)][i];var moos=T(Color(0.35,0.52,0.25))
	var r=[1.4,2.4,1.0][i]
	var sm=SphereMesh.new();sm.radial_segments=6;sm.rings=3;sm.radius=1.0;sm.height=2.0
	L.mesh(T(f),sm,Transform3D(Basis(Vector3.UP,0.4).scaled(Vector3(r*1.3,r,r*1.1)),Vector3(0,KB+r*0.4,0)),1.05)
	L.mesh(T(f.darkened(0.1)),sm,Transform3D(Basis(Vector3.UP,1.3).scaled(Vector3(r*0.8,r*0.75,r*0.8)),Vector3(r*0.9,KB+r*0.25,r*0.3)),1.05)
	if i!=2:L.mesh(T(f.lightened(0.06)),sm,Transform3D(Basis(Vector3.UP,2.1).scaled(Vector3(r*0.7,r*0.6,r*0.7)),Vector3(-r*0.75,KB+r*0.2,-r*0.4)),1.05)
	L.mesh(moos,sm,Transform3D(Basis(Vector3.UP,0.4).scaled(Vector3(r*0.85,r*0.22,r*0.75)),Vector3(0.1*r,KB+r*1.28,0)),1.0)
	L.koll_box(Vector3(0,KB+r*0.45,0),Vector3(r*2.2,r*0.9,r*1.8))
func _kiesel(i:int):
	var sm=SphereMesh.new();sm.radial_segments=5;sm.rings=3;sm.radius=1.0;sm.height=2.0
	for k in 3+i:L.mesh(T(Color(0.58,0.56,0.53).darkened(0.08*k)),sm,Transform3D(Basis(Vector3.UP,k*1.1).scaled(Vector3(0.32,0.2,0.26)*rng.randf_range(0.8,1.6)),Vector3(rng.randf_range(-0.7,0.7),KB+0.05,rng.randf_range(-0.7,0.7))),1.05)
func _totholz():
	var r=T(Color(0.42,0.3,0.2));var innen=T(Color(0.7,0.55,0.35))
	L.zyl(r,Vector3(-2.8,KB+0.35,0),Vector3(2.6,KB+0.3,0.4),0.33,1.15)
	L.zyl(innen,Vector3(2.6,KB+0.3,0.4),Vector3(2.62,KB+0.3,0.4),0.3,1.0)
	L.zyl(r,Vector3(-2.8,KB,1.6),Vector3(-2.8,KB+0.7,1.6),0.35,1.15)
	for k in 4:L.kugel(T(Color(0.85,0.15,0.1)),Vector3(-1.5+k*0.9,KB+0.08,-0.5),Vector3(0.12,0.08,0.12),1.0)
	L.koll_box(Vector3(0,KB+0.35,0.2),Vector3(5.4,0.6,0.6))
func _schilf():
	for k in 14:
		var p=Vector3(rng.randf_range(-1.0,1.0),KB,rng.randf_range(-1.0,1.0));var h=1.4+rng.randf()*0.8
		L.box(T(Color(0.5,0.62,0.3)),p+Vector3(0,h*0.5,0),Vector3(0.04,h,0.04),Basis(Vector3.RIGHT,rng.randf_range(-0.15,0.15)),0.0)
		if k%2==0:L.box(T(Color(0.45,0.3,0.18)),p+Vector3(0,h+0.12,0),Vector3(0.09,0.3,0.09),Basis(),0.0)
func _jagdhuette():
	var holz=T(Color(0.5,0.33,0.2));var holz2=T(Color(0.42,0.28,0.17));var dach=T(Color(0.25,0.22,0.2));var p=Vector3(0,KB,-5.5)
	# Wände aus liegenden Stämmen
	for k in 9:
		var y=0.15+k*0.3
		for e in [[Vector3(-3,y,-2.5),Vector3(3,y,-2.5)],[Vector3(-3,y,2.5),Vector3(3,y,2.5)],[Vector3(-3,y,-2.5),Vector3(-3,y,2.5)],[Vector3(3,y,-2.5),Vector3(3,y,2.5)]]:
			L.zyl(holz if k%2==0 else holz2,p+e[0]*Vector3(1.05,1,1.05),p+e[1]*Vector3(1.05,1,1.05),0.16,1.08)
	L.koll_box(p+Vector3(0,1.4,0),Vector3(6.2,2.8,5.2))
	# Satteldach
	for sd in [-1,1]:
		L.box(dach,p+Vector3(0,3.35,sd*1.4),Vector3(7.0,0.15,3.2),Basis(Vector3.RIGHT,sd*0.55),0.04)
	L.box(holz2,p+Vector3(-3.05,3.3,0),Vector3(0.1,1.0,4.6),Basis(),0.03);L.box(holz2,p+Vector3(3.05,3.3,0),Vector3(0.1,1.0,4.6),Basis(),0.03)
	# Tür, Fenster, Veranda, Schornstein, Geweih
	L.box(T(Color(0.3,0.2,0.12)),p+Vector3(0.6,1.05,2.62),Vector3(1.0,1.9,0.08),Basis(),0.03)
	L.box(T(Color(0.95,0.8,0.4)),p+Vector3(-1.6,1.6,2.62),Vector3(0.9,0.7,0.06),Basis(),0.03)
	L.box(holz2,p+Vector3(0,0.12,3.6),Vector3(6.4,0.2,2.0),Basis(),0.03)
	for sx in [-3.0,3.0]:L.zyl(holz,p+Vector3(sx,0.2,4.5),p+Vector3(sx,2.5,4.5),0.1,1.15)
	L.box(dach,p+Vector3(0,2.6,3.7),Vector3(6.6,0.12,2.2),Basis(Vector3.RIGHT,-0.2),0.03)
	L.box(T(Color(0.5,0.48,0.46)),p+Vector3(2.2,3.6,-0.8),Vector3(0.6,2.2,0.6),Basis(),0.04)
	for sd in [-1,1]:L.zyl(T(Color(0.92,0.88,0.78)),p+Vector3(0.6,2.3,2.7),p+Vector3(0.6+sd*0.5,2.75,2.75),0.04,1.1)
	# Holzstapel + Hackklotz
	for k in 3:L.zyl(holz2,p+Vector3(-4.2,0.2+k*0.3,-1.5),p+Vector3(-4.2,0.2+k*0.3,1.5),0.14,1.1)
	L.zyl(holz,p+Vector3(4.2,0,3.5),p+Vector3(4.2,0.6,3.5),0.3,1.12)
func _hanfpflanze(c:Vector3,h:float):
	# Hanfpflanze (handytauglich): Stängel, 5 Etagen aus je 3 gefingerten Blattsternen (je 5 Finger, flache Quader)
	var stiel=T(Color(0.3,0.46,0.2));var blatt=[T(Color(0.16,0.42,0.16)),T(Color(0.22,0.5,0.2)),T(Color(0.27,0.56,0.22))]
	L.box(stiel,c+Vector3(0,h*0.5,0),Vector3(0.04,h,0.04),Basis(),0.0)
	var E=5
	for e in E:
		var t=float(e)/(E-1);var y=h*(0.2+t*0.72);var s=lerp(1.2,0.45,t)
		for f in 3:
			var bb0=Basis(Vector3.UP,e*0.9+f*TAU/3.0)
			var ansatz=c+Vector3(0,y,0)+bb0*Vector3(0,0,0.1*s)
			for k in 5:
				var a=(k-2)*0.42;var lg=(0.5-abs(k-2)*0.1)*s
				var bb=bb0*Basis(Vector3.UP,a)*Basis(Vector3.RIGHT,-0.35+abs(k-2)*0.08)
				L.box(blatt[(k+e+f)%3],ansatz+bb*Vector3(0,0,lg*0.5),Vector3(0.08*s,0.012,lg),bb,0.0)
	var cm=CylinderMesh.new();cm.top_radius=0.02;cm.bottom_radius=0.11;cm.height=0.38;cm.radial_segments=5;cm.rings=1
	L.mesh(T(Color(0.3,0.5,0.22)),cm,Transform3D(Basis(),c+Vector3(0,h+0.12,0)),1.0)
func _hanf_reihe():
	var erde=T(Color(0.36,0.25,0.16))
	L.box(erde,Vector3(0,KB+0.05,0),Vector3(23.5,0.15,1.3),Basis(),0.0)
	for k in 14:_hanfpflanze(Vector3(-11.05+k*1.7,KB+0.1,0),1.5+0.35*sin(k*1.7))
	L.zyl(T(Color(0.1,0.1,0.1)),Vector3(-11.8,KB+0.14,0.4),Vector3(11.8,KB+0.14,0.4),0.025,1.0)
func _gewaechshaus():
	var rahmen=T(Color(0.85,0.87,0.88));var glas=T(Color(0.7,0.85,0.88));var p=Vector3(0,KB,-12.0)
	L.box(T(Color(0.4,0.38,0.35)),p+Vector3(0,0.05,0),Vector3(9.6,0.1,23.6),Basis(),0.02)
	for z in range(-11,12,2):
		for sd in [-1,1]:L.box(rahmen,p+Vector3(sd*4.7,1.2,z),Vector3(0.08,2.4,0.08),Basis(),0.0)
		L.box(rahmen,p+Vector3(0,3.1,z),Vector3(9.6,0.06,0.06),Basis(),0.0)
	for sd in [-1,1]:
		L.box(glas,p+Vector3(sd*4.75,1.2,0),Vector3(0.03,2.4,23.4),Basis(),0.0)
		L.box(glas,p+Vector3(sd*2.4,3.0,0),Vector3(5.1,0.03,23.4),Basis(Vector3.BACK,sd*0.28),0.03)
	L.box(glas,p+Vector3(0,1.6,-11.75),Vector3(9.4,3.2,0.03),Basis(),0.03)
	L.box(glas,p+Vector3(-2.8,1.6,11.75),Vector3(3.8,3.2,0.03),Basis(),0.03);L.box(glas,p+Vector3(2.8,1.6,11.75),Vector3(3.8,3.2,0.03),Basis(),0.03)
	L.koll_box(p+Vector3(-4.75,1.2,0),Vector3(0.2,2.4,23.4));L.koll_box(p+Vector3(4.75,1.2,0),Vector3(0.2,2.4,23.4));L.koll_box(p+Vector3(0,1.6,-11.75),Vector3(9.4,3.2,0.2))
	for sd in [-1,1]:
		for k in 7:_hanfpflanze(p+Vector3(sd*2.4,0.1,-9.0+k*3.0),1.4+0.2*sin(k*2.0+sd))
	for k in 3:L.box(T(Color(1,0.95,0.7)),p+Vector3(0,2.8,-8+k*8),Vector3(0.3,0.08,1.6),Basis(),0.0)
func _wachhuette():
	var blech=T(Color(0.55,0.58,0.6));var holz=T(Color(0.48,0.35,0.24));var p=Vector3(0,KB,-4.0)
	L.box(blech,p+Vector3(0,1.3,0),Vector3(4.0,2.6,3.2),Basis(),0.04);L.koll_box(p+Vector3(0,1.3,0),Vector3(4.0,2.6,3.2))
	L.box(T(Color(0.35,0.36,0.38)),p+Vector3(0,2.7,0.2),Vector3(4.4,0.12,3.8),Basis(Vector3.RIGHT,0.08),0.03)
	L.box(holz,p+Vector3(-0.8,1.0,1.62),Vector3(0.9,1.9,0.06),Basis(),0.02)
	L.box(T(Color(0.2,0.3,0.4)),p+Vector3(1.0,1.6,1.62),Vector3(1.0,0.6,0.05),Basis(),0.02)
	# Generator, Wassertank, Fässer, Stuhl, Warnschild
	L.box(T(Color(0.85,0.6,0.1)),p+Vector3(3.0,0.45,1.2),Vector3(1.2,0.9,0.8),Basis(),0.03)
	L.zyl(T(Color(0.2,0.35,0.6)),p+Vector3(-3.4,0,-0.5),p+Vector3(-3.4,2.2,-0.5),0.9,1.06)
	for k in 3:L.zyl(T([Color(0.15,0.4,0.2),Color(0.6,0.15,0.1),Color(0.15,0.25,0.5)][k]),p+Vector3(2.6+k*0.7,0,-1.3),p+Vector3(2.6+k*0.7,0.9,-1.3),0.3,1.08)
	L.box(holz,p+Vector3(1.4,0.45,2.6),Vector3(0.5,0.08,0.5),Basis(),0.02)
	L.zyl(holz,p+Vector3(-1.5,0,3.6),p+Vector3(-1.5,1.6,3.6),0.05,1.1)
	L.box(T(Color(0.95,0.85,0.15)),p+Vector3(-1.5,1.6,3.62),Vector3(1.2,0.6,0.04),Basis(),0.02)
	L._schrift("BETRETEN\nVERBOTEN",p+Vector3(-1.5,1.6,3.66),Basis(),0.0035,Color(0.1,0.08,0.05))
func _fern(nadel:bool):
	if nadel:
		var cm=CylinderMesh.new();cm.top_radius=0.0;cm.bottom_radius=2.8;cm.height=9.5;cm.radial_segments=6;cm.rings=1
		L.mesh(T(Color(0.16,0.37,0.22)),cm,Transform3D(Basis(),Vector3(0,KB+5.5,0)),1.0)
	else:
		var sm=SphereMesh.new();sm.radius=2.8;sm.height=4.6;sm.radial_segments=6;sm.rings=3
		L.mesh(T(Color(0.3,0.55,0.23)),sm,Transform3D(Basis(),Vector3(0,KB+5.2,0)),1.0)
		L.box(T(Color(0.38,0.26,0.17)),Vector3(0,KB+1.6,0),Vector3(0.45,3.2,0.45),Basis(),0.0)

# ================= Landschaftsmuster =================
# Biom an einem Weltpunkt: "wald", "rand", "wiese", "fels", "ufer", "strand", "wueste"
func biom(x:float,z:float,h:float,steig:float,kueste:float,trocken:float)->String:
	if h<3.0 and kueste<60.0:return "strand"
	if h<4.0:return "ufer"
	if trocken>0.55 and h<400.0:return "wueste"
	if steig>0.5 or h>520.0:return "fels"
	var f=nwald.get_noise_2d(x,z)+(0.15 if h>80.0 else 0.0)-(0.25 if kueste<150.0 else 0.0)
	if f>0.02:return "wald"
	if f>-0.14:return "rand"
	return "wiese"
func farbe(x:float,z:float,h:float,steig:float,kueste:float,trocken:float)->Color:
	var b=biom(x,z,h,steig,kueste,trocken);var n=nfarbe.get_noise_2d(x,z)*0.5+0.5;var d=ndetail.get_noise_2d(x,z)*0.5+0.5
	var c:Color
	match b:
		"ufer":c=Color(0.36,0.46,0.24).lerp(Color(0.5,0.48,0.34),n)
		"strand":c=Color(0.93,0.84,0.6).lerp(Color(0.86,0.76,0.52),n)
		"wueste":c=Color(0.85,0.7,0.45).lerp(Color(0.78,0.6,0.38),n)
		"fels":c=Color(0.46,0.45,0.4).lerp(Color(0.36,0.42,0.26),smoothstep(0.35,0.75,d))
		"wald":c=Color(0.2,0.32,0.14).lerp(Color(0.28,0.3,0.16),n)
		"rand":c=Color(0.26,0.42,0.18).lerp(Color(0.32,0.4,0.18),n)
		_:c=Color(0.31,0.48,0.2).lerp(Color(0.4,0.52,0.22),n).lerp(Color(0.5,0.49,0.25),smoothstep(0.65,0.95,d)*0.7).lerp(Color(0.24,0.4,0.17),smoothstep(0.2,0.0,d)*0.5)
	if h>620.0:c=c.lerp(Color(0.95,0.96,0.98),smoothstep(620,700,h))
	if steig>0.3 and b!="fels":c=c.lerp(Color(0.46,0.45,0.4),smoothstep(0.3,0.42,steig)*0.5)
	return c

# Bausatz für einen Punkt (leer = nichts). nah = nahe an Straße/Weg (Bodendecker nur dort, spart Speicher)
func waehle(px:float,pz:float,h:float,steig:float,kueste:float,trocken:float,nah:bool,stadt:=false)->String:
	var b=biom(px,pz,h,steig,kueste,trocken);var r=rng.randf();var kit=""
	var d=ndetail.get_noise_2d(px,pz)
	if stadt and b=="wald":b="rand"
	match b:
		"wald":
			var nadel=h>110.0 or nwald.get_noise_2d(px+900,pz)>0.1
			if r<0.62:kit=("nt_tanne_%d"%rng.randi_range(0,2) if rng.randf()<0.8 else "nt_kiefer") if nadel else ("nt_eiche_%d"%rng.randi_range(0,2) if rng.randf()<0.8 else "nt_birke_%d"%rng.randi_range(0,1))
			elif r<0.72:kit="nt_farn" if nah else ""
			elif r<0.8:kit="nt_busch_%d"%rng.randi_range(0,4)
			elif r<0.82:kit="nt_totholz"
			elif r<0.84:kit="nt_fels_2"
		"rand":
			if r<0.3:kit="nt_eiche_%d"%rng.randi_range(0,3) if rng.randf()<0.7 else ("nt_birke_%d"%rng.randi_range(0,1) if rng.randf()<0.6 else "nt_tanne_%d"%rng.randi_range(0,2))
			elif r<0.48:kit="nt_busch_%d"%rng.randi_range(0,4)
			elif r<0.62:kit="nt_gras_%d"%rng.randi_range(0,2) if nah else ""
			elif r<0.7:kit="nt_hohgras_%d"%rng.randi_range(0,1) if nah else ""
		"wiese":
			if r<0.45:kit=("nt_gras_%d"%rng.randi_range(0,2) if rng.randf()<0.75 else "nt_hohgras_%d"%rng.randi_range(0,1)) if nah else ("nt_busch_%d"%rng.randi_range(0,4) if rng.randf()<0.12 else "")
			elif r<0.55 and d>0.1:kit="nt_blumen_%d"%rng.randi_range(0,2) if nah else ""
			elif r<0.62:kit="nt_hohgras_%d"%rng.randi_range(0,1) if nah else ""
			elif r<0.69:kit="nt_busch_%d"%rng.randi_range(0,4)
			elif r<0.72:kit="nt_eiche_%d"%rng.randi_range(0,3) if d<0.25 else "nt_birke_%d"%rng.randi_range(0,1)
			elif r<0.73:kit="nt_kiesel_%d"%rng.randi_range(0,1)
			elif r<0.735:kit="nt_fels_%d"%rng.randi_range(0,2)
		"fels":
			if r<0.08:kit="nt_fels_%d"%rng.randi_range(0,2)
			elif r<0.2:kit="nt_kiesel_%d"%rng.randi_range(0,1)
			elif r<0.28:kit="nt_tanne_2"
			elif r<0.5:kit="nt_busch_%d"%rng.randi_range(0,2)
			elif r<0.62:kit="nt_gras_2" if nah else ""
		"strand":
			if r<0.06:kit="nt_hohgras_0" if nah else ""
			elif r<0.07:kit="nt_kiesel_0"
		"ufer":
			if r<0.35:kit="nt_schilf"
			elif r<0.5:kit="nt_hohgras_1" if nah else ""
			elif r<0.53:kit="nt_busch_%d"%rng.randi_range(0,2)
		"wueste":
			if r<0.035:kit="nd_kaktus_%d"%rng.randi_range(0,2)
			elif r<0.06:kit="nd_fels_%d"%rng.randi_range(0,2)
			elif r<0.12:kit="nt_hohgras_0" if nah else ""
	if kit!="" and not K.KITS.has(kit):return ""
	return kit
func ist_baum(kit:String)->String:
	if kit.begins_with("nt_eiche") or kit.begins_with("nt_birke"):return "nt_fern_laub"
	if kit.begins_with("nt_tanne") or kit.begins_with("nt_kiefer"):return "nt_fern_nadel"
	return ""
# Platzierung über ein Rechteck (Probe). Ergebnis: [kit, Transform3D] mit absoluter Höhe.
func platzieren(rect:Rect2,hoehe:Callable,frei:Callable,info:Callable,raster:=6.0)->Array:
	var out=[]
	var x=rect.position.x
	while x<rect.end.x:
		var z=rect.position.y
		while z<rect.end.y:
			var px=x+rng.randf_range(-raster*0.45,raster*0.45);var pz=z+rng.randf_range(-raster*0.45,raster*0.45)
			z+=raster
			if not frei.call(px,pz):continue
			var h=hoehe.call(px,pz);var inf=info.call(px,pz)
			var kit=waehle(px,pz,h,inf[0],inf[1],inf[2],true)
			if kit=="":continue
			var sc=rng.randf_range(0.85,1.25)
			var xf=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*sc),Vector3(px,h-0.1,pz))
			out.append([kit,xf])
			var fk=ist_baum(kit)
			if fk!="":out.append([fk,xf])
		x+=raster
	return out

func _zaun():
	var pf=T(Color(0.45,0.47,0.48));var netz=T(Color(0.62,0.66,0.66))
	for x in [-5.0,0.0,5.0]:L.zyl(pf,Vector3(x,KB-0.3,0),Vector3(x,KB+2.2,0),0.05,1.1)
	L.zyl(pf,Vector3(-5,KB+2.2,0),Vector3(5,KB+2.2,0),0.03,1.1)
	for k in 3:L.box(netz,Vector3(0,KB+0.4+k*0.62,0),Vector3(10.0,0.04,0.02),Basis(),0.0)
	for k in 21:L.box(netz,Vector3(-5.0+k*0.5,KB+1.1,0),Vector3(0.02,2.0,0.02),Basis(),0.0)
	L.box(T(Color(0.6,0.55,0.4)),Vector3(0,KB+2.35,0),Vector3(10.0,0.06,0.06),Basis(Vector3.RIGHT,0.5),0.0)
	L.koll_box(Vector3(0,KB+1.1,0),Vector3(10.0,2.2,0.2))
func _hochsitz():
	var h=T(Color(0.46,0.32,0.2));var p=Vector3(0,KB,0)
	for sx in [-1,1]:
		for sz in [-1,1]:L.zyl(h,p+Vector3(sx*1.3,0,sz*1.3),p+Vector3(sx*0.8,4.0,sz*0.8),0.09,1.12)
	L.box(h,p+Vector3(0,4.0,0),Vector3(2.0,0.12,2.0),Basis(),0.03)
	for sd in [Vector3(0,0,1),Vector3(0,0,-1),Vector3(1,0,0),Vector3(-1,0,0)]:
		if sd.z<0.5:L.box(h,p+Vector3(0,4.5,0)+sd*0.95,Vector3(2.0 if sd.x==0 else 0.08,0.9,2.0 if sd.x!=0 else 0.08),Basis(),0.03)
	L.box(T(Color(0.3,0.25,0.2)),p+Vector3(0,5.6,0),Vector3(2.4,0.1,2.4),Basis(Vector3.RIGHT,0.12),0.03)
	for sx in [-0.9,0.9]:L.zyl(h,p+Vector3(sx,4.9,-0.95),p+Vector3(sx,5.6,-0.95),0.05,1.1)
	for sx in [-0.4,0.4]:L.zyl(h,p+Vector3(sx,0,2.6),p+Vector3(sx,4.0,1.0),0.05,1.1)
	for k in 7:L.zyl(h,p+Vector3(-0.4,0.5+k*0.5,2.6-(0.5+k*0.5)*0.4),p+Vector3(0.4,0.5+k*0.5,2.6-(0.5+k*0.5)*0.4),0.035,1.1)
	L.koll_box(p+Vector3(0,2.0,0),Vector3(2.6,4.0,2.6))

# ================= Sonderorte =================
# Lichtung mit Jagdhütte + Hochsitz. Gibt [platzierungen, freihalte-radius]
func jagd_platz(c:Vector2,y:float,w:float)->Array:
	var b=Basis(Vector3.UP,w);var o=Vector3(c.x,y-0.1,c.y)
	var P=[["nt_jagdhuette",Transform3D(b,o)],["nt_hochsitz",Transform3D(b,o+b*Vector3(22,0,-14))],["nt_totholz",Transform3D(b*Basis(Vector3.UP,0.7),o+b*Vector3(-12,0,8))]]
	for k in 14:
		var a=rng.randf()*TAU;var r=rng.randf_range(9.0,26.0)
		P.append(["nt_gras_%d"%(k%3) if k%4!=0 else "nt_blumen_%d"%(k%3),Transform3D(Basis(Vector3.UP,a),o+Vector3(cos(a)*r,0,sin(a)*r))])
	return P
# Cannabisfeld: n_x * n_z Reihenblöcke (je 24 x 2.6 m), Gewächshäuser, Wachhütte, Zaun. c=Mitte, y=ebene Höhe
func hanf_platz(c:Vector2,y:float,w:float,nx:=3,nz:=26)->Array:
	var b=Basis(Vector3.UP,w);var o=Vector3(c.x,y-0.05,c.y);var P=[]
	var bx=nx*26.0;var bz=nz*2.6
	for i in nx:
		for k in nz:P.append(["nt_hanf_reihe",Transform3D(b,o+b*Vector3(-bx*0.5+13.0+i*26.0,0,-bz*0.5+1.3+k*2.6))])
	P.append(["nt_gewaechshaus",Transform3D(b,o+b*Vector3(bx*0.5+12.0,0,-bz*0.5+24.0))])
	P.append(["nt_gewaechshaus",Transform3D(b,o+b*Vector3(bx*0.5+26.0,0,-bz*0.5+24.0))])
	P.append(["nt_wachhuette",Transform3D(b*Basis(Vector3.UP,PI),o+b*Vector3(bx*0.5+18.0,0,bz*0.5-4.0))])
	# Zaun rundum (Tor auf der Südseite)
	var ex=bx*0.5+42.0;var ez=bz*0.5+8.0;var x0=-bx*0.5-8.0
	var x=x0+5.0
	while x<ex:
		P.append(["nt_zaun",Transform3D(b,o+b*Vector3(x,0,-ez))])
		if abs(x-(bx*0.5+18.0))>9.0:P.append(["nt_zaun",Transform3D(b,o+b*Vector3(x,0,ez))])
		x+=10.0
	var z=-ez+5.0
	while z<ez:
		P.append(["nt_zaun",Transform3D(b*Basis(Vector3.UP,PI*0.5),o+b*Vector3(x0,0,z))])
		P.append(["nt_zaun",Transform3D(b*Basis(Vector3.UP,PI*0.5),o+b*Vector3(ex,0,z))])
		z+=10.0
	return P
func hanf_groesse(nx:=3,nz:=26)->Vector2:return Vector2(nx*26.0+50.0+16.0,nz*2.6+16.0)

func _palme(p:Vector3,h:float,neig:float):
	var st=T(Color(0.55,0.42,0.28));var bl=[T(Color(0.2,0.55,0.22)),T(Color(0.28,0.62,0.25))]
	var top=p+Vector3(neig,h,0)
	for k in 6:
		var a=p.lerp(top,k/6.0)+Vector3(sin(k/6.0*1.5)*neig*0.15,0,0);var b2=p.lerp(top,(k+1)/6.0)
		L.zyl(st,a,b2,0.24-k*0.015,1.1)
	for k in 7:
		var a=TAU*k/7.0;var bb=Basis(Vector3.UP,a)*Basis(Vector3.RIGHT,0.45)
		L.box(bl[k%2],top+Basis(Vector3.UP,a)*Vector3(0,-0.3,1.6),Vector3(0.6,0.06,3.4),bb,0.03)
	L.kugel(T(Color(0.45,0.32,0.18)),top,Vector3(0.35,0.3,0.35),1.05)
	L.PFOSTEN.append([p,0.3,3.0])
func _strandvilla():
	# moderne Villa: zwei versetzte weiße Kuben, Glasfronten zum Meer (+z), Holzterrasse, Pool, Liegen, Palmen
	var weiss=T(Color(0.95,0.94,0.9));var grau=T(Color(0.32,0.33,0.35));var glas=T(Color(0.45,0.7,0.82));var holz=T(Color(0.62,0.44,0.28))
	var p=Vector3(0,KB,-6.0)
	L.box(T(Color(0.85,0.84,0.8)),p+Vector3(0,0.1,0),Vector3(20,0.3,13),Basis(),0.03)
	# Erdgeschoss
	L.box(weiss,p+Vector3(-1,1.95,-0.5),Vector3(17,3.6,10),Basis(),0.05);L.koll_box(p+Vector3(-1,1.95,-0.5),Vector3(17,3.6,10))
	L.box(glas,p+Vector3(-2,1.85,4.52),Vector3(12,3.0,0.06),Basis(),0.03)
	for x in [-8.0,-5.0,-2.0,1.0,4.0]:L.box(grau,p+Vector3(x,1.85,4.56),Vector3(0.12,3.0,0.08),Basis(),0.0)
	L.box(grau,p+Vector3(-1,3.85,-0.5),Vector3(17.6,0.3,10.6),Basis(),0.04)
	# Obergeschoss, versetzt, mit Balkon
	L.box(weiss,p+Vector3(1.5,5.6,-1.5),Vector3(12,3.4,8),Basis(),0.05);L.koll_box(p+Vector3(1.5,5.6,-1.5),Vector3(12,3.4,8))
	L.box(glas,p+Vector3(1.5,5.5,2.52),Vector3(10,2.8,0.06),Basis(),0.03)
	L.box(grau,p+Vector3(1.5,7.45,-1.0),Vector3(13.4,0.3,10),Basis(),0.04)
	L.box(T(Color(0.7,0.85,0.9)),p+Vector3(1.5,4.55,4.4),Vector3(12,0.9,0.05),Basis(),0.02)
	# Garage + Eingang (Landseite -z)
	L.box(grau,p+Vector3(4.5,1.5,-5.55),Vector3(5,2.8,0.08),Basis(),0.02)
	L.box(T(Color(0.4,0.28,0.18)),p+Vector3(-4,1.4,-5.55),Vector3(1.4,2.6,0.08),Basis(),0.02)
	L.box(T(Color(0.6,0.6,0.58)),p+Vector3(4.5,0.12,-9),Vector3(5.5,0.12,7),Basis(),0.02)
	# Terrasse + Pool
	L.box(holz,p+Vector3(0,0.3,9.0),Vector3(20,0.3,8),Basis(),0.03);L.koll_box(p+Vector3(0,0.3,9.0),Vector3(20,0.3,8))
	L.box(T(Color(0.9,0.9,0.88)),p+Vector3(3,0.5,9.0),Vector3(9.4,0.2,5.4),Basis(),0.02)
	L.box(T(Color(0.2,0.68,0.88)),p+Vector3(3,0.58,9.0),Vector3(8.6,0.06,4.6),Basis(),0.0)
	for k in 3:
		var q=p+Vector3(-7+k*2.2,0.55,8.5)
		L.box(T(Color(0.95,0.95,0.95)),q,Vector3(0.8,0.25,2.0),Basis(Vector3.RIGHT,-0.15),0.02)
		L.box(T(Color(0.15,0.55,0.7)),q+Vector3(0,0.15,0),Vector3(0.7,0.08,1.9),Basis(Vector3.RIGHT,-0.15),0.0)
	L.zyl(T(Color(0.95,0.95,0.95)),p+Vector3(-7.5,0.45,11.5),p+Vector3(-7.5,2.8,11.5),0.04,1.1)
	L.kugel(T(Color(0.95,0.35,0.3)),p+Vector3(-7.5,2.8,11.5),Vector3(1.4,0.3,1.4),1.05)
	_palme(p+Vector3(-10.5,0,7.5),7.0,0.8);_palme(p+Vector3(10.5,0,10.5),8.0,-1.0);_palme(p+Vector3(9.5,0,-4.0),6.5,0.5)
	# Hecke an den Seiten
	for sx in [-12.0,12.0]:L.box(T(Color(0.25,0.48,0.2)),p+Vector3(sx,0.8,1.5),Vector3(1.0,1.4,22),Basis(),0.04)
func _steg():
	# Bootssteg: Holzdeck 3 m breit, 32 m lang (+z = Meer), Pfähle, Poller, Leiter, Lampe; Deck auf y=0.6
	var holz=T(Color(0.55,0.4,0.26));var holz2=T(Color(0.45,0.32,0.2))
	for k in 32:L.box(holz if k%2==0 else holz2,Vector3(0,0.6,k+0.5),Vector3(3.0,0.12,0.92),Basis(),0.0)
	L.box(holz2,Vector3(-1.45,0.48,16),Vector3(0.15,0.2,32),Basis(),0.02);L.box(holz2,Vector3(1.45,0.48,16),Vector3(0.15,0.2,32),Basis(),0.02)
	L.koll_box(Vector3(0,0.55,16),Vector3(3.0,0.2,32))
	for z in range(4,33,6):
		for sx in [-1.5,1.5]:L.zyl(holz2,Vector3(sx,-5.0,z),Vector3(sx,1.1,z),0.14,1.1)
	for z in [10.0,20.0,30.0]:L.zyl(T(Color(0.2,0.2,0.22)),Vector3(1.2,0.66,z),Vector3(1.2,1.0,z),0.12,1.1)
	L.box(T(Color(0.7,0.7,0.72)),Vector3(-1.6,0.0,31.5),Vector3(0.5,1.6,0.08),Basis(),0.0)
	L.zyl(T(Color(0.25,0.25,0.27)),Vector3(1.3,0.66,31.6),Vector3(1.3,3.0,31.6),0.05,1.1)
	L.kugel(T(Color(1.0,0.92,0.6)),Vector3(1.3,3.1,31.6),Vector3(0.2,0.2,0.2),1.05)

# ---------------- Ortswahl (Welt) ----------------
# Strandvilla + Steg: villa_xf und steg_xf (y absolut). ufer = Punkt der Wasserlinie, see = Richtung aufs Meer
func villa_platz(villa:Vector2,y:float,see:Vector2,ufer:Vector2)->Array:
	var yaw=atan2(see.x,see.y);var b=Basis(Vector3.UP,yaw)
	var P=[["nt_strandvilla",Transform3D(b,Vector3(villa.x,y-0.05,villa.y))]]
	var s0=ufer-see*6.0
	P.append(["nt_steg",Transform3D(b,Vector3(s0.x,0.7,s0.y))])
	return P
