extends RefCounted
# Gelände von Radeberg County: eine große Insel (ca. 6 x 11 km). Süden: Radeberg City (Hauptstadt) mit Hafen,
# Flughafen, Strand; nördlich davon die Sonnenhügel (Nobelviertel), dann die Staubebene mit dem Staubsee und dem
# Trailerdorf Staubwinkel, Roter Canyon im Osten, Farmland, im Norden der Radeberg-Gipfel mit dem Espenwald und
# die Küstenstadt Nordbucht. Koordinaten: x = Osten, z = Süden (negativ = Norden). Wasser y = 0.
const X0:=-4400.0
const X1:=4700.0
const Z0:=-11300.0
const Z1:=3500.0
const STEP:=10.0

var noise:=FastNoiseLite.new()
var noise2:=FastNoiseLite.new()
var noise3:=FastNoiseLite.new()
var cut:Dictionary={}        # Gitterzelle -> [Sollhöhe, Gewicht] (Straßen/Plätze glätten das Gelände)
var heights:PackedFloat32Array
var holes:={}
var nx:int;var nz:int

# Landschaften
const STADT:=Vector2(0,550)             # Radeberg City (Ellipse 2750 x 2050)
const MOUNTAIN:=Vector2(-700,-8350)    # Radeberg-Gipfel
const HILLS:=Vector2(-200,-1900)       # Sonnenhügel (Nobelviertel)
const DESERT:=Vector2(-2050,2050)      # Flughafen-Halbinsel
const DESERT2:=Vector2(900,-5700)      # Staubebene (Wüste)
const SEE:=Vector2(550,-6650)          # Staubsee
const SEE_R:=Vector2(1500,520)
const CANYON:=Vector2(-250,-5650)
const ESPEN:=Vector2(-2000,-6200)      # Espenwald
const ESPEN2:=Vector2(1000,-8800)      # Nordwald
const FARM:=Vector2(2350,-7700)
const NORDBUCHT:=Vector2(-2350,-9100)  # langgezogene Küstenstadt im Nordwesten
const DORF:=Vector2(1750,-5950)        # Staubwinkel (Trailerdorf am See)
const MILITAER:=Vector2(-2600,-5450)   # Militärflugplatz
const FLUGHAFEN:=Vector2(-2050,2050)   # internationaler Flughafen
const DOCKS:=Vector2(800,2050)
const STAUSEE:=Vector2(-650,-2550)

func _init():
	noise.seed=7;noise.frequency=0.0016;noise.fractal_octaves=5
	noise2.seed=11;noise2.frequency=0.006;noise2.fractal_octaves=3
	noise3.seed=23;noise3.frequency=0.0006;noise3.fractal_octaves=4
	_laden()

# Vorberechnetes Gelände (tools/gelaende_bake.py): natürliche Höhen, Küstenabstand, Bodenarten
var _nh:PackedFloat32Array;var _kd:PackedFloat32Array;var _bo:PackedByteArray
var rx:int;var rz:int
func _laden():
	var f=FileAccess.open("res://assets/cache/gelaende.bin",FileAccess.READ)
	if f==null:push_error("gelaende.bin fehlt");return
	f.get_buffer(4);rx=f.get_32();rz=f.get_32();f.get_float();f.get_float();f.get_float()
	_nh=f.get_buffer(rx*rz*4).to_float32_array()
	_kd=f.get_buffer(rx*rz*4).to_float32_array()
	_bo=f.get_buffer(rx*rz*4)

func _bilin(a:PackedFloat32Array,x:float,z:float)->float:
	var fx=(x-X0)/STEP;var fz=(z-Z0)/STEP
	var i=clampi(int(fx),0,rx-2);var k=clampi(int(fz),0,rz-2);var tx=clamp(fx-i,0.0,1.0);var tz=clamp(fz-k,0.0,1.0)
	var j=k*rx+i
	return lerp(lerp(a[j],a[j+1],tx),lerp(a[j+rx],a[j+rx+1],tx),tz)

func kuesten_abstand(x:float,z:float)->float:return _bilin(_kd,x,z)

# Inselmaske 0..1 (1 = Land)
func island(x:float,z:float)->float:
	return clamp((kuesten_abstand(x,z)+40.0)/160.0,0.0,1.0)

var plateaus:=[]   # [Vector2 Mitte, Radius, Übergang, Höhe] – ebene Flächen (Bahnhof, Flugplatz, Hafen, Dörfer)
func base_height(x:float,z:float)->float:
	var h=_nat(x,z)
	for p in plateaus:
		var d=Vector2(x,z).distance_to(p[0])
		if d<p[1]+p[2]:h=lerp(h,p[3],1.0-smoothstep(p[1],p[1]+p[2],d))
	return h

func _nat(x:float,z:float)->float:return _bilin(_nh,x,z)

func idx(i:int,k:int)->int:return k*nx+i
func build_heights():
	nx=rx;nz=rz
	heights=_nh.duplicate()
	for p in plateaus:
		var r=p[1]+p[2]
		var i0=max(int((p[0].x-r-X0)/STEP),0);var i1=min(int((p[0].x+r-X0)/STEP)+1,nx-1)
		var k0=max(int((p[0].y-r-Z0)/STEP),0);var k1=min(int((p[0].y+r-Z0)/STEP)+1,nz-1)
		for k in range(k0,k1+1):
			for i in range(i0,i1+1):
				var d=Vector2(X0+i*STEP,Z0+k*STEP).distance_to(p[0])
				if d<r:heights[idx(i,k)]=lerp(heights[idx(i,k)],p[3],1.0-smoothstep(p[1],r,d))

