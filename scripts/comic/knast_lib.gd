extends RefCounted
# Justizvollzugsanstalt (Gefängnis) im Comic-Stil: rechteckige Betonmauer mit NATO-Draht, Wachtürme mit
# Suchscheinwerfern, Außenzaun, Schleusen-Torhaus, vierstöckige Zellenblöcke mit vergitterten Fenstern,
# Verwaltung, Hofgang mit Basketballfeld, Werkstatt, Parkplatz. Ersetzt das alte ovale "Lager".
var L;var K
var rng:=RandomNumberGenerator.new()
const KB:=0.15
const MW:=200.0   # Mauer innen: Breite (x)
const MT:=160.0   # Mauer innen: Tiefe (z), Tor auf +z

func _init(lib,kitlib):
	L=lib;K=kitlib;rng.seed=99

var _mc:={}
func T(c:Color)->Material:
	var k=str(c)
	if not _mc.has(k):
		var m=StandardMaterial3D.new();m.albedo_color=c;m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.specular_mode=BaseMaterial3D.SPECULAR_TOON;m.roughness=0.9;_mc[k]=m
	return _mc[k]
var BETON:Material;var BETON2:Material;var DUNKEL:Material;var GITTER:Material;var DRAHT:Material;var ASPH:Material;var ORANGE:Material

func kits_bauen():
	var alt=[L.leicht,L.hoehen_an];L.leicht=false;L.hoehen_an=false
	BETON=T(Color(0.72,0.71,0.68));BETON2=T(Color(0.6,0.6,0.58));DUNKEL=T(Color(0.12,0.13,0.15));GITTER=T(Color(0.3,0.31,0.33))
	DRAHT=T(Color(0.78,0.8,0.82));ASPH=T(Color(0.36,0.36,0.37));ORANGE=T(Color(0.86,0.46,0.18))
	K.kit("kn_boden",MW+60.0,MT+60.0,func():_boden())
	K.kit("kn_mauer",40.0,1.0,func():_mauer())
	K.kit("kn_zaun",10.0,1.0,func():_zaun())
	K.kit("kn_turm",6.0,6.0,func():_turm())
	for i in 2:K.kit("kn_zellen_%d"%i,62.0,17.0,func():_zellen(i))
	K.kit("kn_verwaltung",52.0,20.0,func():_verwaltung())
	K.kit("kn_tor",40.0,22.0,func():_tor())
	K.kit("kn_hof",60.0,44.0,func():_hof())
	K.kit("kn_werkstatt",40.0,20.0,func():_werkstatt())
	K.kit("kn_parkplatz",50.0,26.0,func():_parkplatz())
	K.kit("kn_zufahrt",9.0,120.0,func():_zufahrt())
	L.leicht=alt[0];L.hoehen_an=alt[1]

# ---------------- Bausätze ----------------
func _boden():
	# Innenhof: Asphalt mit Rasenstreifen und Wegen, außen ein Kiesstreifen zwischen Mauer und Zaun
	L.box(T(Color(0.62,0.6,0.55)),Vector3(0,KB-0.06,0),Vector3(MW+42.0,0.12,MT+42.0),Basis(),0.0)
	L.box(ASPH,Vector3(0,KB,0),Vector3(MW-1.0,0.1,MT-1.0),Basis(),0.0)
	var gras=T(Color(0.36,0.55,0.24))
	for e in [[Vector3(-60,0,52),Vector3(60,0.05,22)],[Vector3(55,0,48),Vector3(70,0.05,26)],[Vector3(-80,0,-65),Vector3(30,0.05,20)]]:
		L.box(gras,Vector3(e[0].x,KB+0.06,e[0].z),e[1]+Vector3(0,0,0),Basis(),0.0)
	# gelbe Fahrspur zum Tor + Linien
	for k in 14:L.box(T(Color(0.95,0.8,0.2)),Vector3(0,KB+0.06,MT*0.5-6.0-k*6.0),Vector3(0.25,0.02,3.0),Basis(),0.0)
