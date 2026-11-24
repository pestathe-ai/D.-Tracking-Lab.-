import html, json, os, re, time, urllib.request, urllib.error, http.cookiejar

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
UA = ("Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36")


def get(url, accept="text/html"):
    r = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": accept,
                                             "Accept-Language": "it-IT,it;q=0.9"})
    try:
        with opener.open(r, timeout=25) as resp:
            raw = resp.read()
            ct = resp.headers.get("Content-Type", "")
            enc = "iso-8859-15" if "8859" in ct else "utf-8"
            return resp.status, ct, raw.decode(enc, "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("Content-Type"), e.read().decode("utf-8", "replace")
    except Exception as e:  # noqa
        return -1, None, repr(e)


def text_of(h):
    h = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", " ", h)
    h = re.sub(r"(?i)<br\s*/?>|</(tr|p|div|li|h\d|table)>", "\n", h)
    h = re.sub(r"(?i)</t[dh]>", " | ", h)
    h = re.sub(r"<[^>]+>", " ", h)
    h = html.unescape(h)
    lines = [re.sub(r"[ \t\xa0]+", " ", l).strip(" |") for l in h.split("\n")]
    return "\n".join(l for l in lines if l.strip(" |"))


out = []
for name, url in [
    ("brt numero spedizione", "https://vas.brt.it/vas/sped_det_show.hsm?referer=sped_numspe_par.htm&Nspediz=123456789012"),
    ("brt form", "https://vas.brt.it/vas/sped_numspe_par.htm"),
    ("brt segnacollo", "https://vas.brt.it/vas/sped_det_show.hsm?referer=sped_numspe_par.htm&ChiSono=123456789012345"),
]:
    code, ct, body = get(url)
    forms = re.findall(r"(?is)<form[^>]*>|<input[^>]*>|<select[^>]*name=[^>]*>", body)
    out.append(f"=== {name}\nURL {url}\nHTTP {code} {ct}\n--- forms/inputs\n" + "\n".join(forms[:40])
               + "\n--- text\n" + text_of(body)[:4000] + "\n")

for name, url in [
    ("inpost it real-format", "https://api-shipx-it.easypack24.net/v1/tracking/IT0000000000000000000000"),
    ("inpost it statuses", "https://api-shipx-it.easypack24.net/v1/statuses?lang=it_IT"),
]:
    code, ct, body = get(url, "application/json")
    out.append(f"=== {name}\nURL {url}\nHTTP {code} {ct}\n{body[:800]}\n")

open("result.txt", "w").write("\n".join(out))
print("\n".join(out))