func h_at(x:float,z:float)->float:
	var fx=(x-X0)/STEP;var fz=(z-Z0)/STEP
	var i=clampi(int(fx),0,nx-2);var k=clampi(int(fz),0,nz-2);var tx=clamp(fx-i,0.0,1.0);var tz=clamp(fz-k,0.0,1.0)
	var a=heights[idx(i,k)];var b=heights[idx(i+1,k)];var c=heights[idx(i,k+1)];var d=heights[idx(i+1,k+1)]
	return lerp(lerp(a,b,tx),lerp(c,d,tx),tz)

# Gelände an Straßen/Plätze anpassen: Gitterpunkte im Radius bekommen die Sollhöhe (weicher Übergang)
func flatten(p:Vector2,y:float,r_core:float,r_fade:float,maske:=Callable()):
	var r=r_core+r_fade
	var i0=int((p.x-r-X0)/STEP);var i1=int((p.x+r-X0)/STEP)+1;var k0=int((p.y-r-Z0)/STEP);var k1=int((p.y+r-Z0)/STEP)+1
	for k in range(max(k0,0),min(k1,nz-1)+1):
		for i in range(max(i0,0),min(i1,nx-1)+1):
			var q=Vector2(X0+i*STEP,Z0+k*STEP);var d=q.distance_to(p)
			if d>r:continue
			if maske.is_valid() and not maske.call(q):continue
			var w=1.0 if d<=r_core else 1.0-smoothstep(r_core,r,d)
			var key=idx(i,k)
			if not cut.has(key) or cut[key][1]<w:cut[key]=[y,w]
func apply_cut():
	for key in cut:
		var c=cut[key];heights[key]=lerp(heights[key],c[0]-0.15,c[1])

# Bodenart je Punkt: RGBA = Gras, Wald, Sand, Fels (Rest = Trockengras) – aus dem vorberechneten Raster
func soil(x:float,z:float,h:float,slope:float)->Color:
	var i=clampi(int(round((x-X0)/STEP)),0,rx-1);var k=clampi(int(round((z-Z0)/STEP)),0,rz-1)
	var j=(k*rx+i)*4
	var rock=max(_bo[j+3]/255.0,smoothstep(0.55,0.85,slope))
	var c=Color(_bo[j]/255.0,_bo[j+1]/255.0,_bo[j+2]/255.0,rock)
	if rock>c.a:c.r*=1.0-rock;c.g*=1.0-rock;c.b*=1.0-rock
	return c

# Geländemesh in Kacheln (640 m): Sichtbarkeit je Kachel, Meeresgrund weglassen
const TILE:=64
func build_mesh(parent:Node3D):
	var sm=ShaderMaterial.new();sm.shader=load("res://shaders/terrain.gdshader")
	var T="res://assets/textures/"
	for t in [["grass","g"],["forest","f"],["sand","s"],["rock","r"],["drygrass","d"]]:
		sm.set_shader_parameter(t[1]+"_alb",load(T+t[0]+"_albedo.jpg"));sm.set_shader_parameter(t[1]+"_nrm",load(T+t[0]+"_normal.png"))
	# Normalen + Bodenarten einmal für das ganze Gitter
	var N=PackedVector3Array();N.resize(nx*nz)
	var C=PackedColorArray();C.resize(nx*nz)
	for k in nz:
		for i in nx:
			var hl=heights[idx(max(i-1,0),k)];var hr=heights[idx(min(i+1,nx-1),k)];var hd=heights[idx(i,max(k-1,0))];var hu=heights[idx(i,min(k+1,nz-1))]
			var n=Vector3(hl-hr,2*STEP,hd-hu).normalized();N[idx(i,k)]=n
			var h=heights[idx(i,k)]
			C[idx(i,k)]=soil(X0+i*STEP,Z0+k*STEP,h,1.0-n.y) if h>-13.0 else Color(0,0,1,0)
	var first=null
	for tk in range(0,nz-1,TILE):
		for ti in range(0,nx-1,TILE):
			var V=PackedVector3Array();var NN=PackedVector3Array();var CC=PackedColorArray();var UV=PackedVector2Array();var I=PackedInt32Array()
			var map={}
			var i1=min(ti+TILE,nx-1);var k1=min(tk+TILE,nz-1)
			for k in range(tk,k1):
				for i in range(ti,i1):
					var a=idx(i,k);var b=idx(i+1,k);var c=idx(i,k+1);var d=idx(i+1,k+1)
					if heights[a]<-12 and heights[b]<-12 and heights[c]<-12 and heights[d]<-12:continue
					if holes.has(Vector2i(i,k)):continue
					var q=[]
					for g in [a,b,c,d]:
						if not map.has(g):
							map[g]=V.size()
							var gi=g%nx;var gk=g/nx
							var p=Vector3(X0+gi*STEP,heights[g],Z0+gk*STEP)
							V.append(p);NN.append(N[g]);CC.append(C[g]);UV.append(Vector2(p.x,p.z)/6.0)
						q.append(map[g])
					I.append_array([q[0],q[1],q[2],q[1],q[3],q[2]])
			if I.is_empty():continue
			var arr=[];arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX]=V;arr[Mesh.ARRAY_NORMAL]=NN;arr[Mesh.ARRAY_COLOR]=CC;arr[Mesh.ARRAY_TEX_UV]=UV;arr[Mesh.ARRAY_INDEX]=I
			var st=SurfaceTool.new();st.create_from_arrays(arr);st.generate_tangents()
			var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.name="Gelaende_%d_%d"%[ti/TILE,tk/TILE]
			mi.material_override=sm;parent.add_child(mi)
			if first==null:first=mi
	return first
