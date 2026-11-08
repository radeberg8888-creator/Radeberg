extends RefCounted
# Gebäude-Bausatz: eine Variante wird einmal mit der stadt_lib gebaut und danach per MultiMesh beliebig oft aufgestellt.
# Damit es auf dem Handy wenige Zeichenaufrufe sind, werden Materialien zusammengelegt:
#  - alle einfarbigen Toon-Materialien -> eine Fläche mit Vertex-Farben
#  - Shader-Materialien gleicher Art (Ziegel, Putz, Glas, ...) -> eine Fläche je Art, Farbe kommt aus der Vertex-Farbe
#  - Kontur (ink) -> eine Fläche
# Lokales Variantensystem: Vorderkante auf z=0 (Straße bei +z), Grundstück reicht nach -z, Breite um x=0.
var L
var KITS:={}            # name -> {mesh, koll:PackedVector3Array, pf:[], park:[], labels:[], lod:[], w, d}
var _vc_mat:StandardMaterial3D
var _shader_vc:={}      # code-hash -> Shader (Vertexfarben-Variante)
var _mat_vc:={}         # key -> ShaderMaterial
var LOD:=[]             # aktuelle Variante: [Transform3D, size, Color]

func _init(lib):
	L=lib
	_vc_mat=StandardMaterial3D.new();_vc_mat.vertex_color_use_as_albedo=true;_vc_mat.roughness=0.8
	_vc_mat.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;_vc_mat.specular_mode=BaseMaterial3D.SPECULAR_TOON

# Hauptbaukörper eintragen: Kollision + Fernansicht (Kasten, leicht eingerückt damit er im Detailmodell verschwindet)
func haupt(c:Vector3,s:Vector3,b:Basis,farbe:Color,dach:=Color(0,0,0,0)):
	L.koll_box(c,s,b)
	LOD.append([Transform3D(b,c),s,farbe,dach])

func kit(name:String,w:float,d:float,builder:Callable)->Dictionary:
	var tmp=Node3D.new()
	var alt=[L.welt,L.st,L.mats,L.zaehler,L.kachel]
	L.welt=tmp;L.st={};L.mats={};L.zaehler={};L.kachel=0.0
	var nKF=L.KOLL_F.size();var nPF=L.PFOSTEN.size();var nPK=L.PARKEN.size()
	LOD=[]
	builder.call()
	# Flächen einsammeln (noch offene SurfaceTools + schon ausgegebene MeshInstances)
	var teile=[]   # [arrays, material]
	for k in L.st.keys():
		var arr=L.st[k].commit_to_arrays()
		if not arr.is_empty() and arr[Mesh.ARRAY_VERTEX]!=null:teile.append([arr,L.mats[k]])
	var labels=[]
	for c in tmp.get_children():
		if c is MeshInstance3D:
			for si in c.mesh.get_surface_count():teile.append([c.mesh.surface_get_arrays(si),c.material_override])
		elif c is Label3D:
			labels.append({"text":c.text,"xf":c.transform,"px":c.pixel_size,"mod":c.modulate,"om":c.outline_modulate,"os":c.outline_size,"fs":c.font_size})
	var mesh=_zusammen(teile)
	var e={"mesh":mesh,"koll":PackedVector3Array(L.KOLL_F.slice(nKF)),"pf":L.PFOSTEN.slice(nPF),"park":L.PARKEN.slice(nPK),
		"labels":labels,"lod":LOD.duplicate(),"w":w,"d":d,"name":name}
	L.KOLL_F.resize(nKF);L.PFOSTEN.resize(nPF);L.PARKEN.resize(nPK)
	tmp.free()
	L.welt=alt[0];L.st=alt[1];L.mats=alt[2];L.zaehler=alt[3];L.kachel=alt[4]
	KITS[name]=e
	return e

func _farbe_von(m:Material)->Color:
	if m is StandardMaterial3D:return m.albedo_color
	var f=m.get_shader_parameter("farbe")
	if f==null:
		var code:String=m.shader.code;var i=code.find("uniform vec3 farbe")
		if i<0:return Color.WHITE
		var a=code.find("vec3(",i+20);var b=code.find(")",a)
		var p=code.substr(a+5,b-a-5).split(",")
		return Color(float(p[0]),float(p[1]),float(p[2]))
	if f is Vector3:return Color(f.x,f.y,f.z)
	return f
func _vc_variante(m:ShaderMaterial)->Material:
	var code:String=m.shader.code
	if code.find("uniform vec3 farbe")<0:return m
	var params={}
	for p in m.shader.get_shader_uniform_list():
		if p.name!="farbe":params[p.name]=m.get_shader_parameter(p.name)
	var key=str(code.hash())+str(params)
	if _mat_vc.has(key):return _mat_vc[key]
	var h=code.hash()
	if not _shader_vc.has(h):
		var i=code.find("uniform vec3 farbe");var j=code.find(";",i)
		var neu=code.substr(0,i)+code.substr(j+1)
		neu=neu.replace("shader_type spatial;","shader_type spatial;\n#define farbe COLOR.rgb")
		var s=Shader.new();s.code=neu;_shader_vc[h]=s
	var nm=ShaderMaterial.new();nm.shader=_shader_vc[h]
	for k in params:nm.set_shader_parameter(k,params[k])
	_mat_vc[key]=nm
	return nm
