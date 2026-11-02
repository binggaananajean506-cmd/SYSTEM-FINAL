import { createServer } from "node:http";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { resolve, dirname, extname, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../deploy_web");
const types = { ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript", ".mjs": "text/javascript",
  ".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg", ".gif": "image/gif", ".svg": "image/svg+xml",
  ".ttf": "font/ttf", ".apk": "application/vnd.android.package-archive" };
createServer(async (request, response) => {
  try {
    let pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    if (pathname === "/") pathname = "/index.html";
    if (pathname === "/admin" || pathname === "/admin/") pathname = "/admin/index.html";
    let file = resolve(root, `.${pathname}`);
    if (!file.startsWith(root + sep)) throw new Error("Invalid path");
    let info;
    try { info = await stat(file); } catch (error) {
      if (!pathname.startsWith("/admin/")) throw error;
      file = resolve(root, "admin/index.html"); info = await stat(file);
    }
    if (!info.isFile()) throw new Error("Not a file");
    const headers = { "Content-Type": types[extname(file)] || "application/octet-stream", "Content-Length": info.size,
      "Cache-Control": "no-cache", "Accept-Ranges": "bytes", "X-Content-Type-Options": "nosniff" };
    if (extname(file) === ".apk") headers["Content-Disposition"] = 'attachment; filename="app-release.apk"';
    const range = request.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
    let start = 0, end = info.size - 1;
    if (range) {
      start = Number(range[1]); end = range[2] ? Math.min(Number(range[2]), end) : end;
      if (start > end || start >= info.size) { response.writeHead(416, { "Content-Range": `bytes */${info.size}` }); response.end(); return; }
      headers["Content-Range"] = `bytes ${start}-${end}/${info.size}`;
      headers["Content-Length"] = end - start + 1;
    }
    response.writeHead(range ? 206 : 200, headers);
    if (request.method === "HEAD") response.end();
    else createReadStream(file, { start, end }).pipe(response);
  } catch { response.writeHead(404, { "Content-Type": "text/plain" }); response.end("Not found"); }
}).listen(4174, "127.0.0.1", () => console.log("E-SUGID preview: http://127.0.0.1:4174"));
