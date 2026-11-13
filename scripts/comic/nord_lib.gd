extends "res://scripts/comic/sued_lib.gd"
# Obere Kartenhälfte (alles außer Comic-Stadt und Süden): Stadtband Nord + Oststadt + Sonnenhügel, Landstraßen und Autobahn-Ring,
# Gefängnis, Militärflugplatz, Wüstenflugplatz, Staubwinkel (Redneck-Trailerdorf), Farm, Wüste, Nordbucht.
# Anders als der Süden ist das Gelände hier hügelig: Straßen, Gehwege und Grundstücke folgen einer geglätteten Höhe (HS),
# Grundstücke werden terrassiert, Landstraßen/Autobahn bekommen ein eigenes Längsprofil und schneiden sich ins Gelände.
const H0:=7.0
var GX0:float;var GZ0:float;var GNX:int;var GNZ:int
var HS:PackedFloat32Array      # geglättete Höhe (Welt)
var TH:PackedFloat32Array      # Zielhöhe Gelände (NAN = Original)
var NAT:PackedFloat32Array
var KLASSE:PackedByteArray     # Stil aus Originalhäusern: 0 nichts, 1 wohn, 2 hoch, 3 ghetto
var STADT:PackedByteArray      # Zelle nahe einer Stadtstraße
var SUED_RW:Rect2
var SU=null                    # Süd-Generator (für Abstände zu dessen Straßen/Bebauung)
var AUSW_W:Rect2=Rect2()       # Comic-Innenstadt (Welt)
const ORTE:={"knast":[Vector2(2000,-5050),340.0],"militaer":[Vector2(-2600,-5450),700.0],"wflug":[Vector2(600,-5265),520.0],
	"redneck":[Vector2(1750,-5950),420.0],"farm":[Vector2(1950,-7750),650.0]}
var TERR:=[]   # [Rect-Ecken (4 x Vector2 Welt), Höhe]

func _init(lib,ghetto_lib,kit_lib,gelaende):
	super(lib,ghetto_lib,kit_lib,gelaende);rng.seed=4711

# ---------------- Raster ----------------
func _ix(x:float)->int:return int(round((x-GX0)/MST))
func _kz(z:float)->int:return int(round((z-GZ0)/MST))
func hs_welt(x:float,z:float)->float:
	var fx=(x-GX0)/MST;var fz=(z-GZ0)/MST;var i=int(floor(fx));var k=int(floor(fz))
	i=clamp(i,0,GNX-2);k=clamp(k,0,GNZ-2);var tx=clamp(fx-i,0.0,1.0);var tz=clamp(fz-k,0.0,1.0)
	var a=HS[k*GNX+i];var b=HS[k*GNX+i+1];var c=HS[(k+1)*GNX+i];var d=HS[(k+1)*GNX+i+1]
	return lerp(lerp(a,b,tx),lerp(c,d,tx),tz)
func hy(pl:Vector2)->float:   # lokale Höhe (relativ zu H0) aus HS
	var w=pl+C;return hs_welt(w.x,w.y)-H0
func ny(pl:Vector2)->float:   # Originalgelände lokal
	var w=pl+C;return G0._nat(w.x,w.y)-H0

func maske_bauen(rect_welt:Rect2,aus_welt:Array):
	var t0=Time.get_ticks_msec()
	SUED_RW=aus_welt[1]
	GX0=G0.X0;GZ0=G0.Z0;GNX=G0.rx;GNZ=G0.rz;MST=10.0
	MX0=GX0;MZ0=GZ0;MNX=GNX;MNZ=GNZ
	var N=GNX*GNZ
	NAT=G0._nh.duplicate()
	HS=NAT.duplicate()
	for j in N:HS[j]=max(HS[j],0.5)
	for durch in 3:_blur(HS,4)
	TH=PackedFloat32Array();TH.resize(N);TH.fill(NAN)
	WASSER=PackedByteArray();WASSER.resize(N);MASKE=PackedByteArray();MASKE.resize(N)
	var dist=PackedInt32Array();dist.resize(N);dist.fill(99999);var q=[]
	for j in N:
		if NAT[j]<1.0:WASSER[j]=1;dist[j]=0;q.append(j)
	_bfs(dist,q,4)
	# Stadtzellen: nahe einer Stadtstraße der Originalkarte (wird in laden() gefüllt) -> dort bebaubar
	STADT=PackedByteArray();STADT.resize(N)
	KLASSE=PackedByteArray();KLASSE.resize(N)
	_WD=dist
	plateaus()
	print("NORD Raster ",GNX,"x",GNZ," ",Time.get_ticks_msec()-t0," ms")
var _WD:PackedInt32Array
func _bfs(dist:PackedInt32Array,q:Array,maxd:int):
	var h=0
	while h<q.size():
		var j=q[h];h+=1;var i=j%GNX;var k=j/GNX;var nd=dist[j]+1
		if nd>maxd:continue
		if i>0 and dist[j-1]>nd:dist[j-1]=nd;q.append(j-1)
		if i<GNX-1 and dist[j+1]>nd:dist[j+1]=nd;q.append(j+1)
		if k>0 and dist[j-GNX]>nd:dist[j-GNX]=nd;q.append(j-GNX)
		if k<GNZ-1 and dist[j+GNX]>nd:dist[j+GNX]=nd;q.append(j+GNX)
func _blur(A:PackedFloat32Array,r:int):
	var B=PackedFloat32Array();B.resize(A.size())
	var n=2*r+1
	for k in GNZ:
		var s=0.0;var base=k*GNX
		for i in range(-r,r+1):s+=A[base+clamp(i,0,GNX-1)]
		for i in GNX:
			B[base+i]=s/n
			s+=A[base+min(i+r+1,GNX-1)]-A[base+max(i-r,0)]
	for i in GNX:
		var s=0.0
		for k in range(-r,r+1):s+=B[clamp(k,0,GNZ-1)*GNX+i]
		for k in GNZ:
			A[k*GNX+i]=s/n
			s+=B[min(k+r+1,GNZ-1)*GNX+i]-B[max(k-r,0)*GNX+i]
func _ausgenommen(w:Vector2)->bool:
	if SUED_RW.has_point(w):return true
	for a in AUS:
		if a.has_point(w-C):return true
	return false

# ---------------- Straßen ----------------
const STADT_TYPEN:=["strasse","allee","gasse"]
const LAND_TYPEN:=["land","autobahn","rampe","piste"]
func laden(datei:String,rect_lokal:Rect2,aus:Array):
	RECT=rect_lokal;AUS=aus
	var d=JSON.parse_string(FileAccess.get_file_as_string(datei))
	# Klassen-Raster aus Originalhäusern (nächstes Haus bis 90 m)
	var kd=PackedInt32Array();kd.resize(GNX*GNZ);kd.fill(99999);var q=[]
	for h in d.houses:
		var i=_ix(h[0]);var k=_kz(h[1])
		if i<0 or k<0 or i>=GNX or k>=GNZ:continue
		var j=k*GNX+i;KLASSE[j]={"w":1,"h":2,"g":3}[h[2]];kd[j]=0;q.append(j)
	var hh=0
	while hh<q.size():
		var j=q[hh];hh+=1;var i=j%GNX;var k=j/GNX;var nd=kd[j]+1
		if nd>9:continue
		for jj in [j-1,j+1,j-GNX,j+GNX]:
			if jj<0 or jj>=GNX*GNZ:continue
			if kd[jj]>nd:kd[jj]=nd;KLASSE[jj]=KLASSE[j];q.append(jj)
	# Stadtstraßen rastern -> Stadtzellen (bis 70 m) -> Maske
	var sd=PackedInt32Array();sd.resize(GNX*GNZ);sd.fill(99999);var q2=[]
	for r in d.roads:
		if not r.typ in STADT_TYPEN:continue
		var P=r.P
		for a in P.size()-1:
			var A=Vector2(P[a][0],P[a][1]);var B=Vector2(P[a+1][0],P[a+1][1]);var Lg=A.distance_to(B);var s=0.0
			while s<=Lg:
				var p=A.lerp(B,s/max(Lg,0.01));var i=_ix(p.x);var k=_kz(p.y)
				if i>=0 and k>=0 and i<GNX and k<GNZ and sd[k*GNX+i]!=0:sd[k*GNX+i]=0;q2.append(k*GNX+i)
				s+=5.0
	_bfs(sd,q2,7)
	for j in GNX*GNZ:
		if sd[j]>7 or WASSER[j]==1 or _WD[j]<3:continue
		var i=j%GNX;var k=j/GNX;var w=Vector2(GX0+i*MST,GZ0+k*MST)
		if _ausgenommen(w):continue
		# zu steil?
		if i>0 and k>0 and i<GNX-1 and k<GNZ-1:
			var gx=(HS[j+1]-HS[j-1])/(2*MST);var gz=(HS[j+GNX]-HS[j-GNX])/(2*MST)
			if sqrt(gx*gx+gz*gz)>0.2:continue
		STADT[j]=1;MASKE[j]=1
	# Straßen übernehmen
	for r in d.roads:
		var P=PackedVector2Array()
		for p in r.P:P.append(Vector2(p[0],p[1])-C)
		if r.typ in ["runway","taxi"]:
			for st in _stuecke_frei(P):SONDER.append({"P":_duenn(st),"w":float(r.w)*(0.5),"typ":r.typ})
			continue
		if r.typ in STADT_TYPEN:
			for st in _stuecke(P,true):_neu_n(st,r.typ,true)
		elif r.typ in LAND_TYPEN:
			for st in _stuecke_frei(P):_neu_n(st,r.typ,false)
	_raster_sperren()
	_enden_verbinden()
	_belag_bestimmen()
	_knoten_angleichen()
	print("NORD Straßen ",ROADS.size()," Sonder ",SONDER.size())

# ---------------- Straßennetz: Enden, Belag, Höhen an Knoten ----------------
func _rang(ri:int)->int:   # Vorfahrt beim Höhenangleich: kleinere Zahl = bestimmt die Höhe
	var r=ROADS[ri]
	if r.orig=="autobahn":return 0
	if r.orig=="rampe":return 1
	if r.get("belag","asphalt")=="asphalt" and not r.stadt:return 2
	if r.stadt:return 3
	return 4 if r.get("belag","")=="schotter" else 5
func _vor(rj:int,ri:int)->bool:return _rang(rj)<_rang(ri) or (_rang(rj)==_rang(ri) and rj<ri)
func _y_fremd(p:Vector2,ri:int,rand:float)->float:
	# niedrigste Fahrbahnhöhe einer vorrangigen Straße, die den Punkt überdeckt (INF = keine)
	var k=Vector2i(int(floor(p.x/20.0)),int(floor(p.y/20.0)));var y=INF
	for i in [-1,0,1]:
		for j in [-1,0,1]:
			for sg in SEG.get(k+Vector2i(i,j),[]):
				if sg.x==ri or not _vor(sg.x,ri):continue
				var r=ROADS[sg.x]
				if not r.has("Y") or sg.y+1>=r.P.size():continue
				var a:Vector2=r.P[sg.y];var b:Vector2=r.P[sg.y+1]
				var t=clamp((p-a).dot(b-a)/max((b-a).length_squared(),0.0001),0.0,1.0)
				if p.distance_to(a.lerp(b,t))<r.w+rand:y=min(y,lerp(r.Y[sg.y],r.Y[sg.y+1],t))
	return y
func _ende_frei(ri:int,p:Vector2)->bool:
	var n=naechst(p,ri)
	return n[2]<0 or n[3]>ROADS[n[2]].w+3.0
func _enden_verbinden():
	# lose Straßenenden mit der nächsten Straße verbinden (Schotterweg), wenn sie nah genug ist
	var n0=ROADS.size();var neu=0
	for ri in n0:
		var r=ROADS[ri]
		if r.orig=="autobahn" or r.P.size()<2:continue
		for ende in [0,r.P.size()-1]:
			var p:Vector2=r.P[ende]
			if not _ende_frei(ri,p):continue
			var n=naechst(p,ri)
			if n[2]<0 or n[2]>=n0 or n[3]>70.0 or n[3]<4.0:continue
			if ROADS[n[2]].orig=="autobahn":continue
			var ziel:Vector2=n[0];var L2=p.distance_to(ziel);var ok=true;var Q=PackedVector2Array()
			var k=0
			while k<=int(ceil(L2/4.0)):
				var q=p.lerp(ziel,min(1.0,k*4.0/L2))
				if _ausgenommen(q+C):ok=false;break
				Q.append(q);k+=1
			if not ok or Q.size()<2:continue
			_neu_n(Q,"piste",false);ROADS[ROADS.size()-1]["belag"]="schotter";neu+=1
	print("NORD Verbinder ",neu)
func _belag_bestimmen():
	var n_s=0;var n_sand=0
	for ri in ROADS.size():
		var r=ROADS[ri]
		if r.has("belag"):n_s+=1;continue
		r["belag"]="asphalt"
		if r.stadt or r.orig in ["autobahn","rampe"]:continue
		var mitte:Vector2=r.P[r.P.size()/2]+C;var b=_boden_art(mitte)
		if r.orig=="piste":
			r["belag"]="sand" if b[2]+b[4]>0.5 else "schotter"
		elif r.S[-1]<500.0 and (_ende_frei(ri,r.P[0]) or _ende_frei(ri,r.P[r.P.size()-1])):
			r["belag"]="sand" if b[2]+b[4]>0.6 else "schotter"   # kurze Stichstraßen: Feld-/Sandweg
		if r.belag=="schotter":n_s+=1
		elif r.belag=="sand":n_sand+=1
	print("NORD Belag Schotter ",n_s," Sand ",n_sand)
