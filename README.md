# Nous (v0)

Application de couple, version locale (pas encore de partage entre téléphones).
Contenu : compteur de jours ensemble, messages rapides, événements avec décompte.

## Mise en route (une seule fois)

1. Va sur github.com, connecte-toi, clique sur "+" en haut à droite puis "New repository".
2. Nom : `nous`. Choisis **Public** (GitHub Pages est gratuit seulement pour les dépôts publics ; la v0 ne contient aucune donnée perso). Clique "Create repository".
3. Sur la page du dépôt vide, clique "uploading an existing file".
4. Dézippe `nous.zip` sur ton ordinateur. Ouvre le dossier `nous`, sélectionne TOUT son contenu (`lib`, `.github`, `pubspec.yaml`, `README.md`, `.gitignore`) et glisse-le dans la page GitHub. Vérifie que les dossiers apparaissent bien avec leurs fichiers.
5. Clique "Commit changes" (en bas).
6. Si `.github` n'apparaît pas dans le dépôt : clique "Add file" > "Create new file", tape comme nom `.github/workflows/build.yml` (les `/` créent les dossiers), colle le contenu du fichier `build.yml` et valide.
7. Va dans Settings > Pages. Sous "Source", choisis **GitHub Actions**.

## Lancer le build

1. Onglet **Actions**. Tu verras "Build Nous" tourner (point jaune). Compte 4 à 6 minutes.
2. Si tu ne vois rien : clique "Build Nous" à gauche, puis "Run workflow".
3. Deux tâches : `android` et `web`. Chacune doit passer au vert.

## Récupérer l'APK Android

1. Actions > clique sur la dernière exécution verte.
2. En bas, section **Artifacts** : télécharge `nous-apk` (un zip contenant `app-release.apk`).
3. Envoie l'APK à ta copine (messagerie, mail, drive).
4. Sur son Android : ouvrir le fichier, autoriser l'installation depuis cette source, confirmer si Play Protect avertit ("Installer quand même").

## Tester sur iPhone (aperçu web)

1. Adresse : `https://TON-PSEUDO-GITHUB.github.io/nous/`
2. Ouvre-la dans Safari. Le premier chargement est un peu lent.
3. Pour l'avoir comme une app : bouton Partager > "Sur l'écran d'accueil".

## Si ça rate

Actions > clique l'exécution en rouge > clique la tâche en rouge > copie les dernières lignes d'erreur et envoie-les moi. Si seul `web` est rouge, c'est probablement Pages (dépôt privé ou étape 7 oubliée) : l'APK reste valable.

## Ensuite

1. Backend Supabase : appairage à deux et envoi réel des messages, dessins et photos.
2. Widgets Android, puis iPhone si compte Apple un jour.
3. Animal, livres, films, souhaits.
