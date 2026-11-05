extends SceneTree
# Comic-Welt vorab bauen: Insel-Gelände (Toon-Farben aus gelaende.bin), Wasser, Comic-Stadt (scripts/comic/stadt_lib.gd),
# Kollision (Höhenfeld + Stadt-Dreiecke + Pfosten), Straßen im Format der alten Welt, Parkplätze, Läden.
# Ergebnis: assets/cache/comic/welt.scn + daten.bin
const ZIEL:="res://assets/cache/comic/"
const CX:=-200.0
const CZ:=500.0
const H0:=7.0
const RX:=470.0
const RZ:=300.0
const DS:=4.0
var W:Node3D

func _init():
	await process_frame
	var t0=Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ZIEL))
	W=Node3D.new();W.name="WeltComic";W.set_script(load("res://scripts/comic/welt_comic.gd"));root.add_child(W)
	# ---- Stadt ----
	var stadt=Node3D.new();stadt.name="Stadt";W.add_child(stadt);stadt.position=Vector3(CX,H0,CZ)
	var L=load("res://scripts/comic/stadt_lib.gd").new()
	L.init_lib(stadt);L.spiel_modus=true;L.kachel=80.0
	# Handy: Kugeln/Zylinder mit weniger Segmenten, kürzere Sichtweite
	L.SPH.radial_segments=9;L.SPH.rings=5;L.CYL.radial_segments=8;L.weit_detail=200.0;L.weit_ink=80.0
	L._stadt();L._fertig()
	print("STADT ",Time.get_ticks_msec()-t0," ms, Parkplätze ",L.PARKEN.size())
	# ---- Gelände ----
	var G0=load("res://scripts/welt_gelaende.gd").new()
	var nx=G0.rx;var nz=G0.rz;var X0=G0.X0;var Z0=G0.Z0;var ST=G0.STEP
	var H=PackedFloat32Array(G0._nh)
	var TUNP:PackedVector2Array=L.TUN.P;var TUNH:PackedFloat32Array=L.TUN.H
	for k in nz:
		for i in nx:
			var x=X0+i*ST-CX;var z=Z0+k*ST-CZ;var j=k*nx+i
			var dx=max(abs(x)-RX,0.0);var dz=max(abs(z)-RZ,0.0);var d=sqrt(dx*dx+dz*dz)
			if abs(x)<RX-0.1 and abs(z)<RZ-0.1:H[j]=H0+L.FY(x,z)-1.6
			elif d<0.1:H[j]=H0+L.KB
			else:H[j]=lerp(H0+L.KB,H[j],smoothstep(0.0,260.0,d))
	# unter dem offenen Tunneltrog absenken
	for t in TUNP.size():
		if TUNH[t]>-0.3:continue
		var p=TUNP[t]
		for k in range(int((p.y+CZ-12-Z0)/ST),int((p.y+CZ+12-Z0)/ST)+1):
			for i in range(int((p.x+CX-12-X0)/ST),int((p.x+CX+12-X0)/ST)+1):
				var q=Vector2(X0+i*ST-CX,Z0+k*ST-CZ)
				if q.distance_to(p)<11.0:H[k*nx+i]=min(H[k*nx+i],H0+TUNH[t]-1.2)
	_gelaende(G0,H,nx,nz,X0,Z0,ST)
	_wasser()
	print("GELAENDE ",Time.get_ticks_msec()-t0," ms")
	# ---- Kollision ----
	var kb=StaticBody3D.new();kb.name="Kollision";W.add_child(kb)
	var hm=HeightMapShape3D.new();hm.map_width=nx;hm.map_depth=nz
	var hd=PackedFloat32Array();hd.resize(nx*nz)
	for j in nx*nz:hd[j]=H[j]/ST
	hm.map_data=hd
	var cs=CollisionShape3D.new();cs.shape=hm;kb.add_child(cs)
	cs.scale=Vector3.ONE*ST;cs.position=Vector3(X0+(nx-1)*ST*0.5,0,Z0+(nz-1)*ST*0.5)
	var sk=StaticBody3D.new();sk.name="KollisionStadt";stadt.add_child(sk)
	var F=PackedVector3Array(L.KOLL_N)
	for v in L.KOLL_F:F.append(Vector3(v.x,v.y+L.FY(v.x,v.z),v.z))
	var stueck=60000*3;var a=0
	while a<F.size():
		var cp=ConcavePolygonShape3D.new();cp.backface_collision=true;cp.set_faces(F.slice(a,min(a+stueck,F.size())))
		var c2=CollisionShape3D.new();c2.shape=cp;sk.add_child(c2);a+=stueck
	for pf in L.PFOSTEN:
		var cy=CylinderShape3D.new();cy.radius=pf[1];cy.height=pf[2]
		var c3=CollisionShape3D.new();c3.shape=cy;sk.add_child(c3)
		c3.position=Vector3(pf[0].x,pf[0].y+L.FY(pf[0].x,pf[0].z)+pf[2]*0.5,pf[0].z)
	# Autobahn-Enden: Absperrung (Ausbau folgt)
	for e in [0,L.HW.P.size()-1]:
		var p:Vector2=L.HW.P[e];var t:Vector2=(L.HW.P[1]-L.HW.P[0] if e==0 else L.HW.P[e]-L.HW.P[e-1]).normalized()
		var bas=Basis(Vector3.UP,atan2(t.x,t.y))
		var bx=BoxShape3D.new();bx.size=Vector3(L.HW.w*2+2,3.0,1.0)
		var c4=CollisionShape3D.new();c4.shape=bx;sk.add_child(c4);c4.transform=Transform3D(bas,Vector3(p.x,L.H_AB+1.5,p.y))
		var mi=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=bx.size;mi.mesh=bm;stadt.add_child(mi);mi.transform=c4.transform
		var mt=StandardMaterial3D.new();mt.albedo_color=Color(0.95,0.75,0.15);mt.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;mi.material_override=mt
		var lb=Label3D.new();lb.text="BAUSTELLE\nAusbau folgt";lb.font_size=96;lb.pixel_size=0.012;lb.modulate=Color(0.1,0.1,0.1);lb.outline_size=0
		stadt.add_child(lb);lb.transform=Transform3D(bas.rotated(Vector3.UP,PI if e==0 else 0.0),Vector3(p.x,L.H_AB+1.6,p.y)-Vector3(t.x,0,t.y)*(0.55 if e!=0 else -0.55))
	print("KOLLISION Dreiecke ",F.size()/3," Pfosten ",L.PFOSTEN.size())
	# ---- Straßen (Format der alten Welt, Weltkoordinaten) ----
	var off=Vector2(CX,CZ)
	var roads=[];var idx={}
	var neu=func(name:String,typ:String,P:PackedVector2Array,hf:Callable,w:float,sw:float,med:float,tunnel:=false)->int:
		var Ls=0.0;var acc=PackedFloat32Array([0.0])
		for i in range(1,P.size()):Ls+=P[i].distance_to(P[i-1]);acc.append(Ls)
		var n=max(2,int(Ls/DS)+1)
		var Q=PackedVector2Array();var Hh=PackedFloat32Array();var T=PackedVector2Array();var tf=[];var el=[]
		var j=1
		for q in n:
			var s=min(q*DS,Ls)
			while j<P.size()-1 and acc[j]<s:j+=1
			var u=clamp((s-acc[j-1])/max(acc[j]-acc[j-1],1e-4),0.0,1.0)
			var pp=P[j-1].lerp(P[j],u)
			Q.append(pp+off);Hh.append(H0+hf.call(pp,s));T.append((P[j]-P[j-1]).normalized())
			tf.append(tunnel and hf.call(pp,s)<-6.5);el.append(false)
		var lane_x=w*0.36 if (sw>0.0 and typ in ["strasse","allee"]) else -1.0
		roads.append({"lane_x":lane_x,"name":name,"typ":typ,"P":Q,"h":Hh,"T":T,"w":w,"sw":sw,"med":med,"tunnel_flags":tf,"elev":el,"lanes":1,"wear":0.2,"closed":false})
		return roads.size()-1
	var fy=func(pp:Vector2,_s):return L.FY(pp.x,pp.y)+0.015
	for r in L.R:
		if r.typ=="tunnelrampe":continue
		var typ={"einbahn":"strasse","rampe":"rampe"}.get(r.typ,r.typ)
		var sw=0.0 if r.aussen else L.SWB
		idx[r]=neu.call(r.n,typ,r.P,fy,r.w,sw,0.2 if r.typ=="allee" else 0.0)
	var hw=L.HW
	neu.call("Autobahn","autobahn",hw.P,func(_p,_s):return L.H_AB+0.01,hw.w,0.0,0.9)
	for rp in L.RAMPEN:
		var Pr:PackedVector2Array=rp.P;var Sr:PackedFloat32Array=rp.S;var Hr:PackedFloat32Array=rp.H
		neu.call(rp.n,"rampe",Pr,func(pp,s):return _interp(Sr,Hr,s)+L.FY(pp.x,pp.y)+0.01,rp.w,0.0,0.0)
	var TS:PackedFloat32Array=L.TUN.S
	neu.call("Stadttunnel","land",TUNP,func(_p,s):return _interp(TS,TUNH,s)+0.01,5.0,0.0,0.0,true)
	# Höhen der Straßenpunkte an der wirklich gebauten Fahrbahn messen (Hügel, Rampen, Tunnel)
	for k in 3:await physics_frame
	var raum=W.get_world_3d().direct_space_state;var korr=0
	for r in roads:
		var Hh:PackedFloat32Array=r.h
		for i in Hh.size():
			var q:Vector2=r.P[i]
			var hit=raum.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x,Hh[i]+1.5,q.y),Vector3(q.x,Hh[i]-1.5,q.y)))
			if hit and hit.normal.y>0.8 and abs(hit.position.y-Hh[i])>0.03 and abs(hit.position.y-Hh[i])<0.8:Hh[i]=hit.position.y+0.01;korr+=1
		r.h=Hh
	print("HOEHEN korrigiert ",korr)
	var junctions=[]
	for k in L.JN:
		if idx.has(k.a) and idx.has(k.b):
			junctions.append({"p":k.p+off,"h":H0+L.FY(k.p.x,k.p.y),"r":k.r,"a":idx[k.a],"b":idx[k.b],"rail":false})
	# ---- Parkplätze, Läden ----
	var parken=[]
	var var_={"c_trabant":["c_trabant_gruen","c_trabant_blau","c_trabant_beige","c_trabant_rot"],"c_wartburg":["c_wartburg_beige","c_wartburg_blau","c_wartburg_gruen"],
		"c_sport":["c_sport_rot","c_sport_gelb","c_sport_schwarz"],"c_jdm":["c_jdm_weiss","c_jdm_blau","c_jdm_rot"],"c_kompakt":["c_kompakt_rot","c_kompakt_weiss","c_kompakt_schwarz"],
		"c_e30":["c_e30_gruen","c_e30_silber","c_e30_schwarz"],"c_luxus":["c_luxus_schwarz","c_luxus_silber"],"c_muscle":["c_muscle_orange","c_muscle_schwarz"],"c_suv":["c_suv_grau","c_suv_gruen"]}
	var rr=RandomNumberGenerator.new();rr.seed=5
	for e in L.PARKEN:
		var k:String=e[0];var tf:Transform3D=e[1]
		if var_.has(k):k=var_[k][rr.randi()%var_[k].size()]
		var o=tf.origin;o.y+=L.FY(o.x,o.z)+H0+0.2;o.x+=CX;o.z+=CZ
		parken.append([k,Transform3D(tf.basis,o)])
	var st:Array=L.SHOW.start
	var sp:Vector3=st[0]
	var shops=[{"typ":"zuhause","c":Vector2(sp.x,sp.z)+off,"y":H0+L.FY(sp.x,sp.z)+L.KB,"yaw":st[1],"w":4.0,"d":-7.0}]
	var ladenorte=[["werkstatt",0.3],["waffen",0.62],["kleider",0.8]]
	for lo in ladenorte:
		for r in L.R:
			if r.n=="ew2":
				var b=L._bei_s(r.P,r.S,r.S[r.S.size()-1]*lo[1]);var p:Vector2=b[0];var n:Vector2=L._rn(b[1])
				var q=p+n*(r.w+L.SWB-0.6)
				# Werkstatt: Einfahrtszone auf der Parkspur vor dem Laden (d so gewählt, dass die Zone dort liegt)
				shops.append({"typ":lo[0],"c":q+off,"y":H0+L.FY(q.x,q.y)+L.KB,"yaw":atan2(-n.x,-n.y),"w":4.0,"d":25.0 if lo[0]=="werkstatt" else -3.0})
				if lo[0]=="werkstatt":
					var zp=q+off-n*6.5
					parken=parken.filter(func(e):return Vector2(e[1].origin.x,e[1].origin.z).distance_to(zp)>16.0)
	var daten={"H":H,"nx":nx,"nz":nz,"X0":X0,"Z0":Z0,"STEP":ST,"roads":roads,"junctions":junctions,"parken":parken,"shops":shops,
		"rect":Rect2(Vector2(CX-RX,CZ-RZ),Vector2(RX*2,RZ*2))}
	var f=FileAccess.open(ZIEL+"daten.bin",FileAccess.WRITE);f.store_var(daten,false);f.close()
	# ---- speichern ----
	_owner(W,W)
	var ps=PackedScene.new();var e1=ps.pack(W)
	var e2=ResourceSaver.save(ps,ZIEL+"welt.scn",ResourceSaver.FLAG_COMPRESS)
	print("GESPEICHERT ",error_string(e1)," ",error_string(e2)," Straßen ",roads.size()," Kreuzungen ",junctions.size()," Parkplätze ",parken.size()," ",(Time.get_ticks_msec()-t0)/1000.0," s")
	quit()