func _knoten_angleichen():
	# Wo eine Straße auf eine vorrangige trifft/sie kreuzt: genau deren Höhe übernehmen, 15 m sanft auslaufen
	var n=0
	for ri in ROADS.size():
		var r=ROADS[ri]
		if not r.has("Y"):continue
		var Y:PackedFloat32Array=r.Y;var fest=[]
		for i in r.P.size():
			var yf=_y_fremd(r.P[i],ri,0.5)
			if yf<INF:fest.append([i,yf])
		if fest.is_empty():continue
		var Y2=Y.duplicate()
		for i in r.P.size():
			var g=0.0;var yz=0.0;var bd=1e9
			for f in fest:
				var d=abs(r.S[i]-r.S[f[0]])
				if d<bd:bd=d;yz=f[1]
			if bd<15.0:Y2[i]=lerp(yz,Y[i],smoothstep(0.0,15.0,bd))
		r.Y=Y2;n+=1
	print("NORD Knoten angeglichen ",n)
func _stuecke_frei(P:PackedVector2Array)->Array:   # nur Ausschlüsse/Wasser, keine Maske
	var aus=[];var cur=PackedVector2Array()
	for p in P:
		var drin=not _ausgenommen(p+C)
		if drin:cur.append(p)
		else:
			if cur.size()>=3:aus.append(cur)
			cur=PackedVector2Array()
	if cur.size()>=3:aus.append(cur)
	return aus
# Landstraßen: Stützpunkte alle ~18 m, dann Ecken rund schleifen (Chaikin) -> weiche Kurven und Serpentinen
func _rund(P:PackedVector2Array)->PackedVector2Array:
	var R=PackedVector2Array();R.append(P[0]);var acc=0.0
	for i in range(1,P.size()-1):
		acc+=P[i].distance_to(P[i-1])
		if acc>=18.0:R.append(P[i]);acc=0.0
	if R.size()>1 and R[R.size()-1].distance_to(P[P.size()-1])<7.0:R.remove_at(R.size()-1)
	R.append(P[P.size()-1])
	for it in 3:
		if R.size()<3:break
		var N=PackedVector2Array();N.append(R[0])
		for i in R.size()-1:
			var a=R[i];var b=R[i+1]
			if i>0:N.append(a.lerp(b,0.25))
			if i<R.size()-2:N.append(a.lerp(b,0.75))
		N.append(R[R.size()-1]);R=N
	return _duenn(R)
func _neu_n(P:PackedVector2Array,typ:String,stadt:bool):
	if not stadt and typ in ["land","piste","rampe","autobahn"] and P.size()>2:P=_rund(P)
	var Q=_duenn(P)
	if Q.size()<2:return
	var S=[0.0]
	for i in range(1,Q.size()):S.append(S[-1]+Q[i].distance_to(Q[i-1]))
	if S[-1]<(16.0 if stadt else 30.0):return
	if stadt:
		var dop=0
		for i in range(0,Q.size(),3):
			if auf_fahrbahn(Q[i],-1,1.0):dop+=1
		if dop>=int(ceil(Q.size()/3.0))*0.7:return
	var w=5.0;var sw=2.5
	match typ:
		"gasse":w=3.4;sw=1.2
		"allee":w=7.0;sw=3.5
		"land":w=4.2;sw=0.0
		"autobahn":w=9.0;sw=0.0
		"rampe":w=4.6;sw=0.0
		"piste":w=3.6;sw=0.0
	var ri=ROADS.size()
	var nm={"strasse":"Straße","allee":"Allee","gasse":"Gasse","land":"Landstraße","autobahn":"Autobahn","rampe":"Auffahrt","piste":"Schotterpiste"}[typ]
	var r={"n":"%s %d"%[nm,ri],"P":Q,"w":w,"sw":sw,"typ":("strasse" if typ in ["land","rampe","piste"] else typ),"orig":typ,"S":S,"stadt":stadt}
	r["Y"]=_profil(Q,S,typ,stadt)
	ROADS.append(r)
	for i in Q.size()-1:_seg_ein(ri,i,Q[i],Q[i+1])
func _profil(Q:PackedVector2Array,S:Array,typ:String,stadt:bool)->PackedFloat32Array:
	var n=Q.size();var Y=PackedFloat32Array();Y.resize(n)
	var roh=PackedFloat32Array();roh.resize(n)
	for i in n:roh[i]=hy(Q[i])
	if stadt:return roh
	# Längsprofil: gleitender Mittelwert, dann Steigung begrenzen
	var fen={"autobahn":110.0,"rampe":40.0,"land":45.0,"piste":30.0}.get(typ,40.0)
	var a=0;var b=0;var summe=0.0
	for i in n:
		while b<n and S[b]<=S[i]+fen:summe+=roh[b];b+=1
		while S[a]<S[i]-fen:summe-=roh[a];a+=1
		Y[i]=summe/max(b-a,1)
	var gmax={"autobahn":0.07,"rampe":0.09,"land":0.12,"piste":0.15}.get(typ,0.12)
	for durch in 2:
		for i in range(1,n):Y[i]=clamp(Y[i],Y[i-1]-gmax*(S[i]-S[i-1]),Y[i-1]+gmax*(S[i]-S[i-1]))
		for i in range(n-2,-1,-1):Y[i]=clamp(Y[i],Y[i+1]-gmax*(S[i+1]-S[i]),Y[i+1]+gmax*(S[i+1]-S[i]))
	# über Wasser: mindestens 2 m über dem Meer
	for i in n:Y[i]=max(Y[i],2.0-H0)
	return Y
func y_bei(r,s:float)->float:
	var S:Array=r.S;var i=0
	while i<S.size()-2 and S[i+1]<s:i+=1
	var t=clamp((s-S[i])/max(S[i+1]-S[i],0.001),0.0,1.0)
	return lerp(r.Y[i],r.Y[i+1],t)

func zwischenstrassen():
	# nur im dichten Stadtgebiet und mit Höhe
	var alt=ROADS.size()
	var nur=[]
	for ri in ROADS.size():
		if ROADS[ri].stadt:nur.append(ri)
	var sic=ROADS
	super.zwischenstrassen()
	for ri in range(alt,ROADS.size()):
		var r=ROADS[ri];r["stadt"]=true;r["orig"]="strasse";r["Y"]=_profil(r.P,r.S,"strasse",true)

# ---------------- Stil ----------------
func stil(pl:Vector2)->String:
	var w=pl+C
	for k in ORTE:
		if w.distance_to(ORTE[k][0])<ORTE[k][1]:return k
	var i=_ix(w.x);var kk=_kz(w.y)
	if i<0 or kk<0 or i>=GNX or kk>=GNZ:return "dorf"
	if hs_welt(w.x,w.y)-H0>75.0 and STADT[kk*GNX+i]==1:return "villa"
	match KLASSE[kk*GNX+i]:
		2:return "hoch"
		3:return "ghetto"
		1:return "wohn" if w.y>-3200 else "dorf"
	return "dorf"

func _typ(st:String,ecke:bool,r)->String:
	if not r.get("stadt",true):return "nichts"
	var x=rng.randf();var haupt=r.typ=="allee" or r.S[-1]>350.0
	match st:
		"hoch":
			if ecke and x<0.5:return "laden"
			if x<0.45:return "hochhaus"
			if x<0.8:return "buero"
			if x<0.92:return "laden"
			return "platz"
		"wohn":
			if ecke and x<0.5:return "laden"
			if haupt and x<0.4:return "block"
			if x<0.45:return "reihe"
			if x<0.62:return "block"
			if x<0.8:return "holz_lang"
			if x<0.86:return "tanke" if haupt else "laden"
			return "holz_kurz"
		"villa":return "villa" if x<0.85 else "busch"
		"redneck":
			if x<0.55:return "trailer"
			if x<0.7:return "brache"
			if x<0.78:return "bar"
			if x<0.84:return "tanke"
			return "trailer"
		"farm":
			if x<0.35:return "feld"
			if x<0.55:return "scheune"
			if x<0.75:return "holz_lang"
			return "feld"
		"dorf":
			if x<0.45:return "holz_lang"
			if x<0.6:return "holz_kurz"
			if x<0.72:return "reihe"
			if x<0.8:return "laden"
			if x<0.84:return "tanke"
			return "busch"
		"knast","militaer","wflug":return "nichts"
	return super._typ(st,ecke,r)
func _kette(st:String,typ:String)->Array:
	if typ=="nichts":return []
	var rest={"hoch":["buero","laden","busch"],"wohn":["reihe","holz_kurz","laden","busch"],"villa":["busch"],"redneck":["trailer","brache","busch"],
		"farm":["holz_kurz","busch"],"dorf":["holz_kurz","busch"]}
	if not rest.has(st):return super._kette(st,typ)
	var k=[typ]
	for r in rest[st]:
		if r!=typ:k.append(r)
	return k
func _wahl(st:String,typ:String)->String:
	for key in [st+"/"+typ,"nord/"+typ,"sued/"+typ,"ghetto/"+typ]:
		if KITLISTE.has(key):var l=KITLISTE[key];return l[rng.randi()%l.size()]
	return KITLISTE["ghetto/busch"][0]

# ---------------- Aufstellen mit Höhe und Terrasse ----------------
func _setzen(kit:String,F:Vector2,t:Vector2,n:Vector2)->Transform3D:
	var k=K.KITS[kit]
	var mitte=F+n*k.d*0.5
	var h=hy(F)*0.6+hy(mitte)*0.4
	var aussen=Vector3(-n.x,0,-n.y);var rechts=Vector3.UP.cross(aussen)
	var xf=Transform3D(Basis(rechts,Vector3.UP,aussen),Vector3(F.x,h-0.14,F.y))
	PLATZ.append([kit,xf])
	for pk in k.park:PARK.append([pk[0],xf*pk[1]])
	var tt=Vector2(-n.y,n.x)
	TERR.append([[F-tt*(k.w*0.5+1),F+tt*(k.w*0.5+1),F+tt*(k.w*0.5+1)+n*(k.d+1),F-tt*(k.w*0.5+1)+n*(k.d+1)],h+H0])
	return xf

# ---------------- Bausätze ----------------
func kits_bauen():
	if not K.KITS.has("gh_holzL_0"):super.kits_bauen()
	GL.ohne_tags=true
	for i in 6:_kit("nord","hochhaus","nd_hoch_%d"%i,26.0,26.0,func():_k_hochhaus(i))
	for i in 5:_kit("nord","buero","nd_buero_%d"%i,22.0,18.0,func():_k_nbuero(i))
	for i in 3:_kit("nord","platz","nd_platz_%d"%i,24.0,24.0,func():_k_platz(i))
	for i in 5:_kit("nord","villa","nd_villa_%d"%i,30.0,32.0,func():_k_villa(i))
	for i in 6:_kit("nord","trailer","nd_trailer_%d"%i,12.0,16.0,func():_k_trailer(i))
	for i in 2:_kit("nord","bar","nd_bar_%d"%i,16.0,16.0,func():_k_bar(i))
	_kit("nord","tanke","nd_tanke",26.0,22.0,func():_k_tanke())
	for i in 2:_kit("nord","scheune","nd_scheune_%d"%i,24.0,28.0,func():_k_scheune(i))
	for i in 3:_kit("nord","feld","nd_feld_%d"%i,30.0,30.0,func():_k_feld(i))
	_kit("nord","wasserturm","nd_wasserturm",10.0,10.0,func():_k_wasserturm())
	for i in 3:_kit("nord","kaktus","nd_kaktus_%d"%i,4.0,4.0,func():_k_kaktus(i))
	for i in 3:_kit("nord","fels","nd_fels_%d"%i,6.0,6.0,func():_k_fels(i))
	_kit("nord","zellen","nd_zellen",44.0,18.0,func():_k_zellenblock())
	_kit("nord","wachturm","nd_wachturm",5.0,5.0,func():_k_wachturm())
	_kit("nord","kaserne","nd_kaserne",34.0,14.0,func():_k_kaserne())
	_kit("nord","jet","nd_jet",16.0,18.0,func():_k_jet())
	# Knast und Militär dichter: Verwaltung, Sporthof, Torhaus, Hubschrauberplatz, Tanklager, Containerreihe
	_kit("nord","knast_haupt","nd_knast_haupt",64.0,24.0,func():_k_knast_haupt())
	_kit("nord","sporthof","nd_sporthof",34.0,26.0,func():_k_sporthof())
	_kit("nord","torhaus","nd_torhaus",22.0,12.0,func():_k_torhaus())
	_kit("nord","heliplatz","nd_heliplatz",26.0,26.0,func():_k_heliplatz())
	_kit("nord","tanklager","nd_tanklager",30.0,18.0,func():_k_tanklager())
	_kit("nord","container","nd_container_reihe",40.0,8.0,func():_k_containerreihe())
	_kit("nord","panzer","nd_panzer",5.0,8.0,func():_k_panzer())
	_kit("nord","radar","nd_radar",12.0,12.0,func():_k_radar())
	_kit("nord","wrackflieger","nd_wrackflieger",30.0,32.0,func():_k_wrackflieger())
	_kit("nord","huette","nd_huette",8.0,8.0,func():GL.huette(_P(0,0,4.0),5.0,4.0,2.5,0.0,Color(0.55,0.5,0.45));K.LOD.append([Transform3D(Basis(),_P(0,1.2,4.0)),Vector3(5,2.5,4),Color(0.55,0.5,0.45),Color(0,0,0,0)]))
	# Landschaft: Bäume, Gras, Steine, Hochstand, Schrottplatz, Zeltlager, Holzstapel
	for i in 4:_kit("land","laub","ld_laub_%d"%i,5.0,5.0,func():_k_laub(i))
	for i in 3:_kit("land","nadel","ld_nadel_%d"%i,4.0,4.0,func():_k_nadel(i))
	for i in 3:_kit("land","gras","ld_gras_%d"%i,2.0,2.0,func():_k_gras(i))
	for i in 3:_kit("land","stein","ld_stein_%d"%i,3.0,3.0,func():_k_stein(i))
	_kit("land","fern","ld_fern_laub",5.0,5.0,func():_k_fernbaum(false))
	_kit("land","fern","ld_fern_nadel",4.0,4.0,func():_k_fernbaum(true))
	_kit("land","hochstand","ld_hochstand",5.0,5.0,func():_k_hochstand())
	_kit("land","schrott","ld_schrott",40.0,32.0,func():_k_schrott())
	_kit("land","camp","ld_camp",14.0,12.0,func():_k_camp())
	_kit("land","holz","ld_holz",6.0,4.0,func():_k_holzstapel())
	GL.ohne_tags=false
	print("NORD Bausätze ",K.KITS.size())

