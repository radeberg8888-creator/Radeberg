extends RefCounted
# Bodykit-Generator: vermisst die echte Karosserie eines Autos (Punktwolke) und baut daraus
# Frontschürze, Seitenschweller, Heckschürze, Spoiler, Hutzen, die der Kontur folgen.
# Alles in "Fahrzeugrahmen": Front = +Z, Boden y=0, Mitte x=0.
const F=preload("res://scripts/fit.gd")

const SKIP=["tire","tyre","wheel","rim","reifen","felge","rubber","side_wall","disk","glass","window","interior","seat","steer","brake","light","lamp","plate","carpet","floor","shadow","engine","chassis","under"]
const WHEELM=["tire","tyre","wheel","rim","reifen","felge","rubber","side_wall","sidewall","disk","rotor"]

class Shape:
	var L:float;var W:float;var H:float;var cz:float
	var zf:PackedFloat32Array;var zr:PackedFloat32Array   # Front-/Heckkontur je x-Spalte (Stoßfängerhöhe)
	var yb_f:float;var yb_r:float                          # Unterkante vorn/hinten
	var xs:PackedFloat32Array;var ys:PackedFloat32Array    # Seitenkontur je z-Zeile, Schwellerunterkante
	var top:Array                                          # ymax[z][x]
	var nx:=24;var nz:=48
	var x0:float;var z0:float;var dx:float;var dz:float
	var wheels:Array=[]                                    # [Vector3 Mitte, Radius, Außenseite x]
	func xi(x:float)->int:return clampi(int((x-x0)/dx),0,nx-1)
	func zi(z:float)->int:return clampi(int((z-z0)/dz),0,nz-1)
	func xc(i:int)->float:return x0+(i+0.5)*dx
	func zc(i:int)->float:return z0+(i+0.5)*dz
	func top_at(x:float,z:float)->float:return top[zi(z)][xi(x)]

static var cache:={}

static func _pts(car:Node3D,rot:Basis)->Array:
	var body=PackedVector3Array();var wheel=PackedVector3Array()
	for m in car.find_children("*","MeshInstance3D",true,false):
		if not m.visible or m.has_meta("tuning_part"):continue
		var xf=Transform3D(rot,Vector3())*F.rel_xf(m,car)
		for s in m.mesh.get_surface_count():
			var mt=m.get_active_material(s);var nm=(mt.resource_name if mt else "").to_lower()+" "+str(m.name).to_lower()
			var is_w=WHEELM.any(func(k):return nm.contains(k)) and not nm.contains("steer")
			var skip=SKIP.any(func(k):return nm.contains(k))
			if skip and not is_w:continue
			var v:PackedVector3Array=m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var step=max(1,v.size()/6000)
			for i in range(0,v.size(),step):
				var p=xf*v[i]
				if is_w:wheel.append(p)
				else:body.append(p)
	return [body,wheel]

