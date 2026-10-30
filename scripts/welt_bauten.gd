extends RefCounted
# Gebäude der Insel: Belegungsraster (2 m), Vorlagen aus den echten Modellen (bereinigt, beidseitig),
# Farb-/Schmutzvarianten je Haus, Platzierung entlang der Straßen je Bezirk, Bauplätze ebnen.
const F=preload("res://scripts/fit.gd")
const CELL:=2.0
var G;var S
var occ:PackedByteArray
var ox:int;var oz:int
var tpl:={}            # name -> Vorlage
var placed:=[]         # Platzierungen
var rng:=RandomNumberGenerator.new()
const E="res://assets/buildings/einzeln/"
const B="res://assets/buildings/"
# Bezirke: Mittelpunkt, Radius, Vorlagenliste [name, gewicht], Abstand zwischen Häusern, Schmutz
var DIST=[
	{"n":"downtown","c":Vector2(250,-350),"r":560.0,"gap":[0.5,3.0],"dirt":0.15,
		"list":[["nycity_02",2],["nycity_04",2],["nycity_06",2],["nycity_07",2],["nycity_09",2],["nycity_10",3],["nycity_19",3],["nycity_20",3],
			["city_04",1],["city_09",2],["city_10",2],["city_11",2],["city_12",2],["city_17",1],
			["beautiful_00",2],["beautiful_01",2],["beautiful_02",2],["beautiful_03",2],["beautiful_04",2],["nyc_00",1],["realcity_10",2],["realcity_04",2]]},
	{"n":"ghetto","c":Vector2(-250,680),"r":520.0,"gap":[0.0,9.0],"dirt":1.0,
		"list":[["house",7],["ghetto",7],["stash",3],["nyc_01",2],["city3_02",2],["cityscene_00",2],["cityscene_01",2],["chicago_00",2],
			["cityscene2_04",1],["cityscene2_08",1],["cityscene2_13",1],["cityscene2_14",1],["cityscene2_29",1]]},
	{"n":"ost","c":Vector2(960,-120),"r":280.0,"gap":[0.0,4.0],"dirt":0.35,
		"list":[["cityscene2_04",2],["cityscene2_08",2],["cityscene2_13",2],["cityscene2_14",2],["cityscene2_20",2],["cityscene2_24",2],["nyc_00",2],["nyc_01",2],["chicago_00",2],["city_18",1],["city3_02",1],["house",1],["stash",1]]},
	{"n":"altstadt","c":Vector2(-150,120),"r":400.0,"gap":[0.0,2.0],"dirt":0.45,
		"list":[["cityscene2_00",1],["cityscene2_01",1],["cityscene2_03",1],["cityscene2_04",2],["cityscene2_05",1],["cityscene2_06",1],["cityscene2_08",2],["cityscene2_10",1],
			["cityscene2_12",1],["cityscene2_13",2],["cityscene2_14",2],["cityscene2_15",2],["cityscene2_16",2],["cityscene2_20",2],["cityscene2_24",2],["cityscene2_28",2],
			["cityscene2_29",1],["cityscene2_34",2],["nyc_00",2],["nyc_01",2],["chicago_00",2],["city3_02",2],["city_18",1],["house",2]]},
	{"n":"vorort","c":Vector2(760,-840),"r":340.0,"gap":[8.0,22.0],"dirt":0.25,
		"list":[["stash",6],["cityscene2_01",1],["cityscene2_02",1],["cityscene2_07",1],["cityscene2_11",1]]},
	{"n":"strand","c":Vector2(-2080,-80),"r":520.0,"gap":[2.0,8.0],"dirt":0.25,
		"list":[["cityscene2_01",2],["cityscene2_02",2],["cityscene2_05",2],["cityscene2_07",2],["cityscene2_11",2],["beautiful_01",1],["beautiful_03",1],["nyc_00",1],["realcity_18",1]]},
	{"n":"kowloon","c":Vector2(-2050,-1150),"r":260.0,"gap":[0.0,3.0],"dirt":0.6,
		"list":[["cityscene2_04",2],["cityscene2_13",2],["cityscene2_20",2],["nyc_00",2],["nyc_01",2],["chicago_00",2],["city3_02",2]]},
	{"n":"stern","c":Vector2(1080,-520),"r":330.0,"gap":[0.0,3.0],"dirt":0.3,
		"list":[["realcity_18",2],["realcity_04",2],["realcity_10",1],["city_09",1],["beautiful_02",1],["cityscene2_15",2],["cityscene2_16",2]]},
	{"n":"nordbucht","c":Vector2(-2150,-8700),"r":700.0,"gap":[3.0,10.0],"dirt":0.4,
		"list":[["stash",3],["house",2],["cityscene2_01",2],["cityscene2_02",2],["cityscene2_05",1],["cityscene2_07",2],["cityscene2_11",1],["cityscene2_04",1],["marino",1]]},
	{"n":"staubwinkel","c":Vector2(1750,-5950),"r":260.0,"gap":[4.0,14.0],"dirt":1.0,
		"list":[["house",4],["ghetto",4],["stash",3],["marino",1]]},
	{"n":"sandufer","c":Vector2(880,-5900),"r":820.0,"gap":[3.0,14.0],"dirt":0.95,
		"list":[["house",4],["ghetto",3],["stash",4],["marino",1]]},
	{"n":"kornfeld","c":Vector2(1720,-7550),"r":520.0,"gap":[8.0,26.0],"dirt":0.6,
		"list":[["stash",5],["house",3],["marino",1]]},
	{"n":"fischerdorf","c":Vector2(-840,-6680),"r":260.0,"gap":[6.0,18.0],"dirt":0.7,
		"list":[["stash",3],["house",2],["marino",2]]},
	{"n":"industrie","c":Vector2(920,560),"r":300.0,"gap":[4.0,12.0],"dirt":0.6,
		"list":[["proc3_07",2],["proc3_08",2],["city3_01",1],["cityscene_00",1]]},
	{"n":"docks","c":Vector2(400,2100),"r":1000.0,"zmin":1880.0,"gap":[6.0,16.0],"dirt":0.7,
		"list":[["proc3_07",2],["proc3_08",2],["city3_01",1]]},
	{"n":"suedstadt","c":Vector2(250,1580),"r":800.0,"gap":[0.0,6.0],"dirt":0.75,
		"list":[["house",4],["ghetto",3],["stash",2],["nyc_01",2],["city3_02",2],["cityscene_00",2],["cityscene_01",2],["chicago_00",2],["cityscene2_04",1],["cityscene2_13",1],["proc3_07",1]]},
	{"n":"ostvorort","c":Vector2(2500,-1050),"r":800.0,"gap":[8.0,22.0],"dirt":0.2,
		"list":[["stash",6],["cityscene2_01",1],["cityscene2_02",1],["cityscene2_07",1],["cityscene2_11",1]]},
	{"n":"oststadt","c":Vector2(2750,700),"r":1300.0,"gap":[0.5,4.0],"dirt":0.3,
		"list":[["realcity_18",2],["realcity_04",2],["realcity_10",1],["city_09",1],["city_10",1],["city_11",1],["nycity_04",1],["nycity_06",1],["beautiful_02",1],["cityscene2_15",2],["cityscene2_16",2],["cityscene2_20",2],["nyc_00",2]]},
	{"n":"stadt","c":Vector2(-200,500),"r":3800.0,"zmin":-1600.0,"gap":[0.5,5.0],"dirt":0.4,
		"list":[["cityscene2_00",1],["cityscene2_03",1],["cityscene2_04",2],["cityscene2_06",1],["cityscene2_08",2],["cityscene2_10",1],["cityscene2_12",1],["cityscene2_13",2],
			["cityscene2_14",2],["cityscene2_15",1],["cityscene2_16",1],["cityscene2_20",2],["cityscene2_24",2],["cityscene2_28",1],["cityscene2_34",1],["nyc_00",2],["nyc_01",2],
			["chicago_00",2],["city3_02",1],["city_18",1],["realcity_18",2]]},
]

