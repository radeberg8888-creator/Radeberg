extends Node3D
# Vorschau: viele verschiedene Menschen aus wenigen Grundmodellen
const P=preload("res://scripts/people.gd")
func _ready():
	load("res://scripts/env.gd").make(self,"day")
	var M=preload("res://scripts/mats.gd")
	var g=MeshInstance3D.new();g.mesh=PlaneMesh.new();g.mesh.size=Vector2(200,200);add_child(g);g.material_override=M.pbr("pavers",0.45)
	var rng=RandomNumberGenerator.new();rng.seed=11
	var anims=["idle","walk","talk","idle","shake","walk","run","dance","punch"]
	var bases=P.CIVIL+["police"]
	var i=0
	for row in 3:
		for col in 8:
			var b=bases[i%bases.size()];i+=1
			var p=P.make(b,rng);add_child(p);p.position=Vector3(col*1.25-4.4+(row%2)*0.6,0,-row*2.2);p.rotation.y=rng.randf_range(-0.4,0.4)
			P.play(p,anims[(i*7+row)%anims.size()],rng.randf())
	var c=Camera3D.new();add_child(c)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	sh.setup([[Vector3(0,1.6,6.5),Vector3(0,1.0,-2),50.0],[Vector3(-2.5,1.5,2.4),Vector3(-2.5,1.2,0),45.0],[Vector3(2.5,1.5,2.4),Vector3(2.5,1.2,0),45.0]],"crowd")
