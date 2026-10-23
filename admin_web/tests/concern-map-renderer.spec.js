const { test, expect } = require("@playwright/test");

test("local barangay boundaries render without a Mapbox token", async ({ page }) => {
  await page.goto("/");
  await page.addScriptTag({ path: require.resolve("maplibre-gl/dist/maplibre-gl.js") });
  const result = await page.evaluate(async () => {
    const container = document.createElement("div");
    container.style.cssText = "width:400px;height:300px;position:fixed;left:0;top:0";
    document.body.append(container);
    const map = new maplibregl.Map({
      container,
      style: { version: 8, sources: {}, layers: [{ id: "background", type: "background", paint: { "background-color": "#eef5f1" } }] },
      center: [123.5, 10.1],
      zoom: 10,
    });
    try {
      await new Promise((resolve, reject) => {
        map.once("load", resolve);
        map.once("error", (event) => reject(event.error));
      });
      map.addSource("barangay", { type: "geojson", data: {
        type: "FeatureCollection",
        features: [{ type: "Feature", properties: { name: "Vito" }, geometry: {
          type: "Polygon", coordinates: [[[123.48, 10.08], [123.52, 10.08], [123.52, 10.12], [123.48, 10.12], [123.48, 10.08]]],
        } }],
      } });
      map.addLayer({ id: "barangay-fill", type: "fill", source: "barangay", paint: { "fill-color": "#10b981" } });
      await new Promise((resolve) => map.once("idle", resolve));
      return map.queryRenderedFeatures([200, 150], { layers: ["barangay-fill"] }).length;
    } finally {
      map.remove();
      container.remove();
    }
  });
  expect(result).toBeGreaterThan(0);
});
