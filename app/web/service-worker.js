// Kill switch for the old Blazor PWA, which registered a service worker under
// this name and keeps serving its cached app. Browsers re-check this script on
// every visit; this version clears the old caches, removes itself and reloads
// open tabs, so they get the Flutter app from the server.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    await self.clients.claim();
    const keys = await caches.keys();
    await Promise.all(keys.map((key) => caches.delete(key)));
    await self.registration.unregister();
    const tabs = await self.clients.matchAll({ type: 'window' });
    tabs.forEach((tab) => tab.navigate(tab.url));
  })());
});
