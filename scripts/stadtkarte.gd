extends Node3D
# Stadtkarte Radeberg: drei Inseln im Meer, durch Brücken verbunden (eigener Entwurf).
#  West  "Hafen & Industrie": Lagerhallen, Containerterminal, Kräne, Werkstatt
#  Mitte "Innenstadt" (Nord: Hochhäuser, Büros) + "Altstadt Radeberg" (Süd: Gründerzeit-Blockrand, Kirche, Marktplatz)
#  Ost   "Wohnviertel": Altbau- und Plattenbau-Blöcke mit Innenhöfen, Stadtpark mit See
# Häuser abseits der Hauptstraße: Blockrand-Bebauung mit echten Fassadentexturen (sehr wenig Draw Calls, handytauglich).
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
const F=preload("res://scripts/fit.gd")
const FT="res://assets/textures/facades/"
const ROAD:=14.0     # Fahrbahnbreite
const WALK:=4.0      # Gehweg
const BAY:=10.4      # Breite einer Fassadentextur (4 Fensterachsen)
const STORY:=13.0    # Höhe einer Fassadentextur (4 Geschosse)
const EG:=4.4        # Erdgeschosshöhe

var rng:=RandomNumberGenerator.new()
var islands:=[]      # [{name, poly:PackedVector2Array, angle, block:Vector2, district:Callable-Name}]
var mesh_tools:={}   # Materialname -> SurfaceTool
var mats:={}
var cams:=[]
var road_mat;var walk_mat;var curb_mat
var tree_spots:=[]
var car_spots:=[]
var people_spots:=[]

# ---------------- Materialien ----------------
func fmat(name:String,metal:=0.0,rough:=0.85)->StandardMaterial3D:
	if mats.has(name):return mats[name]
	var m=StandardMaterial3D.new();m.albedo_texture=load(FT+name+".jpg");m.metallic=metal;m.roughness=rough
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats[name]=m;return m
func st_for(m:Material)->SurfaceTool:
	var k=m.get_instance_id()
	if not mesh_tools.has(k):
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);mesh_tools[k]=[st,m]
	return mesh_tools[k][0]
var out_hint:=Vector3.ZERO   # Bezugspunkt im Inneren eines Körpers: Wände zeigen davon weg
func quad(m:Material,a:Vector3,b:Vector3,c:Vector3,d:Vector3,uv0:Vector2,uv1:Vector2):
	var st=st_for(m);var n=(b-a).cross(d-a).normalized()
	# Ausrichtung erzwingen: waagerechte Flächen nach oben, Wände nach außen
	var flip=false
	if abs(n.y)>0.7:flip=n.y<0
	elif out_hint!=Vector3.ZERO:flip=n.dot(((a+c)*0.5-out_hint)*Vector3(1,0,1))<0
	if flip:
		# Spiegeln entlang der u-Achse (a<->b, d<->c): Textur bleibt aufrecht
		var t=a;a=b;b=t;t=c;c=d;d=t;n=-n
	st.set_normal(n)
	# Godot: Vorderseite = im Uhrzeigersinn gesehen -> Reihenfolge a,c,b / a,d,c
	st.set_uv(Vector2(uv0.x,uv1.y));st.add_vertex(a);st.set_uv(Vector2(uv1.x,uv0.y));st.add_vertex(c);st.set_uv(Vector2(uv1.x,uv1.y));st.add_vertex(b)
	st.set_uv(Vector2(uv0.x,uv1.y));st.add_vertex(a);st.set_uv(Vector2(uv0.x,uv0.y));st.add_vertex(d);st.set_uv(Vector2(uv1.x,uv0.y));st.add_vertex(c)
func commit_all():
	for k in mesh_tools:
		var st:SurfaceTool=mesh_tools[k][0];st.generate_tangents()
		var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=mesh_tools[k][1];add_child(mi)
		if OS.has_environment("KDEBUG"):print("MESH ",mesh_tools[k][1].resource_name," tex=",mesh_tools[k][1].albedo_texture.resource_path if mesh_tools[k][1] is BaseMaterial3D and mesh_tools[k][1].albedo_texture else "-"," aabb=",mi.get_aabb())
	mesh_tools.clear()

