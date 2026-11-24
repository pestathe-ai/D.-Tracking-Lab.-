import re, urllib.request, urllib.error
UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36"
def get(u):
    try:
        with urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": UA, "Accept": "text/html,*/*"}), timeout=25) as r:
            return r.status, r.url, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, u, ""
    except Exception as e:
        return -1, u, repr(e)
out = []
for u in ["https://www.poste.it/cerca/index.html", "https://www.poste.it/cerca/", "https://www.poste.it/support-layer/www-poste-it/cerca/",
          "https://www.poste.it/cerca/views/risultati-spedizioni.html"]:
    c, final, b = get(u)
    out.append(f"=== {u}\nHTTP {c} FINAL {final} {len(b)}B")
    for m in sorted(set(re.findall(r"""(?:src|href)=["']([^"']+\.js[^"']*)["']""", b)))[:30]:
        out.append("js: " + m)
    for m in re.finditer(r"risultati-spedizioni[^\"'<> ]{0,80}", b):
        out.append("route: " + m.group(0))
    for m in re.finditer(r"[#!/]*/?ricerca[^\"'<> ]{0,60}|codiceSpedizione[^\"'<> ]{0,60}|\?[a-zA-Z]+=\{\{[^}]+\}\}", b):
        out.append("ref: " + m.group(0))
    # follow js files and search route definitions
    for js in sorted(set(re.findall(r"""(?:src)=["']([^"']+\.js[^"']*)["']""", b)))[:25]:
        url = js if js.startswith("http") else ("https://www.poste.it" + js if js.startswith("/") else final.rsplit("/",1)[0] + "/" + js)
        c2, _, jb = get(url)
        for m in re.finditer(r".{0,120}risultati-spedizioni.{0,160}", jb):
            out.append(f"jsroute[{url[-50:]}]: " + m.group(0).replace("\n"," "))
            if sum(1 for x in out if x.startswith("jsroute")) > 25: break
open("result.txt", "w").write("\n".join(out)); print("\n".join(out))
