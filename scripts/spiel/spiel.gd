extends Node3D
# RADEBERG – spielbare Version
# Ladebildschirm -> Welt erzeugen -> Kollision -> Spieler am Zuhause. Laufen, jedes Auto fahren (Touch, Neigung,
# Xbox-Controller, Tastatur), Verkehr, Passanten, Minikarte, große Karte, Kleiderladen, Werkstatt (Lack/Neon/Motor/
# Reparatur), Speichern zu Hause, Taxi-Job, Einstellungen.
const WELT=preload("res://scripts/welt.gd")
const STEU=preload("res://scripts/spiel/steuerung.gd")
const SPIELER=preload("res://scripts/spiel/spieler.gd")
const KAM=preload("res://scripts/spiel/kamera.gd")
const AUTO=preload("res://scripts/spiel/fahrzeug.gd")
const HUD=preload("res://scripts/spiel/hud.gd")
const MINI=preload("res://scripts/spiel/minimap.gd")
const PE=preload("res://scripts/people.gd")
const O=preload("res://scripts/outfit.gd")
const TU=preload("res://scripts/tuning.gd")
const TOR=preload("res://scripts/rolltor.gd")
const SAVE:="user://spielstand.json"
const MOTOR=preload("res://scripts/spiel/motor_sound.gd")
const MIS=preload("res://scripts/spiel/missionen.gd")
var motor;var mis

var welt;var st;var spieler;var kam;var hud;var mini
var auto=null            # Fahrzeug, in dem der Spieler sitzt
var ui:CanvasLayer
var lade:Control;var lade_bar:ProgressBar;var lade_text:Label
var bereit:=false
var geld:=500
var zeit:=9.5*60.0       # Spielminuten seit Mitternacht
var zonen:=[]            # Interaktionspunkte
var verkehr:=[]          # KI-Autos
var geparkt:=[]          # abgestellte Autos (inkl. vom Spieler verlassene)
var passanten:=[]        # [node, road, s, dir, seite]
var panel:Control=null   # offenes Menü
var sun:DirectionalLight3D
var env:Environment
var taxi_aktiv:=false;var taxi_gast=null;var taxi_ziel=null;var taxi_phase:=0;var taxi_lohn:=0;var taxi_zeit:=0.0
var rng:=RandomNumberGenerator.new()
var theme_ui:Theme
var test_modus:=""       # für automatische Testbilder

func _ready():
	rng.randomize()
	get_tree().quit_on_go_back=false
	test_modus=_arg("--test")
	st=STEU.new();add_child(st)
	ui=CanvasLayer.new();ui.layer=10;add_child(ui)
	_theme()
	_ladebildschirm()
	sun=load("res://scripts/env.gd").make(self,"day")
	for c in get_children():
		if c is WorldEnvironment:env=c.environment
	env.fog_density=0.0009;env.ssao_enabled=false;env.glow_enabled=false
	sun.directional_shadow_max_distance=90.0;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	await get_tree().process_frame
	welt=WELT.new();welt.spiel=true;add_child(welt)
	await welt.generate(func(t,p):_lade(t,p*0.8))
	_lade("Kollision …",0.82);await get_tree().process_frame
	_kollision()
	_lade("Autos werden vorbereitet …",0.88);await get_tree().process_frame
	for k in ["small_car","taxi","mercedes","bmw_e30","audi_rs7","trabant","polizei","porsche911"]:AUTO.vorlage(k)
	_lade("Spieler …",0.94);await get_tree().process_frame
	_spieler()
	_zonen()
	_passanten_pool(22)
	laden()
	if test_modus!="":st.e.sichtweite=0;st.e.schatten=false
	einstellungen_anwenden()
	lade.queue_free()
	bereit=true
	hud.zeige("Willkommen in Radeberg!",4.0)
	if test_modus!="":_testlauf()

func _arg(k:String)->String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k+"="):return a.substr(k.length()+1)
		if a==k:return "1"
	return ""

# ---------------- Oberfläche ----------------
func _theme():
	theme_ui=Theme.new();theme_ui.default_font_size=26
	var sb=StyleBoxFlat.new();sb.bg_color=Color(0.1,0.1,0.12,0.92);sb.corner_radius_top_left=10;sb.corner_radius_top_right=10;sb.corner_radius_bottom_left=10;sb.corner_radius_bottom_right=10
	sb.content_margin_left=18;sb.content_margin_right=18;sb.content_margin_top=10;sb.content_margin_bottom=10
	var sbh=sb.duplicate();sbh.bg_color=Color(0.85,0.6,0.1,0.95)
	var sbp=sb.duplicate();sbp.bg_color=Color(0.95,0.7,0.15,1.0)
	for t in ["normal","focus"]:theme_ui.set_stylebox(t,"Button",sb)
	theme_ui.set_stylebox("hover",&"Button",sbh);theme_ui.set_stylebox("pressed",&"Button",sbp)
	var pn=StyleBoxFlat.new();pn.bg_color=Color(0.03,0.03,0.04,0.86);pn.corner_radius_top_left=14;pn.corner_radius_top_right=14;pn.corner_radius_bottom_left=14;pn.corner_radius_bottom_right=14
	pn.content_margin_left=26;pn.content_margin_right=26;pn.content_margin_top=20;pn.content_margin_bottom=20
	theme_ui.set_stylebox("panel","PanelContainer",pn)

