extends RefCounted
# Hauptstadt als geschlossene Häuserblöcke: das Straßennetz schneidet die Stadtfläche in Blöcke,
# scripts/stadtbau.gd bebaut jeden Block am Rand lückenlos (Front zur Straße), mit Hinterhäusern,
# Höfen (Garagen, Parkplätze, Spielplatz), Mauern mit Toren, Geldautomaten. Dazu Ampeln an Kreuzungen.
# Häuser landen als Platzierungsdaten in B.placed (Streaming wie bisher), Kleinkram als Kachel-Meshes.
const SB=preload("res://scripts/stadtbau.gd")
const Mats=preload("res://scripts/mats.gd")
var G;var S;var B
var baeume:=[]   # Transform3D für Straßen-/Hofbäume (werden zu MultiMesh-Stufen)
var log:=[]
var _occ0:PackedByteArray
var abgelehnt:=0
var _baum_dummy:=BoxMesh.new()   # Bäume laufen über baum_cb (MultiMesh); Platzhalter nur, damit gestreut wird

func _init(g,s,b):G=g;S=s;B=b

func bauen(parent:Node3D):
	var t0=Time.get_ticks_msec()
	B.reservieren_mitschreiben=false
	_occ0=B.occ.duplicate()   # Stand vor der Blockbebauung: Straßenstempel (1) sind kein Hindernis, die Blöcke liegen schon neben der Fahrbahn
	var sb=SB.new();sb.rng.seed=2027
	var wurzel=Node3D.new();wurzel.name="Hofdeko";parent.add_child(wurzel)
	sb.hoehe_cb=func(p:Vector2)->float:return G.h_at(p.x,p.y)
	sb.baum_cb=func(p:Vector2,y:float,sk:float):baeume.append(Transform3D(Basis(Vector3.UP,sb.rng.randf()*TAU).scaled(Vector3.ONE*sk),Vector3(p.x,y+0.18,p.y)))
	var aktuell={"d":null}
	sb.haus_cb=func(name,yaw,mitte,hy,boden,dehn,laengs_x,m,n):_haus(name,yaw,mitte,hy,boden,dehn,laengs_x,m,n,aktuell.d,sb)
	# 1) Blöcke aus dem Straßennetz
	var mn=Vector2(-2700,-1700);var mx=Vector2(3600,2700)
	var stuecke=[[PackedVector2Array([mn,Vector2(mx.x,mn.y),mx,Vector2(mn.x,mx.y)]),Rect2(mn,mx-mn)]]
	for r in S.roads:
		if not r.typ in ["strasse","allee","gasse","autobahn","rampe","land","schiene"]:continue
		var rad=r.w+r.sw+0.3
		if r.typ=="autobahn":rad=r.w+5.0
		if r.typ=="schiene":rad=4.0
		var bb=Rect2(r.P[0],Vector2.ZERO)
		for p in r.P:bb=bb.expand(p)
		bb=bb.grow(rad+1.0)
		if not bb.intersects(Rect2(mn,mx-mn)):continue
		var linie=PackedVector2Array()
		for i in range(0,r.P.size(),2):linie.append(r.P[i])
		if linie[linie.size()-1]!=r.P[r.P.size()-1]:linie.append(r.P[r.P.size()-1])
		var baender=Geometry2D.offset_polyline(linie,rad,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
		var neu=[]
		for st in stuecke:
			if not st[1].intersects(bb):neu.append(st);continue
			var teile=[st[0]]
			for band in baender:
				var t2=[]
				for t in teile:
					for x in Geometry2D.clip_polygons(t,band):
						if not Geometry2D.is_polygon_clockwise(x):t2.append(x)
				teile=t2
			for t in teile:neu.append([t,_rect(t)])
		stuecke=neu
	log.append("Stücke nach Straßen: %d (%d ms)"%[stuecke.size(),Time.get_ticks_msec()-t0])
	# 2) freigehaltene Flächen (Läden, Bahnhof, Park, Villen …) herausschneiden
	var res_polys=[]
	for r in B.reserviert:
		var c:Vector2=r[0];var a:Vector2=r[1].normalized();var nrm=Vector2(-a.y,a.x)
		var hx=r[2]+3.0;var hz=r[3]+3.0
		res_polys.append(PackedVector2Array([c-a*hx-nrm*hz,c+a*hx-nrm*hz,c+a*hx+nrm*hz,c-a*hx+nrm*hz]))
	var bloecke=[]
	for st in stuecke:
		var teile=[st[0]]
		for rp in res_polys:
			if not st[1].intersects(_rect(rp)):continue
			var t2=[]
			for t in teile:
				for x in Geometry2D.clip_polygons(t,rp):
					if not Geometry2D.is_polygon_clockwise(x):t2.append(x)
			teile=t2
		for t in teile:bloecke.append(t)
	# 2b) zu große Flächen (keine Straße hindurch) mit Fußgängergassen in Blöcke von ~110 m teilen
	var gassen=[]   # Mittellinien, als Betonweg gezeichnet
	var feiner=[]
	for poly in bloecke:
		if _flaeche(poly)<26000.0:feiner.append(poly);continue
		var bb=_rect(poly);var teile=[poly]
		var linien=[]
		var nx=int(round(bb.size.x/110.0));var nz=int(round(bb.size.y/110.0))
		for i in range(1,nx):
			var x=bb.position.x+bb.size.x*i/nx;linien.append([Vector2(x,bb.position.y-5),Vector2(x,bb.end.y+5)])
		for i in range(1,nz):
			var z=bb.position.y+bb.size.y*i/nz;linien.append([Vector2(bb.position.x-5,z),Vector2(bb.end.x+5,z)])
		for l in linien:
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array(l),poly):gassen.append(seg)
			var band=Geometry2D.offset_polyline(PackedVector2Array(l),3.5,Geometry2D.JOIN_SQUARE,Geometry2D.END_BUTT)
			var t2=[]
			for t in teile:
				var rest=[t]
				for b in band:
					var r2=[]
					for x0 in rest:
						for x in Geometry2D.clip_polygons(x0,b):
							if not Geometry2D.is_polygon_clockwise(x):r2.append(x)
					rest=r2
				t2.append_array(rest)
			teile=t2
		feiner.append_array(teile)
	bloecke=feiner
	# 3) bebauen
	var deko={}   # Kachel -> Batch
	var n_bl=0;var grund={"klein":0,"gross":0,"viertel":0,"rand":0}
	var gross_fl=0.0
	for poly in bloecke:
		var fl=sb._flaeche(poly)
		if fl<250.0:grund.klein+=1;continue
		if fl>70000.0:grund.gross+=1;gross_fl+=fl;continue
		var c=Vector2.ZERO
		for v in poly:c+=v
		c/=poly.size()
		var d=B.district(c)
		if d==null or not d.n in B.BLOCK_VIERTEL:grund.viertel+=1;continue
		# Rand der Gesamtfläche, Wasser, Steilhang
		var ok=true;var hmin=INF;var hmax=-INF
		for v in poly:
			if v.x<mn.x+5 or v.y<mn.y+5 or v.x>mx.x-5 or v.y>mx.y-5:ok=false;break
			var h=G.h_at(v.x,v.y);hmin=min(hmin,h);hmax=max(hmax,h)
		if not ok or hmin<1.2:grund.rand+=1;continue
		poly=sb._vereinfachen(poly,0.6)
		if poly.size()<3:continue
		var steil=hmax-hmin>5.0
		aktuell.d=d
		var k=Vector2i(floor(c.x/300.0),floor(c.y/300.0))
		if not deko.has(k):deko[k]=load("res://scripts/batch.gd").new()
		sb.b_deko=deko[k]
		var opt=_optionen(d,fl,sb)
		opt.ohne_gehweg=true;opt.hofboden=false   # Hofboden war eine flache Platte auf schrägem Gelände (schwebte/versank); jetzt Gelände + Pflaster unter Parkplätzen
		var gy=(hmin+hmax)*0.5+0.04
		var e=sb.block(wurzel,poly,gy-sb.bord_h,opt)
		if not steil and e.size()>0:sb.hof_ausstatten(wurzel,e,gy,_baum_dummy,[])
		n_bl+=1
	log.append("übersprungen %s, große Fläche %.0f ha"%[str(grund),gross_fl/10000.0])
	# 4) Ampeln an Kreuzungen in der Stadt
	var n_amp=0
	for j in S.junctions:
		if j.get("rail",false):continue
		var d=B.district(j.p)
		if d==null or not d.n in B.BLOCK_VIERTEL:continue
		var k=Vector2i(floor(j.p.x/300.0),floor(j.p.y/300.0))
		if not deko.has(k):deko[k]=load("res://scripts/batch.gd").new()
		sb.b_deko=deko[k]
		for ri in [j.a,j.b]:
			var r=S.roads[ri]
			if not r.typ in ["strasse","allee"]:continue
			var best=0;var bd=INF
			for i in r.P.size():
				var dd=r.P[i].distance_to(j.p)
				if dd<bd:bd=dd;best=i
			for richtung in [-1,1]:
				var i2=best+richtung*int(ceil((j.r+3.0)/S.DS))
				if i2<0 or i2>=r.P.size():continue
				var p:Vector2=r.P[i2];var t:Vector2=(j.p-p).normalized();var nn=Vector2(t.y,-t.x)
				var q=p+nn*(r.w+r.sw*0.5)
				sb.bord_h=r.h[i2]+0.14-0.0
				sb.ampel(wurzel,q,-t,(ri==j.a)==(n_amp%2==0));n_amp+=1
	sb.bord_h=0.15
	var beton=Mats.pbr("concrete",0.35,Color(0.7,0.69,0.66))
	var n_g=0
	for seg in gassen:
		var a:Vector2=seg[0];var b:Vector2=seg[seg.size()-1]
		var mid=(a+b)*0.5;var d=B.district(mid)
		if d==null or not d.n in B.BLOCK_VIERTEL:continue
		var L=a.distance_to(b);var n=int(ceil(L/5.0))
		var k=Vector2i(floor(mid.x/300.0),floor(mid.y/300.0))
		if not deko.has(k):deko[k]=load("res://scripts/batch.gd").new()
		sb.b_deko=deko[k]
		for i in n:
			var p0=a.lerp(b,float(i)/n);var p1=a.lerp(b,float(i+1)/n)
			var h0=G.h_at(p0.x,p0.y);var h1=G.h_at(p1.x,p1.y)
			if min(h0,h1)<1.0:continue
			var c=(p0+p1)*0.5;var dd=p1-p0;var l=dd.length()
			var bas=Basis(Vector3.UP,atan2(dd.x,dd.y))*Basis(Vector3.RIGHT,-atan2(h1-h0,l))
			sb.b_deko.box_rot(beton,Vector3(c.x,(h0+h1)*0.5-0.1,c.y),Vector3(6.6,0.3,l+0.3),bas)
		n_g+=1
	log.append("Gassen %d"%n_g)
	for k in deko:
		var ms=deko[k].commit(wurzel,false)
		for m in ms:m.visibility_range_end=450.0
	log.append_array(sb.log.filter(func(x):return x.begins_with("Geldautomat")).slice(0,3))
	log.append("abgelehnt %d"%abgelehnt)
	log.append("Blöcke %d, Häuser %d, Bäume %d, Ampeln %d, Geldautomaten %d, %d ms"%[n_bl,B.placed.size(),baeume.size(),n_amp,wurzel.get_tree().get_nodes_in_group("geldautomat").size() if wurzel.is_inside_tree() else -1,Time.get_ticks_msec()-t0])
	B.reservieren_mitschreiben=false

