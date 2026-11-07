extends SceneTree
# Prototyp-Bilder: wie die Original-Viertel als Comic aussehen würden. Aufruf: -- ghetto docks ... (optional)
const OUT:="/home/claude/work/viertel/"
var L;var CA;var W:Node3D
var rng:=RandomNumberGenerator.new()
var KAM:=[]
const TAGS:=["RBG","KING","187","SKRT","YO!","DOPE","CREW","ZONE","OST","BOOM","GHETTO","KRIEG","ROST","NOFX"]
const SPRAY:=[Color(0.95,0.2,0.6),Color(0.2,0.8,0.95),Color(0.98,0.85,0.1),Color(0.4,0.95,0.3),Color(0.95,0.45,0.1),Color(0.6,0.3,0.95),Color(0.95,0.95,0.95)]

func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	W=Node3D.new();root.add_child(W)
	L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W);L._umgebung()
	for n in W.get_children():
		if n is DirectionalLight3D:n.directional_shadow_max_distance=170.0
	CA=load("res://scripts/comic/comic_autos.gd")
	rng.seed=7
	var V=[["ghetto",ghetto],["altstadt",altstadt],["downtown",downtown],["suedstadt",suedstadt],["docks",docks],["industrie",industrie],
		["strand",strand],["kowloon",kowloon],["stern",stern],["vorort",vorort],["sonnenhuegel",sonnenhuegel],["oststadt",oststadt],["flugplatz",flugplatz]]
	var nur=OS.get_cmdline_user_args()
	for i in V.size():
		if nur.size()>0 and not (V[i][0] in nur):continue
		V[i][1].call(Vector3(i*900.0,0,0))
	L._fertig()
	var vp=root.get_viewport();vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=60;cam.far=4000;W.add_child(cam);cam.current=true
	var cl=CanvasLayer.new();root.add_child(cl)
	var lb=Label.new();lb.position=Vector2(28,18);lb.add_theme_font_size_override("font_size",44)
	lb.add_theme_color_override("font_color",Color(1,0.92,0.3));lb.add_theme_color_override("font_outline_color",Color(0.08,0.05,0.06))
	lb.add_theme_constant_override("outline_size",14);cl.add_child(lb)
	for k in KAM:
		lb.text=k[1];cam.look_at_from_position(k[2],k[3])
		for f in 4:await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT+k[0]+".png");print("BILD ",k[0])
	quit()

# ---------------- Helfer ----------------
func T(c:Color,r:=0.8)->StandardMaterial3D:return L._toon(c*Color(0.8,0.8,0.8,1.0),r)
func licht(c:Color)->StandardMaterial3D:
	var m=T(c);m.emission_enabled=true;m.emission=c;m.emission_energy_multiplier=1.3;return m
func Y(yaw:float)->Basis:return Basis(Vector3.UP,yaw)
func B(m,c:Vector3,s:Vector3,yaw:=0.0,k:=0.035):L.box(m,c,s,Y(yaw),k)
func flaeche(m,c:Vector3,sx:float,sz:float,y:=0.0):L.box(m,Vector3(c.x,y-0.05,c.z),Vector3(sx,0.1,sz),Basis(),0.0)
func rich(d:Vector3)->Basis:
	var z=d.normalized();var x=Vector3.UP.cross(z)
	if x.length()<0.01:x=Vector3.RIGHT
	x=x.normalized();return Basis(x,z.cross(x),z)
func strasse(o:Vector3,lang:float,rw:=5.0,sw:=4.0,linie:=true,kaputt:=false):
	flaeche(L.M.asphalt,o,lang,rw*2)
	for s in [-1,1]:
		L.box(L.M.pflaster,o+Vector3(0,0.075,s*(rw+sw*0.5)),Vector3(lang,0.15,sw),Basis(),0.0)
		L.box(L.M.stein_d,o+Vector3(0,0.08,s*(rw+0.1)),Vector3(lang,0.16,0.2),Basis(),0.02)
	if linie:
		var x=-lang*0.5
		while x<lang*0.5:L.box(L.M.markierung,o+Vector3(x+1.5,0.006,0),Vector3(3,0.02,0.15),Basis(),0.0);x+=8.0
	if kaputt:
		var flick=T(Color(0.2,0.2,0.22))
		for k in int(lang/6):
			var p=o+Vector3(rng.randf_range(-lang*0.5,lang*0.5),0.004,rng.randf_range(-rw+0.5,rw-0.5))
			B(flick,p,Vector3(rng.randf_range(0.8,3.0),0.02,rng.randf_range(0.6,2.0)),rng.randf()*TAU,0.0)
			if k%3==0:B(L.M.linie,p+Vector3(1,0,0.5),Vector3(rng.randf_range(1.5,3.5),0.025,0.05),rng.randf()*TAU,0.0)
var AUTO_ELTERN:Node3D=null
func auto(kind:String,p:Vector3,yaw:float,farbe=null):
	var c=CA.bauen(kind,{},farbe);(AUTO_ELTERN if AUTO_ELTERN!=null else W).add_child(c);c.transform=Transform3D(Y(yaw),p)
func parker(o:Vector3,lang:float,rw:float,kinds:Array,dichte:=0.5):
	var x=-lang*0.5+6.0
	while x<lang*0.5-6.0:
		if rng.randf()<dichte:
			var s=1 if rng.randf()<0.5 else -1
			auto(kinds[rng.randi()%kinds.size()],o+Vector3(x,0,s*(rw-1.15)),PI*0.5 if s<0 else -PI*0.5)
		x+=rng.randf_range(6.5,9.0)
func laternen(o:Vector3,lang:float,abst:float,z:float):
	var x=-lang*0.5+5.0
	while x<lang*0.5:
		L._laterne(o+Vector3(x,0.15,z),Vector3(0,0,-sign(z)));L._laterne(o+Vector3(x+abst*0.5,0.15,-z),Vector3(0,0,sign(z)));x+=abst
# Graffiti: farbige Blasen + Schriftzug, auf eine Wand (aussen = Blickrichtung der Wand)
func graffiti(c:Vector3,aussen:Vector3,gr:=1.0):
	var r=Vector3.UP.cross(aussen).normalized();var b=Basis(r,Vector3.UP,aussen)
	var f1=SPRAY[rng.randi()%SPRAY.size()];var f2=SPRAY[rng.randi()%SPRAY.size()]
	var tag:String=TAGS[rng.randi()%TAGS.size()]
	var breite=gr*(0.55*tag.length()+0.6)
	L.mesh(T(f2),L.SPH,Transform3D(b*Basis().scaled(Vector3(breite,gr*1.25,0.03)),c+aussen*0.02),1.0)
	for k in 3:
		var q=c+r*rng.randf_range(-breite*0.4,breite*0.4)+Vector3(0,gr*rng.randf_range(-0.4,0.4),0)
		L.mesh(T(SPRAY[rng.randi()%SPRAY.size()]),L.SPH,Transform3D(b*Basis().scaled(Vector3(gr*0.5,gr*0.45,0.03)),q+aussen*0.025),1.0)
	for k in 2:  # Farbnasen
		var q=c+r*rng.randf_range(-breite*0.3,breite*0.3)-Vector3(0,gr*0.6,0)
		L.box(T(f2),q+aussen*0.03,Vector3(0.05,gr*rng.randf_range(0.3,0.7),0.01),b,0.0)
	L._schrift(tag,c+aussen*0.06,b,gr*0.0105,f1,Color(0.06,0.04,0.05),96)
func wellblech(c:Vector3,w:float,h:float,yaw:float,col:Color):
	var b=Y(yaw);L.box(T(col),c+Vector3(0,h*0.5,0),Vector3(w,h,0.06),b,0.03)
	var dk=T(col*0.72);var x=-w*0.5+0.12
	while x<w*0.5:L.box(dk,c+b*Vector3(x,h*0.5,0.05),Vector3(0.08,h,0.04),b,0.0);x+=0.26
	if rng.randf()<0.6:L.box(T(Color(0.55,0.3,0.16)),c+b*Vector3(rng.randf_range(-w*0.3,w*0.3),h*0.3,0.08),Vector3(rng.randf_range(0.6,1.4),h*0.5,0.02),b,0.0)
func huette(c:Vector3,w:float,d:float,h:float,yaw:float,col:Color):
	var b=Y(yaw)
	var dirs=[Vector3(0,0,1),Vector3(1,0,0),Vector3(0,0,-1),Vector3(-1,0,0)]
	for k in 4:
		var dir=b*dirs[k];var br=w if k%2==0 else d;var ti=d if k%2==0 else w
		wellblech(c+dir*(ti*0.5),br,h,atan2(dir.x,dir.z),col if k!=1 else col*Color(0.85,0.75,0.7))
	L.box(T(Color(0.52,0.33,0.22)),c+Vector3(0,h+0.15,0),Vector3(w+0.7,0.1,d+0.7),b*Basis(Vector3(1,0,0),0.12),0.03)
	L.box(L.M.dunkel,c+b*Vector3(0,1.0,d*0.5+0.07),Vector3(0.9,2.0,0.05),b,0.0)
func holzzaun(a:Vector3,e:Vector3,h:float,col:Color,kaputt:=0.15):
	var d=e-a;var Lg=d.length();var t=d/Lg;var b=Basis(t,Vector3.UP,t.cross(Vector3.UP))
	var m=T(col);var m2=T(col*0.8);var k=0.1
	L.box(m2,(a+e)*0.5+Vector3(0,h*0.7,0),Vector3(Lg,0.1,0.06),b,0.02)
	while k<Lg:
		if rng.randf()>kaputt:
			var hh=h*rng.randf_range(0.85,1.0);var kipp=rng.randf_range(-0.12,0.12) if rng.randf()<0.3 else 0.0
			L.box(m if rng.randf()<0.7 else m2,a+t*k+Vector3(0,hh*0.5,0),Vector3(0.14,hh,0.035),b*Basis(Vector3(0,0,1),kipp),0.015)
		k+=0.19
func garage(c:Vector3,yaw:float,kaputt:=true):
	var b=Y(yaw);var wand=L.M.ziegel[rng.randi()%L.M.ziegel.size()] if rng.randf()<0.5 else T(Color(0.7,0.68,0.62))
	L.box(wand,c+Vector3(0,1.4,0),Vector3(3.6,2.8,6.0),b,0.04)
	L.box(T(Color(0.32,0.3,0.3)),c+b*Vector3(0,2.88,0),Vector3(3.9,0.16,6.3),b*Basis(Vector3(1,0,0),-0.04),0.03)
	var tor=T([Color(0.55,0.58,0.6),Color(0.45,0.55,0.4),Color(0.6,0.45,0.3)][rng.randi()%3])
	var offen=rng.randf()<0.35 and kaputt
	L.box(L.M.dunkel,c+b*Vector3(0,1.15,3.01),Vector3(2.8,2.3,0.04),b,0.0)
	var torh=0.9 if offen else 2.3
	L.box(tor,c+b*Vector3(0,2.3-torh*0.5,3.03),Vector3(2.8,torh,0.06),b*Basis(Vector3(0,0,1),rng.randf_range(-0.05,0.05) if kaputt else 0.0),0.02)
	var y=2.3-0.2
	while y>2.3-torh+0.1:L.box(T(tor.albedo_color*0.75),c+b*Vector3(0,y,3.07),Vector3(2.75,0.04,0.03),b,0.0);y-=0.23
	if kaputt:
		L.box(T(Color(0.5,0.28,0.15)),c+b*Vector3(-0.6,0.5,3.08),Vector3(1.2,0.7,0.02),b,0.0)
		graffiti(c+b*Vector3(rng.randf_range(-0.4,0.4),1.4,3.1),b*Vector3(0,0,1),0.65)
		if offen:  # Gerümpel drin
			for k in 4:L.kugel(L.M.dunkel,c+b*Vector3(rng.randf_range(-1,1),0.3,rng.randf_range(0,2)),Vector3(0.35,0.3,0.35))
func reifen(p:Vector3,n:=3):
	for k in n:L.zyl(L.M.reifen,p+Vector3(0,k*0.24,0),p+Vector3(0,k*0.24+0.22,0),0.36,1.1)
func muellsack(p:Vector3):L.kugel(T(Color(0.12,0.12,0.14),0.3),p+Vector3(0,0.3,0),Vector3(0.38,0.32,0.36))
func mast(p:Vector3)->Vector3:
	L.zyl(T(Color(0.38,0.28,0.2)),p,p+Vector3(0,8.5,0),0.14,1.2)
	B(T(Color(0.38,0.28,0.2)),p+Vector3(0,8.0,0),Vector3(0.12,0.12,1.8),0.0,0.02)
	L.zyl(T(Color(0.4,0.42,0.45)),p+Vector3(0.2,6.8,0),p+Vector3(0.2,7.6,0),0.25,1.1)
	return p+Vector3(0,8.0,0)
func kabel(a:Vector3,e:Vector3,durch:=0.9):
	var n=6;var prev=a
	for k in range(1,n+1):
		var t=float(k)/n;var q=a.lerp(e,t)-Vector3(0,durch*4.0*t*(1.0-t),0)
		L.zyl(L.M.linie,prev,q,0.02,1.0);prev=q
func palme(p:Vector3,h:=8.0):
	var stamm=T(Color(0.6,0.45,0.3));var neig=Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()*rng.randf_range(0.6,1.6)
	var prev=p
	for k in 7:
		var t=(k+1)/7.0;var q=p+Vector3(0,h*t,0)+neig*t*t
		L.zyl(stamm if k%2==0 else T(Color(0.52,0.39,0.26)),prev,q,0.24-0.08*t,1.2);prev=q
	var gr=[T(Color(0.25,0.6,0.22)),T(Color(0.35,0.7,0.25))]
	for k in 9:
		var a=TAU*k/9.0+rng.randf()*0.3;var d=Vector3(cos(a),0,sin(a))
		var m1=prev+d*1.5+Vector3(0,0.45,0);var m2=prev+d*3.0+Vector3(0,-0.4,0);var m3=prev+d*3.9+Vector3(0,-1.4,0)
		L.box(gr[k%2],(prev+m1)*0.5,Vector3(0.75,0.06,(m1-prev).length()),rich(m1-prev),0.02)
		L.box(gr[k%2],(m1+m2)*0.5,Vector3(0.65,0.06,(m2-m1).length()),rich(m2-m1),0.02)
		L.box(gr[(k+1)%2],(m2+m3)*0.5,Vector3(0.4,0.06,(m3-m2).length()),rich(m3-m2),0.02)
	for k in 3:L.kugel(T(Color(0.4,0.3,0.15)),prev+Vector3(cos(k*2.1)*0.3,-0.3,sin(k*2.1)*0.3),Vector3(0.18,0.18,0.18))
func hecke(c:Vector3,s:Vector3):B(L.M.laub[2],c+Vector3(0,s.y*0.5,0),s,0.0,0.05)
# Satteldachhaus (Vorort): c = Mitte unten, Front zeigt nach yaw
func satteldach(c:Vector3,w:float,d:float,H:float,yaw:float,wand:Material,dachc:Color,neig:=2.4):
	var b=Y(yaw);var P=func(x,y,z):return c+b*Vector3(x,y,z)
	L.box(wand,c+Vector3(0,H*0.5,0),Vector3(w,H,d),b,0.04)
	var dm=T(dachc);var ue=0.5
	for sd in [-1,1]:
		var a0=P.call(-w*0.5-ue,H-0.2,sd*(d*0.5+ue));var a1=P.call(w*0.5+ue,H-0.2,sd*(d*0.5+ue))
		var g0=P.call(-w*0.5-ue,H+neig,0.0);var g1=P.call(w*0.5+ue,H+neig,0.0)
		var dy=Vector3(0,-0.2,0)
		L.hex(dm,[a0+dy,a1+dy,g1+dy,g0+dy,a0,a1,g1,g0],0.03)
	for sx in [-1,1]:
		var s=L._st(wand,true);var p0=P.call(sx*w*0.5,H,-d*0.5);var p1=P.call(sx*w*0.5,H,d*0.5);var p2=P.call(sx*w*0.5,H+neig-0.1,0.0)
		L._tri(s,p0,p1,p2,b*Vector3(sx,0,0))
func fenster(p:Vector3,b:Basis,w:=1.2,h:=1.4,glas=null):
	L.box(L.M.weiss,p,Vector3(w+0.2,h+0.2,0.08),b,0.02)
	L.box(glas if glas!=null else L.M.glas[0],p+b*Vector3(0,0,0.05),Vector3(w,h,0.04),b,0.0)
	L.box(L.M.weiss,p+b*Vector3(0,0,0.08),Vector3(0.07,h,0.03),b,0.0)
# Glasturm mit Fensterraster
func turm(c:Vector3,w:float,d:float,h:float,glas:Material,rahmen:Material,etage:=3.6,raster:=3.0):
	B(glas,c+Vector3(0,h*0.5,0),Vector3(w,h,d),0.0,0.06)
	for sd in [[Vector3(0,0,1),w,d],[Vector3(0,0,-1),w,d],[Vector3(1,0,0),d,w],[Vector3(-1,0,0),d,w]]:
		var n:Vector3=sd[0];var br:float=sd[1];var ti:float=sd[2];var r=Vector3.UP.cross(n)
		var b=Basis(r,Vector3.UP,n);var f=c+n*(ti*0.5+0.06)
		var x=-br*0.5
		while x<=br*0.5+0.01:L.box(rahmen,f+r*x+Vector3(0,h*0.5,0),Vector3(0.22,h,0.14),b,0.0);x+=raster
		var y=etage
		while y<h:L.box(rahmen,f+Vector3(0,y,0),Vector3(br,0.32,0.16),b,0.0);y+=etage
	B(rahmen,c+Vector3(0,h+0.6,0),Vector3(w+0.4,1.2,d+0.4),0.0,0.05)
	B(L.M.metall,c+Vector3(w*0.15,h+2.0,-d*0.1),Vector3(w*0.4,1.6,d*0.35),0.0,0.04)
