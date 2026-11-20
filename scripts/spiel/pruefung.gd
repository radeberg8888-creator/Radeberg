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
var CG:={}                       # 1-m-Zelle -> alle nach oben zeigenden sichtbaren Dreiecke (Abdeckung)
var CT:=PackedVector3Array()
var VT:=PackedVector3Array()     # senkrechte Dreiecke (Wände)
var VO:=PackedInt32Array()
var VG:={}                       # 2-m-Zelle -> PackedInt32Array
var NAMEN:=[]                    # Mesh-Nummer -> Name
var BEIDSEITIG:=[]               # Mesh-Nummer -> Material ohne Rückseiten-Ausblendung
var KANTEN:=[]                   # Wand-Unterkanten [a,b,aussen_normal,oben_y,owner]
var KXF:=[]                      # Mesh-Nummer -> Transform der Bausatz-Kopie (sonst null)
var KINST:=[]                    # Mesh-Nummer -> Nummer der Bausatz-Kopie (0 = kein Bausatz)
var KOPIE_N:=0
var DOPPEL_KOPIEN:=[]            # [name, ort] zwei Kopien desselben Bausatzes am selben Platz
const BEKANNT_HIMMEL:=["heli","flug","wolke","kran","mast","jet","ballon","antenne","schornstein","turm","bruecke","autobahn","hochstr","k_b-","klima","schuessel","hoch","stilkontur"]

func _init(galerie):G=galerie

func _matname(mat)->String:
	if mat==null:return "?"
	if mat.resource_name!="":return mat.resource_name
	if mat is BaseMaterial3D:return "#"+mat.albedo_color.to_html(false)
	if mat is ShaderMaterial:
		var f=mat.get_shader_parameter("farbe")
		if f is Color:return "S#"+f.to_html(false)
		if mat.shader:return "S:"+mat.shader.resource_path.get_file()
	return "?"
# Dreiecke einer Oberfläche (wie Mesh.get_faces, aber nur diese Oberfläche)
func _flaechen(me:Mesh,sf:int)->PackedVector3Array:
	var a=me.surface_get_arrays(sf);var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var out=PackedVector3Array()
	var ix=a[Mesh.ARRAY_INDEX]
	if ix!=null and ix.size()>0:
		out.resize(ix.size())
		for k in ix.size():out[k]=v[ix[k]]
	else:out=v
	return out
func _flaechen_farbig(me:Mesh,sf:int)->Dictionary:
	var a=me.surface_get_arrays(sf);var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var col=a[Mesh.ARRAY_COLOR]
	var ix=a[Mesh.ARRAY_INDEX];var hat_ix=ix!=null and ix.size()>0
	var n=ix.size() if hat_ix else v.size()
	var out={}
	for t in range(0,n-2,3):
		var i0=ix[t] if hat_ix else t
		var fk=""
		if col!=null and col.size()>i0:fk="~"+Color(col[i0]).to_html(false)
		if not out.has(fk):out[fk]=[]
		var o:Array=out[fk]
		for q in 3:o.append(v[ix[t+q]] if hat_ix else v[t+q])
	var fertig={}
	for fk in out:fertig[fk]=PackedVector3Array(out[fk])
	return fertig
func _kurz(oid:int)->String:return String(NAMEN[oid]).split("@")[0]
func _beidseitig(m)->bool:
	if m is BaseMaterial3D:return m.cull_mode==BaseMaterial3D.CULL_DISABLED
	if m is ShaderMaterial and m.shader:return m.shader.code.contains("cull_disabled")
	return false
func _ink(m)->bool:
	if m is BaseMaterial3D:return m.cull_mode==BaseMaterial3D.CULL_FRONT
	if m is ShaderMaterial and m.shader:return m.shader.code.contains("cull_front")
	return false

