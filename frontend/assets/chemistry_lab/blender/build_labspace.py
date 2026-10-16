"""Build an editable, approximate 3D Chemistry Laboratory in Blender."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def material(name: str, color: tuple[float, float, float, float], roughness: float = 0.75):
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    return result


def cube(name, location, scale, surface, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(surface)
    if bevel:
        modifier = obj.modifiers.new("Soft manufactured edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def cylinder(name, location, radius, depth, surface, vertices=24, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation or (0, 0, 0),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(surface)
    bevel = obj.modifiers.new("Soft edges", "BEVEL")
    bevel.width = min(radius * 0.12, 0.025)
    bevel.segments = 2
    return obj


def look_at(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat("-Z", "Y").to_euler()


def create_lab():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    floor = material("Warm grey laboratory tile", (0.55, 0.55, 0.51, 1))
    wall = material("Soft off-white wall", (0.78, 0.79, 0.76, 1))
    blue = material("Laboratory blue cabinetry", (0.035, 0.28, 0.42, 1), 0.5)
    blue_dark = material("Deep blue equipment panels", (0.02, 0.16, 0.25, 1), 0.5)
    counter = material("Pale chemical-resistant worktop", (0.79, 0.79, 0.75, 1), 0.4)
    steel = material("Brushed laboratory steel", (0.37, 0.41, 0.41, 1), 0.28)
    glass = material("Translucent glass", (0.58, 0.78, 0.8, 0.38), 0.16)
    glass.blend_method = "BLEND"
    glass.use_nodes = True
    glass.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.38
    wood = material("Wooden reagent shelf", (0.43, 0.29, 0.15, 1))
    black = material("Instrument black", (0.035, 0.045, 0.045, 1), 0.42)
    liquid = material("Amber liquid", (0.8, 0.55, 0.1, 1), 0.28)
    red = material("Reagent red", (0.48, 0.12, 0.1, 1), 0.45)
    green = material("Reagent green", (0.14, 0.34, 0.2, 1), 0.45)

    cube("Room floor", (0, 0, -0.12), (14, 10, 0.24), floor)
    cube("Rear wall below windows", (0, -4.9, 1.51), (14, 0.22, 3.02), wall)
    cube("Rear wall above windows", (0, -4.9, 5.77), (14, 0.22, 0.86), wall)
    for x, width in ((-6.61, 0.78), (-3.3, 0.55), (-0.1, 0.55), (3.1, 0.55), (6.51, 0.98)):
        cube("Wall between windows", (x, -4.9, 4.18), (width, 0.22, 2.32), wall)
    cube("Left wall", (-7, 0, 3.1), (0.22, 10, 6.2), wall)
    cube("Right wall", (7, 0, 3.1), (0.22, 10, 6.2), wall)
    cube("Ceiling", (0, 0, 6.2), (14, 10, 0.18), wall)
    window = material("Blue daylight window glass", (0.22, 0.48, 0.55, 0.5), 0.2)
    for center_x in (-4.9, -1.7, 1.5, 4.7):
        cube("Wide laboratory window", (center_x, -4.76, 4.18), (2.65, 0.06, 2.2), window, 0)
        for dx in (-1.36, 0, 1.36):
            cube("Window divider", (center_x + dx, -4.68, 4.18), (0.055, 0.09, 2.32), steel)
        for height in (3.02, 5.34):
            cube("Window sill", (center_x, -4.68, height), (2.82, 0.09, 0.06), steel)

    cube("Continuous bench worktop", (0, -3.55, 1.78), (11.8, 1.35, 0.2), counter)
    for x in (-5.25, -3.75, -2.25, -0.75, 0.75, 2.25, 3.75, 5.25):
        cube("Blue cabinet door", (x, -2.83, 0.83), (1.35, 0.12, 1.43), blue)
        cube("Cabinet pull", (x, -2.72, 0.94), (0.31, 0.055, 0.035), steel, 0.012)

    cube("Fume hood housing", (3.7, -3.73, 3.05), (3.15, 1.12, 1.15), wall)
    cube("Fume hood canopy", (3.7, -3.65, 3.72), (3.4, 1.45, 0.18), steel)
    cube("Fume hood sash", (3.7, -3.04, 3.04), (2.75, 0.045, 0.88), glass, 0)
    cube("Fume hood work surface", (3.7, -3.62, 2.34), (3.0, 1.1, 0.12), counter)
    cube("Fume hood cabinet", (3.7, -3.75, 1.88), (3.1, 1.08, 0.95), blue_dark)
    cube("Fume hood exhaust", (3.7, -4.08, 4.22), (0.66, 0.7, 0.9), steel)

    cube("Sink rim", (-2.7, -3.52, 1.68), (1.1, 0.67, 0.13), steel)
    cube("Sink basin", (-2.7, -3.52, 1.75), (0.83, 0.43, 0.035), black)
    cylinder("Tap stem", (-2.7, -4.0, 2.1), 0.055, 0.55, steel)
    cylinder("Tap spout", (-2.48, -4.0, 2.35), 0.045, 0.48, steel, rotation=(0, math.pi / 2, 0))

    for height in (2.57, 3.13):
        cube("Reagent shelf", (-1.45, -4.38, height), (4.5, 0.48, 0.09), wood)
    for x in (-3.3, 0.4):
        cube("Shelf bracket", (x, -4.47, 2.83), (0.08, 0.1, 0.62), steel)
    bottle_materials = (green, red, counter, liquid)
    for index in range(7):
        x = -3.2 + index * 0.57
        cylinder("Reagent bottle", (x, -4.02, 2.81), 0.14, 0.38, bottle_materials[index % 4])
        cylinder("Reagent bottle stopper", (x, -4.02, 3.05), 0.07, 0.1, black)

    for x, height in ((-4.8, 0.76), (-4.1, 0.92), (-0.3, 0.7), (0.45, 0.85)):
        cylinder("Glass flask body", (x, -3.47, 1.82 + height * 0.27), 0.14, height * 0.55, glass)
        cylinder("Glass flask neck", (x, -3.47, 1.82 + height * 0.72), 0.055, height * 0.34, glass)
        cylinder("Amber reagent", (x, -3.47, 1.82 + height * 0.12), 0.13, height * 0.12, liquid)

    cube("Test tube rack base", (-1.4, -3.28, 1.9), (1.15, 0.42, 0.13), wood)
    cube("Test tube rack upper frame", (-1.4, -3.28, 2.2), (1.15, 0.42, 0.1), wood)
    for index in range(6):
        x = -1.86 + index * 0.18
        cylinder("Glass test tube", (x, -3.28, 2.38), 0.055, 0.48, glass, vertices=16)
        cylinder("Test tube sample", (x, -3.28, 2.18), 0.047, 0.16, liquid, vertices=16)

    # A recognizable compound microscope with a base, stage, arm and eyepiece.
    mx, my = -4.85, -1.95
    cylinder("Microscope base", (mx, my, 1.97), 0.36, 0.13, black)
    cube("Microscope foot", (mx, my, 1.97), (0.62, 0.34, 0.11), black)
    arm = cylinder("Microscope arm", (mx, my - 0.11, 2.42), 0.11, 0.9, steel, rotation=(0, -0.24, 0))
    arm.rotation_euler[1] = -0.24
    cube("Microscope stage", (mx + 0.06, my + 0.12, 2.44), (0.58, 0.48, 0.09), steel)
    cylinder("Microscope tube", (mx + 0.14, my + 0.01, 2.87), 0.13, 0.54, black, rotation=(0, -0.48, 0))
    cylinder("Microscope eyepiece", (mx - 0.01, my + 0.08, 3.08), 0.1, 0.18, steel, rotation=(0, -0.48, 0))
    cylinder("Microscope objective turret", (mx + 0.3, my + 0.03, 2.61), 0.17, 0.11, steel)
    for x in (mx + 0.17, mx + 0.3, mx + 0.43):
        cylinder("Microscope objective lens", (x, my + 0.1, 2.43), 0.06, 0.26, black)

    cylinder("Bunsen burner base", (1.9, -3.5, 1.94), 0.23, 0.12, steel)
    cylinder("Bunsen burner barrel", (1.9, -3.5, 2.27), 0.09, 0.58, steel)
    cylinder("Bunsen burner collar", (1.9, -3.5, 2.05), 0.13, 0.1, blue)

    cylinder("Stool seat", (-1.65, 1.15, 1.36), 0.66, 0.18, black)
    cylinder("Stool post", (-1.65, 1.15, 0.68), 0.095, 1.27, steel)
    cylinder("Stool base hub", (-1.65, 1.15, 0.1), 0.2, 0.16, steel)
    for index in range(5):
        angle = index * math.tau / 5
        x = -1.65 + math.cos(angle) * 0.48
        y = 1.15 + math.sin(angle) * 0.48
        foot = cube("Stool caster leg", (x, y, 0.06), (0.75, 0.11, 0.08), steel, 0.02)
        foot.rotation_euler[2] = angle

    bpy.ops.object.camera_add(location=(5.4, 8.6, 5.8))
    camera = bpy.context.object
    camera.name = "Chemistry Lab reference viewpoint"
    camera.data.lens = 38
    look_at(camera, (0, -1.2, 2.25))
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(-4, -1, 9))
    key = bpy.context.object
    key.name = "Soft laboratory daylight"
    key.data.energy = 4200
    key.data.shape = "DISK"
    key.data.size = 8
    look_at(key, (0, -2, 1.2))

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 853
    scene.render.resolution_percentage = 100
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.68, 0.7, 0.72, 1)
    background.inputs["Strength"].default_value = 0.8
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0.5
    scene.render.image_settings.file_format = "PNG"


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "generated",
        help="Directory for the editable Blender scene, GLB and optional preview.",
    )
    parser.add_argument("--render-preview", action="store_true", help="Render a reference-angle PNG.")
    return parser.parse_args(argv)


def main():
    args = parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    create_lab()
    scene_path = output_dir / "chemistry_laboratory_approximation.blend"
    glb_path = output_dir / "chemistry_laboratory_approximation.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(scene_path))
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB")
    if args.render_preview:
        bpy.context.scene.render.engine = "BLENDER_EEVEE"
        bpy.context.scene.render.resolution_percentage = 50
        bpy.context.scene.render.filepath = str(output_dir / "chemistry_laboratory_preview.png")
        bpy.ops.render.render(write_still=True)
    print(f"Saved editable scene: {scene_path}")
    print(f"Exported 3D model: {glb_path}")


if __name__ == "__main__":
    main()