# Plattenbau / Mietskaserne: Raster-Fenster
func block(c:Vector3,w:float,d:float,etagen:int,wand:Material,glas:Material,yaw:=0.0,balkon:=true,paneele:=[]):
	var eh=2.9;var H=etagen*eh+0.6;var b=Y(yaw)
	L.box(wand,c+Vector3(0,H*0.5,0),Vector3(w,H,d),b,0.05)
	L.box(L.M.stein_d,c+Vector3(0,H+0.15,0),Vector3(w+0.3,0.3,d+0.3),b,0.04)
	for sd in [1,-1]:
		var n=b*Vector3(0,0,sd);var r=Vector3.UP.cross(n);var fb=Basis(r,Vector3.UP,n);var f=c+n*(d*0.5)
		var nx=int(w/3.2)
		for e in etagen:
			for i in nx:
				var x=(i+0.5)*w/nx-w*0.5;var y=0.6+e*eh+1.45
				L.box(glas,f+r*x+Vector3(0,y,0.0)+n*0.03,Vector3(1.4,1.4,0.04),fb,0.0)
				L.box(L.M.stein_d,f+r*x+Vector3(0,y-0.78,0)+n*0.06,Vector3(1.6,0.1,0.12),fb,0.0)
				if balkon and e>0 and sd==1 and i%3==1:
					var pm=paneele[(e+i)%paneele.size()] if paneele.size()>0 else L.M.stein
					L.box(pm,f+r*x+Vector3(0,y-0.95,0)+n*0.75,Vector3(2.8,1.0,0.1),fb,0.025)
					L.box(L.M.stein_d,f+r*x+Vector3(0,y-1.45,0)+n*0.42,Vector3(2.8,0.14,0.85),fb,0.02)

# ================= GHETTO =================
func ghetto(o:Vector3):
	var lang=150.0
	flaeche(T(Color(0.46,0.47,0.26)),o,lang+80,140,-0.02)   # verdorrter Rasen überall
	strasse(o,lang,5.0,2.5,false,true)
	var farben=[Color(0.55,0.62,0.64),Color(0.74,0.68,0.54),Color(0.6,0.64,0.52),Color(0.7,0.56,0.5),Color(0.62,0.58,0.66),Color(0.78,0.74,0.62),Color(0.5,0.55,0.6)]
	var dreck=[T(Color(0.42,0.33,0.22)),T(Color(0.52,0.46,0.28)),T(Color(0.47,0.42,0.26))]
	var holz=T(Color(0.5,0.38,0.24));var holz2=T(Color(0.62,0.5,0.34))
	var kies=T(Color(0.42,0.4,0.37))
	# Gehweg: Risse und Unkraut
	for k in 60:
		var z=(rng.randf_range(5.2,7.4))*(1 if k%2==0 else -1);var p=o+Vector3(rng.randf_range(-lang*0.5,lang*0.5),0.155,z)
		if k%3==0:L.kugel(L.M.laub[rng.randi()%3],p,Vector3(0.25,0.18,0.25),1.0)
		else:B(L.M.linie,p,Vector3(rng.randf_range(0.6,1.6),0.01,0.04),rng.randf()*TAU,0.0)
	for s in [-1,1]:
		var aussen=Vector3(0,0,-s);var rechts=Vector3.UP.cross(aussen);var yaw=atan2(aussen.x,aussen.z)
		var hb=Basis(rechts,Vector3.UP,aussen)
		# Hintergasse mit Kies, Garagen zur Gasse hin
		flaeche(kies,o+Vector3(0,0,s*35.0),lang+20,6.0,0.02)
		var x=-lang*0.5+4.0
		while x<lang*0.5-8.0:
			var w=rng.randf_range(8.0,9.5)
			var front=o+Vector3(x+w*0.5,0.0,s*7.5)
			var f=front-aussen*4.5
			var P=func(px,py,pz):return f+rechts*px+Vector3.UP*py+aussen*pz
			if rng.randf()<0.75:
				L._holzhaus(front,w,aussen,farben[rng.randi()%farben.size()])
				# Vorgarten: toter Rasen, Dreck
				flaeche(dreck[rng.randi()%3],P.call(rng.randf_range(-1.5,1.5),0,2.4),w*rng.randf_range(0.5,0.95),3.2,0.085)
				# vernagelte Fenster
				for wx in [-w*0.32,w*0.32]:
					if rng.randf()<0.4:
						for q in 3:L.box(holz if q%2==0 else holz2,P.call(wx,1.6+q*0.45,0.14),Vector3(1.2,0.22,0.04),hb*Basis(Vector3(0,0,1),rng.randf_range(-0.15,0.15)),0.012)
						L.box(holz,P.call(wx,2.1,0.17),Vector3(1.5,0.2,0.04),hb*Basis(Vector3(0,0,1),0.75),0.012)
				for wx in [-w*0.3,0.0,w*0.3]:
					if rng.randf()<0.2:L.box(holz2,P.call(wx,4.4,0.1),Vector3(1.0,1.35,0.04),hb,0.012)
				# Schmutz unten an der Wand, abgeblätterte Farbe
				for sd in [-1,1]:
					var sb=Basis(rechts*sd,Vector3.UP,rechts*sd).orthonormalized() if false else Basis(-aussen*sd,Vector3.UP,rechts*sd)
					L.box(T(Color(0.32,0.28,0.22)),P.call(sd*(w*0.5+0.03),1.0,-4.5),Vector3(8.6,0.7,0.02),sb,0.0)
					for q in 3:L.box(T(Color(0.58,0.52,0.44)),P.call(sd*(w*0.5+0.04),rng.randf_range(2,5),rng.randf_range(-8,-1)),Vector3(rng.randf_range(0.4,1.1),rng.randf_range(0.3,0.7),0.02),sb,0.0)
					if rng.randf()<0.7:graffiti(P.call(sd*(w*0.5+0.06),rng.randf_range(1.8,2.6),rng.randf_range(-7,-2)),rechts*sd,rng.randf_range(0.6,0.9))
				if rng.randf()<0.55:L._sofa(P.call(-w*0.25,0.69,1.0),yaw)
				if rng.randf()<0.5:L._sofa(P.call(rng.randf_range(-2,2),0.0,3.3),yaw+rng.randf_range(-0.6,0.6))
				for q in rng.randi_range(0,3):muellsack(P.call(rng.randf_range(-w*0.4,w*0.4),0.05,rng.randf_range(2.5,4.2)))
				if rng.randf()<0.4:reifen(P.call(w*0.35,0.05,3.4),rng.randi_range(1,3))
			else:
				# leeres Grundstück: Blechhütte, Schrott, Autowrack
				flaeche(dreck[0],front-aussen*8.0,w+3,14,0.03)
				huette(front-aussen*rng.randf_range(6,10),rng.randf_range(4,5.5),rng.randf_range(3.5,4.5),2.4,yaw+rng.randf_range(-0.2,0.2),[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4),Color(0.45,0.55,0.6)][rng.randi()%3])
				reifen(front-aussen*3.0+rechts*2.5,rng.randi_range(2,4));reifen(front-aussen*3.8+rechts*3.4,2)
				L._sofa(front-aussen*4.0-rechts*2.5,yaw+0.4)
				auto("c_trabant_beige",front-aussen*12.0+rechts*1.0,yaw+1.2,Color(0.45,0.3,0.2))
			# Einfahrt neben dem Haus
			var gx=x+w+1.9
			flaeche(kies,o+Vector3(gx,0,s*(7.5+13.0)),3.2,26.0,0.025)
			if rng.randf()<0.3:auto(["c_wartburg_beige","c_muscle_schwarz","c_e30_schwarz","c_luxus_schwarz"][rng.randi()%4],o+Vector3(gx,0,s*(7.5+7.0)),yaw)
			# Garage / Blechschuppen hinten zur Gasse
			var gxx=x+w*0.5+rng.randf_range(-2,2)
			if rng.randf()<0.7:garage(o+Vector3(gxx,0,s*29.0),yaw+PI,true)
			else:huette(o+Vector3(gxx,0,s*29.8),4.0,3.5,2.3,yaw+PI,[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4)][rng.randi()%2])
			# hoher Bretterzaun zur Gasse, voller Tags
			for seg in [[x-0.2,gxx-2.0],[gxx+2.0,x+w+4.0]]:
				if seg[1]-seg[0]<0.8:continue
				var a0=o+Vector3(seg[0],0,s*31.9);var a1=o+Vector3(seg[1],0,s*31.9)
				holzzaun(a0,a1,2.0,[Color(0.55,0.45,0.33),Color(0.45,0.4,0.35),Color(0.6,0.55,0.48)][rng.randi()%3],0.08)
				if seg[1]-seg[0]>2.5:graffiti((a0+a1)*0.5+Vector3(0,1.05,0)+Vector3(0,0,s*0.06),Vector3(0,0,s),rng.randf_range(0.6,0.8))
			# Hinterhof: Schrottauto auf Steinen, Wäscheleine, Planschbecken
			var hof=o+Vector3(x+w*0.5,0,s*24.5)
			if rng.randf()<0.35:
				auto(["c_e30_gruen","c_wartburg_gruen","c_trabant_rot"][rng.randi()%3],hof+Vector3(rng.randf_range(-2,2),0.35,0),yaw+PI*0.5+rng.randf_range(-0.3,0.3),Color(0.5,0.35,0.25))
			elif rng.randf()<0.5:
				L.zyl(L.M.metall,hof+Vector3(-3,0,0),hof+Vector3(-3,2.0,0),0.04,1.2);L.zyl(L.M.metall,hof+Vector3(3,0,0),hof+Vector3(3,2.0,0),0.04,1.2)
				L.zyl(L.M.linie,hof+Vector3(-3,1.9,0),hof+Vector3(3,1.9,0),0.01,1.0)
				for q in 5:B(T(SPRAY[rng.randi()%SPRAY.size()]),hof+Vector3(-2.4+q*1.2,1.55,0),Vector3(0.8,0.7,0.03),0.0,0.012)
			else:
				L.zyl(T(Color(0.3,0.6,0.9)),hof,hof+Vector3(0,0.5,0),1.4,1.05);L.zyl(T(Color(0.45,0.7,0.6),0.2),hof+Vector3(0,0.42,0),hof+Vector3(0,0.46,0),1.3)
			# Zaun vorn: Maschendraht oder kaputter Holzzaun, mit Tags
			var za=o+Vector3(x-0.2,0.0,s*7.6);var ze=o+Vector3(x+w+0.2,0.0,s*7.6)
			if rng.randf()<0.45:L._zaun(za,ze,1.4)
			else:
				holzzaun(za,ze,1.25,[Color(0.62,0.5,0.36),Color(0.8,0.78,0.72),Color(0.5,0.42,0.34)][rng.randi()%3],0.28)
				if rng.randf()<0.8:graffiti((za+ze)*0.5+Vector3(rng.randf_range(-2,2),0.62,0)+aussen*0.04,aussen,0.45)
			# Seitenzaun hoch, Zaun hinten zur Gasse (Maschendraht mit Lücken)
			holzzaun(o+Vector3(x-0.2,0,s*7.8),o+Vector3(x-0.2,0,s*26.0),1.9,Color(0.55,0.45,0.33),0.12)
			if rng.randf()<0.7:L._zaun(o+Vector3(x-0.2,0,s*31.8),o+Vector3(x+w*0.5-2.4,0,s*31.8),1.8)
			x+=w+4.2
		# Gasse: Tonnen, Müll, Tags an den Garagentoren (oben in garage())
		for k in 10:
			var p=o+Vector3(rng.randf_range(-lang*0.45,lang*0.45),0,s*rng.randf_range(32.5,37))
			if k%3==0:L._container(p,rng.randf()*0.5,[Color(0.2,0.3,0.25),Color(0.25,0.25,0.3)][k%2])
			else:muellsack(p)
		L._sofa(o+Vector3(rng.randf_range(-40,40),0,s*36.5),rng.randf()*TAU)
		# gegenüberliegende Seite der Gasse: Bretterzäune, Schuppen
		var xx=-lang*0.5
		while xx<lang*0.5:
			var lg=rng.randf_range(8,14)
			if rng.randf()<0.3:huette(o+Vector3(xx+lg*0.5,0,s*40.5),lg-2,4.0,2.6,yaw,[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4),Color(0.5,0.42,0.35)][rng.randi()%3])
			else:
				holzzaun(o+Vector3(xx,0,s*38.1),o+Vector3(xx+lg,0,s*38.1),2.1,[Color(0.55,0.45,0.33),Color(0.45,0.4,0.35)][rng.randi()%2],0.06)
				graffiti(o+Vector3(xx+lg*0.5,1.1,s*38.04),Vector3(0,0,-s),rng.randf_range(0.6,0.85))
			xx+=lg
	# Strommasten mit durchhängenden Kabeln (+ Schuhe am Kabel)
	var prev=[null,null]
	var x=-lang*0.5+3.0
	while x<lang*0.5:
		for si in 2:
			var top=mast(o+Vector3(x,0,[-6.3,6.3][si]))
			if prev[si]!=null:kabel(prev[si],top);kabel(prev[si]+Vector3(0,0,0.7),top+Vector3(0,0,0.7),1.1)
			prev[si]=top
		x+=28.0
	for k in 2:
		var p=o+Vector3(-30+k*45,6.7,-6.3)
		for q in 2:L.zyl(L.M.linie,p+Vector3(q*0.3,0.4,0),p+Vector3(q*0.3,0,0),0.01,1.0);L.box(T([Color(0.95,0.95,0.95),Color(0.85,0.2,0.2)][k]),p+Vector3(q*0.3,-0.1,0.1),Vector3(0.14,0.15,0.32),Basis(),0.02)
	# Basketball-Platz mit Maschendraht
	var bp=o+Vector3(lang*0.5+16.0,0,-20.0)
	flaeche(L.M.asphalt,bp,16,26,0.02)
	for k in 4:
		var e0=[Vector3(-8,0,-13),Vector3(8,0,-13),Vector3(8,0,13),Vector3(-8,0,13)][k];var e1=[Vector3(8,0,-13),Vector3(8,0,13),Vector3(-8,0,13),Vector3(-8,0,-13)][k]
		L._zaun(bp+e0,bp+e1,3.0)
	L._korb(bp+Vector3(0,0,-11.5),Vector3(0,0,1))
	# Graffiti-Mauer an der Straße
	var mw=o+Vector3(lang*0.5-4.0,0,9.5)
	L.box(L.M.mauer,mw+Vector3(0,1.4,0),Vector3(14,2.8,0.4),Basis(),0.04)
	for k in 4:graffiti(mw+Vector3(-5.0+k*3.4,1.45,-0.22),Vector3(0,0,-1),0.95)
	# Ausgebranntes Auto am Rand
	auto("c_wartburg_blau",o+Vector3(-20,0,-3.9),PI*0.5+0.15,Color(0.18,0.15,0.13))
	for k in 8:muellsack(o+Vector3(rng.randf_range(-lang*0.45,lang*0.45),0.15,rng.randf_range(5.6,7.0)*(1 if rng.randf()<0.5 else -1)))
	for k in 5:
		var p=o+Vector3(rng.randf_range(-lang*0.4,lang*0.4),0.15,-6.6)
		L._container(p,rng.randf_range(0,1),Color(0.2,0.3,0.25))
	parker(o,lang,5.0,["c_muscle_orange","c_muscle_schwarz","c_wartburg_gruen","c_e30_gruen","c_luxus_schwarz","c_trabant_beige"],0.4)
	KAM.append(["ghetto_strasse","Ghetto",o+Vector3(-62,3.6,1.5),o+Vector3(-20,2.2,-4)])
	KAM.append(["ghetto_gasse","Ghetto – Hintergasse",o+Vector3(-66,2.6,-35.5),o+Vector3(-20,1.6,-30.5)])
	KAM.append(["ghetto_hoefe","Ghetto – von oben",o+Vector3(-30,22,-60),o+Vector3(0,0,-12)])

# ================= ALTSTADT =================
func altstadt(o:Vector3):
	var lang=140.0
	strasse(o,lang,4.0,4.0,false)
	for s in [-1,1]:
		var aussen=Vector3(0,0,-s);var x=-lang*0.5
		while x<lang*0.5-4.0:
			var w=rng.randf_range(9,14)
			L._haus(o+Vector3(x+w*0.5,0.15,s*8.0),w,14.0,aussen,{"stock":rng.randi_range(3,5),"laden":rng.randf()<0.7})
			x+=w
	# Kirche am Platzende
	var k=o+Vector3(lang*0.5+20,0,0)
	flaeche(L.M.pflaster,k+Vector3(-8,0,0),36,40,0.0)
	var ziegel=L.M.ziegel[3]
	B(ziegel,k+Vector3(14,7,0),Vector3(24,14,16),0.0)
	satteldach(k+Vector3(14,13.8,0),24,16,0.2,0.0,ziegel,Color(0.32,0.3,0.36),6.0)
	B(ziegel,k+Vector3(0,16,0),Vector3(7,32,7))
	var sp=k+Vector3(0,32,0);var d=3.7
	L.hex(T(Color(0.3,0.55,0.45)),[sp+Vector3(-d,0,-d),sp+Vector3(d,0,-d),sp+Vector3(d,0,d),sp+Vector3(-d,0,d),sp+Vector3(-0.05,16,-0.05),sp+Vector3(0.05,16,-0.05),sp+Vector3(0.05,16,0.05),sp+Vector3(-0.05,16,0.05)],0.05)
	L.zyl(L.M.weiss,k+Vector3(-3.55,25,0),k+Vector3(-3.6,25,0),1.6,1.1)
	L.box(L.M.linie,k+Vector3(-3.65,25.4,0),Vector3(0.05,1.1,0.12),Basis(),0.0)
	L.box(L.M.linie,k+Vector3(-3.65,25,0.35),Vector3(0.05,0.12,0.8),Basis(),0.0)
	L.box(L.M.dunkel,k+Vector3(-3.55,2.2,0),Vector3(0.2,4.4,2.6),Basis(),0.0)
	# Brunnen
	var br=o+Vector3(lang*0.5+3,0,0)
	L.zyl(L.M.stein,br,br+Vector3(0,0.7,0),3.0,1.04);L.zyl(T(Color(0.3,0.6,0.85),0.2),br+Vector3(0,0.7,0),br+Vector3(0,0.74,0),2.7)
	L.zyl(L.M.stein,br,br+Vector3(0,2.6,0),0.4,1.1);L.kugel(L.M.stein,br+Vector3(0,2.8,0),Vector3(0.6,0.4,0.6))
	var x=-lang*0.5+8
	while x<lang*0.5:
		L._laterne(o+Vector3(x,0.15,-4.6),Vector3(0,0,1));L._laterne(o+Vector3(x+10,0.15,4.6),Vector3(0,0,-1));x+=20
	parker(o,lang,4.0,["c_trabant_gruen","c_trabant_blau","c_wartburg_beige","c_kompakt_rot","c_taxi"],0.35)
	KAM.append(["altstadt","Altstadt",o+Vector3(-40,4,0.5),o+Vector3(30,6,0)])