# Gebäude als Kubus mit texturierten Fassaden: p0..p3 Grundriss (gegen Uhrzeigersinn), Front = Kante p0->p1
func block_building(p:Array,h:float,facade:String,shopband:String,roof:String,pitched:=false):
	var fm=fmat(facade);var sm=fmat(shopband) if shopband!="" else fm
	var y0=0.15
	out_hint=(p[0]+p[1]+p[2]+p[3])*0.25
	for i in 4:
		var a:Vector3=p[i];var b:Vector3=p[(i+1)%4];var L=a.distance_to(b)
		var u1=L/BAY
		# Erdgeschoss: Ladenband (nur Straßenseite i==0) oder Fassade
		if shopband!="" and i==0:
			quad(sm,a+Vector3(0,y0,0),b+Vector3(0,y0,0),b+Vector3(0,y0+EG,0),a+Vector3(0,y0+EG,0),Vector2(0,0),Vector2(u1,1))
			quad(fm,a+Vector3(0,y0+EG,0),b+Vector3(0,y0+EG,0),b+Vector3(0,h,0),a+Vector3(0,h,0),Vector2(0,0),Vector2(u1,(h-y0-EG)/STORY))
		else:
			quad(fm,a+Vector3(0,y0,0),b+Vector3(0,y0,0),b+Vector3(0,h,0),a+Vector3(0,h,0),Vector2(0,0),Vector2(u1,(h-y0)/STORY))
	var rm=mats.get("roof_flat")
	if rm==null:rm=Mats.flat(Color(0.32,0.31,0.3),0.9);mats["roof_flat"]=rm
	if pitched:
		# Satteldach über der Längsachse (p0->p1), Ziegel
		var rt=Mats.pbr("roof",0.5);var c0=(p[0]+p[3])*0.5;var c1=(p[1]+p[2])*0.5;var rh=4.0
		quad(rt,p[0]+Vector3(0,h,0),p[1]+Vector3(0,h,0),c1+Vector3(0,h+rh,0),c0+Vector3(0,h+rh,0),Vector2(0,0),Vector2(p[0].distance_to(p[1])/4,2))
		quad(rt,p[2]+Vector3(0,h,0),p[3]+Vector3(0,h,0),c0+Vector3(0,h+rh,0),c1+Vector3(0,h+rh,0),Vector2(0,0),Vector2(p[2].distance_to(p[3])/4,2))
		var gm=fmat(facade)
		for e in [[p[3],p[0],c0],[p[1],p[2],c1]]:   # Giebeldreiecke
			var st=st_for(gm);var a=e[0]+Vector3(0,h,0);var b=e[1]+Vector3(0,h,0);var c=e[2]+Vector3(0,h+rh,0)
			st.set_normal((b-a).cross(c-a).normalized());st.set_uv(Vector2(0,1));st.add_vertex(a);st.set_uv(Vector2(0.5,0.6));st.add_vertex(c);st.set_uv(Vector2(1,1));st.add_vertex(b)
	else:
		quad(rm,p[0]+Vector3(0,h,0),p[1]+Vector3(0,h,0),p[2]+Vector3(0,h,0),p[3]+Vector3(0,h,0),Vector2(0,0),Vector2(1,1))
		# Attika (Brüstung) ringsum
		var am=mats.get("attika");if am==null:am=Mats.pbr("concrete",0.4,Color(0.75,0.74,0.72));mats["attika"]=am
		for i in 4:
			var a:Vector3=p[i];var b:Vector3=p[(i+1)%4];var inn=((p[(i+2)%4]+p[(i+3)%4])*0.5-(a+b)*0.5).normalized()*0.35
			quad(am,a+Vector3(0,h,0),b+Vector3(0,h,0),b+Vector3(0,h+0.9,0),a+Vector3(0,h+0.9,0),Vector2(0,0),Vector2(1,1))
			var oh=out_hint;out_hint=(a+b)*0.5+inn*3.0
			quad(am,a+inn+Vector3(0,h+0.9,0),b+inn+Vector3(0,h+0.9,0),b+inn+Vector3(0,h,0),a+inn+Vector3(0,h,0),Vector2(0,0),Vector2(1,1))
			out_hint=oh
			quad(am,a+Vector3(0,h+0.9,0),b+Vector3(0,h+0.9,0),b+inn+Vector3(0,h+0.9,0),a+inn+Vector3(0,h+0.9,0),Vector2(0,0),Vector2(1,1))

# Hochhaus mit Sockel und Rücksprüngen
func tower(c:Vector3,w:float,d:float,h:float,facade:String,ang:float):
	var B=Basis(Vector3.UP,ang)
	var rect=func(cx:float,cz:float,hw:float,hd:float):return [c+B*Vector3(cx-hw,0,cz+hd),c+B*Vector3(cx+hw,0,cz+hd),c+B*Vector3(cx+hw,0,cz-hd),c+B*Vector3(cx-hw,0,cz-hd)]
	block_building(rect.call(0,0,w*0.5+3,d*0.5+3),9.0,"buero_hell","laden_grau","")   # Sockel mit Läden
	var y=9.0;var hw=w*0.5;var hd=d*0.5;var steps=1 if h<90 else (2 if h<140 else 3)
	for s in steps:
		var seg=(h-9.0)/steps
		var r=rect.call(0,0,hw,hd)
		out_hint=c
		for i in 4:
			var a:Vector3=r[i];var b:Vector3=r[(i+1)%4];var L=a.distance_to(b)
			quad(fmat(facade,0.6,0.12),a+Vector3(0,y,0),b+Vector3(0,y,0),b+Vector3(0,y+seg,0),a+Vector3(0,y+seg,0),Vector2(0,y/STORY),Vector2(L/BAY,(y+seg)/STORY))
		var rm=mats["roof_flat"];quad(rm,r[0]+Vector3(0,y+seg,0),r[1]+Vector3(0,y+seg,0),r[2]+Vector3(0,y+seg,0),r[3]+Vector3(0,y+seg,0),Vector2(0,0),Vector2(1,1))
		y+=seg;hw*=0.8;hd*=0.8
	# Dachaufbauten: Technikgeschoss, Antenne
	var tb=Batch.new();var tm=Mats.flat(Color(0.55,0.56,0.58),0.5,0.6)
	tb.box(tm,c+Vector3(-hw*0.5,y,-hd*0.5),c+Vector3(hw*0.5,y+4,hd*0.5))
	if h>120:tb.cyl(Mats.flat(Color(0.8,0.8,0.82),0.4,0.8),c+Vector3(0,y+4+10,0),0.25,20)
	tb.commit(self)

