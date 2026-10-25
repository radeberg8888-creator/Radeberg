extends RefCounted
# Tuning wie in Need for Speed Underground 2:
#  OPTIK: Frontschürze, Seitenschweller, Heckschürze, Spoiler, Motorhaube, Dachhutze, Kotflügel (Widebody),
#         Felgen (8 Designs, 5 Größen, Farbe, Lackart), Bremssättel, Lack (30 Farben, 6 Lackarten),
#         Scheinwerfer (Xenon-Farbe), Unterbodenneon, Scheibentönung, Reifenqualm-Farbe, Auspuffblende
#  LEISTUNG: Ansaugung, Nockenwelle, Krümmer/Auspuff, Steuergerät, Kraftstoffsystem, Aufladung (Kompressor/Turbo/Biturbo),
#         Kupplung, Getriebe, Differenzial, Federn, Dämpfer, Stabilisatoren, Bremsen, Reifenmischung, NOS, Gewichtsreduktion
const F=preload("res://scripts/fit.gd")
const K=preload("res://scripts/kitgen.gd")
const R=preload("res://scripts/rimgen.gd")
const D=preload("res://scripts/deform.gd")

const PAINT={
	"audi_r8":["body"],"audi_rs7":["Car_Paint.001","Car_Paint"],"bmw_m8":["BMW_M8RewardRecycled_2020Paint_Material"],
	"porsche911":["paint","coat"],"bugatti":["Bugatti_EB110SS_By_Alex_Ka"],"hoonicorn":["Body_Paint"],"f100":["Paint"],"supra":["Paint"],
	"mercedes":["Body"],"firetruck":["carpaint_second"],"trabant":["trabik"],"police_ford":["material_5"],"hudson":["Body"],"bmw_e30":["wire_184228153"],
	"small_car":["Material"],"jdm":["Livery"],"bus":[],"ambulance":[],"armored":[],"container_truck":[],"dodge":[],"cartrailer":[]}
# Autos mit echten, separat modellierten Tuningteilen: Option -> Knotennamen-Präfixe
const REAL_PARTS={"jdm":{"front":["Front Spoiler"],"side":["Skirts"],"spoiler":["Spoiler"]}}
# Autos mit separaten Rädern (dort lassen sich Felgen sauber tauschen)
const RIM_OK=["audi_r8","small_car"]
const NO_KIT=["bus","dodge","ambulance","armored","container_truck","cartrailer","firetruck"]   # Lizenz/Nutzfahrzeug
const BASE={
	"trabant":[19,615,112,"FWD"],"bmw_e30":[85,1150,195,"RWD"],"small_car":[55,980,165,"FWD"],"hudson":[108,1600,170,"RWD"],
	"dodge":[75,1500,140,"RWD"],"audi_rs7":[441,2075,305,"AWD"],"bmw_m8":[460,1885,305,"AWD"],"audi_r8":[449,1595,330,"AWD"],
	"porsche911":[331,1565,306,"AWD"],"bugatti":[449,1418,351,"AWD"],"hoonicorn":[1044,1406,320,"AWD"],"police_ford":[227,2100,210,"AWD"],
	"supra":[250,1500,270,"RWD"],"f100":[110,1700,160,"RWD"],"mercedes":[150,1400,220,"RWD"],"firetruck":[260,16000,110,"RWD"],
	"ambulance":[120,3800,150,"RWD"],"armored":[220,7000,140,"RWD"],"container_truck":[350,18000,100,"RWD"],"jdm":[300,1250,265,"RWD"],"bus":[180,9500,90,"RWD"]}

