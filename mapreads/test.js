const E=require('./engine.js');let pass=0,fail=0;
const ok=(n,c)=>{c?pass++:(fail++,console.log('FAIL',n));if(c)console.log('ok  ',n)};
const g=E.generate({seed:7}),g2=E.generate({seed:7}),g3=E.generate({seed:8});
ok('deterministic for same seed',g.h.every((v,k)=>v===g2.h[k]));
ok('different seed differs',g.h.some((v,k)=>v!==g3.h[k]));
ok('elevation range respected',Math.min(...g.h)===1000&&Math.abs(Math.max(...g.h)-1500)<1e-9);
// contour accuracy: every vertex lies on the L-level of the bilinear surface
let worst=0,cnt=0;for(const L of E.levels(g,20))for(const s of E.contour(g,L)){for(const[x,y]of[[s[0],s[1]],[s[2],s[3]]]){worst=Math.max(worst,Math.abs(E.elev(g,x,y)-L));cnt++}}
ok(`contour vertices at exact elevation (n=${cnt}, max err ${worst.toExponential(1)} m)`,cnt>0&&worst<1e-6);
const lv=E.levels(g,20);ok('contour levels are multiples of interval',lv.every(L=>L%20===0)&&lv[1]-lv[0]===20);
// closed-contour check: each vertex on interior edges appears in exactly 2 segments
const S=E.contour(g,1250),m=new Map();for(const s of S)for(const p of[[s[0],s[1]],[s[2],s[3]]]){const k=p.map(v=>v.toFixed(4)).join();m.set(k,(m.get(k)||0)+1)}
const bnd=k=>{const[x,y]=k.split(',').map(Number);return x<1e-6||y<1e-6||x>g.size-1e-6||y>g.size-1e-6};
ok('contours continuous (interior vertices shared by 2 segments)',[...m].every(([k,c])=>c===2||bnd(k)));
// drainage: each flow step goes strictly downhill; accumulation grows downstream
ok('drainage always descends',[...g.flow.keys()].every(k=>g.flow[k]<0||g.h[g.flow[k]]<g.h[k]));
ok('accumulation increases downstream',[...g.flow.keys()].every(k=>g.flow[k]<0||g.acc[g.flow[k]]>g.acc[k]));
// peaks agree with model
ok('spot heights equal model heights',E.peaks(g).every(p=>Math.abs(E.elev(g,p.x,p.y)-p.z)<1e-9));
// calculations
ok('scale 5 cm at 1:50000 = 2500 m',E.groundFromMap(5,50000)===2500);
ok('scale 2500 m -> 5 cm',E.mapFromGround(2500,50000)===5);
ok('gradient 50 m over 1000 m = 1:20, 5%',JSON.stringify(E.gradient(50,1000))==='{"ratio":"1:20","percent":5}');
const O={x:0,y:0};
ok('bearings N/E/S/W',[E.bearing(O,{x:0,y:1}),E.bearing(O,{x:1,y:0}),E.bearing(O,{x:0,y:-1}),E.bearing(O,{x:-1,y:0})].join()==='0,90,180,270');
ok('bearing NE 45 and compass',E.bearing(O,{x:5,y:5})===45&&E.compass(45)==='NE');
ok('4-fig grid ref',E.gridRef(2340,1780,30000,70000,4)==='3271');
ok('6-fig grid ref',E.gridRef(2340,1780,30000,70000,6)==='323717');
let bad=false;try{E.gradient(10,0)}catch(e){bad=true}ok('invalid input throws',bad);
// cross-section & intervisibility
const a={x:500,y:500},b={x:4000,y:3000},P=E.profile(g,a,b,50);
ok('profile endpoints match terrain',Math.abs(P[0].z-E.elev(g,a.x,a.y))<1e-9&&Math.abs(P[50].z-E.elev(g,b.x,b.y))<1e-9&&Math.abs(P[50].d-E.dist(a,b))<1e-9);
const flat={N:11,cell:100,h:new Float64Array(121).fill(100)};
ok('flat terrain is intervisible',E.intervisible(flat,{x:0,y:0},{x:1000,y:1000}).visible);
const hill={N:11,cell:100,h:new Float64Array(121).fill(100)};hill.h[5*11+5]=300;
ok('hill between points blocks view',!E.intervisible(hill,{x:0,y:500},{x:1000,y:500}).visible);
ok('observer on hilltop sees downslope target',E.intervisible(hill,{x:500,y:500},{x:1000,y:500}).visible);