# ================= DOWNTOWN =================
func downtown(o:Vector3):
	var lang=220.0
	flaeche(L.M.pflaster,o,lang+80,200,-0.01)
	strasse(o,lang,8.0,6.0,true)
	var glaeser=[L.M.glas[1],L.M.glas[3],L.M.glas[0]]
	var rahmen=[L.M.stein,L.M.metall,L.M.weiss,T(Color(0.75,0.65,0.45))]
	for s in [-1,1]:
		var x=-lang*0.5+10
		while x<lang*0.5:
			var w=rng.randf_range(20,30);var dd=rng.randf_range(20,28)
			var h=rng.randf_range(40,130)
			turm(o+Vector3(x+w*0.5,0,s*(14.0+dd*0.5)),w,dd,h,glaeser[rng.randi()%3],rahmen[rng.randi()%4],3.6,rng.randf_range(2.4,3.6))
			# Sockel mit Lobby
			B(L.M.stein_d,o+Vector3(x+w*0.5,2.5,s*(14.0+0.6)),Vector3(w,5,1.2),0.0,0.04)
			B(L.M.glas[2],o+Vector3(x+w*0.5,2.2,s*(14.0+1.25)),Vector3(w-2,3.6,0.1),0.0,0.0)
			x+=w+rng.randf_range(4,10)
	# Hintergrund-Skyline
	for k in 14:
		var p=o+Vector3(rng.randf_range(-200,200),0,rng.randf_range(60,200)*(1 if k%2==0 else -1))
		turm(p,rng.randf_range(18,30),rng.randf_range(18,30),rng.randf_range(60,190),glaeser[k%3],rahmen[k%4],4.0,4.0)
	for x in range(-100,110,14):L._baum(o+Vector3(x,0.15,-11.5));L._baum(o+Vector3(x+7,0.15,11.5))
	laternen(o,lang,24,10)
	parker(o,lang,8.0,["c_taxi","c_taxi","c_luxus_schwarz","c_luxus_silber","c_suv_grau","c_polizei","c_sport_rot"],0.45)
	KAM.append(["downtown","Downtown",o+Vector3(-95,3.5,-2),o+Vector3(0,40,0)])

# ================= SÜDSTADT =================
func suedstadt(o:Vector3):
	var lang=150.0
	strasse(o,lang,5.0,3.5,true,true)
	for s in [-1,1]:
		var aussen=Vector3(0,0,-s);var x=-lang*0.5
		while x<lang*0.5-4.0:
			var w=rng.randf_range(7,10)
			L._haus(o+Vector3(x+w*0.5,0.15,s*8.5),w,12.0,aussen,{"stock":rng.randi_range(2,3),"laden":rng.randf()<0.35})
			if rng.randf()<0.4:graffiti(o+Vector3(x+w*0.5+rng.randf_range(-2,2),1.6,s*8.43),aussen,0.7)
			# Treppe vor der Tür (Stoop)
			for k in 3:B(L.M.stein_d,o+Vector3(x+w*0.5+w*0.3,0.15+k*0.18+0.09,s*(8.5-0.3-k*0.0)-aussen.z*0.0+aussen.z*(1.0-k*0.3)),Vector3(1.6,0.18,0.6),0.0,0.02)
			x+=w
	# Hochbahn-Stahlbrücke quer über die Straße
	var hb=o+Vector3(20,0,0);var gruen=T(Color(0.3,0.42,0.38))
	for sz in [-12.0,12.0]:
		for sx in [-2.5,2.5]:L.box(gruen,hb+Vector3(sx,7,sz),Vector3(0.6,14,0.6),Basis(),0.04)
	for sx in [-2.8,2.8]:
		L.box(gruen,hb+Vector3(sx,14.6,0),Vector3(0.5,1.6,90),Basis(),0.04)
		var z=-44.0
		while z<44:L.box(gruen,hb+Vector3(sx,14.6,z),Vector3(0.55,1.4,0.18),Basis(Vector3(1,0,0),0.7),0.0);z+=2.4
	L.box(L.M.dunkel,hb+Vector3(0,15.3,0),Vector3(6,0.3,90),Basis(),0.03)
	graffiti(hb+Vector3(-3.1,14.6,4),Vector3(-1,0,0),0.8)
	# Bushaltestelle, Mülltonnen, Hydrant
	L._hydrant(o+Vector3(-30,0.15,6));L._bank(o+Vector3(-40,0.15,6.5),Vector3(0,0,-1))
	for k in 5:muellsack(o+Vector3(rng.randf_range(-70,70),0.15,-6.2))
	laternen(o,lang,26,6.0)
	parker(o,lang,5.0,["c_e30_silber","c_kompakt_schwarz","c_muscle_orange","c_wartburg_gruen","c_jdm_weiss"],0.5)
	KAM.append(["suedstadt","Südstadt",o+Vector3(-55,4.0,-1.5),o+Vector3(20,4,0)])

# ================= DOCKS =================
func docks(o:Vector3):
	flaeche(L.M.hof,o+Vector3(0,0,-40),300,140,0.0)
	B(T(Color(0.14,0.42,0.6),0.15),o+Vector3(0,-1.6,90),Vector3(400,0.2,160),0.0,0.0)
	B(L.M.stein_d,o+Vector3(0,-0.8,30.5),Vector3(300,1.8,1.2),0.0,0.03)
	for x in range(-140,141,10):L.zyl(T(Color(0.15,0.15,0.15)),o+Vector3(x,0,29.2),o+Vector3(x,0.7,29.2),0.22,1.15)
	# Kranbahn-Schienen
	for z in [8.0,26.0]:L.box(L.M.metall,o+Vector3(0,0.05,z),Vector3(300,0.1,0.3),Basis(),0.0)
	# Containerkräne
	for kx in [-60.0,10.0,80.0]:
		var c=o+Vector3(kx,0,17);var farbe=T([Color(0.92,0.3,0.15),Color(0.95,0.75,0.15),Color(0.25,0.45,0.75)][int(kx/70.0+1)%3])
		for sx in [-6.0,6.0]:
			for sz in [-9.0,9.0]:L.box(farbe,c+Vector3(sx,15,sz),Vector3(1.2,30,1.2),Basis(),0.05)
			L.box(farbe,c+Vector3(sx,30.5,30),Vector3(1.4,1.8,95),Basis(),0.05)
			L.box(farbe,c+Vector3(sx,12,0),Vector3(1.0,1.2,19),Basis(),0.04)
			L.zyl(farbe,c+Vector3(sx,31,-9),c+Vector3(sx,46,-4),0.35,1.2)
			L.zyl(farbe,c+Vector3(sx,46,-4),c+Vector3(sx,31.5,70),0.25,1.2)
		L.box(farbe,c+Vector3(0,30.5,-9),Vector3(13,2,1.4),Basis(),0.05);L.box(farbe,c+Vector3(0,30.5,9),Vector3(13,2,1.4),Basis(),0.05)
		L.box(L.M.weiss,c+Vector3(0,28.5,24),Vector3(3,2.5,3.5),Basis(),0.04);L.box(L.M.glas[0],c+Vector3(0,28.5,25.8),Vector3(2.6,1.6,0.1),Basis(),0.0)
		L.zyl(L.M.linie,c+Vector3(0,29.6,34),c+Vector3(0,12,34),0.04,1.0)
		container(c+Vector3(0,9.5,34),0.0)
	# Containerstapel
	var farben=[Color(0.8,0.2,0.15),Color(0.15,0.4,0.75),Color(0.2,0.55,0.3),Color(0.9,0.6,0.1),Color(0.6,0.6,0.62),Color(0.55,0.25,0.5),Color(0.9,0.9,0.88)]
	for gx in range(-130,131,32):
		for gz in [-22.0,-42.0,-62.0]:
			for i in 2:
				for j in 3:
					var hoehe=rng.randi_range(1,4)
					for k in hoehe:container(o+Vector3(gx+i*12.6,k*2.6,gz+j*2.6),0.0,farben[rng.randi()%farben.size()])
	# Schiff am Kai
	var sch=o+Vector3(-20,-1.6,46)
	var rumpf=T(Color(0.2,0.25,0.35));var rot=T(Color(0.7,0.18,0.14))
	L.box(rot,sch+Vector3(0,1.5,0),Vector3(150,3,26),Basis(),0.05)
	L.box(rumpf,sch+Vector3(0,6.5,0),Vector3(150,7,26),Basis(),0.05)
	L.hex(rumpf,[sch+Vector3(75,0,-13),sch+Vector3(75,0,13),sch+Vector3(90,10,3),sch+Vector3(90,10,-3),sch+Vector3(75,10,-13),sch+Vector3(75,10,13),sch+Vector3(92,10.5,3),sch+Vector3(92,10.5,-3)] if false else
		[sch+Vector3(75,0,-13),sch+Vector3(88,3,-2),sch+Vector3(88,3,2),sch+Vector3(75,0,13),sch+Vector3(75,10,-13),sch+Vector3(93,10,-2),sch+Vector3(93,10,2),sch+Vector3(75,10,13)],0.05)
	L.box(T(Color(0.92,0.9,0.86)),sch+Vector3(-62,17,0),Vector3(14,14,22),Basis(),0.05)
	for e in 4:
		for sd in [-1,1]:L.box(L.M.glas[1],sch+Vector3(-62,12+e*3.2,sd*11.05),Vector3(12,1.4,0.1),Basis(),0.0)
	for e in 4:L.box(L.M.glas[1],sch+Vector3(-55,12+e*3.2,0),Vector3(0.1,1.4,20),Basis(),0.0)
	L.box(rot,sch+Vector3(-66,27,0),Vector3(4,6,4),Basis(),0.04)
	for gx in range(-45,70,13):
		for gz in range(-11,12,3):
			for k in rng.randi_range(1,4):container(sch+Vector3(gx,10.0+k*2.6,gz),0.0,farben[rng.randi()%farben.size()])
	# Lagerhallen hinten
	for hx in [-90.0,0.0,90.0]:
		var h=o+Vector3(hx,0,-95)
		wellblech(h+Vector3(0,0,15),60,10,0.0,Color(0.6,0.62,0.64))
		L.box(T(Color(0.55,0.57,0.6)),h+Vector3(0,5,0),Vector3(59.8,10,29.8),Basis(),0.0)
		satteldach(h+Vector3(0,10,0),60,30,0.1,0.0,T(Color(0.55,0.57,0.6)),Color(0.5,0.3,0.25),3.0)
		for k in 3:L.box(T(Color(0.85,0.6,0.15)),h+Vector3(-18+k*18,2.8,15.1),Vector3(6,5.6,0.1),Basis(),0.03)
	for k in 4:auto(["c_suv_grau","c_e30_silber","c_rtw","c_kompakt_weiss"][k],o+Vector3(-100+k*55,0,0),0.4*k)
	KAM.append(["docks","Docks / Hafen",o+Vector3(-120,32,95),o+Vector3(-10,4,0)])
func container(p:Vector3,yaw:float,farbe:=Color(0.8,0.2,0.15)):
	var m=T(farbe,0.6);var dk=T(farbe*0.75);var b=Y(yaw)
	L.box(m,p+Vector3(0,1.3,0),Vector3(12.2,2.58,2.44),b,0.04)
	var x=-5.8
	while x<6.0:
		for sd in [-1,1]:L.box(dk,p+b*Vector3(x,1.3,sd*1.24),Vector3(0.12,2.4,0.05),b,0.0)
		x+=0.4
	for sd in [-1,1]:L.box(dk,p+b*Vector3(sd*6.12,1.3,0),Vector3(0.05,2.4,2.3),b,0.0)

# ================= INDUSTRIE / GÜTERBAHNHOF =================
func industrie(o:Vector3):
	flaeche(L.M.hof,o,320,240,0.0)
	strasse(o+Vector3(0,0,-30),240,5.0,2.0,true,true)
	# Gleise
	for gz in [8.0,14.0,20.0]:
		var g=o+Vector3(0,0,gz)
		flaeche(T(Color(0.45,0.4,0.36)),g,260,3.6,0.03)
		var x=-130.0
		while x<130:L.box(L.M.holz,g+Vector3(x,0.06,0),Vector3(0.25,0.12,2.6),Basis(),0.0);x+=0.9
		for sd in [-0.72,0.72]:L.box(L.M.chrom,g+Vector3(0,0.18,sd),Vector3(260,0.14,0.1),Basis(),0.0)
	for gz in [8.0,20.0]:
		var x=-100.0
		while x<60:
			var farbe=[Color(0.55,0.25,0.18),Color(0.3,0.35,0.4),Color(0.45,0.4,0.2)][rng.randi()%3]
			wellblech(o+Vector3(x,1.2,gz+1.4),14,3.4,0.0,farbe);wellblech(o+Vector3(x,1.2,gz-1.4),14,3.4,PI,farbe)
			L.box(T(farbe),o+Vector3(x,2.9,gz),Vector3(14,3.4,2.7),Basis(),0.0)
			L.box(T(farbe*0.8),o+Vector3(x,4.65,gz),Vector3(14.2,0.1,3.0),Basis(),0.02)
			for wx in [-5.0,5.0]:
				for sd in [-0.75,0.75]:L.zyl(L.M.reifen,o+Vector3(x+wx-0.7,0.45,gz+sd),o+Vector3(x+wx-0.7,0.45,gz+sd*1.1),0.42,1.1);L.zyl(L.M.reifen,o+Vector3(x+wx+0.7,0.45,gz+sd),o+Vector3(x+wx+0.7,0.45,gz+sd*1.1),0.42,1.1)
				L.box(L.M.dunkel,o+Vector3(x+wx,0.9,gz),Vector3(3,0.5,2.2),Basis(),0.02)
			x+=15.0
	# Fabrikhallen mit Sägezahndach
	for hx in [-80.0,0.0,80.0]:
		var h=o+Vector3(hx,0,-75);var wand=L.M.ziegel[rng.randi()%5]
		L.box(wand,h+Vector3(0,5,0),Vector3(60,10,40),Basis(),0.05)
		for k in 6:
			var z0=-20.0+k*6.67;var z1=z0+6.67
			var p=func(x,y,z):return h+Vector3(x,y,z)
			L.hex(T(Color(0.35,0.33,0.33)),[p.call(-30,10,z0),p.call(30,10,z0),p.call(30,10,z1),p.call(-30,10,z1),p.call(-30,10.05,z0),p.call(30,10.05,z0),p.call(30,13,z1),p.call(-30,13,z1)],0.03)
			L.box(L.M.glas[0],h+Vector3(0,11.5,z1-0.1),Vector3(58,2.6,0.08),Basis(),0.0)
		for k in 6:L.box(L.M.glas[0],h+Vector3(-25+k*10,5.5,20.05),Vector3(6,4,0.1),Basis(),0.0)
		L.box(T(Color(0.85,0.55,0.12)),h+Vector3(20,3,20.06),Vector3(6,6,0.12),Basis(),0.03)
	# Schornsteine
	for cx in [-40.0,40.0]:
		var c=o+Vector3(cx,0,-105)
		L.zyl(L.M.ziegel[0],c,c+Vector3(0,50,0),2.4,1.05)
		for y in [38.0,44.0]:L.zyl(L.M.weiss,c+Vector3(0,y,0),c+Vector3(0,y+2.5,0),2.45,1.04)
		for k in 4:L.kugel(T(Color(0.75,0.75,0.78)),c+Vector3(k*2.5,53+k*2.2,k*1.5),Vector3(2.5,2.0,2.5)*(1+k*0.3))
	# Tanks + Rohre
	for k in 3:
		var t=o+Vector3(120,0,-60+k*22)
		L.zyl(L.M.weiss,t,t+Vector3(0,16,0),8,1.03);L.mesh(L.M.weiss,L.SPH,Transform3D(Basis().scaled(Vector3(16,4,16)),t+Vector3(0,16,0)),1.03)
		L.box(L.M.rot,t+Vector3(0,10,8.05),Vector3(6,1,0.1),Basis(),0.0)
	for y in [5.0,6.2]:L.zyl(L.M.metall,o+Vector3(30,y,-50),o+Vector3(112,y,-50),0.5,1.1)
	for x in range(36,112,12):L.box(L.M.metall,o+Vector3(x,2.8,-50),Vector3(0.4,5.6,0.4),Basis(),0.03)
	L._zaun(o+Vector3(-120,0,-36.5),o+Vector3(120,0,-36.5),2.4)
	for k in 3:auto(["c_rtw","c_suv_gruen","c_wartburg_blau"][k],o+Vector3(-60+k*40,0,-30-2.5),PI*0.5)
	KAM.append(["industrie","Industrie & Güterbahnhof",o+Vector3(-125,14,38),o+Vector3(-20,4,-30)])

