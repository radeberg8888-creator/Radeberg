extends SceneTree
# NEUE WELT (ersetzt die Comic-Stadt + Südhälfte): ganze Stadt nach dem Straßennetz der alten Karte (vor dem Comic-Umbau).
#  - Ein glattes Höhenfeld für die ganze Stadt (Straßen, Gehwege, Häuser, Gleise, Bausätze) -> keine Stufen, nichts schwebt.
#  - Netz bereinigt (Doppelte weg, lose Enden angebunden), große Blöcke bekommen Querstraßen.
#  - Blöcke = Stadtfläche minus Fahrbahnen: Innenstadt-Viertel mit gemalten Fassadenhäusern (stadt_lib, Handy-Fassung),
#    Vororte/Ghetto/Strand/Hafen/Industrie mit Bausätzen (neu_sued.gd).
#  - Bahn durchgehend mit Bahnübergängen, Autobahn als Hochstraße mit Rampen.
#  - Der Norden außerhalb der Stadt kommt wie bisher aus nord_lib (Gelände an der Stadtgrenze angeglichen).
# Ausgabe wie comic_welt_bake: assets/cache/comic/welt.scn + daten.bin + Kacheln + kits/
const ZIEL:="res://assets/cache/comic/"
const CX:=-200.0
const CZ:=500.0
const H0:=7.0
const KACHEL:=300.0
const DS:=4.0
const STADT:=Rect2(-3150,-1750,6600,4420)    # Welt: ganze Stadt der alten Karte (Süd + Nordhälfte)
const MST:=10.0
var C:=Vector2(CX,CZ)
var W:Node3D;var STN:Node3D
var L;var GL;var K;var SU;var G0
var NAT0:PackedFloat32Array
var BER:={}
var NETZ:=[]       # {n,P(lokal),w,typ}
var BAHN:=[];var UEBERGANG:=[];var SCHRANKEN:=[]
var AB:=[];var RAMPEN:=[]
var ALLE_FL:=[]     # bebaute Stadtflächen (Fassadenblöcke, Hafen, Industrie, Flughafen; lokal) – Natur bleibt draußen
var N               # natur_lib
var NATUR_ORTE:=[]  # {art, p (Welt), yaw}
var NATUR_FERN:=[] # [kit, Transform3D Welt] dünner Fernwald (immer geladen)
# Raster über STADT (10 m): Stadtfläche (nahe Straße, Land), Wasser
var MNX:int;var MNZ:int;var MX0:float;var MZ0:float
var FLAECHE:PackedByteArray;var WASS:PackedByteArray
var FASSADE_STILE:=["fassade"]
var t0:=0

func _init():
	await process_frame
	t0=Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ZIEL+"kits/"))
	W=Node3D.new();W.name="WeltComic";W.set_script(load("res://scripts/comic/welt_comic.gd"));root.add_child(W)
	STN=Node3D.new();STN.name="Stadt";W.add_child(STN);STN.position=Vector3(CX,0,CZ)
	L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(STN,11)
	L.spiel_modus=true;L.SPH.radial_segments=9;L.SPH.rings=5;L.CYL.radial_segments=8
	L.kompakt=true;L.kachel=150.0;L.kachel_modul=250.0;L.weit_detail=330.0;L.weit_ink=170.0;L.weit_modul=200.0;L.mat_cache=true
	GL=load("res://scripts/comic/ghetto_lib.gd").new(L);K=load("res://scripts/comic/kit_lib.gd").new(L)
	G0=load("res://scripts/welt_gelaende.gd").new()
	NAT0=G0._nh.duplicate()
	var d=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/alte_karte.json"))
	_mark("start")
	_feld()
	_raster(d)
	_netz_laden(d)
	SU=load("res://scripts/comic/neu_sued.gd").new(L,GL,K,G0)
	SU.VR=VR
	_netz_bereinigen()
	_bahn_laden(d);_autobahn_laden(d)
	_mark("netz")
	var faces=_flaechen_teilen()
	_mark("flaechen")
	_stadt_bauen(faces,d)
	_mark("stadt")
	var ND=_norden()
	_mark("norden")
	_gelaende_und_daten(ND)
	_mark("fertig")
	print("BERICHT ",JSON.stringify(BER))
	var f=FileAccess.open("user://welt_neu_bericht.json",FileAccess.WRITE);f.store_string(JSON.stringify(BER,"  "));f.close()
	quit()

func _mark(n:String):print("ZEIT ",n," ",(Time.get_ticks_msec()-t0)/1000.0," s  RAM ",OS.get_static_memory_usage()/1048576," MB")
func lok(q)->Vector2:return Vector2(q[0],q[1])-C
func FY(p:Vector2)->float:return L.FY(p.x,p.y)

# ================= 1. Höhenfeld =================
func _feld():
	var rand=320.0;var c=4.0
	var x0=STADT.position.x-rand;var z0=STADT.position.y-rand
	var n=int((STADT.size.x+rand*2)/c)+1;var m=int((STADT.size.y+rand*2)/c)+1
	var H=PackedFloat32Array();H.resize(n*m)
	for k in m:
		for i in n:
			var x=x0+i*c;var z=z0+k*c
			H[k*n+i]=max(G0._nat(x,z),1.4)    # Wasser zählt als Ufer (sonst zieht das Glätten die Stadt ins Meer)
	# glätten bis keine Stelle der Stadt (ohne Rand) steiler als 8,5 % ist
	var durch=0;var g=1.0
	var i0=int(rand/c);var k0=int(rand/c);var i1=n-i0;var k1=m-k0
	while durch<6:
		for q in 2:H=_box(H,n,m,9)
		durch+=1;g=_max_steig_teil(H,n,m,c,i0,k0,i1,k1)
		if g<0.085:break
	# wo Berge zu steil bleiben: Steigung hart begrenzen (Kegel), dann Knicke weich machen
	for runde in 3:
		if g<0.085:break
		_steig_begrenzen(H,n,m,0.075*c)
		for q in 2:H=_box(H,n,m,4)
		g=_max_steig_teil(H,n,m,c,i0,k0,i1,k1);durch+=1
	for i in H.size():H[i]=max(H[i],1.6)
	BER["steigung_max_%"]=snapped(g*100.0,0.1)
	L.HF=H;L.HF_N=n;L.HF_M=m;L.HF_C=c;L.HF_X0=x0-CX;L.HF_Z0=z0-CZ
	L.LGX0=STADT.position.x-CX-20;L.LGZ0=STADT.position.y-CZ-20;L.LGW=STADT.size.x+40;L.LGH=STADT.size.y+40
	# Gelände der Insel an das Feld angleichen (Land), mit 300 m Übergang nach außen
	var rx=G0.rx;var X0=G0.X0;var Z0=G0.Z0;var ST=G0.STEP
	for k in G0.rz:
		for i in rx:
			var x=X0+i*ST;var z=Z0+k*ST;var j=k*rx+i
			if NAT0[j]<1.0:continue
			var dx=max(max(STADT.position.x-x,x-STADT.end.x),0.0);var dz=max(max(STADT.position.y-z,z-STADT.end.y),0.0)
			var dd=sqrt(dx*dx+dz*dz)
			if dd>300.0:continue
			G0._nh[j]=lerp(L.FY(x-CX,z-CZ),NAT0[j],smoothstep(0.0,300.0,dd))
	print("FELD Steigung ",BER["steigung_max_%"],"% nach ",durch," Durchgängen")
func _box(H:PackedFloat32Array,n:int,m:int,r:int)->PackedFloat32Array:
	var A=PackedFloat32Array();A.resize(n*m)
	for k in m:
		var s=0.0;var cnt=float(2*r+1)
		for i in range(-r,r+1):s+=H[k*n+clampi(i,0,n-1)]
		for i in n:
			A[k*n+i]=s/cnt
			s+=H[k*n+clampi(i+r+1,0,n-1)]-H[k*n+clampi(i-r,0,n-1)]
	var B=PackedFloat32Array();B.resize(n*m)
	for i in n:
		var s=0.0;var cnt=float(2*r+1)
		for k in range(-r,r+1):s+=A[clampi(k,0,m-1)*n+i]
		for k in m:
			B[k*n+i]=s/cnt
			s+=A[clampi(k+r+1,0,m-1)*n+i]-A[clampi(k-r,0,m-1)*n+i]
	return B
func _steig_begrenzen(H:PackedFloat32Array,n:int,m:int,dh:float):
	for sweep in 2:
		for k in m:
			var o=k*n
			for i in range(1,n):H[o+i]=clamp(H[o+i],H[o+i-1]-dh,H[o+i-1]+dh)
			for i in range(n-2,-1,-1):H[o+i]=clamp(H[o+i],H[o+i+1]-dh,H[o+i+1]+dh)
		for i in n:
			for k in range(1,m):H[k*n+i]=clamp(H[k*n+i],H[(k-1)*n+i]-dh,H[(k-1)*n+i]+dh)
			for k in range(m-2,-1,-1):H[k*n+i]=clamp(H[k*n+i],H[(k+1)*n+i]-dh,H[(k+1)*n+i]+dh)
func _max_steig_teil(H:PackedFloat32Array,n:int,m:int,c:float,i0:int,k0:int,i1:int,k1:int)->float:
	var g=0.0
	for k in range(max(k0,1),min(k1,m-1),2):
		for i in range(max(i0,1),min(i1,n-1),2):
			var gx=(H[k*n+i+1]-H[k*n+i-1])/(2*c);var gz=(H[(k+1)*n+i]-H[(k-1)*n+i])/(2*c)
			g=max(g,gx*gx+gz*gz)
	return sqrt(g)
func _max_steig(H:PackedFloat32Array,n:int,m:int,c:float)->float:
	var g=0.0
	for k in range(1,m-1,2):
		for i in range(1,n-1,2):
			var gx=(H[k*n+i+1]-H[k*n+i-1])/(2*c);var gz=(H[(k+1)*n+i]-H[(k-1)*n+i])/(2*c)
			g=max(g,gx*gx+gz*gz)
	return sqrt(g)

# ================= 2. Raster: Viertel-Stil, Wasser =================
var VR:={}
func _viertel_stil(dn:String,w:Vector2)->String:
	match dn:
		"downtown","altstadt","stern","kowloon":return "fassade"
		"stadt","oststadt":
			# Kern dicht (Fassaden), außen Reihenhäuser/Blocks
			if w.distance_to(Vector2(250,-350))<1000.0 or w.distance_to(Vector2(2550,850))<450.0:return "fassade"
			return "sued"
		"ghetto":return "ghetto"
		"strand","sandufer":return "strand"
		"docks":return "docks"
		"industrie":return "industrie"
		_:return "sued"
func _raster(d):
	MX0=STADT.position.x;MZ0=STADT.position.y;MNX=int(STADT.size.x/MST)+1;MNZ=int(STADT.size.y/MST)+1
	WASS=PackedByteArray();WASS.resize(MNX*MNZ)
	for k in MNZ:
		for i in MNX:
			if G0._bilin(NAT0,MX0+i*MST,MZ0+k*MST)<1.0:WASS[k*MNX+i]=1
	# Viertel-Stil: Mehrheit der alten Häuser je 20-m-Zelle, dann in Lücken ausbreiten
	var zaehl={}
	for b in d.bau:
		var w=Vector2(b.c[0],b.c[1])
		if not STADT.grow(50).has_point(w):continue
		var c=Vector2i(int(floor(w.x/20.0)),int(floor(w.y/20.0)))
		var st=_viertel_stil(b.d,w)
		if not zaehl.has(c):zaehl[c]={}
		zaehl[c][st]=zaehl[c].get(st,0)+1
	var q=[]
	for c in zaehl:
		var best="";var bn=0
		for st in zaehl[c]:
			if zaehl[c][st]>bn:bn=zaehl[c][st];best=st
		VR[c]=best;q.append(c)
	var h=0
	while h<q.size():
		var c=q[h];h+=1
		for dd in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var n=c+dd
			if VR.has(n):continue
			var w=Vector2(n.x*20.0,n.y*20.0)
			if not STADT.grow(60).has_point(w):continue
			VR[n]=VR[c];q.append(n)
	# Flughafen (alte Rollbahn) und Docks-Ufer nach Lage
	for c in VR.keys():
		var w=Vector2(c.x*20.0,c.y*20.0)
		if w.x<-1250 and w.y>1860:VR[c]="flug"
	print("RASTER Viertelzellen ",VR.size())

