extends SceneTree
func _init():
	await process_frame
	var PE=load("res://scripts/people.gd");var U=load("res://scripts/anim_util.gd")
	var r=RandomNumberGenerator.new()
	for b in ["joe","female"]:
		var p=PE.make(b,r);root.add_child(p);var sk:Skeleton3D=U.find_skel(p)
		var ap:AnimationPlayer=p.get_meta("anim");ap.play("run");ap.seek(0.0,true);ap.advance(0)
		await process_frame
		var idx={}
		for i in sk.get_bone_count():idx[U.human_key(sk.get_bone_name(i))]=i
		var g=func(k):return sk.global_transform*sk.get_bone_global_pose(idx[k]).origin
		print("ARM ",b," oberarm ",(g.call("LeftForeArm")-g.call("LeftArm")).normalized()," unterarm ",(g.call("LeftHand")-g.call("LeftForeArm")).normalized(), " schulter ",g.call("LeftArm"))
	quit()
