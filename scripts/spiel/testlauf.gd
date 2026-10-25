extends Node
# Automatischer Spieltest: simuliert Eingaben und speichert Bildschirmfotos (nur am PC mit -- --test).
var spiel
var t:=0.0
var schritt:=0
var bilder:=0
const OUT:="/home/claude/shots_godot/spiel_"
func shot(name:String):
	var img=get_viewport().get_texture().get_image();img.save_png(OUT+"%02d_%s.png"%[bilder,name]);bilder+=1
	print("TESTBILD ",name," fps=",Engine.get_frames_per_second()," pos=",spiel.spieler.global_position," auto=",spiel.auto!=null," kmh=",spiel.auto.kmh() if spiel.auto else 0)

func _process(dt):
	t+=dt
	var st=spiel.st
	match schritt:
		0:
			if t>4.0:shot("start");schritt=1;t=0
		1:
			st.t_move=Vector2(0,1.0)
			if t>3.0:st.t_move=Vector2.ZERO;shot("gelaufen");schritt=2;t=0
		2:
			# Auto direkt neben den Spieler stellen und einsteigen
			var c=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c);c.setup("audi_rs7")
			var p=spiel.spieler.global_position;var fw=Vector3(sin(spiel.kam.blick_yaw()),0,cos(spiel.kam.blick_yaw()))
			var a=spiel.welt.S
			c.global_position=p+fw*4.0+Vector3(0,0.6,0);c.rotation.y=spiel.kam.blick_yaw()
			spiel.geparkt.append(c);schritt=3;t=0
		3:
			if t>1.5:shot("auto_daneben");spiel.einsteigen(spiel.geparkt[-1]);schritt=4;t=0
		4:
			st.t_gas=1.0
			if t>1.0:st.t_move=Vector2(0.25,0)
			if t>5.0:shot("fahren");schritt=5;t=0
		5:
			st.t_gas=1.0;st.t_move=Vector2(-0.2,0)
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