func sammeln(mitte:Vector2,radius:float):
	BT.clear();BO.clear();BG.clear();CG.clear();CT.clear();VT.clear();VO.clear();VG.clear();NAMEN.clear();BEIDSEITIG.clear();KANTEN.clear();KXF.clear();KINST.clear();KOPIE_N=0;DOPPEL_KOPIEN.clear()
	var orte={}
	var feld=Rect2(mitte-Vector2(radius,radius),Vector2(radius,radius)*2.0)
	var welt=G.spiel.welt
	# 1) Meshes (Stadt-/Nord-Kacheln, Gelände-Zubehör)
	for mi in welt.find_children("*","MeshInstance3D",true,false):
		if mi.mesh==null or not mi.is_visible_in_tree():continue
		var mat=mi.material_override
		if mat==null and mi.mesh.get_surface_count()>0:mat=mi.mesh.surface_get_material(0)
		if _ink(mat):continue
		# Gelände-Netz (alle Detailstufen) nicht: das Gelände kommt exakt aus dem Höhenraster;
		# Fern-Stellvertreter (erst ab Entfernung sichtbar) zählen nicht als Boden
		if String(mi.name).begins_with("Gelaende") or mi.visibility_range_begin>0.0:continue
		var gab:AABB=mi.global_transform*mi.mesh.get_aabb()
		if not feld.intersects(Rect2(gab.position.x,gab.position.z,gab.size.x,gab.size.z)):continue
		if gab.size.x>3000.0 or gab.size.z>3000.0:continue   # Wasser über die ganze Insel
		var mn=_matname(mat)
		_mesh_eintragen(mi.mesh.get_faces(),mi.global_transform,mn+"@"+str(mi.get_parent().name),_beidseitig(mat),mitte,radius)
	# 2) Bausätze (MultiMesh-Kopien) mit ihren Wänden, nur im halben Umkreis (teuer)
	for m in welt.find_children("*","MultiMeshInstance3D",true,false):
		if m.multimesh==null or m.multimesh.mesh==null or not m.is_visible_in_tree():continue
		var nm:String=m.name
		if nm.ends_with("ink") or nm.begins_with("NF_") or nm.begins_with("nt_"):continue
		var me:Mesh=m.multimesh.mesh
		if me.get_faces().size()>60000:continue
		# je Oberfläche (Material) eigene Fläche: Rasen–Einfahrt ist ein gewollter Übergang, keine Stufe in einer Fläche
		var teile=[]
		for sf in me.get_surface_count():
			var mat=m.material_override if m.material_override!=null else me.surface_get_material(sf)
			# Bausätze färben über Eckfarben (ein Material für alles): je Farbe eine eigene Fläche
			var nach=_flaechen_farbig(me,sf)
			for fk in nach:teile.append([nach[fk],_matname(mat)+fk,_beidseitig(mat)])
		for i in m.multimesh.instance_count:
			var gx:Transform3D=m.global_transform*m.multimesh.get_instance_transform(i)
			if gx.basis.get_scale().x<0.01:continue
			if Vector2(gx.origin.x,gx.origin.z).distance_to(mitte)>radius*0.6:continue
			# dieselbe Bausatz-Kopie zweimal mit gleicher Lage, Drehung und Größe (z. B. von zwei Kacheln aufgestellt)?
			var b=gx.basis
			var ok="%s|%d|%d|%d|%d|%d|%d|%d|%d|%d"%[me.get_instance_id(),int(round(gx.origin.x*50.0)),int(round(gx.origin.y*50.0)),int(round(gx.origin.z*50.0)),
				int(round(b.x.x*100.0)),int(round(b.x.z*100.0)),int(round(b.y.y*100.0)),int(round(b.z.x*100.0)),int(round(b.z.z*100.0)),int(round(b.x.y*100.0))]
			if orte.has(ok):DOPPEL_KOPIEN.append([nm,gx.origin]);continue
			orte[ok]=true
			KOPIE_N+=1
			for t in teile:
				_mesh_eintragen(t[0],gx,nm+"/"+t[1],t[2],mitte,radius,true)
				KXF[KXF.size()-1]=gx;KINST[KINST.size()-1]=KOPIE_N