func _init(g,s):
	G=g;S=s;rng.seed=99
	ox=int((G.X1-G.X0)/CELL)+1;oz=int((G.Z1-G.Z0)/CELL)+1
	occ.resize(ox*oz)

func _c(p:Vector2)->Vector2i:return Vector2i(int((p.x-G.X0)/CELL),int((p.y-G.Z0)/CELL))
func is_free(p:Vector2)->bool:
	var c=_c(p)
	if c.x<0 or c.y<0 or c.x>=ox or c.y>=oz:return false
	return occ[c.y*ox+c.x]==0
func stamp(p:Vector2,r:float,v:=1):
	var c0=_c(p-Vector2(r,r));var c1=_c(p+Vector2(r,r))
	for k in range(max(c0.y,0),min(c1.y,oz-1)+1):
		for i in range(max(c0.x,0),min(c1.x,ox-1)+1):
			var q=Vector2(G.X0+(i+0.5)*CELL,G.Z0+(k+0.5)*CELL)
			if q.distance_to(p)<=r:occ[k*ox+i]=v
# gedrehtes Rechteck (Mitte, Achse a = Längsrichtung, halbe Maße)
func _rect_cells(c:Vector2,a:Vector2,hx:float,hz:float)->Array:
	var n=Vector2(-a.y,a.x);var r=sqrt(hx*hx+hz*hz)
	var c0=_c(c-Vector2(r,r));var c1=_c(c+Vector2(r,r));var out=[]
	for k in range(max(c0.y,0),min(c1.y,oz-1)+1):
		for i in range(max(c0.x,0),min(c1.x,ox-1)+1):
			var q=Vector2(G.X0+(i+0.5)*CELL,G.Z0+(k+0.5)*CELL)-c
			if abs(q.dot(a))<=hx and abs(q.dot(n))<=hz:out.append(k*ox+i)
	return out
