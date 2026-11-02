const { createHash, randomBytes, randomInt } = require("node:crypto");
const { HttpsError } = require("firebase-functions/v2/https");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { canonicalBarangayName, barangayIdFor } = require("./verification_helpers");
const {
  OTP_LIFETIME_MS, OTP_RESEND_COOLDOWN_MS, OTP_REQUEST_WINDOW_MS,
  OTP_MAX_REQUESTS_PER_WINDOW, OTP_MAX_ATTEMPTS, canonicalOtp,
  maskedEmail, otpHash, otpMatches,
} = require("./registration_otp_helpers");

const CHALLENGES = "_resident_signup_challenges";
const LIMITS = "_resident_signup_limits";
const digest = (value) => createHash("sha256").update(value).digest("hex");
const millis = (value) => value?.toMillis?.() || 0;

function emailValue(value) {
  const email = String(value || "").trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }
  return email;
}

function signupDetails(data, time) {
  const name = String(data?.name || "").trim();
  const password = String(data?.password || "");
  const barangay = canonicalBarangayName(data?.barangay);
  const acceptedPolicyVersion = String(data?.acceptedPolicyVersion || "").trim();
  const policyAcceptedAt = String(data?.policyAcceptedAt || "").trim();
  const birthDate = String(data?.birthDate || "").trim();
  if (!name || name.length > 120 || !barangay || !acceptedPolicyVersion
    || acceptedPolicyVersion.length > 40 || policyAcceptedAt.length > 60
    || !Number.isFinite(Date.parse(policyAcceptedAt))) {
    throw new HttpsError("invalid-argument", "Check your name, barangay and policy acceptance.");
  }
  if (password.length < 8 || password.length > 128) {
    throw new HttpsError("invalid-argument", "Password must be 8-128 characters.");
  }
  const date = new Date(`${birthDate}T00:00:00Z`);
  const today = new Date(time + 8 * 60 * 60 * 1000);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate) || !Number.isFinite(date.getTime())
    || date.toISOString().slice(0, 10) !== birthDate || date > today) {
    throw new HttpsError("invalid-argument", "Enter a valid birth date.");
  }
  const birthdayPending = today.getUTCMonth() < date.getUTCMonth()
    || (today.getUTCMonth() === date.getUTCMonth() && today.getUTCDate() < date.getUTCDate());
  const age = today.getUTCFullYear() - date.getUTCFullYear() - (birthdayPending ? 1 : 0);
  if (age < 15) throw new HttpsError("invalid-argument", "You must be at least 15 to register.");
  return { password, profile: {
    name, barangay, barangayId: barangayIdFor(barangay), birthDate,
    address: String(data?.address || barangay).trim().slice(0, 200),
    contactNumber: String(data?.contactNumber || "").trim().slice(0, 30),
    acceptedPolicyVersion, policyAcceptedAt,
  } };
}

// Only unfinished accounts from older APKs can be completed through email proof.
// Established, staff, restricted and disabled accounts are never overwritten.
function recoverableAccount(user, profile) {
  if (!user || user.disabled || user.emailVerified
    || Object.keys(user.customClaims || {}).length
    || (user.providerData || []).some((provider) => provider.providerId !== "password")) return false;
  if (!profile) return true;
  return profile.role === "resident" && profile.emailOtpRequired === true
    && profile.emailOtpVerified !== true
    && [undefined, "active"].includes(profile.accountStatus)
    && [undefined, "unverified"].includes(profile.status)
    && [undefined, "not_submitted"].includes(profile.verificationStatus)
    && profile.restrictionStatus !== "active";
}

