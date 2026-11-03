// Map features derived from the terrain grid: chained contours, land cover, settlements, roads, bridges.
(function(root,f){if(typeof module==='object')module.exports=f(require('./engine.js'));else root.Feat=f(root.MapEngine);})(this,function(M){
const BAN=['Lilongwe','Blantyre','Zomba','Mzuzu','Kasungu','Salima','Dedza','Ntcheu','Mangochi','Karonga','Nkhotakota','Mulanje','Thyolo','Chitipa','Rumphi','Dowa','Mchinji','Ntchisi','Balaka','Machinga','Chikwawa','Nsanje','Mwanza','Neno','Phalombe','Likoma','Chiradzulu','Livingstonia','Nkhatabay','Mponela','Liwonde','Monkey','Chilumba'],RIVER=60,rng=s=>()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296};
// Join marching-squares segments into polylines {pts:[[x,y]..],closed}
function chain(segs){const K=p=>Math.round(p[0]*1e3)+','+Math.round(p[1]*1e3),m=new Map(),used=new Uint8Array(segs.length);
 segs.forEach((s,i)=>{for(const k of[K([s[0],s[1]]),K([s[2],s[3]])]){if(!m.has(k))m.set(k,[]);m.get(k).push(i)}});
 const nxt=k=>{for(const i of m.get(k)||[])if(!used[i])return i;return-1},out=[];
 for(let i=0;i<segs.length;i++){if(used[i])continue;used[i]=1;const s=segs[i],pts=[[s[0],s[1]],[s[2],s[3]]];
  for(let pass=0;pass<2;pass++){for(;;){const e=pts[pts.length-1],j=nxt(K(e));if(j<0)break;used[j]=1;const t=segs[j];pts.push(K([t[0],t[1]])===K(e)?[t[2],t[3]]:[t[0],t[1]])}pts.reverse()}
  out.push({pts,closed:pts.length>3&&K(pts[0])===K(pts[pts.length-1])})}
 return out}
function slopeAt(g,i,j){const{N,h,cell}=g,a=h[j*N+Math.min(i+1,N-1)]-h[j*N+Math.max(i-1,0)],b=h[Math.min(j+1,N-1)*N+i]-h[Math.max(j-1,0)*N+i];return Math.hypot(a,b)/(2*cell)}
// lc codes: 0 none, 1 woodland, 2 cultivated, 3 wetland
function build(g,nSet=4){const N=g.N,r=rng(g.cfg.seed*7919+13),isR=k=>g.acc[k]>=RIVER,S=new Float32Array(N*N),near=new Uint8Array(N*N),lc=new Uint8Array(N*N);
 for(let j=0;j<N;j++)for(let i=0;i<N;i++)S[j*N+i]=slopeAt(g,i,j);
 for(let k=0;k<N*N;k++)if(isR(k)){const ci=k%N,cj=(k/N)|0;for(let b=-3;b<=3;b++)for(let a=-3;a<=3;a++){const i=ci+a,j=cj+b;if(i>=0&&j>=0&&i<N&&j<N)near[j*N+i]=1}}
 const p1=r()*6,p2=r()*6;
 for(let j=0;j<N;j++)for(let i=0;i<N;i++){const k=j*N+i,n=Math.sin(i*.13+p1)*Math.sin(j*.11+p2)+Math.sin(i*.05+p2)*Math.cos(j*.07+p1),s=S[k];
  lc[k]=near[k]&&s<.03?3:(s>.08||(n>.7&&s>.04))?1:(s<.06&&n<.2)?2:0}
 const c=[];for(let k=0;k<N*N;k++)if(S[k]<.05&&!isR(k)&&lc[k]!==3)c.push(k);
 for(let i=c.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[c[i],c[j]]=[c[j],c[i]]}
 const set=[];for(const k of c){if(set.length>=nSet)break;const x=(k%N)*g.cell,y=((k/N)|0)*g.cell;
  if(x<400||y<400||x>g.size-400||y>g.size-400||set.some(s=>Math.hypot(s.x-x,s.y-y)<900))continue;
  const b=[];for(let q=0;q<(set.length?7:14);q++)b.push({x:x+(r()-.5)*(set.length?240:400),y:y+(r()-.5)*(set.length?240:400)});set.push({x,y,k,b})}
 const heap=[],push=(c,k)=>{heap.push([c,k]);let i=heap.length-1;while(i>0){const p=(i-1)>>1;if(heap[p][0]<=heap[i][0])break;[heap[p],heap[i]]=[heap[i],heap[p]];i=p}},
 pop=()=>{const t=heap[0],l=heap.pop();if(heap.length){heap[0]=l;let i=0;for(;;){let m=i,a=2*i+1,b=a+1;if(a<heap.length&&heap[a][0]<heap[m][0])m=a;if(b<heap.length&&heap[b][0]<heap[m][0])m=b;if(m===i)break;[heap[m],heap[i]]=[heap[i],heap[m]];i=m}}return t};
 function route(a,b){const D=new Float64Array(N*N).fill(Infinity),P=new Int32Array(N*N).fill(-1);D[a]=0;heap.length=0;push(0,a);
  while(heap.length){const[d,k]=pop();if(d>D[k])continue;if(k===b)break;const ci=k%N,cj=(k/N)|0;
   for(let dj=-1;dj<=1;dj++)for(let di=-1;di<=1;di++){if(!di&&!dj)continue;const i=ci+di,j=cj+dj;if(i<0||j<0||i>=N||j>=N)continue;const n=j*N+i,
    w=(di&&dj?Math.SQRT2:1)*(1+25*S[n])+(lc[n]===3?15:0)+(isR(n)?6:0);if(d+w<D[n]){D[n]=d+w;P[n]=k;push(d+w,n)}}}
  const p=[];for(let k=b;k>=0;k=P[k])p.push(k);return p.reverse()}
 const roads=[],bridges=[],addBr=R=>{const{cells,pts}=R;for(let q=0;q<cells.length;){if(!isR(cells[q])){q++;continue}let e=q;while(e+1<cells.length&&isR(cells[e+1]))e++;const m=pts[(q+e)>>1];bridges.push({x:m.x,y:m.y,k:cells[(q+e)>>1]});q=e+1}};
 for(let i=1;i<set.length;i++){let bj=0,bd=1e18;for(let j=0;j<i;j++){const d=Math.hypot(set[i].x-set[j].x,set[i].y-set[j].y);if(d<bd){bd=d;bj=j}}
  const cells=route(set[bj].k,set[i].k),pts=cells.map(k=>({x:(k%N)*g.cell,y:((k/N)|0)*g.cell}));const R={type:roads.length?'track':'main',cells,pts};roads.push(R);addBr(R)}

 // guarantee a river crossing: route an extra track between two settlements via a river cell on the line joining them
 if(!bridges.length)out:for(let a=0;a<set.length;a++)for(let b=a+1;b<set.length;b++){let R=-1;for(let t=1;t<60;t++){const k=Math.round((set[a].y+(set[b].y-set[a].y)*t/60)/g.cell)*N+Math.round((set[a].x+(set[b].x-set[a].x)*t/60)/g.cell);if(isR(k)){R=k;break}}
  if(R<0)continue;const cells=route(set[a].k,R).concat(route(R,set[b].k).slice(1)),X={type:'track',cells,pts:cells.map(k=>({x:(k%N)*g.cell,y:((k/N)|0)*g.cell}))};roads.push(X);addBr(X);break out}
 // fictional names (syllable generator, real district/town names excluded)
 const r2=rng(g.cfg.seed*104729+7),C=['k','m','n','ch','t','s','b','l','p','z','mw','ng','kh','th'],used=new Set(BAN);
 set.forEach((s,i)=>{let n;do{n='';for(let q=0,m=2+(r2()*2|0);q<m;q++)n+=C[r2()*C.length|0]+'aeiou'[r2()*5|0];n=n[0].toUpperCase()+n.slice(1)}while(used.has(n));used.add(n);s.name=n;s.kind=i?'Village':'Trading centre'});
 const marks=[];M.peaks(g,5).forEach((p,i)=>marks.push({kind:i<2?'TP':'SH',x:p.x,y:p.y,z:Math.round(p.z)}));
 bridges.forEach(b=>marks.push({kind:'SH',x:b.x,y:b.y,z:Math.round(M.elev(g,b.x,b.y))}));
 if(roads[0])[.33,.66].forEach(q=>{const c=roads[0].cells[Math.floor(roads[0].cells.length*q)],x=(c%N)*g.cell,y=((c/N)|0)*g.cell;marks.push({kind:'BM',x,y,z:Math.round(M.elev(g,x,y)),k:c})});
 const markets=set.slice(0,1).map(s=>({x:s.x,y:s.y,name:s.name+' market'}));
 const schools=set.slice(1).map(s=>({x:s.b[0]?.x??s.x,y:s.b[0]?.y??s.y,name:'Primary school'}));
 const boreholes=set.slice(0,Math.min(3,set.length)).map(s=>{let best=s.k,score=Infinity,ci=s.k%N,cj=(s.k/N)|0;
  for(let dj=-10;dj<=10;dj++)for(let di=-10;di<=10;di++){const i=ci+di,j=cj+dj;if(i<1||j<1||i>=N-1||j>=N-1)continue;const k=j*N+i;if(isR(k)||lc[k]===3)continue;
   const d=Math.hypot(di,dj),cost=S[k]*500+d+ (lc[k]===1?8:0);if(cost<score){score=cost;best=k}}
  return{x:(best%N)*g.cell,y:((best/N)|0)*g.cell,name:'Borehole'}});
 // synthetic district boundary (not tied to real boundaries); shifted clear of settlements
 let y0=g.size*(.3+.4*r());const ph=r()*6,bnd=()=>{const o=[];for(let x=0;x<=g.size;x+=100)o.push({x,y:Math.min(g.size,Math.max(0,y0+g.size*.06*Math.sin(x/g.size*6+ph)+g.size*.03*Math.sin(x/g.size*15+ph*2)))});return o};
 let boundary=bnd();for(let t=0;t<8&&set.some(s=>boundary.some(p=>Math.hypot(p.x-s.x,p.y-s.y)<300));t++){y0=(y0+g.size*.17)%(g.size*.9);boundary=bnd()}
 return{lc,slope:S,settlements:set,roads,bridges,markets,schools,boreholes,marks,boundary}}
// smooth land cover: blur class indicators, resample bilinearly to res x res (row 0 = north), pick the dominant class if > 0.5
function smoothLC(g,lc,res){const N=g.N,F=[0,1,2,3].map(c=>{if(!c)return null;let a=Float32Array.from(lc,v=>v===c?1:0);for(let p=0;p<2;p++){const b=new Float32Array(N*N);for(let j=0;j<N;j++)for(let i=0;i<N;i++){let s=0,n=0;for(let dj=-1;dj<=1;dj++)for(let di=-1;di<=1;di++){const x=i+di,y=j+dj;if(x>=0&&y>=0&&x<N&&y<N){s+=a[y*N+x];n++}}b[j*N+i]=s/n}a=b}return a}),out=new Uint8Array(res*res);
 for(let py=0;py<res;py++)for(let px=0;px<res;px++){const fx=px/(res-1)*(N-1),fy=(res-1-py)/(res-1)*(N-1),i=Math.min(Math.floor(fx),N-2),j=Math.min(Math.floor(fy),N-2),tx=fx-i,ty=fy-j;let best=0,bv=.5;
  for(let c=1;c<4;c++){const a=F[c],v=a[j*N+i]*(1-tx)*(1-ty)+a[j*N+i+1]*tx*(1-ty)+a[(j+1)*N+i]*(1-tx)*ty+a[(j+1)*N+i+1]*tx*ty;if(v>bv){bv=v;best=c}}out[py*res+px]=best}
 return out}
return{RIVER,chain,build,slopeAt,smoothLC}});
