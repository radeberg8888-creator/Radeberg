extends SceneTree
# Schwere Fremdmodelle vereinfachen (Godot-LOD-Erzeugung) und als leichte Szenen speichern: assets/cache/leicht/<name>.scn
const LISTE={"res://assets/props/neu/bank/bank.gltf":2500,"res://assets/props/neu/muelleimer/muelleimer.gltf":1500,
	"res://assets/props/neu/hubwagen/hubwagen.gltf":6000,"res://assets/props/neu/bruecke/bruecke.gltf":15000,"res://assets/props/neu/park/park.gltf":120000}
func _init():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/cache/leicht/"))
	for pfad in LISTE:
		var src:Node3D=load(pfad).instantiate()
		var ziel=LISTE[pfad];var gesamt=0
		var mis=src.find_children("*","MeshInstance3D",true,false)
		for mi in mis:gesamt+=_tris(mi.mesh)
		var faktor=clamp(float(ziel)/max(gesamt,1),0.0,1.0)
		var root=Node3D.new();root.name=pfad.get_file().get_basename()
		var neu=0
		for mi in mis:
			var am:Mesh=mi.mesh;var out=ArrayMesh.new()
			for s in am.get_surface_count():
				var arr=am.surface_get_arrays(s)
				for k in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:arr[k]=null
				var im=ImporterMesh.new();im.add_surface(Mesh.PRIMITIVE_TRIANGLES,arr)
				im.generate_lods(80.0,180.0,[])
				var basis_n=arr[Mesh.ARRAY_INDEX].size()/3 if arr[Mesh.ARRAY_INDEX]!=null else arr[Mesh.ARRAY_VERTEX].size()/3
				var soll=basis_n*faktor;var idx=arr[Mesh.ARRAY_INDEX]
				for l in im.get_surface_lod_count(0):
					var li=im.get_surface_lod_indices(0,l)
					idx=li
					if li.size()/3<=soll:break
				var a2=arr.duplicate();a2[Mesh.ARRAY_INDEX]=idx
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a2)
				var mat=mi.get_active_material(s)
				if mat:out.surface_set_material(s,mat)
				neu+=idx.size()/3
			var n=MeshInstance3D.new();n.mesh=out;n.name=mi.name;root.add_child(n);n.owner=root
			n.transform=_rel(mi,src)
		var ps=PackedScene.new();ps.pack(root)
		var dat="res://assets/cache/leicht/"+pfad.get_file().get_basename()+".scn"
		ResourceSaver.save(ps,dat,ResourceSaver.FLAG_COMPRESS)
		print("LEICHT ",pfad.get_file()," ",gesamt," -> ",neu," Dreiecke")
	quit()
func _tris(m:Mesh)->int:
	var t=0
	for s in m.get_surface_count():
		var a=m.surface_get_arrays(s)
		t+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null else a[Mesh.ARRAY_VERTEX].size())/3
	return t
func _rel(n:Node,root:Node)->Transform3D:
	var t=Transform3D.IDENTITY;var c=n
	while c!=null and c!=root:
		if c is Node3D:t=c.transform*t
		c=c.get_parent()
	return t
