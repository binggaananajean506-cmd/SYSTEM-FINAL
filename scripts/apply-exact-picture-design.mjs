import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// 1. Update admin_web/index.html
const htmlPath = resolve(__dirname, "../admin_web/index.html");
let html = readFileSync(htmlPath, "utf-8");

// Replace auth-card form inside index.html to match the exact picture layout
const oldFormStart = '<form id="loginForm" class="auth-card">';
const oldFormEnd = '</form>';

const formStartIndex = html.indexOf(oldFormStart);
const formEndIndex = html.indexOf(oldFormEnd, formStartIndex);

if (formStartIndex === -1 || formEndIndex === -1) {
  console.error("Could not find loginForm in index.html");
  process.exit(1);
}

const newFormHtml = `<form id="loginForm" class="auth-card">
        <div class="auth-card-top">
          <div class="auth-card-header-flex">
            <div class="auth-card-shield-icon" aria-hidden="true">
              <span class="material-symbols-rounded">shield</span>
            </div>
            <div class="auth-card-title-group">
              <div class="auth-card-tag-row">
                <span class="auth-card-tag">SECURE STAFF PORTAL</span>
                <span class="auth-card-status-dot" aria-label="System online" title="System online"></span>
              </div>
              <h1 class="auth-card-title">Welcome back</h1>
            </div>
          </div>
          <p class="auth-card-subtitle">Sign in to your staff portal.</p>
        </div>
        <label class="auth-field"><span>Email or username</span>
          <div><span class="material-symbols-rounded">person</span><input type="text" id="email" autocomplete="username email"
              required placeholder="anajean@gmail.com"></div>
        </label>
        <label class="auth-field"><span>Password</span>
          <div><span class="material-symbols-rounded">lock</span><input type="password" id="password"
              autocomplete="current-password" required placeholder="••••••"><button class="field-visibility"
              type="button" data-toggle-password="password" aria-label="Show password"><span
                class="material-symbols-rounded">visibility</span></button></div>
        </label>
        <div class="auth-options-row">
          <label class="auth-remember-row" for="rememberMe">
            <input type="checkbox" id="rememberMe" class="auth-checkbox">
            <span>Remember me</span>
          </label>
          <button type="button" id="forgotPasswordBtn" class="auth-forgot-btn">Forgot password?</button>
        </div>
        <p id="authMessage" class="form-message" role="status" aria-live="polite"></p>
        <button class="button button--primary button--block auth-signin-btn" type="submit"><span class="material-symbols-rounded auth-btn-icon" aria-hidden="true">login</span><span>Sign In</span></button>
        <div class="auth-divider" role="separator" aria-label="or divider">
          <span class="auth-divider-line"></span>
          <span class="auth-divider-text">OR</span>
          <span class="auth-divider-line"></span>
        </div>
        <button type="button" id="openOrganizationRegistration" class="auth-register-btn"><span class="material-symbols-rounded" aria-hidden="true">person_add</span><span>Register an account</span></button>
        <a class="auth-landing-link" href="https://e-sugid.web.app/"><span class="material-symbols-rounded" aria-hidden="true">arrow_back</span><span>Back to landing page</span></a>
      </form>`;

html = html.slice(0, formStartIndex) + newFormHtml + html.slice(formEndIndex + oldFormEnd.length);

