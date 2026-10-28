extends SceneTree
# Waffenmodelle vorbereiten: Lauf zeigt nach +Z, oben = +Y, Ursprung = Griff (rechte Hand), echte Länge.
# Meta: vorn (Stützhand), muendung, laenge. Ergebnis: res://assets/cache/waffen/<id>.scn
# godot --headless --path . -s res://tools/waffen_bake.gd
const F=preload("res://scripts/fit.gd")
const W=preload("res://scripts/spiel/waffen_daten.gd")

func _verts(root:Node3D)->PackedVector3Array:
	var out=PackedVector3Array()
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible or m.mesh==null:continue
		var xf=F.rel_xf(m,root)
		for s in m.mesh.get_surface_count():
			var a=m.mesh.surface_get_arrays(s)
			var V:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var step=max(1,V.size()/6000)
			for i in range(0,V.size(),step):out.append(xf*V[i])
	return out

func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://assets/cache/waffen")
	var only=OS.get_cmdline_user_args()
	for id in W.LISTE:
		var d=W.LISTE[id]
		if not d.has("modell"):continue
		if only.size()>0 and not id in only:continue
		var src:Node3D=load(d.modell).instantiate()
		root.add_child(src)
		await process_frame;await process_frame
		for m in src.find_children("*","MeshInstance3D",true,false):
			if m.skin!=null or m.skeleton!=NodePath(""):
				var am=_entskinnen(m,src)   # Teile an ihre Knochen setzen, dann statisch
				if am:
					for si in am.get_surface_count():am.surface_set_material(si,m.get_active_material(si))
					m.mesh=am
				m.skin=null;m.skeleton=NodePath("")
		if d.has("knoten"):   # aus einem Paket nur eine Waffe behalten
			var keep=src.find_child(d.knoten,true,false)
			for m in src.find_children("*","MeshInstance3D",true,false):
				if not (m==keep or keep.is_ancestor_of(m)):m.visible=false
		if d.get("nur_hauptteil",false):
			var big=null;var bv=0.0
			for m in src.find_children("*","MeshInstance3D",true,false):
				var a=F.rel_xf(m,src)*m.get_aabb()
				if m.visible and a.get_volume()>bv:bv=a.get_volume();big=a
			for m in src.find_children("*","MeshInstance3D",true,false):
				var a=F.rel_xf(m,src)*m.get_aabb()
				if not big.grow(big.get_longest_axis_size()*0.02).intersects(a):m.visible=false
		var V0=_verts(src)
		# Hauptachsen (PCA): Paketmodelle liegen schräg
		var mean=Vector3.ZERO
		for v in V0:mean+=v/V0.size()
		var cov=[[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0]]
		for v in V0:
			var dv=v-mean
			for a in 3:
				for b in 3:cov[a][b]+=dv[a]*dv[b]
		var mul=func(x:Vector3)->Vector3:
			return Vector3(cov[0][0]*x.x+cov[0][1]*x.y+cov[0][2]*x.z,cov[1][0]*x.x+cov[1][1]*x.y+cov[1][2]*x.z,cov[2][0]*x.x+cov[2][1]*x.y+cov[2][2]*x.z)
		var e1=Vector3(1,0.3,0.2).normalized()
		for it in 60:e1=mul.call(e1).normalized()
		var e2=Vector3(0.2,1,0.3)
		for it in 60:
			e2=mul.call(e2);e2=(e2-e1*e2.dot(e1)).normalized()
		var e3=e1.cross(e2).normalized()
		if d.get("achsen_fest",false):e1=Vector3.ZERO;e2=Vector3.ZERO;e3=Vector3.ZERO
		var E=[e1,e2,e3]
		var V=PackedVector3Array()
		if e1==Vector3.ZERO:
			V=V0;E=[Vector3.RIGHT,Vector3.UP,Vector3.BACK]
		else:
			for v in V0:V.append(Vector3((v-mean).dot(e1),(v-mean).dot(e2),(v-mean).dot(e3)))
		var lo=V[0];var hi=V[0]
		for v in V:lo=lo.min(v);hi=hi.max(v)
		var size=hi-lo
		var ax=[0,1,2];ax.sort_custom(func(a,b):return size[a]>size[b])
		var L=ax[0];var H=ax[1];var B=ax[2]
		var c=(lo+hi)*0.5
		# oben: die Seite, deren oberste Scheibe über die längere Strecke reicht (Gehäuse/Lauf statt Griff/Magazin)
		var ext=func(side:int)->float:
			var a=INF;var b=-INF
			for v in V:
				var h=(v[H]-c[H])*side
				if h>size[H]*0.32:a=min(a,v[L]);b=max(b,v[L])
			return b-a if b>a else 0.0
		var up=1 if ext.call(1)>=ext.call(-1) else -1
		if d.get("oben_umkehren",false):up=-up
		# vorne: das Ende mit der kleineren Höhe (Lauf/Klinge ist schmaler als Griffstück/Schaft)
		var hgt=func(side:int)->float:
			var a=INF;var b=-INF
			for v in V:
				if (v[L]-c[L])*side>size[L]*0.4:a=min(a,v[H]);b=max(b,v[H])
			return b-a if b>a else 0.0
		var fw=1 if hgt.call(1)<=hgt.call(-1) else -1
		if d.get("vorne_umkehren",false):fw=-fw
		# Basis: Modellachsen -> Waffenachsen (x rechts, y oben, z vorne)
		var off=mean if E[0]!=Vector3.RIGHT or V0!=V else Vector3.ZERO
		var ez=E[L]*fw
		var ey=E[H]*up
		var ex=ey.cross(ez)
		var basis=Basis(ex,ey,ez).inverse()   # Modell -> Waffe
		# Mittelpunkt (in Modellkoordinaten)
		var cm=(off if V0!=V else Vector3.ZERO)
		var mid=(lo+hi)*0.5
		if V0!=V:cm=mean+E[0]*mid.x+E[1]*mid.y+E[2]*mid.z
		else:cm=mid
		c=cm
		var s=d.laenge/size[L]
		# Griffpunkt in Waffenkoordinaten
		var P=PackedVector3Array()
		for v in V0:P.append(basis*(v-c)*s)
		var plo=P[0];var phi=P[0]
		for p in P:plo=plo.min(p);phi=phi.max(p)
		var gz=lerp(plo.z,phi.z,d.griff);var vz=lerp(plo.z,phi.z,d.get("vorn",d.griff))
		var slice=func(z:float)->Vector2:
			var a=INF;var b=-INF
			for p in P:
				if abs(p.z-z)<d.laenge*0.03:a=min(a,p.y);b=max(b,p.y)
			return Vector2(a,b)
		var gs=slice.call(gz);var vs=slice.call(vz)
		var griff=Vector3(0,gs.x+(gs.y-gs.x)*0.45,gz)
		if d.typ=="nah":griff=Vector3(0,(gs.x+gs.y)*0.5,gz)
		var vorn=Vector3(0,vs.x+(vs.y-vs.x)*0.35,vz)
		var top=slice.call(phi.z-d.laenge*0.02)
		var mund=Vector3(0,(top.x+top.y)*0.5,phi.z)
		# Ausgabe
		var out=Node3D.new();out.name=id
		src.get_parent().remove_child(src)
		var holder=Node3D.new();holder.name="Modell";out.add_child(holder);holder.add_child(src)
		holder.transform=Transform3D(Basis().scaled(Vector3.ONE*s)*basis,-griff+basis*(-c)*s)
		holder.transform=Transform3D(basis.scaled(Vector3.ONE*s),Vector3.ZERO)
		holder.transform.origin=-(holder.transform.basis*c)-griff
		out.set_meta("vorn",vorn-griff);out.set_meta("muendung",mund-griff);out.set_meta("laenge",d.laenge)
		# unsichtbare Teile entfernen (Paket)
		for m in src.find_children("*","MeshInstance3D",true,false):
			if not m.visible:m.get_parent().remove_child(m);m.free()
		_own(out,out)
		var ps=PackedScene.new();ps.pack(out)
		ResourceSaver.save(ps,"res://assets/cache/waffen/"+id+".scn",ResourceSaver.FLAG_COMPRESS)
		print(id," L=",snapped(size[L],0.001)," s=",snapped(s,0.0001)," up=",up," fw=",fw," vorn=",(vorn-griff).snapped(Vector3.ONE*0.01)," mund=",(mund-griff).snapped(Vector3.ONE*0.01))
		out.free()
	quit()

