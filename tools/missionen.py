"""Erzeugt den Missionskatalog (assets/data/missionen.json): Story-Missionen je Auftraggeber,
Nebenjobs, Immobilien und Geschäfte. Orte sind Schlüssel aus der Weltkarte (welt.gd)."""
import json, os
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'missionen.json')

KONTAKTE = {
 "rudi":   {"name": "Onkel Rudi", "ort": "ghetto", "rolle": "Kopf der Lindenhof-Crew, dein Ziehvater"},
 "mara":   {"name": "Mara Klein", "ort": "werkstatt", "rolle": "Tunerin, Königin der Straßenrennen"},
 "brandt": {"name": "Kommissar Brandt", "ort": "downtown", "rolle": "korrupter Ermittler, erpresst dich"},
 "viktor": {"name": "Viktor Sokolov", "ort": "hafen", "rolle": "Schmuggler mit Containerfirma"},
 "ines":   {"name": "Ines Hartmann", "ort": "downtown", "rolle": "Immobilienhai mit Kontakten ins Rathaus"},
 "jojo":   {"name": "Jojo", "ort": "altstadt", "rolle": "Hacker, Elektronik, Überwachung"},
 "baron":  {"name": "Der Baron", "ort": "flugplatz", "rolle": "Waffenhändler am alten Flugplatz"},
 "petro":  {"name": "Familie Petrović", "ort": "altstadt", "rolle": "Clubbesitzer, alte Familie"},
}
GANGS = {"kobras": "Kanal-Kobras", "ratten": "Hafenratten", "ost": "Ostblock-Brüder", "fuechse": "Wüstenfüchse", "lindenhof": "Lindenhof-Crew"}

# Zieltypen -> Ablauf (Schritte). {a}=Start, {b}=Ziel, {g}=Gang
TYPEN = {
 "transport":   ["Fahrzeug bei {a} abholen", "Unbeschädigt nach {b} bringen"],
 "lieferung":   ["Ware bei {a} laden", "In der Zeit nach {b} liefern"],
 "gang":        ["Nach {b} fahren", "Alle Mitglieder der {g} ausschalten", "Gebiet halten bis Verstärkung"],
 "schiesserei": ["Treffpunkt {b} erreichen", "Hinterhalt überleben", "Verletzten Kontakt nach {a} bringen"],
 "verfolgung":  ["Ziel bei {a} finden", "Fahrzeug verfolgen und rammen", "Ware sichern"],
 "eskorte":     ["Konvoi bei {a} treffen", "Konvoi bis {b} beschützen"],
 "ueberfall":   ["Ausrüstung holen", "Überfall in {b}", "Polizei abschütteln (Fahndungslevel 3)", "Versteck in {a} erreichen"],
 "rennen":      ["Zum Start in {a}", "Rennen über die Insel gewinnen", "Siegerauto in die Werkstatt bringen"],
 "diebstahl":   ["Wagen in {b} finden", "Wagen stehlen ohne Alarm", "In der Garage {a} abstellen"],
 "verteidigen": ["Nach {b}", "Angriffswellen der {g} abwehren", "Gebäude halten"],
 "sniper":      ["Aussichtspunkt in {b} erreichen", "Zielperson mit Scharfschützengewehr ausschalten", "Entkommen"],
 "flucht":      ["Kontakt in {a} abholen", "Polizeisperren umfahren", "Sicher nach {b}"],
 "bergung":     ["Mit dem Boot/LKW nach {b}", "Kisten bergen", "Zurück nach {a}"],
 "spionage":    ["Zielperson in {b} beschatten", "Gespräch mitschneiden", "Unentdeckt bleiben"],
 "abschleppen": ["Abschleppwagen holen", "Fahrzeug in {b} aufladen", "Zum Schrottplatz in {a}"],
}

def m(kontakt, titel, typ, a, b, gang="", geld=1000, text=""):
    return {"kontakt": kontakt, "titel": titel, "typ": typ, "start": a, "ziel": b, "gang": GANGS.get(gang, ""),
            "belohnung": geld, "briefing": text,
            "schritte": [s.format(a=a, b=b, g=GANGS.get(gang, "Gang")) for s in TYPEN[typ]]}

