extends MultiMeshInstance3D
# Gras-Büschel um den Spieler (nur auf Wiesen, nicht auf Straßen/Plätzen), wiegen im Wind.
var welt
var anzahl:=3500
var radius:=34.0
var _mitte:=Vector3(1e9,0,1e9)
var _rng:=RandomNumberGenerator.new()

func _ready():
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true
	multimesh.mesh=_buesche();multimesh.instance_count=anzahl;multimesh.visible_instance_count=0
	var sm=ShaderMaterial.new();sm.shader=load("res://shaders/gras.gdshader");sm.set_shader_parameter("tex",_textur())
	material_override=sm

func _buesche()->ArrayMesh:
	# drei gekreuzte Karten
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a=k*PI/3.0;var d=Vector3(cos(a),0,sin(a))*0.45
		var p=[-d,d,d+Vector3(0,0.55,0),-d+Vector3(0,0.55,0)]
		var uv=[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
		for i in [0,1,2,0,2,3]:
			st.set_normal(Vector3.UP);st.set_uv(uv[i]);st.add_vertex(p[i])
	return st.commit()

func _textur()->ImageTexture:
	var w=64;var h=64
	var img=Image.create(w,h,true,Image.FORMAT_RGBA8);img.fill(Color(0,0,0,0))
	var r=RandomNumberGenerator.new();r.seed=3
	for b in 46:
		var x0=r.randf_range(2,w-3);var lean=r.randf_range(-10,10);var top=r.randf_range(4,h*0.55)
		var g=r.randf_range(0.75,1.1)
		for y in range(int(top),h):
			var t=float(y-top)/float(h-top)
			var x=x0+lean*(1.0-t)*(1.0-t)
			var wd=lerp(0.6,1.8,t)
			for xx in range(int(x-wd),int(x+wd)+1):
				if xx<0 or xx>=w:continue
				var c=Color(0.32*g,0.48*g,0.16*g).lerp(Color(0.62*g,0.66*g,0.32*g),1.0-t)
				img.set_pixel(xx,y,Color(c.r,c.g,c.b,1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func aktualisieren(p:Vector3,an:bool):
	visible=an
	if not an:return
	if Vector2(p.x-_mitte.x,p.z-_mitte.z).length()<radius*0.3:return
	_mitte=p
	var G=welt.G;var B=welt.B
	_rng.seed=int(p.x/5.0)*7919+int(p.z/5.0)
	var n=0
	for i in anzahl:
		var a=_rng.randf()*TAU;var d=sqrt(_rng.randf())*radius
		var q=Vector2(p.x+cos(a)*d,p.z+sin(a)*d)
		if not B.is_free(q):continue
		var h=G.h_at(q.x,q.y)
		if h<1.5:continue
		var s=G.soil(q.x,q.y,h,0.1)
		var gras=s.r+s.g*0.6+(1.0-s.r-s.g-s.b-s.a)*0.8
		if gras<0.35 or _rng.randf()>gras:continue
		var sc=_rng.randf_range(0.7,1.35)
		var t=Transform3D(Basis(Vector3.UP,_rng.randf()*TAU).scaled(Vector3(sc,sc*_rng.randf_range(0.8,1.3),sc)),Vector3(q.x,h-0.03,q.y))
		multimesh.set_instance_transform(n,t)
		var trocken=1.0-s.r
		multimesh.set_instance_color(n,Color(1.0-trocken*0.15,1.0-trocken*0.05,1.0-trocken*0.4))
		n+=1
	multimesh.visible_instance_count=n
