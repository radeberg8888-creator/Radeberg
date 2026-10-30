extends SceneTree
func _init():
	var PE=load("res://scripts/people.gd");var U=load("res://scripts/anim_util.gd")
	var r=RandomNumberGenerator.new()
	var p=PE.make("female",r);var sk:Skeleton3D=U.find_skel(p)
	for i in sk.get_bone_count():
		var k=U.human_key(sk.get_bone_name(i))
		if k in ["LeftShoulder","LeftArm","LeftForeArm","LeftHand","Spine2"]:
			print("B ",k," ",sk.get_bone_name(i)," parent ",sk.get_bone_name(sk.get_bone_parent(i))," scale ",sk.get_bone_global_rest(i).basis.get_scale())
	quit()
