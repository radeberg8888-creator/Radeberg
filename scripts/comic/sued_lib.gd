extends RefCounted
# Untere Kartenhälfte (südlich der Autobahn-Linie): baut entlang der ORIGINAL-Straßen (assets/data/karte_alt.json)
# Ghetto, Südstadt, Docks, Hafen/Industrie, Strand, Flugplatz. Alle Koordinaten lokal zur Comic-Stadt (Welt - C).
# Gebäude kommen aus dem Bausatz (kit_lib): Varianten einmal gebaut, per MultiMesh aufgestellt.
var L;var GL;var K
var rng:=RandomNumberGenerator.new()
const C:=Vector2(-200.0,500.0)
const KB:=0.15
const RAND:=3.0
var RECT:Rect2                 # lokales Gebiet
var AUS:=[]                    # lokale Ausschlüsse (Comic-Stadt)
var ROADS:=[]                  # Fahrstraßen {n,P,w,sw,typ,S}
var SONDER:=[]                 # Rollbahn, Taxiway, Schiene {P,w,typ}
var SPERR:=[]                  # Autobahn-Trassen (frei halten)
var SEG:={}
var OCC:={}
var PLATZ:=[]                  # [kit, Transform3D lokal]
var IMMO:=[]                   # kaufbare Gebäude
var JUNC:=[]                   # {p,r,a,b} (Indizes in ROADS)
var PARK:=[]                   # [kind, Transform3D lokal]
var LABEL_PLATZ:=[]            # nichts – Beschriftungen stecken in den Bausätzen
# Gelände-Maske (Raster des Inselgeländes, 10 m)
var G0;var MX0:float;var MZ0:float;var MST:=10.0;var MNX:int;var MNZ:int
var MASKE:PackedByteArray      # 1 = bebaubar (flach auf H0)
var WASSER:PackedByteArray
var KITLISTE:={}               # stil/typ -> [kit names]

func _init(lib,ghetto_lib,kit_lib,gelaende):
	L=lib;GL=ghetto_lib;K=kit_lib;G0=gelaende;rng.seed=2026

# ---------------- Stil je Ort (Weltkoordinaten) ----------------
func stil(pl:Vector2)->String:
	var w=pl+C
	if w.x<-1250 and w.y>1860:return "flug"
	if w.x<-1650:return "strand"
	if w.y>1950 and w.x>-1300:return "docks"
	if w.x>1150:return "hafen"
	if w.x>520 and w.y<1150:return "industrie"
	if w.y>1250 or w.x>0:return "sued"
	return "ghetto"

# ---------------- Maske ----------------
func maske_bauen(rect_welt:Rect2,aus_welt:Array):
	MX0=floor(rect_welt.position.x/MST)*MST-50;MZ0=floor(rect_welt.position.y/MST)*MST-50
	MNX=int(rect_welt.size.x/MST)+11;MNZ=int(rect_welt.size.y/MST)+11
	MASKE=PackedByteArray();MASKE.resize(MNX*MNZ);WASSER=PackedByteArray();WASSER.resize(MNX*MNZ)
	var dist=PackedInt32Array();dist.resize(MNX*MNZ);dist.fill(99999)
	var q=[]
	for k in MNZ:
		for i in MNX:
			var x=MX0+i*MST;var z=MZ0+k*MST;var j=k*MNX+i
			if G0._nat(x,z)<1.0:WASSER[j]=1;dist[j]=0;q.append(j)
	var h=0
	while h<q.size():
		var j=q[h];h+=1;var i=j%MNX;var k=j/MNX
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var a=i+d.x;var b=k+d.y
			if a<0 or b<0 or a>=MNX or b>=MNZ:continue
			var jj=b*MNX+a
			if dist[jj]>dist[j]+1:dist[jj]=dist[j]+1;q.append(jj)
	for k in MNZ:
		for i in MNX:
			var x=MX0+i*MST;var z=MZ0+k*MST;var j=k*MNX+i
			var p=Vector2(x,z)
			if not rect_welt.has_point(p) or WASSER[j]==1:continue
			var aus=false
			for a in aus_welt:
				if a.grow(10.0).has_point(p):aus=true
			if aus:continue
			var docks=stil(p-C)=="docks"
			if docks or dist[j]>=3:MASKE[j]=1
var DM:PackedFloat32Array   # Abstand zur bebaubaren Fläche in m (0 = drin)
func dist_maske():
	DM=PackedFloat32Array();DM.resize(MNX*MNZ);DM.fill(1e9);var q=[]
	for j in MNX*MNZ:
		if MASKE[j]==1:DM[j]=0.0;q.append(j)
	var h=0
	while h<q.size():
		var j=q[h];h+=1;var i=j%MNX;var k=j/MNX
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
			var a=i+d.x;var b=k+d.y
			if a<0 or b<0 or a>=MNX or b>=MNZ:continue
			var nd=DM[j]+MST*(1.414 if d.x!=0 and d.y!=0 else 1.0)
			if nd<DM[b*MNX+a] and nd<400.0:DM[b*MNX+a]=nd;q.append(b*MNX+a)
func dm_welt(x:float,z:float)->float:
	var i=int(round((x-MX0)/MST));var k=int(round((z-MZ0)/MST))
	if i<0 or k<0 or i>=MNX or k>=MNZ:return 1e9
	return DM[k*MNX+i]
func _mv(i:int,k:int)->bool:
	if i<0 or k<0 or i>=MNX or k>=MNZ:return false
	return MASKE[k*MNX+i]==1
func maske(pl:Vector2)->bool:
	var w=pl+C;var fi=(w.x-MX0)/MST;var fk=(w.y-MZ0)/MST
	var i=int(floor(fi));var k=int(floor(fk))
	return _mv(i,k) and _mv(i+1,k) and _mv(i,k+1) and _mv(i+1,k+1)
func wasser(pl:Vector2)->bool:
	var w=pl+C;var i=int(round((w.x-MX0)/MST));var k=int(round((w.y-MZ0)/MST))
	if i<0 or k<0 or i>=MNX or k>=MNZ:return false
	return WASSER[k*MNX+i]==1

# ---------------- Straßen ----------------
func laden(datei:String,rect_lokal:Rect2,aus:Array):
	RECT=rect_lokal;AUS=aus
	var d=JSON.parse_string(FileAccess.get_file_as_string(datei))
	var roh=[]
	for r in d.roads:
		var P=PackedVector2Array()
		for q in r.P:P.append(Vector2(q[0],q[1])-C)
		roh.append([r,P])
	# Autobahn-Trassen frei halten
	for e in roh:
		if e[0].typ=="autobahn":SPERR.append(e[1])
	# Rollbahn / Taxiway / Schiene
	for e in roh:
		if e[0].typ in ["runway","taxi","schiene"]:
			for st in _stuecke(e[1],false):SONDER.append({"P":_duenn(st),"w":float(e[0].w)*(0.5 if e[0].typ!="schiene" else 1.0),"typ":e[0].typ})
	for e in roh:
		var r=e[0]
		if not r.typ in ["strasse","allee","gasse","land"]:continue
		for st in _stuecke(e[1],true):_neu(st,r)
	_raster_sperren()
	print("SUED Straßen ",ROADS.size()," Sonder ",SONDER.size()," Sperr ",SPERR.size())
func _stuecke(P:PackedVector2Array,maske_pruefen:bool)->Array:
	var aus=[];var cur=PackedVector2Array()
	for p in P:
		var drin=RECT.has_point(p)
		for a in AUS:
			if a.grow(2.0).has_point(p):drin=false
		if drin and maske_pruefen and not maske(p):drin=false
		if drin:cur.append(p)
		else:
			if cur.size()>=4:aus.append(cur)
			cur=PackedVector2Array()
	if cur.size()>=4:aus.append(cur)
	return aus
func _duenn(P:PackedVector2Array)->PackedVector2Array:
	var Q=PackedVector2Array();var acc=0.0
	Q.append(P[0])
	for i in range(1,P.size()):
		acc+=P[i].distance_to(P[i-1])
		if acc>=4.0 or i==P.size()-1:Q.append(P[i]);acc=0.0
	return Q
func _neu(P:PackedVector2Array,r):
	var Q=_duenn(P)
	if Q.size()<2:return
	var S=[0.0]
	for i in range(1,Q.size()):S.append(S[-1]+Q[i].distance_to(Q[i-1]))
	if S[-1]<16.0:return
	var dop=0
	for i in range(0,Q.size(),3):
		if auf_fahrbahn(Q[i],-1,1.0):dop+=1
	if dop>=int(ceil(Q.size()/3.0))*0.7:return
	var w=5.0;var sw=2.5
	if r.typ=="gasse":w=3.4;sw=1.2
	elif r.typ=="allee":w=7.0;sw=3.5
	elif r.typ=="land":w=4.6;sw=1.6
	var ri=ROADS.size()
	ROADS.append({"n":"%s %d"%[{"strasse":"Straße","allee":"Allee","gasse":"Gasse","land":"Landstraße"}[r.typ],ri],"P":Q,"w":w,"sw":sw,"typ":"strasse" if r.typ=="land" else r.typ,"S":S})
	for i in Q.size()-1:_seg_ein(ri,i,Q[i],Q[i+1])
# Große Blöcke: neue Hinterstraßen parallel zu den Originalstraßen (folgen deren Kurven), Enden an die nächste Straße angebunden
func zwischenstrassen():
	var n0=ROADS.size()
	for durchgang in 2:
		var bis=ROADS.size()
		for ri in bis:
			var r=ROADS[ri]
			if r.typ=="gasse":continue
			for sd in [-1,1]:
				var D=r.w+r.sw+58.0;var s=0.0;var cur=PackedVector2Array();var Lg:float=r.S[-1]
				while s<=Lg:
					var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var q=p+Vector2(-t.y,t.x)*sd*D
					var ok=RECT.grow(-20).has_point(q) and maske(q) and not _belegt(q) and frei(q)>30.0 and stil(q)!="flug"
					for a in AUS:
						if a.grow(20).has_point(q):ok=false
					if ok:cur.append(q)
					else:
						_zw_neu(cur);cur=PackedVector2Array()
					s+=6.0
				_zw_neu(cur)
	print("SUED Hinterstraßen ",ROADS.size()-n0)
func _zw_neu(P:PackedVector2Array):
	if P.size()<11:return
	# Enden an nächste Straße anbinden (T-Einmündung)
	for ende in [0,1]:
		var e:Vector2=P[0] if ende==0 else P[P.size()-1]
		var nb:Vector2=P[1] if ende==0 else P[P.size()-2]
		var dir=(e-nb).normalized();var best=null
		for k in range(4,60,4):
			var q=e+dir*k
			if not maske(q) or _belegt(q):break
			if auf_fahrbahn(q,-1,0.0):best=q;break
		if best==null:
			# sonst: zur nächsten Straße in der Nähe abbiegen, wenn der Weg frei ist
			var ns=naechst(e)
			if ns[2]>=0 and ns[3]<45.0:
				var ziel:Vector2=ns[0];var frei_=true;var k2=4.0
				while k2<e.distance_to(ziel)-ROADS[ns[2]].w:
					var q=e+(ziel-e).normalized()*k2
					if not maske(q) or _belegt(q):frei_=false;break
					k2+=3.0
				if frei_:best=ziel;dir=(ziel-e).normalized()
		if best!=null:
			var add=PackedVector2Array();var k=4.0;var Lg=e.distance_to(best)
			while k<Lg:add.append(e+dir*k);k+=4.0
			add.append(best)
			if ende==0:add.reverse();P=add+P
			else:P=P+add
	var S=[0.0]
	for i in range(1,P.size()):S.append(S[-1]+P[i].distance_to(P[i-1]))
	var ri=ROADS.size()
	ROADS.append({"n":"Hinterstraße %d"%ri,"P":P,"w":5.0,"sw":2.0,"typ":"strasse","S":S})
	for i in P.size()-1:_seg_ein(ri,i,P[i],P[i+1])