func rect_free(c:Vector2,a:Vector2,hx:float,hz:float)->bool:
	for idx in _rect_cells(c,a,hx,hz):
		if occ[idx]!=0:return false
	return true
var reserviert:=[]   # [mitte, richtung, hx, hz] – von Anlagen freigehaltene Flächen (für die Blockbebauung)
var reservieren_mitschreiben:=true
func rect_mark(c:Vector2,a:Vector2,hx:float,hz:float,v:=2):
	if reservieren_mitschreiben and v==2:reserviert.append([c,a,hx,hz])
	for idx in _rect_cells(c,a,hx,hz):occ[idx]=v

func mark_roads():
	for r in S.roads:
		var rr=r.w+r.sw+0.8
		if r.typ=="schiene":rr=4.0
		if r.typ=="autobahn":rr=r.w+6.0
		for i in r.P.size():
			if r.tunnel_flags[i]:continue
			stamp(r.P[i],rr)

# ---------------- Vorlagen ----------------
func _path(name:String)->Array:
	if name=="house":return [B+"house/house.gltf",0.03,true]
	if name=="ghetto":return [B+"ghetto/ghetto.gltf",1.0,true]
	if name=="stash":return [B+"stash/stash.gltf",1.0,true]
	if name=="citybuilding":return ["res://assets/staedte/citybuilding/citybuilding.gltf",0.1,true]
	if name=="realbuilding":return ["res://assets/staedte/realbuilding/realbuilding.gltf",0.06,true]
	if name=="harley":return ["res://assets/props/neu/harley/harley.gltf",0.018,true]
	if name=="marino":return ["res://assets/staedte/marino/marino.gltf",1.0,true]
	var d=name.substr(0,name.rfind("_"))
	return [E+d+"/"+name+".gltf",1.0,false]

func _meshes(n:Node)->Array:return n.find_children("*","MeshInstance3D",true,false)

# Viertel der Hauptstadt mit Blockrandbebauung (scripts/welt_bloecke.gd)
const BLOCK_VIERTEL:=["downtown","ghetto","ost","altstadt","stern","suedstadt","oststadt","stadt","industrie"]
var spiel:=false
var ohne_dach:=false   # Spiel mit vorbereiteten Gebäudemodellen: Dach steckt schon im Mesh
const CACHE:="res://assets/cache/"
var _cache_meta=null
func _meta()->Dictionary:
	if _cache_meta==null:
		_cache_meta={}
		var f=FileAccess.open(CACHE+"vorlagen.json",FileAccess.READ)
		if f:_cache_meta=JSON.parse_string(f.get_as_text())
	return _cache_meta