static func _interp(S:PackedFloat32Array,H:PackedFloat32Array,s:float)->float:
	var i=clampi(S.bsearch(s),1,S.size()-1)
	return lerp(H[i-1],H[i],clamp((s-S[i-1])/max(S[i]-S[i-1],1e-4),0.0,1.0))
func _owner(n:Node,o:Node):
	for c in n.get_children():c.owner=o;_owner(c,o)

const C_GRAS:=Color(0.5,0.78,0.34)
const C_WALD:=Color(0.3,0.58,0.27)
const C_SAND:=Color(0.95,0.82,0.52)
const C_FELS:=Color(0.62,0.55,0.47)
const C_TROCKEN:=Color(0.84,0.74,0.44)
const C_STRAND:=Color(0.96,0.88,0.64)
const C_SCHNEE:=Color(0.95,0.96,0.98)
func _farbe(G0,i:int,k:int,h:float)->Color:
	var j=(k*G0.rx+i)*4;var bo=G0._bo
	var w=[bo[j]/255.0,bo[j+1]/255.0,bo[j+2]/255.0,bo[j+3]/255.0]
	w.append(max(0.0,1.0-w[0]-w[1]-w[2]-w[3]))
	var best=0
	for q in 5:if w[q]>w[best]:best=q
	var c=[C_GRAS,C_WALD,C_SAND,C_FELS,C_TROCKEN][best]
	if h>620.0:c=C_SCHNEE
	elif h<2.2:c=C_STRAND
	return c
