extends Node3D
# Die Insel Radeberg – offene Welt im Geist von San Andreas (eigene Karte, keine Originalinhalte):
#  NW: Berg mit Nadelwald und Serpentinenstraße     NO: Hügel-Vorort mit Villen
#  Mitte: Downtown (Hochhäuser, gedrehtes Raster)   dazwischen: Altstadt mit Backstein-Mietshäusern
#  Süd: Ghetto in einer Senke (heruntergekommene Häuser, Gangviertel)
#  Ost: Hauptbahnhof, Güterbahnhof, Industrie, Containerhafen
#  SW: Wüste mit verlassenem Flugplatz (Landebahn, Hangars, Tower)
#  Autobahnring um die Insel mit Kurven, Tunnel, Viadukt, Auf-/Abfahrten; rundherum Meer.
const GEL=preload("res://scripts/welt_gelaende.gd")
const STR=preload("res://scripts/welt_strassen.gd")
const BAU=preload("res://scripts/welt_bauten.gd")
const ANL=preload("res://scripts/welt_anlagen.gd")
const LEB=preload("res://scripts/welt_leben.gd")
var LV
var A
var B
const F=preload("res://scripts/fit.gd")
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
var G
var S
var args:=[]
var named:={}
var rng:=RandomNumberGenerator.new()
const D:=Vector2(250,-350)    # Downtown-Mitte
const DA:=0.3                 # Drehung des Downtown-Rasters

func gpt(u:float,v:float)->Vector2:
	return D+Vector2(u*cos(DA)-v*sin(DA),u*sin(DA)+v*cos(DA))
func v3(p:Vector2,y:=0.0)->Vector3:return Vector3(p.x,y,p.y)

