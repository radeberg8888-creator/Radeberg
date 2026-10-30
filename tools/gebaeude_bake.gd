extends SceneTree
# Jedes Gebäudemodell zu EINEM Mesh zusammenfassen (je Material eine Fläche), Detailstufen (LOD) erzeugen,
# Materialien lokal kopieren (Einfärbung über Instanzfarbe). Ergebnis: assets/cache/geb/<name>.res
# Im Spiel werden daraus pro Zelle MultiMeshes – wenige Zeichenaufrufe, kein Laden ganzer Modellszenen.
const ZIEL:="res://assets/cache/geb/"
const VE=preload("res://scripts/vereinfachen.gd")
func _init():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ZIEL))
	var B=load("res://scripts/welt_bauten.gd").new(load("res://scripts/welt_gelaende.gd").new(),null)
	var meta=B._meta();var namen=meta.keys()
	if not OS.get_cmdline_user_args().is_empty():namen=OS.get_cmdline_user_args()
	var roh=0;var neu=0
	var grundrisse={}
	var alt=FileAccess.get_file_as_string(ZIEL+"grundrisse.json")
	if alt!="":grundrisse=JSON.parse_string(alt)
	for name in namen:
		var t=B.get_tpl(name)
		var n:Node3D=load(t.path).instantiate();n.scale=Vector3.ONE*t.sc
		var w=Node3D.new();w.add_child(n)
		var ms=B._meshes(n)
		for k in t.hide:ms[k].visible=false
		var c=t.ab.get_center();var off=Vector3(-c.x,-t.ab.position.y,-c.z)
		var gruppen={}   # Material -> SurfaceTool
		var tris=0
		for m in ms:
			if not m.visible or m.mesh==null:continue
			var xf=Transform3D(Basis(),off)*_rel(m,w)
			for si in m.mesh.get_surface_count():
				if m.mesh.surface_get_primitive_type(si)!=Mesh.PRIMITIVE_TRIANGLES:continue
				var mat=m.get_active_material(si)
				if not gruppen.has(mat):
					var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);gruppen[mat]=st
				gruppen[mat].append_from(m.mesh,si,xf)
		if t.roof!=null:
			var st2=SurfaceTool.new();st2.begin(Mesh.PRIMITIVE_TRIANGLES)
			# hohle Fassaden und Häuser mit Lichthof behalten ihr ergänztes Dach vollständig
			var dach=t.roof if (HOHL.has(name) or name=="beautiful_02") else _dach_freistellen(t.roof,ms,w,t.ab)
			if dach!=null:
				st2.append_from(dach,0,Transform3D(Basis(),off));gruppen[B.roof_mat()]=st2
		# Grundriss (konvexe Hülle von oben) für Fundament, Kollision und – bei hohlen Fassaden – den Gebäudekern
		var pts=PackedVector2Array();var ys=PackedFloat32Array()
		for m in ms:
			if not m.visible or m.mesh==null:continue
			var xf=Transform3D(Basis(),off)*_rel(m,w)
			for si in m.mesh.get_surface_count():
				var mt=m.get_active_material(si)
				if mt is BaseMaterial3D and mt.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue   # Bäume, Glas
				var V:PackedVector3Array=m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				var schritt=max(1,V.size()/4000)
				var y_min=min(4.0,t.ab.size.y*0.3)   # Boden, Gehweg, Autos davor nicht mitzählen
				for q in range(0,V.size(),schritt):
					var v=xf*V[q]
					if v.y<y_min:continue
					pts.append(Vector2(v.x,v.z));ys.append(v.y)
		var huelle=Geometry2D.convex_hull(pts)
		ys.sort()
		var h_kern=ys[int(ys.size()*0.85)] if ys.size()>0 else t.ab.size.y
		grundrisse[name]={"p":Array(huelle).map(func(v):return [snapped(v.x,0.01),snapped(v.y,0.01)]),"h":snapped(t.ab.size.y,0.01)}
		if HOHL.has(name):
			var kern=_kern_raster(ms,w,off,t,h_kern,HOHL[name][0])
			if kern.size()>0:
				gruppen[kern[1]]=kern[0]
				var kh=Geometry2D.convex_hull(kern[2])
				grundrisse[name]["p"]=Array(kh).map(func(v):return [snapped(v.x,0.01),snapped(v.y,0.01)])
		var am:=ArrayMesh.new();var tris_neu=0;var lodtxt=""
		for mat in gruppen:
			gruppen[mat].index()
			var arr=gruppen[mat].commit_to_arrays()
			for k in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV2]:arr[k]=null
			if arr[Mesh.ARRAY_VERTEX]==null or arr[Mesh.ARRAY_VERTEX].size()==0:continue
			if arr[Mesh.ARRAY_INDEX]==null:
				var ii=PackedInt32Array();ii.resize(arr[Mesh.ARRAY_VERTEX].size())
				for q in ii.size():ii[q]=q
				arr[Mesh.ARRAY_INDEX]=ii
			var I:PackedInt32Array=arr[Mesh.ARRAY_INDEX]
			tris+=I.size()/3
			# Grundstufe begrenzen: extrem fein modellierte Häuser werden schon in der Nähe vereinfacht
			var basis_c=0.0
			if I.size()/3>250000:basis_c=0.05   # nur extrem feine Modelle; sonst verschwinden Fensternischen
			if basis_c>0.0:I=_cluster(arr,I,basis_c);arr[Mesh.ARRAY_INDEX]=I
			tris_neu+=I.size()/3
			var lods={};var vor=I.size()
			for cs in [0.5,1.4,3.5,8.0]:
				if cs<=basis_c:continue
				var L=_cluster(arr,I,cs)
				if L.size()<3 or L.size()>vor*0.8:continue
				lods[cs]=L;vor=L.size()
				if L.size()<36:break
			lodtxt+="%d>%s "%[I.size()/3,"/".join(lods.values().map(func(x):return str(x.size()/3)))]
			var d:Material=mat.duplicate() if mat else StandardMaterial3D.new()
			if d is BaseMaterial3D:
				d.cull_mode=BaseMaterial3D.CULL_DISABLED
				d.vertex_color_use_as_albedo=true   # Instanzfarbe = Tönung/Schmutz
			var ks=lods.keys();var kp=VE.kompakt(arr,[I]+ks.map(func(x):return lods[x]))
			arr=kp[0];lods={}
			for j in ks.size():lods[ks[j]]=kp[1][j+1]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr,[],lods)
			am.surface_set_material(am.get_surface_count()-1,d)
		var e=ResourceSaver.save(am,ZIEL+name+".res",ResourceSaver.FLAG_COMPRESS)
		var flaechen=am.get_surface_count()
		print("GEB %s: %d Teile -> %d Flächen, %d -> %d Dreiecke | %s (%s)"%[name,ms.size(),flaechen,tris,tris_neu,lodtxt.left(160),error_string(e)])
		roh+=ms.size();neu+=flaechen
		w.free()
	var f=FileAccess.open(ZIEL+"grundrisse.json",FileAccess.WRITE);f.store_string(JSON.stringify(grundrisse));f.close()
	print("FERTIG Zeichenaufrufe je Haus vorher ~",roh/max(namen.size(),1)," jetzt ~",neu/max(namen.size(),1))
	quit()