func _seg_ein(ri:int,i:int,a:Vector2,b:Vector2):
	var mn=Vector2(min(a.x,b.x),min(a.y,b.y))/20.0;var mx=Vector2(max(a.x,b.x),max(a.y,b.y))/20.0
	for gx in range(int(floor(mn.x))-1,int(floor(mx.x))+2):
		for gz in range(int(floor(mn.y))-1,int(floor(mx.y))+2):
			var k=Vector2i(gx,gz)
			if not SEG.has(k):SEG[k]=[]
			SEG[k].append(Vector2i(ri,i))
func _raster_sperren():
	for P in SPERR:
		for i in P.size()-1:
			var a:Vector2=P[i];var b:Vector2=P[i+1];var Lg=a.distance_to(b);var s=0.0
			while s<=Lg:
				var p=a.lerp(b,s/max(Lg,0.01))
				for dx in range(-8,9,2):
					for dz in range(-8,9,2):_occ(p+Vector2(dx,dz)*1.0)
				s+=2.0
	for sd in SONDER:
		var P:PackedVector2Array=sd.P;var w:float=sd.w+(4.0 if sd.typ=="schiene" else 6.0)
		for i in P.size()-1:
			var a:Vector2=P[i];var b:Vector2=P[i+1];var Lg=a.distance_to(b);var s=0.0;var t=(b-a).normalized();var n=Vector2(-t.y,t.x)
			while s<=Lg:
				var p=a+t*s;var o=-w
				while o<=w:_occ(p+n*o);o+=1.5
				s+=1.5
func _occ(p:Vector2):OCC[Vector2i(int(floor(p.x/2.0)),int(floor(p.y/2.0)))]=true
func _belegt(p:Vector2)->bool:return OCC.has(Vector2i(int(floor(p.x/2.0)),int(floor(p.y/2.0))))
func naechst(p:Vector2,ohne:=-1)->Array:   # [Fußpunkt, Tangente, road, Abstand zur Mittellinie]
	var best=1e9;var res=[p,Vector2(1,0),-1,1e9];var k=Vector2i(int(floor(p.x/20.0)),int(floor(p.y/20.0)))
	for rad in [0,1,2]:
		for i in range(-rad,rad+1):
			for j in range(-rad,rad+1):
				if max(abs(i),abs(j))!=rad:continue
				for sg in SEG.get(k+Vector2i(i,j),[]):
					if sg.x==ohne:continue
					var r=ROADS[sg.x];var a:Vector2=r.P[sg.y];var b:Vector2=r.P[sg.y+1]
					var t=clamp((p-a).dot(b-a)/max((b-a).length_squared(),0.0001),0.0,1.0);var f=a.lerp(b,t)
					if p.distance_to(f)<best:best=p.distance_to(f);res=[f,(b-a).normalized(),sg.x,best]
		if res[2]>=0 and rad>=1:break
	return res
func frei(p:Vector2,ohne:=-1)->float:   # Abstand zur nächsten Gehwegkante (negativ: auf Straße/Gehweg)
	var n=naechst(p,ohne)
	if n[2]<0:return 1e9
	var r=ROADS[n[2]];return n[3]-r.w-r.sw
func auf_fahrbahn(p:Vector2,ohne:=-1,rand:=0.2)->bool:
	var n=naechst(p,ohne)
	if n[2]<0:return false
	return n[3]<ROADS[n[2]].w+rand
func bei(r,s:float)->Array:
	var S:Array=r.S;var P:PackedVector2Array=r.P;var i=0
	while i<S.size()-2 and S[i+1]<s:i+=1
	var t=clamp((s-S[i])/max(S[i+1]-S[i],0.001),0.0,1.0)
	return [P[i].lerp(P[i+1],t),(P[i+1]-P[i]).normalized()]

func kreuzungen():
	var t0=Time.get_ticks_msec()
	for k in SEG:
		var L2:Array=SEG[k]
		for a in L2.size():
			for b in range(a+1,L2.size()):
				var sa:Vector2i=L2[a];var sb:Vector2i=L2[b]
				if sa.x==sb.x:continue
				var ra=ROADS[sa.x];var rb=ROADS[sb.x]
				var x=Geometry2D.segment_intersects_segment(ra.P[sa.y],ra.P[sa.y+1],rb.P[sb.y],rb.P[sb.y+1])
				if x==null:continue
				_junc(x,sa.x,sb.x)
	for ri in ROADS.size():
		var r=ROADS[ri]
		for e in [r.P[0],r.P[r.P.size()-1]]:
			var n=naechst(e,ri)
			if n[2]>=0 and n[3]<ROADS[n[2]].w+3.0:_junc(e,ri,n[2])
	print("SUED Kreuzungen ",JUNC.size()," ",Time.get_ticks_msec()-t0," ms")
func _junc(p:Vector2,a:int,b:int):
	for j in JUNC:
		if j.p.distance_to(p)<14.0 and ((j.a==a and j.b==b) or (j.a==b and j.b==a)):return
	JUNC.append({"p":p,"r":max(ROADS[a].w,ROADS[b].w)+ROADS[a].sw+1.0,"a":a,"b":b})
func nah_kreuzung(p:Vector2,extra:=0.0)->bool:
	for j in JUNC:
		if j.p.distance_to(p)<j.r+extra:return true
	return false

# ---------------- Bausätze ----------------
func T(c:Color)->StandardMaterial3D:return GL.T(c)
func _P(px:float,py:float,pz:float)->Vector3:return Vector3(px,KB+py,-pz)   # lokales Grundstück: pz = Tiefe weg von der Straße
const AUSSEN:=Vector3(0,0,1)
const RECHTS:=Vector3(1,0,0)
func kits_bauen():
	var t0=Time.get_ticks_msec()
	GL.ohne_tags=true
	var holzf=[Color(0.55,0.62,0.64),Color(0.74,0.68,0.54),Color(0.6,0.64,0.52),Color(0.7,0.56,0.5),Color(0.62,0.58,0.66),Color(0.78,0.74,0.62),Color(0.5,0.55,0.6),Color(0.68,0.5,0.42)]
	for i in 14:_kit("ghetto","holz_lang","gh_holzL_%d"%i,12.0,24.0,func():_k_holz(12.0,24.0,holzf[i%8],i,true))
	for i in 8:_kit("ghetto","holz_kurz","gh_holzK_%d"%i,12.0,16.0,func():_k_holz(12.0,16.0,holzf[(i*3)%8],i,false))
	for i in 5:_kit("ghetto","block","gh_block_%d"%i,20.0,18.0,func():_k_block(20.0,18.0,i,false))
	for i in 8:_kit("ghetto","laden","laden_%d"%i,15.0,14.0,func():_k_laden(15.0,14.0,i))
	for i in 4:_kit("ghetto","brache","gh_brache_%d"%i,12.0,12.0,func():_k_brache(12.0,12.0,i))
	_kit("ghetto","kirche","gh_kirche",20.0,28.0,func():_k_kirche())
	for i in 3:_kit("ghetto","werbung","werbung_%d"%i,8.0,6.0,func():_k_werbung(i))
	for i in 6:_kit("ghetto","busch","busch_%d"%i,6.0,6.0,func():_k_busch(i))
	# Südstadt
	for i in 12:_kit("sued","reihe","sd_reihe_%d"%i,9.0,18.0,func():_k_reihe(9.0,18.0,i))
	for i in 6:_kit("sued","block","sd_block_%d"%i,22.0,18.0,func():_k_block(22.0,18.0,i,true))
	KITLISTE["sued/laden"]=KITLISTE["ghetto/laden"];KITLISTE["sued/busch"]=KITLISTE["ghetto/busch"];KITLISTE["sued/werbung"]=KITLISTE["ghetto/werbung"]
	for i in 2:_kit("sued","autohandel","autohandel_%d"%i,30.0,26.0,func():_k_autohandel(i))
	for i in 2:_kit("sued","park","sd_park_%d"%i,30.0,30.0,func():_k_park(i))
	# Docks / Hafen / Industrie
	for i in 3:_kit("docks","lager","lager_%d"%i,44.0,30.0,func():_k_lager(i,false))
	_kit("docks","lager_kauf","lager_kauf",44.0,30.0,func():_k_lager(7,true))
	for i in 6:_kit("docks","container","cont_%d"%i,14.0,9.0,func():_k_container(i))
	_kit("docks","buero","dk_buero",12.0,10.0,func():_k_buero())
	_kit("docks","kran","dk_kran",30.0,24.0,func():_k_kran())
	_kit("docks","schiff","dk_schiff",30.0,160.0,func():_k_schiff())
	for i in 3:_kit("industrie","halle","halle_%d"%i,44.0,34.0,func():_k_halle(i))
	_kit("industrie","tanks","in_tanks",30.0,30.0,func():_k_tanks())
	_kit("industrie","schornstein","in_schorn",20.0,20.0,func():_k_schornstein())
	KITLISTE["industrie/lager"]=KITLISTE["docks/lager"];KITLISTE["industrie/lager_kauf"]=KITLISTE["docks/lager_kauf"];KITLISTE["industrie/container"]=KITLISTE["docks/container"]
	for k in ["halle","tanks","schornstein","lager","lager_kauf","container"]:KITLISTE["hafen/"+k]=KITLISTE["industrie/"+k]
	KITLISTE["docks/halle"]=KITLISTE["industrie/halle"];KITLISTE["industrie/buero"]=KITLISTE["docks/buero"];KITLISTE["hafen/buero"]=KITLISTE["docks/buero"]
	# Strand
	var pastell=[Color(0.98,0.75,0.8),Color(0.6,0.88,0.9),Color(0.98,0.9,0.6),Color(0.75,0.95,0.78),Color(0.85,0.78,0.98),Color(0.98,0.98,0.96),Color(0.98,0.82,0.62),Color(0.7,0.85,0.98)]
	for i in 8:_kit("strand","haus","st_haus_%d"%i,12.0,16.0,func():_k_strandhaus(pastell[i],i))
	for i in 4:_kit("strand","hotel","st_hotel_%d"%i,22.0,18.0,func():_k_hotel(pastell[(i*3)%8],i))
	for i in 3:_kit("strand","palmen","palmen_%d"%i,8.0,8.0,func():_k_palmen(i))
	KITLISTE["strand/laden"]=KITLISTE["ghetto/laden"]
	# Flugplatz
	_kit("flug","hangar","fl_hangar",40.0,44.0,func():_k_hangar())
	_kit("flug","terminal","fl_terminal",80.0,34.0,func():_k_terminal())
	_kit("flug","tower","fl_tower",14.0,14.0,func():_k_tower())
	_kit("flug","flieger","fl_flieger",32.0,34.0,func():_k_flieger())
	KITLISTE["flug/busch"]=KITLISTE["ghetto/busch"]
	GL.ohne_tags=false
	print("SUED Bausätze ",K.KITS.size()," ",Time.get_ticks_msec()-t0," ms")