static func measure(car:Node3D)->Shape:
	var key=car.get_meta("kind","")+str(car.get_instance_id())
	if cache.has(key):return cache[key]
	var f:float=car.get_meta("front",1.0)
	var rot=Basis() if f>0 else Basis(Vector3.UP,PI)
	var pp=_pts(car,rot);var P:PackedVector3Array=pp[0];var WP:PackedVector3Array=pp[1]
	var S=Shape.new()
	var lo=Vector3(INF,INF,INF);var hi=-lo
	for p in P:lo=lo.min(p);hi=hi.max(p)
	S.L=hi.z-lo.z;S.W=hi.x-lo.x;S.H=hi.y;S.cz=(hi.z+lo.z)*0.5
	S.x0=lo.x;S.z0=lo.z;S.dx=S.W/S.nx;S.dz=S.L/S.nz
	S.zf=PackedFloat32Array();S.zr=PackedFloat32Array();S.zf.resize(S.nx);S.zr.resize(S.nx)
	for i in S.nx:S.zf[i]=-INF;S.zr[i]=INF
	S.xs=PackedFloat32Array();S.xs.resize(S.nz);S.ys=PackedFloat32Array();S.ys.resize(S.nz)
	for i in S.nz:S.xs[i]=0.0;S.ys[i]=INF
	S.top=[];for i in S.nz:
		var row=PackedFloat32Array();row.resize(S.nx);row.fill(0.0);S.top.append(row)
	var yb_f=INF;var yb_r=INF
	for p in P:
		var ix=S.xi(p.x);var iz=S.zi(p.z)
		if p.y<S.H*0.42:
			S.zf[ix]=max(S.zf[ix],p.z);S.zr[ix]=min(S.zr[ix],p.z)
		if p.y>0.08 and p.y<S.H*0.45:S.xs[iz]=max(S.xs[iz],abs(p.x))
		if abs(p.x)>S.W*0.3 and p.y>0.06:S.ys[iz]=min(S.ys[iz],p.y)
		if p.y>S.top[iz][ix]:S.top[iz][ix]=p.y
		if p.z>hi.z-S.L*0.08 and p.y>0.05:yb_f=min(yb_f,p.y)
		if p.z<lo.z+S.L*0.08 and p.y>0.05:yb_r=min(yb_r,p.y)
	S.yb_f=yb_f if yb_f<INF else 0.2;S.yb_r=yb_r if yb_r<INF else 0.22
	# leere Spalten auffüllen, glätten
	_fill(S.zf,hi.z-0.05);_fill(S.zr,lo.z+0.05);S.zf=_smooth(S.zf,2);S.zr=_smooth(S.zr,2)
	_fill(S.xs,S.W*0.45);S.xs=_smooth(S.xs,2)
	for i in S.nz:if S.ys[i]==INF:S.ys[i]=0.25
	# Räder: Radpunkte in 4 Viertel teilen
	var q={};for p in WP:
		if p.y>S.H*0.7:continue
		var k=Vector2i(1 if p.x>0 else -1,1 if p.z>S.cz else -1)
		if not q.has(k):q[k]=[Vector3(INF,INF,INF),-Vector3(INF,INF,INF),0]
		q[k][0]=q[k][0].min(p);q[k][1]=q[k][1].max(p);q[k][2]+=1
	for k in [Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		if q.has(k) and q[k][2]>30:
			var a:Vector3=q[k][0];var b:Vector3=q[k][1]
			var r=max(b.y-a.y,b.z-a.z)*0.5
			if r>0.2 and r<0.7:
				S.wheels.append([Vector3((a.x+b.x)*0.5,r,(a.z+b.z)*0.5),r,b.x if k.x>0 else a.x]);continue
		# Schätzung, falls kein Rad erkannt
		var r2=clamp(S.H*0.24,0.3,0.42)
		S.wheels.append([Vector3(k.x*(S.W*0.5-0.12),r2,S.cz+k.y*S.L*0.31),r2,k.x*(S.W*0.5-0.03)])
	cache[key]=S
	return S

static func _fill(a:PackedFloat32Array,dflt:float):
	for i in a.size():
		if a[i]==INF or a[i]==-INF:a[i]=dflt
static func _smooth(a:PackedFloat32Array,it:int)->PackedFloat32Array:
	var b=a.duplicate()
	for k in it:
		var c=b.duplicate()
		for i in range(1,b.size()-1):c[i]=(b[i-1]+b[i]*2+b[i+1])*0.25
		b=c
	return b

# ---------- Geometrie: Profil entlang eines Pfades extrudieren ----------
# path: Punkte, out: Außenrichtung je Punkt (in xz), prof: Vector2(außen, hoch)
static func extrude(st:SurfaceTool,path:Array,out:Array,prof:Array,cap:=true):
	var rings=[]
	for i in path.size():
		var r=[];var n:Vector3=out[i]
		for p in prof:r.append(path[i]+n*p.x+Vector3.UP*p.y)
		rings.append(r)
	var m=prof.size()
	for i in path.size()-1:
		for j in m:
			var a=rings[i][j];var b=rings[i][(j+1)%m];var c=rings[i+1][(j+1)%m];var d=rings[i+1][j]
			st.add_vertex(a);st.add_vertex(b);st.add_vertex(c);st.add_vertex(a);st.add_vertex(c);st.add_vertex(d)
	if cap:
		for e in [0,path.size()-1]:
			for j in range(1,m-1):
				st.add_vertex(rings[e][0]);st.add_vertex(rings[e][j]);st.add_vertex(rings[e][j+1])

static func mesh_of(st:SurfaceTool)->ArrayMesh:
	st.index();st.generate_normals();return st.commit()
static func new_st()->SurfaceTool:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0);return st