func _ladebildschirm():
	lade=Control.new();lade.set_anchors_preset(Control.PRESET_FULL_RECT);ui.add_child(lade)
	var bg=TextureRect.new();bg.texture=load("res://assets/ui/karte_basis.png");bg.set_anchors_preset(Control.PRESET_FULL_RECT);bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;lade.add_child(bg)
	var dim=ColorRect.new();dim.color=Color(0,0,0,0.55);dim.set_anchors_preset(Control.PRESET_FULL_RECT);lade.add_child(dim)
	var t=Label.new();t.text="RADEBERG";t.add_theme_font_size_override("font_size",96);t.add_theme_color_override("font_color",Color(0.98,0.82,0.3))
	t.set_anchors_preset(Control.PRESET_CENTER_TOP);t.position=Vector2(-260,140);t.size=Vector2(520,120);t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;lade.add_child(t)
	lade_bar=ProgressBar.new();lade_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);lade_bar.position=Vector2(-400,-160);lade_bar.size=Vector2(800,26);lade_bar.max_value=1.0;lade_bar.show_percentage=false;lade.add_child(lade_bar)
	lade_text=Label.new();lade_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);lade_text.position=Vector2(-400,-120);lade_text.size=Vector2(800,40);lade_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;lade_text.add_theme_font_size_override("font_size",26);lade.add_child(lade_text)
	var tip=Label.new();tip.text="Tipp: In den Einstellungen kannst du mit Handy-Neigung lenken. Xbox-Controller werden automatisch erkannt.";tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);tip.position=Vector2(-600,-70);tip.size=Vector2(1200,40);tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tip.add_theme_font_size_override("font_size",20);tip.add_theme_color_override("font_color",Color(0.8,0.8,0.8));lade.add_child(tip)

func _lade(t:String,p:float):
	if lade_text:lade_text.text=t;lade_bar.value=p

# ---------------- Kollision ----------------
func _kollision():
	var sb=StaticBody3D.new();sb.name="Kollision";add_child(sb)
	for c in welt.get_children():
		if c is MeshInstance3D and (c.name=="Gelaende" or c.name.begins_with("Strasse") or c.name in ["Beton","Gehweg","Bordstein","Mittelstreifen","Schotter","Leitplanke"]):
			var cs=CollisionShape3D.new();cs.shape=c.mesh.create_trimesh_shape();sb.add_child(cs)
	# Gebäude als Kästen
	for pl in welt.B.placed:
		var t=welt.B.get_tpl(pl.t)
		var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=t.ab.size*Vector3(0.96,1.0,0.96);cs.shape=bx;sb.add_child(cs)
		cs.transform=Transform3D(Basis(Vector3.UP,pl.yaw),Vector3(pl.c.x,pl.y+t.ab.size.y*0.5-0.1,pl.c.y))
	for sh in welt.A.shops:
		if sh.typ!="zuhause":continue
		var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=Vector3(sh.w*0.92,9.0,sh.d*0.92);cs.shape=bx;sb.add_child(cs)
		cs.transform=Transform3D(Basis(Vector3.UP,sh.yaw),Vector3(sh.c.x,sh.y+4.4,sh.c.y))
	# Anlagen (Bahnhof, Hafen, Läden …): nur die zusammengefassten Bauteile
	var an=welt.get_node_or_null("Anlagen")
	if an:
		for m in an.find_children("*","MeshInstance3D",true,false):
			var p=m.get_parent()
			if p.get_script()==TOR or (p.get_parent()!=null and p.get_parent().get_script()==TOR):continue
			if m.mesh==null or m.mesh.get_faces().size()>600000:continue
			if not (p==an or p.get_parent()==an):continue
			var cs=CollisionShape3D.new();cs.shape=m.mesh.create_trimesh_shape();sb.add_child(cs);cs.global_transform=m.global_transform
		for n in an.find_children("*","Node3D",true,false):
			if n.get_script()==TOR and n.open<0.5:
				var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=Vector3(0.2,n.h,n.w);cs.shape=bx;sb.add_child(cs)
				cs.global_transform=n.global_transform*Transform3D(Basis(),Vector3(0,n.h*0.5,0))

# ---------------- Spieler, Kamera, HUD ----------------
func _spieler():
	spieler=SPIELER.new();add_child(spieler)
	var home=_shop("zuhause")
	var fw=Vector3(sin(home.yaw),0,cos(home.yaw))
	spieler.global_position=Vector3(home.c.x,home.y+0.3,home.c.y)+fw*(home.d*0.5+3.5)
	kam=KAM.new();add_child(kam);kam.setze_ziel(spieler,false,[spieler])
	kam.yaw=home.yaw+PI*0.0
	hud=HUD.new();hud.st=st;hud.spiel=self;ui.add_child(hud)
	mini=MINI.new();ui.add_child(mini);mini.position=Vector2(22,22)
	motor=MOTOR.new();add_child(motor)
	mis=MIS.new();mis.spiel=self;add_child(mis)

func _shop(typ:String)->Dictionary:
	for s in welt.A.shops:
		if s.typ==typ:return s
	return {}

