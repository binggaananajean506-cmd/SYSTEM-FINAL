const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canonicalOtp,
  maskedEmail,
  otpHash,
  otpMatches,
} = require("./registration_otp_helpers");

test("canonicalOtp accepts exactly six digits", () => {
  assert.equal(canonicalOtp(" 012345 "), "012345");
  assert.equal(canonicalOtp("12345"), null);
  assert.equal(canonicalOtp("12345a"), null);
});

test("OTP hashes are bound to the user and email", () => {
  const hash = otpHash("123456", "resident-1", "Ana@Example.com", "secret");
  assert.equal(otpMatches({
    code: "123456",
    expectedHash: hash,
    uid: "resident-1",
    email: "ana@example.com",
    secret: "secret",
  }), true);
  assert.equal(otpMatches({
    code: "123456",
    expectedHash: hash,
    uid: "resident-2",
    email: "ana@example.com",
    secret: "secret",
  }), false);
});

test("maskedEmail hides most of the local part", () => {
  assert.equal(maskedEmail("ana@example.com"), "an**@example.com");
  assert.equal(maskedEmail("a@example.com"), "a**@example.com");
});
