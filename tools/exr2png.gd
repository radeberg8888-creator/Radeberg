extends SceneTree
# godot --headless --script exr2png.gd -- <in.exr> <out.png> <maxsize>
func _init():
	var a=OS.get_cmdline_user_args()
	var img=Image.load_from_file(a[0])
	var mx=int(a[2]) if a.size()>2 else 2048
	if img.get_width()>mx:img.resize(mx,int(mx*img.get_height()/float(img.get_width())),Image.INTERPOLATE_LANCZOS)
	if a[1].ends_with(".hdr") or a[1].ends_with(".exr"):img.save_exr(a[1])
	else:
		if img.get_format()>=Image.FORMAT_RF and not a[0].contains("diff"):img.convert(Image.FORMAT_RGB8)
		elif img.get_format()>=Image.FORMAT_RF:img.linear_to_srgb();img.convert(Image.FORMAT_RGB8)
		img.save_png(a[1])
	print("ok ",a[1]," ",img.get_size())
	quit()