func _mauer():
	# 40 m Betonmauer, 7 m hoch, Kappe, NATO-Drahtrolle oben, Flutlicht alle 20 m (Mauerlinie entlang x, innen = +z)
	L.box(BETON,Vector3(0,KB+3.5,0),Vector3(40.0,7.0,0.7),Basis(),0.05)
	L.box(BETON2,Vector3(0,KB+7.1,0),Vector3(40.2,0.25,1.1),Basis(),0.03)
	for x in range(-18,20,4):L.box(BETON2,Vector3(x,KB+3.5,-0.38),Vector3(0.5,7.0,0.12),Basis(),0.0)
	# Drahtrolle: Ringe entlang der Mauer
	for k in 40:
		var x=-19.5+k
		L.zyl(DRAHT,Vector3(x,KB+7.3,-0.35),Vector3(x+0.6,KB+7.95,0.35),0.03,1.0)
		L.zyl(DRAHT,Vector3(x,KB+7.95,-0.35),Vector3(x+0.6,KB+7.3,0.35),0.03,1.0)
	L.zyl(DRAHT,Vector3(-20,KB+7.65,0),Vector3(20,KB+7.65,0),0.02,1.0)
	for x in [-10.0,10.0]:
		L.zyl(GITTER,Vector3(x,KB+7.2,0.3),Vector3(x,KB+8.4,1.4),0.06,1.1)
		L.box(T(Color(1.0,0.96,0.75)),Vector3(x,KB+8.4,1.5),Vector3(0.7,0.3,0.4),Basis(Vector3.RIGHT,0.5),0.02)
	L.koll_box(Vector3(0,KB+3.6,0),Vector3(40.0,7.2,0.8))
func _zaun():
	# Außenzaun: 10 m Maschendraht, 4,5 m hoch, oben schräger Ausleger mit Stacheldraht
	for x in [-5.0,0.0,5.0]:
		L.zyl(GITTER,Vector3(x,KB-0.3,0),Vector3(x,KB+4.5,0),0.06,1.1)
		L.zyl(GITTER,Vector3(x,KB+4.5,0),Vector3(x,KB+5.2,-0.6),0.04,1.1)
	for k in 5:L.box(DRAHT,Vector3(0,KB+0.5+k*1.0,0),Vector3(10.0,0.03,0.02),Basis(),0.0)
	for k in 26:L.box(DRAHT,Vector3(-5.0+k*0.4,KB+2.25,0),Vector3(0.02,4.4,0.02),Basis(),0.0)
	for k in 3:L.zyl(DRAHT,Vector3(-5,KB+4.6+k*0.22,-0.15-k*0.2),Vector3(5,KB+4.6+k*0.22,-0.15-k*0.2),0.02,1.0)
	L.koll_box(Vector3(0,KB+2.3,0),Vector3(10.0,4.6,0.25))
