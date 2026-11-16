extends Node
# Bilder-Rundgang für den Spieler: jedes Viertel auf einer echten Straße (Fahrerhöhe + Luftbild),
# Bahnübergang mit Zug, große Karte mit Legende. Aufruf: --test=galerie [--nur=a,b]
var spiel
var OUT:="/home/claude/shots_godot/galerie/"
const ORTE:=[["Innenstadt",Vector2(250,-350)],["Altstadt",Vector2(-150,-650)],["Nordstadt",Vector2(496,-168)],["Oststadt",Vector2(2550,850)],
	["Suedstadt",Vector2(250,1560)],["Ghetto",Vector2(-262,1040)],["Strand",Vector2(-2300,700)],["Industrie",Vector2(900,640)],
	["Docks",Vector2(500,2090)],["Wohnviertel_West",Vector2(-1083,-504)],["Sonnenhuegel",Vector2(-150,-1450)],["Ostvorort",Vector2(2900,-300)],
	["Staubwinkel",Vector2(1749,-5950)],["Nordbucht",Vector2(-119,-9032)],["Knast",Vector2(1800,-5050)]]
var cam:Camera3D

func start(sp):
	spiel=sp
	if OS.get_environment("GALERIE_OUT")!="":OUT=OS.get_environment("GALERIE_OUT")
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().create_timer(2.0).timeout
	cam=Camera3D.new();cam.far=4000;cam.fov=62;spiel.add_child(cam)
	spiel.ui.visible=false;spiel.zeit=11.0*60.0;spiel.st.e.sichtweite=2;spiel.st.e.schatten=true;spiel.einstellungen_anwenden()
	var nur=spiel._arg("--nur")
	if nur=="figur":await _figur();get_tree().quit();return
	if nur=="nord":await _nordstaedte();get_tree().quit();return
	if nur=="stil":await _stilprobe();get_tree().quit();return
	if nur=="stil2":await _stilprobe2();get_tree().quit();return
	if nur=="punkt":
		var pa=spiel._arg("--punkt").split(",");var q=Vector2(float(pa[0]),float(pa[1])) if pa.size()>=2 else Vector2(1982.6,-9101.3);spiel.welt.viertel_jetzt(q);spiel.spieler.global_position=Vector3(q.x,_boden(q)+80,q.y)
		for k in 30:await get_tree().process_frame
		await get_tree().create_timer(3.0).timeout
		var hq=_boden(q)
		var nv=0
		for m in get_tree().root.find_children("nd_villa_*","MultiMeshInstance3D",true,false):
			if m.name.ends_with("ink"):continue
			for i in m.multimesh.instance_count:
				var gx=m.global_transform*m.multimesh.get_instance_transform(i)
				if Vector2(gx.origin.x,gx.origin.z).distance_to(q)<300 and nv<8:
					nv+=1;var hs=[]
					for o in [Vector3(0,0,-16),Vector3(-8,0,-8),Vector3(8,0,-24),Vector3(-8,0,-24)]:
						var w=gx*o;hs.append([snappedf(_boden(Vector2(w.x,w.z))-gx.origin.y,0.01),snappedf(spiel.welt.G.h_at(w.x,w.z)-gx.origin.y,0.01)])
					print("VILLA y ",gx.origin.y," boden-diff ",hs)
		var vs=spiel._arg("--verstecke")
		if vs!="":
			for n in get_tree().root.find_children(vs,"",true,false):n.visible=false;print("VERSTECKT ",n.get_path())
		var ri=Vector2(60,30) if pa.size()<4 else Vector2(float(pa[2]),float(pa[3]))
		cam.look_at_from_position(Vector3(q.x,hq+2.0,q.y),Vector3(q.x+ri.x,hq+4.0,q.y+ri.y));cam.current=true
		await _foto("Punkt_boden")
		for px in [Vector2(1000,280),Vector2(1300,60),Vector2(250,380)]:
			var o=cam.project_ray_origin(px);var d=cam.project_ray_normal(px)
			for m in get_tree().root.find_children("*","GeometryInstance3D",true,false):
				if not m.is_visible_in_tree():continue
				if m is MultiMeshInstance3D:
					var mm=m.multimesh;if mm.mesh==null:continue
					var ab=mm.mesh.get_aabb()
					for i in mm.instance_count:
						var gx=m.global_transform*mm.get_instance_transform(i)
						var a2=gx*ab
						if a2.intersects_segment(o,o+d*80.0):print("TREFFER ",px," MMI ",m.get_path()," inst ",i," pos ",gx.origin," aabb ",a2.size)
				elif m is MeshInstance3D:
					var a2=m.global_transform*m.get_aabb()
					if a2.intersects_segment(o,o+d*80.0):print("TREFFER ",px," MESH ",m.get_path()," ",m.mesh.surface_get_material(0).resource_path if m.mesh and m.mesh.get_surface_count()>0 and m.mesh.surface_get_material(0) else (m.material_override.resource_path if m.material_override else "-")," ",a2.size)
		print("DC boden ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)," tri ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		cam.look_at_from_position(Vector3(q.x-120,hq+70.0,q.y-120),Vector3(q.x,hq,q.y))
		await _foto("Punkt_luft")
		print("DC luft ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)," tri ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		var n=0;var sicht=0
		for m in get_tree().root.find_children("nt_eiche*","MultiMeshInstance3D",true,false):
			n+=m.multimesh.instance_count;if m.is_visible_in_tree():sicht+=1
		print("EICHEN ",n," knoten sichtbar ",sicht)
		var z=0
		for m in get_tree().root.find_children("nt_eiche*","MultiMeshInstance3D",true,false):
			if m.name.ends_with("ink"):continue
			for i in m.multimesh.instance_count:
				var xf=m.global_transform*m.multimesh.get_instance_transform(i)
				if Vector2(xf.origin.x,xf.origin.z).distance_to(q)<80 and z<8:
					z+=1;print("BAUM y ",xf.origin.y," boden ",_boden(Vector2(xf.origin.x,xf.origin.z))," sichtbar ",m.is_visible_in_tree()," vr ",m.visibility_range_end, " aabb ",m.get_aabb())
		get_tree().quit();return
	for o in ORTE:
		if nur!="" and not o[0].to_lower() in nur.to_lower():continue
		await _ort(o[0],o[1])
	if nur=="" or "bahn" in nur:await _bahn()
	if nur=="" or "natur" in nur:await _natur()
	if nur=="" or "karte" in nur:await _karte()
	print("GALERIE fertig");get_tree().quit()

func _boden(p:Vector2)->float:
	var hit=spiel.kampf._ray(Vector3(p.x,800,p.y),Vector3(p.x,-80,p.y),[])
	return hit.position.y if hit else spiel.welt.G.h_at(p.x,p.y)
func _foto(name:String):
	for k in 5:await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(OUT+name+".png");print("FOTO ",name)
func _ort(name:String,ziel:Vector2):
	# nächste Straße (keine Autobahn) suchen, Blick entlang der Straße
	var S=spiel.welt.S;var best=null;var bd=1e9
	for ri in S.roads.size():
		var r=S.roads[ri]
		if r.typ in ["autobahn","rampe"]:continue
		for i in range(2,r.P.size()-2,3):
			var d=r.P[i].distance_to(ziel)
			if d<bd:bd=d;best=[r,i]
	if best==null:return
	var r=best[0];var i=best[1];var p:Vector2=r.P[i];var t:Vector2=r.T[i]
	spiel.welt.viertel_jetzt(p)
	spiel.spieler.global_position=Vector3(p.x,_boden(p)+0.5,p.y);spiel.spieler.velocity=Vector3.ZERO
	for k in 20:await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	var n=Vector2(-t.y,t.x)
	var a=p-t*14.0+n*r.w*0.4;var z=p+t*40.0
	cam.look_at_from_position(Vector3(a.x,_boden(a)+1.8,a.y),Vector3(z.x,_boden(z)+3.0,z.y));cam.current=true
	spiel.env.fog_enabled=true
	await _foto(name+"_1_strasse")
	var h=Vector3(p.x,_boden(p),p.y)
	cam.look_at_from_position(h+Vector3(-t.x*90+n.x*60,95,-t.y*90+n.y*60),h);spiel.env.fog_enabled=false
	await _foto(name+"_2_luft")

func _bahn():
	var z=spiel.zug
	if z==null or z.strecken.is_empty():print("GALERIE kein Zug");return
	# Bahnübergang: Gleispunkt nahe einer Straße
	var st=z.strecken[0];var S=spiel.welt.S;var kreuz=null
	for i in range(10,st.P.size()-10,2):
		var q=Vector2(st.P[i].x,st.P[i].z)
		var nr=S._near(q,8.0,-1)
		if not nr.is_empty() and S.roads[nr[0]].typ in ["strasse","allee"]:kreuz=[i,q,S.roads[nr[0]],nr[1]];break
	if kreuz==null:print("GALERIE kein Übergang");return
	var q:Vector2=kreuz[1];var r=kreuz[2];var t:Vector2=r.T[kreuz[3]]
	spiel.welt.viertel_jetzt(q)
	spiel.spieler.global_position=Vector3(q.x,_boden(q)+0.5,q.y)+Vector3(t.x,0,t.y)*20.0
	for k in 30:await get_tree().process_frame
	# Zug 160 m vor den Übergang setzen
	var zz=z.zuege[0];zz.strecke=0;zz.richtung=1;zz.s=st.S[kreuz[0]]-160.0
	var hq=_boden(q)
	var a=q-t*22.0+Vector2(-t.y,t.x)*3.0
	cam.look_at_from_position(Vector3(a.x,hq+2.0,a.y),Vector3(q.x,hq+1.5,q.y));cam.current=true
	spiel.env.fog_enabled=true
	await _foto("Bahn_1_uebergang_offen")
	zz.s=st.S[kreuz[0]]-70.0
	await get_tree().create_timer(2.5).timeout
	await _foto("Bahn_2_schranke_zu_zug_kommt")
	zz.s=st.S[kreuz[0]]+20.0
	await get_tree().create_timer(0.6).timeout
	await _foto("Bahn_3_zug_faehrt_durch")
	var w=zz.wagen[1].global_position
	cam.look_at_from_position(w+Vector3(18,9,22),w);await _foto("Bahn_4_zug_nah")
	cam.look_at_from_position(Vector3(q.x,hq+70,q.y)+Vector3(t.x,0,t.y)*60.0,Vector3(q.x,hq,q.y));spiel.env.fog_enabled=false
	await _foto("Bahn_5_von_oben")

func _karte():
	cam.current=false;spiel.ui.visible=true
	spiel.spieler.global_position=Vector3(-250,_boden(Vector2(-250,1000))+0.5,1000)
	spiel.karte_oeffnen()
	var k=spiel.panel
	for zf in [[2.5,"Karte_1_ganze_Stadt"],[9.0,"Karte_2_Innenstadt_Legende"]]:
		k.zoom=zf[0];k.mitte_w=Vector2(150,400) if zf[0]<5 else Vector2(-150,700);k.queue_redraw()
		await _foto(zf[1])
	spiel.panel_zu()
	spiel.mini.zoom=spiel.mini.zoom
	await _foto("Karte_3_Minikarte_im_Spiel")

func _figur():
	# Figur von der Seite auf einer Straße: steht sie auf dem Boden oder steckt sie drin?
	var p=Vector2(250,-350);var S=spiel.welt.S;var best=null;var bd=1e9
	for r in S.roads:
		if r.typ in ["autobahn","rampe"]:continue
		for i in range(2,r.P.size()-2,3):
			var d=r.P[i].distance_to(p)
			if d<bd:bd=d;best=[r,i]
	p=best[0].P[best[1]];var t:Vector2=best[0].T[best[1]]
	spiel.welt.viertel_jetzt(p)
	spiel.spieler.global_position=Vector3(p.x,_boden(p)+0.5,p.y);spiel.spieler.velocity=Vector3.ZERO
	for k in 30:await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var sp=spiel.spieler.global_position
	print("FIGUR fuss ",sp.y," boden ",_boden(p)," auf_boden ",spiel.spieler.is_on_floor())
	var n=Vector3(-t.y,0,t.x)
	cam.look_at_from_position(sp+n*3.2+Vector3(0,1.0,0),sp+Vector3(0,0.8,0));cam.current=true
	await _foto("Figur_seite")
	cam.look_at_from_position(sp-Vector3(t.x,0,t.y)*3.5+Vector3(0,1.6,0),sp+Vector3(0,0.9,0))
	await _foto("Figur_hinten")

func _natur():
	# Sonderorte in der Landschaft + eine Landstraße
	var n={}
	for o in spiel.welt.NATUR_ORTE:
		n[o.art]=n.get(o.art,0)+1
		if n[o.art]>2:continue
		var p=Vector2(o.p[0],o.p[2]);var yaw:float=o.yaw;var vor=Vector2(sin(yaw),cos(yaw))
		spiel.welt.viertel_jetzt(p)
		spiel.spieler.global_position=Vector3(p.x,_boden(p)+60.0,p.y)
		for k in 20:await get_tree().process_frame
		await get_tree().create_timer(2.0).timeout
		var a:Vector2;var hoch:=2.0
		match o.art:
			"villa":a=p+vor*75.0+Vector2(-vor.y,vor.x)*35.0;hoch=6.0
			"hanf":a=p+vor*90.0+Vector2(-vor.y,vor.x)*20.0;hoch=25.0
			_:a=p+vor*16.0+Vector2(-vor.y,vor.x)*9.0;hoch=2.2
		var ha=max(_boden(a),0.5)
		cam.look_at_from_position(Vector3(a.x,ha+hoch,a.y),Vector3(p.x,_boden(p)+2.0,p.y));cam.current=true
		spiel.env.fog_enabled=true
		await _foto("Natur_%s_%d"%[o.art,n[o.art]])
	# Landstraße im Norden + Waldrand
	for e in [["Land_Wald",Vector2(-400,-4200)],["Land_Hang",Vector2(1200,-6500)],["Land_Kueste",Vector2(-3000,-3000)]]:
		await _ort(e[0],e[1])

# ---------- Prüfung der Orte im Norden: 5 Bilder je Ort + Messung Gelände gegen Straße ----------
func _nordstaedte():
	var S=spiel.welt.S;var G=spiel.welt.G
	var stadt:Rect2=spiel.welt.B.rect
	# Ortsstraßen außerhalb der Stadt zu Orten zusammenfassen (Zellen 300 m, Nachbarn verbinden)
	var zellen={}
	for ri in S.roads.size():
		var r=S.roads[ri]
		if r.typ in ["autobahn","rampe"] or r.P.size()<2:continue
		var m:Vector2=r.P[r.P.size()/2]
		if stadt.grow(150).has_point(m):continue
		var k=Vector2i(int(floor(m.x/300.0)),int(floor(m.y/300.0)))
		if not zellen.has(k):zellen[k]=[]
		zellen[k].append(ri)
	# nur dichte Zellen (Ortskern: mind. 3 Straßenstücke) – Landstraßen allein verbinden keine Orte
	var dicht={}
	for k in zellen:
		if zellen[k].size()>=3:dicht[k]=zellen[k]
	zellen=dicht
	var orte=[];var gesehen={}
	for k in zellen:
		if gesehen.has(k):continue
		var stapel=[k];var ro=[];gesehen[k]=true
		while not stapel.is_empty():
			var c=stapel.pop_back();ro.append_array(zellen[c])
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1)]:
				if zellen.has(c+d) and not gesehen.has(c+d):gesehen[c+d]=true;stapel.append(c+d)
		if ro.size()>=5:orte.append(ro)
	print("NORD Orte gefunden ",orte.size())
	var nr=0
	for ro in orte:
		nr+=1
		var sum=Vector2.ZERO;var n=0
		for ri in ro:sum+=S.roads[ri].P[S.roads[ri].P.size()/2];n+=1
		var mitte=sum/n
		# Messung: Gelände über Fahrbahn (sticht durch) / Fahrbahn über Gelände (man kann drunter)
		var ueber=0.0;var unter=0.0;var wo_u=Vector2.ZERO;var wo_d=Vector2.ZERO
		for ri in ro:
			var r=S.roads[ri]
			for i in r.P.size():
				var p:Vector2=r.P[i];var t:Vector2=r.T[i] if i<r.T.size() else Vector2(1,0);var nn=Vector2(-t.y,t.x)
				for q in [-0.9,-0.45,0.0,0.45,0.9]:
					var w=p+nn*r.w*q;var g=G.h_at(w.x,w.y)-float(r.h[i])
					if g>ueber:ueber=g;wo_u=w
					if -g>unter:unter=-g;wo_d=w
		await _laden(mitte);_schwebe_suche(mitte,350.0,nr)
		print("MESS Ort %d bei (%d,%d): Strassen %d  Gelaende ueber Fahrbahn max %.2f m bei %s  Fahrbahn ueber Gelaende max %.2f m bei %s"%[nr,mitte.x,mitte.y,ro.size(),ueber,str(wo_u.round()),unter,str(wo_d.round())])
		# 3 Straßenbilder (Mitte, zwei Enden), schräg von oben, Luftbild
		var ausw=[]
		var bm=-1;var bd=1e9
		for ri in ro:
			var d=S.roads[ri].P[S.roads[ri].P.size()/2].distance_to(mitte)
			if d<bd:bd=d;bm=ri
		ausw.append(bm)
		var fern=-1;var fd=-1.0
		for ri in ro:
			var d=S.roads[ri].P[S.roads[ri].P.size()/2].distance_to(mitte)
			if d>fd:fd=d;fern=ri
		ausw.append(fern)
		var dritte=-1;var dd=-1.0
		for ri in ro:
			var m=S.roads[ri].P[S.roads[ri].P.size()/2]
			var d=min(m.distance_to(mitte),m.distance_to(S.roads[fern].P[S.roads[fern].P.size()/2]))
			if d>dd:dd=d;dritte=ri
		ausw.append(dritte)
		spiel.welt.viertel_jetzt(mitte)
		var k=0
		for ri in ausw:
			k+=1
			var r=S.roads[ri];var i=r.P.size()/2;var p:Vector2=r.P[i];var t:Vector2=r.T[i]
			spiel.spieler.global_position=Vector3(p.x,float(r.h[i])+60.0,p.y)
			# Kamera schon hierhin, sonst entlädt die Welt die frisch geladenen Viertel wieder (Kamera noch am alten Ort)
			cam.global_position=Vector3(p.x,float(r.h[i])+3.0,p.y);cam.current=true
			for rund in 3:
				spiel.welt.viertel_jetzt(p)
				for f in 15:await get_tree().process_frame
				await get_tree().create_timer(1.5).timeout
			var h=float(r.h[i])
			# Bodenfleck-Test: ein Auto steht, eins "springt" (2 m hoch, schräg) – der Fleck muss flach am Boden bleiben
			var ta=[]
			if k==1:
				ta=_autos_parken(r,min(i+2,r.P.size()-3),["c_trabant_blau","c_jdm_blau"])
				if ta.size()==2:
					var sp=ta[1];sp.modus="spieler";sp.freeze=true
					sp.global_transform=Transform3D(Basis(Vector3.UP,atan2(t.x,t.y)+PI)*Basis(Vector3.RIGHT,0.35),sp.global_position+Vector3(0,2.0,0))
				for f in 40:await get_tree().physics_frame
			cam.look_at_from_position(Vector3(p.x-t.x*9.0,h+3.2,p.y-t.y*9.0),Vector3(p.x+t.x*30.0,h+1.0,p.y+t.y*30.0));cam.current=true
			await _foto("Nord_%02d_%d_strasse"%[nr,k])
			if nr==2 and k==2:await _villa_fotos(Vector3(p.x,h,p.y))
			if ta.size()==2 and nr<=2:
				var a0:Vector3=ta[0].global_position;var a1:Vector3=ta[1].global_position
				cam.look_at_from_position((a0+a1)*0.5+Vector3(t.y*9.0,3.0,-t.x*9.0)-Vector3(t.x,0,t.y)*6.0,(a0+a1)*0.5);cam.current=true
				await _foto("Nord_%02d_7_autofleck"%nr)
			for c in ta:spiel.geparkt.erase(c);c.queue_free()
		if not SCHWEBE_LISTE.is_empty():
			SCHWEBE_LISTE.sort_custom(func(a,b):return a[0]>b[0])
			var w:Vector3=SCHWEBE_LISTE[0][2];print("SCHWEBT schlimmste ",SCHWEBE_LISTE.slice(0,6))
			cam.global_position=w+Vector3(-14,6,14);await _laden(Vector2(w.x,w.z))
			cam.look_at_from_position(w+Vector3(-14,6,14),w);cam.current=true
			await _foto("Nord_%02d_6_schwebt"%nr)
			SCHWEBE_LISTE.clear()
		var hm=G.h_at(mitte.x,mitte.y)
		cam.look_at_from_position(Vector3(mitte.x-70,hm+28.0,mitte.y+70),Vector3(mitte.x,hm,mitte.y))
		await _foto("Nord_%02d_4_schraeg"%nr)
		cam.look_at_from_position(Vector3(mitte.x-160,hm+140.0,mitte.y+160),Vector3(mitte.x,hm,mitte.y))
		await _foto("Nord_%02d_5_luft"%nr)

