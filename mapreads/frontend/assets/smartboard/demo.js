// Step-by-step map-reading demonstrations built from the actual terrain. Each step adds annotation items; the last step is the hidden answer.
(function(root,f){if(typeof module==='object')module.exports=f(require('./engine.js'),require('./features.js'));else root.Demo=f(root.MapEngine,root.Feat);})(this,function(M,Fe){
const rng=s=>()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296};
const pip=(p,poly)=>{let c=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])c=!c}return c};
const area=p=>{let s=0;for(let i=0,j=p.length-1;i<p.length;j=i++)s+=p[j][0]*p[i][1]-p[i][0]*p[j][1];return Math.abs(s/2)};
const I=p=>({x:p.x,y:p.y});const R=Math.round;
function rings(g,iv,p,n){const o=[];let L=Math.floor((M.elev(g,p.x,p.y)-1e-6)/iv)*iv;for(let k=0;k<n;k++,L-=iv){const ch=Fe.chain(M.contour(g,L)).filter(c=>c.closed&&pip([p.x,p.y],c.pts)).sort((a,b)=>area(a.pts)-area(b.pts));if(!ch.length)break;o.push({L,pts:ch[0].pts})}return o}
const cellP=(g,k)=>({x:(k%g.N)*g.cell,y:((k/g.N)|0)*g.cell});
const upstream=(g,k,n)=>{const o=[k];for(let q=0;q<n;q++){let b=-1;const ci=k%g.N,cj=(k/g.N)|0;for(let dj=-1;dj<=1;dj++)for(let di=-1;di<=1;di++){const i=ci+di,j=cj+dj;if((di||dj)&&i>=0&&j>=0&&i<g.N&&j<g.N&&g.flow[j*g.N+i]===k&&(b<0||g.acc[j*g.N+i]>g.acc[b]))b=j*g.N+i}if(b<0)break;k=b;o.push(k)}return o};
function nearPart(g,iv,L,c,r){const best=Fe.chain(M.contour(g,L)).map(ch=>({ch,d:Math.min(...ch.pts.map(p=>Math.hypot(p[0]-c.x,p[1]-c.y)))})).sort((a,b)=>a.d-b.d)[0];return best?best.ch.pts.filter(p=>Math.hypot(p[0]-c.x,p[1]-c.y)<r):[]}
function pair(g,r,lo,hi,mz){let a,b;const n=Math.floor(g.size/100)-4,pt=()=>({x:(2+Math.floor(r()*n))*100,y:(2+Math.floor(r()*n))*100});for(let t=0;t<600;t++){a=pt();b=pt();const d=M.dist(a,b);if(d>=lo&&d<=hi&&Math.abs(M.elev(g,a.x,a.y)-M.elev(g,b.x,b.y))>=mz)break}return[a,b]}
const IDS=['hill','valley','ridge','gradient','bearing','distance','gridref','section','intervis'];
function make(g,F,id,o={}){const iv=o.iv||20,rf=o.rf||50000,e0=(o.e0!==undefined?o.e0:30000),n0=(o.n0!==undefined?o.n0:70000),r=rng(((o.seed!==undefined?o.seed:1))*97+g.cfg.seed*13+5),D={id,steps:[],pts:null};const S=(text,items=[],extra={})=>D.steps.push({text,items,...extra});
 const el=p=>R(M.elev(g,p.x,p.y));
 if(id==='hill'){let pk,rg=[];for(const p of M.peaks(g,64)){const candidate=rings(g,iv,p,4);if(candidate.length>=2){pk=p;rg=candidate;break}}
  if(!pk){pk=M.peaks(g,1)[0];if(!pk)throw new Error('The terrain has no summit to demonstrate.');
   for(let q=0;q<8&&!rg.length;q++){const L=Math.floor((pk.z-1e-6)/iv)*iv-q*iv,lines=Fe.chain(M.contour(g,L));
    const nearest=lines.map(ch=>({ch,d:Math.min(...ch.pts.map(p=>Math.hypot(p[0]-pk.x,p[1]-pk.y)))})).sort((a,b)=>a.d-b.d)[0];if(nearest)rg=[{L,pts:nearest.ch.pts,closed:nearest.ch.closed}]}}
  const enclosed=rg.length>=2;D.title=enclosed?'Identify a hill from contour patterns':'Read high ground from contours';
  D.question=enclosed?'Name the landform shown by the contours around the highlighted summit.':'Use the spot height and nearest contour to identify the high ground.';
  S(enclosed?'Look for contour lines that close up into rings.':'Locate the highest spot height and inspect its nearest contour.',rg.length?[{t:'poly',pts:rg[0].pts,closed:!!rg[0].closed||enclosed,c:'b'}]:[{t:'mark',x:pk.x,y:pk.y,s:R(pk.z)+' m',c:'r'}]);
  if(enclosed){S('Read the heights on the rings: they rise towards the centre.',rg.flatMap(q=>[{t:'poly',pts:q.pts,closed:true,c:'b'},{t:'text',x:q.pts[q.pts.length>>2][0],y:q.pts[q.pts.length>>2][1],s:q.L+' m',c:'k'}]));
   S('Check spacing: close rings mean steep ground, wide rings mean gentle ground.',[{t:'arrow',a:{x:rg[0].pts[0][0],y:rg[0].pts[0][1]},b:I(pk),c:'r'},{t:'mark',x:pk.x,y:pk.y,s:R(pk.z)+' m',c:'r'}]);
   S('',[],{answer:`Hill. Closed rings rising inwards to a summit of about ${R(pk.z)} m.`})}
  else{S('Read the contour height and compare it with the spot height.',rg.map(q=>({t:'poly',pts:q.pts,closed:!!q.closed,c:'b'})));
   S('Contours show the surrounding high ground; the study area may not contain complete rings around every summit.',[{t:'mark',x:pk.x,y:pk.y,s:R(pk.z)+' m',c:'r'}]);
   S('',[],{answer:`High ground near a summit of about ${R(pk.z)} m.`})}
  D.data={peak:pk,rings:rg}}
 else if(id==='valley'||id==='ridge'){
  if(id==='valley'){const cs=[...g.acc.keys()].filter(k=>g.acc[k]>=100&&g.acc[k]<500&&(k%g.N)>8&&(k%g.N)<g.N-8&&((k/g.N)|0)>8&&((k/g.N)|0)<g.N-8);const k=cs[Math.floor(r()*cs.length)],up=upstream(g,k,10),dn=[k];for(let q=0,c=k;q<15&&g.flow[c]>=0;q++){c=g.flow[c];dn.push(c)}
   const c=cellP(g,k),z=M.elev(g,c.x,c.y),L=(Math.floor(z/iv)+1)*iv,part=nearPart(g,iv,L,c,700),u=cellP(g,up[up.length-1]);
   D.title='Distinguish a valley from a ridge (valley)';D.question='What landform does the river follow? Explain from the contour shape.';
   S('Find the river: valleys carry streams.',[{t:'poly',pts:[...up.slice().reverse(),...dn.slice(1)].map(q=>{const p=cellP(g,q);return[p.x,p.y]}),c:'b',w:4}]);
   S(`Follow the ${L} m contour where it crosses the river.`,[{t:'poly',pts:part,c:'a',w:4},{t:'text',x:part[part.length>>1][0],y:part[part.length>>1][1],s:L+' m',c:'k'}]);
   S('Notice which way the contour bends: it points towards higher ground (upstream).',[{t:'arrow',a:I(c),b:I(u),c:'r'},{t:'text',x:u.x,y:u.y,s:'uphill',c:'r'}]);
   S('',[],{answer:'A river valley: contours form V (or U) shapes pointing up-slope, towards higher ground, where they cross the river.'});D.data={cell:c,up:u,dn:dn.map(q=>cellP(g,q))}}
  else{const pk=M.peaks(g,1)[0],path=[pk];let cx=Math.round(pk.x/g.cell),cy=Math.round(pk.y/g.cell);for(let q=0;q<40;q++){let best=null;for(let dj=-1;dj<=1;dj++)for(let di=-1;di<=1;di++){const i=cx+di,j=cy+dj;if((!di&&!dj)||i<0||j<0||i>=g.N||j>=g.N)continue;const z=g.h[j*g.N+i];if(z<g.h[cy*g.N+cx]&&(!best||z>best.z))best={i,j,z}}if(!best)break;cx=best.i;cy=best.j;path.push({x:cx*g.cell,y:cy*g.cell})}
   const m=path[path.length>>1],L=(Math.floor(M.elev(g,m.x,m.y)/iv))*iv,part=nearPart(g,iv,L,m,700);
   D.title='Distinguish a valley from a ridge (ridge)';D.question='What landform runs down from the summit along the highlighted line?';
   S('Start at the summit and follow the highest ground downhill (approximate crest line).',[{t:'poly',pts:path.map(p=>[p.x,p.y]),c:'r',w:4}]);
   S(`Look at the ${L} m contour beside the crest.`,[{t:'poly',pts:part,c:'a',w:4},{t:'text',x:part[part.length>>1][0],y:part[part.length>>1][1],s:L+' m',c:'k'}]);
   S('The contour bends away from the crest, pointing downhill.',[{t:'arrow',a:I(path[0]),b:I(path[path.length-1]),c:'g'},{t:'text',x:path[path.length-1].x,y:path[path.length-1].y,s:'downhill',c:'g'}]);
   S('',[],{answer:'A ridge: an elongated crest; contours form V or U shapes pointing down-slope, away from higher ground.'});D.data={path}}}
 else if(id==='gradient'||id==='bearing'||id==='distance'||id==='section'||id==='intervis'){
  let a,b;if(id==='distance'){a=F.settlements[0];b=F.settlements[1]}else[a,b]=pair(g,r,id==='section'?2000:1200,id==='section'?4000:2500,id==='gradient'?40:0);
  if(id==='intervis'){for(let t=0;t<200;t++){[a,b]=pair(g,r,1500,4000,0);if(!M.intervisible(g,a,b).visible)break}}
  D.pts=[I(a),I(b)];const d=M.dist(a,b),ea=el(a),eb=el(b);
  const AB=[{t:'mark',x:a.x,y:a.y,s:id==='distance'?a.name:'A',c:'b'},{t:'mark',x:b.x,y:b.y,s:id==='distance'?b.name:'B',c:'r'}];
  if(id==='gradient'){const vi=Math.abs(eb-ea),gr=M.gradient(vi,R(d));D.title='Calculate a gradient';D.question='Calculate the average gradient from A to B.';
   S('Mark the two points.',AB);S('Read the heights at A and B from the contours.',[{t:'text',x:a.x,y:a.y-120,s:ea+' m',c:'b'},{t:'text',x:b.x,y:b.y-120,s:eb+' m',c:'r'}]);
   S(`Vertical interval = ${Math.max(ea,eb)} − ${Math.min(ea,eb)} = ${vi} m.`,[]);
   S(`Measure A–B (≈ ${(M.mapFromGround(d,rf)).toFixed(1)} cm) and convert with the scale: horizontal distance ≈ ${R(d)} m.`,[{t:'line',a:I(a),b:I(b),c:'a'}]);
   S('',[],{answer:`Gradient = VI ÷ HD = ${vi} ÷ ${R(d)} = ${gr.ratio} (${gr.percent}%).`});D.data={vi,hd:R(d),gr}}
  else if(id==='bearing'){const bg=M.bearing(a,b);D.title='Find a bearing';D.question='Measure the bearing of B from A.';
   S('Mark A and B.',AB);S('Draw grid north through A.',[{t:'arrow',a:I(a),b:{x:a.x,y:Math.min(a.y+900,g.size-20)},c:'k'},{t:'text',x:a.x+40,y:Math.min(a.y+900,g.size-20),s:'N',c:'k'}]);
   S('Draw the line from A to B.',[{t:'line',a:I(a),b:I(b),c:'a'}]);S('Place the protractor at A and read clockwise from north.',[]);
   S('',[],{answer:`Bearing ${bg}° (${M.compass(bg)}).`});D.data={bearing:bg}}
  else if(id==='distance'){D.title='Calculate ground distance';D.question=`Find the ground distance from ${a.name} to ${b.name}.`;const cm=Math.round(M.mapFromGround(d,rf)*10)/10;
   S('Mark the two settlements.',AB);S('Measure the straight line with a ruler.',[{t:'line',a:I(a),b:I(b),c:'a'}]);S(`Ruler reading ≈ ${cm} cm. Ground distance = ${cm} × ${rf} ÷ 100 000.`,[]);
   S('',[],{answer:`≈ ${(d/1000).toFixed(1)} km.`});D.data={cm,km:d/1000}}
  else if(id==='section'){const P=M.profile(g,a,b,400),cr=[];for(let k=1;k<P.length;k++){const z0=P[k-1].z,z1=P[k].z;for(let L=Math.ceil(Math.min(z0,z1)/iv)*iv;L<=Math.max(z0,z1);L+=iv)if((z0<L&&z1>=L)||(z1<L&&z0>=L)){let low=(k-1)/(P.length-1),high=k/(P.length-1),lowZ=z0;
    for(let n=0;n<28;n++){const mid=(low+high)/2,z=M.elev(g,a.x+mid*(b.x-a.x),a.y+mid*(b.y-a.y));if((lowZ<L)===(z<L)){low=mid;lowZ=z}else high=mid}
    const t=(low+high)/2;cr.push({x:a.x+t*(b.x-a.x),y:a.y+t*(b.y-a.y),L,d:t*d})}}
   const zs=P.map(p=>p.z),hi=Math.max(...zs),lo=Math.min(...zs);D.title='Draw a cross-section';D.question='Draw the cross-section A–B and state its highest and lowest points.';
   S('Draw the section line A–B.',[...AB,{t:'line',a:I(a),b:I(b),c:'a'}]);
   S('Mark every contour crossed along the line (index contours labelled).',cr.map(q=>({t:'mark',x:q.x,y:q.y,s:q.L%(iv*5)===0?String(q.L):'',c:'a'})));
   S('Plot distance (horizontal) against height (vertical) and join smoothly. See the profile panel.',[]);
   S('',[],{answer:`Highest ≈ ${R(hi)} m, lowest ≈ ${R(lo)} m, relief ≈ ${R(hi-lo)} m.`});D.data={crossings:cr,hi,lo}}
  else{const v=M.intervisible(g,a,b,1.7,1.7);D.title='Decide intervisibility';D.question='Is B visible from A?';
   S('Mark A and B.',AB);S('Draw the sight line between them.',[{t:'line',a:I(a),b:I(b),c:'a'}]);
   S('Draw the cross-section and add the sight line (see the profile panel). Does any ground rise above it?',v.visible?[]:[{t:'mark',x:v.blockedAt.x,y:v.blockedAt.y,s:R(v.blockedAt.z)+' m',c:'r'}]);
   S('',[],{answer:v.visible?'Visible: no ground rises above the line of sight.':`Not visible: ground rising to ≈ ${R(v.blockedAt.z)} m blocks the line of sight.`});D.data={visible:v.visible,blockedAt:v.blockedAt}}}
 else if(id==='gridref'){const p=F.marks.find(m=>m.kind==='TP')||F.marks[0],ref=M.gridRef(p.x,p.y,e0,n0,6);D.title='Read a six-figure grid reference';D.question=`Give the six-figure grid reference of the ${p.kind==='TP'?'trig point':'spot height'} (${p.z} m).`;
  const ex=Math.floor((e0+p.x)/1000)*1000-e0,ny=Math.floor((n0+p.y)/1000)*1000-n0;D.pts=[I(p)];
  S('Mark the point.',[{t:'mark',x:p.x,y:p.y,s:p.z+' m',c:'r'}]);S('Eastings first: find the grid line to the left of the point.',[{t:'line',a:{x:ex,y:ny-300},b:{x:ex,y:ny+1300},c:'b'}]);
  S('Then northings: the grid line below the point.',[{t:'line',a:{x:ex-300,y:ny},b:{x:ex+1300,y:ny},c:'g'}]);S('Estimate tenths of the square across (3rd figure) and up (6th figure).',[{t:'line',a:{x:p.x,y:ny},b:{x:p.x,y:p.y},c:'a'},{t:'line',a:{x:ex,y:p.y},b:{x:p.x,y:p.y},c:'a'}]);
  S('',[],{answer:ref});D.data={ref,p}}
 D.answerIndex=D.steps.length-1;return D}
const itemsUpTo=(D,k,showAns)=>D.steps.slice(0,Math.min(k,D.answerIndex+(showAns?1:0))).flatMap(s=>s.items);
return{IDS,make,itemsUpTo,pip,rings}});