func _k_hochhaus(i:int):
	L.box(L.M.pflaster,_P(0,-0.07,13),Vector3(26,0.16,26),Basis(),0.0)
	var h=[34.0,46.0,58.0,40.0,70.0,52.0][i];var wv=[20.0,18.0,16.0,22.0,15.0,19.0][i]
	var glas=L.M.glas[i%L.M.glas.size()];var c=_P(0,0,13)
	var rahmen=T([Color(0.82,0.82,0.85),Color(0.35,0.37,0.42),Color(0.72,0.66,0.58),Color(0.9,0.9,0.92),Color(0.2,0.22,0.28),Color(0.62,0.35,0.28)][i])
	L.box(rahmen,c+Vector3(0,2.6,0),Vector3(wv+1.0,5.2,wv+1.0),Basis(),0.05)
	L.box(L.M.glas[1],c+Vector3(0,2.0,(wv+1.0)*0.5+0.02),Vector3(wv*0.7,3.4,0.05),Basis(),0.0)
	L.box(glas,c+Vector3(0,5.2+(h-5.2)*0.5,0),Vector3(wv,h-5.2,wv),Basis(),0.05)
	var y=5.2
	while y<h:
		L.box(rahmen,c+Vector3(0,y,0),Vector3(wv+0.25,0.45 if i%2==0 else 0.25,wv+0.25),Basis(),0.0);y+=3.4
	if i%2==1:
		for sx in [-1,1]:
			for k in 4:L.box(rahmen,c+Vector3(sx*wv*0.5*(1-k*0.5)*1.0+(0 if k==0 else 0),(h+5.2)*0.5,wv*0.5+0.1),Vector3(0.4,h-5.2,0.2),Basis(),0.0)
	L.box(rahmen,c+Vector3(0,h+0.8,0),Vector3(wv*0.6,1.6,wv*0.6),Basis(),0.03)
	if i==4:L.zyl(L.M.metall,c+Vector3(0,h+1.6,0),c+Vector3(0,h+12,0),0.25,1.1)
	K.haupt(c+Vector3(0,h*0.5,0),Vector3(wv,h,wv),Basis(),Color(0.4,0.55,0.7) if i%3!=2 else Color(0.72,0.66,0.58),Color(0.3,0.3,0.33))
	GL.label(["BANK","VERSICHERUNG","HOTEL","TOWER","PLAZA","OFFICES"][i],c+Vector3(0,4.4,(wv+1.0)*0.5+0.06),Basis(),0.012,Color(1,1,1),Color(0.1,0.1,0.15),wv*0.8)
func _k_nbuero(i:int):
	_boden(22,18,Color(0.5,0.5,0.48))
	L._haus(_P(0,0,1.0),21.0,14.0,AUSSEN,{"stock":[4,5,6,5,4][i],"laden":i%2==0})
	var H=3.7+([4,5,6,5,4][i]-1)*3.15
	K.haupt(_P(0,H*0.5,8.0),Vector3(21,H,14),Basis(),Color(0.8,0.72,0.62) if i%2 else Color(0.62,0.33,0.25),Color(0.33,0.33,0.33))
func _k_platz(i:int):
	L.box(L.M.pflaster,_P(0,-0.07,12),Vector3(24,0.16,24),Basis(),0.0)
	var c=_P(0,0,12)
	if i==0:
		L.zyl(L.M.stein,c,c+Vector3(0,0.6,0),4.0,1.05);L.zyl(T(Color(0.3,0.6,0.85)),c+Vector3(0,0.55,0),c+Vector3(0,0.62,0),3.6)
		L.zyl(L.M.stein,c,c+Vector3(0,2.4,0),0.5,1.1)
	for k in 4:L._baum(c+Vector3([-8,8,-8,8][k],0,[-8,-8,8,8][k]))
	L._bank(c+Vector3(-4,0,6),Vector3(0,0,-1));L._bank(c+Vector3(4,0,-6),Vector3(0,0,1))
func _k_villa(i:int):
	L.box(L.M.gras,_P(0,-0.07,16),Vector3(30,0.16,32),Basis(),0.0)
	var weiss=T([Color(0.96,0.95,0.92),Color(0.92,0.88,0.8),Color(0.85,0.85,0.88),Color(0.95,0.9,0.85),Color(0.9,0.93,0.95)][i])
	var c=_P(-2,0,18)
	L.box(weiss,c+Vector3(0,1.8,0),Vector3(16,3.6,11),Basis(),0.05)
	L.box(weiss,c+Vector3(2,5.2,-1),Vector3(12,3.2,9),Basis(),0.05)
	L.box(T(Color(0.25,0.25,0.28)),c+Vector3(2,6.9,-1),Vector3(13,0.25,10),Basis(),0.03)
	L.box(T(Color(0.25,0.25,0.28)),c+Vector3(0,3.7,0),Vector3(17,0.25,12),Basis(),0.03)
	L.box(L.M.glas[1],c+Vector3(0,1.7,5.53),Vector3(12,2.8,0.05),Basis(),0.0)
	L.box(L.M.glas[1],c+Vector3(2,5.1,3.53),Vector3(10,2.4,0.05),Basis(),0.0)
	K.haupt(c+Vector3(0,3.5,0),Vector3(16,7,11),Basis(),Color(0.95,0.94,0.9),Color(0.25,0.25,0.28))
	# Pool, Terrasse, Palmen, Mauer, Garage
	L.box(L.M.pflaster,_P(-2,0.02,8.5),Vector3(14,0.04,5),Basis(),0.0)
	L.box(T(Color(0.2,0.6,0.85)),_P(-4,0.03,8.0),Vector3(8,0.03,3.6),Basis(),0.0)
	L.box(L.M.weiss,_P(-4,0.05,8.0),Vector3(8.6,0.1,4.2),Basis(),0.0)
	palme(_P(7,0,7),8.0);palme(_P(-11,0,10),9.0)
	L.box(weiss,_P(10,1.6,22),Vector3(7,3.2,8),Basis(),0.04);L.koll_box(_P(10,1.6,22),Vector3(7,3.2,8))
	L.box(T(Color(0.4,0.4,0.42)),_P(10,1.3,17.98),Vector3(5,2.6,0.08),Basis(),0.0)
	for sx in [-1,1]:
		L.box(weiss,_P(sx*(15-0.15),1.1,16),Vector3(0.3,2.2,32),Basis(),0.02);L.koll_box(_P(sx*(15-0.15),1.1,16),Vector3(0.3,2.2,32))
	L.box(weiss,_P(-5,1.1,0.2),Vector3(20,2.2,0.3),Basis(),0.02);L.koll_box(_P(-5,1.1,0.2),Vector3(20,2.2,0.3))
	L.box(T(Color(0.15,0.15,0.17)),_P(10,1.0,0.2),Vector3(8,2.0,0.1),Basis(),0.0)
	L._park(Transform3D(Basis(Vector3.UP,PI),_P(10,0.0,12)),["c_luxus","c_sport","c_suv","c_jdm","c_luxus"][i])
func _k_trailer(i:int):
	_boden(12,16,Color(0.62,0.52,0.36))
	var c=_P(-1.0,0,8.0);var al=T([Color(0.82,0.82,0.8),Color(0.85,0.8,0.65),Color(0.7,0.78,0.8),Color(0.8,0.7,0.6),Color(0.78,0.84,0.76),Color(0.9,0.88,0.84)][i])
	var b=Basis(Vector3.UP,PI*0.5)
	L.box(al,c+Vector3(0,1.85,0),Vector3(2.6,2.3,9.5),b,0.05)
	for sz in [-1,1]:L.zyl(al,c+Vector3(sz*4.75,0.7,-1.3),c+Vector3(sz*4.75,0.7,1.3),1.15,1.03)
	L.box(T(Color(0.6,0.15,0.12) if i%2 else Color(0.2,0.35,0.6)),c+Vector3(0,1.7,1.32),Vector3(9.5,0.25,0.02),b.rotated(Vector3.UP,PI*0.5),0.0)
	for k in 3:L.box(L.M.glas[0],c+Vector3(-3+k*2.6,2.0,1.32),Vector3(1.0,0.6,0.04),Basis(),0.0)
	L.box(T(Color(0.4,0.3,0.2)),c+Vector3(2.4,1.3,1.32),Vector3(0.8,1.8,0.04),Basis(),0.0)
	for k in 4:L.box(L.M.stein_d,c+Vector3(-3.5+k*2.3,0.3,0),Vector3(0.5,0.6,0.5),Basis(),0.0)
	K.haupt(c+Vector3(0,1.85,0),Vector3(9.5,2.3,2.6),Basis(),Color(0.8,0.8,0.78),Color(0.75,0.75,0.73),0,false)
	if i%2==0:
		L.box(T(Color(0.85,0.7,0.2)),c+Vector3(0,2.6,2.6),Vector3(5,0.06,2.6),Basis(Vector3(1,0,0),0.12),0.02)
		for sx in [-2.4,2.4]:L.zyl(L.M.metall,c+Vector3(sx,0,3.8),c+Vector3(sx,2.4,3.8),0.04,1.1)
	L._sofa(_P(-3,0.55,3),0.0)
	if i%3==0:GL.auto_wrack(_P(3.5,0,4.0),rng.randf_range(0,PI))
	else:GL.reifen(_P(4,0,3),3)
	GL.muellsack(_P(-5,0,2));L._zaun(_P(-6,0,0.2),_P(2,0,0.2),1.2);L.koll_box(_P(-2,0.6,0.2),Vector3(8,1.2,0.1))
	if i==4:
		for k in 3:L.box(T(GL.SPRAY[k]),_P(-4+k*0.6,1.2,5.5),Vector3(0.5,0.4,0.04),Basis(),0.0)   # Flaggen/Wäsche
func _k_bar(i:int):
	_boden(16,16,Color(0.6,0.5,0.35))
	var c=_P(0,0,9);var holz=T(Color(0.45,0.3,0.18))
	L.box(holz,c+Vector3(0,2.2,0),Vector3(12,4.4,10),Basis(),0.05);K.haupt(c+Vector3(0,2.2,0),Vector3(12,4.4,10),Basis(),Color(0.45,0.3,0.18))
	L.box(holz,c+Vector3(0,5.5,4.95),Vector3(12,2.2,0.2),Basis(),0.03)
	L.box(T(Color(0.25,0.2,0.15)),c+Vector3(0,4.5,1),Vector3(12.4,0.3,11),Basis(),0.03)
	L.box(T(Color(0.2,0.15,0.1)),c+Vector3(0,1.2,5.03),Vector3(1.8,2.4,0.05),Basis(),0.0)
	L.box(T(Color(0.15,0.1,0.08)),c+Vector3(0,2.9,6.5),Vector3(12,0.15,3),Basis(),0.03)
	for sx in [-5.5,-2,2,5.5]:L.zyl(holz,c+Vector3(sx,0,7.8),c+Vector3(sx,2.9,7.8),0.12,1.1)
	GL.label(["SALOON","DUSTY'S BAR"][i],c+Vector3(0,5.5,5.1),Basis(),0.016,Color(1,0.3,0.25),Color(0.1,0.05,0.0),10.0)
	L._park(Transform3D(Basis(Vector3.UP,PI*0.5),_P(-5,0,2.5)),"c_suv");L._park(Transform3D(Basis(Vector3.UP,PI*0.45),_P(4,0,2.8)),"c_muscle")
func _k_tanke():
	L.box(L.M.asphalt,_P(0,-0.07,11),Vector3(26,0.16,22),Basis(),0.0)
	var c=_P(0,0,8);var rot=T(Color(0.85,0.15,0.12))
	L.box(L.M.weiss,c+Vector3(0,5.6,0),Vector3(14,0.8,9),Basis(),0.04);L.box(rot,c+Vector3(0,5.6,4.52),Vector3(14,0.5,0.05),Basis(),0.0)
	for sx in [-5,5]:
		for sz in [-3,3]:L.zyl(L.M.weiss,c+Vector3(sx,0,sz),c+Vector3(sx,5.2,sz),0.25,1.1);L.PFOSTEN.append([c+Vector3(sx,0,sz),0.25,5.2])
	for sx in [-2.5,2.5]:L.box(rot,c+Vector3(sx,0.8,0),Vector3(0.9,1.6,0.6),Basis(),0.03);L.koll_box(c+Vector3(sx,0.8,0),Vector3(0.9,1.6,0.6))
	var s=_P(0,0,18.5)
	L.box(L.M.putz[0],s+Vector3(0,2,0),Vector3(14,4,6),Basis(),0.04);K.haupt(s+Vector3(0,2,0),Vector3(14,4,6),Basis(),Color(0.9,0.88,0.8))
	L.box(L.M.glas[1],s+Vector3(0,1.6,3.02),Vector3(10,2.2,0.05),Basis(),0.0)
	L.zyl(L.M.metall,_P(-11,0,2),_P(-11,8,2),0.2,1.1);L.box(rot,_P(-11,8.5,2),Vector3(3,2,0.4),Basis(),0.03)
	GL.label("TANKE",_P(-11,8.5,2.25),Basis(),0.012,Color(1,1,1),Color(0.3,0,0),2.7);GL.label("SPRIT · SNACKS",c+Vector3(0,5.6,4.6),Basis(),0.008,Color(1,1,1),Color(0.3,0,0),9.0)
	K.LOD.append([Transform3D(Basis(),c+Vector3(0,5.6,0)),Vector3(14,0.8,9),Color(0.95,0.95,0.95),Color(0,0,0,0)])
