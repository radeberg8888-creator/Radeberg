extends SkeletonModifier3D
# Arme per Zwei-Knochen-IK an Zielpunkte führen (Waffe halten / zielen). Läuft nach der Animation,
# Beine und Körper animieren normal weiter. Ziele in Weltkoordinaten.
const U=preload("res://scripts/anim_util.gd")
var ziel_r=null       # Vector3 oder null (rechte Hand)
var ziel_l=null       # linke Hand
var pol_r:=Vector3(0.3,-1,-0.2)   # Ellbogen-Richtung (Welt)
var pol_l:=Vector3(-0.3,-1,-0.2)
var hand_fw=null      # Vector3: Richtung, in die die Hände (Finger) zeigen sollen
var oberkoerper_pitch:=0.0   # Oberkörper nach oben/unten neigen (Zielen), rad
var gewicht_ziel:=0.0
var _w:=0.0
var B:={}             # Knochen-Indizes

func setup(sk:Skeleton3D):
	for i in sk.get_bone_count():
		var k=U.human_key(sk.get_bone_name(i))
		if k in ["RightArm","RightForeArm","RightHand","LeftArm","LeftForeArm","LeftHand","Spine1","Spine2","Spine"]:B[k]=i

func bereit()->bool:
	return B.has("RightArm") and B.has("RightForeArm") and B.has("RightHand")

func _process_modification():
	var sk:=get_skeleton()
	if sk==null or not bereit():return
	_w=move_toward(_w,gewicht_ziel,0.12)
	if _w<=0.001:return
	var inv:=sk.global_transform.affine_inverse()
	# Oberkörper neigen
	if abs(oberkoerper_pitch)>0.001 and B.has("Spine2"):
		var sp=B["Spine2"];var g=sk.get_bone_global_pose(sp)
		var right=(inv.basis*sk.global_transform.basis.x).normalized()
		var q=Quaternion(right,-oberkoerper_pitch*0.6*_w)
		sk.set_bone_global_pose(sp,Transform3D(Basis(q)*g.basis,g.origin))
	if ziel_r!=null:_zwei(sk,B["RightArm"],B["RightForeArm"],B["RightHand"],inv*ziel_r,(inv.basis*pol_r).normalized())
	if ziel_l!=null and B.has("LeftArm"):_zwei(sk,B["LeftArm"],B["LeftForeArm"],B["LeftHand"],inv*ziel_l,(inv.basis*pol_l).normalized())

func _zwei(sk:Skeleton3D,a:int,b:int,c:int,T:Vector3,pole:Vector3):
	var ga=sk.get_bone_global_pose(a);var gb=sk.get_bone_global_pose(b);var gc=sk.get_bone_global_pose(c)
	var A=ga.origin;var Bp=gb.origin;var C=gc.origin
	var l1=A.distance_to(Bp);var l2=Bp.distance_to(C)
	if l1<0.001 or l2<0.001:return
	# Ziel mit Gewicht zwischen Animation und IK
	T=C.lerp(T,_w)
	var d=clamp(A.distance_to(T),abs(l1-l2)+0.001,(l1+l2)*0.999)
	var dir=(T-A).normalized()
	var x=(l1*l1-l2*l2+d*d)/(2.0*d)
	var h=sqrt(max(l1*l1-x*x,0.0))
	var pp=(pole-dir*pole.dot(dir))
	if pp.length()<0.001:pp=Vector3.DOWN-dir*Vector3.DOWN.dot(dir)
	pp=pp.normalized()
	var E=A+dir*x+pp*h
	var Tc=A+dir*d
	# Oberarm drehen
	var q1=Quaternion((Bp-A).normalized(),(E-A).normalized())
	var na=Transform3D(Basis(q1)*ga.basis,A)
	var lb=ga.affine_inverse()*gb;var lc=gb.affine_inverse()*gc
	var nb=na*lb
	var C1=(nb*lc).origin
	var q2=Quaternion((C1-nb.origin).normalized(),(Tc-nb.origin).normalized())
	nb=Transform3D(Basis(q2)*nb.basis,nb.origin)
	var nc=nb*lc
	sk.set_bone_global_pose(a,na)
	sk.set_bone_global_pose(b,nb)
	sk.set_bone_global_pose(c,nc)
