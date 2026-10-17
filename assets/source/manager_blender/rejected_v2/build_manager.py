"""店长可编辑二维骨骼源工程。由官方 Blender 4.5.9 的 Python 执行。"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/source/manager_blender'
OUT = ROOT / 'tmp/manager_blender/frames'
FPS = 30
CELL = (176, 192)
ORIGIN = (88, 184)
SCALE = 2
STRIDE = 14.0
SPEED = 14.0
HIP = 22.0
ANKLE = 3.8
HIP_X = (-12.5, 11.75)
LEG_LENGTH = (HIP - ANKLE) / 2
DEPTH = {'tail': .4, 'far_arm': .3, 'far_leg': .2, 'near_leg': .1,
         'torso': 0, 'near_arm': -.1, 'glass': -.15, 'hold_arm': -.2, 'head': -.3}

# 原稿像素坐标；未对原稿作抠图重绘，UV 窗口使用完整独立部件。
PARTS = {
    'head': {'rect': [16, 35, 437, 441], 'pivot': [225, 388], 'at': [0, 51], 'scale': [.106, .106], 'bone': 'head'},
    'torso': {'rect': [180, 90, 1110, 1170], 'pivot': [650, 1160], 'at': [0, 0], 'scale': [.05, .05], 'bone': 'body', 'atlas': 'body_core_v2.png'},
    'near_arm': {'rect': [965, 60, 1145, 446], 'pivot': [1030, 123], 'at': [-15, 45], 'scale': [.07, .07], 'bone': 'arm_near'},
    'far_arm': {'rect': [130, 486, 334, 863], 'pivot': [235, 548], 'at': [14, 44], 'scale': [.064, .064], 'bone': 'arm_far'},
    'tail': {'rect': [47, 879, 397, 1237], 'pivot': [355, 1190], 'at': [-17, 24], 'scale': [.075, .075], 'bone': 'tail'},
    'hold_arm': {'rect': [450, 914, 834, 1200], 'pivot': [553, 990], 'at': [-15, 43], 'scale': [.075, .075], 'bone': 'hold_arm'},
    'glass': {'rect': [976, 976, 1124, 1150], 'pivot': [1050, 1124], 'at': [3.2, 36.8], 'scale': [.058, .058], 'bone': 'glass'},
}


def smooth(t):
    return t * t * (3 - 2 * t)


def interp(keys, t):
    for (ta, a), (tb, b) in zip(keys, keys[1:]):
        if t <= tb:
            u = smooth(max(0, (t - ta) / (tb - ta)))
            return a + (b - a) * u
    return keys[-1][1]


def contact(phase):
    """已定稿脚目标关键姿势：接触、压重、经过、抬起；支撑严格线性。"""
    p = phase % 1.0
    if p <= .6:
        return 4.2 - STRIDE * p, ANKLE, 0.0, True
    u = (p - .6) / .4
    x = interp([(0, -4.2), (.25, -3.2), (.5, .2), (.75, 3.1), (1, 4.2)], u)
    z = ANKLE + 2.0 * math.sin(math.pi*u)**2
    pitch = math.radians(interp([(0, 0), (.25, -5), (.5, 0), (.75, 4), (1, 0)], u))
    return x, z, pitch, False


def pose_data(kind, t):
    if kind == 'idle':
        return {'height': HIP - .2 + .08 * math.sin(t * math.tau), 'feet': [(HIP_X[0], ANKLE, 0, True), (HIP_X[1], ANKLE, 0, True)], 'swing': 0, 'root': 0}
    if kind == 'walk':
        near, far = contact(t), contact(t + .5)
        h = 21.35 + .25 * math.sin(t*math.tau)**2
        return {'height': h, 'feet': [(near[0]+HIP_X[0], *near[1:]), (far[0]+HIP_X[1], *far[1:])], 'swing': math.cos(t * math.tau), 'root': STRIDE*t}
    if kind == 'start':
        # 后脚固定世界位置；近脚先抬起再落入循环接触姿态。
        root = 2.8 * t**(10/3)
        end = pose_data('walk', 0)
        feet = [(HIP_X[0] + 7*smooth(t) - root, ANKLE + 1.7*math.sin(math.pi*t)**2, math.radians(3*math.sin(math.pi*t)), t in (0,1)), (HIP_X[1]-root,ANKLE,0,True)]
        height=(HIP-.2) + (end['height']-(HIP-.2))*smooth(t)
        return {'height': height, 'feet': feet, 'swing': smooth(t), 'root': root}
    # 从循环的相同接触姿态减速收步，前脚保持落地，远脚收回。
    root = 4.2 * (1-(1-t)**(26/9))
    begin = pose_data('walk', 0)
    feet = [(begin['feet'][0][0]-root,ANKLE,0,True), (begin['feet'][1][0] + 7*smooth(t)-root,ANKLE+1.7*math.sin(math.pi*t)**2,math.radians(3*math.sin(math.pi*t)), t in (0,1))]
    return {'height': 21.35 + (HIP-.2-21.35)*smooth(t), 'feet': feet, 'swing': 1-smooth(t), 'root': root}


def build_rig():
    data = bpy.data.armatures.new('店长骨骼')
    rig = bpy.data.objects.new('ManagerRig', data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    defs = [
        ('root', (0,0), (0,10), None), ('body', (0,HIP), (0,51), 'root'),
        ('head', (0,50), (0,73), 'body'), ('tail', (-17,24), (-33,33), 'body'),
        ('arm_near', (-15,45), (-15,22), 'body'), ('arm_far', (14,44), (14,21), 'body'),
        ('hold_arm', (-15,43), (-15,31), 'body'), ('glass', (3.2,36.8), (3.2,43.8), 'hold_arm')]
    for side, x in zip(['near','far'],HIP_X):
        defs += [(f'thigh_{side}',(x,HIP),(x,HIP-LEG_LENGTH),'body'),(f'shin_{side}',(x,HIP-LEG_LENGTH),(x,ANKLE),f'thigh_{side}'),(f'foot_{side}',(x,ANKLE),(x+8,ANKLE),f'shin_{side}')]
    for name, a, b, parent in defs:
        bone = data.edit_bones.new(name)
        bone.head = (a[0],0,a[1]); bone.tail = (b[0],0,b[1])
        bone.align_roll(Vector((0,-1,0)))
        if parent: bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for bone in rig.pose.bones:
        bone.rotation_mode = 'XYZ'
    rig.show_in_front = True
    rig['held'] = 0.0
    return rig


def make_material(image):
    mat = bpy.data.materials.new('原画透明贴图')
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    tex=nodes.new('ShaderNodeTexImage'); tex.image=image; tex.interpolation='Linear'; tex.extension='CLIP'
    emission=nodes.new('ShaderNodeEmission'); links.new(tex.outputs['Color'],emission.inputs['Color'])
    transparent=nodes.new('ShaderNodeBsdfTransparent')
    # 生成原稿低 alpha 边缘含彩色残余；仅在材质中裁切，原稿保持原样。
    alpha=nodes.new('ShaderNodeMath'); alpha.operation='GREATER_THAN'; alpha.inputs[1].default_value=.88
    links.new(tex.outputs['Alpha'],alpha.inputs[0])
    mix=nodes.new('ShaderNodeMixShader'); links.new(alpha.outputs[0],mix.inputs[0]); links.new(transparent.outputs[0],mix.inputs[1]); links.new(emission.outputs[0],mix.inputs[2])
    out=nodes.new('ShaderNodeOutputMaterial'); links.new(mix.outputs[0],out.inputs['Surface'])
    return mat


def make_part(name, spec, rig, material):
    x0,y0,x1,y1=spec['rect']; sx,sz=spec['scale']; px,py=spec['pivot']; ax,az=spec['at']
    nx=max(2,math.ceil((x1-x0)*sx/.9)); nz=max(2,math.ceil((y1-y0)*sz/.9))
    vertices=[]; uvs=[]; faces=[]
    for j in range(nz+1):
        y=y0+(y1-y0)*j/nz
        for i in range(nx+1):
            x=x0+(x1-x0)*i/nx
            vertices.append((ax+(x-px)*sx,DEPTH[name],az+(py-y)*sz))
            uvs.append((x/1254,1-y/1254))
    for j in range(nz):
        for i in range(nx):
            a=j*(nx+1)+i; faces.append((a,a+1,a+nx+2,a+nx+1))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    uv=mesh.uv_layers.new(name='原稿 UV')
    for face in mesh.polygons:
        for li in face.loop_indices: uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj); obj.data.materials.append(material)
    if name == 'torso':
        # 一张连续底稿/网格；腹部权重向大腿渐变，腿根没有叠片边缘。
        groups={n:obj.vertex_groups.new(name=n) for n in ['body','thigh_near','shin_near','foot_near','thigh_far','shin_far','foot_far']}
        for i,v in enumerate(vertices):
            z=v[2]
            pelvis=smooth(max(0,min(1,(z-15)/11)))
            # 肥厚腿部不能沿窄带折叠：宽过渡并让胯心继续随骨盆。
            central=(max(0,1-abs(v[0])/12))**.7
            pelvis=max(pelvis,central*smooth(max(0,min(1,(z-8)/7))))
            knee=smooth(max(0,min(1,(z-5.9)/14)))
            ankle=smooth(max(0,min(1,(z-4.6)/6)))
            # 胯部中央也连续混合左右权重，避免中线三角形反折。
            far=smooth(max(0,min(1,(v[0]+6)/12)))
            weights={'body':pelvis}
            for side,share in [('near',1-far),('far',far)]:
                weights.update({f'thigh_{side}':share*(1-pelvis)*knee*ankle,f'shin_{side}':share*(1-pelvis)*(1-knee)*ankle,f'foot_{side}':share*(1-pelvis)*(1-ankle)})
            for n,w in weights.items():
                if w>0: groups[n].add([i],w,'REPLACE')
    else:
        obj.vertex_groups.new(name=spec['bone']).add(list(range(len(vertices))),1,'REPLACE')
    mod=obj.modifiers.new('骨骼变形','ARMATURE'); mod.object=rig; mod.use_deform_preserve_volume=True
    obj['source_rect']=spec['rect']; obj['source_atlas']=spec.get('atlas','parts_atlas.png')
    return obj


def apply_pose(rig, data, held, phase, frame):
    rig['held'] = float(held)
    rig.keyframe_insert(data_path='["held"]', frame=frame)
    body=rig.pose.bones['body']; body.location.y=data['height']-HIP
    body.keyframe_insert('location',frame=frame)
    for side,hip_x,foot in zip(['near','far'],HIP_X,data['feet']):
        dx=foot[0]-hip_x; down=data['height']-foot[1]
        length=LEG_LENGTH; d=math.hypot(dx,down)
        if d>2*length+1e-6: raise ValueError(f'脚目标超出骨长: {side} {d}')
        angle=math.atan2(dx,down); bend=math.acos(min(.99999,d/(2*length)))
        upper=angle+bend; lower=angle-bend
        for bone_name, value in [(f'thigh_{side}',upper),(f'shin_{side}',lower-upper),(f'foot_{side}',foot[2]-lower)]:
            bone=rig.pose.bones[bone_name]; bone.rotation_euler.z=value; bone.keyframe_insert('rotation_euler',frame=frame)
    for name, angle in [('arm_near',-6*data['swing']),('arm_far',6*data['swing']),('hold_arm',.5*math.sin(phase*math.tau)),('tail',1.2*math.sin((phase-.12)*math.tau)),('head',.15*math.sin(phase*math.tau))]:
        bone=rig.pose.bones[name]; bone.rotation_euler.z=math.radians(angle); bone.keyframe_insert('rotation_euler',frame=frame)


def setup_scene():
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene
    scene.render.engine='CYCLES'; scene.cycles.samples=32
    scene.cycles.seed=0; scene.cycles.use_animated_seed=False
    scene.cycles.use_denoising=False
    scene.cycles.max_bounces=1; scene.cycles.transparent_max_bounces=16
    scene.render.resolution_x=CELL[0]; scene.render.resolution_y=CELL[1]; scene.render.resolution_percentage=100
    scene.render.fps=FPS; scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'; scene.render.image_settings.color_depth='8'
    scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
    scene.world.color=(0,0,0)
    camera_data=bpy.data.cameras.new('正交二维相机'); camera=bpy.data.objects.new('Camera',camera_data); scene.collection.objects.link(camera)
    center_z=(ORIGIN[1]-CELL[1]/2)/SCALE
    camera.location=(0,-100,center_z); camera.rotation_euler=(math.pi/2,0,0); camera_data.type='ORTHO'; camera_data.ortho_scale=CELL[1]/SCALE
    scene.camera=camera
    return scene


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--preview',action='store_true'); parser.add_argument('--no-render',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    SOURCE.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
    scene=setup_scene(); rig=build_rig()
    image=bpy.data.images.load(str(SOURCE/'parts_atlas.png')); image.pack()
    mat=make_material(image)
    core=bpy.data.images.load(str(SOURCE/'body_core_v2.png')); core.pack()
    core_mat=make_material(core)
    parts={name:make_part(name,spec,rig,core_mat if name=='torso' else mat) for name,spec in PARTS.items()}
    for name in ['near_arm', 'hold_arm', 'glass']:
        for prop in ['hide_render','hide_viewport']:
            driver=parts[name].driver_add(prop).driver
            variable=driver.variables.new(); variable.name='holding'; variable.type='SINGLE_PROP'
            variable.targets[0].id=rig; variable.targets[0].data_path='["held"]'
            driver.expression='holding > 0.5' if name=='near_arm' else 'holding < 0.5'
    manifest={'blender':bpy.app.version_string,'fps':FPS,'cell':CELL,'origin':ORIGIN,'scale':SCALE,'stride':STRIDE,'speed':SPEED,'clips':{},'parts':PARTS}
    cursor=1
    for held in [False,True]:
        for kind,count in [('idle',30),('start',21),('walk',30),('stop',27)]:
            key=kind+('_cup' if held else '')
            duration=count/FPS if kind in ('idle','walk') else (count-1)/FPS
            action=bpy.data.actions.new(key); action.use_fake_user=True
            rig.animation_data_create(); rig.animation_data.action=action
            frames=[]
            for index in range(count+int(kind in ('idle','walk'))):
                t=index/count if kind in ('idle','walk') else index/(count-1)
                pose=pose_data(kind,t)
                apply_pose(rig,pose,held,t,index+1)
                if index<count: frames.append({'root_x':pose['root'],'feet':[list(f) for f in pose['feet']], 'height':pose['height']})
            for obj,visible in [(parts['near_arm'],not held),(parts['hold_arm'],held),(parts['glass'],held)]:
                obj.hide_render=not visible
            clip={'count':count,'duration':duration,'loop':kind in ('idle','walk'),'held':held,'frames':frames,'root_end':pose_data(kind,1)['root'],'action':key}
            manifest['clips'][key]=clip
            scene.frame_start=1; scene.frame_end=count
            if not args.no_render:
                indices=[0,count//4,count//2,3*count//4] if args.preview and kind=='walk' else ([0] if args.preview else range(count))
                for i in indices:
                    scene.frame_set(i+1)
                    scene.render.filepath=str(OUT/f'{key}_{i:03d}.png')
                    bpy.ops.render.render(write_still=True)
            cursor+=count
    # 工程默认打开持杯行走；其他动作保存在 Actions 中，便于关键帧继续调整。
    rig.animation_data.action=bpy.data.actions['walk_cup']; scene.frame_start=1; scene.frame_end=30; scene.frame_set(1)
    for obj,visible in [(parts['near_arm'],False),(parts['hold_arm'],True),(parts['glass'],True)]: obj.hide_render=not visible; obj.hide_viewport=not visible
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'manager_rig.blend'))
    (SOURCE/'animation_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('MANAGER_BUILD_OK',json.dumps({'version':bpy.app.version_string,'clips':len(manifest['clips']),'preview':args.preview}))


if __name__=='__main__': main()
