/**
 * Edit these lists to change the dropdowns and filters across the app.
 * Values are stored as plain text in the database, so no migration is needed.
 * If you rename or remove an entry, existing contacts keep their old value.
 */

export const MET_AT_OPTIONS = ["Undergrad", "Grad school", "Circle", "Other"] as const;

export const RELATIONSHIP_OPTIONS = ["Friend", "Networking", "Colleague", "Mentor", "Other"] as const;

export const MEDIUM_OPTIONS = [
  { value: "call", label: "Call" },
  { value: "text", label: "Text" },
  { value: "email", label: "Email" },
  { value: "in_person", label: "In person" },
  { value: "other", label: "Other" },
] as const;

export type MetAt = (typeof MET_AT_OPTIONS)[number];
export type RelationshipType = (typeof RELATIONSHIP_OPTIONS)[number];
export type Medium = (typeof MEDIUM_OPTIONS)[number]["value"];
