extends Node3D
# Tuning-Werkstatt: Halle mit Drehteller, Menü links (Kategorien), Optionen unten, Werte rechts.
# Am Handy per Touch bedienbar. Mit "-- --shots" werden Vorher/Nachher-Bilder gerendert.
const VH=preload("res://scripts/vehicles.gd")
const T=preload("res://scripts/tuning.gd")
const Mats=preload("res://scripts/mats.gd")
const F=preload("res://scripts/fit.gd")
const R=preload("res://scripts/rimgen.gd")

var kinds:=["jdm","audi_r8","bmw_m8","porsche911","audi_rs7","mercedes","hoonicorn","bmw_e30","trabant","bugatti","small_car"]
var idx:=0
var car:Node3D;var cfg:Dictionary;var base_stats:Dictionary
var turntable:Node3D
var cat:="Frontschürze"
var money:=250000
const CATS=["OPTIK","Frontschürze","Seitenschweller","Heckschürze","Spoiler","Motorhaube","Dachhutze","Widebody","Felgen","Felgenfarbe","Felgenlack","Bremssättel","Lack","Lackart","Scheinwerfer","Neon","Scheiben","Auspuff","Reifenqualm",
	"LEISTUNG","Ansaugung","Nockenwelle","Krümmer","Steuergerät","Kraftstoff","Aufladung","Kupplung","Getriebe","Differenzial","Federn","Dämpfer","Stabis","Tieferlegung","Bremsen","Reifen","NOS","Gewicht"]
const KEYS={"Frontschürze":"front","Seitenschweller":"side","Heckschürze":"rear","Spoiler":"spoiler","Motorhaube":"hood","Dachhutze":"roofscoop","Widebody":"widebody",
	"Felgen":"rim","Felgengröße":"rim_size","Felgenfarbe":"rim_color","Felgenlack":"rim_finish","Bremssättel":"caliper","Lack":"paint","Lackart":"finish","Scheinwerfer":"lights","Neon":"neon","Scheiben":"tint","Auspuff":"exhaust","Reifenqualm":"smoke",
	"Ansaugung":"intake","Nockenwelle":"cam","Krümmer":"headers","Steuergerät":"ecu","Kraftstoff":"fuel","Aufladung":"boost","Kupplung":"clutch","Getriebe":"gearbox","Differenzial":"diff",
	"Federn":"springs","Dämpfer":"dampers","Stabis":"sway","Tieferlegung":"lowering","Bremsen":"brakes","Reifen":"tires","NOS":"nos","Gewicht":"weight"}
var ui:Control;var opt_box:HBoxContainer;var cat_box:VBoxContainer;var stat_box:VBoxContainer;var title:Label;var price_lbl:Label

func _ready():
	var args=OS.get_cmdline_user_args()
	_env();_hall()
	turntable=Node3D.new();add_child(turntable)
	_ui()
	_load_car()
	var cam=Camera3D.new();cam.fov=48;add_child(cam);cam.position=Vector3(5.2,1.7,6.2);cam.look_at(Vector3(0,0.6,0))
	if "--shots" in args:_shots()

func _env():
	var we=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(0.05,0.05,0.06)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(0.55,0.55,0.6);env.ambient_light_energy=0.45
	env.tonemap_mode=Environment.TONE_MAPPER_AGX;env.glow_enabled=true;env.glow_intensity=0.6;env.glow_bloom=0.05
	env.ssao_enabled=true;env.adjustment_enabled=true;env.adjustment_contrast=1.1;env.adjustment_saturation=1.1
	var sky=Sky.new();var ps=ProceduralSkyMaterial.new();ps.sky_top_color=Color(0.3,0.3,0.32);ps.sky_horizon_color=Color(0.5,0.5,0.5);ps.ground_bottom_color=Color(0.1,0.1,0.1);sky.sky_material=ps;env.sky=sky;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	we.environment=env;add_child(we)