func layout():
	# ebene Flächen für Bahnanlagen, Flugplatz
	for z in [-150.0,0.0,150.0,300.0,450.0,600.0,750.0]:G.plateaus.append([Vector2(705,z),95.0,90.0,G._nat(705,300)])
	for k in 8:
		var p=Vector2(-1150,250).lerp(Vector2(-1020,820),k/7.0)
		G.plateaus.append([p,70.0,80.0,G._nat(-1080,540)])
	G.plateaus.append([Vector2(-930,520),120.0,70.0,G._nat(-1080,540)])
	G.plateaus.append([Vector2(1330,330),110.0,60.0,3.0])
	for z in [180.0,300.0,420.0,540.0]:G.plateaus.append([Vector2(1500,z),100.0,50.0,2.9])
	# ---- Autobahnring (y = Anhebung, z.B. Viadukt am Hafen) ----
	named.ring=S.add("autobahn",[Vector3(0,0,-1150),Vector3(600,0,-1185),Vector3(1120,0,-930),Vector3(1340,0,-430),Vector3(1335,10,0),Vector3(1315,10,420),
		Vector3(1150,3,850),Vector3(550,0,1120),Vector3(-250,0,1185),Vector3(-850,0,1110),Vector3(-1330,0,700),Vector3(-1370,0,150),Vector3(-1300,0,-250),
		Vector3(-900,-28,-300),Vector3(-500,0,-600),Vector3(-250,0,-960)],{"closed":true,"name":"Ring"})
	# ---- Bahnstrecke ----
	named.bahn=S.add("schiene",[Vector3(-760,-30,-1030),Vector3(-350,0,-810),Vector3(0,0,-720),Vector3(400,0,-790),Vector3(640,0,-600),Vector3(690,0,-300),
		Vector3(690,0,0),Vector3(690,0,300),Vector3(690,0,500),Vector3(680,0,800),Vector3(450,0,990),Vector3(-200,0,975),Vector3(-650,0,900),Vector3(-950,0,800)],{"name":"Bahn"})
	for x in [672.0,708.0,726.0]:
		var sx=1.0 if x>690 else -1.0
		S.add("schiene",[Vector3(690,0,-260),Vector3(690+sx*6,0,-170),Vector3(x,0,-100),Vector3(x,0,280),Vector3(690+sx*6,0,350),Vector3(690,0,420)])
	for k in 6:S.add("schiene",[Vector3(704+k*5.5,0,470),Vector3(704+k*5.5,0,760)])
	# ---- Downtown: gedrehtes Raster ----
	for u in [-220.0,-110.0,110.0,220.0]:
		S.add("strasse",[v3(gpt(u,-260)),v3(gpt(u,-130)),v3(gpt(u,0)),v3(gpt(u,130)),v3(gpt(u,260))],{"wear":0.1})
	for v in [-260.0,-130.0,0.0,130.0,260.0]:
		S.add("strasse",[v3(gpt(-220,v)),v3(gpt(-110,v)),v3(gpt(0,v)),v3(gpt(110,v)),v3(gpt(220,v))],{"wear":0.1})
	# ---- Radeberger Allee: Ghetto -> Altstadt -> Downtown -> Nord -> Autobahn ----
	var al=[Vector3(-250,0,560),Vector3(-200,0,400),Vector3(-70,0,190)]
	for v in [260.0,130.0,0.0,-130.0,-260.0]:al.append(v3(gpt(0,v)))
	al.append(Vector3(370,0,-780));al.append(Vector3(390,0,-960))
	named.allee=S.add("allee",al,{"name":"Radeberger Allee","wear":0.15})
	S.add("rampe",[Vector3(390,0,-960),Vector3(370,0,-1080),Vector3(330,0,-1166)],{"ab_join":true})
	# ---- Ghetto (Senke im Süden), krumme Straßen, T-Kreuzungen ----
	named.ghetto=S.add("strasse",[Vector3(-660,0,430),Vector3(-450,0,500),Vector3(-250,0,560),Vector3(-100,0,650),Vector3(30,0,770),Vector3(120,0,900)],{"name":"Grove","wear":0.85})
	S.add("rampe",[Vector3(120,0,900),Vector3(230,0,1050),Vector3(330,0,1146)],{"ab_join":true})
	S.add("strasse",[Vector3(-480,0,330),Vector3(-440,0,520),Vector3(-380,0,720),Vector3(-410,0,890)],{"wear":0.8})
	S.add("gasse",[Vector3(-100,0,650),Vector3(-150,0,800),Vector3(-270,0,900)],{"wear":0.9})
	S.add("strasse",[Vector3(-380,0,720),Vector3(-220,0,745),Vector3(-62,0,688)],{"wear":0.85})
	S.add("gasse",[Vector3(-440,0,520),Vector3(-600,0,610),Vector3(-700,0,720)],{"wear":0.9})
	S.add("gasse",[Vector3(-250,0,560),Vector3(-300,0,660),Vector3(-380,0,720)],{"wear":0.9})
	# ---- Altstadt ----
	S.add("strasse",[Vector3(-460,0,160),Vector3(-260,0,190),Vector3(-90,0,150),Vector3(120,0,90),Vector3(380,0,120),Vector3(600,0,170)],{"wear":0.4})
	S.add("strasse",[Vector3(-320,0,-40),Vector3(-160,0,10),v3(gpt(-220,130))],{"wear":0.4})
	S.add("gasse",[Vector3(-360,0,300),Vector3(-220,0,330),Vector3(-120,0,265)],{"wear":0.5})
	S.add("strasse",[v3(gpt(220,0)),Vector3(560,0,-140),Vector3(600,0,60),Vector3(600,0,170)],{"wear":0.2})
	S.add("strasse",[Vector3(-450,0,-100),Vector3(-300,0,-120),Vector3(-150,0,-180),Vector3(0,0,-300),v3(gpt(-220,0))],{"wear":0.4})
	S.add("gasse",[Vector3(-300,0,250),Vector3(-280,0,140),Vector3(-260,0,40)],{"wear":0.5})
	S.add("gasse",[Vector3(-200,0,400),Vector3(-120,0,250),Vector3(-60,0,180)],{"wear":0.5})
	S.add("strasse",[Vector3(-200,0,400),Vector3(-100,0,500),Vector3(-30,0,600),Vector3(30,0,770)],{"wear":0.8})
	S.add("gasse",[Vector3(-560,0,780),Vector3(-420,0,800),Vector3(-270,0,900)],{"wear":0.9})
	S.add("gasse",[Vector3(-600,0,610),Vector3(-560,0,780),Vector3(-500,0,940)],{"wear":0.9})
	# ---- Ostviertel ----
	S.add("strasse",[Vector3(560,0,-140),Vector3(800,0,-200),Vector3(1000,0,-250),Vector3(1180,0,-230)],{"wear":0.3})
	S.add("strasse",[Vector3(800,0,-200),Vector3(850,0,-50),Vector3(900,0,150),Vector3(900,0,330)],{"wear":0.3})
	S.add("gasse",[Vector3(1000,0,-250),Vector3(1020,0,-80),Vector3(900,0,150)],{"wear":0.4})
	# ---- Bahnhof -> Hafen, Industrie ----
	named.hafen=S.add("strasse",[Vector3(600,0,170),Vector3(610,0,320),Vector3(900,0,330),Vector3(1150,0,300),Vector3(1430,0,340)],{"name":"Hafenstraße","wear":0.5})
	S.add("rampe",[Vector3(1150,0,300),Vector3(1240,0,200),Vector3(1333,0,40)],{"ab_join":true})
	S.add("strasse",[Vector3(900,0,330),Vector3(880,0,600),Vector3(960,0,820)],{"wear":0.6})
	# ---- Vorort auf den Hügeln ----
	S.add("strasse",[v3(gpt(220,-260)),Vector3(650,0,-650),Vector3(780,0,-760),Vector3(820,0,-900),Vector3(700,0,-1010)],{"wear":0.1})
	S.add("strasse",[Vector3(650,0,-650),Vector3(560,0,-800),Vector3(620,0,-950),Vector3(700,0,-1010)],{"wear":0.1})
	S.add("strasse",[Vector3(780,0,-760),Vector3(950,0,-700),Vector3(1050,0,-800)],{"wear":0.1})
	S.add("strasse",[Vector3(820,0,-900),Vector3(950,0,-950),Vector3(1050,0,-800)],{"wear":0.1})
	S.add("gasse",[Vector3(560,0,-800),Vector3(470,0,-890),Vector3(390,0,-960)],{"wear":0.1})
	S.add("strasse",[Vector3(880,0,600),Vector3(1100,0,620),Vector3(1180,0,700)],{"wear":0.6})
	# ---- Land- und Bergstraßen, Wüste, Flugplatz ----
	S.add("land",[Vector3(-660,0,430),Vector3(-860,0,500),Vector3(-980,0,600)],{"wear":0.6})
	S.add("land",[Vector3(-660,0,430),Vector3(-700,0,200),Vector3(-760,0,-60),Vector3(-820,0,-250),Vector3(-700,0,-420),Vector3(-640,0,-560),
		Vector3(-760,0,-640),Vector3(-930,0,-600),Vector3(-1000,0,-480),Vector3(-1130,0,-500),Vector3(-1200,0,-620),Vector3(-1150,0,-740),Vector3(-1060,0,-760)],{"g":0.24,"sm":16.0,"tunnel":false,"name":"Bergstraße"})
	S.add("land",[Vector3(-460,0,160),Vector3(-600,0,100),Vector3(-700,0,200)],{"wear":0.3})
	named.runway=S.add("runway",[Vector3(-1150,0,250),Vector3(-1020,0,820)],{"wear":1.0})
	S.add("taxi",[Vector3(-1112,0,415),Vector3(-1040,0,430),Vector3(-960,0,470)],{"wear":1.0})
	S.add("taxi",[Vector3(-1060,0,640),Vector3(-990,0,610),Vector3(-930,0,560),Vector3(-960,0,470)],{"wear":1.0})
	S.add("piste",[Vector3(-980,0,600),Vector3(-930,0,560)],{"wear":1.0})