func _mesh_eintragen(F:PackedVector3Array,xf:Transform3D,name:String,beid:bool,mitte:Vector2,radius:float,nur_waende:=false):
	var oid=NAMEN.size();NAMEN.append(name);BEIDSEITIG.append(beid);KXF.append(null);KINST.append(0)
	for i in range(0,F.size()-2,3):
		var a=xf*F[i];var b=xf*F[i+1];var c=xf*F[i+2]
		var cr=(b-a).cross(c-a);var l2=cr.length_squared()
		if l2<1e-10:continue
		var nv=-cr/sqrt(l2)
		var m=(a+b+c)/3.0
		if Vector2(m.x,m.z).distance_to(mitte)>radius:continue
		if nv.y>0.5 and m.y-G._tri_hg(m.x,m.z)<3.0:
			# Abdeckung für die Lückensuche: jede sichtbare, nach oben zeigende Fläche (auch Schrägen, Bankett,
			# Markierung, Bausatz-Teile) – wo eine davon liegt, schaut man nicht aufs Gelände durch
			var ci=CT.size()/3;CT.append_array([a,b,c])
			var cx0=int(floor(min(a.x,min(b.x,c.x))));var cx1=int(floor(max(a.x,max(b.x,c.x))))
			var cz0=int(floor(min(a.z,min(b.z,c.z))));var cz1=int(floor(max(a.z,max(b.z,c.z))))
			if (cx1-cx0+1)*(cz1-cz0+1)<=90000:
				for gx in range(cx0,cx1+1):
					for gz in range(cz0,cz1+1):
						var k=Vector2i(gx,gz)
						if not CG.has(k):CG[k]=PackedInt32Array()
						CG[k].append(ci)
		if nv.y>0.985:   # Boden ist fast eben (höchstens ~17 % Gefälle); Markisen/Dächer/Böschungen nicht
			var th=G._tri_hg(m.x,m.z)
			var dh=m.y-th
			if dh>1.5 or dh<-0.6:continue
			# keine Bodenfläche: aufgemalte Markierung, Bankett (taucht gewollt unter das Gelände), Sockel-Oberseiten,
			# Teile unter dem Boden eines Bausatzes (verdeckt)
			if name.begins_with("markierung") or name.contains("/markierung") or name.begins_with("stein_d") or name.contains("sockel") or name.begins_with("bankett"):continue
			if nur_waende and m.y<xf.origin.y+0.10:continue
			# Bausätze: nur große, niedrige Flächen (Veranda, Terrasse, Einfahrt, Stufen) – keine Tische/Töpfe
			if nur_waende and (sqrt(l2)*0.5<0.3 or dh>0.9 or name.begins_with("K_")):continue
			var ti=BO.size();BT.append_array([a,b,c]);BO.append(oid)
			var x0=int(floor(min(a.x,min(b.x,c.x))));var x1=int(floor(max(a.x,max(b.x,c.x))))
			var z0=int(floor(min(a.z,min(b.z,c.z))));var z1=int(floor(max(a.z,max(b.z,c.z))))
			if (x1-x0+1)*(z1-z0+1)>90000:continue   # nur riesige Flächen (Wasser) auslassen
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
# tol: Abstand zur Dreieckskante in m (positiv = Punkt muss so weit innen liegen, negativ = Kante zählt mit)
func hoehen(x:float,z:float,tol:=0.0005)->Array:
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
		# Abstand zur Kante = l * Höhe des Dreiecks über dieser Kante
		var ad=abs(d)
		if l1*ad<tol*Vector2(b.x-c.x,b.z-c.z).length() or l2*ad<tol*Vector2(c.x-a.x,c.z-a.z).length() or l3*ad<tol*Vector2(a.x-b.x,a.z-b.z).length():continue
		out.append([l1*a.y+l2*b.y+l3*c.y,ti])
	return out