S = []
# --- Onkel Rudi: Aufstieg der Lindenhof-Crew (Ghetto) ---
S += [
 m("rudi", "Heimkehr", "transport", "bahnhof", "ghetto", geld=200, text="Du kommst nach Jahren zurück. Rudi holt dich nicht ab – also nimm dir ein Auto."),
 m("rudi", "Alte Freunde", "schiesserei", "ghetto", "altstadt", "kobras", 500, "Die Kobras haben deinen Kumpel festgesetzt."),
 m("rudi", "Farbe bekennen", "gang", "ghetto", "ghetto", "kobras", 800, "Übermale die Tags der Kobras und zeig, wem die Straße gehört."),
 m("rudi", "Lieferservice", "lieferung", "ghetto", "ost", geld=600, text="Rudis Ware muss pünktlich bei den Kunden sein."),
 m("rudi", "Grillfest", "verteidigen", "ghetto", "ghetto", "kobras", 900, "Die Kobras stürmen das Nachbarschaftsfest."),
 m("rudi", "Schutzgeld zurück", "verfolgung", "ghetto", "industrie", geld=1100, text="Ein Kobra hat die Kasse vom Kiosk geklaut."),
 m("rudi", "Kanal-Säuberung", "gang", "ghetto", "ghetto", "kobras", 1500, "Räum das Kobra-Versteck am Kanal aus."),
 m("rudi", "Verrat in den eigenen Reihen", "verfolgung", "ghetto", "hafen", geld=1800, text="Jemand redet mit Brandt. Finde ihn."),
 m("rudi", "Begräbnis", "eskorte", "ghetto", "altstadt", geld=1200, text="Beschütze den Trauerzug – die Kobras warten nur darauf."),
 m("rudi", "Krieg der Straßen", "gang", "ghetto", "ghetto", "kobras", 3000, "Ein Viertel nach dem anderen zurückholen."),
 m("rudi", "Der Lindenhof steht", "verteidigen", "ghetto", "ghetto", "kobras", 5000, "Die letzte große Offensive der Kobras."),
 m("rudi", "Familie", "flucht", "ghetto", "berg", geld=4000, text="Rudi ist verletzt – raus aus der Stadt, rauf in die Berghütte."),
]
# --- Mara Klein: Tuning & Straßenrennen ---
S += [
 m("mara", "Probefahrt", "rennen", "werkstatt", "downtown", geld=300, text="Mara will sehen, ob du fahren kannst."),
 m("mara", "Ersatzteile", "diebstahl", "werkstatt", "vorort", geld=700, text="Ein Coupé im Villenviertel hat genau die Felgen, die sie braucht."),
 m("mara", "Nitro auf Rezept", "lieferung", "werkstatt", "industrie", geld=650, text="Lachgasflaschen aus dem Industriegebiet holen – vorsichtig fahren!"),
 m("mara", "Autobahnsprint", "rennen", "autobahn", "autobahn", geld=1000, text="Einmal um die ganze Insel, durch den Tunnel."),
 m("mara", "Drift am Berg", "rennen", "berg", "berg", geld=1200, text="Bergstraße abwärts, Zeitwertung im Drift."),
 m("mara", "Gestohlene Ehre", "verfolgung", "werkstatt", "hafen", geld=1400, text="Jemand hat Maras Showcar gestohlen."),
 m("mara", "Hafenrennen", "rennen", "hafen", "hafen", geld=1500, text="Zwischen Containern, Kränen und LKW."),
 m("mara", "Showroom", "diebstahl", "werkstatt", "downtown", geld=2500, text="Drei Sportwagen aus dem Autohaus Downtown – in einer Nacht."),
 m("mara", "Wüstenrallye", "rennen", "flugplatz", "flugplatz", geld=2000, text="Offroad über die Landebahn und die Dünen."),
 m("mara", "Underground-Meisterschaft", "rennen", "downtown", "downtown", geld=6000, text="Das Finale: Nachtrennen durch Downtown."),
 m("mara", "Abschleppdienst", "abschleppen", "werkstatt", "altstadt", geld=500, text="Ein Kunde hat seinen Tuningwagen in der Altstadt geschrottet."),
]
# --- Kommissar Brandt ---
S += [
 m("brandt", "Ein Gefallen", "transport", "downtown", "berg", geld=0, text="Brandt hat Beweise gegen dich. Bring sein ‚Paket‘ zur Berghütte."),
 m("brandt", "Zeugen", "verfolgung", "downtown", "vorort", geld=500, text="Ein Zeuge will aussagen. Brandt will das nicht."),
 m("brandt", "Asservatenkammer", "ueberfall", "downtown", "downtown", geld=1500, text="Hol das beschlagnahmte Geld aus dem Präsidium."),
 m("brandt", "Kollegenschwein", "spionage", "downtown", "altstadt", geld=800, text="Beschatte die Internen Ermittlungen."),
 m("brandt", "Razzia", "gang", "downtown", "ost", "ost", 1800, "Brandt braucht Erfolge – du lieferst sie."),
 m("brandt", "Akte X", "flucht", "downtown", "flugplatz", geld=2500, text="Brandts Ex-Partner flieht mit belastenden Akten."),
 m("brandt", "Scharfschütze", "sniper", "downtown", "downtown", geld=3000, text="Vom Dach eines Hochhauses."),
 m("brandt", "Abrechnung", "schiesserei", "downtown", "gueterbahnhof", geld=5000, text="Brandt will dich loswerden – du kommst ihm zuvor."),
]
# --- Viktor Sokolov: Hafen ---
S += [
 m("viktor", "Container 47", "bergung", "hafen", "hafen", geld=900, text="Ein Container, der nicht auf der Liste steht."),
 m("viktor", "Hafenratten", "gang", "hafen", "hafen", "ratten", 1500, "Die Ratten klauen Viktors Ware."),
 m("viktor", "Nachtschicht", "lieferung", "hafen", "gueterbahnhof", geld=1100, text="LKW mit Ware vom Terminal zum Güterbahnhof."),
 m("viktor", "Zollkontrolle", "flucht", "hafen", "industrie", geld=1300, text="Die Kontrolle kommt früher als erwartet."),
 m("viktor", "Kranführer", "transport", "hafen", "hafen", geld=800, text="Lade die Container um, bevor der Zoll kommt."),
 m("viktor", "Güterzug", "verfolgung", "gueterbahnhof", "bahn", geld=2000, text="Die Ostblock-Brüder haben einen Wagen am Zug angehängt."),
 m("viktor", "Schiff ahoi", "verteidigen", "hafen", "hafen", "ratten", 2400, "Das Schiff wird beladen – halt die Ratten fern."),
 m("viktor", "Die Ostroute", "eskorte", "hafen", "ost", geld=2200, text="Viktors Konvoi durch das Ostviertel."),
 m("viktor", "Tauchgang", "bergung", "hafen", "hafen", geld=2600, text="Versenkte Kisten vor der Kaimauer."),
 m("viktor", "Der große Deal", "schiesserei", "hafen", "hafen", geld=7000, text="Der Deal platzt – und alle ziehen."),
]
# --- Ines Hartmann: Immobilien & Downtown ---
S += [
 m("ines", "Mietpreisbremse", "verteidigen", "downtown", "altstadt", "kobras", 800, "Ines' Baustelle wird sabotiert."),
 m("ines", "Grundbuch", "spionage", "downtown", "downtown", geld=900, text="Finde heraus, wem das Grundstück am Bahnhof wirklich gehört."),
 m("ines", "Abrissbirne", "transport", "industrie", "altstadt", geld=1000, text="Ein Bagger muss quer durch die Stadt."),
 m("ines", "Bürgerinitiative", "abschleppen", "downtown", "industrie", geld=600, text="Entferne die Protest-Autos von der Baustelle."),
 m("ines", "Rathausfest", "eskorte", "downtown", "vorort", geld=1600, text="Bring den Bürgermeister sicher nach Hause."),
 m("ines", "Hochhausbrand", "flucht", "downtown", "downtown", geld=2000, text="Feuer im Turm – hol Ines' Dokumente raus."),
 m("ines", "Penthouse", "ueberfall", "vorort", "downtown", geld=3500, text="Der Tresor eines Konkurrenten."),
 m("ines", "Grundsteinlegung", "sniper", "downtown", "bahnhof", geld=4000, text="Ein Auftragskiller zielt auf Ines."),
]
# --- Jojo: Hacker ---
S += [
 m("jojo", "Lauschangriff", "spionage", "altstadt", "downtown", geld=500, text="Wanzen im Büro der Ostblock-Brüder."),
 m("jojo", "Serverfarm", "ueberfall", "altstadt", "industrie", geld=1200, text="Festplatten aus dem Rechenzentrum."),
 m("jojo", "Ampelchaos", "flucht", "altstadt", "downtown", geld=900, text="Jojo schaltet die Ampeln – du fährst."),
 m("jojo", "Kamerafahrt", "verfolgung", "altstadt", "ost", geld=1100, text="Ein Drohnenpilot filmt dich. Hol die Drohne runter."),
 m("jojo", "Geldautomat", "diebstahl", "altstadt", "ghetto", geld=1400, text="Ein ganzer Automat auf dem Pick-up."),
 m("jojo", "Funkloch", "verteidigen", "altstadt", "berg", "ost", 2000, "Den Sendemast auf dem Berg halten."),
 m("jojo", "Backup", "transport", "altstadt", "bahnhof", geld=1000, text="Ein Koffer voller Daten in den Zug."),
 m("jojo", "Systemabsturz", "ueberfall", "altstadt", "downtown", geld=5000, text="Die Bank in Downtown – ohne Alarm."),
]
# --- Der Baron: Waffen & Wüste ---
S += [
 m("baron", "Willkommen in der Wüste", "transport", "flugplatz", "ghetto", geld=700, text="Waffenkisten in die Stadt."),
 m("baron", "Wüstenfüchse", "gang", "flugplatz", "flugplatz", "fuechse", 1500, "Die Biker-Gang hält Hangar 2 besetzt."),
 m("baron", "Notlandung", "bergung", "flugplatz", "berg", geld=1800, text="Ein Kleinflugzeug ist am Berg abgestürzt."),
 m("baron", "Schießstand", "schiesserei", "flugplatz", "flugplatz", geld=600, text="Zeig, was du mit dem Gewehr kannst."),
 m("baron", "Konvoi im Sand", "eskorte", "flugplatz", "hafen", geld=2200, text="Drei LKW quer über die Insel."),
 m("baron", "Hangar in Flammen", "verteidigen", "flugplatz", "flugplatz", "fuechse", 2500, "Die Füchse wollen sich rächen."),
 m("baron", "Panzerknacker", "diebstahl", "flugplatz", "industrie", geld=3000, text="Ein Geldtransporter im Industriegebiet."),
 m("baron", "Waffenstillstand", "spionage", "flugplatz", "altstadt", geld=1500, text="Wer verhandelt hinter dem Rücken des Barons?"),
 m("baron", "Sandsturm", "gang", "flugplatz", "flugplatz", "fuechse", 6000, "Endgültig Schluss mit den Wüstenfüchsen."),
]
# --- Familie Petrović: Altstadt-Club ---
S += [
 m("petro", "Türsteher", "schiesserei", "altstadt", "altstadt", geld=500, text="Ärger vor dem Club."),
 m("petro", "Lieferung für die Bar", "lieferung", "altstadt", "hafen", geld=600, text="Spirituosen vom Hafen – keine Fragen."),
 m("petro", "Der Neffe", "flucht", "altstadt", "vorort", geld=1200, text="Der Neffe hat Schulden bei den Ostblock-Brüdern."),
 m("petro", "Schutzgeld", "gang", "altstadt", "ost", "ost", 1800, "Die Brüder kassieren in der Altstadt ab."),
 m("petro", "Hochzeit", "eskorte", "altstadt", "berg", geld=1500, text="Die Hochzeitskolonne zum Aussichtspunkt."),
 m("petro", "Spieleabend", "ueberfall", "altstadt", "ost", geld=2600, text="Das illegale Casino der Brüder."),
 m("petro", "Blutrache", "gang", "altstadt", "ost", "ost", 4000, "Das Hauptquartier im Ostviertel."),
 m("petro", "Erbe", "verteidigen", "altstadt", "altstadt", "ost", 6000, "Die Brüder schlagen zurück – verteidige den Club."),
]
# --- Großer Coup (Finale, mehrteilig wie Heists) ---
S += [
 m("rudi", "Coup: Planung", "spionage", "ghetto", "bahnhof", geld=0, text="Der Geldzug der Zentralbank fährt jeden Freitag."),
 m("jojo", "Coup: Fahrplan", "ueberfall", "altstadt", "bahnhof", geld=0, text="Hol den Fahrplan aus dem Stellwerk."),
 m("mara", "Coup: Fluchtwagen", "diebstahl", "werkstatt", "downtown", geld=0, text="Vier schnelle Autos, unauffällig lackiert."),
 m("baron", "Coup: Ausrüstung", "transport", "flugplatz", "ghetto", geld=0, text="Schweißgeräte, Westen, Waffen."),
 m("viktor", "Coup: Versteck", "bergung", "hafen", "hafen", geld=0, text="Ein leerer Container als Versteck."),
 m("rudi", "Coup: Der Zug", "ueberfall", "gueterbahnhof", "bahn", geld=25000, text="Der Geldzug im Tunnel am Berg."),
 m("rudi", "Coup: Flucht", "flucht", "bahn", "hafen", geld=0, text="Alle Polizisten der Insel sind hinter euch her."),
 m("rudi", "Epilog: König der Insel", "verteidigen", "ghetto", "ghetto", "kobras", 10000, "Ein letzter Angriff auf den Lindenhof."),
]
# --- Fremde & Freaks (kleine Nebenmissionen) ---
FREMD = [
 ("Der Tourist", "transport", "bahnhof", "berg", "Ein verwirrter Tourist will zum Gipfel."),
 ("Paparazzo", "verfolgung", "downtown", "vorort", "Fotografier den Star in seiner Villa."),
 ("Der Sammler", "diebstahl", "vorort", "werkstatt", "Ein Oldtimer im Vorort."),
 ("Zirkusbär", "transport", "hafen", "flugplatz", "Ein Tiertransporter mit sehr unruhiger Fracht."),
 ("Marathon", "rennen", "altstadt", "altstadt", "Zu Fuß durch die Altstadt."),
 ("Schatzsucher", "bergung", "flugplatz", "flugplatz", "Ein Metalldetektor und eine alte Karte."),
 ("Der Prediger", "eskorte", "ghetto", "downtown", "Bring den Straßenprediger zur Kundgebung."),
 ("Fahrradkurier", "lieferung", "downtown", "altstadt", "Zehn Pakete, zehn Minuten."),
 ("Graffiti-Jagd", "gang", "ghetto", "industrie", "Die Kobras übersprühen deine Tags.", "kobras"),
 ("Geisterfahrer", "verfolgung", "autobahn", "autobahn", "Ein Betrunkener fährt falsch auf dem Ring."),
 ("Mopedrennen", "rennen", "vorort", "vorort", "Mit 50 ccm durchs Villenviertel."),
 ("Umzug", "transport", "ost", "vorort", "Ein Klavier – sehr vorsichtig fahren."),
 ("Schrottkönig", "abschleppen", "ghetto", "industrie", "Fünf Wracks zum Schrottplatz."),
 ("Der Erpresser", "spionage", "vorort", "downtown", "Ein Familienvater wird erpresst."),
 ("Hochzeitscrasher", "flucht", "altstadt", "berg", "Die Braut will abhauen – mit dir als Fahrer."),
 ("Bergrettung", "bergung", "berg", "berg", "Wanderer im Nebel."),
 ("Zugverspätung", "rennen", "bahnhof", "flugplatz", "Schneller als der Zug zum Wüstenhalt."),
 ("Taubenzüchter", "transport", "altstadt", "berg", "Freilassung am Gipfel."),
 ("Die Rocker-Oma", "eskorte", "flugplatz", "ghetto", "Eine alte Dame auf einer Harley."),
 ("Der letzte Bus", "transport", "bahnhof", "ghetto", "Fahr den Nachtbus – pünktlich."),
]
for t in FREMD:
    S.append(m("fremd", t[0], t[1], t[2], t[3], t[5] if len(t) > 5 else "", 400, t[4]))
