extends RefCounted
# Passanten: viele unterschiedlich aussehende Menschen aus wenigen Grundmodellen.
# Hautfarbe, Haarfarbe, Kleiderfarben, Größe und Statur werden pro Person zufällig gewählt (Shader, kein Extra-Speicher).
# Alle Figuren bekommen dieselben Bewegungen (Stehen, Gehen, Rennen, Reden, Schlagen, Tanzen) per Retargeting.
const F=preload("res://scripts/fit.gd")
const U=preload("res://scripts/anim_util.gd")
const C="res://assets/characters/"

# Grundmodelle: [Pfad, Variantendatei, Größe in m, Geschlecht]
const BASES={
	"police":[C+"police/police_rig.gltf",C+"police/police_rig.variants.json",1.82,"m"],
	"joe":[C+"joe/joe_rig.gltf",C+"joe/joe_rig.variants.json",1.80,"m"],
	"woman":[C+"woman/woman_rig.gltf",C+"woman/woman_rig.variants.json",1.68,"f"],
	"biker":[C+"biker/biker.gltf",C+"biker/biker.variants.json",1.84,"m"],
	"daya":[C+"daya/daya.gltf",C+"daya/daya.variants.json",1.78,"m"],
	"female":[C+"female/female.gltf",C+"female/female.variants.json",1.67,"f"],
	"aiman":[C+"aiman/aiman_rig.gltf",C+"aiman/aiman_rig.variants.json",1.70,"f"],
	"hqman":[C+"hqman/hqman.gltf",C+"hqman/hqman.variants.json",1.81,"m"],
}
# Straßenpassanten (ohne Polizei-Uniform)
const CIVIL=["joe","biker","daya","female","hqman"]

const SKIN=[Color(0.88,0.72,0.61),Color(0.84,0.66,0.54),Color(0.82,0.62,0.48),Color(0.72,0.52,0.37),Color(0.58,0.39,0.26),Color(0.44,0.28,0.18),Color(0.33,0.2,0.13),Color(0.23,0.14,0.09),Color(0.88,0.74,0.58)]
const HAIR=[Color(0.03,0.025,0.02),Color(0.09,0.06,0.04),Color(0.2,0.12,0.06),Color(0.42,0.27,0.13),Color(0.75,0.6,0.35),Color(0.88,0.78,0.55),Color(0.45,0.14,0.05),Color(0.55,0.55,0.55),Color(0.85,0.85,0.83)]

# realistische Kleidungsfarben
const CLOTH=[Color(0.08,0.1,0.18),Color(0.05,0.05,0.06),Color(0.3,0.3,0.32),Color(0.55,0.55,0.55),Color(0.62,0.53,0.4),Color(0.3,0.33,0.2),Color(0.38,0.08,0.1),Color(0.2,0.3,0.48),Color(0.36,0.24,0.15),Color(0.85,0.84,0.8),Color(0.15,0.25,0.22),Color(0.5,0.2,0.12),Color(0.7,0.62,0.45),Color(0.24,0.17,0.3)]
const ANIMS={
	"idle":["res://assets/animations/xbot_anims.glb","idle"],
	"walk":["res://assets/animations/walking.glb",""],
	"run":["res://assets/animations/xbot_anims.glb","run"],
	"talk":["res://assets/animations/xbot_anims.glb","agree"],
	"shake":["res://assets/animations/xbot_anims.glb","headShake"],
	"punch":["res://assets/characters/daya/daya.gltf",""],
	"dance":["res://assets/characters/michelle.glb","SambaDance"],
}
static var _src:={}        # Animationsquelle -> [root, skeleton, AnimationPlayer]
static var _lib_cache:={}  # Grundmodell -> AnimationLibrary
static var _variants:={}
static var _shader:Shader

static func _src_of(path:String)->Array:
	if not _src.has(path):
		var n=load(path).instantiate();var ap:AnimationPlayer=n.find_child("AnimationPlayer",true,false)
		_src[path]=[n,U.find_skel(n),ap]
	return _src[path]

