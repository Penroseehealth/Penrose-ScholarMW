"""Fix seed_chinese.py and seed_arabic.py: swap mk_g() from vocab to grammar position."""
import re, sys

def fix_seed(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Find lesson tuples where mk_g() is in vocab_data position (item[2])
    # Pattern: ("title", "desc", [\n    mk_g(...)\n], [])  -- grammar in vocab slot
    # Fix: move mk_g to grammar slot: ("title", "desc", [], [\n    mk_g(...)\n])

    # Also find nested patterns:
    # ("title", "desc", [\n    (\n        "sub",\n        "subdesc",\n        [mk_g(...)],\n        [],\n    ),\n],)

    fixed = 0

    # Pattern 1: Simple lesson with mk_g in vocab, empty grammar
    # ("title", "desc",\n  [mk_g(...)],\n  [],\n)
    pattern1 = re.compile(
        r'(\s*\(\s*\n\s*"([^"]+)",\s*\n\s*"([^"]+)",\s*\n)'  # title, desc
        r'\s*\['                                                # opening vocab list
        r'(\s*\n\s*mk_g\()'                                     # mk_g starts right after
    )

    def fix_pattern1(m):
        prefix = m.group(1)
        # Find the closing of this mk_g call and the closing ] of the list
        rest_start = m.end()
        # Count parens to find end of mk_g call
        depth = 1
        i = rest_start
        while i < len(content) and depth > 0:
            if content[i] == '(':
                depth += 1
            elif content[i] == ')':
                depth -= 1
            i += 1
        # Now find the ], that closes this list
        rest = content[i:]
        close_match = re.match(r'\s*\],\s*\n\s*\[\s*\],', rest)
        if close_match:
            mk_g_call = content[m.start(4):i]
            # Replace: move mk_g from vocab to grammar
            return prefix + '\n                        [],\n                        [\n' + ' ' * 24 + mk_g_call + content[i:i+close_match.end()].replace('[],', '').replace('],', ']') + '\n'
        return m.group(0)

    # Simpler approach: just find all instances of the problematic pattern
    # and swap them

    # Pattern: list [mk_g(...)], [] -> [], [mk_g(...)]
    # This appears in the data structure as:
    #   [\n                            <- vocab_data list open
    #     mk_g(...)                   <- BUG: grammar in vocab
    #   ],                            <- vocab close
    #   [],                           <- grammar empty

    lines = content.split('\n')
    result_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Check if this line opens a list followed by mk_g then ], []
        if stripped == '[' and 'mk_g(' in '\n'.join(lines[i+1:i+10]):
            # Look ahead to see if this list contains only mk_g and closes with ], []
            lookahead = '\n'.join(lines[i:i+15])
            # Check: [  \n  mk_g(...),  \n  ],  \n  [],
            # or: [  \n  mk_g(...),  \n  ],  \n  [],
            if re.search(r'\[\s*\n\s*mk_g\(', lookahead):
                # Find the end of this mk_g call
                depth = 0
                found_mk_g = False
                j = i + 1
                while j < len(lines):
                    for ch in lines[j]:
                        if ch == '[' and not found_mk_g:
                            pass
                        elif ch == '(':
                            depth += 1
                        elif ch == ')':
                            depth -= 1

                    if 'mk_g(' in lines[j]:
                        found_mk_g = True

                    if found_mk_g and lines[j].strip() == '],' and depth == 0:
                        # Found the close of the mk_g list
                        # Check if next is [],
                        next_line = lines[j+1].strip() if j+1 < len(lines) else ''
                        if next_line == '[],':
                            # FIX: swap - change to [], then [mk_g(...)]
                            indent = ' ' * (len(lines[i]) - len(lines[i].lstrip()))
                            inner_indent = ' ' * (len(lines[i+1]) - len(lines[i+1].lstrip()))

                            # Extract the mk_g content (everything between [ and ])
                            mk_g_lines = lines[i+1:j]
                            mk_g_block = '\n'.join(mk_g_lines)

                            # Rewrite
                            result_lines.append(f'{indent}[],')
                            result_lines.append(f'{indent}[')
                            result_lines.extend(mk_g_lines)
                            result_lines.append(f'{indent}],')
                            # Skip the old ], and [], lines
                            i = j + 2
                            fixed += 1
                            print(f"Fixed vocab/grammar swap at line {i-5}")
                            break
                    j += 1
                else:
                    result_lines.append(line)
                    i += 1
                    continue
                continue

        result_lines.append(line)
        i += 1

    if fixed > 0:
        with open(path, "w", encoding="utf-8") as f:
            f.write('\n'.join(result_lines))
        print(f"\nFixed {fixed} issues in {path}")
    else:
        print(f"No issues found in {path}")

if __name__ == "__main__":
    fix_seed(r"C:\Users\zispaas\Documents\Default Project\penrose-scholar\backend\app\languages\seed_chinese.py")
    fix_seed(r"C:\Users\zispaas\Documents\Default Project\penrose-scholar\backend\app\languages\seed_arabic.py")
