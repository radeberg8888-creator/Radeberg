extends RefCounted
# Bäume (Nadelwald am Berg, Laubbäume, Alleebäume), Straßenlaternen, geparkte/fahrende Autos, Passanten, Ghetto-Kram.
const F=preload("res://scripts/fit.gd")
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
var G;var S;var B
var rng:=RandomNumberGenerator.new()
var spiel:=false
func _init(g,s,b):G=g;S=s;B=b;rng.seed=2024

# ---------------- Baum-Meshes (wenige Dreiecke, für Wälder als MultiMesh) ----------------
func _leaf_mat(col:Color)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_texture=load("res://assets/textures/leaves_albedo.png");m.albedo_color=col
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;m.alpha_scissor_threshold=0.35;m.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.roughness=0.85;m.vertex_color_use_as_albedo=true;m.uv1_scale=Vector3(2.5,2.5,1)
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

# Fichte: Stamm + 7 hängende Astetagen aus gezackten Sternen (wirkt wie Zweige, nicht wie Kegel)
func pine_mesh()->ArrayMesh:
	var am=ArrayMesh.new()
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark=Color(0.32,0.24,0.18)
	_cyl(st,Vector3.ZERO,0.28,0.12,14.0,6,bark)
	am=st.commit()
	var lt=SurfaceTool.new();lt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers=11
	for l in layers:
		var t=float(l)/layers
		var y=1.6+t*13.0;var r=lerp(3.4,0.5,t);var droop=lerp(1.4,0.4,t)
		var pts=15;var c=Color(1,1,1)*lerp(0.7,1.05,t)
		for k in pts:
			var a0=TAU*k/pts+l*0.7;var a1=TAU*(k+0.5)/pts+l*0.7;var a2=TAU*(k+1)/pts+l*0.7
			var tip=Vector3(cos(a1)*r,y-droop,sin(a1)*r)
			var b0=Vector3(cos(a0)*r*0.62,y-droop*0.35,sin(a0)*r*0.62);var b2=Vector3(cos(a2)*r*0.62,y-droop*0.35,sin(a2)*r*0.62)
			var top=Vector3(0,y+0.9,0)
			for tri in [[top,b0,tip],[top,tip,b2],[b0,tip,b2]]:
				for v in tri:
					lt.set_color(c);lt.set_normal((v-Vector3(0,y-1.5,0)).normalized());lt.set_uv(Vector2(v.x+v.y*0.3,v.z+v.y*0.2)*0.18);lt.add_vertex(v)
	lt.commit(am)
	var trunkm=StandardMaterial3D.new();trunkm.albedo_texture=load("res://assets/textures/bark_albedo.jpg");trunkm.vertex_color_use_as_albedo=true;trunkm.roughness=0.95
	var pm=_leaf_mat(Color(0.38,0.55,0.36));pm.alpha_scissor_threshold=0.18;pm.uv1_scale=Vector3(4,4,1)
	am.surface_set_material(0,trunkm);am.surface_set_material(1,pm)
	return am

# Laubbaum: Stamm + mehrere unregelmäßige Blattkugeln
func broadleaf_mesh(trunk_h:=4.0,crown:=4.5)->ArrayMesh:
	var am=ArrayMesh.new()
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(st,Vector3.ZERO,0.32,0.18,trunk_h+1.5,7,Color(0.35,0.28,0.22))
	for k in 3:
		var a=TAU*k/3.0;_cyl(st,Vector3(0,trunk_h*0.8,0),0.12,0.05,2.5,5,Color(0.35,0.28,0.22),Vector3(cos(a)*0.6,1,sin(a)*0.6).normalized())
	am=st.commit()
	var lt=SurfaceTool.new();lt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r2=RandomNumberGenerator.new();r2.seed=int(trunk_h*100+crown*10)
	for k in 6:
		var c=Vector3(r2.randf_range(-1,1)*crown*0.45,trunk_h+crown*0.55+r2.randf_range(-0.6,0.9)*crown*0.4,r2.randf_range(-1,1)*crown*0.45)
		if k==0:c=Vector3(0,trunk_h+crown*0.7,0)
		_blob(lt,c,crown*r2.randf_range(0.42,0.6),r2,Color(1,1,1)*r2.randf_range(0.8,1.05))
	lt.commit(am)
	var trunkm=StandardMaterial3D.new();trunkm.albedo_texture=load("res://assets/textures/bark_albedo.jpg");trunkm.vertex_color_use_as_albedo=true;trunkm.roughness=0.95
	am.surface_set_material(0,trunkm);am.surface_set_material(1,_leaf_mat(Color(0.62,0.72,0.42)))
	return am

