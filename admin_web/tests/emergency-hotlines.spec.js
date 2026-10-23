const { test, expect } = require("@playwright/test");

test("Barili emergency hotline defaults include all supplied numbers", async () => {
  const { emergencyHotlineDirectory } = await import("../emergency_hotlines.mjs");
  const contacts = emergencyHotlineDirectory();
  const numbers = Object.fromEntries(contacts.map((contact) => [
    contact.id,
    contact.contactNumbers.map((line) => line.number),
  ]));
  expect(numbers["national-911"]).toEqual(["911"]);
  expect(numbers["mdrrmo-barili"]).toEqual(["0918 637 6365"]);
  expect(numbers["bfp-barili"]).toEqual(["0969 410 1951", "0998 598 6361"]);
  expect(numbers["rhu-barili"]).toEqual(["032 517 3472"]);
});

test("IT overrides and deactivations apply to built-in hotlines", async () => {
  const { emergencyHotlineDirectory } = await import("../emergency_hotlines.mjs");
  const contacts = emergencyHotlineDirectory([
    { id: "bfp-barili", contactNumbers: [{ label: "Updated", number: "0912 345 6789" }] },
    { id: "rhu-barili", active: false },
  ], "(032) 470 9201");
  expect(contacts.find((contact) => contact.id === "bfp-barili").contactNumbers)
    .toEqual([{ label: "Updated", number: "0912 345 6789" }]);
  expect(contacts.some((contact) => contact.id === "rhu-barili")).toBe(false);
  expect(contacts.find((contact) => contact.id === "municipal").contactNumbers[0].number)
    .toBe("(032) 470 9201");
});