# Vorlagen-Maße, versteckte Bodenplatten und Dachflächen vorab berechnen (spart beim Spielstart ~1,5 Minuten)
func bake_cache():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE))
	var names={}
	for d in DIST:
		for e in d.list:names[e[0]]=true
	names["stash"]=true
	var meta={}
	for n in names:
		var t=_build_tpl(n)
		var ab:AABB=t.ab
		meta[n]={"ab":[ab.position.x,ab.position.y,ab.position.z,ab.size.x,ab.size.y,ab.size.z],"hide":t.hide,"roof":t.roof!=null}
		if t.roof!=null:ResourceSaver.save(t.roof,CACHE+"dach_"+n+".res")
		print("BAKE ",n)
	var f=FileAccess.open(CACHE+"vorlagen.json",FileAccess.WRITE);f.store_string(JSON.stringify(meta));f.close()

func get_tpl(name:String)->Dictionary:
	if tpl.has(name):return tpl[name]
	var m=_meta()
	if m.has(name):
		var e=m[name];var pp=_path(name);var a=e.ab
		var t={"name":name,"path":pp[0],"sc":pp[1],"fixed":pp[2],"ab":AABB(Vector3(a[0],a[1],a[2]),Vector3(a[3],a[4],a[5])),"hide":e.hide,"var":{}}
		t.roof=load(CACHE+"dach_"+name+".res") if e.roof and not ohne_dach else null
		tpl[name]=t;return t
	tpl[name]=_build_tpl(name);return tpl[name]

func _build_tpl(name:String)->Dictionary:
	var pp=_path(name)
	var n:Node3D=load(pp[0]).instantiate();n.scale=Vector3.ONE*pp[1]
	var w=Node3D.new();w.add_child(n)
	var ms=_meshes(w);var tot=F.aabb(w);var hide=[]
	for k in ms.size():
		var m=ms[k];var a=F.rel_xf(m,w)*m.get_aabb()
		var low=a.end.y<tot.position.y+tot.size.y*0.03+0.35
		var flat=a.size.y<0.6 and max(a.size.x,a.size.z)>2.0
		if low and flat:m.visible=false;hide.append(k)
	var ab=F.aabb(w)
	var t={"name":name,"path":pp[0],"sc":pp[1],"fixed":pp[2],"ab":ab,"hide":hide,"var":{}}
	t.roof=_roof_mesh(w,ab)
	w.free()
	return t

# Material-Variante: Tönung (Farbe) + Schmutz; immer beidseitig
func _variant(t:Dictionary,v:int,dirt:float)->Array:
	v=v%3;dirt=0.2 if dirt<0.35 else (0.5 if dirt<0.7 else 0.9)
	var key=str(v)+"_"+str(dirt)
	if t.var.has(key):return t.var[key]
	var tints=[Color(1,1,1),Color(1.0,0.93,0.84),Color(0.86,0.9,0.95),Color(0.95,0.88,0.86),Color(0.9,0.93,0.86)]
	var tint=tints[v%tints.size()]
	var grime=Color(0.78,0.72,0.62).lerp(Color(1,1,1),1.0-dirt)
	var n:Node3D=load(t.path).instantiate();var ms=_meshes(n);var out=[]
	var cache={}
	for k in ms.size():
		var m=ms[k]
		for si in m.mesh.get_surface_count():
			var mt=m.get_active_material(si)
			if not (mt is BaseMaterial3D):continue
			var d
			if cache.has(mt):d=cache[mt]
			else:
				d=mt.duplicate();d.cull_mode=BaseMaterial3D.CULL_DISABLED
				var c=mt.albedo_color;d.albedo_color=Color(c.r*tint.r*grime.r,c.g*tint.g*grime.g,c.b*tint.b*grime.b,c.a)
				if mt.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:d.roughness=min(1.0,mt.roughness+dirt*0.2)
				cache[mt]=d
			out.append([k,si,d])
	n.free()
	t.var[key]=out;return out