func _cyl(st:SurfaceTool,base:Vector3,r0:float,r1:float,h:float,seg:int,col:Color,dir:=Vector3.UP):
	var bas=Basis(Quaternion(Vector3.UP,dir.normalized()))
	for k in seg:
		var a0=TAU*k/seg;var a1=TAU*(k+1)/seg
		var p=[Vector3(cos(a0)*r0,0,sin(a0)*r0),Vector3(cos(a1)*r0,0,sin(a1)*r0),Vector3(cos(a1)*r1,h,sin(a1)*r1),Vector3(cos(a0)*r1,h,sin(a0)*r1)]
		for i in [0,2,1,0,3,2]:
			var v=bas*p[i];st.set_color(col);st.set_normal(bas*Vector3(p[i].x,0,p[i].z).normalized());st.set_uv(Vector2(float(k)/seg*2.0,p[i].y*0.4));st.add_vertex(base+v)

func _blob(st:SurfaceTool,c:Vector3,r:float,r2:RandomNumberGenerator,col:Color):
	var rings=5;var seg=9
	var pts=[]
	for i in rings+1:
		var row=[]
		for k in seg+1:
			var th=PI*i/rings;var ph=TAU*k/seg
			var n=Vector3(sin(th)*cos(ph),cos(th)*0.8,sin(th)*sin(ph))
			var j=1.0+r2.randf_range(-0.22,0.22)
			if k==seg:row.append(row[0]);continue
			row.append(n*r*j)
		pts.append(row)
	for i in rings:
		for k in seg:
			var q=[pts[i][k],pts[i][k+1],pts[i+1][k+1],pts[i+1][k]]
			for idx in [0,1,2,0,2,3]:
				var v=q[idx];st.set_color(col);st.set_normal(v.normalized());st.set_uv(Vector2(v.x+v.z,v.y)*0.22+Vector2(c.x,c.z)*0.1);st.add_vertex(c+v)

func shrub_mesh()->ArrayMesh:
	var am=ArrayMesh.new();var lt=SurfaceTool.new();lt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r2=RandomNumberGenerator.new();r2.seed=5
	for k in 4:
		_blob(lt,Vector3(r2.randf_range(-0.5,0.5),0.45+r2.randf()*0.3,r2.randf_range(-0.5,0.5)),r2.randf_range(0.5,0.8),r2,Color(1,1,1)*r2.randf_range(0.85,1.0))
	lt.commit(am);am.surface_set_material(0,_leaf_mat(Color(0.55,0.52,0.36)));return am

