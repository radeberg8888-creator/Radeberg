extends Node3D
# Die Insel Radeberg – offene Welt im Geist von San Andreas (eigene Karte, keine Originalinhalte):
#  NW: Berg mit Nadelwald und Serpentinenstraße     NO: Hügel-Vorort mit Villen
#  Mitte: Downtown (Hochhäuser, gedrehtes Raster)   dazwischen: Altstadt mit Backstein-Mietshäusern
#  Süd: Ghetto in einer Senke (heruntergekommene Häuser, Gangviertel)
#  Ost: Hauptbahnhof, Güterbahnhof, Industrie, Containerhafen
#  SW: Wüste mit verlassenem Flugplatz (Landebahn, Hangars, Tower)
#  Autobahnring um die Insel mit Kurven, Tunnel, Viadukt, Auf-/Abfahrten; rundherum Meer.
const GEL=preload("res://scripts/welt_gelaende.gd")
const STR=preload("res://scripts/welt_strassen.gd")
const BAU=preload("res://scripts/welt_bauten.gd")
const ANL=preload("res://scripts/welt_anlagen.gd")
const LEB=preload("res://scripts/welt_leben.gd")
var LV
var A
var B
const F=preload("res://scripts/fit.gd")
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
var G
var S
var args:=[]
var named:={}
var rng:=RandomNumberGenerator.new()
const D:=Vector2(250,-350)    # Downtown-Mitte
const DA:=0.3                 # Drehung des Downtown-Rasters

func gpt(u:float,v:float)->Vector2:
	return D+Vector2(u*cos(DA)-v*sin(DA),u*sin(DA)+v*cos(DA))
func v3(p:Vector2,y:=0.0)->Vector3:return Vector3(p.x,y,p.y)

func layout():
	# ebene Flächen für Bahnanlagen, Flughafen, Militär, Docks, Hafen
	for z in [-150.0,0.0,150.0,300.0,450.0,600.0,750.0]:G.plateaus.append([Vector2(705,z),95.0,90.0,G._nat(705,300)])
	for k in 5:G.plateaus.append([Vector2(-2850+k*400.0,2175),330.0,120.0,4.0])
	G.plateaus.append([Vector2(-1800,1650),300.0,120.0,4.0])
	var mi=G.MILITAER
	for k in 4:G.plateaus.append([mi+Vector2(-600+k*400.0,80),300.0,120.0,G._nat(mi.x,mi.y)])
	for k in 6:G.plateaus.append([Vector2(-600+k*400.0,2030),280.0,90.0,3.0])
	G.plateaus.append([Vector2(1330,330),110.0,60.0,3.0])
	for z in [430.0,550.0,670.0,790.0]:G.plateaus.append([Vector2(1620,z),120.0,50.0,2.9])
	autobahnen()          # zuerst: die Reihenfolge bestimmt, welche Autobahn oben liegt
	innenstadt()
	sternviertel()
	sonnenhuegel()
	hauptstrassen()       # Alleen als Gerüst der Viertel
	strandviertel()
	suedstadt()
	oststadt()
	flughafen_strassen()
	stadtviertel()        # organische Viertel füllen die Lücken
	huegel()
	sackgassen_verbinden()
	abfahrten()
	land()
	nordbucht()
	staubwinkel()
	sandufer()
	kornfeld()
	fischerdorf()
	gefaengnis_strassen()
	militaer_strassen()

func bogen(c:Vector2,r:float,a0:float,a1:float,n:int,y:=0.0)->Array:
	var out=[]
	for k in n+1:
		var a=lerp(a0,a1,float(k)/n);out.append(Vector3(c.x+cos(a)*r,y,c.y+sin(a)*r))
	return out

# ---------------- Innenstadt, Altstadt, Ghetto, Osten, Hafen ----------------
func innenstadt():
	# Downtown: geschwungene Boulevards als Rahmen, das verzogene Raster dazwischen kommt in stadtviertel()
	named.blvd_nord=S.add("allee",[v3(gpt(-430,-380)),v3(gpt(-200,-405)),v3(gpt(60,-410)),v3(gpt(300,-395)),v3(gpt(440,-360))],{"wear":0.1,"name":"Boulevard Nord"})
	named.blvd_sued=S.add("allee",[v3(gpt(-440,380)),v3(gpt(-180,395)),v3(gpt(120,380)),v3(gpt(330,400)),v3(gpt(430,430))],{"wear":0.1,"name":"Boulevard Süd"})
	named.bogen=S.add("allee",[Vector3(-760,0,-560),v3(gpt(-400,-170)),v3(gpt(-180,-30)),v3(gpt(60,30)),v3(gpt(260,10)),v3(gpt(420,-90)),Vector3(870,0,-380)],{"wear":0.15,"name":"Bogenallee"})
	# Radeberger Allee: Ghetto -> Altstadt -> Downtown -> Norden
	var al=[Vector3(-250,0,560),Vector3(-200,0,400),Vector3(-70,0,190)]
	for e in [[0,390],[-35,200],[-10,40],[40,-130],[20,-270],[0,-390]]:al.append(v3(gpt(e[0],e[1])))
	al.append(Vector3(390,0,-860));al.append(Vector3(330,0,-1000))
	named.allee=S.add("allee",al,{"name":"Radeberger Allee","wear":0.15})
	# Ghetto (Senke im Süden): krumme Straßen, Gassen, Hinterhöfe
	named.ghetto=S.add("strasse",[Vector3(-660,0,430),Vector3(-450,0,500),Vector3(-250,0,560),Vector3(-100,0,650),Vector3(30,0,770),Vector3(120,0,900)],{"name":"Grove","wear":0.85})
	S.add("strasse",[Vector3(-480,0,330),Vector3(-440,0,520),Vector3(-380,0,720),Vector3(-410,0,890),Vector3(-430,0,1060),Vector3(-420,0,1140)],{"wear":0.8})
	S.add("gasse",[Vector3(-100,0,650),Vector3(-150,0,800),Vector3(-270,0,900)],{"wear":0.9})
	S.add("strasse",[Vector3(-380,0,720),Vector3(-220,0,745),Vector3(-62,0,688)],{"wear":0.85})
	S.add("gasse",[Vector3(-440,0,520),Vector3(-600,0,610),Vector3(-700,0,720)],{"wear":0.9})
	S.add("gasse",[Vector3(-250,0,560),Vector3(-300,0,660),Vector3(-380,0,720)],{"wear":0.9})
	S.add("gasse",[Vector3(-560,0,780),Vector3(-420,0,800),Vector3(-270,0,900)],{"wear":0.9})
	S.add("gasse",[Vector3(-600,0,610),Vector3(-560,0,780),Vector3(-500,0,940)],{"wear":0.9})
	S.add("strasse",[Vector3(-500,0,940),Vector3(-300,0,960),Vector3(-120,0,1000),Vector3(60,0,960),Vector3(120,0,900),Vector3(240,0,1010),Vector3(300,0,1130)],{"name":"Kanalstraße","wear":0.9})
	S.add("gasse",[Vector3(-270,0,900),Vector3(-300,0,960)],{"wear":0.9})
	S.add("gasse",[Vector3(-150,0,800),Vector3(-120,0,1000),Vector3(-110,0,1140)],{"wear":0.9})
	S.add("gasse",[Vector3(-700,0,720),Vector3(-760,0,880),Vector3(-650,0,1000),Vector3(-500,0,940)],{"wear":0.95})
	S.add("strasse",[Vector3(-660,0,430),Vector3(-860,0,500),Vector3(-1030,0,600)],{"wear":0.6})
	S.add("gasse",[Vector3(-760,0,880),Vector3(-900,0,950),Vector3(-1020,0,1000)],{"wear":0.9})
	# Altstadt
	S.add("strasse",[Vector3(-460,0,160),Vector3(-260,0,190),Vector3(-90,0,150),Vector3(120,0,90),Vector3(380,0,120),Vector3(600,0,170)],{"wear":0.4})
	S.add("gasse",[Vector3(-360,0,300),Vector3(-220,0,330),Vector3(-120,0,265)],{"wear":0.5})
	S.add("strasse",[v3(gpt(330,0)),Vector3(560,0,-140),Vector3(600,0,60),Vector3(600,0,170)],{"wear":0.2})
	S.add("strasse",[Vector3(-640,0,-160),Vector3(-450,0,-100),Vector3(-300,0,-120),Vector3(-150,0,-180),v3(gpt(-330,-130))],{"wear":0.4})
	S.add("gasse",[Vector3(-300,0,250),Vector3(-280,0,140),Vector3(-260,0,40)],{"wear":0.5})
	S.add("gasse",[Vector3(-200,0,400),Vector3(-120,0,250),Vector3(-60,0,180)],{"wear":0.5})
	S.add("strasse",[Vector3(-200,0,400),Vector3(-100,0,500),Vector3(-30,0,600),Vector3(30,0,770)],{"wear":0.8})
	named.weststr=S.add("allee",[Vector3(-460,0,160),Vector3(-640,0,-160),Vector3(-900,0,-350),Vector3(-1110,0,-420)],{"name":"Weststraße","wear":0.4})
	S.add("strasse",[Vector3(-460,0,160),Vector3(-700,0,220),Vector3(-950,0,200),Vector3(-1050,0,180)],{"wear":0.4})
	S.add("gasse",[Vector3(-700,0,220),Vector3(-660,0,430)],{"wear":0.5})
	# Ostviertel, Bahnhof, Hafen, Industrie
	S.add("strasse",[Vector3(560,0,-140),Vector3(800,0,-200),Vector3(1000,0,-250),Vector3(1180,0,-230)],{"wear":0.3})
	S.add("strasse",[Vector3(800,0,-200),Vector3(850,0,-50),Vector3(900,0,150),Vector3(900,0,330)],{"wear":0.3})
	S.add("gasse",[Vector3(1000,0,-250),Vector3(1020,0,-80),Vector3(900,0,150)],{"wear":0.4})
	named.hafen=S.add("strasse",[Vector3(600,0,170),Vector3(610,0,320),Vector3(900,0,330),Vector3(1150,0,300),Vector3(1340,0,320)],{"name":"Hafenstraße","wear":0.5})
	S.add("strasse",[Vector3(900,0,330),Vector3(880,0,600),Vector3(960,0,820)],{"wear":0.6})
	S.add("strasse",[Vector3(880,0,600),Vector3(1100,0,620),Vector3(1300,0,700)],{"wear":0.6})
	named.lager=S.add("strasse",[Vector3(960,0,820),Vector3(800,0,900),Vector3(560,0,920)],{"name":"Lagerweg","wear":0.7})
	# Ostvororte auf den Hügeln
	S.add("strasse",[v3(gpt(330,-390)),Vector3(650,0,-650),Vector3(780,0,-760),Vector3(820,0,-900),Vector3(700,0,-1010)],{"wear":0.1})
	S.add("strasse",[Vector3(650,0,-650),Vector3(560,0,-800),Vector3(620,0,-950),Vector3(700,0,-1010)],{"wear":0.1})
	S.add("strasse",[Vector3(780,0,-760),Vector3(950,0,-700),Vector3(1050,0,-800)],{"wear":0.1})
	S.add("strasse",[Vector3(820,0,-900),Vector3(950,0,-950),Vector3(1050,0,-800)],{"wear":0.1})
	# Bahnstrecke (Hauptbahnhof -> Norden)
	named.bahn=S.add("schiene",[Vector3(-950,0,800),Vector3(-650,0,900),Vector3(-200,0,975),Vector3(450,0,990),Vector3(680,0,800),Vector3(690,0,500),Vector3(690,0,300),
		Vector3(690,0,0),Vector3(690,0,-300),Vector3(640,0,-600),Vector3(560,0,-900),Vector3(560,0,-1400),Vector3(700,-20,-2000),Vector3(900,0,-2700),Vector3(1300,0,-3300),Vector3(1650,0,-3550)],{"name":"Bahn"})
	for x in [672.0,708.0,726.0]:
		var sx=1.0 if x>690 else -1.0
		S.add("schiene",[Vector3(690,0,-260),Vector3(690+sx*6,0,-170),Vector3(x,0,-100),Vector3(x,0,280),Vector3(690+sx*6,0,350),Vector3(690,0,420)])
	for k in 6:S.add("schiene",[Vector3(704+k*5.5,0,470),Vector3(704+k*5.5,0,760)])

