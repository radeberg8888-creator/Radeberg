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
			st2.append_from(t.roof,0,Transform3D(Basis(),off));gruppen[B.roof_mat()]=st2
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
			if I.size()/3>60000:basis_c=0.12
			if I.size()/3>200000:basis_c=0.25
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
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr,[],lods)
			am.surface_set_material(am.get_surface_count()-1,d)
		var e=ResourceSaver.save(am,ZIEL+name+".res",ResourceSaver.FLAG_COMPRESS)
		var flaechen=am.get_surface_count()
		print("GEB %s: %d Teile -> %d Flächen, %d -> %d Dreiecke | %s (%s)"%[name,ms.size(),flaechen,tris,tris_neu,lodtxt.left(160),error_string(e)])
		roh+=ms.size();neu+=flaechen
		w.free()
	print("FERTIG Zeichenaufrufe je Haus vorher ~",roh/max(namen.size(),1)," jetzt ~",neu/max(namen.size(),1))
	quit()
func _cluster(arr:Array,I:PackedInt32Array,c:float)->PackedInt32Array:return VE.cluster(arr,I,c)
func _rel(n:Node,root:Node)->Transform3D:
	var t=Transform3D.IDENTITY;var c=n
	while c!=null and c!=root:
		if c is Node3D:t=c.transform*t
		c=c.get_parent()
	return t
