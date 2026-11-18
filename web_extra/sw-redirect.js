// Les notifications web de Firebase cherchent leur fichier à la racine du domaine
// (https://mathieu569.github.io/firebase-messaging-sw.js), mais l'appli est dans /Nous/.
// On redirige l'enregistrement vers le bon dossier (celui de <base href>).
(function () {
  if (!('serviceWorker' in navigator)) return;
  var original = navigator.serviceWorker.register.bind(navigator.serviceWorker);
  navigator.serviceWorker.register = function (url, options) {
    if (String(url).indexOf('firebase-messaging-sw.js') !== -1) {
      var script = new URL('firebase-messaging-sw.js', document.baseURI).href;
      var scope = new URL('firebase-cloud-messaging-push-scope', document.baseURI).pathname;
      return original(script, { scope: scope });
    }
    return original(url, options);
  };
})();