func _kit(stil_:String,typ:String,name:String,w:float,d:float,f:Callable):
	rng.seed=hash(name);GL.rng.seed=hash(name)+1;L.rng.seed=hash(name)+2
	K.kit(name,w,d,f)
	var key=stil_+"/"+typ
	if not KITLISTE.has(key):KITLISTE[key]=[]
	KITLISTE[key].append(name)

func _boden(w:float,d:float,farbe:Color):
	L.box(T(farbe),_P(0,-0.07,d*0.5),Vector3(w,0.16,d),Basis(),0.0)
func _zaeune(w:float,d:float,vorn:bool,ex:float):
	var farben=[Color(0.62,0.5,0.36),Color(0.8,0.78,0.72),Color(0.5,0.42,0.34)]
	if vorn:
		var a=_P(-w*0.5+0.1,0,0.15);var e=_P(ex-1.8,0,0.15)
		if rng.randf()<0.5:L._zaun(a,e,1.3)
		else:
			GL.holzzaun(a,e,1.2,farben[rng.randi()%3],0.28)
			if rng.randf()<0.5:GL.graffiti((a+e)*0.5+Vector3(0,0.62,0.04),AUSSEN,0.45)
		L.koll_box((a+e)*0.5+Vector3(0,0.6,0),Vector3(abs(e.x-a.x),1.2,0.12))
	var s0=_P(-w*0.5+0.05,0,0.4);var s1=_P(-w*0.5+0.05,0,d-0.1)
	GL.holzzaun(s0,s1,1.8,Color(0.55,0.45,0.33),0.1);L.koll_box((s0+s1)*0.5+Vector3(0,0.9,0),Vector3(0.12,1.8,abs(s1.z-s0.z)))
	var h0=_P(-w*0.5+0.05,0,d-0.1);var h1=_P(w*0.5-0.05,0,d-0.1)
	GL.holzzaun(h0,h1,1.9,Color(0.5,0.42,0.33),0.08);L.koll_box((h0+h1)*0.5+Vector3(0,0.95,0),Vector3(w,1.9,0.12))

func _k_holz(w:float,d:float,farbe:Color,i:int,lang:bool):
	var gras=[Color(0.52,0.53,0.3),Color(0.47,0.45,0.27),Color(0.56,0.5,0.32)][i%3]
	_boden(w,d,gras)
	var hw=8.6;var hx=-(w-hw)*0.5
	L.holz_ghetto=true;L._holzhaus(_P(hx,0,0),hw,AUSSEN,farbe);L.holz_ghetto=false
	K.haupt(_P(hx,3.3,9.0),Vector3(hw,5.6,9.0),Basis(),farbe,Color(0.42,0.38,0.4),2)
	L.koll_box(_P(hx,0.35,3.4),Vector3(hw-1.0,0.7,2.2))
	var holz=T(Color(0.5,0.38,0.24))
	for sx in [-1,1]:
		var sb=Basis(Vector3(0,0,-sx),Vector3.UP,Vector3(sx,0,0))
		L.box(T(Color(0.32,0.28,0.22)),_P(hx+sx*4.33,0.9,9.0),Vector3(8.6,0.7,0.02),sb,0.0)
		if rng.randf()<0.6:GL.graffiti(_P(hx+sx*4.36,rng.randf_range(1.9,2.8),rng.randf_range(6.5,11.5)),Vector3(sx,0,0),rng.randf_range(0.6,0.85))
	if i%3==0:
		for q in 3:L.box(holz,_P(hx+[-2.75,2.75][i%2],1.95+q*0.4,4.36),Vector3(1.2,0.22,0.04),Basis(Vector3(0,0,1),rng.randf_range(-0.15,0.15)),0.012)
	if rng.randf()<0.5:L._sofa(_P(hx-2.0,0.69,3.5),0.0)
	for q in rng.randi_range(0,2):GL.muellsack(_P(hx+rng.randf_range(-3,3),0,rng.randf_range(1.2,3.2)))
	var ex=(w-3.4)*0.5
	L.box(T(Color(0.42,0.4,0.37)),_P(ex,0.012,min(d,22.0)*0.5),Vector3(3.2,0.02,min(d,22.0)),Basis(),0.0)
	if lang:
		if i%3!=2:GL.garage(_P(ex,0,20.5),0.0)
		else:GL.huette(_P(ex,0,20.5),3.4,4.0,2.3,0.0,[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4)][i%2])
		var hof=_P(hx,0,rng.randf_range(17.0,d-3.0));var x=i%4
		if x==0:GL.auto_wrack(hof,PI*0.5+rng.randf_range(-0.3,0.3))
		elif x==1:
			L.zyl(L.M.metall,hof-RECHTS*3.0,hof-RECHTS*3.0+Vector3(0,2.0,0),0.04,1.2);L.zyl(L.M.metall,hof+RECHTS*3.0,hof+RECHTS*3.0+Vector3(0,2.0,0),0.04,1.2)
			L.zyl(L.M.linie,hof-RECHTS*3.0+Vector3(0,1.9,0),hof+RECHTS*3.0+Vector3(0,1.9,0),0.01,1.0)
			for q in 5:L.box(T(GL.SPRAY[q%GL.SPRAY.size()]),hof+RECHTS*(-2.4+q*1.2)+Vector3(0,1.55,0),Vector3(0.8,0.7,0.03),Basis(),0.012)
		elif x==2:
			L.zyl(T(Color(0.3,0.6,0.9)),hof,hof+Vector3(0,0.5,0),1.4,1.05);L.zyl(T(Color(0.45,0.7,0.6)),hof+Vector3(0,0.42,0),hof+Vector3(0,0.46,0),1.3)
		else:GL.reifen(hof,3);GL.muellsack(hof+RECHTS*1.5)
	elif i%2==0:GL.auto_wrack(_P(ex,0,9.0),rng.randf_range(-0.2,0.2))
	_zaeune(w,d,true,ex)
	if lang and i%4==1:L._park(Transform3D(Basis(Vector3.UP,PI),_P(ex,0.0,6.0)),["c_wartburg","c_muscle","c_e30","c_luxus","c_trabant"][i%5])
func _k_block(w:float,d:float,i:int,sued:bool):
	_boden(w,d,Color(0.45,0.44,0.4))
	var hd=13.0;var stock=[2,3,3,4][i%4] if sued else [2,3][i%2]
	L._haus(_P(0,0,0.8),w-0.6,hd,AUSSEN,{"stock":stock,"laden":i%2==0})
	var H=3.7+(stock-1)*3.15
	K.haupt(_P(0,H*0.5,0.8+hd*0.5),Vector3(w-0.6,H,hd),Basis(),Color(0.62,0.35,0.28) if i%2==0 else Color(0.85,0.8,0.7),Color(0.35,0.33,0.33))
	if not sued:GL.graffiti(_P(rng.randf_range(-w*0.3,w*0.3),1.5,0.75),AUSSEN,0.8)
	L.box(L.M.asphalt,_P(0,0.01,(hd+1+d)*0.5),Vector3(w-1.0,0.02,d-hd-1.5),Basis(),0.0)
	L._container(_P(-w*0.3,0,hd+2.5),0.0,Color(0.2,0.3,0.25))
	_zaeune(w,d,false,0.0)
func _k_laden(w:float,d:float,i:int):
	_boden(w,d,Color(0.45,0.44,0.4))
	GL.rng.seed=1000+i
	GL.ecke_bau(func(px,py,pz):return _P(px,py,pz),w,d-1.0,AUSSEN,0.0)
	K.haupt(_P(0,2.2,(d-1.0)*0.5),Vector3(w-0.6,4.4,d-1.0),Basis(),Color(0.75,0.7,0.62),Color(0.4,0.38,0.36))
func _k_brache(w:float,d:float,i:int):
	_boden(w,d,Color(0.42,0.33,0.22))
	if i%2==0:GL.huette(_P(0,0,6.0),min(w-1.5,5.0),4.0,2.4,rng.randf_range(-0.2,0.2),[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4),Color(0.45,0.55,0.6)][i%3]);K.LOD.append([Transform3D(Basis(),_P(0,1.2,6.0)),Vector3(5,2.4,4),Color(0.55,0.55,0.55),Color(0,0,0,0)])
	else:
		GL.reifen(_P(-2,0,3.0),3);GL.auto_wrack(_P(1.0,0,7.0),rng.randf_range(0,PI))
	L._zaun(_P(-w*0.5+0.2,0,0.15),_P(w*0.5-0.2,0,0.15),1.6);L.koll_box(_P(0,0.8,0.15),Vector3(w,1.6,0.12))
func _k_kirche():
	_boden(20,28,Color(0.5,0.52,0.32))
	var wand=L._shader(L.PUTZ,{"farbe":Color(0.92,0.9,0.84)})
	var c=_P(0,0,14.0)
	L.box(wand,c+Vector3(0,3.5,0),Vector3(12,7,20),Basis(),0.05);K.haupt(c+Vector3(0,3.5,0),Vector3(12,7,20),Basis(),Color(0.92,0.9,0.84),Color(0.45,0.3,0.25),2,false)
	var dach=T(Color(0.45,0.3,0.25))
	for sx in [-1,1]:L.box(dach,c+Vector3(sx*3.2,8.6,0),Vector3(7.6,0.25,21),Basis(Vector3(0,0,1),-sx*0.62),0.03)
	L.box(wand,_P(0,6,4.0),Vector3(4,12,4),Basis(),0.05);L.koll_box(_P(0,6,4.0),Vector3(4,12,4))
	L.hex(T(Color(0.85,0.85,0.88)),[_P(-2.1,12,1.9),_P(2.1,12,1.9),_P(2.1,12,6.1),_P(-2.1,12,6.1),_P(-0.05,17,3.95),_P(0.05,17,3.95),_P(0.05,17,4.05),_P(-0.05,17,4.05)],0.04)
	L.box(L.M.holz,_P(0,15.5,4.0),Vector3(0.15,2.0,0.15),Basis(),0.0);L.box(L.M.holz,_P(0,15.9,4.0),Vector3(1.0,0.15,0.15),Basis(),0.0)
	L.box(T(Color(0.35,0.22,0.15)),_P(0,1.3,1.98),Vector3(1.8,2.6,0.05),Basis(),0.0)
	GL.label("GEMEINDE ZION",_P(0,8.3,1.95),Basis(),0.007,Color(0.95,0.9,0.7),Color(0.1,0.08,0.05))
func _k_werbung(i:int):
	var pl=["RADEBERGER COLA","SPRUNK","CLUCKIN' HUHN","PFANDHAUS 24H"]
	for sx in [-2.5,2.5]:L.zyl(L.M.metall,_P(sx,0,3.0),_P(sx,6.0,3.0),0.12,1.2)
	L.PFOSTEN.append([_P(-2.5,0,3.0),0.15,6.0]);L.PFOSTEN.append([_P(2.5,0,3.0),0.15,6.0])
	L.box(L.M.dunkel,_P(0,7.0,3.0),Vector3(7.6,3.4,0.25),Basis(),0.04)
	L.box(T(GL.SPRAY[i%GL.SPRAY.size()]),_P(0,7.0,2.85),Vector3(7.2,3.0,0.05),Basis(),0.0)
	GL.label(pl[i%pl.size()],_P(0,7.0,2.8),Basis(),0.016,Color(1,1,1),Color(0.08,0.08,0.1))