# Skin-Mesh in seiner aktuellen Knochenpose als statisches Mesh (im lokalen Raum der MeshInstance)
func _entskinnen(m:MeshInstance3D,root:Node3D)->ArrayMesh:
	var sk:Skeleton3D=m.get_node_or_null(m.skeleton)
	if sk==null or m.skin==null:return null
	var skin:Skin=m.skin
	var mats=[]
	for i in skin.get_bind_count():
		var b=skin.get_bind_bone(i)
		if b<0:b=sk.find_bone(skin.get_bind_name(i))
		mats.append(sk.get_bone_global_pose(max(b,0))*skin.get_bind_pose(i))
	var to_local=F.rel_xf(m,root).affine_inverse()*F.rel_xf(sk,root)
	var out=ArrayMesh.new()
	for si in m.mesh.get_surface_count():
		var a=m.mesh.surface_get_arrays(si)
		var V:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var N=a[Mesh.ARRAY_NORMAL]
		var BO=a[Mesh.ARRAY_BONES];var WE=a[Mesh.ARRAY_WEIGHTS]
		if BO==null or WE==null:out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);continue
		var k=BO.size()/V.size()
		var V2=PackedVector3Array();V2.resize(V.size())
		var N2=PackedVector3Array();if N!=null:N2.resize(V.size())
		for vi in V.size():
			var p=Vector3.ZERO;var n=Vector3.ZERO;var ws=0.0
			for j in k:
				var w=WE[vi*k+j]
				if w<=0.0:continue
				var t:Transform3D=mats[BO[vi*k+j]]
				p+=(t*V[vi])*w;ws+=w
				if N!=null:n+=(t.basis*N[vi])*w
			if ws>0.0:p/=ws
			else:p=V[vi]
			V2[vi]=to_local*p
			if N!=null:N2[vi]=(to_local.basis*n).normalized() if n.length()>0.0 else N[vi]
		a[Mesh.ARRAY_VERTEX]=V2
		if N!=null:a[Mesh.ARRAY_NORMAL]=N2
		a[Mesh.ARRAY_BONES]=null;a[Mesh.ARRAY_WEIGHTS]=null;a[Mesh.ARRAY_TANGENT]=null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	return out

func _own(n:Node,r:Node):
	for c in n.get_children():
		c.owner=r;c.scene_file_path="";_own(c,r)
