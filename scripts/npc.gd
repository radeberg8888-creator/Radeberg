extends Node3D
# Passanten-Verhalten: auf dem Gehweg laufen, stehen bleiben, mit anderen reden, umdrehen
const P=preload("res://scripts/people.gd")
var lane_x:=0.0;var z_min:=-100.0;var z_max:=100.0
var dir:=1.0;var speed:=1.35;var state:="walk";var timer:=0.0
var rng:=RandomNumberGenerator.new()
func setup(x:float,zmin:float,zmax:float,seed_:int,start:="walk"):
	lane_x=x;z_min=zmin;z_max=zmax;rng.seed=seed_;dir=1.0 if rng.randf()<0.5 else -1.0
	speed=rng.randf_range(1.15,1.5);_set_state(start)
func _set_state(s:String):
	state=s
	match s:
		"walk":P.play(self,"walk",rng.randf(),speed/1.35);timer=rng.randf_range(8,30)
		"run":P.play(self,"run",rng.randf());timer=rng.randf_range(3,8)
		"idle":P.play(self,"idle",rng.randf());timer=rng.randf_range(3,10)
		"talk":P.play(self,["talk","shake","idle"][rng.randi()%3],rng.randf());timer=rng.randf_range(6,20)
	rotation.y=0.0 if dir>0 else PI
func _process(d:float):
	timer-=d
	if state=="walk" or state=="run":
		var v=(speed if state=="walk" else 3.6)*dir
		position.z+=v*d;position.x=lerp(position.x,lane_x,d*0.5)
		if position.z>z_max:dir=-1.0;_set_state(state)
		elif position.z<z_min:dir=1.0;_set_state(state)
	if timer<=0:
		var r=rng.randf()
		if state=="walk":_set_state("idle" if r<0.25 else ("run" if r<0.3 else "walk"))
		elif state=="talk":pass
		else:_set_state("walk")
