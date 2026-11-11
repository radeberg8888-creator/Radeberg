extends Node3D
# Tuning-Werkstatt "Radeberg Customs" als echtes Gebäude:
# Rolltor geht auf, wenn man heranfährt -> reinfahren -> Tor zu, Auto auf die Hebebühne, Kamera innen, Tuning-Menü
# -> Fertig: Bühne runter, Auto gedreht (Drehteller), Tor auf, rausfahren.
# Lokales System: Tor vorne bei z=0 (Straße +z), Halle reicht bis z=-T. Boden auf y=KB.
const B:=18.0      # Breite
const T:=24.0      # Tiefe
const H:=6.2       # Wandhöhe
const TB:=6.4      # Torbreite
const TH:=4.6      # Torhöhe
const KB:=0.15
const PE=preload("res://scripts/people.gd")
var spiel
var tor:Node3D;var tor_koll:CollisionShape3D;var tor_auf:=0.0
var buehne:Node3D;var cam:Camera3D;var licht:OmniLight3D
var besitzer:Node3D
var aktiv:=false        # Auto steht drin, Menü läuft
var sperre:=0.0
var muss_raus:=false     # nach dem Tuning erst wieder einfangen, wenn das Auto draußen war
var _mats:={}
const LIFT:=Vector3(0,KB,-13.0)

func M(c:Color,em:=0.0)->StandardMaterial3D:
	var k=str(c)+str(em)
	if _mats.has(k):return _mats[k]
	var m=StandardMaterial3D.new();m.albedo_color=c;m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.specular_mode=BaseMaterial3D.SPECULAR_DISABLED;m.roughness=1.0
	if em>0.0:m.emission_enabled=true;m.emission=c;m.emission_energy_multiplier=em
	_mats[k]=m;return m
# Hallenboden: liegt komplett im Dachschatten -> keine Schatten empfangen (sonst Streifen-Flimmern auf dem Handy)
func M_boden(c:Color)->StandardMaterial3D:
	var k="boden"+str(c)
	if _mats.has(k):return _mats[k]
	var m=M(c).duplicate();m.disable_receive_shadows=true;m.albedo_color=c*0.82;_mats[k]=m;return m
func box(eltern:Node3D,c:Vector3,s:Vector3,col:Color,koll:=false,em:=0.0,rot:=Vector3.ZERO)->MeshInstance3D:
	var mi=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=s;mi.mesh=bm;mi.material_override=M(col,em);eltern.add_child(mi);mi.position=c;mi.rotation=rot
	if koll:
		var sb=StaticBody3D.new();var cs=CollisionShape3D.new();var sh=BoxShape3D.new();sh.size=s;cs.shape=sh;sb.add_child(cs);eltern.add_child(sb);sb.position=c;sb.rotation=rot
	return mi
func zyl(eltern:Node3D,c:Vector3,r:float,h:float,col:Color,koll:=false,rot:=Vector3.ZERO)->MeshInstance3D:
	var mi=MeshInstance3D.new();var cm=CylinderMesh.new();cm.top_radius=r;cm.bottom_radius=r;cm.height=h;cm.radial_segments=12;mi.mesh=cm;mi.material_override=M(col);eltern.add_child(mi);mi.position=c;mi.rotation=rot
	if koll:
		var sb=StaticBody3D.new();var cs=CollisionShape3D.new();var sh=CylinderShape3D.new();sh.radius=r;sh.height=h;cs.shape=sh;sb.add_child(cs);eltern.add_child(sb);sb.position=c;sb.rotation=rot
	return mi
func schrift(eltern:Node3D,t:String,c:Vector3,px:float,col:Color,rand:Color,rot:=Vector3.ZERO,leucht:=false)->Label3D:
	var l=Label3D.new();l.text=t;l.font_size=96;l.pixel_size=px;l.modulate=col;l.outline_modulate=rand;l.outline_size=18;eltern.add_child(l);l.position=c;l.rotation=rot
	l.shaded=not leucht;l.double_sided=false;l.visibility_range_end=120.0
	return l