func _turm():
	# Wachturm 15 m: Betonschaft, verglaste Kanzel mit Umgang, Flachdach, Suchscheinwerfer, Leiter
	L.box(BETON,Vector3(0,KB+5.5,0),Vector3(3.2,11.0,3.2),Basis(),0.05);L.koll_box(Vector3(0,KB+5.5,0),Vector3(3.2,11.0,3.2))
	for k in 5:L.box(BETON2,Vector3(0,KB+1.0+k*2.2,1.62),Vector3(1.0,0.12,0.06),Basis(),0.0)
	L.box(BETON2,Vector3(0,KB+11.1,0),Vector3(6.4,0.35,6.4),Basis(),0.04)
	for s in [Vector3(0,0,1),Vector3(0,0,-1),Vector3(1,0,0),Vector3(-1,0,0)]:
		var lang=s.z!=0
		L.box(BETON,Vector3(0,KB+11.75,0)+s*3.1,Vector3(6.4 if lang else 0.15,1.0,0.15 if lang else 6.4),Basis(),0.02)
		L.box(T(Color(0.4,0.62,0.72)),Vector3(0,KB+13.0,0)+s*2.05,Vector3(4.0 if lang else 0.06,1.6,0.06 if lang else 4.0),Basis(),0.0)
	L.box(BETON,Vector3(0,KB+12.2,0),Vector3(4.2,0.9,4.2),Basis(),0.03)
	for sx in [-2.05,2.05]:
		for sz in [-2.05,2.05]:L.box(BETON2,Vector3(sx,KB+13.0,sz),Vector3(0.25,1.6,0.25),Basis(),0.0)
	L.box(DUNKEL,Vector3(0,KB+14.0,0),Vector3(5.6,0.35,5.6),Basis(),0.04)
	L.zyl(GITTER,Vector3(2.2,KB+14.2,2.2),Vector3(2.2,KB+14.9,2.2),0.08,1.1)
	L.zyl(T(Color(0.2,0.2,0.22)),Vector3(2.2,KB+15.0,2.2),Vector3(2.7,KB+14.8,2.7),0.35,1.06)
	L.zyl(T(Color(1.0,0.97,0.8)),Vector3(2.7,KB+14.8,2.7),Vector3(2.75,KB+14.78,2.75),0.3,1.0)
	L.zyl(GITTER,Vector3(0,KB+14.2,0),Vector3(0,KB+16.0,0),0.04,1.0)
func _fenster_reihe(c:Vector3,n:int,abst:float,seite:Vector3,yaw:float):
	var b=Basis(Vector3.UP,yaw)
	for k in n:
		var p=c+b*Vector3(-(n-1)*abst*0.5+k*abst,0,0)
		L.box(DUNKEL,p+seite*0.02,Vector3(0.9,1.2,0.06),b,0.0)
		for g in 3:L.box(GITTER,p+seite*0.07+b*Vector3(-0.28+g*0.28,0,0),Vector3(0.05,1.25,0.05),b,0.0)
		L.box(BETON2,p+seite*0.08+Vector3(0,-0.68,0),Vector3(1.1,0.1,0.12),b,0.0)
func _zellen(i:int):
	# Zellenhaus: 60 x 15 m, 4 Geschosse, Fensterbänder mit Gittern, Treppenhaus-Turm, Lüfter auf dem Dach
	var farbe=[T(Color(0.82,0.8,0.74)),T(Color(0.78,0.74,0.66))][i];var band=[T(Color(0.55,0.27,0.18)),T(Color(0.3,0.38,0.5))][i]
	L.box(farbe,Vector3(0,KB+7.0,0),Vector3(60.0,14.0,15.0),Basis(),0.06);L.koll_box(Vector3(0,KB+7.0,0),Vector3(60.0,14.0,15.0))
	for g in 4:
		var y=KB+2.0+g*3.4
		L.box(band,Vector3(0,y-1.0,7.53),Vector3(60.0,0.25,0.06),Basis(),0.0);L.box(band,Vector3(0,y-1.0,-7.53),Vector3(60.0,0.25,0.06),Basis(),0.0)
		_fenster_reihe(Vector3(0,y+0.3,7.5),22,2.6,Vector3(0,0,1),0.0)
		_fenster_reihe(Vector3(0,y+0.3,-7.5),22,2.6,Vector3(0,0,-1),PI)
	L.box(BETON2,Vector3(0,KB+14.2,0),Vector3(60.6,0.4,15.6),Basis(),0.04)
	L.box(farbe,Vector3(30.0,KB+8.0,0),Vector3(5.0,16.0,6.0),Basis(),0.05)
	L.box(DUNKEL,Vector3(32.55,KB+8.0,0),Vector3(0.06,12.0,1.2),Basis(),0.0)
	for k in 3:L.box(T(Color(0.6,0.62,0.64)),Vector3(-18+k*16,KB+15.0,-2),Vector3(3.0,1.4,2.4),Basis(),0.03)
	L.box(T(Color(0.3,0.3,0.32)),Vector3(-31,KB+1.2,3),Vector3(0.1,2.4,1.6),Basis(),0.0)
	L.box(band,Vector3(-20,KB+12.6,7.56),Vector3(8,1.6,0.06),Basis(),0.0)
	L._schrift("ZELLENHAUS",Vector3(-20,KB+12.6,7.62),Basis(),0.006,Color(1,1,1))
