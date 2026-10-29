extends SceneTree
const OUT="/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/diff/"
func _init():
	await process_frame
	var w=Node3D.new();root.add_child(w)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.6,0.7,0.8);env.environment.ambient_light_color=Color(0.7,0.7,0.7);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;w.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,30,0);w.add_child(sun)
	var B=load("res://scripts/welt_bauten.gd").new(load("res://scripts/welt_gelaende.gd").new(),null)
	var cam=Camera3D.new();w.add_child(cam);cam.fov=60
	root.get_viewport().mesh_lod_threshold=2.5
	var namen=B._meta().keys()
	if OS.get_cmdline_user_args().size()>0:namen=OS.get_cmdline_user_args()
	var erg=[]
	for n in namen:
		var t=B.get_tpl(n)
		var s=t.ab.size;var d=max(s.x,max(s.y,s.z))*1.1+10
		cam.position=Vector3(d*0.55,s.y*0.5+d*0.15,d*0.8);cam.look_at(Vector3(0,s.y*0.45,0))
		var bilder=[]
		for j in 2:
			var node:Node3D
			if j==0:node=B.instance(t,0,0.2)
			else:
				var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=load("res://assets/cache/geb/"+n+".res");mm.instance_count=1
				var tint=Color(1,1,1);var grime=Color(0.78,0.72,0.62).lerp(Color(1,1,1),0.8)
				mm.set_instance_color(0,Color(tint.r*grime.r,tint.g*grime.g,tint.b*grime.b));mm.set_instance_transform(0,Transform3D())
				node=MultiMeshInstance3D.new();node.multimesh=mm
			w.add_child(node)
			for k in 8:await process_frame
			bilder.append(root.get_viewport().get_texture().get_image())
			node.free()
		var a:Image=bilder[0];var b:Image=bilder[1]
		var diff=0.0;var cnt=0
		for y in range(0,a.get_height(),4):
			for x in range(0,a.get_width(),4):
				var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y)
				diff+=abs(ca.r-cb.r)+abs(ca.g-cb.g)+abs(ca.b-cb.b);cnt+=1
		diff/=cnt
		erg.append([diff,n])
		if diff>0.03:
			var c=Image.create(a.get_width()*2,a.get_height(),false,a.get_format());c.blit_rect(a,Rect2i(Vector2i.ZERO,a.get_size()),Vector2i.ZERO);c.blit_rect(b,Rect2i(Vector2i.ZERO,b.get_size()),Vector2i(a.get_width(),0))
			c.save_png(OUT+n+".png")
	erg.sort();erg.reverse()
	for e in erg:print("DIFF %.4f %s"%[e[0],e[1]])
	quit()
