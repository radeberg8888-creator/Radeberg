extends RefCounted
# Gelände der Insel Radeberg: Höhenfunktion, Bezirke, Geländemesh mit Bodenarten.
# Koordinaten: x = Osten, z = Süden. Insel ca. 3,4 x 2,8 km, rundherum Meer (Wasser y = 0).
const SX:=1750.0
const SZ:=1450.0
const STEP:=10.0

var noise:=FastNoiseLite.new()
var noise2:=FastNoiseLite.new()
var cut:Dictionary={}        # Gitterzelle -> [Sollhöhe, Gewicht] (Straßen/Plätze glätten das Gelände)
var heights:PackedFloat32Array
var holes:={}
var nx:int;var nz:int

# Bezirke (Mittelpunkt, Radius) für Höhen und Bodenarten
const MOUNTAIN:=Vector2(-1080,-820)
const HILLS:=Vector2(760,-860)
const DESERT:=Vector2(-1080,620)

func _init():
	noise.seed=7;noise.frequency=0.0016;noise.fractal_octaves=5
	noise2.seed=11;noise2.frequency=0.006;noise2.fractal_octaves=3

# Inselmaske 0..1 (1 = Land), Küste leicht zerklüftet
func island(x:float,z:float)->float:
	var e=Vector2(x/SX,z/SZ).length()+noise.get_noise_2d(x*0.6,z*0.6)*0.12
	return clamp((1.0-e)/0.12,0.0,1.0)

var plateaus:=[]   # [Vector2 Mitte, Radius, Übergang, Höhe] – ebene Flächen (Bahnhof, Flugplatz, Hafen)
func base_height(x:float,z:float)->float:
	var h=_nat(x,z)
	for p in plateaus:
		var d=Vector2(x,z).distance_to(p[0])
		if d<p[1]+p[2]:h=lerp(h,p[3],1.0-smoothstep(p[1],p[1]+p[2],d))
	return h
func _nat(x:float,z:float)->float:
	var m=island(x,z)
	var h=13.0+noise.get_noise_2d(x,z)*11.0
	# Berg im Nordwesten (wie Mount Chiliad), mit Graten
	var dm=Vector2(x,z).distance_to(MOUNTAIN)
	h+=235.0*exp(-pow(dm/430.0,2))*(0.9+0.18*noise2.get_noise_2d(x*0.35,z*0.35))+18.0*exp(-pow(dm/200.0,2))
	h+=60.0*exp(-pow(Vector2(x,z).distance_to(Vector2(-700,-1050))/260.0,2))
	# Hügel im Nordosten (Villenviertel)
	h+=70.0*exp(-pow(Vector2(x,z).distance_to(HILLS)/330.0,2))
	h+=30.0*exp(-pow(Vector2(x,z).distance_to(Vector2(200,-1020))/240.0,2))
	# Wüste im Südwesten: flach mit Dünen und Tafelbergen
	var dd=Vector2(x,z).distance_to(DESERT)
	if dd<650:
		var k=1.0-smoothstep(380.0,650.0,dd)
		h=lerp(h,9.0+abs(noise2.get_noise_2d(x*2.0,z*2.0))*7.0,k)
		h+=45.0*exp(-pow(Vector2(x,z).distance_to(Vector2(-1420,330))/120.0,2))
	# Stadtgebiet sanft (leichte Hügel und eine Senke im Ghetto)
	h-=7.0*exp(-pow(Vector2(x,z).distance_to(Vector2(-250,640))/300.0,2))
	h+=12.0*exp(-pow(Vector2(x,z).distance_to(Vector2(650,520))/300.0,2))
	# Küste: Strand und Meeresboden
	if m>=1.0:h=max(h,3.0+abs(noise2.get_noise_2d(x,z))*2.0)
	# Küstenabfall: im Randstreifen sanft zum Strand, dann Meeresgrund
	return lerp(-14.0,lerp(1.2,h,smoothstep(0.0,1.0,m*m)),smoothstep(0.0,0.35,m)) if m<1.0 else h

func idx(i:int,k:int)->int:return k*nx+i
func build_heights():
	nx=int(2*SX/STEP)+1;nz=int(2*SZ/STEP)+1
	heights.resize(nx*nz)
	for k in nz:
		for i in nx:
			heights[idx(i,k)]=base_height(-SX+i*STEP,-SZ+k*STEP)

func h_at(x:float,z:float)->float:
	var fx=(x+SX)/STEP;var fz=(z+SZ)/STEP
	var i=clampi(int(fx),0,nx-2);var k=clampi(int(fz),0,nz-2);var tx=clamp(fx-i,0.0,1.0);var tz=clamp(fz-k,0.0,1.0)
	var a=heights[idx(i,k)];var b=heights[idx(i+1,k)];var c=heights[idx(i,k+1)];var d=heights[idx(i+1,k+1)]
	return lerp(lerp(a,b,tx),lerp(c,d,tx),tz)

