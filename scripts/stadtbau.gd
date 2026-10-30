extends RefCounted
# Stadtbau nach Blöcken: Straßen (Mittellinien) schneiden eine Fläche in Häuserblöcke. Jeder Block bekommt
# Gehweg mit Bordstein und wird am Rand lückenlos bebaut – auch an Kurven (Häuser folgen der Kurve stückweise).
# Ecken: Eckhäuser mit Fenstern auf BEIDEN Straßenseiten; spitze Ecken bekommen einen kleinen Platz.
# Dazu Kreuzungen mit Ampeln und Zebrastreifen, Durchgänge in Innenhöfe, Spielplatz, Sondergebäude (Waffenladen).
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
var fronten:={}
var meshes:={}
var rng:=RandomNumberGenerator.new()
var gehweg:=3.8
var bord_h:=0.15
var tiefe:=20.0
var b_deko:Batch
var log:=[]

func _init():
	var f=FileAccess.get_file_as_string("res://assets/daten/fronten.json")
	if f!="":fronten=JSON.parse_string(f)
	b_deko=Batch.new()

const TINTS=[Color(1,1,1),Color(1.0,0.92,0.82),Color(0.86,0.9,0.95),Color(0.97,0.86,0.82),Color(0.9,0.93,0.85),Color(0.92,0.85,0.75)]
# Häuser, die frei im Hof stehen dürfen (Fenster auf mehreren Seiten)
const MITTELHAUS=["cityscene2_01","cityscene2_02","cityscene2_07","cityscene2_11","stash","cityscene2_13","cityscene2_14"]   # nur Häuser mit Fassaden ringsum (Hofhäuser sieht man von allen Seiten)
const ACHSEN={"+z":Vector2(0,1),"-z":Vector2(0,-1),"+x":Vector2(1,0),"-x":Vector2(-1,0)}
func mesh(name:String)->Mesh:
	if not meshes.has(name):meshes[name]=load("res://assets/cache/geb/"+name+".res")
	return meshes[name]

# Maße eines Hauses, wenn die lokale Seite "vorn" zur Straße zeigt: [Breite entlang Straße, Tiefe]
func masse(name:String,vorn:String)->Vector2:
	var e=fronten[name]
	if vorn in ["+z","-z"]:return Vector2(e.b,e.t)
	return Vector2(e.t,e.b)

func _yaw(vorn:String,n:Vector2)->float:
	var fl=ACHSEN[vorn];return atan2(n.x,n.y)-atan2(fl.x,fl.y)

# welche lokale Seite zeigt nach Drehung in Weltrichtung d?
func _seite_in(yaw:float,d:Vector2)->String:
	var l=Vector2(d.x,d.y).rotated(yaw)   # Welt -> lokal (Drehung um -yaw im xz-Sinn)
	var lv=Basis(Vector3.UP,-yaw)*Vector3(d.x,0,d.y)
	var best="";var bd=-2.0
	for k in ACHSEN:
		var dd=ACHSEN[k].dot(Vector2(lv.x,lv.z))
		if dd>bd:bd=dd;best=k
	return best

var haus_cb:Callable    # Welt-Modus: Häuser als Platzierungsdaten statt Knoten
var baum_cb:Callable    # Welt-Modus: Bäume sammeln (MultiMesh)
var hoehe_cb:Callable   # Welt-Modus: Geländehöhe an einem Punkt
func haus(parent:Node3D,name:String,vorn:String,mitte:Vector2,n:Vector2,y:float,dehnung:=1.0):
	var e=fronten[name]
	if haus_cb.is_valid():
		var hy=hoehe_cb.call(mitte+n*(masse(name,vorn).y*0.5)) if hoehe_cb.is_valid() else y
		var ok=haus_cb.call(name,_yaw(vorn,n),mitte,hy,float(e.boden),dehnung,vorn in ["+z","-z"],masse(name,vorn),n)
		return true if ok==null else ok   # false: Welt hat den Platz abgelehnt (Straße, Laden …)
	# wie im Spiel: MultiMesh mit Instanzfarbe (Farbton + Verschmutzung je Haus)
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh(name);mm.instance_count=1
	var mi=MultiMeshInstance3D.new();mi.multimesh=mm;parent.add_child(mi)
	var t=TINTS[rng.randi()%TINTS.size()];var dreck=rng.randf_range(0.82,1.0)
	mm.set_instance_color(0,Color(t.r*dreck,t.g*dreck*0.98,t.b*dreck*0.95))
	mm.set_instance_transform(0,Transform3D())
	var sk=Vector3(dehnung,1,1) if vorn in ["+z","-z"] else Vector3(1,1,dehnung)   # nur entlang der Straße dehnen
	mi.transform=Transform3D(Basis(Vector3.UP,_yaw(vorn,n))*Basis.from_scale(sk),Vector3(mitte.x,y-float(e.boden)+0.02,mitte.y))
	return mi

func _ziehen(liste:Array)->String:
	var tot=0.0
	for e in liste:tot+=e[1]
	var x=rng.randf()*tot
	for e in liste:
		x-=e[1]
		if x<=0:return e[0]
	return liste[0][0]

# Reihenhaus wählen: Front = Hauptfront der Vorlage, passt in Tiefe und Platz
# Höhenklasse je Häuserzeile: ähnlich hohe Nachbarn, damit keine kahlen Seitenwände über niedrigen Häusern sichtbar werden
var hoehe:=Vector2(0,999)
func _passt_h(n:String)->bool:
	var h=float(fronten[n].h);return h>=hoehe.x and h<=hoehe.y
func _reihe(liste:Array,platz:float)->Array:
	for k in 60:
		var n=_ziehen(liste);var v=fronten[n].vorn;var m=masse(n,v)
		if m.y<=tiefe and m.x<=platz and _passt_h(n):return [n,v,m]
	var best=[];var bm=INF
	for e in liste:
		var v=fronten[e[0]].vorn;var m=masse(e[0],v)
		if m.y<=tiefe and m.x<=platz and m.x<bm and _passt_h(e[0]):bm=m.x;best=[e[0],v,m]
	return best

# Eckhaus wählen: eine detaillierte Seite zur Straße (n), eine weitere detaillierte Seite in Richtung "offen"
func _eckhaus(liste:Array,n:Vector2,offen:Vector2,platz:float)->Array:
	for k in 80:
		var name=_ziehen(liste);var seiten:Array=fronten[name].seiten
		if not _passt_h(name) and k<60:continue
		for vorn in seiten:
			var yaw=_yaw(vorn,n)
			if _seite_in(yaw,offen) in seiten:
				var m=masse(name,vorn)
				if m.y<=tiefe+1.0 and m.x<=platz:return [name,vorn,m]
	return []