# ---------------- Inseln ----------------
func smooth_poly(pts:Array,sub:=6)->PackedVector2Array:
	var out=PackedVector2Array();var n=pts.size()
	for i in n:
		var p0:Vector2=pts[(i-1+n)%n];var p1:Vector2=pts[i];var p2:Vector2=pts[(i+1)%n];var p3:Vector2=pts[(i+2)%n]
		for k in sub:
			var t=float(k)/sub;var t2=t*t;var t3=t2*t
			out.append(0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t2+(-p0+3*p1-3*p2+p3)*t3))
	return out

func land(poly:PackedVector2Array,ground:Material):
	var tri=Geometry2D.triangulate_polygon(poly)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3.UP)
	for i in tri:
		var p=poly[i];st.set_uv(p*0.25);st.add_vertex(Vector3(p.x,0.0,p.y))
	var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=ground;add_child(mi)
	# Kaimauer ringsum (Beton), von +0.15 bis -6 m
	var q=Mats.pbr("concrete",0.25,Color(0.62,0.62,0.6))
	var cc=Vector2();for p in poly:cc+=p
	cc/=poly.size();out_hint=Vector3(cc.x,0,cc.y)
	for i in poly.size():
		var a=poly[i];var b=poly[(i+1)%poly.size()]
		quad(q,Vector3(a.x,-6,a.y),Vector3(b.x,-6,b.y),Vector3(b.x,0.15,b.y),Vector3(a.x,0.15,a.y),Vector2(0,0),Vector2(a.distance_to(b)/4,1.5))
	# Geländer an der Kaikante
	var rail=Batch.new();var rm=Mats.flat(Color(0.2,0.22,0.24),0.4,0.8)
	var acc=0.0
	for i in poly.size():
		var a=poly[i];var b=poly[(i+1)%poly.size()];var L=a.distance_to(b);var d=(b-a)/max(L,0.001)
		var n=Vector2(-d.y,d.x)*0.6   # leicht nach innen
		rail.box_rot(rm,Vector3((a.x+b.x)*0.5+n.x,1.1,(a.y+b.y)*0.5+n.y),Vector3(L+0.05,0.06,0.06),Basis(Vector3.UP,-atan2(d.y,d.x)))
		acc+=L
		if acc>2.5:
			acc=0.0;rail.box(rm,Vector3(a.x+n.x-0.03,0.15,a.y+n.y-0.03),Vector3(a.x+n.x+0.03,1.1,a.y+n.y+0.03))
	rail.commit(self)

func water():
	var w=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(8000,8000);pm.subdivide_width=1;pm.subdivide_depth=1;w.mesh=pm;add_child(w);w.position.y=-1.6
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.04,0.13,0.17);m.metallic=0.2;m.roughness=0.06;m.metallic_specular=0.9
	var nt=NoiseTexture2D.new();nt.seamless=true;nt.as_normal_map=true;nt.bump_strength=6.0;var fn=FastNoiseLite.new();fn.frequency=0.03;nt.noise=fn;nt.width=512;nt.height=512
	m.normal_enabled=true;m.normal_texture=nt;m.normal_scale=0.6;m.uv1_scale=Vector3(260,260,1)
	w.material_override=m;w.set_meta("water",true)
	water_mat=m
var water_mat:StandardMaterial3D
func _process(d):
	if water_mat:water_mat.uv1_offset+=Vector3(d*0.004,d*0.0025,0)

# ---------------- Straßennetz je Insel ----------------
func inside(poly:PackedVector2Array,p:Vector2)->bool:return Geometry2D.is_point_in_polygon(p,poly)
func dist_edge(poly:PackedVector2Array,p:Vector2)->float:
	var best=INF
	for i in poly.size():
		var q=Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()]);best=min(best,p.distance_to(q))
	return best

