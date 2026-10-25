extends SceneTree
# Listet Einzelgebäude in Stadt-Chunks: Gruppen von Meshes je oberstem Knoten
func _init():
	var F=load("res://scripts/fit.gd")
	for p in ["buildings/proc3","buildings/nycity","buildings/beautiful","buildings/seoul","buildings/city3","buildings/neighbourhood","buildings/cityscene"]:
		var n=load("res://assets/"+p+"/"+p.get_file()+".gltf").instantiate()
		var meshes=n.find_children("*","MeshInstance3D",true,false)
		var tot=F.aabb(n)
		print("== ",p," meshes=",meshes.size()," size=",tot.size.snapped(Vector3.ONE*0.1))
		var k=0
		for m in meshes:
			var a=F.rel_xf(m,n)*m.get_aabb()
			if a.size.y>0.08*tot.size.y and max(a.size.x,a.size.z)<0.6*max(tot.size.x,tot.size.z):
				k+=1
				if k<=40:print("  ",m.name," ",a.position.snapped(Vector3.ONE*0.1)," ",a.size.snapped(Vector3.ONE*0.1)," surf=",m.mesh.get_surface_count())
		print("  -> Kandidaten ",k)
	quit()
