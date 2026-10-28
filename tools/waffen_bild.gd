extends SceneTree
# Prüfbild aller vorbereiteten Waffen (Seitenansicht): rot = Griff, blau = Stützhand, grün = Mündung
func _kugel(p:Node3D,pos:Vector3,c:Color):
	var m=MeshInstance3D.new();var s=SphereMesh.new();s.radius=0.02;s.height=0.04;m.mesh=s;p.add_child(m);m.position=pos
	var mt=StandardMaterial3D.new();mt.albedo_color=c;mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.no_depth_test=true;m.material_override=mt
func _init():
	await process_frame
	var W=load("res://scripts/spiel/waffen_daten.gd")
	var w=Node3D.new();root.add_child(w)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.85,0.88,0.92)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(0.8,0.8,0.8);w.add_child(env)
	var sun=DirectionalLight3D.new();w.add_child(sun);sun.rotation_degrees=Vector3(-40,60,0)
	var i=0
	for id in W.REIHE:
		var p="res://assets/cache/waffen/"+id+".scn"
		if not ResourceLoader.exists(p):continue
		var n=load(p).instantiate();w.add_child(n)
		n.position=Vector3(0,-(i/3)*0.55,(i%3)*1.4-1.4)
		_kugel(n,Vector3.ZERO,Color(1,0,0));_kugel(n,n.get_meta("vorn"),Color(0,0,1));_kugel(n,n.get_meta("muendung"),Color(0,0.8,0))
		var lb=Label3D.new();lb.text=id;lb.font_size=40;lb.pixel_size=0.002;lb.modulate=Color(0,0,0);w.add_child(lb);lb.position=n.position+Vector3(0.2,0.18,0);lb.rotation.y=PI*0.5
		i+=1
	var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=3.6;w.add_child(cam)
	cam.position=Vector3(5,-1.35,0);cam.look_at(Vector3(0,-1.35,0));cam.current=true
	for k in 40:await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots_godot/waffen.png")
	quit()
