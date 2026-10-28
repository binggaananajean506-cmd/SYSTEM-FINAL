const test = require("node:test");
const assert = require("node:assert/strict");
const { createResidentSignup } = require("./resident_signup");

function fixture() {
  const records = new Map();
  let clock = Date.parse("2026-10-26T05:00:00Z");
  let failure = null;
  const emails = [];
  const accounts = new Map();
  const ref = (path) => ({ path, get: async () => snapshot(path),
    update: async (data) => { records.set(path, { ...records.get(path), ...data }); } });
  const snapshot = (path) => ({ exists: records.has(path), data: () => records.get(path), ref: ref(path) });
  let queue = Promise.resolve();
  const db = {
    collection: (name) => ({ doc: (id = `audit-${records.size}`) => ref(`${name}/${id}`) }),
    runTransaction: (callback) => {
      const result = queue.then(async () => {
        const writes = [];
        const value = await callback({ get: async (r) => snapshot(r.path),
          set: (r, data, options) => writes.push(() => records.set(r.path,
            options?.merge ? { ...records.get(r.path), ...data } : data)),
          update: (r, data) => writes.push(() => records.set(r.path, { ...records.get(r.path), ...data })),
        });
        writes.forEach((write) => write());
        return value;
      });
      queue = result.catch(() => {});
      return result;
    },
  };
  const auth = {
    getUserByEmail: async (email) => {
      const user = [...accounts.values()].find((u) => u.email === email);
      if (!user) throw Object.assign(new Error("missing"), { code: "auth/user-not-found" });
      return user;
    },
    createUser: async (data) => {
      assert.equal(accounts.size, 0, "must not create a second account");
      const user = { ...data, providerData: [{ providerId: "password" }] };
      accounts.set(user.uid, user);
      return user;
    },
    updateUser: async (uid, data) => {
      if (failure === "update") { failure = null; throw new Error("transient auth failure"); }
      Object.assign(accounts.get(uid), data);
    },
  };
  const service = createResidentSignup({ db, auth, secret: () => "test-secret",
    now: () => clock, sendEmail: async (email) => {
      if (failure === "email") throw new Error("delivery offline");
      emails.push(email);
    } });
  const request = (data) => ({ data, rawRequest: { ip: "127.0.0.1" } });
  const email = "signup@example.com";
  return { records, emails, accounts,
    advance: (ms) => { clock += ms; }, fail: (stage) => { failure = stage; },
    begin: (value = email) => service.begin(request({ email: value })),
    complete: (session, overrides = {}) => service.complete(request({
      email, sessionId: session.sessionId, code: emails.at(-1)?.code,
      password: "Dummy-password-123!", name: "Ana Resident", barangay: "Poblacion",
      birthDate: "2001-05-14", acceptedPolicyVersion: "2026-09-01",
      policyAcceptedAt: "2026-10-26T05:00:00Z", ...overrides,
    })),
  };
}
const users = (f) => [...f.records.keys()].filter((key) => key.startsWith("users/"));

test("requesting a code records no account, profile, password or form details", async () => {
  const f = fixture();
  await f.begin();
  assert.equal(f.accounts.size, 0);
  assert.deepEqual(users(f), []);
  const stored = JSON.stringify([...f.records.values()]);
  for (const key of ["password", "name", "birthDate", "barangay", "Dummy-password"]) assert.ok(!stored.includes(key));
});

test("a correct OTP creates the verified account and resident profile together", async () => {
  const f = fixture();
  const result = await f.complete(await f.begin());
  assert.equal(result.verified, true);
  assert.equal(f.accounts.size, 1);
  assert.equal(users(f).length, 1);
  assert.equal(f.records.get(users(f)[0]).emailOtpVerified, true);
  assert.equal([...f.accounts.values()][0].emailVerified, true);
});

test("leaving signup and registering again does not reserve the email", async () => {
  const f = fixture();
  const abandoned = await f.begin();
  f.advance(61000);
  const next = await f.begin();
  await assert.rejects(f.complete(abandoned), { code: "failed-precondition" });
  assert.equal(f.accounts.size, 0);
  await f.complete(next);
  assert.equal(f.accounts.size, 1);
});