const FINISH=["Glanz","Metallic","Perleffekt","Matt","Satin","Chrom"]
const COLORS={
	"Tiefschwarz":Color(0.015,0.015,0.02),"Weiß":Color(0.93,0.93,0.91),"Perlweiß":Color(0.96,0.94,0.88),"Silber":Color(0.62,0.63,0.65),"Titan":Color(0.36,0.37,0.39),"Anthrazit":Color(0.12,0.13,0.14),
	"Signalrot":Color(0.65,0.02,0.02),"Kirschrot":Color(0.38,0.01,0.04),"Candy-Rot":Color(0.55,0.0,0.06),"Orange":Color(0.95,0.32,0.02),"Kupfer":Color(0.55,0.24,0.1),"Bronze":Color(0.45,0.3,0.15),
	"Racing-Gelb":Color(0.95,0.72,0.02),"Zitrone":Color(0.85,0.85,0.1),"Limette":Color(0.45,0.85,0.05),"Grün":Color(0.03,0.35,0.12),"British Green":Color(0.02,0.16,0.08),"Petrol":Color(0.02,0.3,0.32),
	"Türkis":Color(0.0,0.6,0.62),"Babyblau":Color(0.42,0.66,0.92),"Rallye-Blau":Color(0.03,0.2,0.72),"Nachtblau":Color(0.02,0.05,0.2),"Violett":Color(0.3,0.05,0.45),"Lila":Color(0.55,0.2,0.75),
	"Pink":Color(0.92,0.22,0.52),"Rosé":Color(0.85,0.55,0.6),"Gold":Color(0.78,0.58,0.2),"Champagner":Color(0.75,0.68,0.52),"Sand":Color(0.68,0.6,0.45),"Oliv":Color(0.28,0.3,0.16)}
const NEON={"Aus":Color(0,0,0),"Blau":Color(0.1,0.3,1.0),"Rot":Color(1,0.05,0.05),"Grün":Color(0.1,1,0.2),"Lila":Color(0.7,0.1,1),"Weiß":Color(1,1,1),"Orange":Color(1,0.45,0.05),"Pink":Color(1,0.2,0.7),"Türkis":Color(0.1,0.9,0.9),"Gelb":Color(1,0.85,0.1)}
const XENON={"Serie":Color(1,0.92,0.75),"Xenon Weiß":Color(0.92,0.95,1),"Xenon Blau":Color(0.55,0.7,1),"Gelb":Color(1,0.8,0.25),"Violett":Color(0.75,0.5,1),"Grün":Color(0.5,1,0.6)}
const SMOKE={"Weiß":Color(0.9,0.9,0.9),"Schwarz":Color(0.1,0.1,0.1),"Rot":Color(0.9,0.15,0.1),"Blau":Color(0.2,0.4,1),"Grün":Color(0.2,0.9,0.3),"Gelb":Color(0.95,0.85,0.2),"Lila":Color(0.6,0.2,0.9),"Pink":Color(0.95,0.4,0.7)}
const RIM_SIZE=[["Serie",0.0],["17 Zoll",0.6],["18 Zoll",0.66],["19 Zoll",0.71],["20 Zoll",0.76],["21 Zoll",0.8]]
const CALIPER={"Serie":Color(0.15,0.15,0.16),"Rot":Color(0.75,0.05,0.04),"Gelb":Color(0.95,0.75,0.05),"Blau":Color(0.1,0.25,0.75),"Grün":Color(0.1,0.6,0.2),"Orange":Color(0.95,0.4,0.05)}
const LV=["Serie","Street","Pro","Extrem"]

static func default_cfg()->Dictionary:
	return {"front":0,"side":0,"rear":0,"spoiler":0,"hood":0,"roofscoop":0,"widebody":0,
		"paint":"","finish":"Metallic","rim":-1,"rim_size":0,"rim_color":"Silber","rim_finish":"Metallic","caliper":"Serie",
		"lights":"Serie","neon":"Aus","tint":0,"smoke":"Weiß","exhaust":0,
		"intake":0,"cam":0,"headers":0,"ecu":0,"fuel":0,"boost":0,"clutch":0,"gearbox":0,"diff":0,
		"springs":0,"dampers":0,"sway":0,"brakes":0,"tires":0,"nos":0,"weight":0,"lowering":0}

