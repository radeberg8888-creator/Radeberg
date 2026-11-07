extends RefCounted
# Alle Comic-Fahrzeuge: Name -> [Baufunktion in stadt_lib, Lackfarbe(n), tunbar (optisch), Motorklang]
# Neues Auto = neue Zeile hier; Motorklang ist eine Klasse aus tools/sounds_gen.py (KLASSEN) – damit hat jedes Auto automatisch Sound.
# Wird vom Vorab-Bau (tools/comic_autos_bake.gd) und von der Tuning-Werkstatt (Neubau mit Tuning) benutzt.
const LISTE:={
	"c_trabant_gruen":["_trabant",[Color(0.62,0.72,0.22),Color(0.96,0.95,0.9)],true,"trabant"],
	"c_trabant_blau":["_trabant",[Color(0.45,0.72,0.86),Color(0.96,0.95,0.9)],true,"trabant"],
	"c_trabant_beige":["_trabant",[Color(0.9,0.85,0.7),Color(0.9,0.85,0.7)],true,"trabant"],
	"c_trabant_rot":["_trabant",[Color(0.75,0.25,0.2),Color(0.96,0.95,0.9)],true,"trabant"],
	"c_wartburg_beige":["_wartburg",[Color(0.86,0.78,0.52)],false,"wartburg"],
	"c_wartburg_blau":["_wartburg",[Color(0.35,0.45,0.6)],false,"wartburg"],
	"c_wartburg_gruen":["_wartburg",[Color(0.55,0.65,0.5)],false,"wartburg"],
	"c_taxi":["_taxi",[],false,"vier"],
	"c_polizei":["_polizei",[],false,"vier"],
	"c_rtw":["_rtw",[],false,"diesel"],
	"c_feuerwehr":["_feuerwehr",[],false,"diesel"],
	"c_sport_rot":["_sport",[Color(0.95,0.18,0.12)],false,"v8"],
	"c_sport_gelb":["_sport",[Color(0.98,0.75,0.12)],false,"v8"],
	"c_sport_schwarz":["_sport",[Color(0.16,0.16,0.19)],false,"v8"],
	"c_jdm_weiss":["_jdm",[Color(0.88,0.89,0.9)],true,"turbo6"],
	"c_jdm_blau":["_jdm",[Color(0.15,0.35,0.85)],true,"turbo6"],
	"c_jdm_rot":["_jdm",[Color(0.8,0.12,0.12)],true,"turbo6"],
	"c_kompakt_rot":["_kompakt",[Color(0.85,0.2,0.18)],true,"kompakt4"],
	"c_kompakt_weiss":["_kompakt",[Color(0.94,0.94,0.94)],true,"kompakt4"],
	"c_kompakt_schwarz":["_kompakt",[Color(0.12,0.12,0.14)],true,"kompakt4"],
	"c_e30_gruen":["_e30",[Color(0.3,0.45,0.32)],true,"reihe6"],
	"c_e30_silber":["_e30",[Color(0.72,0.74,0.77)],true,"reihe6"],
	"c_e30_schwarz":["_e30",[Color(0.12,0.12,0.14)],true,"reihe6"],
	"c_luxus_schwarz":["_luxus",[Color(0.1,0.1,0.12)],false,"v8leise"],
	"c_luxus_silber":["_luxus",[Color(0.7,0.72,0.75)],false,"v8leise"],
	"c_muscle_orange":["_muscle",[Color(0.9,0.45,0.08)],false,"v8gross"],
	"c_muscle_schwarz":["_muscle",[Color(0.12,0.12,0.14)],false,"v8gross"],
	"c_suv_grau":["_suv",[Color(0.35,0.38,0.42)],false,"v6diesel"],
	"c_suv_gruen":["_suv",[Color(0.25,0.35,0.25)],false,"v6diesel"],
}
static var _lib=null
static func lib():
	if _lib==null:
		_lib=load("res://scripts/comic/stadt_lib.gd").new();_lib.init_lib(Node3D.new())
	return _lib
static func tunbar(kind:String)->bool:return LISTE.has(kind) and LISTE[kind][2]
static func funktion(kind:String)->String:return LISTE[kind][0] if LISTE.has(kind) else ""

# Fahrzeugoptik bauen: Node3D mit Karosserie-Meshes und Rad_VL/VR/HL/HR, Meta "raeder"
static func bauen(kind:String,tu:={},farbe=null)->Node3D:
	var L=lib();var e=LISTE[kind]
	var car=Node3D.new();car.name=kind
	L.welt=car;L.st={};L.mats={};L.zaehler={};L.rad_capture=true;L.RAEDER=[];L.kachel=0.0;L.hoehen_an=false
	var args=[Transform3D.IDENTITY]+(e[1] as Array).duplicate()
	if farbe!=null and args.size()>1:args[1]=farbe
	if e[2]:
		while args.size()<2:args.append(Color.WHITE)
		args.append(tu)
	L.callv(e[0],args)
	L._fertig()
	car.set_meta("raeder",L.RAEDER.duplicate(true));car.set_meta("front",1.0)
	L.rad_capture=false
	return car
