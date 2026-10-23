/* tutor_probe.mjs - one-shot headless dump of the tutor diagnostics with the
   tutor actor forced on (?diag=1&fighter=1), so the clip-bind reconciliation
   (fighter.clipBind) and the loaded tutor can be verified without a full smoke
   run. Prints the parsed fighter block as JSON. */
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const PORT = Number(process.env.PROBE_PORT ?? 7471);
const URL = process.env.PROBE_URL ?? `http://127.0.0.1:${PORT}/?diag=1&fighter=1`;
const VTIME = process.env.PROBE_VTIME ?? "300000";
const ATTEMPT_TIMEOUT = Number(process.env.PROBE_ATTEMPT_TIMEOUT ?? 180000);

function findBrowser() {
  const c = [
    process.env.EDGE_PATH,
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
  ];
  return c.find((x) => x && existsSync(x)) ?? null;
}
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
function run(command, args, options = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "ignore"], ...options });
    let stdout = "";
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      try { child.kill(); } catch { /* gone */ }
      resolve({ code: "timeout", stdout });
    }, ATTEMPT_TIMEOUT);
    child.stdout.on("data", (ch) => (stdout += ch.toString()));
    child.on("error", (e) => { if (settled) return; settled = true; clearTimeout(timer); resolve({ code: -1, stdout, error: String(e && e.message) }); });
    child.on("close", (code) => { if (settled) return; settled = true; clearTimeout(timer); resolve({ code, stdout }); });
  });
}
const BROWSER_ARGS = [
  "--headless", "--disable-gpu", "--no-sandbox", "--disable-dev-shm-usage",
  "--enable-unsafe-swiftshader", "--no-first-run", "--disable-extensions",
  "--hide-scrollbars", "--mute-audio", "--window-size=1280,800",
];
async function dumpDom(browser, url) {
  const dir = await mkdtemp(join(tmpdir(), "biolab-probe-"));
  const args = [
    ...BROWSER_ARGS,
    `--user-data-dir=${dir}`,
    `--virtual-time-budget=${VTIME}`,
    "--dump-dom",
    url,
  ];
  const { stdout } = await run(browser, args);
  return stdout;
}
async function waitForServer(url, timeoutMs = 12000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try { const r = await fetch(url); if (r.ok) return true; } catch { /* retry */ }
    await wait(200);
  }
  return false;
}
const decodeEntities = (s) =>
  s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
   .replace(/&#39;/g, "'").replace(/&apos;/g, "'").replace(/&amp;/g, "&");

const server = spawn(process.execPath, [join(ROOT, "serve.mjs")], {
  cwd: ROOT, env: { ...process.env, PORT: String(PORT) }, stdio: "ignore",
});
try {
  if (!(await waitForServer(`http://127.0.0.1:${PORT}/`))) {
    console.error("probe: server did not start"); process.exit(2);
  }
  const browser = findBrowser();
  if (!browser) { console.error("probe: no headless browser"); process.exit(2); }
  let dom = "";
  for (let i = 0; i < 3 && !/DIAGREADY/.test(dom); i++) {
    console.log(`probe: attempt ${i + 1}/3`);
    dom = await dumpDom(browser, URL);
  }
  const m = dom.match(/<pre id="__diag"[^>]*>([\s\S]*?)<\/pre>/);
  if (!m) { console.error("probe: no __diag in DOM (len=" + dom.length + ")"); process.exit(3); }
  const report = JSON.parse(decodeEntities(m[1]));
  console.log("errors:", JSON.stringify(report.errors || []));
  console.log("quality:", JSON.stringify(report.quality, null, 2));
  console.log("fighter:", JSON.stringify(report.fighter, null, 2));
  console.log("fighter2:", JSON.stringify(report.fighter2, null, 2));
} finally {
  try { server.kill(); } catch { /* gone */ }
}