# ---------------- Wälder ----------------
func forests(parent:Node3D):
	_weiten()
	var pines=[];var leafs=[];var shrubs=[]
	var step=10.0
	var z=G.Z0
	while z<G.Z1:
		var x=G.X0
		while x<G.X1:
			var p=Vector2(x+rng.randf_range(-4,4),z+rng.randf_range(-4,4))
			x+=step
			var h=G.h_at(p.x,p.y)
			if h<2.5:continue
			if not (B.is_free(p) and B.is_free(p+Vector2(3,0)) and B.is_free(p-Vector2(3,0)) and B.is_free(p+Vector2(0,3)) and B.is_free(p-Vector2(0,3))):continue
			var hx=G.h_at(p.x+5,p.y)-G.h_at(p.x-5,p.y);var hz=G.h_at(p.x,p.y+5)-G.h_at(p.x,p.y-5)
			var slope=Vector2(hx,hz).length()/10.0
			var w=G.soil(p.x,p.y,h,clamp(slope*0.7,0.0,1.0))
			var dm=p.distance_to(G.MOUNTAIN)
			if B.district(p)!=null:
				if rng.randf()<0.012:leafs.append([p,h])
				continue
			if w.g>0.35 and rng.randf()<w.g*0.95:
				if dm<620 or rng.randf()<0.35:pines.append([p,h])
				else:leafs.append([p,h])
			elif w.b>0.5:
				if rng.randf()<0.035:shrubs.append([p,h])
			elif w.a>0.6:
				if rng.randf()<0.05 and h<200:pines.append([p,h])
			else:
				# Baumgruppen statt gleichmäßiger Streuung
				var grove=G.noise2.get_noise_2d(p.x*0.4+900.0,p.y*0.4)
				if grove>0.16 and rng.randf()<0.65:leafs.append([p,h])
				elif rng.randf()<0.006:leafs.append([p,h])
		z+=step
	var pm=pine_mesh();var bm=broadleaf_mesh(4.0,4.6)
	_stufen(parent,pines,0.75,1.35,"Nadelwald",[[pm,0.0,W_MITTEL,200.0],[fern_mesh(true),W_MITTEL,W_FERN,500.0]])
	_stufen(parent,leafs,0.75,1.3,"Laubbaeume",[[baum_nah(),0.0,W_NAH,100.0],[bm,W_NAH,W_MITTEL,200.0],[fern_mesh(false),W_MITTEL,W_FERN,500.0]])
	_stufen(parent,shrubs,0.6,1.3,"Wuestenbuesche",[[shrub_mesh(),0.0,W_MITTEL-40.0,200.0]])
	print("WELT Bäume: Nadel ",pines.size()," Laub ",leafs.size()," Büsche ",shrubs.size())

# Bäume in Detailstufen: nah ein ausgedünntes echtes Baummodell (kleine Kacheln), mittel ein einfaches Modell,
# fern nur noch ein Kegel/Kristall mit wenigen Dreiecken. Jede Stufe hat ihre eigene Sichtweite – so werden
# nie zehntausende Detailbäume gleichzeitig gezeichnet.
var W_NAH:=70.0
var W_MITTEL:=260.0
var W_FERN:=1600.0
func _weiten():
	if not spiel:W_NAH=200.0;W_MITTEL=900.0;W_FERN=4000.0
func _stufen(parent:Node3D,pts:Array,s0:float,s1:float,name:String,stufen:Array,schon_xf:=false):
	_weiten()
	var lst=[]
	for e in pts:
		var xf:Transform3D
		if schon_xf:xf=e
		else:
			var s=rng.randf_range(s0,s1)
			xf=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(s*rng.randf_range(0.9,1.1),s,s*rng.randf_range(0.9,1.1))),Vector3(e[0].x,e[1]-0.4,e[0].y))
		var v=rng.randf_range(0.82,1.12)
		lst.append([xf,Color(v*rng.randf_range(0.95,1.05),v,v*rng.randf_range(0.9,1.02))])
	for st in stufen:
		var mesh:Mesh=st[0];var b0:float=st[1];var b1:float=st[2];var kachel:float=st[3]
		var tiles={}
		for e in lst:
			var k=Vector2i(floor(e[0].origin.x/kachel),floor(e[0].origin.z/kachel))
			if not tiles.has(k):tiles[k]=[]
			tiles[k].append(e)
		for k in tiles:
			var l=tiles[k]
			var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh;mm.instance_count=l.size()
			for i in l.size():mm.set_instance_transform(i,l[i][0]);mm.set_instance_color(i,l[i][1])
			var mi=MultiMeshInstance3D.new();mi.multimesh=mm;mi.name=name;parent.add_child(mi)
			mi.visibility_range_begin=b0;mi.visibility_range_end=b1
			if b1<=W_NAH+1.0:mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			elif b0>=W_MITTEL-1.0:mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Fernstufe: Kegel (Nadelbaum) bzw. Doppelpyramide (Laubbaum), undurchsichtig, ~10 Dreiecke
