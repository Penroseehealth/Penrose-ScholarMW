"""Bake three.js Xbot 'walk'/'idle' clips onto the Ready Player Me teacher rig.

Both rigs share Mixamo topology (67 joints) but their rest poses differ (Xbot is
a T-pose, the RPM avatar an A-pose) and their bone-local axes differ badly (e.g.
RightUpLeg rest differs ~176 deg), so neither a naive local copy nor an absolute
world-orientation copy works. Retarget with the rest-offset formula in WORLD
space instead (absolute copy inverts the legs; rest-delta keeps the teacher's
own upright frame):

    delta_b(t) = Wx_b(t) * inv(Wx_rest_b)          # Xbot world-space delta
    Wr_b(t)    = delta_b(t) * Wr_rest_b            # same delta on the teacher
    Lr_b(t)    = inv(Wr_parent(t)) * Wr_b(t)       # solve local (depth order)

Only orientations matter for the FK. Output: compact JSON of local quaternions
per bone per frame. The runtime plays it with AnimationMixer; ground bob is
added procedurally. Also prints an approximate FK check (hip-relative foot/hand
positions) for Xbot vs the retargeted teacher, as an offline sanity test.

Usage: python build_teacher_anim.py <Xbot.glb> <teacher.glb> <out.json>
"""
import sys, json, struct, math, os

PREFIX = "mixamorig:"

def load_glb(path):
    data = open(path,'rb').read()
    off, js, bc = 12, None, None
    while off < len(data):
        clen, ctype = struct.unpack_from('<II', data, off); off += 8
        chunk = data[off:off+clen]; off += clen
        if ctype == 0x4E4F534A: js = json.loads(chunk.decode('utf-8'))
        elif ctype == 0x004E4942: bc = chunk
    return js, bc

