import assert from "node:assert/strict";
import { createRequire } from "node:module";

import { deleteApp, initializeApp } from "firebase/app";
import { connectAuthEmulator, createUserWithEmailAndPassword, getAuth, signInWithEmailAndPassword } from "firebase/auth";
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions";
import { connectFirestoreEmulator, doc, getDoc, getFirestore } from "firebase/firestore";
import { connectStorageEmulator, getStorage, ref, uploadBytes } from "firebase/storage";

for (const name of ["FIREBASE_AUTH_EMULATOR_HOST", "FIRESTORE_EMULATOR_HOST", "FIREBASE_STORAGE_EMULATOR_HOST", "FIREBASE_EMULATOR_HUB"]) {
  if (!process.env[name]) throw new Error(`${name} must point to a local emulator before this test can run.`);
}
if (process.env.ESUGID_DISABLE_EXTERNAL_DELIVERY !== "1") {
  throw new Error("External email and push delivery must be disabled for this integration test.");
}

const requireFromFunctions = createRequire(new URL("../functions/index.js", import.meta.url));
const { initializeApp: initializeAdminApp, deleteApp: deleteAdminApp } = requireFromFunctions("firebase-admin/app");
const { getAuth: getAdminAuth } = requireFromFunctions("firebase-admin/auth");
const { getFirestore: getAdminFirestore } = requireFromFunctions("firebase-admin/firestore");

const config = { apiKey: "test-key", authDomain: "e-sugid.firebaseapp.com", projectId: "e-sugid", storageBucket: "e-sugid.firebasestorage.app" };
const applicantApp = initializeApp(config, "registration-applicant");
const reviewerApp = initializeApp(config, "registration-reviewer");
const organizationApp = initializeApp(config, "registration-organization");
const adminApp = initializeAdminApp({ projectId: "e-sugid", storageBucket: "e-sugid.firebasestorage.app" }, "registration-integration-admin");
const applicantAuth = getAuth(applicantApp);
const reviewerAuth = getAuth(reviewerApp);
const organizationAuth = getAuth(organizationApp);
connectAuthEmulator(applicantAuth, "http://127.0.0.1:9099", { disableWarnings: true });
connectAuthEmulator(reviewerAuth, "http://127.0.0.1:9099", { disableWarnings: true });
connectAuthEmulator(organizationAuth, "http://127.0.0.1:9099", { disableWarnings: true });
const organizationFirestore = getFirestore(organizationApp);
connectFirestoreEmulator(organizationFirestore, "127.0.0.1", 8085);
const applicantFunctions = getFunctions(applicantApp, "asia-southeast1");
const reviewerFunctions = getFunctions(reviewerApp, "asia-southeast1");
connectFunctionsEmulator(applicantFunctions, "127.0.0.1", 5005);
connectFunctionsEmulator(reviewerFunctions, "127.0.0.1", 5005);
const applicantStorage = getStorage(applicantApp);
connectStorageEmulator(applicantStorage, "127.0.0.1", 9195);