func _rect(p:PackedVector2Array)->Rect2:
	var r=Rect2(p[0],Vector2.ZERO)
	for v in p:r=r.expand(v)
	return r

func _optionen(d:Dictionary,fl:float,sb)->Dictionary:
	var liste=[];var eck=[]
	for e in d.list:
		if not sb.fronten.has(e[0]):continue
		liste.append(e)
		if sb.fronten[e[0]].seiten.size()>=2:eck.append(e)
	if eck.is_empty():eck=liste
	var opt={"liste":liste,"eck":eck,"liste_hinten":liste}
	sb.tiefe=55.0 if d.n=="downtown" else 24.0
	match d.n:
		"downtown":opt.hoehen=[Vector2(25,999)]
		"ghetto","suedstadt":opt.hoehen=[Vector2(5,14),Vector2(12.5,19)]
		_:opt.hoehen=[Vector2(0,999)]
	var z=sb.rng.randf()
	if fl>9000.0 and z<0.25:opt.hof="gruen";opt.ring_ab=99999.0
	elif fl>4000.0 and z<0.45:opt.hof="gasse"
	else:opt.hof="hinterhof"
	if fl<2500.0:opt.durchgang=false
	return opt

func _haus(name,yaw,mitte:Vector2,hy:float,boden:float,dehn:float,laengs_x:bool,m:Vector2,n:Vector2,d,sb):
	# Platz frei? (Läden, Bahnhof … und andere Häuser)
	var a=Vector2(n.y,-n.x)
	for idx in B._rect_cells(mitte,a,m.x*0.5*dehn-1.0,m.y*0.5-1.0):
		if _occ0[idx]==2:abgelehnt+=1;return
	B.rect_mark(mitte,a,m.x*0.5*dehn,m.y*0.5)
	var y=hy+0.15-boden+0.02
	B.placed.append({"t":name,"v":sb.rng.randi()%5,"dirt":float(d.dirt)*sb.rng.randf_range(0.6,1.1),"c":mitte,"y":y+0.12,"yaw":yaw,"d":d.n,
		"sk":[dehn,1.0] if laengs_x else [1.0,dehn]})
	G.flatten(mitte,hy,sqrt(m.x*m.x+m.y*m.y)*0.5+1.0,8.0)

func _flaeche(p:PackedVector2Array)->float:
	var a=0.0
	for i in p.size():a+=p[i].cross(p[(i+1)%p.size()])
	return abs(a)*0.5
