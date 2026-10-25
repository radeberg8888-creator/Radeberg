extends SceneTree
func _init():
	for p in ["res://assets/characters/biker/biker.gltf","res://assets/characters/daya/daya.gltf","res://assets/animations/walking.glb"]:
		var n=load(p).instantiate();var s:Skeleton3D=n.find_children("*","Skeleton3D",true,false)[0]
		var names=[];for i in s.get_bone_count():names.append(s.get_bone_name(i))
		print(p.get_file()," ",names)
		var ap=n.find_children("*","AnimationPlayer",true,false);if ap.size()>0:print(" anims ",ap[0].get_animation_list())
	quit()
