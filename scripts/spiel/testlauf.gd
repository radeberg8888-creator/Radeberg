extends Node
# Automatischer Spieltest: simuliert Eingaben und speichert Bildschirmfotos (nur am PC mit -- --test).
var spiel
var t:=0.0
var _cam_b:Camera3D=null
var _n:=0
var schritt:=0
var bilder:=0
const OUT:="/home/claude/shots_godot/spiel_"
func shot(name:String):
	if DisplayServer.get_name()!="headless":
		var img=get_viewport().get_texture().get_image();img.save_png(OUT+"%02d_%s.png"%[bilder,name])
	bilder+=1
	print("  verkehr=",spiel.verkehr.size()," geparkt=",spiel.geparkt.size()," passanten sichtbar=",spiel.passanten.filter(func(e):return e.n.visible).size())
	for c in spiel.verkehr.slice(0,3):print("   ki ",c.kind," ",c.global_position.snapped(Vector3.ONE*0.1)," v=",snapped(c.ki_speed,0.1))
	if spiel.auto:print("  AUTO ",spiel.auto.global_position.snapped(Vector3.ONE*0.1)," kmh ",snapped(spiel.auto.kmh(),0.1))
	print("LEISTUNG ",name," Aufrufe=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," Dreiecke=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," Objekte=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)," Knoten=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)," Logik_ms=",snapped(Performance.get_monitor(Performance.TIME_PROCESS)*1000,0.1)," Physik_ms=",snapped(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,0.1)," PROF ",spiel.prof if "prof" in spiel else "")
	if spiel._arg("--zaehlen")!="":
		var cam=get_viewport().get_camera_3d();var cp=cam.global_position;var Z={}
		for n in get_tree().root.find_children("*","GeometryInstance3D",true,false):
			if not n.is_visible_in_tree():continue
			var d=n.global_position.distance_to(cp)
			var rv=n.visibility_range_end
			if rv>0 and d>rv+n.visibility_range_end_margin:continue
			if d>1600:continue
			var top=n;var pfad=""
			while top.get_parent()!=null and top.get_parent()!=get_tree().root:
				top=top.get_parent()
			var k=top.name+"/"+n.get_class()+("/"+n.get_parent().name.left(10) if top!=n.get_parent() else "")
			k=k.left(48)
			Z[k]=Z.get(k,0)+1
		var ks=Z.keys();ks.sort_custom(func(a,b):return Z[a]>Z[b])
		for k in ks.slice(0,14):print("   ZAEHL ",Z[k]," ",k)
	print("TESTBILD ",name," fps=",Engine.get_frames_per_second()," pos=",spiel.spieler.global_position," auto=",spiel.auto!=null," kmh=",spiel.auto.kmh() if spiel.auto else 0)

