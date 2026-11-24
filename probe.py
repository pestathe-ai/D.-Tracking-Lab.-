import re, urllib.request, urllib.error
UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36"
def get(u):
    try:
        with urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": UA}), timeout=25) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except Exception as e:
        return -1, repr(e)
out = []
c, b = get("https://www.poste.it/cerca/index.html")
srcs = re.findall(r"""<script[^>]+src=["']([^"']+)["']""", b)
local = [s for s in srcs if "app-resources" not in s and "assets-da" not in s and "risorse_dt" not in s and "google" not in s]
out.append("local scripts: " + ", ".join(local))
for s in local:
    url = s if s.startswith("http") else ("https://www.poste.it" + s if s.startswith("/") else "https://www.poste.it/cerca/" + s)
    c2, jb = get(url)
    for m in re.finditer(r".{0,100}(\$stateProvider|\.state\(|url\s*:\s*['\"]/|\$location\.(path|url|search)|\$stateParams\.\w+).{0,140}", jb):
        out.append(f"[{s}] " + m.group(0).replace("\n", " "))
for m in re.finditer(r".{0,80}(ui-view|ng-app|ng-controller).{0,80}", b):
    out.append("html: " + m.group(0).replace("\n"," "))
open("result.txt", "w").write("\n".join(out)); print("\n".join(out))
