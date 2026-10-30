extends RefCounted
# Blockrandbebauung: ein Häuserblock wird am Rand lückenlos mit Häusern bebaut, alle mit der Front zur Straße.
# Ecken bekommen Eckhäuser, innen liegt ein Hinterhof. Gehweg und Bordstein sind eine durchgehende Fläche je Block.
const Batch=preload("res://scripts/batch.gd")
const Mats=preload("res://scripts/mats.gd")
var fronten:={}     # Vorlage -> {vorn, boden, b, t, h}
var rng:=RandomNumberGenerator.new()
var meshes:={}
var gehweg_breite:=3.6
var bord_h:=0.15

func _init():
	var f=FileAccess.get_file_as_string("res://assets/cache/geb/fronten.json")
	if f!="":fronten=JSON.parse_string(f)

func _vorn_vec(v:String)->Vector2:
	return {"+z":Vector2(0,1),"-z":Vector2(0,-1),"+x":Vector2(1,0),"-x":Vector2(-1,0)}[v]
# Breite entlang der Straße und Tiefe in den Block
func masse(name:String)->Vector2:
	var e=fronten[name]
	if e.vorn in ["+z","-z"]:return Vector2(e.b,e.t)
	return Vector2(e.t,e.b)

func mesh(name:String)->Mesh:
	if not meshes.has(name):meshes[name]=load("res://assets/cache/geb/"+name+".res")
	return meshes[name]

# Ein Haus mit Front in Richtung n (Weltrichtung, 2D) aufstellen; p = Mitte der Grundfläche
func haus(parent:Node3D,name:String,p:Vector2,n:Vector2,y:float)->Node3D:
	var e=fronten[name];var fl=_vorn_vec(e.vorn)
	var yaw=atan2(n.x,n.y)-atan2(fl.x,fl.y)
	var mi=MeshInstance3D.new();mi.mesh=mesh(name);parent.add_child(mi)
	mi.transform=Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,y-float(e.boden)+0.02,p.y))
	return mi