func grid_island(isl:Dictionary):
	var poly:PackedVector2Array=isl.poly;var ang:float=isl.angle;var bs:Vector2=isl.block
	var cell=bs+Vector2(ROAD+2*WALK,ROAD+2*WALK)
	var lo=Vector2(INF,INF);var hi=-lo;for p in poly:lo=lo.min(p);hi=hi.max(p)
	var ctr=(lo+hi)*0.5;var R=(hi-lo).length()*0.6
	var rot=func(v:Vector2)->Vector2:return ctr+v.rotated(ang)
	var nx=int(R*2/cell.x)+2;var nz=int(R*2/cell.y)+2
	var b=Batch.new()
	var cells={}
	for ix in range(-nx/2,nx/2+1):
		for iz in range(-nz/2,nz/2+1):
			var c=Vector2(ix*cell.x,iz*cell.y)
			var corners=[c+Vector2(-bs.x*0.5,-bs.y*0.5),c+Vector2(bs.x*0.5,-bs.y*0.5),c+Vector2(bs.x*0.5,bs.y*0.5),c+Vector2(-bs.x*0.5,bs.y*0.5)].map(func(v):return rot.call(v))
			var ok=corners.all(func(v):return inside(poly,v) and dist_edge(poly,v)>WALK+8)
			if ok:cells[Vector2i(ix,iz)]=corners
	isl["cells"]=cells
	# Straßen: zwischen allen Blöcken (Kanten der Zellen) — nur wo mindestens ein Block anliegt
	var roads=[]
	for k in cells:
		var c=Vector2(k.x*cell.x,k.y*cell.y)
		var hx=cell.x*0.5;var hz=cell.y*0.5
		roads.append([c+Vector2(-hx,-hz),c+Vector2(hx,-hz)]);roads.append([c+Vector2(-hx,hz),c+Vector2(hx,hz)])
		roads.append([c+Vector2(-hx,-hz),c+Vector2(-hx,hz)]);roads.append([c+Vector2(hx,-hz),c+Vector2(hx,hz)])
	var seen={}
	for r in roads:
		var key=str((r[0]+r[1]).snapped(Vector2(0.1,0.1)))
		if seen.has(key):continue
		seen[key]=true
		_road(rot.call(r[0]),rot.call(r[1]),cells.size())
	# Uferstraße: Promenade ringsum (Gehweg-Band an der Kaikante)
	isl["ctr"]=ctr

var road_list:=[]
func _road(a:Vector2,b:Vector2,_n:int):
	out_hint=Vector3.ZERO
	road_list.append([a,b])
	var d=(b-a).normalized();var n=Vector2(-d.y,d.x);var L=a.distance_to(b)
	var e=ROAD*0.5+WALK
	# Fahrbahn (über die Kreuzung hinaus verlängert), Gehwege beidseits
	var a2=a-d*e;var b2=b+d*e
	quad(road_mat,Vector3(a2.x+n.x*ROAD*0.5,0.02,a2.y+n.y*ROAD*0.5),Vector3(b2.x+n.x*ROAD*0.5,0.02,b2.y+n.y*ROAD*0.5),Vector3(b2.x-n.x*ROAD*0.5,0.02,b2.y-n.y*ROAD*0.5),Vector3(a2.x-n.x*ROAD*0.5,0.02,a2.y-n.y*ROAD*0.5),Vector2(0,0),Vector2((L+2*e)/6,ROAD/6))
	for s in [-1,1]:
		var o0=n*s*ROAD*0.5;var o1=n*s*(ROAD*0.5+WALK)
		var p0=a+d*e*0.0;var p1=b
		# Gehweg (zwischen den Kreuzungen) als Platte auf 0.15
		var q=[Vector3(p0.x+o0.x,0.15,p0.y+o0.y),Vector3(p1.x+o0.x,0.15,p1.y+o0.y),Vector3(p1.x+o1.x,0.15,p1.y+o1.y),Vector3(p0.x+o1.x,0.15,p0.y+o1.y)]
		if s<0:q=[q[1],q[0],q[3],q[2]]
		quad(walk_mat,q[0],q[1],q[2],q[3],Vector2(0,0),Vector2(L/2.0,WALK/2.0))
		# Bordsteinkante
		var c=[Vector3(p0.x+o0.x,0.02,p0.y+o0.y),Vector3(p1.x+o0.x,0.02,p1.y+o0.y),Vector3(p1.x+o0.x,0.15,p1.y+o0.y),Vector3(p0.x+o0.x,0.15,p0.y+o0.y)]
		out_hint=Vector3((a.x+b.x)*0.5+n.x*s*(ROAD*0.5+WALK),0,(a.y+b.y)*0.5+n.y*s*(ROAD*0.5+WALK))
		quad(curb_mat,c[0],c[1],c[2],c[3],Vector2(0,0),Vector2(L/2,0.1))
		out_hint=Vector3.ZERO
	# Mittellinie gestrichelt
	var k=0.0
	while k<L-3:
		var m0=a+d*k;var m1=a+d*(k+3)
		quad(line_mat,Vector3(m0.x+n.x*0.07,0.03,m0.y+n.y*0.07),Vector3(m1.x+n.x*0.07,0.03,m1.y+n.y*0.07),Vector3(m1.x-n.x*0.07,0.03,m1.y-n.y*0.07),Vector3(m0.x-n.x*0.07,0.03,m0.y-n.y*0.07),Vector2(0,0),Vector2(1,1))
		k+=9
	# Bäume und Autos entlang längerer Straßen merken
	var t=8.0
	while t<L-8:
		var p=a+d*t
		if rng.randf()<0.5:tree_spots.append(Vector3(p.x+n.x*(ROAD*0.5+1.3),0.15,p.y+n.y*(ROAD*0.5+1.3)))
		if rng.randf()<0.18:car_spots.append([Vector3(p.x-n.x*(ROAD*0.5-1.3),0.02,p.y-n.y*(ROAD*0.5-1.3)),atan2(d.x,d.y)])
		if rng.randf()<0.25:people_spots.append(Vector3(p.x+n.x*(ROAD*0.5+2.6),0.15,p.y+n.y*(ROAD*0.5+2.6)))
		t+=16