func bauen():
	var ziegel=Color(0.55,0.27,0.2);var dunkel=Color(0.18,0.18,0.2);var beton=Color(0.55,0.55,0.53)
	# Boden innen (Beton mit Ölflecken), Vorplatz
	var bo=[box(self,Vector3(0,(KB+0.05)*0.5,-T*0.5),Vector3(B,KB+0.05,T),beton,true)]
	for i in 6:bo.append(box(self,Vector3(randf_range(-6,6),KB+0.062,randf_range(-20,-5)),Vector3(randf_range(0.8,2.2),0.024,randf_range(0.6,1.8)),Color(0.22,0.21,0.2)))
	bo.append(box(self,Vector3(0,KB+0.07,-13),Vector3(5.2,0.04,7.0),Color(0.85,0.75,0.1)))   # gelbe Markierung Bühne
	bo.append(box(self,Vector3(0,KB+0.085,-13),Vector3(4.8,0.07,6.6),beton))
	for b in bo:b.material_override=M_boden((b.material_override as StandardMaterial3D).albedo_color);b.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Wände
	box(self,Vector3(-B*0.5,H*0.5,-T*0.5),Vector3(0.4,H,T),ziegel,true)
	box(self,Vector3(B*0.5,H*0.5,-T*0.5),Vector3(0.4,H,T),ziegel,true)
	box(self,Vector3(0,H*0.5,-T),Vector3(B,H,0.4),ziegel,true)
	var seite=(B-TB)*0.5
	box(self,Vector3(-B*0.5+seite*0.5,H*0.5,0),Vector3(seite,H,0.4),ziegel,true)
	box(self,Vector3(B*0.5-seite*0.5,H*0.5,0),Vector3(seite,H,0.4),ziegel,true)
	box(self,Vector3(0,TH+(H-TH)*0.5,0),Vector3(TB,H-TH,0.4),ziegel,true)
	# Dach, Attika, Torkasten
	box(self,Vector3(0,H+0.15,-T*0.5),Vector3(B+0.6,0.3,T+0.6),dunkel,true)
	box(self,Vector3(0,H+0.95,0.2),Vector3(B+0.6,1.6,0.3),Color(0.85,0.2,0.15))
	box(self,Vector3(0,TH+0.45,0.45),Vector3(TB+0.4,0.9,0.5),Color(0.3,0.3,0.32))
	# Rolltor (bewegt sich)
	tor=Node3D.new();add_child(tor);tor.position=Vector3(0,0,0.05)
	box(tor,Vector3(0,TH*0.5+0.05,0),Vector3(TB,TH,0.12),Color(0.72,0.74,0.76))
	for i in 12:box(tor,Vector3(0,0.3+i*0.37,0.07),Vector3(TB-0.1,0.05,0.04),Color(0.5,0.52,0.55))
	var tg=["RDB","G-STR","KING$","187","LOCO"]
	schrift(tor,tg[randi()%tg.size()],Vector3(-1.2,1.6,0.1),0.012,Color(0.2,0.9,0.4),Color(0.05,0.05,0.05),Vector3(0,0,0.12))
	var tsb=StaticBody3D.new();tor_koll=CollisionShape3D.new();var tsh=BoxShape3D.new();tsh.size=Vector3(TB,TH,0.3);tor_koll.shape=tsh;tsb.add_child(tor_koll);tor.add_child(tsb);tsb.position=Vector3(0,TH*0.5,0)
	# Außen: Schild, Streifen, Graffiti, Reifenstapel, Ölfässer
	schrift(self,"RADEBERG CUSTOMS",Vector3(0,H+0.95,0.37),0.0115,Color(1,0.82,0.2),Color(0.15,0.05,0.0),Vector3.ZERO,true)
	for sx in [-1,1]:
		box(self,Vector3(sx*(TB*0.5+0.35),TH*0.5,0.22),Vector3(0.3,TH,0.05),Color(0.95,0.8,0.1))
		box(self,Vector3(sx*(B*0.5-2.0),2.0,0.22),Vector3(2.8,2.2,0.03),[Color(0.9,0.2,0.6),Color(0.2,0.6,0.95)][int(sx>0)])
		schrift(self,["TUNING","LACK"][int(sx>0)],Vector3(sx*(B*0.5-2.0),2.0,0.25),0.012,Color(1,1,1),Color(0,0,0))
		for k in 3:zyl(self,Vector3(sx*(B*0.5+0.9),KB+0.15+k*0.3,-2.0),0.42,0.28,Color(0.08,0.08,0.08),k==0)
	zyl(self,Vector3(B*0.5+0.8,KB+0.45,-4.5),0.32,0.9,Color(0.2,0.35,0.6),true)
	# Innen: Hebebühne (2 Säulen, Arme bewegen sich mit), Drehteller
	for sx in [-1,1]:
		box(self,Vector3(sx*2.6,KB+2.0,LIFT.z),Vector3(0.45,4.0,0.45),Color(0.95,0.75,0.1),true)
		box(self,Vector3(sx*2.6,KB+4.1,LIFT.z),Vector3(0.55,0.2,0.55),Color(0.2,0.2,0.22))
	box(self,Vector3(0,KB+4.0,LIFT.z),Vector3(5.6,0.18,0.3),Color(0.95,0.75,0.1))
	buehne=Node3D.new();add_child(buehne);buehne.position=LIFT
	for sx in [-1,1]:
		for sz in [-1,1]:box(buehne,Vector3(sx*1.5,0.22,sz*1.3),Vector3(2.0,0.1,0.22),Color(0.25,0.25,0.28),false,0.0,Vector3(0,sx*sz*0.35,0))
	zyl(buehne,Vector3(0,0.14,0),2.6,0.05,Color(0.35,0.35,0.38))
	# Werkbank, Werkzeugwand, Werkzeugwagen, Kompressor, Regale mit Reifen
	box(self,Vector3(-B*0.5+0.9,KB+0.5,-10),Vector3(1.2,1.0,5.0),Color(0.35,0.25,0.18),true)
	box(self,Vector3(-B*0.5+0.25,2.6,-10),Vector3(0.06,1.8,5.0),Color(0.75,0.65,0.5))
	for i in 14:box(self,Vector3(-B*0.5+0.32,randf_range(1.9,3.3),-12.2+i*0.33),Vector3(0.05,randf_range(0.2,0.5),0.06),[Color(0.8,0.1,0.1),Color(0.6,0.6,0.65),Color(0.1,0.1,0.1)][i%3])
	box(self,Vector3(-5.5,KB+0.55,-6.5),Vector3(0.9,1.1,0.6),Color(0.85,0.12,0.1),true)
	zyl(self,Vector3(-B*0.5+1.0,KB+0.6,-16.5),0.45,1.2,Color(0.2,0.4,0.25),true)
	for k in 3:box(self,Vector3(B*0.5-0.8,KB+0.8+k*1.4,-12),Vector3(1.2,0.08,8.0),Color(0.3,0.3,0.33),k==0)
	for k in 3:
		for j in 6:zyl(self,Vector3(B*0.5-0.8,KB+1.2+k*1.4,-15.2+j*1.25),0.42,0.3,Color(0.08,0.08,0.08),false,Vector3(PI*0.5,0,0))
	# Auto-Teile, Motorblock, Fässer
	box(self,Vector3(5,KB+0.4,-20),Vector3(1.2,0.8,0.9),Color(0.3,0.3,0.32),true)
	for k in 3:zyl(self,Vector3(-6+k*0.8,KB+0.45,-22.5),0.3,0.9,[Color(0.1,0.3,0.6),Color(0.7,0.2,0.1),Color(0.1,0.5,0.2)][k],true)
	# Graffiti innen, Neon-Schild an der Rückwand
	schrift(self,"RADEBERG\nCUSTOMS",Vector3(0,4.4,-T+0.25),0.016,Color(0.3,1.0,0.95),Color(0.0,0.2,0.3),Vector3.ZERO,true)
	var tags=[["GROVE 4 LIFE",Color(0.2,0.9,0.3)],["NOS!",Color(1,0.4,0.1)],["LOW & SLOW",Color(0.9,0.3,0.9)],["RDB",Color(1,0.9,0.2)]]
	for i in tags.size():
		var sx=-1 if i<2 else 1
		box(self,Vector3(sx*(B*0.5-0.22),2.4,-6-i%2*9.0),Vector3(0.03,1.6,4.0),tags[i][1]*0.6)
		schrift(self,tags[i][0],Vector3(sx*(B*0.5-0.25),2.4,-6-i%2*9.0),0.011,tags[i][1],Color(0,0,0),Vector3(0,-sx*PI*0.5,0))
	# Deckenlampen (leuchtend), ein Licht nur wenn jemand drin ist
	for k in 3:box(self,Vector3(0,H-0.1,-4-k*7),Vector3(4.0,0.12,0.4),Color(1,0.97,0.85),false,2.0)
	licht=OmniLight3D.new();add_child(licht);licht.position=Vector3(0,H-1.0,-12);licht.omni_range=18.0;licht.light_energy=1.6;licht.visible=false;licht.shadow_enabled=false
	# Besitzer
	var rng=RandomNumberGenerator.new();rng.seed=77
	besitzer=PE.make("biker",rng);add_child(besitzer);besitzer.position=Vector3(-4.2,KB,-9.0);besitzer.rotation.y=PI*0.35
	var ap:AnimationPlayer=besitzer.get_meta("anim",null)
	if ap and ap.has_animation("idle"):ap.play("idle")
	schrift(self,"Big Kurt",Vector3(-4.2,2.25,-9.0),0.006,Color(1,0.9,0.4),Color(0,0,0)).billboard=BaseMaterial3D.BILLBOARD_ENABLED
	# Innenkamera
	cam=Camera3D.new();add_child(cam);cam.fov=62.0
	var cp=Vector3(-6.8,3.6,-3.2);cam.transform=Transform3D(Basis.looking_at(LIFT+Vector3(0,1.3,0)-cp),cp)

