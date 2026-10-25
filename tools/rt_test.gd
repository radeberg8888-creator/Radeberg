extends SceneTree
func _init():
	var U=load("res://scripts/anim_util.gd")
	var src=load("res://assets/animations/xbot_anims.glb").instantiate()
	var ap=src.find_child("AnimationPlayer",true,false);var an=ap.get_animation("idle");var ssk=U.find_skel(src)
	var ch=load("res://assets/characters/joe/joe_rig.gltf").instantiate();var sk=U.find_skel(ch)
	U.retarget_world(an,ssk,src,sk,ch)
	quit()
