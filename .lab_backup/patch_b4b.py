import io
p = r"frontend/web/biology_lab/index.html"
s = io.open(p, encoding='utf-8', newline='').read()
orig = len(s)

def rep(old, new, label=''):
    global s
    o = old.replace('\n', '\r\n'); n = new.replace('\n', '\r\n')
    assert s.count(o) >= 1, "ANCHOR NOT FOUND " + label + ": " + old[:100]
    s = s.replace(o, n, 1)

# --- B1: realistic glass (env-reflective standard material, not flat phong) ---
rep("  glass:new THREE.MeshPhongMaterial({color:0xe6f4fb,transparent:true,opacity:.18,shininess:150,specular:0xffffff,side:THREE.DoubleSide,depthWrite:false}),",
    "  glass:new THREE.MeshStandardMaterial({color:0xeaf6fb,roughness:.05,metalness:0,transparent:true,opacity:.22,envMapIntensity:1.3,side:THREE.DoubleSide,depthWrite:false}),", 'B1a')
rep("  winGlass:new THREE.MeshPhongMaterial({color:0xdff1fa,transparent:true,opacity:.16,shininess:140,specular:0xffffff,side:THREE.DoubleSide,depthWrite:false}),",
    "  winGlass:new THREE.MeshStandardMaterial({color:0xe4f3fb,roughness:.07,metalness:0,transparent:true,opacity:.17,envMapIntensity:1.1,side:THREE.DoubleSide,depthWrite:false}),", 'B1b')

# --- B2: physics + slosh registries; fx inside pickRoot so moved glass stays clickable ---
rep("var beakers=[],beakerN=0,shards=[],spills=[],shardGeo=new THREE.TetrahedronGeometry(.012,0);\nvar fx=new THREE.Group();scene.add(fx);",
r"""var beakers=[],beakerN=0,shards=[],spills=[],shardGeo=new THREE.TetrahedronGeometry(.012,0);
var falling=[],sloshE=0,sloshables=[],benchTops=[];
var fx=new THREE.Group();pickRoot.add(fx);""", 'B2')

# --- B3: beaker rebuild: double wall + rim (thickness), meniscus ring, home slot ---
rep(r"""function beaker(parent,x,z,col){
  var g=new THREE.Group();g.position.set(x,H,z);
  var hasWater=(beakerN++%2===0);
  var ref={group:g,col:col,water:hasWater,broken:false};
  var b=new THREE.Mesh(new THREE.CylinderGeometry(.04,.038,.1,16,1,true),M.glass);b.position.y=.05;g.add(b);
  var f=null;
  if(hasWater){
    f=new THREE.Mesh(new THREE.CylinderGeometry(.036,.036,.055,16),
      new THREE.MeshStandardMaterial({color:col,transparent:true,opacity:.7,roughness:.3}));
    f.position.y=.03;g.add(f);
  }
  ref.fill=f;
  contactShadow(g,0,.002,0,.2,.2);
  var hit=new THREE.Mesh(new THREE.CylinderGeometry(.055,.055,.12,10),M.hit);hit.position.y=.06;g.add(hit);
  b.userData.beakerRef=ref;hit.userData.beakerRef=ref;if(f)f.userData.beakerRef=ref;
  beakers.push(ref);
  parent.add(g);
}""",
r"""function beaker(parent,x,z,col){
  var g=new THREE.Group();g.position.set(x,H,z);
  var hasWater=(beakerN++%2===0);
  var ref={group:g,col:col,water:hasWater,broken:false,homeParent:parent,homePos:g.position.clone()};
  /* outer + inner wall and a rounded rim: real wall thickness reads at grazing angles */
  var b=new THREE.Mesh(new THREE.CylinderGeometry(.04,.038,.1,16,1,true),M.glass);b.position.y=.05;g.add(b);
  var bIn=new THREE.Mesh(new THREE.CylinderGeometry(.0375,.0355,.096,16,1,true),M.glass);bIn.position.y=.049;g.add(bIn);
  var rim=new THREE.Mesh(new THREE.TorusGeometry(.0388,.0016,8,20),M.glass);rim.rotation.x=Math.PI/2;rim.position.y=.1;g.add(rim);
  var f=null,mn=null;
  if(hasWater){
    f=new THREE.Mesh(new THREE.CylinderGeometry(.0355,.0345,.055,16),
      new THREE.MeshStandardMaterial({color:col,transparent:true,opacity:.7,roughness:.12,metalness:0,envMapIntensity:.9}));
    f.position.y=.03;g.add(f);
    /* meniscus: thin curved meniscus ring at the liquid surface */
    mn=new THREE.Mesh(new THREE.TorusGeometry(.0338,.0022,8,20),
      new THREE.MeshStandardMaterial({color:col,transparent:true,opacity:.85,roughness:.05}));
    mn.rotation.x=Math.PI/2;mn.position.y=.0572;f.add(mn);
    sloshables.push({mesh:f,base:0});
  }
  ref.fill=f;
  contactShadow(g,0,.002,0,.2,.2);
  var hit=new THREE.Mesh(new THREE.CylinderGeometry(.055,.055,.12,10),M.hit);hit.position.y=.06;g.add(hit);
  b.userData.beakerRef=ref;bIn.userData.beakerRef=ref;rim.userData.beakerRef=ref;
  hit.userData.beakerRef=ref;if(f)f.userData.beakerRef=ref;
  beakers.push(ref);
  parent.add(g);
}""", 'B3')

