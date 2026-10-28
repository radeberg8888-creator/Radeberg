extends AnimatableBody3D
# Trefferkörper eines Passanten (bewegt sich mit der Figur)
var spiel
var eintrag
func ist_mensch()->bool:return true
func treffer(dmg:float,von,punkt:Vector3):
	spiel.passant_treffer(eintrag,von)
