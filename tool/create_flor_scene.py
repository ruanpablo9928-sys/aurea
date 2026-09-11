"""Create an original, portable Aurea flower. Run with Blender --background --python.

All geometry/textures are generated here; no downloaded assets or add-ons.
The Cycles reference uses translucency and DOF unavailable in Aurea's preview.
"""
import bpy
import math
import random
import json
import os
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output' / 'flor'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(731)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, roughness=.5, subsurface=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Subsurface Weight'].default_value = subsurface
    p.inputs['Subsurface Radius'].default_value = (.04, .018, .01)
    m.use_backface_culling = False
    return m

def texture(name, leaf=False):
    n = 1024 if not leaf else 512
    v, u = np.mgrid[0:1:complex(n), 0:1:complex(n)]
    rng = np.random.default_rng(39)
    if leaf:
        vein = np.exp(-((u-.5)*95)**2)
        vein += .4*np.exp(-(np.sin((v-np.abs(u-.5)*.8)*65)*9)**2)
        shade = .6+.3*np.sin(u*np.pi) + .18*vein
        rgb = np.stack([.14*shade, .34*shade, .075*shade], axis=-1)
    else:
        # Longitudinal fibers, branching veins and a darker magenta throat.
        fiber = np.sin(u*250+np.sin(v*14)*.6)*.018
        veins = np.exp(-(np.sin(u*48+np.sin(v*9)*.3)*12)**2)*.055
        throat = np.exp(-v*7)*.45
        flecks = rng.normal(0, .005, (n,n))
        shade = fiber-veins+flecks
        rgb = np.stack([.78-throat*.55+shade, .25-throat*.45+shade,
                        .44-throat*.6+shade], axis=-1)
    rgba = np.ones((n,n,4), dtype=np.float32)
    rgba[:,:,:3] = np.clip(rgb, .015, 1)
    img = bpy.data.images.new(name, width=n, height=n, alpha=True)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(OUT / (name+'.png'))
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img

petal = material('Pétalas • seda rosa com nervuras', (1,1,1), .72, .08)
petal.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.12
leafmat = material('Folhas • nervuras naturais', (1,1,1), .49, .07)
# A small, static garden backdrop for Aurea; the flower itself stays real 3D.
v,u=np.mgrid[0:1:512j,0:1:512j]
rgb=np.zeros((512,512,4),dtype=np.float32);rgb[:,:,3]=1
rgb[:,:,0]=.10+.11*(1-v);rgb[:,:,1]=.17+.13*(1-v);rgb[:,:,2]=.055+.04*(1-v)
rng=np.random.default_rng(204)
for i in range(22):
    x,y=rng.uniform(-.2,1.2,2);r=rng.uniform(.05,.23)
    spot=np.exp(-((u-x)**2+(v-y)**2)/(r*r))
    rgb[:,:,:3]+=spot[:,:,None]*np.array([.023,.035,.007])*rng.uniform(-2,2)
img=bpy.data.images.new('Jardim • fundo desfocado',width=512,height=512,alpha=True)
img.pixels.foreach_set(np.clip(rgb,0,1).ravel());img.filepath_raw=str(OUT/'jardim.png');img.file_format='PNG';img.save()
for mat, img in [(petal,texture('petalas')), (leafmat,texture('folhas',True))]:
    nodes=mat.node_tree.nodes
    p=nodes.get('Principled BSDF')
    tex=nodes.new('ShaderNodeTexImage'); tex.image=img
    mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    bump=nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value=.10
    bump.inputs['Distance'].default_value=.002
    mat.node_tree.links.new(tex.outputs['Color'],bump.inputs['Height'])
    mat.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
stemmat=material('Caule • verde jovem',(.095,.22,.032),.57)
gold=[material('Pólen • '+str(i),c,.63) for i,c in enumerate([
    (.72,.30,.014),(.98,.52,.027),(.57,.20,.009),(.91,.42,.022)])]
water=material('Orvalho • translúcido',(.91,.98,1),.07)
water.node_tree.nodes.get('Principled BSDF').inputs['Transmission Weight'].default_value=.95
water.node_tree.nodes.get('Principled BSDF').inputs['IOR'].default_value=1.333

objects=[]
def mesh(name, verts, faces, mat, uv=None):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    for poly in me.polygons: poly.use_smooth=True
    if uv:
        layer=me.uv_layers.new(name='UVMap')
        for poly in me.polygons:
            for li in poly.loop_indices: layer.data[li].uv=uv[me.loops[li].vertex_index]
    objects.append(ob)
    return ob