# waagerechter Abstand des Punkts zum nächsten Bodendreieck (Zellen ringsum), 9.99 = keins in 1 m
func _abstand_flaeche(x:float,z:float)->float:
	var best=9.99;var p=Vector2(x,z)
	for dx in [-1,0,1]:
		for dz in [-1,0,1]:
			var k=Vector2i(int(floor(x))+dx,int(floor(z))+dz)
			if not CG.has(k):continue
			for ti in CG[k]:
				var a=CT[ti*3];var b=CT[ti*3+1];var c=CT[ti*3+2]
				var A=Vector2(a.x,a.z);var B=Vector2(b.x,b.z);var Cc=Vector2(c.x,c.z)
				if Geometry2D.point_is_inside_triangle(p,A,B,Cc):return 0.0
				for e in [[A,B],[B,Cc],[Cc,A]]:
					best=min(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,e[0],e[1])))
	return best
# kleinste Breite eines Bodendreiecks (Höhe über der längsten Kante, waagerecht gemessen)
func _breite(ti:int)->float:
	var a=BT[ti*3];var b=BT[ti*3+1];var c=BT[ti*3+2]
	var A2=abs((b.x-a.x)*(c.z-a.z)-(c.x-a.x)*(b.z-a.z))
	var L=max(Vector2(b.x-a.x,b.z-a.z).length(),max(Vector2(c.x-b.x,c.z-b.z).length(),Vector2(a.x-c.x,a.z-c.z).length()))
	return A2/max(L,0.0001)
