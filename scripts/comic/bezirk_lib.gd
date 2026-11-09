extends RefCounted
# Bezirks-Generator: baut Comic-Bebauung entlang der ORIGINAL-Straßen (karte.json) in einem Rechteck.
# Straßen bleiben geschwungen wie im Original; Grundstücke stehen quer zur Straße, so tief wie Platz ist.
var L;var GL
var rng:=RandomNumberGenerator.new()
var ROADS:=[]          # {P:PackedVector2Array, w, sw, typ, S:Array}
var SEG:={}            # Raster 20 m -> [road_i, seg_i]
var OCC:={}            # belegte Zellen (2 m)
var LOTS:=[]
var RECT:Rect2
var AUS:=[]            # ausgeschlossene Rechtecke
const KB:=0.15
var stil:="ghetto"

func _init(lib,ghetto_lib):
	L=lib;GL=ghetto_lib;rng.seed=99

# ---------------- Straßen ----------------
func laden(datei:String,rect:Rect2,aus:Array):
	RECT=rect;AUS=aus
	var d=JSON.parse_string(FileAccess.get_file_as_string(datei))
	for r in d.roads:
		if not r.typ in ["strasse","allee","gasse"]:continue
		# in Stücke zerlegen, die im Rechteck und außerhalb der Ausschlüsse liegen
		var cur=PackedVector2Array()
		for q in r.P:
			var p=Vector2(q[0],q[1]);var drin=rect.grow(-2.0).has_point(p)
			for a in aus:
				if a.has_point(p):drin=false
			if drin:cur.append(p)
			else:
				if cur.size()>=4:_neu(cur,r)
				cur=PackedVector2Array()
		if cur.size()>=4:_neu(cur,r)
	print("BEZIRK Straßen ",ROADS.size())
func _neu(P:PackedVector2Array,r):
	# glätten + auf ~4 m ausdünnen
	var Q=PackedVector2Array();var acc=0.0
	Q.append(P[0])
	for i in range(1,P.size()):
		acc+=P[i].distance_to(P[i-1])
		if acc>=4.0 or i==P.size()-1:Q.append(P[i]);acc=0.0
	if Q.size()<2:return
	var S=[0.0]
	for i in range(1,Q.size()):S.append(S[-1]+Q[i].distance_to(Q[i-1]))
	if S[-1]<12.0:return
	# doppelte Straßen (im Original teils zweimal erfasst) weglassen
	var dop=0
	for i in range(0,Q.size(),3):
		if auf_fahrbahn(Q[i],-1,1.0):dop+=1
	if dop>=int(ceil(Q.size()/3.0))*0.7:return
	var w=float(r.w);var sw=float(r.sw)
	if r.typ=="strasse":w=5.0;sw=2.5
	elif r.typ=="gasse":w=3.2;sw=1.2
	elif r.typ=="allee":w=7.0;sw=3.5
	var ri=ROADS.size()
	ROADS.append({"P":Q,"w":w,"sw":sw,"typ":r.typ,"S":S})
	for i in Q.size()-1:
		var a=Q[i];var b=Q[i+1]
		var mn=Vector2(min(a.x,b.x),min(a.y,b.y))/20.0;var mx=Vector2(max(a.x,b.x),max(a.y,b.y))/20.0
		for gx in range(int(floor(mn.x))-1,int(floor(mx.x))+2):
			for gz in range(int(floor(mn.y))-1,int(floor(mx.y))+2):
				var k=Vector2i(gx,gz)
				if not SEG.has(k):SEG[k]=[]
				SEG[k].append(Vector2i(ri,i))
# Abstand zur nächsten Fahrbahnkante (negativ = auf Fahrbahn), ohne Straße 'ohne'
func frei(p:Vector2,ohne:=-1)->float:
	var best=1e9;var k=Vector2i(int(floor(p.x/20.0)),int(floor(p.y/20.0)))
	for s in SEG.get(k,[]):
		if s.x==ohne:continue
		var r=ROADS[s.x];var a:Vector2=r.P[s.y];var b:Vector2=r.P[s.y+1]
		var t=clamp((p-a).dot(b-a)/max((b-a).length_squared(),0.0001),0.0,1.0)
		best=min(best,p.distance_to(a.lerp(b,t))-r.w-r.sw)
	return best
