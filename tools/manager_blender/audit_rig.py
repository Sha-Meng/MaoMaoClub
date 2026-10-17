"""对保存后的 Blender 工程重新求值，验证导出元数据与真实骨骼一致。"""
import json
import math
from pathlib import Path
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/source/manager_blender'
QA=ROOT/'production/qa/manager_blender'


def main():
    data=json.loads((SOURCE/'animation_manifest.json').read_text(encoding='utf-8'))
    rig=bpy.data.objects['ManagerRig']
    failures=[]; samples=0; max_target_error=0; max_support_drift=0; max_cup_error=0; max_length_error=0
    cup_bind=rig.data.bones['hold_arm'].matrix_local.inverted() @ rig.data.bones['glass'].matrix_local
    core=bpy.data.objects['torso']
    for side in ['near','far']:
        required={f'thigh_{side}',f'shin_{side}',f'foot_{side}'}
        if not required.issubset({g.name for g in bpy.data.objects[side+'_leg'].vertex_groups}):
            failures.append(f'{side}: 缺少腿部完整绑定')
    if 'attachment_fade' not in bpy.data.objects['near_leg'].data.color_attributes:
        failures.append('近腿缺少腹部内的根部融合权重')
    min_foot_spacing=float('inf'); max_foot_spacing=-float('inf'); max_pelvis_rotation=0.0
    crossings={}
    # 读取真正导出的连续身体网格，检查可见区域是否发生三角形/四边形反折。
    core_image=bpy.data.images['crossing_parts_final.png']
    pixels=np.asarray(core_image.pixels[:],dtype=np.float32).reshape(core_image.size[1],core_image.size[0],4)
    geometry={}
    for name in ['torso','near_leg','far_leg']:
        obj=bpy.data.objects[name]; visible_faces=[]
        for polygon in obj.data.polygons:
            uv=sum((obj.data.uv_layers.active.data[i].uv for i in polygon.loop_indices),start=obj.data.uv_layers.active.data[polygon.loop_indices[0]].uv*0)/len(polygon.loop_indices)
            x=min(core_image.size[0]-1,int(uv.x*core_image.size[0])); y=min(core_image.size[1]-1,int(uv.y*core_image.size[1]))
            if pixels[y,x,3]>.95: visible_faces.append(list(polygon.vertices))
        geometry[name]=(np.asarray(visible_faces),np.array([(v.co.x,v.co.z) for v in obj.data.vertices]))
    max_folded_faces=0; worst_fold=None
    for key,clip in data['clips'].items():
        rig.animation_data.action=bpy.data.actions[key]
        previous=None; foot_order=[]
        for index,target in enumerate(clip['frames']):
            bpy.context.scene.frame_set(index+1)
            bpy.context.view_layer.update()
            actual=[]
            for side in ['near','far']:
                foot=rig.pose.bones[f'foot_{side}']
                actual.append((float(foot.head.x),float(foot.head.z)))
                for part in ['thigh','shin','foot']:
                    name=f'{part}_{side}'
                    max_length_error=max(max_length_error,abs(rig.pose.bones[name].length-rig.data.bones[name].length))
            for side in range(2):
                err=math.dist(actual[side],target['feet'][side][:2])
                max_target_error=max(max_target_error,err)
                if previous and previous[1]['feet'][side][3] and target['feet'][side][3]:
                    drift=abs(actual[side][0]+target['root_x']-(previous[0][side][0]+previous[1]['root_x']))
                    max_support_drift=max(max_support_drift,drift)
            min_foot_spacing=min(min_foot_spacing,actual[1][0]-actual[0][0])
            max_foot_spacing=max(max_foot_spacing,actual[1][0]-actual[0][0])
            foot_order.append(actual[1][0]-actual[0][0])
            max_pelvis_rotation=max(max_pelvis_rotation,math.sqrt(sum(v*v for v in rig.pose.bones['body'].rotation_euler)))
            depths={}
            for name,(visible_faces,rest_coords) in geometry.items():
                evaluated=bpy.data.objects[name].evaluated_get(bpy.context.evaluated_depsgraph_get())
                mesh=evaluated.to_mesh()
                depths[name]=(min(v.co.y for v in mesh.vertices),max(v.co.y for v in mesh.vertices))
                coords=np.array([(v.co.x,v.co.z) for v in mesh.vertices])
                faces=coords[visible_faces]
                signed_area=np.sum(faces[:,:,0]*np.roll(faces[:,:,1],-1,axis=1)-faces[:,:,1]*np.roll(faces[:,:,0],-1,axis=1),axis=1)
                folded=int(np.count_nonzero(signed_area>=0))
                if folded>max_folded_faces:
                    max_folded_faces=folded
                    worst_fold={'clip':key,'frame':index,'mesh':name,'rest_centers':rest_coords[visible_faces[signed_area>=0]].mean(axis=1).tolist()}
                evaluated.to_mesh_clear()
            if depths['near_leg'][1]>=depths['torso'][0] or depths['torso'][1]>=depths['far_leg'][0]: failures.append(f'{key}/{index}: 近远腿层级错误')
            cup_relation=rig.pose.bones['hold_arm'].matrix.inverted() @ rig.pose.bones['glass'].matrix
            max_cup_error=max(max_cup_error,max(abs(cup_relation[r][c]-cup_bind[r][c]) for r in range(4) for c in range(4)))
            for part,visible in [('glass',clip['held']),('hold_arm',clip['held']),('near_arm',not clip['held'])]:
                if bpy.data.objects[part].hide_render == visible:
                    failures.append(f'{key}/{index}: {part} 可见性不符')
            previous=(actual,target); samples+=1
        if key.startswith('walk'):
            count=sum(a*b<0 for a,b in zip(foot_order,foot_order[1:]+foot_order[:1]))
            crossings[key]={'crossings':count,'min_far_minus_near':min(foot_order),'max_far_minus_near':max(foot_order)}
            if count!=2 or min(foot_order)>-2 or max(foot_order)<2: failures.append(f'{key}: 前后交替不完整 {crossings[key]}')
    for name,error in [('骨骼足端与导出目标',max_target_error),('支撑脚世界漂移',max_support_drift),('杯子相对持杯手变换',max_cup_error),('骨段长度变化',max_length_error)]:
        if error>.0001: failures.append(f'{name}: {error}')
    if max_pelvis_rotation>.0001: failures.append('骨盆不应扭转摆胯')
    if max_folded_faces: failures.append(f'可见身体网格反折: {max_folded_faces}')
    report={'blender':bpy.app.version_string,'samples':samples,'leg_root_blend':'attachment_fade','fixed_far_leg_layer':True,'crossing_cycles':crossings,'max_folded_visible_body_faces':max_folded_faces,'worst_fold':worst_fold,'signed_foot_spacing_range':[min_foot_spacing,max_foot_spacing],'max_pelvis_rotation':max_pelvis_rotation,'max_target_error':max_target_error,'max_support_drift':max_support_drift,'max_cup_attachment_error':max_cup_error,'max_bone_length_error':max_length_error,'failures':failures,'success':not failures}
    QA.mkdir(parents=True,exist_ok=True)
    (QA/'rig_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))
    if failures: raise RuntimeError('实际骨骼验证失败')


if __name__=='__main__': main()
