extends SceneTree
# Probestück 2: Grove mit kurvigen Straßen, schräger Kreuzung, spitzer und runder Ecke, Ampeln, Zebrastreifen,
# Durchgang in einen Innenhof mit Spielplatz und dem Waffenladen (mit Innenraum).
const OUT="/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/probe2/"
const SB=preload("res://scripts/stadtbau.gd")
var sb
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var w=Node3D.new();root.add_child(w)
	var sun=load("res://scripts/env.gd").make(w,"day");sun.shadow_enabled=true
	sb=SB.new();sb.rng.seed=11
	var flaeche=PackedVector2Array([Vector2(-190,-140),Vector2(190,-140),Vector2(190,140),Vector2(-190,140)])
	var strassen=[]
	# Hauptstraße geschwungen (Ost-West)
	var p=PackedVector2Array()
	for k in 39:var x=-200+k*10.5;p.append(Vector2(x,18.0*sin(x/55.0)))
	strassen.append({"p":p,"w":12.0})
	# gerade Nord-Süd-Straße (90°-Kreuzung)
	strassen.append({"p":PackedVector2Array([Vector2(-70,-150),Vector2(-70,150)]),"w":11.0})
	# schräge Straße (spitze Ecken)
	strassen.append({"p":PackedVector2Array([Vector2(30,-150),Vector2(130,150)]),"w":11.0})
	# Straße mit runder 90°-Kurve im Norden
	var r=PackedVector2Array()
	for k in 8:r.append(Vector2(-200+k*12,-85))
	for k in 11:var a=PI*0.5*k/10.0;r.append(Vector2(-116+30*sin(a),-85-30*(1-cos(a))))
	r.append(Vector2(-86,-150))
	strassen.append({"p":r,"w":10.0})
	# Querstraße im Süden
	strassen.append({"p":PackedVector2Array([Vector2(-200,90),Vector2(200,90)]),"w":11.0})
	# weitere Straßen für kleinere Blöcke
	strassen.append({"p":PackedVector2Array([Vector2(-200,-48),Vector2(200,-48)]),"w":10.0})
	strassen.append({"p":PackedVector2Array([Vector2(-5,-48),Vector2(-5,150)]),"w":10.0})
	# Randstraßen
	strassen.append({"p":PackedVector2Array([Vector2(-185,-150),Vector2(-185,150)]),"w":10.0})
	strassen.append({"p":PackedVector2Array([Vector2(185,-150),Vector2(185,150)]),"w":10.0})
	strassen.append({"p":PackedVector2Array([Vector2(-200,-135),Vector2(200,-135)]),"w":10.0})
	strassen.append({"p":PackedVector2Array([Vector2(-200,135),Vector2(200,135)]),"w":10.0})
	var bl=sb.bloecke(flaeche,strassen)
	var kreuz=sb.kreuzungen(strassen)
	print("PROBE Blöcke ",bl.size()," Kreuzungen ",kreuz.size())
	sb.fahrbahn(w,flaeche,strassen,kreuz)
	var liste=[["ghetto",7],["chicago_00",5],["cityscene2_29",2],["cityscene2_03",1],["cityscene2_06",1],["cityscene2_12",1],["cityscene2_10",1],["cityscene2_22",2],["cityscene2_35",2],
		["cityscene2_01",2],["cityscene2_02",2],["cityscene2_07",2],["cityscene2_11",2],["cityscene2_00",1],["cityscene2_05",1],["marino",1],["house",3]]
	var eck=[["house",7],["cityscene2_01",2],["cityscene2_11",2],["cityscene2_07",2],["cityscene2_00",1],["cityscene2_05",1]]
	# größter Block: Durchgang + Spielplatz; zweitgrößter: Waffenladen
	var groessen=[]
	for i in bl.size():groessen.append([sb._flaeche(bl[i]),i])
	groessen.sort();groessen.reverse()
	var WL=load("res://scripts/waffenladen_bau.gd").new()
	var infos={}
	var baum_mesh=load("res://scripts/welt_leben.gd").new(null,null,null).baum_nah()
	sb.baum_platz=baum_mesh
	var gassen=0
	var autos_hof=["small_car","mercedes","bmw_e30","f100","audi_rs7","supra","dodge"]
	for i in bl.size():
		var opt={"liste":liste,"eck":eck,"hoehen":[Vector2(5,14),Vector2(12.5,19)],
			"liste_hinten":[["ghetto",3],["cityscene2_01",2],["cityscene2_02",2],["cityscene2_07",2],["cityscene2_11",2],["chicago_00",1],["cityscene2_22",1],["cityscene2_35",1]]}
		var fl=sb._flaeche(bl[i])
		if i==groessen[0][1]:opt.hof="gruen";opt.ring_ab=99999.0
		elif fl>4000 and gassen<3 and i%3==0:opt.hof="gasse";gassen+=1
		elif fl>2500:opt.hof="hinterhof"
		else:opt.hof="hinterhof";opt.durchgang=false
		if i==groessen[1][1]:opt.sonder=[{"breite":WL.breite,"tiefe":WL.tiefe,"bau":WL.bau}]
		var e=sb.block(w,bl[i],0.0,opt)
		infos[i]=e
		sb.hof_ausstatten(w,e,0.16,baum_mesh,autos_hof)
		_ausstattung(w,bl[i],kreuz)
	# fahrende Autos mit Fahrer auf der Hauptstraße
	var FA=load("res://scripts/fahrer.gd");var rr=RandomNumberGenerator.new();rr.seed=5
	var hp:PackedVector2Array=strassen[0].p
	var fahr_autos=[]
	for k in [6,13,20,27]:
		var a:Vector2=hp[k];var b:Vector2=hp[k+1];var t=(b-a).normalized();var nn=Vector2(-t.y,t.x)
		var q=a+nn*2.6
		var auto=load("res://assets/cache/autos/"+["taxi","small_car","mercedes","audi_rs7"][k%4]+".scn").instantiate();w.add_child(auto)
		auto.position=Vector3(q.x,0.0,q.y);auto.rotation.y=atan2(t.x,t.y)
		FA.einsetzen(auto,FA.sitzend(["joe","daya","female","hqman"][k%4],rr))
		fahr_autos.append(auto)
	sb.fertig(w)
	for l in sb.log:print("PROBE ",l)
	var cam=Camera3D.new();w.add_child(cam);cam.fov=62;cam.far=1500
	if OS.get_cmdline_user_args().has("zoom"):
		cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=110;cam.rotation_degrees=Vector3(-90,0,0)
		var zi=0
		for q in [Vector2(-130,40),Vector2(-40,-90),Vector2(70,40),Vector2(-130,-90),Vector2(140,-20),Vector2(-40,40)]:
			cam.position=Vector3(q.x,200,q.y)
			for k in 4:await process_frame
			root.get_viewport().get_texture().get_image().save_png(OUT+"zoom_%d.png"%zi);zi+=1
		quit();return
	if OS.get_cmdline_user_args().has("oben"):
		cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=400;cam.position=Vector3(0,300,0);cam.rotation_degrees=Vector3(-90,0,0)
		for k in 6:await process_frame
		root.get_viewport().get_texture().get_image().save_png(OUT+"oben.png");quit();return
	var ansichten=[]
	# Kreuzungen
	var nk=0
	for k in kreuz:
		var q:Vector2=k.p
		if abs(q.x)>160 or abs(q.y)>120 or nk>=4:continue
		var arm=sb._arm(strassen[k.r[0]].p,q,1 if nk%2==0 else -1,30.0)
		if arm==null:continue
		var cp:Vector2=arm[0]+Vector2(-arm[1].y,arm[1].x)*2.5
		ansichten.append(["kreuzung",Vector3(cp.x,3.0,cp.y),Vector3(q.x,3.5,q.y)]);nk+=1
	# Durchgang + Hof
	var dl=infos[groessen[0][1]].get("durchgang",[])
	if dl.size()>0:
		var d=dl[0]
		var m:Vector2=d.p;var nn:Vector2=d.n
		ansichten.append(["durchgang",Vector3(m.x+nn.x*7,1.9,m.y+nn.y*7),Vector3(m.x-nn.x*14,1.8,m.y-nn.y*14)])
		var hm=_hofmitte(infos[groessen[0][1]].hof)
		ansichten.append(["spielplatz",Vector3(hm.x+14,4.5,hm.y+12),Vector3(hm.x,0.5,hm.y)])
	# Gasse und Hinterhof
	for i in infos:
		var e=infos[i]
		if e.get("typ","")=="gasse" and e.durchgang.size()>0 and not ansichten.any(func(x):return x[0]=="gasse"):
			var d2=e.durchgang[0]
			ansichten.append(["gasse",Vector3(d2.p.x+d2.n.x*5,1.8,d2.p.y+d2.n.y*5),Vector3(d2.p.x-d2.n.x*20,1.6,d2.p.y-d2.n.y*20)])
		if e.get("typ","")=="hinterhof" and e.durchgang.size()>0 and not ansichten.any(func(x):return x[0]=="hinterhof"):
			var d3=e.durchgang[0];var hc=_hofmitte(e.hof)
			ansichten.append(["hinterhof",Vector3(d3.p.x-d3.n.x*3,4.0,d3.p.y-d3.n.y*3),Vector3(hc.x,0.5,hc.y)])
	var ga=w.get_tree().get_nodes_in_group("geldautomat")
	if ga.size()>0:
		var gt:Transform3D=ga[0].global_transform
		ansichten.append(["geldautomat",gt*Vector3(0.8,1.7,4.5),gt*Vector3(0,1.2,0)])
	if gelaender_pos.size()>0:
		var gp:Vector2=gelaender_pos[0]
		ansichten.append(["gelaender",Vector3(gp.x+6,1.8,gp.y+6),Vector3(gp.x,0.6,gp.y)])
	# Autos mit Fahrer
	if fahr_autos.size()>0:
		var fa:Node3D=fahr_autos[0];var ft=fa.global_transform
		var ziel=fa.global_position+Vector3(0,1.1,0)
		ansichten.append(["fahrer",fa.global_position+ft.basis.x*3.0+ft.basis.z*0.4+Vector3(0,1.45,0),fa.global_position+ft.basis.x*0.3+Vector3(0,1.0,0)])
	# Waffenladen außen/innen
	var wl=w.find_child("WaffenKrause",true,false)
	if wl:
		var t:Transform3D=wl.global_transform
		ansichten.append(["waffenladen",t*Vector3(0.3,2.0,16.0),t*Vector3(0.3,3.6,0)])
		ansichten.append(["laden_innen",t*Vector3(2.5,1.7,4.5),t*Vector3(-2,1.3,-6)])
		ansichten.append(["laden_theke",t*Vector3(-4.5,1.7,1.5),t*Vector3(1,1.0,-2.5)])
		ansichten.append(["verkaeufer",t*Vector3(0.8,1.6,1.0),t*Vector3(-0.8,1.4,-3.0)])
	# Kurve der Hauptstraße und Luftbild
	ansichten.append(["kurve",Vector3(165,4.5,18*sin(165/55.0)),Vector3(100,5,18*sin(100/55.0))])
	ansichten.append(["runde_ecke",Vector3(-165,4.5,-85),Vector3(-95,6,-112)])
	ansichten.append(["luft",Vector3(-170,95,170),Vector3(-20,0,0)])
	var n=0
	for a in ansichten:
		cam.position=a[1];cam.look_at(a[2])
		for k in 6:await process_frame
		root.get_viewport().get_texture().get_image().save_png(OUT+"%02d_%s.png"%[n,a[0]]);n+=1
	quit()

