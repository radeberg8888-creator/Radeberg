extends Node3D
# Comic-Welt im Spiel: vorgebackene Szene (tools/comic_welt_bake.gd) + Daten. Bietet dem Spiel dieselbe
# Schnittstelle wie die alte Welt (G.h_at, S.roads/at/length/junctions, B.district, A.shops), damit
# Steuerung, Verkehr, Passanten, Missionen und Taxi unverändert laufen.
const DATEN:="res://assets/cache/comic/daten.bin"
const SZENE:="res://assets/cache/comic/welt.scn"
const STR=preload("res://scripts/welt_strassen.gd")
var spiel:=true
var comic:=true
var G;var S;var B;var A
var LV=null
var PARKEN:=[]   # [kind, Transform3D]
var VIERTEL:=[]  # {name, datei, rect, node, laed, ab, weg}
var SUED_RECT:=Rect2()
var BAHN:=[]      # Gleise (PackedVector3Array je Strecke)
var DIENSTE:=[]   # Polizei-, Feuer-, Taxiwachen {art,p,yaw}
var NATUR_ORTE:=[]   # Jagdhütten, Cannabisplantage, Strandvillen {art,p:[x,y,z],yaw}
var IMMO:=[]     # kaufbare Lagerhallen / Autohandel aus dem Generator  – nach Entfernung nachgeladene Stadtviertel
const LADEN_AB:=650.0
const ENTLADEN_AB:=850.0
var _vt:=0.0

static func da()->bool:return ResourceLoader.exists(SZENE) and FileAccess.file_exists(DATEN)

class CG:
	var heights:PackedFloat32Array;var nx:int;var nz:int;var X0:float;var Z0:float;var STEP:float
	func h_at(x:float,z:float)->float:
		var fx=(x-X0)/STEP;var fz=(z-Z0)/STEP
		var i=clampi(int(fx),0,nx-2);var k=clampi(int(fz),0,nz-2);var tx=clamp(fx-i,0.0,1.0);var tz=clamp(fz-k,0.0,1.0)
		var j=k*nx+i
		return lerp(lerp(heights[j],heights[j+1],tx),lerp(heights[j+nx],heights[j+nx+1],tx),tz)
	func soil(_x,_z,_h,_s)->Color:return Color(1,0,0,0)
class CB:
	var placed:=[];var ohne_dach:=false;var rect:Rect2
	func district(p:Vector2):return {"n":"stadt","dirt":0.3} if rect.has_point(p) else null
	func is_free(_p)->bool:return true
	func get_tpl(_n)->Dictionary:return {}
class CA:
	var shops:=[];var icons:=[];var villen:=[]

func aus_cache():
	puffer_setzen(self)
	# Schilder/Beschriftungen nur aus der Nähe zeichnen (jedes ist ein Zeichenaufruf)
	for l in find_children("*","Label3D",true,false):
		if l.visibility_range_end<=0.0 or l.visibility_range_end>90.0:l.visibility_range_end=90.0
	var f=FileAccess.open(DATEN,FileAccess.READ);var d=f.get_var(false);f.close()
	G=CG.new();G.heights=d.H;G.nx=d.nx;G.nz=d.nz;G.X0=d.X0;G.Z0=d.Z0;G.STEP=d.STEP
	S=STR.new(G);S.roads=d.roads;S.junctions=d.junctions
	for ri in S.roads.size():S._index(ri)   # Raster für schnelle Straßensuche (Staub, Biker, …)
	B=CB.new();B.rect=d.rect
	A=CA.new();A.shops=d.shops
	PARKEN=d.parken
	for v in d.get("viertel",[]):VIERTEL.append({"name":v.name,"datei":v.datei,"rect":v.rect,"node":null,"laed":false,"ab":v.get("ab",LADEN_AB),"weg":v.get("weg",ENTLADEN_AB),"baut":false,"weg_jetzt":false})
	BAHN=d.get("bahn",[])
	SUED_RECT=d.get("sued_rect",Rect2());IMMO=d.get("immo",[]);DIENSTE=d.get("dienste",[]);NATUR_ORTE=d.get("natur_orte",[])

