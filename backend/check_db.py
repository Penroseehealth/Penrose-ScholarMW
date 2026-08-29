import sqlite3
conn = sqlite3.connect("penrose_scholar.db")
c = conn.cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [r[0] for r in c.fetchall()]
mastery = [t for t in tables if "mastery" in t.lower()]
print("Mastery tables:", mastery)
c.execute("""SELECT c.id, c.title, c.subtopic_id, st.id as st_id, st.title as st_title, st.discipline_id, sd.id as sd_id, sd.subject_id, ss.subject_slug
FROM stem_concepts c
LEFT JOIN stem_subtopics st ON c.subtopic_id = st.id
LEFT JOIN stem_disciplines sd ON st.discipline_id = sd.id
LEFT JOIN stem_subjects ss ON sd.subject_id = ss.id
WHERE c.id = 1""")
print("Concept chain:", c.fetchone())
conn.close()