# Animationsbibliothek für ein Grundmodell (einmal pro Modell berechnet, dann geteilt)
static func library(base:String,ch:Node3D,sk:Skeleton3D)->AnimationLibrary:
	if _lib_cache.has(base):return _lib_cache[base]
	var lib=AnimationLibrary.new()
	for k in ANIMS:
		var s=_src_of(ANIMS[k][0]);var ap:AnimationPlayer=s[2]
		if ap==null:continue
		var nm:String=ANIMS[k][1]
		if nm=="" or not ap.has_animation(nm):nm=ap.get_animation_list()[0]
		var a=U.retarget_world(ap.get_animation(nm),s[1],s[0],sk,ch)
		a.loop_mode=Animation.LOOP_LINEAR
		if k in ["run","walk"]:_fuesse_planen(a,sk,ch)
		lib.add_animation(k,a)
	_lib_cache[base]=lib
	return lib

static func _variant_info(path:String)->Dictionary:
	if path=="":return {}
	if not _variants.has(path):
		var f=FileAccess.open(path,FileAccess.READ);_variants[path]=JSON.parse_string(f.get_as_text()) if f else {}
	return _variants[path]

static func _get_shader()->Shader:
	if _shader==null:_shader=load("res://shaders/person.gdshader")
	return _shader