var line_mat

# ---------------- Bezirke füllen ----------------
func fill_blocks(isl:Dictionary):
	for k in isl.cells:
		var c=isl.cells[k]   # 4 Ecken Vector2 (Block ohne Gehweg)
		var kind:String=isl.district.call(k,c)
		match kind:
			"tuerme":_block_towers(c)
			"buero":_block_ring(c,["buero_hell","buero_dunkel"],["laden_grau"],[22,40],false,14.0)
			"altbau":_block_ring(c,["altbau_creme","altbau_ocker","altbau_grau","altbau_rose","altbau_blau"],["laden_creme","laden_grau",""],[16,22],true,13.0)
			"platte":_block_ring(c,["platte_grau","platte_gelb"],[""],[18,30],false,12.0)
			"halle":_block_halls(c)
			"hafen":_block_port(c)
			"park":_block_park(c)
			"markt":_block_market(c)

func _v3(p:Vector2,y:=0.0)->Vector3:return Vector3(p.x,y,p.y)

# Blockrand: Häuserzeile entlang aller 4 Kanten, Tiefe d, Innenhof bleibt frei (Rasen + Bäume)
func _block_ring(c:Array,facades:Array,shopbands:Array,hr:Array,pitched:bool,d:float):
	for i in 4:
		var a:Vector2=c[i];var b:Vector2=c[(i+1)%4];var L=a.distance_to(b);var dir=(b-a)/L;var inn=((c[(i+2)%4]+c[(i+3)%4])*0.5-(a+b)*0.5).normalized()
		var s0=d if i%2==1 else 0.0;var s1=L-(d if i%2==1 else 0.0)   # Ecken: Kanten 1/3 kürzer, damit nichts überlappt
		var x=s0
		while s1-x>4.0:
			var w=min(s1-x,rng.randf_range(14.0,22.0))
			if s1-(x+w)<9.0:w=s1-x
			var p0=a+dir*x;var p1=a+dir*(x+w)
			var h=snapped(rng.randf_range(hr[0],hr[1]),3.25)+0.15
			var fac=facades[rng.randi()%facades.size()];var sb=shopbands[rng.randi()%shopbands.size()]
			block_building([_v3(p0),_v3(p1),_v3(p1+inn*d),_v3(p0+inn*d)],h,fac,sb,"",pitched)
			x+=w
	# Innenhof: Rasen
	var ctr=(c[0]+c[1]+c[2]+c[3])*0.25
	var gq=[];for v in c:gq.append(ctr+(v-ctr)*0.6)
	quad(Mats.pbr("grass",0.25),_v3(gq[0],0.03),_v3(gq[1],0.03),_v3(gq[2],0.03),_v3(gq[3],0.03),Vector2(0,0),Vector2(8,8))
	for k in 2:
		tree_spots.append(_v3(ctr+Vector2(rng.randf_range(-8,8),rng.randf_range(-8,8)),0.0))

func _block_towers(c:Array):
	var ctr=(c[0]+c[1]+c[2]+c[3])*0.25;var dir=(c[1]-c[0]).normalized();var ang=-atan2(dir.y,dir.x)
	var L=c[0].distance_to(c[1]);var D=c[1].distance_to(c[2])
	var styles=["turm_blau","turm_gruen","turm_bronze","buero_dunkel"]
	if rng.randf()<0.5:
		tower(_v3(ctr),L*0.55,D*0.55,rng.randf_range(80,190),styles[rng.randi()%styles.size()],ang)
	else:
		for s in [-1,1]:
			var off=dir*s*L*0.24
			tower(_v3(ctr+off),L*0.36,D*0.5,rng.randf_range(50,130),styles[rng.randi()%styles.size()],ang)