# Gerüst: lange, leicht geschwungene Alleen zwischen den Vierteln (wie die Boulevards in Los Santos)
func hauptstrassen():
	named.nordallee=S.add("allee",[Vector3(-1480,0,-1130),Vector3(-1100,0,-1150),Vector3(-800,0,-1190),Vector3(-450,0,-1260),Vector3(-100,0,-1300),Vector3(250,0,-1305),
		Vector3(600,0,-1290),Vector3(1000,0,-1240),Vector3(1300,0,-1150)],{"name":"Nordallee","wear":0.15})
	named.westallee=S.add("allee",[Vector3(-1110,0,-1150),Vector3(-1120,0,-800),Vector3(-1110,0,-420),Vector3(-1070,0,-50),Vector3(-1050,0,180),Vector3(-1030,0,600),
		Vector3(-1020,0,1000),Vector3(-1060,0,1300),Vector3(-1150,0,1450)],{"name":"Westallee","wear":0.3})
	named.delperro=S.add("allee",[Vector3(-2270,0,-380),Vector3(-1950,0,-385),Vector3(-1700,0,-395),Vector3(-1450,0,-405),Vector3(-1110,0,-420)],{"name":"Del-Perro-Allee","wear":0.2})
	named.suedallee=S.add("allee",[Vector3(-1450,0,1160),Vector3(-1020,0,1140),Vector3(-700,0,1130),Vector3(-420,0,1140),Vector3(-110,0,1140),Vector3(300,0,1130),
		Vector3(700,0,1140),Vector3(1050,0,1150),Vector3(1350,0,1120)],{"name":"Südallee","wear":0.4})
	named.oststr=S.add("allee",[Vector3(2560,0,-180),Vector3(2620,0,250),Vector3(2660,0,700),Vector3(2690,0,1150),Vector3(2650,0,1600),Vector3(2580,0,1950)],{"name":"Oststraße","wear":0.3})
	S.add("allee",[Vector3(-2250,0,600),Vector3(-1950,0,650),Vector3(-1700,0,700),Vector3(-1450,0,720),Vector3(-1030,0,700)],{"name":"Vespucci-Allee","wear":0.3})

# Raster-Viertel (alt, wird nur noch für Sonderfälle genutzt)
func raster(c:Vector2,winkel:float,us:Array,vs:Array,opt:={}):
	var rot=func(u,v):return v3(c+Vector2(u*cos(winkel)-v*sin(winkel),u*sin(winkel)+v*cos(winkel)))
	for u in us:
		var pts=[];for v in vs:pts.append(rot.call(u,v))
		S.add(opt.get("typ","strasse"),pts,{"wear":opt.get("wear",0.3)})
	for v in vs:
		var pts=[];for u in us:pts.append(rot.call(u,v))
		S.add(opt.get("typ","strasse"),pts,{"wear":opt.get("wear",0.3)})

# ================= Organische Viertel =================
# Verzogenes (und wahlweise gebogenes) Straßenraster in einem Polygon. Knoten werden mit Rauschen verschoben,
# einzelne Kanten fallen weg (größere Blöcke, Sackgassen), manche Blöcke bekommen Diagonalen.
# hindernisse: [[Straße oder Punktliste, Abstand, anschließen]] – Linien enden dort bzw. werden an die Straße herangeführt.
var _vrng:=RandomNumberGenerator.new()
func _linie(o)->PackedVector2Array:
	var out=PackedVector2Array()
	var pts=o.ctrl if o is Dictionary else o
	for p in pts:out.append(Vector2(p.x,p.z) if p is Vector3 else p)
	return out
func _abst_linie(p:Vector2,L:PackedVector2Array)->Array:
	var bd=1e9;var bq=Vector2.ZERO
	for k in L.size()-1:
		var q=Geometry2D.get_closest_point_to_segment(p,L[k],L[k+1]);var d=p.distance_to(q)
		if d<bd:bd=d;bq=q
	return [bd,bq]
func _schnitt_poly(a:Vector2,b:Vector2,P:PackedVector2Array):
	var best=null;var bd=1e9
	for k in P.size():
		var r=Geometry2D.segment_intersects_segment(a,b,P[k],P[(k+1)%P.size()])
		if r!=null and a.distance_to(r)<bd:bd=a.distance_to(r);best=r
	return best

func viertel(poly:Array,opt:={})->Array:
	var P=PackedVector2Array(poly)
	var c=Vector2.ZERO
	for p in P:c+=p
	c/=P.size();c=opt.get("mitte",c)
	_vrng.seed=opt.get("seed",int(c.x*7.0+c.y*13.0))
	var w:float=opt.get("winkel",0.0);var du:float=opt.get("du",120.0);var dv:float=opt.get("dv",90.0)
	var warp:float=opt.get("warp",22.0);var rb:float=opt.get("bogen",0.0)
	var luecke:float=opt.get("luecken",0.1);var diag:float=opt.get("diagonal",0.05)
	var rand:float=opt.get("rand",18.0)
	var typ:String=opt.get("typ","strasse");var haupt:int=opt.get("haupt",4);var wear:float=opt.get("wear",0.3)
	var hind=[]
	for h in opt.get("hindernisse",[]):hind.append([_linie(h[0]),h[1],h[2]])
	var R=0.0
	for p in P:R=max(R,p.distance_to(c))
	var nu=int(R/du)+2;var nv=int(R/dv)+2
	var fn=FastNoiseLite.new();fn.seed=_vrng.randi();fn.frequency=opt.get("warp_freq",1.0/520.0)
	var cw=cos(w);var sw=sin(w)
	var pos={};var ok={}
	for i in range(-nu,nu+1):
		for j in range(-nv,nv+1):
			var u=i*du;var v=j*dv;var q:Vector2
			if rb!=0.0:q=Vector2((rb+v)*sin(u/rb),(rb+v)*cos(u/rb)-rb)
			else:q=Vector2(u,v)
			var p=c+Vector2(q.x*cw-q.y*sw,q.x*sw+q.y*cw)
			p+=Vector2(fn.get_noise_2d(p.x,p.y),fn.get_noise_2d(p.x+733.0,p.y-411.0))*warp
			var k=Vector2i(i,j);pos[k]=p
			var gut=Geometry2D.is_point_in_polygon(p,P)
			if gut:
				for e in P.size():
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,P[e],P[(e+1)%P.size()]))<rand:gut=false;break
			if gut:
				for h in hind:
					if _abst_linie(p,h[0])[0]<h[1]:gut=false;break
			if gut and G._nat(p.x,p.y)<1.0:gut=false
			ok[k]=gut
	var strassen=[]
	# Endpunkt eines Laufs: an das Hindernis heranführen (falls anschließbar) oder am Polygonrand enden
	var ende=func(a:Vector2,b:Vector2)->Variant:
		var best=null;var bd=1e9
		for h in hind:
			var r=_abst_linie(a,h[0])
			if r[0]<h[1]*2.2 and r[0]<bd:bd=r[0];best=r[1] if h[2] else a
		if best!=null:return best
		var s=_schnitt_poly(a,b,P)
		return s
	var emit=func(lauf:Array,ist_haupt:bool):
		if lauf.size()<2:return
		var L=0.0
		for k in lauf.size()-1:L+=lauf[k].distance_to(lauf[k+1])
		if L<45.0:return
		var pts=[];for q in lauf:pts.append(v3(q))
		var r=S.add("allee" if ist_haupt and opt.get("alleen",true) else typ,pts,{"wear":wear*_vrng.randf_range(0.7,1.2),"name":opt.get("name","") if ist_haupt else ""})
		strassen.append(r)
	for dir in [0,1]:
		var aussen=range(-nv,nv+1) if dir==0 else range(-nu,nu+1)
		var innen=range(-nu,nu+1) if dir==0 else range(-nv,nv+1)
		for a in aussen:
			var ist_haupt=haupt>0 and posmod(a,haupt)==0
			if not ist_haupt and _vrng.randf()<opt.get("linie_weg",0.06):continue
			var lauf=[];var prev=null;var prev_ok=false
			for b in innen:
				var k=Vector2i(b,a) if dir==0 else Vector2i(a,b)
				var p:Vector2=pos[k]
				if ok[k]:
					if lauf.is_empty():
						if prev!=null and not prev_ok:
							var e=ende.call(p,prev)
							if e!=null and e.distance_to(p)<max(du,dv)*1.3:lauf.append(e)
						lauf.append(p)
					elif not ist_haupt and _vrng.randf()<luecke:
						emit.call(lauf,ist_haupt);lauf=[p]
					else:lauf.append(p)
				else:
					if not lauf.is_empty():
						var e=ende.call(lauf[-1],p)
						if e!=null and e.distance_to(lauf[-1])<max(du,dv)*1.3:lauf.append(e)
						emit.call(lauf,ist_haupt);lauf=[]
				prev=p;prev_ok=ok[k]
			emit.call(lauf,ist_haupt)
	# Diagonalen durch einzelne Blöcke
	for i in range(-nu,nu):
		for j in range(-nv,nv):
			if _vrng.randf()>=diag:continue
			var ks=[Vector2i(i,j),Vector2i(i+1,j+1)] if _vrng.randf()<0.5 else [Vector2i(i+1,j),Vector2i(i,j+1)]
			if ok[ks[0]] and ok[ks[1]]:
				var m=(pos[ks[0]]+pos[ks[1]])*0.5+Vector2(_vrng.randf_range(-8,8),_vrng.randf_range(-8,8))
				strassen.append(S.add("gasse",[v3(pos[ks[0]]),v3(m),v3(pos[ks[1]])],{"wear":wear}))
	return strassen