var ui_schritt:=0
var _ab:=0
func _process(dt):
	t+=dt
	var st=spiel.st
	if spiel.test_modus=="biker":
		var B=spiel.biker
		if ui_schritt==0:
			if t<3.0:return
			var tr=B.treffs["hoellenhunde"];var p:Vector2=tr.p[0];var n=Vector2(-tr.p[1].y,tr.p[1].x)
			var q=p+n*14.0
			var hit=spiel.kampf._ray(Vector3(q.x,500,q.y),Vector3(q.x,-50,q.y),[])
			spiel.spieler.global_position=Vector3(q.x,hit.position.y+0.3,q.y)
			var v=Vector3(p.x-q.x,0,p.y-q.y);spiel.kam.yaw=atan2(v.x,v.z)+PI;spiel.kam.pitch=-10.0
			ui_schritt=1;t=0;return
		if ui_schritt==1:
			if t<4.0:return
			shot("biker_treff");print("BIKER treff an=",B.treffs["hoellenhunde"].an," leute=",B.treffs["hoellenhunde"].leute.size()," bikes=",B.treffs["hoellenhunde"].bikes.size())
			var mp=Vector2(spiel.spieler.global_position.x,spiel.spieler.global_position.z)
			for e in B.rudel.duplicate():B._rudel_weg(e)
			B._rudel_neu("hoellenhunde",mp,"hoellenhunde");B._rudel_neu("elbewoelfe",mp,"hoellenhunde")
			print("BIKER rudel=",B.rudel.size())
			ui_schritt=2;t=0;return
		if ui_schritt==2:
			if t<3.0:return
			if B.rudel.size()>0:
				var L=B.rudel[0].leit
				_cam_b=Camera3D.new();spiel.add_child(_cam_b);_cam_b.fov=60
				var fw=L.global_transform.basis.z
				_cam_b.global_position=L.global_position+Vector3(0,3.0,0)+fw*9.0+L.global_transform.basis.x*4.0
				_cam_b.look_at(L.global_position-fw*4.0+Vector3(0,1,0));_cam_b.current=true
				shot("biker_rudel");_cam_b.current=false;spiel.kam.cam.current=true
				print("BIKER rudel0 club=",B.rudel[0].club," folger=",B.rudel[0].folger.size())
			# Krieg erzwingen: zweites Rudel 28 m neben das erste setzen
			if B.rudel.size()>=2:
				var e1=B.rudel[0];var e2=B.rudel[1]
				var basis=e1.leit.global_position
				for k in ([e2.leit]+e2.folger).size():
					var b=([e2.leit]+e2.folger)[k];b.global_position=basis+Vector3(28,0.5,k*2.5)
				e2.leit.global_position=basis+Vector3(28,0.5,0)
				B._absteigen(e1,e2.club);B._absteigen(e2,e1.club)
				var v=e1.leit.global_position-spiel.spieler.global_position
				spiel.spieler.global_position=basis+Vector3(14,0.3,-18)
				var v2=basis+Vector3(14,0,0)-spiel.spieler.global_position;spiel.kam.yaw=atan2(v2.x,v2.z)+PI;spiel.kam.pitch=-12.0
			ui_schritt=3;t=0;_n=0;return
		if t<1.5:return
		t=0;_n+=1
		spiel.kampf.hp=100.0
		var lebend={}
		for g in spiel.kampf.gegner:
			if is_instance_valid(g):lebend[g.fraktion+("_tot" if g.tot else "")]=lebend.get(g.fraktion+("_tot" if g.tot else ""),0)+1
		print("BIKER krieg t=",_n," ",lebend)
		if _n in [1,3,6]:shot("biker_krieg_%d"%_n)
		if _n>=8:get_tree().quit()
		return
	if spiel.test_modus=="crash":
		if ui_schritt==0:
			if t<3.0:return
			var S=spiel.welt.S;var best=null
			for r in S.roads:
				if r.typ!="strasse" or r.P.size()<40:continue
				var p0=r.P[10];var p1=r.P[30]
				if p0.distance_to(Vector2(-262,1040))<500 and (r.T[10].dot(r.T[30]))>0.98:best=r;break
			var r=best;var i=10
			var t2:Vector2=r.T[i];var p=r.P[i];var h=r.h[i]
			var fw=Vector3(t2.x,0,t2.y)
			var c=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c);c.setup("c_e30_silber")
			c.global_transform=Transform3D(Basis.looking_at(-fw,Vector3.UP),Vector3(p.x,h+0.7,p.y))
			spiel.geparkt.append(c);spiel.einsteigen(c)
			var hin=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(hin);hin.setup("c_lkw_weiss")
			var q=p+t2*45.0
			hin.global_transform=Transform3D(Basis.looking_at(-Vector3(-t2.y,0,t2.x),Vector3.UP),Vector3(q.x,h+0.9,q.y));hin.mass=20000.0
			spiel.geparkt.append(hin)
			c.linear_velocity=fw*24.0
			set_meta("auto",c);set_meta("fw",fw)
			ui_schritt=1;t=0;_n=0;return
		var c=get_meta("auto")
		if ui_schritt==1:
			if t<0.35:return
			t=0;_n+=1
			print("CRASH t=",_n," kmh=",snapped(c.kmh(),0.1)," hp=",snapped(c.hp,1))
			if _n<6:c.linear_velocity=get_meta("fw")*24.0 if c.kmh()>40.0 else c.linear_velocity
			if _n==9:
				_cam_b=Camera3D.new();spiel.add_child(_cam_b);_cam_b.fov=50
				var fw=get_meta("fw");var quer=Vector3(-fw.z,0,fw.x)
				_cam_b.global_position=c.global_position+Vector3(0,2.6,0)-fw*3.0+quer*5.5
				_cam_b.look_at(c.global_position+Vector3(0,0.6,0));_cam_b.current=true;spiel.ui.visible=false
			if _n==11:get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/crash_1.png")
			if _n==12:
				c.aufprall(18.0,c.global_transform.basis.x,null)   # zweiter Stoß von der Seite
			if _n==14:get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/crash_2.png")
			if _n==15:c.treffer(900.0,null,c.global_position)
			if _n==19:get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/crash_3.png")
			if _n>=24:get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/crash_4.png");get_tree().quit()
		return
	if spiel.test_modus=="rechts":
		# Prüft, ob KI-Autos rechts ihrer Fahrtrichtung fahren
		if t<12.0:return
		var S=spiel.welt.S;var rechts=0;var links=0
		for c in spiel.verkehr:
			if not is_instance_valid(c) or c.modus!="ki":continue
			var a=S.at(c.ki_road,clamp(c.ki_s,0.0,S.length(c.ki_road)))
			var mitte:Vector2=a[0];var fw=c.global_transform.basis.z;var rv=Vector2(-fw.z,fw.x)   # rechts = (-fz, fx)
			var off=Vector2(c.global_position.x,c.global_position.z)-mitte
			if off.dot(rv)>0.1:rechts+=1
			elif off.dot(rv)<-0.1:links+=1
		print("RECHTSVERKEHR rechts=",rechts," links=",links)
		get_tree().quit();return
	if spiel.test_modus=="tuer":
		# Einsteige-Ablauf: Verkehrsauto neben dem Spieler anhalten, entern, Bilderserie von der Seite
		if ui_schritt==0:
			if t<3.0:return
			var p=Vector2(-262,1040)
			var hit=spiel.kampf._ray(Vector3(p.x,400,p.y),Vector3(p.x,-50,p.y),[])
			var h=hit.position.y
			var c=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c);c.setup("c_wartburg_beige" if ResourceLoader.exists("res://scripts/comic/comic_autos.gd") else "small_car")
			c.global_transform=Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(p.x,h+0.8,p.y))
			spiel.verkehr.append(c);c.modus="geparkt"
			spiel.spieler.global_position=Vector3(p.x,h+0.3,p.y)+c.global_transform.basis.x*(-5.0)+c.global_transform.basis.z*2.0
			_cam_b=Camera3D.new();spiel.add_child(_cam_b);_cam_b.fov=55
			_cam_b.global_position=Vector3(p.x,h+2.6,p.y)+c.global_transform.basis.x*(-7.5)+c.global_transform.basis.z*(-5.5)
			_cam_b.look_at(Vector3(p.x,h+1.0,p.y)+c.global_transform.basis.x*(-1.2),Vector3.UP);_cam_b.current=true;spiel.ui.visible=false
			set_meta("auto",c);ui_schritt=1;t=0;return
		if ui_schritt==1:
			if t<1.5:return
			spiel.entern(get_meta("auto"));ui_schritt=2;t=0;_n=0;return
		if t<0.22:return
		t=0
		if _n<14:
			get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/tuer_%02d.png"%_n);_n+=1;return
		if ui_schritt==2:
			print("TUER drin auto=",spiel.auto!=null);spiel.aussteigen();ui_schritt=3;_n=20;return
		if _n<26:
			get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/tuer_%02d.png"%_n);_n+=1;return
		get_tree().quit();return
	if spiel.test_modus=="fahndung":
		# Fahndungsstufe 5 im Ghetto: Hubschrauber, Abseilen, Panzer
		if ui_schritt==0:
			if t<3.0:return
			var p=Vector2(-262,1040)
			var hit=spiel.kampf._ray(Vector3(p.x,400,p.y),Vector3(p.x,-50,p.y),[])
			spiel.spieler.global_position=Vector3(p.x,hit.position.y+0.3,p.y)
			spiel.kampf.sterne=5.0;spiel.kampf.such_mitte=spiel.spieler.global_position
			if spiel._arg("--nacht")!="":spiel.zeit=22.5*60.0
			ui_schritt=1;t=0;return
		spiel.kampf.hp=100.0
		if t<2.0:return
		t=0;_n+=1
		var K=spiel.kampf
		print("FAHNDUNG t=",_n*2," helis=",K.helis.size()," panzer=",K.panzer.size()," gegner=",K.gegner.size()," sterne=",K.sterne)
		for h in K.helis:if is_instance_valid(h):print("  heli armee=",h.armee," pos=",h.global_position.snapped(Vector3.ONE)," abgesetzt=",h._abgesetzt)
		for z in K.panzer:if is_instance_valid(z):print("  panzer pos=",z.global_position.snapped(Vector3.ONE)," dist=",snapped(z.global_position.distance_to(spiel.spieler.global_position),1))
		# Kamera auf das interessanteste Ziel
		var ziel=null
		for h in K.helis:if is_instance_valid(h) and h.armee:ziel=h
		if _n%3==2 and K.panzer.size()>0:ziel=K.panzer[0]
		if ziel==null and K.helis.size()>0:ziel=K.helis[0]
		if ziel:
			var v=ziel.global_position-spiel.spieler.global_position
			spiel.kam.yaw=atan2(v.x,v.z)+PI;spiel.kam.pitch=clamp(rad_to_deg(atan2(v.y,Vector2(v.x,v.z).length())),-30,40)
		if _n>2:shot("fahndung_%02d"%_n)
		if _n>=24:get_tree().quit()
		return
	if spiel.test_modus=="bilder":
		# Galerie: je Ort eine Straßenansicht (Augenhöhe, ohne HUD) und eine Übersicht aus der Höhe
		var O=[["innenstadt",Vector2(-120,560),Vector2(-60,560)],["ghetto",Vector2(-262,1040),Vector2(-180,1040)],["ghetto_west",Vector2(-560,1150),Vector2(-480,1100)],["suedstadt",Vector2(250,1560),Vector2(330,1560)],
			["docks",Vector2(500,2090),Vector2(600,2090)],["industrie",Vector2(900,640),Vector2(980,640)],["hafen",Vector2(1500,820),Vector2(1580,820)],["strand",Vector2(-2100,700),Vector2(-2100,800)],
			["flughafen",Vector2(-2000,1925),Vector2(-2000,1860)],["nordstadt",Vector2(496,-168),Vector2(543,-160)],["wohnviertel",Vector2(-1083,-504),Vector2(-1114,-509)],["huegel",Vector2(58,-2608),Vector2(76,-2652)],
			["knast",Vector2(1700,-5050),Vector2(1900,-5050)],["militaer",Vector2(-2600,-5250),Vector2(-2600,-5450)],["wuestenflug",Vector2(480,-5265),Vector2(646,-5263)],["staubwinkel",Vector2(1749,-5950),Vector2(1797,-5954)],
			["farmland",Vector2(1939,-7710),Vector2(1985,-7696)],["nordbucht",Vector2(-119,-9032),Vector2(-123,-9080)]]
		if ui_schritt==0 and _n==0:
			_n=1
			var nur=spiel._arg("--nur")
			if nur!="":O=O.filter(func(e):return e[0] in nur.split(","))
			# Wachen und belebte Orte dazu
			for d in spiel.welt.DIENSTE:
				var vor=Vector2(sin(d.yaw),cos(d.yaw))
				if nur=="" or "dienste" in nur:O.append(["dienst_%s_%d"%[d.art,int(d.p.x)],d.p+vor*15.0+Vector2(vor.y,-vor.x)*6.0,d.p-vor*14.0])
			if nur=="" or "belebt" in nur:
				O.append(["knasthof",Vector2(2000,-4990),Vector2(2000,-5040)]);O.append(["hafenarbeiter",Vector2(520,2110),Vector2(500,2090)])
			set_meta("O",O)
		if has_meta("O"):O=get_meta("O")
		if t<(6.0 if ui_schritt%2==0 else 1.5):return
		t=0
		if _cam_b==null:
			_cam_b=Camera3D.new();_cam_b.far=5000;_cam_b.fov=62;spiel.add_child(_cam_b)
			spiel.ui.visible=false;spiel.zeit=11.0*60.0;spiel.st.e.sichtweite=2;spiel.st.e.schatten=true;spiel.einstellungen_anwenden()
		if ui_schritt>0:
			var vorher=O[(ui_schritt-1)/2]
			var img=get_viewport().get_texture().get_image();img.save_png("/home/claude/shots_godot/bild_%s_%d.png"%[vorher[0],(ui_schritt-1)%2])
		if ui_schritt>=O.size()*2:get_tree().quit();return
		var e=O[ui_schritt/2];var p:Vector2=e[1];var z:Vector2=e[2];var d=(z-p).normalized()
		if spiel.welt.has_method("viertel_jetzt"):spiel.welt.viertel_jetzt(p)
		var hit=spiel.kampf._ray(Vector3(p.x,600,p.y),Vector3(p.x,-50,p.y),[])
		var h=hit.position.y if hit else spiel.welt.G.h_at(p.x,p.y)
		var D=Vector3(d.x,0,d.y)
		spiel.spieler.global_position=Vector3(p.x,h+0.3,p.y)-D*8.0;spiel.spieler.velocity=Vector3.ZERO
		spiel.env.fog_enabled=ui_schritt%2==0
		if ui_schritt%2==0:
			_cam_b.global_position=Vector3(p.x,h+1.8,p.y)-D*2.0;_cam_b.look_at(Vector3(p.x,h+3.0,p.y)+D*60.0)
		else:
			var rechts=Vector3(-D.z,0,D.x)
			_cam_b.global_position=Vector3(p.x,h+75,p.y)-D*110.0+rechts*40.0;_cam_b.look_at(Vector3(p.x,h,p.y)+D*120.0)
		_cam_b.current=true
		ui_schritt+=1
		return
	if spiel.test_modus=="rundgang" or spiel.test_modus=="luft":
		var luft=spiel.test_modus=="luft"
		# Rundgang durch die Hauptstadt: an mehreren Straßenpunkten in vier Richtungen fotografieren
		if t<1.2:return
		t=0
		var orte=[Vector2(-120,820),Vector2(-330,700),Vector2(300,1400)]
		var per=14 if luft else 7
		var i=ui_schritt/per;var j=ui_schritt%per
		if luft and j>=1:
			# Prüfrundgang: 4 Blickrichtungen auf Augenhöhe, 2 Luftbilder
			var bl=[[0.0,-8.0,4.2],[PI*0.5,-8.0,4.2],[PI,-8.0,4.2],[PI*1.5,-8.0,4.2],[0.6,-60.0,90.0],[0.6+PI,-35.0,60.0]]
			var k=(j-1)/2
			if k>=bl.size():ui_schritt=(i+1)*14;return
			if (j-1)%2==0:spiel.kam.yaw=bl[k][0];spiel.kam.pitch=bl[k][1];spiel.kam.dist=bl[k][2]
			else:shot("ort%d_%d"%[i,k])
			ui_schritt+=1
			return
		if i>=orte.size():get_tree().quit();return
		if j==0:
			var r=spiel.welt.S.roads;var best=null;var bd=1e9
			for rr in r:
				if not rr.typ in ["strasse","allee","gasse"]:continue
				for k in range(0,rr.P.size(),4):
					var d=rr.P[k].distance_to(orte[i])
					if d<bd:bd=d;best=[rr,k]
			var pp:Vector2=best[0].P[best[1]];var h=best[0].h[best[1]]
			spiel.spieler.global_position=Vector3(pp.x,h+0.6,pp.y);spiel.spieler.velocity=Vector3.ZERO
			spiel.strom.sofort(spiel.spieler.global_position,300.0)
			t=-2.0
		elif j<=4:
			spiel.kam.yaw=j*PI*0.5;spiel.kam.pitch=-8.0
			shot("ort%d_%d"%[i,j])
		elif j==5:spiel.kam.pitch=-55.0;spiel.kam.dist=70.0
		else:shot("ort%d_luft"%i);spiel.kam.dist=4.2;spiel.kam.pitch=-12.0
		ui_schritt+=1
		return
	if spiel.test_modus=="mission":
		if t<1.0:return
		t=0
		var M=spiel.mis
		match ui_schritt:
			0:
				var m=M.spielbare()[0];print("MISSION ",m.titel," typ ",m.typ);M.starten(m)
			1:
				print("  ziel ",M.ziel," auto_m ",M.auto_m!=null);spiel.spieler.global_position=M.auto_m.global_position+Vector3(3,0.5,0)
			2:spiel.einsteigen(M.auto_m);print("  schritt ",M.schritt," text ",spiel.hud.job_text)
			3:M.auto_m.global_position=M.ziel+Vector3(0,0.8,0);M.auto_m.linear_velocity=Vector3.ZERO
			4:print("  nach ziel: aktiv=",M.aktiv!=null," geld=",spiel.geld," erledigt=",M.erledigt)
			5:
				for m in M.spielbare():
					if m.typ=="rennen":print("MISSION ",m.titel);M.starten(m);break
			6:spiel.auto.global_position=M.ziel+Vector3(0,0.8,0);spiel.auto.linear_velocity=Vector3.ZERO
			7,8,9,10,11,12,13,14,15:
				print("  cp ",M.aktiv._cpi if M.aktiv else -1," text ",spiel.hud.job_text)
				if M.aktiv:spiel.auto.global_position=M.ziel+Vector3(0,0.8,0);spiel.auto.linear_velocity=Vector3.ZERO
			16:print("  rennen fertig: aktiv=",M.aktiv!=null," geld=",spiel.geld);get_tree().quit()
		ui_schritt+=1
		return
	if spiel.test_modus=="alles":
		if t<0.6:return
		t=0
		var M=spiel.mis;var K=spiel.kampf;var Wi=spiel.wirt
		var typen=M.KAMPF_TYPEN
		if ui_schritt<typen.size()*3:
			var ti=ui_schritt/3;var ph=ui_schritt%3
			var m=null
			for x in M.spielbare():
				if x.typ==typen[ti]:m=x;break
			if ph==0:print("TEST Mission ",m.typ," ",m.titel);M.starten(m)
			elif ph==1:
				# Schritt 1 erzwingen
				M.schritt=1;M._naechster();print("  feinde ",M.feinde.size()," ziel_auto ",M.ziel_auto!=null)
				for g in M.feinde:
					if is_instance_valid(g):g.treffer(500,spiel.spieler,g.global_position)
			else:print("  aktiv ",M.aktiv!=null," text ",spiel.hud.job_text);M.abbrechen(false)
			ui_schritt+=1;return
		match ui_schritt-typen.size()*3:
			0:spiel.geld=900000;spiel.waffen_menue(false)
			1:spiel.panel_zu();spiel.waffen_menue(true)
			2:spiel.panel_zu();print("TEST Immobilie");Wi.immobilie_menue(Wi.immobilien[1])
			3:
				spiel.panel_zu();Wi.besitz[Wi.immobilien[1].id]=true;Wi.immobilie_menue(Wi.immobilien[1])
			4:spiel.panel_zu();print("TEST Geschäft");Wi.geschaeft_menue(Wi.geschaefte[1])
			5:
				spiel.panel_zu();Wi.besitz["logistik"]=true;Wi.personal["logistik"]={"fahrer":0,"lkw":1,"stapler":2,"mitarbeiter":3,"upgrades":[]};Wi._betrieb_bauen();Wi._abrechnen();Wi.geschaeft_menue(Wi.geschaefte[1])
			6:
				spiel.panel_zu()
				for jk in ["polizei","feuerwehr","rtw","lkw","bus"]:
					var c=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c);c.setup(jk);c.global_position=spiel.spieler.global_position+Vector3(4,1,0)
					spiel.einsteigen(c);Wi.job_umschalten();print("TEST Job ",jk," -> ",Wi.job," ",spiel.hud.job_text);Wi._job(0.1);Wi.job_umschalten();spiel.aussteigen_sofort()
			7:
				var c=spiel.verkehr[0] if spiel.verkehr.size()>0 else null
				if c:c.treffer(2000,spiel.spieler,c.global_position);print("TEST Auto Brand ",c._brand)
				if spiel.passanten.size()>0:spiel.passanten[0].n.visible=true;spiel.passant_treffer(spiel.passanten[0],spiel.spieler)
				K.verbrechen(3.0)
			8,9,10,11,12,13:pass
			14:print("TEST Polizisten ",K.gegner.filter(func(g):return g.fraktion=="polizei").size()," sterne ",K.sterne);K.spieler_treffer(500)
			15,16,17,18,19,20:pass
			21:print("TEST nach Krankenhaus hp ",K.hp," tot ",K.tot);spiel.speichern();spiel.laden();print("TEST ENDE");get_tree().quit()
		ui_schritt+=1
		return
	if spiel.test_modus=="zielen":
		if t<(2.0 if schritt==0 else 1.0):return
		t=0
		var K=spiel.kampf;var sp=spiel.spieler
		match schritt:
			0:
				spiel.admin=true;spiel.admin_gott=true
				var r=null
				for x in spiel.welt.S.roads:
					if x.name=="ew2":r=x
				var ii=int(r.P.size()*0.45);var q:Vector2=r.P[ii];var tt:Vector2=r.T[ii]
				sp.global_position=Vector3(q.x,r.h[ii]+0.5,q.y);sp.reset_physics_interpolation()
				spiel.kam.yaw=atan2(-tt.x,-tt.y);spiel.kam.pitch=-6.0
				var fw=Vector3(tt.x,0,tt.y)
				var rt=Vector3(fw.z,0,-fw.x)
				for i in 3:
					var g=K.spawn(sp.global_position+fw*(9.0+i*3.0)+rt*(i-1)*3.0+Vector3(0,0.5,0),"gang","faust")
					g.set_physics_process(false)
				K.gib_waffe("ak47",4);spiel.st.t_zielen=true;spiel.kam.yaw+=0.3
			3:shot("zielerfassung")
			4:K.gib_waffe("jagdgewehr",2);spiel.st.t_zielen=false
			5:spiel.st.t_zielen=true
			7:shot("zielfernrohr")
			8:get_tree().quit()
		schritt+=1
		return
	if spiel.test_modus=="v28":
		if t<(2.0 if schritt==0 else 1.2):return
		t=0
		var sp=spiel.spieler;var K=spiel.kampf
		match schritt:
			0:
				spiel.admin=true;spiel.admin_geld=true
				# Skyline-Typ vor die Werkstatt stellen, Spieler daneben
				var w=spiel._shop("werkstatt");var fw=Vector3(sin(w.yaw),0,cos(w.yaw))
				var z=Vector3(w.c.x,w.y,w.c.y)+fw*(w.d*0.5-6.0)
				var c=spiel.AUTO.new();spiel.add_child(c);c.setup("c_jdm_blau")
				c.global_transform=Transform3D(Basis(Vector3.UP,w.yaw+PI*0.5),z+Vector3(0,0.4,0)+fw.cross(Vector3.UP)*9.0);c.reset_physics_interpolation();c.parken();spiel.geparkt.append(c);set_meta("testauto",c)
				sp.global_position=c.global_position+c.global_transform.basis.x*3.5+Vector3(0,0.3,0);sp.reset_physics_interpolation()
				print("TEST auto ",c.global_position," spieler ",sp.global_position)
			1:print("TEST vor einsteigen auto ",get_meta("testauto").global_position);spiel.entern(get_meta("testauto"))
			3:
				var c=spiel.auto;print("TEST nach einsteigen auto ",c.global_position if c else null," kipp ",c.global_transform.basis.y if c else null)
				var w=spiel._shop("werkstatt");var fw=Vector3(sin(w.yaw),0,cos(w.yaw))
				var z=Vector3(w.c.x,w.y,w.c.y)+fw*(w.d*0.5-6.0)
				c.global_transform=Transform3D(Basis(Vector3.UP,w.yaw+PI*0.5),z+Vector3(0,0.6,0));c.linear_velocity=Vector3.ZERO;c.reset_physics_interpolation()
			5:print("TEST panel ",spiel.panel!=null);shot("werkstatt_menue")
			6:
				var c=spiel.auto
				spiel._comic_umbauen({"tief":0.06,"breit":0.06,"lippe":true,"schweller":true,"diffusor":true,"spoiler":"gt","felge":"kreuz","felgenfarbe":Color(0.95,0.78,0.25),"neon":Color(0.2,0.6,1.0)},Color(0.8,0.12,0.12),0)
				spiel.panel_zu();spiel.kam.yaw+=2.4;spiel.kam.pitch=-12.0
			8:shot("getunt")
			9:spiel.aussteigen_sofort();print("TEST ausgestiegen ",sp.global_position)
			10:K.gib_waffe("ak47",3);K.magazin["ak47"]=5;K.nachladen()
			11:shot("nachladen")
			12:spiel.karte_oeffnen(false)
			13:shot("karte")
			14:get_tree().quit()
		schritt+=1
		return
	if spiel.test_modus=="rad":
		if t<(2.0 if schritt==0 else 0.4):return
		t=0
		match schritt:
			0:spiel.admin=true;spiel.kampf.waffen_rad()
			1:shot("waffenrad")
			2:spiel.kampf.rad._gui_input(_tipp(spiel.kampf.rad,4));spiel.kampf.rad._gui_input(_tipp(spiel.kampf.rad,4))
			3:shot("waffenrad_gewehr")
			4:get_tree().quit()
		schritt+=1
		return
	if spiel.test_modus=="ghetto":
		_ghetto_test(dt);return
	if spiel.test_modus=="werkstatt":
		_werkstatt_test(dt);return
	if spiel.test_modus=="comic":
		# Comic-Welt: Start, Laufen, nächstes geparktes Auto nehmen, fahren, aussteigen, Luftbilder
		if schritt==3 or schritt==4:st.t_gas=1.0;st.t_move=Vector2.ZERO
		elif schritt==1 or schritt==6:st.t_move=Vector2(0,-1) if schritt==1 else Vector2(0,1)
		else:st.t_gas=0.0;st.t_move=Vector2.ZERO
		if t<[2.0,3.0,1.0,3.0,3.0,2.5,3.0,1.0,1.0][min(schritt,8)]:return
		t=0
		match schritt:
			0:shot("start")
			1:shot("gelaufen")
			2:
				var best=null;var bd=1e9
				for c in spiel.geparkt:
					var d=c.global_position.distance_to(spiel.spieler.global_position)
					if d<bd:bd=d;best=c
				print("TEST naechstes Auto ",best.kind if best else "keins"," ",bd)
				if best:spiel.einsteigen(best)
				shot("eingestiegen")
			3:shot("fahrt1")
			4:shot("fahrt2")
			5:spiel.aussteigen_sofort();shot("ausgestiegen")
			6:print("TEST figur ",spiel.spieler.figur.global_rotation.y," vel ",spiel.spieler.velocity);shot("nach_aussteigen_gelaufen")
			7:pass
			8:get_tree().quit()
		schritt+=1
		return
	if spiel.test_modus=="ost" or spiel.test_modus=="sued" or spiel.test_modus=="nord":
		var P=[["rand",Vector2(-300,812),Vector2(-300,880)],["rand2",Vector2(100,812),Vector2(100,900)],["ghetto",Vector2(-262,1040),Vector2(-180,1040)],["ghetto2",Vector2(-560,1150),Vector2(-480,1100)],["suedstadt",Vector2(250,1560),Vector2(330,1560)],["docks",Vector2(500,2090),Vector2(600,2090)],
			["kai",Vector2(700,2200),Vector2(760,2300)],["industrie",Vector2(900,640),Vector2(980,640)],["hafen",Vector2(1500,820),Vector2(1580,820)],["strand",Vector2(-2100,700),Vector2(-2100,800)],["flughafen",Vector2(-2000,1925),Vector2(-2000,1860)]] if spiel.test_modus=="sued" else [["bruecke",Vector2(1900,-158),Vector2(2400,-140)],["kowloon",Vector2(2760,-385),Vector2(2760,-560)],["lindstadt",Vector2(2700,600),Vector2(2700,450)],
			["dorf",Vector2(3600,495),Vector2(3700,480)],["canyon",Vector2(3990,-330),Vector2(4180,-470)],["moewenbach",Vector2(1110,-490),Vector2(1110,-560)],["nacht",Vector2(250,-350),Vector2(250,-500)]]
		if spiel.test_modus=="nord":P=[["n_stadt",Vector2(496,-168),Vector2(543,-160)],["n_wohn",Vector2(-1083,-504),Vector2(-1114,-509)],["n_villa",Vector2(-701,-1444),Vector2(-695,-1400)],
			["n_huegel",Vector2(58,-2608),Vector2(76,-2652)],["n_knast",Vector2(1700,-5050),Vector2(1900,-5050)],["n_militaer",Vector2(-2600,-5300),Vector2(-2600,-5450)],["n_wflug",Vector2(500,-5200),Vector2(646,-5263)],
			["n_redneck",Vector2(1749,-5950),Vector2(1797,-5954)],["n_farm",Vector2(1939,-7710),Vector2(1985,-7696)],["n_bucht",Vector2(-119,-9032),Vector2(-123,-9080)]]
		if t<2.5:return
		t=0
		if ui_schritt==0 and spiel._arg("--ab")!="":ui_schritt=int(spiel._arg("--ab"));_ab=ui_schritt
		if ui_schritt>_ab:shot(P[ui_schritt-1][0])
		if ui_schritt>=P.size():get_tree().quit();return
		var e=P[ui_schritt];var p:Vector2=e[1];var z:Vector2=e[2]
		if spiel.welt.has_method("viertel_jetzt"):spiel.welt.viertel_jetzt(p)
		var h=spiel.welt.G.h_at(p.x,p.y)
		var hit=spiel.kampf._ray(Vector3(p.x,400,p.y),Vector3(p.x,-50,p.y),[])
		if hit:h=hit.position.y
		if spiel.test_modus=="nord" and spiel._arg("--aus")!="":
			for c in spiel.welt.get_children():
				if str(c.name).begins_with(spiel._arg("--aus")):c.visible=false;print("AUS ",c.name)
		if spiel.test_modus=="nord":
			print("NORDDBG ",e[0]," h_at ",spiel.welt.G.h_at(p.x,p.y)," hit ",(hit.position.y if hit else -999)," coll ",(hit.collider.name if hit else ""))
			for g in spiel.welt.find_children("Gelaende_*","MeshInstance3D",true,false):
				var a:AABB=g.global_transform*g.get_aabb()
				if spiel._arg("--glfix")!="":
					if g.name.ends_with("_1"):g.visibility_range_end=0.0
					else:g.visible=false
				if a.has_point(Vector3(p.x,a.get_center().y,p.y)):print("   GL ",g.name," vis ",g.is_visible_in_tree()," ",a," vr ",g.visibility_range_begin,"-",g.visibility_range_end)
		spiel.spieler.global_position=Vector3(p.x,h+0.3,p.y);spiel.spieler.velocity=Vector3.ZERO
		var v=z-p;spiel.kam.yaw=atan2(v.x,v.y)+PI;spiel.kam.pitch=-8.0
		spiel.zeit=22.5*60.0 if e[0]=="nacht" else 11.0*60.0
		ui_schritt+=1
		return
	if spiel.test_modus=="kampf":
		var K=spiel.kampf
		if K.gegner.size()>0 and is_instance_valid(K.gegner[0]):
			var g=K.gegner[0];var v=g.global_position-spiel.spieler.global_position
			spiel.kam.yaw=atan2(v.x,v.z)+PI;spiel.kam.pitch=-4.0
		if t<1.5:return
		t=0
		match ui_schritt:
			0:
				K.gib_waffe("pistole",3);K.gib_waffe("ar15",3)
				var sp=spiel.spieler;var fw=sp.figur.global_transform.basis.z
				K.gruppe(sp.global_position+fw*16.0,3,"kobras",["pistole","mp5","ak47"],{"mission":true})
				shot("waffe_lauf")
			1:st.t_zielen=true;shot("zielen")
			2:st.t_feuer=true
			3:shot("schiessen");print("  gegner hp ",K.gegner.map(func(g):return g.hp)," spieler ",K.hp)
			4:st.t_feuer=false;K.waehle("pistole")
			5:shot("pistole")
			6:st.t_zielen=false;K.waehle("katana") if K.waffen.has("katana") else K.gib_waffe("katana",0)
			7:shot("katana")
			8:K.waehle("ar15");st.t_feuer=true
			9,10:pass
			11:st.t_feuer=false;shot("danach");print("  gegner tot ",K.gegner.map(func(g):return g.tot)," spieler ",K.hp," sterne ",K.sterne);get_tree().quit()
		ui_schritt+=1
		return
	if spiel.test_modus=="ui":
		if t<1.5:return
		t=0
		match ui_schritt:
			0:spiel.kleider_menue()
			1:shot("ui_kleider");spiel.panel_zu();spiel.karte_oeffnen()
			2:shot("ui_karte");spiel.panel_zu();spiel.pausenmenue()
			3:shot("ui_pause");spiel.einstellungen_menue()
			4:shot("ui_einst");spiel.hilfe()
			5:shot("ui_hilfe");spiel.panel_zu()
			6:get_tree().quit()
		ui_schritt+=1
		return
	match schritt:
		0:
			if t<0.1:
				var h=spiel._shop("zuhause");spiel.kam.yaw=h.yaw-PI*0.5
			if t>4.0:shot("start");schritt=1;t=0
		1:
			st.t_move=Vector2(0,1.0)
			if t>3.0:st.t_move=Vector2.ZERO;shot("gelaufen");schritt=2;t=0
		2:
			# Auto direkt neben den Spieler stellen und einsteigen
			var c=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c);c.setup("audi_rs7")
			var p=spiel.spieler.global_position
			var r=spiel.welt.S.roads_by_name("Grove");var best=0.0;var bd=1e9
			for i in r.P.size():
				var d=r.P[i].distance_to(Vector2(p.x,p.z))
				if d<bd:bd=d;best=i*4.0
			var a=spiel.welt.S.at(r,best);var tv:Vector2=a[2]
			c.global_position=Vector3(a[0].x,a[1]+0.5,a[0].y)-Vector3(-tv.y,0,tv.x)*2.5;c.rotation.y=atan2(tv.x,tv.y)
			spiel.spieler.global_position=c.global_position+Vector3(-tv.y,0,tv.x)*-3.0+Vector3(0,0.3,0)
			spiel.kam.yaw=atan2(tv.x,tv.y)+PI
			spiel.geparkt.append(c);schritt=3;t=0
		3:
			if t>1.5:
				shot("auto_daneben");print("  DBG geparkt ",spiel.geparkt.size()," letzter ",spiel.geparkt[-1].kind," ",spiel.geparkt[-1].global_position)
				spiel.entern(spiel.geparkt[-1]);schritt=35;t=0
		35:
			if spiel.auto!=null:print("  DBG entern ok nach ",t);schritt=4;t=0
			elif t>4.0:print("  DBG entern FEHLER");schritt=4;t=0
		4:
			st.t_gas=1.0
			if t>1.0:st.t_move=Vector2(0.05,0)
			if t>5.0:
				var c=spiel.auto;print("  DBG kind ",c.kind," pos ",c.global_position," wheels ",c.wheels.map(func(w):return [w.is_in_contact(),snapped(w.get_rpm(),1)])," ef ",c.engine_force," brake ",c.brake," modus ",c.modus)
				shot("fahren");schritt=5;t=0
		5:
			st.t_gas=1.0;st.t_move=Vector2(-0.05,0)
			if t>4.0:st.t_gas=0.0;st.t_brake=1.0;st.t_move=Vector2.ZERO;shot("fahren2");schritt=6;t=0
		6:
			if t>3.0:st.t_brake=0.0;shot("gebremst");spiel.aussteigen();schritt=7;t=0
		7:
			if t>1.5:shot("ausgestiegen");spiel.kleider_menue();schritt=8;t=0
		8:
			if t>2.0:shot("kleiderladen");spiel.panel_zu();spiel.karte_oeffnen();schritt=9;t=0
		9:
			if t>1.0:shot("karte");spiel.panel_zu();spiel.einstellungen_menue();schritt=10;t=0
		10:
			if t>1.0:shot("einstellungen");spiel.panel_zu();schritt=11;t=0
		11:
			# Verkehr ansehen
			spiel.kam.pitch=-25.0;spiel.kam.dist=14.0
			if t>3.0:shot("verkehr");get_tree().quit()

