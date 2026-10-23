const assert = require("node:assert/strict");
const test = require("node:test");
const { validOrganizationProofHeader } = require("./organization_registration_helpers");

test("registration proof headers must match their declared file type", () => {
  assert.equal(validOrganizationProofHeader(Buffer.from("%PDF-1.7"), "application/pdf", "pdf"), true);
  assert.equal(validOrganizationProofHeader(Buffer.from([0xff, 0xd8, 0xff, 0xe0]), "image/jpeg", "jpg"), true);
  assert.equal(validOrganizationProofHeader(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), "image/png", "png"), true);
  assert.equal(validOrganizationProofHeader(Buffer.from("<html>"), "application/pdf", "pdf"), false);
  assert.equal(validOrganizationProofHeader(Buffer.from("%PDF-1.7"), "image/jpeg", "jpg"), false);
});
