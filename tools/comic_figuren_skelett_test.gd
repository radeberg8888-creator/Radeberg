extends SceneTree
# Prüfbild: Comic-Körper am Skelett der Spielfiguren (people.gd), mit den Spiel-Animationen
const OUT:="/home/claude/work/figuren/"
func _init():
	await process_frame
	var W=Node3D.new();root.add_child(W)
	var L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L._umgebung()
	L.box(L.M.pflaster,Vector3(0,-0.05,0),Vector3(60,0.1,60),Basis(),0.0);L._fertig()
	var PE=load("res://scripts/people.gd");var CF=load("res://scripts/comic/comic_figur.gd");CF.aktiv=true
	var r=RandomNumberGenerator.new();r.seed=7
	var t0=Time.get_ticks_msec()
	var figs=[["joe","idle",{"c_haut":Color(0.8,0.58,0.42),"c_haar":Color(0.12,0.08,0.05),"mix":0.0}],["female","walk",{}],["police","idle",{}],["biker","run",{}],["daya","walk",{}],["hqman","talk",{}]]
	for i in figs.size():
		var f=figs[i]
		var p=PE.make(f[0],r,f[2]);W.add_child(p);p.position=Vector3(-3.75+i*1.5,0,0)
		if f[1]!="idle":p.rotation.y=PI*0.5
		PE.play(p,f[1],0.3)
	print("FIGUREN ms ",Time.get_ticks_msec()-t0)
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=34;W.add_child(cam);cam.current=true
	cam.look_at_from_position(Vector3(0,1.2,10.5),Vector3(0,0.9,0))
	for k in 20:await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT+"5_im_spiel_skelett.png")
	cam.look_at_from_position(Vector3(-3.75,1.5,3.2),Vector3(-3.75,1.2,0))
	for k in 4:await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT+"6_spieler_skelett_nah.png")
	print("FERTIG")
	quit()
