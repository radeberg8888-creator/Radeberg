extends SceneTree
# Prüfbild: vorbereitetes Auto von der Seite + von oben, Räder rot markiert (Kreis) -> /home/claude/shots_godot/rad_<kind>.png
func _init():
	await process_frame
	for k in OS.get_cmdline_user_args():
		var w=Node3D.new();root.add_child(w)
		var car=load("res://assets/cache/autos/"+k+".scn").instantiate();w.add_child(car)
		var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.85,0.88,0.92)
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(0.7,0.7,0.7);w.add_child(env)
		var sun=DirectionalLight3D.new();w.add_child(sun);sun.rotation_degrees=Vector3(-50,30,0)
		var gr=MeshInstance3D.new();gr.mesh=BoxMesh.new();gr.mesh.size=Vector3(30,0.02,30);w.add_child(gr);gr.position.y=-0.01
		var gm=StandardMaterial3D.new();gm.albedo_color=Color(0.35,0.4,0.35);gr.material_override=gm
		for r in car.get_meta("raeder",[]):
			var ring=MeshInstance3D.new();var tm=TorusMesh.new();tm.inner_radius=r.r-0.012;tm.outer_radius=r.r+0.012;ring.mesh=tm;w.add_child(ring)
			ring.rotation.z=PI*0.5;ring.position=r.p+Vector3((r.breite*0.5+0.02)*(1 if r.links else -1),0,0)
			var mm=StandardMaterial3D.new();mm.albedo_color=Color(1,0,0);mm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mm.no_depth_test=true;ring.material_override=mm
		# Räder leicht drehen, um das Herauslösen zu sehen
		for c in car.get_children():
			if str(c.name).begins_with("Rad_V"):c.rotation.y=0.45
		var vp=SubViewport.new();vp.size=Vector2i(1400,700);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;w.add_child(vp)
		vp.world_3d=w.get_world_3d() if w.get_world_3d() else null
		var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=3.2;w.add_child(cam)
		var L=0.0
		for r in car.get_meta("raeder",[]):L=max(L,abs(r.p.z)*2.0+1.6)
		cam.size=max(3.2,L*0.45)
		cam.position=Vector3(-30,cam.size*0.3,0);cam.look_at(Vector3(0,cam.size*0.3,0))
		cam.current=true
		root.size=Vector2i(1400,700)
		for i in 6:await process_frame
		var img=root.get_texture().get_image()
		img.save_png("/home/claude/shots_godot/rad_"+k+".png")
		w.free()
	quit()
