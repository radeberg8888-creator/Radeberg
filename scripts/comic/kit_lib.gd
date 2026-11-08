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
func haupt(c:Vector3,s:Vector3,b:Basis,farbe:Color,dach:=Color(0,0,0,0),giebel:=0,fenster:=true):
	L.koll_box(c,s,b)
	LOD.append([Transform3D(b,c),s,farbe,dach,giebel,fenster])

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
	var mesh=_zusammen(teile,false);var ink=_zusammen(teile,true)
	var e={"mesh":mesh,"ink":ink if ink.get_surface_count()>0 else null,"koll":PackedVector3Array(L.KOLL_F.slice(nKF)),"pf":L.PFOSTEN.slice(nPF),"park":L.PARKEN.slice(nPK),
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
func _zusammen(teile:Array,nur_ink:bool)->ArrayMesh:
	var G={}   # key -> [V,N,C,mat]
	for t in teile:
		var arr=t[0];var g=_gruppe(t[1]);var k=g[0]
		if (k=="ink")!=nur_ink:continue
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
const INK_SICHT:=55.0   # Konturen nur nah (halbiert Dreiecke und Aufrufe in der Ferne)
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
			if k.get("ink")!=null:
				var mi2=MultiMesh.new();mi2.transform_format=MultiMesh.TRANSFORM_3D;mi2.mesh=k.ink;mi2.instance_count=xs.size()
				for i in xs.size():mi2.set_instance_transform(i,mm.get_instance_transform(i))
				var mmk=MultiMeshInstance3D.new();mmk.multimesh=mi2;mmk.name=kn+"_ink";fn.add_child(mmk)
				mmk.visibility_range_end=INK_SICHT;mmk.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"felder":F.size(),"multimesh":n_mm}

# Fernansicht: Hauptkörper als Kästen mit Dach (flach oder Satteldach) und Fensterreihen, eine Fläche je Feld
var _fern_mat:StandardMaterial3D
func _quad(e:Array,a:Vector3,b:Vector3,c:Vector3,d:Vector3,n:Vector3,col:Color):
	for v in [a,b,c,a,c,d]:e[0].append(v);e[1].append(n);e[2].append(col)