# ================= STRANDVIERTEL =================
func strand(o:Vector3):
	var sand=T(Color(0.96,0.87,0.62))
	flaeche(sand,o+Vector3(0,0,40),300,70,0.0)
	B(T(Color(0.2,0.65,0.8),0.15),o+Vector3(0,-0.25,150),Vector3(400,0.2,160),0.0,0.0)
	B(T(Color(0.4,0.8,0.85),0.15),o+Vector3(0,-0.15,74),Vector3(400,0.2,8),0.0,0.0)
	for k in 10:L.box(L.M.weiss,o+Vector3(rng.randf_range(-140,140),-0.04,rng.randf_range(72,90)),Vector3(rng.randf_range(4,12),0.05,0.3),Basis(),0.0)
	strasse(o,240,5.0,6.0,true)
	# Promenade mit Palmen
	for x in range(-110,120,12):palme(o+Vector3(x,0.15,7.0+rng.randf_range(-0.3,0.3)),rng.randf_range(7,10))
	# Art-Deco-Hotels gegenüber
	var pastell=[Color(0.98,0.75,0.8),Color(0.6,0.88,0.9),Color(0.98,0.9,0.6),Color(0.75,0.95,0.78),Color(0.85,0.78,0.98),Color(0.98,0.98,0.96)]
	var namen=["OCEAN","PALMA","HOTEL","FLAMINGO","SURF","DELUXE","LIDO","BRANDUNG"]
	var x=-120.0
	while x<120:
		var w=rng.randf_range(16,24);var h=rng.randf_range(10,22);var c=o+Vector3(x+w*0.5,0.15,-9.0-7)
		var pm=L._shader(L.PUTZ,{"farbe":pastell[rng.randi()%pastell.size()]*0.92})
		L.box(pm,c+Vector3(0,h*0.5,0),Vector3(w,h,14),Basis(),0.05)
		var akz=T(pastell[rng.randi()%pastell.size()]*0.85)
		var y=3.6
		while y<h-1:
			L.box(akz,c+Vector3(0,y,7.05),Vector3(w,0.35,0.15),Basis(),0.02)
			L.box(L.M.glas[1],c+Vector3(0,y+1.2,7.02),Vector3(w-3,1.4,0.06),Basis(),0.0);y+=3.2
		L.box(akz,c+Vector3(0,h*0.5+2,7.3),Vector3(2.4,h+4,0.6),Basis(),0.03)
		L._schrift(namen[rng.randi()%namen.size()],c+Vector3(0,h-1.5,7.5),Basis(),0.012,[Color(1,0.3,0.6),Color(0.3,1,0.95),Color(1,0.95,0.4)][rng.randi()%3],Color(0.1,0.05,0.1))
		L.box(L.M.markise[rng.randi()%4][0],c+Vector3(0,3.1,8.4),Vector3(w-2,0.12,2.6),Basis(Vector3(1,0,0),0.25),0.03)
		x+=w+rng.randf_range(2,5)
	# Rettungsturm, Schirme, Handtücher, Volleyball
	var rt=o+Vector3(10,0,45)
	for sx in [-1.2,1.2]:
		for sz in [-1.2,1.2]:L.zyl(L.M.weiss,rt+Vector3(sx,0,sz),rt+Vector3(sx,3,sz),0.12,1.2)
	L.box(L.M.rot,rt+Vector3(0,4.2,0),Vector3(3.2,2.4,3.2),Basis(),0.04);L.box(L.M.gelb,rt+Vector3(0,5.6,0),Vector3(3.8,0.2,3.8),Basis(),0.03)
	L.box(L.M.glas[0],rt+Vector3(0,4.5,1.62),Vector3(2.4,1.0,0.05),Basis(),0.0)
	L.box(L.M.holz,rt+Vector3(0,1.5,3.2),Vector3(1.0,0.1,4.0),Basis(Vector3(1,0,0),0.7),0.02)
	for k in 16:
		var p=o+Vector3(rng.randf_range(-120,120),0,rng.randf_range(25,62))
		var sch=CylinderMesh.new();sch.top_radius=0.05;sch.bottom_radius=1.5;sch.height=0.6;sch.radial_segments=12
		var farbe=[Color(0.95,0.3,0.3),Color(0.25,0.6,0.95),Color(0.98,0.85,0.2),Color(0.3,0.85,0.5)][k%4]
		L.zyl(L.M.weiss,p,p+Vector3(0,2.2,0),0.04,1.3);L.mesh(T(farbe),sch,Transform3D(Basis(),p+Vector3(0,2.35,0)),1.04)
		L.box(T([Color(0.95,0.45,0.2),Color(0.4,0.3,0.9),Color(0.95,0.95,0.9)][k%3]),p+Vector3(1.2,0.02,0.6),Vector3(0.9,0.03,1.8),Basis(Vector3.UP,rng.randf()),0.0)
	var vb=o+Vector3(-50,0,40)
	for sx in [-4.5,4.5]:L.zyl(L.M.weiss,vb+Vector3(sx,0,0),vb+Vector3(sx,2.5,0),0.06,1.3)
	L.box(L._masche if L._masche!=null else L.M.weiss,vb+Vector3(0,2.1,0),Vector3(9,0.9,0.02),Basis(),0.0);L.box(L.M.weiss,vb+Vector3(0,2.55,0),Vector3(9,0.08,0.04),Basis(),0.0)
	parker(o,240,5.0,["c_sport_gelb","c_sport_rot","c_jdm_blau","c_muscle_orange","c_kompakt_weiss","c_e30_silber"],0.35)
	KAM.append(["strand","Strandviertel",o+Vector3(-60,6,32),o+Vector3(10,7,-12)])

# ================= NEU-KOWLOON =================
func kowloon(o:Vector3):
	var lang=130.0
	strasse(o,lang,3.5,2.0,false,true)
	var waende=[Color(0.72,0.7,0.62),Color(0.62,0.66,0.62),Color(0.75,0.65,0.55),Color(0.6,0.6,0.66),Color(0.8,0.76,0.68)]
	var neon=[Color(1,0.2,0.5),Color(0.2,0.95,1),Color(1,0.85,0.2),Color(0.4,1,0.4),Color(1,0.45,0.15),Color(0.7,0.4,1)]
	var schilder=["NUDELN","MASSAGE","PFAND","HOTEL","KARAOKE","ZAHNARZT","TEE","DIM SUM","GOLD","BAR","SPIELE","REPARATUR"]
	for s in [-1,1]:
		var x=-lang*0.5;var aussen=Vector3(0,0,-s)
		while x<lang*0.5:
			var w=rng.randf_range(7,11);var et=rng.randi_range(9,16);var eh=2.8;var H=et*eh+3.5
			var c=o+Vector3(x+w*0.5,0.15,s*(5.5+6.0));var wand=T(waende[rng.randi()%waende.size()]*rng.randf_range(0.85,1.0))
			L.box(wand,c+Vector3(0,H*0.5,0),Vector3(w,H,12),Basis(),0.05)
			var f=c+aussen*6.0;var b=Basis(Vector3.UP.cross(aussen),Vector3.UP,aussen);var r=Vector3.UP.cross(aussen)
			# Läden unten
			L.box(L.M.glas[1],f+Vector3(0,1.7,0)+aussen*0.03,Vector3(w-1,2.6,0.05),b,0.0)
			L.box(L.M.markise[rng.randi()%4][0],f+Vector3(0,3.2,0)+aussen*0.9,Vector3(w-0.6,0.1,1.8),b*Basis(Vector3(1,0,0),0.15),0.02)
			for e in et:
				var y=3.5+e*eh+1.3
				for i in int(w/2.2):
					var xx=(i+0.5)*w/int(w/2.2)-w*0.5
					L.box(L.M.glas[rng.randi()%4],f+r*xx+Vector3(0,y,0)+aussen*0.03,Vector3(1.2,1.2,0.04),b,0.0)
					if rng.randf()<0.25:L.box(L.M.weiss,f+r*xx+Vector3(0,y-0.9,0)+aussen*0.35,Vector3(0.9,0.6,0.6),b,0.03)  # Klimagerät
					elif rng.randf()<0.15:L.box(L.M.metall,f+r*xx+Vector3(0,y,0)+aussen*0.45,Vector3(1.6,1.6,0.9),b,0.02)  # Käfig-Balkon
					if rng.randf()<0.08:  # Wäsche
						L.zyl(L.M.metall,f+r*xx+Vector3(0,y-0.2,0)+aussen*0.05,f+r*xx+Vector3(0,y-0.2,0)+aussen*1.6,0.02,1.0)
						for q in 3:L.box(T(SPRAY[rng.randi()%SPRAY.size()]),f+r*xx+Vector3(0,y-0.55,0)+aussen*(0.4+q*0.4),Vector3(0.05,0.6,0.35),b,0.0)
			# Neon-Schilder senkrecht
			for q in rng.randi_range(1,2):
				var col=neon[rng.randi()%neon.size()];var txt:String=schilder[rng.randi()%schilder.size()]
				var hh=txt.length()*1.05+0.6;var p=f+r*rng.randf_range(-w*0.35,w*0.35)+Vector3(0,4.5+hh*0.5+rng.randf_range(0,6),0)+aussen*1.3
				L.box(T(Color(0.12,0.1,0.14)),p,Vector3(1.3,hh,0.25),b,0.03)
				L.box(licht(col),p+aussen*0.13,Vector3(1.1,hh-0.2,0.02),b,0.0)
				L._schrift("\n".join(txt.split("")),p+aussen*0.16,b,0.0095,Color(1,1,1),Color(0.1,0.05,0.12),96)
				L.zyl(L.M.metall,p-aussen*1.2+Vector3(0,hh*0.4,0),p+Vector3(0,hh*0.4,0),0.04,1.0)
			# Dachbuden + Antennen
			for q in 2:
				var dp=c+Vector3(rng.randf_range(-w*0.3,w*0.3),H,rng.randf_range(-3,3))
				if rng.randf()<0.6:huette(dp,3,2.5,2.2,rng.randf()*0.4,[Color(0.55,0.58,0.6),Color(0.6,0.5,0.4)][q])
				else:L.zyl(L.M.metall,dp,dp+Vector3(0,5,0),0.05,1.2);L.box(L.M.metall,dp+Vector3(0,4,0),Vector3(1.6,0.05,0.05),Basis(),0.0)
			x+=w
	# Kabelgewirr quer über die Gasse
	for k in 26:
		var x0=rng.randf_range(-lang*0.45,lang*0.45);var y0=rng.randf_range(6,20)
		kabel(o+Vector3(x0,y0,-5.4),o+Vector3(x0+rng.randf_range(-4,4),y0+rng.randf_range(-2,2),5.4),rng.randf_range(0.3,1.2))
	# Stände auf dem Gehweg
	for k in 8:
		var p=o+Vector3(rng.randf_range(-lang*0.45,lang*0.45),0.15,(4.6 if k%2==0 else -4.6))
		L.box(L.M.holz,p+Vector3(0,0.5,0),Vector3(1.8,1.0,0.9),Basis(),0.03)
		L.box(L.M.markise[k%4][0],p+Vector3(0,2.2,0),Vector3(2.2,0.08,1.6),Basis(),0.02)
		for sx in [-0.85,0.85]:L.zyl(L.M.metall,p+Vector3(sx,0,0),p+Vector3(sx,2.2,0),0.03,1.2)
		for q in 4:L.kugel(T([Color(0.95,0.5,0.1),Color(0.9,0.2,0.2),Color(0.4,0.8,0.2)][q%3]),p+Vector3(-0.6+q*0.4,1.1,0),Vector3(0.15,0.15,0.15),1.0)
	parker(o,lang,3.5,["c_jdm_weiss","c_jdm_rot","c_taxi","c_kompakt_schwarz"],0.3)
	KAM.append(["kowloon","Neu-Kowloon",o+Vector3(-58,3.2,-1.2),o+Vector3(20,7,0)])

# ================= STERNVIERTEL =================
var _klar:StandardMaterial3D
func klarglas()->StandardMaterial3D:
	if _klar==null:
		_klar=StandardMaterial3D.new();_klar.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		_klar.albedo_color=Color(0.75,0.9,0.95,0.22);_klar.roughness=0.05;_klar.metallic_specular=0.9
	return _klar
func figur_puppe(p:Vector3,yaw:float,farbe:Color):
	var m=T(farbe);var hm=T(Color(0.92,0.92,0.9))
	L.zyl(L.M.metall,p,p+Vector3(0,0.1,0),0.25,1.0)
	L.zyl(L.M.metall,p,p+Vector3(0,0.7,0),0.03,1.0)
	L.kapsel(m,p+Vector3(0,0.85,0),p+Vector3(0,1.45,0),0.2)
	L.kugel(hm,p+Vector3(0,1.78,0),Vector3(0.12,0.14,0.12))
# Laden: f = Mitte der Front unten, n = zur Straße, breite, Typ
func laden(f:Vector3,n:Vector3,br:float,typ:String,tief:=4.0):
	var r=Vector3.UP.cross(n);var b=Basis(r,Vector3.UP,n);var hh=4.6
	var innen=f-n*(tief*0.5)
	L.box(L.M.stein,innen+Vector3(0,0.06,0),Vector3(br,0.12,tief),b,0.0)          # Boden
	var wandf=[Color(0.95,0.92,0.85),Color(0.25,0.22,0.24),Color(0.85,0.75,0.65),Color(0.7,0.8,0.82)][rng.randi()%4]
	L.box(T(wandf),f-n*(tief-0.05)+Vector3(0,hh*0.5,0),Vector3(br,hh,0.1),b,0.0)  # Rückwand
	L.box(licht(Color(1,0.95,0.8)),innen+Vector3(0,hh-0.05,0),Vector3(br*0.6,0.06,tief*0.4),b,0.0)
	match typ:
		"MODE":
			for k in 4:figur_puppe(f-n*rng.randf_range(1.2,3.0)+r*(-br*0.38+k*br*0.25),atan2(n.x,n.z),SPRAY[rng.randi()%SPRAY.size()])
			L.box(L.M.chrom,f-n*(tief-0.6)+Vector3(0,1.6,0),Vector3(br*0.8,0.05,0.05),b,0.0)
			for k in 8:L.box(T(SPRAY[k%SPRAY.size()]),f-n*(tief-0.6)+r*(-br*0.35+k*br*0.1)+Vector3(0,1.15,0),Vector3(0.08,0.9,0.5),b,0.0)
		"JUWELIER","UHREN":
			for k in 3:
				var q=f-n*rng.randf_range(1.5,2.5)+r*(-br*0.3+k*br*0.3)
				L.box(L.M.dunkel,q+Vector3(0,0.5,0),Vector3(1.4,1.0,0.7),b,0.02);L.box(klarglas(),q+Vector3(0,1.2,0),Vector3(1.4,0.4,0.7),b,0.0)
				for j in 3:L.kugel(licht(Color(1,0.85,0.3)),q+r*(-0.4+j*0.4)+Vector3(0,1.08,0),Vector3(0.07,0.07,0.07),1.0)
		"GALERIE":
			for k in 3:
				var q=f-n*(tief-0.12)+r*(-br*0.3+k*br*0.3)+Vector3(0,2.2,0)
				L.box(T(Color(0.85,0.7,0.3)),q,Vector3(1.6,1.2,0.06),b,0.0);L.box(T(SPRAY[rng.randi()%SPRAY.size()]),q+n*0.04,Vector3(1.35,0.95,0.02),b,0.0)
		"SCHUHE","PARFUM":
			for y in [0.8,1.4,2.0,2.6]:
				L.box(L.M.holz,f-n*(tief-0.35)+Vector3(0,y,0),Vector3(br*0.85,0.06,0.5),b,0.0)
				for k in 7:L.box(T(SPRAY[rng.randi()%SPRAY.size()]),f-n*(tief-0.35)+r*(-br*0.38+k*br*0.12)+Vector3(0,y+0.14,0),Vector3(0.3,0.22,0.3),b,0.0)
		"CAFÉ","SUSHI":
			L.box(L.M.holz,f-n*(tief-1.0)+Vector3(0,0.55,0),Vector3(br*0.7,1.1,0.7),b,0.02)
			for k in 3:
				var q=f+n*2.2+r*(-br*0.3+k*br*0.3)
				L.zyl(L.M.weiss,q,q+Vector3(0,0.75,0),0.05,1.0);L.zyl(L.M.weiss,q+Vector3(0,0.74,0),q+Vector3(0,0.78,0),0.45,1.05)
				for sd in [-1,1]:B(L.M.metall,q+r*sd*0.75+Vector3(0,0.45,0),Vector3(0.45,0.9,0.45),0.0,0.02)
				var sch=CylinderMesh.new();sch.top_radius=0.05;sch.bottom_radius=1.3;sch.height=0.45;sch.radial_segments=10
				L.zyl(L.M.weiss,q,q+Vector3(0,2.4,0),0.03,1.0);L.mesh(T(Color(0.92,0.9,0.82)),sch,Transform3D(Basis(),q+Vector3(0,2.5,0)),1.04)
	# Front: Pfeiler, Glas, Rahmen, Tür, Schild
	for sd in [-1,1]:L.box(L.M.stein,f+r*sd*(br*0.5-0.3)-n*(tief*0.5)+Vector3(0,hh*0.5,0),Vector3(0.6,hh,tief),b,0.03)
	L.box(klarglas(),f+Vector3(0,2.0,0)-n*0.05,Vector3(br-0.6,3.6,0.04),b,0.0)
	L.box(L.M.dunkel,f+Vector3(0,0.2,0)+n*0.02,Vector3(br-0.6,0.4,0.12),b,0.0)
	L.box(L.M.dunkel,f+Vector3(0,3.8,0)+n*0.02,Vector3(br-0.6,0.1,0.1),b,0.0)
	L.box(L.M.dunkel,f+Vector3(br*0.25,1.9,0)+n*0.02,Vector3(0.08,3.6,0.1),b,0.0)
	L.box(T(Color(0.12,0.12,0.14)),f+Vector3(0,4.3,0)+n*0.12,Vector3(br-0.4,0.75,0.2),b,0.02)
	L._schrift(typ,f+Vector3(0,4.3,0)+n*0.24,b,0.0075,Color(0.98,0.85,0.45),Color(0,0,0,0),96)
	if rng.randf()<0.5:L.box(L.M.markise[rng.randi()%4][0],f+Vector3(0,3.6,0)+n*1.0,Vector3(br-0.6,0.1,2.0),b*Basis(Vector3(1,0,0),0.2),0.02)

