extends RefCounted
# Vollständige Welt-Prüfung (Auftrag ab Build 48, Abschnitt 1.2). Keine Ausnahmen.
# Arbeitet auf den SICHTBAREN Dreiecken (Meshes) und vergleicht mit der Kollision.
#  b) Kollision auf jeder begehbaren Fläche (alle 2 m, ±3 cm zur sichtbaren Oberfläche)
#  c) doppelte Flächen (Z-Fighting): zwei Bodendreiecke gleicher Höhe (±1,5 cm) übereinander
#  d) Spalten/Stufen: kleine ungewollte Stufen (2–10 cm), schmale Lücken, Gelände sticht durch
#  a) Wände/Mauern: Unterkante entlang der ganzen Länge (alle 1 m) nicht über dem Boden
#  e) offene Häuser: Blick von der Straße darf keine Rückseite einer Wand treffen
#  f) Dinge im Himmel: Objekte > 15 m über dem Boden, die kein bekannter Typ sind
var G   # galerie
var BT:=PackedVector3Array()     # Bodendreiecke (3 Ecken je Dreieck)
var BO:=PackedInt32Array()       # Besitzer (Mesh-Nummer) je Dreieck
var BG:={}                       # 1-m-Zelle -> PackedInt32Array Dreiecke
var VT:=PackedVector3Array()     # senkrechte Dreiecke (Wände)
var VO:=PackedInt32Array()
var VG:={}                       # 2-m-Zelle -> PackedInt32Array
var NAMEN:=[]                    # Mesh-Nummer -> Name
var BEIDSEITIG:=[]               # Mesh-Nummer -> Material ohne Rückseiten-Ausblendung
var KANTEN:=[]                   # Wand-Unterkanten [a,b,aussen_normal,oben_y,owner]
const BEKANNT_HIMMEL:=["heli","flug","wolke","kran","mast","jet","ballon","antenne","schornstein","turm","bruecke","autobahn","hochstr","k_b-","klima","schuessel","hoch","stilkontur"]

func _init(galerie):G=galerie

func _beidseitig(m)->bool:
	if m is BaseMaterial3D:return m.cull_mode==BaseMaterial3D.CULL_DISABLED
	if m is ShaderMaterial and m.shader:return m.shader.code.contains("cull_disabled")
	return false
func _ink(m)->bool:
	if m is BaseMaterial3D:return m.cull_mode==BaseMaterial3D.CULL_FRONT
	if m is ShaderMaterial and m.shader:return m.shader.code.contains("cull_front")
	return false

func sammeln(mitte:Vector2,radius:float):
	BT.clear();BO.clear();BG.clear();VT.clear();VO.clear();VG.clear();NAMEN.clear();BEIDSEITIG.clear();KANTEN.clear()
	var feld=Rect2(mitte-Vector2(radius,radius),Vector2(radius,radius)*2.0)
	var welt=G.spiel.welt
	# 1) Meshes (Stadt-/Nord-Kacheln, Gelände-Zubehör)
	for mi in welt.find_children("*","MeshInstance3D",true,false):
		if mi.mesh==null or not mi.is_visible_in_tree():continue
		var mat=mi.material_override
		if mat==null and mi.mesh.get_surface_count()>0:mat=mi.mesh.surface_get_material(0)
		if _ink(mat):continue
		var gab:AABB=mi.global_transform*mi.mesh.get_aabb()
		if not feld.intersects(Rect2(gab.position.x,gab.position.z,gab.size.x,gab.size.z)):continue
		if gab.size.x>3000.0 or gab.size.z>3000.0:continue   # Gelände/Wasser über die ganze Insel
		_mesh_eintragen(mi.mesh.get_faces(),mi.global_transform,str(mi.get_parent().name)+"/"+str(mi.name),_beidseitig(mat),mitte,radius)
	# 2) Bausätze (MultiMesh-Kopien) mit ihren Wänden, nur im halben Umkreis (teuer)
	for m in welt.find_children("*","MultiMeshInstance3D",true,false):
		if m.multimesh==null or m.multimesh.mesh==null or not m.is_visible_in_tree():continue
		var nm:String=m.name
		if nm.ends_with("ink") or nm.begins_with("NF_") or nm.begins_with("nt_"):continue
		var me:Mesh=m.multimesh.mesh
		var F=me.get_faces()
		if F.size()>60000:continue
		var mat=m.material_override
		if mat==null and me.get_surface_count()>0:mat=me.surface_get_material(0)
		var bs=_beidseitig(mat)
		for i in m.multimesh.instance_count:
			var gx:Transform3D=m.global_transform*m.multimesh.get_instance_transform(i)
			if gx.basis.get_scale().x<0.01:continue
			if Vector2(gx.origin.x,gx.origin.z).distance_to(mitte)>radius*0.6:continue
			_mesh_eintragen(F,gx,nm,bs,mitte,radius,true)

