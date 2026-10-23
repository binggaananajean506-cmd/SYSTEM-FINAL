import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, test } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";

// Keep the emulator project aligned with .firebaserc. Storage rules that read
// Firestore always resolve against the emulator's configured project ID.
const projectId = "e-sugid";
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8085";
const [host, portText] = emulatorHost.split(":");
const rules = readFileSync(new URL("../firestore.rules", import.meta.url), "utf8");

let testEnvironment;

const profile = (uid, role, status = "approved", extra = {}) => {
  const normalizedRole = role.trim().toLowerCase();
  const normalizedStatus = status.trim().toLowerCase();
  const resident = normalizedRole === "resident";
  return {
    uid,
    email: `${uid}@example.com`,
    name: uid,
    role,
    status,
    accountStatus: resident
      ? "active"
      : normalizedStatus === "approved"
        ? "active"
        : "pending_approval",
    verificationStatus: resident
      ? normalizedStatus === "approved"
        ? "verified"
        : normalizedStatus === "pending_review"
          ? "pending"
          : "not_submitted"
      : "not_applicable",
    ...extra,
  };
};

const announcement = (authorId, authorRole, status, extra = {}) => ({
  id: `post-${authorId}`,
  title: "Community update",
  content: "Official information for residents.",
  contentType: "announcement",
  schemaVersion: 2,
  authorId,
  authorRole,
  status,
  priority: "regular",
  visibility: "targeted",
  targetBarangay: "Cabcaban",
  targetBarangays: ["Cabcaban"],
  audienceKeys: ["barangay:Cabcaban"],
  ...extra,
});

test("immediate announcement publication respects existing staff rule field limits", async () => {
  await testEnvironment.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "users", "partner-peer"), profile("partner-peer", "organization", "approved", {
      organizationId: "partner", organizationName: "Barili Fire Station",
    }));
  });
  const publishers = [
    ["mayor", "mayor", { visibility: "public", targetBarangay: "All Barangays", targetBarangays: [],
      audienceKeys: ["municipality:barili"], departmentId: "", publisherEntityId: "mayor",
      publisherEntityType: "mayor", publisherEntityName: "mayor" }],
    ["barangay", "barangay_captain", { barangayId: "barili_cabcaban" }],
    ["partner", "organization", { publisherEntityId: "partner" }],
  ];
  for (const [uid, role, publisher] of publishers) {
    const reference = doc(dbFor(uid), "posts", `immediate-${uid}`);
    await assertSucceeds(setDoc(reference, announcement(uid, role, "draft", publisher)));
    const update = { status: "approved", publishAt: serverTimestamp(), notificationRequested: true,
      revision: 1, updatedAt: serverTimestamp() };
    await assertSucceeds(updateDoc(reference, { ...update, publishAt: null, publishedAt: serverTimestamp() }));
    if (uid !== "mayor") {
      await assertSucceeds(updateDoc(reference, { status: "draft", publishedAt: null }));
      const peer = doc(dbFor(uid === "barangay" ? "secretary" : "partner-peer"), "posts", `immediate-${uid}`);
      await assertFails(updateDoc(peer, { ...update, publishedAt: serverTimestamp() }));
      await assertSucceeds(updateDoc(peer, update));
    }
  }
  await assertSucceeds(updateDoc(doc(dbFor("tourism-peer"), "posts", "tourism-draft"), {
    status: "approved", publishAt: serverTimestamp(), notificationRequested: true,
    revision: 1, updatedAt: serverTimestamp(),
  }));
});