# Hinweis für Bausätze: gleiche/andere Kopie, Punkt und Höhen im Bausatz (lokal)
func _diag(e1:Array,e2:Array,x:float,z:float)->String:
	var o1=BO[e1[1]];var o2=BO[e2[1]]
	var gleich=o1==o2 or (KINST[o1]>0 and KINST[o1]==KINST[o2])
	var t=" | "+("gleiche Kopie" if gleich else "andere Kopie")
	var xf=KXF[o1] if KXF[o1]!=null else KXF[o2]
	if xf!=null:
		var inv=xf.affine_inverse()
		var p1=inv*Vector3(x,e1[0],z);var p2=inv*Vector3(x,e2[0],z)
		t+=" lokal (%.2f, %.3f/%.3f, %.2f)"%[p1.x,p1.y,p2.y,p1.z]
	return t
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
	for e in DOPPEL_KOPIEN:FUNDE.append([e[0],"Kopie_doppelt",1.0,e[1],"zwei gleiche Bausätze am selben Platz",e[1]+Vector3(6,8,6)])
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
							var n1=_kurz(BO[hs[i][1]]);var n2=_kurz(BO[hs[i+1][1]])
							if n2<n1:
								var tt=n1;n1=n2;n2=tt
							FUNDE.append(["Boden:"+n1+"&"+n2,"doppelte_Flaeche",hs[i+1][0]-hs[i][0],Vector3(x,hs[i][0],z),NAMEN[BO[hs[i][1]]]+" & "+NAMEN[BO[hs[i+1][1]]]+_diag(hs[i],hs[i+1],x,z)]);break
				var th=G._tri_hg(x,z)
				# d) Gelände sticht durch die Platte (Sägezahn am Hang)
				if th>top+0.02:
					var lk=""
					var kx=KXF[BO[ti_top]]
					if kx!=null:
						var lp=kx.affine_inverse()*Vector3(x,top,z);lk=" | lokal (%.2f, %.3f, %.2f) Gelände lokal %.3f"%[lp.x,lp.y,lp.z,(kx.affine_inverse()*Vector3(x,th,z)).y]
					FUNDE.append(["Boden:"+_kurz(BO[ti_top]),"Gelaende_durch",th-top,Vector3(x,top,z),NAMEN[BO[ti_top]]+lk])
				# b) Kollision alle 2 m
				# (nur begehbare Flächen: mindestens 35 cm breit – Fensterbänke, Gesimse und Leisten betritt niemand)
				if int(floor(x))%2==0 and int(floor(z))%2==0 and _breite(ti_top)>=0.35:
					var r=G._strahl(Vector3(x,top+0.25,z),Vector3(x,top-3.0,z),true)
					if r.is_empty():FUNDE.append(["Boden:"+_kurz(BO[ti_top]),"ohne_Kollision",3.0,Vector3(x,top,z),NAMEN[BO[ti_top]]])
					elif r.position.y<top-0.03:FUNDE.append(["Boden:"+_kurz(BO[ti_top]),"Kollision_tiefer",top-r.position.y,Vector3(x,top,z),NAMEN[BO[ti_top]]+" | "+str(r.collider.get_parent().name)])
				# d) kleine Stufen (2. Ableitung über 0,2 m, Gefälle hebt sich auf)
				# gewollt: Bordstein (Stufe ≥ 4 cm zwischen zwei verschiedenen Flächen, z. B. Fahrbahn–Gehweg)
				var ot=BO[ti_top]
				for d in [Vector2(0.2,0),Vector2(0,0.2)]:
					var e1=_top_o(x-d.x,z-d.y);var e2=_top_o(x+d.x,z+d.y)
					var s2=abs(e1[0]+e2[0]-2.0*top)
					if s2<=0.025 or s2>=0.10:continue
					# Fehler: Stufe innerhalb derselben Fläche oder zwischen Stücken desselben Materials;
					# zwischen verschiedenen Materialien (Bordstein, Hofbelag, Rasenkante) ist die Kante gewollt
					var gleich=(e1[1]==ot and e2[1]==ot)
					var gleich_mat=e1[1]>=0 and e2[1]>=0 and _kurz(e1[1])==_kurz(ot) and _kurz(e2[1])==_kurz(ot)
					if gleich or gleich_mat:
						FUNDE.append(["Boden:"+_kurz(ot),"Stufe",s2,Vector3(x,top,z),NAMEN[ot]+(" | gleiche Fläche" if gleich else " | Übergang")]);break
			else:
				# d) schmale Lücke zwischen zwei Platten (Durchschauen auf das Gelände)
				# Punkt genau auf einer gemeinsamen Kante zweier Dreiecke ist keine Lücke (Spalt unter 2 mm)
				if hoehen(x,z,-0.002).size()>0 or _abstand_flaeche(x,z)<0.002:z+=1.0;continue
				var th=G._tri_hg(x,z)
				for d in [Vector2(0.6,0),Vector2(0,0.6)]:
					var h1=oben(x-d.x,z-d.y);var h2=oben(x+d.x,z+d.y)
					if h1>th+0.05 and h2>th+0.05:
						var e1=hoehen(x-d.x,z-d.y);var e2=hoehen(x+d.x,z+d.y)
						var nm1=_kurz(BO[e1[0][1]]) if e1.size()>0 else "?";var nm2=_kurz(BO[e2[0][1]]) if e2.size()>0 else "?"
						FUNDE.append(["Boden:"+nm1+"|"+nm2,"Luecke",min(h1,h2)-th,Vector3(x,th,z),"zwischen "+nm1+" und "+nm2+" | nächste Fläche %.1f cm"%(_abstand_flaeche(x,z)*100.0),Vector3(x+1.2,th+3.2,z+1.2)]);break
			z+=1.0
		x+=1.0
	# a) Wände, Mauern, Hecken, Zäune: Unterkante alle 1 m gegen den Boden darunter
	for e in KANTEN:
		var a:Vector3=e[0];var b:Vector3=e[1];var nv:Vector3=e[2]
		var L=Vector2(a.x-b.x,a.z-b.z).length();var n=max(1,int(ceil(L)))
		for s in n+1:
			var p=a.lerp(b,float(s)/n)
			var q=p-nv*0.25   # etwas hinter der Wandfläche (unter dem Haus), nicht knapp außerhalb der Platte
			if Vector2(q.x-mitte.x,q.z-mitte.y).length_squared()>r2*0.36:continue   # dort sind auch die Kopien (Sockel) erfasst
			if p.y-G._tri_hg(q.x,q.z)>2.0:continue   # Obergeschoss/Dachaufbau
			# steht die Wand auf einem Sockel/einer Mauer darunter? dann deren Unterkante messen
			var unten=p.y
			for _k in 6:
				var u2=_weiter_unten(Vector3(q.x,unten-0.04,q.z))
				if u2>=unten-0.01:break
				unten=u2
			var r=G._strahl(Vector3(q.x,unten+0.3,q.z),Vector3(q.x,unten-40.0,q.z),true)
			if r.is_empty():continue
			var luft=unten-r.position.y
			# Türen/Fenster/Sockel: trägt der Boden direkt davor (außen), ist von außen keine Lücke zu sehen
			if luft>0.10:
				var qa=p+nv*0.08
				var ra=G._strahl(Vector3(qa.x,unten+0.3,qa.z),Vector3(qa.x,unten-40.0,qa.z),true)
				if not ra.is_empty():luft=min(luft,unten-ra.position.y)
			# verdeckt etwas direkt vor der Wand den Bereich unter der Kante (Sockel, Pfeiler, Stufe)? dann sieht man nichts
			if luft>0.10 and luft<5.0:
				var vo=p+nv*0.5-Vector3(0,0.05,0)
				var hit=_wand_strahl(vo,-nv,0.5)
				if not hit.is_empty() and hit.dist<0.46:luft=0.0
			if luft>0.10 and luft<5.0:
				FUNDE.append([NAMEN[e[4]],"Wand_schwebt",luft,p,str(r.collider.get_parent().name)+" Unterkante y:"+str(snapped(unten,0.01))+" Treffer y:"+str(snapped(r.position.y,0.01)),p+nv*7.0+Vector3(0,0.6,0)]);break
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
				var hn:String=NAMEN[VO[h.ti]]
				if hn.begins_with("K_baum") or hn.begins_with("nt_") or hn.begins_with("K_bus") or hn.begins_with("K_werbung"):continue
				if h.rueck and not BEIDSEITIG[VO[h.ti]]:
					var key=Vector2i(int(h.pos.x/4.0),int(h.pos.z/4.0))
					if gesehen.has(key):continue
					gesehen[key]=true
					FUNDE.append([NAMEN[VO[h.ti]],"Haus_offen",h.dist,h.pos,"Blick von "+str(Vector3(p.x,y,p.y)),Vector3(p.x,y,p.y)])
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
			if nm.begins_with("m_") or nm.begins_with("gelaende"):continue   # zusammengefasste Kachel-Meshes (Hausteile)
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