var _fern_mat:StandardMaterial3D
func fern_mesh(nadel:bool)->ArrayMesh:
	if _fern_mat==null:
		_fern_mat=StandardMaterial3D.new();_fern_mat.vertex_color_use_as_albedo=true;_fern_mat.roughness=1.0
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg=5
	var col=Color(0.2,0.3,0.17) if nadel else Color(0.33,0.42,0.22)
	var unten=1.4 if nadel else 3.2;var mitte=4.5 if nadel else 6.6;var oben=15.0 if nadel else 10.5;var r=3.2 if nadel else 4.2
	for k in seg:
		var a0=TAU*k/seg;var a1=TAU*(k+1)/seg
		var p0=Vector3(cos(a0)*r,mitte,sin(a0)*r);var p1=Vector3(cos(a1)*r,mitte,sin(a1)*r)
		for tri in [[Vector3(0,oben,0),p1,p0],[Vector3(0,unten,0),p0,p1]]:
			var n=(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
			if n.y<0 and tri[0].y>mitte:n=-n
			for v in tri:st.set_color(col);st.set_normal((n+Vector3(0,0.6,0)).normalized());st.add_vertex(v)
	var am=st.commit();am.surface_set_material(0,_fern_mat);return am

# Nahstufe: echtes Baummodell mit ausgedünnten (dafür größeren) Blattkarten und vereinfachtem Stamm
var _baum_nah:ArrayMesh
func baum_nah()->ArrayMesh:
	if _baum_nah:return _baum_nah
	var VE=load("res://scripts/vereinfachen.gd")
	var voll=real_tree_mesh();var am=ArrayMesh.new()
	for s in voll.get_surface_count():
		var arr=voll.surface_get_arrays(s);var mat=voll.surface_get_material(s)
		if arr[Mesh.ARRAY_INDEX]==null:arr[Mesh.ARRAY_INDEX]=PackedInt32Array(range(arr[Mesh.ARRAY_VERTEX].size()))
		for k in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:arr[k]=null
		var blatt=mat is BaseMaterial3D and mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
		if blatt:arr=VE.ausduennen(arr,0.3,1.6)
		else:arr[Mesh.ARRAY_INDEX]=VE.cluster(arr,arr[Mesh.ARRAY_INDEX],0.6)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
		am.surface_set_material(am.get_surface_count()-1,mat)
	_baum_nah=am;return am

# echtes Baummodell als ein Mesh (alle Teile zusammengeführt, auf ~9 m Höhe skaliert)
func real_tree_mesh()->ArrayMesh:
	var n=load("res://assets/props/tree/tree.gltf").instantiate();var w=F.place(n,9.5)
	var am=ArrayMesh.new()
	for m in w.find_children("*","MeshInstance3D",true,false):
		var xf=F.rel_xf(m,w)
		for si in m.mesh.get_surface_count():
			var st=SurfaceTool.new();st.append_from(m.mesh,si,xf);st.commit(am)
			var mat=m.get_active_material(si)
			if mat is BaseMaterial3D:
				mat=mat.duplicate();mat.vertex_color_use_as_albedo=false
			am.surface_set_material(am.get_surface_count()-1,mat)
	w.free();return am

# ---------------- Stadtbäume, Laternen ----------------
var _strassenbaeume:=[]
func street_tree(_parent:Node3D,p:Vector2,y:float):
	var sc=rng.randf_range(0.85,1.15)
	_strassenbaeume.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*sc),Vector3(p.x,y-0.3,p.y)))

