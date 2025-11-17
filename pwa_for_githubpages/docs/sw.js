self.addEventListener("install", event => {
  event.waitUntil(
    caches.open("pwa-cache-v1").then(cache => {
      return cache.addAll(["./", "./index.html"]);
    })
  );
});

self.addEventListener("fetch", event => {
  event.respondWith(
    caches.match(event.request).then(res => res || fetch(event.request))
  );
});
