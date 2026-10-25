extends SceneTree
const F=preload("res://scripts/fit.gd")
func _init():
	for p in ["res://assets/buildings/stash/stash.gltf","res://assets/buildings/ghetto/ghetto.gltf","res://assets/buildings/house/house.gltf","res://assets/buildings/building/building.gltf","res://assets/props/tree/tree.gltf","res://assets/props/busstop/busstop.gltf"]:
		if not ResourceLoader.exists(p):print("fehlt ",p);continue
		var n=load(p).instantiate();root.add_child(n)
		var ab=F.aabb(n);print(p.get_file()," ",ab.position.snapped(Vector3.ONE*0.01)," ",ab.size.snapped(Vector3.ONE*0.01))
		var c=0
		for m in n.find_children("*","MeshInstance3D",true,false):c+=m.mesh.get_faces().size()/3
		print("  tris ",c)
	quit()
