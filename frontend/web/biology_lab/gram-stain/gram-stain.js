(function(){
  var NS="http://www.w3.org/2000/svg",WATER="rgba(205,230,245,.55)";
  var UN="#d8d2c4",UNS="#b9b2a2",P="#3b1a66";
  var cv={gp:"#6a2fa0",gn:"#6a2fa0",gs:"#4c1f78",sm:"#6a40c8"},io={gp:P,gn:P,gs:"#27114a",sm:"#3b2a7c"},
      de={gp:P,gn:"#ece8de",gs:"#c9c2b2",sm:"#c3b3ee"},sa={gp:P,gn:"#e0457b",gs:"#b32a5c",sm:"#7a3fae"};
  function S(n,t,d,time,k,r,c){return{n:n,t:t,d:d,time:time,k:k,r:r,c:c}}
  var stages=[
    S("Loop & smear","Flame the loop, add saline, smear and heat-fix","Hold the inoculating loop in the flame until it glows flame-coloured, then let it cool. Put two drops of normal saline on the clean slide, emulsify a little culture in them and spread a thin smear. Pass the slide horizontally over the flame three times to fix it, then let it dry out slowly.","Loop in the flame, 2 drops of saline, 3 passes over the flame, slow drying","flame",null,{gp:UN,gn:UN,gs:UNS,sm:"rgba(135,130,125,.5)"}),
    S("Crystal violet","Cover the smear with crystal violet","Add a few drops, just enough to cover the smear and a little beyond it. Every cell turns purple.","About 1 minute","stain","#6a2fa0",cv),
    S("Water rinse","Rinse with tap water","Wash off the crystal violet with a gentle stream of water, then tilt the slide to drain.","A few seconds","rinse",null,cv),
    S("Iodine","Cover with Gram’s iodine","Iodine is the mordant. It binds crystal violet inside the cell as a large complex.","About 1 minute","stain","#7a5a2a",io),
    S("Water rinse","Rinse with tap water","Wash off the iodine gently with water.","A few seconds","rinse",null,io),
    S("Decolorize","Decolorize with alcohol or acetone","The key step. Thick peptidoglycan in Gram-positive walls traps the dye. Gram-negative cells lose it and turn colourless. As it is applied the wet patch turns crystal-violet purple while the dye washes out, then the smear fades.","5–15 seconds, do not over-decolorize","stain","#cfe3ea",de),
    S("Water rinse","Rinse with water at once","Stop decolorizing immediately by rinsing with water.","A few seconds","rinse",null,de),
    S("Safranin","Counterstain with safranin","The red-pink counterstain colours the colourless Gram-negative cells. Gram-positive cells stay purple.","30–60 seconds","stain","#e0457b",sa),
    S("Water rinse","Final rinse with water","Wash off the safranin gently until the run-off turns colourless, then blot the slide.","A few seconds","rinse",null,sa),
    S("Warm","Warm the slide to dry it","Hold the slide gently above a flame or on a slide warmer until fully dry. Do not boil or burn it.","Until dry","flame",null,sa),
    S("Microscope","Read under oil immersion","Add immersion oil and view at 1000×. Gram-positive cocci appear as round, deep-purple cells in grape-like clusters, with thin Gram-negative rods stained pink among them. The field shows the Gram-stained background too, with crystal violet haze and a little safranin.","Use the 100× oil objective","none",null,sa)
  ];
  stages[5].ov="#6a2fa0";
  var cx=180,cy=290,R=64,cells=[],seed=7;
  function rnd(){seed=(seed*9301+49297)%233280;return seed/233280}
  var g=document.getElementById("cells");g.style.transformOrigin="180px 290px";g.style.transition="transform 1.4s ease,opacity 1.2s ease";
  function place(type,count){
    var tries=0;
    while(count>0&&tries<800){
      tries++;
      var a=rnd()*6.283,d=Math.sqrt(rnd())*(R-14),x=cx+Math.cos(a)*d,y=cy+Math.sin(a)*d,ok=true;
      for(var i=0;i<cells.length;i++){var dx=cells[i].x-x,dy=cells[i].y-y;if(dx*dx+dy*dy<340){ok=false;break}}
      if(!ok)continue;
      var el;
      if(type==="gp"){el=document.createElementNS(NS,"circle");el.setAttribute("cx",x);el.setAttribute("cy",y);el.setAttribute("r",3.8)}
      else{el=document.createElementNS(NS,"rect");el.setAttribute("x",x-9);el.setAttribute("y",y-1.8);el.setAttribute("width",18);el.setAttribute("height",3.6);el.setAttribute("rx",1.8);el.setAttribute("transform","rotate("+Math.round(rnd()*180)+" "+x+" "+y+")")}
      el.setAttribute("class","cell");el.setAttribute("fill",UN);el.setAttribute("stroke",UNS);el.setAttribute("stroke-width","1");
      g.appendChild(el);cells.push({x:x,y:y,el:el,type:type});count--;
    }
  }
  place("gp",16);place("gn",12);
  /* The first, drawn field of view has been removed for good: the sole field
     reference is the upgraded micrograph (#realPhoto) shown at the last stage.
     The #cells schematic above is the in-progress staining view, not a field
     reference. */

  var cur=0,timer=null,playing=false,tms=[],speed=1,runoff=document.getElementById("runoff");
  var overlay=document.getElementById("overlay"),drops=document.getElementById("drops"),
      flame=document.getElementById("flame"),slideG=document.getElementById("slideG"),armg=document.getElementById("armg"),spoutg=document.getElementById("spoutg"),stream=document.getElementById("stream"),wfilm=document.getElementById("wfilm"),
      label=document.getElementById("slideLabel"),stepsEl=document.getElementById("steps"),btns=[];
  var BL={cv:{x:26,l:["Crystal","violet"],c:"#6a2fa0",full:"Crystal violet",tip:37},
    io:{x:72,l:["Gram’s","iodine"],c:"#8a5a1f",full:"Gram’s iodine",tip:37},
    de:{x:118,l:["Alcohol","95%"],c:"#cfe3ea",full:"Decolorizer (95% alcohol)",tip:37},
    sa:{x:164,l:["Safranin",""],c:"#e0457b",full:"Safranin",tip:37},
    sl:{x:250,l:["Normal","saline"],c:"#cfe6f4",full:"Normal saline (0.85% NaCl)",tip:37}};
  var bottlesG=document.getElementById("bottles"),adding=document.getElementById("adding");
  Object.keys(BL).forEach(function(k){
    var b=BL[k],g2=document.createElementNS(NS,"g"),T='text-anchor="middle" font-size="6.8" font-family="Georgia,serif" fill="var(--ink)"';
    g2.innerHTML='<rect x="-17" y="-22" width="34" height="44" rx="8" fill="var(--panel)" stroke="var(--muted)" stroke-width="1.2"/>'
      +'<g clip-path="url(#bodyclip)"><rect class="bq" x="-15.5" y="-14" width="31" height="34" rx="6.5" fill="'+b.c+'" opacity=".85"/></g>'
      +'<rect x="-6" y="-27" width="12" height="6" rx="1.5" fill="var(--muted)"/>'
      +'<path d="M-3.4 -27L3.4 -27L1.5 -'+b.tip+'L-1.5 -'+b.tip+'Z" fill="var(--ink)" opacity=".8"/>'
      +'<rect x="-15.5" y="-10" width="31" height="20" rx="2" fill="var(--bg)" stroke="var(--line)"/>'
      +'<text y="-1.5" '+T+'>'+b.l[0]+'</text><text y="8" '+T+'>'+b.l[1]+'</text>'
      +'<line x1="-12.5" y1="-19" x2="-12.5" y2="-14" stroke="#fff" stroke-opacity=".5" stroke-width="2" stroke-linecap="round"/>';
    g2.insertAdjacentHTML("beforeend",'<g class="bn" style="opacity:0"><rect x="-4" y="-26.6" width="8" height="5" rx="1" fill="'+b.c+'"/><path d="M-2.3 -27L2.3 -27L.9 -'+(b.tip-1)+'L-.9 -'+(b.tip-1)+'Z" fill="'+b.c+'"/></g>');
    b.liq=g2.querySelector(".bq");b.neck=g2.querySelector(".bn");
    g2.style.transition="transform 1s ease-in-out";
    b.g=g2;b.dy=84-b.tip;bottlesG.appendChild(g2);
  });
  function slot(b){return "translate("+b.x+"px,48px) rotate(0deg)"}
  function resetBottles(){
    Object.keys(BL).forEach(function(k){var b=BL[k];b.g.style.transition="none";b.g.style.transform=slot(b);b.liq.style.transition="none";b.liq.style.transform="translateY(0px)";b.neck.style.transition="none";b.neck.style.opacity=0});
    void bottlesG.getBoundingClientRect();
    Object.keys(BL).forEach(function(k){BL[k].g.style.transition=""});
  }
  function pick(b){
    bottlesG.appendChild(b.g);void b.g.getBoundingClientRect();
    b.g.style.transition="transform "+(.3/speed)+"s ease-out";
    b.g.style.transform="translate("+b.x+"px,38px) rotate(0deg)";
    later(function(){b.g.style.transition="transform "+(.8/speed)+"s ease-in-out";b.g.style.transform="translate(208px,"+b.dy+"px) rotate(180deg)"},300);
    later(function(){b.liq.style.transition="transform "+(.7/speed)+"s ease-in";b.liq.style.transform="translateY(-16px)";b.neck.style.transition="opacity "+(.5/speed)+"s ease "+(.4/speed)+"s";b.neck.style.opacity=1},400);
  }
  function putBack(b){
    b.neck.style.transition="opacity "+(.2/speed)+"s ease";b.neck.style.opacity=0;b.liq.style.transition="transform "+(.7/speed)+"s ease-in-out";b.liq.style.transform="translateY(0px)";
    b.g.style.transition="transform "+(.6/speed)+"s ease-in-out";
    b.g.style.transform="translate("+b.x+"px,38px) rotate(0deg)";
    later(function(){b.g.style.transition="transform "+(.35/speed)+"s ease-in";b.g.style.transform=slot(b)},600);
  }
  resetBottles();
  stages.forEach(function(s,i){
    var b=document.createElement("button");b.textContent=(i+1)+". "+s.n;b.onclick=function(){pause();go(i)};
    stepsEl.appendChild(b);btns.push(b);
  });
  function clearT(){tms.forEach(clearTimeout);tms=[]}
  function later(f,ms){tms.push(setTimeout(f,ms/speed))}
  function paint(c){
    document.getElementById("smearc").setAttribute("fill",c.sm);
    cells.forEach(function(x){
      x.el.setAttribute("fill",x.type==="gp"?c.gp:c.gn);
      x.el.setAttribute("stroke",x.type==="gp"?(c.gp===UN?UNS:"#27114a"):c.gs);
    });
  }
  function dropAnim(color,N,gap,onLand,gdp){
    drops.innerHTML="";var t0=1250,gd=gdp||.12;
    for(var i=0;i<N;i++)(function(i){
      var x=208+((i%3)-1)*2.5,d;
      later(function(){
        d=document.createElementNS(NS,"ellipse");
        d.setAttribute("cx",x);d.setAttribute("cy",88.5);d.setAttribute("rx",3.4);d.setAttribute("ry",5.2);d.setAttribute("fill",color);d.setAttribute("class","drop");
        d.style.animation="grow "+(gd/speed)+"s ease-out forwards,fall "+(.34/speed)+"s cubic-bezier(.55,0,1,.45) "+(gd/speed)+"s forwards";
        drops.appendChild(d);
      },t0+i*gap);
      later(function(){
        if(d)d.remove();
        var rp=document.createElementNS(NS,"ellipse");
        rp.setAttribute("cx",x);rp.setAttribute("cy",143);rp.setAttribute("rx",6);rp.setAttribute("ry",2);rp.setAttribute("fill","none");rp.setAttribute("stroke",color);rp.setAttribute("stroke-width",1.2);rp.setAttribute("class","rip");
        drops.appendChild(rp);onLand(i);
      },t0+i*gap+(gd+.34)*1000);
    })(i);
    return t0+(N-1)*gap;
  }
  function tint(h,a){var n=parseInt(h.slice(1),16);return "rgba("+(n>>16)+","+((n>>8)&255)+","+(n&255)+","+a+")"}
  function splash(x,y,n,spread,fall,color,big){
    for(var i=0;i<n;i++){
      var c=document.createElementNS(NS,"circle");c.setAttribute("cx",x);c.setAttribute("cy",y);c.setAttribute("r",(.9+Math.random()*.7)*(big||1));c.setAttribute("fill",color);
      c.style.setProperty("--sx",((Math.random()*2-1)*spread+(spread>10?spread*.4:0))+"px");c.style.setProperty("--sy",(fall*(.6+Math.random()*.8))+"px");
      c.style.animation="spl "+(.6/speed)+"s ease-out forwards";drops.appendChild(c);
    }
  }
  function prevStain(i){for(var k=i-1;k>=0;k--)if(stages[k].k==="stain")return stages[k];return null}
  function go(i){
    clearT();cur=Math.max(0,Math.min(stages.length-1,i));
    var s=stages[cur];
    document.getElementById("title").textContent=s.t;
    document.getElementById("desc").textContent=s.d;
    document.getElementById("time").textContent=s.time;
    btns.forEach(function(b,k){b.setAttribute("aria-current",k===cur?"true":"false")});
    document.getElementById("prev").disabled=cur===0;
    document.getElementById("next").disabled=cur===stages.length-1;
    drops.innerHTML="";runoff.innerHTML="";label.textContent="Slide with bacterial smear";
    var last=cur===stages.length-1,rn=s.k==="rinse";
    g.style.transform=last?"scale(1.25)":"scale(1)";g.style.opacity=last?0:1;document.getElementById("fieldG").style.transform=last?"scale(1.22)":"scale(1)";document.getElementById("vig").setAttribute("opacity",0);document.getElementById("real").style.opacity=last?1:0;
    /* sole field: the upgraded micrograph (no drawn fallback exists anymore) */
    document.getElementById("realPhoto").style.opacity=last?1:0;
    document.getElementById("fieldLabel").textContent=last?"Field of view · 1000× oil · purple cocci, thin pink rods":"Microscope field";
    document.getElementById("bar").style.width=(cur/(stages.length-1)*100)+"%";
    document.getElementById("legend").className=last?"legend on":"legend";
    flame.style.opacity=1;
    var fy=document.getElementById("fy"),fo2=document.getElementById("fo"),fc2=document.getElementById("fc"),FL=document.getElementById("fl");
    function flameTo(sc,ms,op){FL.style.transition="transform "+(ms/1000/speed)+"s ease-in-out,opacity "+(ms/1000/speed)+"s ease-in-out";FL.style.transform="scale("+sc+")";FL.style.opacity=op}
    [fy,fo2,fc2].forEach(function(e){e.style.transition="none"});
    if(cur===0){fy.setAttribute("opacity",1);fo2.setAttribute("opacity",0);fc2.setAttribute("opacity",0);FL.style.transition="none";FL.style.transform="scale(.02)";FL.style.opacity=0}
    else{fy.setAttribute("opacity",.9);fo2.setAttribute("opacity",.85);fc2.setAttribute("opacity",1);if(FL.style.opacity===""||FL.style.opacity==="0"){FL.style.transition="none";FL.style.transform="scale(.02)";FL.style.opacity=0}}
    void fy.getBoundingClientRect();
    [fy,fo2,fc2].forEach(function(e){e.style.transition="opacity 1.8s ease"});
    if(cur===0){later(function(){flameTo(1,3000,1)},300);later(function(){fy.setAttribute("opacity",.9);fo2.setAttribute("opacity",.85);fc2.setAttribute("opacity",1)},1800)}
    else if(cur===9)flameTo(1,2200,1);
    else if(cur===stages.length-1){flameTo(1,200,1);later(function(){flameTo(.02,3500,0)},5000)}
    else flameTo(.28,1200,1);
    var lg=document.getElementById("loop"),lp=document.getElementById("lp"),lw=document.getElementById("lw2"),lgl=document.getElementById("lgl"),lcul=document.getElementById("lcul"),
        sm=document.getElementById("smearc"),scl=document.getElementById("smcl"),sal=document.getElementById("saline");
    function setL(c,o){lp.setAttribute("stroke",c);lw.setAttribute("stroke",c);lgl.setAttribute("fill",c);lgl.setAttribute("opacity",o)}
    lp.style.transition=lw.style.transition=lgl.style.transition="none";setL("#8d939c",0);void lp.getBoundingClientRect();lp.style.transition=lw.style.transition=lgl.style.transition="";
    lg.style.transition="none";lg.style.transform="translate(0px,0px)";lg.setAttribute("opacity",cur===0?1:0);lcul.setAttribute("opacity",0);void lg.getBoundingClientRect();
    if(cur===0){
      sm.setAttribute("opacity",0);sm.setAttribute("clip-path","url(#smc)");scl.setAttribute("rx",20);scl.setAttribute("ry",5);
      sal.style.transition="none";sal.setAttribute("opacity",0);sal.setAttribute("rx",6);sal.setAttribute("ry",2.4);sal.style.transform="scale(1)";sal.style.transformBox="fill-box";sal.style.transformOrigin="50% 50%";document.getElementById("wisps").setAttribute("opacity",0);void sal.getBoundingClientRect();sal.style.transition="";
      var DU=function(ms){return (ms/1000/speed)+"s"};
      later(function(){setL("#ff9a2a",.55)},1500);
      later(function(){setL("#ffc13a",.8)},3200);
      later(function(){lg.style.transition="transform "+DU(800)+" ease,opacity "+DU(500)+" ease";lg.style.transform="translate(-70px,0px)";lg.setAttribute("opacity",0)},4800);
      later(function(){setL("#8d939c",0)},5400);
      later(function(){
        var b1=BL.sl;pick(b1);adding.textContent="Adding: "+b1.full;
        var t1=dropAnim(WATER,2,600,function(i){sal.setAttribute("opacity",1);sal.setAttribute("rx",6+i*3.5);sal.setAttribute("ry",2.4+i*1.1)},.45);
        later(function(){putBack(b1)},t1+700);
        later(function(){adding.textContent=""},t1+1700);
      },5300);
      later(function(){
        lg.style.transition="none";lg.style.transform="translate(-70px,0px)";void lg.getBoundingClientRect();lcul.setAttribute("opacity",1);
        lg.style.transition="transform "+DU(800)+" ease,opacity "+DU(400)+" ease";lg.setAttribute("opacity",1);lg.style.transform="translate(0px,-64px)";
        adding.textContent="Smearing the culture in the saline";
      },8200);
      var pts=[[172,141],[232,146],[166,147],[238,141],[170,145],[234,142],[176,146],[214,143]],rxs=[22,36,48,58,66,72,77,80],rys=[5,9,13,16,18,20,21,22];
      pts.forEach(function(p,i){later(function(){
        lg.style.transition="transform "+DU(420)+" ease-in-out";lg.style.transform="translate("+(p[0]-200.5)+"px,"+(p[1]-207.5)+"px)";
        sm.setAttribute("opacity",1);scl.setAttribute("rx",rxs[i]);scl.setAttribute("ry",rys[i]);
        sal.setAttribute("rx",rxs[i]+4);sal.setAttribute("ry",rys[i]*.9+2);
      },9000+i*450)});
      later(function(){lg.style.transition="transform "+DU(800)+" ease,opacity "+DU(500)+" ease";lg.style.transform="translate(-70px,0px)";lg.setAttribute("opacity",0);adding.textContent=""},12700);
      later(function(){sm.removeAttribute("clip-path");sm.setAttribute("fill","rgba(110,104,98,.62)")},12900);
      later(function(){adding.textContent="Heat-fixing: passing the slide over the flame, three times"},13200);
      [[13300,-80,.7,1],[14100,80,1.4,.82],[15700,-80,1.4,.6],[17300,80,1.4,.38],[18900,0,.9,.38]].forEach(function(m){later(function(){
        slideG.style.transition="transform "+DU(m[2]*1000)+" ease-in-out";
        slideG.style.transform="translate("+m[1]+"px,"+(m[1]===0?0:6)+"px)";
        sal.style.transition="transform "+DU(m[2]*1000)+" ease,opacity 2s ease";sal.style.transform="scale("+m[3]+")";
      },m[0])});
      later(function(){document.getElementById("wisps").setAttribute("opacity",1)},14000);
      later(function(){
        sal.style.transition="transform "+DU(5000)+" ease-in,opacity "+DU(5000)+" ease-in";sal.style.transform="scale(.1)";sal.setAttribute("opacity",0);
        sm.setAttribute("fill","rgba(150,146,140,.42)");adding.textContent="Air-drying the smear";
      },19200);
      later(function(){document.getElementById("wisps").setAttribute("opacity",0);adding.textContent=""},23600);
    }else{sm.setAttribute("opacity",1);sm.removeAttribute("clip-path");sal.setAttribute("opacity",0)}
    var rm=cur>=8,cvO=cur<2?0:(cur<=4?.55:(cur<=7?.1:(last?.34:.26)));
    document.getElementById("residue").setAttribute("opacity",cur<2?0:(cur<=4?.28:(cur<=7?.05:(last?.2:.14))));
    document.getElementById("cvres").setAttribute("opacity",cvO);
    document.getElementById("cvres2").setAttribute("opacity",cvO*.85);
    document.getElementById("sares").setAttribute("opacity",rm?(last?.42:.3):0);
    document.getElementById("sares2").setAttribute("opacity",rm?(last?.36:.26):0);
    document.getElementById("viewring").setAttribute("opacity",last?1:0);
    resetBottles();document.getElementById("adding").textContent="";
    slideG.style.transition="none";slideG.style.transform="rotate(0deg)";armg.style.transition="none";armg.style.transform="scaleX(.2)";spoutg.style.transition="none";spoutg.style.transform="translateX(101px)";
    stream.setAttribute("opacity",0);document.getElementById("pour").setAttribute("opacity",0);wfilm.setAttribute("opacity",0);wfilm.setAttribute("fill","rgba(215,235,248,.28)");if(cur===0)document.getElementById("trayliq").setAttribute("opacity",0);void slideG.getBoundingClientRect();
    var before=cur>0?stages[cur-1].c:s.c;
    if(s.k==="stain"){
      paint(before);overlay.setAttribute("fill",s.r);overlay.setAttribute("opacity",0);
      overlay.style.transition="none";overlay.style.transform="scale(.22,.4)";void overlay.getBoundingClientRect();overlay.style.transition="";
      var bs=BL[({"Crystal violet":"cv","Iodine":"io","Decolorize":"de","Safranin":"sa"})[s.n]];
      pick(bs);adding.textContent="Adding: "+bs.full;
      var tl=dropAnim(s.r,22,110,function(i){overlay.setAttribute("fill",s.ov||s.r);overlay.setAttribute("opacity",.6);overlay.style.transform="scale("+(.22+.78*(i+1)/22)+","+(.4+.6*(i+1)/22)+")"});
      later(function(){putBack(bs)},tl+260);
      later(function(){paint(s.c)},tl+800);
      later(function(){adding.textContent=""},tl+1250);
    }else if(s.k==="rinse"){
      var ps=prevStain(cur);paint(s.c);
      overlay.setAttribute("fill",ps.ov||ps.r);overlay.setAttribute("opacity",.6);overlay.style.transition="none";overlay.style.transform="scale(1,1)";void overlay.getBoundingClientRect();overlay.style.transition="";
      var D=function(ms){return (ms/1000/speed)+"s"};
      adding.textContent="Rinsing with tap water";
      later(function(){armg.style.transition="transform "+D(700)+" ease-in-out";spoutg.style.transition="transform "+D(700)+" ease-in-out";armg.style.transform="scaleX(1)";spoutg.style.transform="translateX(0px)"},0);
      later(function(){slideG.style.transition="transform "+D(2000)+" ease-in-out";slideG.style.transform="rotate(10deg)"},200);
      later(function(){stream.setAttribute("opacity",1);wfilm.setAttribute("opacity",1)},2300);
      for(var k=0;k<17;k++)later(function(){
        var rp=document.createElementNS(NS,"ellipse");rp.setAttribute("cx",208);rp.setAttribute("cy",173);rp.setAttribute("rx",7);rp.setAttribute("ry",2.2);rp.setAttribute("fill","none");rp.setAttribute("stroke","#9cc3dc");rp.setAttribute("stroke-width",1.2);rp.setAttribute("class","rip");drops.appendChild(rp);
      },2400+k*220);
      later(function(){overlay.style.transition="opacity "+D(2200)+" ease,transform "+D(2400)+" ease-in";overlay.setAttribute("opacity",0);overlay.style.transform="translate(70px,6px) scale(1.15,.9)"},2500);
      var TINT=({"Crystal violet":"#6a2fa0","Iodine":"#8a5a1f","Decolorize":"#6a2fa0","Safranin":"#e0457b"})[ps.n]||"#6a2fa0",TL=document.getElementById("trayliq"),LR=ps.n==="Safranin";
      var pr=document.getElementById("pour");
      later(function(){[].forEach.call(pr.querySelectorAll(".pc"),function(e){e.setAttribute("stroke",tint(TINT,LR?.4:.6))});pr.setAttribute("opacity",1)},2500);
      later(function(){pr.setAttribute("opacity",0)},3600);
      for(var pk=0;pk<6;pk++)(function(pk){later(function(){
        [349,268,286,304].forEach(function(px,ix){
          if((pk+ix)%2)return;
          var rp=document.createElementNS(NS,"ellipse");rp.setAttribute("cx",px);rp.setAttribute("cy",299);rp.setAttribute("rx",6);rp.setAttribute("ry",1.8);rp.setAttribute("fill","none");rp.setAttribute("stroke",tint(TINT,.9));rp.setAttribute("stroke-width",1.2);rp.setAttribute("class","rip");drops.appendChild(rp);
          splash(px,299,2,9,3,tint(TINT,.8));
        });
      },2700+pk*180)})(pk);
      later(function(){wfilm.setAttribute("fill",tint(TINT,.3))},2300);
      later(function(){wfilm.setAttribute("fill","rgba(215,235,248,.28)")},LR?4600:5600);
      for(var k2=0;k2<17;k2++)(function(k2){later(function(){splash(208,173,3,14,5,k2<(LR?3:8)?tint(TINT,.8):"rgba(190,224,242,.9)")},2400+k2*220)})(k2);
      var NQ=28,NT=5;
      for(var sq=0;sq<16;sq++)(function(sq){later(function(){
        var f=sq%2===0,x=f?333+Math.random()*2:256+Math.random()*58,y=f?226+Math.random()*10:185.2+(x-31.1)*.1762;
        splash(x,y,3,f?26:14,f?30:18,tint(TINT,LR?.7:.9),1.8);
      },3300+sq*55)})(sq);
      for(var q=0;q<NQ+NT;q++)(function(q){
        var tail=q>=NQ,j=tail?q-NQ:q,fwd=q%2===0,x,y,dx,hang,
            fo=tail?0:(LR?Math.max(0,.65-j*.03):Math.max(.3,.85-j*.02)),cl=fo<.08,t0=tail?6200+j*220:3800+j*80;
        if(fwd){x=333+Math.random()*2;y=229+Math.random()*6;dx=8+Math.random()*9;hang=.22}
        else{x=256+Math.random()*58;y=185.2+(x-31.1)*.1762+1;dx=(Math.random()-.5)*5;hang=.5}
        var dist=299-y;
        later(function(){
          var d=document.createElementNS(NS,"ellipse");d.setAttribute("cx",x);d.setAttribute("cy",y);d.setAttribute("rx",3.1);d.setAttribute("ry",4.6);
          d.setAttribute("fill",cl?WATER:tint(TINT,fo));d.setAttribute("stroke",cl?"#9cc3dc":tint(TINT,Math.min(1,fo+.2)));d.setAttribute("stroke-width",.6);d.setAttribute("class","run");
          d.style.setProperty("--fd",dist+"px");d.style.setProperty("--dx",dx+"px");
          var fl=.55/speed,hg=hang/speed;
          d.style.animation="grow "+hg+"s ease-out forwards,fall2 "+fl+"s cubic-bezier(.55,0,1,.45) "+hg+"s forwards,driftx "+fl+"s linear "+hg+"s forwards";
          runoff.appendChild(d);
          if(fwd)splash(x,y,3,18,22,cl?"rgba(190,224,242,.9)":tint(TINT,.8));
        },t0);
        later(function(){
          var rp=document.createElementNS(NS,"ellipse");rp.setAttribute("cx",x+dx);rp.setAttribute("cy",299);rp.setAttribute("rx",5);rp.setAttribute("ry",1.6);rp.setAttribute("fill","none");rp.setAttribute("stroke",cl?"#9cc3dc":tint(TINT,.9));rp.setAttribute("stroke-width",1.1);rp.setAttribute("class","rip");drops.appendChild(rp);
          splash(x+dx,299,3,7,3,cl?"rgba(190,224,242,.9)":tint(TINT,.8));
          if(!cl){TL.setAttribute("fill",tint(TINT,1));TL.setAttribute("opacity",.55)}
        },t0+(hang+.55)*1000);
      })(q);
      later(function(){stream.setAttribute("opacity",0)},6200);
      later(function(){armg.style.transform="scaleX(.2)";spoutg.style.transform="translateX(101px)"},6300);
      later(function(){wfilm.setAttribute("opacity",0)},7300);
      later(function(){slideG.style.transition="transform "+D(1400)+" ease-in-out";slideG.style.transform="rotate(0deg)";adding.textContent=""},7600);
    }else{
      overlay.setAttribute("opacity",0);paint(s.c);
      if(s.k==="flame")label.textContent="";
      if(cur===0)flame.style.opacity=1;
    }
  }
  function pause(){playing=false;clearInterval(timer);document.getElementById("play").textContent=cur===stages.length-1?"Replay":"Play"}
  function play(){
    if(cur===stages.length-1)go(0);
    playing=true;document.getElementById("play").textContent="Pause";
    clearTimeout(timer);
    (function tick(){timer=setTimeout(function(){go(cur+1);if(cur===stages.length-1){pause();return}tick()},(cur===0?25500:10000)/speed)})();
  }
  document.getElementById("play").onclick=function(){playing?pause():play()};
  document.getElementById("next").onclick=function(){pause();go(cur+1)};
  document.getElementById("prev").onclick=function(){pause();go(cur-1)};
  document.getElementById("speed").onchange=function(){speed=+this.value;if(playing)play()};
  document.addEventListener("keydown",function(e){
    if(e.target.tagName==="SELECT")return;
    if(e.key==="ArrowRight"){pause();go(cur+1)}
    else if(e.key==="ArrowLeft"){pause();go(cur-1)}
  });
  var qs=/[?&]stage=(\d+)/.exec(location.search);
  /* ?instant=1 skips transitions/animations so a headless capture lands on the
     final state instead of catching a fade mid-flight */
  if(/[?&]instant=1/.test(location.search)){
    var xs=document.createElement("style");
    xs.textContent="*{transition:none!important;animation:none!important}";
    document.head.appendChild(xs);
  }
  go(qs?Math.max(0,Math.min(stages.length-1,+qs[1])):0);
})();