func _lokal(p:Vector3)->Vector3:return global_transform.affine_inverse()*p

func _process(dt:float):
	if spiel==null:return
	sperre=max(sperre-dt,0.0)
	var a=spiel.auto
	var wer:Node3D=a if a!=null else spiel.spieler
	var lp=_lokal(wer.global_position)
	var nah=lp.z>-T and lp.z<22.0 and abs(lp.x)<14.0
	var drin=lp.z<-3.0 and lp.z>-T+1.0 and abs(lp.x)<B*0.5-1.0
	var ziel=1.0 if (nah or aktiv) and not (aktiv and drin and _zu_waehrend) else 0.0
	tor_auf=move_toward(tor_auf,ziel,dt*0.8)
	tor.position.y=tor_auf*(TH-0.2)
	tor.scale.y=1.0-tor_auf*0.85
	tor_koll.disabled=tor_auf>0.6
	licht.visible=nah and lp.z<2.0
	if besitzer and nah:
		var bp=besitzer.global_position;var d=wer.global_position-bp;d.y=0
		if d.length()>0.5:besitzer.rotation.y=lerp_angle(besitzer.rotation.y,atan2(d.x,d.z)-rotation.y,dt*2.0)
	# Auto rein -> Bühne
	if not drin:muss_raus=false
	if a!=null and not aktiv and not muss_raus and sperre<=0.0 and drin and a.kmh()<9.0 and spiel.panel==null:
		_rein(a)