# --- B4: register bench top footprints for landing tests ---
rep(r"""  xs.forEach(function(hx,i){
    var s=makeSink();s.position.set(hx,H,0);
    if(alternate&&i%2)s.rotation.y=Math.PI;
    g.add(s);
  });
  return g;
}""",
r"""  xs.forEach(function(hx,i){
    var s=makeSink();s.position.set(hx,H,0);
    if(alternate&&i%2)s.rotation.y=Math.PI;
    g.add(s);
  });
  benchTops.push({node:g,w:w,d:d});
  return g;
}""", 'B4')

# --- B5: impact thud sound (before playDoorBang) ---
rep("/* door closing bang: broadband impact + heavy wooden thud + metal latch tick */",
r"""/* object impact: dull thud + short noise burst, scaled by drop speed and distance */
function playImpact(impact,pos){
  var ac=audioCtx();if(!ac)return;
  if(ac.state==='suspended'){try{ac.resume();}catch(e){}}
  var vol=clamp(impact/6,.05,1);
  if(pos){var d2=camera.position.distanceTo(pos);vol/= (1+d2*.3);}
  var out=ac.createGain();out.gain.value=masterVol*vol;out.connect(ac.destination);
  var t=ac.currentTime+.003;
  var src=ac.createBufferSource();src.buffer=audioNoise(ac);
  var lp=ac.createBiquadFilter();lp.type='lowpass';
  lp.frequency.setValueAtTime(900+impact*140,t);lp.frequency.exponentialRampToValueAtTime(200,t+.13);
  var g=ac.createGain();g.gain.setValueAtTime(.0005,t);g.gain.linearRampToValueAtTime(.7,t+.004);
  g.gain.exponentialRampToValueAtTime(.0004,t+.2);
  src.connect(lp);lp.connect(g);g.connect(out);src.start(t);src.stop(t+.24);
  thunk(ac,out,t,[110+impact*18,170+impact*22],[.35,.2],.3);
}
/* door closing bang: broadband impact + heavy wooden thud + metal latch tick */""", 'B5')

