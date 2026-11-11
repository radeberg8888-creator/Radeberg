extends Node3D
# Züge auf den Gleisen der neuen Welt (daten "bahn": Liste von Polylinien mit Höhe). Ein Zug fährt eine Strecke von
# Ende zu Ende, wendet dort (an der Stadtgrenze verschwindet er kurz). Schranken (Knoten "Schranke" in den Kacheln)
# gehen zu, solange ein Zug in der Nähe ihres Übergangs ist; Blinklichter und Glocke gibt es über die Schranke.
var spiel
var strecken:=[]   # [{P:PackedVector3Array, S:PackedFloat32Array, L}]
var zuege:=[]      # {node, strecke, s, v, richtung, wagen:[Node3D]}
const WAGEN:=5
const ABST:=16.0
var _st:=0.0

func setup(sp,bahn:Array):
	spiel=sp
	for P in bahn:
		if P.size()<10:continue
		var S=PackedFloat32Array([0.0])
		for i in range(1,P.size()):S.append(S[-1]+P[i].distance_to(P[i-1]))
		if S[-1]<300.0:continue
		strecken.append({"P":P,"S":S,"L":S[-1]})
	for i in strecken.size():
		_neuer_zug(i,randf()*strecken[i].L,1 if i%2==0 else -1)

func _neuer_zug(si:int,s:float,richtung:int):
	var z={"strecke":si,"s":s,"v":17.0,"richtung":richtung,"wagen":[]}
	var farben=[Color(0.85,0.15,0.12),Color(0.12,0.35,0.7),Color(0.15,0.55,0.3)]
	for k in WAGEN:
		var w=_wagen(k==0,farben[randi()%farben.size()] if k>0 else Color(0.95,0.75,0.1))
		add_child(w);z.wagen.append(w)
	zuege.append(z)

func _box(p:Node3D,c:Vector3,s:Vector3,col:Color,koll:=false):
	var mi=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=s;mi.mesh=bm;mi.position=c
	var m=StandardMaterial3D.new();m.albedo_color=col;m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.specular_mode=BaseMaterial3D.SPECULAR_TOON;mi.material_override=m
	p.add_child(mi)
	# Kontur
	var k=MeshInstance3D.new();var kb=BoxMesh.new();kb.size=s+Vector3.ONE*0.08;k.mesh=kb;k.position=c
	var km=StandardMaterial3D.new();km.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;km.albedo_color=Color(0.07,0.05,0.06);km.cull_mode=BaseMaterial3D.CULL_FRONT;k.material_override=km
	k.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;p.add_child(k)
func _wagen(lok:bool,col:Color)->Node3D:
	var w=AnimatableBody3D.new();w.sync_to_physics=false
	var cs=CollisionShape3D.new();var bs=BoxShape3D.new();bs.size=Vector3(3.0,3.6,14.5);cs.shape=bs;cs.position=Vector3(0,2.3,0);w.add_child(cs)
	_box(w,Vector3(0,0.55,0),Vector3(2.4,0.5,14.0),Color(0.15,0.15,0.17))
	_box(w,Vector3(0,2.3,0),Vector3(2.9,3.0,14.2) if not lok else Vector3(2.9,3.0,12.0),col)
	_box(w,Vector3(0,3.9,0),Vector3(2.7,0.25,13.6) if not lok else Vector3(2.7,0.25,11.6),Color(0.35,0.35,0.38))
	var fenster=Color(0.2,0.35,0.5)
	for sd in [-1.46,1.46]:
		for k in 5:_box(w,Vector3(sd,2.75,-5.2+k*2.6),Vector3(0.05,1.0,1.6),fenster)
	if lok:
		_box(w,Vector3(0,2.0,6.4),Vector3(2.7,2.4,1.2),col)
		_box(w,Vector3(0,2.9,6.95),Vector3(2.2,0.9,0.05),fenster)
		for sd in [-0.8,0.8]:
			var l=OmniLight3D.new();l.position=Vector3(sd,1.2,7.2);l.light_color=Color(1,0.95,0.7);l.omni_range=12.0;l.light_energy=1.2;w.add_child(l)
	for zz in [-5.0,5.0]:
		for sd in [-0.75,0.75]:_box(w,Vector3(sd,0.35,zz),Vector3(0.3,0.7,1.4),Color(0.1,0.1,0.1))
	return w

func _lage(st:Dictionary,s:float)->Array:
	var S:PackedFloat32Array=st.S;var P:PackedVector3Array=st.P
	s=clamp(s,0.0,st.L)
	var i=clampi(S.bsearch(s),1,S.size()-1)
	var u=(s-S[i-1])/max(S[i]-S[i-1],0.001)
	return [P[i-1].lerp(P[i],u),(P[i]-P[i-1]).normalized()]

func schritt(dt:float):
	for z in zuege:
		var st=strecken[z.strecke]
		z.s+=z.v*dt*z.richtung
		var zug_l=WAGEN*ABST
		if z.s>st.L+zug_l+60.0 or z.s<-zug_l-60.0:
			z.richtung=-z.richtung   # an der Grenze wenden (außer Sicht)
		for k in z.wagen.size():
			var sk=z.s-z.richtung*k*ABST
			var w:Node3D=z.wagen[k]
			if sk<0.0 or sk>st.L:w.visible=false;w.position.y=-200;continue
			w.visible=true
			var e=_lage(st,sk);var t:Vector3=e[1]*z.richtung
			if sk<6.0 or sk>st.L-6.0:w.visible=false;w.position.y=-200;continue
			var a=_lage(st,sk-z.richtung*5.0)[0];var b=_lage(st,sk+z.richtung*5.0)[0]
			var d=b-a
			if d.length()<0.5:d=t
			if d.length()<0.01 or not d.is_finite():continue
			d=d.normalized()
			if abs(d.y)>0.99:continue
			w.global_transform=Transform3D(Basis.looking_at(-d,Vector3.UP),(a+b)*0.5)
	_st-=dt
	if _st<=0.0:
		_st=0.25
		_schranken()

func _schranken():
	var naehe=[]
	for z in zuege:
		for w in [z.wagen[0],z.wagen[z.wagen.size()-1]]:
			if w.visible:naehe.append(w.global_position)
	for s in get_tree().get_nodes_in_group("schranke"):
		if not is_instance_valid(s):continue
		var zu=false
		for p in naehe:
			if p.distance_to(s.global_position)<140.0:zu=true;break
		var ziel=0.0 if zu else -PI*0.47
		s.rotation.x=move_toward(s.rotation.x,ziel,0.25*1.6)
