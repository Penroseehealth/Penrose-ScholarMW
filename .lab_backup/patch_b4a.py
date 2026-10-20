import io
p = r"frontend/web/biology_lab/index.html"
s = io.open(p, encoding='utf-8', newline='').read()
orig = len(s)

def rep(old, new, label=''):
    global s
    o = old.replace('\n', '\r\n'); n = new.replace('\n', '\r\n')
    assert s.count(o) >= 1, "ANCHOR NOT FOUND " + label + ": " + old[:100]
    s = s.replace(o, n, 1)

# --- A1: stools become shiny stainless steel (metal + env reflections) ---
rep("  stool:new THREE.MeshPhongMaterial({color:0xc7cdd3,specular:0xffffff,shininess:320}),",
    "  stool:new THREE.MeshStandardMaterial({color:0xbfc6cc,metalness:1,roughness:.22,envMapIntensity:1.15}),", 'A1')

# --- A2: curtains state array ---
rep("var taps=[],doors=[],fans=[],ceilFans=[],microscopes=[],whiteMicroscopes=[],renderedMicroscopes=[],drawers=[],cabDrawers=[],windows=[],glowHide=[];",
    "var taps=[],doors=[],fans=[],ceilFans=[],microscopes=[],whiteMicroscopes=[],renderedMicroscopes=[],drawers=[],cabDrawers=[],windows=[],glowHide=[],curtains=[];", 'A2')

# --- A3: lab coats (three per side wall) + framed picture anchor ---
rep("/* ---------- framed wall picture (user-provided image) ---------- */",
r"""/* ---------- LabCoatStation: three coats on each side wall ---------- */
var coatSway=[];   /* {m,phase,amp} lightweight fabric sway driven by the fans */
function makeLabCoat(){
  var g=new THREE.Group();
  var fabric=new THREE.MeshStandardMaterial({color:0xf4f5f2,roughness:.92,metalness:0});
  var fabricB=new THREE.MeshStandardMaterial({color:0xeceee9,roughness:.95,metalness:0});
  /* torso: stacked slabs with alternating offsets simulating drape folds */
  var bodyH=.62,bodyW=.34;
  for(var i=0;i<5;i++){
    var fw=bodyW*(1-.05*Math.abs(i-2));
    box(fw,bodyH/5+.004,.13,fabric,(i-2)*.012,-.06-bodyH/10-i*bodyH/5,0,g,true);
  }
  /* collar + lapels */
  box(.1,.05,.14,fabricB,0,.015,0,g,true);
  [-1,1].forEach(function(sd){
    var lap=box(.07,.16,.02,fabricB,sd*.05,-.06,.07,g,true);lap.rotation.z=sd*.35;
    /* sleeve: two angled segments per side */
    var up=box(.075,.2,.11,fabric,sd*(bodyW/2+.02),-.08,0,g,true);up.rotation.z=sd*.18;
    var lo=box(.065,.24,.1,fabric,sd*(bodyW/2+.055),-.28,.005,g,true);lo.rotation.z=sd*.07;
  });
  /* buttons + pen pocket with pen */
  for(var b2=0;b2<4;b2++){
    var bt=new THREE.Mesh(new THREE.CylinderGeometry(.006,.006,.004,8),new THREE.MeshStandardMaterial({color:0xdadad2,roughness:.5}));
    bt.rotation.x=Math.PI/2;bt.position.set(.01,-.1-b2*.12,.068);g.add(bt);
  }
  box(.05,.09,.01,fabricB,-.1,-.14,.066,g,true);
  box(.006,.07,.006,new THREE.MeshStandardMaterial({color:0x2c6fbb,roughness:.4}),-.1,-.1,.072,g,true);
  return g;
}
function makeCoatRail(x,z,ry){
  /* wall-mounted rail with three hooks and three coats, evenly spaced */
  var g=new THREE.Group();g.position.set(x,0,z);g.rotation.y=ry||0;
  var railY=1.2,span=1.5;
  [-1,1].forEach(function(sd){
    var pt=new THREE.Mesh(new THREE.CylinderGeometry(.012,.012,.07,10),M.chrome);
    pt.rotation.x=Math.PI/2;pt.position.set(sd*span/2,railY,-.035);g.add(pt);
  });
  var rail=new THREE.Mesh(new THREE.CylinderGeometry(.014,.014,span+.08,12),M.chrome);
  rail.rotation.z=Math.PI/2;rail.position.set(0,railY,-.07);rail.castShadow=true;g.add(rail);
  [-.5,0,.5].forEach(function(hx,i){
    var hook=new THREE.Mesh(new THREE.TorusGeometry(.022,.005,6,12,Math.PI),M.chrome);
    hook.position.set(hx,railY-.02,-.055);hook.rotation.x=Math.PI/2;g.add(hook);
    var coat=makeLabCoat();
    coat.position.set(hx,railY-.035,-.075);
    coat.rotation.y=(i-1)*.08;
    coat.scale.setScalar(.97+.02*((i+1)%2));
    g.add(coat);
    coatSway.push({m:coat,phase:i*2.1+x*.7,amp:.012+.004*i});
  });
  pickRoot.add(g);return g;
}
/* three coats on the windowed left wall (clear of the glazing, below the sills)
   and three on the solid right wall */
makeCoatRail(-HX+.12,-2.25,Math.PI/2);
makeCoatRail(-HX+.12,.05,Math.PI/2);
makeCoatRail(-HX+.12,2.35,Math.PI/2);
makeCoatRail(HX-.12,-2.6,-Math.PI/2);
makeCoatRail(HX-.12,-.2,-Math.PI/2);
makeCoatRail(HX-.12,2.2,-Math.PI/2);

/* ---------- framed wall picture (user-provided image) ---------- */""", 'A3')

