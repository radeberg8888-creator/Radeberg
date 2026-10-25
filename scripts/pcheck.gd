extends Node3D
const P=preload("res://scripts/people.gd")
func _ready():
	load("res://scripts/env.gd").make(self,"day")
	var rng=RandomNumberGenerator.new();rng.seed=5
	var bases=["daya","daya","daya","joe","joe","female","biker","female"]
	for i in bases.size():
		var p=P.make(bases[i],rng);add_child(p);p.position=Vector3(i*0.9,0,0)
		P.play(p,"idle",0.3)
	var c=Camera3D.new();add_child(c)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	sh.setup([[Vector3(3.2,1.55,3.6),Vector3(3.2,1.25,0),52.0],[Vector3(0.9,1.7,1.4),Vector3(0.9,1.6,0),45.0]],"pchk")
