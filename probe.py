import json, os, time, urllib.request, urllib.error, http.cookiejar

NUM = os.environ.get("NUM", "")
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
UA = ("Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36")


def req(name, url, data=None, headers=None):
    h = {"User-Agent": UA, "Accept": "application/json, text/plain, */*",
         "Accept-Language": "it-IT,it;q=0.9"}
    h.update(headers or {})
    body = None
    if data is not None:
        body = json.dumps(data).encode()
        h.setdefault("Content-Type", "application/json")
    r = urllib.request.Request(url, data=body, headers=h)
    t = time.time()
    try:
        with opener.open(r, timeout=25) as resp:
            txt = resp.read().decode("utf-8", "replace")
            code, ct = resp.status, resp.headers.get("Content-Type")
    except urllib.error.HTTPError as e:
        txt = e.read().decode("utf-8", "replace")
        code, ct = e.code, e.headers.get("Content-Type")
    except Exception as e:  # noqa
        txt, code, ct = repr(e), -1, None
    return f"=== {name}\nURL {url}\nHTTP {code} {ct} {len(txt)}B {time.time()-t:.1f}s\n{txt[:1500]}\n"


tests = [
    ("CC123456789IT", lambda n: req("poste ricercasemplice",
        "https://www.poste.it/online/dovequando/DQ-REST/ricercasemplice",
        {"tipoRichiedente": "WEB", "codiceSpedizione": n, "periodoRicerca": 1})),
    ("12345678901", lambda n: req("gls rstt001",
        f"https://gls-group.com/app/service/open/rest/IT/it/rstt001?match={n}")),
    ("123456789012", lambda n: req("brt vas",
        f"https://vas.brt.it/vas/sped_det_show.hsm?referer=sped_numspe_par.htm&Nspediz={n}",
        headers={"Accept": "text/html"})),
    ("123456789012", lambda n: req("brt mybrt",
        f"https://www.mybrt.it/it/mybrt/my-parcels/search?parcelNumber={n}",
        headers={"Accept": "text/html"})),
    ("1234567890", lambda n: req("dhl utapi",
        f"https://www.dhl.com/utapi?trackingNumber={n}&language=it&requesterCountryCode=IT&source=tt")),
    ("123456789012345678901234", lambda n: req("inpost it",
        f"https://api-shipx-it.easypack24.net/v1/tracking/{n}")),
    ("123456789012345678901234", lambda n: req("inpost pl",
        f"https://api-shipx-pl.easypack24.net/v1/tracking/{n}")),
    ("12345678901234", lambda n: req("dpd plc",
        f"https://tracking.dpd.de/rest/plc/it_IT/{n}")),
    ("TBA123456789012", lambda n: req("amazon tracker",
        f"https://track.amazon.it/api/tracker/{n}")),
    ("1234567890123", lambda n: req("sda page",
        f"https://www.sda.it/wps/portal/Servizi_online/dettaglio-spedizione?locale=it&tracing.letteraVettura={n}",
        headers={"Accept": "text/html"})),
    ("1Z999AA10123456784", lambda n: req("ups page",
        f"https://www.ups.com/track?loc=it_IT&tracknum={n}", headers={"Accept": "text/html"})),
]

out = [fn(NUM or fake) for fake, fn in tests]
open("result.txt", "w").write("\n".join(out))
print("\n".join(out))
