import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const cssPath = resolve(__dirname, "../admin_web/style.css");
let css = readFileSync(cssPath, "utf-8");

const startMarker = "/* Responsive web sign-in. Keep these rules scoped to the existing login screen. */";
const endMarker = ".barangay-audience-notice-box {";

const startIndex = css.indexOf(startMarker);
const endIndex = css.indexOf(endMarker);

if (startIndex === -1 || endIndex === -1) {
  console.error("Could not find markers in style.css");
  process.exit(1);
}

const replacement = `/* Responsive web sign-in. Fitted to viewport on desktop, responsive scroll on mobile. */
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
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.85fr) !important;
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

#login-screen[hidden] { display: none !important; }

#login-screen {
  position: relative !important;
  width: 100% !important;
  height: 100vh !important;
  height: 100dvh !important;
  max-height: 100vh !important;
  max-height: 100dvh !important;
  display: grid !important;
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.85fr) !important;
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
  gap: 12px;
  width: min(100%, 540px);
  margin: 0 !important;
  text-align: center !important;
  z-index: 2;
}

#login-screen .municipal-brand--large {
  margin: 0 !important;
  justify-content: center !important;
}

#login-screen .brand-logo-medallion {
  display: grid !important;
  place-items: center !important;
  width: clamp(84px, 8.5vw, 112px) !important;
  height: clamp(84px, 8.5vw, 112px) !important;
  padding: 0 !important;
  border-radius: 50% !important;
  border: 3px solid #d4af37 !important;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4), inset 0 0 10px rgba(212, 175, 55, 0.3) !important;
  background: rgba(3, 36, 27, 0.45) !important;
  backdrop-filter: blur(4px) !important;
  -webkit-backdrop-filter: blur(4px) !important;
  animation: none !important;
}

#login-screen .brand-logo {
  display: block;
  width: 100% !important;
  height: 100% !important;
  border-radius: 50% !important;
  object-fit: contain !important;
  filter: drop-shadow(0 6px 16px rgba(0, 0, 0, 0.22)) !important;
  animation: none !important;
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
  gap: 10px;
  margin: 2px 0;
}

#login-screen .auth-gold-dash {
  width: 24px;
  height: 1.5px;
  border-radius: 2px;
  background: #facc15;
}

#login-screen .auth-eyebrow {
  display: inline-block;
  margin: 0 !important;
  padding: 0 !important;
  border: 0 !important;
  background: none !important;
  box-shadow: none;
  color: #fef08a !important;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  text-shadow: 0 2px 6px rgba(0, 0, 0, 0.6);
}

#login-screen .auth-heading-serif {
  margin: 0 !important;
  font: 800 clamp(30px, 3.5vw, 46px)/1.15 'Playfair Display', Georgia, serif !important;
  color: #ffffff !important;
  text-wrap: balance;
  text-shadow: 0 3px 12px rgba(0, 0, 0, 0.7), 0 1px 3px rgba(0, 0, 0, 0.9);
}

#login-screen .auth-subheading {
  max-width: 440px;
  margin: 0 !important;
  color: #ffffff !important;
  font-size: 13.5px;
  font-weight: 500;
  line-height: 1.45;
  text-wrap: balance;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.7);
  opacity: 0.95;
}

#login-screen .auth-gold-diamond {
  display: inline-block;
  color: #facc15;
  font-size: 13px;
  margin-top: 2px;
  text-shadow: 0 2px 6px rgba(0, 0, 0, 0.6);
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
}

#login-screen .auth-form-panel::before,
#login-screen .auth-form-panel::after,
#login-screen .auth-card::before,
#login-screen .button--primary::after { display: none !important; }

#login-screen .auth-card {
  display: block;
  width: min(100%, 380px) !important;
  max-width: 380px !important;
  margin: 0 !important;
  padding: 24px 26px !important;
  border: 1px solid rgba(226, 232, 240, 0.85) !important;
  border-radius: 22px !important;
  background: #ffffff !important;
  color: #0f172a;
  text-shadow: none;
  box-shadow: 0 20px 48px -10px rgba(0, 0, 0, 0.16), 0 8px 18px -4px rgba(0, 0, 0, 0.06) !important;
  overflow: visible !important;
  animation: none !important;
  transform: none !important;
}

#login-screen .auth-card-top { margin-bottom: 16px; }
#login-screen .auth-card-header-flex { display: flex; align-items: center; gap: 12px; }
#login-screen .auth-card-shield-icon {
  display: grid;
  place-items: center;
  flex: 0 0 38px;
  width: 38px;
  height: 38px;
  border-radius: 11px;
  color: #ffffff;
  background: #0d5c43 !important;
  box-shadow: 0 4px 10px rgba(13, 92, 67, 0.25);
}
#login-screen .auth-card-shield-icon .material-symbols-rounded { font-size: 20px; }
#login-screen .auth-card-title-group { min-width: 0; }
#login-screen .auth-card-tag {
  display: block;
  color: #0d5c43 !important;
  font-size: 11.5px;
  font-weight: 800;
  letter-spacing: .1em;
  text-transform: uppercase;
  margin: 0 !important;
  line-height: 1.2;
}

#login-screen .auth-field { display: grid; min-width: 0; gap: 4px; margin-bottom: 11px !important; }
#login-screen .auth-field > span { color: #1e293b !important; font-size: 11.5px; font-weight: 750; }
#login-screen .auth-field > div {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 8px;
  align-items: center;
  min-height: 42px;
  height: 42px;
  padding: 0 6px 0 12px;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  background: #f8fafc;
  box-shadow: none;
}
#login-screen .auth-field > div:focus-within {
  border-color: #0d5c43;
  background: #ffffff;
  box-shadow: 0 0 0 3px rgba(13, 92, 67, 0.12);
}
#login-screen .auth-field > div > .material-symbols-rounded { color: #64748b; font-size: 18px; }
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
  font: 500 13.5px/1.4 'Manrope', sans-serif;
}
#login-screen .auth-field input::placeholder { color: #94a3b8; opacity: 1; }
#login-screen .field-visibility {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  padding: 0;
  border: 0;
  border-radius: 7px;
  color: #64748b;
  background: transparent;
  cursor: pointer;
}
#login-screen .field-visibility:hover { color: #0d5c43; }
#login-screen .field-visibility .material-symbols-rounded { font-size: 18px; }

#login-screen .auth-options-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 8px 0 12px;
}
#login-screen .auth-remember-row {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  color: #475569;
  font-size: 11.5px;
  font-weight: 600;
  user-select: none;
}
#login-screen .auth-checkbox {
  appearance: auto;
  width: 15px;
  height: 15px;
  min-height: 15px;
  margin: 0;
  accent-color: #0d5c43;
  cursor: pointer;
}
#login-screen .auth-forgot-btn {
  min-height: 28px;
  height: 28px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #0d5c43 !important;
  font-size: 11.5px;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  text-decoration: none;
}
#login-screen .auth-forgot-btn:hover {
  text-decoration: underline;
}

#login-screen .form-message { margin: 0 0 10px; padding: 8px 10px; border-radius: 8px; font-size: 12px; line-height: 1.4; overflow-wrap: anywhere; }
#login-screen .form-message:empty { display: none; }
#login-screen .form-message.error { color: var(--error); background: var(--errorSurface); border: 1px solid var(--errorBorder); }
#login-screen .form-message.success { color: var(--success); background: var(--successSurface); border: 1px solid var(--successBorder); }

#login-screen .auth-signin-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  min-height: 44px;
  height: 44px !important;
  margin-top: 2px;
  padding: 10px 16px;
  border: 0;
  border-radius: 12px;
  background: linear-gradient(180deg, #0d5f46 0%, #084332 100%) !important;
  color: #ffffff !important;
  box-shadow: 0 6px 18px rgba(13, 92, 67, 0.32);
  font: 800 14px 'Manrope', sans-serif;
  text-shadow: none;
  cursor: pointer;
  transition: transform .15s, box-shadow .15s;
}
#login-screen .auth-signin-btn:hover { transform: translateY(-1px); box-shadow: 0 8px 22px rgba(13, 92, 67, 0.42); }
#login-screen .auth-signin-btn:active { transform: translateY(0); }
#login-screen .auth-signin-btn:disabled { color: var(--disabled); background: var(--disabledBackground) !important; border-color: var(--border); box-shadow: none; cursor: wait; }
#login-screen .auth-signin-btn .material-symbols-rounded { font-size: 18px; }

#login-screen .auth-divider {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 11px 0;
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
  min-height: 40px;
  height: 40px !important;
  border: 1.5px solid #cbd5e1;
  border-radius: 12px;
  background: #ffffff;
  color: #1e293b;
  font: 750 13px 'Manrope', sans-serif;
  cursor: pointer;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
  transition: all .15s ease;
}
#login-screen .auth-register-btn:hover {
  background: #f8fafc;
  border-color: #94a3b8;
}
#login-screen .auth-register-btn .material-symbols-rounded {
  color: #0d5c43 !important;
  font-size: 18px;
}

#login-screen .auth-landing-link {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  margin-top: 10px;
  color: #64748b;
  font-size: 11.5px;
  font-weight: 600;
  text-decoration: none;
  transition: color 0.15s;
}
#login-screen .auth-landing-link:hover {
  color: #0d5c43;
  text-decoration: underline;
}
#login-screen .auth-landing-link .material-symbols-rounded {
  font-size: 14px;
}

#login-screen .auth-appearance-button {
  position: fixed;
  top: 16px;
  right: 20px;
  width: 38px;
  height: 38px;
  border-radius: 50%;
  color: #0d5c43;
  background: #ffffff;
  border: 1px solid rgba(0, 0, 0, 0.08);
  box-shadow: 0 3px 10px rgba(0, 0, 0, 0.1);
  display: grid;
  place-items: center;
  z-index: 20;
}
#login-screen .auth-appearance-button .material-symbols-rounded { font-size: 19px; }

/* Responsive break for tablets, small screens, mobile */
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
    padding: 24px 16px 10px !important;
  }
  #login-screen .brand-logo-medallion {
    width: 64px !important;
    height: 64px !important;
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
  }
}

`;

const updatedCss = css.slice(0, startIndex) + replacement + css.slice(endIndex);
writeFileSync(cssPath, updatedCss, "utf-8");
console.log("Successfully updated admin_web/style.css with compact, non-scrollable responsive styles!");
