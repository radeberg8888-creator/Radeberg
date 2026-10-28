extends Node
# Admin-/Testmodus: alles freischalten und jede Mechanik direkt ausprobieren
# (Geld, Gott-Modus, Waffen, Autos herbeirufen, Teleport, Uhrzeit, Fahndung, Missionen, Besitz).
const WD=preload("res://scripts/spiel/waffen_daten.gd")
const VH=preload("res://scripts/vehicles.gd")
const AUTO=preload("res://scripts/spiel/fahrzeug.gd")
var spiel

const ORTE:=[["Zuhause (Ghetto)","zuhause"],["Downtown","downtown"],["Altstadt","altstadt"],["Strandviertel","strand"],["Sonnenhügel (Villen)","sonnenhuegel"],
	["Sternviertel","stern"],["Neu-Kowloon","kowloon"],["Hauptbahnhof","bahnhof"],["Hafen","hafen"],["Flughafen","flugplatz"],["Ostvororte","vorort"],
	["Staubwinkel (Wüste)","staubwinkel"],["Staubsee","see"],["Roter Canyon","canyon"],["Farmland","farm"],["Espenwald","espenwald"],
	["Radeberg-Gipfel","berg"],["Nordbucht","nordbucht"],["Autobahn (Stadtring)","autobahn"],["Oststadt","oststadt"],["Südstadt","suedstadt"],["Docks","docks"],["Militärbasis (Tor)","militaer"],["Stausee","stausee"],["Wüste","wueste"]]

func menue():
	var v=spiel._panel("ADMIN-MODUS")
	var sc=ScrollContainer.new();sc.custom_minimum_size=Vector2(470,520);sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;v.add_child(sc)
	var w=VBoxContainer.new();w.size_flags_horizontal=Control.SIZE_EXPAND_FILL;w.add_theme_constant_override("separation",6);sc.add_child(w)
	_titel(w,"Spieler")
	_schalter(w,"Unendlich Geld",spiel.admin_geld,func(b):
		spiel.admin_geld=b
		if b:spiel.geld=max(spiel.geld,99999999))
	_schalter(w,"Gott-Modus (keinen Schaden)",spiel.admin_gott,func(b):spiel.admin_gott=b)
	_schalter(w,"Polizei ignoriert mich",spiel.admin_keine_polizei,func(b):spiel.admin_keine_polizei=b)
	spiel._btn(w,"Alle Waffen + volle Munition",func():
		for id in WD.REIHE:
			if id!="faust":spiel.kampf.gib_waffe(id,8)
		spiel.kampf.ruestung=100.0;spiel.kampf.hp=100.0;spiel.hud.zeige("Alle Waffen erhalten",2.0))
	spiel._btn(w,"Leben + Weste auffüllen",func():spiel.kampf.hp=100.0;spiel.kampf.ruestung=100.0)
	_titel(w,"Fahndung")
	var hf=HBoxContainer.new();w.add_child(hf)
	for n in 6:
		var b=Button.new();b.text=str(n)+"★";b.custom_minimum_size=Vector2(70,52);hf.add_child(b)
		b.pressed.connect(func():spiel.kampf.sterne=float(n);spiel.kampf.such_mitte=spiel.spieler.global_position;spiel.hud.zeige("Fahndungsstufe %d"%n,1.5))
	_titel(w,"Auto herbeirufen")
	var g=GridContainer.new();g.columns=2;w.add_child(g)
	for k in VH.LIST:
		var b=Button.new();b.text=VH.LIST[k][2];b.custom_minimum_size=Vector2(225,48);b.add_theme_font_size_override("font_size",17);g.add_child(b)
		b.pressed.connect(func():auto_rufen(k))
	_titel(w,"Teleport")
	var g2=GridContainer.new();g2.columns=2;w.add_child(g2)
	for o in ORTE:
		var b=Button.new();b.text=o[0];b.custom_minimum_size=Vector2(225,48);b.add_theme_font_size_override("font_size",17);g2.add_child(b)
		b.pressed.connect(func():teleport_ort(o[1]))
	spiel._btn(w,"Karte öffnen und hinTIPPEN = Teleport",func():spiel.panel_zu();spiel.karte_oeffnen(true))
	_titel(w,"Uhrzeit")
	var hz=HBoxContainer.new();w.add_child(hz)
	for z in [["Morgen",7.0],["Mittag",12.5],["Abend",19.5],["Nacht",23.5]]:
		var b=Button.new();b.text=z[0];b.custom_minimum_size=Vector2(110,50);hz.add_child(b)
		b.pressed.connect(func():spiel.zeit=z[1]*60.0)
	_titel(w,"Welt & Spielstand")
	spiel._btn(w,"Alle Häuser, Garagen und Geschäfte besitzen",func():
		for x in spiel.wirt.immobilien:spiel.wirt.besitz[x.id]=true
		for x in spiel.wirt.geschaefte:
			spiel.wirt.besitz[x.id]=true
			if not spiel.wirt.personal.has(x.id):spiel.wirt.personal[x.id]={"fahrer":3,"lkw":2,"stapler":2,"mitarbeiter":5,"upgrades":[]}
		spiel.wirt._betrieb_bauen();spiel.hud.zeige("Alles gehört dir",2.0))
	spiel._btn(w,"Neuer Tag (Geschäfte rechnen ab)",func():spiel.wirt._abrechnen())
	spiel._btn(w,"Alle Story-Kapitel freischalten",func():
		if spiel.story:spiel.story.alles_frei()
		spiel.hud.zeige("Alle Story-Missionen freigeschaltet",2.0))
	spiel._btn(w,"Mission direkt starten …",spiel.missionen_menue)
	_titel(w,"Tests")
	spiel._btn(w,"Gang-Gruppe vor mir (5 Gegner)",func():
		var sp=spiel.spieler;spiel.kampf.gruppe(sp.global_position+sp.figur.global_transform.basis.z*18.0,5,"kobras",["pistole","mp5","ak47","mossberg","machete"],{"alarm":true});spiel.panel_zu())
	spiel._btn(w,"Explosion vor mir",func():
		var sp=spiel.spieler;spiel.kampf.explosion(sp.global_position+sp.figur.global_transform.basis.z*12.0);spiel.panel_zu())
	spiel._btn(w,"Spraydose + Graffiti testen",func():spiel.kampf.gib_waffe("spraydose",1);spiel.panel_zu())
	spiel._btn(w,"FPS-Anzeige an/aus",func():spiel.st.e.fps=not spiel.st.e.fps)
	spiel._btn(v,"Zurück",spiel.pausenmenue)

