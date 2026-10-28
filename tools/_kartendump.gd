extends SceneTree
# Daten für die 2D-Karte: Straßen (mit Breite, Brücke/Tunnel), Häuser-Grundrisse, Läden
func _init():
	await process_frame
	var W=load("res://scripts/welt.gd").new();W.spiel=true;root.add_child(W)
	W.G=W.GEL.new();W.S=W.STR.new(W.G)
	W.layout();W.G.build_heights();W.S.profiles();W.S.shape_terrain()
	W.B=W.BAU.new(W.G,W.S);W.B.spiel=true;W.B.mark_roads()
	W.A=W.ANL.new(W.G,W.S,W.B);W.A.reserve();W.B.place_along()
	var rs=[]
	for r in W.S.roads:
		var p=[];var fl=[];var hh=[];var gr=[]
		for i in range(0,r.P.size(),2):
			p.append([snappedf(r.P[i].x,0.1),snappedf(r.P[i].y,0.1)]);fl.append(2 if r.tunnel_flags[i] else (1 if r.elev[i] else 0))
			hh.append(snappedf(r.h[i],0.1));gr.append(snappedf(r.raw[i],0.1))
		rs.append({"typ":r.typ,"name":r.name,"w":r.w,"sw":r.get("sw",0.0),"p":p,"f":fl,"h":hh,"g":gr})
	var hs=[]
	for pl in W.B.placed:
		var t=W.B.get_tpl(pl.t)
		hs.append([pl.c.x,pl.c.y,pl.yaw,t.ab.size.x,t.ab.size.z,t.ab.size.y,pl.d])
	var sh=[]
	for s in W.A.shops:sh.append([s.typ,s.c.x,s.c.y])
	var f=FileAccess.open("user://kartendaten.json",FileAccess.WRITE);f.store_string(JSON.stringify({"strassen":rs,"haeuser":hs,"laeden":sh}));f.close()
	print("DUMP ok ",rs.size()," ",hs.size())
	quit()
