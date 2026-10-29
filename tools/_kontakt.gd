extends SceneTree
# Kontaktbogen: jede Gebäudevorlage von vorn-schräg und hinten-schräg
const OUT="/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/kb/"
func _init():
	await process_frame
	var w=Node3D.new();root.add_child(w)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.6,0.7,0.8);env.environment.ambient_light_color=Color(0.7,0.7,0.7);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;w.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,30,0);w.add_child(sun)
	var B=load("res://scripts/welt_bauten.gd").new(load("res://scripts/welt_gelaende.gd").new(),null)
	var cam=Camera3D.new();w.add_child(cam);cam.fov=55
	var boden=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(600,600);boden.mesh=pm;w.add_child(boden)
	var namen=B._meta().keys()
	if OS.get_cmdline_user_args().size()>0:namen=OS.get_cmdline_user_args()
	for n in namen:
		var t=B.get_tpl(n)
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=load("res://assets/cache/geb/"+n+".res");mm.instance_count=1
		mm.set_instance_color(0,Color(1,1,1));mm.set_instance_transform(0,Transform3D())
		var node=MultiMeshInstance3D.new();node.multimesh=mm;w.add_child(node)
		var s=t.ab.size;var d=max(s.x,max(s.y,s.z))*1.05+8
		for j in 2:
			var sg=1.0 if j==0 else -1.0
			cam.position=Vector3(d*0.55*sg,s.y*0.45+d*0.25,d*0.8*sg);cam.look_at(Vector3(0,s.y*0.4,0))
			for k in 4:await process_frame
			root.get_viewport().get_texture().get_image().save_png(OUT+n+"_"+str(j)+".png")
		node.free()
	quit()