try {
  const reviewer = await getAdminAuth(adminApp).createUser({
    uid: "organization-registration-reviewer", email: "reviewer@example.com", password: "ReviewPass123!", emailVerified: true,
  });
  await getAdminFirestore(adminApp).collection("users").doc(reviewer.uid).set({
    uid: reviewer.uid, role: "super_admin", accountStatus: "active", status: "approved",
    setupRequired: false, name: "Registration Reviewer", email: reviewer.email,
  });
  const applicant = (await createUserWithEmailAndPassword(
    applicantAuth, "organization-applicant@example.com", "ApplicantPass123!",
  )).user;
  const path = `organization_registration_proofs/${applicant.uid}/proof-123e4567-e89b-12d3-a456-426614174000.jpg`;
  await uploadBytes(ref(applicantStorage, path), new Uint8Array([0xff, 0xd8, 0xff, 0xe0]), { contentType: "image/jpeg" });
  const submitted = await httpsCallable(applicantFunctions, "submitOrganizationRegistration")({
    organizationName: "Registration Test Organization",
    organizationTypeId: "public_safety",
    organizationSector: "public",
    organizationAddress: "Near Poblacion Hall",
    barangay: "Poblacion", barangayId: "barili_poblacion",
    firstName: "Juan", middleName: "Santos", lastName: "Dela Cruz", extension: "Jr.",
    contactNumber: "09171234567", email: applicant.email,
    proofType: "authorization", proofStoragePath: path,
  });
  const requestId = submitted.data.requestId;
  assert.ok(requestId);
  const db = getAdminFirestore(adminApp);
  assert.equal((await db.collection("users").doc(applicant.uid).get()).data().accountStatus, "pending_approval");
  assert.equal((await db.collection("organizations").doc("registration-test-organization").get()).exists, false);
  await signInWithEmailAndPassword(reviewerAuth, reviewer.email, "ReviewPass123!");
  await assert.rejects(
    httpsCallable(reviewerFunctions, "reviewStaffAccountRequest")({
      requestId, decision: "approved", categoryId: "public_safety",
    }),
    (error) => error.code === "functions/failed-precondition",
  );
  await getAdminAuth(adminApp).updateUser(applicant.uid, { emailVerified: true });
  await httpsCallable(reviewerFunctions, "reviewStaffAccountRequest")({
    requestId, decision: "approved", categoryId: "public_safety",
  });
  assert.equal((await db.collection("users").doc(applicant.uid).get()).data().accountStatus, "active");
  assert.equal((await db.collection("organizations").doc("registration-test-organization").get()).data().categoryId, "public_safety");
  assert.equal((await db.collection("staff_account_requests").doc(requestId).get()).data().status, "approved");
  const bankApplicant = (await createUserWithEmailAndPassword(
    applicantAuth, "bank-applicant@example.com", "ApplicantPass123!",
  )).user;
  const bankProofPath = `organization_registration_proofs/${bankApplicant.uid}/proof-123e4567-e89b-12d3-a456-426614174001.jpg`;
  await uploadBytes(ref(applicantStorage, bankProofPath), new Uint8Array([0xff, 0xd8, 0xff, 0xe0]), { contentType: "image/jpeg" });
  const bankRegistration = {
    organizationName: "Registration Test Bank", organizationSector: "private",
    organizationTypeId: "private_banking_finance", organizationAddress: "Poblacion",
    barangay: "Poblacion", barangayId: "barili_poblacion",
    firstName: "Maria", lastName: "Santos", contactNumber: "09171234567",
    email: bankApplicant.email, proofType: "authorization", proofStoragePath: bankProofPath,
  };
  await assert.rejects(
    httpsCallable(applicantFunctions, "submitOrganizationRegistration")({
      ...bankRegistration, organizationSector: "public",
    }),
    (error) => error.code === "functions/invalid-argument",
  );
  const bankRequest = await httpsCallable(applicantFunctions, "submitOrganizationRegistration")(bankRegistration);
  assert.equal((await db.collection("organizations").doc("registration-test-bank").get()).exists, false);
  await getAdminAuth(adminApp).updateUser(bankApplicant.uid, { emailVerified: true });
  await httpsCallable(reviewerFunctions, "reviewStaffAccountRequest")({
    requestId: bankRequest.data.requestId, decision: "approved", categoryId: "private_banking_finance",
  });
  assert.equal((await db.collection("organizations").doc("registration-test-bank").get()).data().organizationSector, "private");
  const master = (await httpsCallable(reviewerFunctions, "manageOrganization")({
    action: "save", name: "Registration Master Org", organizationSector: "public",
    organizationTypeId: "environment",
  })).data;
  assert.equal(master.organizationTypeId, "environment");
  assert.equal((await db.collection("organizations").doc(master.organizationId).get()).data().organizationTypeName, "Environment");
  const masterApplicant = (await createUserWithEmailAndPassword(
    applicantAuth, "master-applicant@example.com", "ApplicantPass123!",
  )).user;
  const masterProofPath = `organization_registration_proofs/${masterApplicant.uid}/proof-123e4567-e89b-12d3-a456-426614174002.jpg`;
  await uploadBytes(ref(applicantStorage, masterProofPath), new Uint8Array([0xff, 0xd8, 0xff, 0xe0]), { contentType: "image/jpeg" });
  const masterRequest = (await httpsCallable(applicantFunctions, "submitOrganizationRegistration")({
    organizationName: "Registration Master Org", organizationSector: "public",
    organizationTypeId: "environment", organizationAddress: "Poblacion",
    firstName: "Ana", lastName: "Reyes", contactNumber: "09171234567",
    email: masterApplicant.email, proofType: "authorization", proofStoragePath: masterProofPath,
  })).data;
  await getAdminAuth(adminApp).updateUser(masterApplicant.uid, { emailVerified: true });
  await httpsCallable(reviewerFunctions, "reviewStaffAccountRequest")({
    requestId: masterRequest.requestId, decision: "approved", categoryId: "environment",
  });
  const linkedMaster = (await db.collection("organizations").doc(master.organizationId).get()).data();
  assert.equal(linkedMaster.primaryAdminId, masterApplicant.uid);
  assert.equal(linkedMaster.organizationTypeId, "environment");
  const directMaster = (await httpsCallable(reviewerFunctions, "manageOrganization")({
    action: "save", name: "Direct Account Organization", organizationSector: "private",
    organizationTypeId: "private_health_medical",
  })).data;
  await assert.rejects(
    httpsCallable(reviewerFunctions, "createStaffAccount")({
      role: "organization", organizationId: directMaster.organizationId,
      categoryId: "private_health_medical", organizationSector: "public",
      organizationAddress: "Main Street", firstName: "Lina", lastName: "Cruz",
      email: "direct-organization@gmail.com", temporaryPassword: "ABC234",
      distributionMethod: "personal",
    }),
    (error) => error.code === "functions/invalid-argument",
  );
  const directAccount = (await httpsCallable(reviewerFunctions, "createStaffAccount")({
    role: "organization", organizationId: directMaster.organizationId,
    categoryId: "private_health_medical", organizationSector: "private",
    expectedOrganizationTypeId: "private_health_medical", expectedOrganizationSector: "private",
    organizationAddress: "Main Street", firstName: "Lina", lastName: "Cruz",
    email: "direct-organization@gmail.com", temporaryPassword: "ABC234",
    distributionMethod: "personal",
  })).data;
  const directProfile = (await db.collection("users").doc(directAccount.uid).get()).data();
  assert.equal(directProfile.organizationId, directMaster.organizationId);
  assert.equal(directProfile.organizationSector, "private");
  assert.equal(directProfile.organizationTypeId, "private_health_medical");
  assert.equal(directProfile.organizationAddress, "Main Street");
  await assert.rejects(
    httpsCallable(reviewerFunctions, "createStaffAccount")({
      role: "organization", organizationId: directMaster.organizationId,
      categoryId: "private_electricity", organizationSector: "private",
      expectedOrganizationTypeId: "private_health_medical", expectedOrganizationSector: "private",
      organizationAddress: "Main Street", firstName: "Sara", lastName: "Cruz",
      email: "second-organization@gmail.com", temporaryPassword: "ABC234",
      distributionMethod: "personal",
    }),
    (error) => error.code === "functions/failed-precondition",
  );
  await db.collection("organizations").doc("unclassified-school").set({
    name: "Unclassified School", status: "verified",
  });
  const schoolAccount = (await httpsCallable(reviewerFunctions, "createStaffAccount")({
    role: "organization", organizationId: "unclassified-school",
    categoryId: "public_school_education", organizationSector: "public",
    expectedOrganizationTypeId: "", expectedOrganizationSector: "",
    organizationAddress: "School Road", firstName: "Mia", lastName: "Reyes",
    email: "school-organization@gmail.com", temporaryPassword: "ABC234",
    distributionMethod: "personal",
  })).data;
  assert.equal((await db.collection("users").doc(schoolAccount.uid).get()).data().organizationTypeId, "public_school_education");
  const classifiedSchool = (await db.collection("organizations").doc("unclassified-school").get()).data();
  assert.equal(classifiedSchool.organizationSector, "public");
  assert.equal(classifiedSchool.organizationTypeId, "public_school_education");
  await db.collection("organizations").doc("bfp").set({
    name: "Barili Fire Station", categoryId: "peace_public_safety", status: "verified",
  });
  await getAdminAuth(adminApp).createUser({
    uid: "bfp-official", email: "bfp-official@example.com", password: "BfpPass123!",
  });
  await db.collection("users").doc("bfp-official").set({
    role: "organization", organizationId: "bfp", accountStatus: "active", setupRequired: false,
  });
  await db.collection("organizations").doc("pending-police").set({
    name: "Pending Police", categoryId: "public_safety", status: "verified",
  });
  await db.collection("users").doc("pending-police-official").set({
    role: "organization", organizationId: "pending-police", accountStatus: "pending_approval",
  });
  await db.collection("organizations").doc("sta-ana-academy").set({
    name: "Sta. Ana Academy", categoryId: "private_school_education",
    organizationSector: "private", status: "verified",
  });
  await db.collection("users").doc("academy-official").set({
    role: "organization", organizationId: "sta-ana-academy", accountStatus: "active",
  });
  await db.collection("organizations").doc("barili-public-school").set({
    name: "Barili Public School", categoryId: "public_school_education",
    organizationTypeId: "public_school_education", organizationSector: "public", status: "verified",
  });
  await db.collection("users").doc("public-school-official").set({
    role: "organization", organizationId: "barili-public-school", accountStatus: "active",
  });
  const resident = await getAdminAuth(adminApp).createUser({
    uid: "concern-resident", email: "concern-resident@example.com", password: "ResidentPass123!",
  });
  await db.collection("users").doc(resident.uid).set({
    role: "resident", accountStatus: "active", verificationStatus: "verified",
    barangay: "Poblacion", barangayId: "barili_poblacion", name: "Test Resident",
  });
  await signInWithEmailAndPassword(applicantAuth, resident.email, "ResidentPass123!");
  const categories = (await httpsCallable(applicantFunctions, "getConcernCategories")({
    organizationSectors: true,
  })).data.categories;
  assert.equal(categories.length, 26);
  assert.equal((await httpsCallable(applicantFunctions, "getConcernCategories")()).data.categories.length, 17);
  assert.equal(categories.find(({ id }) => id === "public_safety").name, "Public Safety");
  const matches = (await httpsCallable(applicantFunctions, "listConcernOrganizations")({
    categoryId: "public_safety", organizationSector: "public",
  })).data.organizations;
  assert.deepEqual(matches.map(({ id }) => id).sort(), ["bfp", "registration-test-organization"]);
  const legacyMatches = (await httpsCallable(applicantFunctions, "listConcernOrganizations")({
    categoryId: "public_safety",
  })).data.organizations;
  assert.deepEqual(legacyMatches.map(({ id }) => id).sort(), ["bfp", "registration-test-organization"]);
  const privateMatches = (await httpsCallable(applicantFunctions, "listConcernOrganizations")({
    categoryId: "private_school_education", organizationSector: "private",
  })).data.organizations;
  assert.deepEqual(privateMatches.map(({ id }) => id), ["sta-ana-academy"]);
  const publicSchoolMatches = (await httpsCallable(applicantFunctions, "listConcernOrganizations")({
    categoryId: "public_school_education", organizationSector: "public",
  })).data.organizations;
  assert.deepEqual(publicSchoolMatches.map(({ id }) => id), ["barili-public-school"]);
  const bankMatches = (await httpsCallable(applicantFunctions, "listConcernOrganizations")({
    categoryId: "private_banking_finance", organizationSector: "private",
  })).data.organizations;
  assert.deepEqual(bankMatches.map(({ id }) => id), ["registration-test-bank"]);
  await assert.rejects(
    httpsCallable(applicantFunctions, "listConcernOrganizations")({
      categoryId: "private_school_education", organizationSector: "public",
    }),
    (error) => error.code === "functions/invalid-argument",
  );
  const concern = {
    id: "CON-2026-999901", draftId: "registration-concern-1", categoryId: "public_safety",
    organizationSector: "public",
    title: "Unsafe street corner", description: "The street corner is unsafe at night.",
    concernType: "Complaint", visibility: "private", location: "Near Poblacion Hall",
    barangay: "Poblacion", barangayId: "barili_poblacion",
  };
  await assert.rejects(
    httpsCallable(applicantFunctions, "submitConcern")({ ...concern, organizationId: "pending-police" }),
    (error) => error.code === "functions/invalid-argument",
  );
  await assert.rejects(
    httpsCallable(applicantFunctions, "submitConcern")({ ...concern }),
    (error) => error.code === "functions/invalid-argument",
  );
  await httpsCallable(applicantFunctions, "submitConcern")({ ...concern, organizationId: "bfp" });
  const savedConcern = (await db.collection("submissions").doc(concern.id).get()).data();
  assert.deepEqual(savedConcern.organizationIds, ["bfp"]);
  assert.equal(savedConcern.recipientId, "bfp");
  assert.equal(savedConcern.visibility, "private");
  await httpsCallable(applicantFunctions, "submitConcern")({
    ...concern, id: "CON-2026-999904", draftId: "legacy-concern",
    organizationId: "bfp", organizationSector: undefined,
  });
  const schoolConcern = {
    ...concern, id: "CON-2026-999902", draftId: "registration-concern-2",
    categoryId: "private_school_education", organizationSector: "private",
    organizationId: "sta-ana-academy", visibility: "public",
  };
  await httpsCallable(applicantFunctions, "submitConcern")(schoolConcern);
  const savedSchoolConcern = (await db.collection("submissions").doc(schoolConcern.id).get()).data();
  assert.equal(savedSchoolConcern.visibility, "public");
  assert.deepEqual(savedSchoolConcern.organizationIds, ["sta-ana-academy"]);
  await assert.rejects(
    httpsCallable(applicantFunctions, "submitConcern")({
      ...schoolConcern, id: "CON-2026-999903", draftId: "registration-concern-3",
      organizationSector: "public",
    }),
    (error) => error.code === "functions/invalid-argument",
  );
  await signInWithEmailAndPassword(organizationAuth, "bfp-official@example.com", "BfpPass123!");
  assert.equal((await getDoc(doc(organizationFirestore, "submissions", concern.id))).exists(), true);
  process.stdout.write("Organization registration, approval filtering, and selected concern routing passed.\n");
} finally {
  await deleteApp(applicantApp);
  await deleteApp(reviewerApp);
  await deleteApp(organizationApp);
  await deleteAdminApp(adminApp);
}
