extends SceneTree
# Ansichten des gebackenen Ghettos (wie im Spiel, mit geparkten Autos). Aufruf: -- name (optional)
const OUT:="/home/claude/work/ghetto/"
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var w=load("res://assets/cache/comic/welt.scn").instantiate();root.add_child(w);w.aus_cache()
	w.viertel_jetzt(Vector2(-300,900))
	var u=Node3D.new();root.add_child(u);load("res://scripts/env.gd").make(u,"day")
	var AUTO=load("res://scripts/spiel/fahrzeug.gd")
	var cam=Camera3D.new();cam.fov=62;cam.far=3000;root.add_child(cam);cam.current=true
	root.get_viewport().msaa_3d=Viewport.MSAA_4X
	var S=w.S
	var V=[]
	var rp=func(n:String,f:float,hoch:float,vor:float,seit:=0.0,ziel_h:=1.2)->Array:
		var r=S.roads_by_name(n);var L=S.length(r);var a=S.at(r,L*f);var b=S.at(r,min(L*f+vor,L-1));var p:Vector2=a[0];var q:Vector2=b[0];var t:Vector2=a[2];var nn=Vector2(-t.y,t.x)
		return [Vector3(p.x+nn.x*seit,a[1]+hoch,p.y+nn.y*seit),Vector3(q.x,b[1]+ziel_h,q.y)]
	var e
	e=rp.call("Grove Street",0.3,3.0,45.0,1.5);V.append(["grove_strasse",e[0],e[1]])
	e=rp.call("Kohlenstraße",0.62,2.0,40.0,-2.0);V.append(["kohlen_strasse",e[0],e[1]])
	e=rp.call("Gasse 1-1",0.2,2.2,35.0);V.append(["gasse",e[0],e[1]])
	e=rp.call("Gasse 2-2",0.7,2.2,35.0);V.append(["gasse2",e[0],e[1]])
	e=rp.call("Grove-Allee",0.05,3.0,40.0);V.append(["einfahrt_nord",e[0],e[1]])
	e=rp.call("grove_zubringer",0.2,3.0,60.0) if not S.roads_by_name("grove_zubringer").is_empty() else null
	if e:V.append(["zubringer",e[0],e[1]])
	e=rp.call("Weststraße",0.4,3.0,40.0);V.append(["weststrasse",e[0],e[1]])
	e=rp.call("Grenzweg",0.5,3.0,40.0,2.0);V.append(["grenzweg",e[0],e[1]])
	e=rp.call("Bahndamm",0.4,3.0,40.0,2.0);V.append(["bahndamm",e[0],e[1]])
	V.append(["ring_einmuendung",Vector3(-318,10.5,645),Vector3(-330,7,720)])
	V.append(["westring_uebergang",Vector3(-496,10,760),Vector3(-500,7,830)])
	V.append(["ecke_nw",Vector3(-640,10,795),Vector3(-660,7,830)])
	V.append(["luft",Vector3(-520,110,690),Vector3(-330,0,950)])
	V.append(["luft_nah",Vector3(-330,38,1000),Vector3(-300,0,930)])
	var nur=OS.get_cmdline_user_args()
	for v in V:
		if nur.size()>0 and not v[0] in nur:continue
		var autos=[]
		for p in w.PARKEN:
			if p[1].origin.distance_to(v[1])<110.0:
				var c=AUTO.new();root.add_child(c);c.setup(p[0]);c.global_transform=p[1];c.freeze=true;autos.append(c)
		cam.look_at_from_position(v[1],v[2])
		for k in 4:await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(OUT+v[0]+".png");print("BILD ",v[0])
		for c in autos:c.queue_free()
	quit()