func _zonen():
	for s in welt.A.shops:
		var fw=Vector3(sin(s.yaw),0,cos(s.yaw))
		var p=Vector3(s.c.x,s.y,s.c.y)+fw*(s.d*0.5+1.8)
		var txt={"werkstatt":"Werkstatt (mit Auto hineinfahren)","waffen":"Waffen Krause","kleider":"Kleiderladen Stoffwechsel","zuhause":"Zuhause – speichern"}[s.typ]
		if s.typ=="werkstatt":p=Vector3(s.c.x,s.y,s.c.y)+fw*(s.d*0.5-6.0)
		zonen.append({"typ":s.typ,"p":p,"r":3.5 if s.typ=="werkstatt" else 1.6,"text":txt})
		_marker(p,1.2 if s.typ!="werkstatt" else 2.6)

func _marker(p:Vector3,r:float):
	var m=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=r;cy.bottom_radius=r;cy.height=1.2;cy.cap_top=false;cy.cap_bottom=false;m.mesh=cy
	var mt=StandardMaterial3D.new();mt.albedo_color=Color(1,0.8,0.1,0.28);mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mt.emission_enabled=true;mt.emission=Color(1,0.75,0.1);mt.emission_energy_multiplier=1.5;mt.cull_mode=BaseMaterial3D.CULL_DISABLED;mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override=mt;m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(m);m.position=p+Vector3(0,0.6,0)

# ---------------- Hauptschleife ----------------
func _physics_process(dt):
	if not bereit:return
	if panel==null:
		if auto!=null:auto.fahren(st,dt)
		else:
			spieler.cam_yaw=kam.blick_yaw()
			if spieler.steuern(st,dt):hud.zeige("Du bist ins Wasser gefallen")
	var hind=verkehr.duplicate();hind.append(spieler if auto==null else auto)
	for c in verkehr:c.ki_schritt(dt,hind)

func _process(dt):
	if not bereit:st.end_frame();return
	zeit+=dt*1.0   # 1 Spielminute je Sekunde
	if zeit>=1440.0:zeit-=1440.0
	if panel==null:kam.drehen(st.look)
	var ziel=auto if auto!=null else spieler
	var p:Vector3=ziel.global_position
	mini.mitte=Vector2(p.x,p.z);mini.drehung=PI-kam.blick_yaw()
	mini.zoom=lerp(mini.zoom,200.0+(auto.kmh()*2.0 if auto else 0.0),dt*2.0)
	hud.geld=geld
	if auto!=null:hud.tacho=auto.kmh();hud.nos=auto.nos_vorrat
	motor.setze(auto.kmh() if auto else 0.0,st.gas if auto else 0.0,auto!=null and panel==null)
	_verkehr_pflege(p)
	_passanten_pflege(p,dt)
	_interaktion()
	_taxi(dt)
	if st.pressed("pause") and panel==null:pausenmenue()
	elif st.pressed("karte"):
		if panel==null:karte_oeffnen()
	if st.pressed("kamera"):kam.nah=not kam.nah;kam.setze_ziel(ziel,auto!=null,[ziel])
	if st.pressed("hupe") and auto!=null:motor.hupe=0.5
	st.end_frame()

func uhrzeit_text()->String:
	return "%02d:%02d"%[int(zeit/60.0)%24,int(zeit)%60]

func ist_taxi()->bool:return auto!=null and auto.kind=="taxi"

# ---------------- Ein-/Aussteigen ----------------
func _naechstes_auto(r:float):
	var best=null;var bd=r
	for c in verkehr+geparkt:
		if not is_instance_valid(c):continue
		var d=c.global_position.distance_to(spieler.global_position)
		if d<bd:bd=d;best=c
	return best

func _interaktion():
	hud.prompt="";hud.prompt_knopf=""
	if panel!=null:return
	if auto==null:
		var c=_naechstes_auto(4.5)
		if c!=null:
			hud.prompt="Einsteigen";hud.prompt_knopf="einsteigen"
			if st.pressed("einsteigen"):einsteigen(c)
			return
		for z in zonen:
			if z.typ=="werkstatt":continue
			if spieler.global_position.distance_to(z.p)<z.r:
				hud.prompt=z.text;hud.prompt_knopf="interagieren"
				if st.pressed("interagieren") or st.pressed("einsteigen"):zone_betreten(z)
				return
	else:
		if st.pressed("einsteigen"):aussteigen();return
		if st.pressed("job") and ist_taxi():taxi_umschalten()
		for z in zonen:
			if z.typ=="werkstatt" and auto.global_position.distance_to(z.p)<z.r+2.0:
				if auto.kmh()<6.0:
					hud.prompt="Werkstatt öffnen";hud.prompt_knopf=""
					if not z.get("offen",false):z.offen=true;werkstatt_menue()
				return
			if z.typ=="werkstatt":z.offen=false

func einsteigen(c):
	verkehr.erase(c);if not geparkt.has(c):geparkt.append(c)
	auto=c;c.uebernehmen();c.contact_monitor=true;c.max_contacts_reported=4
	if not c.body_entered.is_connected(_rempler):c.body_entered.connect(_rempler)
	spieler.visible=false;spieler.process_mode=Node.PROCESS_MODE_DISABLED;spieler.collision_layer=0
	kam.setze_ziel(c,true,[c]);hud.modus="auto";hud.reset_touch()
	if c.kind=="taxi":hud.zeige("Taxi: Tippe TAXI für den Taxi-Job",3.5)