func instance(t:Dictionary,v:int,dirt:float)->Node3D:
	var n:Node3D=load(t.path).instantiate();n.scale=Vector3.ONE*t.sc
	var ms=_meshes(n)
	for k in t.hide:ms[k].visible=false
	for o in _variant(t,v,dirt):ms[o[0]].set_surface_override_material(o[1],o[2])
	var c=t.ab.get_center()
	n.position=Vector3(-c.x,-t.ab.position.y,-c.z)
	var w=Node3D.new();w.add_child(n)
	if t.roof!=null:
		var rm=MeshInstance3D.new();rm.mesh=t.roof;rm.material_override=roof_mat();w.add_child(rm);rm.position=n.position
	return w

# Hohle Modelle (ohne Dach, nur für Straßenansicht gebaut) bekommen ein Flachdach:
# Draufsicht-Höhenraster (1 m) aus allen Dreiecken, Flutfüllung von außen über niedrige Zellen;
# was nicht erreicht wird, ist ein Innenraum ohne Decke -> Dachfläche knapp unter der Attika.
var _roof_mat:StandardMaterial3D
func _roof_mesh(w:Node3D,ab:AABB)->Mesh:
	var cs=1.0
	var nx=int(ceil(ab.size.x/cs))+2;var nz=int(ceil(ab.size.z/cs))+2
	if nx*nz>40000:return null
	var x0=ab.position.x-cs;var z0=ab.position.z-cs;var y0=ab.position.y;var H=ab.size.y
	var hm=PackedFloat32Array();hm.resize(nx*nz);hm.fill(-1e9)
	for m in _meshes(w):
		if not m.visible:continue
		var xf=F.rel_xf(m,w)
		for si in m.mesh.get_surface_count():
			var arr=m.mesh.surface_get_arrays(si);var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX];var I=arr[Mesh.ARRAY_INDEX]
			var cnt=I.size() if I!=null and I.size()>0 else V.size()
			var t=0
			while t+2<cnt:
				var a=xf*V[I[t] if I!=null and I.size()>0 else t];var b=xf*V[I[t+1] if I!=null and I.size()>0 else t+1];var c=xf*V[I[t+2] if I!=null and I.size()>0 else t+2]
				t+=3
				for e in [[a,b],[b,c],[c,a]]:
					var p=e[0];var q=e[1];var L=Vector2(q.x-p.x,q.z-p.z).length();var steps=int(L/(cs*0.5))+1
					for k in steps+1:
						var r=p.lerp(q,float(k)/steps)
						var ix=int((r.x-x0)/cs);var iz=int((r.z-z0)/cs)
						if ix>=0 and iz>=0 and ix<nx and iz<nz:hm[iz*nx+ix]=max(hm[iz*nx+ix],max(p.y,q.y))
	# Flutfüllung von außen über niedrige Zellen
	var occv=[]
	for v in hm:
		if v>-1e8:occv.append(v)
	if occv.size()<10:return null
	occv.sort()
	var low=occv[int(occv.size()*0.9)]-1.6
	var seen=PackedByteArray();seen.resize(nx*nz)
	var stack=[]
	for ix in nx:stack.append(Vector2i(ix,0));stack.append(Vector2i(ix,nz-1))
	for iz in nz:stack.append(Vector2i(0,iz));stack.append(Vector2i(nx-1,iz))
	while stack.size()>0:
		var c=stack.pop_back()
		if c.x<0 or c.y<0 or c.x>=nx or c.y>=nz:continue
		var k=c.y*nx+c.x
		if seen[k]==1 or hm[k]>low:continue
		seen[k]=1
		stack.append(c+Vector2i(1,0));stack.append(c+Vector2i(-1,0));stack.append(c+Vector2i(0,1));stack.append(c+Vector2i(0,-1))
	var inner=[];var walls=[]
	for iz in nz:
		for ix in nx:
			var k=iz*nx+ix
			if seen[k]==0 and hm[k]<=low:inner.append(Vector2i(ix,iz))
	if inner.size()<12:return null
	# Dachhöhe = Median der angrenzenden Wandoberkanten
	for c in inner:
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var q=c+d
			if q.x>=0 and q.y>=0 and q.x<nx and q.y<nz and hm[q.y*nx+q.x]>low:walls.append(hm[q.y*nx+q.x])
	if walls.is_empty():return null
	walls.sort();var ry=walls[walls.size()/2]-0.6
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3.UP)
	for c in inner:
		var ax=x0+c.x*cs-0.05;var az=z0+c.y*cs-0.05;var bx=ax+cs+0.1;var bz=az+cs+0.1
		var A=Vector3(ax,ry,az);var Bv=Vector3(bx,ry,az);var C=Vector3(bx,ry,bz);var Dv=Vector3(ax,ry,bz)
		for v in [A,Bv,C,A,C,Dv]:st.set_uv(Vector2(v.x,v.z)*0.25);st.add_vertex(v)
	return st.commit()
