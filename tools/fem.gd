extends SceneTree
func _init():
	var n=load("res://assets/characters/female/female.gltf").instantiate()
	for s in n.find_children("*","Skeleton3D",true,false):print("SK ",s.get_path()," ",s.get_bone_count()," ",s.get_bone_name(0))
	for m in n.find_children("*","MeshInstance3D",true,false):print("MI ",m.name," skel=",m.skeleton," mat=",m.get_active_material(0).resource_name if m.get_active_material(0) else "", " tex=",m.get_active_material(0).albedo_texture.resource_path if m.get_active_material(0) and m.get_active_material(0).albedo_texture else "")
	quit()