func _hofmitte(h:PackedVector2Array)->Vector2:
	var c=Vector2.ZERO
	for v in h:c+=v
	return c/max(h.size(),1)

var gelaender_pos=[]
func _ausstattung(w:Node3D,poly:PackedVector2Array,kreuz:Array):
	var L=load("res://scripts/welt_leben.gd").new(null,null,null)
	var lampe=L.lamp_mesh();var baum=L.baum_nah()
	var autos=["small_car","taxi","mercedes","bmw_e30","f100","audi_rs7","polizei","porsche911","supra"]
	var n=poly.size()
	for i in n:
		var a:Vector2=poly[i];var c:Vector2=poly[(i+1)%n];var Lk=a.distance_to(c)
		if Lk<12.0:continue
		var t=(c-a)/Lk;var nn=sb._aussen(poly,a,c)
		var s=7.0
		while s<Lk-7.0:
			var p=a+t*s-nn*0.6
			var nah=false
			for k in kreuz:if k.p.distance_to(p)<16.0:nah=true
			if not nah:
				var lm=MeshInstance3D.new();lm.mesh=lampe;w.add_child(lm);lm.transform=Transform3D(Basis(Vector3.UP,atan2(nn.x,nn.y)+PI),Vector3(p.x,0.15,p.y))
				var p2=a+t*(s+8.0)-nn*1.4
				var gel=sb.rng.randf()<0.18 and s+16.0<Lk-4
				if gel:sb.gelaender(a+t*(s+1.5)-nn*0.35,t,14.0,0.15);gelaender_pos.append(a+t*(s+8.0))
				elif sb.rng.randf()<0.55 and s+8.0<Lk-4:
					sb.baum_setzen(w,baum,p2,0.15,sb.rng.randf_range(0.65,0.85))
				if sb.rng.randf()<0.4 and s+5<Lk-5:
					var auto=load("res://assets/cache/autos/"+autos[sb.rng.randi()%autos.size()]+".scn").instantiate();w.add_child(auto)
					var q=a+t*(s+4.5)+nn*1.3
					auto.position=Vector3(q.x,0.0,q.y);auto.rotation.y=atan2(t.x,t.y)
			s+=17.0