HEAD=Vector((0,0,1.32))
def petal_point(t,w,angle,length,width,phase,lift):
    # Wide scalloped lip with a narrow, cupped attachment.
    span=width*(.04+.96*math.sin(math.pi*t*.91)**.67)
    scallop=(.008*math.cos(w*math.pi*4)+.005*math.sin(w*17+phase))*t**8
    radial=.13+length*t+scallop-.18*w*w*t**6
    sideways=span*w+.022*math.sin(t*7+phase)*t
    z=.045+lift*t-.12*t*t+.025*w*w*math.sin(t*math.pi)
    z+=.005*math.sin(w*15+phase+t*4)*t+.027*math.sin(t*5+phase)*t
    return HEAD+Vector((radial*math.cos(angle)-sideways*math.sin(angle),
                        radial*math.sin(angle)+sideways*math.cos(angle),z))

petals=[]
for ring,count,length,width,lift in [(0,9,.86,.34,.08)]:
    for k in range(count):
        angle=2*math.pi*k/count+ring*.3+random.uniform(-.055,.055)
        phase=random.uniform(0,6.28)
        le=length*random.uniform(.91,1.08)
        params=(angle,le,width*random.uniform(.94,1.05),phase,lift)
        verts=[];uv=[];faces=[]; nt=30;nw=18
        for i in range(nt+1):
            for j in range(nw+1):
                t=i/nt;w=j/nw*2-1
                verts.append(petal_point(t,w,*params));uv.append((j/nw,t))
        for i in range(nt):
            for j in range(nw):
                a=i*(nw+1)+j
                faces.append((a,a+nw+1,a+nw+2,a+1))
        ob=mesh(f'Pétala {ring+1}.{k+1:02}',verts,faces,petal,uv)
        # glTF double-sided material preserves thin petals without duplicate faces.
        petals.append(params)

def tube(name, points, radii, mat, sides=10):
    vs=[];fs=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        tangent.normalize()
        a=tangent.cross(Vector((1,0,0)))
        if a.length<.01: a=tangent.cross(Vector((0,1,0)))
        a.normalize();b=tangent.cross(a).normalized()
        for j in range(sides):
            angle=2*math.pi*j/sides
            vs.append(Vector(p)+radii[i]*(a*math.cos(angle)+b*math.sin(angle)))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            fs.append((a,b,b+sides,a+sides))
    fs.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,mat)

tube('Caule curvo',[(.11*math.sin(t*2.3),.055*math.sin(t*3),-1.25+2.55*t) for t in [i/35 for i in range(36)]],
     [.025-.008*t for t in [i/35 for i in range(36)]],stemmat,12)
for k,(z,angle,length) in enumerate([(-.68,.2,.70),(-.10,3.7,.68),(.46,1.4,.44)]):
    base=Vector((.08,.035,z));direction=Vector((math.cos(angle),math.sin(angle),.4)).normalized()
    cross=Vector((-math.sin(angle),math.cos(angle),0))
    verts=[];uv=[];faces=[];rows=24;cols=8
    for i in range(rows+1):
        t=i/rows;mid=base+direction*length*t
        for j in range(cols+1):
            w=j/cols*2-1
            point=mid+cross*(.12*math.sin(math.pi*t)**.85*w)
            point.z+=.10*math.sin(t*math.pi)-.055*abs(w)*math.sin(math.pi*t)
            verts.append(point);uv.append((j/cols,t))
    for i in range(rows):
        for j in range(cols):
            a=i*(cols+1)+j;faces.append((a,a+1,a+cols+2,a+cols+1))
    mesh(f'Folha {k+1}',verts,faces,leafmat,uv)
    tube(f'Nervura {k+1}',[base+direction*length*t+Vector((0,0,.10*math.sin(t*math.pi)+.002)) for t in [i/23 for i in range(24)]],
         [.004*(1-t)+.0005 for t in [i/23 for i in range(24)]],stemmat,6)

def sphere(name, loc, scale, mat, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions,radius=1,location=loc)
    ob=bpy.context.object;ob.name=name;ob.scale=scale;ob.data.materials.append(mat)
    for f in ob.data.polygons:f.use_smooth=True
    objects.append(ob);return ob

sphere('Receptáculo dourado',HEAD+Vector((0,0,.055)),(.235,.235,.05),gold[0],3)
# A sunflower-like spiral of short anthers, joined to a few material groups.
pollen=[]
for k in range(280):
    r=.223*math.sqrt((k+.5)/280);a=k*2.399963
    x=r*math.cos(a);y=r*math.sin(a)
    z=.09+.025*math.sqrt(max(0,1-(r/.237)**2))
    ob=sphere('Antera',HEAD+Vector((x,y,z)),(.009,.009,random.uniform(.014,.024)),gold[k%4],1)
    pollen.append(ob)