func _block_halls(c:Array):
	var ctr=(c[0]+c[1]+c[2]+c[3])*0.25;var dir=(c[1]-c[0]).normalized();var inn=(c[3]-c[0]).normalized()
	var L=c[0].distance_to(c[1]);var D=c[0].distance_to(c[3])
	# zwei Hallen mit Rolltoren zur Straße, Hof mit Containern
	for k in 2:
		var x0=4+k*(L*0.5);var w=L*0.5-8
		var p=[c[0]+dir*x0+inn*3,c[0]+dir*(x0+w)+inn*3,c[0]+dir*(x0+w)+inn*(D*0.55),c[0]+dir*x0+inn*(D*0.55)]
		block_building(p.map(func(v):return _v3(v)),10.15,"halle_ziegel","","")
		# Rolltor
		var t=Node3D.new();t.set_script(load("res://scripts/rolltor.gd"));add_child(t);t.setup(5.0,4.6,Color(0.55,0.57,0.6))
		var m=c[0]+dir*(x0+w*0.5)+inn*2.95;t.position=_v3(m,0.15);t.rotation.y=-atan2(dir.y,dir.x)+PI*0.5*0+(-PI*0.5)
	for k in 6:
		var p=c[0]+dir*rng.randf_range(8,L-12)+inn*rng.randf_range(D*0.65,D-8)
		_container(_v3(p,0.0),-atan2(dir.y,dir.x),rng.randi_range(1,2))

func _container(p:Vector3,yaw:float,stack:int):
	var cols=[Color(0.65,0.12,0.08),Color(0.1,0.3,0.55),Color(0.15,0.45,0.25),Color(0.85,0.55,0.1),Color(0.5,0.5,0.52)]
	for s in stack:
		var mi=MeshInstance3D.new();mi.mesh=BoxMesh.new();mi.mesh.size=Vector3(12.2,2.6,2.45);add_child(mi)
		mi.position=p+Vector3(0,1.3+s*2.6,0);mi.rotation.y=yaw
		var m=Mats.flat(cols[rng.randi()%cols.size()],0.6,0.4);mi.material_override=m

func _block_port(c:Array):
	var dir=(c[1]-c[0]).normalized();var inn=(c[3]-c[0]).normalized();var L=c[0].distance_to(c[1]);var D=c[0].distance_to(c[3])
	var yaw=-atan2(dir.y,dir.x)
	for r in 3:
		for k in int(L/13):
			if rng.randf()<0.85:_container(_v3(c[0]+dir*(6+k*13)+inn*(8+r*5)),yaw,rng.randi_range(1,3))


func _block_park(c:Array):
	var ctr=(c[0]+c[1]+c[2]+c[3])*0.25
	var g=Mats.pbr("grass",0.25)
	quad(g,_v3(c[0],0.16),_v3(c[1],0.16),_v3(c[2],0.16),_v3(c[3],0.16),Vector2(0,0),Vector2(c[0].distance_to(c[1])/4,c[1].distance_to(c[2])/4))
	for k in 7:tree_spots.append(_v3(ctr+Vector2(rng.randf_range(-22,22),rng.randf_range(-16,16)),0.16))
	# Weg (Kies)
	var kies=Mats.pbr("pavers",0.6,Color(0.8,0.75,0.65))
	quad(kies,_v3(c[0].lerp(c[3],0.45),0.17),_v3(c[1].lerp(c[2],0.45),0.17),_v3(c[1].lerp(c[2],0.55),0.17),_v3(c[0].lerp(c[3],0.55),0.17),Vector2(0,0),Vector2(10,1))

func _block_market(c:Array):
	var pav=Mats.pbr("cobble",0.35)
	quad(pav,_v3(c[0],0.16),_v3(c[1],0.16),_v3(c[2],0.16),_v3(c[3],0.16),Vector2(0,0),Vector2(c[0].distance_to(c[1])/3,c[1].distance_to(c[2])/3))
	var ctr=(c[0]+c[1]+c[2]+c[3])*0.25
	# Kirche am Markt
	var ch=Node3D.new();ch.set_script(load("res://scripts/street.gd"));add_child(ch);ch._church(_v3(ctr+(c[2]-c[1]).normalized()*20,0.15))
	# Brunnen
	var b=Batch.new();var st=Mats.pbr("concrete",0.5,Color(0.8,0.78,0.72))
	b.cyl(st,_v3(ctr,0.5),3.0,0.7);b.cyl(st,_v3(ctr,1.6),0.4,2.2);b.commit(self)
	for k in 4:people_spots.append(_v3(ctr+Vector2(rng.randf_range(-10,10),rng.randf_range(-10,10)),0.16))

