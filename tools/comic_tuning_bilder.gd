extends SceneTree
# Prototypbilder: neue Autos serienmäßig und getunt
const OUT:="/home/claude/work/tuning/"
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var W=Node3D.new();root.add_child(W)
	var L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L._umgebung()
	L.box(L.M.pflaster,Vector3(0,-0.05,0),Vector3(400,0.1,400),Basis(),0.0)
	var autos=[
		["jdm_serie",func(t):L._jdm(t,Color(0.85,0.86,0.88))],
		["jdm_tuning",func(t):L._jdm(t,Color(0.15,0.35,0.85),{"tief":0.06,"breit":0.05,"lippe":true,"schweller":true,"diffusor":true,"spoiler":"gt","felge":"kreuz","felgenfarbe":Color(0.95,0.8,0.2),"neon":Color(0.2,0.6,1.0)})],
		["kompakt_serie",func(t):L._kompakt(t,Color(0.85,0.2,0.18))],
		["kompakt_tuning",func(t):L._kompakt(t,Color(0.95,0.95,0.95),{"tief":0.07,"breit":0.03,"lippe":true,"schweller":true,"spoiler":"dach","felge":"tiefbett","felgenfarbe":Color(0.8,0.81,0.83),"neon":Color(0.3,1.0,0.4)})],
		["e30_serie",func(t):L._e30(t,Color(0.3,0.45,0.32))],
		["e30_tuning",func(t):L._e30(t,Color(0.12,0.12,0.14),{"tief":0.07,"breit":0.06,"lippe":true,"schweller":true,"diffusor":true,"spoiler":"ente","felge":"mesh","felgenfarbe":Color(0.9,0.75,0.3),"neon":Color(1.0,0.2,0.3)})],
		["luxus",func(t):L._luxus(t,Color(0.1,0.1,0.12))],
		["muscle",func(t):L._muscle(t,Color(0.9,0.45,0.08))],
		["suv",func(t):L._suv(t,Color(0.35,0.38,0.42))],
	]
	for i in autos.size():autos[i][1].call(Transform3D(Basis(),Vector3(i*16.0,0,0)))
	L._fertig()
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=35;W.add_child(cam);cam.current=true
	for i in autos.size():
		var c=Vector3(i*16.0,0.6,0)
		var ansichten=[["vorn",Vector3(4.6,1.6,6.0)],["hinten",Vector3(-4.6,1.8,-6.2)]]
		if autos[i][0].ends_with("tuning"):ansichten.append(["tief",Vector3(3.0,0.5,4.8)])
		for v in ansichten:
			cam.look_at_from_position(c+v[1],c)
			for k in 4:await process_frame
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(OUT+"%s_%s.png"%[autos[i][0],v[0]])
	print("FERTIG")
	quit()
