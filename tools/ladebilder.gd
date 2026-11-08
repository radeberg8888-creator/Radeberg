extends SceneTree
# Rendert Szenen für den Ladebildschirm (danach Comic-Nachbearbeitung in tools/ladebilder_comic.py)
const OUT:="/home/claude/work/lade/"
const PE=preload("res://scripts/people.gd")
var CA
var W:Node3D
var env:Environment;var sun:DirectionalLight3D
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	W=Node3D.new();root.add_child(W)
	var welt=load("res://assets/cache/comic/welt.scn").instantiate();W.add_child(welt)
	CA=load("res://scripts/comic/comic_autos.gd")
	var we=WorldEnvironment.new();env=Environment.new();we.environment=env;W.add_child(we)
	env.background_mode=Environment.BG_SKY;var sky=Sky.new();var sm=ProceduralSkyMaterial.new();sky.sky_material=sm;env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.glow_enabled=true;env.glow_intensity=0.5
	sun=DirectionalLight3D.new();W.add_child(sun);sun.shadow_enabled=true;sun.directional_shadow_max_distance=120.0
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();W.add_child(cam);cam.current=true;cam.far=3000
	var nur=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nur="):nur=a.substr(6)
	for sz in _szenen():
		if nur!="" and nur!=sz.name:continue
		var tmp=Node3D.new();W.add_child(tmp)
		_kacheln(tmp,sz.ort)
		await physics_frame;await physics_frame
		sm.sky_top_color=sz.himmel[0];sm.sky_horizon_color=sz.himmel[1];sm.ground_horizon_color=sz.himmel[1]
		sun.rotation_degrees=Vector3(-sz.sonne[0],sz.sonne[1],0);sun.light_color=sz.sonne_farbe;sun.light_energy=sz.get("energie",1.3)
		var A=Vector3(sz.ort.x,_boden(sz.ort),sz.ort.y)
		var r=sz.richtung   # Blickachse der Szene (Yaw)
		var B=Basis(Vector3.UP,r)
		for o in sz.dinge:
			var p=A+B*o[1];p.y=_boden(Vector2(p.x,p.z))
			if o[0].begins_with("c_"):
				var c=CA.bauen(o[0]);tmp.add_child(c);c.global_position=p;c.rotation.y=r+o[2]
			else:
				var rng=RandomNumberGenerator.new();rng.seed=hash(o)
				var m=PE.make(o[0],rng);tmp.add_child(m);m.global_position=p;m.rotation.y=r+o[2]
				var ap:AnimationPlayer=m.get_meta("anim",null)
				if ap and ap.has_animation(o[3]):ap.play(o[3]);ap.seek(o[4] if o.size()>4 else 0.4,true);ap.pause()
		cam.fov=sz.get("fov",40.0)
		cam.look_at_from_position(A+B*sz.cam[0],A+B*sz.cam[1])
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT+sz.name+".png");print("BILD ",sz.name)
		tmp.queue_free();await process_frame
	quit()

func _kacheln(ziel:Node3D,ort:Vector2):
	for f in DirAccess.get_files_at("res://assets/cache/comic/"):
		if not f.begins_with("sued_") or not f.ends_with(".scn"):continue
		var t=f.trim_prefix("sued_").trim_suffix(".scn").split("_")
		var r=Rect2(int(t[0])*300.0-200.0,int(t[1])*300.0+500.0,300,300)
		if r.grow(350).has_point(ort):ziel.add_child(load("res://assets/cache/comic/"+f).instantiate())
func _boden(p:Vector2)->float:
	var q=PhysicsRayQueryParameters3D.create(Vector3(p.x,200,p.y),Vector3(p.x,-50,p.y))
	var h=root.get_world_3d().direct_space_state.intersect_ray(q)
	return h.position.y if h else 7.15

# dinge: [modell, Versatz (Szenenachse: -z = vorne/Kamera schaut hin), Drehung, Animation, Zeit]
func _szenen()->Array:
	return [
		{"name":"grove","ort":Vector2(-262,1040),"richtung":0.0,"himmel":[Color(0.35,0.45,0.75),Color(1.0,0.62,0.35)],"sonne":[12,-60],"sonne_farbe":Color(1,0.72,0.45),
			"dinge":[["c_muscle_orange",Vector3(0.5,0,-9),0.5],["joe",Vector3(-1.2,0,-6.2),0.25,"idle",0.6],["biker",Vector3(2.8,0,-7.0),-0.5,"talk",0.8],["hqman",Vector3(-3.0,0,-8.2),0.6,"idle",1.4]],
			"cam":[Vector3(0.3,0.75,0.5),Vector3(-0.2,1.5,-8)],"fov":44.0},
		{"name":"jagd","ort":Vector2(-150,1150),"richtung":PI*0.5,"himmel":[Color(0.08,0.1,0.25),Color(0.45,0.3,0.5)],"sonne":[8,120],"sonne_farbe":Color(0.6,0.65,1.0),"energie":0.7,
			"dinge":[["c_sport_rot",Vector3(0,0,-8),PI+0.15],["c_polizei",Vector3(-1.5,0,-16),PI+0.3],["c_polizei",Vector3(2.0,0,-24),PI-0.2]],
			"cam":[Vector3(-3.5,0.6,-2),Vector3(0,0.9,-12)],"fov":50.0},
		{"name":"docks","ort":Vector2(700,2195),"richtung":PI,"himmel":[Color(0.25,0.3,0.6),Color(1.0,0.5,0.3)],"sonne":[6,10],"sonne_farbe":Color(1,0.6,0.4),
			"dinge":[["hqman",Vector3(0,0,-5),0.0,"idle",0.2],["c_luxus_schwarz",Vector3(3.5,0,-8),0.8]],
			"cam":[Vector3(-1.0,0.9,1.0),Vector3(0.5,6.0,-14)],"fov":55.0},
		{"name":"strand","ort":Vector2(-2100,720),"richtung":0.0,"himmel":[Color(0.25,0.6,0.95),Color(0.75,0.9,1.0)],"sonne":[50,-30],"sonne_farbe":Color(1,0.97,0.9),
			"dinge":[["female",Vector3(0,0,-5.5),0.2,"dance",1.2],["c_sport_gelb",Vector3(3.5,0,-8),0.9]],
			"cam":[Vector3(0.5,1.0,0.5),Vector3(0.5,2.6,-10)],"fov":45.0},
		{"name":"flughafen","ort":Vector2(-2000,1900),"richtung":PI,"himmel":[Color(0.3,0.35,0.7),Color(1.0,0.7,0.45)],"sonne":[10,40],"sonne_farbe":Color(1,0.75,0.5),
			"dinge":[["c_luxus_silber",Vector3(1,0,-8),0.4],["daya",Vector3(-1.5,0,-6),0.1,"idle",0.9]],
			"cam":[Vector3(-2,1.2,3),Vector3(0,4,-25)],"fov":55.0},
	]