const calendarEvent = (id, createdBy, extra = {}) => ({
  id,
  title: "Barangay Assembly",
  description: "Monthly community assembly.",
  startAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  endAt: new Date(Date.now() + 25 * 60 * 60 * 1000),
  allDay: false,
  category: "barangay_event",
  location: "Barangay Hall",
  createdBy,
  sourceType: "manual",
  sourceId: "",
  visibility: "public",
  targetBarangay: "",
  targetUserIds: [],
  audienceKeys: ["municipality:barili"],
  status: "scheduled",
  isImportant: false,
  organizerName: "Municipality of Barili",
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

const dbFor = (uid) => testEnvironment.authenticatedContext(uid).firestore();

async function seedBaseData() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, "users", "admin"), profile("admin", "super_admin", "approved", { department: "IT Department", departmentId: "it-department", departmentPublicName: "LGU IT Department" })),
      setDoc(doc(db, "users", "mayor"), profile("mayor", "mayor", "approved", { positionTitle: "Municipal Mayor" })),
      setDoc(doc(db, "users", "setup-admin"), profile("setup-admin", "lgu", "approved", { setupRequired: true })),
      setDoc(doc(db, "users", "tourism"), profile("tourism", "lgu", "approved", { department: "Tourism Department", departmentId: "tourism-department", departmentPublicName: "LGU Tourism Department" })),
      setDoc(doc(db, "users", "tourism-peer"), profile("tourism-peer", "lgu", "approved", { department: "Tourism Department", departmentId: "tourism-department", departmentPublicName: "LGU Tourism Department" })),
      setDoc(doc(db, "users", "engineering"), profile("engineering", "lgu", "approved", { department: "Engineering Department", departmentId: "engineering-department", departmentPublicName: "LGU Engineering Department" })),
      setDoc(doc(db, "users", "resident"), profile("resident", "resident", "approved", { barangay: "Cabcaban", barangayId: "barili_cabcaban" })),
      setDoc(doc(db, "users", "other"), profile("other", "resident", "approved", { barangay: "Poblacion", barangayId: "barili_poblacion" })),
      setDoc(doc(db, "users", "barangay"), profile("barangay", "barangay", "approved", { barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true })),
      setDoc(doc(db, "users", "vice-captain"), profile("vice-captain", "barangay_vice_captain", "approved", { barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true })),
      setDoc(doc(db, "users", "secretary"), profile("secretary", "barangay_secretary", "approved", { barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true })),
      setDoc(doc(db, "users", "councilor"), profile("councilor", "barangay_councilor", "approved", { barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: false })),
      setDoc(doc(db, "users", "treasurer"), profile("treasurer", "barangay_councilor", "approved", { barangay: "Cabcaban", barangayId: "barili_cabcaban", positionCode: "barangay_treasurer", positionTitle: "Barangay Treasurer", canVerifyResidents: false })),
      setDoc(doc(db, "users", "other-official"), profile("other-official", "barangay_secretary", "approved", { barangay: "Poblacion", barangayId: "barili_poblacion", canVerifyResidents: true })),
      setDoc(doc(db, "users", "pending-staff"), profile("pending-staff", "barangay_secretary", "pending", { barangay: "Cabcaban", barangayId: "barili_cabcaban", approvalRequired: true })),
      setDoc(doc(db, "users", "partner"), profile("partner", "partner", "approved", { organizationId: "partner", organizationName: "Barili Fire Station" })),
      setDoc(doc(db, "users", "partner-no-org"), profile("partner-no-org", "partner", "approved", { organizationName: "CEBECO" })),
      setDoc(doc(db, "users", "pending-local"), profile("pending-local", "resident", "pending_review", { barangay: "Cabcaban", barangayId: "barili_cabcaban" })),
      setDoc(doc(db, "users", "pending-other"), profile("pending-other", "resident", "pending_review", { barangay: "Poblacion", barangayId: "barili_poblacion" })),
      setDoc(doc(db, "submissions", "concern-resident"), { id: "concern-resident", userId: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban", recipientType: "barangay", status: "submitted", date: new Date() }),
      setDoc(doc(db, "submissions", "concern-other"), { id: "concern-other", userId: "other", barangay: "Poblacion", barangayId: "barili_poblacion", recipientType: "barangay", status: "submitted", date: new Date() }),
      setDoc(doc(db, "submissions", "concern-it"), { id: "concern-it", userId: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban", recipientType: "lgu", recipientDepartmentId: "it-department", status: "submitted", date: new Date() }),
      setDoc(doc(db, "submissions", "concern-tourism"), { id: "concern-tourism", userId: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban", recipientDepartmentId: "tourism-department", status: "submitted", date: new Date() }),
      setDoc(doc(db, "submissions", "concern-engineering"), { id: "concern-engineering", userId: "other", barangay: "Poblacion", barangayId: "barili_poblacion", recipientDepartmentId: "engineering-department", status: "submitted", date: new Date() }),
      setDoc(doc(db, "submissions", "public-cabcaban"), { id: "public-cabcaban", userId: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban", schemaVersion: 4, visibility: "public", recipientType: "organization", status: "submitted", date: new Date() }),
      setDoc(doc(db, "submissions", "private-cabcaban-org"), { id: "private-cabcaban-org", userId: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban", schemaVersion: 4, visibility: "private", recipientType: "organization", status: "submitted", date: new Date() }),
      setDoc(doc(db, "submissions", "private-cabcaban-barangay"), { id: "private-cabcaban-barangay", userId: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban", schemaVersion: 4, visibility: "private", recipientType: "barangay", status: "submitted", date: new Date() }),
      setDoc(doc(db, "posts", "approved-post"), announcement("admin", "lgu", "approved", { visibility: "public", targetBarangay: "All Barangays", targetBarangays: [], audienceKeys: ["municipality:barili"] })),
      setDoc(doc(db, "posts", "targeted-post"), announcement("admin", "lgu", "approved")),
      setDoc(doc(db, "posts", "pending-post"), announcement("partner", "partner", "pending_review")),
      setDoc(doc(db, "posts", "tourism-draft"), announcement("tourism", "lgu", "draft", { departmentId: "tourism-department", publisherEntityId: "tourism-department", publisherEntityType: "lgu_department", publisherEntityName: "LGU Tourism Department" })),
      setDoc(doc(db, "posts", "engineering-draft"), announcement("engineering", "lgu", "draft", { departmentId: "engineering-department", publisherEntityId: "engineering-department", publisherEntityType: "lgu_department", publisherEntityName: "LGU Engineering Department" })),
      setDoc(doc(db, "announcement_feeds", "municipality:barili", "posts", "approved-post"), announcement("admin", "lgu", "approved", { visibility: "public", targetBarangay: "All Barangays", targetBarangays: [], audienceKeys: ["municipality:barili"] })),
      setDoc(doc(db, "announcement_feeds", "barangay:Cabcaban", "posts", "targeted-post"), announcement("admin", "lgu", "approved")),
      setDoc(doc(db, "alerts", "active-alert"), { active: true, title: "Weather advisory" }),
      setDoc(doc(db, "organizations", "fire-station"), { name: "Barili Fire Station", status: "verified" }),
      setDoc(doc(db, "organizations", "partner"), { name: "Barili Fire Station", primaryAdminId: "partner", status: "verified", serviceBarangays: ["Cabcaban"], municipalityWidePublishing: true }),
      setDoc(doc(db, "lgu_departments", "it-department"), { name: "IT Department", publicName: "LGU IT Department", status: "active" }),
      setDoc(doc(db, "lgu_departments", "tourism-department"), { name: "Tourism Department", publicName: "LGU Tourism Department", status: "active" }),
      setDoc(doc(db, "lgu_departments", "engineering-department"), { name: "Engineering Department", publicName: "LGU Engineering Department", status: "active" }),
      setDoc(doc(db, "audit_logs", "login-audit"), { action: "sign_in", createdAt: new Date() }),
      setDoc(doc(db, "audit_logs", "profile-audit"), { targetType: "user", targetId: "resident", action: "profile_updated", createdAt: new Date() }),
      setDoc(doc(db, "audit_logs", "it-concern-audit"), { targetType: "submission", targetId: "concern-it", action: "concern_handle", createdAt: new Date() }),
      setDoc(doc(db, "audit_logs", "tourism-concern-audit"), { targetType: "submission", targetId: "concern-tourism", action: "concern_handle", createdAt: new Date() }),
      setDoc(doc(db, "notifications", "it-concern-notice"), { type: "concern_update", referenceId: "concern-it", userId: "resident", read: false }),
      setDoc(doc(db, "notifications", "tourism-concern-notice"), { type: "concern_update", referenceId: "concern-tourism", userId: "resident", read: false }),
      setDoc(doc(db, "emergency_reports", "resident-emergency"), { reporterId: "resident", barangay: "Cabcaban", routingKey: "bfp", status: "submitted" }),
      setDoc(doc(db, "emergency_reports", "other-emergency"), { reporterId: "other", barangay: "Poblacion", routingKey: "health", status: "submitted" }),
      setDoc(doc(db, "helpdesk_tickets", "resident-ticket"), { userId: "resident", status: "Open" }),
      setDoc(doc(db, "civic_points", "resident"), { userId: "resident", points: 5 }),
      setDoc(doc(db, "system", "settings"), { concernSlaHours: 72 }),
      setDoc(doc(db, "verification_queue_versions", "barili_cabcaban"), { barangayId: "barili_cabcaban", updatedAt: new Date() }),
      setDoc(doc(db, "verification_queue_versions", "barili_poblacion"), { barangayId: "barili_poblacion", updatedAt: new Date() }),
      setDoc(doc(db, "staff_account_requests", "secretary-request"), { createdUserId: "pending-staff", name: "Pending Secretary", email: "pending@example.com", role: "barangay_secretary", barangay: "Cabcaban", barangayId: "barili_cabcaban", status: "pending", requestedBy: "barangay", createdAt: new Date() }),
      setDoc(doc(db, "staff_account_requests", "tourism-request"), { createdUserId: "pending-tourism", name: "Pending Tourism User", email: "tourism@example.com", role: "lgu", department: "Tourism Department", departmentId: "tourism-department", status: "pending", requestedBy: "tourism", createdAt: new Date() }),
      setDoc(doc(db, "staff_account_requests", "partner-request"), { createdUserId: "pending-partner", name: "Pending Partner", email: "partner-request@example.com", role: "organization", organizationId: "partner", status: "pending", requestedBy: "partner", createdAt: new Date() }),
      setDoc(doc(db, "staff_account_requests", "internal-secretary-request"), { createdUserId: "pending-staff", name: "Internal Secretary", role: "barangay_secretary", barangayId: "barili_cabcaban", creationSource: "staff_request", status: "pending" }),
      setDoc(doc(db, "staff_account_requests", "self-registered-secretary"), { createdUserId: "pending-staff", name: "Self-registered Secretary", role: "barangay_secretary", barangayId: "barili_cabcaban", creationSource: "staff_self_registration", status: "pending" }),
    ]);
  });
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: { host, port: Number(portText), rules },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await seedBaseData();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("saved announcement calendar links", () => {
  test("official may publish an all-day event that already started today", async () => {
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    await assertSucceeds(setDoc(doc(dbFor("admin"), "calendar_events", "today-event"), calendarEvent("today-event", "admin", {
      allDay: true, startAt: start, endAt: new Date(start.getTime() + 86400000),
    })));
  });
  const eventId = "source_announcement_targeted-post";
  const entry = () => ({ userId: "resident", eventId, sourceAnnouncementId: "targeted-post", createdAt: serverTimestamp() });
  async function seedEvent(extra = {}) {
    await testEnvironment.withSecurityRulesDisabled(context => setDoc(
      doc(context.firestore(), "calendar_events", eventId),
      calendarEvent(eventId, "barangay", { sourceType: "announcement", sourceId: "targeted-post", visibility: "barangay", targetBarangay: "Cabcaban", ...extra }),
    ));
  }
  test("resident saves a same-barangay source link and cannot overwrite or duplicate it", async () => {
    await seedEvent();
    const db = dbFor("resident");
    const ref = doc(db, "users", "resident", "calendar_entries", eventId);
    await assertSucceeds(setDoc(ref, entry()));
    await assertFails(setDoc(ref, entry()));
    await assertFails(setDoc(doc(db, "users", "resident", "calendar_entries", "duplicate"), { ...entry(), eventId: "duplicate" }));
    assert.equal((await getDocs(collection(db, "users", "resident", "calendar_entries"))).size, 1);
    await assertFails(getDoc(doc(dbFor("other"), "users", "resident", "calendar_entries", eventId)));
  });
  test("cannot save another barangay's event or a cancelled event", async () => {
    await seedEvent();
    await assertFails(setDoc(doc(dbFor("other"), "users", "other", "calendar_entries", eventId), { ...entry(), userId: "other" }));
    await seedEvent({ status: "cancelled" });
    await assertFails(setDoc(doc(dbFor("resident"), "users", "resident", "calendar_entries", eventId), entry()));
  });
});

describe("saved announcement authorization", () => {
  const bookmarkPath = ["users", "resident", "saved_announcements", "approved-post"];

  test("verified resident creates one bookmark using the announcement id", async () => {
    const residentDb = dbFor("resident");
    const reference = doc(residentDb, ...bookmarkPath);
    await assertSucceeds(setDoc(reference, {
      announcementId: "approved-post",
      savedAt: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(reference, {
      announcementId: "approved-post",
      savedAt: serverTimestamp(),
    }));
    const snapshot = await getDocs(collection(residentDb, "users", "resident", "saved_announcements"));
    assert.equal(snapshot.size, 1);
  });

  test("bookmark fields and source id are validated", async () => {
    const residentDb = dbFor("resident");
    await assertFails(setDoc(
      doc(residentDb, "users", "resident", "saved_announcements", "wrong-id"),
      { announcementId: "approved-post", savedAt: serverTimestamp() },
    ));
    await assertFails(setDoc(
      doc(residentDb, "users", "resident", "saved_announcements", "approved-post"),
      { announcementId: "approved-post", savedAt: serverTimestamp(), arbitrary: true },
    ));
  });

  test("unverified residents cannot create bookmarks", async () => {
    await assertFails(setDoc(
      doc(dbFor("pending-local"), "users", "pending-local", "saved_announcements", "approved-post"),
      { announcementId: "approved-post", savedAt: serverTimestamp() },
    ));
  });

  test("another resident cannot read or modify the owner's bookmarks", async () => {
    const ownerReference = doc(dbFor("resident"), ...bookmarkPath);
    await assertSucceeds(setDoc(ownerReference, {
      announcementId: "approved-post",
      savedAt: serverTimestamp(),
    }));
    const otherReference = doc(dbFor("other"), ...bookmarkPath);
    await assertFails(getDoc(otherReference));
    await assertFails(getDoc(doc(dbFor("admin"), ...bookmarkPath)));
    await assertFails(setDoc(otherReference, {
      announcementId: "approved-post",
      savedAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(otherReference));
  });

  test("an existing bookmark permits cancelled content only within its audience", async () => {
    const residentDb = dbFor("resident");
    await assertSucceeds(setDoc(doc(residentDb, ...bookmarkPath), {
      announcementId: "approved-post",
      savedAt: serverTimestamp(),
    }));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "posts", "approved-post"), {
        status: "cancelled",
      });
    });
    await assertSucceeds(getDoc(doc(residentDb, "posts", "approved-post")));

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "posts", "approved-post"), {
        visibility: "targeted",
        targetBarangay: "Poblacion",
        targetBarangays: ["Poblacion"],
        audienceKeys: ["barangay:Poblacion"],
      });
    });
    await assertFails(getDoc(doc(residentDb, "posts", "approved-post")));
  });
});

describe("community calendar authorization", () => {
  test("approved administrators create and cancel official events", async () => {
    const adminDb = dbFor("admin");
    const reference = doc(adminDb, "calendar_events", "admin-event");
    await assertSucceeds(setDoc(
      reference,
      calendarEvent("admin-event", "admin"),
    ));
    await assertSucceeds(updateDoc(reference, {
      status: "cancelled",
      updatedAt: serverTimestamp(),
    }));
    const snapshot = await getDoc(reference);
    assert.equal(snapshot.data().status, "cancelled");
  });

  test("barangay officials create only events in their own scope", async () => {
    const barangayDb = dbFor("barangay");
    await assertSucceeds(setDoc(
      doc(barangayDb, "calendar_events", "cabcaban-event"),
      calendarEvent("cabcaban-event", "barangay", {
        visibility: "barangay",
        targetBarangay: "Cabcaban",
        audienceKeys: ["barangay:Cabcaban"],
        organizerName: "Barangay Cabcaban",
      }),
    ));
    await assertFails(setDoc(
      doc(barangayDb, "calendar_events", "public-event"),
      calendarEvent("public-event", "barangay"),
    ));
    await assertFails(setDoc(
      doc(barangayDb, "calendar_events", "other-barangay-event"),
      calendarEvent("other-barangay-event", "barangay", {
        visibility: "barangay",
        targetBarangay: "Poblacion",
        audienceKeys: ["barangay:Poblacion"],
      }),
    ));
  });

  test("the Mayor can add a calendar event only through the Mayor's own announcement", async () => {
    const mayorDb = dbFor("mayor");
    const postId = "mayor-event-post";
    const eventId = `source_announcement_${postId}`;
    const batch = writeBatch(mayorDb);
    batch.set(doc(mayorDb, "posts", postId), announcement("mayor", "mayor", "approved", {
      visibility: "public",
      targetBarangay: "All Barangays",
      targetBarangays: [],
      audienceKeys: ["municipality:barili"],
      departmentId: "",
      publisherEntityId: "mayor",
      publisherEntityType: "mayor",
      publisherEntityName: "mayor",
    }));
    batch.set(doc(mayorDb, "calendar_events", eventId), calendarEvent(eventId, "mayor", {
      category: "announcement",
      sourceType: "announcement",
      sourceId: postId,
      organizerName: "mayor",
      categoryName: "Community Event",
    }));
    await assertSucceeds(batch.commit());
  });

  test("residents cannot modify official events", async () => {
    await assertFails(setDoc(
      doc(dbFor("resident"), "calendar_events", "resident-official"),
      calendarEvent("resident-official", "resident"),
    ));
  });

  test("verified residents manage only their personal reminders", async () => {
    const residentDb = dbFor("resident");
    const reference = doc(residentDb, "calendar_events", "personal-event");
    await assertSucceeds(setDoc(
      reference,
      calendarEvent("personal-event", "resident", {
        category: "personal",
        visibility: "private",
        targetUserIds: ["resident"],
        audienceKeys: ["user:resident"],
        organizerName: "resident",
      }),
    ));
    await assertSucceeds(updateDoc(reference, {
      title: "Updated personal reminder",
      updatedAt: serverTimestamp(),
    }));
  });

  test("private events are readable only by their target users", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "calendar_events", "private-source"), {
        ...calendarEvent("private-source", "resident", {
          category: "bayanihan",
          sourceType: "bayanihan",
          sourceId: "request-1",
          visibility: "private",
          targetUserIds: ["resident"],
          audienceKeys: ["user:resident"],
        }),
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
    await assertSucceeds(getDoc(doc(dbFor("resident"), "calendar_events", "private-source")));
    await assertFails(getDoc(doc(dbFor("other"), "calendar_events", "private-source")));
    await assertFails(getDoc(doc(dbFor("admin"), "calendar_events", "private-source")));
  });

  test("invalid categories and statuses are rejected", async () => {
    const adminDb = dbFor("admin");
    await assertFails(setDoc(
      doc(adminDb, "calendar_events", "bad-category"),
      calendarEvent("bad-category", "admin", { category: "miscellaneous" }),
    ));
    await assertFails(setDoc(
      doc(adminDb, "calendar_events", "bad-status"),
      calendarEvent("bad-status", "admin", { status: "deleted" }),
    ));
  });
});

describe("user profiles and administrator bootstrap", () => {
  test("users can read their own profile without an administrator recursion", async () => {
    await assertSucceeds(getDoc(doc(dbFor("admin"), "users", "admin")));
    await assertSucceeds(getDoc(doc(dbFor("resident"), "users", "resident")));
  });

  test("IT administrators can list users and maintain institutional profiles", async () => {
    const adminDb = dbFor("admin");
    await assertSucceeds(getDocs(collection(adminDb, "users")));
    await assertSucceeds(updateDoc(doc(adminDb, "users", "tourism"), { positionTitle: "Tourism Officer" }));
  });

  test("a restricted verified IT administrator loses privileged access", async () => {
    const adminDb = dbFor("admin");
    await assertSucceeds(getDocs(collection(adminDb, "users")));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "users", "admin"), {
        status: "suspended",
        accountStatus: "disabled",
        verificationStatus: "verified",
      });
    });
    await assertSucceeds(getDoc(doc(adminDb, "users", "admin")));
    await assertFails(getDocs(collection(adminDb, "users")));
    await assertFails(updateDoc(doc(adminDb, "users", "tourism"), { positionTitle: "Changed" }));
  });

  test("IT can record a staff restriction and the target loses case access", async () => {
    const adminDb = dbFor("admin");
    const batch = writeBatch(adminDb);
    batch.update(doc(adminDb, "users", "tourism"), {
      status: "suspended",
      accountStatus: "disabled",
      approvalRequired: false,
      statusReason: "Administrative review",
      updatedBy: "admin",
    });
    batch.set(doc(collection(adminDb, "notifications")), {
      userId: "tourism",
      type: "account_update",
      title: "Account status updated",
      message: "Administrative review",
      read: false,
      createdAt: serverTimestamp(),
    });
    batch.set(doc(collection(adminDb, "audit_logs")), {
      actorId: "admin",
      actorEmail: "admin@example.com",
      action: "user_status_updated",
      targetType: "user",
      targetId: "tourism",
      metadata: { status: "suspended", reason: "Administrative review" },
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(dbFor("tourism"), "users", "tourism")));
    await assertFails(getDoc(doc(dbFor("tourism"), "submissions", "concern-tourism")));
  });

  test("LGU department staff can see only records assigned to their department", async () => {
    const tourismDb = dbFor("tourism");
    await assertSucceeds(getDoc(doc(tourismDb, "users", "tourism-peer")));
    await assertFails(getDoc(doc(tourismDb, "users", "engineering")));
    await assertFails(getDoc(doc(tourismDb, "users", "pending-local")));
    await assertSucceeds(getDocs(query(
      collection(tourismDb, "users"),
      where("departmentId", "==", "tourism-department"),
    )));
    await assertFails(getDocs(collection(tourismDb, "users")));

    await assertSucceeds(getDoc(doc(tourismDb, "submissions", "concern-tourism")));
    await assertFails(getDoc(doc(tourismDb, "submissions", "concern-engineering")));
    await assertSucceeds(getDocs(query(
      collection(tourismDb, "submissions"),
      where("recipientDepartmentId", "==", "tourism-department"),
    )));
    await assertSucceeds(addDoc(collection(tourismDb, "notifications"), {
      type: "concern_update", referenceId: "concern-tourism", userId: "resident",
    }));
    await assertFails(addDoc(collection(tourismDb, "notifications"), {
      type: "concern_update", referenceId: "concern-engineering", userId: "other",
    }));

    await assertSucceeds(getDoc(doc(tourismDb, "posts", "tourism-draft")));
    await assertFails(getDoc(doc(tourismDb, "posts", "engineering-draft")));
    await assertSucceeds(getDocs(query(
      collection(tourismDb, "posts"),
      where("departmentId", "==", "tourism-department"),
    )));

    await assertSucceeds(getDoc(doc(tourismDb, "staff_account_requests", "tourism-request")));
    await assertFails(getDoc(doc(tourismDb, "staff_account_requests", "secretary-request")));
    await assertSucceeds(getDoc(doc(tourismDb, "lgu_departments", "tourism-department")));
    await assertFails(updateDoc(doc(tourismDb, "lgu_departments", "tourism-department"), { publicName: "Changed" }));
  });

  test("administrators can attach every dashboard collection listener", async () => {
    const adminDb = dbFor("admin");
    await assertSucceeds(getDocs(collection(adminDb, "users")));
    await assertSucceeds(getDocs(query(collection(adminDb, "submissions"), where("recipientDepartmentId", "==", "it-department"))));
    await assertSucceeds(getDocs(collection(adminDb, "posts")));
    await assertSucceeds(getDocs(collection(adminDb, "alerts")));
    await assertSucceeds(getDocs(collection(adminDb, "organizations")));
    await assertSucceeds(getDocs(collection(adminDb, "document_requests")));
    await assertSucceeds(getDocs(collection(adminDb, "helpdesk_tickets")));
    await assertSucceeds(getDocs(collection(adminDb, "emergency_reports")));
    await assertSucceeds(getDocs(collection(adminDb, "staff_account_requests")));
    await assertSucceeds(getDoc(doc(adminDb, "system", "settings")));
    await assertFails(getDocs(collection(adminDb, "audit_logs")));
    await assertSucceeds(getDocs(query(collection(adminDb, "audit_logs"), where("targetType", "!=", "submission"), limit(20))));
  });

  test("barangay announcement listeners must use their barangay scope", async () => {
    const barangayDb = dbFor("barangay");
    await assertFails(getDocs(query(
      collection(barangayDb, "posts"),
      where("authorId", "==", "barangay"),
    )));
    await assertSucceeds(getDocs(query(
      collection(barangayDb, "posts"),
      where("barangayId", "==", "barili_cabcaban"),
    )));
  });

  test("residents cannot enumerate users or elevate their role", async () => {
    const residentDb = dbFor("resident");
    await assertFails(getDocs(collection(residentDb, "users")));
    await assertFails(updateDoc(doc(residentDb, "users", "resident"), { role: "lgu" }));
    await assertSucceeds(updateDoc(doc(residentDb, "users", "resident"), { fcmToken: "device-token" }));
    await assertFails(updateDoc(doc(dbFor("other"), "users", "resident"), { fcmToken: "stolen-token" }));
  });

  test("staff completing initial password setup can read only their own profile", async () => {
    const setupDb = dbFor("setup-admin");
    await assertSucceeds(getDoc(doc(setupDb, "users", "setup-admin")));
    await assertFails(getDocs(collection(setupDb, "users")));
    await assertFails(getDocs(collection(setupDb, "staff_account_requests")));
  });

  test("account approval records are visible to IT and the requesting team's scope", async () => {
    const reference = doc(dbFor("admin"), "staff_account_requests", "secretary-request");
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(getDoc(doc(dbFor("barangay"), "staff_account_requests", "secretary-request")));
    await assertSucceeds(getDoc(doc(dbFor("secretary"), "staff_account_requests", "secretary-request")));
    await assertSucceeds(getDoc(doc(dbFor("tourism"), "staff_account_requests", "tourism-request")));
    await assertSucceeds(getDoc(doc(dbFor("partner"), "staff_account_requests", "partner-request")));
    await assertFails(getDoc(doc(dbFor("partner"), "staff_account_requests", "secretary-request")));
    await assertFails(getDoc(doc(dbFor("barangay"), "staff_account_requests", "tourism-request")));
    await assertFails(getDocs(query(collection(dbFor("barangay"), "staff_account_requests"), where("barangayId", "==", "barili_cabcaban"))));
    const internalRequests = await assertSucceeds(getDocs(query(collection(dbFor("barangay"), "staff_account_requests"), where("barangayId", "==", "barili_cabcaban"), where("creationSource", "==", "staff_request"))));
    assert.deepEqual(internalRequests.docs.map((item) => item.id), ["internal-secretary-request"]);
    await assertSucceeds(getDocs(query(collection(dbFor("tourism"), "staff_account_requests"), where("departmentId", "==", "tourism-department"), where("creationSource", "==", "staff_request"))));
    await assertSucceeds(getDocs(query(collection(dbFor("partner"), "staff_account_requests"), where("organizationId", "==", "partner"), where("creationSource", "==", "staff_request"))));
    await assertFails(getDocs(collection(dbFor("barangay"), "staff_account_requests")));
    await assertFails(updateDoc(reference, { status: "approved", approvedBy: "admin" }));
    await assertFails(updateDoc(doc(dbFor("barangay"), "staff_account_requests", "secretary-request"), { status: "rejected" }));
  });

  test("pending institutional accounts cannot use approved staff access", async () => {
    const pendingDb = dbFor("pending-staff");
    await assertSucceeds(getDoc(doc(pendingDb, "users", "pending-staff")));
    await assertFails(getDocs(collection(pendingDb, "users")));
    await assertFails(getDocs(collection(pendingDb, "staff_account_requests")));
    await assertFails(addDoc(collection(pendingDb, "posts"), announcement("pending-staff", "barangay_secretary", "approved")));
  });

  test("barangay officials cannot bypass callable verification authorization", async () => {
    const barangayDb = dbFor("barangay");
    await assertFails(getDocs(query(collection(barangayDb, "users"), where("barangayId", "==", "barili_cabcaban"))));
    await assertFails(getDocs(collection(barangayDb, "users")));
    await assertFails(getDoc(doc(barangayDb, "users", "pending-local")));
    await assertFails(getDoc(doc(barangayDb, "users", "pending-other")));
    await assertFails(updateDoc(doc(barangayDb, "users", "pending-local"), {
      status: "approved",
      accountStatus: "active",
      verificationStatus: "verified",
      reviewedAt: new Date(),
      reviewedBy: "barangay",
      reviewNote: "Credentials confirmed",
      approvedAt: new Date(),
      verificationApprovedAt: new Date(),
    }));
    await assertFails(updateDoc(doc(barangayDb, "users", "pending-other"), { status: "approved", reviewedBy: "barangay" }));
    await assertFails(updateDoc(doc(barangayDb, "users", "partner"), { status: "approved", reviewedBy: "barangay" }));
  });

  test("administrators cannot bypass the callable resident decision audit", async () => {
    const adminDb = dbFor("admin");
    await assertFails(updateDoc(doc(adminDb, "users", "pending-local"), {
      verificationStatus: "verified",
      verifiedBy: "admin",
      verifiedAt: new Date(),
      verifiedBarangayId: "barili_cabcaban",
    }));
    await assertFails(updateDoc(doc(adminDb, "users", "pending-local"), {
      verificationStatus: "additional_document_required",
      reviewReason: "Document is unreadable",
      reviewedBy: "admin",
      reviewedAt: new Date(),
    }));
  });

  test("verification queue refresh signals use delegated BarangayId scope", async () => {
    await assertSucceeds(getDoc(doc(dbFor("barangay"), "verification_queue_versions", "barili_cabcaban")));
    await assertSucceeds(getDoc(doc(dbFor("vice-captain"), "verification_queue_versions", "barili_cabcaban")));
    await assertFails(getDoc(doc(dbFor("barangay"), "verification_queue_versions", "barili_poblacion")));
    await assertSucceeds(getDoc(doc(dbFor("other-official"), "verification_queue_versions", "barili_poblacion")));
    await assertFails(getDoc(doc(dbFor("councilor"), "verification_queue_versions", "barili_cabcaban")));
  });

  test("resident verification submissions cannot bypass the callable workflow", async () => {
    const newResidentDb = testEnvironment.authenticatedContext("verification-resident").firestore();
    const residentReference = doc(newResidentDb, "users", "verification-resident");
    await assertFails(setDoc(
      residentReference,
      profile("verification-resident", "resident", "unverified", { barangay: "Cabcaban", barangayId: "barili_cabcaban" }),
    ));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "verification-resident"), profile(
        "verification-resident",
        "resident",
        "unverified",
        { barangay: "Cabcaban", barangayId: "barili_cabcaban" },
      ));
    });
    await assertFails(updateDoc(residentReference, {
      status: "pending_review",
      accountStatus: "active",
      verificationStatus: "submitted",
      verificationData: {
        documentType: "Barangay Certificate",
        documentUrl: "https://example.com/document.jpg",
        submittedAt: new Date(),
      },
      updatedAt: new Date(),
    }));

    const barangayDb = dbFor("barangay");
    await assertFails(updateDoc(doc(barangayDb, "users", "verification-resident"), {
      verificationStatus: "under_review",
    }));
    await assertFails(updateDoc(doc(barangayDb, "users", "verification-resident"), {
      status: "additional_document_required",
      accountStatus: "active",
      verificationStatus: "additional_document_required",
      reviewedAt: new Date(),
      reviewedBy: "barangay",
      reviewNote: "Upload a document that shows your current address.",
    }));
    await assertFails(updateDoc(residentReference, {
      "verificationData.additionalDocumentType": "Utility bill with current address",
      "verificationData.additionalDocumentUrl": "https://example.com/address.jpg",
      "verificationData.additionalDocumentSubmittedAt": new Date(),
      "verificationData.submittedAt": new Date(),
      "verificationData.submissionStage": "additional_document",
      status: "pending_review",
      accountStatus: "active",
      verificationStatus: "submitted",
      updatedAt: new Date(),
    }));
  });

  test("a resident cannot mark their own verification under review or approved", async () => {
    const pendingDb = dbFor("pending-local");
    await assertFails(updateDoc(doc(pendingDb, "users", "pending-local"), {
      verificationStatus: "under_review",
    }));
    await assertFails(updateDoc(doc(pendingDb, "users", "pending-local"), {
      status: "approved",
      verificationStatus: "verified",
    }));
  });

  test("partner organizations cannot access account verification", async () => {
    await assertFails(getDocs(collection(dbFor("partner"), "users")));
    await assertFails(getDoc(doc(dbFor("partner"), "users", "pending-local")));
  });

  test("barangay councilors cannot review resident verification", async () => {
    const councilorDb = dbFor("councilor");
    await assertFails(getDocs(query(collection(councilorDb, "users"), where("barangay", "==", "Cabcaban"))));
    await assertFails(getDoc(doc(councilorDb, "users", "pending-local")));
    await assertFails(updateDoc(doc(councilorDb, "users", "pending-local"), { status: "approved", reviewedBy: "councilor" }));
  });

  test("staff profiles cannot be created from an untrusted client", async () => {
    const residentDb = dbFor("resident");
    await assertFails(setDoc(doc(residentDb, "users", "resident"), profile("resident", "lgu")));
    await assertFails(setDoc(doc(testEnvironment.authenticatedContext("new-staff").firestore(), "users", "new-staff"), profile("new-staff", "organization", "pending")));
  });

  test("new resident profiles are created only by the backend", async () => {
    const newResidentDb = testEnvironment.authenticatedContext("new-resident").firestore();
    await assertFails(setDoc(doc(newResidentDb, "users", "new-resident"), profile("new-resident", "resident", "unverified", { barangay: "Cabcaban", barangayId: "barili_cabcaban" })));
  });
});