# ---------------- Straßen ----------------
# strassen: [{p:PackedVector2Array, w:Breite der Fahrbahn}]
func bloecke(flaeche:PackedVector2Array,strassen:Array)->Array:
	var teile=[flaeche]
	for s in strassen:
		var band=Geometry2D.offset_polyline(s.p,s.w*0.5,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
		for bp in band:
			var neu=[]
			for t in teile:
				for r in Geometry2D.clip_polygons(t,bp):
					if not Geometry2D.is_polygon_clockwise(r):neu.append(r)
			teile=neu
	var out=[]
	for t in teile:
		var a=_flaeche(t)
		if a>400.0:out.append(_vereinfachen(t,0.6))
	return out

func _flaeche(p:PackedVector2Array)->float:
	var a=0.0
	for i in p.size():a+=p[i].cross(p[(i+1)%p.size()])
	return abs(a)*0.5

func _vereinfachen(p:PackedVector2Array,tol:float)->PackedVector2Array:
	var out=PackedVector2Array()
	for i in p.size():
		var a=p[(i-1+p.size())%p.size()];var b=p[i];var c=p[(i+1)%p.size()]
		var d=Geometry2D.get_closest_point_to_segment(b,a,c).distance_to(b)
		if d>tol*0.15 or a.distance_to(b)>25.0:out.append(b)
	return out

func kreuzungen(strassen:Array)->Array:
	var pts=[]
	for i in strassen.size():
		for j in range(i+1,strassen.size()):
			var A=strassen[i].p;var B=strassen[j].p
			for a in A.size()-1:
				for b in B.size()-1:
					var x=Geometry2D.segment_intersects_segment(A[a],A[a+1],B[b],B[b+1])
					if x!=null:
						var neu=true
						for q in pts:if q.p.distance_to(x)<8.0:neu=false
						if neu:pts.append({"p":x,"r":[i,j]})
	return pts

func fahrbahn(parent:Node3D,flaeche:PackedVector2Array,strassen:Array,kreuz:Array):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in Geometry2D.triangulate_polygon(flaeche):
		st.set_normal(Vector3.UP);st.set_uv(flaeche[k]*0.12);st.add_vertex(Vector3(flaeche[k].x,0,flaeche[k].y))
	var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=Mats.pbr("asphalt",0.12,Color(0.6,0.6,0.62));parent.add_child(mi)
	var weiss=Mats.flat(Color(0.93,0.93,0.9),0.6)
	# Mittellinien (gestrichelt), nicht in Kreuzungen
	for s in strassen:
		var P:PackedVector2Array=s.p
		var L=0.0
		for i in P.size()-1:
			var a=P[i];var c=P[i+1];var seg=a.distance_to(c);var t=(c-a)/seg
			var u=fmod(L,6.0);var pos=-u
			while pos<seg:
				var p0=pos;var p1=min(pos+3.0,seg)
				if p0>=0 and p1>p0:
					var m=a+t*((p0+p1)*0.5)
					var nah=false
					for k in kreuz:if k.p.distance_to(m)<s.w*0.5+gehweg+3.0:nah=true
					if not nah:b_deko.box_rot(weiss,Vector3(m.x,0.012,m.y),Vector3(0.15,0.02,p1-p0),Basis(Vector3.UP,atan2(t.x,t.y)))
				pos+=6.0
			L+=seg
	# Zebrastreifen und Haltelinien an jedem Kreuzungsarm, Ampeln an den Ecken
	for k in kreuz:
		for ri in k.r:
			var s=strassen[ri];var P:PackedVector2Array=s.p
			for richtung in [-1,1]:
				var arm=_arm(P,k.p,richtung,s.w*0.5+gehweg+4.0)
				if arm==null:continue
				var t:Vector2=arm[1];var mp:Vector2=arm[0];var nn=Vector2(-t.y,t.x)
				var breite=s.w
				var n_streifen=int(breite/1.0)
				for q in n_streifen:
					var off=-breite*0.5+0.5+q*1.0
					var c=mp+nn*off
					b_deko.box_rot(weiss,Vector3(c.x,0.013,c.y),Vector3(0.5,0.02,3.0),Basis(Vector3.UP,atan2(t.x,t.y)))
				var hl=mp+t*2.6+nn*(breite*0.25)
				b_deko.box_rot(weiss,Vector3(hl.x,0.013,hl.y),Vector3(breite*0.5,0.02,0.35),Basis(Vector3.UP,atan2(t.x,t.y)))
				# Ampel rechts vom ankommenden Verkehr
				var ap=mp+t*3.5+nn*(breite*0.5+1.0)
				ampel(parent,ap,-t,richtung>0)

# Punkt auf der Straße im Abstand d von der Kreuzung (in Laufrichtung), dazu die Richtung zur Kreuzung hin
func _arm(P:PackedVector2Array,x:Vector2,richtung:int,d:float):
	# nächster Punkt der Linie zur Kreuzung
	var best=0;var bd=INF;var bs=0.0;var L=0.0;var ls=[0.0]
	for i in P.size()-1:L+=P[i].distance_to(P[i+1]);ls.append(L)
	for i in P.size()-1:
		var q=Geometry2D.get_closest_point_to_segment(x,P[i],P[i+1]);var dd=q.distance_to(x)
		if dd<bd:bd=dd;best=i;bs=ls[i]+P[i].distance_to(q)
	var s=bs+richtung*d
	if s<0 or s>L:return null
	var p=_bei(P,ls,s);var p2=_bei(P,ls,s-richtung*1.0)
	return [p,(p2-p).normalized()]

func _bei(P:PackedVector2Array,ls:Array,s:float)->Vector2:
	for i in P.size()-1:
		if s<=ls[i+1]:return P[i].lerp(P[i+1],(s-ls[i])/max(ls[i+1]-ls[i],0.001))
	return P[P.size()-1]

var _ampel_mats=null
func ampel(parent:Node3D,p:Vector2,blick:Vector2,gruen:bool):
	if _ampel_mats==null:
		_ampel_mats={"mast":Mats.flat(Color(0.18,0.19,0.2),0.4,0.7),"kasten":Mats.flat(Color(0.05,0.05,0.05),0.5,0.2),
			"rot":Mats.emissive(Color(1,0.1,0.05),3.0),"gelb":Mats.emissive(Color(1,0.7,0.1),0.4),"gruen":Mats.emissive(Color(0.1,1,0.3),3.0),"aus":Mats.flat(Color(0.12,0.12,0.12),0.3)}
	var M=_ampel_mats
	var yaw=atan2(blick.x,blick.y)
	var xf=Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,bord_h,p.y))
	b_deko.cyl(M.mast,Vector3(0,2.0,0),0.08,4.0,xf)
	b_deko.box(M.kasten,Vector3(-0.2,2.6,-0.12),Vector3(0.2,3.7,0.12),xf)
	b_deko.cyl(M.rot if not gruen else M.aus,Vector3(0,3.5,0.13),0.12,0.04,xf,Basis(Vector3(1,0,0),PI*0.5))
	b_deko.cyl(M.aus,Vector3(0,3.15,0.13),0.12,0.04,xf,Basis(Vector3(1,0,0),PI*0.5))
	b_deko.cyl(M.gruen if gruen else M.aus,Vector3(0,2.8,0.13),0.12,0.04,xf,Basis(Vector3(1,0,0),PI*0.5))
	# Fußgängerampel-Knopf
	b_deko.box(M.kasten,Vector3(-0.08,1.0,-0.2),Vector3(0.08,1.25,-0.08),xf)