static func _add(kit:Node3D,mesh:Mesh,mat:Material)->MeshInstance3D:
	var mi=MeshInstance3D.new();mi.mesh=mesh;mi.material_override=mat;kit.add_child(mi);return mi
static func _box(kit:Node3D,size:Vector3,pos:Vector3,mat:Material,rot:=Vector3())->MeshInstance3D:
	var b=BoxMesh.new();b.size=size;var mi=_add(kit,b,mat);mi.position=pos;mi.rotation=rot;return mi

# ---------- Teile ----------
# Frontschürze: 0 Serie, 1 Lippe, 2 Sport, 3 Race (Splitter + Canards), 4 Extrem
static func front(kit:Node3D,S:Shape,style:int,paint:Material,carbon:Material,dark:Material):
	# Die Schürze selbst entsteht durch Verformung der Karosserie (deform.gd). Hier nur der Carbon-Splitter darunter.
	if style<3:return
	var drop=[0,0.03,0.05,0.07,0.09][style];var push=[0,0.012,0.025,0.04,0.055][style]
	var y0=S.yb_f-drop-0.004
	var path=[];var out=[]
	for i in range(2,S.nx-2):path.append(Vector3(S.xc(i)*0.93,y0,S.zf[i]+push-0.06))
	for i in path.size():
		var a=path[max(i-1,0)];var b=path[min(i+1,path.size()-1)];var t=(b-a).normalized()
		var n=Vector3(t.z,0,-t.x).normalized()
		if n.z<0:n=-n
		out.append(n)
	var w=0.07 if style==3 else 0.11
	var st=new_st();extrude(st,path,out,[Vector2(-0.02,-0.012),Vector2(w,-0.012),Vector2(w,0.0),Vector2(-0.02,0.0)]);_add(kit,mesh_of(st),carbon)

# Seitenschweller: 0 Serie, 1 Street, 2 Sport, 3 Race, 4 Extrem (mit Luftleitblechen)
static func side(kit:Node3D,S:Shape,style:int,paint:Material,carbon:Material):
	# Schweller entstehen durch Verformung; ab Race zusätzlich eine schmale Carbonlippe unten.
	if style<3:return
	var drop=[0,0.02,0.035,0.05,0.065][style];var o=[0,0.008,0.016,0.026,0.036][style]
	var fw=-INF;var rw=INF
	for w in S.wheels:
		if w[0].z>S.cz:fw=w[0].z-w[1]*1.08 if fw==-INF else max(fw,w[0].z-w[1]*1.08)
		else:rw=w[0].z+w[1]*1.08 if rw==INF else min(rw,w[0].z+w[1]*1.08)
	if fw==-INF or rw==INF or fw-rw<0.8:return
	for s in [-1,1]:
		var path=[];var out=[];var n=12
		for k in n+1:
			var z=lerp(rw+0.05,fw-0.05,float(k)/n);var iz=S.zi(z)
			path.append(Vector3(s*(S.xs[iz]+o-0.015),S.ys[iz]-drop-0.004,z));out.append(Vector3(s,0,0))
		var st=new_st();extrude(st,path,out,[Vector2(-0.03,-0.01),Vector2(0.035 if style==3 else 0.05,-0.01),Vector2(0.035 if style==3 else 0.05,0.0),Vector2(-0.03,0.0)]);_add(kit,mesh_of(st),carbon)

# Heckschürze: 0 Serie, 1 Lippe, 2 Sport-Diffusor, 3 Race-Diffusor, 4 Extrem
static func rear(kit:Node3D,S:Shape,style:int,paint:Material,carbon:Material,dark:Material):
	# Heckschürze durch Verformung; ab Sport ein Diffusor unter dem Stoßfänger (Finnen bleiben unterhalb der Kante).
	if style<2:return
	var drop=[0,0.025,0.045,0.065,0.085][style];var push=[0,0.01,0.02,0.035,0.05][style]
	var y0=S.yb_r-drop
	var zr=S.zr[S.nx/2]-push
	var depth=0.32
	_box(kit,Vector3(S.W*0.56,0.012,depth),Vector3(0,y0-0.006,zr+depth*0.5+0.02),carbon)
	var n=[0,0,4,6,8][style];var h=[0,0,0.05,0.065,0.08][style]
	for k in n:
		var x=-S.W*0.26+k*(S.W*0.52/(n-1))
		_box(kit,Vector3(0.01,h,depth*0.9),Vector3(x,y0-0.006+h*0.5,zr+depth*0.5+0.02),carbon)