describe("resident concerns and notifications", () => {
  test("barangay flag notices are private to the recipient and may be marked read", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "notifications", "flag-to-barangay"), {
        userId: "barangay", type: "concern_flag_barangay", residentId: "resident",
        referenceId: "concern-resident", reason: "Nonsense / Spam", read: false,
      });
    });
    const barangayDb = dbFor("barangay");
    await assertSucceeds(getDocs(query(collection(barangayDb, "notifications"),
      where("userId", "==", "barangay"), where("type", "==", "concern_flag_barangay"))));
    await assertSucceeds(updateDoc(doc(barangayDb, "notifications", "flag-to-barangay"), { read: true }));
    await assertFails(getDoc(doc(dbFor("vice-captain"), "notifications", "flag-to-barangay")));
    await assertFails(updateDoc(doc(barangayDb, "notifications", "flag-to-barangay"), { residentId: "other" }));
  });
  test("restricted residents keep read access but cannot create help posts or read private flags", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, "users", "resident"), { restrictionStatus: "active", restrictionEndDate: null });
      await setDoc(doc(db, "concern_flags", "concern-resident"), { concernId: "concern-resident", residentId: "resident", reason: "Nonsense / Spam" });
    });
    const residentDb = dbFor("resident");
    await assertSucceeds(getDoc(doc(residentDb, "users", "resident")));
    await assertSucceeds(getDoc(doc(residentDb, "submissions", "concern-resident")));
    await assertFails(getDoc(doc(residentDb, "concern_flags", "concern-resident")));
    await assertFails(setDoc(doc(residentDb, "jobs", "restricted-job"), {
      title: "Worker needed", posterId: "resident", location: "Cabcaban",
      description: "Need help moving farm supplies.", category: "request", helpCategory: "Manual Labor",
      dateNeeded: "Oct 10, 2026 - 08:00 AM", scheduledAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      contact: "+639171234567", contactPreference: "Both", status: "Active", helpersNeeded: 2,
    }));
    await assertFails(updateDoc(doc(dbFor("admin"), "users", "resident"), { status: "suspended", accountStatus: "disabled" }));
  });
  test("new routed concern visibility follows location, privacy, and category", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "organizations", "partner"), { name: "Safety Partner", status: "verified", categoryId: "peace_public_safety" });
      await setDoc(doc(db, "users", "wrong-category"), profile("wrong-category", "organization", "approved", { organizationId: "other-partner" }));
      await setDoc(doc(db, "organizations", "other-partner"), { name: "Road Partner", status: "verified", categoryId: "roads_accessibility" });
      for (const visibility of ["public", "private"]) {
        await setDoc(doc(db, "submissions", `${visibility}-routed`), {
          schemaVersion: 4, id: `${visibility}-routed`, userId: "resident", reporterIds: ["resident"],
          visibility, categoryId: "peace_public_safety", barangay: "Poblacion", barangayId: "barili_poblacion",
          recipientBarangayId: visibility === "public" ? "barili_poblacion" : "",
          organizationIds: ["partner"], organizationId: "partner", leadOrganizationId: "", receiverAccountId: "",
          status: "new", date: new Date(),
        });
      }
      await setDoc(doc(db, "submissions", "private-barangay"), {
        schemaVersion: 4, id: "private-barangay", userId: "other", reporterIds: ["other"],
        visibility: "private", categoryId: "public_safety", barangay: "Poblacion", barangayId: "barili_poblacion",
        recipientBarangayId: "barili_poblacion", recipientType: "barangay", recipientId: "barangay-barili_poblacion",
        organizationIds: [], organizationId: "", leadOrganizationId: "", receiverAccountId: "other-official",
        status: "new", date: new Date(),
      });
      await setDoc(doc(db, "submissions", "public-routed", "reports", "resident"), { reporterId: "resident", reporterName: "Private name" });
      await setDoc(doc(db, "submissions", "public-routed", "internal_notes", "staff-note"), { note: "Staff-only action", createdAt: new Date() });
      await setDoc(doc(db, "public_concern_summaries", "public-routed"), {
        id: "public-routed", visibility: "public", barangayId: "barili_poblacion",
        title: "Public concern", reporterCount: 1,
      });
    });
    await assertFails(getDoc(doc(dbFor("other"), "submissions", "public-routed")));
    await assertSucceeds(getDoc(doc(dbFor("other"), "public_concern_summaries", "public-routed")));
    await assertFails(getDoc(doc(dbFor("resident"), "public_concern_summaries", "public-routed")));
    await assertSucceeds(getDocs(query(collection(dbFor("other"), "public_concern_summaries"), where("barangayId", "==", "barili_poblacion"), where("visibility", "==", "public"))));
    await assertFails(getDocs(query(collection(dbFor("resident"), "public_concern_summaries"), where("barangayId", "==", "barili_poblacion"), where("visibility", "==", "public"))));
    await assertFails(setDoc(doc(dbFor("other"), "public_concern_summaries", "forged"), {
      visibility: "public", barangayId: "barili_poblacion", title: "Forged concern",
    }));
    await assertFails(getDoc(doc(dbFor("other"), "submissions", "private-routed")));
    await assertFails(getDoc(doc(dbFor("barangay"), "submissions", "public-routed")));
    await assertFails(getDoc(doc(dbFor("barangay"), "submissions", "private-routed")));
    await assertFails(getDoc(doc(dbFor("other-official"), "submissions", "public-routed")));
    await assertFails(getDoc(doc(dbFor("other-official"), "submissions", "private-routed")));
    await assertSucceeds(getDoc(doc(dbFor("other-official"), "submissions", "private-barangay")));
    await assertFails(getDoc(doc(dbFor("secretary"), "submissions", "private-barangay")));
    await assertSucceeds(getDoc(doc(dbFor("resident"), "submissions", "private-routed")));
    await assertSucceeds(getDoc(doc(dbFor("partner"), "submissions", "private-routed")));
    await assertSucceeds(getDoc(doc(dbFor("partner"), "submissions", "public-routed", "internal_notes", "staff-note")));
    await assertFails(getDoc(doc(dbFor("resident"), "submissions", "public-routed", "internal_notes", "staff-note")));
    await assertFails(getDoc(doc(dbFor("wrong-category"), "submissions", "private-routed")));
    await assertSucceeds(addDoc(collection(dbFor("partner"), "notifications"), {
      type: "concern_update", referenceId: "private-routed", userId: "resident",
    }));
    await assertFails(addDoc(collection(dbFor("wrong-category"), "notifications"), {
      type: "concern_update", referenceId: "private-routed", userId: "resident",
    }));
    await assertFails(getDoc(doc(dbFor("other"), "submissions", "public-routed", "reports", "resident")));
    await assertSucceeds(getDoc(doc(dbFor("partner"), "submissions", "public-routed", "reports", "resident")));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "users", "other"), { verificationStatus: "not_submitted" });
      await updateDoc(doc(context.firestore(), "submissions", "public-routed"), { reporterIds: ["resident", "other"] });
    });
    await assertSucceeds(getDoc(doc(dbFor("other"), "submissions", "public-routed")));
    await assertFails(getDoc(doc(dbFor("other"), "public_concern_summaries", "public-routed")));
  });
  test("resident concern creation is backend-only and residents query only their own concerns", async () => {
    const residentDb = dbFor("resident");
    await assertFails(setDoc(doc(residentDb, "submissions", "new-concern"), {
      schemaVersion: 2,
      id: "new-concern",
      userId: "resident",
      residentName: "Resident",
      barangay: "Cabcaban",
      requestedAction: "Please investigate.",
      title: "Road concern",
      description: "There is a large pothole near the public market.",
      category: "Road Repair",
      location: "Public market entrance",
      status: "submitted",
      date: new Date(),
    }));
    await assertSucceeds(getDocs(query(collection(residentDb, "submissions"), where("userId", "==", "resident"))));
    await assertFails(getDoc(doc(residentDb, "submissions", "concern-other")));
    await assertFails(updateDoc(doc(residentDb, "submissions", "concern-resident"), { status: "resolved" }));
  });

  test("IT administrators have view-only oversight across submissions", async () => {
    const adminDb = dbFor("admin");
    await assertSucceeds(getDocs(collection(adminDb, "submissions")));
    await assertSucceeds(getDocs(query(collection(adminDb, "submissions"), where("recipientDepartmentId", "==", "it-department"))));
    await assertSucceeds(getDoc(doc(adminDb, "submissions", "concern-it")));
    await assertSucceeds(getDoc(doc(adminDb, "submissions", "concern-resident")));
    await assertSucceeds(getDoc(doc(adminDb, "audit_logs", "it-concern-audit")));
    await assertFails(getDoc(doc(adminDb, "audit_logs", "tourism-concern-audit")));
    await assertSucceeds(getDoc(doc(adminDb, "notifications", "it-concern-notice")));
    await assertFails(getDoc(doc(adminDb, "notifications", "tourism-concern-notice")));
    await assertFails(updateDoc(doc(adminDb, "submissions", "concern-resident"), { status: "being_handled" }));
    await assertSucceeds(updateDoc(doc(adminDb, "submissions", "concern-it"), { status: "being_handled" }));
    await assertSucceeds(addDoc(collection(adminDb, "notifications"), {
      type: "concern_update", referenceId: "concern-it", userId: "resident",
    }));
    await assertFails(addDoc(collection(adminDb, "notifications"), {
      type: "concern_update", referenceId: "concern-tourism", userId: "resident",
    }));
    await assertSucceeds(addDoc(collection(adminDb, "submissions", "concern-it", "internal_notes"), { note: "Internal", createdAt: new Date() }));
    await assertFails(getDocs(collection(dbFor("resident"), "submissions", "concern-it", "internal_notes")));
  });

  test("barangay case managers can query and update concerns only in their barangay", async () => {
    const barangayDb = dbFor("barangay");
    await assertFails(getDocs(query(collection(barangayDb, "submissions"), where("barangayId", "==", "barili_cabcaban"))));
    await assertFails(getDocs(query(collection(barangayDb, "submissions"), where("barangayId", "==", "barili_cabcaban"), where("visibility", "==", "public"))));
    const directedConcerns = await assertSucceeds(getDocs(query(collection(dbFor("secretary"), "submissions"), where("barangayId", "==", "barili_cabcaban"), where("recipientType", "==", "barangay"))));
    assert.deepEqual(directedConcerns.docs.map((item) => item.id).sort(), ["concern-resident", "private-cabcaban-barangay"]);
    await assertFails(getDoc(doc(barangayDb, "submissions", "private-cabcaban-org")));
    await assertFails(getDocs(collection(barangayDb, "submissions")));
    await assertSucceeds(updateDoc(doc(barangayDb, "submissions", "concern-resident"), {
      status: "in_progress",
      priority: "high",
      department: "Barangay Office",
      updatedAt: new Date(),
      updatedBy: "barangay",
      statusHistory: [],
    }));
    await assertSucceeds(addDoc(collection(barangayDb, "notifications"), {
      type: "concern_update", referenceId: "concern-resident", userId: "resident",
    }));
    await assertFails(addDoc(collection(barangayDb, "notifications"), {
      type: "concern_update", referenceId: "concern-it", userId: "resident",
    }));
    await assertSucceeds(updateDoc(doc(dbFor("secretary"), "submissions", "concern-resident"), {
      priority: "medium",
      updatedAt: new Date(),
      updatedBy: "secretary",
    }));
    await assertFails(updateDoc(doc(barangayDb, "submissions", "concern-other"), {
      status: "in_progress",
      updatedAt: new Date(),
      updatedBy: "barangay",
    }));
  });

  test("non-recipients, including the Mayor, cannot open concern records", async () => {
    const mayorDb = dbFor("mayor");
    await assertFails(getDocs(collection(mayorDb, "submissions")));
    await assertFails(getDoc(doc(mayorDb, "submissions", "concern-resident")));
    await assertFails(getDoc(doc(mayorDb, "submissions", "concern-other")));
    await assertFails(updateDoc(doc(mayorDb, "submissions", "concern-resident"), {
      status: "resolved",
      updatedAt: new Date(),
      updatedBy: "mayor",
    }));
    await assertFails(addDoc(collection(mayorDb, "submissions", "concern-resident", "internal_notes"), {
      note: "Executive note",
      createdAt: new Date(),
    }));
    await assertFails(getDocs(collection(mayorDb, "users")));
    await assertFails(getDocs(collection(mayorDb, "audit_logs")));
  });

  test("only administrators create notifications while owners can mark them read", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "notifications", "resident-note"), { userId: "resident", read: false });
    });
    const residentDb = dbFor("resident");
    await assertSucceeds(getDocs(query(collection(residentDb, "notifications"), where("userId", "==", "resident"))));
    await assertSucceeds(updateDoc(doc(residentDb, "notifications", "resident-note"), { read: true }));
    await assertFails(addDoc(collection(residentDb, "notifications"), { userId: "resident", read: false }));
    await assertSucceeds(addDoc(collection(dbFor("admin"), "notifications"), { userId: "resident", read: false }));
  });
});