# --- Bandenkrieg: Gebiete erobern (je Viertel eine Mission) ---
for ort, g in [("ghetto", "kobras"), ("industrie", "kobras"), ("hafen", "ratten"), ("gueterbahnhof", "ratten"), ("ost", "ost"),
               ("altstadt", "ost"), ("flugplatz", "fuechse"), ("berg", "fuechse"), ("vorort", "ost"), ("bahnhof", "ratten")]:
    S.append(m("lindenhof", "Gebietskampf: " + ort.capitalize(), "gang", "ghetto", ort, g, 1500, f"Erobere das Viertel {ort} von den {GANGS[g]}."))

for i, x in enumerate(S): x["id"] = i + 1

JOBS = {
 "taxi":       {"titel": "Taxifahrer", "start": "Taxi besteigen oder an der Taxizentrale", "ablauf": "Fahrgäste aufnehmen und zum Ziel bringen; Trinkgeld für Tempo und schonende Fahrt", "stufen": 12, "bonus": "Ab Stufe 10: Nitro in allen Taxis"},
 "polizei":    {"titel": "Bürgerwehr / Polizeieinsatz", "start": "Streifenwagen", "ablauf": "Gesuchte Verbrecher stellen", "stufen": 12, "bonus": "Ab Stufe 12: schusssichere Weste"},
 "feuerwehr":  {"titel": "Feuerwehr", "start": "Löschfahrzeug", "ablauf": "Brennende Autos und Häuser löschen", "stufen": 12, "bonus": "Ab Stufe 12: feuerfest"},
 "rettung":    {"titel": "Rettungsdienst", "start": "Rettungswagen", "ablauf": "Verletzte ins Krankenhaus bringen", "stufen": 12, "bonus": "Ab Stufe 12: mehr Lebensenergie"},
 "lkw":        {"titel": "LKW-Fahrer", "start": "Sattelzug am Güterbahnhof", "ablauf": "Fracht zwischen Hafen, Güterbahnhof und Industrie", "stufen": 10, "bonus": "Ab Stufe 10: eigener Sattelzug"},
 "bus":        {"titel": "Busfahrer", "start": "Linienbus am Hauptbahnhof", "ablauf": "Haltestellen pünktlich anfahren", "stufen": 8, "bonus": "Busfahrkarte gratis"},
 "abschlepp":  {"titel": "Abschleppdienst", "start": "Abschleppwagen", "ablauf": "Falschparker und Wracks abschleppen", "stufen": 8, "bonus": "Werkstatt-Rabatt"},
 "kurier":     {"titel": "Kurier", "start": "Roller in der Altstadt", "ablauf": "Pakete zustellen", "stufen": 8, "bonus": "Schnellerer Roller"},
}
IMMOBILIEN = [
 {"id": "haus_lindenhof", "titel": "Elternhaus Lindenhof", "ort": "ghetto", "preis": 0, "garage": 1, "speichern": True, "hinweis": "Startversteck"},
 {"id": "wohnung_altstadt", "titel": "Altbauwohnung Altstadt", "ort": "altstadt", "preis": 25000, "garage": 2, "speichern": True},
 {"id": "loft_ost", "titel": "Loft im Ostviertel", "ort": "ost", "preis": 45000, "garage": 2, "speichern": True},
 {"id": "villa_vorort", "titel": "Villa am Hügel", "ort": "vorort", "preis": 180000, "garage": 4, "speichern": True},
 {"id": "penthouse", "titel": "Penthouse Downtown", "ort": "downtown", "preis": 350000, "garage": 6, "speichern": True},
 {"id": "berghuette", "titel": "Berghütte", "ort": "berg", "preis": 60000, "garage": 1, "speichern": True},
 {"id": "wuestenranch", "titel": "Ranch in der Wüste", "ort": "flugplatz", "preis": 90000, "garage": 3, "speichern": True},
 {"id": "garage_hafen", "titel": "Garage am Hafen", "ort": "hafen", "preis": 15000, "garage": 6, "speichern": False},
 {"id": "garage_downtown", "titel": "Tiefgarage Downtown", "ort": "downtown", "preis": 40000, "garage": 10, "speichern": False},
 {"id": "garage_ghetto", "titel": "Hinterhofgarage", "ort": "ghetto", "preis": 8000, "garage": 3, "speichern": False},
]
GESCHAEFTE = [
 {"id": "taxizentrale", "titel": "Taxizentrale Radeberg", "ort": "bahnhof", "preis": 120000,
  "betrieb": {"fahrer_max": 12, "lohn_pro_fahrer_tag": 150, "umsatz_pro_taxi_tag": [250, 450], "taxi_preis": 18000,
              "upgrades": ["Funkzentrale (+15 % Aufträge)", "Werbung (+10 % Fahrgäste)", "Elektro-Taxis (−30 % Kosten)", "Flughafen-Shuttle"],
              "missionen": ["VIP-Fahrt", "Konkurrenz sabotiert die Funkzentrale", "Fahrer überfallen – Taxi zurückholen", "Taxistreik beenden"]}},
 {"id": "logistik", "titel": "Lagerhaus & Logistikzentrum", "ort": "industrie", "preis": 250000,
  "betrieb": {"mitarbeiter_max": 20, "stapler_max": 6, "lkw_max": 8, "lager_paletten": 2000,
              "ablauf": ["LKW kommt an der Rampe an", "Stapler lädt Paletten aus", "Einlagern ins Hochregal", "Kommissionieren", "Verladen", "Auslieferung per LKW"],
              "auftraege": ["Hafen → Lager (Container)", "Lager → Downtown-Läden", "Güterbahnhof → Lager", "Eilauftrag Flugplatz"],
              "upgrades": ["Hochregal (+1000 Paletten)", "Zweite Rampe", "Nachtschicht", "Lagerverwaltung (−Fehler)"],
              "missionen": ["Diebe im Lager", "LKW-Panne auf der Autobahn", "Großauftrag Hafen", "Inventur unter Zeitdruck"]}},
 {"id": "werkstatt", "titel": "Radeberg Customs (Anteil)", "ort": "werkstatt", "preis": 80000, "betrieb": {"umsatz_tag": [400, 900]}},
 {"id": "club", "titel": "Club in der Altstadt", "ort": "altstadt", "preis": 150000, "betrieb": {"umsatz_tag": [600, 1500]}},
 {"id": "schrottplatz", "titel": "Schrottplatz", "ort": "industrie", "preis": 50000, "betrieb": {"umsatz_tag": [200, 500]}},
]
data = {"kontakte": KONTAKTE, "gangs": GANGS, "missionen": S, "jobs": JOBS, "immobilien": IMMOBILIEN, "geschaefte": GESCHAEFTE}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(data, open(OUT, 'w'), ensure_ascii=False, indent=1)
from collections import Counter
print('Missionen:', len(S), Counter(x['typ'] for x in S).most_common())
print('je Kontakt:', Counter(x['kontakt'] for x in S))