# ---------- Stil-Probe: gleiche Ansichten vorher/nachher (gemalte Texturen, Tusche-Konturen, Licht) ----------
const STIL=preload("res://scripts/stil.gd")
const PROBE_AUTOS:=["c_trabant_blau","c_jdm_blau","c_muscle_schwarz","c_wartburg_gruen","c_e30_silber","c_polizei","c_trabant_rot","c_jdm_weiss"]
func _hang_strasse(nahe:Vector2,radius:float):
	var S=spiel.welt.S;var best=-1;var bs=0.0
	for ri in S.roads.size():
		var r=S.roads[ri]
		if r.typ in ["autobahn","rampe"] or r.P.size()<8:continue
		if r.P[r.P.size()/2].distance_to(nahe)>radius:continue
		var i0=r.P.size()/4;var i1=r.P.size()*3/4
		var lg=r.P[i0].distance_to(r.P[i1])
		if lg<40.0:continue
		var st=abs(float(r.h[i1])-float(r.h[i0]))/lg
		if st>bs and st<0.16:bs=st;best=ri
	print("STIL Hangstrasse ",best," Steigung ",bs)
	return best
func _autos_parken(r,i0:int,kinds:Array)->Array:
	var out=[];var k=0;var i=i0
	while k<kinds.size() and i<r.P.size()-1:
		var p:Vector2=r.P[i];var t:Vector2=r.T[i];var nn=Vector2(-t.y,t.x);var sd=1.0 if k%2==0 else -1.0
		var q=p+nn*sd*(r.w-1.3)
		var c=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c);c.setup(kinds[k])
		var yaw=atan2(t.x,t.y)+(0.0 if sd>0 else PI)
		c.global_transform=Transform3D(Basis(Vector3.UP,yaw),Vector3(q.x,_boden(q)+0.5,q.y))
		c.modus="geparkt";spiel.geparkt.append(c);out.append(c)
		k+=1;i+=2
	return out