# Unterkante einer senkrechten Fläche, die den Punkt (bis 0,3 m Abstand) überdeckt; sonst die Punkthöhe
func _weiter_unten(P:Vector3)->float:
	var k0=Vector2i(int(floor(P.x/2.0)),int(floor(P.z/2.0)))
	var best=P.y+0.04
	var liste=[]
	for dx in [-1,0,1]:
		for dz in [-1,0,1]:
			var kk=k0+Vector2i(dx,dz)
			if VG.has(kk):liste.append_array(VG[kk])
	for vi in liste:
		var a=VT[vi*3];var b=VT[vi*3+1];var c=VT[vi*3+2]
		var lo=min(a.y,min(b.y,c.y));var hi=max(a.y,max(b.y,c.y))
		if P.y<lo or P.y>hi or lo>=best:continue
		var n=(b-a).cross(c-a)
		if n.length_squared()<1e-10:continue
		n=n.normalized()
		var dd=(P-a).dot(n)
		if abs(dd)>0.3:continue
		var Q=P-n*dd
		# Punkt im Dreieck (Baryzentrisch in 3D)
		var v0=c-a;var v1=b-a;var v2=Q-a
		var d00=v0.dot(v0);var d01=v0.dot(v1);var d11=v1.dot(v1);var d20=v2.dot(v0);var d21=v2.dot(v1)
		var den=d00*d11-d01*d01
		if abs(den)<1e-10:continue
		var u=(d11*d20-d01*d21)/den;var v=(d00*d21-d01*d20)/den
		if u>=-0.02 and v>=-0.02 and u+v<=1.02:best=min(best,lo)
	return best
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