CT = {5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
NC = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def read_acc(g, b, i):
    a = g['accessors'][i]; bv = g['bufferViews'][a['bufferView']]
    off = bv.get('byteOffset',0) + a.get('byteOffset',0)
    fmt, sz = CT[a['componentType']]; n = NC[a['type']]
    stride = bv.get('byteStride') or (sz*n)
    out = []
    for k in range(a['count']):
        v = struct.unpack_from('<'+fmt*n, b, off+k*stride)
        out.append(v if n > 1 else v[0])
    return out

def qmul(a,b):
    ax,ay,az,aw=a; bx,by,bz,bw=b
    return [aw*bx+ax*bw+ay*bz-az*by, aw*by-ax*bz+ay*bw+az*bx,
            aw*bz+ax*by-ay*bx+az*bw, aw*bw-ax*bx-ay*by-az*bz]
def qinv(a):
    x,y,z,w=a; n=x*x+y*y+z*z+w*w or 1.0
    return [-x/n,-y/n,-z/n,w/n]
def qnorm(a):
    x,y,z,w=a; n=math.sqrt(x*x+y*y+z*z+w*w) or 1.0
    return [x/n,y/n,z/n,w/n]
def qrot(q,v):
    x,y,z,w=q; vx,vy,vz=v
    # q * (v,0) * q^-1
    tx=2*(y*vz-z*vy); ty=2*(z*vx-x*vz); tz=2*(x*vy-y*vx)
    return [vx+w*tx+(y*tz-z*ty), vy+w*ty+(z*tx-x*tz), vz+w*tz+(x*ty-y*tx)]

def node_q(node):
    if 'rotation' in node: return qnorm(node['rotation'])
    if 'matrix' in node:
        m=node['matrix']; tr=m[0]+m[5]+m[10]
        if tr>0:
            s=math.sqrt(tr+1)*2; w=.25*s; x=(m[9]-m[6])/s; y=(m[2]-m[8])/s; z=(m[4]-m[1])/s
        elif m[0]>m[5] and m[0]>m[10]:
            s=math.sqrt(1+m[0]-m[5]-m[10])*2; w=(m[9]-m[6])/s; x=.25*s; y=(m[1]+m[4])/s; z=(m[2]+m[8])/s
        elif m[5]>m[10]:
            s=math.sqrt(1+m[5]-m[0]-m[10])*2; w=(m[2]-m[8])/s; x=(m[1]+m[4])/s; y=.25*s; z=(m[6]+m[9])/s
        else:
            s=math.sqrt(1+m[10]-m[0]-m[5])*2; w=(m[4]-m[1])/s; x=(m[2]+m[8])/s; y=(m[6]+m[9])/s; z=.25*s
        return qnorm([x,y,z,w])
    return [0,0,0,1]

def node_t(node):
    if 'translation' in node: return list(node['translation'])
    if 'matrix' in node: return [node['matrix'][12],node['matrix'][13],node['matrix'][14]]
    return [0,0,0]

def build_index(g):
    nodes=g['nodes']; n=len(nodes)
    parent=[-1]*n
    for i,nd in enumerate(nodes):
        for c in nd.get('children',[]): parent[c]=i
    names={nd.get('name'):i for i,nd in enumerate(nodes)}
    depth=[0]*n
    for i in range(n):
        d=0; j=i
        while parent[j]!=-1: d+=1; j=parent[j]
        depth[i]=d
    return parent,names,depth

def fk_world(parent, order, locq, locp):
    """Returns (worldQuat, worldPos) lists. order must be topological (by depth)."""
    Wq=[None]*len(parent); Wp=[None]*len(parent)
    for i in order:
        q=locq[i]; p=locp[i]
        if parent[i]==-1:
            Wq[i]=q; Wp[i]=list(p)
        else:
            Wq[i]=qmul(Wq[parent[i]], q)
            off=qrot(Wq[parent[i]], p)
            Wp[i]=[Wp[parent[i]][k]+off[k] for k in range(3)]
    return Wq, Wp

def main():
    xbot, teacher, out = sys.argv[1], sys.argv[2], sys.argv[3]
    gx,bx=load_glb(xbot); gt,bt=load_glb(teacher)
    px,nx,dx=build_index(gx); pr,nr,dr=build_index(gt)
    rqx=[node_q(n) for n in gx['nodes']]; rqr=[node_q(n) for n in gt['nodes']]
    tpx=[node_t(n) for n in gx['nodes']]; tpr=[node_t(n) for n in gt['nodes']]
    orderx=sorted(range(len(gx['nodes'])), key=lambda k: dx[k])
    orderr=sorted(range(len(gt['nodes'])), key=lambda k: dr[k])

    joints=[gt['nodes'][j].get('name') for s in gt.get('skins',[]) for j in s['joints']]
    missing=[j for j in joints if j not in nr or (PREFIX+j) not in nx]
    print("joints:",len(joints),"missing:",missing)

    Wxr, _ = fk_world(px, orderx, rqx, tpx)   # xbot rest world quats
    Wrr, _ = fk_world(pr, orderr, rqr, tpr)   # teacher rest world quats

    clips={}
    for anim in gx.get('animations',[]):
        nm=anim.get('name')
        if nm not in ('walk','idle'): continue
        times=None; local={}
        for ch in anim['channels']:
            if ch['target']['path']!='rotation': continue
            ni=ch['target']['node']; s=anim['samplers'][ch['sampler']]
            if times is None: times=[round(v,5) for v in read_acc(gx,bx,s['input'])]
            local[ni]=[qnorm(q) for q in read_acc(gx,bx,s['output'])]
        F=len(times)
        # xbot animated world quats per node (lists per frame; parents shared)
        Wxt=[None]*len(gx['nodes'])
        for i in orderx:
            L=local.get(i)
            if L is None:
                if px[i]==-1: Wxt[i]=[Wxr[i]]*F
                else: Wxt[i]=Wxt[px[i]]  # inherit parent's animated world (share list)
            else:
                par=Wxt[px[i]] if px[i]!=-1 else [[0,0,0,1]]*F
                Wxt[i]=[qmul(par[f], L[f]) for f in range(F)]
        # rest-offset retarget: apply Xbot's *world-space delta* (animation minus
        # its own rest) to the teacher's rest orientation. The two rigs have
        # different rest poses (Xbot T-pose, RPM A-pose) and different bone-local
        # axis conventions, so a raw absolute copy inverts the legs; using the
        # delta keeps the teacher's own upright rest frame intact.
        Wrt={}
        for jn in joints:
            xi=nx[PREFIX+jn]
            drest=qinv(Wxr[xi])
            Wrt[jn]=[qmul(Wxt[xi][f], drest) for f in range(F)]
        # apply the delta to the teacher's rest world orientation
        for jn in joints:
            ti=nr[jn]
            Wrt[jn]=[qmul(Wrt[jn][f], Wrr[ti]) for f in range(F)]
        # parent world for teacher: joints override; non-joints stay at rest
        Wrt_node={nr[jn]:Wrt[jn] for jn in joints}
        loc={}
        for jn in sorted(joints, key=lambda j: dr[nr[j]]):
            ti=nr[jn]; pi=pr[ti]
            if pi==-1: base=[[0,0,0,1]]*F
            else: base=Wrt_node.get(pi) or [Wrr[pi]]*F
            loc[jn]=[qmul(qinv(base[f]), Wrt[jn][f]) for f in range(F)]
        tracks=[]
        for jn in joints:
            v=[]
            for q in loc[jn]: v.extend(round(c,5) for c in q)
            tracks.append({'bone':jn,'values':v})
        clips[nm]={'duration':times[-1],'times':times,'tracks':tracks}
        print("clip %-5s %d tracks %d frames %.3fs"%(nm,len(tracks),F,times[-1]))

        # --- offline sanity: hip-relative foot/hand positions, Xbot vs teacher
        f=max(range(F), key=lambda k: abs(loc['LeftUpLeg'][k][0]))
        lqx=[local[i][f] if i in local else rqx[i] for i in range(len(gx['nodes']))]
        _,Wpx=fk_world(px, orderx, lqx, tpx)
        hx=Wpx[nx[PREFIX+'Hips']]
        relx=lambda n:[round(Wpx[nx[PREFIX+n]][k]-hx[k],3) for k in range(3)]
        qmap={nr[jn]:loc[jn][f] for jn in joints}
        lq2=[qmap.get(i,rqr[i]) for i in range(len(gt['nodes']))]
        _,Wpr=fk_world(pr, orderr, lq2, tpr)
        hr=Wpr[nr['Hips']]
        relr=lambda n:[round(Wpr[nr[n]][k]-hr[k],3) for k in range(3)]
        print("   frame %d  XBOT LFoot%-22s RFoot%-22s LHand%s"%(f,relx('LeftFoot'),relx('RightFoot'),relx('LeftHand')))
        print("              TEAC LFoot%-22s RFoot%-22s LHand%s"%(relr('LeftFoot'),relr('RightFoot'),relr('LeftHand')))

    json.dump({'source':'three.js r172 Xbot.glb (Mixamo)','retarget':'world-delta FK','up':'Y','clips':clips},
              open(out,'w'), separators=(',',':'))
    print("wrote %s (%d bytes)"%(out, os.path.getsize(out)))

if __name__=='__main__':
    main()
