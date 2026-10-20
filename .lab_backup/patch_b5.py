import io
p = r"frontend/web/biology_lab/index.html"
s = io.open(p, encoding='utf-8', newline='').read()
orig = len(s)

def rep(old, new, label=''):
    global s
    o = old.replace('\n', '\r\n'); n = new.replace('\n', '\r\n')
    assert s.count(o) >= 1, "ANCHOR NOT FOUND " + label + ": " + old[:100]
    s = s.replace(o, n, 1)

# railY becomes a parameter (left-wall rails must clear the 0.9 m bench top)
rep("function makeCoatRail(x,z,ry){",
    "function makeCoatRail(x,z,ry,railY){", 'C1')
rep("  var railY=1.2,span=1.5;",
    "  railY=railY||1.2;var span=1.5;", 'C2')

# re-seat the rails: left wall in front of the bench (raised above the worktop),
# right wall in front of the tall-cupboard doors; rotation flipped so coats face the room
rep(r"""makeCoatRail(-HX+.12,-2.25,Math.PI/2);
makeCoatRail(-HX+.12,.05,Math.PI/2);
makeCoatRail(-HX+.12,2.35,Math.PI/2);
makeCoatRail(HX-.12,-2.6,-Math.PI/2);
makeCoatRail(HX-.12,-.2,-Math.PI/2);
makeCoatRail(HX-.12,2.2,-Math.PI/2);""",
r"""makeCoatRail(-HX+.26,-2.25,Math.PI/2,1.72);
makeCoatRail(-HX+.26,.05,Math.PI/2,1.72);
makeCoatRail(-HX+.26,2.35,Math.PI/2,1.72);
makeCoatRail(HX-.76,-2.6,-Math.PI/2,1.2);
makeCoatRail(HX-.76,-.2,-Math.PI/2,1.2);
makeCoatRail(HX-.76,2.2,-Math.PI/2,1.2);""", 'C3')

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print("PATCH B5 OK;", orig, "->", len(s))
