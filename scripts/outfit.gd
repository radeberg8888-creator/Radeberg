extends RefCounted
# Kleidung wechseln: Oberteil, Hose, Schuhe einzeln einfärben (Material-Klassen der Modelle),
# dazu Accessoires am Kopf-/Halsknochen: Cap, Mütze, Bandana, Sonnenbrille, Goldkette.
const TOP=["T-shirt","T-shirt_0","Topmat","Biker_Vest","Female_T_Shirt"]
const BOTTOM=["Shorts","Bottommat","Biker_Jeans","Denim_shorts"]
const SHOES=["Shoes","Shoesmat","Boots","High_Heels"]
# Auswahl im Laden: Name, Farbe, Preis
const TOPS=[["Weißes Shirt",Color(0.9,0.9,0.88),15],["Schwarzes Shirt",Color(0.07,0.07,0.08),15],["Grünes Trikot",Color(0.12,0.42,0.18),45],["Rotes Hemd",Color(0.6,0.07,0.07),35],["Blaues Hoodie",Color(0.12,0.2,0.45),60],["Grau meliert",Color(0.5,0.5,0.52),25],["Lila Shirt",Color(0.35,0.15,0.5),20],["Camel Jacke",Color(0.62,0.45,0.25),120]]
const BOTTOMS=[["Blue Jeans",Color(0.18,0.28,0.48),40],["Schwarze Jeans",Color(0.08,0.08,0.1),45],["Khaki",Color(0.6,0.52,0.36),35],["Grau Jogger",Color(0.4,0.4,0.42),30],["Weiße Hose",Color(0.86,0.85,0.8),50],["Camo-Grün",Color(0.28,0.32,0.2),40]]
const SHOE_LIST=[["Weiße Sneaker",Color(0.92,0.92,0.9),80],["Schwarze Boots",Color(0.06,0.06,0.06),110],["Rote Sneaker",Color(0.65,0.08,0.06),90],["Braune Schuhe",Color(0.35,0.22,0.12),70]]
const HATS=[["ohne",""],["Cap schwarz","cap_black"],["Cap rot","cap_red"],["Wollmütze","beanie"],["Bandana blau","bandana"]]

static func _cls(name:String)->String:
	for t in TOP:if name.begins_with(t):return "top"
	for t in BOTTOM:if name.begins_with(t):return "bottom"
	for t in SHOES:if name.begins_with(t):return "shoes"
	return ""

