extends RefCounted
# Straßen- und Schienennetz der Insel: Splines, Höhenprofile (Steigung begrenzt), Kreuzungen auf gleicher Höhe,
# Überführungen über die Autobahn, Brücken/Viadukte, Tunnel mit Portalen, Fahrbahn-/Gehweg-/Leitplanken-Geometrie.
const Mats=preload("res://scripts/mats.gd")
const DS:=4.0
# Straßentypen: w = halbe Fahrbahnbreite, sw = Gehweg, g = max. Steigung, sm = Glättung (m), lanes je Richtung, med = halber Mittelstreifen
const TYP={
	"autobahn":{"w":12.0,"sw":0.0,"g":0.05,"sm":160.0,"lanes":2,"med":0.9,"center":0,"tunnel":true},
	"allee":{"w":10.5,"sw":5.0,"g":0.08,"sm":50.0,"lanes":2,"med":2.0,"center":0,"tunnel":false},
	"strasse":{"w":5.5,"sw":3.5,"g":0.10,"sm":30.0,"lanes":1,"med":0.0,"center":1,"tunnel":false},
	"gasse":{"w":4.0,"sw":2.0,"g":0.12,"sm":20.0,"lanes":1,"med":0.0,"center":0,"tunnel":false},
	"rampe":{"w":4.5,"sw":0.0,"g":0.07,"sm":20.0,"lanes":1,"med":0.0,"center":0,"tunnel":false},
	"land":{"w":3.8,"sw":0.0,"g":0.11,"sm":30.0,"lanes":1,"med":0.0,"center":1,"tunnel":true},
	"piste":{"w":3.2,"sw":0.0,"g":0.14,"sm":20.0,"lanes":1,"med":0.0,"center":0,"tunnel":false},
	"runway":{"w":22.0,"sw":0.0,"g":0.02,"sm":300.0,"lanes":1,"med":0.0,"center":1,"tunnel":false},
	"taxi":{"w":8.0,"sw":0.0,"g":0.03,"sm":60.0,"lanes":1,"med":0.0,"center":1,"tunnel":false},
	"schiene":{"w":2.0,"sw":0.0,"g":0.03,"sm":150.0,"lanes":1,"med":0.0,"center":0,"tunnel":true},
}
var G   # Gelände
var roads:=[]           # je Straße: Dictionary
var junctions:=[]       # {p:Vector2,h:float,r:float}
var holes:={}           # Geländezellen ohne Dreiecke (Tunnelportale)
var hash_:={}           # Raster 20 m -> [[road_idx, sample_idx],...]

func _init(g):G=g

func add(typ:String,pts:Array,opt:={})->Dictionary:
	var r={"typ":typ,"ctrl":pts,"closed":opt.get("closed",false),"name":opt.get("name",""),"wear":opt.get("wear",0.0),"ab_join":opt.get("ab_join",false),"hint":[]}
	r.merge(TYP[typ])
	if opt.has("g"):r.g=opt.g
	if opt.has("tunnel"):r.tunnel=opt.tunnel
	if opt.has("sm"):r.sm=opt.sm
	roads.append(r);return r

# ---------------- Spline -> Abtastpunkte ----------------
func _cr(p0:Vector3,p1:Vector3,p2:Vector3,p3:Vector3,t:float)->Vector3:
	var t2=t*t;var t3=t2*t
	return 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t2+(-p0+3.0*p1-3.0*p2+p3)*t3)
func _sample(r:Dictionary):
	var c:Array=r.ctrl;var n=c.size();var dense=[]
	var segs=n if r.closed else n-1
	for i in segs:
		var p0=c[(i-1+n)%n] if (r.closed or i>0) else c[0]*2.0-c[1]
		var p1=c[i];var p2=c[(i+1)%n]
		var p3=c[(i+2)%n] if (r.closed or i+2<n) else c[n-1]*2.0-c[n-2]
		var L=Vector2(p1.x,p1.z).distance_to(Vector2(p2.x,p2.z));var k=max(int(L/1.0),2)
		for j in k:
			var q=_cr(p0,p1,p2,p3,float(j)/k);q.y=lerp(p1.y,p2.y,float(j)/k);dense.append(q)
	if not r.closed:dense.append(c[n-1])
	else:dense.append(c[0])
	# gleichmäßig nach Bogenlänge
	var P=PackedVector2Array();var HI=PackedFloat32Array();var acc=0.0;var nxt=0.0
	P.append(Vector2(dense[0].x,dense[0].z));HI.append(dense[0].y)
	for i in range(1,dense.size()):
		var a=Vector2(dense[i-1].x,dense[i-1].z);var b=Vector2(dense[i].x,dense[i].z);var L=a.distance_to(b)
		while acc+L>=nxt+DS:
			nxt+=DS;var t=(nxt-acc)/max(L,0.0001);P.append(a.lerp(b,t));HI.append(lerp(dense[i-1].y,dense[i].y,t))
		acc+=L
	var last=Vector2(dense[-1].x,dense[-1].z)
	if P[-1].distance_to(last)>DS*0.4:P.append(last);HI.append(dense[-1].y)
	r.P=P;r.hint=HI
	var T=PackedVector2Array();T.resize(P.size())
	for i in P.size():
		var a=P[max(i-1,0)];var b=P[min(i+1,P.size()-1)]
		if r.closed and (i==0 or i==P.size()-1):a=P[P.size()-2];b=P[1]
		T[i]=(b-a).normalized()
	r.T=T

