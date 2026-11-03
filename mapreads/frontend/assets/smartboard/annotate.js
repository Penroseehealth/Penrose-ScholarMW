// Teacher annotation layer: vector items in ground coordinates (metres), so they survive resize, redraw and theme change.
(function(root,f){if(typeof module==='object')module.exports=f(require('./engine.js'));else root.Annot=f(root.MapEngine);})(this,function(M){
const COL={a:'#e0a000',r:'#d62828',b:'#1f6fbf',g:'#2a9d3a',k:'#111111'};
class Store{constructor(){this.items=[];this.redoStack=[]}
 add(it){this.items.push(it);this.redoStack=[];return it}
 undo(){const i=this.items.pop();if(i)this.redoStack.push(i);return!!i}
 redo(){const i=this.redoStack.pop();if(i)this.items.push(i);return!!i}
 clear(){this.items=[];this.redoStack=[]}
 toJSON(){return JSON.stringify(this.items)}load(s){this.items=JSON.parse(s);this.redoStack=[]}}
function label(x,s,px,py,c){x.font='bold 14px sans-serif';x.textAlign='left';x.lineWidth=4;x.strokeStyle='#fff';x.strokeText(s,px,py);x.fillStyle=c;x.fillText(s,px,py)}
function draw(x,items,P){const pp=p=>P(p[0],p[1]);x.save();x.lineCap='round';x.lineJoin='round';
 for(const it of items){const c=COL[it.c]||it.c||COL.r,T=it.t;x.strokeStyle=x.fillStyle=c;x.lineWidth=it.w||2.5;x.globalAlpha=1;
  if(T==='pen'||T==='hl'||T==='poly'){if(!it.pts||it.pts.length<2)continue;if(T==='hl'){x.globalAlpha=.35;x.lineWidth=14}else if(T==='poly')x.lineWidth=it.w||3.5;x.beginPath();it.pts.map(pp).forEach((q,i)=>i?x.lineTo(q[0],q[1]):x.moveTo(q[0],q[1]));if(it.closed)x.closePath();x.stroke()}
  else if(T==='line'||T==='arrow'||T==='dist'){const a=pp([it.a.x,it.a.y]),b=pp([it.b.x,it.b.y]);x.beginPath();x.moveTo(a[0],a[1]);x.lineTo(b[0],b[1]);x.stroke();
   if(T==='arrow'){const t=Math.atan2(b[1]-a[1],b[0]-a[0]);x.beginPath();x.moveTo(b[0],b[1]);x.lineTo(b[0]-13*Math.cos(t-.4),b[1]-13*Math.sin(t-.4));x.lineTo(b[0]-13*Math.cos(t+.4),b[1]-13*Math.sin(t+.4));x.closePath();x.fill()}
   if(T==='dist')label(x,`${Math.round(M.dist(it.a,it.b))} m · ${M.bearing(it.a,it.b)}°`,(a[0]+b[0])/2+6,(a[1]+b[1])/2-8,c)}
  else if(T==='mark'){const q=pp([it.x,it.y]);x.beginPath();x.arc(q[0],q[1],6,0,7);x.fill();if(it.s)label(x,it.s,q[0]+10,q[1]-8,c)}
  else if(T==='text')label(x,it.s,...pp([it.x,it.y]),c)}
 x.restore()}
return{Store,draw,COL}});
