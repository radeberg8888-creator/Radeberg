extends RefCounted
# Fahrzeug-Bibliothek: alle Modelle + abgeleitete Varianten (Taxi, Polizei, Feuerwehr, RTW, LKW ...)
# make(kind) liefert einen Node3D: Boden auf y=0, Fahrzeugmitte im Ursprung, Fahrtrichtung +Z
const F=preload("res://scripts/fit.gd")
const V="res://assets/vehicles/"

# kind: [Modell, Länge in m, Front-Richtung im Modell (nach Einpassen), Beschreibung]
const LIST={
	"trabant":["trabant",3.55,"Trabant 601"],
	"bmw_e30":["bmw_e30",4.33,"BMW E30 (verlassen)"],
	"small_car":["small_car",3.6,"Kleinwagen"],
	"hudson":["hudson",5.3,"Hudson Hornet (Wrack)"],
	"dodge":["dodge",4.9,"Dodge Pickup 1953"],
	"audi_rs7":["audi_rs7",5.01,"Audi RS7"],
	"bmw_m8":["bmw_m8",4.87,"BMW M8"],
	"audi_r8":["audi_r8",4.43,"Audi R8"],
	"porsche911":["porsche911",4.52,"Porsche 911"],
	"bugatti":["bugatti",4.4,"Bugatti EB110"],
	"hoonicorn":["hoonicorn",4.6,"Mustang Hoonicorn"],
	"police_ford":["police_ford",5.4,"Streifenwagen (US)"],
	"polizei":["police_ford",5.4,"Polizei Sachsen"],
	"taxi":["police_ford",5.4,"Taxi"],
	"armored":["armored",6.2,"Geldtransporter"],
	"rtw_alt":["armored",6.2,"Rettungswagen (Umbau)"],
	"rtw":["ambulance",6.9,"Rettungswagen"],
	"feuerwehr":["firetruck",10.2,"Feuerwehr Drehleiter"],
	"mercedes":["mercedes",4.7,"Mercedes"],
	"supra":["supra",4.38,"Supra Breitbau"],
	"f100":["f100",4.9,"Ford F100"],
	"jdm":["jdm",4.45,"JDM Drift-Coupé"],
	"bus":["bus",11.0,"Linienbus"],
	"autotransporter":["cartrailer",13.6,"Autotransporter-Auflieger"],
	"lkw":["container_truck",16.5,"Sattelzug"],
	"lkw_blau":["container_truck",16.5,"Sattelzug blau"],
	"feuerwehr_alt":["container_truck",16.5,"Feuerwehr (Umbau)"],
}
static var _front:={}   # Modell -> Vorzeichen der Längsachse (falls Modell rückwärts liegt)
const FLIP={"trabant":false}
# Fahrzeugfront nach dem Einpassen: +1 = +Z, -1 = -Z (per Testbild ermittelt)
const FRONT={"armored":-1.0,"bmw_m8":-1.0,"hoonicorn":-1.0,"mercedes":-1.0,"container_truck":-1.0}

static func _flat(c:Color,rough:=0.5,metal:=0.0)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=rough;m.metallic=metal;return m
static func _glow(c:Color,e:=3.0)->StandardMaterial3D:
	var m=_flat(c,0.3);m.emission_enabled=true;m.emission=c;m.emission_energy_multiplier=e;return m

static func hide_planes(n:Node3D):
	var tot=F.aabb(n);var mx=max(tot.size.x,tot.size.z)
	for m in n.find_children("*","MeshInstance3D",true,false):
		var a=F.rel_xf(m,n)*m.get_aabb()
		var nm=(m.name+" "+_matname(m)).to_lower()
		if (a.size.y<0.02*mx and max(a.size.x,a.size.z)>0.6*mx) or nm.contains("ground") or nm.contains("carshadow") or nm.ends_with(" floor") or nm.contains("ground"):m.visible=false

static func _matname(m:MeshInstance3D,i:=0)->String:
	if m.mesh==null or m.mesh.get_surface_count()<=i:return ""
	var mt=m.get_active_material(i);return mt.resource_name if mt else ""

# Materialien nach Namen umfärben/ersetzen
static func _each_mat(n:Node3D,f:Callable):
	for m in n.find_children("*","MeshInstance3D",true,false):
		for i in m.mesh.get_surface_count():
			var mt=m.get_active_material(i)
			if mt is BaseMaterial3D:
				var r=f.call(m,mt,mt.resource_name)
				if r!=null:m.set_surface_override_material(i,r)

