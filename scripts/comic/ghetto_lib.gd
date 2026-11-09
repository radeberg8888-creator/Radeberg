extends RefCounted
# Ghetto (Grove): südlich der Comic-Altstadt, hinter der Autobahn. Baut in die stadt_lib L (gleiche Koordinaten).
# Aufbau: Ost-West-Straßen mit Holzhäusern, dazwischen Hintergassen mit Garagen/Schuppen; Nord-Süd-Querstraßen
# mit Eckläden. Kein leerer Hof: jede Parzelle reicht von der Straße bis zur Gasse.
var L
var rng:=RandomNumberGenerator.new()
const X0:=-470.0
const X1:=190.0
const Z0:=300.0
const Z1:=648.0
const ZS:=[312.0,388.0,464.0,540.0,616.0]     # Ost-West-Straßen
const XS:=[-450.0,-300.0,-130.0,40.0,170.0]   # Nord-Süd-Straßen
const NAMEN_EW:=["Grenzweg","Grove Street","Kohlenstraße","Ziegeleiweg","Bahndamm"]
const NAMEN_NS:=["Westkante","Weststraße","Grove-Allee","Kesselweg","Ostkante"]
const W_STR:=5.0      # halbe Fahrbahnbreite (wie Stadtstraßen: Spur 1.8 m, Parker 3.85 m -> KI fährt vorbei)
const SW:=2.5         # Gehweg
const W_GASSE:=2.6
var EW:=[];var NS:=[];var GASSEN:=[]
var LOTS:=0
const TAGS:=["RBG","KING","187","SKRT","YO!","DOPE","CREW","ZONE","OST","BOOM","GROVE","KRIEG","ROST","NOFX","GHETTO","SÜD"]
const SPRAY:=[Color(0.95,0.2,0.6),Color(0.2,0.8,0.95),Color(0.98,0.85,0.1),Color(0.4,0.95,0.3),Color(0.95,0.45,0.1),Color(0.6,0.3,0.95),Color(0.95,0.95,0.95)]
var _mat:={}
var ohne_tags:=false   # Bausatz: keine Label3D-Tags (zu viele Instanzen)

func _init(lib):
	L=lib;rng.seed=4711

func T(c:Color)->StandardMaterial3D:
	var k=c.to_html()
	if not _mat.has(k):_mat[k]=L._toon(c)
	return _mat[k]
func Y(yaw:float)->Basis:return Basis(Vector3.UP,yaw)

# ---------- Straßennetz (wird VOR der Bebauung in L.R eingetragen) ----------
func ez(i:int,x:float)->float:   # z der Ost-West-Straße i an Stelle x (leicht geschwungen)
	return ZS[i]+sin(x*0.011+i*1.7)*2.2
func nx(j:int,z:float)->float:
	return XS[j]+sin(z*0.013+j*2.3)*1.6
func gz(i:int,x:float)->float:   # Gasse zwischen Straße i und i+1
	return (ez(i,x)+ez(i+1,x))*0.5

func strassen():
	for i in ZS.size():
		var P=PackedVector2Array();var x=XS[0]
		while x<XS[XS.size()-1]-0.01:
			P.append(Vector2(x,ez(i,x)));x+=4.0
		P.append(Vector2(XS[XS.size()-1],ez(i,XS[XS.size()-1])))
		# Endpunkte genau auf die Randstraßen legen
		P[0]=Vector2(nx(0,P[0].y),P[0].y);P[P.size()-1]=Vector2(nx(XS.size()-1,P[P.size()-1].y),P[P.size()-1].y)
		var r=L._strasse(NAMEN_EW[i],P,W_STR,"strasse");r["gh"]=true;EW.append(r)
	for j in XS.size():
		var P=PackedVector2Array();var z=Z0 if j in [1,2] else ZS[0]
		while z<ZS[ZS.size()-1]-0.01:
			P.append(Vector2(nx(j,z),z));z+=4.0
		P.append(Vector2(nx(j,ZS[ZS.size()-1]),ZS[ZS.size()-1]))
		var r=L._strasse(NAMEN_NS[j],P,W_STR,"strasse");r["gh"]=true;NS.append(r)
	for i in ZS.size()-1:
		for j in XS.size()-1:
			var xa=nx(j,gz(i,XS[j]))+W_STR;var xb=nx(j+1,gz(i,XS[j+1]))-W_STR
			var P=PackedVector2Array();var x=xa
			while x<xb-0.01:P.append(Vector2(x,gz(i,x)));x+=4.0
			P.append(Vector2(xb,gz(i,xb)))
			var r=L._strasse("Gasse %d-%d"%[i,j],P,W_GASSE,"gasse");r["gh"]=true;GASSEN.append(r)

