import urllib.request, json, sys
url = "http://localhost:8000/api/v1/syllabus/subjects/mathematics/tree"
try:
    with urllib.request.urlopen(url, timeout=10) as resp:
        data = json.loads(resp.read())
except Exception as e:
    print(f"FAILED: {e}"); sys.exit(1)
versions = data.get("versions", [])
ces = versions[0].get("core_elements", []) if versions else data.get("core_elements", [])
total = sum(len(ce.get("topics", [])) for ce in ces)
subs = sum(len(s.get("subtopics", [])) for ce in ces for s in ce.get("topics", []))
los = sum(len(lo) for ce in ces for t in ce.get("topics", []) for s in t.get("subtopics", []) for lo in [s.get("learning_objectives", [])])
print(f"CEs: {len(ces)}, Topics: {total}, Subtopics: {subs}, Objectives: {los}")
# Check for duplicate titles
titles = [(ce["number"], t["title"], t.get("year_level")) for ce in ces for t in ce.get("topics", [])]
from collections import Counter
dups = {k: v for k, v in Counter(titles).items() if v > 1}
if dups:
    print(f"DUPLICATES: {dups}")
else:
    print("No duplicates")
