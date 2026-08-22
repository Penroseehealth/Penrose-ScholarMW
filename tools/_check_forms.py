import json, urllib.request
r = urllib.request.urlopen('http://localhost:8000/api/v1/syllabus/subjects/biology/tree')
d = json.loads(r.read())
v = d['versions'][0]
for yr in [1,2,3,4]:
    topics = []
    for ce in v['core_elements']:
        for t in ce['topics']:
            if t.get('year_level') == yr:
                topics.append("CE%d: %s" % (ce['number'], t['title']))
    print("=== Form %d: %d topics ===" % (yr, len(topics)))
    for t in topics:
        print("  %s" % t)
    print()
