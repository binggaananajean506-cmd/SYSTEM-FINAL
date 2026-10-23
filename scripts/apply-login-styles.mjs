import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const cssPath = resolve(__dirname, "../admin_web/style.css");
let css = readFileSync(cssPath, "utf-8");

const startMarker = "#login-screen .brand-logo-medallion {";
const endMarker = "#login-screen .auth-wave-decoration {";

const startIndex = css.indexOf(startMarker);
const endIndex = css.indexOf(endMarker);

if (startIndex === -1 || endIndex === -1) {
  console.error("Could not find markers in style.css");
  process.exit(1);
}

const newStyles = `#login-screen .brand-logo-medallion {
  display: grid !important;
  place-items: center !important;
  width: clamp(100px, 10.5vw, 130px) !important;
  height: clamp(100px, 10.5vw, 130px) !important;
  padding: 0 !important;
  border-radius: 50% !important;
  border: 3.5px solid #d4af37 !important;
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
  gap: 8px;
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
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  text-shadow: 0 2px 6px rgba(0, 0, 0, 0.6);
}

#login-screen .auth-heading-serif {
  margin: 0 !important;
  font: 800 clamp(36px, 4.2vw, 54px)/1.15 'Playfair Display', Georgia, serif !important;
  color: #ffffff !important;
  text-wrap: balance;
  text-shadow: 0 3px 12px rgba(0, 0, 0, 0.7), 0 1px 3px rgba(0, 0, 0, 0.9);
}

#login-screen .auth-subheading {
  max-width: 460px;
  margin: 0 !important;
  color: #ffffff !important;
  font-size: 14.5px;
  font-weight: 500;
  line-height: 1.5;
  text-wrap: balance;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.7);
  opacity: 0.95;
}

#login-screen .auth-gold-diamond {
  display: inline-block;
  color: #facc15;
  font-size: 14px;
  margin-top: 4px;
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
  min-height: 100vh !important;
  padding: clamp(24px, 4vh, 48px) clamp(20px, 3.5vw, 48px) !important;
  background: transparent !important;
  position: relative !important;
  z-index: 2;
}

#login-screen .auth-form-panel::before,
#login-screen .auth-form-panel::after,
#login-screen .auth-card::before,
#login-screen .button--primary::after { display: none !important; }

#login-screen .auth-card {
  display: block;
  width: min(100%, 450px) !important;
  max-width: 450px !important;
  max-height: none !important;
  margin: 0 !important;
  padding: 34px 36px !important;
  border: 1px solid rgba(226, 232, 240, 0.8) !important;
  border-radius: 28px !important;
  background: #ffffff !important;
  color: #0f172a;
  text-shadow: none;
  box-shadow: 0 25px 60px -12px rgba(0, 0, 0, 0.18), 0 10px 24px -6px rgba(0, 0, 0, 0.08) !important;
  overflow: visible !important;
  animation: none !important;
  transform: none !important;
}

#login-screen .auth-card-top { margin-bottom: 22px; }
#login-screen .auth-card-header-flex { display: flex; align-items: center; gap: 14px; }
#login-screen .auth-card-shield-icon {
  display: grid;
  place-items: center;
  flex: 0 0 46px;
  width: 46px;
  height: 46px;
  border-radius: 14px;
  color: #ffffff;
  background: #0d5c43 !important;
  box-shadow: 0 4px 12px rgba(13, 92, 67, 0.25);
}
#login-screen .auth-card-shield-icon .material-symbols-rounded { font-size: 24px; }
#login-screen .auth-card-title-group { min-width: 0; }
#login-screen .auth-card-tag {
  display: block;
  color: #0d5c43 !important;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: .12em;
  text-transform: uppercase;
}
#login-screen .auth-card h2 {
  margin: 2px 0 0 !important;
  font: 800 clamp(22px, 2.3vw, 26px)/1.15 'Outfit', sans-serif;
  color: #102a22 !important;
}
#login-screen .auth-card-desc {
  margin: 8px 0 0 !important;
  color: #64748b !important;
  font-size: 13.5px;
  line-height: 1.45;
}

#login-screen .auth-field { display: grid; min-width: 0; gap: 6px; margin-bottom: 14px !important; }
#login-screen .auth-field > span { color: #1e293b !important; font-size: 12.5px; font-weight: 750; }
#login-screen .auth-field > div {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 10px;
  align-items: center;
  min-height: 48px;
  padding: 0 8px 0 14px;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  background: #f8fafc;
  box-shadow: none;
}
#login-screen .auth-field > div:focus-within {
  border-color: #0d5c43;
  background: #ffffff;
  box-shadow: 0 0 0 3px rgba(13, 92, 67, 0.15);
}
#login-screen .auth-field > div > .material-symbols-rounded { color: #64748b; font-size: 20px; }
#login-screen .auth-field input {
  min-width: 0;
  width: 100%;
  min-height: 46px;
  height: 46px !important;
  padding: 0 !important;
  border: 0 !important;
  border-radius: 0 !important;
  background: transparent !important;
  color: #0f172a !important;
  box-shadow: none;
  font: 500 14.5px/1.5 'Manrope', sans-serif;
}
#login-screen .auth-field input::placeholder { color: #94a3b8; opacity: 1; }
#login-screen .field-visibility {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  padding: 0;
  border: 0;
  border-radius: 9px;
  color: #64748b;
  background: transparent;
  cursor: pointer;
}
#login-screen .field-visibility:hover { color: #0d5c43; }

#login-screen .auth-options-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 12px 0 16px;
}
#login-screen .auth-remember-row {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  color: #475569;
  font-size: 12.5px;
  font-weight: 600;
  user-select: none;
}
#login-screen .auth-checkbox {
  width: 17px;
  height: 17px;
  min-height: 17px;
  margin: 0;
  accent-color: #0d5c43;
  cursor: pointer;
}
#login-screen .auth-forgot-btn {
  min-height: 38px;
  height: 38px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #0d5c43 !important;
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  text-decoration: none;
}
#login-screen .auth-forgot-btn:hover {
  text-decoration: underline;
}

#login-screen .form-message { margin: 0 0 12px; padding: 10px 12px; border-radius: 10px; font-size: 13px; line-height: 1.5; overflow-wrap: anywhere; }
#login-screen .form-message:empty { display: none; }
#login-screen .form-message.error { color: var(--error); background: var(--errorSurface); border: 1px solid var(--errorBorder); }
#login-screen .form-message.success { color: var(--success); background: var(--successSurface); border: 1px solid var(--successBorder); }

#login-screen .auth-signin-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 9px;
  width: 100%;
  min-height: 50px;
  height: 50px !important;
  margin-top: 2px;
  padding: 12px 18px;
  border: 0;
  border-radius: 14px;
  background: linear-gradient(180deg, #0d5f46 0%, #084332 100%) !important;
  color: #ffffff !important;
  box-shadow: 0 8px 24px rgba(13, 92, 67, 0.35);
  font: 800 15px/1.5 'Manrope', sans-serif;
  text-shadow: none;
  cursor: pointer;
  transition: transform .15s, box-shadow .15s;
}
#login-screen .auth-signin-btn:hover { transform: translateY(-1px); box-shadow: 0 10px 28px rgba(13, 92, 67, 0.45); }
#login-screen .auth-signin-btn:active { transform: translateY(0); }
#login-screen .auth-signin-btn:disabled { color: var(--disabled); background: var(--disabledBackground) !important; border-color: var(--border); box-shadow: none; cursor: wait; }
#login-screen .auth-signin-btn .material-symbols-rounded { font-size: 20px; }

#login-screen .auth-divider {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 16px 0;
  color: #94a3b8 !important;
  font-size: 11px;
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
  gap: 8px;
  width: 100%;
  min-height: 48px;
  height: 48px !important;
  border: 1.5px solid #cbd5e1;
  border-radius: 14px;
  background: #ffffff;
  color: #1e293b;
  font: 750 14px 'Manrope', sans-serif;
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
  font-size: 20px;
}

#login-screen .auth-landing-link {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin-top: 14px;
  color: #64748b;
  font-size: 12px;
  font-weight: 600;
  text-decoration: none;
  transition: color 0.15s;
}
#login-screen .auth-landing-link:hover {
  color: #0d5c43;
  text-decoration: underline;
}
#login-screen .auth-landing-link .material-symbols-rounded {
  font-size: 16px;
}

#login-screen .auth-appearance-button {
  position: fixed;
  top: 20px;
  right: 24px;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  color: #0d5c43;
  background: #ffffff;
  border: 1px solid rgba(0, 0, 0, 0.08);
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.12);
  display: grid;
  place-items: center;
  z-index: 20;
}

`;

const updatedCss = css.slice(0, startIndex) + newStyles + css.slice(endIndex);
writeFileSync(cssPath, updatedCss, "utf-8");
console.log("Successfully updated admin_web/style.css with design styles!");
