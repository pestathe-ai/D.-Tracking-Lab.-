import re, urllib.request
UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36"
def get(u):
    with urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": UA}), timeout=25) as r:
        return r.read().decode("utf-8", "replace")
out = []
for f in ["app/app.js", "app/route-config.js", "app/app-run.js", "cerca-spedizioni-redirect.js"]:
    b = get("https://www.poste.it/cerca-app/js/" + f)
    for m in re.finditer(r".{0,120}(hashPrefix|html5Mode|otherwise|recaptcha|risultati-spedizioni|window\.location|\.hash).{0,160}", b, re.I):
        out.append(f"[{f}] " + m.group(0).replace("\n", " ").strip())
b = get("https://www.poste.it/cerca-app/js/module/risultati-spedizioni-controller.js")
for m in re.finditer(r".{0,100}(recaptcha|ricercasemplice|ricercaSpedizion|\$http\.|\.post\().{0,160}", b, re.I):
    out.append("[ctrl] " + m.group(0).replace("\n", " ").strip())
open("result.txt", "w").write("\n".join(out[:80])); print("\n".join(out[:80]))