# Viertel nachladen/entladen je nach Abstand der Kamera zum Viertel-Rechteck
func _rect_abst(r:Rect2,p:Vector2)->float:
	var dx=max(max(r.position.x-p.x,p.x-r.end.x),0.0);var dz=max(max(r.position.y-p.y,p.y-r.end.y),0.0)
	return sqrt(dx*dx+dz*dz)
func _process(dt:float):
	if VIERTEL.is_empty():return
	_vt-=dt
	for v in VIERTEL:
		if v.laed:
			var st=ResourceLoader.load_threaded_get_status(v.datei)
			if st==ResourceLoader.THREAD_LOAD_LOADED:
				# Szene im Hintergrund-Thread aufbauen, nur das Einhängen passiert im Hauptthread
				var ps:PackedScene=ResourceLoader.load_threaded_get(v.datei);v.laed=false;v.baut=true
				WorkerThreadPool.add_task(func():
					var n=ps.instantiate()
					_eingesetzt.call_deferred(v,n))
				break
			elif st!=ResourceLoader.THREAD_LOAD_IN_PROGRESS:v.laed=false
	if _vt>0.0:return
	_vt=0.5
	var cam=get_viewport().get_camera_3d()
	if cam==null:return
	var p=Vector2(cam.global_position.x,cam.global_position.z)
	for v in VIERTEL:
		var d=_rect_abst(v.rect,p)
		if v.node==null and not v.laed and not v.baut and d<v.ab and ResourceLoader.exists(v.datei):
			ResourceLoader.load_threaded_request(v.datei);v.laed=true
		elif v.node!=null and d>v.weg:
			v.node.queue_free();v.node=null
# Kopien-Lagen aus dem Bake (Meta "puffer") in die MultiMeshes schreiben
static func puffer_setzen(n:Node):
	for sch in n.find_children("Schranke*","Node3D",true,false):sch.add_to_group("schranke")
	for m in n.find_children("*","MultiMeshInstance3D",true,false):
		if m.has_meta("puffer") and m.multimesh:
			var b:PackedFloat32Array=m.get_meta("puffer")
			if m.multimesh.instance_count!=b.size()/12:m.multimesh.instance_count=b.size()/12
			m.multimesh.buffer=b
func _eingesetzt(v,n:Node):
	v.baut=false
	if v.node!=null or v.get("weg_jetzt",false):
		v.weg_jetzt=false;n.queue_free();return
	puffer_setzen(n)
	v.node=n;add_child(n)
# Sofort laden (Spielstart/Teleport), blockierend
func viertel_jetzt(p:Vector2):
	for v in VIERTEL:
		if v.node==null and _rect_abst(v.rect,p)<v.ab:
			if v.baut:v.weg_jetzt=true   # Hintergrund-Aufbau verwerfen, jetzt direkt
			if v.laed:
				v.node=ResourceLoader.load_threaded_get(v.datei).instantiate();v.laed=false
			else:v.node=load(v.datei).instantiate()
			puffer_setzen(v.node)
			add_child(v.node)
# Ist der Boden an dieser Stelle schon da? (Verkehr/Parker nur dann aufstellen)
var _vgitter:={}   # 300-m-Zelle -> Viertel (schnelle Abfrage)
func bereit(p:Vector2)->bool:
	if _vgitter.is_empty():
		for v in VIERTEL:
			var a=Vector2i(int(floor((v.rect.position.x-15.0)/300.0)),int(floor((v.rect.position.y-15.0)/300.0)))
			var b=Vector2i(int(floor((v.rect.end.x+15.0)/300.0)),int(floor((v.rect.end.y+15.0)/300.0)))
			for x in range(a.x,b.x+1):
				for z in range(a.y,b.y+1):
					var k=Vector2i(x,z)
					if not _vgitter.has(k):_vgitter[k]=[]
					_vgitter[k].append(v)
	for v in _vgitter.get(Vector2i(int(floor(p.x/300.0)),int(floor(p.y/300.0))),[]):
		if v.node==null and v.rect.grow(15.0).has_point(p):return false
	return true

func kollision_bauen():pass
