"use strict";

const ASSISTANT_ROUTE_REGISTRY = Object.freeze([
  route("home", "Home", "E-SUGID", "Home dashboard and Community Bulletin overview."),
  route("announcements", "Announcements", "Home > Community Bulletin", "Official municipality and barangay announcements."),
  route("emergencyCenter", "Emergency Center", "Alerts", "Current emergency alerts and safety updates."),
  route("hotlines", "Emergency Hotlines", "Alerts", "Verified emergency contacts.", ["resident"]),
  route("fileConcern", "File a Concern", "Concern Center", "Start the official concern form.", ["resident"]),
  route("myConcerns", "My Concerns", "Concern Center", "Track the signed-in resident's submissions.", ["resident"]),
  route("concernDraft", "Unfinished Drafts", "Concern Center > My Concerns", "Resume a manually saved concern.", ["resident"]),
  route("services", "Services", "E-SUGID", "Municipality services and community tools."),
  route("municipalOfficials", "Municipal Officials", "Services", "Current Mayor, Vice Mayor, councilors, and municipal officials."),
  route("myBarangay", "My Barangay", "Home", "Signed-in user's barangay information.", ["resident", "barangay_captain", "barangay_vice_captain", "barangay_secretary", "barangay_councilor"]),
  route("calendar", "Community Calendar", "Services", "Upcoming events and scheduled announcements."),
  route("exploreBarili", "Explore Barili", "Services", "Barili destinations, heritage places, and directions."),
  route("jobs", "Bayanihan Works", "Services", "Community help requests and offers.", ["resident"]),
  route("market", "Local Market", "Services", "Browse and list local marketplace items.", ["resident"]),
  route("profile", "Profile", "E-SUGID", "Account details, settings, and verification status."),
  route("residentVerification", "Resident Verification", "Profile", "Submit the resident's own verification documents.", ["resident"]),
  route("notifications", "Notifications", "Home", "Updates for the signed-in account."),
  route("savedAnnouncements", "Saved Announcements", "Announcements", "Announcements saved for later and offline reading."),
  route("barangayMap", "Barangay Map", "Services", "Interactive map of Barili and its barangays."),
  route("bariliWeather", "Barili Weather", "Home", "Current weather and forecast for Barili."),
  route("myMarketListings", "My Market Listings", "Local Market", "Items posted by the signed-in resident.", ["resident"]),
  route("bayanihanMessages", "Bayanihan Messages", "Bayanihan Works", "Conversations about help requests and offers.", ["resident"]),
]);

// Trusted fallback for the officials already published in the mobile app. Live
// Firestore records take precedence; this prevents the assistant from losing
// the same directory that residents can still see when the collection is empty.
const BUILT_IN_MUNICIPAL_OFFICIALS = Object.freeze([
  official("municipal-mayor", 'Pablo John "John-John" D. Garcia IV', "Municipal Mayor"),
  official("municipal-vice-mayor", 'Luisito "Loy" L. Ponsica', "Municipal Vice Mayor"),
  official("councilor-jayra-ruiz-javier", "Jayra Angelic Ruiz-Javier", "Municipal Councilor"),
  official("councilor-robert-alquizola", 'Robert Arthur "Bobet" P. Alquizola', "Municipal Councilor"),
  official("councilor-john-ricardel", "John Joshua L. Ricardel", "Municipal Councilor"),
  official("councilor-john-anober", 'John Anthony "John-John" T. Añober', "Municipal Councilor"),
  official("councilor-shelomith-ewican", "Shelomith Ann C. Ewican", "Municipal Councilor"),
  official("councilor-teresito-marinas", "Teresito P. Mariñas", "Municipal Councilor"),
  official("councilor-nelson-ricamora", "Nelson P. Ricamora", "Municipal Councilor"),
  official("councilor-andres-abellana", 'Andres "Dres" G. Abellana', "Municipal Councilor"),
]);

function official(id, name, position) {
  return Object.freeze({ id, name, position, isCurrent: true, office: "Municipality of Barili" });
}

function route(action, title, parent, description, roles = null) {
  return Object.freeze({ action, title, parent, description, roles });
}

const ASSISTANT_ACTIONS = new Set([
  "none",
  ...ASSISTANT_ROUTE_REGISTRY.map((entry) => entry.action),
]);

function routeContextForRole(role) {
  return ASSISTANT_ROUTE_REGISTRY
    .filter((entry) => !entry.roles || entry.roles.includes(role))
    .map(({ action, title, parent, description }) => ({
      action,
      title,
      parent,
      description,
    }));
}

function isActionAllowed(action, role) {
  if (action === "none") return true;
  const entry = ASSISTANT_ROUTE_REGISTRY.find((route) => route.action === action);
  return Boolean(entry) && (!entry.roles || entry.roles.includes(role));
}