func _gelaende(G0,H:PackedFloat32Array,nx:int,nz:int,X0:float,Z0:float,ST:float):
	var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;mat.specular_mode=BaseMaterial3D.SPECULAR_DISABLED;mat.roughness=1.0
	var CH=48
	var n_ch=0
	for k0 in range(0,nz-1,CH):
		for i0 in range(0,nx-1,CH):
			var k1=min(k0+CH,nz-1);var i1=min(i0+CH,nx-1)
			var hoch=-INF
			for k in range(k0,k1+1,4):
				for i in range(i0,i1+1,4):hoch=max(hoch,H[k*nx+i])
			if hoch<-1.0:continue
			for stufe in [1,4]:
				var stt=SurfaceTool.new();stt.begin(Mesh.PRIMITIVE_TRIANGLES)
				var k=k0
				while k<k1:
					var kk=min(k+stufe,k1);var i=i0
					while i<i1:
						var ii=min(i+stufe,i1)
						var P=[[i,k],[ii,k],[ii,kk],[i,kk]]
						var V=[]
						for q in P:V.append(Vector3(X0+q[0]*ST,H[q[1]*nx+q[0]],Z0+q[1]*ST))
						var n1=(V[2]-V[0]).cross(V[1]-V[0]).normalized()
						if n1.y<0:n1=-n1
						for t in [[0,2,1],[0,3,2]]:
							for q in t:
								stt.set_color(_farbe(G0,P[q][0],P[q][1],V[q].y));stt.set_normal(n1);stt.add_vertex(V[q])
						i=ii
					k=kk
				var mi=MeshInstance3D.new();mi.mesh=stt.commit();mi.material_override=mat;mi.name="Gelaende_%d_%d_%d"%[i0,k0,stufe];W.add_child(mi)
				if stufe==1:mi.visibility_range_end=600.0
				else:mi.visibility_range_begin=580.0;mi.visibility_range_end=7000.0;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n_ch+=1
	print("GELAENDE Kacheln ",n_ch)
func _wasser():
	var mi=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(40000,40000);mi.mesh=pm;mi.name="Wasser";W.add_child(mi)
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.3,0.62,0.85);m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.specular_mode=BaseMaterial3D.SPECULAR_TOON;m.roughness=0.25
	mi.material_override=m;mi.position.y=0.0;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