static func make(kind:String)->Node3D:
	var e=LIST[kind];var model:String=e[0]
	var n:Node3D=load(V+model+"/"+model+".gltf").instantiate()
	hide_planes(n)
	# Längsachse bestimmen und auf Z legen
	var ab=F.aabb(n);var axis=2 if ab.size.z>=ab.size.x else 0
	var w=F.place(n,e[1],axis)
	var root=Node3D.new();root.name=kind;root.add_child(w)
	root.set_meta("model",model);root.set_meta("kind",kind);root.set_meta("front",FRONT.get(model,1.0))
	if axis==0:w.rotation.y=PI*0.5
	_ground(root,model)
	match kind:
		"taxi","polizei":
			var body=load(V+"police_ford/"+("taxi" if kind=="taxi" else "polizei")+"_body.jpg");var dec=load(V+"police_ford/"+("taxi" if kind=="taxi" else "polizei")+"_decal.jpg")
			_each_mat(n,func(m,mt,nm):
				var d=null
				if nm=="Body":
					d=mt.duplicate();d.albedo_texture=body
				elif nm=="Car_white":
					d=mt.duplicate();d.albedo_texture=dec
				elif nm=="material_5":
					d=mt.duplicate();d.albedo_color=Color(0.86,0.8,0.62) if kind=="taxi" else Color(0.05,0.16,0.48);d.metallic=0.6;d.roughness=0.3
					d.clearcoat_enabled=true;d.clearcoat=1.0
				elif kind=="taxi" and (nm.begins_with("blue_light") or nm.begins_with("Red_Glass") or nm.begins_with("white_glass")):
					m.visible=false
				return d)
			if kind=="taxi":
				var top=F.aabb(root)
				var sign=MeshInstance3D.new();sign.mesh=BoxMesh.new();sign.mesh.size=Vector3(0.62,0.2,0.16);root.add_child(sign)
				sign.position=Vector3(0,top.end.y+0.08,-0.2);sign.material_override=_glow(Color(1.0,0.86,0.35),1.6)
				for s in [-1,1]:
					var lb=Label3D.new();lb.text="TAXI";lb.font_size=64;lb.pixel_size=0.0028;lb.modulate=Color(0.08,0.08,0.08);lb.outline_size=0;root.add_child(lb)
					lb.position=sign.position+Vector3(0,0,s*0.085);lb.rotation.y=0.0 if s>0 else PI
		"rtw_alt":
			_each_mat(n,func(m,mt,nm):
				var d=null
				if nm.contains("Decals"):
					m.visible=false
				elif nm.contains("ExteriorTrim") or nm.contains("ExteriorDetails") or nm.contains("MetalPaint"):
					d=mt.duplicate();d.albedo_color=Color(1.6,1.6,1.55);d.roughness=0.35
				return d)
			_lightbar(root,Color(0.15,0.35,1.0))
			_stripe(root,Color(0.95,0.35,0.05),"RETTUNGSDIENST")
		"feuerwehr_alt":
			_each_mat(n,func(m,mt,nm):
				var d=null
				if mt.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and nm!="Part1Mtl":
					d=mt.duplicate();d.albedo_color=mt.albedo_color*Color(0.9,0.12,0.1)
				return d)
			_firetruck(root,n)
		"lkw_blau":
			_each_mat(n,func(m,mt,nm):
				var d=null
				if nm=="Semitrailer1Mtl" or nm=="Color1Mtl":
					d=mt.duplicate();d.albedo_color=mt.albedo_color*Color(0.25,0.45,0.85)
				return d)
	return root

# Blaulichtbalken auf dem Dach (vorderer Fahrzeugteil)
static func _lightbar(root:Node3D,c:Color):
	var ab=F.aabb(root);var z=ab.end.z-ab.size.z*0.18
	var y=_roof_y(root,z)
	var bar=MeshInstance3D.new();bar.mesh=BoxMesh.new();bar.mesh.size=Vector3(1.3,0.12,0.28);root.add_child(bar);bar.position=Vector3(0,y+0.06,z);bar.material_override=_flat(Color(0.1,0.1,0.11),0.4,0.5)
	for s in [-1,1]:
		var l=MeshInstance3D.new();l.mesh=BoxMesh.new();l.mesh.size=Vector3(0.5,0.1,0.24);root.add_child(l);l.position=Vector3(s*0.36,y+0.15,z);l.material_override=_glow(c,4.0)
		var ol=OmniLight3D.new();root.add_child(ol);ol.position=l.position+Vector3(0,0.2,0);ol.light_color=c;ol.light_energy=1.2;ol.omni_range=5

static func _roof_y(root:Node3D,z:float)->float:
	var best=0.0
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible:continue
		var a=F.rel_xf(m,root)*m.get_aabb()
		if a.position.z<=z and a.end.z>=z and a.size.x>1.0:best=max(best,a.end.y)
	return best