func _messen(name:String):
	var t0=Time.get_ticks_usec()
	for f in 30:await get_tree().process_frame
	var ms=(Time.get_ticks_usec()-t0)/30000.0
	print("STIL Leistung %s: %.1f ms/Bild (CI-Software-Grafik, nur Vergleich) DC %d Dreiecke %.2fM"%[name,ms,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)/1e6])
func _stilprobe():
	var S=spiel.welt.S
	var sonne:DirectionalLight3D=null
	for l in get_tree().root.find_children("*","DirectionalLight3D",true,false):sonne=l;break
	var env_alt=spiel.env.duplicate();var sonne_alt=[sonne.light_color,sonne.light_energy] if sonne else []
	var kon=null
	# zwei Orte nacheinander, jeweils erst vorher, dann nachher (sonst entlädt der zweite Ort den ersten)
	for ort in 2:
		var ansichten=[];var p:Vector2;var autos=[]
		if ort==0:
			var ri=_hang_strasse(Vector2(1752,-7559),600.0)
			if ri<0:ri=_hang_strasse(Vector2(-2504,-8463),700.0)
			var r=S.roads[ri];var i=r.P.size()/4
			p=r.P[i];var t:Vector2=r.T[i]
			if float(r.h[min(i+6,r.P.size()-1)])<float(r.h[i]):t=-t
			await _laden(p)
			autos=_autos_parken(r,i+2 if t.dot(r.T[i])>0 else max(i-12,1),PROBE_AUTOS.slice(0,6))
			var h=float(r.h[i]);var nn=Vector2(-t.y,t.x)
			spiel.spieler.global_position=Vector3(p.x+t.x*4.0,h+0.3,p.y+t.y*4.0);spiel.spieler.rotation.y=atan2(-t.x,-t.y)
			ansichten.append(["hang_strasse",Vector3(p.x-t.x*7.0,h+2.6,p.y-t.y*7.0),Vector3(p.x+t.x*40.0,h+5.0,p.y+t.y*40.0)])
			var a0:Vector3=autos[0].global_position
			ansichten.append(["autos_nah",a0+Vector3(-nn.x*6.0-t.x*5.0,1.8,-nn.y*6.0-t.y*5.0),a0+Vector3(t.x*6.0,0.6,t.y*6.0)])
			ansichten.append(["haeuser_nah",Vector3(p.x+t.x*12.0-nn.x*2.0,h+1.9,p.y+t.y*12.0-nn.y*2.0),Vector3(p.x+t.x*22.0+nn.x*20.0,h+3.0,p.y+t.y*22.0+nn.y*20.0)])
			ansichten.append(["ort_schraeg",Vector3(p.x-t.x*60.0+nn.x*40.0,h+30.0,p.y-t.y*60.0+nn.y*40.0),Vector3(p.x+t.x*30.0,h,p.y+t.y*30.0)])
		else:
			var q=Vector2(250,-350);var best=null;var bd=1e9
			for rr in S.roads:
				if rr.typ in ["autobahn","rampe"]:continue
				for k in range(2,rr.P.size()-2,3):
					var d=rr.P[k].distance_to(q)
					if d<bd:bd=d;best=[rr,k]
			var r2=best[0];var k2:int=best[1];p=r2.P[k2];var t2:Vector2=r2.T[k2];var h2=float(r2.h[k2])
			await _laden(p)
			autos=_autos_parken(r2,max(k2-3,1),["c_jdm_rot","c_trabant_gruen","c_sport_rot","c_skyline_dummy"].slice(0,3))
			spiel.spieler.global_position=Vector3(p.x+t2.x*3.0,h2+0.3,p.y+t2.y*3.0)
			ansichten.append(["stadt_strasse",Vector3(p.x-t2.x*12.0,h2+3.2,p.y-t2.y*12.0),Vector3(p.x+t2.x*40.0,h2+3.0,p.y+t2.y*40.0)])
			var b0:Vector3=autos[1].global_position
			ansichten.append(["stadt_trabi",b0+Vector3(-t2.x*5.5-t2.y*4.0,1.5,-t2.y*5.5+t2.x*4.0),b0+Vector3(0,0.5,0)])
		for c in autos:c.freeze=true
		for a in ansichten:
			cam.look_at_from_position(a[1],a[2]);cam.current=true
			await _foto("Stil_%s_1_vorher"%a[0])
		if ort==0:cam.look_at_from_position(ansichten[0][1],ansichten[0][2]);await _messen("vorher")
		var n=STIL.anwenden(spiel.welt);print("STIL Materialien umgestellt ",n)
		kon=STIL.kontur_knoten();get_tree().root.add_child(kon)
		STIL.licht(spiel.env,sonne)
		for f in 10:await get_tree().process_frame
		for a in ansichten:
			cam.look_at_from_position(a[1],a[2]);cam.current=true
			await _foto("Stil_%s_2_nachher"%a[0])
		if ort==0:cam.look_at_from_position(ansichten[0][1],ansichten[0][2]);await _messen("nachher")
		# zurück auf den alten Stil für den nächsten Ort
		STIL.zuruecksetzen();kon.queue_free()
		spiel.env.adjustment_enabled=env_alt.adjustment_enabled;spiel.env.fog_density=env_alt.fog_density;spiel.env.ambient_light_energy=env_alt.ambient_light_energy
		if sonne:sonne.light_color=sonne_alt[0];sonne.light_energy=sonne_alt[1]
		for c in autos:c.queue_free()