# Fassadenmodelle, die hinten offen sind: Kern mit Wandmaterial [Textur, Farbe] und Abstand hinter der Fassade
const HOHL={"cityscene_00":[["concrete",Color(0.72,0.64,0.52)],0.6],"cityscene_01":[["bricks",Color(0.75,0.55,0.45)],0.6],
	"city3_00":[["bricks",Color(0.55,0.42,0.36)],0.5],"city3_01":[["bricks",Color(0.7,0.5,0.4)],0.5],"city3_02":[["bricks",Color(0.75,0.55,0.45)],0.4],
	"chicago_00":[["bricks",Color(0.7,0.6,0.55)],0.5]}
# Kern hinter hohlen Fassaden: Raster von oben (1 m). Wandzellen = Fassadengeometrie über Bodenhöhe.
# Eine Zelle gehört zum Kern, wenn man von ihr aus in Blickrichtung der Fassade (Mittel der Normalen) auf eine Wand trifft –
# also liegt sie HINTER der Fassade. So funktioniert es auch bei nach innen gebogenen Fassaden.
func _kern_raster(ms:Array,w:Node3D,off:Vector3,t:Dictionary,h:float,art:Array)->Array:
	var ab:AABB=t.ab;var cs=1.0
	var x0=-ab.size.x*0.5-1.0;var z0=-ab.size.z*0.5-1.0
	var nx=int(ceil(ab.size.x/cs))+2;var nz=int(ceil(ab.size.z/cs))+2
	var wand=PackedByteArray();wand.resize(nx*nz)
	var nsum=Vector2.ZERO
	var y_min=min(4.0,ab.size.y*0.3)
	for m in ms:
		if not m.visible or m.mesh==null:continue
		var xf=Transform3D(Basis(),off)*_rel(m,w)
		for si in m.mesh.get_surface_count():
			var mt=m.get_active_material(si)
			if mt is BaseMaterial3D and mt.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
			var arr=m.mesh.surface_get_arrays(si);var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX];var N=arr[Mesh.ARRAY_NORMAL]
			var schritt=max(1,V.size()/30000)
			for q in range(0,V.size(),schritt):
				var v=xf*V[q]
				if v.y<y_min:continue
				var ix=int((v.x-x0)/cs);var iz=int((v.z-z0)/cs)
				if ix>=0 and iz>=0 and ix<nx and iz<nz:wand[iz*nx+ix]=1
				if N!=null and q<N.size():
					var nn=xf.basis*N[q];nsum+=Vector2(nn.x,nn.z)
	if nsum.length()<1e-3:return []
	var vorn=nsum.normalized()
	var kern=PackedByteArray();kern.resize(nx*nz)
	for iz in nz:
		for ix in nx:
			if wand[iz*nx+ix]==1:continue
			for k in range(1,80):
				var px=int(ix+0.5+vorn.x*k*0.5);var pz=int(iz+0.5+vorn.y*k*0.5)
				if px<0 or pz<0 or px>=nx or pz>=nz:break
				if wand[pz*nx+px]==1:kern[iz*nx+ix]=1;break
	# Zellen direkt an der Wand frei lassen (kein Durchscheinen durch die Fassade)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var n_box=0;var eck=PackedVector2Array()
	for iz in nz:
		var ix=0
		while ix<nx:
			if kern[iz*nx+ix]==0:ix+=1;continue
			var s0=ix
			while ix<nx and kern[iz*nx+ix]==1:ix+=1
			var a=Vector3(x0+s0*cs,0,z0+iz*cs);var b=Vector3(x0+ix*cs,h,z0+(iz+1)*cs)
			_box(st,a,b);n_box+=1
			eck.append_array([Vector2(a.x,a.z),Vector2(b.x,a.z),Vector2(b.x,b.z),Vector2(a.x,b.z)])
	if n_box==0:return []
	var m=StandardMaterial3D.new()
	m.albedo_texture=load("res://assets/textures/"+art[0]+"_albedo.jpg");m.albedo_color=art[1]
	m.uv1_triplanar=true;m.uv1_scale=Vector3(0.33,0.33,0.33)
	m.roughness=0.92;m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	print("  Kern ",n_box," Blöcke, vorn=",vorn)
	return [st,m,eck]
