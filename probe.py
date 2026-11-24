import re, urllib.request, urllib.parse
UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36"
out = []
for n in ["05212345678901", "1234567890123456789"]:
    data = urllib.parse.urlencode({"brtCode": n, "referer": "sped_numspe_par.htm", "RicercaBrtCode": "Ricerca"}).encode()
    r = urllib.request.Request("https://vas.brt.it/vas/sped_det_show.htm", data=data,
        headers={"User-Agent": UA, "Accept": "text/html", "Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(r, timeout=25) as resp:
            body = resp.read().decode("iso-8859-15", "replace"); code = resp.status; final = resp.url
    except Exception as e:
        body = repr(e); code = -1; final = ""
    txt = re.sub(r"(?is)<(script|style).*?</\1>", " ", body); txt = re.sub(r"<[^>]+>", " ", txt); txt = re.sub(r"\s+", " ", txt)
    i = txt.find("Ritorno")
    out.append(f"=== brtCode {len(n)} cifre\nHTTP {code} FINAL {final}\n{txt[max(0,i-100):i+400]}\n")
open("result.txt", "w").write("\n".join(out)); print("\n".join(out))