# --- A4: roll-up curtain inside addWindow (replaces the static blind) ---
rep(r"""  var bh=h*.28;
  box(w-.12,bh,.012,M.blind,u,y1-.07-bh/2,-.035,g,true);
  box(w-.12,.03,.02,M.steel,u,y1-.07-bh,-.04,g,true);
  var roll=cyl(.022,.022,w-.12,M.steel,u,y1-.065,-.045,g,10);roll.rotation.z=Math.PI/2;""",
r"""  /* roll-up curtain: fabric on a top roller; retracts upward when clicked */
  (function(){
    var cw=w-.14,chFull=h-.16;
    var fabTex=canvasTex(64,128,function(x2,w2,h2){
      var grd=x2.createLinearGradient(0,0,w2,0);
      grd.addColorStop(0,'#5f7d78');grd.addColorStop(.18,'#79968f');grd.addColorStop(.36,'#5f7d78');
      grd.addColorStop(.54,'#7d9a93');grd.addColorStop(.72,'#5f7d78');grd.addColorStop(.9,'#79968f');
      grd.addColorStop(1,'#5f7d78');
      x2.fillStyle=grd;x2.fillRect(0,0,w2,h2);
      x2.fillStyle='rgba(255,255,255,.16)';x2.fillRect(0,0,w2,6);
    });
    var fabMat=new THREE.MeshStandardMaterial({map:fabTex,roughness:.94,metalness:0,side:THREE.DoubleSide});
    var fabGeo=new THREE.PlaneGeometry(cw,chFull,12,1);
    fabGeo.translate(0,-chFull/2,0);   /* anchor at the top edge */
    var fab=new THREE.Mesh(fabGeo,fabMat);
    fab.castShadow=true;fab.receiveShadow=true;
    var cg=new THREE.Group();cg.position.set(u,y1-.085,-.045);cg.add(fab);
    g.add(cg);
    var rollM=cyl(.024,.024,cw+.04,M.steel,u,y1-.07,-.048,g,12);rollM.rotation.z=Math.PI/2;
    var hem=new THREE.Mesh(new THREE.BoxGeometry(cw+.01,.022,.02),M.steel);
    hem.position.set(0,-chFull,0);cg.add(hem);
    var cord=new THREE.Mesh(new THREE.CylinderGeometry(.003,.003,.55,6),M.dark);
    cord.position.set(cw/2+.03,-.3,.01);cg.add(cord);
    var knob=new THREE.Mesh(new THREE.SphereGeometry(.016,10,8),M.steel);
    knob.position.set(cw/2+.03,-.58,.01);cg.add(knob);
    var ref={grp:cg,fab:fab,hem:hem,cord:cord,knob:knob,open:.35,target:.35,full:chFull,roller:rollM};
    /* hit plane covers only the lower part of the sash so the window above stays clickable */
    var hitH=chFull*.55;
    var hit=new THREE.Mesh(new THREE.PlaneGeometry(cw+.02,hitH),M.hit);
    hit.position.set(u,y1-.085-chFull+hitH/2,-.05);hit.rotation.y=Math.PI;
    hit.userData.curtainRef=ref;g.add(hit);ref.hit=hit;
    curtains.push(ref);
  })();""", 'A4')

