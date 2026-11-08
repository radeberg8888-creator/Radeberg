extends SceneTree
# Freisteller für den Ladebildschirm: Figuren/Autos vor Grün gerendert, Comic-Nachbearbeitung in tools/ladebilder_comic.py
const OUT:="/home/claude/work/lade/"
const PE=preload("res://scripts/people.gd")
var CA
var W:Node3D
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	W=Node3D.new();root.add_child(W)
	CA=load("res://scripts/comic/comic_autos.gd")
	var we=WorldEnvironment.new();var env=Environment.new();we.environment=env;W.add_child(we)
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,1,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(0.55,0.5,0.6);env.ambient_light_energy=0.9
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var sun=DirectionalLight3D.new();W.add_child(sun);sun.shadow_enabled=false;sun.light_energy=1.5
	var rim=DirectionalLight3D.new();W.add_child(rim);rim.light_energy=1.2
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_8X
	var cam=Camera3D.new();W.add_child(cam);cam.current=true
	for sz in _szenen():
		var tmp=Node3D.new();W.add_child(tmp)
		sun.rotation_degrees=sz.licht[0];sun.light_color=sz.licht[1];rim.rotation_degrees=sz.licht[2];rim.light_color=sz.licht[3]
		for o in sz.dinge:
			if o[0].begins_with("c_"):
				var c=CA.bauen(o[0]);tmp.add_child(c);c.position=o[1];c.rotation.y=o[2]
			else:
				var rng=RandomNumberGenerator.new();rng.seed=hash(str(o))
				var m=PE.make(o[0],rng);tmp.add_child(m);m.position=o[1];m.rotation.y=o[2]
				var ap:AnimationPlayer=m.get_meta("anim",null)
				if ap and ap.has_animation(o[3]):ap.play(o[3]);ap.seek(o[4],true);ap.pause()
		cam.fov=sz.fov
		cam.look_at_from_position(sz.cam[0],sz.cam[1])
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT+"roh_"+sz.name+".png");print("BILD ",sz.name)
		tmp.queue_free();await process_frame
	quit()

const WARM:=Color(1,0.75,0.5)
const KALT:=Color(0.5,0.6,1.0)
func _szenen()->Array:
	return [
		{"name":"grove","fov":34.0,"licht":[Vector3(-25,-130,0),WARM,Vector3(-10,60,0),Color(0.6,0.4,1.0)],
			"dinge":[["c_muscle_orange",Vector3(1.6,0,-1.5),-0.9],["joe",Vector3(-0.9,0,0.6),0.35,"idle",0.6],["biker",Vector3(-2.4,0,-0.6),0.6,"talk",0.9]],
			"cam":[Vector3(-0.8,0.55,6.5),Vector3(0.0,1.25,0.0)]},
		{"name":"jagd","fov":40.0,"licht":[Vector3(-30,-40,0),Color(0.8,0.85,1.0),Vector3(-5,140,0),Color(1.0,0.3,0.3)],
			"dinge":[["c_sport_rot",Vector3(0,0,0),0.35],["c_polizei",Vector3(-1.8,0,-7.5),0.15],["c_polizei",Vector3(2.4,0,-13.5),0.5]],
			"cam":[Vector3(3.2,0.45,6.0),Vector3(-0.3,0.8,-4.0)]},
		{"name":"lauf","fov":32.0,"licht":[Vector3(-35,-150,0),WARM,Vector3(-10,40,0),KALT],
			"dinge":[["hqman",Vector3(0,0,0),0.25,"run",0.35]],
			"cam":[Vector3(0.6,0.45,4.6),Vector3(0,1.05,0)]},
		{"name":"strand","fov":34.0,"licht":[Vector3(-50,-60,0),Color(1,0.95,0.85),Vector3(-15,120,0),Color(0.4,0.8,1.0)],
			"dinge":[["female",Vector3(-0.6,0,0.4),0.3,"dance",1.4],["c_sport_gelb",Vector3(1.8,0,-1.6),-0.6]],
			"cam":[Vector3(-0.4,0.6,6.2),Vector3(0.3,1.2,0)]},
		{"name":"boss","fov":30.0,"licht":[Vector3(-20,-110,0),Color(1,0.85,0.7),Vector3(-5,70,0),Color(0.9,0.3,0.8)],
			"dinge":[["daya",Vector3(0.4,0,0.6),-0.15,"idle",1.1],["c_luxus_schwarz",Vector3(-1.2,0,-1.8),0.7],["hqman",Vector3(-1.5,0,0.2),0.4,"idle",0.3]],
			"cam":[Vector3(0.2,0.7,5.4),Vector3(-0.2,1.15,0)]},
		{"name":"tuning","fov":38.0,"licht":[Vector3(-45,-20,0),Color(0.9,0.95,1.0),Vector3(-10,160,0),Color(0.2,1.0,0.9)],
			"dinge":[["c_jdm_blau",Vector3(0,0,0),-0.7],["biker",Vector3(2.2,0,0.8),-0.8,"shake",0.5]],
			"cam":[Vector3(1.4,0.35,5.6),Vector3(0.2,0.75,0)]},
	]