# Kurvige Hangstraße: folgt grob den Höhenlinien, mit abzweigenden Sackgassen (wie die Villenhügel)
func bergstrasse(start:Vector2,richtung:float,laenge:float,opt:={},tiefe:=0)->Dictionary:
	var pts=[start];var p=start;var a=richtung;var schritt=opt.get("schritt",38.0)
	var n=int(laenge/schritt)
	for k in n:
		var best=a;var bc=1e9
		for da in [-0.55,-0.35,-0.18,0.0,0.18,0.35,0.55]:
			var aa=a+da;var q=p+Vector2(cos(aa),sin(aa))*schritt
			var dh=abs(G._nat(q.x,q.y)-G._nat(p.x,p.y))
			var cost=dh*opt.get("hang",1.0)+abs(wrapf(aa-richtung,-PI,PI))*opt.get("treue",5.0)+_vrng.randf()*3.0
			if G._nat(q.x,q.y)<2.0:cost+=1000.0
			for h in opt.get("meiden",[]):
				if q.distance_to(h[0])<h[1]:cost+=500.0
			if cost<bc:bc=cost;best=aa
		a=best;p+=Vector2(cos(a),sin(a))*schritt;pts.append(p)
		if tiefe<opt.get("tiefe",1) and k>1 and k<n-2 and _vrng.randf()<opt.get("ast",0.2):
			var seite=1.0 if _vrng.randf()<0.5 else -1.0
			bergstrasse(p,a+seite*_vrng.randf_range(1.0,1.5),laenge*_vrng.randf_range(0.25,0.45),opt,tiefe+1)
	return S.add(opt.get("typ","strasse"),pts.map(func(q):return v3(q)),{"wear":opt.get("wear",0.1),"g":0.22,"sm":14.0,"name":opt.get("name","")})

# Bergstraße zu einem Ziel: folgt so weit wie nötig den Höhenlinien (Serpentinen), Steigung möglichst <= g
func pfad(start:Vector2,ziel:Vector2,g:float,schritt:=30.0)->Array:
	var pts=[start];var p=start;var a=(ziel-start).angle();var bes=[start]
	for k in 600:
		if p.distance_to(ziel)<schritt*1.5:break
		var best=a;var bc=1e9
		for st in range(-10,11):
			var aa=a+st*deg_to_rad(15.0)
			var q=p+Vector2(cos(aa),sin(aa))*schritt
			var hq=G._nat(q.x,q.y)
			if hq<2.0:continue
			var grade=abs(hq-G._nat(p.x,p.y))/schritt
			var cost=-(p.distance_to(ziel)-q.distance_to(ziel))+max(0.0,grade-g)*900.0+abs(st)*0.6
			for b in bes.slice(max(0,bes.size()-200),max(0,bes.size()-3)):
				if q.distance_to(b)<schritt*0.9:cost+=60.0
			if cost<bc:bc=cost;best=aa
		a=best;p+=Vector2(cos(a),sin(a))*schritt;bes.append(p)
		if k%2==1:pts.append(p)
	pts.append(ziel)
	return pts.map(func(q):return v3(q))

# Hindernis-Kurzformen
func _hs(r,d:=32.0)->Array:return [r,d,true]       # Straße: Linien laufen auf sie zu
func _ha(r,d:=45.0)->Array:return [r,d,false]      # Autobahn/Bahn: Linien enden davor

func stadtviertel():
	var fw=[_ha(named.a1),_ha(named.a2),_ha(named.a5,38.0),_ha(named.bahn,35.0)]
	for r in _rampen:fw.append(_ha(r,30.0))
	# Downtown: verzogenes, leicht gebogenes Raster zwischen den Boulevards
	var dq=[gpt(-400,-385),gpt(420,-375),gpt(410,395),gpt(-410,385)]
	viertel([Vector2(dq[0].x,dq[0].y),Vector2(dq[1].x,dq[1].y),Vector2(dq[2].x,dq[2].y),Vector2(dq[3].x,dq[3].y)],
		{"mitte":D,"winkel":DA,"du":105.0,"dv":120.0,"bogen":1900.0,"warp":16.0,"warp_freq":1.0/380.0,"haupt":3,"luecken":0.03,"linie_weg":0.0,"diagonal":0.05,"wear":0.1,"seed":5,"rand":14.0,
		"hindernisse":[_hs(named.blvd_nord,30.0),_hs(named.blvd_sued,30.0),_hs(named.bogen,30.0),_hs(named.allee,30.0),_ha(named.bahn,35.0)]})
	# Nordstadt (flach, am Fuß der Hügel), leicht gefächert
	viertel([Vector2(-1100,-1150),Vector2(250,-1305),Vector2(520,-1250),Vector2(520,-690),Vector2(gpt(-330,-390).x,gpt(-330,-390).y),Vector2(-350,-760),Vector2(-1100,-800)],
		{"winkel":0.12,"du":125.0,"dv":88.0,"bogen":-2600.0,"warp":20.0,"haupt":4,"luecken":0.07,"wear":0.2,"seed":11,
		"hindernisse":fw+[_hs(named.nordallee),_hs(named.westallee),_hs(named.allee),_hs(named.blvd_nord),_hs(named.bogen),_hs(named.weststr)]})
	# Weststadt (diagonal gedreht, wie Rockford)
	viertel([Vector2(-1460,-1110),Vector2(-1100,-1150),Vector2(-1100,-800),Vector2(-350,-760),Vector2(gpt(-330,-130).x,gpt(-330,-130).y),Vector2(-640,-170),Vector2(-1050,170),Vector2(-1460,180)],
		{"winkel":0.62,"du":110.0,"dv":95.0,"warp":24.0,"haupt":4,"luecken":0.1,"wear":0.3,"seed":12,
		"hindernisse":fw+[_hs(named.westallee),_hs(named.weststr),_hs(named.delperro),_hs(named.nordallee),_hs(named.bogen),_hs(named.blvd_nord)]})
	# Weststadt Süd (Little Seoul): zwischen Autobahn A1 und Ghetto, gedreht
	viertel([Vector2(-1470,250),Vector2(-1050,230),Vector2(-1040,600),Vector2(-930,1040),Vector2(-1000,1460),Vector2(-1480,1440)],
		{"winkel":-0.35,"du":105.0,"dv":90.0,"warp":20.0,"haupt":3,"luecken":0.1,"wear":0.4,"seed":13,
		"hindernisse":fw+[_hs(named.westallee),_hs(named.suedallee),_hs(S.roads_by_name("Vespucci-Allee"))]})
	# Südstadt (Davis/Strawberry): großer, sanft gebogener Fächer
	viertel([Vector2(-950,1050),Vector2(240,1060),Vector2(1350,1050),Vector2(1380,1450),Vector2(1300,1760),Vector2(-500,1760),Vector2(-950,1600)],
		{"winkel":0.04,"du":120.0,"dv":92.0,"bogen":3200.0,"warp":42.0,"warp_freq":1.0/360.0,"haupt":4,"luecken":0.09,"wear":0.6,"seed":14,"diagonal":0.04,
		"hindernisse":fw+[_hs(named.suedallee),_hs(named.westallee)]})
	# Südstadt Nord: kleines Viertel zwischen Ghetto und Güterbahnhof
	viertel([Vector2(150,470),Vector2(620,460),Vector2(640,760),Vector2(450,940),Vector2(150,870)],
		{"winkel":0.2,"du":95.0,"dv":85.0,"warp":15.0,"haupt":0,"luecken":0.08,"wear":0.7,"seed":15,
		"hindernisse":fw+[_hs(named.lager),_hs(named.ghetto)]})
	# Hafenviertel: Gewerbe zwischen A2 und Hafenbecken
	viertel([Vector2(1470,930),Vector2(1765,930),Vector2(1765,1750),Vector2(1470,1750)],
		{"winkel":0.0,"du":150.0,"dv":120.0,"warp":10.0,"haupt":0,"luecken":0.12,"wear":0.65,"seed":16,"diagonal":0.0,
		"hindernisse":fw+[_hs(S.roads_by_name("Beckenbrücke Nord")),_hs(S.roads_by_name("Hafenbrücke"))]})
	# Strand (Vespucci/Del Perro): parallel zur Küste
	viertel([Vector2(-2240,-950),Vector2(-1620,-950),Vector2(-1600,1000),Vector2(-2150,950),Vector2(-2250,450),Vector2(-2270,0),Vector2(-2240,-450)],
		{"winkel":0.06,"du":95.0,"dv":135.0,"warp":32.0,"warp_freq":1.0/360.0,"haupt":0,"luecken":0.08,"wear":0.3,"seed":17,
		"hindernisse":fw+[_hs(named.promenade),_hs(named.delperro),_hs(S.roads_by_name("Vespucci-Allee"))]})
	# Flughafen-Nord (Wohnblöcke am Rand des Flughafens)
	viertel([Vector2(-2400,1000),Vector2(-1680,1040),Vector2(-1680,1450),Vector2(-2000,1540),Vector2(-2400,1540)],
		{"winkel":-0.25,"du":110.0,"dv":95.0,"warp":32.0,"warp_freq":1.0/360.0,"haupt":0,"luecken":0.12,"wear":0.45,"seed":18,
		"hindernisse":fw+[_hs(named.terminal),_hs(named.promenade)]})
	# Oststadt: zwei Viertel mit verschiedenen Drehungen
	viertel([Vector2(2240,-150),Vector2(2900,-260),Vector2(3150,300),Vector2(3100,820),Vector2(2240,820)],
		{"winkel":0.35,"du":120.0,"dv":95.0,"warp":34.0,"warp_freq":1.0/380.0,"haupt":4,"luecken":0.08,"wear":0.3,"seed":19,
		"hindernisse":fw+[_hs(named.oststr),_hs(named.bruecke),_hs(S.roads_by_name("Beckenbrücke Nord"))]})
	viertel([Vector2(2240,830),Vector2(3100,830),Vector2(3150,1250),Vector2(2950,1880),Vector2(2300,1980)],
		{"winkel":-0.12,"du":115.0,"dv":100.0,"bogen":-2400.0,"warp":34.0,"warp_freq":1.0/380.0,"haupt":4,"luecken":0.09,"wear":0.35,"seed":20,
		"hindernisse":fw+[_hs(named.oststr),_hs(S.roads_by_name("Beckenbrücke Nord")),_hs(S.roads_by_name("Hafenbrücke"))]})
	# Ostvororte (Mirror Park): locker, kurvig
	viertel([Vector2(1620,-1420),Vector2(2700,-1520),Vector2(2800,-760),Vector2(1640,-640)],
		{"winkel":0.2,"du":135.0,"dv":100.0,"warp":40.0,"warp_freq":1.0/380.0,"haupt":0,"luecken":0.18,"wear":0.15,"seed":21,"diagonal":0.03,
		"hindernisse":fw+[_hs(named.bruecke)]})
	S.add("strasse",[Vector3(1300,0,-1150),Vector3(1500,0,-1100),Vector3(1700,0,-1050)],{"wear":0.2})
	S.add("strasse",[Vector3(1800,0,-660),Vector3(1790,0,-400),Vector3(1780,0,-160)],{"wear":0.2})
	S.add("strasse",[Vector3(2400,0,-690),Vector3(2390,0,-420),Vector3(2380,0,-145)],{"wear":0.2})