# Werkstatthalle: Betonboden, Ziegelwände, Rolltor, Leuchtstoffröhren, Regale, Reifenstapel, Hebebühne
func _hall():
	var B=preload("res://scripts/batch.gd").new()
	var floor=Mats.pbr("concrete",0.35,Color(0.62,0.62,0.64));var brick=Mats.bricks(0.45);var dark=Mats.flat(Color(0.12,0.12,0.13),0.6,0.4)
	B.box(floor,Vector3(-12,-0.1,-12),Vector3(12,0,12))
	B.box(brick,Vector3(-12,0,-12),Vector3(12,7,-11.6));B.box(brick,Vector3(-12,0,-12),Vector3(-11.6,7,12));B.box(brick,Vector3(11.6,0,-12),Vector3(12,7,12))
	B.box(Mats.flat(Color(0.18,0.18,0.2),0.7),Vector3(-12,7,-12),Vector3(12,7.3,12))
	for x in range(-10,11,4):B.box(dark,Vector3(x-0.15,6.4,-12),Vector3(x+0.15,7,12))
	# Werkbänke und Regale an der Rückwand
	var wood=Mats.flat(Color(0.35,0.22,0.12),0.7);var red=Mats.flat(Color(0.6,0.05,0.04),0.4,0.3);var steel=Mats.flat(Color(0.5,0.5,0.52),0.35,0.8)
	for i in 4:
		var x0=-10.5+i*3.0
		B.box(red,Vector3(x0,0,-11.6),Vector3(x0+2.6,0.95,-10.9));B.box(steel,Vector3(x0,0.95,-11.6),Vector3(x0+2.6,1.0,-10.8))
		for k in 3:B.box(Mats.flat(Color(0.15+0.1*k,0.15,0.16),0.5,0.6),Vector3(x0+0.1,0.1+k*0.3,-10.88),Vector3(x0+2.5,0.35+k*0.3,-10.86))
		B.box(Mats.flat(Color(0.25,0.27,0.3),0.6,0.6),Vector3(x0,1.6,-11.6),Vector3(x0+2.6,3.4,-11.55))
	for i in 3:B.box(steel,Vector3(4,1.2+i*1.1,-11.6),Vector3(10.8,1.25+i*1.1,-10.9))
	# Reifenstapel
	var tire=Mats.flat(Color(0.03,0.03,0.03),0.85)
	for s in 3:
		for k in 4:B.cyl(tire,Vector3(-9.5+s*0.9,0.15+k*0.28,-8.5),0.36,0.26)
	# Hebebühne rechts
	B.box(Mats.flat(Color(0.8,0.6,0.05),0.4,0.4),Vector3(6.5,0,-6),Vector3(6.9,3.2,-5.6));B.box(Mats.flat(Color(0.8,0.6,0.05),0.4,0.4),Vector3(9.8,0,-6),Vector3(10.2,3.2,-5.6))
	B.box(steel,Vector3(6.5,0.5,-6.2),Vector3(10.2,0.6,-1.2))
	# Bodenmarkierung um den Drehteller
	var paint=Mats.flat(Color(0.9,0.75,0.1),0.6)
	B.box(paint,Vector3(-4.2,0.001,-4.2),Vector3(4.2,0.006,-4.05));B.box(paint,Vector3(-4.2,0.001,4.05),Vector3(4.2,0.006,4.2))
	B.box(paint,Vector3(-4.2,0.001,-4.2),Vector3(-4.05,0.006,4.2));B.box(paint,Vector3(4.05,0.001,-4.2),Vector3(4.2,0.006,4.2))
	B.commit(self)
	# Drehteller
	var tt=MeshInstance3D.new();tt.mesh=CylinderMesh.new();tt.mesh.top_radius=3.3;tt.mesh.bottom_radius=3.35;tt.mesh.height=0.08;add_child(tt);tt.position.y=0.04
	var ttm=StandardMaterial3D.new();ttm.albedo_color=Color(0.08,0.08,0.09);ttm.metallic=0.6;ttm.roughness=0.45;tt.material_override=ttm
	var ring=MeshInstance3D.new();ring.mesh=TorusMesh.new();ring.mesh.inner_radius=3.32;ring.mesh.outer_radius=3.4;add_child(ring);ring.position.y=0.06
	var rm=StandardMaterial3D.new();rm.albedo_color=Color(1,0.7,0.2);rm.emission_enabled=true;rm.emission=Color(1,0.65,0.15);rm.emission_energy_multiplier=3;ring.material_override=rm
	# Rolltor hinten links (Poly Haven Rollladen, groß skaliert)
	var door:Node3D=load("res://assets/props/polyhaven/rollershutter.glb").instantiate();add_child(door)
	door.transform=Transform3D(Basis(Vector3.UP,PI*0.5).scaled(Vector3(6.0/5.1,4.5/1.85,1.0)),Vector3(-11.55,0,2))
	# Leuchtstoffröhren + Licht
	var tube=StandardMaterial3D.new();tube.albedo_color=Color(1,1,1);tube.emission_enabled=true;tube.emission=Color(0.95,0.97,1);tube.emission_energy_multiplier=4
	for x in [-6,-2,2,6]:
		for z in [-6,-1,4]:
			var t=MeshInstance3D.new();t.mesh=BoxMesh.new();t.mesh.size=Vector3(0.12,0.06,1.8);add_child(t);t.position=Vector3(x,6.3,z);t.material_override=tube
	for p in [Vector3(-3,5.5,-3),Vector3(3,5.5,-3),Vector3(-3,5.5,3),Vector3(3,5.5,3)]:
		var l=OmniLight3D.new();add_child(l);l.position=p;l.omni_range=12;l.light_energy=1.3;l.light_color=Color(0.95,0.97,1);l.shadow_enabled=(p.x<0 and p.z<0)
	var key=SpotLight3D.new();add_child(key);key.position=Vector3(0,6.2,0);key.rotation_degrees=Vector3(-90,0,0);key.spot_range=9;key.spot_angle=45;key.light_energy=3.5;key.shadow_enabled=true
	for s in [-1,1]:
		var rim=SpotLight3D.new();add_child(rim);rim.position=Vector3(s*5,2.5,-4);rim.look_at_from_position(rim.position,Vector3(0,0.6,0));rim.spot_range=12;rim.spot_angle=35;rim.light_energy=2.0;rim.light_color=Color(1,0.85,0.7)
	# Schriftzug
	var lb=Label3D.new();lb.text="RADEBERG CUSTOMS";lb.font_size=180;lb.pixel_size=0.012;lb.modulate=Color(1,0.72,0.15);lb.outline_size=0;add_child(lb);lb.position=Vector3(0,5.2,-11.5)