func _k_scheune(i:int):
	_boden(24,28,Color(0.55,0.5,0.32))
	var c=_P(-2,0,15);var rot=T(Color(0.62,0.16,0.12))
	L.box(rot,c+Vector3(0,3.5,0),Vector3(12,7,18),Basis(),0.05)
	for sx in [-1,1]:L.box(T(Color(0.3,0.28,0.27)),c+Vector3(sx*3.4,8.4,0),Vector3(7.6,0.25,19),Basis(Vector3(0,0,1),-sx*0.55),0.03)
	L.box(L.M.weiss,c+Vector3(0,2.6,9.03),Vector3(5,5.2,0.05),Basis(),0.0);L.box(rot,c+Vector3(0,2.6,9.06),Vector3(4.6,4.8,0.05),Basis(),0.0)
	K.haupt(c+Vector3(0,4,0),Vector3(12,8,18),Basis(),Color(0.62,0.16,0.12),Color(0.3,0.28,0.27),1,false)
	if i==0:
		var s=_P(8,0,18);L.zyl(L.M.metall,s,s+Vector3(0,12,0),2.4,1.04);L.kugel(L.M.metall,s+Vector3(0,12,0),Vector3(2.4,1.2,2.4))
		L.PFOSTEN.append([s,2.4,12.0]);K.LOD.append([Transform3D(Basis(),s+Vector3(0,6,0)),Vector3(4.8,12,4.8),Color(0.7,0.72,0.74),Color(0,0,0,0)])
	else:
		for k in 5:L.zyl(T(Color(0.85,0.75,0.4)),_P(8,0.6,6+k*2.5),_P(8.01,0.6,6+k*2.5)+Vector3(0,0,0.01)+Vector3(1.2,0,0),0.6,1.0)
	L._zaun(_P(-12,0,0.2),_P(12,0,0.2),1.3);L.koll_box(_P(0,0.65,0.2),Vector3(24,1.3,0.1))
	L._park(Transform3D(Basis(Vector3.UP,PI*0.8),_P(6,0,5)),"c_suv")
func _k_feld(i:int):
	var farben=[[Color(0.85,0.75,0.3),Color(0.75,0.65,0.25)],[Color(0.45,0.6,0.25),Color(0.38,0.5,0.2)],[Color(0.55,0.42,0.28),Color(0.45,0.35,0.22)]][i]
	for k in 15:L.box(T(farben[k%2]),_P(0,0.0+0.15*(k%2),1+k*1.95),Vector3(29,0.3,1.0),Basis(),0.0)
	L._zaun(_P(-15,0,0.2),_P(15,0,0.2),1.2)
func _k_wasserturm():
	var c=_P(0,0,5)
	for sx in [-1.8,1.8]:
		for sz in [-1.8,1.8]:L.zyl(L.M.metall,c+Vector3(sx,0,sz),c+Vector3(sx*0.7,14,sz*0.7),0.15,1.1)
	L.zyl(T(Color(0.62,0.6,0.55)),c+Vector3(0,14,0),c+Vector3(0,19,0),3.2,1.03);L.hex(T(Color(0.5,0.48,0.45)),[c+Vector3(-3.2,19,-3.2),c+Vector3(3.2,19,-3.2),c+Vector3(3.2,19,3.2),c+Vector3(-3.2,19,3.2),c+Vector3(-0.1,21,-0.1),c+Vector3(0.1,21,-0.1),c+Vector3(0.1,21,0.1),c+Vector3(-0.1,21,0.1)],0.03)
	GL.label("STAUBWINKEL",c+Vector3(0,16.5,3.25),Basis(),0.014,Color(0.25,0.2,0.15),Color(0.8,0.75,0.6),4.6)
	L.PFOSTEN.append([c,1.6,14.0]);K.LOD.append([Transform3D(Basis(),c+Vector3(0,16.5,0)),Vector3(6.4,5,6.4),Color(0.62,0.6,0.55),Color(0,0,0,0)])
# ---------------- Landschafts-Bausätze (Mitte im Ursprung) ----------------
func _k_laub(i:int):
	var h=[4.5,6.0,7.5,5.2][i];var p=Vector3(0,KB,0)
	var laub=[T(Color(0.3,0.56,0.22)),T(Color(0.38,0.64,0.24)),T(Color(0.24,0.48,0.22)),T(Color(0.62,0.6,0.2))][i]
	var laub2=T([Color(0.36,0.62,0.26),Color(0.3,0.55,0.2),Color(0.3,0.56,0.26),Color(0.75,0.5,0.18)][i])
	L.zyl(L.M.rinde,p,p+Vector3(0.1,h*0.7,0.05),0.18+h*0.012,1.25)
	L.zyl(L.M.rinde,p+Vector3(0,h*0.45,0),p+Vector3(0.9,h*0.8,0.3),0.08,1.3)
	var c=p+Vector3(0.1,h*0.78,0.05);var r=h*0.32
	L.kugel(laub,c,Vector3(r,r*0.85,r),1.06)
	L.kugel(laub2,c+Vector3(r*0.6,r*0.25,0.2),Vector3(r*0.7,r*0.6,r*0.7),1.06)
	L.kugel(laub,c+Vector3(-r*0.55,r*0.15,-r*0.3),Vector3(r*0.65,r*0.55,r*0.65),1.06)
	L.PFOSTEN.append([p,0.3,3.0])
func _k_nadel(i:int):
	var h=[7.0,9.5,5.5][i];var p=Vector3(0,KB,0);var g=T([Color(0.16,0.38,0.22),Color(0.2,0.42,0.24),Color(0.14,0.34,0.2)][i])
	L.zyl(L.M.rinde,p,p+Vector3(0,h*0.35,0),0.16+h*0.01,1.25)
	for k in 3:
		var y=h*(0.22+k*0.24);var r=h*(0.3-k*0.07)
		var cm=CylinderMesh.new();cm.top_radius=0.02;cm.bottom_radius=r;cm.height=h*0.42;cm.radial_segments=8;cm.rings=1
		L.mesh(g,cm,Transform3D(Basis(),p+Vector3(0,y+h*0.21,0)),1.06)
	L.PFOSTEN.append([p,0.3,3.0])
func _k_gras(i:int):
	var g=T([Color(0.45,0.7,0.28),Color(0.55,0.72,0.3),Color(0.7,0.68,0.35)][i])
	for k in 9:
		var a=k*2.4;var r=0.25+k*0.07;var h=0.5+rng.randf()*0.5
		L.box(g,Vector3(cos(a)*r,KB+h*0.5-0.05,sin(a)*r),Vector3(0.06,h,0.22),Basis(Vector3.UP,a)*Basis(Vector3.RIGHT,rng.randf_range(-0.3,0.3)),0.0)
	if i==1:
		for k in 3:L.kugel(T(Color(0.95,0.85,0.2) if k%2==0 else Color(0.9,0.4,0.5)),Vector3(cos(k*2.1)*0.5,KB+0.75,sin(k*2.1)*0.5),Vector3(0.09,0.09,0.09),1.0)
func _k_stein(i:int):
	var f=T([Color(0.58,0.57,0.55),Color(0.5,0.49,0.47),Color(0.66,0.64,0.6)][i])
	var n=[1,2,3][i]
	for k in n:L.kugel(f,Vector3(k*0.8-0.6,KB+0.25,k*0.3),Vector3(0.9,0.6+k*0.15,0.75)*rng.randf_range(0.7,1.3),1.06)
	if i==2:L.koll_box(Vector3(0,KB+0.5,0),Vector3(2.2,1.0,1.6))
func _k_fernbaum(nadel:bool):
	# grobe Silhouette für die Ferne: 8-Eck-Kegel bzw. Kugel, ohne Kontur
	var g=T(Color(0.18,0.4,0.23) if nadel else Color(0.3,0.55,0.24))
	if nadel:
		var cm=CylinderMesh.new();cm.top_radius=0.0;cm.bottom_radius=2.6;cm.height=8.0;cm.radial_segments=6;cm.rings=1
		L.mesh(g,cm,Transform3D(Basis(),Vector3(0,KB+4.6,0)),1.0)
	else:
		var sm=SphereMesh.new();sm.radius=2.0;sm.height=3.6;sm.radial_segments=6;sm.rings=3
		L.mesh(g,sm,Transform3D(Basis(),Vector3(0,KB+4.4,0)),1.0)
		L.box(L.M.rinde,Vector3(0,KB+1.4,0),Vector3(0.4,2.8,0.4),Basis(),0.0)
func _k_hochstand():
	var holz=T(Color(0.45,0.32,0.2));var dunkel=T(Color(0.3,0.21,0.13));var p=Vector3(0,KB,0)
	for sx in [-1,1]:
		for sz in [-1,1]:L.zyl(holz,p+Vector3(sx*1.1,0,sz*1.1),p+Vector3(sx*0.75,4.0,sz*0.75),0.1,1.2)
	L.box(holz,p+Vector3(0,4.05,0),Vector3(1.9,0.15,1.9),Basis(),0.04)
	L.box(holz,p+Vector3(0,4.6,0.8),Vector3(1.9,1.0,0.08),Basis(),0.03)
	L.box(holz,p+Vector3(0.9,4.6,0),Vector3(0.08,1.0,1.9),Basis(),0.03);L.box(holz,p+Vector3(-0.9,4.6,0),Vector3(0.08,1.0,1.9),Basis(),0.03)
	L.box(holz,p+Vector3(0,4.4,-0.9),Vector3(1.9,0.6,0.08),Basis(),0.03)
	for sx in [-1,1]:L.box(holz,p+Vector3(sx*0.9,5.6,0),Vector3(0.1,1.2,0.1),Basis(),0.0)
	L.box(dunkel,p+Vector3(0,6.25,0),Vector3(2.3,0.12,2.3),Basis(Vector3.RIGHT,0.15),0.04)
	# Leiter
	for sx in [-1,1]:L.zyl(holz,p+Vector3(sx*0.3,0,-2.4),p+Vector3(sx*0.3,4.0,-0.95),0.05,1.2)
	for k in 9:
		var t=(k+0.5)/9.0;L.box(holz,p+Vector3(0,4.0*t,-2.4+1.45*t),Vector3(0.6,0.06,0.08),Basis(),0.0)
	L.PFOSTEN.append([p,0.9,4.0])
	K.LOD.append([Transform3D(Basis(),p+Vector3(0,4.6,0)),Vector3(1.9,1.2,1.9),Color(0.45,0.32,0.2),Color(0.3,0.21,0.13)])
func _k_schrott():
	var p=Vector3(0,KB,0);var w=38.0;var d=30.0
	L.box(T(Color(0.45,0.4,0.33)),p+Vector3(0,-0.05,0),Vector3(w,0.14,d),Basis(),0.0)
	# Wellblechzaun mit Tor
	var blech=[T(Color(0.55,0.5,0.42)),T(Color(0.5,0.38,0.3)),T(Color(0.42,0.45,0.43))]
	var x=-w*0.5
	while x<w*0.5:
		var b=blech[int(abs(x))%3]
		L.box(b,p+Vector3(x+1.0,1.25,-d*0.5),Vector3(2.0,2.5,0.08),Basis(),0.03)
		if abs(x+1.0)>4.0:L.box(b,p+Vector3(x+1.0,1.25,d*0.5),Vector3(2.0,2.5,0.08),Basis(),0.03)
		x+=2.0
	var z=-d*0.5
	while z<d*0.5:
		for sx in [-1,1]:L.box(blech[int(abs(z))%3],p+Vector3(sx*w*0.5,1.25,z+1.0),Vector3(0.08,2.5,2.0),Basis(),0.03)
		z+=2.0
	L.koll_box(p+Vector3(0,1.25,-d*0.5),Vector3(w,2.5,0.3))
	for sx in [-1,1]:L.koll_box(p+Vector3(sx*w*0.5,1.25,0),Vector3(0.3,2.5,d));L.koll_box(p+Vector3(sx*(w*0.25+2.0),1.25,d*0.5),Vector3(w*0.5-4.0,2.5,0.3))
	# Wrackstapel (gepresste Autos)
	var farben=[Color(0.6,0.2,0.15),Color(0.25,0.35,0.5),Color(0.75,0.7,0.6),Color(0.3,0.45,0.3),Color(0.55,0.45,0.25),Color(0.35,0.32,0.3)]
	for st in 7:
		var sx=-w*0.5+5.0+(st%4)*7.5;var sz=-d*0.5+4.0+(st/4)*9.0
		var n=rng.randi_range(2,5)
		for k in n:
			var c=farben[rng.randi()%farben.size()]*rng.randf_range(0.7,1.0);c.a=1.0
			L.box(T(c),p+Vector3(sx+rng.randf_range(-0.3,0.3),0.35+k*0.72,sz),Vector3(4.0,0.7,1.9),Basis(Vector3.UP,rng.randf_range(-0.15,0.15)),0.03)
		L.koll_box(p+Vector3(sx,n*0.36,sz),Vector3(4.2,n*0.72,2.0))
	# Reifenberg, Autowracks mit Rädern, Kran, Hütte
	for k in 14:L.zyl(T(Color(0.08,0.08,0.08)),p+Vector3(10.0+rng.randf_range(-2,2),0.15+k*0.12,8.0+rng.randf_range(-2,2)),p+Vector3(10.0+rng.randf_range(-2,2),0.4+k*0.12,8.0+rng.randf_range(-2,2)),0.4,1.1)
	for k in 3:
		var wx=-6.0+k*6.0;var c2=T(farben[k+2])
		L.box(c2,p+Vector3(wx,0.75,9.0),Vector3(1.8,0.8,4.2),Basis(Vector3.UP,0.3*k),0.04)
		L.box(c2,p+Vector3(wx,1.35,9.2),Vector3(1.6,0.6,2.2),Basis(Vector3.UP,0.3*k),0.04)
		L.koll_box(p+Vector3(wx,0.8,9.0),Vector3(1.9,1.6,4.3),Basis(Vector3.UP,0.3*k))
	var gelb=T(Color(0.9,0.7,0.12))
	L.box(gelb,p+Vector3(14,0.8,-8),Vector3(3.0,1.6,4.5),Basis(),0.04);L.box(gelb,p+Vector3(14,2.2,-7),Vector3(2.0,1.4,2.0),Basis(),0.04)
	L.zyl(gelb,p+Vector3(14,2.8,-8),p+Vector3(9,9,-8),0.25,1.2);L.zyl(gelb,p+Vector3(9,9,-8),p+Vector3(6,5,-8),0.18,1.2)
	L.koll_box(p+Vector3(14,1.2,-8),Vector3(3,2.4,4.5))
	GL.huette(p+Vector3(-14,0,-9),6.0,4.5,2.8,0.0,Color(0.52,0.45,0.38))
	var schild=Label3D.new();schild.text="SCHROTT\nANKAUF";schild.font_size=96;schild.pixel_size=0.012;schild.modulate=Color(1,0.85,0.2);schild.outline_size=18
	L.welt.add_child(schild);schild.position=p+Vector3(4.5,2.0,d*0.5+0.1)
	K.LOD.append([Transform3D(Basis(),p+Vector3(0,1.25,0)),Vector3(w,2.5,d),Color(0.55,0.5,0.42),Color(0.45,0.4,0.33)])
