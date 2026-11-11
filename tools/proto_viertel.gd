extends SceneTree
# PROBE (nicht im Spiel): ein Stück der alten Karte (vor dem Comic-Umbau) mit dem Bauprinzip des guten Innenstadtblocks.
#  1. Ein glattes Höhenfeld für die ganze Stadt: Straßen, Gehwege, Blöcke, Gleise fragen alle dasselbe Feld -> keine Stufen.
#  2. Straßennetz aus der alten Karte, bereinigt: lose Enden werden angebunden oder entfernt, zu große Blöcke bekommen
#     Querstraßen (deren Enden immer auf bestehenden Straßen liegen).
#  3. Blöcke = Fläche minus Fahrbahnen (alles, was kein Block ist, ist Straße) -> Netz ist lückenlos.
#  4. Bahn: durchgehendes Gleis mit Bahnübergängen (Schranke, Andreaskreuz, Blinklicht), Hochstraße auf Pfeilern.
# Ausgabe: Bilder + Prüfzahlen in /home/claude/work/proto_viertel/
const SL:="res://scripts/comic/stadt_lib.gd"
const OUT:="/home/claude/work/proto_viertel/"
var REG:=Rect2(150,-330,820,800)
var NUR_STATISTIK:=false     # Weltkoordinaten der Probe
var C:Vector2                         # Mitte -> lokale Koordinaten
var L
var W:Node3D
var BAHN:=[]          # [{P:PackedVector2Array, S}]
var UEBERGANG:=[]     # {p, t (Gleisrichtung), r (Straße)}
var BERICHT:={}
var SCHRANKEN:=[]

func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	if OS.get_cmdline_user_args().has("--klein"):REG=Rect2(350,-250,220,220)
	C=REG.get_center()
	W=Node3D.new();W.name="Probe";root.add_child(W)
	L=load(SL).new();L.init_lib(W,7)
	L.leicht=not OS.get_cmdline_user_args().has("--schwer")
	if L.leicht:L.SPH.radial_segments=9;L.SPH.rings=5;L.CYL.radial_segments=8
	L.spiel_modus=OS.get_cmdline_user_args().has("--stat")
	L.weit_detail=2000.0;L.weit_ink=900.0;L.kachel=150.0
	var t0=Time.get_ticks_msec()
	var d=JSON.parse_string(FileAccess.get_file_as_string("/home/claude/work/alte_karte.json"))
	_hoehenfeld(d)
	_strassen_laden(d)
	print("T laden ",Time.get_ticks_msec()-t0," Straßen ",ROH.size())
	_netz_bereinigen()
	print("T bereinigt ",Time.get_ticks_msec()-t0," ",BERICHT)
	_bahn_laden(d)
	_autobahn_laden(d)
	_umgebung()
	_bauen()
	print("BAU ",(Time.get_ticks_msec()-t0)/1000.0," s")
	_pruefen()
	var tri=0;var nmi=0
	for mi in W.find_children("*","MeshInstance3D",true,false):
		nmi+=1
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var a=mi.mesh.surface_get_arrays(si);var I=a[Mesh.ARRAY_INDEX]
				tri+=(I.size() if I!=null and I.size()>0 else a[Mesh.ARRAY_VERTEX].size())/3
	var tri_k=0;var n_k=0;var mm_n=0
	for mmi in W.find_children("*","MultiMeshInstance3D",true,false):
		mm_n+=1;var me=mmi.multimesh.mesh;var t1=0
		for si in me.get_surface_count():
			var a=me.surface_get_arrays(si);var I=a[Mesh.ARRAY_INDEX]
			t1+=(I.size() if I!=null and I.size()>0 else a[Mesh.ARRAY_VERTEX].size())/3
		tri_k+=t1*mmi.multimesh.instance_count;n_k+=mmi.multimesh.instance_count
	print("KOPIEN ",n_k," in ",mm_n," Gruppen, gezeichnete Dreiecke ",tri_k," Bauteile ",L.MODULE.size())
	print("DREIECKE ",tri," Meshes ",nmi," je Haus ",tri/max(BERICHT.haeuser,1))
	var nach={}
	for mi in W.find_children("*","MeshInstance3D",true,false):
		if mi.mesh==null:continue
		var key=mi.name.split("_")[1] if mi.name.begins_with("M_") else "einzeln"
		var m=mi.material_override;var nm=""
		for mk in L.M:
			var mv=L.M[mk]
			if mv is Array:
				for q in mv.size():
					if mv[q] is Material and mv[q]==m:nm=mk+str(q)
			elif mv is Material and mv==m:nm=mk
		if nm=="":nm="ink" if m==L.ink else (str(m.albedo_color) if m is StandardMaterial3D else (m.shader.resource_path+str(m.get_instance_id()) if m is ShaderMaterial else "?"))
		var t2=0
		for si in mi.mesh.get_surface_count():
			var a=mi.mesh.surface_get_arrays(si);var I=a[Mesh.ARRAY_INDEX]
			t2+=(I.size() if I!=null and I.size()>0 else a[Mesh.ARRAY_VERTEX].size())/3
		nach[nm]=nach.get(nm,0)+t2
	var ks=nach.keys();ks.sort_custom(func(a,b):return nach[a]>nach[b])
	for k in ks.slice(0,15):print("  MAT ",k," ",nach[k])
	if OS.get_cmdline_user_args().has("--stat"):quit();return
	await _bilder()
	quit()