func aussteigen():
	if auto.kmh()>25.0:hud.zeige("Zu schnell zum Aussteigen!",1.5);return
	var p=auto.aussteig_punkt()
	auto.modus="geparkt";auto.engine_force=0;auto.brake=8.0;auto.steering=0
	spieler.global_position=p;spieler.velocity=Vector3.ZERO;spieler.visible=true;spieler.process_mode=Node.PROCESS_MODE_INHERIT;spieler.collision_layer=1
	kam.setze_ziel(spieler,false,[spieler]);hud.modus="fuss";hud.reset_touch()
	if taxi_aktiv:taxi_umschalten()
	auto=null

func _rempler(b):
	if auto!=null and auto.kmh()>25.0 and st.e.vibration:Input.vibrate_handheld(int(clamp(auto.kmh(),40,250)))
	if b!=null and b.get_script()==AUTO and b.modus=="ki":
		verkehr.erase(b);b.parken();b.freeze=false;geparkt.append(b)

# ---------------- Verkehr ----------------
const FARB=["small_car","taxi","mercedes","bmw_e30","audi_rs7","trabant","small_car","mercedes","taxi","porsche911","polizei","bmw_e30"]
func _ziel_anzahl()->int:return [12,22,32][int(st.e.sichtweite)]
func _verkehr_pflege(p:Vector3):
	var p2=Vector2(p.x,p.z)
	for c in verkehr.duplicate():
		if Vector2(c.global_position.x,c.global_position.z).distance_to(p2)>360.0:verkehr.erase(c);c.queue_free()
	for c in geparkt.duplicate():
		if c!=auto and is_instance_valid(c) and not (mis!=null and c==mis.auto_m) and Vector2(c.global_position.x,c.global_position.z).distance_to(p2)>420.0:geparkt.erase(c);c.queue_free()
	if verkehr.size()<_ziel_anzahl() and Engine.get_process_frames()%6==0:_spawn_auto(p2)

func _spawn_auto(p2:Vector2):
	for versuch in 12:
		var r=welt.S.roads[rng.randi()%welt.S.roads.size()]
		if not r.typ in ["strasse","allee","autobahn","land","gasse"]:continue
		var L=welt.S.length(r);var s=rng.randf()*L
		var a=welt.S.at(r,s);var q:Vector2=a[0]
		var d=q.distance_to(p2)
		if d<110.0 or d>300.0:continue
		if r.tunnel_flags[a[3]]:continue
		var frei=true
		for o in verkehr:
			if Vector2(o.global_position.x,o.global_position.z).distance_to(q)<20.0:frei=false;break
		if not frei:continue
		var c=AUTO.new();add_child(c)
		var k=FARB[rng.randi()%FARB.size()]
		if r.typ=="autobahn" and rng.randf()<0.15:k=["lkw","bus"][rng.randi()%2]
		c.setup(k)
		var dir=1 if rng.randf()<0.5 else -1
		c.als_ki(r,s,dir,c._lane(r),welt.S)
		verkehr.append(c)
		return

# ---------------- Passanten ----------------
func _passanten_pool(n:int):
	var r2=RandomNumberGenerator.new();r2.seed=11
	for i in n:
		var ps=PE.make(PE.CIVIL[i%PE.CIVIL.size()],r2);add_child(ps);ps.visible=false
		passanten.append({"n":ps,"r":null,"s":0.0,"dir":1,"seite":1,"v":r2.randf_range(1.1,1.6)})

func _passanten_pflege(p:Vector3,dt:float):
	var p2=Vector2(p.x,p.z)
	for e in passanten:
		var n=e.n
		if e.r==null or Vector2(n.global_position.x,n.global_position.z).distance_to(p2)>170.0:
			# neu setzen: Gehweg in einem Stadtviertel 40–150 m entfernt
			if Engine.get_process_frames()%3!=0:continue
			var r=welt.S.roads[rng.randi()%welt.S.roads.size()]
			if not r.typ in ["strasse","allee","gasse"]:continue
			var L=welt.S.length(r);var s=rng.randf()*L;var a=welt.S.at(r,s)
			var d=a[0].distance_to(p2)
			if d<40.0 or d>150.0 or welt.B.district(a[0])==null:continue
			e.r=r;e.s=s;e.dir=1 if rng.randf()<0.5 else -1;e.seite=1 if rng.randf()<0.5 else -1
			n.visible=true;PE.play(n,"walk",rng.randf())
		var r=e.r;var L=welt.S.length(r)
		e.s+=e.v*dt*e.dir
		if e.s<3.0 or e.s>L-3.0:e.dir=-e.dir;e.s=clamp(e.s,3.0,L-3.0)
		var a=welt.S.at(r,e.s);var t:Vector2=a[2];var nn=Vector2(-t.y,t.x)
		var q:Vector2=a[0]+nn*e.seite*(r.w+r.sw*0.55)
		n.global_position=Vector3(q.x,a[1]+0.14,q.y);n.rotation.y=atan2(t.x*e.dir,t.y*e.dir)
		# vor dem Spieler-Auto zur Seite springen
		if auto!=null and auto.global_position.distance_to(n.global_position)<3.0 and auto.kmh()>15:
			e.r=null;n.visible=false