func roof_mat()->StandardMaterial3D:
	if _roof_mat==null:
		_roof_mat=load("res://scripts/mats.gd").pbr("concrete",0.3,Color(0.42,0.41,0.4)).duplicate();_roof_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return _roof_mat

func district(p:Vector2):
	for d in DIST:
		if p.distance_to(d.c)<d.r and p.y>d.get("zmin",-1e9):return d
	return null

func _pick(d:Dictionary)->String:
	var tot=0
	for e in d.list:tot+=e[1]
	var x=rng.randi()%tot
	for e in d.list:
		x-=e[1]
		if x<0:return e[0]
	return d.list[0][0]

# Häuser entlang aller Stadtstraßen
func place_along():
	for r in S.roads:
		if not r.typ in ["allee","strasse","gasse"]:continue
		var L=S.length(r)
		for side in [1,-1]:
			var s=10.0+rng.randf()*6.0
			while s<L-10.0:
				var at=S.at(r,s);var p:Vector2=at[0];var h:float=at[1];var tt:Vector2=at[2]
				var i:int=at[3]
				if r.tunnel_flags[i] or r.elev[i]:s+=8;continue
				var d=district(p)
				if d==null:s+=15.0;continue
				if d.n in BLOCK_VIERTEL:s+=15.0;continue   # dort baut welt_bloecke.gd geschlossene Blöcke
				var ok=false
				for attempt in 3:
					var name=_pick(d);var t=get_tpl(name)
					var k=0 if t.fixed else rng.randi()%4
					var sx=t.ab.size.x;var sz=t.ab.size.z
					if k%2==1:var tmp=sx;sx=sz;sz=tmp
					var nn=Vector2(-tt.y,tt.x)*side
					var setback=r.w+r.sw+1.3
					if d.n=="vorort" or (name=="stash"):setback+=rng.randf_range(4.0,9.0)   # Vorgarten
					var c=p+nn*(setback+sz*0.5)+tt*(sx*0.5)
					if not rect_free(c,tt,sx*0.5+0.3,sz*0.5+0.3):continue
					# Gelände unter dem Haus prüfen
					var base=h+0.14;var bad=false
					for cx in [-1,1]:
						for cz in [-1,1]:
							var q=c+tt*sx*0.5*cx+nn*sz*0.5*cz;var gh=G.base_height(q.x,q.y)
							if gh<1.5 or gh>base+14.0 or gh<base-14.0:bad=true
					if bad:continue
					rect_mark(c,tt,sx*0.5+0.4,sz*0.5+0.4)
					var dir=-nn   # Hausfront zeigt zur Straße
					var yaw=atan2(dir.x,dir.y)+k*PI*0.5
					placed.append({"t":name,"v":rng.randi()%5,"dirt":d.dirt*rng.randf_range(0.6,1.1),"c":c,"y":base,"yaw":yaw,"d":d.n})
					G.flatten(c,base,sqrt(sx*sx+sz*sz)*0.5+1.5,10.0)
					s+=sx+rng.randf_range(d.gap[0],d.gap[1]);ok=true;break
				if not ok:s+=5.0

func build(parent:Node3D):
	var root=Node3D.new();root.name="Gebaeude";parent.add_child(root)
	fundamente(root)
	for i in placed.size():einzeln(root,i)
	print("WELT Gebäude: ",placed.size()," Vorlagen ",tpl.size())