func _smooth(h:PackedFloat32Array,win:float,closed:bool)->PackedFloat32Array:
	var n=h.size();var k=max(int(win/DS*0.5),1);var out=PackedFloat32Array();out.resize(n)
	for i in n:
		var s=0.0;var c=0
		for j in range(i-k,i+k+1):
			var jj=j
			if closed:jj=(j%(n-1)+(n-1))%(n-1)
			elif j<0 or j>=n:continue
			s+=h[jj];c+=1
		out[i]=s/c
	return out

# Steigung begrenzen: untere Hüllkurve (Einschnitt/Tunnel) und obere (Damm/Brücke), gemischt
func _grade(h:PackedFloat32Array,g:float,mixf:float):
	var d=g*DS;var n=h.size()
	var L=h.duplicate();var U=h.duplicate()
	for i in range(1,n):L[i]=min(L[i],L[i-1]+d);U[i]=max(U[i],U[i-1]-d)
	for i in range(n-2,-1,-1):L[i]=min(L[i],L[i+1]+d);U[i]=max(U[i],U[i+1]-d)
	if mixf<=0.0:
		for i in n:h[i]=L[i]
		return
	for i in n:h[i]=(max(L[i],h[i]-8.0)+min(U[i],h[i]+5.0))*0.5
	for it in 2:
		for i in range(1,n):h[i]=clamp(h[i],h[i-1]-d*1.2,h[i-1]+d*1.2)
		for i in range(n-2,-1,-1):h[i]=clamp(h[i],h[i+1]-d*1.2,h[i+1]+d*1.2)

func _key(p:Vector2)->Vector2i:return Vector2i(floor(p.x/20.0),floor(p.y/20.0))
func _index(ri:int):
	var r=roads[ri]
	for i in r.P.size():
		var k=_key(r.P[i])
		if not hash_.has(k):hash_[k]=[]
		hash_[k].append([ri,i])

# nächster Abtastpunkt einer schon berechneten Straße
func _near(p:Vector2,maxd:float,skip:int)->Array:
	var best=[];var bd=maxd
	var k=_key(p)
	for dx in [-1,0,1]:
		for dz in [-1,0,1]:
			var kk=k+Vector2i(dx,dz)
			if not hash_.has(kk):continue
			for e in hash_[kk]:
				if e[0]==skip:continue
				var d=roads[e[0]].P[e[1]].distance_to(p)
				if d<bd:bd=d;best=[e[0],e[1],d]
	return best

func _fall(d:float,core:float,fade:float)->float:
	if d<=core:return 1.0
	return 1.0-smoothstep(core,core+fade,d)

# ---------------- Höhenprofile ----------------
func profiles():
	var order=["autobahn","schiene","runway","taxi","allee","strasse","land","gasse","piste","rampe"]
	var sorted_=[]
	for t in order:
		for r in roads:if r.typ==t:sorted_.append(r)
	roads=sorted_
	for ri in roads.size():
		var r=roads[ri];_sample(r)
		var n=r.P.size();var raw=PackedFloat32Array();raw.resize(n)
		for i in n:raw[i]=G.base_height(r.P[i].x,r.P[i].y)
		r.raw=raw
		var h=PackedFloat32Array();h.resize(n)
		for i in n:h[i]=max(raw[i],2.2)
		h=_smooth(h,r.sm,r.closed)
		if r.typ=="autobahn" or r.typ=="schiene":
			for i in n:h[i]=h[i]+r.hint[i]
		elif r.typ=="land":
			for i in n:h[i]=h[i]+r.hint[i]
		var mixf=0.5
		if r.typ in ["autobahn","schiene"]:mixf=0.0
		_grade(h,r.g,mixf);h=_smooth(h,24.0,r.closed)
		# Anschlüsse/Kreuzungen an schon berechnete Straßen
		var cons=[]   # [i, ziel_h, core, fade, junction]
		var i=0
		while i<n:
			var md=3.2
			if i==0 or i==n-1:md=12.5
			var nb=_near(r.P[i],md,ri)
			if nb.is_empty():i+=1;continue
			# lokales Minimum suchen
			var bi=i;var bn=nb
			var j=i+1
			while j<n and j<i+6:
				var nb2=_near(r.P[j],md,ri)
				if not nb2.is_empty() and nb2[2]<bn[2]:bi=j;bn=nb2
				j+=1
			var o=roads[bn[0]];var oh=o.h[bn[1]]
			var self_ab=r.typ=="autobahn";var o_ab=o.typ=="autobahn"
			if (o_ab and not r.ab_join) or (o.typ=="schiene" and r.typ=="autobahn"):
				# höhenfreie Kreuzung: Überführung über die Autobahn (oder Bahn über Autobahn)
				if o.tunnel_flags[bn[1]]:pass   # Autobahn liegt im Tunnel -> nichts zu tun
				elif abs(h[bi]-oh)<8.0:cons.append([bi,oh+8.2,14.0,170.0 if r.typ=="schiene" else 120.0,false])
			elif o.typ=="schiene" and r.typ!="schiene":
				cons.append([bi,oh+0.05,6.0,40.0,true])     # Bahnübergang
			elif not self_ab:
				cons.append([bi,oh,max(o.w,r.w)+2.0,45.0,true])
			if cons.size()>0 and cons[-1][4]:
				junctions.append({"p":o.P[bn[1]],"h":oh,"r":max(o.w+o.sw,r.w+r.sw)+1.0,"a":ri,"b":bn[0],"rail":o.typ=="schiene"})
			i=bi+8
		for it in 3:
			for c in cons:
				var dh=c[1]-h[c[0]]
				if abs(dh)<0.01:continue
				var s0=c[0]*DS
				for k in n:
					var w=_fall(abs(k*DS-s0),c[2],c[3])
					if w>0.0:h[k]+=dh*w
		for k in n:h[k]=max(h[k],2.0)   # nie unter Meeresniveau
		r.h=h
		# Tunnel/Brücke
		var tf=[];var ef=[]
		for k in n:
			tf.append(r.tunnel and raw[k]-h[k]>8.5)
			ef.append(h[k]-raw[k]>3.2)
		_clean_runs(tf,6);_clean_runs(ef,3)
		r.tunnel_flags=tf;r.elev=ef
		_index(ri)

