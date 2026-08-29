import sqlite3

conn = sqlite3.connect("penrose_scholar.db")
c = conn.cursor()
c.execute("SELECT id FROM syllabus_subjects WHERE slug = 'mathematics'")
row = c.fetchone()
if not row:
    print("No math subject found")
    conn.close()
    exit()
sid = row[0]
print(f"Subject ID: {sid}")
c.execute("SELECT id FROM syllabus_versions WHERE subject_id = ?", (sid,))
vers = [r[0] for r in c.fetchall()]
for vid in vers:
    c.execute("SELECT id FROM syllabus_core_elements WHERE version_id = ?", (vid,))
    ces = [r[0] for r in c.fetchall()]
    for cid in ces:
        c.execute("SELECT id FROM syllabus_topics WHERE core_element_id = ?", (cid,))
        tids = [r[0] for r in c.fetchall()]
        for tid in tids:
            c.execute("SELECT id FROM syllabus_subtopics WHERE topic_id = ?", (tid,))
            sids = [r[0] for r in c.fetchall()]
            for sid2 in sids:
                c.execute("DELETE FROM syllabus_learning_objectives WHERE subtopic_id = ?", (sid2,))
            c.execute("DELETE FROM syllabus_subtopics WHERE topic_id = ?", (tid,))
            c.execute("DELETE FROM syllabus_resources WHERE topic_id = ?", (tid,))
        c.execute("DELETE FROM syllabus_topics WHERE core_element_id = ?", (cid,))
    c.execute("DELETE FROM syllabus_core_elements WHERE version_id = ?", (vid,))
c.execute("DELETE FROM syllabus_versions WHERE subject_id = ?", (sid,))
c.execute("DELETE FROM syllabus_subjects WHERE id = ?", (sid,))
conn.commit()
print("Deleted all math data")
conn.close()
