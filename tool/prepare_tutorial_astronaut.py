import bpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(root/'output/void/ASTRONAUTA.blend'))
for ob in list(bpy.context.scene.objects):
    if ob.type!='MESH': continue
    if len(ob.data.polygons)>80:
        bpy.context.view_layer.objects.active=ob
        modifier=ob.modifiers.new('Tutorial mobile LOD','DECIMATE');modifier.ratio=.23
        bpy.ops.object.modifier_apply(modifier=modifier.name)
out=root/'output/tutorial-scene3d';out.mkdir(exist_ok=True,parents=True)
bpy.ops.export_scene.gltf(filepath=str(out/'ASTRONAUTA-DEMO.glb'),export_format='GLB',export_apply=True,export_animations=False)