# --- B6: grab / drag / release controllers (before pointerdown listener) ---
rep(r"""function dragDrawerMove(dx,dy){
  var u=down.drawer.userData,ax=u.ax;
  var along=(dx*ax.x+dy*ax.y)/ax.len;                 /* pointer px along drawer axis */
  var meters=along/(ax.len*10);                       /* ax.len px == 0.1 m */
  u.ext=clamp(u.ext0+meters/(u.maxExt||.24),0,1);
}""",
r"""function dragDrawerMove(dx,dy){
  var u=down.drawer.userData,ax=u.ax;
  var along=(dx*ax.x+dy*ax.y)/ax.len;                 /* pointer px along drawer axis */
  var meters=along/(ax.len*10);                       /* ax.len px == 0.1 m */
  u.ext=clamp(u.ext0+meters/(u.maxExt||.24),0,1);
}

/* ObjectGrabController: lift glassware off the bench, carry it, throw or set it down */
function grabPointAt(x,y,planeY){
  var r=canvas.getBoundingClientRect();
  ndc.set(((x-r.left)/r.width)*2-1,-((y-r.top)/r.height)*2+1);
  raycaster.setFromCamera(ndc,camera);
  var pt=new THREE.Vector3();
  return raycaster.ray.intersectPlane(new THREE.Plane(new THREE.Vector3(0,1,0),-planeY),pt)?pt:null;
}
function startGrabBeaker(ref,x,y){
  var wp=new THREE.Vector3();ref.group.getWorldPosition(wp);
  for(var gi=falling.length-1;gi>=0;gi--)if(falling[gi].ref===ref)falling.splice(gi,1);
  if(ref.group.parent!==fx)fx.add(ref.group);
  ref.group.position.copy(wp);
  ref.grabY=wp.y;ref.grabbed=true;
  ref.vel=new THREE.Vector3();ref.lastP=wp.clone();ref.lastT=performance.now();
  sloshE=Math.min(1,sloshE+.5);
}
function dragGrabBeaker(x,y){
  var ref=down.beaker;if(!ref||!ref.grabbed)return;
  var pt=grabPointAt(x,y,ref.grabY);if(!pt)return;
  var now=performance.now(),dt2=Math.max(.008,(now-(ref.lastT||now))/1000);
  var nv=new THREE.Vector3().subVectors(pt,ref.lastP).divideScalar(dt2);
  if(nv.length()>8)nv.setLength(8);
  ref.vel.lerp(nv,.35);
  ref.lastP.copy(pt);ref.lastT=now;
  ref.group.position.x=pt.x;ref.group.position.z=pt.z;
  sloshE=Math.min(1.2,sloshE+nv.length()*dt2*.35);
}
function releaseGrabBeaker(ref){
  ref.grabbed=false;
  var v=ref.vel.clone().multiplyScalar(.55);
  falling.push({ref:ref,v:v,fall0:ref.group.position.y});
}""", 'B6')

# --- B7: pointerdown starts a beaker grab ---
rep(r"""  if(ptrs.size===1){down={t:performance.now(),moved:0,multi:false};
    var dh=firstHit(e.clientX,e.clientY);
    if(dh&&dh.object.userData.drawerRef){down.drawer=dh.object.userData.drawerRef;startDrawerDrag(down.drawer,e.clientX,e.clientY);}
  }""",
r"""  if(ptrs.size===1){down={t:performance.now(),moved:0,multi:false};
    var dh=firstHit(e.clientX,e.clientY);
    if(dh&&dh.object.userData.drawerRef){down.drawer=dh.object.userData.drawerRef;startDrawerDrag(down.drawer,e.clientX,e.clientY);}
    else if(dh&&dh.object.userData.beakerRef&&!dh.object.userData.beakerRef.broken&&!dh.object.userData.beakerRef.grabbed){
      down.beaker=dh.object.userData.beakerRef;startGrabBeaker(down.beaker,e.clientX,e.clientY);
    }
  }""", 'B7')

# --- B8: pointermove drags the grabbed beaker ---
rep("    if(down&&down.drawer){dragDrawerMove(dx,dy);}",
    "    if(down&&down.drawer){dragDrawerMove(dx,dy);}\n    else if(down&&down.beaker){dragGrabBeaker(e.clientX,e.clientY);}", 'B8')

# --- B9: pointerup: tap breaks, drag-and-release throws with physics ---
rep(r"""    if(down.drawer){
      down.drawer.userData.dragging=false;
      down.drawer.userData.open=down.drawer.userData.ext>.4;
      if(down.moved>8)playDrawer();
      down.drawer=null;down=null;return;
    }""",
r"""    if(down.drawer){
      down.drawer.userData.dragging=false;
      down.drawer.userData.open=down.drawer.userData.ext>.4;
      if(down.moved>8)playDrawer();
      down.drawer=null;down=null;return;
    }
    if(down.beaker){
      var br=down.beaker;down.beaker=null;
      if(down.moved<8&&performance.now()-down.t<450){br.grabbed=false;breakBeaker(br);}
      else releaseGrabBeaker(br);
      down=null;return;
    }""", 'B9')