# Block bebauen. ecken: 4 Punkte (gegen den Uhrzeigersinn von oben), y = Bodenhöhe.
# liste: [[Vorlage, Gewicht], …] für Reihenhäuser; eck: Vorlagen für Ecken; max_tiefe: Bebauungstiefe
func block(parent:Node3D,ecken:Array,y:float,liste:Array,eck:Array,max_tiefe:float):
	var n_e=ecken.size()
	# Gehweg als Ring zwischen Blockrand (Straßenkante) und Bebauungslinie
	var innen=[]
	for i in n_e:
		var a:Vector2=ecken[i]
		innen.append(a)
	var gw=Mats.pbr("pavers",0.45,Color(0.86,0.84,0.8));var bord=Mats.pbr("concrete",0.5,Color(0.75,0.74,0.72))
	var hof=Mats.pbr("concrete",0.3,Color(0.55,0.54,0.52))
	# Hof (ganze Blockfläche, liegt unter den Häusern)
	var poly=PackedVector2Array(ecken)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in Geometry2D.triangulate_polygon(poly):
		st.set_normal(Vector3.UP);st.set_uv(poly[k]*0.2);st.add_vertex(Vector3(poly[k].x,y+bord_h-0.01,poly[k].y))
	var hm=MeshInstance3D.new();hm.mesh=st.commit();hm.material_override=hof;parent.add_child(hm)
	# Gehweg + Bordsteinkante: geschlossener Ring (Oberseite + senkrechte Kante zur Straße)
	var gpoly=Geometry2D.offset_polygon(poly,-gehweg_breite)
	var gi:PackedVector2Array=gpoly[0] if gpoly.size()>0 else poly
	var sg=SurfaceTool.new();sg.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n_e:
		var a:Vector2=poly[i];var c:Vector2=poly[(i+1)%n_e]
		var ai:Vector2=_naechster(gi,a);var ci:Vector2=_naechster(gi,c)
		var q=[a,c,ci,ai]
		for j in [0,1,2,0,2,3]:sg.set_normal(Vector3.UP);sg.set_uv(q[j]*0.5);sg.add_vertex(Vector3(q[j].x,y+bord_h,q[j].y))
	var gm=MeshInstance3D.new();gm.mesh=sg.commit();gm.material_override=gw;parent.add_child(gm)
	var sk=SurfaceTool.new();sk.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n_e:
		var a:Vector2=poly[i];var c:Vector2=poly[(i+1)%n_e];var nn=_aussen(poly,a,c)
		var q=[Vector3(a.x,y-0.3,a.y),Vector3(c.x,y-0.3,c.y),Vector3(c.x,y+bord_h,c.y),Vector3(a.x,y+bord_h,a.y)]
		for j in [0,2,1,0,3,2]:sk.set_normal(Vector3(nn.x,0,nn.y));sk.set_uv(Vector2(q[j].x+q[j].z,q[j].y)*0.5);sk.add_vertex(q[j])
	var km=MeshInstance3D.new();km.mesh=sk.commit();km.material_override=bord;parent.add_child(km)
	# Häuser: je Kante zuerst das Eckhaus am Kantenanfang, dann bis zum Eckhaus der nächsten Kante lückenlos füllen
	var gy=y+bord_h
	var kanten=[]
	for i in n_e:
		var a:Vector2=_naechster(gi,poly[i]);var c:Vector2=_naechster(gi,poly[(i+1)%n_e])
		var L=a.distance_to(c);var t=(c-a)/L
		var eck_name=_passend(eck,max_tiefe,L*0.5)
		kanten.append({"a":a,"t":t,"n":_aussen(poly,a,c),"L":L,"eck":eck_name,"m":masse(eck_name)})
	var res=[]
	for i in n_e:
		var K=kanten[i];var N=kanten[(i+1)%n_e]
		var reihe=[[K.eck,0.0,K.m]]
		var pos=K.m.x+0.05
		var ende=K.L-N.m.y   # dort beginnt die Tiefe des nächsten Eckhauses
		var versuche=0
		while pos<ende-2.5 and versuche<80:
			versuche+=1
			var name=_passend(liste,max_tiefe,ende-pos)
			if name=="":break
			var m=masse(name)
			reihe.append([name,pos,m]);pos+=m.x+0.05
		var rest=max(0.0,ende-pos);var dx=rest/max(reihe.size()-1,1)
		for k in reihe.size():
			var e=reihe[k]
			var off=e[1]+(k*dx if k>0 else 0.0)
			var mitte=K.a+K.t*(off+e[2].x*0.5)-K.n*(e[2].y*0.5)
			res.append([e[0],mitte,K.n])
			haus(parent,e[0],mitte,K.n,gy)
	return res

# Vorlage ziehen, die in Tiefe und Restlänge passt
func _passend(liste:Array,tiefe:float,platz:float)->String:
	for k in 30:
		var name=_ziehen(liste)
		var m=masse(name)
		if m.y<=tiefe and m.x<=platz:return name
	var best="";var bm=INF
	for e in liste:
		var m=masse(e[0])
		if m.y<=tiefe and m.x<=platz and m.x<bm:bm=m.x;best=e[0]
	return best

# Normale einer Kante, die aus dem Block heraus zur Straße zeigt (unabhängig von der Umlaufrichtung)
func _aussen(poly:PackedVector2Array,a:Vector2,c:Vector2)->Vector2:
	var t=(c-a).normalized();var nn=Vector2(t.y,-t.x)
	if Geometry2D.is_point_in_polygon((a+c)*0.5+nn*0.5,poly):nn=-nn
	return nn

func _naechster(poly:PackedVector2Array,p:Vector2)->Vector2:
	var best=poly[0];var bd=INF
	for q in poly:
		var d=q.distance_to(p)
		if d<bd:bd=d;best=q
	return best

func _ziehen(liste:Array)->String:
	var tot=0.0
	for e in liste:tot+=e[1]
	var x=rng.randf()*tot
	for e in liste:
		x-=e[1]
		if x<=0:return e[0]
	return liste[0][0]
