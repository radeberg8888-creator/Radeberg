extends Node
# Bilder-Rundgang für den Spieler: jedes Viertel auf einer echten Straße (Fahrerhöhe + Luftbild),
# Bahnübergang mit Zug, große Karte mit Legende. Aufruf: --test=galerie [--nur=a,b]
var spiel
const OUT:="/home/claude/shots_godot/galerie/"
const ORTE:=[["Innenstadt",Vector2(250,-350)],["Altstadt",Vector2(-150,-650)],["Nordstadt",Vector2(496,-168)],["Oststadt",Vector2(2550,850)],
	["Suedstadt",Vector2(250,1560)],["Ghetto",Vector2(-262,1040)],["Strand",Vector2(-2300,700)],["Industrie",Vector2(900,640)],
	["Docks",Vector2(500,2090)],["Wohnviertel_West",Vector2(-1083,-504)],["Sonnenhuegel",Vector2(-150,-1450)],["Ostvorort",Vector2(2900,-300)],
	["Staubwinkel",Vector2(1749,-5950)],["Nordbucht",Vector2(-119,-9032)],["Knast",Vector2(1800,-5050)]]
var cam:Camera3D

func start(sp):
	spiel=sp
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().create_timer(2.0).timeout
	cam=Camera3D.new();cam.far=4000;cam.fov=62;spiel.add_child(cam)
	spiel.ui.visible=false;spiel.zeit=11.0*60.0;spiel.st.e.sichtweite=2;spiel.st.e.schatten=true;spiel.einstellungen_anwenden()
	var nur=spiel._arg("--nur")
	if nur=="figur":await _figur();get_tree().quit();return
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
