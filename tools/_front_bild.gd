extends SceneTree
# Vorderseite je Gebäudevorlage aus Bildern bestimmen: jede der vier Seiten orthografisch rendern, auf 48 px
# verkleinern (Ziegel-/Putzstruktur mittelt sich weg) und den Kontrast messen. Fenster, Türen, Läden ergeben
# viel Kontrast, kahle Wände kaum. Ergebnis ergänzt fronten.json (vorn, seiten).
const MAG:=Color(1,0,1)
func _init():
	await process_frame
	var vp=SubViewport.new();vp.size=Vector2i(256,256);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.transparent_bg=false
	root.add_child(vp)
	var w=Node3D.new();vp.add_child(w)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=MAG
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(1,1,1);env.environment.ambient_light_energy=1.0;w.add_child(env)
	var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;w.add_child(cam);cam.current=true
	var fr=JSON.parse_string(FileAccess.get_file_as_string("res://assets/daten/fronten.json"))
	var namen=fr.keys()
	if OS.get_cmdline_user_args().size()>0:namen=OS.get_cmdline_user_args()
	var seiten_n=["+z","-z","+x","-x"];var dirs=[Vector3(0,0,1),Vector3(0,0,-1),Vector3(1,0,0),Vector3(-1,0,0)]
	for n in namen:
		var mesh=load("res://assets/cache/geb/"+n+".res")
		var mi=MeshInstance3D.new();mi.mesh=mesh;w.add_child(mi)
		var ab=mi.get_aabb();var c=ab.get_center()
		var werte=[]
		for j in 4:
			var d:Vector3=dirs[j]
			var breite=abs(Vector3(d.z,0,d.x).dot(ab.size))
			cam.size=max(breite,ab.size.y)*1.02
			cam.position=c+d*(ab.size.length()+5.0);cam.look_at(c)
			cam.near=0.1;cam.far=ab.size.length()*3+20
			for k in 3:await process_frame
			var img:Image=vp.get_texture().get_image()
			# nur das untere Drittel bis ganze Höhe (Erdgeschoss mit Türen zählt mit), Hintergrund ignorieren
			img.resize(48,48,Image.INTERPOLATE_BILINEAR)
			var summe=0.0;var anz=0
			for y in range(1,47):
				for x in range(1,47):
					var p=img.get_pixel(x,y)
					if abs(p.r-1.0)<0.25 and p.g<0.3 and abs(p.b-1.0)<0.25:continue
					var q=img.get_pixel(x+1,y);var r=img.get_pixel(x,y+1)
					if (abs(q.r-1.0)<0.25 and q.g<0.3) or (abs(r.r-1.0)<0.25 and r.g<0.3):continue
					summe+=abs(p.get_luminance()-q.get_luminance())+abs(p.get_luminance()-r.get_luminance());anz+=1
			werte.append(summe/max(anz,1) if anz>200 else 0.0)
		mi.free()
		var k=0;for j in 4:if werte[j]>werte[k]:k=j
		var s=[]
		for j in 4:if werte[j]>=werte[k]*0.55:s.append(seiten_n[j])
		var alt=fr[n].vorn
		fr[n].vorn=seiten_n[k];fr[n].seiten=s
		print("FRONTBILD %s %s -> %s  %s  %s"%[n,alt,seiten_n[k],str(s),str(werte.map(func(x):return snapped(x,0.001)))])
	var f=FileAccess.open("res://assets/daten/fronten.json",FileAccess.WRITE);f.store_string(JSON.stringify(fr));f.close()
	quit()