# --- A5: playCurtain swish sound (after playDrawer) ---
rep("  thunk(ac,out,t+.02,[95,140],[0.28,0.16],0.34);\n}",
r"""  thunk(ac,out,t+.02,[95,140],[0.28,0.16],0.34);
}
/* curtain: fabric swish (rising bandpass noise) + hem knock when it settles */
function playCurtain(){
  var ac=audioCtx();if(!ac)return;
  if(ac.state==='suspended'){try{ac.resume();}catch(e){}}
  var out=ac.createGain();out.gain.value=masterVol*.5;out.connect(ac.destination);
  var t=ac.currentTime+.005;
  var src=ac.createBufferSource();src.buffer=audioNoise(ac);
  var bp=ac.createBiquadFilter();bp.type='bandpass';bp.Q.value=.8;
  bp.frequency.setValueAtTime(320,t);bp.frequency.exponentialRampToValueAtTime(1400,t+.45);
  var g=ac.createGain();g.gain.setValueAtTime(.0004,t);g.gain.linearRampToValueAtTime(.16,t+.05);g.gain.exponentialRampToValueAtTime(.0004,t+.5);
  src.connect(bp);bp.connect(g);g.connect(out);src.start(t);src.stop(t+.55);
  tick(ac,out,t+.42,{freq:900,q:1.2,amp:.1,dur:.05});
}""", 'A5')

# --- A6: curtain click toggles ---
rep("        else if(u.drawerRef){u.drawerRef.userData.open=!u.drawerRef.userData.open;playDrawer();}",
r"""        else if(u.drawerRef){u.drawerRef.userData.open=!u.drawerRef.userData.open;playDrawer();}
        else if(u.curtainRef){u.curtainRef.target=u.curtainRef.target>.5?0:1;playCurtain();}""", 'A6')

# --- A7: hover cursor + tooltip ---
rep("  canvas.style.cursor=(u.tapRef||u.beakerRef||u.doorRef||u.windowRef||u.drawerRef)?'pointer':'grab';",
    "  canvas.style.cursor=(u.tapRef||u.beakerRef||u.doorRef||u.windowRef||u.drawerRef||u.curtainRef)?'pointer':'grab';", 'A7')
rep("  canvas.title=u.beakerRef?'Tap to break the beaker':(u.doorRef?(u.doorRef.target>.5?'Click to close door':'Click to open door'):(u.windowRef?(u.windowRef.target>.5?'Click to close window':'Click to open window'):(u.drawerRef?'Pull the handle to open the drawer':'')));",
    "  canvas.title=u.beakerRef?'Drag to move; throw off the bench to break it':(u.doorRef?(u.doorRef.target>.5?'Click to close door':'Click to open door'):(u.windowRef?(u.windowRef.target>.5?'Click to close window':'Click to open window'):(u.curtainRef?(u.curtainRef.target>.5?'Click to roll the curtain up':'Click to unroll the curtain'):(u.drawerRef?'Pull the handle to open the drawer':''))));", 'A7b')

# --- A8: firstHit lets curtain hit planes through the winGlass filter ---
rep("    if(o.material===M.winGlass&&!u.doorRef&&!u.tapRef&&!u.drawerRef)continue;",
    "    if(o.material===M.winGlass&&!u.doorRef&&!u.tapRef&&!u.drawerRef&&!u.curtainRef)continue;", 'A8')

# --- A9: frame loop: curtain roll animation + daylight link + coat sway ---
rep(r"""  windows.forEach(function(wd){
    wd.open+=(wd.target-wd.open)*Math.min(1,dt*3.5);
    wd.pivot.rotation.y=-wd.open*1.9;
  });""",
r"""  windows.forEach(function(wd){
    wd.open+=(wd.target-wd.open)*Math.min(1,dt*3.5);
    wd.pivot.rotation.y=-wd.open*1.9;
  });
  /* CurtainRollController: fabric retracts towards the roller; hem + cord follow */
  var dayBoost=0;
  curtains.forEach(function(c){
    c.open+=(c.target-c.open)*Math.min(1,dt*2.2);
    var e=c.open<.5?2*c.open*c.open:1-Math.pow(-2*c.open+2,2)/2;   /* easeInOut */
    var len=c.full*(1-.94*e);
    c.fab.scale.y=Math.max(.06,len/c.full);
    c.hem.position.y=-len;
    c.cord.position.y=-.3-e*.05;c.knob.position.y=-.58-e*.05;
    var bulge=1+e*1.6;      /* rolled fabric bulge on the roller */
    c.roller.scale.x=bulge;c.roller.scale.z=bulge;
    dayBoost+=c.open;
  });
  if(curtains.length){
    dayBoost/=curtains.length;
    windowLight.intensity=(lightsOn?(CONFIG.windowDaylight+.55*dayBoost):0.3)*LIGHT_BOOST;
  }
  /* lightweight coat sway: fabric moves with the ceiling fans */
  coatSway.forEach(function(cs){
    cs.m.rotation.z=Math.sin(time*1.4+cs.phase)*cs.amp*fanSpeed;
    cs.m.rotation.x=Math.sin(time*1.1+cs.phase*1.7)*cs.amp*.6*fanSpeed;
  });""", 'A9')

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print("BATCH 4A OK;", orig, "->", len(s))
