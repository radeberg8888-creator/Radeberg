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
	print("TESTBILD ",name," fps=",Engine.get_frames_per_second()," pos=",spiel.spieler.global_position," auto=",spiel.auto!=null," kmh=",spiel.auto.kmh() if spiel.auto else 0)

var ui_schritt:=0
func _process(dt):
	t+=dt
	var st=spiel.st
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
			if t>1.5:shot("auto_daneben");spiel.einsteigen(spiel.geparkt[-1]);schritt=4;t=0
		4:
			st.t_gas=1.0
			if t>1.0:st.t_move=Vector2(0.05,0)
			if t>5.0:shot("fahren");schritt=5;t=0
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