# ---------- Bebauung ----------
func bauen():
	var t0=Time.get_ticks_msec()
	L.mat_cache=true
	# Bodenplatten: Viertel-Rechteck minus Fahrbahnen
	var rect=PackedVector2Array([Vector2(X0,Z0),Vector2(X1,Z0),Vector2(X1,Z1),Vector2(X0,Z1)])
	var stuecke=[rect]
	# Reihenfolge so, dass jedes Band den Rand des aktuellen Stücks berührt (sonst entstünde ein Loch statt eines Schnitts)
	for r in [NS[1],NS[2]]+EW+[NS[0],NS[3],NS[4]]+GASSEN:
		var baender=Geometry2D.offset_polyline(r.P,r.w,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
		var neu=[];var loecher=0
		for pc in stuecke:
			var teile=[pc]
			for band in baender:
				var t2=[]
				for t in teile:
					for x in Geometry2D.clip_polygons(t,band):
						if not Geometry2D.is_polygon_clockwise(x):t2.append(x)
						else:loecher+=1
				teile=t2
			neu.append_array(teile)
		stuecke=neu
		if loecher>0:push_error("GHETTO Bodenplatte: Loch bei "+r.n)
	for pc in stuecke:
		if abs(L._flaeche2(pc))<4.0:continue
		L._platte(pc,-1.2,L.KB,L.M.pflaster,L.M.stein)
	# Fahrbahnen
	L.strassen_modus=true
	var flick=T(Color(0.2,0.2,0.22))
	for r in EW+NS+GASSEN:
		streifen(r.P,r.w+0.05)
		# Flicken, Risse, abgefahrene Mittellinie
		var Ls=r.S[r.S.size()-1];var s=3.0
		while s<Ls-3.0:
			var b=L._bei_s(r.P,r.S,s);var p:Vector2=b[0];var t:Vector2=b[1];var n=L._rn(t)
			if r.typ!="gasse" and fmod(s,9.0)<3.0 and not L._nah_kreuzung(p,2.0) and rng.randf()<0.8:
				L.box(L.M.markierung,Vector3(p.x,0.03,p.y),Vector3(0.14,0.012,2.6),Y(atan2(t.x,t.y)),0.0)
			if rng.randf()<0.18:
				var q=p+n*rng.randf_range(-r.w+0.6,r.w-0.6)
				L.box(flick,Vector3(q.x,0.026,q.y),Vector3(rng.randf_range(0.8,2.6),0.01,rng.randf_range(0.6,1.8)),Y(rng.randf()*TAU),0.0)
			if rng.randf()<0.1:
				var q=p+n*rng.randf_range(-r.w+0.6,r.w-0.6)
				L.box(L.M.linie,Vector3(q.x,0.028,q.y),Vector3(rng.randf_range(1.2,3.0),0.01,0.05),Y(rng.randf()*TAU),0.0)
			s+=3.0
	L.strassen_modus=false
	# Parzellenreihen an den Ost-West-Straßen
	for i in ZS.size():
		for sd in [-1,1]:
			var hat_gasse=(sd==1 and i<ZS.size()-1) or (sd==-1 and i>0)
			for j in XS.size()-1:
				if hat_gasse:reihe(i,sd,j)
				else:randreihe(i,sd,j)
	# Ecken an den Nord-Süd-Straßen
	for i in ZS.size():
		for j in XS.size():
			for sx in [-1,1]:
				for sd in [-1,1]:
					if (j==0 and sx==-1) or (j==XS.size()-1 and sx==1):continue
					if (i==0 and sd==-1) or (i==ZS.size()-1 and sd==1):continue
					ecke(i,j,sx,sd)
	# Nord-Süd-Straßen: Seitenwände zwischen den Ecken (Zäune mit Tags)
	for j in XS.size():
		for sx in [-1,1]:
			if (j==0 and sx==-1) or (j==XS.size()-1 and sx==1):
				randwand_ns(j,sx);continue
	strommasten()
	parken()
	L.mat_cache=false
	print("GHETTO Parzellen ",LOTS," ",Time.get_ticks_msec()-t0," ms")

func front_z(i:int,sd:int,x:float)->float:return ez(i,x)+sd*(W_STR+SW)
func back_z(i:int,sd:int,x:float)->float:
	var g=gz(i,x) if sd==1 else gz(i-1,x)
	return g-sd*(W_GASSE+0.25)

func reihe(i:int,sd:int,j:int):
	var xa=nx(j,ZS[i])+16.0;var xb=nx(j+1,ZS[i])-16.0
	var x=xa
	while x<xb-8.0:
		var w=rng.randf_range(8.2,9.6)
		if x+w>xb:break
		parzelle(i,sd,x,x+w)
		x+=w
		# Einfahrt zwischen den Häusern (bis hinten zur Gasse durch)
		einfahrt(i,sd,x,x+3.6)
		x+=3.6

func parzelle(i:int,sd:int,xa:float,xb:float):
	LOTS+=1
	var xm=(xa+xb)*0.5;var w=xb-xa
	var zf=front_z(i,sd,xm);var zb=back_z(i,sd,xm);var tief=abs(zb-zf)
	var aussen=Vector3(0,0,-sd);var rechts=Vector3.UP.cross(aussen);var yaw=atan2(aussen.x,aussen.z)
	var kb=L.KB
	var front=Vector3(xm,kb,zf)
	var P=func(px,py,pz):return front+rechts*px+Vector3.UP*py-aussen*pz   # pz: von der Straße weg
	# Boden: verdorrter Rasen / Dreck
	var gras=[T(Color(0.52,0.53,0.3)),T(Color(0.47,0.45,0.27)),T(Color(0.56,0.5,0.32))][rng.randi()%3]
	L.box(gras,Vector3(xm,kb+0.012,(zf+zb)*0.5),Vector3(w,0.02,tief),Basis(),0.0)
	if rng.randf()<0.6:L.box(T(Color(0.42,0.33,0.22)),P.call(rng.randf_range(-2,2),0.03,rng.randf_range(1.5,3.0)),Vector3(rng.randf_range(2,5),0.02,rng.randf_range(1.2,2.4)),Y(yaw),0.0)
	var art=rng.randf()
	var farben=[Color(0.55,0.62,0.64),Color(0.74,0.68,0.54),Color(0.6,0.64,0.52),Color(0.7,0.56,0.5),Color(0.62,0.58,0.66),Color(0.78,0.74,0.62),Color(0.5,0.55,0.6),Color(0.68,0.5,0.42)]
	if art<0.82:
		L.holz_ghetto=true
		L._holzhaus(front,w-0.6,aussen,farben[rng.randi()%farben.size()])
		L.holz_ghetto=false
		L.koll_box(P.call(0,0.5+3.0,4.5+4.5),Vector3(w-0.6,6.0,9.0),Y(yaw))
		L.koll_box(P.call(0,0.35,4.5-1.1),Vector3(w-1.6,0.7,2.2),Y(yaw))
		var hw=(w-0.6)*0.5
		# Verfall: vernagelte Fenster, Schmutz, abgeblätterte Farbe, Tags an den Seiten
		var holz=T(Color(0.5,0.38,0.24));var holz2=T(Color(0.62,0.5,0.34))
		var fb=Basis(rechts,Vector3.UP,aussen)
		for wx in [-hw*0.64,hw*0.64]:
			if rng.randf()<0.35:
				for q in 3:L.box(holz if q%2==0 else holz2,P.call(wx,0.5+1.45+q*0.4,4.5-0.14),Vector3(1.2,0.22,0.04),fb*Basis(Vector3(0,0,1),rng.randf_range(-0.15,0.15)),0.012)
		for sx in [-1,1]:
			var sb=Basis(-aussen*sx,Vector3.UP,rechts*sx)
			L.box(T(Color(0.32,0.28,0.22)),P.call(sx*(hw+0.03),0.9,9.0),Vector3(8.6,0.7,0.02),sb,0.0)
			for q in 2:L.box(T(Color(0.58,0.52,0.44)),P.call(sx*(hw+0.04),rng.randf_range(1.8,4.6),rng.randf_range(5.5,12.5)),Vector3(rng.randf_range(0.4,1.1),rng.randf_range(0.3,0.7),0.02),sb,0.0)
			if rng.randf()<0.55:graffiti(P.call(sx*(hw+0.06),rng.randf_range(1.9,2.8),rng.randf_range(6.5,11.5)),rechts*sx,rng.randf_range(0.6,0.85))
		if rng.randf()<0.5:L._sofa(P.call(-hw*0.5,0.69,4.5-1.0),yaw)
		if rng.randf()<0.35:L._sofa(P.call(rng.randf_range(-2,2),kb*0.0,2.6),yaw+rng.randf_range(-0.6,0.6))
		for q in rng.randi_range(0,2):muellsack(P.call(rng.randf_range(-hw*0.8,hw*0.8),0.0,rng.randf_range(1.2,3.2)))
		if rng.randf()<0.3:reifen(P.call(hw*0.7,0.0,2.8),rng.randi_range(1,3))
	else:
		# leeres Grundstück: Blechhütte, Schrott
		L.box(T(Color(0.42,0.33,0.22)),Vector3(xm,kb+0.02,(zf+zb)*0.5),Vector3(w-0.4,0.02,tief-1.0),Basis(),0.0)
		var hc=P.call(rng.randf_range(-1,1),0.0,rng.randf_range(6,9));var hy=yaw+rng.randf_range(-0.25,0.25)
		huette(hc,rng.randf_range(4,5.2),rng.randf_range(3.4,4.2),2.4,hy,[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4),Color(0.45,0.55,0.6)][rng.randi()%3])
		reifen(P.call(2.5,0.0,2.4),rng.randi_range(2,4));reifen(P.call(-2.8,0.0,3.2),2)
		L._sofa(P.call(-2.0,0.0,3.6),yaw+0.4)
	# Zaun vorn
	var za=Vector3(xa,kb,zf+sd*0.15);var ze=Vector3(xb,kb,zf+sd*0.15)
	if rng.randf()<0.5:
		L._zaun(za+Vector3(0.1,0,0),ze-Vector3(0.1,0,0),1.3)
	else:
		holzzaun(za,ze,1.2,[Color(0.62,0.5,0.36),Color(0.8,0.78,0.72),Color(0.5,0.42,0.34)][rng.randi()%3],0.28)
		if rng.randf()<0.6:graffiti((za+ze)*0.5+Vector3(rng.randf_range(-2,2),0.62,0)+aussen*0.04,aussen,0.45)
	L.koll_box((za+ze)*0.5+Vector3(0,0.65,0),Vector3(w,1.3,0.12))
	# Hinterhof
	var hof=P.call(rng.randf_range(-1.5,1.5),0.0,tief-9.5)
	var hofart=rng.randf()
	if hofart<0.25:
		auto_wrack(hof,yaw+PI*0.5+rng.randf_range(-0.3,0.3))
	elif hofart<0.5:
		L.zyl(L.M.metall,hof-rechts*3.0,hof-rechts*3.0+Vector3(0,2.0,0),0.04,1.2);L.zyl(L.M.metall,hof+rechts*3.0,hof+rechts*3.0+Vector3(0,2.0,0),0.04,1.2)
		L.zyl(L.M.linie,hof-rechts*3.0+Vector3(0,1.9,0),hof+rechts*3.0+Vector3(0,1.9,0),0.01,1.0)
		for q in 5:L.box(T(SPRAY[rng.randi()%SPRAY.size()]),hof+rechts*(-2.4+q*1.2)+Vector3(0,1.55,0),Vector3(0.8,0.7,0.03),Y(yaw),0.012)
	elif hofart<0.65:
		L.zyl(T(Color(0.3,0.6,0.9)),hof,hof+Vector3(0,0.5,0),1.4,1.05);L.zyl(T(Color(0.45,0.7,0.6)),hof+Vector3(0,0.42,0),hof+Vector3(0,0.46,0),1.3)
	else:
		for q in 3:muellsack(hof+rechts*rng.randf_range(-2,2)-aussen*rng.randf_range(-1,1))
		if rng.randf()<0.5:L._container(hof+rechts*2.0,yaw,Color(0.2,0.3,0.25))
	# hinten zur Gasse: Garage oder Blechschuppen, Rest Bretterzaun mit Tags
	var gb=P.call(0,0.0,tief-3.35)
	if rng.randf()<0.7:garage(gb,yaw+PI)
	else:huette(gb+aussen*0.3,4.0,3.4,2.3,yaw+PI,[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4)][rng.randi()%2])
	var zb2=zb-sd*0.2
	for seg in [[xa,xm-2.1],[xm+2.1,xb]]:
		if seg[1]-seg[0]<0.5:continue
		var a0=Vector3(seg[0],kb,zb2);var a1=Vector3(seg[1],kb,zb2)
		holzzaun(a0,a1,2.0,[Color(0.55,0.45,0.33),Color(0.45,0.4,0.35),Color(0.6,0.55,0.48)][rng.randi()%3],0.06)
		L.koll_box((a0+a1)*0.5+Vector3(0,1.0,0),Vector3(seg[1]-seg[0],2.0,0.12))
		if seg[1]-seg[0]>2.4 and rng.randf()<0.7:graffiti((a0+a1)*0.5+Vector3(0,1.05,sd*0.06),Vector3(0,0,sd),rng.randf_range(0.5,0.7))
	# Seitenzaun links (zum Nachbarn/zur Einfahrt), hoch
	var s0=Vector3(xa,kb,zf+sd*0.3);var s1=Vector3(xa,kb,zb2-sd*0.3)
	holzzaun(s0,s1,1.8,Color(0.55,0.45,0.33),0.12)
	L.koll_box((s0+s1)*0.5+Vector3(0,0.9,0),Vector3(0.12,1.8,abs(s1.z-s0.z)))