func _k_busch(i:int):
	var p=_P(0,0,3.0)
	match i%3:
		0:L._baum(p)
		1:
			for k in 3:L.kugel(L.M.laub[(i+k)%3],p+Vector3(rng.randf_range(-1.5,1.5),0.6,rng.randf_range(-1.5,1.5)),Vector3(1.2,0.9,1.2)*rng.randf_range(0.7,1.3))
		2:GL.muellsack(p);GL.reifen(p+Vector3(1.5,0,0.5),2);L.kugel(L.M.laub[1],p+Vector3(-1.2,0.5,-0.5),Vector3(1,0.8,1))
func _k_reihe(w:float,d:float,i:int):
	_boden(w,d,Color(0.45,0.55,0.3))
	var stock=2+i%2;var hd=11.0
	L._haus(_P(0,0,2.2),w-0.2,hd,AUSSEN,{"stock":stock,"laden":false})
	var H=3.7+(stock-1)*3.15
	K.haupt(_P(0,H*0.5,2.2+hd*0.5),Vector3(w-0.2,H,hd),Basis(),Color(0.62,0.33,0.25),Color(0.35,0.33,0.33))
	for k in 4:L.box(L.M.stein,_P(w*0.25,0.1+k*0.2,2.2-0.35-k*0.35),Vector3(1.6,0.2+k*0.4,0.35),Basis(),0.02)
	L.box(L.M.metall,_P(-w*0.25,0.5,1.0),Vector3(0.6,1.0,0.6),Basis(),0.02)
	_zaeune(w,d,false,0.0)
	if i%3==0:GL.graffiti(_P(rng.randf_range(-2,2),1.4,2.15),AUSSEN,0.6)
func _k_autohandel(i:int):
	L.box(L.M.asphalt,_P(0,-0.06,13),Vector3(30,0.14,26),Basis(),0.0)
	for x in range(-12,13,6):L.box(L.M.markierung,_P(x,0.02,10),Vector3(0.12,0.01,6.0),Basis(),0.0)
	var c=_P(0,0,21)
	L.box(L.M.putz[i%L.M.putz.size()],c+Vector3(0,2.2,0),Vector3(12,4.4,8),Basis(),0.05);K.haupt(c+Vector3(0,2.2,0),Vector3(12,4.4,8),Basis(),Color(0.9,0.85,0.75))
	L.box(L.M.glas[1],c+Vector3(0,1.8,4.03),Vector3(8,2.2,0.05),Basis(),0.0)
	L.box(T(Color(0.85,0.15,0.12)),c+Vector3(0,5.0,3.0),Vector3(14,1.4,0.3),Basis(),0.03)
	GL.label(["GEBRAUCHTWAGEN ZÖLLNER","AUTO-ANKAUF BAR"][i],c+Vector3(0,5.0,3.2),Basis(),0.011,Color(1,1,0.9),Color(0.1,0.05,0.05))
	for k in 8:
		var q=_P(-13+k*3.6,0,0.6)
		L.zyl(L.M.metall,q,q+Vector3(0,4.0,0),0.04,1.1)
		L.box(T(GL.SPRAY[k%GL.SPRAY.size()]),q+Vector3(0,3.6,0.2),Vector3(0.05,0.5,0.5),Basis(Vector3.UP,PI*0.25),0.0)
	for k in 5:L._park(Transform3D(Basis(Vector3.UP,PI),_P(-12+k*6,0,10)),["c_e30","c_kompakt","c_wartburg","c_muscle","c_luxus"][k])
	L._zaun(_P(-15,0,0.2),_P(-15,0,26),1.6);L._zaun(_P(15,0,0.2),_P(15,0,26),1.6)
	L.koll_box(_P(-15,0.8,13),Vector3(0.12,1.6,26));L.koll_box(_P(15,0.8,13),Vector3(0.12,1.6,26))
func _k_park(i:int):
	L.box(L.M.gras,_P(0,-0.06,15),Vector3(30,0.14,30),Basis(),0.0)
	L.box(L.M.hof,_P(0,0.01,15),Vector3(2.5,0.02,30),Basis(),0.0)
	for k in 6:L._baum(_P(rng.randf_range(-12,12),0,rng.randf_range(3,27)))
	L._bank(_P(-3,0,10),Vector3(1,0,0));L._bank(_P(3,0,20),Vector3(-1,0,0))
	if i==0:
		L.box(L.M.asphalt,_P(8,0.01,20),Vector3(12,0.02,14),Basis(),0.0);L._korb(_P(8,0,26.0),Vector3(0,0,1))
func _k_lager(i:int,kauf:bool):
	L.box(L.M.hof,_P(0,-0.06,15),Vector3(44,0.14,30),Basis(),0.0)
	var farbe=[Color(0.6,0.62,0.64),Color(0.55,0.5,0.45),Color(0.45,0.55,0.6),Color(0.62,0.55,0.4)][i%4]
	var c=_P(0,0,17)
	for sd in [[Vector3(0,0,1),40,0.0],[Vector3(0,0,-1),40,PI],[Vector3(1,0,0),24,PI*0.5],[Vector3(-1,0,0),24,-PI*0.5]]:
		GL.wellblech(c+sd[0]*(12.0 if abs(sd[0].z)>0 else 20.0)-Vector3(0,0,0),sd[1],8.0,sd[2],farbe)
	L.box(T(farbe*0.95),c+Vector3(0,4,0),Vector3(39.8,8,23.8),Basis(),0.0)
	K.haupt(c+Vector3(0,4.0,0),Vector3(40,8,24),Basis(),farbe,Color(0.5,0.3,0.25),1,false)
	var dach=T(Color(0.5,0.3,0.25))
	for sd in [-1,1]:L.box(dach,c+Vector3(0,9.3,sd*6.2),Vector3(41,0.25,12.8),Basis(Vector3(1,0,0),sd*0.2),0.03)
	for k in 3:
		var tx=-13+k*13;var tor=T(Color(0.85,0.6,0.15))
		L.box(tor,c+Vector3(tx,2.8,12.08),Vector3(6,5.6,0.1),Basis(),0.03)
		for y in range(8):L.box(T(Color(0.7,0.48,0.1)),c+Vector3(tx,0.6+y*0.65,12.15),Vector3(5.9,0.06,0.04),Basis(),0.0)
	L.box(L.M.stein_d,c+Vector3(13,0.6,13.5),Vector3(6,1.2,3),Basis(),0.02)
	for k in 3:L.box(L.M.holz,_P(-18+k*1.4,0.4,2.5),Vector3(1.2,0.8,1.0),Basis(),0.02)
	if kauf:
		L.box(T(Color(0.95,0.95,0.92)),_P(-10,4.5,4.6),Vector3(8,2.4,0.2),Basis(),0.03)
		L.zyl(L.M.metall,_P(-13,0,4.6),_P(-13,3.4,4.6),0.08,1.1);L.zyl(L.M.metall,_P(-7,0,4.6),_P(-7,3.4,4.6),0.08,1.1)
		GL.label("ZU VERKAUFEN\nLAGERHALLE",_P(-10,4.5,4.48),Basis(),0.012,Color(0.85,0.1,0.1),Color(1,1,1))
	L._zaun(_P(-22,0,0.3),_P(-6,0,0.3),2.2);L._zaun(_P(6,0,0.3),_P(22,0,0.3),2.2)
	L.koll_box(_P(-14,1.1,0.3),Vector3(16,2.2,0.12));L.koll_box(_P(14,1.1,0.3),Vector3(16,2.2,0.12))
func container(p:Vector3,yaw:float,farbe:Color):
	var m=T(farbe);var dk=T(farbe*0.75);var b=Basis(Vector3.UP,yaw)
	L.box(m,p+Vector3(0,1.3,0),Vector3(12.2,2.58,2.44),b,0.04)
	var x=-5.6
	while x<6.0:
		for sd in [-1,1]:L.box(dk,p+b*Vector3(x,1.3,sd*1.24),Vector3(0.14,2.4,0.05),b,0.0)
		x+=0.8
	for sd in [-1,1]:L.box(dk,p+b*Vector3(sd*6.12,1.3,0),Vector3(0.05,2.4,2.3),b,0.0)
func _k_container(i:int):
	L.box(L.M.hof,_P(0,-0.06,4.5),Vector3(14,0.14,9),Basis(),0.0)
	var farben=[Color(0.8,0.2,0.15),Color(0.15,0.4,0.75),Color(0.2,0.55,0.3),Color(0.9,0.6,0.1),Color(0.6,0.6,0.62),Color(0.55,0.25,0.5),Color(0.9,0.9,0.88)]
	var hmax=0
	for j in 3:
		var h=[1,2,3,4,2,3][(i+j*2)%6];hmax=max(hmax,h)
		for k in h:container(_P(0,k*2.6,1.5+j*2.6),0.0,farben[(i*3+j*5+k)%farben.size()])
	K.haupt(_P(0,hmax*1.3,4.1),Vector3(12.2,hmax*2.6,7.8),Basis(),farben[i%farben.size()],Color(0,0,0,0),0,false)
func _k_buero():
	L.box(L.M.hof,_P(0,-0.06,5),Vector3(12,0.14,10),Basis(),0.0)
	for k in 2:container(_P(0,k*2.6,5),0.0,[Color(0.92,0.92,0.9),Color(0.3,0.5,0.75)][k])
	K.haupt(_P(0,2.6,5),Vector3(12.2,5.2,2.44),Basis(),Color(0.92,0.92,0.9))
	L.box(L.M.glas[1],_P(0,1.3,3.75),Vector3(8,1.0,0.05),Basis(),0.0)
	L.box(L.M.metall,_P(-6.6,1.3,5),Vector3(0.9,2.6,2.0),Basis(),0.02)
