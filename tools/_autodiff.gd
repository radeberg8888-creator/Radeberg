extends SceneTree
const OUT="/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/diff/"
func _init():
	await process_frame
	var w=Node3D.new();root.add_child(w)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.6,0.7,0.8);env.environment.ambient_light_color=Color(0.7,0.7,0.7);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;w.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,30,0);w.add_child(sun)
	var cam=Camera3D.new();w.add_child(cam);cam.fov=50
	root.get_viewport().mesh_lod_threshold=2.5
	var erg=[]
	for f in DirAccess.get_files_at("res://assets/cache/_alt/"):
		if not f.ends_with(".scn"):continue
		var bilder=[]
		for j in 2:
			var n=load(("res://assets/cache/_alt/" if j==0 else "res://assets/cache/autos/")+f).instantiate();w.add_child(n)
			var ab=load("res://scripts/fit.gd").aabb(n);var d=max(ab.size.x,ab.size.z)*1.0+2
			cam.position=ab.get_center()+Vector3(d*0.7,d*0.35,d*0.8);cam.look_at(ab.get_center())
			for k in 6:await process_frame
			bilder.append(root.get_viewport().get_texture().get_image());n.free()
		var a:Image=bilder[0];var b:Image=bilder[1];var diff=0.0;var cnt=0
		for y in range(0,a.get_height(),3):
			for x in range(0,a.get_width(),3):
				var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y);diff+=abs(ca.r-cb.r)+abs(ca.g-cb.g)+abs(ca.b-cb.b);cnt+=1
		diff/=cnt;erg.append([diff,f])
		var c=Image.create(a.get_width()*2,a.get_height(),false,a.get_format());c.blit_rect(a,Rect2i(Vector2i.ZERO,a.get_size()),Vector2i.ZERO);c.blit_rect(b,Rect2i(Vector2i.ZERO,b.get_size()),Vector2i(a.get_width(),0));c.save_png(OUT+"auto_"+f.get_basename()+".png")
	erg.sort();erg.reverse()
	for e in erg:print("ADIFF %.4f %s"%[e[0],e[1]])
	quit()