func _k_camp():
	var p=Vector3(0,KB,0)
	var farben=[Color(0.85,0.45,0.15),Color(0.25,0.45,0.7),Color(0.4,0.55,0.25)]
	for k in 3:
		var c=p+Vector3(-4.0+k*4.0,0,-2.5+(k%2)*1.5);var m=T(farben[k])
		var cm=CylinderMesh.new();cm.top_radius=0.0;cm.bottom_radius=1.4;cm.height=1.8;cm.radial_segments=4;cm.rings=1
		L.mesh(m,cm,Transform3D(Basis(Vector3.UP,PI*0.25+k*0.3).scaled(Vector3(1,1,1.6)),c+Vector3(0,0.9,0)),1.05)
	# Feuerstelle mit Steinring, Baumstämme zum Sitzen
	for k in 10:var a=TAU*k/10.0;L.kugel(T(Color(0.5,0.5,0.48)),p+Vector3(cos(a)*0.8,0.1,2.5+sin(a)*0.8),Vector3(0.22,0.15,0.2),1.0)
	L.kugel(T(Color(1.0,0.55,0.1)),p+Vector3(0,0.3,2.5),Vector3(0.35,0.4,0.35),1.0)
	for sx in [-1,1]:L.zyl(L.M.rinde,p+Vector3(sx*2.2,0.25,1.4),p+Vector3(sx*2.2,0.25,3.6),0.25,1.15)
	L.box(T(Color(0.3,0.3,0.32)),p+Vector3(4.5,0.35,3.0),Vector3(1.0,0.7,0.6),Basis(),0.03)
func _k_holzstapel():
	var p=Vector3(0,KB,0)
	for r in 4:
		for k in 6-r:L.zyl(L.M.rinde,p+Vector3(-2.4,0.3+r*0.5,-1.25+k*0.5+r*0.25),p+Vector3(2.4,0.3+r*0.5,-1.25+k*0.5+r*0.25),0.25,1.12)
	L.koll_box(p+Vector3(0,1.0,0),Vector3(4.8,2.0,3.0))

func _k_kaktus(i:int):
	var g=T(Color(0.25,0.5,0.25));var p=_P(0,0,2)
	var h=[3.5,5.0,2.5][i]
	L.zyl(g,p,p+Vector3(0,h,0),0.32,1.12);L.kugel(g,p+Vector3(0,h,0),Vector3(0.32,0.3,0.32))
	if i!=2:
		for sx in [-1,1]:
			var a=p+Vector3(sx*0.3,h*0.45,0);L.zyl(g,a,a+Vector3(sx*0.8,0,0),0.2,1.1);L.zyl(g,a+Vector3(sx*0.8,0,0),a+Vector3(sx*0.8,1.3,0),0.2,1.1)
	L.PFOSTEN.append([p,0.35,h])
func _k_fels(i:int):
	var f=T([Color(0.7,0.5,0.35),Color(0.6,0.45,0.35),Color(0.75,0.6,0.45)][i]);var p=_P(0,0,3)
	for k in 3:L.kugel(f,p+Vector3(rng.randf_range(-1.2,1.2),0.4,rng.randf_range(-1,1)),Vector3(1.6,1.0+k*0.4,1.4)*rng.randf_range(0.7,1.3))
	L.koll_box(p+Vector3(0,0.8,0),Vector3(3,1.6,2.6))
func _k_zellenblock():
	var c=_P(0,0,9);var grau=T(Color(0.68,0.68,0.66))
	L.box(grau,c+Vector3(0,5.5,0),Vector3(40,11,14),Basis(),0.05);K.haupt(c+Vector3(0,5.5,0),Vector3(40,11,14),Basis(),Color(0.68,0.68,0.66),Color(0.4,0.4,0.42),0,false)
	L.box(T(Color(0.4,0.4,0.42)),c+Vector3(0,11.2,0),Vector3(40.6,0.4,14.6),Basis(),0.03)
	for e in 3:
		for k in 14:
			var x=-18.5+k*2.85
			L.box(T(Color(0.15,0.15,0.18)),c+Vector3(x,2.2+e*3.4,7.03),Vector3(0.9,1.2,0.05),Basis(),0.0)
			for st in 3:L.box(L.M.metall,c+Vector3(x-0.3+st*0.3,2.2+e*3.4,7.07),Vector3(0.05,1.2,0.05),Basis(),0.0)
	GL.label("JVA RADEBERG – BLOCK %s"%["A","B","C"][rng.randi()%3],c+Vector3(0,9.6,7.1),Basis(),0.012,Color(0.15,0.15,0.18),Color(0.85,0.85,0.85),36.0)
func _k_knast_haupt():
	var c=_P(0,0,12);var beton=T(Color(0.74,0.72,0.68));var dunkel=T(Color(0.38,0.38,0.4))
	L.box(beton,c+Vector3(0,7,0),Vector3(60,14,20),Basis(),0.05);K.haupt(c+Vector3(0,7,0),Vector3(60,14,20),Basis(),Color(0.74,0.72,0.68),Color(0.38,0.38,0.4),0,false)
	L.box(beton,c+Vector3(0,10,0),Vector3(16,20,22),Basis(),0.05);K.haupt(c+Vector3(0,10,0),Vector3(16,20,22),Basis(),Color(0.74,0.72,0.68),Color(0.38,0.38,0.4),0,false)
	L.box(dunkel,c+Vector3(0,14.2,0),Vector3(60.6,0.4,20.6),Basis(),0.03);L.box(dunkel,c+Vector3(0,20.2,0),Vector3(16.6,0.4,22.6),Basis(),0.03)
	for e in 3:
		for k in 16:
			var x=-28.0+k*3.7
			if abs(x)<8.5:continue
			L.box(T(Color(0.15,0.16,0.2)),c+Vector3(x,2.5+e*4.0,10.03),Vector3(1.0,1.5,0.05),Basis(),0.0)
			for st in 3:L.box(L.M.metall,c+Vector3(x-0.32+st*0.32,2.5+e*4.0,10.07),Vector3(0.05,1.5,0.05),Basis(),0.0)
	for e in 4:L.box(L.M.glas[1],c+Vector3(0,3.0+e*4.2,11.03),Vector3(10,2.2,0.05),Basis(),0.0)
	L.box(T(Color(0.3,0.32,0.36)),c+Vector3(0,1.6,11.05),Vector3(4,3.2,0.08),Basis(),0.0)
	GL.label("JUSTIZVOLLZUGSANSTALT RADEBERG",c+Vector3(0,17.5,11.1),Basis(),0.016,Color(0.15,0.15,0.18),Color(0.9,0.9,0.88),15.5)
	L.zyl(L.M.metall,c+Vector3(-10,0,14),c+Vector3(-10,12,14),0.08,1.1);L.box(T(Color(0.1,0.1,0.1)),c+Vector3(-9.3,11.4,14),Vector3(1.4,0.5,0.03),Basis(),0.0)
	L.box(T(Color(0.8,0.1,0.1)),c+Vector3(-9.3,10.9,14),Vector3(1.4,0.5,0.03),Basis(),0.0);L.box(T(Color(0.95,0.8,0.1)),c+Vector3(-9.3,10.4,14),Vector3(1.4,0.5,0.03),Basis(),0.0)
	L.koll_box(c+Vector3(0,7,0),Vector3(60,14,20));L.koll_box(c+Vector3(0,10,0),Vector3(16,20,22))
func _k_sporthof():
	var c=_P(0,0,13);var boden=T(Color(0.55,0.32,0.25));var weiss=T(Color(0.95,0.95,0.95));var zaun=L.M.metall
	L.box(boden,c+Vector3(0,0.02,0),Vector3(30,0.06,20),Basis(),0.0)
	for z in [-9.5,9.5]:L.box(weiss,c+Vector3(0,0.06,z),Vector3(28,0.02,0.12),Basis(),0.0)
	for x in [-14.0,14.0,0.0]:L.box(weiss,c+Vector3(x,0.06,0),Vector3(0.12,0.02,19),Basis(),0.0)
	for sx in [-1,1]:
		L.zyl(zaun,c+Vector3(sx*12.5,0,0),c+Vector3(sx*12.5,3.6,0),0.08,1.1)
		L.box(weiss,c+Vector3(sx*12.2,3.4,0),Vector3(0.08,1.0,1.6),Basis(),0.02);L.zyl(T(Color(0.95,0.45,0.1)),c+Vector3(sx*11.8,3.05,-0.25),c+Vector3(sx*11.8,3.05,0.25),0.23,1.0)
	# Zaun rundum
	for k in 16:
		var a=TAU*k/16.0;var q=c+Vector3(cos(a)*16.5,0,sin(a)*12.0)
		L.zyl(zaun,q,q+Vector3(0,4,0),0.06,1.1)
	for sx in [-1,1]:L.box(T(Color(0.4,0.42,0.44,1)),c+Vector3(sx*16.0,2,0),Vector3(0.05,4,22),Basis(),0.0)
	# Hantelbank und Bänke
	for k in 3:L.box(T(Color(0.3,0.3,0.32)),c+Vector3(-8+k*8,0.45,11.5),Vector3(3,0.12,0.6),Basis(),0.02)
	L.zyl(L.M.metall,c+Vector3(10,0.9,-11),c+Vector3(12,0.9,-11),0.03,1.0)
	for sx in [10.0,12.0]:L.zyl(T(Color(0.1,0.1,0.1)),c+Vector3(sx,0.9,-11.2),c+Vector3(sx,0.9,-10.8),0.25,1.0)
func _k_torhaus():
	var c=_P(0,0,6);var beton=T(Color(0.7,0.7,0.68))
	L.box(beton,c+Vector3(-7,2.5,0),Vector3(6,5,8),Basis(),0.05);K.haupt(c+Vector3(-7,2.5,0),Vector3(6,5,8),Basis(),Color(0.7,0.7,0.68),Color(0.35,0.35,0.37),0,true)
	L.box(L.M.glas[0],c+Vector3(-7,3,4.03),Vector3(4,1.5,0.05),Basis(),0.0)
	L.box(T(Color(0.35,0.35,0.37)),c+Vector3(0,5.6,0),Vector3(20,0.5,9),Basis(),0.04)
	for sx in [-9.5,9.5,-4.0]:L.zyl(L.M.metall,c+Vector3(sx,0,-4),c+Vector3(sx,5.4,-4),0.15,1.1)
	# Schranke rot-weiß
	L.box(T(Color(0.2,0.2,0.2)),c+Vector3(-3.5,0.5,4),Vector3(0.5,1.0,0.5),Basis(),0.02)
	for k in 6:L.box(T(Color(0.9,0.1,0.1) if k%2==0 else Color(0.95,0.95,0.95)),c+Vector3(-2.6+k*1.0,1.0,4),Vector3(1.0,0.12,0.12),Basis(),0.0)
	GL.label("JVA – PFORTE",c+Vector3(-7,4.6,4.1),Basis(),0.01,Color(1,1,1),Color(0.1,0.15,0.3),5.5)
	L.koll_box(c+Vector3(-7,2.5,0),Vector3(6,5,8))
func _k_heliplatz():
	var c=_P(0,0,13);var beton=T(Color(0.5,0.5,0.48));var gelb=T(Color(0.95,0.8,0.15));var oliv=T(Color(0.32,0.35,0.21))
	L.zyl(beton,c,c+Vector3(0,0.08,0),11.0,1.0)
	L.zyl(gelb,c+Vector3(0,0.09,0),c+Vector3(0,0.1,0),9.5,1.0);L.zyl(beton,c+Vector3(0,0.1,0),c+Vector3(0,0.11,0),9.0,1.0)
	for x in [-2.0,2.0]:L.box(T(Color(1,1,1)),c+Vector3(x,0.12,0),Vector3(0.8,0.02,6),Basis(),0.0)
	L.box(T(Color(1,1,1)),c+Vector3(0,0.12,0),Vector3(4,0.02,0.8),Basis(),0.0)
	# abgestellter Transporthubschrauber
	var h=c+Vector3(0,0,0)
	L.box(oliv,h+Vector3(0,1.6,0),Vector3(2.4,2.2,6.5),Basis(),0.05);L.box(oliv,h+Vector3(0,1.9,6.0),Vector3(0.7,0.7,6.0),Basis(),0.04)
	L.box(oliv,h+Vector3(0,3.0,8.8),Vector3(0.2,2.0,1.2),Basis(),0.03);L.box(L.M.glas[0],h+Vector3(0,2.0,-3.3),Vector3(2.2,1.1,0.3),Basis(),0.0)
	for a in 2:L.box(T(Color(0.1,0.1,0.1)),h+Vector3(0,3.0,0),Vector3(0.4,0.06,14),Basis(Vector3.UP,PI*0.25+a*PI*0.5),0.0)
	for sx in [-1,1]:L.box(T(Color(0.1,0.1,0.1)),h+Vector3(sx*1.3,0.3,0),Vector3(0.12,0.12,5),Basis(),0.0)
	L.koll_box(h+Vector3(0,1.6,1),Vector3(2.5,2.4,8))
