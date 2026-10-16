import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";

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
};

/* text-ish payloads compress well (heart.obj is ~7.8MB of ASCII) */
const compressible = new Set([".html", ".js", ".mjs", ".css", ".json", ".svg", ".obj", ".mtl"]);
/* content-addressed-ish long cache for immutable vendor/assets, revalidate for pages */
const longCache = /^\/?(vendor|assets)\//;

const gzCache = new Map(); // key -> Buffer

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    let path = decodeURIComponent(url.pathname);
    if (path === "/") path = "/index.html";
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