# ---------------- Block ----------------
# opt: {liste, eck, durchgang:bool, sonder:[{breite,tiefe,bau:Callable}], spielplatz:bool}
func block(parent:Node3D,poly:PackedVector2Array,y:float,opt:Dictionary)->Dictionary:
	var gy=y+bord_h
	var innenring=opt.get("innenring",false)
	if innenring:return _block_haeuser(parent,poly,poly,gy,opt)
	if opt.get("ohne_gehweg",false):
		if opt.get("hofboden",true):
			var hs0=SurfaceTool.new();hs0.begin(Mesh.PRIMITIVE_TRIANGLES)
			for k in Geometry2D.triangulate_polygon(poly):
				var v=poly[k];hs0.set_normal(Vector3.UP);hs0.set_uv(v*0.25);hs0.add_vertex(Vector3(v.x,gy+0.04,v.y))
			var hm0=MeshInstance3D.new();hm0.mesh=hs0.commit();parent.add_child(hm0);hm0.material_override=Mats.pbr("asphalt",0.15,Color(0.55,0.55,0.56))
			hm0.visibility_range_end=600.0
		return _block_haeuser(parent,poly,poly,gy,opt)
	# Gehweg (ganze Blockfläche) + Bordsteinkante
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in Geometry2D.triangulate_polygon(poly):
		st.set_normal(Vector3.UP);st.set_uv(poly[k]*0.5);st.add_vertex(Vector3(poly[k].x,gy,poly[k].y))
	var n_p=poly.size()
	for i in n_p:
		var a=poly[i];var c=poly[(i+1)%n_p];var nn=_aussen(poly,a,c)
		var q=[Vector3(a.x,-0.3,a.y),Vector3(c.x,-0.3,c.y),Vector3(c.x,gy,c.y),Vector3(a.x,gy,a.y)]
		for j in [0,2,1,0,3,2]:st.set_normal(Vector3(nn.x,0,nn.y));st.set_uv(Vector2(q[j].x+q[j].z,q[j].y)*0.5);st.add_vertex(q[j])
	var gm=MeshInstance3D.new();gm.mesh=st.commit();gm.material_override=Mats.pbr("pavers",0.45,Color(0.86,0.84,0.8));parent.add_child(gm)
	var innen_l=Geometry2D.offset_polygon(poly,-gehweg)
	if innen_l.is_empty():log.append("Block ohne Innenfläche");return {}
	var innen:PackedVector2Array=innen_l[0]
	# Hof-Boden: ganze Fläche hinter der Bauflucht (Häuser stehen darauf); Art je nach Hoftyp
	var hoftyp:String=opt.get("hof","hinterhof")
	var hs=SurfaceTool.new();hs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in Geometry2D.triangulate_polygon(innen):
		var v=innen[k];hs.set_normal(Vector3.UP);hs.set_uv(v*0.25);hs.add_vertex(Vector3(v.x,gy+0.006,v.y))
	var hm=MeshInstance3D.new();hm.mesh=hs.commit();parent.add_child(hm)
	hm.material_override=Mats.pbr("grass",0.25,Color(0.75,0.85,0.7)) if hoftyp=="gruen" else Mats.pbr("asphalt",0.15,Color(0.55,0.55,0.56))
	return _block_haeuser(parent,poly,innen,gy,opt)

