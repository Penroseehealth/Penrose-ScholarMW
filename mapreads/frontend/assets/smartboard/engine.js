// Map Reading engine: pure JS, no DOM. Runs in browser/WebView and Node.
(function(root,f){if(typeof module==='object')module.exports=f();else root.MapEngine=f();})(this,function(){
const rng=s=>()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296};
// Grid: h[j*N+i], i=east, j=north, ground coords x=i*cell, y=j*cell (metres)
const ss=(a,b,x)=>{const t=Math.min(1,Math.max(0,(x-a)/(b-a)));return t*t*(3-2*t)},uprof=q=>1-ss(.03,.12,Math.abs(q)); // U profile: flat floor, steep walls
function noiseField(r,cells){const n=cells+1,data=Float32Array.from({length:n*n},r);
 return(x,y)=>{const px=Math.max(0,Math.min(1,x))*cells,py=Math.max(0,Math.min(1,y))*cells,i=Math.min(Math.floor(px),cells-1),j=Math.min(Math.floor(py),cells-1),u=ss(0,1,px-i),v=ss(0,1,py-j),a=data[j*n+i],b=data[j*n+i+1],c=data[(j+1)*n+i],d=data[(j+1)*n+i+1];
  return(a+(b-a)*u)*(1-v)+(c+(d-c)*u)*v}}
function fractal(fields,x,y){let value=0,weight=0;for(let i=0;i<fields.length;i++){const w=1/(1<<i);value+=fields[i](x,y)*w;weight+=w}return value/weight}
function generate(c){
 c=Object.assign({seed:1,N:121,cell:50,hills:3,ridge:true,min:1000,max:1500,complexity:2},c);
 c.N=Math.max(33,Math.min(257,Math.round(c.N)));c.complexity=Math.max(1,Math.min(3,Math.round(c.complexity)));
 const r=rng(c.seed),N=c.N,h=new Float64Array(N*N),macro=[noiseField(r,2),noiseField(r,4),noiseField(r,8),noiseField(r,16)],fine=[...macro,noiseField(r,32),noiseField(r,64)],warpX=noiseField(r,4),warpY=noiseField(r,4),ridgeNoise=[noiseField(r,3),noiseField(r,7),noiseField(r,15)],ranges=[];
 for(let k=0;k<c.hills;k++){const t=r()*Math.PI,cx=.2+.6*r(),cy=.2+.6*r();ranges.push({cx,cy,t,len:.42+.42*r(),width:.055+.075*r(),amp:.25+.28*r(),phase:r()*Math.PI*2})}
 const E={t:r()*Math.PI,offset:(r()-.5)*.12},vt=r()*Math.PI,V={o:.5*(Math.cos(vt)-Math.sin(vt))+(r()-.5)*.08,t:vt,phase:r()*6};let lo=1e9,hi=-1e9;
 for(let j=0;j<N;j++)for(let i=0;i<N;i++){const u=i/(N-1),v=j/(N-1);
  const wx=u+(warpX(u,v)-.5)*.1,wy=v+(warpY(u,v)-.5)*.1;
  const broad=fractal(macro,wx,wy),detail=fractal(c.complexity===1?macro:c.complexity===2?fine.slice(0,5):fine,wx,wy);
  let z=.28-.12*u-.08*v+(broad-.5)*.42+(detail-.5)*(.1+.08*c.complexity);
  for(const f of ranges){const dx=wx-f.cx,dy=wy-f.cy,p=dx*Math.cos(f.t)+dy*Math.sin(f.t),q=-dx*Math.sin(f.t)+dy*Math.cos(f.t),
    bent=q+.028*Math.sin(p*19+f.phase)+.012*Math.sin(p*43-f.phase),extent=Math.abs(p)/(f.len*.5),mask=1-ss(.72,1.12,Math.hypot(bent/f.width,extent));
   if(mask>0){const texture=fractal(ridgeNoise,wx*1.35,wy*1.35),ridge=1-Math.abs(2*fractal(ridgeNoise.slice(1),wx*1.8,wy*1.8)-1);z+=f.amp*mask*(.62+.58*texture)+.1*mask*Math.pow(ridge,1.6)}}
  if(c.ridge&&!ranges.length){const ridge=1-Math.abs(2*detail-1);z+=.28*Math.pow(ridge,1.8)}
  if(c.terrain==='escarp'||c.terrain==='mixed'){const d=(wx-.5)*Math.cos(E.t)+(wy-.5)*Math.sin(E.t)+E.offset+.024*Math.sin(wx*17);z+=.95*ss(-.03,.03,d)+.04*Math.sin(d*28)*ss(-.06,.06,d)}
  if(c.terrain==='uvalley'||c.terrain==='mixed'){const p=wx*Math.cos(V.t)+wy*Math.sin(V.t),q=-wx*Math.sin(V.t)+wy*Math.cos(V.t)-V.o+.035*Math.sin(p*15+V.phase);z-=.9*uprof(q)}
  h[j*N+i]=z;lo=Math.min(lo,z);hi=Math.max(hi,z)}
 for(let k=0;k<h.length;k++)h[k]=c.min+(h[k]-lo)/(hi-lo)*(c.max-c.min);
 const g={N,cell:c.cell,h,cfg:c,size:(N-1)*c.cell,lakes:[]};
 const candidates=[];
 for(let j=4;j<N-4;j++)for(let i=4;i<N-4;i++){const index=j*N+i,z=h[index];let local=true,ring=Infinity;
  for(let dj=-1;dj<=1&&local;dj++)for(let di=-1;di<=1;di++)if((di||dj)&&h[(j+dj)*N+i+di]<z){local=false;break}
  if(!local)continue;
  for(let dj=-4;dj<=4;dj++)for(let di=-4;di<=4;di++){const distance=Math.hypot(di,dj);if(distance>=2.2&&distance<=4.2)ring=Math.min(ring,h[(j+dj)*N+i+di])}
  const prominence=ring-z;if(prominence>=8&&z<c.min+(c.max-c.min)*.82)candidates.push({i,j,z,ring,prominence})}
 candidates.sort((a,b)=>(a.z-a.prominence*.3)-(b.z-b.prominence*.3));
 for(const candidate of candidates){if(g.lakes.length>=2)break;const x=candidate.i/(N-1)*g.size,y=candidate.j/(N-1)*g.size;
  if(g.lakes.some(l=>Math.hypot(l.x-x,l.y-y)<g.size*.18))continue;
  const rx=g.cell*(2.3+.8*r()),ry=rx*(.7+.6*r()),angle=r()*Math.PI,phase=r()*Math.PI*2,level=Math.min(candidate.z+Math.min(10,candidate.prominence*.55),candidate.ring-1);
  const lake={x,y,rx,ry,angle,level,baseline:candidate.z,phase,points:[]};
  for(let q=0;q<48;q++){const t=q/48*Math.PI*2,edge=1+.09*Math.sin(t*3+phase)+.04*Math.sin(t*7-phase*1.7),dx=Math.cos(t)*rx*edge,dy=Math.sin(t)*ry*edge;
   lake.points.push({x:x+dx*Math.cos(angle)-dy*Math.sin(angle),y:y+dx*Math.sin(angle)+dy*Math.cos(angle)})}
  g.lakes.push(lake)}
 for(let j=0;j<N;j++)for(let i=0;i<N;i++){const x=i/(N-1)*g.size,y=j/(N-1)*g.size,k=j*N+i;
  for(const lake of g.lakes){const dx=x-lake.x,dy=y-lake.y,p=dx*Math.cos(lake.angle)+dy*Math.sin(lake.angle),q=-dx*Math.sin(lake.angle)+dy*Math.cos(lake.angle),r2=Math.hypot(p/lake.rx,q/lake.ry),shore=1+.07*Math.sin(Math.atan2(q/lake.ry,p/lake.rx)*3+lake.phase);
   if(r2<shore){const depth=1+(lake.level-lake.baseline+1)*Math.pow(1-Math.min(1,r2/shore),1.7);h[k]=Math.max(c.min,Math.min(h[k],lake.level-depth))}}}
 g.flow=drainage(g);
 const channel=new Float32Array(N*N);
 for(let k=0;k<channel.length;k++)if(g.acc[k]>=24)channel[k]=Math.min(1,(Math.log2(g.acc[k])-4.5)/4);
 for(let pass=0;pass<2;pass++){const smooth=new Float32Array(channel.length);for(let j=1;j<N-1;j++)for(let i=1;i<N-1;i++){const k=j*N+i;smooth[k]=(channel[k]*4+channel[k-1]+channel[k+1]+channel[k-N]+channel[k+N])/8}channel.set(smooth)}
 for(let k=0;k<h.length;k++)h[k]=Math.max(c.min,h[k]-channel[k]*Math.min(7,(c.max-c.min)*.018));
 g.flow=drainage(g);return g}
// D8 drainage: flow[k]=index of lowest downhill neighbour or -1; acc=upstream cell count
function drainage(g){const{N,h}=g,flow=new Int32Array(N*N).fill(-1),acc=new Float64Array(N*N).fill(1);
 for(let j=0;j<N;j++)for(let i=0;i<N;i++){let best=0,bk=-1;
  for(let dj=-1;dj<=1;dj++)for(let di=-1;di<=1;di++){if(!di&&!dj)continue;const a=i+di,b=j+dj;if(a<0||b<0||a>=N||b>=N)continue;
   const s=(h[j*N+i]-h[b*N+a])/(di&&dj?Math.SQRT2:1);if(s>best){best=s;bk=b*N+a}}
  flow[j*N+i]=bk}
 const o=Array.from(h.keys()).sort((a,b)=>h[b]-h[a]);for(const k of o)if(flow[k]>=0)acc[flow[k]]+=acc[k];
 g.acc=acc;return flow}
function isWater(g,x,y){return(g.lakes||[]).some(l=>{const dx=x-l.x,dy=y-l.y,p=dx*Math.cos(l.angle)+dy*Math.sin(l.angle),q=-dx*Math.sin(l.angle)+dy*Math.cos(l.angle),a=Math.atan2(q/l.ry,p/l.rx),shore=1+.07*Math.sin(a*3+l.phase);return Math.hypot(p/l.rx,q/l.ry)<shore})}
function elev(g,x,y){const{N,cell,h}=g;let fx=Math.min(Math.max(x/cell,0),N-1),fy=Math.min(Math.max(y/cell,0),N-1);
 const i=Math.min(Math.floor(fx),N-2),j=Math.min(Math.floor(fy),N-2),tx=fx-i,ty=fy-j,a=h[j*N+i],b=h[j*N+i+1],c=h[(j+1)*N+i],d=h[(j+1)*N+i+1];
 return a*(1-tx)*(1-ty)+b*tx*(1-ty)+c*(1-tx)*ty+d*tx*ty}
// Marching squares. Returns segments [x1,y1,x2,y2] in metres.
function contour(g,L){const{N,cell,h}=g,S=[];
 for(let j=0;j<N-1;j++)for(let i=0;i<N-1;i++){
  const v=[h[j*N+i],h[j*N+i+1],h[(j+1)*N+i+1],h[(j+1)*N+i]],X=[i,i+1,i+1,i],Y=[j,j,j+1,j+1],E=[];
  for(let e=0;e<4;e++){const m=(e+1)%4,a=v[e],b=v[m];if((a<L)!==(b<L)){const t=(L-a)/(b-a);E[e]=[(X[e]+t*(X[m]-X[e]))*cell,(Y[e]+t*(Y[m]-Y[e]))*cell]}}
  const k=E.map((p,e)=>p?e:-1).filter(e=>e>=0);
  if(k.length===2)S.push([...E[k[0]],...E[k[1]]]);
  else if(k.length===4){const ctr=(v[0]+v[1]+v[2]+v[3])/4;
   if((v[0]>=L)===(ctr>=L)){S.push([...E[0],...E[1]],[...E[2],...E[3]])}else S.push([...E[3],...E[0]],[...E[1],...E[2]])}}
 return S}
const levels=(g,iv)=>{let lo=Infinity,hi=-Infinity;for(const z of g.h){lo=Math.min(lo,z);hi=Math.max(hi,z)}const o=[];for(let L=Math.ceil(lo/iv)*iv;L<=hi;L+=iv)o.push(L);return o};
function peaks(g,n=4){const{N,h}=g,P=[];for(let j=1;j<N-1;j++)for(let i=1;i<N-1;i++){const z=h[j*N+i];let ok=true;
 for(let dj=-1;dj<=1&&ok;dj++)for(let di=-1;di<=1;di++)if((di||dj)&&h[(j+dj)*N+i+di]>=z){ok=false;break}
 if(ok)P.push({x:i*g.cell,y:j*g.cell,z})}return P.sort((a,b)=>b.z-a.z).slice(0,n)}
// ---- calculations ----
const num=(...a)=>a.forEach(v=>{if(typeof v!=='number'||!isFinite(v))throw new Error('Invalid numeric input')});
const groundFromMap=(mapCm,rf)=>{num(mapCm,rf);if(rf<=0)throw new Error('RF must be > 0');return mapCm*rf/100}; // metres
const mapFromGround=(m,rf)=>{num(m,rf);return m*100/rf}; // cm
const dist=(a,b)=>Math.hypot(b.x-a.x,b.y-a.y);
function gradient(vi,hd){num(vi,hd);if(hd<=0)throw new Error('Horizontal distance must be > 0');if(vi===0)return{ratio:'level',percent:0};
 return{ratio:'1:'+Math.round(hd/Math.abs(vi)),percent:+(Math.abs(vi)/hd*100).toFixed(2)}}
const bearing=(a,b)=>{const t=Math.atan2(b.x-a.x,b.y-a.y)*180/Math.PI;return +((t+360)%360).toFixed(1)};
const compass=b=>['N','NE','E','SE','S','SW','W','NW'][Math.round(b/45)%8];
function gridRef(x,y,e0,n0,digits=6){const E=e0+x,Nn=n0+y,d=digits/2,u=d===2?1000:100,m=d===2?100:1000,p=v=>String(Math.floor((v%100000)/u)).padStart(d,'0');
 return p(E)+p(Nn)}
function profile(g,a,b,n=100){const L=dist(a,b),P=[];for(let k=0;k<=n;k++){const t=k/n;P.push({d:t*L,z:elev(g,a.x+t*(b.x-a.x),a.y+t*(b.y-a.y))})}return P}
function intervisible(g,a,b,ha=1.7,hb=1.7,n=200){const za=elev(g,a.x,a.y)+ha,zb=elev(g,b.x,b.y)+hb;
 for(let k=1;k<n;k++){const t=k/n,x=a.x+t*(b.x-a.x),y=a.y+t*(b.y-a.y),zl=za+t*(zb-za),zt=elev(g,x,y);if(zt>zl)return{visible:false,blockedAt:{x,y,z:zt}}}
 return{visible:true}}
return{uprof,ss,generate,drainage,isWater,elev,contour,levels,peaks,groundFromMap,mapFromGround,dist,gradient,bearing,compass,gridRef,profile,intervisible}});
