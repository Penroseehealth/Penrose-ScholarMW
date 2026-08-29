import urllib.request, json, sys
url = "http://localhost:8000/api/v1/syllabus/subjects/mathematics/tree"
try:
    with urllib.request.urlopen(url, timeout=10) as resp:
        data = json.loads(resp.read())
except Exception as e:
    print(f"FAILED: {e}"); sys.exit(1)
versions = data.get("versions", [])
ces = versions[0].get("core_elements", []) if versions else data.get("core_elements", [])
print(f"Core Elements: {len(ces)}")
total = 0
for ce in ces:
    topics = ce.get("topics", [])
    total += len(topics)
    print(f"  CE{ce.get('number','?')} ({ce['name']}): {len(topics)} topics")
    for t in topics:
        subs = t.get("subtopics", [])
        print(f"    - {t['title']} (Form {t.get('year_level','?')}) [{len(subs)} subtopics]")
print(f"\nTotal topics: {total}")
