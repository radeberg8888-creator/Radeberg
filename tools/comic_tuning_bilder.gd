extends SceneTree
# Prototypbilder: neue Autos serienmäßig und getunt
const OUT:="/home/claude/work/tuning/"
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var W=Node3D.new();root.add_child(W)
	var L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L._umgebung()
	L.box(L.M.pflaster,Vector3(0,-0.05,0),Vector3(400,0.1,400),Basis(),0.0)
	var ex=func(farbe:Color,felge:String,ff:Color,neon:Color,vinyl:Color,spoiler:="riesig")->Dictionary:
		return {"tief":0.08,"breit":0.12,"lippe":2,"schweller":2,"diffusor":2,"spoiler":spoiler,"felge":felge,"felgenfarbe":ff,"neon":neon,"vinyl":vinyl,"haube":true,"flares":false}
	var autos=[
		["jdm_extrem",func(t):L._jdm(t,Color(0.95,0.75,0.1),ex.call(Color(),"zehn",Color(0.1,0.1,0.11),Color(0.2,0.6,1.0),Color(0.12,0.12,0.14)))],
		["kompakt_extrem",func(t):L._kompakt(t,Color(0.2,0.75,0.95),ex.call(Color(),"fuenf",Color(0.95,0.95,0.95),Color(0.75,0.3,1.0),Color(0.95,0.95,0.95),"gt"))],
		["e30_extrem",func(t):L._e30(t,Color(0.85,0.12,0.12),ex.call(Color(),"mesh",Color(0.95,0.78,0.25),Color(1.0,0.2,0.3),Color(0.1,0.1,0.11)))],
		["trabant_serie",func(t):L._trabant(t,Color(0.62,0.72,0.22),Color(0.96,0.95,0.9))],
		["trabant_extrem",func(t):L._trabant(t,Color(0.3,0.9,0.35),Color(0.1,0.1,0.11),{"tief":0.06,"breit":0.08,"lippe":2,"schweller":2,"diffusor":2,"spoiler":"riesig","felge":"kreuz","felgenfarbe":Color(0.95,0.78,0.25),"neon":Color(0.3,1.0,0.4),"vinyl":Color(0.1,0.1,0.11)})],
	]
	for i in autos.size():autos[i][1].call(Transform3D(Basis(),Vector3(i*16.0,0,0)))
	L._fertig()
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=35;W.add_child(cam);cam.current=true
	for i in autos.size():
		var c=Vector3(i*16.0,0.6,0)
		var ansichten=[["vorn",Vector3(4.6,1.6,6.0)],["hinten",Vector3(-4.6,1.8,-6.2)]]
		if autos[i][0].ends_with("extrem"):ansichten.append(["tief",Vector3(3.0,0.5,4.8)])
		for v in ansichten:
			cam.look_at_from_position(c+v[1],c)
			for k in 4:await process_frame
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(OUT+"%s_%s.png"%[autos[i][0],v[0]])
	print("FERTIG")
	quit()
