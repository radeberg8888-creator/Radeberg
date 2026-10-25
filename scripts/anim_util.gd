extends Node
# Überträgt Mixamo-Animationen auf andere Figuren (gleiche Knochennamen, mit/ohne "mixamorig"-Präfix)
static func find_skel(n:Node)->Skeleton3D:
	var best:Skeleton3D=null
	for s in n.find_children("*","Skeleton3D",true,false):
		if best==null or s.get_bone_count()>best.get_bone_count():best=s
	return best
static func bone_key(s:String)->String:
	return s.replace("mixamorig:","").replace("mixamorig_","").replace("mixamorig","")
static func retarget(src_anim:Animation,src_skel:Skeleton3D,dst_skel:Skeleton3D,dst_root:Node,in_place:=true)->Animation:
	var a=Animation.new();a.length=src_anim.length;a.loop_mode=Animation.LOOP_LINEAR
	var dpath=str(dst_root.get_path_to(dst_skel))
	var dmap={}
	for i in dst_skel.get_bone_count():dmap[bone_key(dst_skel.get_bone_name(i))]=i
	var smap={}
	for i in src_skel.get_bone_count():smap[bone_key(src_skel.get_bone_name(i))]=i
	var hips_s=src_skel.get_bone_rest(smap.get("Hips",0)).origin.y;var hips_d=dst_skel.get_bone_rest(dmap.get("Hips",0)).origin.y
	var sc=hips_d/hips_s if abs(hips_s)>0.0001 else 1.0
	for t in src_anim.get_track_count():
		var p=str(src_anim.track_get_path(t));var parts=p.split(":");if parts.size()<2:continue
		var key=bone_key(parts[parts.size()-1]);if not dmap.has(key) or not smap.has(key):continue
		var di=dmap[key];var si=smap[key];var ty=src_anim.track_get_type(t)
		if ty==Animation.TYPE_ROTATION_3D:
			var nt=a.add_track(Animation.TYPE_ROTATION_3D);a.track_set_path(nt,dpath+":"+dst_skel.get_bone_name(di))
			var rs=src_skel.get_bone_rest(si).basis.get_rotation_quaternion();var rd=dst_skel.get_bone_rest(di).basis.get_rotation_quaternion()
			for k in src_anim.track_get_key_count(t):
				var q:Quaternion=src_anim.track_get_key_value(t,k)
				a.rotation_track_insert_key(nt,src_anim.track_get_key_time(t,k),rd*(rs.inverse()*q))
		elif ty==Animation.TYPE_POSITION_3D and key=="Hips" and false:
			var nt=a.add_track(Animation.TYPE_POSITION_3D);a.track_set_path(nt,dpath+":"+dst_skel.get_bone_name(di))
			var r0=src_skel.get_bone_rest(si).origin
			for k in src_anim.track_get_key_count(t):
				var v:Vector3=src_anim.track_get_key_value(t,k)
				if in_place:v=Vector3(r0.x,v.y,r0.z)
				a.position_track_insert_key(nt,src_anim.track_get_key_time(t,k),v*sc)
	return a
static func play(char_root:Node3D,anim:Animation,name:="walk",offset:=0.0)->AnimationPlayer:
	var ap=AnimationPlayer.new();char_root.add_child(ap);ap.root_node=ap.get_path_to(char_root)
	var lib=AnimationLibrary.new();lib.add_animation(name,anim);ap.add_animation_library("",lib);ap.play(name);ap.seek(offset,true);return ap

# ---- Retargeting im Weltraum: funktioniert auch zwischen verschiedenen Skeletten (Mixamo, Character Creator, ...)
const CC_MAP={"Hip":"Hips","Waist":"Spine","Spine01":"Spine1","Spine02":"Spine2","NeckTwist01":"Neck","Head":"Head",
	"L_Clavicle":"LeftShoulder","L_Upperarm":"LeftArm","L_Forearm":"LeftForeArm","L_Hand":"LeftHand","L_Thigh":"LeftUpLeg","L_Calf":"LeftLeg","L_Foot":"LeftFoot","L_ToeBase":"LeftToeBase",
	"R_Clavicle":"RightShoulder","R_Upperarm":"RightArm","R_Forearm":"RightForeArm","R_Hand":"RightHand","R_Thigh":"RightUpLeg","R_Calf":"RightLeg","R_Foot":"RightFoot","R_ToeBase":"RightToeBase"}
