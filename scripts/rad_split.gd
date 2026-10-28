extends RefCounted
# Räder aus einem Automodell herauslösen (nur am PC beim Vorbereiten, nicht im Spiel):
# 1. Radpositionen + Radius finden (Reifen-Meshes nach Namen, sonst über die tiefsten Punkte)
# 2. alle Dreiecke innerhalb des Radzylinders in eigene Knoten "Rad_VL/VR/HL/HR" verschieben (Drehpunkt = Radmitte)
# Ergebnis-Meta "raeder": [{p:Vector3, r:float, vorne:bool, links:bool, breite:float}]
const F=preload("res://scripts/fit.gd")

static func _nm(m:MeshInstance3D)->String:
	var s=str(m.name)
	if m.mesh and m.mesh.get_surface_count()>0:
		var mt=m.get_active_material(0)
		if mt:s+=" "+mt.resource_name
	return s.to_lower()

static func _is_tire(nm:String)->bool:
	if nm.contains("steering") or nm.contains("lenkrad") or nm.contains("spare"):return false
	for k in ["wheel","tire","tyre","reifen","rim","felge","shina","koleso","disk"]:
		if nm.contains(k):return true
	if nm.contains("rubber") and not nm.contains("trim"):return true
	return false

static func _fixed(nm:String)->bool:   # dreht sich nicht mit (Bremssattel)
	if nm.contains("caliper") or nm.contains("clipper") or nm.contains("supp"):return true
	if nm.contains("brake") and not nm.contains("disk") and not nm.contains("disc"):return true
	return false

static func _verts(m:MeshInstance3D,xf:Transform3D)->PackedVector3Array:
	var out=PackedVector3Array()
	for s in m.mesh.get_surface_count():
		var a=m.mesh.surface_get_arrays(s)
		for v in a[Mesh.ARRAY_VERTEX]:out.append(xf*v)
	return out

# Radpositionen bestimmen
static func find(root:Node3D,override:={})->Array:
	var tot=F.aabb(root);var c=tot.get_center()
	var q={}   # quadrant -> [min,max]
	var have_named=false
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible or m.mesh==null:continue
		var nm=_nm(m)
		if not _is_tire(nm) or _fixed(nm):continue
		var xf=F.rel_xf(m,root)
		var a=xf*m.get_aabb()
		if a.size.y>1.4 or a.position.y>0.25 or a.size.y<0.3:continue
		if abs(a.size.y-a.size.z)>0.25*max(a.size.y,a.size.z):continue   # Reifen/Felge sind rund
		for v in _verts(m,xf):
			var k=Vector2i(1 if v.x>c.x else -1,1 if v.z>c.z else -1)
			if not q.has(k):q[k]=[v,v]
			else:q[k][0]=q[k][0].min(v);q[k][1]=q[k][1].max(v)
		have_named=true
	var named=[]
	if have_named and q.size()==4:
		for k in q:
			var lo:Vector3=q[k][0];var hi:Vector3=q[k][1]
			var r=(hi.y-lo.y)*0.5
			var p=Vector3((lo.x+hi.x)*0.5,lo.y+r,(lo.z+hi.z)*0.5)
			named.append({"p":p,"r":r,"vorne":k.y>0,"links":k.x>0,"breite":hi.x-lo.x,"xo":hi.x if k.x>0 else lo.x,"xi":lo.x if k.x>0 else hi.x})
	var geo=find_geo2(root)
	var spread=func(a:Array)->float:
		var rr=a.map(func(w):return w.r);return rr.max()-rr.min()
	var res=[]
	var m=override.get("methode","")
	if m=="geo" and geo.size()==4:res=geo
	elif m=="name" and named.size()==4:res=named
	elif named.size()==4 and spread.call(named)<0.05:res=named
	elif geo.size()==4:res=geo
	elif named.size()==4:res=named
	else:res=find_geo(root)
	if not override.get("roh",false):res=_konsistent(res)
	if override.has("r"):
		for w in res:w.p.y+=override.r-w.r;w.r=override.r
	if override.has("z"):   # Achspositionen von Hand (vorne, hinten)
		for w in res:w.p.z=override.z[0] if w.vorne else override.z[1]
	if override.has("x"):
		for w in res:
			var s=1.0 if w.links else -1.0
			w.xo=s*override.x;w.xi=w.xo-s*w.breite;w.p.x=w.xo-s*w.breite*0.5
	return res

