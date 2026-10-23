import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, test } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { deleteObject, getBytes, listAll, ref, uploadBytes } from "firebase/storage";

const projectId = "e-sugid";
// Keep local defaults aligned with firebase.json so Firestore-backed Storage
// authorization tests use the same single-project emulator suite.
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8085";
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? "127.0.0.1:9195";
const [firestoreHostname, firestorePort] = firestoreHost.split(":");
const [storageHostname, storagePort] = storageHost.split(":");
const firestoreRules = readFileSync(new URL("../firestore.rules", import.meta.url), "utf8");
const storageRules = readFileSync(new URL("../storage.rules", import.meta.url), "utf8");
const image = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);

let testEnvironment;

const storageFor = (uid) => testEnvironment.authenticatedContext(uid).storage();

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: { host: firestoreHostname, port: Number(firestorePort), rules: firestoreRules },
    storage: { host: storageHostname, port: Number(storagePort), rules: storageRules },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.clearStorage();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, "users", "admin"), { uid: "admin", role: "super_admin", status: "approved", accountStatus: "active", departmentId: "it-department" }),
      setDoc(doc(db, "users", "super-admin"), { uid: "super-admin", role: "super_admin", status: "approved", accountStatus: "active", departmentId: "it-department" }),
      setDoc(doc(db, "users", "mayor"), { uid: "mayor", name: "Mayor Test", role: "mayor", positionTitle: "Municipal Mayor", status: "approved", accountStatus: "active" }),
      setDoc(doc(db, "users", "tourism"), { uid: "tourism", role: "lgu", status: "approved", accountStatus: "active", departmentId: "tourism-department" }),
      setDoc(doc(db, "users", "engineering"), { uid: "engineering", role: "lgu", status: "approved", accountStatus: "active", departmentId: "engineering-department" }),
      setDoc(doc(db, "users", "setup-admin"), { uid: "setup-admin", role: "lgu", status: "approved", setupRequired: true }),
      setDoc(doc(db, "users", "resident"), { uid: "resident", role: "resident", status: "approved", accountStatus: "active", verificationStatus: "verified", barangay: "Cabcaban", barangayId: "barili_cabcaban" }),
      setDoc(doc(db, "users", "unverified"), { uid: "unverified", role: "resident", status: "unverified", accountStatus: "active", verificationStatus: "not_submitted", barangay: "Cabcaban", barangayId: "barili_cabcaban" }),
      setDoc(doc(db, "users", "applicant"), { uid: "applicant", role: "resident", status: "unverified", accountStatus: "active", verificationStatus: "not_submitted", barangay: "Cabcaban", barangayId: "barili_cabcaban" }),
      setDoc(doc(db, "users", "pending-applicant"), { uid: "pending-applicant", role: "resident", status: "pending_review", accountStatus: "active", verificationStatus: "submitted", barangay: "Cabcaban", barangayId: "barili_cabcaban" }),
      setDoc(doc(db, "users", "needs-attention"), { uid: "needs-attention", role: "resident", status: "additional_document_required", accountStatus: "active", verificationStatus: "additional_document_required", barangay: "Cabcaban", barangayId: "barili_cabcaban" }),
      setDoc(doc(db, "users", "other"), { uid: "other", role: "resident", status: "approved", accountStatus: "active", verificationStatus: "verified", barangay: "Poblacion", barangayId: "barili_poblacion" }),
      setDoc(doc(db, "users", "partner"), { uid: "partner", role: "partner", status: "approved", organizationName: "Barili Fire Station" }),
      setDoc(doc(db, "users", "barangay"), { uid: "barangay", role: "barangay", status: "approved", barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true }),
      setDoc(doc(db, "users", "vice-captain"), { uid: "vice-captain", role: "barangay_vice_captain", status: "approved", accountStatus: "active", barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true }),
      setDoc(doc(db, "users", "delegated"), { uid: "delegated", role: "barangay_councilor", status: "approved", accountStatus: "active", barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true }),
      setDoc(doc(db, "users", "treasurer"), { uid: "treasurer", role: "barangay_councilor", status: "approved", accountStatus: "active", barangay: "Cabcaban", barangayId: "barili_cabcaban", positionCode: "barangay_treasurer", canVerifyResidents: false }),
      setDoc(doc(db, "users", "outside-official"), { uid: "outside-official", role: "barangay_secretary", status: "approved", accountStatus: "active", barangay: "Poblacion", barangayId: "barili_poblacion", canVerifyResidents: true }),
      setDoc(doc(db, "emergency_reports", "fire-report"), { reporterId: "resident", barangay: "Cabcaban", routingKey: "bfp" }),
      setDoc(doc(db, "emergency_reports", "health-report"), { reporterId: "resident", barangay: "Poblacion", routingKey: "health" }),
      setDoc(doc(db, "submissions", "CON-2"), { userId: "resident", residentId: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban", recipientType: "barangay", status: "submitted" }),
      setDoc(doc(db, "submissions", "IT-1"), { userId: "resident", residentId: "resident", recipientDepartmentId: "it-department", status: "submitted" }),
      setDoc(doc(db, "submissions", "TOURISM-1"), { userId: "resident", residentId: "resident", barangay: "Cabcaban", recipientDepartmentId: "tourism-department", status: "submitted" }),
      setDoc(doc(db, "posts", "partner-post"), { authorId: "partner", status: "pending_review", visibility: "targeted", targetBarangays: ["Cabcaban"] }),
      setDoc(doc(db, "posts", "targeted-post"), { authorId: "admin", status: "approved", visibility: "targeted", targetBarangays: ["Cabcaban"] }),
      setDoc(doc(db, "posts", "public-post"), { authorId: "admin", status: "approved", visibility: "public", targetBarangays: [] }),
    ]);
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("verification and concern evidence", () => {
  test("organization registration proof stays private to applicant and administrator", async () => {
    const path = "organization_registration_proofs/new-organization/proof-123e4567-e89b-12d3-a456-426614174000.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("new-organization"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("new-organization"), path)));
    await assertSucceeds(getBytes(ref(storageFor("admin"), path)));
    await assertFails(getBytes(ref(storageFor("other"), path)));
    await assertFails(uploadBytes(ref(storageFor("other"), "organization_registration_proofs/new-organization/proof-123e4567-e89b-12d3-a456-426614174001.jpg"), image, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(storageFor("new-organization"), path), image, { contentType: "image/jpeg" }));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "new-organization"), { role: "organization", accountStatus: "pending_approval" });
    });
    await assertFails(deleteObject(ref(storageFor("new-organization"), path)));
  });
  test("concern creation is backend-only for both unverified and verified residents", async () => {
    const unverifiedDb = testEnvironment.authenticatedContext("unverified").firestore();
    const verifiedDb = testEnvironment.authenticatedContext("resident").firestore();
    const concern = {
      userId: "unverified",
      status: "submitted",
      schemaVersion: 2,
      barangay: "Cabcaban",
      title: "Streetlight concern",
      description: "The streetlight has not worked for several nights.",
      category: "Infrastructure",
      residentName: "Fatima Natingga",
      location: "Cabcaban proper",
      requestedAction: "Please inspect the streetlight.",
    };

    await assertSucceeds(getDoc(doc(unverifiedDb, "posts", "public-post")));
    await assertFails(setDoc(doc(unverifiedDb, "submissions", "unverified-concern"), concern));
    await assertFails(setDoc(doc(verifiedDb, "submissions", "verified-concern"), {
      ...concern,
      userId: "resident",
    }));
  });

  test("resident verification documents require a backend-issued link for staff", async () => {
    const path = "verifications/applicant/supporting_document.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("applicant"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("applicant"), path)));
    await assertSucceeds(getBytes(ref(storageFor("admin"), path)));
    await assertSucceeds(getBytes(ref(storageFor("super-admin"), path)));
    await assertFails(getBytes(ref(storageFor("barangay"), path)));
    await assertFails(getBytes(ref(storageFor("vice-captain"), path)));
    await assertFails(getBytes(ref(storageFor("delegated"), path)));
    await assertFails(getBytes(ref(storageFor("outside-official"), path)));
    await assertFails(getBytes(ref(storageFor("other"), path)));
  });

  test("proof-of-residency documents cannot be fetched directly by staff", async () => {
    const path = "verifications/needs-attention/proof_of_residency.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("needs-attention"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("super-admin"), path)));
    await assertSucceeds(getBytes(ref(storageFor("admin"), path)));
    await assertFails(getBytes(ref(storageFor("barangay"), path)));
    await assertFails(getBytes(ref(storageFor("outside-official"), path)));
  });

  test("only resident accounts can upload resident verification documents", async () => {
    await assertFails(uploadBytes(
      ref(storageFor("admin"), "verifications/admin/supporting_document.jpg"),
      image,
      { contentType: "image/jpeg" },
    ));
    await assertFails(uploadBytes(
      ref(storageFor("barangay"), "verifications/barangay/supporting_document.jpg"),
      image,
      { contentType: "image/jpeg" },
    ));
  });

  test("pending residents cannot overwrite a document while it is under review", async () => {
    await assertFails(uploadBytes(
      ref(storageFor("pending-applicant"), "verifications/pending-applicant/supporting_document.jpg"),
      image,
      { contentType: "image/jpeg" },
    ));
  });

  test("unversioned concern evidence is private to its owner", async () => {
    const path = "concerns/resident/CON-1.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertFails(getBytes(ref(storageFor("admin"), path)));
    await assertFails(getBytes(ref(storageFor("other"), path)));
  });

  test("versioned concern evidence follows recipient access", async () => {
    const path = "concerns/resident/CON-2/evidence.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("resident"), path)));
    await assertSucceeds(getBytes(ref(storageFor("barangay"), path)));
    await assertFails(getBytes(ref(storageFor("admin"), path)));
    await assertFails(getBytes(ref(storageFor("other"), path)));
  });

  test("private routed evidence excludes barangay officials and unrelated organizations", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users", "partner"), { uid: "partner", role: "organization", status: "approved", accountStatus: "active", organizationId: "partner" });
      await setDoc(doc(db, "organizations", "partner"), { status: "verified", categoryId: "peace_public_safety" });
      await setDoc(doc(db, "submissions", "PRIVATE-1"), {
        schemaVersion: 4, userId: "resident", reporterIds: ["resident"], visibility: "private",
        barangay: "Cabcaban", barangayId: "barili_cabcaban",
        categoryId: "peace_public_safety", organizationIds: ["partner"],
      });
    });
    const path = "concerns/resident/PRIVATE-1/evidence.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("resident"), path)));
    await assertSucceeds(getBytes(ref(storageFor("partner"), path)));
    await assertFails(getBytes(ref(storageFor("barangay"), path)));
    await assertFails(getBytes(ref(storageFor("other"), path)));
  });

  test("private concerns sent directly to Barangay allow its officials to read evidence", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "submissions", "PRIVATE-BARANGAY"), {
        schemaVersion: 4, userId: "resident", reporterIds: ["resident"],
        visibility: "private", recipientType: "barangay", recipientId: "barangay-barili_cabcaban",
        barangay: "Cabcaban", barangayId: "barili_cabcaban", categoryId: "public_safety",
        organizationIds: [],
      });
    });
    const path = "concerns/resident/PRIVATE-BARANGAY/evidence.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("barangay"), path)));
    await assertFails(getBytes(ref(storageFor("outside-official"), path)));
    await assertFails(getBytes(ref(storageFor("other"), path)));
  });

  test("LGU department staff can read evidence only for concerns assigned to their department", async () => {
    const path = "concerns/resident/TOURISM-1/evidence.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("tourism"), path)));
    await assertFails(getBytes(ref(storageFor("engineering"), path)));
  });

  test("IT Admin sees only IT evidence and Mayor cannot open unrelated evidence", async () => {
    const path = "concerns/resident/CON-2/mayor-review.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertFails(getBytes(ref(storageFor("mayor"), path)));
    const itPath = "concerns/resident/IT-1/evidence.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), itPath), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("admin"), itPath)));
    await assertFails(getBytes(ref(storageFor("tourism"), itPath)));
  });
});

