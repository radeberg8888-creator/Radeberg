extends SceneTree
# Freisteller für den Ladebildschirm: Figuren (mit Waffen im Anschlag), Autos, vor Grün gerendert.
# Kamera rahmt automatisch; Mündungspunkte werden für Mündungsfeuer mitgeschrieben (JSON).
# Comic-Nachbearbeitung + gemalte Hintergründe: tools/ladebilder_comic.py
const OUT:="/home/claude/work/lade/"
const PE=preload("res://scripts/people.gd")
const HALTER=preload("res://scripts/spiel/waffen_halter.gd")
var CA
var W:Node3D
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	W=Node3D.new();root.add_child(W)
	CA=load("res://scripts/comic/comic_autos.gd")
	var we=WorldEnvironment.new();var env=Environment.new();we.environment=env;W.add_child(we)
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,1,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(0.5,0.45,0.6);env.ambient_light_energy=0.7
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var sun=DirectionalLight3D.new();W.add_child(sun);sun.shadow_enabled=true;sun.light_energy=1.7
	var rim=DirectionalLight3D.new();W.add_child(rim);rim.light_energy=1.6
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_8X
	var cam=Camera3D.new();W.add_child(cam);cam.current=true
	var nur=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nur="):nur=a.substr(6)
	var meta={}
	for sz in _szenen():
		if nur!="" and nur!=sz.name:continue
		var tmp=Node3D.new();W.add_child(tmp)
		sun.rotation_degrees=sz.licht[0];sun.light_color=sz.licht[1];rim.rotation_degrees=sz.licht[2];rim.light_color=sz.licht[3]
		var halter=[]
		for o in sz.dinge:
			if o[0].begins_with("c_"):
				var c=CA.bauen(o[0]);tmp.add_child(c);c.position=o[1];c.rotation.y=o[2]
				if o.size()>3:c.rotation.z=o[3]
				for mi in c.find_children("*","MeshInstance3D",true,false):
					var bb:AABB=mi.get_aabb()
					if bb.position.y>-0.01 and bb.position.y<0.012 and bb.size.x>1.5 and bb.size.y>1.0:mi.mesh=_ohne_boden(mi.mesh)
			else:
				var rng=RandomNumberGenerator.new();rng.seed=hash(str(o))
				var m=PE.make(o[0],rng);tmp.add_child(m);m.position=o[1];m.rotation.y=o[2]
				var ap:AnimationPlayer=m.get_meta("anim",null)
				if ap and ap.has_animation(o[3]):ap.play(o[3]);ap.seek(o[4],true);ap.pause()
				if o.size()>5 and o[5]!="":
					var h=HALTER.new();m.add_child(h);h.setup(m);h.setze_waffe(o[5]);h.zielen=o.size()>6
					if h.zielen:h.ziel_richtung=o[6]
					halter.append(h)
		cam.fov=sz.fov
		for i in 4:
			for h in halter:h.aktualisieren(0.016)
			await process_frame
		# rahmen über die Objektpositionen (Autos ~2.5 m Radius, Figuren 1 m)
		var summe=Vector3.ZERO;var nn=0
		for o in sz.dinge:summe+=o[1];nn+=1
		var mitte=summe/nn+Vector3(0,0.95,0)+sz.get("ziel",Vector3.ZERO)
		var r=0.0
		for o in sz.dinge:r=max(r,Vector2(o[1].x-mitte.x,o[1].z-mitte.z).length()+(2.4 if o[0].begins_with("c_") else 0.9))
		r=max(r,1.4)
		var dir=Vector3(sin(sz.blick[0])*cos(sz.blick[1]),sin(sz.blick[1]),cos(sz.blick[0])*cos(sz.blick[1]))
		var dist=r/tan(deg_to_rad(sz.fov)*0.5*16.0/9.0*0.95)*sz.get("abstand",1.0)
		cam.look_at_from_position(mitte+dir*dist,mitte)
		for i in 6:
			for h in halter:h.aktualisieren(0.016)
			await process_frame
		await RenderingServer.frame_post_draw
		var mz=[]
		for h in halter:
			if h.zielen and h.modell:var q=cam.unproject_position(h.muendung());mz.append([q.x,q.y])
		meta[sz.name]={"muendung":mz}
		vp.get_texture().get_image().save_png(OUT+"roh_"+sz.name+".png");print("BILD ",sz.name)
		tmp.queue_free();await process_frame
	var f=FileAccess.open(OUT+"meta.json",FileAccess.WRITE);f.store_string(JSON.stringify(meta));f.close()
	quit()

