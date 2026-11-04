extends SceneTree
# Ansichten der gebackenen Comic-Welt (wie im Spiel): Rampen, Einfädeln, geparkte Autos. Aufruf: -- name=... (optional)
const OUT:="/home/claude/work/ansicht/"
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var w=load("res://assets/cache/comic/welt.scn").instantiate();root.add_child(w);w.aus_cache()
	var u=Node3D.new();root.add_child(u);load("res://scripts/env.gd").make(u,"day")
	var AUTO=load("res://scripts/spiel/fahrzeug.gd")
	var cam=Camera3D.new();cam.fov=62;cam.far=3000;root.add_child(cam);cam.current=true
	root.get_viewport().msaa_3d=Viewport.MSAA_4X
	var V=[]
	for r in w.S.roads:
		if r.typ=="rampe" and r.P.size()>30:
			for f in [0.25,0.6]:
				var i=int(r.P.size()*f);var j=min(i+6,r.P.size()-1)
				var p:Vector2=r.P[i];var q:Vector2=r.P[j]
				V.append(["rampe_"+r.name.replace(" ","_")+"_%d"%int(f*100),Vector3(p.x,r.h[i]+2.6,p.y)-Vector3(q.x-p.x,0,q.y-p.y).normalized()*6.0,Vector3(q.x,r.h[j]+0.8,q.y)])
	var strassen={"ew2":0.45,"ns1":0.4,"allee":0.5,"ring":0.2}
	for r in w.S.roads:
		if strassen.has(r.name):
			var i=int(r.P.size()*strassen[r.name]);var j=min(i+8,r.P.size()-1)
			var p:Vector2=r.P[i];var q:Vector2=r.P[j]
			V.append(["parken_"+r.name,Vector3(p.x,r.h[i]+3.2,p.y),Vector3(q.x,r.h[j]+0.5,q.y)])
	V.append(["luft_stadt",Vector3(-200,260,800),Vector3(-200,0,480)])
	var nur=OS.get_cmdline_user_args()
	for v in V:
		if nur.size()>0 and not v[0].begins_with(nur[0]):continue
		# geparkte Autos nur in der Nähe aufstellen (wie im Spiel)
		var autos=[]
		for e in w.PARKEN:
			if e[1].origin.distance_to(v[1])<130.0:
				var c=AUTO.new();root.add_child(c);c.setup(e[0]);c.global_transform=e[1];c.freeze=true;autos.append(c)
		cam.look_at_from_position(v[1],v[2])
		for k in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(OUT+v[0]+".png");print("BILD ",v[0])
		for c in autos:c.queue_free()
	quit()