# Reifen aus der Aufstandsfläche: tiefste Punkte je Viertel = unter der Achse; Krümmung des unteren Reifenbogens = Radius
static func find_geo2(root:Node3D)->Array:
	var all=PackedVector3Array()
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible or m.mesh==null:continue
		all.append_array(_verts(m,F.rel_xf(m,root)))
	var lo=all[0];var hi=all[0]
	for v in all:lo=lo.min(v);hi=hi.max(v)
	var c=(lo+hi)*0.5
	var res=[]
	for k in [Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		var q=[]
		for v in all:
			if (v.x-c.x)*k.x>0.15 and (v.z-c.z)*k.y>0.3:q.append(v)
		if q.is_empty():return []
		var ymin=INF
		for v in q:ymin=min(ymin,v.y)
		var cont=q.filter(func(v):return v.y<ymin+0.012)
		var zc=0.0;var x0=INF;var x1=-INF
		for v in cont:zc+=v.z/cont.size();x0=min(x0,v.x);x1=max(x1,v.x)
		# Radius aus dem unteren Bogen: r=(dz²+dy²)/(2dy)
		var rs=[]
		for v in q:
			var dy=v.y-ymin;var dz=v.z-zc
			if dy>0.01 and dy<0.13 and abs(dz)<0.45 and v.x>=x0-0.03 and v.x<=x1+0.03:
				var r=(dz*dz+dy*dy)/(2.0*dy)
				if r>0.18 and r<0.7:rs.append(r)
		if rs.size()<6:return []
		rs.sort()
		# häufigster Wert (Lauffläche) statt Mittel: Histogramm 1 cm
		var hist={}
		for r in rs:var b=int(r*100.0);hist[b]=hist.get(b,0)+1
		var best=0;var bn=0
		for b in hist:
			var n=hist[b]+hist.get(b-1,0)+hist.get(b+1,0)
			if n>bn:bn=n;best=b
		var r0=best/100.0+0.005
		var xo=x1 if k.x>0 else x0
		var br=clamp(x1-x0+0.04,0.15,0.42)
		res.append({"p":Vector3(xo-k.x*br*0.5,ymin+r0,zc),"r":r0,"vorne":k.y>0,"links":k.x>0,"breite":br,"xo":xo,"xi":xo-k.x*br})
	return res

# ohne Namen: Reifen geometrisch suchen (Kreis in der Seitenansicht, der den Boden berührt)
static func find_geo(root:Node3D)->Array:
	var all=PackedVector3Array()
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible or m.mesh==null:continue
		all.append_array(_verts(m,F.rel_xf(m,root)))
	var lo=all[0];var hi=all[0]
	for v in all:lo=lo.min(v);hi=hi.max(v)
	var c=(lo+hi)*0.5;var hw=(hi.x-lo.x)*0.5
	var res=[]
	for k in [Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		var pts=[]
		for v in all:
			if (v.x-c.x)*k.x>hw-0.38 and (v.z-c.z)*k.y>0.25 and v.y<lo.y+1.0:pts.append(v)
		if pts.is_empty():continue
		var ymin=INF
		for v in pts:ymin=min(ymin,v.y)
		var zs=[]
		for v in pts:
			if v.y<ymin+0.03:zs.append(v.z)
		zs.sort()
		var z0=zs[0];var z1=zs[-1]
		# nur Punkte nahe der Radstelle, höchstens ~2500
		var near=[]
		for v in pts:
			if v.z>z0-0.65 and v.z<z1+0.65 and v.y<ymin+1.0:near.append(Vector2(v.z,v.y-ymin))
		var stride=max(1,near.size()/2500)
		var P=[]
		for i in range(0,near.size(),stride):P.append(near[i])
		var best=[-1.0,0.0,0.0]
		var score=func(zc,r):
			var n=0.0
			for q in P:
				var d=Vector2(q.x-zc,q.y-r).length()
				if abs(d-r)<0.012:n+=1.0
			return n/r
		var zc=z0-0.1
		while zc<=z1+0.1:
			var r=0.24
			while r<0.55:
				var n=score.call(zc,r)
				if n>best[0]:best=[n,zc,r]
				r+=0.01
			zc+=0.02
		var bz=best[1];var br0=best[2]
		for dz in range(-3,4):
			for dr in range(-3,4):
				var n=score.call(bz+dz*0.006,br0+dr*0.003)
				if n>best[0]:best=[n,bz+dz*0.006,br0+dr*0.003]
		var r2=best[2];var zc2=best[1]
		# Breite: x-Ausdehnung der Randpunkte
		var xo=-INF*k.x;var xi=INF*k.x
		for v in pts:
			var d=Vector2(v.z-zc2,v.y-(ymin+r2)).length()
			if abs(d-r2)<0.015:
				if k.x>0:xo=max(xo,v.x);xi=min(xi,v.x)
				else:xo=min(xo,v.x);xi=max(xi,v.x)
		var br=clamp(abs(xo-xi),0.15,0.4)
		xi=xo-k.x*br
		res.append({"p":Vector3((xo+xi)*0.5,ymin+r2,zc2),"r":r2,"vorne":k.y>0,"links":k.x>0,"breite":br,"xo":xo,"xi":xi})
	return res

# Ausreißer korrigieren: gleicher Radius je Achse, links/rechts symmetrisch, Unterkante auf gemeinsamer Höhe
static func _konsistent(res:Array)->Array:
	if res.size()!=4:return res
	var rs=res.map(func(w):return w.r);rs.sort()
	var rm=(rs[1]+rs[2])*0.5
	var low=INF
	for w in res:
		if abs(w.r-rm)<=0.03:low=min(low,w.p.y-w.r)
	if low==INF:low=0.0
	for ax in [true,false]:
		var pr=res.filter(func(w):return w.vorne==ax)
		if pr.size()!=2:continue
		var good=pr.filter(func(w):return abs(w.r-rm)<=0.03)
		if good.is_empty():good=pr
		var r=0.0;var z=0.0;var b=0.0;var xo=0.0
		var cx=(pr[0].xo+pr[1].xo)*0.5
		for w in good:r+=w.r/good.size();z+=w.p.z/good.size();b+=clamp(w.breite,0.15,0.45)/good.size();xo+=abs(w.xo-cx)/good.size()
		if pr.size()==2 and abs(pr[0].p.z-pr[1].p.z)<0.12 and good.size()==2:z=(pr[0].p.z+pr[1].p.z)*0.5
		for w in pr:
			var s=1.0 if w.links else -1.0
			w.r=r;w.breite=b;w.xo=cx+s*xo;w.xi=cx+s*(xo-b);w.p=Vector3(cx+s*(xo-b*0.5),low+r,z)
	return res

static func _inside(v:Vector3,w:Dictionary,tol:float)->bool:
	var d=Vector2(v.y-w.p.y,v.z-w.p.z).length()
	if d>w.r*1.0+tol:return false
	var lo=min(w.xo,w.xi)-0.03;var hi=max(w.xo,w.xi)+0.03
	return v.x>=lo and v.x<=hi

# Dreiecke verschieben
static func split(root:Node3D,wheels:Array,tol:=0.02)->int:
	var pivots=[]
	for w in wheels:
		var pv=Node3D.new();pv.name="Rad_"+("V" if w.vorne else "H")+("L" if w.links else "R");root.add_child(pv);pv.position=w.p
		pivots.append(pv)
	var moved=0
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible or m.mesh==null or m.get_parent() in pivots:continue
		var nm=_nm(m)
		if _fixed(nm):continue
		var xf=F.rel_xf(m,root)
		var ab=xf*m.get_aabb()
		if ab.position.y>(wheels[0].p.y+wheels[0].r)*1.2:continue
		# ganzes Teil im Rad? -> komplett umhängen
		var whole=-1
		for i in wheels.size():
			var w=wheels[i]
			var ok=true
			for k in 8:
				if not _inside(ab.get_endpoint(k),w,tol+0.04):ok=false;break
			if ok:whole=i;break
		if whole>=0:
			var g=m.global_transform if m.is_inside_tree() else xf
			m.get_parent().remove_child(m);pivots[whole].add_child(m)
			m.transform=Transform3D(Basis(),-wheels[whole].p)*xf
			moved+=1;continue
		# sonst Dreiecke aufteilen
		var am:Mesh=m.mesh
		var rest=ArrayMesh.new();var parts=[]
		for i in wheels.size():parts.append(ArrayMesh.new())
		var any=false
		for s in am.get_surface_count():
			var arr=am.surface_get_arrays(s)
			var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
			var I:PackedInt32Array=arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(V.size()))
			var W=PackedVector3Array();W.resize(V.size())
			for j in V.size():W[j]=xf*V[j]
			var keep=PackedInt32Array();var take=[]
			for i in wheels.size():take.append(PackedInt32Array())
			for t in range(0,I.size(),3):
				var a=I[t];var b=I[t+1];var cc=I[t+2]
				var hit=-1
				for i in wheels.size():
					if _inside(W[a],wheels[i],tol) and _inside(W[b],wheels[i],tol) and _inside(W[cc],wheels[i],tol):hit=i;break
				if hit<0:keep.append_array([a,b,cc])
				else:take[hit].append_array([a,b,cc]);any=true
			var mat=m.get_active_material(s)
			if keep.size()>0:_add(rest,arr,keep,null,mat)
			for i in wheels.size():
				if take[i].size()>0:_add(parts[i],arr,take[i],Transform3D(Basis(),-wheels[i].p)*xf,mat)
		if not any:continue
		m.mesh=rest
		for i in wheels.size():
			if parts[i].get_surface_count()==0:continue
			var mi=MeshInstance3D.new();mi.mesh=parts[i];mi.name="Teil";pivots[i].add_child(mi)
			moved+=1
		# Material-Overrides gehen über surface material in rest mit
		for s in m.get_surface_override_material_count():m.set_surface_override_material(s,null)
	root.set_meta("raeder",wheels.map(func(w):return {"p":w.p,"r":w.r,"vorne":w.vorne,"links":w.links,"breite":w.breite}))
	return moved

# Teilmesh mit den gewählten Dreiecken (kompakt neu indiziert), optional in neuen Raum transformiert
static func _add(out:ArrayMesh,arr:Array,idx:PackedInt32Array,xf,mat):
	var remap={};var n=0
	var src_v:PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
	var newi=PackedInt32Array();newi.resize(idx.size())
	var order=PackedInt32Array()
	for k in idx.size():
		var o=idx[k]
		if not remap.has(o):remap[o]=n;order.append(o);n+=1
		newi[k]=remap[o]
	var na=[];na.resize(Mesh.ARRAY_MAX)
	var V=PackedVector3Array();V.resize(n)
	for k in n:V[k]=src_v[order[k]] if xf==null else xf*src_v[order[k]]
	na[Mesh.ARRAY_VERTEX]=V
	if arr[Mesh.ARRAY_NORMAL]!=null:
		var N=PackedVector3Array();N.resize(n);var sn:PackedVector3Array=arr[Mesh.ARRAY_NORMAL]
		for k in n:N[k]=sn[order[k]] if xf==null else (xf.basis.inverse().transposed()*sn[order[k]]).normalized()
		na[Mesh.ARRAY_NORMAL]=N
	if arr[Mesh.ARRAY_TANGENT]!=null:
		var T=PackedFloat32Array();T.resize(n*4);var st:PackedFloat32Array=arr[Mesh.ARRAY_TANGENT]
		for k in n:
			var o=order[k]
			var tv=Vector3(st[o*4],st[o*4+1],st[o*4+2])
			if xf!=null:tv=(xf.basis*tv).normalized()
			T[k*4]=tv.x;T[k*4+1]=tv.y;T[k*4+2]=tv.z;T[k*4+3]=st[o*4+3]
		na[Mesh.ARRAY_TANGENT]=T
	for ch in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
		if arr[ch]!=null:
			var U=PackedVector2Array();U.resize(n);var su:PackedVector2Array=arr[ch]
			for k in n:U[k]=su[order[k]]
			na[ch]=U
	if arr[Mesh.ARRAY_COLOR]!=null:
		var C=PackedColorArray();C.resize(n);var sc:PackedColorArray=arr[Mesh.ARRAY_COLOR]
		for k in n:C[k]=sc[order[k]]
		na[Mesh.ARRAY_COLOR]=C
	if xf!=null and xf.basis.determinant()<0:
		for k in range(0,newi.size(),3):var t=newi[k+1];newi[k+1]=newi[k+2];newi[k+2]=t
	na[Mesh.ARRAY_INDEX]=newi
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,na)
	if mat:out.surface_set_material(out.get_surface_count()-1,mat)