func lok(p)->Vector2:return Vector2(p[0],p[1])-C
func R_lok()->Rect2:return Rect2(REG.position-C,REG.size)

# ---------------- 1. Höhenfeld ----------------
func _hoehenfeld(d):
	var nx:int=d.nx;var nz:int=d.nz;var X0:float=d.X0;var Z0:float=d.Z0;var ST:float=d.STEP
	var roh=FileAccess.get_file_as_bytes("/home/claude/work/alte_hoehen.bin").to_float32_array()
	var rand=200.0;var c=4.0
	var x0=REG.position.x-rand;var z0=REG.position.y-rand
	var n=int((REG.size.x+rand*2)/c)+1;var m=int((REG.size.y+rand*2)/c)+1
	var H=PackedFloat32Array();H.resize(n*m)
	for k in m:
		for i in n:
			var fx=(x0+i*c-X0)/ST;var fz=(z0+k*c-Z0)/ST
			var a=int(fx);var b=int(fz);var u=fx-a;var v=fz-b
			var h=lerp(lerp(roh[b*nx+a],roh[b*nx+a+1],u),lerp(roh[(b+1)*nx+a],roh[(b+1)*nx+a+1],u),v)
			H[k*n+i]=h
	var h_roh=H.duplicate()
	# glätten (Kastenfilter, mehrfach = Gauß, Radius ~55 m) bis die Steigung überall unter 6 % liegt
	var durch=0
	while true:
		for pass_ in 3:H=_box(H,n,m,7)
		durch+=1
		var g=_max_steig(H,n,m,c)
		if g<0.06 or durch>8:BERICHT["max_steigung_%"]=snapped(g*100.0,0.1);break
	var mn=INF;var mx=-INF
	for v in H:mn=min(mn,v);mx=max(mx,v)
	BERICHT["hoehe_min_max"]=[snapped(mn,0.1),snapped(mx,0.1)]
	L.HF=H;L.HF_N=n;L.HF_M=m;L.HF_C=c;L.HF_X0=x0-C.x;L.HF_Z0=z0-C.y
	L.LGX0=REG.position.x-C.x-20;L.LGZ0=REG.position.y-C.y-20;L.LGW=REG.size.x+40;L.LGH=REG.size.y+40
	var mnr=INF;var mxr=-INF
	for v in h_roh:mnr=min(mnr,v);mxr=max(mxr,v)
	print("HOEHEN roh ",mnr,"..",mxr," glatt ",BERICHT["hoehe_min_max"]," Steigung ",BERICHT["max_steigung_%"],"% nach ",durch," Durchgängen")
func _box(H:PackedFloat32Array,n:int,m:int,r:int)->PackedFloat32Array:
	var A=PackedFloat32Array();A.resize(n*m)
	for k in m:
		var s=0.0;var cnt=0
		for i in range(-r,r+1):
			var ii=clampi(i,0,n-1);s+=H[k*n+ii];cnt+=1
		for i in n:
			A[k*n+i]=s/cnt
			s+=H[k*n+clampi(i+r+1,0,n-1)]-H[k*n+clampi(i-r,0,n-1)]
	var B=PackedFloat32Array();B.resize(n*m)
	for i in n:
		var s=0.0;var cnt=0
		for k in range(-r,r+1):
			var kk=clampi(k,0,m-1);s+=A[kk*n+i];cnt+=1
		for k in m:
			B[k*n+i]=s/cnt
			s+=A[clampi(k+r+1,0,m-1)*n+i]-A[clampi(k-r,0,m-1)*n+i]
	return B
