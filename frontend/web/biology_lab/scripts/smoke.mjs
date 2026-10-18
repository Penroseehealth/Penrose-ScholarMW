/**
 * Headless smoke / regression test for the Bio Lab scene.
 *
 * Boots the static server, loads the scene with ?diag=1 in headless Edge/Chrome, waits for the
 * diagnostics report to be emitted, then asserts the scene meets the enhancement acceptance
 * criteria: an enclosed, contrasty indoor scene, one microscope per bench beside its tap, and
 * water streams that originate at the tap outlet and terminate inside the sink basin.
 *
 * Exits non-zero on any failure so it can gate a release. Override the browser with EDGE_PATH.
 */

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const PORT = Number(process.env.SMOKE_PORT ?? 7469);
const DIAG_URL = `http://127.0.0.1:${PORT}/?diag=1`;
const NAVTEST_URL = `http://127.0.0.1:${PORT}/?navtest=1`;
const BEHAVTEST_URL = `http://127.0.0.1:${PORT}/?behavtest=1`;
const STUDENTTEST_URL = `http://127.0.0.1:${PORT}/?studenttest=1`;
const LESSONTEST_URL = `http://127.0.0.1:${PORT}/?lessontest=1`;
const ENVTEST_URL = `http://127.0.0.1:${PORT}/?envtest=1`;
const CAMTEST_URL = `http://127.0.0.1:${PORT}/?camtest=1`;
const MOVTEST_URL = `http://127.0.0.1:${PORT}/?movtest=1`;
const EVTEST_URL = `http://127.0.0.1:${PORT}/?evtest=1`;
const MICROTEST_URL = `http://127.0.0.1:${PORT}/?microtest=1`;
const CONSISTTEST_URL = `http://127.0.0.1:${PORT}/?consisttest=1`;
const MODELTEST_URL = `http://127.0.0.1:${PORT}/?modeltest=1`;
const VIRTUAL_TIME_BUDGET = process.env.SMOKE_VTIME ?? "300000";
const NAVTEST_VTIME_BUDGET = process.env.SMOKE_NAVTEST_VTIME ?? "600000";
const BEHAVTEST_VTIME_BUDGET = process.env.SMOKE_BEHAVTEST_VTIME ?? "900000";
const STUDENTTEST_VTIME_BUDGET = process.env.SMOKE_STUDENTTEST_VTIME ?? "300000";
const LESSONTEST_VTIME_BUDGET = process.env.SMOKE_LESSONTEST_VTIME ?? "600000";
const ENVTEST_VTIME_BUDGET = process.env.SMOKE_ENVTEST_VTIME ?? "300000";
const CAMTEST_VTIME_BUDGET = process.env.SMOKE_CAMTEST_VTIME ?? "300000";
const MOVTEST_VTIME_BUDGET = process.env.SMOKE_MOVTEST_VTIME ?? "600000";
const EVTEST_VTIME_BUDGET = process.env.SMOKE_EVTEST_VTIME ?? "900000";
const MICROTEST_VTIME_BUDGET = process.env.SMOKE_MICROTEST_VTIME ?? "600000";
const CONSISTTEST_VTIME_BUDGET = process.env.SMOKE_CONSISTTEST_VTIME ?? "300000";
const MODELTEST_VTIME_BUDGET = process.env.SMOKE_MODELTEST_VTIME ?? "600000";
const KIDNEYTEST_URL = `http://127.0.0.1:${PORT}/?kidneytest=1`;
const KIDNEYTEST_VTIME_BUDGET = process.env.SMOKE_KIDNEYTEST_VTIME ?? "600000";

function findBrowser() {
  const candidates = [
    process.env.EDGE_PATH,
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
    "/usr/bin/microsoft-edge",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ];
  return candidates.find((candidate) => candidate && existsSync(candidate)) ?? null;
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitForServer(url, timeoutMs = 10000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return true;
    } catch {
      // not up yet
    }
    await wait(200);
  }
  return false;
}

const RUN_TIMEOUT_MS = Number(process.env.SMOKE_ATTEMPT_TIMEOUT ?? 420000);

function run(command, args, options = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "ignore"], ...options });
    let stdout = "";
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      try { child.kill(); } catch { /* already gone */ }
      resolve({ code: "timeout", stdout: "" });
    }, RUN_TIMEOUT_MS);
    child.stdout.on("data", (chunk) => (stdout += chunk.toString()));
    child.on("error", (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ code: -1, stdout: "", error: String(error && error.message) });
    });
    child.on("close", (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ code, stdout });
    });
  });
}