# ---------------- Brücken ----------------
func bridge(a:Vector2,b:Vector2):
	var d=(b-a).normalized();var n=Vector2(-d.y,d.x);var L=a.distance_to(b);var W=ROAD+2*2.5;var H=9.0
	var deck=Mats.pbr("concrete",0.3,Color(0.6,0.6,0.6));var steel=Mats.flat(Color(0.35,0.38,0.42),0.4,0.8)
	var prof=func(t:float)->float:
		var ramp=min(t,L-t);return min(H,ramp*0.08)+0.15   # 8 % Steigung
	var seg=24
	for i in seg:
		var t0=L*i/seg;var t1=L*(i+1)/seg;var p0=a+d*t0;var p1=a+d*t1;var y0=prof.call(t0);var y1=prof.call(t1)
		quad(road_mat,Vector3(p0.x+n.x*ROAD*0.5,y0+0.02,p0.y+n.y*ROAD*0.5),Vector3(p1.x+n.x*ROAD*0.5,y1+0.02,p1.y+n.y*ROAD*0.5),Vector3(p1.x-n.x*ROAD*0.5,y1+0.02,p1.y-n.y*ROAD*0.5),Vector3(p0.x-n.x*ROAD*0.5,y0+0.02,p0.y-n.y*ROAD*0.5),Vector2(0,0),Vector2((t1-t0)/6,2))
		for s in [-1,1]:
			var o0=n*s*ROAD*0.5;var o1=n*s*W*0.5
			var q=[Vector3(p0.x+o0.x,y0+0.2,p0.y+o0.y),Vector3(p1.x+o0.x,y1+0.2,p1.y+o0.y),Vector3(p1.x+o1.x,y1+0.2,p1.y+o1.y),Vector3(p0.x+o1.x,y0+0.2,p0.y+o1.y)]
			if s<0:q=[q[1],q[0],q[3],q[2]]
			quad(walk_mat,q[0],q[1],q[2],q[3],Vector2(0,0),Vector2((t1-t0)/2,1))
		# Untersicht/Träger
		_quad_down(deck,Vector3(p0.x-n.x*W*0.5,y0-1.2,p0.y-n.y*W*0.5),Vector3(p1.x-n.x*W*0.5,y1-1.2,p1.y-n.y*W*0.5),Vector3(p1.x+n.x*W*0.5,y1-1.2,p1.y+n.y*W*0.5),Vector3(p0.x+n.x*W*0.5,y0-1.2,p0.y+n.y*W*0.5),Vector2(0,0),Vector2(2,2))
		for s in [-1,1]:
			var e0=Vector3(p0.x+n.x*s*W*0.5,0,p0.y+n.y*s*W*0.5);var e1=Vector3(p1.x+n.x*s*W*0.5,0,p1.y+n.y*s*W*0.5)
			var q2=[e0+Vector3(0,y0-1.2,0),e1+Vector3(0,y1-1.2,0),e1+Vector3(0,y1+0.2,0),e0+Vector3(0,y0+0.2,0)]
			out_hint=Vector3((p0.x+p1.x)*0.5,0,(p0.y+p1.y)*0.5)
			quad(deck,q2[0],q2[1],q2[2],q2[3],Vector2(0,0),Vector2((t1-t0)/4,0.4))
			out_hint=Vector3.ZERO
	# Geländer, Pfeiler, Pylone mit Seilen
	var bb=Batch.new()
	for s in [-1,1]:
		var k=0.0
		while k<=L:
			var p=a+d*k+n*s*(W*0.5-0.15);var y=prof.call(k)
			bb.box(steel,Vector3(p.x-0.04,y+0.2,p.y-0.04),Vector3(p.x+0.04,y+1.25,p.y+0.04));k+=2.5
		var pa=a+n*s*(W*0.5-0.15);var pb=b+n*s*(W*0.5-0.15)
	for k in range(1,int(L/40)):
		var p=a+d*k*40.0;var y=prof.call(k*40.0)
		bb.box(deck,Vector3(p.x-2,-6,p.y-2),Vector3(p.x+2,y-1.2,p.y+2))
	bb.commit(self)