# ================= 3. Netz =================
func _netz_laden(d):
	var rr=Rect2(STADT.position-C,STADT.size).grow(30.0)
	var breite={"allee":7.0,"strasse":5.0,"gasse":3.4,"land":5.0}
	for r in d.roads:
		if not r.typ in breite:continue
		var cur=PackedVector2Array()
		for q in r.P:
			var p=lok(q)
			if rr.has_point(p):cur.append(p)
			else:
				if cur.size()>=3:NETZ.append({"P":cur,"w":breite[r.typ],"typ":r.typ,"n":r.name})
				cur=PackedVector2Array()
		if cur.size()>=3:NETZ.append({"P":cur,"w":breite[r.typ],"typ":r.typ,"n":r.name})
	for r in NETZ:r.P=_glatt(_dichte(r.P,DS))
	BER["strassen_alt"]=NETZ.size()
func _dichte(P:PackedVector2Array,ds:float)->PackedVector2Array:
	var Q=PackedVector2Array([P[0]]);var acc=0.0
	for i in range(1,P.size()):
		var a=P[i-1];var b=P[i];var l=a.distance_to(b)
		if l<0.001:continue
		var s=ds-acc
		while s<=l:Q.append(a.lerp(b,s/l));s+=ds
		acc=l-(s-ds)
	if Q[Q.size()-1].distance_to(P[P.size()-1])>0.5:Q.append(P[P.size()-1])
	return Q
func _ohne_doppelte(P:PackedVector2Array)->PackedVector2Array:
	var Q=PackedVector2Array([P[0]])
	for i in range(1,P.size()):
		if P[i].distance_to(Q[Q.size()-1])>0.05:Q.append(P[i])
	if Q.size()<2:Q.append(P[P.size()-1]+Vector2(0.1,0))
	return Q
func _glatt(P:PackedVector2Array)->PackedVector2Array:
	if P.size()<5:return P
	var Q=P.duplicate()
	for it in 3:
		var A=Q.duplicate()
		for i in range(1,Q.size()-1):A[i]=Q[i-1]*0.25+Q[i]*0.5+Q[i+1]*0.25
		Q=A
	return Q
func _len(P:PackedVector2Array)->float:
	var s=0.0
	for i in range(1,P.size()):s+=P[i].distance_to(P[i-1])
	return s
func _am_rand(p:Vector2)->bool:
	var r=Rect2(STADT.position-C,STADT.size)
	return p.x<r.position.x+20 or p.y<r.position.y+20 or p.x>r.end.x-20 or p.y>r.end.y-20
func _netz_bereinigen():
	# a) doppelt übereinanderliegende Straßen
	SU.netz_setzen(NETZ)
	var weg={}
	for i in NETZ.size():
		var P:PackedVector2Array=NETZ[i].P;var auf=0;var n=0;var l=_len(P)
		for k in range(0,P.size(),2):
			n+=1
			var ns=SU.naechst(P[k],i)
			if ns[2]>=0 and not weg.has(ns[2]) and ns[3]<NETZ[ns[2]].w+NETZ[i].w*0.6 and _len(NETZ[ns[2]].P)>=l:auf+=1
		if auf>=n*0.6:weg[i]=true
	BER["doppelt_entfernt"]=weg.size()
	var neu=[];for i in NETZ.size():
		if not weg.has(i):neu.append(NETZ[i])
	NETZ=neu
	# b) lose Enden anbinden / verlängern / Stummel weg
	var an=0;var verl=0;var ent=0
	for runde in 2:
		SU.netz_setzen(NETZ)
		var weg2={}
		for i in NETZ.size():
			for ende in [0,1]:
				var P:PackedVector2Array=NETZ[i].P
				var e:Vector2=P[0] if ende==0 else P[P.size()-1]
				var nb:Vector2=P[1] if ende==0 else P[P.size()-2]
				if _am_rand(e):continue
				var ns=SU.naechst(e,i)
				if ns[2]>=0 and ns[3]<NETZ[ns[2]].w*0.6:continue
				var ziel=null
				if ns[2]>=0 and ns[3]<30.0:ziel=ns[0];an+=1
				else:
					var dir=(e-nb).normalized()
					for st in range(4,92,4):
						var q=e+dir*st;var n2=SU.naechst(q,i)
						if n2[2]>=0 and n2[3]<NETZ[n2[2]].w*0.5:ziel=n2[0];break
					if ziel!=null:verl+=1
				if ziel==null:
					if _len(P)<70.0:weg2[i]=true
					continue
				var add=_dichte(PackedVector2Array([e,ziel]),DS)
				if ende==0:
					add.reverse();add.remove_at(add.size()-1);NETZ[i].P=add+P
				else:
					add.remove_at(0);NETZ[i].P=P+add
		ent+=weg2.size()
		var n2=[];for i in NETZ.size():
			if not weg2.has(i):n2.append(NETZ[i])
		NETZ=n2
	BER["enden_angebunden"]=an;BER["enden_verlaengert"]=verl;BER["stummel_entfernt"]=ent
	SU.netz_setzen(NETZ)

func _bahn_laden(d):
	var rr=Rect2(STADT.position-C,STADT.size).grow(60.0)
	for r in d.roads:
		if r.typ!="schiene" or r.name!="Bahn":continue
		var cur=PackedVector2Array();var stuecke=[]
		for q in r.P:
			var p=lok(q)
			if rr.has_point(p):cur.append(p)
			elif cur.size()>3:stuecke.append(cur);cur=PackedVector2Array()
		if cur.size()>3:stuecke.append(cur)
		for P0 in stuecke:
			var P=_glatt(_dichte(P0,3.0));BAHN.append({"P":P,"S":L._laengen(P)})
	for b in BAHN:
		var P:PackedVector2Array=b.P
		for i in P.size()-1:
			var mn=Vector2(min(P[i].x,P[i+1].x),min(P[i].y,P[i+1].y))
			for ri in NETZ.size():
				var Q:PackedVector2Array=NETZ[ri].P
				for q in Q.size()-1:
					if abs(Q[q].x-mn.x)>40.0 or abs(Q[q].y-mn.y)>40.0:continue
					var x=Geometry2D.segment_intersects_segment(P[i],P[i+1],Q[q],Q[q+1])
					if x==null:continue
					var neu=true
					for u in UEBERGANG:
						if u.p.distance_to(x)<20.0:neu=false
					if neu:UEBERGANG.append({"p":x,"t":(P[i+1]-P[i]).normalized(),"r":NETZ[ri],"tr":(Q[q+1]-Q[q]).normalized()})
	BER["bahnuebergaenge"]=UEBERGANG.size()
func _autobahn_laden(d):
	var rr=Rect2(STADT.position-C,STADT.size).grow(20.0)
	for r in d.roads:
		if r.typ!="autobahn" and r.typ!="rampe":continue
		var cur=PackedVector2Array();var stuecke=[]
		for q in r.P:
			var p=lok(q)
			if rr.has_point(p):cur.append(p)
			elif cur.size()>3:stuecke.append(cur);cur=PackedVector2Array()
		if cur.size()>3:stuecke.append(cur)
		for P0 in stuecke:
			var P=_glatt(_dichte(P0,3.0))
			if r.typ=="autobahn":AB.append({"P":P,"S":L._laengen(P),"w":9.0,"n":r.name})
			else:RAMPEN.append({"P":P,"S":L._laengen(P),"w":4.5,"n":"Rampe"})
	print("AUTOBAHN Stücke ",AB.size()," Rampen ",RAMPEN.size())

# ================= 4. Flächen (Blöcke) =================
# Fläche minus Bänder, mit Raumindex: jedes Band schneidet nur die Stücke, deren Rechteck es berührt
var _ST:=[]   # [poly, rect]
var LOECHER:=0
func _abziehen_idx(band:PackedVector2Array):
	var bb=L._bbox(band);var neu=[]
	for e in _ST:
		if not e[1].intersects(bb):neu.append(e);continue
		var res=Geometry2D.clip_polygons(e[0],band)
		var aussen=[];var loch=[]
		for x in res:
			if x.size()<3:continue
			if Geometry2D.is_polygon_clockwise(x):loch.append(x)
			else:aussen.append(x)
		for o in aussen:
			for h in loch:
				var hc=h[0]
				if not Geometry2D.is_point_in_polygon(hc,o):continue
				# Loch (z. B. Sackgasse mitten im Block) über einen 1,2 m breiten Durchgang zum Blockrand öffnen
				var c=Vector2.ZERO
				for v in h:c+=v
				c/=h.size()
				var bd=INF;var bp=c
				for i in o.size():
					var q=Geometry2D.get_closest_point_to_segment(c,o[i],o[(i+1)%o.size()])
					if q.distance_to(c)<bd:bd=q.distance_to(c);bp=q
				var hr=h.duplicate();hr.reverse()
				var schlitz=Geometry2D.offset_polyline(PackedVector2Array([c,bp+(bp-c).normalized()*2.0]),0.6)[0]
				var u=Geometry2D.merge_polygons(hr,schlitz)
				var ziel=hr
				for m in u:
					if not Geometry2D.is_polygon_clockwise(m):ziel=m
				var r2=Geometry2D.clip_polygons(o,ziel)
				var best=o;var ba=0.0
				for m in r2:
					if not Geometry2D.is_polygon_clockwise(m) and abs(L._flaeche2(m))>ba:ba=abs(L._flaeche2(m));best=m
				for m in r2:
					if m!=best and not Geometry2D.is_polygon_clockwise(m) and m.size()>=3:neu.append([m,L._bbox(m)])
				o=best;LOECHER+=1
			neu.append([o,L._bbox(o)])
	_ST=neu
func _baender(P:PackedVector2Array,w:float)->Array:
	var out=[]
	# lange Linien in Stücken (kleine Rechtecke -> schneller Index)
	var i=0
	while i<P.size()-1:
		var j=min(i+40,P.size()-1)
		out.append_array(Geometry2D.offset_polyline(P.slice(i,j+1),w,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND))
		i=j
	return out
func _flaechen()->Array:
	var rr=Rect2(STADT.position-C,STADT.size)
	_ST=[]
	# Startflächen: 300-m-Raster NUR zur Beschleunigung; danach Nachbarstücke an Rasterlinien wieder vereinen
	_ST=[[PackedVector2Array([rr.position,Vector2(rr.end.x,rr.position.y),rr.end,Vector2(rr.position.x,rr.end.y)]),rr]]
	for r in NETZ:
		for b in _baender(r.P,r.w):_abziehen_idx(b)
	for b in BAHN:
		for bd in _baender(b.P,5.0):_abziehen_idx(bd)
	for a in AB:
		for bd in _baender(a.P,a.w+3.0):_abziehen_idx(bd)
	var out=[]
	for e in _ST:out.append(e[0])
	return out
func _abdeckung(pc:PackedVector2Array)->float:
	var bb=L._bbox(pc);var n=0;var drin=0
	var x=bb.position.x+5.0
	while x<bb.end.x:
		var z=bb.position.y+5.0
		while z<bb.end.y:
			var p=Vector2(x,z)
			if Geometry2D.is_point_in_polygon(p,pc):
				n+=1
				if _stadtflaeche(p):drin+=1
			z+=10.0
		x+=10.0
	return float(drin)/max(n,1)
var _sf:={}
func _stadtflaeche(p:Vector2)->bool:   # lokal: Land, nicht weiter als 70 m von einer Straße
	var w=p+C;var i=int((w.x-MX0)/MST);var k=int((w.y-MZ0)/MST)
	if i<0 or k<0 or i>=MNX or k>=MNZ:return false
	if WASS[k*MNX+i]==1:return false
	var key=k*MNX+i
	if _sf.has(key):return _sf[key]
	var ns=SU.naechst(p)
	var ok=ns[2]>=0 and ns[3]<70.0
	_sf[key]=ok;return ok