# ---------------- Läden / Zonen ----------------
func zone_betreten(z:Dictionary):
	match z.typ:
		"zuhause":speichern();hud.zeige("Spiel gespeichert. Gesundheit aufgefüllt.",3.0)
		"kleider":kleider_menue()
		"waffen":hud.zeige("Waffen Krause: Der Laden öffnet im nächsten Update.",3.0)

func _panel(titel:String)->VBoxContainer:
	if panel:panel.queue_free()
	hud.modus="menue";hud.reset_touch()
	var pc=PanelContainer.new();pc.theme=theme_ui;ui.add_child(pc);panel=pc
	var vs=get_viewport().get_visible_rect().size
	pc.position=Vector2(vs.x-560,max(10.0,vs.y*0.5-330));pc.size=Vector2(520,min(660.0,vs.y-20))
	var v=VBoxContainer.new();v.add_theme_constant_override("separation",10);pc.add_child(v)
	var l=Label.new();l.text=titel;l.add_theme_font_size_override("font_size",36);l.add_theme_color_override("font_color",Color(0.98,0.82,0.3));v.add_child(l)
	return v

func _btn(v:Control,t:String,f:Callable)->Button:
	var b=Button.new();b.text=t;b.custom_minimum_size=Vector2(0,58);b.pressed.connect(f);v.add_child(b);return b

func panel_zu():
	if panel:panel.queue_free();panel=null
	hud.modus="auto" if auto!=null else "fuss"
	kam.setze_ziel(auto if auto else spieler,auto!=null,[auto if auto else spieler])

# Kleiderladen: Teile durchschalten (sofort sichtbar), Preis bezahlen
var _kl_alt:={}
func kleider_menue():
	_kl_alt=spieler.outfit.duplicate()
	var v=_panel("STOFFWECHSEL")
	kam.dist=2.6;kam.yaw=spieler.figur.rotation.y;kam.pitch=-6.0
	var info=Label.new();v.add_child(info)
	var reihen=[["top","Oberteil",O.TOPS],["bottom","Hose",O.BOTTOMS],["shoes","Schuhe",O.SHOE_LIST],["hat","Kopf",O.HATS]]
	var labels={}
	var preis=func()->int:
		var p=0
		for r in reihen:
			if spieler.outfit[r[0]]!=_kl_alt[r[0]]:p+=(r[2][spieler.outfit[r[0]]][2] if r[0]!="hat" else 20)
		if spieler.outfit.glasses and not _kl_alt.glasses:p+=25
		if spieler.outfit.chain and not _kl_alt.chain:p+=150
		return p
	var upd=func():
		for r in reihen:labels[r[0]].text=r[1]+": "+str(r[2][spieler.outfit[r[0]]][0])
		labels.extra.text="Brille: "+("ja" if spieler.outfit.glasses else "nein")+"   Kette: "+("ja" if spieler.outfit.chain else "nein")
		info.text="Preis: $"+str(preis.call())+"     Dein Geld: $"+str(geld)
		spieler.kleidung()
	for r in reihen:
		var h=HBoxContainer.new();v.add_child(h)
		var bl=Button.new();bl.text=" ◀ ";bl.custom_minimum_size=Vector2(70,56);h.add_child(bl)
		var l=Label.new();l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;h.add_child(l);labels[r[0]]=l
		var br=Button.new();br.text=" ▶ ";br.custom_minimum_size=Vector2(70,56);h.add_child(br)
		var key=r[0];var n=r[2].size()
		bl.pressed.connect(func():spieler.outfit[key]=(spieler.outfit[key]-1+n)%n;upd.call())
		br.pressed.connect(func():spieler.outfit[key]=(spieler.outfit[key]+1)%n;upd.call())
	var ex=Button.new();ex.custom_minimum_size=Vector2(0,56);v.add_child(ex);labels.extra=ex
	ex.pressed.connect(func():
		if spieler.outfit.glasses and spieler.outfit.chain:spieler.outfit.glasses=false;spieler.outfit.chain=false
		elif spieler.outfit.glasses:spieler.outfit.chain=true
		else:spieler.outfit.glasses=true
		upd.call())
	var h2=HBoxContainer.new();v.add_child(h2)
	var kauf=Button.new();kauf.text="KAUFEN";kauf.custom_minimum_size=Vector2(220,64);h2.add_child(kauf)
	var weg=Button.new();weg.text="VERLASSEN";weg.custom_minimum_size=Vector2(220,64);h2.add_child(weg)
	kauf.pressed.connect(func():
		var p=preis.call()
		if p>geld:hud.zeige("Nicht genug Geld!",2.0);return
		geld-=p;_kl_alt=spieler.outfit.duplicate();hud.zeige("Gekauft für $"+str(p),2.0);panel_zu())
	weg.pressed.connect(func():spieler.outfit=_kl_alt.duplicate();spieler.kleidung();panel_zu())
	upd.call()