func lamp_mesh()->ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(st,Vector3.ZERO,0.13,0.08,7.0,8,Color(1,1,1))
	_cyl(st,Vector3(0,6.9,0),0.05,0.05,1.7,6,Color(1,1,1),Vector3(0,0.2,1).normalized())
	var am=st.commit()
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.24,0.26,0.28);m.metallic=0.7;m.roughness=0.45;m.vertex_color_use_as_albedo=false
	am.surface_set_material(0,m)
	var hb=BoxMesh.new();hb.size=Vector3(0.36,0.14,0.7)
	var st2=SurfaceTool.new();st2.begin(Mesh.PRIMITIVE_TRIANGLES);st2.append_from(hb,0,Transform3D(Basis(),Vector3(0,7.25,1.7)));st2.commit(am)
	lampen_mat=Mats.emissive(Color(1.0,0.93,0.8),2.5)
	am.surface_set_material(1,lampen_mat)
	return am
var lampen_mat:StandardMaterial3D

func streets(parent:Node3D):
	var lamps=[];var ab_lamps=[]
	for r in S.roads:
		var L=S.length(r)
		if r.typ in ["strasse","allee","gasse"]:
			var stepv=34.0 if r.typ!="gasse" else 45.0
			var s=8.0
			while s<L-4:
				var at=S.at(r,s);var p:Vector2=at[0];var t:Vector2=at[2];var i=at[3]
				s+=stepv
				if r.tunnel_flags[i] or S.near_junction(p,4.0)<0:continue
				var n=Vector2(-t.y,t.x)
				for sd in [1,-1]:
					if r.typ=="gasse" and sd==-1:continue
					var q=p+n*sd*(r.w+0.6)
					lamps.append(Transform3D(Basis(Vector3.UP,atan2(-n.x*sd,-n.y*sd)),Vector3(q.x,at[1]+0.14,q.y)))
				var d=B.district(p)
				# Alleebäume im Mittelstreifen, Straßenbäume in Altstadt/Vorort
				if r.typ=="allee" and not r.elev[i]:
					street_tree(parent,p,at[1]+0.16)
					var at2=S.at(r,s-stepv*0.5)
					if S.near_junction(at2[0],4.0)>0:street_tree(parent,at2[0],at2[1]+0.16)
				elif d!=null and d.n in ["altstadt","vorort"] and rng.randf()<0.5:
					var sd2=1 if rng.randf()<0.5 else -1;var q2=p+n*sd2*(r.w+r.sw-1.2)+t*12
					street_tree(parent,q2,at[1]+0.14)
		elif r.typ=="autobahn":
			var s=10.0
			while s<L:
				var at=S.at(r,s);var i=at[3];s+=60.0
				if r.tunnel_flags[i]:continue
				var t:Vector2=at[2];var n=Vector2(-t.y,t.x)
				for sd in [1,-1]:ab_lamps.append(Transform3D(Basis(Vector3.UP,atan2(n.x*sd,n.y*sd)),Vector3(at[0].x,at[1]+0.9,at[0].y)))
	var lm=lamp_mesh()
	var kacheln={}
	for xf in lamps+ab_lamps:
		var k=Vector2i(floor(xf.origin.x/250.0),floor(xf.origin.z/250.0))
		if not kacheln.has(k):kacheln[k]=[]
		kacheln[k].append(xf)
	for k in kacheln:
		var set=kacheln[k]
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=lm;mm.instance_count=set.size()
		for j in set.size():mm.set_instance_transform(j,set[j])
		var mi=MultiMeshInstance3D.new();mi.multimesh=mm;mi.name="Laternen";parent.add_child(mi)
		mi.visibility_range_end=450.0 if spiel else 1500.0
	if not _strassenbaeume.is_empty():
		_weiten()
		_stufen(parent,_strassenbaeume,1.0,1.0,"Strassenbaeume",[[baum_nah(),0.0,W_NAH*1.6,100.0],[broadleaf_mesh(4.0,4.6),W_NAH*1.6,W_MITTEL,200.0]],true)
		print("WELT Straßenbäume ",_strassenbaeume.size())
	print("WELT Laternen ",lamps.size()+ab_lamps.size())

