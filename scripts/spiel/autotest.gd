extends Node3D
# Physik-Test für Fahrzeuge (headless): ebener Boden, Gas, Lenken, Bremsen
var c;var t:=0.0
var st={"gas":0.0,"brake":0.0,"steer":0.0,"handbrake":false,"nos":false}
func _ready():
	var sb=StaticBody3D.new();add_child(sb);var cs=CollisionShape3D.new();var b=BoxShape3D.new();b.size=Vector3(2000,1,2000);cs.shape=b;sb.add_child(cs);cs.position.y=-0.5
	c=load("res://scripts/spiel/fahrzeug.gd").new();add_child(c);c.setup(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else "audi_rs7")
	c.position=Vector3(0,0.5,0);c.uebernehmen()
	print("ab ",c.ab," mass ",c.mass)
func _physics_process(dt):
	t+=dt
	st.gas=1.0 if t>1.0 and t<6.0 else 0.0
	st.steer=0.6 if t>4.0 and t<6.0 else 0.0
	st.brake=1.0 if t>6.0 and t<8.0 else 0.0
	if t>8.0 and t<10.0:st.brake=1.0  # rückwärts
	c.fahren(Steu.new(st),dt)
	if int(t*2)!=int((t-dt)*2):
		print("t=%.1f pos=%s kmh=%.1f fw=%s up=%.2f"%[t,str(c.global_position.snapped(Vector3.ONE*0.01)),c.kmh(),str(c.global_transform.basis.z.snapped(Vector3.ONE*0.01)),c.global_transform.basis.y.y])
		var ws=[]
		for w in c.wheels:ws.append("%s:%s/%.2f"%[str(w.position.snapped(Vector3.ONE*0.01)),w.is_in_contact(),w.get_rpm()])
		print("   ",ws)
	if t>10.5:get_tree().quit()
class Steu:
	var gas;var brake;var steer;var handbrake;var nos
	func _init(d):gas=d.gas;brake=d.brake;steer=d.steer;handbrake=d.handbrake;nos=d.nos
