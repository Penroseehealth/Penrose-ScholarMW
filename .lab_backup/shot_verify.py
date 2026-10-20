import base64, os, re, shutil, subprocess, tempfile

# Edge silently forwards launches to its running window on this machine (no DOM, no
# screenshot); Chrome with a fresh user-data-dir behaves.
BROWSER = r"C:/Program Files/Google/Chrome/Application/chrome.exe"
if not os.path.exists(BROWSER):
    BROWSER = r"C:/Program Files (x86)/Google/Chrome/Application/chrome.exe"
assert os.path.exists(BROWSER), "no Chrome found"
BASE = "http://127.0.0.1:8000/biology_lab/index.html"
OUT = r"frontend/web/_verify"

# view= preset snaps the camera at init; shot=1 renders 8 frames synchronously and
# parks the PNG in #__shotdata (document.title -> SHOTREADY).
jobs = [
    ("wall", "view=wall"),                      # left wall: windows, curtains, 3 coat rails
    ("cutaway", "view=cutaway"),                # bird's eye: right wall coats from behind
    ("aisle", "view=aisle"),                    # benches: two-section drawers, stools
    ("overview", "view=overview"),              # default angle
    ("aisle_open", "view=aisle&drawers=open"),  # open drawers showing both sections
]

for name, qs in jobs:
    prof = tempfile.mkdtemp(prefix="biolab-shot-")
    url = f"{BASE}?shot=1&{qs}"
    cmd = [
        BROWSER, "--headless", "--disable-gpu", "--enable-unsafe-swiftshader",
        "--use-gl=angle", "--use-angle=swiftshader", "--no-sandbox",
        "--no-first-run", f"--user-data-dir={prof}",
        "--virtual-time-budget=120000", "--dump-dom", url,
    ]
    dom = ""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=400)
        dom = r.stdout or ""
    except subprocess.TimeoutExpired as e:
        out = e.stdout
        dom = out.decode("utf-8", "replace") if isinstance(out, bytes) else (out or "")
    title_m = re.search(r"<title[^>]*>([^<]*)</title>", dom)
    title = title_m.group(1) if title_m else "?"
    shot_m = re.search(r'<div id="__shotdata"[^>]*>(data:image/png;base64,[A-Za-z0-9+/=]+)</div>', dom)
    if not shot_m:
        print(f"{name}: NO SHOT DATA (title={title!r}, dom={len(dom)} bytes)")
    else:
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, f"shot_{name}.png")
        with open(path, "wb") as f:
            f.write(base64.b64decode(shot_m.group(1).split(",", 1)[1]))
        print(f"{name}: {path} ({os.path.getsize(path)} bytes)")
    shutil.rmtree(prof, ignore_errors=True)
print("DONE")