func _tipp(rad,fach:int):
	var e=InputEventScreenTouch.new();e.pressed=true
	var a=(fach+0.5)*TAU/8.0
	e.position=rad.size*0.5+Vector2(sin(a),-cos(a))*(rad.R+rad.R_innen)*0.5
	return e

# ---------- Ghetto-Prüfung: Boden unter allen Straßenpunkten, KI-Autos fahren alle Ghetto-Straßen ----------
var gt_autos:=[]
var gt_phase:=0
func _gh_rect()->Rect2:
	# Testgebiet in der unteren Kartenhälfte: --ort=x,z (Welt), sonst Ghetto
	var a=spiel._arg("--ort");var c=Vector2(-250,1000)
	if a!="":var t=a.split(",");c=Vector2(float(t[0]),float(t[1]))
	return Rect2(c-Vector2(220,220),Vector2(440,440))
func _ghetto_test(dt):
	var W=spiel.welt;var S=W.S;var R=_gh_rect()
	match gt_phase:
		0:
			if t<1.0:return
			var a=Vector3(R.get_center().x,8.0,R.get_center().y)
			spiel.spieler.global_position=a+Vector3(0,1,0)
			W.viertel_jetzt(Vector2(a.x,a.z))
			gt_phase=1;t=0
		1:
			if t<2.0:return
			shot("ghetto_leer")
			# Boden-Prüfung: jeder Straßenpunkt muss auf Fahrbahnhöhe Boden haben
			var raum=spiel.get_world_3d().direct_space_state;var fehl=0;var n=0;var maxd=0.0
			for r in S.roads:
				for i in r.P.size():
					var q:Vector2=r.P[i]
					if not R.grow(30).has_point(q):continue
					for lat in [0.0,r.w*0.7,-r.w*0.7]:
						var nn=Vector2(-r.T[i].y,r.T[i].x);var p=q+nn*lat
						var hit=raum.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,r.h[i]+3.0,p.y),Vector3(p.x,r.h[i]-3.0,p.y),1))
						n+=1
						if not hit:fehl+=1;print("BODEN FEHLT ",r.name," ",p)
						else:
							var d=abs(hit.position.y-r.h[i]);maxd=max(maxd,d)
							if d>0.25:fehl+=1;print("BODEN HOEHE ",r.name," ",p," soll ",r.h[i]," ist ",hit.position.y)
			print("GHETTO BODEN Punkte ",n," Fehler ",fehl," max. Abweichung ",snapped(maxd,0.01))
			# KI-Autos auf alle Ghetto-Straßen (inkl. Zubringer)
			var AUTO=load("res://scripts/spiel/fahrzeug.gd")
			for r in S.roads:
				var mitte:Vector2=r.P[r.P.size()/2]
				if not R.grow(10).has_point(mitte) or not r.get("sued",false):continue
				var L=S.length(r)
				for f in [0.2,0.6]:
					for dir in [1,-1]:
						var c=AUTO.new();spiel.add_child(c);c.setup(["c_wartburg_beige","c_muscle_orange","c_e30_gruen","c_kompakt_rot"][gt_autos.size()%4])
						c.als_ki(r,L*f,dir,c._lane(r),S);spiel.verkehr.append(c)
						gt_autos.append({"c":c,"r":r.name,"start":c.global_position,"weg":0.0,"alt":c.global_position,"steh":0.0,"maxsteh":0.0,"fall":false})
			print("GHETTO KI-Autos ",gt_autos.size())
			gt_phase=2;t=0
		2:
			for e in gt_autos:
				var c=e.c
				if not is_instance_valid(c) or not spiel.verkehr.has(c):continue
				var p=c.global_position;e.weg+=p.distance_to(e.alt);var v=p.distance_to(e.alt)/max(dt,0.001);e.alt=p
				if v<0.5:e.steh+=dt;e.maxsteh=max(e.maxsteh,e.steh)
				else:e.steh=0.0
				var g=W.G.h_at(p.x,p.z)
				if p.y<g-0.5 or p.y<0.0:e.fall=true
			if fmod(t,10.0)<dt:shot("ghetto_%d"%int(t))
			if t<45.0:return
			var fall=0;var steh=0;var wenig=0
			var weg_=0
			for e in gt_autos:
				if not is_instance_valid(e.c):weg_+=1;continue
				if e.fall:fall+=1;print("FAELLT ",e.r," ",e.c.global_position if is_instance_valid(e.c) else "")
				if e.maxsteh>12.0:steh+=1;print("STEHT ",e.r," ",snapped(e.maxsteh,0.1),"s bei ",e.c.global_position if is_instance_valid(e.c) else "")
				if e.weg<60.0:wenig+=1;print("WENIG WEG ",e.r," ",snapped(e.weg,0.1),"m")
			print("GHETTO KI Ergebnis: Autos ",gt_autos.size()," (entfernt ",weg_,")"," gefallen ",fall," lange gestanden ",steh," <60m gefahren ",wenig)
			get_tree().quit()