var spiel:=false          # true: vom Spiel erzeugt (keine Testbilder, keine statischen Autos/Passanten)
func _ready():
	args=OS.get_cmdline_user_args();rng.seed=4711
	if spiel:return
	if "bake" in args:
		BAU.new(GEL.new(),null).bake_cache();get_tree().quit();return
	var t0=Time.get_ticks_msec()
	await generate(func(_t,_p):pass)
	_after(t0)

# Welt erzeugen; progress(text, anteil 0..1) wird zwischen den Schritten aufgerufen
func generate(progress:Callable):
	var tt=[Time.get_ticks_msec()]
	var mark=func(n):print("ZEIT ",n," ",Time.get_ticks_msec()-tt[0]," ms");tt[0]=Time.get_ticks_msec()
	var step=func(t,p):
		progress.call(t,p);await get_tree().process_frame;await get_tree().process_frame
	await step.call("Gelände wird geformt …",0.02)
	G=GEL.new();S=STR.new(G)
	layout()
	G.build_heights();mark.call("hoehen")
	await step.call("Straßen und Autobahn …",0.08)
	S.profiles();mark.call("profile")
	S.shape_terrain();mark.call("formen")
	await step.call("Häuser werden verteilt …",0.14)
	B=BAU.new(G,S);B.spiel=spiel;B.mark_roads()
	A=ANL.new(G,S,B);A.reserve()
	B.place_along();mark.call("platzieren")
	G.apply_cut()
	S.clamp_terrain()
	S.portal_fix();mark.call("cut/clamp/portal")
	G.holes=S.holes
	await step.call("Landschaft …",0.25)
	G.build_mesh(self);mark.call("gelaendemesh")
	await step.call("Fahrbahnen, Brücken, Tunnel …",0.35)
	S.build(self);mark.call("strassenmesh")
	_water()
	await step.call("Gebäude …",0.45)
	B.build(self);mark.call("gebaeude")
	await step.call("Bahnhof, Hafen, Flugplatz, Läden …",0.62)
	A.build(self);mark.call("anlagen")
	if not spiel:_save_icons()
	if not "nolife" in args:
		LV=LEB.new(G,S,B);LV.spiel=spiel
		var lr=Node3D.new();lr.name="Leben";add_child(lr)
		await step.call("Wälder …",0.72)
		LV.forests(lr);mark.call("wald")
		await step.call("Laternen und Straßenbäume …",0.82)
		LV.streets(lr);LV.ghetto_props(lr);mark.call("laternen")
		if not spiel and not "nocars" in args:LV.cars(lr);LV.people(lr,90);mark.call("autos/leute")

