# Solena

Jeu de conduite en 3D jouable dans un navigateur.

## Lancer le jeu en local

Depuis ce dossier, démarrez un serveur HTTP :

```bash
python -m http.server 8000
```

Ouvrez ensuite <http://localhost:8000/> dans votre navigateur.

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

- carrosseries lissées, rétroviseurs, calandre et plaques sur les voitures
- routes plus larges, herbe haute en campagne
- détails de façade sur les immeubles (pilastres, bandes néon)
- caméra orbitale au clic droit