func auf_fahrbahn(p:Vector2,ohne:=-1,rand:=0.2)->bool:
	var k=Vector2i(int(floor(p.x/20.0)),int(floor(p.y/20.0)))
	for s in SEG.get(k,[]):
		if s.x==ohne:continue
		var r=ROADS[s.x];var a:Vector2=r.P[s.y];var b:Vector2=r.P[s.y+1]
		var t=clamp((p-a).dot(b-a)/max((b-a).length_squared(),0.0001),0.0,1.0)
		if p.distance_to(a.lerp(b,t))<r.w+rand:return true
	return false
func bei(r,s:float)->Array:
	var S:Array=r.S;var P:PackedVector2Array=r.P;var i=0
	while i<S.size()-2 and S[i+1]<s:i+=1
	var t=clamp((s-S[i])/max(S[i+1]-S[i],0.001),0.0,1.0)
	var d=(P[i+1]-P[i]).normalized()
	return [P[i].lerp(P[i+1],t),d]

# ---------------- Bauen ----------------
func bauen():
	var t0=Time.get_ticks_msec()
	L.mat_cache=true
	# Grund: verdorrter Boden über das ganze Rechteck (Lücken sehen nach Brache aus, nicht nach Loch)
	L.box(GL.T(Color(0.5,0.48,0.3)),Vector3(RECT.get_center().x,0.0,RECT.get_center().y),Vector3(RECT.size.x,0.02,RECT.size.y),Basis(),0.0)
	fahrbahnen()
	platten()
	grundstuecke()
	alt_haeuser()
	alt_haeuser()
	luecken_fuellen()
	strassenrand()
	L.mat_cache=false
	print("BEZIRK fertig: Straßen ",ROADS.size()," Grundstücke ",LOTS.size()," ",Time.get_ticks_msec()-t0," ms")

