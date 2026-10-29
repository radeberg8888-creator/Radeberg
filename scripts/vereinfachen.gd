extends RefCounted
# Mesh-Vereinfachung ohne externe Werkzeuge (für Detailstufen von Gebäuden und Bäumen).

# Punkt-Bündelung: alle Ecken in einer Gitterzelle (getrennt nach Hauptrichtung der Normalen) werden zu einer Ecke;
# Dreiecke, die dabei zusammenfallen, entfallen. Die neuen Indizes zeigen auf vorhandene Ecken.
static func cluster(arr:Array,I:PackedInt32Array,c:float,uv_raster:=8.0)->PackedInt32Array:
	var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX];var N=arr[Mesh.ARRAY_NORMAL];var UV=arr[Mesh.ARRAY_TEX_UV]
	var mit_uv=UV!=null and UV.size()==V.size() and uv_raster>0.0
	var rep=PackedInt32Array();rep.resize(V.size())
	var zell={}
	var inv=1.0/c
	var mit_n=N!=null and N.size()==V.size()
	for i in V.size():
		var p=V[i]
		var b=0
		if mit_n:
			var n:Vector3=N[i];var ax=n.abs()
			if ax.x>=ax.y and ax.x>=ax.z:b=0 if n.x>0 else 1
			elif ax.y>=ax.z:b=2 if n.y>0 else 3
			else:b=4 if n.z>0 else 5
		var extra=b
		if mit_uv:
			var u:Vector2=UV[i]
			extra+=8*(((int(floor(u.x*uv_raster))%1000+1000)%1000)*1000+((int(floor(u.y*uv_raster))%1000+1000)%1000))
		var key=Vector4i(int(floor(p.x*inv)),int(floor(p.y*inv)),int(floor(p.z*inv)),extra)
		var r=zell.get(key,-1)
		if r<0:zell[key]=i;r=i
		rep[i]=r
	var out=PackedInt32Array();out.resize(I.size());var n_out=0
	var seen={}
	var t=0
	while t<I.size():
		var a=rep[I[t]];var bb=rep[I[t+1]];var cc=rep[I[t+2]];t+=3
		if a==bb or bb==cc or a==cc:continue
		var lo=mini(a,mini(bb,cc));var hi=maxi(a,maxi(bb,cc));var mi=a+bb+cc-lo-hi
		var k=(lo*4000037+mi)*4000037+hi
		if seen.has(k):continue
		seen[k]=true
		out[n_out]=a;out[n_out+1]=bb;out[n_out+2]=cc;n_out+=3
	out.resize(n_out)
	return out

# Blattkarten ausdünnen: zusammenhängende Teile (je Karte/Büschel) finden, nur einen Anteil behalten
# und diese um ihren Mittelpunkt vergrößern, damit die Krone gleich dicht wirkt.
static func ausduennen(arr:Array,anteil:float,groesser:float)->Array:
	var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX].duplicate()
	var I:PackedInt32Array=arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(V.size()))
	# Ecken gleicher Position zusammenfassen, dann Union-Find über Dreiecke
	var pos={};var eltern:Array=[];eltern.resize(V.size())
	for i in V.size():
		var k=V[i].snapped(Vector3.ONE*0.0005)
		if pos.has(k):eltern[i]=pos[k]
		else:pos[k]=i;eltern[i]=i
	var t=0
	while t<I.size():
		var a=_finde(eltern,I[t]);var b=_finde(eltern,I[t+1]);var c=_finde(eltern,I[t+2]);t+=3
		if b!=a:eltern[b]=a
		c=_finde(eltern,c)
		if c!=a:eltern[c]=a
	var wurzel=PackedInt32Array();wurzel.resize(V.size())
	for i in V.size():wurzel[i]=_finde(eltern,i)
	# Mittelpunkte
	var summe={};var anzahl={}
	for i in V.size():
		var r=wurzel[i]
		summe[r]=summe.get(r,Vector3.ZERO)+V[i];anzahl[r]=anzahl.get(r,0)+1
	var behalten={}
	var zz=RandomNumberGenerator.new();zz.seed=4711
	for r in summe:
		if zz.randf()<anteil:behalten[r]=summe[r]/anzahl[r]
	var benutzt={}
	var neu_i=PackedInt32Array()
	t=0
	while t<I.size():
		var r=wurzel[I[t]]
		if behalten.has(r):
			neu_i.append(I[t]);neu_i.append(I[t+1]);neu_i.append(I[t+2])
			benutzt[I[t]]=true;benutzt[I[t+1]]=true;benutzt[I[t+2]]=true
		t+=3
	for i in benutzt:
		var m:Vector3=behalten[wurzel[i]]
		V[i]=m+(V[i]-m)*groesser
	var out=arr.duplicate()
	out[Mesh.ARRAY_VERTEX]=V;out[Mesh.ARRAY_INDEX]=neu_i
	return out

static func _finde(e:Array,x:int)->int:
	while e[x]!=x:
		e[x]=e[e[x]];x=e[x]
	return x