var AH_X:=0.0
func stern(o:Vector3):
	var lang=200.0
	flaeche(L.M.pflaster,o,lang+80,180,-0.01)
	strasse(o+Vector3(0,0,-8),lang,5.0,4.0,true);strasse(o+Vector3(0,0,8),lang,5.0,4.0,true)
	flaeche(L.M.gras,o,lang,6.0,0.16)
	B(L.M.stein,o+Vector3(0,0.08,0),Vector3(lang,0.16,6.2),0.0,0.02)
	for x in range(-90,100,12):L._baum(o+Vector3(x,0.16,0))
	var typen=["MODE","JUWELIER","CAFÉ","GALERIE","SCHUHE","UHREN","PARFUM","SUSHI","MODE","JUWELIER"]
	var stein=[L._shader(L.PUTZ,{"farbe":Color(0.93,0.88,0.78)}),L._shader(L.PUTZ,{"farbe":Color(0.86,0.84,0.8)}),L.M.weiss,L._shader(L.PUTZ,{"farbe":Color(0.8,0.74,0.66)})]
	for s in [-1,1]:
		var n=Vector3(0,0,-s);var r=Vector3.UP.cross(n);var b=Basis(r,Vector3.UP,n)
		var x=-lang*0.5
		while x<lang*0.5:
			var w=rng.randf_range(24,34);var front=o+Vector3(x+w*0.5,0.15,s*17.0)
			if s<0 and x>-30 and x<10:
				autohaus(o+Vector3(x+22,0.15,s*17.0),n);AH_X=x+22;x+=50;continue
			var et=rng.randi_range(4,7);var eh=3.4;var H=et*eh
			var m=stein[rng.randi()%stein.size()]
			# Obergeschosse auf 5 m, Erdgeschoss Läden
			L.box(m,front-n*9.0+Vector3(0,5.0+H*0.5,0),Vector3(w,H,18),b,0.05)
			L.box(m,front-n*11.0+Vector3(0,2.5,0),Vector3(w,5.0,14),b,0.04)
			L.box(L.M.stein,front+Vector3(0,5.0,0)+n*0.1,Vector3(w+0.3,0.35,0.5),b,0.03)
			var nl=int(w/7.5);var bl=w/nl
			for k in nl:laden(front+r*(-w*0.5+(k+0.5)*bl),n,bl,typen[rng.randi()%typen.size()])
			var modern=rng.randf()<0.5
			for e in et:
				var y=5.0+e*eh+1.7
				if modern:
					L.box(L.M.glas[1],front+Vector3(0,y,0)+n*0.03,Vector3(w-1.2,1.9,0.05),b,0.0)
					if e%2==1:L.box(m,front+Vector3(0,y-1.2,0)+n*0.8,Vector3(w,0.2,1.6),b,0.03);L.box(klarglas(),front+Vector3(0,y-0.7,0)+n*1.55,Vector3(w,0.9,0.04),b,0.0)
				else:
					var nf=int(w/2.6)
					for i in nf:
						var xx=-w*0.5+(i+0.5)*w/nf
						fenster(front+r*xx+Vector3(0,y,0),b,1.2,1.9,L.M.glas[1])
						if e%2==0:
							L.box(L.M.stein,front+r*xx+Vector3(0,y-1.1,0)+n*0.25,Vector3(1.6,0.12,0.5),b,0.02)
							L.box(L.M.dunkel,front+r*xx+Vector3(0,y-0.75,0)+n*0.48,Vector3(1.5,0.6,0.04),b,0.0)
			L.box(m,front-n*9.0+Vector3(0,5.0+H+0.4,0),Vector3(w+0.6,0.8,18.6),b,0.04)
			# Pflanzkübel mit Bäumchen
			for k in 2:
				var q=front+n*3.0+r*rng.randf_range(-w*0.4,w*0.4)
				B(L.M.stein_d,q+Vector3(0,0.4,0),Vector3(1.2,0.8,1.2),0.0,0.03);L.kugel(L.M.laub[1],q+Vector3(0,1.6,0),Vector3(0.8,1.1,0.8))
			x+=w+0.5
	# Brunnen-Platz mit Stern
	var pl=o+Vector3(lang*0.5+20,0,0)
	flaeche(L.M.stein,pl,40,60,0.02)
	L.zyl(L.M.stein,pl,pl+Vector3(0,0.6,0),7,1.03);L.zyl(T(Color(0.3,0.65,0.9),0.15),pl+Vector3(0,0.6,0),pl+Vector3(0,0.65,0),6.6)
	L.zyl(L.M.weiss,pl,pl+Vector3(0,3,0),0.6,1.1)
	var st=pl+Vector3(0,5,0)
	for k in 5:
		var a=TAU*k/5.0;L.box(L.M.gelb,st+Vector3(0,cos(a),sin(a))*1.3,Vector3(0.4,2.6,0.8),Basis(Vector3(1,0,0),-a),0.03)
	parker(o+Vector3(0,0,-8),lang,5.0,["c_luxus_schwarz","c_luxus_silber","c_sport_schwarz","c_suv_grau"],0.35)
	parker(o+Vector3(0,0,8),lang,5.0,["c_sport_rot","c_luxus_silber","c_e30_schwarz","c_taxi"],0.35)
	KAM.append(["stern_laeden","Sternviertel – Einkaufsstraße",o+Vector3(-88,3.4,4.0),o+Vector3(-55,3.2,17)])
	KAM.append(["stern_autohaus","Sternviertel – Luxus-Autohaus",o+Vector3(AH_X+14,4.5,-4.0),o+Vector3(AH_X-2,5.0,-30)])
func autohaus(c:Vector3,n:Vector3):
	var r=Vector3.UP.cross(n);var b=Basis(r,Vector3.UP,n);var w=44.0;var d=20.0;var H=10.0
	var P=func(x,y,z):return c+r*x+Vector3.UP*y+n*z
	# Vorplatz mit Ausstellungsautos und Fahnen (Front liegt 6 m zurück)
	L.box(T(Color(0.85,0.85,0.86)),P.call(0,0.05,-3),Vector3(w,0.1,6),b,0.0)
	auto("c_sport_rot",P.call(-12,0.1,-3),atan2(r.x,r.z)+0.5);auto("c_luxus_silber",P.call(12,0.1,-3),atan2(r.x,r.z)-0.5)
	for k in 5:
		var q=P.call(-w*0.5+2+k*10,0.1,-0.6)
		L.zyl(L.M.chrom,q,q+Vector3(0,7,0),0.06,1.2)
		L.box(T([Color(0.1,0.15,0.4),Color(0.85,0.75,0.3)][k%2]),q+Vector3(0,5.6,0)+r*0.55,Vector3(1.0,2.6,0.04),b,0.0)
	var f=P.call(0,0,-6)
	var Q=func(x,y,z):return f+r*x+Vector3.UP*y+n*z
	L.box(L.M.weiss,Q.call(0,0.1,-d*0.5),Vector3(w,0.2,d),b,0.0)
	L.box(L.M.weiss,Q.call(0,H*0.5,-d+0.2),Vector3(w,H,0.4),b,0.03)
	for sd in [-1,1]:L.box(L.M.weiss,Q.call(sd*(w*0.5-0.2),H*0.5,-d*0.5),Vector3(0.4,H,d),b,0.03)
	L.box(L.M.dunkel,Q.call(0,H+0.3,-d*0.5),Vector3(w+0.6,0.6,d+0.6),b,0.04)
	L.box(L.M.weiss,Q.call(0,H+0.7,-d*0.5),Vector3(w+0.2,0.2,d+0.2),b,0.0)
	# Galerie (Zwischengeschoss) hinten
	L.box(L.M.weiss,Q.call(0,4.6,-d+4.5),Vector3(w-1,0.3,8.6),b,0.03)
	L.box(klarglas(),Q.call(0,5.3,-d+8.8),Vector3(w-1,1.1,0.04),b,0.0)
	for k in 3:auto(["c_luxus_schwarz","c_sport_gelb","c_suv_grau"][k],Q.call(-14+k*14,4.75,-d+4.5),atan2(r.x,r.z))
	# Drehteller mit Sportwagen
	L.zyl(L.M.chrom,Q.call(-8,0.2,-7),Q.call(-8,0.55,-7),3.4,1.03)
	auto("c_sport_schwarz",Q.call(-8,0.55,-7),atan2(r.x,r.z)+0.7)
	auto("c_muscle_orange",Q.call(9,0.2,-6),atan2(r.x,r.z)-0.4)
	auto("c_jdm_blau",Q.call(18,0.2,-10),atan2(r.x,r.z)+0.2)
	for k in 6:L.box(licht(Color(1,0.97,0.88)),Q.call(-w*0.5+4+k*7.2,H-0.15,-d*0.4),Vector3(4,0.08,0.6),b,0.0)
	# Glasfront mit Stahlrahmen
	L.box(klarglas(),Q.call(0,H*0.5,0.05),Vector3(w-0.6,H,0.05),b,0.0)
	var x=-w*0.5
	while x<=w*0.5+0.01:L.box(L.M.metall,Q.call(x,H*0.5,0.1),Vector3(0.18,H,0.16),b,0.0);x+=4.4
	for y in [0.15,4.6,H-0.1]:L.box(L.M.metall,Q.call(0,y,0.1),Vector3(w,0.2,0.18),b,0.0)
	# Dachschild mit Stern
	L.box(T(Color(0.08,0.1,0.2)),Q.call(0,H+2.4,-1.5),Vector3(24,3.2,0.4),b,0.04)
	L._schrift("AUTOHAUS STERN",Q.call(2,H+2.4,-1.27),b,0.026,Color(1,0.92,0.6),Color(0.3,0.2,0.05))
	var st=Q.call(-9.5,H+2.4,-1.2)
	for k in 5:
		var a=TAU*k/5.0;var dd=r*sin(a)+Vector3.UP*cos(a)
		L.box(licht(Color(1,0.85,0.3)),st+dd*0.55,Vector3(0.35,1.1,0.1),b*Basis(Vector3(0,0,1),-a),0.0)

# ================= VORORT =================
func vorort(o:Vector3):
	var lang=170.0
	flaeche(L.M.gras,o,lang+80,150,-0.01)
	strasse(o,lang,4.5,2.0,false)
	var waende=[L.M.putz[0],L.M.putz[1],L.M.putz[4],L.M.putz[3],L.M.ziegel[2],L.M.putz[2]]
	var daecher=[Color(0.65,0.25,0.2),Color(0.3,0.3,0.34),Color(0.45,0.3,0.22),Color(0.25,0.35,0.45)]
	for s in [-1,1]:
		var x=-lang*0.5+4;var yaw=0.0 if s<0 else PI
		while x<lang*0.5-14:
			var w=rng.randf_range(10,13);var d=9.0;var c=o+Vector3(x+w*0.5,0.0,s*(6.5+8+d*0.5))
			satteldach(c,w,d,[3.2,5.8][rng.randi()%2],yaw,waende[rng.randi()%waende.size()],daecher[rng.randi()%4],2.6)
			var b=Y(yaw);var fz=d*0.5+0.02
			var hh=3.2
			for fx in [-w*0.3,w*0.3]:fenster(c+b*Vector3(fx,1.6,fz),b,1.6,1.3)
			L.box(L.M.tuer[rng.randi()%5],c+b*Vector3(0,1.1,fz+0.03),Vector3(1.0,2.2,0.06),b,0.02)
			L.box(L.M.stein,c+b*Vector3(0,2.5,fz+0.5),Vector3(1.6,0.1,1.0),b,0.02)
			# Garage daneben + Einfahrt
			var gc=c+b*Vector3(w*0.5+2.2,0,0.5)
			garage(gc,yaw,false)
			flaeche(L.M.hof,o+Vector3(gc.x-o.x,0,s*(6.5+4.2)),3.2,8.5,0.02)
			# Weißer Lattenzaun + Hecke + Briefkasten
			holzzaun(o+Vector3(x,0,s*6.6),o+Vector3(x+w-0.5,0,s*6.6),0.9,Color(0.97,0.96,0.94),0.0)
			if rng.randf()<0.5:L._baum(o+Vector3(x+2.0,0,s*10.0))
			L.zyl(L.M.holz,o+Vector3(x+w-0.2,0,s*6.2),o+Vector3(x+w-0.2,1.1,s*6.2),0.05,1.2);B(L.M.tuer[rng.randi()%5],o+Vector3(x+w-0.2,1.2,s*6.2),Vector3(0.3,0.3,0.5))
			if rng.randf()<0.5:auto(["c_kompakt_rot","c_suv_gruen","c_e30_silber","c_wartburg_beige","c_kompakt_weiss"][rng.randi()%5],o+Vector3(gc.x-o.x,0,s*(6.5+4.5)),0.0 if s<0 else PI)
			x+=w+7.0
	for x in range(-80,90,20):L._laterne(o+Vector3(x,0.15,-5.5),Vector3(0,0,1))
	KAM.append(["vorort","Vorort / Ost-Vorort",o+Vector3(-55,5.5,2),o+Vector3(10,2,-6)])

# ================= SONNENHÜGEL =================
var SH_O:=Vector3.ZERO
var SH_P:=[];var SH_H:=[];var SH_GRID:={};var SH_LID:=[];var SH_KNOTEN:=[]
var SH_PLOTS:=[]   # {c:Vector2, yaw, w, d, h}
var SH_ZUF:=[]     # Zufahrt-Punkte [Vector2, Höhe]
var SH_ZGRID:={}
func sh_basis(x:float,z:float)->float:
	var t=clamp((8.0-z)/225.0,0.0,1.0)
	return 70.0*t*t*(3.0-2.0*t)+4.0*sin(x*0.03+z*0.025)*t+2.0*sin(x*0.07-z*0.05)*t
func sh_kurve(pkt:Array,schritt:=2.0)->Array:
	var aus=[]
	for i in pkt.size()-1:
		var p0:Vector2=pkt[max(i-1,0)];var p1:Vector2=pkt[i];var p2:Vector2=pkt[i+1];var p3:Vector2=pkt[min(i+2,pkt.size()-1)]
		var n=max(int(p1.distance_to(p2)/schritt),1)
		for k in n:
			var t=float(k)/n;var t2=t*t;var t3=t2*t
			aus.append(0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t2+(-p0+3.0*p1-3.0*p2+p3)*t3))
	aus.append(pkt[-1]);return aus
func _naechst(grid:Dictionary,P:Array,Hh:Array,x:float,z:float)->Vector2:
	var best=1e9;var h=0.0;var gx=int(floor(x/10.0));var gz=int(floor(z/10.0))
	for i in range(-1,2):
		for j in range(-1,2):
			for k in grid.get(Vector2i(gx+i,gz+j),[]):
				var d=Vector2(x,z).distance_to(P[k])
				if d<best:best=d;h=Hh[k]
	return Vector2(best,h)
func sh_lane_naechst(x:float,z:float)->Vector2:return _naechst(SH_GRID,SH_P,SH_H,x,z)
func sh_plot_lokal(pl:Dictionary,x:float,z:float)->Vector2:
	var v=Vector2(x,z)-pl.c;var cy=cos(pl.yaw);var sy=sin(pl.yaw)
	# lokale Achsen: x=(cos,-sin) , z=(sin,cos)
	return Vector2(v.x*cy-v.y*sy,v.x*sy+v.y*cy)
func sh_hoehe(x:float,z:float)->float:
	var h=sh_basis(x,z)
	for pl in SH_PLOTS:
		if Vector2(x,z).distance_to(pl.c)>pl.w+20:continue
		var l=sh_plot_lokal(pl,x,z);var dx=max(abs(l.x)-pl.w*0.5,0.0);var dz=max(abs(l.y)-pl.d*0.5,0.0)
		var d=sqrt(dx*dx+dz*dz)
		if d<10.0:h=lerp(pl.h,h,smoothstep(0.0,10.0,d))
	var zb=1e9;var zh=0.0;var gx=int(floor(x/10.0));var gz=int(floor(z/10.0))
	for i in range(-1,2):
		for j in range(-1,2):
			for k in SH_ZGRID.get(Vector2i(gx+i,gz+j),[]):
				var dd=Vector2(x,z).distance_to(SH_ZUF[k][0])
				if dd<zb:zb=dd;zh=SH_ZUF[k][1]
	var l=sh_lane_naechst(x,z)
	if l.x<17.0:h=lerp(l.y-0.15,h,smoothstep(7.2,17.0,l.x))
	if zb<10.0 and l.x>RAND+0.3:h=lerp(zh-0.05,h,smoothstep(4.8,10.0,zb))
	if l.x<5.0:h=min(h,l.y-0.15+max(l.x-3.8,0.0))
	if l.x<16.0 and zb<10.0:h=min(h,l.y-0.15+max(l.x-RAND-0.4,0.0)*0.9)   # neben Auffahrten: Böschung statt Buckel an der Straße
	for pl in SH_PLOTS:   # im Grundstück immer Plateauhöhe (knapp darunter)
		if Vector2(x,z).distance_to(pl.c)>pl.w:continue
		var lp=sh_plot_lokal(pl,x,z)
		if abs(lp.x)<pl.w*0.5+0.5 and abs(lp.y)<pl.d*0.5+0.5:h=pl.h-0.2
	return h
const RAND:=3.6
var _lid_idx:={}
func sh_lid_info(p:Vector2,lid:int)->Array:   # [Höhe, Fußpunkt] auf Fahrbahn lid (ohne Wendehammer-Ring)
	if not _lid_idx.has(lid):
		var l=[]
		for k in SH_P.size():
			if SH_LID[k]==lid:l.append(k)
		_lid_idx[lid]=l
	var best=1e9;var bi=-1
	for k in _lid_idx[lid]:
		var d=p.distance_to(SH_P[k])
		if d<best:best=d;bi=k
	var res=[SH_H[bi],SH_P[bi]];var bd=1e9
	for nb in [bi-1,bi+1]:
		if nb<0 or nb>=SH_P.size() or SH_LID[nb]!=lid:continue
		var A:Vector2=SH_P[min(bi,nb)];var B:Vector2=SH_P[max(bi,nb)]
		if A.distance_to(B)>2.6:continue
		var t=clamp((p-A).dot(B-A)/(B-A).length_squared(),0.0,1.0);var F=A.lerp(B,t)
		if p.distance_to(F)<bd:bd=p.distance_to(F);res=[lerp(SH_H[min(bi,nb)],SH_H[max(bi,nb)],t),F]
	return res
# eine Höhenfunktion für alle Fahrbahnflächen am Abzweig -> keine Stufen
func sh_strasse_h(p:Vector2,lid:int)->float:
	var m=sh_lid_info(p,0)
	if lid==0:return m[0]
	var b=sh_lid_info(p,lid)
	var dm=p.distance_to(m[1])
	if dm<=RAND:return m[0]
	var w=clamp((dm-RAND)/2.5,0.0,1.0);w=w*w*(3.0-2.0*w)
	return lerp(m[0],b[0],w) if p.distance_to(SH_KNOTEN[lid-1])<16.0 else b[0]
func sh_lane0_info(p:Vector2)->Array:   # Projektion nur auf die Hauptstraße
	var best=1e9;var bi=-1
	for k in SH_P.size():
		if SH_LID[k]!=0:continue
		var d=p.distance_to(SH_P[k])
		if d<best:best=d;bi=k
	var res=[SH_H[bi],SH_P[bi]];var bd=1e9
	for nb in [bi-1,bi+1]:
		if nb<0 or nb>=SH_P.size() or SH_LID[nb]!=0:continue
		var A:Vector2=SH_P[min(bi,nb)];var B:Vector2=SH_P[max(bi,nb)]
		var t=clamp((p-A).dot(B-A)/(B-A).length_squared(),0.0,1.0);var F=A.lerp(B,t)
		if p.distance_to(F)<bd:bd=p.distance_to(F);res=[lerp(SH_H[min(bi,nb)],SH_H[max(bi,nb)],t),F]
	return res
func sh_abst_lane0(p:Vector2)->float:return p.distance_to(sh_lane0_info(p)[1])
func sh_lane0_hoehe(p:Vector2)->float:return sh_lane0_info(p)[0]
func sh_abst(p:Vector2)->float:
	return p.distance_to(sh_lane_genau(p.x,p.y)[2])
func sh_auf_kante(p:Vector2)->Vector2:
	var g=sh_lane_genau(p.x,p.y);var F:Vector2=g[2];var d=p-F
	if d.length()<0.001:return p
	return F+d.normalized()*RAND
# Fahrbahnhöhe genau (auf das nächste Segment projiziert): [Höhe, Tangente, Fußpunkt]
func sh_lane_genau(x:float,z:float)->Array:
	var best=1e9;var bi=-1;var gx=int(floor(x/10.0));var gz=int(floor(z/10.0));var P=Vector2(x,z)
	for i in range(-1,2):
		for j in range(-1,2):
			for k in SH_GRID.get(Vector2i(gx+i,gz+j),[]):
				var d=P.distance_to(SH_P[k])
				if d<best:best=d;bi=k
	var res=[SH_H[bi],Vector2(1,0),SH_P[bi]];var bd=1e9
	for nb in [bi-1,bi+1]:
		if nb<0 or nb>=SH_P.size() or SH_LID[nb]!=SH_LID[bi]:continue
		var A:Vector2=SH_P[min(bi,nb)];var B:Vector2=SH_P[max(bi,nb)]
		if A.distance_to(B)>2.6:continue
		var t=clamp((P-A).dot(B-A)/(B-A).length_squared(),0.0,1.0);var F=A.lerp(B,t)
		if P.distance_to(F)<bd:
			bd=P.distance_to(F)
			var hA=SH_H[min(bi,nb)];var hB=SH_H[max(bi,nb)]
			res=[lerp(hA,hB,t),(B-A).normalized(),F]
	return res