func _max_steig(H:PackedFloat32Array,n:int,m:int,c:float)->float:
	var g=0.0
	for k in range(1,m-1):
		for i in range(1,n-1):
			var gx=(H[k*n+i+1]-H[k*n+i-1])/(2*c);var gz=(H[(k+1)*n+i]-H[(k-1)*n+i])/(2*c)
			g=max(g,sqrt(gx*gx+gz*gz))
	return g

# ---------------- 2. Straßen ----------------
var ROH:=[]   # [{P,w,typ,n}]
func _strassen_laden(d):
	var rr=R_lok().grow(60.0)
	var breite={"allee":7.0,"strasse":5.0,"gasse":3.4,"land":5.0}
	for r in d.roads:
		if not r.typ in breite:continue
		var cur=PackedVector2Array()
		for q in r.P:
			var p=lok(q)
			if rr.has_point(p):cur.append(p)
			else:
				if cur.size()>=3:ROH.append({"P":cur,"w":breite[r.typ],"typ":r.typ,"n":r.name})
				cur=PackedVector2Array()
		if cur.size()>=3:ROH.append({"P":cur,"w":breite[r.typ],"typ":r.typ,"n":r.name})
	for r in ROH:r.P=_glatt(_dichte(r.P,4.0))
	BERICHT["strassen_alt"]=ROH.size()
func _dichte(P:PackedVector2Array,ds:float)->PackedVector2Array:
	var Q=PackedVector2Array([P[0]]);var acc=0.0
	for i in range(1,P.size()):
		var a=P[i-1];var b=P[i];var l=a.distance_to(b);var s=ds-acc
		while s<=l:Q.append(a.lerp(b,s/l));s+=ds
		acc=l-(s-ds)
	if Q[Q.size()-1].distance_to(P[P.size()-1])>0.5:Q.append(P[P.size()-1])
	return Q
func _glatt(P:PackedVector2Array)->PackedVector2Array:
	if P.size()<5:return P
	var Q=P.duplicate()
	for it in 3:
		var A=Q.duplicate()
		for i in range(1,Q.size()-1):A[i]=Q[i-1]*0.25+Q[i]*0.5+Q[i+1]*0.25
		Q=A
	return Q
func _len(P:PackedVector2Array)->float:
	var s=0.0
	for i in range(1,P.size()):s+=P[i].distance_to(P[i-1])
	return s
# nächster Punkt auf anderen Straßen: [Abstand, Punkt, Index]
func _naechst(p:Vector2,ohne:int)->Array:
	var bd=INF;var bp=Vector2.ZERO;var bi=-1
	for j in ROH.size():
		if j==ohne:continue
		var P:PackedVector2Array=ROH[j].P
		for i in P.size()-1:
			var q=Geometry2D.get_closest_point_to_segment(p,P[i],P[i+1]);var dd=q.distance_to(p)
			if dd<bd:bd=dd;bp=q;bi=j
	return [bd,bp,bi]
func _am_rand(p:Vector2)->bool:
	var r=R_lok().grow(55.0)
	return p.x<r.position.x+12 or p.y<r.position.y+12 or p.x>r.end.x-12 or p.y>r.end.y-12
func _netz_bereinigen():
	# a) doppelte (parallel übereinanderliegende) Straßen weg
	var weg=[]
	for i in ROH.size():
		var P:PackedVector2Array=ROH[i].P;var auf=0
		for k in range(0,P.size(),2):
			for j in ROH.size():
				if j==i or j in weg:continue
				if _len(ROH[j].P)<_len(P):continue
				var Q:PackedVector2Array=ROH[j].P;var hit=false
				for q in range(0,Q.size()-1):
					if Geometry2D.get_closest_point_to_segment(P[k],Q[q],Q[q+1]).distance_to(P[k])<ROH[j].w+ROH[i].w*0.6:hit=true;break
				if hit:auf+=1;break
		if auf>=int(ceil(P.size()/2.0))*0.6:weg.append(i)
	BERICHT["doppelt_entfernt"]=weg.size()
	var neu=[];for i in ROH.size():
		if not i in weg:neu.append(ROH[i])
	ROH=neu
	# b) lose Enden: an die nächste Straße anschließen, sonst geradeaus verlängern, sonst kurze Stummel entfernen
	var angebunden=0;var verlaengert=0;var entfernt=0
	for runde in 2:
		var weg2=[]
		for i in ROH.size():
			for ende in [0,1]:
				var P:PackedVector2Array=ROH[i].P
				var e:Vector2=P[0] if ende==0 else P[P.size()-1]
				var nb:Vector2=P[1] if ende==0 else P[P.size()-2]
				if _am_rand(e):continue
				var ns=_naechst(e,i)
				if ns[2]>=0 and ns[0]<ROH[ns[2]].w*0.5:continue   # schon verbunden
				var ziel=null
				if ns[2]>=0 and ns[0]<30.0:ziel=ns[1];angebunden+=1
				else:
					# geradeaus bis zur nächsten Straße (max. 90 m)
					var dir=(e-nb).normalized();var best=INF
					for j in ROH.size():
						if j==i:continue
						var Q:PackedVector2Array=ROH[j].P
						for q in Q.size()-1:
							var x=Geometry2D.segment_intersects_segment(e,e+dir*90.0,Q[q],Q[q+1])
							if x!=null and x.distance_to(e)<best:best=x.distance_to(e);ziel=x
					if ziel!=null:verlaengert+=1
				if ziel==null:
					if _len(P)<70.0:weg2.append(i)
					continue
				var add=_dichte(PackedVector2Array([e,ziel]),4.0)
				if ende==0:
					add.reverse();add.remove_at(add.size()-1);ROH[i].P=add+P
				else:
					add.remove_at(0);ROH[i].P=P+add
		entfernt+=weg2.size()
		var n2=[];for i in ROH.size():
			if not i in weg2:n2.append(ROH[i])
		ROH=n2
	BERICHT["enden_angebunden"]=angebunden;BERICHT["enden_verlaengert"]=verlaengert;BERICHT["stummel_entfernt"]=entfernt