# Spoiler: 0 kein, 1 Abrisskante, 2 Street-Flügel, 3 GT-Flügel (Schwanenhals), 4 Big Wing (Doppelflügel), 5 Drift-Flügel (hoch, breit)
static func spoiler(kit:Node3D,S:Shape,style:int,paint:Material,carbon:Material):
	if style<=0:return
	# Heckdeckel: hintere 4-14 % der Länge, höchster Punkt in Fahrzeugmitte, aber unter Dachhöhe
	var z_edge=S.zr[S.nx/2]+S.L*0.05
	var roof=0.0
	for iz in S.nz:roof=max(roof,S.top[iz][S.nx/2])
	var deck=S.top_at(0,z_edge)
	for k in 6:
		var z=z_edge+k*S.L*0.02;var y=S.top_at(0,z)
		if y<roof*0.92:deck=max(deck,y)
	if style==1:return   # Abrisskante: Verformung der Heckklappe (deform.gd)
	if false:
		var path=[];var out=[]
		for i in range(3,S.nx-3):
			var x=S.xc(i);path.append(Vector3(x,S.top_at(x,z_edge+0.04)-0.005,z_edge+0.04));out.append(Vector3(0,0,-1))
		var st=new_st();extrude(st,path,out,[Vector2(-0.03,0),Vector2(0.08,0),Vector2(0.09,0.06),Vector2(0.06,0.06),Vector2(-0.03,0.015)]);_add(kit,mesh_of(st),paint)
		return
	var span=[0,0,S.W*0.86,S.W*0.98,S.W*1.04,S.W*1.08][style]
	var chord=[0,0,0.24,0.3,0.34,0.3][style]
	var hgt=[0,0,0.13,0.26,0.36,0.42][style]
	var zw=z_edge+0.12
	var yw=deck+hgt
	var foil=_airfoil(chord,0.035 if style<4 else 0.04)
	var mat=paint if style==2 else carbon
	_wing(kit,foil,span,Vector3(0,yw,zw),-0.1 if style<4 else -0.16,mat)
	if style==4:  # zweites Element (Gurney-Flap)
		_wing(kit,_airfoil(chord*0.55,0.025),span*0.98,Vector3(0,yw+0.06,zw-chord*0.5),-0.45,carbon)
	# Halter
	for s in [-1,1]:
		var mx=s*span*(0.3 if style!=5 else 0.36);var by=S.top_at(mx,zw)
		if style==3 or style==4:  # Schwanenhals: von oben gehalten
			_box(kit,Vector3(0.025,yw-by+0.06,0.09),Vector3(mx,(yw+by)*0.5+0.03,zw+0.04),carbon,Vector3(0.18,0,0))
		else:
			_box(kit,Vector3(0.035,yw-by,0.12),Vector3(mx,(yw+by)*0.5,zw),mat)
	# Endplatten
	if style>=3:
		for s in [-1,1]:
			var ep=new_st();var w=chord*1.35;var h=0.16 if style==3 else 0.24
			var poly=[Vector2(-w*0.5,-h*0.45),Vector2(w*0.55,-h*0.3),Vector2(w*0.5,h*0.55),Vector2(-w*0.4,h*0.4)]
			var path=[Vector3(s*span*0.5,yw,zw),Vector3(s*(span*0.5+0.012),yw,zw)]
			_plate(ep,poly,s*span*0.5,yw,zw,0.012);_add(kit,mesh_of(ep),carbon)

static func _airfoil(c:float,t:float)->Array:
	var up=[];var lo=[]
	for k in 9:
		var x=float(k)/8.0
		var yt=5*t/c*c*(0.2969*sqrt(x)-0.126*x-0.3516*x*x+0.2843*x*x*x-0.1015*x*x*x*x)*2.4
		up.append(Vector2(-(x-0.5)*c,yt+0.02*c*sin(PI*x)));lo.append(Vector2(-(x-0.5)*c,-yt*0.6+0.02*c*sin(PI*x)))
	lo.reverse()
	return up+lo