bpy.ops.object.select_all(action='DESELECT')
for o in pollen:o.select_set(True)
bpy.context.view_layer.objects.active=pollen[0]
bpy.ops.object.join();pollen[0].name='Miolo • 280 anteras'
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
for k in [1,3,6,8]:
    for j in range(2):
        p=petal_point(random.uniform(.5,.85),random.uniform(-.55,.55),*petals[k])
        radius=random.uniform(.012,.022)
        p.z+=radius*.55
        sphere(f'Orvalho {k}.{j}',p,(radius,radius,radius*.72),water,2)

# Export only flower meshes. Cameras and illumination stay editable in the .blend.
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'FLOR.glb'),export_format='GLB',use_selection=True,
    export_apply=True,export_animations=False,export_cameras=False,export_lights=False,
    export_extras=False,export_image_format='AUTO',export_yup=True)
bounds=[ob.matrix_world@Vector(c) for ob in objects for c in ob.bound_box]
lo=Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
center=(lo+hi)/2;scale=2/max(hi-lo)
camloc=Vector((2.65,-4.7,6.55));target=Vector((0,0,.68))
def normalized_gltf(p):
    p=(Vector(p)-center)*scale
    return [p.x,p.z,-p.y]
metadata={'camera':normalized_gltf(camloc),'target':normalized_gltf(target),'focalLength':78,
          'width':960,'height':1200,'boundsBlender':[list(lo),list(hi)],
          'meshCount':len(objects),'referenceRenderer':'Blender Cycles; DOF and translucency',
          'nativeRenderer':'Aurea Filament; PBR without the reference DOF/translucency'}
(OUT/'scene-settings.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')

# Defocused garden, used only in the Cycles reference; no borrowed photographs.
garden=material('Jardim desfocado',(.035,.068,.013),.9)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.5))
bpy.context.object.data.materials.append(garden)
world=bpy.context.scene.world or bpy.data.worlds.new('Manhã')
bpy.context.scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.26,.14,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.32
for i in range(35):
    # Out of focus meadow leaves behind and below the subject.
    color=(random.uniform(.025,.08),random.uniform(.08,.19),.018)
    mat=material('Vegetação '+str(i),color,.8)
    sphere('Jardim distante', (random.uniform(-7,7),random.uniform(1,8),random.uniform(-1.4,-.6)),
           (random.uniform(.1,.4),random.uniform(.1,.4),random.uniform(.2,.8)),mat,1)

def area(name,loc,power,color,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);ob.location=loc
    ob.rotation_euler=(HEAD-ob.location).to_track_quat('-Z','Y').to_euler()
area('Sol suave',(-3,-4,6),450,(1,.85,.72),3)
area('Reflexo do céu',(3,1,4),220,(.78,.86,1),4)
area('Contorno de manhã',(-1,3,3),350,(1,.92,.73),2)
bpy.ops.object.camera_add(location=camloc)
cam=bpy.context.object;cam.name='Macro • flor ao amanhecer'
cam.rotation_euler=(target-camloc).to_track_quat('-Z','Y').to_euler()
cam.data.lens=78;cam.data.sensor_width=36
cam.data.dof.use_dof=True;cam.data.dof.focus_distance=(HEAD-camloc).length;cam.data.dof.aperture_fstop=16
scene=bpy.context.scene;scene.camera=cam
# Match a real flower's size (about 6 cm), so optical depth of field is macro.
for ob in scene.objects:
    ob.location *= .03
    if ob.type=='MESH':ob.scale *= .03
    if ob.type=='LIGHT':
        ob.data.energy *= .03**2
        ob.data.size *= .03
cam.data.dof.focus_distance *= .03
cam.data.clip_start=.001
scene.render.engine='CYCLES';scene.cycles.samples=96;scene.cycles.use_denoising=True
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    if any(d.type=='OPTIX' for d in prefs.devices):scene.cycles.device='GPU'
except Exception as e:print('Cycles CPU fallback:',str(e))
scene.render.resolution_x=960;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'FLOR-referencia-cycles.png')
scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'FLOR.blend'))
if os.environ.get('AUREA_FLOWER_NO_RENDER')!='1':bpy.ops.render.render(write_still=True)
print('FLOWER COMPLETE:',str(OUT))