// Update cache-busting query parameter
html = html.replace(/style\.css\?v=[^"']+/g, 'style.css?v=20261014-exact-picture-v2');

writeFileSync(htmlPath, html, "utf-8");
console.log("Updated admin_web/index.html with exact picture form structure");

// 2. Update admin_web/style.css
const cssPath = resolve(__dirname, "../admin_web/style.css");
let css = readFileSync(cssPath, "utf-8");

const startMarker = "/* Responsive web sign-in. Fitted to viewport on desktop, responsive scroll on mobile. */";
const endMarker = ".barangay-audience-notice-box {";

const startIndex = css.indexOf(startMarker);
const endIndex = css.indexOf(endMarker);

if (startIndex === -1 || endIndex === -1) {
  console.error("Could not find markers in style.css. startIndex:", startIndex, "endIndex:", endIndex);
  process.exit(1);
}

const exactPictureStyles = `/* Responsive web sign-in. Fitted to viewport on desktop, responsive scroll on mobile. */
html:has(#login-screen:not([hidden])),
body:has(#login-screen:not([hidden])) {
  height: 100% !important;
  height: 100vh !important;
  height: 100dvh !important;
  max-height: 100vh !important;
  max-height: 100dvh !important;
  overflow: hidden !important;
  margin: 0 !important;
  padding: 0 !important;
}

#login-screen:not([hidden]) {
  display: grid !important;
  grid-template-columns: minmax(0, 1.18fr) minmax(0, 0.82fr) !important;
  grid-template-rows: 100% !important;
  height: 100vh !important;
  height: 100dvh !important;
  max-height: 100vh !important;
  max-height: 100dvh !important;
  padding: 0 !important;
  margin: 0 !important;
  position: relative;
  background: #021c14 url('assets/barili-login-bg.jpg') center center / cover no-repeat !important;
  font-family: 'Manrope', system-ui, sans-serif;
  isolation: isolate;
  overflow: hidden !important;
}

/* Atmospheric lighting and depth overlays */
#login-screen::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 1;
  background:
    radial-gradient(circle 540px at 8% 8%, rgba(255, 238, 180, 0.28) 0%, rgba(255, 220, 120, 0.1) 50%, transparent 80%),
    radial-gradient(ellipse 80% 80% at 50% 50%, transparent 52%, rgba(1, 26, 18, 0.42) 100%),
    linear-gradient(180deg, rgba(2, 30, 20, 0.15) 0%, transparent 25%, transparent 75%, rgba(1, 20, 14, 0.35) 100%);
}

#login-screen::after {
  content: '';
  position: absolute;
  top: -20%;
  left: -20%;
  width: 140%;
  height: 140%;
  pointer-events: none;
  z-index: 1;
  background: radial-gradient(circle 380px at 15% 15%, rgba(255, 255, 255, 0.1), transparent 70%);
  animation: ambientSunPulse 10s ease-in-out infinite alternate;
}

@keyframes ambientSunPulse {
  0% { opacity: 0.6; transform: scale(0.98); }
  100% { opacity: 1; transform: scale(1.02); }
}

#login-screen[hidden] { display: none !important; }

#login-screen {
  position: relative !important;
  width: 100% !important;
  height: 100vh !important;
  height: 100dvh !important;
  max-height: 100vh !important;
  max-height: 100dvh !important;
  display: grid !important;
  grid-template-columns: minmax(0, 1.18fr) minmax(0, 0.82fr) !important;
  grid-template-rows: 100% !important;
  background: #021c14 url('assets/barili-login-bg.jpg') center center / cover no-repeat !important;
  isolation: isolate;
  overflow: hidden !important;
}

#login-screen .auth-brand-panel {
  position: relative !important;
  isolation: isolate;
  display: flex !important;
  flex-direction: column !important;
  align-items: center !important;
  justify-content: center !important;
  min-width: 0;
  height: 100% !important;
  max-height: 100vh !important;
  padding: clamp(16px, 3.5vh, 44px) clamp(20px, 3vw, 48px) !important;
  overflow: hidden !important;
  background: transparent !important;
  border: 0 !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  animation: none !important;
  z-index: 2;
  perspective: 1000px;
}

#login-screen .auth-cover-photo {
  display: none !important;
}

#login-screen .auth-brand-panel::before,
#login-screen .auth-brand-panel::after,
#login-screen .auth-brand-panel .brand-blob {
  display: none !important;
}

#login-screen .auth-brand-content {
  position: relative;
  display: flex !important;
  flex-direction: column !important;
  align-items: center !important;
  justify-content: center !important;
  gap: 14px;
  width: min(100%, 540px);
  margin: 0 !important;
  text-align: center !important;
  z-index: 2;
}

#login-screen .municipal-brand--large {
  margin: 0 !important;
  justify-content: center !important;
}

/* 3D Realistic Gold-Rimmed Seal Medallion */
#login-screen .brand-logo-medallion {
  position: relative;
  display: grid !important;
  place-items: center !important;
  width: clamp(92px, 9vw, 118px) !important;
  height: clamp(92px, 9vw, 118px) !important;
  padding: 5px !important;
  border-radius: 50% !important;
  background: linear-gradient(135deg, #fff7cd 0%, #facc15 25%, #ca8a04 50%, #fef08a 75%, #854d0e 100%) !important;
  box-shadow:
    0 16px 36px -4px rgba(0, 0, 0, 0.48),
    0 4px 14px rgba(212, 175, 55, 0.35),
    inset 0 2px 2px rgba(255, 255, 255, 0.9),
    inset 0 -2px 3px rgba(0, 0, 0, 0.4) !important;
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.25s cubic-bezier(0.16, 1, 0.3, 1) !important;
  cursor: pointer;
  transform-style: preserve-3d;
  will-change: transform;
}

#login-screen .brand-logo-medallion:hover {
  box-shadow:
    0 24px 44px -4px rgba(0, 0, 0, 0.58),
    0 8px 22px rgba(212, 175, 55, 0.55),
    inset 0 2px 2px rgba(255, 255, 255, 1) !important;
}

#login-screen .brand-logo-medallion::before {
  content: '';
  position: absolute;
  inset: 4px;
  border-radius: 50%;
  background: radial-gradient(circle at 35% 35%, #064e3b 0%, #022c22 80%, #011b14 100%);
  box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.6), 0 1px 2px rgba(255, 255, 255, 0.3);
  z-index: 1;
}

#login-screen .brand-logo {
  position: relative;
  z-index: 2;
  display: block;
  width: 90% !important;
  height: 90% !important;
  border-radius: 50% !important;
  object-fit: contain !important;
  filter: drop-shadow(0 6px 14px rgba(0, 0, 0, 0.45)) !important;
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
  transform: translateZ(6px);
}

#login-screen .brand-logo-medallion:hover .brand-logo {
  transform: translateZ(10px) scale(1.02);
}

#login-screen .auth-message-block {
  display: flex !important;
  flex-direction: column !important;
  align-items: center !important;
  gap: 6px;
  width: 100%;
  margin: 0 !important;
  text-align: center !important;
}

#login-screen .auth-eyebrow-row {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin: 2px 0;
}

#login-screen .auth-gold-dash {
  width: 26px;
  height: 1.5px;
  border-radius: 2px;
  background: linear-gradient(90deg, transparent, #fde047 50%, #eab308 100%);
  box-shadow: 0 0 6px rgba(250, 204, 21, 0.6);
}

#login-screen .auth-eyebrow-row .auth-gold-dash:first-child {
  background: linear-gradient(90deg, #eab308 0%, #fde047 50%, transparent 100%);
}

#login-screen .auth-eyebrow {
  display: inline-block;
  margin: 0 !important;
  padding: 0 !important;
  border: 0 !important;
  background: none !important;
  box-shadow: none;
  color: #fef08a !important;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.8), 0 0 12px rgba(234, 179, 8, 0.3);
}

#login-screen .auth-heading-serif {
  margin: 0 !important;
  font: 800 clamp(32px, 3.8vw, 48px)/1.15 'Playfair Display', Georgia, serif !important;
  color: #ffffff !important;
  text-wrap: balance;
  letter-spacing: -0.01em;
  text-shadow:
    0 4px 18px rgba(0, 0, 0, 0.85),
    0 1px 3px rgba(0, 0, 0, 0.95),
    0 0 30px rgba(255, 255, 255, 0.15);
  transition: opacity 0.3s ease;
}

#login-screen .auth-subheading {
  max-width: 440px;
  margin: 0 !important;
  color: #f1f5f9 !important;
  font-size: 14px;
  font-weight: 500;
  line-height: 1.5;
  text-wrap: balance;
  text-shadow: 0 2px 10px rgba(0, 0, 0, 0.85);
  opacity: 0.95;
}

#login-screen .auth-gold-diamond {
  display: inline-block;
  color: #facc15;
  font-size: 14px;
  margin-top: 4px;
  text-shadow: 0 0 10px rgba(250, 204, 21, 0.7), 0 2px 6px rgba(0, 0, 0, 0.8);
  animation: diamondGlow 3s ease-in-out infinite alternate;
}

@keyframes diamondGlow {
  0% { transform: scale(0.95); opacity: 0.85; filter: drop-shadow(0 0 2px rgba(250, 204, 21, 0.4)); }
  100% { transform: scale(1.08); opacity: 1; filter: drop-shadow(0 0 8px rgba(250, 204, 21, 0.9)); }
}

#login-screen .auth-trust-badges {
  display: none !important;
}

#login-screen .auth-form-panel {
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  min-width: 0;
  height: 100% !important;
  max-height: 100vh !important;
  padding: clamp(16px, 3vh, 36px) clamp(16px, 2.5vw, 36px) !important;
  background: transparent !important;
  position: relative !important;
  z-index: 2;
  overflow: hidden !important;
  perspective: 1200px;
}

#login-screen .auth-form-panel::before,
#login-screen .auth-form-panel::after,
#login-screen .auth-card::before,
#login-screen .button--primary::after { display: none !important; }

/* EXACT 3D ELEVATED WHITE CARD FROM USER PICTURE */
#login-screen .auth-card {
  position: relative;
  display: block;
  width: min(100%, 380px) !important;
  max-width: 380px !important;
  margin: 0 !important;
  padding: 24px 26px !important;
  border-radius: 24px !important;
  background: rgba(255, 255, 255, 0.98) !important;
  backdrop-filter: blur(20px) !important;
  -webkit-backdrop-filter: blur(20px) !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow:
    0 24px 60px -8px rgba(0, 30, 20, 0.28),
    0 10px 24px -4px rgba(0, 0, 0, 0.12),
    0 0 0 1px rgba(226, 232, 240, 0.8),
    inset 0 1px 1.5px #ffffff,
    inset 0 -1px 2px rgba(0, 0, 0, 0.03) !important;
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.25s cubic-bezier(0.16, 1, 0.3, 1) !important;
  transform-style: preserve-3d;
  will-change: transform, box-shadow;
}

#login-screen .auth-card:hover {
  box-shadow:
    0 32px 70px -8px rgba(0, 30, 20, 0.34),
    0 14px 28px -4px rgba(0, 0, 0, 0.16),
    0 0 0 1px rgba(226, 232, 240, 0.95),
    inset 0 1.5px 2px #ffffff !important;
}

#login-screen .auth-card-top {
  margin-bottom: 16px;
  text-align: left;
}

#login-screen .auth-card-header-flex {
  display: flex;
  align-items: center;
  gap: 12px;
}

/* 3D EMERALD SHIELD BADGE FROM PICTURE */
#login-screen .auth-card-shield-icon {
  display: grid;
  place-items: center;
  flex: 0 0 42px;
  width: 42px;
  height: 42px;
  border-radius: 12px;
  color: #ffffff;
  background: linear-gradient(145deg, #10b981 0%, #059669 45%, #047857 100%) !important;
  box-shadow:
    0 6px 16px -2px rgba(5, 150, 105, 0.45),
    inset 0 1.5px 1px rgba(255, 255, 255, 0.5),
    inset 0 -1.5px 1px rgba(0, 0, 0, 0.25) !important;
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}

#login-screen .auth-card:hover .auth-card-shield-icon {
  transform: scale(1.04);
}

#login-screen .auth-card-shield-icon .material-symbols-rounded {
  font-size: 22px;
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));
}

#login-screen .auth-card-title-group {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

#login-screen .auth-card-tag-row {
  display: flex;
  align-items: center;
  gap: 6px;
}

#login-screen .auth-card-tag {
  color: #047857 !important;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: .12em;
  text-transform: uppercase;
  margin: 0 !important;
  line-height: 1.2;
}

/* Status indicator pulse */
#login-screen .auth-card-status-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10b981;
  box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.25), 0 0 6px #10b981;
  animation: statusPulse 2.5s infinite;
}

@keyframes statusPulse {
  0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.6), 0 0 4px #10b981; }
  70% { transform: scale(1); box-shadow: 0 0 0 4px rgba(16, 185, 129, 0), 0 0 8px #10b981; }
  100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0), 0 0 4px #10b981; }
}

#login-screen .auth-card-title {
  margin: 0 !important;
  font-size: 21px !important;
  font-weight: 850 !important;
  color: #0f172a !important;
  letter-spacing: -0.01em;
  line-height: 1.2;
}

#login-screen .auth-card-subtitle {
  margin: 4px 0 0 !important;
  color: #64748b !important;
  font-size: 12.5px;
  font-weight: 500;
  line-height: 1.4;
}

/* TACTILE 3D INSET FORM FIELDS FROM USER PICTURE */
#login-screen .auth-field {
  display: grid;
  min-width: 0;
  gap: 4px;
  margin-bottom: 11px !important;
}

#login-screen .auth-field > span {
  color: #1e293b !important;
  font-size: 12px;
  font-weight: 750;
  letter-spacing: 0.01em;
}

#login-screen .auth-field > div {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 8px;
  align-items: center;
  min-height: 42px;
  height: 42px;
  padding: 0 8px 0 12px;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  background: #f8fafc;
  box-shadow: inset 0 1.5px 3px rgba(0, 0, 0, 0.03), 0 1px 1px rgba(255, 255, 255, 0.9);
  transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

#login-screen .auth-field > div:focus-within {
  border-color: #059669;
  background: #ffffff;
  box-shadow:
    0 0 0 3.5px rgba(5, 150, 105, 0.16),
    inset 0 1px 2px rgba(0, 0, 0, 0.02);
  transform: translateY(-1px);
}

#login-screen .auth-field > div > .material-symbols-rounded {
  color: #94a3b8;
  font-size: 19px;
  transition: color 0.2s ease, transform 0.2s ease;
}

#login-screen .auth-field > div:focus-within > .material-symbols-rounded {
  color: #059669;
  transform: scale(1.05);
}

#login-screen .auth-field input {
  min-width: 0;
  width: 100%;
  min-height: 40px;
  height: 40px !important;
  padding: 0 !important;
  border: 0 !important;
  border-radius: 0 !important;
  background: transparent !important;
  color: #0f172a !important;
  box-shadow: none;
  font: 500 13px/1.4 'Manrope', sans-serif;
}

#login-screen .auth-field input::placeholder {
  color: #94a3b8;
  opacity: 1;
}

#login-screen .field-visibility {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  padding: 0;
  border: 0;
  border-radius: 7px;
  color: #94a3b8;
  background: transparent;
  cursor: pointer;
  transition: all 0.15s ease;
}

#login-screen .field-visibility:hover {
  color: #047857;
  background: rgba(5, 150, 105, 0.08);
}

#login-screen .field-visibility .material-symbols-rounded {
  font-size: 17px;
}

#login-screen .auth-options-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 6px 0 11px;
}

#login-screen .auth-remember-row {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  cursor: pointer;
  color: #475569;
  font-size: 11.5px;
  font-weight: 600;
  user-select: none;
  transition: color 0.15s ease;
}

#login-screen .auth-remember-row:hover {
  color: #1e293b;
}

#login-screen .auth-checkbox {
  appearance: auto;
  width: 14px;
  height: 14px;
  min-height: 14px;
  margin: 0;
  accent-color: #059669;
  cursor: pointer;
}

#login-screen .auth-forgot-btn {
  min-height: 26px;
  height: 26px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #059669 !important;
  font-size: 11.5px;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  text-decoration: none;
  transition: color 0.15s ease, transform 0.15s ease;
}

#login-screen .auth-forgot-btn:hover {
  color: #047857 !important;
  text-decoration: underline;
  transform: translateY(-0.5px);
}

#login-screen .form-message {
  margin: 0 0 10px;
  padding: 8px 10px;
  border-radius: 8px;
  font-size: 11.5px;
  line-height: 1.4;
  overflow-wrap: anywhere;
}

#login-screen .form-message:empty { display: none; }
#login-screen .form-message.error { color: var(--error); background: var(--errorSurface); border: 1px solid var(--errorBorder); }
#login-screen .form-message.success { color: var(--success); background: var(--successSurface); border: 1px solid var(--successBorder); }

/* 3D JEWEL SIGN IN BUTTON FROM USER PICTURE */
#login-screen .auth-signin-btn {
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  min-height: 45px;
  height: 45px !important;
  margin-top: 2px;
  padding: 10px 18px;
  border: 0;
  border-radius: 13px;
  background: linear-gradient(180deg, #059669 0%, #047857 45%, #024e37 100%) !important;
  color: #ffffff !important;
  font: 800 14px 'Manrope', sans-serif;
  letter-spacing: 0.01em;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.35);
  box-shadow:
    0 8px 22px -3px rgba(4, 120, 87, 0.48),
    inset 0 1.5px 1px rgba(255, 255, 255, 0.35),
    inset 0 -2px 2px rgba(0, 0, 0, 0.3) !important;
  cursor: pointer;
  transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  will-change: transform, box-shadow;
}

#login-screen .auth-signin-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 60%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.25), transparent);
  transform: skewX(-22deg);
  transition: left 0.6s ease;
}

#login-screen .auth-signin-btn:hover {
  transform: translateY(-2px);
  box-shadow:
    0 12px 28px -3px rgba(4, 120, 87, 0.58),
    inset 0 1.5px 1px rgba(255, 255, 255, 0.45),
    inset 0 -2px 2px rgba(0, 0, 0, 0.3) !important;
}

#login-screen .auth-signin-btn:hover::before {
  left: 140%;
}

#login-screen .auth-signin-btn:active {
  transform: translateY(1px);
  box-shadow:
    0 4px 12px rgba(4, 120, 87, 0.35),
    inset 0 1px 1px rgba(0, 0, 0, 0.4) !important;
}

#login-screen .auth-signin-btn:disabled {
  color: var(--disabled);
  background: var(--disabledBackground) !important;
  border-color: var(--border);
  box-shadow: none;
  cursor: wait;
}

#login-screen .auth-signin-btn .material-symbols-rounded {
  font-size: 19px;
  transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

#login-screen .auth-signin-btn:hover .material-symbols-rounded {
  transform: translateX(3px);
}

#login-screen .auth-divider {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 10px 0;
  color: #94a3b8 !important;
  font-size: 10px;
  font-weight: 750;
  letter-spacing: .06em;
}

#login-screen .auth-divider-line {
  flex: 1;
  height: 1px;
  background: #e2e8f0 !important;
}

#login-screen .auth-divider-text {
  padding: 0 4px;
  color: #94a3b8 !important;
  font-weight: 750;
}

#login-screen .auth-register-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  width: 100%;
  min-height: 41px;
  height: 41px !important;
  border: 1.5px solid #cbd5e1;
  border-radius: 12px;
  background: #ffffff;
  color: #1e293b;
  font: 750 12.5px 'Manrope', sans-serif;
  cursor: pointer;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04), inset 0 1px 1px rgba(255, 255, 255, 0.9);
  transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

#login-screen .auth-register-btn:hover {
  background: #f0fdf4;
  border-color: #86efac;
  color: #065f46;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(4, 120, 87, 0.12);
}

#login-screen .auth-register-btn:active {
  transform: translateY(0);
}

#login-screen .auth-register-btn .material-symbols-rounded {
  color: #059669 !important;
  font-size: 17px;
  transition: transform 0.2s ease;
}

#login-screen .auth-register-btn:hover .material-symbols-rounded {
  transform: scale(1.08);
}

#login-screen .auth-landing-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  margin-top: 8px;
  color: #64748b;
  font-size: 11px;
  font-weight: 600;
  text-decoration: none;
  transition: color 0.15s, transform 0.15s;
}

#login-screen .auth-landing-link:hover {
  color: #047857;
}

#login-screen .auth-landing-link:hover .material-symbols-rounded {
  transform: translateX(-3px);
}

#login-screen .auth-landing-link .material-symbols-rounded {
  font-size: 14px;
  transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

/* Frosted 3D Glass Sphere for Appearance Button */
#login-screen .auth-appearance-button {
  position: fixed;
  top: 18px;
  right: 22px;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  color: #047857;
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.9);
  box-shadow:
    0 8px 24px -4px rgba(0, 0, 0, 0.16),
    inset 0 1px 1px rgba(255, 255, 255, 1);
  display: grid;
  place-items: center;
  z-index: 20;
  cursor: pointer;
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}

#login-screen .auth-appearance-button:hover {
  transform: scale(1.08) rotate(15deg);
  box-shadow:
    0 12px 28px -4px rgba(0, 0, 0, 0.22),
    inset 0 1px 1px rgba(255, 255, 255, 1);
  color: #059669;
}

#login-screen .auth-appearance-button .material-symbols-rounded {
  font-size: 20px;
}

/* Fluid Responsive Breakpoint for Mobile and Compact Screens */
@media (max-width: 860px), (max-height: 560px) {
  html:has(#login-screen:not([hidden])),
  body:has(#login-screen:not([hidden])) {
    height: auto !important;
    max-height: none !important;
    overflow-y: auto !important;
    overflow-x: hidden !important;
  }
  #login-screen:not([hidden]) {
    grid-template-columns: minmax(0, 1fr) !important;
    grid-template-rows: auto auto !important;
    height: auto !important;
    min-height: 100vh !important;
    max-height: none !important;
    overflow-y: auto !important;
    overflow-x: hidden !important;
  }
  #login-screen .auth-brand-panel {
    height: auto !important;
    min-height: 0 !important;
    max-height: none !important;
    padding: 24px 16px 8px !important;
  }
  #login-screen .brand-logo-medallion {
    width: 64px !important;
    height: 64px !important;
    transform: none !important;
  }
  #login-screen .auth-heading-serif {
    font-size: clamp(22px, 5vw, 28px) !important;
  }
  #login-screen .auth-subheading {
    font-size: 12px !important;
    max-width: 290px !important;
  }
  #login-screen .auth-form-panel {
    height: auto !important;
    min-height: 0 !important;
    max-height: none !important;
    padding: 8px 16px 28px !important;
  }
  #login-screen .auth-card {
    padding: 20px 18px !important;
    max-width: 360px !important;
    border-radius: 18px !important;
    transform: none !important;
  }
}
`;

const updatedCss = css.slice(0, startIndex) + exactPictureStyles + css.slice(endIndex);
writeFileSync(cssPath, updatedCss, "utf-8");
console.log("Successfully applied exact picture styles to admin_web/style.css!");
