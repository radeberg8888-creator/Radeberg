extends "res://scripts/comic/sued_lib.gd"
# Bausatz-Platzierung (Vororte, Ghetto, Strand, Hafen, Industrie) auf dem NEUEN Straßennetz der alten Karte.
# Unterschiede zu sued_lib: Netz kommt fertig bereinigt von außen, Stil aus dem Viertel-Raster der alten Karte,
# Maske = Stadtfläche ohne Fassaden-Viertel (die baut stadt_lib), Höhen setzt der Bake hinterher (Höhenfeld).
var VR:={}            # Vector2i(20-m-Zelle, Welt) -> Stil
const VZ:=20.0

func stil(pl:Vector2)->String:
	var w=pl+C
	return VR.get(Vector2i(int(floor(w.x/VZ)),int(floor(w.y/VZ))),"sued")

# Netz übernehmen: [{n,P(lokal),w,typ}] -> ROADS mit Gehweg und Längen, Segmentraster
func netz_setzen(netz:Array):
	ROADS=[];SEG={}
	for r in netz:
		var P:PackedVector2Array=r.P
		var S=[0.0]
		for i in range(1,P.size()):S.append(S[-1]+P[i].distance_to(P[i-1]))
		var sw={"allee":3.5,"strasse":2.5,"gasse":1.2,"land":1.6}.get(r.typ,2.5)
		var ri=ROADS.size()
		ROADS.append({"n":r.n,"P":P,"w":r.w,"sw":sw,"typ":"strasse" if r.typ=="land" else r.typ,"S":S})
		for i in P.size()-1:_seg_ein(ri,i,P[i],P[i+1])

# Maske direkt setzen (Weltraster): bebaubar[j] (1/0), wasser[j]
func maske_setzen(x0:float,z0:float,st:float,nx:int,nz:int,bebaubar:PackedByteArray,wasser_:PackedByteArray,rect_lokal:Rect2):
	MX0=x0;MZ0=z0;MST=st;MNX=nx;MNZ=nz;MASKE=bebaubar;WASSER=wasser_;RECT=rect_lokal

# Kreuzungen über ein Raster (bei Tausenden Kreuzungen sonst zu langsam)
var _jr:={};var _jr_n:=-1
func nah_kreuzung(p:Vector2,extra:=0.0)->bool:
	if _jr_n!=JUNC.size():
		_jr={};_jr_n=JUNC.size()
		for j in JUNC:
			var c=Vector2i(int(floor(j.p.x/40.0)),int(floor(j.p.y/40.0)))
			if not _jr.has(c):_jr[c]=[]
			_jr[c].append(j)
	var c0=Vector2i(int(floor(p.x/40.0)),int(floor(p.y/40.0)))
	for dx in range(-1,2):
		for dz in range(-1,2):
			for j in _jr.get(c0+Vector2i(dx,dz),[]):
				if j.p.distance_to(p)<j.r+extra:return true
	return false
func _junc(p:Vector2,a:int,b:int):
	var c0=Vector2i(int(floor(p.x/40.0)),int(floor(p.y/40.0)))
	for dx in range(-1,2):
		for dz in range(-1,2):
			for j in _jr.get(c0+Vector2i(dx,dz),[]):
				if j.p.distance_to(p)<14.0 and ((j.a==a and j.b==b) or (j.a==b and j.b==a)):return
	var j={"p":p,"r":max(ROADS[a].w,ROADS[b].w)+ROADS[a].sw+1.0,"a":a,"b":b}
	JUNC.append(j)
	if not _jr.has(c0):_jr[c0]=[]
	_jr[c0].append(j);_jr_n=JUNC.size()