func _k_tanklager():
	var c=_P(0,0,9);var weiss=T(Color(0.9,0.9,0.88));var oliv=T(Color(0.35,0.38,0.24))
	for k in 3:
		var q=c+Vector3(-10+k*10,0,0)
		L.zyl(weiss,q,q+Vector3(0,7,0),4.0,1.05);L.zyl(T(Color(0.6,0.6,0.6)),q+Vector3(0,7,0),q+Vector3(0,7.6,0),4.1,1.03)
		L.box(T(Color(0.85,0.15,0.1)),q+Vector3(0,4,4.02),Vector3(2.2,0.6,0.05),Basis(),0.0)
		L.koll_box(q+Vector3(0,3.5,0),Vector3(7.5,7,7.5))
	L.zyl(L.M.metall,c+Vector3(-14,1,5),c+Vector3(14,1,5),0.25,1.05)
	L.box(oliv,c+Vector3(13,1.4,-6),Vector3(2.5,2.6,7),Basis(),0.04)
func _k_containerreihe():
	var c=_P(0,0,4);var farben=[Color(0.35,0.38,0.24),Color(0.3,0.33,0.22),Color(0.42,0.4,0.3)]
	for k in 6:
		for e in (2 if k%2==0 else 1):
			var q=c+Vector3(-16+k*6.4,1.3+e*2.6,0);L.box(T(farben[(k+e)%3]),q,Vector3(6,2.6,2.5),Basis(),0.04)
		L.koll_box(c+Vector3(-16+k*6.4,1.3*(2 if k%2==0 else 1),0),Vector3(6,2.6*(2 if k%2==0 else 1),2.5))

func _k_wachturm():
	var p=_P(0,0,2.5);var grau=T(Color(0.6,0.6,0.58))
	for sx in [-1.2,1.2]:
		for sz in [-1.2,1.2]:L.zyl(grau,p+Vector3(sx,0,sz),p+Vector3(sx,9,sz),0.2,1.1)
	L.box(grau,p+Vector3(0,10.2,0),Vector3(3.6,2.4,3.6),Basis(),0.04);L.box(L.M.glas[0],p+Vector3(0,10.4,1.82),Vector3(3.0,1.0,0.05),Basis(),0.0)
	L.box(T(Color(0.3,0.3,0.32)),p+Vector3(0,11.6,0),Vector3(4.2,0.3,4.2),Basis(),0.03)
	L.PFOSTEN.append([p,1.6,9.0]);K.LOD.append([Transform3D(Basis(),p+Vector3(0,10.2,0)),Vector3(3.6,2.4,3.6),Color(0.6,0.6,0.58),Color(0,0,0,0)])
func _k_kaserne():
	var c=_P(0,0,7);var oliv=T(Color(0.45,0.48,0.35))
	L.box(oliv,c+Vector3(0,2,0),Vector3(32,4,11),Basis(),0.05);K.haupt(c+Vector3(0,2,0),Vector3(32,4,11),Basis(),Color(0.45,0.48,0.35),Color(0.3,0.32,0.28),1,false)
	for sz in [-1,1]:L.box(T(Color(0.3,0.32,0.28)),c+Vector3(0,4.8,sz*2.9),Vector3(32.6,0.25,6.2),Basis(Vector3(1,0,0),sz*0.3),0.03)
	for k in 8:L.box(L.M.glas[0],c+Vector3(-14+k*4,2.2,5.53),Vector3(1.6,1.2,0.05),Basis(),0.0)
	L.box(T(Color(0.25,0.22,0.18)),c+Vector3(0,1.2,5.53),Vector3(1.6,2.4,0.05),Basis(),0.0)
	L.zyl(L.M.metall,_P(-14,0,1),_P(-14,9,1),0.08,1.1)
	L.box(T(Color(0.1,0.3,0.15)),_P(-13.2,8.4,1),Vector3(1.6,1.0,0.04),Basis(),0.0)
func _k_jet():
	var p=_P(0,0,9);var m=T(Color(0.45,0.48,0.5))
	L.kapsel(m,p+Vector3(0,1.6,-7),p+Vector3(0,1.6,7),0.9)
	L.hex(m,[p+Vector3(-0.8,1.4,-1),p+Vector3(0.8,1.4,-1),p+Vector3(7,1.4,-5),p+Vector3(-7,1.4,-5),p+Vector3(-0.8,1.6,-1),p+Vector3(0.8,1.6,-1),p+Vector3(7,1.5,-5),p+Vector3(-7,1.5,-5)],0.03)
	for sx in [-1,1]:L.box(m,p+Vector3(sx*1.0,3.0,-6),Vector3(0.15,2.4,2.4),Basis(Vector3(0,0,1),sx*0.3),0.03)
	L.box(L.M.glas[0],p+Vector3(0,2.3,4),Vector3(0.9,0.6,2.4),Basis(),0.0)
	for z in [-2.0,4.0]:L.zyl(L.M.dunkel,p+Vector3(0,0,z),p+Vector3(0,1.0,z),0.15,1.1)
	L.koll_box(p+Vector3(0,1.6,0),Vector3(2,2,14));K.LOD.append([Transform3D(Basis(),p+Vector3(0,1.6,0)),Vector3(2,2,14),Color(0.45,0.48,0.5),Color(0,0,0,0)])
func _k_panzer():
	var p=_P(0,0,4);var o=T(Color(0.4,0.42,0.3))
	L.box(o,p+Vector3(0,1.0,0),Vector3(3.4,1.2,7),Basis(),0.05);L.box(L.M.dunkel,p+Vector3(0,0.5,0),Vector3(3.6,0.9,6.4),Basis(),0.04)
	L.box(o,p+Vector3(0,2.0,-0.5),Vector3(2.2,0.9,3),Basis(),0.05);L.zyl(o,p+Vector3(0,2.0,1),p+Vector3(0,2.1,5.5),0.12,1.1)
	L.koll_box(p+Vector3(0,1.2,0),Vector3(3.6,2.4,7));K.LOD.append([Transform3D(Basis(),p+Vector3(0,1.2,0)),Vector3(3.4,2.2,7),Color(0.4,0.42,0.3),Color(0,0,0,0)])
func _k_radar():
	var p=_P(0,0,6);L.box(T(Color(0.5,0.52,0.45)),p+Vector3(0,1.5,0),Vector3(5,3,5),Basis(),0.04)
	L.zyl(L.M.metall,p+Vector3(0,3,0),p+Vector3(0,7,0),0.3,1.1)
	L.kugel(L.M.weiss,p+Vector3(0,9,0),Vector3(3,3,3));L.koll_box(p+Vector3(0,1.5,0),Vector3(5,3,5))
	K.LOD.append([Transform3D(Basis(),p+Vector3(0,9,0)),Vector3(5,5,5),Color(0.95,0.95,0.95),Color(0,0,0,0)])
func _k_wrackflieger():
	var p=_P(0,0,16);var m=T(Color(0.75,0.72,0.65));var r=T(Color(0.55,0.35,0.25))
	L.kapsel(m,p+Vector3(0,2.0,-12),p+Vector3(0,2.6,10),1.8)
	L.box(m,p+Vector3(-6,1.6,1),Vector3(11,0.35,4),Basis(Vector3(0,0,1),0.12),0.03)
	L.box(r,p+Vector3(5,0.6,1),Vector3(10,0.35,4),Basis(Vector3(0,0,1),-0.35),0.03)
	L.box(m,p+Vector3(0,5.5,-11),Vector3(0.35,5,3),Basis(Vector3(1,0,0),-0.3),0.03)
	L.koll_box(p+Vector3(0,2,0),Vector3(3.6,3.6,22));K.LOD.append([Transform3D(Basis(),p+Vector3(0,2,0)),Vector3(3.6,3.6,22),Color(0.75,0.72,0.65),Color(0,0,0,0)])

func fuellen():
	var n0=PLATZ.size()
	for j in range(0,GNX*GNZ):
		if MASKE[j]!=1 or rng.randf()>0.05:continue
		var w=Vector2(GX0+(j%GNX)*MST,GZ0+(j/GNX)*MST)+Vector2(rng.randf_range(-4,4),rng.randf_range(-4,4))
		var p=w-C
		if _belegt(p) or frei(p)<1.0 or frei(p)>45.0:continue
		var st=stil(p);var kit=_wahl(st,"busch");var k=K.KITS[kit]
		var ns=naechst(p);var tt:Vector2=ns[1] if ns[2]>=0 else Vector2(1,0);var nv=Vector2(-tt.y,tt.x)
		if ns[2]>=0 and (p-ns[0]).dot(nv)<0:nv=-nv;tt=-tt
		if _rechteck_ok(p,tt,nv,k.w,k.d):_belegen(p,tt,nv,k.w,k.d);_setzen(kit,p,tt,nv)
	print("NORD Füllstücke ",PLATZ.size()-n0)

# ---------------- Sonderorte ----------------
var KNAST_WAND:=[]   # für Geometrie
func _platz_bei(kit:String,welt:Vector2,yaw:float,flach:=-1.0):
	var k=K.KITS[kit];var aussen=Vector2(sin(yaw),cos(yaw));var n=-aussen;var t=Vector2(-n.y,n.x)
	var F=welt-C-n*k.d*0.5
	if _belegt(F+n*k.d*0.5):return
	_belegen(F,t,n,k.w,k.d)
	var xf=_setzen(kit,F,t,n)
	if flach>-1000.0:
		xf.origin.y=flach-H0-0.14;PLATZ[PLATZ.size()-1][1]=xf;TERR[TERR.size()-1][1]=flach
func _plateau(mitte:Vector2,rx:float,rz:float,h:float):
	for k in range(_kz(mitte.y-rz-60),_kz(mitte.y+rz+60)+1):
		for i in range(_ix(mitte.x-rx-60),_ix(mitte.x+rx+60)+1):
			if i<0 or k<0 or i>=GNX or k>=GNZ:continue
			var w=Vector2(GX0+i*MST,GZ0+k*MST);var e=Vector2((w.x-mitte.x)/rx,(w.y-mitte.y)/rz).length()
			var j=k*GNX+i
			if WASSER[j]==1:continue
			var t=clamp((e-1.0)*max(rx,rz)/60.0,0.0,1.0)
			var ziel=lerp(h,NAT[j],smoothstep(0.0,1.0,t))
			TH[j]=ziel;HS[j]=ziel
func plateaus():
	var kn=ORTE.knast[0];_plateau(kn,300,260,hs_welt(kn.x,kn.y))
	var mi=ORTE.militaer[0];_plateau(mi+Vector2(0,30),760,220,hs_welt(mi.x,mi.y-20))
	var wf=ORTE.wflug[0];_plateau(wf,520,90,hs_welt(wf.x,wf.y))
func sonderorte():
	var n0=PLATZ.size()
	# Gefängnis: kommt jetzt komplett aus knast_lib (Bake setzt es); hier nur die Fläche freihalten
	var kn=ORTE.knast[0]
	# Militärflugplatz: Kasernen, Hangars, Jets, Panzer, Radar, Tower
	var mi=ORTE.militaer[0];var hm=hs_welt(mi.x,mi.y-20)
	for k in 4:_platz_bei("fl_hangar",mi+Vector2(-500+k*90,-80),0.0,hm)
	for k in 3:_platz_bei("nd_kaserne",mi+Vector2(200+k*60,-120),0.0,hm)
	for k in 6:_platz_bei("nd_jet",mi+Vector2(-480+k*45,-20),0.0,hm)
	for k in 5:_platz_bei("nd_panzer",mi+Vector2(220+k*14,-40),0.0,hm)
	_platz_bei("nd_radar",mi+Vector2(450,-110),0.0,hm);_platz_bei("fl_tower",mi+Vector2(-100,-110),0.0,hm)
	for k in 3:_platz_bei("nd_heliplatz",mi+Vector2(-40+k*45,40),0.0,hm)
	_platz_bei("nd_tanklager",mi+Vector2(380,40),0.0,hm)
	for k in 3:_platz_bei("nd_container_reihe",mi+Vector2(150+k*0,60+k*14),0.0,hm)
	for k in 3:_platz_bei("nd_kaserne",mi+Vector2(200+k*60,-180),0.0,hm)
	for k in 4:_platz_bei("nd_panzer",mi+Vector2(220+k*14,-10),0.0,hm)
	# Wüstenflugplatz: Hangar, Wracks, Wellblechhütten
	var wf=ORTE.wflug[0];var hw=hs_welt(wf.x,wf.y)
	_platz_bei("fl_hangar",wf+Vector2(-150,-60),0.0,hw);_platz_bei("nd_huette",wf+Vector2(-90,-50),0.0,hw);_platz_bei("nd_huette",wf+Vector2(-70,-52),0.3,hw)
	_platz_bei("nd_wrackflieger",wf+Vector2(80,-70),0.4,hw);_platz_bei("nd_wrackflieger",wf+Vector2(200,-65),-0.5,hw)
	_platz_bei("fl_tower",wf+Vector2(-220,-50),0.0,hw)
	# Staubwinkel: Wasserturm
	var rd=ORTE.redneck[0];_platz_bei("nd_wasserturm",rd+Vector2(30,40),0.0)
	# Wüste: Kakteen und Felsen auf Sandflächen (nicht an Straßen, nicht in Orten)
	var nd=0
	for versuch in 9000:
		var w=Vector2(rng.randf_range(-3800,4200),rng.randf_range(-10600,-3200))
		var i=_ix(w.x);var k=_kz(w.y)
		if i<1 or k<1 or i>=GNX-1 or k>=GNZ-1:continue
		var j=(k*GNX+i)*4
		var sand=G0._bo[j+2];var trocken=G0._bo[j+3] if false else 0
		if sand<120 or NAT[k*GNX+i]<2.0:continue
		if frei(w-C)<12.0 or _belegt(w-C) or STADT[k*GNX+i]==1:continue
		var kit=("nd_kaktus_%d" if rng.randf()<0.6 else "nd_fels_%d")%rng.randi_range(0,2)
		var kk=K.KITS[kit];var aussen=Vector2(sin(rng.randf()*TAU),cos(rng.randf()*TAU))
		var F=w-C;var n=-aussen;var xf=Transform3D(Basis(Vector3.UP.cross(Vector3(aussen.x,0,aussen.y)),Vector3.UP,Vector3(aussen.x,0,aussen.y)),Vector3(F.x,ny(F)-0.2,F.y))
		PLATZ.append([kit,xf]);_occ(F);nd+=1
	print("NORD Sonderorte ",PLATZ.size()-n0," davon Wüste ",nd)