# Villenhügel: Hangstraßen mit Sackgassen nördlich der Stadt und über der Oststadt
func huegel():
	_vrng.seed=4242
	var opt={"name":"Hügelweg","wear":0.05,"tiefe":1,"ast":0.25,"treue":3.0,"hang":1.6}
	for e in [[Vector2(-600,-1500),-1.9,900.0],[Vector2(-150,-1480),-1.5,800.0],[Vector2(80,-1450),-1.1,700.0],[Vector2(420,-1400),-1.3,650.0],
			[Vector2(-800,-1450),-2.4,700.0],[Vector2(-1100,-1150),-2.0,650.0],[Vector2(600,-1290),-0.8,600.0]]:
		bergstrasse(e[0],e[1],e[2],opt)
	var opt2={"name":"","wear":0.15,"tiefe":1,"ast":0.2,"treue":3.0,"hang":1.4}
	for e in [[Vector2(3100,820),-0.3,500.0],[Vector2(3150,300),0.3,450.0],[Vector2(2700,-1520),-1.2,550.0]]:
		bergstrasse(e[0],e[1],e[2],opt2)

# Strandviertel an der Westküste: Promenade, Pier, Neu-Kowloon
func strandviertel():
	named.promenade=S.add("allee",[Vector3(-2250,0,-900),Vector3(-2290,0,-450),Vector3(-2320,0,0),Vector3(-2300,0,450),Vector3(-2200,0,850),Vector3(-2350,0,1150),Vector3(-2400,0,1550)],{"name":"Strandpromenade","wear":0.25})
	S.add("strasse",[Vector3(-2200,0,-1000),Vector3(-2050,0,-995),Vector3(-1900,0,-1000),Vector3(-1895,0,-1150),Vector3(-1900,0,-1300),Vector3(-2050,0,-1305),Vector3(-2200,0,-1300),Vector3(-2205,0,-1150)],{"closed":true,"name":"Kowloon-Ring","wear":0.6})
	S.add("strasse",[Vector3(-2250,0,-900),Vector3(-2220,0,-960),Vector3(-2200,0,-1000)],{"wear":0.6})
	S.add("strasse",[Vector3(-1900,0,-1150),Vector3(-1700,0,-1140),Vector3(-1480,0,-1130)],{"wear":0.5})

# Sternviertel: Plätze mit strahlenförmigen Avenuen
const STERN:=Vector2(1080,-520)
func sternviertel():
	G.plateaus.append([STERN,140.0,90.0,G._nat(STERN.x,STERN.y)])
	S.add("strasse",bogen(STERN,110.0,0.0,TAU,16),{"closed":true,"name":"Sternplatz","wear":0.2})
	S.add("strasse",bogen(STERN,215.0,-2.2,1.35,14),{"name":"Sternring","wear":0.25})
	for k in 6:
		var a=TAU*k/6.0+0.25
		if a>1.6 and a<3.8:continue
		var d=Vector2(cos(a),sin(a))
		S.add("strasse",[v3(STERN+d*110.0),v3(STERN+d*215.0),v3(STERN+d*300.0)],{"wear":0.2})
	S.add("strasse",[v3(STERN+Vector2(cos(3.35),sin(3.35))*110.0),Vector3(870,0,-380),Vector3(800,0,-200)],{"wear":0.2})

# Sonnenhügel: Nobelviertel mit Serpentinen und Villen am Hang nördlich der Stadt
func sonnenhuegel():
	S.add("strasse",[Vector3(330,0,-1000),Vector3(250,0,-1300),Vector3(80,0,-1450),Vector3(-150,0,-1480),Vector3(-380,0,-1420),Vector3(-600,0,-1500),Vector3(-800,0,-1450)],{"name":"Sonnenallee","wear":0.05,"g":0.12})
	S.add("strasse",[Vector3(80,0,-1450),Vector3(60,0,-1620),Vector3(-100,0,-1700),Vector3(-320,0,-1650),Vector3(-380,0,-1420)],{"name":"Panoramaweg","wear":0.05,"g":0.13,"sm":18.0})
	S.add("strasse",[Vector3(-100,0,-1700),Vector3(-150,0,-1880),Vector3(-350,0,-1950),Vector3(-550,0,-1850),Vector3(-600,0,-1650),Vector3(-600,0,-1500)],{"name":"Gipfelblick","wear":0.05,"g":0.13,"sm":18.0})
	S.add("strasse",[Vector3(-800,0,-1450),Vector3(-950,0,-1250),Vector3(-1100,0,-1150)],{"wear":0.05,"g":0.12})
	S.add("gasse",[Vector3(250,0,-1300),Vector3(420,0,-1400),Vector3(520,0,-1600),Vector3(380,0,-1750),Vector3(60,0,-1620)],{"name":"Villenweg","wear":0.05,"g":0.14,"sm":16.0})
	S.add("gasse",[Vector3(-350,0,-1950),Vector3(-300,0,-2150),Vector3(-150,0,-2200)],{"name":"Schriftzugweg","wear":0.1,"g":0.15,"sm":16.0})

# ---------------- Südstadt-Docks ----------------
func suedstadt():
	named.docks=S.add("strasse",[Vector3(-850,0,2040),Vector3(-300,0,2045),Vector3(300,0,2050),Vector3(900,0,2050),Vector3(1500,0,2040),Vector3(1700,0,1990)],{"name":"Kaistraße","wear":0.7})
	for x in [-600.0,0.0,600.0,1200.0]:
		S.add("strasse",[Vector3(x,0,1720),Vector3(x,0,1900),Vector3(x,0,2045)],{"wear":0.7})

# ---------------- Oststadt (jenseits des Hafenbeckens) ----------------
func oststadt():
	S.add("strasse",[Vector3(1550,0,950),Vector3(1700,0,950),Vector3(2000,0,950),Vector3(2300,0,965),Vector3(2670,0,980)],{"name":"Beckenbrücke Nord","wear":0.3})
	S.add("allee",[Vector3(1380,0,1620),Vector3(1700,0,1620),Vector3(2000,0,1620),Vector3(2300,0,1650),Vector3(2660,0,1660)],{"name":"Hafenbrücke","wear":0.3})
	named.bruecke=S.add("allee",[Vector3(1180,0,-230),Vector3(1600,0,-170),Vector3(1950,0,-150),Vector3(2300,0,-140),Vector3(2560,0,-180)],{"name":"Ostallee","wear":0.2})

# ---------------- Internationaler Flughafen (Halbinsel im Südwesten) ----------------
func flughafen_strassen():
	named.runway=S.add("runway",[Vector3(-2950,0,1950),Vector3(-1250,0,1950)],{"wear":1.0,"name":"Startbahn Nord"})
	S.add("runway",[Vector3(-2950,0,2400),Vector3(-1350,0,2400)],{"wear":1.0,"name":"Startbahn Süd"})
	S.add("taxi",[Vector3(-2900,0,2175),Vector3(-2100,0,2175),Vector3(-1350,0,2175)],{"wear":1.0})
	for x in [-2850.0,-2100.0,-1400.0]:
		S.add("taxi",[Vector3(x,0,1950),Vector3(x,0,2175),Vector3(x,0,2400)],{"wear":1.0})
	S.add("taxi",[Vector3(-1900,0,1950),Vector3(-1900,0,1800),Vector3(-1900,0,1700)],{"wear":1.0})
	named.terminal=S.add("allee",[Vector3(-1150,0,1450),Vector3(-1300,0,1550),Vector3(-1550,0,1630),Vector3(-2000,0,1625),Vector3(-2400,0,1600)],{"name":"Flughafenallee","wear":0.15})