const WARM:=Color(1,0.72,0.45)
const KALT:=Color(0.45,0.6,1.0)
const MAG:=Color(1.0,0.3,0.8)
const CYAN:=Color(0.2,0.95,1.0)
# dinge: Figur [modell,pos,yaw,anim,zeit,waffe,zielrichtung] | Auto [kind,pos,yaw,(kippen)]
# blick: [yaw, pitch] der Kamera um die Szene (0 = von vorn +z), Höhe über Pitch
func _szenen()->Array:
	var vorn=Vector3(0,0,1)
	return [
		{"name":"gang","fov":46.0,"blick":[0.25,0.08],"licht":[Vector3(-25,-140,0),WARM,Vector3(-5,40,0),MAG],
			"dinge":[["c_muscle_orange",Vector3(0.5,0,-3.2),-1.2],["joe",Vector3(0,0,0),0.0,"idle",0.6,"m1911",Vector3(0.1,0.05,1)],["biker",Vector3(-1.6,0,-0.9),0.3,"idle",0.2,"ar15",Vector3(-0.2,0.08,1)],["hqman",Vector3(1.7,0,-0.7),-0.35,"idle",1.1,"ak47",Vector3(0.35,0.05,1)]]},
		{"name":"jagd","fov":40.0,"blick":[0.9,0.06],"abstand":1.3,"licht":[Vector3(-30,-40,0),Color(0.8,0.85,1.0),Vector3(-5,140,0),Color(1.0,0.25,0.3)],
			"dinge":[["c_sport_rot",Vector3(0,0,0),0.5,0.04],["c_polizei",Vector3(-2.0,0,-7.5),0.2],["c_polizei",Vector3(2.6,0,-13),0.45]]},
		{"name":"lauf","fov":38.0,"blick":[0.35,-0.06],"abstand":1.35,"licht":[Vector3(-35,-150,0),WARM,Vector3(-10,40,0),KALT],
			"dinge":[["hqman",Vector3(0,0,0),0.25,"run",0.35,"mp5"],["joe",Vector3(1.4,0,-1.6),0.4,"run",0.05,"m1911"]]},
		{"name":"strand","fov":38.0,"blick":[-0.2,0.05],"licht":[Vector3(-50,-60,0),Color(1,0.95,0.85),Vector3(-15,120,0),CYAN],
			"dinge":[["female",Vector3(-0.6,0,0.4),0.3,"dance",1.4],["c_sport_gelb",Vector3(1.6,0,-1.8),-0.8]]},
		{"name":"boss","fov":40.0,"blick":[0.0,0.02],"licht":[Vector3(-20,-110,0),Color(1,0.85,0.7),Vector3(-5,70,0),MAG],
			"dinge":[["daya",Vector3(0.0,0,0.6),0.0,"idle",1.1],["c_luxus_schwarz",Vector3(0,0,-2.2),PI*0.5],["hqman",Vector3(-1.6,0,0.1),0.3,"idle",0.3,"m4a1",Vector3(-0.3,0,1)],["biker",Vector3(1.6,0,0.1),-0.3,"idle",0.8,"ak47",Vector3(0.3,0,1)]]},
		{"name":"tuning","fov":38.0,"blick":[0.7,0.05],"licht":[Vector3(-45,-20,0),Color(0.9,0.95,1.0),Vector3(-10,160,0),CYAN],
			"dinge":[["c_jdm_blau",Vector3(0,0,0),-0.7],["biker",Vector3(2.0,0,0.9),-0.9,"shake",0.5]]},
		{"name":"deal","fov":42.0,"blick":[1.57,0.1],"licht":[Vector3(-40,0,0),Color(0.7,0.8,1.0),Vector3(-5,180,0),Color(1,0.5,0.2)],
			"dinge":[["joe",Vector3(0,0,0.9),PI,"talk",0.8],["biker",Vector3(-0.8,0,1.6),PI,"idle",0.4,"ar15",Vector3(0,0,-1)],["hqman",Vector3(0,0,-0.9),0.0,"idle",0.9],["daya",Vector3(0.9,0,-1.6),0.0,"idle",0.2,"m1911",Vector3(0,0.02,1)],["c_luxus_silber",Vector3(-2.6,0,-2.4),0.4],["c_suv_grau",Vector3(-2.6,0,2.6),PI-0.3]]},
		{"name":"schiesserei","fov":36.0,"blick":[-0.5,-0.02],"licht":[Vector3(-15,-80,0),Color(1,0.6,0.35),Vector3(-5,100,0),KALT],
			"dinge":[["joe",Vector3(0,0,0),-0.4,"idle",0.5,"ak47",Vector3(-0.5,0.02,1)],["c_trabant_blau",Vector3(1.6,0,-1.8),1.3]]},
		{"name":"wueste","fov":40.0,"blick":[0.3,0.12],"licht":[Vector3(-12,-150,0),Color(1,0.6,0.3),Vector3(-5,30,0),Color(0.5,0.3,0.8)],
			"dinge":[["biker",Vector3(0,0,0),0.1,"idle",0.7,"mossberg",Vector3(0.1,0.05,1)],["c_suv_gruen",Vector3(-1.2,0,-2.6),-0.6],["c_wartburg_beige",Vector3(2.6,0,-3.5),0.9,0.12]]},
		{"name":"flucht","fov":40.0,"blick":[-0.6,0.05],"licht":[Vector3(-35,-60,0),Color(0.7,0.8,1.0),Vector3(-5,120,0),Color(1,0.2,0.2)],
			"dinge":[["daya",Vector3(0,0,0),-0.3,"run",0.4,"m1911"],["c_polizei",Vector3(-1.0,0,-3.2),0.6]]},
		{"name":"party","fov":40.0,"blick":[0.0,0.05],"licht":[Vector3(-20,-90,0),MAG,Vector3(-5,90,0),CYAN],
			"dinge":[["female",Vector3(-0.8,0,0.3),0.4,"dance",0.6],["daya",Vector3(0.9,0,0.0),-0.3,"dance",2.1],["c_sport_schwarz",Vector3(0,0,-2.6),PI*0.5]]},
		{"name":"rennen","fov":42.0,"blick":[0.5,0.04],"abstand":1.3,"licht":[Vector3(-25,-30,0),WARM,Vector3(-5,160,0),MAG],
			"dinge":[["c_jdm_rot",Vector3(-1.4,0,0),0.05],["c_sport_gelb",Vector3(1.6,0,-2.5),0.0],["c_muscle_schwarz",Vector3(-0.4,0,-6.5),0.08]]},
	]

# entfernt flache Bodendreiecke (Schattenplatte) aus einem Auto-Mesh
func _ohne_boden(m:Mesh)->Mesh:
	var neu=ArrayMesh.new()
	for si in m.get_surface_count():
		var mdt=MeshDataTool.new();mdt.create_from_surface(m,si)
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f in mdt.get_face_count():
			var ys=[]
			for k in 3:ys.append(mdt.get_vertex(mdt.get_face_vertex(f,k)).y)
			if ys.max()<0.03:continue
			for k in 3:
				var v=mdt.get_face_vertex(f,k)
				st.set_normal(mdt.get_vertex_normal(v));st.set_color(mdt.get_vertex_color(v));st.set_uv(mdt.get_vertex_uv(v));st.add_vertex(mdt.get_vertex(v))
		st.commit(neu);neu.surface_set_material(neu.get_surface_count()-1,m.surface_get_material(si))
	return neu

