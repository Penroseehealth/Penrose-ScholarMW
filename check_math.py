import sqlite3

conn = sqlite3.connect("penrose_scholar.db")
c = conn.cursor()
c.execute("SELECT id FROM syllabus_subjects WHERE slug = 'mathematics'")
row = c.fetchone()
if not row:
    print("No math subject")
    conn.close()
    exit()
sid = row[0]
c.execute("SELECT id FROM syllabus_versions WHERE subject_id = ?", (sid,))
vers = [r[0] for r in c.fetchall()]
for vid in vers:
    c.execute("SELECT id, number, name FROM syllabus_core_elements WHERE version_id = ? ORDER BY number", (vid,))
    for r in c.fetchall():
        c.execute("SELECT COUNT(*) FROM syllabus_topics WHERE core_element_id = ?", (r[0],))
        tc = c.fetchone()[0]
        print(f"CE {r[1]}: {r[2]} (id={r[0]}, {tc} topics)")
c.execute("SELECT COUNT(*) FROM syllabus_topics WHERE core_element_id IN (SELECT id FROM syllabus_core_elements WHERE version_id IN (SELECT id FROM syllabus_versions WHERE subject_id = ?))", (sid,))
print(f"Total topics: {c.fetchone()[0]}")
c.execute("SELECT COUNT(*) FROM syllabus_learning_objectives WHERE subtopic_id IN (SELECT id FROM syllabus_subtopics WHERE topic_id IN (SELECT id FROM syllabus_topics WHERE core_element_id IN (SELECT id FROM syllabus_core_elements WHERE version_id IN (SELECT id FROM syllabus_versions WHERE subject_id = ?)))))", (sid,))
print(f"Total learning objectives: {c.fetchone()[0]}")
conn.close()