func wi_knoten_innen(lanes:Array,ln:Array,q:Vector2)->bool:
	return ln!=lanes[0] and q.distance_to(ln[0][0])<5.5
func wi_ende(lanes:Array,ln:Array,p:Vector2)->bool:
	return ln!=lanes[0] and p.distance_to(ln[0][-1])<11.0
func plot_ecken(pl:Dictionary,rand:float)->Array:
	var e=[]
	for k in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var l=Vector2(k.x*(pl.w*0.5+rand),k.y*(pl.d*0.5+rand))
		var cy=cos(pl.yaw);var sy=sin(pl.yaw)
		e.append(pl.c+Vector2(l.x*cy+l.y*sy,-l.x*sy+l.y*cy))
	return e
func sat_ueberlapp(a:Array,b:Array)->bool:
	for poly in [a,b]:
		for i in 4:
			var ed:Vector2=poly[(i+1)%4]-poly[i];var ax=Vector2(-ed.y,ed.x)
			var amin=1e9;var amax=-1e9;var bmin=1e9;var bmax=-1e9
			for p in a:var t=ax.dot(p);amin=min(amin,t);amax=max(amax,t)
			for p in b:var t=ax.dot(p);bmin=min(bmin,t);bmax=max(bmax,t)
			if amax<bmin or bmax<amin:return false
	return true
func sonnenhuegel(o:Vector3):
	SH_O=o
	var gras=L._shader(L.GRAS,{"farbe":Color(0.38,0.55,0.26)})
	var kopf=L._shader(L.PFLASTER,{"farbe":Color(0.62,0.56,0.5),"gr":0.24})
	var mauer=L._shader(L.ZIEGEL,{"farbe":Color(0.78,0.72,0.62),"fuge":Color(0.6,0.55,0.48),"bw":0.9,"bh":0.45})
	# Straßennetz: Hauptserpentine + Abzweige/Sackgassen
	var wege=[[Vector2(-160,12),Vector2(-70,4),Vector2(5,-14),Vector2(62,-10),Vector2(115,-38),Vector2(100,-74),Vector2(35,-82),Vector2(-25,-100),Vector2(-92,-92),Vector2(-138,-122),Vector2(-112,-156),Vector2(-40,-152),Vector2(32,-174),Vector2(98,-162),Vector2(136,-196),Vector2(80,-224),Vector2(5,-226)],
		[Vector2(5,-14),Vector2(-18,-40),Vector2(-58,-50),Vector2(-88,-44)],
		[Vector2(35,-82),Vector2(58,-112),Vector2(30,-130)],
		[Vector2(-40,-152),Vector2(-62,-186),Vector2(-108,-200)],
		[Vector2(98,-162),Vector2(140,-130),Vector2(150,-100)]]
	var lanes=[]
	for wi in wege.size():
		var pk=sh_kurve(wege[wi],2.0);var hs=[]
		for p in pk:hs.append(sh_basis(p.x,p.y))
		for it in 25:   # Steigung glätten
			var h2=hs.duplicate()
			for k in range(1,hs.size()-1):h2[k]=(hs[k-1]+hs[k]+hs[k+1])/3.0
			hs=h2
		if wi>0:   # Abzweig: auf den ersten 24 m exakt an die Höhe der Hauptstraße angleichen
			SH_KNOTEN.append(pk[0])
			var dist=0.0
			for k in hs.size():
				if k>0:dist+=pk[k].distance_to(pk[k-1])
				var t=clamp(dist/24.0,0.0,1.0);t=t*t*(3.0-2.0*t)
				var hm=sh_lane_genau(pk[k].x,pk[k].y)[0]
				if dist<24.0:hs[k]=lerp(hm,hs[k],t)
		lanes.append([pk,hs])
		var punkte=[]
		for k in pk.size():punkte.append([pk[k],hs[k]])
		if wi>0:   # Wendehammer: Fläche ins Gelände einebnen
			for rr in [2.0,4.0,6.0,8.0,10.0]:
				for a in 12:punkte.append([pk[-1]+Vector2(cos(TAU*a/12.0),sin(TAU*a/12.0))*rr,hs[-1]])
		for pt in punkte:
			SH_P.append(pt[0]);SH_H.append(pt[1]);SH_LID.append(wi)
			var key=Vector2i(int(floor(pt[0].x/10.0)),int(floor(pt[0].y/10.0)))
			if not SH_GRID.has(key):SH_GRID[key]=[]
			SH_GRID[key].append(SH_P.size()-1)
	# Grundstücke entlang der Straßen, links und rechts, gedreht zur Straße
	var versuche=0
	while SH_PLOTS.size()<60 and versuche<40000:
		versuche+=1
		var ln=lanes[rng.randi()%lanes.size()];var pk:Array=ln[0]
		if pk.size()<12:continue
		var i=rng.randi_range(4,pk.size()-5)
		var p:Vector2=pk[i];var dir:Vector2=(pk[i+3]-pk[i-3]).normalized();var nn=Vector2(-dir.y,dir.x)
		var side=1 if rng.randf()<0.5 else -1
		var w=rng.randf_range(30,50) if SH_PLOTS.size()>8 else rng.randf_range(46,56);var d=rng.randf_range(27,40) if SH_PLOTS.size()>8 else rng.randf_range(42,46)
		var front=p+nn*side*(3.6+9.0)
		var c=front+nn*side*(d*0.5)
		var zum_weg=-nn*side
		var pl={"c":c,"yaw":atan2(zum_weg.x,zum_weg.y),"w":w,"d":d,"h":0.0,"rh":ln[1][i],"rp":p,"tor":front}
		if abs(c.x)>160 or c.y>-4 or c.y<-240:continue
		var ec=plot_ecken(pl,1.5);var ok=true
		for q in SH_PLOTS:
			if q.c.distance_to(c)<(q.w+w)*0.8 and sat_ueberlapp(ec,plot_ecken(q,1.5)):ok=false;break
		if not ok:continue
		var e4=plot_ecken(pl,5.0)
		for k in SH_P.size():
			var q:Vector2=SH_P[k]
			if q.distance_to(c)>w:continue
			var l=sh_plot_lokal(pl,q.x,q.y)
			if abs(l.x)<w*0.5+4.2 and abs(l.y)<d*0.5+4.2:ok=false;break
		if not ok:continue
		pl.typ=["medi","modern","herren"][rng.randi()%3];pl.sgn=1 if rng.randf()<0.5 else -1
		var tx=villa_tor_x(w,pl.typ,pl.sgn);var cy=cos(pl.yaw);var sy=sin(pl.yaw)
		pl.tor=c+Vector2(tx*cy+d*0.5*sy,-tx*sy+d*0.5*cy)
		pl.rp=pl.tor+zum_weg*12.6;pl.rh=sh_lane_naechst(pl.rp.x,pl.rp.y).y
		# geschwungene Auffahrt: vom Tor raus, parallel zur Straße, am Ende fast rechtwinklig auf die Straße
		var rx=Vector2(cy,-sy);var sa=-1.0 if tx>0 else 1.0
		var T=pl.tor
		var ctrl=[T-zum_weg*1.0,T+zum_weg*2.2,T+zum_weg*4.4+rx*sa*6.0,T+zum_weg*4.8+rx*sa*14.0,T+zum_weg*6.4+rx*sa*20.0,T+zum_weg*9.0+rx*sa*23.0,T+zum_weg*12.0+rx*sa*24.0]
		var kp=sh_kurve(ctrl,0.5)
		var richt:Vector2=(kp[-1]-kp[-2]).normalized()
		for k in 40:kp.append(kp[-1]+richt*0.5)   # gerade weiter, bis die Straßenkante erreicht ist
		var ende=-1
		for k in range(4,kp.size()):
			if sh_lane_naechst(kp[k].x,kp[k].y).x<=RAND:ende=k;break
		if ende<0:continue
		var am_hammer=false
		for li in range(1,lanes.size()):
			if kp[ende].distance_to(lanes[li][0][-1])<15.0:am_hammer=true
		if am_hammer:continue
		# exakter Schnitt mit der Kante
		var d0=sh_lane_naechst(kp[ende-1].x,kp[ende-1].y).x;var d1=sh_lane_naechst(kp[ende].x,kp[ende].y).x
		var E:Vector2=kp[ende-1].lerp(kp[ende],clamp((d0-RAND)/max(d0-d1,0.001),0.0,1.0))
		kp=kp.slice(0,ende);kp.append(E)
		# Auffahrt darf keine andere Fahrbahn berühren
		var schlecht=false
		for k in kp.size()-1:
			if sh_lane_naechst(kp[k].x,kp[k].y).x<RAND+2.8 and k<kp.size()-8:schlecht=true;break
		if schlecht:continue
		var Lg=0.0;var acc=[0.0]
		for k in range(1,kp.size()):Lg+=kp[k].distance_to(kp[k-1]);acc.append(Lg)
		var ls=sh_lane_genau(E.x,E.y)
		pl.mund=ls   # [Höhe, Tangente, Mittelpunkt]
		var maxd=min(max(Lg-3.0,0.0)*0.075,3.0)
		pl.h=ls[0]+clamp(sh_basis(c.x,c.y)-ls[0],-maxd,maxd)
		var hs=[]
		for k in kp.size():
			var t=clamp((acc[k]-3.0)/max(Lg-3.0,1.0),0.0,1.0)
			hs.append(lerp(pl.h,ls[0],t*t*(3.0-2.0*t)))
		pl.rh=ls[0];pl.rp=ls[2]
		pl.zuf=[kp,hs]
		for k in kp.size():
			SH_ZUF.append([kp[k],hs[k]])
			var key=Vector2i(int(floor(kp[k].x/10.0)),int(floor(kp[k].y/10.0)))
			if not SH_ZGRID.has(key):SH_ZGRID[key]=[]
			SH_ZGRID[key].append(SH_ZUF.size()-1)
		SH_PLOTS.append(pl)
	print("GRUNDSTÜCKE ",SH_PLOTS.size())
	var falt=0
	for ln in lanes:
		var pk:Array=ln[0]
		for i in range(1,pk.size()-2):
			var d0:Vector2=(pk[i+1]-pk[i-1]).normalized();var d1:Vector2=(pk[i+2]-pk[i]).normalized()
			var ang=acos(clamp(d0.dot(d1),-1.0,1.0));var seg=pk[i].distance_to(pk[i+1])
			if ang>0.001 and seg/ang<3.6:falt+=1
	print("ENGE KEHREN-SEGMENTE (Radius < 3.6 m): ",falt)
	# Gelände
	var gs=L._st(gras,true)
	var xs=range(-170,171,2);var zs=range(-250,22,2)
	var H={}
	for x in xs:
		for z in zs:H[Vector2i(x,z)]=sh_hoehe(x,z)
	for i in xs.size()-1:
		for j in zs.size()-1:
			var x0=xs[i];var x1=xs[i+1];var z0=zs[j];var z1=zs[j+1]
			var a=o+Vector3(x0,H[Vector2i(x0,z0)],z0);var b=o+Vector3(x1,H[Vector2i(x1,z0)],z0)
			var c=o+Vector3(x1,H[Vector2i(x1,z1)],z1);var d=o+Vector3(x0,H[Vector2i(x0,z1)],z1)
			L._tri(gs,a,b,c,Vector3.UP);L._tri(gs,a,c,d,Vector3.UP)
	# Straßen: Asphalt, Randlinien, Mauern (talseits Brüstung, bergseits Stützmauer)
	var asph=L._st(L.M.asphalt,true);var lin=L._st(L.M.markierung,true)
	var torpunkte=[]
	for pl in SH_PLOTS:torpunkte.append(pl.rp)
	for ln in lanes:
		var pk:Array=ln[0];var hs:Array=ln[1]
		for i in pk.size()-1:
			var p:Vector2=pk[i];var q:Vector2=pk[i+1];var dir=(q-p).normalized();var nn=Vector2(-dir.y,dir.x)
			var dp:Vector2=(pk[min(i+1,pk.size()-1)]-pk[max(i-1,0)]).normalized();var dq:Vector2=(pk[min(i+2,pk.size()-1)]-pk[i]).normalized()
			var np=Vector2(-dp.y,dp.x);var nq=Vector2(-dq.y,dq.x)
			var hp=hs[i]+0.25;var hq=hs[i+1]+0.25
			var A=o+Vector3(p.x+np.x*3.6,hp,p.y+np.y*3.6);var Bq=o+Vector3(q.x+nq.x*3.6,hq,q.y+nq.y*3.6)
			var C=o+Vector3(q.x-nq.x*3.6,hq,q.y-nq.y*3.6);var D=o+Vector3(p.x-np.x*3.6,hp,p.y-np.y*3.6)
			# enge Kehre: Innenkante darf nicht rückwärts laufen (sonst faltet sich der Asphalt)
			if wi_knoten_innen(lanes,ln,q):continue   # wird von der Kreuzungsplatte abgedeckt
			var lid_s=lanes.find(ln)
			if lid_s>0 and p.distance_to(pk[0])<16.0:
				A.y=o.y+sh_strasse_h(Vector2(A.x-o.x,A.z-o.z),lid_s)+0.25;Bq.y=o.y+sh_strasse_h(Vector2(Bq.x-o.x,Bq.z-o.z),lid_s)+0.25
				C.y=o.y+sh_strasse_h(Vector2(C.x-o.x,C.z-o.z),lid_s)+0.25;D.y=o.y+sh_strasse_h(Vector2(D.x-o.x,D.z-o.z),lid_s)+0.25
			if Vector2(Bq.x-A.x,Bq.z-A.z).dot(dir)<0.05:Bq=A
			if Vector2(C.x-D.x,C.z-D.z).dot(dir)<0.05:C=D
			L._tri(asph,A,Bq,C,Vector3.UP);L._tri(asph,A,C,D,Vector3.UP)
			for sd in [-1,1]:
				if wi_ende(lanes,ln,p):continue
				var am_knoten=false
				for J in SH_KNOTEN:
					if p.distance_to(J)<9.0:am_knoten=true
				if am_knoten:continue
				var a0=o+Vector3(p.x+np.x*sd*3.2,hp+0.02,p.y+np.y*sd*3.2);var a1=o+Vector3(q.x+nq.x*sd*3.2,hq+0.02,q.y+nq.y*sd*3.2)
				var w0=o+Vector3(p.x+np.x*sd*3.05,hp+0.02,p.y+np.y*sd*3.05);var w1=o+Vector3(q.x+nq.x*sd*3.05,hq+0.02,q.y+nq.y*sd*3.05)
				L._tri(lin,a0,a1,w1,Vector3.UP);L._tri(lin,a0,w1,w0,Vector3.UP)
			var lz=false
			for zz in SH_ZUF:
				if (zz[0] as Vector2).distance_to(p)<9.0:lz=true;break
			if i%18==9 and not lz:
				var sd=1 if (i/18)%2==0 else -1
				L._laterne(o+Vector3(p.x+nn.x*sd*4.0,hp,p.y+nn.y*sd*4.0),Vector3(-nn.x*sd,0,-nn.y*sd))
		# Kreuzungsplatte: füllt die Ecken zwischen Haupt- und Nebenstraße (Höhe = Hauptstraße)
		if lanes.find(ln)>0:
			var J:Vector2=pk[0];var pb=pk.slice(0,min(14,pk.size()))
			var ring=[];var R=[0.0,2.0,4.0,5.5,7.0,8.5]
			for ri in R.size():
				var rr=[]
				for a in 24:
					var P=J+Vector2(cos(TAU*a/24.0),sin(TAU*a/24.0))*R[ri]
					rr.append(P)
				ring.append(rr)
			var drin=func(P:Vector2)->bool:
				var d0=sh_abst_lane0(P);var db=1e9
				for q in pb:db=min(db,P.distance_to(q))
				return d0<=RAND+0.01 or db<=RAND+0.01 or (d0<=RAND+2.2 and db<=RAND+2.2)
			var lidp=lanes.find(ln)
			var H0=func(P:Vector2)->Vector3:return o+Vector3(P.x,sh_strasse_h(P,lidp)+0.252,P.y)
			for ri in R.size()-1:
				for a in 24:
					var a2=(a+1)%24
					var p00:Vector2=ring[ri][a];var p01:Vector2=ring[ri][a2];var p10:Vector2=ring[ri+1][a];var p11:Vector2=ring[ri+1][a2]
					if drin.call(p00) and drin.call(p10) and drin.call(p11):L._tri(asph,H0.call(p00),H0.call(p10),H0.call(p11),Vector3.UP)
					if drin.call(p00) and drin.call(p11) and drin.call(p01):L._tri(asph,H0.call(p00),H0.call(p11),H0.call(p01),Vector3.UP)
		# Mauern: durchgehend, Höhe geglättet; Lücken an Auffahrten und Einmündungen
		var li=lanes.find(ln)
		for sd in [-1,1]:
			var hoch=[];var an=[]
			for i in pk.size():
				var p:Vector2=pk[i];var dir:Vector2=(pk[min(i+1,pk.size()-1)]-pk[max(i-1,0)]).normalized();var nn=Vector2(-dir.y,dir.x)
				var wp=p+nn*sd*4.3
				var gel=sh_hoehe(wp.x+nn.x*sd*3.0,wp.y+nn.y*sd*3.0)-hs[i]
				hoch.append(clamp(gel+0.7,1.0,5.0))
				var frei=true
				var gx2=int(floor(wp.x/10.0));var gz2=int(floor(wp.y/10.0))
				for ii in range(-1,2):
					for jj in range(-1,2):
						for k in SH_ZGRID.get(Vector2i(gx2+ii,gz2+jj),[]):
							if (SH_ZUF[k][0] as Vector2).distance_to(wp)<6.2:frei=false
						for k in SH_GRID.get(Vector2i(gx2+ii,gz2+jj),[]):
							if SH_LID[k]!=li and (SH_P[k] as Vector2).distance_to(wp)<6.0:frei=false
				if li>0 and wp.distance_to(pk[-1])<13.0:frei=false
				an.append(frei)
			for it in 6:
				var h2=hoch.duplicate()
				for i in range(1,hoch.size()-1):h2[i]=(hoch[i-1]+hoch[i]*2.0+hoch[i+1])/4.0
				hoch=h2
			for i in pk.size()-1:
				if not (an[i] and an[i+1]):continue
				var p:Vector2=pk[i];var q:Vector2=pk[i+1]
				var dp:Vector2=(pk[min(i+1,pk.size()-1)]-pk[max(i-1,0)]).normalized();var dq:Vector2=(pk[min(i+2,pk.size()-1)]-pk[i]).normalized()
				var np=Vector2(-dp.y,dp.x)*sd;var nq=Vector2(-dq.y,dq.x)*sd
				var hp=hs[i]+0.25;var hq=hs[i+1]+0.25
				var i0=p+np*4.0;var i1=q+nq*4.0;var a0=p+np*4.6;var a1=q+nq*4.6
				L.hex(mauer,[o+Vector3(i0.x,hp-1.5,i0.y),o+Vector3(i1.x,hq-1.5,i1.y),o+Vector3(a1.x,hq-1.5,a1.y),o+Vector3(a0.x,hp-1.5,a0.y),
					o+Vector3(i0.x,hp+hoch[i],i0.y),o+Vector3(i1.x,hq+hoch[i+1],i1.y),o+Vector3(a1.x,hq+hoch[i+1],a1.y),o+Vector3(a0.x,hp+hoch[i],a0.y)],0.0)
				var j0=p+np*3.9;var j1=q+nq*3.9;var b0=p+np*4.7;var b1=q+nq*4.7
				L.hex(L.M.stein,[o+Vector3(j0.x,hp+hoch[i],j0.y),o+Vector3(j1.x,hq+hoch[i+1],j1.y),o+Vector3(b1.x,hq+hoch[i+1],b1.y),o+Vector3(b0.x,hp+hoch[i],b0.y),
					o+Vector3(j0.x,hp+hoch[i]+0.14,j0.y),o+Vector3(j1.x,hq+hoch[i+1]+0.14,j1.y),o+Vector3(b1.x,hq+hoch[i+1]+0.14,b1.y),o+Vector3(b0.x,hp+hoch[i]+0.14,b0.y)],0.0)
				# Konturlinie oben
				L.zyl(L.M.linie,o+Vector3(b0.x,hp+hoch[i]+0.15,b0.y),o+Vector3(b1.x,hq+hoch[i+1]+0.15,b1.y),0.025,1.0)
		# Wendehammer am Ende von Abzweigen
		if ln!=lanes[0]:
			var ende:Vector2=pk[-1];var he=hs[-1]+0.1
			L.zyl(L.M.asphalt,o+Vector3(ende.x,he-0.3,ende.y),o+Vector3(ende.x,he+0.12,ende.y),9.5,1.0)
	# Bepflanzung am Hang
	var n=0;var tries=0
	while n<260 and tries<5000:
		tries+=1
		var x=rng.randf_range(-165,165);var z=rng.randf_range(-245,-2)
		if sh_lane_naechst(x,z).x<7.0:continue
		var frei=true
		for pl in SH_PLOTS:
			var l=sh_plot_lokal(pl,x,z)
			if abs(l.x)<pl.w*0.5+2.5 and abs(l.y)<pl.d*0.5+12.0:frei=false;break
		if not frei:continue
		var p=o+Vector3(x,sh_hoehe(x,z)-0.1,z);var art=rng.randf()
		if art<0.4:
			for k in 3:L.kugel(L.M.laub[rng.randi()%3],p+Vector3(rng.randf_range(-1,1),0.6,rng.randf_range(-1,1)),Vector3(1.0,0.8,1.0)*rng.randf_range(0.7,1.4))
		elif art<0.65:zypresse(p,rng.randf_range(5,9))
		elif art<0.85:palme(p,rng.randf_range(7,12))
		else:L._baum(p)
		n+=1
	# Zufahrten: Querschnitte berechnen (am Ende Trichter, Endkante exakt auf der Straßenkante)
	var bericht=[]
	for pl in SH_PLOTS:
		var kp:Array=pl.zuf[0];var hs:Array=pl.zuf[1];var nz=kp.size()
		var ls:Array=pl.mund;var tan:Vector2=ls[1];var fuss:Vector2=ls[2]
		var Lg=0.0;var acc=[0.0]
		for k in range(1,nz):Lg+=kp[k].distance_to(kp[k-1]);acc.append(Lg)
		var QL=[];var QR=[]
		for k in nz:
			var d:Vector2=(kp[min(k+1,nz-1)]-kp[max(k-1,0)]).normalized();var nn=Vector2(-d.y,d.x)
			var rest=Lg-acc[k];var hb=2.5+1.6*clamp(1.0-rest/4.0,0.0,1.0)   # Trichter auf den letzten 4 m
			var l2:Vector2=kp[k]+nn*hb;var r2:Vector2=kp[k]-nn*hb
			if k==nz-1:   # Endkante liegt auf der Straßenkante (parallel zur Fahrbahn)
				var E:Vector2=kp[k];var sg=sign(nn.dot(tan))
				l2=E+tan*sg*hb;r2=E-tan*sg*hb
				l2=sh_auf_kante(l2);r2=sh_auf_kante(r2)
			else:   # keine Ecke darf in die Fahrbahn ragen
				if sh_abst(l2)<RAND:l2=sh_auf_kante(l2)
				if sh_abst(r2)<RAND:r2=sh_auf_kante(r2)
			var hl=hs[k];var hr=hs[k]
			if rest<4.0:   # im Trichter: Höhe = Straßenhöhe an der Kante (bündig, ohne Kante)
				var t=clamp(1.0-rest/4.0,0.0,1.0)
				hl=lerp(hs[k],sh_lane_genau(l2.x,l2.y)[0],t);hr=lerp(hs[k],sh_lane_genau(r2.x,r2.y)[0],t)
			QL.append([l2,hl]);QR.append([r2,hr])
		pl.QL=QL;pl.QR=QR
		# Messwerte: Endkante zur Fahrbahnmitte, Höhenversatz, Steigung, Knick
		var emin=1e9;var emax=-1e9;var dh=0.0
		for q in [QL[-1],QR[-1]]:
			var dd=sh_abst(q[0]);emin=min(emin,dd);emax=max(emax,dd)
			dh=max(dh,abs(q[1]-sh_lane_genau(q[0].x,q[0].y)[0]))
		var innen=1e9
		for k in nz-1:
			for q in [QL[k],QR[k]]:innen=min(innen,sh_abst(q[0]))
		var st=0.0;var kn=0.0;var prev=null
		for k in range(1,nz):
			var sl=(hs[k]-hs[k-1])/max(acc[k]-acc[k-1],0.01);st=max(st,abs(sl))
			if prev!=null:kn=max(kn,abs(sl-prev))
			prev=sl
		bericht.append([emin,emax,dh,innen,st,kn,Lg])
		pl.mess=bericht[-1]
	print("ZUFAHRT-PRUEFUNG (Kante soll %.2f, innen >= %.2f):"%[RAND,RAND])
	var fehler=0
	for i in bericht.size():
		var b=bericht[i];var ok=abs(b[0]-RAND)<0.08 and abs(b[1]-RAND)<0.08 and b[2]<0.03 and b[3]>=RAND-0.05 and b[4]<0.13 and b[5]<0.02
		if not ok:fehler+=1
		print("  %2d Kante %.2f..%.2f  Hoehenversatz %.3f  min.Abstand %.2f  max.Steigung %4.1f%%  Knick %.3f  Laenge %.0fm  %s"%[i,b[0],b[1],b[2],b[3],b[4]*100.0,b[5],b[6],"OK" if ok else "FEHLER"])
	print("ZUFAHRT-FEHLER ",fehler)
	# Bauen
	for pl in SH_PLOTS:
		var QL:Array=pl.QL;var QR:Array=pl.QR;var nz=QL.size();var ks=L._st(kopf,true)
		var Lg=pl.mess[6];var acc=0.0
		for k in nz-1:
			var a0=o+Vector3(QL[k][0].x,QL[k][1]+0.25,QL[k][0].y);var a1=o+Vector3(QL[k+1][0].x,QL[k+1][1]+0.25,QL[k+1][0].y)
			var b0=o+Vector3(QR[k][0].x,QR[k][1]+0.25,QR[k][0].y);var b1=o+Vector3(QR[k+1][0].x,QR[k+1][1]+0.25,QR[k+1][0].y)
			L._tri(ks,a0,a1,b1,Vector3.UP);L._tri(ks,a0,b1,b0,Vector3.UP)
			var kp:Array=pl.zuf[0];acc+=kp[k].distance_to(kp[k+1]);var rest=Lg-acc
			if rest<5.0:   # Trichter: flache Platte im Gelände, keine Bordsteine
				L.hex(kopf,[a0-Vector3(0,0.7,0),a1-Vector3(0,0.7,0),b1-Vector3(0,0.7,0),b0-Vector3(0,0.7,0),a0-Vector3(0,0.01,0),a1-Vector3(0,0.01,0),b1-Vector3(0,0.01,0),b0-Vector3(0,0.01,0)],0.0)
				continue
			# Damm bis unter das Gelände
			var u=min(a0.y,a1.y,b0.y,b1.y)-5.5
			L.hex(mauer,[Vector3(a0.x,u,a0.z),Vector3(a1.x,u,a1.z),Vector3(b1.x,u,b1.z),Vector3(b0.x,u,b0.z),a0-Vector3(0,0.02,0),a1-Vector3(0,0.02,0),b1-Vector3(0,0.02,0),b0-Vector3(0,0.02,0)],0.0)
			for sd in [[a0,a1,b0,b1],[b0,b1,a0,a1]]:
				var p0:Vector3=sd[0];var p1:Vector3=sd[1];var i0:Vector3=(sd[2]-p0).normalized()*0.3;var i1:Vector3=(sd[3]-p1).normalized()*0.3
				L.hex(L.M.stein,[p0-Vector3(0,0.1,0),p1-Vector3(0,0.1,0),p1+i1-Vector3(0,0.1,0),p0+i0-Vector3(0,0.1,0),p0+Vector3(0,0.45,0),p1+Vector3(0,0.45,0),p1+i1+Vector3(0,0.45,0),p0+i0+Vector3(0,0.45,0)],0.015)
	L._fertig()
	# Villen: jede als eigener, gedrehter Knoten
	var typen=["medi","modern","herren"]
	var i=0;var welt_alt=L.welt
	for pl in SH_PLOTS:
		var node=Node3D.new();W.add_child(node);L.welt=node;AUTO_ELTERN=node
		villa_lokal(pl.w,pl.d,pl.typ,kopf,mauer,pl.sgn)
		L._fertig();L.welt=welt_alt;AUTO_ELTERN=null
		node.transform=Transform3D(Y(pl.yaw),o+Vector3(pl.c.x,pl.h,pl.c.y))
		i+=1
	L._schrift("SONNENHÜGEL",o+Vector3(0,sh_basis(0,-240)+14,-240),Basis(Vector3(1,0,0),-0.25),0.13,Color(0.98,0.98,0.95),Color(0.15,0.12,0.1),96)
	auto("c_sport_rot",o+Vector3(lanes[0][0][40].x,lanes[0][1][40]+0.1,lanes[0][0][40].y),atan2((lanes[0][0][41]-lanes[0][0][39]).x,(lanes[0][0][41]-lanes[0][0][39]).y))
	# Kameras
	KAM.append(["sonnenhuegel","Sonnenhügel",o+Vector3(-20,75,70),o+Vector3(0,25,-110)])
	var mk=lanes[0];var ki=int(mk[0].size()*0.47)
	var kp:Vector2=mk[0][ki];var kq:Vector2=mk[0][ki+14]
	KAM.append(["sonnenhuegel_strasse","Sonnenhügel – Serpentinenstraße",o+Vector3(kp.x,mk[1][ki]+2.6,kp.y),o+Vector3(kq.x,mk[1][ki+14]+3.0,kq.y)])
	var best=SH_PLOTS[0];var bd=1e9
	for pl in SH_PLOTS:
		var dd=pl.c.distance_to(Vector2(0,-100))
		if dd<bd:bd=dd;best=pl
	var rp:Vector2=best.rp;var tor:Vector2=best.tor;var dirr=(tor-rp).normalized()
	var cam=rp-dirr*16.0+Vector2(-dirr.y,dirr.x)*8.0
	if OS.get_cmdline_user_args().has("pruef"):
		for ji in SH_KNOTEN.size():
			var J:Vector2=SH_KNOTEN[ji];var hj=sh_lane0_hoehe(J)
			KAM.append(["pruef_knoten_%d_oben"%ji,"Abzweig %d von oben"%ji,o+Vector3(J.x,hj+28,J.y+0.1),o+Vector3(J.x,hj,J.y)])
			var lp=sh_lane0_info(J+Vector2(14,0));var pp:Vector2=lp[1]
			KAM.append(["pruef_knoten_%d_fahrer"%ji,"Abzweig %d Fahrersicht"%ji,o+Vector3(pp.x,lp[0]+1.9,pp.y),o+Vector3(J.x,hj+0.8,J.y)])
		for t in SH_PLOTS.size():
			var pl=SH_PLOTS[t];var zk:Array=pl.zuf[0];var mid:Vector2=zk[int(zk.size()*0.5)]
			var aus:Vector2=(pl.rp-pl.tor).normalized();var quer=Vector2(-aus.y,aus.x)
			var bestc=Vector2.ZERO;var besth=-1e9
			for cand in [mid+aus*16.0+quer*14.0,mid+aus*16.0-quer*14.0,mid-quer*22.0,mid+quer*22.0]:
				var hh=-sh_hoehe(cand.x,cand.y)
				if hh>besth:besth=hh;bestc=cand
			var mf:Vector2=pl.mund[2];var tg:Vector2=pl.mund[1];var zk2:Array=pl.zuf[0];var E2:Vector2=zk2[-1];var rein=(E2-mf).normalized()
			var fp=mf-rein*1.5-tg*12.0;var hh2=sh_lane_genau(fp.x,fp.y)[0]
			if t==6:KAM.append(["pruef_oben_06","Draufsicht 6",o+Vector3(fp.x,hh2+30,fp.y+0.1),o+Vector3(fp.x,hh2,fp.y)])
			KAM.append(["pruef_mund_%02d"%t,"Einmündung %d (Fahrersicht)"%t,o+Vector3(fp.x,hh2+1.7,fp.y),o+Vector3(E2.x+rein.x*6.0,pl.mund[0]+1.0,E2.y+rein.y*6.0)])
			KAM.append(["pruef_zufahrt_%02d"%t,"Prüfung Zufahrt %d"%t,o+Vector3(bestc.x,max(pl.h,sh_hoehe(bestc.x,bestc.y))+9.0,bestc.y),o+Vector3(mid.x,pl.h-1.0,mid.y)])
	KAM.append(["sonnenhuegel_villa","Sonnenhügel – Villa mit Zufahrt",o+Vector3(cam.x,best.h+12,cam.y),o+Vector3(best.c.x,best.h+3,best.c.y)])