# ---------------- Fahrwerte ----------------
static func stats(model:String,c:Dictionary)->Dictionary:
	var b=BASE.get(model,[100,1400,200,"RWD"])
	var engine=1.0+0.03*c.intake+0.04*c.cam+0.035*c.headers+0.04*c.ecu+0.025*c.fuel+0.012*c.exhaust
	var forced=[1.0,1.18,1.3,1.48][c.boost]
	var p=float(b[0])*engine*forced
	var m=float(b[1])*(1.0-0.035*c.weight)
	var aero=0.015*c.spoiler+0.008*(c.front+c.rear)
	var top=float(b[2])*(1.0+0.6*(pow(p/float(b[0]),1.0/3.0)-1.0))*(1.0-0.004*c.spoiler)*(1.0+0.01*c.gearbox)
	var grip=1.0+[0.0,0.06,0.12,0.2,0.1][c.tires]+0.03*(c.springs+c.dampers)+0.02*c.sway+aero+0.015*c.lowering+(0.05 if c.widebody>0 else 0.0)
	var pw=p/m*1000.0
	var accel=clamp(2.0+42.0/pow(max(pw,5.0),0.78)*(1.0/grip)*(0.9 if b[3]=="AWD" else 1.0)*(1.0-0.03*c.clutch-0.02*c.gearbox-0.02*c.diff),1.8,40.0)
	return {"kw":round(p),"ps":round(p*1.36),"mass":round(m),"top":round(top),"accel":snapped(accel,0.1),"grip":snapped(grip,0.01),
		"handling":snapped(1.0+0.05*(c.springs+c.dampers+c.sway)+0.04*c.diff+0.03*c.lowering,0.01),"brake":snapped(1.0+0.1*c.brakes+0.03*c.tires,0.01),
		"nos_shots":[0,2,4,6][c.nos],"nos_boost":[0.0,0.25,0.35,0.5][c.nos],"drive":b[3],"drift":c.tires==4}

static func price(c:Dictionary)->int:
	var t=0
	for k in ["front","side","rear"]:t+=[0,1800,3200,5200,8500][c[k]]
	t+=[0,1500,2800,5500,9000,7000][c.spoiler]+[0,1200,1800,1400,4500][c.hood]+[0,900][c.roofscoop]+[0,12000][c.widebody]
	t+=(1500+[600,900,1500,2400,1800,6000][FINISH.find(c.finish)]) if c.paint!="" else 0
	t+=([0,1800,2400,3200,4200,5500][c.rim_size]+1500) if c.rim>=0 else 0
	t+=0 if c.caliper=="Serie" else 600
	t+=0 if c.lights=="Serie" else 900
	t+=(800 if c.neon!="Aus" else 0)+[0,400,700][c.tint]+[0,1500,3500][c.exhaust]
	for k in ["intake","cam","headers","ecu","fuel","clutch","gearbox","diff","springs","dampers","sway","brakes","weight"]:t+=[0,1500,4000,8000][c[k]]
	t+=[0,9000,14000,26000][c.boost]+[0,1200,2800,4800,3500][c.tires]+[0,3000,6000,10000][c.nos]+[0,1500,3000][c.lowering]
	return t

# ---------------- Materialien ----------------
static func paint_mat(base:BaseMaterial3D,c:Color,finish:String)->StandardMaterial3D:
	var d:StandardMaterial3D=base.duplicate() if base else StandardMaterial3D.new()
	var textured=d.albedo_texture!=null
	d.albedo_color=(c*Color(1.6,1.6,1.6)).clamp() if textured else c
	d.cull_mode=BaseMaterial3D.CULL_DISABLED
	match finish:
		"Glanz":d.metallic=0.0;d.roughness=0.16;d.clearcoat_enabled=true;d.clearcoat=1.0;d.clearcoat_roughness=0.03
		"Metallic":d.metallic=0.72;d.roughness=0.3;d.clearcoat_enabled=true;d.clearcoat=1.0;d.clearcoat_roughness=0.04
		"Perleffekt":d.metallic=0.55;d.roughness=0.22;d.clearcoat_enabled=true;d.clearcoat=1.0;d.rim_enabled=true;d.rim=0.7;d.rim_tint=0.9
		"Matt":d.metallic=0.1;d.roughness=0.78;d.clearcoat_enabled=false
		"Satin":d.metallic=0.4;d.roughness=0.48;d.clearcoat_enabled=true;d.clearcoat=0.4;d.clearcoat_roughness=0.3
		"Chrom":d.metallic=1.0;d.roughness=0.1;d.albedo_color=c.lerp(Color(1,1,1),0.35)*1.3;d.clearcoat_enabled=false;d.rim_enabled=true;d.rim=0.5
	return d

