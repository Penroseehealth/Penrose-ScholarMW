from PIL import Image
import os

SRC = r"frontend/web/_verify/shot_cutaway.png"
OUT = r"frontend/web/_verify"
im = Image.open(SRC)
w, h = im.size
print("src size", im.size)

def crop(box, out, scale=3):
    c = im.crop(box)
    c = c.resize((c.width * scale, c.height * scale), Image.LANCZOS)
    p = os.path.join(OUT, out)
    c.save(p)
    print(out, c.size)

# left wall (windows + coat rails between them), room runs diagonally upper-left
crop((0, 0, int(w * .55), int(h * .62)), "cut_left.png")
# right wall side (shell hidden in cutaway, coats hang behind)
crop((int(w * .45), int(h * .15), w, int(h * .85)), "cut_right.png")
# front whiteboard wall + teacher
crop((int(w * .3), 0, int(w * .95), int(h * .45)), "cut_front.png")
