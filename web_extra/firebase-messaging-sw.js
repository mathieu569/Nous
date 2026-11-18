// Service worker des notifications web (affiche la notification quand l'appli est fermée).
// Copié dans le dossier web/ par le build (voir .github/workflows/build.yml).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBk7DRybY7ygbCoxdHymYs1MQ9sxGdLrMs',
  authDomain: 'nous-2a440.firebaseapp.com',
  projectId: 'nous-2a440',
  storageBucket: 'nous-2a440.firebasestorage.app',
  messagingSenderId: '106684109373',
  appId: '1:106684109373:web:b8cd700c2f2fba3727d054',
});

// Sans autre code, Firebase affiche lui-même les messages de type "notification".
firebase.messaging();