const BROWSER_ARGS = [
  "--headless",
  "--disable-gpu",
  "--enable-unsafe-swiftshader",
  "--use-gl=angle",
  "--use-angle=swiftshader",
  "--no-sandbox",
  "--no-first-run",
];

/**
 * Launch one headless pass and dump its DOM, retrying while the READY title is
 * missing: repeated swiftshader launches occasionally flake under system load
 * (crash / budget expiry before the harness dispatches) and must not fail a run
 * whose harness is deterministic.
 */
async function dumpDom(browser, url, budget, profilePrefix, titleRe, label) {
  let dom = "";
  for (let attempt = 1; attempt <= 3; attempt++) {
    const profile = await mkdtemp(join(tmpdir(), profilePrefix));
    const { code, stdout } = await run(browser, [
      ...BROWSER_ARGS,
      `--user-data-dir=${profile}`,
      `--virtual-time-budget=${budget}`,
      "--dump-dom",
      url,
    ]);
    dom = stdout;
    const title = (dom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    if (titleRe.test(title)) return dom;
    console.warn(
      `smoke: ${label} attempt ${attempt}/3 not ready (exit=${code}, title="${title}")`,
    );
  }
  return dom;
}

const checks = [];
const check = (name, ok, detail) => checks.push({ name, ok: Boolean(ok), detail });

function decodeEntities(text) {
  return text
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'");
}

async function main() {
  console.log("smoke: starting dev server");
  const server = spawn(process.execPath, ["serve.mjs"], {
    cwd: ROOT,
    env: { ...process.env, PORT: String(PORT) },
    stdio: "ignore",
  });

  let report = null;
  try {
    if (!(await waitForServer(`http://127.0.0.1:${PORT}/`))) {
      console.error("smoke: dev server did not start");
      process.exit(2);
    }

    const browser = findBrowser();
    if (!browser) {
      console.error("smoke: no headless browser found (set EDGE_PATH)");
      process.exit(2);
    }

    console.log("smoke: diag pass");
    const dom = await dumpDom(browser, DIAG_URL, VIRTUAL_TIME_BUDGET, "biolab-smoke-", /DIAGREADY/, "diag");

    const title = (dom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("scene loaded (diag ready)", /DIAGREADY/.test(title));
    check("webgl canvas present", /<canvas/.test(dom));
    check("back view button present", /data-view="back"/.test(dom));

    const m = dom.match(/<pre id="__diag"[^>]*>([\s\S]*?)<\/pre>/);
    if (m) {
      try {
        report = JSON.parse(decodeEntities(m[1]));
      } catch (error) {
        console.error("smoke: could not parse diagnostics JSON:", error.message);
      }
    }
    check("diagnostics report emitted", report !== null);

    if (report) {
      const c = report.counts || {};
      const px = report.pixels || {};
      const micros = report.microscopes || [];
      const rendered = report.renderedMicroscopes || [];
      const white = report.whiteMicroscopes || [];
      const teacher = report.teacher || {};
      const taps = report.taps || [];

      check("no runtime errors", (report.errors || []).length === 0);
      check("at least one bench", c.benches >= 1);
      check("one microscope per bench", c.microscopes === c.benches);
      check(
        "every bench has a microscope",
        Object.keys(c.microsPerBench || {}).length === c.benches &&
          Object.values(c.microsPerBench || {}).every((n) => n >= 1),
      );
      check("taps present", c.taps >= 8);
      check("some taps running and some off", c.running >= 1 && c.running < c.taps);
      check("all tap nozzles sit inside a sink", taps.every((t) => t.nozzleInsideSink));
      check("all water streams end inside the basin", taps.every((t) => t.streamEndsInBasin));
      check("no microscope overlaps a sink", micros.every((mm) => !mm.overlapSink));
      check(
        "microscopes are fully modelled (many parts each)",
        micros.every((mm) => mm.parts >= 20),
      );
      check(
        "no rendered white microscope duplicate (one procedural binocular scope per bench)",
        c.renderedMicroscopes === 0,
      );
      check(
        "white reference microscope alongside on every bench",
        c.whiteMicroscopes === c.benches &&
          Object.keys(c.whiteMicrosPerBench || {}).length === c.benches &&
          Object.values(c.whiteMicrosPerBench || {}).every((n) => n >= 1),
      );
      check(
        "white microscopes are fully modelled (many parts each)",
        white.length === c.benches && white.every((mm) => mm.parts >= 20),
      );
      check(
        "no white microscope overlaps a sink",
        white.every((mm) => !mm.overlapSink && typeof mm.gapToSink === "number" && mm.gapToSink > 0.03),
      );
      const bsc = report.bsc || {};
      check(
        "biosafety cabinet present at the back wall",
        c.bsc === 1 && bsc.present === true && typeof bsc.z === "number" && bsc.z > 3.8,
      );
      check(
        "biosafety cabinet faces the room",
        typeof bsc.frontZ === "number" && bsc.frontZ < bsc.z,
      );
      check("teacher present", c.teacher === 1 && teacher.present === true);
      check(
        "teacher is life-sized",
        typeof teacher.height === "number" && teacher.height > 1.55 && teacher.height < 2.05,
      );
      check("teacher stands on the floor", Math.abs(teacher.footY || 0) < 0.08);
      check("teacher stands (not walking)", teacher.walking === false);
      check("teacher plays the idle clip", teacher.hasIdleClip === true);
      check(
        "teacher stands in front of the biosafety cabinet",
        typeof teacher.bscDist === "number" && teacher.bscDist < 1.2,
      );
      check(
        "teacher stands naturally (hands at the sides, not T-posed)",
        teacher.bones && teacher.bones.LeftHand && teacher.bones.Hips &&
          Math.abs(teacher.bones.LeftHand[0] - teacher.bones.Hips[0]) < 0.4 &&
          teacher.bones.LeftHand[1] < 1.45,
      );
      check(
        "teacher faces the room",
        typeof teacher.facingDot === "number" && teacher.facingDot > 0.6,
      );
      const bioT = report.bioTeacher || {};
      check(
        "biology teacher photo present at the front",
        c.bioTeacher === 1 && bioT.present === true &&
          typeof bioT.pos === "object" && typeof bioT.pos[2] === "number" && bioT.pos[2] < -3.6,
      );
      check(
        "biology teacher stands on the podium",
        typeof bioT.pos === "object" && Math.abs(bioT.pos[0]) <= 2.3 &&
          bioT.pos[1] > 0.4 && bioT.pos[1] < 0.5,
      );
      check(
        "biology teacher is life-sized, full-body and grounded on the platform",
        typeof bioT.height === "number" && bioT.height > 1.45 && bioT.height < 1.8 &&
          typeof bioT.bb === "object" && bioT.bb.min[1] > 0.4 && bioT.bb.min[1] < 0.5 &&
          typeof bioT.aspect === "number" && bioT.aspect > 2.0 && bioT.aspect < 2.8,
      );
      const podium = report.podium || {};
      check("raised teaching podium present at the front", c.podium === 1 && podium.present === true);
      check(
        "podium platform is 450 mm high",
        typeof podium.top === "number" && Math.abs(podium.top - 0.45) < 0.02,
      );
      check(
        "podium platform spans the whiteboard width",
        typeof podium.width === "number" && podium.width >= 4.2 &&
          podium.bbox && podium.bbox.min[2] < -4.8,
      );
      check(
        "podium leaves the whiteboard writing surface unobstructed",
        typeof podium.top === "number" && podium.top < 1.0,
      );
      check(
        "podium has exactly three steps on each side",
        podium.stepsTotal === 6 && podium.stepsLeft === 3 && podium.stepsRight === 3,
      );
      check(
        "step risers add up to the platform height",
        Array.isArray(podium.risers) && podium.risers.length === 3 &&
          Math.abs(podium.risers.reduce((s, r) => s + r, 0) - podium.top) < 0.02,
      );
      check(
        "staircases sit at the far ends, outside the central writing zone",
        podium.stairsOutsideCentralZone === true,
      );
      check(
        "front bench kept with a clear aisle to the podium",
        typeof podium.benchAisle === "number" && podium.benchAisle >= 0.5,
      );
      check(
        "teacher stands on the platform (podium-aware placement)",
        podium.teacherOnPodium === true,
      );
      const heart = report.heart || {};
      check("3D heart specimen present", c.heart === 1 && heart.present === true);
      check(
        "3D heart is fully modelled",
        heart.parts >= 30 && heart.vertices > 5000,
      );
      check(
        "3D heart stands upright on its plinth, right of the board",
        Array.isArray(heart.pos) && heart.pos[0] > 2.2 && heart.pos[0] < 5.8 &&
          Array.isArray(heart.size) &&
          heart.size[1] >= heart.size[0] && heart.size[1] >= heart.size[2] &&
          heart.bbox && heart.bbox.min[1] > 0.6 && heart.bbox.min[1] < 1.2,
      );
      check(
        "running streams are sized to reach the basin",
        taps.every((t) => t.mode !== "stream" || !t.running || (t.streamLen > 0.1 && t.streamLen <= t.fall + 0.02)),
      );
      check(
        "microscopes clear of the sink splash zone",
        micros.every((mm) => typeof mm.gapToSink === "number" && mm.gapToSink > 0.03),
      );
      check(
        "outdoor tree diagnostics are consistent",
        typeof c.trees === "number" && report.treesInfo && report.treesInfo.count === c.trees,
      );
      check("glassware present on benches", c.glassware >= 12);
      check(
        "doors are fully clickable (whole surface is a hit target)",
        c.doors >= 1 && c.doorHitMin >= 8,
      );
      check("test tubes present", c.testTubes >= 24);
      check("test-tube racks present", c.tubeRacks >= 8);
      check("autoclave present", c.autoclaves >= 1);
      check("fire extinguishers present", c.extinguishers >= 2);
      check(
        "drawers exist and are wired to open",
        c.drawers >= 40 && c.drawersReady === true,
      );
      check("indoor exposure is not washed out", px.mean > 0.4 && px.mean < 0.85);
      check("scene has visible contrast", px.std > 0.09);
      check("shadows are not crushed", px.crushed < 0.05);
      check("highlights are not blown out", px.blown < 0.05);
      /* Phase 1 nav integration surfaced in the diag dump */
      check("teacher controller created (Phase 1)", teacher.control === true);
      check("nav grid built in the live scene", typeof report.nav === "object" && report.nav !== null &&
        report.nav.cells > 0 && report.nav.walkable > 0);
      /* Phase 2 behaviour layer surfaced in the diag dump */
      check("behaviour layer attached (Phase 2)", teacher.behaviour === true);
      /* Phase 3 equipment catalogue surfaced in the diag dump */
      check("equipment catalogue attached (Phase 3)", teacher.equipment === 4 && teacher.ready === true);
      /* Phase 4 science layer surfaced in the diag dump */
      check("science layer attached (Phase 4)",
        !!report.science && report.science.ready === true && report.science.experiments >= 9);
      /* Phase 5 student layer surfaced in the diag dump */
      check("student layer attached (Phase 5)",
        !!report.students && report.students.ready === true && report.students.count >= 4 &&
        report.students.apiCalls === 0);
      /* Phase 6 lesson engine surfaced in the diag dump */
      check("lesson engine attached (Phase 6)",
        !!report.lessonEngine && report.lessonEngine.ready === true);
      /* Phase 7 environment / biology / safety surfaced in the diag dump */
      check("environment model attached (Phase 7)",
        !!report.environment && report.environment.ready === true &&
        typeof report.environment.daylight === "number" && report.environment.lux > 0);
      check("biology assets attached (Phase 7)",
        !!report.biology && report.biology.ready === true &&
        report.biology.auditOk === true && report.biology.cells.length >= 3);
      check("safety model attached (Phase 7)",
        !!report.safety && report.safety.ready === true);
      /* Phase 8 camera rig + performance monitor surfaced in the diag dump */
      check("camera rig attached (Phase 8)",
        !!report.cameraRig && report.cameraRig.ready === true && report.cameraRig.mode === "orbit");
      check("performance monitor attached (Phase 8)",
        !!report.perfMon && typeof report.perfMon.tier === "string");
    }

    /* ---------- Phase 1 navtest pass (?navtest=1) ---------- */
    console.log("smoke: navtest pass");
    const navDom = await dumpDom(browser, NAVTEST_URL, NAVTEST_VTIME_BUDGET, "biolab-navtest-", /NAVTESTREADY/, "navtest");
    const navTitle = (navDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("navtest ran (NAVTESTREADY)", /NAVTESTREADY/.test(navTitle));
    let navReport = null;
    const nm = navDom.match(/<pre id="__navtest"[^>]*>([\s\S]*?)<\/pre>/);
    if (nm) {
      try {
        navReport = JSON.parse(decodeEntities(nm[1]));
      } catch (error) {
        console.error("smoke: could not parse navtest JSON:", error.message);
      }
    }
    check("navtest report emitted", navReport !== null);
    if (navReport) {
      for (const item of navReport.checks || []) {
        check(`navtest: ${item.name}`, item.ok === true, item.detail);
      }
      check("navtest: zero failures", (navReport.fails ?? 1) === 0);
    }

    /* ---------- Phase 2 behavtest pass (?behavtest=1) ---------- */
    console.log("smoke: behavtest pass");
    const behavDom = await dumpDom(browser, BEHAVTEST_URL, BEHAVTEST_VTIME_BUDGET, "biolab-behavtest-", /BEHAVTESTREADY/, "behavtest");
    const behavTitle = (behavDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("behavtest ran (BEHAVTESTREADY)", /BEHAVTESTREADY/.test(behavTitle));
    let behavReport = null;
    const bm = behavDom.match(/<pre id="__behavtest"[^>]*>([\s\S]*?)<\/pre>/);
    if (bm) {
      try {
        behavReport = JSON.parse(decodeEntities(bm[1]));
      } catch (error) {
        console.error("smoke: could not parse behavtest JSON:", error.message);
      }
    }
    check("behavtest report emitted", behavReport !== null);
    if (behavReport) {
      for (const item of behavReport.checks || []) {
        check(`behavtest: ${item.name}`, item.ok === true, item.detail);
      }
      check("behavtest: zero failures", (behavReport.fails ?? 1) === 0);
      check("behavtest: no page errors", (behavReport.errors ?? []).length === 0);
    }

    /* ---------- Phase 5 studenttest pass (?studenttest=1) ---------- */
    console.log("smoke: studenttest pass");
    const studentDom = await dumpDom(browser, STUDENTTEST_URL, STUDENTTEST_VTIME_BUDGET, "biolab-studenttest-", /STUDENTTESTREADY/, "studenttest");
    const studentTitle = (studentDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("studenttest ran (STUDENTTESTREADY)", /STUDENTTESTREADY/.test(studentTitle));
    let studentReport = null;
    const sm = studentDom.match(/<pre id="__studenttest"[^>]*>([\s\S]*?)<\/pre>/);
    if (sm) {
      try {
        studentReport = JSON.parse(decodeEntities(sm[1]));
      } catch (error) {
        console.error("smoke: could not parse studenttest JSON:", error.message);
      }
    }
    check("studenttest report emitted", studentReport !== null);
    if (studentReport) {
      for (const item of studentReport.checks || []) {
        check(`studenttest: ${item.name}`, item.ok === true, item.detail);
      }
      check("studenttest: zero failures", (studentReport.fails ?? 1) === 0);
    }

    /* ---------- Phase 6 lessontest pass (?lessontest=1) ---------- */
    console.log("smoke: lessontest pass");
    const lessonDom = await dumpDom(browser, LESSONTEST_URL, LESSONTEST_VTIME_BUDGET, "biolab-lessontest-", /LESSONTESTREADY/, "lessontest");
    const lessonTitle = (lessonDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("lessontest ran (LESSONTESTREADY)", /LESSONTESTREADY/.test(lessonTitle));
    let lessonReport = null;
    const lm2 = lessonDom.match(/<pre id="__lessontest"[^>]*>([\s\S]*?)<\/pre>/);
    if (lm2) {
      try {
        lessonReport = JSON.parse(decodeEntities(lm2[1]));
      } catch (error) {
        console.error("smoke: could not parse lessontest JSON:", error.message);
      }
    }
    check("lessontest report emitted", lessonReport !== null);
    if (lessonReport) {
      for (const item of lessonReport.checks || []) {
        check(`lessontest: ${item.name}`, item.ok === true, item.detail);
      }
      check("lessontest: zero failures", (lessonReport.fails ?? 1) === 0);
    }

    /* ---------- Phase 7 envtest pass (?envtest=1) ---------- */
    console.log("smoke: envtest pass");
    const envDom = await dumpDom(browser, ENVTEST_URL, ENVTEST_VTIME_BUDGET, "biolab-envtest-", /ENVTESTREADY/, "envtest");
    const envTitle = (envDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("envtest ran (ENVTESTREADY)", /ENVTESTREADY/.test(envTitle));
    let envReport = null;
    const em = envDom.match(/<pre id="__envtest"[^>]*>([\s\S]*?)<\/pre>/);
    if (em) {
      try {
        envReport = JSON.parse(decodeEntities(em[1]));
      } catch (error) {
        console.error("smoke: could not parse envtest JSON:", error.message);
      }
    }
    check("envtest report emitted", envReport !== null);
    if (envReport) {
      for (const item of envReport.checks || []) {
        check(`envtest: ${item.name}`, item.ok === true, item.detail);
      }
      check("envtest: zero failures", (envReport.fails ?? 1) === 0);
    }

    /* ---------- Phase 8 camtest pass (?camtest=1) ---------- */
    console.log("smoke: camtest pass");
    const camDom = await dumpDom(browser, CAMTEST_URL, CAMTEST_VTIME_BUDGET, "biolab-camtest-", /CAMTESTREADY/, "camtest");
    const camTitle = (camDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("camtest ran (CAMTESTREADY)", /CAMTESTREADY/.test(camTitle));
    let camReport = null;
    const cm = camDom.match(/<pre id="__camtest"[^>]*>([\s\S]*?)<\/pre>/);
    if (cm) {
      try {
        camReport = JSON.parse(decodeEntities(cm[1]));
      } catch (error) {
        console.error("smoke: could not parse camtest JSON:", error.message);
      }
    }
    check("camtest report emitted", camReport !== null);
    if (camReport) {
      for (const item of camReport.checks || []) {
        check(`camtest: ${item.name}`, item.ok === true, item.detail);
      }
      check("camtest: zero failures", (camReport.fails ?? 1) === 0);
    }

    /* ---------- Phase 8 movtest pass (?movtest=1) ---------- */
    console.log("smoke: movtest pass");
    const movDom = await dumpDom(browser, MOVTEST_URL, MOVTEST_VTIME_BUDGET, "biolab-movtest-", /MOVTESTREADY/, "movtest");
    const movTitle = (movDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("movtest ran (MOVTESTREADY)", /MOVTESTREADY/.test(movTitle));
    let movReport = null;
    const mm2 = movDom.match(/<pre id="__movtest"[^>]*>([\s\S]*?)<\/pre>/);
    if (mm2) {
      try {
        movReport = JSON.parse(decodeEntities(mm2[1]));
      } catch (error) {
        console.error("smoke: could not parse movtest JSON:", error.message);
      }
    }
    check("movtest report emitted", movReport !== null);
    if (movReport) {
      for (const item of movReport.checks || []) {
        check(`movtest: ${item.name}`, item.ok === true, item.detail);
      }
      check("movtest: zero failures", (movReport.fails ?? 1) === 0);
    }

    /* ---------- Phase 8 evtest pass (?evtest=1) ---------- */
    console.log("smoke: evtest pass");
    const evDom = await dumpDom(browser, EVTEST_URL, EVTEST_VTIME_BUDGET, "biolab-evtest-", /EVTESTREADY/, "evtest");
    const evTitle = (evDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("evtest ran (EVTESTREADY)", /EVTESTREADY/.test(evTitle));
    let evReport = null;
    const evm = evDom.match(/<pre id="__evtest"[^>]*>([\s\S]*?)<\/pre>/);
    if (evm) {
      try {
        evReport = JSON.parse(decodeEntities(evm[1]));
      } catch (error) {
        console.error("smoke: could not parse evtest JSON:", error.message);
      }
    }
    check("evtest report emitted", evReport !== null);
    if (evReport) {
      for (const item of evReport.checks || []) {
        check(`evtest: ${item.name}`, item.ok === true, item.detail);
      }
      check("evtest: zero failures", (evReport.fails ?? 1) === 0);
    }

    /* ---------- Phase 8 microtest pass (?microtest=1) ---------- */
    console.log("smoke: microtest pass");
    const microDom = await dumpDom(browser, MICROTEST_URL, MICROTEST_VTIME_BUDGET, "biolab-microtest-", /MICROTESTREADY/, "microtest");
    const microTitle = (microDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("microtest ran (MICROTESTREADY)", /MICROTESTREADY/.test(microTitle));
    let microReport = null;
    const micm = microDom.match(/<pre id="__microtest"[^>]*>([\s\S]*?)<\/pre>/);
    if (micm) {
      try {
        microReport = JSON.parse(decodeEntities(micm[1]));
      } catch (error) {
        console.error("smoke: could not parse microtest JSON:", error.message);
      }
    }
    check("microtest report emitted", microReport !== null);
    if (microReport) {
      for (const item of microReport.checks || []) {
        check(`microtest: ${item.name}`, item.ok === true, item.detail);
      }
      check("microtest: zero failures", (microReport.fails ?? 1) === 0);
    }

    /* ---------- Phase 8 consisttest pass (?consisttest=1) ---------- */
    console.log("smoke: consisttest pass");
    const consistDom = await dumpDom(browser, CONSISTTEST_URL, CONSISTTEST_VTIME_BUDGET, "biolab-consisttest-", /CONSISTTESTREADY/, "consisttest");
    const consistTitle = (consistDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("consisttest ran (CONSISTTESTREADY)", /CONSISTTESTREADY/.test(consistTitle));
    let consistReport = null;
    const csm = consistDom.match(/<pre id="__consisttest"[^>]*>([\s\S]*?)<\/pre>/);
    if (csm) {
      try {
        consistReport = JSON.parse(decodeEntities(csm[1]));
      } catch (error) {
        console.error("smoke: could not parse consisttest JSON:", error.message);
      }
    }
    check("consisttest report emitted", consistReport !== null);
    if (consistReport) {
      for (const item of consistReport.checks || []) {
        check(`consisttest: ${item.name}`, item.ok === true, item.detail);
      }
      check("consisttest: zero failures", (consistReport.fails ?? 1) === 0);
    }

    /* ---------- Grab3D modeltest pass (?modeltest=1) — needs internet for upstream ---------- */
    console.log("smoke: modeltest pass");
    const modelDom = await dumpDom(browser, MODELTEST_URL, MODELTEST_VTIME_BUDGET, "biolab-modeltest-", /MODELTESTREADY/, "modeltest");
    const modelTitle = (modelDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("modeltest ran (MODELTESTREADY)", /MODELTESTREADY/.test(modelTitle));
    let modelReport = null;
    const mdm = modelDom.match(/<pre id="__modeltest"[^>]*>([\s\S]*?)<\/pre>/);
    if (mdm) {
      try {
        modelReport = JSON.parse(decodeEntities(mdm[1]));
      } catch (error) {
        console.error("smoke: could not parse modeltest JSON:", error.message);
      }
    }
    check("modeltest report emitted", modelReport !== null);
    if (modelReport) {
      for (const item of modelReport.checks || []) {
        check(`modeltest: ${item.name}`, item.ok === true, item.detail);
      }
      check("modeltest: zero failures", (modelReport.fails ?? 1) === 0);
      check("modeltest: no page errors", (modelReport.errors ?? []).length === 0);
    }

    /* ---------- kidneytest pass (?kidneytest=1) — Stage 3 segmented kidney ---------- */
    console.log("smoke: kidneytest pass");
    const kidneyDom = await dumpDom(browser, KIDNEYTEST_URL, KIDNEYTEST_VTIME_BUDGET, "biolab-kidneytest-", /KIDNEYTESTREADY/, "kidneytest");
    const kidneyTitle = (kidneyDom.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || "";
    check("kidneytest ran (KIDNEYTESTREADY)", /KIDNEYTESTREADY/.test(kidneyTitle));
    let kidneyReport = null;
    const kdm = kidneyDom.match(/<pre id="__kidneytest"[^>]*>([\s\S]*?)<\/pre>/);
    if (kdm) {
      try {
        kidneyReport = JSON.parse(decodeEntities(kdm[1]));
      } catch (error) {
        console.error("smoke: could not parse kidneytest JSON:", error.message);
      }
    }
    check("kidneytest report emitted", kidneyReport !== null);
    if (kidneyReport) {
      for (const item of kidneyReport.checks || []) {
        check(`kidneytest: ${item.name}`, item.ok === true, item.detail);
      }
      check("kidneytest: zero failures", (kidneyReport.fails ?? 1) === 0);
      check("kidneytest: no page errors", (kidneyReport.errors ?? []).length === 0);
    }
  } finally {
    if (server && !server.killed) server.kill();
  }

  let failed = 0;
  for (const item of checks) {
    if (!item.ok) failed += 1;
    console.log(`${item.ok ? "PASS" : "FAIL"}  ${item.name}${item.ok ? "" : item.detail ? `  [${item.detail}]` : ""}`);
  }
  console.log(`\nsmoke: ${checks.length - failed}/${checks.length} checks passed`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error("smoke: unexpected failure", error);
  process.exit(2);
});