func einfahrt(i:int,sd:int,xa:float,xb:float):
	var xm=(xa+xb)*0.5;var zf=front_z(i,sd,xm);var zb=back_z(i,sd,xm)
	L.box(T(Color(0.42,0.4,0.37)),Vector3(xm,L.KB+0.014,(zf+zb)*0.5),Vector3(xb-xa,0.02,abs(zb-zf)),Basis(),0.0)
	if rng.randf()<0.25:
		L._park(Transform3D(Y(0.0 if sd>0 else PI)*Basis(),Vector3(xm,L.KB+0.02,zf+sd*5.5)),["c_wartburg","c_muscle","c_e30","c_luxus","c_trabant"][rng.randi()%5])

# Rand: Nordseite der ersten Straße (Lärmschutzmauer zur Autobahn) und Südseite der letzten (Schrottplatz)
func randreihe(i:int,sd:int,j:int):
	var xa=nx(j,ZS[i])+W_STR+SW+0.5;var xb=nx(j+1,ZS[i])-W_STR-SW-0.5
	var zf=front_z(i,sd,(xa+xb)*0.5)+sd*0.4
	if sd==-1:
		var x=xa
		while x<xb-0.5:
			var lg=min(8.0,xb-x);var c=Vector3(x+lg*0.5,L.KB,ez(i,x+lg*0.5)+sd*(W_STR+SW+0.4))
			L.box(L.M.mauer,c+Vector3(0,1.6,0),Vector3(lg,3.2,0.5),Basis(),0.04)
			L.box(L.M.stein,c+Vector3(0,3.28,0),Vector3(lg,0.16,0.7),Basis(),0.0)
			L.koll_box(c+Vector3(0,1.6,0),Vector3(lg,3.2,0.5))
			if rng.randf()<0.85:graffiti(c+Vector3(rng.randf_range(-1.5,1.5),1.5,0.27),Vector3(0,0,1),rng.randf_range(0.8,1.1))
			x+=lg
		# hinter der Mauer: Gras bis zur Viertelgrenze
		L.box(T(Color(0.47,0.5,0.28)),Vector3((xa+xb)*0.5,L.KB+0.012,(Z0+zf)*0.5-0.5),Vector3(xb-xa,0.02,abs(zf-Z0)-1.0),Basis(),0.0)
	else:
		# Schrottplatz hinter Maschendraht
		L._zaun(Vector3(xa,L.KB,zf),Vector3(xb,L.KB,zf),2.4)
		L.koll_box(Vector3((xa+xb)*0.5,L.KB+1.2,zf),Vector3(xb-xa,2.4,0.12))
		L.box(T(Color(0.42,0.34,0.24)),Vector3((xa+xb)*0.5,L.KB+0.012,(zf+Z1)*0.5),Vector3(xb-xa,0.02,abs(Z1-zf)-0.5),Basis(),0.0)
		var x=xa+5.0
		while x<xb-5.0:
			var c=Vector3(x,L.KB,zf+rng.randf_range(5,12))
			if rng.randf()<0.35:auto_wrack(c,rng.randf()*TAU)
			elif rng.randf()<0.5:reifen(c,rng.randi_range(2,5))
			else:huette(c,rng.randf_range(4,6),3.5,2.5,rng.randf_range(-0.3,0.3)+PI,[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4)][rng.randi()%2])
			x+=rng.randf_range(9,15)

