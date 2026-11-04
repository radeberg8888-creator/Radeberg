extends RefCounted
# Comic-Menschen im Spiel: people.gd baut Figur + Skelett + Bewegungen wie bisher, hier wird der alte Körper
# entfernt und der Comic-Körper (stadt_lib.skelett_koerper) als ein gehäutetes Mesh an dasselbe Skelett gehängt.
static var aktiv:=false
static var _lib=null
const U=preload("res://scripts/anim_util.gd")
const HAUT:=[Color(0.98,0.82,0.7),Color(0.93,0.72,0.56),Color(0.8,0.58,0.42),Color(0.6,0.4,0.28),Color(0.42,0.28,0.2)]
const HAAR:=[Color(0.06,0.05,0.05),Color(0.12,0.08,0.05),Color(0.2,0.12,0.07),Color(0.45,0.28,0.12),Color(0.85,0.65,0.3),Color(0.55,0.55,0.53)]
const OBEN:=[Color(0.93,0.42,0.18),Color(0.18,0.55,0.35),Color(0.75,0.2,0.25),Color(0.95,0.95,0.95),Color(0.3,0.5,0.8),Color(0.9,0.75,0.3),Color(0.85,0.3,0.45),Color(0.2,0.25,0.35),Color(0.12,0.12,0.13),Color(0.55,0.35,0.7)]
const UNTEN:=[Color(0.2,0.3,0.55),Color(0.18,0.18,0.2),Color(0.35,0.3,0.25),Color(0.55,0.5,0.4),Color(0.25,0.25,0.3),Color(0.3,0.25,0.5)]
const SCHUH:=[Color(0.95,0.95,0.95),Color(0.15,0.13,0.12),Color(0.6,0.15,0.2),Color(0.35,0.22,0.12)]

static func lib():
	if _lib==null:
		_lib=load("res://scripts/comic/stadt_lib.gd").new();_lib.init_lib(Node3D.new())
		_lib.SPH.radial_segments=10;_lib.SPH.rings=6   # Handy: weniger Dreiecke pro Figur
	return _lib

static func aussehen(base:String,frau:bool,rng:RandomNumberGenerator,look:Dictionary)->Dictionary:
	var o={"frau":frau,"haut":HAUT[rng.randi()%HAUT.size()],"haar":HAAR[rng.randi()%HAAR.size()],
		"oben":OBEN[rng.randi()%OBEN.size()],"unten":UNTEN[rng.randi()%UNTEN.size()],"schuh":SCHUH[rng.randi()%SCHUH.size()],
		"aermel":"lang" if rng.randf()<0.3 else "kurz","frisur":"glatze" if (not frau and rng.randf()<0.12) else "kurz","bart":not frau and rng.randf()<0.2}
	if look.get("tint") is Color and look.get("mix",1.0)>0.0:o.oben=look.tint
	if base=="police":
		o.oben=Color(0.16,0.25,0.45);o.unten=Color(0.12,0.14,0.2);o.schuh=Color(0.08,0.08,0.08);o.aermel="lang";o.schirmmuetze=Color(0.12,0.16,0.3);o.frisur="glatze";o.bart=false
	for k in ["haut","haar","oben","unten","schuh"]:
		if look.has("c_"+k):o[k]=look["c_"+k]
	return o

# p: Ergebnis von people.make
static func anziehen(p:Node3D,o:Dictionary):
	var sk:Skeleton3D=U.find_skel(p)
	if sk==null:return
	for m in p.find_children("*","MeshInstance3D",true,false):
		m.get_parent().remove_child(m);m.free()
	lib().skelett_koerper(p,sk,o)
	p.set_meta("comic",o)

static func umfaerben(p:Node3D,farben:Dictionary):
	var o:Dictionary=p.get_meta("comic",{}).duplicate()
	if o.is_empty():return
	for k in farben:o[k]=farben[k]
	var sk:Skeleton3D=U.find_skel(p)
	for nm in ["ComicKoerper","ComicKontur"]:
		var alt=sk.get_node_or_null(nm)
		if alt:sk.remove_child(alt);alt.free()
	lib().skelett_koerper(p,sk,o)
	p.set_meta("comic",o)
