# Solena Unity starter

This folder is a migration starter for a Unity-based version of the project.

The goal is to keep the browser prototype as a reference while giving Claude or another developer a clean foundation to rebuild the game in a real engine with proper scene composition, lighting, vehicle logic, and city generation.

## Recommended Unity version

Use Unity 2022.3 LTS or later.

## Structure

- `Assets/Scripts/Bootstrap/` : global bootstrapping and application setup
- `Assets/Scripts/Driving/` : vehicle logic and input handling
- `Assets/Scripts/World/` : city generation and environment setup
- `ProjectSettings/` : Unity project metadata baseline

## Starting point for the rebuild

1. Create a new Unity 3D project and copy the content of this folder as the project root.
2. Add a `Main` scene.
3. Create a `Player` GameObject with a `VehicleController` component.
4. Create a `WorldRoot` GameObject and attach a `CityGenerator` component.
5. Add a daylight directional light, a skybox, and a post-processing volume.
6. Build the game loop around the current browser prototype's rules:
   - drive / exit vehicle
   - city blocks and road layout
   - traffic density management
   - camera orbiting around the player
   - better visual materials and modern/older building variation

## Important notes

- This is a foundation only. It is intentionally lightweight and easy to expand.
- The visual identity should target a premium GTA-inspired city atmosphere, without trying to match a full AAA production in a single pass.
- The HTML prototype remains the source of gameplay direction, while Unity becomes the production-grade implementation target.

## Suggested next milestones

1. Build a drivable vehicle controller and camera rig
2. Create a city generator with roads, sidewalks, and varied blocks
3. Add traffic vehicles and collision layers
4. Add props, building variants, and lighting passes
5. Tune performance and polish materials / reflections
6. Add quests, missions, audio, and progression systems
