extends Node3D
# Folgt einem BoneAttachment3D ohne dessen Skalierung zu übernehmen (Retargeting-Animationen skalieren Knochen teils).
var rel:=Transform3D.IDENTITY   # Lage relativ zum orthonormierten Knochenrahmen
func setup(bone_world:Transform3D,target_world:Transform3D):
	var bn=Transform3D(bone_world.basis.orthonormalized(),bone_world.origin)
	rel=bn.affine_inverse()*target_world
	top_level=true;_upd()
func _process(_d):_upd()
func _upd():
	var a=get_parent() as Node3D
	if a==null:return
	var g=a.global_transform
	global_transform=Transform3D(g.basis.orthonormalized(),g.origin)*rel
