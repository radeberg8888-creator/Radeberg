extends RefCounted
# Sammelt viele Kästen/Zylinder je Material in wenigen Meshes (schnell auf dem Handy)
var tools:={}   # Material -> SurfaceTool
var mats:={}
static var BOX:=BoxMesh.new()
static var CYL:=_zylinder()
# Standard-Zylinder hat 64 Segmente x 4 Ringe (~650 Punkte) – für Masten, Tonnen, Ampellichter reichen 10
static func _zylinder()->CylinderMesh:
	var c=CylinderMesh.new();c.radial_segments=10;c.rings=0
	return c
static var PRISM:=PrismMesh.new()

func _st(m:Material)->SurfaceTool:
	var k=m.get_instance_id()
	if not tools.has(k):
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);tools[k]=st;mats[k]=m
	return tools[k]

func add_mesh(mesh:Mesh,m:Material,xf:Transform3D):
	_st(m).append_from(mesh,0,xf)

# Kasten zwischen zwei Ecken (in einem lokalen Rahmen xf)
func box(m:Material,a:Vector3,b:Vector3,xf:=Transform3D.IDENTITY):
	var c=(a+b)*0.5;var s=(b-a).abs()
	if s.x<0.0005 or s.y<0.0005 or s.z<0.0005:return
	add_mesh(BOX,m,xf*Transform3D(Basis().scaled(s),c))

func box_rot(m:Material,center:Vector3,size:Vector3,basis:Basis,xf:=Transform3D.IDENTITY):
	add_mesh(BOX,m,xf*Transform3D(basis*Basis().scaled(size),center))

func cyl(m:Material,center:Vector3,radius:float,height:float,xf:=Transform3D.IDENTITY,basis:=Basis()):
	add_mesh(CYL,m,xf*Transform3D(basis*Basis().scaled(Vector3(radius*2,height*0.5,radius*2)),center))

func prism(m:Material,center:Vector3,size:Vector3,xf:=Transform3D.IDENTITY,basis:=Basis()):
	add_mesh(PRISM,m,xf*Transform3D(basis*Basis().scaled(size),center))

func commit(parent:Node3D,shadows:=true)->Array:
	var out=[]
	for k in tools:
		var st:SurfaceTool=tools[k];st.generate_tangents()
		var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=mats[k]
		mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi);out.append(mi)
	tools.clear();mats.clear();return out
