// Local performance measurements only: no form values, names or IDs are logged.
// Keep a bounded history for browser diagnostics, including failed requests.
export function timedCallable(factory, timing = globalThis.performance) {
  let sequence = 0;
  const history = [];
  return (...args) => {
    const invoke = factory(...args);
    return async data => {
      let start;
      try { start = timing.now(); } catch {}
      let outcome = 'error';
      try { const result = await invoke(data); outcome = 'success'; return result; }
      finally {
        try {
          const name = `esugid:call:${args[1]}:${++sequence}`;
          timing.measure(name, { start, end: timing.now(), detail: { outcome } });
          history.push(name);
          if (history.length > 100) timing.clearMeasures(history.shift());
        } catch { /* Diagnostics must never change the result of an action. */ }
      }
    };
  };
}