# Für Kartenbilder: jedes Haus als Klotz in echter Größe (spart den Speicher der echten Modelle)
func kloetze(root:Node3D):
	var Batch=load("res://scripts/batch.gd");var fb=Batch.new();var Mats=load("res://scripts/mats.gd")
	var cols=[Mats.flat(Color(0.62,0.6,0.57),0.8),Mats.flat(Color(0.52,0.5,0.48),0.8),Mats.flat(Color(0.7,0.66,0.6),0.8),Mats.flat(Color(0.45,0.42,0.4),0.8),Mats.flat(Color(0.6,0.42,0.35),0.8)]
	for k in placed.size():
		var pl=placed[k];var t=get_tpl(pl.t);var hx=t.ab.size.x*0.49;var hz=t.ab.size.z*0.49
		var xf=Transform3D(Basis(Vector3.UP,pl.yaw),Vector3(pl.c.x,pl.y,pl.c.y))
		fb.box(cols[k%cols.size()],Vector3(-hx,-4.0,-hz),Vector3(hx,t.ab.size.y,hz),xf)
	fb.commit(root)

# Fundamentsockel unter allen Häusern (verhindert sichtbare Spalten an Hängen) – ein Mesh
func fundamente(root:Node3D):
	var fm=load("res://scripts/mats.gd").pbr("concrete",0.4,Color(0.5,0.48,0.45))
	var kacheln={}
	for pl in placed:
		var k=Vector2i(floor(pl.c.x/400.0),floor(pl.c.y/400.0))
		if not kacheln.has(k):kacheln[k]=SurfaceTool.new();kacheln[k].begin(Mesh.PRIMITIVE_TRIANGLES)
		var xf=Transform3D(Basis(Vector3.UP,pl.yaw),Vector3(pl.c.x,pl.y,pl.c.y))
		var poly=grundriss(pl.t)
		var st:SurfaceTool=kacheln[k]
		var n=poly.size()
		for i in n:
			var a=poly[i];var b=poly[(i+1)%n]
			var q=[Vector3(a.x,-4.0,a.y),Vector3(b.x,-4.0,b.y),Vector3(b.x,0.02,b.y),Vector3(a.x,0.02,a.y)]
			var nv=xf.basis*Vector3(b.y-a.y,0,a.x-b.x).normalized()
			for j in [0,1,2,0,2,3]:st.set_normal(nv);st.set_uv(Vector2(q[j].x+q[j].z,q[j].y)*0.25);st.add_vertex(xf*q[j])
		for j in Geometry2D.triangulate_polygon(poly):
			st.set_normal(Vector3.UP);st.set_uv(poly[j]*0.25);st.add_vertex(xf*Vector3(poly[j].x,0.02,poly[j].y))
	var f=Node3D.new();f.name="Fundamente";root.add_child(f)
	for k in kacheln:
		var mi=MeshInstance3D.new();mi.mesh=kacheln[k].commit();mi.material_override=fm;f.add_child(mi)
		mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mi.visibility_range_end=600.0 if spiel else 2400.0

# Grundriss eines Gebäudes (vorbereitet von tools/gebaeude_bake.gd), sonst das Rechteck der Vorlage
var _grundrisse=null
func grundriss(name:String)->PackedVector2Array:
	if _grundrisse==null:
		_grundrisse={}
		var txt=FileAccess.get_file_as_string("res://assets/cache/geb/grundrisse.json")
		if txt!="":_grundrisse=JSON.parse_string(txt)
	if _grundrisse.has(name) and _grundrisse[name].p.size()>=3:
		var out=PackedVector2Array()
		for v in _grundrisse[name].p:out.append(Vector2(v[0],v[1]))
		var innen=Geometry2D.offset_polygon(out,-0.15)
		return innen[0] if innen.size()>0 else out
	var t=get_tpl(name);var hx=t.ab.size.x*0.49;var hz=t.ab.size.z*0.49
	return PackedVector2Array([Vector2(-hx,-hz),Vector2(hx,-hz),Vector2(hx,hz),Vector2(-hx,hz)])

# ein Haus aufstellen (auch zum Nachladen im Spiel)
func einzeln(root:Node3D,i:int)->Node3D:
	var pl=placed[i];var t=get_tpl(pl.t)
	var w=instance(t,int(pl.v),float(pl.dirt));root.add_child(w)
	w.position=Vector3(pl.c.x,pl.y-0.12,pl.c.y);w.rotation.y=pl.yaw
	var h=t.ab.size.y
	for m in _meshes(w):
		if spiel:m.visibility_range_end=1100.0 if h>40 else 480.0
		else:m.visibility_range_end=3200.0 if h>40 else 2400.0
	return w