# Werkstatt: vor das Tor, reinfahren, Menü, Fertig, rausfahren
func _werkstatt_test(dt):
	var g=spiel._garage
	if g==null:print("WERKSTATT fehlt");get_tree().quit();return
	var st=spiel.st
	if schritt==0:
		if t<2.0:return
		var gb:Transform3D=g.global_transform
		var vor=gb*Vector3(0,0,float(spiel._arg("--vor")) if spiel._arg("--vor")!="" else 14.0)
		spiel.welt.viertel_jetzt(Vector2(vor.x,vor.z))
		var c=spiel.AUTO.new();spiel.add_child(c);c.setup("c_muscle_orange")
		c.global_transform=Transform3D(gb.basis*Basis(Vector3.UP,PI),vor+Vector3(0,1.0,0));spiel.einsteigen(c)
		t=0;schritt=1;return
	if schritt==1:
		if t<2.0:return
		print("  START y ",spiel.auto.global_position.y)
		shot("werkstatt_vorn");t=0;schritt=2;return
	if schritt==2:
		st.t_gas=0.45
		if t>1.5 and t<1.6:shot("werkstatt_tor")
		if int(t*2)!=int((t-dt)*2):print("  FAHRT ",spiel.auto.global_position," kmh ",snapped(spiel.auto.kmh(),0.1))
		if g.aktiv or t>12.0:st.t_gas=0.0;print("WERKSTATT drin ",g.aktiv);t=0;schritt=3
		return
	if schritt==3:
		if t<4.0:return
		shot("werkstatt_menue");print("WERKSTATT panel ",spiel.panel!=null);t=0;schritt=4;return
	if schritt==4:
		spiel.panel_zu();t=0;schritt=5;return
	if schritt==5:
		if t<3.5:return
		shot("werkstatt_gedreht");print("WERKSTATT aktiv ",g.aktiv," frozen ",spiel.auto.freeze);t=0;schritt=6;return
	if schritt==6:
		if t<0.05:
			var a=spiel.auto;var sp=a.get_world_3d().direct_space_state
			for off in [Vector3.ZERO,Vector3(1,0,1.5),Vector3(-1,0,-1.5)]:
				var q=PhysicsRayQueryParameters3D.create(a.global_position+off+Vector3(0,3,0),a.global_position+off-Vector3(0,3,0));q.exclude=[a.get_rid()];q.collision_mask=a.collision_mask
				var h=sp.intersect_ray(q);print("  STRAHL ",off," ",h.get("position")," ",h.get("collider"))
			for w in a.get_children():
				if w is VehicleWheel3D:print("  RAD ",w.position," r ",w.wheel_radius," rest ",w.wheel_rest_length," travel ",w.suspension_travel," kontakt ",w.get_contact_body()," ",w.get_contact_point() if w.has_method("get_contact_point") else "")
		st.t_gas=0.6
		if int(t*4)!=int((t-dt)*4):
			var a=spiel.auto;var wk=[]
			for w in a.get_children():
				if w is VehicleWheel3D:wk.append([w.is_in_contact(),snapped(w.get_rpm(),1),w.use_as_traction,w.engine_force])
			print("  RAEDER det ",snapped(a.global_transform.basis.determinant(),0.01)," scale ",a.global_transform.basis.get_scale()," z ",a.global_transform.basis.z," vis ",a.visual.global_transform.basis.get_scale() if a.visual else ""," pos ",a.global_position," v ",a.linear_velocity," fz ",a.freeze," fm ",a.freeze_mode," mode ",PhysicsServer3D.body_get_mode(a.get_rid())," lock ",a.axis_lock_linear_x," sl ",a.sleeping," cs ",a.can_sleep," mass ",a.mass," cb ",a.collision_layer,"/",a.collision_mask)
		if t>3.0:st.t_gas=0.0;shot("werkstatt_raus");print("WERKSTATT draussen ",g._lokal(spiel.auto.global_position));get_tree().quit()