func fahrbahnen():
	var so=L._st(L.M.asphalt,true);var flick=GL.T(Color(0.2,0.2,0.22))
	for r in ROADS:
		var P:PackedVector2Array=r.P.duplicate();var n=P.size()
		P[0]=P[0]+(P[0]-P[1]).normalized()*r.w*0.6;P[n-1]=P[n-1]+(P[n-1]-P[n-2]).normalized()*r.w*0.6
		var Ls=[];var Rs=[]
		for i in n:
			var d:Vector2=(P[min(i+1,n-1)]-P[max(i-1,0)]).normalized();var nn=Vector2(-d.y,d.x)
			Ls.append(P[i]+nn*r.w);Rs.append(P[i]-nn*r.w)
		for i in n-1:
			L._tri(so,Vector3(Ls[i].x,0.015,Ls[i].y),Vector3(Ls[i+1].x,0.015,Ls[i+1].y),Vector3(Rs[i+1].x,0.015,Rs[i+1].y),Vector3.UP)
			L._tri(so,Vector3(Ls[i].x,0.015,Ls[i].y),Vector3(Rs[i+1].x,0.015,Rs[i+1].y),Vector3(Rs[i].x,0.015,Rs[i].y),Vector3.UP)
		# Mittellinie (abgefahren), Flicken
		var s=4.0;var Lg:float=r.S[-1]
		while s<Lg-4.0:
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1]
			var kreuz=false
			for k in [p+Vector2(-t.y,t.x)*(r.w+1.0),p-Vector2(-t.y,t.x)*(r.w+1.0)]:
				if auf_fahrbahn(k,ROADS.find(r)):kreuz=true
			if r.typ!="gasse" and fmod(s,9.0)<3.0 and not kreuz and rng.randf()<0.8:
				L.box(L.M.markierung,Vector3(p.x,0.03,p.y),Vector3(0.14,0.012,2.6),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
			if rng.randf()<0.15:
				var q=p+Vector2(-t.y,t.x)*rng.randf_range(-r.w+0.8,r.w-0.8)
				L.box(flick,Vector3(q.x,0.026,q.y),Vector3(rng.randf_range(0.8,2.6),0.01,rng.randf_range(0.6,1.8)),Basis(Vector3.UP,rng.randf()*TAU),0.0)
			s+=3.0

func gehwege():
	for ri in ROADS.size():
		var r=ROADS[ri];var P:PackedVector2Array=r.P;var n=P.size()
		for sd in [-1,1]:
			for i in n-1:
				var d0:Vector2=(P[min(i+1,n-1)]-P[max(i-1,0)]).normalized();var d1:Vector2=(P[min(i+2,n-1)]-P[i]).normalized()
				var n0=Vector2(-d0.y,d0.x)*sd;var n1=Vector2(-d1.y,d1.x)*sd
				var a0=P[i]+n0*r.w;var a1=P[i+1]+n1*r.w;var b0=P[i]+n0*(r.w+r.sw);var b1=P[i+1]+n1*(r.w+r.sw)
				# nicht in fremde Fahrbahnen hinein (Kreuzungen bleiben frei)
				if auf_fahrbahn((a0+b1)*0.5,ri,0.6) or auf_fahrbahn(b0,ri,0.3) or auf_fahrbahn(b1,ri,0.3) or auf_fahrbahn(a0,ri,0.3) or auf_fahrbahn(a1,ri,0.3):continue
				L.hex(L.M.pflaster,[Vector3(a0.x,-0.1,a0.y),Vector3(a1.x,-0.1,a1.y),Vector3(b1.x,-0.1,b1.y),Vector3(b0.x,-0.1,b0.y),
					Vector3(a0.x,KB,a0.y),Vector3(a1.x,KB,a1.y),Vector3(b1.x,KB,b1.y),Vector3(b0.x,KB,b0.y)],0.0)
				# Bordsteinkante
				var c0=P[i]+n0*(r.w+0.18);var c1=P[i+1]+n1*(r.w+0.18)
				L.hex(L.M.stein,[Vector3(a0.x,-0.1,a0.y),Vector3(a1.x,-0.1,a1.y),Vector3(c1.x,-0.1,c1.y),Vector3(c0.x,-0.1,c0.y),
					Vector3(a0.x,KB+0.01,a0.y),Vector3(a1.x,KB+0.01,a1.y),Vector3(c1.x,KB+0.01,c1.y),Vector3(c0.x,KB+0.01,c0.y)],0.012)

# Gehweg-/Grundfläche als durchgehende Platte (Kachel minus Fahrbahnen), Bordsteinecken gerundet
const RUND:=3.0
func platten():
	var t=Time.get_ticks_msec();var n=0
	var x=RECT.position.x
	while x<RECT.end.x-0.01:
		var z=RECT.position.y
		while z<RECT.end.y-0.01:
			n+=_kachel(Rect2(x,z,min(100.0,RECT.end.x-x),min(100.0,RECT.end.y-z)),0)
			z+=100.0
		x+=100.0
	print("BEZIRK Platten ",n," ",Time.get_ticks_msec()-t," ms")
func _kachel(R:Rect2,tiefe:int)->int:
	for a in AUS:
		if a.encloses(R):return 0
	var T=PackedVector2Array([R.position,Vector2(R.end.x,R.position.y),R.end,Vector2(R.position.x,R.end.y)])
	var teile=[T];var loch=false
	var gross=R.grow(RUND+12.0)
	for ri in ROADS.size():
		var r=ROADS[ri]
		# nur Straßen in der Nähe, Linie auf die Umgebung gekürzt
		var stueck=PackedVector2Array();var stuecke=[]
		for q in r.P:
			if gross.has_point(q):stueck.append(q)
			elif stueck.size()>0:
				stueck.append(q);stuecke.append(stueck);stueck=PackedVector2Array()
		if stueck.size()>0:stuecke.append(stueck)
		for st in stuecke:
			if st.size()<2:continue
			for band in Geometry2D.offset_polyline(st,r.w+RUND,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
				var neu=[]
				for tp in teile:
					for e in Geometry2D.clip_polygons(tp,band):
						if Geometry2D.is_polygon_clockwise(e):loch=true
						else:neu.append(e)
				teile=neu
	if loch and tiefe<3:
		var h=R.size*0.5;var c=0
		for k in [Vector2(0,0),Vector2(h.x,0),Vector2(0,h.y),h]:c+=_kachel(Rect2(R.position+k,h),tiefe+1)
		return c
	var c=0
	for tp in teile:
		# Ausschlüsse abziehen
		var tl=[tp]
		for a in AUS:
			var ap=PackedVector2Array([a.position,Vector2(a.end.x,a.position.y),a.end,Vector2(a.position.x,a.end.y)])
			var t2=[]
			for q in tl:
				for e in Geometry2D.clip_polygons(q,ap):
					if not Geometry2D.is_polygon_clockwise(e):t2.append(e)
			tl=t2
		for q in tl:
			# Ecken runden: um RUND aufblasen (Fahrbahnkante kommt auf w), dann wieder auf die Kachel beschneiden
			for g in Geometry2D.offset_polygon(q,RUND,Geometry2D.JOIN_ROUND):
				if Geometry2D.is_polygon_clockwise(g):continue
				for e in Geometry2D.intersect_polygons(g,T):
					if Geometry2D.is_polygon_clockwise(e) or abs(L._flaeche2(e))<1.0:continue
					L._platte(e,-0.6,KB,L.M.pflaster,L.M.stein);c+=1
	return c

# ---------------- Grundstücke ----------------
func _belegt(p:Vector2)->bool:return OCC.has(Vector2i(int(floor(p.x/2.0)),int(floor(p.y/2.0))))
func _rechteck_ok(F:Vector2,t:Vector2,n:Vector2,w:float,d:float)->bool:
	# F: Mitte Vorderkante, t: entlang Straße, n: von der Straße weg
	var x=-w*0.5
	while x<=w*0.5+0.01:
		var z=0.5
		while z<=d+0.01:
			var p=F+t*x+n*z
			if not RECT.has_point(p) or _belegt(p) or frei(p)<-0.3:return false
			for a in AUS:
				if a.has_point(p):return false
			z+=2.0
		x+=2.0
	return true
func _belegen(F:Vector2,t:Vector2,n:Vector2,w:float,d:float):
	var x=-w*0.5-0.5
	while x<=w*0.5+0.5:
		var z=0.0
		while z<=d+0.5:
			var p=F+t*x+n*z;OCC[Vector2i(int(floor(p.x/2.0)),int(floor(p.y/2.0)))]=true;z+=1.0
		x+=1.0
func grundstuecke():
	for ri in ROADS.size():
		var r=ROADS[ri];var Lg:float=r.S[-1]
		for sd in [-1,1]:
			var s=3.0
			while s<Lg-3.0:
				var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var n=Vector2(-t.y,t.x)*sd
				var F=p+n*(r.w+r.sw+0.3)
				# Ecke? (fremde Straße in der Nähe)
				var ecke=frei(F+t*8.0,ri)<6.0 or frei(F-t*8.0,ri)<6.0
				var typ=_typ_waehlen(ecke,r)
				var w:float=typ[1];var dmin:float=typ[2]
				if not _rechteck_ok(F,t,n,w,dmin):
					s+=2.0;continue
				# so tief wie möglich (bis 42 m), damit kein Innenhof leer bleibt
				var d=dmin
				while d<(26.0 if typ[0]=="holz" else 20.0) and _rechteck_ok(F,t,n,w,d+2.0):d+=2.0
				_belegen(F,t,n,w,d)
				LOTS.append({"F":F,"t":t,"n":n,"w":w,"d":d,"typ":typ[0],"r":ri})
				parzelle(F,t,n,w,d,typ[0])
				s+=w+0.4
func _typ_waehlen(ecke:bool,r)->Array:
	if r.typ=="gasse":
		return ["schuppen",rng.randf_range(6,9),7.0] if rng.randf()<0.6 else ["holz",11.5,16.0]
	if ecke and rng.randf()<0.7:return ["laden",rng.randf_range(13,17),12.0]
	var x=rng.randf()
	if r.typ=="allee" or r.S[-1]>350.0:   # Hauptstraßen: Geschäfte und Mietshäuser
		if x<0.4:return ["block",rng.randf_range(18,28),14.0]
		if x<0.62:return ["laden",rng.randf_range(13,18),12.0]
		if x<0.66:return ["werbung",8.0,6.0]
	if x<0.12:return ["block",rng.randf_range(16,24),14.0]
	if x<0.18:return ["brache",rng.randf_range(10,14),10.0]
	if x<0.21:return ["kirche",20.0,26.0]
	return ["holz",12.0,16.0]

func parzelle(F:Vector2,t:Vector2,n:Vector2,w:float,d:float,typ:String):
	var aussen=Vector3(-n.x,0,-n.y);var rechts=Vector3(t.x,0,t.y)
	if rechts.cross(Vector3.UP).dot(aussen)<0:rechts=-rechts
	var yaw=atan2(aussen.x,aussen.z)
	var F3=Vector3(F.x,KB,F.y)
	var P=func(px,py,pz):return F3+rechts*px+Vector3.UP*py-aussen*pz
	var hb=Basis(rechts,Vector3.UP,aussen)
	# Boden des Grundstücks
	var gras=[GL.T(Color(0.52,0.53,0.3)),GL.T(Color(0.47,0.45,0.27)),GL.T(Color(0.56,0.5,0.32))][rng.randi()%3]
	L.box(gras,P.call(0,-0.07,d*0.5),Vector3(w,0.16,d),hb,0.0)
	match typ:
		"holz":
			var hw=8.6
			var hx=-(w-hw)*0.5   # Haus links, Einfahrt rechts
			L.holz_ghetto=true
			L._holzhaus(P.call(hx,0,0),hw,aussen,[Color(0.55,0.62,0.64),Color(0.74,0.68,0.54),Color(0.6,0.64,0.52),Color(0.7,0.56,0.5),Color(0.62,0.58,0.66),Color(0.78,0.74,0.62),Color(0.5,0.55,0.6),Color(0.68,0.5,0.42)][rng.randi()%8])
			L.holz_ghetto=false
			# Verfall
			for sx in [-1,1]:
				var sb=Basis(-aussen*sx,Vector3.UP,rechts*sx)
				L.box(GL.T(Color(0.32,0.28,0.22)),P.call(hx+sx*4.33,0.9,9.0),Vector3(8.6,0.7,0.02),sb,0.0)
				if rng.randf()<0.55:GL.graffiti(P.call(hx+sx*4.36,rng.randf_range(1.9,2.8),rng.randf_range(6.5,11.5)),rechts*sx,rng.randf_range(0.6,0.85))
			if rng.randf()<0.35:
				var holz=GL.T(Color(0.5,0.38,0.24))
				for q in 3:L.box(holz,P.call(hx+[-2.75,2.75][rng.randi()%2],1.95+q*0.4,4.36),Vector3(1.2,0.22,0.04),hb*Basis(Vector3(0,0,1),rng.randf_range(-0.15,0.15)),0.012)
			if rng.randf()<0.5:L._sofa(P.call(hx-2.0,0.69,3.5),yaw)
			for q in rng.randi_range(0,2):GL.muellsack(P.call(hx+rng.randf_range(-3,3),0,rng.randf_range(1.2,3.2)))
			# Einfahrt + Garage/Schuppen hinten
			var ex=(w-3.4)*0.5
			L.box(GL.T(Color(0.42,0.4,0.37)),P.call(ex,0.012,min(d,22.0)*0.5),Vector3(3.2,0.02,min(d,22.0)),hb,0.0)
			if d>=22.0:
				if rng.randf()<0.7:GL.garage(P.call(ex,0,19.0),yaw)
				else:GL.huette(P.call(ex,0,19.0),3.6,4.0,2.3,yaw,[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4)][rng.randi()%2])
			elif rng.randf()<0.4:GL.auto_wrack(P.call(ex,0,9.0),yaw+rng.randf_range(-0.2,0.2))
			# Hinterhof
			if d>=26.0:
				var hof=P.call(hx,0,rng.randf_range(16.0,d-4.0));var x=rng.randf()
				if x<0.3:GL.auto_wrack(hof,yaw+PI*0.5+rng.randf_range(-0.3,0.3))
				elif x<0.55:
					L.zyl(L.M.metall,hof-rechts*3.0,hof-rechts*3.0+Vector3(0,2.0,0),0.04,1.2);L.zyl(L.M.metall,hof+rechts*3.0,hof+rechts*3.0+Vector3(0,2.0,0),0.04,1.2)
					L.zyl(L.M.linie,hof-rechts*3.0+Vector3(0,1.9,0),hof+rechts*3.0+Vector3(0,1.9,0),0.01,1.0)
					for q in 5:L.box(GL.T(GL.SPRAY[rng.randi()%GL.SPRAY.size()]),hof+rechts*(-2.4+q*1.2)+Vector3(0,1.55,0),Vector3(0.8,0.7,0.03),hb,0.012)
				elif x<0.7:
					L.zyl(GL.T(Color(0.3,0.6,0.9)),hof,hof+Vector3(0,0.5,0),1.4,1.05);L.zyl(GL.T(Color(0.45,0.7,0.6)),hof+Vector3(0,0.42,0),hof+Vector3(0,0.46,0),1.3)
				else:
					GL.reifen(hof,rng.randi_range(2,4));GL.muellsack(hof+rechts*1.5)
			_zaeune(P,w,d,hb,true,ex)
		"block":
			# Mietshaus (2–3 Stockwerke Backstein) mit Feuertreppe
			var hd=min(d-2.0,13.0)
			L._haus(P.call(0,0,0.8),w-0.6,hd,aussen,{"stock":rng.randi_range(2,4),"laden":rng.randf()<0.4})
			for q in rng.randi_range(1,2):GL.graffiti(P.call(rng.randf_range(-w*0.3,w*0.3),1.5,0.75),aussen,rng.randf_range(0.7,1.0))
			if d>hd+6:
				L.box(L.M.asphalt,P.call(0,0.01,(hd+1+d)*0.5),Vector3(w-1.0,0.02,d-hd-1.5),hb,0.0)
				L._container(P.call(-w*0.3,0,hd+3.0),yaw,Color(0.2,0.3,0.25))
				if rng.randf()<0.5:GL.auto_wrack(P.call(w*0.15,0,hd+5.5),yaw+PI*0.5)
			_zaeune(P,w,d,hb,false,0.0)
		"laden":
			GL.ecke_bau(P,w,min(d-1.0,12.0),aussen,yaw)
			if d>15:L.box(L.M.asphalt,P.call(0,0.01,(13.0+d)*0.5),Vector3(w-0.6,0.02,d-13.5),hb,0.0)
			_zaeune(P,w,d,hb,false,0.0)
		"kirche":
			var wand=L._shader(L.PUTZ,{"farbe":Color(0.92,0.9,0.84)})
			var c=P.call(0,0,14.0)
			L.box(wand,c+Vector3(0,3.5,0),Vector3(12,7,20),hb,0.05)
			var dach=GL.T(Color(0.45,0.3,0.25))
			for sx in [-1,1]:L.box(dach,c+rechts*sx*3.2+Vector3(0,8.6,0),Vector3(7.6,0.25,21),hb*Basis(Vector3(0,0,1),-sx*0.62),0.03)
			L.box(wand,P.call(0,6,4.0),Vector3(4,12,4),hb,0.05)
			L.hex(GL.T(Color(0.85,0.85,0.88)),[P.call(-2.1,12,1.9),P.call(2.1,12,1.9),P.call(2.1,12,6.1),P.call(-2.1,12,6.1),P.call(-0.05,17,3.95),P.call(0.05,17,3.95),P.call(0.05,17,4.05),P.call(-0.05,17,4.05)],0.04)
			L.box(L.M.holz,P.call(0,15.5,4.0),Vector3(0.15,2.0,0.15),hb,0.0);L.box(L.M.holz,P.call(0,15.9,4.0),Vector3(1.0,0.15,0.15),hb,0.0)
			L.box(GL.T(Color(0.35,0.22,0.15)),P.call(0,1.3,1.98),Vector3(1.8,2.6,0.05),hb,0.0)
			GL.label("GEMEINDE ZION",P.call(0,8.3,1.95),hb,0.007,Color(0.95,0.9,0.7),Color(0.1,0.08,0.05),3.6)
		"werbung":
			# Plakatwand auf Stelzen
			var pl=["RADEBERGER COLA","ELBQUELL","KAUF DIR EIN AUTO","PFANDHAUS","BROILER-BUDE","BÜRGERMEISTER WÄHLEN"]
			for sx in [-2.5,2.5]:L.zyl(L.M.metall,P.call(sx,0,3.0),P.call(sx,6.0,3.0),0.12,1.2)
			L.box(L.M.dunkel,P.call(0,7.0,3.0),Vector3(7.6,3.4,0.25),hb,0.04)
			L.box(GL.T(GL.SPRAY[rng.randi()%GL.SPRAY.size()]),P.call(0,7.0,2.85),Vector3(7.2,3.0,0.05),hb,0.0)
			GL.label(pl[rng.randi()%pl.size()],P.call(0,7.0,2.8),hb,0.016,Color(1,1,1),Color(0.08,0.08,0.1),6.6)
			if rng.randf()<0.5:GL.graffiti(P.call(0,1.2,3.0),aussen,0.7)
		"brache","schuppen":
			L.box(GL.T(Color(0.42,0.33,0.22)),P.call(0,0.02,d*0.5),Vector3(w-0.4,0.02,d-0.4),hb,0.0)
			if typ=="schuppen" or rng.randf()<0.6:
				GL.huette(P.call(0,0,min(d*0.5,6.0)),min(w-1.5,5.0),min(d-2.0,4.0),2.4,yaw+rng.randf_range(-0.2,0.2),[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4),Color(0.45,0.55,0.6)][rng.randi()%3])
			else:
				GL.reifen(P.call(rng.randf_range(-2,2),0,3.0),rng.randi_range(2,4))
				if rng.randf()<0.5:GL.auto_wrack(P.call(0,0,min(d-4,7.0)),yaw+rng.randf_range(0,PI))
			L._zaun(P.call(-w*0.5+0.2,0,0.15),P.call(w*0.5-0.2,0,0.15),1.6)