static func _mat(c:Color,rough:float,metal:float)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=rough;m.metallic=metal;m.cull_mode=BaseMaterial3D.CULL_DISABLED;return m

# ---------------- Optik anwenden ----------------
static func apply(car:Node3D,c:Dictionary):
	var model:String=car.get_meta("model","")
	for ch in car.get_children():
		if ch.has_meta("tuning_part"):car.remove_child(ch);ch.queue_free()
	var paints:Array=PAINT.get(model,[])
	var body_paint:StandardMaterial3D=null
	for m in car.find_children("*","MeshInstance3D",true,false):
		for i in m.mesh.get_surface_count():
			var mt=m.mesh.surface_get_material(i)
			if not (mt is BaseMaterial3D):continue
			var nm:String=mt.resource_name;var low=nm.to_lower()
			m.set_surface_override_material(i,null)
			if c.paint!="" and nm in paints:
				var pm=paint_mat(mt,COLORS[c.paint],c.finish);m.set_surface_override_material(i,pm)
			elif c.tint>0 and (low.contains("glass") or low.contains("window")) and not low.contains("light"):
				var g:StandardMaterial3D=mt.duplicate();g.albedo_color=Color(0.02,0.02,0.025,[1.0,0.72,0.92][c.tint]);g.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;g.roughness=0.05;g.metallic=0.3
				m.set_surface_override_material(i,g)
			elif c.lights!="Serie" and (low.contains("head") or low.contains("hlight") or low=="lights" or low.contains("white_glass") or low.contains("lamp")) and not (low.contains("red") or low.contains("brake") or low.contains("tail") or low.contains("rear")):
				var l:StandardMaterial3D=mt.duplicate();l.emission_enabled=true;l.emission=XENON[c.lights];l.emission_energy_multiplier=4.0;m.set_surface_override_material(i,l)
			elif c.rim>=0 and model in RIM_OK and _is_rim(low,model):
				m.set_surface_override_material(i,_invisible())   # Originalfelge ausblenden, neue Felge sitzt exakt an ihrer Stelle
	if c.paint!="" :body_paint=paint_mat(null,COLORS[c.paint],c.finish)
	else:body_paint=paint_mat(null,_guess_body_color(car,paints),"Metallic")
	var carbon=_mat(Color(0.03,0.03,0.035),0.22,0.35);carbon.clearcoat_enabled=true;carbon.clearcoat=1.0;carbon.clearcoat_roughness=0.02
	var dark=_mat(Color(0.01,0.01,0.012),0.9,0.0)
	var f:float=car.get_meta("front",1.0)
	var kit=Node3D.new();kit.name="Kit";kit.set_meta("tuning_part",true);car.add_child(kit)
	if f<0:kit.rotation.y=PI
	var S=K.measure(car)
	D.restore(car)
	# Echte Bodykit-Teile, die im Modell als eigene Bauteile vorhanden sind (sauber, passgenau)
	var real=REAL_PARTS.get(model,{})
	for m in car.find_children("*","MeshInstance3D",true,false):
		var n=str(m.name)
		for key in real:
			for prefix in real[key]:
				if n.begins_with(prefix):m.visible=c[key]>0
	var wheels_node=Node3D.new();wheels_node.name="Raeder";wheels_node.set_meta("tuning_part",true);car.add_child(wheels_node)
	if f<0:wheels_node.rotation.y=PI
	# Heckflügel nur bei Autos ohne eigenen Flügel; Schürzen/Haube nur als echte Modellteile (keine aufgesetzten Platzhalter)
	if not model in NO_KIT and not real.has("spoiler") and c.spoiler>=2:
		K.spoiler(kit,S,c.spoiler,body_paint,carbon)
	# Felgen + Bremssättel
	if c.rim>=0 and model in RIM_OK:
		var rm=R.make(c.rim);var rmat=paint_mat(null,COLORS.get(c.rim_color,Color(0.6,0.6,0.62)),c.rim_finish)
		for w in _measure_rims(car,model):
			var ctr:Vector3=w[0];var r:float=w[1];var s=sign(ctr.x);var depth:float=w[3]
			var holder=Node3D.new();wheels_node.add_child(holder)
			holder.transform=Transform3D(Basis() if s>0 else Basis(Vector3.UP,PI),Vector3(w[2]-s*0.004,ctr.y,ctr.z))
			var a=MeshInstance3D.new();a.mesh=rm[0];a.material_override=rmat;holder.add_child(a);a.scale=Vector3(depth/0.48,r/1.02,r/1.02)
			var b=MeshInstance3D.new();b.mesh=rm[1];b.material_override=dark;holder.add_child(b);b.scale=a.scale
			# Bremssattel hinter den Speichen
			var cal=MeshInstance3D.new();cal.mesh=BoxMesh.new();cal.mesh.size=Vector3(0.06,r*0.5,r*0.28);holder.add_child(cal)
			cal.position=Vector3(-depth*0.55,r*0.52,-r*0.28);cal.rotation.x=-0.55;cal.material_override=_mat(CALIPER[c.caliper],0.35,0.2)
	# Unterbodenneon
	if c.neon!="Aus":
		var col:Color=NEON[c.neon];var glow=_mat(col,0.4,0.0);glow.emission_enabled=true;glow.emission=col;glow.emission_energy_multiplier=6.0
		for s in [-1,1]:K._box(kit,Vector3(0.035,0.025,S.L*0.55),Vector3(s*S.W*0.38,0.1,S.cz),glow)
		for zz in [S.cz-S.L*0.28,S.cz,S.cz+S.L*0.28]:
			var l=OmniLight3D.new();kit.add_child(l);l.position=Vector3(0,0.1,zz);l.light_color=col;l.light_energy=2.4;l.omni_range=2.6;l.omni_attenuation=1.5
	# Auspuffblenden
	if c.exhaust>0:
		var chrome=_mat(Color(0.88,0.88,0.9),0.07,1.0)
		for s in ([-1,1] if c.exhaust>=2 else [1]):
			var t=MeshInstance3D.new();t.mesh=CylinderMesh.new();t.mesh.top_radius=0.05+0.018*c.exhaust;t.mesh.bottom_radius=t.mesh.top_radius;t.mesh.height=0.18
			kit.add_child(t);t.rotation.x=PI*0.5;t.position=Vector3(s*S.W*0.3,max(S.yb_r,0.2)+0.05,S.zr[S.xi(s*S.W*0.3)]-0.02);t.material_override=chrome
			var ins=MeshInstance3D.new();ins.mesh=CylinderMesh.new();ins.mesh.top_radius=t.mesh.top_radius*0.8;ins.mesh.bottom_radius=ins.mesh.top_radius;ins.mesh.height=0.181
			kit.add_child(ins);ins.rotation.x=PI*0.5;ins.position=t.position;ins.material_override=dark
	car.set_meta("tuning",c.duplicate())