describe("organization registration requests", () => {
  test("self-registration is backend-created and private to applicant and Admin", async () => {
    const requestData = {
      createdUserId: "new-organization", requestedById: "new-organization",
      role: "organization", organizationId: "new-organization",
      barangayId: "barili_poblacion",
      creationSource: "organization_self_registration", status: "pending",
      proofStoragePath: "organization_registration_proofs/new-organization/proof-123e4567-e89b-12d3-a456-426614174000.jpg",
    };
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "staff_account_requests", "new-organization-request"), requestData);
    });
    await assertSucceeds(getDoc(doc(dbFor("new-organization"), "staff_account_requests", "new-organization-request")));
    await assertSucceeds(getDoc(doc(dbFor("admin"), "staff_account_requests", "new-organization-request")));
    await assertFails(getDoc(doc(dbFor("other"), "staff_account_requests", "new-organization-request")));
    await assertFails(getDoc(doc(dbFor("partner"), "staff_account_requests", "new-organization-request")));
    await assertFails(getDoc(doc(dbFor("other-official"), "staff_account_requests", "new-organization-request")));
    await assertFails(setDoc(doc(dbFor("new-organization"), "staff_account_requests", "forged-registration"), requestData));
  });
});

describe("publishing, alerts, and system settings", () => {
  const itPublisher = {
    departmentId: "it-department",
    publisherEntityId: "it-department",
    publisherEntityType: "lgu_department",
    publisherEntityName: "LGU IT Department",
  };

  test("other announcement categories require a separate bounded custom category", async () => {
    const adminDb = dbFor("admin");
    const municipalAudience = {
      visibility: "public",
      targetBarangay: "All Barangays",
      targetBarangays: [],
      audienceKeys: ["municipality:barili"],
    };
    await assertSucceeds(setDoc(
      doc(adminDb, "posts", "custom-category"),
      announcement("admin", "super_admin", "approved", {
        ...municipalAudience,
        ...itPublisher,
        category: "Other Notice",
        customCategory: "Transportation Update",
      }),
    ));
    await assertFails(setDoc(
      doc(adminDb, "posts", "missing-custom-category"),
      announcement("admin", "super_admin", "approved", {
        ...municipalAudience,
        ...itPublisher,
        category: "Other Notice",
        customCategory: null,
      }),
    ));
    await assertFails(setDoc(
      doc(adminDb, "posts", "long-custom-category"),
      announcement("admin", "super_admin", "approved", {
        ...municipalAudience,
        ...itPublisher,
        category: "Other Notice",
        customCategory: "x".repeat(51),
      }),
    ));
  });

  test("verified publishers post directly within their authorized geographic scope", async () => {
    await assertSucceeds(setDoc(doc(dbFor("admin"), "posts", "municipal"), announcement("admin", "super_admin", "approved", {
      visibility: "public",
      targetBarangay: "All Barangays",
      targetBarangays: [],
      audienceKeys: ["municipality:barili"],
      ...itPublisher,
    })));
    await assertSucceeds(setDoc(doc(dbFor("tourism"), "posts", "tourism-public"), announcement("tourism", "lgu", "approved", {
      visibility: "public",
      targetBarangay: "All Barangays",
      targetBarangays: [],
      audienceKeys: ["municipality:barili"],
      departmentId: "tourism-department",
      publisherEntityId: "tourism-department",
      publisherEntityType: "lgu_department",
      publisherEntityName: "LGU Tourism Department",
    })));
    await assertFails(setDoc(doc(dbFor("tourism"), "posts", "spoofed-engineering"), announcement("tourism", "lgu", "approved", {
      visibility: "public",
      targetBarangay: "All Barangays",
      targetBarangays: [],
      audienceKeys: ["municipality:barili"],
      departmentId: "engineering-department",
      publisherEntityId: "engineering-department",
      publisherEntityType: "lgu_department",
      publisherEntityName: "LGU Engineering Department",
    })));
    const partnerDb = dbFor("partner");
    await assertSucceeds(setDoc(doc(partnerDb, "posts", "partner-local"), announcement("partner", "organization", "approved", { publisherEntityId: "partner" })));
    await assertFails(setDoc(doc(partnerDb, "posts", "partner-review"), announcement("partner", "organization", "pending_review", { publisherEntityId: "partner" })));
    await assertFails(setDoc(doc(partnerDb, "posts", "partner-outside-area"), announcement("partner", "organization", "approved", { targetBarangay: "Poblacion", targetBarangays: ["Poblacion"], audienceKeys: ["barangay:Poblacion"], publisherEntityId: "partner" })));
    await assertSucceeds(setDoc(doc(partnerDb, "posts", "partner-municipality"), announcement("partner", "organization", "approved", { visibility: "public", targetBarangay: "All Barangays", targetBarangays: [], audienceKeys: ["municipality:barili"], publisherEntityId: "partner" })));
    await assertFails(setDoc(doc(dbFor("partner-no-org"), "posts", "partner-no-org-public"), announcement("partner-no-org", "organization", "approved", { visibility: "public", targetBarangay: "All Barangays", targetBarangays: [], audienceKeys: ["municipality:barili"] })));

    const barangayDb = dbFor("barangay");
    await assertSucceeds(setDoc(doc(barangayDb, "posts", "barangay-local"), announcement("barangay", "barangay_captain", "approved", { barangayId: "barili_cabcaban" })));
    await assertSucceeds(setDoc(doc(dbFor("secretary"), "posts", "secretary-local"), announcement("secretary", "barangay_secretary", "approved", { barangayId: "barili_cabcaban" })));
    await assertFails(setDoc(doc(barangayDb, "posts", "barangay-review"), announcement("barangay", "barangay_captain", "pending_review", { barangayId: "barili_cabcaban" })));
    await assertFails(setDoc(doc(barangayDb, "posts", "barangay-public"), announcement("barangay", "barangay_captain", "approved", { visibility: "public", targetBarangay: "All Barangays", targetBarangays: [], audienceKeys: ["municipality:barili"], barangayId: "barili_cabcaban" })));
    await assertFails(setDoc(doc(barangayDb, "posts", "barangay-other"), announcement("barangay", "barangay_captain", "approved", { targetBarangay: "Poblacion", targetBarangays: ["Poblacion"], audienceKeys: ["barangay:Poblacion"], barangayId: "barili_cabcaban" })));
    await assertSucceeds(setDoc(doc(dbFor("councilor"), "posts", "councilor-local"), announcement("councilor", "barangay_councilor", "approved", { barangayId: "barili_cabcaban" })));
    await assertFails(setDoc(doc(dbFor("treasurer"), "posts", "treasurer-local"), announcement("treasurer", "barangay_councilor", "approved", { barangayId: "barili_cabcaban" })));
  });

  test("the Mayor publishes only under the Mayor's own identity", async () => {
    const mayorDb = dbFor("mayor");
    const mayorPublisher = {
      visibility: "public",
      targetBarangay: "All Barangays",
      targetBarangays: [],
      audienceKeys: ["municipality:barili"],
      departmentId: "",
      publisherEntityId: "mayor",
      publisherEntityType: "mayor",
      publisherEntityName: "mayor",
    };
    await assertSucceeds(setDoc(
      doc(mayorDb, "posts", "mayor-public"),
      announcement("mayor", "mayor", "approved", mayorPublisher),
    ));
    await assertFails(setDoc(
      doc(mayorDb, "posts", "mayor-spoofed"),
      announcement("mayor", "mayor", "approved", {
        ...mayorPublisher,
        publisherEntityName: "Municipality of Barili",
      }),
    ));
    await assertSucceeds(updateDoc(doc(mayorDb, "posts", "mayor-public"), {
      title: "Updated community message",
      updatedAt: new Date(),
    }));
    await assertFails(updateDoc(doc(mayorDb, "posts", "approved-post"), { title: "Changed by Mayor" }));
    await assertSucceeds(addDoc(collection(mayorDb, "audit_logs"), {
      action: "announcement_published",
      actorId: "mayor",
      createdAt: new Date(),
    }));
  });

  test("authorized announcement publishers can edit, archive, and delete their records", async () => {
    const tourismPeerDb = dbFor("tourism-peer");
    const tourismPost = doc(tourismPeerDb, "posts", "tourism-draft");
    await assertSucceeds(updateDoc(tourismPost, { title: "Updated by department peer", updatedAt: new Date() }));
    await assertSucceeds(updateDoc(tourismPost, {
      status: "archived", notificationRequested: false, archivedAt: new Date(),
      archivedBy: "tourism-peer", updatedAt: new Date(),
    }));
    await assertSucceeds(deleteDoc(tourismPost));
    await assertFails(deleteDoc(doc(tourismPeerDb, "posts", "engineering-draft")));

    const mayorDb = dbFor("mayor");
    const mayorPost = doc(mayorDb, "posts", "mayor-managed");
    await assertSucceeds(setDoc(mayorPost, announcement("mayor", "mayor", "approved", {
      visibility: "public", targetBarangay: "All Barangays", targetBarangays: [],
      audienceKeys: ["municipality:barili"], departmentId: "", publisherEntityId: "mayor",
      publisherEntityType: "mayor", publisherEntityName: "mayor",
    })));
    await assertSucceeds(updateDoc(mayorPost, { status: "archived", updatedAt: new Date() }));
    await assertSucceeds(deleteDoc(mayorPost));
    await assertFails(deleteDoc(doc(mayorDb, "posts", "approved-post")));

    const partnerDb = dbFor("partner");
    const partnerPost = doc(partnerDb, "posts", "partner-managed");
    await assertSucceeds(setDoc(partnerPost, announcement("partner", "organization", "approved", {
      publisherEntityId: "partner",
    })));
    await assertSucceeds(updateDoc(partnerPost, { status: "archived", updatedAt: new Date() }));
    await assertSucceeds(deleteDoc(partnerPost));
    await assertFails(deleteDoc(doc(partnerDb, "posts", "targeted-post")));

    const barangayPost = doc(dbFor("barangay"), "posts", "barangay-managed");
    await assertSucceeds(setDoc(barangayPost, announcement("barangay", "barangay_captain", "approved", {
      barangayId: "barili_cabcaban",
    })));
    const secretaryPost = doc(dbFor("secretary"), "posts", "barangay-managed");
    await assertSucceeds(updateDoc(secretaryPost, { title: "Updated by barangay secretary", updatedAt: new Date() }));
    await assertSucceeds(deleteDoc(secretaryPost));
    await assertFails(deleteDoc(doc(dbFor("other-official"), "posts", "barangay-local")));
  });

  test("published announcement reads are enforced by municipality and barangay", async () => {
    const anonymousDb = testEnvironment.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anonymousDb, "posts", "approved-post")));
    await assertFails(getDoc(doc(anonymousDb, "posts", "pending-post")));
    await assertSucceeds(getDoc(doc(dbFor("resident"), "posts", "approved-post")));
    await assertSucceeds(getDoc(doc(dbFor("resident"), "posts", "targeted-post")));
    await assertFails(getDoc(doc(dbFor("other"), "posts", "targeted-post")));
  });

  test("residents can query municipality-wide announcements", async () => {
    await assertSucceeds(getDocs(collection(dbFor("resident"), "announcement_feeds", "municipality:barili", "posts")));
  });

  test("residents can query announcements targeted to their barangay", async () => {
    await assertSucceeds(getDocs(collection(dbFor("resident"), "announcement_feeds", "barangay:Cabcaban", "posts")));
    await assertFails(getDocs(collection(dbFor("resident"), "announcement_feeds", "barangay:Poblacion", "posts")));
  });

  test("barangay officials read both published feeds but not another barangay's feed", async () => {
    const barangayDb = dbFor("secretary");
    await assertSucceeds(getDocs(collection(barangayDb, "announcement_feeds", "municipality:barili", "posts")));
    await assertSucceeds(getDocs(collection(barangayDb, "announcement_feeds", "barangay:Cabcaban", "posts")));
    await assertFails(getDocs(collection(barangayDb, "announcement_feeds", "barangay:Poblacion", "posts")));
  });

  test("barangay officials edit, archive, restore, and delete only their barangay posts", async () => {
    const captainDb = dbFor("barangay");
    const secretaryDb = dbFor("secretary");
    const postRef = doc(secretaryDb, "posts", "shared-barangay-post");
    await assertSucceeds(setDoc(doc(captainDb, "posts", "shared-barangay-post"),
      announcement("barangay", "barangay_captain", "approved", { barangayId: "barili_cabcaban" })));
    await assertSucceeds(getDocs(query(collection(secretaryDb, "posts"), where("barangayId", "==", "barili_cabcaban"))));
    await assertSucceeds(updateDoc(postRef, { title: "Edited by secretary", updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(dbFor("other-official"), "posts", "shared-barangay-post"), { title: "Wrong barangay" }));
    await assertFails(updateDoc(doc(secretaryDb, "posts", "approved-post"), { title: "Changed LGU post" }));
    await assertFails(deleteDoc(doc(secretaryDb, "posts", "approved-post")));
    await assertSucceeds(updateDoc(postRef, {
      status: "archived", notificationRequested: false, archivedAt: serverTimestamp(),
      archivedBy: "secretary", updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(postRef, {
      status: "draft", archivedAt: null, archivedBy: null, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(postRef, { status: "approved", updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(postRef));
  });

  test("residents cannot list the canonical publishing collection", async () => {
    await assertFails(getDocs(query(
      collection(dbFor("resident"), "posts"),
      where("status", "==", "approved"),
    )));
  });

  test("emergency alerts are backend-only while system settings stay admin-only", async () => {
    await assertFails(setDoc(doc(dbFor("resident"), "alerts", "alert"), { active: true }));
    await assertFails(setDoc(doc(dbFor("admin"), "alerts", "alert"), {
      title: "Flood warning",
      message: "Flood waters are rising near the river.",
      instructions: "Move to higher ground and follow official directions.",
      alertType: "Flood",
      severity: "warning",
      visibility: "public",
      targetBarangays: ["All Barangays"],
      audienceKeys: ["municipality:barili"],
      expiresAt: "2026-08-30T12:00:00.000Z",
      active: true,
      status: "active",
      notificationRequested: true,
      createdBy: "admin",
    }));
    await assertSucceeds(getDoc(doc(dbFor("resident"), "system", "settings")));
    await assertFails(updateDoc(doc(dbFor("resident"), "system", "settings"), { concernSlaHours: 24 }));
    await assertSucceeds(updateDoc(doc(dbFor("admin"), "system", "settings"), { concernSlaHours: 24 }));
  });

  test("residents manage only their own device token and read only their emergency status", async () => {
    const residentDb = dbFor("resident");
    await assertSucceeds(setDoc(doc(residentDb, "device_tokens", "resident-device"), {
      userId: "resident",
      token: "resident-fcm-token-with-enough-length",
      active: true,
    }));
    await assertFails(setDoc(doc(dbFor("other"), "device_tokens", "resident-device-2"), {
      userId: "resident",
      token: "other-fcm-token-with-enough-length",
      active: true,
    }));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "resident_emergency_statuses", "alert_resident"), {
        emergencyId: "alert",
        residentId: "resident",
        status: "delivered",
      });
    });
    await assertSucceeds(getDoc(doc(residentDb, "resident_emergency_statuses", "alert_resident")));
    await assertFails(getDoc(doc(dbFor("other"), "resident_emergency_statuses", "alert_resident")));
    await assertFails(updateDoc(doc(residentDb, "resident_emergency_statuses", "alert_resident"), {
      status: "acknowledged",
    }));
  });
});

describe("service collections", () => {
  test("document requests are private to their owner and administrators", async () => {
    const residentDb = dbFor("resident");
    await assertSucceeds(setDoc(doc(residentDb, "document_requests", "request"), {
      userId: "resident",
      applicantName: "Resident User",
      type: "Barangay Clearance",
      status: "Pending",
      paymentStatus: "Unpaid",
    }));
    await assertSucceeds(getDocs(query(collection(residentDb, "document_requests"), where("userId", "==", "resident"))));
    await assertFails(getDoc(doc(dbFor("other"), "document_requests", "request")));
    await assertSucceeds(updateDoc(doc(dbFor("admin"), "document_requests", "request"), { status: "Completed" }));
  });

  test("helpdesk tickets and messages stay scoped to their owner", async () => {
    const residentDb = dbFor("resident");
    await assertSucceeds(addDoc(collection(residentDb, "helpdesk_tickets", "resident-ticket", "messages"), { senderId: "resident", message: "Hello" }));
    await assertFails(addDoc(collection(dbFor("other"), "helpdesk_tickets", "resident-ticket", "messages"), { senderId: "other", message: "Injected" }));
  });

  test("emergency reports are private to residents and visible to responders", async () => {
    await assertSucceeds(getDoc(doc(dbFor("resident"), "emergency_reports", "resident-emergency")));
    await assertFails(getDoc(doc(dbFor("other"), "emergency_reports", "resident-emergency")));
    await assertSucceeds(getDoc(doc(dbFor("barangay"), "emergency_reports", "resident-emergency")));
    await assertFails(getDoc(doc(dbFor("barangay"), "emergency_reports", "other-emergency")));
    await assertSucceeds(getDoc(doc(dbFor("partner"), "emergency_reports", "resident-emergency")));
    await assertFails(getDoc(doc(dbFor("partner"), "emergency_reports", "other-emergency")));
  });

  test("clients cannot create emergency reports", async () => {
    await assertFails(setDoc(doc(dbFor("resident"), "emergency_reports", "forged"), {
      reporterId: "resident", barangay: "Cabcaban", routingKey: "bfp", status: "resolved",
    }));
  });

  test("emergency collection queries must match the caller's responder scope", async () => {
    await assertSucceeds(getDocs(query(
      collection(dbFor("resident"), "emergency_reports"),
      where("reporterId", "==", "resident"),
    )));
    await assertSucceeds(getDocs(query(
      collection(dbFor("barangay"), "emergency_reports"),
      where("barangay", "==", "Cabcaban"),
    )));
    await assertSucceeds(getDocs(query(
      collection(dbFor("partner"), "emergency_reports"),
      where("routingKey", "in", ["bfp"]),
    )));
    await assertFails(getDocs(collection(dbFor("barangay"), "emergency_reports")));
    await assertFails(getDocs(collection(dbFor("partner"), "emergency_reports")));
  });

  test("responders update only emergencies routed to their scope", async () => {
    await assertSucceeds(updateDoc(doc(dbFor("barangay"), "emergency_reports", "resident-emergency"), { status: "acknowledged", statusUpdatedAt: new Date(), routedAgency: "Barangay Cabcaban", statusHistory: [], updatedBy: "barangay" }));
    await assertFails(updateDoc(doc(dbFor("barangay"), "emergency_reports", "other-emergency"), { status: "acknowledged", statusUpdatedAt: new Date(), updatedBy: "barangay" }));
    await assertSucceeds(updateDoc(doc(dbFor("partner"), "emergency_reports", "resident-emergency"), { status: "responding", statusUpdatedAt: new Date(), routedAgency: "Barili Fire Station", statusHistory: [], updatedBy: "partner" }));
    await assertFails(updateDoc(doc(dbFor("partner"), "emergency_reports", "other-emergency"), { status: "responding", statusUpdatedAt: new Date(), updatedBy: "partner" }));
    await assertSucceeds(addDoc(collection(dbFor("partner"), "notifications"), { userId: "resident", type: "emergency_update", referenceId: "resident-emergency", actorId: "partner" }));
    await assertFails(addDoc(collection(dbFor("partner"), "notifications"), { userId: "other", type: "emergency_update", referenceId: "other-emergency", actorId: "partner" }));
  });

  test("marketplace ownership, jobs, and civic points enforce their boundaries", async () => {
    await assertSucceeds(setDoc(doc(dbFor("resident"), "marketplace", "item"), {
      sellerId: "resident",
      name: "Native eggs",
      price: "120.00",
      priceUnit: "tray",
      description: "Fresh native eggs collected this morning.",
      imageUrl: "https://example.com/eggs.jpg",
      category: "Fresh Today",
      location: "Cabcaban",
      quantity: 10,
      status: "Available",
    }));
    await assertFails(setDoc(doc(dbFor("other"), "marketplace", "spoofed"), { sellerId: "resident" }));
    await assertFails(setDoc(doc(dbFor("resident"), "marketplace", "invalid-price"), {
      sellerId: "resident",
      name: "Native eggs",
      price: "120.999",
      priceUnit: "tray",
      description: "Fresh native eggs collected this morning.",
      imageUrl: "https://example.com/eggs.jpg",
      category: "Fresh Today",
      location: "Cabcaban",
      quantity: 10,
      status: "Available",
    }));
    const interestRequest = {
      itemId: "item",
      itemName: "Native eggs",
      itemImageUrl: "https://example.com/eggs.jpg",
      buyerId: "other",
      buyerName: "Other Resident",
      sellerId: "resident",
      sellerName: "Resident",
      participantIds: ["other", "resident"],
      initialMessage: "Interested ko sa native eggs.",
      lastMessage: "Interested ko sa native eggs.",
      status: "pending",
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    await assertSucceeds(setDoc(
      doc(dbFor("other"), "marketplace_conversations", "buyer-request"),
      interestRequest,
    ));
    await assertFails(setDoc(
      doc(dbFor("resident"), "marketplace_conversations", "self-request"),
      {
        ...interestRequest,
        buyerId: "resident",
        buyerName: "Resident",
        participantIds: ["resident", "resident"],
      },
    ));
    await assertSucceeds(setDoc(doc(dbFor("resident"), "jobs", "job"), {
      title: "Worker needed",
      posterId: "resident",
      location: "Cabcaban",
      description: "Need help moving farm supplies.",
      category: "request",
      helpCategory: "Manual Labor",
      dateNeeded: "Aug 30, 2026 - 08:00 AM",
      scheduledAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      contact: "+639171234567",
      contactPreference: "Both",
      status: "Active",
      helpersNeeded: 2,
    }));
    await assertFails(setDoc(doc(dbFor("other"), "jobs", "spoofed-job"), { title: "Spoofed", posterId: "resident" }));
    await assertFails(setDoc(doc(dbFor("resident"), "jobs", "invalid-contact"), {
      title: "Worker needed",
      posterId: "resident",
      location: "Cabcaban",
      description: "Need help moving farm supplies.",
      category: "request",
      helpCategory: "Manual Labor",
      dateNeeded: "Aug 30, 2026 - 08:00 AM",
      scheduledAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      contact: "0917123456",
      contactPreference: "Both",
      status: "Active",
      helpersNeeded: 2,
    }));
    await assertFails(setDoc(doc(dbFor("other"), "jobs", "job", "interests", "other"), {
      volunteerId: "other",
      volunteerName: "Other Resident",
      timestamp: new Date(),
      status: "pending",
    }));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "jobs", "job", "interests", "other"), {
        volunteerId: "other",
        volunteerName: "Other Resident",
        timestamp: new Date(),
        status: "pending",
      });
    });
    await assertSucceeds(getDoc(doc(dbFor("resident"), "jobs", "job", "interests", "other")));
    await assertFails(updateDoc(doc(dbFor("resident"), "jobs", "job", "interests", "other"), {
      status: "accepted",
      reviewedAt: new Date(),
    }));
    await assertFails(setDoc(doc(dbFor("resident"), "jobs", "job", "interests", "other"), {
      volunteerId: "other",
      volunteerName: "Spoofed Resident",
      timestamp: new Date(),
      status: "pending",
    }));
    await assertSucceeds(getDoc(doc(dbFor("resident"), "civic_points", "resident")));
    await assertFails(updateDoc(doc(dbFor("resident"), "civic_points", "resident"), { points: 999 }));
  });
});