func _block_haeuser(parent:Node3D,poly:PackedVector2Array,innen:PackedVector2Array,gy:float,opt:Dictionary)->Dictionary:
	var hoftyp:String=opt.get("hof","hinterhof")
	# Läufe zwischen echten Ecken (Knick > 40°)
	var n=innen.size();var ecken=[]
	for i in n:
		var a=innen[(i-1+n)%n];var b=innen[i];var c=innen[(i+1)%n]
		var w=_innenwinkel(innen,a,b,c)
		if w<140.0:ecken.append([i,w])
	if ecken.is_empty():ecken=[[0,180.0]]
	var laeufe=[]
	for e in ecken.size():
		var i0=ecken[e][0];var i1=ecken[(e+1)%ecken.size()][0]
		var pts=PackedVector2Array();var i=i0
		while true:
			pts.append(innen[i])
			if i==i1 and pts.size()>1:break
			i=(i+1)%n
			if pts.size()>n+1:break
		laeufe.append({"p":pts,"w0":ecken[e][1],"w1":ecken[(e+1)%ecken.size()][1]})
	# längster Lauf bekommt Durchgang / Sondergebäude
	var laengster=0;var lmax=0.0
	for li in laeufe.size():
		var L=_laenge(laeufe[li].p)
		if L>lmax:lmax=L;laengster=li
	var anzahl_haeuser=0;var tiefen=[];var fussabdruecke=[]
	var ergebnis={"durchgang":[],"hof":PackedVector2Array(),"typ":hoftyp}
	# gegenüberliegender Lauf (für Gassen quer durch den Block)
	var gegen=-1
	if hoftyp=="gasse":
		var mL=_mitte(laeufe[laengster].p);var bd=0.0
		for li in laeufe.size():
			if li==laengster:continue
			var d=_mitte(laeufe[li].p).distance_to(mL)
			if d>bd:bd=d;gegen=li
	var gasse_b={"gruen":3.0,"hinterhof":4.4,"gasse":2.8}.get(hoftyp,3.0)
	# Eckhäuser vorab wählen, damit jeder Lauf genau so viel Platz frei lässt, wie das nächste Eckhaus tief ist
	var eck_vorab=[]
	for li in laeufe.size():
		var Pq:PackedVector2Array=laeufe[li].p
		if laeufe[li].w0<140.0 and laeufe[li].w0>=70.0 and Pq.size()>1:
			var lsq=[0.0];var acq=0.0
			for i in Pq.size()-1:acq+=Pq[i].distance_to(Pq[i+1]);lsq.append(acq)
			var tq=(Pq[1]-Pq[0]).normalized()
			eck_vorab.append(_eckhaus(opt.eck+opt.liste,_aussen_lauf(innen,Pq,lsq,0.0),-tq,_laenge(Pq)*0.5))
		else:eck_vorab.append([])
	for li in laeufe.size():
		var lauf=laeufe[li]
		var P:PackedVector2Array=lauf.p;var L=_laenge(P)
		var ls=[0.0];var acc=0.0
		for i in P.size()-1:acc+=P[i].distance_to(P[i+1]);ls.append(acc)
		var w0=lauf.w0;var w1=lauf.w1
		var platz0=w0<70.0;var platz1=w1<70.0
		var start=tiefe/tan(deg_to_rad(w0)*0.5) if platz0 else 0.0
		var naechstes=eck_vorab[(li+1)%laeufe.size()]
		var ende=L
		if platz1:ende=L-tiefe/tan(deg_to_rad(w1)*0.5)
		elif w1<140.0:ende=L-(naechstes[2].y+0.05 if not naechstes.is_empty() else tiefe)
		if platz0:_platz(parent,P,ls,0.0,start,gy)
		var pos=start
		var gap0=-1.0;var gap1=-1.0
		if (li==laengster and opt.get("durchgang",true)) or li==gegen:gap0=L*0.5-gasse_b*0.5;gap1=L*0.5+gasse_b*0.5
		# freizuhaltende Wege (Durchgänge der äußeren Häuserreihe) kreuzen diesen Lauf?
		for fr in opt.get("frei",[]):
			var a0:Vector2=fr.p+fr.n*1.0;var a1:Vector2=fr.p-fr.n*80.0
			for i in P.size()-1:
				var x=Geometry2D.segment_intersects_segment(a0,a1,P[i],P[i+1])
				if x!=null:
					var sx=ls[i]+P[i].distance_to(x)
					gap0=max(0.5,sx-gasse_b*0.5-0.5);gap1=sx+gasse_b*0.5+0.5;break
		var sonder:Array=opt.get("sonder",[]) if li==(laengster+1)%laeufe.size() else []
		var erster=true
		var plan=[]
		var klassen:Array=opt.get("hoehen",[Vector2(0,999)])
		hoehe=klassen[rng.randi()%klassen.size()]
		while pos<ende-2.0:
			if gap0>0 and pos+0.5>=gap0 and pos<gap1:pos=gap1;continue
			var platz_rest=(gap0 if (gap0>0 and pos<gap0) else ende)-pos
			var wahl=[]
			if erster and not platz0 and w0<140.0:
				wahl=eck_vorab[li] if not eck_vorab[li].is_empty() and eck_vorab[li][2].x<=platz_rest else []
			if wahl.is_empty() and not sonder.is_empty() and pos>L*0.3:
				var sd=sonder.pop_front()
				if sd.breite<=platz_rest:wahl=["@sonder",sd,Vector2(sd.breite,sd.tiefe)]
			if wahl.is_empty():wahl=_reihe(opt.liste,platz_rest)
			if wahl.is_empty():
				var h_alt=hoehe;hoehe=Vector2(0,999);wahl=_reihe(opt.liste+opt.eck,platz_rest);hoehe=h_alt
			if wahl.is_empty():
				if gap0>0 and pos<gap0:pos=gap1;continue   # Rest vor dem Durchgang wird Mauer, danach weiter bauen
				break
			plan.append([wahl,pos]);pos+=wahl[2].x+0.05;erster=false
		# letztes Haus vor einem Platz an der Ecke: Eckhaus mit offener Seite nach vorn
		if platz1 and plan.size()>0:
			var lp=plan[plan.size()-1];var s0=lp[1]
			var t1=(_bei(P,ls,min(s0+1.0,L))-_bei(P,ls,s0)).normalized()
			var w2=_eckhaus(opt.eck+opt.liste,_aussen_lauf(innen,P,ls,s0),t1,lp[0][2].x+2.0)
			if not w2.is_empty():plan[plan.size()-1]=[w2,s0]
		# Restlücke schließen: Häuser entlang der Straße leicht dehnen (höchstens 20 %), sonst Lücke am Ende
		var dehn=1.0
		if gap0<0 and plan.size()>0:
			var summe=0.0
			for e in plan:summe+=e[0][2].x+0.05
			dehn=clamp((ende-start)/max(summe,1.0),1.0,1.2)
			var lauf_s=start
			for e in plan:e[1]=lauf_s;lauf_s+=(e[0][2].x+0.05)*dehn
		var abgelehnt_k={}
		for k in plan.size():
			var wahl=plan[k][0];var s=plan[k][1]
			var wbreite=wahl[2].x*dehn
			var p0=_bei(P,ls,s);var p1=_bei(P,ls,min(s+wbreite,L))
			var tt=(p1-p0).normalized();if tt.length()<0.5:continue
			var nn=_aussen_lauf(innen,P,ls,s+wbreite*0.5)
			# Haus an der Sehne ausrichten
			var ns=Vector2(-tt.y,tt.x);if ns.dot(nn)<0:ns=-ns
			var mitte=(p0+p1)*0.5-ns*(wahl[2].y*0.5)
			var tq=Vector2(ns.y,-ns.x)*(wbreite*0.5+0.3);var dq=ns*(wahl[2].y*0.5+1.5)
			if wahl[0]!="@sonder" and haus_cb.is_valid():
				if not haus(parent,wahl[0],wahl[1],mitte,ns,gy,dehn):
					# Platz nicht frei (meist ragt das Haus hinten in eine Straße): flachere Häuser gleicher Breite versuchen
					var ersatz=false
					var kand=(opt.liste+opt.eck).duplicate();kand.shuffle()
					for e2 in kand:
						var n2=e2[0]
						if not fronten.has(n2):continue
						var v2=fronten[n2].vorn;var m2=masse(n2,v2)
						if m2.x>wbreite+0.5 or m2.x<wbreite/1.25 or m2.y>=wahl[2].y-2.0:continue
						var mitte2=(p0+p1)*0.5-ns*(m2.y*0.5)
						if haus(parent,n2,v2,mitte2,ns,gy,clamp(wbreite/m2.x,1.0,1.2)):
							ersatz=true;wahl=[n2,v2,m2];mitte=mitte2;dq=ns*(m2.y*0.5+1.5);break
					if not ersatz:abgelehnt_k[k]=true;continue
				fussabdruecke.append(PackedVector2Array([mitte-tq-dq,mitte+tq-dq,mitte+tq+dq,mitte-tq+dq]))
				anzahl_haeuser+=1;tiefen.append(wahl[2].y);continue
			fussabdruecke.append(PackedVector2Array([mitte-tq-dq,mitte+tq-dq,mitte+tq+dq,mitte-tq+dq]))
			if wahl[0]=="@sonder":
				var node=wahl[1].bau.call()
				parent.add_child(node);node.transform=Transform3D(Basis(Vector3.UP,atan2(ns.x,ns.y)),Vector3(mitte.x,gy,mitte.y))
				log.append("Sonderbau bei "+str(mitte))
			else:
				haus(parent,wahl[0],wahl[1],mitte,ns,gy,dehn)
			anzahl_haeuser+=1;tiefen.append(wahl[2].y)
		if not opt.get("innenring",false):log.append("Lauf L=%.1f start=%.1f ende=%.1f häuser=%d w0=%d w1=%d"%[L,start,ende,plan.size(),int(w0),int(w1)])
		# unbebaute Stücke der Bauflucht mit Ziegelmauer schließen (mit Tor oder Geldautomat)
		var belegt_s=[]
		for k in plan.size():
			if not abgelehnt_k.has(k):belegt_s.append([plan[k][1],plan[k][1]+plan[k][0][2].x*dehn])
		if gap0>0:belegt_s.append([gap0,gap1])
		belegt_s.sort_custom(func(x,y):return x[0]<y[0])
		var cur=start
		for iv in belegt_s+[[ende,ende]]:
			if iv[0]-cur>1.5:mauer(parent,P,ls,cur,iv[0],innen,gy,not opt.get("innenring",false))
			cur=max(cur,iv[1])
		if gap0>0:
			var m=_bei(P,ls,(gap0+gap1)*0.5);var nn=_aussen_lauf(innen,P,ls,(gap0+gap1)*0.5)
			ergebnis.durchgang.append({"p":m,"n":nn})
	tiefen.sort()
	var dmax=tiefen[tiefen.size()/2] if tiefen.size()>0 else 8.0   # typische Haustiefe; tiefere Häuser werden ausgeschnitten
	var deko_l=_ausschneiden(Geometry2D.offset_polygon(innen,-dmax-1.0),fussabdruecke)
	if deko_l.size()>0:ergebnis.hof=deko_l
	# großer Innenbereich: zweite Häuserreihe (Hinterhäuser) mit schmaler Gasse dazwischen, Hof wird kleiner
	if not opt.get("innenring",false):
		var ring_p=_ausschneiden(Geometry2D.offset_polygon(innen,-dmax-3.0),fussabdruecke)
		var ring_l=[ring_p] if ring_p.size()>=3 else []
		log.append("Ring? %s Fläche %d dmax %.1f"%[hoftyp,int(_flaeche(ring_l[0])) if ring_l.size()>0 else -1,dmax])
		if ring_l.size()>0 and _flaeche(ring_l[0])>opt.get("ring_ab",350.0):
			var o2=opt.duplicate();o2.innenring=true;o2.erase("sonder")
			o2.liste=opt.get("liste_hinten",opt.liste);o2.eck=o2.liste
			o2.durchgang=false;o2.frei=ergebnis.durchgang.duplicate()
			var e2=_block_haeuser(parent,ring_l[0],ring_l[0],gy,o2)
			if e2.hof.size()>=3:ergebnis.hof=e2.hof
			ergebnis.durchgang.append_array(e2.durchgang)
			ergebnis["ring"]=ring_l[0]
	# Wege durch Durchgänge: schmal, Beton; bei Gassen quer durch den Block
	var beton=Mats.pbr("concrete",0.35,Color(0.7,0.69,0.66))
	var hm2=_mitte(innen)
	for d in ergebnis.durchgang:
		var a:Vector2=d.p+d.n*0.2;var ziel=d.p-d.n*(dmax+4.0)
		_weg(a,ziel,gasse_b,gy,beton)
	log.append("Block %d Ecken, %d Läufe, %d Häuser, Fläche %d"%[poly.size(),laeufe.size(),anzahl_haeuser,int(_flaeche(poly))])
	return ergebnis

