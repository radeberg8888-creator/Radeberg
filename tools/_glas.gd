extends SceneTree
func _init():
	for f in DirAccess.get_files_at("res://assets/cache/autos/"):
		if not f.ends_with(".scn"):continue
		var n=load("res://assets/cache/autos/"+f).instantiate();var gl=[]
		for m in n.find_children("*","MeshInstance3D",true,false):
			for s in m.mesh.get_surface_count():
				var mt=m.get_active_material(s)
				if mt is BaseMaterial3D:
					var nm=mt.resource_name.to_lower()
					if mt.transparency!=0 or nm.contains("glass") or nm.contains("window") or nm.contains("glas"):
						gl.append("%s(t%d a%.2f %s)"%[mt.resource_name,mt.transparency,mt.albedo_color.a,"tex" if mt.albedo_texture else ""])
		print("GLAS ",f," ",gl)
		n.free()
	quit()
