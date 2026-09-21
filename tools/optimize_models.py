#!/usr/bin/env python3
"""Bake static glTF parts by material, retaining separate animated bike wheels.

Authoring tool only: requires numpy. The finished GLBs are shipped with the game.
"""
from pathlib import Path
import copy
import json
import struct
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PAINT = {'RiderTorso','RiderJersey','HelmetShell','RearFender','FrontFender',
         'RightShroud','LeftShroud','RiderLUpperArm','RiderRUpperArm',
         'RiderLShin','RiderRShin','RiderLGlove','RiderRGlove','V4_ChestCenter',
         'V4_HelmetPeak','V4_HandGuard_1','V4_HandGuard_-1',
         'V4_RadiatorGuard_R','V4_RadiatorGuard_L'}
WHEEL = ('Tire','Rim','Hub','BrakeDisc','Spoke','Knob')
DT = {5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
SIZES = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def optimize(src, dst, bike=False):
    data = src.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+length])
    off = 20+length
    blen, kind = struct.unpack_from('<II', data, off)
    binary = data[off+8:off+8+blen]
    def read(idx):
        a = doc['accessors'][idx]; v = doc['bufferViews'][a['bufferView']]
        dtype = np.dtype(DT[a['componentType']]); size = SIZES[a['type']]
        start = v.get('byteOffset',0)+a.get('byteOffset',0)
        arr = np.ndarray((a['count'], size), dtype=dtype, buffer=binary,
                         offset=start, strides=(v.get('byteStride',size*dtype.itemsize),dtype.itemsize)).copy()
        if a.get('normalized') and dtype.kind in 'iu':
            arr = arr.astype(np.float32)/np.iinfo(dtype).max
        return arr
    def transform(node):
        if 'matrix' in node: return np.array(node['matrix']).reshape(4,4).T
        x,y,z,w = node.get('rotation',[0,0,0,1])
        m = np.eye(4)
        m[:3,:3] = np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                             [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                             [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]) @ np.diag(node.get('scale',[1,1,1]))
        m[:3,3] = node.get('translation',[0,0,0])
        return m
    groups = {}
    def walk(idx, parent):
        node = doc['nodes'][idx]; world = parent @ transform(node)
        name = node.get('name','')
        category = 'StaticGeometry'
        if bike and name in PAINT: category = 'RiderJersey'
        for side in ['Rear','Front']:
            if bike and any(name.startswith(side+p) for p in WHEEL): category = side+'TireMerged'
        if 'mesh' in node:
            for p in doc['meshes'][node['mesh']]['primitives']:
                assert p.get('mode',4)==4 and 'targets' not in p
                attrs = {k:read(v) for k,v in p['attributes'].items()}
                points = attrs['POSITION']
                attrs['POSITION'] = (np.c_[points,np.ones(len(points))] @ world.T)[:,:3]
                faces = read(p['indices']).reshape(-1,3) if 'indices' in p else np.arange(len(points)).reshape(-1,3)
                v = attrs['POSITION'][faces]
                faces = faces[np.linalg.norm(np.cross(v[:,1]-v[:,0],v[:,2]-v[:,0]),axis=1)>1e-10]
                if np.linalg.det(world[:3,:3])<0: faces = faces[:,[0,2,1]]
                if 'NORMAL' in attrs:
                    normals=attrs['NORMAL'] @ np.linalg.inv(world[:3,:3])
                    attrs['NORMAL']=normals/np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
                if 'TANGENT' in attrs:
                    t=attrs['TANGENT'][:,:3] @ world[:3,:3].T
                    attrs['TANGENT'][:,:3]=t/np.maximum(np.linalg.norm(t,axis=1,keepdims=True),1e-12)
                material=p.get('material',0)
                if category=='RiderJersey': material=next((i for i,m in enumerate(doc['materials']) if m.get('name')=='orange'),material)
                groups.setdefault((category,material,tuple(sorted(attrs))),[]).append((attrs,faces))
        for child in node.get('children',[]): walk(child,world)
    for n in doc['scenes'][doc.get('scene',0)]['nodes']: walk(n,np.eye(4))
    out={'asset':{'version':'2.0','generator':'DIRTLINE material batch baker'},'scene':0,
         'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'bufferViews':[],'accessors':[]}
    buf=bytearray()
    def view(raw, target=None):
        while len(buf)%4: buf.append(0)
        offset=len(buf);buf.extend(raw)
        result={'buffer':0,'byteOffset':offset,'byteLength':len(raw)}
        if target: result['target']=target
        out['bufferViews'].append(result)
        return len(out['bufferViews'])-1
    for key in ['materials','textures','samplers','images','extensionsUsed','extensionsRequired']:
        if key in doc: out[key]=copy.deepcopy(doc[key])
    for image in out.get('images',[]):
        if 'bufferView' in image:
            v=doc['bufferViews'][image['bufferView']];a=v.get('byteOffset',0)
            image['bufferView']=view(binary[a:a+v['byteLength']])
    def accessor(arr, index=False):
        arr=np.asarray(arr,dtype='<u4' if index else '<f4')
        width=1 if index else arr.shape[1]
        ac={'bufferView':view(arr.tobytes(),34963 if index else 34962),
            'componentType':5125 if index else 5126,'count':len(arr),
            'type':{1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4'}[width]}
        if not index and width==3:
            ac['min']=arr.min(axis=0).tolist();ac['max']=arr.max(axis=0).tolist()
        out['accessors'].append(ac);return len(out['accessors'])-1
    by_category={}
    for (category,material,keys),parts in groups.items():
        combined={k:[] for k in keys};faces=[];offset=0
        for attrs,face in parts:
            for k in keys: combined[k].append(attrs[k])
            faces.append(face+offset);offset+=len(attrs['POSITION'])
        primitive={'attributes':{k:accessor(np.concatenate(combined[k])) for k in keys},
                   'indices':accessor(np.concatenate(faces).reshape(-1),True),'material':material,'mode':4}
        by_category.setdefault(category,[]).append(primitive)
    for category,primitives in by_category.items():
        idx=len(out['meshes']);out['meshes'].append({'name':category,'primitives':primitives})
        out['scenes'][0]['nodes'].append(len(out['nodes']))
        out['nodes'].append({'name':category,'mesh':idx})
    while len(buf)%4: buf.append(0)
    out['buffers']=[{'byteLength':len(buf)}]
    text=json.dumps(out,separators=(',',':')).encode()
    text+=b' '*((-len(text))%4)
    total=12+8+len(text)+8+len(buf)
    dst.write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(buf),0x004e4942)+buf)
    print(f'{src.name}: {len(doc["meshes"])} meshes -> {len(out["meshes"])} meshes / {len(groups)} material batches')

if __name__=='__main__':
    optimize(ROOT/'models/dirt_bike_rider_arcade_v4.glb',ROOT/'models/dirt_bike_rider_arcade_v5.glb',True)
    for name in ['background_pine_ridge_mp','background_red_mesa_mp','background_quarry_mp','pine_tree_ps2','wood_fence_6m','grandstand','tire_barrier','paddock_tent']:
        optimize(ROOT/f'models/props/{name}.glb',ROOT/f'models/props/{name}_batched.glb')