describe("IT access policies and private emergency dispatch", () => {
  test("only IT may inspect every policy and staff cannot edit policies directly", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "access_policies", "department_tourism-department"), {
        type: "department", entityId: "tourism-department", granted: [], denied: ["concerns", "announcements"],
      });
    });
    const policy = doc(dbFor("tourism"), "access_policies", "department_tourism-department");
    await assertSucceeds(getDoc(policy));
    await assertFails(getDoc(doc(dbFor("engineering"), "access_policies", "department_tourism-department")));
    await assertSucceeds(getDocs(collection(dbFor("admin"), "access_policies")));
    await assertFails(setDoc(policy, { denied: [] }));
    await assertFails(getDoc(doc(dbFor("tourism"), "submissions", "concern-tourism")));
    await assertFails(getDoc(doc(dbFor("tourism"), "posts", "tourism-draft")));
  });

  test("private requests stay with the source, recipient, and IT; receiving can be revoked", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users", "pnp"), profile("pnp", "organization", "approved", { organizationId: "pnp" }));
      await setDoc(doc(db, "emergency_dispatches", "request-1"), {
        sourceOrganizationId: "partner", destinationOrganizationId: "pnp", title: "Theft", status: "sent",
      });
    });
    const request = (uid) => doc(dbFor(uid), "emergency_dispatches", "request-1");
    await assertSucceeds(getDoc(request("partner")));
    await assertSucceeds(getDoc(request("pnp")));
    await assertSucceeds(getDoc(request("admin")));
    await assertFails(getDoc(request("tourism")));
    await assertFails(getDoc(request("resident")));
    await assertFails(updateDoc(request("pnp"), { status: "resolved" }));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "access_policies", "organization_pnp"), {
        type: "organization", entityId: "pnp", granted: [], denied: ["emergencies:direct:receive"],
      });
    });
    await assertFails(getDoc(request("pnp")));
    await assertSucceeds(getDoc(request("partner")));
  });

  test("a barangay announcement denial blocks edits without hiding public posts", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "posts", "barangay-post"), announcement("barangay", "barangay_captain", "approved", {
        barangayId: "barili_cabcaban",
      }));
      await setDoc(doc(db, "access_policies", "barangay_barili_cabcaban"), {
        type: "barangay", entityId: "barili_cabcaban", granted: [], denied: ["announcements"],
      });
    });
    await assertFails(updateDoc(doc(dbFor("secretary"), "posts", "barangay-post"), {
      title: "Changed after access was removed", updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(doc(dbFor("resident"), "posts", "barangay-post")));
  });

  test("hotline writes require the backend while approved staff can read numbers", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "emergency_contacts", "police"), {
        name: "Police", active: true, contactNumbers: [{ label: "Station", number: "911" }],
      });
    });
    await assertSucceeds(getDoc(doc(dbFor("partner"), "emergency_contacts", "police")));
    await assertFails(getDoc(doc(dbFor("resident"), "emergency_contacts", "police")));
    await assertFails(updateDoc(doc(dbFor("partner"), "emergency_contacts", "police"), { name: "Changed" }));
  });
});

