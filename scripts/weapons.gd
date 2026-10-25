extends RefCounted
# Waffenarsenal wie in San Andreas: Waffenplätze (Nahkampf, Pistolen, Schrotflinten, MPs, Sturmgewehre, Gewehre),
# jede Waffe in 10 Lackierungen und mit Anbauteilen (Schalldämpfer, Zielfernrohr, Laser, Rotpunkt).
# make(id, finish, attachments) liefert die Waffe aufrecht, Mündung nach +X, Länge in Metern.
const F=preload("res://scripts/fit.gd")
const W="res://assets/weapons/"
const PACK=W+"pack10/pack10.gltf"

# id: [Name, Waffenplatz, Datei, Knoten-Präfix (Waffenpaket) oder "", Länge m, Schaden, Feuerrate/s, Magazin, Reichweite m, mögliche Anbauteile]
const LIST={
	"machete":["Machete","Nahkampf",W+"machete.glb","",0.75,35,1.6,0,2,[]],
	"katana":["Katana","Nahkampf",W+"katana/katana.glb","",1.0,45,1.4,0,2.3,[]],
	"pistole":["Dienstpistole","Pistole",W+"pistol.glb","",0.21,25,3.0,15,40,["daempfer","laser"]],
	"m1911":["M1911",  "Pistole",W+"m1911/m1911.gltf","",0.22,32,2.5,8,45,["daempfer","laser"]],
	"pistole_tac":["Taktische Pistole","Pistole",W+"pistol_tac/pistol_tac.gltf","",0.26,28,3.2,17,45,["daempfer","laser","rotpunkt"]],
	"tp9":["TP9 Elite","Pistole",PACK,"Canit_TP9",0.22,24,4.0,18,40,["daempfer","laser"]],
	"kalibri":["Taschenpistole","Pistole",PACK,"2MM_Kalibri",0.12,12,3.0,6,15,[]],
	"obrez":["Abgesägte Mosin","Schrotflinte",PACK,"Mosin_Nagant",0.42,60,1.0,5,25,[]],
	"mossberg":["Pumpgun","Schrotflinte",PACK,"Mossberg_500",0.95,80,1.1,6,30,["laser","rotpunkt"]],
	"ks7":["Kampfschrotflinte","Schrotflinte",PACK,"Kel_Tec_KS7",0.67,75,1.8,14,30,["laser","rotpunkt"]],
	"mp5":["MP5","Maschinenpistole",W+"mp5/mp5.gltf","",0.66,22,13.0,30,60,["daempfer","laser","rotpunkt"]],
	"mp7":["MP7","Maschinenpistole",PACK,"HK_MP7",0.6,20,15.0,40,60,["daempfer","laser","rotpunkt"]],
	"ar15":["AR-15","Sturmgewehr",W+"ar15/ar15.gltf","",0.92,30,10.0,30,120,["daempfer","visier","laser","rotpunkt"]],
	"m4":["M4A1","Sturmgewehr",PACK,"Colt_M4A1",0.84,30,12.0,30,120,["daempfer","visier","laser","rotpunkt"]],
	"g47":["Gewehr 47","Sturmgewehr",W+"gewehr47/gewehr47.gltf","",0.88,34,10.0,30,110,["daempfer","visier","rotpunkt"]],
	"garand":["M1 Garand","Gewehr",PACK,"M1_Grand",1.1,55,2.0,8,180,["visier"]],
	"repetier":["Repetiergewehr","Gewehr",W+"rifle.glb","",1.23,90,0.8,5,300,["visier","daempfer"]],
	"mauser":["Mauser T-Gewehr","Gewehr",PACK,"Mauser_1918T",1.68,140,0.5,1,350,["visier"]],
	"m14":["M14 EBR (Scharfschütze)","Scharfschützengewehr",PACK,"M14_EBR",1.12,110,1.2,20,400,["visier","daempfer","laser"]],
}
const FINISH=["Standard","Schwarz","Wüste","Wald","Arktis","Urban","Gold","Chrom","Rost","Pink"]
const CAMO={"Wüste":"wueste","Wald":"wald","Arktis":"arktis","Urban":"urban","Pink":"pink"}
const ATT_NAME={"daempfer":"Schalldämpfer","visier":"Zielfernrohr","laser":"Laser","rotpunkt":"Rotpunkt"}

