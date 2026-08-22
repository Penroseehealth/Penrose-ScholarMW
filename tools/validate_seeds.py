#!/usr/bin/env python3
"""Validate seed files: ensure no mk_g() in vocab_data positions."""
import ast, sys

def check_file(path):
    with open(path, encoding="utf-8") as f:
        source = f.read()
    tree = ast.parse(source)
    
    issues = []
    for node in ast.walk(tree):
        # Find list literals inside tuples that contain mk_g calls
        if isinstance(node, ast.Tuple) and len(node.elts) >= 3:
            # item[2] should be vocab list, item[3] should be grammar list
            vocab_node = node.elts[2]
            if isinstance(vocab_node, ast.List):
                for elt in vocab_node.elts:
                    # Check if vocab list contains a call to mk_g
                    if isinstance(elt, ast.Call):
                        func = elt.func
                        if isinstance(func, ast.Name) and func.id == "mk_g":
                            issues.append(f"  Line {elt.lineno}: mk_g() found in vocab_data (item[2])")
            # Check item[3] (grammar list) does NOT contain tuples of 7 strings
            if len(node.elts) > 3:
                grammar_node = node.elts[3]
                if isinstance(grammar_node, ast.List):
                    for elt in grammar_node.elts:
                        if isinstance(elt, ast.Tuple):
                            issues.append(f"  Line {elt.lineno}: tuple literal in grammar_data (item[3]) — should be mk_g() call")
    
    return issues

for path in sys.argv[1:]:
    issues = check_file(path)
    name = path.split("/")[-1].split("\\")[-1]
    if issues:
        print(f"FAIL {name}:")
        for i in issues:
            print(i)
    else:
        print(f"OK {name}")
