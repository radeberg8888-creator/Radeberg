extends SceneTree
func _init():
	await process_frame
	var PE=load("res://scripts/people.gd")
	var w=Node3D.new();root.add_child(w)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.6,0.7,0.8);env.environment.ambient_light_color=Color(0.8,0.8,0.8);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;w.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,40,0);w.add_child(sun)
	var anim=OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else "run"
	var ks=["joe","biker","daya","female","hqman","woman","aiman","police"]
	var r=RandomNumberGenerator.new();r.seed=3
	var ps=[]
	for i in ks.size():
		var p=PE.make(ks[i],r);w.add_child(p);p.position=Vector3(i*1.6-5.6,0,0);p.rotation.y=PI*0.5
		PE.play(p,anim,0.3);ps.append(p)
	var cam=Camera3D.new();w.add_child(cam);cam.position=Vector3(0,1.2,7.5);cam.look_at(Vector3(0,0.9,0))
	for k in 20:await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/lauf_"+anim+".png")
	quit()