func _mesh_eintragen(F:PackedVector3Array,xf:Transform3D,name:String,beid:bool,mitte:Vector2,radius:float,nur_waende:=false):
	var oid=NAMEN.size();NAMEN.append(name);BEIDSEITIG.append(beid)
	for i in range(0,F.size()-2,3):
		var a=xf*F[i];var b=xf*F[i+1];var c=xf*F[i+2]
		var cr=(b-a).cross(c-a);var l2=cr.length_squared()
		if l2<1e-10:continue
		var nv=-cr/sqrt(l2)
		var m=(a+b+c)/3.0
		if Vector2(m.x,m.z).distance_to(mitte)>radius:continue
		if nv.y>0.9 and not nur_waende:
			var th=G._tri_hg(m.x,m.z)
			var dh=m.y-th
			if abs(dh)<0.006 or dh>1.5 or dh<-0.6:continue
			var ti=BO.size();BT.append_array([a,b,c]);BO.append(oid)
			var x0=int(floor(min(a.x,min(b.x,c.x))));var x1=int(floor(max(a.x,max(b.x,c.x))))
			var z0=int(floor(min(a.z,min(b.z,c.z))));var z1=int(floor(max(a.z,max(b.z,c.z))))
			if (x1-x0+1)*(z1-z0+1)>4000:continue
			for gx in range(x0,x1+1):
				for gz in range(z0,z1+1):
					var k=Vector2i(gx,gz)
					if not BG.has(k):BG[k]=PackedInt32Array()
					BG[k].append(ti)
		elif abs(nv.y)<0.15:
			var lo=min(a.y,min(b.y,c.y));var hi=max(a.y,max(b.y,c.y))
			var th=G._tri_hg(m.x,m.z)
			if lo-th>3.0:continue
			var vi=VO.size();VT.append_array([a,b,c]);VO.append(oid)
			var x0=int(floor(min(a.x,min(b.x,c.x))/2.0));var x1=int(floor(max(a.x,max(b.x,c.x))/2.0))
			var z0=int(floor(min(a.z,min(b.z,c.z))/2.0));var z1=int(floor(max(a.z,max(b.z,c.z))/2.0))
			if (x1-x0+1)*(z1-z0+1)<=400:
				for gx in range(x0,x1+1):
					for gz in range(z0,z1+1):
						var k=Vector2i(gx,gz)
						if not VG.has(k):VG[k]=PackedInt32Array()
						VG[k].append(vi)
			# Unterkante einer hohen Wand (mind. 1 m hoch, waagerechte untere Kante)
			if hi-lo>=1.0:
				var P=[a,b,c];P.sort_custom(func(p,q):return p.y<q.y)
				if abs(P[0].y-P[1].y)<0.03 and Vector2(P[0].x-P[1].x,P[0].z-P[1].z).length()>0.4:
					KANTEN.append([P[0],P[1],nv,hi,oid])

# Höhen aller sichtbaren Bodendreiecke an (x,z): Array von [h, dreieck]
func hoehen(x:float,z:float)->Array:
	var out=[]
	var k=Vector2i(int(floor(x)),int(floor(z)))
	if not BG.has(k):return out
	for ti in BG[k]:
		var a=BT[ti*3];var b=BT[ti*3+1];var c=BT[ti*3+2]
		var d=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if abs(d)<1e-9:continue
		var l1=((b.z-c.z)*(x-c.x)+(c.x-b.x)*(z-c.z))/d
		var l2=((c.z-a.z)*(x-c.x)+(a.x-c.x)*(z-c.z))/d
		var l3=1.0-l1-l2
		if l1<0.0005 or l2<0.0005 or l3<0.0005:continue   # Kantenpunkte zählen nicht doppelt
		out.append([l1*a.y+l2*b.y+l3*c.y,ti])
	return out
func oben(x:float,z:float)->float:
	var hs=hoehen(x,z);var m=-INF
	for e in hs:m=max(m,e[0])
	return m
# [Höhe, Besitzer] der obersten sichtbaren Fläche (Besitzer -1 = Gelände)
func _top_o(x:float,z:float)->Array:
	var hs=hoehen(x,z);var m=G._tri_hg(x,z);var o=-1
	for e in hs:
		if e[0]>m:m=e[0];o=BO[e[1]]
	return [m,o]
