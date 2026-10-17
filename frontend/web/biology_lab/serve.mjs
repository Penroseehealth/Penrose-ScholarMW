import { createServer } from "node:http";
import { readFile, stat, mkdir, writeFile, rename } from "node:fs/promises";
import { extname, join, normalize, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";
import { tmpdir } from "node:os";

const root = fileURLToPath(new URL(".", import.meta.url));
const port = Number(process.env.PORT || 7456);

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".glb": "model/gltf-binary",
  ".gltf": "model/gltf+json",
  ".obj": "text/plain; charset=utf-8",
  ".mtl": "text/plain; charset=utf-8",
  ".ico": "image/x-icon",
  ".webp": "image/webp",
  ".txt": "text/plain; charset=utf-8",
};

/* text-ish payloads compress well (heart.obj is ~7.8MB of ASCII) */
const compressible = new Set([".html", ".js", ".mjs", ".css", ".json", ".svg", ".obj", ".mtl"]);
/* content-addressed-ish long cache for immutable vendor/assets, revalidate for pages */
const longCache = /^\/?(vendor|assets)\//;

const gzCache = new Map(); // key -> Buffer

/* ---------- Grab3D public-CC0 relay ----------
   grab3d.com serves no Access-Control-Allow-Origin headers, so browser fetch()
   cannot read the catalogue or GLBs cross-origin. This relay mirrors the official
   keyless endpoints under /grab3d/... on the same origin and caches on disk
   (catalogue revalidated after 6h; immutable download files cached forever). */
const GRAB_UPSTREAM = "https://grab3d.com";
const GRAB_CACHE_DIR = join(tmpdir(), "biolab-grab3d-cache");
const GRAB_TTL_MS = 6 * 3600 * 1000;
const GRAB_MAX_BYTES = 64 * 1024 * 1024;
const GRAB_ROUTES = [
  { re: /^\/grab3d\/api\/v1\/(models\.json|kits\.json|models\/[a-z0-9-]+\.json)$/, ttl: GRAB_TTL_MS, timeout: 20000 },
  { re: /^\/grab3d\/dl\/([a-z0-9-]+\/[A-Za-z0-9._-]+\.(glb|json|txt))$/, ttl: Infinity, timeout: 180000 },
  { re: /^\/grab3d\/m\/([a-z0-9-]+\/[A-Za-z0-9._-]+\.(webp|jpg|jpeg|png|glb))$/, ttl: Infinity, timeout: 120000 },
];

function grabType(rel) {
  const t = types[extname(rel).toLowerCase()];
  return t || "application/octet-stream";
}

async function grabReadCache(rel, ttl) {
  const file = join(GRAB_CACHE_DIR, rel);
  try {
    const st = await stat(file);
    if (ttl !== Infinity && Date.now() - st.mtimeMs > ttl) return { stale: true, file, data: await readFile(file) };
    return { stale: false, file, data: await readFile(file) };
  } catch {
    return null;
  }
}

async function grabFetchUpstream(rel, timeout) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeout);
  try {
    const r = await fetch(GRAB_UPSTREAM + rel, { signal: ctrl.signal, redirect: "follow" });
    if (!r.ok) return { status: r.status };
    if (r.url && !r.url.startsWith(GRAB_UPSTREAM)) return { status: 502 };
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > GRAB_MAX_BYTES) return { status: 502 };
    const file = join(GRAB_CACHE_DIR, rel);
    await mkdir(dirname(file), { recursive: true });
    const tmp = file + "." + process.pid + ".tmp";
    await writeFile(tmp, buf);
    await rename(tmp, file);
    return { status: 200, data: buf, type: r.headers.get("content-type") };
  } catch (e) {
    return { status: 504, error: e && e.message };
  } finally {
    clearTimeout(timer);
  }
}