func _laden(p:Vector2):
	spiel.spieler.global_position=Vector3(p.x,spiel.welt.G.h_at(p.x,p.y)+40.0,p.y)
	for rund in 6:
		spiel.welt.viertel_jetzt(p)
		for f in 20:await get_tree().process_frame
		await get_tree().create_timer(1.5).timeout

# ---------- Stil-Probe 2: Musterhäuser, matte Scheiben, weiche Schatten / ohne Schatten ----------
const MH=preload("res://scripts/musterhaus.gd")
func _haeuser_tauschen(mitte:Vector2,radius:float)->Node3D:
	# alte Hausbausätze im Umkreis ausblenden (Instanz auf Größe 0) und an ihrer Stelle Musterhäuser bauen
	var neu=Node3D.new();neu.name="Musterstrasse";spiel.welt.add_child(neu)
	var farben=[[Color(0.72,0.24,0.2),Color(0.2,0.3,0.25)],[Color(0.86,0.76,0.56),Color(0.35,0.25,0.18)],[Color(0.45,0.52,0.62),Color(0.62,0.2,0.18)],[Color(0.6,0.72,0.62),Color(0.9,0.9,0.86)],[Color(0.9,0.88,0.8),Color(0.2,0.28,0.45)],[Color(0.55,0.5,0.62),Color(0.95,0.93,0.88)]]
	var plaetze=[];var n=0
	for m in spiel.welt.find_children("*","MultiMeshInstance3D",true,false):
		var nm:String=m.name
		if not (nm.begins_with("nd_") or nm.begins_with("ld_")):continue
		if m.multimesh==null or m.multimesh.mesh==null:continue
		var ab:AABB=m.multimesh.mesh.get_aabb()
		if ab.size.x<6.0 or ab.size.z<6.0 or ab.size.y<4.0:continue
		var mm=m.multimesh
		for i in mm.instance_count:
			var xf:Transform3D=mm.get_instance_transform(i);var w=m.global_transform*xf
			if Vector2(w.origin.x,w.origin.z).distance_to(mitte)>radius:continue
			var vs=neu.get_meta("versteckt",[]);vs.append([m,i,xf]);neu.set_meta("versteckt",vs)
			if not nm.ends_with("ink"):
				var dup=false
				for q in plaetze:
					if q.origin.distance_to(w.origin)<3.0:dup=true
				if not dup:plaetze.append(w)
	for w in plaetze:
		var f=farben[n%farben.size()];n+=1
		var h=MH.bauen(f[0],f[1],Color(0.42,0.36,0.33) if n%2==0 else Color(0.35,0.36,0.4),n%3!=0)
		var b=w.basis.orthonormalized();var vor=b*Vector3(0,0,1)
		neu.add_child(h);h.set_meta("mh",true)
		h.global_transform=Transform3D(b,w.origin-vor*9.0)
		MH.briefkasten(neu,w.origin+b*Vector3(2.0,0,1.0),atan2(vor.x,vor.z))
	print("STIL2 Häuser getauscht ",plaetze.size())
	return neu