# ---------------- Autos ----------------
func cars(parent:Node3D):
	var VH=load("res://scripts/vehicles.gd")
	var city=["trabant","taxi","polizei","bmw_e30","mercedes","small_car","audi_rs7","porsche911","bmw_m8","audi_r8","dodge","jdm","small_car","mercedes","taxi"]
	var ghetto=["bmw_e30","hudson","dodge","trabant","small_car","f100","mercedes","jdm"]
	var tmpl={};var n=0;var wrecks=0
	for r in S.roads:
		if not r.typ in ["strasse","allee","autobahn","gasse","rampe"]:continue
		var L=S.length(r);var s=rng.randf_range(10,60)
		var gap=170.0 if r.typ=="autobahn" else 90.0
		while s<L-10:
			var at=S.at(r,s);var p:Vector2=at[0];var t:Vector2=at[2];var i=at[3]
			s+=gap*rng.randf_range(0.5,1.6)
			if S.near_junction(p,6.0)<0:continue
			var d=B.district(p)
			if r.typ in ["strasse","gasse","allee"] and d==null and rng.randf()<0.7:continue
			var nn=Vector2(-t.y,t.x)
			var dirs=1 if rng.randf()<0.5 else -1
			var lane=0
			if r.typ=="autobahn":lane=r.med+0.3+(r.w-0.5-r.med)*(0.25 if rng.randf()<0.6 else 0.75)
			elif r.typ=="allee":lane=r.med+(r.w-r.med)*(0.3 if rng.randf()<0.5 else 0.72)
			elif r.typ=="rampe":lane=0.0
			else:lane=r.w*0.5
			var list=ghetto if (d!=null and d.n=="ghetto") else city
			var kd=list[rng.randi()%list.size()]
			if r.typ=="autobahn" and rng.randf()<0.2:kd=["lkw","lkw_blau","bus"][rng.randi()%3]
			var parked=false
			if d!=null and d.n=="ghetto" and r.typ!="autobahn" and rng.randf()<0.5:parked=true
			if not tmpl.has(kd):tmpl[kd]=VH.make(kd)
			var v:Node3D=tmpl[kd].duplicate();parent.add_child(v)
			var off=lane*(-dirs)
			if parked:off=(r.w-1.1)*(-dirs)
			var q=p+nn*off
			var yaw=atan2(t.x*dirs,t.y*dirs)+(PI if tmpl[kd].get_meta("front",1.0)<0 else 0.0)
			if parked:yaw+=rng.randf_range(-0.08,0.08)
			v.position=Vector3(q.x,at[1]+0.04,q.y);v.rotation.y=yaw
			# ausgebrannte Wracks im Ghetto
			if parked and rng.randf()<0.25:
				wrecks+=1
				for m in v.find_children("*","MeshInstance3D",true,false):
					m.material_override=Mats.flat(Color(0.09,0.08,0.075),0.95,0.2)
			n+=1
	print("WELT Autos ",n," davon Wracks ",wrecks)