# Eine Person erzeugen. look: optionale Vorgaben {skin, hair, hue, sat, val, height}
static func make(base:String,rng:RandomNumberGenerator,look:={})->Node3D:
	var b=BASES[base]
	var ch:Node3D=load(b[0]).instantiate()
	var info=_variant_info(b[1])
	var ref_skin=Color(0.75,0.55,0.45);if info.has("skin"):ref_skin=Color(info.skin[0],info.skin[1],info.skin[2])
	var ref_hair=Color(0.1,0.07,0.05);if info.get("hair")!=null:ref_hair=Color(info.hair[0],info.hair[1],info.hair[2])
	var masks:Dictionary=info.get("masks",{})
	var skin:Color=look.get("skin",SKIN[rng.randi()%SKIN.size()])
	var hair:Color=look.get("hair",HAIR[rng.randi()%(3 if info.get("vmask",false) else HAIR.size())])  # Scans: nur dunkle Töne (kein Fleckenmuster)
	var keep=rng.randf()<0.25
	var hue:float=look.get("hue",0.0 if keep else rng.randf_range(-0.05,0.05))
	var sat:float=look.get("sat",1.0 if keep else rng.randf_range(0.7,1.15))
	var val:float=look.get("val",1.0 if keep else rng.randf_range(0.8,1.12))
	var tint:Color=look.get("tint",CLOTH[rng.randi()%CLOTH.size()])
	var cmix:float=look.get("mix",0.0 if keep else rng.randf_range(0.5,0.85))
	var dir=b[1].get_base_dir()+"/"
	for m in ch.find_children("*","MeshInstance3D",true,false):
		m.extra_cull_margin=2.0
		for i in m.mesh.get_surface_count():
			var mt=m.get_active_material(i)
			if not (mt is BaseMaterial3D):continue
			var nm=mt.resource_name.to_lower()
			if nm.contains("eye") or nm.contains("cornea") or nm.contains("teeth") or nm.contains("tongue") or nm.contains("lash"):continue
			var sm=ShaderMaterial.new();sm.shader=_get_shader()
			var at:Texture2D=mt.albedo_texture
			sm.set_shader_parameter("albedo_tex",at);sm.set_shader_parameter("has_albedo",at!=null)
			sm.set_shader_parameter("albedo_color",mt.albedo_color);sm.set_shader_parameter("use_vcol",mt.vertex_color_use_as_albedo or at==null)
			if mt.normal_enabled and mt.normal_texture:sm.set_shader_parameter("normal_tex",mt.normal_texture);sm.set_shader_parameter("has_normal",true)
			sm.set_shader_parameter("roughness",mt.roughness);sm.set_shader_parameter("metallic",mt.metallic)
			if mt.roughness_texture:sm.set_shader_parameter("rough_tex",mt.roughness_texture);sm.set_shader_parameter("has_rough",true);sm.set_shader_parameter("rough_channel",int(mt.roughness_texture_channel))
			sm.set_shader_parameter("alpha_cut",mt.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED)
			# Haut/Haare: Scan-Figuren über Vertex-Maske (UV2), sonst nach Materialname
			sm.set_shader_parameter("use_uv2",info.get("vmask",false))
			var cls=0
			if nm in ["torso","hand","hands","legs","feet","face","body","arms","skin"] or (base=="daya" and nm.begins_with("material_0")):cls=1   # eindeutig benannte Hautmaterialien (Daya: Kopf = material_0)
			elif not info.get("vmask",false):
				if (nm.contains("skin") or nm.contains("bodymat") or nm=="body") and not nm.contains("nail"):cls=1
				elif nm.contains("hair") or nm.contains("scalp") or nm.contains("brow") or nm.contains("beard") or nm.contains("hawk"):cls=2
			sm.set_shader_parameter("mat_class",cls)
			if cls==1:sm.set_shader_parameter("use_uv2",false)
			sm.set_shader_parameter("ref_skin",ref_skin);sm.set_shader_parameter("ref_hair",ref_hair)
			sm.set_shader_parameter("skin",skin);sm.set_shader_parameter("hair",hair)
			if cls==1 and at!=null:sm.set_shader_parameter("ref_skin",_median_color(at)*mt.albedo_color)   # Bezug = mittlere Farbe genau dieser Hauttextur
			sm.set_shader_parameter("cloth_tint",tint);sm.set_shader_parameter("cloth_mix",cmix)
			sm.set_shader_parameter("cloth_hue",hue);sm.set_shader_parameter("cloth_sat",sat);sm.set_shader_parameter("cloth_val",val)
			m.set_surface_override_material(i,sm)
	var h:float=look.get("height",b[2]*rng.randf_range(0.93,1.07))
	var w=F.place(ch,h)
	var wide=rng.randf_range(0.94,1.1);ch.scale*=Vector3(wide,1,wide)
	var root=Node3D.new();root.name="Person_"+base;root.add_child(w)
	var sk=U.find_skel(ch)
	if sk:
		var old=ch.find_child("AnimationPlayer",true,false)
		if old:old.stop();old.name="OrigPlayer"
		var ap=AnimationPlayer.new();ap.name="Anim";ch.add_child(ap);ap.root_node=ap.get_path_to(ch)
		ap.add_animation_library("",library(base,ch,sk))
		root.set_meta("anim",ap)
	return root

static func play(p:Node3D,anim:String,phase:=0.0,speed:=1.0):
	var ap:AnimationPlayer=p.get_meta("anim",null)
	if ap==null or not ap.has_animation(anim):return
	ap.play(anim,0.25,speed);if phase>0:ap.seek(phase*ap.get_animation(anim).length,true)