function normalizeQuestion(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Fast path for clear app intents. Ambiguous language deliberately returns
 * null so the language model can classify it using conversation context.
 */
function inferKnownIntent(question, history = []) {
  const current = normalizeQuestion(question);
  const recent = history
    .slice(-4)
    .map((item) => normalizeQuestion(item?.text))
    .join(" ");

  if (/difference between announcements? and emergency alerts?|announcements?.*emergency alerts?/.test(current)) {
    return intent("announcement_comparison", "emergencyCenter");
  }
  if (/verify residents?|approve residents?|resident verification queue/.test(current)) {
    return intent("resident_review", "none");
  }
  if (/barangay captain|barangay capta?in|kapitan.*barangay|barangay official|barangay offi?c(?:ial|al)s?/.test(current)) {
    return intent("barangay_officials", "myBarangay", { position: "Barangay Captain" });
  }
  const asksAboutOfficials = /mayou?r|mayr|vice mayou?r|vice mayr|municipal officials?|municipal offi?c(?:ial|al)s?|lgu officials?|councilors?|councilers?|department heads?|people (currently )?(serving|running) the municipality|currently runs? the municipality|nagdumala sa (munisipyo|municipality)/.test(current);
  const officialFollowUp = /^(how|what) about( the)?|^and( the)?|^unya|show me (all|them)/.test(current) &&
    /mayor|municipal official|councilor|department head/.test(recent);
  if (asksAboutOfficials || officialFollowUp) {
    const position = /vice ma(?:yor|yr|your)/.test(current) ? "Vice Mayor" :
      /\bma(?:yor|yr|your)\b/.test(current) ? "Mayor" :
        /councilor|counciler/.test(current) ? "Councilor" :
          /department head/.test(current) ? "Department Head" : "";
    return intent("municipal_officials", "municipalOfficials", position ? { position } : {});
  }
  if (/unfinished concern|saved draft|concern draft|do i have drafts?/.test(current)) {
    return intent("concern_drafts", "concernDraft");
  }
  if (/notifications?|inbox|unread updates?/.test(current)) {
    return intent("navigation", "notifications");
  }
  if (/saved announcements?|bookmarked announcements?|offline announcements?/.test(current)) {
    return intent("navigation", "savedAnnouncements");
  }
  if (/barangay map|map of barili|show.*map/.test(current)) {
    return intent("navigation", "barangayMap");
  }
  if (/barili weather|weather (today|forecast)|forecast.*barili/.test(current)) {
    return intent("navigation", "bariliWeather");
  }
  if (/my market listings?|items? i (posted|listed)|my listed items?/.test(current)) {
    return intent("navigation", "myMarketListings");
  }
  if (/bayanihan messages?|help conversations?|messages? about.*help/.test(current)) {
    return intent("navigation", "bayanihanMessages");
  }
  if (/concerns? (have i|i have) submitted|my concerns?|concern status|track.*concern|see my concern/.test(current)) {
    return intent("concern_status", "myConcerns");
  }
  if (/what happens after.*submit.*concern|after i submit.*concern|concern process/.test(current)) {
    return intent("concern_process", "myConcerns");
  }
  if (/immediate danger|life.threatening|evacuat|active emergency|emergency alerts?|flooding.*danger/.test(current)) {
    return intent("emergency_alerts", "emergencyCenter");
  }
  if (/hotline|what number.*(fire|police|ambulance|rescue)|call.*(fire|police|ambulance|rescue) emergency/.test(current)) {
    const category = /fire/.test(current) ? "fire" : /police/.test(current) ? "police" : "emergency";
    return intent("emergency_hotlines", "hotlines", { category });
  }
  if (/events? (are )?(coming|upcoming)|upcoming events?|community calendar|what.*scheduled/.test(current)) {
    return intent("calendar", "calendar");
  }
  const asksAboutPlace = /mantayupan|where can i visit|places? to visit|tourism|explore barili/.test(current);
  const placeFollowUp = /how do i get there|directions?|where is it/.test(current) &&
    /mantayupan|visit|place|destination|explore barili/.test(recent);
  if (asksAboutPlace || placeFollowUp) {
    const query = /mantayupan/.test(`${recent} ${current}`) ? "Mantayupan Falls" : "";
    return intent("explore", "exploreBarili", query ? { query } : {});
  }
  if (/bayanihan|feature.*residents.*help.*residents|residents.*cooperate|help requests? (are )?available/.test(current)) {
    return intent("bayanihan", "jobs");
  }
  if (/new announcements?|latest announcements?|community bulletin/.test(current)) {
    return intent("announcements", "announcements");
  }
  if (/am i verified|verification status|what barangay am i|registered.*barangay/.test(current)) {
    return intent("profile", "profile");
  }
  if (/drainage|electricity concern|report.*(issue|problem)|submit.*concern|file.*concern|flooding near my house/.test(current)) {
    return intent("concern_file", "fileConcern");
  }
  if (/about barili|history of barili|how many barangays|barili (office|facility|service|heritage)|municipality of barili/.test(current)) {
    return intent("barili_knowledge", "none", { query: current });
  }
  return null;
}

function intent(source, action, entities = {}) {
  return { source, action, entities };
}

function safeClientContext(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const count = Number(value.manualDraftCount);
  const latestDraftId = String(value.latestDraftId || "").trim().slice(0, 120);
  const latestDraftUpdatedAt = String(value.latestDraftUpdatedAt || "").trim().slice(0, 80);
  return {
    manualDraftCount: Number.isInteger(count) && count >= 0 && count <= 100 ? count : 0,
    ...(latestDraftId ? { latestDraftId } : {}),
    ...(latestDraftUpdatedAt ? { latestDraftUpdatedAt } : {}),
  };
}

function cleanPublicRecord(data, allowedFields) {
  const result = {};
  for (const field of allowedFields) {
    const value = data?.[field];
    if (value === null || value === undefined) continue;
    if (typeof value === "string") result[field] = value.trim().slice(0, 500);
    else if (typeof value === "number" || typeof value === "boolean") result[field] = value;
    else if (typeof value?.toDate === "function") result[field] = value.toDate().toISOString();
  }
  return result;
}

function canonicalOfficialRecord(id, data) {
  const name = String(data?.name || data?.fullName || data?.displayName || "").trim();
  const position = String(data?.position || data?.positionTitle || data?.title || "").trim();
  const status = String(data?.status || "").trim().toLowerCase();
  const explicitlyCurrent = data?.isCurrent ?? data?.current;
  return {
    id: String(id || data?.id || "").trim(),
    name: name.slice(0, 160),
    position: position.slice(0, 120),
    isCurrent: explicitlyCurrent !== false && !["former", "inactive", "ended"].includes(status),
    term: String(data?.term || "").trim().slice(0, 120),
    office: String(data?.office || data?.department || "").trim().slice(0, 160),
    photoUrl: String(data?.photoUrl || data?.imageUrl || "").trim().slice(0, 500),
    updatedAt: typeof data?.updatedAt?.toDate === "function" ?
      data.updatedAt.toDate().toISOString() : String(data?.updatedAt || "").trim().slice(0, 80),
  };
}

function officialMatchesPosition(record, requestedPosition) {
  const actual = normalizeQuestion(record?.position);
  const requested = normalizeQuestion(requestedPosition);
  if (!requested) return true;
  if (requested === "mayor") return actual.includes("mayor") && !actual.includes("vice");
  if (requested === "vice mayor") return actual.includes("vice") && actual.includes("mayor");
  if (requested.includes("council")) return actual.includes("council") || actual.includes("sangguniang bayan");
  if (requested.includes("department")) return actual.includes("head") || actual.includes("officer");
  return actual.includes(requested);
}

function isCebuanoQuestion(question) {
  return /\b(kinsa|unsa|asa|unya|ang|mao|sa|mga|makita|kinsay)\b/i.test(String(question || ""));
}

function groundedOfficialAnswer(question, records, requestedPosition, barangay = "") {
  const valid = (Array.isArray(records) ? records : [])
    .filter((record) => record?.isCurrent !== false && record?.name && record?.position)
    .filter((record) => officialMatchesPosition(record, requestedPosition));
  const bisaya = isCebuanoQuestion(question);
  if (!valid.length) {
    if (barangay) {
      return bisaya ?
        "Dili nako makuha ang kasamtangang impormasyon sa opisyal sa barangay karon." :
        "I couldn't retrieve the current barangay official information right now.";
    }
    return bisaya ?
      "Dili nako makuha ang kasamtangang impormasyon sa opisyal karon." :
      "I couldn't retrieve the current municipal official information right now.";
  }
  const area = barangay ? ` sa ${barangay}` : " sa Barili";
  if (requestedPosition && valid.length === 1) {
    const official = valid[0];
    return bisaya ?
      `Ang kasamtangang ${official.position}${area} mao si ${official.name}.` :
      `The current ${official.position}${barangay ? ` of ${barangay}` : " of Barili"} is ${official.name}.`;
  }
  const listing = valid.slice(0, 8).map((record) => `${record.position}: ${record.name}`).join("; ");
  return bisaya ?
    `Mao kini ang kasamtangang mga opisyal${area}: ${listing}.` :
    `These are the current officials${barangay ? ` of ${barangay}` : " of Barili"}: ${listing}.`;
}

module.exports = {
  ASSISTANT_ACTIONS,
  ASSISTANT_ROUTE_REGISTRY,
  BUILT_IN_MUNICIPAL_OFFICIALS,
  canonicalOfficialRecord,
  cleanPublicRecord,
  groundedOfficialAnswer,
  inferKnownIntent,
  isActionAllowed,
  isCebuanoQuestion,
  officialMatchesPosition,
  routeContextForRole,
  safeClientContext,
};