# größtes Stück einer Fläche, nachdem die Grundrisse der Häuser herausgeschnitten wurden
func _ausschneiden(polys:Array,fuss:Array)->PackedVector2Array:
	if polys.is_empty():return PackedVector2Array()
	var teile=[polys[0]]
	for f in fuss:
		var neu=[]
		for t in teile:
			for r in Geometry2D.clip_polygons(t,f):
				if not Geometry2D.is_polygon_clockwise(r):neu.append(r)
		teile=neu
	var best=PackedVector2Array();var ba=0.0
	for t in teile:
		var a=_flaeche(t)
		if a>ba:ba=a;best=t
	# glätten (kleine Zacken weg)
	var g=Geometry2D.offset_polygon(best,-1.0)
	if g.size()>0:g=Geometry2D.offset_polygon(g[0],1.0)
	return g[0] if g.size()>0 else best

func _mitte(P:PackedVector2Array)->Vector2:
	var c=Vector2.ZERO
	for v in P:c+=v
	return c/max(P.size(),1)

func _weg(a:Vector2,b:Vector2,breite:float,gy:float,m:Material):
	var d=b-a;var L=d.length();if L<0.5:return
	var mid=(a+b)*0.5
	b_deko.box_rot(m,Vector3(mid.x,gy+0.02,mid.y),Vector3(breite,0.03,L),Basis(Vector3.UP,atan2(d.x,d.y)))

func _laenge(P:PackedVector2Array)->float:
	var L=0.0
	for i in P.size()-1:L+=P[i].distance_to(P[i+1])
	return L

func _innenwinkel(poly:PackedVector2Array,a:Vector2,b:Vector2,c:Vector2)->float:
	var v1=(a-b).normalized();var v2=(c-b).normalized()
	var w=rad_to_deg(acos(clamp(v1.dot(v2),-1.0,1.0)))
	# konkave Ecke (nach innen) -> >180
	var m=b+(v1+v2).normalized()*0.5 if (v1+v2).length()>0.01 else b
	if not Geometry2D.is_point_in_polygon(m,poly):w=360.0-w
	return w

func _aussen(poly:PackedVector2Array,a:Vector2,c:Vector2)->Vector2:
	var t=(c-a).normalized();var nn=Vector2(t.y,-t.x)
	if Geometry2D.is_point_in_polygon((a+c)*0.5+nn*0.3,poly):nn=-nn
	return nn

func _aussen_lauf(poly:PackedVector2Array,P:PackedVector2Array,ls:Array,s:float)->Vector2:
	var a=_bei(P,ls,max(s-1.0,0.0));var c=_bei(P,ls,min(s+1.0,ls[ls.size()-1]))
	return _aussen(poly,a,c)

# kleiner Platz an spitzer Ecke: Pflaster, Baum, Bänke
func _platz(parent:Node3D,P:PackedVector2Array,ls:Array,s0:float,s1:float,gy:float):
	var holz=Mats.flat(Color(0.42,0.27,0.15),0.7);var eisen=Mats.flat(Color(0.15,0.15,0.16),0.5,0.6)
	for k in 2:
		var s=s1*(0.35+0.4*k)
		var m=_bei(P,ls,s);var t=(_bei(P,ls,s+1.0)-m).normalized();var nn=Vector2(-t.y,t.x)
		var q=m-nn*0.0
		if baum_platz:baum_setzen(parent,baum_platz,q+t*1.8,gy,0.75)
		var xf=Transform3D(Basis(Vector3.UP,atan2(t.x,t.y)+PI*0.5),Vector3(q.x,gy,q.y)-Vector3(t.x,0,t.y)*0.6)
		_bank(xf,holz,eisen)
	log.append("Platz an spitzer Ecke "+str(_bei(P,ls,s1*0.5)))

var baum_platz:Mesh
func _bank(xf:Transform3D,holz:Material,eisen:Material):
	b_deko.box(holz,Vector3(-1.0,0.42,-0.25),Vector3(1.0,0.48,0.25),xf);b_deko.box(holz,Vector3(-1.0,0.55,0.22),Vector3(1.0,0.95,0.28),xf)
	for sx in [-0.85,0.85]:b_deko.box(eisen,Vector3(sx-0.04,0,-0.22),Vector3(sx+0.04,0.95,0.26),xf)