func randwand_ns(j:int,sx:int):
	# äußere Seite der Randstraßen: Maschendraht, dahinter Brache
	var x=nx(j,Z0)+sx*(W_STR+SW+0.4)
	L._zaun(Vector3(x,L.KB,ZS[0]+8),Vector3(x,L.KB,ZS[ZS.size()-1]-8),2.0)
	L.koll_box(Vector3(x,L.KB+1.0,(ZS[0]+ZS[ZS.size()-1])*0.5),Vector3(0.12,2.0,ZS[ZS.size()-1]-ZS[0]-16))

# Ecke einer Kreuzung (Ost-West-Straße i, Nord-Süd-Straße j), Quadrant (sx,sd): Laden oder Brache
func ecke(i:int,j:int,sx:int,sd:int):
	var xns=nx(j,ZS[i]);var x_in=xns+sx*(W_STR+SW+0.3);var x_out=xns+sx*15.5
	var hat_gasse=(sd==1 and i<ZS.size()-1) or (sd==-1 and i>0)
	var zf=front_z(i,sd,(x_in+x_out)*0.5);var zb=back_z(i,sd,(x_in+x_out)*0.5) if hat_gasse else zf+sd*12.0
	var xa=min(x_in,x_out);var xb=max(x_in,x_out);var xm=(xa+xb)*0.5;var w=xb-xa
	var zm=(zf+zb)*0.5;var tief=abs(zb-zf)
	L.box(T(Color(0.45,0.44,0.4)),Vector3(xm,L.KB+0.012,zm),Vector3(w,0.02,tief),Basis(),0.0)
	var aussen=Vector3(0,0,-sd);var yaw=atan2(aussen.x,aussen.z)
	if rng.randf()<0.6:
		# Eckladen, Front zur Ost-West-Straße
		var lw=w-0.6;var ld=min(11.0,tief-1.0);var c=Vector3(xm,L.KB,zf+sd*(ld*0.5+0.2))
		var wand=L.M.ziegel[rng.randi()%L.M.ziegel.size()] if rng.randf()<0.6 else L.M.putz[rng.randi()%L.M.putz.size()]
		var b=Y(yaw);var H=4.2
		L.box(wand,c+Vector3(0,H*0.5,0),Vector3(lw,H,ld),b,0.05)
		L.box(L.M.stein_d,c+Vector3(0,H+0.2,0),Vector3(lw+0.3,0.4,ld+0.3),b,0.04)
		L.koll_box(c+Vector3(0,H*0.5,0),Vector3(lw,H,ld),b)
		var f=c+aussen*(ld*0.5)
		L.box(L.M.glas[2],f+Vector3(0,1.6,0)+aussen*0.03,Vector3(lw-3.0,2.0,0.05),b,0.0)
		var x=-(lw-3.0)*0.5
		while x<(lw-3.0)*0.5:L.box(L.M.metall,f+Basis(Vector3.UP,yaw)*Vector3(x,1.6,0.08),Vector3(0.05,2.0,0.05),b,0.0);x+=0.3
		L.box(L.M.dunkel,f+Basis(Vector3.UP,yaw)*Vector3((lw-1.6)*0.5*(-sx*sd),1.15,0.03),Vector3(1.1,2.3,0.05),b,0.0)
		var namen=["SPÄTI","LIQUOR","PFANDLEIHE","WASCHSALON","HAARSTUDIO","KIOSK","DÖNER","WETTEN","HANDY-REPARATUR","24/7"]
		var schild=T([Color(0.85,0.15,0.12),Color(0.15,0.3,0.6),Color(0.95,0.75,0.1),Color(0.1,0.1,0.12)][rng.randi()%4])
		L.box(schild,f+Vector3(0,3.35,0)+aussen*0.15,Vector3(lw-0.8,0.9,0.2),b,0.03)
		label(namen[rng.randi()%namen.size()],f+Vector3(0,3.35,0)+aussen*0.27,b,0.0085,Color(1,1,0.92),Color(0.05,0.05,0.05))
		# Seitenwand zur Querstraße: großes Graffiti
		var seite=Vector3(sx,0,0)*-1.0 if false else Vector3(-sx,0,0)
		graffiti(c+seite*(lw*0.5+0.06)+Vector3(0,2.0,0),seite,1.1)
		muellsack(c+seite*(lw*0.5+0.8)+aussen*2.0)
		L._container(c+seite*(lw*0.5+1.2)-aussen*2.0,yaw,Color(0.2,0.3,0.25))
	else:
		# Brache mit Maschendraht, Reifen, Matratze
		L.box(T(Color(0.42,0.33,0.22)),Vector3(xm,L.KB+0.02,zm),Vector3(w-0.6,0.02,tief-0.6),Basis(),0.0)
		var e=[Vector3(xa+0.3,L.KB,zf+sd*0.3),Vector3(xb-0.3,L.KB,zf+sd*0.3),Vector3(xb-0.3,L.KB,zb-sd*0.3),Vector3(xa+0.3,L.KB,zb-sd*0.3)]
		for k in 4:
			if k==1 and sx==-1:continue
			if k==3 and sx==1:continue
			L._zaun(e[k],e[(k+1)%4],2.0)
			var mm=(e[k]+e[(k+1)%4])*0.5;var dd=e[(k+1)%4]-e[k]
			L.koll_box(mm+Vector3(0,1.0,0),Vector3(max(abs(dd.x),0.12),2.0,max(abs(dd.z),0.12)))
		reifen(Vector3(xm+rng.randf_range(-3,3),L.KB,zm),rng.randi_range(2,4))
		L.box(T(Color(0.85,0.82,0.72)),Vector3(xm+2,L.KB+0.12,zm+2),Vector3(1.9,0.22,1.4),Y(rng.randf()),0.02)
		for q in 3:muellsack(Vector3(xm+rng.randf_range(-4,4),L.KB,zm+rng.randf_range(-4,4)))