func zypresse(p:Vector3,h:=6.0):
	L.zyl(L.M.rinde,p,p+Vector3(0,1.0,0),0.15,1.2)
	L.kugel(T(Color(0.18,0.38,0.2)),p+Vector3(0,h*0.55,0),Vector3(0.75,h*0.5,0.75))
func walmdach(c:Vector3,w:float,d:float,h:float,col:Color,ue:=0.6):
	var r=max(w-d,0.0)*0.5
	L.hex(T(col),[c+Vector3(-w*0.5-ue,-0.15,-d*0.5-ue),c+Vector3(w*0.5+ue,-0.15,-d*0.5-ue),c+Vector3(w*0.5+ue,-0.15,d*0.5+ue),c+Vector3(-w*0.5-ue,-0.15,d*0.5+ue),
		c+Vector3(-r,h,0),c+Vector3(r,h,0),c+Vector3(r,h,0),c+Vector3(-r,h,0)],0.04)
func balustrade(a:Vector3,e:Vector3,m:Material):
	var d=e-a;var Lg=d.length();var t=d/Lg;var b=rich(t)
	L.box(m,(a+e)*0.5+Vector3(0,0.95,0),Vector3(0.3,0.12,Lg),b,0.02)
	L.box(m,(a+e)*0.5+Vector3(0,0.06,0),Vector3(0.3,0.12,Lg),b,0.0)
	var k=0.2
	while k<Lg:L.zyl(m,a+t*k,a+t*k+Vector3(0,0.9,0),0.07,1.0);k+=0.35
func pool(c:Vector3,w:float,d:float):
	B(L.M.stein,c+Vector3(0,0.12,0),Vector3(w+1.2,0.24,d+1.2),0.0,0.02)
	B(T(Color(0.25,0.82,0.98),0.05),c+Vector3(0,0.26,0),Vector3(w,0.04,d),0.0,0.0)
	for k in 3:
		var q=c+Vector3(-w*0.5+1.2+k*1.6,0.24,d*0.5+1.8)
		B(L.M.weiss,q+Vector3(0,0.3,0),Vector3(0.75,0.12,1.9),0.0,0.015);B(L.M.weiss,q+Vector3(0,0.55,-0.85),Vector3(0.75,0.5,0.1),0.0,0.0)
func garagen(c:Vector3,n:int,wand:Material,dach:Color):
	var w=n*3.4+0.6
	B(wand,c+Vector3(0,1.6,0),Vector3(w,3.2,6.5),0.0,0.04)
	walmdach(c+Vector3(0,3.2,0),w,6.5,1.6,dach,0.4)
	for k in n:
		var q=c+Vector3(-w*0.5+0.3+(k+0.5)*3.4,1.2,3.27)
		B(T(Color(0.4,0.3,0.22)),q,Vector3(2.8,2.4,0.08),0.0,0.02)
		for y in range(5):B(T(Color(0.32,0.24,0.18)),q+Vector3(0,-1.0+y*0.5,0.05),Vector3(2.7,0.05,0.03),0.0,0.0)