# ---------------- Autobahnen ----------------
# A1: Küstenautobahn rund um die Insel – vom Hafen durch den Westen der Stadt, die Westküste hinauf, über den Norden
#     und an der Ostküste zurück bis vor die Oststadt. Dort geht sie in die A5 über.
# A5: Hochstraße quer durch die Stadt (Oststadt -> Hafenbecken -> Bahnhof -> Altstadt -> Strand).
# A2: vom Hafen nach Norden durch die Wüste bis an die Nordküste.
# A3: Querspange durch das Mittelgebirge, Kleeblatt mit der A2.
func autobahnen():
	named.a1=S.add("autobahn",[Vector3(1250,0,1870),Vector3(700,0,1890),Vector3(100,0,1890),Vector3(-500,0,1850),Vector3(-1000,0,1720),Vector3(-1380,0,1530),
		Vector3(-1580,0,1250),Vector3(-1600,0,850),Vector3(-1540,0,400),Vector3(-1520,0,-150),Vector3(-1580,0,-700),Vector3(-1660,0,-1150),Vector3(-1800,0,-1600),
		Vector3(-2300,0,-2200),Vector3(-2450,0,-3100),Vector3(-2550,0,-4000),Vector3(-2250,0,-4750),
		Vector3(-1800,0,-5400),Vector3(-1900,0,-6300),Vector3(-2400,0,-7300),Vector3(-2200,0,-8100),Vector3(-1600,0,-8800),Vector3(-1000,0,-9450),
		Vector3(-300,0,-9800),Vector3(700,0,-9350),Vector3(1700,0,-9300),Vector3(2700,0,-8800),Vector3(3150,0,-7900),Vector3(3050,0,-6900),
		Vector3(3250,0,-5900),Vector3(3150,0,-4800),Vector3(3000,0,-3700),Vector3(3100,0,-2600),Vector3(2950,0,-1750),Vector3(2900,0,-1000),Vector3(2780,0,-350)],{"name":"A1"})
	named.a5=S.add("autobahn",[Vector3(2780,0,-350),Vector3(2620,0,50),Vector3(2330,3,320),Vector3(1950,9,385),Vector3(1650,11,400),Vector3(1400,13,405),
		Vector3(1000,12,395),Vector3(690,13,385),Vector3(300,12,375),Vector3(-200,12,370),Vector3(-700,12,370),Vector3(-1150,12,365),Vector3(-1540,13,355),
		Vector3(-1850,6,300),Vector3(-2120,0,250)],{"name":"A5","ab_join":true})
	named.ring=named.a5
	named.a2=S.add("autobahn",[Vector3(1250,0,1870),Vector3(1420,0,1650),Vector3(1440,0,1100),Vector3(1420,0,700),Vector3(1400,0,405),Vector3(1410,0,0),
		Vector3(1480,0,-500),Vector3(1420,0,-1000),Vector3(1150,0,-1450),Vector3(880,0,-1950),Vector3(900,0,-2700),Vector3(1200,0,-3600),Vector3(1300,0,-4500),Vector3(1600,0,-5200),
		Vector3(2050,0,-5900),Vector3(2400,0,-6700),Vector3(2500,0,-7500),Vector3(2600,0,-8100),Vector3(2550,0,-8450)],{"name":"A2","ab_join":true})
	# A2 trifft im Norden die A1
	S.add("rampe",[Vector3(2550,0,-8450),Vector3(2350,0,-8800),Vector3(2150,0,-9050)],{"ab_join":true})
	S.add("rampe",[Vector3(2550,0,-8450),Vector3(2780,0,-8550),Vector3(2925,0,-8350)],{"ab_join":true})
	# A3 Querspange, überquert die A2 auf einer Brücke (Autobahnkreuz Mittelgebirge, Kleeblatt)
	var K=Vector2(1235,-3890)
	named.a3=S.add("autobahn",[Vector3(-2480,0,-3500),Vector3(-1800,0,-3700),Vector3(-900,0,-3900),Vector3(-100,0,-3950),Vector3(600,0,-3850),Vector3(K.x,12,K.y),
		Vector3(1900,0,-3850),Vector3(2600,0,-3750),Vector3(3000,0,-3700)],{"name":"A3"})
	for q in [0.0,PI*0.5,PI,PI*1.5]:
		var a0=q+0.35;var a1=q+PI*0.5-0.35
		var c=K+Vector2(cos(q+PI*0.25),sin(q+PI*0.25))*420.0
		S.add("rampe",bogen(c,300.0,a0+PI,a1+PI,8),{"ab_join":true,"sm":30.0})
	S.add("rampe",[Vector3(-2480,0,-3500),Vector3(-2520,0,-3700),Vector3(-2545,0,-3900)],{"ab_join":true})
	S.add("rampe",[Vector3(3000,0,-3700),Vector3(3050,0,-3500),Vector3(3080,0,-3300)],{"ab_join":true})
	# Autobahnkreuze in der Stadt: A5 über A2 (Kreuz Hafen) und A5 über A1 (Kreuz West)
	kreuz(Vector2(1400,405),Vector2(0,1),Vector2(1,0.02).normalized(),330.0)
	kreuz(Vector2(-1540,355),Vector2(-0.03,1).normalized(),Vector2(1,0.02).normalized(),330.0)
	# Anschlussstellen über Land
	S.add("rampe",[Vector3(2050,0,-5900),Vector3(1950,0,-5850),Vector3(1880,0,-5800)],{"ab_join":true})       # Staubwinkel
	S.add("rampe",[Vector3(-1800,0,-5400),Vector3(-1850,0,-5300),Vector3(-1900,0,-5250)],{"ab_join":true})    # Militärflugplatz / Wüste
	S.add("rampe",[Vector3(-1900,0,-6300),Vector3(-1700,0,-6400),Vector3(-1550,0,-6450)],{"ab_join":true})    # Espenwald / Gipfel
	S.add("rampe",[Vector3(2500,0,-7500),Vector3(2350,0,-7600),Vector3(2250,0,-7650)],{"ab_join":true})      # Farmland
	S.add("rampe",[Vector3(-2200,0,-8100),Vector3(-2330,0,-8160),Vector3(-2450,0,-8200)],{"ab_join":true})    # Nordbucht
	S.add("rampe",[Vector3(1560,0,-5100),Vector3(1630,0,-5080),Vector3(1700,0,-5050)],{"ab_join":true})      # Gefängnis

var _rampen:=[]
# Autobahnkreuz: vier Verbindungsrampen, je eine pro Quadrant, tangential an beide Autobahnen
func kreuz(X:Vector2,da:Vector2,db:Vector2,r:float):
	for sa in [-1.0,1.0]:
		for sb in [-1.0,1.0]:
			var p1=X+da*sa*r;var p2=X+db*sb*r;var ctl=X+(da*sa+db*sb)*r*0.22
			var pts=[]
			for k in 11:
				var t=k/10.0
				pts.append(v3((1-t)*(1-t)*p1+2*(1-t)*t*ctl+t*t*p2))
			_rampen.append(S.add("rampe",pts,{"ab_join":true,"sm":40.0}))


# ================= Sackgassen verbinden =================
# Jedes Straßenende, das nirgends anschließt, bekommt eine geschwungene Verbindung zur nächsten passenden Straße
# (bevorzugt geradeaus weiter, nie über Autobahn/Bahn/Wasser). Kurze lose Stummel ohne Ziel fallen weg.
var _seg_hash:={}
var _segs:=[]     # [a, b, road]
const _ZELLE:=80.0
func _seg_add(a:Vector2,b:Vector2,r):
	var i=_segs.size();_segs.append([a,b,r])
	var x0=int(floor(min(a.x,b.x)/_ZELLE));var x1=int(floor(max(a.x,b.x)/_ZELLE))
	var z0=int(floor(min(a.y,b.y)/_ZELLE));var z1=int(floor(max(a.y,b.y)/_ZELLE))
	for x in range(x0,x1+1):
		for z in range(z0,z1+1):
			var k=Vector2i(x,z)
			if not _seg_hash.has(k):_seg_hash[k]=[]
			_seg_hash[k].append(i)
func _seg_nah(p:Vector2,rad:float)->Array:
	var out={}
	var x0=int(floor((p.x-rad)/_ZELLE));var x1=int(floor((p.x+rad)/_ZELLE))
	var z0=int(floor((p.y-rad)/_ZELLE));var z1=int(floor((p.y+rad)/_ZELLE))
	for x in range(x0,x1+1):
		for z in range(z0,z1+1):
			for i in _seg_hash.get(Vector2i(x,z),[]):out[i]=true
	return out.keys()
func _road_segs(r):
	var c=r.ctrl;var n=c.size()
	for k in n-1:_seg_add(Vector2(c[k].x,c[k].z),Vector2(c[k+1].x,c[k+1].z),r)
	if r.closed:_seg_add(Vector2(c[n-1].x,c[n-1].z),Vector2(c[0].x,c[0].z),r)

func _sperrt(a:Vector2,b:Vector2,ausser:Array)->bool:
	# kreuzt die Strecke eine Autobahn, Rampe, Bahn oder Wasser?
	for i in _seg_nah((a+b)*0.5,a.distance_to(b)*0.5+10.0):
		var s=_segs[i]
		if s[2] in ausser:continue
		if s[2].typ in ["autobahn","rampe","schiene","runway","taxi"]:
			if Geometry2D.segment_intersects_segment(a,b,s[0],s[1])!=null:return true
	for k in 6:
		var q=a.lerp(b,(k+0.5)/6.0)
		if G._nat(q.x,q.y)<1.5:return true
	return false

func _len_ctrl(r)->float:
	var L=0.0
	for k in r.ctrl.size()-1:L+=Vector2(r.ctrl[k].x,r.ctrl[k].z).distance_to(Vector2(r.ctrl[k+1].x,r.ctrl[k+1].z))
	return L

func sackgassen_verbinden():
	_seg_hash={};_segs=[]
	for r in S.roads:_road_segs(r)
	var STADT=["strasse","allee","gasse"]
	var neu=0;var weg=[];var ziele={}
	var liste=S.roads.duplicate()
	for r in liste:
		if not r.typ in STADT or r.closed or r.name=="Hügelweg":continue
		var c=r.ctrl;var n=c.size()
		var lose=0
		for e in [0,n-1]:
			var p=Vector2(c[e].x,c[e].z);var q0=Vector2(c[1].x,c[1].z) if e==0 else Vector2(c[n-2].x,c[n-2].z)
			var t=(p-q0).normalized()
			# schon angeschlossen?
			var dran=false
			for i in _seg_nah(p,30.0):
				var s=_segs[i]
				if s[2]==r or not s[2].typ in STADT+["land","rampe"]:continue
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p,s[0],s[1]))<26.0:dran=true;break
			if dran:continue
			# Ziele suchen
			var kand=[]
			for i in _seg_nah(p,260.0):
				var s=_segs[i]
				if s[2]==r or not s[2].typ in STADT+["land"]:continue
				var q=Geometry2D.get_closest_point_to_segment(p,s[0],s[1])
				var d=p.distance_to(q)
				if d<26.0 or d>260.0:continue
				var ca=t.dot((q-p)/d)
				if ca<-0.15:continue
				kand.append([d*(1.7-ca*0.8),q,s])
			kand.sort_custom(func(a,b):return a[0]<b[0])
			var ok=false
			for k in min(kand.size(),6):
				var q:Vector2=kand[k][1];var s=kand[k][2];var d=p.distance_to(q)
				if _sperrt(p,q,[r,s[2]]):continue
				# Einmündung möglichst rechtwinklig, Verbindung als Bogen
				var st=(s[1]-s[0]).normalized();var m=Vector2(-st.y,st.x)
				if m.dot(p-q)<0:m=-m
				var P1=p+t*min(d*0.45,90.0);var P2=q+m*min(d*0.4,80.0)
				var pts=[];var frei=true
				for j in 8:
					var u=j/7.0
					var b=(1-u)*(1-u)*(1-u)*p+3*(1-u)*(1-u)*u*P1+3*(1-u)*u*u*P2+u*u*u*q
					pts.append(b)
				# keine Doppelstraße: Mitte der Verbindung muss Abstand zu anderen Straßen haben
				for j in range(2,6):
					for i in _seg_nah(pts[j],24.0):
						var o=_segs[i]
						if o[2]==r or o[2]==s[2]:continue
						if pts[j].distance_to(Geometry2D.get_closest_point_to_segment(pts[j],o[0],o[1]))<20.0:frei=false;break
					if not frei:break
				if not frei:continue
				var nr=S.add("strasse" if r.typ!="gasse" else "gasse",pts.map(func(x):return v3(x)),{"wear":r.wear})
				_road_segs(nr);neu+=1;ok=true;ziele[s[2]]=true;break
			if not ok:lose+=1
		# kurzer Stummel, der an keinem Ende hängt -> weg
		if (lose==2 and _len_ctrl(r)<160.0) or (lose==1 and _len_ctrl(r)<70.0):weg.append(r)
	for r in weg:
		if not ziele.has(r):S.roads.erase(r)
	print("WELT Sackgassen verbunden: ",neu,"  entfernt: ",weg.size())

