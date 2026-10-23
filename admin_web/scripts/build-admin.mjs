import { build } from "esbuild";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");

await build({
  entryPoints: [resolve(root, "app.js")],
  bundle: true,
  minify: true,
  logLevel: "info",
  format: "iife",
  platform: "browser",
  target: "es2020",
  outfile: resolve(root, "app.bundle.js")
});