func _zaeune(P:Callable,w:float,d:float,hb:Basis,vorn:bool,ex:float):
	var farben=[Color(0.62,0.5,0.36),Color(0.8,0.78,0.72),Color(0.5,0.42,0.34)]
	if vorn:
		var a=P.call(-w*0.5+0.1,0,0.15);var e=P.call(ex-1.8,0,0.15)
		if rng.randf()<0.5:L._zaun(a,e,1.3)
		else:
			GL.holzzaun(a,e,1.2,farben[rng.randi()%3],0.28)
			if rng.randf()<0.5:GL.graffiti((a+e)*0.5+Vector3(0,0.62,0)-hb.z*(-0.04),hb.z,0.45)
	# Seiten + hinten: hoher Bretterzaun
	GL.holzzaun(P.call(-w*0.5+0.05,0,0.4),P.call(-w*0.5+0.05,0,d-0.1),1.8,Color(0.55,0.45,0.33),0.1)
	var h0=P.call(-w*0.5+0.05,0,d-0.1);var h1=P.call(w*0.5-0.05,0,d-0.1)
	GL.holzzaun(h0,h1,1.9,Color(0.5,0.42,0.33),0.08)

func naechst(p:Vector2)->Array:   # [Fußpunkt, Tangente, road_i, Abstand]
	var best=1e9;var res=[p,Vector2(1,0),-1,1e9];var k=Vector2i(int(floor(p.x/20.0)),int(floor(p.y/20.0)))
	for rad in [0,1,2]:
		for i in range(-rad,rad+1):
			for j in range(-rad,rad+1):
				for sg in SEG.get(k+Vector2i(i,j),[]):
					var r=ROADS[sg.x];var a:Vector2=r.P[sg.y];var b:Vector2=r.P[sg.y+1]
					var t=clamp((p-a).dot(b-a)/max((b-a).length_squared(),0.0001),0.0,1.0);var f=a.lerp(b,t)
					if p.distance_to(f)<best:best=p.distance_to(f);res=[f,(b-a).normalized(),sg.x,best]
		if res[2]>=0:break
	return res