func _k_kran():
	# Containerbrücke; Ausleger zeigt zur Straße (+z) -> wird so gestellt, dass die Straße/Kaikante vorn liegt
	var c=_P(0,0,12);var farbe=T([Color(0.92,0.3,0.15),Color(0.95,0.75,0.15),Color(0.25,0.45,0.75)][rng.randi()%3])
	for sx in [-7.0,7.0]:
		for sz in [-9.0,9.0]:L.box(farbe,c+Vector3(sx,15,sz),Vector3(1.2,30,1.2),Basis(),0.05);L.koll_box(c+Vector3(sx,15,sz),Vector3(1.2,30,1.2))
		L.box(farbe,c+Vector3(sx,30.5,30),Vector3(1.4,1.8,95),Basis(),0.05)
		L.box(farbe,c+Vector3(sx,12,0),Vector3(1.0,1.2,19),Basis(),0.04)
		L.zyl(farbe,c+Vector3(sx,31,-9),c+Vector3(sx,46,-4),0.35,1.2)
		L.zyl(farbe,c+Vector3(sx,46,-4),c+Vector3(sx,31.5,70),0.25,1.2)
	L.box(farbe,c+Vector3(0,30.5,-9),Vector3(15,2,1.4),Basis(),0.05);L.box(farbe,c+Vector3(0,30.5,9),Vector3(15,2,1.4),Basis(),0.05)
	L.box(L.M.weiss,c+Vector3(0,28.5,24),Vector3(3,2.5,3.5),Basis(),0.04);L.box(L.M.glas[0],c+Vector3(0,28.5,25.8),Vector3(2.6,1.6,0.1),Basis(),0.0)
	L.zyl(L.M.linie,c+Vector3(0,29.6,34),c+Vector3(0,14,34),0.04,1.0)
	container(c+Vector3(0,11.4,34),0.0,Color(0.8,0.2,0.15))
	K.LOD.append([Transform3D(Basis(),c+Vector3(0,15,0)),Vector3(15,30,19),Color(0.9,0.4,0.2),Color(0,0,0,0)])
	K.LOD.append([Transform3D(Basis(),c+Vector3(0,30.5,30)),Vector3(15,1.8,95),Color(0.9,0.4,0.2),Color(0,0,0,0)])
func _k_schiff():
	# Frachter längs (x = Länge 160 m, Breite 26 m): lokal so, dass die Längsachse entlang der Kaikante (x) liegt
	var sch=Vector3(0,-9.0,-15);var rumpf=T(Color(0.2,0.25,0.35));var rot=T(Color(0.7,0.18,0.14))
	L.box(rot,sch+Vector3(0,1.5,0),Vector3(140,3,26),Basis(),0.05)
	L.box(rumpf,sch+Vector3(0,6.5,0),Vector3(140,7,26),Basis(),0.05)
	L.hex(rumpf,[sch+Vector3(70,0,-13),sch+Vector3(83,3,-2),sch+Vector3(83,3,2),sch+Vector3(70,0,13),sch+Vector3(70,10,-13),sch+Vector3(88,10,-2),sch+Vector3(88,10,2),sch+Vector3(70,10,13)],0.05)
	L.koll_box(sch+Vector3(0,5,0),Vector3(150,10,26))
	L.box(T(Color(0.92,0.9,0.86)),sch+Vector3(-58,17,0),Vector3(14,14,22),Basis(),0.05)
	for e in 4:
		for sd in [-1,1]:L.box(L.M.glas[1],sch+Vector3(-58,12+e*3.2,sd*11.05),Vector3(12,1.4,0.1),Basis(),0.0)
	L.box(rot,sch+Vector3(-62,27,0),Vector3(4,6,4),Basis(),0.04)
	var farben=[Color(0.8,0.2,0.15),Color(0.15,0.4,0.75),Color(0.2,0.55,0.3),Color(0.9,0.6,0.1),Color(0.6,0.6,0.62),Color(0.55,0.25,0.5)]
	for gx in range(-42,66,13):
		for gz in range(-10,11,3):
			for k in rng.randi_range(1,3):container(sch+Vector3(gx,10.0+k*2.6-2.6,gz),0.0,farben[rng.randi()%farben.size()])
	K.LOD.append([Transform3D(Basis(),sch+Vector3(0,7,0)),Vector3(150,6,26),Color(0.25,0.28,0.35),Color(0,0,0,0)])
	K.LOD.append([Transform3D(Basis(),sch+Vector3(10,13,0)),Vector3(100,6,22),Color(0.6,0.35,0.3),Color(0,0,0,0)])
func _k_halle(i:int):
	L.box(L.M.hof,_P(0,-0.06,17),Vector3(44,0.14,34),Basis(),0.0)
	var h=_P(0,0,19);var wand=L.M.ziegel[i%L.M.ziegel.size()]
	L.box(wand,h+Vector3(0,5,0),Vector3(40,10,28),Basis(),0.05);K.haupt(h+Vector3(0,5,0),Vector3(40,10,28),Basis(),Color(0.62,0.33,0.25),Color(0.35,0.33,0.33),0,false)
	for k in 4:
		var z0=-14.0+k*7.0;var z1=z0+7.0
		var p=func(x,y,z):return h+Vector3(x,y,z)
		L.hex(T(Color(0.35,0.33,0.33)),[p.call(-20,10,z0),p.call(20,10,z0),p.call(20,10,z1),p.call(-20,10,z1),p.call(-20,10.05,z0),p.call(20,10.05,z0),p.call(20,13,z1),p.call(-20,13,z1)],0.03)
		L.box(L.M.glas[0],h+Vector3(0,11.5,z1-0.1),Vector3(38,2.6,0.08),Basis(),0.0)
	for k in 4:L.box(L.M.glas[0],h+Vector3(-15+k*10,5.5,14.05),Vector3(6,4,0.1),Basis(),0.0)
	L.box(T(Color(0.85,0.55,0.12)),h+Vector3(12,3,14.06),Vector3(6,6,0.12),Basis(),0.03)
	L._container(_P(-16,0,3),0.0,Color(0.3,0.35,0.3))
func _k_tanks():
	L.box(L.M.hof,_P(0,-0.06,15),Vector3(30,0.14,30),Basis(),0.0)
	for k in 2:
		for j in 2:
			var t=_P(-7.5+k*15,0,7.5+j*15)
			L.zyl(L.M.weiss,t,t+Vector3(0,12,0),6,1.03);L.mesh(L.M.weiss,L.SPH,Transform3D(Basis().scaled(Vector3(12,3,12)),t+Vector3(0,12,0)),1.03)
			L.koll_box(t+Vector3(0,6,0),Vector3(10,12,10))
			L.box(L.M.rot,t+Vector3(0,8,6.05),Vector3(4,0.8,0.1),Basis(),0.0)
			K.LOD.append([Transform3D(Basis(),t+Vector3(0,6.5,0)),Vector3(10,13,10),Color(0.95,0.95,0.95),Color(0,0,0,0)])
	for y in [4.0,5.0]:L.zyl(L.M.metall,_P(-14,y,15),_P(14,y,15),0.4,1.1)
	L._zaun(_P(-15,0,0.3),_P(15,0,0.3),2.4);L.koll_box(_P(0,1.2,0.3),Vector3(30,2.4,0.12))
func _k_schornstein():
	L.box(L.M.hof,_P(0,-0.06,10),Vector3(20,0.14,20),Basis(),0.0)
	var c=_P(0,0,12)
	L.box(L.M.ziegel[0],c+Vector3(0,3,0),Vector3(14,6,10),Basis(),0.05);K.haupt(c+Vector3(0,3,0),Vector3(14,6,10),Basis(),Color(0.62,0.33,0.25))
	L.zyl(L.M.ziegel[0],c+Vector3(4,0,0),c+Vector3(4,45,0),2.2,1.05)
	for y in [34.0,40.0]:L.zyl(L.M.weiss,c+Vector3(4,y,0),c+Vector3(4,y+2.5,0),2.25,1.04)
	L.PFOSTEN.append([c+Vector3(4,0,0),2.2,45.0])
	K.LOD.append([Transform3D(Basis(),c+Vector3(4,22.5,0)),Vector3(4.4,45,4.4),Color(0.62,0.33,0.25),Color(0,0,0,0)])
	for k in 3:L.kugel(T(Color(0.8,0.8,0.83)),c+Vector3(4+k*2.5,48+k*2.2,k*1.5),Vector3(2.5,2.0,2.5)*(1+k*0.3))
func palme(p:Vector3,h:=8.0):
	var stamm=T(Color(0.6,0.45,0.3));var neig=Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()*rng.randf_range(0.6,1.4)
	var prev=p
	for k in 6:
		var t=(k+1)/6.0;var q=p+Vector3(0,h*t,0)+neig*t*t
		L.zyl(stamm if k%2==0 else T(Color(0.52,0.39,0.26)),prev,q,0.24-0.08*t,1.2);prev=q
	L.PFOSTEN.append([p,0.25,h])
	var gr=[T(Color(0.25,0.6,0.22)),T(Color(0.35,0.7,0.25))]
	for k in 8:
		var a=TAU*k/8.0+rng.randf()*0.3;var d=Vector3(cos(a),0,sin(a))
		var m1=prev+d*1.5+Vector3(0,0.45,0);var m2=prev+d*3.0+Vector3(0,-0.4,0)
		L.box(gr[k%2],(prev+m1)*0.5,Vector3(0.75,0.06,(m1-prev).length()),_rich(m1-prev),0.02)
		L.box(gr[k%2],(m1+m2)*0.5,Vector3(0.6,0.06,(m2-m1).length()),_rich(m2-m1),0.02)
func _rich(d:Vector3)->Basis:
	var z=d.normalized();var x=Vector3.UP.cross(z)
	if x.length()<0.01:x=Vector3.RIGHT
	x=x.normalized();return Basis(x,z.cross(x),z)
func _k_strandhaus(farbe:Color,i:int):
	L.box(T(Color(0.94,0.86,0.62)),_P(0,-0.06,8),Vector3(12,0.14,16),Basis(),0.0)
	var pm=L._shader(L.PUTZ,{"farbe":farbe*0.95});var c=_P(0,0,9.5)
	L.box(pm,c+Vector3(0,3.2,0),Vector3(10,6.4,9),Basis(),0.05);K.haupt(c+Vector3(0,3.2,0),Vector3(10,6.4,9),Basis(),farbe,Color(0.95,0.95,0.92))
	L.box(L.M.weiss,c+Vector3(0,6.55,0),Vector3(10.6,0.3,9.6),Basis(),0.03)
	for e in 2:
		L.box(L.M.glas[1],c+Vector3(-2.5,1.6+e*3.2,4.53),Vector3(3,1.6,0.05),Basis(),0.0);L.box(L.M.glas[1],c+Vector3(2.5,1.6+e*3.2,4.53),Vector3(3,1.6,0.05),Basis(),0.0)
	L.box(L.M.weiss,c+Vector3(0,3.4,5.6),Vector3(10,0.2,2.2),Basis(),0.02)
	L.box(L.M.glas[0],c+Vector3(0,4.0,6.65),Vector3(10,0.9,0.05),Basis(),0.0)
	L.box(T(Color(0.35,0.25,0.2)),c+Vector3(0,1.1,4.55),Vector3(1.1,2.2,0.05),Basis(),0.0)
	palme(_P(-4.5,0,2.5),rng.randf_range(7,9))
	L.box(T(Color(0.95,0.95,0.95)),_P(0,0.4,0.2),Vector3(12,0.8,0.15),Basis(),0.02);L.koll_box(_P(0,0.4,0.2),Vector3(12,0.8,0.15))
	if i%2==0:L._park(Transform3D(Basis(Vector3.UP,PI),_P(3.5,0,2.5)),["c_sport","c_jdm","c_kompakt"][i%3])