# ---------------- Bahn + Autobahn ----------------
func _bahn_laden(d):
	var rr=R_lok().grow(80.0)
	for r in d.roads:
		if r.typ!="schiene" or r.name!="Bahn":continue
		var cur=PackedVector2Array()
		for q in r.P:
			var p=lok(q)
			if rr.has_point(p):cur.append(p)
			elif cur.size()>3:break
		if cur.size()>3:
			var P=_glatt(_dichte(cur,3.0));BAHN.append({"P":P,"S":L._laengen(P)})
	# Bahnübergänge: Schnitt Gleis x Straße
	for b in BAHN:
		var P:PackedVector2Array=b.P
		for r in ROH:
			var Q:PackedVector2Array=r.P
			for i in P.size()-1:
				for q in Q.size()-1:
					var x=Geometry2D.segment_intersects_segment(P[i],P[i+1],Q[q],Q[q+1])
					if x==null:continue
					var neu=true
					for u in UEBERGANG:
						if u.p.distance_to(x)<20.0:neu=false
					if neu:UEBERGANG.append({"p":x,"t":(P[i+1]-P[i]).normalized(),"r":r,"tr":(Q[q+1]-Q[q]).normalized()})
	BERICHT["bahnuebergaenge"]=UEBERGANG.size()
var AB:={}
func _autobahn_laden(d):
	var rr=R_lok().grow(150.0)
	for r in d.roads:
		if r.typ!="autobahn":continue
		var cur=PackedVector2Array()
		for q in r.P:
			var p=lok(q)
			if rr.has_point(p):cur.append(p)
			elif cur.size()>10:break
		if cur.size()>10:
			var P=_glatt(_dichte(cur,3.0))
			AB={"P":P,"S":L._laengen(P),"w":9.0};return

# ---------------- 3. Bauen ----------------
func _umgebung():
	var we=WorldEnvironment.new();var e=Environment.new();we.environment=e;W.add_child(we)
	var sky=Sky.new();var sm=ProceduralSkyMaterial.new()
	sm.sky_top_color=Color(0.25,0.52,0.9);sm.sky_horizon_color=Color(0.75,0.86,0.96);sm.ground_horizon_color=Color(0.75,0.86,0.96);sm.ground_bottom_color=Color(0.4,0.45,0.4)
	sky.sky_material=sm;e.sky=sky;e.background_mode=Environment.BG_SKY
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(0.72,0.78,0.9);e.ambient_light_energy=0.55
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	e.fog_enabled=true;e.fog_light_color=Color(0.78,0.86,0.96);e.fog_density=0.0007
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);sun.light_color=Color(1.0,0.95,0.86);sun.light_energy=1.15
	sun.shadow_enabled=true;sun.directional_shadow_max_distance=160.0;sun.shadow_bias=0.04;sun.shadow_normal_bias=1.0
	W.add_child(sun);SUN=sun
var SUN:DirectionalLight3D

