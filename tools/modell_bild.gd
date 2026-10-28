extends SceneTree
# Vorschaubild eines Modells: godot -s tools/modell_bild.gd -- res://pfad.gltf [name] [blick_hoehe 0..1]
func _init():
	await process_frame
	var a=OS.get_cmdline_user_args()
	var F=load("res://scripts/fit.gd")
	var w=Node3D.new();root.add_child(w)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.78,0.84,0.9)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(0.75,0.75,0.75);w.add_child(env)
	var sun=DirectionalLight3D.new();w.add_child(sun);sun.rotation_degrees=Vector3(-45,35,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=5000
	var n=load(a[0]).instantiate();w.add_child(n)
	await process_frame
	var ab:AABB=F.aabb(n)
	var c=ab.get_center();var r=ab.size.length()*0.5
	var hf=float(a[2]) if a.size()>2 else 0.45
	var cam=Camera3D.new();w.add_child(cam);cam.fov=45;cam.far=r*20;cam.near=max(0.01,r*0.002)
	cam.position=c+Vector3(r*1.3,r*(0.2+hf*2.0),r*1.6);cam.look_at(c)
	cam.current=true
	print("AABB ",ab)
	for i in 30:await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots_godot/m_"+(a[1] if a.size()>1 else "modell")+".png")
	quit()