func _box(st:SurfaceTool,a:Vector3,b:Vector3):
	var P=[Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z)]
	for f in [[0,1,5,4,Vector3(0,0,-1)],[1,2,6,5,Vector3(1,0,0)],[2,3,7,6,Vector3(0,0,1)],[3,0,4,7,Vector3(-1,0,0)],[4,5,6,7,Vector3.UP]]:
		for i in [0,1,2,0,2,3]:st.set_normal(f[4]);st.add_vertex(P[f[i]])

func _cluster(arr:Array,I:PackedInt32Array,c:float)->PackedInt32Array:return VE.cluster(arr,I,c)
func _rel(n:Node,root:Node)->Transform3D:
	var t=Transform3D.IDENTITY;var c=n
	while c!=null and c!=root:
		if c is Node3D:t=c.transform*t
		c=c.get_parent()
	return t

# Ergänztes Flachdach nur dort, wo das Modell oben offen ist. Hat das Modell schon ein (Sattel-)Dach,
# ragte die flache Platte an den Traufen als schwarze Zacken heraus.
func _dach_freistellen(roof:Mesh,ms:Array,w:Node3D,ab:AABB)->Mesh:
	var cs=0.5;var x0=ab.position.x-1.0;var z0=ab.position.z-1.0
	var nx=int(ceil(ab.size.x/cs))+5;var nz=int(ceil(ab.size.z/cs))+5
	var deckel=PackedByteArray();deckel.resize(nx*nz)
	var y_ab=ab.position.y+ab.size.y*0.45
	for m in ms:
		if not m.visible or m.mesh==null:continue
		var xf=_rel(m,w)
		for si in m.mesh.get_surface_count():
			var arr=m.mesh.surface_get_arrays(si);var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX];var I=arr[Mesh.ARRAY_INDEX]
			var cnt=I.size() if I!=null and I.size()>0 else V.size()
			var t=0
			while t+2<cnt:
				var a=xf*V[I[t] if I!=null and I.size()>0 else t];var b=xf*V[I[t+1] if I!=null and I.size()>0 else t+1];var c=xf*V[I[t+2] if I!=null and I.size()>0 else t+2]
				t+=3
				if max(a.y,max(b.y,c.y))<y_ab:continue
				var nrm=(b-a).cross(c-a)
				if nrm.length()<1e-6 or abs(nrm.normalized().y)<0.25:continue   # nur dachartige (liegende) Flächen
				var L=max(a.distance_to(b),max(b.distance_to(c),c.distance_to(a)));var n=int(L/(cs*0.5))+1
				for i in n+1:
					for j in n+1-i:
						var u=float(i)/n;var v=float(j)/n
						var q=a+(b-a)*u+(c-a)*v
						var ix=int((q.x-x0)/cs);var iz=int((q.z-z0)/cs)
						if ix>=0 and iz>=0 and ix<nx and iz<nz:deckel[iz*nx+ix]=1
	var arr=roof.surface_get_arrays(0);var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3.UP)
	var behalten=0;var weg=0
	for k in range(0,V.size(),3):
		var c=(V[k]+V[k+1]+V[k+2])/3.0
		var ix=int((c.x-x0)/cs);var iz=int((c.z-z0)/cs)
		var zu=false
		for dz in [-1,0,1]:
			for dx in [-1,0,1]:
				var px=ix+dx;var pz=iz+dz
				if px>=0 and pz>=0 and px<nx and pz<nz and deckel[pz*nx+px]==1:zu=true
		if zu:weg+=1;continue
		for q in 3:st.set_uv(Vector2(V[k+q].x,V[k+q].z)*0.25);st.add_vertex(V[k+q])
		behalten+=1
	print("  Dach: %d Dreiecke behalten, %d unter vorhandenem Dach entfernt"%[behalten,weg])
	if behalten==0:return null
	return st.commit()
