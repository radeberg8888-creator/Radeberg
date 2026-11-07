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
var VIERTEL:=[]  # {name, datei, rect, node, laed}  – nach Entfernung nachgeladene Stadtviertel
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
	var f=FileAccess.open(DATEN,FileAccess.READ);var d=f.get_var(false);f.close()
	G=CG.new();G.heights=d.H;G.nx=d.nx;G.nz=d.nz;G.X0=d.X0;G.Z0=d.Z0;G.STEP=d.STEP
	S=STR.new(G);S.roads=d.roads;S.junctions=d.junctions
	B=CB.new();B.rect=d.rect
	A=CA.new();A.shops=d.shops
	PARKEN=d.parken
	for v in d.get("viertel",[]):VIERTEL.append({"name":v.name,"datei":v.datei,"rect":v.rect,"node":null,"laed":false})

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
				v.node=ResourceLoader.load_threaded_get(v.datei).instantiate();add_child(v.node);v.laed=false
				print("VIERTEL geladen ",v.name)
			elif st!=ResourceLoader.THREAD_LOAD_IN_PROGRESS:v.laed=false
	if _vt>0.0:return
	_vt=0.5
	var cam=get_viewport().get_camera_3d()
	if cam==null:return
	var p=Vector2(cam.global_position.x,cam.global_position.z)
	for v in VIERTEL:
		var d=_rect_abst(v.rect,p)
		if v.node==null and not v.laed and d<LADEN_AB and ResourceLoader.exists(v.datei):
			ResourceLoader.load_threaded_request(v.datei);v.laed=true
		elif v.node!=null and d>ENTLADEN_AB:
			v.node.queue_free();v.node=null;print("VIERTEL entladen ",v.name)
# Sofort laden (Spielstart/Teleport), blockierend
func viertel_jetzt(p:Vector2):
	for v in VIERTEL:
		if v.node==null and _rect_abst(v.rect,p)<LADEN_AB:
			if v.laed:
				v.node=ResourceLoader.load_threaded_get(v.datei).instantiate();v.laed=false
			else:v.node=load(v.datei).instantiate()
			add_child(v.node)
# Ist der Boden an dieser Stelle schon da? (Verkehr/Parker nur dann aufstellen)
func bereit(p:Vector2)->bool:
	for v in VIERTEL:
		if v.node==null and v.rect.grow(15.0).has_point(p):return false
	return true

func kollision_bauen():pass