static var _pack:Node3D
static var _pack_basis=null

static func _raw(id:String)->Node3D:
	var e=LIST[id]
	if id=="katana":return katana()
	if e[3]=="":return load(e[2]).instantiate()
	if _pack==null:_pack=load(PACK).instantiate()
	var root=Node3D.new()
	for m in _pack.find_children("*","MeshInstance3D",true,false):
		var p:Node=m;var hit=false
		while p!=null and p!=_pack:
			if str(p.name).begins_with(e[3]):hit=true;break
			p=p.get_parent()
		if not hit:continue
		var c=MeshInstance3D.new();c.mesh=m.mesh;c.transform=F.rel_xf(m,_pack)
		for i in m.mesh.get_surface_count():
			var mt=m.get_active_material(i);if mt:c.set_surface_override_material(i,mt)
		root.add_child(c)
	return root

# Lage bestimmen: längste Achse -> X, dünnste -> Z (seitlich), mittlere -> Y (Höhe). Mündung = schmales Ende -> +X; Griff/Magazin nach unten.
static func _orient(n:Node3D,use_pca:=false,use_pack_basis:=false)->Node3D:
	var pts:=PackedVector3Array()
	for m in n.find_children("*","MeshInstance3D",true,false):
		var xf=F.rel_xf(m,n)
		for s in m.mesh.get_surface_count():
			var v:PackedVector3Array=m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var step=max(1,v.size()/4000)
			for i in range(0,v.size(),step):pts.append(xf*v[i])
	# Hauptachsen (PCA): auch schräg liegende Modelle werden gerade ausgerichtet
	var c=Vector3();for p in pts:c+=p
	c/=max(pts.size(),1)
	var C=[[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0]]
	for p in pts:
		var d=p-c
		for a in 3:
			for b in 3:C[a][b]+=d[a]*d[b]
	var B:Basis
	if use_pack_basis and _pack_basis!=null:
		B=_pack_basis
	else:
		var ev=_eig(C)   # Spalten = Eigenvektoren, absteigend
		var e0:Vector3=ev[0];var e1:Vector3=ev[1];var e2:Vector3=e0.cross(e1).normalized()
		B=Basis(e0,e1,e2).transposed()   # Modell -> X lang, Y mittel, Z dünn
		if not use_pca:
			var lo=Vector3(INF,INF,INF);var hi=-lo
			for p in pts:lo=lo.min(p);hi=hi.max(p)
			var sz=hi-lo;var ax=[0,1,2];ax.sort_custom(func(a,b):return sz[a]>sz[b])
			var e=[Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)]
			B=Basis(e[ax[0]],e[ax[1]],e[ax[2]]).transposed()
			if B.determinant()<0:B=Basis(e[ax[0]],e[ax[1]],-e[ax[2]]).transposed()
	# Mündung: Ende mit kleinerer Höhe; Oberseite: Seite, auf der die Mündung liegt
	var q:=PackedVector3Array();for p in pts:q.append(B*p)
	var l2=Vector3(INF,INF,INF);var h2=-l2
	for p in q:l2=l2.min(p);h2=h2.max(p)
	var L=h2.x-l2.x
	var ylo_a=INF;var yhi_a=-INF;var ylo_b=INF;var yhi_b=-INF
	for p in q:
		if p.x<l2.x+L*0.12:ylo_a=min(ylo_a,p.y);yhi_a=max(yhi_a,p.y)
		elif p.x>h2.x-L*0.12:ylo_b=min(ylo_b,p.y);yhi_b=max(yhi_b,p.y)
	var flip=Basis()
	var muzzle_low=(yhi_a-ylo_a)<(yhi_b-ylo_b)   # Mündung am -X-Ende -> um Y drehen
	var muzzle_y=(ylo_a+yhi_a)*0.5 if muzzle_low else (ylo_b+yhi_b)*0.5
	if muzzle_low:flip=Basis(Vector3.UP,PI)
	if muzzle_y<(l2.y+h2.y)*0.5:flip=Basis(Vector3(1,0,0),PI)*flip   # Lauf soll oben liegen
	var holder=Node3D.new();holder.add_child(n);n.transform=Transform3D(flip*B,Vector3())*n.transform
	return holder