# ---------------- Landschaft zwischen den Orten ----------------
func h_end(w:Vector2)->float:   # endgültige Geländehöhe (Welt) nach gelaende_ziel
	var fx=(w.x-GX0)/MST;var fz=(w.y-GZ0)/MST;var i=clamp(int(floor(fx)),0,GNX-2);var k=clamp(int(floor(fz)),0,GNZ-2)
	var tx=clamp(fx-i,0.0,1.0);var tz=clamp(fz-k,0.0,1.0)
	var v=[]
	for jj in [k*GNX+i,k*GNX+i+1,(k+1)*GNX+i,(k+1)*GNX+i+1]:v.append(TH[jj] if not is_nan(TH[jj]) else NAT[jj])
	return lerp(lerp(v[0],v[1],tx),lerp(v[2],v[3],tx),tz)
func _land_ok(w:Vector2,rand:float)->int:   # 0 = nein, 1 = freie Landschaft, 2 = Ortsrand/Stadtgrün
	var i=_ix(w.x);var k=_kz(w.y)
	if i<1 or k<1 or i>=GNX-1 or k>=GNZ-1:return 0
	var j=k*GNX+i
	if WASSER[j]==1 or NAT[j]<2.5 or NAT[j]>600.0:return 0
	if AUSW_W.size.x>0 and AUSW_W.grow(260.0).has_point(w):return 0
	for o in ORTE:
		if o!="farm" and o!="redneck" and w.distance_to(ORTE[o][0])<ORTE[o][1]+40.0:return 0
	var F=w-C
	if SUED_RW.has_point(w):
		if SU==null:return 0
		if SU.dm_welt(w.x,w.y)<70.0 or SU.frei(F)<rand or SU._belegt(F):return 0
		return 1
	if frei(F)<rand or _belegt(F):return 0
	if MASKE[j]==1 or STADT[j]==1:return 2
	return 1
func _boden_art(w:Vector2)->Array:   # Gewichte [gras, wald, sand, fels, trocken]
	var i=_ix(w.x);var k=_kz(w.y);var j=(k*GNX+i)*4;var bo=G0._bo
	var a=[bo[j]/255.0,bo[j+1]/255.0,bo[j+2]/255.0,bo[j+3]/255.0]
	a.append(max(0.0,1.0-a[0]-a[1]-a[2]-a[3]))
	return a
var _orte_n:={}
func landschaft_orte():
	# besondere Plätze in der freien Landschaft (vor dem Gelände-Ziel: bekommen eine ebene Fläche)
	var t0=Time.get_ticks_msec();var n0=PLATZ.size()
	var plan=[["ld_schrott",7,14.0,45.0,"egal"],["ld_hochstand",50,18.0,1e9,"waldrand"],["ld_camp",12,30.0,1e9,"gruen"],["ld_holz",30,9.0,60.0,"wald"],
		["nd_huette",22,15.0,120.0,"gruen"],["nd_trailer_%d",10,12.0,50.0,"trocken"]]
	for e in plan:
		var kit:String=e[0];var soll:int=e[1];var gesetzt=0
		for versuch in 6000:
			if gesetzt>=soll:break
			var w=Vector2(rng.randf_range(-4300,4600),rng.randf_range(-11200,3400))
			if _land_ok(w,e[2])!=1:continue
			var fr=frei(w-C) if not SUED_RW.has_point(w) else SU.frei(w-C)
			if fr>e[3]:continue
			var b=_boden_art(w)
			match e[4]:
				"waldrand":if b[1]<0.25 or b[1]>0.8:continue
				"wald":if b[1]<0.4:continue
				"gruen":if b[0]+b[1]<0.5:continue
				"trocken":if b[2]+b[4]<0.4:continue
			# nicht zu steil
			var hm=G0._nat(w.x,w.y);var steil=false
			for d in [Vector2(12,0),Vector2(-12,0),Vector2(0,12),Vector2(0,-12)]:
				if abs(G0._nat(w.x+d.x,w.y+d.y)-hm)>3.0:steil=true
			if steil:continue
			var name=kit%rng.randi_range(0,5) if "%d" in kit else kit
			var yaw=rng.randf()*TAU
			# Zufahrt zur Straße ausrichten
			var ns=naechst(w-C) if not SUED_RW.has_point(w) else SU.naechst(w-C)
			if ns[2]>=0:var zu:Vector2=(ns[0]+C)-w;yaw=atan2(zu.x,zu.y)
			var n_vor=PLATZ.size()
			_platz_bei(name,w,yaw,hm)
			if PLATZ.size()>n_vor:gesetzt+=1
		_orte_n[kit]=gesetzt
	print("LANDSCHAFT Plätze ",PLATZ.size()-n0," ",_orte_n," ",Time.get_ticks_msec()-t0," ms")
func landschaft_natur():
	# Bäume, Gras, Steine, Büsche über die ganze Insel (nach dem Gelände-Ziel, auf der endgültigen Höhe)
	var t0=Time.get_ticks_msec();var n0=PLATZ.size();var nb=0
	var busch=KITLISTE.get("ghetto/busch",["busch_0"])
	var x=-4300.0
	while x<4600.0:
		var z=-11200.0
		while z<3400.0:
			var w=Vector2(x+rng.randf_range(-4.5,4.5),z+rng.randf_range(-4.5,4.5))
			z+=10.0
			var art=_land_ok(w,7.0)
			if art==0:continue
			var b=_boden_art(w);var r=rng.randf();var kit=""
			if art==2:
				if r<0.035:kit="ld_laub_%d"%rng.randi_range(0,2)
				elif r<0.06:kit=busch[rng.randi()%busch.size()]
			elif b[1]>=0.45:
				if r<0.5:kit=("ld_nadel_%d" if rng.randf()<0.55 else "ld_laub_%d")%rng.randi_range(0,2)
				elif r<0.62:kit="ld_gras_%d"%rng.randi_range(0,1)
				elif r<0.64:kit="ld_stein_%d"%rng.randi_range(0,2)
			elif b[3]>=0.4:
				if r<0.12:kit="ld_stein_%d"%rng.randi_range(0,2)
				elif r<0.18:kit="ld_nadel_%d"%rng.randi_range(0,2)
				elif r<0.26:kit="ld_gras_2"
			elif b[2]>=0.5:
				if r<0.01:kit="ld_stein_%d"%rng.randi_range(0,2)
			elif b[0]>=b[4]:
				if r<0.07:kit=("ld_laub_%d" if rng.randf()<0.8 else "ld_nadel_%d")%rng.randi_range(0,3 if rng.randf()<0.2 else 2)
				elif r<0.35:kit="ld_gras_%d"%rng.randi_range(0,1)
				elif r<0.38:kit=busch[rng.randi()%busch.size()]
				elif r<0.4:kit="ld_stein_%d"%rng.randi_range(0,2)
			else:
				if r<0.2:kit="ld_gras_2"
				elif r<0.24:kit="ld_stein_%d"%rng.randi_range(0,1)
				elif r<0.27:kit=busch[rng.randi()%busch.size()]
				elif r<0.29:kit="ld_laub_3"
			if kit=="" or not K.KITS.has(kit):continue
			var F=w-C;var sc=rng.randf_range(0.8,1.3)
			var xf=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(sc,sc,sc)),Vector3(F.x,h_end(w)-H0-0.12,F.y))
			PLATZ.append([kit,xf])
			if kit.begins_with("ld_laub") or kit.begins_with("ld_nadel"):
				nb+=1
				PLATZ.append(["ld_fern_nadel" if kit.begins_with("ld_nadel") else "ld_fern_laub",xf])
			if art==2:_occ(F)
		x+=10.0
	print("LANDSCHAFT Natur ",PLATZ.size()-n0," Bäume ",nb," ",Time.get_ticks_msec()-t0," ms")

# ---------------- Geometrie mit Höhe ----------------
var _belag_m:={}
func belag_mat(art:String)->Material:
	# Schotter/Sandweg: kleine Kachel-Textur, extern gespeichert (alle Kacheln teilen sie)
	if _belag_m.has(art):return _belag_m[art]
	var pfad="res://assets/cache/comic/kits/belag_%s.res"%art
	var N=128;var img=Image.create(N,N,false,Image.FORMAT_RGB8);var r=RandomNumberGenerator.new();r.seed=art.hash()
	for y in N:
		for x in N:
			var c=Color(0.56,0.51,0.45)*(0.85+r.randf()*0.25) if art=="schotter" else Color(0.78,0.67,0.48)*(0.92+r.randf()*0.12)
			c.a=1.0;img.set_pixel(x,y,c)
	if art=="schotter":
		for k in 380:
			var q=Vector2i(r.randi()%N,r.randi()%N);var g=r.randf_range(0.35,0.78)
			for dy in 2:
				for dx in 2:img.set_pixel((q.x+dx)%N,(q.y+dy)%N,Color(g,g*0.96,g*0.9))
	img.generate_mipmaps()
	var m=StandardMaterial3D.new();m.albedo_texture=ImageTexture.create_from_image(img);m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_scale=Vector3(0.35,0.35,0.35)
	m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.roughness=1.0;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ResourceSaver.save(m,pfad);m=load(pfad)
	_belag_m[art]=m;L.kein_schatten[m]=true
	return m