func _k_hotel(farbe:Color,i:int):
	L.box(L.M.pflaster,_P(0,-0.06,9),Vector3(22,0.14,18),Basis(),0.0)
	var h=[10.0,13.0,16.0,19.0][i%4];var pm=L._shader(L.PUTZ,{"farbe":farbe*0.92});var c=_P(0,0,10)
	L.box(pm,c+Vector3(0,h*0.5,0),Vector3(20,h,14),Basis(),0.05);K.haupt(c+Vector3(0,h*0.5,0),Vector3(20,h,14),Basis(),farbe,Color(0.9,0.9,0.88))
	var akz=T(farbe*0.8);var y=3.6
	while y<h-1:
		L.box(akz,c+Vector3(0,y,7.05),Vector3(20,0.35,0.15),Basis(),0.02)
		L.box(L.M.glas[1],c+Vector3(0,y+1.2,7.02),Vector3(17,1.4,0.06),Basis(),0.0);y+=3.2
	L.box(akz,c+Vector3(0,h*0.5+2,7.3),Vector3(2.4,h+4,0.6),Basis(),0.03)
	GL.label(["OCEAN","FLAMINGO","LIDO","BRANDUNG"][i%4],c+Vector3(0,h-1.5,7.5),Basis(),0.012,[Color(1,0.3,0.6),Color(0.3,1,0.95),Color(1,0.95,0.4)][i%3],Color(0.1,0.05,0.1))
	L.box(L.M.markise[i%4][0],c+Vector3(0,3.1,8.4),Vector3(18,0.12,2.6),Basis(Vector3(1,0,0),0.25),0.03)
	palme(_P(-9,0,2),8.5);palme(_P(9,0,2),9.5)
func _k_palmen(i:int):
	for k in 2+i%2:palme(_P(rng.randf_range(-3,3),0,rng.randf_range(1.5,6.5)),rng.randf_range(7,11))
func _k_hangar():
	L.box(L.M.asphalt,_P(0,-0.06,22),Vector3(40,0.14,44),Basis(),0.0)
	var h=_P(0,0,24);var m=T(Color(0.7,0.72,0.74))
	L.zyl(m,h+Vector3(0,0,-18),h+Vector3(0,0,18),16,1.02)
	L.box(L.M.dunkel,h+Vector3(0,6,18.1),Vector3(24,12,0.2),Basis(),0.0)
	L.koll_box(h+Vector3(0,7,0),Vector3(30,14,36));K.LOD.append([Transform3D(Basis(),h+Vector3(0,7,0)),Vector3(30,14,36),Color(0.7,0.72,0.74),Color(0,0,0,0)])
func _k_terminal():
	L.box(L.M.pflaster,_P(0,-0.06,17),Vector3(80,0.14,34),Basis(),0.0)
	var t=_P(0,0,18)
	L.box(L.M.weiss,t+Vector3(0,5,0),Vector3(76,10,22),Basis(),0.05);K.haupt(t+Vector3(0,5,0),Vector3(76,10,22),Basis(),Color(0.95,0.95,0.95),Color(0.25,0.4,0.6))
	L.box(L.M.glas[1],t+Vector3(0,5,11.05),Vector3(72,7,0.1),Basis(),0.0)
	L.box(T(Color(0.25,0.4,0.6)),t+Vector3(0,10.6,0),Vector3(80,1.2,26),Basis(),0.04)
	GL.label("FLUGHAFEN RADEBERG",t+Vector3(0,12.6,11.2),Basis(),0.028,Color(0.2,0.35,0.6),Color(1,1,1))
func _k_tower():
	var tw=_P(0,0,7)
	L.zyl(L.M.weiss,tw,tw+Vector3(0,28,0),2.2,1.04);L.PFOSTEN.append([tw,2.2,28.0])
	L.zyl(L.M.glas[0],tw+Vector3(0,28,0),tw+Vector3(0,32,0),4.0,1.03);L.zyl(L.M.dunkel,tw+Vector3(0,32,0),tw+Vector3(0,33,0),4.5,1.03)
	K.LOD.append([Transform3D(Basis(),tw+Vector3(0,15,0)),Vector3(4.4,30,4.4),Color(0.95,0.95,0.95),Color(0,0,0,0)])
func _k_flieger():
	var p=_P(0,0,17);var m=T(Color(0.95,0.95,0.97));var s=T(Color(0.85,0.2,0.2))
	L.kapsel(m,p+Vector3(0,4,-16),p+Vector3(0,4,16),2.0)
	L.box(s,p+Vector3(0,4.0,0),Vector3(4.05,0.5,30),Basis(),0.0)
	L.box(m,p+Vector3(0,3.5,1),Vector3(30,0.4,5),Basis(),0.03)
	L.box(s,p+Vector3(0,8,-15),Vector3(0.4,7,4),Basis(Vector3(1,0,0),-0.35),0.03)
	L.box(m,p+Vector3(0,5,-16),Vector3(11,0.3,3),Basis(),0.03)
	for sd in [-1,1]:L.zyl(L.M.metall,p+Vector3(sd*7,2.6,4),p+Vector3(sd*7,2.6,-1),1.0,1.05)
	L.koll_box(p+Vector3(0,4,0),Vector3(4,4,34));L.koll_box(p+Vector3(0,3.5,1),Vector3(30,0.6,5))
	K.LOD.append([Transform3D(Basis(),p+Vector3(0,4,0)),Vector3(4,4,32),Color(0.95,0.95,0.97),Color(0,0,0,0)])

# ---------------- Grundstücke ----------------
var FAIL:={"rect":0,"occ":0,"maske":0,"frei":0}
func _rechteck_ok(F:Vector2,t:Vector2,n:Vector2,w:float,d:float)->bool:
	var xs=[];var x0=-w*0.5+0.7
	while x0<w*0.5-0.7:xs.append(x0);x0+=2.0
	xs.append(w*0.5-0.7)
	for x in xs:
		var z=0.3
		while z<=d+0.01:
			var p=F+t*x+n*z
			if not RECT.has_point(p):FAIL.rect+=1;return false
			if _belegt(p):FAIL.occ+=1;return false
			if not maske(p):FAIL.maske+=1;return false
			if z>0.5 and frei(p)<-0.2:FAIL.frei+=1;return false
			z+=2.0
	return true
func _belegen(F:Vector2,t:Vector2,n:Vector2,w:float,d:float):
	var x=-w*0.5+0.3
	while x<=w*0.5-0.3:
		var z=0.0
		while z<=d+0.5:_occ(F+t*x+n*z);z+=1.0
		x+=1.0
func _setzen(kit:String,F:Vector2,t:Vector2,n:Vector2)->Transform3D:
	var aussen=Vector3(-n.x,0,-n.y);var rechts=Vector3.UP.cross(aussen)
	var xf=Transform3D(Basis(rechts,Vector3.UP,aussen),Vector3(F.x,0,F.y))
	PLATZ.append([kit,xf])
	for pk in K.KITS[kit].park:PARK.append([pk[0],xf*pk[1]])
	return xf
func _wahl(st:String,typ:String)->String:
	var l=KITLISTE.get(st+"/"+typ,[])
	if l.is_empty():l=KITLISTE["ghetto/"+typ] if KITLISTE.has("ghetto/"+typ) else KITLISTE["ghetto/busch"]
	return l[rng.randi()%l.size()]
func _typ(st:String,ecke:bool,r)->String:
	var x=rng.randf();var haupt=r.typ=="allee" or r.S[-1]>350.0
	match st:
		"ghetto":
			if r.typ=="gasse":return "brache" if x<0.5 else "holz_kurz"
			if ecke and x<0.7:return "laden"
			if haupt:return ["holz_lang","holz_lang","holz_lang","block","laden","werbung","holz_kurz"][rng.randi()%7]
			if x<0.08:return "block"
			if x<0.14:return "brache"
			if x<0.16:return "kirche"
			return "holz_lang" if rng.randf()<0.7 else "holz_kurz"
		"sued":
			if ecke and x<0.6:return "laden"
			if haupt:return ["block","block","laden","reihe"][rng.randi()%4]
			if x<0.03:return "autohandel"
			if x<0.06:return "park"
			if x<0.15:return "block"
			return "reihe"
		"docks":
			if x<0.12:return "lager_kauf"
			if x<0.45:return "lager"
			if x<0.55:return "buero"
			return "container"
		"industrie","hafen":
			if x<0.1:return "lager_kauf"
			if x<0.45:return "halle"
			if x<0.62:return "lager"
			if x<0.74:return "tanks"
			if x<0.8:return "schornstein"
			return "container"
		"strand":
			if ecke and x<0.4:return "laden"
			if haupt and x<0.5:return "hotel"
			if x<0.15:return "hotel"
			if x<0.25:return "palmen"
			return "haus"
		"flug":
			return ["hangar","busch","busch"][rng.randi()%3]
	return "busch"
const IMMO_MAX:={"lager":7,"autohandel":4}
func _immo_frei(F:Vector2,wunsch:String)->bool:
	var art="lager" if wunsch=="lager_kauf" else "autohandel";var n=0
	for im in IMMO:
		if im.art!=art:continue
		n+=1
		if Vector2(im.xf.origin.x,im.xf.origin.z).distance_to(F)<(320.0 if art=="lager" else 450.0):return false
	return n<IMMO_MAX[art]
func _kette(st:String,typ:String)->Array:
	var rest={"ghetto":["holz_kurz","laden","brache","busch"],"sued":["reihe","laden","busch"],"docks":["container"],
		"industrie":["lager","container"],"hafen":["lager","container"],"strand":["haus","palmen"],"flug":["busch"]}.get(st,["busch"])
	var k=[typ]
	for r in rest:
		if r!=typ:k.append(r)
	return k
func grundstuecke():
	var t0=Time.get_ticks_msec()
	for ri in ROADS.size():
		var r=ROADS[ri];var Lg:float=r.S[-1]
		for sd in [-1,1]:
			var s=4.0
			while s<Lg-4.0:
				var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var n=Vector2(-t.y,t.x)*sd
				var F=p+n*(r.w+r.sw+0.3)
				var st=stil(F)
				var ecke=frei(F+t*9.0,ri)<5.0 or frei(F-t*9.0,ri)<5.0 or nah_kreuzung(F,4.0)
				var tt=t*sd
				var kit="";var k=null
				var wunsch=_typ(st,ecke,r)
				if wunsch in ["lager_kauf","autohandel"] and not _immo_frei(F,wunsch):wunsch="lager" if wunsch=="lager_kauf" else "block"
				for typ in _kette(st,wunsch):
					var kn=_wahl(st,typ);var kk=K.KITS[kn]
					if _rechteck_ok(F+t*kk.w*0.5,tt,n,kk.w,kk.d):kit=kn;k=kk;break
				if kit=="":s+=2.0;continue
				var Fm=F+t*k.w*0.5
				_belegen(Fm,tt,n,k.w,k.d)
				var xf=_setzen(kit,Fm,tt,n)
				if kit.begins_with("lager_kauf") or kit.begins_with("autohandel"):
					IMMO.append({"art":"lager" if kit.begins_with("lager") else "autohandel","xf":xf,"stil":st})
				s+=k.w+0.6
	print("SUED FAIL ",FAIL);print("SUED Grundstücke an Straßen ",PLATZ.size()," ",Time.get_ticks_msec()-t0," ms")