# Eigenvektoren einer symmetrischen 3x3-Matrix (Jacobi), nach Eigenwert absteigend sortiert
static func _eig(A:Array)->Array:
	var a=[A[0].duplicate(),A[1].duplicate(),A[2].duplicate()]
	var v=[[1.0,0.0,0.0],[0.0,1.0,0.0],[0.0,0.0,1.0]]
	for it in 50:
		var p=0;var q=1;var mx=abs(a[0][1])
		if abs(a[0][2])>mx:p=0;q=2;mx=abs(a[0][2])
		if abs(a[1][2])>mx:p=1;q=2;mx=abs(a[1][2])
		if mx<1e-10:break
		var th=0.5*atan2(2*a[p][q],a[q][q]-a[p][p]);var cs=cos(th);var sn=sin(th)
		for k in 3:
			var akp=a[k][p];var akq=a[k][q]
			a[k][p]=cs*akp-sn*akq;a[k][q]=sn*akp+cs*akq
		for k in 3:
			var apk=a[p][k];var aqk=a[q][k]
			a[p][k]=cs*apk-sn*aqk;a[q][k]=sn*apk+cs*aqk
		for k in 3:
			var vkp=v[k][p];var vkq=v[k][q]
			v[k][p]=cs*vkp-sn*vkq;v[k][q]=sn*vkp+cs*vkq
	var idx=[0,1,2];idx.sort_custom(func(i,j):return a[i][i]>a[j][j])
	var out=[]
	for i in idx:out.append(Vector3(v[0][i],v[1][i],v[2][i]).normalized())
	return out

static func _finish_mat(mt:BaseMaterial3D,fin:String)->BaseMaterial3D:
	var d:StandardMaterial3D=mt.duplicate()
	match fin:
		"Schwarz":d.albedo_color=mt.albedo_color*Color(0.28,0.28,0.3);d.metallic=0.35;d.roughness=0.55
		"Gold":d.albedo_color=Color(1.0,0.77,0.34);d.metallic=1.0;d.roughness=0.22;d.albedo_texture=null
		"Chrom":d.albedo_color=Color(0.95,0.95,0.97);d.metallic=1.0;d.roughness=0.07;d.albedo_texture=null
		"Rost":d.albedo_color=mt.albedo_color*Color(0.72,0.42,0.24);d.roughness=0.92;d.metallic=0.2
		_:
			if CAMO.has(fin):
				d.albedo_texture=load("res://assets/textures/camo/"+CAMO[fin]+".jpg");d.albedo_color=Color(1,1,1)
				d.uv1_triplanar=true;d.uv1_scale=Vector3(4,4,4);d.normal_enabled=false;d.roughness=0.62;d.metallic=0.1
				d.roughness_texture=null;d.metallic_texture=null
	return d

