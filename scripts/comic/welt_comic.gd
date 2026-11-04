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

func kollision_bauen():pass