func _load_car():
	if car:car.queue_free()
	car=VH.make(kinds[idx]);turntable.add_child(car)
	car.position.y=0.08
	cfg=T.default_cfg();base_stats=T.stats(car.get_meta("model"),cfg)
	_refresh()

func set_opt(k:String,v):
	cfg[k]=v;T.apply(car,cfg);_refresh()

func _process(d):
	if turntable and not OS.get_cmdline_user_args().has("--shots"):turntable.rotation.y+=d*0.25

# ---------------- Menü ----------------
func _style(c:Color,a:=0.82,r:=6)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=Color(c.r,c.g,c.b,a);s.corner_radius_top_left=r;s.corner_radius_top_right=r;s.corner_radius_bottom_left=r;s.corner_radius_bottom_right=r
	s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=8;s.content_margin_bottom=8;return s
func _btn(t:String,on:bool)->Button:
	var b=Button.new();b.text=t;b.add_theme_font_size_override("font_size",20)
	b.add_theme_stylebox_override("normal",_style(Color(1,0.68,0.12) if on else Color(0.08,0.08,0.1),0.95 if on else 0.8))
	b.add_theme_stylebox_override("hover",_style(Color(0.95,0.6,0.1),0.9));b.add_theme_stylebox_override("pressed",_style(Color(1,0.7,0.15),1))
	b.add_theme_color_override("font_color",Color(0.05,0.05,0.05) if on else Color(0.95,0.93,0.88))
	return b
func _ui():
	var cl=CanvasLayer.new();add_child(cl);ui=Control.new();ui.set_anchors_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;cl.add_child(ui)
	title=Label.new();title.add_theme_font_size_override("font_size",34);title.add_theme_color_override("font_color",Color(1,0.75,0.2));title.position=Vector3(24,14,0) if false else Vector2(24,14);ui.add_child(title)
	price_lbl=Label.new();price_lbl.add_theme_font_size_override("font_size",22);price_lbl.position=Vector2(24,58);price_lbl.add_theme_color_override("font_color",Color(0.6,1,0.6));ui.add_child(price_lbl)
	var sc=ScrollContainer.new();sc.position=Vector2(18,96);sc.size=Vector2(190,470);ui.add_child(sc)
	cat_box=VBoxContainer.new();cat_box.add_theme_constant_override("separation",5);sc.add_child(cat_box)
	var panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",_style(Color(0.04,0.04,0.05),0.78,8));panel.position=Vector2(860,96);panel.custom_minimum_size=Vector2(320,0);ui.add_child(panel)
	stat_box=VBoxContainer.new();stat_box.add_theme_constant_override("separation",6);panel.add_child(stat_box)
	var os=ScrollContainer.new();os.position=Vector2(230,590);os.size=Vector2(950,74);ui.add_child(os)
	opt_box=HBoxContainer.new();opt_box.add_theme_constant_override("separation",8);os.add_child(opt_box)
	var prev=_btn("◀ Auto",false);prev.position=Vector2(860,20);ui.add_child(prev);prev.pressed.connect(func():idx=(idx-1+kinds.size())%kinds.size();_load_car())
	var nxt=_btn("Auto ▶",false);nxt.position=Vector2(1040,20);ui.add_child(nxt);nxt.pressed.connect(func():idx=(idx+1)%kinds.size();_load_car())