func _after(t0):
	print("WELT Gelände+Straßen ",Time.get_ticks_msec()-t0," ms, Straßen ",S.roads.size()," Kreuzungen ",S.junctions.size())
	for r in S.roads:
		var tn=r.tunnel_flags.count(true);var el=r.elev.count(true)
		var cutmax=0.0
		for i in r.P.size():if not r.tunnel_flags[i]:cutmax=max(cutmax,r.raw[i]-r.h[i])
		var runs=[];var i0=-1
		for i in r.P.size()+1:
			var e=i<r.P.size() and r.elev[i]
			if e and i0<0:i0=i
			if not e and i0>=0:
				var mx=0.0
				for k in range(i0,i):mx=max(mx,r.h[k]-r.raw[k])
				runs.append("%s-%s(+%.0f)"%[str(r.P[i0].round()),str(r.P[i-1].round()),mx]);i0=-1
		if runs.size()>0:print("    Brücken: ",runs)
		if false:
			var dbg=[]
			for i in range(0,r.P.size(),25):dbg.append("%d:%.0f/%.0f/%.0f"%[i,r.raw[i],r.h[i],r.hint[i]])
			print("    DBG ",dbg)
		if tn>0 or el>0 or cutmax>6:print("  ",r.typ," ",r.name," Tunnel ",tn*4," m, Brücke ",el*4," m, max Einschnitt ",snapped(cutmax,0.1))
	if "debug" in args:
		print("HOLES ",G.holes.size())
		for k in G.nz:
			for i in G.nx:
				var x=-G.SX+i*G.STEP;var z=-G.SZ+k*G.STEP
				if G.heights[G.idx(i,k)]<0.5 and G.island(x,z)>=1.0:print("TIEF ",x," ",z," ",G.heights[G.idx(i,k)])
		for h in G.holes:print("LOCH ",h," ",-G.SX+h.x*G.STEP," ",-G.SZ+h.y*G.STEP)
		get_tree().quit();return
	_env()
	_shots()

