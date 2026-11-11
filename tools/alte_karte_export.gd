extends SceneTree
# Altes Straßennetz (vor dem Comic-Umbau) als Bauplan exportieren:
# Straßen/Gleise mit Abtastpunkten, Höhen, Breiten + Gebäudestellplätze -> JSON
const AUS:="/home/claude/work/alte_karte.json"

func _init():
	await process_frame
	var W=Node3D.new();W.set_script(load("res://scripts/welt.gd"));root.add_child(W)
	W.spiel=true
	W.G=W.GEL.new();W.S=W.STR.new(W.G)
	W.layout()
	W.G.build_heights()
	W.S.profiles()
	W.S.shape_terrain()
	var B=W.BAU.new(W.G,W.S);B.spiel=true;B.mark_roads();W.B=B
	var A=W.ANL.new(W.G,W.S,B);A.reserve();W.A=A
	B.reservieren_mitschreiben=false
	B.place_along()
	var BL=load("res://scripts/welt_bloecke.gd").new(W.G,W.S,B);BL.bauen(W)
	var roads=[]
	for r in W.S.roads:
		var P=[];var H=[]
		for p in r.P:P.append([snapped(p.x,0.1),snapped(p.y,0.1)])
		for h in r.h:H.append(snapped(h,0.01))
		roads.append({"typ":r.typ,"name":r.name,"w":r.w,"sw":r.get("sw",0.0),"closed":r.closed,"P":P,"h":H,
			"tunnel":r.get("tunnel_flags",[]).count(true),"elev":r.get("elev",[]).count(true)})
	var bau=[]
	for p in B.placed:
		bau.append({"t":p.t,"c":[snapped(p.c.x,0.1),snapped(p.c.y,0.1)],"y":snapped(p.y,0.01),"yaw":snapped(p.yaw,0.01),"d":p.d})
	var jn=[]
	for j in W.S.junctions:jn.append({"p":[j.p.x,j.p.y],"h":j.h,"r":j.r})
	var res=[]
	for r in B.reserviert:res.append({"c":[r[0].x,r[0].y],"a":[r[1].x,r[1].y],"hx":r[2],"hz":r[3]})
	var G=W.G
	var f=FileAccess.open(AUS,FileAccess.WRITE)
	f.store_string(JSON.stringify({"roads":roads,"bau":bau,"jn":jn,"res":res,"X0":G.X0,"Z0":G.Z0,"STEP":G.STEP,"nx":G.rx,"nz":G.rz}))
	f.close()
	# Höhenraster separat (binär)
	var hf=FileAccess.open("/home/claude/work/alte_hoehen.bin",FileAccess.WRITE);hf.store_buffer(PackedFloat32Array(G._nh).to_byte_array());hf.close()
	print("EXPORT Straßen ",roads.size()," Bauten ",bau.size()," Kreuzungen ",jn.size()," Raster ",G.rx,"x",G.rz)
	quit()