# Drehleiter auf dem Aufbau
static func _ladder(root:Node3D):
	var ab=F.aabb(root);var len=ab.size.z*0.62;var y=ab.end.y+0.05
	var met=_flat(Color(0.82,0.82,0.84),0.3,0.9)
	var base=MeshInstance3D.new();base.mesh=CylinderMesh.new();base.mesh.top_radius=0.6;base.mesh.bottom_radius=0.7;base.mesh.height=0.35;root.add_child(base)
	base.position=Vector3(0,y+0.17,ab.position.z+ab.size.z*0.25);base.material_override=_flat(Color(0.75,0.1,0.08),0.4,0.4)
	var z0=ab.position.z+ab.size.z*0.2;var z1=z0+len
	for s in [-1,1]:
		var rail=MeshInstance3D.new();rail.mesh=BoxMesh.new();rail.mesh.size=Vector3(0.08,0.14,len);root.add_child(rail);rail.position=Vector3(s*0.42,y+0.45,(z0+z1)*0.5);rail.material_override=met
	var k=z0+0.2
	while k<z1:
		var rung=MeshInstance3D.new();rung.mesh=BoxMesh.new();rung.mesh.size=Vector3(0.84,0.04,0.04);root.add_child(rung);rung.position=Vector3(0,y+0.45,k);rung.material_override=met;k+=0.35

static func _stripe(root:Node3D,c:Color,text:String):
	var ab=F.aabb(root)
	for s in [-1,1]:
		var lb=Label3D.new();lb.text=text;lb.font_size=96;lb.pixel_size=0.0045;lb.modulate=c;lb.outline_size=6;lb.outline_modulate=Color(0,0,0,0.6);root.add_child(lb)
		lb.position=Vector3(s*(ab.end.x+0.01),ab.position.y+ab.size.y*0.45,ab.get_center().z-ab.size.z*0.1);lb.rotation.y=PI*0.5*s

static func _firetruck(root:Node3D,n:Node3D):
	var tot=F.aabb(root);var tr:AABB;var found=false
	for m in root.find_children("*","MeshInstance3D",true,false):
		if _matname(m)=="Semitrailer1Mtl":
			var a=F.rel_xf(m,root)*m.get_aabb()
			if not found:tr=a;found=true
			else:tr=tr.merge(a)
	var dir=sign(tr.get_center().z-tot.get_center().z) if found else -1.0
	var cab_end=tot.end.z if dir<0 else tot.position.z   # vorderes Ende (Fahrerhaus)
	for m in root.find_children("*","MeshInstance3D",true,false):
		var a=F.rel_xf(m,root)*m.get_aabb()
		if abs(a.get_center().z-cab_end)>6.0:m.visible=false
	var red=_flat(Color(0.62,0.04,0.03),0.35,0.3);red.clearcoat_enabled=true
	var z0=cab_end+dir*2.75;var z1=cab_end+dir*9.2
	var body=MeshInstance3D.new();body.mesh=BoxMesh.new();body.mesh.size=Vector3(2.45,2.1,abs(z1-z0));root.add_child(body)
	body.position=Vector3(0,1.0+1.05,(z0+z1)*0.5);body.material_override=red
	var sh=load("res://assets/props/polyhaven/rollershutter.glb")
	for s in [-1,1]:
		for k in 2:
			var r:Node3D=sh.instantiate();root.add_child(r)
			var zc=lerp(z0,z1,0.27+k*0.46)
			r.transform=Transform3D(Basis(Vector3.UP,s*PI*0.5).scaled(Vector3(2.6/5.1,1.5/1.85,0.4)),Vector3(s*1.24,1.25,zc))
	var chrome=_flat(Color(0.8,0.8,0.82),0.25,1.0)
	var bumper=MeshInstance3D.new();bumper.mesh=BoxMesh.new();bumper.mesh.size=Vector3(2.45,0.25,0.2);root.add_child(bumper);bumper.position=Vector3(0,0.95,z1+dir*0.1);bumper.material_override=chrome
	_lightbar(root,Color(0.15,0.35,1.0))
	# Leiter auf dem Aufbau
	var met=_flat(Color(0.85,0.85,0.87),0.3,0.9);var y=3.2
	var lz0=cab_end+dir*1.0;var lz1=z1+dir*0.6;var L=abs(lz1-lz0)
	for s in [-1,1]:
		var rail=MeshInstance3D.new();rail.mesh=BoxMesh.new();rail.mesh.size=Vector3(0.08,0.16,L);root.add_child(rail);rail.position=Vector3(s*0.45,y+0.3,(lz0+lz1)*0.5);rail.material_override=met
	var k2=0.2
	while k2<L:
		var rung=MeshInstance3D.new();rung.mesh=BoxMesh.new();rung.mesh.size=Vector3(0.9,0.05,0.05);root.add_child(rung);rung.position=Vector3(0,y+0.3,lz0+dir*k2);rung.material_override=met;k2+=0.35
	var turn=MeshInstance3D.new();turn.mesh=CylinderMesh.new();turn.mesh.top_radius=0.7;turn.mesh.bottom_radius=0.8;turn.mesh.height=0.3;root.add_child(turn);turn.position=Vector3(0,y,z1-dir*1.2);turn.material_override=red
	for s in [-1,1]:
		var lb=Label3D.new();lb.text="FEUERWEHR";lb.font_size=110;lb.pixel_size=0.0045;lb.modulate=Color(0.97,0.97,0.94);lb.outline_size=0;root.add_child(lb)
		lb.position=Vector3(s*1.235,2.75,(z0+z1)*0.5);lb.rotation.y=PI*0.5*s

