import base64, os, re, shutil, subprocess, tempfile

BROWSER = r"C:/Program Files/Google/Chrome/Application/chrome.exe"
BASE = "http://127.0.0.1:8000/biology_lab/index.html"
OUT = r"frontend/web/_verify"

jobs = [
    ("cutaway16", "view=cutaway"),               # bird's eye: both walls' coat rails
    ("aisle16", "view=aisle"),                   # benches: two-section drawers, stools
    ("aisle_open16", "view=aisle&drawers=open"), # open drawers: upper/lower sections
]

for name, qs in jobs:
    prof = tempfile.mkdtemp(prefix="biolab-shot16-")
    url = f"{BASE}?shot=1&{qs}"
    cmd = [
        BROWSER, "--headless", "--disable-gpu", "--enable-unsafe-swiftshader",
        "--use-gl=angle", "--use-angle=swiftshader", "--no-sandbox",
        "--no-first-run", f"--user-data-dir={prof}",
        "--window-size=1600,1000",
        "--virtual-time-budget=120000", "--dump-dom", url,
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=500)
        dom = r.stdout or ""
    except subprocess.TimeoutExpired as e:
        out = e.stdout
        dom = out.decode("utf-8", "replace") if isinstance(out, bytes) else (out or "")
    shot_m = re.search(r'<div id="__shotdata"[^>]*>(data:image/png;base64,[A-Za-z0-9+/=]+)</div>', dom)
    if not shot_m:
        print(f"{name}: NO SHOT DATA (dom={len(dom)} bytes)", flush=True)
    else:
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, f"shot_{name}.png")
        with open(path, "wb") as f:
            f.write(base64.b64decode(shot_m.group(1).split(",", 1)[1]))
        print(f"{name}: {path} ({os.path.getsize(path)} bytes)", flush=True)
    shutil.rmtree(prof, ignore_errors=True)
print("DONE", flush=True)