// ---- features ----
const F=require('./features.js'),L0=1250,segs=E.contour(g,L0),ch=F.chain(segs);
ok('chain keeps every segment exactly once',ch.reduce((a,c)=>a+c.pts.length-1,0)===segs.length);
ok('chained vertices all at contour elevation',ch.every(c=>c.pts.every(p=>Math.abs(E.elev(g,p[0],p[1])-L0)<1e-6)));
ok(`segments joined into few polylines (${segs.length} segs -> ${ch.length} lines)`,ch.length*5<segs.length);
ok('closed loops start where they end',ch.filter(c=>c.closed).every(c=>Math.hypot(c.pts[0][0]-c.pts.at(-1)[0],c.pts[0][1]-c.pts.at(-1)[1])<2e-3));
const f1=F.build(g),f2=F.build(E.generate({seed:7})),N=g.N,cs=g.cell;
ok('features deterministic',JSON.stringify(f1.settlements)===JSON.stringify(f2.settlements)&&f1.roads.length===f2.roads.length);
ok(`settlements placed (${f1.settlements.length}), >=900 m apart`,f1.settlements.length>=3&&f1.settlements.every((a,i)=>f1.settlements.every((b,j)=>i===j||Math.hypot(a.x-b.x,a.y-b.y)>=900)));
ok('settlements on gentle, non-river, non-marsh ground',f1.settlements.every(s=>f1.slope[s.k]<.05&&g.acc[s.k]<F.RIVER&&f1.lc[s.k]!==3));
ok('one road per extra settlement, each ends at a settlement',f1.roads.length>=f1.settlements.length-1&&f1.roads.every(r=>f1.settlements.some(s=>s.k===r.cells[0])&&f1.settlements.some(s=>s.k===r.cells.at(-1))));
ok('road cells are contiguous',f1.roads.every(r=>r.pts.every((p,i)=>!i||Math.hypot(p.x-r.pts[i-1].x,p.y-r.pts[i-1].y)<=cs*Math.SQRT2+1e-6)));
const mean=a=>a.reduce((x,y)=>x+y,0)/a.length,rs=f1.roads.flatMap(r=>r.cells.map(k=>f1.slope[k]));
ok(`roads avoid steep ground (road mean ${mean(rs).toFixed(3)} < terrain mean ${mean([...f1.slope]).toFixed(3)})`,mean(rs)<mean([...f1.slope]));
ok('every bridge sits on a river cell and a road',f1.bridges.every(b=>g.acc[b.k]>=F.RIVER&&f1.roads.some(r=>r.cells.includes(b.k))));
const lcS=c=>mean([...f1.lc.keys()].filter(k=>f1.lc[k]===c).map(k=>f1.slope[k]));
ok(`woodland steeper than cultivation (${lcS(1).toFixed(3)} > ${lcS(2).toFixed(3)})`,lcS(1)>lcS(2));
ok('marsh only on gentle ground near rivers',[...f1.lc.keys()].filter(k=>f1.lc[k]===3).every(k=>f1.slope[k]<.03));


let nb=0,allOk=true;for(const sd of[1,2,3,4,5]){const h=E.generate({seed:sd}),q=F.build(h);nb+=q.bridges.length;allOk=allOk&&q.bridges.every(b=>h.acc[b.k]>=F.RIVER)&&q.roads.length>=q.settlements.length-1}
ok(`bridges valid across seeds 1-5 (${nb} bridges total)`,nb>0&&allOk);

