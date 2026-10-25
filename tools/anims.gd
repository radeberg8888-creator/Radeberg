extends SceneTree
func _init():
	for p in ["res://assets/animations/xbot_anims.glb","res://assets/characters/soldier.glb","res://assets/characters/michelle.glb","res://assets/characters/daya/daya.gltf","res://assets/characters/female/female.gltf","res://assets/animations/walking.glb"]:
		var n=load(p).instantiate()
		for ap in n.find_children("*","AnimationPlayer",true,false):
			var o=[];for a in ap.get_animation_list():o.append(a+":"+str(snapped(ap.get_animation(a).length,0.01)))
			print("AN ",p.get_file()," ",o)
	quit()