describe("request-linked Bayanihan conversations", () => {
  beforeEach(async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const base = {
        requestId: "job",
        offerId: "other",
        requesterId: "resident",
        helperId: "other",
        participants: ["resident", "other"],
        requestTitle: "Harvest corn",
        requesterName: "Resident",
        helperName: "Other",
        initialMessage: "I can help.",
        createdAt: new Date(),
        lastMessageAt: new Date(),
        requesterUnreadCount: 0,
        helperUnreadCount: 0,
      };
      await Promise.all([
        setDoc(doc(db, "bayanihan_conversations", "active"), { ...base, status: "active" }),
        setDoc(doc(db, "bayanihan_conversations", "pending"), { ...base, status: "pending" }),
        setDoc(doc(db, "bayanihan_conversations", "archived"), { ...base, status: "completed" }),
      ]);
    });
  });

  test("only linked participants can read a conversation", async () => {
    await assertSucceeds(getDoc(doc(dbFor("resident"), "bayanihan_conversations", "active")));
    await assertSucceeds(getDoc(doc(dbFor("other"), "bayanihan_conversations", "active")));
    await assertFails(getDoc(doc(dbFor("pending-local"), "bayanihan_conversations", "active")));
  });

  test("participants can list their inbox ordered by the latest message", async () => {
    const inboxQuery = query(
      collection(dbFor("resident"), "bayanihan_conversations"),
      where("participants", "array-contains", "resident"),
      orderBy("lastMessageAt", "desc"),
    );
    const snapshot = await assertSucceeds(getDocs(inboxQuery));
    assert.equal(snapshot.size, 3);
  });

  test("an active participant can send only as themselves", async () => {
    await assertSucceeds(addDoc(
      collection(dbFor("other"), "bayanihan_conversations", "active", "messages"),
      { senderId: "other", text: "I will arrive at seven.", kind: "message", sentAt: serverTimestamp() },
    ));
    await assertFails(addDoc(
      collection(dbFor("other"), "bayanihan_conversations", "active", "messages"),
      { senderId: "resident", text: "Spoofed", kind: "message", sentAt: serverTimestamp() },
    ));
  });

  test("pending and archived conversations reject new messages", async () => {
    for (const id of ["pending", "archived"]) {
      await assertFails(addDoc(
        collection(dbFor("other"), "bayanihan_conversations", id, "messages"),
        { senderId: "other", text: "Not allowed", kind: "message", sentAt: serverTimestamp() },
      ));
    }
  });

  test("clients cannot alter identities, status, unread state, or reopen archives", async () => {
    await assertFails(updateDoc(doc(dbFor("resident"), "bayanihan_conversations", "active"), {
      helperId: "pending-local",
    }));
    await assertFails(updateDoc(doc(dbFor("resident"), "bayanihan_conversations", "active"), {
      status: "completed",
    }));
    await assertFails(updateDoc(doc(dbFor("resident"), "bayanihan_conversations", "active"), {
      helperUnreadCount: 0,
    }));
    await assertFails(updateDoc(doc(dbFor("resident"), "bayanihan_conversations", "archived"), {
      status: "active",
    }));
  });
});