// ---- improvements ----
const nb2=[...Array(20).keys()].map(i=>F.build(E.generate({seed:i+1})).bridges.length);
ok(`every seed 1-20 has a bridge (min ${Math.min(...nb2)})`,Math.min(...nb2)>0);
const res=(N-1)*4+1,sm=F.smoothLC(g,f1.lc,res);let agree=0;for(let j=0;j<N;j++)for(let i=0;i<N;i++)if(sm[(res-1-j*4)*res+i*4]===f1.lc[j*N+i])agree++;
ok(`smoothed land cover keeps ${(agree/N/N*100).toFixed(1)}% of cells`,agree/N/N>.85&&sm.every(v=>v<4));
const fs=f1.settlements,nm=fs.map(s=>s.name);
ok('settlement names: unique, well-formed, deterministic',new Set(nm).size===nm.length&&nm.every(n=>/^[A-Z][a-z]+$/.test(n))&&JSON.stringify(nm)===JSON.stringify(f2.settlements.map(s=>s.name))&&fs[0].kind==='Trading centre');
ok('no name equals a real town/district',nm.every(n=>!['Lilongwe','Blantyre','Zomba','Mzuzu','Kasungu','Salima','Dedza','Ntcheu','Mangochi','Karonga'].includes(n)));
ok('benchmarks/spot heights equal model height (rounded)',f1.marks.length>=5&&f1.marks.every(m=>m.z===Math.round(E.elev(g,m.x,m.y))));
ok('BMs sit on the main road',f1.marks.filter(m=>m.kind==='BM').every(m=>f1.roads[0].cells.includes(m.k)));
ok('boundary spans map, in bounds, clear of buildings',f1.boundary[0].x===0&&f1.boundary.at(-1).x===g.size&&f1.boundary.every(p=>p.y>=0&&p.y<=g.size)&&fs.every(s=>f1.boundary.every(p=>Math.hypot(p.x-s.x,p.y-s.y)>=300)));
const U=E.uprof;ok('U-valley profile: flat floor, symmetric, steep walls',U(0)===1&&U(.02)===1&&U(.03)===1&&U(-.05)===U(.05)&&U(.12)===0&&U(.05)>0&&U(.05)<1);
const ms=h=>{let m=0;for(let j=0;j<h.N;j++)for(let i=0;i<h.N;i++)m=Math.max(m,F.slopeAt(h,i,j));return m};
const base=E.generate({seed:3,hills:0,ridge:false}),esc=E.generate({seed:3,hills:0,ridge:false,terrain:'escarp'}),uv=E.generate({seed:3,hills:0,ridge:false,terrain:'uvalley'});
ok(`escarpment makes a steep scarp (max slope ${ms(esc).toFixed(2)} vs ${ms(base).toFixed(2)})`,ms(esc)>3*ms(base));
ok(`U-valley has steep walls (max slope ${ms(uv).toFixed(2)} vs ${ms(base).toFixed(2)})`,ms(uv)>2*ms(base));
ok('terrain types in range, deterministic, drain downhill',['escarp','uvalley','mixed'].every(t=>{const a=E.generate({seed:5,terrain:t}),b=E.generate({seed:5,terrain:t});return Math.min(...a.h)===1000&&a.h.every((v,k)=>v===b.h[k])&&[...a.flow.keys()].every(k=>a.flow[k]<0||a.h[a.flow[k]]<a.h[k])}));

// ---- question generator: answers re-derived independently ----
const Qg=require('./questions.js');
const bil=(h,x,y)=>{const fx=x/h.cell,fy=y/h.cell,i=Math.min(Math.floor(fx),h.N-2),j=Math.min(Math.floor(fy),h.N-2),u=fx-i,v=fy-j,H=(a,b)=>h.h[b*h.N+a];return H(i,j)*(1-u)*(1-v)+H(i+1,j)*u*(1-v)+H(i,j+1)*(1-u)*v+H(i+1,j+1)*u*v};
const gr6=p=>String(Math.floor((30000+p.x)%100000/100)).padStart(3,'0')+String(Math.floor((70000+p.y)%100000/100)).padStart(3,'0');
let nparts=0,badq=[];const kinds=new Set(),sawYes={},sawNo={};
for(const sd of[7,3,11,21]){const G=E.generate({seed:sd}),FF=F.build(G);
 for(const lv of['basic','intermediate','advanced','msce'])for(const qs of[1,2,3]){const P=Qg.build(G,FF,{level:lv,seed:qs});
  if(!Qg.verify(G,FF,P).ok)badq.push('verify '+sd+lv);
  if(P.total!==P.questions.reduce((s,q)=>s+q.parts.reduce((a,p)=>a+p.marks,0),0))badq.push('marks');
  for(const q of P.questions)for(const p of q.parts){nparts++;kinds.add(p.kind);const I=p.in,at=(x,y)=>x>=0&&y>=0&&x<=G.size&&y<=G.size;
   if(I.a&&!(at(I.a.x,I.a.y)&&at(I.b.x,I.b.y)))badq.push('range '+p.kind);
   if(I.a&&p.kind!=='mapdist'){const m=[...p.text.matchAll(/GR (\d{6})/g)].map(x=>x[1]);if(m[0]!==gr6(I.a)||m[1]!==gr6(I.b))badq.push('GR text '+p.kind)}
   if(p.kind==='mapdist'&&!p.ans.startsWith((Math.round(Math.hypot(I.b.x-I.a.x,I.b.y-I.a.y)/100)/10).toFixed(1)))badq.push('mapdist');
   if(p.kind==='bearing'){const b=((Math.atan2(I.b.x-I.a.x,I.b.y-I.a.y)*180/Math.PI)+360)%360;if(Math.abs(parseFloat(p.ans)-b)>.06)badq.push('bearing')}
   if(p.kind==='relief'){const d=Math.abs(Math.round(bil(G,I.a.x,I.a.y))-Math.round(bil(G,I.b.x,I.b.y)));if(p.ans!==d+' m')badq.push('relief')}
   if(p.kind==='gradient'){const vi=Math.round(Math.abs(bil(G,I.b.x,I.b.y)-bil(G,I.a.x,I.a.y))),hd=Math.round(Math.hypot(I.b.x-I.a.x,I.b.y-I.a.y));if(!p.ans.includes('1:'+Math.round(hd/vi))||!p.ans.startsWith('VI '+vi+' m'))badq.push('gradient')}
   if(p.kind==='ref'&&p.ans!==gr6(I.p))badq.push('ref');
   if(p.kind==='vis'){let vis=true;const za=bil(G,I.a.x,I.a.y)+1.7,zb=bil(G,I.b.x,I.b.y)+1.7;for(let k=1;k<2000;k++){const t=k/2000;if(bil(G,I.a.x+t*(I.b.x-I.a.x),I.a.y+t*(I.b.y-I.a.y))>za+t*(zb-za)){vis=false;break}}
    if(vis!==p.ans.startsWith('Yes'))badq.push('vis '+sd);(p.ans.startsWith('Yes')?sawYes:sawNo)[sd]=1}
   if(p.kind==='section'){let mx=-1e9;for(let k=0;k<=400;k++){const t=k/400;mx=Math.max(mx,bil(G,I.a.x+t*(I.b.x-I.a.x),I.a.y+t*(I.b.y-I.a.y)))}if(Math.abs(parseInt(p.ans.match(/about (\d+)/)[1])-mx)>2)badq.push('section')}
   if(p.kind==='bridges'&&p.ans!==String(FF.bridges.length))badq.push('bridges');
   if(p.kind==='interval'&&p.ans!=='20 m')badq.push('interval');
   if(!p.ans||!p.steps.length||!p.text)badq.push('empty')}}}