describe("publisher and community uploads", () => {
  test("only approved publishers upload announcement images", async () => {
    await assertSucceeds(uploadBytes(ref(storageFor("partner"), "announcements/partner/partner-post/image.jpg"), image, { contentType: "image/jpeg" }));
    await assertSucceeds(uploadBytes(ref(storageFor("mayor"), "announcements/mayor/mayor-post/image.jpg"), image, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(storageFor("resident"), "announcements/resident/resident-post/image.jpg"), image, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(storageFor("treasurer"), "announcements/treasurer/treasurer-post/image.jpg"), image, { contentType: "image/jpeg" }));
  });

  test("IT announcement overrides also control publisher image uploads", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "access_policies", "department_tourism-department"), {
        granted: [], denied: ["announcements"],
      });
      await setDoc(doc(db, "access_policies", "barangay_barili_cabcaban"), {
        granted: ["announcements"], denied: [],
      });
    });
    await assertFails(uploadBytes(ref(storageFor("tourism"), "announcements/tourism/test/image.jpg"), image, { contentType: "image/jpeg" }));
    await assertSucceeds(uploadBytes(ref(storageFor("treasurer"), "announcements/treasurer/test/image.jpg"), image, { contentType: "image/jpeg" }));
  });

  test("staff cannot use privileged storage access before replacing the initial password", async () => {
    await assertFails(uploadBytes(ref(storageFor("setup-admin"), "announcements/setup-admin/setup-post/image.jpg"), image, { contentType: "image/jpeg" }));
  });

  test("announcement images follow the Firestore audience", async () => {
    const path = "announcements/admin/targeted-post/image.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("admin"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("resident"), path)));
    await assertFails(getBytes(ref(storageFor("other"), path)));
  });

  test("emergency evidence follows report-specific agency and barangay routing", async () => {
    const path = "emergencies/resident/fire-report/report.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("partner"), path)));
    await assertSucceeds(getBytes(ref(storageFor("barangay"), path)));

    const healthPath = "emergencies/resident/health-report/report.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), healthPath), image, { contentType: "image/jpeg" }));
    await assertFails(getBytes(ref(storageFor("partner"), healthPath)));
    await assertFails(getBytes(ref(storageFor("barangay"), healthPath)));
  });

  test("administrators can read emergency evidence", async () => {
    const path = "emergencies/resident/fire-report/admin-review.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("admin"), path)));
  });

  test("unrelated residents cannot read emergency evidence", async () => {
    const path = "emergencies/resident/fire-report/private.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertFails(getBytes(ref(storageFor("other"), path)));
  });

  test("legacy emergency paths no longer expose every report to responders", async () => {
    const path = "emergencies/resident/legacy.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("admin"), path)));
    await assertFails(getBytes(ref(storageFor("partner"), path)));
    await assertFails(getBytes(ref(storageFor("barangay"), path)));
  });

  test("marketplace uploads require ownership and image metadata", async () => {
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), "marketplace/resident/item.jpg"), image, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(storageFor("other"), "marketplace/resident/spoofed.jpg"), image, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(storageFor("resident"), "marketplace/resident/not-image.txt"), image, { contentType: "text/plain" }));
  });

  test("chat photos open by exact name but their folders cannot be listed", async () => {
    const path = "chat_attachments/resident/conversation_photo.jpg";
    await assertSucceeds(uploadBytes(ref(storageFor("resident"), path), image, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(storageFor("other"), path)));
    await assertFails(listAll(ref(storageFor("other"), "chat_attachments/resident")));
  });

  test("restricted residents cannot upload new concern or market evidence", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "resident"), { restrictionStatus: "active", restrictionEndDate: null }, { merge: true });
    });
    await assertFails(uploadBytes(ref(storageFor("resident"), "concerns/resident/CON-2/restricted.jpg"), image, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(storageFor("resident"), "marketplace/resident/restricted.jpg"), image, { contentType: "image/jpeg" }));
  });
});
