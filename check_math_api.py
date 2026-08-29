import urllib.request
import json

try:
    with urllib.request.urlopen("http://localhost:8000/api/v1/syllabus/subjects/mathematics/tree", timeout=15) as resp:
        data = json.loads(resp.read())
    # data could be a list of core_elements or a dict with versions
    if isinstance(data, dict) and "core_elements" in data:
        ces = data["core_elements"]
    elif isinstance(data, list):
        ces = data
    else:
        # Check if wrapped in versions
        versions = data.get("versions", [])
        if versions:
            ces = versions[0].get("core_elements", [])
        else:
            ces = data
    print(f"Core Elements: {len(ces)}")
    total = 0
    for ce in ces:
        topics = ce.get("topics", [])
        total += len(topics)
        print(f"  CE{ce.get('number', '?')} ({ce['name']}): {len(topics)} topics")
        for t in topics:
            subs = t.get("subtopics", [])
            print(f"    - {t['title']} (Form {t.get('year_level', '?')}) [{len(subs)} subtopics]")
    print(f"\nTotal topics: {total}")
except Exception as e:
    import traceback
    traceback.print_exc()