func _verwaltung():
	# Verwaltung/Besucherhaus: 3 Geschosse, Glaseingang, Vordach, Fahnenmasten, große Beschriftung (Schrift extra)
	var w=T(Color(0.88,0.86,0.8))
	L.box(w,Vector3(0,KB+5.0,0),Vector3(50.0,10.0,18.0),Basis(),0.06);L.koll_box(Vector3(0,KB+5.0,0),Vector3(50.0,10.0,18.0))
	for g in 3:
		for k in 14:L.box(T(Color(0.35,0.5,0.62)),Vector3(-22.75+k*3.5,KB+1.8+g*3.2,9.03),Vector3(2.4,1.6,0.06),Basis(),0.0)
	L.box(T(Color(0.45,0.65,0.78)),Vector3(0,KB+1.6,9.06),Vector3(8.0,3.0,0.06),Basis(),0.0)
	L.box(BETON2,Vector3(0,KB+3.4,11.0),Vector3(10.0,0.3,4.2),Basis(),0.03)
	for sx in [-4.6,4.6]:L.zyl(BETON2,Vector3(sx,KB,12.8),Vector3(sx,KB+3.3,12.8),0.15,1.1)
	L.box(T(Color(0.15,0.25,0.45)),Vector3(0,KB+8.6,9.08),Vector3(30.0,1.6,0.08),Basis(),0.02)
	L._schrift("JVA RADEBERG – VERWALTUNG",Vector3(0,KB+8.6,9.16),Basis(),0.0085,Color(1,1,1))
	for k in 3:
		L.zyl(T(Color(0.85,0.85,0.85)),Vector3(-14+k*3,KB,16),Vector3(-14+k*3,KB+9.0,16),0.07,1.1)
		var fc=[Color(0.1,0.1,0.1),Color(0.85,0.15,0.15),Color(0.95,0.8,0.1)]
		for f in 3:L.box(T(fc[f]),Vector3(-13.0+k*3,KB+8.4-f*0.4,16),Vector3(1.8,0.4,0.03),Basis(),0.0)
	L.box(BETON2,Vector3(0,KB+10.2,0),Vector3(50.6,0.4,18.6),Basis(),0.04)
