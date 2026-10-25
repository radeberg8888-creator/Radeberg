extends RefCounted
# Felgen-Generator: 8 Designs, Achse entlang +X (Außenseite), Radius 1 -> beim Einsetzen skaliert.
const DESIGNS=["Fünfspeichen","Y-Speichen","Zehnspeichen","Kreuzspeichen","Turbine","Tiefbett","Monoblock","Stahlfelge"]
static var cache:={}

static func _st()->SurfaceTool:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);return st
static func _cyl(st:SurfaceTool,r0:float,r1:float,x0:float,x1:float,seg:=40):
	# Rohr/Scheibe: Mantel zwischen Radius r0 bei x0 und r1 bei x1
	for i in seg:
		var a=TAU*i/seg;var b=TAU*(i+1)/seg
		var p0=Vector3(x0,cos(a)*r0,sin(a)*r0);var p1=Vector3(x0,cos(b)*r0,sin(b)*r0);var p2=Vector3(x1,cos(b)*r1,sin(b)*r1);var p3=Vector3(x1,cos(a)*r1,sin(a)*r1)
		st.add_vertex(p0);st.add_vertex(p1);st.add_vertex(p2);st.add_vertex(p0);st.add_vertex(p2);st.add_vertex(p3)
static func _ring(st:SurfaceTool,ri:float,ro:float,x:float,seg:=40):
	for i in seg:
		var a=TAU*i/seg;var b=TAU*(i+1)/seg
		var p0=Vector3(x,cos(a)*ri,sin(a)*ri);var p1=Vector3(x,cos(b)*ri,sin(b)*ri);var p2=Vector3(x,cos(b)*ro,sin(b)*ro);var p3=Vector3(x,cos(a)*ro,sin(a)*ro)
		st.add_vertex(p0);st.add_vertex(p2);st.add_vertex(p1);st.add_vertex(p0);st.add_vertex(p3);st.add_vertex(p2)
static func _spoke(st:SurfaceTool,ang:float,r0:float,r1:float,w0:float,w1:float,x0:float,x1:float,twist:=0.0):
	# Speiche als Quader zwischen Nabe (r0) und Felgenhorn (r1), Breite w0 -> w1, Tiefe x0..x1 (x1 = außen)
	var corners=[]
	for rr in [[r0,w0,0.0],[r1,w1,twist]]:
		var a=ang+rr[2];var d=Vector3(0,cos(a),sin(a));var s=Vector3(0,-sin(a),cos(a))
		for xx in [x0,x1]:
			corners.append(Vector3(xx,0,0)+d*rr[0]-s*rr[1]*0.5);corners.append(Vector3(xx,0,0)+d*rr[0]+s*rr[1]*0.5)
	# Indizes: inner(x0:l,r, x1:l,r) outer(x0:l,r, x1:l,r)
	var q=[[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5],[0,2,3,1],[4,5,7,6]]
	for f in q:
		st.add_vertex(corners[f[0]]);st.add_vertex(corners[f[1]]);st.add_vertex(corners[f[2]])
		st.add_vertex(corners[f[0]]);st.add_vertex(corners[f[2]]);st.add_vertex(corners[f[3]])

# liefert [Felgenkörper-Mesh, Dunkel-Mesh (Innenraum/Löcher)]
static func make(design:int)->Array:
	if cache.has(design):return cache[design]
	var st=_st();var dk=_st()
	var face=0.0
	_cyl(st,1.0,1.0,-0.45,face-0.02)          # Felgenbett
	_ring(st,0.9,1.02,face)                    # Felgenhorn außen
	_cyl(st,1.02,1.02,face-0.05,face)
	_ring(dk,0.0,0.92,-0.42)                   # dunkler Innenraum
	var hub=0.22
	_cyl(st,hub,hub*0.9,face-0.18,face+0.02);_ring(st,0.0,hub*0.9,face+0.02)
	match design:
		0:for i in 5:_spoke(st,TAU*i/5,hub,0.92,0.2,0.26,face-0.12,face-0.02)
		1:for i in 5:
			_spoke(st,TAU*i/5,hub,0.55,0.16,0.12,face-0.12,face-0.02)
			for s in [-1,1]:_spoke(st,TAU*i/5+s*0.13,0.5,0.92,0.08,0.09,face-0.11,face-0.02)
		2:for i in 10:_spoke(st,TAU*i/10,hub,0.92,0.07,0.1,face-0.1,face-0.02)
		3:for i in 10:
			_spoke(st,TAU*i/10,hub,0.92,0.04,0.05,face-0.09,face-0.03,0.35)
			_spoke(st,TAU*i/10,hub,0.92,0.04,0.05,face-0.08,face-0.02,-0.35)
		4:for i in 15:_spoke(st,TAU*i/15,hub,0.9,0.04,0.13,face-0.1,face-0.02,0.4)
		5:
			_cyl(st,0.93,0.93,face-0.25,face-0.02);_ring(st,0.88,0.93,face-0.25)   # tiefes Bett (Dish)
			for i in 6:_spoke(st,TAU*i/6,hub,0.88,0.12,0.16,face-0.27,face-0.2)
		6:for i in 7:_spoke(st,TAU*i/7,hub,0.92,0.22,0.24,face-0.14,face-0.02)
		7:
			_ring(st,hub,0.9,face-0.05)
			for i in 8:
				var a=TAU*i/8;var c=Vector3(face-0.045,cos(a)*0.58,sin(a)*0.58)
				_disc(dk,c,0.1)
	# Radmuttern
	for i in 5:
		var a=TAU*i/5;_nut(st,Vector3(face+0.025,cos(a)*0.12,sin(a)*0.12),0.03)
	var m=[_commit(st),_commit(dk)]
	cache[design]=m
	return m
static func _disc(st:SurfaceTool,c:Vector3,r:float):
	for i in 16:
		var a=TAU*i/16;var b=TAU*(i+1)/16
		st.add_vertex(c);st.add_vertex(c+Vector3(0.001,cos(a)*r,sin(a)*r));st.add_vertex(c+Vector3(0.001,cos(b)*r,sin(b)*r))
static func _nut(st:SurfaceTool,c:Vector3,r:float):
	for i in 6:
		var a=TAU*i/6;var b=TAU*(i+1)/6
		var p=[c+Vector3(0,cos(a)*r,sin(a)*r),c+Vector3(0,cos(b)*r,sin(b)*r)]
		st.add_vertex(c+Vector3(0.02,0,0));st.add_vertex(p[0]+Vector3(0.02,0,0));st.add_vertex(p[1]+Vector3(0.02,0,0))
		st.add_vertex(p[0]);st.add_vertex(p[1]);st.add_vertex(p[1]+Vector3(0.02,0,0))
		st.add_vertex(p[0]);st.add_vertex(p[1]+Vector3(0.02,0,0));st.add_vertex(p[0]+Vector3(0.02,0,0))
static func _commit(st:SurfaceTool)->ArrayMesh:
	st.generate_normals();return st.commit()