func _flaechen_teilen()->Array:
	var neu_n=0;var st=[]
	for runde in 6:
		st=_flaechen();var geteilt=false
		var zusatz=[]
		for pc in st:
			var A=abs(L._flaeche2(pc))
			if A<7000:continue
			if _abdeckung(pc)<0.35:continue
			var c=Vector2.ZERO
			for v in pc:c+=v
			c/=pc.size()
			var sxx=0.0;var szz=0.0;var sxz=0.0
			for v in pc:
				var q=v-c;sxx+=q.x*q.x;szz+=q.y*q.y;sxz+=q.x*q.y
			var ang=0.5*atan2(2*sxz,sxx-szz);var ax=Vector2(cos(ang),sin(ang))
			var lo=INF;var hi=-INF
			for v in pc:
				var pr=(v-c).dot(ax);lo=min(lo,pr);hi=max(hi,pr)
			if hi-lo<130.0 and A<12000:continue
			var nrm=Vector2(-ax.y,ax.x)
			# mehrere Schnittlinien quer zur Längsachse probieren (Mitte zuerst)
			var gefunden=null
			for off in [0.0,0.18,-0.18,0.32,-0.32]:
				var m0=c+ax*(lo+hi)*0.5+ax*(hi-lo)*off
				if not Geometry2D.is_point_in_polygon(m0,pc):continue
				var xs=[]
				for i in pc.size():
					var x=Geometry2D.segment_intersects_segment(m0-nrm*800.0,m0+nrm*800.0,pc[i],pc[(i+1)%pc.size()])
					if x!=null:xs.append((x-m0).dot(nrm))
				xs.sort()
				var s0=-INF;var s1=INF
				for x in xs:
					if x<0:s0=x
					elif s1==INF:s1=x
				if s0==-INF or s1==INF or s1-s0<25.0:continue
				var p0=m0+nrm*s0;var p1=m0+nrm*s1
				var ok=true
				for pe in [[p0,-1.0],[p1,1.0]]:
					var p:Vector2=pe[0];var g=false
					for k in 16:
						var ns=SU.naechst(p)
						if ns[2]>=0 and ns[3]<0.8:g=true;break
						p+=nrm*pe[1]
					if not g:ok=false
					if pe[1]<0:p0=p
					else:p1=p
				if ok:gefunden=[p0,p1];break
			if gefunden==null:continue
			zusatz.append({"P":_dichte(PackedVector2Array([gefunden[0],gefunden[1]]),DS),"w":4.5,"typ":"strasse","n":"Querstraße"})
		for z in zusatz:NETZ.append(z);neu_n+=1;geteilt=true
		SU.netz_setzen(NETZ)
		print("TEILEN Runde ",runde," Flächen ",st.size()," neue Querstraßen ",zusatz.size())
		if not geteilt:break
	if neu_n>0:st=_flaechen()
	BER["loecher_geoeffnet"]=LOECHER;BER["querstrassen_neu"]=neu_n;BER["strassen"]=NETZ.size();BER["flaechen"]=st.size()
	return st

# ================= 5. Stadt bauen =================
func _stil_von(pc:PackedVector2Array)->String:
	var bb=L._bbox(pc);var z={}
	var x=bb.position.x+4.0
	while x<bb.end.x:
		var y=bb.position.y+4.0
		while y<bb.end.y:
			var p=Vector2(x,y)
			if Geometry2D.is_point_in_polygon(p,pc):
				var s=SU.stil(p);z[s]=z.get(s,0)+1
			y+=12.0
		x+=12.0
	var best="sued";var bn=-1
	for s in z:
		if z[s]>bn:bn=z[s];best=s
	return best
func _stadt_bauen(faces:Array,d):
	L.hoehen_an=true
	for r in NETZ:L._strasse(r.n,r.P,r.w,r.typ)
	SU.kreuzungen()
	for j in SU.JUNC:L.JN.append({"p":j.p,"r":j.r,"a":L.R[j.a],"b":L.R[j.b]})
	BER["kreuzungen"]=L.JN.size()
	_mark("kreuzungen")
	# Fahrbahnen + Bankett
	L.strassen_modus=true
	for r in NETZ:_fahrbahn(r)
	L.strassen_modus=false
	# Flächen einteilen
	var fass=[];var kit=[];var rand=[]
	for pc in faces:
		var A=abs(L._flaeche2(pc))
		var c=_abdeckung(pc)
		if c<0.3:rand.append(pc);continue
		var s=_stil_von(pc)
		if s=="fassade" or s=="sued":fass.append(pc)
		else:kit.append([pc,s])
	var dump={"fass":[],"kit":[],"rand":[]}
	for pc in fass:dump.fass.append(Array(pc).map(func(v):return [v.x+CX,v.y+CZ]))
	for e in kit:dump.kit.append({"s":e[1],"P":Array(e[0]).map(func(v):return [v.x+CX,v.y+CZ])})
	for pc in rand:dump.rand.append(Array(pc).map(func(v):return [v.x+CX,v.y+CZ]))
	var fd=FileAccess.open("user://welt_neu_flaechen.json",FileAccess.WRITE);fd.store_string(JSON.stringify(dump));fd.close()
	BER["bloecke_fassade"]=fass.size();BER["bloecke_bausatz"]=kit.size();BER["flaechen_rand"]=rand.size()
	print("FLAECHEN Fassade ",fass.size()," Bausatz ",kit.size()," Rand ",rand.size())
	_reservieren()
	# Fassaden-Viertel
	L.leicht=true
	L.lot_ok=func(lot:PackedVector2Array)->bool:
		var c=Vector2.ZERO
		for v in lot:c+=v
		c/=lot.size()
		for r in RESERVIERT:
			if Geometry2D.intersect_polygons(lot,r).size()>0:return false
		return _stadtflaeche(c)
	L.stock_fn=func(c:Vector2)->int:
		var w=c+C;var dd=w.distance_to(Vector2(250,-350))
		if SU.stil(c)=="sued":return 3 if dd<1400 else 2
		return 6 if dd<300 else (5 if dd<550 else (4 if dd<850 else 3))
	var nh=0;var nb=0
	var wk_poly=RESERVIERT[0] if not SU.WERKSTATT.is_empty() else PackedVector2Array()
	for pc in fass:
		if wk_poly.size()>0 and L._bbox(pc).intersects(L._bbox(wk_poly)):
			for teil in Geometry2D.clip_polygons(pc,wk_poly):
				if not Geometry2D.is_polygon_clockwise(teil):L._platte(teil,-1.6,L.KB,L.M.pflaster,L.M.stein)
		else:L._platte(pc,-1.6,L.KB,L.M.pflaster,L.M.stein)
		if abs(L._flaeche2(pc))<150:continue
		nb+=1;nh+=L._block(pc)
		if nb%10==0:L._fertig(false)
		if nb%50==0:print("  Fassadenblöcke ",nb,"/",fass.size()," Häuser ",nh," RAM ",OS.get_static_memory_usage()/1048576)
	BER["haeuser_fassade"]=nh
	_mark("fassaden")
	# Bausatz-Viertel: Gehweg-Ring + Grün, Bausätze kommen von neu_sued
	for e in kit:
		var pc:PackedVector2Array=e[0]
		L._platte(pc,-1.6,L.KB,L.M.pflaster,L.M.stein)
		for inn in Geometry2D.offset_polygon(pc,-2.6,Geometry2D.JOIN_MITER):
			if Geometry2D.is_polygon_clockwise(inn):continue
			L._platte(inn,L.KB,L.KB+0.01,L.M.gras if e[1]!="docks" and e[1]!="industrie" and e[1]!="flug" else L.M.hof,L.M.stein_d)
	L._fertig(false)
	# Straßenausstattung über alle Stadtblöcke
	var alle=fass.duplicate()
	for e in kit:alle.append(e[0])
	L.STADT_STUECKE=alle;ALLE_FL=fass.duplicate()
	for e in kit:
		if e[1] in ["docks","industrie","flug"]:ALLE_FL.append(e[0])
	L.strassen_modus=true;L._markierungen();L.strassen_modus=false
	_ampeln(fass)
	L.STADT_STUECKE=fass
	L._strassenmoebel()
	L._fertig(false)
	_mark("ausstattung")
	# Bahn + Autobahn
	L.strassen_modus=true
	_bahn_bauen()
	_autobahn_bauen()
	L.strassen_modus=false
	L._fertig(false)
	_mark("bahn/autobahn")
	# Bausätze: Maske = Stadtfläche in Bausatz-Vierteln, nicht in Fassadenblöcken, nicht Wasser
	_bausaetze(fass,d)
	_mark("bausaetze")

func _fahrbahn(r):
	var P:PackedVector2Array=r.P;var w:float=r.w+0.05;var n=P.size()
	var so=L._st(L.M.asphalt,true);var sb=L._st(L.M.stein_d,true);var a_k=L.koll_an;L.koll_an=true
	var N=[]
	for i in n:N.append(L._rn((P[min(i+1,n-1)]-P[max(i-1,0)]).normalized()))
	for i in n-1:
		var a=P[i]-N[i]*w;var b=P[i]+N[i]*w;var c=P[i+1]+N[i+1]*w;var dd=P[i+1]-N[i+1]*w
		L._tri(so,Vector3(a.x,0.015,a.y),Vector3(b.x,0.015,b.y),Vector3(c.x,0.015,c.y),Vector3.UP);L._tri(so,Vector3(a.x,0.015,a.y),Vector3(c.x,0.015,c.y),Vector3(dd.x,0.015,dd.y),Vector3.UP)
	L.koll_an=false
	# Bankett: schräg nach außen unter das Gelände (an Blöcken verdeckt die Gehwegplatte)
	for i in n-1:
		for sd in [-1.0,1.0]:
			var a=P[i]+N[i]*w*sd;var b=P[i+1]+N[i+1]*w*sd;var a2=P[i]+N[i]*(w+2.2)*sd;var b2=P[i+1]+N[i+1]*(w+2.2)*sd
			L._tri(sb,Vector3(a.x,0.015,a.y),Vector3(b.x,0.015,b.y),Vector3(b2.x,-0.55,b2.y),Vector3(N[i].x*sd,1,N[i].y*sd));L._tri(sb,Vector3(a.x,0.015,a.y),Vector3(b2.x,-0.55,b2.y),Vector3(a2.x,-0.55,a2.y),Vector3(N[i].x*sd,1,N[i].y*sd))
	L.koll_an=true
	for e in [0,n-1]:
		var c0=P[e]
		for k in 10:
			var a0=TAU*k/10.0;var a1=TAU*(k+1)/10.0
			L._tri(so,Vector3(c0.x,0.015,c0.y),Vector3(c0.x+cos(a0)*w,0.015,c0.y+sin(a0)*w),Vector3(c0.x+cos(a1)*w,0.015,c0.y+sin(a1)*w),Vector3.UP)
	L.koll_an=a_k
# Ampeln: an Kreuzungen größerer Straßen, je Ecke des nächsten Blocks (Raumindex statt alle Blöcke)
func _ampeln(bl:Array):
	var idx={}
	for pc in bl:
		if abs(L._flaeche2(pc))<120.0:continue
		for v in pc:
			var c=Vector2i(int(floor(v.x/30.0)),int(floor(v.y/30.0)))
			if not idx.has(c):idx[c]=[]
			idx[c].append(v)
	var n=0
	for k in L.JN:
		if k.a.typ in ["gasse","rampe"] or k.b.typ in ["gasse","rampe"]:continue
		var c0=Vector2i(int(floor(k.p.x/30.0)),int(floor(k.p.y/30.0)))
		var ecken=[]
		for dx in range(-1,2):
			for dz in range(-1,2):
				for v in idx.get(c0+Vector2i(dx,dz),[]):
					if v.distance_to(k.p)<max(k.a.w,k.b.w)+9.0:ecken.append(v)
		# je Quadrant die nächste Ecke
		var q={}
		for v in ecken:
			var dv=v-k.p;var key=int(dv.x>0)*2+int(dv.y>0)
			if not q.has(key) or q[key].distance_to(k.p)>v.distance_to(k.p):q[key]=v
		var gruen=true
		for key in q:
			var bv:Vector2=q[key];var dj=(k.p-bv).normalized();var p=bv-dj*0.8
			L._ampel(Vector3(p.x,L.KB,p.y),Vector3(dj.x,0,dj.y),gruen);gruen=not gruen;n+=1
	BER["ampeln"]=n

