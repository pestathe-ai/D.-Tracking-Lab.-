import json, re, urllib.request, urllib.error
UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36"
def go(url, data=None, ctype=None, accept="text/html,application/json"):
    h = {"User-Agent": UA, "Accept": accept, "Accept-Language": "it-IT"}
    if ctype: h["Content-Type"] = ctype
    r = urllib.request.Request(url, data=data, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=25) as resp:
            return resp.status, resp.headers.get("Content-Type"), resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("Content-Type"), e.read().decode("utf-8", "replace")
    except Exception as e:
        return -1, None, repr(e)
out = []
fake = "JF80000000000"
code, ct, b = go("https://www.poste.it/online/dovequando/DQ-REST/ricercasemplice",
                 json.dumps({"tipoRichiedente": "WEB", "codiceSpedizione": fake, "periodoRicerca": 1}).encode(), "application/json")
out.append(f"=== poste with SDA-like fake\nHTTP {code} {ct}\n{b[:600]}")
code, ct, b = go(f"https://www.sda.it/wps/portal/Servizi_online/dettaglio-spedizione?locale=it&tracing.letteraVettura={fake}")
out.append(f"=== sda page HTTP {code} {ct} {len(b)}B")
for m in sorted(set(re.findall(r"""(?i)(?:src|href|action|url)\s*[:=]\s*["']([^"']*(?:trac|ricerc|spediz|json|rest|ajax|service|api)[^"']*)["']""", b))):
    out.append("ref: " + m)
for m in re.finditer(r"(?i)(letteraVettura|tracing)", b):
    s = max(0, m.start()-200); out.append("ctx: " + re.sub(r"\s+", " ", b[s:m.start()+300]))
    if len(out) > 60: break
txt = re.sub(r"(?is)<(script|style).*?</\1>", " ", b); txt = re.sub(r"<[^>]+>", " ", txt); txt = re.sub(r"\s+", " ", txt)
i = txt.lower().find("spedizion")
out.append("text: " + txt[max(0,i-300):i+1500])
open("result.txt", "w").write("\n".join(out)); print("\n".join(out))
