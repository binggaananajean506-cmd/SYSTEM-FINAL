export const DEFAULT_EMERGENCY_CONTACTS = [
  {
    id: "national-911",
    name: "National Emergency Hotline",
    category: "Police, fire, ambulance and rescue",
    contactNumbers: [{ label: "911", number: "911" }],
  },
  {
    id: "mdrrmo-barili",
    name: "MDRRMO Barili",
    category: "Disaster response",
    contactNumbers: [{ label: "Mobile", number: "0918 637 6365" }],
  },
  {
    id: "bfp-barili",
    name: "BFP Barili",
    category: "Fire and rescue",
    contactNumbers: [
      { label: "Mobile 1", number: "0969 410 1951" },
      { label: "Mobile 2", number: "0998 598 6361" },
    ],
  },
  {
    id: "rhu-barili",
    name: "RHU Barili",
    category: "Health center",
    contactNumbers: [{ label: "Landline", number: "032 517 3472" }],
  },
];

export function emergencyHotlineDirectory(managedContacts = [], municipalNumber = "") {
  const defaults = [
    ...DEFAULT_EMERGENCY_CONTACTS,
    ...(municipalNumber ? [{
      id: "municipal",
      name: "Municipality of Barili",
      category: "Municipal emergency line",
      contactNumbers: [{ label: "Municipal hotline", number: municipalNumber }],
    }] : []),
  ];
  const overrides = new Map(managedContacts.map((contact) => [contact.id, contact]));
  const builtInIds = new Set(defaults.map((contact) => contact.id));
  return [
    ...defaults.map((contact) => ({ ...contact, ...(overrides.get(contact.id) || {}) })),
    ...managedContacts.filter((contact) => !builtInIds.has(contact.id)),
  ].filter((contact) => contact.active !== false);
}
