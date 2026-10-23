const assert = require("node:assert/strict");
const test = require("node:test");
const {
  MOTORCYCLE_ESTIMATE_FACTOR,
  computeModeRoutes,
  durationSeconds,
  isUnsupportedTravelModeError,
  normalizeRoute,
  parseRouteRequest,
  routesRequestBody,
} = require("./route_helpers");

const POBLACION = { lat: 10.1112404, lng: 123.511296 };
const MANTAYUPAN = { lat: 10.1009225, lng: 123.5357685 };
const MACTAN = { lat: 10.307, lng: 124.01 };

function fakeRoute(seconds, meters = 4300) {
  return {
    distanceMeters: meters,
    duration: `${seconds}s`,
    description: "Barili–Mantayupan Rd",
    polyline: { encodedPolyline: "abc" },
    legs: [{
      steps: [{
        distanceMeters: meters,
        staticDuration: `${seconds}s`,
        polyline: { encodedPolyline: "abc" },
        navigationInstruction: { maneuver: "TURN_RIGHT", instructions: "Turn right" },
      }],
    }],
  };
}

test("route requests must end in Barili and drop walking for long trips", () => {
  assert.equal(parseRouteRequest({ origin: POBLACION, destination: MACTAN }).error,
    "Directions are only available to places in Barili.");
  assert.ok(parseRouteRequest({ origin: { lat: "x" }, destination: MANTAYUPAN }).error);
  assert.deepEqual(
    parseRouteRequest({ origin: POBLACION, destination: MANTAYUPAN }).modes,
    ["car", "motorcycle", "walk"],
  );
  assert.deepEqual(
    parseRouteRequest({ origin: MACTAN, destination: MANTAYUPAN }).modes,
    ["car", "motorcycle"],
  );
  assert.deepEqual(
    parseRouteRequest({ origin: POBLACION, destination: MANTAYUPAN, modes: ["walk", "boat"] }).modes,
    ["walk"],
  );
  assert.ok(parseRouteRequest({ origin: POBLACION, destination: MANTAYUPAN, modes: ["boat"] }).error);
});

test("request bodies map app modes to Google travel modes", () => {
  assert.equal(routesRequestBody(POBLACION, MANTAYUPAN, "motorcycle").travelMode, "TWO_WHEELER");
  assert.equal(routesRequestBody(POBLACION, MANTAYUPAN, "car").routingPreference, "TRAFFIC_UNAWARE");
  assert.equal("routingPreference" in routesRequestBody(POBLACION, MANTAYUPAN, "walk"), false);
});

test("routes are normalized with whole-second durations and steps", () => {
  assert.equal(durationSeconds("605.4s"), 605);
  assert.equal(durationSeconds(undefined), 0);
  const route = normalizeRoute(fakeRoute(600), "car");
  assert.equal(route.durationSeconds, 600);
  assert.equal(route.estimated, false);
  assert.deepEqual(route.steps[0].maneuver, "TURN_RIGHT");
  assert.equal(normalizeRoute({}, "car"), null);
});

test("motorcycle falls back to an estimated car route when Google has none", async () => {
  const calls = [];
  const results = await computeModeRoutes(
    { origin: POBLACION, destination: MANTAYUPAN, modes: ["car", "motorcycle"] },
    async (body) => {
      calls.push(body.travelMode);
      if (body.travelMode === "TWO_WHEELER") {
        throw Object.assign(new Error("unsupported"), { unsupportedTravelMode: true });
      }
      return fakeRoute(600);
    },
  );
  assert.deepEqual(calls, ["DRIVE", "TWO_WHEELER"]);
  assert.equal(results.motorcycle.estimated, true);
  assert.equal(results.motorcycle.mode, "motorcycle");
  assert.equal(results.motorcycle.durationSeconds, Math.round(600 * MOTORCYCLE_ESTIMATE_FACTOR));
  assert.equal(results.car.durationSeconds, 600);
});

test("real motorcycle routes are used when Google returns one", async () => {
  const results = await computeModeRoutes(
    { origin: POBLACION, destination: MANTAYUPAN, modes: ["motorcycle"] },
    async (body) => (body.travelMode === "TWO_WHEELER" ? fakeRoute(500) : fakeRoute(600)),
  );
  assert.equal(results.motorcycle.estimated, false);
  assert.equal(results.motorcycle.durationSeconds, 500);
  assert.equal(results.car, undefined);
});

test("other routing errors are not hidden by the motorcycle fallback", async () => {
  await assert.rejects(computeModeRoutes(
    { origin: POBLACION, destination: MANTAYUPAN, modes: ["motorcycle"] },
    async () => { throw new Error("quota"); },
  ), /quota/);
});

test("unsupported travel mode errors are recognized", () => {
  assert.equal(isUnsupportedTravelModeError(400, {
    error: { message: "Travel mode TWO_WHEELER is not supported in this region." },
  }), true);
  assert.equal(isUnsupportedTravelModeError(403, { error: { message: "not supported" } }), false);
  assert.equal(isUnsupportedTravelModeError(400, { error: { message: "Invalid origin." } }), false);
});
