"use strict";

// Routing for the resident map's "Places to visit" directions. Trips must end
// inside Barili; the bounds match the curated destination checks in the app.
const BARILI_DESTINATION_BOUNDS = Object.freeze({
  minLat: 10.03,
  maxLat: 10.19,
  minLng: 123.46,
  maxLng: 123.61,
});
const TRAVEL_MODES = Object.freeze(["car", "motorcycle", "walk"]);
const GOOGLE_TRAVEL_MODES = Object.freeze({
  car: "DRIVE",
  motorcycle: "TWO_WHEELER",
  walk: "WALK",
});
const MAX_WALK_STRAIGHT_LINE_METERS = 5000;
// Used only when Google has no motorcycle routing for the area: the car route
// is reused and its time shortened slightly.
const MOTORCYCLE_ESTIMATE_FACTOR = 0.9;
const ROUTES_ENDPOINT = "https://routes.googleapis.com/directions/v2:computeRoutes";
const ROUTES_FIELD_MASK = [
  "routes.distanceMeters",
  "routes.duration",
  "routes.description",
  "routes.polyline.encodedPolyline",
  "routes.legs.steps.distanceMeters",
  "routes.legs.steps.staticDuration",
  "routes.legs.steps.polyline.encodedPolyline",
  "routes.legs.steps.navigationInstruction",
].join(",");

function validCoordinate(value) {
  if (!value || typeof value !== "object") return null;
  const lat = Number(value.lat);
  const lng = Number(value.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return { lat, lng };
}

function isInsideBarili(point) {
  const b = BARILI_DESTINATION_BOUNDS;
  return point.lat >= b.minLat && point.lat <= b.maxLat &&
    point.lng >= b.minLng && point.lng <= b.maxLng;
}

function straightLineMeters(from, to) {
  const radius = 6371000;
  const toRad = (deg) => deg * Math.PI / 180;
  const dLat = toRad(to.lat - from.lat);
  const dLng = toRad(to.lng - from.lng);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(from.lat)) * Math.cos(toRad(to.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * radius * Math.asin(Math.sqrt(a));
}

/** Validates the callable payload; returns {origin, destination, modes} or an error message. */
function parseRouteRequest(data) {
  const origin = validCoordinate(data?.origin);
  if (!origin) return { error: "A valid starting location is required." };
  const destination = validCoordinate(data?.destination);
  if (!destination) return { error: "A valid destination is required." };
  if (!isInsideBarili(destination)) {
    return { error: "Directions are only available to places in Barili." };
  }
  const requested = Array.isArray(data?.modes) ? data.modes : TRAVEL_MODES;
  const modes = TRAVEL_MODES.filter((mode) => requested.includes(mode));
  if (modes.length === 0) return { error: "Choose at least one travel mode." };
  const walkable = straightLineMeters(origin, destination) <= MAX_WALK_STRAIGHT_LINE_METERS;
  return {
    origin,
    destination,
    modes: modes.filter((mode) => mode !== "walk" || walkable),
  };
}

function routesRequestBody(origin, destination, mode) {
  const travelMode = GOOGLE_TRAVEL_MODES[mode];
  const waypoint = (point) => ({
    location: { latLng: { latitude: point.lat, longitude: point.lng } },
  });
  return {
    origin: waypoint(origin),
    destination: waypoint(destination),
    travelMode,
    // Walking routes reject a routing preference.
    ...(travelMode === "WALK" ? {} : { routingPreference: "TRAFFIC_UNAWARE" }),
    computeAlternativeRoutes: false,
    languageCode: "en",
    regionCode: "ph",
    units: "METRIC",
  };
}

function durationSeconds(value) {
  const match = /^(\d+(?:\.\d+)?)s$/.exec(String(value ?? ""));
  return match ? Math.round(Number(match[1])) : 0;
}

/** Shrinks a Routes API route into the shape the app reads. */
function normalizeRoute(route, mode, { estimated = false } = {}) {
  if (!route?.polyline?.encodedPolyline) return null;
  const factor = estimated ? MOTORCYCLE_ESTIMATE_FACTOR : 1;
  const steps = (route.legs ?? []).flatMap((leg) => leg.steps ?? []).map((step) => ({
    instruction: String(step.navigationInstruction?.instructions ?? "").trim(),
    maneuver: String(step.navigationInstruction?.maneuver ?? "MANEUVER_UNSPECIFIED"),
    distanceMeters: Number(step.distanceMeters ?? 0),
    durationSeconds: Math.round(durationSeconds(step.staticDuration) * factor),
    encodedPolyline: String(step.polyline?.encodedPolyline ?? ""),
  }));
  return {
    mode,
    distanceMeters: Number(route.distanceMeters ?? 0),
    durationSeconds: Math.round(durationSeconds(route.duration) * factor),
    description: String(route.description ?? ""),
    encodedPolyline: route.polyline.encodedPolyline,
    estimated,
    steps,
  };
}

/**
 * Computes one route per requested mode. `requestRoute(body)` performs the
 * Routes API call and resolves to its first route, or null when there is none;
 * it throws for transport or API errors.
 */
async function computeModeRoutes({ origin, destination, modes }, requestRoute) {
  const results = {};
  for (const mode of modes) {
    if (mode === "motorcycle") continue;
    const route = await requestRoute(routesRequestBody(origin, destination, mode));
    results[mode] = normalizeRoute(route, mode);
  }
  if (modes.includes("motorcycle")) {
    let route = null;
    try {
      route = await requestRoute(routesRequestBody(origin, destination, "motorcycle"));
    } catch (error) {
      if (!error?.unsupportedTravelMode) throw error;
    }
    if (route) {
      results.motorcycle = normalizeRoute(route, "motorcycle");
    } else {
      const carRoute = results.car === undefined ?
        await requestRoute(routesRequestBody(origin, destination, "car")) :
        null;
      const base = results.car ?? normalizeRoute(carRoute, "car");
      results.motorcycle = base ? {
        ...base,
        mode: "motorcycle",
        estimated: true,
        durationSeconds: Math.round(base.durationSeconds * MOTORCYCLE_ESTIMATE_FACTOR),
        steps: base.steps.map((step) => ({
          ...step,
          durationSeconds: Math.round(step.durationSeconds * MOTORCYCLE_ESTIMATE_FACTOR),
        })),
      } : null;
    }
  }
  return results;
}

/** Google answers INVALID_ARGUMENT when a travel mode isn't offered in a region. */
function isUnsupportedTravelModeError(status, body) {
  if (status !== 400) return false;
  const message = String(body?.error?.message ?? "").toLowerCase();
  return message.includes("travel mode") || message.includes("two_wheeler") ||
    message.includes("not supported");
}

module.exports = {
  BARILI_DESTINATION_BOUNDS,
  MOTORCYCLE_ESTIMATE_FACTOR,
  ROUTES_ENDPOINT,
  ROUTES_FIELD_MASK,
  TRAVEL_MODES,
  computeModeRoutes,
  durationSeconds,
  isUnsupportedTravelModeError,
  normalizeRoute,
  parseRouteRequest,
  routesRequestBody,
  straightLineMeters,
};
