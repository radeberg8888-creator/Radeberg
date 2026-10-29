extends SceneTree
const OUT="/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/ab/"
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var w=Node3D.new();root.add_child(w)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.6,0.7,0.8);env.environment.ambient_light_color=Color(0.7,0.7,0.7);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;w.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,30,0);w.add_child(sun)
	var boden=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(200,200);boden.mesh=pm;w.add_child(boden)
	var cam=Camera3D.new();w.add_child(cam);cam.fov=45
	root.get_viewport().mesh_lod_threshold=2.5
	for f in DirAccess.get_files_at("res://assets/cache/autos/"):
		if not f.ends_with(".scn"):continue
		var n=load("res://assets/cache/autos/"+f).instantiate();w.add_child(n)
		var ab=load("res://scripts/fit.gd").aabb(n);var c=ab.get_center()
		var views=[Vector3(0.9,0.45,1.3),Vector3(-1.4,0.3,0.0),Vector3(-0.8,0.5,-1.3),Vector3(6,2.5,9)]
		for j in views.size():
			var d=max(ab.size.x,ab.size.z)*1.0+1.5
			cam.position=c+views[j]*d*(0.75 if j<3 else 1.0);cam.look_at(c)
			for k in 4:await process_frame
			root.get_viewport().get_texture().get_image().save_png(OUT+f.get_basename()+"_"+str(j)+".png")
		n.free()
	quit()