func _tor():
	# Schleusen-Torhaus (40 m breit, ersetzt ein Mauerstück): zwei Rolltore, Durchfahrt, Pförtnerloge, Schranke
	L.box(BETON,Vector3(-14.5,KB+5.0,0),Vector3(11.0,10.0,20.0),Basis(),0.05);L.koll_box(Vector3(-14.5,KB+5.0,0),Vector3(11.0,10.0,20.0))
	L.box(BETON,Vector3(14.5,KB+5.0,0),Vector3(11.0,10.0,20.0),Basis(),0.05);L.koll_box(Vector3(14.5,KB+5.0,0),Vector3(11.0,10.0,20.0))
	L.box(BETON2,Vector3(0,KB+8.5,0),Vector3(18.0,3.0,20.0),Basis(),0.05)
	L.box(BETON2,Vector3(0,KB+10.2,0),Vector3(40.4,0.4,20.4),Basis(),0.04)
	for z in [-9.8,9.8]:
		L.box(T(Color(0.45,0.46,0.48)),Vector3(0,KB+3.5,z),Vector3(18.0,7.0,0.2),Basis(),0.02)
		for k in 9:L.box(GITTER,Vector3(-8.0+k*2.0,KB+3.5,z+(0.12 if z>0 else -0.12)),Vector3(0.12,7.0,0.06),Basis(),0.0)
		L.koll_box(Vector3(0,KB+3.5,z),Vector3(18.0,7.0,0.3))
	for k in 6:L.box(T(Color(0.4,0.62,0.74)),Vector3(-19+k*1.8,KB+6.5,10.03),Vector3(1.2,1.2,0.06),Basis(),0.0)
	# Pförtnerloge vor dem Tor
	L.box(T(Color(0.9,0.9,0.88)),Vector3(13.0,KB+1.6,15.0),Vector3(4.0,3.2,3.0),Basis(),0.04);L.koll_box(Vector3(13.0,KB+1.6,15.0),Vector3(4.0,3.2,3.0))
	L.box(T(Color(0.4,0.62,0.74)),Vector3(10.97,KB+1.9,15.0),Vector3(0.06,1.4,2.4),Basis(),0.0)
	L.box(DUNKEL,Vector3(13.0,KB+3.35,15.0),Vector3(4.6,0.3,3.6),Basis(),0.03)
	L.zyl(T(Color(0.95,0.95,0.95)),Vector3(10.5,KB+1.0,17.5),Vector3(1.0,KB+1.0,17.5),0.08,1.1)
	for k in 5:L.box(T(Color(0.85,0.1,0.1)),Vector3(9.5-k*2.0,KB+1.0,17.5),Vector3(0.9,0.2,0.2),Basis(),0.0)
	L.box(T(Color(0.15,0.25,0.45)),Vector3(0,KB+8.6,10.12),Vector3(17.5,1.6,0.08),Basis(),0.02)
	L._schrift("JUSTIZVOLLZUGSANSTALT RADEBERG",Vector3(0,KB+8.6,10.2),Basis(),0.0075,Color(1,1,1))