var HAEUSER:=[]
func alt_haeuser():
	var d=JSON.parse_string(FileAccess.get_file_as_string("/home/claude/work/karte.json")) if HAEUSER.is_empty() else null
	if d!=null:
		for h in d.houses:HAEUSER.append(Vector2(h[1],h[2]))
	var n=0
	for p in HAEUSER:
		if not RECT.grow(-5).has_point(p) or _belegt(p):continue
		var aus=false
		for a in AUS:
			if a.has_point(p):aus=true
		if aus:continue
		var ns=naechst(p);if ns[2]<0:continue
		var f:Vector2=ns[0];var t:Vector2=ns[1];var nv:Vector2=(p-f).normalized()
		if nv.length()<0.5:continue
		var r=ROADS[ns[2]]
		# Vorderkante: entweder an der Straße (wenn nah) oder als Hinterhaus an der Hausposition
		var F=p-nv*7.0
		if ns[3]<r.w+r.sw+12.0:F=f+nv*(r.w+r.sw+0.3)
		if _belegt(F+nv*1.0):F=p-nv*4.0
		var x=rng.randf();var typ=["holz",12.0,16.0] if x<0.7 else (["block",rng.randf_range(14,20),14.0] if x<0.85 else ["brache",rng.randf_range(9,12),10.0])
		var tt=Vector2(-nv.y,nv.x)
		if not _rechteck_ok(F,tt,nv,typ[1],typ[2]):continue
		var dd:float=typ[2]
		while dd<24.0 and _rechteck_ok(F,tt,nv,typ[1],dd+2.0):dd+=2.0
		_belegen(F,tt,nv,typ[1],dd)
		LOTS.append({"F":F,"t":tt,"n":nv,"w":typ[1],"d":dd,"typ":typ[0],"r":ns[2]})
		parzelle(F,tt,nv,typ[1],dd,typ[0]);n+=1
	print("BEZIRK Häuser aus Originalkarte ",n)

