extends RefCounted
# Alle Waffen: Modell, echte Länge, Griffpunkt (Anteil der Länge von hinten), Kampfwerte, Preise.
# typ: nah | pistole | mp | schrot | gewehr | mg | sniper
# schaden je Treffer, rate = Schuss pro Sekunde, magazin, nachladen s, reichweite m, streuung Grad, preis $, munpreis $ je Magazin
const W="res://assets/weapons/"
const LISTE={
	"faust":{"name":"Fäuste","typ":"nah","schaden":12,"rate":2.2,"reichweite":1.6,"preis":0},
	"machete":{"name":"Machete","modell":W+"machete.glb","laenge":0.62,"griff":0.1,"typ":"nah","schaden":38,"rate":1.6,"reichweite":2.0,"preis":150},
	"katana":{"name":"Katana","modell":W+"katana/katana.glb","laenge":1.0,"griff":0.1,"typ":"nah","schaden":60,"rate":1.3,"reichweite":2.4,"preis":900},
	"pistole":{"name":"Pistole 9 mm","modell":W+"pistol.glb","laenge":0.2,"griff":0.2,"typ":"pistole","schaden":22,"rate":4.0,"magazin":15,"nachladen":1.3,"reichweite":60,"streuung":1.2,"preis":400,"munpreis":30},
	"m1911":{"name":"Colt M1911","modell":W+"m1911/m1911.gltf","laenge":0.216,"griff":0.18,"typ":"pistole","schaden":30,"rate":3.2,"magazin":7,"nachladen":1.4,"reichweite":60,"streuung":1.4,"preis":650,"munpreis":30},
	"tp9":{"name":"TP9 Elite","modell":W+"pack10/pack10.gltf","knoten":"Canit_TP9_Elite_Combat","laenge":0.19,"griff":0.2,"typ":"pistole","schaden":24,"rate":4.5,"magazin":18,"nachladen":1.2,"reichweite":65,"streuung":1.0,"preis":800,"munpreis":35},
	"pistol_tac":{"name":"Taktische Pistole","modell":W+"pistol_tac/pistol_tac.gltf","laenge":0.21,"griff":0.2,"typ":"pistole","schaden":26,"rate":4.0,"magazin":17,"nachladen":1.2,"reichweite":70,"streuung":0.9,"preis":1100,"munpreis":35},
	"mp5":{"name":"MP5","modell":W+"mp5b/mp5b.gltf","vorne_umkehren":true,"laenge":0.68,"griff":0.42,"vorn":0.8,"typ":"mp","schaden":18,"rate":12.0,"magazin":30,"nachladen":1.8,"reichweite":80,"streuung":2.2,"preis":2200,"munpreis":60},
	"mp7":{"name":"MP7","modell":W+"pack10/pack10.gltf","knoten":"HK_MP7","laenge":0.42,"griff":0.42,"vorn":0.72,"typ":"mp","schaden":17,"rate":14.0,"magazin":40,"nachladen":1.7,"reichweite":80,"streuung":2.4,"preis":2800,"munpreis":70},
	"ks7":{"name":"Schrotflinte KS7","modell":W+"pack10/pack10.gltf","knoten":"Kel_Tec_KS7","laenge":0.67,"griff":0.45,"vorn":0.76,"typ":"schrot","schaden":14,"kugeln":8,"rate":1.3,"magazin":7,"nachladen":2.4,"reichweite":35,"streuung":5.0,"preis":1800,"munpreis":40},
	"mossberg":{"name":"Pump-Gun 500","modell":W+"pack10/pack10.gltf","knoten":"Mossberg_500_SWAT","laenge":0.95,"griff":0.3,"vorn":0.66,"typ":"schrot","schaden":16,"kugeln":8,"rate":1.1,"magazin":6,"nachladen":2.8,"reichweite":38,"streuung":4.5,"preis":2400,"munpreis":45},
	"ak47":{"name":"Sturmgewehr 47","modell":W+"gewehr47/gewehr47.gltf","laenge":0.88,"griff":0.38,"vorn":0.6,"typ":"gewehr","schaden":32,"rate":9.0,"magazin":30,"nachladen":2.2,"reichweite":140,"streuung":1.8,"preis":3500,"munpreis":80},
	"ar15":{"name":"AR-15","modell":W+"ar15b/ar15b.gltf","laenge":0.94,"griff":0.36,"vorn":0.62,"typ":"gewehr","schaden":28,"rate":10.0,"magazin":30,"nachladen":2.0,"reichweite":160,"streuung":1.2,"preis":4200,"munpreis":80},
	"m4a1":{"name":"M4A1","modell":W+"pack10/pack10.gltf","knoten":"Colt_M4A1","laenge":0.84,"griff":0.38,"vorn":0.62,"typ":"gewehr","schaden":29,"rate":11.0,"magazin":30,"nachladen":2.0,"reichweite":160,"streuung":1.1,"preis":5200,"munpreis":85},
	"aug":{"name":"Steyr AUG","modell":W+"aug/aug.gltf","nur_hauptteil":true,"laenge":0.79,"griff":0.55,"vorn":0.76,"typ":"gewehr","schaden":30,"rate":10.5,"magazin":30,"nachladen":2.1,"reichweite":170,"streuung":1.0,"preis":6000,"munpreis":85},
	"m248":{"name":"M248 MG","modell":W+"m248/m248.gltf","laenge":1.04,"griff":0.36,"vorn":0.62,"typ":"mg","schaden":30,"rate":13.0,"magazin":100,"nachladen":4.5,"reichweite":170,"streuung":2.6,"preis":12000,"munpreis":250},
	"m14":{"name":"M14 EBR","modell":W+"pack10/pack10.gltf","knoten":"M14_EBR","laenge":1.12,"griff":0.35,"vorn":0.6,"typ":"sniper","schaden":95,"rate":1.6,"magazin":10,"nachladen":2.6,"reichweite":400,"streuung":0.15,"preis":8000,"munpreis":120},
	"mauser":{"name":"Scharfschützengewehr","modell":W+"pack10/pack10.gltf","knoten":"Mauser_1918T_Gewehr","laenge":1.25,"griff":0.3,"vorn":0.55,"typ":"sniper","schaden":160,"rate":0.7,"magazin":5,"nachladen":3.0,"reichweite":500,"streuung":0.05,"preis":9500,"munpreis":120},
	"jagdgewehr":{"name":"Jagdgewehr","modell":W+"rifle.glb","laenge":1.1,"griff":0.3,"vorn":0.58,"typ":"sniper","schaden":110,"rate":0.9,"magazin":5,"nachladen":2.8,"reichweite":350,"streuung":0.2,"preis":3000,"munpreis":60},
}
# Reihenfolge im Laden / beim Durchschalten
const REIHE=["faust","machete","katana","pistole","m1911","tp9","pistol_tac","mp5","mp7","ks7","mossberg","ak47","ar15","m4a1","aug","m248","jagdgewehr","m14","mauser"]
# Was der Wüsten-Händler zusätzlich (günstiger, aber nur dort) anbietet
const WUESTE=["ak47","mossberg","m248","mauser","machete","m1911"]
const ZWEIHAND=["mp","schrot","gewehr","mg","sniper"]

static func daten(id:String)->Dictionary:return LISTE.get(id,LISTE.faust)
static func zweihand(id:String)->bool:return daten(id).typ in ZWEIHAND
