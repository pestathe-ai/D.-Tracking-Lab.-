import re, urllib.request
UA = "Mozilla/5.0"
b = urllib.request.urlopen(urllib.request.Request("https://www.poste.it/app-resources/angular.min.js", headers={"User-Agent": UA}), timeout=25).read().decode("utf-8","replace")
r = urllib.request.urlopen(urllib.request.Request("https://www.poste.it/cerca-app/js/app/app.js", headers={"User-Agent": UA}), timeout=25).read().decode("utf-8","replace")
out = ["angular header: " + b[:120].replace("\n"," "), "hashPrefix in app.js: " + str("hashPrefix" in r), "html5Mode in app.js: " + str("html5Mode" in r)]
for f in ["route-config.js", "app-run.js", "libs.js"]:
    t = urllib.request.urlopen(urllib.request.Request("https://www.poste.it/cerca-app/js/app/" + f, headers={"User-Agent": UA}), timeout=25).read().decode("utf-8","replace")
    out.append(f"{f}: hashPrefix={'hashPrefix' in t} html5Mode={'html5Mode' in t}")
    for m in re.finditer(r".{0,80}(hashPrefix|html5Mode).{0,80}", t): out.append("  " + m.group(0))
open("result.txt","w").write("\n".join(out)); print("\n".join(out))
