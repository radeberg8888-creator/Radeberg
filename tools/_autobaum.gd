extends SceneTree
func _init():
	for k in OS.get_cmdline_user_args():
		var n:Node3D=load("res://assets/cache/autos/"+k+".scn").instantiate()
		print("== ",k," meta front=",n.get_meta("front",null))
		for c in n.find_children("*","Node3D",true,false):
			if c.get_parent()==n or str(c.name).to_lower().contains("rad") or str(c.name).to_lower().contains("wheel"):
				var ab=AABB()
				if c is MeshInstance3D:ab=c.get_aabb()
				print("  ",c.get_path(),"  pos=",c.position.snapped(Vector3.ONE*0.01)," ",c.get_class()," ",ab.size.snapped(Vector3.ONE*0.01))
	quit()
