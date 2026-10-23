import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const htmlPath = resolve(__dirname, "../admin_web/index.html");
let html = readFileSync(htmlPath, "utf-8");

// 1. Remove <h2>Welcome back</h2>
html = html.replace(/\r?\n\s*<h2>Welcome back<\/h2>/g, '');

// 2. Remove <p class="auth-card-desc">Sign in to your staff portal.</p>
html = html.replace(/\r?\n\s*<p class="auth-card-desc">Sign in to your staff portal\.<\/p>/g, '');

// 3. Change span.auth-card-tag to h2.auth-card-tag
html = html.replace('<span class="auth-card-tag">SECURE STAFF PORTAL</span>', '<h2 class="auth-card-tag">SECURE STAFF PORTAL</h2>');

// 4. Change Email or username to Email
html = html.replace('<span>Email or username</span>', '<span>Email</span>');

// 5. Change input type to email and autocomplete to email
html = html.replace('input type="text" id="email" autocomplete="username"', 'input type="email" id="email" autocomplete="email"');

writeFileSync(htmlPath, html, "utf-8");
console.log("Successfully updated admin_web/index.html!");
