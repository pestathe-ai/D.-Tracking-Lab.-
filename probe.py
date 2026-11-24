import re, urllib.request, urllib.error, http.cookiejar

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
UA = ("Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36")


def get(url, accept="text/html,application/json"):
    r = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": accept,
                                             "Accept-Language": "it-IT,it;q=0.9"})
    try:
        with opener.open(r, timeout=25) as resp:
            raw = resp.read()
            ct = resp.headers.get("Content-Type", "")
            return resp.status, ct, raw.decode("iso-8859-15" if "8859" in ct else "utf-8", "replace"), resp.url
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("Content-Type"), e.read().decode("utf-8", "replace"), url
    except Exception as e:  # noqa
        return -1, None, repr(e), url


out = []
# 1) Sezione DPD dentro le pagine BRT
code, ct, body, _ = get("https://vas.brt.it/vas/sped_numspe_par.htm")
i = body.find("Trak&Trace DPD")
out.append("=== brt DPD section\n" + body[i:i + 3000] if i >= 0 else "=== brt DPD section: not found")
for m in re.finditer(r"(?i)dpd[^\"'<>]{0,80}", body):
    out.append("dpd ref: " + m.group(0))

# 2) Endpoint DPD
for name, url in [
    ("dpd plc json", "https://tracking.dpd.de/rest/plc/it_IT/05212345678901"),
    ("dpd status page", "https://tracking.dpd.de/status/it_IT/parcel/05212345678901"),
    ("dpd it site", "https://www.dpd.com/it/it/ricevere-pacchi/traccia-il-tuo-pacco/"),
    ("dpd group api", "https://www.dpdgroup.com/it/mydpd/my-parcels/incoming?parcelNumber=05212345678901"),
    ("brt chisono dpd", "https://vas.brt.it/vas/sped_det_show.hsm?referer=sped_numspe_par.htm&ChiSono=05212345678901"),
]:
    code, ct, body, final = get(url)
    txt = re.sub(r"(?is)<(script|style).*?</\1>", " ", body)
    txt = re.sub(r"<[^>]+>", " ", txt)
    txt = re.sub(r"\s+", " ", txt)
    out.append(f"=== {name}\nURL {url}\nFINAL {final}\nHTTP {code} {ct} {len(body)}B\n{txt[:1200]}\n")

open("result.txt", "w").write("\n".join(out))
print("\n".join(out))