# Abfahrten von den Stadtautobahnen auf die Alleen
func abfahrten():
	for e in [
		# A1 West
		[Vector2(-1560,-1000),Vector2(-1500,-1070),Vector2(-1480,-1130)],
		[Vector2(-1530,-560),Vector2(-1480,-470),Vector2(-1450,-405)],
		[Vector2(-1590,950),Vector2(-1520,880),Vector2(-1450,720)],
		[Vector2(-1560,1330),Vector2(-1490,1230),Vector2(-1450,1160)],
		# A1 Süd (Hafenautobahn)
		[Vector2(-900,1750),Vector2(-800,1770),Vector2(-600,1720)],
		[Vector2(-150,1880),Vector2(-50,1820),Vector2(0,1720)],
		[Vector2(450,1890),Vector2(550,1820),Vector2(600,1720)],
		[Vector2(1050,1880),Vector2(1150,1960),Vector2(1200,2045)],
		# A2 Stadt
		[Vector2(1430,1300),Vector2(1380,1220),Vector2(1350,1120)],
		[Vector2(1420,800),Vector2(1370,720),Vector2(1300,700)],
		[Vector2(1410,-100),Vector2(1350,-180),Vector2(1180,-230)],
		[Vector2(1400,-1080),Vector2(1350,-1130),Vector2(1300,-1150)],
		# A5 (Hochstraße): lange Rampen auf die Straßen darunter
		[Vector2(-900,368),Vector2(-1000,330),Vector2(-1040,250),Vector2(-1050,180)],
		[Vector2(-650,370),Vector2(-450,330),Vector2(-300,335),Vector2(-200,400)],
		[Vector2(100,373),Vector2(250,300),Vector2(330,200),Vector2(380,120)],
		[Vector2(2150,350),Vector2(2350,250),Vector2(2500,120),Vector2(2600,80)]]:
		var pts=[];for p in e:pts.append(v3(p))
		S.add("rampe",pts,{"ab_join":true})

# ---------------- Landstraßen und Bergpässe ----------------
func land():
	# Küstenstraße im Westen
	S.add("land",[Vector3(-2230,0,-1100),Vector3(-2500,0,-1800),Vector3(-2650,0,-2600),Vector3(-2750,0,-3300),Vector3(-2800,0,-3900),Vector3(-2800,0,-4400),Vector3(-2600,0,-4700)],{"name":"Küstenstraße","wear":0.5})
	S.add("land",[Vector3(-2230,0,-1100),Vector3(-2205,0,-1150)],{"wear":0.5})
	# Bergpass durch das Mittelgebirge (Sonnenhügel -> Flusstal -> Wüste)
	var pass1=pfad(Vector2(-150,-2200),Vector2(300,-4100),0.08);var pass2=pfad(Vector2(300,-4100),Vector2(750,-5100),0.08)
	pass2.remove_at(0)
	S.add("land",pass1+pass2,{"name":"Bergpass","wear":0.5,"g":0.11,"sm":16.0})
	S.add("land",[Vector3(-100,0,-1700),Vector3(-150,0,-2200)],{"wear":0.3})
	# Stauseeweg: Rundweg am Ufer des Stausees, Zufahrt vom Sonnenhügel
	var sts=[];var ms=G.STAUSEE
	for k in 22:
		var a=TAU*k/22.0;var d=Vector2(cos(a),sin(a));var r=40.0
		while r<900.0 and G._nat(ms.x+d.x*r,ms.y+d.y*r)<2.5:r+=10.0
		sts.append(v3(ms+d*(r+45.0)))
	S.add("land",sts,{"closed":true,"name":"Stauseeweg","wear":0.4,"g":0.12})
	S.add("land",pfad(Vector2(-600,-1650),Vector2(ms.x,ms.y+300.0),0.09),{"wear":0.4,"g":0.12})
	# Flusstalstraße
	S.add("land",[Vector3(-2600,0,-4700),Vector3(-1900,0,-4500),Vector3(-1100,0,-4350),Vector3(-300,0,-4250),Vector3(300,0,-4100)],{"name":"Flusstalstraße","wear":0.5})
	# Staubsee-Rundweg
	# Seeuferstraße folgt dem echten Ufer (von der Seemitte nach außen bis zum Land, dann ein Stück landeinwärts)
	var see=[];var fs=FastNoiseLite.new();fs.seed=77;fs.frequency=0.9
	for k in 30:
		var a=TAU*k/30.0;var d=Vector2(cos(a),sin(a)*0.5).normalized();var r=100.0
		while r<2600.0 and G._nat(G.SEE.x+d.x*r,G.SEE.y+d.y*r)<2.5:r+=20.0
		r+=130.0+fs.get_noise_1d(k*1.0)*70.0
		see.append(v3(G.SEE+d*r))
	S.add("land",see,{"closed":true,"name":"Seeuferstraße","wear":0.6})
	# Wüstenstraßen
	S.add("land",[Vector3(1880,0,-5800),Vector3(1300,0,-5550),Vector3(750,0,-5100),Vector3(0,0,-5450),Vector3(-600,0,-5550),Vector3(-1200,0,-5450),Vector3(-1900,0,-5250)],{"name":"Wüstenstraße","wear":0.7})
	S.add("runway",[Vector3(150,0,-5280),Vector3(1050,0,-5250)],{"wear":1.0,"name":"Wüstenpiste"})
	S.add("piste",[Vector3(-600,0,-5550),Vector3(-450,0,-5900),Vector3(-250,0,-6050)],{"wear":1.0})
	# Farmland
	S.add("land",[Vector3(2250,0,-7650),Vector3(1950,0,-7800),Vector3(1650,0,-7900),Vector3(1300,0,-7750)],{"name":"Feldweg","wear":0.6})
	S.add("piste",[Vector3(1950,0,-7800),Vector3(2050,0,-8200),Vector3(1850,0,-8400)],{"wear":1.0})
	# Radeberg-Gipfel: Serpentinen zum Gipfel
	S.add("land",pfad(Vector2(-1550,-6450),Vector2(-700,-8020),0.095),{"g":0.12,"sm":12.0,"tunnel":false,"name":"Gipfelstraße","wear":0.5})
	S.add("land",[Vector3(-1550,0,-6450),Vector3(-1000,0,-6300),Vector3(-600,0,-6150)],{"name":"Espenweg","wear":0.5})

# ---------------- Nordbucht: langgezogene Küstenstadt im Nordwesten ----------------
func nordbucht():
	for p in [Vector2(-2430,-8600),Vector2(-1830,-9030)]:G.plateaus.append([p,420.0,150.0,6.0])
	var haupt=[Vector3(-2830,0,-8180),Vector3(-2420,0,-8660),Vector3(-1950,0,-9020),Vector3(-1420,0,-9300)]
	S.add("allee",haupt,{"wear":0.3,"name":"Hauptstraße Nordbucht"})
	var ufer=S.add("strasse",[Vector3(-2950,0,-8300),Vector3(-2520,0,-8800),Vector3(-2030,0,-9180),Vector3(-1500,0,-9440)],{"wear":0.3,"name":"Uferweg"})
	viertel([Vector2(-2980,-8280),Vector2(-2600,-8030),Vector2(-1320,-9080),Vector2(-1500,-9470),Vector2(-2050,-9200),Vector2(-2550,-8820)],
		{"winkel":-0.69,"du":105.0,"dv":80.0,"warp":20.0,"haupt":0,"luecken":0.14,"wear":0.35,"seed":31,
		"hindernisse":[_hs(haupt),_hs(ufer),_ha(named.a1,60.0)]})
	S.add("land",[Vector3(-2450,0,-8200),Vector3(-2560,0,-8320),Vector3(-2600,0,-8450)],{"wear":0.3})

func _poly(pts:Array,t:float)->Vector2:
	var L=0.0
	for i in pts.size()-1:L+=pts[i].distance_to(pts[i+1])
	var s=t*L
	for i in pts.size()-1:
		var d=pts[i].distance_to(pts[i+1])
		if s<=d:return pts[i].lerp(pts[i+1],s/d)
		s-=d
	return pts[-1]

# ---------------- Staubwinkel: Trailerdorf am Staubsee (Waffenhändler, Tuning, Bar) ----------------
func staubwinkel():
	var c=G.DORF
	G.plateaus.append([c,190.0,90.0,G._nat(c.x,c.y)])
	named.dorf=S.add("gasse",[v3(c+Vector2(-180,-40)),v3(c+Vector2(0,0)),v3(c+Vector2(180,-30)),v3(c+Vector2(260,-10))],{"name":"Staubweg","wear":1.0})
	S.add("gasse",[v3(c+Vector2(0,-150)),v3(c+Vector2(0,0)),v3(c+Vector2(20,150))],{"wear":1.0})
	S.add("gasse",[v3(c+Vector2(-120,80)),v3(c+Vector2(20,150)),v3(c+Vector2(160,90))],{"wear":1.0})
	S.add("land",[Vector3(1880,0,-5800),v3(c+Vector2(260,-10))],{"wear":0.8})
	G.plateaus.append([G.CANYON,270.0,90.0,G._nat(G.CANYON.x,G.CANYON.y)])
	G.plateaus.append([Vector2(600,-5265),520.0,80.0,G._nat(600,-5265)])

# ---------------- Sandufer: Wüstenstadt am Südufer des Staubsees ----------------
func sandufer():
	var see=S.roads_by_name("Seeuferstraße")
	named.sandufer=S.add("allee",[Vector3(150,0,-5760),Vector3(600,0,-5740),Vector3(1050,0,-5760),Vector3(1450,0,-5800),Vector3(1700,0,-5880)],{"name":"Hauptstraße Sandufer","wear":0.7})
	viertel([Vector2(120,-6060),Vector2(800,-6110),Vector2(1450,-6200),Vector2(1640,-5960),Vector2(1560,-5620),Vector2(150,-5620)],
		{"winkel":-0.05,"du":105.0,"dv":80.0,"warp":28.0,"haupt":0,"luecken":0.14,"linie_weg":0.05,"wear":0.85,"seed":41,"diagonal":0.03,
		"hindernisse":[_hs(see),_hs(named.sandufer),_ha(named.a2,60.0)]})
	S.add("strasse",[Vector3(600,0,-5740),Vector3(620,0,-5500),Vector3(600,0,-5300)],{"wear":0.8})

# ---------------- Kornfeld: Bauerndorf am Farmland (nordöstlich des Sees) ----------------
func kornfeld():
	var see=S.roads_by_name("Seeuferstraße");var feld=S.roads_by_name("Feldweg")
	viertel([Vector2(1300,-7780),Vector2(2050,-7820),Vector2(2120,-7360),Vector2(1380,-7300)],
		{"winkel":0.28,"du":125.0,"dv":105.0,"warp":30.0,"haupt":0,"luecken":0.32,"linie_weg":0.15,"wear":0.6,"seed":42,
		"hindernisse":[_hs(see),_hs(feld),_ha(named.a2,60.0)]})

# ---------------- Fischerdorf am Westufer des Sees ----------------
func fischerdorf():
	var see=S.roads_by_name("Seeuferstraße")
	G.plateaus.append([Vector2(-830,-6680),170.0,80.0,max(G._nat(-830,-6680),6.0)])
	viertel([Vector2(-1000,-6830),Vector2(-700,-6830),Vector2(-680,-6520),Vector2(-1000,-6520)],
		{"winkel":0.4,"du":75.0,"dv":65.0,"warp":12.0,"haupt":0,"luecken":0.25,"wear":0.8,"seed":43,"typ":"gasse",
		"hindernisse":[_hs(see)]})

