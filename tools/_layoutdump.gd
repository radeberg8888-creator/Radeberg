extends SceneTree
# Nur Layout: Straßen-Kontrollpunkte als JSON (für Planungsbild)
func _init():
	await process_frame
	var W=load("res://scripts/welt.gd").new();root.add_child(W)
	W.G=W.GEL.new();W.S=W.STR.new(W.G)
	W.layout()
	var out=[]
	for r in W.S.roads:
		var p=[];for q in r.ctrl:p.append([q.x,q.z])
		out.append({"typ":r.typ,"name":r.name,"closed":r.closed,"p":p})
	var f=FileAccess.open("user://layout.json",FileAccess.WRITE);f.store_string(JSON.stringify(out));f.close()
	var tr=[]
	for r in out:
		if r.typ=="autobahn" and r.name!="Stadtring":tr.append(r)
	var f2=FileAccess.open("res://assets/cache/autobahn_trassen.json",FileAccess.WRITE);f2.store_string(JSON.stringify(tr));f2.close()
	print("DUMP ",out.size()," ",ProjectSettings.globalize_path("user://layout.json"))
	quit()
