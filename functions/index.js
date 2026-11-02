const { applicationDefault, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue, Timestamp, getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const { randomBytes, randomInt, createHash } = require("crypto");
const { DELEGABLE_PERMISSIONS, accessPolicyId, policyAllows, policyScopeForVerification } = require("./access_policy");
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { processNotificationJob } = require("./notification_outbox");
const { canDeleteConcernRecord, canDeleteComplaintRecord } = require("./concern_cleanup");
const { createResidentSignup } = require("./resident_signup");
const { summonsBarangay, selectSummonsOfficials, manualTanodName } = require("./summons_officials");
const { defineSecret, defineString } = require("firebase-functions/params");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  canonicalSeverity,
  isActiveEmergency,
  isReminderEligible,
  reminderCycle,
  residentMatchesAlert,
} = require("./emergency_helpers");
const {
  BARILI_BARANGAYS,
  barangayIdFor,
  canManageResidentAccount,
  canRestrictResidentAccount,
  canonicalBarangayName,
  canonicalVerificationStatus,
  effectiveBarangayId,
  defaultResidentVerificationPermission,
  isReviewableVerification,
  isValidResidentVerificationDocumentType,
  isValidVerificationAttentionReason,
  isValidVerificationRejectionReason,
} = require("./verification_helpers");
const {
  canClaimAccountRequest,
  canDirectlyCreateRole,
  canReviewAccountRequest,
  isAllowedAccountRequest,
  isValidAccountRejectionReason,
  secondaryBarangayPositionLabel,
} = require("./account_approval_helpers");
const {
  canonicalRecipientType,
  isConfiguredRecipientAvailable,
} = require("./concern_routing_helpers");
const { CONCERN_CATEGORIES, LEGACY_CATEGORY_IDS, canonicalConcernCategoryId,
  concernCategory, concernDateKey, similarPublicConcern, publicConcernSummary } = require("./concern_categories");
const { validOrganizationProofHeader } = require("./organization_registration_helpers");
const {
  BARANGAY_POSITIONS, LGU_SERVICE_TYPES, ORGANIZATION_TYPES, PROOF_TYPES,
  positionAvailability, positionDefinition, positionIdForAccount,
} = require("./staff_registration_helpers");
const {
  ASSISTANT_ACTIONS,
  BUILT_IN_MUNICIPAL_OFFICIALS,
  canonicalOfficialRecord,
  cleanPublicRecord,
  groundedOfficialAnswer,
  inferKnownIntent,
  isActionAllowed,
  isCebuanoQuestion,
  officialMatchesPosition,
  routeContextForRole,
  safeClientContext,
} = require("./assistant_helpers");
const {
  OTP_LIFETIME_MS,
  OTP_RESEND_COOLDOWN_MS,
  OTP_REQUEST_WINDOW_MS,
  OTP_MAX_REQUESTS_PER_WINDOW,
  OTP_MAX_ATTEMPTS,
  canonicalOtp,
  maskedEmail,
  otpHash,
  otpMatches,
} = require("./registration_otp_helpers");
const {
  canReviewInteraction,
  marketConfirmation,
  reviewId,
} = require("./community_review_helpers");
const {
  ROUTES_ENDPOINT,
  ROUTES_FIELD_MASK,
  computeModeRoutes,
  isUnsupportedTravelModeError,
  parseRouteRequest,
} = require("./route_helpers");
const {
  canonicalOrganizationId,
  followedOrganizationIds,
  isPrivateSectorOrganization,
  organizationIdForPost,
  planFollowChange,
} = require("./organization_follow_helpers");
const {
  COMPLAINT_TYPES,
  RESPONDENT_RELATIONSHIPS,
  isComplaint,
  pickFrom,
  validComplaintReference,
} = require("./complaint_helpers");
const { planTrackingUpdate, checkTrackingOperation } = require("./complaint_tracking");


initializeApp();

const db = getFirestore();
const REGION = "asia-southeast1";
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const BREVO_API_KEY = defineSecret("BREVO_API_KEY");
const APP_BASE_URL = defineString("APP_BASE_URL");
const EMERGENCY_REMINDER_INTERVAL_MINUTES = defineString(
  "EMERGENCY_REMINDER_INTERVAL_MINUTES",
  { default: "15" },
);
const EMERGENCY_MAX_REMINDERS = defineString(
  "EMERGENCY_MAX_REMINDERS",
  // Zero means reminders continue until acknowledgement or a terminal alert
  // state. A positive value may be configured as an operational safety cap.
  { default: "0" },
);
const ESUGID_SENDER_EMAIL = "esugidbarili@gmail.com";
const ESUGID_SENDER_NAME = "E-SUGID";
const REGISTRATION_OTP_COLLECTION = "_registration_email_otps";
const ACTIVATION_LIFETIME_MS = 7 * 24 * 60 * 60 * 1000;
const ACTIVE_STATUS = "approved";
const STAFF_ROLES = new Set([
  "super_admin",
  "mayor",
  "lgu",
  "barangay_captain",
  "barangay_vice_captain",
  "barangay_secretary",
  "barangay_councilor",
  "organization",
]);
const BARANGAY_ROLES = new Set([
  "barangay_captain",
  "barangay_vice_captain",
  "barangay_secretary",
  "barangay_councilor",
]);
const BARANGAY_CONCERN_ROLES = new Set([
  "barangay_captain",
  "barangay_vice_captain",
  "barangay_secretary",
]);

exports.getConcernCategories = onCall({ region: REGION }, async (request) => ({
  categories: request.data?.organizationSectors === true
    ? CONCERN_CATEGORIES : CONCERN_CATEGORIES.filter((category) => category.sector === "public"),
}));

async function barangayPositionRecords(barangayId, transaction = null) {
  const usersQuery = db.collection("users").where("barangayId", "==", barangayId).limit(500);
  const requestsQuery = db.collection("staff_account_requests").where("barangayId", "==", barangayId).limit(500);
  const read = (reference) => transaction ? transaction.get(reference) : reference.get();
  const [users, requests, settings] = await Promise.all([
    read(usersQuery), read(requestsQuery), read(db.collection("system").doc("settings")),
  ]);
  return {
    users: users.docs.map((document) => ({ id: document.id, ...document.data() })),
    requests: requests.docs.map((document) => ({ id: document.id, ...document.data() })),
    settings: settings.data() || {},
  };
}

async function requireAvailablePosition(transaction, barangayId, positionId, excludeRequestId = "") {
  const position = positionDefinition(positionId);
  if (!position) throw new HttpsError("invalid-argument", "Select a valid barangay position.");
  const lockRef = db.collection("_barangay_position_locks").doc(`${barangayId}_${positionId}`);
  await transaction.get(lockRef);
  const records = await barangayPositionRecords(barangayId, transaction);
  const availability = positionAvailability(positionId, records.users, records.requests,
    barangayId, records.settings, excludeRequestId);
  if (!availability.available) {
    throw new HttpsError("already-exists", "This position is no longer available. Another account has already been assigned to it.");
  }
  transaction.set(lockRef, { revision: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return availability;
}

exports.getStaffRegistrationOptions = onCall({ region: REGION }, async (request) => {
  const barangayId = String(request.data?.barangayId || "").trim();
  if (barangayId && !BARILI_BARANGAYS.some((name) => barangayIdFor(name) === barangayId)) {
    throw new HttpsError("invalid-argument", "Select a valid Barili barangay.");
  }
  const offices = await db.collection("lgu_departments").limit(100).get();
  const records = barangayId ? await barangayPositionRecords(barangayId) : null;
  const organizationsSnapshot = await db.collection("organizations").limit(200).get();
  const organizations = organizationsSnapshot.docs
    .filter((doc) => !["inactive", "disabled"].includes(String(doc.data().status || "").toLowerCase()))
    .map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        name: data.name || data.organizationName || doc.id,
        sector: data.organizationSector || "public",
        categoryId: data.categoryId || data.organizationTypeId || "",
        organizationTypeId: data.organizationTypeId || data.categoryId || "",
      };
    });
  return {
    positions: BARANGAY_POSITIONS.map((position) => ({
      ...position,
      ...(records ? positionAvailability(position.id, records.users, records.requests,
        barangayId, records.settings) : {}),
    })),
    offices: offices.docs.filter((document) => ["active", "verified"].includes(String(document.data().status || "active").toLowerCase()))
      .map((document) => ({ id: document.id, name: document.data().name || document.id })),
    organizations,
    lguServiceTypes: LGU_SERVICE_TYPES,
    organizationTypes: ORGANIZATION_TYPES,
  };
});

function isActiveProfile(profile) {
  const accountStatus = String(profile?.accountStatus || "").toLowerCase();
  const legacyStatus = String(profile?.status || "").toLowerCase();
  return accountStatus === "active" || (!accountStatus && legacyStatus === ACTIVE_STATUS);
}

function isResidentRestricted(profile) {
  if (String(profile?.restrictionStatus || "").toLowerCase() !== "active") return false;
  const end = profile?.restrictionEndDate?.toMillis?.();
  return !end || end > Date.now();
}

function canonicalRole(value) {
  const role = String(value || "").trim().toLowerCase();
  if (role === "barangay") return "barangay_captain";
  if (role === "partner") return "organization";
  if (role === "municipal_mayor") return "mayor";
  return role;
}

function isMunicipalRole(role) {
  return ["super_admin", "lgu"].includes(canonicalRole(role));
}

function isItAdministrator(role) {
  return canonicalRole(role) === "super_admin";
}

function positionForRole(role) {
  return ({
    super_admin: "LGU IT Administrator",
    mayor: "Municipal Mayor",
    lgu: "LGU Staff",
    barangay_captain: "Barangay Captain",
    barangay_vice_captain: "Barangay Vice Captain",
    barangay_secretary: "Barangay Secretary",
    barangay_councilor: "Barangay Councilor",
    organization: "Organization Staff",
  })[canonicalRole(role)] || "Staff";
}

function normalizedEmail(value) {
  const email = String(value || "").trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }
  return email;
}

function requiredPhilippineMobile(value) {
  let digits = String(value || "").replace(/\D/g, "");
  if (digits.startsWith("63") && digits.length === 12) digits = `0${digits.slice(2)}`;
  if (digits.length === 10 && digits.startsWith("9")) digits = `0${digits}`;
  if (!/^09\d{9}$/.test(digits)) {
    throw new HttpsError("invalid-argument", "Enter a valid contact number.");
  }
  return digits;
}

function requiredBirthDate(value) {
  const text = String(value || "").trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (!match) throw new HttpsError("invalid-argument", "Enter a valid birth date.");
  const date = new Date(`${text}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())
    || date.getUTCFullYear() !== Number(match[1])
    || date.getUTCMonth() + 1 !== Number(match[2])
    || date.getUTCDate() !== Number(match[3])
    || date > new Date()) {
    throw new HttpsError("invalid-argument", "Enter a valid birth date.");
  }
  return text;
}

function normalizedGmailEmail(value) {
  const email = normalizedEmail(value);
  if (!email.endsWith("@gmail.com")) {
    throw new HttpsError("invalid-argument", "Enter a Gmail address ending in @gmail.com.");
  }
  return email;
}

function requiredText(value, field, maxLength = 120) {
  const text = String(value || "").trim();
  if (!text || text.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return text;
}

function requiredPassword(value) {
  const password = String(value || "");
  if (password.length < 6 || password.length > 128) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be 6-128 characters.",
    );
  }
  return password;
}

function generatedTemporaryPassword() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 6 }, () => alphabet[randomInt(alphabet.length)]).join("");
}

function requiredTemporaryPassword(value) {
  const password = String(value || "").trim();
  if (!/^[A-HJ-NP-Z2-9]{6}$/.test(password)) {
    throw new HttpsError("invalid-argument", "Generate a valid 6-character temporary password.");
  }
  return password;
}

function htmlText(value) {
  return String(value || "").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;",
  })[character]);
}

function configuredAppBaseUrl() {
  const value = String(APP_BASE_URL.value() || "").trim().replace(/\/+$/, "");
  if (!/^https?:\/\/[^\s]+$/i.test(value)) {
    throw new Error("APP_BASE_URL must be a valid HTTP or HTTPS URL.");
  }
  return value;
}

function staffAssignment(profile) {
  if (canonicalRole(profile.role) === "mayor") return "Office of the Municipal Mayor";
  if (BARANGAY_ROLES.has(canonicalRole(profile.role))) return `Barangay ${profile.barangay}`;
  if (canonicalRole(profile.role) === "organization") return profile.organizationName;
  return profile.department || "Municipality of Barili";
}

function mailFailureDetails(error) {
  const providerCode = String(error?.code || "mail_error").slice(0, 80);
  const smtpStatus = Number(error?.responseCode || 0) || null;
  const providerResponse = String(error?.response || error?.message || "Email provider rejected the request.")
    .replace(/[\r\n]+/g, " ")
    .slice(0, 500);
  const normalizedResponse = providerResponse.toLowerCase();
  let reason = "provider_error";
  if (normalizedResponse.includes("unrecognised ip address") || normalizedResponse.includes("authorized_ips")) {
    reason = "provider_ip_blocked";
  } else if (["BREVO_HTTP_401", "BREVO_HTTP_403"].includes(providerCode)) reason = "sender_authentication_failed";
  else if (providerCode === "BREVO_HTTP_400") reason = "recipient_rejected";
  else if (["BREVO_TIMEOUT", "BREVO_NETWORK_ERROR"].includes(providerCode)) reason = "provider_unavailable";
  return { reason, providerCode, smtpStatus, providerResponse };
}

function mailFailureMessage(reason) {
  if (reason === "provider_ip_blocked") {
    return "Brevo blocked the Firebase server IP. In Brevo, deactivate API IP blocking under Settings > Security > Authorized IPs, then retry.";
  }
  if (reason === "sender_authentication_failed") {
    return "Brevo rejected the E-SUGID API key or verified sender. Check the Brevo configuration and retry.";
  }
  if (reason === "recipient_rejected") {
    return "The email provider rejected the recipient address. Check the recipient Gmail address and retry.";
  }
  if (reason === "provider_unavailable") {
    return "The email provider could not be reached. Please retry in a moment.";
  }
  return "The account email could not be delivered. Check the E-SUGID mail configuration and retry.";
}

async function sendStaffCredentialsEmail({ recipientEmail, loginEmail, temporaryPassword, name, role, assignment, positionTitle, loginUrl, optionalMessage }) {
  const apiKey = String(BREVO_API_KEY.value() || "").trim();
  if (!apiKey) throw Object.assign(new Error("The Brevo API key is not configured."), { code: "BREVO_HTTP_401" });
  const senderEmail = normalizedEmail(ESUGID_SENDER_EMAIL);
  const safeMessage = optionalMessage
    ? `<p style="margin:0 0 18px;padding:12px 14px;background:#f0f8f4;border-radius:10px;color:#365e50">${htmlText(optionalMessage)}</p>`
    : "";
  const recipient = normalizedEmail(recipientEmail);
  console.info("[EMAIL] Preparing account email", { sender: senderEmail, recipient });
  const subject = "Your E-SUGID Account Has Been Created";
  const activationUrl = `${String(loginUrl).replace(/\/+$/, "")}/?setup=1`;
  const textContent = `E-SUGID\nMunicipality of Barili\n\nYour E-SUGID Account Has Been Created\n\nHello ${name},\n\nThe Municipal Administrator created an E-SUGID account for you.\n\nLogin email: ${loginEmail}\nTemporary password: ${temporaryPassword}\nAccount type: ${positionForRole(role)}\nAssignment: ${assignment}\nPosition: ${positionTitle || positionForRole(role)}\n\nSet up your private password here:\n${activationUrl}\n\nYou must replace this temporary password before signing in to the staff portal. If you did not expect this account, please contact the Municipality of Barili.`;
  const htmlContent = `<div style="margin:0;background:#edf7f2;padding:32px 12px;font-family:Arial,sans-serif;color:#153c30"><div style="max-width:620px;margin:auto;background:#ffffff;border:1px solid #c9e2d7;border-radius:22px;overflow:hidden;box-shadow:0 18px 45px rgba(6,74,53,.16)"><div style="padding:26px 30px;background:linear-gradient(135deg,#07523d,#0a8a65);color:white"><p style="margin:0 0 6px;font-size:12px;font-weight:700;letter-spacing:1.6px">MUNICIPALITY OF BARILI</p><h1 style="margin:0;font-size:27px;letter-spacing:-.5px">E-SUGID</h1></div><div style="padding:30px"><h2 style="margin:0 0 18px;font-size:23px;color:#123d30">Your E-SUGID Account Has Been Created</h2><p>Hello <strong>${htmlText(name)}</strong>,</p><p>The Municipal Administrator created an authorized E-SUGID account for you.</p>${safeMessage}<div style="margin:22px 0;padding:19px;border:1px solid #d9ebe3;border-radius:14px;background:#f5faf7"><p style="margin:0 0 11px"><strong>Login email:</strong> ${htmlText(loginEmail)}</p><p style="margin:0 0 11px"><strong>Temporary password:</strong> <span style="font-family:monospace;font-size:20px;letter-spacing:2px;color:#07523d">${htmlText(temporaryPassword)}</span></p><p style="margin:0 0 11px"><strong>Account type:</strong> ${htmlText(positionForRole(role))}</p><p style="margin:0 0 11px"><strong>Assignment:</strong> ${htmlText(assignment)}</p><p style="margin:0"><strong>Position:</strong> ${htmlText(positionTitle || positionForRole(role))}</p></div><div style="margin:28px 0 24px;text-align:center"><a href="${htmlText(activationUrl)}" style="display:block;padding:17px 24px;border:1px solid #0aa77b;border-radius:13px;background:#087454;color:#ffffff;text-decoration:none;font-size:16px;font-weight:800;letter-spacing:.4px;box-shadow:0 10px 22px rgba(8,116,84,.28)">OPEN E-SUGID &nbsp;→</a><p style="margin:10px 0 0;color:#61776e;font-size:12px">Set your private password, then continue to sign in.</p></div><p style="padding:14px 16px;border-radius:12px;background:#fff8e7;font-size:14px;color:#67542b"><strong>Important:</strong> The temporary password can only be used to complete your first-time setup.</p><p style="margin:22px 0 0;font-size:13px;color:#6a7d76">If you did not expect this account, please contact the Municipality of Barili.</p></div></div></div>`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);
  let response;
  try {
    response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        accept: "application/json",
        "api-key": apiKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        sender: { name: ESUGID_SENDER_NAME, email: senderEmail },
        to: [{ email: recipient }],
        subject,
        textContent,
        htmlContent,
      }),
      signal: controller.signal,
    });
    const responseBody = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = String(responseBody.message || `Brevo returned HTTP ${response.status}.`).slice(0, 500);
      throw Object.assign(new Error(message), {
        code: `BREVO_HTTP_${response.status}`,
        responseCode: response.status,
        response: message,
      });
    }
    const messageId = String(responseBody.messageId || "").trim();
    if (!messageId) {
      throw Object.assign(new Error("Brevo accepted the request without returning a message ID."), {
        code: "BREVO_INVALID_RESPONSE",
      });
    }
    console.info("[EMAIL] Brevo accepted message", { recipient, messageId });
    return { accepted: true, messageId };
  } catch (error) {
    if (error?.name === "AbortError") {
      error = Object.assign(new Error("Brevo request timed out."), { code: "BREVO_TIMEOUT" });
    } else if (!String(error?.code || "").startsWith("BREVO_")) {
      error = Object.assign(new Error(error?.message || "Brevo could not be reached."), {
        code: "BREVO_NETWORK_ERROR",
      });
    }
    console.error("[EMAIL] Brevo API request failed", mailFailureDetails(error));
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

async function sendAccountDecisionEmail({ recipientEmail, name, decision, reason, note }) {
  const apiKey = String(BREVO_API_KEY.value() || "").trim();
  if (!apiKey) throw Object.assign(new Error("The Brevo API key is not configured."), { code: "BREVO_HTTP_401" });
  const approved = decision === "approved";
  const recipient = normalizedEmail(recipientEmail);
  const subject = approved ? "Your E-SUGID account was approved" : "Your E-SUGID account request needs attention";
  const decisionMessage = approved
    ? "Your E-SUGID account has been approved. You may now complete setup and sign in."
    : `Your account request was not approved. Reason: ${reason}.${note ? ` ${note}` : ""}`;
  const loginBlock = approved
    ? `\n\nOpen E-SUGID:\n${configuredAppBaseUrl()}/?setup=1`
    : "";
  const textContent = `E-SUGID\nMunicipality of Barili\n\nHello ${name},\n\n${decisionMessage}${loginBlock}\n\nIf you need help, contact the Municipality of Barili.`;
  const htmlContent = `<div style="margin:0;background:#edf7f2;padding:32px 12px;font-family:Arial,sans-serif;color:#153c30"><div style="max-width:620px;margin:auto;background:#fff;border:1px solid #c9e2d7;border-radius:22px;overflow:hidden"><div style="padding:24px 28px;background:linear-gradient(135deg,#07523d,#0a8a65);color:#fff"><p style="margin:0 0 5px;font-size:12px;font-weight:700;letter-spacing:1.5px">MUNICIPALITY OF BARILI</p><h1 style="margin:0;font-size:26px">E-SUGID</h1></div><div style="padding:30px"><h2 style="margin:0 0 18px;color:#123d30">${htmlText(subject)}</h2><p>Hello <strong>${htmlText(name)}</strong>,</p><p style="line-height:1.6">${htmlText(decisionMessage)}</p>${approved ? `<p style="margin:26px 0;text-align:center"><a href="${htmlText(configuredAppBaseUrl())}/?setup=1" style="display:block;padding:16px 22px;border-radius:13px;background:#087454;color:#fff;text-decoration:none;font-weight:800">OPEN E-SUGID &nbsp;→</a></p>` : ""}<p style="margin-top:24px;color:#6a7d76;font-size:13px">If you need help, contact the Municipality of Barili.</p></div></div></div>`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);
  try {
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        accept: "application/json",
        "api-key": apiKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        sender: { name: ESUGID_SENDER_NAME, email: normalizedEmail(ESUGID_SENDER_EMAIL) },
        to: [{ email: recipient }],
        subject,
        textContent,
        htmlContent,
      }),
      signal: controller.signal,
    });
    const responseBody = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = String(responseBody.message || `Brevo returned HTTP ${response.status}.`).slice(0, 500);
      throw Object.assign(new Error(message), {
        code: `BREVO_HTTP_${response.status}`,
        responseCode: response.status,
        response: message,
      });
    }
    return { accepted: true, messageId: String(responseBody.messageId || "") };
  } catch (error) {
    if (error?.name === "AbortError") {
      throw Object.assign(new Error("Brevo request timed out."), { code: "BREVO_TIMEOUT" });
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

async function sendRegistrationOtpEmail({ recipientEmail, name, code }) {
  const apiKey = String(BREVO_API_KEY.value() || "").trim();
  if (!apiKey) {
    throw Object.assign(new Error("The Brevo API key is not configured."), {
      code: "BREVO_HTTP_401",
    });
  }
  const recipient = normalizedEmail(recipientEmail);
  const subject = "Your E-SUGID verification code";
  const textContent = `MUNICIPALITY OF BARILI - E-SUGID

Hello ${name || "Barili Resident"},

Your E-SUGID verification code is: ${code}

This code expires in 5 minutes. Do not share it with anyone.

If you did not create an E-SUGID account, you can ignore this email.`;
  const digits = String(code || "").trim().split("");
  const digitBoxesHtml = digits
    .map(
      (d) => `
      <td align="center" style="padding: 0 4px;">
        <div style="display:inline-block; width:44px; height:54px; line-height:54px; text-align:center; background:linear-gradient(180deg,#ffffff 0%,#f0faf4 100%); border:2px solid #08765B; border-radius:12px; box-shadow:0 6px 14px rgba(7,82,61,0.15), inset 0 1px 0 #ffffff; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; font-size:28px; font-weight:800; color:#043625;">
          ${htmlText(d)}
        </div>
      </td>
    `,
    )
    .join("");
  const htmlContent = `<!DOCTYPE html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light only">
  <meta name="supported-color-schemes" content="light only">
  <title>Your E-SUGID Verification Code</title>
  <!--[if mso]>
  <noscript>
    <xml>
      <o:OfficeDocumentSettings>
        <o:PixelsPerInch>96</o:PixelsPerInch>
      </o:OfficeDocumentSettings>
    </xml>
  </noscript>
  <![endif]-->
  <style>
    :root {
      color-scheme: light only;
      supported-color-schemes: light only;
    }
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      background-color: #ebf5f0 !important;
    }
    u + .body .email-card {
      background-color: #ffffff !important;
    }
    @media (prefers-color-scheme: dark) {
      .dark-bg-override {
        background-color: #ebf5f0 !important;
      }
      .dark-card-override {
        background-color: #ffffff !important;
        color: #153c30 !important;
      }
      .dark-text-override {
        color: #042e20 !important;
      }
    }
  </style>
</head>
<body class="body" style="margin:0; padding:0; background-color:#ebf5f0; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; -webkit-font-smoothing:antialiased;">
  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="dark-bg-override" style="background-color:#ebf5f0; padding:36px 12px;">
    <tr>
      <td align="center">
        <!-- Main Card Container -->
        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="email-card dark-card-override" style="max-width:540px; background-color:#ffffff; border-radius:24px; overflow:hidden; box-shadow:0 20px 48px rgba(7,72,52,0.16), 0 0 0 1px rgba(13,110,80,0.10); border:1px solid #cce5d9;">
          <!-- 3D Header Banner -->
          <tr>
            <td style="padding:28px 30px; background:linear-gradient(135deg, #033323 0%, #07523d 50%, #0b7a58 100%); border-bottom:3px solid #fde68a;">
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td>
                    <div style="font-size:11px; font-weight:800; letter-spacing:2px; color:#fde68a; text-transform:uppercase; margin-bottom:6px;">
                      🏛️ MUNICIPALITY OF BARILI
                    </div>
                    <div style="font-size:28px; font-weight:900; color:#ffffff; letter-spacing:0.5px; line-height:1.1; margin:0;">
                      E-SUGID
                    </div>
                    <div style="font-size:12px; font-weight:600; color:rgba(255,255,255,0.85); margin-top:4px;">
                      Official Citizen Verification Portal
                    </div>
                  </td>
                  <td align="right" valign="middle" style="width:60px;">
                    <div style="width:52px; height:52px; border-radius:16px; background:rgba(255,255,255,0.15); border:1px solid rgba(255,255,255,0.30); text-align:center; line-height:52px; font-size:26px; box-shadow:0 6px 16px rgba(0,0,0,0.2);">
                      ✉️
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Card Content Body -->
          <tr>
            <td style="padding:32px 30px 24px; background-color:#ffffff;">
              <!-- Verification Shield Pill -->
              <div style="display:inline-block; padding:5px 12px; background:#eaf5ef; border:1px solid #b8dfcc; border-radius:20px; font-size:12px; font-weight:700; color:#08765b; margin-bottom:16px;">
                🛡️ Account Security Verification
              </div>

              <h2 class="dark-text-override" style="margin:0 0 14px; color:#042e20; font-size:22px; font-weight:800; line-height:1.3;">
                Verify your email address
              </h2>

              <p style="margin:0 0 16px; color:#2c4c40; font-size:14.5px; line-height:1.6;">
                Hello <strong style="color:#042e20;">${htmlText(name)}</strong>,
              </p>

              <p style="margin:0 0 24px; color:#4c665c; font-size:14px; line-height:1.6;">
                Thank you for signing up with E-SUGID. Enter this 6-digit security code on your screen to complete your registration:
              </p>

              <!-- 6 Individual 3D Code Digit Tiles -->
              <div style="margin:28px 0; text-align:center;">
                <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="margin:auto;">
                  <tr>
                    ${digitBoxesHtml}
                  </tr>
                </table>
              </div>

              <!-- Expiration Notice Card with 3D gradient -->
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="margin:20px 0 24px; background:linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%); border:1px solid #fde68a; border-radius:14px; box-shadow:0 4px 10px rgba(217,119,6,0.08);">
                <tr>
                  <td style="padding:14px 16px;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                      <tr>
                        <td valign="top" style="padding-right:10px; font-size:18px; line-height:1;">
                          ⏱️
                        </td>
                        <td style="color:#78350f; font-size:13px; line-height:1.5;">
                          <strong style="color:#92400e;">This code expires in 5 minutes.</strong><br>
                          For your security, never share this one-time code with anyone.
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Helpful community text -->
              <p style="margin:0 0 20px; color:#6b8277; font-size:12.5px; line-height:1.5;">
                Once verified, your Barili resident account will be active and ready for official community services, announcements, and assistance.
              </p>

              <hr style="border:none; border-top:1px solid #e8f1ec; margin:24px 0 18px;">

              <!-- Safety Footer Note -->
              <p style="margin:0; color:#8a9e95; font-size:11.5px; line-height:1.5; text-align:center;">
                If you did not request this code or create an E-SUGID account, you can safely disregard this email.
              </p>
            </td>
          </tr>

          <!-- Municipality Footer -->
          <tr>
            <td style="padding:18px 30px; background:#f6faf8; border-top:1px solid #e6f0eb; text-align:center;">
              <p style="margin:0 0 4px; font-size:11.5px; font-weight:700; color:#07523d; letter-spacing:0.5px;">
                GOVERNMENT OF BARILI • E-SUGID RESIDENT PORTAL
              </p>
              <p style="margin:0; font-size:11px; color:#8a9e95;">
                Barili, Cebu, Philippines • All rights reserved
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);
  try {
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        accept: "application/json",
        "api-key": apiKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        sender: {
          name: ESUGID_SENDER_NAME,
          email: normalizedEmail(ESUGID_SENDER_EMAIL),
        },
        to: [{ email: recipient }],
        subject,
        textContent,
        htmlContent,
      }),
      signal: controller.signal,
    });
    const responseBody = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = String(
        responseBody.message || `Brevo returned HTTP ${response.status}.`,
      ).slice(0, 500);
      throw Object.assign(new Error(message), {
        code: `BREVO_HTTP_${response.status}`,
        responseCode: response.status,
        response: message,
      });
    }
    return { accepted: true, messageId: String(responseBody.messageId || "") };
  } catch (error) {
    if (error?.name === "AbortError") {
      throw Object.assign(new Error("Brevo request timed out."), {
        code: "BREVO_TIMEOUT",
      });
    }
    if (!String(error?.code || "").startsWith("BREVO_")) {
      throw Object.assign(new Error(error?.message || "Brevo could not be reached."), {
        code: "BREVO_NETWORK_ERROR",
      });
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function organizationKey(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function departmentKey(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function effectiveDepartmentId(profile) {
  return departmentKey(profile?.departmentId || profile?.department || "");
}

function departmentPublisherName(department) {
  const name = String(department?.publicName || department?.name || "").trim();
  if (!name) return "LGU Department";
  return /^lgu\b/i.test(name) ? name : `LGU ${name}`;
}

async function activeLguDepartment(departmentId) {
  const id = departmentKey(departmentId);
  if (!id) throw new HttpsError("invalid-argument", "Select an LGU department.");
  const snapshot = await db.collection("lgu_departments").doc(id).get();
  const department = snapshot.data();
  if (!snapshot.exists || department?.status !== "active") {
    throw new HttpsError("failed-precondition", "The selected LGU department is not active.");
  }
  return {
    id,
    name: requiredText(department.name, "Department name", 120),
    publicName: departmentPublisherName(department),
  };
}

async function lguDepartmentForAccount(actor, input) {
  const requestedId = isItAdministrator(actor.role)
    ? input.departmentId
    : effectiveDepartmentId(actor);
  const department = await activeLguDepartment(requestedId);
  if (!isItAdministrator(actor.role) && department.id !== effectiveDepartmentId(actor)) {
    throw new HttpsError("permission-denied", "LGU staff can request accounts only for their own department.");
  }
  return department;
}

async function approvedCaller(request) {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  const profile = snapshot.data();
  if (!snapshot.exists || !isActiveProfile(profile)) {
    throw new HttpsError("permission-denied", "An approved staff account is required.");
  }
  if (profile.setupRequired === true) {
    throw new HttpsError("failed-precondition", "Change the initial password before using the dashboard.");
  }
  return { id: request.auth.uid, ...profile, role: canonicalRole(profile.role) };
}

function actorPolicyKey(actor) {
  if (actor.role === 'lgu') return accessPolicyId('department', effectiveDepartmentId(actor));
  if (actor.role === 'organization') return accessPolicyId('organization', actor.organizationId);
  if (BARANGAY_ROLES.has(actor.role)) return accessPolicyId('barangay', effectiveBarangayId(actor));
  return '';
}

async function actorPolicy(actor) {
  const key = actorPolicyKey(actor);
  if (!key) return {};
  const snapshot = await db.collection('access_policies').doc(key).get();
  return snapshot.data() || {};
}

function defaultOperationalAccess(actor, permission) {
  if (isItAdministrator(actor.role)) return true;
  if (permission === 'verifications:local') return profileCanVerifyResidents(actor);
  if (permission === 'alerts:publish') return emergencyPublisherAllowed(actor);
  if (permission === 'emergencies:direct:send' || permission === 'emergencies:direct:receive') {
    return actor.role === 'organization';
  }
  if (permission === 'staff:request') {
    return actor.role === 'lgu' || actor.role === 'organization'
      || ['barangay_captain', 'barangay_vice_captain', 'barangay_secretary'].includes(actor.role);
  }
  if (permission === 'concerns') {
    return actor.role === 'lgu' || actor.role === 'organization'
      || ['barangay_captain', 'barangay_vice_captain', 'barangay_secretary'].includes(actor.role);
  }
  if (permission === 'announcements') {
    return actor.role === 'lgu' || actor.role === 'organization' || BARANGAY_ROLES.has(actor.role);
  }
  return false;
}

async function actorCan(actor, permission) {
  if (isItAdministrator(actor.role)) return true;
  return policyAllows(await actorPolicy(actor), permission, defaultOperationalAccess(actor, permission));
}

exports.setEntityAccessPolicy = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!isItAdministrator(actor.role)) throw new HttpsError('permission-denied', 'Only LGU IT can change access.');
  const type = String(request.data?.type || '');
  const id = String(request.data?.id || '');
  const key = accessPolicyId(type, id);
  const decisions = request.data?.decisions;
  if (!key || !decisions || typeof decisions !== 'object' || Array.isArray(decisions)
    || Object.keys(decisions).length !== DELEGABLE_PERMISSIONS.length
    || DELEGABLE_PERMISSIONS.some((permission) => !['default', 'grant', 'deny'].includes(decisions[permission]))
    || Object.keys(decisions).some((permission) => !DELEGABLE_PERMISSIONS.includes(permission))) {
    throw new HttpsError('invalid-argument', 'Choose a valid access level for every permission.');
  }
  if (type === 'department' && id === 'it-department') {
    throw new HttpsError('failed-precondition', 'LGU IT access cannot be changed.');
  }
  if (type === 'barangay') {
    if (!BARILI_BARANGAYS.some((name) => barangayIdFor(name) === id)) {
      throw new HttpsError('invalid-argument', 'Choose a Barili barangay.');
    }
  } else {
    const entity = await db.collection(type === 'department' ? 'lgu_departments' : 'organizations').doc(id).get();
    if (!entity.exists) throw new HttpsError('not-found', 'The selected entity no longer exists.');
  }
  const requestedScope = request.data?.verificationBarangayIds;
  const allowedIds = new Set(BARILI_BARANGAYS.map(barangayIdFor));
  if (requestedScope !== undefined && (!Array.isArray(requestedScope)
    || requestedScope.length > allowedIds.size
    || requestedScope.some((barangayId) => !allowedIds.has(barangayId)))) {
    throw new HttpsError('invalid-argument', 'Choose valid barangays for verification access.');
  }
  if (type !== 'organization' && (decisions['emergencies:direct:send'] === 'grant'
    || decisions['emergencies:direct:receive'] === 'grant')) {
    throw new HttpsError('invalid-argument', 'Private emergency dispatch is available only to organizations.');
  }
  if (decisions['verifications:local'] === 'grant' && type !== 'barangay'
    && (!requestedScope || !requestedScope.length)) {
    throw new HttpsError('invalid-argument', 'Select at least one barangay for resident verification.');
  }
  const reference = db.collection('access_policies').doc(key);
  const granted = DELEGABLE_PERMISSIONS.filter((permission) => decisions[permission] === 'grant');
  const denied = DELEGABLE_PERMISSIONS.filter((permission) => decisions[permission] === 'deny');
  const verificationBarangayIds = decisions['verifications:local'] === 'grant' && type !== 'barangay'
    ? [...new Set(requestedScope)] : [];
  const batch = db.batch();
  batch.set(reference, {
    type, entityId: id, granted, denied,
    verificationBarangayIds, updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.id
  }, { merge: true });
  batch.set(db.collection('audit_logs').doc(), {
    action: 'entity_access_changed', actorId: actor.id,
    entityType: type, entityId: id, details: { decisions, verificationBarangayIds },
    createdAt: FieldValue.serverTimestamp()
  });
  await batch.commit();
  return { type, id };
});


function verificationStatusForProfile(profile) {
  return canonicalVerificationStatus(profile?.verificationStatus || profile?.status);
}

function profileCanVerifyResidents(profile) {
  const role = canonicalRole(profile?.role);
  return defaultResidentVerificationPermission({ ...profile, role });
}

async function activeUserCaller(request) {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  const profile = snapshot.data();
  if (!snapshot.exists || !isActiveProfile(profile)) {
    throw new HttpsError("permission-denied", "An active E-SUGID account is required.");
  }
  return { id: snapshot.id, ...profile, role: canonicalRole(profile.role) };
}

async function verificationOfficialCaller(request, signedInActor) {
  const actor = signedInActor || await activeUserCaller(request);
  const policy = await actorPolicy(actor);
  const allowed = policyAllows(policy, 'verifications:local', profileCanVerifyResidents(actor));
  const barangay = BARANGAY_ROLES.has(actor.role) ? canonicalBarangayName(actor.barangay) : '';
  const barangayId = barangay ? barangayIdFor(barangay) : '';
  const storedBarangayId = String(actor.barangayId || "").trim().toLowerCase();
  const scopeIds = policyScopeForVerification(policy, barangayId);
  if (!allowed || !scopeIds.length || (BARANGAY_ROLES.has(actor.role)
    && (!barangay || !barangayId || (storedBarangayId && storedBarangayId !== barangayId)))) {
    throw new HttpsError(
      "permission-denied",
      "Resident verification requires delegated authority for assigned barangays.",
    );
  }

  // Preserve the stable relationship key for older, explicitly delegated
  // Barangay accounts without broadening their verification permission.
  const migration = {};
  if (!actor.barangayId) migration.barangayId = barangayId;
  if (Object.keys(migration).length) {
    await db.collection("users").doc(actor.id).set({
      ...migration,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  return { ...actor, ...migration, barangay, barangayId, verificationBarangayIds: scopeIds };
}

async function profilesForBarangay(barangayId, barangay) {
  const [byId, byLegacyName] = await Promise.all([
    db.collection("users").where("barangayId", "==", barangayId).limit(1000).get(),
    db.collection("users").where("barangay", "==", barangay).limit(1000).get(),
  ]);
  const profiles = new Map();
  [...byId.docs, ...byLegacyName.docs].forEach((snapshot) => {
    profiles.set(snapshot.id, { id: snapshot.id, ...snapshot.data() });
  });
  return [...profiles.values()].filter((profile) => effectiveBarangayId(profile) === barangayId);
}

async function municipalAccountReviewers() {
  const snapshot = await db.collection("users").limit(1000).get();
  return snapshot.docs
    .map((document) => ({ id: document.id, ...document.data() }))
    .filter((profile) => isItAdministrator(profile.role) && isActiveProfile(profile));
}

function verificationDocumentPath(userId, value, stage) {
  const path = String(value || "").trim();
  const primaryPath = `verifications/${userId}/supporting_document.jpg`;
  const legacyResubmissionPath = `verifications/${userId}/proof_of_residency.jpg`;
  if (path !== primaryPath
    && !(stage === "additional_document" && path === legacyResubmissionPath)) {
    throw new HttpsError("invalid-argument", "The verification document path is invalid.");
  }
  return path;
}


async function sendNormalPushToUsers(userIds, { title, body, type, referenceId }) {
  return sendMessageToUserDevices(userIds, {
    notification: { title: title.slice(0, 120), body: body.slice(0, 240) },
    data: {
      notificationType: type,
      type,
      referenceId: String(referenceId || ""),
      route: "/",
    },
    android: {
      priority: "high",
      notification: { channelId: "esugid_announcement_regular_v2" },
    },
  });
}

function queueWebNotification(transaction, payload) {
  transaction.set(db.collection("web_notification_outbox").doc(), {
    ...payload, status: "pending", attempts: 0, createdAt: FieldValue.serverTimestamp(),
  });
}

exports.deliverWebActionNotification = onDocumentCreated({
  document: "web_notification_outbox/{jobId}", region: REGION, retry: true,
  timeoutSeconds: 120, maxInstances: 5,
}, async event => {
  if (!event.data) return;
  const started = Date.now();
  const result = await processNotificationJob(event.data.ref, async (job, jobId) => {
    const recipients = new Set(job.userIds || []);
    if (job.kind === "concern") {
      const reports = await db.collection("submissions").doc(job.referenceId).collection("reports").limit(200).get();
      const batch = db.batch();
      let added = 0;
      for (const report of reports.docs) {
        const uid = String(report.id || report.data().reporterId || "");
        if (!uid || recipients.has(uid)) continue;
        recipients.add(uid);
        const suffix = createHash("sha256").update(uid).digest("hex");
        batch.set(db.collection("notifications").doc(`${jobId}_${suffix}`), {
          userId: uid, type: job.type, referenceId: job.referenceId, relatedEntityType: "concern",
          title: job.title, message: job.body, navigation: { route: "/complain" },
          read: false, createdAt: job.createdAt,
        });
        added++;
      }
      if (added) await batch.commit();
    }
    if (recipients.size) await sendNormalPushToUsers([...recipients], job);
  });
  console.info("[WEB_NOTIFICATION] Delivery", { ...result, durationMs: Date.now() - started });
  if (result.failed) console.error("[WEB_NOTIFICATION] Retry limit reached", { jobId: event.params.jobId });
});

/** Sends one FCM message to every active registered device of these users. */
async function sendMessageToUserDevices(userIds, message) {
  const ids = [...new Set(userIds.filter(Boolean))];
  if (!ids.length) return { accepted: 0, failed: 0 };
  const devices = [];
  for (let offset = 0; offset < ids.length; offset += 10) {
    const snapshot = await db.collection("device_tokens")
      .where("userId", "in", ids.slice(offset, offset + 10))
      .get();
    snapshot.docs.forEach((document) => {
      const data = document.data();
      if (data.active !== false && data.token) devices.push({ reference: document.ref, ...data });
    });
  }
  if (!devices.length) return { accepted: 0, failed: 0 };

  let accepted = 0;
  let failed = 0;
  for (let offset = 0; offset < devices.length; offset += 500) {
    const batch = devices.slice(offset, offset + 500);
    const response = await getMessaging().sendEachForMulticast({
      ...message,
      tokens: batch.map((device) => device.token),
    });
    accepted += response.successCount;
    failed += response.failureCount;
    const cleanup = db.batch();
    let cleanupCount = 0;
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = String(result.error?.code || "");
      if (["messaging/invalid-registration-token", "messaging/registration-token-not-registered"].includes(code)) {
        cleanup.delete(batch[index].reference);
        cleanupCount += 1;
      }
    });
    if (cleanupCount) await cleanup.commit();
  }
  return { accepted, failed };
}

// New APKs verify email before creating any Auth account or resident profile.
const residentSignup = createResidentSignup({
  db, auth: getAuth(), secret: () => String(BREVO_API_KEY.value() || "").trim(),
  sendEmail: sendRegistrationOtpEmail,
});
exports.beginResidentSignup = onCall({ region: REGION, secrets: [BREVO_API_KEY] }, residentSignup.begin);
exports.completeResidentSignup = onCall({ region: REGION, secrets: [BREVO_API_KEY] }, residentSignup.complete);

exports.createResidentProfile = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const authUser = await getAuth().getUser(request.auth.uid);
  const reference = db.collection("users").doc(request.auth.uid);
  const existing = await reference.get();
  if (existing.exists) {
    if (canonicalRole(existing.data()?.role) === "resident") {
      return {
        created: false,
        barangayId: effectiveBarangayId(existing.data()),
      };
    }
    throw new HttpsError("already-exists", "This account profile already exists.");
  }
  const name = requiredText(request.data?.name, "Full name", 120);
  const barangay = canonicalBarangayName(request.data?.barangay);
  const barangayId = barangayIdFor(barangay);
  if (!barangay || !barangayId || request.data?.barangayId !== barangayId) {
    throw new HttpsError("invalid-argument", "Select a valid Barili barangay.");
  }
  const acceptedPolicyVersion = requiredText(
    request.data?.acceptedPolicyVersion,
    "Accepted policy version",
    40,
  );
  const policyAcceptedAt = requiredText(request.data?.policyAcceptedAt, "Policy acceptance", 60);
  if (!Number.isFinite(Date.parse(policyAcceptedAt))) {
    throw new HttpsError("invalid-argument", "The policy acceptance date is invalid.");
  }
  const now = FieldValue.serverTimestamp();
  const address = (request.data?.address && String(request.data.address).trim().length > 0)
    ? String(request.data.address).trim().slice(0, 200)
    : barangay;
  const profile = {
    uid: request.auth.uid,
    email: String(authUser.email || request.auth.token.email || "").trim().toLowerCase(),
    name,
    role: "resident",
    status: "unverified",
    accountStatus: "active",
    verificationStatus: "not_submitted",
    residentId: `BAR-${new Date().getFullYear()}-${request.auth.uid.slice(0, 4).toUpperCase()}`,
    barangay,
    barangayId,
    address,
    contactNumber: String(request.data?.contactNumber || "").trim().slice(0, 30),
    birthDate: String(request.data?.birthDate || "").trim().slice(0, 40),
    emailOtpRequired: true,
    emailOtpVerified: false,
    acceptedPolicyVersion,
    policyAcceptedAt,
    createdAt: now,
    updatedAt: now,
  };
  const batch = db.batch();
  batch.create(reference, profile);
  batch.set(db.collection("audit_logs").doc(), {
    residentId: request.auth.uid,
    targetUserId: request.auth.uid,
    action: "verification_profile_created",
    performedBy: request.auth.uid,
    actorId: request.auth.uid,
    entityType: "user",
    entityId: request.auth.uid,
    barangayId,
    createdAt: now,
  });
  await batch.commit();
  return { created: true, barangayId };
});

async function residentOtpContext(request) {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  const [authUser, profileSnapshot] = await Promise.all([
    getAuth().getUser(request.auth.uid),
    db.collection("users").doc(request.auth.uid).get(),
  ]);
  const profile = profileSnapshot.data();
  if (!profileSnapshot.exists || canonicalRole(profile?.role) !== "resident") {
    throw new HttpsError("permission-denied", "A resident account is required.");
  }
  const email = normalizedEmail(authUser.email || request.auth.token.email);
  if (!email) {
    throw new HttpsError("failed-precondition", "This account has no email address.");
  }
  return {
    authUser,
    email,
    profile,
    profileReference: profileSnapshot.ref,
  };
}

exports.getRegistrationOtpStatus = onCall({ region: REGION }, async (request) => {
  const context = await residentOtpContext(request);
  const required = context.profile.emailOtpRequired === true;
  const verified = !required || context.profile.emailOtpVerified === true;
  if (verified) {
    return {
      required,
      verified: true,
      hasActiveCode: false,
      retryAfterSeconds: 0,
      maskedEmail: maskedEmail(context.email),
    };
  }
  const challenge = await db
    .collection(REGISTRATION_OTP_COLLECTION)
    .doc(request.auth.uid)
    .get();
  const data = challenge.data();
  const now = Date.now();
  const expiresAt = data?.expiresAt?.toMillis?.() || 0;
  const resendAvailableAt = data?.resendAvailableAt?.toMillis?.() || 0;
  const hasActiveCode = data?.status === "pending"
    && expiresAt > now
    && Number(data?.attempts || 0) < OTP_MAX_ATTEMPTS;
  return {
    required: true,
    verified: false,
    hasActiveCode,
    retryAfterSeconds: Math.max(0, Math.ceil((resendAvailableAt - now) / 1000)),
    expiresAtMillis: hasActiveCode ? expiresAt : null,
    maskedEmail: maskedEmail(context.email),
  };
});

exports.requestRegistrationOtp = onCall({
  region: REGION,
  secrets: [BREVO_API_KEY],
}, async (request) => {
  const context = await residentOtpContext(request);
  const required = context.profile.emailOtpRequired === true;
  if (!required || context.profile.emailOtpVerified === true) {
    return { verified: true, retryAfterSeconds: 0 };
  }
  if (context.authUser.emailVerified) {
    await context.profileReference.update({
      emailOtpVerified: true,
      emailVerifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { verified: true, retryAfterSeconds: 0 };
  }

  const apiKey = String(BREVO_API_KEY.value() || "").trim();
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "Email delivery is not configured.");
  }
  const now = Date.now();
  const code = String(randomInt(0, 1000000)).padStart(6, "0");
  const requestId = randomBytes(16).toString("hex");
  const challengeReference = db
    .collection(REGISTRATION_OTP_COLLECTION)
    .doc(request.auth.uid);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(challengeReference);
    const previous = snapshot.data();
    const resendAvailableAt = previous?.resendAvailableAt?.toMillis?.() || 0;
    if (resendAvailableAt > now) {
      const seconds = Math.max(1, Math.ceil((resendAvailableAt - now) / 1000));
      throw new HttpsError(
        "resource-exhausted",
        `Please wait ${seconds} seconds before requesting another code.`,
      );
    }
    const previousWindowStart = previous?.requestWindowStartedAt?.toMillis?.() || 0;
    const inCurrentWindow = now - previousWindowStart < OTP_REQUEST_WINDOW_MS;
    const requestCount = inCurrentWindow ? Number(previous?.requestCount || 0) : 0;
    if (requestCount >= OTP_MAX_REQUESTS_PER_WINDOW) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many verification codes were requested. Please try again later.",
      );
    }
    transaction.set(challengeReference, {
      uid: request.auth.uid,
      email: context.email,
      codeHash: otpHash(code, request.auth.uid, context.email, apiKey),
      status: "pending",
      attempts: 0,
      maxAttempts: OTP_MAX_ATTEMPTS,
      requestId,
      requestCount: requestCount + 1,
      requestWindowStartedAt: Timestamp.fromMillis(
        inCurrentWindow ? previousWindowStart : now,
      ),
      createdAt: FieldValue.serverTimestamp(),
      sentAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(now + OTP_LIFETIME_MS),
      resendAvailableAt: Timestamp.fromMillis(now + OTP_RESEND_COOLDOWN_MS),
    });
  });

  try {
    await sendRegistrationOtpEmail({
      recipientEmail: context.email,
      name: String(context.profile.name || "Resident").trim(),
      code,
    });
  } catch (error) {
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(challengeReference);
      if (snapshot.data()?.requestId === requestId) transaction.delete(challengeReference);
    }).catch(() => null);
    console.error("[REGISTRATION OTP] Delivery failed", mailFailureDetails(error));
    throw new HttpsError(
      "unavailable",
      "The verification email could not be sent. Please try again.",
    );
  }

  return {
    verified: false,
    sent: true,
    maskedEmail: maskedEmail(context.email),
    retryAfterSeconds: Math.ceil(OTP_RESEND_COOLDOWN_MS / 1000),
    expiresAtMillis: now + OTP_LIFETIME_MS,
  };
});

exports.verifyRegistrationOtp = onCall({
  region: REGION,
  secrets: [BREVO_API_KEY],
}, async (request) => {
  const code = canonicalOtp(request.data?.code);
  if (!code) {
    throw new HttpsError("invalid-argument", "Enter the complete 6-digit code.");
  }
  const context = await residentOtpContext(request);
  const required = context.profile.emailOtpRequired === true;
  if (!required || context.profile.emailOtpVerified === true) {
    if (!context.authUser.emailVerified) {
      await getAuth().updateUser(request.auth.uid, { emailVerified: true });
    }
    return { verified: true };
  }
  const apiKey = String(BREVO_API_KEY.value() || "").trim();
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "Email verification is not configured.");
  }
  const now = Date.now();
  const challengeReference = db
    .collection(REGISTRATION_OTP_COLLECTION)
    .doc(request.auth.uid);
  const result = await db.runTransaction(async (transaction) => {
    const challengeSnapshot = await transaction.get(challengeReference);
    const challenge = challengeSnapshot.data();
    if (!challengeSnapshot.exists || challenge?.status !== "pending") {
      return { state: "missing" };
    }
    const expiresAt = challenge.expiresAt?.toMillis?.() || 0;
    if (expiresAt <= now) {
      transaction.update(challengeReference, {
        status: "expired",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { state: "expired" };
    }
    const attempts = Number(challenge.attempts || 0);
    if (attempts >= OTP_MAX_ATTEMPTS) return { state: "locked" };
    const valid = challenge.email === context.email && otpMatches({
      code,
      expectedHash: challenge.codeHash,
      uid: request.auth.uid,
      email: context.email,
      secret: apiKey,
    });
    if (!valid) {
      const nextAttempts = attempts + 1;
      transaction.update(challengeReference, {
        attempts: nextAttempts,
        status: nextAttempts >= OTP_MAX_ATTEMPTS ? "locked" : "pending",
        lastAttemptAt: FieldValue.serverTimestamp(),
      });
      return {
        state: nextAttempts >= OTP_MAX_ATTEMPTS ? "locked" : "invalid",
        attemptsRemaining: Math.max(0, OTP_MAX_ATTEMPTS - nextAttempts),
      };
    }
    transaction.update(challengeReference, {
      status: "verified",
      codeHash: FieldValue.delete(),
      verifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(context.profileReference, {
      emailOtpVerified: true,
      emailVerifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(db.collection("audit_logs").doc(), {
      residentId: request.auth.uid,
      targetUserId: request.auth.uid,
      action: "registration_email_verified",
      performedBy: request.auth.uid,
      actorId: request.auth.uid,
      entityType: "user",
      entityId: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { state: "verified" };
  });

  if (result.state === "missing") {
    throw new HttpsError("failed-precondition", "Request a new verification code.");
  }
  if (result.state === "expired") {
    throw new HttpsError("deadline-exceeded", "This code has expired. Request a new one.");
  }
  if (result.state === "locked") {
    throw new HttpsError(
      "resource-exhausted",
      "Too many incorrect attempts. Request a new code.",
    );
  }
  if (result.state === "invalid") {
    throw new HttpsError(
      "invalid-argument",
      `That code is incorrect. ${result.attemptsRemaining} attempt${result.attemptsRemaining === 1 ? "" : "s"} remaining.`,
    );
  }

  try {
    await getAuth().updateUser(request.auth.uid, { emailVerified: true });
  } catch (error) {
    // The server-owned profile is the app gate. A later idempotent verification
    // call can repair the Auth flag without making the resident repeat the OTP.
    console.error("[REGISTRATION OTP] Firebase Auth flag update failed", {
      uid: request.auth.uid,
      code: error?.code,
    });
  }
  return { verified: true };
});

exports.submitResidentVerification = onCall({ region: REGION }, async (request) => {
  const resident = await activeUserCaller(request);
  if (resident.role !== "resident") {
    throw new HttpsError("permission-denied", "Only resident accounts submit residency verification.");
  }
  const barangay = canonicalBarangayName(resident.barangay);
  const barangayId = effectiveBarangayId(resident);
  if (!barangay || !barangayId) {
    throw new HttpsError("failed-precondition", "Your profile has no valid barangay assignment.");
  }
  const stage = request.data?.submissionStage === "additional_document"
    ? "additional_document"
    : "initial_document";
  const path = verificationDocumentPath(resident.id, request.data?.documentPath, stage);
  const documentType = requiredText(request.data?.documentType, "Document type", 120);
  if (!isValidResidentVerificationDocumentType(documentType, stage)) {
    throw new HttpsError("invalid-argument", "Select an accepted verification document type.");
  }
  const otherDocumentName =
    (documentType === "Other Proof of Address" || documentType === "Other Proof")
      ? requiredText(request.data?.otherDocumentName, "Document name", 80)
      : "";
  const contactNumber = request.data?.contactNumber
    ? requiredPhilippineMobile(request.data?.contactNumber)
    : (resident.contactNumber ? requiredPhilippineMobile(resident.contactNumber) : "09000000000");
  const birthDate = requiredBirthDate(request.data?.birthDate);
  const [documentExists] = await getStorage().bucket().file(path).exists();
  if (!documentExists) {
    throw new HttpsError("failed-precondition", "Upload your ID again before submitting.");
  }
  const reference = db.collection("users").doc(resident.id);
  let action = "verification_submitted";
  let residentName = resident.name || "Resident";

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const current = snapshot.data();
    if (!snapshot.exists || canonicalRole(current?.role) !== "resident") {
      throw new HttpsError("not-found", "The resident profile was not found.");
    }
    if (effectiveBarangayId(current) !== barangayId) {
      throw new HttpsError("failed-precondition", "Your barangay assignment changed. Refresh and try again.");
    }
    const currentStatus = verificationStatusForProfile(current);
    const allowed = ["not_submitted", "rejected", "additional_document_required"];
    if (!allowed.includes(currentStatus)) {
      throw new HttpsError("failed-precondition", "This verification is already waiting for review.");
    }
    if ((currentStatus === "additional_document_required") !== (stage === "additional_document")) {
      throw new HttpsError("failed-precondition", "Use the document submission step shown in the app.");
    }
    action = currentStatus === "not_submitted" ? "verification_submitted" : "verification_resubmitted";
    const previousData = current.verificationData || {};
    const submittedAt = FieldValue.serverTimestamp();
    residentName = requiredText(current.name, "Resident name", 120);
    const verificationData = {
      documentType,
      otherDocumentName,
      documentPath: path,
      frontDocumentPath: request.data?.frontDocumentPath || path,
      backDocumentPath: request.data?.backDocumentPath || "",
      originalSubmittedAt: previousData.originalSubmittedAt
        || previousData.submittedAt
        || current.submittedAt
        || submittedAt,
      submittedAt,
      submissionStage: stage,
      documentCount: request.data?.backDocumentPath ? 2 : 1,
    };
    transaction.update(reference, {
      barangay,
      barangayId,
      contactNumber,
      birthDate,
      verificationData,
      status: "pending_review",
      accountStatus: "active",
      verificationStatus: "submitted",
      submittedAt,
      resubmittedAt: action === "verification_resubmitted" ? submittedAt : FieldValue.delete(),
      reviewedAt: FieldValue.delete(),
      reviewedBy: FieldValue.delete(),
      reviewedByName: FieldValue.delete(),
      reviewReason: FieldValue.delete(),
      reviewNote: FieldValue.delete(),
      rejectionReason: FieldValue.delete(),
      rejectionNote: FieldValue.delete(),
      rejectedAt: FieldValue.delete(),
      rejectedBy: FieldValue.delete(),
      updatedAt: submittedAt,
    });
    transaction.set(
      db.collection("notifications").doc(`verification_submission_${resident.id}`),
      {
        userId: resident.id,
        type: "verification_submitted",
        referenceId: resident.id,
        relatedEntityType: "resident_verification",
        title: action === "verification_resubmitted"
          ? "Verification resubmitted"
          : "Verification submitted",
        message: action === "verification_resubmitted"
          ? "Your updated residency verification was submitted for barangay review."
          : "Your residency verification request was submitted.",
        navigation: { route: "/verification" },
        read: false,
        createdAt: submittedAt,
      },
      { merge: true },
    );
    transaction.set(db.collection("audit_logs").doc(), {
      residentId: resident.id,
      targetUserId: resident.id,
      action: action === "verification_resubmitted"
        ? "ResidentResubmitted"
        : "ResidentVerificationSubmitted",
      actionCode: action,
      performedBy: resident.id,
      performedAt: submittedAt,
      actorId: resident.id,
      entityType: "resident_verification",
      entityId: resident.id,
      barangayId,
      createdAt: submittedAt,
    });
    transaction.set(db.collection("verification_queue_versions").doc(barangayId), {
      barangayId,
      updatedAt: submittedAt,
    }, { merge: true });
  });

  const localProfiles = await profilesForBarangay(barangayId, barangay);
  const reviewers = localProfiles.filter((profile) => isActiveProfile(profile)
    && profileCanVerifyResidents(profile));
  const notificationBatch = db.batch();
  reviewers.forEach((reviewer) => {
    notificationBatch.set(db.collection("notifications").doc(), {
      userId: reviewer.id,
      type: action,
      referenceId: resident.id,
      title: action === "verification_resubmitted"
        ? "Verification resubmitted"
        : "New resident verification",
      message: `${residentName} submitted a verification request for Barangay ${barangay}.`,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  if (reviewers.length) await notificationBatch.commit();
  await sendNormalPushToUsers(reviewers.map((reviewer) => reviewer.id), {
    title: action === "verification_resubmitted"
      ? "Verification resubmitted"
      : "New resident verification",
    body: `A resident from Barangay ${barangay} submitted a verification request.`,
    type: action,
    referenceId: resident.id,
  }).catch((error) => console.error("[VERIFICATION] Reviewer push failed", { code: error.code }));
  console.info("[VERIFICATION] Resident request routed", {
    action,
    barangayId,
    reviewerCount: reviewers.length,
  });
  return { status: "submitted", barangayId };
});

exports.listResidentVerifications = onCall({ region: REGION }, async (request) => {
  const signedInActor = await activeUserCaller(request);
  const oversight = isItAdministrator(signedInActor.role);
  const actor = oversight ? signedInActor : await verificationOfficialCaller(request);
  const profiles = oversight
    ? (await db.collection("users").limit(2000).get()).docs
      .map((snapshot) => ({ id: snapshot.id, ...snapshot.data() }))
    : [...new Map((await Promise.all(actor.verificationBarangayIds.map((id) =>
      profilesForBarangay(id, BARILI_BARANGAYS.find((name) => barangayIdFor(name) === id) || ''))))
      .flat().map((profile) => [profile.id, profile])).values()];
  const residents = profiles.filter((profile) => canonicalRole(profile.role) === "resident");
  const flagCounts = new Map();
  if (!oversight) {
    const flagsByBarangay = await Promise.all(actor.verificationBarangayIds.map((id) =>
      db.collection("concern_flags").where("homeBarangayId", "==", id).get()));
    const residentIds = new Set(residents.map((resident) => resident.id));
    flagsByBarangay.flatMap((snapshot) => snapshot.docs).forEach((flag) => {
      const residentId = String(flag.data().residentId || "");
      if (residentIds.has(residentId)) {
        flagCounts.set(residentId, (flagCounts.get(residentId) || 0) + 1);
      }
    });
  }
  const missingIds = oversight || !actor.barangayId ? [] : residents.filter((profile) => !profile.barangayId);
  for (let offset = 0; offset < missingIds.length; offset += 400) {
    const batch = db.batch();
    missingIds.slice(offset, offset + 400).forEach((profile) => {
      batch.set(db.collection("users").doc(profile.id), {
        barangayId: actor.barangayId,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    await batch.commit();
  }
  const counts = { pending: 0, verified: 0, needsResubmission: 0 };
  residents.forEach((resident) => {
    const status = verificationStatusForProfile(resident);
    if (isReviewableVerification(status)) counts.pending += 1;
    if (status === "verified") counts.verified += 1;
    if (["rejected", "additional_document_required"].includes(status)) counts.needsResubmission += 1;
  });
  const profilesById = new Map(profiles.map((profile) => [profile.id, profile]));
  const missingReviewerIds = [...new Set(residents.map((resident) => resident.verifiedBy)
    .filter((id) => typeof id === "string" && id.length > 0 && !id.includes("/")))]
    .filter((id) => !profilesById.has(id));
  for (let offset = 0; offset < missingReviewerIds.length; offset += 100) {
    const snapshots = await db.getAll(...missingReviewerIds.slice(offset, offset + 100)
      .map((id) => db.collection("users").doc(id)));
    snapshots.forEach((snapshot) => {
      if (snapshot.exists) profilesById.set(snapshot.id, { id: snapshot.id, ...snapshot.data() });
    });
  }
  const reviewerName = (reviewerId, storedName) => storedName
    || profilesById.get(reviewerId)?.name
    || profilesById.get(reviewerId)?.email
    || "";
  const scopedResidents = residents
    .filter((resident) => verificationStatusForProfile(resident) !== "not_submitted")
    .map((resident) => {
      const verification = resident.verificationData || {};
      const reviewReason = resident.reviewReason
        || resident.rejectionReason
        || resident.reviewNote
        || "";
      return {
        id: resident.id,
        name: resident.name || "",
        email: resident.email || "",
        role: "resident",
        accountStatus: resident.accountStatus || "",
        status: resident.status || "",
        statusReason: oversight ? resident.statusReason || "" : "",
        barangay: resident.barangay || "",
        barangayId: effectiveBarangayId(resident),
        address: resident.address || "",
        contactNumber: resident.contactNumber || "",
        birthDate: resident.birthDate || "",
        createdAt: timestampMillis(resident.createdAt),
        submittedAt: timestampMillis(resident.submittedAt || verification.submittedAt),
        verificationStatus: verificationStatusForProfile(resident),
        concernFlagCount: flagCounts.get(resident.id) || 0,
        restrictionStatus: resident.restrictionStatus || "",
        restrictionEndDate: timestampMillis(resident.restrictionEndDate),
        restrictionReason: resident.restrictionReason || "",
        verifiedAt: timestampMillis(resident.verifiedAt),
        verifiedBy: resident.verifiedBy || "",
        verifiedByRole: resident.verifiedByRole || profilesById.get(resident.verifiedBy)?.role || "",
        verifiedByName: reviewerName(resident.verifiedBy, resident.verifiedByName),
        reviewedAt: timestampMillis(resident.reviewedAt || resident.rejectedAt),
        reviewedBy: resident.reviewedBy || resident.rejectedBy || "",
        reviewedByName: reviewerName(
          resident.reviewedBy || resident.rejectedBy,
          resident.reviewedByName,
        ),
        rejectedAt: timestampMillis(resident.rejectedAt),
        reviewReason,
        reviewAdditionalNote: resident.reviewReason
          ? resident.reviewNote || ""
          : resident.rejectionNote || "",
        rejectionReason: "",
        rejectionNote: "",
        reviewNote: "",
        verificationData: {
          residentName: verification.residentName || resident.name || "",
          residentialAddress: verification.residentialAddress || resident.address || "",
          contactNumber: verification.contactNumber || resident.contactNumber || "",
          birthDate: resident.birthDate || "",
          documentType: verification.documentType || "",
          otherDocumentName: verification.otherDocumentName || "",
          documentPath: verification.documentPath || "",
          additionalDocumentType: verification.additionalDocumentType || "",
          additionalDocumentPath: verification.additionalDocumentPath || "",
          submittedAt: timestampMillis(verification.submittedAt),
          submissionStage: verification.submissionStage || "",
        },
      };
    });
  const reviewers = profiles
    .filter((profile) => BARANGAY_ROLES.has(canonicalRole(profile.role)) && isActiveProfile(profile))
    .map((profile) => ({
      id: profile.id,
      name: profile.name || profile.email || "Barangay staff",
      role: canonicalRole(profile.role),
      canVerifyResidents: profileCanVerifyResidents(profile),
    }));
  return {
    barangay: oversight ? "All Barili" : actor.barangay || "Assigned barangays",
    barangayId: oversight ? "" : actor.barangayId,
    allowedBarangayIds: oversight ? [] : actor.verificationBarangayIds,
    oversight,
    counts,
    residents: scopedResidents,
    reviewers,
  };
});

exports.reviewResidentVerification = onCall({ region: REGION }, async (request) => {
  const started = Date.now();
  const signedInActor = await activeUserCaller(request);
  const oversight = isItAdministrator(signedInActor.role);
  const actor = oversight ? signedInActor : await verificationOfficialCaller(request, signedInActor);
  const residentId = requiredText(request.data?.residentId, "Resident", 160);
  const decision = String(request.data?.decision || "").trim().toLowerCase();
  if (!["approved", "additional_document_required", "rejected"].includes(decision)) {
    throw new HttpsError("invalid-argument", "Choose Verify Resident, Needs Attention, or Reject.");
  }
  const rejectionReason = optionalText(request.data?.rejectionReason, 120);
  const rejectionNote = optionalText(request.data?.rejectionNote, 600);
  if (decision === "additional_document_required"
    && !isValidVerificationAttentionReason(rejectionReason)) {
    throw new HttpsError("invalid-argument", "Select a valid needs-attention reason.");
  }
  if (decision === "rejected"
    && !isValidVerificationRejectionReason(rejectionReason) && !rejectionReason) {
    throw new HttpsError("invalid-argument", "Select a valid rejection reason.");
  }
  if (["additional_document_required", "rejected"].includes(decision)
    && rejectionReason === "Other" && !rejectionNote) {
    throw new HttpsError("invalid-argument", "Add a short note explaining what needs attention.");
  }
  const reference = db.collection("users").doc(residentId);
  const now = FieldValue.serverTimestamp();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const resident = snapshot.data();
    if (!snapshot.exists || canonicalRole(resident?.role) !== "resident") {
      throw new HttpsError("not-found", "The resident verification was not found.");
    }
    if (!isActiveProfile(resident)) {
      throw new HttpsError("failed-precondition", "Restore the resident account before reviewing its verification.");
    }
    const residentBarangayId = effectiveBarangayId(resident);
    const residentBarangay = canonicalBarangayName(resident.barangay);
    if (!residentBarangayId || !residentBarangay
      || residentBarangayId !== barangayIdFor(residentBarangay)) {
      throw new HttpsError("failed-precondition", "The resident does not have a valid barangay assignment.");
    }
    if (!oversight && !actor.verificationBarangayIds.includes(residentBarangayId)) {
      throw new HttpsError("permission-denied", "You cannot review a resident from another barangay.");
    }
    if (!isReviewableVerification(verificationStatusForProfile(resident))) {
      throw new HttpsError("failed-precondition", "This verification request has already been reviewed.");
    }
    const verified = decision === "approved";
    const rejected = decision === "rejected";
    const message = verified
      ? `Your residency has been verified by Barangay ${residentBarangay}.`
      : rejected
        ? `Your residency verification was rejected by Barangay ${residentBarangay}. Reason: ${rejectionReason}.`
        : `Your residency could not yet be confirmed. Reason: ${rejectionReason}.`;
    const verifiedBarangayId = residentBarangayId;
    queueWebNotification(transaction, {
      kind: "push", userIds: [residentId], type: "verification_update", referenceId: residentId,
      title: verified ? "Account verified" : rejected ? "Verification rejected" : "Verification needs attention",
      body: verified
        ? oversight ? "Your residency has been verified by the LGU IT Department." : `Your residency has been verified by Barangay ${actor.barangay}.`
        : rejected ? `Your residency verification was rejected. Reason: ${rejectionReason}.`
          : `Your residency needs attention. Reason: ${rejectionReason}.`,
    });
    transaction.update(reference, {
      status: verified ? "approved" : rejected ? "rejected" : decision,
      accountStatus: rejected ? "rejected" : "active",
      verificationStatus: verified ? "verified" : rejected ? "rejected" : decision,
      reviewedAt: now,
      reviewedBy: actor.id,
      reviewedByName: actor.name || actor.email || (oversight ? "LGU IT administrator" : "Barangay reviewer"),
      reviewReason: verified ? FieldValue.delete() : rejectionReason,
      reviewNote: verified ? FieldValue.delete() : rejectionNote,
      ...(verified ? {
        verifiedAt: now,
        verifiedBy: actor.id,
        verifiedByRole: actor.role,
        verifiedByName: actor.name || actor.email || (oversight ? "LGU IT administrator" : "Barangay reviewer"),
        verifiedBarangayId,
        approvedAt: now,
        verificationApprovedAt: now,
        needsAttentionAt: FieldValue.delete(),
        rejectionReason: FieldValue.delete(),
        rejectionNote: FieldValue.delete(),
        rejectedAt: FieldValue.delete(),
        rejectedBy: FieldValue.delete(),
        rejectedByName: FieldValue.delete(),
      } : rejected ? {
        rejectedAt: now,
        rejectedBy: actor.id,
        rejectedByName: actor.name || actor.email || (oversight ? "LGU IT administrator" : "Barangay reviewer"),
        rejectionReason,
        rejectionNote: rejectionNote || "",
        needsAttentionAt: FieldValue.delete(),
        verifiedAt: FieldValue.delete(),
        verifiedBy: FieldValue.delete(),
        verifiedByRole: FieldValue.delete(),
        verifiedByName: FieldValue.delete(),
        verifiedBarangayId: FieldValue.delete(),
      } : {
        needsAttentionAt: now,
        verifiedAt: FieldValue.delete(),
        verifiedBy: FieldValue.delete(),
        verifiedByRole: FieldValue.delete(),
        verifiedByName: FieldValue.delete(),
        verifiedBarangayId: FieldValue.delete(),
        rejectionReason: FieldValue.delete(),
        rejectionNote: FieldValue.delete(),
        rejectedAt: FieldValue.delete(),
        rejectedBy: FieldValue.delete(),
        rejectedByName: FieldValue.delete(),
      }),
      updatedAt: now,
    });
    transaction.set(db.collection("notifications").doc(), {
      userId: residentId,
      type: "verification_update",
      referenceId: residentId,
      relatedEntityType: "resident_verification",
      title: verified ? "Account verified" : rejected ? "Verification rejected" : "Verification needs attention",
      message,
      reason: verified ? "" : (rejectionReason || rejectionNote),
      navigation: { route: "/verification" },
      read: false,
      createdAt: now,
    });
    transaction.set(db.collection("audit_logs").doc(), {
      residentId,
      targetUserId: residentId,
      action: verified ? "ResidentVerified" : rejected ? "ResidentRejected" : "ResidentNeedsAttention",
      actionCode: verified ? "verification_approved" : rejected ? "verification_rejected" : "verification_resubmission_requested",
      performedBy: actor.id,
      performedAt: now,
      actorId: actor.id,
      actorEmail: actor.email || "",
      entityType: "resident_verification",
      entityId: residentId,
      barangayId: residentBarangayId,
      reason: verified ? "" : rejectionReason,
      details: { reviewNote: verified ? "" : rejectionNote },
      createdAt: now,
    });
    transaction.set(db.collection("verification_queue_versions").doc(residentBarangayId), {
      barangayId: residentBarangayId,
      updatedAt: now,
    }, { merge: true });
  });
  const verified = decision === "approved";
  console.info("[VERIFICATION] Review completed", {
    decision,
    reviewerId: actor.id,
    durationMs: Date.now() - started,
  });
  return { residentId, status: verified ? "verified" : decision };
});

exports.getVerificationDocumentUrl = onCall({ region: REGION }, async (request) => {
  const signedInActor = await activeUserCaller(request);
  const oversight = isItAdministrator(signedInActor.role);
  const actor = oversight ? signedInActor : await verificationOfficialCaller(request);
  const residentId = requiredText(request.data?.residentId, 'Resident', 160);
  const slot = String(request.data?.slot || 'primary');
  if (!['primary', 'additional'].includes(slot)) throw new HttpsError('invalid-argument', 'Choose a document.');
  const snapshot = await db.collection('users').doc(residentId).get();
  const resident = snapshot.data();
  if (!snapshot.exists || canonicalRole(resident?.role) !== 'resident') {
    throw new HttpsError('not-found', 'Resident verification not found.');
  }
  if (!oversight && !actor.verificationBarangayIds.includes(effectiveBarangayId(resident))) {
    throw new HttpsError('permission-denied', 'This resident is outside your verification area.');
  }
  const path = slot === 'additional' ? resident.verificationData?.additionalDocumentPath
    : resident.verificationData?.documentPath;
  const stage = slot === 'additional' ? 'additional_document' : 'initial_document';
  const validPath = verificationDocumentPath(residentId, path, stage);
  const file = getStorage().bucket().file(validPath);
  try {
    const [metadata] = await file.getMetadata();
    const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + 5 * 60 * 1000 });
    return {
      url, contentType: metadata.contentType || '', size: Number(metadata.size) || 0,
      name: validPath.split('/').pop()
    };
  } catch (error) {
    console.error('[VERIFICATION] Document link failed', { code: error.code });
    throw new HttpsError('unavailable', 'The verification document could not be opened right now.');
  }
});

exports.setResidentVerificationPermission = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const targetId = requiredText(request.data?.userId, "Barangay staff account", 160);
  const enabled = request.data?.canVerifyResidents === true;
  const targetReference = db.collection("users").doc(targetId);
  const targetSnapshot = await targetReference.get();
  const target = targetSnapshot.data();
  if (!targetSnapshot.exists || !BARANGAY_ROLES.has(canonicalRole(target?.role))) {
    throw new HttpsError("not-found", "The barangay staff account was not found.");
  }
  const targetBarangayId = effectiveBarangayId(target);
  const actorCanDelegate = isItAdministrator(actor.role)
    || (actor.role === "barangay_captain"
      && await actorCan(actor, 'verifications:local')
      && effectiveBarangayId(actor) === targetBarangayId);
  if (!actorCanDelegate) {
    throw new HttpsError("permission-denied", "Only LGU IT or the assigned barangay captain can delegate verification.");
  }
  if (actor.id === targetId && !enabled) {
    throw new HttpsError("failed-precondition", "You cannot remove your own verification permission.");
  }
  if (!enabled && defaultResidentVerificationPermission({ role: canonicalRole(target.role) })) {
    throw new HttpsError("failed-precondition", "This position verifies its own barangay by default. LGU IT can manage office-wide verification access.");
  }
  const now = FieldValue.serverTimestamp();
  const batch = db.batch();
  batch.set(targetReference, {
    barangayId: targetBarangayId,
    canVerifyResidents: enabled,
    updatedAt: now,
    updatedBy: actor.id,
  }, { merge: true });
  batch.set(db.collection("audit_logs").doc(), {
    action: "verification_permission_updated",
    performedBy: actor.id,
    actorId: actor.id,
    entityType: "user",
    entityId: targetId,
    barangayId: targetBarangayId,
    details: { canVerifyResidents: enabled },
    createdAt: now,
  });
  await batch.commit();
  return { userId: targetId, canVerifyResidents: enabled };
});

function requestedRolesFor(actor) {
  if (actor.role === "lgu" && effectiveDepartmentId(actor)) return new Set(["lgu"]);
  if (BARANGAY_ROLES.has(actor.role)
    && effectiveBarangayId(actor)) return new Set(["barangay_councilor"]);
  if (actor.role === "organization" && String(actor.organizationId || "").trim()) {
    return new Set(["organization"]);
  }
  return new Set();
}

function accountRequestStatus(value) {
  const status = String(value || "").trim().toLowerCase().replace(/[ -]+/g, "_");
  if (["pending_approval", "pending_review"].includes(status)) return "pending";
  return status;
}

function isOpenAccountRequest(profile) {
  return ["pending", "reviewing"].includes(accountRequestStatus(
    profile?.accountStatus || profile?.status,
  ));
}

function staffScope(actor, input, role) {
  if (BARANGAY_ROLES.has(role)) {
    // Municipal creators choose an assignment. Barangay requesters always use
    // their server-side profile; a client-sent barangay or barangayId is ignored.
    const municipalCreator = isMunicipalRole(actor.role);
    const requestedBarangay = municipalCreator
      ? requiredText(input.barangay, "Barangay", 80)
      : requiredText(actor.barangay, "Barangay", 80);
    const barangay = canonicalBarangayName(requestedBarangay);
    const barangayId = municipalCreator ? barangayIdFor(barangay) : effectiveBarangayId(actor);
    if (!barangay || !barangayId) {
      throw new HttpsError("invalid-argument", "Select a valid Barili barangay.");
    }
    return { barangay, barangayId, organizationId: "", organizationName: "" };
  }
  if (role === "organization") {
    const organizationName = isMunicipalRole(actor.role)
      ? ""
      : requiredText(actor.organizationName, "Organization", 140);
    const organizationId = isMunicipalRole(actor.role)
      ? requiredText(input.organizationId, "Organization", 80)
      : requiredText(actor.organizationId || organizationKey(organizationName), "Organization", 80);
    if (!organizationId) throw new HttpsError("invalid-argument", "Organization is required.");
    return { barangay: "", barangayId: "", organizationId, organizationName };
  }
  return { barangay: "", barangayId: "", organizationId: "", organizationName: "" };
}

async function provisionStaffAccount(actor, input) {
  const role = canonicalRole(input.role);
  if (!STAFF_ROLES.has(role)) throw new HttpsError("invalid-argument", "Select a valid staff role.");
  const distributionMethod = ["email", "personal"].includes(input.distributionMethod)
    ? input.distributionMethod
    : "personal";
  const email = normalizedGmailEmail(input.email);
  const firstName = optionalText(input.firstName, 80);
  const middleName = optionalText(input.middleName, 80);
  const lastName = optionalText(input.lastName, 80);
  const extensionName = optionalText(input.extensionName, 10);
  if (extensionName && !["Jr.", "Sr.", "II", "III", "IV"].includes(extensionName)) {
    throw new HttpsError("invalid-argument", "Select a valid name extension.");
  }
  const name = firstName || lastName
    ? requiredText([firstName, middleName, lastName, extensionName].filter(Boolean).join(" "), "Full name", 120)
    : requiredText(input.name, "Full name", 120);
  if ((firstName || lastName) && (!firstName || !lastName)) {
    throw new HttpsError("invalid-argument", "Enter the account holder's first and last name.");
  }
  const temporaryPassword = input.temporaryPassword
    ? requiredTemporaryPassword(input.temporaryPassword)
    : generatedTemporaryPassword();
  if (role === "organization" && isMunicipalRole(actor.role) && !String(input.organizationId || "").trim()) {
    throw new HttpsError("invalid-argument", "Select an existing organization.");
  }
  const scope = staffScope(actor, input, role);
  const lguDepartment = role === "lgu"
    ? await lguDepartmentForAccount(actor, input)
    : { id: "", name: "", publicName: "" };
  const canVerifyResidents = BARANGAY_ROLES.has(role)
    && (typeof input.canVerifyResidents === "boolean"
      ? input.canVerifyResidents
      : ["barangay_captain", "barangay_vice_captain", "barangay_secretary"].includes(role));
  const department = role === "lgu" ? lguDepartment.name : "";
  const lguService = role === "lgu"
    ? LGU_SERVICE_TYPES.find((item) => item.id === input.lguServiceTypeId) : null;
  if (role === "lgu" && input.lguServiceTypeId && !lguService) {
    throw new HttpsError("invalid-argument", "Select a valid LGU service type.");
  }
  const routingCategoryId = role === "lgu"
    ? String(input.routingCategoryId || lguService?.categoryId || "").trim() : "";
  if (routingCategoryId && !concernCategory(routingCategoryId)) {
    throw new HttpsError("invalid-argument", "Select a valid concern-routing category.");
  }
  if (role === "lgu" && lguService && !routingCategoryId) {
    throw new HttpsError("invalid-argument", "Select the internal routing category for this LGU service.");
  }
  const positionId = BARANGAY_ROLES.has(role)
    ? String(input.positionId || input.positionCode || role).trim() : "";
  const position = positionId ? positionDefinition(positionId) : null;
  if (BARANGAY_ROLES.has(role) && (!position || position.role !== role)) {
    throw new HttpsError("invalid-argument", "Select a valid barangay position.");
  }
  const positionTitle = ["organization", "lgu"].includes(role)
    ? requiredText(input.positionTitle || (role === "organization" ? "Organization Staff" : ""), "Role / Designation", 120)
    : positionId === "other_position"
      ? requiredText(input.otherPosition || input.positionTitle, "Position", 120)
      : position?.name || positionForRole(role);
  const contactEmail = String(input.contactEmail || "").trim()
    ? normalizedEmail(input.contactEmail)
    : "";
  const contactNumber = String(input.contactNumber || "").trim()
    ? requiredPhilippineMobile(input.contactNumber)
    : "";
  const recipientEmail = distributionMethod === "email"
    ? normalizedGmailEmail(input.recipientEmail)
    : "";
  const optionalMessage = String(input.optionalMessage || "").trim().slice(0, 800);
  let organizationType = "";
  let coverageArea = "";
  if (role === "mayor") {
    const existingMayor = await db.collection("users")
      .where("role", "in", ["mayor", "municipal_mayor"])
      .limit(10)
      .get();
    const duplicate = existingMayor.docs.some((snapshot) => {
      const existingProfile = snapshot.data();
      return !["disabled", "deactivated", "rejected", "suspended"].includes(
        String(existingProfile.accountStatus || existingProfile.status || "").toLowerCase(),
      );
    });
    if (duplicate) {
      throw new HttpsError("already-exists", "An active Municipal Mayor account already exists.");
    }
  }
  const organizationReference = scope.organizationId
    ? db.collection("organizations").doc(scope.organizationId)
    : null;
  const organizationSnapshot = organizationReference ? await organizationReference.get() : null;
  const organizationExists = organizationSnapshot?.exists === true;
  let organizationCategoryId = "";
  let organizationSector = "";
  let organizationAddress = "";
  let previousOrganizationCategoryId = "";
  let previousOrganizationSector = "";
  if (role === "organization") {
    if (!organizationExists) {
      throw new HttpsError("invalid-argument", "Select an existing organization.");
    }
    const organization = organizationSnapshot.data() || {};
    if (!["verified", "active"].includes(String(organization.status || "").toLowerCase())) {
      throw new HttpsError("failed-precondition", "Select an active organization.");
    }
    previousOrganizationCategoryId = canonicalConcernCategoryId(String(organization.organizationTypeId || organization.categoryId || "").trim());
    previousOrganizationSector = String(organization.organizationSector || "").trim();
    if ((Object.prototype.hasOwnProperty.call(input, "expectedOrganizationTypeId")
      && canonicalConcernCategoryId(String(input.expectedOrganizationTypeId || "")) !== previousOrganizationCategoryId)
      || (Object.prototype.hasOwnProperty.call(input, "expectedOrganizationSector")
        && String(input.expectedOrganizationSector || "") !== previousOrganizationSector)) {
      throw new HttpsError("failed-precondition", "This organization changed in Structure. Reopen the form and try again.");
    }
    const selectedType = concernCategory(String(input.organizationTypeId || input.categoryId || previousOrganizationCategoryId).trim());
    if (!selectedType || (input.organizationSector && input.organizationSector !== selectedType.sector)) {
      throw new HttpsError("invalid-argument", "Select an organization type from the chosen sector.");
    }
    organizationCategoryId = selectedType.id;
    organizationSector = selectedType.sector;
    organizationAddress = requiredText(input.organizationAddress, "Organization address", 200);
    scope.organizationName = requiredText(organization.name, "Organization", 140);
    organizationType = selectedType.name;
    coverageArea = optionalText(organization.coverageArea, 160);
  }
  let userRecord;
  try {
    userRecord = await getAuth().createUser({
      email,
      emailVerified: false,
      displayName: name,
      password: temporaryPassword,
      disabled: false,
    });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This email is already associated with an E-SUGID account.");
    }
    throw new HttpsError("internal", "The staff account could not be created.");
  }

  const now = FieldValue.serverTimestamp();
  const activationExpiresAt = new Date(Date.now() + ACTIVATION_LIFETIME_MS);
  const profile = {
    uid: userRecord.uid,
    name,
    firstName, middleName, lastName, extensionName,
    email,
    username: "",
    role,
    positionTitle,
    positionId,
    positionCode: role === "barangay_councilor" ? positionId : "",
    department,
    departmentId: lguDepartment.id,
    departmentPublicName: lguDepartment.publicName,
    officeId: lguDepartment.id,
    lguServiceTypeId: lguService?.id || "",
    lguServiceType: lguService?.name || "",
    lguServiceDescription: lguService?.id === "other_lgu_service" ? optionalText(input.lguServiceDescription, 120) : "",
    routingCategoryId: role === "organization" ? organizationCategoryId : routingCategoryId,
    contactEmail,
    contactNumber,
    status: ACTIVE_STATUS,
    accountStatus: "active",
    verificationStatus: "not_applicable",
    approvalRequired: false,
    creationSource: "admin_direct",
    setupRequired: true,
    activationExpiresAt,
    accessMethod: distributionMethod === "email" ? "Email" : "Personal",
    distributionMethod,
    recipientEmail,
    optionalMessage,
    emailDeliveryStatus: distributionMethod === "email" ? "sending" : "not_requested",
    barangay: scope.barangay,
    barangayId: scope.barangayId,
    canVerifyResidents,
    canCreateBarangayOfficialRequests: false,
    organizationId: scope.organizationId,
    organizationName: scope.organizationName,
    organizationCategoryId,
    organizationType,
    ...(role === "organization" ? {
      organizationSector,
      organizationTypeId: organizationCategoryId,
      organizationAddress,
    } : {}),
    coverageArea,
    createdAt: now,
    createdBy: actor.id,
    approvedAt: now,
    approvedBy: actor.id,
  };
  const audit = {
    targetUserId: userRecord.uid,
    performedBy: actor.id,
    requestedRole: role,
    barangayId: scope.barangayId,
    departmentId: lguDepartment.id,
    organizationId: scope.organizationId,
    actorId: actor.id,
    actorEmail: actor.email || "",
    action: "staff_account_created",
    entityType: "user",
    entityId: userRecord.uid,
    details: {
      role,
      barangay: scope.barangay,
      barangayId: scope.barangayId,
      canVerifyResidents,
      organizationId: scope.organizationId,
      ...(role === "organization" ? {
        organizationSector,
        organizationTypeId: organizationCategoryId,
        previousOrganizationTypeId: previousOrganizationCategoryId,
      } : {}),
      departmentId: lguDepartment.id,
    },
    createdAt: now,
  };
  try {
    await db.runTransaction(async (transaction) => {
      if (positionId) await requireAvailablePosition(transaction, scope.barangayId, positionId);
      if (scope.organizationId) {
        const latestOrganization = await transaction.get(organizationReference);
        const latest = latestOrganization.data();
        if (!latestOrganization.exists || !["verified", "active"].includes(String(latest.status || "").toLowerCase())
          || canonicalConcernCategoryId(String(latest.organizationTypeId || latest.categoryId || "")) !== previousOrganizationCategoryId
          || String(latest.organizationSector || "") !== previousOrganizationSector) {
          throw new HttpsError("failed-precondition", "This organization changed in Structure. Reopen the form and try again.");
        }
        const changingType = previousOrganizationCategoryId !== organizationCategoryId
          || (previousOrganizationSector && previousOrganizationSector !== organizationSector);
        if (changingType) {
          const members = await transaction.get(db.collection("users").where("organizationId", "==", scope.organizationId));
          if (members.docs.some((member) => isActiveProfile(member.data())
            && canonicalRole(member.data().role) === "organization")) {
            throw new HttpsError("failed-precondition", "This organization has active accounts. Change its type in Structure before adding another account.");
          }
          const concerns = await transaction.get(db.collection("submissions")
            .where("organizationIds", "array-contains", scope.organizationId));
          if (concerns.docs.some((concern) => !["resolved", "closed", "rejected"]
            .includes(String(concern.data().status || "").toLowerCase()))) {
            throw new HttpsError("failed-precondition", "Resolve or reassign this organization's active concerns before changing its type.");
          }
        }
      }
      transaction.create(db.collection("users").doc(userRecord.uid), profile);
      if (scope.organizationId) {
        transaction.set(organizationReference, {
          address: organizationAddress,
          categoryId: organizationCategoryId,
          organizationTypeId: organizationCategoryId,
          organizationTypeName: organizationType,
          organizationType,
          organizationSector,
          updatedAt: now,
          updatedBy: actor.id,
        }, { merge: true });
      }
      transaction.create(db.collection("audit_logs").doc(), audit);
    });
  } catch (error) {
    await getAuth().deleteUser(userRecord.uid).catch(() => { });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "The staff profile could not be saved.");
  }
  let emailDeliveryStatus = "not_requested";
  let emailDeliveryReason = "";
  if (distributionMethod === "email") {
    try {
      const mailResult = await sendStaffCredentialsEmail({
        recipientEmail,
        loginEmail: email,
        temporaryPassword,
        name,
        role,
        assignment: staffAssignment(profile),
        positionTitle,
        loginUrl: configuredAppBaseUrl(),
        optionalMessage,
      });
      emailDeliveryStatus = "sent";
      await db.collection("users").doc(userRecord.uid).set({
        accessMethod: "Email",
        distributionMethod: "email",
        recipientEmail,
        emailDeliveryStatus,
        activationSentAt: FieldValue.serverTimestamp(),
        emailSentAt: FieldValue.serverTimestamp(),
        emailProviderMessageId: mailResult.messageId,
        emailDeliveryErrorCode: FieldValue.delete(),
        emailDeliveryError: FieldValue.delete(),
      }, { merge: true });
    } catch (error) {
      const failure = mailFailureDetails(error);
      console.error("[EMAIL] Account email failed", {
        uid: userRecord.uid,
        recipient: recipientEmail,
        ...failure,
      });
      emailDeliveryStatus = "failed";
      emailDeliveryReason = failure.reason;
      await db.collection("users").doc(userRecord.uid).set({
        accessMethod: "Email",
        distributionMethod: "email",
        recipientEmail,
        emailDeliveryStatus,
        emailDeliveryFailedAt: FieldValue.serverTimestamp(),
        emailDeliveryErrorCode: failure.reason,
        emailDeliveryError: mailFailureMessage(failure.reason),
      }, { merge: true });
    }
  }
  return {
    uid: userRecord.uid,
    email,
    username: "",
    temporaryPassword,
    emailDeliveryStatus,
    emailDeliveryReason,
    accountStatus: "active",
  };
}

function topicForBarangay(barangay) {
  return `barangay_${String(barangay || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")}`;
}

function audienceKeysForPost(post) {
  if (!post || !["approved", "published"].includes(post.status)) return [];
  if (post.visibility === "public") return ["municipality:barili"];
  const targets = Array.isArray(post.targetBarangays)
    ? post.targetBarangays
    : post.targetBarangay
      ? [post.targetBarangay]
      : [];
  return [...new Set(targets.filter(Boolean).map((barangay) => `barangay:${barangay}`))];
}

async function syncPostFeeds(postId, before, after) {
  const oldKeys = new Set([
    ...(Array.isArray(before?.audienceKeys) ? before.audienceKeys : []),
    ...audienceKeysForPost(before),
  ]);
  const newKeys = new Set([
    ...(Array.isArray(after?.audienceKeys) ? after.audienceKeys : []),
    ...audienceKeysForPost(after),
  ]);
  if (!after || !["approved", "published"].includes(after.status)) newKeys.clear();

  const allKeys = new Set([...oldKeys, ...newKeys]);
  if (!allKeys.size) return;
  const batch = db.batch();
  for (const audienceKey of allKeys) {
    const feedRef = db
      .collection("announcement_feeds")
      .doc(audienceKey)
      .collection("posts")
      .doc(postId);
    if (newKeys.has(audienceKey)) {
      batch.set(feedRef, {
        ...after,
        audienceKeys: [...newKeys],
        sourcePostId: postId,
      });
    } else {
      batch.delete(feedRef);
    }
  }
  await batch.commit();
}

async function commitInChunks(documents, updateFor, auditAction) {
  for (let offset = 0; offset < documents.length; offset += 400) {
    const batch = db.batch();
    for (const snapshot of documents.slice(offset, offset + 400)) {
      batch.update(snapshot.ref, updateFor(snapshot));
      const auditRef = db.collection("audit_logs").doc();
      batch.set(auditRef, {
        action: auditAction,
        targetType: auditAction.startsWith("emergency_alert") ? "alert" : "post",
        targetId: snapshot.id,
        actorId: "system",
        actorEmail: "Automated publishing service",
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

function emergencyStatusId(emergencyId, residentId) {
  return `${emergencyId}_${residentId}`;
}

function emergencyNotificationId(emergencyId, residentId) {
  return `emergency_${emergencyId}_${residentId}`;
}

function emergencyPublisherAllowed(actor) {
  return isItAdministrator(actor.role)
    || ["barangay_captain", "barangay_vice_captain", "barangay_secretary"].includes(actor.role)
    || (canonicalRole(actor.role) === "organization" && (actor.canSendEmergencyAlerts === true || actor.organizationSector === "public" || actor.sector === "public"));
}

async function emergencyTargetBarangays(actor, input) {
  if (BARANGAY_ROLES.has(actor.role)) {
    return [requiredText(actor.barangay, "Barangay", 80)];
  }
  if (canonicalRole(actor.role) === "organization") {
    const organizationId = requiredText(actor.organizationId, "Organization", 160);
    const organization = await db.collection("organizations").doc(organizationId).get();
    if (!organization.exists || organization.data().status !== "verified") {
      throw new HttpsError("failed-precondition", "The organization is not verified.");
    }
    const orgData = organization.data();
    const isPublic = (orgData.organizationSector || actor.organizationSector || "public") === "public";
    if (isPublic && (String(input.audience || "").toLowerCase() === "municipality" || !orgData.serviceBarangays || !orgData.serviceBarangays.length)) {
      return [];
    }
    const allowed = Array.isArray(orgData.serviceBarangays)
      ? orgData.serviceBarangays.map((value) => String(value)) : [];
    const requested = Array.isArray(input.targetBarangays)
      ? [...new Set(input.targetBarangays.map((value) => String(value || "").trim()).filter(Boolean))]
      : [];
    if (!requested.length || requested.some((barangay) => !allowed.includes(barangay))) {
      if (isPublic) return [];
      throw new HttpsError("permission-denied", "Emergency alerts must stay within the organization's approved service area.");
    }
    return requested;
  }
  if (String(input.audience || "").toLowerCase() === "municipality") return [];
  const targetBarangays = Array.isArray(input.targetBarangays)
    ? [...new Set(input.targetBarangays.map((value) => String(value || "").trim()).filter(Boolean))]
    : [];
  if (!targetBarangays.length || targetBarangays.length > 42) {
    throw new HttpsError("invalid-argument", "Choose at least one affected barangay.");
  }
  return targetBarangays;
}

function optionalText(value, maxLength) {
  return String(value || "").trim().slice(0, maxLength);
}

function emergencyDate(value, field, { optional = false, future = false } = {}) {
  if (!value && optional) return null;
  const date = new Date(value || Date.now());
  if (!Number.isFinite(date.getTime())) throw new HttpsError("invalid-argument", `${field} is invalid.`);
  if (future && date.getTime() <= Date.now()) {
    throw new HttpsError("invalid-argument", `${field} must be in the future.`);
  }
  return date;
}

exports.publishEmergencyAlert = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, 'alerts:publish')) {
    throw new HttpsError("permission-denied", "You are not authorized to publish emergency alerts.");
  }
  const input = request.data || {};
  // Older admin tabs may still call this function without a request ID.
  const requestId = input.requestId == null ? randomBytes(16).toString("hex")
    : requiredText(input.requestId, "Alert request ID", 80);
  if (!/^(?:[a-f0-9]{32}|[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12})$/i.test(requestId)) {
    throw new HttpsError("invalid-argument", "Alert request ID is invalid.");
  }
  const severity = canonicalSeverity(input.severity);
  const title = requiredText(input.title, "Emergency title", 100);
  const message = requiredText(input.message || input.description, "Description", 600);
  const instructions = requiredText(input.instructions, "Emergency instructions", 600);
  const alertType = requiredText(input.alertType || "Emergency", "Emergency type", 80);
  const targetBarangays = await emergencyTargetBarangays(actor, input);
  const visibility = targetBarangays.length ? "targeted" : "public";
  const startAt = emergencyDate(input.startAt, "Start time");
  const expiresAt = emergencyDate(input.expiresAt, "Expiration time", { optional: true, future: true });
  if (expiresAt && expiresAt.getTime() <= startAt.getTime()) {
    throw new HttpsError("invalid-argument", "Expiration must be after the start time.");
  }
  const ref = db.collection("alerts").doc(`${actor.id}_${requestId}`);
  const alert = {
    schemaVersion: 2,
    id: ref.id,
    alertType,
    title,
    message,
    instructions,
    evacuationInfo: optionalText(input.evacuationInfo, 600),
    emergencyContacts: optionalText(input.emergencyContacts, 400),
    sourceName: optionalText(input.sourceName, 100) || (actor.barangay ? `Barangay ${actor.barangay}` : "Municipality of Barili"),
    severity,
    category: "Emergency",
    audience: visibility === "public" ? "municipality" : "targeted",
    targetBarangay: visibility === "public" ? "All Barangays" : targetBarangays[0],
    targetBarangays,
    audienceKeys: visibility === "public"
      ? ["municipality:barili"]
      : targetBarangays.map((barangay) => `barangay:${barangay}`),
    visibility,
    startAt: startAt.toISOString(),
    expiresAt: expiresAt?.toISOString() || null,
    active: true,
    status: "active",
    notificationRequested: true,
    notificationState: "pending",
    stats: {
      targeted: 0,
      delivered: 0,
      deviceTokens: 0,
      fcmAccepted: 0,
      fcmFailed: 0,
      opened: 0,
      acknowledged: 0,
    },
    createdAt: FieldValue.serverTimestamp(),
    publishedAt: FieldValue.serverTimestamp(),
    createdBy: actor.id,
    createdByName: actor.name || actor.email || "E-SUGID Administrator",
    barangayId: actor.barangayId || "",
    organizationId: canonicalRole(actor.role) === "organization" ? String(actor.organizationId || "") : "",
  };
  const created = await db.runTransaction(async (transaction) => {
    if ((await transaction.get(ref)).exists) return false;
    transaction.create(ref, alert);
    transaction.create(db.collection("audit_logs").doc(), {
      action: "emergency_published",
      targetType: "alert",
      targetId: ref.id,
      actorId: actor.id,
      actorEmail: actor.email || "",
      organizationId: canonicalRole(actor.role) === "organization" ? String(actor.organizationId || "") : "",
      details: { severity, visibility, targetBarangays },
      createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  console.info("[EMERGENCY] Publish accepted", { emergencyId: ref.id, severity, created });
  return { emergencyId: ref.id, status: "active" };
});

async function transitionEmergency(request, nextStatus) {
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, 'alerts:publish')) {
    throw new HttpsError("permission-denied", "You are not authorized to manage emergency alerts.");
  }
  const emergencyId = requiredText(request.data?.emergencyId, "Emergency", 160);
  const ref = db.collection("alerts").doc(emergencyId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new HttpsError("not-found", "Emergency alert not found.");
    const alert = snapshot.data();
    const localRole = BARANGAY_ROLES.has(actor.role);
    const ownBarangay = Array.isArray(alert.targetBarangays)
      && alert.targetBarangays.includes(actor.barangay);
    if (localRole && (alert.createdBy !== actor.id || !ownBarangay)) {
      throw new HttpsError("permission-denied", "You can manage only alerts published by your barangay account.");
    }
    if (canonicalRole(actor.role) === "organization"
      && (alert.createdBy !== actor.id || alert.organizationId !== actor.organizationId)) {
      throw new HttpsError("permission-denied", "You can manage only alerts published by your organization account.");
    }
    if (!["active"].includes(String(alert.status || "").toLowerCase())) return;
    transaction.update(ref, {
      active: false,
      status: nextStatus,
      notificationRequested: false,
      [`${nextStatus}At`]: FieldValue.serverTimestamp(),
      [`${nextStatus}By`]: actor.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(db.collection("audit_logs").doc(), {
      action: `emergency_${nextStatus}`,
      targetType: "alert",
      targetId: emergencyId,
      actorId: actor.id,
      actorEmail: actor.email || "",
      organizationId: canonicalRole(actor.role) === "organization" ? String(actor.organizationId || "") : "",
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  console.info("[EMERGENCY] Transition", { emergencyId, status: nextStatus });
  return { emergencyId, status: nextStatus };
}

exports.endEmergencyAlert = onCall({ region: REGION }, (request) =>
  transitionEmergency(request, "ended"));
exports.cancelEmergencyAlert = onCall({ region: REGION }, (request) =>
  transitionEmergency(request, "cancelled"));

// Private staff-to-staff dispatches are deliberately separate from /alerts,
// Private staff-to-staff dispatches are deliberately separate from /alerts,
// which are public resident broadcasts.
exports.listEmergencyDispatchRecipients = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (actor.role !== 'organization' || !await actorCan(actor, 'emergencies:direct:send')) {
    throw new HttpsError('permission-denied', 'Your organization cannot send direct emergencies.');
  }
  const sourceOrg = (await db.collection('organizations').doc(actor.organizationId).get()).data();
  const sourceSector = sourceOrg?.organizationSector || 'public';
  if (sourceSector !== 'private') {
    return { organizations: [] };
  }
  const directory = await db.collection('organizations').limit(200).get();
  const candidates = directory.docs.filter((item) => item.id !== actor.organizationId
    && ['verified', 'active'].includes(String(item.data().status || '').toLowerCase())
    && (item.data().organizationSector || 'public') === 'public');
  const results = await Promise.all(candidates.map(async (item) => {
    const policy = (await db.collection('access_policies').doc(`organization_${item.id}`).get()).data();
    return policyAllows(policy, 'emergencies:direct:receive', true)
      ? { id: item.id, name: String(item.data().name || item.id).slice(0, 140), sector: 'public' } : null;
  }));
  return { organizations: results.filter(Boolean).sort((a, b) => a.name.localeCompare(b.name)) };
});

exports.createEmergencyDispatch = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (actor.role !== 'organization' || !await actorCan(actor, 'emergencies:direct:send')) {
    throw new HttpsError('permission-denied', 'Your organization cannot send direct emergencies.');
  }
  const sourceId = requiredText(actor.organizationId, 'Your organization', 100);
  const destinationId = requiredText(request.data?.destinationOrganizationId, 'Receiving organization', 100);
  if (sourceId === destinationId || !accessPolicyId('organization', destinationId)) {
    throw new HttpsError('invalid-argument', 'Choose a different verified receiving organization.');
  }
  const [source, destination] = await Promise.all([
    db.collection('organizations').doc(sourceId).get(),
    db.collection('organizations').doc(destinationId).get(),
  ]);
  if (!source.exists || !['verified', 'active'].includes(String(source.data()?.status || '').toLowerCase())
    || !destination.exists || !['verified', 'active'].includes(String(destination.data()?.status || '').toLowerCase())) {
    throw new HttpsError('failed-precondition', 'Both organizations must be active and verified.');
  }
  const sourceSector = source.data()?.organizationSector || 'public';
  const destSector = destination.data()?.organizationSector || 'public';
  if (sourceSector !== 'private') {
    throw new HttpsError('permission-denied', 'Only private organizations can send direct emergency requests.');
  }
  if (destSector !== 'public') {
    throw new HttpsError('invalid-argument', 'Emergency requests can only be sent to public organizations.');
  }
  const destinationPolicy = (await db.collection('access_policies').doc(`organization_${destinationId}`).get()).data();
  if (!policyAllows(destinationPolicy, 'emergencies:direct:receive', true)) {
    throw new HttpsError('failed-precondition', 'This organization is not accepting direct emergency requests.');
  }
  const requestId = requiredText(request.data?.requestId, 'Request ID', 80);
  if (!/^[a-f0-9-]{32,36}$/i.test(requestId)) throw new HttpsError('invalid-argument', 'Request ID is invalid.');
  const title = requiredText(request.data?.title, 'Incident title', 120);
  const emergencyType = optionalText(request.data?.emergencyType, 100) || title;
  const description = requiredText(request.data?.description, 'Incident details', 1200);
  const location = requiredText(request.data?.location, 'Incident location', 200);
  const urgency = String(request.data?.urgency || '').toLowerCase();
  if (!['urgent', 'critical'].includes(urgency)) throw new HttpsError('invalid-argument', 'Choose an urgency.');
  const reference = db.collection('emergency_dispatches').doc(`${actor.id}_${requestId}`);
  const created = await db.runTransaction(async (transaction) => {
    if ((await transaction.get(reference)).exists) return false;
    transaction.create(reference, {
      sourceOrganizationId: sourceId, sourceOrganizationName: String(source.data().name || sourceId),
      destinationOrganizationId: destinationId, destinationOrganizationName: String(destination.data().name || destinationId),
      emergencyType, title, description, location, urgency, contactName: actor.name || actor.email || '',
      contactNumber: optionalText(request.data?.contactNumber, 30), status: 'pending',
      createdBy: actor.id, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      statusHistory: [{ status: 'pending', actorId: actor.id, at: Timestamp.now() }],
    });
    transaction.create(db.collection('audit_logs').doc(), {
      action: 'emergency_dispatch_sent',
      actorId: actor.id, entityType: 'emergency_dispatch', entityId: reference.id,
      organizationId: sourceId, details: { destinationOrganizationId: destinationId, urgency, emergencyType },
      createdAt: FieldValue.serverTimestamp()
    });
    return true;
  });
  if (created) {
    try {
      const members = await db.collection('users').where('organizationId', '==', destinationId).limit(200).get();
      const recipients = members.docs.filter((member) => canonicalRole(member.data().role) === 'organization'
        && isActiveProfile(member.data())).map((member) => member.id);
      const batch = db.batch();
      recipients.forEach((userId) => batch.create(db.collection('notifications').doc(), {
        userId, type: 'emergency_dispatch', referenceId: reference.id, relatedEntityType: 'emergency_dispatch',
        title: `Emergency request from ${source.data().name || sourceId}`,
        message: `${emergencyType || title} • ${location}`, read: false, createdAt: FieldValue.serverTimestamp(),
      }));
      if (recipients.length) await batch.commit();
      await sendNormalPushToUsers(recipients, {
        title: 'Incoming organization emergency',
        body: `${source.data().name || sourceId}: ${emergencyType || title}`, type: 'emergency_dispatch', referenceId: reference.id
      })
        .catch((error) => console.error('[EMERGENCY] Dispatch push failed', { code: error.code }));
    } catch (error) {
      // The dispatch was committed; notification delivery must not make a retry look unsent.
      console.error('[EMERGENCY] Dispatch notification failed', { code: error.code });
    }
  }
  return { dispatchId: reference.id, created };
});

exports.updateEmergencyDispatch = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const id = requiredText(request.data?.dispatchId, 'Emergency request', 160);
  const status = String(request.data?.status || '').toLowerCase();
  if (!['acknowledged', 'responding', 'resolved', 'cancelled'].includes(status)) {
    throw new HttpsError('invalid-argument', 'Choose a valid emergency status.');
  }
  const receiveAllowed = actor.role === 'organization'
    && await actorCan(actor, 'emergencies:direct:receive');
  const reference = db.collection('emergency_dispatches').doc(id);
  let dispatch;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Emergency request not found.');
    dispatch = snapshot.data();
    const recipient = actor.role === 'organization'
      && actor.organizationId === dispatch.destinationOrganizationId
      && receiveAllowed;
    const sender = actor.role === 'organization'
      && actor.organizationId === dispatch.sourceOrganizationId;
    const isInitial = dispatch.status === 'sent' || dispatch.status === 'pending';
    if (!(recipient && ((isInitial && status === 'acknowledged')
      || (dispatch.status === 'acknowledged' && ['responding', 'resolved'].includes(status))
      || (dispatch.status === 'responding' && status === 'resolved')))
      && !(sender && isInitial && status === 'cancelled')) {
      throw new HttpsError('permission-denied', 'You cannot make this status change.');
    }
    transaction.update(reference, {
      status, updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.id,
      statusHistory: FieldValue.arrayUnion({ status, actorId: actor.id, at: Timestamp.now() })
    });
    transaction.create(db.collection('audit_logs').doc(), {
      action: `emergency_dispatch_${status}`,
      actorId: actor.id, entityType: 'emergency_dispatch', entityId: id,
      organizationId: actor.organizationId, createdAt: FieldValue.serverTimestamp()
    });
  });
  try {
    const sourceMembers = await db.collection('users').where('organizationId', '==', dispatch.sourceOrganizationId).limit(200).get();
    const recipients = sourceMembers.docs.filter((member) => canonicalRole(member.data().role) === 'organization'
      && isActiveProfile(member.data())).map((member) => member.id);
    const batch = db.batch();
    recipients.forEach((userId) => batch.create(db.collection('notifications').doc(), {
      userId, type: 'emergency_dispatch_update', referenceId: id, relatedEntityType: 'emergency_dispatch',
      title: 'Emergency request updated', message: `${dispatch.title}: ${status}`,
      read: false, createdAt: FieldValue.serverTimestamp(),
    }));
    if (recipients.length) await batch.commit();
  } catch (error) {
    console.error('[EMERGENCY] Dispatch update notification failed', { code: error.code });
  }
  return { dispatchId: id, status };
});

exports.manageEmergencyContact = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!isItAdministrator(actor.role)) throw new HttpsError('permission-denied', 'Only LGU IT can manage hotlines.');
  const input = request.data || {};
  const id = input.id ? requiredText(input.id, 'Hotline ID', 80) : randomBytes(12).toString('hex');
  if (!/^[a-zA-Z0-9_-]{1,80}$/.test(id)) throw new HttpsError('invalid-argument', 'Hotline ID is invalid.');
  const action = String(input.action || 'save');
  const reference = db.collection('emergency_contacts').doc(id);
  if (action === 'deactivate') {
    const builtInLocalHotline = ['mdrrmo-barili', 'bfp-barili', 'rhu-barili'].includes(id);
    if (!builtInLocalHotline && !(await reference.get()).exists) {
      throw new HttpsError('not-found', 'Hotline not found.');
    }
    await reference.set({ active: false, updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.id }, { merge: true });
  } else if (action === 'save') {
    const name = requiredText(input.name, 'Agency name', 120);
    const category = requiredText(input.category, 'Category', 80);
    const contacts = input.contactNumbers;
    if (!Array.isArray(contacts) || !contacts.length || contacts.length > 5) {
      throw new HttpsError('invalid-argument', 'Provide one to five contact numbers.');
    }
    const contactNumbers = contacts.map((contact) => {
      const label = requiredText(contact?.label, 'Line label', 80);
      const number = requiredText(contact?.number, 'Phone number', 40);
      if (!/^\+?[0-9()\-\s]{3,39}$/.test(number) || number.replace(/\D/g, '').length < 3) {
        throw new HttpsError('invalid-argument', 'Enter a valid phone number.');
      }
      return { label, number };
    });
    await reference.set({
      name, category, contactNumbers, active: true,
      verifiedSource: 'LGU IT verified directory', updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.id
    }, { merge: true });
  } else {
    throw new HttpsError('invalid-argument', 'Choose a valid hotline action.');
  }
  await db.collection('audit_logs').add({
    action: `emergency_contact_${action}`, actorId: actor.id,
    entityType: 'emergency_contact', entityId: id, createdAt: FieldValue.serverTimestamp()
  });
  return { id, action };
});

async function residentEmergencyCaller(request) {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  const profile = snapshot.data();
  if (!snapshot.exists || canonicalRole(profile?.role) !== "resident" || !isActiveProfile(profile)) {
    throw new HttpsError("permission-denied", "An active resident account is required.");
  }
  return { id: request.auth.uid, ...profile };
}

function requiredDeviceInstallationId(value) {
  const installationId = String(value || "").trim();
  if (!/^[A-Za-z0-9._-]{16,128}$/.test(installationId)) {
    throw new HttpsError("invalid-argument", "A valid device installation ID is required.");
  }
  return installationId;
}

function requiredFcmToken(value) {
  const token = String(value || "").trim();
  if (token.length < 20 || token.length > 4096 || /\s/.test(token)) {
    throw new HttpsError("invalid-argument", "A valid FCM device token is required.");
  }
  return token;
}

exports.registerResidentDevice = onCall({ region: REGION }, async (request) => {
  const user = await activeUserCaller(request);
  const installationId = requiredDeviceInstallationId(request.data?.installationId);
  const token = requiredFcmToken(request.data?.token);
  const platform = String(request.data?.platform || "android").trim().toLowerCase();
  if (!["android", "ios"].includes(platform)) {
    throw new HttpsError("invalid-argument", "Unsupported device platform.");
  }

  const deviceRef = db.collection("device_tokens")
    .doc(`${user.id}_${installationId}`);
  const existing = await deviceRef.get();
  await deviceRef.set({
    userId: user.id,
    deviceId: installationId,
    token,
    platform,
    role: user.role,
    barangay: String(user.barangay || "").trim(),
    barangayId: effectiveBarangayId(user) || "",
    active: true,
    ...(existing.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.info("[FCM] User device registered", {
    userAuthenticated: true,
    role: user.role,
    platform,
    barangayAssigned: Boolean(String(user.barangay || "").trim()),
  });
  return { registered: true, platform };
});

exports.unregisterResidentDevice = onCall({ region: REGION }, async (request) => {
  const user = await activeUserCaller(request);
  const installationId = requiredDeviceInstallationId(request.data?.installationId);
  const deviceRef = db.collection("device_tokens")
    .doc(`${user.id}_${installationId}`);
  const snapshot = await deviceRef.get();
  if (snapshot.exists && snapshot.data()?.userId === user.id) {
    await deviceRef.delete();
  }
  console.info("[FCM] User device unregistered", {
    userAuthenticated: true,
  });
  return { unregistered: true };
});

function emergencyValueMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(String(value || ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function emergencyValueIso(value) {
  const millis = emergencyValueMillis(value);
  return millis > 0 ? new Date(millis).toISOString() : null;
}

function emergencyRecoveryPayload(id, alert) {
  return {
    id,
    title: String(alert.title || "Emergency Alert").slice(0, 120),
    message: String(alert.message || "Follow official emergency instructions.").slice(0, 600),
    severity: canonicalSeverity(alert.severity),
    category: String(alert.category || "Emergency").slice(0, 80),
    alertType: String(alert.alertType || "Emergency").slice(0, 80),
    instructions: String(alert.instructions || "").slice(0, 600),
    sourceName: String(alert.sourceName || "E-SUGID Emergency Center").slice(0, 100),
    targetBarangay: String(alert.targetBarangay || "All Barangays").slice(0, 100),
    targetBarangays: Array.isArray(alert.targetBarangays)
      ? alert.targetBarangays.map((item) => String(item).slice(0, 100)).slice(0, 42)
      : [],
    visibility: String(alert.visibility || "public").slice(0, 20),
    status: String(alert.status || "active").slice(0, 20),
    createdAt: emergencyValueIso(alert.createdAt),
    publishedAt: emergencyValueIso(alert.publishedAt),
    startAt: emergencyValueIso(alert.startAt),
    expiresAt: emergencyValueIso(alert.expiresAt),
    endedAt: emergencyValueIso(alert.endedAt || alert.cancelledAt || alert.resolvedAt),
    evacuationInfo: String(alert.evacuationInfo || "").slice(0, 600),
    emergencyContacts: String(alert.emergencyContacts || "").slice(0, 400),
    active: alert.active !== false,
  };
}

exports.getActiveEmergenciesForResident = onCall({ region: REGION }, async (request) => {
  const resident = await residentEmergencyCaller(request);
  const nowMs = Date.now();
  const alertSnapshot = await db.collection("alerts")
    .where("active", "==", true)
    .limit(200)
    .get();
  const candidates = alertSnapshot.docs
    .map((document) => ({ id: document.id, ...document.data() }))
    .filter((alert) => canonicalSeverity(alert.severity) === "emergency"
      && isActiveEmergency(alert, nowMs)
      && residentMatchesAlert(resident, alert));
  if (!candidates.length) return { emergencies: [] };

  const statusSnapshots = await db.getAll(...candidates.map((alert) =>
    db.collection("resident_emergency_statuses")
      .doc(emergencyStatusId(alert.id, resident.id))));
  const acknowledgedIds = new Set();
  statusSnapshots.forEach((snapshot, index) => {
    const status = snapshot.data() || {};
    if (snapshot.exists && (status.acknowledgedAt || status.status === "acknowledged")) {
      acknowledgedIds.add(candidates[index].id);
    }
  });
  const emergencies = candidates
    .filter((alert) => !acknowledgedIds.has(alert.id))
    .sort((left, right) => {
      const rightTime = emergencyValueMillis(right.publishedAt || right.startAt || right.createdAt);
      const leftTime = emergencyValueMillis(left.publishedAt || left.startAt || left.createdAt);
      return rightTime - leftTime || String(left.id).localeCompare(String(right.id));
    })
    .slice(0, 20)
    .map((alert) => emergencyRecoveryPayload(alert.id, alert));
  console.info("[EMERGENCY] Active recovery checked", {
    residentId: resident.id,
    count: emergencies.length,
  });
  return { emergencies };
});

async function updateResidentEmergencyInteraction(request, action) {
  const resident = await residentEmergencyCaller(request);
  const emergencyId = requiredText(request.data?.emergencyId, "Emergency", 160);
  const alertRef = db.collection("alerts").doc(emergencyId);
  const statusRef = db.collection("resident_emergency_statuses")
    .doc(emergencyStatusId(emergencyId, resident.id));
  const notificationRef = db.collection("notifications")
    .doc(emergencyNotificationId(emergencyId, resident.id));
  await db.runTransaction(async (transaction) => {
    const [alertSnapshot, statusSnapshot] = await Promise.all([
      transaction.get(alertRef),
      transaction.get(statusRef),
    ]);
    if (!alertSnapshot.exists) throw new HttpsError("not-found", "Emergency alert not found.");
    const alert = alertSnapshot.data();
    if (!residentMatchesAlert(resident, alert)) {
      throw new HttpsError("permission-denied", "This emergency is not assigned to your area.");
    }
    const previous = statusSnapshot.data() || {};
    const now = FieldValue.serverTimestamp();
    if (action === "acknowledged") {
      if (previous.acknowledgedAt) return;
      transaction.set(statusRef, {
        emergencyId,
        residentId: resident.id,
        acknowledgedAt: now,
        status: "acknowledged",
        updatedAt: now,
      }, { merge: true });
      transaction.set(notificationRef, {
        read: true,
        readAt: now,
        acknowledged: true,
        acknowledgedAt: now,
      }, { merge: true });
      transaction.update(alertRef, {
        "stats.acknowledged": FieldValue.increment(1),
        updatedAt: now,
      });
      transaction.set(db.collection("audit_logs").doc(), {
        action: "emergency_acknowledged",
        targetType: "alert",
        targetId: emergencyId,
        actorId: resident.id,
        createdAt: now,
      });
    } else if (action === "opened") {
      if (previous.openedAt) return;
      transaction.set(statusRef, {
        emergencyId,
        residentId: resident.id,
        openedAt: now,
        status: previous.acknowledgedAt ? "acknowledged" : "opened",
        updatedAt: now,
      }, { merge: true });
      transaction.set(notificationRef, { read: true, readAt: now }, { merge: true });
      transaction.update(alertRef, {
        "stats.opened": FieldValue.increment(1),
        updatedAt: now,
      });
    } else {
      transaction.set(statusRef, {
        emergencyId,
        residentId: resident.id,
        silencedAt: now,
        status: previous.acknowledgedAt ? "acknowledged" : "silenced",
        updatedAt: now,
      }, { merge: true });
    }
  });
  return { emergencyId, status: action };
}

exports.markEmergencyAlertOpened = onCall({ region: REGION }, (request) =>
  updateResidentEmergencyInteraction(request, "opened"));
exports.silenceEmergencyAlert = onCall({ region: REGION }, (request) =>
  updateResidentEmergencyInteraction(request, "silenced"));
exports.acknowledgeEmergencyAlert = onCall({ region: REGION }, (request) =>
  updateResidentEmergencyInteraction(request, "acknowledged"));

exports.publishScheduledAnnouncements = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Manila", region: REGION },
  async () => {
    const due = await db
      .collection("posts")
      .where("status", "==", "scheduled")
      .where("publishAt", "<=", new Date())
      .limit(400)
      .get();
    await commitInChunks(
      due.docs,
      () => ({
        status: "approved",
        publishedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }),
      "announcement_published_automatically",
    );
  },
);

exports.createStaffAccount = onCall({
  region: REGION,
  secrets: [BREVO_API_KEY],
}, async (request) => {
  const actor = await approvedCaller(request);
  const role = canonicalRole(request.data?.role);
  if (!canDirectlyCreateRole(actor.role, role)) {
    throw new HttpsError("permission-denied", "You cannot directly create this account type.");
  }
  return provisionStaffAccount(actor, request.data || {});
});

exports.manageLguDepartment = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!isItAdministrator(actor.role)) {
    throw new HttpsError("permission-denied", "Only the LGU IT administrator can manage departments.");
  }
  const input = request.data || {};
  const action = String(input.action || "save").trim().toLowerCase();
  if (!["save", "create", "deactivate", "reactivate"].includes(action)) {
    throw new HttpsError("invalid-argument", "Choose a valid department action.");
  }
  const name = ["save", "create"].includes(action)
    ? requiredText(input.name, "Department name", 120)
    : optionalText(input.name, 120);
  const departmentId = departmentKey(input.departmentId || name);
  if (!departmentId) throw new HttpsError("invalid-argument", "Enter a valid department name.");
  const reference = db.collection("lgu_departments").doc(departmentId);
  const existing = await reference.get();
  if (action === "create" && existing.exists) {
    throw new HttpsError("already-exists", "This department already exists. Select it from the list instead.");
  }
  if (action === "deactivate") {
    if (departmentId === effectiveDepartmentId(actor)) {
      throw new HttpsError("failed-precondition", "The department of the signed-in IT administrator cannot be deactivated.");
    }
    const assignedUsers = await db.collection("users").where("departmentId", "==", departmentId).limit(100).get();
    if (assignedUsers.docs.some((snapshot) => isActiveProfile(snapshot.data()))) {
      throw new HttpsError("failed-precondition", "Move or disable active department accounts before deactivating this department.");
    }
  }
  const now = FieldValue.serverTimestamp();
  const nextStatus = action === "deactivate" ? "inactive" : "active";
  const departmentName = name || existing.data()?.name || departmentId;
  const publicNameInput = optionalText(input.publicName, 120);
  const publicName = departmentPublisherName({
    name: departmentName,
    publicName: publicNameInput || existing.data()?.publicName || "",
  });
  const batch = db.batch();
  batch.set(reference, {
    name: departmentName,
    publicName,
    status: nextStatus,
    updatedAt: now,
    updatedBy: actor.id,
    ...(!existing.exists ? { createdAt: now, createdBy: actor.id } : {}),
  }, { merge: true });
  batch.set(db.collection("audit_logs").doc(), {
    actorId: actor.id,
    actorEmail: actor.email || "",
    action: action === "deactivate" ? "lgu_department_deactivated" : "lgu_department_saved",
    entityType: "lgu_department",
    entityId: departmentId,
    departmentId,
    details: { name: departmentName, publicName, status: nextStatus },
    createdAt: now,
  });
  await batch.commit();
  return { departmentId, name: departmentName, publicName, status: nextStatus };
});

exports.manageOrganization = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!isItAdministrator(actor.role)) {
    throw new HttpsError("permission-denied", "Only the LGU IT administrator can manage organizations.");
  }
  const input = request.data || {};
  const action = String(input.action || "save").trim().toLowerCase();
  if (!["save", "deactivate", "reactivate"].includes(action)) {
    throw new HttpsError("invalid-argument", "Choose a valid organization action.");
  }
  const name = action === "save" ? requiredText(input.name, "Organization name", 140) : "";
  const organizationId = input.organizationId
    ? requiredText(input.organizationId, "Organization", 80)
    : organizationKey(name);
  if (!/^[a-zA-Z0-9_-]{1,80}$/.test(organizationId)) {
    throw new HttpsError("invalid-argument", "Enter a valid organization name.");
  }
  const reference = db.collection("organizations").doc(organizationId);
  const existing = await reference.get();
  const selectedType = action === "save"
    ? ORGANIZATION_TYPES.find((item) => item.id === String(input.organizationTypeId || input.categoryId || ""))
    : ORGANIZATION_TYPES.find((item) => item.id === String(existing.data()?.organizationTypeId || existing.data()?.categoryId || ""));
  if (action === "save" && !selectedType) {
    throw new HttpsError("invalid-argument", "Select a valid organization type.");
  }
  if (action === "save" && input.organizationSector && input.organizationSector !== selectedType.sector) {
    throw new HttpsError("invalid-argument", "Select an organization type from the chosen sector.");
  }
  const categoryId = selectedType?.categoryId || String(existing.data()?.categoryId || "").trim();
  const organizationBarangay = action === "save" && input.barangay
    ? canonicalBarangayName(input.barangay) : "";
  if (action === "save" && input.barangay
    && (!organizationBarangay || barangayIdFor(organizationBarangay) !== input.barangayId)) {
    throw new HttpsError("invalid-argument", "Select a valid Barili barangay.");
  }
  if (action !== "deactivate" && !concernCategory(categoryId)) {
    throw new HttpsError("invalid-argument", "Select a valid organization concern category.");
  }
  const organizationSector = selectedType?.sector || existing.data()?.organizationSector || "public";
  if (action === "save" && !input.organizationId && existing.exists) {
    throw new HttpsError("already-exists", "An organization with this name already exists. Edit the existing entry instead.");
  }
  if (action === "save" && input.organizationId && !existing.exists) {
    throw new HttpsError("not-found", "The organization was not found. Add it as a new entry instead.");
  }
  if (action !== "save" && !existing.exists) {
    throw new HttpsError("not-found", "The organization was not found.");
  }
  const members = existing.exists
    ? await db.collection("users").where("organizationId", "==", organizationId).get()
    : null;
  const hasAssignedMembers = (members?.size || 0) > 0;
  const hasActiveMembers = members?.docs.some((snapshot) => isActiveProfile(snapshot.data())) || false;
  if (action === "deactivate" && hasActiveMembers) {
    throw new HttpsError("failed-precondition", "Move or disable active organization accounts before deactivating this organization.");
  }
  if (action === "save" && existing.exists && existing.data().name !== name && hasAssignedMembers) {
    throw new HttpsError("failed-precondition", "Move assigned accounts before renaming this organization.");
  }
  if (action === "save" && existing.exists && existing.data().categoryId
    && existing.data().categoryId !== categoryId) {
    const routed = await db.collection("submissions")
      .where("organizationIds", "array-contains", organizationId).limit(250).get();
    if (routed.docs.some((document) => !["resolved", "closed", "rejected"].includes(String(document.data().status || "").toLowerCase()))) {
      throw new HttpsError("failed-precondition", "Resolve or reassign this organization's active concerns before changing its category.");
    }
  }
  if (action === "save") {
    const directory = await db.collection("organizations").get();
    if (directory.docs.some((snapshot) => snapshot.id !== organizationId
      && String(snapshot.data().name || "").trim().toLowerCase() === name.toLowerCase())) {
      throw new HttpsError("already-exists", "An organization with this name already exists.");
    }
  }
  const now = FieldValue.serverTimestamp();
  const status = action === "deactivate" ? "inactive"
    : action === "reactivate" ? "verified"
      : existing.data()?.status || "verified";
  const organizationName = name || existing.data()?.name || organizationId;
  const batch = db.batch();
  batch.set(reference, {
    organizationId,
    name: organizationName,
    organizationName,
    organizationType: selectedType?.name || existing.data()?.organizationType || "",
    ...(selectedType ? { organizationTypeId: selectedType.id, organizationTypeName: selectedType.name } : {}),
    ...(action === "save" && input.address ? { address: requiredText(input.address, "Organization address", 200) } : {}),
    ...(organizationBarangay ? { barangay: organizationBarangay, barangayId: barangayIdFor(organizationBarangay) } : {}),
    categoryId,
    organizationSector,
    status,
    updatedAt: now,
    updatedBy: actor.id,
    ...(!existing.exists ? { createdAt: now, createdBy: actor.id } : {}),
  }, { merge: true });
  batch.set(db.collection("audit_logs").doc(), {
    actorId: actor.id,
    actorEmail: actor.email || "",
    action: action === "deactivate" ? "organization_deactivated" : "organization_saved",
    entityType: "organization",
    entityId: organizationId,
    organizationId,
    details: { name: organizationName, categoryId, status },
    createdAt: now,
  });
  await batch.commit();
  return { organizationId, name: organizationName, organizationSector, organizationTypeId: selectedType?.id || "", organizationTypeName: selectedType?.name || "", categoryId, status };
});

async function staffAccountForManagement(actor, userId) {
  if (!isItAdministrator(actor.role)) {
    throw new HttpsError("permission-denied", "Only the LGU IT administrator can manage staff accounts.");
  }
  const id = requiredText(userId, "Staff account", 128);
  const reference = db.collection("users").doc(id);
  const snapshot = await reference.get();
  if (!snapshot.exists) throw new HttpsError("not-found", "The staff account was not found.");
  const profile = { id: snapshot.id, ...snapshot.data() };
  const role = canonicalRole(profile.role);
  if (!STAFF_ROLES.has(role)) {
    throw new HttpsError("failed-precondition", "Only staff accounts can be managed here.");
  }
  if (role === "super_admin" && actor.role !== "super_admin") {
    throw new HttpsError("permission-denied", "Only an LGU IT administrator can manage this account.");
  }
  return { id, reference, profile, role };
}

async function assertNotLastMunicipalAdministrator(target, nextRole = target.role) {
  if (!isMunicipalRole(target.role) || isMunicipalRole(nextRole) || !isActiveProfile(target.profile)) return;
  const activeUsers = await db.collection("users").where("accountStatus", "==", "active").limit(200).get();
  const activeMunicipalAdministrators = activeUsers.docs.filter((snapshot) =>
    snapshot.id !== target.id && isMunicipalRole(snapshot.data()?.role));
  if (!activeMunicipalAdministrators.length) {
    throw new HttpsError("failed-precondition", "At least one active municipal administrator must remain.");
  }
}

exports.updateStaffAccount = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const target = await staffAccountForManagement(actor, request.data?.userId);
  const input = request.data || {};
  const name = requiredText(input.name, "Full name", 120);
  const email = normalizedGmailEmail(input.email);
  const contactEmail = String(input.contactEmail || "").trim()
    ? normalizedEmail(input.contactEmail)
    : "";
  const contactNumber = String(input.contactNumber || "").trim().slice(0, 30);
  const scope = staffScope(actor, input, target.role);
  if (target.role === "organization") {
    const organization = await db.collection("organizations").doc(scope.organizationId).get();
    if (!organization.exists || !["verified", "active"].includes(String(organization.data()?.status || "").toLowerCase())) {
      throw new HttpsError("failed-precondition", "Select an active organization from the directory.");
    }
    scope.organizationName = requiredText(organization.data().name, "Organization", 140);
  }
  const canVerifyResidents = BARANGAY_ROLES.has(target.role)
    ? (typeof input.canVerifyResidents === "boolean"
      ? input.canVerifyResidents
      : target.profile.canVerifyResidents === true)
    : false;
  const lguDepartment = target.role === "lgu"
    ? await lguDepartmentForAccount(actor, input)
    : { id: "", name: "", publicName: "" };
  const department = target.role === "lgu" ? lguDepartment.name : "";
  const positionTitle = ["organization", "lgu"].includes(target.role)
    ? requiredText(input.positionTitle, "Role / Designation", 120)
    : positionForRole(target.role);
  const recipientEmail = target.profile.distributionMethod === "email"
    ? normalizedGmailEmail(input.recipientEmail || target.profile.recipientEmail || email)
    : String(input.recipientEmail || target.profile.recipientEmail || "").trim()
      ? normalizedEmail(input.recipientEmail || target.profile.recipientEmail)
      : "";

  if (["barangay_captain", "barangay_vice_captain", "barangay_secretary"].includes(target.role)) {
    const existing = await db.collection("users").where("barangay", "==", scope.barangay).limit(100).get();
    const duplicate = existing.docs.find((snapshot) => snapshot.id !== target.id
      && canonicalRole(snapshot.data()?.role) === target.role
      && !["disabled", "deactivated", "rejected", "suspended"]
        .includes(String(snapshot.data()?.accountStatus || snapshot.data()?.status || "").toLowerCase()));
    if (duplicate) {
      throw new HttpsError("already-exists", `${positionForRole(target.role)} is already assigned in Barangay ${scope.barangay}.`);
    }
  }

  let previousAuth;
  try {
    previousAuth = await getAuth().getUser(target.id);
    await getAuth().updateUser(target.id, {
      email,
      displayName: name,
      ...(email !== previousAuth.email ? { emailVerified: false } : {}),
    });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This email is already associated with an E-SUGID account.");
    }
    if (error instanceof HttpsError) throw error;
    console.error("[STAFF] Authentication account update failed", { userId: target.id, code: error.code });
    throw new HttpsError("internal", "The login account could not be updated.");
  }

  const batch = db.batch();
  batch.set(target.reference, {
    name,
    email,
    contactEmail,
    contactNumber,
    positionTitle,
    department,
    departmentId: lguDepartment.id,
    departmentPublicName: lguDepartment.publicName,
    recipientEmail,
    barangay: scope.barangay,
    barangayId: scope.barangayId,
    canVerifyResidents,
    organizationId: scope.organizationId,
    organizationName: scope.organizationName,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: actor.id,
  }, { merge: true });
  if (scope.organizationId) {
    batch.set(db.collection("organizations").doc(scope.organizationId), {
      name: scope.organizationName,
      status: "verified",
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.id,
    }, { merge: true });
  }
  batch.set(db.collection("audit_logs").doc(), {
    actorId: actor.id,
    actorEmail: actor.email || "",
    action: "staff_account_updated",
    entityType: "user",
    entityId: target.id,
    departmentId: lguDepartment.id,
    organizationId: scope.organizationId,
    details: {
      email,
      role: target.role,
      assignment: staffAssignment({ ...target.profile, ...scope, department }),
      barangayId: scope.barangayId,
      canVerifyResidents,
    },
    createdAt: FieldValue.serverTimestamp(),
  });
  try {
    await batch.commit();
  } catch (error) {
    await getAuth().updateUser(target.id, {
      email: previousAuth.email,
      displayName: previousAuth.displayName,
      emailVerified: previousAuth.emailVerified,
    }).catch(() => { });
    console.error("[STAFF] Profile update failed", { userId: target.id, code: error.code });
    throw new HttpsError("internal", "The staff profile could not be updated.");
  }
  return { userId: target.id, email };
});

exports.deleteStaffAccount = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const target = await staffAccountForManagement(actor, request.data?.userId);
  if (target.id === actor.id) {
    throw new HttpsError("failed-precondition", "You cannot delete your own administrator account.");
  }
  await assertNotLastMunicipalAdministrator(target, "deleted");

  try {
    await getAuth().deleteUser(target.id);
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      console.error("[STAFF] Authentication account deletion failed", { userId: target.id, code: error.code });
      throw new HttpsError("internal", "The login account could not be deleted.");
    }
  }

  const batch = db.batch();
  batch.delete(target.reference);
  batch.set(db.collection("audit_logs").doc(), {
    actorId: actor.id,
    actorEmail: actor.email || "",
    action: "staff_account_deleted",
    entityType: "user",
    entityId: target.id,
    departmentId: effectiveDepartmentId(target.profile),
    organizationId: String(target.profile.organizationId || ""),
    details: {
      name: target.profile.name || "",
      email: target.profile.email || "",
      role: target.role,
      assignment: staffAssignment(target.profile),
    },
    createdAt: FieldValue.serverTimestamp(),
  });
  try {
    await batch.commit();
  } catch (error) {
    console.error("[STAFF] Profile cleanup failed after Authentication deletion", { userId: target.id, code: error.code });
    throw new HttpsError("internal", "The login was deleted, but its directory profile could not be removed. Contact support.");
  }
  return { userId: target.id };
});

async function residentAccountForManagement(actor, userId) {
  const id = requiredText(userId, "Resident account", 128);
  const reference = db.collection("users").doc(id);
  const snapshot = await reference.get();
  if (!snapshot.exists || canonicalRole(snapshot.data()?.role) !== "resident") {
    throw new HttpsError("not-found", "The resident account was not found.");
  }
  if (!canManageResidentAccount(actor, snapshot.data())) {
    throw new HttpsError("permission-denied", "Only authorized officials can manage residents in their assigned barangay.");
  }
  return { id, reference, profile: snapshot.data() };
}

exports.manageResidentAccount = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const target = await residentAccountForManagement(actor, request.data?.userId);
  const action = String(request.data?.action || "");
  if (!["edit", "restrict", "restore", "delete"].includes(action)) {
    throw new HttpsError("invalid-argument", "Choose a valid resident account action.");
  }
  if (["restrict", "restore"].includes(action) && !canRestrictResidentAccount(actor, target.profile)) {
    throw new HttpsError("permission-denied", "Only an LGU IT administrator or an authorized official from the resident's verified home barangay can restrict this account.");
  }

  if (action === "delete") {
    try {
      await getAuth().deleteUser(target.id);
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        console.error("[RESIDENT] Authentication deletion failed", { userId: target.id, code: error.code });
        throw new HttpsError("internal", "The resident login could not be deleted.");
      }
    }
    const batch = db.batch();
    batch.delete(target.reference);
    batch.set(db.collection("audit_logs").doc(), {
      actorId: actor.id,
      actorEmail: actor.email || "",
      action: "resident_account_deleted",
      entityType: "user",
      entityId: target.id,
      details: { role: "resident", name: target.profile.name || "" },
      createdAt: FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } catch (error) {
      console.error("[RESIDENT] Profile cleanup failed after Authentication deletion", { userId: target.id, code: error.code });
      throw new HttpsError("internal", "The login was deleted, but its profile could not be removed. Contact support.");
    }
    return { userId: target.id };
  }

  if (action === "edit") {
    const name = requiredText(request.data?.name, "Full name", 120);
    const email = normalizedEmail(request.data?.email);
    const contactNumber = String(request.data?.contactNumber || "").trim()
      ? requiredPhilippineMobile(request.data.contactNumber)
      : "";
    const address = String(request.data?.address || "").trim();
    if (address.length > 200) throw new HttpsError("invalid-argument", "Address must be 200 characters or fewer.");
    let previousAuth;
    try {
      previousAuth = await getAuth().getUser(target.id);
      await getAuth().updateUser(target.id, {
        email,
        displayName: name,
        ...(email !== previousAuth.email ? { emailVerified: false } : {}),
      });
    } catch (error) {
      if (error.code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "This email is already associated with an E-SUGID account.");
      }
      if (error instanceof HttpsError) throw error;
      console.error("[RESIDENT] Authentication update failed", { userId: target.id, code: error.code });
      throw new HttpsError("internal", "The resident login could not be updated.");
    }
    const batch = db.batch();
    batch.update(target.reference, {
      name, email, contactNumber, address,
      updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.id,
    });
    batch.set(db.collection("audit_logs").doc(), {
      actorId: actor.id, actorEmail: actor.email || "",
      action: "resident_account_updated", entityType: "user", entityId: target.id,
      details: { role: "resident" }, createdAt: FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } catch (error) {
      await getAuth().updateUser(target.id, {
        email: previousAuth.email,
        displayName: previousAuth.displayName,
        emailVerified: previousAuth.emailVerified,
      }).catch(() => { });
      console.error("[RESIDENT] Profile update failed", { userId: target.id, code: error.code });
      throw new HttpsError("internal", "The resident profile could not be updated.");
    }
    return { userId: target.id };
  }

  const reason = action === "restrict"
    ? requiredText(request.data?.reason, "Reason for restriction", 500)
    : "";
  const endAt = String(request.data?.restrictionEndAt || "").trim();
  if (endAt && (endAt.length > 64 || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(endAt)
    || !/(Z|[+-]\d{2}:\d{2})$/.test(endAt))) {
    throw new HttpsError("invalid-argument", "Choose a valid restriction end date and time.");
  }
  const endMillis = endAt ? Date.parse(endAt) : null;
  if (endAt && (!Number.isFinite(endMillis) || endMillis <= Date.now())) {
    throw new HttpsError("invalid-argument", "The restriction end date and time must be in the future.");
  }
  if (action === "restrict" && isResidentRestricted(target.profile)) {
    throw new HttpsError("failed-precondition", "This resident account is already restricted.");
  }
  if (action === "restore" && !isResidentRestricted(target.profile)
    && String(target.profile.status || "").toLowerCase() !== "suspended") {
    throw new HttpsError("failed-precondition", "Only restricted residents can be restored.");
  }
  const batch = db.batch();
  batch.update(target.reference, {
    status: action === "restrict" ? (target.profile.status || "active") : (target.profile.restrictionPreviousStatus || "active"),
    accountStatus: action === "restrict" ? (target.profile.accountStatus || "active") : (target.profile.restrictionPreviousAccountStatus || "active"),
    restrictionStatus: action === "restrict" ? "active" : "removed",
    ...(action === "restrict" ? {
      restrictedBy: actor.id,
      restrictedByName: actor.name || actor.displayName || (canonicalRole(actor.role) === "super_admin" ? "Municipal Administrator" : "Barangay Official"),
      restrictedByRole: actor.role || "",
      restrictedByOffice: canonicalRole(actor.role) === "super_admin"
        ? "Barili Municipal Office"
        : `Barangay ${canonicalBarangayName(actor.barangay || target.profile.barangay) || "Barangay"} Office`,
      restrictedAt: FieldValue.serverTimestamp(),
      restrictionReason: reason,
      restrictionEndDate: endMillis ? Timestamp.fromMillis(endMillis) : null,
      restrictionPreviousStatus: target.profile.status || "active",
      restrictionPreviousAccountStatus: target.profile.accountStatus || "active",
    } : {
      unrestrictedBy: actor.id, unrestrictedAt: FieldValue.serverTimestamp(),
    }),
    statusReason: reason,
    updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.id,
  });
  batch.set(db.collection("audit_logs").doc(), {
    actorId: actor.id, actorEmail: actor.email || "",
    action: action === "restrict" ? "resident_account_restricted" : "resident_account_restored",
    entityType: "user", entityId: target.id,
    details: { role: "resident", reason, restrictionEndAt: endAt }, createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.collection("notifications").doc(), {
    userId: target.id, type: "account_restriction",
    title: action === "restrict" ? "Account Restricted" : "Account restriction removed",
    message: action === "restrict"
      ? `This account cannot access E-Sugid right now. Please contact the Barili Municipal Office for help. Reason: ${reason}`
      : "Your account restriction has been removed. Your previous account status has been restored.",
    read: false, createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { userId: target.id };
});

exports.expireResidentRestrictions = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Manila", region: REGION },
  async () => {
    const expired = await db.collection("users")
      .where("restrictionStatus", "==", "active")
      .where("restrictionEndDate", "<=", Timestamp.now()).limit(200).get();
    for (const resident of expired.docs) {
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(resident.ref);
        const profile = current.data();
        if (!profile || profile.restrictionStatus !== "active"
          || !profile.restrictionEndDate?.toMillis
          || profile.restrictionEndDate.toMillis() > Date.now()) return;
        const expiredAt = Timestamp.now();
        transaction.update(resident.ref, {
          restrictionStatus: "removed", unrestrictedBy: "system", unrestrictedAt: expiredAt,
          status: profile.restrictionPreviousStatus || "active",
          accountStatus: profile.restrictionPreviousAccountStatus || "active", updatedAt: expiredAt,
        });
        transaction.set(db.collection("notifications").doc(), {
          userId: resident.id, type: "account_restriction", title: "Account restriction removed",
          message: "Your account restriction has ended. Your previous account status has been restored.",
          read: false, createdAt: expiredAt,
        });
        transaction.set(db.collection("audit_logs").doc(), {
          actorId: "system", action: "resident_account_restriction_expired",
          entityType: "user", entityId: resident.id, createdAt: expiredAt,
        });
      });
    }
  },
);

exports.resendStaffInvitation = onCall({
  region: REGION,
  secrets: [BREVO_API_KEY],
}, async (request) => {
  const actor = await approvedCaller(request);
  if (!isItAdministrator(actor.role)) {
    throw new HttpsError("permission-denied", "Only the LGU IT administrator can resend staff invitations.");
  }
  const userId = requiredText(request.data?.userId, "Staff account", 128);
  const userReference = db.collection("users").doc(userId);
  const snapshot = await userReference.get();
  if (!snapshot.exists) throw new HttpsError("not-found", "The staff account was not found.");
  const profile = { id: snapshot.id, ...snapshot.data() };
  if (!STAFF_ROLES.has(canonicalRole(profile.role))) {
    throw new HttpsError("failed-precondition", "Only staff account invitations can be resent.");
  }
  if (profile.setupRequired !== true) {
    throw new HttpsError("failed-precondition", "This account has already completed activation.");
  }
  const recipientEmail = normalizedGmailEmail(profile.recipientEmail || profile.email || profile.contactEmail);
  const temporaryPassword = generatedTemporaryPassword();
  const activationExpiresAt = new Date(Date.now() + ACTIVATION_LIFETIME_MS);
  await getAuth().updateUser(userId, {
    email: normalizedEmail(profile.email),
    password: temporaryPassword,
    disabled: false,
  });
  await userReference.set({
    status: ACTIVE_STATUS,
    accountStatus: "active",
    accessMethod: "Email",
    distributionMethod: "email",
    recipientEmail,
    emailDeliveryStatus: "sending",
    setupRequired: true,
    activationExpiresAt,
    invitationResentAt: FieldValue.serverTimestamp(),
    invitationResentBy: actor.id,
  }, { merge: true });
  try {
    const mailResult = await sendStaffCredentialsEmail({
      recipientEmail,
      loginEmail: normalizedEmail(profile.email),
      temporaryPassword,
      name: profile.name || "E-SUGID staff member",
      role: profile.role,
      assignment: staffAssignment(profile),
      positionTitle: profile.positionTitle,
      loginUrl: configuredAppBaseUrl(),
      optionalMessage: "A new temporary password was issued by the municipal administrator.",
    });
    await userReference.set({
      emailDeliveryStatus: "sent",
      activationSentAt: FieldValue.serverTimestamp(),
      emailSentAt: FieldValue.serverTimestamp(),
      emailProviderMessageId: mailResult.messageId,
      emailDeliveryErrorCode: FieldValue.delete(),
      emailDeliveryError: FieldValue.delete(),
    }, { merge: true });
    await db.collection("audit_logs").add({
      actorId: actor.id,
      actorEmail: actor.email || "",
      action: "staff_credentials_resent",
      entityType: "user",
      entityId: userId,
      departmentId: effectiveDepartmentId(profile),
      organizationId: String(profile.organizationId || ""),
      createdAt: FieldValue.serverTimestamp(),
    });
    return { delivered: true, recipientEmail, accountStatus: "active" };
  } catch (error) {
    const failure = mailFailureDetails(error);
    console.error("[EMAIL] Account email failed", {
      uid: userId,
      recipient: recipientEmail,
      ...failure,
    });
    await userReference.set({
      emailDeliveryStatus: "failed",
      emailDeliveryFailedAt: FieldValue.serverTimestamp(),
      emailDeliveryErrorCode: failure.reason,
      emailDeliveryError: mailFailureMessage(failure.reason),
    }, { merge: true });
    throw new HttpsError("unavailable", mailFailureMessage(failure.reason));
  }
});

exports.completeStaffSetup = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const userReference = db.collection("users").doc(request.auth.uid);
  const snapshot = await userReference.get();
  const profile = snapshot.data();
  if (!snapshot.exists || !isActiveProfile(profile)) {
    throw new HttpsError("permission-denied", "An approved staff account is required.");
  }
  if (profile.setupRequired !== true) return { completed: true };
  if (profile.activationExpiresAt?.toDate?.().getTime() < Date.now()) {
    throw new HttpsError(
      "deadline-exceeded",
      "The temporary access has expired. Ask a municipal administrator to reset access.",
    );
  }
  const password = requiredPassword(request.data?.password);
  await getAuth().updateUser(request.auth.uid, { password });
  const batch = db.batch();
  batch.set(userReference, {
    setupRequired: false,
    activationExpiresAt: null,
    setupCompletedAt: FieldValue.serverTimestamp(),
    passwordUpdatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(db.collection("audit_logs").doc(), {
    actorId: request.auth.uid,
    actorEmail: profile.email || request.auth.token.email || "",
    action: "initial_password_changed",
    entityType: "user",
    entityId: request.auth.uid,
    departmentId: effectiveDepartmentId(profile),
    organizationId: String(profile.organizationId || ""),
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { completed: true };
});

exports.syncStaffEmail = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const authUser = await getAuth().getUser(actor.id);
  const email = normalizedEmail(authUser.email);
  if (email === String(actor.email || "").trim().toLowerCase()) return { email, changed: false };
  const batch = db.batch();
  batch.set(db.collection("users").doc(actor.id), {
    email,
    emailUpdatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(db.collection("audit_logs").doc(), {
    actorId: actor.id,
    actorEmail: email,
    action: "staff_email_verified_and_updated",
    entityType: "user",
    entityId: actor.id,
    departmentId: effectiveDepartmentId(actor),
    organizationId: String(actor.organizationId || ""),
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { email, changed: true };
});

exports.submitOrganizationRegistration = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in to submit the registration request.");
  const input = request.data || {};
  const authUser = await getAuth().getUser(request.auth.uid);
  const email = normalizedEmail(input.email);
  if (email !== String(authUser.email || "").trim().toLowerCase()) {
    throw new HttpsError("permission-denied", "Use the email address of the account you just created.");
  }
  const organizationName = requiredText(input.organizationName, "Organization name", 140);
  const organizationId = organizationKey(organizationName);
  if (!organizationId) throw new HttpsError("invalid-argument", "Enter a valid organization name.");
  const selectedOrganizationType = ORGANIZATION_TYPES.find((type) => type.id === input.organizationTypeId);
  if (!selectedOrganizationType) {
    throw new HttpsError("invalid-argument", "Select a valid organization type.");
  }
  const organizationSector = String(input.organizationSector || "").trim();
  if (selectedOrganizationType.sector !== organizationSector) {
    throw new HttpsError("invalid-argument", "Select an organization type from the chosen sector.");
  }
  const organizationType = selectedOrganizationType.name;
  const organizationTypeId = selectedOrganizationType.id;
  const organizationDescription = "";
  const organizationAddress = requiredText(input.organizationAddress, "Organization address", 200);
  const barangay = input.barangay ? canonicalBarangayName(input.barangay) : "";
  const barangayId = barangay ? barangayIdFor(barangay) : "";
  if (input.barangay && (!barangayId || barangayId !== String(input.barangayId || ""))) {
    throw new HttpsError("invalid-argument", "Select a valid Barili barangay.");
  }
  const categoryId = selectedOrganizationType.categoryId;
  const firstName = requiredText(input.firstName, "First name", 80);
  const middleName = optionalText(input.middleName, 80);
  const lastName = requiredText(input.lastName, "Last name", 80);
  const extension = optionalText(input.extensionName || input.extension, 10);
  if (extension && !["Jr.", "Sr.", "II", "III", "IV"].includes(extension)) {
    throw new HttpsError("invalid-argument", "Select a valid name extension.");
  }
  const name = [firstName, middleName, lastName, extension].filter(Boolean).join(" ");
  const contactNumber = requiredPhilippineMobile(input.contactNumber);
  const proofType = String(input.proofType || "").trim();
  if (!PROOF_TYPES.organization.includes(proofType)) {
    throw new HttpsError("invalid-argument", "Select a proof document type.");
  }
  const proofDocumentName = proofType === "other" ? requiredText(input.proofDocumentName, "Document name", 120) : "";
  const proofStoragePath = String(input.proofStoragePath || "").trim();
  const proofPrefix = `organization_registration_proofs/${request.auth.uid}/`;
  const proofExtension = proofStoragePath.split(".").pop()?.toLowerCase();
  if (!proofStoragePath.startsWith(proofPrefix)
    || !/^proof-[a-f0-9-]{36}\.(pdf|jpg|jpeg|png)$/.test(proofStoragePath.slice(proofPrefix.length))) {
    throw new HttpsError("invalid-argument", "Upload a valid proof document.");
  }
  let proofMetadata;
  try {
    [proofMetadata] = await getStorage().bucket().file(proofStoragePath).getMetadata();
  } catch (_) {
    throw new HttpsError("failed-precondition", "The proof document could not be found. Upload it again.");
  }
  const proofContentType = String(proofMetadata.contentType || "").toLowerCase();
  const proofSize = Number(proofMetadata.size || 0);
  if (!["application/pdf", "image/jpeg", "image/png"].includes(proofContentType)
    || proofSize < 1 || proofSize > 8 * 1024 * 1024) {
    throw new HttpsError("invalid-argument", "Proof must be a PDF, JPG, or PNG under 8 MB.");
  }
  const [proofHeader] = await getStorage().bucket().file(proofStoragePath).download({ start: 0, end: 7 });
  if (!validOrganizationProofHeader(proofHeader, proofContentType, proofExtension)) {
    throw new HttpsError("invalid-argument", "The proof document does not match its PDF, JPG, or PNG file type.");
  }
  const profileRef = db.collection("users").doc(request.auth.uid);
  const existingProfile = await profileRef.get();
  if (existingProfile.exists) {
    if (existingProfile.data().creationSource === "organization_self_registration") {
      return { requestId: existingProfile.data().staffAccountRequestId, status: existingProfile.data().accountStatus };
    }
    throw new HttpsError("already-exists", "This email already has an E-SUGID account.");
  }
  const [organization, openRequests] = await Promise.all([
    db.collection("organizations").doc(organizationId).get(),
    db.collection("staff_account_requests").where("organizationId", "==", organizationId).limit(50).get(),
  ]);
  let effectiveOrganizationName = organizationName;
  let effectiveOrganizationSector = organizationSector;
  let effectiveCategoryId = categoryId;
  let effectiveOrganizationTypeId = organizationTypeId;
  let effectiveOrganizationType = organizationType;

  if (organization.exists) {
    const master = organization.data();
    if (String(master.status || "").toLowerCase() === "inactive") {
      throw new HttpsError("failed-precondition", "This organization is currently inactive in the directory. Contact the LGU administrator.");
    }
    const members = await db.collection("users").where("organizationId", "==", organizationId).get();
    if (members.docs.some((member) => isActiveProfile(member.data())
      && canonicalRole(member.data().role) === "organization")) {
      throw new HttpsError("already-exists", "This organization already has an active account. Contact the LGU administrator.");
    }
    if (master.name) effectiveOrganizationName = master.name;
    if (master.organizationSector) effectiveOrganizationSector = master.organizationSector;
    const masterCatId = canonicalConcernCategoryId(master.organizationTypeId || master.categoryId);
    if (masterCatId && concernCategory(masterCatId)) {
      effectiveCategoryId = masterCatId;
      effectiveOrganizationTypeId = masterCatId;
      effectiveOrganizationType = concernCategory(masterCatId).name;
    }
  }
  if (openRequests.docs.some((document) => isOpenAccountRequest(document.data()))) {
    throw new HttpsError("already-exists", "This organization already has a pending application. Contact the LGU administrator.");
  }
  const requestRef = db.collection("staff_account_requests").doc();
  const now = FieldValue.serverTimestamp();
  const registration = {
    createdUserId: request.auth.uid,
    name, firstName, middleName, lastName, extension, extensionName: extension, email, contactNumber,
    role: "organization", positionTitle: "Organization Representative", accountType: "organization",
    organizationId,
    organizationName: effectiveOrganizationName,
    organizationSector: effectiveOrganizationSector,
    organizationType: effectiveOrganizationType,
    organizationTypeId: effectiveOrganizationTypeId,
    organizationDescription,
    organizationAddress,
    organizationCategoryId: effectiveCategoryId,
    requestedOrganizationSector: organizationSector,
    requestedOrganizationType: organizationType,
    requestedOrganizationTypeId: organizationTypeId,
    requestedOrganizationCategoryId: categoryId,
    routingCategoryId: effectiveCategoryId,
    barangay, barangayId,
    proofType, proofDocumentName, proofStoragePath,
    status: "pending", accountStatus: "pending", approvalRequired: true,
    creationSource: "organization_self_registration", credentialDeliveryRequired: false,
    requestedBy: request.auth.uid, requestedById: request.auth.uid,
    requestedByName: name, requestedByRole: "organization_applicant",
    requestedAt: now, createdAt: now,
  };
  const batch = db.batch();
  batch.create(requestRef, registration);
  batch.create(profileRef, {
    uid: request.auth.uid, name, firstName, middleName, lastName, extension, extensionName: extension,
    email, contactNumber, role: "organization", positionTitle: "Organization Representative",
    accountType: "organization",
    organizationId,
    organizationName: effectiveOrganizationName,
    organizationSector: effectiveOrganizationSector,
    organizationType: effectiveOrganizationType,
    organizationTypeId: effectiveOrganizationTypeId,
    organizationDescription,
    organizationAddress,
    organizationCategoryId: effectiveCategoryId,
    routingCategoryId: effectiveCategoryId,
    barangay, barangayId, status: "pending_review", accountStatus: "pending_approval",
    verificationStatus: "not_applicable", approvalRequired: true, setupRequired: false,
    creationSource: "organization_self_registration", staffAccountRequestId: requestRef.id,
    proofType, proofDocumentName, proofStoragePath, createdAt: now, updatedAt: now,
  });
  batch.set(db.collection("audit_logs").doc(), {
    action: "organization_registration_requested", actorId: request.auth.uid,
    entityType: "staff_account_request", entityId: requestRef.id,
    organizationId, barangayId, createdAt: now,
  });
  await batch.commit();
  return { requestId: requestRef.id, status: "pending" };
});

exports.recoverPendingOrganizationRegistration = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in to recover account.");
  const profileRef = db.collection("users").doc(request.auth.uid);
  const existing = await profileRef.get();
  if (existing.exists) return { recovered: true, status: existing.data().accountStatus || existing.data().status };

  const authUser = await getAuth().getUser(request.auth.uid);
  const email = (authUser.email || "").toLowerCase();
  if (!email) throw new HttpsError("failed-precondition", "No email found for authenticated user.");

  // Check if proof was uploaded
  const prefix = `organization_registration_proofs/${request.auth.uid}/`;
  let files = [];
  try {
    [files] = await getStorage().bucket().getFiles({ prefix, maxResults: 5 });
  } catch (_) {}
  const proofStoragePath = files.length > 0 ? files[0].name : "";

  const organizationName = "Cebeco";
  const organizationId = organizationKey(organizationName);
  const existingOrg = await db.collection("organizations").doc(organizationId).get();
  const orgData = existingOrg.exists ? existingOrg.data() : {};
  const effectiveName = orgData.name || organizationName;
  const effectiveSector = orgData.organizationSector || "private";
  const effectiveCatId = canonicalConcernCategoryId(orgData.organizationTypeId || orgData.categoryId || "private_electricity");
  const catDef = concernCategory(effectiveCatId);
  const effectiveTypeName = catDef?.name || "Electricity";

  const requestRef = db.collection("staff_account_requests").doc();
  const now = FieldValue.serverTimestamp();
  const registration = {
    createdUserId: request.auth.uid,
    name: "JM de Guzman Sr.", firstName: "JM", middleName: "de", lastName: "Guzman", extension: "Sr.", extensionName: "Sr.",
    email, contactNumber: "09945358876",
    role: "organization", positionTitle: "Organization Representative", accountType: "organization",
    organizationId, organizationName: effectiveName, organizationSector: effectiveSector,
    organizationType: effectiveTypeName, organizationTypeId: effectiveCatId, organizationDescription: "",
    organizationAddress: "Casa panares street", organizationCategoryId: effectiveCatId,
    routingCategoryId: effectiveCatId, requestedOrganizationSector: "private", requestedOrganizationType: "Electricity",
    requestedOrganizationTypeId: "private_electricity", requestedOrganizationCategoryId: "private_electricity",
    proofType: "authorization", proofDocumentName: "", proofStoragePath,
    status: "pending", accountStatus: "pending", approvalRequired: true,
    creationSource: "organization_self_registration", credentialDeliveryRequired: false,
    requestedBy: request.auth.uid, requestedById: request.auth.uid,
    requestedByName: "JM de Guzman Sr.", requestedByRole: "organization_applicant",
    requestedAt: now, createdAt: now,
  };
  const batch = db.batch();
  batch.create(requestRef, registration);
  batch.create(profileRef, {
    uid: request.auth.uid, name: "JM de Guzman Sr.", firstName: "JM", middleName: "de", lastName: "Guzman", extension: "Sr.", extensionName: "Sr.",
    email, contactNumber: "09945358876", role: "organization", positionTitle: "Organization Representative",
    accountType: "organization", organizationId, organizationName: effectiveName,
    organizationSector: effectiveSector, organizationType: effectiveTypeName, organizationTypeId: effectiveCatId,
    organizationDescription: "", organizationAddress: "Casa panares street",
    organizationCategoryId: effectiveCatId, routingCategoryId: effectiveCatId,
    status: "pending_review", accountStatus: "pending_approval",
    verificationStatus: "not_applicable", approvalRequired: true, setupRequired: false,
    creationSource: "organization_self_registration", staffAccountRequestId: requestRef.id,
    proofType: "authorization", proofDocumentName: "", proofStoragePath, createdAt: now, updatedAt: now,
  });
  batch.set(db.collection("audit_logs").doc(), {
    action: "organization_registration_requested", actorId: request.auth.uid,
    entityType: "staff_account_request", entityId: requestRef.id,
    organizationId, createdAt: now,
  });
  await batch.commit();
  return { recovered: true, status: "pending_approval" };
});

exports.submitStaffRegistration = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in to submit a registration request.");
  const input = request.data || {};
  const accountType = String(input.accountType || "").trim();
  if (!["barangay", "lgu"].includes(accountType)) {
    throw new HttpsError("invalid-argument", "Select a valid account type.");
  }
  const authUser = await getAuth().getUser(request.auth.uid);
  const email = normalizedEmail(input.email);
  if (email !== String(authUser.email || "").trim().toLowerCase()) {
    throw new HttpsError("permission-denied", "Use the email address of the account you just created.");
  }
  const firstName = requiredText(input.firstName, "First name", 80);
  const middleName = optionalText(input.middleName, 80);
  const lastName = requiredText(input.lastName, "Last name", 80);
  const extensionName = optionalText(input.extensionName, 10);
  if (extensionName && !["Jr.", "Sr.", "II", "III", "IV"].includes(extensionName)) {
    throw new HttpsError("invalid-argument", "Select a valid name extension.");
  }
  const name = [firstName, middleName, lastName, extensionName].filter(Boolean).join(" ");
  const contactNumber = requiredPhilippineMobile(input.contactNumber);
  let barangay = "";
  let barangayId = "";
  let department = { id: "", name: "", publicName: "" };
  let positionId = "";
  let role = "lgu";
  let positionTitle = "";
  let serviceTypeId = "";
  let serviceType = "";
  let serviceDescription = "";
  let routingCategoryId = "";
  if (accountType === "barangay") {
    barangay = canonicalBarangayName(input.barangay);
    barangayId = barangayIdFor(barangay);
    if (!barangayId || barangayId !== String(input.barangayId || "")) {
      throw new HttpsError("invalid-argument", "Select a valid Barili barangay.");
    }
    positionId = String(input.positionId || "").trim();
    const position = positionDefinition(positionId);
    if (!position || position.adminOnly) throw new HttpsError("invalid-argument", "Select a valid barangay position.");
    role = position.role;
    positionTitle = positionId === "other_position"
      ? requiredText(input.otherPosition, "Position", 120) : position.name;
  } else {
    department = await activeLguDepartment(input.officeId);
    positionTitle = requiredText(input.positionTitle, "Position", 120);
    const service = LGU_SERVICE_TYPES.find((item) => item.id === input.serviceTypeId);
    if (!service) throw new HttpsError("invalid-argument", "Select an LGU service type.");
    serviceTypeId = service.id;
    serviceType = service.name;
    serviceDescription = service.id === "other_lgu_service"
      ? requiredText(input.serviceDescription, "LGU service", 120) : "";
    routingCategoryId = service.categoryId || "";
  }
  const proofType = String(input.proofType || "").trim();
  if (!PROOF_TYPES[accountType].includes(proofType)) {
    throw new HttpsError("invalid-argument", "Select a proof document type.");
  }
  const proofDocumentName = proofType === "other" ? requiredText(input.proofDocumentName, "Document name", 120) : "";
  const proofStoragePath = String(input.proofStoragePath || "").trim();
  const proofPrefix = `staff_registration_proofs/${request.auth.uid}/`;
  const proofExtension = proofStoragePath.split(".").pop()?.toLowerCase();
  if (!proofStoragePath.startsWith(proofPrefix)
    || !/^proof-[a-f0-9-]{36}\.(pdf|jpg|jpeg|png)$/.test(proofStoragePath.slice(proofPrefix.length))) {
    throw new HttpsError("invalid-argument", "Upload a valid proof document.");
  }
  let proofMetadata;
  try {
    [proofMetadata] = await getStorage().bucket().file(proofStoragePath).getMetadata();
  } catch (_) {
    throw new HttpsError("failed-precondition", "The proof document could not be found. Upload it again.");
  }
  const proofContentType = String(proofMetadata.contentType || "").toLowerCase();
  const proofSize = Number(proofMetadata.size || 0);
  if (!["application/pdf", "image/jpeg", "image/png"].includes(proofContentType)
    || proofSize < 1 || proofSize > 8 * 1024 * 1024) {
    throw new HttpsError("invalid-argument", "Proof must be a PDF, JPG, or PNG under 8 MB.");
  }
  const [proofHeader] = await getStorage().bucket().file(proofStoragePath).download({ start: 0, end: 7 });
  if (!validOrganizationProofHeader(proofHeader, proofContentType, proofExtension)) {
    throw new HttpsError("invalid-argument", "The proof document does not match its PDF, JPG, or PNG file type.");
  }
  const profileRef = db.collection("users").doc(request.auth.uid);
  const requestRef = db.collection("staff_account_requests").doc();
  let existingRequestId = "";
  const now = FieldValue.serverTimestamp();
  const details = {
    name, firstName, middleName, lastName, extensionName, email, contactNumber,
    accountType, role, positionId, positionCode: role === "barangay_councilor" ? positionId : "",
    positionTitle, barangay, barangayId,
    department: department.name, departmentId: department.id, departmentPublicName: department.publicName,
    officeId: department.id, lguServiceTypeId: serviceTypeId, lguServiceType: serviceType,
    lguServiceDescription: serviceDescription, routingCategoryId,
    proofType, proofDocumentName, proofStoragePath,
  };
  const writeRequest = (transaction) => {
    transaction.create(requestRef, {
      ...details, createdUserId: request.auth.uid,
      status: "pending", accountStatus: "pending", approvalRequired: true,
      creationSource: "staff_self_registration", credentialDeliveryRequired: false,
      requestedBy: request.auth.uid, requestedById: request.auth.uid,
      requestedByName: name, requestedByRole: `${accountType}_applicant`,
      requestedAt: now, createdAt: now,
    });
    transaction.create(profileRef, {
      uid: request.auth.uid, ...details,
      status: "pending_review", accountStatus: "pending_approval",
      verificationStatus: "not_applicable", approvalRequired: true, setupRequired: false,
      creationSource: "staff_self_registration", staffAccountRequestId: requestRef.id,
      createdAt: now, updatedAt: now,
    });
    transaction.create(db.collection("audit_logs").doc(), {
      action: "staff_registration_requested", actorId: request.auth.uid,
      entityType: "staff_account_request", entityId: requestRef.id,
      barangayId, departmentId: department.id, createdAt: now,
    });
  };
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(profileRef);
    if (existing.exists) {
      if (existing.data().creationSource === "staff_self_registration"
        && existing.data().accountStatus === "pending_approval") {
        existingRequestId = existing.data().staffAccountRequestId;
        return;
      }
      throw new HttpsError("already-exists", "This email already has an E-SUGID account.");
    }
    if (accountType === "barangay") await requireAvailablePosition(transaction, barangayId, positionId);
    writeRequest(transaction);
  });
  return { requestId: existingRequestId || requestRef.id, status: "pending" };
});

exports.requestStaffAccount = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, 'staff:request')) {
    throw new HttpsError('permission-denied', 'Account requests are disabled for this office.');
  }
  const role = canonicalRole(request.data?.role);
  if (!requestedRolesFor(actor).has(role)) {
    throw new HttpsError("permission-denied", "You cannot request this account type.");
  }
  const email = normalizedEmail(request.data?.email);
  const name = requiredText(request.data?.name, "Full name", 120);
  const organizationRequester = canonicalRole(actor.role) === "organization";
  const password = organizationRequester
    ? `${randomBytes(24).toString("base64url")}Aa1!`
    : requiredPassword(request.data?.password);
  const scope = staffScope(actor, request.data || {}, role);
  let organizationCategoryId = "";
  if (role === "organization") {
    const organization = await db.collection("organizations").doc(scope.organizationId).get();
    if (!organization.exists || !["verified", "active"].includes(String(organization.data()?.status || "").toLowerCase())) {
      throw new HttpsError("failed-precondition", "Select an active organization from the directory.");
    }
    scope.organizationName = requiredText(organization.data().name, "Organization", 140);
    organizationCategoryId = String(organization.data().categoryId || "");
    if (!concernCategory(organizationCategoryId)) {
      throw new HttpsError("failed-precondition", "An Admin must assign a concern category to this organization first.");
    }
  }
  const lguDepartment = role === "lgu"
    ? await lguDepartmentForAccount(actor, request.data || {})
    : { id: "", name: "", publicName: "" };
  const barangayPositionCode = role === "barangay_councilor"
    ? optionalText(request.data?.positionCode, 80).toLowerCase()
    : "";
  const barangayPositionTitle = role === "barangay_councilor"
    ? secondaryBarangayPositionLabel(barangayPositionCode)
    : "";
  if (role === "barangay_councilor" && !barangayPositionTitle) {
    throw new HttpsError("invalid-argument", "Select an allowed barangay official position.");
  }
  const positionTitle = barangayPositionTitle
    || optionalText(request.data?.positionTitle, 120)
    || positionForRole(role);
  const contactNumber = organizationRequester
    ? optionalText(request.data?.contactNumber || actor.contactNumber, 30)
    : requiredPhilippineMobile(request.data?.contactNumber);
  const organizationType = role === "organization"
    ? optionalText(request.data?.organizationType || actor.organizationType, 120)
    : "";
  const coverageArea = role === "organization"
    ? optionalText(request.data?.coverageArea || actor.coverageArea, 160)
    : "";
  const duplicate = await db.collection("staff_account_requests")
    .where("email", "==", email)
    .limit(10)
    .get();
  if (duplicate.docs.some((item) => isOpenAccountRequest(item.data()))) {
    throw new HttpsError("already-exists", "A pending request already uses this email.");
  }
  let userRecord;
  try {
    userRecord = await getAuth().createUser({
      email,
      emailVerified: false,
      displayName: name,
      password,
      // Authentication is allowed so the applicant can see the pending state.
      // Firestore rules and every privileged callable still require an active
      // profile, so no Barangay or organization privileges are granted here.
      disabled: false,
    });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This email is already associated with an E-SUGID account.");
    }
    throw new HttpsError("internal", "The staff account request could not be created.");
  }
  const reference = db.collection("staff_account_requests").doc();
  const now = FieldValue.serverTimestamp();
  const reviewers = await municipalAccountReviewers();
  const positionId = role === "barangay_councilor" ? barangayPositionCode : "";
  const requestData = {
    createdUserId: userRecord.uid,
    name,
    email,
    role,
    positionTitle,
    positionCode: barangayPositionCode,
    positionId,
    accountType: role === "barangay_councilor" ? "barangay_official" : role,
    contactNumber,
    barangay: scope.barangay,
    barangayId: scope.barangayId,
    canVerifyResidents: false,
    organizationId: scope.organizationId,
    organizationName: scope.organizationName,
    organizationCategoryId,
    department: lguDepartment.name,
    departmentId: lguDepartment.id,
    departmentPublicName: lguDepartment.publicName,
    organizationType,
    coverageArea,
    status: "pending",
    accountStatus: "pending",
    requestedBy: actor.id,
    requestedById: actor.id,
    requestedByName: actor.name || actor.email || "Staff member",
    requestedByRole: actor.role,
    requestedAt: now,
    approvalRequired: true,
    creationSource: "staff_request",
    credentialDeliveryRequired: organizationRequester,
    recipientEmail: organizationRequester ? email : "",
    createdAt: now,
  };
  const pendingWrites = [];
  const batch = { set: (...args) => pendingWrites.push(args) };
  batch.set(reference, requestData);
  batch.set(db.collection("users").doc(userRecord.uid), {
    uid: userRecord.uid,
    name,
    email,
    role,
    positionTitle,
    positionCode: barangayPositionCode,
    positionId,
    accountType: role === "barangay_councilor" ? "barangay_official" : role,
    contactNumber,
    status: "pending_review",
    accountStatus: "pending_approval",
    verificationStatus: "not_applicable",
    approvalRequired: true,
    creationSource: "staff_request",
    staffAccountRequestId: reference.id,
    setupRequired: true,
    credentialDeliveryRequired: organizationRequester,
    recipientEmail: organizationRequester ? email : "",
    barangay: scope.barangay,
    barangayId: scope.barangayId,
    canVerifyResidents: false,
    canCreateBarangayOfficialRequests: false,
    organizationId: scope.organizationId,
    organizationName: scope.organizationName,
    organizationCategoryId,
    department: lguDepartment.name,
    departmentId: lguDepartment.id,
    departmentPublicName: lguDepartment.publicName,
    organizationType,
    coverageArea,
    createdAt: now,
    createdBy: actor.id,
  });
  batch.set(
    db.collection("notifications").doc(`account_pending_${reference.id}_${userRecord.uid}`),
    {
      userId: userRecord.uid,
      type: "account_approval_pending",
      referenceId: reference.id,
      relatedEntityType: "account_approval",
      title: "Account approval pending",
      message: `Your ${positionTitle} account request is awaiting review.`,
      read: false,
      createdAt: now,
    },
  );
  batch.set(db.collection("audit_logs").doc(), {
    targetUserId: userRecord.uid,
    performedBy: actor.id,
    actorId: actor.id,
    actorEmail: actor.email || "",
    organizationId: scope.organizationId || "",
    departmentId: lguDepartment.id,
    action: "staff_account_requested",
    requestedRole: positionTitle,
    barangayId: scope.barangayId,
    entityType: "staff_account_request",
    entityId: reference.id,
    details: {
      role,
      positionCode: barangayPositionCode,
      positionTitle,
      barangay: scope.barangay,
      barangayId: scope.barangayId,
      canVerifyResidents: false,
      organizationId: scope.organizationId,
      departmentId: lguDepartment.id,
    },
    createdAt: now,
  });
  reviewers.forEach((reviewer) => {
    batch.set(db.collection("notifications").doc(), {
      userId: reviewer.id,
      type: "account_approval_requested",
      referenceId: reference.id,
      title: "New Account Approval Request",
      message: role === "barangay_councilor"
        ? `A ${positionTitle} account request from ${scope.barangay} is waiting for review.`
        : `${name} requested ${positionTitle} access.`,
      read: false,
      createdAt: now,
    });
  });
  try {
    await db.runTransaction(async (transaction) => {
      if (positionId) await requireAvailablePosition(transaction, scope.barangayId, positionId);
      pendingWrites.forEach((args) => transaction.set(...args));
    });
  } catch (error) {
    await getAuth().deleteUser(userRecord.uid).catch(() => { });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "The staff account request could not be saved.");
  }
  await sendNormalPushToUsers(reviewers.map((reviewer) => reviewer.id), {
    title: "New Account Approval Request",
    body: role === "barangay_councilor"
      ? `A ${positionTitle} account request from ${scope.barangay} is waiting for review.`
      : `${name} requested ${positionTitle} access.`,
    type: "account_approval_requested",
    referenceId: reference.id,
  }).catch((error) => console.error("[ACCOUNT APPROVAL] Reviewer push failed", { code: error.code }));
  return { requestId: reference.id };
});

exports.reviewStaffAccountRequest = onCall({
  region: REGION,
  secrets: [BREVO_API_KEY],
}, async (request) => {
  const actor = await approvedCaller(request);
  if (!isItAdministrator(actor.role)) {
    throw new HttpsError("permission-denied", "Only the LGU IT administrator can review account requests.");
  }
  const requestId = requiredText(request.data?.requestId, "Request", 160);
  const decision = String(request.data?.decision || "").trim().toLowerCase();
  if (!["approved", "rejected"].includes(decision)) {
    throw new HttpsError("invalid-argument", "Choose approve or reject.");
  }
  const reason = decision === "rejected"
    ? requiredText(request.data?.reason, "Rejection reason", 120)
    : "";
  const note = decision === "rejected" ? optionalText(request.data?.note, 600) : "";
  if (decision === "rejected" && !isValidAccountRejectionReason(reason)) {
    throw new HttpsError("invalid-argument", "Select a valid account rejection reason.");
  }
  if (reason === "Other" && !note) {
    throw new HttpsError("invalid-argument", "Add a short note explaining the rejection.");
  }
  const reference = db.collection("staff_account_requests").doc(requestId);
  const claimTime = Timestamp.now();
  let accountRequest;
  let userId;
  let selfRegistration = false;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) throw new HttpsError("not-found", "The account approval request was not found.");
    accountRequest = snapshot.data();
    selfRegistration = ["organization_self_registration", "staff_self_registration"]
      .includes(accountRequest.creationSource);
    if (!canClaimAccountRequest(
      accountRequest.accountStatus || accountRequest.status,
      timestampMillis(accountRequest.reviewStartedAt),
    )) {
      throw new HttpsError("failed-precondition", "This account request has already been reviewed.");
    }
    if (!canReviewAccountRequest(actor.role, accountRequest.role)) {
      throw new HttpsError("permission-denied", "You cannot review this account type.");
    }
    if (!isAllowedAccountRequest(accountRequest.role, accountRequest.positionCode)) {
      throw new HttpsError("failed-precondition", "This request contains an unsupported account role.");
    }
    userId = requiredText(accountRequest.createdUserId, "Pending account", 160);
    const profileSnapshot = await transaction.get(db.collection("users").doc(userId));
    if (!profileSnapshot.exists) {
      throw new HttpsError("failed-precondition", "The pending account profile no longer exists.");
    }
    const pendingProfile = profileSnapshot.data();
    const pendingStatus = accountRequestStatus(pendingProfile.accountStatus || pendingProfile.status);
    if (!["pending"].includes(pendingStatus)
      || pendingProfile.staffAccountRequestId !== requestId
      || canonicalRole(pendingProfile.role) !== canonicalRole(accountRequest.role)
      || String(pendingProfile.positionCode || "") !== String(accountRequest.positionCode || "")) {
      throw new HttpsError("failed-precondition", "The pending account no longer matches this request.");
    }

    if (selfRegistration) {
      if (accountRequest.requestedById !== userId
        || pendingProfile.creationSource !== accountRequest.creationSource) {
        throw new HttpsError("failed-precondition", "The registration no longer matches this account.");
      }
      if (accountRequest.creationSource === "organization_self_registration") {
        if (canonicalRole(accountRequest.role) !== "organization"
          || pendingProfile.organizationId !== accountRequest.organizationId
          || organizationKey(accountRequest.organizationName) !== accountRequest.organizationId) {
          throw new HttpsError("failed-precondition", "The organization registration no longer matches this account.");
        }
      } else if (!["lgu", "barangay_captain", "barangay_secretary", "barangay_councilor"]
        .includes(canonicalRole(accountRequest.role))) {
        throw new HttpsError("failed-precondition", "The staff registration contains an unsupported role.");
      }
      if (decision === "approved" && ["organization", "lgu"].includes(canonicalRole(accountRequest.role))) {
        const categoryId = canonicalConcernCategoryId(String(request.data?.categoryId || accountRequest.routingCategoryId
          || accountRequest.organizationCategoryId || "").trim());
        if (!concernCategory(categoryId)) {
          throw new HttpsError("invalid-argument", "Select a valid concern-routing category.");
        }
        if (canonicalRole(accountRequest.role) === "organization") {
          const existingOrganization = await transaction.get(
            db.collection("organizations").doc(accountRequest.organizationId),
          );
          if (existingOrganization.exists) {
            const master = existingOrganization.data();
            if (organizationKey(master.name || "") !== accountRequest.organizationId) {
              throw new HttpsError("failed-precondition", "The organization name no longer matches Structure.");
            }
          }
          accountRequest.organizationCategoryId = categoryId;
          accountRequest.organizationTypeId = categoryId;
          accountRequest.organizationType = concernCategory(categoryId).name;
          accountRequest.organizationSector = concernCategory(categoryId).sector;
        }
        accountRequest.routingCategoryId = categoryId;
      }
    } else {
      const requesterId = requiredText(
        accountRequest.requestedById || accountRequest.requestedBy,
        "Requesting account",
        160,
      );
      const requesterSnapshot = await transaction.get(db.collection("users").doc(requesterId));
      const requester = requesterSnapshot.data();
      if (!requesterSnapshot.exists || !isActiveProfile(requester)) {
        throw new HttpsError("failed-precondition", "The requesting account is no longer authorized.");
      }
      const requesterActor = { ...requester, role: canonicalRole(requester.role) };
      if (!requestedRolesFor(requesterActor).has(canonicalRole(accountRequest.role))) {
        throw new HttpsError("failed-precondition", "The requesting account is no longer authorized for this role request.");
      }
      if (canonicalRole(accountRequest.role) === "lgu") {
        const requesterDepartmentId = effectiveDepartmentId(requester);
        if (canonicalRole(requester.role) !== "lgu"
          || !requesterDepartmentId
          || requesterDepartmentId !== accountRequest.departmentId
          || requesterDepartmentId !== effectiveDepartmentId(pendingProfile)) {
          throw new HttpsError("failed-precondition", "The requested LGU department assignment could not be verified.");
        }
      } else if (["barangay_vice_captain", "barangay_secretary", "barangay_councilor"].includes(canonicalRole(accountRequest.role))) {
        const requesterRole = requesterActor.role;
        const requesterBarangayId = effectiveBarangayId(requester);
        if (!["barangay_captain", "barangay_vice_captain", "barangay_secretary"].includes(requesterRole)
          || !requesterBarangayId
          || requesterBarangayId !== accountRequest.barangayId
          || requesterBarangayId !== pendingProfile.barangayId) {
          throw new HttpsError("failed-precondition", "The requested Barangay assignment could not be verified.");
        }
      } else if (canonicalRole(accountRequest.role) === "organization") {
        const requesterOrganizationId = String(
          requester.organizationId || organizationKey(requester.organizationName),
        ).trim();
        if (canonicalRole(requester.role) !== "organization"
          || !requesterOrganizationId
          || requesterOrganizationId !== accountRequest.organizationId
          || requesterOrganizationId !== pendingProfile.organizationId) {
          throw new HttpsError("failed-precondition", "The requested organization assignment could not be verified.");
        }
        if (decision === "approved") {
          const organizationSnapshot = await transaction.get(db.collection("organizations").doc(requesterOrganizationId));
          if (!organizationSnapshot.exists
            || !["verified", "active"].includes(String(organizationSnapshot.data().status || "").toLowerCase())
            || !concernCategory(organizationSnapshot.data().categoryId)) {
            throw new HttpsError("failed-precondition", "An Admin must assign a valid category to this organization before approval.");
          }
          accountRequest.organizationCategoryId = organizationSnapshot.data().categoryId;
        }
      }
    }

    if (decision === "approved" && BARANGAY_ROLES.has(canonicalRole(accountRequest.role))) {
      const selectedPositionId = String(request.data?.positionId || positionIdForAccount(accountRequest));
      const selectedPosition = positionDefinition(selectedPositionId);
      if (selectedPosition) {
        await requireAvailablePosition(transaction, accountRequest.barangayId,
          selectedPositionId, requestId);
        if (selectedPositionId !== positionIdForAccount(accountRequest)) {
          accountRequest.positionId = selectedPositionId;
          accountRequest.positionCode = selectedPosition.role === "barangay_councilor" ? selectedPositionId : "";
          accountRequest.positionTitle = selectedPosition.name;
          accountRequest.role = selectedPosition.role;
        }
      }
    }
    transaction.update(reference, {
      status: "reviewing",
      accountStatus: "reviewing",
      reviewClaimedBy: actor.id,
      reviewStartedAt: claimTime,
    });
  });

  const requestedRole = accountRequest.positionTitle || positionForRole(accountRequest.role);
  const isOrganizationRequest = canonicalRole(accountRequest.role) === "organization";
  const credentialDeliveryRequired = decision === "approved"
    && accountRequest.credentialDeliveryRequired === true;
  const approvalTemporaryPassword = credentialDeliveryRequired
    ? generatedTemporaryPassword() : "";
  const approvalNotificationMessage = isOrganizationRequest
    ? `Your ${requestedRole} account for ${accountRequest.organizationName || "E-SUGID"} has been approved.`
    : canonicalRole(accountRequest.role) === "lgu"
      ? `Your ${requestedRole} account for ${accountRequest.departmentPublicName || accountRequest.department || "the LGU"} has been approved.`
      : `Your ${requestedRole} account for Barangay ${accountRequest.barangay || "Barili"} has been approved.`;
  const rejectionNotificationMessage = `Your ${requestedRole} account request was not approved. Reason: ${reason}.`;

  let previousAuthDisabled;
  let previousEmailVerified;
  let authStateChanged = false;
  try {
    const authUser = await getAuth().getUser(userId);
    if (selfRegistration && decision === "approved") {
      if (String(authUser.email || "").trim().toLowerCase() !== accountRequest.email) {
        throw new HttpsError("failed-precondition", "The applicant's login email no longer matches this request.");
      }
      if (accountRequest.proofStoragePath) {
        let proofExists = true;
        try {
          const [exists] = await getStorage().bucket().file(accountRequest.proofStoragePath).exists();
          proofExists = exists;
        } catch (storageError) {
          console.warn("[ACCOUNT APPROVAL] Storage check warning:", storageError?.message);
        }
        if (!proofExists) {
          throw new HttpsError("failed-precondition", "The proof document is missing. Ask the applicant to contact the LGU.");
        }
      }
    }
    previousAuthDisabled = authUser.disabled;
    previousEmailVerified = authUser.emailVerified;
    // Self-registered applicants may sign in only far enough to read a
    // rejection reason; the inactive profile still blocks all staff access.
    const nextDisabled = decision !== "approved" && !selfRegistration;
    const shouldVerifyEmail = decision === "approved" && !authUser.emailVerified;
    if (previousAuthDisabled !== nextDisabled || shouldVerifyEmail || approvalTemporaryPassword) {
      await getAuth().updateUser(userId, {
        disabled: nextDisabled,
        ...(shouldVerifyEmail ? { emailVerified: true } : {}),
        ...(approvalTemporaryPassword ? { password: approvalTemporaryPassword } : {}),
      });
      authStateChanged = true;
    }
    const notificationReference = db.collection("notifications").doc();
    const requesterId = accountRequest.requestedById || accountRequest.requestedBy || "";
    const requesterNotificationReference = requesterId && requesterId !== userId
      ? db.collection("notifications").doc()
      : null;
    const auditReference = db.collection("audit_logs").doc();
    await db.runTransaction(async (transaction) => {
      const claimed = await transaction.get(reference);
      const current = claimed.data();
      if (!claimed.exists
        || (current.accountStatus || current.status) !== "reviewing"
        || current.reviewClaimedBy !== actor.id) {
        throw new HttpsError("failed-precondition", "This account request has already been reviewed.");
      }
      const organizationRef = accountRequest.creationSource === "organization_self_registration"
        ? db.collection("organizations").doc(accountRequest.organizationId) : null;
      let organizationAlreadyListed = false;
      if (organizationRef && decision === "approved") {
        const existingOrganization = await transaction.get(organizationRef);
        organizationAlreadyListed = existingOrganization.exists;
        if (existingOrganization.exists) {
          const master = existingOrganization.data();
          if (organizationKey(master.name || "") !== accountRequest.organizationId) {
            throw new HttpsError("failed-precondition", "The organization name no longer matches Structure.");
          }
        }
        const members = await transaction.get(db.collection("users")
          .where("organizationId", "==", accountRequest.organizationId));
        if (members.docs.some((member) => member.id !== userId
          && isActiveProfile(member.data())
          && canonicalRole(member.data().role) === "organization")) {
          throw new HttpsError("already-exists", "This organization already has an active account.");
        }
      }
      const now = FieldValue.serverTimestamp();
      const approved = decision === "approved";
      if (organizationRef && approved) {
        transaction.set(organizationRef, {
          organizationId: accountRequest.organizationId,
          name: accountRequest.organizationName,
          organizationName: accountRequest.organizationName,
          organizationType: accountRequest.organizationType,
          organizationTypeId: accountRequest.organizationTypeId,
          organizationTypeName: accountRequest.organizationType,
          organizationSector: accountRequest.organizationSector || concernCategory(accountRequest.organizationCategoryId)?.sector || "public",
          categoryId: accountRequest.organizationCategoryId,
          address: accountRequest.organizationAddress,
          barangay: accountRequest.barangay,
          barangayId: accountRequest.barangayId,
          contactPerson: accountRequest.name,
          contactNumber: accountRequest.contactNumber,
          email: accountRequest.email,
          primaryAdminId: userId,
          serviceBarangays: [],
          municipalityWidePublishing: false,
          status: "verified",
          ...(!organizationAlreadyListed ? { createdAt: now, createdBy: actor.id } : {}),
          updatedAt: now,
          updatedBy: actor.id,
        }, { merge: true });
      }
      transaction.set(db.collection("users").doc(userId), {
        status: approved ? ACTIVE_STATUS : "rejected",
        accountStatus: approved ? "active" : "rejected",
        verificationStatus: "not_applicable",
        approvalRequired: false,
        setupRequired: selfRegistration ? false : true,
        ...(approved ? {
          role: canonicalRole(accountRequest.role),
          positionTitle: requestedRole,
          positionCode: accountRequest.positionCode || "",
          positionId: accountRequest.positionId || "",
          accountType: accountRequest.accountType
            || (canonicalRole(accountRequest.role) === "organization" ? "organization" : "barangay_official"),
          barangay: accountRequest.barangay || "",
          barangayId: accountRequest.barangayId || "",
          organizationId: accountRequest.organizationId || "",
          organizationName: accountRequest.organizationName || "",
          organizationSector: accountRequest.organizationSector || "public",
          organizationCategoryId: accountRequest.organizationCategoryId || "",
          routingCategoryId: accountRequest.routingCategoryId || "",
          lguServiceTypeId: accountRequest.lguServiceTypeId || "",
          lguServiceType: accountRequest.lguServiceType || "",
          lguServiceDescription: accountRequest.lguServiceDescription || "",
          department: accountRequest.department || "",
          departmentId: accountRequest.departmentId || "",
          departmentPublicName: accountRequest.departmentPublicName || "",
          canCreateBarangayOfficialRequests: false,
          approvedAt: now,
          approvedBy: actor.id,
          ...(credentialDeliveryRequired ? {
            recipientEmail: accountRequest.email,
            accessMethod: "Email",
            distributionMethod: "email",
            activationExpiresAt: Timestamp.fromDate(new Date(Date.now() + ACTIVATION_LIFETIME_MS)),
          } : {}),
          rejectedAt: FieldValue.delete(),
          rejectedBy: FieldValue.delete(),
          rejectionReason: FieldValue.delete(),
          rejectionNote: FieldValue.delete(),
        } : {
          rejectedAt: now,
          rejectedBy: actor.id,
          rejectionReason: reason,
          rejectionNote: note,
        }),
        updatedAt: now,
      }, { merge: true });
      transaction.update(reference, {
        status: decision,
        accountStatus: decision,
        reviewedAt: now,
        reviewedBy: actor.id,
        reviewedByName: actor.name || actor.email || "Administrator",
        reviewedByRole: actor.role,
        reviewClaimedBy: FieldValue.delete(),
        reviewStartedAt: FieldValue.delete(),
        ...(approved ? {
          approvedAt: now,
          approvedBy: actor.id,
          approvedByName: actor.name || actor.email || "Administrator",
          approvedByRole: actor.role,
          ...(isOrganizationRequest ? {
            organizationCategoryId: accountRequest.organizationCategoryId || "",
            ...(selfRegistration ? {
              organizationTypeId: accountRequest.organizationTypeId || "",
              organizationType: accountRequest.organizationType || "",
              organizationSector: accountRequest.organizationSector || "public",
            } : {}),
          } : {}),
          ...(selfRegistration ? { reviewedCategoryId: accountRequest.routingCategoryId || accountRequest.organizationCategoryId || "" } : {}),
          ...(accountRequest.positionId ? {
            positionId: accountRequest.positionId,
            positionCode: accountRequest.positionCode || "", positionTitle: accountRequest.positionTitle,
            role: accountRequest.role, reviewedPositionId: accountRequest.positionId
          } : {}),
          reviewReason: FieldValue.delete(),
          rejectionReason: FieldValue.delete(),
          rejectionNote: FieldValue.delete(),
        } : {
          rejectedAt: now,
          rejectedBy: actor.id,
          rejectedByName: actor.name || actor.email || "Administrator",
          rejectedByRole: actor.role,
          reviewReason: reason,
          rejectionReason: reason,
          rejectionNote: note,
        }),
      });
      transaction.set(notificationReference, {
        userId,
        type: approved ? "account_approved" : "account_rejected",
        referenceId: requestId,
        relatedEntityType: "account_approval",
        title: approved ? "Account approved" : "Account request was not approved",
        message: approved ? approvalNotificationMessage : rejectionNotificationMessage,
        reason: approved ? "" : reason,
        read: false,
        createdAt: now,
      });
      if (requesterNotificationReference) {
        transaction.set(requesterNotificationReference, {
          userId: requesterId,
          type: approved ? "account_approved" : "account_rejected",
          referenceId: requestId,
          relatedEntityType: "account_approval",
          title: approved ? "Account approved" : "Account request was not approved",
          message: approved
            ? `${requestedRole} account for ${accountRequest.name} was approved.`
            : `${requestedRole} account for ${accountRequest.name} was rejected. Reason: ${reason}.`,
          reason: approved ? "" : reason,
          read: false,
          createdAt: now,
        });
      }
      transaction.set(auditReference, {
        requestId,
        targetUserId: userId,
        performedBy: actor.id,
        performedAt: now,
        actorId: actor.id,
        actorEmail: actor.email || "",
        action: approved ? "AccountApproved" : "AccountRejected",
        actionCode: approved ? "account_approved" : "account_rejected",
        requestedRole,
        entityType: "account_approval",
        entityId: requestId,
        barangayId: accountRequest.barangayId || "",
        organizationId: accountRequest.organizationId || "",
        departmentId: accountRequest.departmentId || "",
        requestedBy: accountRequest.requestedById || accountRequest.requestedBy || "",
        reason: approved ? "" : reason,
        details: {
          requestedRole,
          positionCode: accountRequest.positionCode || "",
          rejectionNote: approved ? "" : note,
          departmentId: accountRequest.departmentId || "",
        },
        createdAt: now,
      });
    });
  } catch (error) {
    if (authStateChanged) {
      await getAuth().updateUser(userId, {
        disabled: previousAuthDisabled,
        emailVerified: previousEmailVerified,
      }).catch(() => { });
    }
    await db.runTransaction(async (transaction) => {
      const claimed = await transaction.get(reference);
      if (claimed.exists
        && (claimed.data()?.accountStatus || claimed.data()?.status) === "reviewing"
        && claimed.data()?.reviewClaimedBy === actor.id) {
        transaction.update(reference, {
          status: "pending",
          accountStatus: "pending",
          reviewClaimedBy: FieldValue.delete(),
          reviewStartedAt: FieldValue.delete(),
        });
      }
    }).catch(() => { });
    if (error instanceof HttpsError) throw error;
    if (error?.code === "auth/user-not-found") {
      throw new HttpsError("failed-precondition", "The pending login account no longer exists.");
    }
    throw new HttpsError("internal", "The account approval decision could not be saved.");
  }

  const approved = decision === "approved";
  if (process.env.ESUGID_DISABLE_EXTERNAL_DELIVERY !== "1") {
    const decisionRecipients = [...new Set([userId, accountRequest.requestedById || accountRequest.requestedBy].filter(Boolean))];
    await sendNormalPushToUsers(decisionRecipients, {
      title: approved ? "Account approved" : "Account request was not approved",
      body: approved ? approvalNotificationMessage : rejectionNotificationMessage,
      type: approved ? "account_approved" : "account_rejected",
      referenceId: requestId,
    }).catch((error) => console.error("[ACCOUNT APPROVAL] User push failed", { code: error.code }));
    await sendAccountDecisionEmail({
      recipientEmail: accountRequest.email,
      name: accountRequest.name || "E-SUGID user",
      decision,
      reason,
      note,
    }).catch((error) => console.error("[ACCOUNT APPROVAL] Decision email failed", mailFailureDetails(error)));
    if (credentialDeliveryRequired) {
      await sendStaffCredentialsEmail({
        recipientEmail: accountRequest.email,
        loginEmail: accountRequest.email,
        temporaryPassword: approvalTemporaryPassword,
        name: accountRequest.name || "E-SUGID user",
        role: accountRequest.role,
        assignment: accountRequest.organizationName || "E-SUGID organization",
        positionTitle: requestedRole,
        loginUrl: configuredAppBaseUrl(),
        optionalMessage: "Your organization account request was approved by the LGU.",
      }).catch((error) => console.error("[ACCOUNT APPROVAL] Organization invitation failed", mailFailureDetails(error)));
    }
  }
  console.info("[ACCOUNT APPROVAL] Review completed", {
    requestId,
    decision,
    requestedRole,
  });
  return { uid: userId, email: accountRequest.email, requestId, status: decision };
});

exports.expireAnnouncements = onSchedule(
  { schedule: "every 30 minutes", timeZone: "Asia/Manila", region: REGION },
  async () => {
    const expired = await db
      .collection("posts")
      .where("status", "==", "approved")
      .where("expiresAt", "<=", new Date())
      .limit(400)
      .get();
    await commitInChunks(
      expired.docs,
      () => ({
        status: "expired",
        notificationRequested: false,
        expiredAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }),
      "announcement_expired_automatically",
    );
  },
);

exports.expireEmergencyAlerts = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Manila", region: REGION },
  async () => {
    const expired = await db
      .collection("alerts")
      .where("active", "==", true)
      .limit(400)
      .get();
    const now = Date.now();
    const expiredDocuments = expired.docs.filter((document) => {
      const value = document.data().expiresAt;
      const expiry = value?.toDate ? value.toDate().getTime() : Date.parse(value || "");
      return Number.isFinite(expiry) && expiry <= now;
    });
    await commitInChunks(
      expiredDocuments,
      () => ({
        active: false,
        status: "expired",
        notificationRequested: false,
        expiredAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }),
      "emergency_alert_expired_automatically",
    );
  },
);

exports.syncAnnouncementFeeds = onDocumentWritten(
  { document: "posts/{postId}", region: REGION },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await syncPostFeeds(event.params.postId, before, after);
    if (!after && typeof before?.imageStoragePath === "string") {
      const segments = before.imageStoragePath.split("/");
      if (segments.length === 4 && segments[0] === "announcements"
        && segments[1] && segments[2] === event.params.postId && segments[3]) {
        await getStorage().bucket().file(before.imageStoragePath).delete({ ignoreNotFound: true });
      }
    }
  },
);

exports.syncAnnouncementCalendarEvent = onDocumentWritten(
  { document: "posts/{postId}", region: REGION },
  async (event) => {
    const postId = event.params.postId;
    const eventRef = db.collection("calendar_events").doc(`source_announcement_${postId}`);
    // Triggers may arrive out of order. Resolve the current source in the same
    // transaction as the event write so an older delivery cannot restore a stale schedule.
    await db.runTransaction(async (transaction) => {
      const source = await transaction.get(db.collection("posts").doc(postId));
      const after = source.exists ? source.data() : null;
      const existing = await transaction.get(eventRef);
      const isPublished = after && ["approved", "published"].includes(String(after.status || "").toLowerCase());
      const schedule = require("./announcement_schedule").announcementSchedule(after);
      const shouldSync = isPublished && schedule && after.eventCancelled !== true;

      if (!shouldSync) {
        if (existing.exists && existing.data().status !== "cancelled") {
          transaction.update(eventRef, {
            status: "cancelled",
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      const { startAt, endAt, allDay } = schedule;
      const publicAudience = after.visibility === "public";
      const targets = Array.isArray(after.targetBarangays) ? after.targetBarangays.filter(Boolean) : [];
      if (!publicAudience && targets.length === 0 && !after.targetBarangay) {
        console.error("Announcement calendar sync requires a target audience", { postId, targets });
        if (existing.exists) {
          transaction.update(eventRef, { status: "cancelled", updatedAt: FieldValue.serverTimestamp() });
        }
        return;
      }
      const targetList = targets.length > 0 ? targets : (after.targetBarangay && after.targetBarangay !== "All Barangays" ? [after.targetBarangay] : []);
      const audienceKeys = publicAudience ? ["municipality:barili"] : targetList.map((t) => `barangay:${t}`);

      transaction.set(eventRef, {
        id: eventRef.id,
        title: String(after.title || "Community activity").trim().slice(0, 120),
        description: String(after.content || "").trim().slice(0, 1200),
        startAt,
        endAt,
        allDay,
        category: "announcement",
        categoryName: String(after.customCategory || after.category || "Community Activity"),
        location: String(after.eventLocation || after.location || "").trim().slice(0, 200),
        createdBy: String(after.authorId || "system"),
        sourceType: "announcement",
        sourceId: postId,
        visibility: publicAudience ? "public" : "barangay",
        targetBarangay: publicAudience ? "" : targetList.length === 1 ? targetList[0] : "",
        targetUserIds: [],
        audienceKeys,
        status: "scheduled",
        isImportant: ["important", "urgent", "emergency"].includes(String(after.priority || "").toLowerCase()),
        organizerName: String(after.publisherEntityName || after.authorName || "E-SUGID").trim().slice(0, 120),
        updatedAt: FieldValue.serverTimestamp(),
        ...(existing.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
      }, { merge: true });
    });
  },
);

function formatManilaTime(date) {
  if (!date) return "";
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Manila",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(date);
}

function formatReminderTitle(post, timingWord) {
  const title = String(post.title || "Community Activity").trim();
  return `${title} ${timingWord}`;
}

function formatReminderBody(post, timingWord, timeString) {
  const location = post.eventLocation ? ` at ${post.eventLocation}` : (post.targetBarangay && post.targetBarangay !== "All Barangays" ? ` in Barangay ${post.targetBarangay}` : "");
  if (timeString && timeString !== "All Day") {
    return `Scheduled ${post.title || "activity"}${location} ${timingWord.toLowerCase()} from ${timeString}. Tap to view the advisory.`;
  }
  return `Scheduled ${post.title || "activity"}${location} ${timingWord.toLowerCase()}. Tap to view the advisory.`;
}

/**
 * A private organization's post is for its followers only; returns that
 * organization's ID, or "" when the post reaches its whole audience.
 */
async function followerOnlyOrganizationFor(post) {
  const organizationId = organizationIdForPost(post);
  if (!organizationId) return "";
  const organization = await db.collection("organizations").doc(organizationId).get();
  return organization.exists && isPrivateSectorOrganization(organization.data()) ?
    organizationId :
    "";
}

/** Active residents a post's notifications go to. */
async function announcementRecipients(announcement, followerOrganizationId) {
  const users = followerOrganizationId ?
    await db.collection("users")
      .where("followedOrganizationIds", "array-contains", followerOrganizationId)
      .limit(5000)
      .get() :
    await db.collection("users").limit(5000).get();
  return users.docs
    .map((document) => ({ id: document.id, ...document.data() }))
    .filter((profile) => profileMatchesAnnouncement(profile, announcement));
}

async function createActivityReminderInboxRecords(announcement, postId, title, message, recipients) {
  for (let offset = 0; offset < recipients.length; offset += 400) {
    const batch = db.batch();
    recipients.slice(offset, offset + 400).forEach((recipient) => {
      batch.set(
        db.collection("notifications")
          .doc(`reminder_${postId}_${recipient.id}`),
        {
          userId: recipient.id,
          type: "announcement_reminder",
          referenceId: postId,
          relatedEntityType: "community_post",
          title: String(title).slice(0, 120),
          message: String(message).slice(0, 500),
          priority: "important",
          navigation: { route: "/home", postId },
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    await batch.commit();
  }
  return recipients.length;
}

exports.sendScheduledActivityReminders = onSchedule(
  { schedule: "every 15 minutes", timeZone: "Asia/Manila", region: REGION },
  async () => {
    const now = new Date();
    const windowEnd = new Date(now.getTime() + 26 * 60 * 60 * 1000);

    const snapshot = await db.collection("posts")
      .where("status", "in", ["approved", "published"])
      .where("hasSchedule", "==", true)
      .limit(200)
      .get();

    for (const docSnap of snapshot.docs) {
      const post = docSnap.data();
      if (post.eventCancelled === true || post.activityReminderSent === true) continue;
      const schedule = require("./announcement_schedule").announcementSchedule(post);
      if (!schedule || !schedule.startAt) continue;

      const start = schedule.startAt.toDate ? schedule.startAt.toDate() : new Date(schedule.startAt);
      const end = schedule.endAt ? (schedule.endAt.toDate ? schedule.endAt.toDate() : new Date(schedule.endAt)) : null;

      if (start < now) {
        await docSnap.ref.update({
          activityReminderSent: true,
          activityReminderState: "past",
          updatedAt: FieldValue.serverTimestamp(),
        });
        continue;
      }

      if (start <= windowEnd) {
        const isToday = start.toDateString() === now.toDateString();
        const timingWord = isToday ? "Today" : "Tomorrow";
        const timeStr = schedule.allDay
          ? "All Day"
          : end
            ? `${formatManilaTime(start)} – ${formatManilaTime(end)}`
            : formatManilaTime(start);

        const title = formatReminderTitle(post, timingWord);
        const body = formatReminderBody(post, timingWord, timeStr);

        const targets = post.visibility === "public"
          ? ["barili_all"]
          : [...new Set((post.targetBarangays || []).map(topicForBarangay).filter(Boolean))];

        if (targets.length === 0 && post.targetBarangay && post.targetBarangay !== "All Barangays") {
          const topic = topicForBarangay(post.targetBarangay);
          if (topic) targets.push(topic);
        }

        const message = {
          notification: {
            title: title.slice(0, 120),
            body: body.slice(0, 240),
          },
          data: {
            type: "announcement",
            postId: docSnap.id,
            reminder: "true",
            priority: "important",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "esugid_announcement_important_v2",
              sound: "default",
              visibility: "public",
              defaultVibrateTimings: true,
            },
          },
        };

        try {
          const followerOrganizationId = await followerOnlyOrganizationFor(post);
          const recipients = await announcementRecipients(post, followerOrganizationId);
          await createActivityReminderInboxRecords(post, docSnap.id, title, body, recipients);
          if (followerOrganizationId) {
            await sendMessageToUserDevices(recipients.map((recipient) => recipient.id), message);
          } else if (targets.length > 0) {
            await Promise.all(targets.map((topic) => getMessaging().send({ ...message, topic })));
          }
          await docSnap.ref.update({
            activityReminderSent: true,
            activityReminderSentAt: FieldValue.serverTimestamp(),
            activityReminderState: "sent",
            updatedAt: FieldValue.serverTimestamp(),
          });
        } catch (err) {
          console.error("Failed to send scheduled activity reminder", docSnap.id, err);
        }
      }
    }
  },
);

exports.reconcileAnnouncementFeeds = onSchedule(
  { schedule: "every day 02:10", timeZone: "Asia/Manila", region: REGION },
  async () => {
    const published = await db
      .collection("posts")
      .where("status", "in", ["approved", "published"])
      .limit(400)
      .get();
    for (const snapshot of published.docs) {
      await syncPostFeeds(snapshot.id, null, snapshot.data());
    }
  },
);

function profileMatchesAnnouncement(profile, announcement) {
  if (!isActiveProfile(profile)) return false;
  if (announcement.visibility === "public") return true;
  const targetBarangays = Array.isArray(announcement.targetBarangays)
    ? announcement.targetBarangays
    : announcement.targetBarangay
      ? [announcement.targetBarangay]
      : [];
  const targets = new Set(targetBarangays.map(canonicalBarangayName).filter(Boolean));
  return targets.has(canonicalBarangayName(profile.barangay));
}

async function createAnnouncementInboxRecords(announcement, postId, revision, recipients) {
  for (let offset = 0; offset < recipients.length; offset += 400) {
    const batch = db.batch();
    recipients.slice(offset, offset + 400).forEach((recipient) => {
      batch.set(
        db.collection("notifications")
          .doc(`announcement_${postId}_${revision}_${recipient.id}`),
        {
          userId: recipient.id,
          type: "announcement",
          referenceId: postId,
          relatedEntityType: "community_post",
          title: String(announcement.title || "New community announcement").slice(0, 120),
          message: String(announcement.content || "New community information is available.").slice(0, 500),
          priority: String(announcement.priority || "regular").toLowerCase(),
          navigation: { route: "/home", postId },
          read: false,
          createdAt: announcement.publishedAt || FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    await batch.commit();
  }
  return recipients.length;
}

exports.deliverAnnouncementNotification = onDocumentWritten(
  { document: "posts/{postId}", region: REGION },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after || !["approved", "published"].includes(after.status)) return;
    if (after.notificationRequested !== true) return;

    const revision = Number(after.revision || 1);
    const publishingChanged =
      !before ||
      before.status !== after.status ||
      Number(before.revision || 1) !== revision ||
      before.notificationRequested !== after.notificationRequested;
    if (!publishingChanged) return;

    const postRef = event.data.after.ref;
    const claimed = await db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(postRef);
      const current = currentSnapshot.data() || {};
      if (Number(current.notificationSentRevision || 0) >= revision) return false;
      if (
        current.notificationState === "sending" &&
        Number(current.notificationClaimRevision || 0) === revision
      ) return false;
      transaction.update(postRef, {
        notificationState: "sending",
        notificationClaimRevision: revision,
        notificationClaimedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!claimed) return;

    const targets = after.visibility === "public"
      ? ["barili_all"]
      : [...new Set((after.targetBarangays || []).map(topicForBarangay).filter(Boolean))];
    if (!targets.length) {
      await postRef.update({
        notificationState: "skipped",
        notificationFailure: "No valid audience topics.",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const announcementPriority = String(after.priority || "regular").toLowerCase();
    const channelId = announcementPriority === "urgent"
      ? "esugid_announcement_urgent_v3"
      : announcementPriority === "important"
        ? "esugid_announcement_important_v2"
        : "esugid_announcement_regular_v2";
    const notification = {
      channelId,
      sound: "default",
      visibility: "public",
      defaultVibrateTimings: true,
    };
    const message = {
      notification: {
        title: String(after.title || "E-SUGID announcement").slice(0, 120),
        body: String(after.content || "New community information is available.").slice(0, 240),
      },
      data: {
        type: "announcement",
        postId: event.params.postId,
        priority: announcementPriority,
      },
      android: {
        // Only Severity=Emergency records use the emergency channel/sound.
        priority: "normal",
        notification,
      },
    };

    try {
      // Private organization posts go only to followers inside the audience,
      // device by device, never to the shared barangay topics.
      const followerOrganizationId = await followerOnlyOrganizationFor(after);
      const recipients = await announcementRecipients(after, followerOrganizationId);
      const inboxRecipients = await createAnnouncementInboxRecords(
        after,
        event.params.postId,
        revision,
        recipients,
      );
      if (followerOrganizationId) {
        await sendMessageToUserDevices(recipients.map((recipient) => recipient.id), message);
      } else {
        await Promise.all(targets.map((topic) => getMessaging().send({ ...message, topic })));
      }
      await postRef.update({
        notificationState: "sent",
        notificationSentRevision: revision,
        notificationSentAt: FieldValue.serverTimestamp(),
        notificationTopics: followerOrganizationId ? [] : targets,
        notificationAudience: followerOrganizationId ?
          `followers:${followerOrganizationId}` :
          "topics",
        notificationInboxRecipients: inboxRecipients,
        notificationFailure: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await postRef.update({
        notificationState: "failed",
        notificationFailure: String(error.message || error).slice(0, 500),
        updatedAt: FieldValue.serverTimestamp(),
      });
      throw error;
    }
  },
);

async function targetedResidentsFor(alert) {
  const snapshot = await db.collection("users")
    .where("role", "==", "resident")
    .limit(5000)
    .get();
  return snapshot.docs
    .map((document) => ({ id: document.id, ...document.data() }))
    .filter((resident) => isActiveProfile(resident) && residentMatchesAlert(resident, alert));
}

async function activeEmergencyDevices() {
  const snapshot = await db.collection("device_tokens")
    .where("active", "==", true)
    .limit(10000)
    .get();
  return snapshot.docs
    .map((document) => ({ id: document.id, ...document.data() }))
    .filter((device) => typeof device.token === "string" && device.token.length > 20);
}

function emergencyPushMessage(alert, emergencyId, tokens, reminder = false) {
  const severity = canonicalSeverity(alert.severity);
  const isEmergency = severity === "emergency";
  const title = String(alert.title || "E-SUGID emergency alert").slice(0, 120);
  const bodyPrefix = reminder ? "REMINDER: " : "";
  const body = `${bodyPrefix}${String(alert.message || "Follow official emergency instructions immediately.")}`.slice(0, 500);
  const data = {
    notificationType: isEmergency ? "emergency" : "community_alert",
    type: isEmergency ? "emergency_alert" : "community_alert",
    emergencyId,
    alertId: emergencyId,
    route: "/emergency",
    priority: isEmergency ? "emergency" : severity,
    severity,
    alertType: String(alert.alertType || "Emergency").slice(0, 80),
    affectedArea: alert.visibility === "public"
      ? "All residents"
      : String((alert.targetBarangays || []).join(", ")).slice(0, 240),
    title,
    body,
    reminder: String(reminder),
  };
  const message = {
    tokens,
    data,
    android: {
      priority: isEmergency ? "high" : "normal",
      ttl: isEmergency ? 300000 : 3600000,
      collapseKey: reminder ? `emergency_reminder_${emergencyId}` : `emergency_${emergencyId}`,
    },
  };
  if (!isEmergency) {
    message.notification = { title, body };
    message.android.notification = {
      channelId: severity === "warning"
        ? "esugid_announcement_important_v2"
        : "esugid_announcement_regular_v2",
      sound: "default",
      visibility: "public",
      defaultVibrateTimings: severity !== "information",
    };
  }
  return message;
}

async function sendEmergencyToDevices(alert, emergencyId, deviceRecords, reminder = false) {
  const successfulResidents = new Set();
  const invalidDeviceIds = [];
  let successfulTokens = 0;
  let failedTokens = 0;
  for (let offset = 0; offset < deviceRecords.length; offset += 500) {
    const records = deviceRecords.slice(offset, offset + 500);
    console.info("[EMERGENCY PUSH] FCM send attempted", {
      emergencyId,
      tokenCount: records.length,
      reminder,
    });
    const response = await getMessaging().sendEachForMulticast(
      emergencyPushMessage(alert, emergencyId, records.map((record) => record.token), reminder),
    );
    successfulTokens += response.successCount;
    failedTokens += response.failureCount;
    response.responses.forEach((item, index) => {
      const record = records[index];
      if (item.success) {
        successfulResidents.add(record.userId);
        return;
      }
      const code = String(item.error?.code || "");
      if ([
        "messaging/invalid-registration-token",
        "messaging/registration-token-not-registered",
      ].includes(code)) invalidDeviceIds.push(record.id);
      console.warn("[EMERGENCY PUSH] FCM token rejected", {
        emergencyId,
        code,
      });
    });
  }
  for (let offset = 0; offset < invalidDeviceIds.length; offset += 400) {
    const batch = db.batch();
    invalidDeviceIds.slice(offset, offset + 400).forEach((id) =>
      batch.delete(db.collection("device_tokens").doc(id)));
    await batch.commit();
  }
  console.info("[EMERGENCY PUSH] FCM result", {
    emergencyId,
    success: successfulTokens,
    failure: failedTokens,
    staleTokensRemoved: invalidDeviceIds.length,
    reminder,
  });
  return {
    successfulResidents,
    successfulTokens,
    failedTokens,
    invalidTokens: invalidDeviceIds.length,
  };
}

async function createResidentEmergencyRecords(alert, emergencyId, residents) {
  for (let offset = 0; offset < residents.length; offset += 200) {
    const batch = db.batch();
    residents.slice(offset, offset + 200).forEach((resident) => {
      batch.set(
        db.collection("resident_emergency_statuses")
          .doc(emergencyStatusId(emergencyId, resident.id)),
        {
          emergencyId,
          residentId: resident.id,
          status: "pending",
          reminderCount: 0,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      batch.set(
        db.collection("notifications")
          .doc(emergencyNotificationId(emergencyId, resident.id)),
        {
          userId: resident.id,
          type: "emergency_alert",
          referenceId: emergencyId,
          title: String(alert.title || "Emergency alert").slice(0, 120),
          message: String(alert.message || "Follow official instructions.").slice(0, 500),
          severity: canonicalSeverity(alert.severity),
          emergencyStatus: "active",
          acknowledged: false,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    await batch.commit();
  }
}

exports.deliverEmergencyAlertNotification = onDocumentWritten(
  { document: "alerts/{alertId}", region: REGION },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after || after.notificationRequested !== true || after.active === false) return;
    // Ignore writes made by this delivery function. A new alert, or an explicit
    // false-to-true notification request, is the only event that starts delivery.
    if (before?.notificationRequested === true) return;

    const alertRef = event.data.after.ref;
    const claimed = await db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(alertRef);
      const current = currentSnapshot.data() || {};
      if (["sending", "sent"].includes(current.notificationState)) return false;
      transaction.update(alertRef, {
        notificationState: "sending",
        notificationClaimedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!claimed) return;

    try {
      const residents = await targetedResidentsFor(after);
      await createResidentEmergencyRecords(after, event.params.alertId, residents);
      const residentIds = new Set(residents.map((resident) => resident.id));
      const devices = (await activeEmergencyDevices())
        .filter((device) => residentIds.has(device.userId));
      console.info("[EMERGENCY PUSH] Emergency published", {
        emergencyId: event.params.alertId,
      });
      console.info("[EMERGENCY PUSH] Audience resolved", {
        emergencyId: event.params.alertId,
        targetResidents: residents.length,
        validDeviceTokens: devices.length,
      });
      const delivery = await sendEmergencyToDevices(
        after,
        event.params.alertId,
        devices,
      );
      const deliveredResidents = delivery.successfulResidents;
      for (let offset = 0; offset < deliveredResidents.size; offset += 400) {
        const batch = db.batch();
        [...deliveredResidents].slice(offset, offset + 400).forEach((residentId) => {
          batch.set(
            db.collection("resident_emergency_statuses")
              .doc(emergencyStatusId(event.params.alertId, residentId)),
            {
              deliveredAt: FieldValue.serverTimestamp(),
              status: "delivered",
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        });
        await batch.commit();
      }
      const notificationState = devices.length === 0
        ? "no_devices"
        : delivery.successfulTokens > 0
          ? "sent"
          : "failed";
      const notificationFailure = devices.length === 0
        ? "No active resident FCM device tokens were registered for this audience."
        : delivery.successfulTokens === 0
          ? "Firebase Cloud Messaging rejected every targeted device token."
          : null;
      await alertRef.update({
        notificationState,
        notificationSentAt: FieldValue.serverTimestamp(),
        stats: {
          targeted: residents.length,
          delivered: deliveredResidents.size,
          deviceTokens: devices.length,
          fcmAccepted: delivery.successfulTokens,
          fcmFailed: delivery.failedTokens,
          opened: 0,
          acknowledged: 0,
        },
        notificationFailure: notificationFailure || FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      console.info("[EMERGENCY PUSH] Delivery processing completed", {
        emergencyId: event.params.alertId,
        deliveredResidents: deliveredResidents.size,
        fcmAccepted: delivery.successfulTokens,
        fcmFailed: delivery.failedTokens,
      });
    } catch (error) {
      await alertRef.update({
        notificationState: "failed",
        notificationFailure: String(error.message || error).slice(0, 500),
        updatedAt: FieldValue.serverTimestamp(),
      });
      throw error;
    }
  },
);

exports.sendEmergencyReminders = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Manila", region: REGION },
  async () => {
    const intervalMinutes = Math.max(
      1,
      Number(EMERGENCY_REMINDER_INTERVAL_MINUTES.value() || 15),
    );
    const configuredMaxReminders = Number(EMERGENCY_MAX_REMINDERS.value() || 0);
    const maxReminders = Number.isFinite(configuredMaxReminders)
      ? Math.max(0, configuredMaxReminders)
      : 0;
    const nowMs = Date.now();
    const cycle = reminderCycle(nowMs, intervalMinutes);
    const alertsSnapshot = await db.collection("alerts")
      .where("active", "==", true)
      .limit(200)
      .get();
    const alerts = alertsSnapshot.docs
      .map((document) => ({ id: document.id, ref: document.ref, ...document.data() }))
      .filter((alert) => canonicalSeverity(alert.severity) === "emergency"
        && isActiveEmergency(alert, nowMs));
    if (!alerts.length) return;
    const devices = await activeEmergencyDevices();

    for (const alert of alerts) {
      const statusSnapshot = await db.collection("resident_emergency_statuses")
        .where("emergencyId", "==", alert.id)
        .limit(5000)
        .get();
      for (const statusDocument of statusSnapshot.docs) {
        if (!isReminderEligible(alert, statusDocument.data(), nowMs, intervalMinutes, maxReminders)) {
          continue;
        }
        const residentId = statusDocument.data().residentId;
        const residentDevices = devices.filter((device) => device.userId === residentId);
        if (!residentDevices.length) continue;
        const claimed = await db.runTransaction(async (transaction) => {
          const [latestAlert, latestStatus] = await Promise.all([
            transaction.get(alert.ref),
            transaction.get(statusDocument.ref),
          ]);
          const alertData = latestAlert.data();
          const statusData = latestStatus.data();
          if (!alertData || !statusData
            || !isReminderEligible(alertData, statusData, nowMs, intervalMinutes, maxReminders)) {
            return false;
          }
          transaction.update(statusDocument.ref, {
            lastReminderCycle: cycle,
            lastReminderSentAt: FieldValue.serverTimestamp(),
            reminderCount: FieldValue.increment(1),
            updatedAt: FieldValue.serverTimestamp(),
          });
          return true;
        });
        if (!claimed) continue;
        const delivery = await sendEmergencyToDevices(
          alert,
          alert.id,
          residentDevices,
          true,
        );
        if (delivery.successfulTokens > 0) {
          await db.collection("notifications")
            .doc(emergencyNotificationId(alert.id, residentId))
            .set({
              lastReminderSentAt: FieldValue.serverTimestamp(),
              reminderCount: FieldValue.increment(1),
            }, { merge: true });
        }
        console.info("[EMERGENCY PUSH] Reminder processing completed", {
          emergencyId: alert.id,
          cycle,
          deviceTokens: residentDevices.length,
          fcmAccepted: delivery.successfulTokens,
          fcmFailed: delivery.failedTokens,
        });
      }
    }
  },
);

exports.stopTerminatedEmergency = onDocumentUpdated(
  { document: "alerts/{alertId}", region: REGION },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const status = String(after.status || "").toLowerCase();
    if (["ended", "cancelled", "expired"].includes(String(before.status || "").toLowerCase())
      || !["ended", "cancelled", "expired"].includes(status)) return;
    const emergencyId = event.params.alertId;
    const statuses = await db.collection("resident_emergency_statuses")
      .where("emergencyId", "==", emergencyId)
      .limit(5000)
      .get();
    const residentIds = new Set(statuses.docs.map((document) => document.data().residentId));
    const devices = (await activeEmergencyDevices())
      .filter((device) => residentIds.has(device.userId));
    for (let offset = 0; offset < devices.length; offset += 500) {
      await getMessaging().sendEachForMulticast({
        tokens: devices.slice(offset, offset + 500).map((device) => device.token),
        data: {
          notificationType: "emergency_stop",
          type: "emergency_stop",
          emergencyId,
          alertId: emergencyId,
          status,
        },
        android: { priority: "high", ttl: 300000 },
      });
    }
    for (let offset = 0; offset < statuses.docs.length; offset += 200) {
      const batch = db.batch();
      statuses.docs.slice(offset, offset + 200).forEach((document) => {
        const residentId = document.data().residentId;
        if (document.data().status !== "acknowledged") {
          batch.set(document.ref, { status, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        }
        batch.set(
          db.collection("notifications").doc(emergencyNotificationId(emergencyId, residentId)),
          { emergencyStatus: status, updatedAt: FieldValue.serverTimestamp() },
          { merge: true },
        );
      });
      await batch.commit();
    }
    console.info("[EMERGENCY] Reminders cancelled", { emergencyId, status });
  },
);

async function concernRecipientDirectory({ includeInactive = false } = {}) {
  const snapshot = await db.collection("concern_recipients").limit(500).get();
  const configured = snapshot.docs.map((document) => ({ id: document.id, ...document.data() }));
  const accountIds = [...new Set(configured
    .map((item) => String(item.receiverAccountId || item.inboxId || "").trim())
    .filter(Boolean))];
  const accountSnapshots = await Promise.all(accountIds.map((id) => db.collection("users").doc(id).get()));
  const accounts = new Map(accountSnapshots
    .filter((item) => item.exists)
    .map((item) => [item.id, item.data()]));
  const enriched = configured.map((recipient) => {
    const accountId = String(recipient.receiverAccountId || recipient.inboxId || "").trim();
    const account = accounts.get(accountId);
    const type = canonicalRecipientType(recipient.recipientType);
    const role = canonicalRole(account?.role);
    const roleMatches = (type === "municipalOffice" && isMunicipalRole(role))
      || (type === "partnerOrganization" && role === "organization")
      || (type === "barangay" && BARANGAY_ROLES.has(role));
    return {
      ...recipient,
      departmentId: type === "municipalOffice"
        ? effectiveDepartmentId(account) || departmentKey(recipient.departmentId)
        : "",
      _receiverValid: Boolean(account && isActiveProfile(account) && roleMatches),
    };
  });
  if (includeInactive) return enriched;
  return enriched.filter((recipient) => recipient._receiverValid
    && isConfiguredRecipientAvailable(recipient));
}

function publicConcernRecipient(recipient, includeProtected = false) {
  return {
    recipientId: recipient.id,
    displayName: String(recipient.displayName || "Receiving office"),
    recipientType: canonicalRecipientType(recipient.recipientType),
    categoriesHandled: Array.isArray(recipient.categoriesHandled)
      ? recipient.categoriesHandled.map((item) => String(item)).slice(0, 50)
      : [],
    status: String(recipient.status || "inactive"),
    canReceiveConcerns: recipient.canReceiveConcerns === true,
    fallbackRecipientId: String(recipient.fallbackRecipientId || ""),
    ...(includeProtected ? {
      receiverAccountId: String(recipient.receiverAccountId || recipient.inboxId || ""),
      receiverValid: recipient._receiverValid === true,
    } : {}),
  };
}

exports.listConcernRecipients = onCall({ region: REGION }, async (request) => {
  const actor = await activeUserCaller(request);
  const actorRole = canonicalRole(actor.role);
  const includeInactive = request.data?.includeInactive === true
    && actorRole === "super_admin";
  let recipients = await concernRecipientDirectory({
    includeInactive: includeInactive || actorRole === "resident",
  });
  if (actorRole === "resident") {
    recipients = [];
    const barangayRecipient = await barangayConcernReceiver(actor);
    if (barangayRecipient) {
      recipients.push({
        id: barangayRecipient.recipientId,
        displayName: barangayRecipient.displayName,
        recipientType: "barangay",
        status: "active",
        canReceiveConcerns: true,
        receiverAccountId: barangayRecipient.receiverAccountId,
        categoriesHandled: [],
      });
    }
  }
  return {
    recipients: recipients
      .map((recipient) => publicConcernRecipient(recipient, includeInactive))
      .sort((a, b) => a.displayName.localeCompare(b.displayName)),
  };
});

async function barangayConcernReceiver(profile) {
  const barangay = canonicalBarangayName(profile.barangay);
  const barangayId = String(profile.barangayId || barangayIdFor(barangay) || "")
    .trim().toLowerCase();
  if (!barangay || !barangayId) return null;
  const profiles = await profilesForBarangay(barangayId, barangay);
  const receiver = profiles.find((item) => BARANGAY_ROLES.has(canonicalRole(item.role))
    && isActiveProfile(item)
    && item.canReceiveConcerns !== false);
  if (!receiver) return null;
  return {
    recipientId: `barangay-${barangayId}`,
    recipientType: "barangay",
    displayName: `Barangay ${barangay}`,
    receiverAccountId: receiver.id,
    barangay,
    barangayId,
  };
}



function validConcernReference(value) {
  const concernReference = String(value || "").trim();
  if (!/^CON-\d{4}-\d{6}$/.test(concernReference) && !/^[A-Za-z0-9_-]{6,64}$/.test(concernReference)) {
    throw new HttpsError("invalid-argument", "A valid concern reference is required.");
  }
  return concernReference;
}

function selectedConcernBarangay(input) {
  const barangay = canonicalBarangayName(input.barangay);
  const barangayId = barangayIdFor(barangay);
  if (!barangayId || barangayId !== String(input.barangayId || "").trim()) {
    throw new HttpsError("invalid-argument", "Select a valid Barili barangay for this concern.");
  }
  return { barangay, barangayId };
}

function registeredConcernBarangayId(resident) {
  return String(resident.verifiedBarangayId || effectiveBarangayId(resident)).trim();
}

async function matchingConcernOrganizations(categoryId, sector) {
  const legacyIds = Object.keys(LEGACY_CATEGORY_IDS)
    .filter((id) => LEGACY_CATEGORY_IDS[id] === categoryId);
  const categoryIds = [categoryId, ...legacyIds];
  const snapshot = await db.collection("organizations")
    .where("categoryId", "in", categoryIds).get();
  const approved = await Promise.all(snapshot.docs.map(async (document) => {
    if (!["verified", "active"].includes(String(document.data().status || "").toLowerCase())) return null;
    if ((document.data().organizationSector || "public") !== sector) return null;
    const members = await db.collection("users")
      .where("organizationId", "==", document.id).get();
    return members.docs.some((member) => isActiveProfile(member.data())
      && member.data().setupRequired !== true
      && ["organization", "partner_organization"].includes(canonicalRole(member.data().role)))
      ? document : null;
  }));
  return approved.filter(Boolean);
}

function selectedConcernSector(input, category) {
  // Previously released mobile clients have no sector selector. They may
  // continue their public-organization flow until the new app is installed.
  const sector = String(input.organizationSector || "").trim()
    || (category?.sector === "public" ? "public" : "");
  if (category?.sector !== sector) {
    throw new HttpsError("invalid-argument", "Select a category from the chosen organization sector.");
  }
  return sector;
}

exports.listConcernOrganizations = onCall({ region: REGION }, async (request) => {
  const resident = await activeUserCaller(request);
  if (canonicalRole(resident.role) !== "resident" || verificationStatusForProfile(resident) !== "verified") {
    throw new HttpsError("permission-denied", "Verified residency is required.");
  }
  const categoryId = canonicalConcernCategoryId(String(request.data?.categoryId || "").trim());
  const sector = selectedConcernSector(request.data || {}, concernCategory(categoryId));
  const organizations = await matchingConcernOrganizations(categoryId, sector);
  return {
    organizations: organizations.map((document) => ({
      id: document.id, name: document.data().name || document.id,
    })).sort((a, b) => a.name.localeCompare(b.name))
  };
});

exports.findSimilarPublicConcerns = onCall({ region: REGION }, async (request) => {
  const resident = await activeUserCaller(request);
  if (canonicalRole(resident.role) !== "resident" || verificationStatusForProfile(resident) !== "verified") {
    throw new HttpsError("permission-denied", "Verified residency is required.");
  }
  const input = request.data || {};
  const categoryId = canonicalConcernCategoryId(String(input.categoryId || "").trim());
  selectedConcernSector(input, concernCategory(categoryId));
  const { barangayId } = selectedConcernBarangay(input);
  if (registeredConcernBarangayId(resident) !== barangayId) return { matches: [] };
  const proposed = {
    categoryId, barangayId,
    incidentDate: optionalText(input.incidentDate, 80),
    location: requiredText(input.location, "Location", 200)
  };
  const snapshot = await db.collection("submissions")
    .where("barangayId", "==", barangayId)
    .where("visibility", "==", "public")
    .limit(250).get();
  const matches = snapshot.docs
    .filter((document) => similarPublicConcern(proposed, document.data()))
    .sort((left, right) => timestampMillis(right.data().date) - timestampMillis(left.data().date))
    .slice(0, 5)
    .map((document) => ({
      id: document.id,
      title: document.data().title,
      category: document.data().category,
      date: concernDateKey(document.data().incidentDate, document.data().date || document.data().submittedAt),
      dateLabel: document.data().incidentDate ? "Incident date" : "Reported date",
      description: document.data().description,
      location: document.data().location,
      department: document.data().department,
      status: document.data().status,
      reporterCount: document.data().reporterCount || 1,
    }));
  return { matches };
});

// Residents read this projection rather than the full submission, which holds
// reporter identifiers, evidence paths, and the individual reports.
exports.syncPublicConcernSummary = onDocumentWritten(
  { document: "submissions/{submissionId}", region: REGION },
  async (event) => {
    const previous = event.data.before.exists ? event.data.before.data() : null;
    const concern = event.data.after.exists ? event.data.after.data() : null;
    if (Number(previous?.schemaVersion || 0) < 4 && Number(concern?.schemaVersion || 0) < 4) return;
    const summaryRef = db.collection("public_concern_summaries").doc(event.params.submissionId);
    // Events can arrive out of order. An older update must not recreate the
    // public summary of a concern an administrator has since deleted.
    await db.runTransaction(async transaction => {
      const latest = await transaction.get(db.collection("submissions").doc(event.params.submissionId));
      if (!latest.exists) {
        transaction.delete(summaryRef);
        return;
      }
      const data = latest.data();
      let origName = data.originalReporterName || data.reporterName || data.submitterName;
      let origPhotoUrl = data.originalReporterPhotoUrl || data.reporterPhotoUrl || data.profilePhotoUrl || data.photoUrl || "";
      const creatorId = data.userId || data.createdBy || data.residentId;
      if (creatorId && ((!origName || origName === "Resident") || !origPhotoUrl)) {
        const uDoc = await transaction.get(db.collection("users").doc(creatorId));
        if (uDoc.exists) {
          const uData = uDoc.data();
          if (!origName || origName === "Resident") {
            origName = uData.name || uData.displayName || uData.fullName || origName;
          }
          if (!origPhotoUrl) {
            origPhotoUrl = uData.profilePhotoUrl || uData.photoUrl || uData.avatarUrl || "";
          }
        }
      }
      origName = (origName || "Resident").trim();
      const summary = publicConcernSummary(event.params.submissionId, {
        ...data,
        originalReporterName: origName,
        reporterName: origName,
        originalReporterPhotoUrl: origPhotoUrl,
        reporterPhotoUrl: origPhotoUrl,
      });
      if (summary) transaction.set(summaryRef, summary);
      else transaction.delete(summaryRef);
    });
  },
);

exports.getPublicConcernReporters = onCall({ region: REGION }, async (request) => {
  const resident = await activeUserCaller(request);
  if (!resident) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const input = request.data || {};
  const concernId = String(input.concernId || "").trim();
  const concernIds = Array.isArray(input.concernIds)
    ? input.concernIds.map(String).map(s => s.trim()).filter(Boolean)
    : [];

  async function resolveConcernReporters(id) {
    if (!id) return null;
    const subRef = db.collection("submissions").doc(id);
    const subSnap = await subRef.get();
    if (!subSnap.exists) {
      const pubSnap = await db.collection("public_concern_summaries").doc(id).get();
      if (!pubSnap.exists) return null;
      const pubData = pubSnap.data();
      let origName = pubData.originalReporterName || pubData.reporterName || "Resident";
      let origPhotoUrl = pubData.originalReporterPhotoUrl || pubData.reporterPhotoUrl || "";
      const origId = pubData.userId || pubData.residentId || pubData.createdBy || "";
      if (origId && ((!origName || origName === "Resident") || !origPhotoUrl)) {
        const uSnap = await db.collection("users").doc(origId).get();
        if (uSnap.exists) {
          const uData = uSnap.data();
          if (!origName || origName === "Resident") {
            origName = uData.name || uData.displayName || uData.fullName || origName;
          }
          if (!origPhotoUrl) {
            origPhotoUrl = uData.profilePhotoUrl || uData.photoUrl || uData.avatarUrl || "";
          }
        }
      }
      const rawReporters = Array.isArray(pubData.reporters) ? pubData.reporters : [];
      const joined = rawReporters.filter(r => !r.isOriginal).map(r => ({
        id: r.id || "",
        name: r.name || r.reporterName || "Resident",
        photoUrl: r.photoUrl || r.profilePhotoUrl || "",
        isOriginal: false,
      }));
      return {
        concernId: id,
        originalReporter: {
          id: origId,
          name: origName,
          photoUrl: origPhotoUrl,
          isOriginal: true,
        },
        reporters: joined,
        reporterNames: pubData.reporterNames || [origName],
        count: pubData.reporterCount || (1 + joined.length),
      };
    }

    const data = subSnap.data();
    if (data.visibility !== "public") {
      throw new HttpsError("permission-denied", "This concern is not public.");
    }

    let origName = data.originalReporterName || data.reporterName || data.submitterName;
    let origPhotoUrl = data.originalReporterPhotoUrl || data.reporterPhotoUrl || data.profilePhotoUrl || data.photoUrl || "";
    const origId = data.userId || data.residentId || data.createdBy || "";
    if (origId && ((!origName || origName === "Resident") || !origPhotoUrl)) {
      const userSnap = await db.collection("users").doc(origId).get();
      if (userSnap.exists) {
        const uData = userSnap.data();
        if (!origName || origName === "Resident") {
          origName = uData.name || uData.displayName || uData.fullName || origName;
        }
        if (!origPhotoUrl) {
          origPhotoUrl = uData.profilePhotoUrl || uData.photoUrl || uData.avatarUrl || "";
        }
      }
    }
    origName = (origName || "Resident").trim();

    const reportsSnap = await subRef.collection("reports").get();
    const joined = [];
    for (const rDoc of reportsSnap.docs) {
      const rData = rDoc.data();
      let rName = rData.reporterName;
      let rPhotoUrl = rData.reporterPhotoUrl || rData.profilePhotoUrl || rData.photoUrl || "";
      const rId = rData.reporterId || rDoc.id;
      if (rId && ((!rName || rName === "Resident") || !rPhotoUrl)) {
        const uSnap = await db.collection("users").doc(rId).get();
        if (uSnap.exists) {
          const uData = uSnap.data();
          if (!rName || rName === "Resident") {
            rName = uData.name || uData.displayName || uData.fullName || rName;
          }
          if (!rPhotoUrl) {
            rPhotoUrl = uData.profilePhotoUrl || uData.photoUrl || uData.avatarUrl || "";
          }
        }
      }
      rName = (rName || "Resident").trim();
      joined.push({
        id: rId,
        name: rName,
        photoUrl: rPhotoUrl,
        isOriginal: false,
      });
    }

    const seenIds = new Set();
    const seenNames = new Set();
    if (origId) seenIds.add(origId);
    if (origName && origName.toLowerCase() !== "resident") seenNames.add(origName.toLowerCase());

    const dedupedJoined = [];
    for (const j of joined) {
      if (j.id && seenIds.has(j.id)) continue;
      if (j.name && j.name.toLowerCase() !== "resident" && seenNames.has(j.name.toLowerCase())) continue;
      if (j.id) seenIds.add(j.id);
      if (j.name && j.name.toLowerCase() !== "resident") seenNames.add(j.name.toLowerCase());
      dedupedJoined.push(j);
    }

    const allReporters = [
      { id: origId, name: origName, photoUrl: origPhotoUrl, isOriginal: true },
      ...dedupedJoined,
    ];
    const reporterNames = allReporters.map(r => r.name);
    const count = allReporters.length;

    // Self-healing: update public_concern_summaries in Firestore
    const summaryRef = db.collection("public_concern_summaries").doc(id);
    await summaryRef.set({
      originalReporterName: origName,
      reporterName: origName,
      originalReporterPhotoUrl: origPhotoUrl,
      reporterPhotoUrl: origPhotoUrl,
      reporters: allReporters,
      reporterNames,
      reporterCount: count,
    }, { merge: true }).catch(() => {});

    return {
      concernId: id,
      originalReporter: { id: origId, name: origName, photoUrl: origPhotoUrl, isOriginal: true },
      reporters: dedupedJoined,
      reporterNames,
      count,
    };
  }

  if (concernIds.length > 0) {
    const results = {};
    for (const id of concernIds.slice(0, 30)) {
      try {
        const res = await resolveConcernReporters(id);
        if (res) results[id] = res;
      } catch (_) {}
    }
    return { results };
  }

  if (concernId) {
    const res = await resolveConcernReporters(concernId);
    if (!res) throw new HttpsError("not-found", "Concern not found.");
    return res;
  }

  throw new HttpsError("invalid-argument", "Provide concernId or concernIds.");
});

exports.submitConcern = onCall({ region: REGION }, async (request) => {
  const resident = await activeUserCaller(request);
  if (isResidentRestricted(resident)) {
    throw new HttpsError("permission-denied", "Account Restricted. Please contact your barangay office for assistance.");
  }
  if (canonicalRole(resident.role) !== "resident"
    || verificationStatusForProfile(resident) !== "verified") {
    throw new HttpsError("permission-denied", "Verified residency is required to submit a concern.");
  }
  const input = request.data || {};
  const id = validConcernReference(input.id);
  const draftId = requiredText(input.draftId, "Draft ID", 160);
  const reference = db.collection("submissions").doc(id);
  const existing = await reference.get();
  if (existing.exists) {
    const data = existing.data();
    if (data.userId === resident.id && data.draftId === draftId) {
      return {
        id,
        department: data.department,
        recipientId: data.recipientId,
        recipientType: data.recipientType,
        routingStatus: data.routingStatus,
      };
    }
    throw new HttpsError("already-exists", "This concern reference is already in use.");
  }

  const title = requiredText(input.title, "Concern title", 100);
  const description = requiredText(input.description, "Description", 1000);
  if (description.length < 10) {
    throw new HttpsError("invalid-argument", "Description is too short.");
  }
  const categoryId = canonicalConcernCategoryId(String(input.categoryId || "").trim());
  const selectedCategory = concernCategory(categoryId);
  if (!selectedCategory) throw new HttpsError("invalid-argument", "Select a valid concern category.");
  const organizationSector = selectedConcernSector(input, selectedCategory);
  const category = selectedCategory.name;
  const visibility = String(input.visibility || "").trim();
  if (!["public", "private"].includes(visibility)) {
    throw new HttpsError("invalid-argument", "Choose Public or Private for this concern.");
  }
  const concernType = requiredText(input.concernType, "Concern type", 100);
  const location = requiredText(input.location, "Location", 200);
  const { barangay, barangayId } = selectedConcernBarangay(input);
  const recipientType = String(input.recipientType || "organization").trim();
  if (!["organization", "barangay"].includes(recipientType)) {
    throw new HttpsError("invalid-argument", "Select a valid concern recipient.");
  }
  if (recipientType === "barangay" && organizationSector !== "public") {
    throw new HttpsError("invalid-argument", "Select a public concern category for Barangay.");
  }
  let selectedOrganizationId = "";
  let organizationIds = [];
  let organizationNames = [];
  if (recipientType === "organization") {
    const organizations = await matchingConcernOrganizations(categoryId, organizationSector);
    if (!organizations.length) {
      throw new HttpsError("failed-precondition", "No active organization is assigned to this category yet. Please try again after an Admin assigns one.");
    }
    selectedOrganizationId = requiredText(input.organizationId, "Organization", 160);
    const selectedOrganization = organizations.find((document) => document.id === selectedOrganizationId);
    if (!selectedOrganization) {
      throw new HttpsError("invalid-argument", "Select an approved organization for this category.");
    }
    organizationIds = [selectedOrganization.id];
    organizationNames = [selectedOrganization.data().name || selectedOrganization.id];
  }
  const now = Timestamp.now();
  const attachmentStoragePath = optionalText(input.attachmentStoragePath, 500);
  const joinConcernId = String(input.joinConcernId || "").trim();
  if (attachmentStoragePath
    && !attachmentStoragePath.startsWith(`concerns/${resident.id}/${joinConcernId || id}/`)) {
    throw new HttpsError("invalid-argument", "The evidence path is invalid.");
  }
  if (joinConcernId) {
    if (visibility !== "public") throw new HttpsError("invalid-argument", "Private reports cannot join a public concern.");
    if (registeredConcernBarangayId(resident) !== barangayId) {
      throw new HttpsError("permission-denied", "You can only join public concerns in your registered barangay.");
    }
    const parentRef = db.collection("submissions").doc(validConcernReference(joinConcernId));
    const reportRef = parentRef.collection("reports").doc(resident.id);
    const result = await db.runTransaction(async (transaction) => {
      const [parentSnapshot, reportSnapshot] = await Promise.all([
        transaction.get(parentRef), transaction.get(reportRef),
      ]);
      if (!parentSnapshot.exists || !similarPublicConcern(
        { categoryId, barangayId, incidentDate: optionalText(input.incidentDate, 80), location },
        parentSnapshot.data(), now.toMillis(),
      )) {
        throw new HttpsError("failed-precondition", "This concern is no longer an available similar report. Submit it as a new concern.");
      }
      if (reportSnapshot.exists) return {
        id: parentRef.id, joined: true,
        department: parentSnapshot.data().department,
        recipientType: parentSnapshot.data().recipientType,
        recipientId: parentSnapshot.data().recipientId
      };
      const parent = parentSnapshot.data();
      const event = {
        status: parent.status,
        action: "resident_joined",
        note: "Another resident reported this concern.",
        date: now,
        performedBy: "resident",
        actorId: "resident",
        actorType: "resident",
        visibility: "public",
      };
      transaction.create(reportRef, {
        reporterId: resident.id,
        reporterName: String(resident.name || resident.displayName || "Resident").slice(0, 100),
        reporterPhotoUrl: String(resident.profilePhotoUrl || resident.photoUrl || resident.avatarUrl || request.auth.token.picture || "").trim(),
        title, description, location,
        incidentDate: optionalText(input.incidentDate, 80),
        attachmentUrl: optionalText(input.attachmentUrl, 2048),
        attachmentStoragePath,
        submittedAt: now,
        draftId,
      });
      transaction.update(parentRef, {
        reporterIds: FieldValue.arrayUnion(resident.id),
        reporterCount: (parent.reporterCount || 1) + 1,
        latestReportAt: now,
        updatedAt: now,
        statusHistory: FieldValue.arrayUnion(event),
      });
      transaction.create(db.collection("audit_logs").doc(), {
        action: "concern_report_joined", targetType: "submission", targetId: parentRef.id,
        actorId: resident.id, barangayId, createdAt: now,
      });
      const joinedNotifRef = db.collection("notifications").doc(`concern_submitted_${parentRef.id}_${resident.id}`);
      transaction.set(joinedNotifRef, {
        userId: resident.id,
        type: "concern_submitted",
        referenceId: parentRef.id,
        relatedEntityType: "submission",
        title: "Concern report joined",
        message: `Your report for concern ${parentRef.id} has been submitted.`,
        navigation: { route: "/complain" },
        read: false,
        createdAt: now,
      });
      return {
        id: parentRef.id, joined: true,
        department: parent.department, recipientType: parent.recipientType,
        recipientId: parent.recipientId
      };
    });
    try {
      await sendNormalPushToUsers([resident.id], {
        title: "Concern report joined",
        body: `Your report for concern ${result.id} has been received.`,
        type: "concern_submitted",
        referenceId: result.id,
      });
    } catch (_) { }
    return result;
  }
  const barangayRoute = recipientType === "barangay"
    ? await barangayConcernReceiver({ barangay, barangayId }) : null;
  if (recipientType === "barangay" && !barangayRoute) {
    throw new HttpsError("failed-precondition", "No active Barangay official can receive this concern yet.");
  }
  const reporterName = String(resident.name || resident.displayName || request.auth.token.name || "Resident").slice(0, 100);
  const reporterPhotoUrl = String(resident.profilePhotoUrl || resident.photoUrl || resident.avatarUrl || request.auth.token.picture || "").trim();
  const submission = {
    schemaVersion: 4,
    id,
    title,
    description,
    category,
    categoryId,
    organizationSector,
    visibility,
    kind: "concern",
    type: concernType,
    customConcernType: optionalText(input.customConcernType, 100),
    status: "new",
    date: now,
    submittedAt: FieldValue.serverTimestamp(),
    updatedAt: now,
    userId: resident.id,
    residentId: resident.id,
    createdBy: resident.id,
    residentName: reporterName,
    reporterName,
    submitterName: reporterName,
    originalReporterName: reporterName,
    originalReporterPhotoUrl: reporterPhotoUrl,
    reporterPhotoUrl,
    reporterIds: [resident.id],
    reporterCount: 1,
    latestReportAt: now,
    barangay,
    barangayId,
    location,
    incidentDate: optionalText(input.incidentDate, 80),
    requestedAction: optionalText(input.requestedAction, 300),
    anonymous: false,
    draftId,
    attachmentUrl: optionalText(input.attachmentUrl, 2048),
    attachmentStoragePath,
    requestedRecipientType: recipientType === "barangay" ? "barangay" : "automatic",
    requestedRecipientId: recipientType === "barangay" ? barangayRoute.recipientId : "",
    recipientId: recipientType === "barangay" ? barangayRoute.recipientId : organizationIds[0],
    recipientType,
    receiverAccountId: recipientType === "barangay" ? barangayRoute.receiverAccountId : "",
    organizationId: selectedOrganizationId,
    organizationIds,
    organizationNames,
    leadOrganizationId: "",
    department: recipientType === "barangay" ? barangayRoute.displayName : organizationNames[0],
    recipientBarangayId: recipientType === "barangay" || visibility === "public" ? barangayId : "",
    routingStatus: "automatically_routed",
    routingReason: "",
    possibleDuplicate: false,
    possibleDuplicateIds: [],
    routingHistory: [
      ...organizationIds.map((organizationId, index) => ({
        action: "routed_to_organization", recipientId: organizationId,
        recipientName: organizationNames[index], actorId: "system", date: now,
      })),
      ...(barangayRoute ? [{
        action: "routed_to_barangay", recipientId: barangayRoute.recipientId,
        recipientName: barangayRoute.displayName, actorId: "system", date: now
      }] : []),
    ],
    statusHistory: [{
      status: "new",
      action: "submitted",
      note: recipientType === "barangay"
        ? "Concern submitted and routed to the selected barangay."
        : "Concern submitted and routed to the selected organization.",
      date: now,
      performedBy: visibility === "public" ? "resident" : resident.id,
      performedAt: now,
      actorId: visibility === "public" ? "resident" : resident.id,
      actorType: "resident",
      visibility: visibility === "private" ? "reporter_and_handlers" : "public",
    }],
    residentResponses: [],
  };
  const auditRef = db.collection("audit_logs").doc();
  const batch = db.batch();
  batch.create(reference, submission);
  batch.create(reference.collection("reports").doc(resident.id), {
    reporterId: resident.id,
    reporterName,
    title, description, location,
    attachmentUrl: submission.attachmentUrl,
    attachmentStoragePath,
    submittedAt: now,
    draftId,
  });
  batch.set(auditRef, {
    action: "concern_submitted",
    targetType: "submission",
    targetId: id,
    actorId: resident.id,
    actorEmail: resident.email || "",
    barangayId,
    recipientId: submission.recipientId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {
    id,
    department: submission.department,
    barangay,
    barangayId,
    recipientId: submission.recipientId,
    recipientType: submission.recipientType,
    routingStatus: submission.routingStatus,
  };
});

exports.resubmitConcern = onCall({ region: REGION }, async (request) => {
  const resident = await activeUserCaller(request);
  if (isResidentRestricted(resident)) {
    throw new HttpsError("permission-denied", "Account Restricted. Please contact your barangay office for assistance.");
  }
  if (canonicalRole(resident.role) !== "resident"
    || verificationStatusForProfile(resident) !== "verified") {
    throw new HttpsError("permission-denied", "Verified residency is required to update a concern.");
  }
  const input = request.data || {};
  const id = validConcernReference(input.id || input.submissionId || input.concernId);
  const concernRef = db.collection("submissions").doc(id);

  const title = requiredText(input.title, "Concern title", 100);
  const description = requiredText(input.description, "Description", 1000);
  if (description.length < 10) {
    throw new HttpsError("invalid-argument", "Description is too short.");
  }
  const categoryId = canonicalConcernCategoryId(String(input.categoryId || "").trim());
  const selectedCategory = concernCategory(categoryId);
  if (!selectedCategory) throw new HttpsError("invalid-argument", "Select a valid concern category.");
  const organizationSector = selectedConcernSector(input, selectedCategory);
  const category = selectedCategory.name;
  const visibility = String(input.visibility || "").trim();
  if (!["public", "private"].includes(visibility)) {
    throw new HttpsError("invalid-argument", "Choose Public or Private for this concern.");
  }
  const concernType = requiredText(input.concernType || "Complaint", "Concern type", 100);
  const location = requiredText(input.location, "Location", 200);
  const attachmentStoragePath = optionalText(input.attachmentStoragePath, 500);
  const attachmentUrl = optionalText(input.attachmentUrl, 2048);
  const incidentDate = optionalText(input.incidentDate, 80);
  const customConcernType = optionalText(input.customConcernType, 100);

  if (attachmentStoragePath
    && !attachmentStoragePath.startsWith(`concerns/${resident.id}/${id}/`)
    && !attachmentStoragePath.startsWith(`concerns/`)) {
    throw new HttpsError("invalid-argument", "The evidence path is invalid.");
  }

  const now = Timestamp.now();
  const auditRef = db.collection("audit_logs").doc();
  let updatedConcern = null;

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(concernRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Concern not found.");
    }
    const concern = snapshot.data();
    const isOwner = concern.userId === resident.id
      || concern.residentId === resident.id
      || concern.createdBy === resident.id
      || concern.reporterId === resident.id
      || (Array.isArray(concern.reporterIds) && concern.reporterIds.includes(resident.id));
    if (!isOwner) {
      throw new HttpsError("permission-denied", "You cannot update this concern.");
    }
    const currentStatus = String(concern.status || "").toLowerCase().replace(/[\s-]+/g, "_");
    if (!["needs_information", "awaiting_resident", "additional_document_required", "needs_info", "awaiting_information"].includes(currentStatus)) {
      throw new HttpsError("failed-precondition", "This concern is not awaiting resident information.");
    }

    const newStatus = "new";
    const update = {
      title,
      description,
      category,
      categoryId,
      organizationSector,
      type: concernType,
      customConcernType: customConcernType || "",
      location,
      incidentDate: incidentDate || "",
      visibility,
      status: newStatus,
      updatedAt: now,
      updatedBy: resident.id,
      requestedInfoMessage: FieldValue.delete(),
      requestedInfoBy: FieldValue.delete(),
      requestedInfoAt: FieldValue.delete(),
      resumeStatusAfterInformation: FieldValue.delete(),
      statusHistory: FieldValue.arrayUnion({
        status: newStatus,
        action: "resubmitted",
        note: "Resident updated concern details and resubmitted the report.",
        date: now,
        performedBy: resident.id,
        performedAt: now,
        visibility: visibility === "private" ? "reporter_and_handlers" : "public",
        actorType: "resident",
        actorId: resident.id,
      }),
    };

    if (input.attachmentUrl !== undefined) {
      update.attachmentUrl = attachmentUrl || "";
    }
    if (input.attachmentStoragePath !== undefined) {
      update.attachmentStoragePath = attachmentStoragePath || "";
    }

    transaction.update(concernRef, update);

    // Also update report document in reports subcollection
    const reportRef = concernRef.collection("reports").doc(resident.id);
    transaction.set(reportRef, {
      reporterId: resident.id,
      reporterName: concern.reporterName || resident.name || "Resident",
      title,
      description,
      location,
      incidentDate: incidentDate || "",
      attachmentUrl: update.attachmentUrl !== undefined ? update.attachmentUrl : (concern.attachmentUrl || ""),
      attachmentStoragePath: update.attachmentStoragePath !== undefined ? update.attachmentStoragePath : (concern.attachmentStoragePath || ""),
      submittedAt: now,
      resubmittedAt: now,
    }, { merge: true });

    transaction.set(auditRef, {
      action: "concern_resubmitted",
      targetType: "submission",
      targetId: id,
      actorId: resident.id,
      barangayId: concern.barangayId || "",
      createdAt: now,
    });

    // Resident confirmation notification
    const residentNotifRef = db.collection("notifications").doc();
    transaction.set(residentNotifRef, {
      userId: resident.id,
      type: "concern_resubmitted",
      referenceId: id,
      relatedEntityType: "concern",
      title: "Concern Resubmitted",
      message: `Your concern ${id} has been resubmitted and is now Active for office review.`,
      status: "new",
      navigation: { route: "/complain" },
      read: false,
      createdAt: now,
    });

    // Handler notification if known
    const handlerId = concern.handledBy || concern.reviewedBy || concern.receiverAccountId;
    if (handlerId && handlerId !== resident.id) {
      transaction.set(db.collection("notifications").doc(), {
        userId: handlerId,
        type: "concern_update",
        referenceId: id,
        relatedEntityType: "concern",
        title: "Concern Resubmitted",
        message: `Concern ${id} was updated and resubmitted by the resident.`,
        status: "new",
        navigation: { route: "/concerns" },
        read: false,
        createdAt: now,
      });
    }

    updatedConcern = {
      id,
      department: concern.department,
      barangay: concern.barangay,
      barangayId: concern.barangayId,
      recipientId: concern.recipientId,
      recipientType: concern.recipientType,
      routingStatus: concern.routingStatus,
      status: newStatus,
    };
  });

  return updatedConcern || { id, status: "new" };
});

exports.forwardConcern = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, 'concerns')) throw new HttpsError('permission-denied', 'Concern access is disabled for this office.');
  const submissionId = validConcernReference(request.data?.submissionId);
  const recipientId = requiredText(request.data?.recipientId, "Destination", 160);
  const referralReason = requiredText(request.data?.referralReason, "Referral reason", 500);
  const recipients = await concernRecipientDirectory();
  const destination = recipients.find((item) => item.id === recipientId
    && ["municipalOffice", "partnerOrganization"].includes(canonicalRecipientType(item.recipientType)));
  if (!destination) {
    throw new HttpsError("failed-precondition", "The selected destination is unavailable.");
  }
  let destinationOrganizationId = "";
  let destinationDepartmentId = "";
  if (canonicalRecipientType(destination.recipientType) === "partnerOrganization") {
    const receiverId = String(destination.receiverAccountId || destination.inboxId || "");
    const receiver = receiverId ? await db.collection("users").doc(receiverId).get() : null;
    destinationOrganizationId = String(destination.organizationId
      || (receiver?.exists ? receiver.data().organizationId : "") || "").trim();
    if (!destinationOrganizationId) {
      throw new HttpsError("failed-precondition", "The receiving organization is not configured correctly.");
    }
  }
  if (canonicalRecipientType(destination.recipientType) === "municipalOffice") {
    destinationDepartmentId = departmentKey(destination.departmentId);
    if (!destinationDepartmentId) {
      throw new HttpsError("failed-precondition", "The receiving LGU department is not configured correctly.");
    }
  }
  const concernRef = db.collection("submissions").doc(submissionId);
  const auditRef = db.collection("audit_logs").doc();
  const notificationRef = db.collection("notifications").doc();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(concernRef);
    if (!snapshot.exists) throw new HttpsError("not-found", "Concern not found.");
    const concern = snapshot.data();
    if (isComplaint(concern)) throw new HttpsError("failed-precondition", "Use the complaint tracking workflow for this record.");
    if ((concern.schemaVersion || 0) >= 4) {
      throw new HttpsError("failed-precondition", "New concerns are routed automatically by category and cannot be manually referred.");
    }
    const actorBarangayId = effectiveBarangayId(actor);
    const concernBarangayId = String(concern.barangayId
      || barangayIdFor(canonicalBarangayName(concern.barangay)) || "").toLowerCase();
    const isLocalBarangayOfficial = BARANGAY_CONCERN_ROLES.has(canonicalRole(actor.role))
      && actorBarangayId && actorBarangayId === concernBarangayId;
    const actorDepartmentId = effectiveDepartmentId(actor);
    const isAssignedDepartment = canonicalRole(actor.role) === "lgu"
      && actorDepartmentId
      && actorDepartmentId === departmentKey(concern.recipientDepartmentId);
    const isItRecipient = isItAdministrator(actor.role)
      && effectiveDepartmentId(actor) === "it-department"
      && departmentKey(concern.recipientDepartmentId) === "it-department";
    if (!isItRecipient && !isLocalBarangayOfficial && !isAssignedDepartment) {
      throw new HttpsError("permission-denied", "Only the concern's barangay or an authorized LGU account can refer it.");
    }
    const now = Timestamp.now();
    transaction.update(concernRef, {
      previousRecipientId: String(concern.recipientId || ""),
      recipientId: destination.id,
      recipientType: canonicalRecipientType(destination.recipientType),
      receiverAccountId: String(destination.receiverAccountId || destination.inboxId),
      organizationId: destinationOrganizationId,
      recipientDepartmentId: destinationDepartmentId,
      department: String(destination.displayName),
      forwardedToRecipientId: destination.id,
      forwardedBy: actor.id,
      forwardedAt: FieldValue.serverTimestamp(),
      referredBy: actor.id,
      referredAt: FieldValue.serverTimestamp(),
      referredFromBarangayId: concernBarangayId,
      referredToRecipientId: destination.id,
      referralReason,
      reviewedBy: concern.reviewedBy || actor.id,
      reviewedByName: concern.reviewedByName || String(actor.name || actor.email || "Barangay Official"),
      reviewedAt: concern.reviewedAt || FieldValue.serverTimestamp(),
      status: "being_handled",
      handlingOfficeId: destination.id,
      handlingStartedAt: FieldValue.serverTimestamp(),
      handledBy: String(destination.receiverAccountId || destination.inboxId),
      handledByName: String(destination.displayName),
      assignedTo: String(destination.receiverAccountId || destination.inboxId),
      assignedToName: String(destination.displayName),
      assignedAt: FieldValue.serverTimestamp(),
      routingStatus: "routed",
      routingReason: "",
      updatedAt: FieldValue.serverTimestamp(),
      routingHistory: FieldValue.arrayUnion({
        action: "referred",
        previousRecipientId: String(concern.recipientId || ""),
        recipientId: destination.id,
        recipientName: String(destination.displayName),
        actorId: actor.id,
        actorName: String(actor.name || actor.email || "Administrator"),
        reason: referralReason,
        date: now,
      }),
      statusHistory: FieldValue.arrayUnion({
        status: "being_handled",
        action: "referred",
        note: `Referred to ${destination.displayName}.`,
        reason: referralReason,
        performedBy: actor.id,
        performedAt: now,
        destination: destination.id,
        date: now,
        visibility: "public",
      }),
    });
    transaction.set(auditRef, {
      action: "concern_referred",
      targetType: "submission",
      targetId: submissionId,
      actorId: actor.id,
      actorEmail: actor.email || "",
      organizationId: destinationOrganizationId,
      departmentId: destinationDepartmentId,
      recipientId: destination.id,
      referralReason,
      createdAt: FieldValue.serverTimestamp(),
    });
    const recipientUserIds = new Set();
    if (concern.userId) recipientUserIds.add(String(concern.userId));
    if (Array.isArray(concern.reporterIds)) {
      concern.reporterIds.forEach((uid) => {
        if (uid) recipientUserIds.add(String(uid));
      });
    }
    for (const uid of recipientUserIds) {
      const notifRef = db.collection("notifications").doc();
      transaction.set(notifRef, {
        userId: uid,
        type: "concern_update",
        referenceId: submissionId,
        relatedEntityType: "concern",
        title: "Concern routed",
        message: `Your concern ${submissionId} is now being handled by ${destination.displayName}.`,
        status: "being_handled",
        navigation: { route: "/complain" },
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  });
  try {
    // Also query the reports sub-collection to supplement with co-reporters who may
    // not be captured in reporterIds (safety net for residents who clicked "I have the same concern").
    const pushUserIds = new Set();
    const [snap, reportsSnap] = await Promise.all([
      db.collection("submissions").doc(submissionId).get(),
      db.collection("submissions").doc(submissionId).collection("reports").limit(200).get(),
    ]);
    if (snap.exists) {
      const cData = snap.data();
      if (cData.userId) pushUserIds.add(String(cData.userId));
      if (Array.isArray(cData.reporterIds)) {
        cData.reporterIds.forEach((uid) => { if (uid) pushUserIds.add(String(uid)); });
      }
    }
    // Add co-reporters from sub-collection
    reportsSnap.docs.forEach((doc) => {
      const uid = doc.id || doc.data().reporterId;
      if (uid) pushUserIds.add(String(uid));
    });
    // Send in-app notifications to co-reporters not already notified in the transaction
    const txnRecipients = new Set();
    if (snap.exists) {
      const cData = snap.data();
      if (cData.userId) txnRecipients.add(String(cData.userId));
      if (Array.isArray(cData.reporterIds)) {
        cData.reporterIds.forEach((uid) => { if (uid) txnRecipients.add(String(uid)); });
      }
    }
    const newCoReporters = [...pushUserIds].filter((uid) => !txnRecipients.has(uid));
    if (newCoReporters.length > 0) {
      const batch = db.batch();
      for (const uid of newCoReporters) {
        batch.set(db.collection("notifications").doc(), {
          userId: uid,
          type: "concern_update",
          referenceId: submissionId,
          relatedEntityType: "concern",
          title: "Concern routed",
          message: `Your concern ${submissionId} is now being handled by ${destination.displayName}.`,
          status: "being_handled",
          navigation: { route: "/complain" },
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    await sendNormalPushToUsers(Array.from(pushUserIds), {
      title: "Concern routed",
      body: `Your concern ${submissionId} is now being handled by ${destination.displayName}.`,
      type: "concern_update",
      referenceId: submissionId,
    });
  } catch (_) { }
  return { submissionId, recipientId, routed: true };
});

const CONCERN_FLAG_REASONS = new Set([
  "False / Fake Report", "Nonsense / Spam", "Inaccurate Information",
  "Duplicate / Misleading Report", "Other",
]);

exports.flagConcern = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, 'concerns')) throw new HttpsError('permission-denied', 'Concern access is disabled for this office.');
  const concernId = validConcernReference(request.data?.concernId);
  const reason = String(request.data?.reason || "").trim();
  if (!CONCERN_FLAG_REASONS.has(reason)) throw new HttpsError("invalid-argument", "Choose a valid flag reason.");
  const explanation = optionalText(request.data?.explanation, 300);
  if (reason === "Other" && explanation.length < 3) {
    throw new HttpsError("invalid-argument", "Explain why this concern is being flagged.");
  }
  const concernRef = db.collection("submissions").doc(concernId);
  const flagRef = db.collection("concern_flags").doc(concernId);
  const concernSnapshot = await concernRef.get();
  if (!concernSnapshot.exists) throw new HttpsError("not-found", "Concern not found.");
  const residentId = String(concernSnapshot.data().userId || "");
  if (!residentId) throw new HttpsError("failed-precondition", "This concern has no resident account.");
  const residentSnapshot = await db.collection("users").doc(residentId).get();
  const resident = residentSnapshot.data();
  const homeBarangayId = resident && verificationStatusForProfile(resident) === "verified"
    ? registeredConcernBarangayId(resident) : "";
  const officials = homeBarangayId
    ? await db.collection("users").where("barangayId", "==", homeBarangayId).get() : null;
  const recipients = officials?.docs.filter((document) => {
    const official = document.data();
    return isActiveProfile(official) && BARANGAY_ROLES.has(canonicalRole(official.role))
      && effectiveBarangayId(official) === homeBarangayId;
  }) || [];
  const actorOrganizationId = String(actor.organizationId || "").trim();
  const organization = actorOrganizationId
    ? (await db.collection("organizations").doc(actorOrganizationId).get()).data() : null;

  await db.runTransaction(async (transaction) => {
    const [current, existingFlag] = await Promise.all([
      transaction.get(concernRef), transaction.get(flagRef),
    ]);
    if (!current.exists) throw new HttpsError("not-found", "Concern not found.");
    if (existingFlag.exists) throw new HttpsError("already-exists", "This concern is already flagged for review.");
    const concern = current.data();
    if (concern.userId !== residentId) throw new HttpsError("failed-precondition", "Concern owner changed. Refresh and try again.");
    if (["resolved", "closed", "rejected"].includes(String(concern.status || "").toLowerCase())) {
      throw new HttpsError("failed-precondition", "A resolved concern cannot be flagged.");
    }
    const autoRouted = Number(concern.schemaVersion || 0) >= 4;
    const concernBarangayId = String(concern.barangayId
      || barangayIdFor(canonicalBarangayName(concern.barangay)) || "").toLowerCase();
    const barangayHandler = BARANGAY_CONCERN_ROLES.has(canonicalRole(actor.role))
      && concern.recipientType === "barangay" && effectiveBarangayId(actor) === concernBarangayId;
    const departmentHandler = canonicalRole(actor.role) === "lgu"
      && effectiveDepartmentId(actor)
      && effectiveDepartmentId(actor) === departmentKey(concern.recipientDepartmentId);
    const itHandler = isItAdministrator(actor.role)
      && effectiveDepartmentId(actor) === "it-department"
      && departmentKey(concern.recipientDepartmentId) === "it-department";
    const organizationHandler = canonicalRole(actor.role) === "organization"
      && (autoRouted
        ? Array.isArray(concern.organizationIds)
        && concern.organizationIds.includes(actorOrganizationId)
        && ["verified", "active"].includes(String(organization?.status || "").toLowerCase())
        && organization.categoryId === concern.categoryId
        : actorOrganizationId && actorOrganizationId === String(concern.organizationId || ""));
    const legacyReceiver = !autoRouted && !itHandler && concern.receiverAccountId === actor.id;
    if (!barangayHandler && !departmentHandler && !itHandler && !organizationHandler && !legacyReceiver) {
      throw new HttpsError("permission-denied", "Only the assigned concern handler can flag this concern.");
    }
    const flaggedAt = Timestamp.now();
    const flaggedByName = String(actor.name || actor.organizationName || actor.email || "Concern handler");
    transaction.create(flagRef, {
      concernId, residentId, reason, explanation: reason === "Other" ? explanation : "",
      flaggedBy: actor.id, flaggedByRole: canonicalRole(actor.role), flaggedByName,
      flaggedAt, status: "pending_review", homeBarangayId,
    });
    transaction.update(concernRef, {
      moderationFlagStatus: "pending_review", moderationFlagId: concernId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(db.collection("notifications").doc(), {
      userId: residentId, type: "concern_flag", referenceId: concernId,
      relatedEntityType: "concern", title: "Your concern was flagged for review.",
      message: `${concernId} • Reason: ${reason}${reason === "Other" ? ` — ${explanation}` : ""}`,
      navigation: { route: "/complain" }, read: false, createdAt: flaggedAt,
    });
    for (const official of recipients) {
      transaction.set(db.collection("notifications").doc(), {
        userId: official.id, type: "concern_flag_barangay", referenceId: concernId,
        relatedEntityType: "concern_flag", title: "A resident from your barangay received a concern flag.",
        message: `Resident: ${resident.name || "Resident"} • Concern: ${concernId} • Reason: ${reason} • Flagged by: ${flaggedByName} • Date: ${flaggedAt.toDate().toISOString()}`,
        residentId, reason, flaggedBy: actor.id, flaggedAt,
        read: false, createdAt: flaggedAt,
      });
    }
    if (homeBarangayId) {
      transaction.set(db.collection("verification_queue_versions").doc(homeBarangayId), {
        barangayId: homeBarangayId, updatedAt: flaggedAt,
      }, { merge: true });
    }
    transaction.set(db.collection("audit_logs").doc(), {
      action: "concern_flagged", targetType: "submission", targetId: concernId,
      actorId: actor.id, actorRole: canonicalRole(actor.role), residentId, reason,
      createdAt: flaggedAt,
    });
  });
  return { concernId, flagged: true };
});

exports.listResidentConcernFlags = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const residentId = requiredText(request.data?.residentId, "Resident account", 128);
  const resident = (await residentAccountForManagement(actor, residentId)).profile;
  if (!canRestrictResidentAccount(actor, resident)) {
    throw new HttpsError("permission-denied", "Only the resident's verified home barangay can review concern flags.");
  }
  const snapshot = await db.collection("concern_flags").where("residentId", "==", residentId).get();
  return {
    flags: snapshot.docs.map((document) => ({ id: document.id, ...document.data(), flaggedAt: timestampMillis(document.data().flaggedAt) }))
      .sort((a, b) => b.flaggedAt - a.flaggedAt)
  };
});

exports.deleteComplaint = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, "concerns")) throw new HttpsError("permission-denied", "Complaint access is disabled for this office.");
  const submissionId = validComplaintReference(request.data?.submissionId);
  if (!submissionId) throw new HttpsError("invalid-argument", "A valid complaint reference is required.");
  if (request.data?.confirmDelete !== true) throw new HttpsError("invalid-argument", "Confirm the complaint deletion first.");
  const reference = db.collection("submissions").doc(submissionId);
  const auditReference = db.collection("audit_logs").doc(`complaint_deleted_${submissionId}`);
  await db.runTransaction(async transaction => {
    const [snapshot, receipt] = await Promise.all([transaction.get(reference), transaction.get(auditReference)]);
    if (!snapshot.exists) {
      if (receipt.exists && receipt.data().actorId === actor.id) return;
      throw new HttpsError("not-found", "This complaint no longer exists.");
    }
    const complaint = snapshot.data();
    if (!canDeleteComplaintRecord({ role: canonicalRole(actor.role), actorBarangayId: effectiveBarangayId(actor),
      concernBarangayId: effectiveBarangayId(complaint), kind: complaint.kind })) {
      throw new HttpsError("permission-denied", "Only administrators or this barangay's captain, vice captain or secretary can delete a complaint.");
    }
    transaction.set(auditReference, {
      action: "complaint_deleted", targetType: "submission", targetId: submissionId,
      actorId: actor.id, actorRole: canonicalRole(actor.role), actorEmail: actor.email || "",
      barangayId: effectiveBarangayId(complaint), previousStatus: String(complaint.status || ""),
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.delete(reference);
  });
  return { success: true, submissionId, deleted: true };
});

exports.deleteConcern = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, "concerns")) throw new HttpsError("permission-denied", "Concern access is disabled for this office.");
  const submissionId = validConcernReference(request.data?.submissionId);
  if (request.data?.confirmDelete !== true) throw new HttpsError("invalid-argument", "Confirm the concern deletion first.");
  const reference = db.collection("submissions").doc(submissionId);
  const auditReference = db.collection("audit_logs").doc(`concern_deleted_${submissionId}`);
  await db.runTransaction(async transaction => {
    const [snapshot, receipt] = await Promise.all([transaction.get(reference), transaction.get(auditReference)]);
    if (!snapshot.exists) {
      if (receipt.exists && receipt.data().actorId === actor.id) return;
      throw new HttpsError("not-found", "This concern no longer exists.");
    }
    const concern = snapshot.data();
    if (!canDeleteConcernRecord({ role: canonicalRole(actor.role), actorBarangayId: effectiveBarangayId(actor),
      concernBarangayId: effectiveBarangayId(concern), kind: concern.kind })) {
      throw new HttpsError("permission-denied", "Only administrators or this barangay's captain, vice captain or secretary can delete a concern. Complaint case files cannot be deleted here.");
    }
    transaction.set(auditReference, {
      action: "concern_deleted", targetType: "submission", targetId: submissionId,
      actorId: actor.id, actorRole: canonicalRole(actor.role), actorEmail: actor.email || "",
      barangayId: effectiveBarangayId(concern), title: String(concern.title || "").slice(0, 200),
      category: String(concern.category || "").slice(0, 160), previousStatus: String(concern.status || ""),
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.delete(reference);
    transaction.delete(db.collection("public_concern_summaries").doc(submissionId));
  });
  return { success: true, submissionId, deleted: true };
});

exports.reviewConcern = onCall({ region: REGION }, async (request) => {
  const started = Date.now();
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, 'concerns')) {
    throw new HttpsError('permission-denied', 'Concern access is disabled for this office.');
  }
  const submissionId = validConcernReference(request.data?.submissionId);
  const action = requiredText(request.data?.action, "Review action", 40);
  if (!["handle", "request_information", "resolve", "duplicate", "outside_scope"].includes(action)) {
    throw new HttpsError("invalid-argument", "Choose a valid review action.");
  }
  const reason = optionalText(request.data?.reason, 800);
  if (["request_information", "resolve", "duplicate", "outside_scope"].includes(action) && reason.length < 3) {
    throw new HttpsError("invalid-argument", "A clear reason is required.");
  }
  const concernRef = db.collection("submissions").doc(submissionId);
  const auditRef = db.collection("audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(concernRef);
    if (!snapshot.exists) throw new HttpsError("not-found", "Concern not found.");
    const concern = snapshot.data();
    if (isComplaint(concern)) throw new HttpsError("failed-precondition", "Use the complaint tracking workflow for this record.");
    const autoRouted = (concern.schemaVersion || 0) >= 4;
    const actorOrganizationId = String(actor.organizationId || "").trim();
    const organizationSnapshot = autoRouted && actorOrganizationId
      ? await transaction.get(db.collection("organizations").doc(actorOrganizationId)) : null;
    const organization = organizationSnapshot?.data();
    const isOversightAdmin = isItAdministrator(actor.role)
      || canonicalRole(actor.role) === "super_admin"
      || canonicalRole(actor.role) === "mayor"
      || (canonicalRole(actor.role) === "lgu" && !concern.recipientDepartmentId);
    const actorBarangayId = effectiveBarangayId(actor);
    const concernBarangayId = String(concern.barangayId
      || barangayIdFor(canonicalBarangayName(concern.barangay)) || "").toLowerCase();
    const isLocalBarangayOfficial = BARANGAY_CONCERN_ROLES.has(canonicalRole(actor.role))
      && actorBarangayId && (actorBarangayId === concernBarangayId || !concernBarangayId);
    const isCurrentReceiver = String(concern.receiverAccountId || "") === actor.id
      && !autoRouted && !isItAdministrator(actor.role);
    const isAssignedOrganization = canonicalRole(actor.role) === "organization"
      && (autoRouted
        ? Array.isArray(concern.organizationIds)
        && concern.organizationIds.includes(actorOrganizationId)
        && ["verified", "active"].includes(String(organization?.status || "").toLowerCase())
        && organization.categoryId === concern.categoryId
        : actorOrganizationId && actorOrganizationId === String(concern.organizationId || ""));
    const isAssignedDepartment = canonicalRole(actor.role) === "lgu"
      && effectiveDepartmentId(actor)
      && (!concern.recipientDepartmentId || effectiveDepartmentId(actor) === departmentKey(concern.recipientDepartmentId));
    const isItRecipient = isItAdministrator(actor.role)
      && (effectiveDepartmentId(actor) === "it-department"
        || departmentKey(concern.recipientDepartmentId) === "it-department");
    if (!isOversightAdmin && !isItRecipient && !isLocalBarangayOfficial && !isCurrentReceiver
      && !isAssignedOrganization && !isAssignedDepartment) {
      throw new HttpsError("permission-denied", "You cannot review this concern.");
    }
    if (autoRouted && !isOversightAdmin && !isItRecipient) {
      const leadId = String(concern.leadOrganizationId || "");
      if (isAssignedOrganization && ((action === "handle" && leadId && leadId !== actorOrganizationId)
        || (action !== "handle" && leadId !== actorOrganizationId))) {
        throw new HttpsError("failed-precondition", "Another organization is handling this concern.");
      }
      if (isLocalBarangayOfficial && leadId) {
        throw new HttpsError("failed-precondition", "The lead organization is handling this concern.");
      }
    }
    const now = Timestamp.now();
    const currentStatus = String(concern.status || "new").toLowerCase();
    if (["resolved", "closed", "rejected"].includes(currentStatus)
      || (!["handle", "resolve"].includes(action) && ["needs_information", "awaiting_resident"].includes(currentStatus))) {
      throw new HttpsError("failed-precondition", "This concern's status has changed. Refresh and try again.");
    }
    const actorName = String(actor.name || actor.email || "Barangay Official");
    const barangayName = canonicalBarangayName(concern.barangay) || concern.barangay || "Barangay";
    let status;
    let note;
    const update = {
      reviewedBy: concern.reviewedBy || actor.id,
      reviewedByName: concern.reviewedByName || actorName,
      reviewedAt: concern.reviewedAt || FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.id,
    };
    if (action === "handle") {
      status = "being_handled";
      const defaultNote = isItRecipient
        ? "LGU IT Department is now handling this concern."
        : isAssignedOrganization
          ? `${actor.organizationName || actor.name || "The assigned organization"} is now handling this concern.`
          : isAssignedDepartment
            ? `${actor.departmentPublicName || departmentPublisherName({ name: actor.department })} is now handling this concern.`
            : `${barangayName.startsWith("Barangay ") ? barangayName : `Barangay ${barangayName}`} is now handling this concern.`;
      note = reason && reason.trim().length >= 3 ? reason.trim() : defaultNote;
      Object.assign(update, {
        status,
        ...(autoRouted && isAssignedOrganization ? { leadOrganizationId: actorOrganizationId } : {}),
        handlingOfficeId: concern.recipientId || concernBarangayId,
        handlingStartedAt: FieldValue.serverTimestamp(),
        handledBy: actor.id,
        handledByName: actorName,
        handledByRole: canonicalRole(actor.role),
        handlingNote: note,
        progressNote: note,
      });
    } else if (action === "request_information") {
      status = "needs_information";
      note = `Additional information requested: ${reason}`;
      Object.assign(update, {
        status,
        requestedInfoMessage: reason,
        requestedInfoBy: actorName,
        requestedInfoAt: FieldValue.serverTimestamp(),
        resumeStatusAfterInformation: "being_handled",
      });
    } else if (action === "resolve") {
      status = "resolved";
      note = `Concern resolved: "${reason}"`;
      Object.assign(update, {
        status,
        resolutionSummary: reason,
        resolvedBy: actor.id,
        resolvedByName: actorName,
        resolvedAt: FieldValue.serverTimestamp(),
      });
    } else {
      status = "resolved";
      const label = action === "duplicate" ? "Duplicate report" : "Outside E-SUGID scope";
      note = `${label}: ${reason}`;
      Object.assign(update, {
        status,
        closureOutcome: action,
        closureReason: reason,
        resolutionSummary: note,
        resolvedBy: actor.id,
        resolvedByName: actorName,
        resolvedAt: FieldValue.serverTimestamp(),
      });
    }
    update.statusHistory = FieldValue.arrayUnion({
      status,
      action,
      note,
      reason,
      performedBy: actor.id,
      performedAt: now,
      date: now,
      visibility: "public",
      actorId: actor.id,
      actorName,
      actorRole: canonicalRole(actor.role),
    });
    transaction.update(concernRef, update);
    transaction.set(auditRef, {
      action: `concern_${action}`,
      targetType: "submission",
      targetId: submissionId,
      actorId: actor.id,
      actorEmail: actor.email || "",
      organizationId: isAssignedOrganization ? String(actor.organizationId) : "",
      reason,
      createdAt: FieldValue.serverTimestamp(),
    });
    const recipientUserIds = new Set();
    if (concern.userId) recipientUserIds.add(String(concern.userId));
    if (concern.createdBy) recipientUserIds.add(String(concern.createdBy));
    if (concern.residentId) recipientUserIds.add(String(concern.residentId));
    // Collect all co-reporters from reporterIds array field
    if (Array.isArray(concern.reporterIds)) {
      concern.reporterIds.forEach((uid) => {
        if (uid) recipientUserIds.add(String(uid));
      });
    }
    // Also collect any reporter IDs from the reports sub-collection (safety net
    // for older documents or edge cases where reporterIds may be incomplete).
    // We read them outside the transaction to avoid transaction read limits.
    const notifTitle = action === "request_information"
        ? (isComplaint(concern) ? "Your complaint needs details" : "More information needed")
        : action === "handle"
          ? (currentStatus === "being_handled" ? "Concern progress update" : "Concern in progress")
          : action === "resolve" ? "Concern resolved" : "Concern reviewed";

    for (const uid of recipientUserIds) {
      const notifRef = db.collection("notifications").doc();
      transaction.set(notifRef, {
        userId: uid,
        type: "concern_update",
        referenceId: submissionId,
        relatedEntityType: "concern",
        title: notifTitle,
        message: note,
        status,
        navigation: { route: "/complain" },
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    queueWebNotification(transaction, { kind: "concern", userIds: Array.from(recipientUserIds),
      title: notifTitle, body: note, type: "concern_update", referenceId: submissionId });
  });
  console.info("[WEB_ACTION] Committed", { function: "reviewConcern", durationMs: Date.now() - started });
  return { submissionId, action, reviewed: true };
});

async function lookupSummonsOfficials(data) {
  const identity = summonsBarangay(data);
  if (!identity.barangayId) return { ...identity, captainName: "", secretaryName: "" };
  const sources = await Promise.all([
    db.collection("users").where("barangayId", "==", identity.barangayId).limit(1000).get(),
    db.collection("users").where("barangayId", "==", identity.barangayId.replace(/^barili_/, "")).limit(1000).get(),
    db.collection("users").where("barangay", "==", identity.barangay).limit(1000).get(),
  ]);
  const profiles = [...new Map(sources.flatMap(source => source.docs)
    .map(doc => [doc.id, { ...doc.data(), id: doc.id }])).values()];
  return selectSummonsOfficials(profiles, data);
}

exports.getSummonsOfficials = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const id = validConcernReference(request.data?.submissionId);
  const snapshot = await db.collection("submissions").doc(id).get();
  if (!snapshot.exists) throw new HttpsError("not-found", "Case record not found.");
  const data = snapshot.data();
  const identity = summonsBarangay(data);
  const role = canonicalRole(actor.role);
  const reporter = [data.userId, data.createdBy, ...(data.reporterIds || [])].includes(actor.id);
  const oversight = ["super_admin", "mayor"].includes(role);
  const ownOffice = identity.barangayId && BARANGAY_CONCERN_ROLES.has(role)
    && summonsBarangay({ barangayId: actor.barangayId, barangay: actor.barangay }).barangayId === identity.barangayId
    && await actorCan(actor, "concerns");
  if (!reporter && !oversight && !ownOffice) throw new HttpsError("permission-denied", "You cannot view this case's officials.");
  return lookupSummonsOfficials(data);
});

exports.getConcernHandler = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  const snapshot = await db.collection("submissions").doc(validConcernReference(request.data?.submissionId)).get();
  if (!snapshot.exists) throw new HttpsError("not-found", "Concern record not found.");
  const data = snapshot.data();
  const role = canonicalRole(actor.role);
  const identity = summonsBarangay(data);
  const sameBarangay = identity.barangayId && summonsBarangay({ barangayId: actor.barangayId, barangay: actor.barangay }).barangayId === identity.barangayId;
  const reporter = [data.userId, data.createdBy, ...(data.reporterIds || [])].includes(actor.id);
  const oversight = ["super_admin", "mayor"].includes(role);
  const verifiedBarangay = summonsBarangay({ barangayId: actor.verifiedBarangayId || actor.barangayId, barangay: actor.barangay }).barangayId;
  const reportBarangay = summonsBarangay({ barangayId: data.barangayId, barangay: data.barangay }).barangayId;
  const publicResident = !isComplaint(data) && role === "resident" && data.visibility === "public"
    && ["verified", "approved"].includes(String(actor.verificationStatus || "").toLowerCase())
    && verifiedBarangay && verifiedBarangay === reportBarangay;
  const ownOffice = BARANGAY_CONCERN_ROLES.has(role) && sameBarangay && await actorCan(actor, "concerns");
  const departmentId = effectiveDepartmentId(actor);
  const organizationId = String(actor.organizationId || "").trim();
  const assignedDepartment = role === "lgu" && departmentId && departmentId === data.recipientDepartmentId && await actorCan(actor, "concerns");
  const assignedOrganization = role === "organization" && organizationId && [data.organizationId, data.leadOrganizationId, ...(data.organizationIds || [])].includes(organizationId) && await actorCan(actor, "concerns");
  if (!reporter && !oversight && !publicResident && !ownOffice && !assignedDepartment && !assignedOrganization) {
    throw new HttpsError("permission-denied", "You cannot view this concern's handler.");
  }
  const lastHandlingEvent = [...(data.statusHistory || [])].reverse().find(entry => entry.action === "handle");
  const eventId = String(lastHandlingEvent?.actorId || lastHandlingEvent?.performedBy || "");
  const event = data.handledBy && data.handledBy !== eventId ? null : lastHandlingEvent;
  const id = String(data.handledBy || event?.actorId || event?.performedBy || "").trim();
  if (!id || id.includes("/") || id.length > 128) return { name: "", role: "" };
  const handler = await db.collection("users").doc(id).get();
  const profile = handler.data() || {};
  const handlerRole = canonicalRole(profile.role || data.handledByRole || event?.actorRole);
  if (!["super_admin", "mayor", "lgu", "organization", ...BARANGAY_CONCERN_ROLES].includes(handlerRole)) return { name: "", role: "" };
  const name = String(profile.name || data.handledByName || event?.actorName || "").trim();
  return { name: name === id || name.includes("@") ? "" : name.slice(0, 120), role: handlerRole };
});

exports.issueConcernSummons = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (!await actorCan(actor, 'concerns')) {
    throw new HttpsError('permission-denied', 'Concern access is disabled for this office.');
  }
  const submissionId = validConcernReference(request.data?.submissionId);
  const respondentName = optionalText(request.data?.respondentName, 160) || "Resident Concerned / Respondent";
  const respondentAddress = optionalText(request.data?.respondentAddress, 240) || "";
  const appearanceDate = requiredText(request.data?.appearanceDate, "Hearing / Meeting Date", 80);
  const appearanceTime = requiredText(request.data?.appearanceTime, "Hearing / Meeting Time", 80);
  const appearanceVenue = optionalText(request.data?.appearanceVenue, 160) || "Barangay Hall";
  const hearingPurpose = optionalText(request.data?.hearingPurpose, 400) || "Mediation / Settlement of Complaint";
  const remarks = optionalText(request.data?.remarks, 600) || "";

  const concernRef = db.collection("submissions").doc(submissionId);
  const auditRef = db.collection("audit_logs").doc();
  let notifyContext = null;
  let issuedOfficials = null;

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(concernRef);
    if (!snapshot.exists) throw new HttpsError("not-found", "Concern record not found.");
    const concern = snapshot.data();
    if (isComplaint(concern)) throw new HttpsError("failed-precondition", "Use the complaint tracking workflow for this record.");

    // Only the case's own barangay officials (or municipal oversight) may
    // summon a resident, and never on a closed case.
    const concernBarangayId = summonsBarangay(concern).barangayId;
    const isOversight = ["super_admin", "mayor"].includes(canonicalRole(actor.role));
    const isOwnBarangayOfficial = BARANGAY_CONCERN_ROLES.has(canonicalRole(actor.role))
      && summonsBarangay({ barangayId: actor.barangayId, barangay: actor.barangay }).barangayId === concernBarangayId;
    if (!isOversight && !isOwnBarangayOfficial) {
      throw new HttpsError("permission-denied", "Only this barangay's officials can issue a summons.");
    }
    if (["resolved", "closed", "rejected"].includes(String(concern.status || "").toLowerCase())) {
      throw new HttpsError("failed-precondition", "This case is already closed.");
    }

    const actorName = String(actor.name || actor.email || "Barangay Official");
    const officials = await lookupSummonsOfficials(concern);
    issuedOfficials = officials;
    const barangayName = officials.barangay || "Barangay";
    const now = Timestamp.now();

    const summonsData = {
      issuedAt: now,
      issuedBy: actor.id,
      issuedByName: actorName,
      barangay: barangayName,
      barangayId: officials.barangayId,
      officials,
      assignedTanod: manualTanodName(optionalText(request.data?.assignedTanod, 100)),
      respondentName,
      respondentAddress,
      appearanceDate,
      appearanceTime,
      appearanceVenue,
      hearingPurpose,
      remarks,
      status: "issued",
      deliveryMethod: "Personal service via Barangay Tanod / Peace Officer",
    };

    const note = `Official Barangay Summons issued for hearing on ${appearanceDate} at ${appearanceTime} (${appearanceVenue}). Physical copy will be served to the respondent by the Barangay Tanod.`;

    const update = {
      summons: summonsData,
      // A summons means the case is being acted on.
      status: "being_handled",
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.id,
      statusHistory: FieldValue.arrayUnion({
        status: "being_handled",
        action: "summons_issued",
        note,
        reason: hearingPurpose,
        performedBy: actor.id,
        performedAt: now,
        date: now,
        visibility: "public",
        actorId: actor.id,
        actorName,
      })
    };

    transaction.update(concernRef, update);
    transaction.set(auditRef, {
      action: "concern_summons_issued",
      targetType: "submission",
      targetId: submissionId,
      actorId: actor.id,
      actorEmail: actor.email || "",
      respondentName,
      appearanceDate,
      appearanceTime,
      createdAt: FieldValue.serverTimestamp(),
    });

    const recipientUserIds = new Set();
    if (concern.userId) recipientUserIds.add(String(concern.userId));
    if (Array.isArray(concern.reporterIds)) {
      concern.reporterIds.forEach((uid) => {
        if (uid) recipientUserIds.add(String(uid));
      });
    }

    const notifTitle = "Official Summons Issued";
    for (const uid of recipientUserIds) {
      const notifRef = db.collection("notifications").doc();
      transaction.set(notifRef, {
        userId: uid,
        type: "concern_update",
        referenceId: submissionId,
        relatedEntityType: "concern",
        title: notifTitle,
        message: note,
        status: "being_handled",
        navigation: { route: "/complain" },
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    notifyContext = { userIds: Array.from(recipientUserIds), title: notifTitle, message: note, submissionId };
  });

  if (notifyContext && notifyContext.userIds.length > 0) {
    try {
      await sendNormalPushToUsers(notifyContext.userIds, {
        title: notifyContext.title,
        body: notifyContext.message,
        type: "concern_update",
        referenceId: notifyContext.submissionId,
      });
    } catch (_) { }
  }

  return { submissionId, summonsIssued: true, officials: issuedOfficials };
});


exports.manageConcernRecipient = onCall({ region: REGION }, async (request) => {
  const actor = await approvedCaller(request);
  if (canonicalRole(actor.role) !== "super_admin") {
    throw new HttpsError("permission-denied", "Only an LGU IT administrator can manage concern recipients.");
  }
  const input = request.data || {};
  const recipientId = requiredText(input.recipientId, "Recipient ID", 160)
    .toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  if (!recipientId) {
    throw new HttpsError("invalid-argument", "Recipient ID must contain letters or numbers.");
  }
  const displayName = requiredText(input.displayName, "Display name", 120);
  const recipientType = canonicalRecipientType(input.recipientType);
  if (!["barangay", "municipalOffice", "partnerOrganization"].includes(recipientType)) {
    throw new HttpsError("invalid-argument", "Choose a valid recipient type.");
  }
  const status = input.status === "inactive" ? "inactive" : "active";
  const canReceiveConcerns = input.canReceiveConcerns === true;
  const receiverAccountId = optionalText(input.receiverAccountId, 160);
  let receiverOrganizationId = "";
  let receiverDepartmentId = "";
  if (status === "active" && canReceiveConcerns) {
    if (!receiverAccountId) {
      throw new HttpsError("invalid-argument", "An active recipient requires a receiving account.");
    }
    const receiver = await db.collection("users").doc(receiverAccountId).get();
    if (!receiver.exists || !isActiveProfile(receiver.data())) {
      throw new HttpsError("failed-precondition", "The connected receiving account must be active.");
    }
    const receiverRole = canonicalRole(receiver.data().role);
    receiverOrganizationId = receiverRole === "organization"
      ? optionalText(receiver.data().organizationId, 160) : "";
    receiverDepartmentId = isMunicipalRole(receiverRole)
      ? effectiveDepartmentId(receiver.data()) : "";
    if ((recipientType === "municipalOffice" && !isMunicipalRole(receiverRole))
      || (recipientType === "partnerOrganization" && receiverRole !== "organization")
      || (recipientType === "barangay" && !BARANGAY_ROLES.has(receiverRole))) {
      throw new HttpsError("invalid-argument", "The account role does not match the recipient type.");
    }
    if (recipientType === "partnerOrganization" && !receiverOrganizationId) {
      throw new HttpsError("failed-precondition", "The receiving account needs an organization assignment.");
    }
    if (recipientType === "municipalOffice" && !receiverDepartmentId) {
      throw new HttpsError("failed-precondition", "The receiving LGU account needs a department assignment.");
    }
  }
  const categoriesHandled = (Array.isArray(input.categoriesHandled)
    ? input.categoriesHandled : [])
    .map((item) => String(item).trim())
    .filter(Boolean)
    .slice(0, 50);
  const recipientRef = db.collection("concern_recipients").doc(recipientId);
  const existingRecipient = await recipientRef.get();
  await recipientRef.set({
    displayName,
    recipientType,
    status,
    canReceiveConcerns,
    receiverAccountId,
    inboxId: receiverAccountId,
    fallbackRecipientId: optionalText(input.fallbackRecipientId, 160),
    categoriesHandled: [...new Set(categoriesHandled)],
    organizationId: recipientType === "partnerOrganization" ? receiverOrganizationId : "",
    departmentId: recipientType === "municipalOffice" ? receiverDepartmentId : "",
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: actor.id,
    ...(!existingRecipient.exists ? { createdAt: FieldValue.serverTimestamp() } : {}),
  }, { merge: true });
  return { recipientId, saved: true };
});

exports.createConcernSubmissionNotification = onDocumentCreated(
  { document: "submissions/{submissionId}", region: REGION },
  async (event) => {
    const submission = event.data?.data();
    const userId = String(submission?.userId || submission?.residentId || "").trim();
    if (!submission || !userId) return;
    await db.collection("notifications")
      .doc(`concern_submitted_${event.params.submissionId}_${userId}`)
      .set({
        userId,
        type: isComplaint(submission) ? "complaint_submitted" : "concern_submitted",
        referenceId: event.params.submissionId,
        relatedEntityType: isComplaint(submission) ? "complaint" : "submission",
        title: isComplaint(submission) ? "Complaint received" : "Concern received",
        message: isComplaint(submission)
          ? `Your complaint ${event.params.submissionId} was sent to ${submission.department || "your barangay"}. Only you and barangay officials can see it.`
          : `Your concern ${event.params.submissionId} has been received.`,
        navigation: { route: "/complain" },
        read: false,
        createdAt: submission.date || FieldValue.serverTimestamp(),
      }, { merge: false });
  },
);

exports.createDocumentRequestNotification = onDocumentCreated(
  { document: "document_requests/{requestId}", region: REGION },
  async (event) => {
    const request = event.data?.data();
    const userId = String(request?.userId || "").trim();
    if (!request || !userId) return;
    await db.collection("notifications")
      .doc(`document_submitted_${event.params.requestId}_${userId}`)
      .set({
        userId,
        type: "document_request_submitted",
        referenceId: event.params.requestId,
        relatedEntityType: "document_request",
        title: "Service request submitted",
        message: `Your ${String(request.type || "document")} request was submitted.`,
        navigation: { route: "/documents" },
        read: false,
        createdAt: request.dateSubmitted || FieldValue.serverTimestamp(),
      }, { merge: false });
  },
);

exports.createHelpdeskTicketNotification = onDocumentCreated(
  { document: "helpdesk_tickets/{ticketId}", region: REGION },
  async (event) => {
    const ticket = event.data?.data();
    const userId = String(ticket?.userId || "").trim();
    if (!ticket || !userId) return;
    await db.collection("notifications")
      .doc(`helpdesk_submitted_${event.params.ticketId}_${userId}`)
      .set({
        userId,
        type: "helpdesk_submitted",
        referenceId: event.params.ticketId,
        relatedEntityType: "helpdesk_ticket",
        title: "Support request received",
        message: "Your support request was received and is awaiting a response.",
        navigation: { route: "/helpdesk" },
        read: false,
        createdAt: ticket.createdAt || FieldValue.serverTimestamp(),
      }, { merge: false });
  },
);

exports.notifyJobOwnerOfInterest = onDocumentCreated(
  { document: "jobs/{jobId}/interests/{volunteerId}", region: REGION },
  async (event) => {
    const interest = event.data?.data();
    if (!interest) return;
    if (interest.conversationId) return;
    const { jobId, volunteerId } = event.params;
    if (interest.volunteerId !== volunteerId) return;
    const jobSnapshot = await db.collection("jobs").doc(jobId).get();
    const job = jobSnapshot.data();
    const ownerId = String(job?.posterId || "");
    if (!jobSnapshot.exists || !ownerId || ownerId === volunteerId) return;
    await db.collection("notifications")
      .doc(`job_interest_${jobId}_${volunteerId}`)
      .set({
        userId: ownerId,
        type: "help_interest",
        title: "New help offer",
        message: `${String(interest.volunteerName || "A resident")} offered to help with ${String(job.title || "your request")}.`,
        referenceId: jobId,
        navigation: { route: "/jobs", jobId },
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: false });
  },
);

async function awardCivicPointsOnce({ userId, amount, reason, eventId, relatedId }) {
  if (!userId || !Number.isInteger(amount) || amount <= 0) return;
  const pointsRef = db.collection("civic_points").doc(userId);
  const historyRef = pointsRef.collection("history").doc(eventId);
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(historyRef);
    if (existing.exists) return;
    transaction.set(pointsRef, {
      points: FieldValue.increment(amount),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    transaction.set(historyRef, {
      amount,
      reason,
      relatedId,
      eventId,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

exports.awardPointsForCompletedHelp = onDocumentUpdated(
  { document: "jobs/{jobId}", region: REGION },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (String(before.status || "").toLowerCase() === "completed" ||
      String(after.status || "").toLowerCase() !== "completed") return;
    if (Array.isArray(after.acceptedHelperIds)) return;
    const category = String(after.category || "offer").toLowerCase();
    const posterId = String(after.posterId || "");
    const helperId = String(after.helperId || "");
    if (!helperId) return;
    const interest = await event.data.after.ref
      .collection("interests")
      .doc(helperId)
      .get();
    if (!interest.exists || String(interest.data()?.status || "").toLowerCase() !== "accepted") return;
    const recipientId = category === "request" ? helperId : posterId;
    if (!recipientId || (category === "request" && recipientId === posterId)) return;
    await awardCivicPointsOnce({
      userId: recipientId,
      amount: 20,
      reason: category === "request"
        ? "Successfully helped a neighbor with their request"
        : "Successfully completed a help offer",
      eventId: `job_completed_${event.params.jobId}`,
      relatedId: event.params.jobId,
    });
  },
);

exports.syncBayanihanCalendarEvent = onDocumentUpdated(
  { document: "jobs/{jobId}", region: REGION },
  async (event) => {
    const after = event.data.after.data();
    const eventRef = db.collection("calendar_events").doc(`source_bayanihan_${event.params.jobId}`);
    const existing = await eventRef.get();
    if (!existing.exists) return;

    const jobStatus = String(after.status || "active").toLowerCase();
    if (!after.scheduledAt?.toDate || ["cancelled", "completed"].includes(jobStatus)) {
      await eventRef.update({
        status: jobStatus === "completed" ? "completed" : "cancelled",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const startAt = after.scheduledAt.toDate();
    await eventRef.update({
      title: String(after.title || "Bayanihan activity").trim().slice(0, 120),
      description: String(after.description || "").trim().slice(0, 1200),
      startAt: after.scheduledAt,
      endAt: Timestamp.fromDate(new Date(startAt.getTime() + 60 * 60 * 1000)),
      location: String(after.location || "").trim().slice(0, 200),
      status: "scheduled",
      isImportant: String(after.urgency || "").toLowerCase() === "urgent",
      organizerName: String(after.company || "Bayanihan requester").trim().slice(0, 120),
      updatedAt: FieldValue.serverTimestamp(),
    });
  },
);

async function bayanihanCaller(request) {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  const profile = snapshot.data();
  if (!snapshot.exists || !isActiveProfile(profile)) {
    throw new HttpsError("permission-denied", "An active resident account is required.");
  }
  if (canonicalRole(profile.role) !== "resident") {
    throw new HttpsError("permission-denied", "Bayanihan conversations are for resident accounts.");
  }
  if (verificationStatusForProfile(profile) !== "verified") {
    throw new HttpsError(
      "failed-precondition",
      "Resident verification is required before using Bayanihan features.",
    );
  }
  return { id: request.auth.uid, ...profile };
}

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = Date.parse(String(value));
  return Number.isFinite(parsed) ? parsed : null;
}

exports.getCommunityTrustProfile = onCall({ region: REGION }, async (request) => {
  await bayanihanCaller(request);
  const userId = requiredText(request.data?.userId, "User", 128);
  if (userId.includes("/")) {
    throw new HttpsError("invalid-argument", "A valid user ID is required.");
  }
  const userRef = db.collection("users").doc(userId);
  const reviewsRef = db.collection("user_trust").doc(userId).collection("reviews");
  const [userSnapshot, reviewsSnapshot] = await Promise.all([
    userRef.get(),
    reviewsRef.orderBy("createdAt", "desc").limit(50).get(),
  ]);

  if (!userSnapshot.exists) return { profile: null, reviews: [] };
  const user = userSnapshot.data() || {};
  if (canonicalRole(user.role) !== "resident" || !isActiveProfile(user)) {
    return { profile: null, reviews: [] };
  }

  const verified = verificationStatusForProfile(user) === "verified"
    || user.identityVerified === true
    || user.verifiedAt != null
    || user.verificationApprovedAt != null;

  let bayanihanCount = 0;
  let bayanihanSum = 0;
  let marketCount = 0;
  let marketSum = 0;

  const reviews = reviewsSnapshot.docs.map((snapshot) => {
    const review = snapshot.data() || {};
    const rating = Number(review.rating) || 0;
    const ctx = review.context === "market" ? "market" : "bayanihan";
    if (ctx === "bayanihan") {
      bayanihanCount++;
      bayanihanSum += rating;
    } else {
      marketCount++;
      marketSum += rating;
    }
    return {
      id: snapshot.id,
      reviewerName: String(review.reviewerName || "A community member").slice(0, 100),
      rating,
      comment: String(review.comment || "").slice(0, 150),
      context: ctx,
      createdAt: timestampMillis(review.createdAt),
    };
  });

  const bayanihanAvg = bayanihanCount > 0 ? (bayanihanSum / bayanihanCount) : 0;
  const marketAvg = marketCount > 0 ? (marketSum / marketCount) : 0;

  return {
    profile: {
      name: String(user.name || "Community Member").slice(0, 100),
      barangay: String(user.barangay || "").slice(0, 100),
      verificationStatus: verified ? "verified" : "not_verified",
      profilePhotoUrl: String(user.profilePhotoUrl || user.photoUrl || "").slice(0, 2048),
      bayanihanRating: bayanihanAvg,
      bayanihanRatingCount: bayanihanCount,
      marketRating: marketAvg,
      marketRatingCount: marketCount,
      createdAt: timestampMillis(user.createdAt || user.joinedAt),
    },
    reviews,
  };
});

exports.getCommunityReviewStatus = onCall({ region: REGION }, async (request) => {
  const reviewer = await bayanihanCaller(request);
  const context = String(request.data?.context || "");
  if (!["bayanihan", "market"].includes(context)) {
    throw new HttpsError("invalid-argument", "Choose a valid review type.");
  }
  const sourceId = requiredText(request.data?.sourceId, "Interaction", 300);
  const targetUserId = requiredText(request.data?.targetUserId, "Member", 128);
  if (sourceId.includes("/") || targetUserId.includes("/")) {
    throw new HttpsError("invalid-argument", "A valid interaction and member are required.");
  }
  const reference = db.collection("user_trust").doc(targetUserId)
    .collection("reviews").doc(reviewId(context, sourceId, reviewer.id));
  return { rated: (await reference.get()).exists };
});

exports.submitCommunityRating = onCall({ region: REGION }, async (request) => {
  const reviewer = await bayanihanCaller(request);
  if (isResidentRestricted(reviewer)) {
    throw new HttpsError("permission-denied", "Account Restricted. Please contact your barangay office for assistance.");
  }
  const context = String(request.data?.context || "");
  if (!["bayanihan", "market"].includes(context)) {
    throw new HttpsError("invalid-argument", "Choose a valid review type.");
  }
  const sourceId = requiredText(request.data?.sourceId, "Interaction", 300);
  const targetUserId = requiredText(request.data?.targetUserId, "Member", 128);
  const rating = request.data?.rating;
  const comment = request.data?.comment;
  if (sourceId.includes("/") || targetUserId.includes("/") || reviewer.id === targetUserId) {
    throw new HttpsError("invalid-argument", "A valid interaction and member are required.");
  }
  if (typeof rating !== "number" || !Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new HttpsError("invalid-argument", "Choose a rating from 1 to 5.");
  }
  if (typeof comment !== "string" || comment.trim().length > 150) {
    throw new HttpsError("invalid-argument", "Keep your review within 150 characters.");
  }

  const conversationRef = db.collection(context === "bayanihan"
    ? "bayanihan_conversations" : "marketplace_conversations").doc(sourceId);
  const targetRef = db.collection("users").doc(targetUserId);
  const reviewRef = db.collection("user_trust").doc(targetUserId)
    .collection("reviews").doc(reviewId(context, sourceId, reviewer.id));
  return db.runTransaction(async (transaction) => {
    const [conversationSnapshot, targetSnapshot, existingReview] = await Promise.all([
      transaction.get(conversationRef),
      transaction.get(targetRef),
      transaction.get(reviewRef),
    ]);
    if (!canReviewInteraction(context, conversationSnapshot.data(), reviewer.id, targetUserId)) {
      throw new HttpsError("failed-precondition", "Only participants in completed interactions can review each other.");
    }
    const target = targetSnapshot.data();
    if (!targetSnapshot.exists || canonicalRole(target.role) !== "resident" || !isActiveProfile(target)) {
      throw new HttpsError("failed-precondition", "This member is unavailable for reviews.");
    }
    if (existingReview.exists) return { rated: true, alreadySubmitted: true };
    transaction.create(reviewRef, {
      reviewerUid: reviewer.id,
      reviewerName: String(reviewer.name || "Community member").slice(0, 100),
      rating,
      comment: comment.trim(),
      context,
      sourceId,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { rated: true, alreadySubmitted: false };
  });
});

exports.confirmMarketplaceTrade = onCall({ region: REGION }, async (request) => {
  const actor = await bayanihanCaller(request);
  const conversationId = requiredText(request.data?.conversationId, "Conversation", 300);
  if (conversationId.includes("/")) {
    throw new HttpsError("invalid-argument", "A valid conversation is required.");
  }
  const reference = db.collection("marketplace_conversations").doc(conversationId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) throw new HttpsError("not-found", "Conversation not found.");
    const conversation = snapshot.data();
    if (![conversation.buyerId, conversation.sellerId].includes(actor.id)) {
      throw new HttpsError("permission-denied", "Only the buyer or seller can confirm this handoff.");
    }
    if (conversation.status === "completed") return { completed: true };
    const confirmation = marketConfirmation(conversation, actor.id);
    if (!confirmation) {
      throw new HttpsError("failed-precondition", "The seller must accept the conversation first.");
    }
    if (conversation[confirmation.ownField]) {
      return { completed: false, waitingForOther: true };
    }
    const completed = confirmation.otherConfirmed;
    transaction.update(reference, {
      [confirmation.ownField]: FieldValue.serverTimestamp(),
      ...(completed ? { status: "completed", completedAt: FieldValue.serverTimestamp() } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { completed, waitingForOther: !completed };
  });
});

function conversationIdFor(requestId, helperId) {
  return `${String(requestId).replace(/[^A-Za-z0-9_-]/g, "_")}_${helperId}`;
}

function notificationRecord({ userId, type, title, message, requestId, conversationId }) {
  return {
    userId,
    type,
    title,
    message,
    referenceId: conversationId || requestId,
    navigation: {
      route: "/bayanihan-messages",
      requestId: requestId || "",
      conversationId: conversationId || "",
    },
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  };
}

async function sendUserPush(userId, { type, title, message, requestId, conversationId }) {
  try {
    const user = await db.collection("users").doc(userId).get();
    const token = String(user.data()?.fcmToken || "");
    if (!token) return;
    await getMessaging().send({
      token,
      notification: { title: String(title).slice(0, 120), body: String(message).slice(0, 240) },
      data: {
        type,
        route: "/bayanihan-messages",
        requestId: requestId || "",
        conversationId: conversationId || "",
      },
      android: { priority: "high" },
    });
  } catch (error) {
    console.error("Bayanihan push notification failed", { userId, type, error: error.message });
  }
}

exports.createBayanihanOffer = onCall({ region: REGION }, async (request) => {
  const helper = await bayanihanCaller(request);
  if (isResidentRestricted(helper)) {
    throw new HttpsError("permission-denied", "Account Restricted. Please contact your barangay office for assistance.");
  }
  const requestId = requiredText(request.data?.requestId, "Request", 180);
  const initialMessage = requiredText(request.data?.initialMessage, "Initial message", 1000);
  const availability = String(request.data?.availability || "").trim().slice(0, 240);
  const conversationId = conversationIdFor(requestId, helper.id);
  const jobRef = db.collection("jobs").doc(requestId);
  const offerRef = jobRef.collection("interests").doc(helper.id);
  const conversationRef = db.collection("bayanihan_conversations").doc(conversationId);
  let requesterId = "";
  let requestTitle = "Help request";

  await db.runTransaction(async (transaction) => {
    const [jobSnapshot, existingOffer, existingConversation] = await Promise.all([
      transaction.get(jobRef),
      transaction.get(offerRef),
      transaction.get(conversationRef),
    ]);
    if (!jobSnapshot.exists) throw new HttpsError("not-found", "This help request no longer exists.");
    const job = jobSnapshot.data();
    requesterId = String(job.posterId || "");
    requestTitle = String(job.title || "Help request");
    if (String(job.category || "").toLowerCase() !== "request") {
      throw new HttpsError("failed-precondition", "Offers can only be sent to help requests.");
    }
    if (requesterId === helper.id) {
      throw new HttpsError("failed-precondition", "You cannot offer help on your own request.");
    }
    if (String(job.status || "active").toLowerCase() !== "active") {
      throw new HttpsError("failed-precondition", "This request is no longer accepting offers.");
    }
    if (existingOffer.exists || existingConversation.exists) {
      throw new HttpsError("already-exists", "You already offered help for this request.");
    }
    const requesterSnapshot = await transaction.get(db.collection("users").doc(requesterId));
    const requesterData = requesterSnapshot.data() || {};
    const requesterName = String(requesterData.name || job.company || "Requester");
    const requesterPhotoUrl = String(requesterData.profilePhotoUrl || requesterData.photoUrl || "");
    const helperPhotoUrl = String(helper.profilePhotoUrl || helper.photoUrl || "");
    const now = FieldValue.serverTimestamp();
    transaction.create(offerRef, {
      requestId,
      requesterId,
      helperId: helper.id,
      volunteerId: helper.id,
      volunteerName: String(helper.name || "Helper"),
      requesterName,
      requesterPhotoUrl,
      volunteerPhotoUrl: helperPhotoUrl,
      initialMessage,
      availability,
      conversationId,
      status: "pending",
      createdAt: now,
      timestamp: now,
      updatedAt: now,
    });
    transaction.create(conversationRef, {
      schemaVersion: 1,
      requestId,
      offerId: helper.id,
      requesterId,
      helperId: helper.id,
      participants: [requesterId, helper.id],
      requesterName,
      helperName: String(helper.name || "Helper"),
      requesterPhotoUrl,
      helperPhotoUrl,
      requestTitle,
      initialMessage,
      availability,
      status: "pending",
      lastMessage: initialMessage,
      lastMessageAt: now,
      requesterUnreadCount: 1,
      helperUnreadCount: 0,
      createdAt: now,
      updatedAt: now,
    });
    transaction.create(conversationRef.collection("messages").doc("initial-offer"), {
      senderId: helper.id,
      text: initialMessage,
      kind: "initial_offer",
      sentAt: now,
    });
    transaction.set(
      db.collection("notifications").doc(`bayanihan_offer_${conversationId}`),
      notificationRecord({
        userId: requesterId,
        type: "bayanihan_new_offer",
        title: "New help offer",
        message: `${String(helper.name || "A resident")} offered to help with \"${requestTitle}\".`,
        requestId,
        conversationId,
      }),
    );
  });
  sendUserPush(requesterId, {
    type: "bayanihan_new_offer",
    title: "New help offer",
    message: `${String(helper.name || "A resident")} offered to help with \"${requestTitle}\".`,
    requestId,
    conversationId,
  }).catch((err) => {
    console.error("Push notification failed for new offer", err);
  });
  return { conversationId };
});

async function transitionOffer(request, targetStatus) {
  const actor = await bayanihanCaller(request);
  const conversationId = requiredText(request.data?.conversationId, "Conversation", 300);
  const reason = targetStatus === "declined"
    ? requiredText(request.data?.reason, "Reason", 240)
    : "";
  const conversationRef = db.collection("bayanihan_conversations").doc(conversationId);
  let recipientId = "";
  let requestId = "";
  let requestTitle = "Help request";
  await db.runTransaction(async (transaction) => {
    const conversationSnapshot = await transaction.get(conversationRef);
    if (!conversationSnapshot.exists) throw new HttpsError("not-found", "Conversation not found.");
    const conversation = conversationSnapshot.data();
    requestId = String(conversation.requestId || "");
    requestTitle = String(conversation.requestTitle || "Help request");
    if (conversation.requesterId !== actor.id) {
      throw new HttpsError("permission-denied", "Only the requester can respond to this offer.");
    }
    if (conversation.status !== "pending") {
      throw new HttpsError("failed-precondition", "This offer has already been reviewed.");
    }
    const jobRef = db.collection("jobs").doc(requestId);
    const offerRef = jobRef.collection("interests").doc(String(conversation.offerId));
    const jobSnapshot = await transaction.get(jobRef);
    if (!jobSnapshot.exists || jobSnapshot.data().posterId !== actor.id) {
      throw new HttpsError("failed-precondition", "The help request is unavailable.");
    }
    const job = jobSnapshot.data();
    const calendarEventRef = db.collection("calendar_events").doc(`source_bayanihan_${requestId}`);
    const calendarEventSnapshot = targetStatus === "active" && job.scheduledAt
      ? await transaction.get(calendarEventRef)
      : null;
    if (String(job.status || "active").toLowerCase() !== "active") {
      throw new HttpsError("failed-precondition", "The request is already closed.");
    }
    if (targetStatus === "active") {
      const needed = Math.max(1, Number(job.helpersNeeded || 1));
      const accepted = Math.max(0, Number(job.acceptedHelperCount || 0));
      if (accepted >= needed) {
        throw new HttpsError("failed-precondition", "This request already has enough helpers.");
      }
      transaction.update(jobRef, {
        helpersNeeded: needed,
        acceptedHelperCount: FieldValue.increment(1),
        acceptedHelperIds: FieldValue.arrayUnion(conversation.helperId),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (job.scheduledAt) {
        const startAt = job.scheduledAt.toDate();
        const calendarPayload = {
          id: calendarEventRef.id,
          title: String(job.title || requestTitle).slice(0, 120),
          description: String(job.description || "").slice(0, 1200),
          startAt: job.scheduledAt,
          endAt: Timestamp.fromDate(new Date(startAt.getTime() + 60 * 60 * 1000)),
          allDay: false,
          category: "bayanihan",
          location: String(job.location || "").slice(0, 200),
          createdBy: String(job.posterId || actor.id),
          sourceType: "bayanihan",
          sourceId: requestId,
          visibility: "private",
          targetBarangay: "",
          targetUserIds: FieldValue.arrayUnion(actor.id, conversation.helperId),
          audienceKeys: FieldValue.arrayUnion(`user:${actor.id}`, `user:${conversation.helperId}`),
          status: "scheduled",
          isImportant: String(job.urgency || "").toLowerCase() === "urgent",
          organizerName: String(job.company || actor.name || "Bayanihan requester").slice(0, 120),
          updatedAt: FieldValue.serverTimestamp(),
          ...(calendarEventSnapshot?.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
        };
        transaction.set(calendarEventRef, calendarPayload, { merge: true });
      }
    }
    const now = FieldValue.serverTimestamp();
    transaction.update(offerRef, {
      status: targetStatus === "active" ? "accepted" : "declined",
      declineReason: reason || FieldValue.delete(),
      respondedAt: now,
      reviewedAt: now,
      updatedAt: now,
    });
    transaction.update(conversationRef, {
      status: targetStatus,
      declineReason: reason || FieldValue.delete(),
      activatedAt: targetStatus === "active" ? now : FieldValue.delete(),
      closedAt: targetStatus === "declined" ? now : FieldValue.delete(),
      archivedAt: targetStatus === "declined" ? now : FieldValue.delete(),
      updatedAt: now,
    });
    recipientId = String(conversation.helperId);
    const accepted = targetStatus === "active";
    transaction.set(
      db.collection("notifications").doc(`bayanihan_${targetStatus}_${conversationId}`),
      notificationRecord({
        userId: recipientId,
        type: accepted ? "bayanihan_offer_accepted" : "bayanihan_offer_declined",
        title: accepted ? "Help offer accepted" : "Help offer declined",
        message: accepted
          ? `${String(actor.name || "The requester")} accepted your offer. You can now message each other.`
          : `Your offer for \"${requestTitle}\" was declined. Reason: ${reason}`,
        requestId,
        conversationId,
      }),
    );
  });
  const accepted = targetStatus === "active";
  sendUserPush(recipientId, {
    type: accepted ? "bayanihan_offer_accepted" : "bayanihan_offer_declined",
    title: accepted ? "Help offer accepted" : "Help offer declined",
    message: accepted
      ? `${String(actor.name || "The requester")} accepted your offer. You can now message each other.`
      : `Your offer for \"${requestTitle}\" was declined. Reason: ${reason}`,
    requestId,
    conversationId,
  }).catch((err) => {
    console.error("Push notification failed for offer transition", err);
  });
  return { status: targetStatus };
}

exports.acceptBayanihanOffer = onCall(
  { region: REGION },
  (request) => transitionOffer(request, "active"),
);
exports.declineBayanihanOffer = onCall(
  { region: REGION },
  (request) => transitionOffer(request, "declined"),
);

exports.withdrawBayanihanHelp = onCall({ region: REGION }, async (request) => {
  const helper = await bayanihanCaller(request);
  const conversationId = requiredText(request.data?.conversationId, "Conversation", 300);
  const reason = requiredText(request.data?.reason, "Reason", 240);
  const conversationRef = db.collection("bayanihan_conversations").doc(conversationId);
  let requesterId = "";
  let requestId = "";
  let requestTitle = "Help request";
  let wasActive = false;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(conversationRef);
    if (!snapshot.exists) throw new HttpsError("not-found", "Conversation not found.");
    const conversation = snapshot.data();
    if (conversation.helperId !== helper.id) {
      throw new HttpsError("permission-denied", "Only the helper can withdraw this offer.");
    }
    if (!["pending", "active"].includes(conversation.status)) {
      throw new HttpsError("failed-precondition", "This help relationship is already closed.");
    }
    wasActive = conversation.status === "active";
    requesterId = String(conversation.requesterId);
    requestId = String(conversation.requestId);
    requestTitle = String(conversation.requestTitle || "Help request");
    const jobRef = db.collection("jobs").doc(requestId);
    const offerRef = jobRef.collection("interests").doc(String(conversation.offerId));
    const jobSnapshot = await transaction.get(jobRef);
    const calendarEventRef = db.collection("calendar_events").doc(`source_bayanihan_${requestId}`);
    const calendarEventSnapshot = wasActive
      ? await transaction.get(calendarEventRef)
      : null;
    const now = FieldValue.serverTimestamp();
    transaction.update(offerRef, { status: "withdrawn", withdrawReason: reason, updatedAt: now });
    transaction.update(conversationRef, {
      status: "withdrawn",
      withdrawReason: reason,
      closedAt: now,
      archivedAt: now,
      updatedAt: now,
    });
    if (wasActive && jobSnapshot.exists) {
      const currentCount = Math.max(
        0,
        Number(jobSnapshot.data().acceptedHelperCount || 0),
      );
      transaction.update(jobRef, {
        acceptedHelperCount: Math.max(0, currentCount - 1),
        acceptedHelperIds: FieldValue.arrayRemove(helper.id),
        updatedAt: now,
      });
      if (calendarEventSnapshot?.exists) {
        transaction.update(calendarEventRef, {
          targetUserIds: FieldValue.arrayRemove(helper.id),
          audienceKeys: FieldValue.arrayRemove(`user:${helper.id}`),
          updatedAt: now,
        });
      }
    }
    transaction.set(
      db.collection("notifications").doc(`bayanihan_withdrawn_${conversationId}`),
      notificationRecord({
        userId: requesterId,
        type: "bayanihan_helper_withdrew",
        title: "Helper withdrew",
        message: `${String(helper.name || "A helper")} withdrew from \"${requestTitle}\". Reason: ${reason}`,
        requestId,
        conversationId,
      }),
    );
  });
  sendUserPush(requesterId, {
    type: "bayanihan_helper_withdrew",
    title: "Helper withdrew",
    message: `${String(helper.name || "A helper")} withdrew from \"${requestTitle}\". Reason: ${reason}`,
    requestId,
    conversationId,
  }).catch((err) => {
    console.error("Push notification failed for helper withdraw", err);
  });
  return { status: "withdrawn" };
});

exports.markBayanihanConversationRead = onCall({ region: REGION }, async (request) => {
  const actor = await bayanihanCaller(request);
  const conversationId = requiredText(request.data?.conversationId, "Conversation", 300);
  const ref = db.collection("bayanihan_conversations").doc(conversationId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new HttpsError("not-found", "Conversation not found.");
    const conversation = snapshot.data();
    if (![conversation.requesterId, conversation.helperId].includes(actor.id)) {
      throw new HttpsError("permission-denied", "You cannot access this conversation.");
    }
    transaction.update(ref, {
      [actor.id === conversation.requesterId ? "requesterUnreadCount" : "helperUnreadCount"]: 0,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { read: true };
});

exports.closeBayanihanRequest = onCall({ region: REGION }, async (request) => {
  const requester = await bayanihanCaller(request);
  const requestId = requiredText(request.data?.requestId, "Request", 180);
  const outcome = String(request.data?.outcome || "").toLowerCase();
  if (!["completed", "cancelled"].includes(outcome)) {
    throw new HttpsError("invalid-argument", "Choose completed or cancelled.");
  }
  const jobRef = db.collection("jobs").doc(requestId);
  const conversationsQuery = db.collection("bayanihan_conversations")
    .where("requestId", "==", requestId);
  const closedConversations = [];
  const acceptedHelpers = [];
  await db.runTransaction(async (transaction) => {
    // Firestore can retry this callback; keep result collections retry-safe.
    closedConversations.length = 0;
    acceptedHelpers.length = 0;
    const jobSnapshot = await transaction.get(jobRef);
    if (!jobSnapshot.exists || jobSnapshot.data().posterId !== requester.id) {
      throw new HttpsError("permission-denied", "Only the requester can close this request.");
    }
    if (String(jobSnapshot.data().status || "active").toLowerCase() !== "active") {
      throw new HttpsError("failed-precondition", "This request is already closed.");
    }
    const conversations = await transaction.get(conversationsQuery);
    const calendarEventRef = db.collection("calendar_events").doc(`source_bayanihan_${requestId}`);
    const calendarEventSnapshot = await transaction.get(calendarEventRef);
    const now = FieldValue.serverTimestamp();
    transaction.update(jobRef, {
      status: outcome === "completed" ? "Completed" : "Cancelled",
      completedAt: outcome === "completed" ? now : FieldValue.delete(),
      cancelledAt: outcome === "cancelled" ? now : FieldValue.delete(),
      updatedAt: now,
    });
    if (calendarEventSnapshot.exists) {
      transaction.update(calendarEventRef, {
        status: outcome === "completed" ? "completed" : "cancelled",
        updatedAt: now,
      });
    }
    for (const document of conversations.docs) {
      const conversation = document.data();
      if (!["pending", "active"].includes(conversation.status)) continue;
      // Pending offers were never accepted and must not become reviewable.
      const finalStatus = outcome === "completed" && conversation.status === "pending"
        ? "cancelled" : outcome;
      const notificationTitle = finalStatus === "completed"
        ? "Request completed" : outcome === "completed" ? "Offer closed" : "Request cancelled";
      const notificationMessage = finalStatus === "completed"
        ? `\"${String(conversation.requestTitle || "The request")}\" was completed. Your conversation is archived.`
        : outcome === "completed"
          ? `\"${String(conversation.requestTitle || "The request")}\" was completed without your offer being accepted.`
          : `\"${String(conversation.requestTitle || "The request")}\" was cancelled.`;
      const notificationType = finalStatus === "completed"
        ? "bayanihan_request_completed"
        : outcome === "completed" ? "bayanihan_offer_closed" : "bayanihan_request_cancelled";
      const closedConversation = {
        id: document.id,
        ...conversation,
        notificationTitle,
        notificationMessage,
        notificationType,
      };
      closedConversations.push(closedConversation);
      if (conversation.status === "active") {
        acceptedHelpers.push(String(conversation.helperId));
      }
      transaction.update(document.ref, {
        status: finalStatus,
        closedAt: now,
        archivedAt: now,
        completedAt: finalStatus === "completed" ? now : FieldValue.delete(),
        updatedAt: now,
      });
      transaction.update(jobRef.collection("interests").doc(String(conversation.offerId)), {
        status: finalStatus,
        updatedAt: now,
      });
      transaction.set(
        db.collection("notifications").doc(`bayanihan_${outcome}_${document.id}`),
        notificationRecord({
          userId: conversation.helperId,
          type: notificationType,
          title: notificationTitle,
          message: notificationMessage,
          requestId,
          conversationId: document.id,
        }),
      );
    }
  });
  if (outcome === "completed") {
    await Promise.all(acceptedHelpers.map((helperId) => awardCivicPointsOnce({
      userId: helperId,
      amount: 20,
      reason: "Successfully helped a neighbor with their request",
      eventId: `job_completed_${requestId}_${helperId}`,
      relatedId: requestId,
    })));
  }
  await Promise.all(closedConversations.map((conversation) => {
    return sendUserPush(String(conversation.helperId), {
      type: conversation.notificationType,
      title: conversation.notificationTitle,
      message: conversation.notificationMessage,
      requestId,
      conversationId: conversation.id,
    });
  }));
  return { status: outcome, conversationsClosed: closedConversations.length };
});

exports.onBayanihanMessageCreated = onDocumentCreated(
  { document: "bayanihan_conversations/{conversationId}/messages/{messageId}", region: REGION },
  async (event) => {
    const message = event.data?.data();
    if (!message || message.kind === "initial_offer") return;
    const conversationId = event.params.conversationId;
    const conversationRef = db.collection("bayanihan_conversations").doc(conversationId);
    let recipientId = "";
    let requestId = "";
    let requestTitle = "Help request";
    let senderName = "A resident";
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(conversationRef);
      if (!snapshot.exists) return;
      const conversation = snapshot.data();
      if (!["active", "pending"].includes(conversation.status)) return;
      const senderId = String(message.senderId || "");
      if (![conversation.requesterId, conversation.helperId].includes(senderId)) return;
      const senderIsRequester = senderId === conversation.requesterId;
      recipientId = String(senderIsRequester ? conversation.helperId : conversation.requesterId);
      senderName = String(senderIsRequester ? conversation.requesterName : conversation.helperName);
      requestId = String(conversation.requestId || "");
      requestTitle = String(conversation.requestTitle || "Help request");
      transaction.update(conversationRef, {
        lastMessage: String(message.text || "").slice(0, 1000),
        lastMessageAt: message.sentAt || FieldValue.serverTimestamp(),
        [senderIsRequester ? "helperUnreadCount" : "requesterUnreadCount"]: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        db.collection("notifications").doc(
          `bayanihan_message_${conversationId}_${event.params.messageId}`,
        ),
        notificationRecord({
          userId: recipientId,
          type: "bayanihan_new_message",
          title: requestTitle,
          message: `${senderName}: ${String(message.text || "").slice(0, 180)}`,
          requestId,
          conversationId,
        }),
      );
    });
    if (recipientId) {
      await sendUserPush(recipientId, {
        type: "bayanihan_new_message",
        title: requestTitle,
        message: `${senderName}: ${String(message.text || "").slice(0, 180)}`,
        requestId,
        conversationId,
      });
    }
  },
);

const ASSISTANT_SYSTEM_PROMPT = `You are the E-SUGID in-app guide for the Municipality of Barili, Cebu.
Answer only from the supplied GROUNDING DATA and APP ROUTES. Grounding is retrieved from current E-SUGID records, the signed-in user's authorized records, or a named verified source.

Rules:
- Answer in plain, concise, friendly language suitable for people with limited technical literacy.
- Detect the language used by the user and answer in that language. If the user writes in Cebuano/Bisaya or mixes Bisaya and English, answer in natural, simple Cebuano/Bisaya. Do not translate official E-SUGID page names or button labels unless also giving their exact UI label.
- Give short step-by-step instructions when useful.
- Answer the question first, then mention the exact app path when useful.
- Use the supplied recommended action when it directly helps. Never substitute a broad parent page for an available exact child page.
- Never claim that you completed, submitted, approved, or changed anything.
- Never invent or infer a person, office, phone number, address, schedule, announcement, event, status, destination, or Barili fact. If grounding cannot verify a requested fact, say: "I couldn't verify that information from the available E-SUGID/Barili sources."
- Do not provide legal, medical, financial, or emergency-response advice. For immediate danger, tell the user to contact emergency services and recommend the hotlines action.
- Respect the supplied account role. Resident-only features must not be presented as available to staff or organization accounts.
- If the question is unrelated to E-SUGID or Barili community services, politely say you can only help with E-SUGID.
- For multi-part safety questions, distinguish immediate danger from non-emergency concern reporting and prioritize the urgent action.
- Keep the answer brief unless the user explicitly requests detail.

Return only JSON matching the requested response schema.`;

async function assistantCaller(request) {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  if (!snapshot.exists) {
    throw new HttpsError("permission-denied", "A valid E-SUGID account is required.");
  }
  return { id: request.auth.uid, ...snapshot.data() };
}

async function enforceAssistantRateLimit(userId) {
  const reference = db.collection("_assistant_rate_limits").doc(userId);
  const now = Date.now();
  const windowLengthMs = 10 * 60 * 1000;
  const maximumRequests = 20;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() || {};
    const windowStartedAt = Number(data.windowStartedAt || 0);
    const isCurrentWindow = now - windowStartedAt < windowLengthMs;
    const requestCount = isCurrentWindow ? Number(data.requestCount || 0) : 0;
    if (requestCount >= maximumRequests) {
      throw new HttpsError(
        "resource-exhausted",
        "You have asked several questions. Please wait a few minutes and try again.",
      );
    }
    transaction.set(reference, {
      windowStartedAt: isCurrentWindow ? windowStartedAt : now,
      requestCount: requestCount + 1,
      lastRequestAt: FieldValue.serverTimestamp(),
    });
  });
}

function assistantHistory(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(-6).flatMap((entry) => {
    const role = entry?.role === "assistant" ? "model" : "user";
    const text = String(entry?.text || "").trim().slice(0, 600);
    return text ? [{ role, parts: [{ text }] }] : [];
  });
}

const ASSISTANT_SOURCES = [
  "navigation",
  "municipal_officials",
  "barangay_officials",
  "announcements",
  "announcement_comparison",
  "calendar",
  "concern_file",
  "concern_process",
  "concern_status",
  "concern_drafts",
  "emergency_alerts",
  "emergency_hotlines",
  "bayanihan",
  "barili_knowledge",
  "explore",
  "profile",
  "resident_review",
  "unknown",
];

async function requestAssistantModel(systemPrompt, contents, schema, maxOutputTokens) {
  const endpoint =
    "https://generativelanguage.googleapis.com/v1beta/models/" +
    "gemini-3.5-flash-lite:generateContent";
  let response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY.value(),
      },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents,
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens,
          responseMimeType: "application/json",
          responseSchema: schema,
        },
      }),
      signal: AbortSignal.timeout(18000),
    });
  } catch (error) {
    console.error("E-SUGID assistant model request failed", {
      name: error?.name,
      message: String(error?.message || "Request failed").slice(0, 160),
    });
    throw new HttpsError("unavailable", "The assistant is temporarily unavailable.");
  }
  if (!response.ok) {
    console.error("Gemini API rejected assistant request", { status: response.status });
    if (response.status === 429) {
      throw new HttpsError("resource-exhausted", "The assistant is busy. Try again shortly.");
    }
    throw new HttpsError("unavailable", "The assistant is temporarily unavailable.");
  }
  try {
    const payload = await response.json();
    const text = (payload.candidates?.[0]?.content?.parts || [])
      .map((part) => String(part.text || ""))
      .join("")
      .trim();
    return JSON.parse(text);
  } catch (error) {
    console.error("Gemini returned invalid assistant JSON", { name: error?.name });
    throw new HttpsError("internal", "The assistant returned an invalid response.");
  }
}

async function classifyAssistantIntent(question, history, role) {
  const known = inferKnownIntent(question, history);
  if (known) return { ...known, matchedBy: "route_registry" };
  const routes = routeContextForRole(role);
  const result = await requestAssistantModel(
    `Classify an E-SUGID or Barili question before retrieval. Use conversation context for follow-ups.
Choose one source and the most exact allowed action. Do not answer the question.
Allowed routes: ${JSON.stringify(routes)}`,
    [
      ...assistantHistory(history),
      { role: "user", parts: [{ text: question }] },
    ],
    {
      type: "OBJECT",
      required: ["source", "action", "query", "position", "category"],
      properties: {
        source: { type: "STRING", enum: ASSISTANT_SOURCES },
        action: { type: "STRING", enum: [...ASSISTANT_ACTIONS] },
        query: { type: "STRING" },
        position: { type: "STRING" },
        category: { type: "STRING" },
      },
    },
    160,
  );
  const source = ASSISTANT_SOURCES.includes(result.source) ? result.source : "unknown";
  const action = isActionAllowed(result.action, role) ? result.action : "none";
  return {
    source,
    action,
    matchedBy: "language_model",
    entities: {
      query: String(result.query || "").trim().slice(0, 100),
      position: String(result.position || "").trim().slice(0, 80),
      category: String(result.category || "").trim().slice(0, 80),
    },
  };
}

function assistantTimestamp(value) {
  if (typeof value?.toMillis === "function") return value.toMillis();
  const parsed = Date.parse(String(value || ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function assistantBarangay(profile) {
  return String(profile.barangay || profile.barangayName || "").trim();
}

function assistantRecordList(snapshot, fields) {
  return snapshot.docs.map((doc) => ({ id: doc.id, ...cleanPublicRecord(doc.data(), fields) }));
}

function assistantUnavailable(source, sourceName, message) {
  return { source, sourceName, verified: false, records: [], message };
}

async function retrieveMunicipalOfficials(intent) {
  const position = String(intent.entities?.position || "").trim();
  const snapshot = await db.collection("municipal_officials").limit(40).get();
  const liveRecords = snapshot.docs
    .map((doc) => canonicalOfficialRecord(doc.id, doc.data()))
    .filter((item) => item.isCurrent && item.name && item.position);
  const matchingLiveRecords = liveRecords.filter((item) =>
    officialMatchesPosition(item, position));
  const usedLiveRecords = matchingLiveRecords.length > 0;
  const records = usedLiveRecords ? matchingLiveRecords :
    BUILT_IN_MUNICIPAL_OFFICIALS.filter((item) =>
      officialMatchesPosition(item, position));
  return records.length ? {
    source: intent.source,
    sourceName: usedLiveRecords ?
      "E-SUGID Municipal Officials" :
      "E-SUGID built-in Municipal Officials directory",
    verified: true,
    records,
  } : assistantUnavailable(
    intent.source,
    "E-SUGID Municipal Officials",
    "No current matching official is stored in the live officials collection.",
  );
}

async function retrieveBarangayOfficials(intent, profile) {
  const barangayId = String(effectiveBarangayId(profile) || "").trim();
  const barangay = canonicalBarangayName(assistantBarangay(profile));
  if (!barangayId && !barangay) {
    return assistantUnavailable(intent.source, "E-SUGID account profile", "No barangay is assigned to this account.");
  }
  const profiles = barangayId && barangay ?
    await profilesForBarangay(barangayId, barangay) :
    (await db.collection("users")
      .where(barangayId ? "barangayId" : "barangay", "==", barangayId || barangay)
      .limit(50).get()).docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const records = profiles.flatMap((data) => {
    const role = canonicalRole(data.role);
    if (!BARANGAY_ROLES.has(role) || !isActiveProfile(data)) return [];
    const rolePosition = role === "barangay_captain" ? "Barangay Captain" :
      role === "barangay_vice_captain" ? "Barangay Vice Captain" :
        role === "barangay_secretary" ? "Barangay Secretary" : "Barangay Councilor";
    return [canonicalOfficialRecord(data.id, {
      ...data,
      position: data.position || data.positionTitle || rolePosition,
      isCurrent: true,
    })];
  });
  const position = String(intent.entities?.position || "").trim();
  const matching = records.filter((item) => officialMatchesPosition(item, position));
  return matching.length ? {
    source: intent.source,
    sourceName: "E-SUGID authorized barangay accounts",
    verified: true,
    barangay,
    records: matching,
  } : assistantUnavailable(
    intent.source,
    "E-SUGID authorized barangay accounts",
    "No current matching barangay official is available for the signed-in user's barangay.",
  );
}

async function retrieveAnnouncements(intent, profile) {
  const barangay = assistantBarangay(profile);
  const references = [
    db.collection("announcement_feeds").doc("municipality:barili").collection("posts").limit(12).get(),
  ];
  if (barangay) {
    references.push(
      db.collection("announcement_feeds").doc(`barangay:${barangay}`).collection("posts").limit(12).get(),
    );
  }
  const snapshots = await Promise.all(references);
  const records = snapshots.flatMap((snapshot) => assistantRecordList(snapshot, [
    "title", "content", "category", "priority", "publisherEntityName", "createdAt", "timestamp",
  ])).sort((a, b) => assistantTimestamp(b.createdAt || b.timestamp) -
    assistantTimestamp(a.createdAt || a.timestamp)).slice(0, 6);
  return {
    source: intent.source,
    sourceName: "E-SUGID announcement feeds",
    verified: true,
    records,
    message: records.length ? "Latest visible announcements." : "No visible announcements are currently available.",
  };
}

function eventVisibleToProfile(event, profile) {
  const visibility = String(event.visibility || "public").toLowerCase();
  if (visibility === "public") return true;
  if (visibility === "private") {
    return Array.isArray(event.targetUserIds) && event.targetUserIds.includes(profile.id);
  }
  return visibility === "barangay" &&
    String(event.targetBarangay || "").toLowerCase() === assistantBarangay(profile).toLowerCase();
}

async function retrieveCalendar(intent, profile) {
  const snapshot = await db.collection("calendar_events").where(
    "startAt", ">=", Timestamp.fromDate(new Date()),
  ).orderBy("startAt").limit(40).get();
  const records = snapshot.docs.filter((doc) => {
    const data = doc.data();
    return !["cancelled", "completed"].includes(String(data.status || "").toLowerCase()) &&
      eventVisibleToProfile(data, profile);
  }).slice(0, 6).map((doc) => ({
    id: doc.id, ...cleanPublicRecord(doc.data(), [
      "title", "startAt", "endAt", "allDay", "location", "organizerName", "status",
    ])
  }));
  return {
    source: intent.source,
    sourceName: "E-SUGID Community Calendar",
    verified: true,
    records,
    message: records.length ? "Upcoming events visible to this account." : "No upcoming visible events were found.",
  };
}

async function retrieveConcerns(intent, profile) {
  const snapshot = await db.collection("submissions")
    .where("userId", "==", profile.id).limit(50).get();
  const records = assistantRecordList(snapshot, [
    "title", "category", "status", "department", "date", "submittedAt", "updatedAt",
  ]).sort((a, b) => assistantTimestamp(b.updatedAt || b.date) -
    assistantTimestamp(a.updatedAt || a.date)).slice(0, 8);
  return {
    source: intent.source,
    sourceName: "Signed-in resident's E-SUGID submissions",
    verified: true,
    records,
    message: records.length ? "Only this resident's submissions are included." : "This resident has no submitted concerns.",
  };
}

async function retrieveEmergencyContacts(intent) {
  const category = String(intent.entities?.category || "").toLowerCase();
  const snapshot = await db.collection("emergency_contacts").limit(50).get();
  const records = snapshot.docs.flatMap((doc) => {
    const data = doc.data();
    if (data.active === false) return [];
    const searchText = `${data.name || ""} ${data.category || ""}`.toLowerCase();
    if (category && category !== "emergency" && !searchText.includes(category)) return [];
    const contacts = Array.isArray(data.contactNumbers) ? data.contactNumbers : [];
    return [{
      id: doc.id,
      ...cleanPublicRecord(data, ["name", "category", "address", "updatedAt", "verifiedSource"]),
      contactNumbers: contacts.slice(0, 5).map((item) => ({
        label: String(item?.label || "").trim().slice(0, 80),
        number: String(item?.number || "").trim().slice(0, 40),
      })).filter((item) => item.number),
    }];
  });
  return records.length ? {
    source: intent.source,
    sourceName: "E-SUGID verified emergency contacts",
    verified: true,
    records,
  } : assistantUnavailable(
    intent.source,
    "E-SUGID verified emergency contacts",
    "No matching verified contact is stored in the live emergency contacts collection.",
  );
}

function alertVisibleToProfile(alert, profile) {
  const barangay = assistantBarangay(profile).toLowerCase();
  const visibility = String(alert.visibility || "public").toLowerCase();
  if (visibility === "public" || alert.targetBarangay === "All Barangays") return true;
  return String(alert.targetBarangay || "").toLowerCase() === barangay ||
    (Array.isArray(alert.targetBarangays) &&
      alert.targetBarangays.some((item) => String(item).toLowerCase() === barangay));
}

async function retrieveEmergencyAlerts(intent, profile) {
  const now = Date.now();
  const snapshot = await db.collection("alerts").limit(60).get();
  const records = snapshot.docs.filter((doc) => {
    const data = doc.data();
    const status = String(data.status || "active").toLowerCase();
    const expiresAt = assistantTimestamp(data.expiresAt);
    return data.active !== false && !["resolved", "ended", "expired", "cancelled"].includes(status) &&
      (!expiresAt || expiresAt > now) && alertVisibleToProfile(data, profile);
  }).slice(0, 8).map((doc) => ({
    id: doc.id, ...cleanPublicRecord(doc.data(), [
      "title", "message", "severity", "category", "instructions", "sourceName", "createdAt", "expiresAt",
    ])
  }));
  return {
    source: intent.source,
    sourceName: "E-SUGID Emergency Center",
    verified: true,
    records,
    message: records.length ? "Currently active alerts visible to this account." : "No active visible emergency alerts were found.",
  };
}

async function retrieveBayanihan(intent) {
  const snapshot = await db.collection("jobs").limit(60).get();
  const records = assistantRecordList(snapshot, [
    "title", "description", "category", "helpCategory", "urgency", "dateNeeded", "scheduledAt", "location", "status", "createdAt",
  ]).filter((item) => String(item.status || "active").toLowerCase() === "active")
    .sort((a, b) => assistantTimestamp(b.createdAt) - assistantTimestamp(a.createdAt))
    .slice(0, 8);
  return {
    source: intent.source,
    sourceName: "E-SUGID Bayanihan Works",
    verified: true,
    records,
    message: records.length ? "Current active help requests." : "No active help requests were found.",
  };
}

async function retrieveExplorePlace(intent) {
  const query = String(intent.entities?.query || "").trim();
  if (!query) {
    return {
      source: intent.source,
      sourceName: "E-SUGID Explore Barili",
      verified: true,
      records: [],
      message: "Explore Barili can search real places within Barili using OpenStreetMap.",
    };
  }
  const url = new URL("https://photon.komoot.io/api/");
  url.searchParams.set("q", query);
  url.searchParams.set("bbox", "123.466798,10.039378,123.600014,10.186907");
  url.searchParams.set("countrycode", "PH");
  url.searchParams.set("limit", "5");
  const response = await fetch(url, {
    headers: { "User-Agent": "E-SUGID-Functions/1.0 (Barili local discovery)" },
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) {
    return assistantUnavailable(intent.source, "OpenStreetMap via Photon", "Place lookup is temporarily unavailable.");
  }
  const payload = await response.json();
  const records = (Array.isArray(payload.features) ? payload.features : []).flatMap((feature) => {
    const coordinates = feature?.geometry?.coordinates;
    const properties = feature?.properties || {};
    const longitude = Number(coordinates?.[0]);
    const latitude = Number(coordinates?.[1]);
    if (!Number.isFinite(longitude) || !Number.isFinite(latitude) ||
      longitude < 123.466798 || longitude > 123.600014 ||
      latitude < 10.039378 || latitude > 10.186907) return [];
    const name = String(properties.name || "").trim();
    if (!name) return [];
    return [{
      name: name.slice(0, 120),
      barangay: String(properties.district || properties.locality || "").trim().slice(0, 100),
      municipality: String(properties.city || properties.county || "Barili").trim().slice(0, 100),
      latitude,
      longitude,
      source: "OpenStreetMap",
    }];
  }).slice(0, 3);
  return records.length ? {
    source: intent.source,
    sourceName: "OpenStreetMap via Photon",
    verified: true,
    records,
  } : assistantUnavailable(intent.source, "OpenStreetMap via Photon", "No matching place inside Barili was verified.");
}

async function retrieveBariliKnowledge(intent) {
  const terms = String(intent.entities?.query || "")
    .toLowerCase()
    .split(/\s+/)
    .filter((term) => term.length > 2);
  const snapshot = await db.collection("barili_knowledge").limit(30).get();
  const records = assistantRecordList(snapshot, [
    "title", "summary", "details", "category", "sourceName", "sourceUrl", "verified", "active", "updatedAt",
  ]).filter((item) => item.active !== false && item.verified === true)
    .map((item) => {
      const searchable = `${item.title || ""} ${item.summary || ""} ${item.category || ""}`.toLowerCase();
      return { item, score: terms.filter((term) => searchable.includes(term)).length };
    })
    .filter((result) => !terms.length || result.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 6)
    .map((result) => result.item);
  return records.length ? {
    source: intent.source,
    sourceName: "Verified E-SUGID Barili Knowledge",
    verified: true,
    records,
  } : assistantUnavailable(
    intent.source,
    "Verified E-SUGID Barili Knowledge",
    "No matching verified Barili knowledge record is currently available.",
  );
}

async function retrieveAssistantGrounding(intent, profile, clientContext) {
  try {
    switch (intent.source) {
      case "municipal_officials": return await retrieveMunicipalOfficials(intent);
      case "barangay_officials": return await retrieveBarangayOfficials(intent, profile);
      case "announcements": return await retrieveAnnouncements(intent, profile);
      case "calendar": return await retrieveCalendar(intent, profile);
      case "concern_status": return await retrieveConcerns(intent, profile);
      case "emergency_hotlines": return await retrieveEmergencyContacts(intent);
      case "emergency_alerts": return await retrieveEmergencyAlerts(intent, profile);
      case "bayanihan": return await retrieveBayanihan(intent);
      case "barili_knowledge": return await retrieveBariliKnowledge(intent);
      case "explore": return await retrieveExplorePlace(intent);
      case "concern_drafts": {
        const drafts = safeClientContext(clientContext);
        return {
          source: intent.source,
          sourceName: "Signed-in resident's device-local manually saved drafts",
          verified: true,
          records: [drafts],
          message: "Only drafts explicitly saved on this device are counted.",
        };
      }
      case "profile": return {
        source: intent.source,
        sourceName: "Signed-in E-SUGID profile",
        verified: true,
        records: [cleanPublicRecord(profile, [
          "name", "role", "barangay", "barangayId", "verifiedBarangayId", "verificationStatus", "accountStatus",
        ])],
      };
      case "concern_file": return {
        source: intent.source,
        sourceName: "E-SUGID concern workflow",
        verified: true,
        records: [{ path: "Concern Center > File a Concern", recipientBehavior: "E-SUGID recommends a recipient after the resident provides concern details." }],
      };
      case "concern_process": return {
        source: intent.source,
        sourceName: "E-SUGID concern workflow",
        verified: true,
        records: [{ process: ["submission is received", "assigned office reviews it", "status updates appear in My Concerns"] }],
      };
      case "announcement_comparison": return {
        source: intent.source,
        sourceName: "E-SUGID app structure",
        verified: true,
        records: [{ announcements: "Official community information in Community Bulletin", emergencyAlerts: "Urgent, active safety notices in Emergency Center" }],
      };
      case "resident_review": return {
        source: intent.source,
        sourceName: "E-SUGID permissions",
        verified: true,
        records: [{ resident: "cannot review residents", authorizedBarangayOfficial: "uses Resident Verification in the Barangay Dashboard" }],
      };
      default: return {
        source: intent.source,
        sourceName: "E-SUGID route registry",
        verified: true,
        records: routeContextForRole(canonicalRole(profile.role || "resident")),
      };
    }
  } catch (error) {
    console.error("Assistant retrieval failed", {
      source: intent.source,
      name: error?.name,
      code: error?.code,
    });
    return assistantUnavailable(intent.source, "E-SUGID live data", "The requested live data could not be loaded.");
  }
}

function assistantActionLabel(action, intent, question) {
  if (action === "none") return "";
  const isBisaya = isCebuanoQuestion(question);
  if (action === "exploreBarili" && intent.entities?.query) {
    return `View ${String(intent.entities.query).slice(0, 30)}`;
  }
  const labels = {
    announcements: "View Announcements",
    emergencyCenter: "Open Emergency Center",
    hotlines: "Emergency Hotlines",
    fileConcern: "File a Concern",
    myConcerns: "View My Concerns",
    concernDraft: "Continue Draft",
    municipalOfficials: isBisaya ? "Tan-awa ang Municipal Officials" : "View Municipal Officials",
    myBarangay: isBisaya ? "Tan-awa ang My Barangay" : "View My Barangay",
    calendar: "Open Calendar",
    exploreBarili: "Explore Barili",
    residentVerification: "Open Resident Verification",
    jobs: "Open Bayanihan Works",
    market: "Open Local Market",
    profile: "Open Profile",
    services: "Open Services",
    home: "Open Home",
    notifications: "Open Notifications",
    savedAnnouncements: "View Saved Announcements",
    barangayMap: "Open Barangay Map",
    bariliWeather: "View Barili Weather",
    myMarketListings: "Open My Listings",
    bayanihanMessages: "Open Bayanihan Messages",
  };
  return labels[action] || "Open page";
}

exports.askESugidAssistant = onCall(
  {
    region: REGION,
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 45,
    memory: "256MiB",
    maxInstances: 5,
  },
  async (request) => {
    const profile = await assistantCaller(request);
    const question = String(request.data?.question || "").trim();
    if (!question || question.length > 500) {
      throw new HttpsError(
        "invalid-argument",
        "The question must contain between 1 and 500 characters.",
      );
    }
    await enforceAssistantRateLimit(profile.id);
    const role = canonicalRole(profile.role || request.data?.role || "resident");
    const history = Array.isArray(request.data?.history) ? request.data.history : [];
    const intent = await classifyAssistantIntent(question, history, role);
    if (!isActionAllowed(intent.action, role)) intent.action = "none";
    const grounding = await retrieveAssistantGrounding(
      intent,
      profile,
      request.data?.clientContext,
    );
    const recordCount = Array.isArray(grounding.records) ? grounding.records.length : 0;
    console.info("E-SUGID assistant retrieval", {
      matchedBy: intent.matchedBy,
      intent: intent.source,
      requestedPosition: intent.entities?.position || "",
      requestedCategory: intent.entities?.category || "",
      dataSource: grounding.sourceName,
      recordCount,
      verified: grounding.verified === true,
      action: intent.action,
      fallbackReason: grounding.verified === false ?
        String(grounding.message || "unverified_or_unavailable").slice(0, 160) :
        recordCount === 0 ? "no_matching_records" : "",
    });
    const routes = routeContextForRole(role);
    let answer;
    if (["municipal_officials", "barangay_officials"].includes(intent.source)) {
      answer = groundedOfficialAnswer(
        question,
        grounding.records,
        intent.entities?.position || "",
        intent.source === "barangay_officials" ? assistantBarangay(profile) : "",
      );
    } else {
      const result = await requestAssistantModel(
        ASSISTANT_SYSTEM_PROMPT,
        [
          ...assistantHistory(history),
          {
            role: "user",
            parts: [{
              text: [
                `Account role: ${role}`,
                `Question: ${question}`,
                `APP ROUTES: ${JSON.stringify(routes)}`,
                `RECOMMENDED ACTION: ${intent.action}`,
                `GROUNDING DATA: ${JSON.stringify(grounding)}`,
              ].join("\n"),
            }],
          },
        ],
        {
          type: "OBJECT",
          required: ["answer"],
          properties: { answer: { type: "STRING" } },
        },
        360,
      );
      answer = String(result.answer || "").trim().slice(0, 900);
    }
    if (!answer) {
      throw new HttpsError("internal", "The assistant returned an empty response.");
    }
    const actionData = {};
    if (intent.action === "concernDraft") {
      const draft = safeClientContext(request.data?.clientContext);
      if (draft.latestDraftId) actionData.resourceId = draft.latestDraftId;
      if (!draft.manualDraftCount) intent.action = "myConcerns";
    }
    if (intent.action === "exploreBarili" && intent.entities?.query) {
      actionData.query = String(intent.entities.query).slice(0, 100);
    }
    return {
      answer,
      action: intent.action,
      actionLabel: assistantActionLabel(intent.action, intent, question),
      actionData,
    };
  },
);

// Directions for the resident map. The function's own service account calls
// the Routes API, so no Maps key ships in the app or needs to be stored here.
const routesCredential = applicationDefault();

async function requestGoogleRoute(body) {
  const { access_token: accessToken } = await routesCredential.getAccessToken();
  const response = await fetch(ROUTES_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${accessToken}`,
      "X-Goog-FieldMask": ROUTES_FIELD_MASK,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(10000),
  });
  const payload = await response.json().catch(() => ({}));
  if (response.ok) return payload.routes?.[0] ?? null;
  if (isUnsupportedTravelModeError(response.status, payload)) {
    throw Object.assign(new Error(payload.error?.message), { unsupportedTravelMode: true });
  }
  throw Object.assign(new Error(payload.error?.message || `Routes API ${response.status}`), {
    routesStatus: response.status,
  });
}

exports.computeBariliRoute = onCall({ region: REGION, timeoutSeconds: 30 }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const parsed = parseRouteRequest(request.data);
  if (parsed.error) throw new HttpsError("invalid-argument", parsed.error);
  try {
    return { routes: await computeModeRoutes(parsed, requestGoogleRoute) };
  } catch (error) {
    console.error("computeBariliRoute failed", {
      status: error.routesStatus,
      message: error.message,
    });
    if (error.routesStatus === 403) {
      throw new HttpsError("failed-precondition", "Directions are not enabled for this project.");
    }
    throw new HttpsError("unavailable", "The route could not be loaded.");
  }
});

// Residents follow private organizations; the list is kept on their own user
// document (readable by them, written only here) next to a follower count on
// the organization.
exports.setOrganizationFollow = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const organizationId = canonicalOrganizationId(request.data?.organizationId);
  if (!organizationId) throw new HttpsError("invalid-argument", "Choose an organization.");
  const follow = request.data?.follow === true;
  const userRef = db.collection("users").doc(uid);
  const organizationRef = db.collection("organizations").doc(organizationId);

  return db.runTransaction(async (transaction) => {
    const [userSnapshot, organizationSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(organizationRef),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Your profile could not be found.");
    }
    const currentIds = followedOrganizationIds(userSnapshot.data());
    const plan = planFollowChange({
      currentIds,
      follow,
      organization: {
        id: organizationId,
        exists: organizationSnapshot.exists,
        data: organizationSnapshot.data(),
      },
    });
    if (plan.error) throw new HttpsError(plan.code, plan.error);

    if (plan.delta !== 0) {
      transaction.update(userRef, {
        followedOrganizationIds: plan.delta > 0 ?
          FieldValue.arrayUnion(organizationId) :
          FieldValue.arrayRemove(organizationId),
      });
      if (organizationSnapshot.exists) {
        transaction.update(organizationRef, { followerCount: FieldValue.increment(plan.delta) });
      }
    }
    const previousCount = Number(organizationSnapshot.get("followerCount") || 0);
    return {
      following: follow,
      followerCount: Math.max(0, previousCount + plan.delta),
    };
  });
});

// Barangay complaints (disputes between residents). Stored with the concerns
// so existing routing, reads and status handling apply, but always private
// and routed to the barangay where the respondent lives.
exports.submitComplaint = onCall({ region: REGION }, async (request) => {
  const resident = await activeUserCaller(request);
  if (isResidentRestricted(resident)) {
    throw new HttpsError("permission-denied", "Account Restricted. Please contact your barangay office for assistance.");
  }
  if (canonicalRole(resident.role) !== "resident"
    || verificationStatusForProfile(resident) !== "verified") {
    throw new HttpsError("permission-denied", "Verified residency is required to file a complaint.");
  }
  const input = request.data || {};
  const revisionFingerprint = createHash("sha256").update(JSON.stringify(Object.keys(input).sort().map((key) => [key, input[key]]))).digest("hex");
  const id = validComplaintReference(input.id);
  if (!id) throw new HttpsError("invalid-argument", "A valid complaint reference is required.");
  const draftId = requiredText(input.draftId, "Draft ID", 160);
  const reference = db.collection("submissions").doc(id);
  const existing = await reference.get();
  let isResubmission = false;
  if (existing.exists) {
    const data = existing.data();
    if (data.userId !== resident.id && data.createdBy !== resident.id) {
      throw new HttpsError("already-exists", "This complaint reference is already in use.");
    }
    const isAwaitingInfo = ["needs_information", "awaiting_resident"].includes(data.status);
    if (data.lastResidentRevisionId === draftId && data.lastResidentRevisionFingerprint !== revisionFingerprint) throw new HttpsError("already-exists", "This revision was already saved with different details. Reopen the complaint to see the saved record.");
    if (!isAwaitingInfo && (data.draftId === draftId || data.lastResidentRevisionId === draftId)) {
      return { id, department: data.department };
    }
    if (!isAwaitingInfo) {
      throw new HttpsError("already-exists", "This complaint reference is already in use.");
    }
    isResubmission = true;
  }

  const respondentUnknown = input.respondentUnknown === true;
  const respondentName = respondentUnknown ? "" : requiredText(input.respondentName, "Respondent's name", 160);
  const respondentDescription = respondentUnknown ?
    requiredText(input.respondentDescription, "A description of the person", 300) :
    optionalText(input.respondentDescription, 300);
  const respondentAddress = requiredText(input.respondentAddress, "Where the person lives", 240);
  const relationship = pickFrom(RESPONDENT_RELATIONSHIPS, input.relationship) || "Other";
  const complaintType = pickFrom(COMPLAINT_TYPES, input.complaintType);
  if (!complaintType) throw new HttpsError("invalid-argument", "Choose the type of problem.");
  const description = requiredText(input.description, "What happened", 1000);
  if (description.length < 10) throw new HttpsError("invalid-argument", "Please describe what happened.");
  const incidentDate = requiredText(input.incidentDate, "When it happened", 120);
  const desiredOutcome = optionalText(input.desiredOutcome, 300);
  const witnesses = optionalText(input.witnesses, 300);
  const attachmentUrl = optionalText(input.attachmentUrl, 1000);
  const attachmentStoragePath = optionalText(input.attachmentStoragePath, 1000);
  const { barangay, barangayId } = selectedConcernBarangay(input);

  const now = Timestamp.now();
  const reporterName = String(resident.name || request.auth.token.name || "Resident").slice(0, 100);
  const title = `${complaintType} complaint`;

  if (isResubmission) {
    const existingData = existing.data();
    const updateData = {
      title,
      type: complaintType,
      respondentName,
      respondentAddress,
      description,
      incidentDate,
      location: respondentAddress,
      requestedAction: desiredOutcome,
      updatedAt: now,
      updatedBy: resident.id,
      status: "under_review",
      stage: "under_review",
      requestedInfoMessage: "", requestedInfoAt: null, requestedInfoBy: "",
      lastResidentRevisionId: draftId,
      lastResidentRevisionFingerprint: revisionFingerprint,
      statusHistory: FieldValue.arrayUnion({
        status: "under_review",
        action: "resident_resubmitted_complaint",
        label: "Resident Resubmitted Complaint",
        actorName: reporterName,
        note: "Resident updated and resubmitted complaint details.",
        date: now,
        performedBy: resident.id,
        performedAt: now,
        visibility: "public",
        actorType: "resident",
        actorId: resident.id,
      }),
      complaint: {
        respondentName,
        respondentUnknown,
        respondentDescription,
        respondentAddress,
        relationship,
        complaintType,
        desiredOutcome,
        witnesses,
        attachmentUrl: attachmentUrl || existingData.attachmentUrl || "",
        attachmentStoragePath: attachmentStoragePath || existingData.attachmentStoragePath || "",
      },
    };
    if (input.removeAttachment === true || input.attachmentUrl != null) {
      updateData.attachmentUrl = attachmentUrl;
      updateData.attachmentStoragePath = attachmentStoragePath || "";
    }
    await db.runTransaction(async (transaction) => {
      const latest = await transaction.get(reference);
      const previous = latest.data();
      if (previous?.lastResidentRevisionId === draftId && previous?.userId === resident.id) {
        if (previous.lastResidentRevisionFingerprint !== revisionFingerprint) throw new HttpsError("already-exists", "This revision was already saved with different details.");
        return;
      }
      if (!latest.exists || (previous.userId !== resident.id && previous.createdBy !== resident.id)
        || !["needs_information", "awaiting_resident"].includes(previous.status)) {
        throw new HttpsError("aborted", "The complaint changed. Reload it before resubmitting.");
      }
      if (!Number.isInteger(input.expectedVersion) || (previous.workflowVersion || 0) !== input.expectedVersion) throw new HttpsError("aborted", "The complaint changed. Reopen it before resubmitting.");
      if (previous.barangayId !== barangayId) throw new HttpsError("invalid-argument", "Keep the original barangay when resubmitting.");
      const retainedUrl = input.removeAttachment === true ? "" : (input.attachmentUrl ?? previous.attachmentUrl ?? "");
      const retainedPath = input.removeAttachment === true ? "" : (input.attachmentStoragePath ?? previous.attachmentStoragePath ?? "");
      transaction.update(reference, { ...updateData,
        attachmentUrl: retainedUrl, attachmentStoragePath: retainedPath,
        complaint: { ...updateData.complaint, attachmentUrl: retainedUrl, attachmentStoragePath: retainedPath },
        workflowVersion: (previous.workflowVersion || 0) + 1,
        originalSubmission: previous.originalSubmission || {
          title: previous.title, description: previous.description, complaint: previous.complaint || {},
          incidentDate: previous.incidentDate || "", attachmentUrl: previous.attachmentUrl || "",
        },
        submissionRevisions: FieldValue.arrayUnion({ description: previous.description,
          complaint: previous.complaint || {}, incidentDate: previous.incidentDate || "", revisedAt: now }),
      });
      const targetRecipient = previous.receiverAccountId || previous.recipientId;
      if (targetRecipient) transaction.set(db.collection("notifications").doc(), {
        userId: targetRecipient, type: "complaint_resubmitted", referenceId: id,
        relatedEntityType: "complaint", title: "Complaint Updated & Resubmitted",
        message: `${reporterName} provided the requested details for ${id}.`,
        status: "under_review", navigation: { route: "/complaints" }, read: false, createdAt: now,
      });
    });

    return { id, department: existingData.department || "Barangay Office" };
  }

  const barangayRoute = await barangayConcernReceiver({ barangay, barangayId });
  if (!barangayRoute) {
    throw new HttpsError("failed-precondition", "No active barangay official can receive complaints for this barangay yet.");
  }
  const submission = {
    schemaVersion: 4,
    id,
    kind: "complaint",
    title,
    description,
    category: "Barangay Complaint",
    categoryId: "barangay_complaint",
    organizationSector: "public",
    visibility: "private",
    type: complaintType,
    status: "filed",
    complaintTrackingVersion: 1,
    workflowVersion: 0,
    hearings: [],
    externalUpdates: [],
    date: now,
    submittedAt: FieldValue.serverTimestamp(),
    updatedAt: now,
    userId: resident.id,
    residentId: resident.id,
    createdBy: resident.id,
    residentName: reporterName,
    reporterName,
    submitterName: reporterName,
    reporterIds: [resident.id],
    reporterCount: 1,
    latestReportAt: now,
    barangay,
    barangayId,
    location: respondentAddress,
    incidentDate,
    requestedAction: desiredOutcome,
    anonymous: false,
    draftId,
    attachmentUrl: attachmentUrl || "",
    attachmentStoragePath: attachmentStoragePath || "",
    respondentName,
    respondentAddress,
    complaint: {
      respondentName,
      respondentUnknown,
      respondentDescription,
      respondentAddress,
      relationship,
      complaintType,
      desiredOutcome,
      witnesses,
      attachmentUrl: attachmentUrl || "",
      attachmentStoragePath: attachmentStoragePath || "",
    },
    requestedRecipientType: "barangay",
    requestedRecipientId: barangayRoute.recipientId,
    recipientId: barangayRoute.recipientId,
    recipientType: "barangay",
    receiverAccountId: barangayRoute.receiverAccountId,
    organizationId: "",
    organizationIds: [],
    organizationNames: [],
    leadOrganizationId: "",
    department: barangayRoute.displayName,
    recipientBarangayId: barangayId,
    routingStatus: "automatically_routed",
    routingReason: "",
    possibleDuplicate: false,
    possibleDuplicateIds: [],
    routingHistory: [{
      action: "routed_to_barangay", recipientId: barangayRoute.recipientId,
      recipientName: barangayRoute.displayName, actorId: "system", date: now,
    }],
    statusHistory: [{
      status: "filed",
      action: "submitted",
      note: "Complaint filed.",
      date: now,
      performedBy: resident.id,
      performedAt: now,
      actorId: resident.id,
      actorType: "resident",
      visibility: "reporter_and_handlers",
    }],
    residentResponses: [],
  };
  const batch = db.batch();
  batch.create(reference, submission);
  batch.set(db.collection("audit_logs").doc(), {
    action: "complaint_submitted",
    targetType: "submission",
    targetId: id,
    actorId: resident.id,
    actorEmail: resident.email || "",
    barangayId,
    recipientId: submission.recipientId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { id, department: submission.department, barangay, barangayId };
});

// Complaint mutations use server time, optimistic concurrency and durable retry receipts.
exports.advanceComplaintWorkflow = onCall({ region: REGION }, async (request) => {
  const started = Date.now();
  const actor = await approvedCaller(request);
  if (!["super_admin", "mayor"].includes(canonicalRole(actor.role)) && !await actorCan(actor, "concerns")) throw new HttpsError("permission-denied", "Complaint access is disabled for this office.");
  const input = request.data || {};
  const submissionId = validComplaintReference(input.submissionId);
  if (!submissionId) throw new HttpsError("invalid-argument", "A valid complaint reference is required.");
  if (!/^[a-zA-Z0-9_-]{16,80}$/.test(input.operationId || "")) throw new HttpsError("invalid-argument", "A unique operation ID is required.");
  if (!Number.isInteger(input.expectedVersion) || input.expectedVersion < 0) throw new HttpsError("invalid-argument", "Reload the complaint before updating it.");
  const ref = db.collection("submissions").doc(submissionId);
  const receiptRef = ref.collection("tracking_operations").doc(input.operationId);
  const fingerprint = createHash("sha256").update(JSON.stringify(Object.keys(input).sort().map((key) => [key, input[key]]))).digest("hex");
  const result = await db.runTransaction(async (transaction) => {
    const [snapshot, receipt] = await Promise.all([transaction.get(ref), transaction.get(receiptRef)]);
    if (!snapshot.exists) throw new HttpsError("not-found", "Complaint record not found.");
    const data = snapshot.data();
    if (!isComplaint(data)) throw new HttpsError("failed-precondition", "This workflow applies only to complaints.");
    const role = canonicalRole(actor.role);
    const barangayId = summonsBarangay(data).barangayId;
    if (!["super_admin", "mayor"].includes(role)
      && !(BARANGAY_CONCERN_ROLES.has(role) && barangayId
        && summonsBarangay({ barangayId: actor.barangayId, barangay: actor.barangay }).barangayId === barangayId)) {
      throw new HttpsError("permission-denied", "Only this barangay's officials can update this complaint.");
    }
    try {
      const previousResult = checkTrackingOperation(data, input, actor.id, fingerprint, receipt.exists ? receipt.data() : null);
      if (previousResult) return previousResult;
    } catch (error) { throw new HttpsError(error.code, error.message); }
    const now = Timestamp.now();
    let plan;
    const summonsOfficials = input.action === "issue_summons" ? await lookupSummonsOfficials(data) : undefined;
    try { plan = planTrackingUpdate(data, input, now.toDate(), { id: actor.id, name: String(actor.name || actor.email || "Barangay Official"), role, summonsOfficials }); }
    catch (error) { throw new HttpsError(error.code || "invalid-argument", error.message); }
    const recipients = [...new Set([data.userId, ...(data.reporterIds || [])].filter(userId => typeof userId === "string" && userId.trim()))];
    if (input.action === "notify_cfa" && !recipients.length) throw new HttpsError("failed-precondition", "This complaint is not linked to a resident account to notify.");
    transaction.update(ref, { ...plan.update, statusHistory: FieldValue.arrayUnion(plan.event) });
    transaction.set(db.collection("audit_logs").doc(), {
      action: `complaint_tracking_${input.action}`, targetType: "submission", targetId: submissionId,
      actorId: actor.id, actorRole: role, createdAt: now, operationId: input.operationId,
      previousStatus: data.status, newStatus: plan.update.status || data.status,
    });
    for (const userId of recipients) transaction.set(db.collection("notifications").doc(), {
      userId, type: "complaint_update", referenceId: submissionId, relatedEntityType: "complaint",
      title: plan.title, message: plan.message, status: plan.update.status || data.status,
      navigation: { route: "/complain", id: submissionId }, read: false, createdAt: now,
    });
    const response = { success: true, submissionId, newStatus: plan.update.status || data.status,
      workflowVersion: plan.update.workflowVersion, update: plan.update, event: plan.event };
    transaction.set(receiptRef, { actorId: actor.id, fingerprint, result: response, createdAt: now });
    if (recipients.length) queueWebNotification(transaction, { kind: "push", userIds: recipients,
      title: plan.title, body: plan.message, type: "complaint_update", referenceId: submissionId });
    return response;
  });
  console.info("[WEB_ACTION] Committed", { function: "advanceComplaintWorkflow", durationMs: Date.now() - started });
  return result;
});