# Gelände an Straßen/Plätze anpassen: Gitterpunkte im Radius bekommen die Sollhöhe (weicher Übergang)
func flatten(p:Vector2,y:float,r_core:float,r_fade:float):
	var r=r_core+r_fade
	var i0=int((p.x-r+SX)/STEP);var i1=int((p.x+r+SX)/STEP)+1;var k0=int((p.y-r+SZ)/STEP);var k1=int((p.y+r+SZ)/STEP)+1
	for k in range(max(k0,0),min(k1,nz-1)+1):
		for i in range(max(i0,0),min(i1,nx-1)+1):
			var q=Vector2(-SX+i*STEP,-SZ+k*STEP);var d=q.distance_to(p)
			if d>r:continue
			var w=1.0 if d<=r_core else 1.0-smoothstep(r_core,r,d)
			var key=idx(i,k)
			if not cut.has(key) or cut[key][1]<w:cut[key]=[y,w]
func apply_cut():
	for key in cut:
		var c=cut[key];heights[key]=lerp(heights[key],c[0]-0.15,c[1])

# Bodenart je Punkt: RGBA = Gras, Wald, Sand, Fels (Rest = Trockengras)
func soil(x:float,z:float,h:float,slope:float)->Color:
	var dd=Vector2(x,z).distance_to(DESERT)+noise2.get_noise_2d(x*0.35,z*0.35)*160.0;var dm=Vector2(x,z).distance_to(MOUNTAIN)
	var sand=1.0-smoothstep(380.0,560.0,dd)
	var beach=1.0-smoothstep(0.12,0.4,island(x,z))
	sand=max(sand,beach)
	var forest=(1.0-smoothstep(380.0,560.0,dm))*smoothstep(25.0,40.0,h)*(1.0-smoothstep(170.0,200.0,h))
	forest=max(forest,(1.0-smoothstep(260.0,380.0,Vector2(x,z).distance_to(HILLS)))*0.6)
	var rock=smoothstep(0.55,0.85,slope)+smoothstep(175.0,215.0,h)
	rock=clamp(rock,0.0,1.0)
	var grass=clamp(1.0-sand-forest-rock,0.0,1.0)
	# trockene Flecken und Übergang zur Wüste (Rest = Trockengras)
	var dryp=smoothstep(0.05,0.35,noise2.get_noise_2d(x*0.25+400.0,z*0.25))*0.75+(1.0-smoothstep(500.0,760.0,dd))*0.8
	grass*=1.0-clamp(dryp,0.0,0.9)
	return Color(grass,forest*(1.0-rock),sand*(1.0-rock),rock)

func build_mesh(parent:Node3D):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts=PackedVector3Array();verts.resize(nx*nz)
	for k in nz:
		for i in nx:verts[idx(i,k)]=Vector3(-SX+i*STEP,heights[idx(i,k)],-SZ+k*STEP)
	for k in nz:
		for i in nx:
			var p=verts[idx(i,k)]
			var hl=heights[idx(max(i-1,0),k)];var hr=heights[idx(min(i+1,nx-1),k)];var hd=heights[idx(i,max(k-1,0))];var hu=heights[idx(i,min(k+1,nz-1))]
			var n=Vector3(hl-hr,2*STEP,hd-hu).normalized()
			st.set_normal(n);st.set_color(soil(p.x,p.z,p.y,1.0-n.y));st.set_uv(Vector2(p.x,p.z)/6.0)
			st.add_vertex(p)
	for k in nz-1:
		for i in nx-1:
			var a=idx(i,k);var b=idx(i+1,k);var c=idx(i,k+1);var d=idx(i+1,k+1)
			# nur Dreiecke über dem Meeresgrund nahe der Insel
			if heights[a]<-12 and heights[b]<-12 and heights[c]<-12 and heights[d]<-12:continue
			if holes.has(Vector2i(i,k)):continue
			st.add_index(a);st.add_index(b);st.add_index(c);st.add_index(b);st.add_index(d);st.add_index(c)
	st.generate_tangents()
	var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.name="Gelaende"
	var sm=ShaderMaterial.new();sm.shader=load("res://shaders/terrain.gdshader")
	var T="res://assets/textures/"
	for t in [["grass","g"],["forest","f"],["sand","s"],["rock","r"],["drygrass","d"]]:
		sm.set_shader_parameter(t[1]+"_alb",load(T+t[0]+"_albedo.jpg"));sm.set_shader_parameter(t[1]+"_nrm",load(T+t[0]+"_normal.png"))
	mi.material_override=sm;parent.add_child(mi)
	return mi