describe("complaint tracking authorization", () => {
  const id = "BC-2026-100001";
  async function seedComplaint() {
    await testEnvironment.withSecurityRulesDisabled(async context => {
      await setDoc(doc(context.firestore(), "submissions", id), {
        id, kind: "complaint", schemaVersion: 4, complaintTrackingVersion: 1,
        userId: "resident", createdBy: "resident", reporterIds: ["resident"],
        barangay: "Cabcaban", barangayId: "barili_cabcaban", recipientType: "barangay",
        visibility: "private", leadOrganizationId: "", status: "hearing_scheduled",
        date: new Date(), hearings: [], workflowVersion: 2,
      });
      await setDoc(doc(context.firestore(), "submissions", id, "tracking_operations", "saved-operation"), { actorId: "barangay", fingerprint: "private" });
    });
  }
  test("complaint owner and own barangay can read; other residents and barangays cannot", async () => {
    await seedComplaint();
    for (const uid of ["resident", "barangay", "secretary", "mayor"]) await assertSucceeds(getDoc(doc(dbFor(uid), "submissions", id)));
    for (const uid of ["other", "other-official", "pending-staff"]) await assertFails(getDoc(doc(dbFor(uid), "submissions", id)));
  });
  test("complaint queries remain available to the owner and receiving barangay", async () => {
    await seedComplaint();
    await assertSucceeds(getDocs(query(collection(dbFor("resident"), "submissions"), where("userId", "==", "resident"))));
    await assertSucceeds(getDocs(query(collection(dbFor("barangay"), "submissions"), where("barangayId", "==", "barili_cabcaban"), where("recipientType", "==", "barangay"))));
  });
  test("complaint status, schedule, history and kind cannot bypass the callable", async () => {
    await seedComplaint();
    for (const uid of ["resident", "barangay", "secretary", "admin", "mayor"]) {
      const ref = doc(dbFor(uid), "submissions", id);
      await assertFails(updateDoc(ref, { status: "resolved", updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(ref, { summons: { appearanceDate: "tomorrow" } }));
      await assertFails(updateDoc(ref, { statusHistory: [] }));
      await assertFails(updateDoc(ref, { kind: "concern" }));
      await assertFails(deleteDoc(ref));
    }
  });
  test("complaint mutation receipts are inaccessible to clients", async () => {
    await seedComplaint();
    for (const uid of ["resident", "barangay", "admin"]) {
      const ref = doc(dbFor(uid), "submissions", id, "tracking_operations", "saved-operation");
      await assertFails(getDoc(ref));
      await assertFails(setDoc(ref, { actorId: uid }));
    }
  });
});