func _water():
	var w=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(200000,200000);w.mesh=pm;add_child(w);w.position.y=0.0
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.05,0.16,0.21);m.metallic=0.25;m.roughness=0.08;m.metallic_specular=0.9
	var nt=NoiseTexture2D.new();nt.seamless=true;nt.as_normal_map=true;nt.bump_strength=5.0;var fn=FastNoiseLite.new();fn.frequency=0.03;nt.noise=fn;nt.width=512;nt.height=512
	m.normal_enabled=true;m.normal_texture=nt;m.normal_scale=0.5;m.uv1_scale=Vector3(8000,8000,1)
	w.material_override=m;water_mat=m
var water_mat:StandardMaterial3D
func _process(d):
	if water_mat:water_mat.uv1_offset+=Vector3(d*0.004,d*0.0025,0)

var sun:DirectionalLight3D
func _env():
	sun=load("res://scripts/env.gd").make(self,"day")
	for c in get_children():
		if c is WorldEnvironment:
			var e:Environment=c.environment;e.fog_density=0.00022;e.fog_aerial_perspective=0.7;e.ssao_enabled=false
	sun.directional_shadow_max_distance=400.0

func _shots():
	var cam=Camera3D.new();cam.far=9000;cam.near=0.3;add_child(cam)
	var list=[]
	var mode=args[0] if args.size()>0 else "luft"
	if mode=="luft":
		list=[[Vector3(600,1500,2300),Vector3(0,0,0),45.0],[Vector3(-400,700,1500),Vector3(-300,0,500),50.0],[Vector3(1500,500,-800),Vector3(300,0,-300),50.0],
			[Vector3(-1800,600,200),Vector3(-900,50,-400),50.0],[Vector3(1200,300,700),Vector3(900,0,300),55.0]]
	if mode=="anlagen":
		for e in [[560,60,-160,690,10,60,55.0],[640,4,-70,705,4,60,60.0],[820,45,520,720,5,640,55.0],[1500,40,120,1600,10,350,60.0],[-780,30,420,-900,5,520,55.0],[-990,6,610,-930,4,540,60.0]]:
			var gy=G.h_at(e[0],e[2]);var ly=G.h_at(e[3],e[5])
			list.append([Vector3(e[0],gy+e[1],e[2]),Vector3(e[3],ly+e[4],e[5]),e[6]])
		for sp in A.shops:
			var c=v3(sp.c,sp.y);var fw=Vector3(sin(sp.yaw),0,cos(sp.yaw))
			list.append([c+fw*(sp.d*0.5+16)+Vector3(0,3,0)+fw.cross(Vector3.UP)*6,c+Vector3(0,3,0),60.0])
	if mode=="tunnel" or mode=="alles":
		for r in [named.ring,named.bahn]:
			for i in range(1,r.P.size()):
				if r.tunnel_flags[i] and not r.tunnel_flags[i-1]:
					var s0=(i-18)*4.0
					list.append(street_cam(r,s0,-4.0,4.0,72.0))
					var a=S.at(r,s0+30);var nn=Vector2(-a[2].y,a[2].x)
					list.append([v3(a[0]+nn*60-a[2]*40,a[1]+45),v3(S.at(r,i*4.0)[0],S.at(r,i*4.0)[1]),55.0])
					break
	if mode=="pfuetze":
		list.append([Vector3(-450,250,750),Vector3(-450,0,580),55.0])
		list.append([Vector3(-150,250,620),Vector3(-150,0,440),55.0])
		list.append([Vector3(-100,250,500),Vector3(-50,0,330),55.0])
	if mode=="luftfinal":
		list.append([Vector3(900,1250,1900),Vector3(-50,0,-100),48.0])
		list.append([Vector3(-150,520,1450),Vector3(-250,0,500),50.0])
	if mode=="final":
		list.append([Vector3(900,1250,1900),Vector3(-50,0,-100),48.0])
		list.append([Vector3(450,420,350),Vector3(-400,60,-700),55.0])
		list.append(street_cam(named.ghetto,215,-3.5,1.7,45))
		list.append(street_cam(named.ghetto,380,6.0,24.0,120))
		var dp=gpt(-110,-150);var dq=gpt(-110,60)
		list.append([v3(dp+Vector2(4,0),G.h_at(dp.x,dp.y)+1.8),v3(dq,G.h_at(dq.x,dq.y)+25),60.0])
		list.append(street_cam(named.allee,420,-6.5,2.2,70))
		list.append([Vector3(1255,G.h_at(1255,330)+2.0,330),Vector3(1330,G.h_at(1330,200)+14,180),60.0])
		var berg=S.roads_by_name("Bergstraße")
		list.append(street_cam(berg,1350,-2.0,9.0,90))
		list.append([Vector3(640,G.h_at(640,-160)+14,-160),Vector3(705,G.h_at(705,40)+3,40),55.0])
		list.append([Vector3(820,G.h_at(820,450)+60,450),Vector3(1480,10,380),55.0])
		list.append([Vector3(-1010,G.h_at(-1010,640)+7,640),Vector3(-890,G.h_at(-890,520)+5,520),58.0])
		for r in [named.ring]:
			for i in range(1,r.P.size()):
				if r.tunnel_flags[i] and not r.tunnel_flags[i-1]:
					list.append(street_cam(r,(i-25)*4.0,-5.0,4.0,90.0));break
	if mode=="strasse":
		list=[street_cam(named.ghetto,260,-3.0,1.8,40),street_cam(named.ghetto,520,2.0,2.5,60),street_cam(named.allee,700,-8.0,2.0,60),
			street_cam(named.allee,1150,-6.0,2.0,80),street_cam(named.allee,350,4.0,12.0,90),street_cam(named.hafen,300,3.0,3.0,70)]
	if mode=="karte":
		cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=3000.0;cam.keep_aspect=Camera3D.KEEP_HEIGHT
		for c in get_children():
			if c is WorldEnvironment:c.environment.fog_enabled=false
		sun.rotation_degrees=Vector3(-62,-150,0);sun.directional_shadow_max_distance=3000.0
		cam.position=Vector3(0,1500,0);cam.rotation_degrees=Vector3(-90,0,0);cam.far=4000
		var t=Timer.new();add_child(t);t.wait_time=0.5;t.one_shot=true;t.start()
		t.timeout.connect(func():
			var img=get_viewport().get_texture().get_image();img.save_png(ProjectSettings.globalize_path("res://assets/ui/karte_basis.png"))
			var vs=get_viewport().get_visible_rect().size
			var a=cam.project_position(Vector2(0,0),100.0);var b=cam.project_position(vs,100.0)
			var f=FileAccess.open("res://assets/ui/karte_bereich.json",FileAccess.WRITE);f.store_string(JSON.stringify({"x0":a.x,"z0":a.z,"x1":b.x,"z1":b.z}));f.close()
			print("KARTE ",a," ",b," ",vs," ",img.get_size())
			get_tree().quit())
		return
	var sh=load("res://scripts/shots.gd").new();add_child(sh);sh.setup(list,"welt_"+mode)

# Kamera auf einer Straße: s = Lauflänge, off = seitlich, hgt = Augenhöhe, ahead = Blickweite
func street_cam(r:Dictionary,s:float,off:float,hgt:float,ahead:float)->Array:
	var a=S.at(r,s);var b=S.at(r,s+ahead)
	var n=Vector2(-a[2].y,a[2].x)
	var p=a[0]+n*off;var q=b[0]+n*off*0.3
	return [Vector3(p.x,a[1]+hgt,p.y),Vector3(q.x,b[1]+hgt*0.6,q.y),62.0]

func _save_icons():
	var out=[]
	for i in A.icons:out.append({"typ":i[0],"x":i[1].x,"z":i[1].y,"name":i[2]})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	var f=FileAccess.open("res://assets/ui/karte_icons.json",FileAccess.WRITE);f.store_string(JSON.stringify(out," "));f.close()