# ---------------- Gefängnis (Hochsicherheits-JVA südlich der Wüste) ----------------
const KNAST:=Vector2(2000,-5050)
func gefaengnis_strassen():
	G.plateaus.append([KNAST,330.0,120.0,G._nat(KNAST.x,KNAST.y)])
	named.knast=S.add("strasse",[Vector3(1700,0,-5050),Vector3(1735,0,-5050),Vector3(1772,0,-5050)],{"name":"Gefängnisstraße","wear":0.3})
	var ring=[]
	for k in 16:
		var a=TAU*k/16.0
		ring.append(v3(KNAST+Vector2(cos(a)*300.0,sin(a)*260.0)))
	S.add("gasse",ring,{"closed":true,"wear":0.6})

# ---------------- Militärflugplatz (Sperrgebiet) ----------------
func militaer_strassen():
	var m=G.MILITAER
	named.mil_bahn=S.add("runway",[v3(m+Vector2(-650,0)),v3(m+Vector2(650,0))],{"wear":0.6,"name":"Militärpiste"})
	S.add("taxi",[v3(m+Vector2(-600,150)),v3(m+Vector2(0,150)),v3(m+Vector2(600,150))],{"wear":0.5})
	for x in [-500.0,0.0,500.0]:
		S.add("taxi",[v3(m+Vector2(x,0)),v3(m+Vector2(x,75)),v3(m+Vector2(x,150))],{"wear":0.5})
	named.mil_tor=S.add("strasse",[v3(m+Vector2(600,150)),v3(m+Vector2(700,190)),Vector3(-1900,0,-5250)],{"name":"Kasernenstraße","wear":0.3})

var spiel:=false          # true: vom Spiel erzeugt (keine Testbilder, keine statischen Autos/Passanten)
func _ready():
	args=OS.get_cmdline_user_args();rng.seed=4711
	if spiel:return
	if "bake" in args:
		BAU.new(GEL.new(),null).bake_cache();get_tree().quit();return
	var t0=Time.get_ticks_msec()
	await generate(func(_t,_p):pass)
	_after(t0)

# Welt erzeugen; progress(text, anteil 0..1) wird zwischen den Schritten aufgerufen
func generate(progress:Callable):
	var tt=[Time.get_ticks_msec()]
	var mark=func(n):print("ZEIT ",n," ",Time.get_ticks_msec()-tt[0]," ms");tt[0]=Time.get_ticks_msec()
	var step=func(t,p):
		progress.call(t,p);await get_tree().process_frame;await get_tree().process_frame
	await step.call("Gelände wird geformt …",0.02)
	G=GEL.new();S=STR.new(G)
	layout()
	G.build_heights();mark.call("hoehen")
	await step.call("Straßen und Autobahn …",0.08)
	S.profiles();mark.call("profile")
	S.shape_terrain();mark.call("formen")
	await step.call("Häuser werden verteilt …",0.14)
	B=BAU.new(G,S);B.spiel=spiel;B.mark_roads()
	A=ANL.new(G,S,B);A.reserve()
	B.place_along();mark.call("platzieren")
	G.apply_cut()
	S.clamp_terrain()
	S.portal_fix();mark.call("cut/clamp/portal")
	G.holes=S.holes
	await step.call("Landschaft …",0.25)
	G.build_mesh(self);mark.call("gelaendemesh")
	await step.call("Fahrbahnen, Brücken, Tunnel …",0.35)
	S.build(self);mark.call("strassenmesh")
	_water()
	await step.call("Gebäude …",0.45)
	if spiel:
		var geb=Node3D.new();geb.name="Gebaeude";add_child(geb);B.fundamente(geb)   # Häuser blendet das Spiel nach und nach ein
	elif "karte" in args:
		var geb=Node3D.new();geb.name="Gebaeude";add_child(geb);B.kloetze(geb)
	else:B.build(self)
	mark.call("gebaeude")
	await step.call("Bahnhof, Hafen, Flugplatz, Läden …",0.62)
	A.build(self);mark.call("anlagen")
	if not spiel:_save_icons()
	if not "nolife" in args:
		LV=LEB.new(G,S,B);LV.spiel=spiel
		var lr=Node3D.new();lr.name="Leben";add_child(lr)
		await step.call("Wälder …",0.72)
		LV.forests(lr);mark.call("wald")
		await step.call("Laternen und Straßenbäume …",0.82)
		LV.streets(lr);LV.ghetto_props(lr);LV.moebel(lr);mark.call("laternen")
		if not spiel and not "nocars" in args:LV.cars(lr);LV.people(lr,90);mark.call("autos/leute")

# ================= Welt-Cache: einmal am PC erzeugen, im Spiel nur laden (schneller Start auf dem Handy) =================
const CACHE_DIR:="res://assets/cache/welt/"
static func cache_da()->bool:
	return ResourceLoader.exists(CACHE_DIR+"welt.scn") and FileAccess.file_exists(CACHE_DIR+"welt_daten.bin")

# Kollision der festen Welt (Gelände, Straßen, Anlagen); Gebäude bekommen ihre Kästen beim Einblenden
func kollision_bauen():
	var sb=StaticBody3D.new();sb.name="Kollision";add_child(sb)
	var teile=["Gelaende","Strasse","Beton","Gehweg","Bordstein","Mittelstreifen","Schotter","Leitplanke","Kreuzung","Platz"]
	for c in get_children():
		if c is MeshInstance3D and c.mesh:
			var ok=false
			for k in teile:
				if str(c.name).contains(k):ok=true
			if ok:
				var cs=CollisionShape3D.new();cs.shape=c.mesh.create_trimesh_shape();sb.add_child(cs)
	for sh in A.shops:
		if sh.typ!="zuhause":continue
		var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=Vector3(sh.w*0.92,9.0,sh.d*0.92);cs.shape=bx;sb.add_child(cs)
		cs.transform=Transform3D(Basis(Vector3.UP,sh.yaw),Vector3(sh.c.x,sh.y+4.4,sh.c.y))
	var TOR=load("res://scripts/rolltor.gd")
	var an=get_node_or_null("Anlagen")
	if an:
		for m in an.find_children("*","MeshInstance3D",true,false):
			var p=m.get_parent()
			if p.get_script()==TOR or (p.get_parent()!=null and p.get_parent().get_script()==TOR):continue
			if m.mesh==null or not m.visible:continue
			if not (p==an or p.get_parent()==an):continue
			if m.mesh.get_faces().size()>900000:continue
			var cs=CollisionShape3D.new();cs.shape=m.mesh.create_trimesh_shape();sb.add_child(cs);cs.transform=m.global_transform
		for n in an.find_children("*","Node3D",true,false):
			if n.get_script()==TOR and n.open<0.5:
				var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=Vector3(0.2,n.h,n.w);cs.shape=bx;sb.add_child(cs)
				cs.transform=n.global_transform*Transform3D(Basis(),Vector3(0,n.h*0.5,0))
	return sb

func _cache_wert(v):
	if v is Object:return null
	if v is Dictionary:
		var d={}
		for k in v:
			var w=_cache_wert(v[k])
			if not (v[k] is Object):d[k]=w
		return d
	if v is Array:
		var a=[]
		for e in v:a.append(_cache_wert(e))
		return a
	return v

func cache_speichern()->Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	kollision_bauen()
	if LV and LV.lampen_mat:set_meta("lampen_mat",LV.lampen_mat)
	# Gebäude werden im Spiel nach und nach eingeblendet (nur Daten speichern)
	var geb=get_node_or_null("Gebaeude")
	if geb:
		var fund=geb.get_node_or_null("Fundamente")
		if fund:geb.remove_child(fund);fund.name="Fundamente";add_child(fund)
		remove_child(geb);geb.free()
	_besitz(self)
	var ps=PackedScene.new();var e=ps.pack(self)
	if e!=OK:return e
	e=ResourceSaver.save(ps,CACHE_DIR+"welt.scn",ResourceSaver.FLAG_COMPRESS)
	var daten={"G":{"heights":G.heights,"nx":G.nx,"nz":G.nz,"holes":G.holes.keys()},
		"S":{"roads":_cache_wert(S.roads),"junctions":_cache_wert(S.junctions)},
		"B":{"placed":_cache_wert(B.placed),"occ":B.occ,"ox":B.ox,"oz":B.oz},
		"A":{"shops":_cache_wert(A.shops),"icons":_cache_wert(A.icons),"villen":_cache_wert(A.villen)}}
	var f=FileAccess.open(CACHE_DIR+"welt_daten.bin",FileAccess.WRITE);f.store_var(daten,false);f.close()
	return e

func _besitz(n:Node):
	for c in n.get_children():
		if c.owner==null:c.owner=self
		if c.scene_file_path=="":_besitz(c)
		else:_besitz_innen(c)
func _besitz_innen(n:Node):
	# in eingebundenen Szenen nur selbst hinzugefügte Knoten übernehmen
	for c in n.get_children():
		if c.owner==null:c.owner=self
		_besitz_innen(c)

# Daten nach dem Laden der fertigen Welt wiederherstellen
func aus_cache():
	var f=FileAccess.open(CACHE_DIR+"welt_daten.bin",FileAccess.READ)
	var d=f.get_var(false);f.close()
	G=GEL.new();G.heights=d.G.heights;G.nx=d.G.nx;G.nz=d.G.nz
	for h in d.G.holes:G.holes[h]=true
	S=STR.new(G);S.roads=d.S.roads;S.junctions=d.S.junctions
	B=BAU.new(G,S);B.spiel=true;B.placed=d.B.placed;B.occ=d.B.occ;B.ox=d.B.ox;B.oz=d.B.oz
	A=ANL.new(G,S,B);A.shops=d.A.shops;A.icons=d.A.icons;A.villen=d.A.villen
	var geb=Node3D.new();geb.name="Gebaeude";add_child(geb)

func _after(t0):
	print("WELT Gelände+Straßen ",Time.get_ticks_msec()-t0," ms, Straßen ",S.roads.size()," Kreuzungen ",S.junctions.size())
	for r in S.roads:
		var tn=r.tunnel_flags.count(true);var el=r.elev.count(true)
		var cutmax=0.0
		for i in r.P.size():if not r.tunnel_flags[i]:cutmax=max(cutmax,r.raw[i]-r.h[i])
		var runs=[];var i0=-1
		for i in r.P.size()+1:
			var e=i<r.P.size() and r.elev[i]
			if e and i0<0:i0=i
			if not e and i0>=0:
				var mx=0.0
				for k in range(i0,i):mx=max(mx,r.h[k]-r.raw[k])
				runs.append("%s-%s(+%.0f)"%[str(r.P[i0].round()),str(r.P[i-1].round()),mx]);i0=-1
		if runs.size()>0:print("    Brücken: ",runs)
		if false:
			var dbg=[]
			for i in range(0,r.P.size(),25):dbg.append("%d:%.0f/%.0f/%.0f"%[i,r.raw[i],r.h[i],r.hint[i]])
			print("    DBG ",dbg)
		if tn>0 or el>0 or cutmax>6:print("  ",r.typ," ",r.name," Tunnel ",tn*4," m, Brücke ",el*4," m, max Einschnitt ",snapped(cutmax,0.1))
	if "debug" in args:
		print("HOLES ",G.holes.size())
		for k in G.nz:
			for i in G.nx:
				var x=G.X0+i*G.STEP;var z=G.Z0+k*G.STEP
				if G.heights[G.idx(i,k)]<0.5 and G.island(x,z)>=1.0:print("TIEF ",x," ",z," ",G.heights[G.idx(i,k)])
		for h in G.holes:print("LOCH ",h," ",G.X0+h.x*G.STEP," ",G.Z0+h.y*G.STEP)
		get_tree().quit();return
	_env()
	_shots()