# Hinterland: Originalhäuser als Vorlage, danach Füllstücke
# Tuning-Werkstatt (Halle 20 x 26 m) an einer Ghetto-Straße reservieren; gebaut wird sie im Spiel (scripts/spiel/garage.gd)
var WERKSTATT:={}
func werkstatt_reservieren(nahe_welt:Vector2):
	var ziel=nahe_welt-C;var best=null;var bd=1e9
	for ri in ROADS.size():
		var r=ROADS[ri]
		if r.typ!="strasse" or r.n.begins_with("Hinter"):continue
		var s=10.0
		while s<r.S[-1]-10.0:
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1]
			for sd in [-1,1]:
				var n=Vector2(-t.y,t.x)*sd;var F=p+n*(r.w+r.sw+0.3)
				var d=F.distance_to(ziel)
				if d<bd and d<400.0 and _rechteck_ok(F,t,n,21.0,27.0) and not nah_kreuzung(F,14.0):bd=d;best=[F,t,n,r]
			s+=6.0
	if best==null:print("SUED Werkstatt: kein Platz!");return
	var F:Vector2=best[0];var n:Vector2=best[2]
	_belegen(F,best[1],n,21.0,27.0)
	var aussen=-n
	WERKSTATT={"F":F,"yaw":atan2(aussen.x,aussen.y),"vor":F+aussen*(best[3].sw+best[3].w*0.5)}
	print("SUED Werkstatt bei ",F+C)

# Blockinneres: Häuser an Original-Positionen, aber nur mit eigener Zufahrt bis zur Straße (läuft VOR der Straßenreihe,
# damit dort Lücken für die Zufahrten bleiben)
var WEGE:=[]   # {a, b, stil}
func hinterland(haeuser:Array):
	var n0=PLATZ.size();var ohne=0
	for hw in haeuser:
		var p:Vector2=hw-C
		if not RECT.grow(-5).has_point(p) or _belegt(p) or not maske(p):continue
		if frei(p)<34.0:continue          # vorne baut die Straßenreihe
		var ns=naechst(p);if ns[2]<0 or ns[3]>110.0:continue
		var nv:Vector2=(p-ns[0]).normalized();if nv.length()<0.5:continue
		var st=stil(p)
		if st=="flug":continue
		var typ={"ghetto":"holz_kurz","sued":"reihe","docks":"container","industrie":"container","hafen":"container","strand":"haus"}[st]
		var kit=_wahl(st,typ);var k=K.KITS[kit]
		var tt=Vector2(-nv.y,nv.x)
		var F=p-nv*k.d*0.5
		if not _rechteck_ok(F,tt,nv,k.w,k.d):continue
		# Zufahrt: vom Grundstück (bei Holzhäusern von der Einfahrt) gerade zur nächsten Straße
		var ex=(k.w-3.4)*0.5 if kit.begins_with("gh_holz") else 0.0
		var A=F+Vector2(-nv.y,nv.x)*ex
		var nr=naechst(A);if nr[2]<0:ohne+=1;continue
		var r=ROADS[nr[2]];var dir:Vector2=(nr[0]-A).normalized();var Lg=A.distance_to(nr[0])-r.w
		if Lg>95.0 or dir.dot(-nv)<0.6:ohne+=1;continue
		var ok=true;var q0=0.6
		while q0<Lg:
			var q=A+dir*q0
			for lat in [-1.6,0.0,1.6]:
				var qq=q+Vector2(-dir.y,dir.x)*lat
				if not maske(qq) or _belegt(qq):ok=false
			var nq=naechst(q)
			if nq[2]!=nr[2] and frei(q)<1.0:ok=false
			if not ok:break
			q0+=1.5
		if not ok:ohne+=1;continue
		_belegen(F,tt,nv,k.w,k.d);_setzen(kit,F,tt,nv)
		var q1=0.0
		while q1<=Lg:
			for lat in [-1.8,-0.6,0.6,1.8]:_occ(A+dir*q1+Vector2(-dir.y,dir.x)*lat)
			q1+=1.0
		WEGE.append({"a":A,"b":A+dir*(Lg+0.2),"stil":st})
	print("SUED Hinterhäuser ",PLATZ.size()-n0," ohne Zufahrt verworfen ",ohne)
func fuellen():
	var n0=PLATZ.size();var x=RECT.position.x+3.0
	while x<RECT.end.x:
		var z=RECT.position.y+3.0
		while z<RECT.end.y:
			var p=Vector2(x,z)
			if maske(p) and not _belegt(p) and frei(p)>1.0 and frei(p)<45.0 and stil(p)!="flug":
				var st=stil(p);var typ={"ghetto":"busch","sued":"busch","docks":"container","industrie":"container","hafen":"container","strand":"palmen","flug":"busch"}[st]
				if rng.randf()<(0.12 if typ=="container" else 0.07):
					var kit=_wahl(st,typ);var k=K.KITS[kit]
					var ns=naechst(p);var tt:Vector2=ns[1] if ns[2]>=0 else Vector2(1,0);var nv=Vector2(-tt.y,tt.x)
					if ns[2]>=0 and (p-ns[0]).dot(nv)<0:nv=-nv;tt=-tt
					if _rechteck_ok(p,tt,nv,k.w,k.d):_belegen(p,tt,nv,k.w,k.d);_setzen(kit,p,tt,nv)
			z+=7.0
		x+=7.0
	print("SUED Füllstücke ",PLATZ.size()-n0)

# Kaikante, Kräne, Schiffe (Docks)
func hafenkante():
	var n=0;var kr=0;var letzte_kran=Vector2(1e9,1e9);var schiffe=[]
	var k=0
	while k<MNZ-1:
		var i=0
		while i<MNX-1:
			var j=k*MNX+i
			if MASKE[j]==1 and stil(Vector2(MX0+i*MST,MZ0+k*MST)-C)=="docks":
				for d in [Vector2i(0,1),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,-1)]:
					var a=i+d.x;var b=k+d.y
					if a<0 or b<0 or a>=MNX or b>=MNZ:continue
					if WASSER[b*MNX+a]==1:
						var pw=Vector2(MX0+i*MST,MZ0+k*MST)-C;var dn=Vector2(d.x,d.y)
						var c=pw+dn*(MST*0.5)
						var tt=Vector2(-dn.y,dn.x)
						L.box(L.M.stein_d,Vector3(c.x,KB-4.6,c.y),Vector3(abs(tt.x)*MST+abs(dn.x)*1.2+0.02,9.5,abs(tt.y)*MST+abs(dn.y)*1.2+0.02),Basis(),0.03)
						L.koll_box(Vector3(c.x,KB-4.6,c.y),Vector3(abs(tt.x)*MST+abs(dn.x)*1.2,9.5,abs(tt.y)*MST+abs(dn.y)*1.2))
						if (i+k)%2==0:L.zyl(T(Color(0.15,0.15,0.15)),Vector3(c.x-dn.x*1.0,KB,c.y-dn.y*1.0),Vector3(c.x-dn.x*1.0,KB+0.7,c.y-dn.y*1.0),0.22,1.15)
						n+=1
						# Kran alle ~70 m an Süd-Kaikanten
						var F=pw-dn*2.0
						if dn==Vector2(0,1) and F.distance_to(letzte_kran)>70.0:
							var kk=K.KITS["dk_kran"]
							if _rechteck_ok(F-dn*0.0+Vector2(0,0),Vector2(-1,0),-dn,kk.w*0.8,kk.d*0.8) or true:
								_setzen("dk_kran",F,Vector2(-1,0),-dn);_belegen(F,Vector2(-1,0),-dn,kk.w,kk.d);letzte_kran=F;kr+=1
								schiffe.append(F)
			i+=1
		k+=1
	# Schiffe an manchen Kränen
	var gesetzt=[]
	for F in schiffe:
		var weit=true
		for g in gesetzt:
			if g.distance_to(F)<190.0:weit=false
		if not weit:continue
		var mitte=F+Vector2(0,17.0)
		var ok=true
		for dx in range(-80,81,20):
			for dz in [8.0,30.0]:
				if not wasser(F+Vector2(dx,dz)):ok=false
		if not ok:continue
		var xf=Transform3D(Basis(Vector3(-1,0,0),Vector3.UP,Vector3(0,0,-1)),Vector3(F.x,0,F.y+3.0))
		PLATZ.append(["dk_schiff",xf]);gesetzt.append(F)
	print("SUED Kaikante ",n," Kräne ",kr," Schiffe ",gesetzt.size())

# Flughafen: Terminal, Vorfeld mit Fliegern, Tower, Hangars (Weltkoordinaten nach Original-Rollbahnen)
var VORFELD:=[]
func flughafen():
	var n0=PLATZ.size()
	var setz=func(kit:String,fw:Vector2,nord:bool):
		var F=fw-C;var n=Vector2(0,-1) if nord else Vector2(0,1);var tt=Vector2(1,0);var k=K.KITS[kit]
		if not maske(F) :return
		_belegen(F,tt,n,k.w,k.d);_setzen(kit,F,tt,n)
	setz.call("fl_terminal",Vector2(-2000,1885),true)
	for x in [-2120.0,-2050.0,-1980.0,-1910.0]:setz.call("fl_flieger",Vector2(x,1931),true)
	setz.call("fl_tower",Vector2(-1760,1885),true)
	for x in [-2620.0,-2560.0,-2500.0,-2440.0]:setz.call("fl_hangar",Vector2(x,1885),true)
	for x in [-2700.0,-2640.0,-2580.0]:setz.call("fl_hangar",Vector2(x,1968),false)
	VORFELD.append(Rect2(Vector2(-2680,1885)-C,Vector2(1000,54)))
	print("SUED Flughafen ",PLATZ.size()-n0)

