"""
Common utilities for Cabrera Harvest Blender sprite generation.

Usage:
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from common import setup_scene, render_frame, make_sprite_sheet
"""

import bpy
import os


def setup_scene(resolution: tuple = (59, 49)):
    """
    Clear the default Blender scene and configure for sprite rendering.

    - Removes all default objects (cube, light, camera)
    - Creates an orthographic camera
    - Sets render resolution and transparent background
    - Uses Eevee for fast rendering
    """
    # Clear all objects
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

    # Also clear orphan data
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in bpy.data.cameras:
        if block.users == 0:
            bpy.data.cameras.remove(block)
    for block in bpy.data.lights:
        if block.users == 0:
            bpy.data.lights.remove(block)

    # Create orthographic camera
    cam_data = bpy.data.cameras.new("SpriteCamera")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 2.0

    cam_obj = bpy.data.objects.new("SpriteCamera", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    # Default: front view with slight top-down angle
    cam_obj.location = (0, -3, 1.5)
    cam_obj.rotation_euler = (1.2, 0, 0)

    # Create sun light with warm tint
    light_data = bpy.data.lights.new("SpriteSun", type='SUN')
    light_data.energy = 3.0
    light_data.color = (1.0, 0.95, 0.9)

    light_obj = bpy.data.objects.new("SpriteSun", light_data)
    light_obj.rotation_euler = (0.8, 0.2, -0.5)
    bpy.context.scene.collection.objects.link(light_obj)

    # Render settings
    scene = bpy.context.scene
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

    # Eevee settings for clean renders
    scene.eevee.taa_render_samples = 16

    print(f"Scene configured: {resolution[0]}x{resolution[1]}, orthographic, transparent background")


def render_frame(output_path: str):
    """Render the current scene to a PNG file."""
    bpy.context.scene.render.filepath = output_path
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {output_path}")


def make_sprite_sheet(frame_paths: list, output_path: str, cols: int = 4):
    """
    Assemble individual frame PNGs into a horizontal sprite sheet.

    Requires Pillow (PIL). Install with: pip install Pillow
    """
    try:
        from PIL import Image
    except ImportError:
        print("ERROR: Pillow is required for sprite sheet assembly.")
        print("Install with: pip install Pillow")
        return

    if not frame_paths:
        print("ERROR: No frames to assemble.")
        return

    frames = [Image.open(p) for p in frame_paths]
    frame_w, frame_h = frames[0].size

    rows = (len(frames) + cols - 1) // cols
    sheet_w = frame_w * min(cols, len(frames))
    sheet_h = frame_h * rows

    sheet = Image.new('RGBA', (sheet_w, sheet_h), (0, 0, 0, 0))

    for i, frame in enumerate(frames):
        col = i % cols
        row = i // cols
        sheet.paste(frame, (col * frame_w, row * frame_h))

    sheet.save(output_path)
    print(f"Sprite sheet: {output_path} ({sheet_w}x{sheet_h}, {len(frames)} frames)")


def make_flat_material(name: str, color: tuple, roughness: float = 0.9) -> bpy.types.Material:
    """
    Create a flat/matte material matching the Pixelwood Valley art style.

    Args:
        name: Material name
        color: RGBA tuple (0-1 range), e.g., (0.3, 0.65, 0.2, 1.0)
        roughness: Surface roughness (0.9 = very matte)
    """
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = 0.05
    return mat


def clear_scene_objects():
    """Remove all mesh objects from the scene (keeps camera and lights)."""
    for obj in list(bpy.data.objects):
        if obj.type == 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)

    # Clean orphan meshes
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