test("wrong OTPs lock after five attempts and never create an account", async () => {
  const f = fixture();
  const session = await f.begin();
  const wrong = f.emails[0].code === "000000" ? "111111" : "000000";
  for (let i = 0; i < 5; i++) await assert.rejects(f.complete(session, { code: wrong }),
    { code: i === 4 ? "resource-exhausted" : "invalid-argument" });
  await assert.rejects(f.complete(session), { code: "resource-exhausted" });
  assert.equal(f.accounts.size, 0);
  assert.deepEqual(users(f), []);
});

test("expired codes and a code used for another email cannot create accounts", async () => {
  const f = fixture();
  const session = await f.begin();
  await assert.rejects(f.complete(session, { email: "another@example.com" }), { code: "failed-precondition" });
  f.advance(300001);
  await assert.rejects(f.complete(session), { code: "deadline-exceeded" });
  assert.equal(f.accounts.size, 0);
});

test("failed email delivery preserves request limits without reserving an account", async () => {
  const f = fixture();
  f.fail("email");
  for (let i = 0; i < 5; i++) await assert.rejects(f.begin(), { code: "unavailable" });
  await assert.rejects(f.begin(), { code: "resource-exhausted" });
  assert.equal(f.accounts.size, 0);
});

test("resend cooldown applies when restarting signup", async () => {
  const f = fixture();
  await f.begin();
  await assert.rejects(f.begin(), { code: "resource-exhausted" });
  assert.equal(f.emails.length, 1);
});

test("IP limits apply across different email addresses", async () => {
  const f = fixture();
  for (let i = 0; i < 30; i++) await f.begin(`resident${i}@example.com`);
  await assert.rejects(f.begin("another@example.com"), { code: "resource-exhausted" });
});

test("unfinished accounts from older APKs require OTP before recovery", async () => {
  const f = fixture();
  f.accounts.set("legacy", { uid: "legacy", email: "signup@example.com", emailVerified: false });
  f.records.set("users/legacy", { role: "resident", accountStatus: "active", status: "unverified",
    verificationStatus: "not_submitted", emailOtpRequired: true, emailOtpVerified: false });
  const session = await f.begin();
  assert.equal(f.records.get("users/legacy").emailOtpVerified, false);
  await f.complete(session);
  assert.equal(f.accounts.size, 1);
  assert.equal(f.records.get("users/legacy").emailOtpVerified, true);
});

for (const profile of [
  { role: "lgu" }, { role: "resident", emailOtpVerified: true },
  { role: "resident", accountStatus: "suspended" },
  { role: "resident", restrictionStatus: "active" },
]) test(`existing protected accounts cannot be replaced: ${JSON.stringify(profile)}`, async () => {
  const f = fixture();
  f.accounts.set("protected", { uid: "protected", email: "signup@example.com", emailVerified: false });
  const original = { role: "resident", emailOtpRequired: true, emailOtpVerified: false, ...profile };
  f.records.set("users/protected", original);
  await assert.rejects(f.begin(), { code: "already-exists" });
  assert.deepEqual(f.records.get("users/protected"), original);
  assert.equal(f.emails.length, 0);
});

test("a transient failure after correct OTP can complete without duplicate accounts", async () => {
  const f = fixture();
  const session = await f.begin();
  f.fail("update");
  await assert.rejects(f.complete(session), { code: "unavailable" });
  await f.complete(session);
  assert.equal(f.accounts.size, 1);
  assert.equal(users(f).length, 1);
});

test("lost completion responses can be retried without changing the password or profile", async () => {
  const f = fixture();
  const session = await f.begin();
  // The client never receives this first successful response.
  await f.complete(session);
  const result = await f.complete(session, { password: "Another-password-123!", name: "Different name" });
  assert.ok(result.uid);
  assert.equal([...f.accounts.values()][0].password, "Dummy-password-123!");
  assert.equal(f.records.get(users(f)[0]).name, "Ana Resident");
});

test("concurrent completion accepts one attempt without creating duplicates", async () => {
  const f = fixture();
  const session = await f.begin();
  const results = await Promise.allSettled([f.complete(session), f.complete(session)]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(f.accounts.size, 1);
});
