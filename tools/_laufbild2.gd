extends SceneTree
func _init():
	await process_frame
	var PE=load("res://scripts/people.gd")
	var w=Node3D.new();root.add_child(w)
	load("res://scripts/env.gd").make(w,"day")
	var base=OS.get_cmdline_user_args()[0]
	var r=RandomNumberGenerator.new();r.seed=3
	for i in 4:
		var p=PE.make(base,r);w.add_child(p);p.position=Vector3(i*1.0-1.5,0,0);p.rotation.y=PI*0.5
		var ap:AnimationPlayer=p.get_meta("anim");ap.play("run");ap.seek(i/4.0*ap.current_animation_length,true);ap.speed_scale=0.0
	var cam=Camera3D.new();w.add_child(cam);cam.position=Vector3(0,1.2,3.6);cam.look_at(Vector3(0,1.0,0))
	for k in 10:await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/lauf_"+base+".png")
	quit()
