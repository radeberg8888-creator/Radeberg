extends SceneTree
# Comic-Autos als fahrbare Vorlagen (assets/cache/autos/c_*.scn): Karosserie + einzelne Räder (Rad_VL …),
# Meta "raeder" für fahrzeug.gd. Front = +Z.
const LISTE:=[
	["c_trabant_gruen","_trabant",[Color(0.62,0.72,0.22),Color(0.96,0.95,0.9)]],
	["c_trabant_blau","_trabant",[Color(0.45,0.72,0.86),Color(0.96,0.95,0.9)]],
	["c_trabant_beige","_trabant",[Color(0.9,0.85,0.7),Color(0.9,0.85,0.7)]],
	["c_trabant_rot","_trabant",[Color(0.75,0.25,0.2),Color(0.96,0.95,0.9)]],
	["c_wartburg_beige","_wartburg",[Color(0.86,0.78,0.52)]],
	["c_wartburg_blau","_wartburg",[Color(0.35,0.45,0.6)]],
	["c_wartburg_gruen","_wartburg",[Color(0.55,0.65,0.5)]],
	["c_taxi","_taxi",[]],
	["c_polizei","_polizei",[]],
	["c_rtw","_rtw",[]],
	["c_feuerwehr","_feuerwehr",[]],
	["c_sport_rot","_sport",[Color(0.95,0.18,0.12)]],
	["c_sport_gelb","_sport",[Color(0.98,0.75,0.12)]],
	["c_sport_schwarz","_sport",[Color(0.16,0.16,0.19)]],
]
func _owner(n:Node,o:Node):
	for c in n.get_children():c.owner=o;_owner(c,o)
func _init():
	await process_frame
	var lib=load("res://scripts/comic/stadt_lib.gd").new()
	var d=Node3D.new();root.add_child(d);lib.init_lib(d)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/cache/autos/"))
	var nur=OS.get_cmdline_user_args()
	for e in LISTE:
		if nur.size()>0 and not e[0] in nur:continue
		var car=Node3D.new();car.name=e[0];root.add_child(car)
		lib.welt=car;lib.st={};lib.mats={};lib.zaehler={};lib.rad_capture=true;lib.RAEDER=[]
		lib.callv(e[1],[Transform3D.IDENTITY]+e[2])
		lib._fertig()
		car.set_meta("raeder",lib.RAEDER.duplicate(true));car.set_meta("front",1.0)
		_owner(car,car)
		var ps=PackedScene.new();ps.pack(car)
		var err=ResourceSaver.save(ps,"res://assets/cache/autos/"+e[0]+".scn",ResourceSaver.FLAG_COMPRESS)
		print("AUTO ",e[0]," räder ",lib.RAEDER.size()," ",error_string(err))
		car.queue_free()
	quit()
