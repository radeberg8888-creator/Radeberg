extends SceneTree
# Prototyp: ganze untere Kartenhälfte mit dem Bausatz-Generator, als Bilder.
const OUT:="/home/claude/work/sued/"
const CX:=-200.0
const CZ:=500.0
var S
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var t0=Time.get_ticks_msec()
	var W=Node3D.new();root.add_child(W)
	var L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L._umgebung()
	for n in W.get_children():
		if n is DirectionalLight3D:n.directional_shadow_max_distance=200.0
	L.hoehen_an=false
	var GL=load("res://scripts/comic/ghetto_lib.gd").new(L)
	var K=load("res://scripts/comic/kit_lib.gd").new(L)
	var G0=load("res://scripts/welt_gelaende.gd").new()
	S=load("res://scripts/comic/sued_lib.gd").new(L,GL,K,G0)
	var RW=Rect2(-3000,340,4700,2310)
	var AUSW=[Rect2(-680,190,960,612)]
	S.maske_bauen(RW,AUSW)
	var aus=[];for a in AUSW:aus.append(Rect2(a.position-Vector2(CX,CZ),a.size))
	S.laden("/home/claude/work/karte.json",Rect2(RW.position-Vector2(CX,CZ),RW.size),aus)
	S.zwischenstrassen()
	S.kreuzungen()
	S.kits_bauen()
	S.hafenkante()
	S.flughafen()
	var d=JSON.parse_string(FileAccess.get_file_as_string("/home/claude/work/karte.json"))
	var hs=[];for h in d.houses:hs.append(Vector2(h[1],h[2]))
	S.hinterland(hs)
	S.grundstuecke()
	S.fuellen()
	S.parken_strasse()
	print("IMMO ",S.IMMO.size()," PARK ",S.PARK.size())
	var dump={"roads":[],"sonder":[],"platz":[],"immo":[]}
	for r in S.ROADS:
		var P=[];for q in r.P:P.append([q.x,q.y])
		dump.roads.append({"P":P,"w":r.w,"sw":r.sw})
	for r in S.SONDER:
		var P=[];for q in r.P:P.append([q.x,q.y])
		dump.sonder.append({"P":P,"w":r.w,"typ":r.typ})
	for p in S.PLATZ:
		var k=K.KITS[p[0]];var o:Vector3=p[1].origin;var bx:Vector3=p[1].basis.x
		dump.platz.append([p[0],o.x,o.z,bx.x,bx.z,k.w,k.d])
	for im in S.IMMO:dump.immo.append([im.art,im.xf.origin.x,im.xf.origin.z])
	var fd=FileAccess.open(OUT+"dump.json",FileAccess.WRITE);fd.store_string(JSON.stringify(dump));fd.close()
	L.kachel=300.0;L.weit_detail=1800.0
	S.fahrbahnen();S.platten();S.wege();L._fertig()
	L.weit_detail=450.0;S.strassenrand();L._fertig()
	var B=Node3D.new();B.name="Bausatz";W.add_child(B)
	print("AUFSTELLEN ",K.aufstellen(B,S.PLATZ)," FERN ",K.fern(B,S.PLATZ))
	# Beschriftungen je Instanz
	var nl=0
	for p in S.PLATZ:
		for lb in K.KITS[p[0]].labels:
			var l=Label3D.new();l.text=lb.text;l.pixel_size=lb.px;l.modulate=lb.mod;l.outline_modulate=lb.om;l.outline_size=lb.os;l.font_size=lb.fs;l.shaded=false
			l.visibility_range_end=55.0;l.transform=p[1]*lb.xf;W.add_child(l);nl+=1
	print("LABELS ",nl)
	# Boden: einfache Fläche (Wasser / Gras) zur Orientierung
	var wasser=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(9000,6000);wasser.mesh=pm;wasser.position=Vector3(-200,-1.2,1300)
	var wm=StandardMaterial3D.new();wm.albedo_color=Color(0.25,0.5,0.6);wasser.material_override=wm;W.add_child(wasser)
	var land=SurfaceTool.new();land.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in S.MNZ-1:
		for i in S.MNX-1:
			if S.WASSER[k*S.MNX+i]==1:continue
			var x=S.MX0+i*S.MST-CX;var z=S.MZ0+k*S.MST-CZ;var y=-0.25 if S.MASKE[k*S.MNX+i]==1 else -0.6
			land.add_vertex(Vector3(x,y,z));land.add_vertex(Vector3(x+S.MST,y,z));land.add_vertex(Vector3(x+S.MST,y,z+S.MST))
			land.add_vertex(Vector3(x,y,z));land.add_vertex(Vector3(x+S.MST,y,z+S.MST));land.add_vertex(Vector3(x,y,z+S.MST))
	land.generate_normals();var lm=MeshInstance3D.new();lm.mesh=land.commit();var gm=StandardMaterial3D.new();gm.albedo_color=Color(0.5,0.55,0.32);lm.material_override=gm;W.add_child(lm)
	# Parker (nur Vorschau)
	var CA=load("res://scripts/comic/comic_autos.gd")
	var map={"c_wartburg":"c_wartburg_beige","c_muscle":"c_muscle_orange","c_e30":"c_kompakt_weiss","c_luxus":"c_luxus_schwarz","c_trabant":"c_trabant_beige","c_kompakt":"c_kompakt_rot","c_suv":"c_suv_grau","c_jdm":"c_jdm_blau","c_sport":"c_sport_rot"}
	print("BAUZEIT ",Time.get_ticks_msec()-t0," ms")
	var V=_ansichten()
	var na=0
	for pk in S.PARK:
		var nah=false
		for v in V:
			if Vector2(pk[1].origin.x,pk[1].origin.z).distance_to(Vector2(v[2].x,v[2].z))<140:nah=true
		if not nah:continue
		var c=CA.bauen(map.get(pk[0],"c_kompakt_rot"));W.add_child(c);c.transform=pk[1];na+=1
	print("AUTOS ",na)
	for n in W.get_children():
		if n is WorldEnvironment:n.environment.fog_density*=0.3
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=62;cam.far=6000;W.add_child(cam);cam.current=true
	for v in V:
		cam.look_at_from_position(v[1],v[2])
		for f in 4:await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT+v[0]+".png");print("BILD ",v[0])
	quit()