ok(`all ${nparts} generated parts re-derived independently (${badq.length} mismatches${badq.length?': '+badq.slice(0,5):''})`,badq.length===0);
ok('all 15 question kinds exercised',kinds.size>=15);
ok('intervisibility questions include both visible and blocked cases',Object.keys(sawYes).length>0&&Object.keys(sawNo).length>0);
const Pa=Qg.build(g,f1,{level:'msce',seed:2}),Pb=Qg.build(g,f1,{level:'msce',seed:2}),Pc=Qg.build(g,f1,{level:'msce',seed:3});
ok('papers deterministic; different seed differs',JSON.stringify(Pa)===JSON.stringify(Pb)&&JSON.stringify(Pa)!==JSON.stringify(Pc));
ok('MSCE paper has 5 structured questions, multi-part, marks add up',Pa.questions.length===5&&Pa.questions.every(q=>q.parts.length>=2)&&Pa.total===42);
ok('basic < intermediate < advanced in marks',['basic','intermediate','advanced'].map(l=>Qg.build(g,f1,{level:l}).total).every((v,i,a)=>!i||v>a[i-1]));
const tamper=JSON.parse(JSON.stringify(Pa));tamper.questions[0].parts[1].ans='999 m';
ok('verify() catches a wrong answer',!Qg.verify(g,f1,tamper).ok);
ok('markdown export has marks, answers and MANEB disclaimer',/Not official MANEB/.test(Qg.toMarkdown(Pa,true))&&/Answer:/.test(Qg.toMarkdown(Pa,true))&&!/Answer:/.test(Qg.toMarkdown(Pa,false)));