# Werkstatt: Lackieren, Neon, Motor, NOS, Reparieren
var _tu:={}
func werkstatt_menue():
	if auto==null:return
	auto.engine_force=0;auto.brake=10.0
	var v=_panel("RADEBERG CUSTOMS")
	_tu=auto.get_meta("tuning",TU.default_cfg())
	var g=GridContainer.new();g.columns=6;v.add_child(g)
	var farben=["Signalrot","Racing-Gelb","Rallye-Blau","Tiefschwarz","Weiß","Limette","Orange","Lila","Pink","Silber","Gold","Petrol"]
	var lk=Label.new();lk.text="Lack ($250):";v.move_child(lk,1)
	for f in farben:
		var b=Button.new();b.custom_minimum_size=Vector2(66,54);g.add_child(b)
		var sb=StyleBoxFlat.new();sb.bg_color=TU.COLORS[f];sb.corner_radius_top_left=8;sb.corner_radius_top_right=8;sb.corner_radius_bottom_left=8;sb.corner_radius_bottom_right=8
		b.add_theme_stylebox_override("normal",sb);b.add_theme_stylebox_override("hover",sb)
		b.pressed.connect(func():if _zahlen(250):_tu.paint=f;_tu_anwenden())
	var hn=HBoxContainer.new();v.add_child(hn)
	var ln=Label.new();ln.text="Neon ($400): ";hn.add_child(ln)
	for nn in ["Aus","Blau","Rot","Grün","Lila","Türkis"]:
		var b=Button.new();b.text=nn;b.add_theme_font_size_override("font_size",18);hn.add_child(b)
		b.pressed.connect(func():if _zahlen(400 if nn!="Aus" else 0):_tu.neon=nn;_tu_anwenden())
	_btn(v,"Motor-Tuning Stufe +1 ($1.500)",func():
		var lv=auto.get_meta("motor",0)
		if lv>=3:hud.zeige("Motor ist voll getunt");return
		if _zahlen(1500):auto.set_meta("motor",lv+1);auto.kraft*=1.12;auto.max_kmh+=12;hud.zeige("Motor Stufe "+str(lv+1)))
	_btn(v,"NOS-Tank füllen ($200)",func():if _zahlen(200):auto.nos_vorrat=1.0;hud.zeige("NOS voll"))
	_btn(v,"Reparieren ($100)",func():if _zahlen(100):auto.aufrichten();hud.zeige("Repariert"))
	_btn(v,"Fertig",panel_zu)

func _zahlen(b:int)->bool:
	if b>geld:hud.zeige("Nicht genug Geld!",2.0);return false
	geld-=b;return true
func _tu_anwenden():
	auto.set_meta("tuning",_tu)
	auto.visual.set_meta("model",auto.visual.get_meta("model",""))
	TU.apply(auto.visual,_tu)

# ---------------- Karte ----------------
func karte_oeffnen():
	var k=load("res://scripts/karte_ui.gd").new()
	hud.modus="menue";hud.reset_touch()
	var p=(auto if auto else spieler).global_position
	k.player=Vector2(p.x,p.z);k.player_dir=kam.blick_yaw()
	ui.add_child(k);panel=k
	var b=Button.new();b.text="  ZURÜCK  ";b.theme=theme_ui;b.custom_minimum_size=Vector2(200,64);k.add_child(b)
	var vs=get_viewport().get_visible_rect().size;b.position=Vector2(vs.x-240,vs.y-90)
	b.pressed.connect(panel_zu)

# ---------------- Pause / Einstellungen ----------------
func pausenmenue():
	get_tree().paused=false
	var v=_panel("PAUSE")
	_btn(v,"Weiter",panel_zu)
	_btn(v,"Karte",func():panel_zu();karte_oeffnen())
	_btn(v,"Missionen ("+str(mis.erledigt.size())+"/"+str(mis.spielbare().size())+")",missionen_menue)
	if mis.aktiv!=null:_btn(v,"Mission abbrechen",func():mis.abbrechen();panel_zu())
	_btn(v,"Einstellungen",einstellungen_menue)
	_btn(v,"Steuerung (Hilfe)",hilfe)
	_btn(v,"Neu starten am Zuhause",func():panel_zu();if auto:aussteigen();_zum_zuhause())
	_btn(v,"Beenden",func():speichern();get_tree().quit())

func missionen_menue():
	var v=_panel("MISSIONEN")
	var info=Label.new();info.text="Fahr-Missionen sind spielbar. Kampf-Missionen kommen mit dem Waffensystem.";info.autowrap_mode=TextServer.AUTOWRAP_WORD;info.add_theme_font_size_override("font_size",18);info.custom_minimum_size=Vector2(460,0);v.add_child(info)
	var sc=ScrollContainer.new();sc.custom_minimum_size=Vector2(470,420);v.add_child(sc)
	var w=VBoxContainer.new();w.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.add_child(w)
	var last=""
	for m in mis.spielbare():
		if m.kontakt!=last:
			last=m.kontakt;var l=Label.new();l.text=mis.kontakt_name(m.kontakt);l.add_theme_color_override("font_color",Color(0.98,0.82,0.3));l.add_theme_font_size_override("font_size",22);w.add_child(l)
		var done=mis.erledigt.has(str(m.id))
		var b=Button.new();b.text=("✔ " if done else "")+m.titel+"  ($"+str(int(m.belohnung) if int(m.belohnung)>0 else 500)+")";b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",20);b.custom_minimum_size=Vector2(0,48);w.add_child(b)
		var mm=m
		b.pressed.connect(func():panel_zu();mis.starten(mm))
	_btn(v,"Zurück",pausenmenue)

