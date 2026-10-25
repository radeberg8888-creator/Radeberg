extends SceneTree
func _init():
	var F=load("res://scripts/fit.gd")
	for d in ["vehicles/trabant","vehicles/hudson","vehicles/bugatti","vehicles/dodge","characters/biker","characters/james","characters/police","characters/daya","characters/woman","weapons/ar15","weapons/mp5","weapons/pistol_tac","weapons/m1911","props/tree","buildings/building","buildings/city","buildings/cityscene","buildings/cityscene2","buildings/nyc","buildings/neighbourhood","buildings/chicago","interiors/kitchen"]:
		var n=load("res://assets/"+d+"/"+d.get_file()+".gltf").instantiate()
		var ab=F.aabb(n);print("AB ",d," pos ",ab.position.snapped(Vector3.ONE*0.01)," size ",ab.size.snapped(Vector3.ONE*0.01))
	quit()
