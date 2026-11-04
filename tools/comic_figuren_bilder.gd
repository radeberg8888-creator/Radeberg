extends SceneTree
# Comic-Menschen (wie im Stadt-Prototyp) als Einzelbilder: Spieler vorn/seitlich/hinten/gehend, Passanten, Polizist, Gangster.
const OUT:="/home/claude/work/figuren/"
var L
var W:Node3D
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	W=Node3D.new();root.add_child(W)
	L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L._umgebung()
	L.box(L.M.pflaster,Vector3(0,-0.05,0),Vector3(60,0.1,60),Basis(),0.0)
	L.box(L.M.asphalt,Vector3(0,-0.04,-9),Vector3(60,0.1,8),Basis(),0.0)
	var H=L.HAUT
	var spieler={"haut":H[2],"oben":Color(0.93,0.42,0.18),"unten":Color(0.2,0.3,0.55),"haar":Color(0.12,0.08,0.05),"frisur":"kurz"}
	# Reihe 1: Spieler in 4 Ansichten (x=-3..3 nebeneinander, gleiche Kamera)
	L._mensch(Vector3(-3,0,0),0.0,spieler)
	L._mensch(Vector3(-1,0,0),PI*0.5,spieler)
	L._mensch(Vector3(1,0,0),PI,spieler)
	var g=spieler.duplicate();g.geht=true;g.ph=1.2
	L._mensch(Vector3(3,0,0),PI*0.5,g)
	# Reihe 2 (z=12): Passanten
	var P=[
		{"frau":true,"haut":H[0],"oben":Color(0.9,0.75,0.3),"unten":Color(0.3,0.25,0.5),"haar":Color(0.85,0.6,0.25),"frisur":"lang","rock":true,"schuh":Color(0.6,0.15,0.2),"tasche":true},
		{"haut":H[3],"oben":Color(0.18,0.55,0.35),"unten":Color(0.18,0.18,0.2),"haar":Color(0.06,0.05,0.05),"frisur":"locken","aermel":"lang","kapuze":true},
		{"haut":H[1],"oben":Color(0.75,0.2,0.25),"unten":Color(0.35,0.3,0.25),"haar":Color(0.55,0.55,0.53),"frisur":"glatze","bart":true,"brille":true,"aermel":"lang"},
		{"frau":true,"haut":H[4],"oben":Color(0.95,0.95,0.95),"unten":Color(0.2,0.3,0.6),"haar":Color(0.08,0.06,0.05),"frisur":"zopf"},
		{"haut":H[2],"oben":Color(0.3,0.5,0.8),"unten":Color(0.25,0.25,0.3),"haar":Color(0.12,0.08,0.05),"frisur":"kurz","kurz":true,"muster":"streifen","gr":0.8},
	]
	for i in P.size():L._mensch(Vector3(-4+i*2,0,12),0.0,P[i])
	# Reihe 3 (z=24): Polizist, Gangster
	L._mensch(Vector3(-1,0,24),0.0,{"haut":H[1],"oben":Color(0.16,0.25,0.45),"unten":Color(0.12,0.14,0.2),"haar":Color(0.2,0.12,0.07),"aermel":"lang","frisur":"glatze","schirmmuetze":Color(0.12,0.16,0.3),"schuh":Color(0.08,0.08,0.08)})
	L._mensch(Vector3(1,0,24),0.0,{"haut":H[3],"oben":Color(0.12,0.12,0.13),"unten":Color(0.22,0.24,0.3),"haar":Color(0.05,0.05,0.05),"frisur":"kurz","aermel":"lang","kapuze":true,"bart":true,"schuh":Color(0.85,0.15,0.15)})
	L._fertig()
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=30;W.add_child(cam);cam.current=true
	var bilder=[["1_spieler_ansichten",Vector3(0,1.15,11.0),Vector3(0,0.95,0)],
		["2_spieler_nah",Vector3(-3,1.5,3.4),Vector3(-3,1.25,0)],
		["3_passanten",Vector3(0,1.15,23.0),Vector3(0,0.95,12)],
		["4_polizist_gangster",Vector3(0,1.2,30.5),Vector3(0,0.95,24)]]
	for b in bilder:
		cam.look_at_from_position(b[1],b[2])
		for k in 8:await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT+b[0]+".png");print("BILD ",b[0])
	quit()