func _beschriftung_merken(name:String,text:String):
	var f=FileAccess.open(OUT+"beschriftung.txt",FileAccess.READ_WRITE if FileAccess.file_exists(OUT+"beschriftung.txt") else FileAccess.WRITE)
	f.seek_end();f.store_line(name+"|"+text);f.close()
func _haus_strasse()->int:
	# Ortsstraße im Norden mit den meisten Häusern in 35 m (Steigung als Bonus)
	var S=spiel.welt.S;var best=-1;var bw=-1.0
	var orte=[Vector2(1752,-7559),Vector2(-2504,-8463),Vector2(-1577,-9220)]
	for ri in S.roads.size():
		var r=S.roads[ri]
		if r.typ in ["autobahn","rampe"] or r.P.size()<8:continue
		var m:Vector2=r.P[r.P.size()/2];var nah=false
		for o in orte:
			if m.distance_to(o)<500.0:nah=true
		if not nah:continue
		var i0=r.P.size()/4;var i1=r.P.size()*3/4;var lg=r.P[i0].distance_to(r.P[i1])
		if lg<40.0:continue
		var st=abs(float(r.h[i1])-float(r.h[i0]))/lg
		var w=float(r.P.size())*(1.0+st*6.0)
		if r.typ in ["strasse","land"]:w*=0.3
		if w>bw:bw=w;best=ri
	print("STIL2 Strasse ",best)
	return best