# ---------------- Passanten ----------------
func people(parent:Node3D,maxn:=80):
	var PE=load("res://scripts/people.gd");var pr=RandomNumberGenerator.new();pr.seed=77
	var k=0;var tries=0
	while k<maxn and tries<2000:
		tries+=1
		var r=S.roads[rng.randi()%S.roads.size()]
		if not r.typ in ["strasse","allee","gasse"]:continue
		var at=S.at(r,rng.randf()*S.length(r));var p:Vector2=at[0];var t:Vector2=at[2]
		var d=B.district(p)
		if d==null or d.n=="industrie":continue
		var nn=Vector2(-t.y,t.x);var sd=1 if rng.randf()<0.5 else -1
		var q=p+nn*sd*(r.w+r.sw*rng.randf_range(0.3,0.75))
		var ps=PE.make(PE.CIVIL[k%PE.CIVIL.size()],pr);parent.add_child(ps)
		ps.position=Vector3(q.x,at[1]+0.14,q.y)
		var walk=rng.randf()<0.6
		ps.rotation.y=atan2(t.x,t.y)+(0.0 if rng.randf()<0.5 else PI) if walk else rng.randf()*TAU
		PE.play(ps,"walk" if walk else ["idle","talk"][rng.randi()%2],rng.randf())
		# kleine Gruppen
		if not walk and rng.randf()<0.5:
			var p2=PE.make(PE.CIVIL[(k+1)%PE.CIVIL.size()],pr);parent.add_child(p2)
			p2.position=ps.position+Vector3(1.1,0,0.4);p2.rotation.y=ps.rotation.y+PI+0.4;PE.play(p2,"talk",rng.randf());k+=1
		k+=1
	print("WELT Passanten ",k)

# ---------------- Ghetto-Kram: Mülltonnen, Fässer, Müllsäcke, Zäune, Basketballplatz ----------------
func ghetto_props(parent:Node3D):
	var b=Batch.new();var green=Mats.flat(Color(0.12,0.28,0.18),0.7,0.4);var rust=Mats.flat(Color(0.4,0.22,0.12),0.85,0.4)
	var bag=Mats.flat(Color(0.04,0.04,0.045),0.35,0.0);var fence=Mats.flat(Color(0.55,0.57,0.58),0.45,0.8)
	var chain=StandardMaterial3D.new();chain.albedo_color=Color(0.6,0.62,0.63,0.55);chain.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;chain.metallic=0.7;chain.roughness=0.4;chain.cull_mode=BaseMaterial3D.CULL_DISABLED
	var cnt=0
	for r in S.roads:
		if not r.typ in ["strasse","gasse"]:continue
		var L=S.length(r);var s=5.0
		while s<L-5:
			var at=S.at(r,s);var p:Vector2=at[0];var t:Vector2=at[2];s+=rng.randf_range(9,22)
			var d=B.district(p)
			if d==null or d.n!="ghetto" or S.near_junction(p,3.0)<0:continue
			var nn=Vector2(-t.y,t.x)*(1 if rng.randf()<0.5 else -1)
			var q=p+nn*(r.w+r.sw-0.7);var y=at[1]+0.14
			var xf=Transform3D(Basis(Vector3.UP,atan2(t.x,t.y)),Vector3(q.x,y,q.y))
			match rng.randi()%3:   # (Maschendrahtzaun entfernt – wirkte wie eine Glasscheibe auf dem Gehweg)
				0:   # Müllcontainer
					b.box(green,Vector3(-0.9,0.05,-0.55),Vector3(0.9,1.25,0.55),xf);b.box(Mats.flat(Color(0.08,0.15,0.1),0.6),Vector3(-0.95,1.25,-0.6),Vector3(0.95,1.32,0.6),xf)
				1:   # Ölfässer
					for k in 1+rng.randi()%3:b.cyl(rust,Vector3(k*0.65-0.6,0.45,rng.randf_range(-0.2,0.2)),0.29,0.9,xf)
				2:   # Müllsäcke
					for k in 2+rng.randi()%4:b.box_rot(bag,Vector3(rng.randf_range(-0.8,0.8),0.25,rng.randf_range(-0.3,0.3)),Vector3(0.55,0.5,0.5),Basis(Vector3.UP,rng.randf()*3),xf)
				3:   # Maschendrahtzaun-Stück
					var len=rng.randf_range(4,9)
					for k in int(len/2.5)+1:b.cyl(fence,Vector3(-len*0.5+k*2.5,1.0,0.6),0.04,2.0,xf)
					b.box(chain,Vector3(-len*0.5,0.0,0.59),Vector3(len*0.5,2.0,0.61),xf);b.cyl(fence,Vector3(0,2.0,0.6),0.03,len,xf,Basis(Vector3(0,0,1),PI*0.5))
			cnt+=1
	for gm in b.commit(parent):gm.visibility_range_end=350.0 if spiel else 1500.0
	print("WELT Ghetto-Kram ",cnt)

