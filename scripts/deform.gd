extends RefCounted
# Bodykit durch Verformung der echten Karosserie: Frontschürze, Seitenschweller, Heckschürze,
# Widebody (ausgestellte Kotflügel), Abrisskante, Tieferlegung. Dadurch sitzt alles nahtlos am Auto,
# im selben Lack und mit derselben Oberfläche. Die Originalmeshes werden gemerkt und vor jeder Änderung wiederhergestellt.
const F=preload("res://scripts/fit.gd")
const K=preload("res://scripts/kitgen.gd")

static func _ss(t:float)->float:
	t=clamp(t,0.0,1.0);return t*t*(3.0-2.0*t)

static func is_wheel(nm:String)->bool:
	return K.WHEELM.any(func(k):return nm.contains(k)) and not nm.contains("steer")

# Originale wiederherstellen
static func restore(car:Node3D):
	for m in car.find_children("*","MeshInstance3D",true,false):
		if m.has_meta("orig_mesh"):m.mesh=m.get_meta("orig_mesh")

# Verschiebung eines Punktes (Fahrzeugrahmen: Front +Z) für die Karosserie
static func body_offset(p:Vector3,S,c:Dictionary,zF:float,zR:float)->Vector3:
	var d=Vector3()
	var hw=S.W*0.5
	var ax=abs(p.x);var sx=sign(p.x) if p.x!=0 else 1.0
	# Radläufe schützen (dort nicht nach unten ziehen)
	var arch=1.0
	for w in S.wheels:
		var dd=Vector2(p.y-w[0].y,p.z-w[0].z).length()
		arch=min(arch,_ss((dd-w[1]*1.02)/(w[1]*0.25)))
	# Frontschürze
	if c.front>0:
		var drop=[0,0.03,0.05,0.07,0.09][c.front];var push=[0,0.012,0.025,0.04,0.055][c.front]
		var wz=_ss((p.z-(zF-0.55))/0.55)
		var wb=1.0-_ss((p.y-S.yb_f)/0.32)
		var w=wz*wb*arch
		d.y-=drop*w;d.z+=push*w*wz
		if c.front>=3:d.x+=sx*0.018*w*pow(ax/hw,2)
	# Heckschürze
	if c.rear>0:
		var drop=[0,0.025,0.045,0.065,0.085][c.rear];var push=[0,0.01,0.02,0.035,0.05][c.rear]
		var wz=_ss(((zR+0.5)-p.z)/0.5)
		var wb=1.0-_ss((p.y-S.yb_r)/0.3)
		var w=wz*wb*arch
		d.y-=drop*w;d.z-=push*w*wz
	# Seitenschweller (zwischen den Radläufen)
	if c.side>0:
		var drop=[0,0.02,0.035,0.05,0.065][c.side];var out=[0,0.008,0.016,0.026,0.036][c.side]
		var iz=S.zi(p.z);var sill=S.ys[iz]
		var wx=_ss((ax-hw*0.62)/(hw*0.3))
		var wb=1.0-_ss((p.y-sill)/0.26)
		var w=wx*wb*arch
		d.y-=drop*w;d.x+=sx*out*w
	# Widebody: Kotflügel um die Räder herum ausstellen
	if c.widebody>0:
		for wh in S.wheels:
			if sign(wh[0].x)!=sx:continue
			var dd=Vector2(p.y-wh[0].y,p.z-wh[0].z).length()
			var w=(1.0-_ss((dd-wh[1]*1.0)/(wh[1]*0.85)))*_ss((ax-hw*0.5)/(hw*0.3))*(1.0-_ss((p.y-(wh[0].y+wh[1]*1.45))/0.15))
			d.x+=sx*0.07*w
	# Abrisskante: Heckdeckelkante hochziehen
	if c.spoiler==1:
		var deck=S.top_at(0,zR+S.L*0.06)
		var wz=1.0-_ss((p.z-zR)/0.5)
		var wy=_ss((p.y-(deck-0.14))/0.12)*(1.0-_ss((p.y-(deck+0.06))/0.05))
		var w=wz*wy*_ss((hw*0.92-ax)/(hw*0.2))
		d.y+=0.05*w;d.z-=0.02*w
	# Tieferlegung
	d.y-=[0.0,0.03,0.06][c.lowering]
	return d

static func apply(car:Node3D,S,c:Dictionary):
	restore(car)
	var need=c.front>0 or c.rear>0 or c.side>0 or c.widebody>0 or c.spoiler==1 or c.lowering>0
	if not need:return
	var f:float=car.get_meta("front",1.0)
	var rot=Basis() if f>0 else Basis(Vector3.UP,PI)
	var zF=-INF;var zR=INF
	for i in S.nx:zF=max(zF,S.zf[i]);zR=min(zR,S.zr[i])
	for m in car.find_children("*","MeshInstance3D",true,false):
		if m.has_meta("tuning_part") or m.mesh==null or not (m.mesh is ArrayMesh):continue
		var orig:ArrayMesh=m.get_meta("orig_mesh") if m.has_meta("orig_mesh") else m.mesh
		var X:Transform3D=Transform3D(rot,Vector3())*F.rel_xf(m,car);var Xi=X.affine_inverse()
		var nm=ArrayMesh.new();var changed=false
		for s in orig.get_surface_count():
			var arr=orig.surface_get_arrays(s)
			var mt=orig.surface_get_material(s)
			var name=((mt.resource_name if mt else "")+" "+str(m.name)).to_lower()
			var v:PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
			var wheel=is_wheel(name)
			if wheel and c.widebody==0:
				nm.add_surface_from_arrays(orig.surface_get_primitive_type(s),arr);nm.surface_set_material(nm.get_surface_count()-1,mt);continue
			for i in v.size():
				var p=X*v[i]
				var dp:Vector3
				if wheel:dp=Vector3(sign(p.x)*0.06,0,0)   # Räder mit nach außen (Widebody)
				else:dp=body_offset(p,S,c,zF,zR)
				if dp!=Vector3():v[i]=Xi*(p+dp);changed=true
			arr[Mesh.ARRAY_VERTEX]=v
			nm.add_surface_from_arrays(orig.surface_get_primitive_type(s),arr);nm.surface_set_material(nm.get_surface_count()-1,mt)
		if changed:
			if not m.has_meta("orig_mesh"):m.set_meta("orig_mesh",orig)
			m.mesh=nm