const CORE=["Hips","Spine","Spine1","Spine2","Neck","Head","LeftShoulder","LeftArm","LeftForeArm","LeftHand","RightShoulder","RightArm","RightForeArm","RightHand","LeftUpLeg","LeftLeg","LeftFoot","LeftToeBase","RightUpLeg","RightLeg","RightFoot","RightToeBase"]
static func human_key(s:String)->String:
	var k=s.replace("mixamorig:","").replace("mixamorig_","").replace("mixamorig","")
	var re=RegEx.create_from_string("_\\d+$");k=re.sub(k,"")
	if k.begins_with("CC_Base_"):k=CC_MAP.get(k.substr(8),"")
	return k
static func _skel_rot(skel:Skeleton3D,root:Node)->Quaternion:
	var t=Transform3D.IDENTITY;var c:Node=skel
	while c!=null and c!=root:
		if c is Node3D:t=c.transform*t
		c=c.get_parent()
	return t.basis.orthonormalized().get_rotation_quaternion()
static func _grest(skel:Skeleton3D)->Array:
	var g=[];g.resize(skel.get_bone_count())
	for i in skel.get_bone_count():
		var q=skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion();var p=skel.get_bone_parent(i)
		g[i]=q if p<0 else null
	var done=false
	while not done:
		done=true
		for i in skel.get_bone_count():
			if g[i]!=null:continue
			var p=skel.get_bone_parent(i)
			if g[p]==null:done=false;continue
			g[i]=g[p]*skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
	return g