# Baum auf runder Baumscheibe (Erde) mit Steinkranz
var _erde:Material;var _stein:Material
func baum_setzen(parent:Node3D,baum:Mesh,p:Vector2,gy:float,sk:float):
	if baum_cb.is_valid():
		if hoehe_cb.is_valid():gy=hoehe_cb.call(p)
		baum_cb.call(p,gy,sk)
	elif baum==null:return
	if _erde==null:_erde=Mats.pbr("forest",0.6,Color(0.45,0.35,0.25));_stein=Mats.flat(Color(0.62,0.6,0.57),0.85)
	var xf=Transform3D(Basis(),Vector3(p.x,gy,p.y))
	b_deko.cyl(_erde,Vector3(0,0.02,0),1.05,0.04,xf)
	var n=14
	for k in n:
		var a=TAU*k/n
		b_deko.box_rot(_stein,Vector3(cos(a)*1.15,0.06,sin(a)*1.15),Vector3(0.22,0.14,0.5),Basis(Vector3.UP,-a),xf)
	if baum_cb.is_valid():return
	var bm=MeshInstance3D.new();bm.mesh=baum;parent.add_child(bm);bm.position=Vector3(p.x,gy+0.03,p.y);bm.scale=Vector3.ONE*sk;bm.rotation.y=rng.randf()*TAU

# Ziegelmauer entlang der Bauflucht von s0 bis s1; Tor in der Mitte oder Geldautomat an der Straßenseite
var _ziegel:Material
func mauer(parent:Node3D,P:PackedVector2Array,ls:Array,s0:float,s1:float,poly:PackedVector2Array,gy:float,strasse:=true):
	if _ziegel==null:_ziegel=Mats.bricks(0.45)
	var abdeck=Mats.flat(Color(0.55,0.53,0.5),0.8);var tor=Mats.flat(Color(0.18,0.2,0.22),0.5,0.6)
	var a=_bei(P,ls,s0);var c=_bei(P,ls,s1);var L=a.distance_to(c);if L<0.5:return
	var t=(c-a)/L;var nn=_aussen(poly,a,c)
	var h=rng.randf_range(2.4,3.2)
	var xf=Transform3D(Basis(Vector3.UP,atan2(t.x,t.y)),Vector3((a.x+c.x)*0.5,gy,(a.y+c.y)*0.5)-Vector3(nn.x,0,nn.y)*0.2)
	var mit_tor=L>5.0 and rng.randf()<0.6
	if mit_tor:
		var tb=min(3.2,L-1.0)
		for seite in [-1,1]:
			var z0=-L*0.5 if seite<0 else tb*0.5;var z1=-tb*0.5 if seite<0 else L*0.5
			b_deko.box(_ziegel,Vector3(-0.15,0,z0),Vector3(0.15,h,z1),xf);b_deko.box(abdeck,Vector3(-0.2,h,z0),Vector3(0.2,h+0.1,z1),xf)
		b_deko.box(tor,Vector3(-0.04,0.05,-tb*0.5),Vector3(0.04,h-0.3,tb*0.5),xf)
		for k in int(tb/0.25):b_deko.box(tor,Vector3(-0.06,0.05,-tb*0.5+k*0.25),Vector3(0.06,h-0.2,-tb*0.5+k*0.25+0.04),xf)
	else:
		b_deko.box(_ziegel,Vector3(-0.15,0,-L*0.5),Vector3(0.15,h,L*0.5),xf);b_deko.box(abdeck,Vector3(-0.2,h,-L*0.5),Vector3(0.2,h+0.1,L*0.5),xf)
		if strasse and L>2.0 and rng.randf()<0.3:geldautomat(parent,xf*Vector3(0,0,0)+Vector3(nn.x,0,nn.y)*0.15,nn)
	log.append("Mauer %.1f m%s %s"%[L," mit Tor" if mit_tor else "","Straße" if strasse else "innen"])

# Geldautomat in eine Wand gesetzt (Front nach n); Knoten in Gruppe "geldautomat" -> im Spiel Geld abheben
func geldautomat(parent:Node3D,p:Vector3,n:Vector2):
	var g=Node3D.new();g.name="Geldautomat";g.add_to_group("geldautomat");parent.add_child(g)
	g.transform=Transform3D(Basis(Vector3.UP,atan2(n.x,n.y)),p)
	var b=b_deko;var xf=g.transform
	b.box(Mats.flat(Color(0.75,0.76,0.78),0.4,0.6),Vector3(-0.55,0.0,-0.05),Vector3(0.55,2.1,0.35),xf)
	b.box(Mats.flat(Color(0.1,0.25,0.55),0.4),Vector3(-0.55,1.75,0.35),Vector3(0.55,2.1,0.42),xf)
	b.box(Mats.emissive(Color(0.35,0.6,1.0),1.5),Vector3(-0.28,1.15,0.33),Vector3(0.28,1.5,0.36),xf)
	b.box(Mats.flat(Color(0.15,0.15,0.16),0.5),Vector3(-0.3,0.95,0.33),Vector3(0.3,1.1,0.45),xf)
	b.box(Mats.flat(Color(0.1,0.1,0.1),0.4),Vector3(-0.12,0.75,0.35),Vector3(0.12,0.8,0.38),xf)
	var lb=Label3D.new();lb.text="GELD";lb.font_size=64;lb.pixel_size=0.006;lb.modulate=Color(1,1,1);g.add_child(lb);lb.position=Vector3(0,1.93,0.43)
	log.append("Geldautomat bei "+str(Vector2(p.x,p.z)))

# Geländer am Gehweg (an der Bordsteinkante), Länge L ab a in Richtung t
func gelaender(a:Vector2,t:Vector2,L:float,gy:float):
	var eisen=Mats.flat(Color(0.2,0.3,0.25),0.45,0.6)
	var xf=Transform3D(Basis(Vector3.UP,atan2(t.x,t.y)),Vector3(a.x,gy,a.y))
	var k=0.0
	while k<=L:
		b_deko.box(eisen,Vector3(-0.03,0,k-0.03),Vector3(0.03,1.0,k+0.03),xf);k+=1.5
	for y in [0.45,0.95]:b_deko.box(eisen,Vector3(-0.025,y,0),Vector3(0.025,y+0.05,L),xf)