func _water():
	var w=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(200000,200000);w.mesh=pm;add_child(w);w.position.y=0.0
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.05,0.16,0.21);m.metallic=0.25;m.roughness=0.08;m.metallic_specular=0.9
	var nt=NoiseTexture2D.new();nt.seamless=true;nt.as_normal_map=true;nt.bump_strength=5.0;var fn=FastNoiseLite.new();fn.frequency=0.03;nt.noise=fn;nt.width=512;nt.height=512
	m.normal_enabled=true;m.normal_texture=nt;m.normal_scale=0.5;m.uv1_scale=Vector3(8000,8000,1)
	w.material_override=m;water_mat=m
var water_mat:StandardMaterial3D
func _process(d):
	if water_mat:water_mat.uv1_offset+=Vector3(d*0.004,d*0.0025,0)

var sun:DirectionalLight3D
func _env():
	sun=load("res://scripts/env.gd").make(self,"day")
	for c in get_children():
		if c is WorldEnvironment:
			var e:Environment=c.environment;e.fog_density=0.00022;e.fog_aerial_perspective=0.7;e.ssao_enabled=false
	sun.directional_shadow_max_distance=400.0

func _shots():
	var cam=Camera3D.new();cam.far=9000;cam.near=0.3;add_child(cam)
	var list=[]
	var mode=args[0] if args.size()>0 else "luft"
	if mode=="luft":
		list=[[Vector3(600,1500,2300),Vector3(0,0,0),45.0],[Vector3(-400,700,1500),Vector3(-300,0,500),50.0],[Vector3(1500,500,-800),Vector3(300,0,-300),50.0],
			[Vector3(-1800,600,200),Vector3(-900,50,-400),50.0],[Vector3(1200,300,700),Vector3(900,0,300),55.0]]
	if mode=="anlagen":
		for e in [[560,60,-160,690,10,60,55.0],[640,4,-70,705,4,60,60.0],[820,45,520,720,5,640,55.0],[1500,40,120,1600,10,350,60.0],[-780,30,420,-900,5,520,55.0],[-990,6,610,-930,4,540,60.0]]:
			var gy=G.h_at(e[0],e[2]);var ly=G.h_at(e[3],e[5])
			list.append([Vector3(e[0],gy+e[1],e[2]),Vector3(e[3],ly+e[4],e[5]),e[6]])
		for sp in A.shops:
			var c=v3(sp.c,sp.y);var fw=Vector3(sin(sp.yaw),0,cos(sp.yaw))
			list.append([c+fw*(sp.d*0.5+16)+Vector3(0,3,0)+fw.cross(Vector3.UP)*6,c+Vector3(0,3,0),60.0])
	if mode=="tunnel" or mode=="alles":
		for r in [named.ring,named.bahn]:
			for i in range(1,r.P.size()):
				if r.tunnel_flags[i] and not r.tunnel_flags[i-1]:
					var s0=(i-18)*4.0
					list.append(street_cam(r,s0,-4.0,4.0,72.0))
					var a=S.at(r,s0+30);var nn=Vector2(-a[2].y,a[2].x)
					list.append([v3(a[0]+nn*60-a[2]*40,a[1]+45),v3(S.at(r,i*4.0)[0],S.at(r,i*4.0)[1]),55.0])
					break
	if mode=="pfuetze":
		list.append([Vector3(-450,250,750),Vector3(-450,0,580),55.0])
		list.append([Vector3(-150,250,620),Vector3(-150,0,440),55.0])
		list.append([Vector3(-100,250,500),Vector3(-50,0,330),55.0])
	if mode=="luftfinal":
		list.append([Vector3(900,1250,1900),Vector3(-50,0,-100),48.0])
		list.append([Vector3(-150,520,1450),Vector3(-250,0,500),50.0])
	if mode=="final":
		list.append([Vector3(900,1250,1900),Vector3(-50,0,-100),48.0])
		list.append([Vector3(450,420,350),Vector3(-400,60,-700),55.0])
		list.append(street_cam(named.ghetto,215,-3.5,1.7,45))
		list.append(street_cam(named.ghetto,380,6.0,24.0,120))
		var dp=gpt(-110,-150);var dq=gpt(-110,60)
		list.append([v3(dp+Vector2(4,0),G.h_at(dp.x,dp.y)+1.8),v3(dq,G.h_at(dq.x,dq.y)+25),60.0])
		list.append(street_cam(named.allee,420,-6.5,2.2,70))
		list.append([Vector3(1255,G.h_at(1255,330)+2.0,330),Vector3(1330,G.h_at(1330,200)+14,180),60.0])
		var berg=S.roads_by_name("Bergstraße")
		list.append(street_cam(berg,1350,-2.0,9.0,90))
		list.append([Vector3(640,G.h_at(640,-160)+14,-160),Vector3(705,G.h_at(705,40)+3,40),55.0])
		list.append([Vector3(820,G.h_at(820,450)+60,450),Vector3(1480,10,380),55.0])
		list.append([Vector3(-1010,G.h_at(-1010,640)+7,640),Vector3(-890,G.h_at(-890,520)+5,520),58.0])
		for r in [named.ring]:
			for i in range(1,r.P.size()):
				if r.tunnel_flags[i] and not r.tunnel_flags[i-1]:
					list.append(street_cam(r,(i-25)*4.0,-5.0,4.0,90.0));break
	if mode=="neu":
		# Übersicht aller neuen Gebiete: [Ziel, Abstand, Höhe, Richtung]
		for e in [[Vector2(250,-350),900.0,700.0,0.4],[Vector2(-250,700),500.0,380.0,0.9],[Vector2(250,1650),700.0,500.0,0.2],[Vector2(2700,500),900.0,650.0,-0.3],
				[Vector2(500,2150),700.0,450.0,0.6],[Vector2(-2000,2050),1000.0,600.0,0.5],[Vector2(-2600,-5250),900.0,550.0,0.7],[Vector2(1750,-5950),350.0,220.0,0.3],
				[Vector2(-2150,-8800),900.0,550.0,0.8],[Vector2(550,-6200),1800.0,900.0,0.2],[Vector2(-700,-8300),1800.0,1100.0,0.5],[Vector2(1235,-3890),800.0,600.0,0.3],
				[Vector2(-300,-1700),700.0,500.0,0.2],[Vector2(-2150,-100),700.0,450.0,-0.9],[Vector2(-650,-2550),800.0,500.0,0.4],[Vector2(1960,1200),700.0,420.0,-0.5]]:
			var c:Vector2=e[0];var d=Vector2(sin(e[3]),cos(e[3]))*e[1];var gy=G.h_at(c.x,c.y)
			list.append([Vector3(c.x+d.x,gy+e[2],c.y+d.y),Vector3(c.x,gy,c.y),55.0])
		list.append(street_cam(named.ghetto,260,-3.0,1.8,40))
		list.append(street_cam(S.roads_by_name("Kaistraße"),900,-3.0,2.0,60))
		list.append(street_cam(S.roads_by_name("Flughafenallee"),500,-3.0,2.0,80))
		list.append(street_cam(S.roads_by_name("Hauptstraße Nordbucht"),500,-3.0,2.0,60))
		list.append(street_cam(named.a1,9000,-6.0,2.5,120))
		list.append(street_cam(S.roads_by_name("Staubweg"),60,-2.0,1.8,50))
	if mode=="strasse":
		list=[street_cam(named.ghetto,260,-3.0,1.8,40),street_cam(named.ghetto,520,2.0,2.5,60),street_cam(named.allee,700,-8.0,2.0,60),
			street_cam(named.allee,1150,-6.0,2.0,80),street_cam(named.allee,350,4.0,12.0,90),street_cam(named.hafen,300,3.0,3.0,70)]
	if mode=="karte":
		# Hochformat-Karte über einen eigenen Viewport (2 Pixel ≈ 10 m)
		for c in get_children():
			if c is WorldEnvironment:c.environment.fog_enabled=false
		sun.rotation_degrees=Vector3(-62,-150,0);sun.directional_shadow_max_distance=3000.0
		var vp=SubViewport.new();vp.size=Vector2i(1240,2380);vp.world_3d=get_viewport().world_3d;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(vp)
		var c2=Camera3D.new();vp.add_child(c2);c2.projection=Camera3D.PROJECTION_ORTHOGONAL;c2.keep_aspect=Camera3D.KEEP_HEIGHT;c2.size=G.Z1-G.Z0
		c2.position=Vector3((G.X0+G.X1)*0.5,2500,(G.Z0+G.Z1)*0.5);c2.rotation_degrees=Vector3(-90,0,0);c2.far=6000;c2.current=true
		var t=Timer.new();add_child(t);t.wait_time=1.0;t.one_shot=true;t.start()
		t.timeout.connect(func():
			var img=vp.get_texture().get_image();img.save_png(ProjectSettings.globalize_path("res://assets/ui/karte_basis.png"))
			var hw=(G.Z1-G.Z0)*0.5*1240.0/2380.0;var cx=(G.X0+G.X1)*0.5
			var f=FileAccess.open("res://assets/ui/karte_bereich.json",FileAccess.WRITE);f.store_string(JSON.stringify({"x0":cx-hw,"z0":G.Z0,"x1":cx+hw,"z1":G.Z1}));f.close()
			print("KARTE ",img.get_size())
			get_tree().quit())
		return
	var sh=load("res://scripts/shots.gd").new();add_child(sh);sh.setup(list,"welt_"+mode)

# Kamera auf einer Straße: s = Lauflänge, off = seitlich, hgt = Augenhöhe, ahead = Blickweite
func street_cam(r:Dictionary,s:float,off:float,hgt:float,ahead:float)->Array:
	var a=S.at(r,s);var b=S.at(r,s+ahead)
	var n=Vector2(-a[2].y,a[2].x)
	var p=a[0]+n*off;var q=b[0]+n*off*0.3
	return [Vector3(p.x,a[1]+hgt,p.y),Vector3(q.x,b[1]+hgt*0.6,q.y),62.0]

func _save_icons():
	var out=[]
	for i in A.icons:out.append({"typ":i[0],"x":i[1].x,"z":i[1].y,"name":i[2]})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	var f=FileAccess.open("res://assets/ui/karte_icons.json",FileAccess.WRITE);f.store_string(JSON.stringify(out," "));f.close()
