extends SceneTree
# Einzelbilder der Comic-Autos (wie im Spiel gebaut): vorn-schräg und hinten-schräg
const OUT:="/home/claude/work/autos/"
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var W=Node3D.new();root.add_child(W)
	var L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L._umgebung()
	L.box(L.M.pflaster,Vector3(0,-0.05,0),Vector3(200,0.1,200),Basis(),0.0)
	var autos=[["sport",func(t):L._sport(t,Color(0.95,0.18,0.12))],["wartburg",func(t):L._wartburg(t,Color(0.86,0.78,0.52))],
		["taxi",func(t):L._taxi(t)],["trabant",func(t):L._trabant(t,Color(0.62,0.72,0.22),Color(0.96,0.95,0.9))],["polizei",func(t):L._polizei(t)]]
	var nur=OS.get_cmdline_user_args()
	if nur.size()>0:autos=autos.filter(func(a):return a[0] in nur)
	for i in autos.size():autos[i][1].call(Transform3D(Basis(),Vector3(i*14.0,0,0)))
	L._fertig()
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=35;W.add_child(cam);cam.current=true
	for i in autos.size():
		var c=Vector3(i*14.0,0.6,0)
		for v in [["vorn",Vector3(4.2,1.7,5.6)],["hinten",Vector3(-4.2,1.9,-5.8)],["seite",Vector3(7.5,0.9,0.0)],["tief",Vector3(2.6,0.75,4.6)]]:
			cam.look_at_from_position(c+v[1],c)
			for k in 4:await process_frame
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(OUT+"%s_%s.png"%[autos[i][0],v[0]]);print("BILD ",autos[i][0],v[0])
	quit()