func _lv(names:Array)->Array:
	var o=[]
	for i in names.size():o.append([names[i],i])
	return o
func _options()->Array:
	match cat:
		"Frontschürze","Heckschürze":return _lv(["Serie","Lippe","Sport","Race","Extrem"])
		"Seitenschweller":return _lv(["Serie","Street","Sport","Race","Extrem"])
		"Spoiler":return _lv(["Kein","Abrisskante","Street-Flügel","GT-Flügel","Big Wing","Drift-Flügel"])
		"Motorhaube":return _lv(["Serie","Lufthutze","Doppelhutze","Kiemen","Carbon"])
		"Dachhutze","Widebody":return _lv(["Nein","Ja"])
		"Felgen":
			var o=[["Serie",-1]]
			for i in R.DESIGNS.size():o.append([R.DESIGNS[i],i])
			return o
		"Felgengröße":
			var o2=[]
			for i in T.RIM_SIZE.size():o2.append([T.RIM_SIZE[i][0],i])
			return o2
		"Felgenfarbe":return ["Silber","Tiefschwarz","Weiß","Gold","Titan","Bronze","Signalrot","Rallye-Blau","Kupfer","Anthrazit","Champagner"].map(func(k):return [k,k])
		"Felgenlack","Lackart":return T.FINISH.map(func(k):return [k,k])
		"Bremssättel":return T.CALIPER.keys().map(func(k):return [k,k])
		"Lack":return [["Original",""]]+T.COLORS.keys().map(func(k):return [k,k])
		"Scheinwerfer":return T.XENON.keys().map(func(k):return [k,k])
		"Neon":return T.NEON.keys().map(func(k):return [k,k])
		"Scheiben":return _lv(["Klar","Leicht","Limo"])
		"Auspuff":return _lv(["Serie","Sport","Doppelrohr"])
		"Reifenqualm":return T.SMOKE.keys().map(func(k):return [k,k])
		"Aufladung":return _lv(["Sauger","Kompressor","Turbo","Biturbo"])
		"Reifen":return _lv(["Straße","Sport","Semi-Slick","Slick","Drift"])
		"NOS":return _lv(["Kein","2 Ladungen","4 Ladungen","6 Ladungen"])
		"Tieferlegung":return _lv(["Serie","-3 cm","-6 cm"])
	return _lv(T.LV)
func _key()->String:
	return KEYS.get(cat,"front")

func _refresh():
	title.text=VH.LIST[kinds[idx]][2].to_upper()
	for c in cat_box.get_children():c.queue_free()
	for c in CATS:
		if c=="OPTIK" or c=="LEISTUNG":
			var h=Label.new();h.text=c;h.add_theme_font_size_override("font_size",18);h.add_theme_color_override("font_color",Color(1,0.72,0.15));cat_box.add_child(h);continue
		var b=_btn(c,c==cat);b.custom_minimum_size=Vector2(170,0);cat_box.add_child(b);b.pressed.connect(func():cat=c;_refresh())
	for c in opt_box.get_children():c.queue_free()
	for o in _options():
		var b=_btn(o[0],cfg[_key()]==o[1]);opt_box.add_child(b);var v=o[1];var k=_key();b.pressed.connect(func():set_opt(k,v))
	var s=T.stats(car.get_meta("model"),cfg)
	for c in stat_box.get_children():c.queue_free()
	var h=Label.new();h.text="FAHRWERTE";h.add_theme_font_size_override("font_size",22);h.add_theme_color_override("font_color",Color(1,0.75,0.2));stat_box.add_child(h)
	_bar("Leistung",str(s.ps)+" PS",s.ps/1500.0,base_stats.ps/1500.0)
	_bar("Höchstgeschw.",str(s.top)+" km/h",s.top/420.0,base_stats.top/420.0)
	_bar("0-100 km/h",str(s.accel)+" s",1.0-s.accel/16.0,1.0-base_stats.accel/16.0)
	_bar("Grip",str(s.grip),(s.grip-0.7)/0.8,(base_stats.grip-0.7)/0.8)
	_bar("Handling",str(s.handling),(s.handling-0.7)/0.8,(base_stats.handling-0.7)/0.8)
	_bar("Bremsen",str(s.brake),(s.brake-0.7)/0.8,(base_stats.brake-0.7)/0.8)
	_bar("NOS",str(s.nos_shots)+" × +"+str(int(s.nos_boost*100))+" %",s.nos_shots/6.0,0.0)
	var info=Label.new();info.text="Antrieb: %s   Gewicht: %d kg"%[s.drive,s.mass];info.add_theme_font_size_override("font_size",16);stat_box.add_child(info)
	price_lbl.text="Kosten: %s €   ·   Konto: %s €"%[_fmt(T.price(cfg)),_fmt(money-T.price(cfg))]