func _titel(w:Control,t:String):
	var l=Label.new();l.text=t;l.add_theme_color_override("font_color",Color(0.98,0.82,0.3));l.add_theme_font_size_override("font_size",24);w.add_child(l)

func _schalter(w:Control,t:String,an:bool,f:Callable):
	var c=CheckButton.new();c.text=t;c.button_pressed=an;c.toggled.connect(f);w.add_child(c)

func auto_rufen(k:String):
	var sp=spiel.spieler
	if spiel.auto!=null:spiel.aussteigen_sofort()
	var c=AUTO.new();spiel.add_child(c);c.setup(k)
	var fw=sp.figur.global_transform.basis.z;fw.y=0;fw=fw.normalized()
	var p=sp.global_position+fw*6.0
	c.global_transform=Transform3D(Basis.looking_at(-fw,Vector3.UP),Vector3(p.x,_boden(p)+0.8,p.z))
	spiel.geparkt.append(c);spiel.panel_zu();spiel.hud.zeige(VH.LIST[k][2]+" steht bereit",1.5)

func _boden(p:Vector3)->float:
	return spiel.kampf._boden(p)

func teleport_ort(key:String):
	var p:Vector3
	if key=="zuhause":
		var h=spiel._shop("zuhause");var fw=Vector3(sin(h.yaw),0,cos(h.yaw));p=Vector3(h.c.x,h.y+0.3,h.c.y)+fw*(h.d*0.5+3.5)
	else:p=spiel.mis.ort(key,5)
	teleport(p)

func teleport(p:Vector3):
	var ziel=spiel.auto if spiel.auto!=null else spiel.spieler
	var y=_boden(Vector3(p.x,p.y,p.z))
	if ziel==spiel.auto:
		spiel.auto.global_position=Vector3(p.x,y+1.0,p.z);spiel.auto.linear_velocity=Vector3.ZERO;spiel.auto.angular_velocity=Vector3.ZERO
	else:
		spiel.spieler.global_position=Vector3(p.x,y+0.4,p.z);spiel.spieler.velocity=Vector3.ZERO
	spiel.panel_zu()
	spiel.hud.zeige("Teleport",1.0)