async function grabRelay(req, res, path) {
  if (req.method !== "GET" && req.method !== "HEAD") {
    res.writeHead(405, { allow: "GET,HEAD", "content-type": "text/plain" });
    res.end("method not allowed");
    return;
  }
  let matched = null, rel = null, ttl = null, timeout = 20000;
  for (const route of GRAB_ROUTES) {
    const m = path.match(route.re);
    if (m) { matched = route; rel = m[1]; ttl = route.ttl; timeout = route.timeout; break; }
  }
  if (!matched) {
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("unknown grab3d route");
    return;
  }
  const upstreamRel = matched.re === GRAB_ROUTES[0].re ? "/api/v1/" + rel : (path.startsWith("/grab3d/m/") ? "/m/" + rel : "/dl/" + rel);
  const cacheKey = upstreamRel.replace(/^\//, ""); /* cache layout mirrors the upstream path */
  try {
    let hit = await grabReadCache(cacheKey, ttl);
    let cacheState = hit ? (hit.stale ? "stale" : "hit") : "miss";
    let status = hit && !hit.stale ? 200 : 0;
    let data = hit ? hit.data : null;
    let ctype = grabType(cacheKey);
    if (status !== 200) {
      const up = await grabFetchUpstream(upstreamRel, timeout);
      if (up.status === 200) {
        status = 200;
        data = up.data;
        ctype = up.type || ctype;
        cacheState = "fetched";
      } else if (hit && hit.stale) {
        status = 200; /* upstream down: prefer stale cache over failing */
        cacheState = "stale";
      } else {
        res.writeHead(up.status === 404 ? 404 : 502, { "content-type": "text/plain" });
        res.end(up.status === 404 ? "not found upstream" : "grab3d upstream unavailable");
        return;
      }
    }
    const headers = {
      "content-type": ctype,
      "content-length": data.length,
      "cache-control": ttl === Infinity ? "public, max-age=604800" : "public, max-age=300",
      "x-grab3d-cache": cacheState,
    };
    res.writeHead(status, headers);
    console.log("  grab3d", cacheKey, "->", status, cacheState, data.length + "B");
    res.end(req.method === "HEAD" ? undefined : data);
  } catch {
    res.writeHead(502, { "content-type": "text/plain" });
    res.end("grab3d relay error");
  }
}

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    let path = decodeURIComponent(url.pathname);
    if (path === "/") path = "/index.html";
    console.log(new Date().toISOString(), req.method, path);
    if (path.startsWith("/grab3d/")) {
      await grabRelay(req, res, path);
      return;
    }
    const file = normalize(join(root, path));
    if (!file.startsWith(normalize(root))) {
      res.writeHead(403, { "content-type": "text/plain" });
      res.end("forbidden");
      return;
    }
    const ext = extname(file).toLowerCase();
    const type = types[ext] || "application/octet-stream";

    let st;
    try { st = await stat(file); } catch { st = null; }
    const etag = st ? `W/"${st.size}-${Math.round(st.mtimeMs)}"` : null;

    const headers = { "content-type": type, vary: "accept-encoding" };
    if (etag) headers.etag = etag;
    headers["cache-control"] = longCache.test(path)
      ? "public, max-age=86400, must-revalidate"
      : "no-cache";

    if (etag && req.headers["if-none-match"] === etag) {
      res.writeHead(304, headers);
      res.end();
      return;
    }

    const data = await readFile(file);

    const acceptGz = /\bgzip\b/.test(req.headers["accept-encoding"] || "");
    if (acceptGz && compressible.has(ext) && data.length > 1024) {
      const key = file + ":" + (etag || data.length);
      let gz = gzCache.get(key);
      if (!gz) { gz = gzipSync(data); gzCache.set(key, gz); }
      headers["content-encoding"] = "gzip";
      headers["content-length"] = gz.length;
      res.writeHead(200, headers);
      res.end(gz);
      return;
    }

    headers["content-length"] = data.length;
    res.writeHead(200, headers);
    res.end(data);
  } catch {
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("not found");
  }
}).listen(port, () => {
  console.log(`biology-lab serving http://127.0.0.1:${port}/`);
});
