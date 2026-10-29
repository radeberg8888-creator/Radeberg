extends SceneTree
# Fahrzeuge (assets/cache/autos/*.scn) für Handys aufbereiten:
# Karosserie = EIN Mesh (je Material eine Fläche), jedes Rad = EIN Mesh, Detailstufen für die Entfernung,
# extrem fein modellierte Autos (bis 1,6 Mio. Dreiecke) auch in der Nähe vereinfacht.
# Teile, die das Tuning einzeln ein-/ausblendet, bleiben eigene Knoten.
const VE=preload("res://scripts/vereinfachen.gd")
const F=preload("res://scripts/fit.gd")
const TU=preload("res://scripts/tuning.gd")
const DIR:="res://assets/cache/autos/"
const STUFEN:=[0.02,0.05,0.12,0.3]

func _init():
	var namen=OS.get_cmdline_user_args()
	if namen.is_empty():
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".scn"):namen.append(f.get_basename())
	for k in namen:
		var p=DIR+k+".scn"
		var n:Node3D=load(p).instantiate()
		if n.has_meta("lod_fertig"):print("AUTO ",k," schon fertig");n.free();continue
		var vorher=_zaehle(n)
		var behalten=[]
		for pre in TU.REAL_PARTS.get(n.get_meta("model",""),{}).values():behalten.append_array(pre)
		# Räder
		for c in n.get_children():
			if str(c.name).begins_with("Rad_"):_verschmelzen(c,c,[],14000,"Rad_Mesh")
		# Karosserie (alles außer Rädern)
		_verschmelzen(n,n,behalten,200000,"Karosserie",true)
		n.set_meta("lod_fertig",true)
		_own(n,n)
		var ps=PackedScene.new();var e=ps.pack(n)
		if e==OK:e=ResourceSaver.save(ps,p,ResourceSaver.FLAG_COMPRESS)
		var nachher=_zaehle(n)
		print("AUTO %s: %d -> %d Dreiecke, Flächen %d -> %d (%s)"%[k,vorher[0],nachher[0],vorher[1],nachher[1],error_string(e)])
		n.free()
	quit()

func _zaehle(n:Node)->Array:
	var t=0;var s=0
	for m in n.find_children("*","MeshInstance3D",true,false):
		if m.mesh==null or not m.is_visible_in_tree():continue
		for i in m.mesh.get_surface_count():
			s+=1;var a=m.mesh.surface_get_arrays(i);var I=a[Mesh.ARRAY_INDEX];t+=(I.size() if I else a[0].size())/3
	return [t,s]

func _own(n:Node,root:Node):
	for c in n.get_children():
		c.owner=root;_own(c,root)

# Alle sichtbaren Meshes unter "quelle" (ohne Räder, ohne behaltene Teile) zu einem Mesh unter "ziel" zusammenfassen
func _verschmelzen(quelle:Node3D,ziel:Node3D,behalten:Array,max_tris:int,name:String,ohne_raeder:=false):
	var gruppen={};var weg=[]
	for m in quelle.find_children("*","MeshInstance3D",true,false):
		if m.mesh==null:continue
		if ohne_raeder and _unter_rad(m,quelle):continue
		var skip=false
		for pre in behalten:
			if str(m.name).begins_with(pre):skip=true
		if skip:continue
		weg.append(m)
		if not m.is_visible_in_tree():continue
		var xf=F.rel_xf(m,ziel)
		for si in m.mesh.get_surface_count():
			if m.mesh is ArrayMesh and m.mesh.surface_get_primitive_type(si)!=Mesh.PRIMITIVE_TRIANGLES:continue
			var mat=m.get_active_material(si)
			if m.material_override:mat=m.material_override
			# gespiegelte Teile (negative Skalierung): Dreiecke umdrehen, sonst erscheinen sie von innen (schwarz)
			var spiegel=xf.basis.determinant()<0.0
			var key=[mat,spiegel]
			if not gruppen.has(key):
				var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);gruppen[key]=st
			gruppen[key].append_from(m.mesh,si,xf)
	if gruppen.is_empty():return
	var flaechen=[];var gesamt=0
	var flip={}
	for key in gruppen:
		var arr=gruppen[key].commit_to_arrays()
		var mat=key[0]
		for k in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:arr[k]=null
		if arr[Mesh.ARRAY_VERTEX]==null or arr[Mesh.ARRAY_VERTEX].size()==0:continue
		if arr[Mesh.ARRAY_INDEX]==null:arr[Mesh.ARRAY_INDEX]=PackedInt32Array(range(arr[Mesh.ARRAY_VERTEX].size()))
		if key[1]:
			var J:PackedInt32Array=arr[Mesh.ARRAY_INDEX]
			for t in range(0,J.size(),3):
				var tmp=J[t+1];J[t+1]=J[t+2];J[t+2]=tmp
			arr[Mesh.ARRAY_INDEX]=J
		gesamt+=arr[Mesh.ARRAY_INDEX].size()/3
		flaechen.append([mat,arr])
	# Grundstufe begrenzen
	var basis_c=0.0
	if gesamt>max_tris:
		for c in [0.003,0.006,0.01,0.016,0.025,0.04,0.06]:
			var s=0
			for f in flaechen:s+=VE.cluster(f[1],f[1][Mesh.ARRAY_INDEX],c,64.0).size()/3
			basis_c=c
			if s<=max_tris:break
		for f in flaechen:f[1][Mesh.ARRAY_INDEX]=VE.cluster(f[1],f[1][Mesh.ARRAY_INDEX],basis_c,64.0)
	var am=ArrayMesh.new()
	for f in flaechen:
		var arr=f[1];var I:PackedInt32Array=arr[Mesh.ARRAY_INDEX]
		if I.size()<3:continue
		var lods={};var vor=I.size()
		for c in STUFEN:
			if c<=basis_c:continue
			var L=VE.cluster(arr,I,c,32.0)
			if L.size()<3 or L.size()>vor*0.8:continue
			lods[c]=L;vor=L.size()
		var ks=lods.keys();var kp=VE.kompakt(arr,[I]+ks.map(func(x):return lods[x]))
		arr=kp[0];lods={}
		for j in ks.size():lods[ks[j]]=kp[1][j+1]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr,[],lods)
		am.surface_set_material(am.get_surface_count()-1,f[0])
	weg.sort_custom(func(a,b):return a.get_path().get_name_count()>b.get_path().get_name_count() if a.is_inside_tree() else false)
	for m in weg:
		if is_instance_valid(m):
			for ch in m.get_children():m.remove_child(ch);m.get_parent().add_child(ch)
			m.get_parent().remove_child(m);m.free()
	# leere Zwischenknoten aufräumen
	_leer_weg(quelle)
	var mi=MeshInstance3D.new();mi.name=name;mi.mesh=am;ziel.add_child(mi)

func _unter_rad(m:Node,root:Node)->bool:
	var c=m.get_parent()
	while c!=null and c!=root:
		if str(c.name).begins_with("Rad_"):return true
		c=c.get_parent()
	return false

func _leer_weg(n:Node):
	for c in n.get_children():
		if str(c.name).begins_with("Rad_"):continue
		_leer_weg(c)
		if c.get_child_count()==0 and c.get_class()=="Node3D" and c.get_script()==null:
			n.remove_child(c);c.free()
