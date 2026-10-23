import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { dirname, extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const contentTypes = {
  ".css": "text/css",
  ".gif": "image/gif",
  ".html": "text/html",
  ".js": "text/javascript",
  ".json": "application/json",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
};

createServer(async (request, response) => {
  let target;
  try {
    const path = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    target = resolve(root, `.${path === "/" ? "/index.html" : path}`);
    if (!target.startsWith(`${root}${sep}`)) throw new Error("Invalid path");
    const content = await readFile(target);
    response.writeHead(200, { "Content-Type": contentTypes[extname(target)] || "application/octet-stream" });
    response.end(content);
  } catch {
    response.writeHead(404);
    response.end("Not found");
  }
}).listen(4173, "127.0.0.1");
