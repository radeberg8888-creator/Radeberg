extends Node
# Automatischer Spieltest: simuliert Eingaben und speichert Bildschirmfotos (nur am PC mit -- --test).
var spiel
var t:=0.0
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
	print("LEISTUNG ",name," Aufrufe=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," Dreiecke=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," Objekte=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)," Knoten=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)," Logik_ms=",snapped(Performance.get_monitor(Performance.TIME_PROCESS)*1000,0.1)," Physik_ms=",snapped(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,0.1))
	print("TESTBILD ",name," fps=",Engine.get_frames_per_second()," pos=",spiel.spieler.global_position," auto=",spiel.auto!=null," kmh=",spiel.auto.kmh() if spiel.auto else 0)

var ui_schritt:=0
var _ab:=0
func _process(dt):
	t+=dt
	var st=spiel.st
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
	if spiel.test_modus=="ost":
		var P=[["bruecke",Vector2(1900,-158),Vector2(2400,-140)],["kowloon",Vector2(2760,-385),Vector2(2760,-560)],["lindstadt",Vector2(2700,600),Vector2(2700,450)],
			["dorf",Vector2(3600,495),Vector2(3700,480)],["canyon",Vector2(3990,-330),Vector2(4180,-470)],["moewenbach",Vector2(1110,-490),Vector2(1110,-560)],["nacht",Vector2(250,-350),Vector2(250,-500)]]
		if t<2.5:return
		t=0
		if ui_schritt==0 and spiel._arg("--ab")!="":ui_schritt=int(spiel._arg("--ab"));_ab=ui_schritt
		if ui_schritt>_ab:shot(P[ui_schritt-1][0])
		if ui_schritt>=P.size():get_tree().quit();return
		var e=P[ui_schritt];var p:Vector2=e[1];var z:Vector2=e[2]
		var h=spiel.welt.G.h_at(p.x,p.y)
		var hit=spiel.kampf._ray(Vector3(p.x,400,p.y),Vector3(p.x,-50,p.y),[])
		if hit:h=hit.position.y
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