# sichtbare Oberkante: Platte, sonst Gelände
func sicht(x:float,z:float)->float:
	return max(oben(x,z),G._tri_hg(x,z))

func pruefen(mitte:Vector2,radius:float,FUNDE:Array):
	var r2=radius*radius
	var x=mitte.x-radius+0.37
	while x<mitte.x+radius:
		var z=mitte.y-radius+0.41
		while z<mitte.y+radius:
			if Vector2(x-mitte.x,z-mitte.y).length_squared()>r2:z+=1.0;continue
			var hs=hoehen(x,z)
			if hs.size()>0:
				var top=-INF;var ti_top=-1
				for e in hs:
					if e[0]>top:top=e[0];ti_top=e[1]
				# c) doppelte Flächen
				if hs.size()>1:
					hs.sort_custom(func(p,q):return p[0]<q[0])
					for i in hs.size()-1:
						if hs[i+1][0]-hs[i][0]<0.015:
							FUNDE.append(["Boden","doppelte_Flaeche",hs[i+1][0]-hs[i][0],Vector3(x,hs[i][0],z),NAMEN[BO[hs[i][1]]]+" & "+NAMEN[BO[hs[i+1][1]]]]);break
				var th=G._tri_hg(x,z)
				# d) Gelände sticht durch die Platte (Sägezahn am Hang)
				if th>top+0.02:FUNDE.append(["Boden","Gelaende_durch",th-top,Vector3(x,top,z),NAMEN[BO[ti_top]]])
				# b) Kollision alle 2 m
				if int(floor(x))%2==0 and int(floor(z))%2==0:
					var r=G._strahl(Vector3(x,top+0.25,z),Vector3(x,top-3.0,z),true)
					if r.is_empty():FUNDE.append(["Boden","ohne_Kollision",3.0,Vector3(x,top,z),NAMEN[BO[ti_top]]])
					elif r.position.y<top-0.03:FUNDE.append(["Boden","Kollision_tiefer",top-r.position.y,Vector3(x,top,z),NAMEN[BO[ti_top]]+" | "+str(r.collider.get_parent().name)])
				# d) kleine Stufen (2. Ableitung über 0,2 m, Gefälle hebt sich auf)
				# gewollt: Bordstein (Stufe ≥ 4 cm zwischen zwei verschiedenen Flächen, z. B. Fahrbahn–Gehweg)
				var ot=BO[ti_top]
				for d in [Vector2(0.2,0),Vector2(0,0.2)]:
					var e1=_top_o(x-d.x,z-d.y);var e2=_top_o(x+d.x,z+d.y)
					var s2=abs(e1[0]+e2[0]-2.0*top)
					if s2<=0.025 or s2>=0.10:continue
					var gleich=(e1[1]==ot and e2[1]==ot)
					if gleich or s2<0.04:
						FUNDE.append(["Boden","Stufe",s2,Vector3(x,top,z),NAMEN[ot]+(" | gleiche Fläche" if gleich else " | Übergang")]);break
			else:
				# d) schmale Lücke zwischen zwei Platten (Durchschauen auf das Gelände)
				var th=G._tri_hg(x,z)
				for d in [Vector2(0.6,0),Vector2(0,0.6)]:
					var h1=oben(x-d.x,z-d.y);var h2=oben(x+d.x,z+d.y)
					if h1>th+0.05 and h2>th+0.05:
						FUNDE.append(["Boden","Luecke",min(h1,h2)-th,Vector3(x,th,z),"zwischen Platten"]);break
			z+=1.0
		x+=1.0
	# a) Wände, Mauern, Hecken, Zäune: Unterkante alle 1 m gegen den Boden darunter
	for e in KANTEN:
		var a:Vector3=e[0];var b:Vector3=e[1];var nv:Vector3=e[2]
		var L=Vector2(a.x-b.x,a.z-b.z).length();var n=max(1,int(ceil(L)))
		for s in n+1:
			var p=a.lerp(b,float(s)/n)
			var q=p-nv*0.06
			if Vector2(q.x-mitte.x,q.z-mitte.y).length_squared()>r2:continue
			if p.y-G._tri_hg(q.x,q.z)>2.0:continue   # Obergeschoss/Dachaufbau
			var r=G._strahl(Vector3(q.x,p.y+0.3,q.z),Vector3(q.x,p.y-40.0,q.z),true)
			if r.is_empty():continue
			var luft=p.y-r.position.y
			if luft>0.10 and luft<5.0:
				FUNDE.append([NAMEN[e[4]],"Wand_schwebt",luft,p,str(r.collider.get_parent().name)]);break
	# e) offene Häuser: von den Straßen aus in 8 Richtungen schauen
	var gesehen={}
	for rd in G.spiel.welt.S.roads:
		var P:PackedVector2Array=rd.P
		for i in range(0,P.size(),6):
			var p=P[i]
			if p.distance_squared_to(mitte)>r2*0.5:continue
			var y=G._tri_hg(p.x,p.y)+1.7
			var rr=G._strahl(Vector3(p.x,y+40,p.y),Vector3(p.x,y-40,p.y))
			if not rr.is_empty():y=rr.position.y+1.7
			for k in 8:
				var dir=Vector3(cos(k*PI/4.0+0.2),0.0,sin(k*PI/4.0+0.2))
				var h=_wand_strahl(Vector3(p.x,y,p.y),dir,40.0)
				if h.is_empty():continue
				if h.rueck and not BEIDSEITIG[VO[h.ti]]:
					var key=Vector2i(int(h.pos.x/4.0),int(h.pos.z/4.0))
					if gesehen.has(key):continue
					gesehen[key]=true
					FUNDE.append([NAMEN[VO[h.ti]],"Haus_offen",h.dist,h.pos,"Blick von "+str(Vector3(p.x,y,p.y))])
	# f) Dinge im Himmel
	for m in G.spiel.welt.find_children("*","GeometryInstance3D",true,false):
		if not m.is_visible_in_tree():continue
		var nm=String(m.name).to_lower()
		var bek=false
		for w in BEKANNT_HIMMEL:
			if nm.contains(w):bek=true;break
		if bek:continue
		if m is MultiMeshInstance3D and m.multimesh and m.multimesh.mesh:
			var ab=m.multimesh.mesh.get_aabb()
			for i in m.multimesh.instance_count:
				var gx:Transform3D=m.global_transform*m.multimesh.get_instance_transform(i)
				if gx.basis.get_scale().x<0.01:continue
				var lo=gx*ab.position;var c=gx*ab.get_center()
				if Vector2(c.x,c.z).distance_squared_to(mitte)>r2:continue
				var unten=min(lo.y,(gx*(ab.position+Vector3(0,0,ab.size.z))).y)
				var boden=G._tri_hg(c.x,c.z)
				if unten-boden>15.0:FUNDE.append([m.name,"im_Himmel",unten-boden,c,"Kopie"]);break
		elif m is MeshInstance3D and m.mesh:
			var gab:AABB=m.global_transform*m.mesh.get_aabb()
			if gab.size.x>40.0 or gab.size.z>40.0:continue
			var c=gab.get_center()
			if Vector2(c.x,c.z).distance_squared_to(mitte)>r2:continue
			var boden=G._tri_hg(c.x,c.z)
			if gab.position.y-boden>15.0:FUNDE.append([str(m.get_parent().name)+"/"+m.name,"im_Himmel",gab.position.y-boden,c,"Mesh"])
		elif m is Label3D:
			var c=m.global_position
			if Vector2(c.x,c.z).distance_squared_to(mitte)>r2:continue
			if c.y-G._tri_hg(c.x,c.z)>15.0:FUNDE.append(["Schild "+m.text,"im_Himmel",c.y-G._tri_hg(c.x,c.z),c,"Label"])