# ---------------- Stadtmöbel aus echten Modellen (Bank, Betonmülleimer, Müllcontainer) als MultiMesh ----------------
const MOEBEL:={"bank":["res://assets/props/neu/bank/bank.gltf",0.0],"eimer":["res://assets/props/neu/muelleimer/muelleimer.gltf",0.95],"container":["res://assets/props/neu/container/container.gltf",1.45]}
func moebel(parent:Node3D):
	var sets={"bank":[],"eimer":[],"container":[]}
	for r in S.roads:
		if not r.typ in ["strasse","allee"]:continue
		var L=S.length(r);var s=rng.randf_range(15,40)
		while s<L-8:
			var at=S.at(r,s);var p:Vector2=at[0];var t:Vector2=at[2];var i=at[3];s+=rng.randf_range(45,85)
			if r.tunnel_flags[i] or r.elev[i] or S.near_junction(p,8.0)<0:continue
			var d=B.district(p)
			if d==null or d.n in ["staubwinkel","docks"]:continue
			var sd=1 if rng.randf()<0.5 else -1;var nn=Vector2(-t.y,t.x)*sd
			var art="bank" if rng.randf()<0.6 else "container"
			var q=p+nn*(r.w+r.sw-(0.6 if art=="bank" else 0.9))
			var yaw=atan2(-nn.x,-nn.y) if art=="bank" else atan2(t.x,t.y)
			sets[art].append(Transform3D(Basis(Vector3.UP,yaw),Vector3(q.x,at[1]+0.14,q.y)))
	for k in sets:
		if sets[k].is_empty() or not ResourceLoader.exists(MOEBEL[k][0]):continue
		_mm_modell(parent,MOEBEL[k][0],sets[k],MOEBEL[k][1],"Moebel_"+k)
	print("WELT Moebel ",sets.bank.size()," ",sets.eimer.size()," ",sets.container.size())

# Modell -> je Teil-Mesh ein MultiMesh; ziel_h>0 skaliert auf diese Höhe, Fuß auf y=0, mittig
func _mm_modell(parent:Node3D,pfad:String,xfs:Array,ziel_h:float,name:String):
	var m:Node3D=load(F.leicht(pfad)).instantiate()
	var ab=F.aabb(m);var sk=1.0
	if ziel_h>0.0:sk=ziel_h/max(ab.size.y,0.001)
	var basis=Transform3D(Basis().scaled(Vector3.ONE*sk),-Vector3(ab.get_center().x,ab.position.y,ab.get_center().z)*sk)
	# in 250-m-Zellen aufteilen, damit die Sichtweite pro Zelle greift
	var zellen={}
	for x in xfs:
		var k=Vector2i(floor(x.origin.x/250.0),floor(x.origin.z/250.0))
		if not zellen.has(k):zellen[k]=[]
		zellen[k].append(x)
	for mi in m.find_children("*","MeshInstance3D",true,false):
		var lx=basis*F.rel_xf(mi,m)
		for k in zellen:
			var l=zellen[k];var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mi.mesh;mm.instance_count=l.size()
			for j in l.size():mm.set_instance_transform(j,l[j]*lx)
			var inst=MultiMeshInstance3D.new();inst.multimesh=mm;inst.name=name;inst.visibility_range_end=220.0
			if mi.material_override:inst.material_override=mi.material_override
			parent.add_child(inst,true)
	m.free()