static func _is_rim(low:String,model:String)->bool:
	if model=="small_car":return low.contains("disk")
	return low.contains("rim") or low.contains("caliper")

static func _invisible()->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.albedo_color=Color(0,0,0,0);m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;return m

# Originalfelgen vermessen: je Rad Mitte, Radius, Außenkante (x), Tiefe — im Fahrzeugrahmen (Front +Z)
static func _measure_rims(car:Node3D,model:String)->Array:
	var f:float=car.get_meta("front",1.0);var rot=Basis() if f>0 else Basis(Vector3.UP,PI)
	var pts=PackedVector3Array()
	for m in car.find_children("*","MeshInstance3D",true,false):
		if m.has_meta("tuning_part"):continue
		var xf=Transform3D(rot,Vector3())*F.rel_xf(m,car)
		for i in m.mesh.get_surface_count():
			var mt=m.mesh.surface_get_material(i);var low=(mt.resource_name if mt else "").to_lower()
			if not _is_rim(low,model) or low.contains("caliper"):continue
			var v:PackedVector3Array=m.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			for k in range(0,v.size(),max(1,v.size()/3000)):pts.append(xf*v[k])
	var cz=0.0;for p in pts:cz+=p.z
	cz/=max(pts.size(),1)
	var q={}
	for p in pts:
		var k=Vector2i(1 if p.x>0 else -1,1 if p.z>cz else -1)
		if not q.has(k):q[k]=[Vector3(INF,INF,INF),-Vector3(INF,INF,INF)]
		q[k][0]=q[k][0].min(p);q[k][1]=q[k][1].max(p)
	var out=[]
	for k in q:
		var a:Vector3=q[k][0];var b:Vector3=q[k][1]
		var r=max(b.y-a.y,b.z-a.z)*0.5
		out.append([Vector3((a.x+b.x)*0.5,(a.y+b.y)*0.5,(a.z+b.z)*0.5),r,b.x if k.x>0 else a.x,clamp(b.x-a.x,0.12,0.3)])
	return out