# Strahl gegen die gesammelten Wanddreiecke (2-m-Raster), erster Treffer
func _wand_strahl(o:Vector3,dir:Vector3,maxd:float)->Dictionary:
	var best={};var bd=maxd;var t=0.0;var gepr={}
	while t<bd:
		var p=o+dir*t
		var k=Vector2i(int(floor(p.x/2.0)),int(floor(p.z/2.0)))
		if VG.has(k):
			for vi in VG[k]:
				if gepr.has(vi):continue
				gepr[vi]=true
				var a=VT[vi*3];var b=VT[vi*3+1];var c=VT[vi*3+2]
				var e1=b-a;var e2=c-a;var pv=dir.cross(e2);var det=e1.dot(pv)
				if abs(det)<1e-9:continue
				var inv=1.0/det;var tv=o-a;var u=tv.dot(pv)*inv
				if u<0.0 or u>1.0:continue
				var qv=tv.cross(e1);var v=dir.dot(qv)*inv
				if v<0.0 or u+v>1.0:continue
				var dd=e2.dot(qv)*inv
				if dd>0.05 and dd<bd:
					bd=dd;var cr=e1.cross(e2)
					# Vorderseite: Kreuzprodukt zeigt vom Betrachter weg (Godot: im Uhrzeigersinn)
					best={"ti":vi,"dist":dd,"pos":o+dir*dd,"rueck":cr.dot(dir)<0.0}
		t+=1.0
	return best