# Restflächen (Ecken, Kurven-Innenseiten): Brache mit Maschendraht, Büschen, Müll
func luecken_fuellen():
	var n=0;var x=RECT.position.x+3.0
	while x<RECT.end.x:
		var z=RECT.position.y+3.0
		while z<RECT.end.y:
			var p=Vector2(x,z)
			var aus=false
			for a in AUS:
				if a.has_point(p):aus=true
			if not aus and not _belegt(p) and frei(p)>3.2:
				L.box(GL.T(Color(0.5,0.47,0.3)),Vector3(p.x,KB+0.004,p.y),Vector3(6.02,0.01,6.02),Basis(),0.0)
			if not aus and not _belegt(p) and frei(p)>0.5:
				var r=rng.randf()
				if r<0.25:L.kugel(L.M.laub[rng.randi()%3],Vector3(p.x,0.5,p.y),Vector3(1.2,0.9,1.2)*rng.randf_range(0.7,1.3))
				elif r<0.32:L._baum(Vector3(p.x,0.0,p.y))
				elif r<0.38:GL.muellsack(Vector3(p.x,0,p.y))
				elif r<0.4:GL.reifen(Vector3(p.x,0,p.y),rng.randi_range(1,3))
				n+=1
			z+=6.0
		x+=6.0

# Strommasten, Laternen
func strassenrand():
	for ri in ROADS.size():
		var r=ROADS[ri];if r.typ=="gasse":continue
		var s=10.0;var prev=null;var Lg:float=r.S[-1]
		while s<Lg-6.0:
			var b=bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var n=Vector2(-t.y,t.x)
			var q=p+n*(r.w+0.6)
			if frei(q,ri)>0.5 and not auf_fahrbahn(q,ri,1.0):
				var top=GL.mast(Vector3(q.x,KB,q.y))
				if prev!=null and top.distance_to(prev)<40.0:GL.kabel(prev,top,0.9)
				prev=top
			else:prev=null
			s+=30.0
