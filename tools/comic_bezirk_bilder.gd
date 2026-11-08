extends SceneTree
# Prototyp: großes Ghetto entlang der Original-Straßen, als Bilder.
const OUT:="/home/claude/work/bezirk/"
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var W=Node3D.new();root.add_child(W)
	var L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L._umgebung()
	for n in W.get_children():
		if n is DirectionalLight3D:n.directional_shadow_max_distance=160.0
	L.hoehen_an=false
	var GL=load("res://scripts/comic/ghetto_lib.gd").new(L)
	var BZ=load("res://scripts/comic/bezirk_lib.gd").new(L,GL)
	BZ.laden("/home/claude/work/karte.json",Rect2(-1300,790,1500,560),[Rect2(-680,190,960,612)])
	BZ.bauen();L._fertig()
	# Autos am Straßenrand
	var CA=load("res://scripts/comic/comic_autos.gd")
	var kinds=["c_wartburg_beige","c_muscle_orange","c_muscle_schwarz","c_e30_gruen","c_luxus_schwarz","c_trabant_beige","c_kompakt_rot","c_suv_grau"]
	var rng=RandomNumberGenerator.new();rng.seed=3;var na=0
	for ri in BZ.ROADS.size():
		var r=BZ.ROADS[ri];if r.typ=="gasse":continue
		var s=8.0
		while s<r.S[-1]-8.0:
			s+=rng.randf_range(9,22)
			if rng.randf()>0.35:continue
			var b=BZ.bei(r,s);var p:Vector2=b[0];var t:Vector2=b[1];var sd=[-1,1][rng.randi()%2];var n=Vector2(-t.y,t.x)*sd
			var q=p+n*(r.w-1.15)
			# Auto muss ganz auf der eigenen Fahrbahn stehen und weg von Kreuzungen
			var ok=true
			for e in [q+t*2.4+n*1.0,q-t*2.4+n*1.0,q+t*2.4-n*1.0,q-t*2.4-n*1.0]:
				var ns=BZ.naechst(e)
				if ns[2]!=ri or ns[3]>r.w-0.15:ok=false
			if not ok or BZ.auf_fahrbahn(q,ri,8.0):continue
			var h=t*(-sd);var c=CA.bauen(kinds[rng.randi()%kinds.size()]);W.add_child(c);c.transform=Transform3D(Basis(Vector3.UP,atan2(h.x,h.y)),Vector3(q.x,0.015,q.y));na+=1
	print("AUTOS ",na)
	for n in W.get_children():
		if n is WorldEnvironment:n.environment.fog_density*=0.35
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=62;cam.far=4000;W.add_child(cam);cam.current=true
	var V=[]
	V.append(["uebersicht",Vector3(-1350,320,1500),Vector3(-560,0,1000)])
	V.append(["schraeg_nah",Vector3(-560,75,1180),Vector3(-470,0,1040)])
	V.append(["uebersicht2",Vector3(-200,170,1420),Vector3(-650,0,1000)])
	# Straßenansichten: Stellen mit Kurven
	var kand=[]
	for ri in BZ.ROADS.size():
		var r=BZ.ROADS[ri];if r.typ=="gasse" or r.S[-1]<80:continue
		for s in range(20,int(r.S[-1])-50,15):
			var a=BZ.bei(r,s)[1];var e=BZ.bei(r,s+40)[1]
			kand.append([abs(a.angle_to(e)),ri,s])
	kand.sort_custom(func(x,y):return x[0]>y[0])
	var genutzt=[]
	for k in kand:
		if V.size()>=9:break
		var r=BZ.ROADS[k[1]];var b=BZ.bei(r,k[2]);var p:Vector2=b[0]
		var weit=true
		for g in genutzt:
			if g.distance_to(p)<180:weit=false
		if not weit:continue
		genutzt.append(p)
		var t:Vector2=b[1];var n=Vector2(-t.y,t.x);var e=BZ.bei(r,k[2]+45)[0]
		V.append(["strasse_%d"%V.size(),Vector3(p.x+n.x*1.8,2.4,p.y+n.y*1.8),Vector3(e.x,1.8,e.y)])
	var cl=CanvasLayer.new();root.add_child(cl)
	for v in V:
		cam.look_at_from_position(v[1],v[2])
		for f in 4:await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT+v[0]+".png");print("BILD ",v[0])
	quit()
