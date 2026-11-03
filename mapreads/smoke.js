// Headless smoke test of index.html's page script (stubbed DOM/canvas/THREE). Exercises every control path; exits 1 on any exception.
const fs=require('fs'),path=require('path');
const code=fs.readFileSync(path.join(__dirname,'index.html'),'utf8').split('<script>')[1].split('</script>')[0];
const log={};const ctx=new Proxy({},{get:(t,k)=>k==='getImageData'?()=>({data:[1,1,1,255]}):k==='createImageData'?(w,h)=>({data:new Uint8ClampedArray(w*h*4)}):(...a)=>{log[k]=(log[k]||0)+1},set:()=>true});
const mk=()=>({getContext:()=>ctx,style:{},getBoundingClientRect:()=>({width:700,height:700,left:0,top:0}),addEventListener(){},appendChild(){},setAttribute(){},dispatchEvent(){},offsetParent:{},clientWidth:300,clientHeight:150,checked:true,value:'20',classList:{add(){},remove(){},toggle(){},contains:()=>true},querySelectorAll:()=>[],dataset:{},setPointerCapture(){},click(){this.onclick&&this.onclick()}});
const els={t3:{offsetParent:null}},G=i=>els[i]=els[i]||mk();
global.window=global;global.parent=global;global.CustomEvent=class{constructor(type,init){this.type=type;this.detail=init.detail}};global.dispatchEvent=()=>{};global.document={body:{classList:{add(){},remove(){},toggle(){}}},getElementById:G,documentElement:{dataset:{}},createElement:()=>mk(),querySelectorAll:()=>[],addEventListener(){}};
global.getComputedStyle=()=>({getPropertyValue:()=>'#888'});global.matchMedia=()=>({matches:false});global.location={search:''};global.addEventListener=()=>{};global.requestAnimationFrame=()=>{};global.devicePixelRatio=1;global.prompt=()=>'label';global.print=()=>{};
const stub=()=>new Proxy(function(){},{get:(t,k)=>k===Symbol.toPrimitive?()=>0:stub(),apply:()=>stub(),construct:()=>stub(),set:()=>true});
global.THREE=stub();for(const[n,f]of[['MapEngine','engine'],['Feat','features'],['Questions','questions'],['Annot','annotate'],['Demo','demo']])global[n]=require('./'+f+'.js');require('./smartboard-bridge.js');
let n=0;const step=(name,fn)=>{try{fn();n++}catch(e){console.error('FAIL',name,'\n',e.stack.split('\n').slice(0,3).join('\n'));process.exit(1)}};
G('rf').value='50000';G('pm').value='std';G('palette').value='brown';step('load page script',()=>(0,eval)(code));
for(const t of['hills','escarp','uvalley','mixed'])for(const pm of['std','hc','gray'])for(const th of['light','dark'])step(`generate ${t}/${pm}/${th}`,()=>{G('tp').value=t;G('pm').value=pm;G('seed').value='5';G('hills').value='3';G('iv').value='20';G('gen').onclick();window.setTheme(th)});
for(const iv of['10','20','50']){G('iv').value=iv;step('interval '+iv,()=>G('iv').onchange())}
step('rnd',()=>G('rnd').onclick());step('ve',()=>G('ve').oninput());step('view',()=>G('vw').onchange({target:{value:'v2d'}}));step('cam',()=>{G('top').onclick();G('rst').onclick()});
step('picks',()=>{MapReading.pick(1000,1000);MapReading.pick(3500,3000);MapReading.pick(500,500);G('clr').onclick()});
for(const lv of['basic','intermediate','advanced','msce'])step('paper '+lv,()=>{G('ql').value=lv;G('qbtn').onclick();G('qg').onclick();G('qa').onchange();G('qpr').onclick()});
step('toolbar',()=>{G('tbt').onclick();G('tc').onchange({target:{value:'b'}})});
for(const id of Demo.IDS)step('demo '+id,()=>{G('dsel').value=id;G('dgo').onclick();for(let k=0;k<6;k++)G('dn').onclick();G('da').onclick();G('dp').onclick();G('dr').onclick();G('dnew').onclick();G('dx').onclick()});
step('draw tools',()=>{G('an').onpointerdown({clientX:300,clientY:300,pointerId:1});G('an').onpointermove({clientX:310,clientY:310});G('an').onpointerup();G('tu').onclick();G('tr').onclick();G('tcl').onclick();MapReading.loadAnnotations(MapReading.annotations())});
console.log(`smoke ok: ${n} page actions ran without errors`);
