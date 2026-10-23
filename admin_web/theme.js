/* Blocking head script: resolve the preference before any application UI paints. */
(function () {
  "use strict";
  const storageKey = "esugid_theme";
  const modes = ["light", "dark", "system"];
  const system = window.matchMedia("(prefers-color-scheme: dark)");
  const root = document.documentElement;
  let preference = "system";
  let transitionFrame;

  function readPreference() {
    try {
      const saved = localStorage.getItem(storageKey);
      return modes.includes(saved) ? saved : "system";
    } catch {
      return "system";
    }
  }

  function apply() {
    const resolved = preference === "system" ? (system.matches ? "dark" : "light") : preference;
    // Existing components animate all properties. Resolve foregrounds and
    // surfaces together so their intermediate colors cannot lose contrast.
    if (root.dataset.theme && root.dataset.theme !== resolved) {
      root.classList.add("theme-changing");
      cancelAnimationFrame(transitionFrame);
      transitionFrame = requestAnimationFrame(() => {
        transitionFrame = requestAnimationFrame(() => root.classList.remove("theme-changing"));
      });
    }
    root.dataset.theme = resolved;
    root.dataset.themePreference = preference;
    root.style.colorScheme = resolved;
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", resolved === "dark" ? "#101e19" : "#0b4a38");
    window.dispatchEvent(new CustomEvent("esugid:themechange", { detail: { preference, resolved } }));
  }

  window.ESugidTheme = Object.freeze({
    get preference() { return preference; },
    get resolved() { return root.dataset.theme; },
    set(mode) {
      if (!modes.includes(mode)) return;
      preference = mode;
      try { localStorage.setItem(storageKey, mode); } catch { /* Remains usable without storage. */ }
      apply();
    }
  });

  system.addEventListener("change", () => { if (preference === "system") apply(); });
  window.addEventListener("storage", (event) => {
    if (event.key === storageKey || event.key === null) {
      preference = readPreference();
      apply();
    }
  });
  preference = readPreference();
  apply();
})();