static func _guess_body_color(car:Node3D,paints:Array)->Color:
	for m in car.find_children("*","MeshInstance3D",true,false):
		for i in m.mesh.get_surface_count():
			var mt=m.mesh.surface_get_material(i)
			if mt is BaseMaterial3D and mt.resource_name in paints:
				var c:Color=mt.albedo_color
				if mt.albedo_texture:
					var img:Image=mt.albedo_texture.get_image()
					if img:
						if img.is_compressed():img=img.duplicate();img.decompress()
						img=img.duplicate();img.resize(8,8);var acc=Color(0,0,0);for y in 8:
							for x in 8:acc+=img.get_pixel(x,y)
						c=c*(acc/64.0)
				return c
	return Color(0.3,0.3,0.32)

# NOS-Flammen aus den Endrohren (beim Zünden)
static func nos_flame(car:Node3D,on:bool):
	for ch in car.get_children():
		if ch.has_meta("nos_fx"):car.remove_child(ch);ch.queue_free()
	if not on:return
	var S=K.measure(car);var f:float=car.get_meta("front",1.0)
	var fx=Node3D.new();fx.set_meta("nos_fx",true);car.add_child(fx);if f<0:fx.rotation.y=PI
	var fl=StandardMaterial3D.new();fl.albedo_color=Color(0.3,0.5,1,0.85);fl.emission_enabled=true;fl.emission=Color(0.35,0.55,1.0);fl.emission_energy_multiplier=10;fl.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;fl.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for s in [-1,1]:
		var cone=MeshInstance3D.new();cone.mesh=CylinderMesh.new();cone.mesh.top_radius=0.0;cone.mesh.bottom_radius=0.08;cone.mesh.height=0.7
		fx.add_child(cone);cone.rotation.x=PI*0.5;cone.position=Vector3(s*S.W*0.3,max(S.yb_r,0.2)+0.05,S.zr[S.xi(s*S.W*0.3)]-0.38);cone.material_override=fl
		var l=OmniLight3D.new();fx.add_child(l);l.position=cone.position;l.light_color=Color(0.4,0.6,1);l.light_energy=3;l.omni_range=3