func _zum_zuhause():
	var home=_shop("zuhause");var fw=Vector3(sin(home.yaw),0,cos(home.yaw))
	spieler.global_position=Vector3(home.c.x,home.y+0.3,home.c.y)+fw*(home.d*0.5+3.5)

func einstellungen_menue():
	var v=_panel("EINSTELLUNGEN")
	var sc=ScrollContainer.new();sc.custom_minimum_size=Vector2(470,500);v.add_child(sc)
	var w=VBoxContainer.new();w.size_flags_horizontal=Control.SIZE_EXPAND_FILL;w.add_theme_constant_override("separation",8);sc.add_child(w)
	var lenk=OptionButton.new();lenk.add_item("Lenken: Joystick");lenk.add_item("Lenken: Handy neigen");lenk.selected=1 if st.e.lenkung=="neigen" else 0;w.add_child(lenk)
	lenk.item_selected.connect(func(i):st.e.lenkung="neigen" if i==1 else "stick";if i==1:st.kalibrieren();hud.zeige("Halte das Handy gerade – Mitte gespeichert",3.0))
	_btn(w,"Neigung: Mitte neu setzen",func():st.kalibrieren();hud.zeige("Mitte gespeichert"))
	_slider(w,"Neigungs-Empfindlichkeit","neig_empf",0.4,2.5)
	var inv=CheckButton.new();inv.text="Neigung umkehren";inv.button_pressed=st.e.neig_umkehren;w.add_child(inv);inv.toggled.connect(func(b):st.e.neig_umkehren=b)
	_slider(w,"Kamera-Empfindlichkeit","kamera_empf",0.3,2.5)
	var iy=CheckButton.new();iy.text="Kamera hoch/runter umkehren";iy.button_pressed=st.e.kamera_invert_y;w.add_child(iy);iy.toggled.connect(func(b):st.e.kamera_invert_y=b)
	_slider(w,"Größe der Touch-Knöpfe","hud_groesse",0.7,1.4)
	var sw=OptionButton.new();for t in ["Sichtweite: niedrig (schnell)","Sichtweite: mittel","Sichtweite: hoch"]:sw.add_item(t)
	sw.selected=int(st.e.sichtweite);w.add_child(sw);sw.item_selected.connect(func(i):st.e.sichtweite=i;einstellungen_anwenden())
	var sh=CheckButton.new();sh.text="Schatten";sh.button_pressed=st.e.schatten;w.add_child(sh);sh.toggled.connect(func(b):st.e.schatten=b;einstellungen_anwenden())
	var fp=CheckButton.new();fp.text="FPS anzeigen";fp.button_pressed=st.e.fps;w.add_child(fp);fp.toggled.connect(func(b):st.e.fps=b)
	var lc=Label.new();lc.text="Controller: "+("verbunden ✔" if st.controller else "keiner – Xbox-Controller per Bluetooth koppeln");lc.add_theme_font_size_override("font_size",20);lc.autowrap_mode=TextServer.AUTOWRAP_WORD;w.add_child(lc)
	_btn(v,"Speichern & zurück",func():st.speichern();panel_zu())

func _slider(v:Control,t:String,key:String,a:float,b:float):
	var l=Label.new();l.text=t;l.add_theme_font_size_override("font_size",22);v.add_child(l)
	var s=HSlider.new();s.min_value=a;s.max_value=b;s.step=0.05;s.value=st.e[key];s.custom_minimum_size=Vector2(420,44);v.add_child(s)
	s.value_changed.connect(func(x):st.e[key]=x)

func einstellungen_anwenden():
	sun.shadow_enabled=st.e.schatten
	var f=[0.6,1.0,1.6][int(st.e.sichtweite)]
	var g=welt.get_node_or_null("Gebaeude")
	if g:
		for m in g.find_children("*","MeshInstance3D",true,false):
			if not m.has_meta("vr"):m.set_meta("vr",m.visibility_range_end)
			if m.get_meta("vr")>0.0:m.visibility_range_end=m.get_meta("vr")*f
	var far=[900.0,1600.0,2600.0][int(st.e.sichtweite)]
	kam.cam.far=far
	env.fog_density=[0.0016,0.0009,0.0005][int(st.e.sichtweite)]

func hilfe():
	var v=_panel("STEUERUNG")
	var l=Label.new();l.autowrap_mode=TextServer.AUTOWRAP_WORD;l.custom_minimum_size=Vector2(460,0);l.add_theme_font_size_override("font_size",20)
	l.text="TOUCH\n• Links: Stick zum Laufen/Lenken (erscheint, wo du tippst)\n• Rechts wischen: Kamera drehen\n• Auto: GAS, BREMSE (Rückwärts), HAND, NOS, RAUS\n• Neigen-Lenkung in den Einstellungen\n\nXBOX-CONTROLLER\n• Linker Stick: laufen/lenken, rechter Stick: Kamera\n• RT Gas, LT Bremse/Rückwärts, RB Handbremse, X NOS\n• Y Ein-/Aussteigen, A Springen, B Rennen\n• D-Pad rechts: Laden betreten, D-Pad hoch: Taxi-Job\n• Start: Pause, Back: Karte\n\nTASTATUR\n• WASD, Maus, F/E Einsteigen, Leertaste, Shift, M Karte, Esc Pause"
	var sc=ScrollContainer.new();sc.custom_minimum_size=Vector2(470,440);v.add_child(sc);sc.add_child(l)
	_btn(v,"Zurück",pausenmenue)