func _stilprobe2():
	var S=spiel.welt.S
	var sonne:DirectionalLight3D=null
	for l in get_tree().root.find_children("*","DirectionalLight3D",true,false):sonne=l;break
	var sonne_alt=[sonne.light_color,sonne.light_energy,sonne.shadow_blur,sonne.directional_shadow_max_distance] if sonne else []
	var adj=[spiel.env.adjustment_enabled,spiel.env.fog_density,spiel.env.ambient_light_energy]
	for ort in 2:
		var ansichten=[];var p:Vector2;var autos=[];var extra:Node3D=null
		if ort==0:
			var ri=_haus_strasse()
			var r=S.roads[ri];var i=r.P.size()/4
			p=r.P[i];var t:Vector2=r.T[i]
			if float(r.h[min(i+6,r.P.size()-1)])<float(r.h[i]):t=-t
			await _laden(p)
			extra=_haeuser_tauschen(p,160.0)
			for k in range(1,r.P.size()-1,4):MH.gully(extra,Vector3(r.P[k].x+r.T[k].y*1.6,float(r.h[k])+0.01,r.P[k].y-r.T[k].x*1.6))
			extra.visible=false
			autos=_autos_parken(r,i+2 if t.dot(r.T[i])>0 else max(i-12,1),["c_trabant_blau","c_jdm_blau","c_muscle_schwarz","c_wartburg_gruen"])
			var h=float(r.h[i]);var nn=Vector2(-t.y,t.x)
			spiel.spieler.global_position=Vector3(p.x+t.x*4.0,h+0.3,p.y+t.y*4.0);spiel.spieler.rotation.y=atan2(-t.x,-t.y)
			ansichten.append(["hang_strasse",Vector3(p.x-t.x*7.0,h+2.4,p.y-t.y*7.0),Vector3(p.x+t.x*40.0,h+4.0,p.y+t.y*40.0)])
			var hs=extra.get_children().filter(func(x):return x.has_meta("mh"))
			hs.sort_custom(func(a,b):return Vector2(a.global_position.x,a.global_position.z).distance_to(p)<Vector2(b.global_position.x,b.global_position.z).distance_to(p))
			for j in min(2,hs.size()):
				var hh:Node3D=hs[j];var vor=hh.global_transform.basis*Vector3(0,0,1);var seit=hh.global_transform.basis*Vector3(1,0,0)
				var z=hh.global_position+Vector3(0,3.5,0)
				ansichten.append(["haus_nah%d"%(j+1),hh.global_position+vor*17.0+seit*7.0+Vector3(0,1.8,0),z])
			var a0:Vector3=autos[0].global_position
			ansichten.append(["autos",a0+Vector3(-nn.x*6.0-t.x*5.0,1.6,-nn.y*6.0-t.y*5.0),a0+Vector3(t.x*6.0,0.6,t.y*6.0)])
		else:
			var q=Vector2(250,-350);var best=null;var bd=1e9
			for rr in S.roads:
				if rr.typ in ["autobahn","rampe"]:continue
				for k in range(2,rr.P.size()-2,3):
					var d=rr.P[k].distance_to(q)
					if d<bd:bd=d;best=[rr,k]
			var r2=best[0];var k2:int=best[1];p=r2.P[k2];var t2:Vector2=r2.T[k2];var h2=float(r2.h[k2])
			await _laden(p)
			autos=_autos_parken(r2,max(k2-3,1),["c_jdm_rot","c_trabant_gruen","c_sport_rot"])
			spiel.spieler.global_position=Vector3(p.x+t2.x*3.0,h2+0.3,p.y+t2.y*3.0)
			ansichten.append(["stadt_strasse",Vector3(p.x-t2.x*12.0,h2+3.2,p.y-t2.y*12.0),Vector3(p.x+t2.x*40.0,h2+3.0,p.y+t2.y*40.0)])
			var b0:Vector3=autos[1].global_position
			ansichten.append(["stadt_trabi",b0+Vector3(-t2.x*5.5-t2.y*4.0,1.5,-t2.y*5.5+t2.x*4.0),b0+Vector3(0,0.5,0)])
		for c in autos:c.freeze=true
		for a in ansichten:
			cam.look_at_from_position(a[1],a[2]);cam.current=true
			await _foto("S2_%s_1"%a[0])
		if extra:
			# Vorher-Bilder sind gemacht: alte Häuser weg, Musterhäuser sichtbar
			extra.visible=true
			for m in extra.get_meta("versteckt",[]):
				m[0].multimesh.set_instance_transform(m[1],Transform3D(Basis().scaled(Vector3(0.0001,0.0001,0.0001)),m[2].origin))
		var n=STIL.anwenden(spiel.welt);print("STIL2 Materialien ",n," matt ",STIL.matt(get_tree().root))
		var kon=STIL.kontur_knoten();get_tree().root.add_child(kon)
		STIL.licht(spiel.env,sonne);STIL.schatten(sonne,"weich")
		for f in 10:await get_tree().process_frame
		for a in ansichten:
			cam.look_at_from_position(a[1],a[2]);cam.current=true
			await _foto("S2_%s_2"%a[0])
		if ort==0:cam.look_at_from_position(ansichten[0][1],ansichten[0][2]);await _messen("nachher weiche Schatten")
		STIL.schatten(sonne,"aus")
		for f in 5:await get_tree().process_frame
		for a in ansichten:
			cam.look_at_from_position(a[1],a[2]);cam.current=true
			await _foto("S2_%s_3"%a[0])
		if ort==0:cam.look_at_from_position(ansichten[0][1],ansichten[0][2]);await _messen("nachher ohne Schatten")
		STIL.zuruecksetzen();kon.queue_free()
		if extra:extra.queue_free()
		spiel.env.adjustment_enabled=adj[0];spiel.env.fog_density=adj[1];spiel.env.ambient_light_energy=adj[2]
		if sonne:
			sonne.shadow_enabled=true;sonne.light_color=sonne_alt[0];sonne.light_energy=sonne_alt[1];sonne.shadow_blur=sonne_alt[2];sonne.directional_shadow_max_distance=sonne_alt[3]
		for c in autos:c.queue_free()