static func retarget_world(src_anim:Animation,src_skel:Skeleton3D,src_root:Node,dst_skel:Skeleton3D,dst_root:Node,fps:=30.0)->Animation:
	var smap={};for i in src_skel.get_bone_count():
		var k=human_key(src_skel.get_bone_name(i));if k!="" and not smap.has(k):smap[k]=i
	var dmap={};for i in dst_skel.get_bone_count():
		var k=human_key(dst_skel.get_bone_name(i));if k in CORE and not dmap.has(k):dmap[k]=i
	var strack={}
	for t in src_anim.get_track_count():
		if src_anim.track_get_type(t)!=Animation.TYPE_ROTATION_3D:continue
		var p=str(src_anim.track_get_path(t)).split(":");var bn=p[p.size()-1]
		var bi=src_skel.find_bone(bn);if bi>=0:strack[bi]=t
	var sgr=_grest(src_skel);var dgr=_grest(dst_skel)
	var cs=_skel_rot(src_skel,src_root);var cd=_skel_rot(dst_skel,dst_root)
	# Ausrichtung der Ruhepose (T-Pose / A-Pose / hängende Arme) angleichen
	var PAIRS={"Hips":"Spine","Spine":"Spine1","Spine1":"Spine2","Spine2":"Neck","Neck":"Head","LeftShoulder":"LeftArm","LeftArm":"LeftForeArm","LeftForeArm":"LeftHand","RightShoulder":"RightArm","RightArm":"RightForeArm","RightForeArm":"RightHand","LeftUpLeg":"LeftLeg","LeftLeg":"LeftFoot","LeftFoot":"LeftToeBase","RightUpLeg":"RightLeg","RightLeg":"RightFoot","RightFoot":"RightToeBase"}
	var INHERIT={"LeftHand":"LeftForeArm","RightHand":"RightForeArm","Head":"Neck","LeftToeBase":"LeftFoot","RightToeBase":"RightFoot"}
	var sgp=[];for i in src_skel.get_bone_count():sgp.append(src_skel.get_bone_global_rest(i).origin)
	var dgp=[];for i in dst_skel.get_bone_count():dgp.append(dst_skel.get_bone_global_rest(i).origin)
	var align={}
	for k in PAIRS:
		var c=PAIRS[k]
		if dmap.has(k) and dmap.has(c) and smap.has(k) and smap.has(c):
			var vs:Vector3=cs*(sgp[smap[c]]-sgp[smap[k]]);var vd:Vector3=cd*(dgp[dmap[c]]-dgp[dmap[k]])
			if vs.length()>1e-6 and vd.length()>1e-6:align[k]=Quaternion(vd.normalized(),vs.normalized())
	for k in INHERIT:if align.has(INHERIT[k]):align[k]=align[INHERIT[k]]
	# Nur Arme angleichen (T-Pose/A-Pose/hängend); Rumpf und Beine direkt übertragen -> natürliche Haltung
	for k in ["Hips","Spine","Spine1","Spine2","Neck","Head"]:align.erase(k)
	if true:
		for k in ["LeftUpLeg","LeftLeg","LeftFoot","LeftToeBase","RightUpLeg","RightLeg","RightFoot","RightToeBase"]:align.erase(k)
	if OS.has_environment("RT_DEBUG"):
		for k in align:print("  align ",k," ",rad_to_deg(align[k].get_angle())," ",(cs*(sgp[smap[k]])) if smap.has(k) else ""," d ",cd*dgp[dmap[k]])
	var a=Animation.new();a.length=src_anim.length;a.loop_mode=Animation.LOOP_LINEAR
	var dpath=str(dst_root.get_path_to(dst_skel))
	var tracks={}
	for k in dmap:if smap.has(k):
		var nt=a.add_track(Animation.TYPE_ROTATION_3D);a.track_set_path(nt,dpath+":"+dst_skel.get_bone_name(dmap[k]));tracks[dmap[k]]=nt
	# Reihenfolge der Zielknochen: Eltern zuerst
	var order=[];var seen={}
	var visit=func(f,i):
		if seen.has(i):return
		var p=dst_skel.get_bone_parent(i);if p>=0:f.call(f,p)
		seen[i]=true;order.append(i)
	for i in dst_skel.get_bone_count():visit.call(visit,i)
	var n=int(ceil(src_anim.length*fps))+1
	var dmap_inv={};for k in dmap:dmap_inv[dmap[k]]=k
	for f in n:
		var time=min(f/fps,src_anim.length)
		# Quelle: globale Posen
		var sg=[];sg.resize(src_skel.get_bone_count())
		for i in src_skel.get_bone_count():
			var lq:Quaternion=src_anim.rotation_track_interpolate(strack[i],time) if strack.has(i) else src_skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
			var p=src_skel.get_bone_parent(i)
			sg[i]=lq if p<0 else null
			if p>=0:sg[i]=[p,lq]
		var resolved=[];resolved.resize(sg.size())
		var res=func(g,i):
			if resolved[i]!=null:return resolved[i]
			var v=sg[i];var r:Quaternion
			if v is Quaternion:r=v
			else:r=g.call(g,v[0])*v[1]
			resolved[i]=r;return r
		var dg={}
		for i in order:
			var p=dst_skel.get_bone_parent(i);var key=dmap_inv.get(i,"")
			var g:Quaternion
			if key!="" and smap.has(key):
				var si=smap[key]
				var delta=res.call(res,si)*sgr[si].inverse()
				var dc=cs*delta*cs.inverse()
				var dd=cd.inverse()*dc*align.get(key,Quaternion())*cd
				g=dd*dgr[i]
			else:
				g=(dg[p] if p>=0 else Quaternion())*dst_skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion() if p>=0 else dst_skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
			dg[i]=g
			if tracks.has(i):
				var local=(dg[p].inverse()*g) if p>=0 else g
				a.rotation_track_insert_key(tracks[i],time,local.normalized())
	return a