# ---------------- Spielplatz ----------------
func spielplatz(parent:Node3D,hof:PackedVector2Array,gy:float):
	if hof.size()<3:return
	var c=Vector2.ZERO
	for v in hof:c+=v
	c/=hof.size()
	var sand=Mats.pbr("sand",0.3,Color(0.95,0.88,0.7));var holz=Mats.flat(Color(0.55,0.36,0.2),0.75)
	var rot=Mats.flat(Color(0.85,0.15,0.1),0.5);var gelb=Mats.flat(Color(0.95,0.75,0.1),0.5);var blau=Mats.flat(Color(0.15,0.35,0.8),0.5)
	var metall=Mats.flat(Color(0.6,0.62,0.65),0.35,0.8)
	var xf=Transform3D(Basis(),Vector3(c.x,gy,c.y))
	b_deko.box(sand,Vector3(-9,0.0,-7),Vector3(9,0.06,7),xf)
	for e in [[-9,-7,9,-6.85],[-9,6.85,9,7],[-9,-7,-8.85,7],[8.85,-7,9,7]]:b_deko.box(holz,Vector3(e[0],0,e[1]),Vector3(e[2],0.35,e[3]),xf)
	# Schaukel
	for sx in [-6.5,-2.5]:
		b_deko.box_rot(metall,Vector3(sx,1.25,-4.2),Vector3(0.08,2.6,0.08),Basis(Vector3(1,0,0),0.25),xf)
		b_deko.box_rot(metall,Vector3(sx,1.25,-2.8),Vector3(0.08,2.6,0.08),Basis(Vector3(1,0,0),-0.25),xf)
	b_deko.box(metall,Vector3(-6.6,2.45,-3.55),Vector3(-2.4,2.55,-3.45),xf)
	for sx in [-5.4,-3.6]:
		b_deko.box(metall,Vector3(sx-0.02,0.6,-3.52),Vector3(sx-0.0,2.45,-3.48),xf);b_deko.box(metall,Vector3(sx+0.6,0.6,-3.52),Vector3(sx+0.62,2.45,-3.48),xf)
		b_deko.box(rot,Vector3(sx-0.05,0.55,-3.7),Vector3(sx+0.67,0.62,-3.3),xf)
	# Rutsche mit Turm
	b_deko.box(holz,Vector3(2.0,0,1.0),Vector3(4.0,1.8,3.0),xf)
	b_deko.box(gelb,Vector3(1.8,1.8,0.8),Vector3(4.2,1.95,3.2),xf)
	b_deko.box_rot(blau,Vector3(5.6,0.95,2.0),Vector3(3.4,0.08,1.0),Basis(Vector3(0,0,1),-0.55),xf)
	b_deko.box(metall,Vector3(1.6,0,1.9),Vector3(1.7,1.8,2.1),xf)
	# Wippe
	b_deko.box(metall,Vector3(-4.2,0,3.3),Vector3(-3.8,0.5,3.7),xf)
	b_deko.box_rot(rot,Vector3(-4.0,0.6,3.5),Vector3(4.0,0.1,0.35),Basis(Vector3(0,0,1),0.18),xf)
	# Bänke
	for bx in [-7.0,6.5]:
		b_deko.box(holz,Vector3(bx-1.0,0.42,8.2),Vector3(bx+1.0,0.5,8.7),xf);b_deko.box(holz,Vector3(bx-1.0,0.5,8.65),Vector3(bx+1.0,0.95,8.75),xf)
		b_deko.box(metall,Vector3(bx-0.9,0,8.3),Vector3(bx-0.8,0.42,8.6),xf);b_deko.box(metall,Vector3(bx+0.8,0,8.3),Vector3(bx+0.9,0.42,8.6),xf)
	log.append("Spielplatz bei "+str(c))

