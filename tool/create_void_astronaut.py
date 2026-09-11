"""Original astronaut for the native Aurea 3D scene. Blender 5.2, no external assets."""
import bpy
import math
import random
from mathutils import Vector
from pathlib import Path
import numpy as np

OUT=Path(__file__).resolve().parents[1]/'output'/'void'
OUT.mkdir(parents=True,exist_ok=True)
random.seed(813)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def mat(name,color,rough=.5,metal=0,emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1)
        p.inputs['Emission Strength'].default_value=emission
    return m

cloth=mat('01 • Tecido branco cerâmico',(.70,.77,.79),.82)
joint=mat('02 • Juntas de pressão',(.095,.13,.15),.72)
white=mat('03 • Estrutura marfim',(.78,.83,.82),.4)
orange=mat('04 • Faixas de resgate',(.80,.13,.025),.52)
dark=mat('05 • Grafite',(.015,.026,.035),.58)
silver=mat('06 • Alumínio anodizado',(.38,.45,.47),.35,.55)
gold=mat('07 • Aro dourado',(.66,.32,.055),.28,.45)
cyan=mat('08 • Indicadores azuis',(.03,.55,.82),.3,0,1)
screen=mat('09 • Tela',(.006,.025,.034),.3)
visor=mat('10 • Visor',(.12,.18,.21),.24,.28)

# A designed environment reflection on the visor, portable as base color.
# It is a texture, not realtime ray-traced reflection.
n=512;v,u=np.mgrid[0:1:512j,0:1:512j]
pixels=np.ones((n,n,4),dtype=np.float32)
base=np.exp(-((u-.82)/.11)**2-((v-.7)/.28)**2)
edge=np.exp(-((u-.9)/.018)**2)*np.exp(-((v-.58)/.32)**2)
warm=np.exp(-((u-.13)/.08)**2-((v-.52)/.26)**2)
pixels[:,:,0]=.022+base*.04+edge*.35+warm*.22
pixels[:,:,1]=.037+base*.13+edge*.48+warm*.11
pixels[:,:,2]=.050+base*.21+edge*.58+warm*.03
img=bpy.data.images.new('Reflexo do vazio',width=n,height=n,alpha=True)
img.pixels.foreach_set(pixels.ravel());img.filepath_raw=str(OUT/'visor.png');img.file_format='PNG';img.save();img.pack()
tex=visor.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
visor.node_tree.links.new(tex.outputs['Color'],visor.node_tree.nodes['Principled BSDF'].inputs['Base Color'])

def finish(ob,name,m):
    ob.name=name;ob.data.materials.append(m)
    for p in ob.data.polygons:p.use_smooth=True
    return ob

def ellipsoid(name,p,s,m,segments=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=p)
    ob=bpy.context.object;ob.scale=s;return finish(ob,name,m)

def box(name,p,s,m,bevel=.05):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p)
    ob=bpy.context.object;ob.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Costuras arredondadas','BEVEL');mod.width=bevel;mod.segments=3
        bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(ob,name,m)

def cylinder(name,a,b,r,m,r2=None):
    a=Vector(a);b=Vector(b);d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2)
    ob=bpy.context.object;ob.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return finish(ob,name,m)

def ring(name,p,r,thick,m,normal=(0,0,1)):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=6,location=p,major_radius=r,minor_radius=thick)
    ob=bpy.context.object;ob.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler()
    return finish(ob,name,m)

def limb(name,a,b,r,m):
    a=Vector(a);b=Vector(b);d=b-a
    ob=ellipsoid(name,(a+b)/2,(r,r,d.length*.5+r*.25),m)
    ob.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    # Pressure folds follow the limb rather than floating around its center.
    for k,t in enumerate([.2,.31,.43,.56,.69,.8]):
        rr=r*math.sqrt(max(.15,1-((t-.5)*1.6)**2))
        ring(name+' • dobra '+str(k),a+d*t,rr,.011,cloth,d)
    return ob

# Front is -Y, up is Z. glTF export converts to Aurea Y-up.
box('Mochila de suporte à vida',(0,.31,.44),(.83,.43,1.07),white,.11)
box('Mochila • tampa',(0,.56,.42),(.62,.09,.77),silver,.05)
for x in [-.33,.33]:
    box('Mochila • faixa',(x,.57,.43),(.06,.025,.80),orange,.012)
for z in [.65,.53,.41,.29]:box('Mochila • radiador',(0,.619,z),(.39,.015,.033),dark,.008)
cylinder('Antena',( .31,.4,.90),(.39,.46,1.37),.012,silver)
ellipsoid('Base do tronco',(0,0,.40),(.47,.32,.67),cloth)
ellipsoid('Bacia',(0,0,-.20),(.40,.29,.33),cloth)
ring('Cinturão',(0,0,-.15),.34,.055,joint)
for x in [-.31,.31]:box('Fecho lateral',(x,-.24,-.13),(.13,.09,.12),silver,.02)

# Helmet shell, neck coupling and front-facing convex visor.
ring('Trava cervical',(0,0,.92),.31,.068,silver)
ring('Anel cervical interno',(0,0,.96),.29,.04,joint)
ellipsoid('Capacete',(0,0,1.27),(.465,.415,.465),white,40,24)
for x in [-.435,.435]:
    ellipsoid('Módulo lateral do capacete',(x,.015,1.28),(.065,.18,.16),silver)
    ellipsoid('Parafuso lateral',(x*1.1,-.045,1.30),(.025,.055,.055),dark)
verts=[];uv=[];faces=[];radials=14;angular=64
for i in range(radials+1):
    r=i/radials
    for j in range(angular):
        a=2*math.pi*j/angular
        x=.395*r*math.cos(a);z=.305*r*math.sin(a)
        verts.append((x,-.325-.15*math.sqrt(max(0,1-r*r)),1.29+z))
        uv.append((.5+x/.79,.5+z/.61))