func _hof():
	# Hofgang: Asphalt, Basketballfeld, Klimmzugstangen, Bänke, 5 m Zaun rundum mit Tor
	L.box(T(Color(0.42,0.43,0.45)),Vector3(0,KB+0.08,0),Vector3(58,0.06,42),Basis(),0.0)
	var weiss=T(Color(0.95,0.95,0.92))
	L.box(T(Color(0.7,0.35,0.2)),Vector3(-10,KB+0.12,0),Vector3(28,0.02,15),Basis(),0.0)
	for e in [[Vector3(-10,0,7.5),Vector3(28,0.02,0.15)],[Vector3(-10,0,-7.5),Vector3(28,0.02,0.15)],[Vector3(-24,0,0),Vector3(0.15,0.02,15)],[Vector3(4,0,0),Vector3(0.15,0.02,15)],[Vector3(-10,0,0),Vector3(0.15,0.02,15)]]:
		L.box(weiss,e[0]+Vector3(0,KB+0.14,0),e[1],Basis(),0.0)
	for sx in [-1,1]:
		var x=-10+sx*13.5
		L.zyl(GITTER,Vector3(x+sx*1.2,KB,0),Vector3(x+sx*1.2,KB+3.4,0),0.08,1.1)
		L.box(weiss,Vector3(x,KB+3.6,0),Vector3(0.08,1.0,1.6),Basis(),0.02)
		L.zyl(ORANGE,Vector3(x-sx*0.3,KB+3.05,-0.25),Vector3(x-sx*0.3,KB+3.05,0.25),0.24,1.0)
	for k in 3:
		var x=16+k*3.0
		L.zyl(GITTER,Vector3(x,KB,-12),Vector3(x,KB+2.6,-12),0.06,1.1);L.zyl(GITTER,Vector3(x+2.0,KB,-12),Vector3(x+2.0,KB+2.6,-12),0.06,1.1)
		L.zyl(GITTER,Vector3(x,KB+2.5,-12),Vector3(x+2.0,KB+2.5,-12),0.04,1.0)
	for k in 4:
		L.box(T(Color(0.5,0.38,0.25)),Vector3(14+k*4.0,KB+0.45,12),Vector3(2.4,0.1,0.5),Basis(),0.02)
		L.box(GITTER,Vector3(14+k*4.0,KB+0.22,12),Vector3(2.2,0.45,0.1),Basis(),0.0)
	L.box(T(Color(0.6,0.55,0.5)),Vector3(20,KB+0.45,2),Vector3(2.0,0.6,1.0),Basis(),0.02)
	# Zaun
	for e in [[Vector3(0,0,21),58.0,0.0],[Vector3(0,0,-21),58.0,0.0],[Vector3(29,0,0),42.0,PI*0.5],[Vector3(-29,0,0),42.0,PI*0.5]]:
		var b=Basis(Vector3.UP,e[2]);var lg:float=e[1]
		var n=int(lg/3.0)
		for k in n+1:
			var p=e[0]+b*Vector3(-lg*0.5+k*lg/n,0,0)
			L.zyl(GITTER,p+Vector3(0,KB,0),p+Vector3(0,KB+5.0,0),0.05,1.1)
		for h in [0.3,2.5,4.9]:L.box(DRAHT,e[0]+Vector3(0,KB+h,0),b*Vector3(lg,0.04,0.04) if e[2]==0.0 else Vector3(0.04,0.04,lg),Basis(),0.0)
		L.box(T(Color(0.7,0.72,0.74)),e[0]+Vector3(0,KB+2.6,0),Vector3(lg,4.6,0.02) if e[2]==0.0 else Vector3(0.02,4.6,lg),Basis(),0.0)
		if e[0].z>0:
			L.koll_box(e[0]+Vector3(-lg*0.25-2.0,KB+2.5,0),Vector3(lg*0.5-4.0,5.0,0.3));L.koll_box(e[0]+Vector3(lg*0.25+2.0,KB+2.5,0),Vector3(lg*0.5-4.0,5.0,0.3))
		else:L.koll_box(e[0]+Vector3(0,KB+2.5,0),Vector3(lg,5.0,0.3) if e[2]==0.0 else Vector3(0.3,5.0,lg))
func _werkstatt():
	# Werkstatt/Küche mit Sheddach, Ladetoren und Schornstein
	var w=T(Color(0.7,0.68,0.62))
	L.box(w,Vector3(0,KB+3.5,0),Vector3(38.0,7.0,18.0),Basis(),0.05);L.koll_box(Vector3(0,KB+3.5,0),Vector3(38.0,7.0,18.0))
	for k in 6:L.box(T(Color(0.5,0.5,0.52)),Vector3(-15.8+k*6.3,KB+7.8,0),Vector3(6.0,0.25,18.4),Basis(Vector3.BACK,0.25),0.03)
	for k in 3:L.box(T(Color(0.4,0.42,0.45)),Vector3(-12+k*12,KB+2.0,9.03),Vector3(5.0,4.0,0.08),Basis(),0.0)
	L.zyl(BETON2,Vector3(16,KB,-6),Vector3(16,KB+14.0,-6),0.6,1.08)
	for k in 8:L.box(DUNKEL,Vector3(-17+k*4.6,KB+5.4,-9.03),Vector3(1.4,0.9,0.06),Basis(),0.0)
func _zufahrt():
	# Zufahrt vom Tor nach Süden bis zur alten Straße (120 m)
	L.box(ASPH,Vector3(0,KB+0.03,0),Vector3(9.0,0.1,120.0),Basis(),0.0)
	for k in 20:L.box(T(Color(0.95,0.95,0.92)),Vector3(0,KB+0.09,-57+k*6.0),Vector3(0.15,0.02,3.0),Basis(),0.0)
	for sx in [-4.3,4.3]:L.box(T(Color(0.95,0.95,0.92)),Vector3(sx,KB+0.09,0),Vector3(0.15,0.02,120.0),Basis(),0.0)
