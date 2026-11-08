extends SceneTree
func _init():
	await process_frame
	var W=Node3D.new();root.add_child(W)
	var L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L.hoehen_an=false
	L.mat_cache=true
	var t=func(name,f):
		for c in W.get_children():c.free()
		L.welt=W;f.call();L._fertig()
		var tris=0;var mats={};var shader=0
		for c in W.get_children():
			if c is MeshInstance3D:
				var n=0
				for s in c.mesh.get_surface_count():n+=c.mesh.surface_get_array_len(s)
				tris+=n/3;mats[c.material_override]=1
				if c.material_override is ShaderMaterial:shader+=1
		print(name," Dreiecke ",tris," Materialien ",mats.size()," davon Shader ",shader)
	t.call("holzhaus",func():L.holz_ghetto=true;L._holzhaus(Vector3(0,0.15,0),8.6,Vector3(0,0,1),Color(0.6,0.6,0.5)))
	t.call("haus3",func():L._haus(Vector3(0,0.15,0),18,13,Vector3(0,0,1),{"stock":3,"laden":true}))
	var GL=load("res://scripts/comic/ghetto_lib.gd").new(L)
	t.call("garage",func():GL.garage(Vector3.ZERO,0.0))
	t.call("zaun",func():GL.holzzaun(Vector3(0,0,0),Vector3(12,0,0),1.2,Color(0.6,0.5,0.4)))
	t.call("graffiti",func():GL.graffiti(Vector3(0,1,0),Vector3(0,0,1),0.8))
	for m in [L.M.ziegel[0],L.M.putz[0],L.M.pflaster,L.M.glas[0],L.M.holz,L.M.stein,L.M.mauer]:print(m.get_class()," ",m.resource_name)
	quit()
