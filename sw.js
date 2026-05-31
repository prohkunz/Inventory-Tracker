/* Inventory Tracker — service worker
   Caches the app shell so it launches instantly (even offline).
   Live data always goes to the network — Supabase traffic is never cached. */

var CACHE = "inventory-shell-v2";

var CORE = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icon-192.png",
  "./icon-512.png",
  "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"
];

// install: pre-cache the app shell (tolerant of individual failures)
self.addEventListener("install", function (e) {
  e.waitUntil(
    caches.open(CACHE).then(function (c) {
      return Promise.all(
        CORE.map(function (url) {
          return c.add(url).catch(function () { /* skip if unreachable */ });
        })
      );
    }).then(function () { return self.skipWaiting(); })
  );
});

// activate: drop old caches
self.addEventListener("activate", function (e) {
  e.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys.filter(function (k) { return k !== CACHE; })
            .map(function (k) { return caches.delete(k); })
      );
    }).then(function () { return self.clients.claim(); })
  );
});

// fetch routing
self.addEventListener("fetch", function (e) {
  var req = e.request;
  var url = new URL(req.url);

  // Supabase API / auth / realtime must always be live — don't touch it
  if (url.hostname.indexOf(".supabase.co") >= 0) return;
  if (req.method !== "GET") return;

  // page loads: fresh when online, cached shell when offline
  if (req.mode === "navigate") {
    e.respondWith(
      fetch(req).catch(function () { return caches.match("./index.html"); })
    );
    return;
  }

  // other assets (icons, fonts, library): serve cached, refresh in background
  e.respondWith(
    caches.match(req).then(function (cached) {
      var fresh = fetch(req).then(function (res) {
        if (res && res.status === 200 && url.protocol === "https:") {
          var copy = res.clone();
          caches.open(CACHE).then(function (c) { c.put(req, copy); });
        }
        return res;
      }).catch(function () { return cached; });
      return cached || fresh;
    })
  );
});
