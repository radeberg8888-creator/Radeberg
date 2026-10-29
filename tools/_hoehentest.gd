extends SceneTree
func _init():
	await process_frame
	var W=load("res://scripts/welt.gd").new();W.spiel=true;W.args=["nolife"];root.add_child(W)
	await W.generate(func(a,b):pass)
	var G=W.G
	for p in [Vector2(-211,570),Vector2(-250,560),Vector2(0,0),Vector2(250,-350),Vector2(-1000,500),Vector2(500,1500),Vector2(2700,600)]:
		print("H ",p," nat=",G._nat(p.x,p.y)," base=",G.base_height(p.x,p.y)," h_at=",G.h_at(p.x,p.y))
	var unter=0;var gesamt=0
	for x in range(-2400,3200,50):
		for z in range(-1500,1900,50):
			if G._nat(x,z)>1.0:
				gesamt+=1
				if G.h_at(x,z)<0.3:unter+=1
	print("UNTER WASSER in der Stadt: ",unter," von ",gesamt)
	quit()