func _gruppe(m:Material)->Array:   # [Schlüssel, Zielmaterial, vertexfarbe]
	if m==L.ink:return ["ink",m,null]
	if m is StandardMaterial3D:
		var sm:StandardMaterial3D=m
		if sm.albedo_texture==null and sm.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.emission_enabled and sm.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and not sm.vertex_color_use_as_albedo:
			return ["vc",_vc_mat,sm.albedo_color]
		return ["m"+str(m.get_instance_id()),m,null]
	if m is ShaderMaterial and m.shader.code.find("uniform vec3 farbe")>=0:
		var vm=_vc_variante(m)
		# Shader nutzen die Farbe nach source_color (sRGB->linear); Vertexfarbe liegt roh an -> vorher umrechnen
		return ["s"+str(vm.get_instance_id()),vm,_farbe_von(m).srgb_to_linear()]
	return ["m"+str(m.get_instance_id()),m,null]
func _zusammen(teile:Array)->ArrayMesh:
	var G={}   # key -> [V,N,C,mat]
	for t in teile:
		var arr=t[0];var g=_gruppe(t[1]);var k=g[0]
		if not G.has(k):G[k]=[PackedVector3Array(),PackedVector3Array(),PackedColorArray(),g[1]]
		var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX];var N=arr[Mesh.ARRAY_NORMAL];var I=arr[Mesh.ARRAY_INDEX]
		var e=G[k];var col=g[2] if g[2]!=null else Color.WHITE
		if I!=null and I.size()>0:
			for idx in I:
				e[0].append(V[idx]);e[1].append(N[idx] if N!=null else Vector3.UP);e[2].append(col)
		else:
			for i in V.size():
				e[0].append(V[i]);e[1].append(N[i] if N!=null else Vector3.UP);e[2].append(col)
	var am=ArrayMesh.new()
	var keys=G.keys();keys.sort()
	for k in keys:
		var e=G[k];var a=[];a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX]=e[0];a[Mesh.ARRAY_NORMAL]=e[1];a[Mesh.ARRAY_COLOR]=e[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		am.surface_set_material(am.get_surface_count()-1,e[3])
		if k=="ink":am.surface_set_name(am.get_surface_count()-1,"ink")
	return am

# ---------------- Aufstellen ----------------
# Platzierungen: [kit_name, Transform3D (lokale Stadtkoordinaten)]
# Ergebnis: Knoten mit MultiMeshInstances je 100-m-Feld und Variante, Sichtweite begrenzt.
func aufstellen(ziel:Node3D,platz:Array,feld:=100.0,sicht:=260.0,lod_sicht:=1600.0)->Dictionary:
	var F={}   # Vector2i -> {kit -> [xf]}
	for p in platz:
		var o:Vector3=p[1].origin;var key=Vector2i(int(floor(o.x/feld)),int(floor(o.z/feld)))
		if not F.has(key):F[key]={}
		if not F[key].has(p[0]):F[key][p[0]]=[]
		F[key][p[0]].append(p[1])
	var n_mm=0
	for key in F:
		var mitte=Vector3((key.x+0.5)*feld,0,(key.y+0.5)*feld)
		var fn=Node3D.new();fn.name="F_%d_%d"%[key.x,key.y];ziel.add_child(fn);fn.position=mitte
		for kn in F[key]:
			var k=KITS[kn];var xs:Array=F[key][kn]
			var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=k.mesh;mm.instance_count=xs.size()
			for i in xs.size():mm.set_instance_transform(i,Transform3D(xs[i].basis,xs[i].origin-mitte))
			var mmi=MultiMeshInstance3D.new();mmi.multimesh=mm;mmi.name=kn;fn.add_child(mmi)
			mmi.visibility_range_end=sicht;mmi.visibility_range_end_margin=25.0
			n_mm+=1
	return {"felder":F.size(),"multimesh":n_mm}

# Fernansicht: alle Hauptkörper als Kästen mit Vertexfarben, eine Fläche je Feld (groß)
func fern(ziel:Node3D,platz:Array,feld:=600.0,sicht:=1800.0):
	var G={}
	var box=BoxMesh.new();var bf=box.get_faces()
	for p in platz:
		var k=KITS[p[0]];var xf:Transform3D=p[1]
		var key=Vector2i(int(floor(xf.origin.x/feld)),int(floor(xf.origin.z/feld)))
		if not G.has(key):G[key]=[PackedVector3Array(),PackedVector3Array(),PackedColorArray()]
		var e=G[key]
		for l in k.lod:
			var lt:Transform3D=l[0];var s:Vector3=l[1]-Vector3(0.5,0.4,0.5)
			var t=xf*lt*Transform3D(Basis().scaled(s),Vector3(0,-0.2,0))
			for i in range(0,bf.size(),3):
				var a=t*bf[i];var b=t*bf[i+1];var c=t*bf[i+2]
				var n=(b-a).cross(c-a).normalized()
				var col:Color=l[2]
				if n.y>0.5 and l[3].a>0.0:col=l[3]
				col=col*(1.0 if n.y>0.5 else (0.85 if abs(n.x)>abs(n.z) else 0.95))
				e[0].append(a);e[1].append(-n);e[2].append(col);e[0].append(b);e[1].append(-n);e[2].append(col);e[0].append(c);e[1].append(-n);e[2].append(col)
	for key in G:
		var e=G[key]
		if e[0].is_empty():continue
		var a=[];a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX]=e[0];a[Mesh.ARRAY_NORMAL]=e[1];a[Mesh.ARRAY_COLOR]=e[2]
		var am=ArrayMesh.new();am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);am.surface_set_material(0,_vc_mat)
		var mi=MeshInstance3D.new();mi.mesh=am;mi.name="Fern_%d_%d"%[key.x,key.y];ziel.add_child(mi)
		mi.visibility_range_end=sicht;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return G.size()

# Kollision und Beschriftung der Platzierungen in einen Knoten (Kachel)
func kollision(platz:Array)->PackedVector3Array:
	var F=PackedVector3Array()
	for p in platz:
		var k=KITS[p[0]];var xf:Transform3D=p[1]
		for v in k.koll:F.append(xf*v)
	return F