// ---- annotation store and demonstrations ----
const An=require('./annotate.js'),Dm=require('./demo.js');
const st=new An.Store();st.add({t:'pen',pts:[[0,0],[1,1]]});st.add({t:'mark',x:1,y:2});
ok('annotation undo/redo/clear',(st.undo(),st.items.length===1)&&(st.redo(),st.items.length===2)&&(st.undo(),st.add({t:'text',x:0,y:0,s:'a'}),!st.redo())&&(st.clear(),st.items.length===0&&!st.undo()));
const st2=new An.Store();st2.add({t:'dist',a:{x:0,y:0},b:{x:30,y:40}});st2.add({t:'arrow',a:{x:0,y:0},b:{x:9,y:9}});st2.add({t:'hl',pts:[[0,0],[5,5]]});st2.add({t:'text',x:1,y:1,s:'t'});st2.add({t:'poly',pts:[[0,0],[1,1],[2,0]],closed:true});
ok('annotations serialise and reload',(()=>{const s=new An.Store();s.load(st2.toJSON());return JSON.stringify(s.items)===JSON.stringify(st2.items)})());
const calls=[];const cx=new Proxy({},{get:(_,k)=>(...a)=>calls.push(k+':'+a.join()),set:()=>true});An.draw(cx,st2.items,(x,y)=>[x,y]);
ok('annotation renderer draws every type incl. measured distance label "50 m"',calls.some(c=>c.startsWith('fillText:50 m')));
const dmBad=[],hitIds=new Set();
const inb=(G,x,y)=>x>=-1&&y>=-1&&x<=G.size+1&&y<=G.size+1;
for(const sd of[7,3,11]){const G=E.generate({seed:sd}),FF=F.build(G);
 for(const id of Dm.IDS){const D=Dm.make(G,FF,id,{seed:2}),D2=Dm.make(G,FF,id,{seed:2});hitIds.add(id);
  if(JSON.stringify(D)!==JSON.stringify(D2))dmBad.push('determinism '+id);
  if(D.steps.length<3||!D.steps[D.answerIndex].answer||D.steps.slice(0,D.answerIndex).some(s=>s.answer))dmBad.push('shape '+id);
  for(const it of D.steps.flatMap(s=>s.items)){const ps=it.pts?it.pts.map(p=>({x:p[0],y:p[1]})):it.a?[it.a,it.b]:[{x:it.x,y:it.y}];if(!ps.every(p=>isFinite(p.x)&&isFinite(p.y)&&inb(G,p.x,p.y)))dmBad.push('bounds '+id)}
  if(Dm.itemsUpTo(D,99,false).length!==D.steps.slice(0,D.answerIndex).flatMap(s=>s.items).length)dmBad.push('answer leaks '+id);
  const d=D.data;
  if(id==='hill'){const pk=d.peak;if(!d.rings.length)dmBad.push('hill rings');d.rings.forEach((r,i)=>{if(!(r.L<pk.z)||!Dm.pip([pk.x,pk.y],r.pts)||(i&&r.L!==d.rings[i-1].L-20)||r.pts.some(p=>Math.abs(bil(G,p[0],p[1])-r.L)>1e-6))dmBad.push('hill ring '+i)})}
  if(id==='valley'){if(!(bil(G,d.up.x,d.up.y)>bil(G,d.cell.x,d.cell.y)))dmBad.push('valley upstream');if(!d.dn.every((p,i)=>!i||bil(G,p.x,p.y)<bil(G,d.dn[i-1].x,d.dn[i-1].y)))dmBad.push('valley downstream')}
  if(id==='ridge'){const p=d.path;if(p.length<4||p[0].x!==E.peaks(G,1)[0].x||!p.every((q,i)=>!i||G.h[Math.round(q.y/G.cell)*G.N+Math.round(q.x/G.cell)]<G.h[Math.round(p[i-1].y/G.cell)*G.N+Math.round(p[i-1].x/G.cell)]))dmBad.push('ridge path')}
  if(id==='gradient'){const[a,b]=D.pts,vi=Math.abs(Math.round(bil(G,b.x,b.y))-Math.round(bil(G,a.x,a.y))),hd=Math.round(Math.hypot(b.x-a.x,b.y-a.y));if(d.vi!==vi||d.hd!==hd||d.gr.ratio!=='1:'+Math.round(hd/vi))dmBad.push('gradient')}
  if(id==='bearing'){const[a,b]=D.pts;if(Math.abs(d.bearing-(((Math.atan2(b.x-a.x,b.y-a.y)*180/Math.PI)+360)%360))>.06)dmBad.push('bearing')}
  if(id==='gridref'&&d.ref!==gr6(d.p))dmBad.push('gridref');
  if(id==='section'&&!(d.crossings.length>0&&d.crossings.every(c=>Math.abs(bil(G,c.x,c.y)-c.L)<.5)))dmBad.push('section crossings');
  if(id==='intervis'){const[a,b]=D.pts;let vis=true;const za=bil(G,a.x,a.y)+1.7,zb=bil(G,b.x,b.y)+1.7;for(let k=1;k<2000;k++){const t=k/2000;if(bil(G,a.x+t*(b.x-a.x),a.y+t*(b.y-a.y))>za+t*(zb-za)){vis=false;break}}if(vis!==d.visible)dmBad.push('intervis')}}}
ok(`all ${Dm.IDS.length} demonstrations verified on 3 maps (${dmBad.length} problems${dmBad.length?': '+dmBad.slice(0,4):''})`,dmBad.length===0&&hitIds.size===9);
console.log(`\n${pass} passed, ${fail} failed`);process.exit(fail?1:0);