# ---------------- Bahn ----------------
func _bahn_bauen():
	var schotter=L._toon(Color(0.52,0.48,0.44));var schwelle=L._toon(Color(0.38,0.28,0.2));var schiene=L._toon(Color(0.55,0.56,0.6),0.3)
	for b in BAHN:
		var P:PackedVector2Array=b.P;var S:PackedFloat32Array=b.S;var Lg=S[S.size()-1]
		for bb in _baender(P,2.6):
			var teile=[bb]
			for r in NETZ:
				if not L._bbox(r.P).grow(r.w+1).intersects(L._bbox(bb)):continue
				var t2=[]
				for t in teile:
					for x in Geometry2D.clip_polygons(t,Geometry2D.offset_polyline(r.P,r.w+0.3)[0]):
						if not Geometry2D.is_polygon_clockwise(x):t2.append(x)
				teile=t2
			for pc in teile:L._platte(pc,-0.4,0.12,schotter,schotter)
		var s=0.0
		while s<Lg:
			var e=L._bei_s(P,S,s);var p:Vector2=e[0];var t:Vector2=e[1]
			var im=false
			for u in UEBERGANG:
				if u.p.distance_to(p)<u.r.w+1.6:im=true
			if not im:L.box(schwelle,Vector3(p.x,0.16,p.y),Vector3(2.5,0.09,0.24),Basis(Vector3.UP,atan2(t.x,t.y)+PI*0.5),0.0)
			s+=0.75
		for sd in [-0.72,0.72]:
			for i in P.size()-1:
				var a=P[i];var c=P[i+1];var t=(c-a).normalized();var m=(a+c)*0.5+L._rn(t)*sd;var im=false
				for u in UEBERGANG:
					if u.p.distance_to(m)<u.r.w+1.6:im=true
				L.box(schiene,Vector3(m.x,0.045 if im else 0.27,m.y),Vector3(0.09,0.12,a.distance_to(c)+0.02),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
		# Zaun
		for sd in [-4.8,4.8]:
			var s2=0.0
			while s2<Lg:
				var e=L._bei_s(P,S,s2);var p:Vector2=e[0];var t:Vector2=e[1];var q=p+L._rn(t)*sd;var q2=q+t*3.0
				var ns=SU.naechst(q);var ns2=SU.naechst(q2)
				var frei=(ns[2]<0 or ns[3]>NETZ[ns[2]].w+2.5) and (ns2[2]<0 or ns2[3]>NETZ[ns2[2]].w+2.5)
				if frei:
					L.box(L.M.metall,Vector3(q.x,0.75,q.y),Vector3(0.06,1.5,0.06),Basis(),0.0)
					for hy in [0.5,1.0,1.45]:L.box(L.M.metall,Vector3((q.x+q2.x)*0.5,hy,(q.y+q2.y)*0.5),Vector3(0.03,0.03,3.0),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
				s2+=3.0
	for u in UEBERGANG:_uebergang(u)
func _uebergang(u):
	var r=u.r;var tr:Vector2=u.tr;var tg:Vector2=u.t
	L.box(L.M.dunkel,Vector3(u.p.x,0.025,u.p.y),Vector3(2.2,0.02,(r.w*2.0+0.6)/max(abs(tg.dot(L._rn(tr))),0.4)),Basis(Vector3.UP,atan2(tg.x,tg.y)),0.0)
	for dir in [-1,1]:
		var t=tr*dir;var rr=L._rn(t)
		var cosw=abs(t.dot(L._rn(tg)));var vor=4.2/max(cosw,0.35)
		var fuss=u.p-t*vor+rr*(r.w+1.0);var f3=Vector3(fuss.x,L.KB,fuss.y)
		L.zyl(L.M.weiss,f3,f3+Vector3(0,3.2,0),0.07,1.2)
		var bk=Basis(Vector3.UP,atan2(t.x,t.y)+PI)
		for a in [PI*0.25,-PI*0.25]:L.box(L.M.rot,f3+Vector3(0,2.9,0)-Vector3(t.x,0,t.y)*0.09,Vector3(1.1,0.16,0.03),bk*Basis(Vector3.BACK,a),0.02)
		var lb=Vector3(f3.x,2.3,f3.z)-Vector3(t.x,0,t.y)*0.12
		L.box(L.M.dunkel,lb,Vector3(0.75,0.32,0.12),bk,0.02)
		for sx in [-0.2,0.2]:L.kugel(L.M.rot_l,lb+bk*Vector3(sx,0,-0.08),Vector3(0.11,0.11,0.05),1.0)
		var an=fuss+rr*0.6
		L.box(L.M.gelb,Vector3(an.x,0.75,an.y),Vector3(0.5,1.2,0.5),bk,0.03)
		var arm=Node3D.new();arm.name="Schranke";arm.position=Vector3(an.x,FY(an)+1.15,an.y);arm.rotation.y=atan2(-rr.x,-rr.y)
		arm.set_meta("bahn",true)
		for k in int((r.w+1.0)/0.8):
			var mi=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=Vector3(0.12,0.12,0.8);mi.mesh=bm
			mi.material_override=L.M.rot if k%2==0 else L.M.weiss;mi.position=Vector3(0,0,k*0.8+0.4);arm.add_child(mi)
		arm.rotation.x=-PI*0.47   # offen (im Spiel senkt der Zug sie)
		STN.add_child(arm)

# ---------------- Autobahn (Hochstraße, an der Stadtgrenze auf Gelände) ----------------
func _ab_hoehe(p:Vector2)->float:
	var r=Rect2(STADT.position-C,STADT.size)
	var dd=min(min(p.x-r.position.x,r.end.x-p.x),min(p.y-r.position.y,r.end.y-p.y))
	return L.H_AB*smoothstep(40.0,340.0,dd)
func _autobahn_bauen():
	for a in AB:
		var P:PackedVector2Array=a.P;var H=PackedFloat32Array()
		for p in P:H.append(_ab_hoehe(p))
		L.HW=a;L.RAMPEN=[]
		L._deck(P,H,a.w,1.2,true,true)
		var S:PackedFloat32Array=a.S;var Lg=S[S.size()-1];var s=1.0
		while s<Lg-1.0:
			var e=L._bei_s(P,S,s);var p:Vector2=e[0];var t:Vector2=e[1];var rn=L._rn(t);var h=_ab_hoehe(p)+0.01
			for sd in [-1,1]:
				for lat in [0.9,a.w-0.9]:
					var c=p+rn*lat*sd;L.box(L.M.markierung,Vector3(c.x,h,c.y),Vector3(0.15,0.012,2.6),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
				if fmod(s,12.0)<2.6:
					var c=p+rn*4.9*sd;L.box(L.M.markierung,Vector3(c.x,h,c.y),Vector3(0.15,0.012,4.5),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
			s+=2.5
		s=10.0
		while s<Lg:
			var e=L._bei_s(P,S,s);var p:Vector2=e[0];var t:Vector2=e[1];var rn=L._rn(t);var h=_ab_hoehe(p)
			if h>3.0:
				var frei=true
				for sd in [-1,1]:
					var ns=SU.naechst(p+rn*4.6*sd)
					if ns[2]>=0 and ns[3]<NETZ[ns[2]].w+1.5:frei=false
				if frei:
					for sd in [-1,1]:
						var c=p+rn*4.6*sd
						L.zyl(L.M.stein,Vector3(c.x,-0.5,c.y),Vector3(c.x,h-1.6,c.y),0.75,1.05);L.PFOSTEN.append([Vector3(c.x,0,c.y),0.75,h-1.6])
					L.box(L.M.stein,Vector3(p.x,h-1.95,p.y),Vector3(a.w*2.0-1.0,0.9,1.6),Basis(Vector3.UP,atan2(t.x,t.y))*Basis(Vector3.UP,PI*0.5),0.04)
			s+=26.0
	# Rampen: Höhe von Straße (Ende nahe Stadtstraße) bis Autobahn
	for rp in RAMPEN:
		var P:PackedVector2Array=rp.P;var S:PackedFloat32Array=rp.S;var Lg=S[S.size()-1]
		var n0=SU.naechst(P[0]);var n1=SU.naechst(P[P.size()-1])
		var unten_am_anfang=(n0[2]>=0 and n0[3]<12.0) or not (n1[2]>=0 and n1[3]<12.0)
		var H=PackedFloat32Array()
		for i in P.size():
			var u=S[i]/max(Lg,1.0)
			if not unten_am_anfang:u=1.0-u
			H.append(_ab_hoehe(P[i])*smoothstep(0.05,0.95,u))
		rp.H=H
		L._deck(P,H,rp.w,0.9,false,true,rp)
		var s=8.0
		while s<Lg:
			var i=clampi(S.bsearch(s),0,P.size()-1);var h=H[i];var p=P[i]
			if h>3.2:
				var ns=SU.naechst(p)
				if ns[2]<0 or ns[3]>NETZ[ns[2]].w+1.0:
					L.zyl(L.M.stein,Vector3(p.x,-0.5,p.y),Vector3(p.x,h-1.2,p.y),0.6,1.05);L.PFOSTEN.append([Vector3(p.x,0,p.y),0.6,h-1.2])
			s+=15.0

# ---------------- Bausätze ----------------
var RESERVIERT:=[]   # Grundrisse (lokal) von Werkstatt und Wachen: dort keine Fassadenhäuser
func _reservieren():
	var beb=PackedByteArray();beb.resize(MNX*MNZ)
	for k in MNZ:
		for i in MNX:
			var j=k*MNX+i
			if WASS[j]==0 and _stadtflaeche(Vector2(MX0+i*MST,MZ0+k*MST)-C):beb[j]=1
	SU.maske_setzen(MX0,MZ0,MST,MNX,MNZ,beb,WASS,Rect2(STADT.position-C,STADT.size))
	SU.dist_maske()
	for b in BAHN:SU.SONDER.append({"P":b.P,"w":3.0,"typ":"schiene"})
	for a in AB:SU.SPERR.append(a.P)
	SU._raster_sperren()
	var alt_l=L.leicht;L.leicht=false
	SU.kits_bauen()
	L.leicht=alt_l
	for z in [Vector2(-200,960),Vector2(-450,1150),Vector2(100,1300),Vector2(-700,900)]:
		if SU.WERKSTATT.is_empty():SU.werkstatt_reservieren(z)
	for e in [["polizei",Vector2(-60,1250)],["feuerwehr",Vector2(350,1700)],["taxi",Vector2(-420,1180)],["polizei",Vector2(1300,900)],
			["polizei",Vector2(300,-500)],["feuerwehr",Vector2(-700,-300)],["taxi",Vector2(800,-150)],["polizei",Vector2(-1000,-1300)]]:SU.dienst_reservieren(e[0],e[1])
	var rechteck=func(F:Vector2,yaw:float,w:float,dd:float)->PackedVector2Array:
		var au=Vector2(sin(yaw),cos(yaw));var t=Vector2(-au.y,au.x);var rein=-au
		return PackedVector2Array([F+t*(w*0.5+2),F-t*(w*0.5+2),F-t*(w*0.5+2)+rein*(dd+2),F+t*(w*0.5+2)+rein*(dd+2)])
	if not SU.WERKSTATT.is_empty():RESERVIERT.append(rechteck.call(SU.WERKSTATT.F,SU.WERKSTATT.yaw,21.0,27.0))
	for dd in SU.DIENSTE:
		var k=K.KITS["sv_"+dd.art];RESERVIERT.append(rechteck.call(dd.F,dd.yaw,k.w,k.d))
	print("RESERVIERT ",RESERVIERT.size())
func _bausaetze(fass:Array,d):
	var beb=PackedByteArray();beb.resize(MNX*MNZ)
	# Fassadenblöcke ausschließen
	var fr={}
	for pc in fass:
		var bb=L._bbox(pc)
		var x=bb.position.x
		while x<bb.end.x:
			var z=bb.position.y
			while z<bb.end.y:
				if Geometry2D.is_point_in_polygon(Vector2(x,z),pc):
					var w=Vector2(x,z)+C;fr[Vector2i(int((w.x-MX0)/MST),int((w.y-MZ0)/MST))]=true
				z+=5.0
			x+=5.0
	for k in MNZ:
		for i in MNX:
			var j=k*MNX+i
			if WASS[j]==1 or fr.has(Vector2i(i,k)):continue
			var p=Vector2(MX0+i*MST,MZ0+k*MST)-C
			if _stadtflaeche(p) and not SU.stil(p) in ["fassade","sued"]:beb[j]=1
	SU.MASKE=beb;SU.dist_maske()
	SU.grundstuecke()
	var hs=[]
	for b in d.bau:
		var w=Vector2(b.c[0],b.c[1])
		if STADT.has_point(w):hs.append(w)
	SU.hinterland(hs)
	SU.fuellen()
	SU.hafenkante()
	SU.flughafen()
	SU.parken_strasse()
	var pd=[]
	for p in SU.PLATZ:pd.append([p[0],p[1].origin.x+CX,p[1].origin.z+CZ])
	var fp=FileAccess.open("user://welt_neu_platz.json",FileAccess.WRITE);fp.store_string(JSON.stringify(pd));fp.close()
	BER["bausaetze"]=SU.PLATZ.size();BER["parkplaetze"]=SU.PARK.size()
	# Höhen: Bausatz auf die höchste Ecke seiner Grundfläche, Sockel bis ins Gelände
	var sockel=L._toon(Color(0.6,0.58,0.55))
	var neu=[]
	for p in SU.PLATZ:
		var xf:Transform3D=p[1];var k=K.KITS[p[0]]
		if p[0]=="dk_schiff":neu.append(p);continue
		var w:float=k.w;var dd:float=k.d
		var ys=[]
		for e in [Vector3(-w*0.5,0,0),Vector3(w*0.5,0,0),Vector3(-w*0.5,0,-dd),Vector3(w*0.5,0,-dd),Vector3(0,0,-dd*0.5)]:
			var q=xf*e;ys.append(L.FY(q.x,q.z))
		var hi=ys.max();var lo=ys.min()
		xf.origin.y=hi;neu.append([p[0],xf])
		if hi-lo>0.12:
			var mitte=xf*Vector3(0,0,-dd*0.5)
			var sh=hi-lo+0.4
			L.strassen_modus=false;L.fest_modus=true
			L.box(sockel,Vector3(mitte.x,hi-sh*0.5+L.KB-0.02,mitte.z),Vector3(w-0.2,sh,dd-0.2),xf.basis,0.03)
			L.fest_modus=false
	SU.PLATZ=neu
	for i in SU.PARK.size():
		var o:Vector3=SU.PARK[i][1].origin;o.y+=L.FY(o.x,o.z)+0.2;SU.PARK[i][1].origin=o
	# Kits ausgeben (Kacheln 150 m) in den Stadtknoten
	var mats={}
	for kn in K.KITS:
		for m in [K.KITS[kn].mesh,K.KITS[kn].ink]:
			if m==null:continue
			for si in m.get_surface_count():
				var mt=m.surface_get_material(si)
				if mt:mats[mt]=true
	_mats_extern(mats)
	for kn in K.KITS:
		if K.KITS[kn].mesh.resource_path!="":continue
		var pfad=ZIEL+"kits/"+kn+".res"
		ResourceSaver.save(K.KITS[kn].mesh,pfad,ResourceSaver.FLAG_COMPRESS);K.KITS[kn].mesh.take_over_path(pfad)
		if K.KITS[kn].ink!=null:
			var pi=ZIEL+"kits/"+kn+"_ink.res"
			ResourceSaver.save(K.KITS[kn].ink,pi,ResourceSaver.FLAG_COMPRESS);K.KITS[kn].ink.take_over_path(pi)
var _nmat:=0;var _nsh:=0
func _mats_extern(mats:Dictionary):
	var shs={}
	for mt in mats:
		if mt.resource_path!="":continue
		if mt is ShaderMaterial and mt.shader and mt.shader.resource_path=="" and not shs.has(mt.shader):
			var sp=ZIEL+"kits/shader_%d.gdshader"%_nsh;_nsh+=1
			ResourceSaver.save(mt.shader,sp);mt.shader.take_over_path(sp);shs[mt.shader]=true
		var mp=ZIEL+"kits/mat_%d.res"%_nmat;_nmat+=1
		ResourceSaver.save(mt,mp);mt.take_over_path(mp)

# ================= 5b. Natur (natur_lib): Sonderorte + Bewuchs auf der ganzen Insel =================
var NM:=PackedByteArray();var NM_X0:=0.0;var NM_Z0:=0.0;var NM_NX:=0;var NM_NZ:=0;const NM_ST:=4.0
var SONDER_FREI:=[]   # [Welt-Mitte, Radius]
func _natur_maske():
	# 4-m-Raster über Stadt + Rand: 1 = Stadtfläche, Gleis, Autobahn (dort kein Bewuchs)
	var r=STADT.grow(300.0);NM_X0=r.position.x;NM_Z0=r.position.y;NM_NX=int(r.size.x/NM_ST)+1;NM_NZ=int(r.size.y/NM_ST)+1
	NM.resize(NM_NX*NM_NZ);NM.fill(0)
	for pc in ALLE_FL:
		var bb=L._bbox(pc)
		for k in range(int((bb.position.y+C.y-NM_Z0)/NM_ST),int((bb.end.y+C.y-NM_Z0)/NM_ST)+1):
			for i in range(int((bb.position.x+C.x-NM_X0)/NM_ST),int((bb.end.x+C.x-NM_X0)/NM_ST)+1):
				if i<0 or k<0 or i>=NM_NX or k>=NM_NZ:continue
				if Geometry2D.is_point_in_polygon(Vector2(NM_X0+i*NM_ST,NM_Z0+k*NM_ST)-C,pc):NM[k*NM_NX+i]=1
	var linien=[]
	for b in BAHN:linien.append([b.P,6.0])
	for a in AB+RAMPEN:linien.append([a.P,a.get("w",9.0)+6.0])
	for li in linien:
		var P:PackedVector2Array=li[0];var R:float=li[1]
		for i in P.size()-1:
			var a=P[i]+C;var b=P[i+1]+C;var lg=a.distance_to(b);var s=0.0
			while s<=lg:
				var q=a.lerp(b,s/max(lg,0.01))
				for k in range(int((q.y-R-NM_Z0)/NM_ST),int((q.y+R-NM_Z0)/NM_ST)+1):
					for ii in range(int((q.x-R-NM_X0)/NM_ST),int((q.x+R-NM_X0)/NM_ST)+1):
						if ii<0 or k<0 or ii>=NM_NX or k>=NM_NZ:continue
						if Vector2(NM_X0+ii*NM_ST,NM_Z0+k*NM_ST).distance_to(q)<=R:NM[k*NM_NX+ii]=1
				s+=3.0
func _nm(w:Vector2)->bool:
	var i=int((w.x-NM_X0)/NM_ST+0.5);var k=int((w.y-NM_Z0)/NM_ST+0.5)
	if i<0 or k<0 or i>=NM_NX or k>=NM_NZ:return false
	return NM[k*NM_NX+i]==1
func _natur_ok(NL,w:Vector2)->int:   # 0 nein, 1 Landschaft, 2 Stadtgrün
	for f in SONDER_FREI:
		if w.distance_to(f[0])<f[1]:return 0
	if not STADT.grow(260.0).has_point(w):return NL._land_ok(w,4.0)
	var i=NL._ix(w.x);var k=NL._kz(w.y)
	if i<1 or k<1 or i>=NL.GNX-1 or k>=NL.GNZ-1:return 0
	var j=k*NL.GNX+i
	if NL.WASSER[j]==1 or NAT0[G0rj(w)]<1.0:return 0
	if _nm(w):return 0
	var p=w-C
	if SU.frei(p)<4.0:return 0
	for d in [Vector2.ZERO,Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3)]:
		if SU._belegt(p+d):return 0
	if not STADT.has_point(w) and (NL.frei(p)<4.0 or NL._belegt(p)):return 0
	return 2
func G0rj(w:Vector2)->int:
	var i=clampi(int((w.x-G0.X0)/G0.STEP+0.5),0,G0.rx-1);var k=clampi(int((w.y-G0.Z0)/G0.STEP+0.5),0,G0.rz-1);return k*G0.rx+i
func _natur_h(NL,w:Vector2)->float:
	if STADT.has_point(w):return L.FY(w.x-C.x,w.y-C.y)
	return NL.h_end(w)
func _trocken(w:Vector2)->float:
	# Wüste nur in den echten Wüstengebieten (Sandboden, weit weg von der Stadt, nicht am Strand)
	if STADT.grow(500.0).has_point(w):return 0.0
	var j=G0rj(w)*4;return G0._bo[j+2]/255.0
func _natur(NL):
	var t0=Time.get_ticks_msec();_natur_maske();print("NATUR Maske ",Time.get_ticks_msec()-t0," ms")
	var n0=NL.PLATZ.size();var nb=0;var st={};var RS:=7.0
	var x=-4300.0
	while x<4600.0:
		var z=-11200.0
		while z<3400.0:
			var w=Vector2(x+N.rng.randf_range(-RS*0.45,RS*0.45),z+N.rng.randf_range(-RS*0.45,RS*0.45))
			z+=RS
			var art=_natur_ok(NL,w)
			if art==0:continue
			var h=_natur_h(NL,w)
			if h<0.3:continue
			var stg=Vector2(_natur_h(NL,w+Vector2(3,0))-_natur_h(NL,w-Vector2(3,0)),_natur_h(NL,w+Vector2(0,3))-_natur_h(NL,w-Vector2(0,3))).length()/6.0
			var p=w-C
			var nah=(SU.frei(p) if STADT.grow(260.0).has_point(w) else NL.frei(p))<120.0
			var kit=N.waehle(w.x,w.y,h,stg,G0.kuesten_abstand(w.x,w.y),_trocken(w),nah,art==2)
			if kit=="":continue
			if art==2 and N.rng.randf()<0.2:continue   # Stadtgrün etwas lockerer
			var sc=N.rng.randf_range(0.85,1.25)
			var xf=Transform3D(Basis(Vector3.UP,N.rng.randf()*TAU).scaled(Vector3.ONE*sc),Vector3(p.x,h-NL.H0-0.1,p.y))
			NL.PLATZ.append([kit,xf]);st[kit.split("_")[1]]=st.get(kit.split("_")[1],0)+1
			var fk=N.ist_baum(kit)
			if fk!="":
				nb+=1;NL.PLATZ.append([fk,xf])
				if nb%3==0:NATUR_FERN.append([fk,Transform3D(xf.basis,Vector3(w.x,h-0.1,w.y))])
		x+=RS
	print("NATUR ",NL.PLATZ.size()-n0," Bäume ",nb," Fern ",NATUR_FERN.size()," ",st," ",Time.get_ticks_msec()-t0," ms")

func _ebnen(NL,mitte:Vector2,r:float,h:float,rand:float):
	# ebene Fläche, weicher Übergang zur bisherigen Zielhöhe (überschreibt keine Nachbarn hart)
	for k in range(NL._kz(mitte.y-r-rand),NL._kz(mitte.y+r+rand)+1):
		for i in range(NL._ix(mitte.x-r-rand),NL._ix(mitte.x+r+rand)+1):
			if i<0 or k<0 or i>=NL.GNX or k>=NL.GNZ:continue
			var j=k*NL.GNX+i
			if NL.WASSER[j]==1:continue
			var d=Vector2(NL.GX0+i*NL.MST,NL.GZ0+k*NL.MST).distance_to(mitte)
			var cur=NL.TH[j] if not is_nan(NL.TH[j]) else NL.NAT[j]
			var t=smoothstep(r,r+rand,d)
			if t>=1.0:continue
			NL.TH[j]=lerp(h,cur,t);NL.HS[j]=NL.TH[j]
func _natur_orte(NL):
	# Jagdhütten im Wald, eine große versteckte Cannabisplantage, Strandvillen mit Bootssteg
	var t0=Time.get_ticks_msec();var rng=N.rng
	var grund={}
	var gut=func(w:Vector2,r:float,maxd:float,mind:float,flach:float)->bool:
		if NL._land_ok(w,min(r,12.0))!=1:grund["land"]=grund.get("land",0)+1;return false
		for f in SONDER_FREI:
			if w.distance_to(f[0])<f[1]+r+250.0:grund["nah"]=grund.get("nah",0)+1;return false
		var fr=NL.frei(w-C)
		if fr>maxd or fr<mind:grund["strasse"]=grund.get("strasse",0)+1;return false
		var hm=G0._nat(w.x,w.y)
		for a in 8:
			var d=Vector2(cos(a*TAU/8.0),sin(a*TAU/8.0))*r
			if NL._land_ok(w+d,2.0)==0:grund["rand"]=grund.get("rand",0)+1;return false
			if abs(G0._nat(w.x+d.x,w.y+d.y)-hm)>flach:grund["steil"]=grund.get("steil",0)+1;return false
		return true
	var setze=func(P:Array,mitte:Vector2,rx:float,h:float,art:String,yaw:float):
		_ebnen(NL,mitte,rx,h,40.0)
		for e in P:
			var xf:Transform3D=e[1];var o=xf.origin
			NL.PLATZ.append([e[0],Transform3D(xf.basis,Vector3(o.x-C.x,o.y-NL.H0,o.z-C.y))])
			NL._occ(Vector2(o.x,o.z)-C)
		SONDER_FREI.append([mitte,rx]);NATUR_ORTE.append({"art":art,"p":[mitte.x,h,mitte.y],"yaw":yaw})
	# Cannabisplantage (1x): abseits (80-900 m von der Straße), möglichst eben – Bedingungen werden schrittweise gelockert
	var g=N.hanf_groesse();var rh=g.length()*0.5
	for stufe in 4:
		var ok=false
		for v in 15000:
			var w=Vector2(rng.randf_range(-4000,4300),rng.randf_range(-10800,-2200))
			if _trocken(w)>0.4:continue
			if not gut.call(w,rh,900.0,80.0 if stufe<3 else 30.0,[6.0,10.0,16.0,24.0][stufe]):continue
			var h=G0._nat(w.x,w.y);var yaw=rng.randf()*TAU
			setze.call(N.hanf_platz(w,h,yaw),w,rh+6.0,h,"hanf",yaw);ok=true;break
		if ok:break
	print("NATUR Hanf-Suche ",grund);grund.clear()
	# Jagdhütten (4x) mitten im Wald, 60-400 m von der Straße
	var nj=0
	for v in 20000:
		if nj>=4:break
		var w=Vector2(rng.randf_range(-4000,4300),rng.randf_range(-10800,-1900))
		if N.biom(w.x,w.y,G0._nat(w.x,w.y),0.0,G0.kuesten_abstand(w.x,w.y),_trocken(w))!="wald":continue
		var rundum=true
		for a in 6:
			var q=w+Vector2(cos(a*1.047),sin(a*1.047))*70.0
			if N.biom(q.x,q.y,G0._nat(q.x,q.y),0.0,G0.kuesten_abstand(q.x,q.y),_trocken(q))!="wald":rundum=false
		if not rundum:continue
		if not gut.call(w,24.0,400.0,60.0,4.0):continue
		var h=G0._nat(w.x,w.y);var yaw=rng.randf()*TAU
		setze.call(N.jagd_platz(w,h,yaw),w,24.0,h,"jagd",yaw);nj+=1
	grund.clear()
	# Strandvillen (4x): Wasserlinie suchen, Haus 40 m landeinwärts, Steg ins Wasser, Straße höchstens 400 m entfernt
	var nv=0
	for v in 60000:
		if nv>=4:break
		var u=Vector2(rng.randf_range(-4300,4600),rng.randf_range(-11000,3300))
		var hu=G0._nat(u.x,u.y)
		if hu<0.0 or hu>2.0:continue
		var gr=Vector2(G0._nat(u.x+10,u.y)-G0._nat(u.x-10,u.y),G0._nat(u.x,u.y+10)-G0._nat(u.x,u.y-10))
		if gr.length()<0.05:grund["flach"]=grund.get("flach",0)+1;continue
		var land=gr.normalized();var w=u+land*42.0
		var hv=G0._nat(w.x,w.y)
		if hv<1.5 or hv>16.0:grund["hoehe"]=grund.get("hoehe",0)+1;continue
		if G0._nat(u.x-land.x*25,u.y-land.y*25)>-0.3:grund["kein_meer"]=grund.get("kein_meer",0)+1;continue
		if STADT.grow(400.0).has_point(w) or _trocken(w)>0.25:continue
		if not gut.call(w,16.0,400.0,12.0,5.0):continue
		var see=-land;var yaw=atan2(see.x,see.y)
		setze.call(N.villa_platz(w,hv,see,u),w,20.0,hv,"villa",yaw)
		for k in 12:
			var q=w+see*(18.0+k*2.0)
			_ebnen(NL,q,7.0,lerp(hv,0.9,(k+1)/12.0),10.0)
		SONDER_FREI.append([w+see*30.0,14.0])
		nv+=1
	print("NATUR Villen-Suche ",nv," ",grund)
	print("NATUR Orte ",NATUR_ORTE.size()," ",Time.get_ticks_msec()-t0," ms")

# ================= 6. Norden (wie bisher, ohne Stadtfläche) =================
func _norden()->Dictionary:
	var NL=load("res://scripts/comic/nord_lib.gd").new(L,GL,K,G0)
	var flach=Node3D.new();var alt_w=L.welt;L.welt=flach
	var alt=[L.kachel,L.weit_detail,L.weit_ink,L.leicht,L.hoehen_an,L.HF_N]
	L.leicht=false;L.hoehen_an=false;L.HF_N=0
	var insel=Rect2(-4400,-11300,9100,14800)
	NL.maske_bauen(insel,[STADT.grow(20),STADT.grow(20)])
	NL.SU=SU;NL.AUSW_W=STADT
	NL.KITLISTE=SU.KITLISTE.duplicate(true)
	NL.laden("res://assets/data/karte_nord.json",Rect2(insel.position-C,insel.size),[Rect2(STADT.position-C,STADT.size).grow(20)])
	var n0=L.KOLL_F.size();var p0=L.PFOSTEN.size()
	NL.zwischenstrassen();NL.kreuzungen();NL.kits_bauen();NL.sonderorte()
	N=load("res://scripts/comic/natur_lib.gd").new(L,K,G0);N.kits_bauen()
	for e in [["polizei",Vector2(1760,-5900)],["feuerwehr",Vector2(1900,-7650)]]:NL.dienst_reservieren(e[0],e[1])
	var dn=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/karte_nord.json"))
	var hs=[];for h in dn.houses:hs.append(Vector2(h[0],h[1]))
	NL.hinterland(hs);NL.grundstuecke();NL.fuellen();NL.landschaft_orte();_natur_orte(NL);NL.parken_strasse();NL.gelaende_ziel();_natur(NL)
	L.kachel=KACHEL;L.weit_detail=900.0;L.weit_ink=300.0
	NL.fahrbahnen();NL.platten();NL.wege();L._fertig(false)
	L.weit_detail=300.0;L.weit_ink=120.0
	NL.strassenrand();L._fertig(false)
	var KF=L.KOLL_F.slice(n0);var PF=L.PFOSTEN.slice(p0)
	L.KOLL_F.resize(n0);L.PFOSTEN.resize(p0)
	L.kachel=alt[0];L.weit_detail=alt[1];L.weit_ink=alt[2];L.leicht=alt[3];L.hoehen_an=alt[4];L.HF_N=alt[5]
	var mats={}
	for kn in K.KITS:
		for m in [K.KITS[kn].mesh,K.KITS[kn].ink]:
			if m==null:continue
			for si in m.get_surface_count():
				var mt=m.surface_get_material(si)
				if mt:mats[mt]=true
	for c in flach.get_children():
		if c is MeshInstance3D and c.material_override:mats[c.material_override]=true
	_mats_extern(mats)
	for kn in K.KITS:
		if K.KITS[kn].mesh.resource_path!="":continue
		var pfad=ZIEL+"kits/"+kn+".res"
		ResourceSaver.save(K.KITS[kn].mesh,pfad,ResourceSaver.FLAG_COMPRESS);K.KITS[kn].mesh.take_over_path(pfad)
		if K.KITS[kn].ink!=null:
			var pi=ZIEL+"kits/"+kn+"_ink.res"
			ResourceSaver.save(K.KITS[kn].ink,pi,ResourceSaver.FLAG_COMPRESS);K.KITS[kn].ink.take_over_path(pi)
	var T={}
	var kachel=func(key:Vector2i)->Node3D:
		if not T.has(key):
			var n=Node3D.new();n.name="Nord_%d_%d"%[key.x,key.y];n.position=Vector3(CX,H0,CZ);T[key]=n
		return T[key]
	var schl=func(v:Vector3)->Vector2i:return Vector2i(int(floor(v.x/KACHEL)),int(floor(v.z/KACHEL)))
	for c in flach.get_children():
		var teile=c.name.split("_");var key=Vector2i(int(teile[teile.size()-2]),int(teile[teile.size()-1]))
		flach.remove_child(c);kachel.call(key).add_child(c)
	flach.free();L.welt=alt_w
	var PL={}
	for p in NL.PLATZ:
		var key=schl.call(p[1].origin)
		if not PL.has(key):PL[key]=[]
		PL[key].append(p)
	var KK={}
	for i in range(0,KF.size(),3):
		var key=schl.call((KF[i]+KF[i+1]+KF[i+2])/3.0)
		if not KK.has(key):KK[key]=PackedVector3Array()
		KK[key].append_array([KF[i],KF[i+1],KF[i+2]])
	var PK={}
	for pf in PF:
		var key=schl.call(pf[0])
		if not PK.has(key):PK[key]=[]
		PK[key].append(pf)
	for key in PL:
		var tn=kachel.call(key);K.aufstellen(tn,PL[key],150.0,140.0)
		_labels(tn,PL[key])
		for p in PL[key]:
			for pf in K.KITS[p[0]].pf:
				if not PK.has(key):PK[key]=[]
				PK[key].append([p[1]*pf[0],pf[1],pf[2]])
		if not KK.has(key):KK[key]=PackedVector3Array()
		KK[key].append_array(K.kollision(PL[key]))
	var viertel=_kacheln_speichern(T,KK,PK,"nord")
	var fern=Node3D.new();fern.name="NordFern";W.add_child(fern);fern.position=Vector3(CX,H0,CZ)
	K.fern(fern,NL.PLATZ,600.0,2200.0)
	var immo=[];var zn={"lager":0,"autohandel":0}
	for im in NL.IMMO:
		var xf:Transform3D=im.xf;var zp=xf*Vector3(0,0,1.2);zn[im.art]+=1
		immo.append({"art":im.art,"id":"n%s_%d"%[im.art,zn[im.art]],"ort":"Land","p":Vector3(zp.x+CX,H0+xf.origin.y+L.KB+0.05,zp.z+CZ),"yaw":atan2(xf.basis.z.x,xf.basis.z.z)})
	var dienste=[]
	for dd in NL.DIENSTE:dienste.append({"art":dd.art,"p":dd.F+C,"yaw":dd.yaw})
	print("NORD Kacheln ",viertel.size())
	return {"S":NL,"viertel":viertel,"immo":immo,"dienste":dienste}
func _labels(tn:Node3D,pl:Array):
	for p in pl:
		for lb in K.KITS[p[0]].labels:
			var l=Label3D.new();l.text=lb.text;l.pixel_size=lb.px;l.modulate=lb.mod;l.outline_modulate=lb.om;l.outline_size=lb.os;l.font_size=lb.fs;l.shaded=false
			l.visibility_range_end=55.0;l.transform=p[1]*lb.xf;tn.add_child(l)
func _kacheln_speichern(T:Dictionary,KK:Dictionary,PK:Dictionary,art:String)->Array:
	var viertel=[]
	for key in T:
		var tn:Node3D=T[key]
		var sk=StaticBody3D.new();sk.name="Kollision";tn.add_child(sk)
		var F:PackedVector3Array=_saubere_dreiecke(KK.get(key,PackedVector3Array()))
		var a=0
		while a<F.size():
			var cp=ConcavePolygonShape3D.new();cp.backface_collision=true;cp.set_faces(F.slice(a,min(a+180000,F.size())))
			var c2=CollisionShape3D.new();c2.shape=cp;sk.add_child(c2);a+=180000
		for pf in PK.get(key,[]):
			var cy=CylinderShape3D.new();cy.radius=pf[1];cy.height=pf[2]
			var c3=CollisionShape3D.new();c3.shape=cy;sk.add_child(c3);c3.position=pf[0]+Vector3(0,pf[2]*0.5,0)
		_owner(tn,tn)
		var datei=ZIEL+"%s_%d_%d.scn"%[art,key.x,key.y]
		var ps=PackedScene.new();ps.pack(tn);ResourceSaver.save(ps,datei,ResourceSaver.FLAG_COMPRESS)
		viertel.append({"name":tn.name,"datei":datei,"rect":Rect2(Vector2(key.x*KACHEL+CX,key.y*KACHEL+CZ),Vector2(KACHEL,KACHEL)),"ab":480.0,"weg":620.0})
		tn.free()
	return viertel
# Kollision: Dreiecke ohne Fläche oder mit ungültigen Werten raus (sonst rechnet die Physik mit NaN)
var ENTFERNT_KOLL:=0
func _saubere_dreiecke(F:PackedVector3Array)->PackedVector3Array:
	var G=PackedVector3Array()
	for i in range(0,F.size()-2,3):
		var a=F[i];var b=F[i+1];var c=F[i+2]
		if not (a.is_finite() and b.is_finite() and c.is_finite()) or (b-a).cross(c-a).length_squared()<1e-8:ENTFERNT_KOLL+=1;continue
		G.append_array([a,b,c])
	return G
func _owner(n:Node,o:Node):
	for c in n.get_children():c.owner=o;_owner(c,o)

# ================= 7. Stadt-Kacheln, Gelände, Kollision, Daten =================
func _gelaende_und_daten(ND:Dictionary):
	L._fertig(true)
	# Stadtknoten in 300-m-Kacheln zerlegen (eigene Szenen, im Spiel nach Entfernung geladen)
	var schl=func(v:Vector3)->Vector2i:return Vector2i(int(floor(v.x/KACHEL)),int(floor(v.z/KACHEL)))
	var T={}
	var kachel=func(key:Vector2i)->Node3D:
		if not T.has(key):
			var n=Node3D.new();n.name="Stadt_%d_%d"%[key.x,key.y];n.position=Vector3(CX,0,CZ);T[key]=n
		return T[key]
	for c in STN.get_children():
		var mitte:Vector3
		if c is MeshInstance3D:mitte=c.mesh.get_aabb().get_center()+c.position
		elif c is MultiMeshInstance3D:
			# ohne Grafiktreiber kennt das MultiMesh seine Ausdehnung nicht -> Mitte aus dem Lagen-Puffer
			var b:PackedFloat32Array=c.get_meta("puffer",PackedFloat32Array())
			var sm=Vector3.ZERO;var nn=b.size()/12
			for q in nn:sm+=Vector3(b[q*12+3],b[q*12+7],b[q*12+11])
			mitte=sm/max(nn,1)+c.position
		elif c is Node3D:mitte=c.position
		else:continue
		STN.remove_child(c);kachel.call(schl.call(mitte)).add_child(c)
	# Bausätze der Stadt
	var PL={}
	for p in SU.PLATZ:
		var key=schl.call(p[1].origin)
		if not PL.has(key):PL[key]=[]
		PL[key].append(p)
	# Kollision: Fahrbahnen/Platten folgen dem Feld, Häuser sind fertig
	var KK={}
	for i in range(0,L.KOLL_F.size(),3):
		var a=L.KOLL_F[i];var b=L.KOLL_F[i+1];var c=L.KOLL_F[i+2]
		a.y+=L.FY(a.x,a.z);b.y+=L.FY(b.x,b.z);c.y+=L.FY(c.x,c.z)
		var key=schl.call((a+b+c)/3.0)
		if not KK.has(key):KK[key]=PackedVector3Array()
		KK[key].append_array([a,b,c])
	for i in range(0,L.KOLL_N.size(),3):
		var key=schl.call((L.KOLL_N[i]+L.KOLL_N[i+1]+L.KOLL_N[i+2])/3.0)
		if not KK.has(key):KK[key]=PackedVector3Array()
		KK[key].append_array([L.KOLL_N[i],L.KOLL_N[i+1],L.KOLL_N[i+2]])
	var PK={}
	for pf in L.PFOSTEN:
		var o:Vector3=pf[0];o.y+=L.FY(o.x,o.z)
		var key=schl.call(o)
		if not PK.has(key):PK[key]=[]
		PK[key].append([o,pf[1],pf[2]])
	for key in PL:
		var tn=kachel.call(key);K.aufstellen(tn,PL[key],150.0,160.0)
		_labels(tn,PL[key])
		for p in PL[key]:
			for pf in K.KITS[p[0]].pf:
				if not PK.has(key):PK[key]=[]
				PK[key].append([p[1]*pf[0],pf[1],pf[2]])
		if not KK.has(key):KK[key]=PackedVector3Array()
		KK[key].append_array(K.kollision(PL[key]))
	var fern=Node3D.new();fern.name="StadtFern";W.add_child(fern);fern.position=Vector3(CX,0,CZ)
	K.fern(fern,SU.PLATZ,600.0,2200.0)
	print("FERN Häuser-Felder ",L.fern_haeuser(fern,600.0,300.0,2400.0))
	# Materialien der Stadt extern (alle Kacheln teilen sie)
	var mats={}
	for key in T:
		for c in T[key].find_children("*","GeometryInstance3D",true,false):
			if c is MeshInstance3D:
				if c.material_override:mats[c.material_override]=true
			elif c is MultiMeshInstance3D and c.multimesh.mesh:
				for si in c.multimesh.mesh.get_surface_count():
					var m=c.multimesh.mesh.surface_get_material(si)
					if m:mats[m]=true
	_mats_extern(mats)
	var mi_n=0
	for k in L.MODULE:
		var pfad=ZIEL+"kits/modul_%d.res"%mi_n;mi_n+=1
		ResourceSaver.save(L.MODULE[k],pfad,ResourceSaver.FLAG_COMPRESS);L.MODULE[k].take_over_path(pfad)
	var viertel=_kacheln_speichern(T,KK,PK,"stadt")
	KK={};PK={};PL={};T={}
	L.KOLL_F=PackedVector3Array();L.KOLL_N=PackedVector3Array();L.PFOSTEN=[];L.MODULE={};L.st={}
	print("STADT Kacheln ",viertel.size()," RAM ",OS.get_static_memory_usage()/1048576)
	# ---- Gelände: Insel + Feld; unter Stadtstraßen/Blöcken 0,4 m tiefer (sonst sticht es durch den Asphalt)
	var nx=G0.rx;var nz=G0.rz;var X0=G0.X0;var Z0=G0.Z0;var ST=G0.STEP
	var H=PackedFloat32Array(G0._nh)
	var NO=ND.S
	for k in nz:
		for i in nx:
			var j=k*nx+i;var x=X0+i*ST;var z=Z0+k*ST
			if STADT.has_point(Vector2(x,z)):
				if NAT0[j]<1.0:continue
				var p=Vector2(x,z)-C
				var ns=SU.naechst(p)
				var tief=(ns[2]>=0 and ns[3]<NETZ[ns[2]].w+4.0) or _stadtflaeche(p)
				H[j]=L.FY(p.x,p.y)-(0.45 if tief else 0.0)
				continue
			var thn=NO.TH[j]
			if not is_nan(thn):H[j]=thn
	HG=H
	_gelaende(H,nx,nz,X0,Z0,ST)
	_natur_fern()
	_karte_bild(H,nx,nz,X0,Z0,ST)
	_wasser()
	var kb=StaticBody3D.new();kb.name="Kollision";W.add_child(kb)
	var hm=HeightMapShape3D.new();hm.map_width=nx;hm.map_depth=nz
	var hd=PackedFloat32Array();hd.resize(nx*nz)
	for j in nx*nz:hd[j]=H[j]/ST
	hm.map_data=hd
	var cs=CollisionShape3D.new();cs.shape=hm;kb.add_child(cs)
	cs.scale=Vector3.ONE*ST;cs.position=Vector3(X0+(nx-1)*ST*0.5,0,Z0+(nz-1)*ST*0.5)
	# ---- Straßen (Format der alten Welt, Weltkoordinaten)
	var roads=[]
	for r in NETZ:r.P=_ohne_doppelte(r.P)
	for a in AB+RAMPEN:
		if a.has("H"):continue
		a.P=_ohne_doppelte(a.P)
	for r in NETZ:
		var P:PackedVector2Array=r.P
		var Q=PackedVector2Array();var Hh=PackedFloat32Array();var Tg=PackedVector2Array();var tf=[];var el=[]
		for i in P.size():
			var p=P[i];Q.append(p+C);Hh.append(L.FY(p.x,p.y)+0.015)
			Tg.append((P[min(i+1,P.size()-1)]-P[max(i-1,0)]).normalized());tf.append(false);el.append(false)
		var sw={"allee":3.5,"strasse":2.5,"gasse":1.2,"land":1.6}.get(r.typ,2.5)
		roads.append({"lane_x":r.w*0.36,"name":r.n,"typ":"strasse" if r.typ=="land" else r.typ,"P":Q,"h":Hh,"T":Tg,"w":r.w,"sw":sw,"med":0.2 if r.typ=="allee" else 0.0,"tunnel_flags":tf,"elev":el,"lanes":1,"wear":0.3,"closed":false,"sued":true,"belag":"asphalt"})
	for a in AB+RAMPEN:
		var P:PackedVector2Array=a.P
		var Q=PackedVector2Array();var Hh=PackedFloat32Array();var Tg=PackedVector2Array();var tf=[];var el=[]
		for i in P.size():
			var p=P[i];var hh=a.H[i] if a.has("H") else _ab_hoehe(p)
			Q.append(p+C);Hh.append(L.FY(p.x,p.y)+hh+0.01);Tg.append((P[min(i+1,P.size()-1)]-P[max(i-1,0)]).normalized());tf.append(false);el.append(hh>1.0)
		roads.append({"lane_x":a.w*0.5 if a.n!="Rampe" else -1.0,"name":a.n,"typ":"autobahn" if a.n!="Rampe" else "rampe","P":Q,"h":Hh,"T":Tg,"w":a.w,"sw":0.0,"med":0.9 if a.n!="Rampe" else 0.0,"tunnel_flags":tf,"elev":el,"lanes":1,"wear":0.2,"closed":false,"sued":true})
	var junctions=[]
	for j in SU.JUNC:junctions.append({"p":j.p+C,"h":L.FY(j.p.x,j.p.y)+0.015,"r":j.r,"a":j.a,"b":j.b,"rail":false})
	var basis_n=roads.size()
	for r in NO.ROADS:
		var Q=PackedVector2Array();var Hh=PackedFloat32Array();var Tg=PackedVector2Array();var tf=[];var el=[]
		for i in r.P.size():
			var p:Vector2=r.P[i];Q.append(p+C);Hh.append(H0+NO.hy(p)+0.07)
			Tg.append((r.P[min(i+1,r.P.size()-1)]-r.P[max(i-1,0)]).normalized());tf.append(false);el.append(false)
		roads.append({"lane_x":r.w*(0.5 if r.get("orig","")=="autobahn" else 0.36),"name":r.n,"typ":r.typ,"P":Q,"h":Hh,"T":Tg,"w":r.w,"sw":r.sw,"med":0.2 if r.typ in ["allee","autobahn"] else 0.0,"tunnel_flags":tf,"elev":el,"lanes":1,"wear":0.3,"closed":false,"sued":true,"belag":r.get("belag","asphalt")})
	for j in NO.JUNC:
		junctions.append({"p":j.p+C,"h":H0+NO.hy(j.p)+0.07,"r":j.r,"a":basis_n+j.a,"b":basis_n+j.b,"rail":false})
	# ---- Parkplätze (sparsam), Läden
	var var_={"c_trabant":["c_trabant_gruen","c_trabant_blau","c_trabant_beige","c_trabant_rot"],"c_wartburg":["c_wartburg_beige","c_wartburg_blau","c_wartburg_gruen"],
		"c_sport":["c_sport_rot","c_sport_gelb","c_sport_schwarz"],"c_jdm":["c_jdm_weiss","c_jdm_blau","c_jdm_rot"],"c_kompakt":["c_kompakt_rot","c_kompakt_weiss","c_kompakt_schwarz"],
		"c_e30":["c_e30_gruen","c_e30_silber","c_e30_schwarz"],"c_luxus":["c_luxus_schwarz","c_luxus_silber"],"c_muscle":["c_muscle_orange","c_muscle_schwarz"],"c_suv":["c_suv_grau","c_suv_gruen"]}
	var rr=RandomNumberGenerator.new();rr.seed=5
	var parken=[]
	for e in SU.PARK:
		if rr.randf()>0.45:continue
		var k:String=e[0];var tf:Transform3D=e[1]
		if var_.has(k):k=var_[k][rr.randi()%var_[k].size()]
		var o=tf.origin;o.x+=CX;o.z+=CZ
		parken.append([k,Transform3D(tf.basis,o)])
	for e in NO.PARK:
		var k:String=e[0];var tf:Transform3D=e[1]
		if var_.has(k):k=var_[k][rr.randi()%var_[k].size()]
		var o=tf.origin;o.y+=H0+0.2;o.x+=CX;o.z+=CZ
		parken.append([k,Transform3D(tf.basis,o)])
	var shops=[]
	var laden=func(typ:String,ziel:Vector2,d_:float):
		var ns=SU.naechst(ziel-C)
		if ns[2]<0:print("LADEN ",typ," kein Platz");return
		var r=SU.ROADS[ns[2]];var t:Vector2=ns[1];var n=L._rn(t)
		if (ziel-C-ns[0]).dot(n)<0:n=-n
		var q=ns[0]+n*(r.w+r.sw-0.6)
		shops.append({"typ":typ,"c":q+C,"y":L.FY(q.x,q.y)+L.KB,"yaw":atan2(-n.x,-n.y),"w":4.0,"d":d_})
	laden.call("zuhause",Vector2(-250,1000),-7.0)
	laden.call("waffen",Vector2(150,-250),-3.0)
	laden.call("kleider",Vector2(350,-420),-3.0)
	if not SU.WERKSTATT.is_empty():
		var wk=SU.WERKSTATT;var vor:Vector2=wk.vor
		var gy=L.FY(vor.x,vor.y)
		shops.append({"typ":"werkstatt","c":vor+C,"y":gy+L.KB+0.03,"yaw":wk.yaw+PI,"w":20.0,"d":0.0,"g":[wk.F.x+CX,wk.F.y+CZ,wk.yaw],"gy":L.FY(wk.F.x,wk.F.y)})
		var zp=vor+C
		parken=parken.filter(func(e):return Vector2(e[1].origin.x,e[1].origin.z).distance_to(zp)>16.0)
	var immo=ND.immo.duplicate();var zn={"lager":0,"autohandel":0}
	for im in SU.IMMO:
		var xf:Transform3D=im.xf;var zp=xf*Vector3(0,0,1.2);zn[im.art]+=1
		immo.append({"art":im.art,"id":"%s_%d"%[im.art,zn[im.art]],"ort":{"ghetto":"Ghetto","sued":"Südstadt","docks":"Docks","industrie":"Industrie","strand":"Strand"}.get(im.stil,"Stadt"),"p":Vector3(zp.x+CX,L.FY(xf.origin.x,xf.origin.z)+L.KB+0.05,zp.z+CZ),"yaw":atan2(xf.basis.z.x,xf.basis.z.z)})
	var dienste=ND.dienste.duplicate()
	for dd in SU.DIENSTE:dienste.append({"art":dd.art,"p":dd.F+C,"yaw":dd.yaw})
	var bahn=[]
	for b in BAHN:
		var P=PackedVector3Array()
		for p in b.P:P.append(Vector3(p.x+CX,L.FY(p.x,p.y)+0.33,p.y+CZ))
		bahn.append(P)
	var daten={"H":H,"nx":nx,"nz":nz,"X0":X0,"Z0":Z0,"STEP":ST,"roads":roads,"junctions":junctions,"parken":parken,"shops":shops,
		"rect":STADT,"sued_rect":STADT,"viertel":viertel+ND.viertel,"immo":immo,"dienste":dienste,"bahn":bahn,"neu":true,"natur_orte":NATUR_ORTE}
	var f=FileAccess.open(ZIEL+"daten.bin",FileAccess.WRITE);f.store_var(daten,false);f.close()
	STN.free()
	_owner(W,W)
	var ps=PackedScene.new();var e1=ps.pack(W)
	var e2=ResourceSaver.save(ps,ZIEL+"welt.scn",ResourceSaver.FLAG_COMPRESS)
	BER["koll_dreiecke_entfernt"]=ENTFERNT_KOLL;BER["kacheln"]=viertel.size()+ND.viertel.size();BER["parkplaetze_spiel"]=parken.size();BER["laeden"]=shops.size()
	print("GESPEICHERT ",error_string(e1)," ",error_string(e2)," Straßen ",roads.size()," Kreuzungen ",junctions.size()," Parkplätze ",parken.size())

const C_GRAS:=Color(0.5,0.78,0.34)
const C_WALD:=Color(0.3,0.58,0.27)
const C_SAND:=Color(0.86,0.7,0.44)
const C_FELS:=Color(0.62,0.55,0.47)
const C_TROCKEN:=Color(0.76,0.66,0.38)
const C_STRAND:=Color(0.92,0.82,0.58)
const C_SCHNEE:=Color(0.95,0.96,0.98)
var HG:PackedFloat32Array
func _farbe(i:int,k:int,h:float)->Color:
	var nx=G0.rx;var x=G0.X0+i*G0.STEP;var z=G0.Z0+k*G0.STEP
	var i0=max(i-1,0);var i1=min(i+1,nx-1);var k0=max(k-1,0);var k1=min(k+1,G0.rz-1)
	var stg=Vector2((HG[k*nx+i1]-HG[k*nx+i0])/((i1-i0)*G0.STEP),(HG[k1*nx+i]-HG[k0*nx+i])/((k1-k0)*G0.STEP)).length()
	var w=Vector2(x,z);var c:Color
	if STADT.has_point(w):
		c=N.farbe(x,z,h,min(stg,0.3),G0.kuesten_abstand(x,z),0.0)
		if h>2.5:c=c.lerp(Color(0.4,0.52,0.28),0.3)
	else:c=N.farbe(x,z,h,stg,G0.kuesten_abstand(x,z),_trocken(w))
	# im Spiel hellen Licht + Dunst die Farben auf -> Gelände etwas dunkler und satter
	var g=c.v;c.v=g*0.82;c.s=min(c.s*1.12,1.0)
	return c
func _gelaende(H:PackedFloat32Array,nx:int,nz:int,X0:float,Z0:float,ST:float):
	var mat=ShaderMaterial.new();var sh=Shader.new();sh.code="""shader_type spatial;
render_mode diffuse_toon,specular_disabled;
uniform sampler2D rausch:repeat_enable,filter_linear_mipmap;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float a=texture(rausch,wp.xz/9.0).r;float b=texture(rausch,wp.xz/53.0).r;
	ALBEDO=COLOR.rgb*(0.84+0.22*a+0.12*(b-0.5));ROUGHNESS=1.0;
}"""
	mat.shader=sh
	var tex=NoiseTexture2D.new();tex.width=256;tex.height=256;tex.seamless=true;tex.generate_mipmaps=true
	var fn=FastNoiseLite.new();fn.frequency=0.03;fn.fractal_octaves=3;tex.noise=fn
	ResourceSaver.save(tex,ZIEL+"gelaende_rausch.res");tex.take_over_path(ZIEL+"gelaende_rausch.res")
	mat.set_shader_parameter("rausch",tex)
	var CH=48
	for k0 in range(0,nz-1,CH):
		for i0 in range(0,nx-1,CH):
			var k1=min(k0+CH,nz-1);var i1=min(i0+CH,nx-1)
			var hoch=-INF
			for k in range(k0,k1+1,4):
				for i in range(i0,i1+1,4):hoch=max(hoch,H[k*nx+i])
			if hoch<-1.0:continue
			for stufe in [1,4]:
				var stt=SurfaceTool.new();stt.begin(Mesh.PRIMITIVE_TRIANGLES)
				var k=k0
				while k<k1:
					var kk=min(k+stufe,k1);var i=i0
					while i<i1:
						var ii=min(i+stufe,i1)
						var P=[[i,k],[ii,k],[ii,kk],[i,kk]]
						var V=[]
						for q in P:V.append(Vector3(X0+q[0]*ST,H[q[1]*nx+q[0]],Z0+q[1]*ST))
						var n1=(V[2]-V[0]).cross(V[1]-V[0]).normalized()
						if n1.y<0:n1=-n1
						for t in [[0,1,2],[0,2,3]]:
							for q in t:
								stt.set_color(_farbe(P[q][0],P[q][1],V[q].y));stt.set_normal(n1);stt.add_vertex(V[q])
						i=ii
					k=kk
				var mi=MeshInstance3D.new();mi.mesh=stt.commit();mi.material_override=mat;mi.name="Gelaende_%d_%d_%d"%[i0,k0,stufe];W.add_child(mi)
				if stufe==1:mi.visibility_range_end=600.0
				else:mi.visibility_range_begin=580.0;mi.visibility_range_end=7000.0;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _wasser():
	var mi=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(40000,40000);mi.mesh=pm;mi.name="Wasser";W.add_child(mi)
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.3,0.62,0.85);m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.specular_mode=BaseMaterial3D.SPECULAR_TOON;m.roughness=0.25
	mi.material_override=m;mi.position.y=0.0;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _natur_fern():
	# dünner Fernwald, immer geladen (Kacheln laden erst ab 480 m): jeder 3. Baum als einfacher Fernbaum
	var fern=Node3D.new();fern.name="NaturFern";W.add_child(fern)
	var G={}
	for e in NATUR_FERN:
		var key=Vector2i(int(floor(e[1].origin.x/800.0)),int(floor(e[1].origin.z/800.0)))
		if not G.has(key):G[key]={}
		if not G[key].has(e[0]):G[key][e[0]]=[]
		G[key][e[0]].append(e[1])
	for key in G:
		var mitte=Vector3((key.x+0.5)*800.0,0,(key.y+0.5)*800.0)
		for kn in G[key]:
			var xs=G[key][kn];var buf=PackedFloat32Array()
			for xf in xs:buf.append_array(L.xf_puffer(Transform3D(xf.basis,xf.origin-mitte)))
			var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=K.KITS[kn].mesh;mm.instance_count=xs.size();mm.buffer=buf
			var mmi=MultiMeshInstance3D.new();mmi.multimesh=mm;mmi.name="NF_%d_%d_%s"%[key.x,key.y,kn];mmi.position=mitte;fern.add_child(mmi);mmi.set_meta("puffer",buf)
			mmi.visibility_range_begin=470.0;mmi.visibility_range_end=1900.0;mmi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("NATUR Fernwald Felder ",G.size()," Bäume ",NATUR_FERN.size())

func _karte_bild(H:PackedFloat32Array,nx:int,nz:int,X0:float,Z0:float,ST:float):
	# Grundkarte für Karte/Minikarte: Geländefarben mit Schummerung, Stadtblöcke hellgrau, Wasser nach Tiefe
	var b=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/karte_bereich.json"))
	var W2=1230;var H2=2000
	var img=Image.create(W2,H2,false,Image.FORMAT_RGB8)
	var hb=func(x,z):return G0._bilin(H,x,z)
	for py in H2:
		var z=b.z0+(py+0.5)/H2*(b.z1-b.z0)
		for px in W2:
			var x=b.x0+(px+0.5)/W2*(b.x1-b.x0)
			var h=G0._bilin(H,x,z);var c:Color
			if h<0.15:
				c=Color(0.36,0.62,0.78).lerp(Color(0.16,0.36,0.56),clamp(-h/25.0,0.0,1.0))
			else:
				var w=Vector2(x,z)
				var hx=G0._bilin(H,x+5,z)-G0._bilin(H,x-5,z);var hz=G0._bilin(H,x,z+5)-G0._bilin(H,x,z-5)
				var stg=Vector2(hx,hz).length()/10.0
				if STADT.grow(300).has_point(w) and _nm(w) and STADT.has_point(w):c=Color(0.78,0.77,0.74)
				else:c=N.farbe(x,z,h,stg,G0.kuesten_abstand(x,z),_trocken(w) if not STADT.has_point(w) else 0.0)
				var licht=clamp(1.0+(-hx+hz)*0.06,0.75,1.2)
				c=Color(c.r*licht,c.g*licht,c.b*licht)
			img.set_pixel(px,py,c)
	img.resize(2460,3999,Image.INTERPOLATE_BILINEAR)
	img.save_png("res://assets/ui/karte_basis.png")
	print("KARTE Grundbild gespeichert")