static func make(id:String,fin:="Standard",att:=[])->Node3D:
	var e=LIST[id]
	if e[3]!="" and _pack_basis==null and id!="m4":
		make("m4")   # Lage des Waffenpakets einmal an einer langen Waffe messen
	var raw=_raw(id)
	var o=_orient(raw,e[3]!="",e[3]!="" and id!="m4")
	if id=="m4" and _pack_basis==null:_pack_basis=o.get_child(0).transform.basis.orthonormalized()
	var w=F.place(o,e[4],0)   # Länge entlang X einpassen, Boden y=0, mittig
	var root=Node3D.new();root.name=id;root.add_child(w)
	root.set_meta("weapon",id)
	if fin!="Standard":
		for m in raw.find_children("*","MeshInstance3D",true,false)+([raw] if raw is MeshInstance3D else []):
			for i in m.mesh.get_surface_count():
				var mt=m.get_active_material(i)
				if mt is BaseMaterial3D:m.set_surface_override_material(i,_finish_mat(mt,fin))
	var ab=F.aabb(root);var L=ab.size.x;var H=ab.size.y
	var dark=StandardMaterial3D.new();dark.albedo_color=Color(0.04,0.04,0.045);dark.metallic=0.6;dark.roughness=0.4
	var mx=ab.end.x;var top=ab.end.y
	# Mündungshöhe: oberes Drittel
	var my=ab.position.y+H*(0.78 if H<0.25 else 0.72)
	for a in att:
		if not a in e[9]:continue
		match a:
			"daempfer":
				var s=MeshInstance3D.new();s.mesh=CylinderMesh.new();s.mesh.top_radius=0.019 if L<0.4 else 0.023;s.mesh.bottom_radius=s.mesh.top_radius;s.mesh.height=0.14 if L<0.4 else 0.2
				root.add_child(s);s.rotation.z=PI*0.5;s.position=Vector3(mx+s.mesh.height*0.5-0.005,my,0);s.material_override=dark
			"visier":
				var sc=MeshInstance3D.new();sc.mesh=CylinderMesh.new();sc.mesh.top_radius=0.026;sc.mesh.bottom_radius=0.026;sc.mesh.height=min(0.32,L*0.3)
				root.add_child(sc);sc.rotation.z=PI*0.5;sc.position=Vector3(ab.position.x+L*0.52,my+0.07,0);sc.material_override=dark
				for k in [-1,1]:
					var bell=MeshInstance3D.new();bell.mesh=CylinderMesh.new();bell.mesh.top_radius=0.03;bell.mesh.bottom_radius=0.022;bell.mesh.height=0.05
					root.add_child(bell);bell.rotation.z=PI*0.5*k;bell.position=sc.position+Vector3(k*(sc.mesh.height*0.5+0.02),0,0);bell.material_override=dark
					var mount=MeshInstance3D.new();mount.mesh=BoxMesh.new();mount.mesh.size=Vector3(0.025,0.04,0.03);root.add_child(mount);mount.position=sc.position+Vector3(k*0.07,-0.03,0);mount.material_override=dark
			"laser":
				var lb=MeshInstance3D.new();lb.mesh=BoxMesh.new();lb.mesh.size=Vector3(0.07,0.025,0.03);root.add_child(lb);lb.position=Vector3(mx-L*0.25,my-0.035,0);lb.material_override=dark
				var dot=MeshInstance3D.new();dot.mesh=SphereMesh.new();dot.mesh.radius=0.006;dot.mesh.height=0.012;root.add_child(dot);dot.position=lb.position+Vector3(0.037,0,0)
				var red=StandardMaterial3D.new();red.albedo_color=Color(1,0,0);red.emission_enabled=true;red.emission=Color(1,0.05,0.05);red.emission_energy_multiplier=8;dot.material_override=red
			"rotpunkt":
				var rd=MeshInstance3D.new();rd.mesh=BoxMesh.new();rd.mesh.size=Vector3(0.06,0.04,0.035);root.add_child(rd);rd.position=Vector3(ab.position.x+L*0.6,my+0.05,0);rd.material_override=dark
	return root

# alle Kombinationen zählen (für die Anzeige)
static func variant_count()->int:
	var n=0
	for id in LIST:n+=FINISH.size()*int(pow(2,LIST[id][9].size()))
	return n

# Katana: Texturen liegen getrennt (Poly Haven), daher eigenes Material
static func katana()->Node3D:
	var K="res://assets/weapons/katana/"
	var n=load(K+"katana.glb").instantiate()
	var m=StandardMaterial3D.new();m.albedo_texture=load(K+"katana_diff.jpg");m.roughness_texture=load(K+"katana_rough.jpg");m.roughness=1.0
	m.normal_enabled=true;m.normal_texture=load(K+"katana_nor.exr");m.metallic_texture=load(K+"katana_metal.exr");m.metallic=1.0
	for mi in n.find_children("*","MeshInstance3D",true,false):mi.material_override=m
	return n