# Hof ausstatten je nach Typ:
#  hinterhof – Asphalt, Garagenzeile, parkende Autos, Müllcontainer, Mülltonnen, ein paar Bäume
#  gruen     – Rasen, Betonwege über Kreuz, Spielplatz, Bänke, Bäume
#  gasse     – schmale Gasse quer durch den Block: Container, Kisten, Mülltonnen an den Wänden
func hof_ausstatten(parent:Node3D,e:Dictionary,gy:float,baum:Mesh,autos:Array):
	var hof:PackedVector2Array=e.get("hof",PackedVector2Array())
	log.append("Hof %s Ecken %d Fläche %d"%[e.get("typ","?"),hof.size(),int(_flaeche(hof)) if hof.size()>2 else 0])
	if hof.size()<3:return
	var typ=e.typ
	var c=_mitte(hof)
	var gruen=Mats.flat(Color(0.12,0.3,0.18),0.7);var grau=Mats.flat(Color(0.32,0.33,0.34),0.6,0.4)
	var holz=Mats.flat(Color(0.45,0.32,0.2),0.8);var blech=Mats.flat(Color(0.55,0.56,0.55),0.45,0.7)
	var asph=Mats.pbr("asphalt",0.15,Color(0.5,0.5,0.52))
	var tor_farben=[Color(0.75,0.74,0.7),Color(0.55,0.6,0.65),Color(0.7,0.62,0.5),Color(0.45,0.5,0.45)]
	if typ=="gruen":
		spielplatz(parent,hof,gy)
		var beton=Mats.pbr("concrete",0.35,Color(0.72,0.71,0.68))
		var mn=Vector2(INF,INF);var mx=-mn
		for v in hof:mn=mn.min(v);mx=mx.max(v)
		_weg(Vector2(mn.x,c.y+12),Vector2(mx.x,c.y+12),2.2,gy,beton);_weg(Vector2(c.x-14,mn.y),Vector2(c.x-14,mx.y),2.2,gy,beton)
		_streuen(parent,hof,gy,baum,c,16.0,0.5,0.0,0.0)
		return
	# Hof füllen: Rasterplanung im Hof-Koordinatensystem (x entlang der längsten Kante, y nach innen)
	var n=hof.size();var bi=0;var bl=0.0
	for i in n:
		var L=hof[i].distance_to(hof[(i+1)%n])
		if L>bl:bl=L;bi=i
	var ka=hof[bi];var kb=hof[(bi+1)%n];var ex=(kb-ka)/bl;var ey=-_aussen(hof,ka,kb)
	var belegt=[]   # [mitte, halbe Größe x, halbe Größe y, drehung-Achsen]
	var frei=func(m:Vector2,hx:float,hy:float,ax:Vector2,ay:Vector2,rand:float)->bool:
		for q in [m+ax*hx+ay*hy,m-ax*hx+ay*hy,m+ax*hx-ay*hy,m-ax*hx-ay*hy,m]:
			if not Geometry2D.is_point_in_polygon(q,hof):return false
			for i in hof.size():
				if Geometry2D.get_closest_point_to_segment(q,hof[i],hof[(i+1)%hof.size()]).distance_to(q)<rand:return false
		for bq in belegt:
			if abs((m-bq[0]).dot(bq[3]))<hx+bq[1]+0.8 and abs((m-bq[0]).dot(bq[4]))<hy+bq[2]+0.8:return false
		return true
	# 1) großer Hof: Haus in der Mitte (Hinterhaus/Remise), Front zur längsten Kante
	var fl=_flaeche(hof)
	var hl=MITTELHAUS.duplicate();hl.shuffle()
	var mn0=Vector2(INF,INF);var mx0=-mn0
	for v in hof:mn0=mn0.min(v);mx0=mx0.max(v)
	var mittel=0;var ziel_m=int(fl/700.0)
	for versuch in 80:
		if mittel>=ziel_m:break
		var name=hl[rng.randi()%hl.size()]
		if not fronten.has(name):continue
		var v=fronten[name].vorn;var m=masse(name,v)
		var mp=c+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*(mx0-mn0)*0.4*(versuch/80.0+0.1)
		if frei.call(mp,m.x*0.5+3.0,m.y*0.5+3.0,ex,ey,0.5):
			haus(parent,name,v,mp,-ey if rng.randf()<0.5 else ey,gy)
			belegt.append([mp,m.x*0.5+2.0,m.y*0.5+2.0,ex,ey]);log.append("Mittelhaus "+name);mittel+=1
	# 2) Garagenzeile an der längsten Kante
	if typ=="hinterhof" and bl>12.0:
		var anzahl=int((bl-4.0)/3.2)
		for k in anzahl:
			var p=ka+ex*(2.0+k*3.2+1.6)+ey*3.2
			if not frei.call(p,1.6,3.0,ex,ey,0.0):continue
			var xf=Transform3D(Basis(Vector3.UP,atan2(ey.x,ey.y)),Vector3(p.x,_y(p,gy),p.y))
			if hoehe_cb.is_valid():b_deko.box(asph,Vector3(-1.7,-0.6,-3.1),Vector3(1.7,0.03,6.5),xf)
			b_deko.box(Mats.flat(Color(0.62,0.6,0.56),0.85),Vector3(-1.6,0,-3.0),Vector3(1.6,2.6,3.0),xf)
			b_deko.box(Mats.flat(tor_farben[rng.randi()%tor_farben.size()],0.5,0.5),Vector3(-1.25,0.05,3.0),Vector3(1.25,2.2,3.06),xf)
			for r in 6:b_deko.box(grau,Vector3(-1.25,0.25+r*0.33,3.06),Vector3(1.25,0.28+r*0.33,3.09),xf)
			b_deko.box(Mats.flat(Color(0.28,0.27,0.27),0.8),Vector3(-1.7,2.6,-3.1),Vector3(1.7,2.72,3.2),xf)
			belegt.append([p,1.7,3.2,ex,ey])
	# 3) Parkplätze (Reihe mit Markierung) überall, wo 5x2.6 m frei sind; jede zweite Lücke mit Auto
	var weiss=Mats.flat(Color(0.92,0.92,0.88),0.6)
	var plaetze=0
	var spanne=(mx0-mn0).length()
	for reihe in range(0,mini(int(spanne/6.0)+1,2)):   # höchstens zwei Reihen an der langen Kante
		var y0=3.0+reihe*6.0
		var x=-spanne
		while x<spanne:
			var p=ka+ex*x+ey*y0
			if frei.call(p,1.3,2.5,ex,ey,0.6):
				var xf=Transform3D(Basis(Vector3.UP,atan2(ey.x,ey.y)),Vector3(p.x,_y(p,gy)+0.01,p.y))
				if hoehe_cb.is_valid():b_deko.box(asph,Vector3(-1.4,-0.6,-3.6),Vector3(1.4,0.0,2.6),xf)
				b_deko.box(weiss,Vector3(-1.32,0,-2.5),Vector3(-1.22,0.01,2.5),xf);b_deko.box(weiss,Vector3(1.22,0,-2.5),Vector3(1.32,0.01,2.5),xf)
				if rng.randf()<0.55 and not autos.is_empty():
					var auto=load("res://assets/cache/autos/"+autos[rng.randi()%autos.size()]+".scn").instantiate();parent.add_child(auto)
					auto.position=Vector3(p.x,_y(p,gy),p.y);auto.rotation.y=atan2(ey.x,ey.y)+(PI if rng.randf()<0.5 else 0.0)
				belegt.append([p,1.3,2.5,ex,ey]);plaetze+=1
			x+=2.7
		if plaetze>int(fl/60.0):break
	# 4) kleine Lücken: Bänke mit Baum, Müllcontainer, Tonnen, Fahrradständer
	var kleines=0
	for versuch in 300:
		var p=Vector2(rng.randf(),rng.randf())
		var mn=Vector2(INF,INF);var mx=-mn
		for v in hof:mn=mn.min(v);mx=mx.max(v)
		p=mn+(mx-mn)*p
		var art=rng.randi()%4
		var hx=[1.2,1.0,1.2,0.9][art];var hy=[1.2,0.7,0.6,0.6][art]
		if not frei.call(p,hx,hy,ex,ey,0.4):continue
		var xf=Transform3D(Basis(Vector3.UP,atan2(ey.x,ey.y)),Vector3(p.x,_y(p,gy),p.y))
		match art:
			0:
				b_deko.box(holz,Vector3(-1.0,0.42,-0.25),Vector3(1.0,0.5,0.25),xf);b_deko.box(holz,Vector3(-1.0,0.5,0.2),Vector3(1.0,0.95,0.28),xf)
				b_deko.box(grau,Vector3(-0.9,0,-0.2),Vector3(-0.8,0.42,0.2),xf);b_deko.box(grau,Vector3(0.8,0,-0.2),Vector3(0.9,0.42,0.2),xf)
				if baum and rng.randf()<0.6:
					var bp=xf*Vector3(0,0,-2.2);baum_setzen(parent,baum,Vector2(bp.x,bp.z),gy,rng.randf_range(0.55,0.75))
			1:
				b_deko.box(gruen,Vector3(-0.9,0.05,-0.55),Vector3(0.9,1.25,0.55),xf);b_deko.box(Mats.flat(Color(0.08,0.15,0.1),0.6),Vector3(-0.95,1.25,-0.6),Vector3(0.95,1.32,0.6),xf)
			2:
				for q in 3:b_deko.cyl([grau,gruen,Mats.flat(Color(0.2,0.3,0.6),0.6)][q],Vector3(q*0.75-0.75,0.5,0),0.3,1.0,xf)
			3:
				for q in 4:b_deko.box(grau,Vector3(q*0.5-0.8,0,-0.03),Vector3(q*0.5-0.75,0.8,0.03),xf)
				b_deko.box(grau,Vector3(-0.85,0.78,-0.04),Vector3(0.75,0.82,0.04),xf)
		belegt.append([p,hx,hy,ex,ey]);kleines+=1
		if kleines>=int(fl/60.0):break
	log.append("Hof gefüllt: Parkplätze %d, Kleinkram %d"%[plaetze,kleines])

# ein paar Bäume im Hof (frei = Bereich um Punkt c mit Radius r_frei bleibt leer)
func _streuen(parent:Node3D,hof:PackedVector2Array,gy:float,baum:Mesh,c:Vector2,r_frei:float,dichte:float,_a,_b):
	if baum==null:return
	var mn=Vector2(INF,INF);var mx=-mn
	for v in hof:mn=mn.min(v);mx=mx.max(v)
	var n=int((mx-mn).x*(mx-mn).y/250.0*dichte)
	for k in n:
		var p=Vector2(rng.randf_range(mn.x,mx.x),rng.randf_range(mn.y,mx.y))
		if not Geometry2D.is_point_in_polygon(p,hof) or p.distance_to(c)<r_frei:continue
		var ok=true
		for i in hof.size():
			if Geometry2D.get_closest_point_to_segment(p,hof[i],hof[(i+1)%hof.size()]).distance_to(p)<3.0:ok=false
		if not ok:continue
		baum_setzen(parent,baum,p,gy,rng.randf_range(0.6,0.85))

# Bodenhöhe an einem Punkt (in der Welt: Gelände, im Probestück: Blockhöhe)
func _y(p:Vector2,gy:float)->float:
	return hoehe_cb.call(p) if hoehe_cb.is_valid() else gy

func fertig(parent:Node3D):b_deko.commit(parent)