func _clean_runs(f:Array,minlen:int):
	var i=0
	while i<f.size():
		if f[i]:
			var j=i
			while j<f.size() and f[j]:j+=1
			if j-i<minlen:
				for k in range(i,j):f[k]=false
			i=j
		else:i+=1

func near_junction(p:Vector2,extra:=0.0)->float:
	var best=1e9
	for j in junctions:
		var d=p.distance_to(j.p)-j.r-extra
		if d<best:best=d
	return best

# Gelände an Straßen anpassen (vor dem Bau des Geländemeshs)
func shape_terrain():
	for r in roads:
		var n=r.P.size()
		for i in range(0,n,2):
			if r.tunnel_flags[i] or r.elev[i]:continue
			var core=r.w+r.sw+2.0;var fade=22.0 if r.typ=="autobahn" else 14.0
			if r.typ=="schiene":core=4.5
			G.flatten(r.P[i],r.h[i]-(0.25 if r.typ=="schiene" else 0.0),core,fade)

# ---------------- Geometrie ----------------
var mats:={}
func _road_mat(r:Dictionary)->ShaderMaterial:
	var key=r.typ+str(r.wear)
	if mats.has(key):return mats[key]
	var m=ShaderMaterial.new();m.shader=load("res://shaders/road.gdshader")
	var T="res://assets/textures/"
	var base="asphalt"
	if r.typ=="piste":base="gravel"
	m.set_shader_parameter("alb",load(T+base+"_albedo.jpg"));m.set_shader_parameter("nrm",load(T+base+"_normal.png"))
	var nt=NoiseTexture2D.new();nt.seamless=true;var fn=FastNoiseLite.new();fn.frequency=0.05;fn.fractal_octaves=4;nt.noise=fn;nt.width=256;nt.height=256
	m.set_shader_parameter("crack",nt)
	m.set_shader_parameter("half_width",r.w);m.set_shader_parameter("lanes",r.lanes);m.set_shader_parameter("median",r.med)
	m.set_shader_parameter("center_mode",r.center)
	if r.typ=="piste":m.set_shader_parameter("edge_lines",0.0);m.set_shader_parameter("center_mode",0)
	if r.typ=="gasse":m.set_shader_parameter("edge_lines",0.0)
	if r.typ=="autobahn":m.set_shader_parameter("tint",Color(0.92,0.92,0.95))
	mats[key]=m;return m

class Strip:
	var st:=SurfaceTool.new()
	func _init():st.begin(Mesh.PRIMITIVE_TRIANGLES)
	func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,ua:Vector2,ub:Vector2,uc:Vector2,ud:Vector2,col:=Color(0,0,0,1),col2:=Color(0,0,0,1)):
		# a,b vorn (links,rechts), c,d hinten (rechts,links); Normale aus Geometrie
		var nrm=(b-a).cross(d-a).normalized()
		if nrm.length()<0.5:nrm=Vector3.UP
		if nrm.y<-0.3:
			# waagerechte Flächen immer nach oben ausrichten (Vorderseite = Kreuzprodukt-Richtung)
			var t=a;a=b;b=t;t=c;c=d;d=t;var u=ua;ua=ub;ub=u;u=uc;uc=ud;ud=u;nrm=-nrm
		st.set_normal(nrm)
		st.set_color(col);st.set_uv(ua);st.add_vertex(a);st.set_color(col2);st.set_uv(uc);st.add_vertex(c);st.set_color(col);st.set_uv(ub);st.add_vertex(b)
		st.set_color(col);st.set_uv(ua);st.add_vertex(a);st.set_color(col2);st.set_uv(ud);st.add_vertex(d);st.set_color(col2);st.set_uv(uc);st.add_vertex(c)
	func commit(parent:Node3D,m:Material,name:="",shadow:=true)->MeshInstance3D:
		st.generate_tangents()
		var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=m;mi.name=name;parent.add_child(mi,true)
		if not shadow:mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi

func _two(m:StandardMaterial3D)->StandardMaterial3D:
	var d=m.duplicate();d.cull_mode=BaseMaterial3D.CULL_DISABLED;return d

func _v(p:Vector2,y:float)->Vector3:return Vector3(p.x,y,p.y)

func build(parent:Node3D):
	var conc=_two(Mats.pbr("concrete",0.25,Color(0.72,0.71,0.69)))
	var paver=Mats.pbr("pavers",0.45,Color(0.86,0.84,0.8))
	var curbm=_two(Mats.pbr("concrete",0.6,Color(0.78,0.78,0.77)))
	var steel=_two(Mats.flat(Color(0.62,0.64,0.66),0.35,0.85))
	var lamp_m=Mats.emissive(Color(1,0.93,0.78),3.0);lamp_m.cull_mode=BaseMaterial3D.CULL_DISABLED
	var grass=Mats.pbr("grass",0.25)
	var ballast=Mats.pbr("gravel",0.5,Color(0.62,0.58,0.54))
	var rail_m=_two(Mats.flat(Color(0.38,0.34,0.32),0.35,0.9))
	var wood=Mats.flat(Color(0.3,0.24,0.19),0.9)
	var gs=Strip.new();var cs=Strip.new();var ps=Strip.new();var ks=Strip.new();var ss=Strip.new();var bs=Strip.new();var rs=Strip.new();var lm=Strip.new()
	var sleepers=[]
	for r in roads:
		var n=r.P.size();var w=r.w
		if r.typ=="schiene":
			_rails(r,bs,rs,sleepers);continue
		var st=Strip.new()
		for i in n-1:
			var p0=r.P[i];var p1=r.P[i+1];var t0=r.T[i];var t1=r.T[i+1]
			var n0=Vector2(-t0.y,t0.x);var n1=Vector2(-t1.y,t1.x)
			var y0=r.h[i]+0.04;var y1=r.h[i+1]+0.04
			var m0=0.0 if near_junction(p0)<0 else 1.0;var m1=0.0 if near_junction(p1)<0 else 1.0
			var c0=Color(r.wear,0,0,m0);var c1=Color(r.wear,0,0,m1)
			var s0=i*DS;var s1=(i+1)*DS
			st.quad(_v(p0+n0*w,y0),_v(p0-n0*w,y0),_v(p1-n1*w,y1),_v(p1+n1*w,y1),Vector2(-w,s0),Vector2(w,s0),Vector2(w,s1),Vector2(-w,s1),c0,c1)
			var tun=r.tunnel_flags[i] or r.tunnel_flags[i+1]
			var el=r.elev[i] or r.elev[i+1]
			# Seitenschürzen (verdecken Spalten zum Gelände)
			if r.sw<=0.0 and not tun:
				for sd in [1,-1]:
					var a=_v(p0+n0*w*sd,y0);var b=_v(p1+n1*w*sd,y1)
					var drop=1.2 if not el else 0.0
					if drop>0:cs.quad(a,b,b-Vector3(0,drop,0),a-Vector3(0,drop,0),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
			# Gehwege mit Bordstein
			if r.sw>0.0:
				var jn0=near_junction(p0,1.0)<0;var jn1=near_junction(p1,1.0)<0
				for sd in [1,-1]:
					if jn0 or jn1:continue
					var a0=p0+n0*w*sd;var a1=p1+n1*w*sd;var b0=p0+n0*(w+r.sw)*sd;var b1=p1+n1*(w+r.sw)*sd
					var hy0=y0+0.14;var hy1=y1+0.14
					ps.quad(_v(a0,hy0),_v(b0,hy0),_v(b1,hy1),_v(a1,hy1),a0/2.0,b0/2.0,b1/2.0,a1/2.0)
					ks.quad(_v(a0,hy0),_v(a1,hy1),_v(a1,y1-0.05),_v(a0,y0-0.05),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
					ks.quad(_v(b0,hy0),_v(b1,hy1),_v(b1,y1-1.0),_v(b0,y0-1.0),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
			# Grüner Mittelstreifen der Allee
			if r.typ=="allee" and near_junction(p0,2.0)>0 and near_junction(p1,2.0)>0:
				var md=r.med-0.2
				gs.quad(_v(p0+n0*md,y0+0.16),_v(p0-n0*md,y0+0.16),_v(p1-n1*md,y1+0.16),_v(p1+n1*md,y1+0.16),p0/3.0,p0/3.0+Vector2(1,0),p1/3.0+Vector2(1,0),p1/3.0)
				for sd in [1,-1]:ks.quad(_v(p0+n0*md*sd,y0+0.16),_v(p1+n1*md*sd,y1+0.16),_v(p1+n1*md*sd,y1-0.02),_v(p0+n0*md*sd,y0-0.02),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
			# Autobahn: Mittelleitwand + Leitplanken
			if r.typ=="autobahn":
				for sd in [1,-1]:
					var a=p0+n0*0.35*sd;var b=p1+n1*0.35*sd
					cs.quad(_v(a,y0+0.9),_v(b,y1+0.9),_v(b,y1),_v(a,y0),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
				cs.quad(_v(p0+n0*0.35,y0+0.9),_v(p0-n0*0.35,y0+0.9),_v(p1-n1*0.35,y1+0.9),_v(p1+n1*0.35,y1+0.9),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
				if not tun and not el and near_junction(p0,40.0)>0:
					for sd in [1,-1]:
						var a=p0+n0*(w-0.3)*sd;var b=p1+n1*(w-0.3)*sd
						ss.quad(_v(a,y0+0.82),_v(b,y1+0.82),_v(b,y1+0.48),_v(a,y0+0.48),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
						if i%2==0:ss.quad(_v(a,y0+0.8),_v(a+t0*0.12,y0+0.8),_v(a+t0*0.12,y0),_v(a,y0),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
			# Brücke: Brüstung, Untersicht, Pfeiler
			if el and not tun:
				var ew=w+r.sw+0.4
				for sd in [1,-1]:
					var a=p0+n0*ew*sd;var b=p1+n1*ew*sd
					cs.quad(_v(a,y0+1.0),_v(b,y1+1.0),_v(b,y1-1.4),_v(a,y0-1.4),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
					var a2=p0+n0*(ew-0.35)*sd;var b2=p1+n1*(ew-0.35)*sd
					cs.quad(_v(a2,y0+1.0),_v(b2,y1+1.0),_v(b,y1+1.0),_v(a,y0+1.0),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
				cs.quad(_v(p0+n0*ew,y0-1.4),_v(p0-n0*ew,y0-1.4),_v(p1-n1*ew,y1-1.4),_v(p1+n1*ew,y1-1.4),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
				if r.sw>0:
					for sd in [1,-1]:
						var a0=p0+n0*w*sd;var a1=p1+n1*w*sd;var b0=p0+n0*(w+r.sw)*sd;var b1=p1+n1*(w+r.sw)*sd
						if near_junction(p0,1.0)<0:ps.quad(_v(a0,y0+0.14),_v(b0,y0+0.14),_v(b1,y1+0.14),_v(a1,y1+0.14),a0/2.0,b0/2.0,b1/2.0,a1/2.0)
				if i%8==0 and r.elev[i]:
					var ground=min(r.raw[i],G.h_at(p0.x,p0.y))-3.0
					var xs=[0.0] if w<8 else [-w*0.45,w*0.45]
					for xo in xs:_pillar(cs,p0+n0*xo,t0,ground,y0-1.4,1.6 if w<8 else 2.2)
			# Tunnel: Wände, Decke, Licht
			if tun:
				var tw=w+1.2
				for sd in [1,-1]:
					var a=p0+n0*tw*sd;var b=p1+n1*tw*sd
					cs.quad(_v(a,y0+7.0),_v(b,y1+7.0),_v(b,y1-0.1),_v(a,y0-0.1),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
					# Gehsteig/Notweg im Tunnel
					var c0_=p0+n0*w*sd;var c1_=p1+n1*w*sd
					ks.quad(_v(c0_,y0+0.3),_v(a,y0+0.3),_v(b,y1+0.3),_v(c1_,y1+0.3),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
				cs.quad(_v(p0+n0*tw,y0+7.0),_v(p0-n0*tw,y0+7.0),_v(p1-n1*tw,y1+7.0),_v(p1+n1*tw,y1+7.0),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
				if i%6==0:
					for sd in [1,-1]:
						var lp=p0+n0*(w*0.55)*sd
						lm.quad(_v(lp+n0*0.25+t0*1.2,y0+6.95),_v(lp-n0*0.25+t0*1.2,y0+6.95),_v(lp-n0*0.25-t0*1.2,y0+6.95),_v(lp+n0*0.25-t0*1.2,y0+6.95),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
		var mi=st.commit(parent,_road_mat(r),"Strasse_"+r.typ,false)
		r.mesh=mi
		_portals(cs,ps,r)
	# Kreuzungsflächen (Pflaster unter den Fahrbahnen, füllt die Ecken)
	for j in junctions:
		if j.rail:continue
		var c=Vector3(j.p.x,j.h-0.02,j.p.y);var rr=j.r+1.0
		for k in 20:
			var a1=TAU*k/20.0;var a2=TAU*(k+1)/20.0
			ps.quad(c,c,c+Vector3(cos(a2),0,sin(a2))*rr,c+Vector3(cos(a1),0,sin(a1))*rr,Vector2(j.p.x,j.p.y)/2.0,Vector2(j.p.x,j.p.y)/2.0,Vector2(j.p.x+cos(a2)*rr,j.p.y+sin(a2)*rr)/2.0,Vector2(j.p.x+cos(a1)*rr,j.p.y+sin(a1)*rr)/2.0)
	cs.commit(parent,conc,"Beton");ps.commit(parent,paver,"Gehweg",false);ks.commit(parent,curbm,"Bordstein",false);ss.commit(parent,steel,"Leitplanke");gs.commit(parent,grass,"Mittelstreifen",false)
	bs.commit(parent,ballast,"Schotter",false);rs.commit(parent,rail_m,"Schienen",false);lm.commit(parent,lamp_m,"Tunnellicht",false)
	# Schwellen als MultiMesh
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;var bm=BoxMesh.new();bm.size=Vector3(2.6,0.16,0.26);mm.mesh=bm
	mm.instance_count=sleepers.size()
	for k in sleepers.size():mm.set_instance_transform(k,sleepers[k])
	var mmi=MultiMeshInstance3D.new();mmi.multimesh=mm;mmi.material_override=wood;mmi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mmi)

func _pillar(s:Strip,p:Vector2,t:Vector2,y0:float,y1:float,size:float):
	var n=Vector2(-t.y,t.x)*size*0.5;var tt=t*size*0.5
	var c=[p+n+tt,p-n+tt,p-n-tt,p+n-tt]
	for k in 4:
		var a=c[k];var b=c[(k+1)%4]
		s.quad(_v(a,y1),_v(b,y1),_v(b,y0),_v(a,y0),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
	# Kopfbalken
	var n2=Vector2(-t.y,t.x)*(size*0.5+2.5);var t2=t*0.9
	var cc=[p+n2+t2,p-n2+t2,p-n2-t2,p+n2-t2]
	for k in 4:
		var a=cc[k];var b=cc[(k+1)%4]
		s.quad(_v(a,y1),_v(b,y1),_v(b,y1-1.1),_v(a,y1-1.1),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
	s.quad(_v(cc[0],y1-1.1),_v(cc[1],y1-1.1),_v(cc[2],y1-1.1),_v(cc[3],y1-1.1),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))

# Stützmauern am Tunnelmund (verdecken das ausgeschnittene Gelände)
func _trench(s:Strip,r:Dictionary,i:int):
	if i>=r.P.size()-1:return
	var p0=r.P[i];var p1=r.P[i+1];var t0=r.T[i];var t1=r.T[i+1];var n0=Vector2(-t0.y,t0.x);var n1=Vector2(-t1.y,t1.x)
	var y0=r.h[i];var y1=r.h[i+1];var w=r.w+1.2
	for sd in [1,-1]:
		var top0=max(G.base_height(p0.x+n0.x*(w+16)*sd,p0.y+n0.y*(w+16)*sd),y0+7.6)+0.4
		var top1=max(G.base_height(p1.x+n1.x*(w+16)*sd,p1.y+n1.y*(w+16)*sd),y1+7.6)+0.4
		var a=p0+n0*w*sd;var b=p1+n1*w*sd;var a2=p0+n0*(w+16)*sd;var b2=p1+n1*(w+16)*sd
		s.quad(_v(a,top0),_v(b,top1),_v(b,y1-0.2),_v(a,y0-0.2),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
		s.quad(_v(a,top0),_v(a2,top0),_v(b2,top1),_v(b,top1),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
	# Deckel über dem Tunnel (Erdüberdeckung) in Portalnähe
	if r.tunnel_flags[i]:
		var tw=r.w+1.2
		s.quad(_v(p0+n0*tw,y0+7.6),_v(p0-n0*tw,y0+7.6),_v(p1-n1*tw,y1+7.6),_v(p1+n1*tw,y1+7.6),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))

# ---------------- Tunnelportale ----------------
# Nach dem Formen des Geländes: über dem Tunnelmund das Gelände auf Deckenhöhe anheben, die Zellen, die den Mund
# kreuzen würden, entfernen und die Röhre bis dorthin verlängern. Davor steht eine Stirnwand, deren Oberkante dem Gelände folgt.
var portals:=[]
func portal_fix():
	for r in roads:
		if not r.has("tunnel_flags"):continue
		var n=r.P.size();var starts=[]
		for i in range(1,n):
			if r.tunnel_flags[i] and not r.tunnel_flags[i-1]:starts.append([i,1])
			if not r.tunnel_flags[i] and r.tunnel_flags[i-1]:starts.append([i-1,-1])
		for st in starts:_fix_one(r,st[0],st[1])

func _local(r:Dictionary,k:int,dir:int,q:Vector2)->Array:
	# nächster Abtastpunkt im Fenster um das Portal -> [s relativ (in Tunnelrichtung), seitlicher Abstand, Index]
	var best=1e9;var bj=k
	for j in range(max(k-20,0),min(k+20,r.P.size()-1)+1):
		var d=r.P[j].distance_squared_to(q)
		if d<best:best=d;bj=j
	var t:Vector2=r.T[bj];var nn=Vector2(-t.y,t.x);var dv=q-r.P[bj]
	return [((bj-k)*DS+dv.dot(t))*dir,abs(dv.dot(nn)),bj]

func _fix_one(r:Dictionary,k:int,dir:int):
	var w=r.w;var cw=w+9.0;var roof=7.0
	var p=r.P[k];var R=cw+80.0
	var i0=int((p.x-R-G.X0)/G.STEP);var i1=int((p.x+R-G.X0)/G.STEP)+1;var k0=int((p.y-R-G.Z0)/G.STEP);var k1=int((p.y+R-G.Z0)/G.STEP)+1
	var inside={}
	for kk in range(max(k0,0),min(k1,G.nz-1)+1):
		for ii in range(max(i0,0),min(i1,G.nx-1)+1):
			var q=Vector2(G.X0+ii*G.STEP,G.Z0+kk*G.STEP);var L=_local(r,k,dir,q)
			if L[1]<cw and L[0]>=0.0 and L[0]<70.0:
				var key=G.idx(ii,kk);var lim=r.h[L[2]]+roof+1.2
				if G.heights[key]<lim:G.heights[key]=lim;inside[Vector2i(ii,kk)]=true
	# Zellen mit gemischten Ecken -> Loch
	var smin=0.0;var cells=[]
	for kk in range(max(k0,0),min(k1,G.nz-2)+1):
		for ii in range(max(i0,0),min(i1,G.nx-2)+1):
			var c=[Vector2i(ii,kk),Vector2i(ii+1,kk),Vector2i(ii,kk+1),Vector2i(ii+1,kk+1)]
			var nin=0
			for v in c:if inside.has(v):nin+=1
			if nin==0 or nin==4:continue
			var cc=Vector2(G.X0+(ii+0.5)*G.STEP,G.Z0+(kk+0.5)*G.STEP);var L=_local(r,k,dir,cc)
			if L[1]>cw+8.0 or L[0]>14.0 or L[0]<-14.0:continue
			G.holes[Vector2i(ii,kk)]=true;cells.append(Vector2i(ii,kk))
			for v in c:
				var q=Vector2(G.X0+v.x*G.STEP,G.Z0+v.y*G.STEP);var L2=_local(r,k,dir,q)
				if L2[1]<cw+8:smin=min(smin,L2[0])
	# Röhre bis vor die entfernten Zellen verlängern
	var ext=int(ceil(-smin/DS))+1
	for e in range(1,ext+1):
		var j=k-e*dir
		if j>=0 and j<r.P.size():r.tunnel_flags[j]=true
	var kw=clampi(k-ext*dir,0,r.P.size()-1)
	portals.append({"r":r,"k":kw,"dir":dir,"cells":cells})

func _portals(s:Strip,floor_s:Strip,r:Dictionary):
	for po in portals:
		if po.r!=r:continue
		var k=po.k;var dir=po.dir
		var p=r.P[k];var t=r.T[k]*dir;var nn=Vector2(-t.y,t.x);var y=r.h[k];var w=r.w+1.2
		var W=w+30.0
		# Stirnwand: Spalten à 2 m, Oberkante folgt dem (angehobenen) Gelände knapp hinter der Wand
		var x=-W
		while x<W-0.01:
			var x2=min(x+2.0,W)
			var qa=p+nn*x;var qb=p+nn*x2
			var ta=max(G.h_at(qa.x+t.x*3,qa.y+t.y*3),y+8.2)+0.7;var tb=max(G.h_at(qb.x+t.x*3,qb.y+t.y*3),y+8.2)+0.7
			var bot_a=min(G.h_at(qa.x-t.x*2,qa.y-t.y*2),y)-1.5;var bot_b=min(G.h_at(qb.x-t.x*2,qb.y-t.y*2),y)-1.5
			var open=abs(x+1.0)<w and abs(x2-1.0)<w
			var ya=bot_a;var yb=bot_b
			if abs((x+x2)*0.5)<w:ya=y+7.0;yb=y+7.0
			s.quad(_v(qa,ta),_v(qb,tb),_v(qb,yb),_v(qa,ya),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
			s.quad(_v(qa,ta),_v(qb,tb),_v(qb+t*4.0,tb),_v(qa+t*4.0,ta),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
			x=x2
		# Gesims über dem Tunnelmund
		s.quad(_v(p+nn*(w+1)-t*0.6,y+7.9),_v(p-nn*(w+1)-t*0.6,y+7.9),_v(p-nn*(w+1)-t*0.6,y+7.0),_v(p+nn*(w+1)-t*0.6,y+7.0),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
		s.quad(_v(p+nn*(w+1)-t*0.6,y+7.9),_v(p-nn*(w+1)-t*0.6,y+7.9),_v(p-nn*(w+1),y+7.9),_v(p+nn*(w+1),y+7.9),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
		# entfernte Zellen: Boden (Straßenniveau) und Deckel (über der Röhre)
		for c in po.cells:
			var a=Vector2(G.X0+c.x*G.STEP,G.Z0+c.y*G.STEP);var bb=a+Vector2(G.STEP,G.STEP)
			var L=_local(r,po.k,dir,(a+bb)*0.5);var yy=r.h[L[2]]
			if L[0]<-1.0:
				floor_s.quad(_v(a,yy-0.06),_v(Vector2(bb.x,a.y),yy-0.06),_v(bb,yy-0.06),_v(Vector2(a.x,bb.y),yy-0.06),a/2.0,Vector2(bb.x,a.y)/2.0,bb/2.0,Vector2(a.x,bb.y)/2.0)
			else:
				var ly=max(G.h_at((a.x+bb.x)*0.5,(a.y+bb.y)*0.5),yy+8.2)
				s.quad(_v(a,ly),_v(Vector2(bb.x,a.y),ly),_v(bb,ly),_v(Vector2(a.x,bb.y),ly),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))

func _rails(r:Dictionary,bs:Strip,rs:Strip,sleepers:Array):
	var n=r.P.size()
	for i in n-1:
		var p0=r.P[i];var p1=r.P[i+1];var t0=r.T[i];var t1=r.T[i+1];var n0=Vector2(-t0.y,t0.x);var n1=Vector2(-t1.y,t1.x)
		var y0=r.h[i];var y1=r.h[i+1]
		bs.quad(_v(p0+n0*1.7,y0+0.3),_v(p0-n0*1.7,y0+0.3),_v(p1-n1*1.7,y1+0.3),_v(p1+n1*1.7,y1+0.3),p0/3.0,p0/3.0+Vector2(1,0),p1/3.0+Vector2(1,0),p1/3.0)
		for sd in [1,-1]:
			bs.quad(_v(p0+n0*1.7*sd,y0+0.3),_v(p1+n1*1.7*sd,y1+0.3),_v(p1+n1*2.9*sd,y1-0.3),_v(p0+n0*2.9*sd,y0-0.3),p0/3.0,p1/3.0,p1/3.0+Vector2(0.4,0),p0/3.0+Vector2(0.4,0))
			for e in [0.75,0.68]:
				var a=p0+n0*e*sd;var b=p1+n1*e*sd
				rs.quad(_v(a,y0+0.56),_v(b,y1+0.56),_v(b,y1+0.4),_v(a,y0+0.4),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
			rs.quad(_v(p0+n0*0.75*sd,y0+0.56),_v(p0+n0*0.68*sd,y0+0.56),_v(p1+n1*0.68*sd,y1+0.56),_v(p1+n1*0.75*sd,y1+0.56),Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1))
		for k in 6:
			var t=k/6.0;var p=p0.lerp(p1,t);var y=lerp(y0,y1,t)+0.36;var ang=atan2(t0.x,t0.y)
			sleepers.append(Transform3D(Basis(Vector3.UP,ang),Vector3(p.x,y,p.y)))
		# Brücke für die Bahn
		if r.elev[i] and i%8==0:
			pass

# Höhe/Lage an Lauflänge s
func at(r:Dictionary,s:float)->Array:
	var i=clampi(int(s/DS),0,r.P.size()-2);var t=clamp(s/DS-i,0.0,1.0)
	return [r.P[i].lerp(r.P[i+1],t),lerp(r.h[i],r.h[i+1],t),r.T[i],i]
func length(r:Dictionary)->float:return (r.P.size()-1)*DS
func roads_by_name(n:String)->Dictionary:
	for r in roads:
		if r.name==n:return r
	return {}

# Gelände darf nie über die Fahrbahn/den Gehweg ragen: Gitterpunkte nahe der Straße nach unten begrenzen
# (erlaubt jenseits des Gehwegs einen Anstieg von 60 %)
func clamp_terrain():
	# Landinneres nie unter Wasser (keine Pfützen-Seen durch Einschnitte)
	for k in G.nz:
		for i in G.nx:
			var key=G.idx(i,k)
			if G.heights[key]<1.2 and G.island(G.X0+i*G.STEP,G.Z0+k*G.STEP)>=1.0:G.heights[key]=1.2
	for r in roads:
		if r.typ=="schiene":continue
		var edge=r.w+r.sw
		var rr=edge+9.0
		for i in r.P.size():
			if r.tunnel_flags[i] or r.elev[i]:continue
			var p=r.P[i];var h=r.h[i]
			var i0=int((p.x-rr-G.X0)/G.STEP);var i1=int((p.x+rr-G.X0)/G.STEP)+1;var k0=int((p.y-rr-G.Z0)/G.STEP);var k1=int((p.y+rr-G.Z0)/G.STEP)+1
			for k in range(max(k0,0),min(k1,G.nz-1)+1):
				for ii in range(max(i0,0),min(i1,G.nx-1)+1):
					var q=Vector2(G.X0+ii*G.STEP,G.Z0+k*G.STEP);var d=q.distance_to(p)
					if d>rr:continue
					var lim=h-0.12+max(0.0,d-edge)*0.6
					var key=G.idx(ii,k)
					if G.heights[key]>lim:G.heights[key]=lim