func strommasten():
	for i in ZS.size():
		var prev=null;var x=XS[0]+8.0
		var sdm=-1 if i%2==0 else 1
		while x<XS[XS.size()-1]-6.0:
			var naehe=false
			for j in XS.size():
				if abs(x-nx(j,ZS[i]))<9.0:naehe=true
			if not naehe:
				var top=mast(Vector3(x,L.KB,ez(i,x)+sdm*(W_STR+0.6)))
				if prev!=null and top.distance_to(prev)<40.0:kabel(prev,top,0.9);kabel(prev+Vector3(0,0,0.7*sdm),top+Vector3(0,0,0.7*sdm),1.1)
				prev=top
			else:prev=null
			x+=30.0

func parken():
	for r in EW+NS:
		var Ls=r.S[r.S.size()-1];var s=rng.randf_range(4,10)
		while s<Ls-4:
			var b=L._bei_s(r.P,r.S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=L._rn(t)
			s+=rng.randf_range(6.0,8.0)
			if L._nah_kreuzung(p,14.0):continue
			for sd in [-1,1]:
				if rng.randf()>0.13:continue
				var h=t*(-sd);var c=p+rn*sd*(r.w-1.15)
				if not L._park_frei(c):continue
				L._park(Transform3D(Basis(Vector3.UP,atan2(h.x,h.y)),Vector3(c.x,0.015,c.y)),["c_wartburg","c_muscle","c_e30","c_luxus","c_trabant","c_trabant","c_kompakt","c_suv"][rng.randi()%8])

# Laden mit Front an P(0,0,0), Breite lw, Tiefe ld (für den Bezirks-Generator)
func ecke_bau(P:Callable,lw:float,ld:float,aussen:Vector3,yaw:float):
	var c=P.call(0,0,ld*0.5)
	var wand=L.M.ziegel[rng.randi()%L.M.ziegel.size()] if rng.randf()<0.6 else L.M.putz[rng.randi()%L.M.putz.size()]
	var b=Y(yaw);var H=4.4
	L.box(wand,c+Vector3(0,H*0.5,0),Vector3(lw-0.6,H,ld),b,0.05)
	L.box(L.M.stein_d,c+Vector3(0,H+0.2,0),Vector3(lw-0.3,0.4,ld+0.3),b,0.04)
	L.koll_box(c+Vector3(0,H*0.5,0),Vector3(lw-0.6,H,ld),b)
	var f=P.call(0,0,0)
	L.box(L.M.glas[2],f+Vector3(0,1.6,0)+aussen*0.03,Vector3(lw-4.0,2.0,0.05),b,0.0)
	var x=-(lw-4.0)*0.5
	while x<(lw-4.0)*0.5:L.box(L.M.metall,f+b*Vector3(x,1.6,0.08),Vector3(0.05,2.0,0.05),b,0.0);x+=0.3
	L.box(L.M.dunkel,f+b*Vector3((lw-2.2)*0.5,1.15,0.03),Vector3(1.1,2.3,0.05),b,0.0)
	var namen=["SPÄTI","LIQUOR","PFANDLEIHE","WASCHSALON","HAARSTUDIO","KIOSK","DÖNER","WETTEN","HANDY-REPARATUR","24/7","CHICKEN","SCHECKS EINLÖSEN"]
	var schild=T([Color(0.85,0.15,0.12),Color(0.15,0.3,0.6),Color(0.95,0.75,0.1),Color(0.1,0.1,0.12)][rng.randi()%4])
	L.box(schild,f+Vector3(0,3.5,0)+aussen*0.15,Vector3(lw-1.2,0.9,0.2),b,0.03)
	label(namen[rng.randi()%namen.size()],f+Vector3(0,3.5,0)+aussen*0.27,b,0.0085,Color(1,1,0.92),Color(0.05,0.05,0.05))
	var seite=b*Vector3(1,0,0)
	graffiti(c+seite*((lw-0.6)*0.5+0.06)+Vector3(0,2.0,0),seite,1.0)
	muellsack(c+seite*((lw-0.6)*0.5+0.8)+aussen*2.0)

# ---------- Bausteine ----------
# Fahrbahn als Viereckstreifen entlang der Linie (wenige Dreiecke, mit Kollision)
func streifen(P:PackedVector2Array,w:float):
	var alt=L.koll_an;L.koll_an=true
	var so=L._st(L.M.asphalt,true)
	# Enden um eine Fahrbahnbreite verlängern (deckt Eck- und Einmündungsflächen ab)
	P=P.duplicate()
	if P.size()>=2:
		P.insert(0,P[0]+(P[0]-P[1]).normalized()*w);P.append(P[P.size()-1]+(P[P.size()-1]-P[P.size()-2]).normalized()*w)
	var n=P.size()
	var Ls=[];var Rs=[]
	for i in n:
		var d:Vector2=(P[min(i+1,n-1)]-P[max(i-1,0)]).normalized();var nn=Vector2(-d.y,d.x)
		Ls.append(P[i]+nn*w);Rs.append(P[i]-nn*w)
	for i in n-1:
		var a=Vector3(Ls[i].x,0.015,Ls[i].y);var b=Vector3(Ls[i+1].x,0.015,Ls[i+1].y);var c=Vector3(Rs[i+1].x,0.015,Rs[i+1].y);var e=Vector3(Rs[i].x,0.015,Rs[i].y)
		L._tri(so,a,b,c,Vector3.UP);L._tri(so,a,c,e,Vector3.UP)
	L.koll_an=alt
func label(text:String,pos:Vector3,b:Basis,px:float,farbe:Color,umriss:Color,maxb:=0.0):
	# maxb: größte Breite in m (Schild/Tafel) – Schrift wird verkleinert, damit sie nicht übersteht
	if maxb>0.0:
		var f=ThemeDB.fallback_font;var w=0.0
		for z in text.split("\n"):w=max(w,f.get_string_size(z,HORIZONTAL_ALIGNMENT_LEFT,-1,96).x)
		w+=24.0
		if w*px>maxb:px=maxb/w
	var lb=Label3D.new();lb.text=text;lb.font_size=96;lb.pixel_size=px;lb.modulate=farbe;lb.shaded=false;lb.double_sided=false
	lb.outline_size=12;lb.outline_modulate=umriss
	lb.visibility_range_end=55.0;lb.visibility_range_end_margin=10.0
	lb.transform=Transform3D(b,pos);L.welt.add_child(lb)
func graffiti(c:Vector3,aussen:Vector3,gr:=1.0):
	var r=Vector3.UP.cross(aussen).normalized();var b=Basis(r,Vector3.UP,aussen)
	var f1=SPRAY[rng.randi()%SPRAY.size()];var f2=SPRAY[rng.randi()%SPRAY.size()]
	var tag:String=TAGS[rng.randi()%TAGS.size()]
	var breite=gr*(0.55*tag.length()+0.6)
	L.mesh(T(f2),L.SPH,Transform3D(b*Basis().scaled(Vector3(breite,gr*1.25,0.03)),c+aussen*0.02),1.0)
	for k in 2:
		var q=c+r*rng.randf_range(-breite*0.4,breite*0.4)+Vector3(0,gr*rng.randf_range(-0.4,0.4),0)
		L.mesh(T(SPRAY[rng.randi()%SPRAY.size()]),L.SPH,Transform3D(b*Basis().scaled(Vector3(gr*0.5,gr*0.45,0.03)),q+aussen*0.025),1.0)
	L.box(T(f2),c+r*rng.randf_range(-breite*0.3,breite*0.3)-Vector3(0,gr*0.6,0)+aussen*0.03,Vector3(0.05,gr*rng.randf_range(0.3,0.7),0.01),b,0.0)
	if gr>=0.6 and not ohne_tags:label(tag,c+aussen*0.06,b,gr*0.0105,f1,Color(0.06,0.04,0.05))
func wellblech(c:Vector3,w:float,h:float,yaw:float,col:Color):
	var b=Y(yaw);L.box(T(col),c+Vector3(0,h*0.5,0),Vector3(w,h,0.06),b,0.03)
	var dk=T(col*0.72);var x=-w*0.5+0.15
	while x<w*0.5:L.box(dk,c+b*Vector3(x,h*0.5,0.05),Vector3(0.08,h,0.04),b,0.0);x+=0.32
	if rng.randf()<0.6:L.box(T(Color(0.55,0.3,0.16)),c+b*Vector3(rng.randf_range(-w*0.3,w*0.3),h*0.3,0.08),Vector3(rng.randf_range(0.6,1.4),h*0.5,0.02),b,0.0)
func huette(c:Vector3,w:float,d:float,h:float,yaw:float,col:Color):
	var b=Y(yaw);var dirs=[Vector3(0,0,1),Vector3(1,0,0),Vector3(0,0,-1),Vector3(-1,0,0)]
	for k in 4:
		var dir=b*dirs[k];var br=w if k%2==0 else d;var ti=d if k%2==0 else w
		wellblech(c+dir*(ti*0.5),br,h,atan2(dir.x,dir.z),col if k!=1 else col*Color(0.85,0.75,0.7))
	L.box(T(Color(0.52,0.33,0.22)),c+Vector3(0,h+0.15,0),Vector3(w+0.7,0.1,d+0.7),b*Basis(Vector3(1,0,0),0.12),0.03)
	L.box(L.M.dunkel,c+b*Vector3(0,1.0,d*0.5+0.07),Vector3(0.9,2.0,0.05),b,0.0)
	L.koll_box(c+Vector3(0,h*0.5,0),Vector3(w,h,d),b)
func holzzaun(a:Vector3,e:Vector3,h:float,col:Color,kaputt:=0.15):
	var d=e-a;var Lg=d.length();if Lg<0.2:return
	var t=d/Lg;var b=Basis(t,Vector3.UP,t.cross(Vector3.UP))
	var m=T(col);var m2=T(col*0.8);var k=0.1
	L.box(m2,(a+e)*0.5+Vector3(0,h*0.7,0),Vector3(Lg,0.1,0.06),b,0.02)
	while k<Lg:
		if rng.randf()>kaputt:
			var hh=h*rng.randf_range(0.85,1.0);var kipp=rng.randf_range(-0.12,0.12) if rng.randf()<0.3 else 0.0
			L.box(m if rng.randf()<0.7 else m2,a+t*k+Vector3(0,hh*0.5,0),Vector3(0.16,hh,0.035),b*Basis(Vector3(0,0,1),kipp),0.015)
		k+=0.22
func garage(c:Vector3,yaw:float):
	var b=Y(yaw);var wand=L.M.ziegel[rng.randi()%L.M.ziegel.size()] if rng.randf()<0.5 else T(Color(0.7,0.68,0.62))
	L.box(wand,c+Vector3(0,1.4,0),Vector3(3.6,2.8,6.0),b,0.04)
	L.koll_box(c+Vector3(0,1.4,0),Vector3(3.6,2.8,6.0),b)
	L.box(T(Color(0.32,0.3,0.3)),c+b*Vector3(0,2.88,0),Vector3(3.9,0.16,6.3),b*Basis(Vector3(1,0,0),-0.04),0.03)
	var tor=T([Color(0.55,0.58,0.6),Color(0.45,0.55,0.4),Color(0.6,0.45,0.3)][rng.randi()%3])
	var offen=rng.randf()<0.3
	L.box(L.M.dunkel,c+b*Vector3(0,1.15,3.01),Vector3(2.8,2.3,0.04),b,0.0)
	var torh=0.9 if offen else 2.3
	L.box(tor,c+b*Vector3(0,2.3-torh*0.5,3.03),Vector3(2.8,torh,0.06),b*Basis(Vector3(0,0,1),rng.randf_range(-0.05,0.05)),0.02)
	var y=2.1
	while y>2.3-torh+0.1:L.box(T(tor.albedo_color*0.75),c+b*Vector3(0,y,3.07),Vector3(2.75,0.04,0.03),b,0.0);y-=0.23
	L.box(T(Color(0.5,0.28,0.15)),c+b*Vector3(-0.6,0.5,3.08),Vector3(1.2,0.7,0.02),b,0.0)
	if rng.randf()<0.75:graffiti(c+b*Vector3(rng.randf_range(-0.4,0.4),1.45,3.1),b*Vector3(0,0,1),0.62)
	if offen:
		for k in 3:L.kugel(L.M.dunkel,c+b*Vector3(rng.randf_range(-1,1),0.3,rng.randf_range(0,2)),Vector3(0.35,0.3,0.35))
func reifen(p:Vector3,n:=3):
	for k in n:L.zyl(L.M.reifen,p+Vector3(0,k*0.24,0),p+Vector3(0,k*0.24+0.22,0),0.36,1.1)
func muellsack(p:Vector3):L.kugel(T(Color(0.12,0.12,0.14)),p+Vector3(0,0.3,0),Vector3(0.38,0.32,0.36))
func mast(p:Vector3)->Vector3:
	var hm=T(Color(0.38,0.28,0.2))
	L.zyl(hm,p,p+Vector3(0,8.5,0),0.14,1.2)
	L.box(hm,p+Vector3(0,8.0,0),Vector3(0.12,0.12,1.8),Basis(),0.02)
	L.zyl(T(Color(0.4,0.42,0.45)),p+Vector3(0.2,6.8,0),p+Vector3(0.2,7.6,0),0.25,1.1)
	L.PFOSTEN.append([p,0.16,8.5])
	return p+Vector3(0,8.0,0)
func kabel(a:Vector3,e:Vector3,durch:=0.9):
	var n=5;var prev=a
	for k in range(1,n+1):
		var t=float(k)/n;var q=a.lerp(e,t)-Vector3(0,durch*4.0*t*(1.0-t),0)
		L.zyl(L.M.linie,prev,q,0.02,1.0);prev=q
# Wrack: echte Karosserie ohne Räder, aufgebockt auf Steinen, ausgeblichener/rostiger Lack
func auto_wrack(p:Vector3,yaw:float):
	var art=["_wartburg","_e30","_muscle","_kompakt"][rng.randi()%4]
	var lack=[Color(0.55,0.42,0.32),Color(0.42,0.46,0.5),Color(0.5,0.5,0.38),Color(0.36,0.3,0.26),Color(0.6,0.55,0.45)][rng.randi()%5]
	var b=Y(yaw);var TT=Transform3D(b,p+Vector3(0,0.28,0))
	var alt=[L.rad_capture,L.rad_weg];L.rad_capture=true;L.rad_weg=true
	if art=="_wartburg":L._wartburg(TT,lack)
	else:L.call(art,TT,lack,{})
	L.rad_capture=alt[0];L.rad_weg=alt[1]
	for z in [-1.35,1.35]:
		for x in [-0.6,0.6]:
			L.box(L.M.stein_d,p+b*Vector3(x,0.2,z),Vector3(0.38,0.4,0.38),b,0.02)
	if rng.randf()<0.6:
		var rz=rng.randf_range(-1,1);L.zyl(L.M.reifen,p+b*Vector3(1.5,0,rz),p+b*Vector3(1.5,0.24,rz),0.33,1.1)
	L.koll_box(p+b*Vector3(0,0.8,0),Vector3(1.8,1.6,4.2),b)
func _rost()->StandardMaterial3D:return T(Color(0.5,0.27,0.14))