# --- B10: frame loop: falling glassware + liquid slosh settle ---
rep(r"""  for(var pi=spills.length-1;pi>=0;pi--){
    var sp3=spills[pi];sp3.life+=dt;
    sp3.m.scale.setScalar(1+sp3.life*.5);
    sp3.m.material.opacity=Math.max(0,.6-sp3.life*.22);
    if(sp3.m.material.opacity<=0){fx.remove(sp3.m);sp3.m.material.dispose();spills.splice(pi,1);}
  }""",
r"""  for(var pi=spills.length-1;pi>=0;pi--){
    var sp3=spills[pi];sp3.life+=dt;
    sp3.m.scale.setScalar(1+sp3.life*.5);
    sp3.m.material.opacity=Math.max(0,.6-sp3.life*.22);
    if(sp3.m.material.opacity<=0){fx.remove(sp3.m);sp3.m.material.dispose();spills.splice(pi,1);}
  }
  /* GlasswarePhysics: thrown/carried vessels fall under gravity and land on
     bench tops or the floor; hard impacts shatter them (spilling any liquid) */
  for(var fbi=falling.length-1;fbi>=0;fbi--){
    var fb=falling[fbi];
    if(fb.ref.broken||fb.ref.grabbed){falling.splice(fbi,1);continue;}
    var rg=fb.ref.group;
    fb.v.y-=9.8*dt;
    rg.position.addScaledVector(fb.v,dt);
    var restY=.004;
    for(var bti=0;bti<benchTops.length;bti++){
      var bt=benchTops[bti];
      var lw=bt.node.worldToLocal(new THREE.Vector3(rg.position.x,0,rg.position.z));
      if(Math.abs(lw.x)<bt.w/2+.03&&Math.abs(lw.z)<bt.d/2+.03)restY=Math.max(restY,H+.004);
    }
    if(rg.position.y<=restY){
      rg.position.y=restY;
      var impact=Math.abs(fb.v.y);
      falling.splice(fbi,1);
      if(impact>3.0||fb.fall0-restY>.55)breakBeaker(fb.ref);
      else{playImpact(impact,rg.position);sloshE=Math.min(1.2,sloshE+impact*.12);}
    }
  }
  /* LiquidSloshController: surfaces ripple after carrying/dropping, then settle */
  if(sloshE>.001){
    sloshE*=Math.pow(.03,dt);
    sloshables.forEach(function(sl,i){
      sl.mesh.rotation.z=Math.sin(time*13+i)*.09*sloshE;
      sl.mesh.rotation.x=Math.cos(time*11+i*1.7)*.07*sloshE;
    });
  }""", 'B10')

# --- B11: reset button for broken/thrown glassware ---
rep("    <button id=\"alloff\">Turn taps off</button>",
    "    <button id=\"alloff\">Turn taps off</button>\n    <button id=\"glassreset\">Replace broken glassware</button>", 'B11')
rep(r"""document.getElementById('alloff').addEventListener('click',function(){
  taps.forEach(function(t){t.target=0;});updateStatus();
});""",
r"""document.getElementById('alloff').addEventListener('click',function(){
  taps.forEach(function(t){t.target=0;});updateStatus();
});
document.getElementById('glassreset').addEventListener('click',function(){
  for(var ri=shards.length-1;ri>=0;ri--){fx.remove(shards[ri].m);shards[ri].mat.dispose();shards.splice(ri,1);}
  for(var rj=spills.length-1;rj>=0;rj--){fx.remove(spills[rj].m);spills[rj].m.material.dispose();spills.splice(rj,1);}
  falling.length=0;sloshE=0;
  beakers.forEach(function(ref){
    ref.broken=false;ref.grabbed=false;ref.group.visible=true;
    ref.group.rotation.set(0,0,0);
    if(ref.homeParent){ref.homeParent.add(ref.group);ref.group.position.copy(ref.homePos);}
  });
});""", 'B11b')

# --- B12: shards + spills must not intercept pointer picks ---
rep("    fx.add(m);\n    shards.push({m:m,mat:mat,",
    "    m.userData.noPick=1;fx.add(m);\n    shards.push({m:m,mat:mat,", 'B12a')
rep("    sp.rotation.x=-Math.PI/2;sp.position.set(wp.x,restY+.001,wp.z);fx.add(sp);",
    "    sp.rotation.x=-Math.PI/2;sp.position.set(wp.x,restY+.001,wp.z);sp.userData.noPick=1;fx.add(sp);", 'B12b')
rep("    if(!visibleDeep(o))continue;",
    "    if(!visibleDeep(o)||u.noPick)continue;", 'B12c')

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print("BATCH 4B OK;", orig, "->", len(s))
