const STORAGE_PREFIX = "esugid.web.notifications.seen.v1.";

function itemKey(item) {
  // A resubmission is a new event even when the underlying record ID is reused.
  return JSON.stringify([String(item.type || ""), String(item.id || ""), Number(item.timestamp) || 0]);
}

export function createNotificationReadState(storageProvider) {
  const accounts = new Map();

  function seenFor(userId) {
    const account = String(userId || "");
    if (!accounts.has(account)) {
      let saved = [];
      try {
        const parsed = account ? JSON.parse(storageProvider()?.getItem(STORAGE_PREFIX + account) || "[]") : [];
        if (Array.isArray(parsed)) saved = parsed.filter(key => typeof key === "string");
      } catch (_) {
        // Storage restrictions must not prevent the notification list opening.
      }
      accounts.set(account, new Set(saved));
    }
    return accounts.get(account);
  }

  return {
    unreadCount(userId, items) {
      const seen = seenFor(userId);
      return items.filter(item => !seen.has(itemKey(item))).length;
    },
    markSeen(userId, items) {
      const seen = seenFor(userId);
      for (const item of items) {
        const key = itemKey(item);
        seen.delete(key);
        seen.add(key);
      }
      // Keep current items plus recent history without allowing unlimited growth.
      const keep = Math.max(2000, items.length);
      while (seen.size > keep) seen.delete(seen.values().next().value);
      if (!userId) return;
      try {
        storageProvider()?.setItem(STORAGE_PREFIX + userId, JSON.stringify([...seen]));
      } catch (_) {
        // The in-memory markers still clear the badge for this session.
      }
    },
  };
}