# ---------------- Aufbau ----------------
func _ready():
	rng.seed=42
	if OS.has_environment("KDEBUG"):
		await get_tree().process_frame
	var args=OS.get_cmdline_user_args()
	load("res://scripts/env.gd").make(self,"sunset" if "--sunset" in args else "day")
	for we in find_children("*","WorldEnvironment",true,false):
		we.environment.fog_density=0.00035;we.environment.fog_aerial_perspective=0.3
	road_mat=Mats.pbr("asphalt",1.0,Color(1,1,1),false);walk_mat=Mats.pbr("pavers",1.0,Color(1,1,1),false);curb_mat=Mats.pbr("concrete",1.0,Color(0.8,0.8,0.78),false)
	line_mat=Mats.flat(Color(0.9,0.9,0.86),0.6)
	water()
	var pave=Mats.pbr("pavers",0.45)
	# Inseln (eigene Formen)
	var mid=smooth_poly([Vector2(-330,-520),Vector2(-80,-610),Vector2(240,-560),Vector2(360,-300),Vector2(330,40),Vector2(380,330),Vector2(260,560),Vector2(-40,640),Vector2(-300,520),Vector2(-360,200),Vector2(-300,-80),Vector2(-380,-300)])
	var west=smooth_poly([Vector2(-1020,-430),Vector2(-760,-520),Vector2(-560,-420),Vector2(-520,-120),Vector2(-560,180),Vector2(-700,330),Vector2(-950,280),Vector2(-1080,40)])
	var east=smooth_poly([Vector2(560,-560),Vector2(860,-620),Vector2(1080,-420),Vector2(1100,-60),Vector2(1060,300),Vector2(880,520),Vector2(620,480),Vector2(560,160),Vector2(600,-160)])
	islands=[
		{"name":"Innenstadt","poly":mid,"angle":0.08,"block":Vector2(74,58),"district":func(k,c):
			var p=(c[0]+c[2])*0.5
			if p.y<-120 and abs(p.x)<220:return "tuerme"
			if p.y<60:return "buero" if rng.randf()<0.5 else "altbau"
			if p.distance_to(Vector2(0,330))<60:return "markt"
			return "altbau"},
		{"name":"Hafen","poly":west,"angle":-0.12,"block":Vector2(96,70),"district":func(k,c):
			var p=(c[0]+c[2])*0.5
			return "hafen" if p.x<-850 else "halle"},
		{"name":"Wohnviertel","poly":east,"angle":0.2,"block":Vector2(70,60),"district":func(k,c):
			var p=(c[0]+c[2])*0.5
			if p.distance_to(Vector2(830,-60))<110:return "park"
			return "platte" if p.y<-250 else "altbau"},
	]
	for isl in islands:
		land(isl.poly,pave)
		grid_island(isl)
		fill_blocks(isl)
	# Brücken (Hauptachsen)
	bridge(Vector2(-560,-60),Vector2(-330,-40))
	bridge(Vector2(-600,120),Vector2(-345,160))
	bridge(Vector2(345,-200),Vector2(598,-170))
	bridge(Vector2(355,240),Vector2(580,250))
	commit_all()
	_trees();_cars();_people()
	var cam=Camera3D.new();cam.far=6000;cam.near=0.1;add_child(cam)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	var sv=func(target:Vector2,look_up:=6.0,fov:=62.0):
		var best=null;var bd=INF
		for r in road_list:
			var m=(r[0]+r[1])*0.5;var dd=m.distance_to(target)
			if dd<bd and r[0].distance_to(r[1])>40:bd=dd;best=r
		var d=(best[1]-best[0]).normalized();var p=(best[0]+best[1])*0.5-d*20.0+Vector2(-d.y,d.x)*2.0
		var t=p+d*60.0
		return [Vector3(p.x,1.7,p.y),Vector3(t.x,look_up,t.y),fov]
	sh.setup([
		[Vector3(-200,900,1600),Vector3(0,0,-50),42.0],
		[Vector3(800,280,700),Vector3(0,40,-250),52.0],
		sv.call(Vector2(0,-330),25.0),
		sv.call(Vector2(-60,180)),
		sv.call(Vector2(0,330),4.0),
		[Vector3(-470,14,-25),Vector3(-300,12,-45),55.0],
		sv.call(Vector2(-800,-100),5.0),
		sv.call(Vector2(780,-300)),
		sv.call(Vector2(820,120)),
		[Vector3(250,30,-500),Vector3(-50,60,-300),55.0]],"karte")

func _trees():
	var n=gl_tree();var k=0
	tree_spots.shuffle()
	for p in tree_spots:
		if k>260:break
		var w=n.duplicate();add_child(w);w.position=p+Vector3(0,-0.3,0);w.rotation.y=rng.randf()*TAU;var s=rng.randf_range(0.85,1.15);w.scale=Vector3(s,s,s);k+=1
var _tree:Node3D
func gl_tree()->Node3D:
	var n=load("res://assets/props/tree/tree.gltf").instantiate();var w=F.place(n,9.5);return w

func _cars():
	var VH=load("res://scripts/vehicles.gd");var kinds=["trabant","taxi","polizei","bmw_e30","mercedes","small_car","audi_rs7","porsche911","bmw_m8","audi_r8"]
	car_spots.shuffle();var tmpl={}
	for i in min(90,car_spots.size()):
		var kd=kinds[rng.randi()%kinds.size()]
		if not tmpl.has(kd):tmpl[kd]=VH.make(kd)
		var v=tmpl[kd].duplicate();add_child(v);v.position=car_spots[i][0];v.rotation.y=car_spots[i][1]+(PI if tmpl[kd].get_meta("front",1.0)<0 else 0.0)

func _people():
	var PE=load("res://scripts/people.gd");var prng=RandomNumberGenerator.new();prng.seed=9
	people_spots.shuffle()
	for i in min(60,people_spots.size()):
		var p=PE.make(["joe","biker","daya","female"][i%4],prng);add_child(p);p.position=people_spots[i];p.rotation.y=prng.randf()*TAU
		PE.play(p,["walk","idle","talk"][i%3],prng.randf())

func _quad_down(m,a,b,c,d,uv0,uv1):
	var st=st_for(m);st.set_normal(Vector3.DOWN)
	for v in [a,c,b,a,d,c]:st.set_uv(Vector2(0,0));st.add_vertex(v)
