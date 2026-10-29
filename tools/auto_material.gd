extends SceneTree
# Fahrzeugmaterialien reparieren: Karosserie-Teile, die fälschlich als "durchsichtig" markiert sind
# (Alpha-Modus bei voller Deckkraft), werden deckend bzw. mit Alphatest gezeichnet – sonst flackern/verschwinden
# Teile auf dem Handy. Echtes Glas bleibt durchsichtig, wird aber mindestens leicht getönt.
const DIR:="res://assets/cache/autos/"
func _init():
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".scn"):continue
		var n:Node3D=load(DIR+f).instantiate();var aend=[]
		var fertig={}
		for m in n.find_children("*","MeshInstance3D",true,false):
			if m.mesh==null:continue
			for s in m.mesh.get_surface_count():
				var mt=m.mesh.surface_get_material(s)
				var ov=m.get_surface_override_material(s)
				for x in [mt,ov,m.material_override]:
					if not (x is BaseMaterial3D) or fertig.has(x):continue
					fertig[x]=true
					if x.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:continue
					var nm=x.resource_name.to_lower()
					var glas=nm.contains("glass") or nm.contains("glas") or nm.contains("window") or nm.contains("light") or nm.contains("lamp")
					if glas and x.albedo_color.a<0.99:
						if x.albedo_color.a<0.3:x.albedo_color.a=0.35;x.albedo_color=x.albedo_color.darkened(0.3)
						x.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;aend.append("Glas "+x.resource_name)
						continue
					if x.albedo_color.a>=0.99:
						var tex:Texture2D=x.albedo_texture
						var alpha=false
						if tex:
							var img=tex.get_image()
							if img:
								if img.is_compressed():img=img.duplicate();img.decompress()
								alpha=img.detect_alpha()!=Image.ALPHA_NONE
						x.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if alpha else BaseMaterial3D.TRANSPARENCY_DISABLED
						if alpha:x.alpha_scissor_threshold=0.05   # Scheiben im Textur-Atlas bleiben als dunkles Glas sichtbar
						aend.append(("Schnitt " if alpha else "deckend ")+x.resource_name)
		var ps=PackedScene.new();ps.pack(n)
		var e=ResourceSaver.save(ps,DIR+f,ResourceSaver.FLAG_COMPRESS)
		print("MAT ",f," ",aend.size()," geändert ",str(aend).left(200)," ",error_string(e))
		n.free()
	quit()