# Schwebende Teile suchen: jede MultiMesh-Kopie (Natur, Deko, Häuser) im Umkreis – liegt ihre Unterkante
# mehr als 0,8 m über dem Boden darunter (Strahl auf Gelände/Kollision), wird sie gemeldet
var SCHWEBE_LISTE:=[]
func _schwebe_suche(mitte:Vector2,radius:float,nr:int):
	var ss=spiel.get_world_3d().direct_space_state;var funde={}
	for m in get_tree().root.find_children("*","MultiMeshInstance3D",true,false):
		var nm:String=m.name
		if nm.ends_with("_ink") or m.multimesh==null or m.multimesh.mesh==null:continue
		var ab:AABB=m.multimesh.mesh.get_aabb()
		if ab.size.y<0.15:continue
		var mm=m.multimesh
		for i in mm.instance_count:
			var gx:Transform3D=m.global_transform*mm.get_instance_transform(i)
			if gx.basis.get_scale().x<0.01:continue
			var c=gx*ab.get_center()
			if Vector2(c.x,c.z).distance_to(mitte)>radius:continue
			var unten=(gx*ab).position.y
			var q=PhysicsRayQueryParameters3D.create(Vector3(c.x,unten+0.3,c.z),Vector3(c.x,unten-30.0,c.z))
			var r=ss.intersect_ray(q)
			var boden=r.position.y if not r.is_empty() else spiel.welt.G.h_at(c.x,c.z)
			var dh=unten-boden
			if dh>0.8 and not nm.begins_with("NF_") and not nm.begins_with("nt_fern"):
				SCHWEBE_LISTE.append([dh,nm,c])
				var pre=nm.substr(0,nm.rfind("_")) if nm.rfind("_")>0 else nm
				if not funde.has(pre):funde[pre]=[0,0.0,Vector3()]
				funde[pre][0]+=1
				if dh>funde[pre][1]:funde[pre][1]=dh;funde[pre][2]=c
	print("SCHWEBT Ort ",nr," ",funde)

# Nächste Villa zur Kamera: von vorne (Straße) und von hinten (Garten) fotografieren
func _villa_fotos(nah:Vector3):
	var best=null;var bd=1e9
	for m in get_tree().root.find_children("nd_villa*","MultiMeshInstance3D",true,false):
		if String(m.name).ends_with("ink"):continue
		for i in m.multimesh.instance_count:
			var gx:Transform3D=m.global_transform*m.multimesh.get_instance_transform(i)
			if gx.basis.get_scale().x<0.01:continue
			var d=gx.origin.distance_to(nah)
			if d<bd:bd=d;best=gx
	if best==null:print("VILLA keine gefunden");return
	var b:Basis=best.basis.orthonormalized();var o:Vector3=best.origin
	var mitte=o-b.z*16.0+Vector3(0,3.0,0)
	print("VILLA bei ",o," Abstand ",bd)
	cam.look_at_from_position(o+b.z*14.0+b.x*6.0+Vector3(0,3.5,0),mitte);cam.current=true
	await _foto("Villa_1_vorne")
	cam.look_at_from_position(o-b.z*46.0-b.x*8.0+Vector3(0,5.0,0),mitte);cam.current=true
	await _foto("Villa_2_hinten")