# ---------------- Geometrie: Fahrbahnen, Gehwege, Sonderflächen ----------------
func fahrbahnen():
	var so=L._st(L.M.asphalt,true);var flick=T(Color(0.2,0.2,0.22))
	var alt=L.koll_an;L.koll_an=true
	for ri in ROADS.size():
		var r=ROADS[ri]
		var P:PackedVector2Array=r.P.duplicate();var n=P.size()
		P[0]=P[0]+(P[0]-P[1]).normalized()*r.w*0.6;P[n-1]=P[n-1]+(P[n-1]-P[n-2]).normalized()*r.w*0.6
		var Ls=[];var Rs=[]
		for i in n:
			var d:Vector2=(P[min(i+1,n-1)]-P[max(i-1,0)]).normalized();var nn=Vector2(-d.y,d.x)
			Ls.append(P[i]+nn*r.w);Rs.append(P[i]-nn*r.w)
		for i in n-1:
			L._tri(so,Vector3(Ls[i].x,0.03,Ls[i].y),Vector3(Ls[i+1].x,0.03,Ls[i+1].y),Vector3(Rs[i+1].x,0.03,Rs[i+1].y),Vector3.UP)
			L._tri(so,Vector3(Ls[i].x,0.03,Ls[i].y),Vector3(Rs[i+1].x,0.03,Rs[i+1].y),Vector3(Rs[i].x,0.03,Rs[i].y),Vector3.UP)
	L.koll_an=alt
	for ri in ROADS.size():
		var r=ROADS[ri];var s=4.0;var Lg:float=r.S[-1]
		while s<Lg-4.0:
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1]
			if r.typ!="gasse" and fmod(s,9.0)<3.0 and not nah_kreuzung(p,2.0) and rng.randf()<0.85:
				L.box(L.M.markierung,Vector3(p.x,0.045,p.y),Vector3(0.14,0.012,2.6),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
			if rng.randf()<0.12 and stil(p) in ["ghetto","sued","docks","industrie"]:
				var q=p+Vector2(-t.y,t.x)*rng.randf_range(-r.w+0.8,r.w-0.8)
				L.box(flick,Vector3(q.x,0.04,q.y),Vector3(rng.randf_range(0.8,2.6),0.01,rng.randf_range(0.6,1.8)),Basis(Vector3.UP,rng.randf()*TAU),0.0)
			s+=3.0
	# Rollbahn, Taxiways, Gleise
	var so2=L._st(L.M.asphalt,true)
	for v in VORFELD:
		var a=v.position;var e=v.end
		L._tri(so2,Vector3(a.x,KB+0.035,a.y),Vector3(e.x,KB+0.035,a.y),Vector3(e.x,KB+0.035,e.y),Vector3.UP);L._tri(so2,Vector3(a.x,KB+0.035,a.y),Vector3(e.x,KB+0.035,e.y),Vector3(a.x,KB+0.035,e.y),Vector3.UP)
	for sd in SONDER:
		var P:PackedVector2Array=sd.P;var n=P.size()
		if sd.typ=="schiene":
			for i in n-1:
				var a:Vector2=P[i];var b:Vector2=P[i+1];var t=(b-a).normalized();var nn=Vector2(-t.y,t.x);var Lg=a.distance_to(b);var s=0.0
				if auf_fahrbahn((a+b)*0.5,-1,2.5) or not maske((a+b)*0.5):continue
				var bas=Basis(Vector3.UP,atan2(t.x,t.y))
				L.box(T(Color(0.45,0.4,0.36)),Vector3((a.x+b.x)*0.5,KB+0.05,(a.y+b.y)*0.5),Vector3(3.6,0.1,Lg+0.2),bas,0.0)
				while s<Lg:
					var q=a+t*s;L.box(L.M.holz,Vector3(q.x,KB+0.13,q.y),Vector3(2.6,0.1,0.25),bas,0.0);s+=1.0
				for o in [-0.72,0.72]:
					var q=(a+b)*0.5+nn*o;L.box(L.M.chrom,Vector3(q.x,KB+0.24,q.y),Vector3(0.1,0.12,Lg+0.05),bas,0.0)
			continue
		var Ls=[];var Rs=[]
		for i in n:
			var d:Vector2=(P[min(i+1,n-1)]-P[max(i-1,0)]).normalized();var nn=Vector2(-d.y,d.x)
			Ls.append(P[i]+nn*sd.w);Rs.append(P[i]-nn*sd.w)
		for i in n-1:
			if not (maske(P[i]) and maske(P[i+1])):continue
			L._tri(so2,Vector3(Ls[i].x,KB+0.04,Ls[i].y),Vector3(Ls[i+1].x,KB+0.04,Ls[i+1].y),Vector3(Rs[i+1].x,KB+0.04,Rs[i+1].y),Vector3.UP)
			L._tri(so2,Vector3(Ls[i].x,KB+0.04,Ls[i].y),Vector3(Rs[i+1].x,KB+0.04,Rs[i+1].y),Vector3(Rs[i].x,KB+0.04,Rs[i].y),Vector3.UP)
		if sd.typ=="runway":
			for i in range(0,n-1,3):
				var a:Vector2=P[i];var b:Vector2=P[min(i+1,n-1)];var t=(b-a).normalized()
				L.box(L.M.markierung,Vector3(a.x,KB+0.05,a.y),Vector3(0.6,0.01,6.0),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
		else:
			for i in range(0,n-1,2):
				var a:Vector2=P[i];var b:Vector2=P[min(i+1,n-1)];var t=(b-a).normalized()
				L.box(T(Color(0.95,0.8,0.15)),Vector3(a.x,KB+0.05,a.y),Vector3(0.25,0.01,3.0),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)

# Gehwegplatten: Kacheln minus Fahrbahnbänder, nur auf der Maske
const KRUND:=3.0
var BODEN:={}
func _flaeche(poly:PackedVector2Array,y:float,m:Material):
	var so=L._st(m,true);var idx=Geometry2D.triangulate_polygon(poly)
	for i in range(0,idx.size(),3):
		var a=poly[idx[i]];var b=poly[idx[i+1]];var c=poly[idx[i+2]]
		L._tri(so,Vector3(a.x,y,a.y),Vector3(b.x,y,b.y),Vector3(c.x,y,c.y),Vector3.UP)
func wege():
	var dreck=L._toon(Color(0.4,0.34,0.25))
	for w in WEGE:
		var a:Vector2=w.a;var b:Vector2=w.b;var d=(b-a).normalized();var n=Vector2(-d.y,d.x)*1.5
		var m=dreck if w.stil=="ghetto" else (L.M.pflaster if w.stil in ["sued","strand"] else L.M.hof)
		var so=L._st(m,true);var y=KB+0.012
		var P=[a+n,b+n,b-n,a-n]
		L._tri(so,Vector3(P[0].x,y,P[0].y),Vector3(P[1].x,y,P[1].y),Vector3(P[2].x,y,P[2].y),Vector3.UP)
		L._tri(so,Vector3(P[0].x,y,P[0].y),Vector3(P[2].x,y,P[2].y),Vector3(P[3].x,y,P[3].y),Vector3.UP)
func platten():
	BODEN={"ghetto":L._toon(Color(0.44,0.43,0.28)),"sued":L.M.gras,"docks":L.M.hof,"industrie":L.M.hof,"hafen":L.M.hof,"strand":L._toon(Color(0.85,0.76,0.55)),"flug":L._toon(Color(0.47,0.55,0.32))}
	var t=Time.get_ticks_msec();var n=0
	var x=RECT.position.x
	while x<RECT.end.x-0.01:
		var z=RECT.position.y
		while z<RECT.end.y-0.01:
			n+=_kachel(Rect2(x,z,min(100.0,RECT.end.x-x),min(100.0,RECT.end.y-z)),0)
			z+=100.0
		x+=100.0
	print("SUED Platten ",n," ",Time.get_ticks_msec()-t," ms")
func _maske_voll(R:Rect2)->int:   # 2 = ganz, 1 = teils, 0 = nichts
	var ja=0;var nein=0;var x=R.position.x
	while x<=R.end.x+0.01:
		var z=R.position.y
		while z<=R.end.y+0.01:
			var p=Vector2(x,z);var aus=false
			for a in AUS:
				if a.has_point(p):aus=true
			if maske(p) and not aus:ja+=1
			else:nein+=1
			z+=R.size.y/4.0
		x+=R.size.x/4.0
	return 2 if nein==0 else (0 if ja==0 else 1)
func _kachel(R:Rect2,tiefe:int)->int:
	var mv=_maske_voll(R)
	if mv==0:return 0
	var T4=PackedVector2Array([R.position,Vector2(R.end.x,R.position.y),R.end,Vector2(R.position.x,R.end.y)])
	var teile=[T4];var loch=false;var geh=[]
	var gross=R.grow(KRUND+12.0)
	if mv==2:
		var gesehen={}
		for gx in range(int(floor(gross.position.x/20.0)),int(floor(gross.end.x/20.0))+1):
			for gz in range(int(floor(gross.position.y/20.0)),int(floor(gross.end.y/20.0))+1):
				for sg in SEG.get(Vector2i(gx,gz),[]):gesehen[sg.x]=true
		for ri in gesehen:
			var r=ROADS[ri]
			var stueck=PackedVector2Array();var stuecke=[]
			for q in r.P:
				if gross.has_point(q):stueck.append(q)
				elif stueck.size()>0:stueck.append(q);stuecke.append(stueck);stueck=PackedVector2Array()
			if stueck.size()>0:stuecke.append(stueck)
			for st in stuecke:
				if st.size()<2:continue
				for band in Geometry2D.offset_polyline(st,r.w+r.sw,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):geh.append(band)
				for band in Geometry2D.offset_polyline(st,r.w+KRUND,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
					var neu=[]
					for tp in teile:
						for e in Geometry2D.clip_polygons(tp,band):
							if Geometry2D.is_polygon_clockwise(e):loch=true
							else:neu.append(e)
					teile=neu
	if (loch or mv==1) and tiefe<3:
		var h=R.size*0.5;var c=0
		for k in [Vector2(0,0),Vector2(h.x,0),Vector2(0,h.y),h]:c+=_kachel(Rect2(R.position+k,h),tiefe+1)
		return c
	if mv!=2:return 0
	var c=0;var st=stil(R.get_center())
	var mat=BODEN.get(st,L.M.gras)
	var gw=L.M.hof if st in ["docks","industrie","hafen","flug"] else L.M.pflaster
	for tp in teile:
		for g in Geometry2D.offset_polygon(tp,KRUND,Geometry2D.JOIN_ROUND):
			if Geometry2D.is_polygon_clockwise(g):continue
			for e in Geometry2D.intersect_polygons(g,T4):
				if Geometry2D.is_polygon_clockwise(e) or abs(L._flaeche2(e))<1.0:continue
				L._platte(e,-0.6,KB,mat,L.M.stein);c+=1
				for band in geh:
					for f in Geometry2D.intersect_polygons(e,band):
						if Geometry2D.is_polygon_clockwise(f) or abs(L._flaeche2(f))<0.5:continue
						_flaeche(f,KB+0.006,gw)
	return c

# Strommasten (Ghetto/Süd), Laternen (Strand/Süd)
func strassenrand():
	for ri in ROADS.size():
		var r=ROADS[ri];if r.typ=="gasse":continue
		var s=10.0;var prev=null;var Lg:float=r.S[-1]
		while s<Lg-6.0:
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var n=Vector2(-t.y,t.x)
			var q=p+n*(r.w+0.6);var st=stil(q)
			if not nah_kreuzung(q,3.0) and frei(q,ri)>0.5 and maske(q):
				if st in ["ghetto","sued","industrie","docks","hafen"]:
					var top=GL.mast(Vector3(q.x,KB,q.y))
					if prev!=null and top.distance_to(prev)<40.0:GL.kabel(prev,top,0.9)
					prev=top
				else:
					L._laterne(Vector3(q.x,KB,q.y),Vector3(-n.x,0,-n.y));prev=null
			else:prev=null
			s+=30.0

# Parken am Straßenrand
func parken_strasse():
	var kinds=["c_wartburg","c_muscle","c_e30","c_luxus","c_trabant","c_kompakt","c_suv","c_jdm"]
	for ri in ROADS.size():
		var r=ROADS[ri];if r.typ=="gasse":continue
		var s=8.0
		while s<r.S[-1]-8.0:
			s+=rng.randf_range(7,14)
			if rng.randf()>0.22:continue
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var sd=[-1,1][rng.randi()%2];var n=Vector2(-t.y,t.x)*sd
			var q=p+n*(r.w-1.15)
			var ok=not nah_kreuzung(q,10.0) and (WERKSTATT.is_empty() or q.distance_to(WERKSTATT.vor)>18.0)
			for e in [q+t*2.4+n*1.0,q-t*2.4+n*1.0,q+t*2.4-n*1.0,q-t*2.4-n*1.0]:
				var ns=naechst(e)
				if ns[2]!=ri or ns[3]>r.w-0.15:ok=false
			if not ok:continue
			var h=t*(-sd)
			PARK.append([kinds[rng.randi()%kinds.size()],Transform3D(Basis(Vector3.UP,atan2(h.x,h.y)),Vector3(q.x,0.03,q.y))])
