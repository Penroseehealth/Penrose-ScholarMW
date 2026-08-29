"""Add default resources to all topics with empty resources lists."""
with open("backend/app/mathematics/seed_math_syllabus.py", "r", encoding="utf-8") as f:
    content = f.read()

# Find all occurrences of "resources": [] and replace with basic math resources
basic_resources = '''"resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],'''

import re

# Match "resources": [] with optional whitespace/newlines
pattern = r'"resources": \[\s*\]'
matches = list(re.finditer(pattern, content))
print(f"Found {len(matches)} topics with empty resources")

# Replace from end to start to preserve positions
for m in reversed(matches):
    content = content[:m.start()] + basic_resources + content[m.end():]

with open("backend/app/mathematics/seed_math_syllabus.py", "w", encoding="utf-8") as f:
    f.write(content)

print(f"Updated {len(matches)} topics with default resources")