# Auf die Räder stellen: tiefster Reifenpunkt = Boden. Teile, die dann unter den Boden ragen, ausblenden.
static func _ground(root:Node3D,model:String):
	if model=="bus":_bus_wheels(root);return
	var lo=INF
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible:continue
		var nm=(str(m.name)+" "+_matname(m)).to_lower()
		if nm.contains("wheel") or nm.contains("tire") or nm.contains("tyre") or nm.contains("reifen") or nm.contains("rubber"):
			lo=min(lo,(F.rel_xf(m,root)*m.get_aabb()).position.y)
	if lo==INF or abs(lo)<0.01:return
	for c in root.get_children():c.position.y-=lo
	for m in root.find_children("*","MeshInstance3D",true,false):
		if m.visible and (F.rel_xf(m,root)*m.get_aabb()).position.y<-0.06:m.visible=false

# Der Bus-Modell hat keine Reifen: an den Achsen Zwillingsreifen mit Felgen ergänzen
static func _bus_wheels(root:Node3D):
	var groups={}
	for m in root.find_children("*","MeshInstance3D",true,false):
		var n=str(m.name).split("_")[0]
		if n=="permost" or n=="zadmost":
			var a=F.rel_xf(m,root)*m.get_aabb()
			if not groups.has(n) or a.size.z<groups[n].size.z:groups[n]=a   # schmalstes Teil = Achsmitte
	# Feinkorrektur auf die Radlaufmitte (am Testbild gemessen)
	if groups.has("permost"):groups["permost"].position.z+=0.19
	if groups.has("zadmost"):groups["zadmost"].position.z+=0.39
	var axles=groups.values()
	if axles.is_empty():return
	var tot=F.aabb(root);var r=0.47
	var ay=0.0;for a in axles:ay+=a.get_center().y
	ay/=axles.size()
	var lift=r-ay
	for c in root.get_children():c.position.y+=lift
	var tire=_flat(Color(0.03,0.03,0.03),0.85);var rim=_flat(Color(0.5,0.5,0.52),0.3,0.9);var hub=_flat(Color(0.2,0.2,0.22),0.5,0.6)
	var zs=[]
	for a in axles:
		var z=a.get_center().z
		if zs.all(func(q):return abs(q-z)>0.5):zs.append(z)
	for z in zs:
		for s in [-1,1]:
			var x=s*(tot.size.x*0.5-0.2)
			var t=MeshInstance3D.new();t.mesh=CylinderMesh.new();t.mesh.top_radius=r;t.mesh.bottom_radius=r;t.mesh.height=0.3;t.mesh.radial_segments=40
			root.add_child(t);t.rotation.z=PI*0.5;t.position=Vector3(x,r,z);t.material_override=tire
			var f=MeshInstance3D.new();f.mesh=CylinderMesh.new();f.mesh.top_radius=r*0.62;f.mesh.bottom_radius=r*0.62;f.mesh.height=0.31;f.mesh.radial_segments=32
			root.add_child(f);f.rotation.z=PI*0.5;f.position=t.position;f.material_override=rim
			var h=MeshInstance3D.new();h.mesh=CylinderMesh.new();h.mesh.top_radius=r*0.22;h.mesh.bottom_radius=r*0.22;h.mesh.height=0.34
			root.add_child(h);h.rotation.z=PI*0.5;h.position=t.position;h.material_override=hub
	for m in root.find_children("*","MeshInstance3D",true,false):
		if str(m.name).begins_with("bryzgoviki"):m.visible=false   # Schmutzfänger ragten in den Boden