for i in range(radials):
    for j in range(angular):
        a=i*angular+j;b=i*angular+(j+1)%angular
        faces.append((a,b,b+angular,a+angular))
me=bpy.data.meshes.new('Visor convexo');me.from_pydata(verts,[],faces);me.update()
ob=bpy.data.objects.new('Visor convexo',me);bpy.context.collection.objects.link(ob);finish(ob,'Visor convexo',visor)
layer=me.uv_layers.new()
for poly in me.polygons:
    for li in poly.loop_indices:layer.data[li].uv=uv[me.loops[li].vertex_index]

def curve(name,points,r,m):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=12
    data.bevel_depth=r;data.bevel_resolution=3
    sp=data.splines.new('POLY');sp.points.add(len(points)-1)
    for p,xyz in zip(sp.points,points):p.co=(*xyz,1)
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);ob.data.materials.append(m)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    bpy.ops.object.convert(target='MESH');ob.select_set(False)
    return ob

for radius,m in [(.025,dark),(.010,gold)]:
    curve('Vedação do visor',[(.404*math.cos(a),-.326-radius*.4,1.29+.315*math.sin(a)) for a in [j*2*math.pi/96 for j in range(97)]],radius,m)
box('Luz do capacete',(-.30,-.26,1.61),(.13,.14,.08),dark,.025)
box('Lente do capacete',(-.30,-.34,1.61),(.095,.02,.035),cyan,.01)

# Floating, asymmetrical pose; limbs are real rounded geometry.
arms=[('Esquerdo',(-.42,0,.67),(-.86,.015,.53),(-1.02,-.09,1.02)),
      ('Direito',(.42,0,.64),(.82,-.005,.23),(1.15,-.19,.48))]
for name,shoulder,elbow,wrist in arms:
    ellipsoid('Ombro '+name,shoulder,(.25,.26,.25),cloth)
    limb('Braço '+name,shoulder,elbow,.19,cloth)
    ellipsoid('Cotovelo '+name,elbow,(.18,.18,.18),joint)
    limb('Antebraço '+name,elbow,wrist,.165,cloth)
    d=(Vector(wrist)-Vector(elbow)).normalized()
    ring('Trava da luva '+name,wrist,.16,.035,orange,d)
    palm=Vector(wrist)+d*.14
    ellipsoid('Luva '+name,palm,(.15,.12,.18),white)
    for j in range(4):
        base=palm+Vector(((j-1.5)*.055,-.045,0))+d*.08
        tip=base+d*(.13-abs(j-1.5)*.02)+Vector((0,-.07,0))
        cylinder('Dedo '+name,base,tip,.028,white)
        ellipsoid('Ponta da luva',tip,(.029,.029,.03),joint,12,6)

legs=[('Esquerda',(-.22,0,-.26),(-.38,-.07,-.86),(-.56,.23,-1.36)),
      ('Direita',(.22,0,-.26),(.44,-.04,-.77),(.67,.12,-1.18))]
for name,hip,knee,ankle in legs:
    limb('Coxa '+name,hip,knee,.24,cloth)
    ellipsoid('Joelho '+name,knee,(.225,.23,.20),joint)
    box('Proteção do joelho '+name,(knee[0],knee[1]-.19,knee[2]),(.28,.10,.20),white,.045)
    limb('Canela '+name,knee,ankle,.19,cloth)
    d=(Vector(ankle)-Vector(knee)).normalized()
    ring('Tornozelo '+name,ankle,.18,.035,orange,d)
    boot=Vector(ankle)+Vector((0,-.12,-.12))
    box('Bota '+name,boot,(.37,.50,.27),white,.08)
    box('Solado '+name,boot+Vector((0,0,-.12)),(.38,.52,.07),dark,.022)
    for j in range(5):box('Friso do solado',(boot.x,boot.y-.20+j*.10,boot.z-.16),(.36,.035,.023),joint,.005)

box('Controle peitoral',(0,-.305,.46),(.56,.16,.45),silver,.05)
box('Painel frontal',(0,-.401,.46),(.48,.035,.36),white,.025)
box('Monitor',(-.055,-.424,.52),(.27,.018,.14),screen,.016)
for i in range(3):box('Telemetria',(-.11+i*.061,-.437,.51+i*.01),(.036,.009,.014),cyan,.003)
for x in [-.15,0,.15]:
    cylinder('Conector',(x,-.415,.34),(x,-.46,.34),.037,gold)
    cylinder('Entrada',(x,-.46,.34),(x,-.47,.34),.018,dark)
for z in [.61,.52,.43]:box('Botão',( .18,-.434,z),(.045,.014,.04),orange,.006)
box('Identificação A-07',(-.22,-.294,.78),(.22,.025,.055),dark,.008)
for i in range(3):box('Patch • barras',(-.275+i*.038,-.311,.78),(.019,.006,.022),white,.001)
for s in [-1,1]:
    pts=[]
    for i in range(33):
        t=i/32
        pts.append((s*(.20+.22*math.sin(t*math.pi)),-.40-.055*math.sin(t*math.pi),.31-.48*t))
    curve('Mangueira de oxigênio',pts,.026,orange)
    for i in range(2,31,3):
        d=Vector(pts[i+1])-Vector(pts[i-1]);ring('Nervura da mangueira',pts[i],.029,.008,joint,d)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'ASTRONAUTA.glb'),export_format='GLB',export_apply=True,
    export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
bpy.context.scene.world.color=(.002,.003,.006)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'ASTRONAUTA.blend'))
print('ASTRONAUT READY',str(OUT/'ASTRONAUTA.glb'))