func _fmt(n:int)->String:
	var s=str(abs(n));var o="";var c=0
	for i in range(s.length()-1,-1,-1):
		o=s[i]+o;c+=1
		if c%3==0 and i>0:o="."+o
	return ("-" if n<0 else "")+o
func _bar(name:String,val:String,f:float,f0:float):
	var row=VBoxContainer.new();row.add_theme_constant_override("separation",2);stat_box.add_child(row)
	var l=Label.new();l.text=name+":  "+val;l.add_theme_font_size_override("font_size",17);row.add_child(l)
	var bg=ColorRect.new();bg.color=Color(0.2,0.2,0.22);bg.custom_minimum_size=Vector2(290,10);row.add_child(bg)
	var base=ColorRect.new();base.color=Color(0.85,0.85,0.85);base.size=Vector2(290*clamp(f0,0,1),10);bg.add_child(base)
	if f>f0+0.001:
		var up=ColorRect.new();up.color=Color(0.3,0.95,0.35);up.position=Vector2(290*clamp(f0,0,1),0);up.size=Vector2(290*clamp(f-f0,0,1-clamp(f0,0,1)),10);bg.add_child(up)

# ---------------- Testbilder ----------------
func _shots():
	var full={"front":4,"side":4,"rear":4,"spoiler":4,"hood":1,"widebody":1,"paint":"Racing-Gelb","finish":"Perleffekt","rim":4,"rim_size":4,"rim_color":"Tiefschwarz","rim_finish":"Satin","caliper":"Rot","lights":"Xenon Blau","neon":"Blau","tint":2,"exhaust":2,"intake":3,"cam":3,"headers":3,"ecu":3,"fuel":3,"boost":3,"nos":3,"tires":3,"springs":3,"dampers":3,"sway":3,"brakes":3,"weight":2}
	var plan=[
		["jdm",{},"Frontschürze",Vector3(4.6,1.3,4.6)],
		["jdm",{"front":1,"side":1,"spoiler":1,"rim":-1,"neon":"Türkis","lights":"Xenon Blau"},"Frontschürze",Vector3(4.6,1.3,4.6)],
		["jdm",{"front":1,"side":1,"spoiler":1,"paint":"Racing-Gelb","finish":"Perleffekt","neon":"Blau"},"Spoiler",Vector3(-4.4,1.5,-4.6)],
		["supra",{"spoiler":4,"paint":"Racing-Gelb","finish":"Perleffekt","neon":"Blau","lights":"Xenon Blau","tint":2},"Spoiler",Vector3(-4.4,1.6,-4.6)],
		["audi_r8",{"spoiler":3,"paint":"Lila","finish":"Perleffekt","rim":0,"rim_size":4,"rim_color":"Silber","rim_finish":"Chrom","caliper":"Gelb","neon":"Lila"},"Felgen",Vector3(4.2,1.0,3.0)],
		["porsche911",{"spoiler":3,"paint":"Signalrot","finish":"Glanz","neon":"Rot"},"Spoiler",Vector3(-4.6,1.4,-4.2)],
		["bmw_m8",{"paint":"Nachtblau","finish":"Matt","tint":2,"lights":"Xenon Weiß","neon":"Weiß"},"Lackart",Vector3(5.2,1.3,4.4)],
	]
	await get_tree().process_frame
	var cam:Camera3D=get_viewport().get_camera_3d()
	for i in plan.size():
		var p=plan[i];idx=kinds.find(p[0]);_load_car()
		var c=T.default_cfg();for k in p[1]:c[k]=p[1][k]
		cfg=c;cat=p[2];T.apply(car,cfg)
		if p[0]=="trabant":T.nos_flame(car,true)
		_refresh()
		cam.position=p[3];cam.look_at(Vector3(0,0.5,0) if p[3].y>0.9 else Vector3(1.0,0.35,1.4))
		for f in 10:await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/garage_%d.png"%i)
	get_tree().quit()
