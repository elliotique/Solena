# Solena

Jeu de conduite en 3D jouable dans un navigateur.

## Lancer le jeu en local

Installez Node.js, puis depuis ce dossier démarrez le serveur inclus :

```powershell
node server.js
```

Gardez le terminal ouvert et ouvrez ensuite <http://127.0.0.1:8000/> dans votre navigateur. Pour arrêter le serveur, faites `Ctrl+C`.

Three.js et ses modules de post-traitement sont fournis dans `vendor/` : le jeu ne dépend pas d'un CDN pour démarrer.

## Contrôles

- `↑` / `Z` / `W` : accélérer
- `↓` / `S` : freiner ou reculer
- `←` / `Q` / `A` et `→` / `D` : tourner
- `Espace` : frein à main
- `E` : entrer dans la voiture ou en sortir
- `X` / `Maj` / `Ctrl` : descendre ou réduire
- `C` : changer de caméra
- Clic droit maintenu + déplacement de la souris : orbiter autour du personnage ou du véhicule
- `M` : afficher la carte
- `R` : réparer ou replacer la voiture sur la route
- `T` : accélérer le temps
- `H` : klaxon
- `N` : activer ou désactiver le son
- `B` : activer ou désactiver les lueurs
- `P` ou `Échap` : mettre en pause

Sur mobile, utilisez les boutons tactiles affichés en bas de l'écran, notamment `Entrer` et `Bas` lorsque vous êtes à pied ou dans un véhicule.

## Base Unity pour la suite du projet

Le dossier `unity/` contient une base de démarrage pour reconstruire le projet dans Unity avec une architecture plus propre pour la voiture, la ville, l'éclairage et les contrôles de caméra. Il sert de socle pour que Claude ou un autre développeur puisse reprendre le jeu dans un moteur 3D réel sans repartir de zéro.

Le prototype navigateur reste la référence fonctionnelle et visuelle de la version actuelle, tandis que le projet Unity constitue la piste de production pour une version plus ambitieuse.

## Améliorations visuelles de la version actuelle

- matériaux plus travaillés et reflets de voiture améliorés
- éclairage plus lumineux et rendu plus premium
- grass, plantation et détails de terrain enrichis
- bâtiments plus variés en hauteur et en style
- meilleure séparation route / trottoir et collisions plus crédibles
- ambiance plus soignée en ville et sur les bords de mer