static var _medcache:={}
static var _medfile=null
static func _median_color(t:Texture2D)->Color:
	var key=t.get_rid().get_id()
	if _medcache.has(key):return _medcache[key]
	# vorab berechnete Werte (auf dem Handy niemals Texturen von der Grafikkarte zurücklesen – das hängt)
	if _medfile==null:
		_medfile={}
		var f=FileAccess.open("res://assets/cache/median_farben.json",FileAccess.READ)
		if f:_medfile=JSON.parse_string(f.get_as_text())
	if _medfile.has(t.resource_path):
		var v=_medfile[t.resource_path];var c0=Color(v[0],v[1],v[2]);_medcache[key]=c0;return c0
	print("MEDIAN-CACHE FEHLT: ",t.resource_path)
	if OS.has_feature("mobile") or OS.has_feature("template"):
		_medcache[key]=Color(0.6,0.5,0.45);return _medcache[key]
	var img:Image=t.get_image()
	if img==null:return Color(0.75,0.55,0.45)
	img=img.duplicate()
	if img.is_compressed():img.decompress()
	img.resize(16,16)
	var rs=[];var gs=[];var bs=[]
	for y in 16:
		for x in 16:
			var c=img.get_pixel(x,y)
			if c.a>0.5 and c.get_luminance()>0.06:rs.append(c.r);gs.append(c.g);bs.append(c.b)
	if rs.is_empty():return Color(0.75,0.55,0.45)
	rs.sort();gs.sort();bs.sort()
	var c=Color(rs[rs.size()/2],gs[gs.size()/2],bs[bs.size()/2])
	_medcache[key]=c
	# am PC fehlende Werte in den Cache schreiben (wird mit ins Spiel gepackt)
	if t.resource_path!="" and not OS.has_feature("template"):
		_medfile[t.resource_path]=[c.r,c.g,c.b]
		var fw=FileAccess.open("res://assets/cache/median_farben.json",FileAccess.WRITE)
		if fw:fw.store_string(JSON.stringify(_medfile));fw.close()
	return c


# Bodenkontakt: Die Bewegungen übertragen nur Drehungen – beim Rennen schwebten die Füße dadurch über dem Boden.
# Hier wird pro Bild die Hüfte so weit abgesenkt, dass der tiefste Fuß wieder auf dem Boden steht.
static func _fuesse_planen(a:Animation,sk:Skeleton3D,ch:Node3D):
	var hips=-1;var fuesse=[]
	for i in sk.get_bone_count():
		var k=U.human_key(sk.get_bone_name(i))
		if k=="Hips" and hips<0:hips=i
		if k in ["LeftFoot","RightFoot","LeftToeBase","RightToeBase"]:fuesse.append(i)
	if hips<0 or fuesse.is_empty():return
	var sx=F.rel_xf(sk,ch)
	var up=(sx.basis.inverse()*Vector3.UP).normalized()
	var spur={}
	for t in a.get_track_count():
		if a.track_get_type(t)!=Animation.TYPE_ROTATION_3D:continue
		var bn=str(a.track_get_path(t)).get_slice(":",1)
		var bi=sk.find_bone(bn)
		if bi>=0:spur[bi]=t
	var n=sk.get_bone_count()
	var fk=func(zeit:float,mit_anim:bool)->Array:
		var g=[];g.resize(n)
		for i in n:
			var r:Transform3D=sk.get_bone_rest(i)
			var q:Quaternion=r.basis.orthonormalized().get_rotation_quaternion()
			if mit_anim and spur.has(i):q=a.rotation_track_interpolate(spur[i],zeit)
			var lok=Transform3D(Basis(q).scaled(r.basis.get_scale()),r.origin)
			var p=sk.get_bone_parent(i)
			g[i]=lok if p<0 else g[p]*lok
		return g
	# Eltern liegen bei glTF-Skeletten immer vor den Kindern
	var ruhe=fk.call(0.0,false)
	var h0=INF
	for f in fuesse:h0=min(h0,ruhe[f].origin.dot(up))
	var pt=a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pt,str(ch.get_path_to(sk))+":"+sk.get_bone_name(hips))
	var schritte=int(ceil(a.length*30.0))
	var hp=sk.get_bone_parent(hips)
	for f in schritte+1:
		var zeit=min(f/30.0,a.length)
		var g=fk.call(zeit,true)
		var h=INF
		for fu in fuesse:h=min(h,g[fu].origin.dot(up))
		var d=up*(h-h0)
		var lokal=d
		if hp>=0:lokal=g[hp].basis.inverse()*d
		a.position_track_insert_key(pt,zeit,sk.get_bone_rest(hips).origin-lokal)