# o = {top:Color, bottom:Color, shoes:Color, hat:String, glasses:bool, chain:bool}
static func apply(p:Node3D,o:Dictionary):
	for m in p.find_children("*","MeshInstance3D",true,false):
		for i in m.mesh.get_surface_count():
			var orig=m.mesh.surface_get_material(i)
			if orig==null:continue
			var c=_cls(orig.resource_name)
			if c=="":continue
			var sm=m.get_surface_override_material(i)
			if not (sm is ShaderMaterial):continue
			sm=sm.duplicate();m.set_surface_override_material(i,sm)
			if o.has(c):
				# Helligkeit der Originaltextur ausgleichen, damit die Wunschfarbe getroffen wird
				var tx=sm.get_shader_parameter("albedo_tex");var ac=sm.get_shader_parameter("albedo_color")
				if ac==null:ac=Color(1,1,1)
				var mc=ac
				if tx!=null:mc=load("res://scripts/people.gd")._median_color(tx)*ac
				var lum=clamp(mc.r*0.3+mc.g*0.59+mc.b*0.11,0.04,1.0)
				lum=min(lum,0.32*2.2)/1.0
				var want:Color=o[c];var k=0.32/lum
				sm.set_shader_parameter("cloth_tint",Color(want.r*k,want.g*k,want.b*k));sm.set_shader_parameter("cloth_mix",0.92)
				sm.set_shader_parameter("cloth_hue",0.0);sm.set_shader_parameter("cloth_sat",1.0);sm.set_shader_parameter("cloth_val",1.0)
	for old in p.find_children("Outfit_*","Node3D",true,false):old.queue_free()
	var sk:Skeleton3D=null
	var sks=p.find_children("*","Skeleton3D",true,false)
	if sks.size()>0:sk=sks[0]
	if sk==null:return
	var head=-1;var neck=-1
	for k in sk.get_bone_count():
		var bn=sk.get_bone_name(k)
		if bn.ends_with("Head") or bn.contains("_Head_") or bn.ends_with("Head_06") or bn=="CC_Base_Head_038":head=k
		if bn.contains("Neck") and neck<0:neck=k
	if head<0:return
	# Zielpositionen in Weltkoordinaten messen (Kopfoberkante aus der Figur, Mitte über dem Kopfknochen),
	# dann in den Knochenraum umrechnen -> Accessoires sitzen bei jeder Figur/Skalierung richtig und folgen der Animation
	var F=load("res://scripts/fit.gd")
	var ab:AABB=p.global_transform*F.aabb(p)
	var bw:Transform3D=sk.global_transform*sk.get_bone_global_pose(head)
	var fw:Vector3=p.global_transform.basis.z.normalized();var up=Vector3.UP;var rt=up.cross(fw).normalized()
	var top=ab.end.y
	var hc=Vector3(bw.origin.x,top-0.105,bw.origin.z)+fw*0.05
	var B0=Basis(rt,up,fw)
	var at=BoneAttachment3D.new();at.name="Outfit_Kopf";at.bone_idx=head;sk.add_child(at)
	var acc=Node3D.new();acc.set_script(load("res://scripts/bone_follow.gd"));at.add_child(acc)
	acc.setup(bw,Transform3D(B0,hc))
	var hat:String=o.get("hat","")
	if hat.begins_with("cap"):
		var col=Color(0.06,0.06,0.07) if hat=="cap_black" else Color(0.6,0.06,0.05)
		_sphere(acc,Vector3(0,-0.004,-0.008),Vector3(0.106,0.108,0.118),col,true)
		_box(acc,Vector3(0,0.0,0.118),Vector3(0.165,0.012,0.1),col)
	elif hat=="beanie":
		_sphere(acc,Vector3(0,-0.006,-0.01),Vector3(0.11,0.122,0.12),Color(0.15,0.17,0.22),true)
	elif hat=="bandana":
		_sphere(acc,Vector3(0,-0.002,-0.008),Vector3(0.104,0.104,0.114),Color(0.1,0.18,0.5),true)
		_box(acc,Vector3(0,-0.02,-0.11),Vector3(0.03,0.07,0.02),Color(0.1,0.18,0.5))
	if o.get("glasses",false):
		for sd in [-1,1]:_box(acc,Vector3(sd*0.033,-0.03,0.099),Vector3(0.047,0.026,0.006),Color(0.02,0.02,0.02),0.9)
		_box(acc,Vector3(0,-0.022,0.102),Vector3(0.11,0.005,0.005),Color(0.6,0.5,0.2),0.2)
		for sd in [-1,1]:_box(acc,Vector3(sd*0.072,-0.022,0.052),Vector3(0.004,0.004,0.1),Color(0.1,0.1,0.1),0.5)
	if o.get("chain",false) and neck>=0:
		var nw:Transform3D=sk.global_transform*sk.get_bone_global_pose(neck)
		var at2=BoneAttachment3D.new();at2.name="Outfit_Hals";at2.bone_idx=neck;sk.add_child(at2)
		var cn=Node3D.new();cn.set_script(load("res://scripts/bone_follow.gd"));at2.add_child(cn)
		cn.setup(nw,Transform3D(B0,nw.origin+fw*0.035-Vector3(0,0.05,0)))
		var t=MeshInstance3D.new();var tm=TorusMesh.new();tm.inner_radius=0.072;tm.outer_radius=0.08;t.mesh=tm;cn.add_child(t)
		t.rotation_degrees=Vector3(65,0,0)
		var gm=StandardMaterial3D.new();gm.albedo_color=Color(1.0,0.78,0.3);gm.metallic=1.0;gm.roughness=0.2;t.material_override=gm

static func _sphere(p:Node3D,pos:Vector3,sz:Vector3,c:Color,half:=false):
	var m=MeshInstance3D.new();var sm=SphereMesh.new();sm.radius=1.0;sm.height=1.0 if half else 2.0;sm.is_hemisphere=half;m.mesh=sm;p.add_child(m)
	m.position=pos;m.scale=sz
	var mt=StandardMaterial3D.new();mt.albedo_color=c;mt.roughness=0.8;m.material_override=mt
static func _box(p:Node3D,pos:Vector3,sz:Vector3,c:Color,metal:=0.0):
	var m=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=sz;m.mesh=bm;p.add_child(m);m.position=pos
	var mt=StandardMaterial3D.new();mt.albedo_color=c;mt.roughness=0.3 if metal>0 else 0.7;mt.metallic=metal;m.material_override=mt