func _fern_eintrag(e:Array,t:Transform3D,s:Vector3,wand:Color,dach:Color,giebel:int,fenster:bool):
	var h=s*0.5;var nb=t.basis.orthonormalized()
	var P=func(x,y,z):return t*Vector3(x,y,z)
	var W=wand*0.88;W.a=1.0
	var D=dach if dach.a>0.0 else wand*0.62;D.a=1.0
	# Seiten
	var seiten=[[Vector3(0,0,1),Vector3(1,0,0),h.z,h.x],[Vector3(0,0,-1),Vector3(-1,0,0),h.z,h.x],[Vector3(1,0,0),Vector3(0,0,-1),h.x,h.z],[Vector3(-1,0,0),Vector3(0,0,1),h.x,h.z]]
	for sd in seiten:
		var n:Vector3=sd[0];var r:Vector3=sd[1];var o=n*sd[2];var hw=sd[3]
		var sh=0.92 if abs(n.x)>0.5 else 1.0
		_quad(e,P.call(o.x-r.x*hw,-h.y,o.z-r.z*hw),P.call(o.x+r.x*hw,-h.y,o.z+r.z*hw),P.call(o.x+r.x*hw,h.y,o.z+r.z*hw),P.call(o.x-r.x*hw,h.y,o.z-r.z*hw),nb*n,W*sh)
		if fenster and s.y>=3.0 and e.size()>3:
			var fe=e[3];var fc=Color(0.16,0.2,0.27);var y=-h.y+1.0
			while y+1.4<h.y-0.3:
				var x=-hw+1.4
				while x+1.1<hw-0.6:
					var q=o+n*0.06
					_quad(fe,P.call(q.x+r.x*x,y,q.z+r.z*x),P.call(q.x+r.x*(x+1.1),y,q.z+r.z*(x+1.1)),P.call(q.x+r.x*(x+1.1),y+1.3,q.z+r.z*(x+1.1)),P.call(q.x+r.x*x,y+1.3,q.z+r.z*x),nb*n,fc)
					x+=2.8
				y+=3.1
	if giebel==0:
		_quad(e,P.call(-h.x,h.y,-h.z),P.call(h.x,h.y,-h.z),P.call(h.x,h.y,h.z),P.call(-h.x,h.y,h.z),nb*Vector3.UP,D)
	else:
		# Satteldach: First entlang z (giebel 2) oder x (giebel 1), Höhe 0.45 * Spannweite
		var lz=giebel==2;var span=h.x if lz else h.z;var fh=span*0.6;var u=0.4
		if lz:
			for sx in [-1,1]:
				_quad(e,P.call(sx*(h.x+u),h.y-0.2,-h.z-u),P.call(sx*(h.x+u),h.y-0.2,h.z+u),P.call(0,h.y+fh,h.z+u),P.call(0,h.y+fh,-h.z-u),nb*Vector3(sx,1.2,0).normalized(),D*(1.0 if sx>0 else 0.85))
			for sz in [-1,1]:
				var a=P.call(-h.x,h.y,sz*h.z);var b=P.call(h.x,h.y,sz*h.z);var c=P.call(0,h.y+fh-0.2,sz*h.z)
				for v in [a,b,c]:e[0].append(v);e[1].append(nb*Vector3(0,0,sz));e[2].append(W)
		else:
			for sz in [-1,1]:
				_quad(e,P.call(-h.x-u,h.y-0.2,sz*(h.z+u)),P.call(h.x+u,h.y-0.2,sz*(h.z+u)),P.call(h.x+u,h.y+fh,0),P.call(-h.x-u,h.y+fh,0),nb*Vector3(0,1.2,sz).normalized(),D*(1.0 if sz>0 else 0.85))
			for sx in [-1,1]:
				var a=P.call(sx*h.x,h.y,-h.z);var b=P.call(sx*h.x,h.y,h.z);var c=P.call(sx*h.x,h.y+fh-0.2,0)
				for v in [a,b,c]:e[0].append(v);e[1].append(nb*Vector3(sx,0,0));e[2].append(W)
func fern(ziel:Node3D,platz:Array,feld:=600.0,sicht:=1800.0):
	if _fern_mat==null:
		_fern_mat=_vc_mat.duplicate();_fern_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var G={}
	for p in platz:
		var k=KITS[p[0]];var xf:Transform3D=p[1]
		var key=Vector2i(int(floor(xf.origin.x/feld)),int(floor(xf.origin.z/feld)))
		if not G.has(key):G[key]=[PackedVector3Array(),PackedVector3Array(),PackedColorArray(),[PackedVector3Array(),PackedVector3Array(),PackedColorArray()]]
		for l in k.lod:
			var s:Vector3=l[1]-Vector3(0.4,0.3,0.4)
			var t:Transform3D=xf*l[0]*Transform3D(Basis(),Vector3(0,-0.15,0))
			_fern_eintrag(G[key],t,s,l[2],l[3],l[4] if l.size()>4 else 0,l[5] if l.size()>5 else false)
	for key in G:
		for teil in [[G[key],sicht,""],[G[key][3],450.0,"F"]]:
			var e=teil[0]
			if e[0].is_empty():continue
			var a=[];a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX]=e[0];a[Mesh.ARRAY_NORMAL]=e[1];a[Mesh.ARRAY_COLOR]=e[2]
			var am=ArrayMesh.new();am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);am.surface_set_material(0,_fern_mat)
			var mi=MeshInstance3D.new();mi.mesh=am;mi.name="Fern%s_%d_%d"%[teil[2],key.x,key.y];ziel.add_child(mi)
			mi.visibility_range_end=teil[1];mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return G.size()

# Kollision und Beschriftung der Platzierungen in einen Knoten (Kachel)
func kollision(platz:Array)->PackedVector3Array:
	var F=PackedVector3Array()
	for p in platz:
		var k=KITS[p[0]];var xf:Transform3D=p[1]
		for v in k.koll:F.append(xf*v)
	return F