func fahrbahnen():
	var flick=T(Color(0.2,0.2,0.22));var gelb=T(Color(0.95,0.8,0.15))
	var bank=T(Color(0.47,0.6,0.33));L.kein_schatten[bank]=true;L.kein_schatten[L.M.asphalt]=true;L.kein_schatten[L.M.markierung]=true;L.kein_schatten[gelb]=true;L.kein_schatten[L.M.pflaster]=true
	var alt=L.koll_an;L.koll_an=true
	for ri in ROADS.size():
		var r=ROADS[ri];var belag=r.get("belag","asphalt")
		var so=L._st(L.M.asphalt if belag=="asphalt" else belag_mat(belag),true)
		var P:PackedVector2Array=r.P;var Y:PackedFloat32Array=r.Y;var n=P.size()
		var Ls=[];var Rs=[]
		for i in n:
			var d:Vector2=(P[min(i+1,n-1)]-P[max(i-1,0)]).normalized();var nn=Vector2(-d.y,d.x)
			var e=0.0
			if i==0 or i==n-1:e=r.w*0.6
			var pp=P[i]+(d*(-e if i==0 else e))
			var a3=Vector3(pp.x+nn.x*r.w,Y[i]+0.06,pp.y+nn.y*r.w);var b3=Vector3(pp.x-nn.x*r.w,Y[i]+0.06,pp.y-nn.y*r.w)
			# auf einer vorrangigen Fahrbahn immer knapp unter deren Belag (kein Durchstechen an Einmündungen)
			for v in [a3,b3]:
				var yf=_y_fremd(Vector2(v.x,v.z),ri,0.3)
				if yf<INF:v.y=min(v.y,yf+0.03)
			a3.y=min(a3.y,_y_fremd(Vector2(a3.x,a3.z),ri,0.3)+0.03);b3.y=min(b3.y,_y_fremd(Vector2(b3.x,b3.z),ri,0.3)+0.03)
			Ls.append(a3);Rs.append(b3)
		for i in n-1:
			L._tri(so,Ls[i],Ls[i+1],Rs[i+1],Vector3.UP);L._tri(so,Ls[i],Rs[i+1],Rs[i],Vector3.UP)
		# Bankett: schräg vom Fahrbahnrand 2,6 m nach außen ins Gelände (statt senkrechter Kante)
		if not r.stadt:
			var sb=L._st(bank,true)
			for i in n-1:
				for sd in [1,-1]:
					var a=Ls[i] if sd>0 else Rs[i];var b=Ls[i+1] if sd>0 else Rs[i+1]
					var o=(a-(Rs[i] if sd>0 else Ls[i]));o.y=0;o=o.normalized()
					var o2=(b-(Rs[i+1] if sd>0 else Ls[i+1]));o2.y=0;o2=o2.normalized()
					var mid=(a+b)*0.5+o*1.3
					if auf_fahrbahn(Vector2(mid.x,mid.z),ri,0.5):continue
					var a_in=a-o*0.05-Vector3(0,0.03,0);var b_in=b-o2*0.05-Vector3(0,0.03,0)
					var a_out=a+o*2.6-Vector3(0,0.41,0);var b_out=b+o2*2.6-Vector3(0,0.41,0)
					if sd>0:L._tri(sb,a_in,a_out,b_out,Vector3.UP);L._tri(sb,a_in,b_out,b_in,Vector3.UP)
					else:L._tri(sb,a_in,b_in,b_out,Vector3.UP);L._tri(sb,a_in,b_out,a_out,Vector3.UP)
	L.koll_an=alt
	for ri in ROADS.size():
		var r=ROADS[ri];var s=4.0;var Lg:float=r.S[-1]
		if r.get("belag","asphalt")!="asphalt":continue
		while s<Lg-4.0:
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var y=y_bei(r,s)+0.075;var nn=Vector2(-t.y,t.x)
			var bas=Basis(Vector3.UP,atan2(t.x,t.y))
			if r.orig=="autobahn":
				if fmod(s,12.0)<4.0:
					for o in [-r.w*0.5,r.w*0.5]:var q=p+nn*o;L.box(L.M.markierung,Vector3(q.x,y,q.y),Vector3(0.18,0.012,4.0),bas,0.0)
				for o in [-0.25,0.25]:var q=p+nn*o;L.box(gelb,Vector3(q.x,y,q.y),Vector3(0.15,0.012,3.05),bas,0.0)
				if fmod(s,6.0)<3.0:
					for o in [-r.w-0.6,r.w+0.6]:
						var q=p+nn*o;L.box(L.M.metall,Vector3(q.x,y+0.55,q.y),Vector3(0.08,0.3,3.1),bas,0.0)
						L.box(L.M.metall,Vector3(q.x,y+0.3,q.y),Vector3(0.1,0.6,0.1),bas,0.0)
			elif r.typ!="gasse" and fmod(s,9.0)<3.0 and not nah_kreuzung(p,2.0):
				L.box(L.M.markierung if r.stadt else gelb,Vector3(p.x,y,p.y),Vector3(0.14,0.012,2.6),bas,0.0)
			if r.stadt and rng.randf()<0.08:
				var q=p+nn*rng.randf_range(-r.w+0.8,r.w-0.8)
				L.box(flick,Vector3(q.x,y-0.005,q.y),Vector3(rng.randf_range(0.8,2.6),0.01,rng.randf_range(0.6,1.8)),Basis(Vector3.UP,rng.randf()*TAU),0.0)
			s+=3.0
	# Rollbahnen
	var so2=L._st(L.M.asphalt,true)
	for sd in SONDER:
		var P:PackedVector2Array=sd.P;var n=P.size()
		var mat_sand=stil(P[n/2])=="wflug"
		var so3=L._st(T(Color(0.72,0.62,0.45)),true) if mat_sand else so2
		for i in n-1:
			var a:Vector2=P[i];var b:Vector2=P[i+1];var t=(b-a).normalized();var nn=Vector2(-t.y,t.x)
			var ya=hy(a)+0.08;var yb=hy(b)+0.08
			var A1=Vector3(a.x+nn.x*sd.w,ya,a.y+nn.y*sd.w);var A2=Vector3(a.x-nn.x*sd.w,ya,a.y-nn.y*sd.w)
			var B1=Vector3(b.x+nn.x*sd.w,yb,b.y+nn.y*sd.w);var B2=Vector3(b.x-nn.x*sd.w,yb,b.y-nn.y*sd.w)
			L._tri(so3,A1,B1,B2,Vector3.UP);L._tri(so3,A1,B2,A2,Vector3.UP)
			if sd.typ=="runway" and i%3==0 and not mat_sand:L.box(L.M.markierung,Vector3(a.x,ya+0.01,a.y),Vector3(0.6,0.01,6.0),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
func platten():
	# keine Platten: Gelände ist der Boden; Gehwege als Streifen entlang der Stadtstraßen
	var alt=L.koll_an;L.koll_an=true
	var so=L._st(L.M.pflaster,true);var n_ok=0
	for ri in ROADS.size():
		var r=ROADS[ri]
		if not r.stadt or r.sw<=0.0:continue
		var s=0.0;var Lg:float=r.S[-1]
		while s<Lg:
			var s2=min(s+3.0,Lg)
			var b1=bei(r,s);var b2=bei(r,s2)
			for sd in [1,-1]:
				var n1=Vector2(-b1[1].y,b1[1].x)*sd;var n2=Vector2(-b2[1].y,b2[1].x)*sd
				var a0:Vector2=b1[0]+n1*r.w;var a1:Vector2=b1[0]+n1*(r.w+r.sw);var c0:Vector2=b2[0]+n2*r.w;var c1:Vector2=b2[0]+n2*(r.w+r.sw)
				var mid=(a0+a1+c0+c1)*0.25
				if auf_fahrbahn(mid,ri,0.3) or nah_kreuzung(mid,1.0):continue
				var ya=y_bei(r,s)+0.11;var yc=y_bei(r,s2)+0.11
				L._tri(so,Vector3(a0.x,ya,a0.y),Vector3(c0.x,yc,c0.y),Vector3(c1.x,yc,c1.y),Vector3.UP)
				L._tri(so,Vector3(a0.x,ya,a0.y),Vector3(c1.x,yc,c1.y),Vector3(a1.x,ya,a1.y),Vector3.UP)
				n_ok+=1
			s=s2
	L.koll_an=alt
	# Gefängnismauer (ovaler Ring)
	if not KNAST_WAND.is_empty():
		var c:Vector2=KNAST_WAND[0]-C;var y=KNAST_WAND[3]-H0;var grau=T(Color(0.7,0.7,0.68))
		for a in range(0,360,4):
			var p0=c+Vector2(cos(deg_to_rad(a))*KNAST_WAND[1],sin(deg_to_rad(a))*KNAST_WAND[2])
			var p1=c+Vector2(cos(deg_to_rad(a+4))*KNAST_WAND[1],sin(deg_to_rad(a+4))*KNAST_WAND[2])
			var m=(p0+p1)*0.5;var t=(p1-p0)
			if a>=84 and a<96:continue   # Tor
			var b=Basis(Vector3.UP,atan2(t.x,t.y))
			L.box(grau,Vector3(m.x,y+3.0,m.y),Vector3(0.8,6.0,t.length()+0.3),b,0.04);L.koll_box(Vector3(m.x,y+3.0,m.y),Vector3(0.8,6.0,t.length()+0.3),b)
			L.zyl(L.M.metall,Vector3(m.x,y+6.0,m.y),Vector3(m.x,y+6.6,m.y),0.35,1.1)
	print("NORD Gehwegstücke ",n_ok)
func wege():
	var dreck=L._toon(Color(0.4,0.34,0.25))
	for w in WEGE:
		var a:Vector2=w.a;var b:Vector2=w.b;var d=(b-a).normalized();var n=Vector2(-d.y,d.x)*1.5
		var m=dreck if w.stil in ["ghetto","redneck","farm","dorf"] else L.M.pflaster
		var so=L._st(m,true);var ya=hy(a)+0.1;var yb=hy(b)+0.1
		L._tri(so,Vector3(a.x+n.x,ya,a.y+n.y),Vector3(b.x+n.x,yb,b.y+n.y),Vector3(b.x-n.x,yb,b.y-n.y),Vector3.UP)
		L._tri(so,Vector3(a.x+n.x,ya,a.y+n.y),Vector3(b.x-n.x,yb,b.y-n.y),Vector3(a.x-n.x,ya,a.y-n.y),Vector3.UP)
func strassenrand():
	for ri in ROADS.size():
		var r=ROADS[ri]
		if not r.stadt or r.typ=="gasse":continue
		var s=10.0;var prev=null;var Lg:float=r.S[-1]
		while s<Lg-6.0:
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var n=Vector2(-t.y,t.x)
			var q=p+n*(r.w+0.6);var st=stil(q);var y=y_bei(r,s)+0.11
			if not nah_kreuzung(q,3.0) and frei(q,ri)>0.5:
				if st in ["ghetto","dorf","redneck","farm"]:
					var top=GL.mast(Vector3(q.x,y,q.y))
					if prev!=null and top.distance_to(prev)<40.0:GL.kabel(prev,top,0.9)
					prev=top
				else:L._laterne(Vector3(q.x,y,q.y),Vector3(-n.x,0,-n.y));prev=null
			else:prev=null
			s+=30.0
func parken_strasse():
	var kinds=["c_wartburg","c_muscle","c_e30","c_luxus","c_trabant","c_kompakt","c_suv","c_jdm"]
	for ri in ROADS.size():
		var r=ROADS[ri]
		if not r.stadt or r.typ=="gasse":continue
		var s=8.0
		while s<r.S[-1]-8.0:
			s+=rng.randf_range(8,16)
			if rng.randf()>0.18:continue
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var sd=[-1,1][rng.randi()%2];var n=Vector2(-t.y,t.x)*sd
			var q=p+n*(r.w-1.15)
			var ok=not nah_kreuzung(q,10.0)
			for e in [q+t*2.4+n*1.0,q-t*2.4+n*1.0,q+t*2.4-n*1.0,q-t*2.4-n*1.0]:
				var ns=naechst(e)
				if ns[2]!=ri or ns[3]>r.w-0.15:ok=false
			if not ok:continue
			var h=t*(-sd)
			PARK.append([kinds[rng.randi()%kinds.size()],Transform3D(Basis(Vector3.UP,atan2(h.x,h.y)),Vector3(q.x,y_bei(r,s)+0.07,q.y))])

# ---------------- Gelände-Zielhöhen ----------------
func gelaende_ziel():
	var t0=Time.get_ticks_msec()
	# 1) Stadtmaske: geglättete Höhe, Übergang 40 m
	var dist=PackedInt32Array();dist.resize(GNX*GNZ);dist.fill(99999);var q=[]
	for j in GNX*GNZ:
		if MASKE[j]==1:dist[j]=0;q.append(j)
	_bfs(dist,q,4)
	for j in GNX*GNZ:
		if dist[j]>4 or WASSER[j]==1 or not is_nan(TH[j]):continue
		TH[j]=lerp(HS[j],NAT[j],smoothstep(0.0,4.0,float(dist[j])))
	# 2) Grundstücks-Terrassen
	var LOT=PackedByteArray();LOT.resize(GNX*GNZ)
	for e in TERR:
		var P:Array=e[0];var h:float=e[1]
		var mn=Vector2(INF,INF);var mx=-mn
		for p in P:mn=Vector2(min(mn.x,p.x+C.x),min(mn.y,p.y+C.y));mx=Vector2(max(mx.x,p.x+C.x),max(mx.y,p.y+C.y))
		var poly=PackedVector2Array();for p in P:poly.append(p+C)
		for k in range(_kz(mn.y),_kz(mx.y)+1):
			for i in range(_ix(mn.x),_ix(mx.x)+1):
				if i<0 or k<0 or i>=GNX or k>=GNZ:continue
				if Geometry2D.is_point_in_polygon(Vector2(GX0+i*MST,GZ0+k*MST),poly):TH[k*GNX+i]=h;LOT[k*GNX+i]=1
	# 3) Straßen: Fahrbahn plus eine Rasterzelle Rand flach auf Profilhöhe (sonst sticht das Gelände
	#    zwischen den 10-m-Punkten durch den Asphalt), danach Böschung – je größer der Höhenunterschied, desto breiter
	var best={}   # j -> [abstand, zielhöhe, w, stadt, böschung]
	var unter={}  # j -> niedrigste Fahrbahnhöhe aller Straßen, deren Fahrbahnband die Zelle überdeckt
	for r in ROADS:
		var P:PackedVector2Array=r.P;var Y:PackedFloat32Array=r.Y
		var wk=r.w+r.sw
		for i in P.size()-1:
			var a=P[i]+C;var b=P[i+1]+C;var Lg=a.distance_to(b);var s=0.0
			while s<=Lg:
				var p=a.lerp(b,s/max(Lg,0.01));var y=lerp(Y[i],Y[i+1],s/max(Lg,0.01))+H0
				var R:float
				if r.stadt:R=wk+MST*1.2
				else:
					var dh=abs(y-G0._nat(p.x,p.y))
					R=wk+MST*1.5+clamp(dh*2.0+8.0,16.0,80.0)
				for k in range(_kz(p.y-R),_kz(p.y+R)+1):
					for ii in range(_ix(p.x-R),_ix(p.x+R)+1):
						if ii<0 or k<0 or ii>=GNX or k>=GNZ:continue
						var d=Vector2(GX0+ii*MST,GZ0+k*MST).distance_to(p)
						if d>R:continue
						var j=k*GNX+ii
						if d<=(wk+1.0 if r.stadt else wk+MST*1.5):unter[j]=min(unter.get(j,INF),y-0.12)
						if not best.has(j) or best[j][0]>d:best[j]=[d,y,wk,r.stadt,R]
				s+=4.0
	for j in best:
		var e=best[j];var d:float=e[0];var y:float=e[1];var wk:float=e[2];var R:float=e[4]
		var basis=TH[j] if not is_nan(TH[j]) else NAT[j]
		if e[3]:
			if d<=wk+1.0:TH[j]=y-0.12
			else:TH[j]=min(basis,y-0.06)   # Stadt: nur absenken (Grundstücke bleiben auf ihrer Terrasse)
		else:
			var band=wk+MST*1.5
			if d<=band:TH[j]=y-0.12
			elif LOT[j]==0:TH[j]=lerp(y-0.12,basis,smoothstep(band,R,d))
	# zuletzt: unter jeder Fahrbahn höchstens auf der niedrigsten Straßenhöhe -> nie Gelände im Belag
	for j in unter:TH[j]=unter[j]
	print("NORD Gelände-Ziel ",Time.get_ticks_msec()-t0," ms, Straßenzellen ",best.size())
