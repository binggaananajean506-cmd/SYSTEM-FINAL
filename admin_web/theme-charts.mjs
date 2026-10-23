/* Chart.js renders into canvas, so CSS color values must be resolved here. */
function seriesColor(value) {
  if (typeof value !== "string") return null;
  let channels;
  if (/^#[\da-f]{6}$/i.test(value)) channels = [1, 3, 5].map(index => parseInt(value.slice(index, index + 2), 16));
  else if (/^rgba?\(/.test(value)) channels = value.match(/[\d.]+/g)?.map(Number);
  if (!channels || channels.length < 3) return null;
  const [r, g, b] = channels;
  const max = Math.max(r, g, b), min = Math.min(r, g, b), delta = max - min;
  if (delta < 20) return null; // Keep neutral point markers and separators.
  let hue = max === r ? (g - b) / delta : max === g ? (b - r) / delta + 2 : (r - g) / delta + 4;
  hue = (hue * 60 + 360) % 360;
  return { role: hue < 25 || hue >= 335 ? "error" : hue < 75 ? "warning" : hue < 190 ? "primaryGreen" : hue < 255 ? "info" : "purple", alpha: channels[3] ?? 1 };
}

export function themeSeriesCssColor(value) {
  const series = seriesColor(value);
  if (!series) return value;
  const dark = series.alpha < 1 ? `color-mix(in srgb, var(--${series.role}) ${series.alpha * 100}%, transparent)` : `var(--${series.role})`;
  return `light-dark(${value}, ${dark})`;
}

export function installChartTheme(Chart) {
  if (!Chart) return;
  const originals = new WeakMap();
  Chart.register({
    id: "esugidTheme",
    beforeUpdate(chart) {
      const options = chart.config.options;
      if (!originals.has(chart)) originals.set(chart, new Map());
      const saved = originals.get(chart);
      const styles = getComputedStyle(document.documentElement);
      const dark = window.ESugidTheme.resolved === "dark";
      const color = (name) => styles.getPropertyValue(`--${name}`).trim();
      function set(object, key, value, path = key) {
        if (!object) return;
        // Chart.js rebuilds scale option objects during updates. Store original
        // values by their option path so switching back restores the light UI.
        if (!saved.has(path)) saved.set(path, object[key]);
        object[key] = dark ? value : saved.get(path);
      }
      set(options, "color", color("textSecondary"));
      for (const [index, dataset] of chart.data.datasets.entries()) {
        for (const key of ["borderColor", "backgroundColor", "pointBorderColor", "pointHoverBackgroundColor"]) {
          const path = `datasets.${index}.${key}`;
          if (!saved.has(path)) saved.set(path, dataset[key]);
          const original = saved.get(path);
          const resolve = value => {
            const series = seriesColor(value);
            if (!series) return value; // Canvas gradients retain their original fills.
            const resolved = color(series.role);
            if (series.alpha === 1) return resolved;
            const rgb = [1, 3, 5].map(offset => parseInt(resolved.slice(offset, offset + 2), 16));
            return `rgba(${rgb.join(", ")}, ${series.alpha})`;
          };
          dataset[key] = dark ? (Array.isArray(original) ? original.map(resolve) : resolve(original)) : original;
        }
      }
      for (const [id, scale] of Object.entries(options.scales || {})) {
        scale.ticks ||= {};
        scale.grid ||= {};
        scale.border ||= {};
        set(scale.ticks, "color", color("textSecondary"), `scales.${id}.ticks.color`);
        set(scale.grid, "color", color("border"), `scales.${id}.grid.color`);
        set(scale.border, "color", color("border"), `scales.${id}.border.color`);
        set(scale.title, "color", color("textPrimary"), `scales.${id}.title.color`);
      }
      if (options.plugins === false) return;
      const plugins = options.plugins ||= {};
      if (plugins.tooltip !== false) {
        const tooltip = plugins.tooltip ||= {};
        for (const [key, value] of Object.entries({ backgroundColor: color("surfaceAlt"), titleColor: color("textPrimary"), bodyColor: color("textPrimary"), borderColor: color("border"), borderWidth: 1 })) {
          set(tooltip, key, value, `tooltip.${key}`);
        }
      }
      set(plugins.legend?.labels, "color", color("textSecondary"), "legend.labels.color");
      set(plugins.title, "color", color("textPrimary"), "title.color");
    }
  });
  function updateCharts() {
    for (const chart of Object.values(Chart.instances)) chart.update("none");
  }
  window.addEventListener("esugid:themechange", updateCharts);
  window.addEventListener("beforeprint", updateCharts);
  window.addEventListener("afterprint", updateCharts);
}
