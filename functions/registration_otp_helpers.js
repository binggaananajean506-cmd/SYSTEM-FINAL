const { createHmac, timingSafeEqual } = require("crypto");

const OTP_DIGITS = 6;
const OTP_LIFETIME_MS = 5 * 60 * 1000;
const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const OTP_REQUEST_WINDOW_MS = 60 * 60 * 1000;
const OTP_MAX_REQUESTS_PER_WINDOW = 5;
const OTP_MAX_ATTEMPTS = 5;

function canonicalOtp(value) {
  const code = String(value || "").trim();
  return new RegExp(`^\\d{${OTP_DIGITS}}$`).test(code) ? code : null;
}

function otpHash(code, uid, email, secret) {
  return createHmac("sha256", `e-sugid-registration-otp:${secret}`)
    .update(`${uid}\n${String(email || "").trim().toLowerCase()}\n${code}`)
    .digest("hex");
}

function otpMatches({ code, expectedHash, uid, email, secret }) {
  const canonical = canonicalOtp(code);
  const expected = String(expectedHash || "");
  if (!canonical || !/^[a-f0-9]{64}$/i.test(expected)) return false;
  const actualBuffer = Buffer.from(otpHash(canonical, uid, email, secret), "hex");
  const expectedBuffer = Buffer.from(expected, "hex");
  return actualBuffer.length === expectedBuffer.length
    && timingSafeEqual(actualBuffer, expectedBuffer);
}

function maskedEmail(value) {
  const email = String(value || "").trim().toLowerCase();
  const separator = email.lastIndexOf("@");
  if (separator <= 0) return "your email address";
  const local = email.slice(0, separator);
  const domain = email.slice(separator + 1);
  const visible = local.slice(0, Math.min(2, local.length));
  return `${visible}${"*".repeat(Math.max(2, local.length - visible.length))}@${domain}`;
}

module.exports = {
  OTP_DIGITS,
  OTP_LIFETIME_MS,
  OTP_RESEND_COOLDOWN_MS,
  OTP_REQUEST_WINDOW_MS,
  OTP_MAX_REQUESTS_PER_WINDOW,
  OTP_MAX_ATTEMPTS,
  canonicalOtp,
  maskedEmail,
  otpHash,
  otpMatches,
};