# ---------------- Taxi-Job ----------------
func taxi_umschalten():
	taxi_aktiv=not taxi_aktiv
	if taxi_aktiv:hud.zeige("Taxi-Job gestartet – fahr zum gelben Punkt",3.0);taxi_phase=0;_taxi_neuer_gast()
	else:
		hud.zeige("Taxi-Job beendet",2.0);hud.job_text="";mini.ziel=null
		if taxi_gast:taxi_gast.queue_free();taxi_gast=null
		if _taxi_marker:_taxi_marker.queue_free();_taxi_marker=null

var _taxi_marker:MeshInstance3D
func _taxi_punkt(min_d:float,max_d:float)->Vector3:
	var p=Vector2(auto.global_position.x,auto.global_position.z)
	for i in 200:
		var r=welt.S.roads[rng.randi()%welt.S.roads.size()]
		if not r.typ in ["strasse","allee","gasse"]:continue
		var a=welt.S.at(r,rng.randf()*welt.S.length(r))
		var d=a[0].distance_to(p)
		if d>min_d and d<max_d and welt.B.district(a[0])!=null:
			var t:Vector2=a[2];var nn=Vector2(-t.y,t.x);var q=a[0]+nn*(r.w+1.2)
			return Vector3(q.x,a[1]+0.14,q.y)
	return auto.global_position+Vector3(80,0,0)

func _taxi_neuer_gast():
	var pos=_taxi_punkt(120.0,450.0)
	var r2=RandomNumberGenerator.new();r2.randomize()
	taxi_gast=PE.make(PE.CIVIL[r2.randi()%PE.CIVIL.size()],r2);add_child(taxi_gast);taxi_gast.global_position=pos;PE.play(taxi_gast,"idle")
	taxi_ziel=pos;taxi_phase=0;_taxi_mark(pos)
	hud.job_text="Fahrgast abholen"

func _taxi_mark(p:Vector3):
	if _taxi_marker:_taxi_marker.queue_free()
	var m=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=3.0;cy.bottom_radius=3.0;cy.height=1.5;cy.cap_top=false;cy.cap_bottom=false;m.mesh=cy
	var mt=StandardMaterial3D.new();mt.albedo_color=Color(1,0.85,0.1,0.3);mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.material_override=mt;add_child(m);m.global_position=p+Vector3(0,0.75,0);_taxi_marker=m
	mini.ziel=Vector2(p.x,p.z)

func _taxi(dt):
	if not taxi_aktiv or auto==null:return
	taxi_zeit+=dt
	var d=auto.global_position.distance_to(taxi_ziel)
	if taxi_phase==0:
		if d<6.0 and auto.kmh()<8.0:
			taxi_gast.visible=false;taxi_phase=1;taxi_zeit=0.0
			taxi_ziel=_taxi_punkt(250.0,900.0);_taxi_mark(taxi_ziel)
			taxi_lohn=int(taxi_ziel.distance_to(auto.global_position)*0.18)+25
			hud.zeige("Fahrgast eingestiegen – bring ihn zum Ziel",3.0)
	else:
		hud.job_text="Ziel: %d m   Fahrpreis: $%d   Zeit: %ds"%[int(d),taxi_lohn,int(taxi_zeit)]
		if d<7.0 and auto.kmh()<8.0:
			var bonus=max(0,int(60-taxi_zeit*0.15))
			geld+=taxi_lohn+bonus
			hud.zeige("Fahrt bezahlt: $%d (Trinkgeld $%d)"%[taxi_lohn,bonus],3.5)
			if taxi_gast:taxi_gast.queue_free();taxi_gast=null
			_taxi_neuer_gast()

# ---------------- Speichern / Laden ----------------
func speichern():
	var p=spieler.global_position
	var d={"geld":geld,"zeit":zeit,"outfit":spieler.outfit,"pos":[p.x,p.y,p.z],"missionen":mis.erledigt.keys()}
	var f=FileAccess.open(SAVE,FileAccess.WRITE);f.store_string(JSON.stringify(d));f.close()

func laden():
	var f=FileAccess.open(SAVE,FileAccess.READ)
	if f==null:return
	var d=JSON.parse_string(f.get_as_text())
	if not d is Dictionary:return
	geld=int(d.get("geld",500));zeit=float(d.get("zeit",zeit))
	for k in d.get("missionen",[]):mis.erledigt[str(k)]=true
	if d.has("outfit"):
		for k in d.outfit:spieler.outfit[k]=d.outfit[k] if not (d.outfit[k] is float) else int(d.outfit[k])
		spieler.kleidung()

func _notification(what):
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and bereit:
		if panel!=null:panel_zu()
		else:pausenmenue()
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_WM_CLOSE_REQUEST:
		if bereit:speichern()

# ---------------- automatischer Test (Bilder) ----------------
func _testlauf():
	var s=load("res://scripts/spiel/testlauf.gd").new();s.spiel=self;add_child(s)