func tennis(c0:Vector3,yaw:=0.0):
	var R=Y(yaw)
	var Bx=func(m,v:Vector3,sz:Vector3):L.box(m,c0+R*v,sz,R,0.0)
	Bx.call(T(Color(0.75,0.38,0.25)),Vector3(0,0.05,0),Vector3(15,0.1,28))
	Bx.call(T(Color(0.28,0.55,0.4)),Vector3(0,0.1,0),Vector3(10.97,0.02,23.77))
	for x in [-5.4,-4.1,4.1,5.4]:Bx.call(L.M.weiss,Vector3(x,0.12,0),Vector3(0.08,0.01,23.77))
	for z in [-11.85,-6.4,6.4,11.85]:Bx.call(L.M.weiss,Vector3(0,0.12,z),Vector3(10.97 if abs(z)>10 else 8.23,0.01,0.08))
	Bx.call(L.M.weiss,Vector3(0,0.12,0),Vector3(0.08,0.01,12.8))
	Bx.call(L.M.dunkel,Vector3(0,0.55,0),Vector3(11.5,0.9,0.02));Bx.call(L.M.weiss,Vector3(0,1.0,0),Vector3(11.5,0.08,0.04))
	for k in 4:
		var e0=[Vector3(-7.5,0,-14),Vector3(7.5,0,-14),Vector3(7.5,0,14),Vector3(-7.5,0,14)][k];var e1=[Vector3(7.5,0,-14),Vector3(7.5,0,14),Vector3(-7.5,0,14),Vector3(-7.5,0,-14)][k]
		L._zaun(c0+R*e0,c0+R*e1,3.0)
# Villa im lokalen Raum: Mitte (0,0,0) = Plateau, Front (Tor) bei +z
func villa_tor_x(w:float,typ:String,sgn:int)->float:
	var hw={"medi":18.0,"modern":22.0,"herren":20.0}[typ];var ng={"medi":3,"modern":2,"herren":3}[typ];var gw=ng*3.4+0.6
	var hx=-sgn*w*0.12
	return clamp(hx+sgn*(hw*0.5+gw*0.5+1.5),-w*0.5+gw*0.5+1.5,w*0.5-gw*0.5-1.5)
func villa_lokal(w:float,d:float,typ:String,kopf:Material,mauer:Material,sgn:int):
	var c=Vector3.ZERO
	B(mauer,Vector3(0,-7.0,0),Vector3(w,14.4,d),0.0,0.05)          # Sockel/Stützmauer
	B(L.M.gras,Vector3(0,0.15,0),Vector3(w-0.4,0.1,d-0.4),0.0,0.0)
	var hw={"medi":18.0,"modern":22.0,"herren":20.0}[typ];var hd={"medi":11.0,"modern":10.0,"herren":10.0}[typ]
	var hx=-sgn*w*0.12;var hz=-d*0.5+hd*0.5+3.0
	var ng={"medi":3,"modern":2,"herren":3}[typ];var gw=ng*3.4+0.6
	var gx=hx+sgn*(hw*0.5+gw*0.5+1.5);gx=clamp(gx,-w*0.5+gw*0.5+1.5,w*0.5-gw*0.5-1.5)
	var gz=-d*0.5+3.25+3.0
	var tx=gx
	# hohe Mauer vorn mit Tor, Seiten/hinten Mauer + Hecke
	for sd in [-1,1]:
		var x0=tx+sd*3.0;var x1=sd*w*0.5;var lg=abs(x1-x0)
		if lg>0.3:
			B(mauer,Vector3((x0+x1)*0.5,1.3,d*0.5-0.3),Vector3(lg,2.6,0.6),0.0,0.03)
			B(L.M.stein,Vector3((x0+x1)*0.5,2.66,d*0.5-0.3),Vector3(lg,0.14,0.75),0.0,0.0)
		B(L.M.stein,Vector3(tx+sd*3.0,1.6,d*0.5-0.3),Vector3(0.9,3.2,0.9),0.0,0.03)
		L.box(L.M.lampe,Vector3(tx+sd*3.0,3.45,d*0.5-0.3),Vector3(0.4,0.5,0.4),Basis(),0.02)
		B(mauer,Vector3(sd*(w*0.5-0.3),1.1,0),Vector3(0.6,2.2,d),0.0,0.03)
		B(L.M.laub[2],Vector3(sd*(w*0.5-1.4),1.5,0),Vector3(1.4,3.0,d-2),0.0,0.04)
	B(mauer,Vector3(0,1.1,-d*0.5+0.3),Vector3(w,2.2,0.6),0.0,0.03)
	# Schiebetor (halb offen)
	B(L.M.metall,Vector3(tx-2.2,1.2,d*0.5-0.75),Vector3(2.4,2.0,0.08),0.0,0.0)
	for k in 6:B(L.M.metall,Vector3(tx-3.2+k*0.4,1.2,d*0.5-0.75),Vector3(0.06,2.0,0.1),0.0,0.0)
	# Hof von Tor bis Garage
	B(kopf,Vector3(tx,0.2,(gz+3.25+d*0.5)*0.5),Vector3(max(gw,6.0)+1.0,0.06,d*0.5-gz-3.25),0.0,0.0)
	garagen(Vector3(gx,0.2,gz),ng,L._shader(L.PUTZ,{"farbe":Color(0.95,0.9,0.8)}) if typ!="modern" else L.M.weiss,{"medi":Color(0.75,0.36,0.22),"modern":Color(0.3,0.3,0.32),"herren":Color(0.28,0.3,0.36)}[typ])
	auto(["c_luxus_schwarz","c_sport_gelb","c_luxus_silber","c_sport_rot","c_suv_grau"][rng.randi()%5],Vector3(tx+rng.randf_range(-1,1),0.23,gz+9.0),PI+rng.randf_range(-0.3,0.3))
	var hc=Vector3(hx,0.2,hz)
	var putz=[Color(0.98,0.88,0.7),Color(0.96,0.8,0.68),Color(0.97,0.95,0.9),Color(0.9,0.84,0.72)]
	match typ:
		"medi":
			var wand=L._shader(L.PUTZ,{"farbe":putz[rng.randi()%putz.size()]})
			B(wand,hc+Vector3(0,3.4,0),Vector3(18,6.8,11),0.0,0.05)
			walmdach(hc+Vector3(0,6.8,0),18,11,3.2,Color(0.75,0.36,0.22))
			B(wand,hc+Vector3(-sgn*9.5,5.0,-1),Vector3(5,10,5),0.0,0.05);walmdach(hc+Vector3(-sgn*9.5,10,-1),5,5,2.2,Color(0.75,0.36,0.22),0.4)
			for e in 2:
				for k in 5:
					var q=hc+Vector3(-7+k*3.5,1.9+e*3.3,5.53)
					B(T(Color(0.2,0.25,0.3)),q,Vector3(1.2,2.0,0.05),0.0,0.0);L.zyl(T(Color(0.2,0.25,0.3)),q+Vector3(0,1.0,-0.02),q+Vector3(0,1.0,0.03),0.6,1.0)
					B(T(Color(0.25,0.45,0.35)),q+Vector3(-0.85,0,0.05),Vector3(0.45,2.0,0.05),0.0,0.01);B(T(Color(0.25,0.45,0.35)),q+Vector3(0.85,0,0.05),Vector3(0.45,2.0,0.05),0.0,0.01)
			B(L.M.stein,hc+Vector3(0,0.35,8.5),Vector3(22,0.3,6),0.0,0.02)
			balustrade(hc+Vector3(-11,0.5,11.4),hc+Vector3(11,0.5,11.4),L.M.weiss)
			pool(Vector3(hx-sgn*2.0,0.2,hz+hd*0.5+11.0),11,5)
			for k in 4:zypresse(Vector3(-sgn*(w*0.5-2.6),0.2,-d*0.5+3+k*5.5),rng.randf_range(5,7))
			palme(Vector3(hx-sgn*9,0.2,hz+hd*0.5+16),9)
		"modern":
			var holz=T(Color(0.58,0.4,0.26))
			B(L.M.weiss,hc+Vector3(0,1.8,0),Vector3(22,3.6,10),0.0,0.05)
			B(klarglas(),hc+Vector3(0,1.8,5.03),Vector3(20,3.0,0.05),0.0,0.0)
			B(holz,hc+Vector3(-sgn*3,5.4,1),Vector3(16,3.6,11),0.0,0.05)
			B(L.M.glas[1],hc+Vector3(-sgn*3,5.4,6.53),Vector3(14,2.8,0.05),0.0,0.0)
			B(L.M.weiss,hc+Vector3(0,3.75,1),Vector3(26,0.3,14),0.0,0.03);B(L.M.weiss,hc+Vector3(-sgn*3,7.35,1),Vector3(19,0.3,14),0.0,0.03)
			B(klarglas(),hc+Vector3(0,4.4,8.0),Vector3(26,1.0,0.05),0.0,0.0)
			B(L.M.stein,Vector3(hx,0.3,hz+hd*0.5+6.0),Vector3(26,0.25,9),0.0,0.0)
			pool(Vector3(hx,0.3,hz+hd*0.5+7.5),18,4.0)
			for k in 3:palme(Vector3(-sgn*(w*0.5-3),0.2,-d*0.5+4+k*6),rng.randf_range(8,10))
		"herren":
			var wand=L._shader(L.PUTZ,{"farbe":Color(0.94,0.92,0.86)})
			B(wand,hc+Vector3(0,3.6,0),Vector3(20,7.2,10),0.0,0.05)
			walmdach(hc+Vector3(0,7.2,0),20,10,3.4,Color(0.28,0.3,0.36))
			for x in [-3.0,-1.0,1.0,3.0]:L.zyl(L.M.weiss,hc+Vector3(x,0,6.5),hc+Vector3(x,6.2,6.5),0.32,1.08)
			B(L.M.weiss,hc+Vector3(0,6.5,5.8),Vector3(8.4,0.6,2.2),0.0,0.03)
			var st=L._st(L.M.weiss,true)
			L._tri(st,hc+Vector3(-4.2,6.8,6.9),hc+Vector3(4.2,6.8,6.9),hc+Vector3(0,8.6,6.9),Vector3(0,0,1))
			for e in 2:
				for k in 6:
					if e==0 and abs(k-2.5)<1:continue
					fenster(hc+Vector3(-8.3+k*3.3,2.0+e*3.4,5.05),Basis(),1.1,1.9,L.M.glas[1])
			B(T(Color(0.3,0.22,0.16)),hc+Vector3(0,1.3,5.06),Vector3(1.6,2.6,0.05),0.0,0.0)
			for k in 3:B(L.M.stein,hc+Vector3(0,0.1+k*0.15,6.8+k*0.5),Vector3(8,0.15,1.0),0.0,0.02)
			var fb=Vector3(hx,0.2,hz+hd*0.5+7.0)
			L.zyl(L.M.stein,fb,fb+Vector3(0,0.5,0),2.4,1.03);L.zyl(T(Color(0.3,0.65,0.9),0.1),fb+Vector3(0,0.5,0),fb+Vector3(0,0.54,0),2.1)
			L.zyl(L.M.stein,fb,fb+Vector3(0,1.8,0),0.25,1.1);L.kugel(L.M.stein,fb+Vector3(0,1.9,0),Vector3(0.6,0.25,0.6))
			for k in 3:zypresse(Vector3(-sgn*(w*0.5-2.6),0.2,-d*0.5+3+k*6),6.5)
	# Tennisplatz auf großen Grundstücken (vorn, gegenüber vom Hof)
	if d>=42 and w>=46:
		tennis(Vector3(-sgn*(w*0.5-15.5),0.2,d*0.5-9.5),PI*0.5)
	elif typ!="modern":
		pool(Vector3(-sgn*(w*0.5-8),0.2,d*0.5-7),8,4)

# ================= OSTSTADT =================
func oststadt(o:Vector3):
	var lang=220.0
	flaeche(L.M.gras,o,lang+80,200,-0.01)
	strasse(o,lang,7.0,5.0,true)
	var platte=[T(Color(0.85,0.82,0.74)),T(Color(0.78,0.8,0.78)),T(Color(0.88,0.84,0.7))]
	var paneele=[T(Color(0.85,0.35,0.2)),T(Color(0.3,0.55,0.75)),T(Color(0.95,0.75,0.2)),T(Color(0.4,0.65,0.4))]
	for s in [-1,1]:
		var x=-lang*0.5+20
		while x<lang*0.5-10:
			var w=rng.randf_range(50,70)
			block(o+Vector3(x+w*0.5,0,s*(22+6)),w,12,rng.randi_range(6,11),platte[rng.randi()%3],L.M.glas[rng.randi()%2],0.0 if s<0 else PI,true,paneele)
			x+=w+14
	# Fernsehturm im Hintergrund
	var ft=o+Vector3(60,0,-160)
	L.zyl(L.M.stein,ft,ft+Vector3(0,120,0),4.0,1.03);L.zyl(L.M.stein,ft+Vector3(0,120,0),ft+Vector3(0,160,0),2.0,1.05)
	L.kugel(T(Color(0.7,0.72,0.78),0.2),ft+Vector3(0,128,0),Vector3(13,13,13),1.03)
	L.zyl(L.M.rot,ft+Vector3(0,160,0),ft+Vector3(0,180,0),0.6,1.1)
	# moderne Türme dahinter
	for k in 8:turm(o+Vector3(-120+k*34,0,170+rng.randf_range(0,40)),22,22,rng.randf_range(50,110),L.M.glas[1+k%3],L.M.weiss,3.6,3.2)
	# Straßenbahn
	var sb=o+Vector3(-20,0,-2.0)
	L.box(T(Color(0.95,0.8,0.2)),sb+Vector3(0,1.8,0),Vector3(26,3.0,2.5),Basis(),0.05)
	L.box(L.M.weiss,sb+Vector3(0,0.6,0),Vector3(26,0.6,2.52),Basis(),0.0)
	L.box(L.M.glas[1],sb+Vector3(0,2.3,1.27),Vector3(24,1.2,0.04),Basis(),0.0)
	L.box(L.M.metall,sb+Vector3(0,3.6,0),Vector3(3,0.6,1.2),Basis(),0.03)
	L.zyl(L.M.metall,sb+Vector3(0,3.9,0),sb+Vector3(1.5,5.6,0),0.04,1.2)
	for k in 9:L.zyl(L.M.metall,o+Vector3(-100+k*25,5.7,-6),o+Vector3(-100+k*25,5.7,6),0.03,1.0)
	L.zyl(L.M.linie,o+Vector3(-110,5.6,-2),o+Vector3(110,5.6,-2),0.02,1.0)
	for k in 9:L.zyl(L.M.metall,o+Vector3(-100+k*25,0,-6.5),o+Vector3(-100+k*25,5.8,-6.5),0.12,1.2)
	for x in range(-100,110,15):L._baum(o+Vector3(x,0.15,-10.5));L._baum(o+Vector3(x+7,0.15,10.5))
	parker(o,lang,7.0,["c_trabant_gruen","c_trabant_blau","c_trabant_beige","c_wartburg_beige","c_wartburg_blau","c_kompakt_rot"],0.45)
	KAM.append(["oststadt","Oststadt",o+Vector3(-90,6,4),o+Vector3(0,10,-12)])

# ================= FLUGPLATZ =================
func flugplatz(o:Vector3):
	flaeche(T(Color(0.5,0.65,0.35)),o,500,400,-0.02)
	flaeche(L.M.asphalt,o+Vector3(0,0,30),440,30,0.0)
	for x in range(-200,200,20):L.box(L.M.markierung,o+Vector3(x,0.006,30),Vector3(10,0.02,0.5),Basis(),0.0)
	for k in 8:L.box(L.M.markierung,o+Vector3(-205,0.006,20+k*2.6),Vector3(14,0.02,1.2),Basis(),0.0)
	flaeche(L.M.asphalt,o+Vector3(0,0,-20),200,50,0.0)
	# Terminal
	var t=o+Vector3(-40,0,-60)
	B(L.M.weiss,t+Vector3(0,5,0),Vector3(90,10,24),0.0,0.05)
	B(L.M.glas[1],t+Vector3(0,5,12.05),Vector3(86,7,0.1),0.0,0.0)
	B(T(Color(0.25,0.4,0.6)),t+Vector3(0,10.6,0),Vector3(94,1.2,28),0.0,0.04)
	L._schrift("FLUGHAFEN RADEBERG",t+Vector3(0,12.8,12.2),Basis(),0.03,Color(0.2,0.35,0.6),Color(1,1,1))
	# Tower
	var tw=o+Vector3(40,0,-55)
	L.zyl(L.M.weiss,tw,tw+Vector3(0,28,0),2.2,1.04)
	L.zyl(L.M.glas[0],tw+Vector3(0,28,0),tw+Vector3(0,32,0),4.0,1.03);L.zyl(L.M.dunkel,tw+Vector3(0,32,0),tw+Vector3(0,33,0),4.5,1.03)
	L.zyl(L.M.rot,tw+Vector3(0,33,0),tw+Vector3(0,37,0),0.1,1.2)
	# Hangar
	var h=o+Vector3(110,0,-55)
	L.zyl(T(Color(0.7,0.72,0.74)),h+Vector3(0,0,-20),h+Vector3(0,0,20),18,1.02)
	B(L.M.dunkel,h+Vector3(0,7,20.1),Vector3(26,14,0.2),0.0,0.0)
	# Flugzeuge
	flieger(o+Vector3(-20,0,-15),0.0,Color(0.95,0.95,0.97),Color(0.85,0.2,0.2))
	flieger(o+Vector3(90,0,-12),-0.6,Color(0.98,0.85,0.2),Color(0.2,0.3,0.7),0.5)
	KAM.append(["flugplatz","Flugplatz",o+Vector3(-70,9,14),o+Vector3(-5,6,-35)])
func flieger(p:Vector3,yaw:float,rumpf:Color,streif:Color,gr:=1.0):
	var b=Y(yaw);var m=T(rumpf);var s=T(streif)
	var P=func(x,y,z):return p+b*(Vector3(x,y,z)*gr)
	L.kapsel(m,P.call(0,4,-16),P.call(0,4,16),2.0*gr)
	L.box(s,P.call(0,4.0,0),Vector3(4.05,0.5,30)*gr,b,0.0)
	for z in range(-12,13,2):
		for sd in [-1,1]:L.box(L.M.glas[1],P.call(sd*2.0,4.7,z),Vector3(0.05,0.5,0.6)*gr,b,0.0)
	L.box(m,P.call(0,3.5,1),Vector3(30,0.4,5)*gr,b,0.03)
	L.box(s,P.call(0,8,-15),Vector3(0.4,7,4)*gr,b*Basis(Vector3(1,0,0),-0.35),0.03)
	L.box(m,P.call(0,5,-16),Vector3(11,0.3,3)*gr,b,0.03)
	for sd in [-1,1]:L.zyl(L.M.metall,P.call(sd*7,2.6,4),P.call(sd*7,2.6,-1),1.0*gr,1.05)
	for sd in [-1.5,0.0,1.5]:L.zyl(L.M.reifen,P.call(sd*1.5,0.5,(8.0 if sd==0.0 else 0.0)),P.call(sd*1.5,2.2,(8.0 if sd==0.0 else 0.0)),0.15*gr,1.2);L.kugel(L.M.reifen,P.call(sd*1.5,0.5,(8.0 if sd==0.0 else 0.0)),Vector3(0.5,0.5,0.3)*gr)
