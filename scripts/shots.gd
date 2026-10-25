extends Node
# Rendert Standbilder: godot -- --shots=<datei-präfix>
var cams:Array=[]
var idx:=0
var wait:=0
var prefix:="shot"
func setup(list:Array,pfx:String):
	cams=list;prefix=pfx
func _process(_d):
	if cams.is_empty():return
	wait+=1
	var cam:Camera3D=get_viewport().get_camera_3d()
	if wait==1:
		var c=cams[idx];cam.global_position=c[0];cam.look_at(c[1]);if c.size()>2:cam.fov=c[2]
		cam.near=4.0 if c[0].y>300.0 else 0.3
	if wait==8:
		var img=get_viewport().get_texture().get_image()
		img.save_png("/home/claude/shots_godot/%s_%d.png"%[prefix,idx])
		idx+=1;wait=0
		if idx>=cams.size():get_tree().quit()