func _w(x,z)->Vector3:return Vector3(x-CX,0,z-CZ)
func _ansichten()->Array:
	var V=[]
	var only=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nur="):only=a.substr(6)
	var Z={"ghetto":Vector2(-250,1000),"suedstadt":Vector2(250,1580),"docks":Vector2(500,2150),"industrie":Vector2(900,700),"hafen":Vector2(1500,800),"strand":Vector2(-2100,500),"flug":Vector2(-2000,2050)}
	V.append(["0_gesamt",_w(-500,4200)+Vector3(0,2600,0),_w(-450,1500)])
	for k in Z:
		if only!="" and only!=k:continue
		var c=Z[k];var t=_w(c.x,c.y)
		V.append([k+"_ueber",t+Vector3(-260,300,330),t])
		V.append([k+"_schraeg",t+Vector3(90,55,120),t+Vector3(-30,0,-20)])
		# Straßenansicht: nächste Straße am Zentrum
		var ns=S.naechst(Vector2(t.x,t.z))
		if ns[2]>=0:
			var r=S.ROADS[ns[2]];var p:Vector2=ns[0];var tt:Vector2=ns[1];var n=Vector2(-tt.y,tt.x)
			V.append([k+"_strasse",Vector3(p.x+n.x*1.6,2.4,p.y+n.y*1.6),Vector3(p.x+tt.x*45,1.8,p.y+tt.y*45)])
	return V