function createResidentSignup({ db, auth, secret, sendEmail, now = Date.now }) {
  async function lookup(email) {
    try { return await auth.getUserByEmail(email); } catch (error) {
      if (error.code === "auth/user-not-found") return null;
      throw error;
    }
  }
  async function checkAvailable(email, ownedUid) {
    const user = await lookup(email);
    if (!user) return null;
    const profile = (await db.collection("users").doc(user.uid).get()).data();
    // A prior completion of this very challenge may have lost its response.
    if (ownedUid === user.uid && !user.disabled && (!profile || profile.role === "resident")
      && profile?.restrictionStatus !== "active"
      && [undefined, "active"].includes(profile?.accountStatus)) return user;
    if (!recoverableAccount(user, profile)) {
      throw new HttpsError("already-exists", "An account already uses this email. Please sign in instead.");
    }
    return user;
  }
  const challengeRef = (email) => db.collection(CHALLENGES).doc(digest(email));

  async function begin(request) {
    const email = emailValue(request.data?.email);
    const name = String(request.data?.name || "").replace(/\s+/g, " ").trim();
    if (name.length > 120) throw new HttpsError("invalid-argument", "Your name must be 120 characters or fewer.");
    const apiKey = secret();
    if (!apiKey) throw new HttpsError("failed-precondition", "Email delivery is not configured.");
    await checkAvailable(email);
    const time = now();
    const sessionId = randomBytes(32).toString("hex");
    const code = String(randomInt(0, 1000000)).padStart(6, "0");
    const reference = challengeRef(email);
    const ipReference = db.collection(LIMITS).doc(digest(String(request.rawRequest?.ip || "unknown")));
    await db.runTransaction(async (tx) => {
      const [snapshot, ipSnapshot] = await Promise.all([tx.get(reference), tx.get(ipReference)]);
      const old = snapshot.data() || {};
      const ip = ipSnapshot.data() || {};
      const retryAfterSeconds = Math.max(0, Math.ceil((millis(old.resendAvailableAt) - time) / 1000));
      if (retryAfterSeconds || (old.status === "finalizing" && millis(old.leaseUntil) > time)) {
        throw new HttpsError("resource-exhausted", "Please wait before requesting another code.", { retryAfterSeconds: retryAfterSeconds || 30 });
      }
      const inWindow = time - millis(old.requestWindowStartedAt) < OTP_REQUEST_WINDOW_MS;
      const count = inWindow ? Number(old.requestCount || 0) : 0;
      const ipInWindow = time - millis(ip.windowStartedAt) < OTP_REQUEST_WINDOW_MS;
      const ipCount = ipInWindow ? Number(ip.count || 0) : 0;
      if (count >= OTP_MAX_REQUESTS_PER_WINDOW || ipCount >= 30) {
        throw new HttpsError("resource-exhausted", "Too many verification codes were requested. Please try again later.");
      }
      tx.set(reference, {
        email, sessionHash: digest(sessionId), codeHash: otpHash(code, sessionId, email, apiKey),
        status: "pending", attempts: 0, requestCount: count + 1,
        requestWindowStartedAt: Timestamp.fromMillis(inWindow ? millis(old.requestWindowStartedAt) : time),
        expiresAt: Timestamp.fromMillis(time + OTP_LIFETIME_MS),
        resendAvailableAt: Timestamp.fromMillis(time + OTP_RESEND_COOLDOWN_MS),
        // Suitable for a Firestore TTL policy; expiry is also enforced on every call.
        deleteAfter: Timestamp.fromMillis(time + OTP_REQUEST_WINDOW_MS * 2),
      });
      tx.set(ipReference, { count: ipCount + 1,
        windowStartedAt: Timestamp.fromMillis(ipInWindow ? millis(ip.windowStartedAt) : time),
        deleteAfter: Timestamp.fromMillis(time + OTP_REQUEST_WINDOW_MS * 2) });
    });
    try {
      await sendEmail({ recipientEmail: email, name: name || "Resident", code });
    } catch (_) {
      // Preserve the rate counters even if the delivery service fails.
      await db.runTransaction(async (tx) => {
        const snapshot = await tx.get(reference);
        if (snapshot.data()?.sessionHash === digest(sessionId)) {
          tx.update(reference, { status: "delivery_failed", resendAvailableAt: Timestamp.fromMillis(0) });
        }
      });
      throw new HttpsError("unavailable", "The verification email could not be sent. Please try again.");
    }
    return { sessionId, sent: true, hasActiveCode: true, verified: false,
      maskedEmail: maskedEmail(email), retryAfterSeconds: OTP_RESEND_COOLDOWN_MS / 1000,
      expiresAtMillis: time + OTP_LIFETIME_MS };
  }

  async function complete(request) {
    const email = emailValue(request.data?.email);
    const sessionId = String(request.data?.sessionId || "");
    const code = canonicalOtp(request.data?.code);
    if (!/^[a-f0-9]{64}$/.test(sessionId) || !code) {
      throw new HttpsError("invalid-argument", "Enter the complete 6-digit code.");
    }
    const time = now();
    const { password, profile } = signupDetails(request.data, time);
    const apiKey = secret();
    if (!apiKey) throw new HttpsError("failed-precondition", "Email verification is not configured.");
    const reference = challengeRef(email);
    const leaseId = randomBytes(16).toString("hex");
    const result = await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(reference);
      const challenge = snapshot.data();
      if (!challenge || challenge.sessionHash !== digest(sessionId)
        || challenge.status === "delivery_failed") return { error: "missing" };
      if (millis(challenge.expiresAt) <= time) return { error: "expired" };
      if (Number(challenge.attempts || 0) >= OTP_MAX_ATTEMPTS) return { error: "locked" };
      if (!otpMatches({ code, expectedHash: challenge.codeHash, uid: sessionId, email, secret: apiKey })) {
        const attempts = Number(challenge.attempts || 0) + 1;
        tx.update(reference, { attempts });
        return { error: attempts >= OTP_MAX_ATTEMPTS ? "locked" : "invalid" };
      }
      if (challenge.status === "completed") return { uid: challenge.uid, completed: true };
      if (challenge.status === "finalizing" && millis(challenge.leaseUntil) > time) return { error: "busy" };
      const uid = challenge.uid || randomBytes(16).toString("hex");
      tx.update(reference, { status: "finalizing", uid, leaseId, leaseUntil: Timestamp.fromMillis(time + 90000) });
      return { uid };
    });
    const errors = {
      missing: ["failed-precondition", "Request a new verification code."],
      expired: ["deadline-exceeded", "This code has expired. Request a new one."],
      locked: ["resource-exhausted", "Too many incorrect attempts. Request a new code."],
      invalid: ["invalid-argument", "That code is incorrect. Please try again."],
      busy: ["aborted", "Registration is being completed. Please try again in a moment."],
    };
    if (result.error) throw new HttpsError(...errors[result.error]);
    if (result.completed) return { uid: result.uid, verified: true };
    try {
      let user = await checkAvailable(email, result.uid);
      if (!user) {
        try {
          user = await auth.createUser({ uid: result.uid, email, password, displayName: profile.name, emailVerified: true });
        } catch (error) {
          if (error.code !== "auth/email-already-exists" && error.code !== "auth/uid-already-exists") throw error;
          user = await checkAvailable(email, result.uid);
          if (!user) throw error;
        }
      }
      // Bind the legacy account UID before updating it, so a lost response can resume.
      await reference.update({ uid: user.uid });
      await auth.updateUser(user.uid, { password, displayName: profile.name, emailVerified: true });
      const userRef = db.collection("users").doc(user.uid);
      await db.runTransaction(async (tx) => {
        const snapshot = await tx.get(userRef);
        const existing = snapshot.data();
        if (existing && (existing.role !== "resident" || existing.restrictionStatus === "active"
          || ![undefined, "active"].includes(existing.accountStatus))) {
          throw new HttpsError("permission-denied", "This account cannot complete resident signup.");
        }
        const timestamp = FieldValue.serverTimestamp();
        tx.set(userRef, { ...(!existing ? {
          uid: user.uid, email, role: "resident", accountStatus: "active",
          status: "unverified", verificationStatus: "not_submitted",
          residentId: `BAR-${new Date(time).getFullYear()}-${user.uid.slice(0, 4).toUpperCase()}`,
          createdAt: timestamp,
        } : {}), ...profile, emailOtpRequired: true, emailOtpVerified: true,
        emailVerifiedAt: timestamp, updatedAt: timestamp }, { merge: true });
        tx.update(reference, { uid: user.uid, status: "completed", leaseUntil: Timestamp.fromMillis(0) });
        tx.set(db.collection("audit_logs").doc(), { action: "registration_email_verified",
          actorId: user.uid, targetUserId: user.uid, entityType: "user", entityId: user.uid, createdAt: timestamp });
      });
      return { uid: user.uid, verified: true };
    } catch (error) {
      await db.runTransaction(async (tx) => {
        const snapshot = await tx.get(reference);
        if (snapshot.data()?.leaseId === leaseId && snapshot.data()?.status === "finalizing") {
          tx.update(reference, { leaseUntil: Timestamp.fromMillis(0) });
        }
      }).catch(() => null);
      if (error instanceof HttpsError) throw error;
      // Never log the request, which contains the password.
      console.error("[RESIDENT SIGNUP] Completion failed", { code: error?.code || "unknown" });
      throw new HttpsError("unavailable", "Registration could not finish. Please try verifying again.");
    }
  }
  return { begin, complete };
}

module.exports = { createResidentSignup, recoverableAccount };