static func _wing(kit:Node3D,foil:Array,span:float,c:Vector3,angle:float,mat:Material):
	var st=new_st()
	var path=[Vector3(-span*0.5,0,0),Vector3(span*0.5,0,0)];var out=[Vector3(0,0,1),Vector3(0,0,1)]
	# Profil liegt in (z, y): extrude erwartet (außen, hoch) -> außen = +z
	var rot=[];for p in foil:rot.append(Vector2(p.x*cos(angle)-p.y*sin(angle),p.x*sin(angle)+p.y*cos(angle)))
	extrude(st,path,out,rot);var mi=_add(kit,mesh_of(st),mat);mi.position=c
static func _plate(st:SurfaceTool,poly:Array,x:float,y:float,z:float,th:float):
	var a=[];var b=[]
	for p in poly:a.append(Vector3(x-th*0.5,y+p.y,z+p.x));b.append(Vector3(x+th*0.5,y+p.y,z+p.x))
	for j in range(1,poly.size()-1):
		st.add_vertex(a[0]);st.add_vertex(a[j]);st.add_vertex(a[j+1]);st.add_vertex(b[0]);st.add_vertex(b[j+1]);st.add_vertex(b[j])
	for j in poly.size():
		var k=(j+1)%poly.size()
		st.add_vertex(a[j]);st.add_vertex(b[j]);st.add_vertex(b[k]);st.add_vertex(a[j]);st.add_vertex(b[k]);st.add_vertex(a[k])

# Motorhaube: 0 Serie, 1 Lufthutze, 2 Doppelhutze, 3 Kiemen (Entlüftungsschlitze), 4 Carbon-Haube mit Hutze
static func hood(kit:Node3D,S:Shape,style:int,paint:Material,carbon:Material,dark:Material):
	if style<=0:return
	var zf=S.zf[S.nx/2];var zc=zf-S.L*0.18
	var y=S.top_at(0,zc)
	if style==1 or style==4:_scoop(kit,Vector3(0,y,zc),0.42,0.5,0.07,carbon if style==4 else paint,dark)
	if style==2:
		for s in [-1,1]:_scoop(kit,Vector3(s*S.W*0.17,S.top_at(s*S.W*0.17,zc),zc),0.22,0.42,0.06,paint,dark)
	if style==3:
		for s in [-1,1]:
			for k in 5:
				var z=zc-0.05+k*0.055;var x=s*S.W*0.2
				_box(kit,Vector3(0.24,0.012,0.022),Vector3(x,S.top_at(x,z)+0.004,z),dark,Vector3(-0.1,0,0))
	if style==4:  # Carbonfläche als dünne Auflage
		_box(kit,Vector3(S.W*0.5,0.006,S.L*0.18),Vector3(0,S.top_at(0,zc-0.15)+0.005,zc-0.05),carbon,Vector3(-0.08,0,0))
static func _scoop(kit:Node3D,p:Vector3,w:float,l:float,h:float,mat:Material,dark:Material):
	var st=new_st()
	# Keil: vorne offen (dunkel), hinten flach auslaufend
	var a=Vector3(-w*0.5,0,l*0.5);var b=Vector3(w*0.5,0,l*0.5);var c=Vector3(w*0.4,h,l*0.42);var d=Vector3(-w*0.4,h,l*0.42)
	var e=Vector3(-w*0.45,0,-l*0.5);var f=Vector3(w*0.45,0,-l*0.5)
	for t in [[d,c,f],[d,f,e],[a,d,e],[b,f,c]]:
		st.add_vertex(t[0]);st.add_vertex(t[1]);st.add_vertex(t[2])
	var mi=_add(kit,mesh_of(st),mat);mi.position=p
	_box(kit,Vector3(w*0.72,h*0.75,0.01),p+Vector3(0,h*0.45,l*0.47),dark)

# Dachhutze
static func roof_scoop(kit:Node3D,S:Shape,on:int,paint:Material,dark:Material):
	if on<=0:return
	var best=0;var by=0.0
	for iz in S.nz:
		if S.top[iz][S.nx/2]>by:by=S.top[iz][S.nx/2];best=iz
	var z=S.zc(best)+0.15
	_scoop(kit,Vector3(0,S.top_at(0,z),z),0.3,0.38,0.08,paint,dark)

# Kotflügelverbreiterung (Widebody): Radlauf-Bögen über allen 4 Rädern
static func fenders(kit:Node3D,S:Shape,on:int,paint:Material):
	return   # Widebody entsteht durch Verformung der Kotflügel (deform.gd)