func _parkplatz():
	L.box(ASPH,Vector3(0,KB+0.04,0),Vector3(50,0.08,26),Basis(),0.0)
	for k in 13:L.box(T(Color(0.95,0.95,0.92)),Vector3(-24+k*4.0,KB+0.09,-6),Vector3(0.15,0.02,5.0),Basis(),0.0)
	for k in 13:L.box(T(Color(0.95,0.95,0.92)),Vector3(-24+k*4.0,KB+0.09,6),Vector3(0.15,0.02,5.0),Basis(),0.0)
	L.box(T(Color(0.15,0.25,0.5)),Vector3(-22,KB+2.2,-12.5),Vector3(3.0,1.4,0.1),Basis(),0.02)
	L._schrift("P\nBESUCHER",Vector3(-22,KB+2.2,-12.42),Basis(),0.004,Color(1,1,1))
	L.zyl(GITTER,Vector3(-22,KB,-12.6),Vector3(-22,KB+1.6,-12.6),0.05,1.1)

# ---------------- Anlage (lokale Koordinaten: Mitte, Tor auf +z) ----------------
# Gibt [kit, Transform3D] relativ zur Mitte (y=0) zurück; der Aufrufer setzt Lage/Drehung/Höhe.
func anlage()->Array:
	var P=[]
	var t=func(kit:String,x:float,z:float,yaw:=0.0):P.append([kit,Transform3D(Basis(Vector3.UP,yaw),Vector3(x,0,z))])
	t.call("kn_boden",0,0)
	# Mauer: 5 x 40 m an den Längsseiten (Süd mit Tor in der Mitte), 4 x 40 m an den Schmalseiten
	for k in 5:
		var x=-MW*0.5+20.0+k*40.0
		t.call("kn_mauer",x,-MT*0.5,PI)
		if k==2:t.call("kn_tor",x,MT*0.5)
		else:t.call("kn_mauer",x,MT*0.5)
	for k in 4:
		var z=-MT*0.5+20.0+k*40.0
		t.call("kn_mauer",-MW*0.5,z,PI*0.5);t.call("kn_mauer",MW*0.5,z,-PI*0.5)
	# Außenzaun 12 m vor der Mauer, Lücke am Tor
	var ax=MW*0.5+12.0;var az=MT*0.5+12.0
	var x=-ax+5.0
	while x<ax:
		t.call("kn_zaun",x,-az)
		if abs(x)>14.0:t.call("kn_zaun",x,az)
		x+=10.0
	var z=-az+5.0
	while z<az:
		t.call("kn_zaun",-ax,z,PI*0.5);t.call("kn_zaun",ax,z,PI*0.5);z+=10.0
	# Wachtürme: Ecken, Mitte der Längsseiten (Nord), Schmalseiten, beidseits vom Tor
	for e in [[-1,-1],[1,-1],[-1,1],[1,1]]:t.call("kn_turm",e[0]*(MW*0.5-3.0),e[1]*(MT*0.5-3.0))
	t.call("kn_turm",0,-MT*0.5+3.0);t.call("kn_turm",-MW*0.5+3.0,0);t.call("kn_turm",MW*0.5-3.0,0)
	t.call("kn_turm",-26.0,MT*0.5-3.0);t.call("kn_turm",26.0,MT*0.5-3.0)
	# Gebäude
	for k in 3:t.call("kn_zellen_%d"%(k%2),-78.0+k*30.0,-30.0,PI*0.5)
	t.call("kn_zellen_1",30.0,-58.0)
	t.call("kn_verwaltung",-45.0,52.0)
	t.call("kn_hof",58.0,-15.0)
	t.call("kn_werkstatt",62.0,45.0)
	t.call("kn_parkplatz",-40.0,MT*0.5+40.0)
	t.call("kn_zufahrt",0.0,MT*0.5+70.0)
	return P