func _baender(P:PackedVector2Array,w:float)->Array:
	return Geometry2D.offset_polyline(P,w,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
func _abziehen(stuecke:Array,baender:Array)->Array:
	for band in baender:
		var t2=[]
		for t in stuecke:
			for x in Geometry2D.clip_polygons(t,band):
				if not Geometry2D.is_polygon_clockwise(x):t2.append(x)
		stuecke=t2
	return stuecke
func _flaechen()->Array:
	var rr=R_lok()
	var stuecke=[PackedVector2Array([rr.position,Vector2(rr.end.x,rr.position.y),rr.end,Vector2(rr.position.x,rr.end.y)])]
	for r in ROH:stuecke=_abziehen(stuecke,_baender(r.P,r.w))
	for b in BAHN:stuecke=_abziehen(stuecke,_baender(b.P,5.0))
	if not AB.is_empty():stuecke=_abziehen(stuecke,_baender(AB.P,AB.w+3.0))
	return stuecke

# zu große Blöcke: Querstraße durch die Mitte, senkrecht zur längsten Ausdehnung, Enden bis auf die Nachbarstraßen
func _bloecke_teilen():
	var neu_n=0
	for runde in 4:
		var st=_flaechen();var geteilt=false
		for pc in st:
			var A=abs(L._flaeche2(pc))
			if A<9000:continue
			# Hauptachse (Kovarianz)
			var c=Vector2.ZERO
			for v in pc:c+=v
			c/=pc.size()
			var sxx=0.0;var szz=0.0;var sxz=0.0
			for v in pc:
				var q=v-c;sxx+=q.x*q.x;szz+=q.y*q.y;sxz+=q.x*q.y
			var ang=0.5*atan2(2*sxz,sxx-szz);var ax=Vector2(cos(ang),sin(ang))
			var lo=INF;var hi=-INF
			for v in pc:
				var pr=(v-c).dot(ax);lo=min(lo,pr);hi=max(hi,pr)
			if hi-lo<150.0 and A<16000:continue
			var nrm=Vector2(-ax.y,ax.x)
			var a=c-nrm*400.0;var b=c+nrm*400.0
			# Schnittstrecke mit dem Polygon: Teil, der die Mitte enthält
			var xs=[]
			for i in pc.size():
				var x=Geometry2D.segment_intersects_segment(a,b,pc[i],pc[(i+1)%pc.size()])
				if x!=null:xs.append((x-c).dot(nrm))
			xs.sort()
			var s0=-INF;var s1=INF
			for x in xs:
				if x<0:s0=x
				elif s1==INF:s1=x
			if s0==-INF or s1==INF:continue
			var p0=c+nrm*s0;var p1=c+nrm*s1
			# bis an die Straßenmitte verlängern
			for k in 14:
				var ns=_naechst(p0,-1)
				if ns[0]<0.6:break
				p0-=nrm
			for k in 14:
				var ns=_naechst(p1,-1)
				if ns[0]<0.6:break
				p1+=nrm
			if _am_rand(p0) or _am_rand(p1):
				if not R_lok().has_point(p0) or not R_lok().has_point(p1):continue
			ROH.append({"P":_dichte(PackedVector2Array([p0,p1]),4.0),"w":4.5,"typ":"strasse","n":"Querstraße"})
			neu_n+=1;geteilt=true
		if not geteilt:break
	BERICHT["querstrassen_neu"]=neu_n

func _bauen():
	_bloecke_teilen()
	print("T geteilt ",BERICHT)
	L.hoehen_an=true
	for r in ROH:L._strasse(r.n,r.P,r.w,r.typ)
	L._kreuzungen()
	var st=_flaechen()
	print("T flaechen ",st.size()," leicht ",L.leicht)
	L.STADT_STUECKE=st
	L.strassen_modus=true
	for r in ROH:_fahrbahn(r)
	L.strassen_modus=false
	var n_haus=0;var n_block=0
	for pc in st:
		var A=abs(L._flaeche2(pc))
		L._platte(pc,-1.6,L.KB,L.M.pflaster,L.M.stein)
		L._spitze_ecke_merken(pc)
		if A<150:continue
		n_block+=1;n_haus+=L._block(pc)
		if n_block%6==0:
			L._fertig(false)
			if n_block%24==0:print("T block ",n_block," haeuser ",n_haus," mem ",OS.get_static_memory_usage()/1048576)
	BERICHT["bloecke"]=n_block;BERICHT["haeuser"]=n_haus;BERICHT["kreuzungen"]=L.JN.size();BERICHT["strassen"]=ROH.size()
	L.strassen_modus=true;L._markierungen();L.strassen_modus=false
	L._ampeln();L._strassenmoebel()
	L.strassen_modus=true;_bahn_bauen()
	if not AB.is_empty():
		L.HW=AB;L._autobahn()
		# Boden unter der Hochstraße (Parkstreifen/Grün), ohne die Fahrbahnen
		var unter=_abziehen(_baender(AB.P,AB.w+3.0),[])
		for r in ROH:unter=_abziehen(unter,_baender(r.P,r.w))
		for b in BAHN:unter=_abziehen(unter,_baender(b.P,5.0))
		for pc in unter:L._platte(pc,-0.6,0.03,L.M.gras,L.M.stein_d)
	if AB.is_empty():L.HW={"P":PackedVector2Array([Vector2.ZERO,Vector2(1,0)]),"S":PackedFloat32Array([0.0,1.0]),"w":9.0}
	L._parken()
	L.strassen_modus=false
	L._fertig()
	for s in SCHRANKEN:W.add_child(s)

# Fahrbahn als Streifen entlang der Mittellinie (2 Dreiecke je 4 m statt feiner Zerlegung)
func _fahrbahn(r):
	var P:PackedVector2Array=r.P;var w:float=r.w+0.05;var n=P.size()
	var so=L._st(L.M.asphalt,true);var a_k=L.koll_an;L.koll_an=true
	var N=[]
	for i in n:N.append(L._rn((P[min(i+1,n-1)]-P[max(i-1,0)]).normalized()))
	for i in n-1:
		var a=P[i]-N[i]*w;var b=P[i]+N[i]*w;var c=P[i+1]+N[i+1]*w;var d=P[i+1]-N[i+1]*w
		var y=0.015
		L._tri(so,Vector3(a.x,y,a.y),Vector3(b.x,y,b.y),Vector3(c.x,y,c.y),Vector3.UP);L._tri(so,Vector3(a.x,y,a.y),Vector3(c.x,y,c.y),Vector3(d.x,y,d.y),Vector3.UP)
	# runde Enden (Wendekreis / Einmündung)
	for e in [0,n-1]:
		var c0=P[e]
		for k in 8:
			var a0=TAU*k/8.0;var a1=TAU*(k+1)/8.0
			L._tri(so,Vector3(c0.x,0.015,c0.y),Vector3(c0.x+cos(a0)*w,0.015,c0.y+sin(a0)*w),Vector3(c0.x+cos(a1)*w,0.015,c0.y+sin(a1)*w),Vector3.UP)
	L.koll_an=a_k

# ---------------- Bahn ----------------
var M_SCHOTTER;var M_SCHWELLE;var M_SCHIENE;var M_ROTWEISS
func _bahn_bauen():
	M_SCHOTTER=L._toon(Color(0.52,0.48,0.44));M_SCHWELLE=L._toon(Color(0.38,0.28,0.2));M_SCHIENE=L._toon(Color(0.55,0.56,0.6),0.3)
	for b in BAHN:
		var P:PackedVector2Array=b.P;var S:PackedFloat32Array=b.S;var Lg=S[S.size()-1]
		# Schotterbett ohne die Straßen
		var bett=_baender(P,2.6)
		for r in ROH:bett=_abziehen(bett,_baender(r.P,r.w+0.3))
		for pc in bett:L._platte(pc,-0.4,0.12,M_SCHOTTER,M_SCHOTTER)
		# Grünstreifen + Zaun am Rand des Gleiskorridors
		var korr=_abziehen(_baender(P,5.0),[])
		korr=_abziehen(korr,_baender(P,2.6))
		for r in ROH:korr=_abziehen(korr,_baender(r.P,r.w+0.3))
		for pc in korr:L._platte(pc,-0.4,0.06,L.M.gras,L.M.stein_d)
		var s=0.0
		while s<Lg:
			var bb=L._bei_s(P,S,s);var p:Vector2=bb[0];var t:Vector2=bb[1];var rn=L._rn(t)
			var im_uebergang=false
			for u in UEBERGANG:
				if u.p.distance_to(p)<u.r.w+1.6:im_uebergang=true
			var yaw=atan2(t.x,t.y)
			if not im_uebergang:
				L.box(M_SCHWELLE,Vector3(p.x,0.16,p.y),Vector3(2.5,0.09,0.24),Basis(Vector3.UP,yaw+PI*0.5),0.0)
			s+=0.75
		# Schienen: durchgehend (im Übergang bündig mit der Fahrbahn)
		for sd in [-0.72,0.72]:
			for i in P.size()-1:
				var a=P[i];var c=P[i+1];var t=(c-a).normalized();var rn=L._rn(t)
				var m=(a+c)*0.5+rn*sd;var im=false
				for u in UEBERGANG:
					if u.p.distance_to(m)<u.r.w+1.6:im=true
				var y=0.045 if im else 0.27
				L.box(M_SCHIENE,Vector3(m.x,y,m.y),Vector3(0.09,0.12,a.distance_to(c)+0.02),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
		# Zaun entlang des Korridors (nicht an Übergängen)
		for sd in [-4.8,4.8]:
			var s2=0.0
			while s2<Lg:
				var bb=L._bei_s(P,S,s2);var p:Vector2=bb[0];var t:Vector2=bb[1];var q=p+L._rn(t)*sd
				var frei=true
				for r in ROH:
					var ns=_naechst_r(q,r)
					if ns<r.w+2.5:frei=false
				if frei:
					L.zyl(L.M.metall,Vector3(q.x,0,q.y),Vector3(q.x,1.5,q.y),0.04,1.0)
					var q2=q+t*3.0
					var frei2=true
					for r in ROH:
						if _naechst_r(q2,r)<r.w+2.5:frei2=false
					if frei2:
						for hy in [0.5,1.0,1.45]:L.box(L.M.metall,Vector3((q.x+q2.x)*0.5,hy,(q.y+q2.y)*0.5),Vector3(0.03,0.03,3.0),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
				s2+=3.0
	for u in UEBERGANG:_uebergang(u)
func _naechst_r(p:Vector2,r)->float:
	var P:PackedVector2Array=r.P;var bd=INF
	for i in P.size()-1:bd=min(bd,Geometry2D.get_closest_point_to_segment(p,P[i],P[i+1]).distance_to(p))
	return bd
func _uebergang(u):
	var r=u.r;var tr:Vector2=u.tr;var rn=L._rn(tr);var tg:Vector2=u.t
	# Gummiplatten zwischen den Schienen (dunkler Streifen über die Fahrbahn)
	L.box(L.M.dunkel,Vector3(u.p.x,0.025,u.p.y),Vector3(2.2,0.02,(r.w*2.0+0.6)/max(abs(tg.dot(L._rn(tr))),0.4)),Basis(Vector3.UP,atan2(tg.x,tg.y)),0.0)
	# je Fahrtrichtung: Andreaskreuz + Blinklicht rechts, Schranke über die rechte Fahrbahnhälfte
	for dir in [-1,1]:
		var t=tr*dir;var rr=L._rn(t)
		# Abstand vor dem Gleis entlang der Straße
		var cosw=abs(t.dot(L._rn(tg)))
		var vor=(4.2)/max(cosw,0.35)
		var fuss=u.p-t*vor+rr*(r.w+1.0)
		var f3=Vector3(fuss.x,L.KB,fuss.y)
		L.zyl(L.M.weiss,f3,f3+Vector3(0,3.2,0),0.07,1.2)
		var bk=Basis(Vector3.UP,atan2(t.x,t.y)+PI)
		for a in [PI*0.25,-PI*0.25]:
			L.box(L.M.rot,f3+Vector3(0,2.9,0)-Vector3(t.x,0,t.y)*0.09,Vector3(1.1,0.16,0.03),bk*Basis(Vector3.BACK,a),0.02)
		var lb=Vector3(f3.x,2.3,f3.z)-Vector3(t.x,0,t.y)*0.12
		L.box(L.M.dunkel,lb,Vector3(0.75,0.32,0.12),bk,0.02)
		for sx in [-0.2,0.2]:L.kugel(L.M.rot_l,lb+bk*Vector3(sx,0,-0.08),Vector3(0.11,0.11,0.05),1.0)
		# Schrankenantrieb + Baum (eigener Knoten -> im Spiel beweglich)
		var an=fuss+rr*0.6
		L.box(L.M.gelb,Vector3(an.x,0.75,an.y),Vector3(0.5,1.2,0.5),bk,0.03)
		var arm=Node3D.new();arm.name="Schranke";arm.position=Vector3(an.x,L.FY(an.x,an.y)+1.15,an.y)
		arm.rotation.y=atan2(-rr.x,-rr.y)
		var len_=r.w+1.0
		for k in int(len_/0.8):
			var mi=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=Vector3(0.12,0.12,0.8);mi.mesh=bm
			mi.material_override=L.M.rot if k%2==0 else L.M.weiss;mi.position=Vector3(0,0,k*0.8+0.4);arm.add_child(mi)
		SCHRANKEN.append(arm)

# ---------------- Prüfung ----------------
func _pruefen():
	# lose Enden im fertigen Netz
	var lose=0;var punkte=[]
	for i in ROH.size():
		for e in [ROH[i].P[0],ROH[i].P[ROH[i].P.size()-1]]:
			if _am_rand(e):continue
			var ns=_naechst(e,i)
			if ns[2]<0 or ns[0]>ROH[ns[2]].w:lose+=1;punkte.append(e)
	BERICHT["lose_enden"]=lose
	# Höhensprung an Kreuzungen: beide Straßen fragen dasselbe Feld -> 0
	var sprung=0.0
	for k in L.JN:
		var a=L.FY(k.p.x,k.p.y);sprung=max(sprung,abs(a-L.FY(k.p.x+0.01,k.p.y)))
	BERICHT["max_hoehensprung_kreuzung_m"]=snapped(sprung,0.001)
	# Häuser: Unterkante vs. Boden
	BERICHT["gleisenden_in_der_probe"]=0
	for b in BAHN:
		for e in [b.P[0],b.P[b.P.size()-1]]:
			if R_lok().grow(10).has_point(e):BERICHT["gleisenden_in_der_probe"]+=1
	print("BERICHT ",JSON.stringify(BERICHT))
	var f=FileAccess.open(OUT+"bericht.json",FileAccess.WRITE);f.store_string(JSON.stringify(BERICHT,"  "));f.close()
	LOSE=punkte
var LOSE:=[]

# ---------------- Bilder ----------------
func _cam(pos:Vector3,ziel:Vector3,fov:=60.0)->Camera3D:
	var c=Camera3D.new();W.add_child(c);c.fov=fov;c.far=4000.0
	c.look_at_from_position(pos,ziel);c.current=true;return c
func _bild(n:String):
	for k in 4:await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT+n+".png");print("BILD ",n)
func Y(p:Vector2)->float:return L.FY(p.x,p.y)
func _bilder():
	root.size=Vector2i(1600,900)
	SUN.directional_shadow_max_distance=900.0
	var c=_cam(Vector3(-150,420,520),Vector3(0,0,0),55.0)
	await _bild("01_ueberblick")
	c.queue_free()
	# Draufsicht (Karte)
	var t=Camera3D.new();W.add_child(t);t.projection=Camera3D.PROJECTION_ORTHOGONAL;t.size=REG.size.y+20;t.far=3000
	t.look_at_from_position(Vector3(0,900,0.01),Vector3.ZERO,Vector3.FORWARD);t.current=true
	await _bild("02_draufsicht");t.queue_free()
	SUN.directional_shadow_max_distance=160.0
	# Bahnübergang nah
	if UEBERGANG.size()>0:
		var u=UEBERGANG[0];var tr:Vector2=u.tr
		var p:Vector2=u.p-tr*24.0+L._rn(tr)*2.6
		c=_cam(Vector3(p.x,Y(p)+2.2,p.y),Vector3(u.p.x,Y(u.p)+1.0,u.p.y))
		await _bild("03_bahnuebergang");c.queue_free()
		# Schranke unten
		for s in SCHRANKEN:s.rotation.x=0.0
		for s in SCHRANKEN:
			s.rotation=Vector3(0,s.rotation.y,0)
		p=u.p+L._rn(u.t)*14.0+tr*10.0
		c=_cam(Vector3(p.x,Y(p)+6.0,p.y),Vector3(u.p.x,Y(u.p),u.p.y))
		await _bild("04_bahnuebergang_oben");c.queue_free()
	# Straßenszenen: an drei Kreuzungen, Fahrerhöhe
	var picks=[]
	for k in L.JN:
		if k.a.typ in ["strasse","allee"] and R_lok().grow(-120).has_point(k.p):picks.append(k)
	for i in min(4,picks.size()):
		var k=picks[(i*picks.size())/4]
		var r=k.a;var s0=L._s_von(r.P,r.S,k.p);var b=L._bei_s(r.P,r.S,max(s0-45.0,1.0))
		var p:Vector2=b[0]+L._rn(b[1])*1.8
		c=_cam(Vector3(p.x,Y(p)+2.4,p.y),Vector3(k.p.x,Y(k.p)+1.5,k.p.y),65.0)
		await _bild("1%d_strasse"%i);c.queue_free()
	# Hochstraße von unten
	if not AB.is_empty():
		var b=L._bei_s(AB.P,AB.S,AB.S[AB.S.size()-1]*0.5);var p:Vector2=b[0]+L._rn(b[1])*30.0
		c=_cam(Vector3(p.x,Y(p)+2.0,p.y),Vector3(b[0].x,Y(b[0])+6.0,b[0].y),70.0)
		await _bild("20_hochstrasse");c.queue_free()
