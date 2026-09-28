# Solena — version Godot (prototype)

Reconstruction de Solena dans le moteur Godot 4. Base de départ : ville générée, voiture à physique réaliste (suspensions et pneus du moteur Godot), cycle jour/nuit, éclairage urbain.

## Lancer

1. Installer Godot 4.7 (gratuit) : https://godotengine.org/download
2. Ouvrir Godot, « Importer », choisir le dossier `godot/` (fichier `project.godot`)
3. Appuyer sur F5

## Contrôles

- ↑ ↓ ou W / S : accélérer, freiner, reculer
- ← → ou A / D : tourner
- Espace : frein à main
- R : remettre la voiture sur ses roues
- C : changer de caméra
- T : accélérer le temps
- Échap : quitter

## Structure

- `project.godot` : configuration (rendu Forward+, ombres 4096, MSAA)
- `scenes/main.tscn` : scène principale
- `scripts/main.gd` : ambiance, ciel, jour/nuit, caméra, lumières des lampadaires, interface
- `scripts/world.gd` : génération de la ville, des routes, de la campagne et de la plage
- `scripts/car.gd` : voiture (VehicleBody3D) et commandes