var _zu_waehrend:=false
# Die Karosserie (a.visual) wird während des Besuchs an eine Puppe gehängt und animiert; der Physik-Körper
# wird nie eingefroren, sondern nur einmal an die Ausfahrt-Position gesetzt (eingefrorene Fahrzeuge blieben hängen).
var puppe:Node3D;var _vo:Transform3D;var _auto=null
func _vis_folgen():
	if _auto==null or not is_instance_valid(_auto) or _auto.visual==null:return
	var v:Node3D=_auto.visual
	if v.get_parent()!=self:
		if v.get_parent():v.get_parent().remove_child(v)
		add_child(v)
	v.global_transform=puppe.global_transform*_vo
func _physics_process(_dt):
	if aktiv:_vis_folgen()
func _rein(a):
	aktiv=true;_zu_waehrend=true;_auto=a
	a.engine_force=0.0;a.brake=10.0
	_vo=a.visual.transform
	if puppe==null:puppe=Node3D.new();add_child(puppe)
	puppe.global_transform=a.global_transform
	_vis_folgen()
	# Körper sofort an die spätere Ausfahrt-Position (Bühne, Blick zum Tor)
	a.global_transform=global_transform*Transform3D(Basis(),LIFT+Vector3(0,0.35,0));a.linear_velocity=Vector3.ZERO;a.angular_velocity=Vector3.ZERO
	var ap:AnimationPlayer=besitzer.get_meta("anim",null)
	if ap and ap.has_animation("talk"):ap.play("talk")
	spiel.hud.zeige("Big Kurt: \"Na, was soll's sein?\"",3.0)
	var ziel=global_transform*Transform3D(Basis(Vector3.UP,PI),LIFT+Vector3(0,0.0,0))
	var tw=create_tween();tw.tween_property(puppe,"global_transform",ziel,1.2).set_trans(Tween.TRANS_SINE)
	await tw.finished
	cam.current=true
	var tw2=create_tween().set_parallel(true)
	tw2.tween_property(puppe,"global_position",ziel.origin+global_transform.basis.y*1.3,1.6).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(buehne,"position",LIFT+Vector3(0,1.3,0),1.6).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	spiel.werkstatt_menue()

func raus():
	if not aktiv:return
	var a=_auto
	if a==null or not is_instance_valid(a):aktiv=false;return
	spiel.hud.zeige("Big Kurt: \"Fährt sich jetzt wie 'ne Rakete. Komm wieder!\"",3.0)
	var unten=global_transform*Transform3D(Basis(),LIFT)
	var tw=create_tween().set_parallel(true)
	tw.tween_property(puppe,"global_transform",unten,2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(buehne,"position",LIFT,2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(buehne,"rotation:y",buehne.rotation.y+PI,2.2).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_zu_waehrend=false
	# Karosserie zurück ans Auto
	var v:Node3D=a.visual
	if v.get_parent()!=a:
		v.get_parent().remove_child(v);a.add_child(v)
	v.transform=_vo
	spiel.kam.cam.current=true
	a.brake=0.0;a.sleeping=false
	var ap:AnimationPlayer=besitzer.get_meta("anim",null)
	if ap and ap.has_animation("idle"):ap.play("idle")
	sperre=1.0;aktiv=false;muss_raus=true;_auto=null
	spiel.hud.zeige("Tor ist offen – rausfahren!",2.5)
